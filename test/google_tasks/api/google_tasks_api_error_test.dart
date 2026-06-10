import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_client.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_error.dart';

import 'test_api_client_support.dart';

void main() {
  test('parses Google API error response', () async {
    final httpClient = RecordingClient({
      'error': {
        'code': 403,
        'status': 'PERMISSION_DENIED',
        'message': 'Insufficient Permission',
      },
    }, statusCode: 403);
    final client = GoogleTasksRestApiClient(
      httpClient: httpClient,
      baseUri: Uri.parse('https://tasks.googleapis.com'),
      authorizationHeaderProvider: () async => 'Bearer test-token',
    );

    await expectLater(
      client.getTaskList('list-1'),
      throwsA(
        isA<GoogleTasksApiError>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.status, 'status', 'PERMISSION_DENIED')
            .having(
              (error) => error.message,
              'message',
              'Insufficient Permission',
            ),
      ),
    );
  });
}
