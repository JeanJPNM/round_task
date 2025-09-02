import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_better_trigram/sqlite_better_trigram.dart';

Matcher equalsDate(DateTime expected) {
  return predicate((arg) {
    if (arg is! DateTime) return false;
    return arg.difference(expected).inMilliseconds.abs() < 1;
  }, 'is close to $expected');
}

SqliteExtension loadBetterTrigramForTest() {
  try {
    final path = Directory.current.path;

    if (Platform.isLinux) {
      final lib = DynamicLibrary.open(
        "$path/build/linux/x64/release/bundle/libsqlite_better_trigram.so",
      );
      return BetterTrigram.fromLib(lib);
    }

    if (Platform.isWindows) {
      final lib = DynamicLibrary.open(
        "$path/build/windows/x64/runner/Release/sqlite_better_trigram.dll",
      );
      return BetterTrigram.fromLib(lib);
    }

    throw UnimplementedError(
      'sqlite_better_trigram only has workarounds for Linux and Windows at the moment.',
    );
  } on ArgumentError catch (e) {
    throw StateError(
      'Could not load the sqlite_better_trigram dynamic library. Did you build the app? Error: $e',
    );
  }
}
