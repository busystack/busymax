import 'package:busymax/src/features/sync/conflict_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = ConflictDetector();
  final baseline = DateTime.utc(2026, 6, 4);
  final current = baseline.add(const Duration(minutes: 1));

  test('separately decoded structured task values compare deeply', () {
    final values = <String, Object?>{
      'categories': ['Home', 'Important'],
      'recurrence': {
        'pattern': {
          'type': 'weekly',
          'interval': 2,
          'daysOfWeek': ['monday'],
        },
        'range': {'type': 'endDate', 'endDate': '2026-12-31'},
      },
      'microsoftDueDateTime': {
        'dateTime': '2026-06-05T09:30:00.0000000',
        'timeZone': 'America/Vancouver',
      },
    };
    final equivalent = <String, Object?>{
      'categories': <Object?>['Home', 'Important'],
      'recurrence': <String, Object?>{
        'pattern': <String, Object?>{
          'type': 'weekly',
          'interval': 2,
          'daysOfWeek': <Object?>['monday'],
        },
        'range': <String, Object?>{'type': 'endDate', 'endDate': '2026-12-31'},
      },
      'microsoftDueDateTime': <String, Object?>{
        'dateTime': '2026-06-05T09:30:00.0000000',
        'timeZone': 'America/Vancouver',
      },
    };

    final conflict = detector.detect(
      entityType: 'task',
      entityId: 'task-1',
      localPendingFields: values,
      lastServerJson: values,
      currentServerJson: equivalent,
      baselineUpdatedUtc: baseline,
      currentUpdatedUtc: current,
    );

    expect(conflict.hasConflict, isFalse);
  });

  test('a genuinely changed nested value remains a conflict', () {
    final conflict = detector.detect(
      entityType: 'task',
      entityId: 'task-1',
      localPendingFields: const {'recurrence': true},
      lastServerJson: const {
        'recurrence': {
          'pattern': {'interval': 1},
        },
      },
      currentServerJson: const {
        'recurrence': {
          'pattern': {'interval': 2},
        },
      },
      baselineUpdatedUtc: baseline,
      currentUpdatedUtc: current,
    );

    expect(conflict.changedFields, {'recurrence'});
  });
}
