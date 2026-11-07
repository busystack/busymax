import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dart:io';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/xml/dav_xml.dart';
import 'package:busymax/src/dav/storage/dav_collection_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/caldav_fixture.dart';
import 'support/caldav_qa_targets.dart';

void main() {
  final enabled = Platform.environment['BUSYMAX_CALDAV_LIVE'] == '1';
  for (final server in calDavQaTargets.entries) {
    test(
      '${server.key}: gateway DELETE 207 retains collection and reconciles actually removed child',
      () async {
        final fault = _PartialDeleteFault();
        final f = CalDavFixture(
          Uri.parse(server.value),
          wrapAccountClient: (client) => _PartialDeleteGateway(client, fault),
        );
        await f.open();
        addTearDown(f.close);
        fault.collection = f.createdCollectionUri!;
        fault.removed = fault.collection!.resolve('removed.ics');
        fault.locked = fault.collection!.resolve('locked.ics');
        final marker = DateTime.now().microsecondsSinceEpoch;
        for (final name in ['removed', 'locked']) {
          final raw =
              'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VTODO\r\nUID:partial-$name-$marker@example.invalid\r\nDTSTAMP:20261107T000000Z\r\nSUMMARY:Partial $name\r\nEND:VTODO\r\nEND:VCALENDAR\r\n';
          expect(
            (await f.independentRequest(
              'PUT',
              fault.collection!.resolve('$name.ics'),
              body: raw,
              headers: const {
                'content-type': 'text/calendar',
                'if-none-match': '*',
              },
            )).statusCode,
            201,
          );
        }
        await f.synchronize(full: true);
        expect(
          (await f.database.select(f.database.davObjects).get()).where(
            (r) => r.collectionId == f.collectionId,
          ),
          hasLength(2),
        );
        await expectLater(
          f.administration.remove(f.collectionId!),
          throwsA(
            isA<DavException>().having(
              (e) => e.code,
              'partial deletion',
              'DavCollectionRemovalPartial',
            ),
          ),
        );
        expect(fault.calls, 1);
        expect(
          (await f.database.select(f.database.davCollections).get())
              .singleWhere((r) => r.id == f.collectionId)
              .deleted,
          isFalse,
        );
        final objects = (await f.database.select(f.database.davObjects).get())
            .where((r) => r.collectionId == f.collectionId)
            .toList();
        expect(objects.where((r) => !r.serverDeleted), hasLength(1));
        expect(
          objects.singleWhere((r) => !r.serverDeleted).requestUri,
          fault.locked.toString(),
        );
        expect(
          objects
              .singleWhere((r) => r.requestUri == fault.removed.toString())
              .serverDeleted,
          isTrue,
        );
        expect(
          (await f.database.select(f.database.tasks).get()).where(
            (r) => r.title == 'Partial removed',
          ),
          isEmpty,
        );
        expect(
          (await f.database.select(f.database.tasks).get()).where(
            (r) => r.title == 'Partial locked',
          ),
          hasLength(1),
        );
        expect(
          (await f.independentRequest('GET', fault.removed!)).statusCode,
          404,
        );
        expect(
          (await f.independentRequest('GET', fault.locked!)).statusCode,
          200,
        );
        expect(
          (await f.independentRequest(
            'PROPFIND',
            fault.collection!,
            headers: const {'Depth': '0'},
          )).statusCode,
          207,
        );
        await f.reopen();
        expect(
          (await f.database.select(f.database.davCollections).get())
              .singleWhere((r) => r.id == f.collectionId)
              .deleted,
          isFalse,
        );
        await f.synchronize(full: true);
        expect(
          fault.calls,
          1,
          reason: 'refresh/restart never repeats the destructive request',
        );
      },
      skip: enabled ? false : 'Requires pinned HTTPS fixtures; 207/423 is injected by the gateway, not emitted by the server.',
    );
  }

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

final class _PartialDeleteFault {
  Uri? collection, removed, locked;
  int calls = 0;
}

/// Fault gateway, not a claim that the upstream emits DELETE multistatus.
/// One child is really deleted upstream; the collection DELETE is intercepted.
final class _PartialDeleteGateway extends http.BaseClient {
  _PartialDeleteGateway(this.delegate, this.fault);
  final http.Client delegate;
  final _PartialDeleteFault fault;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'DELETE' && request.url == fault.collection) {
      fault.calls++;
      final removed = http.Request('DELETE', fault.removed!)
        ..headers.addAll(request.headers);
      final result = await delegate.send(removed);
      await result.stream.drain<void>();
      expect(result.statusCode, anyOf(200, 204));
      final body =
          '<d:multistatus xmlns:d="DAV:"><d:response><d:href>${fault.locked!.path}</d:href><d:status>HTTP/1.1 423 Locked</d:status></d:response></d:multistatus>';
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        207,
        request: request,
        headers: const {'content-type': 'application/xml'},
      );
    }
    return delegate.send(request);
  }

  @override
  void close() => delegate.close();
}
