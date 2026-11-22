import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/sync/account_sync_activity.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/features/sync/account_synchronization_service.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/features/sync/sync_engine.dart';
import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the production scope dispatcher and account coordinator with
/// deterministic pulls and no provider transport.
class RestSyncFixture {
  RestSyncFixture({
    required AppDatabase database,
    required AccountsRepository accounts,
    required AccountSyncCoordinator coordinator,
    required AccountSyncActivity activity,
    required Future<void> Function(String id, bool full) pullTasks,
    required Future<void> Function(String id, bool full) pullCalendar,
  }) {
    final service = AccountSynchronizationService(
      accounts: accounts,
      database: database,
      requireNetwork: () async {},
      coordinator: coordinator,
      gate: const InProcessAccountGate(),
      activity: activity,
      authorization: AuthorizationPersistence(
        database: database,
        secrets: InMemorySecretStore(),
      ),
      webCalService: () => throw StateError('Unexpected WebCal request'),
      davEngine: (id) => throw StateError('Unexpected DAV request for $id'),
      tasksEngine: (id, _) => _TasksEngine((full) => pullTasks(id, full)),
      calendarEngine: (id, _) =>
          _CalendarEngine((full) => pullCalendar(id, full)),
      loadDavCreationNotices: (_, _) async => const [],
      discoverFederation: (_, _) async {},
      onManualFailure: (id, error) async => failures[id] = error,
      clearAccountFailure: (_) async {},
    );
    operations = RequestAccountSyncOperations((request) {
      requests.add(request);
      return service.operations.execute(request);
    });
  }

  final requests = <SyncRequest>[];
  final failures = <String, Object>{};
  late final ScopedAccountSyncOperations operations;

  static Future<void> insertAccount(
    AppDatabase database,
    AccountEntity account,
  ) => database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: account.id,
          provider: account.provider.storageValue,
          authority: account.authority,
          providerAccountId: account.providerAccountId,
          credentialKind: 'oauth',
          authState: Value(account.authState),
          tasksEnabled: Value(account.tasksEnabled),
          calendarsEnabled: Value(account.calendarsEnabled),
          createdAtUtc: '2026-01-01T00:00:00Z',
          updatedAtUtc: '2026-01-01T00:00:00Z',
        ),
      );
}

class _TasksEngine extends Fake implements SyncEngine {
  _TasksEngine(this.pull);
  final Future<void> Function(bool full) pull;

  @override
  Future<void> fullSync() => pull(true);
  @override
  Future<void> incrementalSync() => pull(false);
  @override
  Future<void> dispatchPendingWrites() async {}
  @override
  Future<void> maintainCachedReminders() async {}
  @override
  Set<String> get affectedCollectionIds => const {};
  @override
  Set<String> get completedCollectionIds => const {};
  @override
  bool get remoteImportWroteData => false;
}

class _CalendarEngine extends Fake implements CalendarSyncEngine {
  _CalendarEngine(this.pull);
  final Future<void> Function(bool full) pull;

  @override
  Future<void> fullSync() => pull(true);
  @override
  Future<void> incrementalSync() => pull(false);
  @override
  Future<void> dispatchPendingWrites() async {}
  @override
  Future<void> maintainCachedReminders() async {}
  @override
  Set<String> get affectedCollectionIds => const {};
  @override
  Set<String> get completedCollectionIds => const {};
}
