import 'dart:async';
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
    'allows Nextcloud root well-known discovery only until its installation redirect',
    () async {
      final requested = <http.Request>[];
      final transport = _nextcloudTransport(
        MockClient((request) async {
          requested.add(request);
          if (requested.length == 1) {
            return http.Response(
              '',
              302,
              headers: {
                'location':
                    'https://cloud.example.test/nextcloud/remote.php/dav/',
              },
            );
          }
          return http.Response('', 200);
        }),
      );

      final response = await transport.send(
        _propfind(Uri.parse('https://cloud.example.test/.well-known/caldav')),
        credential: credential,
      );

      expect(response.requestUri.path, '/nextcloud/remote.php/dav/');
      expect(requested, hasLength(2));
      expect(
        requested.map((request) => request.headers['authorization']),
        everyElement(startsWith('Basic ')),
      );
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

  test(
    'operation timeout interrupts retry backoff without another request',
    () async {
      var calls = 0;
      final delayGate = Completer<void>();
      final transport = _nextcloudTransport(
        MockClient((_) async {
          calls += 1;
          return http.Response('', 503, headers: {'retry-after': '1'});
        }),
        limits: const DavTransportLimits(
          operationTimeout: Duration(milliseconds: 25),
        ),
        delay: (_) => delayGate.future,
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
            (error) => error.code,
            'code',
            'DavOperationTimeout',
          ),
        ),
      );
      delayGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    },
  );

  test('timeout awaiting headers aborts the active request', () async {
    final client = _AbortObservingClient(hangFirstHeaders: true);
    final transport = _nextcloudTransport(
      client,
      limits: const DavTransportLimits(
        connectTimeout: Duration(seconds: 1),
        operationTimeout: Duration(milliseconds: 25),
        maximumReadAttempts: 1,
      ),
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
          (error) => error.code,
          'code',
          'DavOperationTimeout',
        ),
      ),
    );
    expect(client.calls, 1);
    expect(client.aborts, 1);
  });

  test(
    'cancellation during body streaming aborts and stops consumption',
    () async {
      final client = _AbortObservingClient(streamBody: true);
      final token = DavCancellationToken();
      final transport = _nextcloudTransport(
        client,
        limits: const DavTransportLimits(
          operationTimeout: Duration(seconds: 1),
        ),
      );
      final request = transport.send(
        _propfind(
          Uri.parse('https://cloud.example.test/nextcloud/remote.php/dav'),
        ),
        credential: credential,
        cancellationToken: token,
      );
      await client.bodyStarted.future;
      token.cancel();

      await expectLater(
        request,
        throwsA(
          isA<DavException>().having(
            (error) => error.kind,
            'kind',
            DavErrorKind.cancelled,
          ),
        ),
      );
      expect(client.aborts, 1);
      expect(client.bodyCancelled, 1);
    },
  );

  test(
    'cancelled concurrency waiter never dispatches or leaks a permit',
    () async {
      final client = _AbortObservingClient(hangFirstHeaders: true);
      final transport = _nextcloudTransport(
        client,
        limits: const DavTransportLimits(
          operationTimeout: Duration(seconds: 1),
          maximumReadAttempts: 1,
          maximumConcurrentPerAccount: 1,
        ),
      );
      final firstToken = DavCancellationToken();
      final first = transport.send(
        _propfind(
          Uri.parse(
            'https://cloud.example.test/nextcloud/remote.php/dav/first',
          ),
        ),
        credential: credential,
        cancellationToken: firstToken,
      );
      await client.firstStarted.future;
      final waitingToken = DavCancellationToken();
      final waiting = transport.send(
        _propfind(
          Uri.parse(
            'https://cloud.example.test/nextcloud/remote.php/dav/waiting',
          ),
        ),
        credential: credential,
        cancellationToken: waitingToken,
      );
      waitingToken.cancel();
      await expectLater(waiting, throwsA(isA<DavException>()));
      expect(client.calls, 1);

      firstToken.cancel();
      await expectLater(first, throwsA(isA<DavException>()));
      final third = await transport.send(
        _propfind(
          Uri.parse(
            'https://cloud.example.test/nextcloud/remote.php/dav/third',
          ),
        ),
        credential: credential,
      );
      expect(third.statusCode, 200);
      expect(client.calls, 2);
    },
  );

  test(
    'operation timeout does not cancel a token shared with a sibling',
    () async {
      final client = _AbortObservingClient(hangFirstHeaders: true);
      final token = DavCancellationToken();
      final transport = _nextcloudTransport(
        client,
        limits: const DavTransportLimits(
          operationTimeout: Duration(milliseconds: 25),
          maximumReadAttempts: 1,
        ),
      );

      final timedOut = transport.send(
        _propfind(
          Uri.parse('https://cloud.example.test/nextcloud/remote.php/dav/slow'),
        ),
        credential: credential,
        cancellationToken: token,
      );
      final timedOutExpectation = expectLater(
        timedOut,
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'DavOperationTimeout',
          ),
        ),
      );
      await client.firstStarted.future;
      final sibling = await transport.send(
        _propfind(
          Uri.parse(
            'https://cloud.example.test/nextcloud/remote.php/dav/sibling',
          ),
        ),
        credential: credential,
        cancellationToken: token,
      );

      expect(sibling.statusCode, 200);
      await timedOutExpectation;
      expect(token.isCancelled, isFalse);
      expect(client.calls, 2);
      expect(client.aborts, 1);
    },
  );
}

final class _AbortObservingClient extends http.BaseClient {
  _AbortObservingClient({
    this.hangFirstHeaders = false,
    this.streamBody = false,
  });

  final bool hangFirstHeaders;
  final bool streamBody;
  final Completer<void> firstStarted = Completer<void>();
  final Completer<void> bodyStarted = Completer<void>();
  var calls = 0;
  var aborts = 0;
  var bodyCancelled = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    calls += 1;
    if (!firstStarted.isCompleted) firstStarted.complete();
    final abortTrigger = request is http.Abortable
        ? request.abortTrigger
        : null;
    if (hangFirstHeaders && calls == 1) {
      final response = Completer<http.StreamedResponse>();
      unawaited(
        abortTrigger!.then((_) {
          aborts += 1;
          response.completeError(http.RequestAbortedException(request.url));
        }),
      );
      return response.future;
    }
    if (streamBody) {
      late StreamController<List<int>> body;
      body = StreamController<List<int>>(
        onListen: () {
          if (!bodyStarted.isCompleted) bodyStarted.complete();
          body.add(utf8.encode('chunk'));
        },
        onCancel: () => bodyCancelled += 1,
      );
      unawaited(
        abortTrigger!.then((_) {
          aborts += 1;
          if (!body.isClosed) {
            body.addError(http.RequestAbortedException(request.url));
            unawaited(body.close());
          }
        }),
      );
      return Future.value(http.StreamedResponse(body.stream, 200));
    }
    return Future.value(
      http.StreamedResponse(Stream.value(utf8.encode('ok')), 200),
    );
  }
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
