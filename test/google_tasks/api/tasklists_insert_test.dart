import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasklists.insert sends exact request body', () async {
    final httpClient = RecordingClient(taskListJson());
    final client = newTestApiClient(httpClient);

    final result = await client.createTaskList(title: 'Inbox');

    final request = httpClient.singleRequest;
    expect(request.method, 'POST');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/users/@me/lists');
    expect(request.url.queryParameters, isEmpty);
    expect(jsonDecode(request.body), {'title': 'Inbox'});
    expectBearer(request);
    expect(result.id, 'list-1');
  });
}
