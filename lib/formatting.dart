import 'dart:ui' show Locale;

import 'package:duration/locale.dart';
import 'package:intl/intl.dart';

String formatDate(String languageTag, DateTime now, DateTime date) {
  if (now.year != date.year) {
    return DateFormat.yMMMEd(languageTag).add_jm().format(date);
  }
  if (now.month != date.month) {
    return DateFormat.MMMEd(languageTag).add_jm().format(date);
  }
  if (now.day != date.day) {
    return DateFormat("E d,", languageTag).add_jm().format(date);
  }

  return DateFormat.jm(languageTag).format(date);
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  String padded(int value) {
    return value.toString().padLeft(2, '0');
  }

  if (hours > 0) {
    return "$hours:${padded(minutes)}:${padded(seconds)}";
  }
  return "$minutes:${padded(seconds)}";
}

extension LocaleExtension on Locale {
  DurationLocale get durationLocale =>
      DurationLocale.fromLanguageCode(languageCode) ?? englishLocale;
}
