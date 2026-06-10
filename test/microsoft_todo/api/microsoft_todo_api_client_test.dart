import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';

void main() {
  test('list lists sends GET /me/todo/lists', () async {
    late http.Request captured;
    final client = _client((request) {
      captured = request;
      return _json({'value': []});
    });

    await client.listTaskListsPage();

    expect(captured.method, 'GET');
    expect(
      captured.url.toString(),
      'https://graph.microsoft.com/v1.0/me/todo/lists',
    );
  });

  test('create, update, and delete list use documented endpoints', () async {
    final requests = <http.Request>[];
    final client = _client((request) {
      requests.add(request);
      if (request.method == 'DELETE') {
        return http.Response('', 204);
      }
      return _json({'id': 'list-1', 'displayName': 'Inbox'});
    });

    await client.createTaskList(displayName: 'Inbox');
    await client.updateTaskList(
      taskListId: 'list-1',
      patch: {'displayName': 'Renamed'},
    );
    await client.deleteTaskList('list-1');

    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, '/v1.0/me/todo/lists');
    expect(jsonDecode(requests[0].body), {'displayName': 'Inbox'});
    expect(requests[1].method, 'PATCH');
    expect(requests[1].url.path, '/v1.0/me/todo/lists/list-1');
    expect(jsonDecode(requests[1].body), {'displayName': 'Renamed'});
    expect(requests[2].method, 'DELETE');
    expect(requests[2].url.path, '/v1.0/me/todo/lists/list-1');
  });

  test('task methods use documented endpoints and bodies', () async {
    final requests = <http.Request>[];
    final client = _client((request) {
      requests.add(request);
      if (request.method == 'DELETE') {
        return http.Response('', 204);
      }
      if (request.method == 'GET') {
        return _json({'value': []});
      }
      return _json({'id': 'task-1', 'title': 'Task'});
    });

    await client.listTasksPage(taskListId: 'list-1');
    await client.createTask(taskListId: 'list-1', body: {'title': 'Task'});
    await client.updateTask(
      taskListId: 'list-1',
      taskId: 'task-1',
      patch: {'importance': 'high'},
    );
    await client.deleteTask(taskListId: 'list-1', taskId: 'task-1');

    expect(requests[0].method, 'GET');
    expect(requests[0].url.path, '/v1.0/me/todo/lists/list-1/tasks');
    expect(requests[1].method, 'POST');
    expect(requests[1].url.path, '/v1.0/me/todo/lists/list-1/tasks');
    expect(jsonDecode(requests[1].body), {'title': 'Task'});
    expect(requests[2].method, 'PATCH');
    expect(requests[2].url.path, '/v1.0/me/todo/lists/list-1/tasks/task-1');
    expect(jsonDecode(requests[2].body), {'importance': 'high'});
    expect(requests[3].method, 'DELETE');
    expect(requests[3].url.path, '/v1.0/me/todo/lists/list-1/tasks/task-1');
  });

  test('delta and paging use full stored URLs unchanged', () async {
    final urls = <String>[];
    final client = _client((request) {
      urls.add(request.url.toString());
      return _json({
        '@odata.nextLink': 'https://graph.microsoft.com/v1.0/next',
        '@odata.deltaLink': 'https://graph.microsoft.com/v1.0/delta',
        'value': [],
      });
    });

    await client.deltaTaskLists(
      deltaLinkOrNextLink: 'https://graph.microsoft.com/v1.0/list-delta',
    );
    await client.deltaTasks(
      taskListId: 'list-1',
      deltaLinkOrNextLink: 'https://graph.microsoft.com/v1.0/task-delta',
    );
    await client.listTaskListsPage(
      nextLink: 'https://graph.microsoft.com/v1.0/list-next',
    );
    await client.listTasksPage(
      taskListId: 'list-1',
      nextLink: 'https://graph.microsoft.com/v1.0/task-next',
    );

    expect(urls, [
      'https://graph.microsoft.com/v1.0/list-delta',
      'https://graph.microsoft.com/v1.0/task-delta',
      'https://graph.microsoft.com/v1.0/list-next',
      'https://graph.microsoft.com/v1.0/task-next',
    ]);
  });

  test('401 refreshes authorization and retries once', () async {
    var calls = 0;
    var refreshes = 0;
    final headers = <String?>[];
    final client = MicrosoftTodoRestApiClient(
      httpClient: MockClient((request) async {
        calls += 1;
        headers.add(request.headers['Authorization']);
        if (calls == 1) {
          return http.Response('unauthorized', 401);
        }
        return _json({'value': []});
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      authorizationHeaderProvider: () async =>
          refreshes == 0 ? 'Bearer old-token' : 'Bearer new-token',
      unauthorizedRefreshProvider: () async {
        refreshes += 1;
      },
    );

    await client.listTaskListsPage();

    expect(calls, 2);
    expect(refreshes, 1);
    expect(headers, ['Bearer old-token', 'Bearer new-token']);
  });
}

MicrosoftTodoApiClient _client(
  http.Response Function(http.Request request) handler,
) {
  return MicrosoftTodoRestApiClient(
    httpClient: MockClient((request) async => handler(request)),
    baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
    authorizationHeaderProvider: () async => 'Bearer token',
  );
}

http.Response _json(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'Content-Type': 'application/json'},
  );
}
