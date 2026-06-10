import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_json.dart';

void main() {
  test('encodes due date as date-only neutral UTC midnight', () {
    expect(
      encodeGoogleDueDate(DateTime.utc(2026, 6, 5, 13, 30)),
      '2026-06-05T00:00:00.000Z',
    );
  });

  test('encodes UI-selected civil date without UTC day shifting', () {
    expect(encodeGoogleDateParts(2026, 1, 2), '2026-01-02');
    expect(encodeGoogleDateOnly(DateTime(2026, 1, 2)), '2026-01-02');

    const selectedDate = '2026-01-02';
    for (final offset in [
      Duration(hours: -8),
      Duration.zero,
      Duration(hours: 5, minutes: 30),
      Duration(hours: 14),
    ]) {
      final utcInstantForLocalMidnight = DateTime.utc(
        2026,
        1,
        2,
      ).subtract(offset);
      expect(
        encodeGoogleDateParts(2026, 1, 2),
        selectedDate,
        reason:
            'Offset $offset maps local midnight to $utcInstantForLocalMidnight, '
            'but the selected civil date must remain $selectedDate.',
      );
    }
  });

  test('normalizes due date values to yyyy-mm-dd', () {
    expect(
      normalizeGoogleDueDateValue('2026-06-05T23:59:59.000Z'),
      '2026-06-05',
    );
    expect(normalizeGoogleDueDateValue('2026-06-05'), '2026-06-05');
  });
}
