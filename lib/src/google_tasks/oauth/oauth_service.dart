import '../../core/http/bounded_http.dart';
import '../../core/http/retry_after.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../config/build_config.dart';
import '../../db/app_database.dart' show AccountsCompanion;
import '../../core/auth/oauth_registration.dart';
import '../../core/auth/registration_staging.dart';
import '../../core/auth/authorization_persistence.dart';
import '../../core/logging/redacting_logger.dart';
import '../../providers/busy_provider.dart';
import '../api/google_tasks_api_surface.dart';
import 'oauth_loopback_flow.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';

abstract interface class OAuthGateway {
  Future<String?> get activeAccountId;

  Future<OAuthTokenSet?> readActiveTokenSet();

  Future<GoogleUserInfo?> fetchUserInfo(OAuthTokenSet tokenSet);

  Future<OAuthSignInResult> signIn({String? loginHint});

  Future<OAuthTokenSet> refreshActiveToken();

  Future<void> revokeAndSignOutAccount(String accountId);

  Future<void> revokeAuthorization(String accountId);

  Future<void> clearLocalSession({String? accountId});

  Future<void> cancelSignIn();
}

abstract interface class GoogleConnectionGateway {
  Future<OAuthSignInResult> connectGoogle(AuthorizationRequest request);
}

class OAuthService
    implements
        OAuthGateway,
        GoogleConnectionGateway,
        RegistrationBindingResolver {
  OAuthService({
    required BuildConfig config,
    required http.Client httpClient,
    required SecretStore tokenStore,
    required OAuthLoopbackFlow loopbackFlow,
    DateTime Function()? nowUtc,
    RegistrationStaging? registrations,
    AuthorizationPersistence? persistence,
    Duration authorizationRevocationTimeout = const Duration(seconds: 10),
  }) : _registrations = registrations ?? RegistrationStaging(config),
       _persistence = persistence,
       _config = config,
       _httpClient = httpClient,
       _tokenStore = tokenStore,
       _loopbackFlow = loopbackFlow,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _authorizationRevocationTimeout = authorizationRevocationTimeout;

  final RegistrationStaging _registrations;
  final AuthorizationPersistence? _persistence;
  final Map<String, Future<OAuthTokenSet>> _refreshes = {};
  int _attemptGeneration = 0;
  Completer<void>? _authorizationAbort;
  final BuildConfig _config;
  final http.Client _httpClient;
  final SecretStore _tokenStore;
  final OAuthLoopbackFlow _loopbackFlow;
  final DateTime Function() _nowUtc;
  final Duration _authorizationRevocationTimeout;
  final RedactingLogger _logger = RedactingLogger(Logger('OAuthService'));
  final Map<String, int> _credentialGenerations = {};

  @override
  Future<String?> get activeAccountId => _tokenStore.readActiveAccountId();

  @override
  Future<OAuthTokenSet?> readActiveTokenSet() async {
    final accountId = await _tokenStore.readActiveAccountId();
    if (accountId == null) {
      return null;
    }
    return _readTokenSet(accountId);
  }

  Future<OAuthTokenSet?> readTokenSet(String accountId) {
    return _readTokenSet(accountId);
  }

  @override
  Future<GoogleUserInfo?> fetchUserInfo(
    OAuthTokenSet tokenSet, {
    Future<void>? cancellation,
  }) async {
    if (tokenSet.accessToken.trim().isEmpty) {
      return null;
    }
    final response = await boundedHttpRequest(
      _httpClient,
      'GET',
      Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
      cancellation: cancellation,
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
    final decoded = decodeOAuthProviderObject(response.body);
    return GoogleUserInfo.fromJson(decoded);
  }

  Future<OAuthTokenSet> validTokenForAccount(String accountId) async {
    final tokenSet = await _readTokenSet(accountId);
    if (tokenSet == null) {
      throw const OAuthException(
        'OAuthMissingToken',
        'No OAuth token is available for this account.',
      );
    }
    if (!tokenSet.canRefresh) {
      throw const OAuthException(
        'OAuthMissingRefreshToken',
        'No refresh token is available for this account.',
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
  Future<OAuthSignInResult> signIn({String? loginHint}) =>
      connectGoogle(const AuthorizationRequest.newConnection(null));

  @override
  Future<OAuthSignInResult> connectGoogle(AuthorizationRequest request) async {
    final persistence = _persistence;
    if (persistence == null) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'Account authorization storage is unavailable.',
      );
    }
    await persistence.recover();
    final attempt = ++_attemptGeneration;
    final candidateDeadline = _nowUtc().add(const Duration(minutes: 10));
    _authorizationAbort = Completer<void>();
    final target = request.accountId;
    final previous = target == null
        ? null
        : request.intent == AuthorizationIntent.reconnect
        ? await boundCredentialForAccount(target)
        : await _existingBoundCredential(target);
    final intendedSubject = target == null
        ? null
        : previous?.subject ?? await _existingSubject(target);
    var expected = target == null ? 0 : await persistence.generation(target);
    final registration = request.intent == AuthorizationIntent.reconnect
        ? previous!.registration
        : request.registration == null
        ? null
        : _registrations.consume(request.registration!);
    if (registration is! GoogleDesktopRegistration) {
      throw const OAuthException(
        'OAuthSetupRequired',
        'Set up your Google Cloud project and import its Desktop OAuth JSON.',
      );
    }
    if (registration.origin == RegistrationOrigin.retiringShared &&
        (request.intent != AuthorizationIntent.reconnect ||
            previous?.transitionEligible != true ||
            !await persistence.wasPreexisting(target!))) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'This is the retiring shared client. Select a Desktop client from your own Google Cloud project.',
      );
    }
    final result = await _loopbackFlow.start(
      authorizationEndpoint: Uri.https(
        'accounts.google.com',
        '/o/oauth2/v2/auth',
      ),
      clientId: registration.clientId,
      scope: googleBusyMaxOAuthScope,
      extraAuthorizationParameters: const {
        'access_type': 'offline',
        'prompt': 'consent',
      },
      loginHint: previous?.subject,
    );
    final tokens = await exchangeAuthorizationCode(
      code: result.callback.code,
      codeVerifier: result.codeVerifier,
      redirectUri: result.redirectUri,
      fallbackScopeText: result.callback.scope,
      registration: registration,
      cancellation: _authorizationAbort!.future,
    );
    if (!tokens.scopes.contains(googleTasksReadWriteScope) ||
        !tokens.scopes.contains(googleCalendarReadWriteScope)) {
      throw const OAuthException(
        'OAuthMissingRequiredScope',
        'Grant both Google Tasks and Google Calendar permissions.',
      );
    }
    final user = await fetchUserInfo(
      tokens,
      cancellation: _authorizationAbort!.future,
    );
    final subject = user?.subject;
    if (subject == null || subject.isEmpty) {
      throw const OAuthException(
        'OAuthIdentityUnavailable',
        'Google account identity could not be verified. Try again.',
      );
    }
    if (target != null && intendedSubject != subject) {
      throw const OAuthException(
        'OAuthWrongAccount',
        'Authorize the account selected for reconnection.',
      );
    }
    if (attempt != _attemptGeneration ||
        !_nowUtc().isBefore(candidateDeadline)) {
      throw const OAuthException(
        'OAuthSignInCancelled',
        'Google sign-in was cancelled.',
      );
    }
    final id = target ?? 'google:$subject';
    if (target == null) {
      expected = await persistence.generation(id);
      final matches =
          await (persistence.database.select(persistence.database.accounts)
                ..where(
                  (r) =>
                      r.provider.equals('google') &
                      r.providerAccountId.equals(subject),
                ))
              .get();
      if (matches.isNotEmpty ||
          await (_persistence?.readCurrentCredential(id) ??
                  _tokenStore.readCredential(id)) !=
              null) {
        throw const OAuthException(
          'OAuthAccountAlreadyConnected',
          'This account already exists. Use its Reconnect or Migrate action.',
        );
      }
    }
    final candidate = GoogleDesktopCredential(
      registration: registration,
      tokenSet: tokens,
      subject: subject,
      generation: expected + 1,
      transitionEligible:
          request.intent == AuthorizationIntent.reconnect &&
          previous!.transitionEligible,
    );
    return OAuthSignInResult(
      accountId: id,
      tokenSet: tokens,
      user: user,
      commit: (persistAccount) async {
        if (attempt != _attemptGeneration ||
            !_nowUtc().isBefore(candidateDeadline)) {
          throw const OAuthException(
            'OAuthSignInCancelled',
            'Google sign-in was cancelled.',
          );
        }
        await persistence.commit(
          accountId: id,
          expectedGeneration: expected,
          candidate: candidate,
          validateCandidate: () {
            if (attempt != _attemptGeneration ||
                !_nowUtc().isBefore(candidateDeadline)) {
              throw const OAuthException(
                'OAuthSignInCancelled',
                'Authorization was cancelled.',
              );
            }
          },
          requireExisting: target != null,
          persistAccount: persistAccount,
        );
      },
    );
  }

  Future<GoogleDesktopCredential?> _existingBoundCredential(String id) async {
    final record =
        await (_persistence?.readCurrentCredential(id) ??
            _tokenStore.readCredential(id));
    return record is GoogleDesktopCredential ? record : null;
  }

  Future<String> _existingSubject(String id) async {
    final account = await (_persistence!.database.select(
      _persistence.database.accounts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (account == null || account.provider != 'google') {
      throw const OAuthException(
        'OAuthStaleAuthorization',
        'The selected account is unavailable.',
      );
    }
    // A previously verified provider subject is independent of its local key.
    if (account.providerAccountId.isNotEmpty &&
        account.providerAccountId != id) {
      return account.providerAccountId;
    }
    final record = await _persistence.readCurrentCredential(id);
    if (record is OAuthSecretRecord && record.provider == BusyProvider.google) {
      final user = await fetchUserInfo(
        record.tokenSet,
        cancellation: _authorizationAbort!.future,
      );
      if (user?.subject case final subject? when subject.isNotEmpty) {
        return subject;
      }
    }
    throw const OAuthException(
      'OAuthRegistrationUnresolved',
      'This account lacks a verified Google identity. Its data and credentials are preserved; restore its original configuration before reconnecting.',
    );
  }

  @override
  Future<void> establishExistingBinding(
    String id,
    BusyProvider provider,
  ) async {
    if (provider == BusyProvider.google) await boundCredentialForAccount(id);
  }

  /// Legacy desktop records are bound only after a successful refresh against
  /// the protected original client, followed by provider identity validation.
  Future<GoogleDesktopCredential> boundCredentialForAccount(String id) async {
    await _tokenStore.migrateLegacyOAuthCredential(id, BusyProvider.google);
    final record =
        await (_persistence?.readCurrentCredential(id) ??
            _tokenStore.readCredential(id));
    if (record is GoogleDesktopCredential) {
      if (record.registration.origin == RegistrationOrigin.retiringShared) {
        _registrations.rememberRetiringClient(record.registration.clientId);
      }
      return record;
    }
    final persistence = _persistence;
    if (record is! OAuthSecretRecord ||
        record.provider != BusyProvider.google ||
        persistence == null ||
        !await persistence.wasPreexisting(id) ||
        _config.googleOAuthClientId.trim().isEmpty) {
      throw const OAuthException(
        'OAuthRegistrationUnresolved',
        'The original Google registration is unavailable or unidentified. Account data is preserved; configure this account explicitly.',
      );
    }
    final expected = await persistence.generation(id);
    final registration = GoogleDesktopRegistration(
      clientId: _config.googleOAuthClientId.trim(),
      clientSecret: _config.googleOAuthClientSecret.trim().isEmpty
          ? null
          : _config.googleOAuthClientSecret.trim(),
      projectId: 'original-shipped-project',
      origin: RegistrationOrigin.retiringShared,
    );
    await persistence.checkTokenCooldown(id, registration.clientId, _nowUtc());
    final OAuthTokenSet tokens;
    try {
      tokens = await refreshToken(record.tokenSet, registration: registration);
    } on OAuthRefreshException catch (failure) {
      if (failure.statusCode == 400 || failure.statusCode == 401) {
        throw const OAuthException(
          'OAuthRegistrationUnresolved',
          'The original Google registration could not be established. Account data and credentials are preserved; configure this account explicitly.',
        );
      }
      await persistence.recordTokenRequestCooldown(
        id,
        expected,
        registration.clientId,
        failure,
        _nowUtc(),
      );
      rethrow;
    }
    final user = await fetchUserInfo(tokens);
    final account = await (persistence.database.select(
      persistence.database.accounts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (user?.subject == null ||
        account == null ||
        (account.providerAccountId != id &&
            account.providerAccountId != user!.subject)) {
      throw const OAuthException(
        'OAuthRegistrationUnresolved',
        'The original Google account identity could not be established. Account data is preserved.',
      );
    }
    final bound = GoogleDesktopCredential(
      registration: registration,
      tokenSet: tokens,
      subject: user!.subject!,
      generation: expected,
      transitionEligible: true,
    );
    await persistence.commit(
      accountId: id,
      expectedGeneration: expected,
      candidate: bound,
      requireExisting: true,
      persistAccount: () async {
        // An old token-derived local key remains unchanged. Record the
        // independently verified subject so future onboarding recognizes it.
        await (persistence.database.update(persistence.database.accounts)
              ..where((row) => row.id.equals(id)))
            .write(AccountsCompanion(providerAccountId: Value(bound.subject)));
      },
    );
    return bound;
  }

  @override
  Future<void> cancelSignIn() async {
    _attemptGeneration++;
    if (_authorizationAbort case final abort? when !abort.isCompleted) {
      abort.complete();
    }
    _registrations.cancel();
    await _loopbackFlow.cancel();
  }

  Future<OAuthTokenSet> exchangeAuthorizationCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
    String? fallbackScopeText,
    GoogleDesktopRegistration? registration,
    Future<void>? cancellation,
  }) async {
    final clientId =
        registration?.clientId ?? _config.googleOAuthClientId.trim();
    final clientSecret = registration == null
        ? _config.googleOAuthClientSecret.trim()
        : registration.clientSecret ?? '';
    _validateTokenExchangeParameters(
      clientId: clientId,
      code: code,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
    );
    final tokenEndpoint = Uri.https('oauth2.googleapis.com', '/token');
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

    final response = await boundedHttpRequest(
      _httpClient,
      'POST',
      tokenEndpoint,
      cancellation: cancellation,
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

    final json = decodeOAuthProviderObject(response.body);
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
      throw const OAuthException('OAuthMissingToken', 'No active account.');
    }

    return refreshTokenForAccount(accountId);
  }

  Future<OAuthTokenSet> refreshTokenForAccount(String accountId) {
    final running = _refreshes[accountId];
    if (running != null) return running;
    final operation = _refreshBound(accountId);
    _refreshes[accountId] = operation;
    unawaited(
      operation.then<void>(
        (_) => _refreshes.remove(accountId),
        onError: (Object _, StackTrace _) {
          _refreshes.remove(accountId);
        },
      ),
    );
    return operation;
  }

  Future<OAuthTokenSet> _refreshBound(String id) async {
    final current = await boundCredentialForAccount(id);
    await _persistence!.checkTokenCooldown(
      id,
      current.registration.clientId,
      _nowUtc(),
    );
    late final OAuthTokenSet refreshed;
    try {
      refreshed = await refreshToken(
        current.tokenSet,
        registration: current.registration,
      );
    } on OAuthRefreshException catch (error) {
      await _persistence.recordTokenCooldown(id, current, error, _nowUtc());
      rethrow;
    }
    await _persistence.writeRefresh(
      id,
      current.generation,
      current.withTokens(refreshed),
      expectedRefreshToken: current.tokenSet.refreshToken,
    );
    return refreshed;
  }

  Future<OAuthTokenSet> refreshToken(
    OAuthTokenSet current, {
    GoogleDesktopRegistration? registration,
  }) async {
    final clientId =
        registration?.clientId ?? _config.googleOAuthClientId.trim();
    final clientSecret = registration == null
        ? _config.googleOAuthClientSecret.trim()
        : registration.clientSecret ?? '';
    _validateTokenRefreshParameters(
      clientId: clientId,
      refreshToken: current.refreshToken,
    );
    final tokenEndpoint = Uri.https('oauth2.googleapis.com', '/token');
    _logger.info(
      'OAuth token refresh request: '
      'endpoint=${_tokenEndpointLabel(tokenEndpoint)} '
      'grant_type=refresh_token '
      'has_refresh_token=${current.refreshToken?.isNotEmpty ?? false} '
      'has_client_secret=${clientSecret.isNotEmpty} '
      'client_id_suffix=${_clientIdSuffix(clientId)}',
    );

    final response = await boundedHttpRequest(
      _httpClient,
      'POST',
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
      final details = _tokenEndpointFailureDetails(response.body);
      throw OAuthRefreshException(
        'OAuthRefreshFailed',
        _tokenEndpointFailureMessage(
          operation: 'refresh',
          response: response,
          details: details,
        ),
        statusCode: response.statusCode,
        oauthError: response.statusCode == 400 || response.statusCode == 401
            ? details?.oauthError
            : null,
        oauthErrorDescription: null,
        retryAfter: parseHttpRetryAfter(
          response.headers['retry-after'],
          now: _nowUtc(),
        ),
      );
    }

    final json = decodeOAuthProviderObject(response.body);
    return OAuthTokenSet.fromTokenEndpointJson(
      json,
      issuedAtUtc: _nowUtc(),
      existingRefreshToken: current.refreshToken,
      existingIdToken: current.idToken,
      existingScopes: current.scopes,
    );
  }

  @override
  Future<void> revokeAndSignOutAccount(String accountId) async {
    try {
      await revokeAuthorization(accountId);
    } finally {
      await clearLocalSession(accountId: accountId);
    }
  }

  @override
  Future<void> revokeAuthorization(String accountId) async {
    final tokenSet = await _readTokenSet(accountId);
    final token = tokenSet?.refreshToken ?? tokenSet?.accessToken;
    if (token == null || token.isEmpty) {
      throw const OAuthException(
        'OAuthRevocationUnavailable',
        'No local Google authorization is available to revoke.',
      );
    }

    late final http.Response response;
    try {
      response = await boundedHttpRequest(
        _httpClient,
        'POST',
        Uri.https('oauth2.googleapis.com', '/revoke'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'token': token},
        timeout: _authorizationRevocationTimeout,
      );
    } on OAuthException catch (error) {
      if (error.classification != OAuthFailureKind.timeout) rethrow;
      throw const OAuthException(
        'OAuthRevocationTimedOut',
        'Google authorization revocation timed out.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OAuthException(
        'OAuthRevocationFailed',
        'Google authorization revocation failed '
            '(HTTP ${response.statusCode}).',
      );
    }
  }

  @override
  Future<void> clearLocalSession({String? accountId}) async {
    final targetAccountId =
        accountId ?? await _tokenStore.readActiveAccountId();
    if (targetAccountId != null) {
      _invalidateCredentialWrites(targetAccountId);
      await _tokenStore.deleteCredential(targetAccountId);
    }
    if (targetAccountId == null ||
        await _tokenStore.readActiveAccountId() == targetAccountId) {
      await _tokenStore.clearActiveAccount();
    }
  }

  void _invalidateCredentialWrites(String accountId) {
    _credentialGenerations[accountId] =
        (_credentialGenerations[accountId] ?? 0) + 1;
  }

  Future<OAuthTokenSet?> _readTokenSet(String accountId) async {
    await _tokenStore.migrateLegacyOAuthCredential(
      accountId,
      BusyProvider.google,
    );
    if (_persistence != null) {
      return (await boundCredentialForAccount(accountId)).tokenSet;
    }
    return _tokenStore.readOAuthTokenSet(accountId, BusyProvider.google);
  }
}

class OAuthSignInResult {
  const OAuthSignInResult({
    required this.accountId,
    required this.tokenSet,
    this.user,
    this.commit,
  });

  final GoogleUserInfo? user;
  final AuthorizationCommit? commit;

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
  final text = value is String ? value.trim() : null;
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
      'OAuthMissingRefreshToken',
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
  _TokenEndpointFailureDetails? details,
}) {
  return 'Google token $operation failed (HTTP ${response.statusCode}). Check the registration or try again after a temporary outage.';
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
        return _TokenEndpointFailureDetails(
          '$error - $description',
          isJson: true,
          oauthError: error,
          oauthErrorDescription: description,
        );
      }
      if (error.isNotEmpty) {
        return _TokenEndpointFailureDetails(
          error,
          isJson: true,
          oauthError: error,
        );
      }
      if (description.isNotEmpty) {
        return _TokenEndpointFailureDetails(
          description,
          isJson: true,
          oauthErrorDescription: description,
        );
      }
    }
  } on FormatException {
    return _TokenEndpointFailureDetails(
      redactForLog(trimmedBody),
      isJson: false,
    );
  }

  return _TokenEndpointFailureDetails(redactForLog(trimmedBody), isJson: false);
}

class _TokenEndpointFailureDetails {
  const _TokenEndpointFailureDetails(
    this.text, {
    required this.isJson,
    this.oauthError,
    this.oauthErrorDescription,
  });

  final String text;
  final bool isJson;
  final String? oauthError;
  final String? oauthErrorDescription;
}
