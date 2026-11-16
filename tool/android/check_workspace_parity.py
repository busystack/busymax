#!/usr/bin/env python3
"""Exercise BusyMax on Android with controlled fixture data.

Only the existing isolated QA package is installed. Emulator display overrides
are restored; --phone never changes display preferences. No live provider
mutations or invitations are sent.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

p = argparse.ArgumentParser()
p.add_argument('--device', required=True)
p.add_argument('--output', required=True)
p.add_argument('--phone', action='store_true', help='Keep physical-phone display preferences unchanged.')
a = p.parse_args()
if not a.phone and not a.device.startswith('emulator-'):
    p.error('Use a designated disposable emulator for native display overrides.')
out = Path(a.output).resolve()
out.mkdir(parents=True, exist_ok=True)
root = Path(__file__).resolve().parents[2]
sdk = os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME')
adb = str(Path(sdk) / 'platform-tools/adb') if sdk else shutil.which('adb')
if not adb:
    p.error('Set ANDROID_SDK_ROOT or make the official adb available on PATH.')
flutter = os.environ.get('BUSYMAX_FLUTTER_EXECUTABLE', 'flutter')
package = 'io.busystack.busymax.caldavqa'
run_id = str(time.time_ns())
exchange = f'files/parity/native-{run_id}'

def device(*args, check=True):
    return subprocess.run([adb, '-s', a.device, *args], check=check,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)

original_scale = device('shell', 'settings', 'get', 'system', 'font_scale').stdout.decode().strip()
env = os.environ.copy()
env.update(ORG_GRADLE_PROJECT_busymaxCalDavQa='true',
           ORG_GRADLE_PROJECT_busymaxTestSigning='true')
command = [flutter, 'test', '--no-pub', '--no-uninstall',
           'integration_test/android_workspace_parity_test.dart', '-d', a.device,
           '--dart-define=BUSYMAX_PARITY_QA=true',
           '--dart-define=BUSYMAX_PARITY_NATIVE_VIEWPORTS=true',
           f'--dart-define=BUSYMAX_PARITY_RUN_ID={run_id}',
           f'--dart-define=BUSYMAX_PARITY_PHONE={str(a.phone).lower()}', '--reporter', 'expanded']
seen = set()
log = (out / 'runtime.log').open('wb')
process = subprocess.Popen(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
try:
    while process.poll() is None:
        result = device('shell', 'run-as', package, 'cat', f'{exchange}/request.json', check=False)
        try:
            req = json.loads(result.stdout)
        except (ValueError, UnicodeDecodeError):
            time.sleep(.25)
            continue
        seq = req['seq']
        if seq in seen:
            time.sleep(.1)
            continue
        if req['kind'] == 'focus':
            device('shell', 'input', 'tap', str(req['x']), str(req['y']))
            time.sleep(.7)
        elif req['kind'] == 'back':
            device('shell', 'input', 'keyevent', 'KEYCODE_BACK')
            time.sleep(.4)
        elif req['kind'] == 'viewport':
            if a.phone:
                raise ValueError('Physical-phone display changes are forbidden')
            device('shell', 'wm', 'size', f"{req['width']}x{req['height']}")
            device('shell', 'wm', 'density', '160')
            device('shell', 'settings', 'put', 'system', 'font_scale', str(req['scale']))
            time.sleep(.7)
            print(f"Native viewport {req['width']}x{req['height']}, text {req['scale']}", flush=True)
        elif req['kind'] == 'capture':
            name = req['name']
            if not re.fullmatch(r'[a-zA-Z0-9_.-]+', name):
                raise ValueError('Invalid capture name')
            (out / f'{name}.png').write_bytes(device('exec-out', 'screencap', '-p').stdout)
        else:
            raise ValueError('Unknown native request')
        device('shell', 'run-as', package, 'touch', f'{exchange}/ack-{seq}')
        seen.add(seq)
    code = process.wait()
finally:
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=30)
    log.close()
    if not a.phone:
        device('shell', 'wm', 'size', 'reset', check=False)
        device('shell', 'wm', 'density', 'reset', check=False)
    if not a.phone and original_scale in ('', 'null'):
        device('shell', 'settings', 'delete', 'system', 'font_scale', check=False)
    elif not a.phone:
        device('shell', 'settings', 'put', 'system', 'font_scale', original_scale, check=False)
if code == 0 and 'All tests passed!' not in (out / 'runtime.log').read_text(errors='replace'):
    print('Flutter exited without completing the runtime test.', flush=True)
    code = 1
print(f'Android runtime exit: {code}; screenshots: {out}', flush=True)
raise SystemExit(code)
