import 'dart:async';

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
  void stop() {
    if (!abort.isCompleted) abort.complete();
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
    final streamed = await Future.any([
      client.send(request),
      abort.future.then<http.StreamedResponse>((_) => throw stopped()),
    ]);
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
      await iterator.cancel();
    }
    if (abort.isCompleted) throw stopped();
    return http.Response.bytes(
      bytes,
      streamed.statusCode,
      headers: streamed.headers,
      reasonPhrase: streamed.reasonPhrase,
      request: request,
    );
  } finally {
    timer.cancel();
  }
}
