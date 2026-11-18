import 'package:busymax/src/features/calendar/domain/event_reminders.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google popup edits preserve original order, methods and metadata', () {
    const email = {'method': 'email', 'minutes': 0, 'custom': 'keep'};
    const original = {
      'useDefault': false,
      'other': 'keep',
      'overrides': [
        email,
        {'method': 'popup', 'minutes': 0, 'extra': 'keep'},
        {'method': 'popup', 'minutes': 30},
      ],
    };
    const editor = EventReminderEditor(BusyProvider.google, original);
    expect(editor.minutes, [0, 30]);
    expect(editor.hasUnsupportedRows, isTrue);

    final updated = editor.edit(0, 5);
    expect(updated, {
      'useDefault': false,
      'other': 'keep',
      'overrides': [
        email,
        {'method': 'popup', 'minutes': 5, 'extra': 'keep'},
        {'method': 'popup', 'minutes': 30},
      ],
    });
    expect(EventReminderEditor(BusyProvider.google, updated).remove(1), {
      'useDefault': false,
      'other': 'keep',
      'overrides': [
        email,
        {'method': 'popup', 'minutes': 5, 'extra': 'keep'},
      ],
    });
    expect(editor.minutes, [0, 30]);
  });

  test('Google counts every override towards the provider limit', () {
    final editor = EventReminderEditor(BusyProvider.google, {
      'useDefault': false,
      'overrides': [
        for (var index = 0; index < googleReminderLimit; index++)
          {'method': 'email', 'minutes': index},
      ],
    });
    expect(editor.canAdd, isFalse);
    expect(() => editor.edit(null, 10), throwsStateError);
  });

  test('DAV offset editing keeps the original alarm identity', () {
    const editor = EventReminderEditor(BusyProvider.nextcloud, {
      'davEditableRows': [
        {'originalIndex': 3, 'minutes': 30},
      ],
    });
    expect(editor.edit(0, 5), {
      'davEditableRows': [
        {'originalIndex': 3, 'minutes': 5},
      ],
    });
  });

  test('Microsoft supports one reminder and respects the disabled flag', () {
    const editor = EventReminderEditor(BusyProvider.microsoft, {
      'isReminderOn': false,
      'reminderMinutesBeforeStart': 15,
    });
    expect(editor.minutes, isEmpty);
    expect(editor.canAdd, isTrue);
    final enabled = EventReminderEditor(
      BusyProvider.microsoft,
      editor.edit(null, 0),
    );
    expect(enabled.minutes, [0]);
    expect(enabled.canAdd, isFalse);
    expect(enabled.remove(0), containsPair('isReminderOn', false));
    expect(eventReminderValuesFor(15), contains(15));
    expect(nextEventReminderMinute([0, 5, 10]), 30);
  });
}
