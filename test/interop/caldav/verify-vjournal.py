#!/usr/bin/env python3
"""Run available journal checks and fail if the required matrix is incomplete."""

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

FIXTURES = Path(__file__).resolve().parent
BUSYMAX = FIXTURES.parents[2]


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

    evidence = {
        'run': artifact.name,
        'started': utc(),
        'busymax': commit(BUSYMAX),
        'server': candidate_info['sourceCommit'],
        'serverSchema': candidate_info['schema'],
        'busymaxSchema': 27,
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
    environment = dict(os.environ, BUSYMAX_JOURNAL_LIVE_FIXTURE=str(fixture))

    def run(label, command, *, named=()):
        log = artifact / (label + '.log')
        started = utc()
        with log.open('w') as output:
            process = subprocess.run(command, cwd=BUSYMAX, env=environment,
                                     stdout=output, stderr=subprocess.STDOUT)
        content = log.read_text(errors='replace')
        missing = [name for name in named
                   if not re.search(r'^\d\d:\d\d \+\d+.*: .*' + re.escape(name) + r'$', content, re.M)]
        results[label] = dict(started=started, finished=utc(), exitCode=process.returncode,
                              command=command, missing=missing, log=log.name)
        print(f'{label} completed with status {process.returncode}', flush=True)

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
    run('busymax-live', ['flutter', 'test', 'test/journal', '--reporter', 'expanded'],
        named=[f'journal durable CRUD with independent HTTPS readback on {provider}'
               for provider in profiles])
    run('linux-native', ['flutter', 'test', '-d', 'linux',
        'integration_test/journal_linux_workflows_test.dart', '--reporter', 'expanded'],
        named=[f'Linux journal collection and editor on {provider}' for provider in profiles])
    linux = results['linux-native']
    for platform in ('linux', 'windows', 'android'):
        for provider in ('caldav', 'nextcloud'):
            if platform == 'linux':
                result = (
                    'partial workflow executed successfully'
                    if linux['exitCode'] == 0 and not linux['missing']
                    else 'partial workflow failed or a required case was absent'
                )
            else:
                result = 'required native journal workflow unavailable'
            evidence['nativeMatrix'][f'{platform}/{provider}'] = result
    evidence['finished'] = utc()
    (artifact / 'manifest.json').write_text(json.dumps(evidence, indent=2) + '\n')
    print(f'Required matrix incomplete. Evidence is in {artifact}', flush=True)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
