import 'package:flutter_test/flutter_test.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasks.list sends all discovery query parameters', () async {
    final httpClient = RecordingClient({
      'kind': 'tasks#tasks',
      'etag': 'etag-page',
      'nextPageToken': 'next',
      'items': [taskJson()],
    });
    final client = newTestApiClient(httpClient);

    final result = await client.listTasksPage(
      taskListId: 'list-1',
      completedMax: DateTime.utc(2026, 6, 10),
      completedMin: DateTime.utc(2026, 6, 1),
      dueMax: DateTime.utc(2026, 6, 11),
      dueMin: DateTime.utc(2026, 6, 2),
      maxResults: 500,
      pageToken: 'page',
      showCompleted: true,
      showDeleted: true,
      showHidden: true,
      updatedMin: DateTime.utc(2026, 6, 3),
      showAssigned: true,
    );

    final request = httpClient.singleRequest;
    expect(request.method, 'GET');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/lists/list-1/tasks');
    expect(request.url.queryParameters, {
      'completedMax': '2026-06-10T00:00:00.000Z',
      'completedMin': '2026-06-01T00:00:00.000Z',
      'dueMax': '2026-06-11T00:00:00.000Z',
      'dueMin': '2026-06-02T00:00:00.000Z',
      'maxResults': '100',
      'pageToken': 'page',
      'showCompleted': 'true',
      'showDeleted': 'true',
      'showHidden': 'true',
      'updatedMin': '2026-06-03T00:00:00.000Z',
      'showAssigned': 'true',
    });
    expect(request.body, isEmpty);
    expectBearer(request);
    expect(result.nextPageToken, 'next');
    expect(result.items.single.id, 'task-1');
  });
}
