import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:round_task/db/db.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/screens/task_view.dart';
import 'package:round_task/widgets/app_drawer.dart';
import 'package:round_task/widgets/select_dropdown.dart';
import 'package:round_task/widgets/task_card.dart';

const _listPadding = EdgeInsets.only(bottom: 100, top: 40);

enum _QueuedTaskViewMode {
  orderByEndDate,
  orderByAutoInsertDate,
  orderByReference,
  groupByPriority,
}

class TaskQueueScreen extends ConsumerStatefulWidget {
  const TaskQueueScreen({super.key});

  @override
  ConsumerState<TaskQueueScreen> createState() => _TaskQueueScreenState();
}

class _TaskQueueScreenState extends ConsumerState<TaskQueueScreen>
    with SingleTickerProviderStateMixin {
  final _bucket = PageStorageBucket();
  late final TabController _tabController;
  final _currentIndex = ValueNotifier(0);
  final _searchFocusNode = FocusNode();
  final _searchController = SearchController();

  var _searchStatus = TaskStatus.active;
  var _queuedTasksViewMode = _QueuedTaskViewMode.orderByReference;
  var _pendingTasksSorting = TaskSorting.creationDate;

  TaskSorting? get _queuedTasksSorting => switch (_queuedTasksViewMode) {
    _QueuedTaskViewMode.orderByEndDate => TaskSorting.endDate,
    _QueuedTaskViewMode.orderByAutoInsertDate => TaskSorting.autoInsertDate,
    _QueuedTaskViewMode.orderByReference ||
    _QueuedTaskViewMode.groupByPriority => null,
  };

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _tabController.animation!.addListener(() {
      final index = _tabController.indexIsChanging
          ? _tabController.index
          : _tabController.animation!.value.round();

      _currentIndex.value = index;
      _searchStatus = switch (index) {
        1 => TaskStatus.pending,
        2 => TaskStatus.archived,
        _ => TaskStatus.active,
      };
    });
  }

  @override
  void dispose() {
    _currentIndex.dispose();
    _tabController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();

    super.dispose();
  }

  void _unfocusSearchBar() {
    _searchFocusNode.unfocus();
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
  }

  Widget _buildTask(UserTask task) => SizedBox(
    key: ValueKey(task.id),
    width: double.infinity,
    child: TaskCard(task: task),
  );

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databasePod);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: SearchAnchor(
                  searchController: _searchController,
                  isFullScreen: true,
                  viewBuilder: (suggestions) {
                    return SafeArea(
                      top: false,
                      bottom: false,
                      child: _TaskSearchView(
                        searchController: _searchController,
                        statusFilter: _searchStatus,
                      ),
                    );
                  },
                  builder: (context, controller) {
                    return SearchBar(
                      controller: controller,
                      focusNode: _searchFocusNode,
                      hintText: context.tr("search"),
                      leading: const AppDrawerButton(),
                      onTapOutside: (event) {
                        _unfocusSearchBar();
                      },
                      onTap: () {
                        _unfocusSearchBar();
                        controller.openView();
                      },
                      onChanged: (value) {
                        _unfocusSearchBar();
                        controller.openView();
                      },
                    );
                  },
                  suggestionsBuilder: (context, controller) => const [],
                  viewLeading: BackButton(
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _unfocusSearchBar();
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageStorage(
                bucket: _bucket,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final queuedTasks = ref.watch(
                          queuedTasksPod(_queuedTasksSorting),
                        );
                        return queuedTasks.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) =>
                              Center(child: Text(context.tr("general_error"))),
                          data: (tasks) => _QueuedTasksTab(
                            mode: _queuedTasksViewMode,
                            tasks: tasks,
                            database: database,
                            onModeChanged: (sorting) {
                              setState(() {
                                _queuedTasksViewMode = sorting;
                              });
                            },
                          ),
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final pendingTasks = ref.watch(
                          pendingTasksPod(_pendingTasksSorting),
                        );

                        return pendingTasks.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) =>
                              Center(child: Text(context.tr("general_error"))),
                          data: (tasks) => _PendingTasksTab(
                            sorting: _pendingTasksSorting,
                            tasks: tasks,
                            onSortingChanged: (sorting) {
                              setState(() {
                                _pendingTasksSorting = sorting;
                              });
                            },
                          ),
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final archivedTasks = ref.watch(archivedTasksPod);

                        return archivedTasks.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) =>
                              Center(child: Text(context.tr("general_error"))),
                          data: (tasks) => AnimatedReorderableListView(
                            key: const PageStorageKey("archivedTasks"),
                            padding: _listPadding,
                            shrinkWrap: true,
                            items: tasks,
                            isSameItem: (a, b) => a.id == b.id,
                            onReorder: (oldIndex, newIndex) {},
                            nonDraggableItems: tasks,
                            enableSwap: true,
                            itemBuilder: (context, index) =>
                                _buildTask(tasks[index]),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: _currentIndex,
        builder: (context, selectedIndex, child) {
          return NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (value) {
              _tabController.index = value;
            },
            destinations: [
              Consumer(
                builder: (context, ref, child) {
                  final queuedTasks = ref.watch(
                    queuedTasksPod(_queuedTasksSorting),
                  );

                  final label = switch (queuedTasks) {
                    AsyncData(value: List(isNotEmpty: true, :final length)) =>
                      context.tr("queued.amount", args: [length.toString()]),
                    _ => context.tr("queued.none"),
                  };

                  return NavigationDestination(
                    icon: const Icon(Icons.low_priority),
                    label: label,
                  );
                },
              ),
              Consumer(
                builder: (context, ref, child) {
                  final pendingTasks = ref.watch(
                    pendingTasksPod(_pendingTasksSorting),
                  );

                  final label = switch (pendingTasks) {
                    AsyncData(value: List(isNotEmpty: true, :final length)) =>
                      context.tr("pending.amount", args: [length.toString()]),
                    _ => context.tr("pending.none"),
                  };

                  return NavigationDestination(
                    icon: const Icon(Icons.pending_actions),
                    label: label,
                  );
                },
              ),
              Consumer(
                builder: (context, ref, child) {
                  final archivedTasks = ref.watch(archivedTasksPod);

                  final label = switch (archivedTasks) {
                    AsyncData(value: List(isNotEmpty: true, :final length)) =>
                      context.tr("archived.amount", args: [length.toString()]),
                    _ => context.tr("archived.none"),
                  };

                  return NavigationDestination(
                    icon: const Icon(Icons.archive),
                    label: label,
                  );
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push(
            "/task",
            extra: TaskViewParams(
              null,
              addToQueue: _searchStatus == TaskStatus.active,
              autofocusTitle: true,
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _QueuedTasksTab extends StatefulWidget {
  const _QueuedTasksTab({
    required this.mode,
    required this.tasks,
    required this.database,
    this.onModeChanged,
  });

  final _QueuedTaskViewMode mode;
  final AppDatabase database;
  final List<UserTask> tasks;
  final void Function(_QueuedTaskViewMode)? onModeChanged;

  @override
  State<_QueuedTasksTab> createState() => _QueuedTasksTabState();
}

class _QueuedTasksTabState extends State<_QueuedTasksTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mode = widget.mode;
    final tasks = widget.tasks;
    final database = widget.database;

    return Column(
      children: [
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SelectDropdown(
              items: [
                DropdownMenuItem(
                  value: _QueuedTaskViewMode.orderByReference,
                  child: Text(context.tr("order.default")),
                ),
                DropdownMenuItem(
                  value: _QueuedTaskViewMode.orderByEndDate,
                  child: Text(context.tr("order.by_end_date")),
                ),
                DropdownMenuItem(
                  value: _QueuedTaskViewMode.orderByAutoInsertDate,
                  child: Text(context.tr("order.by_start_date")),
                ),
                DropdownMenuItem(
                  value: _QueuedTaskViewMode.groupByPriority,
                  child: Text(context.tr("order.group_by_priority")),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                widget.onModeChanged?.call(value);
              },
              value: mode,
            ),
          ),
        ),
        Expanded(
          child: mode == _QueuedTaskViewMode.groupByPriority
              ? _buildGroupedByPriority(database)
              : _buildNormalList(database: database, mode: mode, tasks: tasks),
        ),
      ],
    );
  }

  Widget _buildNormalList({
    required AppDatabase database,
    required _QueuedTaskViewMode mode,
    required List<UserTask> tasks,
  }) {
    return AnimatedReorderableListView<UserTask>(
      enableSwap: true,
      padding: _listPadding,
      shrinkWrap: true,
      items: tasks,
      isSameItem: (a, b) => a.id == b.id,
      nonDraggableItems: mode == _QueuedTaskViewMode.orderByReference
          ? const []
          : tasks,
      onReorder: (oldIndex, newIndex) async {
        final task = tasks.removeAt(oldIndex);
        tasks.insert(newIndex, task);

        await database.reorderTasks(tasks);
      },
      itemBuilder: (context, index) => _buildTask(tasks[index]),
    );
  }

  Widget _buildGroupedByPriority(AppDatabase database) {
    const importantUrgent = TaskPriority(important: true, urgent: true);
    const importantNotUrgent = TaskPriority(important: true, urgent: false);
    const notImportantUrgent = TaskPriority(important: false, urgent: true);
    const notImportantNotUrgent = TaskPriority(important: false, urgent: false);

    return Consumer(
      builder: (context, ref, child) {
        final groupedTasks = ref.watch(groupedQueuedTasksPod);

        if (groupedTasks.hasError) {
          return Center(child: Text(context.tr("general_error")));
        }

        if (groupedTasks.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final theme = Theme.of(context);
        final groups = groupedTasks.value!;

        Widget? group(TaskPriority priority, String translationKey) {
          final tasks = groups[priority];
          if (tasks == null || tasks.isEmpty) {
            return null;
          }

          return SliverMainAxisGroup(
            key: ValueKey(priority),
            slivers: [
              PinnedHeaderSliver(
                child: Material(
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          context.tr(
                            translationKey,
                            args: [tasks.length.toString()],
                          ),
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                ),
              ),
              ReorderableAnimatedListImpl(
                scrollDirection: Axis.vertical,
                enableSwap: true,
                items: tasks,
                isSameItem: (a, b) => a.id == b.id,
                itemBuilder: (context, index) => _buildTask(tasks[index]),
                nonDraggableItems: tasks,
              ),
            ],
          );
        }

        return CustomScrollView(
          slivers: [
            ?group(importantUrgent, "task_priority_group.important_urgent"),
            ?group(
              importantNotUrgent,
              "task_priority_group.important_not_urgent",
            ),
            ?group(
              notImportantUrgent,
              "task_priority_group.not_important_urgent",
            ),
            ?group(
              notImportantNotUrgent,
              "task_priority_group.not_important_not_urgent",
            ),
          ],
        );
      },
    );
  }
}

class _PendingTasksTab extends StatefulWidget {
  const _PendingTasksTab({
    required this.sorting,
    required this.tasks,
    this.onSortingChanged,
  });

  final TaskSorting sorting;
  final List<UserTask> tasks;
  final void Function(TaskSorting)? onSortingChanged;
  @override
  State<_PendingTasksTab> createState() => __PendingTasksTabState();
}

class __PendingTasksTabState extends State<_PendingTasksTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sorting = widget.sorting;
    final tasks = widget.tasks;

    return Column(
      children: [
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SelectDropdown(
              items: [
                DropdownMenuItem(
                  value: TaskSorting.creationDate,
                  child: Text(context.tr("order.default")),
                ),
                DropdownMenuItem(
                  value: TaskSorting.endDate,
                  child: Text(context.tr("order.by_end_date")),
                ),
                DropdownMenuItem(
                  value: TaskSorting.autoInsertDate,
                  child: Text(context.tr("order.by_start_date")),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                widget.onSortingChanged?.call(value);
              },
              value: sorting,
            ),
          ),
        ),
        Expanded(
          child: AnimatedReorderableListView(
            padding: _listPadding,
            shrinkWrap: true,
            items: tasks,
            isSameItem: (a, b) => a.id == b.id,
            onReorder: (oldIndex, newIndex) {},
            nonDraggableItems: tasks,
            enableSwap: true,
            itemBuilder: (context, index) => _buildTask(tasks[index]),
          ),
        ),
      ],
    );
  }
}

class _TaskSearchView extends StatefulWidget {
  const _TaskSearchView({
    required this.searchController,
    required this.statusFilter,
  });

  final TaskStatus statusFilter;
  final TextEditingController searchController;

  @override
  State<_TaskSearchView> createState() => _TaskSearchViewState();
}

class _TaskSearchViewState extends State<_TaskSearchView> {
  List<UserTask> _previousResults = [];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.searchController,
      builder: (context, value, child) {
        return Consumer(
          builder: (context, ref, child) {
            final filter = TaskFilter(
              status: widget.statusFilter,
              searchQuery: value.text,
            );
            final data = ref.watch(filteredTasksPod(filter));

            if (data case AsyncError()) {
              return Center(child: Text(context.tr("general_error")));
            }

            final tasks = data.valueOrNull ?? _previousResults;
            _previousResults = tasks;

            return Stack(
              children: [
                AnimatedOpacity(
                  opacity: data.isLoading ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: const LinearProgressIndicator(),
                ),
                ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildTask(task);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Widget _buildTask(UserTask task) => SizedBox(
  key: ValueKey(task.id),
  width: double.infinity,
  child: TaskCard(task: task),
);
