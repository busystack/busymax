import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sunday-first month query is the exact displayed 42-day grid', () {
    final range = androidMonthGridRange(
      DateTime(2026, 8, 19),
      firstWeekday: DateTime.sunday,
    );

    expect(range.start, DateTime(2026, 7, 26));
    expect(range.end, DateTime(2026, 9, 6));
    expect(_civilDays(range.start, range.end), 42);
  });

  test('Monday-first month query is the exact displayed 42-day grid', () {
    final range = androidMonthGridRange(
      DateTime(2026, 8, 19),
      firstWeekday: DateTime.monday,
    );

    expect(range.start, DateTime(2026, 7, 27));
    expect(range.end, DateTime(2026, 9, 7));
    expect(_civilDays(range.start, range.end), 42);
  });

  test('month grid advances by civil dates rather than 24-hour instants', () {
    final range = androidMonthGridRange(
      DateTime(2026, 11),
      firstWeekday: DateTime.sunday,
    );
    final days = [
      for (var index = 0; index < 42; index++)
        DateTime(range.start.year, range.start.month, range.start.day + index),
    ];

    expect(days.first, range.start);
    expect(
      DateTime(days.last.year, days.last.month, days.last.day + 1),
      range.end,
    );
    expect(
      days.map((day) => '${day.year}-${day.month}-${day.day}').toSet(),
      hasLength(42),
    );
  });

  test('year query covers every miniature adjacent-date cell', () {
    final range = androidYearGridRange(
      DateTime(2026),
      firstWeekday: DateTime.sunday,
    );

    expect(
      range.start,
      androidMonthGridRange(
        DateTime(2026, DateTime.january),
        firstWeekday: DateTime.sunday,
      ).start,
    );
    expect(
      range.end,
      androidMonthGridRange(
        DateTime(2026, DateTime.december),
        firstWeekday: DateTime.sunday,
      ).end,
    );
    expect(range.start.year, 2025);
    expect(range.end.year, 2027);
  });
}

int _civilDays(DateTime start, DateTime end) {
  var current = start;
  var count = 0;
  while (current.isBefore(end)) {
    current = DateTime(current.year, current.month, current.day + 1);
    count++;
  }
  return count;
}
