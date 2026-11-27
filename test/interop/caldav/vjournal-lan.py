#!/usr/bin/env python3
"""Serve an additional trusted HTTPS endpoint on the isolated QA LAN."""

import argparse
import ipaddress
import json
import os
from pathlib import Path
import runpy
import ssl
import subprocess
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlsplit

import https_proxy


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixture', type=Path)
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
    official['occ'](nextcloud.name, 'config:system:set', 'trusted_domains', '2',
                    f'--value={address}:{args.nextcloud_port}')
    relay_profile = {}
    with ThreadPoolExecutor(max_workers=2) as group:
        running = []
        for provider, origin, port, dav in zip(
                ('caldav', 'nextcloud'), authorities, ports, ('/dav/', '/remote.php/dav/')):
            profile = profiles[provider]
            upstream_ca = ssl.create_default_context(cafile=profile['caFile'])
            relay_profile[provider] = dict(profile, authority=f'https://{address}:{port}/',
                                           caFile=str(runtime / 'ca.pem'))
            running.append(group.submit(https_proxy.serve, port, origin.netloc,
                                        well_known_caldav=dav, listen=str(address),
                                        upstream_tls=upstream_ca))
        (runtime / 'busymax-live.json').write_text(json.dumps(relay_profile) + '\n')
        for relay in running:
            relay.result()


if __name__ == '__main__':
    main()
