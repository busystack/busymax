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
    File('${root.path}/lib/main_android.dart')
        .writeAsStringSync("import 'package:busymax/src/bridge.dart';\n");
    File('${root.path}/lib/src/android_background.dart').writeAsStringSync('');
    File('${root.path}/lib/src/bridge.dart')
        .writeAsStringSync("export 'package:yaru/yaru.dart';\n");

    final failures = boundary_check.findPlatformBoundaryViolations(root);

    expect(
      failures,
      contains(
        'Android foreground graph: lib/src/bridge.dart reaches '
        'desktop-only package:yaru/yaru.dart',
      ),
    );
  });

  test('conditional dependencies and parts are traversed transitively', () {
    final root = Directory.systemTemp.createTempSync('busymax-boundaries-');
    addTearDown(() => root.deleteSync(recursive: true));
    void write(String path, String source) {
      final file = File('${root.path}/$path');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(source);
    }

    write('lib/main_android.dart', '''
      import 'src/stub.dart' if (dart.library.io) 'src/bridge.dart';
      // import 'package:yaru/ignored.dart';
    ''');
    write(
      'lib/main_windows.dart',
      "export 'src/stub.dart'\n"
          " if (dart.library.io) 'src/bridge.dart';",
    );
    write('lib/src/android/android_background.dart', '');
    write('lib/src/stub.dart', '');
    write('lib/src/bridge.dart', "part 'linux/platform_bindings.dart';");
    write('lib/src/linux/platform_bindings.dart', "part of '../bridge.dart';");

    final failures = boundary_check.findPlatformBoundaryViolations(root);
    expect(
      failures,
      containsAll([
        'Android foreground graph: lib/src/bridge.dart reaches desktop-only '
            'linux/platform_bindings.dart',
        'Windows graph: lib/src/bridge.dart reaches linux/platform_bindings.dart',
      ]),
    );
    expect(
      failures.any((failure) => failure.contains('ignored.dart')),
      isFalse,
    );
  });
}
