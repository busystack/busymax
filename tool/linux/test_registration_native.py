#!/usr/bin/python3
"""Exercise native registration storage, the GTK chooser and its handle reader.

The accessible chooser is operated only in this subprocess's private D-Bus
session, and only the packaged synthetic fixture is selected. No provider
account or existing keyring is accessed. Requires system Python's GI/Atspi.
"""
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time


def ensure_system_python():
    system_python = Path("/usr/bin/python3")
    if Path(sys.executable).resolve() != system_python.resolve():
        # Accessibility and pidfd cleanup both require the system interpreter.
        # Switch before allocating resources, preserving arguments and environment.
        os.execv(str(system_python), [
            str(system_python), str(Path(__file__).resolve()), *sys.argv[1:],
        ])
    if not callable(getattr(os, "pidfd_open", None)) or not callable(
        getattr(signal, "pidfd_send_signal", None)
    ):
        raise RuntimeError("System Python must support os.pidfd_open and signal.pidfd_send_signal.")


def exercise_registration(root):
    import gi
    gi.require_version("Atspi", "2.0")
    from gi.repository import Atspi, GLib

    flutter = os.environ["BUSYMAX_FLUTTER_EXECUTABLE"]
    command = [flutter, "test", "integration_test/native_registration_storage_test.dart", "-d", "linux"]
    if os.environ.get("BUSYMAX_NATIVE_CHOOSER_ONLY") == "1":
        command += ["--name", "native file selection"]
    process = subprocess.Popen(command, cwd=root)
    fixture = Path(os.environ["BUSYMAX_NATIVE_IMPORT_FIXTURE"]).name

    def owned(pid):
        while pid > 1:
            if pid == process.pid:
                return True
            try:
                status = Path(f"/proc/{pid}/status").read_text()
                pid = int(next(line.split()[1] for line in status.splitlines() if line.startswith("PPid:")))
            except (OSError, StopIteration):
                break
        return False

    def descendants(node):
        yield node
        for index in range(node.get_child_count()):
            child = node.get_child_at_index(index)
            if child is not None:
                yield from descendants(child)

    selected = False
    deadline = time.monotonic() + 600
    try:
        while process.poll() is None:
            if time.monotonic() > deadline:
                raise SystemExit("Native integration process exceeded its deadline.")
            while GLib.MainContext.default().pending():
                GLib.MainContext.default().iteration(False)
            if not selected:
                desktop = Atspi.get_desktop(0)
                for index in range(desktop.get_child_count()):
                    app = desktop.get_child_at_index(index)
                    if app is None or not owned(app.get_process_id()):
                        continue
                    for dialog in descendants(app):
                        if dialog.get_name() not in ("Open File", "Open file", "Open"):
                            continue
                        for item in descendants(dialog):
                            if item.get_name() != fixture:
                                continue
                            action = item.get_action_iface()
                            if action is None:
                                continue
                            for action_index in range(action.get_n_actions()):
                                if action.get_action_name(action_index) == "activate":
                                    if not action.do_action(action_index):
                                        raise SystemExit("The owned GTK fixture activation was rejected.")
                                    selected = True
                                    print("Activated the packaged fixture through the owned GTK chooser's accessible action.", flush=True)
                                    break
                            if selected:
                                break
                        if selected:
                            break
                    if selected:
                        break
            time.sleep(0.05)  # Poll native accessibility readiness, not a race assertion.
        if process.returncode:
            return process.returncode
        if not selected:
            raise RuntimeError("The native picker was not exercised.")
        print("PASSED: real GTK chooser selected and imported the packaged synthetic fixture.")
        return 0
    finally:
        if process.poll() is None:
            stop_child(process)


def stop_child(process):
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=3)


def session(root):
    # Keep the keyring in the foreground so it is reaped with this private
    # session instead of becoming an orphaned desktop daemon.
    keyring = subprocess.Popen([
        "gnome-keyring-daemon", "--foreground", "--unlock",
        "--components=secrets",
        f"--control-directory={os.environ['BUSYMAX_NATIVE_KEYRING_CONTROL']}",
    ], stdin=subprocess.PIPE)
    result = 1
    try:
        keyring.stdin.write(b"\n")
        keyring.stdin.close()
        result = exercise_registration(root)
    except (Exception, SystemExit) as error:
        print(f"Native integration failed: {error}", file=sys.stderr, flush=True)
    finally:
        try:
            stop_child(keyring)
        except Exception as error:
            print(f"Private keyring teardown failed: {error}", file=sys.stderr, flush=True)
            result = result or 1
    return result


def private_mounts(runtime):
    mounts = []
    for line in Path("/proc/self/mountinfo").read_text().splitlines():
        # mountinfo escapes spaces, tabs, newlines and backslashes as octal.
        mount = Path(re.sub(r"\\([0-7]{3})", lambda match: chr(int(match[1], 8)), line.split()[4]))
        if mount == runtime or runtime in mount.parents:
            mounts.append(mount)
    return sorted(mounts, key=lambda mount: len(mount.parts), reverse=True)


def private_processes(runtime):
    marker = b"XDG_RUNTIME_DIR=" + os.fsencode(runtime)
    processes = {}
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit() or int(proc.name) == os.getpid():
            continue
        try:
            if proc.stat().st_uid != os.getuid():
                continue
            if marker not in (proc / "environ").read_bytes().split(b"\0"):
                continue
            fields = (proc / "stat").read_text().rsplit(")", 1)[1].split()
            if fields[0] != "Z":
                processes[int(proc.name)] = fields[19]  # Process start time.
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            continue
    return processes


def wait_until(predicate, timeout):
    deadline = time.monotonic() + timeout
    while not predicate():
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return False
        time.sleep(min(0.05, remaining))
    return True


def signal_private_processes(runtime, sig):
    for pid, started in private_processes(runtime).items():
        try:
            # A pidfd prevents a reused PID from receiving our signal. Recheck
            # ownership after opening it; only this random runtime is eligible.
            descriptor = os.pidfd_open(pid)
            try:
                if private_processes(runtime).get(pid) == started:
                    signal.pidfd_send_signal(descriptor, sig)
            finally:
                os.close(descriptor)
        except ProcessLookupError:
            continue


def detach_mount(mount, runtime):
    diagnostics = []
    for options in (["-u"], ["-u", "-z"]):
        if mount not in private_mounts(runtime):
            return
        try:
            result = subprocess.run(
                ["fusermount3", *options, str(mount)],
                capture_output=True, text=True, timeout=3,
            )
            if result.returncode:
                diagnostics.append(result.stderr.strip() or f"exit {result.returncode}")
        except (OSError, subprocess.TimeoutExpired) as error:
            diagnostics.append(str(error))
        # An unmount can race natural GVFS exit or return before mountinfo is
        # updated. Its exit code alone is neither success nor failure.
        if wait_until(lambda: mount not in private_mounts(runtime), 2):
            return
    raise RuntimeError(f"Private mount could not be detached: {mount}; {'; '.join(diagnostics)}")


def teardown_private_runtime(home):
    runtime = home / "runtime"
    # dbus-run-session has exited. Give its services a bounded natural exit
    # period before unmounting or stopping this runtime's stragglers.
    wait_until(lambda: not private_mounts(runtime) and not private_processes(runtime), 3)
    failed_mounts = {}
    # Accessibility can also activate the private document portal (runtime/doc).
    # Try normal user unmounts before a bounded lazy fallback, deepest first.
    attempted_mounts = private_mounts(runtime)
    for mount in attempted_mounts:
        try:
            detach_mount(mount, runtime)
        except Exception as error:
            failed_mounts[mount] = str(error)

    if private_processes(runtime):
        signal_private_processes(runtime, signal.SIGTERM)
        if not wait_until(lambda: not private_processes(runtime), 2):
            signal_private_processes(runtime, signal.SIGKILL)
            wait_until(lambda: not private_processes(runtime), 2)
    # Catch a mount created during service shutdown, confined to this runtime.
    for mount in private_mounts(runtime):
        if mount in attempted_mounts:
            continue
        try:
            detach_mount(mount, runtime)
        except Exception as error:
            failed_mounts[mount] = str(error)
    remaining_mounts = private_mounts(runtime)
    remaining_processes = private_processes(runtime)
    # A daemon's exit may finish detaching an initially stuck mount. Success
    # still requires the final mountinfo check, regardless of command results.
    errors = [failed_mounts[mount] for mount in remaining_mounts if mount in failed_mounts]
    if remaining_mounts:
        errors.append(f"Remaining private mounts: {remaining_mounts}")
    if remaining_processes:
        errors.append(f"Remaining private processes: {list(remaining_processes)}")
    if errors:
        raise RuntimeError("; ".join(errors))
    shutil.rmtree(home)
    print(f"PASSED: private runtime detached and temporary tree removed: {home}", flush=True)


def run_private_session(command, root, env, home):
    result = 1
    try:
        result = subprocess.call(command, cwd=root, env=env)
    except Exception as error:
        print(f"Native integration session failed: {error}", file=sys.stderr, flush=True)
    finally:
        print(f"Native integration session exit code: {result}", flush=True)
        try:
            teardown_private_runtime(home)
        except Exception as error:
            print(f"TEARDOWN FAILED: {error}", file=sys.stderr, flush=True)
            # Preserve a failing integration result; a passing test still fails
            # the helper if its private resources could not be removed.
            result = result or 1
    return result


def main():
    root = Path(__file__).resolve().parents[2]
    if "--session" in sys.argv:
        return session(root)
    flutter = os.environ.get("BUSYMAX_FLUTTER_EXECUTABLE", "flutter")
    home = Path(tempfile.mkdtemp(prefix="busymax-native-registration-"))
    try:
        env = os.environ.copy()
        for name in ("DATA", "CONFIG", "CACHE", "RUNTIME"):
            directory = home / name.lower()
            directory.mkdir(mode=0o700)
            env[f"XDG_{name}_HOME" if name != "RUNTIME" else "XDG_RUNTIME_DIR"] = str(directory)
        env["BUSYMAX_NATIVE_KEYRING_CONTROL"] = str(home / "keyring")
        env["GNOME_KEYRING_CONTROL"] = env["BUSYMAX_NATIVE_KEYRING_CONTROL"]
        env["BUSYMAX_NATIVE_IMPORT_FIXTURE"] = str(root / "test/fixtures/oauth/desktop_synthetic.json")
        env["GTK_USE_PORTAL"] = "0"
        env["GDK_BACKEND"] = "x11"
        env["GIO_USE_VFS"] = "local"
        env["NO_AT_BRIDGE"] = "0"
        env["BUSYMAX_FLUTTER_EXECUTABLE"] = flutter
        (home / "keyring").mkdir(mode=0o700)
        command = ["/usr/bin/dbus-run-session", "--", "/usr/bin/python3", str(Path(__file__).resolve()), "--session"]
    except BaseException:
        teardown_private_runtime(home)
        raise
    return run_private_session(command, root, env, home)


if __name__ == "__main__":
    ensure_system_python()
    raise SystemExit(main())
