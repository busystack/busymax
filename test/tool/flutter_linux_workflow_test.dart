import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux CI uploads only a configured installable strict Snap', () {
    final workflow = File(
      '.github/workflows/flutter-linux.yml',
    ).readAsStringSync();

    expect(workflow, contains('runs-on: ubuntu-24.04'));
    expect(workflow, contains("flutter-version: '3.44.4'"));
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
}
