#!/usr/bin/env python3
"""Run available journal checks and fail if the required matrix is incomplete."""

import argparse
import base64
import datetime as dt
import errno
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
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
NEXTCLOUD_35_0_3 = (
    'nextcloud:35.0.3-apache@'
    'sha256:f44180601f18e7664557232b4c5edb0eb4a82d649c05b93313f4e15909553d42'
)
NEXTCLOUD_35_0_3_REJECTIONS = {
    'J15-start-end', 'J15-start-duration', 'J12-link-uid',
    'J12-link-xml', 'J12-related-uid',
}


def commit(path):
    return subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=path, text=True).strip()


def clean(path):
    return not subprocess.check_output(['git', 'status', '--porcelain'], cwd=path)


def remove_linux_profile(root):
    def active_mount(mount):
        try:
            return mount.is_mount()
        except OSError as error:
            if error.errno == errno.ENOTCONN:
                return True
            raise

    for attempt in range(12):
        try:
            for mount in (root / 'runtime/doc', root / 'runtime/gvfs'):
                if active_mount(mount):
                    result = subprocess.run(['fusermount3', '-uz', str(mount)], capture_output=True)
                    if result.returncode and active_mount(mount):
                        result.check_returncode()
            shutil.rmtree(root)
            return
        except (OSError, subprocess.CalledProcessError) as error:
            if isinstance(error, OSError) and error.errno != errno.ENOTCONN:
                raise
            if attempt == 11:
                raise
            # A portal can detach its FUSE mount between is_mount and
            # rmtree. Wait for that process to finish, then inspect again.
            time.sleep(0.5)


def apk_signer_digests(output):
    # Build-tools 37 labels signers by signature scheme. Older official
    # releases label them by ordinal.
    return {digest.lower() for digest in re.findall(
        r'^(?:Signer #\d+|V[1-4](?:\.\d+)? Signer(?: #\d+)?):? '
        r'certificate SHA-256 digest: ([a-fA-F0-9]{64})$', output, re.M,
    )}


def classify_nextcloud_admission(records, fixture, fixture_sha, identity, exit_code):
    """Classify the exact stock-provider exceptions independently of client tests."""
    identity_matches = (identity['image'] == NEXTCLOUD_35_0_3 and
                        identity['nextcloud'] == '35.0.3.2')
    if (len(records) < 2 or records[0].get('fixture_sha256') != fixture_sha or
            records[0].get('fixture_version') != fixture['version']):
        return 'fail'
    pairs = {(row['id'], operation) for row in fixture['cases']
             for operation in ('create', 'update')}
    operations = records[1:-1]
    actual = {(row.get('case'), row.get('operation')) for row in operations}
    if len(operations) != len(pairs) or actual != pairs:
        return 'fail'
    rejected = set()
    for row in operations:
        case, operation = row['case'], row['operation']
        created = operation == 'create'
        if row.get('issue') is None and row.get('get') == 200 and row.get('put') == (201 if created else 204):
            continue
        if (identity_matches and case in NEXTCLOUD_35_0_3_REJECTIONS and row.get('put') == 500
                and row.get('get') == (404 if created else 200)
                and row.get('issue') == 'admission rejected; original state unchanged'):
            rejected.add((case, operation))
        else:
            return 'fail'
    if not rejected and exit_code == 0 and records[-1] == {
            'executed': len(pairs), 'passed': len(pairs), 'failed': 0}:
        return 'pass'
    known = {(case, operation) for case in NEXTCLOUD_35_0_3_REJECTIONS
             for operation in ('create', 'update')}
    if (rejected == known and exit_code == 1 and records[-1] == {
            'executed': len(pairs), 'passed': len(pairs) - len(known), 'failed': len(known)}):
        return 'upstream-blocked'
    return 'fail'


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def checkpoint(artifact, evidence):
    temporary = artifact / 'manifest.json.next'
    temporary.write_text(json.dumps(evidence, indent=2) + '\n')
    temporary.replace(artifact / 'manifest.json')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--nextcloud', type=Path, required=True)
    parser.add_argument('--fixture', type=Path, required=True, help='Private two-account JSON')
    parser.add_argument('--artifacts', type=Path, required=True)
    parser.add_argument('--android-device', help='Serial of the isolated Android QA device')
    parser.add_argument('--android-aapt', type=Path, help='Official Android build-tools aapt executable')
    parser.add_argument('--android-process-restart', action='store_true',
                        help='Test offline queue and replay in separate Android QA processes')
    parser.add_argument('--windows-runner', type=Path,
                        help='Authorized executable that runs the Windows native journal suite')
    parser.add_argument('--native-platform', action='append', choices=('linux', 'windows', 'android'),
                        help='Run only the selected native runtime(s) for diagnosis. Omitted cells remain incomplete.')
    parser.add_argument('--native-provider', action='append', choices=('caldav', 'nextcloud'),
                        help='Run native diagnostics only on selected providers. Omitted cells remain incomplete.')
    parser.add_argument('--native-only', action='store_true',
                        help='Rerun native cells after a device interruption without repeating provider probes. '
                             'The result is always an incomplete matrix.')
    parser.add_argument('--linux-process-restart', action='store_true',
                        help='Run the Linux offline workflow in two native processes using an isolated keyring')
    parser.add_argument('--linux-account-enrollment', action='store_true',
                        help='Run provider enrollment via the real Linux Settings UI on isolated X11')
    args = parser.parse_args()
    artifact = args.artifacts.resolve() / ('vjournal-' + uuid.uuid4().hex[:12])
    artifact.mkdir(parents=True, mode=0o700)
    server = args.server.resolve()
    fixture = args.fixture.resolve()
    candidate = args.candidate.resolve()
    nextcloud = args.nextcloud.resolve()
    if fixture.stat().st_mode & 0o077:
        raise SystemExit('The fixture contains app passwords and must be private.')
    if not clean(BUSYMAX) or not clean(server):
        raise SystemExit('Qualification requires clean BusyMax and server source checkouts.')
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
        'nativeMatrix': {f'{platform}/{provider}': 'not run'
                         for platform in ('linux', 'windows', 'android')
                         for provider in profiles},
    }
    if 'calendarLimits' in nextcloud_info:
        evidence['nextcloud']['calendarLimits'] = nextcloud_info['calendarLimits']
    results = evidence['gates']
    environment = dict(os.environ, BUSYMAX_JOURNAL_LIVE_FIXTURE=str(fixture),
                       BUSYMAX_JOURNAL_CORPUS=str(corpus))
    checkpoint(artifact, evidence)

    def run(label, command, *, named=(), extra_env=None):
        log = artifact / (label + '.log')
        started = utc()
        results[label] = dict(started=started, status='running',
                              command=command, missing=list(named), log=log.name)
        checkpoint(artifact, evidence)
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
        checkpoint(artifact, evidence)
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

    def linux_profile(label, command, named, *, restart=False, enrollment=None):
        root = Path(tempfile.mkdtemp(prefix='journal-native-profile-'))
        runtime = root / 'runtime'
        runtime.mkdir(mode=0o700)
        extra_env = {'XDG_CONFIG_HOME': str(root / 'config'),
                     'XDG_DATA_HOME': str(root / 'data'),
                     'XDG_RUNTIME_DIR': str(runtime),
                     'GIO_USE_VFS': 'local'}
        if restart:
            extra_env['BUSYMAX_JOURNAL_RESTART_PROFILE'] = str(root / 'profile')
        launcher = ['dbus-run-session', '--']
        if enrollment:
            for directory in (root / 'config', root / 'data'):
                directory.mkdir(mode=0o700)
            extra_env.update(GDK_BACKEND='x11', BUSYMAX_JOURNAL_LINUX_NATIVE_ENROLLMENT='1',
                             BUSYMAX_JOURNAL_LINUX_ENROLLMENT_PROVIDER=enrollment)
            launcher = ['xvfb-run', '-a', '-s', '-screen 0 1280x1024x24', *launcher]
            if enrollment == 'nextcloud':
                applications = root / 'data' / 'applications'
                applications.mkdir(mode=0o700)
                handler = FIXTURES / 'browser/nextcloud-journal-open.sh'
                desktop = 'busymax-journal-nextcloud-qa.desktop'
                (applications / desktop).write_text(
                    '[Desktop Entry]\nType=Application\nName=BusyMax Nextcloud QA browser\n'
                    f'Exec="{handler}" %u\nMimeType=x-scheme-handler/https;\nNoDisplay=true\n',
                )
                (root / 'config' / 'mimeapps.list').write_text(
                    f'[Default Applications]\nx-scheme-handler/https={desktop}\n',
                )
        passed = run(label, [*launcher, *command],
                     named=named, extra_env=extra_env)
        binary = BUSYMAX / 'build/linux/x64/debug/bundle/busymax'
        if passed:
            try:
                with binary.open('rb') as executable:
                    results[label]['executableSha256'] = hashlib.file_digest(executable, 'sha256').hexdigest()
            except OSError as error:
                results[label]['artifactError'] = str(error)
                passed = False
            checkpoint(artifact, evidence)
        try:
            remove_linux_profile(root)
        except (OSError, subprocess.CalledProcessError) as error:
            results[label]['cleanupError'] = str(error)
            passed = False
        return passed

    def linux_restart(provider):
        label = f'linux-{provider}-process-restart'
        stages = """
set -eu
printf %s busymax-journal-test-keyring | gnome-keyring-daemon --unlock --components=secrets
for stage in queue replay; do
  BUSYMAX_JOURNAL_RESTART_STAGE="$stage" flutter test --no-pub -d linux \
    integration_test/journal_linux_workflows_test.dart --reporter expanded \
    --plain-name "Linux offline journal $stage across processes on $1"
done
"""
        passed = linux_profile(
            label, ['bash', '-c', stages, 'journal-restart', provider],
            named=[f'Linux offline journal {stage} across processes on {provider}'
                   for stage in ('queue', 'replay')],
            restart=True,
        )
        return label, passed

    def linux_account_enrollment(provider):
        label = f'linux-{provider}-account-enrollment'
        display = 'Nextcloud' if provider == 'nextcloud' else 'CalDAV'
        command = '''
set -eu
printf %s busymax-journal-test-keyring | gnome-keyring-daemon --unlock --components=secrets
flutter test --no-pub -d linux integration_test/journal_linux_account_enrollment_test.dart --reporter expanded
'''
        passed = linux_profile(
            label, ['bash', '-c', command],
            named=[f'Linux production {display} enrollment discovers a journal source'],
            enrollment=provider,
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
        defines = {'BUSYMAX_JOURNAL_PROVIDER': provider,
                   'BUSYMAX_JOURNAL_NATIVE_FIXTURE': base64.b64encode(
                       json.dumps(configuration).encode()).decode()}
        os.close(os.open(private, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600))
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

        def stage_run(label, stage=None):
            stage_defines = dict(defines)
            expected = f'Android journal collection and editor on {provider}'
            prefix = f'android-{provider}' if stage is None else label
            if stage is not None:
                stage_defines.update(BUSYMAX_JOURNAL_RESTART_STAGE=stage,
                                     BUSYMAX_JOURNAL_RESTART_RUN=artifact.name.removeprefix('vjournal-'))
                expected = f'Android offline journal {stage} across processes on {provider}'
            private.write_text(json.dumps(stage_defines))
            if not run(f'{prefix}-build', ['flutter', 'build', 'apk', '--debug',
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
                return apk_signer_digests(response.stdout)

            def read_installed(local_apk):
                paths = subprocess.run(
                    [*adb, 'shell', 'pm', 'path', package_id],
                    capture_output=True, text=True,
                )
                base = next((line.removeprefix('package:') for line in paths.stdout.splitlines()
                             if line.startswith('package:') and line.endswith('/base.apk')), None)
                if paths.returncode or base is None:
                    return False
                copied = subprocess.run([*adb, 'pull', base, str(local_apk)],
                                        capture_output=True)
                return copied.returncode == 0

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
                with tempfile.TemporaryDirectory(dir=artifact) as directory:
                    local_apk = Path(directory) / 'existing-qa.apk'
                    if not read_installed(local_apk) or certificates(local_apk) != signing_identity:
                        return 'not run: existing QA signing identity differs; retained installed package and data'
            # A safe update catches other install problems before Flutter's
            # install retry can uninstall a previously installed QA package.
            if not run(f'{prefix}-install-check', [*adb, 'install', '-r', '-t', str(apk)]):
                return 'not run: the safe QA install/update failed'
            with apk.open('rb') as binary:
                apk_hash = hashlib.file_digest(binary, 'sha256').hexdigest()
            apk_identity = {'applicationId': package_id, 'preflightSha256': apk_hash,
                            'signerCertificateSha256': sorted(signing_identity)}
            results[f'{prefix}-apk'] = apk_identity
            passed = run(label, ['flutter', 'test', native, '-d', serial,
                         '--no-uninstall', define, '--reporter', 'expanded'], extra_env=flags,
                         named=[expected])
            with tempfile.TemporaryDirectory(dir=artifact) as directory:
                local_apk = Path(directory) / 'tested-qa.apk'
                if read_installed(local_apk) and certificates(local_apk) == signing_identity:
                    with local_apk.open('rb') as binary:
                        apk_identity['installedSha256'] = hashlib.file_digest(binary, 'sha256').hexdigest()
                else:
                    apk_identity['artifactError'] = 'Installed QA artifact could not be verified after the run.'
                    passed = False
            return passed

        mapped = False
        try:
            if not run(f'android-{provider}-reverse', [*adb, 'reverse', '--no-rebind', tcp, tcp]):
                return 'not run: fixture port mapping failed'
            mapped = True
            labels = [f'android-{provider}-native']
            passed = stage_run(labels[0])
            if isinstance(passed, str):
                return passed
            if args.android_process_restart:
                for stage in ('queue', 'replay'):
                    if stage == 'replay' and not run(
                        f'android-{provider}-restart-stop', [*adb, 'shell', 'am', 'force-stop', package_id],
                    ):
                        passed = False
                        break
                    label = f'android-{provider}-restart-{stage}'
                    staged = stage_run(label, stage)
                    if isinstance(staged, str):
                        results[label] = {'status': staged}
                        passed = False
                        break
                    labels.append(label)
                    if not staged:
                        passed = False
                        break
            return native_result('android', provider, labels, passed)
        finally:
            if mapped:
                subprocess.run([*adb, 'reverse', '--remove', tcp], capture_output=True)
            private.unlink(missing_ok=True)

    if args.native_only:
        for label in ('caldav-admission', 'caldav-reports', 'nextcloud-admission',
                      'nextcloud-reports', 'nextcloud-permission-views', 'busymax-live'):
            results[label] = {'status': 'not run: native-only retry'}
    else:
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
        # Keep provider and migration checks serial on shared fixture accounts.
        run('busymax-live', ['flutter', 'test', '--concurrency', '1', '--timeout', '90s',
                            'test/journal', '--reporter', 'expanded'],
            named=[f'{scenario} with independent HTTPS readback on {provider}'
                   for provider in profiles
                   for scenario in ('journal durable CRUD',
                                    'journal range and historical queue recovery',
                                    'journal MOVE, conflict, and restart reconciliation')])
    for platform in ('linux', 'windows', 'android'):
        if args.native_platform and platform not in args.native_platform:
            continue
        for provider in ('caldav', 'nextcloud'):
            if args.native_provider and provider not in args.native_provider:
                continue
            if platform == 'linux':
                name = f'Linux journal collection and editor on {provider}'
                label = f'linux-{provider}-native'
                passed = linux_profile(label, ['flutter', 'test', '-d', 'linux',
                    'integration_test/journal_linux_workflows_test.dart', '--reporter', 'expanded',
                    '--plain-name', name], named=[name])
                labels = [label]
                if args.linux_process_restart:
                    restart_label, restart_passed = linux_restart(provider)
                    labels.append(restart_label)
                    passed = passed and restart_passed
                if args.linux_account_enrollment:
                    enrollment_label, enrollment_passed = linux_account_enrollment(provider)
                    labels.append(enrollment_label)
                    passed = passed and enrollment_passed
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
            checkpoint(artifact, evidence)
    evidence['finished'] = utc()
    evidence['sourceUnchanged'] = (clean(BUSYMAX) and clean(server)
                                   and commit(BUSYMAX) == evidence['busymax']
                                   and commit(server) == evidence['server'])
    if args.native_only:
        evidence['nextcloudRawAdmission'] = {'status': 'not run: native-only retry'}
    else:
        try:
            nextcloud_records = [json.loads(line) for line in
                                 (artifact / results['nextcloud-admission']['log']).read_text().splitlines()]
        except (ValueError, OSError):
            nextcloud_records = []
        evidence['nextcloudRawAdmission'] = classify_nextcloud_admission(
            nextcloud_records, json.loads(corpus.read_bytes()), evidence['admissionCorpusSha256'],
            nextcloud_info, results['nextcloud-admission']['exitCode'],
        )
    checkpoint(artifact, evidence)
    complete = (not args.native_only and evidence['sourceUnchanged']
                and all(isinstance(outcome, dict) and outcome['status'] == 'pass'
                    for outcome in evidence['nativeMatrix'].values())
                and all(gate.get('exitCode', 0) == 0 and not gate.get('missing')
                        for gate in results.values()))
    print(f'Required matrix {"passed" if complete else "incomplete"}. Evidence is in {artifact}', flush=True)
    return 0 if complete else 1


if __name__ == '__main__':
    raise SystemExit(main())
