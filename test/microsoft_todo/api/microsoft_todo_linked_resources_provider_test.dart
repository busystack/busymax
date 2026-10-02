import 'dart:convert';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('a malformed later page fails the whole linked-resource lookup', () async {
    final client = MicrosoftTodoRestApiClient(
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.queryParameters.containsKey(r'$skiptoken')
                ? <String, Object?>{'error': 'incomplete'}
                : <String, Object?>{
                    'value': [
                      {'id': 'first', 'webUrl': 'https://example.test/task'},
                    ],
                    '@odata.nextLink':
                        'https://graph.microsoft.com/v1.0/me/todo/lists/list/tasks/task/linkedResources?\$skiptoken=next',
                  },
          ),
          200,
        ),
      ),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      authorizationHeaderProvider: () async => 'Bearer token',
    );
    final container = ProviderContainer(
      overrides: [
        microsoftTodoApiClientForAccountProvider(
          'microsoft:a',
        ).overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(
        microsoftTaskLinkedResourcesProvider((
          accountId: 'microsoft:a',
          taskListId: 'list',
          taskId: 'task',
        )).future,
      ),
      throwsFormatException,
    );
  });

  test(
    'on-demand provider paginates, filters unsafe and duplicate links',
    () async {
      final requests = <Uri>[];
      final client = MicrosoftTodoRestApiClient(
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode(
              request.url.queryParameters.containsKey(r'$skiptoken')
                  ? {
                      'value': [
                        {
                          'id': 'second',
                          'applicationName': 'Outlook',
                          'displayName': 'Mail',
                          'webUrl': 'https://example.test/mail',
                        },
                        {
                          'id': 'duplicate',
                          'applicationName': 'Planner',
                          'displayName': 'Task',
                          'webUrl': 'https://example.test/task',
                        },
                      ],
                    }
                  : {
                      'value': [
                        {
                          'id': 'first',
                          'applicationName': 'Planner',
                          'displayName': 'Task',
                          'webUrl': 'https://example.test/task',
                        },
                        {
                          'id': 'invalid',
                          'applicationName': 'Unknown',
                          'webUrl': 'javascript:alert(1)',
                        },
                      ],
                      '@odata.nextLink':
                          'https://graph.microsoft.com/v1.0/me/todo/lists/list/tasks/task/linkedResources?\$skiptoken=next',
                    },
            ),
            200,
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        authorizationHeaderProvider: () async => 'Bearer token',
      );
      final container = ProviderContainer(
        overrides: [
          microsoftTodoApiClientForAccountProvider(
            'microsoft:a',
          ).overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      final links = await container.read(
        microsoftTaskLinkedResourcesProvider((
          accountId: 'microsoft:a',
          taskListId: 'list',
          taskId: 'task',
        )).future,
      );
      expect(requests, hasLength(2));
      expect(links.map((link) => link.url), [
        'https://example.test/task',
        'https://example.test/mail',
      ]);
      expect(links.last.label, 'Mail · Outlook');
    },
  );
}
