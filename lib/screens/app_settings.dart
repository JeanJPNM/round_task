import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:round_task/provider.dart';

class AppSettings extends ConsumerStatefulWidget {
  const AppSettings({super.key});

  @override
  ConsumerState<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends ConsumerState<AppSettings> {
  Future<String> _getBackupDirectoryPath() async {
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();

    return dir.path;
  }

  Future<bool> _tryAction(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e, stackTrace) {
      FlutterError.presentError(FlutterErrorDetails(
        exception: e,
        stack: stackTrace,
        library: 'Round Task',
      ));
      return false;
    }
  }

  Future<void> _exportData(
    DatabaseNotifier dbNotifier,
    BuildContext context,
  ) async {
    final dir = await _getBackupDirectoryPath();
    final path = join(dir, 'round_task_backup.sqlite');
    final success = await _tryAction(() async {
      await dbNotifier.exportData(path);
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            success ? "export_success" : "export_failed",
            args: [path],
          ),
        ),
      ),
    );
  }

  Future<void> _importData(
    DatabaseNotifier dbNotifier,
    BuildContext context,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null) return;

    final path = result.files.single.path!;
    final success = await _tryAction(() async {
      // Attempt to import the database
      return await dbNotifier.importData(path);
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            success ? "import_success" : "import_failed",
            args: [path],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dbNotifier = ref.watch(databasePod.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr("settings")),
      ),
      body: ListView(
        children: [
          _SectionHeader(title: Text(context.tr("backup_and_restore"))),
          ListTile(
            onTap: () => _exportData(dbNotifier, context),
            leading: const Icon(Icons.upload),
            title: Text(context.tr("export_database")),
          ),
          ListTile(
            onTap: () => _importData(dbNotifier, context),
            leading: const Icon(Icons.download),
            title: Text(context.tr("import_database")),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final Widget title;
  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.titleMedium!,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 16,
          bottom: 16,
          left: 16,
        ),
        child: title,
      ),
    );
  }
}
