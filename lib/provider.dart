import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:round_task/models/task.dart';

const _defaultSkipSize = 256;

final isarPod = FutureProvider((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open([UserTaskSchema, SubTaskSchema, TaskDirSchema],
      directory: dir.path);

  ref.onDispose(isar.close);
  return isar;
});

final repositoryPod = Provider(Repository.new);

// no need to dispose, since they are used in the main screen of the app
final queuedTasksPod = StreamProvider((ref) {
  final repository = ref.watch(repositoryPod);

  return repository.getQueuedTasksStream();
});

final pendingTasksPod = StreamProvider((ref) {
  final repository = ref.watch(repositoryPod);

  return repository.getPendingTasksStream();
});

class AutomaticTaskQueuer {
  AutomaticTaskQueuer(this.repository);

  final Repository repository;

  DateTime? _value;
  Timer? _timer;

  Future<void> init() async {
    await repository.addScheduledTasks();
    value = await repository.getNextPendingTaskDate();
    return;
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
    _updateTimer(date);
  }

  void _updateTimer(DateTime? date) {
    if (date == null) return;

    final now = DateTime.now();
    var duration = date.difference(now);
    if (duration.isNegative) duration = Duration.zero;

    _timer?.cancel();
    _timer = Timer(duration, () async {
      await repository.addScheduledTasks();
      value = await repository.getNextPendingTaskDate();
    });
  }

  void dispose() {
    _timer?.cancel();
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

  Future<void> _saveTask(Isar isar, UserTask task) async {
    // the task needs to be in the database
    // before saving the subtasks link
    await isar.userTasks.put(task);
    // we need to save the links, otherwise they won't be considered
    // by the iterator methods to calculate the progress
    await task.subTasks.save();

    task.progress = task.subTasks.isEmpty
        ? null
        : task.subTasks.where((subTask) => subTask.done).length /
            task.subTasks.length;

    await isar.userTasks.put(task);
  }

  Future<void> updateTask(UserTask task) async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      await _saveTask(isar, task);
    });

    taskQueuer.tryUpdate(task.autoInsertDate);
  }

  Future<void> updateSubTasks(List<SubTask> subTasks) async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      await isar.subTasks.putAll(subTasks);
    });
  }

  Future<void> deleteSubTasks(List<SubTask> subTasks) async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      await isar.subTasks.deleteAll(
        subTasks.map((subTask) => subTask.id).toList(),
      );
    });
  }

  Stream<List<UserTask>> getQueuedTasksStream() async* {
    final isar = await _isar;
    await _queueInitFuture;

    yield* isar.userTasks
        .where()
        .referenceIsNotNull()
        .watch(fireImmediately: true);
  }

  Stream<List<UserTask>> getPendingTasksStream() async* {
    final isar = await _isar;
    await _queueInitFuture;

    final query = isar.userTasks
        .where()
        .referenceIsNull()
        .filter()
        .archivedEqualTo(false)
        .sortByCreationDate();
    yield* query.watch(fireImmediately: true);
  }

  Future<void> addTaskToQueue(UserTask task) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      final insertAtStart =
          task.autoInsertDate?.isBefore(DateTime.now()) ?? false;

      final reference = await isar.userTasks
          .where(sort: insertAtStart ? Sort.asc : Sort.desc)
          .referenceIsNotNull()
          .referenceProperty()
          .findFirst();

      if (reference == null) {
        task.reference = 0;
      } else if (insertAtStart) {
        task.reference = reference - _defaultSkipSize;
      } else {
        task.reference = reference + _defaultSkipSize;
      }

      await _saveTask(isar, task);
    });

    // TODO: is this even required anymore?
    taskQueuer.tryUpdate(task.autoInsertDate);
  }

  Future<void> removeTaskFromQueue(UserTask task) async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      task.reference = null;
      await _saveTask(isar, task);
    });

    taskQueuer.tryUpdate(task.autoInsertDate);
  }

  Future<void> addScheduledTasks() async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      final now = DateTime.now();
      final tasks = await isar.userTasks
          .where()
          .autoInsertDateBetween(null, now, includeLower: false)
          .filter()
          .referenceIsNull()
          .findAll();

      final firstReference = await isar.userTasks
          .where()
          .referenceIsNotNull()
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

  Future<void> moveTaskToEndOfQueue(UserTask task) async {
    final isar = await _isar;
    final lastTask = await isar.userTasks
        .where(sort: Sort.desc)
        .referenceIsNotNull()
        .findFirst();

    if (lastTask == null) {
      task.reference = 0;
    } else {
      if (lastTask.id == task.id) return;
      task.reference = lastTask.reference! + _defaultSkipSize;
    }

    await isar.writeTxn(() async {
      await _saveTask(isar, task);
    });

    taskQueuer.tryUpdate(task.autoInsertDate);
  }

  Future<void> moveTaskToStartOfQueue(UserTask task) async {
    final isar = await _isar;
    final firstTask =
        await isar.userTasks.where().referenceIsNotNull().findFirst();

    if (firstTask == null) {
      task.reference = 0;
    } else {
      if (firstTask.id == task.id) return;
      task.reference = firstTask.reference! - _defaultSkipSize;
    }

    await isar.writeTxn(() async {
      await _saveTask(isar, task);
    });

    taskQueuer.tryUpdate(task.autoInsertDate);
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

  Future<List<UserTask>> searchTasks(bool queued, String searchText) async {
    final isar = await _isar;

    QueryBuilder<UserTask, UserTask, QFilterCondition> query;
    if (queued) {
      query = isar.userTasks.where().referenceIsNotNull().filter();
    } else {
      query = isar.userTasks.where().referenceIsNull().filter();
    }

    return await query
        .group((q) => q
            .titleContains(searchText, caseSensitive: false)
            .or()
            .descriptionContains(searchText, caseSensitive: false))
        .findAll();
  }
}
