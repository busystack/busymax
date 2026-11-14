import 'package:http/http.dart' as http;

import 'terminating_http_client.dart';

/// Rechecks a destination immediately before dispatch, including retained and
/// headless bindings. The check never presents UI or owns shared app clients.
final class DestinationCheckedHttpClient extends http.BaseClient
    implements TerminatingHttpClient {
  DestinationCheckedHttpClient(
    this.inner,
    this.check, {
    required this.closeInner,
  });
  final http.Client inner;
  final Future<void> Function(Uri) check;
  final bool closeInner;
  bool _closed = false;

  Future<void> _check(http.BaseRequest request, Future<void>? terminate) async {
    await Future.any<void>([
      check(request.url),
      if (terminate != null)
        terminate.then((_) => throw http.RequestAbortedException(request.url)),
    ]);
    if (_closed) {
      throw http.ClientException('HTTP client is closed.', request.url);
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _check(
      request,
      request is http.Abortable ? request.abortTrigger : null,
    );
    return inner.send(request);
  }

  @override
  Future<http.StreamedResponse> sendTerminating(
    http.BaseRequest request, {
    required Future<void> terminate,
    required Duration connectionTimeout,
  }) async {
    await _check(request, terminate);
    final delegate = inner;
    return delegate is TerminatingHttpClient
        ? delegate.sendTerminating(
            request,
            terminate: terminate,
            connectionTimeout: connectionTimeout,
          )
        : delegate.send(request);
  }

  @override
  void close() {
    _closed = true;
    if (closeInner) inner.close();
  }
}
