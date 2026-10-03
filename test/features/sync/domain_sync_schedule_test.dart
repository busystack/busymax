import 'dart:async';
import 'dart:convert';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/features/sync/domain_sync_schedule.dart';
import 'package:busymax/src/features/sync/sync_engine.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_error.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late DomainSyncPolicy policy;
  setUp(() async {
    db = AppDatabase.memoryForTests();
    now = DateTime.utc(2026, 10, 3, 12);
    await AccountsRepository(database: db).upsertSignedInAccount(
      id: 'a',
      provider: BusyProvider.google,
      providerAccountId: 'subject',
      grantedScopes: 'tasks calendar',
    );
    policy = DomainSyncPolicy(db, nowUtc: () => now);
  });
  tearDown(() => db.close());

  for (final collections in [1, 5, 20]) {
    test(
      'quiet $collections collections: real Tasks engine request budget and checkpoint overlap',
      () async {
        final requests = <http.Request>[];
        final client = GoogleTasksRestApiClient(
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(
                r.url.path.endsWith('/lists')
                    ? {
                        'items': [
                          for (var i = 0; i < collections; i++)
                            {'id': 'l$i', 'title': 'List $i'},
                        ],
                      }
                    : {'items': []},
              ),
              200,
            );
          }),
          baseUri: Uri.https('tasks.googleapis.com', '/'),
        );
        final engine = SyncEngine(
          database: db,
          apiClient: client,
          accountId: 'a',
          nowUtc: () => now,
        );
        Future<void> run(SyncTrigger trigger) => withSyncTrigger(
          trigger,
          () => policy.run(
            'a',
            SyncDomain.tasks,
            pull: engine.incrementalSync,
            deferred: engine.dispatchPendingWrites,
          ),
        );
        await run(SyncTrigger.background);
        expect(requests.length, 1 + collections);
        final persisted = await db.select(db.domainSyncSchedules).getSingle();
        for (var wake = 1; wake <= 3; wake++) {
          now = now.add(const Duration(minutes: 15));
          await run(SyncTrigger.background);
        }
        expect(requests.length, 1 + collections);
        expect(
          (await db.select(db.domainSyncSchedules).getSingle())
              .nextPassivePullUtc,
          persisted.nextPassivePullUtc,
        );
        now = DateTime.parse(persisted.nextPassivePullUtc!);
        await run(SyncTrigger.background);
        expect(requests.length, 2 * (1 + collections));
        expect(
          requests.last.url.queryParameters['updatedMin'],
          DateTime.utc(2026, 10, 3, 11, 58).toIso8601String(),
        );
        await run(SyncTrigger.manual);
        expect(requests.length, 3 * (1 + collections));
        expect(
          requests.last.url.queryParameters.containsKey('updatedMin'),
          true,
        );
      },
    );
  }
  test(
    'changed paginated workload preserves pages and dispatches local creation without passive polling',
    () async {
      final requests = <http.Request>[];
      final client = GoogleTasksRestApiClient(
        httpClient: MockClient((r) async {
          requests.add(r);
          if (r.method == 'POST') {
            return http.Response(
              jsonEncode({'id': 'remote-created', 'title': 'Offline'}),
              200,
            );
          }
          if (r.url.path.endsWith('/lists')) {
            return http.Response(
              jsonEncode({
                'items': r.url.queryParameters['pageToken'] == null
                    ? []
                    : [
                        {'id': 'l', 'title': 'List'},
                      ],
                if (r.url.queryParameters['pageToken'] == null)
                  'nextPageToken': 'lists-next',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': r.url.queryParameters['pageToken'] == null
                      ? 't1'
                      : 't2',
                  'title': 'Changed',
                  'status': 'needsAction',
                },
              ],
              if (r.url.queryParameters['pageToken'] == null)
                'nextPageToken': 'tasks-next',
            }),
            200,
          );
        }),
        baseUri: Uri.https('tasks.googleapis.com', '/'),
      );
      final engine = SyncEngine(
        database: db,
        apiClient: client,
        accountId: 'a',
        nowUtc: () => now,
      );
      await withSyncTrigger(
        SyncTrigger.background,
        () => policy.run(
          'a',
          SyncDomain.tasks,
          pull: engine.incrementalSync,
          deferred: engine.dispatchPendingWrites,
        ),
      );
      expect(requests.length, 4);
      expect(await db.select(db.tasks).get(), hasLength(2));
      await db
          .into(db.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: 'op',
              accountId: 'a',
              entityType: 'task',
              operation: 'create_task',
              taskListId: const Value('l'),
              taskId: const Value('local'),
              localTempId: const Value('local'),
              requestJson: jsonEncode({
                'body': {'title': 'Offline'},
              }),
              createdAtUtc: now.toIso8601String(),
              updatedAtUtc: now.toIso8601String(),
            ),
          );
      await withSyncTrigger(
        SyncTrigger.localMutation,
        () => policy.run(
          'a',
          SyncDomain.tasks,
          pull: engine.incrementalSync,
          deferred: engine.dispatchPendingWrites,
        ),
      );
      expect(requests.length, 5);
      expect(requests.last.method, 'POST');
      expect(await db.select(db.pendingOps).get(), isEmpty);
    },
  );
  test(
    'foreground and background overlap consume one window under production account coordination',
    () async {
      final coordinator = AccountSyncCoordinator();
      addTearDown(coordinator.dispose);
      final started = Completer<void>(), release = Completer<void>();
      var pulls = 0, reminders = 0;
      Future<void> run(SyncTrigger trigger) => withSyncTrigger(
        trigger,
        () => coordinator.run(
          'a',
          () => policy.run(
            'a',
            SyncDomain.tasks,
            pull: () async {
              pulls++;
              started.complete();
              await release.future;
            },
            deferred: () async {
              reminders++;
            },
          ),
        ),
      );
      final background = run(SyncTrigger.background);
      await started.future;
      final foreground = run(SyncTrigger.foreground);
      release.complete();
      await Future.wait([background, foreground]);
      expect(pulls, 1);
      expect(reminders, 1);
      policy = DomainSyncPolicy(
        db,
        nowUtc: () => now,
      ); // restart retains eligibility
      await run(SyncTrigger.background);
      expect(pulls, 1);
    },
  );
  test(
    'Tasks quota defers its domain through restart while Calendar and cached reminders continue',
    () async {
      var tasks = 0, calendar = 0, reminders = 0;
      final operations = RoutingAccountSyncOperations(
        providerForAccount: (_) async => BusyProvider.google,
        syncDav: (_, {required full}) async {},
        syncWebCal: (_, {required full}) async {},
        syncTasksRest: (_, {required full}) => policy.run(
          'a',
          SyncDomain.tasks,
          pull: () async {
            tasks++;
            throw const TaskRemoteError(
              statusCode: 403,
              code: 'quota',
              message: 'Rate limit',
              retryable: true,
              retryAfter: Duration(hours: 2),
            );
          },
          deferred: () async {},
          maintainCached: () async {
            reminders++;
          },
        ),
        syncCalendarRest: (_, {required full}) => policy.run(
          'a',
          SyncDomain.calendar,
          pull: () async {
            calendar++;
          },
          deferred: () async {
            reminders++;
          },
        ),
      );
      // Use the actual remote error classification, including a long server hint.
      await expectLater(
        operations.syncAccount('a', full: false),
        throwsA(isA<PartialAccountSyncException>()),
      );
      expect(tasks, 1);
      expect(calendar, 1);
      policy = DomainSyncPolicy(db, nowUtc: () => now);
      await expectLater(
        withSyncTrigger(
          SyncTrigger.manual,
          () => operations.syncAccount('a', full: false),
        ),
        throwsA(isA<PartialAccountSyncException>()),
      );
      expect(tasks, 1);
      expect(calendar, 2);
      expect(reminders, 1);
      final row = await (db.select(
        db.domainSyncSchedules,
      )..where((r) => r.domain.equals('tasks'))).getSingle();
      expect(
        DateTime.parse(row.cooldownUntilUtc!),
        now.add(const Duration(hours: 2)),
      );
      now = now.subtract(const Duration(hours: 3));
      await expectLater(
        operations.syncTasks('a', full: false),
        throwsA(isA<DomainCooldownException>()),
      );
      expect(tasks, 1);
    },
  );
  test(
    'clock reversal permits stale work and disabled domains issue no requests',
    () async {
      var pulls = 0;
      Future<void> run() => withSyncTrigger(
        SyncTrigger.background,
        () => policy.run(
          'a',
          SyncDomain.tasks,
          pull: () async {
            pulls++;
          },
          deferred: () async {},
        ),
      );
      await run();
      now = now.subtract(const Duration(days: 1));
      await run();
      expect(pulls, 2);
      await (db.update(db.accounts)..where((r) => r.id.equals('a'))).write(
        const AccountsCompanion(tasksEnabled: Value(false)),
      );
      await run();
      expect(pulls, 2);
      await (db.delete(db.accounts)..where((r) => r.id.equals('a'))).go();
      expect(await db.select(db.domainSyncSchedules).get(), isEmpty);
    },
  );
}
