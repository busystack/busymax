import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/ui/windows/windows_schedule_day_week_view.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:busymax/src/l10n/time_format_scope.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;

import '../../support/schedule_planner_gesture_suite.dart';
import '../../support/schedule_date_gesture_suite.dart';

void main() {
  testWidgets(
    'Windows rulers repaint clock changes without replacing planner state',
    (tester) async {
      State? state;
      icv.HoursPainter? previous;
      for (final use24 in [false, true, false]) {
        await tester.pumpWidget(
          FluentApp(
            locale: const Locale('de'),
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => BusyMaxTimeFormatScope(
              formatter: BusyMaxTimeFormatter(locale: 'de', use24Hour: use24),
              child: child!,
            ),
            home: ScaffoldPage(
              content: WindowsScheduleDayWeekView(
                initialDate: PlannerGestureScenario.day,
                daysShowed: 1,
                items: const [],
                onOpen: (_) {},
                onSelectDate: (_) {},
                onVisibleDateChanged: (_) {},
                onEmptySlot: (_) {},
                onRangeCreated: (_) {},
                onReschedule: (_, _) async {},
                onTaskCompletionChanged: (_, _) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        state ??= tester.state(find.byType(WindowsScheduleDayWeekView));
        expect(
          tester.state(find.byType(WindowsScheduleDayWeekView)),
          same(state),
        );
        final planner = tester.widget<icv.EventsPlanner>(
          find.byType(icv.EventsPlanner),
        );
        final painter =
            planner.timesIndicatorsParam.timesIndicatorsCustomPainter!(.9)
                as icv.HoursPainter;
        final label = painter.textPainterBuilder!(
          const TimeOfDay(hour: 14, minute: 37),
          Colors.black,
        );
        expect(label.text!.toPlainText(), use24 ? '14:37' : '2:37 PM');
        label.layout();
        expect(
          planner.timesIndicatorsParam.timesIndicatorsWidth,
          greaterThan(label.width),
        );
        label.dispose();
        final midnight = painter.textPainterBuilder!(
          const TimeOfDay(hour: 24, minute: 0),
          Colors.black,
        );
        expect(midnight.text!.toPlainText(), use24 ? '00:00' : '12:00 AM');
        midnight.dispose();
        if (previous != null) expect(painter.shouldRepaint(previous), isTrue);
        previous = painter;
      }
    },
  );
  scheduleDateGestureTests(
    'Windows',
    (scenario) => FluentApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ScaffoldPage(
        content: WindowsScheduleMonthView(
          selectedDate: PlannerGestureScenario.day,
          range: ScheduleRange.month(PlannerGestureScenario.day),
          items: scenario.items,
          locale: 'en',
          onOpen: scenario.opened.add,
          onSelectDate: (_) {},
          onReschedule: scenario.save,
        ),
      ),
    ),
  );
  schedulePlannerGestureTests(
    'Windows',
    (scenario) => FluentApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ScaffoldPage(
        content: Directionality(
          textDirection: scenario.rtl ? TextDirection.rtl : TextDirection.ltr,
          child: WindowsScheduleDayWeekView(
            initialDate: PlannerGestureScenario.day,
            daysShowed: scenario.days,
            items: scenario.items,
            onOpen: scenario.opened.add,
            onSelectDate: (_) {},
            onVisibleDateChanged: (_) {},
            onEmptySlot: scenario.clicks.add,
            onRangeCreated: scenario.selections.add,
            onReschedule: scenario.save,
            onTaskCompletionChanged: (_, value) =>
                scenario.completed.add(value),
          ),
        ),
      ),
    ),
  );
}
