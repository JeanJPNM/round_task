import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:rrule/rrule.dart';

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

@immutable
final class TaskPriority {
  final bool important;
  final bool urgent;

  const TaskPriority({required this.important, required this.urgent});

  factory TaskPriority.fromRank(int rank) => switch (rank) {
    0 => const TaskPriority(important: true, urgent: true),
    1 => const TaskPriority(important: true, urgent: false),
    2 => const TaskPriority(important: false, urgent: true),
    _ => const TaskPriority(important: false, urgent: false),
  };

  int get rank {
    return switch (important) {
      true => urgent ? 0 : 1,
      false => urgent ? 2 : 3,
    };
  }

  TaskPriority copyWith({bool? important, bool? urgent}) {
    return TaskPriority(
      important: important ?? this.important,
      urgent: urgent ?? this.urgent,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TaskPriority &&
        other.important == important &&
        other.urgent == urgent;
  }

  @override
  int get hashCode => Object.hash(important, urgent);
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

class TaskPriorityConverter extends TypeConverter<TaskPriority, int> {
  const TaskPriorityConverter();

  @override
  TaskPriority fromSql(int fromDb) {
    return TaskPriority.fromRank(fromDb);
  }

  @override
  int toSql(TaskPriority value) {
    return value.rank;
  }
}
