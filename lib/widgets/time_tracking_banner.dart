import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:round_task/db/database.dart';
import 'package:round_task/formatting.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/screens/task_view.dart';
import 'package:round_task/widgets/second_tick_provider.dart';

const _duration = Duration(milliseconds: 500);
const _curve = Curves.easeInOut;

class TimeTrackingBanner extends StatelessWidget {
  const TimeTrackingBanner({
    super.key,
    required this.task,
  });

  final UserTask task;
  @override
  Widget build(BuildContext context) {
    SecondTickProvider.of(context);

    final now = DateTime.now();
    final duration = now.difference(task.activeTimeMeasurementStart ?? now);

    return FilledButton(
      onPressed: () {
        context.push("/task", extra: TaskViewParams(task));
      },
      style: const ButtonStyle(
        shape: WidgetStatePropertyAll(LinearBorder()),
      ),
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: IntrinsicHeight(
            child: Row(
              key: ValueKey(task.id),
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(formatDuration(duration)),
                const VerticalDivider(),
                Flexible(
                  child: Text(
                    task.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TimeTrackingScreenWrapper extends ConsumerWidget {
  const TimeTrackingScreenWrapper({
    super.key,
    required this.child,
    this.disabled = false,
  });

  final bool disabled;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentlyTrackedTask = ref.watch(currentlyTrackedTaskPod).valueOrNull;
    late final colorScheme = Theme.of(context).colorScheme;
    late final statusBarBrightness =
        ThemeData.estimateBrightnessForColor(colorScheme.onPrimary);
    final hideBanner = disabled || currentlyTrackedTask == null;

    return Column(
      children: [
        AnimatedSwitcher(
          duration: _duration,
          switchInCurve: _curve,
          switchOutCurve: _curve,
          transitionBuilder: (child, animation) {
            return SizeTransition(
              sizeFactor: animation,
              axis: Axis.vertical,
              child: child,
            );
          },
          child: hideBanner
              ? const SizedBox.shrink()
              : AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarBrightness: statusBarBrightness,
                    statusBarIconBrightness: statusBarBrightness,
                  ),
                  child: TimeTrackingBanner(task: currentlyTrackedTask),
                ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            removeTop: !hideBanner,
            context: context,
            child: child,
          ),
        ),
      ],
    );
  }
}
