import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';
import 'package:busymax/src/core/http/request_dispatch_exception.dart';

void main() {
  test(
    'task attachments use task-scoped metadata, content and mutation endpoints',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) {
        requests.add(request);
        if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        if (request.url.path.endsWith(r'/$value')) {
          return http.Response.bytes([1, 2], 200);
        }
        if (request.method == 'POST') {
          return _json({
            'id': 'file-1',
            'name': 'notes.txt',
            '@odata.type': '#microsoft.graph.taskFileAttachment',
          });
        }
        return _json({
          'value': [
            {
              'id': 'file-1',
              'name': 'notes.txt',
              '@odata.type': '#microsoft.graph.taskFileAttachment',
              'size': 2,
            },
          ],
        });
      });
      final page = await client.listTaskAttachmentsPage(
        taskListId: 'list',
        taskId: 'task',
      );
      expect(page.attachments.single.isFile, isTrue);
      expect(
        await client.downloadTaskAttachment(
          taskListId: 'list',
          taskId: 'task',
          attachmentId: 'file-1',
        ),
        [1, 2],
      );
      await client.createSmallTaskAttachment(
        taskListId: 'list',
        taskId: 'task',
        name: 'notes.txt',
        contentType: 'text/plain',
        bytes: [1, 2],
      );
      await client.deleteTaskAttachment(
        taskListId: 'list',
        taskId: 'task',
        attachmentId: 'file-1',
      );
      expect(requests.map((request) => request.method), [
        'GET',
        'GET',
        'POST',
        'DELETE',
      ]);
      expect(
        requests[0].url.path,
        '/v1.0/me/todo/lists/list/tasks/task/attachments',
      );
      expect(
        requests[1].url.path,
        r'/v1.0/me/todo/lists/list/tasks/task/attachments/file-1/$value',
      );
      expect(jsonDecode(requests[2].body), {
        '@odata.type': '#microsoft.graph.taskFileAttachment',
        'name': 'notes.txt',
        'contentType': 'text/plain',
        'size': 2,
        'contentBytes': 'AQI=',
      });
      expect(
        requests[3].url.path,
        '/v1.0/me/todo/lists/list/tasks/task/attachments/file-1',
      );
    },
  );

  test(
    'task attachment continuation rejects another host and invalid uploads',
    () async {
      var requests = 0;
      final client = _client((request) {
        requests++;
        return _json({'value': []});
      });
      await expectLater(
        client.listTaskAttachmentsPage(
          taskListId: 'list',
          taskId: 'task',
          nextLink: 'https://attacker.test/steal',
        ),
        throwsFormatException,
      );
      await expectLater(
        client.createSmallTaskAttachment(
          taskListId: 'list',
          taskId: 'task',
          name: '../escape',
          contentType: 'text/plain',
          bytes: [1],
        ),
        throwsArgumentError,
      );
      expect(requests, 0);
    },
  );

  test('linked resources use task-scoped endpoint and safe pagination', () async {
    final requests = <http.Request>[];
    final client = _client((request) {
      requests.add(request);
      return _json({
        'value': [
          {
            'id': 'resource-1',
            'applicationName': 'Planner',
            'displayName': 'Project',
            'webUrl': 'https://example.test/project',
          },
        ],
        '@odata.nextLink':
            'https://graph.microsoft.com/v1.0/me/todo/lists/list-1/tasks/task-1/linkedResources?\$skiptoken=next',
      });
    });
    final first = await client.listLinkedResourcesPage(
      taskListId: 'list-1',
      taskId: 'task-1',
    );
    expect(first.resources.single.displayName, 'Project');
    expect(first.resources.single.applicationName, 'Planner');
    expect(
      requests.single.url.path,
      '/v1.0/me/todo/lists/list-1/tasks/task-1/linkedResources',
    );
    await client.listLinkedResourcesPage(
      taskListId: 'list-1',
      taskId: 'task-1',
      nextLink: first.nextLink,
    );
    expect(requests, hasLength(2));
    await expectLater(
      client.listLinkedResourcesPage(
        taskListId: 'list-1',
        taskId: 'task-1',
        nextLink: 'https://attacker.test/steal',
      ),
      throwsFormatException,
    );
    expect(requests, hasLength(2));
  });

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

  test('checklist methods use the task child endpoints and bodies', () async {
    final requests = <http.Request>[];
    final client = _client((request) {
      requests.add(request);
      if (request.method == 'DELETE') return http.Response('', 204);
      if (request.method == 'GET') {
        return _json({
          'value': [
            {'id': 'step-1', 'displayName': 'Step', 'isChecked': false},
          ],
        });
      }
      return _json({
        'id': 'step-1',
        ...jsonDecode(request.body) as Map<String, Object?>,
      });
    });

    await client.listChecklistItemsPage(taskListId: 'list-1', taskId: 'task-1');
    await client.createChecklistItem(
      taskListId: 'list-1',
      taskId: 'task-1',
      body: {'displayName': 'Step'},
    );
    await client.updateChecklistItem(
      taskListId: 'list-1',
      taskId: 'task-1',
      checklistItemId: 'step-1',
      patch: {'isChecked': true},
    );
    await client.deleteChecklistItem(
      taskListId: 'list-1',
      taskId: 'task-1',
      checklistItemId: 'step-1',
    );

    const path = '/v1.0/me/todo/lists/list-1/tasks/task-1/checklistItems';
    expect(requests[0].method, 'GET');
    expect(requests[0].url.path, path);
    expect(requests[1].method, 'POST');
    expect(requests[1].url.path, path);
    expect(jsonDecode(requests[1].body), {'displayName': 'Step'});
    expect(requests[2].method, 'PATCH');
    expect(requests[2].url.path, '$path/step-1');
    expect(jsonDecode(requests[2].body), {'isChecked': true});
    expect(requests[3].method, 'DELETE');
    expect(requests[3].url.path, '$path/step-1');
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

  test(
    '401 followed by refresh failure is known safe before retry dispatch',
    () async {
      var calls = 0;
      final client = MicrosoftTodoRestApiClient(
        httpClient: MockClient((_) async {
          calls += 1;
          return http.Response('unauthorized', 401);
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        authorizationHeaderProvider: () async => 'Bearer token',
        unauthorizedRefreshProvider: () async => throw StateError('signed out'),
      );

      await expectLater(
        client.createTaskList(displayName: 'Inbox'),
        throwsA(
          isA<RequestNotDispatchedException>().having(
            (error) => error.kind,
            'kind',
            RequestPreDispatchFailureKind.authentication,
          ),
        ),
      );
      expect(calls, 1);
    },
  );
}

MicrosoftTodoRestApiClient _client(
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
