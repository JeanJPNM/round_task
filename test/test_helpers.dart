import 'package:flutter_test/flutter_test.dart';

Matcher equalsDate(DateTime expected) {
  return predicate((arg) {
    if (arg is! DateTime) return false;
    return arg.difference(expected).inMilliseconds.abs() < 1;
  }, 'is close to $expected');
}
