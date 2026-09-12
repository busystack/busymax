import 'package:busymax/src/dav/ical/ical_task_alarm.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'creation retains incompatible recurrence until destination validation and save',
    () {
      final rule = RecurrenceRule.fromIcalendar(
        rules: ['FREQ=MONTHLY;BYMONTHDAY=1,15'],
      );
      TaskDetailsDraft draft(BusyProvider provider) =>
          TaskDetailsDraft.forCreation(
            taskListId: 'list',
            provider: provider,
            timeZone: 'UTC',
            title: 'Twice monthly',
            due: DateTime(2026, 9, 1),
            recurrence: rule,
          );
      final microsoft = draft(BusyProvider.microsoft);
      expect(microsoft.creationRecurrence!.rule.byMonthDay, [1, 15]);
      expect(
        microsoft.recurrenceIssueFor(microsoftTaskCollectionCapabilities),
        TaskRecurrenceIssue.unsupportedDestination,
      );
      expect(
        () => microsoft.toCreateInput(
          microsoftTaskCollectionCapabilities,
          localTimeZone: 'UTC',
        ),
        throwsStateError,
      );
      final nextcloud = draft(BusyProvider.nextcloud);
      expect(
        nextcloud.recurrenceIssueFor(nextcloudTaskCollectionCapabilities),
        TaskRecurrenceIssue.none,
      );
      expect(
        (nextcloud
                .toCreateInput(
                  nextcloudTaskCollectionCapabilities,
                  localTimeZone: 'UTC',
                )
                .fields['recurrence']
            as Map)['rules'],
        ['FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=1,15'],
      );
    },
  );

  test(
    'hidden URL and start fields do not invalidate a Google destination',
    () {
      final draft = TaskDetailsDraft.forCreation(
        taskListId: 'list',
        provider: BusyProvider.google,
        timeZone: 'UTC',
        title: 'Task',
        taskUrl: 'example.test',
        start: DateTime(2026, 9, 2),
        due: DateTime(2026, 9, 1),
      );
      expect(
        draft.hasValidTaskUrlFor(nextcloudTaskCollectionCapabilities),
        isFalse,
      );
      expect(
        draft.scheduleIssueFor(nextcloudTaskCollectionCapabilities),
        TaskScheduleIssue.dueBeforeStart,
      );
      expect(
        draft.hasValidTaskUrlFor(googleTaskCollectionCapabilities),
        isTrue,
      );
      expect(
        draft.scheduleIssueFor(googleTaskCollectionCapabilities),
        TaskScheduleIssue.none,
      );
      final input = draft.toCreateInput(
        googleTaskCollectionCapabilities,
        localTimeZone: 'UTC',
      );
      expect(input.fields, isNot(contains('taskUrl')));
      expect(input.fields, isNot(contains('microsoftStartDateTime')));
      expect(draft.taskUrl, 'example.test');
      expect(draft.microsoftStartDate, '2026-09-02');
    },
  );

  test(
    'recurrence without an applicable date is actionable rather than dropped',
    () {
      final draft = TaskDetailsDraft.forCreation(
        taskListId: 'list',
        provider: BusyProvider.microsoft,
        timeZone: 'UTC',
        recurrence: RecurrenceRule.fromIcalendar(rules: ['FREQ=DAILY']),
      );
      expect(
        draft.recurrenceIssueFor(microsoftTaskCollectionCapabilities),
        TaskRecurrenceIssue.missingDate,
      );
      expect(
        () => draft.toCreateInput(
          microsoftTaskCollectionCapabilities,
          localTimeZone: 'UTC',
        ),
        throwsStateError,
      );
    },
  );

  test('all-day DAV tasks omit timed provider fields and keep every alarm', () {
    final fields = _fields(
      capability: nextcloudTaskCollectionCapabilities,
      provider: BusyProvider.nextcloud,
      scheduledAllDay: true,
      alarms: [
        IcalTaskAlarm.displayAbsolute(DateTime.utc(2026, 9, 1, 8)),
        IcalTaskAlarm.displayAbsolute(DateTime.utc(2026, 9, 1, 9)),
      ],
    );

    expect((fields['microsoftDueDateTime'] as Map)['dateTime'], '2026-09-01');
    expect((fields['microsoftStartDateTime'] as Map)['dateTime'], '2026-09-01');
    expect(
      fields['taskAlarms'],
      isA<List<Object?>>().having((value) => value.length, 'length', 2),
    );
  });

  test('timed Microsoft tasks include zones and one provider reminder', () {
    final fields = _fields(
      capability: microsoftTaskCollectionCapabilities,
      provider: BusyProvider.microsoft,
      scheduledAllDay: false,
      reminder: DateTime(2026, 9, 1, 8, 45),
    );

    expect(fields['microsoftDueTimeZone'], 'America/Vancouver');
    expect(fields['microsoftStartTimeZone'], 'America/Vancouver');
    expect(fields['microsoftIsReminderOn'], isTrue);
    expect(fields, isNot(contains('taskAlarms')));
  });

  test('an empty Microsoft reminder stays disabled', () {
    final fields = _fields(
      capability: microsoftTaskCollectionCapabilities,
      provider: BusyProvider.microsoft,
      scheduledAllDay: true,
    );

    expect(fields['microsoftIsReminderOn'], isNot(isTrue));
  });
}

Map<String, Object?> _fields({
  required TaskCollectionCapabilities capability,
  required BusyProvider provider,
  required bool scheduledAllDay,
  DateTime? reminder,
  List<IcalTaskAlarm> alarms = const [],
}) => TaskDetailsDraft.forCreation(
  taskListId: 'list',
  provider: provider,
  due: DateTime(2026, 9, 1, 10),
  start: DateTime(2026, 9, 1, 9),
  reminder: reminder,
  alarms: alarms,
  scheduledAllDay: scheduledAllDay,
  timeZone: 'America/Vancouver',
  recurrence: const RecurrenceRule.none(),
  importance: 'normal',
  status: '',
  priority: 0,
  progress: 0,
  location: '',
  taskUrl: '',
  classification: 'PUBLIC',
  pinned: false,
  hideSubtasks: false,
  hideCompletedSubtasks: false,
).toCreateInput(capability, localTimeZone: 'America/Vancouver').fields;
