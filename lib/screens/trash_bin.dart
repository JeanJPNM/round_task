import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/widgets/app_drawer.dart';
import 'package:round_task/widgets/task_card.dart';

class TrashBinScreen extends ConsumerWidget {
  const TrashBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databasePod);
    final softDeletedTasks = ref.watch(softDeletedTasksPod);

    return Scaffold(
      appBar: AppBar(
        leading: const AppDrawerButton(),
        title: Text(context.tr("trash_bin.title")),
        actions: [
          if (softDeletedTasks case AsyncData(value: List(isNotEmpty: true)))
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: context.tr("trash_bin.clear"),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      context.tr("trash_bin.clear_confirmation.title"),
                    ),
                    content: Text(
                      context.tr("trash_bin.clear_confirmation.content"),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(context.tr("cancel")),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(context.tr("confirm")),
                      ),
                    ],
                  ),
                );

                if (confirmed != true) return;
                await database.clearSoftDeletedTasks();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr("trash_bin.cleared"))),
                  );
                }
              },
            ),
        ],
      ),
      body: softDeletedTasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(child: Text(context.tr("trash_bin.empty")));
          }
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    context.tr("trash_bin.info"),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return TaskCard(task: task);
                },
              ),
            ].map((sliver) => SliverSafeArea(sliver: sliver)).toList(),
          );
        },
      ),
    );
  }
}
