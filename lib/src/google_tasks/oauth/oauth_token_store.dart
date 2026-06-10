import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  SecureOAuthTokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const activeAccountKey = 'busymax.oauth.active_account_id';

  @override
  Future<String?> readActiveAccountId() => _storage.read(key: activeAccountKey);

  @override
  Future<OAuthTokenSet?> readTokenSet(String accountId) async {
    final accessToken = await _storage.read(
      key: _key(accountId, 'access_token'),
    );
    final expiresAtText = await _storage.read(
      key: _key(accountId, 'expires_at_utc'),
    );
    if (accessToken == null || expiresAtText == null) {
      return null;
    }

    final refreshToken = await _storage.read(
      key: _key(accountId, 'refresh_token'),
    );
    final tokenType = await _storage.read(key: _key(accountId, 'token_type'));
    final scopeText = await _storage.read(key: _key(accountId, 'scope'));
    final idToken = await _storage.read(key: _key(accountId, 'id_token'));

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
    await _storage.write(
      key: _key(accountId, 'access_token'),
      value: tokenSet.accessToken,
    );
    if (tokenSet.refreshToken != null) {
      await _storage.write(
        key: _key(accountId, 'refresh_token'),
        value: tokenSet.refreshToken,
      );
    }
    if (tokenSet.idToken != null) {
      await _storage.write(
        key: _key(accountId, 'id_token'),
        value: tokenSet.idToken,
      );
    }
    await _storage.write(
      key: _key(accountId, 'expires_at_utc'),
      value: tokenSet.expiresAtUtc.toUtc().toIso8601String(),
    );
    await _storage.write(
      key: _key(accountId, 'token_type'),
      value: tokenSet.tokenType,
    );
    await _storage.write(
      key: _key(accountId, 'scope'),
      value: tokenSet.scopes.join(' '),
    );
  }

  @override
  Future<void> setActiveAccountId(String accountId) {
    return _storage.write(key: activeAccountKey, value: accountId);
  }

  @override
  Future<void> clearTokenSet(String accountId) async {
    await _storage.delete(key: _key(accountId, 'access_token'));
    await _storage.delete(key: _key(accountId, 'refresh_token'));
    await _storage.delete(key: _key(accountId, 'id_token'));
    await _storage.delete(key: _key(accountId, 'expires_at_utc'));
    await _storage.delete(key: _key(accountId, 'token_type'));
    await _storage.delete(key: _key(accountId, 'scope'));
  }

  @override
  Future<void> clearActiveAccount() {
    return _storage.delete(key: activeAccountKey);
  }

  String _key(String accountId, String name) =>
      'busymax.oauth.$accountId.$name';
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
