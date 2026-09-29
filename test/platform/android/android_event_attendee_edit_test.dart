import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/providers/busy_provider.dart';
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

  test('role edits preserve guest identity and response metadata', () {
    final guest = EventAttendeeDraft.fromJson(const {
      'email': 'guest@example.test',
      'displayName': 'Guest',
      'responseStatus': 'accepted',
      'comment': 'Joining remotely',
      'additionalGuests': 2,
      'providerExtension': 'retain locally',
    });
    final changed = applyAndroidEventAttendeeRoles(
      AndroidEventAttendeeEdit(attendees: [guest], changed: false),
      const {'guest@example.test': true},
    );
    expect(changed.changed, isTrue);
    expect(changed.attendees.single.optional, isTrue);
    expect(changed.attendees.single.displayName, 'Guest');
    expect(changed.attendees.single.responseStatus, 'accepted');
    expect(
      changed.attendees.single.rawJson['providerExtension'],
      'retain locally',
    );
    expect(
      changed.attendees.single.toGoogleJson()['comment'],
      'Joining remotely',
    );
    expect(changed.attendees.single.toGoogleJson()['additionalGuests'], 2);
  });

  test('reminder selection separates defaults, none and at-start', () {
    expect(
      androidEventReminderSelection(BusyProvider.google, const {
        'useDefault': true,
      }),
      -1,
    );
    expect(
      androidEventReminderSelection(BusyProvider.google, const {
        'useDefault': false,
        'overrides': [],
      }),
      -2,
    );
    expect(
      androidEventReminderSelection(BusyProvider.google, const {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 0},
        ],
      }),
      0,
    );
    expect(
      androidEventReminderSelection(BusyProvider.microsoft, const {
        'isReminderOn': true,
        'reminderMinutesBeforeStart': 0,
      }),
      0,
    );
    expect(
      androidEventReminderSelection(BusyProvider.google, const {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 0},
          {'method': 'popup', 'minutes': 10},
        ],
      }),
      isNull,
    );
    expect(
      androidEventReminderMinutes(BusyProvider.google, const {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 0},
          {'method': 'popup', 'minutes': 10},
        ],
      }),
      [0, 10],
    );
  });

  test('Google popup edits preserve other and unsupported reminders', () {
    const original = {
      'useDefault': false,
      'overrides': [
        {'method': 'popup', 'minutes': 0, 'providerTag': 'retain'},
        {'method': 'email', 'minutes': 30},
        {'method': 'popup', 'minutes': 60},
      ],
    };
    final changed =
        androidEditGooglePopupReminder(original, overrideIndex: 2, minutes: 10)
            as Map;
    expect(changed['overrides'], [
      {'method': 'popup', 'minutes': 0, 'providerTag': 'retain'},
      {'method': 'email', 'minutes': 30},
      {'method': 'popup', 'minutes': 10},
    ]);
    final removed =
        androidRemoveGooglePopupReminder(changed, overrideIndex: 0) as Map;
    expect(removed['overrides'], [
      {'method': 'email', 'minutes': 30},
      {'method': 'popup', 'minutes': 10},
    ]);
    final added =
        androidEditGooglePopupReminder(removed, overrideIndex: null, minutes: 5)
            as Map;
    expect((added['overrides'] as List).length, 3);
    expect((added['overrides'] as List)[0], {'method': 'email', 'minutes': 30});
  });
}
