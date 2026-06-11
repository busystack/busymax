import 'dart:io';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/features/schedule/application/compact_agenda_data.dart';
import 'package:busymax/src/features/schedule/presentation/compact_agenda_panel.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

void main() {
  final today = DateTime(2026, 6, 10);

  testWidgets('signed-out state shows sign-in and open app message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testPanel(
        data: _data(today, hasSignedInAccounts: false, hasSources: false),
      ),
    );

    expect(find.text('Sign in to show agenda.'), findsOneWidget);
    expect(find.text('Open BusyMax'), findsWidgets);
  });

  testWidgets('no sources state shows no sources message', (tester) async {
    await tester.pumpWidget(_testPanel(data: _data(today, hasSources: false)));

    expect(find.text('No visible calendars or task lists.'), findsOneWidget);
    expect(find.text('Open BusyMax'), findsWidgets);
  });

  testWidgets('long error state scrolls without overflowing', (tester) async {
    final message = List.filled(160, 'Failure details').join('\n');

    await tester.pumpWidget(
      _testPanel(
        data: AsyncError<CompactAgendaData>(message, StackTrace.empty),
        size: const Size(420, 520),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Agenda unavailable'), findsOneWidget);
  });

  testWidgets('empty state shows positive empty message', (tester) async {
    await tester.pumpWidget(_testPanel(data: _data(today)));

    expect(find.text('Clear for now'), findsOneWidget);
    expect(find.text('No events or tasks'), findsOneWidget);
  });

  test('compact agenda panel loads more days as the list is scrolled', () {
    final source = File(
      'lib/src/features/schedule/presentation/compact_agenda_panel.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('ref.watch(compactAgendaDataForQueryProvider(_query))'),
    );
    expect(source, contains('_loadedDays += compactAgendaPageDays'));
    expect(source, contains('metrics.extentAfter > 1'));
    expect(source, contains('end: data.range.end'));
  });

  testWidgets('no-date tasks render in a No date section', (tester) async {
    await tester.pumpWidget(
      _testPanel(data: _data(today, items: [_task('Plan someday')])),
    );

    expect(find.text('No date'), findsOneWidget);
    expect(find.text('Plan someday'), findsOneWidget);
  });

  testWidgets('compact shell has rounded corners', (tester) async {
    await tester.pumpWidget(_testPanel(data: _data(today)));

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);

    expect(clip.borderRadius, isA<BorderRadius>());
  });

  testWidgets('header uses native close control and no open-app chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testPanel(
        data: _data(today, items: [_event('Team sync', start: today)]),
      ),
    );

    expect(find.byType(YaruWindowControl), findsOneWidget);
    expect(find.byIcon(Icons.open_in_full), findsNothing);
    expect(find.text('Open BusyMax'), findsNothing);
    expect(find.text('New task'), findsOneWidget);
  });

  testWidgets('more overdue row loads overdue tasks in place', (tester) async {
    final overdueDay = today.subtract(const Duration(days: 1));
    final items = [
      for (var index = 0; index < 10; index += 1)
        _task('Overdue task $index', start: overdueDay),
    ];

    await tester.pumpWidget(
      _testPanel(
        data: _data(today, items: items),
        size: const Size(420, 680),
      ),
    );

    expect(find.text('Load more overdue tasks'), findsOneWidget);
    expect(find.text('Overdue task 8'), findsNothing);

    await tester.ensureVisible(find.text('Load more overdue tasks'));
    await tester.pump();
    await tester.tap(find.text('Load more overdue tasks'));
    await tester.pump();

    expect(find.text('Load more overdue tasks'), findsNothing);
    expect(find.text('Overdue task 8'), findsOneWidget);
    expect(find.text('Overdue task 9'), findsOneWidget);
  });

  testWidgets('more no-date row loads no-date tasks in place', (tester) async {
    final items = [
      for (var index = 0; index < 10; index += 1) _task('Someday task $index'),
    ];

    await tester.pumpWidget(
      _testPanel(
        data: _data(today, items: items),
        size: const Size(420, 680),
      ),
    );

    expect(find.text('Load more no-date tasks'), findsOneWidget);
    expect(find.text('Someday task 8'), findsNothing);

    await tester.ensureVisible(find.text('Load more no-date tasks'));
    await tester.pump();
    await tester.tap(find.text('Load more no-date tasks'));
    await tester.pump();

    expect(find.text('Load more no-date tasks'), findsNothing);
    expect(find.text('Someday task 8'), findsOneWidget);
    expect(find.text('Someday task 9'), findsOneWidget);
  });

  testWidgets('task row renders checkbox and calls completion callback', (
    tester,
  ) async {
    var completed = false;
    final task = _task('Submit report', start: today);

    await tester.pumpWidget(
      _testPanel(
        data: _data(today, items: [task]),
        onTaskCompletionChanged: (_, value) async {
          completed = value;
        },
      ),
    );

    expect(find.byType(YaruCheckbox), findsOneWidget);
    await tester.tap(find.byType(YaruCheckbox));
    await tester.pump();

    expect(completed, isTrue);
  });

  testWidgets('event row does not render checkbox', (tester) async {
    await tester.pumpWidget(
      _testPanel(
        data: _data(today, items: [_event('Team sync', start: today)]),
      ),
    );

    expect(find.text('Team sync'), findsOneWidget);
    expect(find.byType(YaruCheckbox), findsNothing);
  });

  testWidgets('rows use native grouped action row pattern', (tester) async {
    final event = _event('Team sync', start: today);

    await tester.pumpWidget(_testPanel(data: _data(today, items: [event])));

    expect(find.byType(BusyMaxGroupedList), findsWidgets);
    expect(find.byType(BusyMaxActionRow), findsWidgets);
    expect(find.text('Team sync'), findsOneWidget);
  });

  testWidgets('chrome uses scroll shadows instead of static borders', (
    tester,
  ) async {
    final items = [
      for (var index = 0; index < 24; index += 1)
        _event('Event $index', start: today.add(Duration(minutes: index))),
    ];

    await tester.pumpWidget(
      _testPanel(
        data: _data(today, items: items),
        size: const Size(420, 520),
      ),
    );

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('compactAgendaHeader')),
    );
    final footer = tester.widget<Container>(
      find.byKey(const ValueKey('compactAgendaFooter')),
    );
    final headerDecoration = header.decoration! as BoxDecoration;
    final footerDecoration = footer.decoration! as BoxDecoration;

    expect(headerDecoration.border, isNull);
    expect(footerDecoration.border, isNull);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('compactAgendaTopScrollShadow')),
          )
          .opacity,
      0,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('compactAgendaBottomScrollShadow')),
          )
          .opacity,
      0,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('compactAgendaTopScrollShadow')),
          )
          .opacity,
      1,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('compactAgendaBottomScrollShadow')),
          )
          .opacity,
      1,
    );
  });

  testWidgets('row tap calls open-item callback', (tester) async {
    ScheduleItem? opened;
    final event = _event('Team sync', start: today);

    await tester.pumpWidget(
      _testPanel(
        data: _data(today, items: [event]),
        onOpenItem: (item) async {
          opened = item;
        },
      ),
    );

    await tester.tap(find.text('Team sync'));
    await tester.pump();

    expect(opened, event);
  });

  testWidgets('default row tap shows details popover in compact window', (
    tester,
  ) async {
    final event = _event('Team sync', start: today);

    await tester.pumpWidget(_testPanel(data: _data(today, items: [event])));

    await tester.tap(find.text('Team sync'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.text('Work'), findsWidgets);
  });

  testWidgets('loading state renders progress and skeleton rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testPanel(data: const AsyncLoading<CompactAgendaData>()),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('startup one-pixel allocation does not overflow', (tester) async {
    await tester.pumpWidget(
      _testPanel(data: _data(today), size: const Size(1, 1)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Agenda'), findsNothing);
  });
}

Widget _testPanel({
  required AsyncValue<CompactAgendaData> data,
  Size size = const Size(420, 680),
  Future<void> Function(ScheduleItem item)? onOpenItem,
  CompactAgendaTaskCompletionCallback? onTaskCompletionChanged,
}) {
  return ProviderScope(
    child: localizedTestApp(
      child: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: CompactAgendaPanel(
            data: data,
            onOpenBusyMax: () async {},
            onNewTask: () async {},
            onRefresh: () async {},
            onHide: () async {},
            onOpenItem: onOpenItem,
            onTaskCompletionChanged: onTaskCompletionChanged,
          ),
        ),
      ),
    ),
  );
}

AsyncValue<CompactAgendaData> _data(
  DateTime today, {
  List<ScheduleItem> items = const [],
  bool hasMoreOverdueTasks = false,
  bool hasMoreNoDateTasks = false,
  bool hasSignedInAccounts = true,
  bool hasSources = true,
}) {
  return AsyncData(
    CompactAgendaData(
      today: today,
      range: ScheduleRange(
        start: today,
        end: today.add(const Duration(days: 30)),
      ),
      items: items,
      hasMoreOverdueTasks: hasMoreOverdueTasks,
      hasMoreNoDateTasks: hasMoreNoDateTasks,
      hasSignedInAccounts: hasSignedInAccounts,
      hasSources: hasSources,
      generatedAt: today,
    ),
  );
}

TaskScheduleItem _task(String title, {DateTime? start}) {
  return TaskScheduleItem(
    id: title,
    accountId: 'account',
    provider: TaskProvider.google,
    sourceId: 'tasks',
    title: title,
    completed: false,
    allDay: true,
    start: start,
    sourceName: 'Inbox',
  );
}

CalendarScheduleItem _event(String title, {required DateTime start}) {
  return CalendarScheduleItem(
    id: title,
    accountId: 'account',
    provider: TaskProvider.google,
    sourceId: 'calendar',
    providerCalendarId: 'calendar',
    title: title,
    allDay: false,
    start: start,
    end: start.add(const Duration(hours: 1)),
    sourceName: 'Work',
  );
}
