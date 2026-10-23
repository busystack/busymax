import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final acknowledgement in [
    'before read',
    'after read',
    'after enqueue',
    'after read with unavailable list',
  ]) {
    test(
      'R07 checklist creation resolves parent acknowledgement $acknowledgement',
      () async {
        final barrier = _ReadDeliveryBarrier();
        final database = AppDatabase(
          NativeDatabase.memory().interceptWith(barrier),
        );
        addTearDown(database.close);
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'microsoft-qa',
                provider: 'microsoft',
                authority: 'https://login.microsoftonline.com',
                providerAccountId: 'synthetic',
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                createdAtUtc: '',
                updatedAtUtc: '',
              ),
            );
        for (final id in ['list', 'other']) {
          await database.taskListsDao.upsertTaskList(
            TaskListsCompanion.insert(
              accountId: 'microsoft-qa',
              id: id,
              title: id,
              rawJson: '{}',
              createdLocalAtUtc: '',
              updatedLocalAtUtc: '',
            ),
          );
        }
        final provider = _ChecklistProvider();
        final repository = TasksRepository(
          database: database,
          accountId: 'microsoft-qa',
          apiClient: provider,
          nowUtc: () => DateTime.utc(2026, 10, 22),
        );
        Future<int> replay() => PendingOpsReplayer(
          database: database,
          accountId: 'microsoft-qa',
          apiClient: provider,
          nowUtc: () => DateTime.utc(2026, 10, 23),
        ).replayDueOps();
        final temporary = await repository.createTask(
          'list',
          const TaskCreateInput(title: 'Parent'),
        );
        final parentReplay = replay();
        await provider.createEntered.future;
        if (acknowledgement == 'before read') {
          provider.releaseCreate.complete();
          expect(await parentReplay, 1);
        }
        final holdsRead = acknowledgement.startsWith('after read');
        if (holdsRead) barrier.arm(temporary);
        final child = repository.createSubtask(
          taskListId: 'list',
          parentTaskId: temporary,
          title: 'Held child',
        );
        if (holdsRead) {
          await barrier.readCompleted.future;
          // The SELECT has completed in SQLite, but its old result has not yet
          // reached the repository. Acknowledgment really commits in this window.
          provider.releaseCreate.complete();
          expect(await parentReplay, 1);
          expect(
            (await repository.readTask('list', temporary))!.id,
            'parent-server',
          );
          if (acknowledgement.endsWith('unavailable list')) {
            await TaskListsRepository(
              database: database,
              accountId: 'microsoft-qa',
            ).deleteTaskList('list');
            final rowsBefore = (await database.select(database.tasks).get())
                .map((task) => task.toJson())
                .toList();
            final operationsBefore =
                (await database.select(database.pendingOps).get())
                    .map((op) => op.toJson())
                    .toList();
            barrier.releaseDelivery.complete();
            await expectLater(child, throwsStateError);
            expect(
              (await database.select(database.tasks).get())
                  .map((task) => task.toJson())
                  .toList(),
              rowsBefore,
            );
            expect(
              (await database.select(database.pendingOps).get())
                  .map((op) => op.toJson())
                  .toList(),
              operationsBefore,
            );
            expect(provider.checklistCreates, 0);
            return;
          }
          await repository.createSubtask(
            taskListId: 'list',
            parentTaskId: 'parent-server',
            title: 'Sibling',
          );
          expect(await replay(), 1);
          final sibling = (await repository.readTask(
            'list',
            temporary,
          ))!.microsoftChecklistItems.single;
          expect(sibling.id, 'step-1');
          expect(sibling.localIdentityAliases, hasLength(1));
          await repository.patchChecklistSubtask(
            taskListId: 'list',
            parentTaskId: 'parent-server',
            checklistItemId: sibling.id,
            title: 'Newer sibling edit',
          );
          barrier.releaseDelivery.complete();
        }
        await child;
        if (acknowledgement == 'after enqueue') {
          final operations = await database.select(database.pendingOps).get();
          final create = operations.singleWhere(
            (op) => op.operation == 'create_task',
          );
          final step = operations.singleWhere(
            (op) => op.operation == 'create_task_checklist_item',
          );
          expect(step.dependsOnOpId, create.id);
          provider.releaseCreate.complete();
          expect(await parentReplay, 1);
        }
        final parent = (await repository.readTask('list', temporary))!;
        expect(parent.id, 'parent-server');
        final operations = await database.select(database.pendingOps).get();
        expect(operations, isNotEmpty);
        expect(
          operations.every(
            (op) => op.taskId == parent.id && op.taskListId == 'list',
          ),
          isTrue,
        );
        final held = parent.microsoftChecklistItems.where(
          (item) => item.title == 'Held child',
        );
        expect(held, hasLength(1));
        if (acknowledgement == 'after read') {
          expect(parent.microsoftChecklistItems, hasLength(2));
          final sibling = parent.microsoftChecklistItems.singleWhere(
            (item) => item.id == 'step-1',
          );
          expect(sibling.title, 'Newer sibling edit');
          expect(sibling.localIdentityAliases, hasLength(1));
        }
        expect(await replay(), acknowledgement == 'after read' ? 2 : 1);
        expect(await database.select(database.pendingOps).get(), isEmpty);
        expect(provider.createdParents, everyElement('parent-server'));
        expect(
          provider.items.values.where(
            (item) => item['displayName'] == 'Held child',
          ),
          hasLength(1),
        );
        expect(
          provider.checklistCreates,
          acknowledgement == 'after read' ? 2 : 1,
        );
        expect(
          (await repository.readTask(
            'list',
            temporary,
          ))!.microsoftChecklistItems.length,
          acknowledgement == 'after read' ? 2 : 1,
        );
        // An alias is only valid inside the original account/list ownership.
        await expectLater(
          repository.createSubtask(
            taskListId: 'other',
            parentTaskId: temporary,
            title: 'Wrong list',
          ),
          throwsStateError,
        );
        await expectLater(
          TasksRepository(
            database: database,
            accountId: 'another-account',
            apiClient: provider,
          ).createSubtask(
            taskListId: 'list',
            parentTaskId: temporary,
            title: 'Wrong account',
          ),
          throwsStateError,
        );
        await expectLater(
          repository.createSubtask(
            taskListId: 'list',
            parentTaskId: 'missing',
            title: 'Unavailable',
          ),
          throwsStateError,
        );
        expect(await database.select(database.pendingOps).get(), isEmpty);
      },
    );
  }
}

class _ReadDeliveryBarrier extends QueryInterceptor {
  String? _taskId;
  final readCompleted = Completer<void>();
  final releaseDelivery = Completer<void>();
  void arm(String taskId) => _taskId = taskId;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    if (_taskId != null &&
        result.any(
          (row) => row['id'] == _taskId && row['task_list_id'] == 'list',
        )) {
      _taskId = null;
      readCompleted.complete();
      await releaseDelivery.future;
    }
    return result;
  }
}

class _ChecklistProvider
    implements TaskRemoteClient, TaskChecklistRemoteClient {
  final createEntered = Completer<void>();
  final releaseCreate = Completer<void>();
  final items = <String, Map<String, Object?>>{};
  final createdParents = <String>[];
  var checklistCreates = 0;
  var revision = 0;
  Map<String, Object?> parent = {};

  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    createEntered.complete();
    await releaseCreate.future;
    parent = {
      'id': 'parent-server',
      ...create.fields,
      'updated': '2026-10-22T01:00:00Z',
    };
    return TaskDto.fromJson(parent);
  }

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    expect(taskId, 'parent-server');
    return TaskDto.fromJson({
      ...parent,
      'checklistItems': items.values.toList(),
    });
  }

  @override
  Future<TaskChecklistItemDto> createChecklistItem({
    required String taskListId,
    required String taskId,
    required String title,
    bool completed = false,
  }) async {
    expect(taskId, 'parent-server');
    createdParents.add(taskId);
    final id = 'step-${++checklistCreates}';
    items[id] = {
      'id': id,
      'displayName': title,
      'isChecked': completed,
      'createdDateTime': '2026-10-22T02:00:00Z',
    };
    return _item(items[id]!);
  }

  @override
  Future<TaskChecklistItemsPageDto> listChecklistItemsPage({
    required String taskListId,
    required String taskId,
    String? pageToken,
  }) async {
    expect(taskId, 'parent-server');
    final all = items.values.toList();
    final index = int.parse(pageToken ?? '0');
    return TaskChecklistItemsPageDto(
      items: all.skip(index).take(1).map(_item).toList(),
      rawJson: const {},
      nextPageToken: index + 1 < all.length ? '${index + 1}' : null,
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
    expect(taskId, 'parent-server');
    final item = items[checklistItemId]!;
    if (title != null) item['displayName'] = title;
    if (completed != null) item['isChecked'] = completed;
    item['modifiedDateTime'] = '2026-10-22T03:${++revision}:00Z';
    return _item(jsonDecode(jsonEncode(item)) as Map<String, Object?>);
  }

  TaskChecklistItemDto _item(Map<String, Object?> item) => TaskChecklistItemDto(
    id: item['id']! as String,
    title: item['displayName']! as String,
    completed: item['isChecked'] == true,
    rawJson: Map.of(item),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
