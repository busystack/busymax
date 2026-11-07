import 'dart:async';

import 'package:busymax/src/core/http/authorization_leased_http_client.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  final endpoint = Uri.parse('https://example.test/slow');

  for (final failure in ['connection', 'stream', 'cancellation', 'timeout']) {
    test(
      'request-scoped binding recovers after $failure without replacing authorization',
      () async {
        var attempts = 0, closed = 0, leases = 0;
        var valid = true;
        final abort = Completer<void>();
        final client = AuthorizationLeasedHttpClient.requestScoped(
          maximumLifetime: const Duration(milliseconds: 30),
          createDelegate: () {
            final attempt = ++attempts;
            return _Client(
              (request) async {
                if (attempt != 2) {
                  return http.StreamedResponse(Stream.value([111, 107]), 200);
                }
                switch (failure) {
                  case 'connection':
                    throw http.ClientException('connection lost');
                  case 'stream':
                    return http.StreamedResponse(
                      Stream.error(http.ClientException('body lost')),
                      200,
                    );
                  case 'cancellation':
                    abort.complete();
                }
                return Completer<http.StreamedResponse>().future;
              },
              onClose: () {
                expect(
                  leases,
                  greaterThan(0),
                  reason: 'terminate before releasing authorization',
                );
                closed++;
              },
            );
          },
          runLease: (work) async {
            leases++;
            try {
              await work();
            } finally {
              leases--;
            }
          },
          validate: () async {
            if (!valid) throw StateError('replaced authorization');
          },
        );
        addTearDown(client.close);
        expect((await client.get(endpoint)).body, 'ok');
        final failed = client
            .sendTerminating(
              http.Request('GET', endpoint),
              terminate: abort.future,
              connectionTimeout: const Duration(seconds: 1),
            )
            .then(http.Response.fromStream);
        await expectLater(failed, throwsA(isA<Exception>()));
        expect(closed, 2);
        expect((await client.get(endpoint)).body, 'ok');
        expect(attempts, 3);
        valid = false;
        await expectLater(client.get(endpoint), throwsStateError);
        expect(
          attempts,
          3,
          reason: 'replacement/removal invalidates the old binding before transport creation',
        );
      },
    );
  }

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
  _Client(this.sendRequest, {this.onClose});
  final void Function()? onClose;
  final Future<http.StreamedResponse> Function(http.BaseRequest) sendRequest;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      sendRequest(request);
  @override
  void close() => onClose?.call();
}
