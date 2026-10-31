#!/usr/bin/env python3
"""Exercise an isolated APK across a retained-WorkManager process restart.

Build integration_test/android_retained_startup_test.dart with
BUSYMAX_RETAINED_STARTUP_QA=true. Run the same APK in both phases. Requires an
unlocked designated Android device with NO installed BusyMax package. Only this
new test installation is removed after evidence capture, including on failure.
No scheduled jobs are cancelled or replaced to obtain a passing restart.
"""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import os
import subprocess
import sqlite3
import tempfile
import threading
import time
import urllib.parse
import urllib.request

PACKAGE = 'io.busystack.busymax'
# The recovery phase contains up to eight sequential native workers (each has
# its unchanged 45-second Dart assertion bound), plus UI and remote revocation.
# The former 180-second host watchdog could stop publishing receipts while a
# worker that was still within its own bound completed successfully.
LIFECYCLE_PHASE_SECONDS = 8 * 45 + 60


def classify_database_failures(operations):
    """Keep SQL/unknown failures fatal; retain proven idle-read cancellations.

    Drift's public final CancellationException is expected when an obsolete
    query-stream subscription is cancelled. It is not a SQLite failure. Never
    apply that classification to a write, a transaction, missing metadata or a
    record carrying a SQLite error code.
    """
    unexpected, cancelled_reads = [], []
    for event in operations:
        if event.get('failed') is False:
            continue
        if (event.get('failed') is True and
                event.get('operation') == 'read' and
                'transaction' in event and event['transaction'] is None and
                event.get('errorType') == 'CancellationException' and
                event.get('cancelled') is True and
                'sqliteExtendedResultCode' not in event and
                'sqliteResultCode' not in event):
            cancelled_reads.append(event)
        else:
            unexpected.append(event)
    return unexpected, cancelled_reads


def logcat_resume_cursor(contents):
    stamps = re.findall(r'(?m)^\s*(\d{10}\.\d{3,})\s', contents)
    if not stamps:
        raise RuntimeError('Log capture ended without a resumable timestamp.')
    # Re-read a one-second overlap across Android log buffers; event identities
    # are deduplicated below. This never restarts or alters an app worker.
    return f'{max(map(float, stamps)) - 1:.3f}'


def foreground_test_completed(contents, verified):
    if not verified:
        return False
    verified_at = datetime.fromisoformat(verified['utc'].replace('Z', '+00:00')).timestamp()
    return any('All tests passed!' in line and
               (stamp := re.match(r'^\s*(\d{10}\.\d{3,})\s', line)) and
               float(stamp[1]) + .001 >= verified_at
               for line in contents.splitlines())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--apk', required=True, type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--sample-stacks', action='store_true', help='Collect expensive VM stacks in addition to connection timing.')
    parser.add_argument('--lifecycle', action='store_true', help='Evaluate the live certificate lifecycle and changed-pin restart after original worker completion.')
    options = parser.parse_args()
    output = options.output or Path(tempfile.mkdtemp(prefix='busymax-retained-startup-'))
    if output.exists() and any(output.iterdir()):
        raise SystemExit('Use a new empty evidence directory; stale results are not acceptance.')
    output.mkdir(parents=True, exist_ok=True)
    base = ['adb', '-s', options.device]

    def adb(*args, timeout=20, check=True, data=None):
        result = subprocess.run([*base, *args], capture_output=True, timeout=timeout, input=data)
        if check and result.returncode:
            raise RuntimeError('QA ADB command failed: ' + ' '.join(args[:3]))
        return result

    def receipt(name):
        result = adb('exec-out', 'run-as', PACKAGE, 'cat',
                     f'files/retained-startup-qa/{name}.json', check=False)
        try:
            return json.loads(result.stdout)
        except (ValueError, UnicodeError):
            return None

    sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
               or str(Path.home() / 'Android/Sdk'))
    candidates = sorted((sdk / 'build-tools').glob('*/aapt'), reverse=True)
    aapt = shutil.which('aapt') or (str(candidates[0]) if candidates else None)
    if not aapt:
        raise SystemExit('Android SDK build-tools/aapt is required to verify the APK identity.')
    metadata = subprocess.check_output([aapt, 'dump', 'badging', str(options.apk)], timeout=20).decode()
    if not re.search(r"^package: name='" + re.escape(PACKAGE) + r"'", metadata, re.M):
        raise SystemExit('The APK is not the isolated BusyMax test application.')
    if adb('shell', 'pm', 'list', 'packages', PACKAGE).stdout.strip():
        raise SystemExit('Refusing to replace an existing BusyMax installation.')
    policy = adb('shell', 'dumpsys', 'window', 'policy').stdout.decode()
    if 'showing=true' in policy:
        raise SystemExit('Unlock the designated test device before this probe.')
    original_awake = adb('shell', 'settings', 'get', 'global',
                         'stay_on_while_plugged_in').stdout.decode().strip()
    report = {'apkSha256': hashlib.sha256(options.apk.read_bytes()).hexdigest(),
              'device': options.device, 'retainedWorkCancelled': False}
    (output / 'manifest.json').write_text(json.dumps(report, indent=2))
    installed = False
    logcat = None
    capture_name = None
    capture_pid = None
    report['logcatReconnects'] = []
    observer = None
    stop = threading.Event()
    forwards = []
    samples = []

    def vm_observer():
        known = {}
        sampled_metadata = set()
        observed_rpc_errors = set()
        while not stop.wait(.5):
            path = output / 'restart-logcat.log'
            if not path.exists():
                continue
            text = path.read_text(errors='replace')
            for port, token in re.findall(
                    r'Dart VM service is listening on http://127\.0\.0\.1:(\d+)/([^\s/]+)/', text):
                if (port, token) not in known:
                    forwarded = adb('forward', 'tcp:0', 'tcp:' + port, check=False)
                    if forwarded.returncode == 0:
                        host = forwarded.stdout.decode().strip()
                        forwards.append(host)
                        known[(port, token)] = f'http://127.0.0.1:{host}/{token}/'
            for root in list(known.values()):
                def rpc(method, **params):
                    request = root + method + '?' + urllib.parse.urlencode(params)
                    with urllib.request.urlopen(request, timeout=.8) as response:
                        message = json.load(response)
                        if 'error' in message:
                            key = (method, str(message['error']))
                            if key not in observed_rpc_errors:
                                observed_rpc_errors.add(key)
                                with (output / 'vm-errors.jsonl').open('a') as errors:
                                    errors.write(json.dumps({'method': method, 'error': message['error']}) + '\n')
                        return message.get('result', {})
                try:
                    vm = rpc('getVM')
                    snapshot = {'hostMonotonicNs': time.monotonic_ns(),
                                'groups': vm.get('isolateGroups', []), 'isolates': []}
                    for isolate in vm.get('isolates', []):
                        item = {'id': isolate['id'], 'name': isolate.get('name')}
                        if isolate['id'] not in sampled_metadata:
                            detail = rpc('getIsolate', isolateId=isolate['id'])
                            item['rootLibrary'] = detail.get('rootLib', {}).get('uri')
                            item['group'] = detail.get('isolateGroupId')
                            item['pauseKind'] = detail.get('pauseEvent', {}).get('kind')
                            if item['rootLibrary']:
                                sampled_metadata.add(isolate['id'])
                        stack = rpc('getStack', isolateId=isolate['id'], limit=40) if options.sample_stacks else {}
                        frames = stack.get('frames', []) + stack.get('asyncCausalFrames', [])
                        item['frames'] = [
                            {'function': f.get('function', {}).get('name'),
                             'script': f.get('location', {}).get('script', {}).get('uri'),
                             'tokenPos': f.get('location', {}).get('tokenPos')}
                            for f in frames]
                        snapshot['isolates'].append(item)
                    samples.append(snapshot)
                except (OSError, ValueError, KeyError):
                    pass  # Sampling unavailability is reported, never a pass.
        (output / 'vm-samples.json').write_text(json.dumps(samples))

    def collect():
        current = receipt('entry') or {}
        for name in ['entry', 'inventory', 'runtime-start', 'runtime-opened',
                     'seeded', 'prepared', 'foreground-ready', 'foreground-writing', 'workers-finished', 'retained-verified', 'certificate-paused', 'failure', 'verified']:
            value = receipt(name)
            if value is not None and (name in ['seeded', 'prepared', 'retained-verified', 'certificate-paused'] or value.get('pid') == current.get('pid')):
                (output / (name + '.json')).write_text(json.dumps(value, indent=2))
        inventory = adb('shell', 'dumpsys', 'jobscheduler', PACKAGE, check=False)
        (output / 'jobscheduler.log').write_bytes(inventory.stdout)

    try:
        adb('shell', 'settings', 'put', 'global', 'stay_on_while_plugged_in', '2')
        adb('install', '--no-streaming', str(options.apk.resolve()), timeout=120)
        installed = True
        def start_capture(name, resume=None):
            nonlocal capture_name, capture_pid
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                value = adb('shell', 'pidof', PACKAGE, check=False).stdout.decode().strip()
                if value:
                    break
                time.sleep(.05)
            if not value:
                raise RuntimeError('The QA activity process did not start.')
            if resume is not None and value != capture_pid:
                raise RuntimeError('The observed app process died; refusing to substitute a new process.')
            capture_name, capture_pid = name, value
            args = [*base, 'logcat', '-v', 'epoch', '--pid=' + value]
            if resume is not None:
                args += ['-T', resume]
            with (output / name).open('ab' if resume is not None else 'wb') as log:
                return subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)

        def resume_capture_if_needed():
            nonlocal logcat
            if logcat.poll() is None:
                return
            if len(report['logcatReconnects']) >= 5:
                raise RuntimeError('Repeated logcat transport failure; native evidence is incomplete.')
            cursor = logcat_resume_cursor((output / capture_name).read_text(errors='replace'))
            report['logcatReconnects'].append({'file': capture_name, 'pid': capture_pid, 'cursor': cursor})
            logcat = start_capture(capture_name, resume=cursor)
        adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
        logcat = start_capture('prepare-logcat.log')
        observer = threading.Thread(target=vm_observer, daemon=True)
        observer.start()
        deadline = time.monotonic() + 90
        preparation = None
        while time.monotonic() < deadline:
            resume_capture_if_needed()
            preparation = receipt('prepared')
            if preparation is not None:
                break
            if receipt('failure'):
                raise RuntimeError('Preparation failed; no restart pass is possible.')
            time.sleep(.1)
        if preparation is None:
            raise RuntimeError('Preparation receipt barrier was not reached.')
        # Capture original IDs/states and stop promptly, before cold workers
        # can complete. This is the intended real process interruption.
        (output / 'before-stop.json').write_text(json.dumps(preparation, indent=2))
        adb('shell', 'am', 'force-stop', PACKAGE)
        logcat.terminate()
        logcat.wait(timeout=10)
        if adb('shell', 'pidof', PACKAGE, check=False).stdout.strip():
            raise RuntimeError('The original QA process did not stop.')
        for source, target in [
                ('no_backup/androidx.work.workdb', 'work-before-restart.db'),
                ('files/busymax.sqlite', 'app-before-restart.db')]:
            for suffix in ['', '-wal', '-shm']:
                result = adb('exec-out', 'run-as', PACKAGE, 'cat',
                             source + suffix, check=False)
                if result.returncode == 0:
                    (output / (target + suffix)).write_bytes(result.stdout)
        snapshot_uri = (output / 'work-before-restart.db').resolve().as_uri() + '?mode=ro'
        with sqlite3.connect(snapshot_uri, uri=True) as work:
            report['retainedNames'] = work.execute(
                'SELECT name,work_spec_id FROM WorkName').fetchall()
            retained_rows = work.execute(
                'SELECT id,state,run_attempt_count,period_count,initial_delay,'
                'interval_duration,flex_duration FROM WorkSpec').fetchall()
        report['retainedWorkRows'] = retained_rows
        if len(retained_rows) != 2 or any(row[1:4] != (0, 0, 0) for row in retained_rows):
            raise RuntimeError('Work was already attempted before force-stop; backoff would invalidate concurrency.')
        # Let the explicit three-second first-run delay expire while STOPPED.
        # No WorkManager row, attempt count, constraints or backoff is edited.
        time.sleep(3)
        report['forceStopHostMonotonicNs'] = time.monotonic_ns()
        adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
        logcat = start_capture('restart-logcat.log')
        deadline = time.monotonic() + 35
        report['evaluatedPids'] = [capture_pid]
        expected_ids = {row[0] for row in retained_rows}
        worker_results = {}
        acknowledged = False
        observation_started = False
        lifecycle_started = False
        recovery_started = False
        published_outcomes = {}
        while time.monotonic() < deadline:
            resume_capture_if_needed()
            text = (output / 'restart-logcat.log').read_text(errors='replace')
            if (output / 'recovery-logcat.log').exists():
                text += (output / 'recovery-logcat.log').read_text(errors='replace')
            worker_results = dict((job, state) for state, job in re.findall(
                r'Worker result (\w+) for Work \[ id=([a-f0-9-]+)', text))
            opened = receipt('runtime-opened')
            if (not observation_started and opened and
                    str(opened.get('pid')) == capture_pid):
                # Match the Dart probe's bounded observation budget,
                # which begins after runtime creation. The previous host clock
                # incorrectly spent that budget on initialization as well.
                observation_started = True
                report['observationStartedAfterRuntime'] = opened['utc']
                report['observationBudgetSeconds'] = 120 if options.lifecycle else 35
                deadline = time.monotonic() + report['observationBudgetSeconds']
            if options.lifecycle:
                outcomes = {}
                for state, job, tags in re.findall(
                        r'Worker result (\w+) for Work \[ id=([a-f0-9-]+), tags=\{([^}]+)\}', text):
                    for tag in tags.split(','):
                        tag = tag.strip()
                        if tag.startswith('busymax.qa.native.'):
                            outcomes[tag] = {'state': state, 'id': job}
                if outcomes != published_outcomes:
                    adb('shell', 'run-as', PACKAGE, 'tee',
                        'files/retained-startup-qa/worker-outcomes.tmp',
                        data=json.dumps(outcomes).encode())
                    adb('shell', 'run-as', PACKAGE, 'mv',
                        'files/retained-startup-qa/worker-outcomes.tmp',
                        'files/retained-startup-qa/worker-outcomes.json')
                    published_outcomes = outcomes
            if not acknowledged and receipt('foreground-writing') and expected_ids <= worker_results.keys():
                refill_ids = {job for name, job in report['retainedNames']
                              if name == 'busymax.notification-refill.v1'}
                acknowledgment = {
                    'workerResults': worker_results,
                    'retainedNames': report['retainedNames'],
                    'allRetainedWorkersFinished': True,
                    'workerInitializationFailed': any(worker_results.get(job) == 'FAILURE' for job in expected_ids),
                    'notificationRefillSucceeded': bool(refill_ids) and all(worker_results.get(job) == 'SUCCESS' for job in refill_ids),
                }
                adb('shell', 'run-as', PACKAGE, 'tee',
                    'files/retained-startup-qa/workers-finished.json',
                    data=json.dumps(acknowledgment).encode())
                acknowledged = True
            if options.lifecycle and acknowledged and receipt('retained-verified') and not lifecycle_started:
                # The completed live startup observation has its own bound.
                # The subsequent lifecycle phase performs multiple real workers,
                # UI replacement, outage/recovery and remote revocation.
                lifecycle_started = True
                deadline = time.monotonic() + LIFECYCLE_PHASE_SECONDS
            if options.lifecycle and receipt('certificate-paused') and not recovery_started:
                collect()
                report['changedPinProcessInterrupted'] = True
                adb('shell', 'am', 'force-stop', PACKAGE)
                logcat.terminate()
                logcat.wait(timeout=10)
                if adb('shell', 'pidof', PACKAGE, check=False).stdout.strip():
                    raise RuntimeError('Changed-pin process did not stop.')
                adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')
                logcat = start_capture('recovery-logcat.log')
                report['evaluatedPids'].append(capture_pid)
                recovery_started = True
                deadline = time.monotonic() + LIFECYCLE_PHASE_SECONDS
            if (foreground_test_completed(text, receipt('verified')) or receipt('failure')) and expected_ids <= worker_results.keys():
                break
            time.sleep(.15)
        collect()
        foreground = receipt('verified')
        failure = receipt('failure')
        text = (output / 'restart-logcat.log').read_text(errors='replace')
        if (output / 'recovery-logcat.log').exists():
            text += (output / 'recovery-logcat.log').read_text(errors='replace')
        report['sqliteErrors'] = [line for line in text.splitlines()
                                  if 'SqliteException(' in line or 'database is locked' in line]
        report['workerResults'] = worker_results
        report['allRetainedWorkersFinished'] = expected_ids <= worker_results.keys()
        report['workerInitializationFailed'] = any(worker_results.get(job) == 'FAILURE' for job in expected_ids)
        refill_ids = {job for name, job in report['retainedNames']
                      if name == 'busymax.notification-refill.v1'}
        report['notificationRefillSucceeded'] = bool(refill_ids) and all(
            worker_results.get(job) == 'SUCCESS' for job in refill_ids)
        report['foregroundFailure'] = failure
        report['foregroundVerified'] = foreground is not None
        report['foregroundTestCompleted'] = foreground_test_completed(text, foreground)
        report['maxSimultaneousIsolateGroups'] = max(
            (len(s['groups']) for s in samples
             if s['hostMonotonicNs'] >= report['forceStopHostMonotonicNs']), default=0)
        trace_lines = []
        trace_root = output / 'sql-traces'
        trace_root.mkdir(exist_ok=True)
        names = adb('shell', 'run-as', PACKAGE, 'ls', '-1', 'files').stdout.decode().splitlines()
        for name in names:
            match = re.fullmatch(r'busymax-qa-sql-(\d+)-[A-Za-z0-9]+', name)
            if not match or match[1] not in report['evaluatedPids']:
                continue
            value = adb('exec-out', 'run-as', PACKAGE, 'cat', 'files/' + name + '/operations.jsonl').stdout
            (trace_root / (name + '.jsonl')).write_bytes(value)
            trace_lines.extend(value.decode().splitlines())
        report['traceFailure'] = 'BUSYMAX_SQLITE_TRACE_FAILED' in text
        starts = {}
        operations = []
        observed_events = set()
        for line in trace_lines:
            event = json.loads(line)
            if event['connection'].split('/')[0] not in report['evaluatedPids']:
                continue
            key = (event['connection'], event['event'])
            identity = (*key, event['phase'])
            if identity in observed_events:
                continue
            observed_events.add(identity)
            if event['phase'] == 'start':
                starts[key] = event
            elif key in starts:
                start = starts.pop(key)
                operations.append({**event, 'startMicros': start['utcMicros']})
        overlaps = []
        ordered = sorted(operations, key=lambda e: e['startMicros'])
        for i, a in enumerate(ordered):
            for b in ordered[i+1:]:
                if b['startMicros'] >= a['utcMicros']:
                    break
                if a['connection'] != b['connection'] and ({a['operation'], b['operation']} & {'begin', 'commit', 'insert', 'update', 'delete', 'custom', 'batch'}):
                    overlaps.append([a, b])
        (output / 'sqlite-operations.json').write_text(json.dumps(operations))
        report['sqliteConnections'] = sorted({e['connection'] for e in operations})
        report['overlappingDatabaseOperations'] = len(overlaps)
        startup = (receipt('retained-verified') if options.lifecycle else foreground) or {}
        foreground_isolate = startup.get('isolate')
        foreground_overlaps = [pair for pair in overlaps if foreground_isolate and any(
            foreground_isolate in e['connection'] for e in pair)]
        report['foregroundDatabaseOverlaps'] = len(foreground_overlaps)
        report['overlapExamples'] = overlaps[:5]
        unexpected, cancelled_reads = classify_database_failures(operations)
        report['failedSqlOperations'] = unexpected
        report['cancelledReadOperations'] = cancelled_reads
        report['passed'] = bool(foreground and not failure and
                                report['foregroundTestCompleted'] and
                                not report['sqliteErrors'] and
                                not report['traceFailure'] and
                                not report['failedSqlOperations'] and
                                report['foregroundDatabaseOverlaps'] > 0 and
                                startup.get('foregroundTransactions', 0) > 0 and
                                (not options.lifecycle or (recovery_started and foreground.get('certificateLifecycleCompleted'))) and
                                len(report['sqliteConnections']) >= 3 and
                                report['maxSimultaneousIsolateGroups'] >= 3 and
                                report['allRetainedWorkersFinished'] and
                                not report['workerInitializationFailed'] and
                                report['notificationRefillSucceeded'])
    except Exception as error:
        report['orchestrationFailure'] = str(error)
        if installed:
            collect()
        report['passed'] = False
    finally:
        stop.set()
        if observer:
            observer.join(timeout=10)
        if logcat:
            logcat.terminate()
            logcat.wait(timeout=10)
        if installed:
            adb('shell', 'am', 'force-stop', PACKAGE, check=False)
            removed = adb('uninstall', PACKAGE, check=False)
            report['testInstallationRemoved'] = b'Success' in removed.stdout
        for port in forwards:
            adb('forward', '--remove', 'tcp:' + port, check=False)
        if original_awake == 'null':
            adb('shell', 'settings', 'delete', 'global', 'stay_on_while_plugged_in')
        else:
            adb('shell', 'settings', 'put', 'global',
                'stay_on_while_plugged_in', original_awake)
        (output / 'result.json').write_text(json.dumps(report, indent=2))
    print(json.dumps({'passed': report['passed'], 'evidence': str(output),
                      'foregroundFailure': (report.get('foregroundFailure') or {}).get('sqliteExtendedResultCode'),
                      'maxSimultaneousIsolateGroups': report.get('maxSimultaneousIsolateGroups')}))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
