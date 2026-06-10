import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

class RetryingHttpClient extends http.BaseClient {
  RetryingHttpClient({
    required http.Client inner,
    Random? random,
    this.maxRetries = 3,
  }) : _inner = inner,
       _random = random ?? Random.secure();

  final http.Client _inner;
  final Random _random;
  final int maxRetries;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().toBytes();

    for (var attempt = 0; attempt <= maxRetries; attempt += 1) {
      final response = await _inner.send(_clone(request, bodyBytes));
      if (!_isRetryable(response.statusCode) || attempt == maxRetries) {
        return response;
      }
      await response.stream.drain<void>();
      await Future<void>.delayed(_backoff(attempt));
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

  Duration _backoff(int attempt) {
    final baseSeconds = min(pow(2, attempt).toInt(), 300);
    final jitterMs = _random.nextInt(max(baseSeconds * 500, 1));
    return Duration(seconds: baseSeconds, milliseconds: jitterMs);
  }
}
