import 'package:busymax/src/features/schedule/presentation/schedule_search_result_text.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  final criteria = ScheduleSearchCriteria(
    referenceDate: DateTime(2026, 6, 12),
    firstWeekday: DateTime.monday,
    sourceIds: {},
    taskListKeys: {},
  );
  TaskScheduleItem task({
    DateTime? due,
    DateTime? start,
    bool allDay = false,
    BusyProvider provider = BusyProvider.microsoft,
  }) => TaskScheduleItem(
    id: 'task',
    accountId: 'account',
    sourceId: 'list',
    provider: provider,
    title: 'Report',
    completed: false,
    allDay: allDay,
    due: due,
    start: start,
    sourceName: 'Work',
    accountEmail: 'alex@example.com',
  );

  for (final (name, item, dateLabel) in [
    (
      'date-only due',
      task(due: DateTime(2026, 6, 12), allDay: true),
      'Due date: Jun 12, 2026',
    ),
    (
      'timed due takes precedence over start',
      task(due: DateTime(2026, 6, 12, 15, 45), start: DateTime(2026, 6, 10, 9)),
      'Due date: Jun 12, 2026 · 15:45',
    ),
    (
      'timed due remains visible with an all-day start',
      task(
        due: DateTime(2026, 6, 12, 15, 45),
        start: DateTime(2026, 6, 10),
        allDay: true,
        provider: BusyProvider.nextcloud,
      ),
      'Due date: Jun 12, 2026 · 15:45',
    ),
    (
      'timed midnight due',
      task(due: DateTime(2026, 6, 12)),
      'Due date: Jun 12, 2026 · 00:00',
    ),
    (
      'Microsoft start without due',
      task(start: DateTime(2026, 6, 10, 9, 30)),
      'Start date: Jun 10, 2026 · 09:30',
    ),
    (
      'DAV start without due',
      task(
        start: DateTime(2026, 6, 10, 9, 30),
        provider: BusyProvider.nextcloud,
      ),
      'Start date: Jun 10, 2026 · 09:30',
    ),
    (
      'all-day start without due',
      task(start: DateTime(2026, 6, 10), allDay: true),
      'Start date: Jun 10, 2026',
    ),
    ('neither due nor start', task(), 'No due date'),
  ]) {
    testWidgets('task result shows $name', (tester) async {
      await tester.pumpWidget(
        localizedTestApp(
          alwaysUse24HourFormat: true,
          child: Builder(
            builder: (context) =>
                Text(scheduleSearchResultText(context, item, criteria, '')),
          ),
        ),
      );
      expect(find.text('$dateLabel · Work · alex@example.com'), findsOneWidget);
    });
  }
  testWidgets('task due time respects the 12-hour clock preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        alwaysUse24HourFormat: false,
        child: Builder(
          builder: (context) => Text(
            scheduleSearchResultText(
              context,
              task(due: DateTime(2026, 6, 12, 15, 45)),
              criteria,
              '',
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('3:45 PM'), findsOneWidget);
  });

  test('search Agenda display date prefers task due then start', () {
    final due = DateTime(2026, 6, 12, 15, 45);
    final start = DateTime(2026, 6, 20, 9);

    expect(scheduleSearchResultDisplayDate(task(due: due, start: start)), due);
    expect(scheduleSearchResultDisplayDate(task(start: start)), start);
    expect(scheduleSearchResultDisplayDate(task()), isNull);
  });

  test('search Agenda ordering is due-first and leaves undated items last', () {
    TaskScheduleItem result(String id, {DateTime? due, DateTime? start}) =>
        TaskScheduleItem(
          id: id,
          accountId: 'account',
          sourceId: 'list',
          provider: BusyProvider.microsoft,
          title: id,
          completed: false,
          allDay: true,
          due: due,
          start: start,
        );
    final values = <ScheduleItem>[
      result('undated'),
      result(
        'later start but earlier due',
        due: DateTime(2026, 6, 12),
        start: DateTime(2026, 6, 20),
      ),
      result('start fallback', start: DateTime(2026, 6, 14)),
    ]..sort(compareScheduleSearchResultPresentation);

    expect(values.map((item) => item.id), [
      'later start but earlier due',
      'start fallback',
      'undated',
    ]);
  });
}
