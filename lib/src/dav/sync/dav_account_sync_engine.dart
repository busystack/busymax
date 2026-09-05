import 'dart:async';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/secrets/secret_store.dart';
import '../../db/app_database.dart';
import '../../features/accounts/domain/account_connection_state.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../dav_provider_profile.dart';
import '../discovery/dav_discovery_repository.dart';
import '../discovery/dav_discovery_service.dart';
import '../http/dav_http_transport.dart';
import '../mutation/dav_conditional_mutation_service.dart';
import '../mutation/dav_pending_operations.dart';
import '../storage/dav_object_repository.dart';
import 'dav_collection_remote_client.dart';
import 'dav_sync_engine.dart';

final class DavAccountSyncPolicy {
  const DavAccountSyncPolicy({
    this.discoveryMaxAge = const Duration(hours: 24),
    this.inventoryMaxAge = const Duration(hours: 1),
    this.maximumConcurrentCollections = 2,
  }) : assert(maximumConcurrentCollections > 0);

  final Duration discoveryMaxAge;
  final Duration inventoryMaxAge;
  final int maximumConcurrentCollections;
}

final class DavAccountSyncResult {
  const DavAccountSyncResult({
    required this.discoveryRefreshed,
    required this.collectionsSynchronized,
    required this.pendingOperationsApplied,
    required this.conflictsCreated,
    required this.followUpCollectionsSynchronized,
    required this.affectedObjectIds,
  });

  final bool discoveryRefreshed;
  final int collectionsSynchronized;
  final int pendingOperationsApplied;
  final int conflictsCreated;
  final int followUpCollectionsSynchronized;
  final Set<String> affectedObjectIds;
}

final class DavAccountSyncException implements Exception {
  DavAccountSyncException(Iterable<DavException> failures)
    : failures = List.unmodifiable(failures);

  final List<DavException> failures;

  @override
  String toString() =>
      'DavAccountSyncException(codes: '
      '${failures.map((failure) => failure.code).join(',')})';
}

/// Coordinates discovery, synchronization, pending writes, and notification
/// rebuilds for one DAV account.
final class DavAccountSyncEngine {
  DavAccountSyncEngine({
    required AppDatabase database,
    required SecretStore secretStore,
    required http.Client httpClient,
    required String accountId,
    DavAccountSyncPolicy policy = const DavAccountSyncPolicy(),
    DavTransportLimits transportLimits = const DavTransportLimits(),
    DavSyncLimits syncLimits = const DavSyncLimits(),
    Future<void> Function(String accountId, Set<String> affectedObjectIds)?
    rebuildNotifications,
    Future<void> Function(String accountId, DavException error)?
    reportPendingMutationFailure,
    DateTime Function()? nowUtc,
    String Function()? correlationIdFactory,
  }) : _database = database,
       _secretStore = secretStore,
       _httpClient = httpClient,
       _accountId = accountId,
       _policy = policy,
       _transportLimits = transportLimits,
       _syncLimits = syncLimits,
       _rebuildNotifications = rebuildNotifications,
       _reportPendingMutationFailure = reportPendingMutationFailure,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _correlationIdFactory = correlationIdFactory ?? const Uuid().v4;

  final AppDatabase _database;
  final SecretStore _secretStore;
  final http.Client _httpClient;
  final String _accountId;
  final DavAccountSyncPolicy _policy;
  final DavTransportLimits _transportLimits;
  final DavSyncLimits _syncLimits;
  final Future<void> Function(String, Set<String>)? _rebuildNotifications;
  final Future<void> Function(String, DavException)?
  _reportPendingMutationFailure;
  final DateTime Function() _nowUtc;
  final String Function() _correlationIdFactory;

  Future<DavAccountSyncResult>? _activeSync;

  Future<DavAccountSyncResult> synchronize({
    bool full = false,
    DavCancellationToken? cancellationToken,
  }) {
    if (_activeSync != null) return _activeSync!;
    final operation = _synchronize(
      full: full,
      cancellationToken: cancellationToken ?? DavCancellationToken(),
    );
    _activeSync = operation;
    unawaited(
      operation.then<void>(
        (_) => _clearActive(operation),
        onError: (_, _) => _clearActive(operation),
      ),
    );
    return operation;
  }

  Future<DavAccountSyncResult> _synchronize({
    required bool full,
    required DavCancellationToken cancellationToken,
  }) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).getSingleOrNull();
    if (account == null) {
      throw const DavException(
        kind: DavErrorKind.notFound,
        code: 'DavAccountRemoved',
        safeMessage: 'The DAV account is no longer available.',
      );
    }
    final provider = BusyProviderCodec.requireStorageValue(account.provider);
    if (provider != BusyProvider.appleICloud &&
        provider != BusyProvider.nextcloud) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavUnsupportedAccountProvider',
        safeMessage: 'This account does not use the DAV transport.',
      );
    }
    late final _DavCredentialContext loaded;
    try {
      loaded = await _loadCredential(account, provider);
    } on SecretStoreException catch (error) {
      final mapped = _mapSecretStoreFailure(error);
      await _setConnectionState(
        _requiresReconnect(mapped)
            ? AccountConnectionState.reauthenticationRequired
            : AccountConnectionState.temporarilyUnavailable,
      );
      throw mapped;
    }
    final profile = davProviderProfile(
      provider,
      nextcloudServer: provider == BusyProvider.nextcloud
          ? loaded.authority
          : null,
    );
    final transport = DavHttpTransport(
      client: _httpClient,
      profile: profile,
      accountAuthority: loaded.authority,
      limits: _transportLimits,
    );
    final objectRepository = DavObjectRepository(database: _database);
    final discoveryRepository = DavDiscoveryRepository(database: _database);
    var discoveryRefreshed = false;
    var notificationProjectionsChanged = false;
    final affected = <String>{};
    final failures = <DavException>[];

    try {
      cancellationToken.throwIfCancelled();
      if (full || await _discoveryIsDue()) {
        discoveryRefreshed = true;
        final discovery =
            await DavDiscoveryService(
              transport: transport,
              profile: profile,
              accountAuthority: loaded.authority,
              accountId: _accountId,
              credential: loaded.basic,
              nowUtc: _nowUtc,
            ).discover(
              correlationId: _correlationIdFactory(),
              cancellationToken: cancellationToken,
            );
        notificationProjectionsChanged = await discoveryRepository
            .commitSuccessfulInventory(discovery);
      }

      final collections = await _selectedCollections();
      final initialResults = await _synchronizeCollections(
        collections,
        provider: provider,
        profile: profile,
        authority: loaded.authority,
        credential: loaded.basic,
        transport: transport,
        objectRepository: objectRepository,
        forceRebaseline: full,
        cancellationToken: cancellationToken,
      );
      for (final result in initialResults.results) {
        affected.addAll(result.affectedObjectIds);
      }
      failures.addAll(initialResults.failures);

      final hasBlockingFailure = failures.any(
        (failure) => switch (failure.category) {
          DavErrorCategory.davAuthRejected ||
          DavErrorCategory.davCredentialsRevoked ||
          DavErrorCategory.davPermissionDenied ||
          DavErrorCategory.davReadOnly => true,
          _ => false,
        },
      );
      DavReplaySummary replay = const DavReplaySummary(
        appliedCount: 0,
        conflictCount: 0,
        retryCount: 0,
        mutatedCollectionIds: {},
        affectedObjectIds: {},
        paused: false,
      );
      if (!hasBlockingFailure) {
        replay = await DavPendingOperationsReplayer(
          database: _database,
          accountId: _accountId,
          objectRepository: objectRepository,
          nowUtc: _nowUtc,
          idFactory: _correlationIdFactory,
          onPermanentFailure: (operation, error) async {
            await _reportPendingMutationFailure?.call(_accountId, error);
          },
          serviceFactory: ({required account, required collection}) async =>
              DavConditionalMutationService(
                remoteClient: DavMutationHttpClient(
                  transport: transport,
                  accountId: _accountId,
                  collectionId: collection.id,
                  credential: loaded.basic,
                ),
                nowUtc: _nowUtc,
              ),
        ).replayDueOperations();
        affected.addAll(replay.affectedObjectIds);
      }

      var followUpCount = 0;
      if (!replay.paused && replay.mutatedCollectionIds.isNotEmpty) {
        final currentById = {
          for (final collection in await _selectedCollections())
            collection.id: collection,
        };
        final followUp = <DavCollection>[
          for (final id in replay.mutatedCollectionIds)
            if (currentById[id] != null) currentById[id]!,
        ];
        final followUpResults = await _synchronizeCollections(
          followUp,
          provider: provider,
          profile: profile,
          authority: loaded.authority,
          credential: loaded.basic,
          transport: transport,
          objectRepository: objectRepository,
          forceRebaseline: false,
          cancellationToken: cancellationToken,
        );
        followUpCount = followUpResults.results.length;
        for (final result in followUpResults.results) {
          affected.addAll(result.affectedObjectIds);
        }
        failures.addAll(followUpResults.failures);
      }

      if (affected.isNotEmpty || notificationProjectionsChanged) {
        await _rebuildNotifications?.call(_accountId, affected);
      }
      if (failures.isNotEmpty) {
        await _recordFailureState(failures.first, discoveryRepository);
        throw DavAccountSyncException(failures);
      }
      if (!replay.paused) {
        await _markSuccessful(full: full);
      }
      return DavAccountSyncResult(
        discoveryRefreshed: discoveryRefreshed,
        collectionsSynchronized: initialResults.results.length,
        pendingOperationsApplied: replay.appliedCount,
        conflictsCreated: replay.conflictCount,
        followUpCollectionsSynchronized: followUpCount,
        affectedObjectIds: Set.unmodifiable(affected),
      );
    } on DavAccountSyncException {
      rethrow;
    } on DavException catch (error) {
      await _recordFailureState(error, discoveryRepository);
      rethrow;
    } on SecretStoreException catch (error) {
      final mapped = _mapSecretStoreFailure(error);
      await _setConnectionState(
        _requiresReconnect(mapped)
            ? AccountConnectionState.reauthenticationRequired
            : AccountConnectionState.temporarilyUnavailable,
      );
      throw mapped;
    }
  }

  Future<_DavCredentialContext> _loadCredential(
    Account account,
    BusyProvider provider,
  ) async {
    final secret = await _secretStore.readCredential(_accountId);
    if (provider == BusyProvider.appleICloud &&
        secret is AppleICloudSecretRecord) {
      if (secret.username != account.providerAccountId) {
        throw SecretStoreCredentialMismatchException(
          accountId: _accountId,
          expectedProvider: provider,
          actualProvider: secret.provider,
          actualKind: secret.kind,
        );
      }
      return _DavCredentialContext(
        authority: Uri.parse(account.authority),
        basic: DavBasicCredential(
          username: secret.username,
          password: secret.appSpecificPassword,
        ),
      );
    }
    if (provider == BusyProvider.nextcloud && secret is NextcloudSecretRecord) {
      final authority = Uri.parse(account.authority);
      if (secret.canonicalServer != authority ||
          secret.loginName != account.providerAccountId) {
        throw SecretStoreCredentialMismatchException(
          accountId: _accountId,
          expectedProvider: provider,
          actualProvider: secret.provider,
          actualKind: secret.kind,
        );
      }
      return _DavCredentialContext(
        authority: authority,
        basic: DavBasicCredential(
          username: secret.loginName,
          password: secret.appPassword,
        ),
      );
    }
    await _setConnectionState(AccountConnectionState.reauthenticationRequired);
    throw const DavException(
      kind: DavErrorKind.authentication,
      code: 'DavCredentialsRevoked',
      safeMessage: 'The DAV account credential is unavailable.',
    );
  }

  DavException _mapSecretStoreFailure(SecretStoreException error) {
    if (error.code == 'SecretStoreUnavailable') {
      return DavException(
        kind: DavErrorKind.network,
        code: 'DavCredentialStoreUnavailable',
        safeMessage: error.message,
      );
    }
    return const DavException(
      kind: DavErrorKind.authentication,
      code: 'DavCredentialsRevoked',
      safeMessage: 'The DAV account credential is unavailable or invalid.',
    );
  }

  Future<bool> _discoveryIsDue() async {
    final service = await (_database.select(
      _database.davAccountServices,
    )..where((row) => row.accountId.equals(_accountId))).getSingleOrNull();
    if (service == null ||
        service.providerProfileVersion != davProviderProfileVersion ||
        service.lastDiscoveryErrorCode != null) {
      return true;
    }
    final validated = DateTime.tryParse(
      service.lastValidatedAtUtc ?? service.discoveredAtUtc,
    )?.toUtc();
    if (validated == null ||
        _nowUtc().toUtc().difference(validated) >= _policy.discoveryMaxAge) {
      return true;
    }
    final collections = await (_database.select(
      _database.davCollections,
    )..where((row) => row.accountId.equals(_accountId))).get();
    if (collections.isEmpty) return true;
    final oldestInventory = collections
        .map(
          (collection) =>
              DateTime.tryParse(collection.lastInventoryAtUtc ?? ''),
        )
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (oldest, value) =>
              oldest == null || value.isBefore(oldest) ? value : oldest,
        );
    return oldestInventory == null ||
        _nowUtc().toUtc().difference(oldestInventory.toUtc()) >=
            _policy.inventoryMaxAge;
  }

  Future<List<DavCollection>> _selectedCollections() {
    return (_database.select(_database.davCollections)..where(
          (row) =>
              row.accountId.equals(_accountId) &
              row.deleted.equals(false) &
              row.serverMissing.equals(false) &
              ((row.eventProjectionEnabled.equals(true) &
                      row.eventsSelected.equals(true)) |
                  (row.taskProjectionEnabled.equals(true) &
                      row.tasksSelected.equals(true))),
        ))
        .get();
  }

  Future<_CollectionBatchResult> _synchronizeCollections(
    List<DavCollection> collections, {
    required BusyProvider provider,
    required DavProviderProfile profile,
    required Uri authority,
    required DavBasicCredential credential,
    required DavHttpTransport transport,
    required DavObjectRepository objectRepository,
    required bool forceRebaseline,
    required DavCancellationToken cancellationToken,
  }) async {
    if (collections.isEmpty) return const _CollectionBatchResult();
    var nextIndex = 0;
    final results = <DavCollectionSyncResult>[];
    final failures = <DavException>[];

    Future<void> worker() async {
      while (true) {
        cancellationToken.throwIfCancelled();
        if (nextIndex >= collections.length) return;
        final collection = collections[nextIndex];
        nextIndex += 1;
        try {
          final remote = DavCollectionHttpClient(
            transport: transport,
            profile: profile,
            accountAuthority: authority,
            accountId: _accountId,
            collectionId: collection.id,
            collectionUri: Uri.parse(collection.requestUri),
            credential: credential,
          );
          final result =
              await DavSyncEngine(
                database: _database,
                objectRepository: objectRepository,
                remoteClient: remote,
                accountId: _accountId,
                collectionId: collection.id,
                provider: provider,
                limits: _syncLimits,
                nowUtc: _nowUtc,
              ).synchronize(
                correlationId: _correlationIdFactory(),
                cancellationToken: cancellationToken,
                forceRebaseline: forceRebaseline,
              );
          results.add(result);
        } on DavException catch (error) {
          failures.add(error);
        }
      }
    }

    final workerCount =
        collections.length < _policy.maximumConcurrentCollections
        ? collections.length
        : _policy.maximumConcurrentCollections;
    await Future.wait([for (var i = 0; i < workerCount; i += 1) worker()]);
    return _CollectionBatchResult(results: results, failures: failures);
  }

  Future<void> _recordFailureState(
    DavException error,
    DavDiscoveryRepository discoveryRepository,
  ) async {
    await discoveryRepository.recordDiscoveryFailure(_accountId, error.code);
    final state = switch (error.category) {
      DavErrorCategory.davAuthRejected ||
      DavErrorCategory.davCredentialsRevoked =>
        AccountConnectionState.reauthenticationRequired,
      DavErrorCategory.davPermissionDenied ||
      DavErrorCategory.davReadOnly => AccountConnectionState.permissionChanged,
      DavErrorCategory.davUnsupportedServer ||
      DavErrorCategory.davProtocolViolation ||
      DavErrorCategory.davUnsupportedComponent =>
        AccountConnectionState.unsupportedServerProfile,
      _ => AccountConnectionState.temporarilyUnavailable,
    };
    await _setConnectionState(state);
  }

  Future<void> _markSuccessful({required bool full}) {
    final now = _nowUtc().toUtc().toIso8601String();
    return (_database.update(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).write(
      AccountsCompanion(
        authState: Value(AccountConnectionState.connected.storageValue),
        lastSuccessfulSyncAtUtc: Value(now),
        lastFullSyncAtUtc: full ? Value(now) : const Value.absent(),
        updatedAtUtc: Value(now),
      ),
    );
  }

  Future<void> _setConnectionState(AccountConnectionState state) {
    return (_database.update(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).write(
      AccountsCompanion(
        authState: Value(state.storageValue),
        updatedAtUtc: Value(_nowUtc().toUtc().toIso8601String()),
      ),
    );
  }

  void _clearActive(Future<DavAccountSyncResult> operation) {
    if (identical(_activeSync, operation)) _activeSync = null;
  }
}

bool _requiresReconnect(DavException error) => switch (error.category) {
  DavErrorCategory.davAuthRejected ||
  DavErrorCategory.davCredentialsRevoked => true,
  _ => false,
};

final class _DavCredentialContext {
  const _DavCredentialContext({required this.authority, required this.basic});

  final Uri authority;
  final DavBasicCredential basic;
}

final class _CollectionBatchResult {
  const _CollectionBatchResult({
    this.results = const [],
    this.failures = const [],
  });

  final List<DavCollectionSyncResult> results;
  final List<DavException> failures;
}
