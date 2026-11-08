import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('production multiget accepts UTF-16 DAV XML', () async {
    final authority = Uri.parse('https://cal.example.test/');
    final profile = davProviderProfile(
      BusyProvider.caldav,
      caldavServer: authority,
    );
    const xml =
        '<?xml version="1.0" encoding="UTF-16"?>'
        '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
        '<d:response><d:href>a.ics</d:href><d:propstat><d:prop><d:getetag>"v1"</d:getetag>'
        '<c:calendar-data>Café 😀</c:calendar-data></d:prop>'
        '<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>';
    final client = MockClient(
      (request) async => http.Response.bytes(
        [
          255,
          254,
          for (final u in xml.codeUnits) ...[u & 255, u >> 8],
        ],
        207,
        headers: {'content-type': 'application/xml; charset=utf-16'},
      ),
    );
    addTearDown(client.close);
    final result =
        await DavCollectionHttpClient(
          transport: DavHttpTransport(
            client: client,
            profile: profile,
            accountAuthority: authority,
          ),
          profile: profile,
          accountAuthority: authority,
          accountId: 'a',
          collectionId: 'c',
          collectionUri: authority.resolve('/work/'),
          credential: DavBasicCredential(username: 'qa', password: 'synthetic'),
        ).fetchMembers(
          [
            DavRemoteMember(
              hrefKey: '/work/a.ics',
              requestUri: authority.resolve('/work/a.ics'),
              etag: '"v1"',
            ),
          ],
          correlationId: 'utf16',
          useCalendarMultiget: true,
        );
    expect(result.single.rawIcsBody, 'Café 😀');
  });

  for (final resourceBytes in [3 * 1024 * 1024, 9 * 1024 * 1024]) {
    test('multiget recovers bounded aggregate limits with $resourceBytes byte members', () async {
      final authority = Uri.parse('https://cal.example.test/');
      final profile = davProviderProfile(
        BusyProvider.caldav,
        caldavServer: authority,
      );
      final raw =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VEVENT\r\nUID:large\r\nDTSTAMP:20261108T000000Z\r\nDTSTART:20261109T090000Z\r\nDESCRIPTION:${'x' * resourceBytes}\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
      final methods = <String>[];
      final client = MockClient((request) async {
        methods.add(request.method);
        if (request.method == 'GET') {
          return http.Response(raw, 200, headers: {'etag': '"large"'});
        }
        return http.Response(
          '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
          '<d:response><d:href>a.ics</d:href><d:propstat><d:prop>'
          '<d:getetag>"large"</d:getetag><c:calendar-data>$raw</c:calendar-data>'
          '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'
          '<d:response><d:href>b.ics</d:href><d:propstat><d:prop>'
          '<d:getetag>"large"</d:getetag><c:calendar-data>$raw</c:calendar-data>'
          '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'
          '</d:multistatus>',
          207,
        );
      });
      addTearDown(client.close);
      final result =
          await DavCollectionHttpClient(
            transport: DavHttpTransport(
              client: client,
              profile: profile,
              accountAuthority: authority,
            ),
            profile: profile,
            accountAuthority: authority,
            accountId: 'a',
            collectionId: 'c',
            collectionUri: authority.resolve('/work/'),
            credential: DavBasicCredential(
              username: 'qa',
              password: 'synthetic',
            ),
          ).fetchMembers(
            [
              for (final name in ['a', 'b'])
                DavRemoteMember(
                  hrefKey: '/work/$name.ics',
                  requestUri: authority.resolve('/work/$name.ics'),
                  etag: '"large"',
                ),
            ],
            correlationId: 'large',
            useCalendarMultiget: true,
          );
      expect(result.map((m) => m.rawIcsBody), [raw, raw]);
      expect(methods, ['REPORT', 'GET', 'GET']);
    });
  }
  for (final scenario in [
    'resource404',
    'property404',
    'missing-data',
    'missing-etag',
    'omitted',
    'identical-duplicate',
    'contradictory-duplicate',
  ]) {
    test('multiget $scenario uses only authoritative resource evidence', () async {
      final authority = Uri.parse('https://cal.example.test/');
      final profile = davProviderProfile(
        BusyProvider.caldav,
        caldavServer: authority,
      );
      final methods = <String>[];
      final live =
          '<d:response><d:href>a.ics</d:href><d:propstat><d:prop>'
          '<d:getetag>"a2"</d:getetag><c:calendar-data>complete calendar</c:calendar-data>'
          '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>';
      const missing =
          '<d:response><d:href>a.ics</d:href><d:status>HTTP/1.1 404 Not Found</d:status></d:response>';
      final client = MockClient((request) async {
        methods.add(request.method);
        if (request.method == 'GET') {
          return http.Response(
            'retrieved calendar',
            200,
            headers: {'etag': '"a3"'},
          );
        }
        final content = switch (scenario) {
          'resource404' => missing,
          'property404' => live.replaceFirst('200 OK', '404 Not Found'),
          'missing-data' => live.replaceFirst(
            '<c:calendar-data>complete calendar</c:calendar-data>',
            '',
          ),
          'missing-etag' => live.replaceFirst(
            '<d:getetag>"a2"</d:getetag>',
            '',
          ),
          'omitted' => '',
          'identical-duplicate' => live + live,
          _ => missing + live,
        };
        return http.Response(
          '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">$content</d:multistatus>',
          207,
        );
      });
      addTearDown(client.close);
      final result =
          DavCollectionHttpClient(
            transport: DavHttpTransport(
              client: client,
              profile: profile,
              accountAuthority: authority,
            ),
            profile: profile,
            accountAuthority: authority,
            accountId: 'a',
            collectionId: 'c',
            collectionUri: authority.resolve('/work/'),
            credential: DavBasicCredential(
              username: 'qa',
              password: 'synthetic',
            ),
          ).fetchMembers(
            [
              DavRemoteMember(
                hrefKey: '/work/a.ics',
                requestUri: authority.resolve('/work/a.ics'),
                etag: '"a2"',
              ),
            ],
            correlationId: 'multiget',
            useCalendarMultiget: true,
          );
      if (scenario.endsWith('duplicate')) {
        await expectLater(result, throwsA(isA<DavException>()));
        expect(methods, ['REPORT']);
      } else {
        final member = (await result).single;
        expect(member.missing, scenario == 'resource404');
        expect(
          member.rawIcsBody,
          scenario == 'resource404' ? null : 'retrieved calendar',
        );
        expect(
          methods,
          scenario == 'resource404' ? ['REPORT'] : ['REPORT', 'GET'],
        );
      }
    });
  }
  for (final limit in [null, 17]) {
    test('sync-collection uses RFC 6578 Depth: 0', () async {
      final authority = Uri.parse('https://cloud.example.test/nextcloud');
      final client = MockClient((request) async {
        // Model a strict RFC 6578 server: sync-level controls member depth and
        // an HTTP Depth value other than zero is rejected.
        if (request.headers['depth'] != '0') {
          return http.Response('', 400);
        }
        expect(request.method, 'REPORT');
        expect(request.body, contains('<d:sync-level>1</d:sync-level>'));
        expect(request.body.contains('<d:limit>'), limit != null);
        if (limit != null) {
          expect(request.body, contains('<d:nresults>$limit</d:nresults>'));
        }
        return http.Response(
          '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"><d:sync-token>urn:test:next-token</d:sync-token></d:multistatus>''',
          207,
          headers: const {'content-type': 'application/xml'},
        );
      });
      addTearDown(client.close);
      final profile = davProviderProfile(
        BusyProvider.nextcloud,
        nextcloudServer: authority,
      );
      final remote = DavCollectionHttpClient(
        transport: DavHttpTransport(
          client: client,
          profile: profile,
          accountAuthority: authority,
          delay: (_) async {},
        ),
        profile: profile,
        accountAuthority: authority,
        accountId: 'account',
        collectionId: 'collection',
        collectionUri: Uri.parse(
          'https://cloud.example.test/nextcloud/remote.php/dav/calendars/alex/work/',
        ),
        credential: DavBasicCredential(username: 'alex', password: 'secret'),
        maximumSyncResults: limit,
      );

      final page = await remote.syncCollectionPage(
        syncToken: '',
        correlationId: 'strict-depth',
      );

      expect(page.nextSyncToken, 'urn:test:next-token');
    });
  }
  for (final condition in [false, true]) {
    test(
      'collection 507 recognizes truncation; optional condition=$condition',
      () async {
        final page = await _page(
          _multi(
            _collection507(condition) + _changed(),
            token: 'urn:test:page',
          ),
        );
        expect(page.truncated, isTrue);
        expect(page.changedMembers.single.hrefKey, '/calendars/u/work/a.ics');
        expect(page.changedMembers.single.etag, '"a1"');
        expect(page.nextSyncToken, 'urn:test:page');
        expect(page.deletedHrefKeys, isEmpty);
      },
    );
  }
  test('initial inventory retains existing tolerance for valid-form tombstones', () async {
    final page = await _page(
      _multi(
        '${_changed()}<d:response><d:href>removed.ics</d:href><d:status>HTTP/1.1 404 Not Found</d:status></d:response>',
      ),
      syncToken: '',
    );
    expect(page.truncated, isFalse);
    expect(page.changedMembers.single.etag, '"a1"');
    expect(page.deletedHrefKeys, {'/calendars/u/work/removed.ics'});
  });
  final invalid = <String, (String, int)>{
    'member 507': (
      _multi(
        '<d:response><d:href>a.ics</d:href><d:status>HTTP/1.1 507 Insufficient Storage</d:status></d:response>',
      ),
      207,
    ),
    'member property 507': (_multi(_changed(status: 507)), 207),
    'contradictory property statuses': (
      _multi(
        _changed().replaceFirst(
          '</d:propstat>',
          '<d:status>HTTP/1.1 507 Insufficient Storage</d:status></d:propstat>',
        ),
      ),
      207,
    ),
    'duplicate property containers': (
      _multi(_changed().replaceFirst('</d:prop>', '</d:prop><d:prop/>')),
      207,
    ),
    'missing token': (_multi(_collection507(false), token: null), 207),
    'empty token': (_multi(_collection507(false), token: ''), 207),
    'invalid token URI': (
      _multi(_collection507(false), token: 'not-a-uri'),
      207,
    ),
    'unchanged continuation': (
      _multi(_collection507(false), token: 'urn:test:previous'),
      207,
    ),
    'duplicate token': (
      _multi(_changed()).replaceFirst(
        '</d:multistatus>',
        '<d:sync-token>urn:test:other</d:sync-token></d:multistatus>',
      ),
      207,
    ),
    'overall 507': (_multi(_collection507(true)), 507),
    'limit condition without collection 507': (
      _multi(_changed()).replaceFirst(
        '</d:multistatus>',
        '<d:error><d:number-of-matches-within-limits/></d:error></d:multistatus>',
      ),
      207,
    ),
    'collection 507 with properties': (
      _multi(
        _collection507(false).replaceFirst(
          '</d:response>',
          '<d:propstat><d:prop/><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>',
        ),
      ),
      207,
    ),
    'duplicate collection': (
      _multi(_collection507(false) + _collection507(true)),
      207,
    ),
    'duplicate member': (_multi(_changed() + _changed()), 207),
    'changed member status': (
      _multi(
        '<d:response><d:href>a.ics</d:href><d:status>HTTP/1.1 200 OK</d:status></d:response>',
      ),
      207,
    ),
    'status plus property': (
      _multi(
        _changed().replaceFirst(
          '</d:href>',
          '</d:href><d:status>HTTP/1.1 200 OK</d:status>',
        ),
      ),
      207,
    ),
    'member error status': (_multi(_changed(status: 500)), 207),
    'missing ETag': (
      _multi(_changed().replaceFirst('<d:getetag>"a1"</d:getetag>', '')),
      207,
    ),
    'outside member': (
      _multi(_changed().replaceFirst('a.ics', '../outside.ics')),
      207,
    ),
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key}', () async {
      await expectLater(
        _page(entry.value.$1, status: entry.value.$2),
        throwsA(isA<DavException>()),
      );
    });
  }
}

String _collection507(bool condition) =>
    '<d:response><d:href>/calendars/u/work/</d:href><d:status>HTTP/1.1 507 Insufficient Storage</d:status>${condition ? '<d:error><d:number-of-matches-within-limits/></d:error>' : ''}</d:response>';
String _changed({int status = 200}) =>
    '<d:response><d:href>a.ics</d:href><d:propstat><d:prop><d:getetag>"a1"</d:getetag></d:prop><d:status>HTTP/1.1 $status status</d:status></d:propstat></d:response>';
String _multi(String responses, {String? token = 'urn:test:page'}) =>
    '<d:multistatus xmlns:d="DAV:">$responses${token == null ? '' : '<d:sync-token>$token</d:sync-token>'}</d:multistatus>';
Future<DavSyncPage> _page(
  String body, {
  int status = 207,
  String syncToken = 'urn:test:previous',
}) async {
  final authority = Uri.parse('https://cal.example.test/');
  final profile = davProviderProfile(
    BusyProvider.caldav,
    caldavServer: authority,
  );
  final client = MockClient((_) async => http.Response(body, status));
  try {
    return await DavCollectionHttpClient(
      transport: DavHttpTransport(
        client: client,
        profile: profile,
        accountAuthority: authority,
        limits: const DavTransportLimits(maximumReadAttempts: 1),
      ),
      profile: profile,
      accountAuthority: authority,
      accountId: 'account',
      collectionId: 'collection',
      collectionUri: authority.resolve('/calendars/u/work/'),
      credential: DavBasicCredential(username: 'u', password: 'synthetic'),
    ).syncCollectionPage(syncToken: syncToken, correlationId: 'rfc6578');
  } finally {
    client.close();
  }
}
