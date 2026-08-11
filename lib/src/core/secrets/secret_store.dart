import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';

import '../../providers/busy_provider.dart';
import '../../providers/account_authority.dart';
import '../auth/oauth_models.dart';
import '../logging/redacting_logger.dart';

const secretRecordSchemaVersion = 1;

enum CredentialKind { oauth, appleAppSpecificPassword, nextcloudAppPassword }

extension CredentialKindValue on CredentialKind {
  String get storageValue => switch (this) {
    CredentialKind.oauth => 'oauth',
    CredentialKind.appleAppSpecificPassword => 'apple_app_specific_password',
    CredentialKind.nextcloudAppPassword => 'nextcloud_app_password',
  };
}

sealed class SecretRecord {
  const SecretRecord({required this.provider, required this.kind});

  final BusyProvider provider;
  final CredentialKind kind;

  Map<String, Object?> toJson();

  static SecretRecord fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != secretRecordSchemaVersion) {
      throw SecretStoreCorruptException(
        'Unsupported credential schema version ${json['schemaVersion']}.',
      );
    }
    final provider = BusyProviderCodec.requireStorageValue(
      json['provider']?.toString(),
    );
    return switch (json['kind']) {
      'oauth' => OAuthSecretRecord(
        provider: provider,
        tokenSet: OAuthTokenSet(
          accessToken: _requiredSecretString(json, 'accessToken'),
          refreshToken: _optionalSecretString(json, 'refreshToken'),
          idToken: _optionalSecretString(json, 'idToken'),
          expiresAtUtc: DateTime.parse(
            _requiredSecretString(json, 'expiresAtUtc'),
          ).toUtc(),
          tokenType: _requiredSecretString(json, 'tokenType'),
          scopes: _stringList(json['scopes']).toSet(),
        ),
      ),
      'apple_app_specific_password' => AppleICloudSecretRecord(
        username: _requiredSecretString(json, 'username'),
        appSpecificPassword: _requiredSecretString(json, 'appSpecificPassword'),
      ),
      'nextcloud_app_password' => NextcloudSecretRecord(
        canonicalServer: Uri.parse(
          _requiredSecretString(json, 'canonicalServer'),
        ),
        loginName: _requiredSecretString(json, 'loginName'),
        appPassword: _requiredSecretString(json, 'appPassword'),
      ),
      final Object? value => throw SecretStoreCorruptException(
        'Unsupported credential kind $value.',
      ),
    };
  }

  @override
  String toString() =>
      '$runtimeType(provider: ${provider.storageValue}, secret: [REDACTED])';
}

final class OAuthSecretRecord extends SecretRecord {
  const OAuthSecretRecord({required super.provider, required this.tokenSet})
    : assert(
        provider == BusyProvider.google || provider == BusyProvider.microsoft,
      ),
      super(kind: CredentialKind.oauth);

  final OAuthTokenSet tokenSet;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': secretRecordSchemaVersion,
    'kind': kind.storageValue,
    'provider': provider.storageValue,
    'accessToken': tokenSet.accessToken,
    if (tokenSet.refreshToken != null) 'refreshToken': tokenSet.refreshToken,
    if (tokenSet.idToken != null) 'idToken': tokenSet.idToken,
    'expiresAtUtc': tokenSet.expiresAtUtc.toUtc().toIso8601String(),
    'tokenType': tokenSet.tokenType,
    'scopes': tokenSet.scopes.toList()..sort(),
  };
}

final class AppleICloudSecretRecord extends SecretRecord {
  AppleICloudSecretRecord({
    required String username,
    required String appSpecificPassword,
  }) : username = username.trim(),
       appSpecificPassword = appSpecificPassword.trim(),
       super(
         provider: BusyProvider.appleICloud,
         kind: CredentialKind.appleAppSpecificPassword,
       ) {
    if (this.username.isEmpty || this.appSpecificPassword.isEmpty) {
      throw const SecretStoreCorruptException(
        'Apple iCloud credentials must not be empty.',
      );
    }
  }

  final String username;
  final String appSpecificPassword;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': secretRecordSchemaVersion,
    'kind': kind.storageValue,
    'provider': provider.storageValue,
    'username': username,
    'appSpecificPassword': appSpecificPassword,
  };
}

final class NextcloudSecretRecord extends SecretRecord {
  NextcloudSecretRecord({
    required Uri canonicalServer,
    required String loginName,
    required String appPassword,
  }) : canonicalServer = Uri.parse(
         normalizeNextcloudServerAuthority(canonicalServer.toString()),
       ),
       loginName = loginName.trim(),
       appPassword = appPassword.trim(),
       super(
         provider: BusyProvider.nextcloud,
         kind: CredentialKind.nextcloudAppPassword,
       ) {
    if (canonicalServer.scheme != 'https' ||
        canonicalServer.host.isEmpty ||
        canonicalServer.userInfo.isNotEmpty ||
        this.loginName.isEmpty ||
        this.appPassword.isEmpty) {
      throw const SecretStoreCorruptException(
        'Nextcloud credentials contain an invalid server or empty value.',
      );
    }
  }

  final Uri canonicalServer;
  final String loginName;
  final String appPassword;

  @override
  Map<String, Object?> toJson() => {
    'schemaVersion': secretRecordSchemaVersion,
    'kind': kind.storageValue,
    'provider': provider.storageValue,
    'canonicalServer': canonicalServer.toString(),
    'loginName': loginName,
    'appPassword': appPassword,
  };
}

abstract interface class SecretStore {
  Future<String?> readActiveAccountId();
  Future<void> setActiveAccountId(String accountId);
  Future<void> clearActiveAccount();
  Future<SecretRecord?> readCredential(String accountId);
  Future<void> saveCredential(String accountId, SecretRecord credential);
  Future<void> deleteCredential(String accountId);

  /// Performs the one-time legacy OAuth key migration for an existing account.
  /// Returns true only when legacy values were replaced and then deleted.
  Future<bool> migrateLegacyOAuthCredential(
    String accountId,
    BusyProvider provider,
  );
}

extension OAuthSecretStoreAccess on SecretStore {
  Future<OAuthTokenSet?> readOAuthTokenSet(
    String accountId,
    BusyProvider expectedProvider,
  ) async {
    final credential = await readCredential(accountId);
    if (credential == null) {
      return null;
    }
    if (credential case OAuthSecretRecord(
      provider: final provider,
      tokenSet: final tokenSet,
    ) when provider == expectedProvider) {
      return tokenSet;
    }
    throw SecretStoreCredentialMismatchException(
      accountId: accountId,
      expectedProvider: expectedProvider,
      actualProvider: credential.provider,
      actualKind: credential.kind,
    );
  }

  Future<void> saveOAuthTokenSet(
    String accountId,
    BusyProvider provider,
    OAuthTokenSet tokenSet,
  ) {
    return saveCredential(
      accountId,
      OAuthSecretRecord(provider: provider, tokenSet: tokenSet),
    );
  }
}

class SecureSecretStore implements SecretStore {
  SecureSecretStore(this._storage, {RedactingLogger? logger})
    : _logger = logger ?? RedactingLogger(Logger('SecureSecretStore'));

  final FlutterSecureStorage _storage;
  final RedactingLogger _logger;
  var _loggedRuntime = false;

  static const activeAccountKey = 'busymax.secret.active_account_id';
  static const legacyActiveAccountKey = 'busymax.oauth.active_account_id';

  @override
  Future<String?> readActiveAccountId() async {
    final current = await _read(activeAccountKey);
    if (current != null) {
      return current;
    }
    final legacy = await _read(legacyActiveAccountKey);
    if (legacy == null) {
      return null;
    }
    await _write(activeAccountKey, legacy);
    if (await _read(activeAccountKey) != legacy) {
      throw const SecretStoreException(
        'SecretStoreMigrationVerificationFailed',
        'The active account secret migration could not be verified.',
      );
    }
    await _delete(legacyActiveAccountKey);
    return legacy;
  }

  @override
  Future<SecretRecord?> readCredential(String accountId) async {
    final serialized = await _read(_credentialKey(accountId));
    if (serialized == null) {
      return null;
    }
    return _decodeCredential(serialized);
  }

  @override
  Future<void> saveCredential(String accountId, SecretRecord credential) async {
    await _write(_credentialKey(accountId), jsonEncode(credential.toJson()));
  }

  @override
  Future<void> setActiveAccountId(String accountId) {
    return _write(activeAccountKey, accountId);
  }

  @override
  Future<void> deleteCredential(String accountId) {
    return _delete(_credentialKey(accountId));
  }

  @override
  Future<void> clearActiveAccount() => _delete(activeAccountKey);

  @override
  Future<bool> migrateLegacyOAuthCredential(
    String accountId,
    BusyProvider provider,
  ) async {
    if (provider != BusyProvider.google && provider != BusyProvider.microsoft) {
      return false;
    }
    if (await readCredential(accountId) != null) {
      return false;
    }
    final accessToken = await _read(_legacyKey(accountId, 'access_token'));
    final expiresAtText = await _read(_legacyKey(accountId, 'expires_at_utc'));
    if (accessToken == null || expiresAtText == null) {
      return false;
    }
    final tokenSet = OAuthTokenSet(
      accessToken: accessToken,
      refreshToken: await _read(_legacyKey(accountId, 'refresh_token')),
      idToken: await _read(_legacyKey(accountId, 'id_token')),
      expiresAtUtc: DateTime.parse(expiresAtText).toUtc(),
      tokenType: await _read(_legacyKey(accountId, 'token_type')) ?? 'Bearer',
      scopes: (await _read(_legacyKey(accountId, 'scope')) ?? '')
          .split(RegExp(r'\s+'))
          .where((scope) => scope.isNotEmpty)
          .toSet(),
    );
    await saveOAuthTokenSet(accountId, provider, tokenSet);
    final verified = await readOAuthTokenSet(accountId, provider);
    if (verified == null || verified.accessToken != tokenSet.accessToken) {
      throw const SecretStoreException(
        'SecretStoreMigrationVerificationFailed',
        'The OAuth credential migration could not be verified.',
      );
    }
    await _deleteLegacyOAuthKeys(accountId);
    return true;
  }

  String _credentialKey(String accountId) => 'busymax.secret.$accountId.v1';

  String _legacyKey(String accountId, String name) =>
      'busymax.oauth.$accountId.$name';

  Future<void> _deleteLegacyOAuthKeys(String accountId) async {
    for (final name in _legacyOAuthFieldNames) {
      await _delete(_legacyKey(accountId, name));
    }
  }

  Future<String?> _read(String key) async {
    _logRuntime();
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (error) {
      throw _secureStorageException('read', error);
    }
  }

  Future<void> _write(String key, String? value) async {
    _logRuntime();
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (error) {
      throw _secureStorageException('write', error);
    }
  }

  Future<void> _delete(String key) async {
    _logRuntime();
    try {
      await _storage.delete(key: key);
    } on PlatformException catch (error) {
      throw _secureStorageException('delete', error);
    }
  }

  void _logRuntime() {
    if (_loggedRuntime) {
      return;
    }
    _loggedRuntime = true;
    _logger.info(
      'Secret storage runtime: backend=flutter-secure-storage '
      'snap=${_isRunningInSnap()} secret_backend=${_secretBackendLabel()}',
    );
  }

  SecretStoreException _secureStorageException(
    String operation,
    PlatformException error,
  ) {
    _logger.warning(
      'Secret storage $operation failed: '
      '${sanitizedFlutterSecureStorageError(error)}',
    );
    return const SecretStoreException(
      'SecretStoreUnavailable',
      secretStorageUnavailableMessage,
    );
  }
}

class InMemorySecretStore implements SecretStore {
  final _credentials = <String, SecretRecord>{};
  String? _activeAccountId;

  @override
  Future<void> clearActiveAccount() async => _activeAccountId = null;

  @override
  Future<void> deleteCredential(String accountId) async {
    _credentials.remove(accountId);
  }

  @override
  Future<bool> migrateLegacyOAuthCredential(
    String accountId,
    BusyProvider provider,
  ) async => false;

  @override
  Future<String?> readActiveAccountId() async => _activeAccountId;

  @override
  Future<SecretRecord?> readCredential(String accountId) async =>
      _credentials[accountId];

  @override
  Future<void> saveCredential(String accountId, SecretRecord credential) async {
    _credentials[accountId] = credential;
  }

  @override
  Future<void> setActiveAccountId(String accountId) async {
    _activeAccountId = accountId;
  }
}

class SecretStoreException implements Exception {
  const SecretStoreException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class SecretStoreCorruptException extends SecretStoreException {
  const SecretStoreCorruptException(String message)
    : super('SecretStoreCorrupt', message);
}

class SecretStoreCredentialMismatchException extends SecretStoreException {
  SecretStoreCredentialMismatchException({
    required this.accountId,
    required this.expectedProvider,
    required this.actualProvider,
    required this.actualKind,
  }) : super(
         'SecretStoreCredentialMismatch',
         'The stored credential does not match the requested account provider.',
       );

  final String accountId;
  final BusyProvider expectedProvider;
  final BusyProvider actualProvider;
  final CredentialKind actualKind;
}

const secretStorageUnavailableMessage =
    'Secure credential storage is locked. Unlock your system keyring and try again.';

String sanitizedFlutterSecureStorageError(PlatformException error) {
  final message = redactForLog(error.message).replaceAll(RegExp(r'\s+'), ' ');
  return 'domain=flutter_secure_storage_linux code=${error.code} '
      'message=${message.trim()} details_type=${error.details.runtimeType}';
}

SecretRecord _decodeCredential(String serialized) {
  try {
    final decoded = jsonDecode(serialized);
    if (decoded is! Map) {
      throw const SecretStoreCorruptException(
        'The credential record is not a JSON object.',
      );
    }
    return SecretRecord.fromJson(decoded.cast<String, Object?>());
  } on SecretStoreException {
    rethrow;
  } on Object catch (error) {
    throw SecretStoreCorruptException(
      'The credential record could not be decoded (${error.runtimeType}).',
    );
  }
}

String _requiredSecretString(Map<String, Object?> json, String key) {
  final value = json[key]?.toString();
  if (value == null || value.isEmpty) {
    throw SecretStoreCorruptException('Credential record is missing $key.');
  }
  return value;
}

String? _optionalSecretString(Map<String, Object?> json, String key) {
  final value = json[key]?.toString();
  return value == null || value.isEmpty ? null : value;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map((entry) => entry.toString()).toList(growable: false);
}

const _legacyOAuthFieldNames = <String>[
  'access_token',
  'refresh_token',
  'id_token',
  'expires_at_utc',
  'token_type',
  'scope',
];

bool _isRunningInSnap() => Platform.environment['SNAP']?.isNotEmpty ?? false;

String _secretBackendLabel() {
  final backend = Platform.environment['SECRET_BACKEND'];
  if (backend == null || backend.isEmpty) {
    return '<unset>';
  }
  return backend == 'file' ? 'file' : '<set>';
}
