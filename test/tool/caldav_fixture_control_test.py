import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock


SPEC = importlib.util.spec_from_file_location(
    'caldav_fixture_control',
    Path(__file__).resolve().parents[1] / 'interop/caldav/control.py',
)
CONTROL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONTROL)


class CalDavFixtureCredentialRotationTest(unittest.TestCase):
    def test_rotation_revokes_the_held_identity_even_when_issuance_updates_registry(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            credentials = runtime / 'busystack-credentials.json'
            state = runtime / 'busystack-credential-label.json'
            credentials.write_text(json.dumps({'alice': 'old-id.synthetic'}))
            state.write_text(json.dumps({'label': 'task-owned-old', 'credentialId': 'old-id'}))
            calls = []

            def browser(command, **kwargs):
                calls.append(command[-3:])
                if command[-3] == 'issue':
                    credentials.write_text(json.dumps({'alice': 'new-id.synthetic'}))
                    state.write_text(json.dumps({'label': command[-1], 'credentialId': 'new-id'}))
                return mock.Mock(returncode=0)

            with mock.patch.object(CONTROL, 'RUNTIME', runtime), \
                    mock.patch.object(CONTROL.subprocess, 'run', side_effect=browser), \
                    mock.patch('sys.argv', ['control.py', 'rotate', 'busystack']):
                CONTROL.main()
            self.assertEqual(calls[1], ['revoke', 'alice', 'task-owned-old'])
            self.assertEqual(json.loads(state.read_text())['credentialId'], 'new-id')
            self.assertEqual(json.loads((runtime / 'rotation-busystack.json').read_text()),
                             {'password': 'new-id.synthetic'})

    def test_stale_label_cannot_revoke_another_credential(self):
        self._reject_stale({'label': 'unrelated-label', 'credentialId': 'different-id'})

    def test_missing_label_requires_explicit_fixture_issuance(self):
        self._reject_stale(None)

    def _reject_stale(self, state):
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            credentials = runtime / 'busystack-credentials.json'
            original = json.dumps({'alice': 'held-id.synthetic'})
            credentials.write_text(original)
            if state is not None:
                (runtime / 'busystack-credential-label.json').write_text(json.dumps(state))
            with mock.patch.object(CONTROL, 'RUNTIME', runtime), \
                    mock.patch.object(CONTROL.subprocess, 'run') as browser, \
                    mock.patch('sys.argv', ['control.py', 'rotate', 'busystack']):
                with self.assertRaises(SystemExit):
                    CONTROL.main()
            browser.assert_not_called()
            self.assertEqual(credentials.read_text(), original)
            self.assertFalse((runtime / 'rotation-busystack.json').exists())


class LifecycleExpiryIsolationTest(unittest.TestCase):
    def test_expiry_only_ages_the_credential_of_the_recorded_disposable_user(self):
        self._run_case('busymax-life-123456789abc', 'busymax-life-123456789abc', True)

    def test_another_qa_or_production_identity_cannot_be_aged(self):
        self._run_case('busymax-life-123456789abc', 'administrator', False)

    def test_a_tampered_receipt_cannot_interpolate_an_identity_into_sql(self):
        self._run_case("administrator' OR true --", "administrator' OR true --", False)

    def _run_case(self, recorded, requested, allowed):
        spec = importlib.util.spec_from_file_location(
            'busystack_fixture', Path(__file__).resolve().parents[1] / 'interop/caldav/busystack-fixture.py')
        fixture = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fixture)
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            credential_id = 'ebbc4fc1-f1c2-4ab8-a7db-22b08b5725e4'
            (runtime / 'busystack-lifecycle-account.json').write_text(json.dumps({'username': recorded}))
            (runtime / 'busystack-credentials.json').write_text(json.dumps({recorded: credential_id + '.synthetic'}))
            with mock.patch.object(fixture, 'RUNTIME', runtime), \
                    mock.patch.object(fixture.subprocess, 'run', return_value=mock.Mock(stdout=credential_id)) as execute, \
                    mock.patch('sys.argv', ['busystack-fixture.py', 'expire', requested]):
                if allowed:
                    fixture.main()
                    sql = execute.call_args.kwargs['input']
                    self.assertIn("id='" + credential_id + "'", sql)
                    self.assertIn("username='" + recorded + "'", sql)
                    self.assertEqual(sql.count('UPDATE dav_credentials'), 1)
                else:
                    with self.assertRaises(SystemExit):
                        fixture.main()
                    execute.assert_not_called()


if __name__ == '__main__':
    unittest.main()
