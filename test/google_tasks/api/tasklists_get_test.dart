import 'package:flutter_test/flutter_test.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasklists.get sends exact request and preserves raw JSON', () async {
    final httpClient = RecordingClient(taskListJson());
    final client = newTestApiClient(httpClient);

    final result = await client.getTaskList('list 1');

    final request = httpClient.singleRequest;
    expect(request.method, 'GET');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/users/@me/lists/list%201');
    expect(request.url.queryParameters, isEmpty);
    expect(request.body, isEmpty);
    expectBearer(request);
    expect(result.rawJson['unknown'], 'preserved');
  });
}
