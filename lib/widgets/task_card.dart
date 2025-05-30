import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:relative_time/relative_time.dart';
import 'package:round_task/custom_colors.dart';
import 'package:round_task/models/task.dart';
import 'package:round_task/screens/task_view.dart';
import 'package:round_task/widgets/animated_progress_bar.dart';
import 'package:round_task/widgets/second_tick_provider.dart';

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
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;
    final ColorScheme(
      :outlineVariant,
      :surfaceContainerLow,
    ) = theme.colorScheme;
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

    final timeMessage = switch (task) {
      UserTask(reference: _?, :final endDate?) =>
        context.tr("task_card_end", args: [
          endDate.relativeTime(context),
          _formatDate(locale, now, endDate),
        ]),
      UserTask(reference: null, :final autoInsertDate?) =>
        context.tr("task_card_start", args: [
          autoInsertDate.relativeTime(context),
          _formatDate(locale, now, autoInsertDate),
        ]),
      _ => null,
    };

    if (timeMessage != null) {
      SecondTickProvider.of(context);
    }

    // TODO: add quick actions: start, send to end of queue, archive, delete
    const radius = Radius.circular(12.0);
    const paddingValue = 15.0;
    const borderWidth = 1.0;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(radius),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          context.push("/task", extra: TaskViewParams(task));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(paddingValue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.labelLarge,
                  ),
                  if (task.description.isNotEmpty)
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium,
                    ),
                  if (timeMessage != null) Text(timeMessage),
                ],
              ),
            ),
            if (task.progress case final progress?)
              Padding(
                padding: const EdgeInsets.only(
                  left: paddingValue,
                  right: paddingValue,
                  bottom: borderWidth,
                ),
                child: AnimatedProgressBar(
                  value: progress,
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeInOut,
                  borderRadius: const BorderRadius.only(
                    topRight: radius,
                    topLeft: radius,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
