#!/usr/bin/env python3
"""Run an isolated BusyStack candidate using the verified image manifest."""

import argparse
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile

FIXTURES = Path(__file__).resolve().parent
PORT = 18448
PUBLIC = f'https://localhost:{PORT}'
BROWSER = 'busymax-caldav-browser-qa:1.61.1'


def capture(*args):
    return subprocess.check_output(args, text=True).strip()


def prepare(server, runtime):
    manifest = json.loads((server / 'target/image-build.json').read_text())
    if manifest['sourceCommit'] != capture('git', '-C', str(server), 'rev-parse', 'HEAD'):
        raise SystemExit('Candidate manifest does not match the server checkout')
    image = json.loads(capture('docker', 'image', 'inspect', manifest['imageId']))[0]
    if (image['Id'] != manifest['imageId'] or
            image['Config']['Labels']['org.opencontainers.image.revision'] != manifest['sourceCommit']):
        raise SystemExit('Candidate image does not match its source manifest')
    digest = capture('docker', 'run', '--rm', '--entrypoint', 'sha256sum',
                     manifest['imageId'], '/opt/busystack/application.jar').split()[0]
    if digest != manifest['jarSha256']:
        raise SystemExit('Candidate image does not contain the verified JAR')
    candidate = Path(tempfile.mkdtemp(prefix='busymax-vjournal-candidate-', dir=runtime))
    tls = candidate / '.runtime'
    tls.mkdir(mode=0o700)
    script = candidate / 'make-certificates.sh'
    shutil.copyfile(FIXTURES / script.name, script)
    subprocess.run(['sh', script], check=True)
    private = candidate / 'private'
    private.mkdir(mode=0o700)
    for name, mode in (
        ('administrator-password', 0o600), ('database-password', 0o444),
        ('postgres-admin-password', 0o444),
    ):
        path = private / name
        path.write_text(secrets.token_hex(24) + '\n')
        path.chmod(mode)
    accounts = private / 'accounts.json'
    accounts.write_text(json.dumps({name: secrets.token_hex(24)
                                   for name in ['alice', 'bob', 'disabled']}))
    accounts.chmod(0o600)
    env = {
        'BUSYSTACK_APPLICATION_IMAGE': manifest['image'],
        'BUSYSTACK_BUILD_CONTEXT': str(server),
        'BUSYSTACK_BUILD_VERSION': manifest['version'],
        'BUSYSTACK_SOURCE_REVISION': manifest['sourceCommit'],
        'BUSYSTACK_PUBLIC_BASE_URL': PUBLIC,
        'BUSYSTACK_ISSUER': PUBLIC,
        'BUSYSTACK_DATABASE_PASSWORD_FILE': str(private / 'database-password'),
        'BUSYSTACK_POSTGRES_ADMIN_PASSWORD_FILE': str(private / 'postgres-admin-password'),
    }
    (tls / 'busystack-qa.env').write_text(''.join(f'{k}={v}\n' for k, v in env.items()))
    overlay = {
        'services': {
            'application': {'image': manifest['imageId'], 'ports': []},
            'https': {
                'image': 'python:3.13.7-slim-bookworm@sha256:adafcc17694d715c905b4c7bebd96907a1fd5cf183395f0ebc4d3428bd22d92d',
                'command': ['python', '-c', f'from https_proxy import serve; serve({PORT}, "application:8080")'],
                'working_dir': '/fixtures',
                'ports': [f'127.0.0.1:{PORT}:{PORT}'],
                'volumes': [f'{FIXTURES}/https_proxy.py:/fixtures/https_proxy.py:ro',
                            f'{tls}:/fixtures/.runtime:ro'],
            },
        },
    }
    # docker compose accepts JSON as YAML. !reset removes the deployment's
    # direct HTTP port from this isolated TLS-only fixture.
    (candidate / 'compose.json').write_text(json.dumps(overlay))
    (candidate / 'compose-no-http.yaml').write_text('services:\n  application:\n    ports: !reset []\n')
    state = {
        **manifest, 'server': str(server), 'project': 'busymax-vjournal-' + secrets.token_hex(6),
        'endpoint': PUBLIC + '/dav/', 'candidate': str(candidate),
    }
    (candidate / 'candidate.json').write_text(json.dumps(state, indent=2) + '\n')
    return candidate


def compose(state, *args, **kwargs):
    candidate = Path(state['candidate'])
    return subprocess.run(
        ['docker', 'compose', '-p', state['project'], '--env-file',
         str(candidate / '.runtime/busystack-qa.env'),
         '-f', str(Path(state['server']) / 'compose.yaml'),
         '-f', str(candidate / 'compose.json'),
         '-f', str(candidate / 'compose-no-http.yaml'), *args],
        check=True, **kwargs,
    )


def start(candidate):
    state = json.loads((candidate / 'candidate.json').read_text())
    private = candidate / 'private'
    tls = candidate / '.runtime'
    compose(state, 'up', '-d', '--no-build', '--wait')
    compose(state, 'stop', 'application')
    compose(state, 'run', '--rm', '--no-deps', '--user', f'{private.stat().st_uid}:{private.stat().st_gid}',
            '--volume', f'{private / "administrator-password"}:/bootstrap-password:ro',
            'application', '--spring.main.web-application-type=none', '--busystack.bootstrap=true',
            '--busystack.bootstrap-username=administrator',
            '--busystack.bootstrap-password-file=/bootstrap-password')
    compose(state, 'up', '-d', '--no-build', '--wait', 'application')
    verified = capture('docker', 'ps', '--filter', f'label=com.docker.compose.project={state["project"]}',
                       '--filter', 'label=com.docker.compose.service=application', '--format', '{{.ID}}')
    if capture('docker', 'inspect', '--format', '{{.Image}}', verified) != state['imageId']:
        raise RuntimeError('Running application image differs from the verified image')
    running_sha = compose(
        state, 'exec', '-T', 'application', 'sha256sum', '/opt/busystack/application.jar',
        stdout=subprocess.PIPE, text=True,
    ).stdout.split()[0]
    if running_sha != state['jarSha256']:
        raise RuntimeError('Running application JAR differs from the verified JAR')
    schema = subprocess.run(
        ['docker', 'exec', '-i', capture('docker', 'ps', '--filter',
         f'label=com.docker.compose.project={state["project"]}', '--filter',
         'label=com.docker.compose.service=database', '--format', '{{.ID}}'),
         'sh', '-ec', 'export PGPASSWORD="$(cat /run/secrets/spring.datasource.password)"; '
         'exec psql -h 127.0.0.1 -U busystack -d busystack -Atq'],
        input="select max(version::integer) from flyway_schema_history where success;\n",
        text=True, check=True, capture_output=True,
    ).stdout.strip()
    if schema != '17':
        raise RuntimeError(f'Unexpected candidate schema: {schema}')
    state['schema'] = int(schema)
    (candidate / 'candidate.json').write_text(json.dumps(state, indent=2) + '\n')
    print(json.dumps({key: state[key] for key in ('sourceCommit', 'imageId', 'schema', 'endpoint')}))


def provision(candidate):
    state = json.loads((candidate / 'candidate.json').read_text())
    private = candidate / 'private'
    tls = candidate / '.runtime'
    helpers = Path(state['server']) / 'qualification/passkeys'
    script = FIXTURES / 'browser/vjournal-candidate.mjs'
    subprocess.run([
        'docker', 'run', '--rm', '--network', 'host', '--shm-size', '256m',
        '-v', f'{helpers}:/qa/server-qualification:ro',
        '-v', f'{script}:/qa/vjournal-candidate.mjs:ro',
        '-v', f'{tls}:/fixture', '-v', f'{private}:/private:ro',
        '--entrypoint', '/bin/sh', BROWSER, '-ec',
        'export HOME=/tmp/journal-browser NODE_EXTRA_CA_CERTS=/fixture/ca.pem; '
        'mkdir -p "$HOME/.pki/nssdb"; '
        'certutil -N --empty-password -d "sql:$HOME/.pki/nssdb"; '
        'certutil -A -d "sql:$HOME/.pki/nssdb" -n journal-qa -t "C,," -i /fixture/ca.pem; '
        'exec node /qa/vjournal-candidate.mjs',
    ], check=True)
    credentials = tls / 'busystack-credentials.json'
    subprocess.run([
        'docker', 'run', '--rm', '--user', '0', '-v', f'{tls}:/fixture',
        '--entrypoint', 'chown', BROWSER,
        f'{tls.stat().st_uid}:{tls.stat().st_gid}', '/fixture/busystack-credentials.json',
    ], check=True)
    if not credentials.is_file():
        raise RuntimeError('Candidate credentials were not written')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare', 'start', 'provision', 'stop'])
    parser.add_argument('path', type=Path, help='Server checkout for prepare, candidate directory otherwise')
    parser.add_argument('--runtime', type=Path, default=Path(tempfile.gettempdir()))
    args = parser.parse_args()
    path = args.path.resolve()
    if args.action == 'prepare':
        print(prepare(path, args.runtime.resolve()))
    elif args.action == 'start':
        start(path)
    elif args.action == 'provision':
        provision(path)
    else:
        state = json.loads((path / 'candidate.json').read_text())
        if not state['project'].startswith('busymax-vjournal-') or state['candidate'] != str(path):
            raise SystemExit('Refusing to stop a deployment unrelated to this fixture')
        compose(state, 'down', '--volumes')


if __name__ == '__main__':
    main()
