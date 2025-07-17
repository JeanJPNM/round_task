import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:round_task/db/database.dart';
import 'package:round_task/formatting.dart';
import 'package:round_task/provider.dart';
import 'package:round_task/screens/task_view.dart';
import 'package:round_task/widgets/second_tick_provider.dart';

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

class TimeTrackingBannerShell extends ConsumerWidget {
  const TimeTrackingBannerShell({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeInOut,
    this.isDisabled = _defaultIsDisabled,
  });

  final Duration duration;
  final Curve curve;
  final bool Function(int trackedTaskId) isDisabled;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentlyTrackedTask = ref.watch(currentlyTrackedTaskPod).valueOrNull;
    late final colorScheme = Theme.of(context).colorScheme;
    late final statusBarBrightness =
        ThemeData.estimateBrightnessForColor(colorScheme.onPrimary);
    final hideBanner =
        currentlyTrackedTask == null || isDisabled(currentlyTrackedTask.id);

    return Column(
      children: [
        AnimatedSwitcher(
          duration: duration,
          switchInCurve: curve,
          switchOutCurve: curve.flipped,
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

bool _defaultIsDisabled(int trackedTaskId) => false;
