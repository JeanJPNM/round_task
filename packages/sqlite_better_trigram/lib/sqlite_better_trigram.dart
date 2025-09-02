import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const String _libName = 'sqlite_better_trigram';

final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final class BetterTrigram {
  static SqliteExtension _getExtension(DynamicLibrary lib) {
    var symbol = "sqlite3_bettertrigram_init";
    if (!lib.providesSymbol(symbol)) {
      symbol = "sqlite3Fts5BetterTrigramInit";
    }
    if (!lib.providesSymbol(symbol)) {
      throw Exception(
        "Could not find symbol 'sqlite3_bettertrigram_init' or 'sqlite3Fts5BetterTrigramInit' in dynamic library",
      );
    }

    return SqliteExtension.inLibrary(lib, symbol);
  }

  static SqliteExtension load() {
    return _getExtension(_dylib);
  }

  /// Uses the provided [lib] to load the extension instead
  /// of the default dynamic library.
  ///
  /// Used in the testing environment.
  static SqliteExtension fromLib(DynamicLibrary lib) {
    return _getExtension(lib);
  }
}
