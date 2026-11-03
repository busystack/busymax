import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('hygiene', Path(__file__).resolve().parents[2] / 'tool/check_repository_hygiene.py')
hygiene = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hygiene)


class HygieneTest(unittest.TestCase):
    def test_disposable_outputs_rejected(self):
        for name in ['qa-results/failure.png', 'test-results/run.json',
                     'diagnostics-captures/run.txt', 'test.key',
                     'vm-backups/test.vdi', 'scratch/run.log', 'local.sqlite',
                     'cache.db', 'build/test.apk', 'dist/package.zip',
                     'app.aab', 'app.msix', 'app.snap', 'disk.qcow2',
                     'signing.jks', 'signing.keystore', 'signing.p12',
                     'signing.pfx', '.env', '.env.local', 'credentials.json']:
            with self.subTest(name=name):
                self.assertTrue(hygiene.violations(name, ''))

    def test_ordinary_source_and_manifests_remain_valid(self):
        for name in ['lib/main.dart', 'linux/runner.cc',
                     '.github/workflows/test.yml', 'tool/maintain.py',
                     'test/fixtures/certificates.dart', 'pubspec.lock',
                     'tool/upstream_packages.json', '.env.example',
                     'test/fixtures/schema_v21_v040.sql',
                     'docs/screenshots/main_window_day.png']:
            with self.subTest(name=name):
                self.assertFalse(hygiene.violations(name, 'ordinary text'))

    def test_workstation_paths_rejected_throughout_tracked_text(self):
        paths = ['/home/' + 'local-owner/sdk/', '/mnt/' + 'Media/work/sdk',
                 'C:' + r'\Users\LocalOwner\sdk',
                 'C:' + r'\\Users\\LocalOwner\\sdk',
                 'D:' + '/Users/LocalOwner/sdk', '/home/' + 'local-owner',
                 '/home/' + 'user-person/sdk', 'C:' + r'\Users\fixture-owner\sdk']
        for name in ['lib/config.dart', 'linux/main.cc', 'windows/main.cpp',
                     'android/Main.kt', '.github/workflows/check.yml',
                     'tool/maintain.py', 'docs/development.md',
                     'test/paths_test.dart', 'integration_test/run.dart',
                     'config/settings.json', 'other.txt']:
            for value in paths:
                with self.subTest(name=name, value=value):
                    self.assertEqual(hygiene.violations(name, 'safe\n' + value),
                                     [f'{name}:2: workstation-specific path'])

    def test_synthetic_paths_and_urls_permitted(self):
        for value in ['/home/example/sdk/', '/home/fixture/sdk/',
                      'C:' + r'\Users\fixture\desktop.json',
                      'https://example.test/home/team/',
                      '/remote.php/dav/calendars/alex/home/']:
            self.assertFalse(hygiene.violations('test/paths_test.dart', value))
        unicode_path = 'C:' + r'\Users\Renée\Calendar\予定.ics'
        name = 'test/platform/common/desktop_activation_test.dart'
        self.assertFalse(hygiene.violations(name, unicode_path))
        self.assertTrue(hygiene.violations('docs/readme.md', unicode_path))
        self.assertTrue(hygiene.violations(name, unicode_path + ' /home/' + 'owner/sdk/'))
        for name, values in hygiene.SYNTHETIC_PATHS.items():
            for value in values:
                self.assertFalse(hygiene.violations(name, value))

    def test_public_certificate_fixture_is_not_private_signing_material(self):
        cert = '-----BEGIN CERTIFICATE-----\nsynthetic\n-----END CERTIFICATE-----'
        for suffix in ['pem', 'crt', 'cer']:
            self.assertFalse(hygiene.violations('test/fixtures/ca.' + suffix, cert))
        self.assertTrue(hygiene.violations('test/fixtures/empty.pem', ''))
        for kind in ['', 'RSA ', 'EC ', 'OPENSSH ', 'ENCRYPTED ']:
            private = '-----BEGIN ' + kind + 'PRIVATE KEY-----'
            self.assertTrue(hygiene.violations('test/fixtures/private.pem', cert + private))
            self.assertTrue(hygiene.violations('config/signing.txt', private))

    def test_binary_resources_are_not_decoded(self):
        self.assertEqual(hygiene.text_content(b'\x89PNG\r\n\x1a\n\xff'), '')
        self.assertEqual(hygiene.text_content(b'binary\0/home/' + b'owner/sdk/'), '')
        self.assertEqual(hygiene.text_content(b'plain text'), 'plain text')
        self.assertEqual(hygiene.text_content(b'\xef\xbb\xbfplain text'), 'plain text')

    def test_only_git_tracked_inventory_is_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            subprocess.run(['git', 'init', '-q', directory], check=True)
            root = Path(directory)
            (root / 'source.txt').write_text('ordinary source')
            (root / '.gitignore').write_text('ignored.txt\n')
            (root / 'ignored.txt').write_text('/home/' + 'owner/private/')
            (root / 'untracked.log').write_text('disposable')
            subprocess.run(['git', '-C', directory, 'add', '.gitignore', 'source.txt'], check=True)
            previous = Path.cwd()
            try:
                os.chdir(root)
                with patch('builtins.print'):
                    self.assertEqual(hygiene.main(), 0)
                    (root / 'source.txt').write_text('/home/' + 'owner/private/')
                    self.assertEqual(hygiene.main(), 1)
                    (root / 'source.txt').unlink()
                    self.assertEqual(hygiene.main(), 0)
            finally:
                os.chdir(previous)
