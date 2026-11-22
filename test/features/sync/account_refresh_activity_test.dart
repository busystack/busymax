import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/sync/account_sync_activity.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/features/sync/domain_sync_schedule.dart';
import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:flutter_test/flutter_test.dart';

import '../../support/rest_sync_fixture.dart';

void main() {
  test(
    'routine domain deferrals preserve verified history and independent errors',
    () async {
      final database = AppDatabase.memoryForTests();
      final activity = AccountSyncActivity();
      final coordinator = AccountSyncCoordinator();
      addTearDown(database.close);
      addTearDown(activity.dispose);
      addTearDown(coordinator.dispose);
      const id = 'google:account';
      await RestSyncFixture.insertAccount(
        database,
        const AccountEntity(
          id: id,
          provider: BusyProvider.google,
          authority: 'https://accounts.google.com',
          providerAccountId: 'account',
          authState: accountAuthStateSignedIn,
        ),
      );
      final failing = <SyncDomain>{};
      final calls = <(SyncDomain, bool)>[];
      final error = StateError('provider rejected the pull');
      Future<void> pull(SyncDomain domain, bool full) async {
        calls.add((domain, full));
        if (failing.contains(domain)) throw error;
      }

      final fixture = RestSyncFixture(
        database: database,
        accounts: AccountsRepository(database: database),
        coordinator: coordinator,
        activity: activity,
        pullTasks: (_, full) => pull(SyncDomain.tasks, full),
        pullCalendar: (_, full) => pull(SyncDomain.calendar, full),
      );
      final account = accountSyncScope(id);
      SyncScope scope(SyncDomain domain) => (
        kind: domain == SyncDomain.calendar
            ? SyncScopeKind.calendar
            : SyncScopeKind.tasks,
        accountId: id,
        resourceId: null,
      );
      Future<SyncOutcome> refresh(
        SyncTrigger origin, {
        SyncScope? target,
        SyncStrategy strategy = SyncStrategy.ordinary,
      }) => fixture.operations.execute((
        scope: target ?? account,
        origin: origin,
        strategy: strategy,
      ));
      Future<DomainSyncSchedule> history(String domain) =>
          (database.select(database.domainSyncSchedules)..where(
                (row) => row.accountId.equals(id) & row.domain.equals(domain),
              ))
              .getSingle();
      Future<void> makeDue(SyncDomain domain) =>
          (database.update(database.domainSyncSchedules)..where(
                (row) =>
                    row.accountId.equals(id) & row.domain.equals(domain.name),
              ))
              .write(
                const DomainSyncSchedulesCompanion(
                  nextPassivePullUtc: Value('2000-01-01T00:00:00Z'),
                ),
              );

      expect(
        (await refresh(SyncTrigger.manual)).disposition,
        SyncDisposition.completed,
      );
      final verified = await history(accountRefreshHistoryKey);
      final tasksHistory = await history('tasks');
      calls.clear();
      for (var i = 0; i < 3; i++) {
        await makeDue(SyncDomain.calendar);
        final background = await refresh(SyncTrigger.background);
        expect(background.children.map((child) => child.disposition), [
          SyncDisposition.deferred,
          SyncDisposition.completed,
        ]);
        expect(background.children.first.deferral, SyncDeferral.scheduled);
        expect(activity.accountNeedsAttention(id), isFalse);
        expect(activity.outcome(account), isNull);
        expect(await history('tasks'), tasksHistory);
        expect(await history(accountRefreshHistoryKey), verified);
      }
      expect(calls, List.filled(3, (SyncDomain.calendar, false)));
      expect(
        (await refresh(SyncTrigger.background)).disposition,
        SyncDisposition.deferred,
      );
      expect(activity.accountNeedsAttention(id), isFalse);

      failing.addAll(SyncDomain.values);
      expect(
        (await refresh(SyncTrigger.manual, target: allSyncScope)).hasFailure,
        isTrue,
      );
      expect(activity.outcome(allSyncScope)?.hasFailure, isTrue);
      expect(activity.accountHasFailure(id), isTrue);
      expect(activity.outcome(scope(SyncDomain.tasks))?.error, same(error));
      expect(activity.outcome(scope(SyncDomain.calendar))?.error, same(error));

      failing.remove(SyncDomain.calendar);
      await makeDue(SyncDomain.calendar);
      await refresh(SyncTrigger.background);
      expect(activity.outcome(scope(SyncDomain.calendar)), isNull);
      expect(activity.outcome(scope(SyncDomain.tasks))?.error, same(error));
      expect(
        activity.outcome(account)?.children.map((child) => child.request.scope),
        [scope(SyncDomain.tasks)],
      );
      expect(activity.accountNeedsAttention(id), isTrue);
      expect(await history(accountRefreshHistoryKey), verified);

      failing.clear();
      await refresh(SyncTrigger.manual, target: scope(SyncDomain.tasks));
      expect(activity.accountNeedsAttention(id), isFalse);
      expect(activity.outcome(account), isNull);
      expect(activity.outcome(allSyncScope), isNull);
      expect(await history(accountRefreshHistoryKey), verified);

      await database
          .into(database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: 'queued-write',
              accountId: id,
              operation: 'patch_task',
              entityType: 'task',
              requestJson: '{}',
              createdAtUtc: '2026-01-01T00:00:00Z',
              updatedAtUtc: '2026-01-01T00:00:00Z',
            ),
          );
      final partial = await refresh(
        SyncTrigger.manual,
        strategy: SyncStrategy.fullRecovery,
      );
      expect(partial.disposition, SyncDisposition.partial);
      expect(partial.children.first.deferral, SyncDeferral.pendingWrites);
      expect(partial.hasFailure, isFalse);
      expect(activity.accountNeedsAttention(id), isTrue);
      expect(
        (await database.select(database.pendingOps).getSingle()).state,
        'pending',
      );
      expect(await history(accountRefreshHistoryKey), verified);
      await database.delete(database.pendingOps).go();
      expect(
        (await refresh(SyncTrigger.manual)).disposition,
        SyncDisposition.completed,
      );
      expect(activity.accountNeedsAttention(id), isFalse);
      expect(
        (await history(accountRefreshHistoryKey)).lastSuccessfulPullUtc,
        isNot(verified.lastSuccessfulPullUtc),
      );
    },
  );
}
