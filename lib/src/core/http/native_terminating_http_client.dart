import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'terminating_http_client.dart';

/// Uses the shared client for ordinary requests and an isolated native client
/// for requests that need connection-establishment termination.
final class NativeTerminatingHttpClient extends http.BaseClient
    implements TerminatingHttpClient {
  NativeTerminatingHttpClient({
    http.Client? sharedClient,
    HttpClient Function()? nativeClientFactory,
  }) : _nativeClientFactory = nativeClientFactory ?? HttpClient.new,
       _sharedClient =
           sharedClient ??
           (nativeClientFactory == null
               ? http.Client()
               : IOClient(nativeClientFactory()));

  final http.Client _sharedClient;
  final HttpClient Function() _nativeClientFactory;
  final Set<HttpClient> _attempts = {};
  var _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_closed) {
      throw http.ClientException('HTTP client is closed.', request.url);
    }
    return _sharedClient.send(request);
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
    _sharedClient.close();
    for (final attempt in _attempts) {
      attempt.close(force: true);
    }
    _attempts.clear();
  }
}
