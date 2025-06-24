import 'package:flutter/material.dart';

class BottomSheetSafeArea extends StatelessWidget {
  const BottomSheetSafeArea({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 80),
    this.basePadding = EdgeInsets.zero,
  });

  final EdgeInsets basePadding;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      curve: Curves.easeInCubic,
      duration: duration,
      padding:
          basePadding + padding + EdgeInsets.only(bottom: viewInsets.bottom),
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        child: child,
      ),
    );
  }
}
