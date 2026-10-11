import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release PR versions and ancestry use the actual GitHub refs',
    () async {
      final result = await Process.run(
        Platform.isWindows ? 'python' : 'python3',
        ['test/tool/release_pull_request_test.py'],
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
    // This runs 17 regressions that each create real Git repositories; process
    // startup is more expensive on Windows CI than on a local Linux checkout.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
