import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_draft.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Microsoft UTC reminder opens as local time without dirty draft', () {
    final task = TaskEntity(
      accountId: 'account',
      taskListId: 'inbox',
      id: 'task-1',
      title: 'File report',
      status: 'needsAction',
      microsoftIsReminderOn: true,
      microsoftReminderDateTime: '2026-06-12T13:02:00',
      microsoftReminderTimeZone: 'UTC',
      localDirty: false,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      updatedLocalAtUtc: '2026-06-12T00:00:00.000Z',
    );
    final localReminder = DateTime.utc(2026, 6, 12, 13, 2).toLocal();

    final draft = TaskDetailsDraft.fromTask(task, 'America/Vancouver');

    expect(draft.microsoftReminderDate, _dateOnly(localReminder));
    expect(draft.microsoftReminderTime, _timeOnly(localReminder));
    expect(draft.microsoftReminderTimeZone, 'America/Vancouver');
    expect(
      draft.toPatch(
        task,
        microsoftTaskCollectionCapabilities,
        localTimeZone: 'America/Vancouver',
      ),
      isEmpty,
    );
  });

  test('schedule reports a due date before the start date', () {
    final draft = TaskDetailsDraft.fromTask(
      _task(due: '2026-08-09', start: '2026-08-10'),
      'America/Vancouver',
    );

    expect(draft.scheduleIssue, TaskScheduleIssue.dueBeforeStart);
  });

  test('schedule accepts the same all-day start and due date', () {
    final draft = TaskDetailsDraft.fromTask(
      _task(due: '2026-08-10', start: '2026-08-10'),
      'America/Vancouver',
    );

    expect(draft.scheduleIssue, TaskScheduleIssue.none);
  });

  test('schedule reports mixed all-day and timed values', () {
    final draft = TaskDetailsDraft.fromTask(
      _task(due: '2026-08-10', start: '2026-08-10T09:00:00'),
      'America/Vancouver',
    );

    expect(draft.scheduleIssue, TaskScheduleIssue.mixedTimeModes);
  });
}

TaskEntity _task({required String due, required String start}) {
  return TaskEntity(
    accountId: 'account',
    taskListId: 'inbox',
    id: 'task-1',
    title: 'Task',
    status: 'needsAction',
    dueUtc: due.substring(0, 10),
    microsoftDueDateTime: due,
    microsoftDueTimeZone: 'America/Vancouver',
    microsoftStartDateTime: start,
    microsoftStartTimeZone: 'America/Vancouver',
    localDirty: false,
    pendingDelete: false,
    pendingMove: false,
    rawJson: '{}',
    updatedLocalAtUtc: '2026-08-09T00:00:00.000Z',
  );
}

String _dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _timeOnly(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
