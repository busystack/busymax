import 'package:busymax/src/google_tasks/http/retrying_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
