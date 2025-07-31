import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:relative_time/relative_time.dart';
import 'package:round_task/custom_colors.dart';
import 'package:round_task/db/database.dart';
import 'package:round_task/formatting.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/screens/task_view.dart';
import 'package:round_task/widgets/animated_progress_bar.dart';
import 'package:round_task/widgets/second_tick_provider.dart';

const _radius = Radius.circular(12.0);
const _paddingValue = 15.0;

class TaskCard extends ConsumerWidget {
  const TaskCard({
    super.key,
    required this.task,
  });

  final UserTask task;

  Widget _overrideThemes(ThemeData theme, Widget child) {
    return DefaultTextStyle(
      style: TextStyle(color: theme.colorScheme.onPrimary),
      child: Theme(
        data: ThemeData(
          textTheme: theme.textTheme.copyWith(
            labelLarge: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
            labelMedium: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
          progressIndicatorTheme: ProgressIndicatorThemeData(
            color: theme.colorScheme.inversePrimary,
            linearTrackColor: Color.alphaBlend(
              theme.colorScheme.onPrimary.withAlpha(75),
              theme.colorScheme.primary,
            ),
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;
    final ColorScheme(
      :outlineVariant,
      :surfaceContainerLow,
      :primary,
    ) = theme.colorScheme;

    final currentlyTrackedTask = ref.watch(currentlyTrackedTaskPod).valueOrNull;
    final now = DateTime.now();

    if (currentlyTrackedTask?.id == task.id) {
      final buttonStyle = const FilledButton(
        child: null,
        onPressed: null,
      ).defaultStyleOf(context);

      return Card.filled(
        clipBehavior: Clip.antiAlias,
        color: primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(_radius),
        ),
        child: _overrideThemes(
          theme,
          _TaskCardContent(
            task: task,
            now: now,
            overlayColor: buttonStyle.overlayColor,
          ),
        ),
      );
    }

    if (task.endDate != null) {
      SecondTickProvider.of(context);
    }

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

    const borderWidth = 1.0;

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(_radius),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      color: backgroundColor,
      child: _TaskCardContent(
        task: task,
        now: now,
        borderWidth: borderWidth,
      ),
    );
  }
}

class _TaskCardContent extends StatelessWidget {
  const _TaskCardContent({
    required this.task,
    required this.now,
    this.overlayColor,
    this.borderWidth = 0,
  });

  final DateTime now;
  final UserTask task;
  final double borderWidth;
  final WidgetStateProperty<Color?>? overlayColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageTag = Localizations.localeOf(context).toLanguageTag();

    final timeMessage = switch (task) {
      UserTask(status: TaskStatus.active, :final endDate?) =>
        context.tr("task_card_end", args: [
          endDate.relativeTime(context),
          formatDate(languageTag, now, endDate),
        ]),
      UserTask(status: TaskStatus.pending, :final autoInsertDate?) =>
        context.tr("task_card_start", args: [
          autoInsertDate.relativeTime(context),
          formatDate(languageTag, now, autoInsertDate),
        ]),
      _ => null,
    };

    if (timeMessage != null) {
      SecondTickProvider.of(context);
    }

    return InkWell(
      overlayColor: overlayColor,
      onTap: () {
        context.push("/task", extra: TaskViewParams(task));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(_paddingValue),
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
              padding: EdgeInsets.only(
                left: _paddingValue,
                right: _paddingValue,
                bottom: borderWidth,
              ),
              child: AnimatedProgressBar(
                value: progress,
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeInOut,
                borderRadius: const BorderRadius.vertical(top: _radius),
              ),
            )
        ],
      ),
    );
  }
}
