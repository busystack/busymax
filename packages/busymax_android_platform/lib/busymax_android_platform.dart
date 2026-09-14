import 'dart:async';

import 'package:flutter/services.dart';

/// Narrow Android API surface owned by BusyMax.
///
/// Interactive methods fail with `android/activity-unavailable` in a headless
/// engine. Silent authorization, clock queries, and operation gates are safe
/// without an attached Activity.
final class BusyMaxAndroidPlatform {
  BusyMaxAndroidPlatform({MethodChannel? methodChannel, EventChannel? events})
    : _methodChannel =
          methodChannel ?? const MethodChannel('io.busystack.busymax/android'),
      _events = events ?? const EventChannel('io.busystack.busymax/events');

  static final BusyMaxAndroidPlatform instance = BusyMaxAndroidPlatform();

  final MethodChannel _methodChannel;
  final EventChannel _events;

  Stream<AndroidPlatformEvent>? _eventStream;

  Stream<AndroidPlatformEvent> get events => _eventStream ??= _events
      .receiveBroadcastStream()
      .map((value) => AndroidPlatformEvent.fromMap(_stringMap(value)))
      .asBroadcastStream();

  Future<String> currentTimeZoneId() async =>
      await _methodChannel.invokeMethod<String>('currentTimeZoneId') ??
      'Etc/UTC';

  Future<bool> uses24HourFormat() async =>
      await _methodChannel.invokeMethod<bool>('uses24HourFormat') ?? false;

  Future<bool> googleAuthorizationAvailable() async =>
      await _methodChannel.invokeMethod<bool>('googleAuthorizationAvailable') ??
      false;

  Future<bool> microsoftAuthorizationAvailable() async =>
      await _methodChannel.invokeMethod<bool>(
        'microsoftAuthorizationAvailable',
      ) ??
      false;

  Future<AndroidAuthorizationToken> authorizeGoogleInteractively({
    required List<String> scopes,
  }) async => AndroidAuthorizationToken.fromMap(
    _stringMap(
      await _methodChannel.invokeMethod<Object?>('authorizeGoogleInteractive', {
        'scopes': scopes,
      }),
    ),
  );

  Future<AndroidAuthorizationToken> authorizeGoogleSilently({
    required String accountId,
    required List<String> scopes,
  }) async => AndroidAuthorizationToken.fromMap(
    _stringMap(
      await _methodChannel.invokeMethod<Object?>('authorizeGoogleSilent', {
        'accountId': accountId,
        'scopes': scopes,
      }),
    ),
  );

  Future<AndroidAuthorizationToken> authorizeMicrosoftInteractively({
    required List<String> scopes,
  }) async => AndroidAuthorizationToken.fromMap(
    _stringMap(
      await _methodChannel.invokeMethod<Object?>(
        'authorizeMicrosoftInteractive',
        {'scopes': scopes},
      ),
    ),
  );

  Future<AndroidAuthorizationToken> authorizeMicrosoftSilently({
    required String accountId,
    required List<String> scopes,
  }) async => AndroidAuthorizationToken.fromMap(
    _stringMap(
      await _methodChannel.invokeMethod<Object?>('authorizeMicrosoftSilent', {
        'accountId': accountId,
        'scopes': scopes,
      }),
    ),
  );

  Future<void> bindAuthorization({
    required String provider,
    required String accountId,
    required String nativeAccountId,
    String? username,
    String? authority,
  }) {
    final arguments = <String, Object?>{
      'provider': provider,
      'accountId': accountId,
      'nativeAccountId': nativeAccountId,
    };
    if (username != null) arguments['username'] = username;
    if (authority != null) arguments['authority'] = authority;
    return _methodChannel.invokeMethod<void>('bindAuthorization', arguments);
  }

  Future<void> clearRejectedToken(String token) => _methodChannel
      .invokeMethod<void>('clearRejectedGoogleToken', {'token': token});

  Future<void> removeAuthorization({
    required String provider,
    required String accountId,
    bool revoke = false,
  }) => _methodChannel.invokeMethod<void>('removeAuthorization', {
    'provider': provider,
    'accountId': accountId,
    'revoke': revoke,
  });

  Future<void> cancelInteractiveAuthorization() =>
      _methodChannel.invokeMethod<void>('cancelInteractiveAuthorization');

  Future<AndroidDocument?> openDocument({
    List<String> mimeTypes = const ['text/calendar'],
    int maximumBytes = 16 * 1024 * 1024,
  }) async {
    final value = await _methodChannel.invokeMethod<Object?>('openDocument', {
      'mimeTypes': mimeTypes,
      'maximumBytes': maximumBytes,
    });
    return value == null ? null : AndroidDocument.fromMap(_stringMap(value));
  }

  /// Reads a URI BusyMax received through ACTION_VIEW or ACTION_SEND.
  ///
  /// The native side deliberately accepts only content URIs and enforces the
  /// same bound as the document picker; callers never treat the URI as a path.
  Future<AndroidDocument> readDocumentUri(
    Uri uri, {
    int maximumBytes = 16 * 1024 * 1024,
  }) async => AndroidDocument.fromMap(
    _stringMap(
      await _methodChannel.invokeMethod<Object?>('readDocumentUri', {
        'uri': uri.toString(),
        'maximumBytes': maximumBytes,
      }),
    ),
  );

  Future<void> notifyDataChanged() =>
      _methodChannel.invokeMethod<void>('notifyDataChanged');

  Future<String?> createDocument({
    required String suggestedName,
    required String mimeType,
    required Uint8List bytes,
  }) => _methodChannel.invokeMethod<String>('createDocument', {
    'suggestedName': suggestedName,
    'mimeType': mimeType,
    'bytes': bytes,
  });

  Future<String?> exportDocumentTree({
    required String folderName,
    required List<AndroidExportResource> resources,
  }) => _methodChannel.invokeMethod<String>('exportDocumentTree', {
    'folderName': folderName,
    'resources': [for (final resource in resources) resource.toMap()],
  });

  Future<bool> launchExternalUri(Uri uri) async =>
      await _methodChannel.invokeMethod<bool>('launchExternalUri', {
        'uri': uri.toString(),
      }) ??
      false;

  Future<bool> hasLocalNetworkAccess() async =>
      await _methodChannel.invokeMethod<bool>('hasLocalNetworkAccess') ?? true;

  Future<bool> requestLocalNetworkAccess() async =>
      await _methodChannel.invokeMethod<bool>('requestLocalNetworkAccess') ??
      false;

  Future<void> openNotificationSettings() =>
      _methodChannel.invokeMethod<void>('openNotificationSettings');

  Future<String> acquireAccountGate(
    String accountId, {
    Duration timeout = const Duration(seconds: 30),
  }) async => (await _methodChannel.invokeMethod<String>('acquireAccountGate', {
    'accountId': accountId,
    'timeoutMillis': timeout.inMilliseconds,
  }))!;

  Future<void> releaseAccountGate(String leaseId) => _methodChannel
      .invokeMethod<void>('releaseAccountGate', {'leaseId': leaseId});

  /// Releases every gate acquired by this Flutter engine.
  ///
  /// WorkManager calls this before tearing down a stopped background engine;
  /// the native plugin also performs the same cleanup when detached.
  Future<void> releaseOwnedAccountGates() =>
      _methodChannel.invokeMethod<void>('releaseOwnedAccountGates');

  Future<AndroidActivation?> takeInitialActivation() async {
    final value = await _methodChannel.invokeMethod<Object?>(
      'takeInitialActivation',
    );
    return value == null ? null : AndroidActivation.fromMap(_stringMap(value));
  }
}

final class AndroidAuthorizationToken {
  const AndroidAuthorizationToken({
    required this.accessToken,
    required this.scopes,
    required this.nativeAccountId,
    this.username,
    this.authority,
    this.expiresAtUtc,
  });

  factory AndroidAuthorizationToken.fromMap(Map<String, Object?> map) {
    final token = map['accessToken']?.toString() ?? '';
    final nativeAccountId = map['nativeAccountId']?.toString() ?? '';
    if (token.isEmpty || nativeAccountId.isEmpty) {
      throw const FormatException(
        'Android authorization result is incomplete.',
      );
    }
    return AndroidAuthorizationToken(
      accessToken: token,
      scopes: [
        for (final scope in map['scopes'] as List? ?? const []) '$scope',
      ],
      nativeAccountId: nativeAccountId,
      username: map['username']?.toString(),
      authority: map['authority']?.toString(),
      expiresAtUtc: switch (map['expiresAtEpochMillis']) {
        final int value => DateTime.fromMillisecondsSinceEpoch(
          value,
          isUtc: true,
        ),
        _ => null,
      },
    );
  }

  final String accessToken;
  final List<String> scopes;
  final String nativeAccountId;
  final String? username;
  final String? authority;
  final DateTime? expiresAtUtc;
}

final class AndroidDocument {
  const AndroidDocument({
    required this.uri,
    required this.bytes,
    this.name,
    this.mimeType,
  });

  factory AndroidDocument.fromMap(Map<String, Object?> map) => AndroidDocument(
    uri: Uri.parse(map['uri']! as String),
    bytes: map['bytes']! as Uint8List,
    name: map['name']?.toString(),
    mimeType: map['mimeType']?.toString(),
  );

  final Uri uri;
  final Uint8List bytes;
  final String? name;
  final String? mimeType;
}

final class AndroidExportResource {
  const AndroidExportResource({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  Map<String, Object?> toMap() => {'name': name, 'bytes': bytes};
}

final class AndroidActivation {
  const AndroidActivation({
    required this.kind,
    this.uri,
    this.mimeType,
    this.action,
    this.payload,
  });

  factory AndroidActivation.fromMap(Map<String, Object?> map) =>
      AndroidActivation(
        kind: map['kind']?.toString() ?? 'unknown',
        uri: switch (map['uri']) {
          final String value when value.isNotEmpty => Uri.tryParse(value),
          _ => null,
        },
        mimeType: map['mimeType']?.toString(),
        action: map['action']?.toString(),
        payload: map['payload']?.toString(),
      );

  final String kind;
  final Uri? uri;
  final String? mimeType;
  final String? action;
  final String? payload;
}

final class AndroidPlatformEvent {
  const AndroidPlatformEvent(this.type, this.data);

  factory AndroidPlatformEvent.fromMap(Map<String, Object?> map) =>
      AndroidPlatformEvent(
        map['type']?.toString() ?? map['kind']?.toString() ?? 'unknown',
        map,
      );

  final String type;
  final Map<String, Object?> data;
}

Map<String, Object?> _stringMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw const FormatException('Android platform response is not a map.');
}
