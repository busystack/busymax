import 'package:fake_async/fake_async.dart';
import 'dart:async';
import 'dart:convert';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class ControlledResponseClient extends http.BaseClient {
  ControlledResponseClient(this.respond);
  final Future<http.StreamedResponse> Function() respond;
  int sends = 0;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sends++;
    return respond();
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  for (final microsoft in [false, true]) {
    Future<OAuthTokenSet> exchange(
      http.Client client, {
      Future<void>? cancellation,
    }) {
      if (microsoft) {
        return MicrosoftOAuthService(
          config: BuildConfig.fromEnvironment(),
          httpClient: client,
          tokenStore: InMemorySecretStore(),
          loopbackFlow: OAuthLoopbackFlow(),
        ).exchangeAuthorizationCode(
          code: 'synthetic-code',
          codeVerifier: 'synthetic-verifier',
          redirectUri: 'http://localhost:4321/',
          registration: MicrosoftPublicRegistration(
            clientId: '22222222-2222-2222-2222-222222222222',
            audience: MicrosoftAudience.personalAndOrganizations,
          ),
          cancellation: cancellation,
        );
      }
      return OAuthService(
        config: BuildConfig.fromEnvironment(),
        httpClient: client,
        tokenStore: InMemorySecretStore(),
        loopbackFlow: OAuthLoopbackFlow(),
      ).exchangeAuthorizationCode(
        code: 'synthetic-code',
        codeVerifier: 'synthetic-verifier',
        redirectUri: 'http://127.0.0.1:4321/',
        registration: const GoogleDesktopRegistration(
          clientId: 'synthetic.apps.googleusercontent.com',
          projectId: 'synthetic-project',
        ),
        cancellation: cancellation,
      );
    }

    for (final (status, body) in [
      (400, 'not-json-sensitive'),
      (200, 'not-json-sensitive'),
      (200, 'x' * (1024 * 1024 + 1)),
    ]) {
      test(
        'code exchange safely rejects malformed/bounded response HTTP$status microsoft=$microsoft size=${body.length}',
        () async {
          final client = ControlledResponseClient(
            () async =>
                http.StreamedResponse(Stream.value(utf8.encode(body)), status),
          );
          await expectLater(
            exchange(client),
            throwsA(
              isA<OAuthException>()
                  .having(
                    (e) => e.classification,
                    'temporary',
                    OAuthFailureKind.temporary,
                  )
                  .having(
                    (e) => e.toString(),
                    'redacted',
                    isNot(contains('sensitive')),
                  ),
            ),
          );
          expect(client.sends, 1);
          expect(client.closed, false);
        },
      );
    }
    test(
      'code exchange cancellation stops stalled body consumption without closing shared client microsoft=$microsoft',
      () async {
        final listening = Completer<void>(), cancellation = Completer<void>();
        var cleaned = false;
        final stream = StreamController<List<int>>(
          onListen: () => listening.complete(),
          onCancel: () {
            cleaned = true;
          },
        );
        final client = ControlledResponseClient(
          () async => http.StreamedResponse(stream.stream, 200),
        );
        final work = exchange(client, cancellation: cancellation.future);
        final failed = expectLater(
          work,
          throwsA(
            isA<OAuthException>().having(
              (e) => e.classification,
              'cancelled',
              OAuthFailureKind.cancelled,
            ),
          ),
        );
        await listening.future;
        cancellation.complete();
        await failed;
        expect(cleaned, true);
        expect(client.closed, false);
        expect(client.sends, 1);
        await stream.close();
      },
    );
    test(
      'code exchange deadline bounds a stalled body and its cleanup microsoft=$microsoft',
      () {
        fakeAsync((clock) {
          var listening = false;
          final cleanup = Completer<void>();
          final stream = StreamController<List<int>>(
            onListen: () {
              listening = true;
            },
            onCancel: () => cleanup.future,
          );
          final client = ControlledResponseClient(
            () async => http.StreamedResponse(stream.stream, 200),
          );
          Object? failure;
          unawaited(
            exchange(client).then<void>(
              (_) => fail('Stalled exchange completed'),
              onError: (Object e, StackTrace _) {
                failure = e;
              },
            ),
          );
          clock.flushMicrotasks();
          expect(listening, true);
          clock.elapse(const Duration(seconds: 30));
          clock.flushMicrotasks();
          expect(
            failure,
            isA<OAuthException>().having(
              (e) => e.classification,
              'deadline',
              OAuthFailureKind.timeout,
            ),
          );
          expect(client.sends, 1);
          expect(client.closed, false);
          cleanup.complete();
          unawaited(stream.close());
          clock.flushMicrotasks();
        });
      },
    );
    test(
      'already cancelled code exchange makes zero requests microsoft=$microsoft',
      () async {
        final client = ControlledResponseClient(
          () async => http.StreamedResponse(Stream.value([]), 200),
        );
        await expectLater(
          exchange(client, cancellation: Future.value()),
          throwsA(
            isA<OAuthException>().having(
              (e) => e.classification,
              'cancelled',
              OAuthFailureKind.cancelled,
            ),
          ),
        );
        expect(client.sends, 0);
        expect(client.closed, false);
      },
    );
  }
}
