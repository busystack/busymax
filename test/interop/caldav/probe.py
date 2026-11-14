#!/usr/bin/env python3
"""Independent DAV fixture provisioning/readiness (not BusyMax acceptance)."""
import argparse
import base64
import json
import pathlib
import ssl
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent
SERVERS = {'radicale': 'http://127.0.0.1:18532/', 'baikal': 'http://127.0.0.1:18580/dav.php/',
           'busystack': 'https://localhost:18448/dav/'}
NS = {'d': 'DAV:', 'c': 'urn:ietf:params:xml:ns:caldav'}
PROPS = '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><d:resourcetype/><d:displayname/><d:current-user-principal/><c:calendar-home-set/><c:supported-calendar-component-set/><d:current-user-privilege-set/><d:supported-report-set/></d:prop></d:propfind>'


def request(url, method, user='alice', body=None, headers=None, context=None):
    filename = 'busystack-credentials.json' if urllib.parse.urlsplit(url).port == 18448 else 'credentials.json'
    credentials = json.loads((ROOT / '.runtime' / filename).read_text())
    if url.startswith('https://') and context is None:
        context = ssl.create_default_context(cafile=str(ROOT / '.runtime/ca.pem'))
    authorization = base64.b64encode(f'{user}:{credentials[user]}'.encode()).decode()
    req = urllib.request.Request(url, method=method, data=body.encode() if body else None,
                                 headers={'Authorization': f'Basic {authorization}', 'Content-Type': 'application/xml', **(headers or {})})
    with urllib.request.urlopen(req, timeout=15, context=context) as response:
        return response.status, response.headers, response.read()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--provision', action='store_true')
    parser.add_argument('--https', action='store_true')
    parser.add_argument('--server', action='append', choices=list(SERVERS))
    args = parser.parse_args()
    servers = SERVERS if not args.https else {
        'radicale': 'https://localhost:18443/', 'baikal': 'https://localhost:18444/dav.php/',
        'radicale-installation': 'https://localhost:18445/installation/',
        'baikal-installation': 'https://localhost:18447/baikal/dav.php/',
        'busystack': 'https://localhost:18448/dav/'}
    if args.server:
        servers = {name: url for name, url in servers.items() if any(name == selected or name.startswith(selected + '-') for selected in args.server)}
    context = ssl.create_default_context(cafile=str(ROOT / '.runtime/ca.pem')) if args.https else None
    def authenticated(url, method, user='alice', body=None, headers=None):
        return request(url, method, user, body, headers, context)
    for name, root in servers.items():
        for user in ['alice', 'bob']:
            mixed_creation = 'not-attempted'
            status, _, data = authenticated(root, 'PROPFIND', user, PROPS, {'Depth': '0'})
            assert status == 207, (name, status)
            principal = ET.fromstring(data).find('.//d:current-user-principal/d:href', NS).text
            _, _, data = authenticated(urllib.parse.urljoin(root, principal), 'PROPFIND', user, PROPS, {'Depth': '0'})
            home = ET.fromstring(data).find('.//c:calendar-home-set/d:href', NS).text
            home = urllib.parse.urljoin(root, home)
            if args.provision and name in ('radicale', 'busystack'):
                restricted = name == 'radicale' and user == 'alice' or name == 'busystack' and user == 'bob'
                for slug, components in {'events': ['VEVENT'], 'tasks': ['VTODO'], 'mixed': ['VEVENT', 'VTODO'], **({'restricted': ['VEVENT', 'VTODO']} if restricted else {}), **({'property-locked': ['VEVENT'], 'delete-protected': ['VEVENT']} if name == 'radicale' and user == 'alice' else {})}.items():
                    if slug == 'restricted' and name == 'busystack':
                        components = ['VTODO']
                    provisioner = 'bob' if slug in ('restricted', 'property-locked', 'delete-protected') and name == 'radicale' else user
                    try:
                        authenticated(home + slug + '/', 'PROPFIND', provisioner, PROPS, {'Depth': '0'})
                        continue  # Existing fixture; creation is not claimed.
                    except urllib.error.HTTPError as e:
                        if e.code != 404:
                            raise
                    xml = '<c:mkcalendar xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:"><d:set><d:prop><d:displayname>BusyMax QA ' + slug + '</d:displayname><c:supported-calendar-component-set>' + ''.join(f'<c:comp name="{c}"/>' for c in components) + '</c:supported-calendar-component-set></d:prop></d:set></c:mkcalendar>'
                    try:
                        authenticated(home + slug + '/', 'MKCALENDAR', provisioner, xml)
                        if slug == 'mixed':
                            mixed_creation = 'created'
                    except urllib.error.HTTPError as e:
                        if slug == 'mixed' and e.code == 403:
                            error = ET.fromstring(e.read())
                            if error.find('c:supported-calendar-component', NS) is not None:
                                mixed_creation = 'rejected-component-set'
                                continue
                        if e.code not in (405, 409):
                            raise
            _, headers, _ = authenticated(home, 'OPTIONS', user)
            _, _, data = authenticated(home, 'PROPFIND', user, PROPS, {'Depth': '1'})
            collections = []
            for response in ET.fromstring(data).findall('d:response', NS):
                components = [e.attrib['name'] for e in response.findall('.//c:comp', NS)]
                if components:
                    collections.append({'href': response.find('d:href', NS).text, 'components': components,
                                        'aclAdvertised': response.find('.//d:current-user-privilege-set', NS) is not None})
            observed_components = {component for collection in collections for component in collection['components']}
            assert len(collections) >= 2 and {'VEVENT', 'VTODO'} <= observed_components, (name, user, collections)
            print(json.dumps({'server': name, 'user': user, 'status': 'authenticated DAV ready',
                              'allow': headers.get('Allow'), 'dav': headers.get('DAV'),
                              'mixedCollectionObserved': any({'VEVENT', 'VTODO'} <= set(c['components']) for c in collections),
                              'mixedCreationResult': mixed_creation,
                              'collections': collections}))


if __name__ == '__main__':
    main()
