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
  const TimeTrackingBanner({super.key, required this.task});

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
      style: const ButtonStyle(shape: WidgetStatePropertyAll(LinearBorder())),
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
                  child: Text(task.title, overflow: TextOverflow.ellipsis),
                ),
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

  Widget _buildBanner(BuildContext context, UserTask task) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusBarBrightness = ThemeData.estimateBrightnessForColor(
      colorScheme.onPrimary,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: statusBarBrightness,
        statusBarIconBrightness: statusBarBrightness,
      ),
      child: TimeTrackingBanner(task: task),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentlyTrackedTask = ref.watch(currentlyTrackedTaskPod).valueOrNull;
    final hideBanner =
        currentlyTrackedTask == null || isDisabled(currentlyTrackedTask.id);

    return _AnimatedBannerShell(
      duration: duration,
      curve: curve,
      banner: hideBanner ? null : _buildBanner(context, currentlyTrackedTask),
      child: child,
    );
  }
}

class _AnimatedBannerShell extends StatefulWidget {
  const _AnimatedBannerShell({
    required this.duration,
    required this.curve,
    required this.banner,
    required this.child,
  });

  final Duration duration;
  final Curve curve;
  final Widget? banner;
  final Widget child;

  @override
  State<_AnimatedBannerShell> createState() => __AnimatedBannerShellState();
}

class __AnimatedBannerShellState extends State<_AnimatedBannerShell>
    with SingleTickerProviderStateMixin {
  Widget _currentBanner = const SizedBox.shrink();
  late final _controller = AnimationController(
    duration: widget.duration,
    vsync: this,
  );

  late final _animation = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
    reverseCurve: widget.curve.flipped,
  );

  @override
  void initState() {
    super.initState();

    if (widget.banner case final banner?) {
      _currentBanner = banner;
      _controller.value = 1.0;
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _currentBanner = const SizedBox.shrink();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedBannerShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    // we are not updating the animation properties
    // because they are not going to change anyway

    if (widget.banner != oldWidget.banner) {
      if (widget.banner case final banner?) {
        setState(() {
          _currentBanner = banner;
        });
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizeTransition(
          sizeFactor: _animation,
          axis: Axis.vertical,
          child: _currentBanner,
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final data = MediaQuery.of(context);
              final value = 1 - _animation.value;
              return MediaQuery(
                data: data.copyWith(
                  padding: data.padding.copyWith(top: data.padding.top * value),
                  viewPadding: data.viewPadding.copyWith(
                    top: data.viewPadding.top * value,
                  ),
                ),
                child: widget.child,
              );
            },
          ),
        ),
      ],
    );
  }
}

bool _defaultIsDisabled(int trackedTaskId) => false;
