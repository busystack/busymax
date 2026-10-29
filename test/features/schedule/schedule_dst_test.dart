import 'dart:io';

import 'package:busymax/src/features/schedule/presentation/schedule_month_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_agenda_view.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_localized_app.dart';
import '../../support/process_time_zone.dart';

void main() {
  test('week and month boundaries support every first weekday', () {
    final anchor = DateTime(2028, 2, 29);
    for (
      var firstWeekday = DateTime.monday;
      firstWeekday <= DateTime.sunday;
      firstWeekday++
    ) {
      final week = ScheduleRange.week(anchor, firstWeekday: firstWeekday);
      final month = ScheduleRange.month(anchor, firstWeekday: firstWeekday);
      expect(week.start.weekday, firstWeekday);
      expect(
        week.end,
        DateTime(week.start.year, week.start.month, week.start.day + 7),
      );
      expect(month.start.weekday, firstWeekday);
      expect(month.end.weekday, firstWeekday);
      expect(month.start.isAfter(DateTime(2028, 2, 1)), isFalse);
      expect(month.end.isAfter(DateTime(2028, 2, 29)), isTrue);
    }
  });

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

      testWidgets(
        'Agenda horizons retain the final civil day across autumn DST',
        (tester) async {
          final start = DateTime(2026, 10, 23);
          for (final count in [30, 60]) {
            final range = ScheduleRange.days(start, count: count);
            expect(range.end, DateTime(2026, 10, 23 + count));
            expect(range.end.hour, 0);
            final finalDay = DateTime(2026, 10, 22 + count, 12);
            await tester.pumpWidget(
              localizedTestApp(
                child: Scaffold(
                  body: ScheduleAgendaView(
                    range: range,
                    items: [
                      CalendarScheduleItem(
                        id: 'last-day',
                        accountId: 'account',
                        provider: BusyProvider.google,
                        sourceId: 'calendar',
                        providerCalendarId: 'calendar',
                        title: 'Final loaded day',
                        allDay: false,
                        start: finalDay,
                        end: finalDay.add(const Duration(hours: 1)),
                      ),
                    ],
                    onItemSelected: (_, _, [_]) {},
                    onTaskCompletionChanged: (_, _) {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Final loaded day'), findsOneWidget);
          }
        },
      );

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
        final range = ScheduleRange.month(
          DateTime(2025, 10, 15),
          firstWeekday: DateTime.monday,
        );

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
