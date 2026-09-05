import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../db/app_database.dart';
import '../../../dav/mutation/dav_task_list_mutation_service.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_collection_creation_capabilities.dart';
import '../../notifications/notification_schedule_service.dart';
import '../../tasks/domain/task_remote_client.dart';
import '../../tasks/domain/task_remote_models.dart';

class TaskListEntity {
  const TaskListEntity({
    required this.accountId,
    required this.id,
    required this.title,
    required this.localDirty,
    required this.pendingDelete,
    required this.rawJson,
    this.remindersEnabled = true,
    this.updatedUtc,
    this.etag,
    this.providerListKind,
    this.isOwner,
    this.isShared,
    this.davCollectionId,
  });

  factory TaskListEntity.fromRow(TaskList row) {
    return TaskListEntity(
      accountId: row.accountId,
      id: row.id,
      title: row.title,
      localDirty: row.localDirty,
      pendingDelete: row.pendingDelete,
      rawJson: row.rawJson,
      remindersEnabled: row.remindersEnabled,
      updatedUtc: row.updatedUtc,
      etag: row.etag,
      providerListKind: row.providerListKind,
      isOwner: row.isOwner,
      isShared: row.isShared,
      davCollectionId: row.davCollectionId,
    );
  }

  final String accountId;
  final String id;
  final String title;
  final bool localDirty;
  final bool pendingDelete;
  final String rawJson;
  final bool remindersEnabled;
  final String? updatedUtc;
  final String? etag;
  final String? providerListKind;
  final bool? isOwner;
  final bool? isShared;
  final String? davCollectionId;

  bool get isMicrosoftBuiltIn =>
      providerListKind == 'defaultList' || providerListKind == 'flaggedEmails';

  bool get canRenameOrDeleteForMicrosoft =>
      !isMicrosoftBuiltIn && isOwner != false;
}

class TaskListsRepository {
  TaskListsRepository({
    required AppDatabase database,
    required String accountId,
    TaskRemoteClient? apiClient,
    DavTaskListMutationClient? davMutationClient,
    void Function()? onMutationQueued,
    Future<void> Function()? onNotificationScheduleChanged,
    Uuid uuid = const Uuid(),
    DateTime Function()? nowUtc,
  }) : _database = database,
       _accountId = accountId,
       _apiClient = apiClient,
       _davMutationClient = davMutationClient,
       _onMutationQueued = onMutationQueued,
       _onNotificationScheduleChanged = onNotificationScheduleChanged,
       _uuid = uuid,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final String _accountId;
  final TaskRemoteClient? _apiClient;
  final DavTaskListMutationClient? _davMutationClient;
  final void Function()? _onMutationQueued;
  final Future<void> Function()? _onNotificationScheduleChanged;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  Stream<List<TaskListEntity>> watchTaskLists() {
    return _database.taskListsDao
        .watchTaskLists(_accountId)
        .map((rows) => rows.map(TaskListEntity.fromRow).toList());
  }

  Future<List<TaskListEntity>> listTaskLists() async {
    final rows = await _database.taskListsDao.listTaskLists(_accountId);
    return rows
        .where((row) => !row.pendingDelete && !row.serverMissing)
        .map(TaskListEntity.fromRow)
        .toList();
  }

  Stream<TaskListEntity?> watchTaskList(String id) {
    final query = _database.select(_database.taskLists)
      ..where(
        (row) =>
            row.accountId.equals(_accountId) &
            row.id.equals(id) &
            row.pendingDelete.equals(false) &
            row.serverMissing.equals(false),
      );
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : TaskListEntity.fromRow(row),
    );
  }

  Future<void> createTaskList(String title) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'A task-list name is required.',
      );
    }
    final mode = await _taskListCreationMode();
    switch (mode) {
      case TaskListCreationMode.nextcloudDav:
        await _requiredDavMutationClient().createTaskList(trimmedTitle);
        return;
      case TaskListCreationMode.unavailable:
        throw StateError('Task-list creation is unavailable for this account.');
      case TaskListCreationMode.cloudPendingOperation:
        break;
    }
    final now = _now();
    final localId = 'local-tasklist-${_uuid.v4()}';
    await _database.transaction(() async {
      await _database.taskListsDao.upsertTaskList(
        TaskListsCompanion.insert(
          accountId: _accountId,
          id: localId,
          title: trimmedTitle,
          rawJson: jsonEncode({'id': localId, 'title': trimmedTitle}),
          localDirty: const Value(true),
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
      await _enqueue(
        operation: 'create_task_list',
        taskListId: localId,
        localTempId: localId,
        request: {'title': trimmedTitle},
        createdAtUtc: now,
      );
    });
    _onMutationQueued?.call();
  }

  Future<void> renameTaskList(String id, String title) async {
    final now = _now();
    final baseline = await _baselineRow(id);
    if (baseline?.davCollectionId != null) {
      await _requiredDavMutationClient().renameTaskList(
        baseline!.davCollectionId!,
        title,
      );
      return;
    }
    await _updateLocalList(
      id,
      TaskListsCompanion(
        title: Value(title),
        localDirty: const Value(true),
        updatedLocalAtUtc: Value(now),
      ),
    );
    await _enqueue(
      operation: 'patch_task_list',
      taskListId: id,
      request: {'title': title},
      baselineUpdatedUtc: baseline?.updatedUtc,
      baselineRawJson: baseline?.rawJson,
      createdAtUtc: now,
    );
    _onMutationQueued?.call();
  }

  Future<void> updateTaskListFull(String id, TaskListPut replacement) async {
    final now = _now();
    final baseline = await _baselineRow(id);
    final title = replacement.fields['title']?.toString();
    if (baseline?.davCollectionId != null) {
      if (title == null) {
        throw ArgumentError(
          'A complete DAV task-list update must include its title.',
        );
      }
      await _requiredDavMutationClient().renameTaskList(
        baseline!.davCollectionId!,
        title,
      );
      return;
    }
    if (title != null) {
      await _updateLocalList(
        id,
        TaskListsCompanion(
          title: Value(title),
          localDirty: const Value(true),
          updatedLocalAtUtc: Value(now),
        ),
      );
    }
    await _enqueue(
      operation: 'update_task_list',
      taskListId: id,
      request: replacement.toJson(),
      baselineUpdatedUtc: baseline?.updatedUtc,
      baselineRawJson: baseline?.rawJson,
      createdAtUtc: now,
    );
    _onMutationQueued?.call();
  }

  Future<void> deleteTaskList(String id) async {
    final now = _now();
    final baseline = await _baselineRow(id);
    if (baseline?.davCollectionId != null) {
      await _requiredDavMutationClient().deleteTaskList(
        baseline!.davCollectionId!,
      );
      return;
    }
    await _updateLocalList(
      id,
      TaskListsCompanion(
        pendingDelete: const Value(true),
        localDirty: const Value(true),
        updatedLocalAtUtc: Value(now),
      ),
    );
    await _enqueue(
      operation: 'delete_task_list',
      taskListId: id,
      request: const {},
      baselineUpdatedUtc: baseline?.updatedUtc,
      baselineRawJson: baseline?.rawJson,
      createdAtUtc: now,
    );
    _onMutationQueued?.call();
  }

  Future<void> refreshTaskList(String id) async {
    final apiClient = _apiClient;
    if (apiClient == null) {
      return;
    }

    final dto = await apiClient.getTaskList(id);
    await _database.taskListsDao.upsertTaskList(
      taskListFromDto(_accountId, dto, _now()),
    );
  }

  Future<void> setRemindersEnabled(String id, bool enabled) async {
    final updated =
        await (_database.update(_database.taskLists)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.id.equals(id) &
                  row.pendingDelete.equals(false) &
                  row.serverMissing.equals(false),
            ))
            .write(TaskListsCompanion(remindersEnabled: Value(enabled)));
    if (updated != 1) {
      throw StateError('The task list is no longer available.');
    }
    await NotificationScheduleService(
      database: _database,
      nowUtc: _nowUtc,
    ).rebuildUpcomingTaskNotifications(_accountId);
    await _onNotificationScheduleChanged?.call();
  }

  Future<void> _updateLocalList(String id, TaskListsCompanion companion) {
    final update = _database.update(_database.taskLists)
      ..where((row) => row.accountId.equals(_accountId) & row.id.equals(id));
    return update.write(companion);
  }

  Future<void> _enqueue({
    required String operation,
    required Map<String, Object?> request,
    required String createdAtUtc,
    String? taskListId,
    String? localTempId,
    String? baselineUpdatedUtc,
    String? baselineRawJson,
  }) {
    return _database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: _uuid.v4(),
        accountId: _accountId,
        entityType: 'task_list',
        operation: operation,
        taskListId: Value(taskListId),
        localTempId: Value(localTempId),
        requestJson: jsonEncode(request),
        baselineUpdatedUtc: Value(baselineUpdatedUtc),
        baselineRawJson: Value(baselineRawJson),
        createdAtUtc: createdAtUtc,
        updatedAtUtc: createdAtUtc,
      ),
    );
  }

  Future<TaskList?> _baselineRow(String id) {
    return (_database.select(
          _database.taskLists,
        )..where((row) => row.accountId.equals(_accountId) & row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<TaskListCreationMode> _taskListCreationMode() async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).getSingleOrNull();
    if (account == null) return TaskListCreationMode.unavailable;
    final entity = AccountEntity.fromRow(account);
    if (!entity.tasksEnabled || !entity.isSignedIn) {
      return TaskListCreationMode.unavailable;
    }
    return accountCollectionCreationModes(entity.provider).taskListMode;
  }

  DavTaskListMutationClient _requiredDavMutationClient() {
    final client = _davMutationClient;
    if (client == null) {
      throw StateError('The Nextcloud task-list mutation client is missing.');
    }
    return client;
  }

  String _now() => _nowUtc().toIso8601String();
}

TaskListsCompanion taskListFromDto(
  String accountId,
  TaskListDto dto,
  String nowUtc,
) {
  return TaskListsCompanion.insert(
    accountId: accountId,
    id: dto.id,
    kind: Value(dto.kind),
    etag: Value(dto.etag),
    title: dto.title,
    updatedUtc: Value(dto.updated?.toIso8601String()),
    selfLink: Value(dto.selfLink),
    rawJson: jsonEncode(dto.rawJson),
    providerListKind: Value(_stringOrNull(dto.rawJson['wellknownListName'])),
    isOwner: Value(_boolOrNull(dto.rawJson['isOwner'])),
    isShared: Value(_boolOrNull(dto.rawJson['isShared'])),
    providerMetadataJson: Value(_providerMetadataJson(dto.rawJson)),
    serverMissing: const Value(false),
    localDirty: const Value(false),
    pendingDelete: const Value(false),
    lastSyncedAtUtc: Value(nowUtc),
    createdLocalAtUtc: nowUtc,
    updatedLocalAtUtc: nowUtc,
  );
}

String? _stringOrNull(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

bool? _boolOrNull(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value == null) {
    return null;
  }
  return value.toString() == 'true';
}

String? _providerMetadataJson(Map<String, Object?> rawJson) {
  final metadata = <String, Object?>{
    if (rawJson.containsKey('wellknownListName'))
      'wellknownListName': rawJson['wellknownListName'],
    if (rawJson.containsKey('isOwner')) 'isOwner': rawJson['isOwner'],
    if (rawJson.containsKey('isShared')) 'isShared': rawJson['isShared'],
    if (rawJson.containsKey('@removed')) '@removed': rawJson['@removed'],
  };
  return metadata.isEmpty ? null : jsonEncode(metadata);
}
