import '../core/http/request_dispatch_exception.dart';
import '../core/auth/oauth_registration.dart';
import '../core/auth/registration_staging.dart';
import '../core/auth/authorization_persistence.dart';
import '../db/app_database.dart' hide AuthorizationCommit;
import 'android_account_gate.dart';
import 'dart:async';
import '../core/http/bounded_http.dart';

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
import '../calendar_providers/calendar_provider_capabilities.dart';
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

const _microsoftSharedNativeScope = 'Calendars.ReadWrite.Shared';
const _microsoftCategoryNativeScope = 'MailboxSettings.Read';

const _microsoftStoredScopes = <String>{
  'https://graph.microsoft.com/User.Read',
  'https://graph.microsoft.com/Tasks.ReadWrite',
  'https://graph.microsoft.com/Calendars.ReadWrite',
};

String? microsoftTenantIdFromAuthority(String? authority) {
  final uri = Uri.tryParse(authority ?? '');
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.toLowerCase() != 'login.microsoftonline.com' ||
      uri.pathSegments.isEmpty) {
    return null;
  }
  final segment = uri.pathSegments.first.toLowerCase();
  if (segment == 'consumers') return microsoftPersonalTenantId;
  return RegExp(
        r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
      ).hasMatch(segment)
      ? segment
      : null;
}

final class AndroidAuthorizationBroker
    implements
        OAuthGateway,
        GoogleConnectionGateway,
        RegistrationBindingResolver,
        MicrosoftConnectionGateway,
        MicrosoftOAuthGateway,
        MicrosoftSharedCalendarAuthorization,
        MicrosoftCategoryAuthorization,
        AccountTokenBroker {
  AndroidAuthorizationBroker({
    required BusyMaxAndroidPlatform platform,
    required http.Client httpClient,
    required SecretStore secretStore,
    required BuildConfig config,
    AppDatabase? database,
    RegistrationStaging? registrations,
    DateTime Function()? nowUtc,
  }) : _registrations = registrations ?? RegistrationStaging(config),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _platform = platform,
       _httpClient = httpClient,
       _secretStore = secretStore {
    if (database != null) {
      persistence = AuthorizationPersistence(
        database: database,
        secrets: secretStore,
        gate: AndroidCrossEngineAccountGate(platform),
        onCredentialWritten: applyNativeBinding,
        readNativeBinding: snapshotNativeBinding,
        restoreNativeBinding: restoreNativeBindingSnapshot,
        onRemovalCommitted: finishNativeRemoval,
      );
    }
  }

  AuthorizationPersistence? persistence;
  final RegistrationStaging _registrations;
  final DateTime Function() _nowUtc;
  int _attemptGeneration = 0;
  Completer<void>? _attemptCancellation;
  final BusyMaxAndroidPlatform _platform;
  final http.Client _httpClient;
  final SecretStore _secretStore;
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
  Future<OAuthSignInResult> signIn({String? loginHint}) =>
      connectGoogle(const AuthorizationRequest.newConnection(null));
  @override
  Future<OAuthSignInResult> connectGoogle(AuthorizationRequest request) async {
    if (request.registration != null ||
        request.intent == AuthorizationIntent.replaceRegistration) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'Google Android uses its native package/signature registration. Desktop configuration cannot replace it.',
      );
    }
    if (persistence == null) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'Account storage is unavailable.',
      );
    }
    await persistence!.recover();
    final attempt = _beginAttempt();
    final cancellation = _attemptCancellation!.future;
    final deadline = _nowUtc().add(const Duration(minutes: 10));
    final target = request.accountId;
    final previous = target == null
        ? null
        : await nativeCredential(target, BusyProvider.google);
    var expected = target == null ? 0 : await persistence!.generation(target);
    try {
      final native = await _boundedNative(
        () => _platform.authorizeGoogleInteractively(scopes: _googleScopes),
      );
      final tokens = _tokenSet(native);
      _requireSilentScopes(BusyProvider.google, tokens, candidate: true);
      final user = await fetchUserInfo(tokens, cancellation: cancellation);
      final subject = user?.subject;
      if (subject == null || subject.isEmpty) {
        throw const OAuthException(
          'OAuthIdentityUnavailable',
          'Google account identity could not be verified.',
        );
      }
      if (previous != null && previous.subject != subject) {
        throw const OAuthException(
          'OAuthWrongAccount',
          'Authorize the selected Google account.',
        );
      }
      final id = target ?? 'google:$subject';
      if (target == null) expected = await persistence!.generation(id);
      await _rejectDuplicate(target, id, subject, BusyProvider.google);
      final candidate = GoogleAndroidCredential(
        nativeAccountId: native.nativeAccountId,
        subject: subject,
        generation: expected + 1,
        username: native.username ?? user?.email,
      );
      return OAuthSignInResult(
        accountId: id,
        tokenSet: tokens,
        user: user,
        commit: _nativeCommit(
          id,
          expected,
          attempt,
          deadline,
          candidate,
          target != null,
        ),
      );
    } on PlatformException catch (error) {
      throw _oauthError(error, provider: 'Google');
    }
  }

  @override
  Future<MicrosoftOAuthSignInResult> signInWithMicrosoft() =>
      connectMicrosoft(const AuthorizationRequest.newConnection(null));
  @override
  Future<MicrosoftOAuthSignInResult> connectMicrosoft(
    AuthorizationRequest request,
  ) => _connectMicrosoft(request);
  Future<MicrosoftOAuthSignInResult> _connectMicrosoft(
    AuthorizationRequest request, {
    List<String> optional = const [],
  }) async {
    if (persistence == null) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'Account storage is unavailable.',
      );
    }
    await persistence!.recover();
    final attempt = _beginAttempt();
    final cancellation = _attemptCancellation!.future;
    final deadline = _nowUtc().add(const Duration(minutes: 10));
    final target = request.accountId;
    final stored = target == null
        ? null
        : await (persistence?.readCurrentCredential(target) ??
              _secretStore.readCredential(target));
    final previous = target == null
        ? null
        : request.intent == AuthorizationIntent.reconnect
        ? await nativeCredential(target, BusyProvider.microsoft)
              as MicrosoftAndroidCredential
        : stored is MicrosoftAndroidCredential
        ? stored
        : null;
    final intendedIdentity = target == null
        ? null
        : previous == null
        ? await _existingMicrosoftIdentity(target)
        : (previous.subject, previous.tenantId);
    var expected = target == null ? 0 : await persistence!.generation(target);
    final registration = request.intent == AuthorizationIntent.reconnect
        ? previous!.registration
        : request.registration == null
        ? null
        : _registrations.consume(request.registration!);
    if (registration is! MicrosoftPublicRegistration ||
        registration.platform != AuthenticationPlatform.android) {
      throw const OAuthException(
        'OAuthSetupRequired',
        'Set up your Microsoft public registration for the installed Android package and signature.',
      );
    }
    final installedIdentity = await _platform.microsoftRegistrationIdentity();
    if ((registration.origin == RegistrationOrigin.retiringShared ||
            registration.clientId == installedIdentity.retiringClientId) &&
        (request.intent != AuthorizationIntent.reconnect ||
            previous?.transitionEligible != true ||
            !await persistence!.wasPreexisting(target!))) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'Use your own Microsoft registration.',
      );
    }
    try {
      final native = await _boundedNative(
        () => _platform.authorizeMicrosoftInteractively(
          scopes: [..._microsoftNativeScopes, ...optional],
          clientId: registration.clientId,
          authorityTenant: registration.authorityTenant,
        ),
      );
      final tokens = _tokenSet(native);
      _requireSilentScopes(BusyProvider.microsoft, tokens, candidate: true);
      for (final scope in optional) {
        if (!tokens.scopes.contains('https://graph.microsoft.com/$scope')) {
          throw const OAuthException(
            'OAuthMissingRequiredScope',
            'The requested optional permission was not granted.',
          );
        }
      }
      final user = await _microsoftMe(
        native.accessToken,
        cancellation: cancellation,
      );
      final tenant = microsoftTenantIdFromAuthority(native.authority);
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
      final id = target ?? 'microsoft:${user.id}';
      if (target == null) expected = await persistence!.generation(id);
      await _rejectDuplicate(target, id, user.id, BusyProvider.microsoft);
      final candidate = MicrosoftAndroidCredential(
        registration: registration,
        tenantId: tenant,
        authority: native.authority!,
        nativeAccountId: native.nativeAccountId,
        subject: user.id,
        username: native.username ?? user.mail ?? user.userPrincipalName,
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
        commit: _nativeCommit(
          id,
          expected,
          attempt,
          deadline,
          candidate,
          target != null,
        ),
      );
    } on PlatformException catch (error) {
      throw _oauthError(error, provider: 'Microsoft');
    }
  }

  AuthorizationCommit _nativeCommit(
    String id,
    int expected,
    int attempt,
    DateTime deadline,
    NativeOAuthCredential candidate,
    bool existing,
  ) => (persistAccount) async {
    if (attempt != _attemptGeneration || !_nowUtc().isBefore(deadline)) {
      throw const OAuthException(
        'OAuthSignInCancelled',
        'Authorization was cancelled.',
      );
    }
    if (persistence == null) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'Account storage is unavailable.',
      );
    }
    await persistence!.commit(
      accountId: id,
      expectedGeneration: expected,
      candidate: candidate,
      validateCandidate: () {
        if (attempt != _attemptGeneration || !_nowUtc().isBefore(deadline)) {
          throw const OAuthException(
            'OAuthSignInCancelled',
            'Authorization was cancelled.',
          );
        }
      },
      requireExisting: existing,
      persistAccount: persistAccount,
    );
  };
  Future<void> _rejectDuplicate(
    String? target,
    String id,
    String subject,
    BusyProvider provider,
  ) async {
    if (persistence == null) {
      throw const OAuthException(
        'OAuthConfigurationRejected',
        'Account storage is unavailable.',
      );
    }
    if (target != null) return;
    final rows = await persistence!.database
        .select(persistence!.database.accounts)
        .get();
    if (rows.any(
      (row) =>
          row.id == id ||
          (row.provider == provider.storageValue &&
              row.providerAccountId == subject),
    )) {
      throw const OAuthException(
        'OAuthAccountAlreadyConnected',
        'This account already exists. Use its Reconnect or Migrate action.',
      );
    }
  }

  @override
  Future<void> establishExistingBinding(
    String id,
    BusyProvider provider,
  ) async {
    await nativeCredential(id, provider);
  }

  Future<NativeOAuthCredential> nativeCredential(
    String id,
    BusyProvider provider,
  ) async {
    final record =
        await (persistence?.readCurrentCredential(id) ??
            _secretStore.readCredential(id));
    if (record is NativeOAuthCredential && record.provider == provider) {
      final alias = await _platform.readAuthorizationBinding(
        provider.storageValue,
        id,
      );
      if (alias?.nativeAccountId != record.nativeAccountId ||
          (record is MicrosoftAndroidCredential &&
              (alias?.clientId != record.registration.clientId ||
                  alias?.authorityTenant !=
                      record.registration.authorityTenant))) {
        await persistence!.run(id, () async {
          if (await persistence!.generation(id) != record.generation) {
            throw const OAuthException(
              'OAuthStaleAuthorization',
              'The account authorization changed.',
            );
          }
          await applyNativeBinding(id, record);
        });
      }
      if (record is MicrosoftAndroidCredential &&
          record.registration.origin == RegistrationOrigin.retiringShared) {
        _registrations.rememberRetiringClient(record.registration.clientId);
      }
      return record;
    }
    final store = persistence;
    final binding = await _platform.readAuthorizationBinding(
      provider.storageValue,
      id,
    );
    if (record != null ||
        store == null ||
        binding == null ||
        !await store.wasPreexisting(id)) {
      throw const OAuthException(
        'OAuthRegistrationUnresolved',
        'Native registration binding is unavailable. Account data is preserved.',
      );
    }
    final row = await (store.database.select(
      store.database.accounts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const OAuthException(
        'OAuthStaleAuthorization',
        'This account was removed.',
      );
    }
    final generation = await store.generation(id);
    final NativeOAuthCredential candidate;
    if (provider == BusyProvider.google) {
      candidate = GoogleAndroidCredential(
        nativeAccountId: binding.nativeAccountId,
        subject: row.providerAccountId,
        generation: generation,
        username: binding.username,
      );
    } else {
      if (binding.clientId == null ||
          row.tenantId == null ||
          !binding.originalRegistration) {
        throw const OAuthException(
          'OAuthRegistrationUnresolved',
          'The original native Microsoft client or tenant is unavailable. Account data is preserved.',
        );
      }
      final authorityTenant = binding.authorityTenant ?? 'common';
      final audience = switch (authorityTenant) {
        'common' => MicrosoftAudience.personalAndOrganizations,
        'organizations' => MicrosoftAudience.organizations,
        'consumers' => MicrosoftAudience.personal,
        _ => MicrosoftAudience.tenant,
      };
      candidate = MicrosoftAndroidCredential(
        registration: MicrosoftPublicRegistration(
          clientId: binding.clientId!,
          audience: audience,
          tenantId: audience == MicrosoftAudience.tenant
              ? authorityTenant
              : null,
          platform: AuthenticationPlatform.android,
          origin: RegistrationOrigin.retiringShared,
        ),
        tenantId: row.tenantId!,
        authority: binding.authority!,
        transitionEligible: true,
        nativeAccountId: binding.nativeAccountId,
        subject: row.providerAccountId,
        generation: generation,
        username: binding.username,
      );
    }
    await store.commit(
      accountId: id,
      expectedGeneration: generation,
      candidate: candidate,
      requireExisting: true,
      persistAccount: () async {},
    );
    return candidate;
  }

  Future<AndroidAuthorizationToken> _boundedSilent(
    Future<AndroidAuthorizationToken> operation,
  ) => operation.timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw const OAuthException(
      'OAuthRequestTimeout',
      'Native token acquisition timed out. Try again.',
    ),
  );

  Future<AndroidAuthorizationToken> _boundedNative(
    Future<AndroidAuthorizationToken> Function() authorize,
  ) =>
      Future.any([
        authorize(),
        _attemptCancellation!.future.then<AndroidAuthorizationToken>(
          (_) => throw const OAuthException(
            'OAuthSignInCancelled',
            'Authorization was cancelled.',
          ),
        ),
      ]).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          unawaited(_platform.cancelInteractiveAuthorization());
          throw const OAuthException(
            'OAuthRequestTimeout',
            'Native authorization timed out.',
          );
        },
      );

  Future<(String, String)> _existingMicrosoftIdentity(String id) async {
    final account = await (persistence!.database.select(
      persistence!.database.accounts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (account == null ||
        account.provider != 'microsoft' ||
        account.providerAccountId.isEmpty ||
        account.tenantId == null) {
      throw const OAuthException(
        'OAuthRegistrationUnresolved',
        'This account lacks a verified tenant identity. Its data is preserved; restore the original configuration first.',
      );
    }
    return (account.providerAccountId, account.tenantId!);
  }

  Future<BusyProvider> _nativeProvider(String id) async {
    final account = await (persistence!.database.select(
      persistence!.database.accounts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return account == null
        ? (id.startsWith('google:')
              ? BusyProvider.google
              : BusyProvider.microsoft)
        : BusyProviderCodec.requireStorageValue(account.provider);
  }

  Future<NativeBindingSnapshot?> snapshotNativeBinding(String id) async {
    final provider = await _nativeProvider(id);
    final binding = await _platform.readAuthorizationBinding(
      provider.storageValue,
      id,
    );
    return binding == null
        ? null
        : NativeBindingSnapshot(
            provider: provider,
            nativeAccountId: binding.nativeAccountId,
            username: binding.username,
            authority: binding.authority,
            clientId: binding.clientId,
            authorityTenant: binding.authorityTenant,
          );
  }

  Future<void> restoreNativeBindingSnapshot(
    String id,
    NativeBindingSnapshot? snapshot,
  ) async {
    if (snapshot == null) {
      await _platform.clearAuthorizationBinding(
        (await _nativeProvider(id)).storageValue,
        id,
      );
    } else {
      await _platform.bindAuthorization(
        provider: snapshot.provider.storageValue,
        accountId: id,
        nativeAccountId: snapshot.nativeAccountId,
        username: snapshot.username,
        authority: snapshot.authority,
        clientId: snapshot.clientId,
        authorityTenant: snapshot.authorityTenant,
      );
    }
  }

  Future<void> finishNativeRemoval(
    String id,
    NativeBindingSnapshot? snapshot,
  ) async {
    await _platform.removeAuthorization(
      provider: (snapshot?.provider ?? await _nativeProvider(id)).storageValue,
      accountId: id,
    );
  }

  Future<void> applyNativeBinding(String id, SecretRecord? record) async {
    if (record == null) {
      await _platform.clearAuthorizationBinding(
        (await _nativeProvider(id)).storageValue,
        id,
      );
    } else if (record is NativeOAuthCredential) {
      final microsoft = record is MicrosoftAndroidCredential ? record : null;
      await _platform.bindAuthorization(
        provider: record.provider.storageValue,
        accountId: id,
        nativeAccountId: record.nativeAccountId,
        username: record.username,
        authority: microsoft?.authority,
        clientId: microsoft?.registration.clientId,
        authorityTenant: microsoft?.registration.authorityTenant,
      );
    }
  }

  @override
  Future<void> authorizeCategoryAccess(String id) async {
    await _optionalNativeConsent(id, _microsoftCategoryNativeScope);
  }

  @override
  Future<void> authorizeSharedCalendarAccess(String id) async {
    await _optionalNativeConsent(id, _microsoftSharedNativeScope);
  }

  Future<void> _optionalNativeConsent(String id, String scope) async {
    final current = await nativeCredential(id, BusyProvider.microsoft);
    try {
      final result = await _connectMicrosoft(
        AuthorizationRequest.reconnect(id),
        optional: [scope],
      );
      await result.commit!(() async {});
    } on OAuthException catch (error) {
      throw AuthorizationScopedOAuthException(
        accountId: id,
        generation: current.generation,
        cause: error,
      );
    }
  }

  @override
  Future<GoogleUserInfo?> fetchUserInfo(
    OAuthTokenSet tokenSet, {
    Future<void>? cancellation,
  }) async {
    final response = await boundedHttpRequest(
      _httpClient,
      'GET',
      Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
      cancellation: cancellation,
      headers: {'Authorization': 'Bearer ${tokenSet.accessToken}'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = decodeOAuthProviderObject(response.body);
    return GoogleUserInfo.fromJson(decoded);
  }

  Future<MicrosoftTodoUserDto> _microsoftMe(
    String accessToken, {
    Future<void>? cancellation,
  }) async {
    final response = await boundedHttpRequest(
      _httpClient,
      'GET',
      Uri.https('graph.microsoft.com', '/v1.0/me'),
      cancellation: cancellation,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OAuthException(
        'MicrosoftOAuthUserInfoFailed',
        'Microsoft account details could not be loaded (HTTP ${response.statusCode}).',
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

  @override
  Future<String> authorizationHeader(
    BusyProvider provider,
    String accountId,
  ) async {
    try {
      final current = persistence == null
          ? null
          : await nativeCredential(accountId, provider);
      final microsoft = current is MicrosoftAndroidCredential ? current : null;
      final token = switch (provider) {
        BusyProvider.google => await _boundedSilent(
          _platform.authorizeGoogleSilently(
            accountId: accountId,
            scopes: _googleScopes,
          ),
        ),
        BusyProvider.microsoft => await _boundedSilent(
          _platform.authorizeMicrosoftSilently(
            accountId: accountId,
            scopes: _microsoftNativeScopes,
            clientId: microsoft?.registration.clientId,
            authorityTenant: microsoft?.registration.authorityTenant,
            nativeAccountId: microsoft?.nativeAccountId,
            authority: microsoft?.authority,
          ),
        ),
        _ => throw StateError('$provider does not use native authorization.'),
      };
      final tokenSet = _tokenSet(token);
      _requireSilentScopes(provider, tokenSet);
      await _acceptNativeToken(accountId, current, token);
      return 'Bearer ${token.accessToken}';
    } on PlatformException catch (error) {
      throw _silentOAuthError(error, provider: provider);
    }
  }

  @override
  Future<String> microsoftSharedCalendarAuthorizationHeader(
    String accountId,
  ) async {
    try {
      final current = persistence == null
          ? null
          : await nativeCredential(accountId, BusyProvider.microsoft)
                as MicrosoftAndroidCredential;
      final native = await _boundedSilent(
        _platform.authorizeMicrosoftSilently(
          accountId: accountId,
          scopes: [..._microsoftNativeScopes, _microsoftSharedNativeScope],
          clientId: current?.registration.clientId,
          authorityTenant: current?.registration.authorityTenant,
          nativeAccountId: current?.nativeAccountId,
          authority: current?.authority,
        ),
      );
      final tokenSet = _tokenSet(native);
      _requireSilentScopes(BusyProvider.microsoft, tokenSet);
      if (!tokenSet.scopes.contains(microsoftSharedCalendarScope)) {
        throw const OAuthException(
          'MicrosoftOAuthSharedConsentRequired',
          'Shared-calendar permission must be granted for this account.',
        );
      }
      await _acceptNativeToken(accountId, current, native);
      return 'Bearer ${native.accessToken}';
    } on PlatformException catch (error) {
      throw _silentOAuthError(error, provider: BusyProvider.microsoft);
    }
  }

  @override
  Future<String> microsoftCategoryAuthorizationHeader(String accountId) async {
    try {
      final current = persistence == null
          ? null
          : await nativeCredential(accountId, BusyProvider.microsoft)
                as MicrosoftAndroidCredential;
      final native = await _boundedSilent(
        _platform.authorizeMicrosoftSilently(
          accountId: accountId,
          scopes: [..._microsoftNativeScopes, _microsoftCategoryNativeScope],
          clientId: current?.registration.clientId,
          authorityTenant: current?.registration.authorityTenant,
          nativeAccountId: current?.nativeAccountId,
          authority: current?.authority,
        ),
      );
      final tokenSet = _tokenSet(native);
      _requireSilentScopes(BusyProvider.microsoft, tokenSet);
      if (!tokenSet.scopes.contains(microsoftCategoryScope)) {
        throw const OAuthException(
          'MicrosoftOAuthCategoryConsentRequired',
          'Outlook category lookup requires optional mailbox-settings consent.',
        );
      }
      await _acceptNativeToken(accountId, current, native);
      return 'Bearer ${native.accessToken}';
    } on PlatformException catch (error) {
      throw _silentOAuthError(error, provider: BusyProvider.microsoft);
    }
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
    try {
      final current = persistence == null
          ? null
          : await nativeCredential(accountId, BusyProvider.google);
      final native = await _boundedSilent(
        _platform.authorizeGoogleSilently(
          accountId: accountId,
          scopes: _googleScopes,
        ),
      );
      final tokenSet = _tokenSet(native);
      _requireSilentScopes(BusyProvider.google, tokenSet);
      await _acceptNativeToken(accountId, current, native);
      return tokenSet;
    } on PlatformException catch (error) {
      throw _silentOAuthError(error, provider: BusyProvider.google);
    }
  }

  Future<void> _acceptNativeToken(
    String id,
    NativeOAuthCredential? observed,
    AndroidAuthorizationToken token,
  ) async {
    final store = persistence;
    if (store == null || observed == null) {
      _lastAccessTokens[id] = token.accessToken;
      return;
    }
    await store.run(id, () async {
      if (await store.generation(id) != observed.generation) {
        throw const OAuthException(
          'OAuthStaleAuthorization',
          'The account authorization changed during native token acquisition.',
        );
      }
      final current = await _secretStore.readCredential(id);
      if (current is! NativeOAuthCredential ||
          current.provider != observed.provider ||
          current.subject != observed.subject ||
          current.nativeAccountId != observed.nativeAccountId ||
          current.generation != observed.generation) {
        throw const OAuthException(
          'OAuthStaleAuthorization',
          'The native account binding changed during token acquisition.',
        );
      }
      if (token.nativeAccountId != observed.nativeAccountId ||
          (observed is MicrosoftAndroidCredential &&
              microsoftTenantIdFromAuthority(token.authority) !=
                  observed.tenantId)) {
        throw const OAuthException(
          'OAuthWrongAccount',
          'The native token did not match the selected account and tenant.',
        );
      }
      _lastAccessTokens[id] = token.accessToken;
    });
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
    if (target != null) {
      _lastAccessTokens.remove(target);
      await _secretStore.deleteCredential(target);
      if (target.startsWith('google:')) {
        await _platform.removeAuthorization(
          provider: BusyProvider.google.storageValue,
          accountId: target,
        );
      }
    }
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
    await _secretStore.deleteCredential(accountId);
    await clearLocalSession(accountId: accountId);
  }

  @override
  Future<void> cancelSignIn() async {
    _attemptGeneration++;
    _attemptCancellation?.complete();
    _attemptCancellation = null;
    _registrations.cancel();
    await _platform.cancelInteractiveAuthorization().timeout(
      const Duration(seconds: 10),
    );
  }

  int _beginAttempt() {
    if (_attemptCancellation?.isCompleted == false) {
      _attemptCancellation!.complete();
    }
    _attemptCancellation = Completer<void>();
    return ++_attemptGeneration;
  }

  OAuthTokenSet _tokenSet(AndroidAuthorizationToken token) => OAuthTokenSet(
    accessToken: token.accessToken,
    expiresAtUtc:
        token.expiresAtUtc ??
        DateTime.now().toUtc().add(const Duration(minutes: 45)),
    tokenType: 'Bearer',
    // Persist only scopes reported by the authorization provider. Adding the
    // requested scopes here would turn a denied permission into a fake grant.
    scopes: {for (final scope in token.scopes) _storedScope(scope)},
  );

  void _requireSilentScopes(
    BusyProvider provider,
    OAuthTokenSet tokenSet, {
    bool candidate = false,
  }) {
    final granted = tokenSet.scopes;
    final complete = switch (provider) {
      BusyProvider.google =>
        granted.contains(googleTasksReadWriteScope) &&
            granted.contains(googleCalendarReadWriteScope),
      BusyProvider.microsoft => _microsoftStoredScopes.every(granted.contains),
      _ => true,
    };
    if (!complete) {
      throw OAuthException(
        candidate
            ? 'OAuthMissingRequiredScope'
            : provider == BusyProvider.microsoft
            ? 'MicrosoftOAuthMissingToken'
            : 'OAuthMissingToken',
        '${provider.displayName} permissions must be reconnected.',
      );
    }
  }
}

String _storedScope(String value) {
  final scope = value.trim();
  for (final nativeScope in [
    ..._microsoftNativeScopes,
    _microsoftSharedNativeScope,
    _microsoftCategoryNativeScope,
  ]) {
    if (scope.toLowerCase() == nativeScope.toLowerCase()) {
      return 'https://graph.microsoft.com/$nativeScope';
    }
  }
  return scope;
}

OAuthException _silentOAuthError(
  PlatformException error, {
  required BusyProvider provider,
}) {
  final reconnect = error.code == 'android/auth-interaction-required';
  if (reconnect) {
    return OAuthException(
      provider == BusyProvider.microsoft
          ? 'MicrosoftOAuthMissingToken'
          : 'OAuthMissingToken',
      '${provider.displayName} authorization must be reconnected.',
    );
  }
  return OAuthException(
    error.code,
    error.message ?? '${provider.displayName} authorization failed.',
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
