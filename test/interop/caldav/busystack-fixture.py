#!/usr/bin/env python3
"""Operate an isolated BusyMax qualification deployment."""
import argparse
import json
import os
import pathlib
import re
import runpy
import subprocess
import sys
import uuid

ROOT = pathlib.Path(__file__).resolve().parent
RUNTIME = ROOT / '.runtime'
PROJECT = 'busymax-caldav-busystack-qa'


def compose(*arguments):
    return ['docker', 'compose', '-p', PROJECT, '--env-file', str(RUNTIME / 'busystack-qa.env'),
            '-f', str(RUNTIME / 'busystack-release/caldav-server-0.1.0-deploy/compose.yaml'),
            '-f', str(ROOT / 'busystack-qa.override.yaml'), *arguments]


def browser(*arguments):
    private = pathlib.Path((RUNTIME / 'busystack-private-directory').read_text())
    return ['docker', 'run', '--rm', '--network', 'host', '--shm-size', '256m',
            '--volume', f'{ROOT}:/fixtures:ro', '--volume', f'{RUNTIME}:/fixtures/.runtime',
            '--volume', f'{private}:/private:ro', 'busymax-caldav-browser-qa:1.61.1', *arguments]


def main():
    global RUNTIME
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=pathlib.Path, help='Verified journal candidate fixture directory')
    parser.add_argument('action', choices=['setup', 'start', 'bootstrap', 'build-browser', 'provision', 'prepare-lifecycle',
                                         'share', 'group-create', 'group-members', 'group-delete', 'group-share',
                                         'issue', 'revoke', 'disable', 'expire', 'restart', 'profile', 'stop', 'reset', 'identity'])
    parser.add_argument('arguments', nargs='*')
    args = parser.parse_args()
    candidate = None
    candidate_tools = None
    if args.candidate:
        if args.action in ('setup', 'start', 'bootstrap', 'build-browser', 'provision', 'stop', 'reset'):
            raise SystemExit('Use vjournal-candidate.py for candidate setup and cleanup')
        candidate_tools = runpy.run_path(str(ROOT / 'vjournal-candidate.py'))
        candidate = candidate_tools['candidate_state'](args.candidate.resolve())
        RUNTIME = args.candidate.resolve() / '.runtime'
        schema = candidate_tools['verify_running_identity'](candidate)
        if schema != candidate.get('schema'):
            raise SystemExit('Running database differs from the qualified candidate schema')

    def deployment(*arguments):
        return (candidate_tools['compose_command'](candidate, *arguments)
                if candidate is not None else compose(*arguments))

    if args.action == 'identity':
        if candidate is None:
            raise SystemExit('Identity verification requires an explicit candidate')
        print(json.dumps({name: candidate[name] for name in
                          ('sourceCommit', 'imageId', 'jarSha256', 'schema', 'endpoint')}))
        return
    if args.action == 'setup':
        subprocess.run([sys.executable, str(ROOT / 'setup-busystack.py')], check=True)
    elif args.action == 'start':
        subprocess.run(compose('up', '-d', '--no-build', '--wait'), check=True)
    elif args.action == 'bootstrap':
        private = pathlib.Path((RUNTIME / 'busystack-private-directory').read_text())
        subprocess.run(compose('stop', 'application'), check=True)
        subprocess.run(compose('run', '--rm', '--no-deps', '--user', f'{os.getuid()}:{os.getgid()}',
                              '--volume', f'{private / "administrator-password"}:/bootstrap-password:ro',
                              'application', '--spring.main.web-application-type=none', '--busystack.bootstrap=true',
                              '--busystack.bootstrap-username=administrator', '--busystack.bootstrap-password-file=/bootstrap-password'), check=True)
        subprocess.run(compose('up', '-d', '--no-build', '--wait', 'application'), check=True)
    elif args.action == 'build-browser':
        subprocess.run(['docker', 'build', '-f', str(ROOT / 'browser.Dockerfile'),
                        '-t', 'busymax-caldav-browser-qa:1.61.1', str(ROOT)], check=True)
    elif args.action in ('provision', 'prepare-lifecycle', 'share', 'group-create', 'group-members', 'group-delete', 'group-share', 'issue', 'revoke', 'disable'):
        if candidate is None:
            subprocess.run(browser(args.action, *args.arguments), check=True)
        else:
            candidate_tools['browser_action'](candidate, args.action, *args.arguments)
    elif args.action == 'expire':
        lifecycle = RUNTIME / 'busystack-lifecycle-account.json'
        username = json.loads(lifecycle.read_text())['username'] if lifecycle.exists() else 'disabled'
        if args.arguments != [username] or (username != 'disabled' and not re.fullmatch(r'busymax-life-[0-9a-f]{12}', username)):
            raise SystemExit('Expiry aging is restricted to the recorded disposable lifecycle user')
        token = json.loads((RUNTIME / 'busystack-credentials.json').read_text())[username]
        credential_id = str(uuid.UUID(token.split('.')[0]))
        # Age a genuinely MFA/browser-issued credential. No credential/verifier
        # is inserted or changed, and account authentication is never bypassed.
        sql = ("UPDATE dav_credentials SET created_at=created_at-interval '2 days', "
               "expires_at=expires_at-interval '2 days' WHERE id='" + credential_id + "' "
               "AND account_id=(SELECT id FROM accounts WHERE username='" + username + "') RETURNING id;\n")
        result = subprocess.run(deployment('exec', '-T', 'database', 'sh', '-ec',
            'IFS= read -r PGPASSWORD < /run/secrets/spring.datasource.password; export PGPASSWORD; '
            'exec psql -h 127.0.0.1 -U busystack -d busystack --no-psqlrc --tuples-only --no-align --set ON_ERROR_STOP=1'),
            input=sql, text=True, check=True, capture_output=True)
        if credential_id not in result.stdout:
            raise SystemExit('Dedicated issued expiry fixture not found')
        print('Aged only the issued QA credential timestamps; verifier unchanged and secrets not printed.')
    elif args.action == 'restart':
        subprocess.run(deployment('restart', 'application'), check=True)
        if candidate is None:
            subprocess.run(deployment('up', '-d', '--no-build', '--wait', 'application'), check=True)
        else:
            candidate_tools['wait_for_readiness'](candidate)
    elif args.action == 'profile':
        if args.arguments not in [['default'], ['strict'], ['no-repair'], ['subpath']]:
            raise SystemExit('Select default, strict, no-repair or subpath QA profile')
        path = RUNTIME / 'busystack-qa.env'
        lines = [line for line in path.read_text().splitlines() if not line.startswith(('BUSYSTACK_PUBLIC_BASE_URL=', 'BUSYSTACK_ISSUER=', 'BUSYSTACK_DAV_ALLOW_SYNC_DEPTH_ONE=', 'BUSYSTACK_DAV_REPAIR_LOCAL_OBSERVANCE_UNTIL='))]
        public = 'https://localhost:18448' + ('/calendar' if args.arguments == ['subpath'] else '')
        lines.extend(['BUSYSTACK_PUBLIC_BASE_URL=' + public, 'BUSYSTACK_ISSUER=' + public])
        if args.arguments[0] in ('strict', 'no-repair'):
            lines.append('BUSYSTACK_DAV_ALLOW_SYNC_DEPTH_ONE=false')
        if args.arguments[0] == 'no-repair':
            lines.append('BUSYSTACK_DAV_REPAIR_LOCAL_OBSERVANCE_UNTIL=false')
        path.write_text('\n'.join(lines) + '\n')
        environment = dict(os.environ)
        environment.pop('BUSYSTACK_DAV_ALLOW_SYNC_DEPTH_ONE', None)
        environment.pop('BUSYSTACK_DAV_REPAIR_LOCAL_OBSERVANCE_UNTIL', None)
        wait = ['--wait'] if candidate is None else []
        subprocess.run(deployment('up', '-d', '--no-build', '--force-recreate', *wait, 'application'), check=True, env=environment)
        if candidate is not None:
            candidate_tools['wait_for_readiness'](candidate)
        subprocess.run(deployment('up', '-d', '--no-build', '--force-recreate', '--wait', 'https'), check=True, env=environment)
    elif args.action == 'stop':
        subprocess.run(compose('down'), check=True)
    elif args.action == 'reset':
        subprocess.run(compose('down', '--volumes'), check=True)
        for name in ['busystack-authenticators.json', 'busystack-credentials.json', 'busystack-credential-label.json', 'rotation-busystack.json']:
            (RUNTIME / name).unlink(missing_ok=True)
    if candidate is not None and args.action in ('profile', 'restart'):
        candidate_tools['verify_running_identity'](candidate)


if __name__ == '__main__':
    main()
