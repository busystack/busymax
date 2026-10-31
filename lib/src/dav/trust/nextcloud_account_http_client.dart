import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/auth/authorization_persistence.dart';
import '../../core/http/terminating_http_client.dart';
import '../../core/secrets/secret_store.dart';
import 'nextcloud_http_client_factory.dart';

/// Selects a fresh immutable credential/policy snapshot for each operation.
/// Account generation observers close outstanding factory clients on changes.
final class NextcloudAccountHttpClient extends http.BaseClient
    implements TerminatingHttpClient {
  NextcloudAccountHttpClient({
    required this.accountId,
    required this.persistence,
    required this.factory,
    required this.standardClient,
  });
  final String accountId;
  final AuthorizationPersistence persistence;
  final NextcloudHttpClientFactory factory;
  final http.Client standardClient;

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
  }) async {
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
    // Keep the existing authorization lease through the streamed response.
    // Replacement/removal in another Android engine cannot commit while an
    // operation still owns the old credential and policy. No new lock is used.
    unawaited(
      persistence
          .withCurrentCredential(accountId, (credential) async {
            http.Client? client;
            try {
              if (terminated) throw http.RequestAbortedException(request.url);
              if (credential is NextcloudSecretRecord) {
                final expected =
                    'Basic ${base64.encode(utf8.encode('${credential.loginName}:${credential.appPassword}'))}';
                final supplied = request.headers['authorization'];
                if (supplied != null && supplied != expected) {
                  throw const SecretStoreException(
                    'NextcloudAuthorizationChanged',
                    'The account authorization changed.',
                  );
                }
                client = factory.create(
                  owner: accountId,
                  authority: credential.canonicalServer,
                  policy: credential.trustPolicy,
                );
              } else if (credential is AppleICloudSecretRecord) {
                client = standardClient;
              } else {
                throw const SecretStoreException(
                  'NextcloudAccountUnavailable',
                  'The account is unavailable.',
                );
              }
              final selected = client;
              final response =
                  terminate != null && selected is TerminatingHttpClient
                  ? await selected.sendTerminating(
                      request,
                      terminate: terminate,
                      connectionTimeout:
                          connectionTimeout ?? const Duration(seconds: 15),
                    )
                  : await selected.send(request);
              void finished() {
                if (!drained.isCompleted) drained.complete();
              }

              if (terminate != null) {
                unawaited(terminate.then((_) => finished()));
              }
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
                  contentLength: response.contentLength,
                  request: response.request,
                  headers: response.headers,
                  isRedirect: response.isRedirect,
                  persistentConnection: false,
                  reasonPhrase: response.reasonPhrase,
                ),
              );
              await drained.future;
            } on Object catch (error, stack) {
              if (!ready.isCompleted) ready.completeError(error, stack);
            } finally {
              if (client != null && !identical(client, standardClient)) {
                client.close();
              }
            }
          })
          .catchError((Object error, StackTrace stack) {
            if (!ready.isCompleted) ready.completeError(error, stack);
          }),
    );
    return ready.future;
  }

  @override
  void close() {} // The factory owns leases, the app owns standardClient.
}
