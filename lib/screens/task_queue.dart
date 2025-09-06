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

const _selectPadding = EdgeInsets.only(left: 16, right: 16, top: 10);

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
    with TickerProviderStateMixin {
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

  void _onFabPressed() {
    context.push(
      "/task",
      extra: TaskViewParams(
        null,
        addToQueue: _searchStatus == TaskStatus.active,
        autofocusTitle: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databasePod);

    final searchBar = Padding(
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
              elevation: const WidgetStatePropertyAll(0),
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
    );

    final tabViewContent = TabBarView(
      controller: _tabController,
      children: [
        _QueuedTasksTab(
          mode: _queuedTasksViewMode,
          database: database,
          sorting: _queuedTasksSorting,
          onModeChanged: (mode) {
            setState(() {
              _queuedTasksViewMode = mode;
            });
          },
        ),
        _PendingTasksTab(
          sorting: _pendingTasksSorting,
          onSortingChanged: (sorting) {
            setState(() {
              _pendingTasksSorting = sorting;
            });
          },
        ),
        const _ArchivedTasksTab(),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > constraints.maxHeight;

        late final navigationRail = ValueListenableBuilder(
          valueListenable: _currentIndex,
          builder: (context, selectedIndex, child) {
            return NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) {
                _tabController.index = value;
              },
              labelType: NavigationRailLabelType.all,
              scrollable: true,
              destinations: [
                NavigationRailDestination(
                  icon: _TaskCountBadge(
                    pod: queuedTasksPod(_queuedTasksSorting),
                    child: const Icon(Icons.low_priority),
                  ),
                  label: Text(context.tr("queued.none")),
                ),
                NavigationRailDestination(
                  icon: _TaskCountBadge(
                    pod: pendingTasksPod(_pendingTasksSorting),
                    child: const Icon(Icons.pending_actions),
                  ),
                  label: Text(context.tr("pending.none")),
                ),
                NavigationRailDestination(
                  icon: _TaskCountBadge(
                    pod: archivedTasksPod,
                    child: const Icon(Icons.archive),
                  ),
                  label: Text(context.tr("archived.none")),
                ),
              ],
              trailing: FloatingActionButton(
                onPressed: _onFabPressed,
                child: const Icon(Icons.add),
              ),
            );
          },
        );

        late final navigationBar = ValueListenableBuilder(
          valueListenable: _currentIndex,
          builder: (context, selectedIndex, child) {
            return NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) {
                _tabController.index = value;
              },
              destinations: [
                NavigationDestination(
                  icon: _TaskCountBadge(
                    pod: queuedTasksPod(_queuedTasksSorting),
                    child: const Icon(Icons.low_priority),
                  ),
                  label: context.tr("queued.none"),
                ),
                NavigationDestination(
                  icon: _TaskCountBadge(
                    pod: pendingTasksPod(_pendingTasksSorting),
                    child: const Icon(Icons.pending_actions),
                  ),
                  label: context.tr("pending.none"),
                ),
                NavigationDestination(
                  icon: _TaskCountBadge(
                    pod: archivedTasksPod,
                    child: const Icon(Icons.archive),
                  ),
                  label: context.tr("archived.none"),
                ),
              ],
            );
          },
        );

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                searchBar,
                Expanded(
                  child: isWideScreen
                      ? Row(
                          children: [
                            navigationRail,
                            const VerticalDivider(),
                            Expanded(child: tabViewContent),
                          ],
                        )
                      : tabViewContent,
                ),
              ],
            ),
          ),
          bottomNavigationBar: isWideScreen ? null : navigationBar,
          floatingActionButton: isWideScreen
              ? null
              : FloatingActionButton(
                  onPressed: _onFabPressed,
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }
}

class _TaskCountBadge extends ConsumerWidget {
  const _TaskCountBadge({required this.pod, required this.child});
  final ProviderListenable<AsyncValue<List<UserTask>>> pod;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(pod);
    final theme = Theme.of(context);
    final count = tasks.valueOrNull?.length ?? 0;

    return Badge(
      backgroundColor: theme.colorScheme.primary,
      textColor: theme.colorScheme.onPrimary,
      isLabelVisible: count > 0,
      label: Text(count.toString()),
      child: child,
    );
  }
}

class _QueuedTasksTab extends ConsumerStatefulWidget {
  const _QueuedTasksTab({
    required this.mode,
    required this.database,
    required this.sorting,
    required this.onModeChanged,
  });

  final TaskSorting? sorting;
  final _QueuedTaskViewMode mode;
  final AppDatabase database;
  final void Function(_QueuedTaskViewMode) onModeChanged;

  @override
  ConsumerState<_QueuedTasksTab> createState() => __QueuedTasksTabState();
}

class __QueuedTasksTabState extends ConsumerState<_QueuedTasksTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const storageKey = PageStorageKey("queued_tasks");

    final mode = widget.mode;
    final database = widget.database;
    final tasksValue = ref.watch(queuedTasksPod(widget.sorting));

    if (tasksValue.isLoading) {
      return const _TabScrollView(
        storageKey: storageKey,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (tasksValue.hasError) {
      return _TabScrollView(
        storageKey: storageKey,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(context.tr("general_error"))),
          ),
        ],
      );
    }

    final tasks = tasksValue.value!;

    return _TabScrollView(
      storageKey: storageKey,
      header: SliverFloatingHeader(
        child: Material(
          child: Padding(
            padding: _selectPadding,
            child: Align(
              alignment: Alignment.centerRight,
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
                  widget.onModeChanged.call(value);
                },
                value: mode,
              ),
            ),
          ),
        ),
      ),
      slivers: [
        mode == _QueuedTaskViewMode.groupByPriority
            ? _buildGroupedByPriority(database)
            : _buildNormalList(database: database, mode: mode, tasks: tasks),
      ],
    );
  }

  Widget _buildNormalList({
    required AppDatabase database,
    required _QueuedTaskViewMode mode,
    required List<UserTask> tasks,
  }) {
    return ReorderableAnimatedListImpl<UserTask>(
      scrollDirection: Axis.vertical,
      enableSwap: true,
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

        return SliverMainAxisGroup(
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

class _PendingTasksTab extends ConsumerStatefulWidget {
  const _PendingTasksTab({required this.sorting, this.onSortingChanged});

  final TaskSorting sorting;
  final void Function(TaskSorting)? onSortingChanged;
  @override
  ConsumerState<_PendingTasksTab> createState() => __PendingTasksTabState();
}

class __PendingTasksTabState extends ConsumerState<_PendingTasksTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);

    const storageKey = PageStorageKey("pending_tasks");
    final sorting = widget.sorting;
    final tasksValue = ref.watch(pendingTasksPod(sorting));

    if (tasksValue.isLoading) {
      return const _TabScrollView(
        storageKey: storageKey,
        slivers: [
          SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (tasksValue.hasError) {
      return _TabScrollView(
        storageKey: storageKey,
        slivers: [
          SliverFillRemaining(
            child: Center(child: Text(context.tr("general_error"))),
          ),
        ],
      );
    }

    final tasks = tasksValue.value!;

    return _TabScrollView(
      storageKey: storageKey,
      header: SliverFloatingHeader(
        child: Material(
          child: Padding(
            padding: _selectPadding,
            child: Align(
              alignment: Alignment.centerRight,
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
        ),
      ),
      slivers: [
        ReorderableAnimatedListImpl(
          scrollDirection: Axis.vertical,
          items: tasks,
          isSameItem: (a, b) => a.id == b.id,
          onReorder: (oldIndex, newIndex) {},
          nonDraggableItems: tasks,
          enableSwap: true,
          itemBuilder: (context, index) => _buildTask(tasks[index]),
        ),
      ],
    );
  }
}

class _ArchivedTasksTab extends ConsumerStatefulWidget {
  const _ArchivedTasksTab();

  @override
  ConsumerState<_ArchivedTasksTab> createState() => __ArchivedTasksTabState();
}

class __ArchivedTasksTabState extends ConsumerState<_ArchivedTasksTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final archivedTasks = ref.watch(archivedTasksPod);

    return _TabScrollView(
      storageKey: const PageStorageKey("archived_tasks"),
      slivers: [
        archivedTasks.when(
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => SliverFillRemaining(
            child: Center(child: Text(context.tr("general_error"))),
          ),
          data: (tasks) => ReorderableAnimatedListImpl(
            scrollDirection: Axis.vertical,
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

class _TabScrollView extends StatelessWidget {
  const _TabScrollView({
    required this.storageKey,
    this.header,
    required this.slivers,
  });

  final PageStorageKey<String> storageKey;
  final Widget? header;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: storageKey,
      slivers: [
        ?header,
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}
