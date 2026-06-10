import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasks.update sends replacement writable fields', () async {
    final httpClient = RecordingClient(taskJson());
    final client = newTestApiClient(httpClient);

    await client.updateTask(
      taskListId: 'list-1',
      taskId: 'task-1',
      replacement: TaskPut(
        title: 'Replacement',
        notes: 'Replacement notes',
        status: 'completed',
        completed: DateTime.utc(2026, 6, 6),
        deleted: false,
      ),
    );

    final request = httpClient.singleRequest;
    expect(request.method, 'PUT');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/lists/list-1/tasks/task-1');
    expect(request.url.queryParameters, isEmpty);
    expect(jsonDecode(request.body), {
      'title': 'Replacement',
      'notes': 'Replacement notes',
      'status': 'completed',
      'completed': '2026-06-06T00:00:00.000Z',
      'deleted': false,
    });
    expectBearer(request);
  });
}
