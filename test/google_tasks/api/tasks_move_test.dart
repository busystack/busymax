import 'package:flutter_test/flutter_test.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasks.move sends exact query parameters', () async {
    final httpClient = RecordingClient(taskJson());
    final client = newTestApiClient(httpClient);

    await client.moveTask(
      sourceTaskListId: 'source-list',
      taskId: 'task-1',
      parentTaskId: 'parent-1',
      previousSiblingTaskId: 'previous-1',
      destinationTaskListId: 'dest-list',
    );

    final request = httpClient.singleRequest;
    expect(request.method, 'POST');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/lists/source-list/tasks/task-1/move');
    expect(request.url.queryParameters, {
      'parent': 'parent-1',
      'previous': 'previous-1',
      'destinationTasklist': 'dest-list',
    });
    expect(request.body, isEmpty);
    expectBearer(request);
  });
}
