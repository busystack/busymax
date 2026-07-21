import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_error.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_models.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_error.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_models.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_google_tasks_adapter.dart';

void main() {
  test(
    'create task maps Google-shaped fields to Microsoft Graph body',
    () async {
      final client = _FakeMicrosoftTodoApiClient();
      final adapter = MicrosoftTodoGoogleTasksAdapter(
        client: client,
        defaultTimeZone: 'America/Vancouver',
        nowUtc: () => DateTime.utc(2026, 6, 6, 18),
      );

      await adapter.createTask(
        taskListId: 'list-1',
        create: const TaskCreate.fields({
          'title': 'Task',
          'notes': 'Line 1\nLine 2',
          'due': '2026-06-06T00:00:00.000Z',
          'status': 'completed',
          'completed': '2026-06-06T15:45:00',
        }),
      );

      expect(client.createdTaskListId, 'list-1');
      expect(client.createdTaskBody['title'], 'Task');
      expect(client.createdTaskBody['body'], {
        'content': 'Line 1<br>Line 2',
        'contentType': 'html',
      });
      expect(client.createdTaskBody['dueDateTime'], {
        'dateTime': '2026-06-06',
        'timeZone': 'America/Vancouver',
      });
      expect(client.createdTaskBody['status'], 'completed');
      expect(client.createdTaskBody['completedDateTime'], {
        'dateTime': '2026-06-06T15:45:00',
        'timeZone': 'America/Vancouver',
      });
    },
  );

  test('unsupported Microsoft move and clear completed are blocked', () async {
    final adapter = MicrosoftTodoGoogleTasksAdapter(
      client: _FakeMicrosoftTodoApiClient(),
      defaultTimeZone: 'UTC',
    );

    expect(
      () => adapter.clearCompletedTasks('list-1'),
      throwsA(
        isA<GoogleTasksApiError>().having(
          (error) => error.code,
          'code',
          'unsupported_provider_operation',
        ),
      ),
    );
    expect(
      () => adapter.moveTask(sourceTaskListId: 'list-1', taskId: 'task-1'),
      throwsA(isA<GoogleTasksApiError>()),
    );
  });

  test('patch sends Microsoft dateTime values with timeZone', () async {
    final client = _FakeMicrosoftTodoApiClient();
    final adapter = MicrosoftTodoGoogleTasksAdapter(
      client: client,
      defaultTimeZone: 'UTC',
    );

    await adapter.patchTask(
      taskListId: 'list-1',
      taskId: 'task-1',
      patch: const TaskPatch.fields({
        'microsoftDueDateTime': {
          'dateTime': '2026-06-06T14:30:00',
          'timeZone': 'America/Vancouver',
        },
        'microsoftStartDateTime': {
          'dateTime': '2026-06-06T08:00:00',
          'timeZone': 'America/Vancouver',
        },
        'microsoftReminderDateTime': {
          'dateTime': '2026-06-06T09:00:00',
          'timeZone': 'America/Vancouver',
        },
      }),
    );

    expect(client.updatedTaskPatch['dueDateTime'], {
      'dateTime': '2026-06-06T14:30:00',
      'timeZone': 'America/Vancouver',
    });
    expect(client.updatedTaskPatch['startDateTime'], {
      'dateTime': '2026-06-06T08:00:00',
      'timeZone': 'America/Vancouver',
    });
    expect(client.updatedTaskPatch['reminderDateTime'], {
      'dateTime': '2026-06-06T09:00:00',
      'timeZone': 'America/Vancouver',
    });
  });

  test(
    'completedDateTime patch preserves Microsoft wall-clock timezone',
    () async {
      final client = _FakeMicrosoftTodoApiClient();
      final adapter = MicrosoftTodoGoogleTasksAdapter(
        client: client,
        defaultTimeZone: 'UTC',
      );

      await adapter.patchTask(
        taskListId: 'list-1',
        taskId: 'task-1',
        patch: const TaskPatch.fields({
          'status': 'completed',
          'microsoftCompletedDateTime': {
            'dateTime': '2026-06-06T15:45:00',
            'timeZone': 'America/Vancouver',
          },
        }),
      );

      expect(client.updatedTaskPatch['status'], 'completed');
      expect(client.updatedTaskPatch['completedDateTime'], {
        'dateTime': '2026-06-06T15:45:00',
        'timeZone': 'America/Vancouver',
      });
    },
  );

  test('normalizes Microsoft errors without losing provider details', () async {
    const rawJson = <String, Object?>{
      'error': <String, Object?>{
        'code': 'Authorization_RequestDenied',
        'message': 'Access denied by policy.',
      },
    };
    final client = _FakeMicrosoftTodoApiClient()
      ..updateTaskError = const MicrosoftTodoApiError(
        statusCode: 403,
        code: 'Authorization_RequestDenied',
        message: 'Access denied by policy.',
        rawJson: rawJson,
      );
    final adapter = MicrosoftTodoGoogleTasksAdapter(
      client: client,
      defaultTimeZone: 'UTC',
    );

    await expectLater(
      () => adapter.patchTask(
        taskListId: 'list-1',
        taskId: 'task-1',
        patch: const TaskPatch.fields({'title': 'Updated'}),
      ),
      throwsA(
        isA<GoogleTasksApiError>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
              (error) => error.code,
              'code',
              'Authorization_RequestDenied',
            )
            .having(
              (error) => error.message,
              'message',
              'Access denied by policy.',
            )
            .having((error) => error.rawJson, 'rawJson', rawJson),
      ),
    );
  });
}

class _FakeMicrosoftTodoApiClient implements MicrosoftTodoApiClient {
  var createdTaskListId = '';
  var createdTaskBody = <String, Object?>{};
  var updatedTaskPatch = <String, Object?>{};
  MicrosoftTodoApiError? updateTaskError;

  @override
  Future<MicrosoftTodoTaskDto> createTask({
    required String taskListId,
    required Map<String, Object?> body,
  }) async {
    createdTaskListId = taskListId;
    createdTaskBody = body;
    return MicrosoftTodoTaskDto(
      id: 'task-1',
      title: body['title']?.toString(),
      categories: const [],
      rawJson: {'id': 'task-1', ...body},
    );
  }

  @override
  Future<MicrosoftTodoTaskListDto> createTaskList({
    required String displayName,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteTaskList(String taskListId) => throw UnimplementedError();

  @override
  Future<MicrosoftTodoTaskListsDeltaPageDto> deltaTaskLists({
    String? deltaLinkOrNextLink,
  }) => throw UnimplementedError();

  @override
  Future<MicrosoftTodoTasksDeltaPageDto> deltaTasks({
    required String taskListId,
    String? deltaLinkOrNextLink,
  }) => throw UnimplementedError();

  @override
  Future<MicrosoftTodoUserDto> getMe() => throw UnimplementedError();

  @override
  Future<MicrosoftTodoTaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) => throw UnimplementedError();

  @override
  Future<MicrosoftTodoTaskListsPageDto> listTaskListsPage({String? nextLink}) =>
      throw UnimplementedError();

  @override
  Future<MicrosoftTodoTasksPageDto> listTasksPage({
    required String taskListId,
    String? nextLink,
  }) => throw UnimplementedError();

  @override
  Future<MicrosoftTodoTaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required Map<String, Object?> patch,
  }) async {
    final error = updateTaskError;
    if (error != null) {
      throw error;
    }
    updatedTaskPatch = patch;
    return MicrosoftTodoTaskDto(
      id: taskId,
      title: patch['title']?.toString(),
      categories: const [],
      rawJson: {'id': taskId, ...patch},
    );
  }

  @override
  Future<MicrosoftTodoTaskListDto> updateTaskList({
    required String taskListId,
    required Map<String, Object?> patch,
  }) => throw UnimplementedError();
}
