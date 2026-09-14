import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'month overflow opens every item and supports keyboard activation at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final items = [for (var i = 0; i < 8; i++) _event('Event $i')];
        ScheduleItem? opened;
        await tester.pumpWidget(
          _app(
            WindowsScheduleMonthView(
              selectedDate: _day,
              range: ScheduleRange.month(_day),
              items: items,
              locale: 'en',
              onOpen: (item) => opened = item,
              onSelectDate: (_) {},
              onReschedule: (_, _) async {},
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        final overflow = find.byKey(const ValueKey('month-overflow-2026-9-14'));
        await tester.ensureVisible(overflow);
        await tester.tap(overflow);
        await tester.pumpAndSettle();
        expect(find.byType(ContentDialog), findsOneWidget);
        final last = find.descendant(
          of: find.byType(ContentDialog),
          matching: find.text('Event 7'),
        );
        await tester.scrollUntilVisible(
          last,
          100,
          scrollable: find.descendant(
            of: find.byType(ContentDialog),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(opened?.id, 'Event 7');
        // Focused overflow is operable without a pointer.
        Focus.of(
          tester.element(
            find.descendant(of: overflow, matching: find.byType(Text)).first,
          ),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(ContentDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('month shows more items when more vertical space is available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final items = [for (var i = 0; i < 8; i++) _event('Event $i')];
    Widget month(double height) => _app(
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: height,
          child: WindowsScheduleMonthView(
            selectedDate: _day,
            range: ScheduleRange.month(_day),
            items: items,
            locale: 'en',
            onOpen: (_) {},
            onSelectDate: (_) {},
            onReschedule: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(month(400));
    await tester.pumpAndSettle();
    final small = find.textContaining('Event ').evaluate().length;
    await tester.pumpWidget(month(1000));
    await tester.pumpAndSettle();
    expect(find.textContaining('Event ').evaluate().length, greaterThan(small));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'year provides valid mini-calendar days, span markers and exact date selection',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      DateTime? selected;
      await tester.pumpWidget(
        _app(
          WindowsScheduleYearView(
            selectedDate: DateTime(2026, 1, 1),
            items: [
              _event(
                'Spanning event',
                start: DateTime(2026, 1, 30),
                end: DateTime(2026, 2, 3),
              ),
            ],
            locale: 'en',
            onSelectDate: (date) => selected = date,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('year-day-2026-2-29')), findsNothing);
      final day = find.byKey(const ValueKey('year-day-2026-2-2'));
      expect(
        find.ancestor(
          of: day,
          matching: find.byWidgetPredicate(
            (w) => w is Tooltip && (w.message?.contains('1 item') ?? false),
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(day);
      await tester.pumpAndSettle();
      expect(selected, DateTime(2026, 2, 2));
      expect(tester.takeException(), isNull);
    },
  );
}

final _day = DateTime(2026, 9, 14);
CalendarScheduleItem _event(String id, {DateTime? start, DateTime? end}) =>
    CalendarScheduleItem(
      id: id,
      accountId: 'account',
      sourceId: 'source',
      provider: BusyProvider.google,
      providerCalendarId: 'calendar',
      title: id,
      allDay: true,
      colorHex: '#cc3300',
      sourceName: 'Work',
      start: start ?? _day,
      end: end ?? DateTime(2026, 9, 15),
    );
Widget _app(Widget child, {double scale = 1}) => FluentApp(
  localizationsDelegates: const [AppLocalizations.delegate],
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: ScaffoldPage(content: child),
);
