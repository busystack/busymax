import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'terminating_http_client.dart';

/// Uses request-owned native clients (or reusable lanes) for requests that
/// need connection-establishment deadlines and termination.
final class NativeTerminatingHttpClient extends http.BaseClient
    implements TerminatingHttpClient {
  NativeTerminatingHttpClient({
    http.Client? sharedClient,
    HttpClient Function()? nativeClientFactory,
    this.reuseConnections = false,
  }) : _nativeClientFactory = nativeClientFactory ?? HttpClient.new,
       _sharedClient = sharedClient {
    // Native factories can validate a stored trust policy. Preserve that
    // validation at construction, before a caller accepts the client as usable.
    if (reuseConnections) {
      _reusableNative = _nativeClientFactory();
      _reusableClient = IOClient(_reusableNative!);
    } else {
      _sharedClient ??= IOClient(_nativeClientFactory());
    }
  }

  http.Client? _sharedClient;
  HttpClient? _reusableNative;
  IOClient? _reusableClient;

  /// Only for a request-owned lane: termination may close this entire client.
  /// The owner must not dispatch overlapping requests on a reusable lane.
  final bool reuseConnections;
  bool _busy = false;
  final HttpClient Function() _nativeClientFactory;
  final Set<HttpClient> _attempts = {};
  var _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_closed) {
      throw http.ClientException('HTTP client is closed.', request.url);
    }
    return (_sharedClient ??= IOClient(_nativeClientFactory())).send(request);
  }

  @override
  Future<http.StreamedResponse> sendTerminating(
    http.BaseRequest request, {
    required Future<void> terminate,
    required Duration connectionTimeout,
  }) async {
    if (_closed) {
      throw http.ClientException('HTTP client is closed.', request.url);
    }
    if (reuseConnections) {
      if (_busy) throw StateError('A reusable HTTP lane is already active.');
      _busy = true;
      // A lane has at most one active request. Configure the native connection
      // deadline before opening a socket; existing idle sockets remain reusable.
      final native = _reusableNative ??= _nativeClientFactory();
      native.connectionTimeout = connectionTimeout;
      final pooled = _reusableClient ??= IOClient(native);
      var finished = false;
      unawaited(
        terminate.then(
          (_) {
            if (!finished) close();
          },
          onError: (Object _, StackTrace _) {
            if (!finished) close();
          },
        ),
      );
      try {
        final response = await pooled.send(request);
        if (_closed) throw http.RequestAbortedException(request.url);
        return http.StreamedResponse(
          response.stream.transform(
            StreamTransformer.fromHandlers(
              handleDone: (sink) {
                finished = true;
                _busy = false;
                sink.close();
              },
            ),
          ),
          response.statusCode,
          headers: response.headers,
          contentLength: response.contentLength,
          request: response.request,
          isRedirect: response.isRedirect,
          reasonPhrase: response.reasonPhrase,
          persistentConnection: response.persistentConnection,
        );
      } on Object {
        finished = true;
        close();
        rethrow;
      }
    }
    final nativeClient = _nativeClientFactory()
      ..connectionTimeout = connectionTimeout;
    _attempts.add(nativeClient);
    final attemptClient = IOClient(nativeClient);
    var terminated = false;
    unawaited(
      terminate.whenComplete(() {
        terminated = true;
        // This client belongs only to this request. Force-closing it can
        // interrupt openUrl without cancelling sibling operations.
        nativeClient.close(force: true);
        _attempts.remove(nativeClient);
      }),
    );
    try {
      final response = await attemptClient.send(request);
      if (terminated) {
        throw http.RequestAbortedException(request.url);
      }
      return response;
    } on Object {
      nativeClient.close(force: true);
      _attempts.remove(nativeClient);
      rethrow;
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _sharedClient?.close();
    _reusableClient?.close();
    for (final attempt in _attempts) {
      attempt.close(force: true);
    }
    _attempts.clear();
  }
}
