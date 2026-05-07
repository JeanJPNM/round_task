import 'package:sqlite3/sqlite3.dart';

import 'bindings.dart' as bindings;

final class BetterTrigram {
  static SqliteExtension load() {
    final initFunctionPtr = bindings.sqlite_better_trigram_get_init();
    return SqliteExtension(initFunctionPtr);
  }
}
