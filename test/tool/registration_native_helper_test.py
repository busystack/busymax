"""Resource-lifecycle regressions for the private native registration helper."""
import contextlib
import importlib.util
import io
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "registration_native", Path(__file__).resolve().parents[2]
    / "tool/linux/test_registration_native.py",
)
helper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(helper)


class InterpreterTest(unittest.TestCase):
    def test_alternate_python_reexecutes_before_allocating_resources(self):
        arguments = [helper.__file__, "--session", "extra-argument"]
        with patch.object(helper.sys, "executable", "/alternate/python3"), \
                patch.object(helper.sys, "argv", arguments), \
                patch.object(helper.os, "pidfd_open", None, create=True), \
                patch.object(helper.signal, "pidfd_send_signal", None, create=True), \
                patch.object(helper.os, "execv", side_effect=SystemExit(0)) as execute, \
                patch.object(helper.tempfile, "mkdtemp") as allocate:
            with self.assertRaises(SystemExit):
                runpy.run_path(helper.__file__, run_name="__main__")
        execute.assert_called_once_with("/usr/bin/python3", ["/usr/bin/python3", *arguments])
        allocate.assert_not_called()

    def test_missing_system_pidfd_support_fails_before_allocating_resources(self):
        with patch.object(helper.sys, "executable", "/usr/bin/python3"), \
                patch.object(helper.os, "pidfd_open", None, create=True), \
                patch.object(helper.os, "execv") as execute, \
                patch.object(helper.tempfile, "mkdtemp") as allocate:
            with self.assertRaisesRegex(RuntimeError, "System Python must support"):
                runpy.run_path(helper.__file__, run_name="__main__")
        execute.assert_not_called()
        allocate.assert_not_called()


class TeardownTest(unittest.TestCase):
    def setUp(self):
        self.home = Path("/tmp/private-registration-fixture")
        self.runtime = self.home / "runtime"
        self.mount = self.runtime / "gvfs"
        self.elapsed = 0
        self.mounted = True
        self.disappears_at = None
        self.calls = []
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(helper.time, "monotonic", lambda: self.elapsed))
        self.stack.enter_context(patch.object(helper.time, "sleep", self.sleep))
        self.stack.enter_context(patch.object(helper, "private_mounts", self.mounts))
        self.stack.enter_context(patch.object(helper, "private_processes", return_value={}))
        self.stack.enter_context(patch.object(helper.subprocess, "run", self.unmount))
        self.remove = self.stack.enter_context(patch.object(helper.shutil, "rmtree"))
        self.stack.enter_context(contextlib.redirect_stdout(io.StringIO()))

    def sleep(self, seconds):
        self.elapsed += seconds

    def mounts(self, runtime):
        self.assertEqual(runtime, self.runtime)
        if self.disappears_at is not None and self.elapsed >= self.disappears_at:
            self.mounted = False
        return [self.mount] if self.mounted else []

    def unmount(self, command, **kwargs):
        self.calls.append((command, self.elapsed))
        self.assertEqual(kwargs["timeout"], 3)
        self.disappears_at = self.elapsed + 0.2
        return subprocess.CompletedProcess(command, 0, "", "")

    def test_natural_exit_gets_grace_before_tree_removal(self):
        self.disappears_at = 0.2
        helper.teardown_private_runtime(self.home)
        self.assertGreaterEqual(self.elapsed, 0.2)
        self.assertFalse(self.calls)
        self.remove.assert_called_once_with(self.home)

    def test_normal_unmount_waits_for_mountinfo_before_removal(self):
        helper.teardown_private_runtime(self.home)
        self.assertEqual(self.calls[0][0], ["fusermount3", "-u", str(self.mount)])
        self.assertGreaterEqual(self.calls[0][1], 3)
        self.assertGreaterEqual(self.elapsed, self.disappears_at)
        self.assertEqual(len(self.calls), 1)
        self.remove.assert_called_once_with(self.home)

    def test_unmount_precedes_stopping_private_process_stragglers(self):
        processes = {123: "private-started"}

        def stop(runtime, sig):
            self.assertEqual(runtime, self.runtime)
            self.assertEqual(sig, helper.signal.SIGTERM)
            self.assertFalse(self.mounts(runtime))
            self.assertEqual(len(self.calls), 1)
            processes.clear()

        with patch.object(helper, "private_processes", lambda _: processes), \
                patch.object(helper, "signal_private_processes", stop):
            helper.teardown_private_runtime(self.home)
        self.remove.assert_called_once_with(self.home)

    def test_mount_created_during_private_service_shutdown_is_detached(self):
        self.mounted = False
        processes = {123: "private-started"}

        def stop(runtime, sig):
            self.mounted = True
            processes.clear()

        with patch.object(helper, "private_processes", lambda _: processes), \
                patch.object(helper, "signal_private_processes", stop):
            helper.teardown_private_runtime(self.home)
        self.assertEqual(self.calls[0][0], ["fusermount3", "-u", str(self.mount)])
        self.assertGreaterEqual(self.elapsed, self.disappears_at)
        self.remove.assert_called_once_with(self.home)

    def test_normal_timeout_uses_lazy_fallback_and_waits(self):
        normal = self.unmount

        def timeout_then_detach(command, **kwargs):
            if "-z" not in command:
                self.calls.append((command, self.elapsed))
                raise subprocess.TimeoutExpired(command, kwargs["timeout"])
            return normal(command, **kwargs)

        self.stack.enter_context(patch.object(helper.subprocess, "run", timeout_then_detach))
        helper.teardown_private_runtime(self.home)
        self.assertEqual([call[0][1:-1] for call in self.calls], [["-u"], ["-u", "-z"]])
        self.assertGreaterEqual(self.calls[1][1] - self.calls[0][1], 2)
        self.assertGreaterEqual(self.elapsed, self.disappears_at)
        self.remove.assert_called_once_with(self.home)

    def test_failed_unmount_racing_natural_exit_is_confirmed(self):
        def raced(command, **kwargs):
            self.calls.append((command, self.elapsed))
            self.disappears_at = self.elapsed + 0.1
            return subprocess.CompletedProcess(command, 1, "", "Invalid argument")

        self.stack.enter_context(patch.object(helper.subprocess, "run", raced))
        helper.teardown_private_runtime(self.home)
        self.assertEqual(len(self.calls), 1)
        self.remove.assert_called_once_with(self.home)

    def test_remaining_mount_is_explicit_failure_and_is_never_traversed(self):
        def refused(command, **kwargs):
            self.calls.append((command, self.elapsed))
            return subprocess.CompletedProcess(command, 1, "", "Device or resource busy")

        self.stack.enter_context(patch.object(helper.subprocess, "run", refused))
        with self.assertRaisesRegex(RuntimeError, "Private mount could not be detached.*Device or resource busy"):
            helper.teardown_private_runtime(self.home)
        self.assertEqual(len(self.calls), 2)
        self.remove.assert_not_called()

    def test_failed_test_exit_is_preserved_when_teardown_also_fails(self):
        errors = io.StringIO()
        with patch.object(helper.subprocess, "call", return_value=7), \
                patch.object(helper, "teardown_private_runtime", side_effect=RuntimeError("stuck private mount")), \
                contextlib.redirect_stderr(errors):
            result = helper.run_private_session(["private-session"], Path("."), {}, self.home)
        self.assertEqual(result, 7)
        self.assertIn("TEARDOWN FAILED: stuck private mount", errors.getvalue())

    def test_passing_test_exit_becomes_failure_when_teardown_fails(self):
        with patch.object(helper.subprocess, "call", return_value=0), \
                patch.object(helper, "teardown_private_runtime", side_effect=RuntimeError("stuck private mount")), \
                contextlib.redirect_stderr(io.StringIO()):
            result = helper.run_private_session(["private-session"], Path("."), {}, self.home)
        self.assertEqual(result, 1)


class OwnershipTest(unittest.TestCase):
    def test_session_overrides_inherited_desktop_keyring_control(self):
        with tempfile.TemporaryDirectory(prefix="busymax-keyring-ownership-") as temporary:
            home = Path(temporary) / "native-session"
            home.mkdir(mode=0o700)

            def run(command, root, env, actual_home):
                self.assertEqual(actual_home, home)
                self.assertEqual(env["GNOME_KEYRING_CONTROL"], str(home / "keyring"))
                self.assertEqual(env["BUSYMAX_NATIVE_KEYRING_CONTROL"], env["GNOME_KEYRING_CONTROL"])
                self.assertEqual(env["XDG_RUNTIME_DIR"], str(home / "runtime"))
                return 0

            with patch.dict(helper.os.environ, {"GNOME_KEYRING_CONTROL": "/tmp/unrelated-desktop-keyring"}), \
                    patch.object(helper.sys, "argv", ["registration_native"]), \
                    patch.object(helper.tempfile, "mkdtemp", return_value=str(home)), \
                    patch.object(helper, "run_private_session", run):
                self.assertEqual(helper.main(), 0)

    def test_process_signals_are_confined_to_the_exact_private_runtime(self):
        with tempfile.TemporaryDirectory(prefix="busymax-runtime-ownership-") as temporary:
            runtime = Path(temporary) / "runtime"
            owned = subprocess.Popen([
                "/usr/bin/python3", "-c", "import time; time.sleep(30)",
            ], env={"XDG_RUNTIME_DIR": str(runtime)})
            other = subprocess.Popen([
                "/usr/bin/python3", "-c", "import time; time.sleep(30)",
            ], env={"XDG_RUNTIME_DIR": str(runtime) + "-other"})
            try:
                self.assertTrue(helper.wait_until(lambda: owned.pid in helper.private_processes(runtime), 2))
                self.assertNotIn(other.pid, helper.private_processes(runtime))
                result = subprocess.run([
                    "/usr/bin/python3", "-c",
                    "import runpy, sys; from pathlib import Path; "
                    "helper = runpy.run_path(sys.argv[1]); "
                    "helper['signal_private_processes'](Path(sys.argv[2]), int(sys.argv[3]))",
                    helper.__file__, str(runtime), str(helper.signal.SIGTERM),
                ], capture_output=True, text=True, timeout=3)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(owned.wait(timeout=3), -helper.signal.SIGTERM)
                self.assertIsNone(other.poll())
                self.assertFalse(helper.private_processes(runtime))
            finally:
                helper.stop_child(owned)
                helper.stop_child(other)

    def test_mountinfo_decodes_escapes_and_keeps_only_private_mounts(self):
        runtime = Path("/tmp/private registration/runtime")
        mountinfo = "\n".join([
            r"1 0 0:1 / /tmp/private\040registration/runtime/gvfs rw - fuse.gvfsd-fuse gvfsd-fuse rw",
            r"2 0 0:2 / /tmp/private\040registration/runtime/doc rw - fuse.portal portal rw",
            r"3 0 0:3 / /tmp/private\040registration/runtime/doc/child rw - fuse.portal portal rw",
            r"4 0 0:4 / /tmp/private\040registration/runtime-other/gvfs rw - fuse.gvfsd-fuse gvfsd-fuse rw",
            r"5 0 0:5 / /run/user/1000/gvfs rw - fuse.gvfsd-fuse gvfsd-fuse rw",
        ])
        with patch.object(Path, "read_text", return_value=mountinfo):
            self.assertEqual(helper.private_mounts(runtime), [
                runtime / "doc/child", runtime / "gvfs", runtime / "doc",
            ])

    def test_pid_reuse_does_not_signal_an_unrelated_process(self):
        runtime = Path("/tmp/private-registration-fixture/runtime")
        with patch.object(helper, "private_processes", side_effect=[{123: "old"}, {123: "new"}]), \
                patch.object(helper.os, "pidfd_open", return_value=42, create=True), \
                patch.object(helper.os, "close") as close, \
                patch.object(helper.signal, "pidfd_send_signal", create=True) as send:
            helper.signal_private_processes(runtime, helper.signal.SIGTERM)
        send.assert_not_called()
        close.assert_called_once_with(42)


if __name__ == "__main__":
    unittest.main()
