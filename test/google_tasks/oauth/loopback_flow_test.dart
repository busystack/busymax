import 'package:busymax/src/core/auth/authorization_attempt.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';

void main() {
  test('an already cancelled invocation cannot bind or launch', () async {
    var launches = 0;
    final flow = OAuthLoopbackFlow(
      authorizationLauncher: (_) async {
        launches++;
        return true;
      },
    );
    final attempt = AuthorizationAttempt(nowUtc: () => DateTime.now().toUtc())
      ..cancel();
    addTearDown(attempt.dispose);
    expect(
      () => flow.start(
        attempt: attempt,
        authorizationEndpoint: _authorizationEndpoint,
        clientId: 'fixture',
        scope: googleTasksOAuthScope,
      ),
      throwsA(
        isA<OAuthException>().having(
          (e) => e.classification,
          'kind',
          OAuthFailureKind.cancelled,
        ),
      ),
    );
    expect(launches, 0);
  });
  for (final error in [
    'access_denied',
    'invalid_client',
    'temporarily_unavailable',
    'unknown-sensitive-description',
  ]) {
    test(
      'validated callback $error ends real loopback with actionable failure',
      () async {
        final started = await _startFlow();
        final failed = expectLater(
          started.result,
          throwsA(
            isA<OAuthAuthorizationException>()
                .having(
                  (e) => e.classification,
                  'kind',
                  error == 'access_denied'
                      ? OAuthFailureKind.permission
                      : error == 'invalid_client'
                      ? OAuthFailureKind.configuration
                      : OAuthFailureKind.temporary,
                )
                .having(
                  (e) => e.toString(),
                  'safe',
                  isNot(contains('sensitive')),
                ),
          ),
        );
        final response = await http.get(
          Uri.http('127.0.0.1:${started.port}', '/', {
            'state': started.state,
            'error': error,
            'error_description': 'sensitive-description',
          }),
        );
        expect(response.statusCode, HttpStatus.badRequest);
        await failed;
      },
    );
  }
  test(
    'cancel during browser launch permits retry and old cleanup cannot close new server',
    () async {
      final oldLaunched = Completer<void>(),
          releaseOld = Completer<bool>(),
          newLaunched = Completer<Uri>();
      var launches = 0;
      final flow = OAuthLoopbackFlow(
        authorizationLauncher: (uri) {
          launches++;
          if (launches == 1) {
            oldLaunched.complete();
            return releaseOld.future;
          }
          newLaunched.complete(uri);
          return Future.value(true);
        },
      );
      final a = AuthorizationAttempt(nowUtc: () => DateTime.now().toUtc());
      final b = AuthorizationAttempt(nowUtc: () => DateTime.now().toUtc());
      addTearDown(() => a.dispose());
      addTearDown(() => b.dispose());
      final old = flow.start(
        attempt: a,
        authorizationEndpoint: _authorizationEndpoint,
        clientId: 'fixture',
        scope: googleTasksOAuthScope,
      );
      final failed = expectLater(
        old,
        throwsA(
          isA<OAuthException>().having(
            (e) => e.classification,
            'kind',
            OAuthFailureKind.cancelled,
          ),
        ),
      );
      await oldLaunched.future;
      a.cancel();
      final next = flow.start(
        attempt: b,
        authorizationEndpoint: _authorizationEndpoint,
        clientId: 'fixture',
        scope: googleTasksOAuthScope,
      );
      final uri = await newLaunched.future;
      releaseOld.complete(true);
      await failed;
      final redirect = Uri.parse(uri.queryParameters['redirect_uri']!);
      expect(
        (await http.get(
          redirect.replace(
            queryParameters: {
              'state': uri.queryParameters['state']!,
              'code': 'fresh',
            },
          ),
        )).statusCode,
        HttpStatus.ok,
      );
      expect((await next).callback.code, 'fresh');
    },
  );
  test('cancelSignIn is idempotent after server already closed', () async {
    final started = await _startFlow();

    final response = await http.get(started.callbackUri(code: 'code'));
    expect(response.statusCode, HttpStatus.ok);

    final result = await started.result;
    expect(result.callback.code, 'code');

    await expectLater(started.flow.cancel(), completes);
    await expectLater(started.flow.cancel(), completes);
  });

  test(
    'invalid request before real callback does not terminate flow',
    () async {
      final started = await _startFlow();

      final invalidResponse = await http.get(
        Uri.parse('http://127.0.0.1:${started.port}/favicon.ico'),
      );
      expect(invalidResponse.statusCode, HttpStatus.badRequest);

      final callbackResponse = await http.get(
        started.callbackUri(code: 'code'),
      );
      expect(callbackResponse.statusCode, HttpStatus.ok);

      final result = await started.result;
      expect(result.callback.code, 'code');
    },
  );

  test('localhost callback works for Microsoft loopback redirects', () async {
    final started = await _startFlow(redirectHost: 'localhost');

    final response = await http.get(
      Uri.http('localhost:${started.port}', '/', {
        'state': started.state,
        'code': 'code',
      }),
    );
    expect(response.statusCode, HttpStatus.ok);

    final result = await started.result;
    expect(result.callback.code, 'code');
    expect(result.redirectUri, 'http://localhost:${started.port}/');
  });

  test('mismatched state cannot terminate legitimate consent', () async {
    final started = await _startFlow();
    expect(
      (await http.get(
        started.callbackUri(code: 'wrong', state: 'wrong-state'),
      )).statusCode,
      HttpStatus.badRequest,
    );
    expect(
      (await http.get(started.callbackUri(code: 'legitimate'))).statusCode,
      HttpStatus.ok,
    );
    expect((await started.result).callback.code, 'legitimate');
  });

  test('timeout closes server cleanly', () async {
    final started = await _startFlow(timeout: const Duration(milliseconds: 40));

    await expectLater(
      started.result,
      throwsA(
        isA<OAuthException>().having(
          (error) => error.code,
          'code',
          'OAuthCallbackTimeout',
        ),
      ),
    );
    await expectLater(started.flow.cancel(), completes);
  });

  test('second sign-in while active fails with controlled error', () async {
    final launcher = _LaunchCapture();
    final flow = OAuthLoopbackFlow(authorizationLauncher: launcher.call);
    final first = flow.start(
      authorizationEndpoint: _authorizationEndpoint,
      clientId: 'client-id',
      scope: googleTasksOAuthScope,
    );
    await launcher.authorizationUri;

    expect(
      () => flow.start(
        authorizationEndpoint: _authorizationEndpoint,
        clientId: 'client-id',
        scope: googleTasksOAuthScope,
      ),
      throwsA(
        isA<OAuthException>().having(
          (error) => error.code,
          'code',
          'OAuthServerAlreadyRunning',
        ),
      ),
    );
    expect(launcher.launchCount, 1);

    await flow.cancel();
    await expectLater(
      first,
      throwsA(
        isA<OAuthException>().having(
          (error) => error.code,
          'code',
          'OAuthSignInCancelled',
        ),
      ),
    );
  });

  for (final platform in ['linux', 'windows']) {
    test(
      '$platform browser launch false returns visible OAuth error',
      () async {
        final flow = OAuthLoopbackFlow(
          authorizationLauncher: (_) async => false,
        );
        await expectLater(
          flow.start(
            authorizationEndpoint: _authorizationEndpoint,
            clientId: 'client-id',
            scope: googleTasksOAuthScope,
            browserLaunchFailureMessage: 'Could not open the system browser.',
          ),
          throwsA(
            isA<OAuthException>()
                .having(
                  (error) => error.code,
                  'code',
                  'OAuthBrowserLaunchFailed',
                )
                .having(
                  (error) => error.message,
                  'message',
                  'Could not open the system browser.',
                ),
          ),
        );
      },
    );

    test('$platform browser launch exception is sanitized', () async {
      final flow = OAuthLoopbackFlow(
        authorizationLauncher: (_) => throw StateError('private shell error'),
      );
      await expectLater(
        flow.start(
          authorizationEndpoint: _authorizationEndpoint,
          clientId: 'client-id',
          scope: googleTasksOAuthScope,
          browserLaunchFailureMessage: 'Could not open the system browser.',
        ),
        throwsA(
          isA<OAuthException>()
              .having((error) => error.code, 'code', 'OAuthBrowserLaunchFailed')
              .having(
                (error) => error.message,
                'message',
                isNot(contains('private shell error')),
              ),
        ),
      );
    });
  }

  test('Windows-reachable OAuth implementation contains no xdg-open', () {
    final source = File(
      'lib/src/google_tasks/oauth/oauth_loopback_flow.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('xdg-open')));
  });
}

Future<_StartedFlow> _startFlow({
  Duration timeout = const Duration(seconds: 2),
  String redirectHost = '127.0.0.1',
}) async {
  final launcher = _LaunchCapture();
  final flow = OAuthLoopbackFlow(
    timeout: timeout,
    authorizationLauncher: launcher.call,
  );
  final result = flow.start(
    authorizationEndpoint: _authorizationEndpoint,
    clientId: 'client-id',
    scope: googleTasksOAuthScope,
    redirectHost: redirectHost,
  );
  final authorizationUri = await launcher.authorizationUri;
  final redirectUri = Uri.parse(
    authorizationUri.queryParameters['redirect_uri']!,
  );
  return _StartedFlow(
    flow: flow,
    result: result,
    port: redirectUri.port,
    state: authorizationUri.queryParameters['state']!,
  );
}

class _StartedFlow {
  const _StartedFlow({
    required this.flow,
    required this.result,
    required this.port,
    required this.state,
  });

  final OAuthLoopbackFlow flow;
  final Future<OAuthLoopbackResult> result;
  final int port;
  final String state;

  Uri callbackUri({required String code, String? state}) {
    return Uri.http('127.0.0.1:$port', '/', {
      'state': state ?? this.state,
      'code': code,
    });
  }
}

class _LaunchCapture {
  final _authorizationUri = Completer<Uri>();
  var launchCount = 0;

  Future<Uri> get authorizationUri => _authorizationUri.future;

  Future<bool> call(Uri authorizationUri) async {
    launchCount += 1;
    if (!_authorizationUri.isCompleted) {
      _authorizationUri.complete(authorizationUri);
    }
    return true;
  }
}

final _authorizationEndpoint = Uri.parse('https://accounts.example.test/oauth');
