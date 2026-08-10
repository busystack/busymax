import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const accountId = 'account';
  const correlationId = 'correlation-1';
  final credential = DavBasicCredential(
    username: 'alex',
    password: 'app-secret',
  );

  test('sends explicit UTF-8 bodies and preserves quoted ETags', () async {
    late http.Request captured;
    final transport = _nextcloudTransport(
      MockClient((request) async {
        captured = request;
        return http.Response('stored', 200, headers: {'etag': '"abc-123"'});
      }),
    );
    final response = await transport.send(
      DavRequest.icalendar(
        method: 'PUT',
        uri: Uri.parse(
          'https://cloud.example.test/nextcloud/remote.php/dav/calendars/a/new.ics',
        ),
        accountId: accountId,
        collectionId: 'collection',
        correlationId: correlationId,
        body: 'BEGIN:VCALENDAR\r\nSUMMARY:Résumé 📅\r\nEND:VCALENDAR\r\n',
        headers: const {'if-match': '"old-etag"'},
      ),
      credential: credential,
    );

    expect(captured.method, 'PUT');
    expect(captured.headers['content-type'], 'text/calendar; charset=utf-8');
    expect(captured.headers['if-match'], '"old-etag"');
    expect(captured.headers['authorization'], startsWith('Basic '));
    expect(utf8.decode(captured.bodyBytes), contains('Résumé 📅'));
    expect(response.etag, '"abc-123"');
    expect(credential.toString(), isNot(contains('app-secret')));
  });

  test(
    'rejects cross-origin redirect before credentials are forwarded',
    () async {
      final requested = <Uri>[];
      final transport = _nextcloudTransport(
        MockClient((request) async {
          requested.add(request.url);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://evil.example.test/steal'},
          );
        }),
      );

      await expectLater(
        transport.send(
          _propfind(
            Uri.parse(
              'https://cloud.example.test/nextcloud/.well-known/caldav',
            ),
          ),
          credential: credential,
        ),
        throwsA(
          isA<DavException>().having(
            (error) => error.kind,
            'kind',
            DavErrorKind.redirectRejected,
          ),
        ),
      );
      expect(requested, hasLength(1));
    },
  );

  test(
    'allows approved iCloud shards but rejects look-alike domains',
    () async {
      final requested = <Uri>[];
      final headers = <String?>[];
      final client = MockClient((request) async {
        requested.add(request.url);
        headers.add(request.headers['authorization']);
        if (requested.length == 1) {
          return http.Response(
            '',
            301,
            headers: {'location': 'https://p123-caldav.icloud.com/principal/'},
          );
        }
        return http.Response('<ok/>', 200);
      });
      final profile = davProviderProfile(BusyProvider.appleICloud);
      final transport = DavHttpTransport(
        client: client,
        profile: profile,
        accountAuthority: Uri.parse('https://caldav.icloud.com'),
        delay: (_) async {},
        random: Random(1),
      );

      final response = await transport.send(
        _propfind(Uri.parse('https://caldav.icloud.com/.well-known/caldav')),
        credential: credential,
      );
      expect(response.requestUri.host, 'p123-caldav.icloud.com');
      expect(headers, everyElement(startsWith('Basic ')));

      final unsafe = DavHttpTransport(
        client: MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'https://p1-caldav.icloud.com.evil.test/'},
          ),
        ),
        profile: profile,
        accountAuthority: Uri.parse('https://caldav.icloud.com'),
        delay: (_) async {},
      );
      await expectLater(
        unsafe.send(
          _propfind(Uri.parse('https://caldav.icloud.com/.well-known/caldav')),
          credential: credential,
        ),
        throwsA(isA<DavException>()),
      );
    },
  );

  test('retries safe reads but never blindly retries a mutation', () async {
    var safeCalls = 0;
    final safeTransport = _nextcloudTransport(
      MockClient((_) async {
        safeCalls += 1;
        return safeCalls == 1
            ? http.Response('', 503, headers: {'retry-after': '0'})
            : http.Response('ok', 200);
      }),
    );
    final response = await safeTransport.send(
      _propfind(
        Uri.parse('https://cloud.example.test/nextcloud/remote.php/dav'),
      ),
      credential: credential,
    );
    expect(response.statusCode, 200);
    expect(safeCalls, 2);

    var mutationCalls = 0;
    final mutationTransport = _nextcloudTransport(
      MockClient((_) async {
        mutationCalls += 1;
        return http.Response('', 503);
      }),
    );
    final mutationResponse = await mutationTransport.send(
      DavRequest.icalendar(
        method: 'PUT',
        uri: Uri.parse(
          'https://cloud.example.test/nextcloud/remote.php/dav/a.ics',
        ),
        accountId: accountId,
        collectionId: 'collection',
        correlationId: correlationId,
        body: 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n',
        headers: const {'if-none-match': '*'},
      ),
      credential: credential,
    );
    expect(mutationResponse.statusCode, 503);
    expect(mutationCalls, 1);
  });

  test('honors delta-seconds and HTTP-date Retry-After values', () async {
    final now = DateTime.utc(2026, 8, 8, 12);
    final delays = <Duration>[];
    var calls = 0;
    final transport = _nextcloudTransport(
      MockClient((_) async {
        calls += 1;
        if (calls == 1) {
          return http.Response(
            '',
            503,
            headers: {
              'retry-after': HttpDate.format(
                now.add(const Duration(seconds: 23)),
              ),
            },
          );
        }
        return http.Response('ok', 200);
      }),
      delay: (duration) async => delays.add(duration),
      nowUtc: () => now,
    );

    final response = await transport.send(
      _propfind(
        Uri.parse('https://cloud.example.test/nextcloud/remote.php/dav'),
      ),
      credential: credential,
    );

    expect(response.statusCode, 200);
    expect(delays, [const Duration(seconds: 23)]);
  });

  test('enforces response and cancellation bounds', () async {
    final transport = _nextcloudTransport(
      MockClient((_) async => http.Response('12345', 200)),
      limits: const DavTransportLimits(maximumResponseBytes: 4),
    );
    await expectLater(
      transport.send(
        _propfind(
          Uri.parse('https://cloud.example.test/nextcloud/remote.php/dav'),
        ),
        credential: credential,
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.kind,
          'kind',
          DavErrorKind.responseTooLarge,
        ),
      ),
    );

    final token = DavCancellationToken()..cancel();
    await expectLater(
      transport.send(
        _propfind(
          Uri.parse('https://cloud.example.test/nextcloud/remote.php/dav'),
        ),
        credential: credential,
        cancellationToken: token,
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.kind,
          'kind',
          DavErrorKind.cancelled,
        ),
      ),
    );
  });
}

DavHttpTransport _nextcloudTransport(
  http.Client client, {
  DavTransportLimits limits = const DavTransportLimits(),
  DavDelay? delay,
  DateTime Function()? nowUtc,
}) {
  final authority = Uri.parse('https://cloud.example.test/nextcloud');
  return DavHttpTransport(
    client: client,
    profile: davProviderProfile(
      BusyProvider.nextcloud,
      nextcloudServer: authority,
    ),
    accountAuthority: authority,
    limits: limits,
    delay: delay ?? (_) async {},
    random: Random(1),
    nowUtc: nowUtc,
  );
}

DavRequest _propfind(Uri uri) => DavRequest.xml(
  method: 'PROPFIND',
  uri: uri,
  accountId: 'account',
  correlationId: 'correlation-1',
  body: '<d:propfind xmlns:d="DAV:"><d:prop/></d:propfind>',
  headers: const {'depth': '0'},
);
