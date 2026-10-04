import 'dart:convert';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../features/sync/account_sync_operations.dart';
import '../../providers/busy_provider.dart';
import '../secrets/secret_store.dart';
import 'oauth_models.dart';
import 'oauth_registration.dart';

/// Serialized, recoverable boundary for secure storage and account metadata.
/// A normal token refresh leaves authorization generation unchanged.
final class AuthorizationPersistence {
  AuthorizationPersistence({
    required this.database,
    required this.secrets,
    CrossEngineAccountGate? gate,
    this.onCredentialWritten,
    this.readNativeBinding,
    this.restoreNativeBinding,
    this.onRemovalCommitted,
  }) : gate = gate ?? const InProcessAccountGate();
  final Future<void> Function(String id, SecretRecord? record)?
  onCredentialWritten;
  final Future<NativeBindingSnapshot?> Function(String id)? readNativeBinding;
  final Future<void> Function(String id, NativeBindingSnapshot? snapshot)?
  restoreNativeBinding;
  final Future<void> Function(String id, NativeBindingSnapshot? snapshot)?
  onRemovalCommitted;
  final AppDatabase database;
  final SecretStore secrets;
  final CrossEngineAccountGate gate;
  final AccountSyncCoordinator _coordinator = AccountSyncCoordinator();

  Future<T> run<T>(String id, Future<T> Function() operation) =>
      _coordinator.run(id, () => gate.run('authorization:$id', operation));

  Future<bool> wasPreexisting(String id) async =>
      (await (database.select(
        database.oAuthTransitionAccounts,
      )..where((r) => r.accountId.equals(id))).getSingleOrNull()) !=
      null;
  Future<int> generation(String id) async =>
      (await (database.select(
        database.authorizationGenerations,
      )..where((r) => r.accountId.equals(id))).getSingleOrNull())?.generation ??
      0;

  /// Readers use the same serialized boundary as replacement/removal. They
  /// cannot select the temporary secure write before its SQLite commit.
  Future<SecretRecord?> readCurrentCredential(String id) =>
      run(id, () => _readCurrentCredential(id));

  Future<SecretRecord?> _readCurrentCredential(String id) async {
    final record = await secrets.readCredential(id);
    final recordGeneration = switch (record) {
      BoundOAuthSecretRecord() => record.generation,
      NativeOAuthCredential() => record.generation,
      _ => null,
    };
    if (recordGeneration != null && recordGeneration != await generation(id)) {
      throw const OAuthException(
        'OAuthStaleAuthorization',
        'Authorization recovery must complete before this account can be used.',
      );
    }
    return record;
  }

  /// Recovery precedes the boundary. The callback owns it once, including
  /// revocation and local removal; it receives a validated snapshot, no reader.
  Future<T> runRemoval<T>(
    String id,
    Future<T> Function(AuthorizationRemovalSnapshot snapshot) operation,
  ) async {
    await recover();
    return run(id, () async {
      final account = await (database.select(
        database.accounts,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      final provider = account?.provider;
      if (provider == 'google' || provider == 'microsoft') {
        await secrets.migrateLegacyOAuthCredential(
          id,
          provider == 'google' ? BusyProvider.google : BusyProvider.microsoft,
        );
      }
      final snapshot = AuthorizationRemovalSnapshot._(
        id,
        await _readCurrentCredential(id),
      );
      try {
        return await operation(snapshot);
      } finally {
        snapshot._active = false;
      }
    });
  }

  Future<void> recover() async {
    final journals = await database.select(database.authorizationCommits).get();
    for (final pending in journals) {
      await run(pending.accountId, () async {
        final currentJournal =
            await (database.select(database.authorizationCommits)
                  ..where((r) => r.accountId.equals(pending.accountId)))
                .getSingleOrNull();
        if (currentJournal == null) return;
        final journal = currentJournal;
        final recovery = AuthorizationRecoveryState.decode(
          journal.previousNativeBindingJson,
        );
        if (!recovery.committed) {
          if (journal.hadCredential) {
            final backup = await secrets.readCredential(
              _backupKey(journal.accountId),
            );
            if (backup == null) {
              throw const SecretStoreCorruptException(
                'Authorization rollback credential is unavailable.',
              );
            }
            await secrets.saveCredential(journal.accountId, backup);
          } else {
            await secrets.deleteCredential(journal.accountId);
          }
          if (restoreNativeBinding != null) {
            await restoreNativeBinding!(
              journal.accountId,
              recovery.previousNativeBinding,
            );
          } else {
            await onCredentialWritten?.call(
              journal.accountId,
              await secrets.readCredential(journal.accountId),
            );
          }
          await _restoreActive(journal.previousActiveAccountId);
        } else {
          final account = await (database.select(
            database.accounts,
          )..where((r) => r.id.equals(journal.accountId))).getSingleOrNull();
          if (account == null) {
            await onRemovalCommitted?.call(
              journal.accountId,
              recovery.previousNativeBinding,
            );
          }
        }
        await _clearJournal(journal.accountId);
      });
    }
  }

  Future<void> commit({
    required String accountId,
    required int expectedGeneration,
    required SecretRecord candidate,
    required Future<void> Function() persistAccount,
    bool requireExisting = false,
    void Function()? validateCandidate,
    void Function()? onCommitted,
  }) => run(accountId, () async {
    validateCandidate?.call();
    final existingAccount = await (database.select(
      database.accounts,
    )..where((r) => r.id.equals(accountId))).getSingleOrNull();
    if (await generation(accountId) != expectedGeneration ||
        (requireExisting && existingAccount == null) ||
        (!requireExisting && existingAccount != null)) {
      throw const OAuthException(
        'OAuthStaleAuthorization',
        'This account changed while authorization was open. Try again.',
      );
    }
    // Capture the latest accepted record, including refresh-token rotation.
    final previous = await secrets.readCredential(accountId);
    var credential = candidate;
    if (credential is BoundOAuthSecretRecord &&
        !credential.tokenSet.canRefresh) {
      if (previous is BoundOAuthSecretRecord &&
          previous.provider == credential.provider &&
          previous.subject == credential.subject &&
          previous.registration.clientId == credential.registration.clientId &&
          previous.generation == expectedGeneration &&
          previous.tokenSet.canRefresh) {
        credential = credential.withTokens(
          credential.tokenSet.copyWith(
            refreshToken: previous.tokenSet.refreshToken,
          ),
        );
      } else {
        throw const OAuthException(
          'OAuthMissingRefreshToken',
          'This registration needs its own offline authorization. Authorize again.',
        );
      }
    }
    final previousActive = await secrets.readActiveAccountId();
    final nativeSnapshot = await readNativeBinding?.call(accountId);
    if (previous != null) {
      await secrets.saveCredential(_backupKey(accountId), previous);
    }
    await database
        .into(database.authorizationCommits)
        .insertOnConflictUpdate(
          AuthorizationCommitsCompanion.insert(
            accountId: accountId,
            generation: _generation(credential),
            hadCredential: previous != null,
            previousActiveAccountId: Value(previousActive),
            previousNativeBindingJson: Value(
              AuthorizationRecoveryState(
                committed: false,
                previousNativeBinding: nativeSnapshot,
              ).encode(),
            ),
          ),
        );
    try {
      await secrets.saveCredential(accountId, credential);
      final verified = await secrets.readCredential(accountId);
      if (verified == null ||
          jsonEncode(verified.toJson()) != jsonEncode(credential.toJson())) {
        throw const SecretStoreException(
          'SecretStoreWriteVerificationFailed',
          'Credential storage could not be verified.',
        );
      }
      await onCredentialWritten?.call(accountId, credential);
      await secrets.setActiveAccountId(accountId);
      await database.transaction(() async {
        validateCandidate?.call();
        await persistAccount();
        await database
            .into(database.authorizationGenerations)
            .insertOnConflictUpdate(
              AuthorizationGenerationsCompanion.insert(
                accountId: accountId,
                generation: _generation(credential),
              ),
            );
        await database
            .into(database.accountAuthorizations)
            .insertOnConflictUpdate(
              AccountAuthorizationsCompanion.insert(
                accountId: accountId,
                generation: _generation(credential),
                summaryJson: jsonEncode(summaryJson(_summary(credential))),
              ),
            );
        validateCandidate?.call();
        await (database.update(
          database.authorizationCommits,
        )..where((row) => row.accountId.equals(accountId))).write(
          AuthorizationCommitsCompanion(
            previousNativeBindingJson: Value(
              AuthorizationRecoveryState(
                committed: true,
                previousNativeBinding: nativeSnapshot,
              ).encode(),
            ),
          ),
        );
        validateCandidate?.call();
      });
    } on Object {
      // Leave journal intact if rollback fails: restart recovery runs before auth/sync.
      if (previous != null) {
        await secrets.saveCredential(accountId, previous);
      } else {
        await secrets.deleteCredential(accountId);
      }
      if (restoreNativeBinding != null) {
        await restoreNativeBinding!(accountId, nativeSnapshot);
      } else {
        await onCredentialWritten?.call(accountId, previous);
      }
      await _restoreActive(previousActive);
      await _clearJournal(accountId);
      rethrow;
    }
    onCommitted?.call();
    // Cleanup is optional after the durable commit; recovery can finish it.
    try {
      await _clearJournal(accountId);
    } on Object {
      /* retained recovery journal */
    }
  });

  Future<void> writeRefresh(
    String id,
    int expectedGeneration,
    BoundOAuthSecretRecord credential, {
    String? expectedRefreshToken,
  }) => run(id, () async {
    final latest = await secrets.readCredential(id);
    if (await generation(id) != expectedGeneration ||
        latest is! BoundOAuthSecretRecord ||
        latest.generation != expectedGeneration ||
        latest.provider != credential.provider ||
        latest.subject != credential.subject ||
        latest.registration.clientId != credential.registration.clientId ||
        (expectedRefreshToken != null &&
            latest.tokenSet.refreshToken != expectedRefreshToken)) {
      throw const OAuthException(
        'OAuthStaleAuthorization',
        'The authorization changed while a token was refreshing.',
      );
    }
    await secrets.saveCredential(id, credential);
  });

  Future<void> checkTokenCooldown(
    String id,
    String clientId,
    DateTime now,
  ) async {
    final row =
        await (database.select(database.domainSyncSchedules)..where(
              (r) =>
                  r.accountId.equals(id) &
                  r.domain.equals('authorization:$clientId'),
            ))
            .getSingleOrNull();
    final until = DateTime.tryParse(row?.cooldownUntilUtc ?? '');
    if (until != null && until.isAfter(now)) {
      throw OAuthRefreshException(
        'OAuthTokenCooldown',
        'The provider requested a cooldown. Try again later.',
        statusCode: 429,
        retryAfter: until.difference(now),
      );
    }
  }

  Future<void> recordTokenCooldown(
    String id,
    BoundOAuthSecretRecord current,
    OAuthRefreshException error,
    DateTime now,
  ) => recordTokenRequestCooldown(
    id,
    current.generation,
    current.registration.clientId,
    error,
    now,
  );

  /// A request cooldown identifies its destination client, not an inferred
  /// issuer. This also protects the known original-client binding upgrade.
  Future<void> recordTokenRequestCooldown(
    String id,
    int expectedGeneration,
    String requestClientId,
    OAuthRefreshException error,
    DateTime now,
  ) => run(id, () async {
    if (await generation(id) != expectedGeneration ||
        (error.statusCode != 429 && error.statusCode < 500)) {
      return;
    }
    final account = await (database.select(
      database.accounts,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (account == null) return;
    final domain = 'authorization:$requestClientId';
    final row =
        await (database.select(database.domainSyncSchedules)
              ..where((r) => r.accountId.equals(id) & r.domain.equals(domain)))
            .getSingleOrNull();
    var until = now.add(error.retryAfter ?? const Duration(minutes: 1));
    final previous = DateTime.tryParse(row?.cooldownUntilUtc ?? '');
    if (previous != null && previous.isAfter(until)) until = previous;
    await database
        .into(database.domainSyncSchedules)
        .insertOnConflictUpdate(
          DomainSyncSchedulesCompanion.insert(
            accountId: id,
            domain: domain,
            cooldownUntilUtc: Value(until.toIso8601String()),
          ),
        );
  });

  Future<void> invalidate(String id) async {
    await database
        .into(database.authorizationGenerations)
        .insertOnConflictUpdate(
          AuthorizationGenerationsCompanion.insert(
            accountId: id,
            generation: await generation(id) + 1,
          ),
        );
  }

  Future<void> remove(String id, Future<void> Function() operation) =>
      run(id, operation);

  /// Caller already owns the serialized account boundary. A removal journal
  /// survives a crash between secure cleanup and SQLite deletion. Native
  /// cache removal happens only after deletion commits: its grant cannot be
  /// restored by a secure-record rollback.
  Future<void> removeCoherently(
    String id,
    Future<void> Function() clearAuthorization,
    Future<void> Function() deleteAccount,
  ) async {
    final previous = await secrets.readCredential(id);
    final active = await secrets.readActiveAccountId();
    final nativeSnapshot = await readNativeBinding?.call(id);
    final nextGeneration = await generation(id) + 1;
    if (previous != null) {
      await secrets.saveCredential(_backupKey(id), previous);
    }
    await database
        .into(database.authorizationCommits)
        .insertOnConflictUpdate(
          AuthorizationCommitsCompanion.insert(
            accountId: id,
            generation: nextGeneration,
            hadCredential: previous != null,
            previousActiveAccountId: Value(active),
            previousNativeBindingJson: Value(
              AuthorizationRecoveryState(
                committed: false,
                previousNativeBinding: nativeSnapshot,
              ).encode(),
            ),
          ),
        );
    try {
      await secrets.deleteCredential(id);
      if (active == id) await secrets.clearActiveAccount();
      await database.transaction(() async {
        await invalidate(id);
        await deleteAccount();
        await (database.update(
          database.authorizationCommits,
        )..where((row) => row.accountId.equals(id))).write(
          AuthorizationCommitsCompanion(
            previousNativeBindingJson: Value(
              AuthorizationRecoveryState(
                committed: true,
                previousNativeBinding: nativeSnapshot,
              ).encode(),
            ),
          ),
        );
      });
    } on Object {
      if (previous != null) {
        await secrets.saveCredential(id, previous);
      } else {
        await secrets.deleteCredential(id);
      }
      if (restoreNativeBinding != null) {
        await restoreNativeBinding!(id, nativeSnapshot);
      } else {
        await onCredentialWritten?.call(id, previous);
      }
      await _restoreActive(active);
      await _clearJournal(id);
      rethrow;
    }
    // Failed native cleanup retains the journal for retry on restart. Account
    // deletion and generation invalidation are already durable.
    if (onRemovalCommitted != null) {
      await onRemovalCommitted!(id, nativeSnapshot);
    } else {
      await clearAuthorization();
    }
    try {
      await _clearJournal(id);
    } on Object {
      /* recovered on restart */
    }
  }

  Future<void> _restoreActive(String? id) => id == null
      ? secrets.clearActiveAccount()
      : secrets.setActiveAccountId(id);
  Future<void> _clearJournal(String id) async {
    // Delete the journal first. An orphan backup cannot affect live credentials.
    await (database.delete(
      database.authorizationCommits,
    )..where((r) => r.accountId.equals(id))).go();
    await secrets.deleteCredential(_backupKey(id));
  }

  String _backupKey(String id) => 'busymax.authorization.rollback:$id';
}

/// Issued only inside runRemoval. It cannot be used as an unlocked reader or
/// after the operation releases the account boundary.
final class AuthorizationRemovalSnapshot {
  AuthorizationRemovalSnapshot._(this.accountId, this._credential);
  final String accountId;
  final SecretRecord? _credential;
  bool _active = true;
  SecretRecord? get credential {
    if (!_active) throw StateError('The removal boundary was released.');
    return _credential;
  }
}

/// Versioned non-secret recovery receipt. Its committed flag is written in the
/// same SQLite transaction as account metadata, independently of auth generation.
final class AuthorizationRecoveryState {
  const AuthorizationRecoveryState({
    required this.committed,
    this.previousNativeBinding,
  });
  final bool committed;
  final NativeBindingSnapshot? previousNativeBinding;
  String encode() => jsonEncode({
    'version': 1,
    'committed': committed,
    'previousNativeBinding': previousNativeBinding?.toJson(),
  });
  factory AuthorizationRecoveryState.decode(String? serialized) {
    try {
      final value = jsonDecode(serialized!) as Map<String, dynamic>;
      if (value['version'] != 1 || value['committed'] is! bool) {
        throw const FormatException();
      }
      final binding = value['previousNativeBinding'];
      return AuthorizationRecoveryState(
        committed: value['committed'] as bool,
        previousNativeBinding: binding == null
            ? null
            : NativeBindingSnapshot.fromJson(binding as Map<String, dynamic>),
      );
    } on Object {
      throw const SecretStoreCorruptException(
        'Authorization recovery state is invalid. Records are preserved.',
      );
    }
  }
}

Map<String, Object?> summaryJson(RegistrationSummary summary) => {
  'provider': summary.provider.storageValue,
  'platform': summary.platform.name,
  'origin': summary.origin.name,
  'clientId': summary.clientId,
  if (summary.projectId != null) 'projectId': summary.projectId,
  if (summary.authority != null) 'authority': summary.authority,
  'transitionEligible': summary.transitionEligible,
};

RegistrationSummary? decodeRegistrationSummary(String? serialized) {
  if (serialized == null) return null;
  try {
    final json = jsonDecode(serialized) as Map<String, dynamic>;
    return RegistrationSummary(
      provider: BusyProviderCodec.requireStorageValue(
        json['provider'] as String,
      ),
      platform: AuthenticationPlatform.values.byName(
        json['platform'] as String,
      ),
      origin: RegistrationOrigin.values.byName(json['origin'] as String),
      clientId: json['clientId'] as String,
      projectId: json['projectId'] as String?,
      authority: json['authority'] as String?,
      transitionEligible: json['transitionEligible'] == true,
    );
  } on Object {
    return null;
  }
}

int _generation(SecretRecord record) => switch (record) {
  BoundOAuthSecretRecord() => record.generation,
  NativeOAuthCredential() => record.generation,
  _ => throw const SecretStoreCorruptException('Credential is not bound.'),
};
RegistrationSummary _summary(SecretRecord record) => switch (record) {
  BoundOAuthSecretRecord() => record.registration.summary(
    transitionEligible: record.transitionEligible,
  ),
  NativeOAuthCredential() => record.summary,
  _ => throw const SecretStoreCorruptException('Credential is not bound.'),
};
