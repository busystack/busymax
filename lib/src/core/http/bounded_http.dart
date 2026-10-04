import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../auth/oauth_models.dart';

/// Aborts transport and stream consumption, and bounds the decoded body.
Future<http.Response> boundedHttpRequest(
  http.Client client,
  String method,
  Uri uri, {
  Map<String, String> headers = const {},
  Map<String, String>? body,
  Future<void>? cancellation,
  Duration timeout = const Duration(seconds: 30),
  int maximumBytes = 1024 * 1024,
}) async {
  final abort = Completer<void>();
  var timedOut = false;
  var finished = false;
  void stop() {
    if (!finished && !abort.isCompleted) abort.complete();
  }

  final timer = Timer(timeout, () {
    timedOut = true;
    stop();
  });
  if (cancellation != null) unawaited(cancellation.then((_) => stop()));
  try {
    final request = http.AbortableRequest(
      method,
      uri,
      abortTrigger: abort.future,
    )..headers.addAll(headers);
    if (body != null) request.bodyFields = body;
    OAuthException stopped() => OAuthException(
      timedOut ? 'OAuthRequestTimeout' : 'OAuthSignInCancelled',
      timedOut
          ? 'The provider request timed out.'
          : 'Authorization was cancelled.',
    );
    // Let an already-completed captured cancellation signal run before send.
    await Future<void>.value();
    if (abort.isCompleted) throw stopped();
    var claimed = false;
    final sending = client.send(request);
    unawaited(
      sending.then<void>((response) {
        if (!claimed && abort.isCompleted) {
          unawaited(
            response.stream
                .listen((_) {})
                .cancel()
                .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
          );
        }
      }, onError: (Object _, StackTrace _) {}),
    );
    final streamed = await Future.any([
      sending,
      abort.future.then<http.StreamedResponse>((_) => throw stopped()),
    ]);
    claimed = true;
    if (abort.isCompleted) throw stopped();
    final bytes = <int>[];
    final iterator = StreamIterator(streamed.stream);
    try {
      while (await Future.any([
        iterator.moveNext(),
        abort.future.then<bool>((_) => throw stopped()),
      ])) {
        if (abort.isCompleted) throw stopped();
        final chunk = iterator.current;
        if (bytes.length + chunk.length > maximumBytes) {
          stop();
          throw const OAuthException(
            'OAuthResponseMalformed',
            'The provider response exceeds the allowed size.',
          );
        }
        bytes.addAll(chunk);
      }
    } finally {
      // Cancellation stops subscription delivery synchronously. A transport's
      // asynchronous cleanup acknowledgement must not extend this deadline.
      unawaited(
        iterator.cancel().then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        ),
      );
    }
    if (abort.isCompleted) throw stopped();
    return http.Response.bytes(
      bytes,
      streamed.statusCode,
      headers: streamed.headers,
      reasonPhrase: streamed.reasonPhrase,
      request: request,
    );
  } on http.ClientException {
    throw const OAuthException(
      'OAuthTemporaryTransport',
      'The provider request could not complete. Try again.',
    );
  } on SocketException {
    throw const OAuthException(
      'OAuthTemporaryTransport',
      'The provider request could not complete. Try again.',
    );
  } finally {
    finished = true;
    timer.cancel();
  }
}
