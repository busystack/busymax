import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/ui/windows/windows_event_reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'decodes multiple provider reminders without losing start-time zero',
    () {
      expect(
        decodeWindowsEventReminderMinutes({
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': 30},
            {'method': 'popup', 'minutes': 0},
            {'method': 'popup', 'minutes': 30},
          ],
        }),
        [30, 0],
      );
      expect(
        decodeWindowsEventReminderMinutes({
          'isReminderOn': true,
          'reminderMinutesBeforeStart': 15,
        }),
        [15],
      );
    },
  );

  test('encodes all Google reminders and one Microsoft reminder', () {
    expect(
      encodeWindowsEventReminderPayload(BusyProvider.google, const [30, 5, 30]),
      {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 30},
          {'method': 'popup', 'minutes': 5},
        ],
      },
    );
    expect(
      encodeWindowsEventReminderPayload(BusyProvider.microsoft, const [30, 5]),
      {'isReminderOn': true, 'reminderMinutesBeforeStart': 30},
    );
    expect(
      encodeWindowsEventReminderPayload(BusyProvider.microsoft, const []),
      {'isReminderOn': false},
    );
  });

  test('keeps custom values selectable and chooses an unused default', () {
    expect(windowsEventReminderValuesFor(15), contains(15));
    expect(nextWindowsEventReminderMinute(const [0, 5, 10]), 30);
  });
}
