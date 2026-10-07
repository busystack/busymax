import '../../../core/auth/authorization_attempt.dart';
import '../../../core/http/request_dispatch_exception.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/logging/redacting_logger.dart';
import '../../../core/auth/microsoft_graph_scopes.dart';
import '../../../core/auth/oauth_registration.dart';
import '../../../core/auth/authorization_persistence.dart';
import '../../../dav/dav_errors.dart';
import '../../../db/app_database.dart';
import '../../../features/accounts/data/accounts_repository.dart';
import '../../../google_tasks/api/google_tasks_api_surface.dart';
import '../../../google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import '../../../google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import '../../../microsoft_todo/oauth/microsoft_oauth_service.dart';
import '../../sync/sync_auth_error.dart';
import 'package:busymax/src/providers/busy_provider.dart';

enum AuthSessionStatus {
  unconfigured,
  loading,
  signedOut,
  signingIn,
  signedIn,
  expired,
  error,
}

@immutable
class AuthSessionState {
  const AuthSessionState._({
    required this.status,
    this.accountId,
    this.message,
    this.failureKind,
  });

  const AuthSessionState.unconfigured()
    : this._(status: AuthSessionStatus.unconfigured);

  const AuthSessionState.loading() : this._(status: AuthSessionStatus.loading);

  const AuthSessionState.signedOut()
    : this._(status: AuthSessionStatus.signedOut);

  const AuthSessionState.signingIn()
    : this._(status: AuthSessionStatus.signingIn);

  const AuthSessionState.signedIn(String accountId)
    : this._(status: AuthSessionStatus.signedIn, accountId: accountId);

  const AuthSessionState.expired(String accountId)
    : this._(status: AuthSessionStatus.expired, accountId: accountId);

  const AuthSessionState.error(String message, {OAuthFailureKind? failureKind})
    : this._(
        status: AuthSessionStatus.error,
        message: message,
        failureKind: failureKind,
      );

  final AuthSessionStatus status;
  final String? accountId;
  final String? message;
  final OAuthFailureKind? failureKind;

  bool get isSignedIn => status == AuthSessionStatus.signedIn;
}

enum AccountAuthorizationRevocationStatus { notRequested, succeeded, failed }

@immutable
class AccountRemovalResult {
  const AccountRemovalResult({
    required this.authorizationRevocationStatus,
    this.alreadyRemoved = false,
  });

  const AccountRemovalResult.alreadyRemoved()
    : authorizationRevocationStatus =
          AccountAuthorizationRevocationStatus.notRequested,
      alreadyRemoved = true;

  final AccountAuthorizationRevocationStatus authorizationRevocationStatus;
  final bool alreadyRemoved;

  bool get authorizationRevocationFailed =>
      authorizationRevocationStatus ==
      AccountAuthorizationRevocationStatus.failed;
}

class AccountRemovalPersistenceException extends OAuthException {
  const AccountRemovalPersistenceException()
    : super(
        'OAuthRemovalAfterRevocationFailed',
        'Google authorization was revoked, but account cleanup could not finish. Restart BusyMax to retry local recovery.',
      );
  bool get remoteAuthorizationRevoked => true;
  @override
  OAuthFailureKind get classification => OAuthFailureKind.storage;
}

class AuthRepository {
  AuthRepository({
    required OAuthGateway oAuth,
    required AppDatabase database,
    AccountsRepository? accountsRepository,
    MicrosoftOAuthGateway? microsoftOAuth,
    DateTime Function()? nowUtc,
    AuthorizationPersistence? authorizationPersistence,
  }) : _authorizationPersistence = authorizationPersistence,
       _oAuth = oAuth,
       _accountsRepository =
           accountsRepository ??
           AccountsRepository(database: database, nowUtc: nowUtc),
       _microsoftOAuth = microsoftOAuth;

  final AuthorizationPersistence? _authorizationPersistence;
  final OAuthGateway _oAuth;
  final AccountsRepository _accountsRepository;
  final MicrosoftOAuthGateway? _microsoftOAuth;
  final RedactingLogger _logger = RedactingLogger(Logger('AuthRepository'));

  Future<AuthSessionState> loadSession() async {
    await _authorizationPersistence?.recover();
    final connectedAccounts = await _accountsRepository.listSignedInAccounts();
    if (connectedAccounts.isNotEmpty) {
      return AuthSessionState.signedIn(connectedAccounts.first.id);
    }
    final accounts = await _accountsRepository.listVisibleAccounts();
    if (accounts.isEmpty) {
      return const AuthSessionState.signedOut();
    }

    return AuthSessionState.signedIn(accounts.first.id);
  }

  /// Reads only persisted connection state; recovery belongs to startup/load.
  Future<AuthSessionState?> sessionAfterConnection(
    String connectedAccountId, {
    String? currentAccountId,
  }) async {
    final connected = await _accountsRepository.accountById(connectedAccountId);
    if (connected == null ||
        connected.isSubscription ||
        !connected.isSignedIn) {
      return null;
    }
    if (currentAccountId != null && currentAccountId != connectedAccountId) {
      final current = await _accountsRepository.accountById(currentAccountId);
      if (current != null && !current.isSubscription && current.isSignedIn) {
        return AuthSessionState.signedIn(current.id);
      }
    }
    return AuthSessionState.signedIn(connected.id);
  }

  Future<AuthSessionState> signIn({AuthorizationRequest? request}) async {
    final gateway = _oAuth;
    final result = request != null && gateway is GoogleConnectionGateway
        ? await (gateway as GoogleConnectionGateway).connectGoogle(request)
        : await gateway.signIn();
    final missingScopes = _missingRequiredGoogleApiScopes(result.tokenSet);
    if (missingScopes.isNotEmpty) {
      throw OAuthException(
        'OAuthMissingRequiredScope',
        _googleMissingScopesMessage(missingScopes),
      );
    }

    Future<void> persist() => _upsertGoogleSignedInAccount(
      result.accountId,
      result.tokenSet,
      user: result.user,
    );
    if (result.commit != null) {
      await result.commit!(persist);
    } else {
      await persist();
    }
    return AuthSessionState.signedIn(result.accountId);
  }

  Future<AuthSessionState> signInWithMicrosoft({
    AuthorizationRequest? request,
  }) async {
    final microsoftOAuth = _microsoftOAuth;
    if (microsoftOAuth == null) {
      throw const OAuthException(
        'MicrosoftOAuthUnavailable',
        'Microsoft sign-in is not available.',
      );
    }
    final result =
        request != null && microsoftOAuth is MicrosoftConnectionGateway
        ? await (microsoftOAuth as MicrosoftConnectionGateway).connectMicrosoft(
            request,
          )
        : await microsoftOAuth.signInWithMicrosoft();
    if (!_hasRequiredMicrosoftScopes(result.tokenSet)) {
      throw const OAuthException(
        'MicrosoftOAuthMissingRequiredScope',
        'Required Microsoft To Do permission was not granted.',
      );
    }

    Future<void> persist() async {
      // Read preferences inside the serialized database commit, after secure
      // storage succeeds. Changes made during that write must be retained.
      final existing = await _accountsRepository.accountById(result.accountId);
      await _accountsRepository.upsertSignedInAccount(
        id: result.accountId,
        calendarsEnabled: existing?.calendarsEnabled ?? true,
        tasksEnabled: existing?.tasksEnabled ?? true,
        provider: BusyProvider.microsoft,
        providerAccountId: result.user.id,
        displayName: result.user.displayName,
        email: result.user.mail ?? result.user.userPrincipalName,
        tenantId: result.tenantId,
        grantedScopes: result.tokenSet.scopes.join(' '),
        providerMetadata: result.user.rawJson,
      );
    }

    if (result.commit != null) {
      await result.commit!(persist);
    } else {
      await persist();
    }
    return AuthSessionState.signedIn(result.accountId);
  }

  Future<void> markReconnectRequired(
    String accountId, {
    int? authorizationGeneration,
  }) async {
    Future<void> mark() async {
      final account = await _accountsRepository.accountById(accountId);
      if (account == null) return;
      if (authorizationGeneration != null &&
          _authorizationPersistence != null &&
          await _authorizationPersistence.generation(accountId) !=
              authorizationGeneration) {
        return;
      }
      await _accountsRepository.markReconnectRequired(accountId);
      // A recoverable state never deletes native bindings, credentials or reminders.
    }

    if (_authorizationPersistence != null) {
      await _authorizationPersistence.run(accountId, mark);
    } else {
      await mark();
    }
  }

  Future<AccountRemovalResult> removeAccount({
    required String accountId,
    bool revokeAuthorization = false,
  }) {
    final persistence = _authorizationPersistence;
    if (persistence == null) {
      return _removeAccount(
        accountId: accountId,
        revokeAuthorization: revokeAuthorization,
      );
    }
    return persistence.runRemoval(
      accountId,
      (snapshot) => _removeAccount(
        accountId: accountId,
        revokeAuthorization: revokeAuthorization,
        snapshot: snapshot,
      ),
    );
  }

  Future<AccountRemovalResult> _removeAccount({
    required String accountId,
    bool revokeAuthorization = false,
    AuthorizationRemovalSnapshot? snapshot,
  }) async {
    final account = await _accountsRepository.accountById(accountId);
    if (account == null) {
      return const AccountRemovalResult.alreadyRemoved();
    }

    var revocationStatus = AccountAuthorizationRevocationStatus.notRequested;
    if (revokeAuthorization && account.provider == BusyProvider.google) {
      try {
        final gateway = _oAuth;
        if (snapshot != null && gateway is GoogleRemovalRevoker) {
          await (gateway as GoogleRemovalRevoker).revokeSelectedAuthorization(
            snapshot,
          );
        } else {
          await gateway.revokeAuthorization(accountId);
        }
        revocationStatus = AccountAuthorizationRevocationStatus.succeeded;
      } on Object catch (error) {
        _logger.warning(
          'Google authorization revocation failed during account removal: '
          '$error',
        );
        revocationStatus = AccountAuthorizationRevocationStatus.failed;
      }
    }

    Future<void> clearAuthorization() async {
      if (account.provider == BusyProvider.microsoft) {
        await _microsoftOAuth?.signOutAccount(accountId);
      } else {
        await _oAuth.clearLocalSession(accountId: accountId);
      }
    }

    if (_authorizationPersistence case final persistence?) {
      try {
        await persistence.removeCoherently(
          accountId,
          clearAuthorization,
          () => _accountsRepository.deleteAccount(accountId),
        );
      } on Object {
        if (revocationStatus ==
            AccountAuthorizationRevocationStatus.succeeded) {
          throw const AccountRemovalPersistenceException();
        }
        rethrow;
      }
    } else {
      await clearAuthorization();
      await _accountsRepository.deleteAccount(accountId);
    }

    return AccountRemovalResult(
      authorizationRevocationStatus: revocationStatus,
    );
  }

  Future<void> cancelSignIn() async {
    await Future.wait([
      _oAuth.cancelSignIn(),
      if (_microsoftOAuth != null) _microsoftOAuth.cancelSignIn(),
    ]);
  }

  Set<String> _missingRequiredGoogleApiScopes(OAuthTokenSet tokenSet) {
    return {
      if (!tokenSet.scopes.contains(googleTasksReadWriteScope))
        googleTasksReadWriteScope,
      if (!tokenSet.scopes.contains(googleCalendarReadWriteScope))
        googleCalendarReadWriteScope,
    };
  }

  String _googleMissingScopesMessage(
    Set<String> missingScopes, {
    bool noLongerAvailable = false,
  }) {
    final permissionNames = [
      if (missingScopes.contains(googleTasksReadWriteScope)) 'Google Tasks',
      if (missingScopes.contains(googleCalendarReadWriteScope))
        'Google Calendar',
    ];
    final permissionText = switch (permissionNames) {
      [final single] => '$single permission',
      [final first, final second] => '$first and $second permissions',
      _ => 'required Google permissions',
    };
    final singlePermission = permissionNames.length == 1;
    final suffix = noLongerAvailable
        ? (singlePermission
              ? 'is no longer available'
              : 'are no longer available')
        : (singlePermission ? 'was not granted' : 'were not granted');
    return 'Required $permissionText $suffix.';
  }

  bool _hasRequiredMicrosoftScopes(OAuthTokenSet tokenSet) {
    return hasMicrosoftGraphScopes(tokenSet.scopes, const [
      'User.Read',
      'Tasks.ReadWrite',
      'Calendars.ReadWrite',
    ]);
  }

  Future<void> _upsertGoogleSignedInAccount(
    String accountId,
    OAuthTokenSet tokenSet, {
    GoogleUserInfo? user,
  }) async {
    final existing = await _accountsRepository.accountById(accountId);
    final idTokenClaims = googleIdTokenClaims(tokenSet);
    final userInfo = user ?? await _fetchGoogleUserInfo(tokenSet);
    await _accountsRepository.upsertSignedInAccount(
      id: accountId,
      calendarsEnabled: existing?.calendarsEnabled ?? true,
      tasksEnabled: existing?.tasksEnabled ?? true,
      provider: BusyProvider.google,
      providerAccountId: _firstNonBlank([
        userInfo?.subject,
        idTokenClaims['sub']?.toString(),
        existing?.providerAccountId,
      ]),
      displayName: _firstNonBlank([
        userInfo?.name,
        idTokenClaims['name']?.toString(),
        existing?.displayName,
      ]),
      email: _firstNonBlank([
        userInfo?.email,
        idTokenClaims['email']?.toString(),
        existing?.email,
      ]),
      grantedScopes: tokenSet.scopes.join(' '),
      providerMetadata: userInfo?.rawJson,
    );
  }

  Future<GoogleUserInfo?> _fetchGoogleUserInfo(OAuthTokenSet tokenSet) async {
    try {
      return await _oAuth.fetchUserInfo(tokenSet);
    } on Object {
      return null;
    }
  }
}

String? _firstNonBlank(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

class AuthSessionController extends StateNotifier<AuthSessionState> {
  AuthSessionController({
    required AuthRepository repository,
    required bool isConfigured,
    required Future<void> Function(String accountId, bool initial) onSignedIn,
  }) : _repository = repository,
       _isConfigured = isConfigured,
       _onSignedIn = onSignedIn,
       super(
         isConfigured
             ? const AuthSessionState.loading()
             : const AuthSessionState.unconfigured(),
       ) {
    if (_isConfigured) {
      load();
    }
  }

  final AuthRepository _repository;
  final bool _isConfigured;
  final Future<void> Function(String accountId, bool initial) _onSignedIn;
  final RedactingLogger _logger = RedactingLogger(
    Logger('AuthSessionController'),
  );
  var _signInGeneration = 0;

  /// Reconciles a committed Settings connection without scheduling any sync.
  Future<void> reconcileConnectedAccount(String accountId) async {
    if (!mounted) return;
    final previous = state;
    final generation = _signInGeneration;
    final reconciled = await _repository.sessionAfterConnection(
      accountId,
      currentAccountId: previous.isSignedIn ? previous.accountId : null,
    );
    if (!mounted ||
        generation != _signInGeneration ||
        !identical(state, previous) ||
        reconciled == null) {
      return;
    }
    if (!previous.isSignedIn || previous.accountId != reconciled.accountId) {
      state = reconciled;
    }
  }

  Future<void> load() async {
    if (!_isConfigured) {
      state = const AuthSessionState.unconfigured();
      return;
    }

    try {
      final loaded = await _repository.loadSession();
      state = loaded;
      if (loaded.accountId != null && loaded.isSignedIn) {
        _startSignedInSync(loaded.accountId!, false);
      }
    } on Object catch (error) {
      state = AuthSessionState.error(
        authErrorMessage(error),
        failureKind: error is OAuthException ? error.classification : null,
      );
    }
  }

  Future<void> signIn({AuthorizationRequest? request}) async {
    if (!_isConfigured) {
      state = const AuthSessionState.unconfigured();
      return;
    }
    if (state.status == AuthSessionStatus.signingIn) {
      return;
    }

    final generation = _signInGeneration + 1;
    _signInGeneration = generation;
    state = const AuthSessionState.signingIn();
    try {
      final signedIn = await _repository.signIn(request: request);
      if (generation != _signInGeneration) {
        return;
      }
      state = signedIn;
      _startSignedInSync(signedIn.accountId!, true);
    } on Object catch (error) {
      if (generation != _signInGeneration) {
        return;
      }
      if (error is OAuthException && error.code == 'OAuthSignInCancelled') {
        state = const AuthSessionState.signedOut();
        return;
      }
      state = AuthSessionState.error(
        authErrorMessage(error),
        failureKind: error is OAuthException ? error.classification : null,
      );
    }
  }

  Future<void> signInWithMicrosoft({AuthorizationRequest? request}) async {
    if (!_isConfigured) {
      state = const AuthSessionState.unconfigured();
      return;
    }
    if (state.status == AuthSessionStatus.signingIn) {
      return;
    }

    final generation = _signInGeneration + 1;
    _signInGeneration = generation;
    state = const AuthSessionState.signingIn();
    try {
      final signedIn = await _repository.signInWithMicrosoft(request: request);
      if (generation != _signInGeneration) {
        return;
      }
      state = signedIn;
      _startSignedInSync(signedIn.accountId!, true);
    } on Object catch (error) {
      if (generation != _signInGeneration) {
        return;
      }
      if (error is OAuthException && error.code == 'OAuthSignInCancelled') {
        state = const AuthSessionState.signedOut();
        return;
      }
      state = AuthSessionState.error(
        authErrorMessage(error),
        failureKind: error is OAuthException ? error.classification : null,
      );
    }
  }

  Future<void> cancelSignIn({AuthorizationCancellation? cancellation}) async {
    if (cancellation?.wasCommitted == true) return;
    _signInGeneration += 1;
    if (cancellation == null) {
      await _repository.cancelSignIn();
    } else {
      cancellation.cancel();
    }
    state = const AuthSessionState.signedOut();
  }

  void _startSignedInSync(String accountId, bool initial) {
    unawaited(_runSignedInSync(accountId, initial));
  }

  Future<void> _runSignedInSync(String accountId, bool initial) async {
    try {
      await _onSignedIn(accountId, initial);
    } on Object catch (error) {
      _logger.warning('Signed-in sync failed: initial=$initial error=$error');
      if (!isMissingOAuthTokenError(error)) {
        return;
      }
      try {
        await _repository.markReconnectRequired(
          accountId,
          authorizationGeneration: failureAuthorizationGeneration(
            error,
            accountId,
          ),
        );
        state = await _repository.loadSession();
        final nextAccountId = state.accountId;
        if (nextAccountId != null &&
            state.isSignedIn &&
            nextAccountId != accountId) {
          _startSignedInSync(nextAccountId, false);
        }
      } on Object catch (cleanupError) {
        _logger.warning(
          'Failed to mark account reconnect required after missing sync token: '
          '$cleanupError',
        );
      }
    }
  }
}

String authErrorMessage(Object error) {
  if (error is DavException) {
    return error.safeMessage;
  }
  if (error is OAuthException) {
    if (_isCallbackFailure(error.code)) {
      if (error.message == microsoftSignInCallbackNotReceivedMessage) {
        return error.message;
      }
      return googleSignInCallbackNotReceivedMessage;
    }
    return error.message;
  }
  if (error is PlatformException) {
    return secretStorageUnavailableMessage;
  }
  if (error is SecretStoreException) return error.message;
  return 'Authorization could not complete. Try again.';
}

bool _isCallbackFailure(String code) {
  return code == 'OAuthCallbackTimeout' ||
      code == 'OAuthCallbackListenerClosed' ||
      code == 'OAuthCallbackStateMismatch' ||
      code == 'OAuthCallbackProviderError' ||
      code == 'OAuthCallbackMissingCode' ||
      code == 'OAuthCallbackInvalidPath' ||
      code == 'OAuthCallbackError';
}
