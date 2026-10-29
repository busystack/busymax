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
        self.git = git
        git('init', '--template=', '--initial-branch=fixture')
        (self.root / '.gitattributes').write_bytes(b'* text=auto\n*.dart text\n*.md text\n*.bat text eol=crlf\n*.bin binary\n')
        (self.root / 'framework.dart').write_text('const official = true;\n')
        git('add', '.gitattributes', 'framework.dart'); git('commit', '-m', 'Official source fixture')
        revision = git('rev-parse', 'HEAD').decode().strip()
        self.identity = {'frameworkRevision': revision, 'frameworkVersion': '3.47.5', 'dartSdkVersion': '3.13.4'}
        cache = self.root / 'bin/cache'; cache.mkdir(parents=True)
        (cache / 'flutter.version.json').write_text(json.dumps(self.identity))
        self.binary = cache / 'dart-sdk/bin/dart'; self.binary.parent.mkdir(parents=True); self.binary.write_bytes(b'Official compiler fixture')
        artifact = {'directory': 'bin/cache', 'required': True, 'files': {'dart-sdk/bin/dart': hashlib.sha256(self.binary.read_bytes()).hexdigest()}}
        self.spec = {'identity': self.identity, 'artifacts': {'fixture-host': [artifact]}}

    def check(self):
        return verify_sdk(self.root, self.spec, 'fixture-host')

    def commit_source(self, *paths):
        self.git('add', *paths); self.git('commit', '-m', 'Application-owned source fixture')
        self.identity['frameworkRevision'] = self.git('rev-parse', 'HEAD').decode().strip()
        (self.root / 'bin/cache/flutter.version.json').write_text(json.dumps(self.identity))

    def test_official_source_and_binary_are_required_together(self):
        self.assertEqual(1, self.check())
        self.binary.write_bytes(b'Modified compiler with unchanged version')
        with self.assertRaisesRegex(ValueError, 'compiler/runtime'): self.check()

    def test_modified_framework_is_rejected_with_unchanged_version_file(self):
        (self.root / 'framework.dart').write_text('const downstream = true;\n')
        with self.assertRaisesRegex(ValueError, r'source modifications: framework\.dart \(Git blob identity mismatch after upstream text normalization; expected [0-9a-f]{40}, got [0-9a-f]{40}\)') as failure:
            self.check()
        self.assertNotIn('downstream', str(failure.exception))

    def test_missing_tracked_source_identifies_the_failed_path(self):
        (self.root / 'framework.dart').unlink()
        with self.assertRaisesRegex(ValueError, r'missing or substituted: framework\.dart'):
            self.check()

    def test_link_replacement_diagnostic_reports_identity_without_target_contents(self):
        source = self.root / 'link-fixture'
        source.write_bytes(b'fixture-target')
        self.git('add', 'link-fixture')
        blob = self.git('rev-parse', ':link-fixture').decode().strip()
        self.git('update-index', '--cacheinfo', f'120000,{blob},link-fixture')
        self.git('commit', '-m', 'Synthetic link fixture')
        self.identity['frameworkRevision'] = self.git('rev-parse', 'HEAD').decode().strip()
        (self.root / 'bin/cache/flutter.version.json').write_text(json.dumps(self.identity))
        self.git('config', 'core.symlinks', 'false')
        with self.assertRaisesRegex(ValueError, 'source link was replaced: link-fixture') as failure:
            self.check()
        message = str(failure.exception)
        self.assertIn(f'entry type file; expected blob {blob}, got {blob}; core.symlinks=false', message)
        self.assertNotIn('fixture-target', message)

    def test_framework_revision_cannot_be_relabelled_by_version_metadata(self):
        self.spec['identity'] = {**self.identity, 'frameworkRevision': '0' * 40}
        (self.root / 'bin/cache/flutter.version.json').write_text(json.dumps(self.spec['identity']))
        with self.assertRaisesRegex(ValueError, 'approved upstream revision'):
            self.check()

    def test_existing_windows_script_normalization_keeps_source_edits_detectable(self):
        source = self.root / 'bootstrap.bat'
        source.write_bytes(b'@echo off\necho Official fixture\n')
        self.git('add', 'bootstrap.bat'); self.git('commit', '-m', 'Script fixture')
        revision = self.git('rev-parse', 'HEAD').decode().strip()
        self.identity['frameworkRevision'] = revision
        (self.root / 'bin/cache/flutter.version.json').write_text(json.dumps(self.identity))
        source.write_bytes(b'@echo off\r\necho Official fixture\r\n')
        self.assertEqual(1, self.check())
        source.write_bytes(b'@echo off\r\necho Changed fixture\r\n')
        with self.assertRaisesRegex(ValueError, r'bootstrap\.bat \(Git blob identity mismatch'):
            self.check()

    def test_windows_markdown_checkout_uses_the_pinned_text_attributes(self):
        source = self.root / '.agents/agents/README.md'
        source.parent.mkdir(parents=True)
        original = b'# BusyMax integrity fixture\n\nSynthetic upstream text.\n'
        source.write_bytes(original)
        self.commit_source('.agents/agents/README.md')
        windows = original.replace(b'\n', b'\r\n')
        source.write_bytes(windows)
        self.assertEqual(1, self.check())
        self.assertEqual(windows, source.read_bytes(), 'Verification must not repair an installation')
        source.write_bytes(windows.replace(b'Synthetic', b'Modified'))
        with self.assertRaisesRegex(ValueError, r'\.agents/agents/README\.md .*identity mismatch'):
            self.check()

    def test_auto_text_without_a_suffix_and_quoted_paths(self):
        relative = 'fixtures/Unicode 漢 name with spaces'
        source = self.root / relative
        source.parent.mkdir()
        source.write_bytes(b'BusyMax automatic text fixture\nsecond line\n')
        self.commit_source(relative)
        source.write_bytes(source.read_bytes().replace(b'\n', b'\r\n'))
        self.assertEqual(1, self.check())

    def test_binary_crlf_bytes_and_local_attribute_overrides_cannot_bypass_identity(self):
        source = self.root / 'data.bin'
        original = b'BusyMax synthetic binary\nwith ASCII and CRLF-like bytes\n'
        source.write_bytes(original)
        self.commit_source('data.bin')
        source.write_bytes(original.replace(b'\n', b'\r\n'))
        # Neither SDK-local attributes nor a clean filter may relabel bytes.
        (self.root / '.git/info').mkdir(exist_ok=True)
        (self.root / '.git/info/attributes').write_bytes(b'*.bin text filter=fixture\n')
        self.git('config', 'filter.fixture.clean', 'fixture-clean-filter-must-not-run')
        self.git('config', 'filter.fixture.required', 'true')
        self.git('config', 'core.autocrlf', 'true')
        with self.assertRaisesRegex(ValueError, r'data\.bin .*identity mismatch'):
            self.check()

    def test_nested_binary_rule_overrides_the_root_text_rule(self):
        directory = self.root / 'assets'
        directory.mkdir()
        (directory / '.gitattributes').write_bytes(b'*.md binary\n')
        source = directory / 'binary.md'
        source.write_bytes(b'BusyMax binary fixture\n')
        self.commit_source('assets')
        source.write_bytes(b'BusyMax binary fixture\r\n')
        with self.assertRaisesRegex(ValueError, r'assets/binary\.md .*identity mismatch'):
            self.check()

    def test_auto_binary_with_nul_and_crlf_is_byte_exact(self):
        source = self.root / 'compiler-fixture'
        source.write_bytes(b'BusyMax\x00\r\nbinary fixture\r\n')
        self.commit_source('compiler-fixture')
        source.write_bytes(source.read_bytes().replace(b'\r\n', b'\n'))
        with self.assertRaisesRegex(ValueError, r'compiler-fixture .*identity mismatch'):
            self.check()

    def test_nul_bytes_are_exact_even_under_an_explicit_text_rule(self):
        source = self.root / 'binary-fixture.dart'
        source.write_bytes(b'BusyMax\x00binary fixture\n')
        self.commit_source('binary-fixture.dart')
        source.write_bytes(b'BusyMax\x00binary fixture\r\n')
        with self.assertRaisesRegex(ValueError, r'binary-fixture\.dart .*identity mismatch'):
            self.check()

    def test_runtime_with_crlf_like_bytes_is_byte_exact(self):
        original = b'Official\x00\r\ncompiler\r\nfixture'
        self.binary.write_bytes(original)
        self.spec['artifacts']['fixture-host'][0]['files']['dart-sdk/bin/dart'] = hashlib.sha256(original).hexdigest()
        self.assertEqual(1, self.check())
        self.binary.write_bytes(original.replace(b'\r\n', b'\n'))
        with self.assertRaisesRegex(ValueError, 'compiler/runtime'):
            self.check()

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
