"""Runtime verifier failure/ownership contracts without launching a VM."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class RuntimeVerifierTest(unittest.TestCase):
    def invoke(self, mode):
        with tempfile.TemporaryDirectory(prefix='busymax-runtime-test-') as directory:
            root = Path(directory)
            snap = root / 'fixture.snap'
            snap.write_bytes(b'synthetic-package')
            evidence = root / 'evidence.json'
            calls = root / 'calls.jsonl'
            executable = root / 'lxc'
            executable.write_text(r"""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
arguments = sys.argv[1:]
with Path(os.environ['FIXTURE_CALLS']).open('a') as stream:
    stream.write(json.dumps(arguments) + '\n')
mode = os.environ['FIXTURE_MODE']
if arguments[0] == 'info':
    sys.exit(0 if mode == 'existing' else 1)
if arguments[0] == 'config':
    print('changed-owner' if mode == 'ownership' else os.environ['FIXTURE_DIGEST'])
if arguments[0] == 'exec' and 'bash' in arguments:
    sys.stdin.read()
    if mode in ('failure', 'ownership'):
        print('synthetic runtime failure', file=sys.stderr)
        sys.exit(1)
""")
            executable.chmod(0o755)
            environment = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'],
                               FIXTURE_CALLS=str(calls), FIXTURE_MODE=mode,
                               FIXTURE_DIGEST=hashlib.sha256(snap.read_bytes()).hexdigest())
            result = subprocess.run(['bash', str(ROOT/'tool/release/verify_snap_runtime.sh'),
                                     str(snap), str(evidence)], env=environment,
                                    text=True, capture_output=True)
            commands = [json.loads(line) for line in calls.read_text().splitlines()]
            data = json.loads(evidence.read_text()) if evidence.exists() else None
            return result, commands, data, environment['FIXTURE_DIGEST']

    def test_success_records_exact_package_and_cleans_own_vm(self):
        result, calls, evidence, digest = self.invoke('success')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(evidence['snap_sha256'], digest)
        self.assertTrue(evidence['startup_x11'])
        self.assertTrue(evidence['startup_wayland'])
        self.assertEqual([call[0] for call in calls][-2:], ['stop', 'delete'])

    def test_failed_runtime_never_writes_acceptance_evidence(self):
        result, calls, evidence, _ = self.invoke('failure')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('synthetic runtime failure', result.stderr)
        self.assertIsNone(evidence)
        self.assertEqual([call[0] for call in calls][-2:], ['stop', 'delete'])

    def test_existing_vm_is_preserved(self):
        result, calls, evidence, _ = self.invoke('existing')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([call[0] for call in calls], ['info'])
        self.assertIsNone(evidence)

    def test_changed_ownership_prevents_cleanup(self):
        result, calls, evidence, _ = self.invoke('ownership')
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(evidence)
        self.assertNotIn('delete', [call[0] for call in calls])
        self.assertNotIn('stop', [call[0] for call in calls])


if __name__ == '__main__':
    unittest.main()
