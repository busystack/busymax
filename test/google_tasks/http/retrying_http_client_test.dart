import 'package:busymax/src/google_tasks/http/retrying_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final hint in ['120', 'Sat, 03 Oct 2026 12:02:00 GMT']) {
    test(
      'long Retry-After $hint is returned unshortened without retry',
      () async {
        var calls = 0;
        final client = RetryingHttpClient(
          inner: MockClient((r) async {
            calls++;
            return http.Response(
              'rate limited',
              429,
              headers: {'retry-after': hint},
            );
          }),
          nowUtc: () => DateTime.utc(2026, 10, 3, 12),
          delay: (_) async => fail('must not wait beyond the deadline'),
        );
        final response = await client.get(
          Uri.https('tasks.googleapis.com', '/tasks/v1/users/@me/lists'),
        );
        expect(response.statusCode, 429);
        expect(response.headers['retry-after'], hint);
        expect(calls, 1);
      },
    );
  }
  for (final reason in [
    'rateLimitExceeded',
    'userRateLimitExceeded',
    'quotaExceeded',
    'dailyLimitExceeded',
    'insufficientPermissions',
  ]) {
    test(
      'Google 403 reason $reason controls retry, not status alone',
      () async {
        var calls = 0;
        final delays = <Duration>[];
        final client = RetryingHttpClient(
          inner: MockClient((r) async {
            calls++;
            return calls == 1
                ? http.Response(
                    jsonEncode({
                      'error': {
                        'errors': [
                          {'reason': reason},
                        ],
                      },
                    }),
                    403,
                  )
                : http.Response('ok', 200);
          }),
          delay: (d) async {
            delays.add(d);
          },
          maxRetries: 1,
        );
        final response = await client.get(
          Uri.https('tasks.googleapis.com', '/tasks/v1/users/@me/lists'),
        );
        expect(calls, reason == 'insufficientPermissions' ? 1 : 2);
        expect(
          response.statusCode,
          reason == 'insufficientPermissions' ? 403 : 200,
        );
      },
    );
  }
  test(
    'valid short server hint wins over backoff; invalid hint uses bounded backoff',
    () async {
      for (final hint in ['5', 'invalid', '-5']) {
        var calls = 0;
        final delays = <Duration>[];
        final client = RetryingHttpClient(
          inner: MockClient((r) async {
            calls++;
            return http.Response(
              'body',
              calls == 1 ? 429 : 200,
              headers: {'retry-after': hint},
            );
          }),
          delay: (d) async {
            delays.add(d);
          },
          maxRetries: 1,
        );
        expect(
          (await client.get(
            Uri.https('graph.microsoft.com', '/v1.0/me'),
          )).statusCode,
          200,
        );
        expect(
          delays.single,
          hint == '5'
              ? const Duration(seconds: 5)
              : lessThan(const Duration(seconds: 2)),
        );
      }
    },
  );
  test('cancellation aborts waiting for a stalled read transport', () async {
    final abort = Completer<void>();
    final client = RetryingHttpClient(
      inner: MockClient((r) => Completer<http.Response>().future),
    );
    final result = client.send(
      http.AbortableRequest(
        'GET',
        Uri.https('tasks.googleapis.com', '/'),
        abortTrigger: abort.future,
      ),
    );
    final assertion = expectLater(
      result,
      throwsA(isA<http.RequestAbortedException>()),
    );
    abort.complete();
    await assertion;
  });
  for (final method in const ['GET', 'HEAD', 'OPTIONS', 'TRACE']) {
    test('retries safe $method requests after a server failure', () async {
      var calls = 0;
      final delays = <Duration>[];
      final client = RetryingHttpClient(
        inner: MockClient((request) async {
          calls += 1;
          return calls == 1
              ? http.Response('temporary failure', 503)
              : http.Response('success', 200);
        }),
        delay: (duration) async => delays.add(duration),
        maxRetries: 1,
      );

      final response = await client.send(
        http.Request(method, Uri.parse('https://example.test/resource')),
      );

      expect(response.statusCode, 200);
      expect(await response.stream.bytesToString(), 'success');
      expect(calls, 2);
      expect(delays, hasLength(1));
    });
  }

  for (final method in const ['POST', 'PATCH', 'PUT', 'DELETE']) {
    for (final statusCode in const [429, 500]) {
      test('sends $method only once after HTTP $statusCode', () async {
        var calls = 0;
        late String receivedBody;
        final client = RetryingHttpClient(
          inner: MockClient((request) async {
            calls += 1;
            receivedBody = request.body;
            return http.Response('committed, but response failed', statusCode);
          }),
          delay: (_) async => fail('a mutation must not enter retry backoff'),
          maxRetries: 3,
        );

        final response = await client.send(
          http.Request(method, Uri.parse('https://example.test/resource'))
            ..body = '{"title":"Created once"}',
        );

        expect(response.statusCode, statusCode);
        expect(calls, 1);
        expect(receivedBody, '{"title":"Created once"}');
      });
    }
  }
}
