import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_platform_boundaries.dart' as boundary_check;

void main() {
  test('platform import boundaries remain valid', () {
    final failures = boundary_check.findPlatformBoundaryViolations(
      Directory.current,
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('Android traversal follows package imports and exports', () {
    final root = Directory.systemTemp.createTempSync(
      'busymax-platform-boundary-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/lib/src').createSync(recursive: true);
    File(
      '${root.path}/lib/main_android.dart',
    ).writeAsStringSync("import 'package:busymax/src/bridge.dart';\n");
    File('${root.path}/lib/src/android_background.dart').writeAsStringSync('');
    File(
      '${root.path}/lib/src/bridge.dart',
    ).writeAsStringSync("export 'package:yaru/yaru.dart';\n");

    final failures = boundary_check.findPlatformBoundaryViolations(root);

    expect(
      failures,
      contains(
        'Android foreground graph: lib/src/bridge.dart reaches '
        'desktop-only package:yaru/yaru.dart',
      ),
    );
  });
}
