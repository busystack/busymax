import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../config/build_config.dart';
import '../../core/logging/redacting_logger.dart';
import '../../google_tasks/oauth/oauth_loopback_flow.dart';
import '../../google_tasks/oauth/oauth_models.dart';
import '../../google_tasks/oauth/oauth_token_store.dart';
import '../api/microsoft_todo_api_client.dart';
import '../api/microsoft_todo_api_models.dart';

const microsoftTodoOAuthScopes =
    'openid profile email offline_access '
    'https://graph.microsoft.com/User.Read '
    'https://graph.microsoft.com/Tasks.ReadWrite '
    'https://graph.microsoft.com/Calendars.ReadWrite';

const microsoftSignInCallbackNotReceivedMessage =
    'Microsoft sign-in callback was not received by BusyMax. Try signing in '
    'again. If the browser opened an old tab, close it and start sign-in '
    'again.';

class MicrosoftOAuthService {
  MicrosoftOAuthService({
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
  final RedactingLogger _logger = RedactingLogger(
    Logger('MicrosoftOAuthService'),
  );

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
    await _tokenStore.saveTokenSet(accountId, tokenSet);
    await _tokenStore.setActiveAccountId(accountId);
    return MicrosoftOAuthSignInResult(
      accountId: accountId,
      tokenSet: tokenSet,
      user: user,
    );
  }

  Future<void> cancelSignIn() => _loopbackFlow.cancel();

  Future<OAuthTokenSet?> readTokenSet(String accountId) {
    return _tokenStore.readTokenSet(accountId);
  }

  Future<OAuthTokenSet> validTokenForAccount(String accountId) async {
    final tokenSet = await _tokenStore.readTokenSet(accountId);
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

  Future<OAuthTokenSet> exchangeAuthorizationCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
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
      fallbackScopeText: microsoftTodoOAuthScopes,
    );
  }

  Future<OAuthTokenSet> refreshTokenForAccount(String accountId) async {
    final current = await _tokenStore.readTokenSet(accountId);
    if (current == null || !current.canRefresh) {
      throw const OAuthException(
        'MicrosoftOAuthRefreshFailed',
        'No Microsoft refresh token is available.',
      );
    }

    final refreshed = await refreshToken(current);
    await _tokenStore.saveTokenSet(accountId, refreshed);
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
        'scope': microsoftTodoOAuthScopes,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OAuthException(
        'MicrosoftOAuthRefreshFailed',
        _tokenEndpointFailureMessage('refresh', response),
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

  Future<void> signOutAccount(String accountId) async {
    await _tokenStore.clearTokenSet(accountId);
    if (await _tokenStore.readActiveAccountId() == accountId) {
      await _tokenStore.clearActiveAccount();
    }
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
  });

  final String accountId;
  final OAuthTokenSet tokenSet;
  final MicrosoftTodoUserDto user;
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
      'MicrosoftOAuthRefreshFailed',
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

String _tokenEndpointFailureMessage(String operation, http.Response response) {
  final details = _tokenEndpointFailureDetails(response.body);
  if (details == null || details.isEmpty) {
    return 'Microsoft token $operation failed with HTTP '
        '${response.statusCode}.';
  }
  return 'Microsoft token $operation failed: $details.';
}

String? _tokenEndpointFailureDetails(String body) {
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
        return '$error - $description';
      }
      if (error.isNotEmpty) {
        return error;
      }
      if (description.isNotEmpty) {
        return description;
      }
    }
  } on FormatException {
    return redactForLog(trimmedBody);
  }
  return redactForLog(trimmedBody);
}
