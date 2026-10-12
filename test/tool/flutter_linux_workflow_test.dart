import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux CI verifies source and a smoke Snap without release credentials or uploads', () {
    final workflow = File('.github/workflows/flutter-linux.yml')
        .readAsStringSync();
    for (final required in [
      'pull_request:',
      'push:',
      'branches: [main]',
      'cancel-in-progress: true',
      'runs-on: ubuntu-24.04',
      "flutter-version: '3.47.5'",
      'tool/verify_flutter_sdk.dart',
      '--expected-flutter 3.47.5',
      '--expected-dart 3.13.4',
      'tool/check_release_pull_request.py',
      'tool/checkout_shared_dependencies.py',
      r'"$BUSYMAX_FLUTTER_EXECUTABLE" pub get --enforce-lockfile',
      r'"$BUSYMAX_FLUTTER_EXECUTABLE" gen-l10n',
      'run build_runner build',
      'git diff --exit-code',
      '--set-exit-if-changed',
      r'"$BUSYMAX_FLUTTER_EXECUTABLE" analyze',
      'tool/check_platform_boundaries.dart',
      r'"$BUSYMAX_FLUTTER_EXECUTABLE" test',
      'gtk_header_icons_integration_test.dart',
      'tool/release/check_linux_native.sh',
      'registration_native_helper_test.py',
      'busymax_registration_reader_tests',
      'uses: snapcore/action-build@v1',
      'sudo snap install --dangerous',
      'snap info --verbose busymax',
    ]) {
      expect(workflow, contains(required));
    }
    for (final removed in [
      'workflow_dispatch',
      'production_release',
      'secrets.',
      'vars.',
      '--dart-define',
      'upload-artifact',
      'busymax-snap-ci-non-production',
      'busymax-source',
      'tool/package_source.py',
      'snapcraft upload',
    ]) {
      expect(workflow, isNot(contains(removed)));
    }
    expect(File('tool/package_source.py').existsSync(), isTrue);
    expect(
      workflow,
      contains(r'dart_executable="$flutter_bin/cache/dart-sdk/bin/dart"'),
    );
    expect(workflow, isNot(contains(r'command -v dart')));
  });

  test('production validator requires managed Google but no original or managed Microsoft', () async {
    final directory = Directory.systemTemp.createTempSync(
      'busymax-config-check-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/defines.json');
    Future<ProcessResult> check(Map<String, Object?> values) async {
      file.writeAsStringSync(jsonEncode(values));
      return Process.run(_hostDartExecutable(), [
        '--packages=.dart_tool/package_config.json',
        'tool/check_desktop_oauth_config.dart',
        '--config',
        file.path,
      ]);
    }

    final google = <String, Object?>{
      'BUSYMAX_GOOGLE_OAUTH_CLIENT_ID':
          'release-fixture.apps.googleusercontent.com',
      'BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET': 'fixture-secret-never-print',
      'BUSYMAX_GOOGLE_OAUTH_PROJECT_ID': 'fixture-project',
      'BUSYMAX_PRIVACY_POLICY_URL': 'https://busystack.org/privacy-busymax',
    };
    final complete = await check(google);
    expect(complete.exitCode, 0);
    expect(complete.stdout, contains('still require owner review'));
    expect(
      '${complete.stdout}${complete.stderr}',
      isNot(contains('fixture-secret-never-print')),
    );
    expect((await check({})).exitCode, 1);
    for (final key in google.keys) {
      expect((await check({...google, key: ''})).exitCode, 1);
    }
    for (final key in [
      'MICROSOFT_OAUTH_CLIENT_ID',
      'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID',
    ]) {
      expect(
        (await check({...google, key: '01234567-89ab-cdef-0123-456789abcdef'}))
            .exitCode,
        0,
      );
      expect((await check({...google, key: ''})).exitCode, 1);
      expect((await check({...google, key: false})).exitCode, 1);
    }
    expect(
      (await check({
        ...google,
        'BUSYMAX_GOOGLE_OAUTH_CLIENT_ID':
            'busymax-ci-managed.apps.googleusercontent.com',
      })).exitCode,
      1,
    );
    expect(
      (await check({
        ...google,
        'BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET': ' synthetic-ci-public-secret ',
      })).exitCode,
      1,
    );
    expect(
      (await check({
        ...google,
        'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID':
            '44444444-4444-4444-4444-444444444444',
      })).exitCode,
      1,
    );
    expect(
      (await check({...google, 'BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET': false}))
          .exitCode,
      1,
    );
    file.writeAsStringSync('{"secret":"must-not-print"');
    final malformed = await Process.run(_hostDartExecutable(), [
      '--packages=.dart_tool/package_config.json',
      'tool/check_desktop_oauth_config.dart',
      '--config',
      file.path,
    ]);
    expect(malformed.exitCode, 1);
    expect(malformed.stderr, isNot(contains('must-not-print')));
    final environment = await Process.run(_hostDartExecutable(), [
      '--packages=.dart_tool/package_config.json',
      'tool/check_desktop_oauth_config.dart',
    ], environment: google.cast<String, String>());
    expect(environment.exitCode, 0);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

String _hostDartExecutable() {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final candidate = File(
      '${directory.path}/dart-sdk/bin/${Platform.isWindows ? 'dart.exe' : 'dart'}',
    );
    if (candidate.existsSync()) return candidate.path;
    directory = directory.parent;
  }
  throw StateError('Cannot locate bundled Dart SDK.');
}
