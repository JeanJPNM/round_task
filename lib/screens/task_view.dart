import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:round_task/models/task.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/widgets/recurrence_picker.dart';
import 'package:rrule/rrule.dart';

typedef TaskViewParams = (UserTask task, bool addToQueue);

class TaskViewScreen extends ConsumerStatefulWidget {
  const TaskViewScreen({
    super.key,
    required this.task,
    this.addToQueue = false,
  });

  final bool addToQueue;
  final UserTask task;

  @override
  ConsumerState<TaskViewScreen> createState() => _TaskViewScreenState();
}

class _TaskViewScreenState extends ConsumerState<TaskViewScreen> {
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final titleController = TextEditingController(),
      descriptionController = TextEditingController();

  final startDateController = DateTimeEditingController();
  final endDateController = DateTimeEditingController();

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
    recurrenceRule = task.recurrence;

    _subTaskControllers = _originalSubTasks
        .map((subTask) => _SubTaskController(subTask))
        .toList();

    endDateController.addListener(() {
      final value = endDateController.value;
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
    titleController.dispose();
    descriptionController.dispose();
    startDateController.dispose();
    endDateController.dispose();

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

  void showMenu(Repository repository) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final reference = widget.task.reference;
        return Column(
          children: [
            if (reference != null)
              ListTile(
                leading: const Icon(Icons.remove),
                title: Text(context.tr("remove_from_queue")),
                onTap: () async {
                  await repository.writeTask(widget.task, [
                    const RemoveTaskFromQueue(),
                  ]);
                  setState(() {});

                  if (!context.mounted) return;
                  context.pop();
                },
              ),
            if (reference == null)
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(context.tr("add_to_queue")),
                onTap: () async {
                  await repository.writeTask(widget.task, [
                    PutTaskInQueue(QueueInsertionPosition.preferred),
                  ]);
                  setState(() {});

                  if (!context.mounted) return;
                  context.pop();
                },
              ),
          ],
        );
      },
    );
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

    for (final controller in _subTaskControllers) {
      controller.subTask.done = false;
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

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final repository = ref.watch(repositoryPod);
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;

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
            IconButton(
              onPressed: () {
                showMenu(repository);
              },
              icon: const Icon(Icons.more_vert),
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(8.0),
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: context.tr("title")),
              keyboardType: TextInputType.multiline,
              maxLines: null,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.singleLineFormatter,
              ],
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: context.tr("description")),
              maxLines: null,
            ),
            ValueListenableBuilder(
              valueListenable: endDateController,
              builder: (context, endDate, child) {
                return DateTimePicker(
                  label: Text(context.tr("start_date")),
                  controller: startDateController,
                  lastDate: endDate,
                );
              },
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
            const Divider(),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _subTaskControllers
                  .whereNot((controller) => controller.removed)
                  .map(
                    (controller) => Dismissible(
                      key: ObjectKey(controller),
                      onDismissed: (direction) => _removeSubTask(controller),
                      background: Container(color: tertiaryColor),
                      child: _SubTaskEditor(
                        controller: controller,
                        onDelete: () => _removeSubTask(controller),
                      ),
                    ),
                  )
                  .toList(),
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex--;
                }

                setState(() {
                  final controller = _subTaskControllers.removeAt(oldIndex);
                  _subTaskControllers.insert(newIndex, controller);
                });
              },
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _subTaskControllers.add(_SubTaskController(
                    SubTask(name: "", done: false, reference: 0),
                  ));
                });
              },
              child: Text(context.tr("add_subtask")),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () async {
                  _applyChanges();
                  await _save(repository, [
                    if (widget.addToQueue)
                      PutTaskInQueue(QueueInsertionPosition.preferred),
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
                flex: 2,
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
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: IconButton.outlined(
                  onPressed: () async {
                    _applyChanges();

                    await _save(repository, [
                      PutTaskInQueue(QueueInsertionPosition.start),
                    ]);

                    if (!context.mounted) return;
                    context.pop();
                  },
                  icon: const Icon(Icons.arrow_upward),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: IconButton.outlined(
                  onPressed: () async {
                    _applyChanges();

                    await _save(repository, [
                      PutTaskInQueue(QueueInsertionPosition.end),
                    ]);

                    if (!context.mounted) return;
                    context.pop();
                  },
                  icon: const Icon(Icons.arrow_downward),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class DateTimeEditingController extends ValueNotifier<DateTime?> {
  DateTimeEditingController([super.value]);
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
}

class _SubTaskEditor extends StatefulWidget {
  const _SubTaskEditor({
    required this.controller,
    required this.onDelete,
  });

  final void Function() onDelete;
  final _SubTaskController controller;
  @override
  State<_SubTaskEditor> createState() => __SubTaskEditorState();
}

class __SubTaskEditorState extends State<_SubTaskEditor> {
  Future<void> _showEditDialog() async {
    final newText = await showDialog<String>(
      context: context,
      builder: (context) {
        return _SubTaskDialog(
          initialTitle: widget.controller.textController.value,
          onDelete: widget.onDelete,
        );
      },
    );
    if (newText != null) {
      widget.controller.textController.value = newText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final doneController = widget.controller.doneController;
    final titleController = widget.controller.textController;

    return ListTile(
      onTap: () async {
        await _showEditDialog();
      },
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

class _SubTaskDialog extends StatefulWidget {
  const _SubTaskDialog({
    required this.initialTitle,
    required this.onDelete,
  });

  final String initialTitle;
  final void Function() onDelete;

  @override
  State<_SubTaskDialog> createState() => __SubTaskDialogState();
}

class __SubTaskDialogState extends State<_SubTaskDialog> {
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
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDelete();
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
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(context.tr("cancel")),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(controller.text.trim());
                  },
                  child: Text(context.tr("ok")),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

DateTime? _nextDate(RecurrenceRule rule, DateTime date) {
  return rule
      .copyWith(count: null) // we do our own count tracking
      .getInstances(
        start: date.copyWith(isUtc: true),
        after: DateTime.now().copyWith(isUtc: true),
        includeAfter: true,
      )
      .firstOrNull
      ?.copyWith(isUtc: false);
}
