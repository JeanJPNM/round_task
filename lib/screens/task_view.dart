import 'dart:async';

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:round_task/custom_colors.dart';
import 'package:round_task/models/task.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/widgets/bottom_sheet_safe_area.dart';
import 'package:round_task/widgets/recurrence_picker.dart';
import 'package:round_task/widgets/sliver_material_reorderable_list.dart';
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

  Future<void> _restoreTask(Repository repository) async {
    final task = widget.task;

    task.subTasks.clear();
    task.subTasks.addAll(_originalSubTasks);

    await repository.writeTask(task, [
      PutSubTasks(_originalSubTasks),
    ]);
  }

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
    final task = widget.task;
    final repository = ref.watch(repositoryPod);
    final CustomColors(:deleteSurface) = Theme.of(context).extension()!;

    return ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr(
            task.id == Isar.autoIncrement ? "create_task" : "edit_task",
          )),
          actions: [
            IconButton(
              onPressed: () async {
                await repository.deleteTask(task);

                if (!context.mounted) return;
                parentScaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(context.tr("task_deleted")),
                    action: SnackBarAction(
                      label: context.tr("undo"),
                      onPressed: () => _restoreTask(repository),
                    ),
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
                    DateTimePicker(
                      label: Text(context.tr("start_date")),
                      controller: startDateController,
                    ),
                    ValueListenableBuilder(
                      valueListenable: startDateController,
                      builder: (context, startDate, child) {
                        return DateTimePicker(
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
                    const SizedBox(height: 8),
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
                    oldIndex = _mapSubtaskIndex(oldIndex, _subTaskControllers);
                    newIndex = _mapSubtaskIndex(newIndex, _subTaskControllers);
                    if (oldIndex < newIndex) {
                      newIndex--;
                    }

                    setState(() {
                      final controller = _subTaskControllers.removeAt(oldIndex);
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
    );
  }
}

class DateTimeEditingController extends ValueNotifier<DateTime?> {
  DateTimeEditingController([super.value]);

  DateTime? previous;

  @override
  set value(DateTime? newValue) {
    previous = value;
    super.value = newValue;
  }
}

class DateTimePicker extends StatefulWidget {
  DateTimePicker({
    super.key,
    required this.label,
    required this.controller,
    this.defaultHour = 0,
    this.defaultMinute = 0,
    DateTime? firstDate,
    DateTime? lastDate,
  })  : firstDate = firstDate ?? DateTime(2000),
        lastDate = lastDate ?? DateTime(2100);
  final DateTimeEditingController? controller;
  final Widget label;
  final DateTime firstDate;
  final DateTime lastDate;
  final int defaultHour;
  final int defaultMinute;
  @override
  State<DateTimePicker> createState() => _DateTimePickerState();
}

class _DateTimePickerState extends State<DateTimePicker> {
  bool _disposeController = false;
  late final DateTimeEditingController _controller;

  @override
  void initState() {
    super.initState();

    if (widget.controller == null) {
      _controller = DateTimeEditingController();
      _disposeController = true;
    } else {
      _controller = widget.controller!;
    }
  }

  @override
  void dispose() {
    if (_disposeController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, value, child) {
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            widget.label,
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: value,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                    );

                    if (date != null) {
                      _controller.value = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        value?.hour ?? widget.defaultHour,
                        value?.minute ?? widget.defaultMinute,
                      );
                    }
                  },
                  child: Text(switch (value) {
                    null => context.tr("select_date"),
                    _ => DateFormat.yMMMEd(locale).format(value),
                  }),
                ),
                if (value != null) ...[
                  TextButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(value),
                      );
                      if (time != null) {
                        _controller.value = DateTime(
                          value.year,
                          value.month,
                          value.day,
                          time.hour,
                          time.minute,
                        );
                      }
                    },
                    child: Text(DateFormat.jm(locale).format(value)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      _controller.value = null;
                    },
                  ),
                ],
              ],
            ),
          ],
        );
      },
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
