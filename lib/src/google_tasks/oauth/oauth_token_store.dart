import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../../core/logging/redacting_logger.dart';
import 'oauth_models.dart';

abstract interface class OAuthTokenStore {
  Future<String?> readActiveAccountId();

  Future<OAuthTokenSet?> readTokenSet(String accountId);

  Future<void> saveTokenSet(String accountId, OAuthTokenSet tokenSet);

  Future<void> setActiveAccountId(String accountId);

  Future<void> clearTokenSet(String accountId);

  Future<void> clearActiveAccount();
}

class SecureOAuthTokenStore implements OAuthTokenStore {
  SecureOAuthTokenStore(this._storage, {RedactingLogger? logger})
    : _logger = logger ?? RedactingLogger(Logger('SecureOAuthTokenStore'));

  final FlutterSecureStorage _storage;
  final RedactingLogger _logger;
  var _loggedRuntime = false;

  static const activeAccountKey = 'busymax.oauth.active_account_id';

  @override
  Future<String?> readActiveAccountId() => _read(activeAccountKey);

  @override
  Future<OAuthTokenSet?> readTokenSet(String accountId) async {
    final accessToken = await _read(_key(accountId, 'access_token'));
    final expiresAtText = await _read(_key(accountId, 'expires_at_utc'));
    if (accessToken == null || expiresAtText == null) {
      return null;
    }

    final refreshToken = await _read(_key(accountId, 'refresh_token'));
    final tokenType = await _read(_key(accountId, 'token_type'));
    final scopeText = await _read(_key(accountId, 'scope'));
    final idToken = await _read(_key(accountId, 'id_token'));

    return OAuthTokenSet(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      expiresAtUtc: DateTime.parse(expiresAtText).toUtc(),
      tokenType: tokenType ?? 'Bearer',
      scopes: (scopeText ?? '')
          .split(RegExp(r'\s+'))
          .where((scope) => scope.isNotEmpty)
          .toSet(),
    );
  }

  @override
  Future<void> saveTokenSet(String accountId, OAuthTokenSet tokenSet) async {
    await _write(_key(accountId, 'access_token'), tokenSet.accessToken);
    if (tokenSet.refreshToken != null) {
      await _write(_key(accountId, 'refresh_token'), tokenSet.refreshToken);
    }
    if (tokenSet.idToken != null) {
      await _write(_key(accountId, 'id_token'), tokenSet.idToken);
    }
    await _write(
      _key(accountId, 'expires_at_utc'),
      tokenSet.expiresAtUtc.toUtc().toIso8601String(),
    );
    await _write(_key(accountId, 'token_type'), tokenSet.tokenType);
    await _write(_key(accountId, 'scope'), tokenSet.scopes.join(' '));
  }

  @override
  Future<void> setActiveAccountId(String accountId) {
    return _write(activeAccountKey, accountId);
  }

  @override
  Future<void> clearTokenSet(String accountId) async {
    await _delete(_key(accountId, 'access_token'));
    await _delete(_key(accountId, 'refresh_token'));
    await _delete(_key(accountId, 'id_token'));
    await _delete(_key(accountId, 'expires_at_utc'));
    await _delete(_key(accountId, 'token_type'));
    await _delete(_key(accountId, 'scope'));
  }

  @override
  Future<void> clearActiveAccount() {
    return _delete(activeAccountKey);
  }

  String _key(String accountId, String name) =>
      'busymax.oauth.$accountId.$name';

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
      'Secure token storage runtime: backend=flutter-secure-storage '
      'snap=${_isRunningInSnap()} secret_backend=${_secretBackendLabel()}',
    );
  }

  OAuthException _secureStorageException(
    String operation,
    PlatformException error,
  ) {
    _logger.warning(
      'Secure token storage $operation failed: '
      '${sanitizedFlutterSecureStorageError(error)}',
    );
    return const OAuthException(
      'OAuthSecureStorageUnavailable',
      secureTokenStorageUnavailableMessage,
    );
  }
}

const secureTokenStorageUnavailableMessage =
    'Secure token storage is locked. Unlock your system keyring and try again.';

String sanitizedFlutterSecureStorageError(PlatformException error) {
  final message = redactForLog(error.message).replaceAll(RegExp(r'\s+'), ' ');
  return 'domain=flutter_secure_storage_linux code=${error.code} '
      'message=${message.trim()} details_type=${error.details.runtimeType}';
}

class InMemoryOAuthTokenStore implements OAuthTokenStore {
  final _tokens = <String, OAuthTokenSet>{};
  String? _activeAccountId;

  @override
  Future<void> clearActiveAccount() async {
    _activeAccountId = null;
  }

  @override
  Future<void> clearTokenSet(String accountId) async {
    _tokens.remove(accountId);
  }

  @override
  Future<String?> readActiveAccountId() async => _activeAccountId;

  @override
  Future<OAuthTokenSet?> readTokenSet(String accountId) async {
    return _tokens[accountId];
  }

  @override
  Future<void> saveTokenSet(String accountId, OAuthTokenSet tokenSet) async {
    _tokens[accountId] = tokenSet;
  }

  @override
  Future<void> setActiveAccountId(String accountId) async {
    _activeAccountId = accountId;
  }
}

bool _isRunningInSnap() => Platform.environment['SNAP']?.isNotEmpty ?? false;

String _secretBackendLabel() {
  final backend = Platform.environment['SECRET_BACKEND'];
  if (backend == null || backend.isEmpty) {
    return '<unset>';
  }
  if (backend == 'file') {
    return 'file';
  }
  return '<set>';
}
