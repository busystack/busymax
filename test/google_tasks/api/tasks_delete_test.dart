import 'package:flutter_test/flutter_test.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasks.delete sends exact request', () async {
    final httpClient = RecordingClient('');
    final client = newTestApiClient(httpClient);

    await client.deleteTask(taskListId: 'list-1', taskId: 'task/id');

    final request = httpClient.singleRequest;
    expect(request.method, 'DELETE');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/lists/list-1/tasks/task%2Fid');
    expect(request.url.queryParameters, isEmpty);
    expect(request.body, isEmpty);
    expectBearer(request);
  });
}
