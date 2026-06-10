import 'dart:convert';

import 'package:http/http.dart' as http;

import 'microsoft_todo_api_error.dart';
import 'microsoft_todo_api_models.dart';
import 'microsoft_todo_json.dart';
import 'microsoft_todo_paths.dart';

abstract interface class MicrosoftTodoApiClient {
  Future<MicrosoftTodoUserDto> getMe();

  Future<MicrosoftTodoTaskListsPageDto> listTaskListsPage({String? nextLink});
  Future<MicrosoftTodoTaskListsDeltaPageDto> deltaTaskLists({
    String? deltaLinkOrNextLink,
  });
  Future<MicrosoftTodoTaskListDto> createTaskList({
    required String displayName,
  });
  Future<MicrosoftTodoTaskListDto> updateTaskList({
    required String taskListId,
    required Map<String, Object?> patch,
  });
  Future<void> deleteTaskList(String taskListId);

  Future<MicrosoftTodoTasksPageDto> listTasksPage({
    required String taskListId,
    String? nextLink,
  });
  Future<MicrosoftTodoTasksDeltaPageDto> deltaTasks({
    required String taskListId,
    String? deltaLinkOrNextLink,
  });
  Future<MicrosoftTodoTaskDto> createTask({
    required String taskListId,
    required Map<String, Object?> body,
  });
  Future<MicrosoftTodoTaskDto> getTask({
    required String taskListId,
    required String taskId,
  });
  Future<MicrosoftTodoTaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> patch,
  });
  Future<void> deleteTask({required String taskListId, required String taskId});
}

class MicrosoftTodoRestApiClient implements MicrosoftTodoApiClient {
  MicrosoftTodoRestApiClient({
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
  Future<MicrosoftTodoUserDto> getMe() async {
    final json = await _requestJson(
      'GET',
      _uri(
        microsoftMePath(),
        query: const {r'$select': 'id,displayName,mail,userPrincipalName'},
      ),
    );
    return MicrosoftTodoUserDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoTaskListsPageDto> listTaskListsPage({
    String? nextLink,
  }) async {
    final json = await _requestJson(
      'GET',
      _uriOrFullUrl(nextLink, microsoftTaskListsPath()),
    );
    return MicrosoftTodoTaskListsPageDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoTaskListsDeltaPageDto> deltaTaskLists({
    String? deltaLinkOrNextLink,
  }) async {
    final json = await _requestJson(
      'GET',
      _uriOrFullUrl(deltaLinkOrNextLink, microsoftTaskListsDeltaPath()),
    );
    return MicrosoftTodoTaskListsDeltaPageDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoTaskListDto> createTaskList({
    required String displayName,
  }) async {
    final json = await _requestJson(
      'POST',
      _uri(microsoftTaskListsPath()),
      body: {'displayName': displayName},
    );
    return MicrosoftTodoTaskListDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoTaskListDto> updateTaskList({
    required String taskListId,
    required Map<String, Object?> patch,
  }) async {
    final json = await _requestJson(
      'PATCH',
      _uri(microsoftTaskListPath(taskListId)),
      body: patch,
    );
    return MicrosoftTodoTaskListDto.fromJson(json);
  }

  @override
  Future<void> deleteTaskList(String taskListId) {
    return _requestEmpty('DELETE', _uri(microsoftTaskListPath(taskListId)));
  }

  @override
  Future<MicrosoftTodoTasksPageDto> listTasksPage({
    required String taskListId,
    String? nextLink,
  }) async {
    final json = await _requestJson(
      'GET',
      _uriOrFullUrl(nextLink, microsoftTasksPath(taskListId)),
    );
    return MicrosoftTodoTasksPageDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoTasksDeltaPageDto> deltaTasks({
    required String taskListId,
    String? deltaLinkOrNextLink,
  }) async {
    final json = await _requestJson(
      'GET',
      _uriOrFullUrl(deltaLinkOrNextLink, microsoftTasksDeltaPath(taskListId)),
    );
    return MicrosoftTodoTasksDeltaPageDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoTaskDto> createTask({
    required String taskListId,
    required Map<String, Object?> body,
  }) async {
    final json = await _requestJson(
      'POST',
      _uri(microsoftTasksPath(taskListId)),
      body: body,
    );
    return MicrosoftTodoTaskDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoTaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    final json = await _requestJson(
      'GET',
      _uri(microsoftTaskPath(taskListId, taskId)),
    );
    return MicrosoftTodoTaskDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoTaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> patch,
  }) async {
    final json = await _requestJson(
      'PATCH',
      _uri(microsoftTaskPath(taskListId, taskId)),
      body: patch,
    );
    return MicrosoftTodoTaskDto.fromJson(json);
  }

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) {
    return _requestEmpty('DELETE', _uri(microsoftTaskPath(taskListId, taskId)));
  }

  Future<void> _requestEmpty(String method, Uri uri) async {
    final response = await _send(method, uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MicrosoftTodoApiError.fromResponse(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }

  Future<Map<String, Object?>> _requestJson(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    final response = await _send(method, uri, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MicrosoftTodoApiError.fromResponse(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    return microsoftJsonObjectFromBody(response.body);
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
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
      _ => throw ArgumentError.value(method, 'method'),
    };
  }

  Uri _uriOrFullUrl(String? fullUrl, String path) {
    if (fullUrl != null && fullUrl.isNotEmpty) {
      return Uri.parse(fullUrl);
    }
    return _uri(path);
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(path: '$basePath$path', queryParameters: query);
  }
}
