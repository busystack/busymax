"""Exercise the release runner with real pipes, process trees and signals."""
import base64
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import shlex
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('release_runner', ROOT / 'tool/release/build_snap_local.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)
SECRET = "synthetic-desktop-credential-'雪"


class RedactorTest(unittest.TestCase):
    def test_every_chunk_boundary_including_base64_unicode_and_overlaps(self):
        values = [SECRET, 'abc', 'abcdef', 'bcdefg', '', 'abc']
        encoded = base64.b64encode(SECRET.encode()).decode()
        text = f'begin {SECRET}\r{encoded}\nabcdef abc bcdefg end'
        expected = 'begin [redacted]\r[redacted]\n[redacted] [redacted] [redacted] end'
        for boundary in range(len(text) + 1):
            with self.subTest(boundary=boundary):
                redactor = release.OutputRedactor(values)
                first = redactor.feed(text[:boundary])
                self.assertEqual(first + redactor.feed(text[boundary:], final=True), expected)
        redactor = release.OutputRedactor(values)
        self.assertEqual(''.join(redactor.feed(char) for char in text) + redactor.feed('', final=True), expected)

    def test_partial_prefix_is_withheld_then_released_at_eof(self):
        redactor = release.OutputRedactor([SECRET])
        self.assertEqual(redactor.feed('safe ' + SECRET[:12]), 'safe ')
        self.assertEqual(redactor.feed('', final=True), SECRET[:12])

    def test_main_reports_interruption_without_traceback(self):
        arguments = ['build_snap_local.py', '--revision', 'a' * 40, '--version', '0.4.0',
                     '--workspace', '/unused/workspace', '--google-oauth', '/unused/desktop.json']
        for signum in (signal.SIGINT, signal.SIGTERM):
            error_output = io.StringIO()
            with self.subTest(signum=signum), patch.object(sys, 'argv', arguments), \
                    patch.object(release, 'build', side_effect=release.ReleaseInterrupted(signum)), \
                    contextlib.redirect_stderr(error_output):
                self.assertEqual(release.main(), 128 + signum)
            self.assertIn('Workspace retained', error_output.getvalue())
            self.assertNotIn('Traceback', error_output.getvalue())


class SubprocessTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='busymax-runner-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.log = self.root / 'build.log'
        self.child = self.root / 'child.py'
        self.wrapper = self.root / 'runner.py'
        self.wrapper.write_text(f'''
import importlib.util, json, signal, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location('release', {str(ROOT / 'tool/release/build_snap_local.py')!r})
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
try:
    with release.release_signals():
        result = release.run([sys.executable, '-u', 'child.py'], Path.cwd(),
                             log=Path('build.log'), redactions=[{SECRET!r}],
                             label='fixture step', progress_interval=0.1)
    Path('result.json').write_text(json.dumps(result))
except release.ReleaseError as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
except release.ReleaseInterrupted as error:
    sys.exit(128 + error.signum)
''')

    def launch(self, code):
        self.child.write_text(code)
        process = subprocess.Popen([sys.executable, '-u', str(self.wrapper)], cwd=self.root,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        self.addCleanup(self.stop, process)
        return process

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.send_signal(signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        if process.stdout:
            process.stdout.close()

    def wait_for(self, condition):
        # Deadlines here bound a broken regression test, never release commands.
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if condition():
                return
            time.sleep(0.01)
        self.fail('Fixture did not reach its expected observable state')

    def log_contains(self, value):
        return self.log.exists() and value in self.log.read_text()

    def assert_stopped(self, pid):
        def stopped():
            try:
                return Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[0] == 'Z'
            except FileNotFoundError:
                return True
        self.wait_for(stopped)

    def test_streams_and_flushes_before_exit_without_newlines(self):
        process = self.launch(f'''
import os, time
from pathlib import Path
secret = {SECRET!r}.encode()
os.write(1, b'first progress\\r' + secret[:13])
while not Path('continue').exists(): time.sleep(0.01)
for byte in secret[13:]: os.write(1, bytes([byte]))
os.write(2, b' stderr progress\\n')
''')
        self.wait_for(lambda: self.log_contains('first progress'))
        self.assertIsNone(process.poll())
        self.assertNotIn(SECRET[:13], self.log.read_text())
        # Also observe terminal output while the command is still blocked.
        terminal = b''
        while b'first progress' not in terminal:
            terminal += os.read(process.stdout.fileno(), 4096)
        self.assertIsNone(process.poll())
        (self.root / 'continue').touch()
        rest, _ = process.communicate(timeout=10)
        terminal = (terminal + rest).decode()
        self.assertEqual(process.returncode, 0, terminal)
        with self.log.open(newline='') as stream:
            self.assertEqual(terminal, stream.read())
        self.assertNotIn(SECRET, terminal)
        self.assertIn('first progress\r[redacted] stderr progress', terminal)
        self.assertEqual(json.loads((self.root / 'result.json').read_text()),
                         'first progress\r[redacted] stderr progress')

    def test_failure_redacts_command_output_and_logs_exit(self):
        self.child.write_text('import sys; print(sys.argv[1]); print(sys.argv[2], file=sys.stderr); sys.exit(17)')
        encoded = base64.b64encode(SECRET.encode()).decode()
        terminal = io.StringIO()
        self.log.write_text('retained evidence\n')
        with contextlib.redirect_stdout(terminal), self.assertRaisesRegex(release.ReleaseError, 'exit 17') as caught:
            release.run([sys.executable, self.child, SECRET, encoded], self.root,
                        log=self.log, redactions=[SECRET])
        for text in (terminal.getvalue(), self.log.read_text(), str(caught.exception)):
            self.assertNotIn(SECRET, text)
            self.assertNotIn(shlex.quote(SECRET), text)
            self.assertNotIn(encoded, text)
        self.assertEqual(self.log.read_text(), 'retained evidence\n' + terminal.getvalue())
        self.assertIn('exit=17', self.log.read_text())
        self.assertNotIn('result.json', [path.name for path in self.root.iterdir()])

    def test_invalid_utf8_and_eof_without_newline(self):
        with contextlib.redirect_stdout(io.StringIO()):
            result = release.run([sys.executable, '-c', "import os; os.write(1, b'progress\\xfftail')"], self.root)
        self.assertEqual(result, 'progress\ufffdtail')

    def test_spawn_failure_is_logged_without_success(self):
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(OSError):
            release.run([self.root / 'missing'], self.root, log=self.log)
        self.assertIn('Starting', self.log.read_text())
        self.assertNotIn('Finished', self.log.read_text())

    def test_sigint_and_sigterm_stop_owned_descendants_and_preserve_unrelated_process(self):
        unrelated = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'], start_new_session=True)
        self.addCleanup(self.stop, unrelated)
        for signum in (signal.SIGINT, signal.SIGTERM):
            with self.subTest(signum=signum):
                ready = self.root / 'ready.json'
                if ready.exists(): ready.unlink()
                if self.log.exists(): self.log.unlink()
                process = self.launch('''
import json, os, signal, subprocess, sys, time
from pathlib import Path
grandchild = subprocess.Popen([sys.executable, '-c',
    'import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print("grandchild ready", flush=True); time.sleep(60)'],
    process_group=0)
Path('ready.json').write_text(json.dumps([os.getpid(), grandchild.pid]))
while True: time.sleep(1)
''')
                self.wait_for(lambda: ready.exists() and self.log_contains('grandchild ready'))
                pids = json.loads(ready.read_text())
                self.wait_for(lambda: self.log_contains(f'pid={pids[0]} state='))
                self.assertIsNone(process.poll())
                process.send_signal(signum)
                terminal, _ = process.communicate(timeout=12)
                self.assertEqual(process.returncode, 128 + signum, terminal.decode())
                for pid in pids: self.assert_stopped(pid)
                self.assertIsNone(unrelated.poll())
                self.assertIn('Stopped fixture step', self.log.read_text())
                self.assertIn('cpu=', self.log.read_text())
                self.assertIn('rss=', self.log.read_text())
                self.assertFalse((self.root / 'result.json').exists())

    def test_exited_parent_with_inherited_pipe_remains_diagnosable_and_interruptible(self):
        process = self.launch('''
import subprocess, sys
from pathlib import Path
child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])
Path('orphan.pid').write_text(str(child.pid))
''')
        self.wait_for(lambda: self.log_contains('exit=0') and self.log_contains('state='))
        self.assertIsNone(process.poll())
        process.terminate()
        terminal, _ = process.communicate(timeout=12)
        self.assertEqual(process.returncode, 143, terminal.decode())
        self.assert_stopped(int((self.root / 'orphan.pid').read_text()))

    def test_failed_parent_cleans_descendant_holding_output_pipe(self):
        process = self.launch('''
import subprocess, sys
from pathlib import Path
child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])
Path('orphan.pid').write_text(str(child.pid))
print('failure evidence', flush=True)
sys.exit(19)
''')
        terminal, _ = process.communicate(timeout=12)
        self.assertEqual(process.returncode, 1, terminal.decode())
        self.assertIn('exit 19', terminal.decode())
        self.assertIn('failure evidence', self.log.read_text())
        self.assert_stopped(int((self.root / 'orphan.pid').read_text()))
        self.assertFalse((self.root / 'result.json').exists())

    def test_log_write_failure_stops_command(self):
        pidfile = self.root / 'pid'
        self.child.write_text("import os,time\nfrom pathlib import Path\nPath('pid').write_text(str(os.getpid()))\nprint('trigger-write-failure',flush=True)\ntime.sleep(60)\n")

        class BrokenLog(io.StringIO):
            def write(self, value):
                if 'trigger-write-failure' in value:
                    raise OSError('synthetic log failure')
                return super().write(value)

        class LogPath:
            def open(self, *args, **kwargs):
                return BrokenLog()

        with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(OSError, 'synthetic log failure'):
            release.run([sys.executable, self.child], self.root, log=LogPath())
        self.assert_stopped(int(pidfile.read_text()))


if __name__ == '__main__':
    unittest.main()
