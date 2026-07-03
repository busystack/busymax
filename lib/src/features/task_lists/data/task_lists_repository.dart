import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../db/app_database.dart';
import '../../../google_tasks/api/google_tasks_api_client.dart';
import '../../../google_tasks/api/google_tasks_api_models.dart';

class TaskListEntity {
  const TaskListEntity({
    required this.accountId,
    required this.id,
    required this.title,
    required this.localDirty,
    required this.pendingDelete,
    required this.rawJson,
    this.updatedUtc,
    this.etag,
    this.providerListKind,
    this.isOwner,
    this.isShared,
  });

  factory TaskListEntity.fromRow(TaskList row) {
    return TaskListEntity(
      accountId: row.accountId,
      id: row.id,
      title: row.title,
      localDirty: row.localDirty,
      pendingDelete: row.pendingDelete,
      rawJson: row.rawJson,
      updatedUtc: row.updatedUtc,
      etag: row.etag,
      providerListKind: row.providerListKind,
      isOwner: row.isOwner,
      isShared: row.isShared,
    );
  }

  final String accountId;
  final String id;
  final String title;
  final bool localDirty;
  final bool pendingDelete;
  final String rawJson;
  final String? updatedUtc;
  final String? etag;
  final String? providerListKind;
  final bool? isOwner;
  final bool? isShared;

  bool get isMicrosoftBuiltIn =>
      providerListKind == 'defaultList' || providerListKind == 'flaggedEmails';

  bool get canRenameOrDeleteForMicrosoft =>
      !isMicrosoftBuiltIn && isOwner != false;
}

class TaskListsRepository {
  TaskListsRepository({
    required AppDatabase database,
    required String accountId,
    GoogleTasksApiClient? apiClient,
    void Function()? onMutationQueued,
    Uuid uuid = const Uuid(),
    DateTime Function()? nowUtc,
  }) : _database = database,
       _accountId = accountId,
       _apiClient = apiClient,
       _onMutationQueued = onMutationQueued,
       _uuid = uuid,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final String _accountId;
  final GoogleTasksApiClient? _apiClient;
  final void Function()? _onMutationQueued;
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
    final now = _now();
    final localId = 'local-tasklist-${_uuid.v4()}';
    await _database.transaction(() async {
      await _database.taskListsDao.upsertTaskList(
        TaskListsCompanion.insert(
          accountId: _accountId,
          id: localId,
          title: title,
          rawJson: jsonEncode({'id': localId, 'title': title}),
          localDirty: const Value(true),
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
      await _enqueue(
        operation: 'create_task_list',
        taskListId: localId,
        localTempId: localId,
        request: {'title': title},
        createdAtUtc: now,
      );
    });
    _onMutationQueued?.call();
  }

  Future<void> renameTaskList(String id, String title) async {
    final now = _now();
    final baseline = await _baselineRow(id);
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
