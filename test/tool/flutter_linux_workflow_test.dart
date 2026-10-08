import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _productionCondition =
    "if: github.event_name == 'workflow_dispatch' && "
    "inputs.production_release && github.ref == 'refs/heads/main'";
const _ciCondition =
    "if: github.event_name != 'workflow_dispatch' || !inputs.production_release";

void main() {
  test('Linux builds installable strict Snaps with the pinned SDK', () {
    final workflow = File('.github/workflows/flutter-linux.yml')
        .readAsStringSync();

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
    expect(workflow, contains('BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID'));
    expect(workflow, contains('MICROSOFT_OAUTH_AUTHORITY_TENANT'));
    expect(workflow, contains('https://busystack.org/privacy-busymax'));
    expect(workflow, contains('for key in GOOGLE_OAUTH_CLIENT_ID'));
    expect(workflow, contains(r'grep -aFq -- "${!key}"'));
    expect(workflow, contains(r'grep -aFq -- "$GOOGLE_OAUTH_CLIENT_SECRET"'));
    expect(workflow, contains('name: busymax-linux-production-snap'));
    expect(workflow, contains(r'path: ${{ steps.snapcraft.outputs.snap }}'));
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
      final workflow = File('.github/workflows/flutter-linux.yml')
          .readAsStringSync();
      final triggers = workflow.substring(
        workflow.indexOf('on:'),
        workflow.indexOf('\nconcurrency:'),
      );
      final concurrency = workflow.substring(
        workflow.indexOf('concurrency:'),
        workflow.indexOf('\njobs:'),
      );

      expect(
        _triggerBlock(triggers, 'pull_request'),
        'pull_request:\n    branches: [main]',
      );
      expect(_triggerBlock(triggers, 'push'), 'push:\n    branches: [main]');
      final manual = _triggerBlock(triggers, 'workflow_dispatch');
      expect(manual, contains('production_release:'));
      expect(manual, contains('type: boolean'));
      expect(manual, contains('required: true'));
      expect(manual, contains('default: false'));
      expect(triggers, isNot(contains('Release/**')));
      expect(
        concurrency,
        contains(r'group: ${{ github.workflow }}-${{ github.ref }}'),
      );
      expect(concurrency, contains('cancel-in-progress: true'));
      for (final name in [
        'Upload verified non-production Snap',
        'Upload verified production Snap',
      ]) {
        final upload = _stepBlock(workflow, name);
        expect(upload, contains('retention-days: 7'));
        expect(upload, contains('if-no-files-found: error'));
        expect(
          workflow.indexOf('- name: $name'),
          greaterThan(workflow.indexOf('- name: Verify installed strict Snap')),
          reason: 'Only verified artifacts may be uploaded.',
        );
      }
    },
  );

  test(
    'routine Linux CI needs no production credentials and verifies its Snap',
    () {
      final workflow = File('.github/workflows/flutter-linux.yml')
          .readAsStringSync();

      for (final name in [
        'Resolve dependencies',
        'Generate localizations',
        'Generate Drift code',
        'Check formatting',
        'Analyze',
        'Check platform boundaries',
        'Test',
        'Test GTK header-icon bridge',
        'Test native clock patterns, weekday locale, and GTK time picker',
        'Test native registration helper teardown',
        'Test native registration configuration handles',
        'Build unconfigured release with usable custom registration paths',
        'Build strict Snap from the release bundle',
        'Install strict Snap',
        'Verify installed strict Snap',
      ]) {
        final step = _stepBlock(workflow, name);
        expect(step, contains('- name: $name'));
        expect(
          step,
          isNot(contains('\n        if:')),
          reason: '$name must run for both pull requests and main pushes.',
        );
        expect(step, isNot(contains('secrets.')));
        expect(step, isNot(contains('vars.')));
      }
      final unconfigured = _stepBlock(
        workflow,
        'Build unconfigured release with usable custom registration paths',
      );
      expect(unconfigured, isNot(contains('--dart-define')));
      expect(unconfigured, contains('docs/google_setup.md'));
      expect(unconfigured, contains('docs/microsoft_setup.md'));
      final label = _stepBlock(workflow, 'Label verified non-production Snap');
      final upload = _stepBlock(
        workflow,
        'Upload verified non-production Snap',
      );
      expect(label, contains(_ciCondition));
      expect(upload, contains(_ciCondition));
      expect(
        label,
        contains('build/busymax-linux-ci-unconfigured-non-production.snap'),
      );
      expect(
        upload,
        contains(
          'path: build/busymax-linux-ci-unconfigured-non-production.snap',
        ),
      );
      expect(
        upload,
        contains('name: busymax-linux-ci-unconfigured-non-production'),
      );
      expect(workflow, isNot(contains('snapcraft upload')));
    },
  );

  test(
    'production validation, build and artifact require explicit main dispatch',
    () {
      final workflow = File('.github/workflows/flutter-linux.yml')
          .readAsStringSync();
      final guard = _stepBlock(workflow, 'Require main for manual runs');
      expect(
        guard,
        contains(
          "if: github.event_name == 'workflow_dispatch' && github.ref != 'refs/heads/main'",
        ),
      );
      expect(guard, contains('::error::'));
      expect(guard, contains('exit 1'));
      expect(
        workflow.indexOf('- name: Require main for manual runs'),
        lessThan(workflow.indexOf('- name: Check out repository')),
      );
      const validation =
          'Validate production registrations and protected originals';
      const build =
          'Build official Linux release with explicit active registrations';
      for (final name in [
        validation,
        build,
        'Upload verified production Snap',
      ]) {
        expect(_stepBlock(workflow, name), contains(_productionCondition));
      }
      for (final step in workflow.split(RegExp(r'(?=      - name:)'))) {
        if (step.contains('secrets.') || step.contains('vars.')) {
          expect(step, contains(_productionCondition));
        }
      }
      expect(
        _stepBlock(workflow, validation),
        contains('tool/check_desktop_oauth_config.dart'),
      );
      expect(_stepBlock(workflow, build), contains('--dart-define-from-file='));
      expect(
        workflow.indexOf('- name: $validation'),
        lessThan(workflow.indexOf('- name: $build')),
      );
      expect(
        workflow.indexOf('- name: $build'),
        lessThan(workflow.indexOf('- name: Build strict Snap')),
      );
    },
  );

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

      for (final invalid in ['', 'not-a-client-id']) {
        final invalidMicrosoft = await check({
          ...values,
          'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID': invalid,
        });
        expect(invalidMicrosoft.exitCode, 1);
        expect(
          invalidMicrosoft.stderr,
          contains('External prerequisite: Microsoft'),
        );
      }
      final originalOnly = await check({
        'GOOGLE_OAUTH_CLIENT_ID': values['GOOGLE_OAUTH_CLIENT_ID'],
        'GOOGLE_OAUTH_CLIENT_SECRET': 'fixture-original-secret',
        'MICROSOFT_OAUTH_CLIENT_ID': values['MICROSOFT_OAUTH_CLIENT_ID'],
        'BUSYMAX_PRIVACY_POLICY_URL': values['BUSYMAX_PRIVACY_POLICY_URL'],
      });
      expect(originalOnly.exitCode, 1);
      expect(originalOnly.stderr, contains('External prerequisite: Google'));
      expect(originalOnly.stderr, contains('External prerequisite: Microsoft'));
      final ci = await check({
        ...values,
        'BUSYMAX_GOOGLE_OAUTH_CLIENT_ID':
            'busymax-ci-managed.apps.googleusercontent.com',
      });
      expect(ci.exitCode, 1);
      expect(ci.stderr, contains('Synthetic CI'));
      final microsoftCi = await check({
        ...values,
        'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID':
            '44444444-4444-4444-4444-444444444444',
      });
      expect(microsoftCi.exitCode, 1);
      expect(microsoftCi.stderr, contains('Synthetic CI'));
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
    timeout: const Timeout(Duration(minutes: 2)),
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
  final nextEvent = RegExp(r'\n  [a-z_]+:')
      .firstMatch(triggers.substring(start + 1));
  final end = nextEvent == null ? null : start + 1 + nextEvent.start;
  return triggers.substring(start, end).trim();
}
