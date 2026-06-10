import 'dart:convert';

import 'package:http/http.dart' as http;

import 'google_tasks_api_error.dart';
import 'google_tasks_api_models.dart';
import 'google_tasks_api_paths.dart';
import 'google_tasks_json.dart';

abstract interface class GoogleTasksApiClient {
  Future<void> deleteTaskList(String taskListId);
  Future<TaskListDto> getTaskList(String taskListId);
  Future<TaskListDto> createTaskList({required String title});
  Future<TaskListsPageDto> listTaskListsPage({
    int maxResults = 1000,
    String? pageToken,
  });
  Future<TaskListDto> patchTaskList(String taskListId, TaskListPatch patch);
  Future<TaskListDto> updateTaskList(
    String taskListId,
    TaskListPut replacement,
  );

  Future<void> clearCompletedTasks(String taskListId);
  Future<void> deleteTask({required String taskListId, required String taskId});
  Future<TaskDto> getTask({required String taskListId, required String taskId});
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  });
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
  });
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  });
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  });
  Future<TaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required TaskPut replacement,
  });
}

class GoogleTasksRestApiClient implements GoogleTasksApiClient {
  GoogleTasksRestApiClient({
    required http.Client httpClient,
    required Uri baseUri,
    Future<String> Function()? authorizationHeaderProvider,
    Future<void> Function()? unauthorizedRefreshProvider,
  }) : _httpClient = httpClient,
       _baseUri = baseUri,
       _authorizationHeaderProvider = authorizationHeaderProvider,
       _unauthorizedRefreshProvider = unauthorizedRefreshProvider;

  final http.Client _httpClient;
  final Uri _baseUri;
  final Future<String> Function()? _authorizationHeaderProvider;
  final Future<void> Function()? _unauthorizedRefreshProvider;

  @override
  Future<void> deleteTaskList(String taskListId) {
    return _requestEmpty('DELETE', taskListPath(taskListId));
  }

  @override
  Future<TaskListDto> getTaskList(String taskListId) async {
    final json = await _requestJson('GET', taskListPath(taskListId));
    return TaskListDto.fromJson(json);
  }

  @override
  Future<TaskListDto> createTaskList({required String title}) async {
    final json = await _requestJson(
      'POST',
      taskListsPath(),
      body: TaskListPatch.title(title).toJson(),
    );
    return TaskListDto.fromJson(json);
  }

  @override
  Future<TaskListsPageDto> listTaskListsPage({
    int maxResults = 1000,
    String? pageToken,
  }) async {
    final json = await _requestJson(
      'GET',
      taskListsPath(),
      query: compactQuery({
        'maxResults': intQuery(maxResults.clamp(1, 1000).toInt()),
        'pageToken': pageToken,
      }),
    );
    return TaskListsPageDto.fromJson(json);
  }

  @override
  Future<TaskListDto> patchTaskList(
    String taskListId,
    TaskListPatch patch,
  ) async {
    final json = await _requestJson(
      'PATCH',
      taskListPath(taskListId),
      body: patch.toJson(),
    );
    return TaskListDto.fromJson(json);
  }

  @override
  Future<TaskListDto> updateTaskList(
    String taskListId,
    TaskListPut replacement,
  ) async {
    final json = await _requestJson(
      'PUT',
      taskListPath(taskListId),
      body: replacement.toJson(),
    );
    return TaskListDto.fromJson(json);
  }

  @override
  Future<void> clearCompletedTasks(String taskListId) {
    return _requestEmpty('POST', tasksClearPath(taskListId));
  }

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) {
    return _requestEmpty('DELETE', taskPath(taskListId, taskId));
  }

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    final json = await _requestJson('GET', taskPath(taskListId, taskId));
    return TaskDto.fromJson(json);
  }

  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    final json = await _requestJson(
      'POST',
      tasksPath(taskListId),
      query: compactQuery({
        'parent': parentTaskId,
        'previous': previousSiblingTaskId,
      }),
      body: create.toJson(),
    );
    return TaskDto.fromJson(json);
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
    final json = await _requestJson(
      'GET',
      tasksPath(taskListId),
      query: compactQuery({
        'completedMax': dateTimeQuery(completedMax),
        'completedMin': dateTimeQuery(completedMin),
        'dueMax': dateTimeQuery(dueMax),
        'dueMin': dateTimeQuery(dueMin),
        'maxResults': intQuery(maxResults.clamp(1, 100).toInt()),
        'pageToken': pageToken,
        'showCompleted': boolQuery(showCompleted),
        'showDeleted': boolQuery(showDeleted),
        'showHidden': boolQuery(showHidden),
        'updatedMin': dateTimeQuery(updatedMin),
        'showAssigned': boolQuery(showAssigned),
      }),
    );
    return TasksPageDto.fromJson(json);
  }

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) async {
    final json = await _requestJson(
      'POST',
      taskMovePath(sourceTaskListId, taskId),
      query: compactQuery({
        'parent': parentTaskId,
        'previous': previousSiblingTaskId,
        'destinationTasklist': destinationTaskListId,
      }),
    );
    return TaskDto.fromJson(json);
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    final json = await _requestJson(
      'PATCH',
      taskPath(taskListId, taskId),
      body: patch.toJson(),
    );
    return TaskDto.fromJson(json);
  }

  @override
  Future<TaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required TaskPut replacement,
  }) async {
    final json = await _requestJson(
      'PUT',
      taskPath(taskListId, taskId),
      body: replacement.toJson(),
    );
    return TaskDto.fromJson(json);
  }

  Future<void> _requestEmpty(
    String method,
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _send(method, path, query: query);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleTasksApiError.fromResponse(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  Future<Map<String, Object?>> _requestJson(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final response = await _send(method, path, query: query, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleTasksApiError.fromResponse(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    return jsonObjectFromBody(response.body);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final uri = _baseUri.replace(path: path, queryParameters: query);
    final encodedBody = body == null ? null : jsonEncode(body);
    var response = await _sendOnce(
      method,
      uri,
      body: body,
      encodedBody: encodedBody,
    );
    final refresh = _unauthorizedRefreshProvider;
    if (response.statusCode == 401 && refresh != null) {
      await refresh();
      response = await _sendOnce(
        method,
        uri,
        body: body,
        encodedBody: encodedBody,
      );
    }
    return response;
  }

  Future<http.Response> _sendOnce(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    String? encodedBody,
  }) async {
    final headers = <String, String>{};
    if (body != null) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    final authorizationHeader = await _authorizationHeaderProvider?.call();
    if (authorizationHeader != null) {
      headers['Authorization'] = authorizationHeader;
    }

    return switch (method) {
      'DELETE' => _httpClient.delete(uri, headers: headers),
      'GET' => _httpClient.get(uri, headers: headers),
      'PATCH' => _httpClient.patch(uri, headers: headers, body: encodedBody),
      'POST' => _httpClient.post(uri, headers: headers, body: encodedBody),
      'PUT' => _httpClient.put(uri, headers: headers, body: encodedBody),
      _ => throw ArgumentError.value(method, 'method'),
    };
  }
}
