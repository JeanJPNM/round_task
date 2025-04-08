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

final taskPod = FutureProvider.family.autoDispose((ref, int taskId) async {
  final value = ref.read(isarPod);
  final Isar isar;
  if (value.hasValue) {
    isar = value.value!;
  } else {
    isar = await ref.read(isarPod.future);
  }

  final task = await isar.userTasks.get(taskId);

  return task;
});

final repositoryPod = Provider(Repository.new);

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

    if (value == null) {
      value = date;
    } else if (date.isBefore(value!)) {
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
    unawaited(taskQueuer.init());
    ref.onDispose(taskQueuer.dispose);
  }

  late final AutomaticTaskQueuer taskQueuer = AutomaticTaskQueuer(this);
  final Ref ref;

  Future<Isar> get _isar => ref.read(isarPod.future);

  Future<void> updateTask(UserTask task) async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      await isar.userTasks.put(task);
    });
    taskQueuer.tryUpdate(
      task.startDate ?? task.endDate?.subtract(const Duration(days: 1)),
    );
  }

  Stream<List<UserTask>> getQueuedTasksStream() async* {
    final isar = await _isar;
    // isar.userTasks.where().anyReference().filter().referenceIsNotNull();

    await for (final _ in isar.userTasks.watchLazy(fireImmediately: true)) {
      yield await isar.userTasks.where().referenceIsNotNull().findAll();
    }
  }

  Stream<List<UserTask>> getPendingTasksStream() async* {
    final isar = await _isar;
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
      final lastTask = await isar.userTasks
          .where()
          .referenceIsNotNull()
          .sortByReferenceDesc()
          .findFirst();

      if (lastTask != null) {
        task.reference = lastTask.reference! + _defaultSkipSize;
      }

      await isar.userTasks.put(task);
    });
  }

  Future<void> removeTaskFromQueue(UserTask task) async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      task.reference = null;
      await isar.userTasks.put(task);
    });
  }

  Future<void> addScheduledTasks() async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      final now = DateTime.now();
      final tasks = await isar.userTasks
          .where()
          .referenceIsNull()
          .filter()
          .group(
            (q) => q.startDateIsNotNull().startDateLessThan(now, include: true),
          )
          .or()
          .group(
            (q) => q.startDateIsNull().endDateIsNotNull().endDateLessThan(
                  now.add(const Duration(days: 1)),
                  include: true,
                ),
          )
          .sortByStartDate()
          .thenByEndDate()
          .findAll();

      final firstTask = await isar.userTasks
          .where()
          .referenceIsNotNull()
          .sortByReference()
          .findFirst();

      var current = 0;
      var increment = _defaultSkipSize;
      Iterable<UserTask> taskIterable = tasks;

      if (firstTask != null) {
        increment = -increment;
        current = firstTask.reference! + increment;

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
        .where()
        .referenceIsNotNull()
        .sortByReferenceDesc()
        .findFirst();

    if (lastTask == null) {
      task.reference = 0;
    } else {
      if (lastTask.id == task.id) return;
      task.reference = lastTask.reference! + _defaultSkipSize;
    }

    await isar.writeTxn(() async {
      await isar.userTasks.put(task);
    });
  }

  Future<void> moveTaskToStartOfQueue(UserTask task) async {
    final isar = await _isar;
    final firstTask = await isar.userTasks
        .where()
        .referenceIsNotNull()
        .sortByReference()
        .findFirst();

    if (firstTask == null) {
      task.reference = 0;
    } else {
      if (firstTask.id == task.id) return;
      task.reference = firstTask.reference! - _defaultSkipSize;
    }

    await isar.writeTxn(() async {
      await isar.userTasks.put(task);
    });
  }

  Future<void> deleteTask(UserTask task) async {
    final isar = await _isar;

    await isar.writeTxn(() async {
      await isar.userTasks.delete(task.id);
    });
  }

  Future<DateTime?> getNextPendingTaskDate() async {
    final isar = await _isar;
    final task = await isar.userTasks
        .where()
        .referenceIsNull()
        .filter()
        .startDateGreaterThan(DateTime.now())
        .sortByStartDate()
        .findFirst();

    return task?.startDate;
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
}
