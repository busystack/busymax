import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_draft.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late TasksRepository repository;
  late _StatefulTasks provider;
  setUp(() async {
    database = AppDatabase.memoryForTests();
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account',
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'synthetic',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: '',
            updatedAtUtc: '',
          ),
        );
    for (final id in ['a', 'b']) {
      await database.taskListsDao.upsertTaskList(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: id,
          title: id,
          rawJson: '{}',
          createdLocalAtUtc: '',
          updatedLocalAtUtc: '',
        ),
      );
    }
    provider = _StatefulTasks();
    provider.tasks['t'] = {
      'id': 't',
      'title': 'A',
      'notes': 'N',
      'status': 'needsAction',
      'updated': '2026-08-01T00:00:00Z',
    };
    repository = TasksRepository(
      database: database,
      accountId: 'account',
      apiClient: provider,
      nowUtc: () => DateTime.utc(2026, 8, 2),
    );
    await _pull(database, provider);
  });
  tearDown(() => database.close());

  test(
    'F04 observed same-field change rejects Save without touching row/outbox',
    () async {
      final observed = (await repository.readTask('a', 't'))!;
      final draft = TaskDetailsDraft.fromTask(
        observed,
        'UTC',
      ).copyWith(title: 'C');
      provider.tasks['t']!['title'] = 'B';
      provider.tasks['t']!['updated'] = '2026-08-01T01:00:00Z';
      await _pull(database, provider);
      await expectLater(
        repository.patchTask(
          'a',
          't',
          TaskPatchInput(
            draft.toPatch(
              observed,
              googleTaskCollectionCapabilities,
              localTimeZone: 'UTC',
            ),
            observedTask: draft.observedTask,
          ),
        ),
        throwsA(isA<TaskDraftConflictException>()),
      );
      expect((await repository.readTask('a', 't'))!.title, 'B');
      expect(draft.title, 'C');
      expect(provider.tasks['t']!['title'], 'B');
      expect(await database.select(database.pendingOps).get(), isEmpty);
      // Explicitly reload the remote version before making another edit.
      final resolved = (await repository.readTask('a', 't'))!;
      await repository.patchTask(
        'a',
        't',
        TaskPatchInput({'title': 'D'}, observedTask: resolved),
      );
      expect((await repository.readTask('a', 't'))!.title, 'D');
    },
  );

  test(
    'F04 disjoint remote edit merges and retains genuine queued baseline',
    () async {
      final observed = (await repository.readTask('a', 't'))!;
      provider.tasks['t']!['notes'] = 'R';
      provider.tasks['t']!['updated'] = '2026-08-01T01:00:00Z';
      await _pull(database, provider);
      await repository.patchTask(
        'a',
        't',
        TaskPatchInput({'title': 'C'}, observedTask: observed),
      );
      final row = (await repository.readTask('a', 't'))!;
      expect(row.title, 'C');
      expect(row.notes, 'R');
      final op = await database.select(database.pendingOps).getSingle();
      expect(jsonDecode(op.requestJson), {'title': 'C'});
      expect((jsonDecode(op.baselineRawJson!) as Map)['title'], 'A');
      await PendingOpsReplayer(
        database: database,
        apiClient: provider,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 8, 3),
      ).replayDueOps();
      expect(provider.tasks['t']!['title'], 'C');
      expect(provider.tasks['t']!['notes'], 'R');
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test(
    'F04 acknowledged predecessor permits edit, unseen pending edit conflicts',
    () async {
      await repository.patchTask(
        'a',
        't',
        const TaskPatchInput({'title': 'P'}),
      );
      final observed = (await repository.readTask('a', 't'))!;
      await PendingOpsReplayer(
        database: database,
        apiClient: provider,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 8, 3),
      ).replayDueOps();
      await repository.patchTask(
        'a',
        't',
        TaskPatchInput({'title': 'Q'}, observedTask: observed),
      );
      await expectLater(
        repository.patchTask(
          'a',
          't',
          TaskPatchInput({'title': 'C'}, observedTask: observed),
        ),
        throwsA(isA<TaskDraftConflictException>()),
      );
      expect((await repository.readTask('a', 't'))!.title, 'Q');
      expect(await database.select(database.pendingOps).get(), hasLength(1));
      final latest = (await repository.readTask('a', 't'))!;
      await repository.patchTask(
        'a',
        't',
        TaskPatchInput(const {}, observedTask: latest),
      );
      expect(await database.select(database.pendingOps).get(), hasLength(1));
    },
  );

  test(
    'F07 acknowledgment retains watch/draft identity and subsequent references',
    () async {
      final temporary = await repository.createTask(
        'a',
        const TaskCreateInput(title: 'Draft'),
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      provider.beforeCreate = () async {
        entered.complete();
        await release.future;
      };
      final observed = (await repository.readTask('a', temporary))!;
      final seen = <TaskEntity?>[];
      final sub = repository.watchTask('a', temporary).listen(seen.add);
      final replay = PendingOpsReplayer(
        database: database,
        apiClient: provider,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 8, 3),
      ).replayDueOps();
      await entered.future;
      final draft = TaskDetailsDraft.fromTask(
        observed,
        'UTC',
      ).copyWith(title: 'Edited', notes: 'Exact notes');
      release.complete();
      await replay;
      final acknowledged = (await repository.readTask('a', temporary))!;
      expect(acknowledged.id, 'created-1');
      expect(acknowledged.matchesIdentity(temporary), isTrue);
      // Refresh cannot discard the verified alias used after a process restart.
      final row = (await database.select(database.tasks).get()).singleWhere(
        (t) => t.id == acknowledged.id,
      );
      await database.tasksDao.upsertTask(
        taskFromDto(
          'account',
          'a',
          TaskDto.fromJson(provider.tasks[acknowledged.id]!),
          row.updatedLocalAtUtc,
        ),
      );
      expect((await repository.readTask('a', temporary))!.id, acknowledged.id);
      await repository.patchTask(
        'a',
        temporary,
        TaskPatchInput(
          draft.toPatch(
            observed,
            googleTaskCollectionCapabilities,
            localTimeZone: 'UTC',
          ),
          observedTask: observed,
        ),
      );
      await repository.createSubtask(
        taskListId: 'a',
        parentTaskId: temporary,
        title: 'Child',
      );
      await sub.cancel();
      expect(seen.where((t) => t == null), isEmpty);
      await repository.moveTask(
        TaskMoveInput(
          sourceTaskListId: 'a',
          taskId: temporary,
          destinationTaskListId: 'b',
        ),
      );
      expect(await repository.watchTask('a', temporary).first, isNull);
      final ops = await database.select(database.pendingOps).get();
      expect(ops.every((op) => op.taskId != temporary), isTrue);
      expect(ops.every((op) => !op.requestJson.contains(temporary)), isTrue);
      expect((await repository.readTask('b', temporary))!.notes, 'Exact notes');
      await repository.deleteTask('b', temporary);
      expect(
        (await database.select(database.pendingOps).get()).last.taskId,
        acknowledged.id,
      );
    },
  );

  test(
    'F07 genuine missing target fails instead of queuing a zero-row mutation',
    () async {
      await expectLater(
        repository.patchTask(
          'a',
          'missing',
          const TaskPatchInput({'title': 'Ghost'}),
        ),
        throwsStateError,
      );
      await expectLater(
        repository.deleteTask('a', 'missing'),
        throwsStateError,
      );
      await expectLater(
        repository.moveTask(
          const TaskMoveInput(sourceTaskListId: 'a', taskId: 'missing'),
        ),
        throwsStateError,
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(await repository.readTask('b', 't'), isNull);
    },
  );

  test('F11 notification failure returns committed create/patch and requests sync once', () async {
    var queued = 0;
    final auxiliary = <Object>[];
    repository = TasksRepository(
      database: database,
      accountId: 'account',
      onMutationQueued: () => queued++,
      onNotificationScheduleChanged: () async =>
          throw StateError('scheduler unavailable'),
      onAuxiliaryFailure: (error, _) async => auxiliary.add(error),
    );
    final id = await repository.createTask(
      'a',
      const TaskCreateInput(title: 'Durable'),
    );
    await repository.patchTask(
      'a',
      id,
      const TaskPatchInput({'notes': 'Committed'}),
    );
    final row = (await repository.readTask('a', id))!;
    expect(row.title, 'Durable');
    expect(row.notes, 'Committed');
    expect(
      (await database.select(database.pendingOps).get()).map(
        (op) => op.operation,
      ),
      ['create_task', 'patch_task'],
    );
    expect(queued, 2);
    expect(auxiliary, hasLength(2));
  });

  test(
    'F11 precommit outbox rejection rolls back row and retry creates once',
    () async {
      await database.customStatement(
        "CREATE TRIGGER fail_queue BEFORE INSERT ON pending_ops BEGIN SELECT RAISE(FAIL, 'synthetic local commit failure'); END",
      );
      await expectLater(
        repository.createTask(
          'a',
          const TaskCreateInput(title: 'Retry', notes: 'Exact'),
        ),
        throwsA(anything),
      );
      expect(await database.tasksDao.listTasks('account', 'a'), hasLength(1));
      expect(await database.select(database.pendingOps).get(), isEmpty);
      await database.customStatement('DROP TRIGGER fail_queue');
      final id = await repository.createTask(
        'a',
        const TaskCreateInput(title: 'Retry', notes: 'Exact'),
      );
      expect((await repository.readTask('a', id))!.notes, 'Exact');
      expect(await database.select(database.pendingOps).get(), hasLength(1));
    },
  );
}

Future<void> _pull(AppDatabase db, _StatefulTasks provider) =>
    db.tasksDao.upsertTask(
      taskFromDto('account', 'a', TaskDto.fromJson(provider.tasks['t']!), ''),
    );

class _StatefulTasks implements TaskRemoteClient {
  final tasks = <String, Map<String, Object?>>{};
  Future<void> Function()? beforeCreate;
  var creates = 0;
  var patches = 0;
  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async => TaskDto.fromJson(tasks[taskId]!);
  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    await beforeCreate?.call();
    final id = 'created-${++creates}';
    tasks[id] = {'id': id, ...create.fields, 'updated': '2026-08-02T01:00:00Z'};
    return TaskDto.fromJson(tasks[id]!);
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    tasks[taskId]!.addAll(patch.fields);
    tasks[taskId]!['updated'] = DateTime.utc(
      2026,
      8,
      3,
      0,
      ++patches,
    ).toIso8601String();
    return TaskDto.fromJson(tasks[taskId]!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
