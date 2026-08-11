import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../providers/account_authority.dart';
import '../dav_errors.dart';
import '../http/dav_http_transport.dart';

typedef NextcloudBrowserLauncher = Future<bool> Function(Uri loginUri);
typedef NextcloudLoginDelay = Future<void> Function(Duration duration);

final class NextcloudLoginFlowResult {
  NextcloudLoginFlowResult({
    required this.canonicalServer,
    required String loginName,
    required String appPassword,
  }) : loginName = loginName.trim(),
       appPassword = appPassword.trim() {
    if (this.loginName.isEmpty || this.appPassword.isEmpty) {
      throw const DavException(
        kind: DavErrorKind.authentication,
        code: 'NextcloudLoginFlowMalformedCredential',
        safeMessage: 'Nextcloud returned an incomplete app credential.',
      );
    }
  }

  final Uri canonicalServer;
  final String loginName;
  final String appPassword;

  @override
  String toString() => 'NextcloudLoginFlowResult(credentials: [REDACTED])';
}

final class NextcloudLoginFlowV2 {
  NextcloudLoginFlowV2({
    required http.Client client,
    NextcloudBrowserLauncher? browserLauncher,
    NextcloudLoginDelay? delay,
    DateTime Function()? nowUtc,
    this.pollInterval = const Duration(seconds: 1),
    this.operationTimeout = const Duration(minutes: 10),
    this.responseTimeout = const Duration(seconds: 30),
    this.maximumResponseBytes = 64 * 1024,
    this.maximumRedirects = 3,
  }) : _client = client,
       _browserLauncher = browserLauncher ?? _launchExternalBrowser,
       _delay = delay ?? Future<void>.delayed,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()) {
    if (pollInterval <= Duration.zero ||
        operationTimeout <= Duration.zero ||
        responseTimeout <= Duration.zero ||
        maximumResponseBytes < 1 ||
        maximumRedirects < 0) {
      throw ArgumentError('Nextcloud Login Flow limits must be positive.');
    }
  }

  final http.Client _client;
  final NextcloudBrowserLauncher _browserLauncher;
  final NextcloudLoginDelay _delay;
  final DateTime Function() _nowUtc;
  final Duration pollInterval;
  final Duration operationTimeout;
  final Duration responseTimeout;
  final int maximumResponseBytes;
  final int maximumRedirects;

  Future<NextcloudLoginFlowResult>? _activeOperation;
  DavCancellationToken? _activeCancellation;

  Future<NextcloudLoginFlowResult> start(String enteredServer) {
    if (_activeOperation != null) {
      throw const DavException(
        kind: DavErrorKind.conflict,
        code: 'NextcloudLoginFlowAlreadyRunning',
        safeMessage: 'A Nextcloud connection is already in progress.',
      );
    }
    final cancellation = DavCancellationToken();
    _activeCancellation = cancellation;
    final operation = _run(enteredServer, cancellation);
    _activeOperation = operation;
    unawaited(
      operation.then<void>(
        (_) => _clear(operation),
        onError: (_, _) => _clear(operation),
      ),
    );
    return operation;
  }

  void cancel() => _activeCancellation?.cancel();

  Future<NextcloudLoginFlowResult> _run(
    String enteredServer,
    DavCancellationToken cancellation,
  ) async {
    final baseServer = normalizeNextcloudLoginServer(enteredServer);
    final startUri = _appendPath(baseServer, 'index.php/login/v2');
    final deadline = _nowUtc().toUtc().add(operationTimeout);
    cancellation.throwIfCancelled();
    final startResponse = await _postFollowingRedirects(
      startUri,
      body: null,
      trustedBase: baseServer,
      cancellation: cancellation,
    );
    if (startResponse.statusCode != HttpStatus.ok) {
      throw DavException(
        kind: startResponse.statusCode >= 500
            ? DavErrorKind.server
            : DavErrorKind.authentication,
        code: 'NextcloudLoginFlowStartRejected',
        safeMessage: 'Nextcloud could not start browser authorization.',
        statusCode: startResponse.statusCode,
      );
    }
    final startJson = _jsonObject(startResponse.bodyBytes);
    final pollJson = _jsonObjectValue(startJson, 'poll');
    final token = _requiredJsonString(pollJson, 'token');
    final pollEndpoint = _validatedFlowUri(
      _requiredJsonString(pollJson, 'endpoint'),
      responseUri: startResponse.requestUri,
      installationPath: baseServer.path,
      allowQuery: false,
    );
    final loginUri = _validatedFlowUri(
      _requiredJsonString(startJson, 'login'),
      responseUri: startResponse.requestUri,
      installationPath: baseServer.path,
      allowQuery: true,
    );
    cancellation.throwIfCancelled();
    final launched = await _browserLauncher(loginUri);
    if (!launched) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'NextcloudLoginBrowserLaunchFailed',
        safeMessage: 'The Nextcloud sign-in page could not be opened.',
      );
    }

    while (true) {
      cancellation.throwIfCancelled();
      if (!_nowUtc().toUtc().isBefore(deadline)) {
        throw const DavException(
          kind: DavErrorKind.timeout,
          code: 'NextcloudLoginFlowExpired',
          safeMessage: 'The Nextcloud sign-in request expired.',
        );
      }
      final pollResponse = await _postFollowingRedirects(
        pollEndpoint,
        body: {'token': token},
        trustedBase: pollEndpoint.replace(path: baseServer.path),
        cancellation: cancellation,
      );
      if (pollResponse.statusCode == HttpStatus.notFound) {
        await _delay(pollInterval);
        continue;
      }
      if (pollResponse.statusCode != HttpStatus.ok) {
        throw DavException(
          kind: pollResponse.statusCode >= 500
              ? DavErrorKind.server
              : DavErrorKind.authentication,
          code: 'NextcloudLoginFlowRejected',
          safeMessage: 'Nextcloud did not complete browser authorization.',
          statusCode: pollResponse.statusCode,
        );
      }
      final completed = _jsonObject(pollResponse.bodyBytes);
      final normalizedAuthority = normalizeNextcloudServerAuthority(
        _requiredJsonString(completed, 'server'),
      );
      return NextcloudLoginFlowResult(
        canonicalServer: Uri.parse(normalizedAuthority),
        loginName: _requiredJsonString(completed, 'loginName'),
        appPassword: _requiredJsonString(completed, 'appPassword'),
      );
    }
  }

  Future<_FlowResponse> _postFollowingRedirects(
    Uri initialUri, {
    required Map<String, String>? body,
    required Uri trustedBase,
    required DavCancellationToken cancellation,
  }) async {
    var current = initialUri;
    final visited = <String>{};
    for (var redirects = 0; redirects <= maximumRedirects; redirects += 1) {
      cancellation.throwIfCancelled();
      if (!visited.add(current.toString())) {
        throw _redirectError('NextcloudLoginRedirectLoop');
      }
      if (!_safeHttps(current) ||
          !_sameOrigin(current, trustedBase) ||
          !_withinInstallationPath(current.path, trustedBase.path)) {
        throw _redirectError('NextcloudLoginRedirectRejected');
      }
      final request = http.Request('POST', current)
        ..followRedirects = false
        ..headers['accept'] = 'application/json';
      if (body != null) {
        request.headers['content-type'] =
            'application/x-www-form-urlencoded; charset=utf-8';
        request.body = _formEncode(body);
      }
      http.StreamedResponse streamed;
      try {
        streamed = await _client.send(request).timeout(responseTimeout);
      } on TimeoutException {
        throw const DavException(
          kind: DavErrorKind.timeout,
          code: 'NextcloudLoginResponseTimeout',
          safeMessage: 'The Nextcloud login server did not respond in time.',
        );
      } on HandshakeException {
        throw const DavException(
          kind: DavErrorKind.tls,
          code: 'DavTlsFailure',
          safeMessage: 'The Nextcloud TLS connection could not be verified.',
        );
      } on Object {
        throw const DavException(
          kind: DavErrorKind.network,
          code: 'DavTransientNetwork',
          safeMessage: 'The Nextcloud login server could not be reached.',
        );
      }
      final bytes = await _readBody(streamed, cancellation);
      if (!_isRedirect(streamed.statusCode)) {
        return _FlowResponse(
          statusCode: streamed.statusCode,
          bodyBytes: bytes,
          requestUri: current,
        );
      }
      final location = streamed.headers['location'];
      if (location == null || redirects == maximumRedirects) {
        throw _redirectError('NextcloudLoginRedirectLimitExceeded');
      }
      final destination = current.resolve(location);
      if (!_safeHttps(destination) ||
          !_withinInstallationPath(destination.path, trustedBase.path) ||
          !_sameOrigin(destination, trustedBase)) {
        throw _redirectError('NextcloudLoginRedirectRejected');
      }
      current = destination;
    }
    throw StateError('Unreachable Nextcloud redirect state.');
  }

  Future<Uint8List> _readBody(
    http.StreamedResponse response,
    DavCancellationToken cancellation,
  ) async {
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    try {
      await for (final chunk in response.stream.timeout(responseTimeout)) {
        cancellation.throwIfCancelled();
        length += chunk.length;
        if (length > maximumResponseBytes) {
          throw const DavException(
            kind: DavErrorKind.responseTooLarge,
            code: 'NextcloudLoginResponseTooLarge',
            safeMessage: 'The Nextcloud login response was too large.',
          );
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } on TimeoutException {
      throw const DavException(
        kind: DavErrorKind.timeout,
        code: 'NextcloudLoginResponseTimeout',
        safeMessage: 'The Nextcloud login server did not respond in time.',
      );
    }
  }

  void _clear(Future<NextcloudLoginFlowResult> operation) {
    if (identical(_activeOperation, operation)) {
      _activeOperation = null;
      _activeCancellation = null;
    }
  }
}

Uri normalizeNextcloudLoginServer(String enteredServer) {
  var source = enteredServer.trim();
  if (source.isEmpty) {
    throw const FormatException('Enter a Nextcloud server address.');
  }
  if (!source.contains('://')) source = 'https://$source';
  final parsed = Uri.tryParse(source);
  if (parsed == null ||
      (parsed.scheme != 'http' && parsed.scheme != 'https') ||
      parsed.host.isEmpty ||
      parsed.userInfo.isNotEmpty ||
      parsed.hasQuery ||
      parsed.hasFragment) {
    throw const FormatException('Enter a valid Nextcloud HTTPS server.');
  }
  var path = parsed.normalizePath().path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  path = _nextcloudInstallationPath(path);
  return Uri(
    scheme: 'https',
    host: parsed.host.toLowerCase(),
    port: parsed.hasPort && parsed.port != 443 ? parsed.port : null,
    path: path == '/' ? '' : path,
  );
}

String _nextcloudInstallationPath(String enteredPath) {
  final normalized = enteredPath.toLowerCase();
  const davEndpoints = [
    '/remote.php/dav',
    '/remote.php/caldav',
    '/remote.php/webdav',
  ];
  for (final endpoint in davEndpoints) {
    final index = normalized.indexOf(endpoint);
    if (index < 0) continue;
    final endpointEnd = index + endpoint.length;
    if (endpointEnd == normalized.length ||
        normalized.codeUnitAt(endpointEnd) == 0x2f) {
      return enteredPath.substring(0, index);
    }
  }
  return enteredPath;
}

final class _FlowResponse {
  const _FlowResponse({
    required this.statusCode,
    required this.bodyBytes,
    required this.requestUri,
  });

  final int statusCode;
  final Uint8List bodyBytes;
  final Uri requestUri;
}

Map<String, Object?> _jsonObject(Uint8List bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (decoded is! Map) throw const FormatException();
    return decoded.cast<String, Object?>();
  } on Object {
    throw const DavException(
      kind: DavErrorKind.protocol,
      code: 'NextcloudLoginMalformedResponse',
      safeMessage: 'Nextcloud returned a malformed login response.',
    );
  }
}

Map<String, Object?> _jsonObjectValue(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw const DavException(
      kind: DavErrorKind.protocol,
      code: 'NextcloudLoginMalformedResponse',
      safeMessage: 'Nextcloud returned a malformed login response.',
    );
  }
  return value.cast<String, Object?>();
}

String _requiredJsonString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > 16384) {
    throw const DavException(
      kind: DavErrorKind.protocol,
      code: 'NextcloudLoginMalformedResponse',
      safeMessage: 'Nextcloud returned a malformed login response.',
    );
  }
  return value;
}

Uri _validatedFlowUri(
  String source, {
  required Uri responseUri,
  required String installationPath,
  required bool allowQuery,
}) {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      !_safeHttps(uri) ||
      !_sameOrigin(uri, responseUri) ||
      !_withinInstallationPath(uri.path, installationPath) ||
      (!allowQuery && uri.hasQuery)) {
    throw _redirectError('NextcloudLoginEndpointRejected');
  }
  return uri;
}

Uri _appendPath(Uri base, String suffix) {
  final path = base.path.isEmpty
      ? '/$suffix'
      : '${base.path.endsWith('/') ? base.path : '${base.path}/'}$suffix';
  return base.replace(path: path);
}

String _formEncode(Map<String, String> values) => values.entries
    .map(
      (entry) =>
          '${Uri.encodeQueryComponent(entry.key)}='
          '${Uri.encodeQueryComponent(entry.value)}',
    )
    .join('&');

bool _safeHttps(Uri uri) =>
    uri.scheme.toLowerCase() == 'https' &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty &&
    !uri.hasFragment;

bool _sameOrigin(Uri left, Uri right) =>
    left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
    left.host.toLowerCase() == right.host.toLowerCase() &&
    left.port == right.port;

bool _withinInstallationPath(String candidate, String installationPath) {
  var base = installationPath;
  while (base.length > 1 && base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  if (base.isEmpty || base == '/') return candidate.startsWith('/');
  return candidate == base || candidate.startsWith('$base/');
}

bool _isRedirect(int status) =>
    status == HttpStatus.movedPermanently ||
    status == HttpStatus.found ||
    status == HttpStatus.temporaryRedirect ||
    status == HttpStatus.permanentRedirect;

DavException _redirectError(String code) => DavException(
  kind: DavErrorKind.redirectRejected,
  code: code,
  safeMessage: 'Nextcloud returned an untrusted login destination.',
);

Future<bool> _launchExternalBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
