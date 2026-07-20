import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/logging/redacting_logger.dart';
import '../../../db/app_database.dart';
import '../../../features/accounts/data/accounts_repository.dart';
import '../../../google_tasks/api/google_tasks_api_surface.dart';
import '../../../google_tasks/oauth/oauth_loopback_flow.dart';
import '../../../google_tasks/oauth/oauth_models.dart';
import '../../../google_tasks/oauth/oauth_service.dart';
import '../../../google_tasks/oauth/oauth_token_store.dart';
import '../../../microsoft_todo/oauth/microsoft_oauth_service.dart';
import '../../sync/sync_auth_error.dart';
import '../../../task_providers/task_provider.dart';

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

  const AuthSessionState.error(String message)
    : this._(status: AuthSessionStatus.error, message: message);

  final AuthSessionStatus status;
  final String? accountId;
  final String? message;

  bool get isSignedIn => status == AuthSessionStatus.signedIn;
}

class AuthRepository {
  AuthRepository({
    required OAuthGateway oAuth,
    required AppDatabase database,
    AccountsRepository? accountsRepository,
    MicrosoftOAuthService? microsoftOAuth,
    DateTime Function()? nowUtc,
  }) : _oAuth = oAuth,
       _database = database,
       _accountsRepository =
           accountsRepository ??
           AccountsRepository(database: database, nowUtc: nowUtc),
       _microsoftOAuth = microsoftOAuth;

  final OAuthGateway _oAuth;
  final AppDatabase _database;
  final AccountsRepository _accountsRepository;
  final MicrosoftOAuthService? _microsoftOAuth;

  Future<AuthSessionState> loadSession() async {
    final accounts = await _accountsRepository.listSignedInAccounts();
    if (accounts.isEmpty) {
      return const AuthSessionState.signedOut();
    }

    return AuthSessionState.signedIn(accounts.first.id);
  }

  Future<AuthSessionState> signIn() async {
    final result = await _oAuth.signIn();
    final missingScopes = _missingRequiredGoogleApiScopes(result.tokenSet);
    if (missingScopes.isNotEmpty) {
      await _oAuth.revokeAndSignOutAccount(result.accountId);
      throw OAuthException(
        'OAuthMissingRequiredScope',
        _googleMissingScopesMessage(missingScopes),
      );
    }

    await _upsertGoogleSignedInAccount(result.accountId, result.tokenSet);
    return AuthSessionState.signedIn(result.accountId);
  }

  Future<AuthSessionState> signInWithMicrosoft() async {
    final microsoftOAuth = _microsoftOAuth;
    if (microsoftOAuth == null) {
      throw const OAuthException(
        'MicrosoftOAuthUnavailable',
        'Microsoft sign-in is not available.',
      );
    }
    final result = await microsoftOAuth.signIn();
    if (!_hasRequiredMicrosoftScopes(result.tokenSet)) {
      await microsoftOAuth.signOutAccount(result.accountId);
      throw const OAuthException(
        'MicrosoftOAuthMissingRequiredScope',
        'Required Microsoft To Do permission was not granted.',
      );
    }

    await _accountsRepository.upsertSignedInAccount(
      id: result.accountId,
      provider: TaskProvider.microsoft,
      providerAccountId: result.user.id,
      displayName: result.user.displayName,
      email: result.user.mail ?? result.user.userPrincipalName,
      grantedScopes: result.tokenSet.scopes.join(' '),
      providerMetadata: result.user.rawJson,
    );
    return AuthSessionState.signedIn(result.accountId);
  }

  Future<void> signOut({String? accountId}) async {
    final targetAccountId = accountId ?? await _oAuth.activeAccountId;
    if (targetAccountId == null) {
      return;
    }
    await _deactivateAccount(targetAccountId, reconnectRequired: false);
    if (targetAccountId.startsWith('microsoft:')) {
      await _microsoftOAuth?.signOutAccount(targetAccountId);
    } else {
      await _oAuth.signOutAccount(targetAccountId);
    }
  }

  Future<void> markReconnectRequired(String accountId) async {
    await _deactivateAccount(accountId, reconnectRequired: true);
    if (accountId.startsWith('microsoft:')) {
      await _microsoftOAuth?.signOutAccount(accountId);
    } else {
      await _oAuth.signOutAccount(accountId);
    }
  }

  Future<void> revokeAndSignOut({String? accountId}) async {
    final targetAccountId = accountId ?? await _oAuth.activeAccountId;
    if (targetAccountId == null) {
      return;
    }
    await _deactivateAccount(targetAccountId, reconnectRequired: false);
    if (targetAccountId.startsWith('microsoft:')) {
      await _microsoftOAuth?.signOutAccount(targetAccountId);
    } else {
      await _oAuth.revokeAndSignOutAccount(targetAccountId);
    }
  }

  Future<void> deleteLocalAccountData({String? accountId}) async {
    final targetAccountId = accountId ?? await _oAuth.activeAccountId;
    if (targetAccountId == null) {
      return;
    }

    await _database.transaction(() async {
      await _deleteScheduledNotifications(targetAccountId);
      await (_database.delete(
        _database.accounts,
      )..where((row) => row.id.equals(targetAccountId))).go();
    });

    if (targetAccountId.startsWith('microsoft:')) {
      await _microsoftOAuth?.signOutAccount(targetAccountId);
    } else {
      await _oAuth.signOutAccount(targetAccountId);
    }
  }

  Future<void> _deactivateAccount(
    String accountId, {
    required bool reconnectRequired,
  }) {
    return _database.transaction(() async {
      if (reconnectRequired) {
        await _accountsRepository.markReconnectRequired(accountId);
      } else {
        await _accountsRepository.markSignedOut(accountId);
      }
      await _deleteScheduledNotifications(accountId);
    });
  }

  Future<void> _deleteScheduledNotifications(String accountId) {
    return (_database.delete(
      _database.notificationSchedule,
    )..where((row) => row.accountId.equals(accountId))).go();
  }

  Future<void> cancelSignIn() async {
    await _oAuth.cancelSignIn();
    await _microsoftOAuth?.cancelSignIn();
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
    return tokenSet.scopes.contains('https://graph.microsoft.com/User.Read') &&
        tokenSet.scopes.contains(
          'https://graph.microsoft.com/Tasks.ReadWrite',
        ) &&
        tokenSet.scopes.contains(
          'https://graph.microsoft.com/Calendars.ReadWrite',
        );
  }

  Future<void> _upsertGoogleSignedInAccount(
    String accountId,
    OAuthTokenSet tokenSet,
  ) async {
    final existing = await _accountsRepository.accountById(accountId);
    final idTokenClaims = googleIdTokenClaims(tokenSet);
    final userInfo = await _fetchGoogleUserInfo(tokenSet);
    await _accountsRepository.upsertSignedInAccount(
      id: accountId,
      provider: TaskProvider.google,
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
      state = AuthSessionState.error(authErrorMessage(error));
    }
  }

  Future<void> signIn() async {
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
      final signedIn = await _repository.signIn();
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
      state = AuthSessionState.error(authErrorMessage(error));
    }
  }

  Future<void> signInWithMicrosoft() async {
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
      final signedIn = await _repository.signInWithMicrosoft();
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
      state = AuthSessionState.error(authErrorMessage(error));
    }
  }

  Future<void> revokeAndSignOut() async {
    await _repository.revokeAndSignOut(accountId: state.accountId);
    state = const AuthSessionState.signedOut();
  }

  Future<void> signOut() async {
    await _repository.signOut(accountId: state.accountId);
    state = const AuthSessionState.signedOut();
  }

  Future<void> deleteLocalAccountData() async {
    await _repository.deleteLocalAccountData(accountId: state.accountId);
    state = const AuthSessionState.signedOut();
  }

  Future<void> cancelSignIn() async {
    _signInGeneration += 1;
    await _repository.cancelSignIn();
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
        await _repository.markReconnectRequired(accountId);
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
    return secureTokenStorageUnavailableMessage;
  }
  return error.toString();
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
