import 'package:collection/collection.dart';
import 'package:duration/duration.dart';
import 'package:duration/locale.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:round_task/formatting.dart';
import 'package:round_task/models/task.dart';
import 'package:round_task/models/time_measurement.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/widgets/bottom_sheet_safe_area.dart';
import 'package:round_task/widgets/date_time_input.dart';
import 'package:round_task/widgets/second_tick_provider.dart';
import 'package:round_task/widgets/time_tracking_banner.dart';

final _measurementsProvider =
    FutureProvider.autoDispose.family<List<TimeMeasurement>, UserTask>(
  (ref, task) async {
    await task.timeMeasurements.load();
    return task.timeMeasurements
        .sorted((a, b) => -a.startTime.compareTo(b.startTime));
  },
);

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
    Repository repository,
    TimeMeasurement measurement,
  ) async {
    await repository.writeTask(
      widget.task,
      [PutTimeMeasurement(measurement)],
    );
    if (!mounted) return;

    ref.invalidate(_measurementsProvider(widget.task));
  }

  Future<void> _removeMeasurement(
    Repository repository,
    TimeMeasurement measurement,
  ) async {
    await repository.writeTask(
      widget.task,
      [RemoveTimeMeasurement(measurement)],
    );

    if (!mounted) return;

    ref.invalidate(_measurementsProvider(widget.task));

    final languageTag = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.now();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr("measurement_deleted", args: [
            formatDate(languageTag, now, measurement.startTime),
          ]),
        ),
        action: SnackBarAction(
          label: context.tr("undo"),
          onPressed: () => _putMeasurement(repository, measurement),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final measurements = ref.watch(_measurementsProvider(task));
    final repository = ref.watch(repositoryPod);
    final currentlyTrackedTask = ref.watch(currentlyTrackedTaskPod).valueOrNull;

    return TimeTrackingScreenWrapper(
      disabled: currentlyTrackedTask?.id == task.id,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr("task_time_measurements_title")),
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
                  start: measurement.startTime,
                  end: measurement.endTime,
                  onChange: (result) async {
                    switch (result) {
                      case _MeasurementDeleted():
                        await _removeMeasurement(repository, measurement);
                        return;
                      case _MeasurementEdited(
                          start: final start,
                          end: final end,
                        ):
                        final updatedMeasurement = TimeMeasurement(
                          id: measurement.id,
                          startTime: start,
                          endTime: end,
                        );
                        await _putMeasurement(repository, updatedMeasurement);
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
              startTime: now,
              endTime: now,
              allowDelete: false,
            );

            if (result
                case _MeasurementEdited(
                  start: final start,
                  end: final end,
                )) {
              await _putMeasurement(
                repository,
                TimeMeasurement(
                  startTime: start,
                  endTime: end,
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
        startTime: start, endTime: end!, allowDelete: true);
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
  required DateTime startTime,
  required DateTime endTime,
  bool allowDelete = false,
}) async {
  return await showModalBottomSheet<_EditorResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => BottomSheetSafeArea(
      basePadding: const EdgeInsets.all(16),
      child: _TimeMeasurementEditor(
        startTime: startTime,
        endTime: endTime,
        allowDelete: allowDelete,
      ),
    ),
  );
}

class _TimeMeasurementEditor extends StatefulWidget {
  const _TimeMeasurementEditor({
    required this.startTime,
    required this.endTime,
    this.allowDelete = true,
  });

  final DateTime startTime;
  final DateTime endTime;
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

    startController.value = widget.startTime;
    endController.value = widget.endTime;
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
