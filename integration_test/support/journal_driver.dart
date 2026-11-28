import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 8),
  responseDataCallback: (data) {
    final name = data?['journalTest'];
    final cases = data?['journalCases'];
    if (name is! String || cases is! List || cases.isEmpty) {
      throw StateError('The installed journal test returned no named results.');
    }
    stdout.writeln('JOURNAL_NATIVE_TEST $name PASS');
    for (final marker in cases.cast<String>()) {
      stdout.writeln(marker);
    }
  },
);
