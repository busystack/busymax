import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class AndroidReleaseIntegrityTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.log = self.root / 'commands.jsonl'
        self.flutter = self.root / 'sdk/bin/flutter'
        self.script = self.root / 'tool/android/build_release.sh'
        self.script.parent.mkdir(parents=True)
        shutil.copy2(ROOT / 'tool/android/build_release.sh', self.script)
        prerequisite = self.script.with_name('check_prerequisites.sh')
        prerequisite.write_text('#!/usr/bin/env bash\nexit 0\n')
        prerequisite.chmod(0o755)
        self.flutter.parent.mkdir(parents=True)
        self.flutter.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['COMMAND_LOG'], 'a') as log:
    print(json.dumps(sys.argv[1:]), file=log)
raise SystemExit(1 if sys.argv[1] == os.environ.get('FAILURE') else 0)
''')
        self.flutter.chmod(0o755)
        (self.root / 'tool/verify_upstream_packages.py').write_text('''
import json, os, sys
with open(os.environ['COMMAND_LOG'], 'a') as log:
    print(json.dumps(['verify', *sys.argv[1:]]), file=log)
stage = 'after' if '--android-maven-mode' in sys.argv else 'before'
raise SystemExit(1 if stage == os.environ.get('FAILURE') else 0)
''')

    def build(self, *options, failure=''):
        result = subprocess.run(
            ['bash', self.script, *options, '--test-signing', '--allow-unconfigured-providers'],
            cwd=self.root.parent, capture_output=True, text=True, timeout=30,
            env={**os.environ, 'BUSYMAX_FLUTTER_EXECUTABLE': str(self.flutter),
                 'COMMAND_LOG': str(self.log), 'FAILURE': failure},
        )
        return result, [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_locked_restore_and_integrity_bracket_both_builds(self):
        result, commands = self.build('--all')
        self.assertEqual(result.returncode, 0, result.stderr)
        verify = ['verify', '--sdk', str(self.flutter.parent.parent), '--require-target', 'android-release']
        post = [*verify, '--android-maven-mode', 'release']
        self.assertEqual(commands, [
            ['precache', '--android_gen_snapshot', '--android_internal_build'],
            ['pub', 'get', '--enforce-lockfile'],
            verify,
            ['build', 'apk', '--no-pub', '--release', '-t', 'lib/main_android.dart'],
            post,
            ['build', 'appbundle', '--no-pub', '--release', '-t', 'lib/main_android.dart'],
            post,
        ])

    def test_lockfile_or_integrity_failure_cannot_accept_an_artifact(self):
        for failure, build_count in [('pub', 0), ('before', 0), ('after', 1)]:
            with self.subTest(failure=failure):
                self.log.unlink(missing_ok=True)
                result, commands = self.build('--all', failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(sum(cmd[0] == 'build' for cmd in commands), build_count)
                self.assertNotIn('Artifacts are explicitly TEST-SIGNED', result.stdout)


if __name__ == '__main__':
    unittest.main()
