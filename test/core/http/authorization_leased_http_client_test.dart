import 'dart:async';

import 'package:busymax/src/core/http/authorization_leased_http_client.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  final endpoint = Uri.parse('https://example.test/slow');

  test('queue time does not consume the two-minute active response budget', () {
    fakeAsync((clock) {
      final acquired = Completer<void>();
      final source = StreamController<List<int>>();
      var sent = 0;
      var released = false;
      Object? failure;
      String? result;
      final client = AuthorizationLeasedHttpClient(
        delegate: _Client((request) async {
          sent++;
          return http.StreamedResponse(source.stream, 200);
        }),
        runLease: (work) async {
          await acquired.future;
          try {
            await work();
          } finally {
            released = true;
          }
        },
        validate: () async {},
      );
      expect(
        client.maximumLifetime,
        const DavTransportLimits().operationTimeout,
      );
      unawaited(
        client
            .get(endpoint)
            .then(
              (r) {
                result = r.body;
              },
              onError: (Object error) {
                failure = error;
              },
            ),
      );
      clock.elapse(const Duration(seconds: 100));
      expect(sent, 0);
      acquired.complete();
      clock.flushMicrotasks();
      expect(sent, 1);
      // This response is slow but within the existing DAV operation budget.
      clock.elapse(const Duration(seconds: 100));
      source.add([111, 107]);
      unawaited(source.close());
      clock.flushMicrotasks();
      expect(result, 'ok');
      expect(failure, isNull);
      expect(released, isTrue);
      client.close();
    });
  });

  test('bounded acquisition expires without a later HTTP dispatch', () {
    fakeAsync((clock) {
      final acquired = Completer<void>();
      var sent = 0;
      Object? failure;
      final client = AuthorizationLeasedHttpClient(
        delegate: _Client((request) async {
          sent++;
          return http.StreamedResponse(const Stream.empty(), 200);
        }),
        runLease: (work) async {
          await acquired.future;
          await work();
        },
        validate: () async {},
      );
      unawaited(
        client
            .get(endpoint)
            .then(
              (_) {},
              onError: (Object e) {
                failure = e;
              },
            ),
      );
      clock.elapse(const Duration(minutes: 2));
      expect(failure, isA<TimeoutException>());
      acquired.complete();
      clock.flushMicrotasks();
      expect(sent, 0);
      client.close();
    });
  });

  test('abandoned response releases its active lease at two minutes', () {
    fakeAsync((clock) {
      var released = false;
      final client = AuthorizationLeasedHttpClient(
        delegate: _Client(
          (request) async => http.StreamedResponse(const Stream.empty(), 200),
        ),
        runLease: (work) async {
          await work();
          released = true;
        },
        validate: () async {},
      );
      http.StreamedResponse? response;
      unawaited(
        client.send(http.Request('GET', endpoint)).then((r) {
          response = r;
        }),
      );
      clock.flushMicrotasks();
      expect(response, isNotNull);
      clock.elapse(const Duration(seconds: 119));
      expect(released, isFalse);
      clock.elapse(const Duration(seconds: 1));
      expect(released, isTrue);
      Object? failure;
      unawaited(
        response!.stream.drain<void>().catchError((Object e) {
          failure = e;
        }),
      );
      clock.flushMicrotasks();
      expect(failure, isA<TimeoutException>());
      client.close();
    });
  });
}

final class _Client extends http.BaseClient {
  _Client(this.sendRequest);
  final Future<http.StreamedResponse> Function(http.BaseRequest) sendRequest;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      sendRequest(request);
  @override
  void close() {}
}
