# sqlite_better_trigram

A Dart FFI package project that loads the [better-trigram extension](https://github.com/streetwriters/sqlite-better-trigram) to use with [sqlite3](https://pub.dev/packages/sqlite3).

This plugin contains modified copies of the files from the original repo to fix a few compiler warnings.

This plugin also contains a copy of fts5_unicode2.c (which better-trigram depends on) from sqlite to avoid havin g to download sqlite's whole source code instead of just the amalgamation headers.
