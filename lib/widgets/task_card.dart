import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_task/custom_colors.dart';
import 'package:round_task/models/task.dart';
import 'package:round_task/widgets/animated_progress_bar.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
  });

  final UserTask task;

  String _formatDate(String locale, DateTime now, DateTime date) {
    if (now.year != date.year) {
      return DateFormat.yMMMEd(locale).add_jm().format(date);
    }
    if (now.month != date.month) {
      return DateFormat.MMMEd(locale).add_jm().format(date);
    }
    if (now.day != date.day) {
      return DateFormat("E d,", locale).add_jm().format(date);
    }

    return DateFormat.jm(locale).format(date);
  }

  @override
  Widget build(BuildContext context) {
    late final locale = Localizations.localeOf(context).toLanguageTag();
    late final customColors = Theme.of(context).extension<CustomColors>()!;
    final ColorScheme(:outlineVariant, :surfaceContainerLow) =
        ColorScheme.of(context);
    final now = DateTime.now();

    final tintColor = switch (task.endDate) {
      final endDate? when endDate.isBefore(now) => customColors.overdueColor,
      final endDate? when endDate.isBefore(now.add(const Duration(days: 1))) =>
        customColors.untilTodayColor,
      _ => null,
    };

    final borderColor = switch (tintColor) {
      null => outlineVariant,
      _ => Color.alphaBlend(tintColor.withAlpha(75), outlineVariant),
    };

    final backgroundColor = switch (tintColor) {
      null => surfaceContainerLow,
      _ => Color.alphaBlend(tintColor.withAlpha(20), surfaceContainerLow),
    };

    // TODO: add quick actions: start, send to end of queue, archive, delete
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12.0)),
        side: BorderSide(color: borderColor),
      ),
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          context.push("/task", extra: (task, false));
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
                  if (task case UserTask(reference: _?, :final endDate?))
                    Text(
                      context.tr("task_card_end", args: [
                        _formatDate(locale, now, endDate),
                      ]),
                    )
                  else if (task
                      case UserTask(reference: null, :final autoInsertDate?))
                    Text(
                      context.tr("task_card_start", args: [
                        _formatDate(locale, now, autoInsertDate),
                      ]),
                    ),
                ],
              ),
            ),
            if (task.progress case final progress?)
              AnimatedProgressBar(
                value: progress,
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeInOut,
              )
          ],
        ),
      ),
    );
  }
}
