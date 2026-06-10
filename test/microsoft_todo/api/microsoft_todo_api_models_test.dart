import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_models.dart';

void main() {
  test('parses todoTask with Microsoft-specific fields and removed marker', () {
    final task = MicrosoftTodoTaskDto.fromJson({
      '@odata.etag': 'etag-1',
      'id': 'task-1',
      'title': 'Task',
      'body': {'content': '<p>Notes</p>', 'contentType': 'html'},
      'categories': ['Important', 'Home'],
      'completedDateTime': {
        'dateTime': '2026-06-06T15:45:00',
        'timeZone': 'America/Vancouver',
      },
      'dueDateTime': {
        'dateTime': '2026-06-06T14:30:00',
        'timeZone': 'America/Vancouver',
      },
      'reminderDateTime': {
        'dateTime': '2026-06-06T09:00:00',
        'timeZone': 'America/Vancouver',
      },
      'startDateTime': {
        'dateTime': '2026-06-05T09:00:00',
        'timeZone': 'America/Vancouver',
      },
      'isReminderOn': true,
      'importance': 'high',
      'status': 'completed',
      'recurrence': {
        'pattern': {'type': 'weekly', 'interval': 1},
        'range': {'type': 'noEnd', 'startDate': '2026-06-06'},
      },
      'hasAttachments': true,
      'createdDateTime': '2026-06-01T00:00:00Z',
      'lastModifiedDateTime': '2026-06-02T00:00:00Z',
      'bodyLastModifiedDateTime': '2026-06-02T00:00:00Z',
      '@removed': {'reason': 'deleted'},
    });

    expect(task.id, 'task-1');
    expect(task.etag, 'etag-1');
    expect(task.body!.contentType, 'html');
    expect(task.categories, ['Important', 'Home']);
    expect(task.dueDateTime!.dateTime, '2026-06-06T14:30:00');
    expect(task.reminderDateTime!.timeZone, 'America/Vancouver');
    expect(task.startDateTime!.dateTime, '2026-06-05T09:00:00');
    expect(task.completedDateTime!.dateTime, '2026-06-06T15:45:00');
    expect(task.recurrence!['pattern'], isA<Map>());
    expect(task.importance, 'high');
    expect(task.hasAttachments, isTrue);
    expect(task.removed, isTrue);
    expect(task.removedReason, 'deleted');
    expect(task.rawJson['title'], 'Task');
  });

  test('parses todoTaskList with Microsoft fields and removed marker', () {
    final list = MicrosoftTodoTaskListDto.fromJson({
      'id': 'list-1',
      'displayName': 'Tasks',
      'isOwner': true,
      'isShared': false,
      'wellknownListName': 'defaultList',
      '@removed': {'reason': 'deleted'},
    });

    expect(list.id, 'list-1');
    expect(list.displayName, 'Tasks');
    expect(list.isOwner, isTrue);
    expect(list.isShared, isFalse);
    expect(list.wellknownListName, 'defaultList');
    expect(list.removed, isTrue);
    expect(list.removedReason, 'deleted');
  });
}
