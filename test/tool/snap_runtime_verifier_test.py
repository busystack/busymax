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


class RuntimeAssertionsTest(unittest.TestCase):
    """Execute the real shell assertions with controlled process/log inputs."""

    def check_network(self, mode):
        script = (ROOT/'tool/release/verify_snap_runtime.sh').read_text()
        session = script.split("<<'SESSION'\n", 1)[1].split('\nSESSION', 1)[0]
        preamble = session.split('cd "$HOME"', 1)[0]
        checks = session.split("check='confined network:", 1)[1]
        checks = "check='confined network:" + checks
        with tempfile.TemporaryDirectory(prefix='busymax-network-test-') as directory:
            root = Path(directory)
            checks = checks.replace('/tmp/busymax-network.log', str(root/'network.log'))
            # The TCP outcomes are fixtures; all resolution, retries, address
            # filtering and acceptance assertions run from the actual verifier.
            fixture = r"""
timeout() { shift 2; "$@"; }
snap() {
  printf '%s\n' "$*" >> "$FIXTURE_CALLS"
  case "$*" in
    *getent*)
      [ "$FIXTURE_MODE" != dns_failure ] || return 2
      printf '192.0.2.1 STREAM oauth2.googleapis.com\n192.0.2.1 DGRAM\n2001:db8::1 STREAM\n'
      ;;
    *'/dev/tcp/2001:db8::1/443'*) [ "$FIXTURE_MODE" = ipv6_success ] ;;
    *) return 124 ;;
  esac
}
"""
            result = subprocess.run(['bash', '-c', preamble + fixture + checks],
                                    env=dict(os.environ, FIXTURE_MODE=mode,
                                             FIXTURE_CALLS=str(root/'calls')),
                                    text=True, capture_output=True)
            return result, (root/'calls').read_text().splitlines()

    def test_confined_network_tries_ipv6_after_unreachable_ipv4(self):
        result, calls = self.check_network('ipv6_success')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 3)
        self.assertIn('getent ahosts oauth2.googleapis.com', calls[0])
        self.assertIn('/dev/tcp/192.0.2.1/443', calls[1])
        self.assertIn('/dev/tcp/2001:db8::1/443', calls[2])

    def test_network_resolution_or_all_connection_failures_reject_release(self):
        for mode, expected_calls in [('dns_failure', 3), ('all_fail', 9)]:
            with self.subTest(mode=mode):
                result, calls = self.check_network(mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('confined network: oauth2.googleapis.com:443', result.stderr)
                self.assertEqual(len(calls), expected_calls)

    def check_x11(self, *, status=124, visible=True, log=''):
        script = (ROOT/'tool/release/verify_snap_runtime.sh').read_text()
        session = script.split("<<'SESSION'\n", 1)[1].split('\nSESSION', 1)[0]
        preamble = session.split('cd "$HOME"', 1)[0]
        function = 'run_x11() {' + session.split('run_x11() {', 1)[1].split('\nrun_x11 1', 1)[0]
        with tempfile.TemporaryDirectory(prefix='busymax-x11-test-') as directory:
            root = Path(directory)
            (root/'log').write_text(log)
            function = function.replace('/tmp/busymax-x11-ready', str(root/'ready'))
            function = function.replace('/tmp/busymax-x11.log', str(root/'log'))
            fixture = 'timeout() {\n'
            if visible: fixture += f'touch "{root}/ready"\n'
            fixture += f'return {status}\n}}\n'
            return subprocess.run(['bash', '-c', preamble + fixture + function + '\nrun_x11 1'],
                                  text=True, capture_output=True)

    def test_x11_requires_a_visible_window_and_expected_process_lifetime(self):
        self.assertEqual(self.check_x11().returncode, 0)
        for status, visible in [(0, True), (137, True), (124, False)]:
            with self.subTest(status=status, visible=visible):
                result = self.check_x11(status=status, visible=visible)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('X11 startup and visible window', result.stderr)
                self.assertIn(f'timeout status={status}', result.stdout)

    def test_x11_rejects_application_exceptions(self):
        result = self.check_x11(log='Unhandled Exception: unavailable')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('X11 startup and visible window', result.stderr)

    def check_wayland(self, log, status=124):
        script = (ROOT/'tool/release/verify_snap_runtime.sh').read_text()
        session = script.split("<<'SESSION'\n", 1)[1].split('\nSESSION', 1)[0]
        preamble = session.split('cd "$HOME"', 1)[0]
        checks = session.split('test "$status" = 124', 2)[2]
        checks = 'test "$status" = 124' + checks.split('# Basic confined network', 1)[0]
        with tempfile.TemporaryDirectory(prefix='busymax-wayland-test-') as directory:
            path = Path(directory)/'wayland.log'
            path.write_text(log)
            checks = checks.replace('/tmp/busymax-wayland.log', str(path))
            return subprocess.run(['bash', '-c', preamble +
                                   f"check='Wayland application lifetime'\nstatus={status}\n" + checks],
                                  text=True, capture_output=True)

    def test_wayland_requires_expected_lifetime_and_both_native_operations(self):
        good = 'xdg_surface@18.get_toplevel(new id xdg_toplevel@19)\nwl_surface@16.commit()\n'
        self.assertEqual(self.check_wayland(good).returncode, 0)
        for status in (0, 1, 137):
            with self.subTest(status=status):
                result = self.check_wayland(good, status)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Wayland application lifetime', result.stderr)
                self.assertIn('test "$status" = 124', result.stderr)
        for log, label in [('wl_surface@16.commit()\n', 'native toplevel'),
                           ('xdg_surface@18.get_toplevel()\n', 'surface submission')]:
            with self.subTest(label=label):
                result = self.check_wayland(log)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(label, result.stderr)

    def test_native_activity_does_not_mask_application_failures(self):
        for error in ('Segmentation fault', 'symbol lookup error',
                      'Unhandled Exception: Bad state: Notification server unavailable.'):
            with self.subTest(error=error):
                result = self.check_wayland('get_toplevel\nwl_surface.commit\n' + error)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Wayland application errors', result.stderr)
                self.assertIn(error, result.stdout)


if __name__ == '__main__':
    unittest.main()
