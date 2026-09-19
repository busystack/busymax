import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unchanged guest text preserves structured attendees and change flag',
    () {
      const attendees = <EventAttendeeDraft>[
        EventAttendeeDraft(
          email: 'owner@example.test',
          displayName: 'Owner',
          self: true,
          organizer: true,
          responseStatus: 'accepted',
        ),
        EventAttendeeDraft(
          email: 'guest@example.test',
          displayName: 'Optional Guest',
          optional: true,
          responseStatus: 'tentative',
        ),
      ];

      final edit = mergeAndroidEventAttendees(attendees, 'guest@example.test');

      expect(edit.changed, isFalse);
      expect(identical(edit.attendees, attendees), isTrue);
      expect(edit.attendees.last.optional, isTrue);
      expect(edit.attendees.last.displayName, 'Optional Guest');
      expect(edit.attendees.last.responseStatus, 'tentative');
    },
  );

  test('guest additions preserve metadata on existing guests', () {
    const existing = EventAttendeeDraft(
      email: 'guest@example.test',
      displayName: 'Guest',
      optional: true,
      responseStatus: 'accepted',
    );

    final edit = mergeAndroidEventAttendees(const [
      existing,
    ], 'guest@example.test, new@example.test');

    expect(edit.changed, isTrue);
    expect(identical(edit.attendees.first, existing), isTrue);
    expect(edit.attendees.last.email, 'new@example.test');
  });
}
