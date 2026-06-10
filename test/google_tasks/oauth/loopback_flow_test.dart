import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_models.dart';

void main() {
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

  test('state mismatch reports controlled OAuth error', () async {
    final started = await _startFlow();

    final response = await http.get(
      started.callbackUri(code: 'code', state: 'wrong-state'),
    );
    expect(response.statusCode, HttpStatus.badRequest);

    await expectLater(
      started.result,
      throwsA(
        isA<OAuthException>().having(
          (error) => error.code,
          'code',
          'OAuthCallbackStateMismatch',
        ),
      ),
    );
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
