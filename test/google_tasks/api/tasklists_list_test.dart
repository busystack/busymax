import 'package:flutter_test/flutter_test.dart';

import 'test_api_client_support.dart';

void main() {
  test('tasklists.list sends exact query and parses page', () async {
    final httpClient = RecordingClient({
      'kind': 'tasks#taskLists',
      'etag': 'etag-page',
      'nextPageToken': 'next',
      'items': [taskListJson()],
    });
    final client = newTestApiClient(httpClient);

    final result = await client.listTaskListsPage(
      maxResults: 5000,
      pageToken: 'page',
    );

    final request = httpClient.singleRequest;
    expect(request.method, 'GET');
    expect(request.url.host, 'tasks.googleapis.com');
    expect(request.url.path, '/tasks/v1/users/@me/lists');
    expect(request.url.queryParameters, {
      'maxResults': '1000',
      'pageToken': 'page',
    });
    expect(request.body, isEmpty);
    expectBearer(request);
    expect(result.nextPageToken, 'next');
    expect(result.items.single.id, 'list-1');
  });
}
