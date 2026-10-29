import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R03 supported moves retain scoped recovery provenance through ack, pull and restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'busymax-move-identity-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tasks.sqlite');
    var database = AppDatabase(NativeDatabase(file));
    addTearDown(() => database.close());
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'qa',
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'synthetic',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: '',
            updatedAtUtc: '',
          ),
        );
    for (final list in ['a', 'b', 'c', 'unrelated']) {
      await database.taskListsDao.upsertTaskList(
        TaskListsCompanion.insert(
          accountId: 'qa',
          id: list,
          title: list,
          rawJson: '{}',
          createdLocalAtUtc: '',
          updatedLocalAtUtc: '',
        ),
      );
    }
    final provider = _MoveProvider();
    await database.tasksDao.upsertTask(
      taskFromDto('qa', 'a', provider.current, ''),
    );
    for (final move in [('a', 'b'), ('b', 'c')]) {
      final repository = TasksRepository(database: database, accountId: 'qa');
      await repository.moveTask(
        TaskMoveInput(
          sourceTaskListId: move.$1,
          destinationTaskListId: move.$2,
          taskId: 't',
        ),
      );
      expect(await repository.readTask(move.$1, 't'), isNull);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.taskListId, move.$1);
      expect(
        (jsonDecode(pending.requestJson) as Map)['destinationTasklist'],
        move.$2,
      );
      final metadata = jsonDecode(
        (await repository.readTask(move.$2, 't'))!.providerMetadataJson ?? '{}',
      ) as Map;
      expect(
        metadata['_busymaxTaskPreviousListIds'],
        containsAll(['a', if (move.$1 == 'b') 'b']),
      );
      expect(
        await PendingOpsReplayer(
          database: database,
          accountId: 'qa',
          apiClient: provider,
        ).replayDueOps(),
        1,
      );
      expect(provider.listId, move.$2);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      // Provider projections contain no client recovery metadata. A normal
      // refresh must retain only provenance already established for this row.
      await database.tasksDao.upsertTask(
        taskFromDto('qa', move.$2, provider.current, ''),
      );
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      final row = await (database.select(
        database.tasks,
      )..where((row) => row.taskListId.equals(move.$2))).getSingle();
      expect(
        (jsonDecode(row.providerMetadataJson ?? '{}')
            as Map)['_busymaxTaskPreviousListIds'],
        containsAll(['a', if (move.$1 == 'b') 'b']),
      );
    }
    expect(provider.moves, 2);
    await database.tasksDao.upsertTask(
      taskFromDto('qa', 'unrelated', provider.current, ''),
    );
    final unrelated = await (database.select(
      database.tasks,
    )..where((row) => row.taskListId.equals('unrelated'))).getSingle();
    expect(
      (jsonDecode(unrelated.providerMetadataJson ?? '{}')
          as Map)['_busymaxTaskPreviousListIds'],
      isNull,
    );
    final repository = TasksRepository(database: database, accountId: 'qa');
    await repository.moveTask(
      const TaskMoveInput(sourceTaskListId: 'c', taskId: 't'),
    );
    final unchangedScope = await repository.readTask('c', 't');
    expect(
      (jsonDecode(unchangedScope!.providerMetadataJson!)
          as Map)['_busymaxTaskPreviousListIds'],
      unorderedEquals(['a', 'b']),
    );
    final beforeRows = (await database.select(database.tasks).get())
        .map((row) => row.toJson())
        .toList();
    final beforeOps = (await database.select(database.pendingOps).get())
        .map((row) => row.toJson())
        .toList();
    await expectLater(
      repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'c',
          destinationTaskListId: 'missing',
          taskId: 't',
        ),
      ),
      throwsStateError,
    );
    expect(
      (await database.select(database.tasks).get())
          .map((row) => row.toJson())
          .toList(),
      beforeRows,
    );
    expect(
      (await database.select(database.pendingOps).get())
          .map((row) => row.toJson())
          .toList(),
      beforeOps,
    );
  });
}

class _MoveProvider implements TaskRemoteClient {
  var listId = 'a';
  var moves = 0;
  final _task = <String, Object?>{
    'id': 't',
    'title': 'Task',
    'notes': 'Notes',
    'status': 'needsAction',
    'updated': '2026-10-22T00:00:00Z',
  };
  TaskDto get current => TaskDto.fromJson({..._task});

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    expect(taskListId, listId);
    expect(taskId, 't');
    return current;
  }

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) async {
    expect(sourceTaskListId, listId);
    expect(taskId, 't');
    listId = destinationTaskListId ?? listId;
    _task['updated'] = DateTime.utc(2026, 10, 22, ++moves).toIso8601String();
    return current;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
