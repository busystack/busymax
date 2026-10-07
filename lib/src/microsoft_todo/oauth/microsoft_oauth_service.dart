import '../../core/auth/authorization_attempt.dart';
import '../../core/http/request_dispatch_exception.dart';
import '../../core/http/bounded_http.dart';
import '../../core/http/retry_after.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../config/build_config.dart';
import '../../core/auth/oauth_registration.dart';
import '../../core/auth/registration_staging.dart';
import '../../core/auth/authorization_persistence.dart';
import '../../core/logging/redacting_logger.dart';
import '../../core/auth/microsoft_graph_scopes.dart';
import '../../google_tasks/oauth/oauth_loopback_flow.dart';
import '../../providers/busy_provider.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
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
  Future<void> authorizeCategoryAccess(
    String accountId, {
    AuthorizationCancellation? cancellation,
  });
}

abstract interface class MicrosoftSharedCalendarAuthorization {
  Future<void> authorizeSharedCalendarAccess(
    String accountId, {
    AuthorizationCancellation? cancellation,
  });
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

abstract interface class MicrosoftConnectionGateway {
  Future<MicrosoftOAuthSignInResult> connectMicrosoft(
    AuthorizationRequest request,
  );
}

class MicrosoftOAuthService
    implements
        MicrosoftOAuthGateway,
        MicrosoftConnectionGateway,
        RegistrationBindingResolver,
        MicrosoftSharedCalendarAuthorization,
        MicrosoftCategoryAuthorization {
  MicrosoftOAuthService({
    required BuildConfig config,
    required http.Client httpClient,
    required SecretStore tokenStore,
    required OAuthLoopbackFlow loopbackFlow,
    DateTime Function()? nowUtc,
    RegistrationStaging? registrations,
    AuthorizationPersistence? persistence,
  }) : _registrations = registrations ?? RegistrationStaging(config),
       _persistence = persistence,
       _config = config,
       _httpClient = httpClient,
       _tokenStore = tokenStore,
       _loopbackFlow = loopbackFlow,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final RegistrationStaging _registrations;
  final AuthorizationPersistence? _persistence;
  final Map<String, Future<OAuthTokenSet>> _refreshes = {};
  final AuthorizationAttemptOwner _attempts = AuthorizationAttemptOwner();
  final BuildConfig _config;
  final http.Client _httpClient;
  final SecretStore _tokenStore;
  final OAuthLoopbackFlow _loopbackFlow;
  final DateTime Function() _nowUtc;
  final RedactingLogger _logger = RedactingLogger(
    Logger('MicrosoftOAuthService'),
  );
  final Map<String, int> _credentialGenerations = {};

  Future<MicrosoftOAuthSignInResult> signIn() =>
      connectMicrosoft(const AuthorizationRequest.newConnection(null));
  @override
  Future<MicrosoftOAuthSignInResult> signInWithMicrosoft() => signIn();
  @override
  Future<MicrosoftOAuthSignInResult> connectMicrosoft(
    AuthorizationRequest request,
  ) => _connect(request);

  Future<MicrosoftOAuthSignInResult> _connect(
    AuthorizationRequest request, {
    Set<String> optionalScopes = const {},
    AuthorizationAttempt? capturedAttempt,
  }) {
    final attempt =
        capturedAttempt ?? _attempts.begin(_nowUtc, request.cancellation);
    return _connectPrepared(request, attempt, optionalScopes).catchError((
      Object error,
      StackTrace stack,
    ) {
      attempt.cancel();
      _attempts.finish(attempt);
      if (request.registration case final handle?) {
        _registrations.discard(handle.id);
      }
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<MicrosoftOAuthSignInResult> _connectPrepared(
    AuthorizationRequest request,
    AuthorizationAttempt attempt,
    Set<String> optionalScopes,
  ) async {
    final persistence = _persistence;
    if (persistence == null) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'Account authorization storage is unavailable.',
      );
    }
    attempt.check();
    await attempt.wait(persistence.recover());
    final target = request.accountId;
    final previous = target == null
        ? null
        : request.intent == AuthorizationIntent.reconnect
        ? await attempt.wait(boundCredentialForAccount(target))
        : await attempt.wait(_existingBoundCredential(target));
    final intendedIdentity = target == null
        ? null
        : previous == null
        ? await attempt.wait(_existingIdentity(target))
        : (previous.subject, previous.tenantId);
    var expected = target == null
        ? 0
        : await attempt.wait(persistence.generation(target));
    attempt.check();
    final registration = request.intent == AuthorizationIntent.reconnect
        ? previous!.registration
        : request.registration == null
        ? null
        : _registrations.consume(request.registration!);
    if (registration is! MicrosoftPublicRegistration ||
        registration.platform != AuthenticationPlatform.desktop) {
      throw const OAuthException(
        'OAuthSetupRequired',
        'Set up a Microsoft public app registration with an Application/client ID and account audience.',
      );
    }
    if (registration.origin == RegistrationOrigin.retiringShared &&
        (request.intent != AuthorizationIntent.reconnect ||
            previous?.transitionEligible != true ||
            !await persistence.wasPreexisting(target!))) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'This is the retiring shared client. Use your own Microsoft app registration.',
      );
    }
    final scopes = [
      microsoftTodoOAuthScopes,
      ...optionalScopes,
      if (previous != null &&
          hasMicrosoftGraphScope(
            previous.tokenSet.scopes,
            microsoftSharedCalendarScope,
          ))
        microsoftSharedCalendarScope,
      if (previous != null &&
          hasMicrosoftGraphScope(
            previous.tokenSet.scopes,
            microsoftCategoryScope,
          ))
        microsoftCategoryScope,
    ].join(' ');
    attempt.check();
    final result = await _loopbackFlow.start(
      attempt: attempt,
      authorizationEndpoint: registration.endpoint('authorize'),
      clientId: registration.clientId,
      scope: scopes,
      redirectHost: 'localhost',
      signInCancelledMessage: 'Microsoft sign-in was cancelled.',
      callbackNotReceivedMessage: microsoftSignInCallbackNotReceivedMessage,
      extraAuthorizationParameters: const {
        'response_mode': 'query',
        'prompt': 'consent',
      },
    );
    attempt.check();
    final tokens = await exchangeAuthorizationCode(
      code: result.callback.code,
      codeVerifier: result.codeVerifier,
      redirectUri: result.redirectUri,
      fallbackScopeText: '',
      registration: registration,
      cancellation: attempt.cancellation,
    );
    if (!hasMicrosoftGraphScopes(tokens.scopes, {
      'User.Read',
      'Tasks.ReadWrite',
      'Calendars.ReadWrite',
      ...optionalScopes,
    })) {
      throw const OAuthException(
        'MicrosoftOAuthMissingRequiredScope',
        'Grant Microsoft Tasks and Calendar permissions.',
      );
    }
    attempt.check();
    final user = await _getMe(tokens, cancellation: attempt.cancellation);
    final tenant = microsoftTenantIdFromIdToken(
      tokens.idToken,
      clientId: registration.clientId,
    );
    if (user.id.isEmpty || tenant == null) {
      throw const OAuthException(
        'OAuthIdentityUnavailable',
        'Microsoft account and tenant identity could not be verified.',
      );
    }
    if (intendedIdentity != null &&
        (intendedIdentity.$1 != user.id || intendedIdentity.$2 != tenant)) {
      throw const OAuthException(
        'OAuthWrongAccount',
        'Authorize the selected Microsoft account in the same tenant.',
      );
    }
    attempt.check();
    final id = target ?? 'microsoft:${user.id}';
    if (target == null) {
      expected = await persistence.generation(id);
      final matches =
          await (persistence.database.select(persistence.database.accounts)
                ..where(
                  (r) =>
                      r.provider.equals('microsoft') &
                      r.providerAccountId.equals(user.id),
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
    final candidate = MicrosoftDesktopCredential(
      registration: registration,
      tokenSet: tokens,
      subject: user.id,
      tenantId: tenant,
      generation: expected + 1,
      transitionEligible:
          request.intent == AuthorizationIntent.reconnect &&
          previous!.transitionEligible,
    );
    return MicrosoftOAuthSignInResult(
      accountId: id,
      tokenSet: tokens,
      user: user,
      tenantId: tenant,
      commit: (persistAccount) async {
        try {
          attempt.check();
          await persistence.commit(
            accountId: id,
            expectedGeneration: expected,
            candidate: candidate,
            onCommitted: attempt.committed,
            validateCandidate: () {
              attempt.check();
            },
            requireExisting: target != null,
            persistAccount: persistAccount,
          );
          attempt.committed();
        } finally {
          _attempts.finish(attempt);
        }
      },
    );
  }

  Future<MicrosoftDesktopCredential?> _existingBoundCredential(
    String id,
  ) async {
    final record =
        await (_persistence?.readCurrentCredential(id) ??
            _tokenStore.readCredential(id));
    return record is MicrosoftDesktopCredential ? record : null;
  }

  Future<(String, String)> _existingIdentity(String id) async {
    final account = await (_persistence!.database.select(
      _persistence.database.accounts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (account == null || account.provider != 'microsoft') {
      throw const OAuthException(
        'OAuthStaleAuthorization',
        'The selected account is unavailable.',
      );
    }
    final record = await _persistence.readCurrentCredential(id);
    final tenant =
        account.tenantId ??
        (record is OAuthSecretRecord
            ? microsoftTenantIdFromIdToken(record.tokenSet.idToken)
            : null);
    if (account.providerAccountId.isNotEmpty && tenant != null) {
      return (account.providerAccountId, tenant);
    }
    throw const OAuthException(
      'OAuthRegistrationUnresolved',
      'This account lacks verified Microsoft tenant identity. Data and credentials are preserved; restore its original configuration before reconnecting.',
    );
  }

  @override
  Future<void> establishExistingBinding(
    String id,
    BusyProvider provider,
  ) async {
    if (provider == BusyProvider.microsoft) await boundCredentialForAccount(id);
  }

  Future<MicrosoftDesktopCredential> boundCredentialForAccount(
    String id,
  ) async {
    await _tokenStore.migrateLegacyOAuthCredential(id, BusyProvider.microsoft);
    final record =
        await (_persistence?.readCurrentCredential(id) ??
            _tokenStore.readCredential(id));
    if (record is MicrosoftDesktopCredential) {
      if (record.registration.origin == RegistrationOrigin.retiringShared) {
        _registrations.rememberRetiringClient(record.registration.clientId);
      }
      return record;
    }
    final persistence = _persistence;
    if (record is! OAuthSecretRecord ||
        record.provider != BusyProvider.microsoft ||
        persistence == null ||
        !await persistence.wasPreexisting(id) ||
        _config.microsoftOAuthClientId.trim().isEmpty) {
      throw const OAuthException(
        'OAuthRegistrationUnresolved',
        'The original Microsoft registration is unavailable or unidentified. Account data is preserved; configure this account explicitly.',
      );
    }
    final expected = await persistence.generation(id);
    final registration = _originalRegistration;
    await persistence.checkTokenCooldown(id, registration.clientId, _nowUtc());
    final OAuthTokenSet tokens;
    try {
      tokens = await refreshToken(record.tokenSet, registration: registration);
    } on OAuthRefreshException catch (failure) {
      if (failure.statusCode == 400 || failure.statusCode == 401) {
        throw const OAuthException(
          'OAuthRegistrationUnresolved',
          'The original Microsoft registration could not be established. Account data and credentials are preserved; configure this account explicitly.',
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
    final user = await _getMe(tokens);
    final tenant = microsoftTenantIdFromIdToken(
      tokens.idToken,
      clientId: registration.clientId,
    );
    final account = await (persistence.database.select(
      persistence.database.accounts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (user.id.isEmpty ||
        tenant == null ||
        account == null ||
        account.providerAccountId != user.id ||
        (account.tenantId != null && account.tenantId != tenant)) {
      throw const OAuthException(
        'OAuthRegistrationUnresolved',
        'The original Microsoft identity could not be established. Account data is preserved.',
      );
    }
    final bound = MicrosoftDesktopCredential(
      registration: registration,
      tokenSet: tokens,
      subject: user.id,
      tenantId: tenant,
      generation: expected,
      transitionEligible: true,
    );
    await persistence.commit(
      accountId: id,
      expectedGeneration: expected,
      candidate: bound,
      requireExisting: true,
      persistAccount: () async {},
    );
    return bound;
  }

  @override
  Future<void> cancelSignIn() async {
    final attempt = _attempts.current;
    if (attempt == null) return;
    attempt.cancel();
    await _loopbackFlow.cancelFor(attempt);
  }

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
    if (!hasMicrosoftGraphScope(
      tokenSet.scopes,
      microsoftSharedCalendarScope,
    )) {
      throw const OAuthException(
        'MicrosoftOAuthSharedConsentRequired',
        'Shared-calendar permission must be granted for this account.',
      );
    }
    return 'Bearer ${tokenSet.accessToken}';
  }

  Future<String> categoryAuthorizationHeaderForAccount(String accountId) async {
    final tokenSet = await validTokenForAccount(accountId);
    if (!hasMicrosoftGraphScope(tokenSet.scopes, microsoftCategoryScope)) {
      throw const OAuthException(
        'MicrosoftOAuthCategoryConsentRequired',
        'Outlook category lookup requires optional mailbox-settings consent.',
      );
    }
    return 'Bearer ${tokenSet.accessToken}';
  }

  @override
  Future<void> authorizeCategoryAccess(
    String accountId, {
    AuthorizationCancellation? cancellation,
  }) => _optionalConsent(accountId, microsoftCategoryScope, cancellation);
  @override
  Future<void> authorizeSharedCalendarAccess(
    String accountId, {
    AuthorizationCancellation? cancellation,
  }) => _optionalConsent(accountId, microsoftSharedCalendarScope, cancellation);
  Future<void> _optionalConsent(
    String id,
    String scope,
    AuthorizationCancellation? cancellation,
  ) async {
    final attempt = _attempts.begin(_nowUtc, cancellation);
    MicrosoftDesktopCredential? current;
    try {
      final active = await attempt.wait(boundCredentialForAccount(id));
      current = active;
      if (hasMicrosoftGraphScope(active.tokenSet.scopes, scope)) {
        attempt.committed();
        return;
      }
      final result = await _connect(
        AuthorizationRequest.reconnect(id),
        optionalScopes: {scope},
        capturedAttempt: attempt,
      );
      await result.commit!(() async {});
    } on OAuthException catch (error) {
      if (current == null) rethrow;
      throw AuthorizationScopedOAuthException(
        accountId: id,
        generation: current.generation,
        cause: error,
      );
    } finally {
      _attempts.finish(attempt);
    }
  }

  Future<OAuthTokenSet> exchangeAuthorizationCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
    String fallbackScopeText = microsoftTodoOAuthScopes,
    String? existingRefreshToken,
    String? existingIdToken,
    MicrosoftPublicRegistration? registration,
    Future<void>? cancellation,
  }) async {
    final clientId =
        registration?.clientId ?? _config.microsoftOAuthClientId.trim();
    _validateTokenExchangeParameters(
      clientId: clientId,
      code: code,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
    );
    final tokenEndpoint = (registration ?? _originalRegistration).endpoint(
      'token',
    );
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

    final response = await boundedHttpRequest(
      _httpClient,
      'POST',
      tokenEndpoint,
      cancellation: cancellation,
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
      throw codeExchangeFailure(
        'MicrosoftOAuthTokenExchangeFailed',
        response.body,
        response.statusCode,
        parseHttpRetryAfter(response.headers['retry-after'], now: _nowUtc()),
      );
    }

    final json = decodeOAuthProviderObject(response.body);
    return OAuthTokenSet.fromTokenEndpointJson(
      json,
      issuedAtUtc: _nowUtc(),
      fallbackScopeText: fallbackScopeText,
      existingRefreshToken: existingRefreshToken,
      existingIdToken: existingIdToken,
    );
  }

  Future<OAuthTokenSet> refreshTokenForAccount(String id) {
    final running = _refreshes[id];
    if (running != null) return running;
    final operation = _refreshBound(id);
    _refreshes[id] = operation;
    unawaited(
      operation.then<void>(
        (_) => _refreshes.remove(id),
        onError: (Object _, StackTrace _) {
          _refreshes.remove(id);
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
    MicrosoftPublicRegistration? registration,
  }) async {
    final clientId =
        registration?.clientId ?? _config.microsoftOAuthClientId.trim();
    _validateTokenRefreshParameters(
      clientId: clientId,
      refreshToken: current.refreshToken,
    );
    final tokenEndpoint = (registration ?? _originalRegistration).endpoint(
      'token',
    );
    _logger.info(
      'Microsoft OAuth token refresh request: '
      'endpoint=${_endpointLabel(tokenEndpoint)} '
      'grant_type=refresh_token '
      'has_refresh_token=${current.refreshToken?.isNotEmpty ?? false} '
      'has_client_secret=false '
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
        'scope': [
          microsoftTodoOAuthScopes,
          if (hasMicrosoftGraphScope(
            current.scopes,
            microsoftSharedCalendarScope,
          ))
            microsoftSharedCalendarScope,
          if (hasMicrosoftGraphScope(current.scopes, microsoftCategoryScope))
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
    if (_persistence != null) {
      return (await boundCredentialForAccount(accountId)).tokenSet;
    }
    return _tokenStore.readOAuthTokenSet(accountId, BusyProvider.microsoft);
  }

  Future<MicrosoftTodoUserDto> _getMe(
    OAuthTokenSet tokenSet, {
    Future<void>? cancellation,
  }) async {
    final response = await boundedHttpRequest(
      _httpClient,
      'GET',
      Uri.https('graph.microsoft.com', '/v1.0/me'),
      cancellation: cancellation,
      headers: {'Authorization': 'Bearer ${tokenSet.accessToken}'},
    );
    if (response.statusCode != 200) {
      throw const OAuthException(
        'OAuthIdentityUnavailable',
        'Microsoft account identity could not be verified.',
      );
    }
    final decoded = decodeOAuthProviderObject(response.body);
    if (decoded['id'] is! String || (decoded['id'] as String).trim().isEmpty) {
      throw const OAuthException(
        'OAuthTemporaryResponse',
        'Microsoft returned an incomplete account response.',
      );
    }
    return MicrosoftTodoUserDto.fromJson(decoded);
  }

  MicrosoftPublicRegistration get _originalRegistration {
    final tenant = _config.microsoftOAuthAuthorityTenant.trim().toLowerCase();
    final audience = switch (tenant) {
      'common' => MicrosoftAudience.personalAndOrganizations,
      'organizations' => MicrosoftAudience.organizations,
      'consumers' => MicrosoftAudience.personal,
      _ => MicrosoftAudience.tenant,
    };
    return MicrosoftPublicRegistration(
      clientId: _config.microsoftOAuthClientId,
      audience: audience,
      tenantId: audience == MicrosoftAudience.tenant ? tenant : null,
      origin: RegistrationOrigin.retiringShared,
    );
  }
}

class MicrosoftOAuthSignInResult {
  const MicrosoftOAuthSignInResult({
    required this.accountId,
    required this.tokenSet,
    required this.user,
    this.tenantId,
    this.commit,
  });

  final String accountId;
  final OAuthTokenSet tokenSet;
  final MicrosoftTodoUserDto user;
  final String? tenantId;
  final AuthorizationCommit? commit;
}

/// ID tokens are issued to this client; Graph access tokens are opaque and
/// must never be decoded to infer account capabilities.
String? microsoftTenantIdFromIdToken(String? idToken, {String? clientId}) {
  if (idToken == null) return null;
  final parts = idToken.split('.');
  if (parts.length != 3) return null;
  try {
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (decoded is! Map) return null;
    if (clientId != null && decoded['aud'] != clientId) return null;
    final value = decoded['tid'];
    if (value is! String) return null;
    final tenantId = value.toLowerCase();
    return RegExp(
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
  return 'Microsoft token $operation failed (HTTP ${response.statusCode}). Check the registration or try again after a temporary outage.';
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
