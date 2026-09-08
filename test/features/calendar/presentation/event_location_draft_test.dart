import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opening an existing location and point is unchanged', () {
    final point = GeographicPoint(latitude: 0, longitude: 0);
    final draft = _draft(location: 'Hall', point: point);

    expect(draft.location, 'Hall');
    expect(draft.locationPoint, point);
    expect(draft.effectiveLocationPoint, point);
    expect(draft.locationChange, const LocationChange.unchanged());
    expect(draft.copyWith(), draft);
  });

  test('same-label new pin is a real draft change', () {
    final initial = _draft(
      location: 'Hall',
      point: GeographicPoint(latitude: 1, longitude: 2),
    );
    final selection = LocationResult(
      label: 'Hall',
      point: GeographicPoint(latitude: 3, longitude: 4),
    );
    final changed = initial.copyWith(
      location: selection.label,
      locationChange: LocationChange.replace(selection),
    );

    expect(changed, isNot(initial));
    expect(changed.location, initial.location);
    expect(changed.effectiveLocationPoint, selection.point);
  });

  test('typing and clearing invalidate an earlier selection', () {
    final selection = LocationResult(
      label: 'Hall',
      point: GeographicPoint(latitude: 3, longitude: 4),
    );
    final selected = _draft(
      location: selection.label,
      point: GeographicPoint(latitude: 1, longitude: 2),
    ).copyWith(locationChange: LocationChange.replace(selection));

    final typed = selected.copyWith(location: 'Meeting room 3');
    expect(typed.locationChange, const LocationChange.clear());
    expect(typed.effectiveLocationPoint, isNull);

    final cleared = selected.copyWith(
      clearLocation: true,
      locationChange: const LocationChange.clear(),
    );
    expect(cleared.location, isNull);
    expect(cleared.effectiveLocationPoint, isNull);
  });

  test(
    'restoring the original location restores coordinates and clean state',
    () {
      final point = GeographicPoint(latitude: 49.2827, longitude: -123.1207);
      final initial = _draft(location: 'Harbour Centre', point: point);

      final changed = initial.copyWith(location: 'Meeting room 3');
      final restored = changed.copyWith(location: 'Harbour Centre');

      expect(changed.locationChange, const LocationChange.clear());
      expect(changed.effectiveLocationPoint, isNull);
      expect(restored.locationChange, const LocationChange.unchanged());
      expect(restored.effectiveLocationPoint, point);
      expect(restored, initial);
    },
  );

  test('entering then clearing a new location restores the null baseline', () {
    final initial = EventEditorDraft.newEvent(
      accountId: 'account',
      sourceId: 'source',
      providerCalendarId: 'calendar',
      start: DateTime.utc(2026, 9, 7, 10),
      end: DateTime.utc(2026, 9, 7, 11),
    );

    final changed = initial.copyWith(location: 'Meeting room 3');
    final restored = changed.copyWith(location: '');

    expect(restored.location, isNull);
    expect(restored.locationChange, const LocationChange.unchanged());
    expect(restored, initial);
  });
}

EventEditorDraft _draft({
  required String location,
  required GeographicPoint? point,
}) => EventEditorDraft.existing(
  eventId: 'event',
  accountId: 'account',
  sourceId: 'source',
  providerCalendarId: 'calendar',
  title: 'Event',
  allDay: false,
  start: DateTime.utc(2026, 9, 7, 10),
  end: DateTime.utc(2026, 9, 7, 11),
  location: location,
  locationPoint: point,
);
