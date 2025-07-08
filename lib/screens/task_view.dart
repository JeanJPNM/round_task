import 'dart:async';

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:round_task/custom_colors.dart';
import 'package:round_task/formatting.dart';
import 'package:round_task/models/task.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/screens/task_time_measurements.dart';
import 'package:round_task/widgets/bottom_sheet_safe_area.dart';
import 'package:round_task/widgets/date_time_input.dart';
import 'package:round_task/widgets/recurrence_picker.dart';
import 'package:round_task/widgets/second_tick_provider.dart';
import 'package:round_task/widgets/sliver_material_reorderable_list.dart';
import 'package:round_task/widgets/time_tracking_banner.dart';
import 'package:rrule/rrule.dart';

class TaskViewParams {
  TaskViewParams(
    this.task, {
    this.addToQueue = false,
    this.autofocusTitle = false,
  });

  final UserTask task;
  final bool addToQueue;
  final bool autofocusTitle;
}

class TaskViewScreen extends ConsumerStatefulWidget {
  TaskViewScreen({super.key, required TaskViewParams params})
      : task = params.task,
        addToQueue = params.addToQueue,
        focusTitle = params.autofocusTitle;

  final bool addToQueue;
  final bool focusTitle;
  final UserTask task;

  @override
  ConsumerState<TaskViewScreen> createState() => _TaskViewScreenState();
}

class _TaskViewScreenState extends ConsumerState<TaskViewScreen> {
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final scrollController = ScrollController();
  final titleController = TextEditingController(),
      descriptionController = TextEditingController();
  final titleFocusNode = FocusNode();
  final descriptionFocusNode = FocusNode();

  final startDateController = DateTimeEditingController();
  final endDateController = DateTimeEditingController();
  final autoInserDateController = ValueNotifier<DateTime?>(null);

  final positionController = ValueNotifier<QueueInsertionPosition?>(null);
  bool lockTaskInQueue = false;

  late final List<SubTask> _originalSubTasks;
  late ScaffoldMessengerState parentScaffoldMessenger;
  ScaffoldMessengerState get childScaffoldMessenger =>
      scaffoldMessengerKey.currentState!;
  List<_SubTaskController> _subTaskControllers = const [];

  RecurrenceRule? recurrenceRule;
  @override
  void initState() {
    super.initState();

    final task = widget.task;
    _originalSubTasks = task.subTasks.sortedBy<num>((a) => a.reference);

    titleController.text = task.title;
    descriptionController.text = task.description;
    startDateController.value = task.startDate;
    endDateController.value = task.endDate;
    autoInserDateController.value = task.autoInsertDate;
    recurrenceRule = task.recurrence;
    positionController.value = task.reference != null || widget.addToQueue
        ? QueueInsertionPosition.preferred
        : null;
    lockTaskInQueue = task.autoInsertDate?.isBefore(DateTime.now()) ?? false;

    _subTaskControllers = _originalSubTasks
        .map((subTask) => _SubTaskController(subTask))
        .toList();

    startDateController.addListener(() {
      autoInserDateController.value = UserTask.getAutoInsertDate(
        startDateController.value,
        endDateController.value,
      );

      final value = startDateController.value;
      final previous = startDateController.previous;
      final endDate = endDateController.value;

      if (value == null || previous == null || endDate == null) return;

      final duration = endDate.difference(previous);

      endDateController.value = value.add(duration);
    });
    endDateController.addListener(() {
      final value = endDateController.value;
      autoInserDateController.value = UserTask.getAutoInsertDate(
        startDateController.value,
        value,
      );
      if (value == null) return;
      if (startDateController.value != null) return;

      startDateController.value = DateTime(value.year, value.month, value.day);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    parentScaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    scrollController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    titleFocusNode.dispose();
    descriptionFocusNode.dispose();
    startDateController.dispose();
    endDateController.dispose();
    autoInserDateController.dispose();
    positionController.dispose();

    for (final controller in _subTaskControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _applyChanges() {
    final task = widget.task;
    task.title = titleController.text.trim();
    task.description = descriptionController.text.trim();
    task.startDate = startDateController.value;
    task.endDate = endDateController.value;
    task.recurrence = recurrenceRule;
    task.lastTouched = DateTime.now();

    if (task.archived && task.autoInsertDate != null) {
      task.archived = false;
    }

    for (final controller in _subTaskControllers) {
      controller.apply();
    }
  }

  ({List<SubTask> put, List<SubTask> remove}) _updateSubTasks() {
    final task = widget.task;
    final removedSubTasks = _subTaskControllers
        .where((controller) => controller.removed)
        .map((controller) => controller.subTask)
        .where((subTask) => subTask.id != Isar.autoIncrement)
        .toList();

    final subTasks = _subTaskControllers
        .whereNot((controller) => controller.removed)
        .map((controller) => controller.subTask)
        .toList();

    for (final (i, subTask) in subTasks.indexed) {
      subTask.reference = i;
    }

    task.subTasks.removeAll(removedSubTasks);
    task.subTasks.addAll(subTasks);
    return (put: subTasks, remove: removedSubTasks);
  }

  // Future<void> _restoreTask(Repository repository) async {
  //   final task = widget.task;

  //   task.subTasks.clear();
  //   task.subTasks.addAll(_originalSubTasks);

  //   await repository.writeTask(task, [
  //     PutSubTasks(_originalSubTasks),
  //   ]);
  // }

  Future<void> _save(
    Repository repository, [
    List<TaskEditAction> extra = const [],
  ]) async {
    final task = widget.task;
    final (:put, :remove) = _updateSubTasks();

    task.progress = put.isEmpty
        ? null
        : put.where((subTask) => subTask.done).length / put.length;

    await repository.writeTask(task, [
      PutSubTasks(put),
      RemoveSubTasks(remove),
      ...extra,
    ]);
  }

  void _markAsDone(Repository repository) {
    final task = widget.task;

    switch (task) {
      case UserTask(
          :final startDate?,
          :final endDate,
          :final recurrence?,
        ):
        final newStart = _nextDate(recurrence, startDate);
        task.startDate = newStart;
        task.endDate = switch ((newStart, endDate)) {
          (final newStart?, final endDate?) =>
            newStart.add(endDate.difference(startDate)),
          _ => null,
        };

        if (recurrence.count case final count?) {
          task.recurrence =
              count > 1 ? recurrence.copyWith(count: count - 1) : null;
        }
        break;
      case UserTask(
          :final endDate?,
          :final recurrence?,
        ):
        final newEnd = _nextDate(recurrence, endDate);

        task.endDate = newEnd;

        if (recurrence.count case final count?) {
          task.recurrence =
              count > 1 ? recurrence.copyWith(count: count - 1) : null;
        }
        break;
      default:
        task.recurrence = null;
        task.startDate = null;
        task.endDate = null;
        break;
    }

    if (task.autoInsertDate == null) {
      task.archived = true;
    } else {
      // only need to reset subtasks if the task
      // is going to be repeated
      for (final controller in _subTaskControllers) {
        controller.subTask.done = false;
      }
    }
  }

  void _removeSubTask(_SubTaskController controller) {
    setState(() {
      controller.removed = true;
    });

    childScaffoldMessenger.showSnackBar(SnackBar(
      content: Text(context.tr('subtask_deleted')),
      action: SnackBarAction(
        label: context.tr('undo'),
        onPressed: () {
          setState(() {
            controller.removed = false;
          });
        },
      ),
    ));
  }

  TaskEditAction? _getTaskEditAction() {
    return switch ((positionController.value, widget.task.reference)) {
      // remove from queue + already not in queue
      (null, null) => null,
      // put somewhere in queue + already in queue
      (QueueInsertionPosition.preferred, _?) => null,
      (final position?, _) => PutTaskInQueue(position),
      (null, _?) => const RemoveTaskFromQueue(),
    };
  }

  @override
  Widget build(BuildContext context) {
    const buttonRadius = Radius.circular(60);
    final task = widget.task;
    final repository = ref.watch(repositoryPod);
    final currentlyTrackedTask = ref.watch(currentlyTrackedTaskPod).valueOrNull;
    final CustomColors(:deleteSurface) = Theme.of(context).extension()!;
    final isCreatingTask = task.id == Isar.autoIncrement;

    return TimeTrackingScreenWrapper(
      disabled: currentlyTrackedTask?.id == task.id,
      child: ScaffoldMessenger(
        key: scaffoldMessengerKey,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.tr(
              isCreatingTask ? "create_task" : "edit_task",
            )),
            actions: [
              IconButton(
                onPressed: () async {
                  await repository.deleteTask(task);

                  if (!context.mounted) return;
                  parentScaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(context.tr("task_deleted")),
                      // TODO: restore after migrating to drift
                      // action: SnackBarAction(
                      //   label: context.tr("undo"),
                      //   onPressed: () => _restoreTask(repository),
                      // ),
                    ),
                  );
                  context.pop();
                },
                icon: const Icon(Icons.delete),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverList.list(
                    children: [
                      TextField(
                        autofocus: widget.focusTitle,
                        focusNode: titleFocusNode,
                        controller: titleController,
                        decoration:
                            InputDecoration(labelText: context.tr("title")),
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.singleLineFormatter,
                        ],
                        onTapOutside: (event) => titleFocusNode.unfocus(),
                      ),
                      TextField(
                        focusNode: descriptionFocusNode,
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: context.tr("description"),
                        ),
                        maxLines: null,
                        onTapOutside: (event) => descriptionFocusNode.unfocus(),
                      ),
                      DateTimeInput(
                        label: Text(context.tr("start_date")),
                        controller: startDateController,
                      ),
                      ValueListenableBuilder(
                        valueListenable: startDateController,
                        builder: (context, startDate, child) {
                          return DateTimeInput(
                            label: Text(context.tr("end_date")),
                            controller: endDateController,
                            firstDate: startDate,
                            defaultHour: 23,
                            defaultMinute: 59,
                          );
                        },
                      ),
                      ValueListenableBuilder(
                        valueListenable: startDateController,
                        builder: (context, startDate, child) {
                          if (startDate == null) return const SizedBox.shrink();

                          return Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(context.tr("recurrence")),
                              TextButton(
                                onPressed: () async {
                                  final rule = await showRecurrencePicker(
                                    context,
                                    initialRecurrenceRule: recurrenceRule,
                                    initialWeekDays: [startDate.weekday],
                                  );

                                  if (rule == null) return;
                                  setState(() {
                                    recurrenceRule = rule;
                                  });
                                },
                                child: Text(context.tr(recurrenceRule == null
                                    ? "add_recurrence"
                                    : "edit_recurrence")),
                              ),
                              if (recurrenceRule != null)
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      recurrenceRule = null;
                                    });
                                  },
                                  icon: const Icon(Icons.delete),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder(
                        valueListenable: autoInserDateController,
                        builder: (context, date, child) {
                          return _QueuePositionPicker(
                            controller: positionController,
                            startDate: date,
                          );
                        },
                      ),
                      if (!isCreatingTask) ...[
                        const SizedBox(height: 16),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 4,
                                child: _TimeMeasurementButton(
                                    task: task,
                                    repository: repository,
                                    style: const ButtonStyle(
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.horizontal(
                                            left: buttonRadius,
                                          ),
                                        ),
                                      ),
                                    )),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: IconButton.filledTonal(
                                  onPressed: () {
                                    context.push(
                                      "/task/measurements",
                                      extra: TaskTimeMeasurementsParams(
                                        task: task,
                                      ),
                                    );
                                  },
                                  style: const ButtonStyle(
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.horizontal(
                                          right: buttonRadius,
                                        ),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.history),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                      const Divider(),
                    ],
                  ),
                  SliverMaterialReorderableList(
                    children: _subTaskControllers
                        .whereNot((controller) => controller.removed)
                        .map(
                          (controller) => Dismissible(
                            key: ObjectKey(controller),
                            onDismissed: (direction) =>
                                _removeSubTask(controller),
                            background: Container(color: deleteSurface),
                            child: _SubTaskCard(
                              controller: controller,
                              onDelete: () => _removeSubTask(controller),
                            ),
                          ),
                        )
                        .toList(),
                    onReorder: (oldIndex, newIndex) {
                      oldIndex =
                          _mapSubtaskIndex(oldIndex, _subTaskControllers);
                      newIndex =
                          _mapSubtaskIndex(newIndex, _subTaskControllers);
                      if (oldIndex < newIndex) {
                        newIndex--;
                      }

                      setState(() {
                        final controller =
                            _subTaskControllers.removeAt(oldIndex);
                        _subTaskControllers.insert(newIndex, controller);
                      });
                    },
                  ),
                  SliverList.list(children: [
                    TextButton(
                      onPressed: () async {
                        final controller = _SubTaskController(
                          SubTask(name: "", done: false, reference: 0),
                        );

                        final added = await controller.openView(context);
                        if (!added || !context.mounted) return;

                        setState(() {
                          _subTaskControllers.add(controller);
                        });

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!scrollController.hasClients) return;
                          scrollController.animateTo(
                            scrollController.offset + 60,
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.bounceInOut,
                          );
                        });
                      },
                      child: Text(context.tr("add_subtask")),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                  ])
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      _applyChanges();
                      await _save(repository, [
                        if (_getTaskEditAction() case final action?) action,
                      ]);
                      if (!context.mounted) return;
                      context.pop();
                    },
                    child: Text(context.tr("save")),
                  ),
                ),
                if (task.reference != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        _applyChanges();
                        _markAsDone(repository);

                        await _save(repository, [
                          const RemoveTaskFromQueue(),
                          StopTimeMeasurement(DateTime.now()),
                        ]);

                        if (!context.mounted) return;
                        context.pop();
                      },
                      child: Text(context.tr("done")),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _QueuePositionPicker extends StatefulWidget {
  const _QueuePositionPicker({
    required this.controller,
    required this.startDate,
  });

  final ValueNotifier<QueueInsertionPosition?> controller;
  final DateTime? startDate;
  @override
  State<_QueuePositionPicker> createState() => __QueuePositionPickerState();
}

class __QueuePositionPickerState extends State<_QueuePositionPicker> {
  Timer? _timer;
  bool _mustBeInQueue = false;

  @override
  void initState() {
    super.initState();

    _updateQueueLock();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateQueueLock(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _QueuePositionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    _updateQueueLock();
  }

  void _updateQueueLock() {
    final startDate = widget.startDate;

    if (startDate?.isBefore(DateTime.now()) ?? false) {
      if (_mustBeInQueue) return;
      setState(() {
        _mustBeInQueue = true;
        widget.controller.value ??= QueueInsertionPosition.preferred;
      });
    } else {
      if (!_mustBeInQueue) return;
      setState(() {
        _mustBeInQueue = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.controller.value;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: Text(context.tr("queued.none")),
          selected: position != null,
          onSelected: _mustBeInQueue
              ? null
              : (value) {
                  setState(() {
                    widget.controller.value =
                        value ? QueueInsertionPosition.preferred : null;
                  });
                },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text(context.tr("queue_position.start")),
          selected: position == QueueInsertionPosition.start,
          onSelected: position == null
              ? null
              : (value) {
                  setState(() {
                    widget.controller.value = value
                        ? QueueInsertionPosition.start
                        : QueueInsertionPosition.preferred;
                  });
                },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text(context.tr("queue_position.end")),
          selected: position == QueueInsertionPosition.end,
          onSelected: position == null
              ? null
              : (value) {
                  setState(() {
                    widget.controller.value = value
                        ? QueueInsertionPosition.end
                        : QueueInsertionPosition.preferred;
                  });
                },
        ),
      ],
    );
  }
}

class _SubTaskController {
  _SubTaskController(this.subTask) {
    textController.value = subTask.name;
    doneController.value = subTask.done;
  }

  bool removed = false;
  final SubTask subTask;
  final textController = ValueNotifier("");
  final doneController = ValueNotifier(false);

  void apply() {
    subTask.name = textController.value;
    subTask.done = doneController.value;
  }

  void dispose() {
    textController.dispose();
    doneController.dispose();
  }

  Future<bool> openView(
    BuildContext context, {
    void Function()? onDelete,
  }) async {
    final newText = await showModalBottomSheet<String>(
        isScrollControlled: true,
        context: context,
        builder: (context) {
          return BottomSheetSafeArea(
            basePadding: const EdgeInsets.all(15.0),
            child: _SubTaskEditor(
              initialTitle: textController.value,
              onDelete: onDelete,
            ),
          );
        });

    if (newText != null) {
      textController.value = newText;
    }

    return newText != null;
  }
}

class _SubTaskCard extends StatefulWidget {
  const _SubTaskCard({
    required this.controller,
    required this.onDelete,
  });

  final void Function() onDelete;
  final _SubTaskController controller;
  @override
  State<_SubTaskCard> createState() => _SubTaskCardState();
}

class _SubTaskCardState extends State<_SubTaskCard> {
  @override
  Widget build(BuildContext context) {
    final doneController = widget.controller.doneController;
    final titleController = widget.controller.textController;

    return ListTile(
      onTap: () => widget.controller.openView(
        context,
        onDelete: widget.onDelete,
      ),
      leading: ValueListenableBuilder(
        valueListenable: doneController,
        builder: (context, value, child) {
          return Checkbox(
            value: value,
            onChanged: (value) {
              doneController.value = value ?? false;
            },
          );
        },
      ),
      title: ValueListenableBuilder(
        valueListenable: titleController,
        builder: (context, value, child) => Text(value),
      ),
    );
  }
}

class _SubTaskEditor extends StatefulWidget {
  const _SubTaskEditor({
    required this.initialTitle,
    this.onDelete,
  });

  final String initialTitle;
  final void Function()? onDelete;

  @override
  State<_SubTaskEditor> createState() => _SubTaskEditorState();
}

class _SubTaskEditorState extends State<_SubTaskEditor> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();

    controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onDelete case final onDelete?)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDelete();
              },
              icon: const Icon(Icons.delete),
            ),
          ),
        TextField(
          autofocus: true,
          controller: controller,
          onSubmitted: (value) {
            Navigator.of(context).pop(value.trim());
          },
          keyboardType: TextInputType.multiline,
          maxLines: null,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.singleLineFormatter,
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
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: Text(context.tr("ok")),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeMeasurementButton extends StatefulWidget {
  const _TimeMeasurementButton({
    required this.task,
    required this.repository,
    this.style,
  });

  final Repository repository;
  final UserTask task;
  final ButtonStyle? style;

  @override
  State<_TimeMeasurementButton> createState() => _TimeMeasurementButtonState();
}

class _TimeMeasurementButtonState extends State<_TimeMeasurementButton> {
  static const _startKey = ValueKey("start");
  static const _stopKey = ValueKey("stop");
  static const _duration = Duration(milliseconds: 500);
  static const _curve = Curves.easeOut;

  Future<void> _start() async {
    await widget.repository.writeTask(widget.task, [
      StartTimeMeasurement(DateTime.now()),
    ]);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _stop() async {
    await widget.repository.writeTask(widget.task, [
      StopTimeMeasurement(DateTime.now()),
    ]);
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
  }

  Widget _buildTransition(Widget child, Animation<double> animation) {
    const offset = Offset(2, 0);
    final tween = Tween<Offset>(
      begin: child.key == _startKey ? -offset : offset,
      end: Offset.zero,
    );
    final offsetAnimation = animation.drive(tween);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: offsetAnimation,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = widget.task.activeTimeMeasurementStart;
    final onPressed = start == null ? _start : _stop;
    if (start != null) SecondTickProvider.of(context);

    return FilledButton(
      onPressed: onPressed,
      style: widget.style,
      child: AnimatedSwitcher(
        switchInCurve: _curve,
        switchOutCurve: _curve,
        transitionBuilder: _buildTransition,
        duration: _duration,
        child: switch (start) {
          null => Text(
              key: _startKey,
              context.tr("start_time_measurement"),
            ),
          _ => IntrinsicHeight(
              key: _stopKey,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatDuration(now.difference(start))),
                  const VerticalDivider(),
                  Flexible(child: Text(context.tr("stop_time_measurement")))
                ],
              ),
            ),
        },
      ),
    );
  }
}

DateTime? _nextDate(RecurrenceRule rule, DateTime date) {
  final now = DateTime.now();

  final after = date.isBefore(now) ? now : date;
  return rule
      .copyWith(count: null) // we do our own count tracking
      .getInstances(
        start: date.copyWith(isUtc: true),
        after: after.copyWith(isUtc: true),
        includeAfter: after == now,
      )
      .firstOrNull
      ?.copyWith(isUtc: false);
}

int _mapSubtaskIndex(
    int relativeIndex, List<_SubTaskController> subTaskControllers) {
  var lastValidIndex = 0;
  var count = 0;

  for (var (i, controller) in subTaskControllers.indexed) {
    if (controller.removed) continue;

    if (count == relativeIndex) return i;
    lastValidIndex = i;
    count++;
  }

  return lastValidIndex + 1;
}
