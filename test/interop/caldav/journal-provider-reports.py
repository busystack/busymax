#!/usr/bin/env python3
"""Probe journal query, expansion, and validation separately from storage."""

import argparse
import json
from pathlib import Path
import re
import runpy
from uuid import uuid4
from xml.etree import ElementTree as ET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('server_checkout', type=Path)
    parser.add_argument('fixture', type=Path)
    parser.add_argument('provider', choices=['caldav', 'nextcloud'])
    args = parser.parse_args()
    support = runpy.run_path(str(args.server_checkout / 'qualification/clients/journal-admission.py'))
    D, C, XML, ICAL = (support[name] for name in ('D', 'C', 'XML', 'ICAL'))
    config = json.loads(args.fixture.read_text())[args.provider]
    suffix = 'remote.php/dav/' if args.provider == 'nextcloud' else 'dav/'
    endpoint = config['authority'].rstrip('/') + '/' + suffix
    dav = support['Dav'](endpoint, config['username'], config['password'], config['caFile'])
    principal, = dav.properties(endpoint, '<d:current-user-principal/>').values()
    href = principal[D + 'current-user-principal'].findtext(D + 'href')
    home, = dav.properties(href, '<c:calendar-home-set/>').values()
    collection = home[C + 'calendar-home-set'].findtext(D + 'href').rstrip('/') + '/journal-reports-' + uuid4().hex + '/'
    status, _, _ = dav.request('MKCALENDAR', collection, (
        '<c:mkcalendar xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">'
        '<d:set><d:prop><c:supported-calendar-component-set><c:comp name="VJOURNAL"/>'
        '</c:supported-calendar-component-set></d:prop></d:set></c:mkcalendar>'
    ), XML)
    if status != 201:
        raise RuntimeError(f'MKCALENDAR returned {status}')
    results = []

    def record(identifier, response, observed, expected):
        passed = observed == expected
        results.append(passed)
        print(json.dumps(dict(case=identifier, status=response,
                              observed=observed, expected=expected, passed=passed)), flush=True)

    def report(identifier, expected, *, start=None, end=None, expand=None):
        time_range = f'<c:time-range start="{start}" end="{end}"/>' if start else ''
        expansion = f'<c:expand start="{expand[0]}" end="{expand[1]}"/>' if expand else ''
        payload = (
            '<c:calendar-query xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:">'
            f'<d:prop><d:getetag/><c:calendar-data>{expansion}</c:calendar-data></d:prop>'
            '<c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VJOURNAL">'
            f'{time_range}</c:comp-filter></c:comp-filter></c:filter></c:calendar-query>'
        )
        status, _, response = dav.request('REPORT', collection, payload, {**XML, 'Depth': '1'})
        observed = None
        if status == 207:
            data = {(member.findtext(D + 'href') or '').rsplit('/', 1)[-1]:
                    member.findtext(f'.//{C}calendar-data', '')
                    for member in ET.fromstring(response).findall(D + 'response')
                    if member.find(f'.//{C}calendar-data') is not None}
            if expand:
                observed = {}
                for name, value in data.items():
                    unfolded = re.sub(r'\r?\n[ \t]', '', value)
                    entries = [sorted(line for line in journal.splitlines()
                        if re.match(r'^(DTSTART|RECURRENCE-ID|DTEND|DURATION)([:;])', line))
                        for journal in re.findall(r'BEGIN:VJOURNAL.*?END:VJOURNAL', unfolded, re.S)]
                    if entries:
                        observed[name] = sorted(entries)
            else:
                observed = sorted(data)
        record(identifier, status, observed, expected if expand else sorted(expected))

    try:
        for name, fields in {
            'undated': [],
            'day': ['DTSTART;VALUE=DATE:20261126'],
            'recurring': ['DTSTART:20261125T090000Z', 'RRULE:FREQ=DAILY;COUNT=2'],
        }.items():
            body = support['representation'](name, {'journal': fields})
            status, _, _ = dav.request('PUT', collection + name + '.ics', body,
                                       {**ICAL, 'If-None-Match': '*'})
            if status != 201:
                raise RuntimeError(f'{name} fixture returned {status}')
        report('component-inventory', ['day.ics', 'recurring.ics', 'undated.ics'])
        report('recurring-future-point', ['day.ics', 'recurring.ics'],
               start='20261126T090000Z', end='20261126T090001Z')
        report('day-next-midnight-exclusive', [],
               start='20261127T000000Z', end='20261127T000001Z')
        report('calendar-data-expanded-journal', {
            'day.ics': [['DTSTART;VALUE=DATE:20261126']],
            'recurring.ics': [['DTSTART:20261126T090000Z', 'RECURRENCE-ID:20261126T090000Z']],
        },
               expand=('20261126T000000Z', '20261127T000000Z'))
        request = (
            '<d:sync-collection xmlns:d="DAV:"><d:sync-token/><d:sync-level>1</d:sync-level>'
            '<d:limit><d:nresults>100</d:nresults></d:limit><d:prop><d:getetag/></d:prop></d:sync-collection>'
        )
        status, _, _ = dav.request('REPORT', collection, request, {**XML, 'Depth': '0'})
        record('initial-sync-with-limit', status, status, 207)
        original_status, original_headers, original = dav.request('GET', collection + 'undated.ics')
        if original_status != 200:
            raise RuntimeError('Cannot establish strict write baseline')
        missing_dtstamp = original.replace(b'DTSTAMP:20261125T080000Z\r\n', b'')
        baseline_etag = original_headers.get('ETag')
        status, _, _ = dav.request(
            'PUT', collection + 'undated.ics', missing_dtstamp,
            {**ICAL, 'If-Match': baseline_etag, 'Prefer': 'handling=strict'},
        )
        read_status, read_headers, read = dav.request('GET', collection + 'undated.ics')
        record('strict-missing-dtstamp-update', status,
               status >= 400 and read_status == 200 and read == original
               and read_headers.get('ETag') == baseline_etag, True)
        malformed_new = support['representation']('repair', {'journal': []}).replace(
            b'DTSTAMP:20261125T080000Z\r\n', b'')
        status, _, _ = dav.request('PUT', collection + 'repair.ics', malformed_new,
                                   {**ICAL, 'If-None-Match': '*'})
        read_status, _, read = dav.request('GET', collection + 'repair.ics')
        print(json.dumps(dict(case='default-missing-dtstamp-create', status=status,
                              get=read_status, returned_dtstamp=b'DTSTAMP:' in read)), flush=True)
        corpus = json.loads((args.server_checkout / 'qualification/fixtures/vjournal/admission-v1.json').read_text())
        periods = [case for case in corpus['cases'] if case['id'].startswith('J15-')]
        for case in periods:
            name = case['id']
            status, _, _ = dav.request(
                'PUT', collection + name + '.ics', support['representation'](name, case),
                {**ICAL, 'If-None-Match': '*'},
            )
            record(name + '-admission-for-report', status, status, 201)
        if all(results[-len(periods):]):
            report('period-occurrence-start', [case['id'] + '.ics' for case in periods]
                   + ['day.ics', 'recurring.ics'],
                   start='20261126T090000Z', end='20261126T090001Z')
            report('period-interior-excludes-start', ['day.ics'],
                   start='20261126T100000Z', end='20261126T100001Z')
        else:
            for identifier in ('period-occurrence-start', 'period-interior-excludes-start'):
                print(json.dumps(dict(case=identifier, blocked='fixture rejected at admission')),
                      flush=True)
        vstatus = ['BEGIN:VSTATUS', 'STATUS:FINAL', 'COMMENT:Reviewed', 'END:VSTATUS']
        status, _, _ = dav.request(
            'PUT', collection + 'vstatus.ics',
            support['representation']('vstatus', {'journal': ['STATUS:FINAL', *vstatus]}),
            {**ICAL, 'If-None-Match': '*'},
        )
        read_status, _, read = dav.request('GET', collection + 'vstatus.ics')
        record('rfc10051-vstatus-readback', status, status == 201
               and read_status == 200 and '\r\n'.join(vstatus).encode() in read, True)
        detached = '\r\n'.join([
            'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//BusyMax//Detached REPORT QA//EN',
            'BEGIN:VJOURNAL', 'UID:detached-report', 'DTSTAMP:20261126T000000Z',
            'RECURRENCE-ID:20261128T090000Z', 'DTSTART:20261128T110000Z', 'END:VJOURNAL',
            'BEGIN:VJOURNAL', 'UID:detached-report', 'DTSTAMP:20261126T000000Z',
            'RECURRENCE-ID:20261129T090000Z', 'DTSTART:20261129T120000Z', 'END:VJOURNAL',
            'END:VCALENDAR', '',
        ]).encode()
        status, _, _ = dav.request('PUT', collection + 'detached.ics', detached,
                                  {**ICAL, 'If-None-Match': '*'})
        record('detached-report-storage', status, status, 201)
        if status == 201:
            report('calendar-data-expanded-detached-journal', {'detached.ics': [
                ['DTSTART:20261128T110000Z', 'RECURRENCE-ID:20261128T090000Z'],
                ['DTSTART:20261129T120000Z', 'RECURRENCE-ID:20261129T090000Z'],
            ]}, expand=('20261128T000000Z', '20261130T000000Z'))
            status, _, value = dav.request('GET', collection + 'detached.ics')
            record('calendar-data-expansion-leaves-storage-unchanged', status,
                   status == 200 and value == detached, True)
    finally:
        status, _, _ = dav.request('DELETE', collection)
        if status not in (200, 204):
            raise RuntimeError(f'Fixture cleanup failed with HTTP {status}')
    return 0 if all(results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
