import 'dart:io';
import 'package:drift/native.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_task_remote_client.dart';
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
  late Directory directory;
  late File databaseFile;
  late DateTime now;
  late DomainSyncPolicy policy;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('busymax-cooldown-test-');
    databaseFile = File('${directory.path}/schedule.sqlite');
    db = AppDatabase(NativeDatabase(databaseFile));
    now = DateTime.utc(2026, 10, 3, 12);
    await AccountsRepository(database: db).upsertSignedInAccount(
      id: 'a',
      provider: BusyProvider.google,
      providerAccountId: 'subject',
      grantedScopes: 'tasks calendar',
    );
    policy = DomainSyncPolicy(db, nowUtc: () => now);
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  for (final microsoft in [false, true]) {
    for (final domain in SyncDomain.values) {
      for (final trigger in [
        SyncTrigger.manual,
        SyncTrigger.localMutation,
        SyncTrigger.background,
      ]) {
        test(
          'real replay establishes domain cooldown before remaining writes and pull: microsoft=$microsoft $domain $trigger',
          () async {
            final requests = <http.Request>[];
            var throttled = true;
            final transport = MockClient((request) async {
              requests.add(request);
              if (request.method == 'POST' && throttled) {
                return http.Response(
                  '{"error":{"code":429,"message":"Rate limited"}}',
                  429,
                  headers: {'retry-after': '7200'},
                );
              }
              if (request.method == 'POST') {
                return http.Response(
                  jsonEncode({
                    'id': 'created-${requests.length}',
                    'title': 'Offline',
                    'summary': 'Offline',
                    'status': microsoft ? 'notStarted' : 'needsAction',
                  }),
                  200,
                );
              }
              return http.Response(
                microsoft ? '{"value":[]}' : '{"items":[]}',
                200,
              );
            });
            final tasksClient = microsoft
                ? MicrosoftTodoTaskRemoteClient(
                    client: MicrosoftTodoRestApiClient(
                      httpClient: transport,
                      baseUri: Uri.https('graph.microsoft.com', '/v1.0/'),
                    ),
                    defaultTimeZone: 'UTC',
                    nowUtc: () => now,
                  )
                : GoogleTasksRestApiClient(
                    httpClient: transport,
                    baseUri: Uri.https('tasks.googleapis.com', '/'),
                  );
            final CloudCalendarClient calendarClient = microsoft
                ? MicrosoftCalendarApiClient(
                    httpClient: transport,
                    baseUri: Uri.https('graph.microsoft.com', '/v1.0/'),
                    responseTimeZone: 'UTC',
                  )
                : GoogleCalendarApiClient(
                    httpClient: transport,
                    baseUri: Uri.https('www.googleapis.com', '/calendar/v3/'),
                  );
            if (microsoft) {
              await (db.update(db.accounts)..where((r) => r.id.equals('a')))
                  .write(const AccountsCompanion(provider: Value('microsoft')));
            }
            await db
                .into(db.taskLists)
                .insert(
                  TaskListsCompanion.insert(
                    accountId: 'a',
                    id: 'l',
                    title: 'Fixture',
                    rawJson: '{}',
                    createdLocalAtUtc: now.toIso8601String(),
                    updatedLocalAtUtc: now.toIso8601String(),
                  ),
                );
            for (var i = 0; i < 3; i++) {
              await db.pendingOpsDao.enqueue(
                PendingOpsCompanion.insert(
                  id: 'write-$i',
                  accountId: 'a',
                  entityType: domain == SyncDomain.tasks ? 'task' : 'calendar',
                  provider: Value(microsoft ? 'microsoft' : 'google'),
                  operationType: Value(
                    domain == SyncDomain.tasks
                        ? 'create_task'
                        : 'calendar.create',
                  ),
                  operation: 'create_task',
                  taskListId: const Value('l'),
                  taskId: Value('local-$i'),
                  localTempId: Value('local-$i'),
                  requestJson: domain == SyncDomain.tasks
                      ? '{"body":{"title":"Offline"}}'
                      : '{"summary":"Offline"}',
                  createdAtUtc: now.toIso8601String(),
                  updatedAtUtc: now.toIso8601String(),
                ),
              );
            }
            var engine = SyncEngine(
              database: db,
              apiClient: tasksClient,
              accountId: 'a',
              nowUtc: () => now,
            );
            var calendar = CalendarSyncEngine(
              database: db,
              client: calendarClient,
              accountId: 'a',
              nowUtc: () => now,
            );
            Future<void> pull() => domain == SyncDomain.tasks
                ? engine.incrementalSync()
                : calendar.incrementalSync();
            Future<void> dispatch() => domain == SyncDomain.tasks
                ? engine.dispatchPendingWrites()
                : calendar.dispatchPendingWrites();
            Future<void> maintenance() => domain == SyncDomain.tasks
                ? engine.maintainCachedReminders()
                : calendar.maintainCachedReminders();
            Future<void> run(SyncTrigger current) => withSyncTrigger(
              current,
              () => policy.run(
                'a',
                domain,
                pull: pull,
                deferred: dispatch,
                maintainCached: maintenance,
              ),
            );
            await expectLater(run(trigger), throwsA(anything));
            expect(requests.map((r) => r.method).toList(), ['POST']);
            final schedule = await db
                .select(db.domainSyncSchedules)
                .getSingle();
            expect(
              DateTime.parse(schedule.cooldownUntilUtc!),
              now.add(const Duration(hours: 2)),
            );
            expect(schedule.lastSuccessfulPullUtc, isNull);
            for (final op in await db.select(db.pendingOps).get()) {
              expect(op.attemptCount, op.id == 'write-0' ? 1 : 0);
              expect(op.state, op.id == 'write-0' ? 'retry' : 'pending');
            }
            for (final wake in SyncTrigger.values) {
              await expectLater(
                run(wake),
                throwsA(isA<DomainCooldownException>()),
              );
            }
            expect(requests.length, 1);
            if (domain == SyncDomain.calendar) {
              await expectLater(
                calendar.retrieveMonth(DateTime.utc(2027, 1)),
                throwsA(isA<DomainCooldownException>()),
              );
              expect(requests.length, 1);
            }
            await db.close();
            db = AppDatabase(NativeDatabase(databaseFile));
            policy = DomainSyncPolicy(db, nowUtc: () => now);
            engine = SyncEngine(
              database: db,
              apiClient: tasksClient,
              accountId: 'a',
              nowUtc: () => now,
            );
            calendar = CalendarSyncEngine(
              database: db,
              client: calendarClient,
              accountId: 'a',
              nowUtc: () => now,
            );
            final restarted = policy;
            await expectLater(
              restarted.run('a', domain, pull: pull, deferred: dispatch),
              throwsA(isA<DomainCooldownException>()),
            );
            expect(requests.length, 1);
            if (domain == SyncDomain.calendar) {
              await expectLater(
                calendar.retrieveMonth(DateTime.utc(2027, 1)),
                throwsA(isA<DomainCooldownException>()),
              );
              expect(requests.length, 1);
            }
            // Independent domains remain eligible; no application-wide blackout.
            var independent = 0;
            await policy.run(
              'a',
              domain == SyncDomain.tasks
                  ? SyncDomain.calendar
                  : SyncDomain.tasks,
              pull: () async {
                independent++;
              },
              deferred: () async {},
            );
            expect(independent, 1);
            throttled = false;
            now = now.add(const Duration(hours: 2));
            await run(SyncTrigger.manual);
            expect(requests.where((r) => r.method == 'POST'), hasLength(4));
            expect(await db.select(db.pendingOps).get(), isEmpty);
            final persisted = await (db.select(
              db.domainSyncSchedules,
            )..where((r) => r.domain.equals(domain.name))).getSingle();
            expect(persisted.lastSuccessfulPullUtc, now.toIso8601String());
            expect(persisted.cooldownUntilUtc, isNull);
          },
        );
      }
    }
  }

  test(
    'concurrent cooldown writers retain the longest value and stale success cannot clear it',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final pull = policy.run(
        'a',
        SyncDomain.tasks,
        pull: () async {
          entered.complete();
          await release.future;
        },
        deferred: () async {},
      );
      final rejected = expectLater(
        pull,
        throwsA(isA<DomainCooldownException>()),
      );
      await entered.future;
      await Future.wait([
        policy.recordFailureCooldown(
          'a',
          SyncDomain.tasks,
          const TaskRemoteError(
            statusCode: 429,
            code: 'throttled',
            message: 'synthetic',
            retryable: true,
            retryAfter: Duration(hours: 4),
          ),
        ),
        DomainSyncPolicy(db, nowUtc: () => now).recordFailureCooldown(
          'a',
          SyncDomain.tasks,
          const TaskRemoteError(
            statusCode: 429,
            code: 'throttled',
            message: 'synthetic',
            retryable: true,
            retryAfter: Duration(seconds: 1),
          ),
        ),
      ]);
      release.complete();
      await rejected;
      final row = await db.select(db.domainSyncSchedules).getSingle();
      expect(
        row.cooldownUntilUtc,
        now.add(const Duration(hours: 4)).toIso8601String(),
      );
      expect(row.lastSuccessfulPullUtc, isNull);
    },
  );
  for (final quota in [false, true]) {
    for (final retryHeader in [null, 'malformed']) {
      test(
        'real Google quota=$quota missing/invalid retry timing $retryHeader uses durable fallback',
        () async {
          var requests = 0;
          final client = GoogleTasksRestApiClient(
            httpClient: MockClient((r) async {
              requests++;
              return http.Response(
                '{"error":{"code":${quota ? 403 : 429},"errors":[{"reason":"userRateLimitExceeded"}]}}',
                quota ? 403 : 429,
                headers: {if (retryHeader != null) 'retry-after': retryHeader},
              );
            }),
            baseUri: Uri.https('tasks.googleapis.com', '/'),
          );
          await db.pendingOpsDao.enqueue(
            PendingOpsCompanion.insert(
              id: 'throttled',
              accountId: 'a',
              entityType: 'task',
              operation: 'create_task',
              taskListId: const Value('l'),
              taskId: const Value('local'),
              localTempId: const Value('local'),
              requestJson: '{"body":{"title":"Offline"}}',
              createdAtUtc: now.toIso8601String(),
              updatedAtUtc: now.toIso8601String(),
            ),
          );
          final engine = SyncEngine(
            database: db,
            apiClient: client,
            accountId: 'a',
            nowUtc: () => now,
          );
          await expectLater(
            engine.incrementalSync(),
            throwsA(isA<TaskRemoteError>()),
          );
          expect(
            (await db.select(db.domainSyncSchedules).getSingle())
                .cooldownUntilUtc,
            now.add(const Duration(minutes: 1)).toIso8601String(),
          );
          await expectLater(
            engine.dispatchPendingWrites(),
            throwsA(isA<DomainCooldownException>()),
          );
          expect(requests, 1);
          expect((await db.select(db.pendingOps).getSingle()).attemptCount, 1);
        },
      );
    }
  }
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
