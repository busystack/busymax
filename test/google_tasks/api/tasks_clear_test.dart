import 'package:flutter_test/flutter_test.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasks.clear sends exact request', () async {
    final httpClient = RecordingClient('');
    final client = newTestApiClient(httpClient);

    await client.clearCompletedTasks('list-1');

    final request = httpClient.singleRequest;
    expect(request.method, 'POST');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/lists/list-1/clear');
    expect(request.url.queryParameters, isEmpty);
    expect(request.body, isEmpty);
    expectBearer(request);
  });
}
