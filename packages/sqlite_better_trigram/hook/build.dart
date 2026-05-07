import 'dart:io';

import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:logging/logging.dart';
import 'package:hooks/hooks.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      final packageName = input.packageName;

      final amalgamationDir = Directory.fromUri(
        input.outputDirectory.resolve("amalgamation"),
      );

      await getSqliteAmalgamationHeaders(
        "https://sqlite.org/2025/sqlite-amalgamation-3500400.zip",
        amalgamationDir,
      );

      final cbuilder = CBuilder.library(
        name: packageName,
        assetName: 'bindings.dart',
        sources: ['src/$packageName.c', 'src/better-trigram.c'],
        includes: [amalgamationDir.path],
      );
      await cbuilder.run(
        input: input,
        output: output,
        logger: Logger('')
          ..level = .ALL
          ..onRecord.listen((record) => print(record.message)),
      );
    }
  });
}

Future<void> getSqliteAmalgamationHeaders(
  String url,
  Directory outputDir,
) async {
  Uri uri = Uri.parse(url);

  final response = await http.get(uri);

  if (response.statusCode != 200) {
    throw StateError(
      'Failed to download the sqlite amalgamation zip. Status code: ${response.statusCode}',
    );
  }

  final archive = ZipDecoder().decodeBytes(response.bodyBytes);

  for (final entry in archive) {
    if (!entry.isFile || !entry.name.endsWith('.h')) continue;
    final file = File(p.join(outputDir.path, p.basename(entry.name)));

    if (file.existsSync() && file.lastModifiedSync() == entry.lastModDateTime) {
      continue;
    }

    final bytes = entry.readBytes();
    if (bytes == null) continue;

    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    await file.setLastModified(entry.lastModDateTime);
  }
}
