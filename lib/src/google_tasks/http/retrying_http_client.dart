import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

class RetryingHttpClient extends http.BaseClient {
  RetryingHttpClient({
    required http.Client inner,
    Random? random,
    Future<void> Function(Duration delay)? delay,
    this.maxRetries = 3,
  }) : _inner = inner,
       _random = random ?? Random.secure(),
       _delay = delay ?? ((duration) => Future<void>.delayed(duration));

  final http.Client _inner;
  final Random _random;
  final Future<void> Function(Duration delay) _delay;
  final int maxRetries;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // A provider can commit a mutation before returning an error, and the
    // provider APIs do not share a universal idempotency mechanism.
    if (!_isSafeMethod(request.method)) {
      return _inner.send(request);
    }

    final bodyBytes = await request.finalize().toBytes();

    for (var attempt = 0; attempt <= maxRetries; attempt += 1) {
      final response = await _inner.send(_clone(request, bodyBytes));
      if (!_isRetryable(response.statusCode) || attempt == maxRetries) {
        return response;
      }
      await response.stream.drain<void>();
      await _delay(_backoff(attempt));
    }

    throw StateError('Retry loop exited unexpectedly.');
  }

  http.Request _clone(http.BaseRequest original, List<int> bodyBytes) {
    return http.Request(original.method, original.url)
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection
      ..headers.addAll(original.headers)
      ..bodyBytes = bodyBytes;
  }

  bool _isRetryable(int statusCode) {
    return statusCode == 429 || statusCode >= 500;
  }

  bool _isSafeMethod(String method) {
    return switch (method.toUpperCase()) {
      'GET' || 'HEAD' || 'OPTIONS' || 'TRACE' => true,
      _ => false,
    };
  }

  Duration _backoff(int attempt) {
    final baseSeconds = min(pow(2, attempt).toInt(), 300);
    final jitterMs = _random.nextInt(max(baseSeconds * 500, 1));
    return Duration(seconds: baseSeconds, milliseconds: jitterMs);
  }
}
