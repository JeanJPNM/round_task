export './database.dart';
export "package:drift/drift.dart" show Value, Insertable;

DateTime? autoInsertDateOf(DateTime? startDate, DateTime? endDate) {
  return startDate ?? endDate?.subtract(const Duration(days: 1));
}
