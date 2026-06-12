import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_draft.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
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
        microsoftTaskProviderCapabilities,
        localTimeZone: 'America/Vancouver',
      ),
      isEmpty,
    );
  });
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
