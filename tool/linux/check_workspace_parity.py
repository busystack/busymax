#!/usr/bin/env python3
"""Run the real Linux shell or the hosted Android matrix with source identity."""
import argparse
import json
import os
import signal
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'android'))
from parity_source_identity import parity_source_identity

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--presentation', choices=['linux', 'android'], default='linux')
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--timezone', default='Etc/GMT+7')
parser.add_argument('--timeout', type=int, default=300)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)
identity = parity_source_identity(root)
(out / 'source-identity.json').write_text(json.dumps(identity, indent=2) + '\n')
command = [os.environ.get('BUSYMAX_FLUTTER_EXECUTABLE', 'flutter'), 'test',
           'integration_test/android_workspace_parity_test.dart', '--no-pub', '-d', 'linux',
           '--dart-define=BUSYMAX_PARITY_QA=true',
           f'--dart-define=BUSYMAX_PARITY_TIME_ZONE={args.timezone}',
           f'--dart-define=BUSYMAX_PARITY_OUTPUT={out}',
           f"--dart-define=BUSYMAX_PARITY_BASE_REVISION={identity['base_revision']}",
           f"--dart-define=BUSYMAX_PARITY_SOURCE_SHA256={identity['source_sha256']}",
           '--reporter=expanded']
if args.presentation == 'android':
    command.append('--dart-define=BUSYMAX_PARITY_ANDROID_UI=true')
env = os.environ.copy()
env.update(TZ=args.timezone, GDK_BACKEND='x11')
(out / 'command.json').write_text(json.dumps({'argv': command, 'timezone': args.timezone}, indent=2) + '\n')
with (out / 'runtime.log').open('wb') as log:
    process = subprocess.Popen(command, cwd=root, env=env, stdout=log,
                               stderr=subprocess.STDOUT, start_new_session=True)
    try:
        code = process.wait(timeout=args.timeout)
    except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        code = 130 if isinstance(error, KeyboardInterrupt) else 124
if code == 0 and 'All tests passed!' not in (out / 'runtime.log').read_text(errors='replace'):
    code = 1
(out / 'exit-status.json').write_text(json.dumps({'exit_code': code}) + '\n')
print(json.dumps({'presentation': args.presentation, 'exit_code': code, 'output': str(out)}))
raise SystemExit(code)
