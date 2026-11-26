#!/usr/bin/env python3
"""Run available journal checks and fail if the required matrix is incomplete."""

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import uuid
from urllib.parse import urlsplit

FIXTURES = Path(__file__).resolve().parent
BUSYMAX = FIXTURES.parents[2]
NATIVE_CASES = {
    'account-connect-and-discover', 'collection-create', 'collection-administration',
    'undated-repeated-description', 'dated-and-recurrence-editor', 'advanced-properties',
    'native-file-attachments-and-ics-transfer', 'peer-refresh-search',
    'draft-reopen', 'offline-process-restart', 'conditional-conflict-resolution',
    'permissions-and-scoped-sync-recovery', 'delete-tombstone-and-reopen',
}


def commit(path):
    return subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=path, text=True).strip()


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--nextcloud', type=Path, required=True)
    parser.add_argument('--fixture', type=Path, required=True, help='Private two-account JSON')
    parser.add_argument('--artifacts', type=Path, required=True)
    parser.add_argument('--android-device', help='Serial of the isolated Android QA device')
    parser.add_argument('--android-aapt', type=Path, help='Official Android build-tools aapt executable')
    parser.add_argument('--windows-runner', type=Path,
                        help='Authorized executable that runs the Windows native journal suite')
    parser.add_argument('--linux-process-restart', action='store_true',
                        help='Run the Linux offline workflow in two native processes using an isolated keyring')
    args = parser.parse_args()
    artifact = args.artifacts.resolve() / ('vjournal-' + uuid.uuid4().hex[:12])
    artifact.mkdir(parents=True, mode=0o700)
    server = args.server.resolve()
    fixture = args.fixture.resolve()
    candidate = args.candidate.resolve()
    nextcloud = args.nextcloud.resolve()
    if fixture.stat().st_mode & 0o077:
        raise SystemExit('The fixture contains app passwords and must be private.')
    profiles = json.loads(fixture.read_text())
    candidate_info = json.loads((candidate / 'candidate.json').read_text())
    nextcloud_info = json.loads((nextcloud / 'identity.json').read_text())
    corpus = server / 'qualification/fixtures/vjournal/admission-v1.json'
    if candidate_info['sourceCommit'] != commit(server) or candidate_info.get('schema') != 17:
        raise SystemExit('The candidate must be running the requested source commit at schema 17.')
    if profiles['caldav']['authority'] + 'dav/' != candidate_info['endpoint']:
        raise SystemExit('The BusyStack profile must point to the qualified candidate.')
    if profiles['nextcloud']['authority'] != nextcloud_info['authority']:
        raise SystemExit('The Nextcloud profile must point to the official fixture.')
    ports = {'caldav': candidate_info['project'], 'nextcloud': nextcloud_info['project']}
    application = subprocess.check_output(
        ['docker', 'ps', '--quiet', '--filter', 'label=com.docker.compose.project=' + ports['caldav'],
         '--filter', 'label=com.docker.compose.service=application'], text=True
    ).strip()
    for provider, container, identity in (
        ('caldav', application, candidate_info), ('nextcloud', ports['nextcloud'], nextcloud_info)
    ):
        if not container or '\n' in container:
            raise SystemExit(f'Expected one running {provider} fixture.')
        actual = subprocess.check_output(
            ['docker', 'inspect', '--format', '{{.State.Running}} {{.Image}}', container], text=True,
        ).strip()
        if actual != 'true ' + identity['imageId']:
            raise SystemExit(f'The running {provider} fixture has a different image.')
    running_jar = subprocess.check_output(
        ['docker', 'exec', application, 'sha256sum', '/opt/busystack/application.jar'], text=True
    ).split()[0]
    if running_jar != candidate_info['jarSha256']:
        raise SystemExit('The running candidate does not contain the verified JAR.')

    evidence = {
        'run': artifact.name,
        'started': utc(),
        'busymax': commit(BUSYMAX),
        'server': candidate_info['sourceCommit'],
        'serverSchema': candidate_info['schema'],
        'busymaxSchema': 28,
        'jarSha256': candidate_info['jarSha256'],
        'busyStackImage': candidate_info['imageId'],
        'nextcloud': {key: nextcloud_info[key] for key in (
            'nextcloud', 'image', 'imageId', 'php', 'database', 'sabreDav', 'sabreVObject'
        )},
        'admissionCorpusSha256': hashlib.sha256(corpus.read_bytes()).hexdigest(),
        'gates': {},
        'nativeMatrix': {},
    }
    results = evidence['gates']
    environment = dict(os.environ, BUSYMAX_JOURNAL_LIVE_FIXTURE=str(fixture),
                       BUSYMAX_JOURNAL_CORPUS=str(corpus))

    def run(label, command, *, named=(), extra_env=None):
        log = artifact / (label + '.log')
        started = utc()
        with log.open('w') as output:
            try:
                process = subprocess.run(command, cwd=BUSYMAX, env={**environment, **(extra_env or {})},
                                         stdout=output, stderr=subprocess.STDOUT)
                code = process.returncode
            except OSError as error:
                output.write(str(error) + '\n')
                code = 127
        content = log.read_text(errors='replace')
        missing = [name for name in named
                   if not re.search(r'^\d\d:\d\d \+\d+.*: .*' + re.escape(name) + r'$', content, re.M)]
        results[label] = dict(started=started, finished=utc(), exitCode=code,
                              command=command, missing=missing, log=log.name)
        print(f'{label} completed with status {code}', flush=True)
        return code == 0 and not missing

    def native_result(platform, provider, labels, smoke_passed):
        expected = NATIVE_CASES | ({'background-engine-invalidation'} if platform == 'android' else set())
        content = '\n'.join((artifact / results[label]['log']).read_text(errors='replace')
                            for label in labels)
        executed = set(re.findall(r'^JOURNAL_WORKFLOW_CASE ' + re.escape(provider)
                                  + r' ([a-z0-9-]+) PASS$', content, re.M))
        missing = sorted(expected - executed)
        return dict(status='fail' if not smoke_passed else 'partial' if missing else 'pass',
                    executed=sorted(executed), missing=missing)

    def linux_restart(provider):
        label = f'linux-{provider}-process-restart'
        with tempfile.TemporaryDirectory(prefix='journal-native-profile-') as profile:
            root = Path(profile)
            runtime = root / 'runtime'
            runtime.mkdir(mode=0o700)
            stages = """
set -eu
printf %s busymax-journal-test-keyring | gnome-keyring-daemon --unlock --components=secrets
for stage in queue replay; do
  BUSYMAX_JOURNAL_RESTART_STAGE="$stage" flutter test --no-pub -d linux \
    integration_test/journal_linux_workflows_test.dart --reporter expanded \
    --plain-name "Linux offline journal $stage across processes on $1"
done
"""
            passed = run(
                label, ['dbus-run-session', '--', 'bash', '-c', stages, 'journal-restart', provider],
                named=[f'Linux offline journal {stage} across processes on {provider}'
                       for stage in ('queue', 'replay')],
                extra_env={'XDG_CONFIG_HOME': str(root / 'config'),
                           'XDG_DATA_HOME': str(root / 'data'),
                           'XDG_RUNTIME_DIR': str(runtime),
                           'BUSYMAX_JOURNAL_RESTART_PROFILE': str(root / 'profile')},
            )
        return label, passed

    def android(provider, profile):
        if not args.android_device or not args.android_aapt:
            return 'not run: supply --android-device and --android-aapt'
        configuration = dict(profile)
        configuration['ca'] = Path(configuration.pop('caFile')).read_text()
        port = urlsplit(configuration['authority']).port
        if not port or urlsplit(configuration['authority']).hostname != 'localhost':
            return 'not run: Android fixture requires a TLS localhost endpoint with an explicit port'
        private = artifact / f'android-{provider}-private.json'
        with os.fdopen(os.open(private, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600), 'w') as stream:
            json.dump({'BUSYMAX_JOURNAL_PROVIDER': provider,
                       'BUSYMAX_JOURNAL_NATIVE_FIXTURE': base64.b64encode(
                           json.dumps(configuration).encode()).decode()}, stream)
        serial = args.android_device
        suffix = 'caldavqa' if provider == 'caldav' else 'nextcloudqa'
        package_id = 'io.busystack.busymax.' + suffix
        flags = {'ORG_GRADLE_PROJECT_busymaxTestSigning': 'true',
                 'ORG_GRADLE_PROJECT_busymaxCalDavQa': str(provider == 'caldav').lower(),
                 'ORG_GRADLE_PROJECT_busymaxNextcloudQa': str(provider == 'nextcloud').lower()}
        native = 'integration_test/journal_android_workflows_test.dart'
        define = '--dart-define-from-file=' + str(private)
        tcp = f'tcp:{port}'
        adb = ['adb', '-s', serial]
        mapped = False
        try:
            if not run(f'android-{provider}-reverse', [*adb, 'reverse', '--no-rebind', tcp, tcp]):
                return 'not run: fixture port mapping failed'
            mapped = True
            if not run(f'android-{provider}-build', ['flutter', 'build', 'apk', '--debug',
                       '--target=' + native, define], extra_env=flags):
                return 'not run: APK build failed'
            apk = BUSYMAX / 'build/app/outputs/flutter-apk/app-debug.apk'
            badging = subprocess.run([str(args.android_aapt.resolve()), 'dump', 'badging', str(apk)],
                                     text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            match = re.search(r"^package: name='([^']+)'", badging.stdout, re.M)
            if badging.returncode or not match or match[1] != package_id:
                return 'not run: verified APK application ID did not match the QA package'
            signer = args.android_aapt.resolve().with_name('apksigner')
            if not signer.is_file():
                return 'not run: apksigner must be installed alongside aapt'

            def certificates(path):
                response = subprocess.run(
                    [str(signer), 'verify', '--print-certs', str(path)],
                    capture_output=True, text=True,
                )
                if response.returncode:
                    return set()
                return set(re.findall(
                    r'^Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]+)$',
                    response.stdout, re.M,
                ))

            signing_identity = certificates(apk)
            if not signing_identity:
                return 'not run: the QA APK signature could not be verified'
            installed = subprocess.run(
                [*adb, 'shell', 'pm', 'list', 'packages', package_id],
                capture_output=True, text=True,
            )
            if installed.returncode:
                return 'not run: the device package inventory could not be read'
            if f'package:{package_id}' in installed.stdout.splitlines():
                paths = subprocess.run(
                    [*adb, 'shell', 'pm', 'path', package_id],
                    capture_output=True, text=True,
                )
                base = next((line.removeprefix('package:') for line in paths.stdout.splitlines()
                             if line.startswith('package:') and line.endswith('/base.apk')), None)
                if paths.returncode or base is None:
                    return 'not run: the installed QA APK could not be located'
                with tempfile.TemporaryDirectory(dir=artifact) as directory:
                    local_apk = Path(directory) / 'existing-qa.apk'
                    copied = subprocess.run([*adb, 'pull', base, str(local_apk)],
                                            capture_output=True)
                    if copied.returncode or certificates(local_apk) != signing_identity:
                        return 'not run: existing QA signing identity differs; retained installed package and data'
            # A safe update catches other install problems before Flutter's
            # install retry can uninstall a previously installed QA package.
            if not run(f'android-{provider}-install-check', [*adb, 'install', '-r', '-t', str(apk)]):
                return 'not run: the safe QA install/update failed'
            with apk.open('rb') as binary:
                apk_hash = hashlib.file_digest(binary, 'sha256').hexdigest()
            results[f'android-{provider}-apk'] = {'applicationId': package_id, 'sha256': apk_hash}
            label = f'android-{provider}-native'
            passed = run(label, ['flutter', 'test', native, '-d', serial,
                         '--no-uninstall', define, '--reporter', 'expanded'], extra_env=flags,
                         named=[f'Android journal collection and editor on {provider}'])
            return native_result('android', provider, [label], passed)
        finally:
            if mapped:
                subprocess.run([*adb, 'reverse', '--remove', tcp], capture_output=True)
            private.unlink(missing_ok=True)

    probe = server / 'qualification/clients/journal-admission.py'
    for provider, directory, dav_path in (
        ('caldav', candidate, 'dav/'), ('nextcloud', nextcloud, 'remote.php/dav/')
    ):
        profile = profiles[provider]
        run(f'{provider}-admission', [
            sys.executable, str(probe), profile['authority'] + dav_path, profile['username'],
            str(directory / 'owner-app-password'), '--ca-file', profile['caFile'],
        ])
        run(f'{provider}-reports', [
            sys.executable, str(FIXTURES / 'journal-provider-reports.py'), str(server),
            str(fixture), provider,
        ])
    run('nextcloud-permission-views', [
        sys.executable, str(FIXTURES / 'journal-nextcloud-views.py'),
        str(server), str(nextcloud),
    ])
    run('busymax-live', ['flutter', 'test', 'test/journal', '--reporter', 'expanded'],
        named=[f'journal durable CRUD with independent HTTPS readback on {provider}'
               for provider in profiles])
    for platform in ('linux', 'windows', 'android'):
        for provider in ('caldav', 'nextcloud'):
            if platform == 'linux':
                name = f'Linux journal collection and editor on {provider}'
                label = f'linux-{provider}-native'
                passed = run(label, ['flutter', 'test', '-d', 'linux',
                    'integration_test/journal_linux_workflows_test.dart', '--reporter', 'expanded',
                    '--plain-name', name], named=[name])
                labels = [label]
                if args.linux_process_restart:
                    restart_label, restart_passed = linux_restart(provider)
                    labels.append(restart_label)
                    passed = passed and restart_passed
                result = native_result(platform, provider, labels, passed)
            elif platform == 'android':
                result = android(provider, profiles[provider])
            elif args.windows_runner:
                label = f'windows-{provider}-native'
                passed = run(label, [str(args.windows_runner.resolve()), provider, str(fixture)],
                             named=[f'Windows journal collection and editor on {provider}'])
                result = native_result(platform, provider, [label], passed)
            else:
                result = 'not run: supply --windows-runner'
            evidence['nativeMatrix'][f'{platform}/{provider}'] = result
    evidence['finished'] = utc()
    (artifact / 'manifest.json').write_text(json.dumps(evidence, indent=2) + '\n')
    complete = (all(isinstance(outcome, dict) and outcome['status'] == 'pass'
                    for outcome in evidence['nativeMatrix'].values())
                and all(gate.get('exitCode', 0) == 0 and not gate.get('missing')
                        for gate in results.values()))
    print(f'Required matrix {"passed" if complete else "incomplete"}. Evidence is in {artifact}', flush=True)
    return 0 if complete else 1


if __name__ == '__main__':
    raise SystemExit(main())
