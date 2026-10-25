import 'package:busymax/src/features/schedule/presentation/schedule_agenda_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_month_view.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../test_localized_app.dart';

void main() {
  setUpAll(initializeDateFormatting);
  for (final allDay in [false, true]) {
    for (final month in [false, true]) {
      testWidgets(
        '${month ? 'month' : 'ordinary agenda'} keeps an ongoing ${allDay ? 'all-day' : 'timed'} event',
        (tester) async {
          final range = ScheduleRange(
            start: DateTime(2026, 6, 1),
            end: DateTime(2026, 6, 8),
          );
          final event = CalendarScheduleItem(
            id: 'ongoing',
            accountId: 'account',
            provider: BusyProvider.google,
            sourceId: 'calendar',
            providerCalendarId: 'calendar',
            title: 'Ongoing event',
            allDay: allDay,
            start: DateTime(2026, 5, 31, allDay ? 0 : 22),
            end: DateTime(2026, 6, 3),
          );
          ScheduleItem? opened;
          final view = month
              ? ScheduleMonthView(
                  range: range,
                  selectedDate: DateTime(2026, 6, 1),
                  firstWeekday: DateTime.monday,
                  items: [event],
                  onDaySelected: (_) {},
                  onCreateAtDay: (_, {anchorContext}) {},
                  onItemSelected: (_, item, [_]) => opened = item,
                  onTaskCompletionChanged: (_, _) {},
                )
              : ScheduleAgendaView(
                  range: range,
                  items: [event],
                  onItemSelected: (_, item, [_]) => opened = item,
                  onTaskCompletionChanged: (_, _) {},
                );
          await tester.pumpWidget(
            localizedTestApp(child: Scaffold(body: view)),
          );
          await tester.pumpAndSettle();
          expect(find.text('Ongoing event'), findsNWidgets(month ? 2 : 1));
          await tester.tap(find.text('Ongoing event').first);
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
          expect(opened, same(event));
          expect(opened!.start, event.start);
          expect(opened!.end, DateTime(2026, 6, 3));
        },
      );
    }
  }
}
