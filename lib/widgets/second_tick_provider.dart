import 'dart:async';

import 'package:flutter/widgets.dart';

/// Provides a second ticker used by task cards to keep their
/// relative time strings up to date.
class SecondTickProvider extends StatefulWidget {
  const SecondTickProvider({super.key, required this.child});

  final Widget child;

  static int of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SecondTick>()!
        .notifier!
        .value;
  }

  @override
  State<SecondTickProvider> createState() => _SecondTickProviderState();
}

class _SecondTickProviderState extends State<SecondTickProvider> {
  final _notifier = _SecondNotifier();

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SecondTick(notifier: _notifier, child: widget.child);
  }
}

class _SecondNotifier extends ValueNotifier<int> {
  _SecondNotifier() : super(0) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      value = timer.tick;
    });
  }

  late Timer _timer;

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

class _SecondTick extends InheritedNotifier<_SecondNotifier> {
  const _SecondTick({required super.notifier, required super.child});
}
