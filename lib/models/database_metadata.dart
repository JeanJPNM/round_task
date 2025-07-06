import 'package:isar/isar.dart';

part 'database_metadata.g.dart';

@collection
class DatabaseMetadata {
  const DatabaseMetadata({
    this.id = Isar.autoIncrement,
    this.version = DatabaseMetadata.currentVersion,
  });

  static const currentVersion = 1;

  final Id id;
  final int version;
}
