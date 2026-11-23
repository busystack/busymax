import 'package:busymax/src/core/time/iana_time_zone_data.dart'
    as time_zone_data;
import 'package:busymax/src/features/calendar/domain/event_editor_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(time_zone_data.initializeTimeZones);
  EventEditorDraft draft(int endHour) =>
      EventEditorDraft.newEvent(
        accountId: 'account',
        sourceId: 'calendar',
        providerCalendarId: 'provider-calendar',
        start: DateTime(2026, 11, 17, 16),
        end: DateTime(2026, 11, 17, endHour),
      ).copyWith(
        title: 'Planning',
        startTimeZone: 'UTC',
        endTimeZone: 'America/Los_Angeles',
      );

  test('a valid cross-zone interval retains the original end fields', () {
    final current = draft(9);
    expect(current.canSave, isTrue);
    expect(current.withValidEnd(), same(current));
  });

  test('a default end is expressed in the end field’s zone', () {
    final current = draft(7);
    expect(current.canSave, isFalse);
    final adjusted = current.withValidEnd();
    expect(adjusted.canSave, isTrue);
    expect(adjusted.end!.hour, 9);
    expect(adjusted.endTimeZone, 'America/Los_Angeles');
  });
}
