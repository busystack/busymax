import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/mutation/dav_task_list_mutation_service.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:busymax/src/providers/busy_provider.dart';

void main() {
  late AppDatabase database;
  late TaskListsRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await _insertAccount(database);
    repository = TaskListsRepository(
      database: database,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 4),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('createTaskList writes local row and queues create op', () async {
    var mutationQueuedCalls = 0;
    repository = _repository(
      database,
      onMutationQueued: () => mutationQueuedCalls += 1,
    );

    await repository.createTaskList('Inbox');

    final lists = await database.taskListsDao.listTaskLists('account');
    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      DateTime.utc(2026, 6, 4, 1),
    );

    expect(lists.single.id, startsWith('local-tasklist-'));
    expect(lists.single.title, 'Inbox');
    expect(lists.single.localDirty, isTrue);
    expect(ops.single.operation, 'create_task_list');
    expect(jsonDecode(ops.single.requestJson), {'title': 'Inbox'});
    expect(mutationQueuedCalls, 1);
  });

  test('Microsoft createTaskList keeps the cloud pending path', () async {
    await (database.update(
      database.accounts,
    )..where((row) => row.id.equals('account'))).write(
      const AccountsCompanion(
        provider: Value('microsoft'),
        authority: Value('https://login.microsoftonline.com/common'),
        providerAccountId: Value('microsoft-account'),
      ),
    );

    await repository.createTaskList('Microsoft list');

    final list = await database.select(database.taskLists).getSingle();
    final operation = await database.select(database.pendingOps).getSingle();
    expect(list.id, startsWith('local-tasklist-'));
    expect(operation.operation, 'create_task_list');
    expect(jsonDecode(operation.requestJson), {'title': 'Microsoft list'});
  });

  test('createTaskList requires a non-empty title', () async {
    await expectLater(repository.createTaskList('   '), throwsArgumentError);
    expect(await database.select(database.taskLists).get(), isEmpty);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  for (final provider in [BusyProvider.appleICloud, BusyProvider.webCal]) {
    test('${provider.displayName} task-list creation is rejected', () async {
      await (database.update(
        database.accounts,
      )..where((row) => row.id.equals('account'))).write(
        AccountsCompanion(
          provider: Value(provider.storageValue),
          credentialKind: Value(
            provider == BusyProvider.webCal
                ? 'webcal_subscription'
                : 'apple_app_specific_password',
          ),
        ),
      );

      await expectLater(
        repository.createTaskList('Unsupported'),
        throwsStateError,
      );
      expect(await database.select(database.taskLists).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    });
  }

  test('renameTaskList updates local row and queues patch op', () async {
    var mutationQueuedCalls = 0;
    repository = _repository(
      database,
      onMutationQueued: () => mutationQueuedCalls += 1,
    );
    await database.taskListsDao.upsertTaskList(
      TaskListsCompanion.insert(
        accountId: 'account',
        id: 'list-1',
        title: 'Inbox',
        updatedUtc: const Value('2026-06-04T00:00:00.000Z'),
        rawJson: '{"id":"list-1","title":"Inbox"}',
        createdLocalAtUtc: _now,
        updatedLocalAtUtc: _now,
      ),
    );

    await repository.renameTaskList('list-1', 'Renamed');

    final lists = await database.taskListsDao.listTaskLists('account');
    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      DateTime.utc(2026, 6, 4, 1),
    );

    expect(lists.single.title, 'Renamed');
    expect(lists.single.localDirty, isTrue);
    expect(ops.single.operation, 'patch_task_list');
    expect(ops.single.baselineUpdatedUtc, '2026-06-04T00:00:00.000Z');
    expect(ops.single.baselineRawJson, '{"id":"list-1","title":"Inbox"}');
    expect(mutationQueuedCalls, 1);
  });

  test('deleteTaskList requests sync after queuing delete op', () async {
    var mutationQueuedCalls = 0;
    repository = _repository(
      database,
      onMutationQueued: () => mutationQueuedCalls += 1,
    );
    await database.taskListsDao.upsertTaskList(_taskList('list-1'));

    await repository.deleteTaskList('list-1');

    final lists = await database.taskListsDao.listTaskLists('account');
    final ops = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      DateTime.utc(2026, 6, 4, 1),
    );

    expect(lists.single.pendingDelete, isTrue);
    expect(ops.single.operation, 'delete_task_list');
    expect(mutationQueuedCalls, 1);
  });

  test('listTaskLists hides pending-delete and server-missing rows', () async {
    await database.taskListsDao.upsertTaskList(_taskList('visible'));
    await database.taskListsDao.upsertTaskList(
      _taskList('pending-delete', pendingDelete: const Value(true)),
    );
    await database.taskListsDao.upsertTaskList(
      _taskList('server-missing', serverMissing: const Value(true)),
    );

    final lists = await repository.listTaskLists();
    final watchedLists = await repository.watchTaskLists().first;

    expect(lists.map((list) => list.id), ['visible']);
    expect(watchedLists.map((list) => list.id), ['visible']);
  });

  test(
    'setRemindersEnabled updates only the local notification policy',
    () async {
      var scheduleChangedCalls = 0;
      repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 4),
        onNotificationScheduleChanged: () async {
          scheduleChangedCalls += 1;
        },
      );
      await database.taskListsDao.upsertTaskList(_taskList('list-1'));

      await repository.setRemindersEnabled('list-1', false);

      final list = await database.select(database.taskLists).getSingle();
      expect(list.remindersEnabled, isFalse);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(scheduleChangedCalls, 1);
    },
  );

  test(
    'provider refresh preserves the local task-list reminder policy',
    () async {
      await database.taskListsDao.upsertTaskList(
        _taskList('list-1', remindersEnabled: const Value(false)),
      );

      await database.taskListsDao.upsertTaskList(
        taskListFromDto(
          'account',
          const TaskListDto(
            id: 'list-1',
            title: 'Renamed remotely',
            rawJson: {'id': 'list-1', 'title': 'Renamed remotely'},
          ),
          _now,
        ),
      );

      final list = await database.select(database.taskLists).getSingle();
      expect(list.title, 'Renamed remotely');
      expect(list.remindersEnabled, isFalse);
    },
  );

  test(
    'Nextcloud list mutations use CalDAV instead of REST pending ops',
    () async {
      await (database.update(
        database.accounts,
      )..where((row) => row.id.equals('account'))).write(
        const AccountsCompanion(
          provider: Value('nextcloud'),
          authority: Value('https://cloud.example.test'),
          providerAccountId: Value('alex'),
          credentialKind: Value('nextcloud_app_password'),
        ),
      );
      await database
          .into(database.davCollections)
          .insert(
            DavCollectionsCompanion.insert(
              id: 'collection',
              accountId: 'account',
              hrefKey: '/remote.php/dav/calendars/alex/tasks/',
              requestUri:
                  'https://cloud.example.test/remote.php/dav/calendars/alex/tasks/',
              displayName: 'Tasks',
              supportedComponentMask: const Value(2),
              taskProjectionEnabled: const Value(true),
              createdAtUtc: _now,
              updatedAtUtc: _now,
            ),
          );
      await database.taskListsDao.upsertTaskList(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: 'dav-list',
          davCollectionId: const Value('collection'),
          title: 'Tasks',
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
      final dav = _FakeDavTaskListMutations();
      repository = TaskListsRepository(
        database: database,
        accountId: 'account',
        davMutationClient: dav,
      );

      await repository.createTaskList('New list');
      await repository.renameTaskList('dav-list', 'Renamed');
      await repository.deleteTaskList('dav-list');

      expect(dav.created, ['New list']);
      expect(dav.renamed, [('collection', 'Renamed')]);
      expect(dav.deleted, ['collection']);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(
        (await database.select(database.taskLists).getSingle()).title,
        'Tasks',
        reason: 'DAV projections change only after server-confirmed discovery.',
      );
    },
  );
}

TaskListsRepository _repository(
  AppDatabase database, {
  void Function()? onMutationQueued,
}) {
  return TaskListsRepository(
    database: database,
    accountId: 'account',
    onMutationQueued: onMutationQueued,
    nowUtc: () => DateTime.utc(2026, 6, 4),
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

const _now = '2026-06-04T00:00:00.000Z';

TaskListsCompanion _taskList(
  String id, {
  Value<bool> pendingDelete = const Value.absent(),
  Value<bool> serverMissing = const Value.absent(),
  Value<bool> remindersEnabled = const Value.absent(),
}) {
  return TaskListsCompanion.insert(
    accountId: 'account',
    id: id,
    title: 'Inbox',
    pendingDelete: pendingDelete,
    serverMissing: serverMissing,
    remindersEnabled: remindersEnabled,
    rawJson: '{}',
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  );
}

final class _FakeDavTaskListMutations implements DavTaskListMutationClient {
  final created = <String>[];
  final renamed = <(String, String)>[];
  final deleted = <String>[];

  @override
  Future<void> createTaskList(String title) async => created.add(title);

  @override
  Future<void> deleteTaskList(String collectionId) async {
    deleted.add(collectionId);
  }

  @override
  Future<void> renameTaskList(String collectionId, String title) async {
    renamed.add((collectionId, title));
  }
}
