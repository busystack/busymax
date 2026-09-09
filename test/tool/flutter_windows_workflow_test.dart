import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows CI has main-only triggers and per-ref cancellation', () {
    final workflow = _readWorkflow();
    final triggers = workflow.substring(
      workflow.indexOf('on:'),
      workflow.indexOf('\nconcurrency:'),
    );
    final concurrency = workflow.substring(
      workflow.indexOf('concurrency:'),
      workflow.indexOf('\njobs:'),
    );

    expect(triggers, contains('workflow_dispatch:'));
    expect(
      _triggerBlock(triggers, 'pull_request'),
      'pull_request:\n    branches: [main]',
    );
    expect(_triggerBlock(triggers, 'push'), 'push:\n    branches: [main]');
    expect(triggers, isNot(contains('Release/**')));
    expect(
      concurrency,
      contains(r'group: ${{ github.workflow }}-${{ github.ref }}'),
    );
    expect(concurrency, contains('cancel-in-progress: true'));
  });

  test('Windows CI retains combined validation and all build stages', () {
    final workflow = _readWorkflow();
    final buildScript = File(
      'tool/windows/build_release.ps1',
    ).readAsStringSync();
    final prerequisiteScript = File(
      'tool/windows/check_prerequisites.ps1',
    ).readAsStringSync();

    for (final name in [
      'Verify x64 Windows build host',
      'Verify pinned Flutter version',
      'Verify Visual Studio C++ toolchain',
      'Verify Windows SDK packaging tools',
      'Validate non-production CI identity',
    ]) {
      expect(workflow, isNot(contains('- name: $name')));
    }

    final identity = _stepBlock(
      workflow,
      'Create explicitly non-production CI identity',
    );
    final prerequisites = _stepBlock(
      workflow,
      'Verify combined Windows build prerequisites',
    );
    expect(identity, contains('build/windows/store-ci.json'));
    expect(identity, contains("identityName = 'BusyStack.BusyMax.CI'"));
    expect(prerequisites, contains('./tool/windows/check_prerequisites.ps1'));
    expect(
      prerequisites,
      contains('build/windows/test-results/windows-environment.json'),
    );

    final stages = {
      'Run pinned Pester contract tests': 'PesterTests',
      'Restore dependencies and generate sources': 'SourceGeneration',
      'Check formatting, analysis, and platform boundaries': 'StaticAnalysis',
      'Run Dart and Flutter tests': 'FlutterTests',
      'Compile Windows x64 release': 'WindowsCompile',
      'Run native C++ tests': 'NativeTests',
      'Pack and inspect exact MSIX': 'Package',
    };
    for (final entry in stages.entries) {
      final step = _stepBlock(workflow, entry.key);
      expect(step, contains('./tool/windows/build_release.ps1'));
      expect(step, contains('-Ci -Stage ${entry.value}'));
    }

    final package = _stepBlock(workflow, 'Pack and inspect exact MSIX');
    expect(package, isNot(contains('github.event_name')));
    expect(buildScript, contains('& flutter pub get --enforce-lockfile'));
    expect(
      buildScript,
      contains('& git diff --exit-code -- lib/l10n/generated lib/src/db'),
    );
    expect(prerequisiteScript, contains('Get-Command flutter'));
    expect(prerequisiteScript, contains('Get-Command dart'));
    expect(prerequisiteScript, contains(r'if ($flutterBin -ne $dartBin)'));
    expect(prerequisiteScript, contains("dartSdkVersion -ne '3.12.2'"));
  });

  test(
    'Windows CI retains diagnostics and limits package artifact uploads',
    () {
      final workflow = _readWorkflow();
      final diagnostics = _stepBlock(workflow, 'Upload Windows test reports');
      final package = _stepBlock(
        workflow,
        'Upload unsigned CI MSIX and package evidence',
      );

      expect(diagnostics, contains('if: always()'));
      expect(diagnostics, contains('name: busymax-windows-x64-test-reports'));
      expect(diagnostics, contains('path: build/windows/test-results/**'));
      expect(diagnostics, contains('if-no-files-found: warn'));
      expect(diagnostics, contains('retention-days: 7'));
      expect(
        package,
        contains(
          "if: success() && (github.event_name == 'push' || "
          "github.event_name == 'workflow_dispatch')",
        ),
      );
      expect(package, contains('name: busymax-windows-x64-ci'));
      expect(package, contains('build/windows/store/*.msix'));
      expect(package, contains('if-no-files-found: error'));
      expect(package, contains('retention-days: 7'));
    },
  );
}

String _readWorkflow() =>
    File('.github/workflows/flutter-windows.yml').readAsStringSync();

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
