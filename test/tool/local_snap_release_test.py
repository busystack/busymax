"""Contracts for the production entry point; all credentials here are synthetic."""
import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('local_release', ROOT / 'tool/release/build_snap_local.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class LocalReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='busymax-local-release-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.credentials = self.root / 'desktop.json'
        self.installed = {'client_id': 'release-fixture.apps.googleusercontent.com',
                          'project_id': 'release-fixture', 'client_secret': 'fixture-secret-never-print'}
        self.write_google()

    def write_google(self, value=None):
        self.credentials.write_text(json.dumps(value if value is not None else {'installed': self.installed}))

    def config(self):
        return release.google_configuration(self.credentials, self.source)

    def source_files(self):
        for name in ['pubspec.yaml', 'snap/snapcraft.yaml', 'linux/io.busystack.busymax.metainfo.xml',
                     'windows/runner/Runner.rc', 'android/app/build.gradle.kts',
                     'tool/check_release_pull_request.py', 'tool/shared_dependencies.json']:
            target = self.source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)

    def source_runner(self, args, cwd, **kwargs):
        if args[1:3] == ['rev-parse', 'HEAD']:
            return 'a' * 40
        if args[1:3] == ['branch', '--show-current']:
            return 'release/v0.3.1'
        return ''

    def bundle(self, root):
        for name in ['busymax', 'lib/libapp.so', 'lib/libflutter_linux_gtk.so', 'data/icudtl.dat',
                     'data/flutter_assets/docs/google_setup.md', 'data/flutter_assets/docs/microsoft_setup.md',
                     'data/flutter_assets/assets/branding/busymax-logo.svg']:
            p = root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes((' '.join(self.config().values())).encode() if name == 'lib/libapp.so' else b'fixture')
        (root / 'data/flutter_assets/version.json').write_text('{"app_name":"busymax","version":"0.3.1"}')
        os.chmod(root / 'busymax', 0o755)

    def test_valid_desktop_derives_only_managed_fields(self):
        values = self.config()
        self.assertEqual(values['BUSYMAX_GOOGLE_OAUTH_PROJECT_ID'], self.installed['project_id'])
        self.assertNotIn('GOOGLE_OAUTH_CLIENT_ID', values)
        self.assertEqual(values['BUSYMAX_GOOGLE_OAUTH_CLIENT_ID'], self.installed['client_id'])

    def test_wrong_client_types_rejected(self):
        for value in [{'web': self.installed}, {'type': 'service_account'},
                      {'installed': self.installed, 'web': {}}]:
            self.write_google(value)
            with self.assertRaises(release.ReleaseError): self.config()

    def test_known_application_fixture_rejected(self):
        self.installed['client_id'] = 'fixture.apps.googleusercontent.com'; self.write_google()
        with self.assertRaises(release.ReleaseError): self.config()

    def test_missing_client_id_rejected(self):
        del self.installed['client_id']; self.write_google()
        with self.assertRaises(release.ReleaseError): self.config()

    def test_missing_project_rejected(self):
        del self.installed['project_id']; self.write_google()
        with self.assertRaises(release.ReleaseError): self.config()

    def test_malformed_json_is_safe(self):
        self.credentials.write_text('{"secret":"must-not-print"')
        with self.assertRaises(release.ReleaseError) as caught: self.config()
        self.assertNotIn('must-not-print', str(caught.exception))

    def test_directory_selection_requires_one_json(self):
        selected = self.root / 'selection'; selected.mkdir()
        shutil.copy2(self.credentials, selected / 'first.json')
        self.assertEqual(release.google_configuration(selected, self.source), self.config())
        shutil.copy2(self.credentials, selected / 'second.json')
        with self.assertRaises(release.ReleaseError): release.google_configuration(selected, self.source)
        self.assertEqual(release.google_configuration(selected / 'first.json', self.source), self.config())

    def test_secrets_redacted_in_build_output(self):
        log = self.root / 'build.log'
        with patch.object(subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, self.installed['client_secret'])):
            with self.assertRaises(release.ReleaseError) as caught:
                release.run(['flutter'], self.source, log=log, redactions=self.config().values())
        self.assertNotIn(self.installed['client_secret'], log.read_text() + str(caught.exception))

    def test_download_must_stay_outside_git(self):
        internal = self.source / 'desktop.json'; shutil.copy2(self.credentials, internal)
        with self.assertRaises(release.ReleaseError): release.google_configuration(internal, self.source)
        self.source_files()
        def runner(args, cwd, **kwargs):
            if args[1] == 'ls-files': return 'client_secret_download.json'
            return self.source_runner(args, cwd, **kwargs)
        with patch.object(release, 'run', side_effect=runner):
            with self.assertRaises(release.ReleaseError): release.source_gate(self.source, 'a'*40, '0.3.1')

    def test_wrong_source_version_rejected(self):
        self.source_files()
        for old in ['0.2.4', '0.3.0']:
            (self.source / 'pubspec.yaml').write_text(f'version: {old}\n')
            with patch.object(release, 'run', side_effect=self.source_runner):
                with self.assertRaises(release.ReleaseError): release.source_gate(self.source, 'a'*40, '0.3.1')

    def test_wrong_revision_rejected(self):
        with patch.object(release, 'run', side_effect=self.source_runner):
            with self.assertRaises(release.ReleaseError): release.source_gate(self.source, 'b'*40, '0.3.1')

    def test_existing_workspace_and_shared_repository_untouched(self):
        workspace = self.root / 'existing'; workspace.mkdir()
        shared = workspace / 'busystack_graph'; shared.mkdir()
        sentinel = shared / 'local-work'; sentinel.write_text('keep')
        with self.assertRaises(release.ReleaseError): release.workspace_gate(workspace, self.source)
        self.assertEqual(sentinel.read_text(), 'keep')

    def test_wrong_snapcraft_version_rejected(self):
        sdk = self.root / 'sdk/bin'; (sdk / 'cache/dart-sdk/bin').mkdir(parents=True)
        flutter = sdk / 'flutter'; flutter.touch(); (sdk / 'cache/dart-sdk/bin/dart').touch()
        with patch.object(release, 'run', side_effect=['{}', 'snapcraft 8.0.0']):
            with self.assertRaises(release.ReleaseError): release.tool_gate(self.source, flutter)

    def test_missing_bundle_rejected(self):
        with self.assertRaises(release.ReleaseError): release.bundle_gate(self.root / 'missing', self.config())

    def test_old_flutter_version_is_rejected(self):
        bundle = self.root / 'bundle'; self.bundle(bundle)
        (bundle / 'data/flutter_assets/version.json').write_text('{"app_name":"busymax","version":"0.3.0"}')
        with self.assertRaises(release.ReleaseError): release.bundle_gate(bundle, self.config(), '0.3.1')

    def test_unconfigured_compilation_rejected(self):
        bundle = self.root / 'bundle'; self.bundle(bundle)
        (bundle / 'lib/libapp.so').write_bytes(b'unconfigured')
        with self.assertRaises(release.ReleaseError): release.bundle_gate(bundle, self.config())

    def test_missing_final_snap_rejected(self):
        with self.assertRaises(release.ReleaseError):
            release.package_gate(self.root / 'missing.snap', self.root, '0.3.1', self.config(), self.source)

    def package_tree(self, tree):
        self.bundle(tree)
        for name in ['share/applications/io.busystack.busymax.desktop',
                     'share/applications/io.busystack.busymax-autostart.desktop',
                     'share/icons/hicolor/scalable/apps/io.busystack.busymax.svg']:
            p = tree / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_text('fixture')
        p = tree / 'share/metainfo/io.busystack.busymax.metainfo.xml'; p.parent.mkdir(parents=True)
        p.write_text('<component><releases><release version="0.3.1"/></releases></component>')
        p = tree / 'meta/snap.yaml'; p.parent.mkdir()
        (tree / 'meta/gui').mkdir(); (tree / 'meta/gui/busymax.desktop').write_text('fixture')
        p.write_text('name: busymax\nversion: 0.3.1\nbase: core24\ngrade: devel\nconfinement: strict\napps:\n  busymax:\n    command: busymax\n    autostart: io.busystack.busymax-autostart.desktop\n')

    def test_packaged_metadata_verified(self):
        snap = self.root / 'busymax.snap'; snap.touch()
        self.package_tree(self.root / 'inspection')
        with patch.object(release, 'run'):
            release.package_gate(snap, self.root, '0.3.1', self.config(), self.source)
            with self.assertRaises(release.ReleaseError): release.package_gate(snap, self.root, '0.3.0', self.config(), self.source)
        (self.root / 'inspection/meta/snap.yaml').write_text('confinement: classic')
        with patch.object(release, 'run'):
            with self.assertRaises(release.ReleaseError): release.package_gate(snap, self.root, '0.3.1', self.config(), self.source)

    def test_unexpected_output_artifacts_rejected(self):
        snap = self.root / 'busymax.snap'; snap.touch(); (self.root / 'other.snap').touch()
        with self.assertRaises(release.ReleaseError): release.package_gate(snap, self.root, '0.3.1', self.config(), self.source)

    def test_upload_and_destructive_modes_absent(self):
        script = (ROOT / 'tool/release/build_snap_local.py').read_text()
        for forbidden in ['snapcraft upload', 'snapcraft login', '--destructive-mode', 'reset --hard', 'clean -fd', 'worktree remove']:
            self.assertNotIn(forbidden, script)
        self.assertIn("'pack', '--use-lxd'", script)

    def mocked_build(self, failure=None):
        self.source_files()
        workspace = self.root / 'workspace'
        options = argparse.Namespace(source=self.source, workspace=workspace, google_oauth=self.credentials,
                                     local_config=None, revision='a'*40, version='0.3.1', flutter=self.root/'flutter')
        seen = []
        def runner(args, cwd, **kwargs):
            seen.append([str(a) for a in args])
            if args[0] == 'git' and args[1] == 'clone': shutil.copytree(self.source, args[-1])
            if args[0] == 'git' and args[1] == 'ls-files': return ''
            if failure == 'dependency' and 'tool/checkout_shared_dependencies.py' in args:
                raise release.ReleaseError('Missing pinned dependency.')
            if failure == 'stale' and args[0] == 'git' and args[1] == 'checkout':
                self.bundle(workspace/'busymax/build/linux/x64/release/bundle')
            if len(args) > 2 and args[1:3] == ['build', 'linux']:
                configuration = Path(str(args[-1]).split('=',1)[1])
                self.assertEqual(configuration.stat().st_mode & 0o777, 0o600)
                self.assertFalse(configuration.is_relative_to(workspace / 'busymax'))
                self.bundle(workspace/'busymax/build/linux/x64/release/bundle')
            if args[:2] == ['snapcraft', 'pack'] and failure != 'snap':
                (workspace/'artifacts/busymax_0.3.1_amd64.snap').write_bytes(b'fixture-snap')
            if args[0] == 'unsquashfs': self.package_tree(Path(args[3]))
            if 'tool/release/verify_snap_runtime.sh' in args:
                if failure == 'runtime': raise release.ReleaseError('Runtime failure.')
                Path(args[-1]).write_text(json.dumps({'startup_x11':True,'elf_dependencies':True,'startup_wayland':True,'restart':True,'confined_network':True,
                'snap_sha256':release.hashlib.sha256(b'fixture-snap').hexdigest()}))
            return ''
        with patch.object(release, 'source_gate'), patch.object(release, 'tool_gate', return_value=self.root/'dart'), \
             patch.object(release, 'run', side_effect=runner), contextlib.redirect_stdout(io.StringIO()):
            if failure:
                with self.assertRaises(release.ReleaseError): release.build(options)
            else:
                artifact = release.build(options); self.assertTrue(artifact.exists())
        return workspace, seen

    def test_successful_pipeline_has_checksum_and_safe_manifest(self):
        workspace, seen = self.mocked_build()
        manifest = json.loads((workspace/'artifacts/manifest.json').read_text())
        self.assertFalse(manifest['release_ready'])
        self.assertEqual(manifest['revision'], 'a'*40)
        self.assertTrue(list((workspace/'artifacts').glob('*.sha256')))
        self.assertFalse(list(workspace.glob('.oauth-*')))
        self.assertNotIn(self.installed['client_secret'], json.dumps(manifest))
        self.assertTrue(any('tool/checkout_shared_dependencies.py' in cmd for cmd in seen))
        self.assertTrue(any(cmd[:2] == ['snapcraft','pack'] and '--use-lxd' in cmd for cmd in seen))

    def test_failed_build_never_emits_success_manifest(self):
        for failure in ['dependency','stale','snap','runtime']:
            with self.subTest(failure=failure):
                workspace, _ = self.mocked_build(failure)
                self.assertFalse((workspace/'artifacts/manifest.json').exists())
                self.assertFalse(list(workspace.glob('.oauth-*')))
                shutil.rmtree(workspace)  # Only this test's own temporary fixture.

    def test_optional_microsoft_and_invalid_public_settings(self):
        self.assertEqual(release.public_configuration(None), {})
        p = self.root/'public.json'
        for value in [{'MICROSOFT_OAUTH_CLIENT_ID':'bad'}, {'BUSYMAX_MICROSOFT_OAUTH_CLIENT_ID':''},
                      {'GOOGLE_OAUTH_PROJECT_ID':'manual-project'}]:
            p.write_text(json.dumps(value))
            with self.assertRaises(release.ReleaseError): release.public_configuration(p)
        p.write_text('{"MICROSOFT_OAUTH_CLIENT_ID":"01234567-89ab-cdef-0123-456789abcdef"}')
        self.assertIn('MICROSOFT_OAUTH_CLIENT_ID', release.public_configuration(p))


if __name__ == '__main__': unittest.main()
