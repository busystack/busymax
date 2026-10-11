import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in [
    (
      name: 'matching release branch',
      title: 'Release/v0.2.4',
      source: 'Release/v0.2.4',
      allowed: true,
    ),
    (
      name: 'intentional lowercase release branch',
      title: 'Release/v0.3.0',
      source: 'release/v0.3.0',
      allowed: true,
    ),
    (
      name: 'release title on the naming fix branch',
      title: 'Release/v0.2.4',
      source: 'fix/release-action-names',
      allowed: false,
    ),
    (
      name: 'release title on the OAuth hotfix branch',
      title: 'Release/v0.2.4',
      source: 'hotfix/ci-oauth-configuration',
      allowed: false,
    ),
    (
      name: 'wrong release version',
      title: 'Release/v0.2.4',
      source: 'Release/v0.2.3',
      allowed: false,
    ),
    (
      name: 'missing release source',
      title: 'Release/v0.2.4',
      source: '',
      allowed: false,
    ),
    (
      name: 'ordinary feature PR',
      title: 'Feature/shared contacts package',
      source: 'feature/shared-contacts-package',
      allowed: true,
    ),
    (name: 'push without PR metadata', title: '', source: '', allowed: true),
  ]) {
    test('release PR source validation: ${scenario.name}', () async {
      final result = await Process.run(
        Platform.isWindows ? 'python' : 'python3',
        ['tool/check_release_pull_request.py'],
        environment: {
          'RELEASE_PR_TITLE': scenario.title,
          'GITHUB_HEAD_REF': scenario.source,
        },
      );

      expect(result.exitCode, scenario.allowed ? 0 : 1);
      expect(result.stdout, isEmpty);
      if (scenario.allowed) {
        expect(result.stderr, isEmpty);
      } else {
        expect(result.stderr, contains('Release pull requests must originate'));
      }
    });
  }
}
