import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color;
import 'package:round_task/db/database.steps.dart';
import 'package:rrule/rrule.dart';

part 'database.g.dart';

const _defaultSkipSize = 256;

mixin DatabaseEnum on Enum {
  int get dbCode;
}

enum TaskStatus with DatabaseEnum {
  active(0),
  pending(1),
  archived(2);

  @override
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

class CodeEnumConverter<T extends DatabaseEnum> extends TypeConverter<T, int> {
  const CodeEnumConverter(this.fromDb);

  final T Function(int) fromDb;

  @override
  T fromSql(int code) => fromDb(code);

  @override
  int toSql(T value) => value.dbCode;
}

class ColorConverter extends TypeConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromSql(int value) => Color(value);

  @override
  int toSql(Color color) => color.toARGB32();
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
  late final status = integer().map(
    const CodeEnumConverter(TaskStatus.fromDbCode),
  )();
  late final reference = integer().nullable()();
  late final progress = real().nullable()();
  late final createdAt = integer().map(const DateTimeConverter())();
  late final updatedByUserAt = integer().map(const DateTimeConverter())();
  late final deletedAt = integer().map(const DateTimeConverter()).nullable()();
  late final startDate = integer().map(const DateTimeConverter()).nullable()();
  late final endDate = integer().map(const DateTimeConverter()).nullable()();
  late final autoInsertDate = integer()
      .map(const DateTimeConverter())
      .nullable()
      .generatedAs(
        coalesce([
          startDate,
          endDate - Constant(const Duration(days: 1).inMilliseconds),
        ]),
        stored: true,
      )();
  late final activeTimeMeasurementStart = integer()
      .map(const DateTimeConverter())
      .nullable()();

  late final recurrence = text()
      .map(const RecurrenceRuleConverter())
      .nullable()();
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
@TableIndex(name: "idx_time_measurements_start", columns: {#start})
@TableIndex(name: "idx_time_measurements_end", columns: {#end})
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

typedef TitledTimeMeasurement = ({String title, TimeMeasurement measurement});

enum AppBrightness with DatabaseEnum {
  system(0),
  light(1),
  dark(2);

  const AppBrightness(this.dbCode);

  @override
  final int dbCode;

  factory AppBrightness.fromDbCode(int code) {
    return values.firstWhere(
      (e) => e.dbCode == code,
      orElse: () => AppBrightness.system,
    );
  }
}

@DataClassName("AppSettings")
class AppSettingsTable extends Table {
  late final id = integer().autoIncrement()();

  late final brightness = integer().map(
    const CodeEnumConverter(AppBrightness.fromDbCode),
  )();

  late final seedColor = integer().map(const ColorConverter()).nullable()();
}

enum QueueInsertionPosition { start, end, preferred }

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

class SoftDeleteTask extends TaskEditAction {
  const SoftDeleteTask(this.deletedAt);
  final DateTime deletedAt;
}

class UndoSoftDeleteTask extends TaskEditAction {
  const UndoSoftDeleteTask();
}

class PutSubTasks extends TaskEditAction {
  PutSubTasks(this.subTasks);

  final List<SubTasksCompanion> subTasks;
}

class RemoveSubTasks extends TaskEditAction {
  RemoveSubTasks(this.subTasksIds);

  final List<int> subTasksIds;
}

class RestoreSubTasks extends TaskEditAction {
  const RestoreSubTasks(this.originalSubTasks);

  final List<SubTask> originalSubTasks;
}

class StartTimeMeasurement extends TaskEditAction {
  const StartTimeMeasurement(this.reference);
  final DateTime reference;
}

class StopTimeMeasurement extends TaskEditAction {
  const StopTimeMeasurement(this.reference);
  final DateTime reference;
}

class UndoStopTimeMeasurement extends TaskEditAction {
  const UndoStopTimeMeasurement(this.originalStart);

  final DateTime originalStart;
}

class PutTimeMeasurement extends TaskEditAction {
  PutTimeMeasurement(this.measurement);

  final Insertable<TimeMeasurement> measurement;
}

class RemoveTimeMeasurement extends TaskEditAction {
  RemoveTimeMeasurement(this.measurement);

  final TimeMeasurement measurement;
}

@DriftDatabase(
  tables: [UserTasks, SubTasks, TimeMeasurements, AppSettingsTable],
)
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase(super.e);

  late final AutomaticTaskQueuer _queuer = AutomaticTaskQueuer(this);

  static const _defaultSettings = AppSettings(
    id: 0,
    brightness: AppBrightness.system,
    seedColor: null,
  );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
      onUpgrade: stepByStep(
        from1To2: (m, schema) async {
          await m.createIndex(schema.idxTimeMeasurementsStart);
          await m.createIndex(schema.idxTimeMeasurementsEnd);
          await m.createTable(schema.appSettingsTable);
        },
      ),
    );
  }

  @override
  Future<void> close() {
    _queuer.dispose();
    return super.close();
  }

  Future<void> init() async {
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

  Stream<List<UserTask>> getSoftDeletedTasksStream() async* {
    yield* (select(userTasks)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .watch();
  }

  Stream<UserTask?> getCurrentlyTrackedTaskStream() async* {
    yield* (_selectTasks()
          ..where((t) => t.activeTimeMeasurementStart.isNotNull())
          ..limit(1))
        .watchSingleOrNull();
  }

  SingleOrNullSelectable<UserTask> getTaskById(int taskId) {
    return (select(userTasks)..where((t) => t.id.equals(taskId)));
  }

  MultiSelectable<SubTask> getSubTasks(int taskId) {
    return (select(subTasks)
      ..where((s) => s.taskId.equals(taskId))
      ..orderBy([(t) => OrderingTerm.asc(t.reference)]));
  }

  MultiSelectable<TimeMeasurement> getTaskTimeMeasurements(int taskId) {
    return (select(timeMeasurements)
      ..where((t) => t.taskId.equals(taskId))
      ..orderBy([(t) => OrderingTerm.desc(t.start)]));
  }

  MultiSelectable<TitledTimeMeasurement> getAllTimeMeasurements({
    DateTime? after,
    DateTime? before,
  }) {
    final query = select(timeMeasurements).join([
      innerJoin(
        userTasks,
        timeMeasurements.taskId.equalsExp(userTasks.id),
        useColumns: false,
      ),
    ]);
    query.addColumns([userTasks.title]);

    query.where(userTasks.deletedAt.isNull());

    if (after != null) {
      query.where(
        timeMeasurements.start.isSmallerOrEqualValue(
          after.millisecondsSinceEpoch,
        ),
      );
    }
    if (before != null) {
      query.where(
        timeMeasurements.end.isSmallerOrEqualValue(
          before.millisecondsSinceEpoch,
        ),
      );
    }
    query.orderBy([OrderingTerm.asc(timeMeasurements.start)]);

    return query.map<TitledTimeMeasurement>((row) {
      final measurement = row.readTable(timeMeasurements);
      final title = row.read(userTasks.title)!;
      return (title: title, measurement: measurement);
    });
  }

  Stream<AppSettings> getAppSettings() {
    return (select(appSettingsTable)..limit(1)).watchSingleOrNull().map(
      (settings) => settings ?? _defaultSettings,
    );
  }

  Future<void> saveAppSettings(AppSettingsTableCompanion settings) async {
    final existing = await (select(
      appSettingsTable,
    )..limit(1)).getSingleOrNull();

    if (existing == null) {
      await into(
        appSettingsTable,
      ).insert(_defaultSettings.copyWithCompanion(settings));
    } else {
      await (update(
        appSettingsTable,
      )..whereSamePrimaryKey(existing)).write(settings);
    }
  }

  Future<UserTask> writeTask(
    Insertable<UserTask> taskInsertable, [
    List<TaskEditAction> actions = const [],
  ]) async {
    final UserTask task = await transaction(() async {
      var task = await into(userTasks).insertReturning(
        taskInsertable,
        onConflict: DoUpdate(
          (_) => switch (taskInsertable) {
            UserTask task => task.toCompanion(false),
            _ => taskInsertable,
          },
        ),
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
          case SoftDeleteTask(:final deletedAt):
            task = task.copyWith(deletedAt: Value(deletedAt));
          case UndoSoftDeleteTask():
            task = task.copyWith(deletedAt: const Value(null));
          case StartTimeMeasurement(:final reference):
            task = await _startTimeMeasurement(task, reference);
          case StopTimeMeasurement(:final reference):
            task = await _stopTimeMeasurement(task, reference);
          case UndoStopTimeMeasurement(originalStart: final reference):
            task = await _undoStopTimeMeasurement(task, reference);
          case PutSubTasks():
          case RemoveSubTasks():
          case RestoreSubTasks():
          case PutTimeMeasurement():
          case RemoveTimeMeasurement():
        }
      }

      await update(userTasks).replace(task);

      await batch((batch) {
        for (final action in actions) {
          switch (action) {
            case PutSubTasks(:final subTasks):
              final taskId = Value(task.id);
              batch.insertAllOnConflictUpdate(
                this.subTasks,
                subTasks.map((s) => s.copyWith(taskId: taskId)),
              );
            case RemoveSubTasks(subTasksIds: final subTasksIds):
              batch.deleteWhere(subTasks, (t) => t.id.isIn(subTasksIds));
            case RestoreSubTasks(:final originalSubTasks):
              batch.deleteWhere(subTasks, (t) => t.taskId.equals(task.id));
              batch.insertAll(subTasks, originalSubTasks);

            case PutTimeMeasurement(:final measurement):
              final data = switch (measurement) {
                TimeMeasurementsCompanion c => c.copyWith(
                  taskId: Value(task.id),
                ),
                final m => m,
              };
              batch.insert(
                timeMeasurements,
                data,
                onConflict: DoUpdate((_) => data),
              );
            case RemoveTimeMeasurement(:final measurement):
              batch.deleteWhere(
                timeMeasurements,
                (t) => t.id.equals(measurement.id),
              );
            case PutTaskInQueue():
            case RemoveTaskFromQueue():
            case SoftDeleteTask():
            case UndoSoftDeleteTask():
            case StartTimeMeasurement():
            case StopTimeMeasurement():
            case UndoStopTimeMeasurement():
          }
        }
      });

      return task;
    });

    _queuer.tryUpdate(task.autoInsertDate);

    return task;
  }

  Future<void> deleteTask(UserTask task) async {
    await (delete(userTasks)..whereSamePrimaryKey(task)).go();
  }

  Future<void> clearSoftDeletedTasks() async {
    await (delete(userTasks)..where((t) => t.deletedAt.isNotNull())).go();
  }

  Future<DateTime?> getNextPendingTaskDate() async {
    final query = selectOnly(userTasks)
      ..addColumns([userTasks.autoInsertDate])
      ..where(
        userTasks.status.equalsValue(TaskStatus.pending) &
            userTasks.autoInsertDate.isNotNull(),
      )
      ..limit(1)
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

      final tasks =
          await (_selectTasks()
                ..where(
                  (t) =>
                      t.status.equalsValue(TaskStatus.pending) &
                      t.autoInsertDate.isSmallerOrEqualValue(
                        now.millisecondsSinceEpoch,
                      ),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.autoInsertDate)]))
              .get();

      final firstReference =
          await (selectOnly(userTasks)
                ..addColumns([userTasks.reference])
                ..where(
                  userTasks.deletedAt.isNull() &
                      userTasks.reference.isNotNull(),
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
    final threshold = now
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;

    // delete all tasks that were soft deleted more than an hour ago
    await (delete(userTasks)..where(
          (t) =>
              t.deletedAt.isNotNull() &
              t.deletedAt.isSmallerThanValue(threshold),
        ))
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
  MultiSelectable<UserTask> searchTasks(TaskStatus status, String searchText) {
    final pattern = '%$searchText%';
    final query = _selectTasks()
      ..where((t) => t.status.equalsValue(status))
      ..where((t) => t.title.like(pattern) | t.description.like(pattern));

    switch (status) {
      case TaskStatus.active:
        query.orderBy([(t) => OrderingTerm.asc(t.reference)]);
      case TaskStatus.pending:
        query.orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
      case TaskStatus.archived:
        query.orderBy([(t) => OrderingTerm.desc(t.updatedByUserAt)]);
    }

    return query;
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

    final expr = insertAtStart
        ? userTasks.reference.min()
        : userTasks.reference.max();

    final previousReference = await (selectOnly(
      userTasks,
    )..addColumns([expr])).map((row) => row.read(expr)).getSingle();

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

  Future<void> _stopAllTimeMeasurements(DateTime now) async {
    final currentlyActive =
        await (_selectTasks()
              ..where((t) => t.activeTimeMeasurementStart.isNotNull()))
            .get();

    for (final active in currentlyActive) {
      final modifiedActive = await _stopTimeMeasurement(active, now);
      await update(userTasks).replace(modifiedActive);
    }
  }

  Future<UserTask> _startTimeMeasurement(UserTask task, DateTime now) async {
    await _stopAllTimeMeasurements(now);

    return task.copyWith(activeTimeMeasurementStart: Value(now));
  }

  /// Needs to be wrapped in a write transaction
  Future<UserTask> _stopTimeMeasurement(UserTask task, DateTime now) async {
    if (task.activeTimeMeasurementStart == null) return task;

    await into(timeMeasurements).insert(
      TimeMeasurementsCompanion.insert(
        taskId: task.id,
        start: task.activeTimeMeasurementStart!,
        end: now,
      ),
    );

    return task.copyWith(activeTimeMeasurementStart: const Value(null));
  }

  Future<UserTask> _undoStopTimeMeasurement(
    UserTask task,
    DateTime reference,
  ) async {
    await _stopAllTimeMeasurements(DateTime.now());

    await (delete(
      timeMeasurements,
    )..where((t) => t.start.equalsValue(reference))).go();

    return task.copyWith(activeTimeMeasurementStart: Value(reference));
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
