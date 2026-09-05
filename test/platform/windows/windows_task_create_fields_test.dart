import 'package:busymax/src/dav/ical/ical_task_alarm.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_task_create_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    expect(fields, isNot(contains('microsoftDueDateTime')));
    expect(fields, isNot(contains('microsoftStartDateTime')));
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

  test('an empty Microsoft reminder emits the explicit disabled state', () {
    final fields = _fields(
      capability: microsoftTaskCollectionCapabilities,
      provider: BusyProvider.microsoft,
      scheduledAllDay: true,
    );

    expect(fields['microsoftIsReminderOn'], isFalse);
  });
}

Map<String, Object?> _fields({
  required TaskCollectionCapabilities capability,
  required BusyProvider provider,
  required bool scheduledAllDay,
  DateTime? reminder,
  List<IcalTaskAlarm> alarms = const [],
}) => buildWindowsTaskCreateFields(
  capability: capability,
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
);
