import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasks.patch sends writable fields and explicit null clears', () async {
    final httpClient = RecordingClient(taskJson());
    final client = newTestApiClient(httpClient);

    await client.patchTask(
      taskListId: 'list-1',
      taskId: 'task-1',
      patch: TaskPatch(
        title: 'Updated',
        status: 'needsAction',
        clearDue: true,
        clearCompleted: true,
      ),
    );

    final request = httpClient.singleRequest;
    expect(request.method, 'PATCH');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/lists/list-1/tasks/task-1');
    expect(request.url.queryParameters, isEmpty);
    expect(jsonDecode(request.body), {
      'title': 'Updated',
      'status': 'needsAction',
      'due': null,
      'completed': null,
    });
    expectBearer(request);
  });
}
