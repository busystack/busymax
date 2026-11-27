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
        self.global_cache = self.root / 'existing-pub-cache'
        self.global_cache.mkdir()
        self.poisoned_package = self.global_cache / 'unlisted.dart'
        self.poisoned_package.write_text('modified cached package')
        self.outputs = self.root / 'build/app/outputs'
        self.release_files = [
            self.outputs / 'flutter-apk/app-release.apk',
            self.outputs / 'flutter-apk/app-release.apk.sha1',
            self.outputs / 'apk/release/app-release.apk',
            self.outputs / 'bundle/release/app-release.aab',
        ]
        self.flutter = self.root / 'sdk/bin/flutter'
        self.registrant = self.root / 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'
        self.registrant.parent.mkdir(parents=True)
        self.registrant.write_text('debug')
        self.script = self.root / 'tool/android/build_release.sh'
        self.script.parent.mkdir(parents=True)
        shutil.copy2(ROOT / 'tool/android/build_release.sh', self.script)
        prerequisite = self.script.with_name('check_prerequisites.sh')
        prerequisite.write_text('#!/usr/bin/env bash\nexit 0\n')
        prerequisite.chmod(0o755)
        self.flutter.parent.mkdir(parents=True)
        self.flutter.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
with open(os.environ['COMMAND_LOG'], 'a') as log:
    print(json.dumps(sys.argv[1:]), file=log)
cache = Path(os.environ['PUB_CACHE'])
assert os.environ['PUB_HOSTED_URL'] == 'https://pub.dev'
if sys.argv[1] == 'pub':
    assert cache.is_dir() and not list(cache.iterdir())
    (cache / 'unlisted.dart').write_text('upstream archive')
if sys.argv[1] == 'build':
    assert Path(os.environ['REGISTRANT']).read_text() == 'release'
    assert (cache / 'unlisted.dart').read_text() == 'upstream archive'
    outputs = Path('build/app/outputs')
    names = ['flutter-apk/app-release.apk', 'flutter-apk/app-release.apk.sha1',
             'apk/release/app-release.apk'] if sys.argv[2] == 'apk' else ['bundle/release/app-release.aab']
    for name in names:
        target = outputs / name
        assert not target.exists()
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('newly compiled')
raise SystemExit(1 if sys.argv[1] == os.environ.get('FAILURE') else 0)
''')
        self.flutter.chmod(0o755)
        dart = self.flutter.parent / 'cache/dart-sdk/bin/dart'
        dart.parent.mkdir(parents=True)
        dart.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
assert sys.argv[1] == '--packages=' + sys.argv[3] + '/packages/flutter_tools/.dart_tool/package_config.json'
assert 'injectPlugins(project, releaseMode: true, androidPlatform: true)' in Path(sys.argv[2]).read_text()
with open(os.environ['COMMAND_LOG'], 'a') as log:
    print(json.dumps(['generate-release-registrant']), file=log)
Path(os.environ['REGISTRANT']).write_text('release')
''')
        dart.chmod(0o755)
        (self.root / 'tool/verify_upstream_packages.py').write_text('''
import json, os, sys
from pathlib import Path
with open(os.environ['COMMAND_LOG'], 'a') as log:
    print(json.dumps(['verify', *sys.argv[1:]]), file=log)
assert (Path(os.environ['PUB_CACHE']) / 'unlisted.dart').read_text() == 'upstream archive'
stage = 'after' if '--android-maven-mode' in sys.argv else 'before'
failure = os.environ.get('FAILURE')
after_bundle = stage == 'after' and Path('build/app/outputs/bundle/release/app-release.aab').is_file()
raise SystemExit(1 if stage == failure or (after_bundle and failure == 'after-appbundle') else 0)
''')

    def build(self, *options, failure=''):
        result = subprocess.run(
            ['bash', self.script, *options, '--test-signing', '--allow-unconfigured-providers'],
            cwd=self.root.parent, capture_output=True, text=True, timeout=30,
            env={**os.environ, 'BUSYMAX_FLUTTER_EXECUTABLE': str(self.flutter),
                 'PUB_CACHE': str(self.global_cache), 'PUB_HOSTED_URL': 'https://fixture.invalid',
                 'COMMAND_LOG': str(self.log), 'FAILURE': failure, 'REGISTRANT': str(self.registrant)},
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
            ['generate-release-registrant'],
            ['build', 'apk', '--no-pub', '--release', '-t', 'lib/main_android.dart'],
            post,
            ['build', 'appbundle', '--no-pub', '--release', '-t', 'lib/main_android.dart'],
            post,
        ])
        self.assertEqual(self.registrant.read_text(), 'debug')
        self.assertEqual(self.poisoned_package.read_text(), 'modified cached package')
        self.assertTrue(all(path.is_file() for path in self.release_files))

    def test_lockfile_or_integrity_failure_cannot_accept_an_artifact(self):
        for failure, build_count in [('pub', 0), ('before', 0), ('build', 1),
                                     ('after', 1), ('after-appbundle', 2)]:
            with self.subTest(failure=failure):
                self.log.unlink(missing_ok=True)
                for path in self.release_files:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('stale output')
                result, commands = self.build('--all', failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(sum(cmd[0] == 'build' for cmd in commands), build_count)
                self.assertNotIn('Artifacts are explicitly TEST-SIGNED', result.stdout)
                self.assertEqual(self.registrant.read_text(), 'debug')
                self.assertFalse(any(path.exists() for path in self.release_files))

    def test_rejection_does_not_delete_unselected_or_debug_outputs(self):
        aab = self.release_files[-1]
        debug = self.outputs / 'flutter-apk/app-debug.apk'
        for path in [aab, debug]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('unrelated output')
        result, _ = self.build('--apk', failure='after')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(path.exists() for path in self.release_files[:-1]))
        for path in [aab, debug]:
            self.assertEqual(path.read_text(), 'unrelated output')


if __name__ == '__main__':
    unittest.main()
