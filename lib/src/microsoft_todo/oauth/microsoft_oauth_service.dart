import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../config/build_config.dart';
import '../../core/logging/redacting_logger.dart';
import '../../google_tasks/oauth/oauth_loopback_flow.dart';
import '../../providers/busy_provider.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import '../api/microsoft_todo_api_client.dart';
import '../api/microsoft_todo_api_models.dart';

const microsoftTodoOAuthScopes =
    'openid profile email offline_access '
    'https://graph.microsoft.com/User.Read '
    'https://graph.microsoft.com/Tasks.ReadWrite '
    'https://graph.microsoft.com/Calendars.ReadWrite';

const microsoftSharedCalendarScope =
    'https://graph.microsoft.com/Calendars.ReadWrite.Shared';

const microsoftCategoryScope =
    'https://graph.microsoft.com/MailboxSettings.Read';

abstract interface class MicrosoftCategoryAuthorization {
  Future<void> authorizeCategoryAccess(String accountId);
}

abstract interface class MicrosoftSharedCalendarAuthorization {
  Future<void> authorizeSharedCalendarAccess(String accountId);
}

const microsoftSignInCallbackNotReceivedMessage =
    'Microsoft sign-in callback was not received by BusyMax. Try signing in '
    'again. If the browser opened an old tab, close it and start sign-in '
    'again.';

abstract interface class MicrosoftOAuthGateway {
  Future<MicrosoftOAuthSignInResult> signInWithMicrosoft();

  Future<void> cancelSignIn();

  Future<void> signOutAccount(String accountId);
}

class MicrosoftOAuthService
    implements
        MicrosoftOAuthGateway,
        MicrosoftSharedCalendarAuthorization,
        MicrosoftCategoryAuthorization {
  MicrosoftOAuthService({
    required BuildConfig config,
    required http.Client httpClient,
    required SecretStore tokenStore,
    required OAuthLoopbackFlow loopbackFlow,
    DateTime Function()? nowUtc,
  }) : _config = config,
       _httpClient = httpClient,
       _tokenStore = tokenStore,
       _loopbackFlow = loopbackFlow,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final BuildConfig _config;
  final http.Client _httpClient;
  final SecretStore _tokenStore;
  final OAuthLoopbackFlow _loopbackFlow;
  final DateTime Function() _nowUtc;
  final RedactingLogger _logger = RedactingLogger(
    Logger('MicrosoftOAuthService'),
  );
  final Map<String, int> _credentialGenerations = {};

  Future<MicrosoftOAuthSignInResult> signIn() async {
    final clientId = _config.microsoftOAuthClientId.trim();
    if (clientId.isEmpty) {
      throw const OAuthException(
        'MicrosoftOAuthMissingClientId',
        'Microsoft sign-in is not configured. Set MICROSOFT_OAUTH_CLIENT_ID.',
      );
    }

    final result = await _loopbackFlow.start(
      authorizationEndpoint: _authorizationEndpoint,
      clientId: clientId,
      scope: microsoftTodoOAuthScopes,
      redirectHost: 'localhost',
      signInCancelledMessage: 'Microsoft sign-in was cancelled.',
      callbackNotReceivedMessage: microsoftSignInCallbackNotReceivedMessage,
      serverStartFailureMessage:
          'Could not start the local Microsoft sign-in callback listener.',
      browserLaunchFailureMessage:
          'Could not open the browser for Microsoft sign-in.',
      extraAuthorizationParameters: const {
        'response_mode': 'query',
        'prompt': 'select_account',
      },
    );

    final tokenSet = await exchangeAuthorizationCode(
      code: result.callback.code,
      codeVerifier: result.codeVerifier,
      redirectUri: result.redirectUri,
    );
    final user = await _getMe(tokenSet);
    if (user.id.trim().isEmpty) {
      throw const OAuthException(
        'MicrosoftOAuthMissingUserId',
        'Microsoft Graph did not return a user id.',
      );
    }

    final accountId = 'microsoft:${user.id}';
    await _tokenStore.saveOAuthTokenSet(
      accountId,
      BusyProvider.microsoft,
      tokenSet,
    );
    await _tokenStore.setActiveAccountId(accountId);
    return MicrosoftOAuthSignInResult(
      accountId: accountId,
      tokenSet: tokenSet,
      user: user,
      tenantId: microsoftTenantIdFromIdToken(tokenSet.idToken),
    );
  }

  @override
  Future<MicrosoftOAuthSignInResult> signInWithMicrosoft() => signIn();

  @override
  Future<void> cancelSignIn() => _loopbackFlow.cancel();

  Future<OAuthTokenSet?> readTokenSet(String accountId) {
    return _readTokenSet(accountId);
  }

  Future<OAuthTokenSet> validTokenForAccount(String accountId) async {
    final tokenSet = await _readTokenSet(accountId);
    if (tokenSet == null) {
      throw const OAuthException(
        'MicrosoftOAuthMissingToken',
        'No Microsoft OAuth token is available for this account.',
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

  Future<String> sharedCalendarAuthorizationHeaderForAccount(
    String accountId,
  ) async {
    final tokenSet = await validTokenForAccount(accountId);
    if (!tokenSet.scopes.contains(microsoftSharedCalendarScope)) {
      throw const OAuthException(
        'MicrosoftOAuthSharedConsentRequired',
        'Shared-calendar permission must be granted for this account.',
      );
    }
    return 'Bearer ${tokenSet.accessToken}';
  }

  Future<String> categoryAuthorizationHeaderForAccount(String accountId) async {
    final tokenSet = await validTokenForAccount(accountId);
    if (!tokenSet.scopes.contains(microsoftCategoryScope)) {
      throw const OAuthException(
        'MicrosoftOAuthCategoryConsentRequired',
        'Outlook category lookup requires optional mailbox-settings consent.',
      );
    }
    return 'Bearer ${tokenSet.accessToken}';
  }

  @override
  Future<void> authorizeCategoryAccess(String accountId) async {
    final generation = _credentialGenerations[accountId] ?? 0;
    final existing = await _readTokenSet(accountId);
    if (existing == null) {
      throw const OAuthException(
        'MicrosoftOAuthMissingToken',
        'Reconnect this Microsoft account before loading categories.',
      );
    }
    if (existing.scopes.contains(microsoftCategoryScope)) return;
    final result = await _loopbackFlow.start(
      authorizationEndpoint: _authorizationEndpoint,
      clientId: _config.microsoftOAuthClientId.trim(),
      scope: [
        microsoftTodoOAuthScopes,
        if (existing.scopes.contains(microsoftSharedCalendarScope))
          microsoftSharedCalendarScope,
        microsoftCategoryScope,
      ].join(' '),
      redirectHost: 'localhost',
      signInCancelledMessage: 'Microsoft category consent was cancelled.',
      callbackNotReceivedMessage: microsoftSignInCallbackNotReceivedMessage,
      serverStartFailureMessage:
          'Could not start the Microsoft sign-in callback listener.',
      browserLaunchFailureMessage:
          'Could not open the browser for Microsoft sign-in.',
      extraAuthorizationParameters: const {
        'response_mode': 'query',
        'prompt': 'consent',
      },
    );
    final candidate = await exchangeAuthorizationCode(
      code: result.callback.code,
      codeVerifier: result.codeVerifier,
      redirectUri: result.redirectUri,
      fallbackScopeText: '',
    );
    final user = await _getMe(candidate);
    if ('microsoft:${user.id}' != accountId ||
        !candidate.scopes.contains(microsoftCategoryScope) ||
        !candidate.scopes.containsAll({
          'https://graph.microsoft.com/User.Read',
          'https://graph.microsoft.com/Tasks.ReadWrite',
          'https://graph.microsoft.com/Calendars.ReadWrite',
          if (existing.scopes.contains(microsoftSharedCalendarScope))
            microsoftSharedCalendarScope,
        })) {
      throw const OAuthException(
        'MicrosoftOAuthCategoryConsentDenied',
        'Outlook category access was not granted for this account.',
      );
    }
    if ((_credentialGenerations[accountId] ?? 0) != generation ||
        await _readTokenSet(accountId) == null) {
      throw const OAuthException(
        'MicrosoftOAuthCategoryConsentCancelled',
        'The account was removed before category consent completed.',
      );
    }
    await _tokenStore.saveOAuthTokenSet(
      accountId,
      BusyProvider.microsoft,
      candidate,
    );
  }

  @override
  Future<void> authorizeSharedCalendarAccess(String accountId) async {
    final generation = _credentialGenerations[accountId] ?? 0;
    final existing = await _readTokenSet(accountId);
    if (existing == null) {
      throw const OAuthException(
        'MicrosoftOAuthMissingToken',
        'Reconnect this Microsoft account before opening a shared calendar.',
      );
    }
    if (existing.scopes.contains(microsoftSharedCalendarScope)) return;
    final result = await _loopbackFlow.start(
      authorizationEndpoint: _authorizationEndpoint,
      clientId: _config.microsoftOAuthClientId.trim(),
      scope: [
        microsoftTodoOAuthScopes,
        microsoftSharedCalendarScope,
        if (existing.scopes.contains(microsoftCategoryScope))
          microsoftCategoryScope,
      ].join(' '),
      redirectHost: 'localhost',
      signInCancelledMessage:
          'Microsoft shared-calendar consent was cancelled.',
      callbackNotReceivedMessage: microsoftSignInCallbackNotReceivedMessage,
      serverStartFailureMessage:
          'Could not start the Microsoft sign-in callback listener.',
      browserLaunchFailureMessage:
          'Could not open the browser for Microsoft sign-in.',
      extraAuthorizationParameters: const {
        'response_mode': 'query',
        'prompt': 'consent',
      },
    );
    final candidate = await exchangeAuthorizationCode(
      code: result.callback.code,
      codeVerifier: result.codeVerifier,
      redirectUri: result.redirectUri,
      fallbackScopeText: '',
    );
    final user = await _getMe(candidate);
    if ('microsoft:${user.id}' != accountId ||
        !candidate.scopes.contains(microsoftSharedCalendarScope) ||
        !candidate.scopes.contains('https://graph.microsoft.com/User.Read') ||
        !candidate.scopes.contains(
          'https://graph.microsoft.com/Tasks.ReadWrite',
        ) ||
        !candidate.scopes.contains(
          'https://graph.microsoft.com/Calendars.ReadWrite',
        ) ||
        (existing.scopes.contains(microsoftCategoryScope) &&
            !candidate.scopes.contains(microsoftCategoryScope))) {
      throw const OAuthException(
        'MicrosoftOAuthSharedConsentDenied',
        'Shared-calendar access was not granted for this account.',
      );
    }
    if ((_credentialGenerations[accountId] ?? 0) != generation ||
        await _readTokenSet(accountId) == null) {
      throw const OAuthException(
        'MicrosoftOAuthSharedConsentCancelled',
        'The account was removed before shared-calendar consent completed.',
      );
    }
    await _tokenStore.saveOAuthTokenSet(
      accountId,
      BusyProvider.microsoft,
      candidate,
    );
  }

  Future<OAuthTokenSet> exchangeAuthorizationCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
    String fallbackScopeText = microsoftTodoOAuthScopes,
  }) async {
    final clientId = _config.microsoftOAuthClientId.trim();
    _validateTokenExchangeParameters(
      clientId: clientId,
      code: code,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
    );
    final tokenEndpoint = _tokenEndpoint;
    _logger.info(
      'Microsoft OAuth token exchange request: '
      'endpoint=${_endpointLabel(tokenEndpoint)} '
      'redirect_uri=$redirectUri '
      'grant_type=authorization_code '
      'has_code=${code.isNotEmpty} '
      'has_code_verifier=${codeVerifier.isNotEmpty} '
      'has_client_secret=false '
      'client_id_suffix=${_clientIdSuffix(clientId)}',
    );

    final response = await _httpClient.post(
      tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'code': code,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': codeVerifier,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OAuthException(
        'MicrosoftOAuthTokenExchangeFailed',
        _tokenEndpointFailureMessage('exchange', response),
      );
    }

    final json = jsonDecode(response.body) as Map<String, Object?>;
    return OAuthTokenSet.fromTokenEndpointJson(
      json,
      issuedAtUtc: _nowUtc(),
      fallbackScopeText: fallbackScopeText,
    );
  }

  Future<OAuthTokenSet> refreshTokenForAccount(String accountId) async {
    final generation = _credentialGenerations[accountId] ?? 0;
    final current = await _readTokenSet(accountId);
    if (current == null || !current.canRefresh) {
      throw const OAuthException(
        'MicrosoftOAuthMissingRefreshToken',
        'No Microsoft refresh token is available.',
      );
    }

    final refreshed = await refreshToken(current);
    if ((_credentialGenerations[accountId] ?? 0) != generation) {
      throw const OAuthException(
        'MicrosoftOAuthRefreshCancelled',
        'The account was removed while its credential was refreshing.',
      );
    }
    await _tokenStore.saveOAuthTokenSet(
      accountId,
      BusyProvider.microsoft,
      refreshed,
    );
    return refreshed;
  }

  Future<OAuthTokenSet> refreshToken(OAuthTokenSet current) async {
    final clientId = _config.microsoftOAuthClientId.trim();
    _validateTokenRefreshParameters(
      clientId: clientId,
      refreshToken: current.refreshToken,
    );
    final tokenEndpoint = _tokenEndpoint;
    _logger.info(
      'Microsoft OAuth token refresh request: '
      'endpoint=${_endpointLabel(tokenEndpoint)} '
      'grant_type=refresh_token '
      'has_refresh_token=${current.refreshToken?.isNotEmpty ?? false} '
      'has_client_secret=false '
      'client_id_suffix=${_clientIdSuffix(clientId)}',
    );

    final response = await _httpClient.post(
      tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': current.refreshToken!,
        'scope': [
          microsoftTodoOAuthScopes,
          if (current.scopes.contains(microsoftSharedCalendarScope))
            microsoftSharedCalendarScope,
          if (current.scopes.contains(microsoftCategoryScope))
            microsoftCategoryScope,
        ].join(' '),
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final details = _tokenEndpointFailureDetails(response.body);
      throw OAuthRefreshException(
        'MicrosoftOAuthRefreshFailed',
        _tokenEndpointFailureMessage('refresh', response, details: details),
        statusCode: response.statusCode,
        oauthError: details?.oauthError,
        oauthErrorDescription: details?.oauthErrorDescription,
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
  Future<void> signOutAccount(String accountId) async {
    _credentialGenerations[accountId] =
        (_credentialGenerations[accountId] ?? 0) + 1;
    await _tokenStore.deleteCredential(accountId);
    if (await _tokenStore.readActiveAccountId() == accountId) {
      await _tokenStore.clearActiveAccount();
    }
  }

  Future<OAuthTokenSet?> _readTokenSet(String accountId) async {
    await _tokenStore.migrateLegacyOAuthCredential(
      accountId,
      BusyProvider.microsoft,
    );
    return _tokenStore.readOAuthTokenSet(accountId, BusyProvider.microsoft);
  }

  Future<MicrosoftTodoUserDto> _getMe(OAuthTokenSet tokenSet) {
    final client = MicrosoftTodoRestApiClient(
      httpClient: _httpClient,
      baseUri: Uri.parse(_config.microsoftGraphBaseUrl),
      authorizationHeaderProvider: () async => 'Bearer ${tokenSet.accessToken}',
    );
    return client.getMe();
  }

  Uri get _authorizationEndpoint {
    return Uri.https(
      'login.microsoftonline.com',
      '/${_config.microsoftOAuthAuthorityTenant.trim()}/oauth2/v2.0/authorize',
    );
  }

  Uri get _tokenEndpoint {
    return Uri.https(
      'login.microsoftonline.com',
      '/${_config.microsoftOAuthAuthorityTenant.trim()}/oauth2/v2.0/token',
    );
  }
}

class MicrosoftOAuthSignInResult {
  const MicrosoftOAuthSignInResult({
    required this.accountId,
    required this.tokenSet,
    required this.user,
    this.tenantId,
  });

  final String accountId;
  final OAuthTokenSet tokenSet;
  final MicrosoftTodoUserDto user;
  final String? tenantId;
}

/// ID tokens are issued to this client; Graph access tokens are opaque and
/// must never be decoded to infer account capabilities.
String? microsoftTenantIdFromIdToken(String? idToken) {
  if (idToken == null) return null;
  final parts = idToken.split('.');
  if (parts.length != 3) return null;
  try {
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (decoded is! Map) return null;
    final tenantId = decoded['tid']?.toString().toLowerCase();
    return tenantId != null &&
            RegExp(
              r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
            ).hasMatch(tenantId)
        ? tenantId
        : null;
  } on Object {
    return null;
  }
}

void _validateTokenExchangeParameters({
  required String clientId,
  required String code,
  required String codeVerifier,
  required String redirectUri,
}) {
  if (clientId.trim().isEmpty) {
    throw const OAuthException(
      'MicrosoftOAuthMissingClientId',
      'Microsoft sign-in is not configured. Set MICROSOFT_OAUTH_CLIENT_ID.',
    );
  }
  if (code.trim().isEmpty) {
    throw const OAuthException(
      'MicrosoftOAuthTokenExchangeInvalidRequest',
      'Microsoft token exchange is missing an authorization code.',
    );
  }
  if (codeVerifier.trim().isEmpty) {
    throw const OAuthException(
      'MicrosoftOAuthTokenExchangeInvalidRequest',
      'Microsoft token exchange is missing the PKCE code verifier.',
    );
  }
  if (redirectUri.trim().isEmpty) {
    throw const OAuthException(
      'MicrosoftOAuthTokenExchangeInvalidRequest',
      'Microsoft token exchange is missing the redirect URI.',
    );
  }
  final parsed = Uri.tryParse(redirectUri);
  if (parsed == null || !_isAllowedLoopbackRedirectUri(parsed)) {
    throw const OAuthException(
      'MicrosoftOAuthTokenExchangeInvalidRequest',
      'Microsoft token exchange redirect URI must be loopback HTTP.',
    );
  }
}

void _validateTokenRefreshParameters({
  required String clientId,
  required String? refreshToken,
}) {
  if (clientId.trim().isEmpty) {
    throw const OAuthException(
      'MicrosoftOAuthMissingClientId',
      'Microsoft sign-in is not configured. Set MICROSOFT_OAUTH_CLIENT_ID.',
    );
  }
  if (refreshToken == null || refreshToken.trim().isEmpty) {
    throw const OAuthException(
      'MicrosoftOAuthMissingRefreshToken',
      'No Microsoft refresh token is available.',
    );
  }
}

bool _isAllowedLoopbackRedirectUri(Uri redirectUri) {
  return redirectUri.scheme == 'http' &&
      (redirectUri.host == 'localhost' || redirectUri.host == '127.0.0.1') &&
      redirectUri.hasPort &&
      redirectUri.port > 0 &&
      redirectUri.path == '/' &&
      !redirectUri.hasQuery &&
      redirectUri.fragment.isEmpty;
}

String _endpointLabel(Uri endpoint) {
  final port = endpoint.hasPort ? ':${endpoint.port}' : '';
  return '${endpoint.scheme}://${endpoint.host}$port${endpoint.path}';
}

String _clientIdSuffix(String clientId) {
  final trimmed = clientId.trim();
  if (trimmed.isEmpty) {
    return '<empty>';
  }
  final suffixLength = trimmed.length < 12 ? trimmed.length : 12;
  return '...${trimmed.substring(trimmed.length - suffixLength)}';
}

String _tokenEndpointFailureMessage(
  String operation,
  http.Response response, {
  _TokenEndpointFailureDetails? details,
}) {
  final safeDetails = details ?? _tokenEndpointFailureDetails(response.body);
  if (safeDetails == null || safeDetails.text.isEmpty) {
    return 'Microsoft token $operation failed with HTTP '
        '${response.statusCode}.';
  }
  return 'Microsoft token $operation failed: ${safeDetails.text}.';
}

_TokenEndpointFailureDetails? _tokenEndpointFailureDetails(String body) {
  final trimmedBody = body.trim();
  if (trimmedBody.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(trimmedBody);
    if (decoded is Map) {
      final json = decoded.cast<String, Object?>();
      final error = redactForLog(json['error']).trim();
      final description = redactForLog(json['error_description']).trim();
      if (error.isNotEmpty && description.isNotEmpty) {
        return _TokenEndpointFailureDetails(
          '$error - $description',
          oauthError: error,
          oauthErrorDescription: description,
        );
      }
      if (error.isNotEmpty) {
        return _TokenEndpointFailureDetails(error, oauthError: error);
      }
      if (description.isNotEmpty) {
        return _TokenEndpointFailureDetails(
          description,
          oauthErrorDescription: description,
        );
      }
    }
  } on FormatException {
    return _TokenEndpointFailureDetails(redactForLog(trimmedBody));
  }
  return _TokenEndpointFailureDetails(redactForLog(trimmedBody));
}

class _TokenEndpointFailureDetails {
  const _TokenEndpointFailureDetails(
    this.text, {
    this.oauthError,
    this.oauthErrorDescription,
  });

  final String text;
  final String? oauthError;
  final String? oauthErrorDescription;
}
