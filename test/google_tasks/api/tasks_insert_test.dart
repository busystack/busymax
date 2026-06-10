import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasks.insert sends exact query and body', () async {
    final httpClient = RecordingClient(taskJson());
    final client = newTestApiClient(httpClient);

    await client.createTask(
      taskListId: 'list-1',
      parentTaskId: 'parent-1',
      previousSiblingTaskId: 'previous-1',
      create: TaskCreate(
        title: 'Task',
        notes: 'Notes',
        status: 'needsAction',
        due: DateTime.utc(2026, 6, 5, 13, 30),
      ),
    );

    final request = httpClient.singleRequest;
    expect(request.method, 'POST');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/lists/list-1/tasks');
    expect(request.url.queryParameters, {
      'parent': 'parent-1',
      'previous': 'previous-1',
    });
    expect(jsonDecode(request.body), {
      'title': 'Task',
      'notes': 'Notes',
      'status': 'needsAction',
      'due': '2026-06-05T00:00:00.000Z',
    });
    expectBearer(request);
  });
}
