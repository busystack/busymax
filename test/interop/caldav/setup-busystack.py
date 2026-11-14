#!/usr/bin/env python3
"""Verify/extract the official deployment bundle; prepare private QA inputs."""
import hashlib
import json
import os
import pathlib
import secrets
import tarfile
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent
RUNTIME = ROOT / '.runtime'
ASSETS = {
    'caldav-server-0.1.0-deploy.tar.gz': '615c703ef94b21393a3e1ca2c2a1209c90d5f2716d302e1f3e664635a58f04b4',
    'release-manifest.json': '24f5e02bee838021ee67f66f0c95e908247e112480ffaee8c5562ac6ada50a77',
    'SHA256SUMS': 'f5ba940da14ce47657443e2636a9037c042fdebe3ec439a5417c9bb3ad43afb9',
}


def main():
    assets = RUNTIME / 'busystack-release'
    assets.mkdir(parents=True, exist_ok=True)
    for name, digest in ASSETS.items():
        path = assets / name
        if not path.exists():
            urllib.request.urlretrieve('https://github.com/busystack/caldav-server/releases/download/v0.1.0/' + name, path)
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise SystemExit('Official release asset checksum mismatch: ' + name)
    manifest = json.loads((assets / 'release-manifest.json').read_text())
    if manifest['sourceCommit'] != 'db302ec69f786ba89945e1a761734a844572145b':
        raise SystemExit('Unexpected release source')
    with tarfile.open(assets / 'caldav-server-0.1.0-deploy.tar.gz') as archive:
        archive.extractall(assets, filter='data')
    deployment = assets / 'caldav-server-0.1.0-deploy'
    for name, digest in manifest['deploymentFiles'].items():
        if hashlib.sha256((deployment / name).read_bytes()).hexdigest() != digest:
            raise SystemExit('Unmodified deployment file verification failed: ' + name)
    pointer = RUNTIME / 'busystack-private-directory'
    if not pointer.exists():
        directory = pathlib.Path(tempfile.mkdtemp(prefix='busymax-caldav-private-'))
        pointer.write_text(str(directory))
        pointer.chmod(0o600)
    private = pathlib.Path(pointer.read_text())
    private.mkdir(mode=0o700, exist_ok=True)
    accounts = private / 'accounts.json'
    if not accounts.exists():
        accounts.write_text(json.dumps({name: secrets.token_hex(24) for name in ['alice', 'bob', 'disabled']}))
        accounts.chmod(0o600)
    for name, mode in [('database-password', 0o444), ('postgres-admin-password', 0o444), ('administrator-password', 0o600)]:
        path = private / name
        if not path.exists():
            descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            with os.fdopen(descriptor, 'w') as stream:
                stream.write(secrets.token_hex(24) + '\n')
            path.chmod(mode)
    values = {
        'BUSYSTACK_DATABASE_PASSWORD_FILE': private / 'database-password',
        'BUSYSTACK_POSTGRES_ADMIN_PASSWORD_FILE': private / 'postgres-admin-password',
        'BUSYSTACK_PUBLIC_BASE_URL': 'https://localhost:18448',
        'BUSYSTACK_ISSUER': 'https://localhost:18448',
        'BUSYSTACK_HTTP_PORT': 18581,
        'BUSYMAX_CALDAV_FIXTURES': ROOT,
    }
    env = RUNTIME / 'busystack-qa.env'
    env.write_text(''.join(f'{name}={value}\n' for name, value in values.items()))
    env.chmod(0o600)
    print('Official BusyStack v0.1.0 bundle and every deployment file verified. Private QA inputs prepared; secrets not printed.')


if __name__ == '__main__':
    main()
