import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'package metadata uses matching versions and accurate provider names',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final snap = File('snap/snapcraft.yaml').readAsStringSync();
      final metainfo = File(
        'linux/io.busystack.busymax.metainfo.xml',
      ).readAsStringSync();
      final windowsRunner = File('windows/runner/Runner.rc').readAsStringSync();
      final androidBuild = File(
        'android/app/build.gradle.kts',
      ).readAsStringSync();

      final pubspecVersion = _capture(
        pubspec,
        RegExp(r'^version:\s*(\S+)', multiLine: true),
      );
      final snapVersion = _capture(
        snap,
        RegExp(r'^version:\s*"([^"]+)"', multiLine: true),
      );
      final metainfoVersion = _capture(
        metainfo,
        RegExp(r'<release version="([^"]+)"'),
      );

      expect(pubspecVersion, '0.2.4');
      expect(snapVersion, pubspecVersion);
      expect(metainfoVersion, pubspecVersion);
      expect(windowsRunner, contains('#define VERSION_AS_NUMBER 0,2,4,0'));
      expect(windowsRunner, contains('#define VERSION_AS_STRING "0.2.4"'));
      expect(androidBuild, contains('versionCode = 4'));
      expect(androidBuild, contains('versionName = flutter.versionName'));

      for (final document in [snap, metainfo]) {
        expect(document, contains('Apple iCloud Calendar'));
        expect(document, contains('Nextcloud Calendar'));
        expect(document, contains('Nextcloud Tasks'));
        expect(document, contains('Apple Reminders is not supported'));
        expect(document.toLowerCase(), contains('app-specific password'));
        expect(document.toLowerCase(), contains('default browser'));
      }
    },
  );
}

String _capture(String source, RegExp pattern) {
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: 'Expected ${pattern.pattern}');
  return match!.group(1)!;
}
