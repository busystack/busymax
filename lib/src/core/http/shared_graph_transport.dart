import 'dart:convert';

import 'package:busystack_graph/busystack_graph.dart';
import 'package:http/http.dart' as http;

import 'request_dispatch_exception.dart';

typedef BusyMaxGraphAuthorizationHeader = Future<String> Function(
  String? claims,
);

/// Thin BusyMax error/authorization adapter over the shared Graph pipeline.
/// Calendar, task and attachment endpoint policy stays in their callers.
final class BusyMaxGraphTransport {
  BusyMaxGraphTransport({
    required http.Client httpClient,
    required BusyMaxGraphAuthorizationHeader authorizationHeader,
    Future<void> Function()? recoverUnauthorized,
    int maximumResponseBytes = 32 * 1024 * 1024,
  }) : graph = GraphClient(
         httpClient: httpClient,
         maximumResponseBytes: maximumResponseBytes,
         authenticationRecovery: recoverUnauthorized == null
             ? null
             : () async {
                 try {
                   await recoverUnauthorized();
                 } on Object catch (error) {
                   throw GraphTokenProviderException(
                     KnownUnsentRequestException(
                       kind: RequestPreDispatchFailureKind.authentication,
                       cause: error,
                     ),
                   );
                 }
               },
         tokenProvider: ({claims}) async {
           String header;
           try {
             header = await authorizationHeader(claims);
           } on Object catch (error, stackTrace) {
             Error.throwWithStackTrace(
               GraphTokenProviderException(
                 KnownUnsentRequestException(
                   kind: RequestPreDispatchFailureKind.authentication,
                   cause: error,
                 ),
               ),
               stackTrace,
             );
           }
           final match = RegExp(
             r'^Bearer ([^\s\r\n]+)$',
             caseSensitive: false,
           ).firstMatch(header);
           if (match == null) {
             throw StateError('Invalid Graph authorization header.');
           }
           return GraphAuthorization(match.group(1)!);
         },
       );

  final GraphClient graph;

  Future<http.Response> request(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    List<int>? bytes,
    Map<String, String> headers = const <String, String>{},
  }) async {
    try {
      final response = await graph.request(
        method,
        uri.toString(),
        json: body,
        bytes: bytes,
        headers: headers,
      );
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
      );
    } on GraphTokenProviderException catch (error) {
      throw error.cause;
    } on GraphException catch (error) {
      if (error.kind == GraphFailure.authentication &&
          error.statusCode == null) {
        throw KnownUnsentRequestException(
          kind: RequestPreDispatchFailureKind.authentication,
          cause: error,
        );
      }
      final status = error.statusCode;
      if (status == null) {
        if (error.kind == GraphFailure.unknownOutcome ||
            error.kind == GraphFailure.connectivity ||
            error.kind == GraphFailure.timeout ||
            error.kind == GraphFailure.tls) {
          throw http.ClientException('Microsoft Graph response unavailable.');
        }
        rethrow;
      }
      return http.Response(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{'code': error.code, 'message': error.code},
        }),
        status,
        headers: <String, String>{
          if (error.requestId != null) 'request-id': error.requestId!,
          if (error.clientRequestId != null)
            'client-request-id': error.clientRequestId!,
          if (error.retryAfterProvided && error.retryAt != null)
            'retry-after':
                '${error.retryAt!.difference(DateTime.now().toUtc()).inSeconds + 1}',
        },
      );
    }
  }

  Future<List<int>> download(Uri uri, {required int maximumBytes}) async {
    final bytes = <int>[];
    try {
      await for (final chunk in graph.download(uri.toString())) {
        if (bytes.length + chunk.length > maximumBytes) {
          throw const GraphException(
            GraphFailure.protocol,
            'download-too-large',
          );
        }
        bytes.addAll(chunk);
      }
    } on GraphTokenProviderException catch (error) {
      throw error.cause;
    } on GraphException catch (error) {
      if (error.kind == GraphFailure.authentication &&
          error.statusCode == null) {
        throw KnownUnsentRequestException(
          kind: RequestPreDispatchFailureKind.authentication,
          cause: error,
        );
      }
      if (error.statusCode == null &&
          (error.kind == GraphFailure.connectivity ||
              error.kind == GraphFailure.timeout ||
              error.kind == GraphFailure.tls)) {
        throw http.ClientException('Microsoft Graph response unavailable.');
      }
      rethrow;
    }
    return bytes;
  }

  Future<GraphResponse> uploadPreauthorized(
    Uri uri, {
    required List<int> bytes,
    required Map<String, String> headers,
  }) => graph.upload(
    GraphUploadDestination(uri),
    source: Stream<List<int>>.value(bytes),
    length: bytes.length,
    headers: headers,
  );

  void close() => graph.close();
}
