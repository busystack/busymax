import 'package:busymax/src/features/calendar/domain/google_status_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 6, 8, 9);
  final end = DateTime.utc(2026, 6, 8, 10);

  void validate(
    String type, {
    bool primary = true,
    bool allDay = false,
    DateTime? finish,
    String? original,
    String? visibility,
    String? transparency,
    Map<String, Object?>? properties,
  }) => validateGoogleStatusEvent(
    primaryCalendar: primary,
    eventType: type,
    originalEventType: original,
    allDay: allDay,
    start: start,
    end: finish ?? end,
    visibility:
        visibility ?? (type == 'workingLocation' ? 'public' : 'default'),
    transparency:
        transparency ?? (type == 'workingLocation' ? 'transparent' : 'opaque'),
    properties: properties ?? defaultGoogleStatusProperties(type),
  );

  test(
    'all three documented status types validate on the primary calendar',
    () {
      for (final type in googleStatusEventTypes) {
        validate(type);
        expect(defaultGoogleStatusProperties(type), isNotEmpty);
      }
    },
  );

  test('secondary calendars and in-place type conversion are rejected', () {
    expect(() => validate('focusTime', primary: false), throwsUnsupportedError);
    expect(
      () => validate('focusTime', original: 'default'),
      throwsUnsupportedError,
    );
    expect(() => validate('fromGmail'), throwsUnsupportedError);
  });

  test(
    'timing, transparency, visibility, and working-location form are enforced',
    () {
      expect(() => validate('focusTime', allDay: true), throwsArgumentError);
      expect(
        () => validate('outOfOffice', transparency: 'transparent'),
        throwsArgumentError,
      );
      expect(
        () => validate('workingLocation', visibility: 'private'),
        throwsArgumentError,
      );
      expect(
        () => validate(
          'workingLocation',
          allDay: true,
          finish: DateTime.utc(2026, 6, 10),
        ),
        throwsArgumentError,
      );
      expect(
        () => validate('workingLocation', properties: const {'type': 'other'}),
        throwsArgumentError,
      );
    },
  );

  test(
    'unknown provider fields remain in status properties during extraction',
    () {
      expect(
        googleStatusPropertiesFromRaw('workingLocation', {
          'workingLocationProperties': {
            'type': 'officeLocation',
            'officeLocation': {'buildingId': 'building', 'label': 'HQ'},
            'providerOwned': 'keep',
          },
        })['providerOwned'],
        'keep',
      );
    },
  );
}
