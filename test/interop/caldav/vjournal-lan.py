#!/usr/bin/env python3
"""Serve an additional trusted HTTPS endpoint on the isolated QA LAN."""

import argparse
import ipaddress
import json
import os
from pathlib import Path
import runpy
import signal
import ssl
import subprocess
import threading
from urllib.parse import urlsplit

import https_proxy


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixture', type=Path)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('nextcloud', type=Path)
    parser.add_argument('runtime', type=Path, help='New private directory')
    parser.add_argument('--address', type=ipaddress.IPv4Address, required=True)
    parser.add_argument('--caldav-port', type=int, required=True)
    parser.add_argument('--nextcloud-port', type=int, required=True)
    args = parser.parse_args()
    address = args.address
    ports = args.caldav_port, args.nextcloud_port
    if (not address.is_private or address.is_loopback or address.is_unspecified
            or address.is_multicast or address.is_reserved
            or ports[0] == ports[1] or any(not 1024 <= port <= 65535 for port in ports)):
        parser.error('Supply a routed private IPv4 address and two distinct QA ports.')
    os.umask(0o077)
    if args.fixture.stat().st_mode & 0o077:
        parser.error('The source profile must be private.')
    profiles = json.loads(args.fixture.read_text())
    authorities = [urlsplit(profiles[provider]['authority'])
                   for provider in ('caldav', 'nextcloud')]
    if any(uri.scheme != 'https' or uri.hostname != 'localhost' or uri.port is None
           for uri in authorities):
        parser.error('Use the dedicated localhost BusyStack and Nextcloud fixtures.')
    nextcloud = args.nextcloud.resolve()
    candidate = runpy.run_path(str(Path(__file__).with_name('vjournal-candidate.py')))
    state = candidate['candidate_state'](args.candidate.resolve())
    if (state['endpoint'] != profiles['caldav']['authority'] + 'dav/'
            or candidate['verify_running_identity'](state) != state['schema']):
        parser.error('The CalDAV profile must identify the verified disposable candidate.')
    identity = json.loads((nextcloud / 'identity.json').read_text())
    official = runpy.run_path(str(Path(__file__).with_name('vjournal-nextcloud.py')))
    if (identity['directory'] != str(nextcloud) or identity['project'] != nextcloud.name
            or not nextcloud.name.startswith('busymax-vjournal-nextcloud-')
            or identity['authority'] != profiles['nextcloud']['authority']
            or identity['image'] != official['NEXTCLOUD']
            or identity['imageId'] != official['docker'](
                'inspect', '--format', '{{.Image}}', nextcloud.name)):
        parser.error('The Nextcloud profile must identify the running official disposable fixture.')

    runtime = args.runtime.resolve()
    runtime.mkdir(mode=0o700)
    https_proxy.RUNTIME = runtime
    subprocess.run([
        'openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '7',
        '-subj', '/CN=BusyMax disposable LAN QA CA', '-addext',
        'basicConstraints=critical,CA:TRUE', '-addext',
        'keyUsage=critical,keyCertSign,cRLSign', '-addext', 'subjectKeyIdentifier=hash',
        '-keyout', 'ca.key', '-out', 'ca.pem',
    ], cwd=runtime, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run([
        'openssl', 'req', '-newkey', 'rsa:2048', '-nodes',
        '-subj', f'/CN={address}', '-keyout', 'server.key', '-out', 'server.csr',
    ], cwd=runtime, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    (runtime / 'server.ext').write_text(
        f'basicConstraints=critical,CA:FALSE\nsubjectAltName=IP:{address}\n'
        'keyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\n'
        'authorityKeyIdentifier=keyid,issuer\n')
    subprocess.run([
        'openssl', 'x509', '-req', '-days', '7', '-in', 'server.csr', '-CA', 'ca.pem',
        '-CAkey', 'ca.key', '-CAcreateserial', '-extfile', 'server.ext', '-out', 'server.pem',
    ], cwd=runtime, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    trusted_domain = f'{address}:{args.nextcloud_port}'
    trusted_domains = json.loads(official['occ'](
        nextcloud.name, 'config:list', 'system', '--output=json'))['system']['trusted_domains']
    domains = (dict(enumerate(trusted_domains)) if isinstance(trusted_domains, list)
               else {int(key): value for key, value in trusted_domains.items()})
    if trusted_domain in domains.values():
        trust_key = None
    else:
        trust_key = str(max(domains, default=-1) + 1)
    settings_file = args.candidate / '.runtime/busystack-qa.env'
    ordinary_settings = settings_file.read_text()
    lan_origin = f'https://{address}:{args.caldav_port}'
    lan_settings = ''.join(
        f'{line.split("=", 1)[0]}={lan_origin}\n'
        if line.startswith(('BUSYSTACK_PUBLIC_BASE_URL=', 'BUSYSTACK_ISSUER='))
        else line
        for line in ordinary_settings.splitlines(keepends=True)
    )
    stop = threading.Event()
    for event in (signal.SIGINT, signal.SIGTERM):
        signal.signal(event, lambda _signum, _frame: stop.set())
    relay_profile = {}
    servers = []
    threads = []
    trust_added = False
    try:
        if trust_key is not None:
            official['occ'](nextcloud.name, 'config:system:set', 'trusted_domains', trust_key,
                            f'--value={trusted_domain}')
            trust_added = True
        for provider, origin, port, dav in zip(
                ('caldav', 'nextcloud'), authorities, ports, ('/dav/', '/remote.php/dav/')):
            profile = profiles[provider]
            upstream_ca = ssl.create_default_context(cafile=profile['caFile'])
            relay_profile[provider] = dict(profile, authority=f'https://{address}:{port}/',
                                           caFile=str(runtime / 'ca.pem'))
            servers.append(https_proxy.create_server(
                port, origin.netloc, well_known_caldav=dav, listen=str(address),
                upstream_tls=upstream_ca))
        settings_file.write_text(lan_settings)
        candidate['compose'](state, 'up', '-d', '--no-build', '--wait',
                             '--wait-timeout', '240', 'application')
        candidate['verify_running_identity'](state)
        for server in servers:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            threads.append(thread)
        (runtime / 'busymax-live.json').write_text(json.dumps(relay_profile) + '\n')
        stop.wait()
    finally:
        for server in servers[:len(threads)]:
            server.shutdown()
        for server in servers:
            server.server_close()
        try:
            if settings_file.read_text() == lan_settings:
                settings_file.write_text(ordinary_settings)
                candidate['compose'](state, 'up', '-d', '--no-build', '--wait',
                                     '--wait-timeout', '240', 'application')
                candidate['verify_running_identity'](state)
        finally:
            if (trust_added and official['occ'](
                    nextcloud.name, 'config:system:get', 'trusted_domains', trust_key) == trusted_domain):
                official['occ'](nextcloud.name, 'config:system:delete', 'trusted_domains', trust_key)


if __name__ == '__main__':
    main()
