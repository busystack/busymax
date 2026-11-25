import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from verify_upstream_packages import verify, verify_android_maven, verify_sdk


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

    def check(self, *targets):
        return verify_sdk(self.root, self.spec, 'fixture-host', targets)

    def add_release_artifacts(self):
        directory = 'bin/cache/artifacts/engine/fixture-release'
        digest = hashlib.sha256(b'Official runtime').hexdigest()
        self.spec['artifacts']['fixture-host'].append({
            'directory': directory, 'required_for': ['fixture-release'],
            'files': {'engine.dll': digest, 'tools/gen_snapshot': digest},
        })
        return self.root / directory

    def test_required_mode_cannot_skip_an_absent_artifact_directory(self):
        self.add_release_artifacts()
        self.assertEqual(1, self.check())
        with self.assertRaisesRegex(ValueError, 'fixture-release/engine.dll'):
            self.check('fixture-release')

    def test_required_mode_cannot_skip_partially_acquired_artifacts(self):
        release = self.add_release_artifacts()
        release.mkdir(parents=True)
        (release / 'engine.dll').write_bytes(b'Official runtime')
        self.assertEqual(2, self.check())
        with self.assertRaisesRegex(ValueError, 'fixture-release/tools/gen_snapshot'):
            self.check('fixture-release')
        (release / 'tools').mkdir()
        (release / 'tools/gen_snapshot').write_bytes(b'Official runtime')
        self.assertEqual(3, self.check('fixture-release'))

    def test_present_optional_files_still_require_official_bytes(self):
        release = self.add_release_artifacts()
        release.mkdir(parents=True)
        (release / 'engine.dll').write_bytes(b'Modified runtime')
        with self.assertRaisesRegex(ValueError, 'fixture-release/engine.dll'):
            self.check()

    def test_optional_artifact_directory_cannot_be_a_dangling_symlink(self):
        release = self.add_release_artifacts()
        release.parent.mkdir(parents=True)
        release.symlink_to(self.root / 'absent', target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'directory was substituted'):
            self.check()

    def test_unknown_target_fails_closed(self):
        with self.assertRaisesRegex(ValueError, 'No reviewed SDK artifact requirements'):
            self.check('fixture-profile')

    def test_engine_stamp_must_match_the_reviewed_revision(self):
        self.identity['engineRevision'] = 'a' * 40
        cache = self.root / 'bin/cache'
        (cache / 'flutter.version.json').write_text(json.dumps(self.identity))
        stamp = cache / 'engine.stamp'
        stamp.write_text(self.identity['engineRevision'])
        self.assertEqual(1, self.check())
        stamp.write_text('b' * 40)
        with self.assertRaisesRegex(ValueError, 'engine stamp'):
            self.check()

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

    def link_file_fixture(self):
        source = self.root / 'link-fixture'
        source.write_bytes(b'fixture-target')
        self.git('add', 'link-fixture')
        blob = self.git('rev-parse', ':link-fixture').decode().strip()
        self.git('update-index', '--cacheinfo', f'120000,{blob},link-fixture')
        self.git('commit', '-m', 'Synthetic link fixture')
        self.identity['frameworkRevision'] = self.git('rev-parse', 'HEAD').decode().strip()
        (self.root / 'bin/cache/flutter.version.json').write_text(json.dumps(self.identity))
        self.git('config', 'core.symlinks', 'false')
        self.spec['artifacts']['win32'] = self.spec['artifacts']['fixture-host']
        return source, blob

    def test_link_replacement_diagnostic_reports_identity_without_target_contents(self):
        _, blob = self.link_file_fixture()
        with self.assertRaisesRegex(ValueError, 'source link was replaced: link-fixture') as failure:
            self.check()
        message = str(failure.exception)
        self.assertIn(f'entry type file; expected blob {blob}, got {blob}; core.symlinks=false', message)
        self.assertNotIn('fixture-target', message)

    def test_windows_git_link_file_retains_exact_target_identity(self):
        source, _ = self.link_file_fixture()
        self.assertEqual(1, verify_sdk(self.root, self.spec, 'win32'))
        self.assertEqual(b'fixture-target', source.read_bytes())
        for changed in [b'other-target', b'fixture-target\r\n']:
            source.write_bytes(changed)
            with self.assertRaisesRegex(ValueError, 'link-fixture .*identity mismatch'):
                verify_sdk(self.root, self.spec, 'win32')

    def test_windows_link_file_requires_the_explicit_git_checkout_setting(self):
        self.link_file_fixture()
        self.git('config', 'core.symlinks', 'true')
        with self.assertRaisesRegex(ValueError, 'source link was replaced: link-fixture'):
            verify_sdk(self.root, self.spec, 'win32')
        self.git('config', '--unset', 'core.symlinks')
        with self.assertRaisesRegex(ValueError, 'source link was replaced: link-fixture'):
            verify_sdk(self.root, self.spec, 'win32')

    def test_windows_git_link_file_cannot_be_missing_or_a_directory(self):
        source, _ = self.link_file_fixture()
        source.unlink()
        with self.assertRaisesRegex(ValueError, 'source link was replaced: link-fixture'):
            verify_sdk(self.root, self.spec, 'win32')
        source.mkdir()
        with self.assertRaisesRegex(ValueError, 'source link was replaced: link-fixture'):
            verify_sdk(self.root, self.spec, 'win32')

    def test_native_sdk_link_target_remains_exact(self):
        source, _ = self.link_file_fixture()
        source.unlink()
        source.symlink_to('fixture-target')
        self.assertEqual(1, self.check())
        source.unlink()
        source.symlink_to('other-target')
        with self.assertRaisesRegex(ValueError, 'link-fixture .*identity mismatch'):
            self.check()

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


class AndroidEngineArtifactsTest(unittest.TestCase):
    def test_catalog_covers_supported_abis_and_modes_on_both_hosts(self):
        path = Path(__file__).with_name('upstream_packages.json')
        sdk = json.loads(path.read_text(encoding='utf-8'))['flutter']
        engine = sdk['identity']['engineRevision']
        upstream = f'https://storage.googleapis.com/flutter_infra_release/flutter/{engine}'
        for host, host_arch in [('linux', 'linux-x64'), ('win32', 'windows-x64')]:
            artifacts = {group['directory']: group for group in sdk['artifacts'][host]}
            for mode in ('debug', 'profile', 'release'):
                for arch in ('arm', 'arm64', 'x64'):
                    with self.subTest(host=host, arch=arch, mode=mode):
                        target = f'android-{mode}'
                        platform = f'android-{arch}' + ('' if mode == 'debug' else f'-{mode}')
                        directory = f'bin/cache/artifacts/engine/{platform}'
                        group = artifacts[directory]
                        self.assertIn(target, group['required_for'])
                        self.assertRegex(group['files']['flutter.jar'], r'^[0-9a-f]{64}$')
                        self.assertEqual(group['archives'][0]['archive_url'], f'{upstream}/{platform}/artifacts.zip')
                        if mode != 'debug':
                            compiler = artifacts[f'{directory}/{host_arch}']
                            self.assertIn(target, compiler['required_for'])
                            name = 'gen_snapshot.exe' if host == 'win32' else 'gen_snapshot'
                            self.assertRegex(compiler['files'][name], r'^[0-9a-f]{64}$')
                            self.assertEqual(compiler['archives'][0]['archive_url'], f'{upstream}/{platform}/{host_arch}.zip')
                for arch in ('flutter_embedding', 'armeabi_v7a', 'arm64_v8a', 'x86_64'):
                    module = f'{arch}_{mode}'
                    for extension in ('jar', 'pom'):
                        name = f'{module}-1.0.0-{engine}.{extension}'
                        self.assertRegex(sdk['android_maven'][mode][module][name], r'^[0-9a-f]{64}$')

    def test_maven_cache_requires_official_bytes_for_every_candidate(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            revision = 'a' * 40
            module = 'arm64_v8a_release'
            name = f'{module}-1.0.0-{revision}.jar'
            digest = hashlib.sha256(b'Official engine').hexdigest()
            expected = {
                'identity': {'engineRevision': revision},
                'android_maven': {'release': {module: {name: digest}}},
            }
            with self.assertRaisesRegex(ValueError, 'Maven artifact missing'):
                verify_android_maven(home, expected, 'release')
            component = home / f'caches/modules-2/files-2.1/io.flutter/{module}/1.0.0-{revision}'
            first = component / 'first' / name
            first.parent.mkdir(parents=True)
            first.write_bytes(b'Official engine')
            self.assertEqual(1, verify_android_maven(home, expected, 'release'))
            second = component / 'second' / name
            second.parent.mkdir()
            second.write_bytes(b'Modified engine')
            with self.assertRaisesRegex(ValueError, name):
                verify_android_maven(home, expected, 'release')


if __name__ == '__main__': unittest.main()
