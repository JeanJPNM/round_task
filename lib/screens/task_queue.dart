import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:round_task/db/db.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/screens/task_view.dart';
import 'package:round_task/widgets/task_card.dart';
import 'package:round_task/widgets/time_tracking_banner.dart';

const _listPadding = EdgeInsets.only(bottom: 100, top: 40);

class TaskQueueScreen extends ConsumerStatefulWidget {
  const TaskQueueScreen({super.key});

  @override
  ConsumerState<TaskQueueScreen> createState() => _TaskQueueScreenState();
}

class _TaskQueueScreenState extends ConsumerState<TaskQueueScreen>
    with TickerProviderStateMixin {
  final _bucket = PageStorageBucket();
  late final TabController _tabController;
  final _currentIndex = ValueNotifier(0);
  final _searchFocusNode = FocusNode();
  final _searchController = SearchController();

  TaskStatus _searchStatus = TaskStatus.active;
  TaskSorting? _queuedTasksSorting;
  TaskSorting _pendingTasksSorting = TaskSorting.creationDate;

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

    return TimeTrackingScreenWrapper(
      child: Scaffold(
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
                        child: ListView(
                          children: suggestions.toList(),
                        ),
                      );
                    },
                    builder: (context, controller) {
                      return SearchBar(
                        controller: controller,
                        focusNode: _searchFocusNode,
                        hintText: context.tr("search"),
                        leading: const Icon(Icons.search),
                        trailing: [
                          IconButton(
                            onPressed: () {
                              _unfocusSearchBar();
                              context.push("/settings");
                            },
                            icon: const Icon(Icons.settings),
                          )
                        ],
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
                    suggestionsBuilder: (context, controller) async {
                      final tasks = await database.searchTasks(
                        _searchStatus,
                        controller.text,
                      );
                      return tasks.map((task) => TaskCard(
                            key: ValueKey(task.id),
                            task: task,
                          ));
                    },
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
                      Consumer(builder: (context, ref, child) {
                        final queuedTasks =
                            ref.watch(queuedTasksPod(_queuedTasksSorting));
                        return queuedTasks.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) => Center(
                            child: Text(context.tr("general_error")),
                          ),
                          data: (tasks) => _QueuedTasksTab(
                            sorting: _queuedTasksSorting,
                            tasks: tasks,
                            database: database,
                            onSortingChanged: (sorting) {
                              setState(() {
                                _queuedTasksSorting = sorting;
                              });
                            },
                          ),
                        );
                      }),
                      Consumer(
                        builder: (context, ref, child) {
                          final pendingTasks =
                              ref.watch(pendingTasksPod(_pendingTasksSorting));

                          return pendingTasks.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, stackTrace) => Center(
                              child: Text(context.tr("general_error")),
                            ),
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
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (error, stackTrace) => Center(
                              child: Text(context.tr("general_error")),
                            ),
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
                      )
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
                      final queuedTasks =
                          ref.watch(queuedTasksPod(_queuedTasksSorting));

                      final label = switch (queuedTasks) {
                        AsyncData(
                          value: List(isNotEmpty: true, :final length)
                        ) =>
                          context.tr(
                            "queued.amount",
                            args: [length.toString()],
                          ),
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
                      final pendingTasks =
                          ref.watch(pendingTasksPod(_pendingTasksSorting));

                      final label = switch (pendingTasks) {
                        AsyncData(
                          value: List(isNotEmpty: true, :final length)
                        ) =>
                          context.tr(
                            "pending.amount",
                            args: [length.toString()],
                          ),
                        _ => context.tr("pending.none"),
                      };

                      return NavigationDestination(
                        icon: const Icon(Icons.pending_actions),
                        label: label,
                      );
                    },
                  ),
                  Consumer(builder: (context, ref, child) {
                    final archivedTasks = ref.watch(archivedTasksPod);

                    final label = switch (archivedTasks) {
                      AsyncData(value: List(isNotEmpty: true, :final length)) =>
                        context.tr(
                          "archived.amount",
                          args: [length.toString()],
                        ),
                      _ => context.tr("archived.none"),
                    };

                    return NavigationDestination(
                      icon: const Icon(Icons.archive),
                      label: label,
                    );
                  }),
                ],
              );
            }),
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
      ),
    );
  }
}

class _QueuedTasksTab extends StatefulWidget {
  const _QueuedTasksTab({
    required this.sorting,
    required this.tasks,
    required this.database,
    this.onSortingChanged,
  });

  final TaskSorting? sorting;
  final AppDatabase database;
  final List<UserTask> tasks;
  final void Function(TaskSorting?)? onSortingChanged;

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
    final sorting = widget.sorting;
    final tasks = widget.tasks;
    final database = widget.database;

    return Column(
      children: [
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _SortingPicker(
              defaultSorting: null,
              sorting: sorting,
              entries: [
                TaskSorting.endDate,
                TaskSorting.autoInsertDate,
              ],
              onSortingChanged: (value) {
                widget.onSortingChanged?.call(value);
              },
            ),
          ),
        ),
        Expanded(
          child: AnimatedReorderableListView<UserTask>(
            enableSwap: true,
            padding: _listPadding,
            shrinkWrap: true,
            items: tasks,
            isSameItem: (a, b) => a.id == b.id,
            nonDraggableItems: sorting == null ? const [] : tasks,
            onReorder: (oldIndex, newIndex) async {
              final task = tasks.removeAt(oldIndex);
              tasks.insert(newIndex, task);

              await database.reorderTasks(tasks);
            },
            itemBuilder: (context, index) => _buildTask(tasks[index]),
          ),
        ),
      ],
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
            child: _SortingPicker(
              defaultSorting: TaskSorting.creationDate,
              onSortingChanged: (TaskSorting? value) {
                if (value != null) {
                  widget.onSortingChanged?.call(value);
                }
              },
              sorting: sorting,
              entries: [
                TaskSorting.endDate,
                TaskSorting.autoInsertDate,
              ],
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

class _SortingPicker extends StatelessWidget {
  const _SortingPicker({
    required this.defaultSorting,
    required this.entries,
    required this.sorting,
    this.onSortingChanged,
  });

  final TaskSorting? defaultSorting;
  final List<TaskSorting> entries;
  final TaskSorting? sorting;
  final void Function(TaskSorting?)? onSortingChanged;

  String _getSortingLabel(TaskSorting sorting) {
    return switch (sorting) {
      TaskSorting.endDate => "order.by_end_date",
      TaskSorting.autoInsertDate => "order.by_start_date",
      TaskSorting.creationDate => "order.by_creation_date",
    };
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton(
      items: [
        DropdownMenuItem(
          value: defaultSorting,
          child: Text(context.tr("order.default")),
        ),
        for (final entry in entries)
          DropdownMenuItem(
            value: entry,
            child: Text(context.tr(_getSortingLabel(entry))),
          ),
      ],
      onChanged: (value) => onSortingChanged?.call(value),
      borderRadius: BorderRadius.circular(8.0),
      value: sorting,
      underline: const SizedBox.shrink(),
    );
  }
}

Widget _buildTask(UserTask task) => SizedBox(
      key: ValueKey(task.id),
      width: double.infinity,
      child: TaskCard(task: task),
    );
