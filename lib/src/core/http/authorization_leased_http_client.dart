import 'dart:async';

import 'package:http/http.dart' as http;

import 'terminating_http_client.dart';

/// Owns a bounded request/response lease. Closing the request-owned delegate
/// stops transmission before releasing authorization, even for abandoned bodies.
final class AuthorizationLeasedHttpClient extends http.BaseClient
    implements TerminatingHttpClient {
  AuthorizationLeasedHttpClient({
    required this.delegate,
    required this.runLease,
    required this.validate,
    this.maximumLifetime = const Duration(minutes: 2),
    this.acquisitionTimeout = const Duration(minutes: 2),
  }) : _createDelegate = null;

  /// Long-lived bindings create a fresh request-owned transport inside the
  /// authorization lease. A terminated transport is never reused by a retry.
  AuthorizationLeasedHttpClient.requestScoped({
    required http.Client Function() createDelegate,
    required this.runLease,
    required this.validate,
    this.maximumLifetime = const Duration(minutes: 2),
    this.acquisitionTimeout = const Duration(minutes: 2),
  }) : delegate = null,
       _createDelegate = createDelegate;

  final http.Client? delegate;
  final http.Client Function()? _createDelegate;
  final Future<void> Function(Future<void> Function()) runLease;
  final Future<void> Function() validate;
  final Duration maximumLifetime;
  final Duration acquisitionTimeout;
  final _active = <void Function()>{};
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
    final stop = Completer<void>();
    StreamSubscription<List<int>>? subscription;
    late final StreamController<List<int>> body;
    Timer? timer;
    http.Client? operationDelegate = delegate;
    var finished = false;
    void finish([Object? error, StackTrace? stack, bool closeDelegate = true]) {
      if (finished) return;
      finished = true;
      timer?.cancel();
      // The delegate belongs to this operation/binding, never the app client.
      if (closeDelegate || _createDelegate != null) operationDelegate?.close();
      stop.complete();
      if (error != null) {
        if (!ready.isCompleted) {
          ready.completeError(error, stack);
        } else {
          body.addError(error, stack);
        }
      }
      unawaited(subscription?.cancel());
      unawaited(body.close());
      drained.complete();
    }

    void abort() => finish(http.RequestAbortedException(request.url));
    body = StreamController<List<int>>(
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => finish(),
    );
    _active.add(abort);
    timer = Timer(
      acquisitionTimeout,
      () =>
          finish(TimeoutException('Authorization lease acquisition expired.')),
    );
    if (terminate != null) {
      unawaited(
        terminate.then(
          (_) => abort(),
          onError: (Object e, StackTrace s) => finish(e, s),
        ),
      );
    }
    unawaited(
      runLease(() async {
            try {
              if (finished) return;
              // Queueing must not consume the active request's budget. The
              // transport's operation deadline/cancellation still takes priority.
              timer?.cancel();
              timer = Timer(
                maximumLifetime,
                () => finish(
                  TimeoutException('Authorization request lease expired.'),
                ),
              );
              if (_closed) {
                throw http.ClientException(
                  'HTTP client is closed.',
                  request.url,
                );
              }
              await validate();
              if (finished) return;
              final inner = operationDelegate =
                  _createDelegate?.call() ?? delegate!;
              final sending = (inner is TerminatingHttpClient
                  ? inner.sendTerminating(
                      request,
                      terminate: stop.future,
                      connectionTimeout:
                          connectionTimeout ?? const Duration(seconds: 15),
                    )
                  : inner.send(request));
              final response = await Future.any([
                sending,
                stop.future.then<http.StreamedResponse>(
                  (_) => throw http.RequestAbortedException(request.url),
                ),
              ]);
              if (finished) return;
              body.onListen = () {
                if (finished) return;
                subscription = response.stream.listen(
                  body.add,
                  onError: (Object e, StackTrace s) => finish(e, s),
                  onDone: () => finish(null, null, false),
                  cancelOnError: true,
                );
              };
              ready.complete(
                http.StreamedResponse(
                  body.stream,
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
              finish(error, stack);
            }
          })
          .catchError((Object error, StackTrace stack) => finish(error, stack))
          .whenComplete(() {
            _active.remove(abort);
          }),
    );
    return ready.future;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final cancel in _active.toList()) {
      cancel();
    }
    delegate?.close();
  }
}
