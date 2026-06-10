import '../../google_tasks/api/google_tasks_api_client.dart';
import '../../google_tasks/api/google_tasks_api_error.dart';
import '../../google_tasks/api/google_tasks_api_models.dart';
import 'microsoft_todo_api_client.dart';
import 'microsoft_todo_api_error.dart';
import 'microsoft_todo_api_models.dart';

class MicrosoftTodoGoogleTasksAdapter implements GoogleTasksApiClient {
  MicrosoftTodoGoogleTasksAdapter({
    required MicrosoftTodoApiClient client,
    required String defaultTimeZone,
    DateTime Function()? nowUtc,
  }) : _client = client,
       _defaultTimeZone = defaultTimeZone,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final MicrosoftTodoApiClient _client;
  final String _defaultTimeZone;
  final DateTime Function() _nowUtc;

  @override
  Future<TaskListDto> createTaskList({required String title}) async {
    final dto = await _client.createTaskList(displayName: title);
    return _taskListDto(dto);
  }

  @override
  Future<void> deleteTaskList(String taskListId) {
    return _client.deleteTaskList(taskListId);
  }

  @override
  Future<TaskListDto> getTaskList(String taskListId) async {
    var nextLink = null as String?;
    do {
      final page = await _client.listTaskListsPage(nextLink: nextLink);
      for (final item in page.items) {
        if (item.id == taskListId) {
          return _taskListDto(item);
        }
      }
      nextLink = page.nextLink;
    } while (nextLink != null && nextLink.isNotEmpty);

    throw const GoogleTasksApiError(
      statusCode: 404,
      code: 'not_found',
      message: 'Microsoft To Do task list was not found.',
    );
  }

  @override
  Future<TaskListsPageDto> listTaskListsPage({
    int maxResults = 1000,
    String? pageToken,
  }) async {
    final page = await _client.listTaskListsPage(nextLink: pageToken);
    return TaskListsPageDto(
      items: page.items.map(_taskListDto).toList(),
      nextPageToken: page.nextLink,
      rawJson: page.rawJson,
    );
  }

  @override
  Future<TaskListDto> patchTaskList(String taskListId, TaskListPatch patch) {
    return _updateTaskList(taskListId, patch.fields);
  }

  @override
  Future<TaskListDto> updateTaskList(
    String taskListId,
    TaskListPut replacement,
  ) {
    return _updateTaskList(taskListId, replacement.fields);
  }

  Future<TaskListDto> _updateTaskList(
    String taskListId,
    Map<String, Object?> fields,
  ) async {
    final dto = await _client.updateTaskList(
      taskListId: taskListId,
      patch: {
        if (fields.containsKey('title')) 'displayName': fields['title'],
        if (fields.containsKey('displayName'))
          'displayName': fields['displayName'],
      },
    );
    return _taskListDto(dto);
  }

  @override
  Future<void> clearCompletedTasks(String taskListId) {
    throw const GoogleTasksApiError(
      statusCode: 400,
      code: 'unsupported_provider_operation',
      message: 'Clear completed is not supported for Microsoft To Do accounts.',
    );
  }

  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    if (parentTaskId != null || previousSiblingTaskId != null) {
      throw const GoogleTasksApiError(
        statusCode: 400,
        code: 'unsupported_provider_operation',
        message:
            'Nested tasks are not supported by Microsoft To Do sync in this version.',
      );
    }
    final dto = await _client.createTask(
      taskListId: taskListId,
      body: _microsoftTaskPatch(create.fields),
    );
    return _taskDto(dto);
  }

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) {
    return _client.deleteTask(taskListId: taskListId, taskId: taskId);
  }

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    final dto = await _client.getTask(taskListId: taskListId, taskId: taskId);
    return _taskDto(dto);
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
    final page = await _client.listTasksPage(
      taskListId: taskListId,
      nextLink: pageToken,
    );
    return TasksPageDto(
      items: page.items.map(_taskDto).toList(),
      nextPageToken: page.nextLink,
      rawJson: page.rawJson,
    );
  }

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) {
    throw const GoogleTasksApiError(
      statusCode: 400,
      code: 'unsupported_provider_operation',
      message:
          'Moving Microsoft To Do tasks between lists is not supported in this version.',
    );
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) {
    return _updateTask(taskListId, taskId, patch.fields);
  }

  @override
  Future<TaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required TaskPut replacement,
  }) {
    return _updateTask(taskListId, taskId, replacement.fields);
  }

  Future<TaskDto> _updateTask(
    String taskListId,
    String taskId,
    Map<String, Object?> fields,
  ) async {
    final patch = _microsoftTaskPatch(fields);
    try {
      final dto = await _client.updateTask(
        taskListId: taskListId,
        taskId: taskId,
        patch: patch,
      );
      return _taskDto(dto);
    } on MicrosoftTodoApiError catch (error) {
      if (error.statusCode == 400 &&
          patch['completedDateTime'] == null &&
          patch.containsKey('completedDateTime')) {
        final retryPatch = Map<String, Object?>.from(patch)
          ..remove('completedDateTime');
        final dto = await _client.updateTask(
          taskListId: taskListId,
          taskId: taskId,
          patch: retryPatch,
        );
        return _taskDto(dto);
      }
      rethrow;
    }
  }

  Map<String, Object?> _microsoftTaskPatch(Map<String, Object?> fields) {
    final patch = <String, Object?>{};
    if (fields.containsKey('title')) {
      patch['title'] = fields['title'];
    }
    if (fields.containsKey('notes')) {
      patch['body'] = {
        'content': _plainTextToHtml(fields['notes']?.toString() ?? ''),
        'contentType': 'html',
      };
    }
    if (fields.containsKey('status')) {
      final status = fields['status']?.toString();
      if (status == 'completed') {
        patch['status'] = 'completed';
        patch['completedDateTime'] =
            fields['microsoftCompletedDateTime'] ??
            _completedFieldDateTime(fields['completed']) ??
            _dateTimeTimeZone(_localNowDateTime());
      } else {
        patch['status'] = 'notStarted';
        patch['completedDateTime'] = null;
      }
    }
    if (fields.containsKey('due')) {
      final due = fields['due'];
      patch['dueDateTime'] = due == null ? null : _dateOnlyToDateTime(due);
    }
    if (fields.containsKey('microsoftDueDateTime')) {
      patch['dueDateTime'] = fields['microsoftDueDateTime'];
    }
    if (fields.containsKey('microsoftStartDateTime')) {
      patch['startDateTime'] = fields['microsoftStartDateTime'];
    }
    if (fields.containsKey('microsoftReminderDateTime')) {
      patch['reminderDateTime'] = fields['microsoftReminderDateTime'];
    }
    if (fields.containsKey('microsoftCompletedDateTime')) {
      patch['completedDateTime'] = fields['microsoftCompletedDateTime'];
    }
    if (fields.containsKey('microsoftIsReminderOn')) {
      patch['isReminderOn'] = fields['microsoftIsReminderOn'];
    }
    if (fields.containsKey('recurrence')) {
      patch['recurrence'] = fields['recurrence'];
    }
    if (fields.containsKey('importance')) {
      patch['importance'] = fields['importance'];
    }
    if (fields.containsKey('categories')) {
      patch['categories'] = fields['categories'];
    }
    return patch;
  }

  Map<String, Object?> _dateOnlyToDateTime(Object value) {
    final text = value.toString();
    final date = text.length >= 10 ? text.substring(0, 10) : text;
    return {'dateTime': '${date}T00:00:00', 'timeZone': _defaultTimeZone};
  }

  Map<String, Object?> _dateTimeTimeZone(String value) {
    return {'dateTime': value, 'timeZone': _defaultTimeZone};
  }

  Map<String, Object?>? _completedFieldDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    return _dateTimeTimeZone(value.toString());
  }

  String _localNowDateTime() {
    final now = _nowUtc().toLocal();
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    return '${date}T$time';
  }
}

TaskListDto _taskListDto(MicrosoftTodoTaskListDto dto) {
  return TaskListDto(
    id: dto.id,
    title: dto.displayName ?? '',
    rawJson: dto.rawJson,
    kind: '#microsoft.graph.todoTaskList',
  );
}

TaskDto _taskDto(MicrosoftTodoTaskDto dto) {
  return TaskDto(
    id: dto.id,
    etag: dto.etag,
    title: dto.title ?? '',
    updated: _parseUtc(dto.lastModifiedDateTime),
    notes: _htmlToPlainText(dto.body?.content ?? ''),
    status: dto.status == 'completed' ? 'completed' : 'needsAction',
    completed: null,
    due: null,
    deleted: dto.removed ? true : null,
    hidden: false,
    rawJson: dto.rawJson,
    kind: '#microsoft.graph.todoTask',
  );
}

DateTime? _parseUtc(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

String _plainTextToHtml(String value) {
  return _htmlEscape(value).replaceAll('\n', '<br>');
}

String _htmlToPlainText(String value) {
  return value
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .trim();
}

String _htmlEscape(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
