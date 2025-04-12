import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:round_task/models/task.dart';

class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
  });

  final UserTask task;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    // TODO: add quick actions: start, send to end of queue, archive, delete
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push("/task", extra: (widget.task, false));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  if (task.description.isNotEmpty)
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  if (task.endDate case final endDate?)
                    Text(DateFormat.yMMMMd("pt_BR").add_jm().format(endDate))
                ],
              ),
            ),
            if (task.progress case final progress?)
              LinearProgressIndicator(value: progress)
          ],
        ),
      ),
    );
  }
}
