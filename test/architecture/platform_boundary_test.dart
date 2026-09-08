import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_platform_boundaries.dart' as boundary_check;

void main() {
  test(
    'platform import boundaries remain valid',
    () {
      final failures = boundary_check.findPlatformBoundaryViolations(
        Directory.current,
      );
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
