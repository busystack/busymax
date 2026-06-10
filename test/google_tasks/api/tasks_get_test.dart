import 'package:flutter_test/flutter_test.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasks.get sends exact request and parses all fields', () async {
    final httpClient = RecordingClient(taskJson());
    final client = newTestApiClient(httpClient);

    final result = await client.getTask(taskListId: 'list-1', taskId: 'task 1');

    final request = httpClient.singleRequest;
    expect(request.method, 'GET');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/lists/list-1/tasks/task%201');
    expect(request.url.queryParameters, isEmpty);
    expect(request.body, isEmpty);
    expectBearer(request);
    expect(result.links.single.type, 'email');
    expect(result.assignmentInfo?['surfaceType'], 'DOCUMENT');
    expect(result.rawJson['unknown'], 'preserved');
  });
}
