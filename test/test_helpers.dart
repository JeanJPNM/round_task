import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:round_task/db/types.dart';
import 'package:rrule/rrule.dart';

Matcher equalsDate(DateTime expected) {
  return predicate((arg) {
    if (arg is! DateTime) return false;
    return arg.difference(expected).inMilliseconds.abs() < 1;
  }, 'is close to $expected');
}

extension DateTimeToSql on DateTime {
  int toSql() => const DateTimeConverter().toSql(this);
}

extension RecurrenceRuleToSql on RecurrenceRule {
  String? toSql() => const RecurrenceRuleConverter().toSql(this);
}

extension TaskStatusToSql on TaskStatus {
  int toSql() => const CodeEnumConverter(TaskStatus.fromDbCode).toSql(this);
}

extension TaskPriorityToSql on TaskPriority {
  int toSql() => const TaskPriorityConverter().toSql(this);
}

extension AppBrightnessToSql on AppBrightness {
  int toSql() => const CodeEnumConverter(AppBrightness.fromDbCode).toSql(this);
}

extension ColorToSql on Color {
  int toSql() => const ColorConverter().toSql(this);
}
