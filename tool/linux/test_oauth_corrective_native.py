#!/usr/bin/env python3
"""Exercise real Settings controls, a private keyring and the native GTK chooser.

The accessible chooser is operated only in this subprocess's private D-Bus
session, and only the packaged synthetic fixture is selected. No provider
account or existing keyring is accessed. Requires system Python's GI/Atspi.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def session(root):
    import gi
    gi.require_version("Atspi", "2.0")
    from gi.repository import Atspi, GLib

    flutter = os.environ["BUSYMAX_FLUTTER_EXECUTABLE"]
    command = [flutter, "test", "integration_test/oauth_corrective_native_test.dart", "-d", "linux"]
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
        if process.returncode or not selected:
            raise SystemExit(process.returncode or "The native picker was not exercised.")
        print("PASSED: real GTK chooser selected and imported the packaged synthetic fixture.")
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=30)


def main():
    root = Path(__file__).resolve().parents[2]
    if "--session" in sys.argv:
        session(root)
        return
    flutter = os.environ.get("BUSYMAX_FLUTTER_EXECUTABLE", "flutter")
    with tempfile.TemporaryDirectory(prefix="busymax-native-oauth-") as temporary:
        home = Path(temporary)
        env = os.environ.copy()
        for name in ("DATA", "CONFIG", "CACHE", "RUNTIME"):
            directory = home / name.lower()
            directory.mkdir(mode=0o700)
            env[f"XDG_{name}_HOME" if name != "RUNTIME" else "XDG_RUNTIME_DIR"] = str(directory)
        env["BUSYMAX_NATIVE_KEYRING_CONTROL"] = str(home / "keyring")
        env["BUSYMAX_NATIVE_IMPORT_FIXTURE"] = str(root / "test/fixtures/oauth/desktop_synthetic.json")
        env["GTK_USE_PORTAL"] = "0"
        env["GDK_BACKEND"] = "x11"
        env["GIO_USE_VFS"] = "local"
        env["NO_AT_BRIDGE"] = "0"
        env["BUSYMAX_FLUTTER_EXECUTABLE"] = flutter
        command = ["/usr/bin/dbus-run-session", "--", "bash", "-c", r'''
set -euo pipefail
mkdir -m 700 -p "$BUSYMAX_NATIVE_KEYRING_CONTROL"
eval "$(printf '\n' | gnome-keyring-daemon --unlock --components=secrets --control-directory="$BUSYMAX_NATIVE_KEYRING_CONTROL")"
exec /usr/bin/python3 "$1" --session
''', "busymax-native-test", str(Path(__file__).resolve())]
        try:
            result = subprocess.call(command, cwd=root, env=env)
        finally:
            # GTK accessibility may start GVFS in this private session. Unmount
            # only its temporary runtime mount before deleting our directory.
            mount = home / "runtime/gvfs"
            mounted = any(line.split()[4] == str(mount) for line in Path("/proc/self/mountinfo").read_text().splitlines())
            if mounted:
                subprocess.run(["fusermount3", "-u", "-z", str(mount)], check=True)
    raise SystemExit(result)


if __name__ == "__main__":
    main()
