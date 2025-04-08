import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
  final titleController = TextEditingController(),
      descriptionController = TextEditingController();

  final startDateController = DateTimeEditingController();
  final endDateController = DateTimeEditingController();

  RecurrenceRule? recurrenceRule;
  @override
  void initState() {
    super.initState();

    titleController.text = widget.task.title;
    descriptionController.text = widget.task.description;
    startDateController.value = widget.task.startDate;
    endDateController.value = widget.task.endDate;
    recurrenceRule = widget.task.recurrence;

    endDateController.addListener(() {
      final value = endDateController.value;
      if (value == null) return;
      if (startDateController.value != null) return;

      startDateController.value = DateTime(value.year, value.month, value.day);
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    startDateController.dispose();
    endDateController.dispose();

    super.dispose();
  }

  void _applyChanges() {
    final task = widget.task;
    task.title = titleController.text;
    task.description = descriptionController.text;
    task.startDate = startDateController.value;
    task.endDate = endDateController.value;
    task.recurrence = recurrenceRule;
    task.lastTouched = DateTime.now();
  }

  void showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final reference = widget.task.reference;
        return Column(
          children: [
            if (reference != null)
              ListTile(
                leading: const Icon(Icons.remove),
                title: const Text("Remove from queue"),
                onTap: () {
                  context.pop();
                },
              ),
            if (reference == null)
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text("Add to queue"),
                onTap: () {
                  context.pop();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text("Delete"),
              onTap: () {
                context.pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final repository = ref.watch(repositoryPod);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(task.id == Isar.autoIncrement ? "Create task" : "Edit task"),
        actions: [
          IconButton(
            onPressed: () async {
              await repository.deleteTask(task);

              if (!context.mounted) return;
              context.pop();
            },
            icon: const Icon(Icons.delete),
          ),
          IconButton(
            onPressed: () {
              showMenu();
            },
            icon: Icon(Icons.more_vert),
          )
        ],
      ),
      body: ListView(
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: "Title"),
            keyboardType: TextInputType.multiline,
            maxLines: null,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.singleLineFormatter,
            ],
          ),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(labelText: "Description"),
            maxLines: null,
          ),
          ValueListenableBuilder(
            valueListenable: endDateController,
            builder: (context, endDate, child) {
              return DateTimePicker(
                label: const Text("Start date"),
                controller: startDateController,
                lastDate: endDate,
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: startDateController,
            builder: (context, startDate, child) {
              return DateTimePicker(
                label: const Text("End date"),
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

              return Row(
                children: [
                  const Text("Recurrence"),
                  TextButton(
                    onPressed: () async {
                      final rule = await showRecurrencePicker(context,
                          initialRecurrenceRule: recurrenceRule);

                      setState(() {
                        recurrenceRule = rule;
                      });
                    },
                    child: Text(recurrenceRule == null
                        ? "Add recurrence"
                        : "Edit recurrence"),
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
        ],
      ),
      bottomNavigationBar: Row(children: [
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () async {
              _applyChanges();

              if (widget.addToQueue) {
                await repository.addTaskToQueue(task);
              } else {
                await repository.updateTask(task);
              }
              if (!context.mounted) return;
              context.pop();
            },
            child: Text("Save"),
          ),
        ),
        if (task.reference != null) ...[
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () async {
                _applyChanges();
                task.reference = null;

                switch (task) {
                  case UserTask(
                      startDate: DateTime start,
                      endDate: DateTime end,
                      recurrence: RecurrenceRule rule
                    ):
                    final newStart = rule
                        .getInstances(start: start.copyWith(isUtc: true))
                        .map((date) => date.copyWith(isUtc: false))
                        .where((date) => date.isAfter(DateTime.now()))
                        .first;
                    task.startDate = newStart;
                    task.endDate = newStart.add(end.difference(start));
                    break;
                  case UserTask(
                      startDate: DateTime start,
                      recurrence: RecurrenceRule rule
                    ):
                    final newStart = rule
                        .getInstances(start: start.copyWith(isUtc: true))
                        .map((date) => date.copyWith(isUtc: false))
                        .where((date) => date.isAfter(DateTime.now()))
                        .first;
                    task.startDate = newStart;
                    break;
                  default:
                    task.recurrence = null;
                    task.startDate = null;
                    task.endDate = null;
                    break;
                }

                await repository.updateTask(task);
                if (!context.mounted) return;
                context.pop();
              },
              child: const Text("Done"),
            ),
          ),
          Expanded(
            flex: 1,
            child: IconButton.outlined(
              onPressed: () async {
                _applyChanges();

                await repository.moveTaskToStartOfQueue(task);

                if (!context.mounted) return;
                context.pop();
              },
              icon: Icon(Icons.arrow_upward),
            ),
          ),
          Expanded(
            flex: 1,
            child: IconButton.outlined(
              onPressed: () async {
                _applyChanges();

                await repository.moveTaskToEndOfQueue(task);

                if (!context.mounted) return;
                context.pop();
              },
              icon: Icon(Icons.arrow_downward),
            ),
          ),
        ],
      ]),
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
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, value, child) {
        return Row(
          children: [
            widget.label,
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
                null => "Select date",
                _ => DateFormat.yMMMMd("pt_BR").format(value),
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
                child: Text(DateFormat.jm("pt_BR").format(value)),
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  _controller.value = null;
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
