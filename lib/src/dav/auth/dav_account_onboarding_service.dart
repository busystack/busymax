import 'package:drift/drift.dart';
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

typedef DavOnboardingDiscovery =
    Future<DavDiscoveryResult> Function({
      required String accountId,
      required BusyProvider provider,
      required Uri accountAuthority,
      required DavBasicCredential credential,
      DavCancellationToken? cancellationToken,
    });

typedef NextcloudCredentialRevoker =
    Future<void> Function({
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
    DavDiscoveryRepository? discoveryRepository,
    NextcloudCredentialRevoker? nextcloudCredentialRevoker,
    String Function()? idFactory,
    DateTime Function()? nowUtc,
  }) : _database = database,
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
    final login = await _nextcloudLoginFlow.start(enteredServer);
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
    final login = await _nextcloudLoginFlow.start(enteredServer);
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
    final discovery = await _discover(
      accountId: accountId,
      provider: BusyProvider.appleICloud,
      accountAuthority: Uri.parse(appleICloudAccountAuthority),
      credential: DavBasicCredential(
        username: replacement.username,
        password: replacement.appSpecificPassword,
      ),
      cancellationToken: cancellationToken,
    );
    _validateDiscovery(
      discovery,
      accountId: accountId,
      provider: BusyProvider.appleICloud,
    );
    await _replaceCredentialVerified(accountId, replacement, previous);
    try {
      await _database.transaction(() async {
        await _accountsRepository.upsertSignedInAccount(
          id: accountId,
          provider: BusyProvider.appleICloud,
          providerAccountId: account.providerAccountId,
          authority: appleICloudAccountAuthority,
          credentialKind: CredentialKind.appleAppSpecificPassword,
          displayName: account.displayName,
          email: account.email,
          grantedScopes: '',
          calendarsEnabled: true,
          tasksEnabled: false,
        );
        await _discoveryRepository.commitSuccessfulInventory(discovery);
        await _requeueAuthenticationBlockedOperations(accountId);
      });
      return DavAccountConnectionResult(
        accountId: accountId,
        discovery: discovery,
      );
    } on Object {
      await _secretStore.saveCredential(accountId, previous);
      rethrow;
    }
  }

  Future<DavAccountRemovalResult> removeAccount(String accountId) async {
    final account = await _accountsRepository.accountById(accountId);
    if (account == null) {
      return const DavAccountRemovalResult(
        remoteRevocationAttempted: false,
        remoteRevocationSucceeded: false,
        remoteFailureCode: null,
      );
    }
    final credential = await _secretStore.readCredential(accountId);
    var attempted = false;
    var succeeded = false;
    String? failureCode;
    if (account.provider == BusyProvider.nextcloud &&
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

    // Local removal is deliberately independent of remote revocation success.
    await _secretStore.deleteCredential(accountId);
    if (await _secretStore.readActiveAccountId() == accountId) {
      await _secretStore.clearActiveAccount();
    }
    await _accountsRepository.deleteAccount(accountId);
    return DavAccountRemovalResult(
      remoteRevocationAttempted: attempted,
      remoteRevocationSucceeded: succeeded,
      remoteFailureCode: failureCode,
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
    final existing =
        await (_database.select(_database.accounts)..where(
              (row) =>
                  row.provider.equals(provider.storageValue) &
                  row.authority.equals(normalizedAuthority) &
                  row.providerAccountId.equals(normalizedProviderAccountId),
            ))
            .getSingleOrNull();
    final accountId =
        existing?.id ?? '${provider.storageValue}:${_idFactory()}';
    final previousCredential = existing == null
        ? null
        : await _secretStore.readCredential(accountId);

    // No durable credential or connected account state is written until the
    // supplied credential has completed principal/home/collection discovery.
    final discovery = await _discover(
      accountId: accountId,
      provider: provider,
      accountAuthority: Uri.parse(normalizedAuthority),
      credential: basicCredential,
      cancellationToken: cancellationToken,
    );
    _validateDiscovery(discovery, accountId: accountId, provider: provider);
    await _replaceCredentialVerified(accountId, credential, previousCredential);
    try {
      await _database.transaction(() async {
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
      });
      await _secretStore.setActiveAccountId(accountId);
      return DavAccountConnectionResult(
        accountId: accountId,
        discovery: discovery,
      );
    } on Object {
      if (previousCredential != null) {
        await _secretStore.saveCredential(accountId, previousCredential);
      } else {
        await _secretStore.deleteCredential(accountId);
        await _accountsRepository.deleteAccount(accountId);
      }
      rethrow;
    }
  }

  Future<void> _replaceCredentialVerified(
    String accountId,
    SecretRecord replacement,
    SecretRecord? previous,
  ) async {
    await _secretStore.saveCredential(accountId, replacement);
    try {
      final readBack = await _secretStore.readCredential(accountId);
      if (!_sameCredential(readBack, replacement)) {
        throw const SecretStoreException(
          'SecretStoreWriteVerificationFailed',
          'The credential could not be verified after secure storage.',
        );
      }
    } on Object {
      if (previous != null) {
        await _secretStore.saveCredential(accountId, previous);
      } else {
        await _secretStore.deleteCredential(accountId);
      }
      rethrow;
    }
  }

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

bool _sameCredential(SecretRecord? left, SecretRecord right) =>
    switch ((left, right)) {
      (
        AppleICloudSecretRecord(
          username: final leftUser,
          appSpecificPassword: final leftPassword,
        ),
        AppleICloudSecretRecord(
          username: final rightUser,
          appSpecificPassword: final rightPassword,
        ),
      ) =>
        leftUser == rightUser && leftPassword == rightPassword,
      (
        NextcloudSecretRecord(
          canonicalServer: final leftServer,
          loginName: final leftUser,
          appPassword: final leftPassword,
        ),
        NextcloudSecretRecord(
          canonicalServer: final rightServer,
          loginName: final rightUser,
          appPassword: final rightPassword,
        ),
      ) =>
        leftServer == rightServer &&
            leftUser == rightUser &&
            leftPassword == rightPassword,
      _ => false,
    };
