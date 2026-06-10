import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasklists.patch sends exact request body', () async {
    final httpClient = RecordingClient(taskListJson());
    final client = newTestApiClient(httpClient);

    await client.patchTaskList('list-1', TaskListPatch.title('Renamed'));

    final request = httpClient.singleRequest;
    expect(request.method, 'PATCH');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/users/@me/lists/list-1');
    expect(request.url.queryParameters, isEmpty);
    expect(jsonDecode(request.body), {'title': 'Renamed'});
    expectBearer(request);
  });
}
