import 'dart:convert';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/build_config.dart';
import '../core/auth/account_token_broker.dart';
import '../core/auth/oauth_models.dart';
import '../core/secrets/secret_store.dart';
import '../google_tasks/api/google_tasks_api_surface.dart';
import '../google_tasks/oauth/oauth_service.dart';
import '../microsoft_todo/api/microsoft_todo_api_models.dart';
import '../microsoft_todo/oauth/microsoft_oauth_service.dart';
import '../providers/busy_provider.dart';

const _googleScopes = <String>[
  'openid',
  'email',
  'profile',
  googleTasksReadWriteScope,
  googleCalendarReadWriteScope,
];

const _microsoftNativeScopes = <String>[
  'User.Read',
  'Tasks.ReadWrite',
  'Calendars.ReadWrite',
];

const _microsoftStoredScopes = <String>{
  'https://graph.microsoft.com/User.Read',
  'https://graph.microsoft.com/Tasks.ReadWrite',
  'https://graph.microsoft.com/Calendars.ReadWrite',
};

final class AndroidAuthorizationBroker
    implements OAuthGateway, MicrosoftOAuthGateway, AccountTokenBroker {
  AndroidAuthorizationBroker({
    required BusyMaxAndroidPlatform platform,
    required http.Client httpClient,
    required SecretStore secretStore,
    required BuildConfig config,
  }) : _platform = platform,
       _httpClient = httpClient,
       _secretStore = secretStore,
       _config = config;

  final BusyMaxAndroidPlatform _platform;
  final http.Client _httpClient;
  final SecretStore _secretStore;
  final BuildConfig _config;
  final Map<String, String> _lastAccessTokens = <String, String>{};

  @override
  Future<String?> get activeAccountId => _secretStore.readActiveAccountId();

  @override
  Future<OAuthTokenSet?> readActiveTokenSet() async {
    final accountId = await activeAccountId;
    if (accountId == null || !accountId.startsWith('google:')) return null;
    return _googleToken(accountId);
  }

  @override
  Future<OAuthSignInResult> signIn({String? loginHint}) async {
    try {
      final native = await _platform.authorizeGoogleInteractively(
        scopes: _googleScopes,
      );
      final tokenSet = _tokenSet(native, extraScopes: _googleScopes);
      final user = await fetchUserInfo(tokenSet);
      final subject = user?.subject?.trim();
      if (subject == null || subject.isEmpty) {
        await _platform.clearRejectedToken(native.accessToken);
        throw const OAuthException(
          'OAuthMissingSubject',
          'Google did not return an account identity.',
        );
      }
      final accountId = 'google:$subject';
      await _platform.bindAuthorization(
        provider: BusyProvider.google.storageValue,
        accountId: accountId,
        nativeAccountId: native.nativeAccountId,
        username: native.username ?? user?.email,
      );
      await _secretStore.setActiveAccountId(accountId);
      _lastAccessTokens[accountId] = native.accessToken;
      return OAuthSignInResult(accountId: accountId, tokenSet: tokenSet);
    } on PlatformException catch (error) {
      throw _oauthError(error, provider: 'Google');
    }
  }

  @override
  Future<MicrosoftOAuthSignInResult> signInWithMicrosoft() async {
    try {
      final native = await _platform.authorizeMicrosoftInteractively(
        scopes: _microsoftNativeScopes,
      );
      final tokenSet = _tokenSet(native, extraScopes: _microsoftStoredScopes);
      final user = await _microsoftMe(native.accessToken);
      if (user.id.trim().isEmpty) {
        throw const OAuthException(
          'MicrosoftOAuthMissingUserId',
          'Microsoft Graph did not return a user id.',
        );
      }
      final accountId = 'microsoft:${user.id}';
      await _platform.bindAuthorization(
        provider: BusyProvider.microsoft.storageValue,
        accountId: accountId,
        nativeAccountId: native.nativeAccountId,
        username: native.username ?? user.mail ?? user.userPrincipalName,
        authority: native.authority,
      );
      await _secretStore.setActiveAccountId(accountId);
      _lastAccessTokens[accountId] = native.accessToken;
      return MicrosoftOAuthSignInResult(
        accountId: accountId,
        tokenSet: tokenSet,
        user: user,
      );
    } on PlatformException catch (error) {
      throw _oauthError(error, provider: 'Microsoft');
    }
  }

  @override
  Future<GoogleUserInfo?> fetchUserInfo(OAuthTokenSet tokenSet) async {
    final response = await _httpClient.get(
      Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
      headers: {'Authorization': 'Bearer ${tokenSet.accessToken}'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body);
    return decoded is Map
        ? GoogleUserInfo.fromJson(decoded.cast<String, Object?>())
        : null;
  }

  Future<MicrosoftTodoUserDto> _microsoftMe(String accessToken) async {
    final response = await _httpClient.get(
      Uri.parse('${_config.microsoftGraphBaseUrl}/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OAuthException(
        'MicrosoftOAuthUserInfoFailed',
        'Microsoft account details could not be loaded (HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const OAuthException(
        'MicrosoftOAuthUserInfoFailed',
        'Microsoft returned an invalid account response.',
      );
    }
    return MicrosoftTodoUserDto.fromJson(decoded.cast<String, Object?>());
  }

  @override
  Future<String> authorizationHeader(
    BusyProvider provider,
    String accountId,
  ) async {
    final token = switch (provider) {
      BusyProvider.google => await _platform.authorizeGoogleSilently(
        accountId: accountId,
        scopes: _googleScopes,
      ),
      BusyProvider.microsoft => await _platform.authorizeMicrosoftSilently(
        accountId: accountId,
        scopes: _microsoftNativeScopes,
      ),
      _ => throw StateError('$provider does not use native authorization.'),
    };
    _lastAccessTokens[accountId] = token.accessToken;
    return 'Bearer ${token.accessToken}';
  }

  @override
  Future<void> recoverUnauthorized(
    BusyProvider provider,
    String accountId,
  ) async {
    final rejected = _lastAccessTokens.remove(accountId);
    if (provider == BusyProvider.google && rejected != null) {
      await _platform.clearRejectedToken(rejected);
    }
    await authorizationHeader(provider, accountId);
  }

  Future<OAuthTokenSet> _googleToken(String accountId) async {
    final native = await _platform.authorizeGoogleSilently(
      accountId: accountId,
      scopes: _googleScopes,
    );
    _lastAccessTokens[accountId] = native.accessToken;
    return _tokenSet(native, extraScopes: _googleScopes);
  }

  @override
  Future<OAuthTokenSet> refreshActiveToken() async {
    final accountId = await activeAccountId;
    if (accountId == null) {
      throw const OAuthException(
        'OAuthMissingToken',
        'No Google account is active.',
      );
    }
    await recoverUnauthorized(BusyProvider.google, accountId);
    return _googleToken(accountId);
  }

  @override
  Future<void> revokeAndSignOutAccount(String accountId) async {
    await _platform.removeAuthorization(
      provider: BusyProvider.google.storageValue,
      accountId: accountId,
      revoke: true,
    );
    await clearLocalSession(accountId: accountId);
  }

  @override
  Future<void> revokeAuthorization(String accountId) =>
      _platform.removeAuthorization(
        provider: BusyProvider.google.storageValue,
        accountId: accountId,
        revoke: true,
      );

  @override
  Future<void> clearLocalSession({String? accountId}) async {
    final target = accountId ?? await activeAccountId;
    if (target != null) _lastAccessTokens.remove(target);
    if (target == null || await activeAccountId == target) {
      await _secretStore.clearActiveAccount();
    }
  }

  @override
  Future<void> signOutAccount(String accountId) async {
    await _platform.removeAuthorization(
      provider: BusyProvider.microsoft.storageValue,
      accountId: accountId,
    );
    await clearLocalSession(accountId: accountId);
  }

  @override
  Future<void> cancelSignIn() => _platform.cancelInteractiveAuthorization();

  OAuthTokenSet _tokenSet(
    AndroidAuthorizationToken token, {
    Iterable<String> extraScopes = const [],
  }) => OAuthTokenSet(
    accessToken: token.accessToken,
    expiresAtUtc:
        token.expiresAtUtc ??
        DateTime.now().toUtc().add(const Duration(minutes: 45)),
    tokenType: 'Bearer',
    scopes: {...token.scopes, ...extraScopes},
  );
}

OAuthException _oauthError(
  PlatformException error, {
  required String provider,
}) {
  final cancelled = error.code == 'android/auth-cancelled';
  return OAuthException(
    cancelled ? 'OAuthSignInCancelled' : error.code,
    cancelled
        ? '$provider sign-in was cancelled.'
        : (error.message ?? '$provider authorization failed.'),
  );
}
