import 'package:flutter/material.dart';

class AnimatedProgressBar extends ImplicitlyAnimatedWidget {
  const AnimatedProgressBar({
    super.key,
    super.curve,
    required super.duration,
    super.onEnd,
    required this.value,
    this.backgroundColor,
    this.valueColor,
    this.borderRadius,
    this.color,
    this.minHeight,
    this.semanticsLabel,
    this.semanticsValue,
    this.stopIndicatorColor,
    this.stopIndicatorRadius,
    this.trackGap,
  });

  final double value;
  final Color? backgroundColor;

  final Animation<Color?>? valueColor;
  final BorderRadius? borderRadius;
  final Color? color;
  final double? minHeight;
  final String? semanticsLabel;
  final String? semanticsValue;
  final Color? stopIndicatorColor;
  final double? stopIndicatorRadius;
  final double? trackGap;

  @override
  ImplicitlyAnimatedWidgetState<AnimatedProgressBar> createState() =>
      _AnimatedProgressBarState();
}

class _AnimatedProgressBarState
    extends ImplicitlyAnimatedWidgetState<AnimatedProgressBar> {
  Tween<double>? _value;
  late Animation<double> _valueAnimation;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _value = visitor(_value, widget.value,
        (value) => Tween<double>(begin: value as double)) as Tween<double>?;
  }

  @override
  void didUpdateTweens() {
    _valueAnimation = animation.drive(_value!);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _valueAnimation,
      builder: (context, child) {
        return LinearProgressIndicator(
          value: _valueAnimation.value,
          backgroundColor: widget.backgroundColor,
          valueColor: widget.valueColor,
          borderRadius: widget.borderRadius,
          color: widget.color,
          minHeight: widget.minHeight,
          semanticsLabel: widget.semanticsLabel,
          semanticsValue: widget.semanticsValue,
          stopIndicatorColor: widget.stopIndicatorColor,
          stopIndicatorRadius: widget.stopIndicatorRadius,
          trackGap: widget.trackGap,
        );
      },
    );
  }
}
