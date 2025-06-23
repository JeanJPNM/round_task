import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    required this.deleteSurface,
    required this.untilTodayColor,
    required this.overdueColor,
  });

  static const light = CustomColors(
    deleteSurface: Colors.red,
    untilTodayColor: Colors.amber,
    overdueColor: Colors.red,
  );
  static const dark = CustomColors(
    deleteSurface: Colors.redAccent,
    untilTodayColor: Colors.amberAccent,
    overdueColor: Colors.redAccent,
  );

  final Color deleteSurface;
  final Color untilTodayColor;
  final Color overdueColor;

  @override
  CustomColors copyWith({
    Color? deleteSurface,
    Color? untilTodayColor,
    Color? overdueColor,
  }) {
    return CustomColors(
      deleteSurface: deleteSurface ?? this.deleteSurface,
      untilTodayColor: untilTodayColor ?? this.untilTodayColor,
      overdueColor: overdueColor ?? this.overdueColor,
    );
  }

  @override
  CustomColors lerp(covariant ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) return this;
    return CustomColors(
      deleteSurface: Color.lerp(deleteSurface, other.deleteSurface, t)!,
      untilTodayColor: Color.lerp(untilTodayColor, other.untilTodayColor, t)!,
      overdueColor: Color.lerp(overdueColor, other.overdueColor, t)!,
    );
  }

  CustomColors harmonized(ColorScheme colorScheme) {
    return copyWith(
      deleteSurface: deleteSurface.harmonizeWith(colorScheme.primary),
      untilTodayColor: untilTodayColor.harmonizeWith(colorScheme.primary),
      overdueColor: overdueColor.harmonizeWith(colorScheme.primary),
    );
  }
}

extension BrightnessExtension on Brightness {
  Brightness get opposite {
    return switch (this) {
      Brightness.light => Brightness.dark,
      Brightness.dark => Brightness.light,
    };
  }
}
