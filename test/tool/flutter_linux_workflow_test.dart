import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux CI uploads only a configured installable strict Snap', () {
    final workflow = File(
      '.github/workflows/flutter-linux.yml',
    ).readAsStringSync();

    expect(workflow, contains('runs-on: ubuntu-24.04'));
    expect(workflow, contains("flutter-version: '3.44.4'"));
    expect(workflow, contains('Verify pinned Flutter and bundled Dart'));
    expect(workflow, contains(r'command -v flutter'));
    expect(
      workflow,
      contains(r'dart_executable="$flutter_bin/cache/dart-sdk/bin/dart"'),
    );
    expect(workflow, contains('tool/verify_flutter_sdk.dart'));
    expect(workflow, contains('--expected-dart 3.12.2'));
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
    expect(workflow, contains('Validate release provider configuration'));
    expect(workflow, contains('Verify release provider configuration'));
    expect(
      workflow,
      contains("echo '::error::Release provider configuration is incomplete.'"),
    );
    expect(workflow, contains(r'grep -aFq -- "$GOOGLE_OAUTH_CLIENT_ID"'));
    expect(workflow, contains(r'grep -aFq -- "$GOOGLE_OAUTH_CLIENT_SECRET"'));
    expect(workflow, contains(r'grep -aFq -- "$MICROSOFT_OAUTH_CLIENT_ID"'));
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
