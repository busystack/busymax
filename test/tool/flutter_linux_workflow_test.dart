import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux CI uploads only a configured installable strict Snap', () {
    final workflow = File(
      '.github/workflows/flutter-linux.yml',
    ).readAsStringSync();

    expect(workflow, contains('runs-on: ubuntu-24.04'));
    expect(workflow, contains("flutter-version: '3.47.5'"));
    expect(workflow, contains('Verify pinned Flutter and bundled Dart'));
    expect(workflow, contains(r'command -v flutter'));
    expect(
      workflow,
      contains(r'dart_executable="$flutter_bin/cache/dart-sdk/bin/dart"'),
    );
    expect(workflow, contains('tool/verify_flutter_sdk.dart'));
    expect(workflow, contains('--expected-flutter 3.47.5'));
    expect(workflow, contains('--expected-dart 3.13.4'));
    expect(workflow, isNot(contains(r'command -v dart')));
    expect(
      workflow,
      contains(
        r"printf 'BUSYMAX_FLUTTER_EXECUTABLE=%s\n' "
        r'"$flutter_executable" >> "$GITHUB_ENV"',
      ),
    );
    expect(
      workflow,
      contains(
        r"printf 'BUSYMAX_DART_EXECUTABLE=%s\n' "
        r'"$dart_executable" >> "$GITHUB_ENV"',
      ),
    );
    expect(
      workflow,
      contains(r'"$BUSYMAX_FLUTTER_EXECUTABLE" pub get --enforce-lockfile'),
    );
    expect(workflow, contains(r'"$BUSYMAX_FLUTTER_EXECUTABLE" gen-l10n'));
    expect(
      workflow,
      contains(r'"$BUSYMAX_DART_EXECUTABLE" run build_runner build'),
    );
    expect(workflow, contains(r'"$BUSYMAX_DART_EXECUTABLE" format'));
    expect(
      workflow,
      contains(
        r'"$BUSYMAX_DART_EXECUTABLE" run '
        'tool/check_platform_boundaries.dart',
      ),
    );
    expect(workflow, contains(r'"$BUSYMAX_FLUTTER_EXECUTABLE" analyze'));
    expect(workflow, contains(r'"$BUSYMAX_FLUTTER_EXECUTABLE" test'));
    expect(workflow, contains(r'"$BUSYMAX_FLUTTER_EXECUTABLE" build linux'));
    expect(
      workflow,
      isNot(
        matches(RegExp(r'^\s+(?:run:\s*)?(?:dart|flutter)\s', multiLine: true)),
      ),
    );
    expect(workflow, contains('uses: snapcore/action-build@v1'));
    expect(workflow, contains('uses: actions/upload-artifact@v7'));
    expect(
      workflow,
      contains('Validate production registrations and protected originals'),
    );
    expect(
      workflow,
      contains(
        'Build official Linux release with explicit active registrations',
      ),
    );
    expect(workflow, contains('tool/check_desktop_oauth_config.dart'));
    expect(workflow, contains('BUSYMAX_GOOGLE_OAUTH_PROJECT_ID'));
    expect(workflow, contains('BUSYMAX_MICROSOFT_OAUTH_AUTHORITY_TENANT'));
    expect(workflow, contains('https://busystack.org/privacy-busymax'));
    expect(workflow, contains('for key in GOOGLE_OAUTH_CLIENT_ID'));
    expect(workflow, contains(r'grep -aFq -- "${!key}"'));
    expect(workflow, contains(r'grep -aFq -- "$GOOGLE_OAUTH_CLIENT_SECRET"'));
    expect(workflow, contains('name: busymax-snap'));
    expect(workflow, contains(r'path: ${{ steps.snapcraft.outputs.snap }}'));
    expect(
      RegExp(
        r'- name: Upload Snap artifact\s+'
        r"if: github\.event_name == 'push'",
      ).hasMatch(workflow),
      isTrue,
    );
    expect(workflow, contains('sudo snap install --dangerous'));
    expect(workflow, contains('snap info --verbose busymax'));
    expect(workflow, contains(r'confinement:[[:space:]]+strict'));
    expect(workflow, contains(r'test -x "$SNAP/busymax"'));
    expect(workflow, isNot(contains('SNAP_CONFINEMENT')));
    expect(workflow, isNot(contains('busymax-linux-x64-release-bundle')));
    expect(workflow, isNot(contains('Build Linux debug')));
    expect(workflow, isNot(contains('zip -r')));
  });

  test(
    'Linux CI has main-only triggers, cancellation, and short Snap retention',
    () {
      final workflow = File(
        '.github/workflows/flutter-linux.yml',
      ).readAsStringSync();
      final triggers = workflow.substring(
        workflow.indexOf('on:'),
        workflow.indexOf('\nconcurrency:'),
      );
      final concurrency = workflow.substring(
        workflow.indexOf('concurrency:'),
        workflow.indexOf('\njobs:'),
      );
      final upload = _stepBlock(workflow, 'Upload Snap artifact');

      expect(
        _triggerBlock(triggers, 'pull_request'),
        'pull_request:\n    branches: [main]',
      );
      expect(_triggerBlock(triggers, 'push'), 'push:\n    branches: [main]');
      expect(triggers, isNot(contains('workflow_dispatch:')));
      expect(triggers, isNot(contains('Release/**')));
      expect(
        concurrency,
        contains(r'group: ${{ github.workflow }}-${{ github.ref }}'),
      );
      expect(concurrency, contains('cancel-in-progress: true'));
      expect(upload, contains("if: github.event_name == 'push'"));
      expect(upload, contains('retention-days: 7'));
      expect(upload, contains('if-no-files-found: error'));
    },
  );

  test('Linux CI validates the strict Snap on pull requests', () {
    final workflow = File(
      '.github/workflows/flutter-linux.yml',
    ).readAsStringSync();

    for (final name in [
      'Build strict Snap from the release bundle',
      'Install strict Snap',
      'Verify installed strict Snap',
    ]) {
      final step = _stepBlock(workflow, name);
      expect(step, contains('- name: $name'));
      expect(
        step,
        isNot(contains('\n        if:')),
        reason: '$name must run for pull requests.',
      );
    }
  });

  test(
    'official release checks report prerequisites without exposing credentials',
    () async {
      final temporary = Directory.systemTemp.createTempSync(
        'busymax-release-check.',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      final configuration = File('${temporary.path}/registration.json');
      Future<ProcessResult> check(Map<String, Object?> values) {
        configuration.writeAsStringSync(jsonEncode(values));
        return Process.run(_hostDartExecutable(), [
          '--packages=.dart_tool/package_config.json',
          'tool/check_desktop_oauth_config.dart',
          '--config',
          configuration.path,
        ]);
      }

      final absent = await check({});
      expect(absent.exitCode, 1);
      expect(absent.stderr, contains('External prerequisite: Google'));
      expect(absent.stderr, contains('External prerequisite: Microsoft'));
      expect(absent.stderr, contains('Protected original registration IDs'));

      // Test data only: syntax cannot establish a real provider registration.
      final values = <String, Object?>{
        'GOOGLE_OAUTH_CLIENT_ID': 'fixture-original.apps.googleusercontent.com',
        'MICROSOFT_OAUTH_CLIENT_ID': '11111111-1111-1111-1111-111111111111',
        'BUSYMAX_GOOGLE_OAUTH_CLIENT_ID':
            'fixture-active.apps.googleusercontent.com',
        'BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET':
            'fixture-value-must-not-be-printed',
        'BUSYMAX_GOOGLE_OAUTH_PROJECT_ID': 'fixture-active',
        'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID':
            '33333333-3333-3333-3333-333333333333',
        'BUSYMAX_MICROSOFT_OAUTH_AUTHORITY_TENANT': 'organizations',
        'BUSYMAX_PRIVACY_POLICY_URL': 'https://busystack.org/privacy-busymax',
      };
      final complete = await check(values);
      expect(complete.exitCode, 0);
      expect(complete.stdout, contains('syntactically complete'));
      expect(complete.stdout, contains('still require owner review'));
      expect(
        '${complete.stdout}${complete.stderr}',
        isNot(contains(values['BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET'])),
      );

      final noAudience = await check({
        ...values,
        'BUSYMAX_MICROSOFT_OAUTH_AUTHORITY_TENANT': '',
      });
      expect(noAudience.exitCode, 1);
      expect(noAudience.stderr, contains('External prerequisite: Microsoft'));
      final ci = await check({
        ...values,
        'BUSYMAX_GOOGLE_OAUTH_CLIENT_ID':
            'busymax-ci-managed.apps.googleusercontent.com',
      });
      expect(ci.exitCode, 1);
      expect(ci.stderr, contains('Synthetic CI'));
      final paddedCi = await check({
        ...values,
        'BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET': ' synthetic-ci-public-secret ',
      });
      expect(paddedCi.exitCode, 1);
      expect(paddedCi.stderr, contains('Synthetic CI'));
      final wrongType = await check({
        ...values,
        'BUSYMAX_GOOGLE_OAUTH_CLIENT_SECRET': false,
      });
      expect(wrongType.exitCode, 1);
      expect(wrongType.stderr, contains('External prerequisite: Google'));

      configuration.writeAsStringSync('{"secret":"must-not-be-printed"');
      final malformed = await Process.run(_hostDartExecutable(), [
        '--packages=.dart_tool/package_config.json',
        'tool/check_desktop_oauth_config.dart',
        '--config',
        configuration.path,
      ]);
      expect(malformed.exitCode, 1);
      expect(malformed.stderr, contains('Cannot read a JSON object'));
      expect(malformed.stderr, isNot(contains('must-not-be-printed')));
    },
  );
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
  throw StateError('Cannot locate the test runner’s bundled Dart SDK.');
}

String _stepBlock(String workflow, String name) {
  final start = workflow.indexOf('- name: $name');
  expect(start, isNonNegative, reason: 'Missing workflow step: $name');
  final end = workflow.indexOf('\n      - name:', start + 1);
  return end == -1 ? workflow.substring(start) : workflow.substring(start, end);
}

String _triggerBlock(String triggers, String event) {
  final start = triggers.indexOf('  $event:');
  expect(start, isNonNegative, reason: 'Missing workflow trigger: $event');
  final nextEvent = RegExp(
    r'\n  [a-z_]+:',
  ).firstMatch(triggers.substring(start + 1));
  final end = nextEvent == null ? null : start + 1 + nextEvent.start;
  return triggers.substring(start, end).trim();
}
