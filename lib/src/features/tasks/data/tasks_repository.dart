import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../dav/ical/ical_document.dart';
import '../../../dav/ical/ical_semantics.dart';
import '../../../dav/mutation/dav_conditional_mutation_service.dart';
import '../../../dav/mutation/dav_mutation_patch.dart';
import '../../../dav/mutation/dav_pending_operations.dart';
import '../../../dav/mutation/dav_projection_mutations.dart';
import '../../../dav/storage/dav_object_repository.dart';
import '../../../db/app_database.dart';
import '../../../google_tasks/api/google_tasks_json.dart';
import '../domain/task_checklist_item.dart';
import '../domain/task_remote_client.dart';
import '../domain/task_remote_models.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import '../../notifications/notification_schedule_service.dart';

class TaskTreeNode {
  const TaskTreeNode({required this.task, required this.children});

  final TaskEntity task;
  final List<TaskTreeNode> children;
}

enum TaskSubtaskKind { task, checklistItem }

class TaskSubtaskEntity {
  const TaskSubtaskEntity._({
    required this.kind,
    required this.id,
    required this.title,
    required this.completed,
    required this.hasChildren,
    this.task,
    this.checklistItem,
  });

  factory TaskSubtaskEntity.task(TaskEntity task, {required bool hasChildren}) {
    return TaskSubtaskEntity._(
      kind: TaskSubtaskKind.task,
      id: task.id,
      title: task.title,
      completed: task.status == 'completed',
      hasChildren: hasChildren,
      task: task,
    );
  }

  factory TaskSubtaskEntity.checklistItem(TaskChecklistItemEntity item) {
    return TaskSubtaskEntity._(
      kind: TaskSubtaskKind.checklistItem,
      id: item.id,
      title: item.title,
      completed: item.completed,
      hasChildren: false,
      checklistItem: item,
    );
  }

  final TaskSubtaskKind kind;
  final String id;
  final String title;
  final bool completed;
  final bool hasChildren;
  final TaskEntity? task;
  final TaskChecklistItemEntity? checklistItem;
}

class TaskHierarchySnapshot {
  const TaskHierarchySnapshot({required this.parent, required this.subtasks});

  final TaskEntity? parent;
  final List<TaskSubtaskEntity> subtasks;
}

class TaskTreeGroup {
  const TaskTreeGroup({
    required this.accountId,
    required this.accountLabel,
    required this.provider,
    required this.taskListId,
    required this.taskListTitle,
    required this.nodes,
  });

  final String accountId;
  final String accountLabel;
  final BusyProvider provider;
  final String taskListId;
  final String taskListTitle;
  final List<TaskTreeNode> nodes;
}

class TaskEntity {
  const TaskEntity({
    required this.accountId,
    required this.taskListId,
    required this.id,
    required this.title,
    required this.localDirty,
    required this.pendingDelete,
    required this.pendingMove,
    required this.rawJson,
    required this.updatedLocalAtUtc,
    this.davCollectionId,
    this.davObjectId,
    this.icalUid,
    this.recurrenceIdKey,
    this.icalPriority,
    this.percentComplete,
    this.taskLocation,
    this.taskUrl,
    this.taskClassification,
    this.taskPinned,
    this.taskHideSubtasks,
    this.taskHideCompletedSubtasks,
    this.taskAlarmsJson,
    this.parentUid,
    this.sortOrder,
    this.etag,
    this.updatedUtc,
    this.selfLink,
    this.parent,
    this.position,
    this.notes,
    this.status,
    this.dueUtc,
    this.completedUtc,
    this.providerStatus,
    this.bodyContent,
    this.bodyContentType,
    this.microsoftDueDateTime,
    this.microsoftDueTimeZone,
    this.microsoftStartDateTime,
    this.microsoftStartTimeZone,
    this.microsoftReminderDateTime,
    this.microsoftReminderTimeZone,
    this.microsoftIsReminderOn,
    this.microsoftCompletedDateTime,
    this.microsoftCompletedTimeZone,
    this.microsoftChecklistItems = const [],
    this.recurrenceJson,
    this.importance,
    this.categoriesJson,
    this.hasAttachments,
    this.providerMetadataJson,
    this.deleted,
    this.hidden,
    this.linksJson,
    this.webViewLink,
    this.assignmentInfoJson,
  });

  factory TaskEntity.fromRow(Task row) {
    final native = _davNativeTaskFields(row.providerMetadataJson);
    return TaskEntity(
      accountId: row.accountId,
      taskListId: row.taskListId,
      id: row.id,
      title: row.title,
      localDirty: row.localDirty,
      pendingDelete: row.pendingDelete,
      pendingMove: row.pendingMove,
      rawJson: row.rawJson,
      updatedLocalAtUtc: row.updatedLocalAtUtc,
      davCollectionId: row.davCollectionId,
      davObjectId: row.davObjectId,
      icalUid: row.icalUid,
      recurrenceIdKey: row.recurrenceIdKey,
      icalPriority: row.icalPriority,
      percentComplete: row.percentComplete,
      taskLocation: row.taskLocation,
      taskUrl: row.taskUrl,
      taskClassification: row.taskClassification,
      taskPinned: row.taskPinned,
      taskHideSubtasks: row.taskHideSubtasks,
      taskHideCompletedSubtasks: row.taskHideCompletedSubtasks,
      taskAlarmsJson: row.taskAlarmsJson,
      parentUid: row.parentUid,
      sortOrder: row.sortOrder,
      etag: row.etag,
      updatedUtc: row.updatedUtc,
      selfLink: row.selfLink,
      parent: row.parent,
      position: row.position,
      notes: row.notes,
      status: row.status,
      dueUtc: row.dueUtc,
      completedUtc: row.completedUtc,
      providerStatus: row.providerStatus,
      bodyContent: row.bodyContent,
      bodyContentType: row.bodyContentType,
      microsoftDueDateTime: row.microsoftDueDateTime ?? native.dueDateTime,
      microsoftDueTimeZone: row.microsoftDueTimeZone ?? native.dueTimeZone,
      microsoftStartDateTime:
          row.microsoftStartDateTime ?? native.startDateTime,
      microsoftStartTimeZone:
          row.microsoftStartTimeZone ?? native.startTimeZone,
      microsoftReminderDateTime: row.microsoftReminderDateTime,
      microsoftReminderTimeZone: row.microsoftReminderTimeZone,
      microsoftIsReminderOn: row.microsoftIsReminderOn,
      microsoftCompletedDateTime: row.microsoftCompletedDateTime,
      microsoftCompletedTimeZone: row.microsoftCompletedTimeZone,
      microsoftChecklistItems: decodeTaskChecklistItems(
        row.microsoftChecklistItemsJson,
      ),
      recurrenceJson: row.recurrenceJson,
      importance: row.importance,
      categoriesJson: row.categoriesJson,
      hasAttachments: row.hasAttachments,
      providerMetadataJson: row.providerMetadataJson,
      deleted: row.deleted,
      hidden: row.hidden,
      linksJson: row.linksJson,
      webViewLink: row.webViewLink,
      assignmentInfoJson: row.assignmentInfoJson,
    );
  }

  final String accountId;
  final String taskListId;
  final String id;
  final String title;
  final bool localDirty;
  final bool pendingDelete;
  final bool pendingMove;
  final String rawJson;
  final String updatedLocalAtUtc;
  final String? davCollectionId;
  final String? davObjectId;
  final String? icalUid;
  final String? recurrenceIdKey;
  final int? icalPriority;
  final int? percentComplete;
  final String? taskLocation;
  final String? taskUrl;
  final String? taskClassification;
  final bool? taskPinned;
  final bool? taskHideSubtasks;
  final bool? taskHideCompletedSubtasks;
  final String? taskAlarmsJson;
  final String? parentUid;
  final int? sortOrder;
  final String? etag;
  final String? updatedUtc;
  final String? selfLink;
  final String? parent;
  final String? position;
  final String? notes;
  final String? status;
  final String? dueUtc;
  final String? completedUtc;
  final String? providerStatus;
  final String? bodyContent;
  final String? bodyContentType;
  final String? microsoftDueDateTime;
  final String? microsoftDueTimeZone;
  final String? microsoftStartDateTime;
  final String? microsoftStartTimeZone;
  final String? microsoftReminderDateTime;
  final String? microsoftReminderTimeZone;
  final bool? microsoftIsReminderOn;
  final String? microsoftCompletedDateTime;
  final String? microsoftCompletedTimeZone;
  final List<TaskChecklistItemEntity> microsoftChecklistItems;
  final String? recurrenceJson;
  final String? importance;
  final String? categoriesJson;
  final bool? hasAttachments;
  final String? providerMetadataJson;
  final bool? deleted;
  final bool? hidden;
  final String? linksJson;
  final String? webViewLink;
  final String? assignmentInfoJson;
}

class TaskCreateInput {
  const TaskCreateInput({
    required this.title,
    this.notes,
    this.status,
    this.dueUtc,
    this.categories = const [],
    this.fields = const {},
    this.parentTaskId,
    this.previousSiblingTaskId,
  });

  final String title;
  final String? notes;
  final String? status;
  final DateTime? dueUtc;
  final List<String> categories;
  final Map<String, Object?> fields;
  final String? parentTaskId;
  final String? previousSiblingTaskId;

  Map<String, Object?> toFields() {
    final trimmedCategories = [
      for (final category in categories)
        if (category.trim().isNotEmpty) category.trim(),
    ];
    return {
      'title': title,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (dueUtc != null) 'due': dueUtc,
      if (trimmedCategories.isNotEmpty) 'categories': trimmedCategories,
      ...fields,
    };
  }
}

class TaskPatchInput {
  const TaskPatchInput(this.fields);

  final Map<String, Object?> fields;
}

class TaskPutInput {
  const TaskPutInput(this.fields);

  final Map<String, Object?> fields;
}

class TaskMoveInput {
  const TaskMoveInput({
    required this.sourceTaskListId,
    required this.taskId,
    this.parentTaskId,
    this.previousSiblingTaskId,
    this.destinationTaskListId,
  });

  final String sourceTaskListId;
  final String taskId;
  final String? parentTaskId;
  final String? previousSiblingTaskId;
  final String? destinationTaskListId;
}

class DavTaskBatchMutationException implements Exception {
  const DavTaskBatchMutationException({
    required this.appliedCount,
    required this.failedCount,
  });

  final int appliedCount;
  final int failedCount;

  @override
  String toString() =>
      'Some completed tasks could not be queued for deletion '
      '($appliedCount queued, $failedCount failed).';
}

class TaskViewFilter {
  const TaskViewFilter({
    this.showCompleted = true,
    this.showDeleted = false,
    this.showHidden = false,
    this.showAssigned = true,
    this.searchQuery = '',
    this.completedMin,
    this.completedMax,
    this.dueMin,
    this.dueMax,
    this.updatedMin,
  });

  final bool showCompleted;
  final bool showDeleted;
  final bool showHidden;
  final bool showAssigned;
  final String searchQuery;
  final DateTime? completedMin;
  final DateTime? completedMax;
  final DateTime? dueMin;
  final DateTime? dueMax;
  final DateTime? updatedMin;
}

class TasksRepository {
  TasksRepository({
    required AppDatabase database,
    required String accountId,
    TaskRemoteClient? apiClient,
    void Function()? onMutationQueued,
    Future<void> Function()? onNotificationScheduleChanged,
    Uuid uuid = const Uuid(),
    DateTime Function()? nowUtc,
  }) : _database = database,
       _accountId = accountId,
       _apiClient = apiClient,
       _onMutationQueued = onMutationQueued,
       _onNotificationScheduleChanged = onNotificationScheduleChanged,
       _uuid = uuid,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final String _accountId;
  final TaskRemoteClient? _apiClient;
  final void Function()? _onMutationQueued;
  final Future<void> Function()? _onNotificationScheduleChanged;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  Stream<List<TaskTreeNode>> watchTaskTree(
    String taskListId,
    TaskViewFilter filter,
  ) {
    return _database.tasksDao.watchTaskTree(_accountId, taskListId).map((rows) {
      final visible = rows.where((row) => _matchesFilter(row, filter));
      return _buildTree(visible.map(TaskEntity.fromRow).toList());
    });
  }

  Stream<TaskHierarchySnapshot> watchTaskHierarchy(
    String taskListId,
    String taskId,
  ) {
    return _database.tasksDao.watchTaskTree(_accountId, taskListId).map((rows) {
      final entities = rows
          .where((row) => row.deleted != true && row.hidden != true)
          .map(TaskEntity.fromRow)
          .toList();
      final current = entities.firstWhereOrNull((task) => task.id == taskId);
      if (current == null) {
        return const TaskHierarchySnapshot(parent: null, subtasks: []);
      }
      final parent = entities.firstWhereOrNull(
        (task) =>
            task.id == current.parent ||
            (current.parentUid != null && task.icalUid == current.parentUid),
      );
      final taskChildren =
          entities
              .where(
                (task) =>
                    task.parent == current.id ||
                    (current.icalUid != null &&
                        task.parentUid == current.icalUid),
              )
              .toList()
            ..sort(_compareTaskOrder);
      final taskSubtasks = [
        for (final child in taskChildren)
          TaskSubtaskEntity.task(
            child,
            hasChildren:
                entities.any(
                  (candidate) =>
                      candidate.parent == child.id ||
                      (child.icalUid != null &&
                          candidate.parentUid == child.icalUid),
                ) ||
                child.microsoftChecklistItems.isNotEmpty,
          ),
      ];
      final checklistSubtasks = [
        for (final item in current.microsoftChecklistItems)
          TaskSubtaskEntity.checklistItem(item),
      ];
      return TaskHierarchySnapshot(
        parent: parent,
        subtasks: [...taskSubtasks, ...checklistSubtasks],
      );
    });
  }

  Stream<List<TaskTreeGroup>> watchAllTaskTreeGroups(
    List<String> accountIds,
    TaskViewFilter filter,
  ) {
    if (accountIds.isEmpty) {
      return Stream.value(const []);
    }

    return _database.tasksDao.watchAllTaskTrees(accountIds).map((rows) {
      final visibleRows = rows.where(
        (row) => _matchesFilter(row.task, filter, taskList: row.taskList),
      );
      final byList = groupBy(
        visibleRows,
        (row) => '${row.task.accountId}\u0000${row.task.taskListId}',
      );

      return [
        for (final rows in byList.values)
          if (rows.isNotEmpty)
            TaskTreeGroup(
              accountId: rows.first.account.id,
              accountLabel: _accountLabel(rows.first.account),
              provider: BusyProviderCodec.requireStorageValue(
                rows.first.account.provider,
              ),
              taskListId: rows.first.taskList.id,
              taskListTitle: rows.first.taskList.title,
              nodes: _buildTree(
                rows.map((row) => TaskEntity.fromRow(row.task)).toList(),
              ),
            ),
      ];
    });
  }

  Stream<TaskEntity?> watchTask(String taskListId, String taskId) {
    final query = _database.select(_database.tasks)
      ..where(
        (row) =>
            row.accountId.equals(_accountId) &
            row.taskListId.equals(taskListId) &
            row.id.equals(taskId) &
            row.pendingDelete.equals(false) &
            row.serverMissing.equals(false),
      );
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : TaskEntity.fromRow(row),
    );
  }

  Stream<List<String>> watchCategorySuggestions() {
    final query = _database.select(_database.tasks)
      ..where(
        (row) =>
            row.accountId.equals(_accountId) &
            row.pendingDelete.equals(false) &
            row.serverMissing.equals(false) &
            row.categoriesJson.isNotNull(),
      );
    return query.watch().map((rows) {
      final categories = <String>{};
      for (final row in rows) {
        categories.addAll(_stringListFromJson(row.categoriesJson));
      }
      return categories.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  Future<void> createTask(String taskListId, TaskCreateInput input) async {
    final taskList = await _requiredTaskList(taskListId);
    if (taskList.davCollectionId != null) {
      return _createDavTask(taskList, input);
    }
    final now = _now();
    final localId = 'local-task-${_uuid.v4()}';
    final fields = input.toFields();
    final title = fields['title']?.toString() ?? input.title;
    await _database.transaction(() async {
      await _database.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: _accountId,
          taskListId: taskListId,
          id: localId,
          title: title,
          status: Value(fields['status']?.toString() ?? 'needsAction'),
          parent: Value(input.parentTaskId),
          rawJson: jsonEncode({'id': localId, 'title': title}),
          localDirty: const Value(true),
          localCreated: const Value(true),
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
      await _patchLocalTask(taskListId, localId, fields, now);
      final createOperationId = await _enqueue(
        operation: 'create_task',
        taskListId: taskListId,
        taskId: localId,
        localTempId: localId,
        request: {
          'body': _remoteTaskFields(fields),
          if (input.parentTaskId != null) 'parent': input.parentTaskId,
          if (input.previousSiblingTaskId != null)
            'previous': input.previousSiblingTaskId,
        },
        createdAtUtc: now,
      );
      if (input.parentTaskId != null) {
        final moveCreatedAt = DateTime.parse(
          now,
        ).add(const Duration(milliseconds: 1)).toIso8601String();
        await _enqueue(
          operation: 'move_task',
          taskListId: taskListId,
          taskId: localId,
          request: {
            'parent': input.parentTaskId,
            if (input.previousSiblingTaskId != null)
              'previous': input.previousSiblingTaskId,
          },
          createdAtUtc: moveCreatedAt,
          dependsOnOpId: createOperationId,
        );
      }
    });
    await _rebuildTaskNotifications();
    _onMutationQueued?.call();
  }

  Future<void> createSubtask({
    required String taskListId,
    required String parentTaskId,
    required String title,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title');
    }
    if (_apiClient is TaskChecklistRemoteClient) {
      await _createChecklistSubtask(
        taskListId: taskListId,
        parentTaskId: parentTaskId,
        title: normalizedTitle,
      );
      return;
    }
    await createTask(
      taskListId,
      TaskCreateInput(title: normalizedTitle, parentTaskId: parentTaskId),
    );
  }

  Future<void> patchChecklistSubtask({
    required String taskListId,
    required String parentTaskId,
    required String checklistItemId,
    String? title,
    bool? completed,
  }) async {
    if (_apiClient is! TaskChecklistRemoteClient) {
      throw UnsupportedError('This provider does not use checklist subtasks.');
    }
    final normalizedTitle = title?.trim();
    if (normalizedTitle != null && normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title');
    }
    if (normalizedTitle == null && completed == null) return;

    final task = await _requiredTask(taskListId, parentTaskId);
    final items = List<TaskChecklistItemEntity>.of(
      decodeTaskChecklistItems(task.microsoftChecklistItemsJson),
    );
    final index = items.indexWhere((item) => item.id == checklistItemId);
    if (index < 0) {
      throw StateError('The checklist subtask is unavailable.');
    }
    final now = _now();
    final raw = items[index].toJson();
    if (normalizedTitle != null) raw['displayName'] = normalizedTitle;
    if (completed != null) {
      raw['isChecked'] = completed;
      if (completed) {
        raw['checkedDateTime'] = now;
      } else {
        raw.remove('checkedDateTime');
      }
    }
    items[index] = TaskChecklistItemEntity.fromJson(raw);
    final body = <String, Object?>{
      if (normalizedTitle != null) 'displayName': normalizedTitle,
      if (completed != null) 'isChecked': completed,
    };
    await _database.transaction(() async {
      await _writeChecklistProjection(taskListId, parentTaskId, items, now);
      await _enqueueChecklistOperation(
        operation: 'patch_task_checklist_item',
        taskListId: taskListId,
        parentTaskId: parentTaskId,
        checklistItemId: checklistItemId,
        request: {'checklistItemId': checklistItemId, 'body': body},
        createdAtUtc: now,
      );
    });
    _onMutationQueued?.call();
  }

  Future<void> deleteChecklistSubtask({
    required String taskListId,
    required String parentTaskId,
    required String checklistItemId,
  }) async {
    if (_apiClient is! TaskChecklistRemoteClient) {
      throw UnsupportedError('This provider does not use checklist subtasks.');
    }
    final task = await _requiredTask(taskListId, parentTaskId);
    final items = decodeTaskChecklistItems(task.microsoftChecklistItemsJson);
    if (!items.any((item) => item.id == checklistItemId)) {
      throw StateError('The checklist subtask is unavailable.');
    }
    final now = _now();
    final pendingCreate = await _pendingChecklistCreate(
      taskListId,
      parentTaskId,
      checklistItemId,
    );
    await _database.transaction(() async {
      await _writeChecklistProjection(taskListId, parentTaskId, [
        for (final item in items)
          if (item.id != checklistItemId) item,
      ], now);
      if (pendingCreate != null) {
        await _deleteChecklistOperationChain(
          parentTaskId: parentTaskId,
          checklistItemId: checklistItemId,
        );
      } else {
        await _enqueueChecklistOperation(
          operation: 'delete_task_checklist_item',
          taskListId: taskListId,
          parentTaskId: parentTaskId,
          checklistItemId: checklistItemId,
          request: {'checklistItemId': checklistItemId},
          createdAtUtc: now,
        );
      }
    });
    _onMutationQueued?.call();
  }

  Future<void> _createChecklistSubtask({
    required String taskListId,
    required String parentTaskId,
    required String title,
  }) async {
    final task = await _requiredTask(taskListId, parentTaskId);
    final items = List<TaskChecklistItemEntity>.of(
      decodeTaskChecklistItems(task.microsoftChecklistItemsJson),
    );
    final now = _now();
    final localId = 'local-checklist-${_uuid.v4()}';
    items.add(
      TaskChecklistItemEntity.fromJson({
        'id': localId,
        'displayName': title,
        'isChecked': false,
        'createdDateTime': now,
      }),
    );
    await _database.transaction(() async {
      await _writeChecklistProjection(taskListId, parentTaskId, items, now);
      await _enqueueChecklistOperation(
        operation: 'create_task_checklist_item',
        taskListId: taskListId,
        parentTaskId: parentTaskId,
        checklistItemId: localId,
        localTempId: localId,
        request: {
          'checklistItemId': localId,
          'body': {'displayName': title, 'isChecked': false},
        },
        createdAtUtc: now,
      );
    });
    _onMutationQueued?.call();
  }

  Future<void> patchTask(
    String taskListId,
    String taskId,
    TaskPatchInput input,
  ) async {
    final taskList = await _requiredTaskList(taskListId);
    if (taskList.davCollectionId != null) {
      return _updateDavTaskWithHierarchy(taskList, taskId, input.fields);
    }
    final now = _now();
    await _database.transaction(() async {
      final baseline = await _baselineRow(taskListId, taskId);
      await _patchLocalTask(taskListId, taskId, input.fields, now);
      await _enqueue(
        operation: 'patch_task',
        taskListId: taskListId,
        taskId: taskId,
        request: _remoteTaskFields(input.fields),
        baselineUpdatedUtc: baseline?.updatedUtc,
        baselineRawJson: baseline?.rawJson,
        createdAtUtc: now,
      );
    });
    await _rebuildTaskNotifications();
    _onMutationQueued?.call();
  }

  Future<void> updateTaskFull(
    String taskListId,
    String taskId,
    TaskPutInput input,
  ) async {
    final taskList = await _requiredTaskList(taskListId);
    if (taskList.davCollectionId != null) {
      return _updateDavTaskWithHierarchy(taskList, taskId, input.fields);
    }
    final now = _now();
    await _database.transaction(() async {
      final baseline = await _baselineRow(taskListId, taskId);
      await _patchLocalTask(taskListId, taskId, input.fields, now);
      await _enqueue(
        operation: 'update_task',
        taskListId: taskListId,
        taskId: taskId,
        request: _remoteTaskFields(input.fields),
        baselineUpdatedUtc: baseline?.updatedUtc,
        baselineRawJson: baseline?.rawJson,
        createdAtUtc: now,
      );
    });
    await _rebuildTaskNotifications();
    _onMutationQueued?.call();
  }

  Future<void> deleteTask(String taskListId, String taskId) async {
    final taskList = await _requiredTaskList(taskListId);
    if (taskList.davCollectionId != null) {
      await _deleteDavTask(taskList, taskId);
      await _rebuildTaskNotifications();
      _onMutationQueued?.call();
      return;
    }
    final now = _now();
    final baseline = await _baselineRow(taskListId, taskId);
    await _writeLocalTask(
      taskListId,
      taskId,
      TasksCompanion(
        pendingDelete: const Value(true),
        localDirty: const Value(true),
        updatedLocalAtUtc: Value(now),
      ),
    );
    await _enqueue(
      operation: 'delete_task',
      taskListId: taskListId,
      taskId: taskId,
      request: const {},
      baselineUpdatedUtc: baseline?.updatedUtc,
      baselineRawJson: baseline?.rawJson,
      createdAtUtc: now,
    );
    await _rebuildTaskNotifications();
    _onMutationQueued?.call();
  }

  Future<void> moveTask(TaskMoveInput input) async {
    final taskList = await _requiredTaskList(input.sourceTaskListId);
    if (taskList.davCollectionId != null) {
      await _moveDavTask(taskList, input);
      await _rebuildTaskNotifications();
      _onMutationQueued?.call();
      return;
    }
    final now = _now();
    final baseline = await _baselineRow(input.sourceTaskListId, input.taskId);
    await _writeLocalTask(
      input.sourceTaskListId,
      input.taskId,
      TasksCompanion(
        taskListId: Value(
          input.destinationTaskListId ?? input.sourceTaskListId,
        ),
        parent: Value(input.parentTaskId),
        pendingMove: const Value(true),
        localDirty: const Value(true),
        updatedLocalAtUtc: Value(now),
      ),
    );
    await _enqueue(
      operation: 'move_task',
      taskListId: input.sourceTaskListId,
      taskId: input.taskId,
      request: {
        if (input.parentTaskId != null) 'parent': input.parentTaskId,
        if (input.previousSiblingTaskId != null)
          'previous': input.previousSiblingTaskId,
        if (input.destinationTaskListId != null)
          'destinationTasklist': input.destinationTaskListId,
      },
      baselineUpdatedUtc: baseline?.updatedUtc,
      baselineRawJson: baseline?.rawJson,
      createdAtUtc: now,
    );
    _onMutationQueued?.call();
  }

  Future<void> clearCompleted(String taskListId) async {
    final taskList = await _requiredTaskList(taskListId);
    if (taskList.davCollectionId != null) {
      return _clearCompletedDavTasks(taskList);
    }
    final now = _now();
    final baselineUpdatedUtc = await _completedTasksBaselineUpdatedUtc(
      taskListId,
    );
    await _enqueue(
      operation: 'clear_completed_tasks',
      taskListId: taskListId,
      request: const {},
      baselineUpdatedUtc: baselineUpdatedUtc,
      createdAtUtc: now,
    );
    _onMutationQueued?.call();
  }

  Future<String> duplicateTask(String taskListId, String taskId) async {
    final taskList = await _requiredTaskList(taskListId);
    if (taskList.davCollectionId == null) {
      throw UnsupportedError(
        'Native task duplication is only available for DAV task lists.',
      );
    }
    final source = await _requiredTask(taskList.id, taskId);
    if (source.recurrenceIdKey != null) {
      throw UnsupportedError(
        'An individual recurring DAV task occurrence cannot be duplicated.',
      );
    }
    final existingParent = await _davParentTask(taskList.id, source);
    final result = await _duplicateDavTaskNode(
      taskList,
      source,
      parentId: existingParent?.id,
      parentUid: existingParent?.icalUid,
      dependsOnOperationId: null,
    );
    await _rebuildTaskNotifications();
    _onMutationQueued?.call();
    return result.localId;
  }

  Future<String?> nativeTaskExport(String taskListId, String taskId) async {
    final taskList = await _requiredTaskList(taskListId);
    if (taskList.davCollectionId == null) return null;
    final task = await _requiredTask(taskList.id, taskId);
    final objectId = task.davObjectId;
    if (objectId == null) {
      final create = await _pendingDavCreateForProjection(task.id);
      return create == null ? null : _pendingDavCreateRawIcs(create);
    }
    return DavPendingOperationQueue(
      database: _database,
      idFactory: _uuid.v4,
      nowUtc: _nowUtc,
    ).editableRawIcsForObject(
      accountId: _accountId,
      collectionId: taskList.davCollectionId!,
      objectId: objectId,
    );
  }

  Future<void> _createDavTask(TaskList taskList, TaskCreateInput input) async {
    final collectionId = taskList.davCollectionId!;
    final fields = Map<String, Object?>.from(input.toFields());
    await _ensureDavCreateAllowed(taskList, fields);
    final parent = await _davParent(
      taskList.id,
      input.parentTaskId,
      childTaskId: null,
    );
    if (parent != null &&
        !_requestsDavTaskCompletion(fields) &&
        _davTaskCompleted(parent)) {
      await _updateDavTaskHierarchyNode(taskList, parent.id, const {
        'percentComplete': 0,
      }, visited: <String>{});
    }
    final object = buildDavTaskObject(
      fields,
      parentUid: parent?.icalUid,
      idFactory: _uuid.v4,
      nowUtc: _nowUtc,
    );
    final sortOrder = nextcloudTaskSortOrder(
      IcalSemanticDocument.parse(object.rawIcs).components.single,
    );
    final now = _now();
    final localId = 'dav-local-task-${_uuid.v4()}';
    final metadata = jsonEncode({
      'transport': 'caldav',
      'uid': object.uid,
      'localPendingCreate': true,
    });
    await _database.transaction(() async {
      await _database.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: _accountId,
          taskListId: taskList.id,
          id: localId,
          davCollectionId: Value(collectionId),
          icalUid: Value(object.uid),
          parentUid: Value(parent?.icalUid),
          sortOrder: Value(sortOrder),
          title: input.title.trim(),
          status: Value(fields['status']?.toString() ?? 'needsAction'),
          parent: Value(parent?.id),
          position: Value('$sortOrder'),
          providerMetadataJson: Value(metadata),
          rawJson: metadata,
          localDirty: const Value(true),
          localCreated: const Value(true),
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
      await _patchLocalTask(taskList.id, localId, fields, now);
      await DavPendingOperationQueue(
        database: _database,
        idFactory: _uuid.v4,
        nowUtc: _nowUtc,
      ).enqueueCreate(
        accountId: _accountId,
        collectionId: collectionId,
        object: object,
        localProjectionId: localId,
      );
    });
    await _rebuildTaskNotifications();
    _onMutationQueued?.call();
  }

  Future<({String localId, String uid, String lastOperationId})>
  _duplicateDavTaskNode(
    TaskList taskList,
    Task source, {
    required String? parentId,
    required String? parentUid,
    required String? dependsOnOperationId,
  }) async {
    await _ensureDavTaskMutable(taskList, source);
    final collectionId = taskList.davCollectionId!;
    final sourceUid = source.icalUid;
    if (sourceUid == null || sourceUid.isEmpty) {
      throw StateError('The DAV task UID is unavailable.');
    }
    final queue = DavPendingOperationQueue(
      database: _database,
      idFactory: _uuid.v4,
      nowUtc: _nowUtc,
    );
    final sourceRaw = source.davObjectId == null
        ? _pendingDavCreateRawIcs(
            await _pendingDavCreateForProjection(source.id) ??
                (throw StateError('The pending DAV task is unavailable.')),
          )
        : await queue.editableRawIcsForObject(
            accountId: _accountId,
            collectionId: collectionId,
            objectId: source.davObjectId!,
          );
    final newUid = _uuid.v4();
    final duplicatedRaw = _duplicateDavTaskResource(
      sourceRaw,
      sourceUid: sourceUid,
      newUid: newUid,
      parentUid: parentUid,
      nowUtc: _nowUtc(),
    );
    final duplicatedMaster = IcalSemanticDocument.parse(
      duplicatedRaw,
    ).components.singleWhere((component) => component.recurrenceIdKey == null);
    final sortOrder = nextcloudTaskSortOrder(duplicatedMaster);
    final localId = 'dav-local-task-${_uuid.v4()}';
    final metadata = jsonEncode({
      'transport': 'caldav',
      'uid': newUid,
      'localPendingCreate': true,
      'duplicatedFromUid': sourceUid,
    });
    final now = _now();
    late final String operationId;
    await _database.transaction(() async {
      await _database.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: _accountId,
          taskListId: taskList.id,
          id: localId,
          davCollectionId: Value(collectionId),
          icalUid: Value(newUid),
          icalPriority: Value(source.icalPriority),
          percentComplete: Value(source.percentComplete),
          taskLocation: Value(source.taskLocation),
          taskUrl: Value(source.taskUrl),
          taskClassification: Value(source.taskClassification),
          taskPinned: Value(source.taskPinned),
          taskHideSubtasks: Value(source.taskHideSubtasks),
          taskHideCompletedSubtasks: Value(source.taskHideCompletedSubtasks),
          taskAlarmsJson: Value(source.taskAlarmsJson),
          parentUid: Value(parentUid),
          sortOrder: Value(sortOrder),
          title: source.title,
          notes: Value(source.notes),
          status: Value(source.status),
          dueUtc: Value(source.dueUtc),
          completedUtc: Value(source.completedUtc),
          providerStatus: Value(source.providerStatus),
          microsoftDueDateTime: Value(source.microsoftDueDateTime),
          microsoftDueTimeZone: Value(source.microsoftDueTimeZone),
          microsoftStartDateTime: Value(source.microsoftStartDateTime),
          microsoftStartTimeZone: Value(source.microsoftStartTimeZone),
          recurrenceJson: Value(source.recurrenceJson),
          importance: Value(source.importance),
          categoriesJson: Value(source.categoriesJson),
          parent: Value(parentId),
          position: Value('$sortOrder'),
          providerMetadataJson: Value(metadata),
          rawJson: metadata,
          localDirty: const Value(true),
          localCreated: const Value(true),
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
      operationId = await queue.enqueueCreate(
        accountId: _accountId,
        collectionId: collectionId,
        object: DavNewObject(
          uid: newUid,
          initialMemberName: '${_uuid.v4()}.ics',
          rawIcs: duplicatedRaw,
          componentType: 'VTODO',
        ),
        localProjectionId: localId,
        dependsOnOperationId: dependsOnOperationId,
      );
    });

    var lastOperationId = operationId;
    for (final child in await _davChildren(taskList.id, source)) {
      final duplicate = await _duplicateDavTaskNode(
        taskList,
        child,
        parentId: localId,
        parentUid: newUid,
        dependsOnOperationId: lastOperationId,
      );
      lastOperationId = duplicate.lastOperationId;
    }
    return (localId: localId, uid: newUid, lastOperationId: lastOperationId);
  }

  Future<void> _updateDavTask(
    TaskList taskList,
    String taskId,
    Map<String, Object?> requestedFields, {
    bool announce = true,
  }) async {
    final task = await _requiredTask(taskList.id, taskId);
    await _ensureDavTaskMutable(
      taskList,
      task,
      changesClassification: requestedFields.containsKey('taskClassification'),
    );
    if (task.recurrenceIdKey != null) {
      throw UnsupportedError(
        'Editing an individual recurring DAV task occurrence is disabled.',
      );
    }
    final collectionId = taskList.davCollectionId!;
    final uid = task.icalUid;
    if (uid == null) throw StateError('The DAV task UID is unavailable.');
    final fields = Map<String, Object?>.from(requestedFields);
    String? parentUid;
    if (fields.containsKey('parentUid')) {
      final parent = await _davParent(
        taskList.id,
        fields['parentUid']?.toString(),
        childTaskId: task.id,
      );
      parentUid = parent?.icalUid;
      fields['parentUid'] = parentUid;
    }
    final target = IcalComponentKey(
      componentType: 'VTODO',
      uid: uid,
      recurrenceIdKey: task.recurrenceIdKey,
    );
    final queue = DavPendingOperationQueue(
      database: _database,
      idFactory: _uuid.v4,
      nowUtc: _nowUtc,
    );
    final objectId = task.davObjectId;
    late final String baselineRawIcs;
    if (objectId == null) {
      final create = await _pendingDavCreateForProjection(task.id);
      if (create == null) {
        throw StateError('The pending DAV task create is unavailable.');
      }
      baselineRawIcs = _pendingDavCreateRawIcs(create);
    } else {
      baselineRawIcs = await queue.editableRawIcsForObject(
        accountId: _accountId,
        collectionId: collectionId,
        objectId: objectId,
      );
    }
    final mutationNow = _nowUtc().toUtc();
    final patch = _buildDavTaskMutationPatch(
      target: target,
      baselineRawIcs: baselineRawIcs,
      fields: fields,
      parentUid: parentUid,
      mutationNowUtc: mutationNow,
    );
    if (patch == null) return;
    final durablePatch = patch.materialize(mutationNow);
    final candidate = durablePatch.applyTo(baselineRawIcs, nowUtc: mutationNow);
    final now = mutationNow.toIso8601String();
    await _database.transaction(() async {
      if (objectId == null) {
        final updated = await queue.updateUnsentCreate(
          accountId: _accountId,
          collectionId: collectionId,
          localProjectionId: task.id,
          patch: durablePatch,
        );
        if (!updated) {
          throw StateError(
            'The pending DAV task create is no longer editable.',
          );
        }
      } else {
        await queue.enqueueUpdate(
          accountId: _accountId,
          collectionId: collectionId,
          objectId: objectId,
          patch: durablePatch,
        );
      }
      if (objectId == null) {
        await _patchLocalTask(taskList.id, task.id, fields, now);
      } else {
        final account = await (_database.select(
          _database.accounts,
        )..where((row) => row.id.equals(_accountId))).getSingle();
        await DavObjectRepository(
          database: _database,
        ).projectLocalMutationCandidate(
          accountId: _accountId,
          collectionId: collectionId,
          provider: BusyProviderCodec.requireStorageValue(account.provider),
          objectId: objectId,
          candidateRawIcs: candidate,
          projectedAtUtc: mutationNow,
        );
      }
    });
    if (announce) {
      await _rebuildTaskNotifications();
      _onMutationQueued?.call();
    }
  }

  Future<void> _updateDavTaskWithHierarchy(
    TaskList taskList,
    String taskId,
    Map<String, Object?> fields,
  ) async {
    await _updateDavTaskHierarchyNode(
      taskList,
      taskId,
      fields,
      visited: <String>{},
    );
    await _rebuildTaskNotifications();
    _onMutationQueued?.call();
  }

  Future<void> _updateDavTaskHierarchyNode(
    TaskList taskList,
    String taskId,
    Map<String, Object?> fields, {
    required Set<String> visited,
  }) async {
    if (!visited.add(taskId)) {
      throw StateError('The DAV task hierarchy contains a cycle.');
    }
    final task = await _requiredTask(taskList.id, taskId);
    try {
      if (fields.containsKey('percentComplete')) {
        final percent = fields['percentComplete'];
        if (percent is! int || percent < 0 || percent > 100) {
          throw ArgumentError.value(percent, 'percentComplete');
        }
        if (percent < 100) {
          final parent = await _davParentTask(taskList.id, task);
          if (parent != null && _davTaskClosed(parent)) {
            await _updateDavTaskHierarchyNode(taskList, parent.id, const {
              'percentComplete': 0,
            }, visited: visited);
          }
        } else {
          for (final child in await _davChildren(taskList.id, task)) {
            if (!_davTaskClosed(child)) {
              await _updateDavTaskHierarchyNode(taskList, child.id, const {
                'percentComplete': 100,
              }, visited: visited);
            }
          }
        }
      } else if (fields.containsKey('taskStatus') ||
          fields.containsKey('status')) {
        final requested = fields.containsKey('taskStatus')
            ? fields['taskStatus']
            : fields['status'];
        final status = _davProviderStatus(requested);
        if (status != 'CANCELLED' && !_davTaskCompleted(task)) {
          final parent = await _davParentTask(taskList.id, task);
          if (parent != null && _davTaskClosed(parent)) {
            await _updateDavTaskHierarchyNode(taskList, parent.id, const {
              'taskStatus': 'IN-PROCESS',
            }, visited: visited);
          }
        } else {
          for (final child in await _davChildren(taskList.id, task)) {
            if (!_davTaskClosed(child)) {
              await _updateDavTaskHierarchyNode(taskList, child.id, const {
                'taskStatus': 'CANCELLED',
              }, visited: visited);
            }
          }
        }
      }
      await _updateDavTask(taskList, task.id, fields, announce: false);
    } finally {
      visited.remove(taskId);
    }
  }

  Future<String?> _deleteDavTask(
    TaskList taskList,
    String taskId, {
    String? dependsOnOperationId,
  }) async {
    final task = await _requiredTask(taskList.id, taskId);
    await _ensureDavTaskMutable(taskList, task);
    if (task.recurrenceIdKey != null) {
      throw UnsupportedError(
        'Deleting an individual recurring DAV task occurrence is disabled.',
      );
    }
    final collectionId = taskList.davCollectionId!;
    final uid = task.icalUid;
    if (uid == null) throw StateError('The DAV task UID is unavailable.');
    final children = await _davChildren(taskList.id, task);
    var dependency = dependsOnOperationId;
    for (final child in children) {
      dependency = await _deleteDavTask(
        taskList,
        child.id,
        dependsOnOperationId: dependency,
      );
    }
    final queue = DavPendingOperationQueue(
      database: _database,
      idFactory: _uuid.v4,
      nowUtc: _nowUtc,
    );
    final objectId = task.davObjectId;
    String? operationId;
    await _database.transaction(() async {
      if (objectId == null) {
        final cancelled = await queue.cancelUnsentCreate(
          accountId: _accountId,
          collectionId: collectionId,
          localProjectionId: task.id,
        );
        if (!cancelled) {
          throw StateError(
            'The DAV task create may already be in progress and cannot be '
            'cancelled locally.',
          );
        }
        await (_database.delete(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(taskList.id) &
                  row.id.equals(task.id),
            ))
            .go();
      } else {
        final object = await (_database.select(
          _database.davObjects,
        )..where((row) => row.id.equals(objectId))).getSingleOrNull();
        if (object == null || object.collectionId != collectionId) {
          throw StateError('The DAV task baseline is unavailable.');
        }
        final semantic = IcalSemanticDocument.parse(object.rawIcsBody);
        final components = semantic.components
            .where(
              (component) =>
                  component.componentType == 'VTODO' && component.uid == uid,
            )
            .toList(growable: false);
        if (components.isEmpty) {
          throw StateError('The DAV task component is unavailable.');
        }
        final targets = [
          for (final component in components)
            IcalComponentKey(
              componentType: component.componentType,
              uid: uid,
              recurrenceIdKey: component.recurrenceIdKey,
            ),
        ];
        final targetDocumentComponents = {
          for (final component in components) component.documentComponent,
        };
        final hasUntargetedCalendarComponent = semantic
            .document
            .calendarComponents
            .any(
              (component) =>
                  component.name != 'VTIMEZONE' &&
                  !targetDocumentComponents.contains(component),
            );
        final scope = components.length > 1
            ? DavMutationScope.recurrenceMaster
            : DavMutationScope.object;
        if (!hasUntargetedCalendarComponent) {
          operationId = await queue.enqueueDelete(
            accountId: _accountId,
            collectionId: collectionId,
            objectId: objectId,
            target: targets.first,
            scope: scope,
            dependsOnOperationId: dependency,
          );
          await (_database.update(
            _database.tasks,
          )..where((row) => row.davObjectId.equals(objectId))).write(
            TasksCompanion(
              pendingDelete: const Value(true),
              localDirty: const Value(true),
              updatedLocalAtUtc: Value(_now()),
            ),
          );
        } else {
          final patch = buildDavComponentRemovalPatch(
            targets: targets,
            scope: scope,
          );
          final candidate = patch.applyTo(object.rawIcsBody, nowUtc: _nowUtc());
          operationId = await queue.enqueueUpdate(
            accountId: _accountId,
            collectionId: collectionId,
            objectId: objectId,
            patch: patch,
            dependsOnOperationId: dependency,
          );
          final account = await (_database.select(
            _database.accounts,
          )..where((row) => row.id.equals(_accountId))).getSingle();
          await DavObjectRepository(
            database: _database,
          ).projectLocalMutationCandidate(
            accountId: _accountId,
            collectionId: collectionId,
            provider: BusyProviderCodec.requireStorageValue(account.provider),
            objectId: objectId,
            candidateRawIcs: candidate,
            projectedAtUtc: _nowUtc(),
          );
        }
      }
    });
    return operationId ?? dependency;
  }

  Future<void> _moveDavTask(TaskList taskList, TaskMoveInput input) async {
    final destination = input.destinationTaskListId;
    final task = await _requiredTask(taskList.id, input.taskId);
    await _ensureDavTaskMutable(taskList, task);
    if (task.recurrenceIdKey != null) {
      throw UnsupportedError(
        'An individual recurring DAV task occurrence cannot be moved.',
      );
    }
    if (destination != null && destination != taskList.id) {
      final destinationList = await _requiredTaskList(destination);
      if (destinationList.davCollectionId == null) {
        throw UnsupportedError(
          'Tasks cannot be moved between DAV and non-DAV task lists.',
        );
      }
      final parent = await _davParent(
        destinationList.id,
        input.parentTaskId,
        childTaskId: null,
      );
      await _ensureDavDestinationAllowsTask(destinationList, task);
      await _moveDavTaskTreeToCollection(
        sourceList: taskList,
        destinationList: destinationList,
        task: task,
        parentId: parent?.id,
        parentUid: parent?.icalUid,
        completeSubtree: parent != null && _davTaskCompleted(parent),
        dependsOnOperationId: null,
      );
      return;
    }
    final parent = await _davParent(
      taskList.id,
      input.parentTaskId,
      childTaskId: task.id,
    );
    final ordering = await _davSortOrderForMove(
      taskList.id,
      parentId: parent?.id,
      previousSiblingTaskId: input.previousSiblingTaskId,
      movingTaskId: task.id,
    );
    for (final adjustment in ordering.adjustments) {
      await _updateDavTask(taskList, adjustment.taskId, {
        'sortOrder': adjustment.sortOrder,
      }, announce: false);
    }
    final sortOrder = ordering.movingSortOrder;
    final fields = <String, Object?>{
      'parentUid': parent?.icalUid,
      'sortOrder': sortOrder,
    };
    await _updateDavTask(taskList, task.id, fields, announce: false);
    if (parent != null &&
        _davTaskCompleted(parent) &&
        !_davTaskCompleted(task)) {
      await _updateDavTaskHierarchyNode(taskList, task.id, const {
        'percentComplete': 100,
      }, visited: <String>{});
    }
    await _writeLocalTask(
      taskList.id,
      task.id,
      TasksCompanion(
        parent: Value(parent?.id),
        parentUid: Value(parent?.icalUid),
        sortOrder: Value(sortOrder),
        position: Value('$sortOrder'),
        pendingMove: const Value(true),
        localDirty: const Value(true),
        updatedLocalAtUtc: Value(_now()),
      ),
    );
  }

  Future<String> _moveDavTaskTreeToCollection({
    required TaskList sourceList,
    required TaskList destinationList,
    required Task task,
    required String? parentId,
    required String? parentUid,
    required bool completeSubtree,
    required String? dependsOnOperationId,
  }) async {
    await _ensureDavTaskMutable(sourceList, task);
    await _ensureDavDestinationAllowsTask(destinationList, task);
    var dependency = dependsOnOperationId;
    final children = await _davChildren(sourceList.id, task);
    for (final child in children) {
      dependency = await _moveDavTaskTreeToCollection(
        sourceList: sourceList,
        destinationList: destinationList,
        task: child,
        parentId: task.id,
        parentUid: task.icalUid,
        completeSubtree: completeSubtree,
        dependsOnOperationId: dependency,
      );
    }

    final queue = DavPendingOperationQueue(
      database: _database,
      idFactory: _uuid.v4,
      nowUtc: _nowUtc,
    );
    final fields = <String, Object?>{
      if (task.parentUid != parentUid) 'parentUid': parentUid,
      if (completeSubtree && !_davTaskCompleted(task)) 'percentComplete': 100,
    };
    final uid = task.icalUid;
    if (uid == null || uid.isEmpty) {
      throw StateError('The DAV task UID is unavailable.');
    }
    final objectId = task.davObjectId;
    late final String operationId;
    if (objectId == null) {
      final create = await _pendingDavCreateForProjection(task.id);
      if (create == null) {
        throw StateError('The pending DAV task create is unavailable.');
      }
      final sourceObject = _pendingDavCreateObject(create);
      var movedRaw = sourceObject.rawIcs;
      if (fields.isNotEmpty) {
        final patch = buildDavTaskUpdatePatch(
          target: IcalComponentKey(componentType: 'VTODO', uid: uid),
          baselineRawIcs: movedRaw,
          fields: fields,
          parentUid: parentUid,
          nowUtc: _nowUtc,
        );
        if (patch != null) {
          movedRaw = patch.applyTo(movedRaw, nowUtc: _nowUtc().toUtc());
        }
      }
      final cancelled = await queue.cancelUnsentCreate(
        accountId: _accountId,
        collectionId: sourceList.davCollectionId!,
        localProjectionId: task.id,
      );
      if (!cancelled) {
        throw StateError(
          'The pending DAV task create can no longer be moved locally.',
        );
      }
      operationId = await queue.enqueueCreate(
        accountId: _accountId,
        collectionId: destinationList.davCollectionId!,
        object: DavNewObject(
          uid: sourceObject.uid,
          initialMemberName: sourceObject.initialMemberName,
          rawIcs: movedRaw,
          componentType: sourceObject.componentType,
        ),
        localProjectionId: task.id,
        dependsOnOperationId: dependency,
      );
    } else {
      final editableRaw = await queue.editableRawIcsForObject(
        accountId: _accountId,
        collectionId: sourceList.davCollectionId!,
        objectId: objectId,
      );
      final postMovePatch = fields.isEmpty
          ? null
          : buildDavTaskUpdatePatch(
              target: IcalComponentKey(componentType: 'VTODO', uid: uid),
              baselineRawIcs: editableRaw,
              fields: fields,
              parentUid: parentUid,
              nowUtc: _nowUtc,
            );
      operationId = await queue.enqueueMove(
        accountId: _accountId,
        sourceCollectionId: sourceList.davCollectionId!,
        destinationCollectionId: destinationList.davCollectionId!,
        objectId: objectId,
        target: IcalComponentKey(componentType: 'VTODO', uid: uid),
        localProjectionId: task.id,
        postMovePatch: postMovePatch,
        dependsOnOperationId: dependency,
      );
    }

    final now = _now();
    if (objectId == null) {
      await _writeLocalTask(
        sourceList.id,
        task.id,
        TasksCompanion(
          taskListId: Value(destinationList.id),
          davCollectionId: Value(destinationList.davCollectionId),
          parent: Value(parentId),
          parentUid: Value(parentUid),
          status: completeSubtree
              ? const Value('completed')
              : const Value.absent(),
          providerStatus: completeSubtree
              ? const Value('COMPLETED')
              : const Value.absent(),
          percentComplete: completeSubtree
              ? const Value(100)
              : const Value.absent(),
          completedUtc: completeSubtree
              ? Value(task.completedUtc ?? now)
              : const Value.absent(),
          pendingMove: const Value(true),
          localDirty: const Value(true),
          updatedLocalAtUtc: Value(now),
        ),
      );
    } else {
      await (_database.update(_database.tasks)..where(
            (row) =>
                row.accountId.equals(_accountId) &
                row.davObjectId.equals(objectId),
          ))
          .write(
            TasksCompanion(
              taskListId: Value(destinationList.id),
              davCollectionId: Value(destinationList.davCollectionId),
              parent: Value(parentId),
              parentUid: Value(parentUid),
              status: completeSubtree
                  ? const Value('completed')
                  : const Value.absent(),
              providerStatus: completeSubtree
                  ? const Value('COMPLETED')
                  : const Value.absent(),
              percentComplete: completeSubtree
                  ? const Value(100)
                  : const Value.absent(),
              completedUtc: completeSubtree
                  ? Value(task.completedUtc ?? now)
                  : const Value.absent(),
              pendingMove: const Value(true),
              localDirty: const Value(true),
              updatedLocalAtUtc: Value(now),
            ),
          );
    }
    return operationId;
  }

  Future<void> _clearCompletedDavTasks(TaskList taskList) async {
    final rows =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(taskList.id) &
                  row.pendingDelete.equals(false) &
                  row.serverMissing.equals(false),
            ))
            .get();
    final ids = {for (final task in rows) task.id};
    final uids = {
      for (final task in rows)
        if (task.icalUid case final uid?) uid,
    };
    final roots = rows.where((task) {
      if (task.recurrenceIdKey != null || !_davTaskClosed(task)) return false;
      final parent = task.parent;
      final parentUid = task.parentUid;
      final parentAvailable =
          (parent != null && ids.contains(parent)) ||
          (parentUid != null && uids.contains(parentUid));
      return !parentAvailable;
    });
    final failures = <String>[];
    var queued = 0;
    for (final task in roots) {
      try {
        await _deleteDavTask(taskList, task.id);
        queued += 1;
      } on Object {
        failures.add(task.id);
      }
    }
    if (queued > 0) {
      await _rebuildTaskNotifications();
      _onMutationQueued?.call();
    }
    if (failures.isNotEmpty) {
      throw DavTaskBatchMutationException(
        appliedCount: queued,
        failedCount: failures.length,
      );
    }
  }

  Future<TaskList> _requiredTaskList(String taskListId) async {
    final taskList =
        await (_database.select(_database.taskLists)..where(
              (row) =>
                  row.accountId.equals(_accountId) & row.id.equals(taskListId),
            ))
            .getSingleOrNull();
    if (taskList == null || taskList.serverMissing || taskList.pendingDelete) {
      throw StateError('The task list is unavailable.');
    }
    return taskList;
  }

  Future<Task> _requiredTask(String taskListId, String taskId) async {
    final task = await _baselineRow(taskListId, taskId);
    if (task == null || task.serverMissing || task.pendingDelete) {
      throw StateError('The task is unavailable.');
    }
    return task;
  }

  Future<Task?> _davParent(
    String taskListId,
    String? parentTaskId, {
    required String? childTaskId,
  }) async {
    if (parentTaskId == null || parentTaskId.isEmpty) return null;
    final rows =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(taskListId) &
                  row.serverMissing.equals(false) &
                  row.pendingDelete.equals(false),
            ))
            .get();
    final parent = rows.firstWhereOrNull(
      (row) => row.id == parentTaskId || row.icalUid == parentTaskId,
    );
    if (parent == null || parent.icalUid == null) {
      throw StateError('The DAV parent task is unavailable.');
    }
    if (childTaskId != null &&
        _wouldCreateDavCycle(rows, childTaskId, parent)) {
      throw ArgumentError('A task cannot be moved beneath its own subtree.');
    }
    return parent;
  }

  Future<List<Task>> _davChildren(String taskListId, Task task) {
    return (_database.select(_database.tasks)
          ..where(
            (row) =>
                row.accountId.equals(_accountId) &
                row.taskListId.equals(taskListId) &
                row.pendingDelete.equals(false) &
                row.serverMissing.equals(false) &
                (row.parent.equals(task.id) |
                    (task.icalUid == null
                        ? const Constant(false)
                        : row.parentUid.equals(task.icalUid!))),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .get();
  }

  Future<Task?> _davParentTask(String taskListId, Task task) async {
    final parentId = task.parent;
    final parentUid = task.parentUid;
    if ((parentId == null || parentId.isEmpty) &&
        (parentUid == null || parentUid.isEmpty)) {
      return null;
    }
    return (_database.select(_database.tasks)
          ..where(
            (row) =>
                row.accountId.equals(_accountId) &
                row.taskListId.equals(taskListId) &
                row.pendingDelete.equals(false) &
                row.serverMissing.equals(false) &
                ((parentId == null
                        ? const Constant(false)
                        : row.id.equals(parentId)) |
                    (parentUid == null
                        ? const Constant(false)
                        : row.icalUid.equals(parentUid))),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> _ensureDavCreateAllowed(
    TaskList taskList,
    Map<String, Object?> fields,
  ) async {
    if (!await _davCollectionIsShared(taskList.davCollectionId!)) return;
    final classification = _davClassification(fields['taskClassification']);
    if (classification != null && classification != 'PUBLIC') {
      throw UnsupportedError(
        'Private and confidential tasks cannot be created in a calendar '
        'shared with this account.',
      );
    }
  }

  Future<void> _ensureDavTaskMutable(
    TaskList taskList,
    Task task, {
    bool changesClassification = false,
  }) async {
    if (!await _davCollectionIsShared(taskList.davCollectionId!)) return;
    final classification =
        task.taskClassification?.trim().toUpperCase() ?? 'PUBLIC';
    if (classification != 'PUBLIC') {
      throw UnsupportedError(
        'Private and confidential tasks in a shared calendar are read-only.',
      );
    }
    if (changesClassification) {
      throw UnsupportedError(
        'Task classification cannot be changed in a calendar shared with '
        'this account.',
      );
    }
  }

  Future<void> _ensureDavDestinationAllowsTask(
    TaskList destination,
    Task task,
  ) async {
    if (!await _davCollectionIsShared(destination.davCollectionId!)) return;
    final classification =
        task.taskClassification?.trim().toUpperCase() ?? 'PUBLIC';
    if (classification != 'PUBLIC') {
      throw UnsupportedError(
        'Private and confidential tasks cannot be moved into a calendar '
        'shared with this account.',
      );
    }
  }

  Future<bool> _davCollectionIsShared(String collectionId) async {
    final collection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(collectionId))).getSingle();
    final service = await (_database.select(
      _database.davAccountServices,
    )..where((row) => row.accountId.equals(_accountId))).getSingleOrNull();
    final owner = _davHrefPath(collection.ownerHref);
    final principal = _davHrefPath(service?.principalHref);
    return owner != null && principal != null && owner != principal;
  }

  Future<
    ({int movingSortOrder, List<({String taskId, int sortOrder})> adjustments})
  >
  _davSortOrderForMove(
    String taskListId, {
    required String? parentId,
    required String? previousSiblingTaskId,
    required String movingTaskId,
  }) async {
    final rows =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(taskListId) &
                  row.id.equals(movingTaskId).not() &
                  row.recurrenceIdKey.isNull() &
                  row.pendingDelete.equals(false) &
                  row.serverMissing.equals(false),
            ))
            .get();
    final siblings = rows.where((row) => row.parent == parentId).toList()
      ..sort((left, right) {
        final order = (left.sortOrder ?? 0).compareTo(right.sortOrder ?? 0);
        return order != 0 ? order : left.id.compareTo(right.id);
      });
    if (siblings.isEmpty) {
      return (
        movingSortOrder: 0,
        adjustments: const <({String taskId, int sortOrder})>[],
      );
    }
    final insertIndex = previousSiblingTaskId == null
        ? 0
        : siblings.indexWhere((row) => row.id == previousSiblingTaskId) + 1;
    if (previousSiblingTaskId != null && insertIndex == 0) {
      throw ArgumentError('The previous DAV task sibling is unavailable.');
    }
    final previous = insertIndex == 0 ? null : siblings[insertIndex - 1];
    final next = insertIndex < siblings.length ? siblings[insertIndex] : null;
    final previousOrder = previous?.sortOrder ?? 0;
    final nextOrder = next?.sortOrder ?? 0;
    var proposedOrder =
        next != null && (previous == null || nextOrder - 1 > previousOrder)
        ? nextOrder - 1
        : previousOrder + 1;
    if (proposedOrder < 0) proposedOrder = 0;

    final adjustments = <({String taskId, int sortOrder})>[];
    int? priorOrder;
    var movingSortOrder = proposedOrder;
    for (var index = 0; index <= siblings.length; index += 1) {
      final moving = index == insertIndex;
      final sibling = moving
          ? null
          : siblings[index < insertIndex ? index : index - 1];
      final currentOrder = moving ? proposedOrder : sibling!.sortOrder ?? 0;
      final normalizedOrder = priorOrder != null && currentOrder <= priorOrder
          ? priorOrder + 1
          : currentOrder;
      if (moving) {
        movingSortOrder = normalizedOrder;
      } else if (normalizedOrder != currentOrder) {
        adjustments.add((taskId: sibling!.id, sortOrder: normalizedOrder));
      }
      priorOrder = normalizedOrder;
    }
    return (
      movingSortOrder: movingSortOrder,
      adjustments: List<({String taskId, int sortOrder})>.unmodifiable(
        adjustments,
      ),
    );
  }

  Future<PendingOp?> _pendingDavCreateForProjection(String projectionId) {
    return (_database.select(_database.pendingOps)
          ..where(
            (row) =>
                row.taskId.equals(projectionId) &
                row.operationType.equals('dav.create') &
                row.state.isIn(const ['pending', 'failed']) &
                row.attemptCount.equals(0),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAtUtc)]))
        .get()
        .then(
          (operations) =>
              operations.firstWhereOrNull(isDavCreateLocallyEditable),
        );
  }

  Future<void> refreshTask(String taskListId, String taskId) async {
    final apiClient = _apiClient;
    if (apiClient == null) {
      return;
    }

    final dto = await apiClient.getTask(taskListId: taskListId, taskId: taskId);
    List<TaskChecklistItemEntity>? checklistItems;
    if (apiClient is TaskChecklistRemoteClient) {
      final checklistClient = apiClient as TaskChecklistRemoteClient;
      final serverItems = <TaskChecklistItemDto>[];
      String? pageToken;
      do {
        final page = await checklistClient.listChecklistItemsPage(
          taskListId: taskListId,
          taskId: taskId,
          pageToken: pageToken,
        );
        serverItems.addAll(page.items);
        pageToken = page.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);
      final localTask = await _baselineRow(taskListId, taskId);
      final pending = await _pendingChecklistOperations(taskListId, taskId);
      checklistItems = mergeTaskChecklistProjection(
        serverItems: serverItems,
        localItems: decodeTaskChecklistItems(
          localTask?.microsoftChecklistItemsJson,
        ),
        pendingOperations: pending,
      );
    }
    final now = _now();
    await _database.transaction(() async {
      await _database.tasksDao.upsertTask(
        taskFromDto(_accountId, taskListId, dto, now),
      );
      if (checklistItems != null) {
        await _writeChecklistProjection(
          taskListId,
          taskId,
          checklistItems,
          now,
        );
      }
    });
  }

  Future<void> _rebuildTaskNotifications() async {
    await NotificationScheduleService(
      database: _database,
      nowUtc: _nowUtc,
    ).rebuildUpcomingTaskNotifications(_accountId);
    await _onNotificationScheduleChanged?.call();
  }

  Future<void> _patchLocalTask(
    String taskListId,
    String taskId,
    Map<String, Object?> fields,
    String now,
  ) async {
    final current = await _baselineRow(taskListId, taskId);
    final davState = current?.davCollectionId == null
        ? null
        : _localDavTaskState(current!, fields, now);
    await _writeLocalTask(
      taskListId,
      taskId,
      TasksCompanion(
        title: fields.containsKey('title')
            ? Value(fields['title']?.toString() ?? '')
            : const Value.absent(),
        notes: fields.containsKey('notes')
            ? Value(fields['notes']?.toString())
            : const Value.absent(),
        status: davState != null
            ? Value(davState.status)
            : fields.containsKey('status')
            ? Value(fields['status']?.toString())
            : const Value.absent(),
        dueUtc: fields.containsKey('due')
            ? Value(normalizeGoogleDueDateValue(fields['due']))
            : const Value.absent(),
        completedUtc: davState != null
            ? Value(davState.completedUtc)
            : fields.containsKey('completed')
            ? Value(fields['completed']?.toString())
            : fields.containsKey('status')
            ? Value(
                fields['status']?.toString().toLowerCase() == 'completed'
                    ? now
                    : null,
              )
            : const Value.absent(),
        providerStatus: davState != null
            ? Value(davState.providerStatus)
            : fields.containsKey('providerStatus')
            ? Value(fields['providerStatus']?.toString())
            : fields.containsKey('status')
            ? Value(_davProviderStatus(fields['status']))
            : const Value.absent(),
        bodyContent: fields.containsKey('bodyContent')
            ? Value(fields['bodyContent']?.toString())
            : const Value.absent(),
        bodyContentType: fields.containsKey('bodyContentType')
            ? Value(fields['bodyContentType']?.toString())
            : const Value.absent(),
        microsoftDueDateTime: fields.containsKey('microsoftDueDateTime')
            ? Value(_microsoftDateTimeField(fields['microsoftDueDateTime']))
            : const Value.absent(),
        microsoftDueTimeZone: fields.containsKey('microsoftDueTimeZone')
            ? Value(fields['microsoftDueTimeZone']?.toString())
            : const Value.absent(),
        microsoftStartDateTime: fields.containsKey('microsoftStartDateTime')
            ? Value(_microsoftDateTimeField(fields['microsoftStartDateTime']))
            : const Value.absent(),
        microsoftStartTimeZone: fields.containsKey('microsoftStartTimeZone')
            ? Value(fields['microsoftStartTimeZone']?.toString())
            : const Value.absent(),
        microsoftReminderDateTime:
            fields.containsKey('microsoftReminderDateTime')
            ? Value(
                _microsoftDateTimeField(fields['microsoftReminderDateTime']),
              )
            : const Value.absent(),
        microsoftReminderTimeZone:
            fields.containsKey('microsoftReminderTimeZone')
            ? Value(fields['microsoftReminderTimeZone']?.toString())
            : const Value.absent(),
        microsoftIsReminderOn: fields.containsKey('microsoftIsReminderOn')
            ? Value(fields['microsoftIsReminderOn'] as bool?)
            : const Value.absent(),
        recurrenceJson: fields.containsKey('recurrence')
            ? Value(_jsonOrNull(fields['recurrence']))
            : const Value.absent(),
        importance: fields.containsKey('importance')
            ? Value(fields['importance']?.toString())
            : const Value.absent(),
        icalPriority: fields.containsKey('icalPriority')
            ? Value(_exactDavPriority(fields['icalPriority']))
            : fields.containsKey('importance')
            ? Value(_davPriority(fields['importance']))
            : const Value.absent(),
        percentComplete: davState != null
            ? Value(davState.percentComplete)
            : fields.containsKey('percentComplete') ||
                  fields.containsKey('status')
            ? Value(_davPercentComplete(fields))
            : const Value.absent(),
        taskLocation: fields.containsKey('location')
            ? Value(_trimmedOrNull(fields['location']))
            : const Value.absent(),
        taskUrl: fields.containsKey('taskUrl')
            ? Value(_trimmedOrNull(fields['taskUrl']))
            : const Value.absent(),
        taskClassification: fields.containsKey('taskClassification')
            ? Value(_davClassification(fields['taskClassification']))
            : const Value.absent(),
        taskPinned: fields.containsKey('taskPinned')
            ? Value(fields['taskPinned'] == true)
            : const Value.absent(),
        taskHideSubtasks: fields.containsKey('taskHideSubtasks')
            ? Value(fields['taskHideSubtasks'] == true)
            : const Value.absent(),
        taskHideCompletedSubtasks:
            fields.containsKey('taskHideCompletedSubtasks')
            ? Value(fields['taskHideCompletedSubtasks'] == true)
            : const Value.absent(),
        taskAlarmsJson: fields.containsKey('taskAlarms')
            ? Value(jsonEncode(fields['taskAlarms']))
            : const Value.absent(),
        parentUid: fields.containsKey('parentUid')
            ? Value(fields['parentUid']?.toString())
            : const Value.absent(),
        sortOrder: fields.containsKey('sortOrder')
            ? Value(fields['sortOrder'] as int?)
            : const Value.absent(),
        categoriesJson: fields.containsKey('categories')
            ? Value(_jsonOrNull(fields['categories']))
            : const Value.absent(),
        deleted: fields.containsKey('deleted')
            ? Value(fields['deleted'] as bool?)
            : const Value.absent(),
        localDirty: const Value(true),
        updatedLocalAtUtc: Value(now),
      ),
    );
  }

  Future<void> _writeLocalTask(
    String taskListId,
    String taskId,
    TasksCompanion companion,
  ) {
    final update = _database.update(_database.tasks)
      ..where(
        (row) =>
            row.accountId.equals(_accountId) &
            row.taskListId.equals(taskListId) &
            row.id.equals(taskId),
      );
    return update.write(companion);
  }

  Future<void> _writeChecklistProjection(
    String taskListId,
    String parentTaskId,
    Iterable<TaskChecklistItemEntity> items,
    String now,
  ) {
    return _writeLocalTask(
      taskListId,
      parentTaskId,
      TasksCompanion(
        microsoftChecklistItemsJson: Value(encodeTaskChecklistItems(items)),
        updatedLocalAtUtc: Value(now),
      ),
    );
  }

  Future<void> _enqueueChecklistOperation({
    required String operation,
    required String taskListId,
    required String parentTaskId,
    required String checklistItemId,
    required Map<String, Object?> request,
    required String createdAtUtc,
    String? localTempId,
  }) async {
    final predecessor = await _latestPendingChecklistOperation(
      taskListId,
      parentTaskId,
      checklistItemId,
    );
    await _database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: _uuid.v4(),
        accountId: _accountId,
        entityType: 'task_checklist_item',
        operation: operation,
        taskListId: Value(taskListId),
        taskId: Value(parentTaskId),
        localTempId: Value(localTempId),
        dependsOnOpId: Value(predecessor?.id),
        requestJson: jsonEncode(request),
        createdAtUtc: createdAtUtc,
        updatedAtUtc: createdAtUtc,
      ),
    );
  }

  Future<List<PendingOp>> _pendingChecklistOperations(
    String taskListId,
    String parentTaskId,
  ) {
    final query = _database.select(_database.pendingOps)
      ..where(
        (row) =>
            row.accountId.equals(_accountId) &
            row.entityType.equals('task_checklist_item') &
            row.taskListId.equals(taskListId) &
            row.taskId.equals(parentTaskId),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAtUtc),
        (row) => OrderingTerm.asc(row.updatedAtUtc),
      ]);
    return query.get();
  }

  Future<PendingOp?> _latestPendingChecklistOperation(
    String taskListId,
    String parentTaskId,
    String checklistItemId,
  ) async {
    final operations = await _pendingChecklistOperations(
      taskListId,
      parentTaskId,
    );
    for (final operation in operations.reversed) {
      if (_checklistItemIdFromOperation(operation) == checklistItemId) {
        return operation;
      }
    }
    return null;
  }

  Future<PendingOp?> _pendingChecklistCreate(
    String taskListId,
    String parentTaskId,
    String checklistItemId,
  ) async {
    final operations = await _pendingChecklistOperations(
      taskListId,
      parentTaskId,
    );
    return operations.firstWhereOrNull(
      (operation) =>
          operation.operation == 'create_task_checklist_item' &&
          _checklistItemIdFromOperation(operation) == checklistItemId,
    );
  }

  Future<void> _deleteChecklistOperationChain({
    required String parentTaskId,
    required String checklistItemId,
  }) async {
    final operations =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.entityType.equals('task_checklist_item') &
                  row.taskId.equals(parentTaskId),
            ))
            .get();
    for (final operation in operations) {
      if (_checklistItemIdFromOperation(operation) == checklistItemId) {
        await _database.pendingOpsDao.deleteOp(operation.id);
      }
    }
  }

  Future<String> _enqueue({
    required String operation,
    required Map<String, Object?> request,
    required String createdAtUtc,
    String? taskListId,
    String? taskId,
    String? localTempId,
    String? baselineUpdatedUtc,
    String? baselineRawJson,
    String? dependsOnOpId,
  }) async {
    final operationId = _uuid.v4();
    await _database.transaction(() async {
      final predecessor = await _latestPendingTaskEdit(
        operation: operation,
        taskListId: taskListId,
        taskId: taskId,
      );
      await _database.pendingOpsDao.enqueue(
        PendingOpsCompanion.insert(
          id: operationId,
          accountId: _accountId,
          entityType: 'task',
          operation: operation,
          taskListId: Value(taskListId),
          taskId: Value(taskId),
          localTempId: Value(localTempId),
          dependsOnOpId: Value(dependsOnOpId ?? predecessor?.id),
          requestJson: jsonEncode(request),
          baselineUpdatedUtc: Value(baselineUpdatedUtc),
          baselineRawJson: Value(baselineRawJson),
          createdAtUtc: createdAtUtc,
          updatedAtUtc: createdAtUtc,
        ),
      );
    });
    return operationId;
  }

  Future<PendingOp?> _latestPendingTaskEdit({
    required String operation,
    required String? taskListId,
    required String? taskId,
  }) async {
    if ((operation != 'patch_task' && operation != 'update_task') ||
        taskListId == null ||
        taskId == null) {
      return null;
    }
    final query = _database.select(_database.pendingOps)
      ..where(
        (row) =>
            row.accountId.equals(_accountId) &
            row.entityType.equals('task') &
            row.taskListId.equals(taskListId) &
            row.taskId.equals(taskId) &
            (row.operation.equals('patch_task') |
                row.operation.equals('update_task')),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.createdAtUtc),
        (row) => OrderingTerm.desc(row.updatedAtUtc),
      ]);
    final edits = await query.get();
    final predecessorIds = {
      for (final edit in edits)
        if (edit.dependsOnOpId != null) edit.dependsOnOpId!,
    };
    for (final edit in edits) {
      if (!predecessorIds.contains(edit.id)) {
        return edit;
      }
    }
    return edits.isEmpty ? null : edits.first;
  }

  Future<Task?> _baselineRow(String taskListId, String taskId) {
    return (_database.select(_database.tasks)..where(
          (row) =>
              row.accountId.equals(_accountId) &
              row.taskListId.equals(taskListId) &
              row.id.equals(taskId),
        ))
        .getSingleOrNull();
  }

  Future<String?> _completedTasksBaselineUpdatedUtc(String taskListId) async {
    final rows =
        await (_database.select(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.taskListId.equals(taskListId) &
                  row.status.equals('completed') &
                  (row.deleted.isNull() | row.deleted.equals(false)),
            ))
            .get();

    DateTime? latest;
    for (final row in rows) {
      final updated = DateTime.tryParse(row.updatedUtc ?? '')?.toUtc();
      if (updated != null && (latest == null || updated.isAfter(latest))) {
        latest = updated;
      }
    }
    return latest?.toIso8601String();
  }

  bool _matchesFilter(Task row, TaskViewFilter filter, {TaskList? taskList}) {
    if (!filter.showCompleted && row.status == 'completed') {
      return false;
    }
    if (!filter.showDeleted && row.deleted == true) {
      return false;
    }
    if (!filter.showHidden && row.hidden == true) {
      return false;
    }
    if (!filter.showAssigned && row.assignmentInfoJson != null) {
      return false;
    }
    return _matchesSearch(row, filter.searchQuery, taskList: taskList);
  }

  bool _matchesSearch(Task row, String query, {TaskList? taskList}) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    return [
      row.title,
      row.notes,
      row.bodyContent,
      row.categoriesJson,
      taskList?.title,
    ].whereType<String>().any(
      (value) => value.toLowerCase().contains(normalizedQuery),
    );
  }

  List<TaskTreeNode> _buildTree(List<TaskEntity> tasks) {
    final byId = {for (final task in tasks) task.id: task};
    final byUid = {
      for (final task in tasks)
        if (task.icalUid != null && task.icalUid!.isNotEmpty)
          task.icalUid!: task,
    };
    TaskEntity? parentOf(TaskEntity task) {
      final parentId = task.parent;
      final parentUid = task.parentUid;
      return (parentId == null ? null : byId[parentId] ?? byUid[parentId]) ??
          (parentUid == null ? null : byUid[parentUid] ?? byId[parentUid]);
    }

    final byParent = <String, List<TaskEntity>>{};
    final roots = <TaskEntity>[];
    for (final task in tasks) {
      final parent = parentOf(task);
      if (parent == null || parent.id == task.id) {
        roots.add(task);
      } else {
        byParent.putIfAbsent(parent.id, () => []).add(task);
      }
    }
    roots.sort(_compareTaskOrder);
    for (final children in byParent.values) {
      children.sort(_compareTaskOrder);
    }

    final emitted = <String>{};
    TaskTreeNode buildNode(TaskEntity task, Set<String> ancestors) {
      emitted.add(task.id);
      if (!ancestors.add(task.id)) {
        return TaskTreeNode(task: task, children: const []);
      }
      final children = <TaskTreeNode>[];
      for (final child in byParent[task.id] ?? const <TaskEntity>[]) {
        if (!ancestors.contains(child.id)) {
          children.add(buildNode(child, ancestors));
        }
      }
      ancestors.remove(task.id);
      return TaskTreeNode(task: task, children: children);
    }

    final nodes = [for (final root in roots) buildNode(root, <String>{})];
    for (final task in tasks..sort(_compareTaskOrder)) {
      if (!emitted.contains(task.id)) {
        nodes.add(buildNode(task, <String>{}));
      }
    }
    return nodes;
  }

  int _compareTaskOrder(TaskEntity left, TaskEntity right) {
    if (left.sortOrder != null && right.sortOrder != null) {
      final sortOrderCompare = left.sortOrder!.compareTo(right.sortOrder!);
      if (sortOrderCompare != 0) return sortOrderCompare;
    }
    final positionCompare = (left.position ?? '').compareTo(
      right.position ?? '',
    );
    if (positionCompare != 0) {
      return positionCompare;
    }
    return left.title.compareTo(right.title);
  }

  String _now() => _nowUtc().toIso8601String();
}

TaskChecklistItemEntity taskChecklistItemFromDto(TaskChecklistItemDto dto) {
  final raw = <String, Object?>{
    ...dto.rawJson,
    'id': dto.id,
    'displayName': dto.title,
    'isChecked': dto.completed,
    if (dto.createdAtUtc != null)
      'createdDateTime': dto.createdAtUtc!.toIso8601String(),
    if (dto.completedAtUtc != null)
      'checkedDateTime': dto.completedAtUtc!.toIso8601String(),
  };
  return TaskChecklistItemEntity.fromJson(raw);
}

List<TaskChecklistItemEntity> mergeTaskChecklistProjection({
  required Iterable<TaskChecklistItemDto> serverItems,
  required Iterable<TaskChecklistItemEntity> localItems,
  required Iterable<PendingOp> pendingOperations,
}) {
  final items = <String, TaskChecklistItemEntity>{
    for (final item in serverItems.map(taskChecklistItemFromDto)) item.id: item,
  };
  final localById = {for (final item in localItems) item.id: item};
  for (final operation in pendingOperations) {
    final itemId = _checklistItemIdFromOperation(operation);
    if (itemId == null) continue;
    final request = _pendingRequestOrNull(operation);
    if (request == null) continue;
    switch (operation.operation) {
      case 'create_task_checklist_item':
        final local = localById[itemId];
        if (local != null) {
          items[itemId] = local;
          continue;
        }
        final body = request['body'];
        if (body is Map) {
          items[itemId] = TaskChecklistItemEntity.fromJson({
            ...body.cast<String, Object?>(),
            'id': itemId,
          });
        }
      case 'patch_task_checklist_item':
        final current = items[itemId];
        final body = request['body'];
        if (current == null || body is! Map) continue;
        items[itemId] = TaskChecklistItemEntity.fromJson({
          ...current.toJson(),
          ...body.cast<String, Object?>(),
        });
      case 'delete_task_checklist_item':
        items.remove(itemId);
    }
  }
  return List.unmodifiable(items.values);
}

String? _checklistItemIdFromOperation(PendingOp operation) {
  final request = _pendingRequestOrNull(operation);
  return request?['checklistItemId']?.toString() ?? operation.localTempId;
}

Map<String, Object?>? _pendingRequestOrNull(PendingOp operation) {
  try {
    final decoded = jsonDecode(operation.requestJson);
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}

String _duplicateDavTaskResource(
  String sourceRawIcs, {
  required String sourceUid,
  required String newUid,
  required String? parentUid,
  required DateTime nowUtc,
}) {
  final semantic = IcalSemanticDocument.parse(sourceRawIcs);
  final sourceComponents = semantic.components
      .where(
        (component) =>
            component.componentType == 'VTODO' && component.uid == sourceUid,
      )
      .toList(growable: false);
  if (sourceComponents.isEmpty ||
      sourceComponents
              .where((component) => component.recurrenceIdKey == null)
              .length !=
          1) {
    throw StateError('The DAV task recurrence set is unavailable.');
  }

  // RFC 5545 requires every component in a recurrence set to share its UID.
  // Nextcloud changes the duplicated task's UID; update detached instances as
  // well so a recurring duplicate remains one valid calendar object resource.
  final patcher = IcalDocumentPatcher(semantic.document);
  for (final component in sourceComponents) {
    patcher.replaceSingletonRaw(
      IcalComponentKey(
        componentType: 'VTODO',
        uid: sourceUid,
        recurrenceIdKey: component.recurrenceIdKey,
      ),
      'UID',
      newUid,
    );
  }

  final timestamp = _utcIcalTimestamp(nowUtc);
  final duplicated = DavMutationPatch(
    target: IcalComponentKey(componentType: 'VTODO', uid: newUid),
    scope: DavMutationScope.recurrenceMaster,
    operations: [
      DavPatchOperation.setRaw('CREATED', timestamp),
      DavPatchOperation.setRaw('LAST-MODIFIED', timestamp),
      DavPatchOperation.setRaw('DTSTAMP', timestamp),
      DavPatchOperation.setTaskParent(parentUid),
    ],
  ).applyTo(semantic.document.serialize(), nowUtc: nowUtc.toUtc());
  final result = IcalSemanticDocument.parse(duplicated);
  if (result.primaryUid != newUid ||
      result.components.any(
        (component) =>
            component.componentType == 'VTODO' && component.uid != newUid,
      )) {
    throw StateError('The duplicated DAV task is invalid.');
  }
  return duplicated;
}

String _utcIcalTimestamp(DateTime value) {
  final utc = value.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}'
      '${two(utc.month)}${two(utc.day)}T'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

bool _wouldCreateDavCycle(
  List<Task> tasks,
  String childTaskId,
  Task proposedParent,
) {
  final byId = {for (final task in tasks) task.id: task};
  final byUid = {
    for (final task in tasks)
      if (task.icalUid != null) task.icalUid!: task,
  };
  final seen = <String>{};
  Task? cursor = proposedParent;
  while (cursor != null && seen.add(cursor.id)) {
    if (cursor.id == childTaskId) return true;
    final parentKey = cursor.parentUid ?? cursor.parent;
    cursor = parentKey == null ? null : byId[parentKey] ?? byUid[parentKey];
  }
  return false;
}

String? _davHrefPath(String? source) {
  final value = source?.trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

bool _davTaskCompleted(Task task) =>
    task.providerStatus?.toUpperCase() == 'COMPLETED' ||
    task.completedUtc != null;

bool _davTaskClosed(Task task) =>
    _davTaskCompleted(task) ||
    task.providerStatus?.toUpperCase() == 'CANCELLED';

DavMutationPatch? _buildDavTaskMutationPatch({
  required IcalComponentKey target,
  required String baselineRawIcs,
  required Map<String, Object?> fields,
  required DateTime mutationNowUtc,
  String? parentUid,
}) {
  DavMutationPatch? regular(Map<String, Object?> values) =>
      buildDavTaskUpdatePatch(
        target: target,
        baselineRawIcs: baselineRawIcs,
        fields: values,
        parentUid: parentUid,
        nowUtc: () => mutationNowUtc,
      );

  if (!_requestsDavTaskCompletion(fields)) return regular(fields);
  final nonCompletionFields = Map<String, Object?>.from(fields)
    ..remove('status')
    ..remove('taskStatus')
    ..remove('percentComplete')
    ..remove('completedAtUtc')
    ..remove('completed');
  final preceding = regular(nonCompletionFields);
  final preparedRawIcs = preceding == null
      ? baselineRawIcs
      : preceding.applyTo(baselineRawIcs, nowUtc: mutationNowUtc);
  final prepared = IcalSemanticDocument.parse(preparedRawIcs);
  final master = prepared.components.firstWhereOrNull(
    (component) =>
        component.componentType == 'VTODO' &&
        component.uid == target.uid &&
        component.recurrenceIdKey == null,
  );
  if (master == null ||
      master.recurrenceRules.isEmpty ||
      master.taskUiState == IcalTaskUiState.completed) {
    return regular(fields);
  }
  final completedAt = _requestedDavCompletionDate(fields);
  final completion = buildDavRecurringTaskCompletionPatch(
    target: target,
    baselineRawIcs: preparedRawIcs,
    completedAtUtc: completedAt,
    nowUtc: () => mutationNowUtc,
  );
  if (preceding == null) return completion;
  return DavMutationPatch(
    target: target,
    scope: DavMutationScope.recurrenceMaster,
    operations: [...preceding.operations, ...completion.operations],
  );
}

bool _requestsDavTaskCompletion(Map<String, Object?> fields) {
  if (fields['completedAtUtc'] != null || fields['completed'] != null) {
    return true;
  }
  if (fields['percentComplete'] == 100) return true;
  final value = fields.containsKey('taskStatus')
      ? fields['taskStatus']
      : fields['status'];
  return switch (value?.toString().trim().toUpperCase()) {
    'COMPLETED' => true,
    _ => false,
  };
}

DateTime? _requestedDavCompletionDate(Map<String, Object?> fields) {
  final value = fields['completedAtUtc'] ?? fields['completed'];
  if (value == null) return null;
  final parsed = value is DateTime
      ? value
      : DateTime.tryParse(value.toString());
  if (parsed == null) throw ArgumentError.value(value, 'completedAtUtc');
  return parsed.toUtc();
}

String _pendingDavCreateRawIcs(PendingOp operation) {
  return _pendingDavCreateObject(operation).rawIcs;
}

DavNewObject _pendingDavCreateObject(PendingOp operation) {
  try {
    final decoded = jsonDecode(operation.requestJson);
    if (decoded is Map &&
        decoded['uid'] is String &&
        decoded['initialMemberName'] is String &&
        decoded['rawIcs'] is String &&
        decoded['componentType'] is String) {
      return DavNewObject(
        uid: decoded['uid']! as String,
        initialMemberName: decoded['initialMemberName']! as String,
        rawIcs: decoded['rawIcs']! as String,
        componentType: decoded['componentType']! as String,
      );
    }
  } on FormatException {
    // Invalid pending payloads use the same local-state error.
  }
  throw StateError('The pending DAV task body is invalid.');
}

int? _davPriority(Object? importance) => switch (importance?.toString()) {
  'high' => 1,
  'low' => 9,
  'normal' || null => null,
  _ => null,
};

int? _exactDavPriority(Object? value) {
  if (value == null) return null;
  if (value is! int || value < 0 || value > 9) {
    throw ArgumentError.value(value, 'icalPriority');
  }
  return value == 0 ? null : value;
}

({
  String status,
  String? providerStatus,
  int? percentComplete,
  String? completedUtc,
})?
_localDavTaskState(Task current, Map<String, Object?> fields, String now) {
  final hasStatus =
      fields.containsKey('taskStatus') || fields.containsKey('status');
  final hasPercent = fields.containsKey('percentComplete');
  final hasCompleted = fields.containsKey('completedAtUtc');
  if (!hasStatus && !hasPercent && !hasCompleted) return null;

  final currentPercent = current.percentComplete ?? 0;
  final completedValue = fields['completedAtUtc'];
  if (hasCompleted && completedValue != null) {
    final parsed = DateTime.tryParse(completedValue.toString());
    if (parsed == null) throw ArgumentError.value(completedValue);
    return (
      status: 'completed',
      providerStatus: 'COMPLETED',
      percentComplete: 100,
      completedUtc: parsed.toUtc().toIso8601String(),
    );
  }
  if (hasPercent) {
    final percent = fields['percentComplete'];
    if (percent is! int || percent < 0 || percent > 100) {
      throw ArgumentError.value(percent, 'percentComplete');
    }
    if (percent == 100) {
      return (
        status: 'completed',
        providerStatus: 'COMPLETED',
        percentComplete: 100,
        completedUtc: current.completedUtc ?? now,
      );
    }
    if (percent == 0) {
      return (
        status: 'needsAction',
        providerStatus: 'NEEDS-ACTION',
        percentComplete: null,
        completedUtc: null,
      );
    }
    return (
      status: 'inProcess',
      providerStatus: 'IN-PROCESS',
      percentComplete: percent,
      completedUtc: null,
    );
  }
  if (hasStatus) {
    final raw = fields.containsKey('taskStatus')
        ? fields['taskStatus']
        : fields['status'];
    final providerStatus = _davProviderStatus(raw);
    return switch (providerStatus) {
      'COMPLETED' => (
        status: 'completed',
        providerStatus: 'COMPLETED',
        percentComplete: 100,
        completedUtc: current.completedUtc ?? now,
      ),
      'IN-PROCESS' => (
        status: 'inProcess',
        providerStatus: 'IN-PROCESS',
        percentComplete: currentPercent == 100
            ? 99
            : currentPercent == 0
            ? 1
            : currentPercent,
        completedUtc: null,
      ),
      'CANCELLED' => (
        status: 'cancelled',
        providerStatus: 'CANCELLED',
        percentComplete: current.percentComplete,
        completedUtc: current.completedUtc,
      ),
      'NEEDS-ACTION' || null => (
        status: 'needsAction',
        providerStatus: providerStatus,
        percentComplete: currentPercent == 100 ? 99 : current.percentComplete,
        completedUtc: null,
      ),
      _ => throw ArgumentError.value(raw, 'taskStatus'),
    };
  }
  if (currentPercent == 100) {
    return (
      status: 'inProcess',
      providerStatus: 'IN-PROCESS',
      percentComplete: 99,
      completedUtc: null,
    );
  }
  return (
    status: current.status ?? 'needsAction',
    providerStatus: current.providerStatus,
    percentComplete: current.percentComplete,
    completedUtc: null,
  );
}

String? _trimmedOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _davClassification(Object? value) =>
    switch (value?.toString().toUpperCase()) {
      'PUBLIC' => 'PUBLIC',
      'PRIVATE' => 'PRIVATE',
      'CONFIDENTIAL' => 'CONFIDENTIAL',
      null || '' => null,
      _ => throw ArgumentError.value(value, 'taskClassification'),
    };

int _davPercentComplete(Map<String, Object?> fields) {
  final explicit = fields['percentComplete'];
  if (explicit is int) return explicit.clamp(0, 100);
  return switch (fields['status']?.toString().toLowerCase()) {
    'completed' => 100,
    'inprocess' || 'in-process' => 50,
    _ => 0,
  };
}

String? _davProviderStatus(Object? status) =>
    switch (status?.toString().toLowerCase()) {
      'completed' => 'COMPLETED',
      'inprocess' || 'in-process' => 'IN-PROCESS',
      'needsaction' || 'needs-action' => 'NEEDS-ACTION',
      null => null,
      final value => value.toUpperCase(),
    };

({
  String? dueDateTime,
  String? dueTimeZone,
  String? startDateTime,
  String? startTimeZone,
})
_davNativeTaskFields(String? source) {
  const empty = (
    dueDateTime: null,
    dueTimeZone: null,
    startDateTime: null,
    startTimeZone: null,
  );
  if (source == null || source.isEmpty) return empty;
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) return empty;
    final due = _davNativeTemporal(decoded['nativeDue']);
    final start = _davNativeTemporal(decoded['nativeStart']);
    return (
      dueDateTime: due.dateTime,
      dueTimeZone: due.timeZone,
      startDateTime: start.dateTime,
      startTimeZone: start.timeZone,
    );
  } on FormatException {
    return empty;
  }
}

({String? dateTime, String? timeZone}) _davNativeTemporal(Object? source) {
  if (source is! Map) return (dateTime: null, timeZone: null);
  final raw = source['raw']?.toString();
  if (raw == null || raw.isEmpty) return (dateTime: null, timeZone: null);
  final kind = source['kind']?.toString();
  final date = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(raw);
  if (date != null) {
    return (
      dateTime: '${date.group(1)}-${date.group(2)}-${date.group(3)}',
      timeZone: null,
    );
  }
  final dateTime = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$',
  ).firstMatch(raw);
  if (dateTime == null) return (dateTime: null, timeZone: null);
  final normalized =
      '${dateTime.group(1)}-${dateTime.group(2)}-${dateTime.group(3)}'
      'T${dateTime.group(4)}:${dateTime.group(5)}:${dateTime.group(6)}'
      '${dateTime.group(7)}';
  return (
    dateTime: normalized,
    timeZone: kind == 'utcDateTime' ? 'UTC' : source['timeZoneId']?.toString(),
  );
}

String _accountLabel(Account account) {
  final name = account.displayName?.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  final address = account.email?.trim();
  if (address != null && address.isNotEmpty) {
    return address;
  }
  return BusyProviderCodec.requireStorageValue(account.provider).displayName;
}

Map<String, Object?> _remoteTaskFields(Map<String, Object?> fields) {
  return {
    for (final entry in fields.entries)
      entry.key: entry.key == 'due' && entry.value != null
          ? _remoteDueValue(entry.value!)
          : entry.value,
  };
}

Object? _remoteDueValue(Object value) {
  if (value is DateTime) {
    return encodeGoogleDueDate(value);
  }
  final normalized = normalizeGoogleDueDateValue(value);
  if (normalized == null) {
    return null;
  }
  return '${normalized}T00:00:00.000Z';
}

List<String> _stringListFromJson(String? value) {
  if (value == null || value.isEmpty) {
    return const [];
  }
  try {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      return [
        for (final item in decoded)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString().trim(),
      ];
    }
  } on FormatException {
    return const [];
  }
  return const [];
}

TasksCompanion taskFromDto(
  String accountId,
  String taskListId,
  TaskDto dto,
  String nowUtc,
) {
  return TasksCompanion.insert(
    accountId: accountId,
    taskListId: taskListId,
    id: dto.id,
    kind: Value(dto.kind),
    etag: Value(dto.etag),
    title: dto.title,
    updatedUtc: Value(dto.updated?.toIso8601String()),
    selfLink: Value(dto.selfLink),
    parent: Value(dto.parent),
    position: Value(dto.position),
    notes: Value(dto.notes),
    status: Value(dto.status),
    dueUtc: Value(_providerNeutralDueDate(dto)),
    completedUtc: Value(dto.completed?.toIso8601String()),
    providerStatus: Value(_stringOrNull(dto.rawJson['status'])),
    bodyContent: Value(_bodyContent(dto.rawJson)),
    bodyContentType: Value(_bodyContentType(dto.rawJson)),
    microsoftDueDateTime: Value(
      _dateTimeTimeZoneDateTime(dto.rawJson['dueDateTime']),
    ),
    microsoftDueTimeZone: Value(
      _dateTimeTimeZoneTimeZone(dto.rawJson['dueDateTime']),
    ),
    microsoftStartDateTime: Value(
      _dateTimeTimeZoneDateTime(dto.rawJson['startDateTime']),
    ),
    microsoftStartTimeZone: Value(
      _dateTimeTimeZoneTimeZone(dto.rawJson['startDateTime']),
    ),
    microsoftReminderDateTime: Value(
      _dateTimeTimeZoneDateTime(dto.rawJson['reminderDateTime']),
    ),
    microsoftReminderTimeZone: Value(
      _dateTimeTimeZoneTimeZone(dto.rawJson['reminderDateTime']),
    ),
    microsoftIsReminderOn: Value(_boolOrNull(dto.rawJson['isReminderOn'])),
    microsoftCompletedDateTime: Value(
      _dateTimeTimeZoneDateTime(dto.rawJson['completedDateTime']),
    ),
    microsoftCompletedTimeZone: Value(
      _dateTimeTimeZoneTimeZone(dto.rawJson['completedDateTime']),
    ),
    microsoftChecklistItemsJson: dto.rawJson.containsKey('checklistItems')
        ? Value(_jsonOrNull(dto.rawJson['checklistItems']))
        : const Value.absent(),
    recurrenceJson: Value(_jsonOrNull(dto.rawJson['recurrence'])),
    importance: Value(_stringOrNull(dto.rawJson['importance'])),
    categoriesJson: Value(_jsonOrNull(dto.rawJson['categories'])),
    hasAttachments: Value(_boolOrNull(dto.rawJson['hasAttachments'])),
    providerMetadataJson: Value(_providerMetadataJson(dto.rawJson)),
    deleted: Value(dto.deleted),
    hidden: Value(dto.hidden),
    linksJson: Value(
      jsonEncode(dto.links.map((link) => link.rawJson).toList()),
    ),
    webViewLink: Value(dto.webViewLink),
    assignmentInfoJson: Value(
      dto.assignmentInfo == null ? null : jsonEncode(dto.assignmentInfo),
    ),
    rawJson: jsonEncode(dto.rawJson),
    serverMissing: const Value(false),
    localDirty: const Value(false),
    pendingDelete: const Value(false),
    pendingMove: const Value(false),
    localCreated: const Value(false),
    lastSyncedAtUtc: Value(nowUtc),
    createdLocalAtUtc: nowUtc,
    updatedLocalAtUtc: nowUtc,
  );
}

String? _providerNeutralDueDate(TaskDto dto) {
  final microsoftDue = _dateTimeTimeZoneDateTime(dto.rawJson['dueDateTime']);
  if (microsoftDue != null && microsoftDue.length >= 10) {
    return microsoftDue.substring(0, 10);
  }
  return normalizeGoogleDueDateValue(dto.rawJson['due'] ?? dto.due);
}

String? _microsoftDateTimeField(Object? value) {
  if (value is Map) {
    return value['dateTime']?.toString();
  }
  return value?.toString();
}

String? _dateTimeTimeZoneDateTime(Object? value) {
  if (value is Map) {
    return value['dateTime']?.toString();
  }
  return null;
}

String? _dateTimeTimeZoneTimeZone(Object? value) {
  if (value is Map) {
    return value['timeZone']?.toString();
  }
  return null;
}

String? _bodyContent(Map<String, Object?> rawJson) {
  final body = rawJson['body'];
  if (body is Map) {
    return body['content']?.toString();
  }
  return null;
}

String? _bodyContentType(Map<String, Object?> rawJson) {
  final body = rawJson['body'];
  if (body is Map) {
    return body['contentType']?.toString();
  }
  return null;
}

String? _jsonOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return jsonEncode(value);
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
    if (rawJson.containsKey('createdDateTime'))
      'createdDateTime': rawJson['createdDateTime'],
    if (rawJson.containsKey('lastModifiedDateTime'))
      'lastModifiedDateTime': rawJson['lastModifiedDateTime'],
    if (rawJson.containsKey('bodyLastModifiedDateTime'))
      'bodyLastModifiedDateTime': rawJson['bodyLastModifiedDateTime'],
    if (rawJson.containsKey('@removed')) '@removed': rawJson['@removed'],
  };
  return metadata.isEmpty ? null : jsonEncode(metadata);
}
