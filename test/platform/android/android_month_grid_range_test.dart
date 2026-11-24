import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter/rendering.dart';
import 'package:busymax/src/ui/common/schedule/schedule_year_view.dart';
import 'package:busymax/src/ui/common/schedule/mini_calendar.dart';

import '../../test_localized_app.dart';

void main() {
  testWidgets('Year keeps complete date numbers at 800 wide and 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final selected = <DateTime>[];
    await tester.pumpWidget(
      localizedTestApp(
        textScaler: const TextScaler.linear(2),
        child: Scaffold(
          body: ScheduleYearView(
            selectedDate: DateTime(2026, 11, 16),
            items: const [],
            firstWeekday: DateTime.monday,
            onDaySelected: selected.add,
            onMonthSelected: (_) {},
            onWeekSelected: (_) {},
            onCreateAtDay: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final january = find.byWidgetPredicate(
      (w) => w is YearMonthMiniCalendar && w.displayedMonth.month == 1,
    );
    for (final number in ['12', '28', '31']) {
      final dates = find.descendant(of: january, matching: find.text(number));
      expect(dates, findsWidgets);
      for (final element in dates.evaluate()) {
        final paragraph = element.findRenderObject()! as RenderParagraph;
        final boxes = paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 2),
        );
        expect(boxes, hasLength(1), reason: '$number must remain on one line.');
        final marker = tester.getRect(
          find
              .ancestor(
                of: find.byElementPredicate(
                  (candidate) => candidate == element,
                ),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        final right = paragraph.localToGlobal(Offset(boxes.single.right, 0)).dx;
        final left = paragraph.localToGlobal(Offset(boxes.single.left, 0)).dx;
        expect(right, lessThanOrEqualTo(marker.right + .5));
        expect(left, greaterThanOrEqualTo(marker.left - .5));
      }
    }
    await tester.tap(find.descendant(of: january, matching: find.text('12')));
    await tester.pumpAndSettle();
    expect(selected, [DateTime(2026, 1, 12)]);
    expect(tester.takeException(), isNull);
  });

  test('Sunday-first month query includes all six required August weeks', () {
    final range = androidMonthGridRange(
      DateTime(2026, 8, 19),
      firstWeekday: DateTime.sunday,
    );

    expect(range.start, DateTime(2026, 7, 26));
    expect(range.end, DateTime(2026, 9, 6));
    expect(_civilDays(range.start, range.end), 42);
  });

  test(
    'Monday-first month query includes only the five required June weeks',
    () {
      final range = androidMonthGridRange(
        DateTime(2026, 6, 19),
        firstWeekday: DateTime.monday,
      );

      expect(range.start, DateTime(2026, 6));
      expect(range.end, DateTime(2026, 7, 6));
      expect(_civilDays(range.start, range.end), 35);
    },
  );

  test('a four-week February has four rows', () {
    final range = androidMonthGridRange(
      DateTime(2021, 2),
      firstWeekday: DateTime.monday,
    );
    expect(range.start, DateTime(2021, 2));
    expect(range.end, DateTime(2021, 3));
    expect(_civilDays(range.start, range.end), 28);
  });

  test('month grid advances by civil dates rather than 24-hour instants', () {
    final range = androidMonthGridRange(
      DateTime(2026, 11),
      firstWeekday: DateTime.sunday,
    );
    final days = [
      for (var index = 0; index < _civilDays(range.start, range.end); index++)
        DateTime(range.start.year, range.start.month, range.start.day + index),
    ];

    expect(days.first, range.start);
    expect(
      DateTime(days.last.year, days.last.month, days.last.day + 1),
      range.end,
    );
    expect(
      days.map((day) => '${day.year}-${day.month}-${day.day}').toSet(),
      hasLength(35),
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
      ).start.add(const Duration(days: 42)),
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
