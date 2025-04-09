import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:round_task/models/task.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/widgets/task_card.dart';

class TaskQueueScreen extends ConsumerStatefulWidget {
  const TaskQueueScreen({super.key});

  @override
  ConsumerState<TaskQueueScreen> createState() => _TaskQueueScreenState();
}

class _TaskQueueScreenState extends ConsumerState<TaskQueueScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  bool _addToQueue = true;
  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _tabController.animation!.addListener(() {
      if (_tabController.indexIsChanging) {
        _addToQueue = _tabController.index == 0;
      } else {
        final index = _tabController.animation!.value.round();
        _addToQueue = index == 0;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(repositoryPod);

    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Consumer(
              builder: (context, ref, child) {
                final queuedTasks = ref.watch(queuedTasksPod);

                return switch (queuedTasks) {
                  AsyncData(:final value) =>
                    Tab(text: "Queued (${value.length})"),
                  _ => Tab(text: "Queued"),
                };
              },
            ),
            Consumer(
              builder: (context, ref, child) {
                final pendingTasks = ref.watch(pendingTasksPod);

                return switch (pendingTasks) {
                  AsyncData(:final value) =>
                    Tab(text: "Pending (${value.length})"),
                  _ => Tab(text: "Pending"),
                };
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Consumer(builder: (context, ref, child) {
            final queuedTasks = ref.watch(queuedTasksPod);
            return queuedTasks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  const Center(child: Text("An error occurred.")),
              data: (tasks) => ReorderableListView.builder(
                padding: EdgeInsets.only(bottom: 100),
                shrinkWrap: true,
                itemCount: tasks.length,
                onReorder: (oldIndex, newIndex) async {
                  if (oldIndex < newIndex) {
                    newIndex--;
                  }

                  // modifying the list directly is a big no-no
                  // but this is kind of fine because
                  // a new list is produced a few milliseconds later
                  // TODO: find a better way to do this
                  final task = tasks.removeAt(oldIndex);
                  tasks.insert(newIndex, task);

                  await repository.reorderTasks(tasks);
                },
                itemBuilder: (context, index) {
                  final task = tasks[index];

                  return SizedBox(
                    key: ValueKey(task.id),
                    width: double.infinity,
                    child: TaskCard(task: task),
                  );
                },
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
                error: (error, stackTrace) => const Center(
                  child: Text("An error occurred."),
                ),
                data: (tasks) => ListView.builder(
                  padding: EdgeInsets.only(bottom: 100),
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return TaskCard(key: ValueKey(task.id), task: task);
                  },
                ),
              );
            },
          ),
        ],
      ),
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
              _addToQueue,
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
