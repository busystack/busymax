import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from verify_upstream_packages import verify, verify_sdk


class UpstreamPackagesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.package = self.root / 'official'
        (self.package / 'lib').mkdir(parents=True)
        (self.package / 'pubspec.yaml').write_text('name: selected\nversion: 1.0.0\n')
        (self.package / 'lib/client.dart').write_text('const upstream = true;\n')
        self.configuration = self.root / 'package_config.json'
        self.configuration.write_text(json.dumps({'packages': [{'name': 'selected', 'rootUri': self.package.as_uri()}]}))
        self.manifest = self.root / 'upstream.json'
        self.record = {'name': 'selected', 'version': '1.0.0', 'archive_url': 'https://pub.dev/api/archives/selected-1.0.0.tar.gz', 'archive_sha256': 'a' * 64,
                       'files': {p.relative_to(self.package).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in self.package.rglob('*') if p.is_file()}}
        self.write_manifest()

    def write_manifest(self):
        self.manifest.write_text(json.dumps({'schema': 1, 'packages': [self.record]}))

    def check(self):
        return verify(self.configuration, self.manifest)

    def test_unchanged_publisher_source_and_encoded_paths(self):
        moved = self.root / 'Unicode 漢 package'
        self.package.rename(moved)
        self.configuration.write_text(json.dumps({'packages': [{'name': 'selected', 'rootUri': moved.as_uri()}]}))
        self.assertEqual('selected', self.check()[0]['name'])

    def test_same_version_modified_source_is_rejected(self):
        (self.package / 'lib/client.dart').write_text('const downstream = true;\n')
        with self.assertRaisesRegex(ValueError, 'source modified'): self.check()

    def test_added_source_is_rejected(self):
        (self.package / 'lib/downstream.dart').write_text('unapproved')
        with self.assertRaisesRegex(ValueError, 'source added'): self.check()

    def test_missing_source_is_rejected(self):
        (self.package / 'lib/client.dart').unlink()
        with self.assertRaisesRegex(ValueError, 'missing or substituted'): self.check()

    def test_symlink_escape_is_rejected(self):
        source = self.package / 'lib/client.dart'
        outside = self.root / 'outside.dart'; outside.write_bytes(source.read_bytes()); source.unlink()
        try: source.symlink_to(outside)
        except OSError as failure: self.fail('Native symlink fixture unavailable: ' + str(failure))
        with self.assertRaisesRegex(ValueError, 'substituted'): self.check()

    def test_manifest_path_escape_is_rejected(self):
        self.record['files']['../outside'] = 'a' * 64; self.write_manifest()
        with self.assertRaisesRegex(ValueError, 'escapes'): self.check()

    def test_required_and_retired_dependencies_are_distinct(self):
        self.configuration.write_text('{"packages": []}')
        with self.assertRaisesRegex(ValueError, 'unresolved'): self.check()
        self.record['optional'] = True; self.write_manifest(); self.assertEqual([], self.check())

    def test_generated_output_does_not_exempt_nested_source_directories(self):
        (self.package / 'build').mkdir(); (self.package / 'build/generated').write_text('tool output')
        self.check()
        (self.package / 'lib/build').mkdir(); (self.package / 'lib/build/downstream.dart').write_text('unapproved')
        with self.assertRaisesRegex(ValueError, 'source added'): self.check()


class OfficialSdkTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
        self.environment.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')
        def git(*args):
            return subprocess.check_output(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-C', str(self.root), *args], env=self.environment, stderr=subprocess.DEVNULL, timeout=10)
        git('init', '--template=', '--initial-branch=fixture')
        (self.root / 'framework.dart').write_text('const official = true;\n')
        git('add', 'framework.dart'); git('commit', '-m', 'Official source fixture')
        revision = git('rev-parse', 'HEAD').decode().strip()
        self.identity = {'frameworkRevision': revision, 'frameworkVersion': '3.47.5', 'dartSdkVersion': '3.13.4'}
        cache = self.root / 'bin/cache'; cache.mkdir(parents=True)
        (cache / 'flutter.version.json').write_text(json.dumps(self.identity))
        self.binary = cache / 'dart-sdk/bin/dart'; self.binary.parent.mkdir(parents=True); self.binary.write_bytes(b'Official compiler fixture')
        artifact = {'directory': 'bin/cache', 'required': True, 'files': {'dart-sdk/bin/dart': hashlib.sha256(self.binary.read_bytes()).hexdigest()}}
        self.spec = {'identity': self.identity, 'artifacts': {'fixture-host': [artifact]}}

    def check(self):
        return verify_sdk(self.root, self.spec, 'fixture-host')

    def test_official_source_and_binary_are_required_together(self):
        self.assertEqual(1, self.check())
        self.binary.write_bytes(b'Modified compiler with unchanged version')
        with self.assertRaisesRegex(ValueError, 'compiler/runtime'): self.check()

    def test_modified_framework_is_rejected_with_unchanged_version_file(self):
        (self.root / 'framework.dart').write_text('const downstream = true;\n')
        with self.assertRaisesRegex(ValueError, 'source modifications'): self.check()

    def test_changed_version_cannot_relabel_the_runtime(self):
        (self.root / 'bin/cache/flutter.version.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'identity'): self.check()

    def test_missing_required_compiler_is_rejected(self):
        self.binary.unlink()
        with self.assertRaisesRegex(ValueError, 'compiler/runtime'): self.check()

    def test_only_cataloged_publisher_overlay_variants_are_accepted(self):
        files = self.spec['artifacts']['fixture-host'][0]['files']
        original = files['dart-sdk/bin/dart']
        overlay = b'Another official publisher artifact fixture'
        files['dart-sdk/bin/dart'] = [original, hashlib.sha256(overlay).hexdigest()]
        self.binary.write_bytes(overlay); self.assertEqual(1, self.check())
        self.binary.write_bytes(b'Unreviewed downstream artifact')
        with self.assertRaisesRegex(ValueError, 'compiler/runtime'): self.check()

    def test_inherited_git_redirection_cannot_substitute_another_index(self):
        previous = os.environ.get('GIT_INDEX_FILE')
        try:
            os.environ['GIT_INDEX_FILE'] = str(self.root / 'unapproved-index')
            self.assertEqual(1, self.check())
        finally:
            if previous is None: os.environ.pop('GIT_INDEX_FILE', None)
            else: os.environ['GIT_INDEX_FILE'] = previous


if __name__ == '__main__': unittest.main()
