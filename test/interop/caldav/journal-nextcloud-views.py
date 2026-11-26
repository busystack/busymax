#!/usr/bin/env python3
"""Verify stock Nextcloud journal views with the fixture's disposable accounts."""

import argparse
import json
from pathlib import Path
import runpy
from uuid import uuid4
from xml.sax.saxutils import escape


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('server_checkout', type=Path)
    parser.add_argument('fixture_directory', type=Path)
    args = parser.parse_args()
    support = runpy.run_path(str(args.server_checkout / 'qualification/clients/journal-admission.py'))
    D, C, XML, ICAL = (support[name] for name in ('D', 'C', 'XML', 'ICAL'))
    identity = json.loads((args.fixture_directory / 'identity.json').read_text())
    endpoint = identity['authority'] + 'remote.php/dav/'
    profile = json.loads((args.fixture_directory / 'busymax-live.json').read_text())['nextcloud']
    roles = {role: support['Dav'](
        endpoint, 'fixture-' + role,
        (args.fixture_directory / (role + '-app-password')).read_text().strip(),
        profile['caFile'],
    ) for role in ('owner', 'writer', 'reader', 'unrelated')}

    def home(dav):
        principal, = dav.properties(endpoint, '<d:current-user-principal/>').values()
        href = principal[D + 'current-user-principal'].findtext(D + 'href')
        props, = dav.properties(href, '<c:calendar-home-set/>').values()
        return props[C + 'calendar-home-set'].findtext(D + 'href')

    label = 'journal-view-' + uuid4().hex
    owner = roles['owner']
    collection = home(owner).rstrip('/') + '/' + label + '/'
    status, _, _ = owner.request('MKCALENDAR', collection, (
        '<c:mkcalendar xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">'
        f'<d:set><d:prop><d:displayname>{label}</d:displayname>'
        '<c:supported-calendar-component-set><c:comp name="VJOURNAL"/>'
        '</c:supported-calendar-component-set></d:prop></d:set></c:mkcalendar>'
    ), XML)
    assert status == 201, status

    def mount(role):
        dav = roles[role]
        mounts = [href for href, props in
                  dav.properties(home(dav), '<d:displayname/>', depth=1).items()
                  if props.get(D + 'displayname') is not None
                  and (props[D + 'displayname'].text or '').startswith(label)]
        assert len(mounts) <= 1, 'The unique fixture label matched multiple mounts.'
        return mounts[0] if mounts else None

    def share(role, access):
        href = escape('principal:principals/users/fixture-' + role)
        action = 'remove' if access == 'none' else 'set'
        status, _, _ = owner.request('POST', collection, (
            '<oc:share xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">'
            f'<oc:{action}><d:href>{href}</d:href>'
            + ('<oc:read-write/>' if access == 'write' else '')
            + f'</oc:{action}></oc:share>'
        ), XML)
        assert status == 200, status

    def record(case):
        print(json.dumps(dict(provider=identity['nextcloud'], case=case, passed=True)), flush=True)

    try:
        for role, access in [('writer', 'write'), ('reader', 'read')]:
            share(role, access)
        writer, reader = mount('writer'), mount('reader')
        assert writer and reader and mount('unrelated') is None
        for classification in ('PUBLIC', 'PRIVATE', 'CONFIDENTIAL'):
            raw = support['representation'](label + '-' + classification, {
                'journal': ['CLASS:' + classification, 'DESCRIPTION:Fixture body',
                            'DTSTART:20261126T090000Z'],
            }, summary='Fixture title')
            member = classification.lower() + '.ics'
            status, _, _ = owner.request('PUT', collection + member, raw,
                                        {**ICAL, 'If-None-Match': '*'})
            assert status == 201, status
            status, headers, body = owner.request('GET', collection + member)
            assert status == 200 and raw == body
            assert roles['unrelated'].request('GET', collection + member)[0] in (403, 404)
            responses = [roles[role].request('GET', href + member)
                         for role, href in [('writer', writer), ('reader', reader)]]
            if classification == 'PRIVATE':
                assert all(response[0] in (403, 404) for response in responses)
            else:
                assert all(response[0] == 200 for response in responses)
                full, limited = [response[2] for response in responses]
                assert b'DESCRIPTION:Fixture body' in full and b'DTSTAMP:' in full
                if classification == 'CONFIDENTIAL':
                    assert b'BEGIN:VJOURNAL' in limited and b'DTSTART:' in limited
                    assert b'DESCRIPTION:' not in limited and b'DTSTAMP:' not in limited
                    assert b'SUMMARY:Fixture title' not in limited
                    share('reader', 'write')
                    upgraded = roles['reader'].request('GET', mount('reader') + member)
                    assert upgraded[0] == 200 and b'DESCRIPTION:Fixture body' in upgraded[2]
                    assert b'DTSTAMP:' in upgraded[2]
                    record('journal-confidential-privilege-upgrade')
                    share('writer', 'read')
                    downgrade = roles['writer'].request(
                        'PUT', mount('writer') + member, raw,
                        {**ICAL, 'If-Match': responses[0][1]['ETag']},
                    )
                    assert downgrade[0] in (403, 404), downgrade[0]
                    status, after, body = owner.request('GET', collection + member)
                    assert status == 200 and body == raw and after['ETag'] == headers['ETag']
                    record('journal-downgraded-writer-denied-unchanged-owner-resource')
            record('journal-' + classification.lower() + '-permission-views')
    finally:
        status, _, _ = owner.request('DELETE', collection)
        assert status in (200, 204), status
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
