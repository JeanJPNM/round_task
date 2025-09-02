import 'package:drift/drift.dart';
import 'package:round_task/db/types.dart';

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

  late final priority = integer()
      .map(const TaskPriorityConverter())
      // this is unlikely to ever change on the dart
      // side of the code, but I still don't like hardcoding the
      // constant value
      .withDefault(const Constant(3))();
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

@DataClassName("AppSettings")
class AppSettingsTable extends Table {
  late final id = integer().autoIncrement()();

  late final brightness = integer().map(
    const CodeEnumConverter(AppBrightness.fromDbCode),
  )();

  late final seedColor = integer().map(const ColorConverter()).nullable()();
}
