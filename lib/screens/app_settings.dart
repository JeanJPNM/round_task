import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:round_task/db/db.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/widgets/app_drawer.dart';
import 'package:round_task/widgets/bottom_sheet_safe_area.dart';
import 'package:round_task/widgets/select_dropdown.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _AppSettingsState();
}

class _AppSettingsState extends ConsumerState<SettingsScreen> {
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
    final dir = await getDownloadDirectory();
    final now = DateTime.now();
    final suffix = DateFormat('yyyy-MM-dd-HH-mm-ss').format(now);
    final path = join(dir.path, 'round-task-$suffix.sqlite');
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

    final file = result.files.single;
    final success = await _tryAction(() async {
      // Attempt to import the database
      return await dbNotifier.importData(file.path!);
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            success ? "import_success" : "import_failed",
            args: [file.name],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databasePod);
    final dbNotifier = ref.watch(databasePod.notifier);
    final settings = ref.watch(appSettingsPod);

    return Scaffold(
      appBar: AppBar(
        leading: const AppDrawerButton(),
        title: Text(context.tr("settings")),
      ),
      body: settings.when(
        error: (error, stackTrace) {
          FlutterError.presentError(FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Round Task',
          ));
          return Center(child: Text(context.tr("error_loading_settings")));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        data: (settings) {
          return ListView(
            children: [
              _SectionHeader(title: Text(context.tr("appearance"))),
              ListTile(
                leading: const Icon(Icons.palette),
                title: Text(context.tr("accent_color")),
                onTap: () async {
                  final color = await showColorPickerBottomSheet(
                    context,
                    initialColor: settings.seedColor ?? Colors.deepPurple,
                    useSystemColor: settings.seedColor == null,
                  );
                  if (color == null) return;
                  await database.saveAppSettings(
                    AppSettingsTableCompanion(seedColor: color),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: Text(context.tr("theme_mode.name")),
                trailing: SelectDropdown(
                  value: settings.brightness,
                  items: [
                    DropdownMenuItem(
                      value: AppBrightness.system,
                      child: Text(context.tr("theme_mode.system")),
                    ),
                    DropdownMenuItem(
                      value: AppBrightness.light,
                      child: Text(context.tr("theme_mode.light")),
                    ),
                    DropdownMenuItem(
                      value: AppBrightness.dark,
                      child: Text(context.tr("theme_mode.dark")),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    database.saveAppSettings(
                      AppSettingsTableCompanion(brightness: Value(value)),
                    );
                  },
                ),
              ),
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
          );
        },
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

Future<Value<Color?>?> showColorPickerBottomSheet(
  BuildContext context, {
  required Color initialColor,
  bool useSystemColor = false,
}) {
  return showModalBottomSheet<Value<Color?>>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return BottomSheetSafeArea(
        basePadding: const EdgeInsets.all(16),
        child: _ColorPickerBottomSheet(
          initialColor: initialColor,
          useSystemColor: useSystemColor,
        ),
      );
    },
  );
}

class _ColorPickerBottomSheet extends StatefulWidget {
  const _ColorPickerBottomSheet({
    required this.initialColor,
    this.useSystemColor = false,
  });

  final Color initialColor;
  final bool useSystemColor;
  @override
  State<_ColorPickerBottomSheet> createState() =>
      _ColorPickerBottomSheetState();
}

class _ColorPickerBottomSheetState extends State<_ColorPickerBottomSheet> {
  bool useSystemColor = false;
  Color selectedColor = Colors.white;

  @override
  void initState() {
    super.initState();
    useSystemColor = widget.useSystemColor;
    selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          title: Text(context.tr("use_system_accent_color")),
          value: useSystemColor,
          onChanged: (value) {
            setState(() {
              useSystemColor = value;
            });
          },
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: useSystemColor ? 0.6 : 1.0,
          child: ColorPicker(
            color: selectedColor,
            onColorChanged: (color) {
              setState(() {
                useSystemColor = false;
                selectedColor = color;
              });
            },
            enableOpacity: false,
            borderRadius: 12,
            columnSpacing: 16,
            pickersEnabled: {
              ColorPickerType.primary: true,
              ColorPickerType.accent: false,
              ColorPickerType.bw: false,
              ColorPickerType.wheel: true
            },
            pickerTypeLabels: {
              ColorPickerType.primary: context.tr("color_picker.primary"),
              ColorPickerType.wheel: context.tr("color_picker.wheel"),
            },
          ),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(context.tr("cancel")),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  useSystemColor ? const Value(null) : Value(selectedColor),
                );
              },
              child: Text(context.tr("done")),
            ),
          ],
        ),
      ],
    );
  }
}
