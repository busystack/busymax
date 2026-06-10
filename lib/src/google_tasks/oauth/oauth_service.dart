import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../config/build_config.dart';
import '../../core/logging/redacting_logger.dart';
import '../api/google_tasks_api_surface.dart';
import 'oauth_loopback_flow.dart';
import 'oauth_models.dart';
import 'oauth_token_store.dart';

abstract interface class OAuthGateway {
  Future<String?> get activeAccountId;

  Future<OAuthTokenSet?> readActiveTokenSet();

  Future<GoogleUserInfo?> fetchUserInfo(OAuthTokenSet tokenSet);

  Future<OAuthSignInResult> signIn({String? loginHint});

  Future<OAuthTokenSet> refreshActiveToken();

  Future<void> signOut();

  Future<void> signOutAccount(String accountId);

  Future<void> revokeAndSignOut();

  Future<void> revokeAndSignOutAccount(String accountId);

  Future<void> clearLocalSession({String? accountId});

  Future<void> cancelSignIn();
}

class OAuthService implements OAuthGateway {
  OAuthService({
    required BuildConfig config,
    required http.Client httpClient,
    required OAuthTokenStore tokenStore,
    required OAuthLoopbackFlow loopbackFlow,
    DateTime Function()? nowUtc,
  }) : _config = config,
       _httpClient = httpClient,
       _tokenStore = tokenStore,
       _loopbackFlow = loopbackFlow,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final BuildConfig _config;
  final http.Client _httpClient;
  final OAuthTokenStore _tokenStore;
  final OAuthLoopbackFlow _loopbackFlow;
  final DateTime Function() _nowUtc;
  final RedactingLogger _logger = RedactingLogger(Logger('OAuthService'));

  @override
  Future<String?> get activeAccountId => _tokenStore.readActiveAccountId();

  @override
  Future<OAuthTokenSet?> readActiveTokenSet() async {
    final accountId = await _tokenStore.readActiveAccountId();
    if (accountId == null) {
      return null;
    }
    return _tokenStore.readTokenSet(accountId);
  }

  Future<OAuthTokenSet?> readTokenSet(String accountId) {
    return _tokenStore.readTokenSet(accountId);
  }

  @override
  Future<GoogleUserInfo?> fetchUserInfo(OAuthTokenSet tokenSet) async {
    if (tokenSet.accessToken.trim().isEmpty) {
      return null;
    }
    final response = await _httpClient.get(
      Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
      headers: {
        'Authorization': '${tokenSet.tokenType} ${tokenSet.accessToken}',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logger.warning(
        'Google userinfo request failed with HTTP ${response.statusCode}.',
      );
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) {
      return GoogleUserInfo.fromJson(decoded);
    }
    if (decoded is Map) {
      return GoogleUserInfo.fromJson(decoded.cast<String, Object?>());
    }
    return null;
  }

  Future<OAuthTokenSet> validTokenForAccount(String accountId) async {
    final tokenSet = await _tokenStore.readTokenSet(accountId);
    if (tokenSet == null) {
      throw const OAuthException(
        'OAuthMissingToken',
        'No OAuth token is available for this account.',
      );
    }
    if (tokenSet.expiresWithin(const Duration(seconds: 60), _nowUtc())) {
      return refreshTokenForAccount(accountId);
    }
    return tokenSet;
  }

  Future<String> authorizationHeaderForAccount(String accountId) async {
    final tokenSet = await validTokenForAccount(accountId);
    return 'Bearer ${tokenSet.accessToken}';
  }

  @override
  Future<OAuthSignInResult> signIn({String? loginHint}) async {
    if (!_config.hasGoogleOAuthClientId) {
      throw const OAuthException(
        'OAuthMissingClientId',
        'BusyMax is missing GOOGLE_OAUTH_CLIENT_ID.',
      );
    }

    final result = await _loopbackFlow.start(
      authorizationEndpoint: Uri.parse(_config.oauthAuthorizationEndpoint),
      clientId: _config.googleOAuthClientId,
      scope: googleBusyMaxOAuthScope,
      extraAuthorizationParameters: const {'include_granted_scopes': 'true'},
      loginHint: loginHint,
    );
    final tokenSet = await exchangeAuthorizationCode(
      code: result.callback.code,
      codeVerifier: result.codeVerifier,
      redirectUri: result.redirectUri,
      fallbackScopeText: result.callback.scope,
    );
    final accountId = deriveAccountId(tokenSet);
    await _tokenStore.saveTokenSet(accountId, tokenSet);
    await _tokenStore.setActiveAccountId(accountId);
    return OAuthSignInResult(accountId: accountId, tokenSet: tokenSet);
  }

  @override
  Future<void> cancelSignIn() => _loopbackFlow.cancel();

  @override
  Future<void> signOut() => _tokenStore.clearActiveAccount();

  @override
  Future<void> signOutAccount(String accountId) async {
    final active = await _tokenStore.readActiveAccountId();
    await _tokenStore.clearTokenSet(accountId);
    if (active == accountId) {
      await _tokenStore.clearActiveAccount();
    }
  }

  Future<OAuthTokenSet> exchangeAuthorizationCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
    String? fallbackScopeText,
  }) async {
    final clientId = _config.googleOAuthClientId.trim();
    final clientSecret = _config.googleOAuthClientSecret.trim();
    _validateTokenExchangeParameters(
      clientId: clientId,
      code: code,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
    );
    final tokenEndpoint = Uri.parse(_config.oauthTokenEndpoint);
    _logger.info(
      'OAuth token exchange request: '
      'endpoint=${_tokenEndpointLabel(tokenEndpoint)} '
      'redirect_uri=$redirectUri '
      'grant_type=authorization_code '
      'has_code=${code.isNotEmpty} '
      'has_code_verifier=${codeVerifier.isNotEmpty} '
      'has_client_secret=${clientSecret.isNotEmpty} '
      'client_id_suffix=${_clientIdSuffix(clientId)}',
    );

    final response = await _httpClient.post(
      tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'code': code,
        'code_verifier': codeVerifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
        if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OAuthException(
        'OAuthTokenExchangeFailed',
        _tokenEndpointFailureMessage(operation: 'exchange', response: response),
      );
    }

    final json = jsonDecode(response.body) as Map<String, Object?>;
    return OAuthTokenSet.fromTokenEndpointJson(
      json,
      issuedAtUtc: _nowUtc(),
      fallbackScopeText: fallbackScopeText,
    );
  }

  @override
  Future<OAuthTokenSet> refreshActiveToken() async {
    final accountId = await _tokenStore.readActiveAccountId();
    if (accountId == null) {
      throw const OAuthException('OAuthRefreshFailed', 'No active account.');
    }

    return refreshTokenForAccount(accountId);
  }

  Future<OAuthTokenSet> refreshTokenForAccount(String accountId) async {
    final current = await _tokenStore.readTokenSet(accountId);
    if (current == null || !current.canRefresh) {
      throw const OAuthException(
        'OAuthRefreshFailed',
        'No refresh token is available.',
      );
    }

    try {
      final refreshed = await refreshToken(current);
      await _tokenStore.saveTokenSet(accountId, refreshed);
      return refreshed;
    } on OAuthException catch (error) {
      if (error is OAuthRefreshException && error.statusCode == 400) {
        await _clearAccountAfterInvalidRefresh(accountId);
      }
      rethrow;
    }
  }

  Future<OAuthTokenSet> refreshToken(OAuthTokenSet current) async {
    final clientId = _config.googleOAuthClientId.trim();
    final clientSecret = _config.googleOAuthClientSecret.trim();
    _validateTokenRefreshParameters(
      clientId: clientId,
      refreshToken: current.refreshToken,
    );
    final tokenEndpoint = Uri.parse(_config.oauthTokenEndpoint);
    _logger.info(
      'OAuth token refresh request: '
      'endpoint=${_tokenEndpointLabel(tokenEndpoint)} '
      'grant_type=refresh_token '
      'has_refresh_token=${current.refreshToken?.isNotEmpty ?? false} '
      'has_client_secret=${clientSecret.isNotEmpty} '
      'client_id_suffix=${_clientIdSuffix(clientId)}',
    );

    final response = await _httpClient.post(
      tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': current.refreshToken!,
        if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OAuthRefreshException(
        'OAuthRefreshFailed',
        _tokenEndpointFailureMessage(operation: 'refresh', response: response),
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, Object?>;
    return OAuthTokenSet.fromTokenEndpointJson(
      json,
      issuedAtUtc: _nowUtc(),
      existingRefreshToken: current.refreshToken,
      existingIdToken: current.idToken,
      existingScopes: current.scopes,
    );
  }

  @override
  Future<void> revokeAndSignOut() async {
    final accountId = await _tokenStore.readActiveAccountId();
    if (accountId == null) {
      return;
    }

    await revokeAndSignOutAccount(accountId);
  }

  @override
  Future<void> revokeAndSignOutAccount(String accountId) async {
    final active = await _tokenStore.readActiveAccountId();
    final tokenSet = await _tokenStore.readTokenSet(accountId);
    final token = tokenSet?.refreshToken ?? tokenSet?.accessToken;
    try {
      if (token != null && token.isNotEmpty) {
        await _httpClient.post(
          Uri.parse(
            _config.oauthRevocationEndpoint,
          ).replace(queryParameters: {'token': token}),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        );
      }
    } finally {
      await _tokenStore.clearTokenSet(accountId);
      if (active == accountId) {
        await _tokenStore.clearActiveAccount();
      }
    }
  }

  @override
  Future<void> clearLocalSession({String? accountId}) async {
    final targetAccountId =
        accountId ?? await _tokenStore.readActiveAccountId();
    if (targetAccountId != null) {
      await _tokenStore.clearTokenSet(targetAccountId);
    }
    if (targetAccountId == null ||
        await _tokenStore.readActiveAccountId() == targetAccountId) {
      await _tokenStore.clearActiveAccount();
    }
  }

  Future<void> _clearAccountAfterInvalidRefresh(String accountId) async {
    final active = await _tokenStore.readActiveAccountId();
    await _tokenStore.clearTokenSet(accountId);
    if (active == accountId) {
      await _tokenStore.clearActiveAccount();
    }
  }
}

class OAuthSignInResult {
  const OAuthSignInResult({required this.accountId, required this.tokenSet});

  final String accountId;
  final OAuthTokenSet tokenSet;
}

class GoogleUserInfo {
  const GoogleUserInfo({
    this.subject,
    this.name,
    this.email,
    required this.rawJson,
  });

  factory GoogleUserInfo.fromJson(Map<String, Object?> json) {
    return GoogleUserInfo(
      subject: _nonBlankString(json['sub']),
      name: _nonBlankString(json['name']),
      email: _nonBlankString(json['email']),
      rawJson: json,
    );
  }

  final String? subject;
  final String? name;
  final String? email;
  final Map<String, Object?> rawJson;
}

String deriveAccountId(OAuthTokenSet tokenSet) {
  final subject = googleIdTokenClaims(tokenSet)['sub']?.toString().trim();
  if (subject != null && subject.isNotEmpty) {
    return 'google:$subject';
  }
  final stableInput = tokenSet.refreshToken ?? tokenSet.accessToken;
  final digest = sha256.convert(utf8.encode(stableInput)).toString();
  return 'google:${digest.substring(0, 24)}';
}

Map<String, Object?> googleIdTokenClaims(OAuthTokenSet tokenSet) {
  final idToken = tokenSet.idToken;
  if (idToken == null || idToken.isEmpty) {
    return const {};
  }
  final parts = idToken.split('.');
  if (parts.length < 2) {
    return const {};
  }
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload = utf8.decode(base64Url.decode(normalized));
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }
  } on Object {
    return const {};
  }
  return const {};
}

String? _nonBlankString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

void _validateTokenExchangeParameters({
  required String clientId,
  required String code,
  required String codeVerifier,
  required String redirectUri,
}) {
  if (clientId.trim().isEmpty) {
    throw const OAuthException(
      'OAuthMissingClientId',
      'BusyMax is missing GOOGLE_OAUTH_CLIENT_ID.',
    );
  }
  if (code.trim().isEmpty) {
    throw const OAuthException(
      'OAuthTokenExchangeInvalidRequest',
      'OAuth token exchange is missing an authorization code.',
    );
  }
  if (codeVerifier.trim().isEmpty) {
    throw const OAuthException(
      'OAuthTokenExchangeInvalidRequest',
      'OAuth token exchange is missing the PKCE code verifier.',
    );
  }
  if (redirectUri.trim().isEmpty) {
    throw const OAuthException(
      'OAuthTokenExchangeInvalidRequest',
      'OAuth token exchange is missing the redirect URI.',
    );
  }

  final parsedRedirectUri = Uri.tryParse(redirectUri);
  if (parsedRedirectUri == null ||
      !_isAllowedLoopbackRedirectUri(parsedRedirectUri)) {
    throw const OAuthException(
      'OAuthTokenExchangeInvalidRequest',
      'OAuth token exchange redirect URI must be loopback HTTP.',
    );
  }
}

void _validateTokenRefreshParameters({
  required String clientId,
  required String? refreshToken,
}) {
  if (clientId.trim().isEmpty) {
    throw const OAuthException(
      'OAuthMissingClientId',
      'BusyMax is missing GOOGLE_OAUTH_CLIENT_ID.',
    );
  }
  if (refreshToken == null || refreshToken.trim().isEmpty) {
    throw const OAuthException(
      'OAuthRefreshFailed',
      'No refresh token is available.',
    );
  }
}

bool _isAllowedLoopbackRedirectUri(Uri redirectUri) {
  return redirectUri.scheme == 'http' &&
      (redirectUri.host == '127.0.0.1' || redirectUri.host == 'localhost') &&
      redirectUri.hasPort &&
      redirectUri.port > 0 &&
      redirectUri.path == '/' &&
      !redirectUri.hasQuery &&
      redirectUri.fragment.isEmpty;
}

String _tokenEndpointLabel(Uri endpoint) {
  final port = endpoint.hasPort ? ':${endpoint.port}' : '';
  return '${endpoint.scheme}://${endpoint.host}$port${endpoint.path}';
}

String _clientIdSuffix(String clientId) {
  final trimmed = clientId.trim();
  if (trimmed.isEmpty) {
    return '<empty>';
  }
  const googleClientIdSuffix = '.apps.googleusercontent.com';
  if (trimmed.endsWith(googleClientIdSuffix)) {
    return '...apps.googleusercontent.com';
  }

  final suffixLength = trimmed.length < 12 ? trimmed.length : 12;
  return '...${trimmed.substring(trimmed.length - suffixLength)}';
}

String _tokenEndpointFailureMessage({
  required String operation,
  required http.Response response,
}) {
  final details = _tokenEndpointFailureDetails(response.body);
  if (details == null || details.text.isEmpty) {
    return 'Google token $operation failed with HTTP ${response.statusCode}.';
  }
  if (_isMissingClientSecretError(details)) {
    return 'This Google Desktop OAuth client requires a client secret. Re-run '
        'BusyMax with GOOGLE_OAUTH_CLIENT_SECRET set from the same Desktop '
        'OAuth client credentials.';
  }

  final statusPrefix = details.isJson
      ? 'Google token $operation failed'
      : 'Google token $operation failed with HTTP ${response.statusCode}';
  return '$statusPrefix: ${details.text}.';
}

_TokenEndpointFailureDetails? _tokenEndpointFailureDetails(String body) {
  final trimmedBody = body.trim();
  if (trimmedBody.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(trimmedBody);
    if (decoded is Map<String, Object?>) {
      final error = redactForLog(decoded['error']).trim();
      final description = redactForLog(decoded['error_description']).trim();
      if (error.isNotEmpty && description.isNotEmpty) {
        return _TokenEndpointFailureDetails('$error - $description', true);
      }
      if (error.isNotEmpty) {
        return _TokenEndpointFailureDetails(error, true);
      }
      if (description.isNotEmpty) {
        return _TokenEndpointFailureDetails(description, true);
      }
    }
  } on FormatException {
    return _TokenEndpointFailureDetails(redactForLog(trimmedBody), false);
  }

  return _TokenEndpointFailureDetails(redactForLog(trimmedBody), false);
}

bool _isMissingClientSecretError(_TokenEndpointFailureDetails details) {
  final normalized = details.text.toLowerCase();
  return normalized.contains('invalid_request') &&
      normalized.contains('client_secret') &&
      normalized.contains('missing');
}

class _TokenEndpointFailureDetails {
  const _TokenEndpointFailureDetails(this.text, this.isJson);

  final String text;
  final bool isJson;
}
