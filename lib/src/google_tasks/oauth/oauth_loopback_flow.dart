import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import 'oauth_models.dart';
import 'pkce.dart';

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

  HttpServer? _server;
  Future<OAuthLoopbackResult>? _activeOperation;
  var _cancelRequested = false;

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
  }) {
    if (_activeOperation != null) {
      throw const OAuthException(
        'OAuthServerAlreadyRunning',
        'An OAuth sign-in attempt is already running.',
      );
    }

    _cancelRequested = false;
    final operation = _start(
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
    );
    _activeOperation = operation;
    unawaited(
      operation.then<void>(
        (_) => _clearActiveOperation(operation),
        onError: (_, _) => _clearActiveOperation(operation),
      ),
    );
    return operation;
  }

  Future<OAuthLoopbackResult> _start({
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
    final pkce = generatePkcePair();
    final state = generateOAuthState();
    final server = await _bindServer(
      serverStartFailureMessage,
      redirectHost: redirectHost,
    );
    _server = server;
    _logger.info('OAuth loopback server selected port ${server.port}');

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
    _logger.info(
      'OAuth authorization URL built: '
      '${_redactedAuthorizationUri(authorizationUri)}',
    );

    try {
      if (_cancelRequested) {
        throw OAuthException('OAuthSignInCancelled', signInCancelledMessage);
      }
      await _launchBrowser(authorizationUri, browserLaunchFailureMessage);

      await for (final request in server.timeout(timeout)) {
        _logger.info(
          'OAuth callback request received: '
          'method=${request.method} path=${request.uri.path} '
          'hasQuery=${request.uri.hasQuery} '
          'host=${request.headers.value(HttpHeaders.hostHeader) ?? ''}',
        );

        try {
          final callback = parseOAuthCallback(
            request.uri,
            expectedState: state,
            expectedPort: server.port,
            hostHeader: request.headers.value(HttpHeaders.hostHeader),
          );
          await _writeBrowserResponse(request.response);
          _logger.info('OAuth callback accepted');
          return OAuthLoopbackResult(
            callback: callback,
            redirectUri: redirectUri,
            codeVerifier: pkce.codeVerifier,
          );
        } on OAuthException catch (error) {
          _logger.warning('OAuth callback rejected: ${error.code}');
          await _writeBrowserErrorResponse(request.response, error);
          if (_isTerminalCallbackError(error)) {
            rethrow;
          }
        }
      }

      if (_cancelRequested) {
        throw OAuthException('OAuthSignInCancelled', signInCancelledMessage);
      }
      throw OAuthException(
        'OAuthCallbackListenerClosed',
        callbackNotReceivedMessage,
      );
    } on TimeoutException {
      throw OAuthException('OAuthCallbackTimeout', callbackNotReceivedMessage);
    } on HttpException {
      if (_cancelRequested) {
        throw OAuthException('OAuthSignInCancelled', signInCancelledMessage);
      }
      throw OAuthException(
        'OAuthCallbackListenerClosed',
        callbackNotReceivedMessage,
      );
    } finally {
      await close();
    }
  }

  Future<void> cancel() => close();

  Future<void> close() async {
    _cancelRequested = true;
    final server = _server;
    _server = null;
    if (server == null) {
      return;
    }

    try {
      await server.close(force: true);
      _logger.info('OAuth loopback server closed');
    } on HttpException {
      _logger.warning('OAuth loopback server close ignored; already closed');
    } on IOException {
      _logger.warning('OAuth loopback server close ignored; already closed');
    }
  }

  void _clearActiveOperation(Future<OAuthLoopbackResult> operation) {
    if (identical(_activeOperation, operation)) {
      _activeOperation = null;
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
      final launched = await _authorizationLauncher(authorizationUri);
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

  final state = uri.queryParameters['state'];
  if (state == null || !_constantTimeEquals(state, expectedState)) {
    throw const OAuthException(
      'OAuthCallbackStateMismatch',
      'OAuth callback state did not match the sign-in attempt.',
    );
  }

  final error = uri.queryParameters['error'];
  if (error != null && error.isNotEmpty) {
    throw OAuthException('OAuthCallbackProviderError', error);
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
  return switch (error.code) {
    'OAuthCallbackStateMismatch' ||
    'OAuthCallbackProviderError' ||
    'OAuthCallbackMissingCode' => true,
    _ => false,
  };
}

Uri _redactedAuthorizationUri(Uri uri) {
  return uri.replace(
    queryParameters: {
      for (final entry in uri.queryParameters.entries)
        entry.key: switch (entry.key) {
          'code_challenge' || 'login_hint' || 'state' => '[REDACTED]',
          _ => entry.value,
        },
    },
  );
}

Future<bool> _defaultAuthorizationLauncher(Uri authorizationUri) async {
  if (await launchUrl(authorizationUri, mode: LaunchMode.externalApplication)) {
    return true;
  }

  await Process.start('xdg-open', [authorizationUri.toString()]);
  return true;
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
