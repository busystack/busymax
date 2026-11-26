#!/usr/bin/env python3
"""Start a disposable official Nextcloud journal fixture with private HTTPS."""

import argparse
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import ssl
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

FIXTURES = Path(__file__).resolve().parent
NEXTCLOUD = (
    'nextcloud:35.0.3-apache@'
    'sha256:f44180601f18e7664557232b4c5edb0eb4a82d649c05b93313f4e15909553d42'
)
PROXY = (
    'python:3.13.7-slim-bookworm@'
    'sha256:adafcc17694d715c905b4c7bebd96907a1fd5cf183395f0ebc4d3428bd22d92d'
)


def docker(*args, content=None, check=True):
    result = subprocess.run(
        ['docker', *args], input=content, text=True, capture_output=True, timeout=180
    )
    if check and result.returncode:
        raise RuntimeError(f'Docker operation {args[0]} failed ({result.returncode})')
    return result.stdout.strip()


def occ(project, *args, password=None, check=True):
    command = ['exec', '-i', '-u', 'www-data', project]
    if password is None:
        command += ['php', 'occ', *args]
    else:
        command += [
            'sh', '-ec', 'IFS= read -r NC_PASS; export NC_PASS; exec php occ "$@"',
            'occ', *args,
        ]
    return docker(*command, content=None if password is None else password + '\n', check=check)


def cleanup(project):
    for container in (project + '-tls', project):
        docker('rm', '--force', '--volumes', container, check=False)
    docker('network', 'rm', project, check=False)


def start(runtime):
    private = Path(tempfile.mkdtemp(prefix='busymax-vjournal-nextcloud-', dir=runtime))
    project = private.name
    script = private / 'make-certificates.sh'
    shutil.copyfile(FIXTURES / script.name, script)
    subprocess.run(['sh', script], check=True)
    tls = private / '.runtime'
    admin_file = private / 'install.env'
    admin = 'fixture-admin'
    admin_file.write_text(
        'SQLITE_DATABASE=nextcloud\n'
        f'NEXTCLOUD_ADMIN_USER={admin}\n'
        f'NEXTCLOUD_ADMIN_PASSWORD={secrets.token_hex(32)}\n'
    )
    admin_file.chmod(0o600)
    try:
        docker('network', 'create', project)
        docker('run', '-d', '--name', project, '--network', project,
               '--env-file', str(admin_file), NEXTCLOUD)
        deadline = time.monotonic() + 240
        while time.monotonic() < deadline:
            try:
                status = json.loads(occ(project, 'status', '--output=json', check=False))
                if status.get('installed') and not status.get('maintenance'):
                    break
            except json.JSONDecodeError:
                pass
            time.sleep(2)
        else:
            raise RuntimeError('Nextcloud fixture did not complete its fresh install')

        docker('run', '-d', '--name', project + '-tls', '--network', project,
               '--publish', '127.0.0.1::8443',
               '--volume', f'{FIXTURES / "https_proxy.py"}:/fixtures/https_proxy.py:ro',
               '--volume', f'{tls}:/fixtures/.runtime:ro', '--workdir', '/fixtures',
               PROXY, 'python', '-c',
               'import sys; from https_proxy import serve; '
               'serve(8443, sys.argv[1], well_known_caldav="/remote.php/dav/")',
               project + ':80')
        port = docker('port', project + '-tls', '8443/tcp').rsplit(':', 1)[1]
        authority = f'https://localhost:{port}/'
        occ(project, 'config:system:set', 'trusted_domains', '1', f'--value=localhost:{port}')
        occ(project, 'config:system:set', 'overwriteprotocol', '--value=https')
        ca_file = tls / 'ca.pem'
        context = ssl.create_default_context(cafile=str(ca_file))
        for attempt in range(30):
            try:
                with urllib.request.urlopen(authority + 'status.php', context=context, timeout=5) as response:
                    public = json.load(response)
                if public['version'] != status['version'] or not public['installed']:
                    raise RuntimeError('HTTPS endpoint is serving another Nextcloud installation')
                break
            except OSError:
                if attempt == 29:
                    raise
                time.sleep(1)

        for command in ('user:add', 'user:auth-tokens:add'):
            if '--password-from-env' not in occ(project, command, '--help'):
                raise RuntimeError(f'Unsupported fixture account command {command}')
        credentials = {}
        for role in ('owner', 'writer', 'reader', 'unrelated'):
            username = 'fixture-' + role
            password = secrets.token_hex(32)
            occ(project, 'user:add', '--password-from-env', '--no-interaction',
                username, password=password)
            result = occ(project, 'user:auth-tokens:add', '--password-from-env',
                         '--no-interaction', '--no-warnings',
                         '--name=BusyMax VJOURNAL QA', username, password=password)
            rows = [line.strip() for line in result.splitlines() if line.strip()]
            tokens = [line for label, line in zip(rows, rows[1:])
                      if label.casefold() == 'app password:']
            if len(tokens) != 1 or not re.fullmatch(r'[A-Za-z0-9-]{20,128}', tokens[0]):
                raise RuntimeError('Unrecognized Nextcloud app password response')
            token = tokens[0]
            token_file = private / (role + '-app-password')
            token_file.write_text(token + '\n')
            token_file.chmod(0o600)
            credentials[role] = dict(authority=authority, username=username,
                                     password=token, caFile=str(ca_file))
        installed = json.loads(docker('exec', project, 'cat', '/var/www/html/3rdparty/composer.lock'))
        versions = {p['name']: p['version'] for p in installed['packages']}
        image_id = docker('inspect', '--format', '{{.Image}}', project)
        identity = dict(
            project=project, directory=str(private), authority=authority,
            nextcloud=status['version'], image=NEXTCLOUD, imageId=image_id,
            php=docker('exec', project, 'php', '-r', 'echo PHP_VERSION;'),
            database=occ(project, 'config:system:get', 'dbtype'),
            sabreDav=versions['sabre/dav'], sabreVObject=versions['sabre/vobject'],
        )
        (private / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')
        config = private / 'busymax-live.json'
        config.write_text(json.dumps({'nextcloud': credentials['owner']}, indent=2) + '\n')
        config.chmod(0o600)
        print(private)
    except BaseException:
        cleanup(project)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['start', 'stop'])
    parser.add_argument('path', type=Path, help='Runtime parent for start or the named fixture for stop')
    args = parser.parse_args()
    path = args.path.resolve()
    os.umask(0o077)
    if args.action == 'start':
        start(path)
    else:
        manifest = json.loads((path / 'identity.json').read_text())
        if manifest['project'] != path.name or manifest['directory'] != str(path) or not path.name.startswith('busymax-vjournal-nextcloud-'):
            raise SystemExit('Refusing to stop a deployment unrelated to this fixture')
        cleanup(path.name)


if __name__ == '__main__':
    main()
