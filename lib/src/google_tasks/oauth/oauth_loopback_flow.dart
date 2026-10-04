import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:busymax/src/core/auth/oauth_models.dart';
import 'pkce.dart';
import '../../core/auth/authorization_attempt.dart';

const googleTasksOAuthScope = 'https://www.googleapis.com/auth/tasks';
const googleSignInCallbackNotReceivedMessage =
    'Google sign-in callback was not received by BusyMax. Try signing in '
    'again. If the browser opened an old tab, close it and start sign-in '
    'again.';

class OAuthLoopbackFlow {
  OAuthLoopbackFlow({
    this.timeout = const Duration(minutes: 5),
    Future<bool> Function(Uri authorizationUri)? authorizationLauncher,
  }) : _authorizationLauncher =
           authorizationLauncher ?? _defaultAuthorizationLauncher;

  final Duration timeout;
  final Future<bool> Function(Uri authorizationUri) _authorizationLauncher;
  final Logger _logger = Logger('OAuthLoopbackFlow');

  _LoopbackInvocation? _current;

  Future<OAuthLoopbackResult> start({
    required Uri authorizationEndpoint,
    required String clientId,
    required String scope,
    String redirectHost = '127.0.0.1',
    String signInCancelledMessage = 'Google sign-in was cancelled.',
    String callbackNotReceivedMessage = googleSignInCallbackNotReceivedMessage,
    String serverStartFailureMessage =
        'Could not start the local Google sign-in callback listener.',
    String browserLaunchFailureMessage =
        'Could not open the browser for Google sign-in.',
    Map<String, String> extraAuthorizationParameters = const {},
    String? loginHint,
    AuthorizationAttempt? attempt,
  }) {
    final captured =
        attempt ??
        AuthorizationAttempt(
          nowUtc: () => DateTime.now().toUtc(),
          lifetime: timeout,
        );
    captured.check();
    if (_current case final current? when !current.attempt.cancelled) {
      if (attempt == null) captured.dispose();
      throw const OAuthException(
        'OAuthServerAlreadyRunning',
        'An OAuth sign-in attempt is already running.',
      );
    }
    final invocation = _LoopbackInvocation(captured);
    _current = invocation;
    unawaited(captured.cancellation.then((_) => _closeInvocation(invocation)));
    final operation =
        _start(
          invocation,
          authorizationEndpoint: authorizationEndpoint,
          clientId: clientId,
          scope: scope,
          redirectHost: redirectHost,
          signInCancelledMessage: signInCancelledMessage,
          callbackNotReceivedMessage: callbackNotReceivedMessage,
          serverStartFailureMessage: serverStartFailureMessage,
          browserLaunchFailureMessage: browserLaunchFailureMessage,
          extraAuthorizationParameters: extraAuthorizationParameters,
          loginHint: loginHint,
        ).whenComplete(() async {
          await _closeInvocation(invocation);
          if (identical(_current, invocation)) _current = null;
          if (attempt == null) captured.dispose();
        });
    unawaited(
      operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    return operation;
  }

  Future<OAuthLoopbackResult> _start(
    _LoopbackInvocation invocation, {
    required Uri authorizationEndpoint,
    required String clientId,
    required String scope,
    required String redirectHost,
    required String signInCancelledMessage,
    required String callbackNotReceivedMessage,
    required String serverStartFailureMessage,
    required String browserLaunchFailureMessage,
    required Map<String, String> extraAuthorizationParameters,
    String? loginHint,
  }) async {
    final attempt = invocation.attempt;
    final deadline = Timer(timeout, () {
      invocation.timedOut = true;
      attempt.cancel();
    });
    try {
      attempt.check();
      final binding =
          _bindServer(
            serverStartFailureMessage,
            redirectHost: redirectHost,
          ).then((server) async {
            if (attempt.cancelled) {
              await server.close(force: true);
              attempt.check();
            }
            invocation.server = server;
            return server;
          });
      final server = await attempt.wait(binding);
      final pkce = generatePkcePair();
      final state = generateOAuthState();
      final redirectUri = 'http://$redirectHost:${server.port}/';
      final authorizationUri = buildAuthorizationUri(
        authorizationEndpoint: authorizationEndpoint,
        clientId: clientId,
        redirectUri: redirectUri,
        scope: scope,
        codeChallenge: pkce.codeChallenge,
        state: state,
        extraParameters: extraAuthorizationParameters,
        loginHint: loginHint,
      );
      attempt.check();
      await attempt.wait(
        _launchBrowser(authorizationUri, browserLaunchFailureMessage),
      );
      await for (final request in server) {
        attempt.check();
        try {
          if (request.method != 'GET') {
            throw const OAuthException(
              'OAuthCallbackInvalidMethod',
              'Invalid callback method.',
            );
          }
          final callback = parseOAuthCallback(
            request.uri,
            expectedState: state,
            expectedPort: server.port,
            hostHeader: request.headers.value(HttpHeaders.hostHeader),
          );
          await attempt.wait(_writeBrowserResponse(request.response));
          return OAuthLoopbackResult(
            callback: callback,
            redirectUri: redirectUri,
            codeVerifier: pkce.codeVerifier,
          );
        } on OAuthException catch (error) {
          await attempt.wait(
            _writeBrowserErrorResponse(request.response, error),
          );
          if (_isTerminalCallbackError(error)) rethrow;
        }
      }
      attempt.check();
      throw OAuthException(
        'OAuthCallbackListenerClosed',
        callbackNotReceivedMessage,
      );
    } on Object catch (error) {
      if (invocation.timedOut ||
          (error is OAuthException &&
              error.classification == OAuthFailureKind.timeout)) {
        throw OAuthException(
          'OAuthCallbackTimeout',
          callbackNotReceivedMessage,
        );
      }
      attempt.check();
      rethrow;
    } finally {
      deadline.cancel();
    }
  }

  Future<void> cancel() => close();
  Future<void> cancelFor(AuthorizationAttempt attempt) async {
    if (_current case final current? when identical(current.attempt, attempt)) {
      attempt.cancel();
      await _closeInvocation(current);
    }
  }

  Future<void> close() async {
    final current = _current;
    if (current == null) return;
    current.attempt.cancel();
    await _closeInvocation(current);
  }

  Future<void> _closeInvocation(_LoopbackInvocation invocation) async {
    final server = invocation.server;
    invocation.server = null;
    try {
      await server?.close(force: true);
    } on IOException {
      /* already closed */
    }
  }

  Future<HttpServer> _bindServer(
    String failureMessage, {
    required String redirectHost,
  }) async {
    try {
      if (redirectHost == 'localhost') {
        try {
          return await HttpServer.bind(
            InternetAddress.loopbackIPv6,
            0,
            v6Only: false,
            shared: false,
          );
        } on IOException {
          return await HttpServer.bind(
            InternetAddress.loopbackIPv4,
            0,
            shared: false,
          );
        }
      }
      return await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: false,
      );
    } on HttpException {
      throw OAuthException('OAuthServerStartFailed', failureMessage);
    } on IOException {
      throw OAuthException('OAuthServerStartFailed', failureMessage);
    }
  }

  Future<void> _launchBrowser(
    Uri authorizationUri,
    String failureMessage,
  ) async {
    try {
      final launched = await _authorizationLauncher(
        authorizationUri,
      ).timeout(const Duration(seconds: 20));
      _logger.info('OAuth browser launch result: $launched');
      if (!launched) {
        throw OAuthException('OAuthBrowserLaunchFailed', failureMessage);
      }
    } on OAuthException {
      rethrow;
    } on Object {
      throw OAuthException('OAuthBrowserLaunchFailed', failureMessage);
    }
  }
}

final class _LoopbackInvocation {
  _LoopbackInvocation(this.attempt);
  final AuthorizationAttempt attempt;
  HttpServer? server;
  bool timedOut = false;
}

class OAuthLoopbackResult {
  const OAuthLoopbackResult({
    required this.callback,
    required this.redirectUri,
    required this.codeVerifier,
  });

  final OAuthCallbackResult callback;
  final String redirectUri;
  final String codeVerifier;
}

Uri buildAuthorizationUri({
  required Uri authorizationEndpoint,
  required String clientId,
  required String redirectUri,
  required String scope,
  required String codeChallenge,
  required String state,
  Map<String, String> extraParameters = const {},
  String? loginHint,
}) {
  return authorizationEndpoint.replace(
    queryParameters: {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': scope,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
      ...extraParameters,
      if (loginHint != null && loginHint.trim().isNotEmpty)
        'login_hint': loginHint.trim(),
    },
  );
}

OAuthCallbackResult parseOAuthCallback(
  Uri uri, {
  required String expectedState,
  required int expectedPort,
  String? hostHeader,
}) {
  final effectiveHost = hostHeader ?? uri.authority;
  final allowedHosts = {'127.0.0.1:$expectedPort', 'localhost:$expectedPort'};
  if (!allowedHosts.contains(effectiveHost)) {
    throw const OAuthException(
      'OAuthCallbackError',
      'OAuth callback host was not loopback.',
    );
  }

  if (uri.path != '/' && uri.path.isNotEmpty) {
    throw const OAuthException(
      'OAuthCallbackInvalidPath',
      'OAuth callback path was invalid.',
    );
  }

  if (uri.hasFragment ||
      uri.queryParametersAll.values.any((values) => values.length != 1) ||
      (uri.queryParameters.containsKey('code') &&
          uri.queryParameters.containsKey('error'))) {
    throw const OAuthException(
      'OAuthCallbackContradictoryParameters',
      'Invalid callback parameters.',
    );
  }
  final state = uri.queryParameters['state'];
  if (state == null || !_constantTimeEquals(state, expectedState)) {
    throw const OAuthException(
      'OAuthCallbackStateMismatch',
      'OAuth callback state did not match the sign-in attempt.',
    );
  }

  final error = uri.queryParameters['error'];
  if (error != null && error.isNotEmpty) {
    throw authorizationOutcomeFailure(
      code: 'OAuthCallbackAuthorizationFailed',
      providerError: error,
    );
  }

  final code = uri.queryParameters['code'];
  if (code == null || code.isEmpty) {
    throw const OAuthException(
      'OAuthCallbackMissingCode',
      'OAuth callback did not include an authorization code.',
    );
  }

  return OAuthCallbackResult(code: code, scope: uri.queryParameters['scope']);
}

bool _constantTimeEquals(String left, String right) {
  if (left.length != right.length) {
    return false;
  }

  var diff = 0;
  for (var i = 0; i < left.length; i += 1) {
    diff |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
  }
  return diff == 0;
}

bool _isTerminalCallbackError(OAuthException error) {
  if (error is OAuthAuthorizationException) return true;
  return switch (error.code) {
    'OAuthSignInCancelled' => true,
    _ => false,
  };
}

Future<bool> _defaultAuthorizationLauncher(Uri authorizationUri) async {
  return launchUrl(authorizationUri, mode: LaunchMode.externalApplication);
}

Future<void> _writeBrowserResponse(HttpResponse response) async {
  response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType.html
    ..write(
      '<!doctype html><html><body>'
      '<h1>BusyMax sign-in complete</h1>'
      '<p>You can close this browser tab.</p>'
      '</body></html>',
    );
  await response.close();
}

Future<void> _writeBrowserErrorResponse(
  HttpResponse response,
  OAuthException error,
) async {
  response
    ..statusCode = HttpStatus.badRequest
    ..headers.contentType = ContentType.html
    ..write(
      '<!doctype html><html><body>'
      '<h1>BusyMax sign-in could not complete</h1>'
      '<p>${_htmlEscape(error.message)}</p>'
      '</body></html>',
    );
  await response.close();
}

String _htmlEscape(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
