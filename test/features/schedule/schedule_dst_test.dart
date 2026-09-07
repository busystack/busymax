import 'dart:io';

import 'package:busymax/src/features/schedule/presentation/schedule_month_view.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_localized_app.dart';
import '../../support/process_time_zone.dart';

void main() {
  final supportsPosixTimeZones = Platform.isLinux || Platform.isMacOS;

  group(
    'calendar ranges across daylight-saving transitions',
    skip: supportsPosixTimeZones
        ? false
        : 'This regression test requires POSIX setenv and tzset.',
    () {
      late ProcessTimeZone processTimeZone;

      setUpAll(() {
        processTimeZone = ProcessTimeZone();
        processTimeZone.set('America/Vancouver');
      });

      tearDownAll(() {
        processTimeZone.restore();
      });

      test('day ranges end at the next local midnight', () {
        final springForward = ScheduleRange.day(DateTime(2025, 3, 9));
        final fallBack = ScheduleRange.day(DateTime(2025, 11, 2));

        expect(springForward.start, DateTime(2025, 3, 9));
        expect(springForward.end, DateTime(2025, 3, 10));
        expect(springForward.end.difference(springForward.start).inHours, 23);

        expect(fallBack.start, DateTime(2025, 11, 2));
        expect(fallBack.end, DateTime(2025, 11, 3));
        expect(fallBack.end.difference(fallBack.start).inHours, 25);
      });

      test('week ranges retain civil midnights at both boundaries', () {
        final springForward = ScheduleRange.week(
          DateTime(2025, 3, 10),
          firstWeekday: DateTime.sunday,
        );
        final fallBack = ScheduleRange.week(
          DateTime(2025, 11, 3),
          firstWeekday: DateTime.sunday,
        );

        expect(springForward.start, DateTime(2025, 3, 9));
        expect(springForward.end, DateTime(2025, 3, 16));
        expect(springForward.end.difference(springForward.start).inHours, 167);

        expect(fallBack.start, DateTime(2025, 11, 2));
        expect(fallBack.end, DateTime(2025, 11, 9));
        expect(fallBack.end.difference(fallBack.start).inHours, 169);
      });

      test('month range retains civil midnight across its trailing days', () {
        final range = ScheduleRange.month(DateTime(2025, 10, 15));

        expect(range.start, DateTime(2025, 9, 29));
        expect(range.end, DateTime(2025, 11, 3));
      });

      testWidgets('month view emits every civil date exactly once', (
        tester,
      ) async {
        final selectedDays = <DateTime>[];

        await tester.pumpWidget(
          localizedTestApp(
            child: Scaffold(
              body: SizedBox(
                width: 1000,
                height: 720,
                child: ScheduleMonthView(
                  range: ScheduleRange(
                    start: DateTime(2025, 10, 27),
                    end: DateTime(2025, 11, 10),
                  ),
                  selectedDate: DateTime(2025, 11, 15),
                  items: const [],
                  firstWeekday: DateTime.monday,
                  onDaySelected: selectedDays.add,
                  onCreateAtDay: (_, {anchorContext}) {},
                  onItemSelected: (_, _, [_]) {},
                  onTaskCompletionChanged: (_, _) {},
                ),
              ),
            ),
          ),
        );

        final dayCells = tester
            .widgetList<InkWell>(
              find.descendant(
                of: find.byType(ScheduleMonthView),
                matching: find.byType(InkWell),
              ),
            )
            .where((cell) => cell.onDoubleTap != null);
        for (final cell in dayCells) {
          cell.onTap!();
        }

        expect(
          selectedDays,
          List<DateTime>.generate(
            14,
            (index) => DateTime(2025, 10, 27 + index),
          ),
        );
      });
    },
  );
}
