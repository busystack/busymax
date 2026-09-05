import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/ical/ical_timezone.dart';
import 'package:busymax/src/features/calendar/domain/event_timing_policy.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_event_rescheduling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'endpoint zones represent the same instants, independent of host OS',
    () {
      final instant = DateTime.utc(2026, 6, 8, 16, 37);
      final vancouver = providerInstantInTimeZone(instant, 'America/Vancouver');
      final tokyo = providerInstantInTimeZone(instant, 'Asia/Tokyo');
      expect(vancouver.hour, 9);
      expect(vancouver.minute, 37);
      expect(tokyo.day, 9);
      expect(tokyo.hour, 1);
      expect(
        providerWallTimeToInstant(vancouver, 'America/Vancouver'),
        instant,
      );
      expect(providerWallTimeToInstant(tokyo, 'Asia/Tokyo'), instant);
      expect(
        providerInstantInTimeZone(instant, 'Pacific Standard Time').hour,
        9,
      );
    },
  );
  test(
    'zone-less provider timestamps resolve IANA zones for schedule display',
    () {
      expect(
        providerDateTimeAsLocal(
          '2026-06-08T09:37:00',
          'America/Vancouver',
        )!.toUtc(),
        DateTime.utc(2026, 6, 8, 16, 37),
      );
    },
  );
  test('move snaps start only and retains a short off-grid duration', () {
    const math = ScheduleTimeMath(displayTimeZone: 'UTC');
    final original = ScheduleInterval(
      DateTime.utc(2026, 1, 12, 9, 7),
      DateTime.utc(2026, 1, 12, 9, 12),
    );
    final anchor = DateTime.utc(2026, 1, 12, 9, 9);
    expect(
      math.change(
        original: original,
        action: ScheduleTimingAction.move,
        anchor: anchor,
        pointer: anchor,
      ),
      same(original),
    );
    final moved = math.change(
      original: original,
      action: ScheduleTimingAction.move,
      anchor: anchor,
      pointer: anchor.add(const Duration(minutes: 45)),
    );
    expect(moved.start, DateTime.utc(2026, 1, 12, 9, 45));
    expect(moved.duration, const Duration(minutes: 5));
  });
  test('resize clamps to one grid interval and changes only its endpoint', () {
    const math = ScheduleTimeMath(displayTimeZone: 'UTC');
    final original = ScheduleInterval(
      DateTime.utc(2026, 1, 12, 9),
      DateTime.utc(2026, 1, 12, 10),
    );
    final resized = math.change(
      original: original,
      action: ScheduleTimingAction.resizeStart,
      anchor: original.start,
      pointer: original.end.add(const Duration(hours: 1)),
    );
    expect(resized.start, DateTime.utc(2026, 1, 12, 9, 45));
    expect(resized.end, original.end);
  });
  test(
    'DST spring gap is resolved before preview, preserving actual duration',
    () {
      const math = ScheduleTimeMath(displayTimeZone: 'America/New_York');
      final start = providerWallTimeToInstant(
        DateTime.utc(2026, 3, 7, 2, 30),
        math.displayTimeZone,
      );
      final interval = math.change(
        original: ScheduleInterval(start, start.add(const Duration(hours: 1))),
        action: ScheduleTimingAction.move,
        anchor: DateTime.utc(2026, 3, 7),
        pointer: DateTime.utc(2026, 3, 8),
        dateOnly: true,
      );
      expect(interval.start.hour, 3);
      expect(interval.start.minute, 30);
      expect(interval.duration, const Duration(hours: 1));
      expect(
        providerWallTimeToInstant(
          interval.start,
          math.displayTimeZone,
        ).isAtSameMomentAs(interval.start),
        isTrue,
      );
    },
  );
  test('DST fall movement retains actual duration through repeated hour', () {
    const math = ScheduleTimeMath(displayTimeZone: 'America/New_York');
    final start = providerWallTimeToInstant(
      DateTime.utc(2026, 10, 31, 1, 30),
      math.displayTimeZone,
    );
    final interval = math.change(
      original: ScheduleInterval(start, start.add(const Duration(hours: 2))),
      action: ScheduleTimingAction.move,
      anchor: DateTime.utc(2026, 10, 31),
      pointer: DateTime.utc(2026, 11, 1),
      dateOnly: true,
    );
    expect(interval.start.hour, 1);
    expect(interval.start.minute, 30);
    expect(interval.duration, const Duration(hours: 2));
  });
  test('all-day movement uses civil days and an exclusive end across DST', () {
    const math = ScheduleTimeMath(displayTimeZone: 'America/New_York');
    final interval = math.change(
      original: ScheduleInterval(DateTime(2026, 3, 7), DateTime(2026, 3, 9)),
      action: ScheduleTimingAction.move,
      anchor: DateTime(2026, 3, 7),
      pointer: DateTime(2026, 3, 8),
      allDay: true,
    );
    expect(interval.start, DateTime(2026, 3, 8));
    expect(interval.end, DateTime(2026, 3, 10));
    expect(ScheduleTimeMath.dayDifference(interval.end, interval.start), 2);
  });
  test('embedded custom VTIMEZONE inverse follows its own offsets', () {
    final document = IcalSemanticDocument.parse(
      'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'
      'BEGIN:VTIMEZONE\r\nTZID:Custom/Office\r\nBEGIN:STANDARD\r\n'
      'DTSTART:20200101T000000\r\nTZOFFSETFROM:+0545\r\nTZOFFSETTO:+0545\r\n'
      'END:STANDARD\r\nEND:VTIMEZONE\r\nBEGIN:VEVENT\r\nUID:zone-test\r\n'
      'DTSTART;TZID=Custom/Office:20260608T151500\r\nDTEND;TZID=Custom/Office:20260608T161500\r\n'
      'END:VEVENT\r\nEND:VCALENDAR\r\n',
    );
    final resolver = IcalTimeZoneResolver.fromDocument(document);
    final instant = DateTime.utc(2026, 6, 8, 9, 30);
    final wall = resolver.fromUtc(instant, 'Custom/Office');
    expect(wall.hour, 15);
    expect(wall.minute, 15);
    expect(wall.isUtc, isFalse);
    expect(
      resolver.toUtc(
        IcalTemporalValue(
          rawValue: '20260608T151500',
          kind: IcalTemporalKind.tzidDateTime,
          localValue: wall,
          timeZoneId: 'Custom/Office',
        ),
      ),
      instant,
    );
  });
  test(
    'Microsoft invitees cannot reschedule; nullable DAV organizer is valid',
    () {
      expect(
        canEditEventTiming(
          provider: BusyProvider.microsoft,
          canEdit: true,
          isOrganizer: false,
        ),
        isFalse,
      );
      expect(
        canEditEventTiming(
          provider: BusyProvider.microsoft,
          canEdit: true,
          isOrganizer: true,
        ),
        isTrue,
      );
      expect(
        canEditEventTiming(provider: BusyProvider.nextcloud, canEdit: true),
        isTrue,
      );
      expect(
        canEditEventTiming(provider: BusyProvider.webCal, canEdit: true),
        isFalse,
      );
      expect(
        canEditEventTiming(
          provider: BusyProvider.google,
          canEdit: true,
          guestsCanModify: true,
        ),
        isTrue,
      );
    },
  );
  test('Google following scope respects event-specific restrictions', () {
    expect(
      googleEventCanSplit(eventType: 'focusTime', conference: null),
      isFalse,
    );
    expect(
      googleEventCanSplit(
        eventType: 'default',
        conference: {
          'conferenceSolution': {
            'key': {'type': 'thirdParty'},
          },
        },
      ),
      isFalse,
    );
    expect(
      googleEventCanSplit(
        eventType: 'default',
        conference: {
          'conferenceSolution': {
            'key': {'type': 'hangoutsMeet'},
          },
        },
      ),
      isTrue,
    );
  });
}
