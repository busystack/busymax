import 'package:busymax/src/features/tasks/domain/task_remote_error.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/sync/sync_auth_error.dart';
import 'package:busymax/src/features/sync/domain_sync_schedule.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/features/sync/sync_engine.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/schedule/schedule_sidebar_order.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_error.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:busymax/src/features/tasks/domain/task_checklist_item.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_error.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_models.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_task_remote_client.dart';

import '../../support/recording_notification_backend.dart';
import '../../support/memory_settings_store.dart';

import '../../support/persistence_test_directory.dart';

void main() {
  late AppDatabase database;
  late _FakeTaskRemoteClient apiClient;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    apiClient = _FakeTaskRemoteClient();
    await _insertAccount(database);
    await database.taskListsDao.upsertTaskList(_taskList('list-1'));
  });

  tearDown(() async {
    await database.close();
  });

  for (final fullUpdate in [false, true]) {
    test(
      'recurring completion retries definitive Graph throttling ($fullUpdate)',
      () async {
        await database
            .update(database.accounts)
            .write(const AccountsCompanion(provider: Value('microsoft')));
        final graph = _ThrottledMicrosoftTodoApiClient();
        final remote = MicrosoftTodoTaskRemoteClient(
          client: graph,
          defaultTimeZone: 'UTC',
        );
        final original = await remote.getTask(
          taskListId: 'list-1',
          taskId: 'task-1',
        );
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', original, _now),
        );
        var now = DateTime.utc(2026, 6, 4, 1);
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => now,
        );
        if (fullUpdate) {
          await repository.updateTaskFull(
            'list-1',
            'task-1',
            const TaskPutInput({'status': 'completed'}),
          );
        } else {
          await repository.patchTask(
            'list-1',
            'task-1',
            const TaskPatchInput({'status': 'completed'}),
          );
        }
        await repository.patchTask(
          'list-1',
          'task-1',
          const TaskPatchInput({'title': 'After completion'}),
        );
        final queued = await database.select(database.pendingOps).get();
        final completion = queued.singleWhere(
          (op) => jsonDecode(op.requestJson)['status'] == 'completed',
        );
        expect(
          queued.singleWhere((op) => op.id != completion.id).dependsOnOpId,
          completion.id,
        );
        Future<int> replay() => PendingOpsReplayer(
          database: database,
          apiClient: remote,
          accountId: 'account',
          nowUtc: () => now,
          random: Random(0),
        ).replayDueOps();
        for (var attempt = 1; attempt <= 2; attempt++) {
          final dispatchTime = now;
          await expectLater(
            replay(),
            throwsA(
              isA<TaskRemoteError>()
                  .having((error) => error.statusCode, 'HTTP status', 429)
                  .having(
                    (error) => error.retryAfter,
                    'Retry-After',
                    const Duration(minutes: 5),
                  ),
            ),
          );
          final pending = (await database.pendingOpsDao.getOp(completion.id))!;
          expect(pending.state, 'retry');
          expect(pending.attemptCount, attempt);
          final eligible = DateTime.parse(pending.nextAttemptAtUtc!);
          expect(eligible.year, lessThan(9999));
          expect(
            eligible.isBefore(dispatchTime.add(const Duration(minutes: 5))),
            isFalse,
          );
          expect(graph.updates, attempt);
          expect(graph.current['status'], 'notStarted');
          now = eligible.subtract(const Duration(milliseconds: 1));
          try {
            await replay();
          } on DomainCooldownException {
            /* The domain cooldown also gates dispatch. */
          }
          expect(graph.updates, attempt);
          now = eligible;
        }
        expect(await replay(), 2);
        expect(
          graph.updates,
          4,
        ); // Two rejections, completion, dependent title.
        expect(graph.completionMutations, 3);
        expect(
          graph.readStatuses.where((status) => status == 'notStarted').length,
          greaterThanOrEqualTo(3),
        );
        expect(await database.select(database.pendingOps).get(), isEmpty);
        final local = await database.select(database.tasks).getSingle();
        expect(local.status, 'completed');
        expect(local.title, 'After completion');
        expect(local.localDirty, isFalse);
        expect(await replay(), 0);
        expect(graph.updates, 4);
      },
    );

    test(
      'uncertain recurring completion retains dispatch through Graph read 429 ($fullUpdate)',
      () async {
        final graph = _ThrottledMicrosoftTodoApiClient()
          ..remainingThrottles = 0
          ..loseCompletionResponse = true;
        final remote = MicrosoftTodoTaskRemoteClient(
          client: graph,
          defaultTimeZone: 'UTC',
        );
        await database
            .update(database.accounts)
            .write(const AccountsCompanion(provider: Value('microsoft')));
        final original = await remote.getTask(
          taskListId: 'list-1',
          taskId: 'task-1',
        );
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', original, _now),
        );
        var now = DateTime.utc(2026, 6, 4, 1);
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => now,
        );
        if (fullUpdate) {
          await repository.updateTaskFull(
            'list-1',
            'task-1',
            const TaskPutInput({'status': 'completed'}),
          );
        } else {
          await repository.patchTask(
            'list-1',
            'task-1',
            const TaskPatchInput({'status': 'completed'}),
          );
        }
        Future<int> replay() => PendingOpsReplayer(
          database: database,
          apiClient: remote,
          accountId: 'account',
          nowUtc: () => now,
        ).replayDueOps();
        expect(await replay(), 0);
        final sent = await database.select(database.pendingOps).getSingle();
        expect(sent.state, 'in_progress');
        now = DateTime.utc(2026, 6, 4, 2);
        graph.throttleRead = true;
        await expectLater(
          replay(),
          throwsA(
            isA<TaskRemoteError>().having(
              (error) => error.statusCode,
              'HTTP status',
              429,
            ),
          ),
        );
        final afterRead = (await database.pendingOpsDao.getOp(sent.id))!;
        expect(afterRead.state, 'in_progress');
        expect(afterRead.requestJson, sent.requestJson);
        now = DateTime.utc(2026, 6, 4, 3);
        expect(await replay(), 0);
        final protected = (await database.pendingOpsDao.getOp(sent.id))!;
        expect(protected.state, 'recovery_required');
        expect(protected.lastErrorCode, 'completion_outcome_unknown');
        await expectLater(
          PendingOpResolutionService(
            database: database,
            apiClient: remote,
            accountId: 'account',
            syncTasks: () async {},
            syncCalendar: () async {},
          ).retryNow(sent.id),
          throwsStateError,
        );
        expect(graph.updates, 1);
      },
    );
  }

  for (final fullUpdate in [false, true]) {
    for (final rejectedRead in [false, true]) {
      for (final diverged in [false, true]) {
        test(
          '${rejectedRead ? 'S02' : 'R05'} ${fullUpdate ? 'PUT' : 'PATCH'} retains prior dispatch through ${rejectedRead ? 'a permission-denied' : 'an unsent'} reconciliation read (diverged $diverged)',
          () async {
            final directory = await createPersistenceTestDirectory(
              'busymax-write-evidence-',
            );
            final file = File('${directory.path}/tasks.sqlite');
            final previousWarning =
                driftRuntimeOptions.dontWarnAboutMultipleDatabases;
            driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
            var disk = AppDatabase(NativeDatabase(file));
            final provider = _LifecycleTaskRemoteClient();
            try {
              await _insertAccount(disk);
              await disk.taskListsDao.upsertTaskList(_taskList('list-1'));
              final original = _taskDto(
                'task-1',
                title: 'A',
                notes: 'N',
                updated: DateTime.utc(2026, 6, 4),
              );
              provider.members['list-1'] = {'task-1': original};
              await disk.tasksDao.upsertTask(
                taskFromDto('account', 'list-1', original, _now),
              );
              final repository = TasksRepository(
                database: disk,
                accountId: 'account',
              );
              if (fullUpdate) {
                await repository.updateTaskFull(
                  'list-1',
                  'task-1',
                  const TaskPutInput({'title': 'B'}),
                );
              } else {
                await repository.patchTask(
                  'list-1',
                  'task-1',
                  const TaskPatchInput({'title': 'B'}),
                );
              }
              await repository.patchTask(
                'list-1',
                'task-1',
                const TaskPatchInput({'notes': 'L'}),
              );
              provider.loseNextPatchResponse = true;
              Future<int> replay(int hour) => PendingOpsReplayer(
                database: disk,
                apiClient: provider,
                accountId: 'account',
                nowUtc: () => DateTime.utc(2026, 6, 4, hour),
              ).replayDueOps();
              expect(await replay(1), 0);
              final sent = (await disk.select(disk.pendingOps).get())
                  .singleWhere(
                    (op) =>
                        op.operation ==
                            (fullUpdate ? 'update_task' : 'patch_task') &&
                        jsonDecode(op.requestJson)['title'] == 'B',
                  );
              expect(sent.state, 'in_progress');
              provider.nextGetError = rejectedRead
                  ? GoogleTasksApiError.fromResponse(
                      statusCode: 403,
                      body: jsonEncode({
                        'error': {
                          'code': 403,
                          'status': 'PERMISSION_DENIED',
                          'message': 'QA permission denied',
                        },
                      }),
                    )
                  : const KnownUnsentRequestException(
                      kind: RequestPreDispatchFailureKind.connectivity,
                    );
              expect(await replay(3), 0);
              final afterReadFailure = await disk.pendingOpsDao.getOp(sent.id);
              expect(afterReadFailure!.state, 'in_progress');
              expect(afterReadFailure.requestJson, sent.requestJson);
              expect(afterReadFailure.baselineRawJson, sent.baselineRawJson);
              if (rejectedRead) {
                expect(afterReadFailure.lastErrorCode, '403');
                expect(
                  afterReadFailure.lastErrorMessage,
                  'QA permission denied',
                );
                expect(
                  afterReadFailure.nextAttemptAtUtc,
                  startsWith('9999-12-31'),
                );
                expect(
                  await disk.pendingOpsDao.watchBlockedOps('account').first,
                  hasLength(1),
                );
              }
              await disk.close();
              disk = AppDatabase(NativeDatabase(file));
              if (diverged) {
                provider.members['list-1']!['task-1'] = TaskDto.fromJson({
                  ...provider.members['list-1']!['task-1']!.rawJson,
                  'title': 'Remote C',
                  'updated': '2026-06-04T04:00:00.000Z',
                });
              }
              var syncRequests = 0;
              final resolution = PendingOpResolutionService(
                database: disk,
                apiClient: provider,
                accountId: 'account',
                syncTasks: () async {
                  syncRequests++;
                },
                syncCalendar: () async {},
                nowUtc: () => DateTime.utc(2026, 6, 4, 5),
              );
              if (rejectedRead) {
                await (disk.update(
                  disk.accounts,
                )..where((row) => row.id.equals('account'))).write(
                  const AccountsCompanion(
                    authState: Value(accountAuthStateReauthRequired),
                  ),
                );
                await expectLater(
                  resolution.retryNow(sent.id),
                  throwsA(isA<AccountNotSyncEligibleException>()),
                );
                expect(syncRequests, 0);
                expect(
                  (await disk.pendingOpsDao.getOp(sent.id))!.lastErrorCode,
                  '403',
                );
                await (disk.update(
                  disk.accounts,
                )..where((row) => row.id.equals('account'))).write(
                  const AccountsCompanion(authState: Value('signed_in')),
                );
              }
              await resolution.retryNow(sent.id);
              expect(syncRequests, 1);
              expect(
                (await disk.pendingOpsDao.getOp(sent.id))!.state,
                'in_progress',
              );
              await disk.close();
              disk = AppDatabase(NativeDatabase(file));
              expect(await replay(6), diverged ? 0 : 2);
              expect(provider.patchCount, diverged ? 1 : 2);
              expect(
                provider.writes.where((fields) => fields['title'] == 'B'),
                hasLength(1),
              );
              expect(
                provider.writes.where((fields) => fields['notes'] == 'L'),
                hasLength(diverged ? 0 : 1),
              );
              expect(provider.putCount, fullUpdate ? 1 : 0);
              final local = await disk.select(disk.tasks).getSingle();
              expect(local.title, 'B');
              expect(local.notes, 'L');
              if (diverged) {
                expect(
                  (await disk.pendingOpsDao.getOp(sent.id))!.lastErrorCode,
                  'conflict',
                );
                expect(
                  provider.members['list-1']!['task-1']!.title,
                  'Remote C',
                );
                expect(await disk.select(disk.pendingOps).get(), hasLength(2));
              } else {
                expect(provider.members['list-1']!['task-1']!.title, 'B');
                expect(provider.members['list-1']!['task-1']!.notes, 'L');
                expect(local.localDirty, isFalse);
                expect(await disk.select(disk.pendingOps).get(), isEmpty);
              }
            } finally {
              await disk.close();
              await directory.delete(recursive: true);
              driftRuntimeOptions.dontWarnAboutMultipleDatabases =
                  previousWarning;
            }
          },
        );
      }
    }
  }

  test(
    'R05 first mutation prevented before dispatch remains retryable',
    () async {
      final provider = _LifecycleTaskRemoteClient();
      final original = _taskDto(
        'task-1',
        title: 'A',
        updated: DateTime.utc(2026, 6, 4),
      );
      provider.members['list-1'] = {'task-1': original};
      await database.tasksDao.upsertTask(
        taskFromDto('account', 'list-1', original, _now),
      );
      await TasksRepository(
        database: database,
        accountId: 'account',
      ).patchTask('list-1', 'task-1', const TaskPatchInput({'title': 'B'}));
      provider.nextMutationError = const KnownUnsentRequestException(
        kind: RequestPreDispatchFailureKind.authentication,
      );
      Future<int> replay(int hour) => PendingOpsReplayer(
        database: database,
        apiClient: provider,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, hour),
      ).replayDueOps();
      expect(await replay(1), 0);
      expect(provider.patchCount, 0);
      expect(
        (await database.select(database.pendingOps).getSingle()).state,
        'retry',
      );
      expect(await replay(3), 1);
      expect(provider.patchCount, 1);
      expect(provider.members['list-1']!['task-1']!.title, 'B');
    },
  );

  for (final fullUpdate in [false, true]) {
    for (final matchingRemote in [false, true]) {
      test(
        'S02 first rejected ${fullUpdate ? 'PUT' : 'PATCH'} is not uncertain (matching remote $matchingRemote)',
        () async {
          final provider = _LifecycleTaskRemoteClient();
          final original = _taskDto(
            'task-1',
            title: 'A',
            updated: DateTime.utc(2026, 6, 4),
          );
          provider.members['list-1'] = {'task-1': original};
          await database.tasksDao.upsertTask(
            taskFromDto('account', 'list-1', original, _now),
          );
          final repository = TasksRepository(
            database: database,
            accountId: 'account',
          );
          if (fullUpdate) {
            await repository.updateTaskFull(
              'list-1',
              'task-1',
              const TaskPutInput({'title': 'B'}),
            );
          } else {
            await repository.patchTask(
              'list-1',
              'task-1',
              const TaskPatchInput({'title': 'B'}),
            );
          }
          provider.nextMutationError = GoogleTasksApiError.fromResponse(
            statusCode: 403,
            body: '{"error":{"code":403,"status":"PERMISSION_DENIED","message":"QA write rejected"}}',
          );
          Future<int> replay(int hour) => PendingOpsReplayer(
            database: database,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, hour),
          ).replayDueOps();
          expect(await replay(1), 0);
          final rejected = await database
              .select(database.pendingOps)
              .getSingle();
          expect(rejected.state, 'failed');
          expect(rejected.lastErrorCode, '403');
          expect(provider.writes, isEmpty);
          expect(provider.members['list-1']!['task-1']!.title, 'A');
          if (matchingRemote) {
            provider.members['list-1']!['task-1'] = TaskDto.fromJson({
              ...original.rawJson,
              'title': 'B',
              'updated': '2026-06-04T02:00:00Z',
            });
          }
          await PendingOpResolutionService(
            database: database,
            apiClient: provider,
            accountId: 'account',
            syncTasks: () async {},
            syncCalendar: () async {},
            nowUtc: () => DateTime.utc(2026, 6, 4, 3),
          ).retryNow(rejected.id);
          expect(await replay(4), matchingRemote ? 0 : 1);
          expect(provider.writes, hasLength(matchingRemote ? 0 : 1));
          final local = await database.select(database.tasks).getSingle();
          expect(local.title, 'B');
          expect(local.localDirty, matchingRemote);
          if (matchingRemote) {
            expect(
              (await database.pendingOpsDao.getOp(rejected.id))!.lastErrorCode,
              'conflict',
            );
            expect(
              await database.select(database.pendingOps).get(),
              hasLength(1),
            );
          } else {
            expect(await database.select(database.pendingOps).get(), isEmpty);
          }
        },
      );
    }
    test(
      'S02 uncertain recurring ${fullUpdate ? 'PUT' : 'PATCH'} remains recovery required after HTTP 403 and Retry',
      () async {
        final directory = await createPersistenceTestDirectory(
          'busymax-s02-recurring-',
        );
        final file = File('${directory.path}/tasks.sqlite');
        final previousWarning =
            driftRuntimeOptions.dontWarnAboutMultipleDatabases;
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        var disk = AppDatabase(NativeDatabase(file));
        final provider = _LifecycleTaskRemoteClient();
        try {
          await _insertAccount(disk);
          await disk
              .update(disk.accounts)
              .write(const AccountsCompanion(provider: Value('microsoft')));
          await disk.taskListsDao.upsertTaskList(_taskList('list-1'));
          final original = TaskDto.fromJson({
            'id': 'task-1',
            'title': 'Recurring task',
            'status': 'needsAction',
            'updated': _now,
            'recurrence': {
              'pattern': {'type': 'daily', 'interval': 1},
            },
          });
          provider.members['list-1'] = {'task-1': original};
          await disk.tasksDao.upsertTask(
            taskFromDto('account', 'list-1', original, _now),
          );
          final repository = TasksRepository(
            database: disk,
            accountId: 'account',
          );
          if (fullUpdate) {
            await repository.updateTaskFull(
              'list-1',
              'task-1',
              const TaskPutInput({'status': 'completed'}),
            );
          } else {
            await repository.patchTask(
              'list-1',
              'task-1',
              const TaskPatchInput({'status': 'completed'}),
            );
          }
          Future<int> replay(int hour) => PendingOpsReplayer(
            database: disk,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, hour),
          ).replayDueOps();
          provider.loseNextPatchResponse = true;
          expect(await replay(1), 0);
          final sent = await disk.select(disk.pendingOps).getSingle();
          expect(sent.state, 'in_progress');
          provider.nextGetError = GoogleTasksApiError.fromResponse(
            statusCode: 403,
            body: '{"error":{"code":403,"status":"PERMISSION_DENIED","message":"QA read denied"}}',
          );
          expect(await replay(3), 0);
          expect(
            (await disk.pendingOpsDao.getOp(sent.id))!.state,
            'in_progress',
          );
          await PendingOpResolutionService(
            database: disk,
            apiClient: provider,
            accountId: 'account',
            syncTasks: () async {},
            syncCalendar: () async {},
            nowUtc: () => DateTime.utc(2026, 6, 4, 4),
          ).retryNow(sent.id);
          await disk.close();
          disk = AppDatabase(NativeDatabase(file));
          expect(await replay(5), 0);
          final guarded = await disk.select(disk.pendingOps).getSingle();
          expect(guarded.state, 'recovery_required');
          expect(guarded.lastErrorCode, 'completion_outcome_unknown');
          expect(guarded.requestJson, sent.requestJson);
          expect(guarded.baselineRawJson, sent.baselineRawJson);
          expect(provider.writes, hasLength(1));
          expect(provider.members['list-1']!['task-1']!.status, 'completed');
          expect(
            (await disk.select(disk.tasks).getSingle()).status,
            'completed',
          );
          await expectLater(
            PendingOpResolutionService(
              database: disk,
              apiClient: provider,
              accountId: 'account',
              syncTasks: () async {},
              syncCalendar: () async {},
              nowUtc: () => DateTime.utc(2026, 6, 4, 6),
            ).retryNow(sent.id),
            throwsStateError,
          );
          expect(await replay(7), 0);
          expect(provider.writes, hasLength(1));
        } finally {
          await disk.close();
          await directory.delete(recursive: true);
          driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning;
        }
      },
    );
  }

  for (final edit in ['rename', 'check', 'uncheck']) {
    for (final rejectedRead in [false, true]) {
      for (final remoteChange in ['none', 'untouched', 'missing']) {
        if (rejectedRead && remoteChange != 'none') continue;
        test(
          '${rejectedRead ? 'S02 checklist control' : 'R06'} Microsoft checklist $edit reconciles a lost acknowledgment after ${rejectedRead ? 'HTTP 403' : 'read failure'} and restart ($remoteChange)',
          () async {
            final directory = await createPersistenceTestDirectory(
              'busymax-checklist-ack-',
            );
            final file = File('${directory.path}/tasks.sqlite');
            final previousWarning =
                driftRuntimeOptions.dontWarnAboutMultipleDatabases;
            driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
            var disk = AppDatabase(NativeDatabase(file));
            final graph = _LostChecklistMicrosoftTodoApiClient();
            final adapter = _microsoftAdapter(graph);
            try {
              await _insertAccount(disk);
              await (disk.update(disk.accounts)
                    ..where((row) => row.id.equals('account')))
                  .write(const AccountsCompanion(provider: Value('microsoft')));
              await disk.taskListsDao.upsertTaskList(_taskList('list-1'));
              final original = <String, Object?>{
                'id': 'step',
                'displayName': 'A',
                'isChecked': edit == 'uncheck',
                'createdDateTime': _now,
                if (edit == 'uncheck') 'checkedDateTime': _now,
              };
              graph.items['step'] = original;
              graph.items['sibling'] = {
                'id': 'sibling',
                'displayName': 'Sibling',
                'isChecked': false,
              };
              await disk.tasksDao.upsertTask(
                _task(
                  'list-1',
                  'task-1',
                  checklistItemsJson: jsonEncode(graph.items.values.toList()),
                ),
              );
              final repository = TasksRepository(
                database: disk,
                accountId: 'account',
                apiClient: adapter,
              );
              await repository.patchChecklistSubtask(
                taskListId: 'list-1',
                parentTaskId: 'task-1',
                checklistItemId: 'step',
                title: edit == 'rename' ? 'B' : null,
                completed: edit == 'rename' ? null : edit == 'check',
              );
              await repository.patchChecklistSubtask(
                taskListId: 'list-1',
                parentTaskId: 'task-1',
                checklistItemId: 'step',
                title: edit == 'rename' ? null : 'Local C',
                completed: edit == 'rename' ? true : null,
              );
              final queued = await disk.select(disk.pendingOps).get();
              final first = queued.singleWhere(
                (op) => op.dependsOnOpId == null,
              );
              final dependent = queued.singleWhere((op) => op.id != first.id);
              final dependentBaseline =
                  jsonDecode(dependent.baselineRawJson!) as Map;
              Future<int> replay(int hour) => PendingOpsReplayer(
                database: disk,
                apiClient: adapter,
                accountId: 'account',
                nowUtc: () => DateTime.utc(2026, 6, 4, hour),
              ).replayDueOps();
              expect(await replay(1), 0);
              expect(graph.updates, hasLength(1));
              expect(
                (await disk.pendingOpsDao.getOp(first.id))!.state,
                'in_progress',
              );
              graph.nextSecondPageError = rejectedRead
                  ? MicrosoftTodoApiError.fromResponse(
                      statusCode: 403,
                      body: '{"error":{"code":"ErrorAccessDenied","message":"QA checklist permission denied"}}',
                    )
                  : const KnownUnsentRequestException(
                      kind: RequestPreDispatchFailureKind.connectivity,
                    );
              expect(await replay(3), 0);
              expect(
                (await disk.pendingOpsDao.getOp(first.id))!.state,
                'in_progress',
              );
              expect(graph.pages, [
                null,
                _checklistSecondPage,
                null,
                _checklistSecondPage,
              ]);
              graph.items['sibling'] = {
                ...graph.items['sibling']!,
                'displayName': 'Remote sibling',
              };
              if (remoteChange == 'missing') {
                graph.items.remove('step');
              } else if (remoteChange == 'untouched') {
                graph.items['step'] = {
                  ...graph.items['step']!,
                  if (edit == 'rename')
                    'isChecked': true
                  else
                    'displayName': 'Remote R',
                };
              }
              await disk.close();
              disk = AppDatabase(NativeDatabase(file));
              await PendingOpResolutionService(
                database: disk,
                apiClient: adapter,
                accountId: 'account',
                syncTasks: () async {},
                syncCalendar: () async {},
                nowUtc: () => DateTime.utc(2026, 6, 4, 4),
              ).retryNow(first.id);
              expect(
                await replay(5),
                remoteChange == 'none'
                    ? 2
                    : remoteChange == 'missing'
                    ? 0
                    : 1,
              );
              expect(graph.updates, hasLength(remoteChange == 'none' ? 2 : 1));
              expect(graph.items['sibling']!['displayName'], 'Remote sibling');
              final local = decodeTaskChecklistItems(
                (await disk.select(disk.tasks).getSingle())
                    .microsoftChecklistItemsJson,
              ).singleWhere((item) => item.id == 'step');
              expect(local.title, edit == 'rename' ? 'B' : 'Local C');
              expect(local.completed, edit != 'uncheck');
              if (remoteChange == 'none') {
                expect(await disk.select(disk.pendingOps).get(), isEmpty);
                expect(
                  graph.items['step']!['displayName'],
                  edit == 'rename' ? 'B' : 'Local C',
                );
                expect(graph.items['step']!['isChecked'], edit != 'uncheck');
              } else {
                final retained = await disk.pendingOpsDao.getOp(
                  remoteChange == 'missing' ? first.id : dependent.id,
                );
                expect(retained!.lastErrorCode, 'conflict');
                if (remoteChange == 'untouched') {
                  final baseline = jsonDecode(retained.baselineRawJson!) as Map;
                  final untouched = edit == 'rename'
                      ? 'isChecked'
                      : 'displayName';
                  expect(baseline[untouched], dependentBaseline[untouched]);
                  expect(retained.requestJson, dependent.requestJson);
                  expect(await disk.pendingOpsDao.getOp(first.id), isNull);
                }
              }
            } finally {
              await disk.close();
              await directory.delete(recursive: true);
              driftRuntimeOptions.dontWarnAboutMultipleDatabases =
                  previousWarning;
            }
          },
        );
      }
    }
  }

  test('R05 unsent reconciliation read retains uncertain recurring completion protection', () async {
    await (database.update(database.accounts)
          ..where((row) => row.id.equals('account')))
        .write(const AccountsCompanion(provider: Value('microsoft')));
    final provider = _LifecycleTaskRemoteClient();
    final original = TaskDto.fromJson({
      'id': 'task-1',
      'title': 'Recurring task',
      'status': 'needsAction',
      'updated': _now,
      'recurrence': {
        'pattern': {'type': 'daily', 'interval': 1},
      },
    });
    provider.members['list-1'] = {'task-1': original};
    await database.tasksDao.upsertTask(
      taskFromDto('account', 'list-1', original, _now),
    );
    await TasksRepository(database: database, accountId: 'account').patchTask(
      'list-1',
      'task-1',
      const TaskPatchInput({'status': 'completed'}),
    );
    provider.loseNextPatchResponse = true;
    Future<int> replay(int hour) => PendingOpsReplayer(
      database: database,
      apiClient: provider,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4, hour),
    ).replayDueOps();
    expect(await replay(1), 0);
    provider.nextGetError = const KnownUnsentRequestException(
      kind: RequestPreDispatchFailureKind.authentication,
    );
    expect(await replay(3), 0);
    final retained = await database.select(database.pendingOps).getSingle();
    expect(retained.state, 'in_progress');
    expect(await replay(5), 0);
    expect(provider.patchCount, 1);
    final protected = await database.select(database.pendingOps).getSingle();
    expect(protected.state, 'recovery_required');
    expect(protected.lastErrorCode, 'completion_outcome_unknown');
    expect(protected.requestJson, retained.requestJson);
  });

  test('R06 Microsoft checklist acknowledgment and dependent projection commit together', () async {
    final directory = await createPersistenceTestDirectory(
      'busymax-checklist-ack-transaction-',
    );
    final file = File('${directory.path}/tasks.sqlite');
    final previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final barrier = _CommitInterruption();
    final disk = AppDatabase(NativeDatabase(file).interceptWith(barrier));
    AppDatabase? reopened;
    Future<int>? interrupted;
    final graph = _LostChecklistMicrosoftTodoApiClient();
    final adapter = _microsoftAdapter(graph);
    try {
      await _insertAccount(disk);
      await (disk.update(disk.accounts)
            ..where((row) => row.id.equals('account')))
          .write(const AccountsCompanion(provider: Value('microsoft')));
      await disk.taskListsDao.upsertTaskList(_taskList('list-1'));
      graph.items['step'] = {
        'id': 'step',
        'displayName': 'A',
        'isChecked': false,
      };
      graph.items['sibling'] = {
        'id': 'sibling',
        'displayName': 'Sibling',
        'isChecked': false,
      };
      await disk.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          checklistItemsJson: jsonEncode(graph.items.values.toList()),
        ),
      );
      final repository = TasksRepository(
        database: disk,
        accountId: 'account',
        apiClient: adapter,
      );
      await repository.patchChecklistSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        checklistItemId: 'step',
        title: 'B',
      );
      await repository.patchChecklistSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        checklistItemId: 'step',
        completed: true,
      );
      final queued = await disk.select(disk.pendingOps).get();
      final first = queued.singleWhere((op) => op.dependsOnOpId == null);
      final dependent = queued.singleWhere((op) => op.id != first.id);
      expect(
        await PendingOpsReplayer(
          database: disk,
          apiClient: adapter,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        0,
      );
      barrier.arm();
      interrupted = PendingOpsReplayer(
        database: disk,
        apiClient: adapter,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 3),
      ).replayDueOps();
      await barrier.commitReached.future;
      reopened = AppDatabase(NativeDatabase(file));
      expect(await reopened.pendingOpsDao.getOp(first.id), isNull);
      final retained = await reopened.pendingOpsDao.getOp(dependent.id);
      expect(jsonDecode(retained!.baselineRawJson!)['displayName'], 'B');
      expect(jsonDecode(retained.baselineRawJson!)['isChecked'], false);
      expect(retained.requestJson, dependent.requestJson);
      final local = decodeTaskChecklistItems(
        (await reopened.select(reopened.tasks).getSingle())
            .microsoftChecklistItemsJson,
      ).singleWhere((item) => item.id == 'step');
      expect(local.title, 'B');
      expect(local.completed, isTrue);
      expect(
        await PendingOpsReplayer(
          database: reopened,
          apiClient: adapter,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 4),
        ).replayDueOps(),
        1,
      );
      expect(graph.updates, [
        {'displayName': 'B'},
        {'isChecked': true},
      ]);
      expect(await reopened.select(reopened.pendingOps).get(), isEmpty);
      barrier.resume();
      expect(await interrupted, 1);
    } finally {
      barrier.resume();
      await interrupted;
      await reopened?.close();
      await disk.close();
      await directory.delete(recursive: true);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning;
    }
  });

  for (final chain in [
    'clear-delete-list',
    'delete-child-delete-list',
    'move-clear-destination',
  ]) {
    for (final blocked in [false, true]) {
      test(
        'R08 Google $chain waits for ${blocked ? 'blocked' : 'deferred'} predecessor across restart and acknowledges only its own effects',
        () async {
          final directory = await createPersistenceTestDirectory(
            'busymax-destructive-chain-',
          );
          final file = File('${directory.path}/tasks.sqlite');
          final previousWarning =
              driftRuntimeOptions.dontWarnAboutMultipleDatabases;
          driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
          var disk = AppDatabase(NativeDatabase(file));
          final provider = _GoogleLifecycleTaskRemoteClient();
          try {
            await _insertAccount(disk);
            for (final listId in ['list-1', 'list-2']) {
              await disk.taskListsDao.upsertTaskList(_taskList(listId));
              provider.members[listId] = {};
            }
            final original = TaskDto.fromJson({
              'id': 'task-1',
              'title': 'A',
              'notes': 'N',
              'status': chain == 'delete-child-delete-list'
                  ? 'needsAction'
                  : 'completed',
              'hidden': false,
              'updated': _now,
            });
            provider.members['list-1']!['task-1'] = original;
            final other = _taskDto(
              'other',
              title: 'Other',
              status: 'needsAction',
              updated: DateTime.utc(2026, 6, 4),
            );
            provider.members[chain == 'move-clear-destination'
                    ? 'list-2'
                    : 'list-1']!['other'] =
                other;
            await disk.tasksDao.upsertTask(
              taskFromDto('account', 'list-1', original, _now),
            );
            await disk.tasksDao.upsertTask(
              taskFromDto(
                'account',
                chain == 'move-clear-destination' ? 'list-2' : 'list-1',
                other,
                _now,
              ),
            );
            final repository = TasksRepository(
              database: disk,
              accountId: 'account',
            );
            if (chain == 'clear-delete-list') {
              await repository.clearCompleted('list-1');
            } else if (chain == 'delete-child-delete-list') {
              await repository.deleteTask('list-1', 'task-1');
            } else {
              await repository.moveTask(
                const TaskMoveInput(
                  sourceTaskListId: 'list-1',
                  taskId: 'task-1',
                  destinationTaskListId: 'list-2',
                ),
              );
            }
            if (chain == 'move-clear-destination') {
              await repository.clearCompleted('list-2');
            } else {
              await TaskListsRepository(
                database: disk,
                accountId: 'account',
              ).deleteTaskList('list-1');
            }
            final operations = await disk.select(disk.pendingOps).get();
            final first = operations.singleWhere(
              (op) =>
                  op.operation ==
                  (chain == 'clear-delete-list'
                      ? 'clear_completed_tasks'
                      : chain == 'delete-child-delete-list'
                      ? 'delete_task'
                      : 'move_task'),
            );
            final following = operations.singleWhere((op) => op.id != first.id);
            await (disk.update(
              disk.pendingOps,
            )..where((row) => row.id.equals(first.id))).write(
              PendingOpsCompanion(
                nextAttemptAtUtc: Value(
                  blocked
                      ? '9999-12-31T00:00:00.000Z'
                      : '2026-06-09T00:00:00.000Z',
                ),
                state: Value(blocked ? 'failed' : 'retry'),
              ),
            );
            Future<int> replay() => PendingOpsReplayer(
              database: disk,
              apiClient: provider,
              accountId: 'account',
              nowUtc: () => DateTime.utc(2026, 6, 4, 6),
            ).replayDueOps();
            expect(await replay(), 0);
            expect(provider.effects, isEmpty);
            expect(
              (await disk.pendingOpsDao.getOp(following.id))!.requestJson,
              following.requestJson,
            );
            await disk.close();
            disk = AppDatabase(NativeDatabase(file));
            expect(await replay(), 0);
            await PendingOpResolutionService(
              database: disk,
              apiClient: provider,
              accountId: 'account',
              syncTasks: () async {},
              syncCalendar: () async {},
              nowUtc: () => DateTime.utc(2026, 6, 4, 5),
            ).retryNow(first.id);
            expect(await replay(), 2);
            expect(await disk.select(disk.pendingOps).get(), isEmpty);
            if (chain == 'move-clear-destination') {
              expect(provider.effects, [
                'move:task-1:list-1:list-2',
                'clear:list-2',
              ]);
              expect(provider.members['list-1'], isEmpty);
              expect(provider.members['list-2']!['task-1']!.hidden, isTrue);
              expect(
                (await disk.select(disk.tasks).get())
                    .singleWhere((task) => task.id == 'task-1')
                    .hidden,
                isTrue,
              );
            } else {
              expect(provider.deletedLists, ['list-1']);
              expect(provider.effects, [
                chain == 'clear-delete-list' ? 'clear:list-1' : 'delete:task-1',
                'delete-list:list-1',
              ]);
              expect(provider.sawHidden, chain == 'clear-delete-list');
              expect(
                provider.sawTombstone,
                chain == 'delete-child-delete-list',
              );
            }
            expect(
              provider.pageReads.any((request) => request.endsWith(':1')),
              isTrue,
            );
          } finally {
            await disk.close();
            await directory.delete(recursive: true);
            driftRuntimeOptions.dontWarnAboutMultipleDatabases =
                previousWarning;
          }
        },
      );
    }
  }

  for (final chain in [
    'clear-delete-list',
    'delete-child-delete-list',
    'move-clear-destination',
  ]) {
    test(
      'R08 Google $chain commits predecessor acknowledgment and approved snapshots together',
      () async {
        final directory = await createPersistenceTestDirectory(
          'busymax-destructive-ack-transaction-',
        );
        final file = File('${directory.path}/tasks.sqlite');
        final previousWarning =
            driftRuntimeOptions.dontWarnAboutMultipleDatabases;
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        final barrier = _CommitInterruption();
        final disk = AppDatabase(NativeDatabase(file).interceptWith(barrier));
        AppDatabase? reopened;
        Future<int>? interrupted;
        final provider = _GoogleLifecycleTaskRemoteClient();
        try {
          final (first, following) = await _queueGoogleDestructiveChain(
            disk,
            provider,
            chain,
          );
          barrier.arm();
          interrupted = PendingOpsReplayer(
            database: disk,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 3),
          ).replayDueOps();
          await barrier.commitReached.future;
          reopened = AppDatabase(NativeDatabase(file));
          expect(await reopened.pendingOpsDao.getOp(first.id), isNull);
          final retained = await reopened.pendingOpsDao.getOp(following.id);
          expect(retained, isNot(isNull));
          final request = jsonDecode(retained!.requestJson) as Map;
          final approved =
              request[chain == 'move-clear-destination'
                      ? '_busymaxCompletedTaskBaselines'
                      : '_busymaxChildTaskConflictBaselines']
                  as Map;
          final rows = await reopened.select(reopened.tasks).get();
          if (chain == 'delete-child-delete-list') {
            expect(approved.containsKey('task-1'), isFalse);
            expect(rows.where((task) => task.id == 'task-1'), isEmpty);
            expect(provider.members['list-1']!['task-1']!.deleted, isTrue);
          } else {
            final raw = (approved['task-1'] as Map)['rawJson'] as Map;
            expect(raw['notes'], 'N');
            final local = rows.singleWhere((task) => task.id == 'task-1');
            if (chain == 'clear-delete-list') {
              expect(raw['hidden'], isTrue);
              expect(local.hidden, isTrue);
              expect(jsonDecode(local.rawJson)['hidden'], isTrue);
            } else {
              expect(
                (approved['task-1'] as Map)['updatedUtc'],
                provider.members['list-2']!['task-1']!.updated!
                    .toIso8601String(),
              );
              expect(local.taskListId, 'list-2');
            }
          }
          expect(provider.effects, hasLength(1));
          expect(
            await PendingOpsReplayer(
              database: reopened,
              apiClient: provider,
              accountId: 'account',
              nowUtc: () => DateTime.utc(2026, 6, 4, 4),
            ).replayDueOps(),
            1,
          );
          expect(provider.effects, hasLength(2));
          expect(await reopened.select(reopened.pendingOps).get(), isEmpty);
          barrier.resume();
          expect(await interrupted, 1);
        } finally {
          barrier.resume();
          await interrupted;
          await reopened?.close();
          await disk.close();
          await directory.delete(recursive: true);
          driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning;
        }
      },
    );
  }

  for (final remoteNotesChanged in [false, true]) {
    test(
      'R08 related list deletion after clear acknowledgment preserves its known hidden effect (remote notes $remoteNotesChanged)',
      () async {
        final provider = _GoogleLifecycleTaskRemoteClient();
        final original = TaskDto.fromJson({
          'id': 'task-1',
          'title': 'A',
          'notes': 'N',
          'status': 'completed',
          'hidden': false,
          'updated': _now,
        });
        provider.members['list-1'] = {'task-1': original};
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', original, _now),
        );
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
        );
        Future<int> replay() => PendingOpsReplayer(
          database: database,
          apiClient: provider,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 6),
        ).replayDueOps();
        await repository.clearCompleted('list-1');
        expect(await replay(), 1);
        if (remoteNotesChanged) {
          provider.members['list-1']!['task-1'] = TaskDto.fromJson({
            ...provider.members['list-1']!['task-1']!.rawJson,
            'notes': 'Remote R',
            'updated': '2026-06-04T03:00:00.000Z',
          });
        }
        await TaskListsRepository(
          database: database,
          accountId: 'account',
        ).deleteTaskList('list-1');
        expect(await replay(), remoteNotesChanged ? 0 : 1);
        if (remoteNotesChanged) {
          final retained = await database
              .select(database.pendingOps)
              .getSingle();
          expect(retained.lastErrorCode, 'conflict');
          final baseline =
              (jsonDecode(
                        retained.requestJson,
                      )['_busymaxChildTaskConflictBaselines']
                      as Map)['task-1']
                  as Map;
          expect((baseline['rawJson'] as Map)['notes'], 'N');
          expect(provider.deletedLists, isEmpty);
          expect(provider.members['list-1']!['task-1']!.notes, 'Remote R');
        } else {
          expect(provider.deletedLists, ['list-1']);
          expect(await database.select(database.pendingOps).get(), isEmpty);
        }
      },
    );
  }

  for (final changedNotes in [false, true]) {
    test(
      'R08 related incoming move retains the approved destination deletion notes baseline (remote notes $changedNotes)',
      () async {
        final provider = _GoogleLifecycleTaskRemoteClient();
        provider.members['list-1'] = {};
        provider.members['list-2'] = {};
        await database.taskListsDao.upsertTaskList(_taskList('list-2'));
        final original = TaskDto.fromJson({
          'id': 'task-1',
          'title': 'A',
          'notes': 'N',
          'status': 'needsAction',
          'hidden': false,
          'updated': _now,
        });
        provider.members['list-1']!['task-1'] = original;
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', original, _now),
        );
        await TasksRepository(
          database: database,
          accountId: 'account',
        ).moveTask(
          const TaskMoveInput(
            sourceTaskListId: 'list-1',
            taskId: 'task-1',
            destinationTaskListId: 'list-2',
          ),
        );
        await TaskListsRepository(
          database: database,
          accountId: 'account',
        ).deleteTaskList('list-2');
        if (changedNotes) {
          provider.afterMove = (listId) {
            provider.members[listId]!['task-1'] = TaskDto.fromJson({
              ...provider.members[listId]!['task-1']!.rawJson,
              'notes': 'Remote R',
              'updated': '2026-06-04T03:00:00.000Z',
            });
          };
        }
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 6),
          ).replayDueOps(),
          changedNotes ? 1 : 2,
        );
        if (changedNotes) {
          final retained = await database
              .select(database.pendingOps)
              .getSingle();
          expect(retained.lastErrorCode, 'conflict');
          final approved =
              (jsonDecode(
                        retained.requestJson,
                      )['_busymaxChildTaskConflictBaselines']
                      as Map)['task-1']
                  as Map;
          expect((approved['rawJson'] as Map)['notes'], 'N');
          expect(provider.deletedLists, isEmpty);
          expect(provider.members['list-2']!['task-1']!.notes, 'Remote R');
        } else {
          expect(provider.deletedLists, ['list-2']);
          expect(await database.select(database.pendingOps).get(), isEmpty);
        }
      },
    );
  }

  for (final change in [
    'notes',
    'clear-notes',
    'new-live-child',
    'new-completed',
  ]) {
    test(
      'R08 Google own acknowledgment retains the $change negative control',
      () async {
        final provider = _GoogleLifecycleTaskRemoteClient();
        provider.members['list-1'] = {};
        provider.members['list-2'] = {};
        await database.taskListsDao.upsertTaskList(_taskList('list-2'));
        final original = TaskDto.fromJson({
          'id': 'task-1',
          'title': 'A',
          'notes': 'N',
          'status': 'completed',
          'hidden': false,
          'updated': _now,
        });
        provider.members['list-1']!['task-1'] = original;
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', original, _now),
        );
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
        );
        if (change == 'new-live-child' || change == 'clear-notes') {
          await repository.clearCompleted('list-1');
          await TaskListsRepository(
            database: database,
            accountId: 'account',
          ).deleteTaskList('list-1');
          provider.afterClear = (listId) {
            if (change == 'clear-notes') {
              provider.members[listId]!['task-1'] = TaskDto.fromJson({
                ...provider.members[listId]!['task-1']!.rawJson,
                'notes': 'Remote R',
                'updated': '2026-06-04T03:00:00.000Z',
              });
              return;
            }
            provider.members[listId]!['remote-child'] = _taskDto(
              'remote-child',
              title: 'Remote child',
              status: 'needsAction',
              updated: DateTime.utc(2026, 6, 4, 2),
            );
          };
        } else {
          await repository.moveTask(
            const TaskMoveInput(
              sourceTaskListId: 'list-1',
              taskId: 'task-1',
              destinationTaskListId: 'list-2',
            ),
          );
          await repository.clearCompleted('list-2');
          provider.afterMove = (listId) {
            if (change == 'notes') {
              provider.members[listId]!['task-1'] = TaskDto.fromJson({
                ...provider.members[listId]!['task-1']!.rawJson,
                'notes': 'Remote R',
                'updated': '2026-06-04T03:00:00.000Z',
              });
            } else {
              provider.members[listId]!['remote-completed'] = _taskDto(
                'remote-completed',
                title: 'Remote completed',
                status: 'completed',
                updated: DateTime.utc(2026, 6, 4, 3),
              );
            }
          };
        }
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 6),
          ).replayDueOps(),
          1,
        );
        final retained = await database.select(database.pendingOps).getSingle();
        expect(retained.lastErrorCode, 'conflict');
        if (change == 'new-live-child' || change == 'clear-notes') {
          expect(provider.deletedLists, isEmpty);
          if (change == 'clear-notes') {
            expect(provider.members['list-1']!['task-1']!.notes, 'Remote R');
            final entry =
                (jsonDecode(
                          retained.requestJson,
                        )['_busymaxChildTaskConflictBaselines']
                        as Map)['task-1']
                    as Map;
            expect((entry['rawJson'] as Map)['notes'], 'N');
          } else {
            expect(provider.members['list-1']!['remote-child'], isNot(isNull));
          }
        } else {
          expect(provider.clearCount, 0);
          expect(provider.members['list-2']!['task-1']!.hidden, isFalse);
          final baseline =
              (jsonDecode(
                        retained.requestJson,
                      )['_busymaxCompletedTaskBaselines']
                      as Map)['task-1']
                  as Map;
          expect((baseline['rawJson'] as Map)['notes'], 'N');
        }
      },
    );
  }

  for (final action in ['rename', 'delete', 'complete', 'missing', 'sibling']) {
    test(
      'F06 checklist $action checks the observed item through all provider pages',
      () async {
        final provider = _StatefulChecklistTaskRemoteClient();
        const baseline = {'id': 'step', 'displayName': 'A', 'isChecked': false};
        provider.items['sibling'] = {
          'id': 'sibling',
          'displayName': action == 'sibling' ? 'Remote sibling' : 'Sibling',
          'isChecked': false,
        };
        if (action != 'missing') {
          provider.items['step'] = {
            ...baseline,
            'displayName': action == 'sibling' ? 'A' : 'Remote B',
          };
        }
        final deleting = action == 'delete';
        final desired = action == 'complete'
            ? {'isChecked': true}
            : {'displayName': 'Local C'};
        await database.tasksDao.upsertTask(
          _task(
            'list-1',
            'task-1',
            checklistItemsJson: jsonEncode([
              if (!deleting) {...baseline, ...desired},
              provider.items['sibling'],
            ]),
          ),
        );
        await _enqueue(
          database,
          id: '01',
          operation: deleting
              ? 'delete_task_checklist_item'
              : 'patch_task_checklist_item',
          entityType: 'task_checklist_item',
          taskListId: 'list-1',
          taskId: 'task-1',
          baselineRawJson: jsonEncode(baseline),
          request: {'checklistItemId': 'step', if (!deleting) 'body': desired},
        );
        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: provider,
          accountId: 'account',
        ).replayDueOps();
        expect(provider.pages, [null, 'second']);
        if (action == 'complete' || action == 'sibling') {
          expect(applied, 1);
          expect(provider.items['step'], {
            ...baseline,
            'displayName': action == 'sibling' ? 'Local C' : 'Remote B',
            'isChecked': action != 'sibling',
          });
          expect(provider.writes, ['update:step']);
        } else {
          expect(applied, 0);
          expect(provider.writes, isEmpty);
          final retained = await database
              .select(database.pendingOps)
              .getSingle();
          expect(retained.lastErrorCode, 'conflict');
          expect(jsonDecode(retained.baselineRawJson!), baseline);
          expect(
            jsonDecode(retained.requestJson)['body'],
            deleting ? isNull : desired,
          );
        }
        expect(
          provider.items['sibling']!['displayName'],
          action == 'sibling' ? 'Remote sibling' : 'Sibling',
        );
        final visible = decodeTaskChecklistItems(
          (await database.select(database.tasks).getSingle())
              .microsoftChecklistItemsJson,
        );
        if (action == 'complete') {
          expect(
            visible.singleWhere((item) => item.id == 'step').title,
            'Remote B',
          );
        } else if (!deleting) {
          expect(
            visible.singleWhere((item) => item.id == 'step').title,
            'Local C',
          );
        }
      },
    );
  }

  test(
    'F01 deferred move and source deletion survive a database restart',
    () async {
      final directory = await createPersistenceTestDirectory(
        'busymax-list-move-barrier-',
      );
      final file = File('${directory.path}/tasks.sqlite');
      final previousDatabaseWarning =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      var disk = AppDatabase(NativeDatabase(file));
      final provider = _LifecycleTaskRemoteClient();
      try {
        await _insertAccount(disk);
        await disk.taskListsDao.upsertTaskList(
          _taskList('list-1', updatedUtc: '2026-06-04T00:10:00.000Z'),
        );
        await disk.taskListsDao.upsertTaskList(_taskList('list-2'));
        final task = _taskDto('task-1', updated: DateTime.utc(2026, 6, 4));
        provider.members['list-1'] = {'task-1': task};
        provider.members['list-2'] = {};
        await disk.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', task, _now),
        );
        await TasksRepository(database: disk, accountId: 'account').moveTask(
          const TaskMoveInput(
            sourceTaskListId: 'list-1',
            taskId: 'task-1',
            destinationTaskListId: 'list-2',
          ),
        );
        final move = await disk.select(disk.pendingOps).getSingle();
        await (disk.update(
          disk.pendingOps,
        )..where((row) => row.id.equals(move.id))).write(
          const PendingOpsCompanion(
            nextAttemptAtUtc: Value('2026-06-05T00:00:00.000Z'),
          ),
        );
        await TaskListsRepository(
          database: disk,
          accountId: 'account',
        ).deleteTaskList('list-1');
        await disk.close();
        disk = AppDatabase(NativeDatabase(file));
        expect(
          await PendingOpsReplayer(
            database: disk,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 1),
          ).replayDueOps(),
          0,
        );
        expect(provider.deletedLists, isEmpty);
        expect(
          (await disk.select(disk.tasks).getSingle()).taskListId,
          'list-2',
        );
        expect(
          await PendingOpsReplayer(
            database: disk,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 5, 1),
          ).replayDueOps(),
          2,
        );
        expect(provider.deletedLists, ['list-1']);
        expect(provider.members['list-2']!.keys, ['task-1']);
      } finally {
        await disk.close();
        await directory.delete(recursive: true);
        driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousDatabaseWarning;
      }
    },
  );

  test(
    'F14 several offline completions wait for a deferred member across restart',
    () async {
      final directory = await createPersistenceTestDirectory(
        'busymax-clear-barrier-',
      );
      final file = File('${directory.path}/tasks.sqlite');
      final previousDatabaseWarning =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      var disk = AppDatabase(NativeDatabase(file));
      final provider = _LifecycleTaskRemoteClient();
      try {
        await _insertAccount(disk);
        await disk.taskListsDao.upsertTaskList(_taskList('list-1'));
        provider.members['list-1'] = {};
        final repository = TasksRepository(
          database: disk,
          accountId: 'account',
        );
        for (final id in ['one', 'two']) {
          final task = _taskDto(
            id,
            status: 'needsAction',
            updated: DateTime.utc(2026, 6, 4),
          );
          provider.members['list-1']![id] = task;
          await disk.tasksDao.upsertTask(
            taskFromDto('account', 'list-1', task, _now),
          );
          await repository.patchTask(
            'list-1',
            id,
            const TaskPatchInput({'status': 'completed'}),
          );
        }
        final deferred = (await disk.select(disk.pendingOps).get()).singleWhere(
          (op) => op.taskId == 'two',
        );
        await (disk.update(
          disk.pendingOps,
        )..where((row) => row.id.equals(deferred.id))).write(
          const PendingOpsCompanion(
            nextAttemptAtUtc: Value('2026-06-05T00:00:00.000Z'),
          ),
        );
        await repository.clearCompleted('list-1');
        expect(
          await PendingOpsReplayer(
            database: disk,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 1),
          ).replayDueOps(),
          1,
        );
        expect(provider.clearCount, 0);
        await disk.close();
        disk = AppDatabase(NativeDatabase(file));
        expect(
          await PendingOpsReplayer(
            database: disk,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 2),
          ).replayDueOps(),
          0,
        );
        expect(provider.clearCount, 0);
        expect(
          await PendingOpsReplayer(
            database: disk,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 5),
          ).replayDueOps(),
          2,
        );
        expect(provider.clearCount, 1);
        expect(
          provider.members['list-1']!.values.every(
            (task) => task.hidden == true,
          ),
          isTrue,
        );
      } finally {
        await disk.close();
        await directory.delete(recursive: true);
        driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousDatabaseWarning;
      }
    },
  );

  test('F14 reopening an approved task before clear replay retains the reopened task', () async {
    final provider = _LifecycleTaskRemoteClient();
    final task = _taskDto(
      'task-1',
      status: 'needsAction',
      updated: DateTime.utc(2026, 6, 4),
    );
    provider.members['list-1'] = {'task-1': task};
    await database.tasksDao.upsertTask(
      taskFromDto('account', 'list-1', task, _now),
    );
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
    );
    await repository.patchTask(
      'list-1',
      'task-1',
      const TaskPatchInput({'status': 'completed'}),
    );
    await repository.clearCompleted('list-1');
    await repository.patchTask(
      'list-1',
      'task-1',
      const TaskPatchInput({'status': 'needsAction'}),
    );
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: provider,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 3),
      ).replayDueOps(),
      2,
    );
    expect(provider.clearCount, 0);
    expect(provider.members['list-1']!['task-1']!.status, 'needsAction');
    expect(
      (await database.select(database.tasks).getSingle()).status,
      'needsAction',
    );
    expect(
      (await database.select(database.pendingOps).getSingle()).lastErrorCode,
      'conflict',
    );
  });

  test(
    'F14 reopening during the provider preflight defers clear dispatch',
    () async {
      final provider = _LifecycleTaskRemoteClient();
      final task = _taskDto(
        'task-1',
        status: 'completed',
        updated: DateTime.utc(2026, 6, 4),
      );
      provider.members['list-1'] = {'task-1': task};
      await database.tasksDao.upsertTask(
        taskFromDto('account', 'list-1', task, _now),
      );
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
      );
      await repository.clearCompleted('list-1');
      provider.onListRead = () => repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'status': 'needsAction'}),
      );
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: provider,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        0,
      );
      expect(provider.clearCount, 0);
      expect(provider.members['list-1']!['task-1']!.status, 'completed');
      expect(
        (await database.select(database.tasks).getSingle()).status,
        'needsAction',
      );
      expect(await database.select(database.pendingOps).get(), hasLength(2));
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: provider,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        1,
      );
      expect(provider.clearCount, 0);
      expect(provider.members['list-1']!['task-1']!.status, 'needsAction');
    },
  );

  test('F13 lost title acknowledgment and dependent notes survive database restart', () async {
    final directory = await createPersistenceTestDirectory(
      'busymax-patch-ack-',
    );
    final file = File('${directory.path}/tasks.sqlite');
    final previousDatabaseWarning =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    var disk = AppDatabase(NativeDatabase(file));
    final provider = _LifecycleTaskRemoteClient();
    try {
      await _insertAccount(disk);
      await disk.taskListsDao.upsertTaskList(_taskList('list-1'));
      final task = _taskDto(
        'task-1',
        title: 'A',
        notes: 'N',
        updated: DateTime.utc(2026, 6, 4),
      );
      provider.members['list-1'] = {'task-1': task};
      await disk.tasksDao.upsertTask(
        taskFromDto('account', 'list-1', task, _now),
      );
      final repository = TasksRepository(database: disk, accountId: 'account');
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'B'}),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'notes': 'L'}),
      );
      provider.loseNextPatchResponse = true;
      expect(
        await PendingOpsReplayer(
          database: disk,
          apiClient: provider,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        0,
      );
      expect(provider.patchCount, 1);
      await disk.close();
      disk = AppDatabase(NativeDatabase(file));
      expect(
        await PendingOpsReplayer(
          database: disk,
          apiClient: provider,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 3),
        ).replayDueOps(),
        2,
      );
      expect(provider.patchCount, 2);
      expect(provider.members['list-1']!['task-1']!.title, 'B');
      expect(provider.members['list-1']!['task-1']!.notes, 'L');
      final projected = await disk.select(disk.tasks).getSingle();
      expect(projected.title, 'B');
      expect(projected.notes, 'L');
      expect(projected.localDirty, isFalse);
      expect(await disk.select(disk.pendingOps).get(), isEmpty);
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases =
          previousDatabaseWarning;
    }
  });

  for (final recurring in [false, true]) {
    test(
      'F13 lost completion response ${recurring ? 'protects an uncertain recurrence' : 'acknowledges a single task'}',
      () async {
        if (recurring) {
          await (database.update(database.accounts)
                ..where((row) => row.id.equals('account')))
              .write(const AccountsCompanion(provider: Value('microsoft')));
        }
        final provider = _LifecycleTaskRemoteClient();
        final task = TaskDto.fromJson({
          'id': 'task-1',
          'title': 'A',
          'status': 'needsAction',
          'updated': _now,
          if (recurring)
            'recurrence': {
              'pattern': {'type': 'daily', 'interval': 1},
            },
        });
        provider.members['list-1'] = {'task-1': task};
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', task, _now),
        );
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
        );
        await repository.patchTask(
          'list-1',
          'task-1',
          const TaskPatchInput({'status': 'completed'}),
        );
        provider.loseNextPatchResponse = true;
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 1),
          ).replayDueOps(),
          0,
        );
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 3),
          ).replayDueOps(),
          recurring ? 0 : 1,
        );
        expect(provider.patchCount, 1);
        if (recurring) {
          final pending = await database
              .select(database.pendingOps)
              .getSingle();
          expect(pending.lastErrorCode, 'completion_outcome_unknown');
          expect(pending.state, 'recovery_required');
          expect(jsonDecode(pending.requestJson)['status'], 'completed');
          await expectLater(
            PendingOpResolutionService(
              database: database,
              apiClient: provider,
              accountId: 'account',
              syncTasks: () async {
                fail('An uncertain occurrence must not be retried.');
              },
              syncCalendar: () async {},
            ).retryNow(pending.id),
            throwsStateError,
          );
          await database.pendingOpsDao.retryNow(
            pending.id,
            DateTime.utc(2026, 6, 4, 4),
          );
          expect(
            await PendingOpsReplayer(
              database: database,
              apiClient: provider,
              accountId: 'account',
              nowUtc: () => DateTime.utc(2026, 6, 4, 5),
            ).replayDueOps(),
            0,
          );
          expect(provider.patchCount, 1);
        } else {
          expect(await database.select(database.pendingOps).get(), isEmpty);
          expect(
            (await database.select(database.tasks).getSingle()).status,
            'completed',
          );
        }
      },
    );
  }

  for (final edit in ['notes', 'reopen', 'complete', 'due']) {
    test(
      'F13 Microsoft lost $edit response uses the adapter-normalized postcondition',
      () async {
        await (database.update(database.accounts)
              ..where((row) => row.id.equals('account')))
            .write(const AccountsCompanion(provider: Value('microsoft')));
        final graph = _LostMicrosoftTodoApiClient({
          'id': 'task-1',
          'title': 'A',
          'status': edit == 'reopen' ? 'completed' : 'notStarted',
          'body': {'content': 'N', 'contentType': 'text'},
          'lastModifiedDateTime': _now,
        });
        final client = _microsoftAdapter(graph);
        final original = await client.getTask(
          taskListId: 'list-1',
          taskId: 'task-1',
        );
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', original, _now),
        );
        await TasksRepository(
          database: database,
          accountId: 'account',
          apiClient: client,
        ).patchTask(
          'list-1',
          'task-1',
          TaskPatchInput(switch (edit) {
            'notes' => {'notes': 'L <tag>\nline'},
            'complete' => {
              'status': 'completed',
              'completed': '2026-06-04T01:00:00.000Z',
            },
            'due' => {
              'microsoftDueDateTime': {
                'dateTime': '2026-07-09T09:00:00',
                'timeZone': 'UTC',
              },
            },
            _ => {'status': 'needsAction', 'completed': null},
          }),
        );
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: client,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 1),
          ).replayDueOps(),
          0,
        );
        expect(graph.updates, 1);
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: client,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 3),
          ).replayDueOps(),
          1,
        );
        expect(graph.updates, 1);
        expect(await database.select(database.pendingOps).get(), isEmpty);
        final local = await database.select(database.tasks).getSingle();
        if (edit == 'notes') {
          expect(local.notes, 'L <tag>\nline');
          expect((graph.current['body'] as Map)['contentType'], 'html');
        } else if (edit == 'reopen') {
          expect(local.status, 'needsAction');
          expect(graph.current['status'], 'notStarted');
        } else if (edit == 'complete') {
          expect(local.status, 'completed');
          expect(
            (graph.current['completedDateTime'] as Map)['dateTime'],
            '2026-06-04T01:00:00.0000000',
          );
        } else {
          expect(local.microsoftDueDateTime, '2026-07-09T09:00:00');
          expect(local.microsoftDueTimeZone, 'UTC');
        }
      },
    );
  }

  for (final extraRemoteCompletion in [false, true]) {
    test(
      'F14 offline completion then clear ${extraRemoteCompletion ? 'blocks a new remote completion' : 'acknowledges its own completion'}',
      () async {
        final provider = _LifecycleTaskRemoteClient();
        final baseline = _taskDto(
          'task-1',
          title: 'A',
          notes: 'N',
          status: 'needsAction',
          updated: DateTime.utc(2026, 6, 4),
        );
        provider.members['list-1'] = {'task-1': baseline};
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', baseline, _now),
        );
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
        );
        await repository.patchTask(
          'list-1',
          'task-1',
          const TaskPatchInput({'status': 'completed'}),
        );
        await repository.clearCompleted('list-1');
        if (extraRemoteCompletion) {
          provider.members['list-1']!['remote-new'] = _taskDto(
            'remote-new',
            status: 'completed',
            updated: DateTime.utc(2026, 6, 4, 2),
          );
        }
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 3),
          ).replayDueOps(),
          extraRemoteCompletion ? 1 : 2,
        );
        expect(provider.clearCount, extraRemoteCompletion ? 0 : 1);
        expect(provider.patchCount, 1);
        if (extraRemoteCompletion) {
          final clear = await database.select(database.pendingOps).getSingle();
          expect(clear.operation, 'clear_completed_tasks');
          expect(clear.lastErrorCode, 'conflict');
          expect(
            provider.members['list-1']!['remote-new']!.hidden,
            isNot(isTrue),
          );
        } else {
          expect(await database.select(database.pendingOps).get(), isEmpty);
          expect(provider.members['list-1']!['task-1']!.hidden, isTrue);
        }
      },
    );
  }

  for (final deferred in [false, true]) {
    test(
      'F01 source list deletion waits for ${deferred ? 'deferred' : 'rejected'} moves',
      () async {
        final provider = _LifecycleTaskRemoteClient();
        final baseline = _taskDto(
          'task-1',
          title: 'Original',
          updated: DateTime.utc(2026, 6, 4),
        );
        provider.members['list-1'] = {'task-1': baseline};
        provider.members['list-2'] = {};
        provider.moveFailures.add('task-1');
        await database.taskListsDao.upsertTaskList(
          _taskList('list-1', updatedUtc: '2026-06-04T00:10:00.000Z'),
        );
        await database.taskListsDao.upsertTaskList(_taskList('list-2'));
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', baseline, _now),
        );
        await TasksRepository(
          database: database,
          accountId: 'account',
        ).moveTask(
          const TaskMoveInput(
            sourceTaskListId: 'list-1',
            taskId: 'task-1',
            destinationTaskListId: 'list-2',
          ),
        );
        final move = await database.select(database.pendingOps).getSingle();
        if (deferred) {
          await (database.update(
            database.pendingOps,
          )..where((row) => row.id.equals(move.id))).write(
            const PendingOpsCompanion(
              nextAttemptAtUtc: Value('2026-06-05T00:00:00.000Z'),
            ),
          );
        }
        await TaskListsRepository(
          database: database,
          accountId: 'account',
        ).deleteTaskList('list-1');
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 1),
          ).replayDueOps(),
          0,
        );
        expect(provider.deletedLists, isEmpty);
        expect(provider.members['list-1']!.keys, ['task-1']);
        final retained = await database.select(database.tasks).getSingle();
        expect(retained.taskListId, 'list-2');
        expect(retained.pendingMove, isTrue);
        expect(await database.select(database.pendingOps).get(), hasLength(2));
        // Restarting the replayer must respect operations excluded from its due query.
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 2),
          ).replayDueOps(),
          0,
        );
        expect(provider.deletedLists, isEmpty);
      },
    );
  }

  test('F01 source list deletion follows every successful move and verifies remaining children', () async {
    final provider = _LifecycleTaskRemoteClient();
    provider.members['list-1'] = {};
    provider.members['list-2'] = {};
    await database.taskListsDao.upsertTaskList(
      _taskList('list-1', updatedUtc: '2026-06-04T00:10:00.000Z'),
    );
    await database.taskListsDao.upsertTaskList(_taskList('list-2'));
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
    );
    for (final id in ['one', 'two']) {
      final baseline = _taskDto(id, updated: DateTime.utc(2026, 6, 4));
      provider.members['list-1']![id] = baseline;
      await database.tasksDao.upsertTask(
        taskFromDto('account', 'list-1', baseline, _now),
      );
      await repository.moveTask(
        TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: id,
          destinationTaskListId: 'list-2',
        ),
      );
    }
    provider.moveFailures.add('two');
    await TaskListsRepository(
      database: database,
      accountId: 'account',
    ).deleteTaskList('list-1');
    final replayer = PendingOpsReplayer(
      database: database,
      apiClient: provider,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4, 1),
    );
    expect(await replayer.replayDueOps(), 1);
    expect(provider.deletedLists, isEmpty);
    expect(provider.members['list-1']!.keys, ['two']);
    provider.moveFailures.clear();
    final blocked = (await database.select(database.pendingOps).get())
        .singleWhere((op) => op.operation == 'move_task');
    await (database.update(
      database.pendingOps,
    )..where((row) => row.id.equals(blocked.id))).write(
      const PendingOpsCompanion(
        nextAttemptAtUtc: Value(null),
        state: Value('pending'),
      ),
    );
    expect(await replayer.replayDueOps(), 2);
    expect(provider.members['list-2']!.keys, containsAll(['one', 'two']));
    expect(provider.deletedLists, ['list-1']);
  });

  for (final clearing in [false, true]) {
    test(
      'F13 lost ${clearing ? 'clearing' : 'title'} response is acknowledged without rebasing unrelated notes',
      () async {
        final provider = _LifecycleTaskRemoteClient();
        final baseline = _taskDto(
          'task-1',
          title: 'A',
          notes: 'N',
          updated: DateTime.utc(2026, 6, 4),
        );
        provider.members['list-1'] = {'task-1': baseline};
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', baseline, _now),
        );
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4),
        );
        await repository.patchTask(
          'list-1',
          'task-1',
          TaskPatchInput(clearing ? {'notes': null} : {'title': 'B'}),
        );
        if (!clearing) {
          await repository.patchTask(
            'list-1',
            'task-1',
            const TaskPatchInput({'notes': 'L'}),
          );
        }
        provider.loseNextPatchResponse = true;
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: provider,
            accountId: 'account',
            random: Random(1),
            nowUtc: () => DateTime.utc(2026, 6, 4, 1),
          ).replayDueOps(),
          0,
        );
        expect(provider.patchCount, 1);
        if (!clearing) {
          provider.members['list-1']!['task-1'] = TaskDto.fromJson({
            ...provider.members['list-1']!['task-1']!.rawJson,
            'notes': 'R',
            'updated': '2026-06-04T02:00:00.000Z',
          });
        }
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: provider,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 3),
          ).replayDueOps(),
          1,
        );
        expect(provider.patchCount, 1);
        final pending = await database.select(database.pendingOps).get();
        if (clearing) {
          expect(pending, isEmpty);
          expect(
            (await database.select(database.tasks).getSingle()).notes,
            isNull,
          );
        } else {
          expect(pending, hasLength(1));
          expect(pending.single.lastErrorCode, 'conflict');
          expect(jsonDecode(pending.single.requestJson)['notes'], 'L');
          expect(jsonDecode(pending.single.baselineRawJson!)['notes'], 'N');
          expect(
            (await database.select(database.tasks).getSingle()).notes,
            'L',
          );
          expect(provider.members['list-1']!['task-1']!.notes, 'R');
        }
      },
    );
  }

  for (final chained in [false, true]) {
    test(
      'blocked Google move and dependent edit keep one optimistic task during pulls (chain: $chained)',
      () async {
        final account = await database.select(database.accounts).getSingle();
        await database
            .into(database.accounts)
            .insert(
              account
                  .toCompanion(false)
                  .copyWith(
                    id: const Value('other-account'),
                    providerAccountId: const Value('google-other-account'),
                  ),
            );
        await database.taskListsDao.upsertTaskList(
          _taskList('list-1').copyWith(accountId: const Value('other-account')),
        );
        await database.tasksDao.upsertTask(
          _task(
            'list-1',
            'task-1',
            title: 'Other account',
          ).copyWith(accountId: const Value('other-account')),
        );
        for (final list in ['list-2', 'list-3', 'unrelated']) {
          await database.taskListsDao.upsertTaskList(_taskList(list));
        }
        final baseline = _taskDto(
          'task-1',
          title: 'Original',
          updated: DateTime.utc(2026, 6, 4),
        );
        await database.tasksDao.upsertTask(
          _task(
            'list-1',
            'task-1',
            title: baseline.title,
            updatedUtc: baseline.updated!.toIso8601String(),
            rawJson: jsonEncode(baseline.rawJson),
          ),
        );
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4),
        );
        await repository.moveTask(
          const TaskMoveInput(
            sourceTaskListId: 'list-1',
            taskId: 'task-1',
            destinationTaskListId: 'list-2',
          ),
        );
        if (chained) {
          await repository.moveTask(
            const TaskMoveInput(
              sourceTaskListId: 'list-2',
              taskId: 'task-1',
              destinationTaskListId: 'list-3',
            ),
          );
        }
        final destination = chained ? 'list-3' : 'list-2';
        await repository.patchTask(
          destination,
          'task-1',
          const TaskPatchInput({'title': 'Local dependent edit'}),
        );
        apiClient.persistTaskPatches = true;
        apiClient.remoteTask = _taskDto(
          'task-1',
          title: 'Remote edit',
          updated: DateTime.utc(2026, 6, 4, 0, 5),
        );
        apiClient.remoteTaskListsPage = TaskListsPageDto(
          items: [
            for (final list in ['list-1', 'list-2', 'list-3', 'unrelated'])
              _taskListDto(list),
          ],
          rawJson: const {},
        );
        apiClient.remoteTasksPages['list-1'] = TasksPageDto(
          items: [apiClient.remoteTask!],
          rawJson: const {},
        );
        apiClient.remoteTasksPages['unrelated'] = TasksPageDto(
          items: [_taskDto('task-1', title: 'Unrelated')],
          rawJson: const {},
        );
        final engine = SyncEngine(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        );
        for (var round = 0; round < 2; round++) {
          await engine.fullSync();
          final rows = (await database.select(database.tasks).get())
              .where(
                (task) =>
                    task.accountId == 'account' &&
                    task.taskListId != 'unrelated',
              )
              .toList();
          expect(rows, hasLength(1));
          expect(rows.single.taskListId, destination);
          expect(rows.single.title, 'Local dependent edit');
          expect(rows.single.pendingMove, isTrue);
          expect(
            (await database.select(database.tasks).get())
                .singleWhere((task) => task.accountId == 'other-account')
                .title,
            'Other account',
          );
          final pending = await database.select(database.pendingOps).get();
          expect(pending, hasLength(chained ? 3 : 2));
          expect(
            pending
                .singleWhere((op) => op.taskListId == 'list-1')
                .lastErrorCode,
            'conflict',
          );
        }
        final move = (await database.select(database.pendingOps).get())
            .singleWhere((op) => op.taskListId == 'list-1');
        // The provider returns to the checked baseline; retry through the existing recovery control.
        apiClient.remoteTask = baseline;
        await PendingOpResolutionService(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          syncTasks: () => PendingOpsReplayer(
            database: database,
            apiClient: apiClient,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 2),
          ).replayDueOps(),
          syncCalendar: () async {},
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).retryNow(move.id);
        expect(await database.select(database.pendingOps).get(), isEmpty);
        apiClient.remoteTasksPages['list-1'] = const TasksPageDto(
          items: [],
          rawJson: {},
        );
        apiClient.remoteTasksPages[destination] = TasksPageDto(
          items: [apiClient.remoteTask!],
          rawJson: const {},
        );
        await engine.fullSync();
        final finalRows = (await database.select(database.tasks).get())
            .where(
              (task) =>
                  task.accountId == 'account' && task.taskListId != 'unrelated',
            )
            .toList();
        expect(finalRows, hasLength(1));
        expect(finalRows.single.taskListId, destination);
        expect(finalRows.single.localDirty, isFalse);
        expect(finalRows.single.title, 'Local dependent edit');
      },
    );
  }

  test('replay blocks legacy Docs-assigned note mutation', () async {
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'assigned',
        assignmentInfoJson: '{"surfaceType":"DOCUMENT"}',
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'patch_task',
      taskListId: 'list-1',
      taskId: 'assigned',
      request: {'notes': 'Unsupported'},
    );

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      0,
    );
    expect(apiClient.calls, isEmpty);
    expect(
      (await database.pendingOpsDao.getOp('01'))?.lastErrorCode,
      'unsupported_assigned_task',
    );
  });

  test(
    'replay blocks notes when a task became Docs-assigned remotely',
    () async {
      const baseline = {'id': 'task', 'title': 'Task'};
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task',
          updatedUtc: _now,
          rawJson: jsonEncode(baseline),
        ),
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: 'task',
        request: {'notes': 'Now forbidden'},
        baselineUpdatedUtc: _now,
        baselineRawJson: jsonEncode(baseline),
      );
      apiClient.remoteTask = TaskDto.fromJson({
        ...baseline,
        'updated': _now,
        'assignmentInfo': {'surfaceType': 'DOCUMENT'},
      });

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        0,
      );
      expect(apiClient.calls, isEmpty);
      expect(
        (await database.pendingOpsDao.getOp('01'))?.lastErrorCode,
        'unsupported_assigned_task',
      );
    },
  );

  test('replay blocks a parent that became assigned remotely', () async {
    const child = {'id': 'child', 'title': 'Child'};
    const parent = {'id': 'parent', 'title': 'Parent'};
    await database.tasksDao.upsertTask(
      _task('list-1', 'child', updatedUtc: _now, rawJson: jsonEncode(child)),
    );
    await database.tasksDao.upsertTask(
      _task('list-1', 'parent', updatedUtc: _now, rawJson: jsonEncode(parent)),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'move_task',
      taskListId: 'list-1',
      taskId: 'child',
      request: {'parent': 'parent'},
      baselineUpdatedUtc: _now,
      baselineRawJson: jsonEncode(child),
    );
    apiClient.remoteTasksById.addAll({
      'child': TaskDto.fromJson({...child, 'updated': _now}),
      'parent': TaskDto.fromJson({
        ...parent,
        'updated': _now,
        'assignmentInfo': {'surfaceType': 'SPACE'},
      }),
    });

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      0,
    );
    expect(apiClient.calls, isEmpty);
    expect(
      (await database.pendingOpsDao.getOp('01'))?.lastErrorCode,
      'unsupported_assigned_task',
    );
  });

  test('replay blocks creation below a newly assigned parent', () async {
    await database.tasksDao.upsertTask(_task('list-1', 'parent'));
    await _enqueue(
      database,
      id: '01',
      operation: 'create_task',
      taskListId: 'list-1',
      taskId: 'local-child',
      localTempId: 'local-child',
      request: {
        'parent': 'parent',
        'body': {'title': 'Child'},
      },
    );
    apiClient.remoteTasksById['parent'] = TaskDto.fromJson({
      'id': 'parent',
      'title': 'Parent',
      'assignmentInfo': {'surfaceType': 'DOCUMENT'},
    });

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      0,
    );
    expect(apiClient.calls, isEmpty);
    expect(
      (await database.pendingOpsDao.getOp('01'))?.lastErrorCode,
      'unsupported_assigned_task',
    );
  });

  test('replay blocks assigned child and assigned parent moves', () async {
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'assigned',
        assignmentInfoJson: '{"surfaceType":"SPACE"}',
      ),
    );
    await database.tasksDao.upsertTask(_task('list-1', 'ordinary'));
    await _enqueue(
      database,
      id: '01',
      operation: 'move_task',
      taskListId: 'list-1',
      taskId: 'assigned',
      request: {'parent': 'ordinary'},
    );
    await _enqueue(
      database,
      id: '02',
      operation: 'move_task',
      taskListId: 'list-1',
      taskId: 'ordinary',
      request: {'parent': 'assigned'},
    );

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      0,
    );
    expect(apiClient.calls, isEmpty);
    final ops = await database.select(database.pendingOps).get();
    expect(
      ops.map((op) => op.lastErrorCode),
      everyElement('unsupported_assigned_task'),
    );
  });

  test('replay keeps assigned top-level ordering available', () async {
    const assigned = {
      'id': 'assigned',
      'title': 'Assigned',
      'assignmentInfo': {'surfaceType': 'DOCUMENT'},
    };
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'assigned',
        updatedUtc: _now,
        rawJson: jsonEncode(assigned),
        assignmentInfoJson: jsonEncode(assigned['assignmentInfo']),
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'move_task',
      taskListId: 'list-1',
      taskId: 'assigned',
      request: {'previous': 'sibling'},
      baselineUpdatedUtc: _now,
      baselineRawJson: jsonEncode(assigned),
    );
    apiClient.remoteTask = TaskDto.fromJson({...assigned, 'updated': _now});

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      1,
    );
    expect(apiClient.calls, ['move_task:assigned']);
  });

  for (final confirmed in [false, true]) {
    test('replay ${confirmed ? 'deletes' : 'blocks'} assigned source only '
        '${confirmed ? 'with' : 'without'} recorded confirmation', () async {
      const raw = {
        'id': 'assigned',
        'title': 'Assigned',
        'assignmentInfo': {'surfaceType': 'SPACE'},
      };
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'assigned',
          updatedUtc: _now,
          rawJson: jsonEncode(raw),
          assignmentInfoJson: jsonEncode(raw['assignmentInfo']),
        ),
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'delete_task',
        taskListId: 'list-1',
        taskId: 'assigned',
        request: {if (confirmed) 'confirmedAssignedSourceDeletion': true},
        baselineUpdatedUtc: _now,
        baselineRawJson: jsonEncode(raw),
      );
      apiClient.remoteTask = TaskDto.fromJson({...raw, 'updated': _now});

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        confirmed ? 1 : 0,
      );
      expect(apiClient.calls, confirmed ? ['delete_task:assigned'] : isEmpty);
      if (!confirmed) {
        expect(
          (await database.pendingOpsDao.getOp('01'))?.lastErrorCode,
          'unsupported_assigned_task',
        );
      }
    });
  }

  for (final lifecycle in ['snoozed', 'sent', 'dismissed']) {
    test(
      'actual create replay preserves $lifecycle reminder identity',
      () async {
        await database
            .update(database.accounts)
            .write(
              const AccountsCompanion(
                provider: Value('microsoft'),
                authState: Value('signed_in'),
              ),
            );
        var now = DateTime.utc(2026, 6, 8, 8, 59);
        final reminder = DateTime.utc(2026, 6, 8, 9);
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => now,
        );
        await repository.createTask(
          'list-1',
          TaskCreateInput(
            title: 'Offline reminder',
            fields: {
              'microsoftIsReminderOn': true,
              'microsoftReminderDateTime': reminder.toIso8601String(),
              'microsoftReminderTimeZone': 'UTC',
            },
          ),
        );
        final original = await database
            .select(database.notificationSchedule)
            .getSingle();
        apiClient.createdTask = TaskDto(
          id: 'task-server',
          title: 'Offline reminder',
          status: 'needsAction',
          rawJson: {
            'isReminderOn': true,
            'reminderDateTime': {
              'dateTime': reminder.toIso8601String(),
              'timeZone': 'UTC',
            },
          },
        );
        final backend = RecordingNotificationBackend();
        NotificationScheduleData? opened;
        final scheduler = NotificationScheduler(
          database: database,
          notifications: DesktopNotificationService(
            backend: backend,
            settings: AppSettings.defaults(),
          ),
          nowUtc: () => now,
          onNotificationActivated: (row) async => opened = row,
        );
        addTearDown(scheduler.stop);
        now = reminder;
        await scheduler.checkNow();
        expect(backend.requests, hasLength(1));
        if (lifecycle != 'sent') {
          await backend.invoke(
            0,
            lifecycle == 'snoozed' ? 'snooze' : 'dismiss',
          );
        }
        final before = await database
            .select(database.notificationSchedule)
            .getSingle();
        now = reminder.add(const Duration(minutes: 2));
        expect(
          await PendingOpsReplayer(
            database: database,
            apiClient: apiClient,
            accountId: 'account',
            nowUtc: () => now,
          ).replayDueOps(),
          1,
        );
        final replaced = await database
            .select(database.notificationSchedule)
            .getSingle();
        expect(replaced.id, original.id);
        expect(replaced.sourceId, 'task-server');
        expect(replaced.generation, before.generation);
        expect(replaced.snoozedUntilUtc, before.snoozedUntilUtc);
        expect(replaced.sentAtUtc, before.sentAtUtc);
        expect(replaced.dismissedAtUtc, before.dismissedAtUtc);
        expect(
          (await database.tasksDao.listTasks('account', 'list-1')).single.id,
          'task-server',
        );
        final schedules = NotificationScheduleService(
          database: database,
          nowUtc: () => now,
        );
        await schedules.rebuildUpcomingTaskNotifications('account');
        await scheduler.checkNow();
        expect(backend.requests, hasLength(1));
        if (lifecycle == 'sent') {
          await backend.invoke(0, 'default');
          expect(opened?.sourceId, 'task-server');
          expect(backend.cancelledIds, isEmpty);
        }
        now = reminder.add(const Duration(minutes: 10));
        await schedules.rebuildUpcomingTaskNotifications('account');
        await scheduler.checkNow();
        await scheduler.checkNow();
        expect(backend.requests, hasLength(lifecycle == 'snoozed' ? 2 : 1));
        if (lifecycle == 'snoozed') {
          expect(backend.requests.last.payload!['itemId'], 'task-server');
          expect(
            (await database.select(database.notificationSchedule).getSingle())
                .sentAtUtc,
            now.millisecondsSinceEpoch,
          );
        }
      },
    );
  }

  for (final throughEngine in [false, true]) {
    for (final failSettings in [false, true]) {
      test(
        'task list ID callback follows commit (engine=$throughEngine, failure=$failSettings)',
        () async {
          final settings = AppSettingsController(MemorySettingsStore());
          addTearDown(settings.dispose);
          await settings.registerSidebarIds(SidebarOrderSection.taskLists, [
            'before',
            'temp-list',
            'after',
            'list-server',
          ], accountId: 'account');
          await database.taskListsDao.upsertTaskList(
            _taskList('temp-list', title: 'Temp'),
          );
          await _enqueue(
            database,
            id: 'create-list',
            operation: 'create_task_list',
            entityType: 'task_list',
            taskListId: 'temp-list',
            localTempId: 'temp-list',
            request: {'title': 'Temp'},
          );
          var callbackCount = 0;
          var committed = false;
          Future<void> replaced(String oldId, String newId) async {
            callbackCount++;
            final ids = (await database.taskListsDao.listTaskLists('account'))
                .map((list) => list.id);
            committed =
                oldId == 'temp-list' &&
                newId == 'list-server' &&
                !ids.contains(oldId) &&
                ids.contains(newId);
            await settings.replaceSidebarId(
              SidebarOrderSection.taskLists,
              oldId,
              newId,
              accountId: 'account',
            );
            if (failSettings) throw StateError('settings unavailable');
          }

          final replayer = PendingOpsReplayer(
            database: database,
            apiClient: apiClient,
            accountId: 'account',
            onTaskListIdReplaced: replaced,
            nowUtc: () => DateTime.utc(2026, 6, 4),
          );
          if (throughEngine) {
            await SyncEngine(
              database: database,
              apiClient: apiClient,
              accountId: 'account',
              onTaskListIdReplaced: replaced,
              nowUtc: () => DateTime.utc(2026, 6, 4),
            ).fullSync();
          } else {
            expect(await replayer.replayDueOps(), 1);
          }
          expect(committed, isTrue);
          expect(callbackCount, 1);
          expect(settings.state.sidebarOrder.taskListIdsByAccount['account'], [
            'before',
            'list-server',
            'after',
          ]);
          expect(await replayer.replayDueOps(), 0);
          expect(
            apiClient.calls.where(
              (call) => call.startsWith('create_task_list:'),
            ),
            ['create_task_list:Temp'],
          );
        },
      );
    }
  }

  test('replays all operation handlers and rewrites task temp IDs', () async {
    await database.taskListsDao.upsertTaskList(
      _taskList('local-tasklist-1', title: 'Temp'),
    );
    await database.tasksDao.upsertTask(
      _task('list-1', 'local-task-1', title: 'Draft'),
    );

    await _enqueue(
      database,
      id: '01',
      operation: 'create_task_list',
      entityType: 'task_list',
      taskListId: 'local-tasklist-1',
      localTempId: 'local-tasklist-1',
      request: {'title': 'Temp'},
    );
    await _enqueue(
      database,
      id: '02',
      operation: 'patch_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: {'title': 'Patched'},
    );
    await _enqueue(
      database,
      id: '03',
      operation: 'update_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: {'title': 'Updated'},
    );
    await _enqueue(
      database,
      id: '04',
      operation: 'create_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      localTempId: 'local-task-1',
      request: {
        'body': {'title': 'Draft'},
      },
    );
    await _enqueue(
      database,
      id: '05',
      operation: 'patch_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      request: {'title': 'Patched task'},
    );
    await _enqueue(
      database,
      id: '06',
      operation: 'update_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      request: {'title': 'Updated task'},
    );
    await _enqueue(
      database,
      id: '07',
      operation: 'move_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      request: {'previous': 'task-0'},
    );
    await _enqueue(
      database,
      id: '08',
      operation: 'delete_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      request: const {},
    );
    await _enqueue(
      database,
      id: '09',
      operation: 'clear_completed_tasks',
      taskListId: 'list-1',
      request: const {},
    );
    await _enqueue(
      database,
      id: '10',
      operation: 'delete_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    expect(applied, 10);
    expect(
      await database.pendingOpsDao.pendingOpsForReplay('account', _later),
      isEmpty,
    );
    expect(apiClient.calls, [
      'create_task_list:Temp',
      'patch_task_list:list-1',
      'update_task_list:list-1',
      'create_task:list-1',
      'patch_task:task-server',
      'update_task:task-server',
      'move_task:task-server',
      'delete_task:task-server',
      'clear:list-1',
      'delete_task_list:list-1',
    ]);

    final lists = await database.taskListsDao.listTaskLists('account');
    expect(lists.map((list) => list.id), contains('list-server'));
    expect(lists.map((list) => list.id), isNot(contains('local-tasklist-1')));
  });

  test('concurrent replayers dispatch a queued task create once', () async {
    await database.tasksDao.upsertTask(
      _task('list-1', 'local-task-1', title: 'Draft'),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'create_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      localTempId: 'local-task-1',
      request: {
        'body': {'title': 'Draft'},
      },
    );
    final createGate = Completer<void>();
    apiClient.createTaskGate = createGate;

    PendingOpsReplayer replayer() => PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    final first = replayer().replayDueOps();
    await _waitFor(() => apiClient.calls.length == 1);
    final second = replayer().replayDueOps();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(apiClient.calls, ['create_task:list-1']);

    createGate.complete();
    expect(await first, 1);
    expect(await second, 0);
    expect(apiClient.calls, ['create_task:list-1']);
  });

  test('task edit waits while a rate-limited creation is retrying', () async {
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.createTask(
      'list-1',
      const TaskCreateInput(title: 'Draft'),
    );
    final localTask = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    await repository.patchTask(
      'list-1',
      localTask.id,
      const TaskPatchInput({'title': 'Edited offline'}),
    );
    apiClient.createTaskError = const GoogleTasksApiError(
      statusCode: 429,
      message: 'Rate limited',
    );

    await expectLater(
      PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      throwsA(isA<TaskRemoteError>()),
    );
    expect(apiClient.calls, ['create_task:list-1']);
    var operations = await database.select(database.pendingOps).get();
    final pendingCreate = operations.singleWhere(
      (operation) => operation.operation == 'create_task',
    );
    final pendingPatch = operations.singleWhere(
      (operation) => operation.operation == 'patch_task',
    );
    expect(pendingCreate.state, 'retry');
    expect(pendingCreate.attemptCount, 1);
    expect(pendingPatch.dependsOnOpId, pendingCreate.id);
    expect(pendingPatch.attemptCount, 0);

    apiClient.createTaskError = null;
    final secondApplied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 5),
    ).replayDueOps();

    expect(secondApplied, 2);
    expect(apiClient.calls, [
      'create_task:list-1',
      'create_task:list-1',
      'patch_task:task-server',
    ]);
    expect(apiClient.taskPatchFields.single['title'], 'Edited offline');
    operations = await database.select(database.pendingOps).get();
    expect(operations, isEmpty);
  });

  test('task creation acknowledgment preserves a newer queued edit', () async {
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.createTask(
      'list-1',
      const TaskCreateInput(title: 'Draft'),
    );
    final temporary = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    await repository.patchTask(
      'list-1',
      temporary.id,
      const TaskPatchInput({'title': 'Revised'}),
    );
    apiClient.patchTaskError = const GoogleTasksApiError(
      statusCode: 503,
      message: 'Temporary failure',
    );

    await expectLater(
      PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      throwsA(isA<TaskRemoteError>()),
    );

    final visible = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    expect(visible.id, 'task-server');
    expect(visible.title, 'Revised');
    expect(visible.localDirty, isTrue);
    expect(
      (await database.select(database.pendingOps).get()).single.operation,
      'patch_task',
    );
  });

  test(
    'remote edit after creation conflicts with a delayed dependent patch',
    () async {
      final createdUpdated = DateTime.utc(2026, 6, 4, 0, 5);
      final createdTask = _taskDto(
        'task-server',
        title: 'Draft',
        updated: createdUpdated,
      );
      apiClient
        ..createdTask = createdTask
        ..remoteTask = createdTask
        ..patchTaskError = const GoogleTasksApiError(
          statusCode: 503,
          message: 'Temporary failure',
        );
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.createTask(
        'list-1',
        const TaskCreateInput(title: 'Draft'),
      );
      final temporary = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      await repository.patchTask(
        'list-1',
        temporary.id,
        const TaskPatchInput({'title': 'Local title'}),
      );

      await expectLater(
        PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        throwsA(isA<TaskRemoteError>()),
      );

      var pending = await database.select(database.pendingOps).getSingle();
      expect(pending.operation, 'patch_task');
      // The request was dispatched; retain that uncertainty durably so a
      // matching retry result can be acknowledged without resending it.
      expect(pending.state, 'in_progress');
      expect(pending.attemptCount, 1);
      expect(pending.nextAttemptAtUtc, isNot(equals(null)));
      expect(pending.lastErrorCode, '503');
      expect(pending.baselineUpdatedUtc, createdUpdated.toIso8601String());
      expect(jsonDecode(pending.baselineRawJson!)['title'], 'Draft');

      apiClient
        ..patchTaskError = null
        ..remoteTask = _taskDto(
          'task-server',
          title: 'Competing remote title',
          updated: DateTime.utc(2026, 6, 4, 0, 10),
        );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 5),
        ).replayDueOps(),
        0,
      );

      pending = await database.select(database.pendingOps).getSingle();
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('title'));
      expect(apiClient.taskPatchFields, isEmpty);
      expect(apiClient.remoteTask!.title, 'Competing remote title');
    },
  );

  for (final entity in ['task', 'task list']) {
    test(
      '$entity creation restart after identity persistence stays acknowledged',
      () async {
        final directory = await createPersistenceTestDirectory(
          'busymax-$entity-create-ack-',
        );
        final databaseFile = File('${directory.path}/busymax.sqlite');
        final previousDatabaseWarningSetting =
            driftRuntimeOptions.dontWarnAboutMultipleDatabases;
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        final commitInterruption = _CommitInterruption();
        final interruptedDatabase = AppDatabase(
          NativeDatabase(databaseFile).interceptWith(commitInterruption),
        );
        AppDatabase? restartedDatabase;
        Future<int>? interruptedReplay;
        addTearDown(() async {
          commitInterruption.resume();
          await interruptedReplay;
          await restartedDatabase?.close();
          await interruptedDatabase.close();
          await directory.delete(recursive: true);
          driftRuntimeOptions.dontWarnAboutMultipleDatabases =
              previousDatabaseWarningSetting;
        });

        await _insertAccount(interruptedDatabase);
        await interruptedDatabase.taskListsDao.upsertTaskList(
          _taskList('list-1'),
        );
        if (entity == 'task') {
          await interruptedDatabase.tasksDao.upsertTask(
            _task('list-1', 'local-task-1', title: 'Draft'),
          );
          await _enqueue(
            interruptedDatabase,
            id: 'create',
            operation: 'create_task',
            taskListId: 'list-1',
            taskId: 'local-task-1',
            localTempId: 'local-task-1',
            request: {
              'body': {'title': 'Draft'},
            },
          );
        } else {
          await interruptedDatabase.taskListsDao.upsertTaskList(
            _taskList('local-list', title: 'Draft list'),
          );
          await _enqueue(
            interruptedDatabase,
            id: 'create',
            operation: 'create_task_list',
            entityType: 'task_list',
            taskListId: 'local-list',
            localTempId: 'local-list',
            request: {'title': 'Draft list'},
          );
        }

        final interruptedClient = _FakeTaskRemoteClient();
        commitInterruption.arm();
        interruptedReplay = PendingOpsReplayer(
          database: interruptedDatabase,
          apiClient: interruptedClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4),
        ).replayDueOps();
        await commitInterruption.commitReached.future;

        restartedDatabase = AppDatabase(NativeDatabase(databaseFile));
        final restartedClient = _FakeTaskRemoteClient();
        expect(
          await PendingOpsReplayer(
            database: restartedDatabase,
            apiClient: restartedClient,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 4, 1),
          ).replayDueOps(),
          0,
        );

        expect(
          await restartedDatabase.pendingOpsDao.getOp('create'),
          equals(null),
        );
        expect(restartedClient.calls, isEmpty);
        if (entity == 'task') {
          final tasks = await restartedDatabase.tasksDao.listTasks(
            'account',
            'list-1',
          );
          expect(tasks.map((task) => task.id), ['task-server']);
          expect(interruptedClient.calls, ['create_task:list-1']);
        } else {
          final lists = await restartedDatabase.taskListsDao.listTaskLists(
            'account',
          );
          expect(lists.map((list) => list.id), contains('list-server'));
          expect(lists.map((list) => list.id), isNot(contains('local-list')));
          expect(interruptedClient.calls, ['create_task_list:Draft list']);
        }

        commitInterruption.resume();
        expect(await interruptedReplay, 1);
      },
    );
  }

  test(
    'checklist creation restart after identity persistence stays acknowledged',
    () async {
      final directory = await createPersistenceTestDirectory(
        'busymax-checklist-create-ack-',
      );
      final databaseFile = File('${directory.path}/busymax.sqlite');
      final previousDatabaseWarningSetting =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final commitInterruption = _CommitInterruption();
      final interruptedDatabase = AppDatabase(
        NativeDatabase(databaseFile).interceptWith(commitInterruption),
      );
      AppDatabase? restartedDatabase;
      Future<int>? interruptedReplay;
      addTearDown(() async {
        commitInterruption.resume();
        await interruptedReplay;
        await restartedDatabase?.close();
        await interruptedDatabase.close();
        await directory.delete(recursive: true);
        driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousDatabaseWarningSetting;
      });

      await _insertAccount(interruptedDatabase);
      await interruptedDatabase.taskListsDao.upsertTaskList(
        _taskList('list-1'),
      );
      await interruptedDatabase.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          checklistItemsJson: jsonEncode([
            {'id': 'local-step', 'displayName': 'Step', 'isChecked': false},
          ]),
        ),
      );
      await _enqueue(
        interruptedDatabase,
        id: 'create',
        operation: 'create_task_checklist_item',
        entityType: 'task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        localTempId: 'local-step',
        request: {
          'checklistItemId': 'local-step',
          'body': {'displayName': 'Step', 'isChecked': false},
        },
      );
      await _enqueue(
        interruptedDatabase,
        id: 'patch',
        operation: 'patch_task_checklist_item',
        entityType: 'task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        dependsOnOpId: 'create',
        request: {
          'checklistItemId': 'local-step',
          'body': {'isChecked': true},
        },
      );

      final interruptedClient = _ChecklistTaskRemoteClient();
      commitInterruption.arm();
      interruptedReplay = PendingOpsReplayer(
        database: interruptedDatabase,
        apiClient: interruptedClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();
      await commitInterruption.commitReached.future;

      restartedDatabase = AppDatabase(NativeDatabase(databaseFile));
      final restartedClient = _ChecklistTaskRemoteClient();
      restartedClient.remoteItems.addAll(interruptedClient.remoteItems);
      expect(
        await PendingOpsReplayer(
          database: restartedDatabase,
          apiClient: restartedClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        1,
      );

      expect(
        await restartedDatabase.pendingOpsDao.getOp('create'),
        equals(null),
      );
      expect(restartedClient.checklistCalls, ['update:server-step:true']);
      final task = (await restartedDatabase.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      final item = decodeTaskChecklistItems(task.microsoftChecklistItemsJson)
          .single;
      expect(item.id, 'server-step');
      expect(item.completed, isTrue);
      expect(
        await restartedDatabase.select(restartedDatabase.pendingOps).get(),
        isEmpty,
      );

      commitInterruption.resume();
      expect(await interruptedReplay, 1);
      expect(interruptedClient.checklistCalls, ['create:Step']);
    },
  );

  test('unknown task creation outcome is not submitted again', () async {
    await database.tasksDao.upsertTask(
      _task('list-1', 'local-task-1', title: 'Draft'),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'create_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      localTempId: 'local-task-1',
      request: {
        'body': {'title': 'Draft'},
      },
    );
    apiClient.createTaskError = StateError('response was lost');

    final replayer = PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );

    expect(await replayer.replayDueOps(), 0);
    final pending = await database.pendingOpsDao.getOp('01');
    expect(pending!.state, 'recovery_required');
    expect(pending.lastErrorCode, 'creation_outcome_unknown');
    expect(pending.nextAttemptAtUtc, startsWith('9999-12-31'));

    await database.pendingOpsDao.retryNow('01', DateTime.utc(2026, 6, 4));
    expect(await replayer.replayDueOps(), 0);
    final stillPending = await database.pendingOpsDao.getOp('01');
    expect(stillPending!.state, 'recovery_required');
    expect(stillPending.nextAttemptAtUtc, startsWith('9999-12-31'));
    expect(apiClient.calls, ['create_task:list-1']);
  });

  test('abandoned in-progress task creation is not submitted again', () async {
    await _enqueue(
      database,
      id: '01',
      operation: 'create_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      localTempId: 'local-task-1',
      request: {
        'body': {'title': 'Draft'},
      },
    );
    await (database.update(database.pendingOps)
          ..where((row) => row.id.equals('01')))
        .write(const PendingOpsCompanion(state: Value('in_progress')));

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps(),
      0,
    );

    final pending = await database.pendingOpsDao.getOp('01');
    expect(pending!.state, 'recovery_required');
    expect(pending.lastErrorCode, 'creation_outcome_unknown');
    expect(apiClient.calls, isEmpty);
  });

  test('unknown task-list creation outcome is not submitted again', () async {
    await database.taskListsDao.upsertTaskList(
      _taskList('local-list', title: 'Draft list'),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'create_task_list',
      entityType: 'task_list',
      taskListId: 'local-list',
      localTempId: 'local-list',
      request: {'title': 'Draft list'},
    );
    apiClient.createTaskListError = StateError('response was lost');

    final replayer = PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    expect(await replayer.replayDueOps(), 0);
    expect(await replayer.replayDueOps(), 0);

    final pending = await database.pendingOpsDao.getOp('01');
    expect(pending!.state, 'recovery_required');
    expect(apiClient.calls, ['create_task_list:Draft list']);
  });

  test('deleting a task whose create is in flight queues after it', () async {
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.createTask(
      'list-1',
      const TaskCreateInput(title: 'Draft'),
    );
    final localTask = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    final gate = Completer<void>();
    apiClient.createTaskGate = gate;
    final firstReplay = PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4, 1),
    ).replayDueOps();
    await _waitFor(() => apiClient.calls.isNotEmpty);

    await repository.deleteTask('list-1', localTask.id);

    var operations = await database.select(database.pendingOps).get();
    final create = operations.singleWhere(
      (operation) => operation.operation == 'create_task',
    );
    final delete = operations.singleWhere(
      (operation) => operation.operation == 'delete_task',
    );
    expect(create.state, 'in_progress');
    expect(delete.dependsOnOpId, create.id);

    gate.complete();
    expect(await firstReplay, 1);
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 2),
      ).replayDueOps(),
      1,
    );
    expect(apiClient.calls, ['create_task:list-1', 'delete_task:task-server']);
    operations = await database.select(database.pendingOps).get();
    expect(operations, isEmpty);
  });

  test('server ID rewrite revives a legacy blocked task edit', () async {
    await database.tasksDao.upsertTask(
      _task('list-1', 'local-task-1', title: 'Draft'),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'create_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      localTempId: 'local-task-1',
      request: {
        'body': {'title': 'Draft'},
      },
    );
    await _enqueue(
      database,
      id: '02',
      operation: 'patch_task',
      taskListId: 'list-1',
      taskId: 'local-task-1',
      request: {'title': 'Edited offline'},
    );
    await (database.update(
      database.pendingOps,
    )..where((row) => row.id.equals('02'))).write(
      const PendingOpsCompanion(
        state: Value('failed'),
        attemptCount: Value(1),
        nextAttemptAtUtc: Value('9999-12-31T00:00:00.000Z'),
        lastErrorCode: Value('400'),
        lastErrorMessage: Value('Invalid temporary task ID'),
      ),
    );

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      1,
    );

    final revived = await database.pendingOpsDao.getOp('02');
    expect(revived!.taskId, 'task-server');
    expect(revived.state, 'pending');
    expect(revived.nextAttemptAtUtc, equals(null));
    expect(revived.lastErrorCode, equals(null));
    expect(revived.lastErrorMessage, equals(null));
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 2),
      ).replayDueOps(),
      1,
    );
    expect(apiClient.calls, ['create_task:list-1', 'patch_task:task-server']);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test('new task can move to another list before creation sync', () async {
    await database.taskListsDao.upsertTaskList(_taskList('list-2'));
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.createTask(
      'list-1',
      const TaskCreateInput(title: 'Draft'),
    );
    final localTask = (await database.tasksDao.listTasks(
      'account',
      'list-1',
    )).single;
    await repository.moveTask(
      TaskMoveInput(
        sourceTaskListId: 'list-1',
        taskId: localTask.id,
        destinationTaskListId: 'list-2',
      ),
    );

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      2,
    );

    expect(apiClient.calls, ['create_task:list-1', 'move_task:task-server']);
    expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
    final destination = await database.tasksDao.listTasks('account', 'list-2');
    expect(destination.single.id, 'task-server');
  });

  test(
    'new task moved and edited before creation sync has one destination row',
    () async {
      await database.taskListsDao.upsertTaskList(_taskList('list-2'));
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.createTask(
        'list-1',
        const TaskCreateInput(title: 'Draft'),
      );
      final localTask = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      await repository.moveTask(
        TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: localTask.id,
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.patchTask(
        'list-2',
        localTask.id,
        const TaskPatchInput({'title': 'Edited after move'}),
      );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        3,
      );

      expect(apiClient.calls, [
        'create_task:list-1',
        'move_task:task-server',
        'patch_task:task-server',
      ]);
      expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
      final tasks = await database.select(database.tasks).get();
      expect(tasks, hasLength(1));
      expect(tasks.single.taskListId, 'list-2');
      expect(tasks.single.id, 'task-server');
      expect(tasks.single.title, 'Edited after move');
      expect(tasks.single.localDirty, isFalse);
    },
  );

  test(
    'move replay repairs a source projection before a dependent edit',
    () async {
      await database.taskListsDao.upsertTaskList(_taskList('list-2'));
      await database.tasksDao.upsertTask(
        _task('list-1', 'task-1', title: 'Original'),
      );
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.patchTask(
        'list-2',
        'task-1',
        const TaskPatchInput({'title': 'Edited after move'}),
      );
      await (database.update(database.tasks)..where(
            (row) =>
                row.accountId.equals('account') &
                row.taskListId.equals('list-2') &
                row.id.equals('task-1'),
          ))
          .write(const TasksCompanion(taskListId: Value('list-1')));

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        2,
      );

      expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
      final tasks = await database.select(database.tasks).get();
      expect(tasks, hasLength(1));
      expect(tasks.single.taskListId, 'list-2');
      expect(tasks.single.title, 'Edited after move');
      expect(tasks.single.localDirty, isFalse);
    },
  );

  test(
    'cross-list move orders an equal-timestamp edit and preserves projection',
    () async {
      await database.taskListsDao.upsertTaskList(_taskList('list-2'));
      await database.tasksDao.upsertTask(
        _task('list-1', 'task-1', title: 'Original'),
      );
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.patchTask(
        'list-2',
        'task-1',
        const TaskPatchInput({'title': 'Edited after move'}),
      );
      final queued = await database.select(database.pendingOps).get();
      final move = queued.singleWhere((op) => op.operation == 'move_task');
      final edit = queued.singleWhere((op) => op.operation == 'patch_task');
      expect(edit.dependsOnOpId, move.id);

      apiClient.moveTaskError = const GoogleTasksApiError(
        statusCode: 429,
        message: 'Rate limited',
      );
      await expectLater(
        PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        throwsA(isA<TaskRemoteError>()),
      );
      expect(apiClient.calls, ['move_task:task-1']);
      expect(
        (await database.tasksDao.listTasks('account', 'list-2')).single.title,
        'Edited after move',
      );

      apiClient.moveTaskError = null;
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        2,
      );
      expect(apiClient.calls, [
        'move_task:task-1',
        'move_task:task-1',
        'patch_task:task-1',
      ]);
      expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
      final finalTask = (await database.tasksDao.listTasks(
        'account',
        'list-2',
      )).single;
      expect(finalTask.title, 'Edited after move');
      expect(finalTask.localDirty, isFalse);
    },
  );

  test(
    'three cross-list moves form one dependency chain before an edit',
    () async {
      await database.taskListsDao.upsertTaskList(_taskList('list-2'));
      await database.taskListsDao.upsertTaskList(_taskList('list-3'));
      await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-2',
          taskId: 'task-1',
          destinationTaskListId: 'list-3',
        ),
      );
      await repository.patchTask(
        'list-3',
        'task-1',
        const TaskPatchInput({'title': 'Final title'}),
      );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        3,
      );
      expect(apiClient.calls, [
        'move_task:task-1',
        'move_task:task-1',
        'patch_task:task-1',
      ]);
      expect(
        (await database.tasksDao.listTasks('account', 'list-3')).single.title,
        'Final title',
      );
    },
  );

  test(
    'remote edit after a move still conflicts with the dependent patch',
    () async {
      const baselineUpdated = '2026-06-04T00:00:00.000Z';
      final baselineRaw = jsonEncode({
        'id': 'task-1',
        'title': 'Base title',
        'updated': baselineUpdated,
      });
      await database.taskListsDao.upsertTaskList(_taskList('list-2'));
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'Base title',
          updatedUtc: baselineUpdated,
          rawJson: baselineRaw,
        ),
      );
      apiClient
        ..remoteTask = _taskDto(
          'task-1',
          title: 'Base title',
          updated: DateTime.parse(baselineUpdated),
        )
        ..remoteTaskAfterMove = _taskDto(
          'task-1',
          title: 'Independent remote title',
          updated: DateTime.utc(2026, 6, 4, 0, 10),
        );
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.patchTask(
        'list-2',
        'task-1',
        const TaskPatchInput({'title': 'Local title'}),
      );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        1,
      );

      expect(apiClient.calls, ['move_task:task-1']);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.operation, 'patch_task');
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('title'));
      expect(
        (await database.tasksDao.listTasks('account', 'list-2')).single.title,
        'Local title',
      );
    },
  );

  test(
    'remote edit conflicts with a patch between two cross-list moves',
    () async {
      const baselineUpdated = '2026-06-04T00:00:00.000Z';
      final baselineRaw = jsonEncode({
        'id': 'task-1',
        'title': 'Base title',
        'updated': baselineUpdated,
      });
      for (final listId in ['list-2', 'list-3']) {
        await database.taskListsDao.upsertTaskList(_taskList(listId));
      }
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'Base title',
          updatedUtc: baselineUpdated,
          rawJson: baselineRaw,
        ),
      );
      apiClient
        ..remoteTask = _taskDto(
          'task-1',
          title: 'Base title',
          updated: DateTime.parse(baselineUpdated),
        )
        ..remoteTaskAfterMove = _taskDto(
          'task-1',
          title: 'Independent remote title',
          updated: DateTime.utc(2026, 6, 4, 0, 10),
        );
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.patchTask(
        'list-2',
        'task-1',
        const TaskPatchInput({'title': 'Local title'}),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-2',
          taskId: 'task-1',
          destinationTaskListId: 'list-3',
        ),
      );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        1,
      );

      expect(apiClient.calls, ['move_task:task-1']);
      final pending = await database.select(database.pendingOps).get();
      final patch = pending.singleWhere(
        (operation) => operation.operation == 'patch_task',
      );
      final laterMove = pending.singleWhere(
        (operation) => operation.operation == 'move_task',
      );
      expect(patch.lastErrorCode, 'conflict');
      expect(patch.lastErrorMessage, contains('title'));
      expect(laterMove.dependsOnOpId, patch.id);
      expect(
        (await database.tasksDao.listTasks('account', 'list-3')).single.title,
        'Local title',
      );
      expect(apiClient.remoteTask!.title, 'Independent remote title');
    },
  );

  test(
    'delete remains blocked behind a permanently rejected cross-list move',
    () async {
      await database.taskListsDao.upsertTaskList(_taskList('list-2'));
      await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
      await repository.deleteTask('list-2', 'task-1');
      apiClient.moveTaskError = const GoogleTasksApiError(
        statusCode: 400,
        message: 'Rejected',
      );

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        0,
      );
      expect(apiClient.calls, ['move_task:task-1']);
      final operations = await database.select(database.pendingOps).get();
      final move = operations.singleWhere((op) => op.operation == 'move_task');
      final delete = operations.singleWhere(
        (op) => op.operation == 'delete_task',
      );
      expect(move.nextAttemptAtUtc, startsWith('9999-12-31'));
      expect(delete.dependsOnOpId, move.id);
    },
  );

  test('known pre-dispatch create failure remains safely retryable', () async {
    await database.tasksDao.upsertTask(
      _task('list-1', 'local-task-safe', title: 'Draft'),
    );
    await _enqueue(
      database,
      id: 'safe-create',
      operation: 'create_task',
      taskListId: 'list-1',
      taskId: 'local-task-safe',
      localTempId: 'local-task-safe',
      request: {
        'body': {'title': 'Draft'},
      },
    );
    apiClient.createTaskError = const KnownUnsentRequestException(
      kind: RequestPreDispatchFailureKind.authentication,
    );
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps(),
      0,
    );
    final retry = await database.pendingOpsDao.getOp('safe-create');
    expect(retry!.state, 'retry');
    expect(retry.lastErrorCode, 'authentication_failed_before_dispatch');

    apiClient.createTaskError = null;
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 2),
      ).replayDueOps(),
      1,
    );
    expect(
      apiClient.calls.where((call) => call == 'create_task:list-1'),
      hasLength(2),
    );
  });

  test(
    'equal-timestamp task-list renames replay in dependency order',
    () async {
      apiClient.persistTaskListPatches = true;
      apiClient.remoteTaskList = _taskListDto('list-1', title: 'A');
      await database.taskListsDao.upsertTaskList(
        _taskList('list-1', title: 'A'),
      );
      final repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.renameTaskList('list-1', 'B');
      await repository.renameTaskList('list-1', 'C');
      final queued = await database.select(database.pendingOps).get();
      expect(queued, hasLength(2));
      expect(queued.last.dependsOnOpId, queued.first.id);

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        2,
      );
      expect(apiClient.taskListPatchTitles, ['B', 'C']);
      expect(apiClient.remoteTaskList!.title, 'C');
      final local = (await database.taskListsDao.listTaskLists('account'))
          .single;
      expect(local.title, 'C');
      expect(local.localDirty, isFalse);
    },
  );

  test(
    'in-flight task-list rename response does not revert a newer title',
    () async {
      final started = Completer<void>();
      final gate = Completer<void>();
      apiClient
        ..persistTaskListPatches = true
        ..taskListPatchStarted = started
        ..taskListPatchGate = gate;
      final repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.renameTaskList('list-1', 'B');
      final replay = PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();
      await started.future;
      await repository.renameTaskList('list-1', 'C');
      gate.complete();
      expect(await replay, 1);
      expect(
        (await database.taskListsDao.listTaskLists('account')).single.title,
        'C',
      );
      apiClient.taskListPatchGate = null;
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        1,
      );
      expect(apiClient.remoteTaskList!.title, 'C');
    },
  );

  test(
    'dependent list rename waits through a retryable first rename',
    () async {
      final repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.renameTaskList('list-1', 'B');
      await repository.renameTaskList('list-1', 'C');
      apiClient.patchTaskListError = const GoogleTasksApiError(
        statusCode: 429,
        message: 'Rate limited',
      );

      await expectLater(
        PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        throwsA(isA<TaskRemoteError>()),
      );
      expect(apiClient.taskListPatchTitles, isEmpty);
      expect(
        (await database.taskListsDao.listTaskLists('account')).single.title,
        'C',
      );

      apiClient.patchTaskListError = null;
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        2,
      );
      expect(apiClient.taskListPatchTitles, ['B', 'C']);
      expect(
        (await database.taskListsDao.listTaskLists('account')).single.title,
        'C',
      );
    },
  );

  test('task-list rename followed by full update replays in order', () async {
    final repository = TaskListsRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.renameTaskList('list-1', 'B');
    await repository.updateTaskListFull(
      'list-1',
      const TaskListPut({'title': 'C'}),
    );

    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      2,
    );
    expect(apiClient.calls, [
      'patch_task_list:list-1',
      'update_task_list:list-1',
    ]);
    final local = (await database.taskListsDao.listTaskLists('account')).single;
    expect(local.title, 'C');
    expect(local.localDirty, isFalse);
  });

  for (final childChanged in [false, true]) {
    test(
      'rename then delete ${childChanged ? 'blocks' : 'succeeds'} for child membership baseline',
      () async {
        final baseline = DateTime.utc(2026, 6, 4);
        final childEdit = baseline.add(const Duration(minutes: 5));
        final renameAcknowledged = baseline.add(const Duration(minutes: 10));
        final baselineChild = _taskDto('child-1', updated: baseline);
        await database.tasksDao.upsertTask(
          taskFromDto('account', 'list-1', baselineChild, _now),
        );
        await database.taskListsDao.upsertTaskList(
          _taskList(
            'list-1',
            title: 'A',
            updatedUtc: baseline.toIso8601String(),
          ),
        );
        apiClient
          ..persistTaskListPatches = true
          ..remoteTaskList = _taskListDto(
            'list-1',
            title: 'A',
            updated: baseline,
          )
          ..taskListPatchResultUpdated = renameAcknowledged
          ..remoteTasksPage = TasksPageDto(
            items: childChanged
                ? [_taskDto('child-1', updated: childEdit)]
                : [baselineChild],
            rawJson: const {},
          );
        final repository = TaskListsRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => baseline,
        );
        await repository.renameTaskList('list-1', 'B');
        await repository.deleteTaskList('list-1');

        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => baseline.add(const Duration(hours: 1)),
        ).replayDueOps();

        // Full membership snapshots also detect an unchanged timestamp and a
        // moved-out local row; a timestamp-filtered query cannot prove this.
        expect(apiClient.taskListPageUpdatedMins, [null]);
        expect(
          apiClient.calls.where((call) => call == 'delete_task_list:list-1'),
          hasLength(childChanged ? 0 : 1),
        );
        expect(applied, childChanged ? 1 : 2);
        if (childChanged) {
          final delete = (await database.select(database.pendingOps).get())
              .singleWhere(
                (operation) => operation.operation == 'delete_task_list',
              );
          expect(delete.lastErrorCode, 'conflict');
          expect(
            delete.baselineUpdatedUtc,
            renameAcknowledged.toIso8601String(),
          );
          expect(
            jsonDecode(delete.requestJson),
            containsPair('_busymaxChildTaskConflictBaselines', {
              'child-1': {
                'updatedUtc': baseline.toIso8601String(),
                'rawJson': baselineChild.rawJson,
              },
            }),
          );
        }
      },
    );
  }

  for (final reminderValue in [false, true]) {
    test(
      'list creation preserves in-flight reminder value $reminderValue and rename',
      () async {
        final started = Completer<void>();
        final gate = Completer<void>();
        apiClient
          ..createTaskListStarted = started
          ..createTaskListGate = gate;
        final repository = TaskListsRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4),
        );
        await repository.createTaskList('Temporary');
        final temporary = (await database.taskListsDao.listTaskLists('account'))
            .singleWhere((list) => list.id.startsWith('local-tasklist-'));
        await repository.renameTaskList(temporary.id, 'Renamed');
        await database.tasksDao.upsertTask(
          TasksCompanion.insert(
            accountId: 'account',
            taskListId: temporary.id,
            id: 'task-in-temporary-list',
            title: 'Reminder task',
            status: const Value('needsAction'),
            microsoftIsReminderOn: const Value(true),
            microsoftReminderDateTime: const Value('2026-06-05T09:00:00.000Z'),
            microsoftReminderTimeZone: const Value('UTC'),
            rawJson: '{"id":"task-in-temporary-list"}',
            createdLocalAtUtc: _now,
            updatedLocalAtUtc: _now,
          ),
        );
        await repository.setRemindersEnabled(temporary.id, !reminderValue);

        final replay = PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps();
        await started.future;
        await repository.setRemindersEnabled(temporary.id, reminderValue);
        gate.complete();
        expect(await replay, 2);

        final lists = await database.taskListsDao.listTaskLists('account');
        expect(lists.any((list) => list.id == temporary.id), isFalse);
        final server = lists.singleWhere((list) => list.id == 'list-server');
        expect(server.remindersEnabled, reminderValue);
        expect(server.title, 'Renamed');
        expect(
          (await database.tasksDao.listTasks(
            'account',
            'list-server',
          )).single.id,
          'task-in-temporary-list',
        );
        final schedules = NotificationScheduleService(
          database: database,
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        );
        await schedules.rebuildUpcomingTaskNotifications('account');
        final retained =
            (await database.select(database.notificationSchedule).get()).single;
        expect(
          await schedules.isReminderSourceEligible(retained),
          reminderValue,
        );
        expect(retained.sentAtUtc, isNull);
        if (!reminderValue) {
          expect(retained.title, isEmpty);
          // Temporary list disablement retains the unsent identity even when
          // creation replaces the list ID. Re-enabling restores that future
          // alarm without manufacturing another generation or consuming it.
          await repository.setRemindersEnabled(server.id, true);
          final enabled =
              (await database.select(database.notificationSchedule).get())
                  .single;
          expect(enabled.id, retained.id);
          expect(enabled.generation, retained.generation);
          expect(await schedules.isReminderSourceEligible(enabled), isTrue);
          expect(enabled.sentAtUtc, isNull);
        }
      },
    );
  }

  test(
    'parent identity dependency does not leave the parent locally dirty',
    () async {
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        apiClient: apiClient,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.createTask(
        'list-1',
        const TaskCreateInput(title: 'Parent'),
      );
      final temporaryParent = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      await repository.createSubtask(
        taskListId: 'list-1',
        parentTaskId: temporaryParent.id,
        title: 'Child',
      );
      apiClient.createdTasks.addAll([
        _taskDto('parent-server', title: 'Parent'),
        _taskDto('child-server', title: 'Child'),
      ]);

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        3,
      );
      var tasks = await database.tasksDao.listTasks('account', 'list-1');
      expect(tasks, hasLength(2));
      expect(tasks.map((task) => task.localDirty), everyElement(isFalse));
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(apiClient.createParentTaskIds, [null, 'parent-server']);

      apiClient
        ..remoteTaskListsPage = TaskListsPageDto(
          items: [_taskListDto('list-1')],
          rawJson: const {},
        )
        ..remoteTasksPage = TasksPageDto(
          items: [
            _taskDto(
              'parent-server',
              title: 'Parent changed remotely',
              updated: DateTime.utc(2026, 6, 4, 2),
            ),
            _taskDto('child-server', title: 'Child', parent: 'parent-server'),
          ],
          rawJson: const {},
        );
      await SyncEngine(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 3),
      ).fullSync();
      tasks = await database.tasksDao.listTasks('account', 'list-1');
      expect(
        tasks.singleWhere((task) => task.id == 'parent-server').title,
        'Parent changed remotely',
      );
    },
  );

  test(
    'Google subtask is moved under its parent after a root insert',
    () async {
      await database.tasksDao.upsertTask(_task('list-1', 'parent'));
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        apiClient: apiClient,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.createSubtask(
        taskListId: 'list-1',
        parentTaskId: 'parent',
        title: 'Child',
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 2);
      expect(apiClient.calls, ['create_task:list-1', 'move_task:task-server']);
      expect(apiClient.createParentTaskIds, ['parent']);
      expect(apiClient.moveParentTaskIds, ['parent']);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final tasks = await database.tasksDao.listTasks('account', 'list-1');
      final child = tasks.singleWhere((task) => task.id == 'task-server');
      expect(child.parent, 'parent');
    },
  );

  test('failed Google subtask move retries without another insert', () async {
    await database.tasksDao.upsertTask(_task('list-1', 'parent'));
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      apiClient: apiClient,
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    await repository.createSubtask(
      taskListId: 'list-1',
      parentTaskId: 'parent',
      title: 'Child',
    );
    apiClient.moveTaskError = const GoogleTasksApiError(
      statusCode: 503,
      message: 'Temporarily unavailable',
    );

    await expectLater(
      PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      throwsA(isA<TaskRemoteError>()),
    );
    var pending = await database.select(database.pendingOps).get();
    expect(pending, hasLength(1));
    expect(pending.single.operation, 'move_task');
    expect(pending.single.taskId, 'task-server');
    expect(apiClient.calls, ['create_task:list-1', 'move_task:task-server']);

    apiClient.moveTaskError = null;
    final secondApplied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4, 2),
    ).replayDueOps();

    expect(secondApplied, 1);
    pending = await database.select(database.pendingOps).get();
    expect(pending, isEmpty);
    expect(apiClient.calls, [
      'create_task:list-1',
      'move_task:task-server',
      'move_task:task-server',
    ]);
    final tasks = await database.tasksDao.listTasks('account', 'list-1');
    expect(
      tasks.singleWhere((task) => task.id == 'task-server').parent,
      'parent',
    );
  });

  test('404 delete is treated as success', () async {
    apiClient.deleteTaskError = const GoogleTasksApiError(
      statusCode: 404,
      message: 'Not found',
    );
    await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
    await _enqueue(
      database,
      id: '01',
      operation: 'delete_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    expect(applied, 1);
    expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
    expect(
      await database.pendingOpsDao.pendingOpsForReplay('account', _later),
      isEmpty,
    );
  });

  test('leaves calendar operations untouched for calendar replay', () async {
    await _enqueue(
      database,
      id: '01',
      operation: 'patch',
      operationType: 'calendar.patch',
      entityType: 'calendar',
      request: {'summary': 'Renamed'},
    );
    await _enqueue(
      database,
      id: '02',
      operation: 'create',
      operationType: 'event.create',
      entityType: 'event',
      request: {'title': 'Planning'},
    );
    await _enqueue(
      database,
      id: '03',
      operation: 'delete',
      entityType: 'event',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      _later,
    );
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(ops, hasLength(3));
    for (final op in ops) {
      expect(op.attemptCount, 0);
      expect(op.nextAttemptAtUtc, equals(null));
      expect(op.lastErrorCode, equals(null));
      expect(op.lastErrorMessage, equals(null));
    }
  });

  test('unknown task operation is still blocked', () async {
    await _enqueue(
      database,
      id: '01',
      operation: 'frob_task',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.pendingOpsDao.getOp('01');
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(op!.lastErrorCode, 'unknown_operation');
    expect(op.nextAttemptAtUtc, startsWith('9999-12-31'));
  });

  test(
    'temp ID rewrite preserves request text that merely mentions ID',
    () async {
      await database.tasksDao.upsertTask(
        _task('list-1', 'local-task-1', title: 'Draft'),
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'create_task',
        taskListId: 'list-1',
        taskId: 'local-task-1',
        localTempId: 'local-task-1',
        request: {
          'body': {'title': 'Draft'},
        },
      );
      await _enqueue(
        database,
        id: '02',
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: 'local-task-1',
        request: {
          'parent': 'local-task-1',
          'notes': 'Do not rewrite local-task-1 inside user text.',
        },
      );

      await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      expect(apiClient.taskPatchFields.single, {
        'parent': 'task-server',
        'notes': 'Do not rewrite local-task-1 inside user text.',
      });
    },
  );

  test('conflicting task patch is blocked before remote mutation', () async {
    apiClient.remoteTask = TaskDto(
      id: 'task-1',
      title: 'Remote title',
      updated: DateTime.utc(2026, 6, 4, 0, 10),
      rawJson: {'id': 'task-1', 'title': 'Remote title'},
    );
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        title: 'Base title',
        updatedUtc: '2026-06-04T00:00:00.000Z',
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'patch_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: {'title': 'Local title'},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
    );
    final conflicts = <String>[];

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
      onConflictBlocked: (summary) async {
        conflicts.add(summary);
      },
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(op.lastErrorCode, 'conflict');
    expect(op.nextAttemptAtUtc, startsWith('9999-12-31'));
    expect(conflicts.single, contains('Remote task changed fields'));
  });

  test('task conflict detection uses queued baseline JSON', () async {
    apiClient.remoteTask = TaskDto(
      id: 'task-1',
      title: 'Remote title',
      updated: DateTime.utc(2026, 6, 4, 0, 10),
      rawJson: {'id': 'task-1', 'title': 'Remote title'},
    );
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        title: 'Remote title',
        updatedUtc: '2026-06-04T00:00:00.000Z',
        rawJson: jsonEncode({'id': 'task-1', 'title': 'Remote title'}),
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'patch_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: {'title': 'Local title'},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
      baselineRawJson: jsonEncode({'id': 'task-1', 'title': 'Base title'}),
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(op.lastErrorCode, 'conflict');
    expect(op.lastErrorMessage, contains('Remote task changed fields'));
  });

  for (final conflictCase in [
    (
      name: 'notes',
      field: 'notes',
      localValue: 'Local notes' as Object?,
      baseline: <String, Object?>{
        'body': {'content': '<p>Base notes</p>', 'contentType': 'html'},
      },
      current: <String, Object?>{
        'body': {'content': '<p>Remote notes</p>', 'contentType': 'html'},
      },
    ),
    (
      name: 'due date',
      field: 'microsoftDueDateTime',
      localValue: <String, Object?>{
        'dateTime': '2026-06-07T09:00:00',
        'timeZone': 'UTC',
      },
      baseline: <String, Object?>{
        'dueDateTime': {'dateTime': '2026-06-05T09:00:00', 'timeZone': 'UTC'},
      },
      current: <String, Object?>{
        'dueDateTime': {'dateTime': '2026-06-06T09:00:00', 'timeZone': 'UTC'},
      },
    ),
    (
      name: 'reminder date',
      field: 'microsoftReminderDateTime',
      localValue: <String, Object?>{
        'dateTime': '2026-06-07T08:00:00',
        'timeZone': 'UTC',
      },
      baseline: <String, Object?>{
        'reminderDateTime': {
          'dateTime': '2026-06-05T08:00:00',
          'timeZone': 'UTC',
        },
      },
      current: <String, Object?>{
        'reminderDateTime': {
          'dateTime': '2026-06-06T08:00:00',
          'timeZone': 'UTC',
        },
      },
    ),
    (
      name: 'reminder setting',
      field: 'microsoftIsReminderOn',
      localValue: true as Object?,
      baseline: <String, Object?>{'isReminderOn': false},
      current: <String, Object?>{'isReminderOn': true},
    ),
  ]) {
    test(
      'Microsoft ${conflictCase.name} overlap is blocked before mutation',
      () async {
        final baselineRaw = <String, Object?>{
          'id': 'task-1',
          'title': 'Task',
          'lastModifiedDateTime': '2026-06-04T00:00:00.000Z',
          ...conflictCase.baseline,
        };
        final remoteRaw = <String, Object?>{
          'id': 'task-1',
          'title': 'Task',
          'lastModifiedDateTime': '2026-06-04T00:10:00.000Z',
          ...conflictCase.current,
        };
        await database.tasksDao.upsertTask(
          _task(
            'list-1',
            'task-1',
            updatedUtc: '2026-06-04T00:00:00.000Z',
            rawJson: jsonEncode(baselineRaw),
          ),
        );
        await _enqueue(
          database,
          id: '01',
          operation: 'patch_task',
          taskListId: 'list-1',
          taskId: 'task-1',
          request: {conflictCase.field: conflictCase.localValue},
          baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
          baselineRawJson: jsonEncode(baselineRaw),
        );
        final graphClient = _ConflictMicrosoftTodoApiClient(remoteRaw);

        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: _microsoftAdapter(graphClient),
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps();

        final pending = await database.pendingOpsDao.getOp('01');
        expect(applied, 0);
        expect(graphClient.updateTaskCalls, 0);
        expect(pending!.lastErrorCode, 'conflict');
        expect(pending.lastErrorMessage, contains(conflictCase.field));
      },
    );
  }

  test('Microsoft plain-text angle-bracket note changes conflict', () async {
    final baselineRaw = <String, Object?>{
      'id': 'task-1',
      'title': 'Task',
      'lastModifiedDateTime': '2026-06-04T00:00:00.000Z',
      'body': {'content': 'Contact <old@example.com>', 'contentType': 'text'},
    };
    final remoteRaw = <String, Object?>{
      'id': 'task-1',
      'title': 'Task',
      'lastModifiedDateTime': '2026-06-04T00:10:00.000Z',
      'body': {'content': 'Contact <new@example.com>', 'contentType': 'text'},
    };
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        updatedUtc: '2026-06-04T00:00:00.000Z',
        rawJson: jsonEncode(baselineRaw),
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'patch_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: const {'notes': 'Local notes'},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
      baselineRawJson: jsonEncode(baselineRaw),
    );
    final graphClient = _ConflictMicrosoftTodoApiClient(remoteRaw);

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: _microsoftAdapter(graphClient),
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4, 1),
    ).replayDueOps();

    final pending = await database.pendingOpsDao.getOp('01');
    expect(applied, 0);
    expect(graphClient.updateTaskCalls, 0);
    expect(pending!.lastErrorCode, 'conflict');
    expect(pending.lastErrorMessage, contains('notes'));
  });

  test(
    'back-to-back local task patches replay in order without self-conflict',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final baselineRawJson = jsonEncode({
        'id': 'task-1',
        'title': 'Base title',
        'updated': baselineUpdatedUtc,
      });
      apiClient
        ..persistTaskPatches = true
        ..remoteTask = _taskDto(
          'task-1',
          title: 'Base title',
          updated: DateTime.parse(baselineUpdatedUtc),
        );
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'Base title',
          updatedUtc: baselineUpdatedUtc,
          rawJson: baselineRawJson,
        ),
      );
      var localEdit = 0;
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++localEdit),
      );

      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'First local title'}),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'Second local title'}),
      );

      final queued = await database.pendingOpsDao.pendingOpsForReplay(
        'account',
        _later,
      );
      expect(queued, hasLength(2));
      expect(queued.first.dependsOnOpId, equals(null));
      expect(queued.last.dependsOnOpId, queued.first.id);
      expect(
        queued.map((op) => op.baselineRawJson),
        everyElement(baselineRawJson),
      );
      expect(
        queued.map((op) => op.baselineUpdatedUtc),
        everyElement(baselineUpdatedUtc),
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 2);
      expect(apiClient.taskPatchFields.map((fields) => fields['title']), [
        'First local title',
        'Second local title',
      ]);
      expect(apiClient.remoteTask!.title, 'Second local title');
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final local = await database.tasksDao.listTasks('account', 'list-1');
      expect(local.single.title, 'Second local title');
      expect(local.single.localDirty, isFalse);
    },
  );

  test('title notes title task patches replay without self-conflict', () async {
    const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
    final baselineRawJson = jsonEncode({
      'id': 'task-1',
      'title': 'A',
      'notes': 'Base notes',
      'updated': baselineUpdatedUtc,
    });
    apiClient
      ..persistTaskPatches = true
      ..remoteTask = _taskDto(
        'task-1',
        title: 'A',
        notes: 'Base notes',
        updated: DateTime.parse(baselineUpdatedUtc),
      );
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        title: 'A',
        updatedUtc: baselineUpdatedUtc,
        rawJson: baselineRawJson,
      ),
    );
    var localEdit = 0;
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++localEdit),
    );

    await repository.patchTask(
      'list-1',
      'task-1',
      const TaskPatchInput({'title': 'B'}),
    );
    await repository.patchTask(
      'list-1',
      'task-1',
      const TaskPatchInput({'notes': 'Local notes'}),
    );
    await repository.patchTask(
      'list-1',
      'task-1',
      const TaskPatchInput({'title': 'C'}),
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4, 1),
    ).replayDueOps();

    expect(applied, 3);
    expect(apiClient.taskPatchFields, [
      {'title': 'B'},
      {'notes': 'Local notes'},
      {'title': 'C'},
    ]);
    expect(apiClient.remoteTask!.title, 'C');
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test(
    'title notes title task patches preserve a genuine remote title conflict',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final baselineRawJson = jsonEncode({
        'id': 'task-1',
        'title': 'A',
        'notes': 'Base notes',
        'updated': baselineUpdatedUtc,
      });
      apiClient
        ..persistTaskPatches = true
        ..remoteTask = _taskDto(
          'task-1',
          title: 'A',
          notes: 'Base notes',
          updated: DateTime.parse(baselineUpdatedUtc),
        )
        ..remoteTaskAfterSecondPatch = _taskDto(
          'task-1',
          title: 'External title',
          notes: 'Local notes',
          updated: DateTime.utc(2026, 6, 4, 0, 8),
        );
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'A',
          updatedUtc: baselineUpdatedUtc,
          rawJson: baselineRawJson,
        ),
      );
      var localEdit = 0;
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++localEdit),
      );

      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'B'}),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'notes': 'Local notes'}),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'C'}),
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 2);
      expect(apiClient.taskPatchFields, [
        {'title': 'B'},
        {'notes': 'Local notes'},
      ]);
      expect(apiClient.remoteTask!.title, 'External title');
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('title'));
    },
  );

  for (final dependentOperation in ['delete_task', 'move_task']) {
    final action = dependentOperation == 'delete_task' ? 'delete' : 'move';
    test(
      'existing task edit followed by $action does not self-conflict',
      () async {
        const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
        final baselineRawJson = jsonEncode({
          'id': 'task-1',
          'title': 'Base title',
          'updated': baselineUpdatedUtc,
        });
        apiClient
          ..persistTaskPatches = true
          ..remoteTask = _taskDto(
            'task-1',
            title: 'Base title',
            updated: DateTime.parse(baselineUpdatedUtc),
          );
        await database.tasksDao.upsertTask(
          _task(
            'list-1',
            'task-1',
            title: 'Base title',
            updatedUtc: baselineUpdatedUtc,
            rawJson: baselineRawJson,
          ),
        );
        var localEdit = 0;
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++localEdit),
        );

        await repository.patchTask(
          'list-1',
          'task-1',
          const TaskPatchInput({'title': 'Local title'}),
        );
        if (dependentOperation == 'delete_task') {
          await repository.deleteTask('list-1', 'task-1');
        } else {
          await repository.moveTask(
            const TaskMoveInput(
              sourceTaskListId: 'list-1',
              taskId: 'task-1',
              previousSiblingTaskId: 'task-0',
            ),
          );
        }

        final queued = await database.pendingOpsDao.pendingOpsForReplay(
          'account',
          _later,
        );
        expect(queued, hasLength(2));
        final edit = queued.singleWhere(
          (operation) => operation.operation == 'patch_task',
        );
        final dependent = queued.singleWhere(
          (operation) => operation.operation == dependentOperation,
        );
        expect(dependent.dependsOnOpId, edit.id);

        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          random: Random(0),
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps();

        expect(applied, 2);
        expect(await database.select(database.pendingOps).get(), isEmpty);
        expect(apiClient.calls, ['patch_task:task-1', '${action}_task:task-1']);
      },
    );
  }

  test(
    'task edit does not hide an unrelated remote change from deletion',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final baselineRawJson = jsonEncode({
        'id': 'task-1',
        'title': 'A',
        'notes': 'N',
        'updated': baselineUpdatedUtc,
      });
      apiClient
        ..persistTaskPatches = true
        ..remoteTask = _taskDto(
          'task-1',
          title: 'A',
          notes: 'Remote notes',
          updated: DateTime.utc(2026, 6, 4, 0, 5),
        );
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'A',
          updatedUtc: baselineUpdatedUtc,
          rawJson: baselineRawJson,
        ),
      );
      var localEdit = 0;
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++localEdit),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'B'}),
      );
      await repository.deleteTask('list-1', 'task-1');

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 1);
      expect(apiClient.calls, ['patch_task:task-1']);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.operation, 'delete_task');
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('Remote task changed'));
    },
  );

  for (final editCase in [
    (name: 'completion', fields: <String, Object?>{'status': 'completed'}),
    (
      name: 'due date',
      fields: <String, Object?>{'due': DateTime.utc(2026, 6, 10)},
    ),
  ]) {
    test(
      'Google ${editCase.name} followed by deletion does not self-conflict',
      () async {
        const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
        final baselineRaw = <String, Object?>{
          'kind': 'tasks#task',
          'id': 'task-1',
          'title': 'Task',
          'notes': 'Base notes',
          'status': 'needsAction',
          'updated': baselineUpdatedUtc,
        };
        apiClient
          ..persistTaskPatches = true
          ..remoteTask = TaskDto.fromJson(baselineRaw);
        await database.tasksDao.upsertTask(
          _task(
            'list-1',
            'task-1',
            updatedUtc: baselineUpdatedUtc,
            rawJson: jsonEncode(baselineRaw),
          ),
        );
        var edit = 0;
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++edit),
        );
        await repository.patchTask(
          'list-1',
          'task-1',
          TaskPatchInput(editCase.fields),
        );
        await repository.deleteTask('list-1', 'task-1');

        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps();

        expect(applied, 2);
        expect(await database.select(database.pendingOps).get(), isEmpty);
        expect(apiClient.calls, ['patch_task:task-1', 'delete_task:task-1']);
      },
    );

    test(
      'Google ${editCase.name} does not hide an unrelated deletion conflict',
      () async {
        const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
        final baselineRaw = <String, Object?>{
          'kind': 'tasks#task',
          'id': 'task-1',
          'title': 'Task',
          'notes': 'Base notes',
          'status': 'needsAction',
          'updated': baselineUpdatedUtc,
        };
        apiClient
          ..persistTaskPatches = true
          ..remoteTask = TaskDto.fromJson({
            ...baselineRaw,
            'notes': 'Remote notes',
            'updated': '2026-06-04T00:03:00.000Z',
          });
        await database.tasksDao.upsertTask(
          _task(
            'list-1',
            'task-1',
            updatedUtc: baselineUpdatedUtc,
            rawJson: jsonEncode(baselineRaw),
          ),
        );
        var edit = 0;
        final repository = TasksRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++edit),
        );
        await repository.patchTask(
          'list-1',
          'task-1',
          TaskPatchInput(editCase.fields),
        );
        await repository.deleteTask('list-1', 'task-1');

        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: apiClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps();

        expect(applied, 1);
        expect(apiClient.calls, ['patch_task:task-1']);
        final pending = await database.select(database.pendingOps).getSingle();
        expect(pending.operation, 'delete_task');
        expect(pending.lastErrorCode, 'conflict');
      },
    );
  }

  test('queued move followed by deletion does not self-conflict', () async {
    const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
    final baselineRaw = <String, Object?>{
      'kind': 'tasks#task',
      'id': 'task-1',
      'title': 'Task',
      'position': 'old-position',
      'updated': baselineUpdatedUtc,
    };
    apiClient.remoteTask = TaskDto.fromJson(baselineRaw);
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        updatedUtc: baselineUpdatedUtc,
        rawJson: jsonEncode(baselineRaw),
      ),
    );
    var edit = 0;
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++edit),
    );
    await repository.moveTask(
      const TaskMoveInput(
        sourceTaskListId: 'list-1',
        taskId: 'task-1',
        previousSiblingTaskId: 'task-0',
      ),
    );
    await repository.deleteTask('list-1', 'task-1');

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4, 1),
    ).replayDueOps();

    expect(applied, 2);
    expect(apiClient.calls, ['move_task:task-1', 'delete_task:task-1']);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test(
    'queued move followed by deletion preserves a remote notes conflict',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final baselineRaw = <String, Object?>{
        'kind': 'tasks#task',
        'id': 'task-1',
        'title': 'Task',
        'notes': 'Base notes',
        'position': 'old-position',
        'updated': baselineUpdatedUtc,
      };
      apiClient
        ..remoteTask = TaskDto.fromJson(baselineRaw)
        ..remoteTaskAfterMove = TaskDto.fromJson({
          ...baselineRaw,
          'notes': 'Remote notes',
          'position': 'moved-position',
          'updated': '2026-06-04T00:10:00.000Z',
        });
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          updatedUtc: baselineUpdatedUtc,
          rawJson: jsonEncode(baselineRaw),
        ),
      );
      var edit = 0;
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++edit),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          previousSiblingTaskId: 'task-0',
        ),
      );
      await repository.deleteTask('list-1', 'task-1');

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 1);
      expect(apiClient.calls, ['move_task:task-1']);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.operation, 'delete_task');
      expect(pending.lastErrorCode, 'conflict');
    },
  );

  for (final remoteTitle in ['Task', 'Remote task']) {
    final conflicts = remoteTitle != 'Task';
    test(
      'Microsoft collection-to-GET annotation ${conflicts ? 'preserves a real conflict' : 'does not create a conflict'}',
      () async {
        const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
        final baselineRaw = <String, Object?>{
          'id': 'task-1',
          'title': 'Task',
          'status': 'notStarted',
          'lastModifiedDateTime': baselineUpdatedUtc,
          'body': {'content': 'Notes', 'contentType': 'text'},
        };
        await database.tasksDao.upsertTask(
          _task(
            'list-1',
            'task-1',
            updatedUtc: baselineUpdatedUtc,
            rawJson: jsonEncode(baselineRaw),
          ),
        );
        await _enqueue(
          database,
          id: '01',
          operation: 'delete_task',
          taskListId: 'list-1',
          taskId: 'task-1',
          request: const {},
          baselineUpdatedUtc: baselineUpdatedUtc,
          baselineRawJson: jsonEncode(baselineRaw),
        );
        final graphClient = _ConflictMicrosoftTodoApiClient({
          ...baselineRaw,
          '@odata.context':
              r'https://graph.microsoft.com/v1.0/$metadata#tasks/$entity',
          'title': remoteTitle,
        });

        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: _microsoftAdapter(graphClient),
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps();

        expect(applied, conflicts ? 0 : 1);
        expect(graphClient.deleteTaskCalls, conflicts ? 0 : 1);
        if (conflicts) {
          expect(
            (await database.pendingOpsDao.getOp('01'))!.lastErrorCode,
            'conflict',
          );
        } else {
          expect(await database.pendingOpsDao.getOp('01'), equals(null));
        }
      },
    );
  }

  test(
    'Microsoft list rename without updated timestamp detects conflict',
    () async {
      await database.taskListsDao.upsertTaskList(
        _taskList(
          'list-1',
          title: 'Base list',
          rawJson: jsonEncode(const {
            'id': 'list-1',
            'displayName': 'Base list',
          }),
        ),
      );
      final repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.renameTaskList('list-1', 'Local list');
      final graphClient = _ConflictMicrosoftTaskListApiClient(
        list: const {'id': 'list-1', 'displayName': 'Remote list'},
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(graphClient),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 0);
      expect(graphClient.updateTaskListCalls, 0);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('title'));
    },
  );

  test(
    'Microsoft list deletion detects child change without list timestamp',
    () async {
      const childBaseline = '2026-06-04T00:00:00.000Z';
      final baselineTaskRaw = <String, Object?>{
        'id': 'task-1',
        'title': 'Base task',
        'lastModifiedDateTime': childBaseline,
        'body': {'content': 'Base notes', 'contentType': 'text'},
      };
      await database.taskListsDao.upsertTaskList(
        _taskList(
          'list-1',
          title: 'Base list',
          rawJson: jsonEncode(const {
            'id': 'list-1',
            'displayName': 'Base list',
          }),
        ),
      );
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'Base task',
          updatedUtc: childBaseline,
          rawJson: jsonEncode(baselineTaskRaw),
        ),
      );
      final repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.deleteTaskList('list-1');
      final graphClient = _ConflictMicrosoftTaskListApiClient(
        list: const {'id': 'list-1', 'displayName': 'Base list'},
        tasks: const [
          {
            'id': 'task-1',
            'title': 'Base task',
            'lastModifiedDateTime': '2026-06-04T00:10:00.000Z',
            'body': {'content': 'Remote notes', 'contentType': 'text'},
          },
        ],
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(graphClient),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 0);
      expect(graphClient.deleteTaskListCalls, 0);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('Remote task in list'));
    },
  );

  test(
    'Microsoft list deletion detects an independently added remote child',
    () async {
      await database.taskListsDao.upsertTaskList(
        _taskList(
          'list-1',
          rawJson: jsonEncode(const {
            'id': 'list-1',
            'displayName': 'Base list',
          }),
        ),
      );
      final repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await repository.deleteTaskList('list-1');
      final graphClient = _ConflictMicrosoftTaskListApiClient(
        list: const {'id': 'list-1', 'displayName': 'Base list'},
        tasks: const [
          {
            'id': 'remote-task',
            'title': 'Remote task',
            'lastModifiedDateTime': '2026-06-04T00:10:00.000Z',
          },
        ],
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(graphClient),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 0);
      expect(graphClient.deleteTaskListCalls, 0);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.lastErrorCode, 'conflict');
    },
  );

  for (final renameBeforeDelete in [false, true]) {
    test(
      'Microsoft create${renameBeforeDelete ? ' rename' : ''} delete list uses the server identity baseline',
      () async {
        await (database.update(database.accounts)
              ..where((row) => row.id.equals('account')))
            .write(const AccountsCompanion(provider: Value('microsoft')));
        var mutation = 0;
        final repository = TaskListsRepository(
          database: database,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++mutation),
        );
        await repository.createTaskList('Draft list');
        final localList = (await database.taskListsDao.listTaskLists('account'))
            .singleWhere((list) => list.id.startsWith('local-tasklist-'));
        if (renameBeforeDelete) {
          await repository.renameTaskList(localList.id, 'Renamed list');
        }
        await repository.deleteTaskList(localList.id);
        final graphClient = _ConflictMicrosoftTaskListApiClient(
          list: const {'id': 'list-server', 'displayName': 'Draft list'},
        );

        final applied = await PendingOpsReplayer(
          database: database,
          apiClient: _microsoftAdapter(graphClient),
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps();

        expect(applied, renameBeforeDelete ? 3 : 2);
        expect(graphClient.createTaskListCalls, 1);
        expect(graphClient.updateTaskListCalls, renameBeforeDelete ? 1 : 0);
        expect(graphClient.deleteTaskListCalls, 1);
        expect(await database.select(database.pendingOps).get(), isEmpty);
      },
    );
  }

  test(
    'Microsoft create delete list still detects a post-create remote rename',
    () async {
      await (database.update(database.accounts)
            ..where((row) => row.id.equals('account')))
          .write(const AccountsCompanion(provider: Value('microsoft')));
      var mutation = 0;
      final repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++mutation),
      );
      await repository.createTaskList('Draft list');
      final localList = (await database.taskListsDao.listTaskLists('account'))
          .singleWhere((list) => list.id.startsWith('local-tasklist-'));
      await repository.deleteTaskList(localList.id);
      final graphClient = _ConflictMicrosoftTaskListApiClient(
        list: const {'id': 'list-server', 'displayName': 'Draft list'},
        listAfterCreate: const {'displayName': 'Remote list'},
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(graphClient),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 1);
      expect(graphClient.deleteTaskListCalls, 0);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.operation, 'delete_task_list');
      expect(pending.lastErrorCode, 'conflict');
    },
  );

  test(
    'Microsoft child edit followed by list deletion does not self-conflict',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final taskRaw = <String, Object?>{
        'id': 'task-1',
        'title': 'A',
        'status': 'notStarted',
        'lastModifiedDateTime': baselineUpdatedUtc,
        'body': {'content': 'Notes', 'contentType': 'text'},
      };
      await database.taskListsDao.upsertTaskList(
        _taskList(
          'list-1',
          rawJson: jsonEncode(const {'id': 'list-1', 'displayName': 'List'}),
        ),
      );
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'A',
          updatedUtc: baselineUpdatedUtc,
          rawJson: jsonEncode(taskRaw),
        ),
      );
      var mutation = 0;
      final tasks = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++mutation),
      );
      final lists = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++mutation),
      );
      await tasks.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'B'}),
      );
      await lists.deleteTaskList('list-1');
      final graphClient = _ConflictMicrosoftTaskListApiClient(
        list: const {'id': 'list-1', 'displayName': 'List'},
        tasks: [taskRaw],
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(graphClient),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 2);
      expect(graphClient.updateTaskCalls, 1);
      expect(graphClient.deleteTaskListCalls, 1);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test(
    'Microsoft child creation followed by list deletion rebases membership',
    () async {
      await database.taskListsDao.upsertTaskList(
        _taskList(
          'list-1',
          rawJson: jsonEncode(const {'id': 'list-1', 'displayName': 'List'}),
        ),
      );
      var mutation = 0;
      final tasks = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++mutation),
      );
      final lists = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++mutation),
      );
      await tasks.createTask(
        'list-1',
        const TaskCreateInput(title: 'New task'),
      );
      await lists.deleteTaskList('list-1');
      final graphClient = _ConflictMicrosoftTaskListApiClient(
        list: const {'id': 'list-1', 'displayName': 'List'},
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(graphClient),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 2);
      expect(graphClient.createTaskCalls, 1);
      expect(graphClient.deleteTaskListCalls, 1);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test(
    'Microsoft child deletion followed by list deletion rebases membership',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final taskRaw = <String, Object?>{
        'id': 'task-1',
        'title': 'Task',
        'status': 'notStarted',
        'lastModifiedDateTime': baselineUpdatedUtc,
      };
      await database.taskListsDao.upsertTaskList(
        _taskList(
          'list-1',
          rawJson: jsonEncode(const {'id': 'list-1', 'displayName': 'List'}),
        ),
      );
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          updatedUtc: baselineUpdatedUtc,
          rawJson: jsonEncode(taskRaw),
        ),
      );
      var mutation = 0;
      final tasks = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++mutation),
      );
      final lists = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++mutation),
      );
      await tasks.deleteTask('list-1', 'task-1');
      await lists.deleteTaskList('list-1');
      final graphClient = _ConflictMicrosoftTaskListApiClient(
        list: const {'id': 'list-1', 'displayName': 'List'},
        tasks: [taskRaw],
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(graphClient),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 2);
      expect(graphClient.deleteTaskCalls, 1);
      expect(graphClient.deleteTaskListCalls, 1);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test(
    'Microsoft acknowledged child edit preserves a remote notes conflict',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final baselineRaw = <String, Object?>{
        'id': 'task-1',
        'title': 'A',
        'status': 'notStarted',
        'lastModifiedDateTime': baselineUpdatedUtc,
        'body': {'content': 'Base notes', 'contentType': 'text'},
      };
      await database.taskListsDao.upsertTaskList(
        _taskList(
          'list-1',
          rawJson: jsonEncode(const {'id': 'list-1', 'displayName': 'List'}),
        ),
      );
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'A',
          updatedUtc: baselineUpdatedUtc,
          rawJson: jsonEncode(baselineRaw),
        ),
      );
      var mutation = 0;
      final tasks = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++mutation),
      );
      final lists = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++mutation),
      );
      await tasks.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'B'}),
      );
      await lists.deleteTaskList('list-1');
      final graphClient = _ConflictMicrosoftTaskListApiClient(
        list: const {'id': 'list-1', 'displayName': 'List'},
        tasks: [
          {
            ...baselineRaw,
            'lastModifiedDateTime': '2026-06-04T00:03:00.000Z',
            'body': {'content': 'Remote notes', 'contentType': 'text'},
          },
        ],
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(graphClient),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 1);
      expect(graphClient.updateTaskCalls, 1);
      expect(graphClient.deleteTaskListCalls, 0);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.operation, 'delete_task_list');
      expect(pending.lastErrorCode, 'conflict');
    },
  );

  test(
    'earlier local patch does not hide a genuine conflict on a later field',
    () async {
      const baselineUpdatedUtc = '2026-06-04T00:00:00.000Z';
      final baselineRawJson = jsonEncode({
        'id': 'task-1',
        'title': 'Base title',
        'notes': 'Base notes',
        'updated': baselineUpdatedUtc,
      });
      apiClient.persistTaskPatches = true;
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          title: 'Base title',
          updatedUtc: baselineUpdatedUtc,
          rawJson: baselineRawJson,
        ),
      );
      var localEdit = 0;
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 0, 0, ++localEdit),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'title': 'Local title'}),
      );
      await repository.patchTask(
        'list-1',
        'task-1',
        const TaskPatchInput({'notes': 'Local notes'}),
      );
      apiClient.remoteTask = _taskDto(
        'task-1',
        title: 'Base title',
        notes: 'Remote notes',
        updated: DateTime.utc(2026, 6, 4, 0, 5),
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();

      expect(applied, 1);
      expect(apiClient.taskPatchFields, [
        {'title': 'Local title'},
      ]);
      expect(apiClient.remoteTask!.title, 'Local title');
      expect(apiClient.remoteTask!.notes, 'Remote notes');
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.lastErrorCode, 'conflict');
      expect(pending.lastErrorMessage, contains('notes'));
      final local = await database.tasksDao.listTasks('account', 'list-1');
      expect(local.single.title, 'Local title');
      expect(local.single.notes, 'Local notes');
      expect(local.single.localDirty, isTrue);
    },
  );

  test(
    'conflicting task list delete is blocked before remote mutation',
    () async {
      apiClient.remoteTaskList = _taskListDto(
        'list-1',
        title: 'Remote list',
        updated: DateTime.utc(2026, 6, 4, 0, 10),
      );
      await database.taskListsDao.upsertTaskList(
        _taskList(
          'list-1',
          title: 'Base list',
          updatedUtc: '2026-06-04T00:00:00.000Z',
        ),
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'delete_task_list',
        entityType: 'task_list',
        taskListId: 'list-1',
        request: const {},
        baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      final op = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(apiClient.calls, isEmpty);
      expect(op.lastErrorCode, 'conflict');
      expect(op.lastErrorMessage, contains('Remote task list changed'));
    },
  );

  test(
    'conflicting task list delete is blocked by child task change',
    () async {
      apiClient.remoteTasksPage = TasksPageDto(
        items: [_taskDto('task-1', updated: DateTime.utc(2026, 6, 4, 0, 10))],
        rawJson: const {},
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'delete_task_list',
        entityType: 'task_list',
        taskListId: 'list-1',
        request: const {},
        baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      final op = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(apiClient.calls, isEmpty);
      expect(op.lastErrorCode, 'conflict');
      expect(op.lastErrorMessage, contains('Remote task in list changed'));
    },
  );

  test('non-conflicting task list delete proceeds', () async {
    apiClient.remoteTasksPage = TasksPageDto(
      items: [_taskDto('task-1', updated: DateTime.utc(2026, 6, 3, 23, 59))],
      rawJson: const {},
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'delete_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: const {},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    expect(applied, 1);
    expect(apiClient.calls, ['delete_task_list:list-1']);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test('conflicting task delete is blocked before remote mutation', () async {
    apiClient.remoteTask = _taskDto(
      'task-1',
      title: 'Remote task',
      updated: DateTime.utc(2026, 6, 4, 0, 10),
    );
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        title: 'Base task',
        updatedUtc: '2026-06-04T00:00:00.000Z',
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'delete_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: const {},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(op.lastErrorCode, 'conflict');
    expect(op.lastErrorMessage, contains('Remote task changed'));
  });

  test('conflicting task move is blocked before remote mutation', () async {
    apiClient.remoteTask = _taskDto(
      'task-1',
      title: 'Remote task',
      updated: DateTime.utc(2026, 6, 4, 0, 10),
    );
    await database.tasksDao.upsertTask(
      _task(
        'list-1',
        'task-1',
        title: 'Base task',
        updatedUtc: '2026-06-04T00:00:00.000Z',
      ),
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'move_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: {'previous': 'task-0'},
      baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(apiClient.calls, isEmpty);
    expect(op.lastErrorCode, 'conflict');
    expect(op.lastErrorMessage, contains('Remote task changed'));
  });

  test(
    'conflicting clear completed is blocked before remote mutation',
    () async {
      apiClient.remoteTasksPage = TasksPageDto(
        items: [
          _taskDto(
            'task-1',
            status: 'completed',
            updated: DateTime.utc(2026, 6, 4, 0, 10),
          ),
        ],
        rawJson: const {},
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'clear_completed_tasks',
        taskListId: 'list-1',
        request: const {},
        baselineUpdatedUtc: '2026-06-04T00:00:00.000Z',
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      final op = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(apiClient.calls, isEmpty);
      expect(op.lastErrorCode, 'conflict');
      expect(op.lastErrorMessage, contains('Remote completed task changed'));
    },
  );

  test('retryable errors schedule backoff', () async {
    apiClient.patchTaskListError = const GoogleTasksApiError(
      statusCode: 500,
      message: 'Server error',
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'patch_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: {'title': 'Patched'},
    );

    await expectLater(
      PendingOpsReplayer(
        database: database,
        apiClient: apiClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps(),
      throwsA(isA<TaskRemoteError>()),
    );

    final op = await database.select(database.pendingOps).getSingle();
    expect(op.attemptCount, 1);
    expect(op.lastErrorCode, '500');
    expect(op.nextAttemptAtUtc, isNot(equals(null)));
  });

  test('permanent errors block operation far in the future', () async {
    apiClient.patchTaskListError = const GoogleTasksApiError(
      statusCode: 400,
      message: 'Bad request',
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'patch_task_list',
      entityType: 'task_list',
      taskListId: 'list-1',
      request: {'title': 'Patched'},
    );

    await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(op.attemptCount, 1);
    expect(op.lastErrorCode, '400');
    expect(op.nextAttemptAtUtc, startsWith('9999-12-31'));
  });

  for (final statusCode in [400, 403, 404]) {
    test('Microsoft To Do $statusCode errors block operation', () async {
      final microsoftClient = _ThrowingMicrosoftTodoApiClient(
        updateTaskError: MicrosoftTodoApiError(
          statusCode: statusCode,
          code: 'permanent_error',
          message: 'Permanent Microsoft Graph error',
        ),
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: 'task-1',
        request: {'title': 'Patched'},
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: _microsoftAdapter(microsoftClient),
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      final op = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(op.attemptCount, 1);
      expect(op.lastErrorCode, '$statusCode');
      expect(op.lastErrorMessage, 'Permanent Microsoft Graph error');
      expect(op.nextAttemptAtUtc, startsWith('9999-12-31'));
    });
  }

  for (final statusCode in [429, 503]) {
    test('Microsoft To Do $statusCode errors schedule retry', () async {
      final microsoftClient = _ThrowingMicrosoftTodoApiClient(
        updateTaskError: MicrosoftTodoApiError(
          statusCode: statusCode,
          code: 'transient_error',
          message: 'Transient Microsoft Graph error',
        ),
      );
      final now = DateTime.utc(2026, 6, 4);
      await _enqueue(
        database,
        id: '01',
        operation: 'patch_task',
        taskListId: 'list-1',
        taskId: 'task-1',
        request: {'title': 'Patched'},
      );

      await expectLater(
        PendingOpsReplayer(
          database: database,
          apiClient: _microsoftAdapter(microsoftClient),
          accountId: 'account',
          random: Random(0),
          nowUtc: () => now,
        ).replayDueOps(),
        throwsA(isA<TaskRemoteError>()),
      );

      final op = await database.select(database.pendingOps).getSingle();
      expect(op.attemptCount, 1);
      expect(op.lastErrorCode, '$statusCode');
      expect(op.lastErrorMessage, 'Transient Microsoft Graph error');
      expect(DateTime.parse(op.nextAttemptAtUtc!).isAfter(now), isTrue);
      expect(op.nextAttemptAtUtc, isNot(startsWith('9999-12-31')));
    });
  }

  test('Microsoft To Do 404 delete reconciles as success', () async {
    await (database.update(database.accounts)
          ..where((row) => row.id.equals('account')))
        .write(const AccountsCompanion(provider: Value('microsoft')));
    final microsoftClient = _ThrowingMicrosoftTodoApiClient(
      deleteTaskError: const MicrosoftTodoApiError(
        statusCode: 404,
        code: 'not_found',
        message: 'Microsoft To Do task was not found',
      ),
    );
    await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
    await _enqueue(
      database,
      id: '01',
      operation: 'delete_task',
      taskListId: 'list-1',
      taskId: 'task-1',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: _microsoftAdapter(microsoftClient),
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    expect(applied, 1);
    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(await database.tasksDao.listTasks('account', 'list-1'), isEmpty);
  });

  test('unsupported provider operation is blocked during replay', () async {
    apiClient.clearCompletedError = const GoogleTasksApiError(
      statusCode: 400,
      code: 'unsupported_provider_operation',
      message: 'Clear completed is not supported.',
    );
    await _enqueue(
      database,
      id: '01',
      operation: 'clear_completed_tasks',
      taskListId: 'list-1',
      request: const {},
    );

    final applied = await PendingOpsReplayer(
      database: database,
      apiClient: apiClient,
      accountId: 'account',
      random: Random(0),
      nowUtc: () => DateTime.utc(2026, 6, 4),
    ).replayDueOps();

    final op = await database.select(database.pendingOps).getSingle();
    expect(applied, 0);
    expect(op.lastErrorCode, '400');
    expect(op.lastErrorMessage, contains('Clear completed'));
    expect(op.nextAttemptAtUtc, startsWith('9999-12-31'));
  });

  test(
    'replays checklist create and dependent patch against the server id',
    () async {
      final checklistClient = _ChecklistTaskRemoteClient();
      await database.tasksDao.upsertTask(
        _task(
          'list-1',
          'task-1',
          checklistItemsJson: jsonEncode([
            {'id': 'local-step', 'displayName': 'Step', 'isChecked': false},
          ]),
        ),
      );
      await _enqueue(
        database,
        id: '01',
        operation: 'create_task_checklist_item',
        entityType: 'task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        localTempId: 'local-step',
        request: {
          'checklistItemId': 'local-step',
          'body': {'displayName': 'Step', 'isChecked': false},
        },
      );
      await _enqueue(
        database,
        id: '02',
        operation: 'patch_task_checklist_item',
        entityType: 'task_checklist_item',
        taskListId: 'list-1',
        taskId: 'task-1',
        dependsOnOpId: '01',
        request: {
          'checklistItemId': 'local-step',
          'body': {'isChecked': true},
        },
      );

      final applied = await PendingOpsReplayer(
        database: database,
        apiClient: checklistClient,
        accountId: 'account',
        random: Random(0),
        nowUtc: () => DateTime.utc(2026, 6, 4),
      ).replayDueOps();

      final task = (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single;
      final item = decodeTaskChecklistItems(task.microsoftChecklistItemsJson)
          .single;
      expect(applied, 2);
      expect(checklistClient.checklistCalls, [
        'create:Step',
        'update:server-step:true',
      ]);
      expect(item.id, 'server-step');
      expect(item.completed, isTrue);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test(
    'deleting an in-flight checklist create queues a server delete',
    () async {
      final checklistClient = _ChecklistTaskRemoteClient();
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        apiClient: checklistClient,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
      await repository.createSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        title: 'Step',
      );
      final localItem = decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      ).single;
      final gate = Completer<void>();
      checklistClient.createChecklistGate = gate;
      final replay = PendingOpsReplayer(
        database: database,
        apiClient: checklistClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps();
      await _waitFor(() => checklistClient.checklistCalls.isNotEmpty);

      await repository.deleteChecklistSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        checklistItemId: localItem.id,
      );
      final queued = await database.select(database.pendingOps).get();
      final create = queued.singleWhere(
        (operation) => operation.operation == 'create_task_checklist_item',
      );
      final delete = queued.singleWhere(
        (operation) => operation.operation == 'delete_task_checklist_item',
      );
      expect(create.state, 'in_progress');
      expect(delete.dependsOnOpId, create.id);

      gate.complete();
      expect(await replay, 1);
      final afterCreate = decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      );
      expect(afterCreate, isEmpty);
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: checklistClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        1,
      );
      expect(checklistClient.checklistCalls, [
        'create:Step',
        'delete:server-step',
      ]);
    },
  );

  test('checklist claim invalidates a cancellation snapshot before its transaction', () async {
    final checklistClient = _ChecklistTaskRemoteClient();
    final deleteReached = Completer<void>();
    final releaseDelete = Completer<void>();
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      apiClient: checklistClient,
      nowUtc: () => DateTime.utc(2026, 6, 4),
      beforeChecklistDeleteTransaction: () async {
        deleteReached.complete();
        await releaseDelete.future;
      },
    );
    await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
    await repository.createSubtask(
      taskListId: 'list-1',
      parentTaskId: 'task-1',
      title: 'Step',
    );
    final localItem = decodeTaskChecklistItems(
      (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single.microsoftChecklistItemsJson,
    ).single;

    final deletion = repository.deleteChecklistSubtask(
      taskListId: 'list-1',
      parentTaskId: 'task-1',
      checklistItemId: localItem.id,
    );
    await deleteReached.future;
    final createGate = Completer<void>();
    checklistClient.createChecklistGate = createGate;
    final replay = PendingOpsReplayer(
      database: database,
      apiClient: checklistClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4, 1),
    ).replayDueOps();
    await _waitFor(() => checklistClient.checklistCalls.isNotEmpty);
    releaseDelete.complete();
    await deletion;

    final queued = await database.select(database.pendingOps).get();
    final create = queued.singleWhere(
      (operation) => operation.operation == 'create_task_checklist_item',
    );
    final delete = queued.singleWhere(
      (operation) => operation.operation == 'delete_task_checklist_item',
    );
    expect(create.state, 'in_progress');
    expect(delete.dependsOnOpId, create.id);

    createGate.complete();
    expect(await replay, 1);
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: checklistClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 2),
      ).replayDueOps(),
      1,
    );
    expect(checklistClient.checklistCalls, [
      'create:Step',
      'delete:server-step',
    ]);
  });

  test('checklist deletion resolves a creation acknowledged before its transaction', () async {
    final checklistClient = _ChecklistTaskRemoteClient();
    final deleteReached = Completer<void>();
    final releaseDelete = Completer<void>();
    final repository = TasksRepository(
      database: database,
      accountId: 'account',
      apiClient: checklistClient,
      nowUtc: () => DateTime.utc(2026, 6, 4),
      beforeChecklistDeleteTransaction: () async {
        deleteReached.complete();
        await releaseDelete.future;
      },
    );
    await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
    await repository.createSubtask(
      taskListId: 'list-1',
      parentTaskId: 'task-1',
      title: 'Step',
    );
    final localItem = decodeTaskChecklistItems(
      (await database.tasksDao.listTasks(
        'account',
        'list-1',
      )).single.microsoftChecklistItemsJson,
    ).single;

    final deletion = repository.deleteChecklistSubtask(
      taskListId: 'list-1',
      parentTaskId: 'task-1',
      checklistItemId: localItem.id,
    );
    await deleteReached.future;
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: checklistClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 1),
      ).replayDueOps(),
      1,
    );
    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(
      decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      ).single.id,
      'server-step',
    );

    releaseDelete.complete();
    await deletion;
    final pendingDelete = await database
        .select(database.pendingOps)
        .getSingle();
    expect(pendingDelete.operation, 'delete_task_checklist_item');
    expect(
      jsonDecode(pendingDelete.requestJson)['checklistItemId'],
      'server-step',
    );
    expect(
      decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      ),
      isEmpty,
    );
    expect(
      await PendingOpsReplayer(
        database: database,
        apiClient: checklistClient,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4, 2),
      ).replayDueOps(),
      1,
    );
    expect(checklistClient.checklistCalls, [
      'create:Step',
      'delete:server-step',
    ]);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test(
    'checklist deletion accepts a temporary ID after creation is acknowledged',
    () async {
      final checklistClient = _ChecklistTaskRemoteClient();
      final repository = TasksRepository(
        database: database,
        accountId: 'account',
        apiClient: checklistClient,
        nowUtc: () => DateTime.utc(2026, 6, 4),
      );
      await database.tasksDao.upsertTask(_task('list-1', 'task-1'));
      await repository.createSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        title: 'Step',
      );
      final temporaryId = decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      ).single.id;

      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: checklistClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 1),
        ).replayDueOps(),
        1,
      );
      final acknowledged = decodeTaskChecklistItems(
        (await database.tasksDao.listTasks(
          'account',
          'list-1',
        )).single.microsoftChecklistItemsJson,
      ).single;
      expect(acknowledged.id, 'server-step');
      expect(acknowledged.matchesIdentity(temporaryId), isTrue);

      await repository.deleteChecklistSubtask(
        taskListId: 'list-1',
        parentTaskId: 'task-1',
        checklistItemId: temporaryId,
      );

      final pendingDelete = await database
          .select(database.pendingOps)
          .getSingle();
      expect(pendingDelete.operation, 'delete_task_checklist_item');
      expect(
        jsonDecode(pendingDelete.requestJson)['checklistItemId'],
        'server-step',
      );
      expect(
        await PendingOpsReplayer(
          database: database,
          apiClient: checklistClient,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 4, 2),
        ).replayDueOps(),
        1,
      );
      expect(checklistClient.checklistCalls, [
        'create:Step',
        'delete:server-step',
      ]);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test('unknown checklist creation outcome is not submitted again', () async {
    final checklistClient = _ChecklistTaskRemoteClient()
      ..createChecklistItemError = StateError('response was lost');
    await _enqueue(
      database,
      id: '01',
      operation: 'create_task_checklist_item',
      entityType: 'task_checklist_item',
      taskListId: 'list-1',
      taskId: 'task-1',
      localTempId: 'local-step',
      request: {
        'checklistItemId': 'local-step',
        'body': {'displayName': 'Step', 'isChecked': false},
      },
    );

    final replayer = PendingOpsReplayer(
      database: database,
      apiClient: checklistClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
    expect(await replayer.replayDueOps(), 0);
    expect(await replayer.replayDueOps(), 0);

    final pending = await database.pendingOpsDao.getOp('01');
    expect(pending!.state, 'recovery_required');
    expect(checklistClient.checklistCalls, ['create:Step']);
  });
}

Future<(PendingOp, PendingOp)> _queueGoogleDestructiveChain(
  AppDatabase database,
  _GoogleLifecycleTaskRemoteClient provider,
  String chain,
) async {
  await _insertAccount(database);
  for (final listId in ['list-1', 'list-2']) {
    await database.taskListsDao.upsertTaskList(_taskList(listId));
    provider.members[listId] = {};
  }
  final task = TaskDto.fromJson({
    'id': 'task-1',
    'title': 'A',
    'notes': 'N',
    'status': chain == 'delete-child-delete-list' ? 'needsAction' : 'completed',
    'hidden': false,
    'updated': _now,
  });
  provider.members['list-1']!['task-1'] = task;
  await database.tasksDao.upsertTask(
    taskFromDto('account', 'list-1', task, _now),
  );
  final repository = TasksRepository(database: database, accountId: 'account');
  final firstOperation = switch (chain) {
    'clear-delete-list' => 'clear_completed_tasks',
    'delete-child-delete-list' => 'delete_task',
    _ => 'move_task',
  };
  switch (chain) {
    case 'clear-delete-list':
      await repository.clearCompleted('list-1');
    case 'delete-child-delete-list':
      await repository.deleteTask('list-1', 'task-1');
    default:
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'list-1',
          taskId: 'task-1',
          destinationTaskListId: 'list-2',
        ),
      );
  }
  if (chain == 'move-clear-destination') {
    await repository.clearCompleted('list-2');
  } else {
    await TaskListsRepository(
      database: database,
      accountId: 'account',
    ).deleteTaskList('list-1');
  }
  final operations = await database.select(database.pendingOps).get();
  final first = operations.singleWhere((op) => op.operation == firstOperation);
  return (first, operations.singleWhere((op) => op.id != first.id));
}

MicrosoftTodoTaskRemoteClient _microsoftAdapter(MicrosoftTodoApiClient client) {
  return MicrosoftTodoTaskRemoteClient(
    client: client,
    defaultTimeZone: 'UTC',
    nowUtc: () => DateTime.utc(2026, 6, 4),
  );
}

const _checklistSecondPage =
    'https://graph.microsoft.test/checklist?page=second';

class _LostChecklistMicrosoftTodoApiClient
    implements MicrosoftTodoApiClient, MicrosoftTodoChecklistApiClient {
  final items = <String, Map<String, Object?>>{};
  final pages = <String?>[];
  final updates = <Map<String, Object?>>[];
  bool loseNextUpdateResponse = true;
  Object? nextSecondPageError;

  @override
  Future<MicrosoftTodoChecklistItemsPageDto> listChecklistItemsPage({
    required String taskListId,
    required String taskId,
    String? nextLink,
  }) async {
    pages.add(nextLink);
    if (nextLink != null) {
      final error = nextSecondPageError;
      nextSecondPageError = null;
      if (error != null) throw error;
    }
    return MicrosoftTodoChecklistItemsPageDto(
      items: [
        for (final entry in items.entries)
          if ((nextLink == null) == (entry.key == 'sibling'))
            MicrosoftTodoChecklistItemDto.fromJson(entry.value),
      ],
      nextLink: nextLink == null ? _checklistSecondPage : null,
      rawJson: const {},
    );
  }

  @override
  Future<MicrosoftTodoChecklistItemDto> updateChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
    required Map<String, Object?> patch,
  }) async {
    updates.add(Map.of(patch));
    final current = {...items[checklistItemId]!, ...patch};
    if (patch.containsKey('isChecked')) {
      if (patch['isChecked'] == true) {
        current['checkedDateTime'] = '2026-06-04T01:00:00.0000000Z';
      } else {
        current.remove('checkedDateTime');
      }
    }
    items[checklistItemId] = current;
    if (loseNextUpdateResponse) {
      loseNextUpdateResponse = false;
      throw StateError('QA checklist response lost after commit');
    }
    return MicrosoftTodoChecklistItemDto.fromJson(current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GoogleLifecycleTaskRemoteClient extends _LifecycleTaskRemoteClient {
  final effects = <String>[];
  final pageReads = <String>[];
  bool sawTombstone = false;
  bool sawHidden = false;
  void Function(String taskListId)? afterClear;
  void Function(String taskListId)? afterMove;

  @override
  Future<void> clearCompletedTasks(String taskListId) async {
    clearCount++;
    effects.add('clear:$taskListId');
    final tasks = members[taskListId]!;
    for (final task in tasks.values.toList()) {
      if (task.status == 'completed' && task.deleted != true) {
        tasks[task.id] = TaskDto.fromJson({
          ...task.rawJson,
          'hidden': true,
          'updated': '2026-06-04T02:00:00.000Z',
        });
      }
    }
    afterClear?.call(taskListId);
  }

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) async {
    final before = await getTask(taskListId: taskListId, taskId: taskId);
    members[taskListId]![taskId] = TaskDto.fromJson({
      ...before.rawJson,
      'deleted': true,
      'updated': '2026-06-04T02:00:00.000Z',
    });
    effects.add('delete:$taskId');
  }

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) async {
    final moved = await super.moveTask(
      sourceTaskListId: sourceTaskListId,
      taskId: taskId,
      parentTaskId: parentTaskId,
      previousSiblingTaskId: previousSiblingTaskId,
      destinationTaskListId: destinationTaskListId,
    );
    final destination = destinationTaskListId ?? sourceTaskListId;
    effects.add('move:$taskId:$sourceTaskListId:$destination');
    afterMove?.call(destination);
    return members[destination]?[taskId] ?? moved;
  }

  @override
  Future<void> deleteTaskList(String taskListId) async {
    effects.add('delete-list:$taskListId');
    await super.deleteTaskList(taskListId);
  }

  @override
  Future<TasksPageDto> listTasksPage({
    required String taskListId,
    DateTime? completedMax,
    DateTime? completedMin,
    DateTime? dueMax,
    DateTime? dueMin,
    int maxResults = 100,
    String? pageToken,
    bool showCompleted = true,
    bool showDeleted = false,
    bool showHidden = false,
    DateTime? updatedMin,
    bool showAssigned = false,
  }) async {
    final all = (members[taskListId]?.values ?? <TaskDto>[])
        .where(
          (task) =>
              (showCompleted || task.status != 'completed') &&
              (showDeleted || task.deleted != true) &&
              (showHidden || task.hidden != true) &&
              (updatedMin == null ||
                  task.updated == null ||
                  !task.updated!.isBefore(updatedMin)),
        )
        .toList();
    final offset = int.tryParse(pageToken ?? '') ?? 0;
    final result = all.skip(offset).take(1).toList();
    sawTombstone = sawTombstone || result.any((task) => task.deleted == true);
    sawHidden = sawHidden || result.any((task) => task.hidden == true);
    pageReads.add(
      '$taskListId:$showCompleted:$showDeleted:$showHidden:$offset',
    );
    return TasksPageDto(
      items: result,
      nextPageToken: offset + 1 < all.length ? '${offset + 1}' : null,
      rawJson: const {},
    );
  }
}

class _ThrowingMicrosoftTodoApiClient implements MicrosoftTodoApiClient {
  _ThrowingMicrosoftTodoApiClient({this.updateTaskError, this.deleteTaskError});

  final MicrosoftTodoApiError? updateTaskError;
  final MicrosoftTodoApiError? deleteTaskError;

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) async {
    final error = deleteTaskError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<MicrosoftTodoTaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> patch,
  }) async {
    final error = updateTaskError;
    if (error != null) {
      throw error;
    }
    return MicrosoftTodoTaskDto(
      id: taskId,
      title: patch['title']?.toString(),
      categories: const [],
      rawJson: {'id': taskId, ...patch},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LostMicrosoftTodoApiClient implements MicrosoftTodoApiClient {
  _LostMicrosoftTodoApiClient(this.current);
  Map<String, Object?> current;
  var updates = 0;
  var loseResponse = true;

  @override
  Future<MicrosoftTodoTaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async => MicrosoftTodoTaskDto.fromJson(current);

  @override
  Future<MicrosoftTodoTaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> patch,
  }) async {
    updates++;
    current = {
      ...current,
      ...patch,
      'lastModifiedDateTime': '2026-06-04T01:00:00.000Z',
    };
    final completion = current['completedDateTime'];
    if (completion is Map && completion['timeZone'] == 'UTC') {
      current['completedDateTime'] = {
        ...completion,
        'dateTime': completion['dateTime']?.toString().replaceFirst(
          '.000Z',
          '.0000000',
        ),
      };
    }
    if (loseResponse) {
      loseResponse = false;
      throw StateError('QA Graph response lost after commit');
    }
    return MicrosoftTodoTaskDto.fromJson(current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ConflictMicrosoftTodoApiClient implements MicrosoftTodoApiClient {
  _ConflictMicrosoftTodoApiClient(Map<String, Object?> remoteTask)
    : remoteTask = MicrosoftTodoTaskDto.fromJson(remoteTask);

  final MicrosoftTodoTaskDto remoteTask;
  int updateTaskCalls = 0;
  int deleteTaskCalls = 0;

  @override
  Future<MicrosoftTodoTaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async => remoteTask;

  @override
  Future<MicrosoftTodoTaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> patch,
  }) async {
    updateTaskCalls += 1;
    return MicrosoftTodoTaskDto.fromJson({...remoteTask.rawJson, ...patch});
  }

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) async {
    deleteTaskCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ConflictMicrosoftTaskListApiClient implements MicrosoftTodoApiClient {
  _ConflictMicrosoftTaskListApiClient({
    required Map<String, Object?> list,
    List<Map<String, Object?>> tasks = const [],
    this.listAfterCreate,
  }) : _list = Map<String, Object?>.from(list),
       _tasks = tasks.map(Map<String, Object?>.from).toList();

  Map<String, Object?> _list;
  final List<Map<String, Object?>> _tasks;
  final Map<String, Object?>? listAfterCreate;
  int createTaskListCalls = 0;
  int updateTaskListCalls = 0;
  int deleteTaskListCalls = 0;
  int createTaskCalls = 0;
  int updateTaskCalls = 0;
  int deleteTaskCalls = 0;

  @override
  Future<MicrosoftTodoTaskListDto> createTaskList({
    required String displayName,
  }) async {
    createTaskListCalls += 1;
    final created = <String, Object?>{
      ..._list,
      'id': _list['id'] ?? 'list-server',
      'displayName': displayName,
    };
    _list = listAfterCreate == null
        ? Map<String, Object?>.from(created)
        : {...created, ...listAfterCreate!};
    return MicrosoftTodoTaskListDto.fromJson(created);
  }

  @override
  Future<MicrosoftTodoTaskListsPageDto> listTaskListsPage({
    String? nextLink,
  }) async {
    return MicrosoftTodoTaskListsPageDto.fromJson({
      'value': [_list],
    });
  }

  @override
  Future<MicrosoftTodoTaskListDto> updateTaskList({
    required String taskListId,
    required Map<String, Object?> patch,
  }) async {
    updateTaskListCalls += 1;
    _list = {..._list, ...patch};
    return MicrosoftTodoTaskListDto.fromJson(_list);
  }

  @override
  Future<void> deleteTaskList(String taskListId) async {
    deleteTaskListCalls += 1;
  }

  @override
  Future<MicrosoftTodoTasksPageDto> listTasksPage({
    required String taskListId,
    String? nextLink,
  }) async {
    return MicrosoftTodoTasksPageDto.fromJson({'value': _tasks});
  }

  @override
  Future<MicrosoftTodoTaskDto> createTask({
    required String taskListId,
    required Map<String, Object?> body,
  }) async {
    createTaskCalls += 1;
    final created = <String, Object?>{
      'id': 'task-server',
      'title': body['title'] ?? '',
      'status': body['status'] ?? 'notStarted',
      'lastModifiedDateTime': '2026-06-04T00:05:00.000Z',
      ...body,
    };
    _tasks.add(created);
    return MicrosoftTodoTaskDto.fromJson(created);
  }

  @override
  Future<MicrosoftTodoTaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    return MicrosoftTodoTaskDto.fromJson(
      _tasks.singleWhere((task) => task['id'] == taskId),
    );
  }

  @override
  Future<MicrosoftTodoTaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> patch,
  }) async {
    updateTaskCalls += 1;
    final index = _tasks.indexWhere((task) => task['id'] == taskId);
    final updated = <String, Object?>{
      ..._tasks[index],
      ...patch,
      'lastModifiedDateTime': '2026-06-04T00:05:00.000Z',
    };
    _tasks[index] = updated;
    return MicrosoftTodoTaskDto.fromJson(updated);
  }

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) async {
    deleteTaskCalls += 1;
    _tasks.removeWhere((task) => task['id'] == taskId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CommitInterruption extends QueryInterceptor {
  final commitReached = Completer<void>();
  final _resume = Completer<void>();
  var _armed = false;

  void arm() => _armed = true;

  void resume() {
    if (!_resume.isCompleted) _resume.complete();
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await super.commitTransaction(inner);
    if (!_armed) return;
    _armed = false;
    commitReached.complete();
    await _resume.future;
  }
}

class _FakeTaskRemoteClient implements TaskRemoteClient {
  final remoteTasksPages = <String, TasksPageDto>{};
  TaskDto? createdTask;
  final List<TaskDto> createdTasks = [];
  final calls = <String>[];
  final taskPatchFields = <Map<String, Object?>>[];
  final createParentTaskIds = <String?>[];
  final moveParentTaskIds = <String?>[];
  final taskListPatchTitles = <String>[];
  GoogleTasksApiError? patchTaskListError;
  Object? createTaskListError;
  Object? createTaskError;
  Object? patchTaskError;
  GoogleTasksApiError? deleteTaskError;
  GoogleTasksApiError? clearCompletedError;
  GoogleTasksApiError? moveTaskError;
  TaskListDto? remoteTaskList;
  TaskDto? remoteTask;
  final Map<String, TaskDto> remoteTasksById = {};
  TaskDto? remoteTaskAfterSecondPatch;
  TaskDto? remoteTaskAfterMove;
  DateTime? taskListPatchResultUpdated;
  final taskListPageUpdatedMins = <DateTime?>[];
  Completer<void>? createTaskGate;
  Completer<void>? createTaskListStarted;
  Completer<void>? createTaskListGate;
  Completer<void>? taskListPatchStarted;
  Completer<void>? taskListPatchGate;
  bool persistTaskPatches = false;
  bool persistTaskListPatches = false;
  int _taskPatchRevision = 0;
  TasksPageDto remoteTasksPage = const TasksPageDto(items: [], rawJson: {});
  TaskListsPageDto remoteTaskListsPage = const TaskListsPageDto(
    items: [],
    rawJson: {},
  );

  @override
  Future<TaskListDto> createTaskList({required String title}) async {
    calls.add('create_task_list:$title');
    if (createTaskListStarted?.isCompleted == false) {
      createTaskListStarted!.complete();
    }
    await createTaskListGate?.future;
    final error = createTaskListError;
    if (error != null) throw error;
    return _taskListDto('list-server', title: title);
  }

  @override
  Future<TaskListDto> patchTaskList(
    String taskListId,
    TaskListPatch patch,
  ) async {
    final error = patchTaskListError;
    if (error != null) {
      throw error;
    }
    calls.add('patch_task_list:$taskListId');
    final title = patch.fields['title'].toString();
    taskListPatchTitles.add(title);
    if (taskListPatchStarted?.isCompleted == false) {
      taskListPatchStarted!.complete();
    }
    await taskListPatchGate?.future;
    final result = _taskListDto(
      taskListId,
      title: title,
      updated: taskListPatchResultUpdated,
    );
    if (persistTaskListPatches) remoteTaskList = result;
    return result;
  }

  @override
  Future<TaskListDto> updateTaskList(
    String taskListId,
    TaskListPut replacement,
  ) async {
    calls.add('update_task_list:$taskListId');
    return _taskListDto(
      taskListId,
      title: replacement.fields['title'].toString(),
    );
  }

  @override
  Future<void> deleteTaskList(String taskListId) async {
    calls.add('delete_task_list:$taskListId');
  }

  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    calls.add('create_task:$taskListId');
    createParentTaskIds.add(parentTaskId);
    await createTaskGate?.future;
    final error = createTaskError;
    if (error != null) throw error;
    return (createdTasks.isNotEmpty ? createdTasks.removeAt(0) : createdTask) ??
        _taskDto('task-server', title: create.fields['title'].toString());
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    final error = patchTaskError;
    if (error != null) throw error;
    taskPatchFields.add(patch.fields);
    calls.add('patch_task:$taskId');
    final current = remoteTask;
    final revision = DateTime.utc(2026, 6, 4, 0, ++_taskPatchRevision + 5);
    final patchedRaw = <String, Object?>{
      ...?current?.rawJson,
      'id': taskId,
      ...patch.fields,
      'updated': revision.toIso8601String(),
    };
    if (patch.fields['status'] == 'completed' &&
        !patchedRaw.containsKey('completed')) {
      patchedRaw['completed'] = revision.toIso8601String();
    } else if (patch.fields.containsKey('status') &&
        patch.fields['status'] != 'completed') {
      patchedRaw.remove('completed');
    }
    final dto = persistTaskPatches
        ? TaskDto.fromJson(patchedRaw)
        : _taskDto(taskId, title: patch.fields['title'].toString());
    if (persistTaskPatches) {
      remoteTask = dto;
      if (taskPatchFields.length == 2 && remoteTaskAfterSecondPatch != null) {
        remoteTask = remoteTaskAfterSecondPatch;
      }
    }
    return dto;
  }

  @override
  Future<TaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required TaskPut replacement,
  }) async {
    calls.add('update_task:$taskId');
    return _taskDto(taskId, title: replacement.fields['title'].toString());
  }

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) async {
    final error = deleteTaskError;
    if (error != null) {
      throw error;
    }
    calls.add('delete_task:$taskId');
  }

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) async {
    calls.add('move_task:$taskId');
    moveParentTaskIds.add(parentTaskId);
    final error = moveTaskError;
    if (error != null) throw error;
    final current = remoteTask;
    final movedRaw = <String, Object?>{
      ...?current?.rawJson,
      'id': taskId,
      'title': current?.title ?? 'Task',
      'position': 'moved-position',
      'updated': DateTime.utc(2026, 6, 4, 0, 5).toIso8601String(),
      if (parentTaskId != null) 'parent': parentTaskId,
    };
    if (parentTaskId == null) movedRaw.remove('parent');
    final result = TaskDto.fromJson(movedRaw);
    remoteTask = result;
    final afterMove = remoteTaskAfterMove;
    if (afterMove != null) remoteTask = afterMove;
    return result;
  }

  @override
  Future<void> clearCompletedTasks(String taskListId) async {
    final error = clearCompletedError;
    if (error != null) {
      throw error;
    }
    calls.add('clear:$taskListId');
  }

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    return remoteTasksById[taskId] ?? remoteTask ?? _taskDto(taskId);
  }

  @override
  Future<TaskListDto> getTaskList(String taskListId) async {
    return remoteTaskList ?? _taskListDto(taskListId);
  }

  @override
  Future<TaskListsPageDto> listTaskListsPage({
    int maxResults = 1000,
    String? pageToken,
  }) async => remoteTaskListsPage;

  @override
  Future<TasksPageDto> listTasksPage({
    required String taskListId,
    DateTime? completedMax,
    DateTime? completedMin,
    DateTime? dueMax,
    DateTime? dueMin,
    int maxResults = 100,
    String? pageToken,
    bool showCompleted = true,
    bool showDeleted = false,
    bool showHidden = false,
    DateTime? updatedMin,
    bool showAssigned = false,
  }) async {
    taskListPageUpdatedMins.add(updatedMin);
    return remoteTasksPages[taskListId] ?? remoteTasksPage;
  }
}

class _StatefulChecklistTaskRemoteClient extends _FakeTaskRemoteClient
    implements TaskChecklistRemoteClient {
  final items = <String, Map<String, Object?>>{};
  final pages = <String?>[];
  final writes = <String>[];

  TaskChecklistItemDto _dto(Map<String, Object?> raw) => TaskChecklistItemDto(
    id: raw['id']! as String,
    title: raw['displayName']! as String,
    completed: raw['isChecked'] == true,
    rawJson: raw,
  );

  @override
  Future<TaskChecklistItemsPageDto> listChecklistItemsPage({
    required String taskListId,
    required String taskId,
    String? pageToken,
  }) async {
    pages.add(pageToken);
    return TaskChecklistItemsPageDto(
      items: [
        for (final entry in items.entries)
          if ((entry.key == 'sibling') == (pageToken == null))
            _dto(entry.value),
      ],
      nextPageToken: pageToken == null ? 'second' : null,
      rawJson: const {},
    );
  }

  @override
  Future<TaskChecklistItemDto> updateChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
    String? title,
    bool? completed,
  }) async {
    writes.add('update:$checklistItemId');
    final updated = {
      ...?items[checklistItemId],
      'id': checklistItemId,
      if (title != null) 'displayName': title,
      if (completed != null) 'isChecked': completed,
    };
    items[checklistItemId] = updated;
    return _dto(updated);
  }

  @override
  Future<void> deleteChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
  }) async {
    writes.add('delete:$checklistItemId');
    items.remove(checklistItemId);
  }

  @override
  Future<TaskChecklistItemDto> createChecklistItem({
    required String taskListId,
    required String taskId,
    required String title,
    bool completed = false,
  }) async {
    writes.add('create');
    return _dto(
      items['created'] = {
        'id': 'created',
        'displayName': title,
        'isChecked': completed,
      },
    );
  }
}

class _LifecycleTaskRemoteClient extends _FakeTaskRemoteClient {
  final writes = <Map<String, Object?>>[];
  final members = <String, Map<String, TaskDto>>{};
  final deletedLists = <String>[];
  final moveFailures = <String>{};
  int patchCount = 0;
  int clearCount = 0;
  bool loseNextPatchResponse = false;
  Object? nextGetError;
  Object? nextMutationError;
  int putCount = 0;
  Future<void> Function()? onListRead;

  @override
  Future<void> clearCompletedTasks(String taskListId) async {
    clearCount++;
    final tasks = members[taskListId]!;
    for (final task in tasks.values.toList()) {
      if (task.status == 'completed') {
        tasks[task.id] = TaskDto.fromJson({...task.rawJson, 'hidden': true});
      }
    }
  }

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    final readError = nextGetError;
    nextGetError = null;
    if (readError != null) throw readError;
    final task = members[taskListId]?[taskId];
    if (task == null) {
      throw const TaskRemoteError(statusCode: 404, message: 'Missing QA task');
    }
    return task;
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    final mutationError = nextMutationError;
    nextMutationError = null;
    if (mutationError != null) throw mutationError;
    final before = await getTask(taskListId: taskListId, taskId: taskId);
    patchCount++;
    writes.add(Map.of(patch.fields));
    final updated = TaskDto.fromJson({
      ...before.rawJson,
      ...patch.fields,
      'updated': DateTime.utc(2026, 6, 4, 1, patchCount).toIso8601String(),
    });
    members[taskListId]![taskId] = updated;
    if (loseNextPatchResponse) {
      loseNextPatchResponse = false;
      throw StateError('QA response lost after provider commit');
    }
    return updated;
  }

  @override
  Future<TaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required TaskPut replacement,
  }) async {
    putCount++;
    return patchTask(
      taskListId: taskListId,
      taskId: taskId,
      patch: TaskPatch.fields(replacement.fields),
    );
  }

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) async {
    if (moveFailures.contains(taskId)) {
      throw const TaskRemoteError(statusCode: 400, message: 'QA rejected move');
    }
    final before = await getTask(taskListId: sourceTaskListId, taskId: taskId);
    final moved = TaskDto.fromJson({
      ...before.rawJson,
      'updated': '2026-06-04T00:11:00.000Z',
    });
    members[sourceTaskListId]!.remove(taskId);
    (members[destinationTaskListId ?? sourceTaskListId] ??= {})[taskId] = moved;
    return moved;
  }

  @override
  Future<void> deleteTaskList(String taskListId) async {
    deletedLists.add(taskListId);
    members.remove(taskListId);
  }

  @override
  Future<TasksPageDto> listTasksPage({
    required String taskListId,
    DateTime? completedMax,
    DateTime? completedMin,
    DateTime? dueMax,
    DateTime? dueMin,
    int maxResults = 100,
    String? pageToken,
    bool showCompleted = true,
    bool showDeleted = false,
    bool showHidden = false,
    DateTime? updatedMin,
    bool showAssigned = false,
  }) async {
    final onRead = onListRead;
    onListRead = null;
    await onRead?.call();
    return TasksPageDto(
      items: (members[taskListId]?.values ?? <TaskDto>[])
          .where(
            (task) =>
                updatedMin == null ||
                task.updated == null ||
                !task.updated!.isBefore(updatedMin),
          )
          .toList(),
      rawJson: const {},
    );
  }
}

class _ChecklistTaskRemoteClient extends _FakeTaskRemoteClient
    implements TaskChecklistRemoteClient {
  final checklistCalls = <String>[];
  final remoteItems = <String, TaskChecklistItemDto>{};
  Object? createChecklistItemError;
  Completer<void>? createChecklistGate;

  @override
  Future<TaskChecklistItemDto> createChecklistItem({
    required String taskListId,
    required String taskId,
    required String title,
    bool completed = false,
  }) async {
    checklistCalls.add('create:$title');
    await createChecklistGate?.future;
    final error = createChecklistItemError;
    if (error != null) throw error;
    return remoteItems['server-step'] = TaskChecklistItemDto(
      id: 'server-step',
      title: title,
      completed: completed,
      rawJson: {
        'id': 'server-step',
        'displayName': title,
        'isChecked': completed,
      },
    );
  }

  @override
  Future<TaskChecklistItemDto> updateChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
    String? title,
    bool? completed,
  }) async {
    checklistCalls.add('update:$checklistItemId:$completed');
    final existing = remoteItems[checklistItemId]!;
    return remoteItems[checklistItemId] = TaskChecklistItemDto(
      id: checklistItemId,
      title: title ?? existing.title,
      completed: completed ?? existing.completed,
      rawJson: {
        ...existing.rawJson,
        'displayName': title ?? existing.title,
        'isChecked': completed ?? existing.completed,
      },
    );
  }

  @override
  Future<void> deleteChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
  }) async {
    checklistCalls.add('delete:$checklistItemId');
    remoteItems.remove(checklistItemId);
  }

  @override
  Future<TaskChecklistItemsPageDto> listChecklistItemsPage({
    required String taskListId,
    required String taskId,
    String? pageToken,
  }) async => TaskChecklistItemsPageDto(
    items: remoteItems.values.toList(),
    rawJson: const {},
  );
}

Future<void> _insertAccount(AppDatabase database) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'google-account',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
}

TaskListsCompanion _taskList(
  String id, {
  String title = 'List',
  String? updatedUtc,
  String? rawJson,
}) {
  return TaskListsCompanion.insert(
    accountId: 'account',
    id: id,
    title: title,
    updatedUtc: Value(updatedUtc),
    rawJson: rawJson ?? jsonEncode({'id': id, 'title': title}),
    localDirty: Value(id.startsWith('local-')),
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

TasksCompanion _task(
  String taskListId,
  String id, {
  String title = 'Task',
  String? updatedUtc,
  String? rawJson,
  String? checklistItemsJson,
  String? assignmentInfoJson,
}) {
  return TasksCompanion.insert(
    accountId: 'account',
    taskListId: taskListId,
    id: id,
    title: title,
    updatedUtc: Value(updatedUtc),
    rawJson: rawJson ?? jsonEncode({'id': id, 'title': title}),
    microsoftChecklistItemsJson: Value(checklistItemsJson),
    assignmentInfoJson: Value(assignmentInfoJson),
    localDirty: Value(id.startsWith('local-')),
    localCreated: Value(id.startsWith('local-')),
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

Future<void> _enqueue(
  AppDatabase database, {
  required String id,
  required String operation,
  required Map<String, Object?> request,
  String entityType = 'task',
  String? operationType,
  String? taskListId,
  String? taskId,
  String? localTempId,
  String? dependsOnOpId,
  String? baselineUpdatedUtc,
  String? baselineRawJson,
}) {
  return database.pendingOpsDao.enqueue(
    PendingOpsCompanion.insert(
      id: id,
      accountId: 'account',
      entityType: entityType,
      operation: operation,
      operationType: Value(operationType),
      taskListId: Value(taskListId),
      taskId: Value(taskId),
      localTempId: Value(localTempId),
      dependsOnOpId: Value(dependsOnOpId),
      baselineUpdatedUtc: Value(baselineUpdatedUtc),
      baselineRawJson: Value(baselineRawJson),
      requestJson: jsonEncode(request),
      createdAtUtc: '2026-06-04T00:00:${id.padLeft(2, '0')}.000Z',
      updatedAtUtc: _now,
    ),
  );
}

TaskListDto _taskListDto(
  String id, {
  String title = 'List',
  DateTime? updated,
}) {
  return TaskListDto(
    id: id,
    title: title,
    updated: updated,
    rawJson: {
      'id': id,
      'title': title,
      if (updated != null) 'updated': updated.toIso8601String(),
    },
  );
}

TaskDto _taskDto(
  String id, {
  String title = 'Task',
  String? notes,
  DateTime? updated,
  String? status,
  String? parent,
}) {
  return TaskDto(
    id: id,
    title: title,
    notes: notes,
    updated: updated,
    status: status,
    parent: parent,
    rawJson: {
      'id': id,
      'title': title,
      if (notes != null) 'notes': notes,
      if (updated != null) 'updated': updated.toIso8601String(),
      if (status != null) 'status': status,
      if (parent != null) 'parent': parent,
    },
  );
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for condition.');
}

const _now = '2026-06-04T00:00:00.000Z';
final _later = DateTime.utc(2026, 6, 4, 1);

class _ThrottledMicrosoftTodoApiClient implements MicrosoftTodoApiClient {
  Map<String, Object?> current = {
    'id': 'task-1',
    'title': 'Recurring task',
    'status': 'notStarted',
    'lastModifiedDateTime': '2026-06-04T00:00:00.000Z',
    'recurrence': {
      'pattern': {'type': 'daily', 'interval': 1},
      'range': {'type': 'noEnd', 'startDate': '2026-06-04'},
    },
  };
  int remainingThrottles = 2;
  int updates = 0;
  int completionMutations = 0;
  bool loseCompletionResponse = false;
  bool throttleRead = false;
  final readStatuses = <String?>[];
  MicrosoftTodoApiError throttled() => MicrosoftTodoApiError.fromResponse(
    statusCode: 429,
    body: '{"error":{"code":"TooManyRequests","message":"QA throttled"}}',
    headers: {'retry-after': '300'},
  );
  @override
  Future<MicrosoftTodoTaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    if (throttleRead) {
      throttleRead = false;
      throw throttled();
    }
    readStatuses.add(current['status'] as String?);
    return MicrosoftTodoTaskDto.fromJson(current);
  }

  @override
  Future<MicrosoftTodoTaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> patch,
  }) async {
    updates++;
    if (patch['status'] == 'completed') completionMutations++;
    if (remainingThrottles > 0) {
      remainingThrottles--;
      throw throttled();
    }
    current = {
      ...current,
      ...patch,
      'lastModifiedDateTime': DateTime.utc(
        2026,
        6,
        4,
        1,
        updates,
      ).toIso8601String(),
    };
    if (loseCompletionResponse) {
      loseCompletionResponse = false;
      throw StateError('QA response lost after provider commit');
    }
    return MicrosoftTodoTaskDto.fromJson(current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
