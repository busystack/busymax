import 'dart:io';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/xml/dav_xml.dart';
import 'package:busymax/src/dav/storage/dav_collection_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/caldav_fixture.dart';

void main() {
  final enabled = Platform.environment['BUSYMAX_CALDAV_LIVE'] == '1';
  test('Radicale 3.9.0: conditional PUT, zero-offset VALARM and VTODO time filtering', () async {
    final f = CalDavFixture(Uri.parse('https://localhost:18443/'));
    await f.open();
    try {
      final base = f.createdCollectionUri!;
      const alarm =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\n'
          'BEGIN:VEVENT\r\nUID:zero-alarm@example.test\r\nDTSTAMP:20261102T000000Z\r\n'
          'DTSTART:20261102T120000Z\r\nDTEND:20261102T130000Z\r\nSUMMARY:Zero alarm\r\n'
          'BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:PT0S\r\nDESCRIPTION:At start\r\nEND:VALARM\r\n'
          'END:VEVENT\r\nEND:VCALENDAR\r\n';
      final target = base.resolve('zero.ics');
      expect(
        (await f.independentRequest(
          'PUT',
          target,
          body: alarm,
          headers: const {
            'content-type': 'text/calendar',
            'if-none-match': '*',
          },
        )).statusCode,
        201,
      );
      expect(
        (await f.independentRequest(
          'PUT',
          target,
          body: alarm.replaceFirst('Zero alarm', 'Conditional alarm'),
          headers: const {'content-type': 'text/calendar', 'if-match': '*'},
        )).statusCode,
        204,
      );
      expect(
        (await f.independentRequest(
          'PUT',
          base.resolve('missing.ics'),
          body: alarm,
          headers: const {'content-type': 'text/calendar', 'if-match': '*'},
        )).statusCode,
        412,
      );
      for (final component in ['VEVENT', 'VTODO']) {
        if (component == 'VTODO') {
          expect(
            (await f.independentRequest(
              'PUT',
              base.resolve('todo.ics'),
              body:
                  'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\n'
                  'BEGIN:VTODO\r\nUID:filtered-todo@example.test\r\nDTSTAMP:20261102T000000Z\r\n'
                  'DTSTART:20261102T120000Z\r\nDUE:20261102T130000Z\r\nSUMMARY:Filtered task\r\nEND:VTODO\r\nEND:VCALENDAR\r\n',
              headers: const {
                'content-type': 'text/calendar',
                'if-none-match': '*',
              },
            )).statusCode,
            201,
          );
        }
        for (final overlaps in [true, false]) {
          final day = overlaps ? '02' : '05';
          final range =
              '<c:time-range start="202611${day}T115900Z" end="202611${day}T120100Z"/>';
          final filter = component == 'VEVENT'
              ? '<c:comp-filter name="VEVENT"><c:comp-filter name="VALARM">$range</c:comp-filter></c:comp-filter>'
              : '<c:comp-filter name="VTODO">$range</c:comp-filter>';
          final response = await f.independentRequest(
            'REPORT',
            base,
            headers: const {'Depth': '1'},
            body:
                '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
                '<d:prop><d:getetag/></d:prop><c:filter><c:comp-filter name="VCALENDAR">$filter</c:comp-filter></c:filter></c:calendar-query>',
          );
          expect(response.statusCode, 207);
          final hrefs = XmlDocument.parse(response.body)
              .findAllElements('response', namespaceUri: 'DAV:');
          expect(
            hrefs.length,
            overlaps ? 1 : 0,
            reason: '$component time-range filtering',
          );
        }
      }
      await f.synchronize();
      expect(
        (await f.database.select(f.database.calendarEvents).get()).any(
          (e) => e.title == 'Conditional alarm',
        ),
        isTrue,
      );
      expect(
        (await f.database.select(f.database.tasks).get()).any(
          (t) => t.title == 'Filtered task',
        ),
        isTrue,
      );
    } finally {
      await f.close();
    }
  }, skip: enabled ? false : 'Requires Radicale 3.9.0 release fixture.');

  test(
    'Radicale 3.9.0: inconsistent locked-property ACL and deletion denials are handled without data loss',
    () async {
      final f = CalDavFixture(Uri.parse('https://localhost:18443/'));
      await f.open();
      try {
        final locked =
            (await f.database.select(f.database.davCollections).get())
                .singleWhere((c) => c.hrefKey.endsWith('/property-locked/'));
        final caps = collectionCapabilitiesFromStored(locked);
        expect(caps.canWriteContent, isTrue);
        // Upstream advertises DAV:all/write even with its l property lock.
        // RFC 3744 aggregates those privileges. BusyMax must honor the actual
        // server rejection rather than adding a brand-specific ACL exception.
        expect(caps.canWriteProperties, isTrue);
        expect(locked.currentUserPrivilegesJson, contains('{DAV:}all'));
        await expectLater(
          f.administration.update(locked.id, {
            const DavPropertyName(davNamespace, 'displayname'):
                'Must not rename',
          }),
          throwsA(isA<DavException>()),
        );
        final raw = await f.independentRequest(
          'PROPPATCH',
          Uri.parse(locked.requestUri),
          body: '<d:propertyupdate xmlns:d="DAV:"><d:set><d:prop><d:displayname>Must not rename</d:displayname></d:prop></d:set></d:propertyupdate>',
        );
        expect(raw.statusCode, 403);
        expect(
          (await f.database.select(f.database.davCollections).get())
              .singleWhere((c) => c.id == locked.id)
              .displayName,
          'BusyMax QA property-locked',
        );
        final protected =
            (await f.database.select(f.database.davCollections).get())
                .singleWhere((c) => c.hrefKey.endsWith('/delete-protected/'));
        await expectLater(
          f.administration.remove(protected.id),
          throwsA(isA<DavException>()),
        );
        expect(
          (await f.independentRequest(
            'PROPFIND',
            Uri.parse(protected.requestUri),
            headers: const {'Depth': '0'},
          )).statusCode,
          207,
        );
        expect(
          (await f.database.select(f.database.davCollections).get())
              .singleWhere((c) => c.id == protected.id)
              .deleted,
          isFalse,
        );
      } finally {
        await f.close();
      }
    },
    skip: enabled ? false : 'Requires provisioned locked/deletion-protected Radicale collections.',
  );
}
