import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:round_task/models/task.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/widgets/task_card.dart';

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
  final _searchFocusNode = FocusNode();
  final _searchController = SearchController();

  TaskSearchType _searchType = TaskSearchType.queued;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _tabController.animation!.addListener(() {
      final index = _tabController.indexIsChanging
          ? _tabController.index
          : _tabController.animation!.value.round();

      _searchType = switch (index) {
        1 => TaskSearchType.pending,
        2 => TaskSearchType.archived,
        _ => TaskSearchType.queued,
      };
    });
  }

  @override
  void dispose() {
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
    final repository = ref.watch(repositoryPod);

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
                  builder: (context, controller) {
                    return SearchBar(
                      controller: controller,
                      focusNode: _searchFocusNode,
                      hintText: context.tr("search"),
                      leading: const Icon(Icons.search),
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
                    final tasks = await repository.searchTasks(
                      _searchType,
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
                      final queuedTasks = ref.watch(queuedTasksPod);
                      return queuedTasks.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => Center(
                          child: Text(context.tr("general_error")),
                        ),
                        data: (tasks) => AnimatedReorderableListView(
                          key: const PageStorageKey("queuedTasks"),
                          padding: _listPadding,
                          shrinkWrap: true,
                          items: tasks,
                          isSameItem: (a, b) => a.id == b.id,
                          onReorder: (oldIndex, newIndex) async {
                            // modifying the list directly is a big no-no
                            // but this is kind of fine because
                            // a new list is produced a few milliseconds later
                            // TODO: find a better way to do this
                            final task = tasks.removeAt(oldIndex);
                            tasks.insert(newIndex, task);

                            await repository.reorderTasks(tasks);
                          },
                          itemBuilder: (context, index) =>
                              _buildTask(tasks[index]),
                        ),
                      );
                    }),
                    Consumer(
                      builder: (context, ref, child) {
                        final pendingTasks = ref.watch(pendingTasksPod);

                        return pendingTasks.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, stackTrace) => Center(
                            child: Text(context.tr("general_error")),
                          ),
                          data: (tasks) => AnimatedReorderableListView(
                            key: const PageStorageKey("pendingTasks"),
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
      bottomNavigationBar: ListenableBuilder(
          listenable: _tabController,
          builder: (context, child) {
            return NavigationBar(
              selectedIndex: _tabController.index,
              onDestinationSelected: (value) {
                _tabController.index = value;
              },
              destinations: [
                Consumer(
                  builder: (context, ref, child) {
                    final queuedTasks = ref.watch(queuedTasksPod);

                    final label = switch (queuedTasks) {
                      AsyncData(value: List(isNotEmpty: true, :final length)) =>
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
                    final pendingTasks = ref.watch(pendingTasksPod);

                    final label = switch (pendingTasks) {
                      AsyncData(value: List(isNotEmpty: true, :final length)) =>
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
            extra: (
              UserTask(
                title: '',
                description: '',
                lastTouched: DateTime.now(),
                creationDate: DateTime.now(),
              ),
              _searchType == TaskSearchType.queued,
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
