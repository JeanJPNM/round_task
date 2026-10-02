import 'dart:async';

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:round_task/custom_colors.dart';
import 'package:round_task/db/db.dart';
import 'package:round_task/formatting.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/screens/task_time_measurements.dart';
import 'package:round_task/widgets/bottom_sheet_safe_area.dart';
import 'package:round_task/widgets/date_time_input.dart';
import 'package:round_task/widgets/recurrence_picker.dart';
import 'package:round_task/widgets/second_tick_provider.dart';
import 'package:round_task/widgets/sliver_material_reorderable_list.dart';
import 'package:rrule/rrule.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskViewParams {
  TaskViewParams(
    this.task, {
    this.addToQueue = false,
    this.autofocusTitle = false,
  });

  final UserTask? task;
  final bool addToQueue;
  final bool autofocusTitle;
}

class LazyTaskViewParams {
  LazyTaskViewParams(this.taskId);

  final int taskId;
}

class TaskViewScreen extends ConsumerWidget {
  const TaskViewScreen({super.key, required this.params});

  final TaskViewParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (task, subTasks) = switch (params.task) {
      final task? => (
        ref.watch(taskByIdPod(task.id)).value ?? task,
        ref.watch(taskSubTasksPod(task.id)),
      ),
      _ => (null, const AsyncData(<SubTask>[])),
    };

    return _TaskEditor(
      task: task,
      originalTask: params.task,
      addToQueue: params.addToQueue,
      focusTitle: params.autofocusTitle,
      subTasksValue: subTasks,
    );
  }
}

class LazyTaskViewScreen extends ConsumerWidget {
  const LazyTaskViewScreen({super.key, required this.params});

  final LazyTaskViewParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(taskByIdPod(params.taskId))
        .when(
          data: (task) => TaskViewScreen(params: TaskViewParams(task)),
          error: (error, stackTrace) =>
              Scaffold(body: Center(child: Text(error.toString()))),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
  }
}

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({
    required this.task,
    required this.originalTask,
    required this.addToQueue,
    required this.focusTitle,
    required this.subTasksValue,
  });

  final bool addToQueue;
  final bool focusTitle;
  final UserTask? task;
  final UserTask? originalTask;
  final AsyncValue<List<SubTask>> subTasksValue;

  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
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
  final priorityController = ValueNotifier<TaskPriority>(
    const TaskPriority(important: false, urgent: false),
  );
  bool lockTaskInQueue = false;

  late ScaffoldMessengerState parentScaffoldMessenger;
  ScaffoldMessengerState get childScaffoldMessenger =>
      scaffoldMessengerKey.currentState!;
  final _subTasksController = SubTasksController([]);

  RecurrenceRule? recurrenceRule;
  @override
  void initState() {
    super.initState();

    final task = widget.task;
    if (task != null) {
      titleController.text = task.title;
      descriptionController.text = task.description;
      startDateController.value = task.startDate;
      endDateController.value = task.endDate;
      autoInserDateController.value = task.autoInsertDate;
      recurrenceRule = task.recurrence;
      priorityController.value = task.priority;
    }

    _subTasksController.setSubTasks(widget.subTasksValue.value ?? []);
    positionController.value =
        task?.status == TaskStatus.active || widget.addToQueue
        ? QueueInsertionPosition.preferred
        : null;
    lockTaskInQueue = isQueueLocked(task?.autoInsertDate, DateTime.now());

    Listenable.merge([startDateController, endDateController]).addListener(() {
      autoInserDateController.value = autoInsertDateOf(
        startDateController.value,
        endDateController.value,
      );
    });
    startDateController.addListener(() {
      final shifted = getShiftedEndDate(
        newStart: startDateController.value,
        previousStart: startDateController.previous,
        currentEnd: endDateController.value,
      );
      if (shifted != null) {
        endDateController.value = shifted;
      }
    });
    endDateController.addListener(() {
      if (startDateController.value != null) return;
      final defaultStart = getDefaultStartDate(endDateController.value);
      if (defaultStart != null) {
        startDateController.value = defaultStart;
      }
    });
  }

  @override
  void didUpdateWidget(covariant _TaskEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.subTasksValue != widget.subTasksValue) {
      widget.subTasksValue.whenData((subTasks) {
        _subTasksController.setSubTasks(subTasks);
      });
    }
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
    _subTasksController.dispose();

    super.dispose();
  }

  UserTasksCompanion _getTaskCompanion({
    bool done = false,
    bool restore = false,
    double? progress,
    DateTime? startDate,
    DateTime? endDate,
    RecurrenceRule? recurrence,
  }) {
    final task = widget.task;
    final now = DateTime.now();
    final hasAutoInsertDate = (startDate, endDate) != (null, null);

    final status = getNextTaskStatus(
      currentStatus: task?.status,
      done: done,
      hasAutoInsertDate: hasAutoInsertDate,
    );

    return UserTasksCompanion.insert(
      id: Value.absentIfNull(task?.id),
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      activeTimeMeasurementStart: Value(task?.activeTimeMeasurementStart),
      startDate: Value(startDate),
      endDate: Value(endDate),
      recurrence: Value(recurrence),
      status: status,
      progress: Value(progress),
      createdAt: task?.createdAt ?? now,
      updatedByUserAt: now,
      reference: Value.absentIfNull(task?.reference),
      priority: Value(priorityController.value),
      deletedAt: restore
          ? const Value(null)
          : Value.absentIfNull(task?.deletedAt),
    );
  }

  Future<Future<void> Function()?> _save(
    AppDatabase db, {
    bool markAsDone = false,
    bool restoreTask = false,
    List<TaskEditAction> extra = const [],
  }) async {
    final (:startDate, :endDate, :recurrence) = switch (markAsDone) {
      true => getNextOccurrence(
        startDate: startDateController.value,
        endDate: endDateController.value,
        recurrence: recurrenceRule,
        now: DateTime.now(),
      ),
      false => (
        startDate: startDateController.value,
        endDate: endDateController.value,
        recurrence: recurrenceRule,
      ),
    };
    final hasAutoInsertDate = (startDate, endDate) != (null, null);

    final put = _subTasksController.toCompanions(
      resetDone: markAsDone && hasAutoInsertDate,
    );
    final remove = _subTasksController.removedSubTaskIds();

    final progress = _subTasksController.getProgress(
      resetDone: markAsDone && hasAutoInsertDate,
    );

    final taskCompanion = _getTaskCompanion(
      done: markAsDone,
      restore: restoreTask,
      progress: progress,
      startDate: startDate,
      endDate: endDate,
      recurrence: recurrence,
    );

    final preservedTask = widget.task;
    final preservedSubTasks = widget.subTasksValue.value;

    await db.writeTask(taskCompanion, [
      PutSubTasks(put),
      RemoveSubTasks(remove),
      ...extra,
    ]);

    if (preservedTask == null) return null;

    return () async {
      await db.writeTask(preservedTask, [
        if (preservedTask.activeTimeMeasurementStart case final start?)
          UndoStopTimeMeasurement(start),
        if (preservedSubTasks != null) RestoreSubTasks(preservedSubTasks),
      ]);
    };
  }

  void _onRemoveSubTask(SubTaskController controller) {
    childScaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(context.tr('subtask_deleted')),
        action: SnackBarAction(
          label: context.tr('undo'),
          onPressed: () {
            _subTasksController.markAsActive(controller);
          },
        ),
      ),
    );
  }

  TaskEditAction? _getTaskEditAction() {
    return getQueueEditAction(
      position: positionController.value,
      taskStatus: widget.task?.status,
    );
  }

  @override
  Widget build(BuildContext context) {
    const buttonRadius = Radius.circular(60);
    final originalTask = widget.originalTask;
    final task = widget.task;
    final database = ref.watch(databasePod);
    final isCreatingTask = originalTask == null;

    return ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr(isCreatingTask ? "create_task" : "edit_task")),
          actions: [
            if (task case UserTask(deletedAt: null))
              IconButton(
                onPressed: () async {
                  final reference = DateTime.now();
                  await database.writeTask(task, [
                    StopTimeMeasurement(reference),
                    SoftDeleteTask(reference),
                  ]);

                  if (!context.mounted) return;
                  parentScaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(context.tr("task_deleted")),
                      action: SnackBarAction(
                        label: context.tr("undo"),
                        onPressed: () => database.writeTask(task, [
                          const UndoSoftDeleteTask(),
                          if (task.activeTimeMeasurementStart case final start?)
                            UndoStopTimeMeasurement(start),
                        ]),
                      ),
                    ),
                  );
                  context.pop();
                },
                icon: const Icon(Icons.delete),
              ),
            if (task case UserTask(deletedAt: _?))
              IconButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(
                          context.tr(
                            "delete_task_permanently_confirmation.title",
                          ),
                        ),
                        content: Text(
                          context.tr(
                            "delete_task_permanently_confirmation.content",
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(context.tr("cancel")),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(context.tr("confirm")),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirmed != true) return;
                  await database.deleteTask(task);

                  if (!context.mounted) return;
                  parentScaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(context.tr("task_deleted_permanently")),
                    ),
                  );
                  context.pop();
                },
                icon: const Icon(Icons.delete_forever),
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
                      decoration: InputDecoration(
                        labelText: context.tr("title"),
                      ),
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
                              child: Text(
                                context.tr(
                                  recurrenceRule == null
                                      ? "add_recurrence"
                                      : "edit_recurrence",
                                ),
                              ),
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
                    const SizedBox(height: 16),
                    _TaskPriorityPicker(controller: priorityController),
                    if (!isCreatingTask && task != null) ...[
                      const SizedBox(height: 16),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 4,
                              child: _TimeMeasurementButton(
                                task: task,
                                database: database,
                                style: const ButtonStyle(
                                  shape: WidgetStatePropertyAll(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.horizontal(
                                        left: buttonRadius,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(),
                  ],
                ),
                widget.subTasksValue.when(
                  error: (error, stackTrace) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.tr("error_loading_subtasks")),
                    ),
                  ),
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                  ),
                  data: (subTasks) => _SubTasksSliver(
                    onRemoveSubTask: _onRemoveSubTask,
                    subTasks: subTasks,
                    subTasksController: _subTasksController,
                    scrollController: scrollController,
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              spacing: 8,
              children: [
                if (originalTask case null || UserTask(deletedAt: null))
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final undo = await _save(
                          database,
                          extra: [?_getTaskEditAction()],
                        );
                        if (!context.mounted) return;
                        context.pop();

                        if (undo == null) return;

                        parentScaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(context.tr("task_saved")),
                            action: SnackBarAction(
                              label: context.tr("undo"),
                              onPressed: undo,
                            ),
                          ),
                        );
                      },
                      child: Text(context.tr("save")),
                    ),
                  ),
                if (originalTask case UserTask(
                  deletedAt: null,
                  status: TaskStatus.active,
                ))
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final undo = await _save(
                          database,
                          markAsDone: true,
                          extra: [StopTimeMeasurement(DateTime.now())],
                        );

                        if (!context.mounted) return;
                        context.pop();

                        if (undo == null) return;
                        parentScaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(context.tr("task_done")),
                            action: SnackBarAction(
                              label: context.tr("undo"),
                              onPressed: undo,
                            ),
                          ),
                        );
                      },
                      child: Text(context.tr("done")),
                    ),
                  ),
                if (originalTask case UserTask(deletedAt: _?))
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final undo = await _save(database, restoreTask: true);
                        if (!context.mounted) return;
                        context.pop();

                        if (undo == null) return;
                        parentScaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(context.tr("task_restored")),
                            action: SnackBarAction(
                              label: context.tr("undo"),
                              onPressed: undo,
                            ),
                          ),
                        );
                      },
                      child: Text(context.tr("restore")),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubTasksSliver extends StatefulWidget {
  const _SubTasksSliver({
    required this.subTasks,
    required this.subTasksController,
    required this.scrollController,
    required this.onRemoveSubTask,
  });

  final ScrollController scrollController;
  final List<SubTask> subTasks;
  final SubTasksController subTasksController;
  final void Function(SubTaskController) onRemoveSubTask;
  @override
  State<_SubTasksSliver> createState() => _SubTasksSliverState();
}

class _SubTasksSliverState extends State<_SubTasksSliver> {
  void _removeSubTask(SubTaskController controller) {
    widget.subTasksController.markAsRemoved(controller);
    widget.onRemoveSubTask(controller);
  }

  void _addSubTask() async {
    final controller = SubTaskController(title: "", done: false);

    final added = await controller.openView(context);
    if (!added) {
      controller.dispose();
      return;
    }
    widget.subTasksController.add(controller);

    if (!context.mounted) return;

    final scrollController = widget.scrollController;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.offset + 60,
        duration: const Duration(milliseconds: 150),
        curve: Curves.bounceInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final CustomColors(:deleteSurface) = Theme.of(context).extension()!;
    final subTasksController = widget.subTasksController;

    return SliverMainAxisGroup(
      slivers: [
        ListenableBuilder(
          listenable: subTasksController,
          builder: (context, child) {
            final controllers = subTasksController.activeControllers;

            return SliverMaterialReorderableList(
              onReorder: subTasksController.reorderActiveController,
              children: [
                for (final controller in controllers)
                  Dismissible(
                    key: ObjectKey(controller),
                    onDismissed: (direction) => _removeSubTask(controller),
                    background: Container(color: deleteSurface),
                    child: _SubTaskCard(
                      controller: controller,
                      onDelete: () => _removeSubTask(controller),
                    ),
                  ),
              ],
            );
          },
        ),
        SliverList.list(
          children: [
            TextButton(
              onPressed: _addSubTask,
              child: Text(context.tr("add_subtask")),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
          ],
        ),
      ],
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
    if (isQueueLocked(widget.startDate, DateTime.now())) {
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
          tooltip: context.tr("queue_position.queued_tooltip"),
          selected: position != null,
          onSelected: _mustBeInQueue
              ? null
              : (value) {
                  setState(() {
                    widget.controller.value = value
                        ? QueueInsertionPosition.preferred
                        : null;
                  });
                },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text(context.tr("queue_position.start")),
          tooltip: context.tr("queue_position.start_tooltip"),
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
          tooltip: context.tr("queue_position.end_tooltip"),
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

class SubTasksController extends ChangeNotifier {
  SubTasksController(this.controllers);

  final List<SubTaskController> controllers;

  Iterable<SubTaskController> get activeControllers =>
      controllers.whereNot((c) => c.removed);

  List<int> removedSubTaskIds() => controllers
      .where((c) => c.removed)
      .map((c) => c.id)
      .whereType<int>()
      .toList();

  double? getProgress({bool resetDone = false}) {
    final active = activeControllers.toList();
    if (active.isEmpty) return null;
    if (resetDone) return 0.0;
    return active.where((c) => c.doneController.value).length / active.length;
  }

  List<SubTasksCompanion> toCompanions({bool resetDone = false}) =>
      activeControllers
          .mapIndexed(
            (index, controller) =>
                controller.toCompanion(index, resetDone: resetDone),
          )
          .toList();

  void setSubTasks(List<SubTask> subTasks) {
    clear();
    for (final subTask in subTasks) {
      final controller = SubTaskController(
        id: subTask.id,
        title: subTask.title,
        done: subTask.done,
      );
      controllers.add(controller);
    }

    notifyListeners();
  }

  void add(SubTaskController controller) {
    controllers.add(controller);
    notifyListeners();
  }

  void markAsRemoved(SubTaskController controller) {
    controller.removed = true;
    notifyListeners();
  }

  void markAsActive(SubTaskController controller) {
    controller.removed = false;
    notifyListeners();
  }

  void clear() {
    for (final controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
    notifyListeners();
  }

  void reorderActiveController(int oldIndex, int newIndex) {
    oldIndex = mapSubtaskIndex(oldIndex, controllers);
    newIndex = mapSubtaskIndex(newIndex, controllers);
    if (oldIndex < newIndex) {
      newIndex--;
    }
    final oldController = controllers.removeAt(oldIndex);
    controllers.insert(newIndex, oldController);
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}

class SubTaskController {
  SubTaskController({this.id, required String title, required bool done}) {
    textController.value = title;
    doneController.value = done;
  }

  bool removed = false;
  final int? id;
  final textController = ValueNotifier("");
  final doneController = ValueNotifier(false);

  SubTasksCompanion toCompanion(int reference, {bool resetDone = false}) {
    return SubTasksCompanion(
      id: Value.absentIfNull(id),
      taskId: const Value.absent(),
      title: Value(textController.value),
      done: Value(!resetDone && doneController.value),
      reference: Value(reference),
    );
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
      },
    );

    if (newText != null) {
      textController.value = newText;
    }

    return newText != null;
  }
}

class _SubTaskCard extends StatefulWidget {
  const _SubTaskCard({required this.controller, required this.onDelete});

  final void Function() onDelete;
  final SubTaskController controller;
  @override
  State<_SubTaskCard> createState() => _SubTaskCardState();
}

class _SubTaskCardState extends State<_SubTaskCard> {
  @override
  Widget build(BuildContext context) {
    final doneController = widget.controller.doneController;
    final titleController = widget.controller.textController;

    return ListTile(
      onTap: () =>
          widget.controller.openView(context, onDelete: widget.onDelete),
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
  const _SubTaskEditor({required this.initialTitle, this.onDelete});

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
          inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
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
    required this.database,
    this.style,
  });

  final AppDatabase database;
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
    await widget.database.writeTask(widget.task, [
      StartTimeMeasurement(DateTime.now()),
    ]);
  }

  Future<void> _stop() async {
    final originalStart = widget.task.activeTimeMeasurementStart;
    if (originalStart == null) return;

    await widget.database.writeTask(widget.task, [
      StopTimeMeasurement(DateTime.now()),
    ]);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr("time_measurement_stopped")),
        action: SnackBarAction(
          label: context.tr("undo"),
          onPressed: () async {
            await widget.database.writeTask(widget.task, [
              UndoStopTimeMeasurement(originalStart),
            ]);
          },
        ),
      ),
    );
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
      child: SlideTransition(position: offsetAnimation, child: child),
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
          null => Text(key: _startKey, context.tr("start_time_measurement")),
          _ => IntrinsicHeight(
            key: _stopKey,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatDuration(now.difference(start))),
                const VerticalDivider(),
                Flexible(child: Text(context.tr("stop_time_measurement"))),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _TaskPriorityPicker extends StatefulWidget {
  const _TaskPriorityPicker({required this.controller});

  final ValueNotifier<TaskPriority> controller;

  @override
  State<_TaskPriorityPicker> createState() => _TaskPriorityPickerState();
}

class _TaskPriorityPickerState extends State<_TaskPriorityPicker> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, priority, child) {
        return Wrap(
          children: [
            ChoiceChip(
              label: Text(context.tr("task_priority.important")),
              tooltip: context.tr("task_priority.important_tooltip"),
              selected: priority.important,
              onSelected: (value) {
                controller.value = priority.copyWith(important: value);
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(context.tr("task_priority.urgent")),
              tooltip: context.tr("task_priority.urgent_tooltip"),
              selected: priority.urgent,
              onSelected: (value) {
                controller.value = priority.copyWith(urgent: value);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                launchUrl(Uri.parse(context.tr("task_priority.help_url")));
              },
              tooltip: context.tr("task_priority.help_tooltip"),
              icon: const Icon(Icons.help_outline),
            ),
          ],
        );
      },
    );
  }
}

@visibleForTesting
TaskStatus getNextTaskStatus({
  required TaskStatus? currentStatus,
  required bool done,
  required bool hasAutoInsertDate,
}) {
  return switch ((currentStatus, done, hasAutoInsertDate)) {
    (_, true, false) => TaskStatus.archived,
    (_, true, true) => TaskStatus.pending,
    (TaskStatus.archived, false, true) => TaskStatus.pending,
    (final status, false, _) => status ?? TaskStatus.pending,
  };
}

@visibleForTesting
DateTime? getNextDate(RecurrenceRule rule, DateTime currentDate, DateTime now) {
  final after = currentDate.isBefore(now) ? now : currentDate;
  return rule
      .copyWith(count: null) // we do our own count tracking
      .getInstances(
        start: currentDate.copyWith(isUtc: true),
        after: after.copyWith(isUtc: true),
        includeAfter: after == now,
      )
      .firstOrNull
      ?.copyWith(isUtc: false);
}

@visibleForTesting
({DateTime? startDate, DateTime? endDate, RecurrenceRule? recurrence})
getNextOccurrence({
  required DateTime? startDate,
  required DateTime? endDate,
  required RecurrenceRule? recurrence,
  required DateTime now,
}) {
  switch ((startDate, endDate, recurrence)) {
    case (final startDate?, final endDate, final recurrence?):
      final newStart = getNextDate(recurrence, startDate, now);

      final newEnd = switch ((newStart, endDate)) {
        (final newStart?, final endDate?) => newStart.add(
          endDate.difference(startDate),
        ),
        _ => null,
      };

      final newRecurrence = switch (recurrence.count) {
        null => recurrence,
        final count when count > 1 => recurrence.copyWith(count: count - 1),
        _ => null,
      };

      return (startDate: newStart, endDate: newEnd, recurrence: newRecurrence);
    case (null, final endDate?, final recurrence?):
      final newEnd = getNextDate(recurrence, endDate, now);

      final newRecurrence = switch (recurrence.count) {
        null => recurrence,
        final count when count > 1 => recurrence.copyWith(count: count - 1),
        _ => null,
      };

      return (startDate: null, endDate: newEnd, recurrence: newRecurrence);
    default:
      return (startDate: null, endDate: null, recurrence: recurrence);
  }
}

@visibleForTesting
TaskEditAction? getQueueEditAction({
  required QueueInsertionPosition? position,
  required TaskStatus? taskStatus,
}) {
  return switch ((position, taskStatus)) {
    (null, TaskStatus.active) => const RemoveTaskFromQueue(),
    // remove from queue + already not in queue
    (null, _) => null,
    // put somewhere in queue + already in queue
    (QueueInsertionPosition.preferred, TaskStatus.active) => null,
    (final pos?, _) => PutTaskInQueue(pos),
  };
}

@visibleForTesting
DateTime? getShiftedEndDate({
  required DateTime? newStart,
  required DateTime? previousStart,
  required DateTime? currentEnd,
}) {
  if (newStart == null || previousStart == null || currentEnd == null) {
    return null;
  }
  final duration = currentEnd.difference(previousStart);
  return newStart.add(duration);
}

@visibleForTesting
DateTime? getDefaultStartDate(DateTime? endDate) {
  if (endDate == null) return null;
  return DateTime(endDate.year, endDate.month, endDate.day);
}

@visibleForTesting
bool isQueueLocked(DateTime? date, DateTime now) {
  return date?.isBefore(now) ?? false;
}

@visibleForTesting
int mapSubtaskIndex(
  int relativeIndex,
  List<SubTaskController> subTaskControllers,
) {
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
