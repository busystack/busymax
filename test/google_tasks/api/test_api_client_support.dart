import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:busymax/src/google_tasks/api/google_tasks_api_client.dart';

class RecordedRequest {
  const RecordedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;
}

class RecordingClient extends http.BaseClient {
  RecordingClient(this.responseBody, {this.statusCode = 200});

  final Object? responseBody;
  final int statusCode;
  final requests = <RecordedRequest>[];

  RecordedRequest get singleRequest {
    if (requests.length != 1) {
      throw StateError('Expected one request, found ${requests.length}.');
    }
    return requests.single;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().bytesToString();
    requests.add(
      RecordedRequest(
        method: request.method,
        url: request.url,
        headers: Map.unmodifiable(request.headers),
        body: body,
      ),
    );

    final encoded = responseBody is String
        ? responseBody! as String
        : jsonEncode(responseBody ?? <String, Object?>{});
    return http.StreamedResponse(
      Stream.value(utf8.encode(encoded)),
      statusCode,
      headers: {'Content-Type': 'application/json'},
    );
  }
}

GoogleTasksRestApiClient newTestApiClient(RecordingClient httpClient) {
  return GoogleTasksRestApiClient(
    httpClient: httpClient,
    baseUri: Uri.parse('https://tasks.googleapis.com'),
    authorizationHeaderProvider: () async => 'Bearer test-token',
  );
}

Map<String, Object?> taskListJson({String id = 'list-1'}) {
  return {
    'kind': 'tasks#taskList',
    'id': id,
    'etag': 'etag-list',
    'title': 'List',
    'updated': '2026-06-04T00:00:00.000Z',
    'selfLink': 'https://example.test/list',
    'unknown': 'preserved',
  };
}

Map<String, Object?> taskJson({String id = 'task-1'}) {
  return {
    'kind': 'tasks#task',
    'id': id,
    'etag': 'etag-task',
    'title': 'Task',
    'updated': '2026-06-04T00:00:00.000Z',
    'selfLink': 'https://example.test/task',
    'parent': 'parent-1',
    'position': '0001',
    'notes': 'Notes',
    'status': 'needsAction',
    'due': '2026-06-05T00:00:00.000Z',
    'completed': '2026-06-06T00:00:00.000Z',
    'deleted': false,
    'hidden': false,
    'links': [
      {
        'type': 'email',
        'description': 'Related message',
        'link': 'https://example.test/mail',
      },
    ],
    'webViewLink': 'https://tasks.google.com/task',
    'assignmentInfo': {'surfaceType': 'DOCUMENT'},
    'unknown': 'preserved',
  };
}

void expectBearer(RecordedRequest request) {
  if (request.headers['Authorization'] != 'Bearer test-token') {
    throw StateError('Missing Authorization header.');
  }
}
