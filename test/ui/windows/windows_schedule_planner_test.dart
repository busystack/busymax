import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/ui/windows/windows_schedule_day_week_view.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../support/schedule_planner_gesture_suite.dart';
import '../../support/schedule_date_gesture_suite.dart';

void main() {
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
