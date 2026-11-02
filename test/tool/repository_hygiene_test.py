import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('hygiene', Path(__file__).resolve().parents[2] / 'tool/check_repository_hygiene.py')
hygiene = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hygiene)


class HygieneTest(unittest.TestCase):
    def test_disposable_outputs_rejected(self):
        for name in ['qa-results/failure.png', 'test-results/run.json', 'test.key', 'vm-backups/test.vdi', 'build/test.apk']:
            self.assertTrue(hygiene.violations(name, ''))

    def test_fixtures_source_and_manifests_remain_valid(self):
        for name in ['test/fixtures/certificates.dart', 'pubspec.lock', 'tool/upstream_packages.json', 'docs/screenshots/main_window_day.png']:
            self.assertFalse(hygiene.violations(name, ''))
        self.assertFalse(hygiene.violations('test/paths_test.dart', r'C:\Users\Renée\Calendar\予定.ics'))
        self.assertFalse(hygiene.violations('docs/development.md', '/home/example/sdk/'))

    def test_product_workstation_path_rejected(self):
        self.assertTrue(hygiene.violations('lib/config.dart', '/home/local-owner/sdk/'))
