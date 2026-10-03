import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/http/retry_after.dart';
import '../../core/http/provider_throttle.dart';

class RetryingHttpClient extends http.BaseClient {
  RetryingHttpClient({
    required http.Client inner,
    Random? random,
    Future<void> Function(Duration delay)? delay,
    DateTime Function()? nowUtc,
    this.maxRetries = 3,
    this.operationTimeout = const Duration(seconds: 30),
  }) : _inner = inner,
       _random = random ?? Random.secure(),
       _delay = delay ?? ((duration) => Future<void>.delayed(duration)),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());
  final http.Client _inner;
  final Random _random;
  final Future<void> Function(Duration delay) _delay;
  final DateTime Function() _nowUtc;
  final int maxRetries;
  final Duration operationTimeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Mutations remain the durable replayer's responsibility.
    if (!_isSafeMethod(request.method)) return _inner.send(request);
    final body = await request.finalize().toBytes();
    final deadline = _nowUtc().add(operationTimeout);
    final abort = Completer<void>();
    void stop() {
      if (!abort.isCompleted) abort.complete();
    }

    final timer = Timer(operationTimeout, stop);
    if (request is http.Abortable) {
      unawaited(
        (request).abortTrigger?.then((_) => stop()) ?? Future<void>.value(),
      );
    }
    var handedOff = false;
    http.StreamedResponse finish(http.StreamedResponse response) {
      handedOff = true;
      return http.StreamedResponse(
        _deadlineStream(response.stream, timer, abort.future, request.url),
        response.statusCode,
        headers: response.headers,
        contentLength: response.contentLength,
        request: response.request,
        reasonPhrase: response.reasonPhrase,
      );
    }

    try {
      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        if (abort.isCompleted) throw http.RequestAbortedException(request.url);
        var response = await Future.any([
          _inner.send(_clone(request, body, abort.future)),
          abort.future.then<http.StreamedResponse>(
            (_) => throw http.RequestAbortedException(request.url),
          ),
        ]);
        var quota = false;
        if (response.statusCode == 403 &&
            const {
              'www.googleapis.com',
              'tasks.googleapis.com',
            }.contains(request.url.host)) {
          final bytes = <int>[];
          final iterator = StreamIterator(response.stream);
          try {
            while (await Future.any([
              iterator.moveNext(),
              abort.future.then<bool>(
                (_) => throw http.RequestAbortedException(request.url),
              ),
            ])) {
              if (bytes.length + iterator.current.length > 1024 * 1024) {
                throw const FormatException(
                  'Provider response exceeds the allowed size.',
                );
              }
              bytes.addAll(iterator.current);
            }
          } finally {
            await iterator.cancel();
          }
          quota = isGoogleQuotaResponse(
            403,
            utf8.decode(bytes, allowMalformed: true),
          );
          response = _buffered(response, bytes);
        }
        if (!(response.statusCode == 429 ||
                response.statusCode >= 500 ||
                quota) ||
            attempt == maxRetries) {
          return finish(response);
        }
        final retryAfter = parseHttpRetryAfter(
          response.headers['retry-after'],
          now: _nowUtc(),
        );
        final backoff = _backoff(attempt);
        final delay = retryAfter != null && retryAfter > backoff
            ? retryAfter
            : backoff;
        // Return the unshortened server hint for domain/pending-op persistence.
        if (!_nowUtc().add(delay).isBefore(deadline)) return finish(response);
        await response.stream.drain<void>();
        await Future.any([
          _delay(delay),
          abort.future.then(
            (_) => throw http.RequestAbortedException(request.url),
          ),
        ]);
      }
      throw StateError('Retry loop exited unexpectedly.');
    } finally {
      if (!handedOff) timer.cancel();
    }
  }

  Stream<List<int>> _deadlineStream(
    Stream<List<int>> stream,
    Timer timer,
    Future<void> abort,
    Uri uri,
  ) async* {
    final iterator = StreamIterator(stream);
    try {
      while (await Future.any([
        iterator.moveNext(),
        abort.then<bool>((_) => throw http.RequestAbortedException(uri)),
      ])) {
        yield iterator.current;
      }
    } finally {
      await iterator.cancel();
      timer.cancel();
    }
  }

  http.AbortableRequest _clone(
    http.BaseRequest original,
    List<int> body,
    Future<void> abort,
  ) => http.AbortableRequest(original.method, original.url, abortTrigger: abort)
    ..followRedirects = original.followRedirects
    ..maxRedirects = original.maxRedirects
    ..persistentConnection = original.persistentConnection
    ..headers.addAll(original.headers)
    ..bodyBytes = body;
  http.StreamedResponse _buffered(
    http.StreamedResponse original,
    List<int> bytes,
  ) => http.StreamedResponse(
    Stream.value(bytes),
    original.statusCode,
    headers: original.headers,
    contentLength: bytes.length,
    request: original.request,
    reasonPhrase: original.reasonPhrase,
    isRedirect: original.isRedirect,
    persistentConnection: original.persistentConnection,
  );
  bool _isSafeMethod(String method) =>
      const {'GET', 'HEAD', 'OPTIONS', 'TRACE'}.contains(method.toUpperCase());
  Duration _backoff(int attempt) {
    final seconds = min(pow(2, attempt).toInt(), 300);
    return Duration(
      seconds: seconds,
      milliseconds: _random.nextInt(max(seconds * 500, 1)),
    );
  }

  @override
  void close() => _inner.close();
}
