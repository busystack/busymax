import 'dart:async';

import 'package:http/http.dart' as http;

import '../../core/http/terminating_http_client.dart';

/// Holds the existing cross-engine contacts lease through HTTP stream use.
/// A binding validates its durable generation after acquiring that lease.
final class NextcloudLeasedHttpClient extends http.BaseClient
    implements TerminatingHttpClient {
  NextcloudLeasedHttpClient({
    required this.delegate,
    required this.runLease,
    required this.validate,
  });
  final http.Client delegate;
  final Future<void> Function(Future<void> Function()) runLease;
  final Future<void> Function() validate;
  bool _closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);
  @override
  Future<http.StreamedResponse> sendTerminating(
    http.BaseRequest request, {
    required Future<void> terminate,
    required Duration connectionTimeout,
  }) => _send(
    request,
    terminate: terminate,
    connectionTimeout: connectionTimeout,
  );
  Future<http.StreamedResponse> _send(
    http.BaseRequest request, {
    Future<void>? terminate,
    Duration? connectionTimeout,
  }) {
    terminate ??= request is http.Abortable ? request.abortTrigger : null;
    final ready = Completer<http.StreamedResponse>();
    final drained = Completer<void>();
    var terminated = false;
    if (terminate != null) {
      unawaited(
        terminate.then((_) {
          terminated = true;
        }),
      );
    }
    void finished() {
      if (!drained.isCompleted) drained.complete();
    }

    unawaited(
      runLease(() async {
        try {
          if (_closed) {
            throw http.ClientException('Nextcloud contacts client is closed.');
          }
          try {
            await validate();
          } on Object {
            close();
            rethrow;
          }
          if (terminated) throw http.RequestAbortedException(request.url);
          final inner = delegate;
          final response = terminate != null && inner is TerminatingHttpClient
              ? await inner.sendTerminating(
                  request,
                  terminate: terminate,
                  connectionTimeout:
                      connectionTimeout ?? const Duration(seconds: 15),
                )
              : await inner.send(request);
          if (terminate != null) unawaited(terminate.then((_) => finished()));
          Stream<List<int>> body() async* {
            try {
              yield* response.stream;
            } finally {
              finished();
            }
          }

          ready.complete(
            http.StreamedResponse(
              body(),
              response.statusCode,
              headers: response.headers,
              contentLength: response.contentLength,
              request: response.request,
              isRedirect: response.isRedirect,
              reasonPhrase: response.reasonPhrase,
              persistentConnection: response.persistentConnection,
            ),
          );
          await drained.future;
        } on Object catch (error, stack) {
          if (!ready.isCompleted) ready.completeError(error, stack);
        }
      }).catchError((Object error, StackTrace stack) {
        if (!ready.isCompleted) ready.completeError(error, stack);
      }),
    );
    return ready.future;
  }

  @override
  void close() {
    _closed = true;
    delegate.close();
  }
}
