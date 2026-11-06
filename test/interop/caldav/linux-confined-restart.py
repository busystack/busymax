#!/usr/bin/env python3
"""Run the existing native recovery harness under an installed BusyMax Snap profile.

Does not install, replace or launch the normal app, or open its account database.
Requires the documented debug QA bundle and an authorized desktop session.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[3]
RUNTIME = ROOT / 'test/interop/caldav/.runtime'
SNAP = Path('/snap/busymax/current')


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def main():
    os.umask(0o077)
    metadata = (SNAP / 'meta/snap.yaml').read_text()
    require(re.search(r'^name: busymax$', metadata, re.M) and
            re.search(r'^base: core24$', metadata, re.M) and
            re.search(r'^confinement: strict$', metadata, re.M) and
            'SECRET_BACKEND: file' in metadata,
            'Requires the installed BusyMax core24 strict/file-backend profile.')
    owner = subprocess.check_output([
        'gdbus', 'call', '--session', '--dest', 'org.freedesktop.DBus',
        '--object-path', '/org/freedesktop/DBus', '--method',
        'org.freedesktop.DBus.NameHasOwner', 'io.busystack.busymax'], text=True)
    require(owner.strip() == '(false,)', 'Close the normal BusyMax application first.')
    bundle = ROOT / 'build/linux/x64/debug/bundle'
    require((bundle / 'data/flutter_assets/kernel_blob.bin').is_file(),
            'Build the documented Linux process-restart debug QA target first.')
    require(b'Linux keyring, queued edits and collection operation IDs survive process restart'
            in (bundle / 'data/flutter_assets/kernel_blob.bin').read_bytes(),
            'The debug bundle does not contain the expected recovery harness.')
    leaf = 'caldav-qa-' + uuid.uuid4().hex
    directory = Path.home() / 'snap/busymax/common' / leaf
    directory.mkdir(mode=0o700, parents=False)
    (directory / '.busymax-caldav-qa').write_text(leaf)
    fixture = directory / 'fixtures'
    fixture.mkdir(mode=0o700)
    for name in ('ca.pem', 'credentials.json', 'busystack-credentials.json'):
        shutil.copyfile(RUNTIME / name, fixture / name)
        (fixture / name).chmod(0o600)
    shutil.copytree(bundle, directory / 'bundle', symlinks=True)
    # Select the matching, unmodified debug engine after the installed GNOME
    # launch wrappers have configured their release-library search paths.
    (directory / 'launch.sh').write_text(
        '#!/bin/sh\nexport LD_LIBRARY_PATH="$SNAP_USER_COMMON/$BUSYMAX_CALDAV_QA_LEAF/bundle/lib:$LD_LIBRARY_PATH"\n'
        'exec "$SNAP_USER_COMMON/$BUSYMAX_CALDAV_QA_LEAF/bundle/busymax"\n')
    (directory / 'launch.sh').chmod(0o700)
    record = {
        'sourceCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'installedSnapVersion': re.search(r'^version: (.+)$', metadata, re.M).group(1),
        'kernelSha256': hashlib.sha256((bundle / 'data/flutter_assets/kernel_blob.bin').read_bytes()).hexdigest(),
        'qaDirectory': str(directory), 'phases': [],
    }
    report = RUNTIME / 'linux-confined-results.json'
    report.write_text(json.dumps(record, indent=2))
    receipt = fixture / 'linux-process-restart-v2.json'
    environment = dict(os.environ, BUSYMAX_CALDAV_NATIVE='1',
                       BUSYMAX_CALDAV_FIXTURE_DIR=str(fixture),
                       BUSYMAX_CALDAV_QA_LEAF=leaf, GDK_BACKEND='x11')
    command = ['snap', 'run', '--shell', 'busymax', '-c',
               'cd "$SNAP_USER_COMMON/$BUSYMAX_CALDAV_QA_LEAF" && exec '
               '"$SNAP/snap/command-chain/gpu-2404-wrapper" '
               '"$SNAP/snap/command-chain/desktop-launch" '
               '"$SNAP_USER_COMMON/$BUSYMAX_CALDAV_QA_LEAF/launch.sh"']
    for phase in (1, 2):
        logfile = RUNTIME / f'linux-confined-process{phase}.log'
        success = False
        with logfile.open('w') as stream:
            process = subprocess.Popen(command, env=environment, cwd='/tmp',
                                       stdout=stream, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                deadline = time.monotonic() + 120
                while time.monotonic() < deadline:
                    output = logfile.read_text(errors='replace')
                    finished = 'All tests passed!' in output
                    prepared = 'BUSYMAX_CALDAV_LINUX_PROCESS_PREPARED' in output and receipt.exists()
                    recovered = output.count('BUSYMAX_CALDAV_LINUX_PROCESS_PASS ') == 3 and not receipt.exists()
                    if finished and ((phase == 1 and prepared) or (phase == 2 and recovered)):
                        success = True
                        break
                    if process.poll() is not None or 'EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK' in output:
                        break
                    time.sleep(0.5)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=5)
        record['phases'].append({'phase': phase, 'launcherPid': process.pid, 'passed': success})
        report.write_text(json.dumps(record, indent=2))
        print(f'Confined QA phase {phase}: ' + ('PASS' if success else 'FAILED; inspect ignored runtime log'), flush=True)
        require(success, 'QA directory retained for diagnosis/recovery; its path is in the ignored results file.')
        for line in logfile.read_text(errors='replace').splitlines():
            if line.startswith('BUSYMAX_CALDAV_'):
                print(line, flush=True)
    require((directory / '.busymax-caldav-qa').read_text() == leaf, 'QA cleanup ownership changed.')
    shutil.rmtree(directory)
    record['qaDirectoryRemoved'] = True
    report.write_text(json.dumps(record, indent=2))
    print('Both Snap-confined processes passed; installed package unchanged; QA directory removed.', flush=True)


if __name__ == '__main__':
    main()
