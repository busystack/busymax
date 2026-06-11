import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../db/app_database.dart';
import '../../../google_tasks/api/google_tasks_api_client.dart';
import '../../../google_tasks/api/google_tasks_api_models.dart';
import '../../../google_tasks/api/google_tasks_json.dart';
import '../../../task_providers/task_provider.dart';
import '../../notifications/notification_schedule_service.dart';

class TaskTreeNode {
  const TaskTreeNode({required this.task, required this.children});

  final TaskEntity task;
  final List<TaskTreeNode> children;
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
  final TaskProvider provider;
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
      microsoftDueDateTime: row.microsoftDueDateTime,
      microsoftDueTimeZone: row.microsoftDueTimeZone,
      microsoftStartDateTime: row.microsoftStartDateTime,
      microsoftStartTimeZone: row.microsoftStartTimeZone,
      microsoftReminderDateTime: row.microsoftReminderDateTime,
      microsoftReminderTimeZone: row.microsoftReminderTimeZone,
      microsoftIsReminderOn: row.microsoftIsReminderOn,
      microsoftCompletedDateTime: row.microsoftCompletedDateTime,
      microsoftCompletedTimeZone: row.microsoftCompletedTimeZone,
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
    this.parentTaskId,
    this.previousSiblingTaskId,
  });

  final String title;
  final String? notes;
  final String? status;
  final DateTime? dueUtc;
  final List<String> categories;
  final String? parentTaskId;
  final String? previousSiblingTaskId;
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

  Stream<List<TaskTreeNode>> watchTaskTree(
    String taskListId,
    TaskViewFilter filter,
  ) {
    return _database.tasksDao.watchTaskTree(_accountId, taskListId).map((rows) {
      final visible = rows.where((row) => _matchesFilter(row, filter));
      return _buildTree(visible.map(TaskEntity.fromRow).toList());
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
              provider: TaskProviderParsing.fromStorageValue(
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
            row.pendingDelete.equals(false),
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
    final now = _now();
    final localId = 'local-task-${_uuid.v4()}';
    final due = normalizeGoogleDueDateValue(input.dueUtc);
    final categories = [
      for (final category in input.categories)
        if (category.trim().isNotEmpty) category.trim(),
    ];
    await _database.transaction(() async {
      await _database.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: _accountId,
          taskListId: taskListId,
          id: localId,
          title: input.title,
          notes: Value(input.notes),
          status: Value(input.status ?? 'needsAction'),
          dueUtc: Value(due),
          categoriesJson: categories.isEmpty
              ? const Value.absent()
              : Value(_jsonOrNull(categories)),
          parent: Value(input.parentTaskId),
          rawJson: jsonEncode({'id': localId, 'title': input.title}),
          localDirty: const Value(true),
          localCreated: const Value(true),
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
      await _enqueue(
        operation: 'create_task',
        taskListId: taskListId,
        taskId: localId,
        localTempId: localId,
        request: {
          'body': {
            'title': input.title,
            if (input.notes != null) 'notes': input.notes,
            if (input.status != null) 'status': input.status,
            if (input.dueUtc != null) 'due': encodeGoogleDueDate(input.dueUtc!),
            if (categories.isNotEmpty) 'categories': categories,
          },
          if (input.parentTaskId != null) 'parent': input.parentTaskId,
          if (input.previousSiblingTaskId != null)
            'previous': input.previousSiblingTaskId,
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
    final now = _now();
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
    await NotificationScheduleService(
      database: _database,
      nowUtc: _nowUtc,
    ).rebuildUpcomingTaskNotifications(_accountId);
    _onMutationQueued?.call();
  }

  Future<void> updateTaskFull(
    String taskListId,
    String taskId,
    TaskPutInput input,
  ) async {
    final now = _now();
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
    await NotificationScheduleService(
      database: _database,
      nowUtc: _nowUtc,
    ).rebuildUpcomingTaskNotifications(_accountId);
    _onMutationQueued?.call();
  }

  Future<void> deleteTask(String taskListId, String taskId) async {
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
    await NotificationScheduleService(
      database: _database,
      nowUtc: _nowUtc,
    ).rebuildUpcomingTaskNotifications(_accountId);
    _onMutationQueued?.call();
  }

  Future<void> moveTask(TaskMoveInput input) async {
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

  Future<void> refreshTask(String taskListId, String taskId) async {
    final apiClient = _apiClient;
    if (apiClient == null) {
      return;
    }

    final dto = await apiClient.getTask(taskListId: taskListId, taskId: taskId);
    await _database.tasksDao.upsertTask(
      taskFromDto(_accountId, taskListId, dto, _now()),
    );
  }

  Future<void> _patchLocalTask(
    String taskListId,
    String taskId,
    Map<String, Object?> fields,
    String now,
  ) {
    return _writeLocalTask(
      taskListId,
      taskId,
      TasksCompanion(
        title: fields.containsKey('title')
            ? Value(fields['title']?.toString() ?? '')
            : const Value.absent(),
        notes: fields.containsKey('notes')
            ? Value(fields['notes']?.toString())
            : const Value.absent(),
        status: fields.containsKey('status')
            ? Value(fields['status']?.toString())
            : const Value.absent(),
        dueUtc: fields.containsKey('due')
            ? Value(normalizeGoogleDueDateValue(fields['due']))
            : const Value.absent(),
        completedUtc: fields.containsKey('completed')
            ? Value(fields['completed']?.toString())
            : const Value.absent(),
        providerStatus: fields.containsKey('providerStatus')
            ? Value(fields['providerStatus']?.toString())
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

  Future<void> _enqueue({
    required String operation,
    required Map<String, Object?> request,
    required String createdAtUtc,
    String? taskListId,
    String? taskId,
    String? localTempId,
    String? baselineUpdatedUtc,
    String? baselineRawJson,
  }) {
    return _database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: _uuid.v4(),
        accountId: _accountId,
        entityType: 'task',
        operation: operation,
        taskListId: Value(taskListId),
        taskId: Value(taskId),
        localTempId: Value(localTempId),
        requestJson: jsonEncode(request),
        baselineUpdatedUtc: Value(baselineUpdatedUtc),
        baselineRawJson: Value(baselineRawJson),
        createdAtUtc: createdAtUtc,
        updatedAtUtc: createdAtUtc,
      ),
    );
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
    final byParent = groupBy(tasks, (task) => task.parent ?? '');

    List<TaskTreeNode> buildChildren(String parentId) {
      final children = [...byParent[parentId] ?? const <TaskEntity>[]]
        ..sort(_compareTaskOrder);
      return [
        for (final child in children)
          TaskTreeNode(task: child, children: buildChildren(child.id)),
      ];
    }

    return buildChildren('');
  }

  int _compareTaskOrder(TaskEntity left, TaskEntity right) {
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

String _accountLabel(Account account) {
  final name = account.displayName?.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  final address = account.email?.trim();
  if (address != null && address.isNotEmpty) {
    return address;
  }
  return TaskProviderParsing.fromStorageValue(account.provider).displayName;
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
