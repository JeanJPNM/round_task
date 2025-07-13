import 'package:duration/duration.dart';
import 'package:duration/locale.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:round_task/db/db.dart';
import 'package:round_task/formatting.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/widgets/bottom_sheet_safe_area.dart';
import 'package:round_task/widgets/date_time_input.dart';
import 'package:round_task/widgets/second_tick_provider.dart';
import 'package:round_task/widgets/time_tracking_banner.dart';

final class TaskTimeMeasurementsParams {
  const TaskTimeMeasurementsParams({required this.task});

  final UserTask task;
}

class TaskTimeMeasurements extends ConsumerStatefulWidget {
  TaskTimeMeasurements({
    super.key,
    required TaskTimeMeasurementsParams params,
  }) : task = params.task;

  final UserTask task;

  @override
  ConsumerState<TaskTimeMeasurements> createState() =>
      _TaskTimeMeasurementsState();
}

class _TaskTimeMeasurementsState extends ConsumerState<TaskTimeMeasurements> {
  Future<void> _putMeasurement(
    AppDatabase database,
    Insertable<TimeMeasurement> measurement,
  ) async {
    await database.writeTask(
      widget.task,
      [PutTimeMeasurement(measurement)],
    );
  }

  Future<void> _removeMeasurement(
    AppDatabase database,
    TimeMeasurement measurement,
  ) async {
    await database.writeTask(
      widget.task,
      [RemoveTimeMeasurement(measurement)],
    );

    if (!mounted) return;

    final languageTag = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.now();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr("measurement_deleted", args: [
            formatDate(languageTag, now, measurement.start),
          ]),
        ),
        action: SnackBarAction(
          label: context.tr("undo"),
          onPressed: () => _putMeasurement(database, measurement),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final measurements = ref.watch(taskTimeMeasurementsPod(task.id));
    final measurementSum = ref.watch(
      taskTimeMeasurementsPod(task.id).select(
        (measurements) => measurements.whenData(
          (data) => data.fold(
            Duration.zero,
            (total, measurement) => total + measurement.duration,
          ),
        ),
      ),
    );
    final database = ref.watch(databasePod);
    final currentlyTrackedTask = ref.watch(currentlyTrackedTaskPod).valueOrNull;

    return TimeTrackingScreenWrapper(
      disabled: currentlyTrackedTask?.id == task.id,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr("task_time_measurements_title")),
          bottom:
              _TotalDurationBanner(task: task, measurementSum: measurementSum),
        ),
        body: measurements.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) => Center(
            child: Text('Error: $error'),
          ),
          data: (measurements) {
            final itemCount = measurements.length;
            final activeStart = widget.task.activeTimeMeasurementStart;
            final totalCount = activeStart != null ? itemCount + 1 : itemCount;

            return ListView.builder(
              reverse: true,
              padding: MediaQuery.paddingOf(context),
              itemCount: totalCount,
              itemBuilder: (context, index) {
                if (index == 0 && activeStart != null) {
                  return _TimeMeasurementItem(start: activeStart, end: null);
                }

                if (activeStart != null) index--;

                final measurement = measurements[index];
                return _TimeMeasurementItem(
                  start: measurement.start,
                  end: measurement.end,
                  onChange: (result) async {
                    switch (result) {
                      case _MeasurementDeleted():
                        await _removeMeasurement(database, measurement);
                        return;
                      case _MeasurementEdited(
                          start: final start,
                          end: final end,
                        ):
                        await _putMeasurement(
                          database,
                          measurement.copyWith(start: start, end: end),
                        );
                    }
                  },
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final now = DateTime.now();
            final result = await _showTimeMeasurementEditor(
              context,
              start: now,
              end: now,
              allowDelete: false,
            );

            if (result case _MeasurementEdited(:final start, :final end)) {
              await _putMeasurement(
                database,
                TimeMeasurementsCompanion.insert(
                  taskId: task.id,
                  start: start,
                  end: end,
                ),
              );
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _TotalDurationBanner extends StatelessWidget
    implements PreferredSizeWidget {
  const _TotalDurationBanner({
    required this.task,
    required this.measurementSum,
  });

  final UserTask task;
  final AsyncValue<Duration> measurementSum;

  @override
  Size get preferredSize => const Size.fromHeight(30);

  @override
  Widget build(BuildContext context) {
    final sum = measurementSum.valueOrNull;
    if (sum == null) return const SizedBox.shrink();

    final Duration total;
    if (task.activeTimeMeasurementStart case final start?) {
      total = sum + DateTime.now().difference(start);
      SecondTickProvider.of(context);
    } else {
      total = sum;
    }

    if (total == Duration.zero) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 16.0, right: 16.0),
        child: Text(
          context.tr("task_time_measurements_total", args: [
            total.pretty(
              locale: DurationLocale.fromLanguageCode(
                    Localizations.localeOf(context).languageCode,
                  ) ??
                  const EnglishDurationLocale(),
              tersity: DurationTersity.second,
              upperTersity: DurationTersity.hour,
              maxUnits: 2,
            ),
          ]),
        ),
      ),
    );
  }
}

class _TimeMeasurementItem extends StatelessWidget {
  const _TimeMeasurementItem({
    required this.start,
    this.end,
    this.onChange,
  });

  final DateTime start;
  final DateTime? end;
  final void Function(_EditorResult)? onChange;

  Future<void> _handleTap(BuildContext context) async {
    final result = await _showTimeMeasurementEditor(context,
        start: start, end: end!, allowDelete: true);
    if (result == null) return;
    onChange?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = this.end == null;
    final locale = Localizations.localeOf(context);
    final now = DateTime.now();
    final end = this.end ?? now;
    if (isRunning) SecondTickProvider.of(context);

    return ListTile(
      selected: isRunning,
      onTap: isRunning || onChange == null ? null : () => _handleTap(context),
      title: Text(
        formatDate(locale.toLanguageTag(), now, start),
      ),
      subtitle: Text(
        end.difference(start).pretty(
              locale: DurationLocale.fromLanguageCode(locale.languageCode) ??
                  const EnglishDurationLocale(),
              tersity: DurationTersity.second,
              upperTersity: DurationTersity.hour,
            ),
      ),
    );
  }
}

sealed class _EditorResult {
  const _EditorResult();
}

class _MeasurementEdited extends _EditorResult {
  const _MeasurementEdited(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

class _MeasurementDeleted extends _EditorResult {
  const _MeasurementDeleted();
}

Future<_EditorResult?> _showTimeMeasurementEditor(
  BuildContext context, {
  required DateTime start,
  required DateTime end,
  bool allowDelete = false,
}) async {
  return await showModalBottomSheet<_EditorResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => BottomSheetSafeArea(
      basePadding: const EdgeInsets.all(16),
      child: _TimeMeasurementEditor(
        start: start,
        end: end,
        allowDelete: allowDelete,
      ),
    ),
  );
}

class _TimeMeasurementEditor extends StatefulWidget {
  const _TimeMeasurementEditor({
    required this.start,
    required this.end,
    this.allowDelete = true,
  });

  final DateTime start;
  final DateTime end;
  final bool allowDelete;
  @override
  State<_TimeMeasurementEditor> createState() => __TimeMeasurementEditorState();
}

class __TimeMeasurementEditorState extends State<_TimeMeasurementEditor> {
  final startController = DateTimeEditingController();
  final endController = DateTimeEditingController();
  final isValid = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();

    startController.addListener(_runValidation);
    endController.addListener(_runValidation);

    startController.value = widget.start;
    endController.value = widget.end;
  }

  void _runValidation() {
    final start = startController.value;
    final end = endController.value;

    if (start == null || end == null) {
      isValid.value = false;
      return;
    }

    isValid.value = start.isBefore(end);
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.allowDelete)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  Navigator.of(context).pop(const _MeasurementDeleted());
                },
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr("measurement_start_time")),
              DateTimeInput(
                allowDelete: false,
                controller: startController,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr("measurement_end_time")),
              DateTimeInput(
                allowDelete: false,
                controller: endController,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(context.tr("cancel")),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: isValid,
                builder: (context, valid, child) {
                  return FilledButton(
                    onPressed: valid
                        ? () {
                            final start = startController.value!;
                            final end = endController.value!;
                            final result = _MeasurementEdited(start, end);
                            Navigator.of(context).pop(result);
                          }
                        : null,
                    child: Text(context.tr("ok")),
                  );
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
