import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../calendar_providers/attachment_upload_session.dart';
import '../../core/http/request_dispatch_exception.dart';
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

abstract interface class MicrosoftTodoChecklistApiClient {
  Future<MicrosoftTodoChecklistItemsPageDto> listChecklistItemsPage({
    required String taskListId,
    required String taskId,
    String? nextLink,
  });
  Future<MicrosoftTodoChecklistItemDto> createChecklistItem({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> body,
  });
  Future<MicrosoftTodoChecklistItemDto> updateChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
    required Map<String, Object?> patch,
  });
  Future<void> deleteChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
  });
}

abstract interface class MicrosoftTodoLinkedResourcesApiClient {
  Future<MicrosoftTodoLinkedResourcesPageDto> listLinkedResourcesPage({
    required String taskListId,
    required String taskId,
    String? nextLink,
  });
}

abstract interface class MicrosoftTodoAttachmentsApiClient {
  Future<MicrosoftTodoAttachmentsPageDto> listTaskAttachmentsPage({
    required String taskListId,
    required String taskId,
    String? nextLink,
  });
  Future<List<int>> downloadTaskAttachment({
    required String taskListId,
    required String taskId,
    required String attachmentId,
  });
  Future<MicrosoftTodoAttachmentDto> createSmallTaskAttachment({
    required String taskListId,
    required String taskId,
    required String name,
    required String contentType,
    required List<int> bytes,
  });
  Future<void> deleteTaskAttachment({
    required String taskListId,
    required String taskId,
    required String attachmentId,
  });
  Future<String> uploadTaskFileAttachment({
    required String taskListId,
    required String taskId,
    required String name,
    required String contentType,
    required List<int> bytes,
    MicrosoftAttachmentUploadSession? resumeSession,
    void Function(MicrosoftAttachmentUploadSession)? onSession,
  });
  Future<void> cancelTaskAttachmentUpload(
    MicrosoftAttachmentUploadSession session,
  );
}

class MicrosoftTodoRestApiClient
    implements
        MicrosoftTodoApiClient,
        MicrosoftTodoChecklistApiClient,
        MicrosoftTodoLinkedResourcesApiClient,
        MicrosoftTodoAttachmentsApiClient {
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
  Future<MicrosoftTodoLinkedResourcesPageDto> listLinkedResourcesPage({
    required String taskListId,
    required String taskId,
    String? nextLink,
  }) async {
    final uri = nextLink == null
        ? _uri(microsoftLinkedResourcesPath(taskListId, taskId))
        : _trustedNextLink(nextLink);
    final json = await _requestJson('GET', uri);
    return MicrosoftTodoLinkedResourcesPageDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoAttachmentsPageDto> listTaskAttachmentsPage({
    required String taskListId,
    required String taskId,
    String? nextLink,
  }) async {
    final uri = nextLink == null
        ? _uri(microsoftTaskAttachmentsPath(taskListId, taskId))
        : _trustedNextLink(nextLink);
    return MicrosoftTodoAttachmentsPageDto.fromJson(
      await _requestJson('GET', uri),
    );
  }

  @override
  Future<List<int>> downloadTaskAttachment({
    required String taskListId,
    required String taskId,
    required String attachmentId,
  }) async {
    final response = await _send(
      'GET',
      _uri(
        '${microsoftTaskAttachmentPath(taskListId, taskId, attachmentId)}/\$value',
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MicrosoftTodoApiError.fromResponse(
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<MicrosoftTodoAttachmentDto> createSmallTaskAttachment({
    required String taskListId,
    required String taskId,
    required String name,
    required String contentType,
    required List<int> bytes,
  }) async {
    if (name.trim().isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        bytes.length >= 3 * 1024 * 1024) {
      throw ArgumentError(
        'Invalid name or file exceeds the direct-upload limit.',
      );
    }
    return MicrosoftTodoAttachmentDto.fromJson(
      await _requestJson(
        'POST',
        _uri(microsoftTaskAttachmentsPath(taskListId, taskId)),
        body: {
          '@odata.type': '#microsoft.graph.taskFileAttachment',
          'name': name,
          'contentType': contentType,
          'size': bytes.length,
          'contentBytes': base64Encode(bytes),
        },
      ),
    );
  }

  @override
  Future<void> deleteTaskAttachment({
    required String taskListId,
    required String taskId,
    required String attachmentId,
  }) => _requestEmpty(
    'DELETE',
    _uri(microsoftTaskAttachmentPath(taskListId, taskId, attachmentId)),
  );

  @override
  Future<String> uploadTaskFileAttachment({
    required String taskListId,
    required String taskId,
    required String name,
    required String contentType,
    required List<int> bytes,
    MicrosoftAttachmentUploadSession? resumeSession,
    void Function(MicrosoftAttachmentUploadSession)? onSession,
  }) async {
    if (name.trim().isEmpty || name.contains('/') || name.contains('\\')) {
      throw ArgumentError.value(name, 'name', 'Invalid attachment name.');
    }
    if (bytes.length > 25 * 1024 * 1024) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'Task file exceeds 25 MB.',
      );
    }
    if (bytes.length < 3 * 1024 * 1024 && resumeSession == null) {
      final created = await createSmallTaskAttachment(
        taskListId: taskListId,
        taskId: taskId,
        name: name,
        contentType: contentType,
        bytes: bytes,
      );
      if (created.id.isEmpty) {
        throw const MicrosoftAttachmentUploadUncertain();
      }
      return created.id;
    }
    MicrosoftAttachmentUploadSession session;
    if (resumeSession == null) {
      final created = await _requestJson(
        'POST',
        _uri(
          '${microsoftTaskAttachmentsPath(taskListId, taskId)}/createUploadSession',
        ),
        body: {
          'attachmentInfo': {
            'attachmentType': 'file',
            'name': name,
            'size': bytes.length,
          },
        },
      );
      final uploadUrl = created['uploadUrl']?.toString();
      if (uploadUrl == null) {
        throw const FormatException('Task attachment upload URL is missing.');
      }
      session = MicrosoftAttachmentUploadSession(
        url: _trustedNextLink(uploadUrl),
        expiresAt: null,
        nextOffset: 0,
      );
      session.update(created, bytes.length);
      onSession?.call(session);
    } else {
      session = resumeSession;
      try {
        session.update(await _requestJson('GET', session.url), bytes.length);
      } on Object {
        throw const MicrosoftAttachmentUploadUncertain();
      }
    }
    if (session.expiresAt case final expiry?) {
      if (!expiry.isAfter(DateTime.now().toUtc())) {
        throw const MicrosoftAttachmentUploadUncertain();
      }
    }
    // Task sessions are Graph-authenticated, unlike pre-authenticated Outlook
    // event sessions. Never send a bearer token to a non-Graph authority.
    final contentUri = session.url.replace(path: '${session.url.path}/content');
    var offset = session.nextOffset;
    if (offset == bytes.length) {
      throw const MicrosoftAttachmentUploadUncertain();
    }
    const chunkSize = 2 * 1024 * 1024;
    while (offset < bytes.length) {
      final end = offset + chunkSize < bytes.length
          ? offset + chunkSize
          : bytes.length;
      try {
        if (end == bytes.length) {
          session.finalRangeMayHaveBeenSubmitted = true;
        }
        final authorization = await _authorizationHeaderProvider?.call();
        final response = await _httpClient.put(
          contentUri,
          headers: {
            if (authorization != null) 'Authorization': authorization,
            'Content-Type': 'application/octet-stream',
            'Content-Length': '${end - offset}',
            'Content-Range': 'bytes $offset-${end - 1}/${bytes.length}',
          },
          body: bytes.sublist(offset, end),
        );
        if (end == bytes.length) {
          if (response.statusCode != 201) {
            throw const MicrosoftAttachmentUploadUncertain();
          }
          return attachmentIdFromUploadHeaders(response.headers);
        }
        if (response.statusCode != 200) {
          throw const MicrosoftAttachmentUploadUncertain();
        }
        session.update(
          (jsonDecode(response.body) as Map).cast<String, Object?>(),
          bytes.length,
        );
        if (session.nextOffset <= offset) {
          throw const MicrosoftAttachmentUploadUncertain();
        }
      } on Object {
        throw const MicrosoftAttachmentUploadUncertain();
      }
      offset = session.nextOffset;
    }
    throw const MicrosoftAttachmentUploadUncertain();
  }

  @override
  Future<void> cancelTaskAttachmentUpload(
    MicrosoftAttachmentUploadSession session,
  ) async {
    try {
      final response = await _send('DELETE', session.url);
      if (response.statusCode != 204) {
        throw const MicrosoftAttachmentUploadUncertain();
      }
    } on Object {
      throw const MicrosoftAttachmentUploadUncertain();
    }
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

  @override
  Future<MicrosoftTodoChecklistItemsPageDto> listChecklistItemsPage({
    required String taskListId,
    required String taskId,
    String? nextLink,
  }) async {
    final json = await _requestJson(
      'GET',
      _uriOrFullUrl(nextLink, microsoftChecklistItemsPath(taskListId, taskId)),
    );
    return MicrosoftTodoChecklistItemsPageDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoChecklistItemDto> createChecklistItem({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> body,
  }) async {
    final json = await _requestJson(
      'POST',
      _uri(microsoftChecklistItemsPath(taskListId, taskId)),
      body: body,
    );
    return MicrosoftTodoChecklistItemDto.fromJson(json);
  }

  @override
  Future<MicrosoftTodoChecklistItemDto> updateChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
    required Map<String, Object?> patch,
  }) async {
    final json = await _requestJson(
      'PATCH',
      _uri(microsoftChecklistItemPath(taskListId, taskId, checklistItemId)),
      body: patch,
    );
    return MicrosoftTodoChecklistItemDto.fromJson(json);
  }

  @override
  Future<void> deleteChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
  }) {
    return _requestEmpty(
      'DELETE',
      _uri(microsoftChecklistItemPath(taskListId, taskId, checklistItemId)),
    );
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
      try {
        await refresh();
      } on Object catch (error, stackTrace) {
        Error.throwWithStackTrace(
          KnownUnsentRequestException(
            kind: RequestPreDispatchFailureKind.authentication,
            cause: error,
          ),
          stackTrace,
        );
      }
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
    String? authorizationHeader;
    try {
      authorizationHeader = await _authorizationHeaderProvider?.call();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        KnownUnsentRequestException(
          kind: RequestPreDispatchFailureKind.authentication,
          cause: error,
        ),
        stackTrace,
      );
    }
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

  Uri _trustedNextLink(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != _baseUri.scheme ||
        uri.host != _baseUri.host ||
        uri.port != _baseUri.port ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith(
          _baseUri.path.endsWith('/') ? _baseUri.path : '${_baseUri.path}/',
        )) {
      throw FormatException('Untrusted Microsoft Graph continuation URL.');
    }
    return uri;
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(path: '$basePath$path', queryParameters: query);
  }
}
