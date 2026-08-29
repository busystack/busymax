import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux CI uploads only the installable strict Snap', () {
    final workflow = File(
      '.github/workflows/flutter-linux.yml',
    ).readAsStringSync();

    expect(workflow, contains('runs-on: ubuntu-24.04'));
    expect(workflow, contains("flutter-version: '3.44.4'"));
    expect(workflow, contains('uses: snapcore/action-build@v1'));
    expect(workflow, contains('uses: actions/upload-artifact@v7'));
    expect(workflow, contains('name: busymax-snap'));
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
}
