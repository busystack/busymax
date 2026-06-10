import 'dart:io';

import 'package:busymax/src/features/schedule/presentation/schedule_agenda_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_day_week_view.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_event_block.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_item_chip.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_item_details_popover.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_item_exporter.dart';
import 'package:busymax/src/features/schedule/presentation/mini_calendar.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_month_view.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;

import '../../../test_localized_app.dart';

void main() {
  testWidgets('day view uses package planner with custom BusyMax items', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleDayWeekView(
              range: ScheduleRange.day(selectedDate),
              selectedDate: selectedDate,
              daysShowed: 1,
              items: _itemsFor(selectedDate),
              onDaySelected: (_) {},
              onEmptySlot: (_) {},
              onItemSelected: (_, _) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(icv.EventsPlanner), findsOneWidget);
    expect(find.text('Design review', skipOffstage: false), findsOneWidget);
    expect(find.text('Submit report', skipOffstage: false), findsOneWidget);
    expect(find.byType(icv.EventsMonths), findsNothing);
    expect(find.byType(icv.EventsList), findsNothing);
  });

  testWidgets('short overlapping event block does not overflow', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final item = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Center(
            child: ScheduleEventBlock(item: item, width: 120, height: 22),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Design review'), findsOneWidget);
  });

  testWidgets('event and task chips tolerate negative planner widths', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final items = _itemsFor(selectedDate);
    final event = items.whereType<CalendarScheduleItem>().first;
    final task = items.whereType<TaskScheduleItem>().first;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Column(
            children: [
              ScheduleEventBlock(item: event, width: -331.6, height: 54),
              ScheduleItemChip(item: task, width: -331.6, height: 54),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  test('all-day bar uses rendered range and collapses without items', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('final fullDayBarHeight = showFullDayBar ? 82.0 : 0.0;'),
    );
    expect(source, contains('fullDayEventsBarVisibility: showFullDayBar'));
    expect(source, contains('fullDayEventsBarHeight: fullDayBarHeight'));
    expect(source, contains('fullDayEventHeight: showFullDayBar ? 24 : 0'));
    expect(source, contains('final displayEnd = _endOfDay('));
    expect(source, contains('endTime: displayEnd'));
    expect(source, contains('final visibleStart = _plannerStartDate(widget);'));
    expect(source, contains('final visibleRange = ScheduleRange('));
    expect(
      source,
      contains('end: visibleStart.add(Duration(days: widget.daysShowed))'),
    );
  });

  testWidgets('month view is a custom BusyMax grid with merged chips', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleMonthView(
              range: ScheduleRange.month(selectedDate),
              selectedDate: selectedDate,
              firstWeekday: DateTime.monday,
              items: _itemsFor(selectedDate),
              onDaySelected: (_) {},
              onCreateAtDay: (_) {},
              onItemSelected: (_, _) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(icv.EventsMonths), findsNothing);
    expect(find.text('Design review'), findsOneWidget);
    expect(find.text('Submit report'), findsOneWidget);
  });

  testWidgets('calendar schedule chip invokes calendar item tap', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    ScheduleItem? selectedItem;
    final event = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Center(
            child: ScheduleItemChip(
              item: event,
              height: 34,
              onTap: (_) => selectedItem = event,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ScheduleEventBlock).first);

    expect(selectedItem, isA<CalendarScheduleItem>());
  });

  testWidgets('schedule item details popover offers export and edit', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final event = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;
    Future<ScheduleItemDetailsAction?>? action;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  action = showScheduleItemDetailsPopover(
                    context: context,
                    anchorContext: context,
                    item: event,
                  );
                },
                child: const Text('Open details'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();

    expect(find.text('Design review'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Export'), findsNothing);
    expect(find.text('Edit event'), findsNothing);

    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pumpAndSettle();

    expect(await action, ScheduleItemDetailsAction.export);
  });

  testWidgets('schedule item details popover closes from empty space', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);
    final event = _itemsFor(
      selectedDate,
    ).whereType<CalendarScheduleItem>().first;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showScheduleItemDetailsPopover(
                    context: context,
                    anchorContext: context,
                    item: event,
                  );
                },
                child: const Text('Open details'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('Design review'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Design review'), findsNothing);
  });

  test('schedule item export writes event and task iCalendar payloads', () {
    final event = CalendarScheduleItem(
      id: 'event:1',
      accountId: 'google:g',
      provider: TaskProvider.google,
      sourceId: 'calendar:primary',
      providerCalendarId: 'primary',
      title: 'Review, plan',
      allDay: false,
      start: DateTime.utc(2026, 1, 15, 16),
      end: DateTime.utc(2026, 1, 15, 17),
      location: 'Room 1',
      description: 'Line 1\nLine 2',
    );
    final task = TaskScheduleItem(
      id: 'task:1',
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      sourceId: 'tasks:inbox',
      title: 'Submit report',
      completed: true,
      allDay: true,
      start: DateTime.utc(2026, 1, 16),
      notes: 'Done',
    );

    final eventPayload = scheduleItemToICalendar(
      event,
      nowUtc: DateTime.utc(2026, 1, 1),
    );
    final taskPayload = scheduleItemToICalendar(
      task,
      nowUtc: DateTime.utc(2026, 1, 1),
    );

    expect(eventPayload, contains('BEGIN:VEVENT'));
    expect(eventPayload, contains(r'SUMMARY:Review\, plan'));
    expect(eventPayload, contains('DTSTART:20260115T160000Z'));
    expect(eventPayload, contains('DTEND:20260115T170000Z'));
    expect(eventPayload, contains(r'DESCRIPTION:Line 1\nLine 2'));
    expect(taskPayload, contains('BEGIN:VTODO'));
    expect(taskPayload, contains('DUE;VALUE=DATE:20260116'));
    expect(taskPayload, contains('STATUS:COMPLETED'));
    expect(scheduleExportFileName(event), endsWith('.ics'));
  });

  test('month weekday header uses calendar surface background', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_month_view.dart',
    ).readAsStringSync();

    expect(source, contains('ColoredBox('));
    expect(source, contains('color: theme.colorScheme.surface'));
  });

  testWidgets('agenda view is custom and keeps no-date tasks', (tester) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleAgendaView(
              range: ScheduleRange.week(selectedDate),
              items: [
                ..._itemsFor(selectedDate),
                const TaskScheduleItem(
                  id: 'task:no-date',
                  accountId: 'google:g',
                  provider: TaskProvider.google,
                  sourceId: 'tasks:inbox',
                  title: 'Plan someday',
                  completed: false,
                  allDay: true,
                  sourceName: 'Inbox',
                ),
              ],
              onItemSelected: (_, _) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(icv.EventsList), findsNothing);
    expect(find.text('Design review'), findsOneWidget);
    expect(find.text('Submit report'), findsOneWidget);
    expect(find.text('No date'), findsOneWidget);
    expect(find.text('Plan someday'), findsOneWidget);
  });

  testWidgets('agenda view stays blank instead of showing empty-state card', (
    tester,
  ) async {
    final selectedDate = DateTime(2026, 1, 15);

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 720,
            child: ScheduleAgendaView(
              range: ScheduleRange.week(selectedDate),
              items: const [],
              onItemSelected: (_, _) {},
              onTaskCompletionChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('No events or tasks'), findsNothing);
    expect(find.text('New event'), findsNothing);
    expect(find.text('New task'), findsNothing);
  });

  test('schedule presentation does not use banned package final UI', () {
    final files = Directory(
      'lib/src/features/schedule/presentation',
    ).listSync().whereType<File>();
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('EventsMonths')));
      expect(source, isNot(contains('EventsList')));
      expect(source, isNot(contains('DefaultDayEvent')));
    }
  });

  test('Today toolbar action preserves current display mode', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('onToday: _goToToday'));
    expect(source, contains('BusyMaxHeaderBarAction.today'));
    expect(
      source,
      isNot(contains('onToday: () => _selectScope(ScheduleScope.today)')),
    );
  });

  test('schedule workspace uses Flutter toolbar only as native fallback', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('linuxHeaderBarServiceProvider'));
    expect(source, contains('final showFallbackHeader'));
    expect(source, contains('if (showFallbackHeader)'));
    expect(source, contains('setTitleRange(headerBarState.titleRange)'));
    expect(source, contains('setViewMode(headerBarState.viewMode)'));
  });

  test('native headerbar actions are wired to schedule commands', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('BusyMaxHeaderBarAction.previous'));
    expect(source, contains('BusyMaxHeaderBarAction.next'));
    expect(source, contains('BusyMaxHeaderBarAction.viewModeDay'));
    expect(source, contains('BusyMaxHeaderBarAction.viewModeWeek'));
    expect(source, contains('BusyMaxHeaderBarAction.viewModeMonth'));
    expect(source, contains('BusyMaxHeaderBarAction.viewModeYear'));
    expect(source, contains('BusyMaxHeaderBarAction.viewModeAgenda'));
    expect(source, contains('BusyMaxHeaderBarAction.refresh'));
    expect(source, contains('allAccountsSyncRunnerProvider'));
    expect(source, contains('context.l10n.allTasksRefreshed'));
    expect(source, contains('setScheduleViewMode(mode)'));
    expect(source, contains('settings.scheduleViewMode'));
    expect(source, isNot(contains('ScheduleEmptyState')));
    expect(source, isNot(contains('BusyMaxHeaderBarAction.newItem')));
    expect(source, isNot(contains('BusyMaxHeaderBarAction.openMenu')));
  });

  test('calendar event mutations request immediate account sync', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('calendarRepositoryProvider).updateLocalEvent'));
    expect(source, contains('_requestCalendarMutationSync(draft.accountId)'));
    expect(source, contains('.deleteLocalEvent(eventId)'));
    expect(source, contains('_requestCalendarMutationSync(accountId)'));
    expect(source, contains('calendarSyncEngineForAccountFactoryProvider'));
    expect(source, isNot(contains('signedInSyncRunnerProvider)(accountId')));
  });

  test('schedule item clicks route through details popover before edit', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('showScheduleItemDetailsPopover('));
    expect(source, contains('ScheduleItemDetailsAction.export'));
    expect(source, contains('ScheduleItemDetailsAction.edit'));
    expect(source, contains('exportScheduleItemWithSaveDialog(item)'));
    expect(source, isNot(contains('exportScheduleItemToDownloads(item)')));
    expect(source, contains('void _editItem('));
  });

  test(
    'schedule search renders query results instead of current range only',
    () {
      final workspace = File(
        'lib/src/features/schedule/presentation/schedule_workspace.dart',
      ).readAsStringSync();
      final agenda = File(
        'lib/src/features/schedule/presentation/schedule_agenda_view.dart',
      ).readAsStringSync();
      final repository = File(
        'lib/src/schedule/schedule_repository.dart',
      ).readAsStringSync();

      expect(
        workspace,
        contains('final searchHasQuery = _searchQuery.trim().isNotEmpty'),
      );
      expect(workspace, contains('_rangeForSearchResults(items, range)'));
      expect(
        workspace,
        contains(
          'searchHasQuery\n                    ? ScheduleViewMode.agenda',
        ),
      );
      expect(
        repository,
        contains('final searching = filters.query.trim().isNotEmpty'),
      );
      expect(repository, contains('!searching && !_intersects'));
      expect(agenda, contains('groups.keys'));
      expect(agenda, contains('ColoredBox('));
      expect(agenda, contains('color: Theme.of(context).colorScheme.surface'));
      expect(agenda, isNot(contains('_daysInRange')));
    },
  );

  test('sidebar does not render redundant provider group titles', () {
    final sidebar = File(
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
    ).readAsStringSync();
    final nativeRunner = File(
      'linux/runner/my_application.cc',
    ).readAsStringSync();

    expect(nativeRunner, contains('header_sidebar_brand_box'));
    expect(nativeRunner, contains('gtk_label_new(kApplicationDisplayName)'));
    expect(nativeRunner, isNot(contains('busymax-sidebar-header')));
    expect(nativeRunner, isNot(contains('GtkWidget* brand_box')));
    expect(sidebar, isNot(contains('title: account.provider.displayName')));
    expect(sidebar, isNot(contains('YaruIcons.globe')));
    expect(sidebar, isNot(contains('Icons.account_circle_outlined')));
  });

  test('sidebar account rows are accordions', () {
    final sidebar = File(
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
    ).readAsStringSync();

    expect(sidebar, contains('class _AccountSourcesGroupState'));
    expect(sidebar, contains('var _expanded = true'));
    expect(sidebar, contains('class _AccountHeaderRow'));
    expect(sidebar, contains('AnimatedRotation'));
    expect(sidebar, contains('YaruIcons.pan_end'));
    expect(sidebar, contains('if (_expanded)'));
    expect(sidebar, isNot(contains('BusyMaxGroupedList(')));
    expect(sidebar, isNot(contains('hoverColor: Colors.transparent')));
  });

  test('mini calendar has separate month and year steppers', () {
    final source = File(
      'lib/src/features/schedule/presentation/mini_calendar.dart',
    ).readAsStringSync();

    expect(source, contains('class _MiniCalendarStepper'));
    expect(source, contains('required this.onMonthSelected'));
    expect(source, contains('required this.onYearSelected'));
    expect(source, contains('required this.onWeekSelected'));
    expect(source, contains('required this.firstWeekday'));
    expect(
      source,
      contains('(first.weekday - firstWeekday) % DateTime.daysPerWeek'),
    );
    expect(source, contains('final weekNumberExtent = math.min'));
    expect(source, contains('constraints.maxWidth - weekNumberExtent'));
    expect(source, isNot(contains('final calendarWidth =')));
    expect(source, contains('class _MiniCalendarWeekRow'));
    expect(source, contains('class _MiniCalendarWeekNumberButton'));
    expect(source, contains('class _MiniCalendarDayButton'));
    expect(source, contains('class _MiniCalendarDayIndicators'));
    expect(
      source,
      contains('final groupedItems = ScheduleProjection.groupByDay(items)'),
    );
    expect(source, contains('DateFormat.E('));
    expect(source, contains('_weekdays(firstWeekday)'));
    expect(source, contains('DateFormat.yMMMMEEEEd(locale)'));
    expect(source, contains('ScheduleProjection.colorForItem'));
    expect(source, contains('height: dayExtent'));
    expect(source, contains('width: double.infinity'));
    expect(source, contains('crossAxisAlignment: CrossAxisAlignment.stretch'));
    expect(source, contains('SizedBox(width: weekNumberExtent)'));
    expect(
      source,
      contains('for (var column = 0; column < DateTime.daysPerWeek; column++)'),
    );
    expect(source, isNot(contains('GridView.builder')));
    expect(source, contains('const SizedBox(width: BusyMaxSpacing.xs)'));
    expect(source, contains('label: _monthName(selectedDate)'));
    expect(source, contains('BusyMaxSpacing.headerInset'));
    expect(
      source,
      isNot(contains('padding: const EdgeInsets.all(BusyMaxSpacing.md)')),
    );
    expect(source, contains("labelTooltip: 'Open month'"));
    expect(source, contains('onMonthSelected(first)'));
    expect(source, contains('busyMaxHeaderTextButtonStyle'));
    expect(source, contains("label: '\${selectedDate.year}'"));
    expect(source, contains("labelTooltip: 'Open year'"));
    expect(source, contains('onYearSelected('));
    expect(source, contains('String _monthName(DateTime date)'));
    expect(source, contains('return months[date.month - 1];'));
    expect(
      source,
      isNot(contains("return '\${months[date.month - 1]} \${date.year}';")),
    );
    expect(source, contains("'Previous month'"));
    expect(source, contains("'Next month'"));
    expect(source, contains("'Previous year'"));
    expect(source, contains("'Next year'"));
    expect(source, contains('selectedDate.year - 1'));
    expect(source, contains('selectedDate.year + 1'));
    expect(source, contains('busyMaxHeaderIconButtonStyle'));
    expect(source, contains('miniCalendarWeekButton'));
    expect(source, contains('busyMaxHeaderButtonBackground(context)'));
    expect(source, isNot(contains('busyMaxSubtleButtonBackground(context)')));
    expect(source, contains('_isoWeekNumber'));
    expect(source, contains('DateTime.daysPerWeek'));
    expect(source, contains('TextButton('));
    expect(source, contains("message: 'Week \$weekNumber'"));
    expect(source, contains('onSelected(weekStart)'));
    expect(source, contains('BoxShape.circle'));
    expect(source, contains('customBorder: const CircleBorder()'));
    expect(source, contains('final markerSize = math.min'));
    expect(source, contains('final highlightToday = today && currentMonth'));
    expect(source, contains('color: highlightToday'));
    expect(source, contains('selectedYear == DateTime.now().year'));
    expect(source, contains('selectedMonth == DateTime.now().month'));
    expect(
      source,
      isNot(contains('final selected = _sameDay(day, selectedDate)')),
    );
    expect(source, isNot(contains('YaruIcons.arrow_left')));
    expect(source, isNot(contains('YaruIcons.arrow_right')));
    expect(source, isNot(contains('BorderRadius.circular(BusyMaxRadius.sm)')));
  });

  testWidgets('mini calendar week number selects that week', (tester) async {
    DateTime? selectedWeek;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 300,
            child: MiniCalendar(
              selectedDate: DateTime(2026, 1, 15),
              firstWeekday: DateTime.monday,
              onSelected: (_) {},
              onMonthSelected: (_) {},
              onYearSelected: (_) {},
              onWeekSelected: (weekStart) => selectedWeek = weekStart,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Week 3'));

    expect(selectedWeek, DateTime(2026, 1, 12));
  });

  testWidgets('mini calendar week number honors first weekday', (tester) async {
    DateTime? selectedWeek;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 300,
            child: MiniCalendar(
              selectedDate: DateTime(2026, 1, 15),
              firstWeekday: DateTime.sunday,
              onSelected: (_) {},
              onMonthSelected: (_) {},
              onYearSelected: (_) {},
              onWeekSelected: (weekStart) => selectedWeek = weekStart,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Week 1'));

    expect(selectedWeek, DateTime(2026, 1, 4));
  });

  testWidgets('mini calendar month label selects that month', (tester) async {
    DateTime? selectedMonth;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 300,
            child: MiniCalendar(
              selectedDate: DateTime(2026, 5, 15),
              firstWeekday: DateTime.monday,
              onSelected: (_) {},
              onMonthSelected: (month) => selectedMonth = month,
              onYearSelected: (_) {},
              onWeekSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open month'));

    expect(selectedMonth, DateTime(2026, 5));
  });

  testWidgets('mini calendar year label selects that year', (tester) async {
    DateTime? selectedYear;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 300,
            child: MiniCalendar(
              selectedDate: DateTime(2026, 5, 15),
              firstWeekday: DateTime.monday,
              onSelected: (_) {},
              onMonthSelected: (_) {},
              onYearSelected: (year) => selectedYear = year,
              onWeekSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open year'));

    expect(selectedYear, DateTime(2026));
  });

  test('sidebar mini calendar opens month and week modes', () {
    final sidebar = File(
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
    ).readAsStringSync();
    final workspace = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(sidebar, contains('required this.firstWeekday'));
    expect(sidebar, contains('firstWeekday: firstWeekday'));
    expect(workspace, contains('firstWeekday: _firstWeekday(context)'));
    expect(workspace, contains('final miniCalendarItemsFuture = ref'));
    expect(workspace, contains('ScheduleRange.month('));
    expect(workspace, contains('showNoDateTasks: false'));
    expect(workspace, contains('items: miniCalendarItems'));
    expect(sidebar, contains('required this.onMonthSelected'));
    expect(sidebar, contains('required this.onYearSelected'));
    expect(sidebar, contains('required this.onWeekSelected'));
    expect(sidebar, contains('onMonthSelected: onMonthSelected'));
    expect(sidebar, contains('onYearSelected: onYearSelected'));
    expect(sidebar, contains('onWeekSelected: onWeekSelected'));
    expect(workspace, contains('onMonthSelected: _setMonth'));
    expect(workspace, contains('onYearSelected: _setYear'));
    expect(workspace, contains('onWeekSelected: _setWeek'));
    expect(workspace, contains('void _setMonth(DateTime month)'));
    expect(workspace, contains('void _setYear(DateTime year)'));
    expect(workspace, contains('void _setWeek(DateTime weekStart)'));
    expect(workspace, contains('_mode = ScheduleViewMode.month'));
    expect(workspace, contains('_mode = ScheduleViewMode.year'));
    expect(workspace, contains('_mode = ScheduleViewMode.week'));
    expect(workspace, contains('setScheduleViewMode(ScheduleViewMode.month)'));
    expect(workspace, contains('setScheduleViewMode(ScheduleViewMode.year)'));
    expect(workspace, contains('setScheduleViewMode(ScheduleViewMode.week)'));
  });

  test('sidebar source rows keep visibility actions on the right', () {
    final sidebar = File(
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
    ).readAsStringSync();

    expect(sidebar, contains('class _CompactSourceRow'));
    expect(sidebar, contains('class _SourceRowActions'));
    expect(sidebar, contains('class _SourceVisibilityButton'));
    expect(sidebar, contains('visibilityButton: _SourceVisibilityButton'));
    expect(sidebar, contains('menuButton: BusyMaxMenuButton'));
    expect(sidebar, contains('tooltip: context.l10n.options'));
    expect(sidebar, contains('value ? context.l10n.hide : context.l10n.show'));
    expect(sidebar, isNot(contains('tooltip: context.l10n.sourceCalendar')));
    expect(sidebar, isNot(contains('tooltip: context.l10n.sourceTaskList')));
    expect(sidebar, isNot(contains('? context.l10n.hideFromSchedule')));
    expect(sidebar, isNot(contains(': context.l10n.showInSchedule')));
    expect(sidebar, contains('minHeight: BusyMaxSizes.sidebarRowHeight'));
    expect(sidebar, contains('YaruIcons.checkmark'));
    expect(sidebar, contains('busyMaxSubtleButtonBackground(context)'));
    expect(sidebar, isNot(contains('YaruIcons.checkbox')));
    expect(sidebar, isNot(contains('InkWell(')));
    expect(sidebar, isNot(contains('_SourceVisibilityIndicator')));
  });

  test('schedule create action is a bottom-right floating plus button', () {
    final workspace = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();
    final sidebar = File(
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
    ).readAsStringSync();
    final toolbar = File(
      'lib/src/features/schedule/presentation/schedule_toolbar.dart',
    ).readAsStringSync();

    expect(workspace, contains('floatingActionButtonLocation'));
    expect(workspace, contains('FloatingActionButtonLocation.endFloat'));
    expect(workspace, contains('floatingActionButton: FloatingActionButton'));
    expect(workspace, contains('child: const Icon(YaruIcons.plus)'));
    expect(workspace, isNot(contains('BusyMaxHeaderBarAction.newItem')));
    expect(sidebar, isNot(contains('context.l10n.create')));
    expect(sidebar, isNot(contains('PushButton.filled')));
    expect(toolbar, isNot(contains('BusyMaxMenuButton<String>')));
  });

  test('day and week today tint stays subtle', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'final todayOverlayAlpha = widget.daysShowed == 1 ? 0.0 : 0.035',
      ),
    );
    expect(source, isNot(contains('alpha: 0.07')));
  });

  test('day mode removes weekday date header but keeps week headers', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('daysHeaderHeight: widget.daysShowed == 1 ? 0 : 50'),
    );
    expect(
      source,
      contains('widget.daysShowed == 1\n            ? const SizedBox.shrink()'),
    );
    expect(source, contains('_PlannerDayHeader(day: day, isToday: isToday)'));
  });

  test('schedule chips keep grid metadata out of inline text', () {
    final eventBlock = File(
      'lib/src/features/schedule/presentation/schedule_event_block.dart',
    ).readAsStringSync();
    final taskChip = File(
      'lib/src/features/schedule/presentation/schedule_task_chip.dart',
    ).readAsStringSync();

    expect(eventBlock, contains('showTime'));
    expect(eventBlock, contains('_tooltipDetails'));
    expect(eventBlock, isNot(contains('details,\n')));
    expect(taskChip, contains('Tooltip'));
    expect(taskChip, isNot(contains('if (!compact)')));
  });

  test('day and week planner jumps when selected date changes', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
    ).readAsStringSync();

    expect(source, contains('final _plannerKey = GlobalKey'));
    expect(source, contains('_plannerKey.currentState?.jumpToDate(date)'));
    expect(source, contains('initialDate: _plannerStartDate(widget)'));
  });

  test(
    'day and week all-day bar and time gutter use rendered planner state',
    () {
      final source = File(
        'lib/src/features/schedule/presentation/schedule_day_week_view.dart',
      ).readAsStringSync();

      expect(source, contains('_hasRenderedFullDayEvents(context, widget)'));
      expect(source, contains('_ScheduleIcvEvent.fromItem(context, item)'));
      expect(source, contains('_fullDayEventIntersectsRange'));
      expect(source, isNot(contains('_allDayItemIntersectsRange')));
      expect(source, contains('textAlign: TextAlign.center'));
    },
  );

  test('month and agenda views support horizontal paging gestures', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();

    expect(source, contains('class _HorizontalSchedulePager'));
    expect(source, contains('onHorizontalDragEnd'));
    expect(
      source,
      contains('ScheduleViewMode.month => _HorizontalSchedulePager'),
    );
    expect(
      source,
      contains('ScheduleViewMode.year => _HorizontalSchedulePager'),
    );
    expect(
      source,
      contains('ScheduleViewMode.agenda => _HorizontalSchedulePager'),
    );
    expect(source, contains('onPrevious: onPrevious'));
    expect(source, contains('onNext: onNext'));
  });

  test('year mode uses existing schedule primitives', () {
    final mode = File(
      'lib/src/schedule/schedule_view_mode.dart',
    ).readAsStringSync();
    final range = File(
      'lib/src/schedule/schedule_range.dart',
    ).readAsStringSync();
    final workspace = File(
      'lib/src/features/schedule/presentation/schedule_workspace.dart',
    ).readAsStringSync();
    final yearView = File(
      'lib/src/features/schedule/presentation/schedule_year_view.dart',
    ).readAsStringSync();

    expect(mode, contains('year'));
    expect(range, contains('factory ScheduleRange.year(DateTime day)'));
    expect(workspace, contains('ScheduleRange.year(_selectedDate)'));
    expect(workspace, contains('DateFormat.y(locale).format(selectedDate)'));
    expect(workspace, contains('ScheduleYearView('));
    expect(yearView, contains('ScheduleProjection.groupByDay(items)'));
    expect(yearView, contains('ScheduleProjection.colorForItem'));
    expect(yearView, contains('final monthWidth ='));
    expect(yearView, contains('_monthPanelHeight(monthWidth)'));
    expect(yearView, contains('mainAxisExtent: monthHeight'));
    expect(yearView, contains('ColoredBox('));
    expect(yearView, contains('color: Theme.of(context).colorScheme.surface'));
    expect(yearView, contains('double _monthPanelHeight(double width)'));
    expect(yearView, contains('BusyMaxSurface('));
    expect(
      yearView,
      contains('color: BusyMaxSurfaceColors.of(context).control'),
    );
    expect(yearView, contains('BusyMaxActionRow('));
    expect(yearView, contains('class _YearMonthGrid'));
    expect(yearView, contains('mainAxisExtent: rowHeight'));
    expect(yearView, contains('final markerSize = math.min'));
    expect(yearView, contains('firstWeekday'));
    expect(yearView, contains('onMonthSelected(month)'));
    expect(yearView, isNot(contains('height: 142')));
    expect(yearView, isNot(contains('availableHeight')));
    expect(yearView, isNot(contains('borderColor')));
    expect(yearView, isNot(contains('RoundedRectangleBorder(')));
    expect(yearView, isNot(contains('TextButton(')));
  });

  test('month view uses visible full cell borders', () {
    final source = File(
      'lib/src/features/schedule/presentation/schedule_month_view.dart',
    ).readAsStringSync();

    expect(source, contains('colorScheme.onSurface.withValues'));
    expect(source, contains('Brightness.dark ? 0.06 : 0.10'));
    expect(source, contains('position: DecorationPosition.foreground'));
    expect(source, contains('left: BorderSide(color: border)'));
    expect(source, contains('bottom: row == rows - 1'));
  });
}

List<ScheduleItem> _itemsFor(DateTime day) {
  return [
    CalendarScheduleItem(
      id: 'event:1',
      accountId: 'google:g',
      provider: TaskProvider.google,
      sourceId: 'calendar:primary',
      providerCalendarId: 'primary',
      title: 'Design review',
      allDay: false,
      start: DateTime(day.year, day.month, day.day, 9),
      end: DateTime(day.year, day.month, day.day, 10),
      colorHex: '#3584e4',
      sourceName: 'Work',
    ),
    TaskScheduleItem(
      id: 'task:1',
      accountId: 'microsoft:m',
      provider: TaskProvider.microsoft,
      sourceId: 'tasks:inbox',
      title: 'Submit report',
      completed: false,
      allDay: true,
      start: DateTime(day.year, day.month, day.day),
      end: DateTime(day.year, day.month, day.day + 1),
      sourceName: 'Inbox',
    ),
  ];
}
