import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/auth/authorization_persistence.dart';
import '../../core/http/authorization_leased_http_client.dart';
import '../../core/http/terminating_http_client.dart';
import '../../core/secrets/secret_store.dart';

/// Internal dispatch guard consumed by this client, never sent on the wire.
const davAuthorizationGenerationHeader = 'x-busymax-authorization-generation';

/// Common DAV authorization lifecycle. TLS selection belongs to the provider;
/// iCloud always receives the ordinary platform HTTPS implementation.
final class DavAccountHttpClient extends http.BaseClient
    implements TerminatingHttpClient {
  DavAccountHttpClient({
    required this.accountId,
    required this.persistence,
    required this.createClient,
    this.maximumLifetime = const Duration(seconds: 90),
  });
  final Duration maximumLifetime;
  final String accountId;
  final AuthorizationPersistence persistence;
  final http.Client Function(SecretRecord) createClient;
  final _active = <http.Client>{};
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
  }) async {
    http.Client? selected;
    late final AuthorizationLeasedHttpClient lease;
    // Selection and credential comparison happen under the same shared native
    // lease as transmission. No credential is cached outside that boundary.
    lease = AuthorizationLeasedHttpClient(
      maximumLifetime: maximumLifetime,
      delegate: _DeferredClient(() => selected),
      runLease: (work) => persistence.withCurrentCredential(accountId, (
        record,
      ) async {
        if (_closed) {
          throw http.ClientException('HTTP client is closed.', request.url);
        }
        final (String, String) identity = switch (record) {
          NextcloudSecretRecord() => (record.loginName, record.appPassword),
          AppleICloudSecretRecord() => (
            record.username,
            record.appSpecificPassword,
          ),
          _ => throw const SecretStoreException(
            'DavAccountUnavailable',
            'The account is unavailable.',
          ),
        };
        final expected =
            'Basic ${base64Encode(utf8.encode('${identity.$1}:${identity.$2}'))}';
        final expectedGeneration = request.headers.remove(
          davAuthorizationGenerationHeader,
        );
        if (expectedGeneration != null &&
            expectedGeneration !=
                '${await persistence.generation(accountId)}') {
          throw const SecretStoreException(
            'DavAuthorizationChanged',
            'The account authorization changed.',
          );
        }
        final supplied = request.headers['authorization'];
        if (supplied != null && supplied != expected) {
          throw const SecretStoreException(
            'DavAuthorizationChanged',
            'The account authorization changed.',
          );
        }
        selected = createClient(record!);
        try {
          await work();
        } finally {
          selected?.close();
          _active.remove(lease);
        }
      }),
      validate: () async {},
    );
    _active.add(lease);
    try {
      // Removal from the ownership set follows lease completion, not headers.
      return await lease.sendTerminating(
        request,
        terminate:
            terminate ??
            (request is http.Abortable ? request.abortTrigger : null) ??
            Completer<void>().future,
        connectionTimeout: connectionTimeout ?? const Duration(seconds: 15),
      );
    } finally {
      // The set is bounded by active requests; the delegate removes itself when closed.
      if (selected == null) _active.remove(lease);
    }
  }

  @override
  void close() {
    _closed = true;
    for (final client in _active.toList()) {
      client.close();
    }
    _active.clear();
  }
}

final class _DeferredClient extends http.BaseClient
    implements TerminatingHttpClient {
  _DeferredClient(this.current);
  final http.Client? Function() current;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      current()!.send(request);
  @override
  Future<http.StreamedResponse> sendTerminating(
    http.BaseRequest request, {
    required Future<void> terminate,
    required Duration connectionTimeout,
  }) {
    final client = current()!;
    return client is TerminatingHttpClient
        ? client.sendTerminating(
            request,
            terminate: terminate,
            connectionTimeout: connectionTimeout,
          )
        : client.send(request);
  }

  @override
  void close() => current()?.close();
}
