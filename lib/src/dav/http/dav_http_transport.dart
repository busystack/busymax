import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:busystack_dav/busystack_dav.dart' as shared;
import 'package:http/http.dart' as http;

import '../../core/http/terminating_http_client.dart';
import '../../providers/busy_provider.dart';
import '../dav_provider_profile.dart';

typedef DavCancellationToken = shared.DavCancellationToken;
typedef DavBasicCredential = shared.DavBasicCredential;
typedef DavResponse = shared.DavResponse;
typedef DavDelay = shared.DavDelay;

enum DavRedirectPolicy { none, discovery }

enum DavRetryClass { safeRead, conditionalMutation, never }

final class DavRequest {
  DavRequest({
    required this.method,
    required this.uri,
    required this.accountId,
    required this.correlationId,
    this.collectionId,
    this.headers = const {},
    this.bodyBytes,
    this.retryClass = DavRetryClass.never,
    this.redirectPolicy = DavRedirectPolicy.none,
    this.mutationMayHaveCommitted = true,
  }) {
    if (uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        uri,
        'uri',
        'URI user information is forbidden.',
      );
    }
    if (headers.keys.any((name) => name.toLowerCase() == 'authorization')) {
      throw ArgumentError(
        'Authorization is owned by DavHttpTransport and cannot be supplied.',
      );
    }
  }

  factory DavRequest.xml({
    required String method,
    required Uri uri,
    required String accountId,
    required String correlationId,
    required String body,
    String? collectionId,
    Map<String, String> headers = const {},
    DavRetryClass retryClass = DavRetryClass.safeRead,
    DavRedirectPolicy redirectPolicy = DavRedirectPolicy.none,
  }) => DavRequest(
    method: method,
    uri: uri,
    accountId: accountId,
    correlationId: correlationId,
    collectionId: collectionId,
    headers: {'content-type': 'application/xml; charset=utf-8', ...headers},
    bodyBytes: Uint8List.fromList(utf8.encode(body)),
    retryClass: retryClass,
    redirectPolicy: redirectPolicy,
  );

  factory DavRequest.icalendar({
    required String method,
    required Uri uri,
    required String accountId,
    required String correlationId,
    required String body,
    required String collectionId,
    required Map<String, String> headers,
  }) => DavRequest(
    method: method,
    uri: uri,
    accountId: accountId,
    correlationId: correlationId,
    collectionId: collectionId,
    headers: {'content-type': 'text/calendar; charset=utf-8', ...headers},
    bodyBytes: Uint8List.fromList(utf8.encode(body)),
    retryClass: DavRetryClass.conditionalMutation,
  );

  final String method;
  final Uri uri;
  final String accountId;
  final String correlationId;
  final String? collectionId;
  final Map<String, String> headers;
  final Uint8List? bodyBytes;
  final DavRetryClass retryClass;
  final DavRedirectPolicy redirectPolicy;
  final bool mutationMayHaveCommitted;
}

final class DavTransportLimits {
  const DavTransportLimits({
    this.connectTimeout = const Duration(seconds: 15),
    this.responseTimeout = const Duration(seconds: 30),
    this.operationTimeout = const Duration(minutes: 2),
    this.maximumResponseBytes = 16 * 1024 * 1024,
    this.maximumRedirects = 5,
    this.maximumReadAttempts = 3,
    this.maximumConcurrentPerAccount = 4,
    this.maximumConcurrentPerCollection = 2,
  });

  final Duration connectTimeout;
  final Duration responseTimeout;
  final Duration operationTimeout;
  final int maximumResponseBytes;
  final int maximumRedirects;
  final int maximumReadAttempts;
  final int maximumConcurrentPerAccount;
  final int maximumConcurrentPerCollection;
}

/// BusyMax product policy remains app-owned while all bounded HTTP, retry,
/// redirect, cancellation, concurrency, and mutation-outcome mechanics run
/// through the public shared DAV transport.
final class DavHttpTransport {
  DavHttpTransport({
    required http.Client client,
    required DavProviderProfile profile,
    required Uri accountAuthority,
    DavTransportLimits limits = const DavTransportLimits(),
    DavDelay? delay,
    Random? random,
    DateTime Function()? nowUtc,
  }) : _profile = profile,
       _transport = shared.DavHttpTransport(
         client: client is TerminatingHttpClient
             ? _TerminatingClientBridge(client)
             : client,
         profile: sharedDavProviderProfile(profile),
         accountAuthority: accountAuthority,
         limits: shared.DavTransportLimits(
           connectTimeout: limits.connectTimeout,
           responseTimeout: limits.responseTimeout,
           operationTimeout: limits.operationTimeout,
           maximumResponseBytes: limits.maximumResponseBytes,
           maximumRedirects: limits.maximumRedirects,
           maximumReadAttempts: limits.maximumReadAttempts,
           maximumConcurrentPerAccount: limits.maximumConcurrentPerAccount,
           maximumConcurrentPerCollection:
               limits.maximumConcurrentPerCollection,
         ),
         delay: delay,
         random: random,
         nowUtc: nowUtc,
       );

  final DavProviderProfile _profile;
  final shared.DavHttpTransport _transport;
  Set<String> _serverFeatures = const {};

  /// Nextcloud's negotiated calendar cache extension remains provider policy,
  /// not a generic behavior of the shared transport.
  void setServerFeatures(Iterable<String> features) {
    _serverFeatures = Set.unmodifiable(features);
  }

  Future<DavResponse> send(
    DavRequest request, {
    required DavBasicCredential credential,
    DavCancellationToken? cancellationToken,
  }) {
    final headers = <String, String>{
      ...request.headers,
      // Preserve BusyMax correlation diagnostics while the shared transport
      // also emits its suite-level correlation header.
      'x-busymax-correlation-id': request.correlationId,
      if (_profile.provider == BusyProvider.nextcloud &&
          _serverFeatures.contains('nc-calendar-webcal-cache'))
        'X-NC-CalDAV-Webcal-Caching': 'On',
    };
    return _transport.send(
      shared.DavRequest(
        method: request.method,
        uri: request.uri,
        accountId: request.accountId,
        correlationId: request.correlationId,
        collectionId: request.collectionId,
        headers: headers,
        bodyBytes: request.bodyBytes,
        retryClass: switch (request.retryClass) {
          DavRetryClass.safeRead => shared.DavRetryClass.safeRead,
          DavRetryClass.conditionalMutation =>
            shared.DavRetryClass.conditionalMutation,
          DavRetryClass.never => shared.DavRetryClass.never,
        },
        redirectPolicy: switch (request.redirectPolicy) {
          DavRedirectPolicy.none => shared.DavRedirectPolicy.none,
          DavRedirectPolicy.discovery => shared.DavRedirectPolicy.discovery,
        },
        mutationMayHaveCommitted: request.mutationMayHaveCommitted,
      ),
      credential: credential,
      cancellationToken: cancellationToken,
    );
  }
}

final class _TerminatingClientBridge extends http.BaseClient
    implements shared.TerminatingHttpClient {
  _TerminatingClientBridge(this._delegate);

  final TerminatingHttpClient _delegate;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _delegate.send(request);

  @override
  Future<http.StreamedResponse> sendTerminating(
    http.BaseRequest request, {
    required Future<void> terminate,
    required Duration connectionTimeout,
  }) => _delegate.sendTerminating(
    request,
    terminate: terminate,
    connectionTimeout: connectionTimeout,
  );
}
