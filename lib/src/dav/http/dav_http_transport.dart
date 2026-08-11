import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../dav/dav_errors.dart';
import '../dav_provider_profile.dart';

enum DavRetryClass { safeRead, conditionalMutation, never }

final class DavCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled({String? correlationId}) {
    if (_cancelled) {
      throw DavException(
        kind: DavErrorKind.cancelled,
        code: 'DavOperationCancelled',
        safeMessage: 'The DAV operation was cancelled.',
        correlationId: correlationId,
      );
    }
  }
}

final class DavBasicCredential {
  DavBasicCredential({required String username, required String password})
    : username = username.trim(),
      password = password.trim() {
    if (this.username.isEmpty || this.password.isEmpty) {
      throw ArgumentError('DAV credentials must not be empty.');
    }
  }

  final String username;
  final String password;

  String get authorizationValue =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  @override
  String toString() => 'DavBasicCredential([REDACTED])';
}

final class DavRequest {
  DavRequest({
    required this.method,
    required this.uri,
    required this.accountId,
    required this.correlationId,
    this.collectionId,
    this.headers = const {},
    this.bodyBytes,
    this.retryClass = DavRetryClass.never,
  }) {
    if (uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        uri,
        'uri',
        'URI user information is forbidden.',
      );
    }
    if (headers.keys.any((name) => name.toLowerCase() == 'authorization')) {
      throw ArgumentError(
        'Authorization is owned by DavHttpTransport and cannot be supplied.',
      );
    }
  }

  factory DavRequest.xml({
    required String method,
    required Uri uri,
    required String accountId,
    required String correlationId,
    required String body,
    String? collectionId,
    Map<String, String> headers = const {},
    DavRetryClass retryClass = DavRetryClass.safeRead,
  }) => DavRequest(
    method: method,
    uri: uri,
    accountId: accountId,
    correlationId: correlationId,
    collectionId: collectionId,
    headers: {'content-type': 'application/xml; charset=utf-8', ...headers},
    bodyBytes: Uint8List.fromList(utf8.encode(body)),
    retryClass: retryClass,
  );

  factory DavRequest.icalendar({
    required String method,
    required Uri uri,
    required String accountId,
    required String correlationId,
    required String body,
    required String collectionId,
    required Map<String, String> headers,
  }) => DavRequest(
    method: method,
    uri: uri,
    accountId: accountId,
    correlationId: correlationId,
    collectionId: collectionId,
    headers: {'content-type': 'text/calendar; charset=utf-8', ...headers},
    bodyBytes: Uint8List.fromList(utf8.encode(body)),
    retryClass: DavRetryClass.conditionalMutation,
  );

  final String method;
  final Uri uri;
  final String accountId;
  final String correlationId;
  final String? collectionId;
  final Map<String, String> headers;
  final Uint8List? bodyBytes;
  final DavRetryClass retryClass;
}

final class DavResponse {
  const DavResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
    required this.requestUri,
    required this.correlationId,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Uint8List bodyBytes;
  final Uri requestUri;
  final String correlationId;

  String get bodyText => utf8.decode(bodyBytes, allowMalformed: false);

  String? get etag => headers['etag'];
}

final class DavTransportLimits {
  const DavTransportLimits({
    this.connectTimeout = const Duration(seconds: 15),
    this.responseTimeout = const Duration(seconds: 30),
    this.operationTimeout = const Duration(minutes: 2),
    this.maximumResponseBytes = 16 * 1024 * 1024,
    this.maximumRedirects = 5,
    this.maximumReadAttempts = 3,
    this.maximumConcurrentPerAccount = 4,
    this.maximumConcurrentPerCollection = 2,
  });

  final Duration connectTimeout;
  final Duration responseTimeout;
  final Duration operationTimeout;
  final int maximumResponseBytes;
  final int maximumRedirects;
  final int maximumReadAttempts;
  final int maximumConcurrentPerAccount;
  final int maximumConcurrentPerCollection;
}

typedef DavDelay = Future<void> Function(Duration duration);

final class DavHttpTransport {
  DavHttpTransport({
    required http.Client client,
    required DavProviderProfile profile,
    required Uri accountAuthority,
    DavTransportLimits limits = const DavTransportLimits(),
    DavDelay? delay,
    Random? random,
    DateTime Function()? nowUtc,
  }) : _client = client,
       _profile = profile,
       _accountAuthority = accountAuthority,
       _limits = limits,
       _delay = delay ?? Future<void>.delayed,
       _random = random ?? Random.secure(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final http.Client _client;
  final DavProviderProfile _profile;
  final Uri _accountAuthority;
  final DavTransportLimits _limits;
  final DavDelay _delay;
  final Random _random;
  final DateTime Function() _nowUtc;
  final _accountSemaphores = <String, _AsyncSemaphore>{};
  final _collectionSemaphores = <String, _AsyncSemaphore>{};

  Future<DavResponse> send(
    DavRequest request, {
    required DavBasicCredential credential,
    DavCancellationToken? cancellationToken,
  }) {
    final token = cancellationToken ?? DavCancellationToken();
    return _withConcurrencyLimit(request, () {
      return _sendWithRetry(request, credential, token).timeout(
        _limits.operationTimeout,
        onTimeout: () => throw DavException(
          kind: DavErrorKind.timeout,
          code: 'DavOperationTimeout',
          safeMessage: 'The DAV operation timed out.',
          correlationId: request.correlationId,
        ),
      );
    });
  }

  Future<T> _withConcurrencyLimit<T>(
    DavRequest request,
    Future<T> Function() action,
  ) async {
    final account = _accountSemaphores.putIfAbsent(
      request.accountId,
      () => _AsyncSemaphore(_limits.maximumConcurrentPerAccount),
    );
    await account.acquire();
    _AsyncSemaphore? collection;
    try {
      final collectionId = request.collectionId;
      if (collectionId != null) {
        collection = _collectionSemaphores.putIfAbsent(
          '${request.accountId}|$collectionId',
          () => _AsyncSemaphore(_limits.maximumConcurrentPerCollection),
        );
        await collection.acquire();
      }
      return await action();
    } finally {
      collection?.release();
      account.release();
    }
  }

  Future<DavResponse> _sendWithRetry(
    DavRequest request,
    DavBasicCredential credential,
    DavCancellationToken token,
  ) async {
    final attempts = request.retryClass == DavRetryClass.safeRead
        ? _limits.maximumReadAttempts
        : 1;
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt += 1) {
      token.throwIfCancelled(correlationId: request.correlationId);
      try {
        final response = await _sendFollowingRedirects(
          request,
          credential,
          token,
        );
        if (!_isRetryableStatus(response.statusCode) || attempt == attempts) {
          return response;
        }
        final honorsRetryAfter =
            response.statusCode == HttpStatus.tooManyRequests ||
            response.statusCode == HttpStatus.serviceUnavailable;
        await _delay(
          _retryDelay(
            honorsRetryAfter ? response.headers['retry-after'] : null,
            attempt,
          ),
        );
      } on DavException catch (error) {
        lastError = error;
        if (attempt == attempts || !_isRetryableException(error)) {
          rethrow;
        }
        await _delay(_retryDelay(null, attempt));
      } on Object catch (error) {
        lastError = error;
        if (attempt == attempts) {
          throw _networkException(error, request.correlationId);
        }
        await _delay(_retryDelay(null, attempt));
      }
    }
    throw _networkException(lastError, request.correlationId);
  }

  Future<DavResponse> _sendFollowingRedirects(
    DavRequest request,
    DavBasicCredential credential,
    DavCancellationToken token,
  ) async {
    var currentUri = request.uri;
    var method = request.method.toUpperCase();
    var body = request.bodyBytes;
    final visited = <String>{};

    for (
      var redirectCount = 0;
      redirectCount <= _limits.maximumRedirects;
      redirectCount += 1
    ) {
      token.throwIfCancelled(correlationId: request.correlationId);
      if (!visited.add(currentUri.toString())) {
        throw DavException(
          kind: DavErrorKind.redirectLoop,
          code: 'DavRedirectLoop',
          safeMessage: 'The DAV server returned a redirect loop.',
          correlationId: request.correlationId,
        );
      }
      if (!_profile.isTrustedCredentialDestination(
        currentUri,
        accountAuthority: _accountAuthority,
      )) {
        throw DavException(
          kind: DavErrorKind.redirectRejected,
          code: 'DavRedirectDestinationRejected',
          safeMessage: 'The DAV server redirected to an untrusted destination.',
          correlationId: request.correlationId,
        );
      }

      final outbound = http.Request(method, currentUri)
        ..followRedirects = false
        ..headers.addAll(request.headers)
        ..headers['authorization'] = credential.authorizationValue
        ..headers['x-busymax-correlation-id'] = request.correlationId;
      if (body != null) {
        outbound.bodyBytes = body;
      }

      final streamed = await _client
          .send(outbound)
          .timeout(
            _limits.connectTimeout,
            onTimeout: () => throw DavException(
              kind: DavErrorKind.timeout,
              code: 'DavConnectTimeout',
              safeMessage:
                  'The DAV server did not accept a connection in time.',
              correlationId: request.correlationId,
            ),
          );
      final responseBytes = await _readBoundedBody(
        streamed,
        token,
        request.correlationId,
      );
      final headers = <String, String>{
        for (final entry in streamed.headers.entries)
          entry.key.toLowerCase(): entry.value,
      };

      if (!_isRedirect(streamed.statusCode)) {
        return DavResponse(
          statusCode: streamed.statusCode,
          headers: headers,
          bodyBytes: responseBytes,
          requestUri: currentUri,
          correlationId: request.correlationId,
        );
      }
      final location = headers['location'];
      if (location == null || location.trim().isEmpty) {
        throw DavException(
          kind: DavErrorKind.protocol,
          code: 'DavRedirectMissingLocation',
          safeMessage: 'The DAV server returned an invalid redirect.',
          statusCode: streamed.statusCode,
          correlationId: request.correlationId,
        );
      }
      if (redirectCount == _limits.maximumRedirects) {
        throw DavException(
          kind: DavErrorKind.redirectLoop,
          code: 'DavRedirectLimitExceeded',
          safeMessage: 'The DAV server returned too many redirects.',
          correlationId: request.correlationId,
        );
      }
      final destination = currentUri.resolve(location.trim());
      if (streamed.statusCode == HttpStatus.seeOther &&
          method != 'GET' &&
          method != 'HEAD') {
        throw DavException(
          kind: DavErrorKind.redirectRejected,
          code: 'DavMutationSeeOtherRejected',
          safeMessage: 'The DAV server returned an unsafe mutation redirect.',
          statusCode: streamed.statusCode,
          correlationId: request.correlationId,
        );
      }
      currentUri = destination;
    }
    throw StateError('Unreachable redirect loop termination.');
  }

  Future<Uint8List> _readBoundedBody(
    http.StreamedResponse response,
    DavCancellationToken token,
    String correlationId,
  ) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response.stream.timeout(
      _limits.responseTimeout,
    )) {
      token.throwIfCancelled(correlationId: correlationId);
      length += chunk.length;
      if (length > _limits.maximumResponseBytes) {
        throw DavException(
          kind: DavErrorKind.responseTooLarge,
          code: 'DavResponseTooLarge',
          safeMessage: 'The DAV response exceeded the configured size limit.',
          statusCode: response.statusCode,
          correlationId: correlationId,
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  bool _isRetryableStatus(int statusCode) =>
      statusCode == HttpStatus.tooManyRequests ||
      statusCode == HttpStatus.serviceUnavailable ||
      statusCode == HttpStatus.badGateway ||
      statusCode == HttpStatus.gatewayTimeout ||
      statusCode == HttpStatus.internalServerError;

  bool _isRetryableException(DavException error) =>
      error.kind == DavErrorKind.timeout ||
      error.kind == DavErrorKind.network ||
      error.kind == DavErrorKind.tls;

  Duration _retryDelay(String? retryAfter, int attempt) {
    final value = retryAfter?.trim() ?? '';
    final seconds = int.tryParse(value);
    if (seconds != null && seconds >= 0) {
      return Duration(seconds: min(seconds, 60));
    }
    if (value.isNotEmpty) {
      try {
        final deadline = HttpDate.parse(value).toUtc();
        final remaining = deadline.difference(_nowUtc().toUtc());
        if (remaining <= Duration.zero) return Duration.zero;
        return remaining > const Duration(seconds: 60)
            ? const Duration(seconds: 60)
            : remaining;
      } on FormatException {
        // Fall through to bounded exponential backoff with jitter.
      }
    }
    final capMilliseconds = min(8000, 250 * (1 << (attempt - 1)));
    return Duration(
      milliseconds:
          capMilliseconds ~/ 2 + _random.nextInt(capMilliseconds ~/ 2 + 1),
    );
  }

  DavException _networkException(Object? error, String correlationId) {
    final tls = error is HandshakeException || error is TlsException;
    return DavException(
      kind: tls ? DavErrorKind.tls : DavErrorKind.network,
      code: tls ? 'DavTlsFailure' : 'DavNetworkFailure',
      safeMessage: tls
          ? 'The DAV server TLS connection could not be verified.'
          : 'The DAV server could not be reached.',
      correlationId: correlationId,
    );
  }
}

bool _isRedirect(int statusCode) =>
    statusCode == HttpStatus.movedPermanently ||
    statusCode == HttpStatus.found ||
    statusCode == HttpStatus.seeOther ||
    statusCode == HttpStatus.temporaryRedirect ||
    statusCode == HttpStatus.permanentRedirect;

final class _AsyncSemaphore {
  _AsyncSemaphore(this.maximum) : _available = maximum {
    if (maximum < 1) {
      throw ArgumentError.value(maximum, 'maximum', 'Must be positive.');
    }
  }

  final int maximum;
  int _available;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() {
    if (_available > 0) {
      _available -= 1;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
      return;
    }
    if (_available >= maximum) {
      throw StateError('DAV semaphore released more often than acquired.');
    }
    _available += 1;
  }
}
