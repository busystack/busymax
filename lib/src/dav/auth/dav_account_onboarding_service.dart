import 'dart:async';

import 'package:drift/drift.dart';

import '../../core/auth/authorization_persistence.dart';
import '../../features/sync/account_sync_operations.dart';

import 'package:uuid/uuid.dart';

import '../../core/secrets/secret_store.dart';
import '../../db/app_database.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../providers/account_authority.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../discovery/dav_discovery_models.dart';
import '../discovery/dav_discovery_repository.dart';
import '../http/dav_http_transport.dart';
import 'nextcloud_login_flow_v2.dart';

typedef DavOnboardingDiscovery = Future<DavDiscoveryResult> Function({
  required String accountId,
  required BusyProvider provider,
  required Uri accountAuthority,
  required DavBasicCredential credential,
  DavCancellationToken? cancellationToken,
});

typedef NextcloudCredentialRevoker = Future<void> Function({
  required String accountId,
  required NextcloudSecretRecord credential,
});

final class DavAccountConnectionResult {
  const DavAccountConnectionResult({
    required this.accountId,
    required this.discovery,
  });

  final String accountId;
  final DavDiscoveryResult discovery;
}

final class DavAccountRemovalResult {
  const DavAccountRemovalResult({
    required this.remoteRevocationAttempted,
    required this.remoteRevocationSucceeded,
    required this.remoteFailureCode,
  });

  final bool remoteRevocationAttempted;
  final bool remoteRevocationSucceeded;
  final String? remoteFailureCode;
}

final class DavAccountOnboardingService {
  DavAccountOnboardingService({
    required AppDatabase database,
    required SecretStore secretStore,
    required DavOnboardingDiscovery discover,
    required NextcloudLoginFlowV2 nextcloudLoginFlow,
    AccountsRepository? accountsRepository,
    AuthorizationPersistence? authorizationPersistence,
    this.accountGate = const InProcessAccountGate(),
    this.syncCoordinator,
    this.onAccountRemovalStarting,
    this.onAccountRemoving,
    this.persistLinkedAccountRemoval,
    this.onAccountRemovalFailed,
    this.onAccountRemoved,
    this.onAccountRemovalFinished,
    DavDiscoveryRepository? discoveryRepository,
    NextcloudCredentialRevoker? nextcloudCredentialRevoker,
    String Function()? idFactory,
    DateTime Function()? nowUtc,
  }) : _persistence =
           authorizationPersistence ??
           AuthorizationPersistence(database: database, secrets: secretStore),
       _database = database,
       _secretStore = secretStore,
       _discover = discover,
       _nextcloudLoginFlow = nextcloudLoginFlow,
       _accountsRepository =
           accountsRepository ?? AccountsRepository(database: database),
       _discoveryRepository =
           discoveryRepository ?? DavDiscoveryRepository(database: database),
       _nextcloudCredentialRevoker = nextcloudCredentialRevoker,
       _idFactory = idFactory ?? const Uuid().v4,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AuthorizationPersistence _persistence;
  final CrossEngineAccountGate accountGate;
  final AccountSyncCoordinator? syncCoordinator;
  final void Function(String)? onAccountRemovalStarting;
  final Future<void> Function(String)? onAccountRemoving;
  final Future<void> Function(String)? persistLinkedAccountRemoval;
  final Future<void> Function(String)? onAccountRemovalFailed;
  final void Function()? onAccountRemoved;
  final void Function(String)? onAccountRemovalFinished;
  final Map<String, Future<DavAccountRemovalResult>> _removing = {};
  final Map<String, Set<DavCancellationToken>> _accountWork = {};

  Future<T> _serialized<T>(String id, Future<T> Function() work) =>
      accountGate.run(
        id,
        () => syncCoordinator == null ? work() : syncCoordinator!.run(id, work),
      );

  final AppDatabase _database;
  final SecretStore _secretStore;
  final DavOnboardingDiscovery _discover;
  final NextcloudLoginFlowV2 _nextcloudLoginFlow;
  final AccountsRepository _accountsRepository;
  final DavDiscoveryRepository _discoveryRepository;
  final NextcloudCredentialRevoker? _nextcloudCredentialRevoker;
  final String Function() _idFactory;
  final DateTime Function() _nowUtc;

  Future<DavAccountConnectionResult> connectAppleICloud({
    required String email,
    required String appSpecificPassword,
    DavCancellationToken? cancellationToken,
  }) {
    final credential = AppleICloudSecretRecord(
      username: email,
      appSpecificPassword: appSpecificPassword,
    );
    return _connect(
      provider: BusyProvider.appleICloud,
      authority: Uri.parse(appleICloudAccountAuthority),
      providerAccountId: credential.username,
      credential: credential,
      basicCredential: DavBasicCredential(
        username: credential.username,
        password: credential.appSpecificPassword,
      ),
      calendarsEnabled: true,
      tasksEnabled: false,
      email: credential.username,
      displayName: credential.username,
      cancellationToken: cancellationToken,
    );
  }

  Future<DavAccountConnectionResult> connectNextcloud({
    required String enteredServer,
    DavCancellationToken? cancellationToken,
  }) async {
    final login = await _nextcloudLoginFlow.start(
      enteredServer,
      cancellationToken: cancellationToken,
    );
    cancellationToken?.throwIfCancelled();
    return _connectNextcloudLogin(login, cancellationToken: cancellationToken);
  }

  Future<DavAccountConnectionResult> reconnectNextcloud({
    required String accountId,
    required String enteredServer,
    DavCancellationToken? cancellationToken,
  }) async {
    final account = await _accountsRepository.accountById(accountId);
    if (account == null || account.provider != BusyProvider.nextcloud) {
      throw const DavException(
        kind: DavErrorKind.authentication,
        code: 'DavNextcloudAccountUnavailable',
        safeMessage: 'The Nextcloud account could not be reconnected.',
      );
    }
    final generation = await _persistence.generation(accountId);
    final login = await _nextcloudLoginFlow.start(
      enteredServer,
      cancellationToken: cancellationToken,
    );
    cancellationToken?.throwIfCancelled();
    final authority = normalizeAccountAuthority(
      BusyProvider.nextcloud,
      authority: login.canonicalServer.toString(),
    );
    final providerId = normalizeProviderAccountId(
      BusyProvider.nextcloud,
      login.loginName,
    );
    if (authority != account.authority ||
        providerId != account.providerAccountId) {
      throw const DavException(
        kind: DavErrorKind.authentication,
        code: 'DavNextcloudReconnectIdentityMismatch',
        safeMessage: 'Nextcloud returned a different account during reconnect.',
      );
    }
    final result = await _connectNextcloudLogin(
      login,
      cancellationToken: cancellationToken,
      expectedAccountId: accountId,
      expectedGeneration: generation,
    );
    if (result.accountId != accountId) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavNextcloudReconnectAccountMismatch',
        safeMessage: 'The Nextcloud account identity could not be restored.',
      );
    }
    return result;
  }

  Future<DavAccountConnectionResult> _connectNextcloudLogin(
    NextcloudLoginFlowResult login, {
    DavCancellationToken? cancellationToken,
    String? expectedAccountId,
    int? expectedGeneration,
  }) {
    final credential = NextcloudSecretRecord(
      canonicalServer: login.canonicalServer,
      loginName: login.loginName,
      appPassword: login.appPassword,
    );
    return _connect(
      provider: BusyProvider.nextcloud,
      authority: credential.canonicalServer,
      providerAccountId: credential.loginName,
      credential: credential,
      basicCredential: DavBasicCredential(
        username: credential.loginName,
        password: credential.appPassword,
      ),
      calendarsEnabled: true,
      tasksEnabled: true,
      displayName: credential.loginName,
      expectedAccountId: expectedAccountId,
      expectedGeneration: expectedGeneration,
      cancellationToken: cancellationToken,
    );
  }

  void cancelNextcloudLogin() => _nextcloudLoginFlow.cancel();

  Future<DavAccountConnectionResult> replaceAppleAppSpecificPassword({
    required String accountId,
    required String appSpecificPassword,
    DavCancellationToken? cancellationToken,
  }) async {
    final account = await _accountsRepository.accountById(accountId);
    final previous = await _secretStore.readCredential(accountId);
    if (account == null ||
        account.provider != BusyProvider.appleICloud ||
        previous is! AppleICloudSecretRecord) {
      throw const DavException(
        kind: DavErrorKind.authentication,
        code: 'DavAppleAccountUnavailable',
        safeMessage: 'The Apple iCloud account could not be reconnected.',
      );
    }
    final replacement = AppleICloudSecretRecord(
      username: previous.username,
      appSpecificPassword: appSpecificPassword,
    );
    return _connect(
      provider: account.provider,
      authority: Uri.parse(account.authority),
      providerAccountId: account.providerAccountId,
      credential: replacement,
      basicCredential: DavBasicCredential(
        username: replacement.username,
        password: replacement.appSpecificPassword,
      ),
      calendarsEnabled: true,
      tasksEnabled: false,
      displayName: account.displayName ?? replacement.username,
      email: account.email,
      expectedAccountId: accountId,
      expectedGeneration: await _persistence.generation(accountId),
      activateAccount: false,
      cancellationToken: cancellationToken,
    );
  }

  Future<DavAccountRemovalResult> removeAccount(String accountId) {
    final running = _removing[accountId];
    if (running != null) return running;
    for (final token in _accountWork[accountId] ?? <DavCancellationToken>{}) {
      token.cancel();
    }
    onAccountRemovalStarting?.call(accountId);
    late final Future<DavAccountRemovalResult> operation;
    operation =
        _serialized(accountId, () async {
          try {
            return await _persistence.runRemoval(accountId, (snapshot) async {
              final account = await _accountsRepository.accountById(accountId);
              final credential = snapshot.credential;
              // The journal restores the secret and selection if SQLite deletion fails.
              // Revoke only after local commit so a failed removal keeps a usable account.
              await _persistence.removeCoherently(
                accountId,
                () async {},
                () async {
                  await persistLinkedAccountRemoval?.call(accountId);
                  await _accountsRepository.deleteAccount(accountId);
                },
                manageNativeBinding: false,
              );
              onAccountRemoved?.call();
              var attempted = false, succeeded = false;
              String? failureCode;
              if (account?.provider == BusyProvider.nextcloud &&
                  credential is NextcloudSecretRecord &&
                  _nextcloudCredentialRevoker != null) {
                attempted = true;
                try {
                  await _nextcloudCredentialRevoker(
                    accountId: accountId,
                    credential: credential,
                  );
                  succeeded = true;
                } on DavException catch (error) {
                  failureCode = error.code;
                } on Object {
                  failureCode = 'NextcloudAppPasswordRevocationFailed';
                }
              }
              return DavAccountRemovalResult(
                remoteRevocationAttempted: attempted,
                remoteRevocationSucceeded: succeeded,
                remoteFailureCode: failureCode,
              );
            }, prepare: () async => onAccountRemoving?.call(accountId));
          } on Object catch (error, stack) {
            // Preparation itself may have detached a worker before failing.
            try {
              await _persistence.run(accountId, () async {
                if (await _persistence.removalRecoveryAvailable(accountId)) {
                  await onAccountRemovalFailed?.call(accountId);
                }
              });
            } on Object {
              /* retain original failure */
            }
            Error.throwWithStackTrace(error, stack);
          }
        }).whenComplete(() {
          _removing.remove(accountId);
          onAccountRemovalFinished?.call(accountId);
        });
    _removing[accountId] = operation;
    return operation;
  }

  /// Revalidate the saved credential without changing identity or registration.
  /// Discovery must succeed before blocked accounts or queued writes are enabled.
  Future<DavAccountConnectionResult> revalidateAccount(
    String accountId, {
    DavCancellationToken? cancellationToken,
  }) async {
    final account = await _accountsRepository.accountById(accountId);
    final generation = await _persistence.generation(accountId);
    final secret = await _persistence.readCurrentCredential(accountId);
    if (account == null ||
        secret is! NextcloudSecretRecord ||
        account.provider != BusyProvider.nextcloud ||
        secret.canonicalServer.toString() != account.authority ||
        secret.loginName != account.providerAccountId) {
      throw const DavException(
        kind: DavErrorKind.authentication,
        code: 'DavCredentialsRevoked',
        safeMessage: 'Reconnect this account to restore its credential.',
      );
    }
    return _connect(
      provider: account.provider,
      authority: secret.canonicalServer,
      providerAccountId: account.providerAccountId,
      credential: secret,
      basicCredential: DavBasicCredential(
        username: secret.loginName,
        password: secret.appPassword,
      ),
      calendarsEnabled: account.calendarsEnabled,
      tasksEnabled: account.tasksEnabled,
      displayName: account.displayName ?? secret.loginName,
      email: account.email,
      cancellationToken: cancellationToken,
      expectedAccountId: accountId,
      expectedGeneration: generation,
      activateAccount: false,
    );
  }

  Future<DavAccountConnectionResult> _connect({
    required BusyProvider provider,
    required Uri authority,
    required String providerAccountId,
    required SecretRecord credential,
    required DavBasicCredential basicCredential,
    required bool calendarsEnabled,
    required bool tasksEnabled,
    required String displayName,
    String? email,
    String? expectedAccountId,
    int? expectedGeneration,
    bool activateAccount = true,
    DavCancellationToken? cancellationToken,
  }) async {
    final normalizedAuthority = normalizeAccountAuthority(
      provider,
      authority: authority.toString(),
    );
    final normalizedProviderAccountId = normalizeProviderAccountId(
      provider,
      providerAccountId,
    );
    await _persistence.recover();
    cancellationToken?.throwIfCancelled();
    final existing =
        await (_database.select(_database.accounts)..where(
              (row) =>
                  row.provider.equals(provider.storageValue) &
                  row.authority.equals(normalizedAuthority) &
                  row.providerAccountId.equals(normalizedProviderAccountId),
            ))
            .getSingleOrNull();
    if (provider == BusyProvider.nextcloud &&
        expectedAccountId == null &&
        existing != null) {
      throw const DavException(
        kind: DavErrorKind.conflict,
        code: 'DavAccountAlreadyConnected',
        safeMessage:
            'This account is already connected. Use its Reconnect action.',
      );
    }
    final accountId =
        existing?.id ?? '${provider.storageValue}:${_idFactory()}';
    if (expectedAccountId != null && existing?.id != expectedAccountId ||
        _removing.containsKey(accountId)) {
      throw const DavException(
        kind: DavErrorKind.cancelled,
        code: 'DavAccountChanged',
        safeMessage: 'The account changed during connection.',
      );
    }
    final generation =
        expectedGeneration ?? await _persistence.generation(accountId);
    final token = DavCancellationToken();
    final subscription = cancellationToken?.cancellations.listen(
      (_) => token.cancel(),
    );
    if (cancellationToken?.isCancelled == true) token.cancel();
    (_accountWork[accountId] ??= {}).add(token);
    try {
      token.throwIfCancelled();
      final discovery = await _waitForDiscovery(
        _discover(
          accountId: accountId,
          provider: provider,
          accountAuthority: Uri.parse(normalizedAuthority),
          credential: basicCredential,
          cancellationToken: token,
        ),
        token,
      );
      _validateDiscovery(discovery, accountId: accountId, provider: provider);
      var beganCommit = false;
      final committing = _serialized(accountId, () {
        beganCommit = true;
        return _persistence.commit(
          accountId: accountId,
          expectedGeneration: generation,
          candidate: credential,
          requireExisting: existing != null,
          activateAccount: activateAccount,
          validateCandidate: token.throwIfCancelled,
          persistAccount: () async {
            await _accountsRepository.upsertSignedInAccount(
              id: accountId,
              provider: provider,
              providerAccountId: normalizedProviderAccountId,
              authority: normalizedAuthority,
              credentialKind: credential.kind,
              displayName: displayName,
              email: email,
              grantedScopes: '',
              calendarsEnabled: calendarsEnabled,
              tasksEnabled: tasksEnabled,
            );
            await _discoveryRepository.commitSuccessfulInventory(discovery);
            await _requeueAuthenticationBlockedOperations(accountId);
          },
        );
      });
      await Future.any<void>([
        committing,
        token.whenCancelled.then((_) async {
          // Queued work has no durable side effects. Let its caller finish so
          // parent removal can drain contacts without waiting on its own gate.
          if (!beganCommit) token.throwIfCancelled();
          // Once secure persistence starts, wait for its verified rollback or
          // commit. Returning early could let a late secret overwrite recovery.
          await committing;
        }),
      ]);
      // A late cancellation cannot undo the accepted SQLite/credential commit.
      return DavAccountConnectionResult(
        accountId: accountId,
        discovery: discovery,
      );
    } finally {
      await subscription?.cancel();
      _accountWork[accountId]?.remove(token);
      if (_accountWork[accountId]?.isEmpty == true) {
        _accountWork.remove(accountId);
      }
    }
  }

  Future<DavDiscoveryResult> _waitForDiscovery(
    Future<DavDiscoveryResult> discovery,
    DavCancellationToken token,
  ) =>
      Future.any([
        discovery,
        token.whenCancelled.then<DavDiscoveryResult>((_) {
          token.throwIfCancelled();
          throw StateError('Unreachable cancellation');
        }),
      ]).then((result) {
        token.throwIfCancelled();
        return result;
      });

  Future<void> _requeueAuthenticationBlockedOperations(String accountId) async {
    await (_database.update(_database.pendingOps)..where(
          (row) =>
              row.accountId.equals(accountId) &
              row.operationType.like('dav.%') &
              row.state.equals('auth_blocked'),
        ))
        .write(
          PendingOpsCompanion(
            state: const Value('pending'),
            retryClassification: const Value('credential_replaced'),
            attemptCount: const Value(0),
            nextAttemptAtUtc: const Value(null),
            lastErrorCode: const Value(null),
            lastErrorMessage: const Value(null),
            lastError: const Value(null),
            updatedAtUtc: Value(_nowUtc().toUtc().toIso8601String()),
          ),
        );
  }
}

void _validateDiscovery(
  DavDiscoveryResult discovery, {
  required String accountId,
  required BusyProvider provider,
}) {
  if (discovery.accountId != accountId ||
      discovery.provider != provider ||
      !discovery.service.capabilities.hasPrincipal ||
      !discovery.service.capabilities.hasCalendarHome) {
    throw const DavException(
      kind: DavErrorKind.protocol,
      code: 'DavDiscoveryIdentityMismatch',
      safeMessage: 'DAV discovery returned an invalid account identity.',
    );
  }
}
