import 'dart:async';

import 'package:drift/drift.dart';
import 'package:rrule/rrule.dart';

part 'database.g.dart';

const _defaultSkipSize = 256;

enum TaskStatus {
  active(0),
  pending(1),
  archived(2);

  final int dbCode;

  const TaskStatus(this.dbCode);

  factory TaskStatus.fromDbCode(int code) {
    return switch (code) {
      0 => TaskStatus.active,
      1 => TaskStatus.pending,
      2 => TaskStatus.archived,
      _ => TaskStatus.pending,
    };
  }
}

class TaskStatusConverter extends TypeConverter<TaskStatus, int> {
  const TaskStatusConverter();

  @override
  TaskStatus fromSql(int fromDb) {
    return TaskStatus.fromDbCode(fromDb);
  }

  @override
  int toSql(TaskStatus value) {
    return value.dbCode;
  }
}

class RecurrenceRuleConverter extends TypeConverter<RecurrenceRule?, String?> {
  const RecurrenceRuleConverter();

  @override
  RecurrenceRule? fromSql(String? fromDb) {
    if (fromDb == null) return null;

    try {
      return RecurrenceRule.fromString(fromDb);
    } catch (e) {
      return null;
    }
  }

  @override
  String? toSql(RecurrenceRule? value) {
    return value?.toString();
  }
}

/// Stores values as milliseconds since epoch,
/// retrieving them in the local timezone.
class DateTimeConverter extends TypeConverter<DateTime, int> {
  const DateTimeConverter();

  @override
  DateTime fromSql(int fromDb) {
    return DateTime.fromMillisecondsSinceEpoch(fromDb);
  }

  @override
  int toSql(DateTime value) {
    return value.millisecondsSinceEpoch;
  }
}

@TableIndex(name: "idx_user_tasks_status", columns: {#status})
@TableIndex(name: "idx_user_tasks_auto_insert_date", columns: {#autoInsertDate})
@TableIndex(name: "idx_user_tasks_deleted_at", columns: {#deletedAt})
@TableIndex(
  name: "idx_user_tasks_active_time_measurement_start",
  columns: {#activeTimeMeasurementStart},
)
class UserTasks extends Table {
  late final id = integer().autoIncrement()();
  late final title = text()();
  late final description = text()();
  late final status = integer().map(const TaskStatusConverter())();
  late final reference = integer().nullable()();
  late final progress = real().nullable()();
  late final createdAt = integer().map(const DateTimeConverter())();
  late final updatedByUserAt = integer().map(const DateTimeConverter())();
  late final deletedAt = integer().map(const DateTimeConverter()).nullable()();
  late final startDate = integer().map(const DateTimeConverter()).nullable()();
  late final endDate = integer().map(const DateTimeConverter()).nullable()();
  late final autoInsertDate =
      integer().map(const DateTimeConverter()).nullable().generatedAs(
            coalesce([
              startDate,
              endDate - Constant(const Duration(days: 1).inMilliseconds),
            ]),
            stored: true,
          )();
  late final activeTimeMeasurementStart =
      integer().map(const DateTimeConverter()).nullable()();

  late final recurrence =
      text().map(const RecurrenceRuleConverter()).nullable()();
}

@TableIndex(name: "idx_sub_tasks_task_id", columns: {#taskId})
class SubTasks extends Table {
  late final id = integer().autoIncrement()();
  late final taskId = integer().references(
    UserTasks,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final title = text()();
  late final done = boolean()();
  late final reference = integer()();
}

@TableIndex(name: "idx_time_measurements_task_id", columns: {#taskId})
class TimeMeasurements extends Table {
  late final id = integer().autoIncrement()();
  late final taskId = integer().references(
    UserTasks,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final start = integer().map(const DateTimeConverter())();
  late final end = integer().map(const DateTimeConverter())();
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

  final List<SubTasksCompanion> subTasks;
}

class RemoveSubTasks extends TaskEditAction {
  RemoveSubTasks(this.subTasksIds);

  final List<int> subTasksIds;
}

class StartTimeMeasurement extends TaskEditAction {
  const StartTimeMeasurement(this.reference);
  final DateTime reference;
}

class StopTimeMeasurement extends TaskEditAction {
  const StopTimeMeasurement(this.reference);
  final DateTime reference;
}

class PutTimeMeasurement extends TaskEditAction {
  PutTimeMeasurement(this.measurement);

  final Insertable<TimeMeasurement> measurement;
}

class RemoveTimeMeasurement extends TaskEditAction {
  RemoveTimeMeasurement(this.measurement);

  final TimeMeasurement measurement;
}

@DriftDatabase(tables: [UserTasks, SubTasks, TimeMeasurements])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase(super.e);

  late final AutomaticTaskQueuer _queuer = AutomaticTaskQueuer(this);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  @override
  Future<void> close() {
    _queuer.dispose();
    return super.close();
  }

  Future<void> init({
    Future<void> Function(AppDatabase)? runIsarMigration,
  }) async {
    if (runIsarMigration != null) {
      await runIsarMigration(this);
    }
    await _queuer.init();
  }

  SimpleSelectStatement<$UserTasksTable, UserTask> _selectTasks() {
    return select(userTasks)..where((t) => t.deletedAt.isNull());
  }

  Stream<List<UserTask>> getQueuedTasksStream() async* {
    yield* (_selectTasks()
          ..where((t) => t.status.equalsValue(TaskStatus.active))
          ..orderBy([(t) => OrderingTerm.asc(t.reference)]))
        .watch();
  }

  Stream<List<UserTask>> getPendingTasksStream() async* {
    yield* (_selectTasks()
          ..where((t) => t.status.equalsValue(TaskStatus.pending))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<UserTask>> getArchivedTasksStream() async* {
    yield* (_selectTasks()
          ..where((t) => t.status.equalsValue(TaskStatus.archived))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedByUserAt)]))
        .watch();
  }

  Stream<UserTask?> getCurrentlyTrackedTaskStream() async* {
    yield* (_selectTasks()
          ..where((t) => t.activeTimeMeasurementStart.isNotNull())
          ..limit(1))
        .watchSingleOrNull();
  }

  Stream<UserTask?> getTaskByIdStream(int taskId) {
    return (select(userTasks)..where((t) => t.id.equals(taskId)))
        .watchSingleOrNull();
  }

  Stream<List<SubTask>> getSubTasksStream(int taskId) {
    return (select(subTasks)
          ..where((s) => s.taskId.equals(taskId))
          ..orderBy([(t) => OrderingTerm.asc(t.reference)]))
        .watch();
  }

  Stream<List<TimeMeasurement>> getTimeMeasurementsStream(int taskId) {
    return (select(timeMeasurements)
          ..where((t) => t.taskId.equals(taskId))
          ..orderBy([(t) => OrderingTerm.desc(t.start)]))
        .watch();
  }

  Future<void> writeTask(
    Insertable<UserTask> taskInsertable, [
    List<TaskEditAction> actions = const [],
  ]) async {
    final DateTime? autoInsertDate = await transaction(() async {
      var task = await into(userTasks).insertReturning(
        taskInsertable,
        mode: InsertMode.insertOrReplace,
      );

      for (final action in actions) {
        switch (action) {
          case PutTaskInQueue(:final position):
            task = await _putTaskInQueue(position, task);
          case RemoveTaskFromQueue():
            task = task.copyWith(
              status: TaskStatus.pending,
              reference: const Value(null),
            );
          case StartTimeMeasurement(:final reference):
            task = await _startTimeMeasurement(task, reference);
          case StopTimeMeasurement(:final reference):
            task = await _stopTimeMeasurement(task, reference);
          case PutSubTasks():
          case RemoveSubTasks():
          case PutTimeMeasurement():
          case RemoveTimeMeasurement():
        }
      }

      await into(userTasks).insert(
        task,
        mode: InsertMode.insertOrReplace,
      );

      await batch((batch) {
        for (final action in actions) {
          switch (action) {
            case PutSubTasks(:final subTasks):
              batch.insertAllOnConflictUpdate(this.subTasks,
                  subTasks.map((s) => s.copyWith(taskId: Value(task.id))));
            case RemoveSubTasks(subTasksIds: final subTasksIds):
              batch.deleteWhere(
                subTasks,
                (t) => t.id.isIn(subTasksIds),
              );
            case PutTimeMeasurement(:final measurement):
              batch.insert(
                timeMeasurements,
                measurement,
                mode: InsertMode.insertOrReplace,
              );
            case RemoveTimeMeasurement(:final measurement):
              batch.deleteWhere(
                timeMeasurements,
                (t) => t.id.equals(measurement.id),
              );
            case PutTaskInQueue():
            case RemoveTaskFromQueue():
            case StartTimeMeasurement():
            case StopTimeMeasurement():
          }
        }
      });

      return task.autoInsertDate;
    });

    _queuer.tryUpdate(autoInsertDate);
  }

  Future<void> softDeleteTask(UserTask task) async {
    final now = DateTime.now();

    await (update(userTasks)..where((t) => t.id.equals(task.id)))
        .write(UserTasksCompanion(deletedAt: Value(now)));
  }

  Future<void> undoSoftDeleteTask(UserTask task) async {
    await (update(userTasks)..where((t) => t.id.equals(task.id)))
        .write(const UserTasksCompanion(deletedAt: Value(null)));
  }

  Future<void> deleteTask(UserTask task) async {
    await (delete(userTasks)..where((t) => t.id.equals(task.id))).go();
  }

  Future<DateTime?> getNextPendingTaskDate() async {
    final query = selectOnly(userTasks)
      ..addColumns([userTasks.autoInsertDate])
      ..where(userTasks.status.equalsValue(TaskStatus.pending) &
          userTasks.autoInsertDate.isNotNull())
      ..orderBy([OrderingTerm.asc(userTasks.autoInsertDate)]);

    return await query
        .map((row) => row.readWithConverter(userTasks.autoInsertDate))
        .getSingleOrNull();
  }

  Future<DateTime?> addScheduledTasks() async {
    final now = DateTime.now();

    return await transaction(() async {
      // this is not particularly great,
      // but I don't want to manage a separate
      // timer for this
      await deleteSoftDeletedTasks();

      final tasks = await (_selectTasks()
            ..where((t) =>
                t.status.equalsValue(TaskStatus.pending) &
                t.autoInsertDate
                    .isSmallerOrEqualValue(now.millisecondsSinceEpoch))
            ..orderBy([(t) => OrderingTerm.desc(t.autoInsertDate)]))
          .get();

      final firstReference = await (selectOnly(userTasks)
            ..addColumns([userTasks.reference])
            ..where(
              userTasks.deletedAt.isNull() & userTasks.reference.isNotNull(),
            )
            ..orderBy([OrderingTerm.asc(userTasks.reference)])
            ..limit(1))
          .map((row) => row.read(userTasks.reference))
          .getSingleOrNull();

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

      await batch((batch) {
        for (final task in taskIterable) {
          batch.update(
            userTasks,
            UserTasksCompanion(
              id: Value(task.id),
              status: const Value(TaskStatus.active),
              reference: Value(current),
            ),
            where: (t) => t.id.equals(task.id),
          );
          current += increment;
        }
      });

      return await getNextPendingTaskDate();
    });
  }

  Future<void> deleteSoftDeletedTasks() async {
    final now = DateTime.now();
    final threshold =
        now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;

    // delete all tasks that were soft deleted more than an hour ago
    await (delete(userTasks)
          ..where((t) =>
              t.deletedAt.isNotNull() &
              t.deletedAt.isSmallerThanValue(threshold)))
        .go();
  }

  Future<void> reorderTasks(List<UserTask> tasks) async {
    await batch((batch) {
      for (var i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        batch.update(
          userTasks,
          UserTasksCompanion(reference: Value(i * _defaultSkipSize)),
          where: (t) => t.id.equals(task.id),
        );
      }
    });
  }

  // TODO: just filter it on the dart side
  Future<List<UserTask>> searchTasks(
    TaskStatus status,
    String searchText,
  ) async {
    final pattern = '%$searchText%';
    final query = _selectTasks()
      ..where((t) => t.status.equalsValue(status))
      ..where((t) => t.title.like(pattern) | t.description.like(pattern));

    switch (status) {
      case TaskStatus.active:
        query.orderBy([
          (t) => OrderingTerm.asc(t.reference),
        ]);
      case TaskStatus.pending:
        query.orderBy([
          (t) => OrderingTerm.asc(t.createdAt),
        ]);
      case TaskStatus.archived:
        query.orderBy([
          (t) => OrderingTerm.desc(t.updatedByUserAt),
        ]);
    }

    return await query.get();
  }

  Future<UserTask> _putTaskInQueue(
    QueueInsertionPosition position,
    UserTask task,
  ) async {
    final insertAtStart = switch (position) {
      QueueInsertionPosition.start => true,
      QueueInsertionPosition.end => false,
      QueueInsertionPosition.preferred =>
        task.autoInsertDate?.isBefore(DateTime.now()) ?? false,
    };

    final expr =
        insertAtStart ? userTasks.reference.min() : userTasks.reference.max();

    final previousReference = await (selectOnly(userTasks)..addColumns([expr]))
        .map((row) => row.read(expr))
        .getSingle();

    final reference = switch ((previousReference, insertAtStart)) {
      (final r?, true) => r - _defaultSkipSize,
      (final r?, false) => r + _defaultSkipSize,
      (null, _) => 0,
    };

    return task.copyWith(
      status: TaskStatus.active,
      reference: Value(reference),
    );
  }

  Future<UserTask> _startTimeMeasurement(
    UserTask task,
    DateTime now,
  ) async {
    final currentlyActive = await (_selectTasks()
          ..where((t) => t.activeTimeMeasurementStart.isNotNull()))
        .get();

    for (final active in currentlyActive) {
      // stop all other time measurements
      final modifiedActive = await _stopTimeMeasurement(active, now);
      await into(userTasks).insert(
        modifiedActive,
        mode: InsertMode.insertOrReplace,
      );
    }

    return task.copyWith(
      activeTimeMeasurementStart: Value(now),
    );
  }

  /// Needs to be wrapped in a write transaction
  Future<UserTask> _stopTimeMeasurement(
    UserTask task,
    DateTime now,
  ) async {
    if (task.activeTimeMeasurementStart == null) return task;

    await into(timeMeasurements).insert(TimeMeasurementsCompanion.insert(
      taskId: task.id,
      start: task.activeTimeMeasurementStart!,
      end: now,
    ));

    return task.copyWith(
      activeTimeMeasurementStart: const Value(null),
    );
  }
}

class AutomaticTaskQueuer {
  AutomaticTaskQueuer(this.database);

  final AppDatabase database;

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
      final date = await database.addScheduledTasks();
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
