import 'dart:async';
import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/settings/presentation/account_sync_status.dart';
import 'package:busymax/src/features/sync/calendar_pending_ops_replayer.dart';
import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'failed Google visibility survives restart independently of queued changes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'busymax-sync-status-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/fixture.sqlite');
      final database = AppDatabase(NativeDatabase(file));
      final first = _container(database);
      final when = DateTime.utc(2026, 6, 1, 12);
      late final String failedId;
      try {
        final account = await _seedAccount(database, 'account', when);
        final calendars = CalendarRepository(database: database);
        await calendars.upsertSource(
          accountId: account.id,
          source: const CalendarSourceDto(
            provider: BusyProvider.google,
            providerCalendarId: 'calendar',
            summary: 'Calendar',
            accessRole: 'owner',
          ),
        );
        await calendars.setSourceProviderHidden(
          (await database.select(database.calendarSources).getSingle()).id,
          true,
        );
        final queued = await _waitForStatus(
          first,
          account,
          (value) => value.hasPendingChanges && value.lastRefreshed != null,
        );
        expect(queued.status, AccountRefreshStatus.refreshed);
        expect(queued.hasFailedChanges, isFalse);

        final client = MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.body, contains('"hidden":true'));
          return http.Response(
            '{"error":{"message":"Synthetic rejection"}}',
            403,
          );
        });
        addTearDown(client.close);
        await CalendarPendingOpsReplayer(
          database: database,
          client: GoogleCalendarApiClient(
            httpClient: client,
            baseUri: Uri.parse('https://calendar.example.test'),
          ),
          accountId: account.id,
        ).replayDueOps();
        final operation = await database
            .select(database.pendingOps)
            .getSingle();
        expect(operation.operationType, 'calendar.patch');
        expect(operation.lastErrorCode, isNotNull);
        failedId = operation.id;
      } finally {
        first.dispose();
        await database.close();
      }

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final second = _container(reopened);
      addTearDown(second.dispose);
      final account = (await AccountsRepository(database: reopened)
          .accountById('account'))!;
      final other = await _seedAccount(reopened, 'other', when);
      expect(
        second.read(accountSyncActivityProvider).accountHasFailure(account.id),
        isFalse,
      );
      final persisted = await _waitForStatus(
        second,
        account,
        (value) => value.hasFailedChanges && value.lastRefreshed != null,
      );
      expect(persisted.status, AccountRefreshStatus.failed);
      expect(persisted.hasPendingChanges, isFalse);
      expect(persisted.lastRefreshed, when);
      expect(
        (await _waitForStatus(
          second,
          other,
          (value) => value.lastRefreshed != null,
        )).status,
        AccountRefreshStatus.refreshed,
      );

      await reopened.pendingOpsDao.retryNow(failedId, when);
      final retry = await _waitForStatus(
        second,
        account,
        (value) => value.hasPendingChanges && value.lastRefreshed != null,
      );
      expect(retry.status, AccountRefreshStatus.refreshed);
      expect(retry.hasFailedChanges, isFalse);
    },
  );

  test(
    'an account-scoped task list load failure is visible and can recover',
    () async {
      final database = AppDatabase.memoryForTests();
      addTearDown(database.close);
      final when = DateTime.utc(2026, 6, 1);
      final account = await _seedAccount(database, 'broken', when);
      final other = await _seedAccount(database, 'healthy', when);
      final repository = _TaskListsWithFailure(database, account.id);
      final container = _container(database, taskLists: repository);
      addTearDown(container.dispose);
      final status = await _waitForStatus(
        container,
        account,
        (value) =>
            value.status == AccountRefreshStatus.failed &&
            value.lastRefreshed != null,
      );
      expect(status.lastRefreshed, when);
      expect(status.hasFailedChanges, isFalse);
      expect(status.hasPendingChanges, isFalse);
      expect(status.hasInventoryLoadFailure, isTrue);
      expect(
        (await _waitForStatus(
          container,
          other,
          (value) => value.lastRefreshed != null,
        )).status,
        AccountRefreshStatus.refreshed,
      );
      await expectLater(
        container.read(scheduleTaskListsProvider.future),
        throwsStateError,
      );

      repository.fail = false;
      container.invalidate(scheduleTaskListsForAccountProvider(account.id));
      expect(await container.read(scheduleTaskListsProvider.future), isEmpty);
      expect(
        (await _waitForStatus(
          container,
          account,
          (value) => value.status == AccountRefreshStatus.refreshed,
        )).lastRefreshed,
        when,
      );
    },
  );
}

ProviderContainer _container(
  AppDatabase database, {
  _TaskListsWithFailure? taskLists,
}) => ProviderContainer(
  overrides: [
    databaseProvider.overrideWithValue(database),
    scheduleDataRevisionProvider.overrideWith((ref) => Stream.value(0)),
    taskListsRepositoryForAccountProvider.overrideWith(
      (ref, id) => taskLists?.accountId == id
          ? taskLists!
          : TaskListsRepository(database: database, accountId: id),
    ),
  ],
);

Future<AccountEntity> _seedAccount(
  AppDatabase database,
  String id,
  DateTime when,
) async {
  final accounts = AccountsRepository(database: database);
  await accounts.upsertSignedInAccount(
    id: id,
    provider: BusyProvider.google,
    grantedScopes: 'calendar tasks',
  );
  await database
      .into(database.domainSyncSchedules)
      .insert(
        DomainSyncSchedulesCompanion.insert(
          accountId: id,
          domain: accountRefreshHistoryKey,
          lastSuccessfulPullUtc: Value(when.toIso8601String()),
        ),
      );
  return (await accounts.accountById(id))!;
}

Future<AccountSyncStatus> _waitForStatus(
  ProviderContainer container,
  AccountEntity account,
  bool Function(AccountSyncStatus) predicate,
) async {
  final result = Completer<AccountSyncStatus>();
  final subscription = container.listen(accountSyncStatusProvider(account), (
    _,
    status,
  ) {
    if (!result.isCompleted && predicate(status)) result.complete(status);
  }, fireImmediately: true);
  try {
    return await result.future.timeout(const Duration(seconds: 4));
  } finally {
    subscription.close();
  }
}

class _TaskListsWithFailure extends TaskListsRepository {
  _TaskListsWithFailure(AppDatabase database, this.accountId)
    : super(database: database, accountId: accountId);

  final String accountId;
  var fail = true;

  @override
  Future<List<TaskListEntity>> listTaskLists() async {
    if (fail) throw StateError('Synthetic task-list read failure');
    return super.listTaskLists();
  }
}
