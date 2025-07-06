import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:round_task/models/database_metadata.dart';
import 'package:round_task/models/task.dart';

const _defaultSkipSize = 256;

final isarPod = AsyncNotifierProvider<IsarNotifier, Isar>(IsarNotifier.new);

final repositoryPod = Provider(Repository.new);

// no need to dispose, since they are used in the main screen of the app
final _innerQueuedTasksPod = StreamProvider((ref) async* {
  await ref.watch(isarPod.future);
  final repository = ref.watch(repositoryPod);

  yield* repository.getQueuedTasksStream();
});

final queuedTasksPod = Provider.family.autoDispose((ref, TaskSorting? sorting) {
  final tasks = ref.watch(_innerQueuedTasksPod);

  // tasks already come sorted by reference
  if (sorting == null) return tasks;

  if (tasks case AsyncData()) {
    return tasks.applySorting(sorting);
  }

  return tasks;
});

final _innerPendingTasksPod = StreamProvider((ref) async* {
  await ref.watch(isarPod.future);
  final repository = ref.watch(repositoryPod);

  yield* repository.getPendingTasksStream();
});

final pendingTasksPod = Provider.family.autoDispose((
  ref,
  TaskSorting sorting,
) {
  final tasks = ref.watch(_innerPendingTasksPod);

  // tasks already come sorted by creation date
  if (sorting == TaskSorting.creationDate) return tasks;

  if (tasks case AsyncData()) {
    return tasks.applySorting(sorting);
  }

  return tasks;
});

final archivedTasksPod = StreamProvider.autoDispose((ref) async* {
  await ref.watch(isarPod.future);
  final repository = ref.watch(repositoryPod);

  yield* repository.getArchivedTasksStream();
});

class IsarNotifier extends AsyncNotifier<Isar> {
  late final String _isarDir;
  @override
  Future<Isar> build() async {
    final dir = Platform.isAndroid || Platform.isIOS
        ? await getApplicationDocumentsDirectory()
        : await getApplicationSupportDirectory();

    _isarDir = dir.path;

    final isar = await _openIsar(
      directory: _isarDir,
    );
    await _migrateIfNeeded(isar);

    ref.onDispose(dispose);

    return isar;
  }

  Future<Isar> _openIsar({
    required String directory,
    String name = Isar.defaultName,
  }) async {
    return Isar.open(
      [UserTaskSchema, SubTaskSchema, TaskDirSchema, DatabaseMetadataSchema],
      directory: directory,
      name: name,
    );
  }

  Future<void> _migrateIfNeeded(Isar isar) async {
    final metadata = await isar.databaseMetadatas.get(0);
    if (metadata == null) {
      // first time opening the database, create metadata
      await isar.writeTxn(() async {
        await isar.databaseMetadatas.put(const DatabaseMetadata(id: 0));
      });
    }

    // add migration logic later
  }

  Future<void> exportDatabase(String path) async {
    final isar = await future;
    state = const AsyncValue.loading();

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      await isar.copyToFile(path);
    } finally {
      state = AsyncValue.data(isar);
    }
  }

  Future<void> importDatabase(String path) async {
    var isar = await future;
    state = const AsyncValue.loading();
    await isar.close();

    try {
      final file = File(path);
      // make sure the other isar file is valid
      final importedIsar = await _openIsar(
        directory: file.parent.path,
        name: basenameWithoutExtension(file.path),
      );
      await importedIsar.close();

      await file.copy(join(_isarDir, "${Isar.defaultName}.isar"));
    } finally {
      isar = await _openIsar(directory: _isarDir);
      await _migrateIfNeeded(isar);
      state = AsyncValue.data(isar);
    }
  }

  void dispose() {
    if (state case AsyncData<Isar> data) {
      data.value.close();
    }
  }
}

class AutomaticTaskQueuer {
  AutomaticTaskQueuer(this.repository);

  final Repository repository;

  DateTime? _value;
  Timer? _timer;

  Future<void> init() async {
    await _runUpdate(force: true);
  }

  void tryUpdate(DateTime? date) {
    if (date == null) return;

    if (value == null || date.isBefore(value!)) {
      value = date;
    }
  }

  DateTime? get value => _value;
  set value(DateTime? date) {
    _value = date;

    if (date?.isBefore(DateTime.now()) ?? false) {
      _runUpdate();
    }
  }

  // we check for pending tasks every 5 seconds
  // because a fixed timer to the next task
  // can be delayed if the app is put in the background
  // and reopened later
  Future<void> _runUpdate({bool force = false}) async {
    _timer?.cancel();
    const duration = Duration(seconds: 5);

    final now = DateTime.now();

    if (value?.isBefore(now) ?? force) {
      await repository.addScheduledTasks();
      final date = await repository.getNextPendingTaskDate();
      _timer = Timer(duration, _runUpdate);
      value = date;
    } else {
      _timer = Timer(duration, _runUpdate);
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

enum QueueInsertionPosition {
  start,
  end,
  preferred,
}

sealed class TaskEditAction {
  const TaskEditAction();
}

class PutTaskInQueue extends TaskEditAction {
  PutTaskInQueue(this.position);

  final QueueInsertionPosition position;
}

class RemoveTaskFromQueue extends TaskEditAction {
  const RemoveTaskFromQueue();
}

class PutSubTasks extends TaskEditAction {
  PutSubTasks(this.subTasks);

  final List<SubTask> subTasks;
}

class RemoveSubTasks extends TaskEditAction {
  RemoveSubTasks(this.subTasks);

  final List<SubTask> subTasks;
}

enum TaskSearchType {
  queued,
  pending,
  archived,
}

enum TaskSorting {
  creationDate,
  autoInsertDate,
  endDate;

  DateTime? Function(UserTask task) get _keyOf {
    return switch (this) {
      TaskSorting.creationDate => (task) => task.creationDate,
      TaskSorting.autoInsertDate => (task) => task.autoInsertDate,
      TaskSorting.endDate => (task) => task.endDate,
    };
  }
}

class Repository {
  Repository(this.ref) {
    _queueInitFuture = taskQueuer.init();
    ref.onDispose(taskQueuer.dispose);
  }

  late final Future<void> _queueInitFuture;
  late final AutomaticTaskQueuer taskQueuer = AutomaticTaskQueuer(this);
  final Ref ref;

  Future<Isar> get _isar => ref.read(isarPod.future);

  Future<void> writeTask(
    UserTask task, [
    List<TaskEditAction> actions = const [],
  ]) async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      for (final action in actions) {
        switch (action) {
          case PutTaskInQueue(:final position):
            await _putTaskInQueue(isar, task, position);
          case RemoveTaskFromQueue():
            task.reference = null;
          case PutSubTasks(:final subTasks):
            await isar.subTasks.putAll(subTasks);
          case RemoveSubTasks(:final subTasks):
            await isar.subTasks.deleteAll(
              subTasks.map((subTask) => subTask.id).toList(),
            );
        }
      }

      await isar.userTasks.put(task);
      await task.subTasks.save();
    });

    taskQueuer.tryUpdate(task.autoInsertDate);
  }

  Future<void> _putTaskInQueue(
    Isar isar,
    UserTask task,
    QueueInsertionPosition position,
  ) async {
    final insertAtStart = switch (position) {
      QueueInsertionPosition.start => true,
      QueueInsertionPosition.end => false,
      QueueInsertionPosition.preferred =>
        task.autoInsertDate?.isBefore(DateTime.now()) ?? false,
    };

    final reference = await isar.userTasks
        .where(sort: insertAtStart ? Sort.asc : Sort.desc)
        .referenceIsNotNullAnyArchived()
        .referenceProperty()
        .findFirst();

    task.archived = false;

    if (reference == null) {
      task.reference = 0;
    } else if (insertAtStart) {
      task.reference = reference - _defaultSkipSize;
    } else {
      task.reference = reference + _defaultSkipSize;
    }
  }

  Stream<List<UserTask>> getQueuedTasksStream() async* {
    final isar = await _isar;
    await _queueInitFuture;

    yield* isar.userTasks
        .where()
        .referenceIsNotNullAnyArchived()
        .watch(fireImmediately: true);
  }

  Stream<List<UserTask>> getPendingTasksStream() async* {
    final isar = await _isar;
    await _queueInitFuture;

    final query = isar.userTasks
        .where()
        .referenceArchivedEqualTo(null, false)
        .sortByCreationDate();
    yield* query.watch(fireImmediately: true);
  }

  Stream<List<UserTask>> getArchivedTasksStream() async* {
    final isar = await _isar;
    await _queueInitFuture;

    final query = isar.userTasks
        .where()
        .referenceArchivedEqualTo(null, true)
        .sortByLastTouchedDesc();
    yield* query.watch(fireImmediately: true);
  }

  Future<void> addScheduledTasks() async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      final now = DateTime.now();
      final tasks = await isar.userTasks
          .where(sort: Sort.desc)
          .autoInsertDateBetween(null, now, includeLower: false)
          .filter()
          .referenceIsNull()
          .findAll();

      final firstReference = await isar.userTasks
          .where()
          .referenceIsNotNullAnyArchived()
          .referenceProperty()
          .findFirst();

      var current = 0;
      var increment = _defaultSkipSize;
      Iterable<UserTask> taskIterable = tasks;

      if (firstReference != null) {
        increment = -increment;
        current = firstReference + increment;

        // in this mode, the tasks are added to the beginning of the queue
        // so we need to reverse the iteration order
        taskIterable = tasks.reversed;
      }

      for (final task in taskIterable) {
        task.reference = current;
        current += increment;
      }

      await isar.userTasks.putAll(tasks);
    });
  }

  Future<void> deleteTask(UserTask task) async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      await isar.subTasks.deleteAll(
        task.subTasks.map((subTask) => subTask.id).toList(),
      );
      await isar.userTasks.delete(task.id);
    });
  }

  Future<DateTime?> getNextPendingTaskDate() async {
    final isar = await _isar;
    return await isar.userTasks
        .where()
        .autoInsertDateIsNotNull()
        .filter()
        .referenceIsNull()
        .archivedEqualTo(false)
        .autoInsertDateProperty()
        .findFirst();
  }

  //  TODO: use the reference to only update one task
  Future<void> reorderTasks(List<UserTask> tasks) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      for (var i = 0; i < tasks.length; i++) {
        tasks[i].reference = i * _defaultSkipSize;
      }

      await isar.userTasks.putAll(tasks);
    });
  }

  Future<List<UserTask>> searchTasks(
    TaskSearchType type,
    String searchText,
  ) async {
    final isar = await _isar;

    final query = switch (type) {
      TaskSearchType.queued =>
        isar.userTasks.where().referenceIsNotNullAnyArchived(),
      TaskSearchType.pending =>
        isar.userTasks.where().referenceArchivedEqualTo(null, false),
      TaskSearchType.archived =>
        isar.userTasks.where().referenceArchivedEqualTo(null, true),
    };

    return await query
        .filter()
        .group((q) => q
            .titleContains(searchText, caseSensitive: false)
            .or()
            .descriptionContains(searchText, caseSensitive: false))
        .findAll();
  }
}

int _compareNullableDatetime(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

extension on AsyncData<List<UserTask>> {
  AsyncData<List<UserTask>> applySorting(TaskSorting sorting) {
    return AsyncData(value.sortedByCompare(
      sorting._keyOf,
      _compareNullableDatetime,
    ));
  }
}
