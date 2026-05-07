// ignore_for_file: type=lint, unused_import
import 'dart:ffi' as ffi;

@ffi.Native<ffi.Pointer<ffi.Void> Function()>()
external ffi.Pointer<ffi.Void> sqlite_better_trigram_get_init();
