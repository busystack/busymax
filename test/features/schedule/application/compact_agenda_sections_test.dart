import 'dart:io';

import 'package:busymax/src/features/schedule/application/compact_agenda_sections.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 6, 10);

  test('overdue incomplete tasks appear in Overdue', () {
    final sections = buildCompactAgendaSections(
      today: today,
      items: [_task('overdue', start: DateTime(2026, 6, 9))],
    );

    expect(sections, hasLength(1));
    expect(sections.single.kind, CompactAgendaSectionKind.overdue);
    expect(sections.single.items.single.title, 'overdue');
  });

  test('completed tasks are excluded before sectioning', () {
    final sections = buildCompactAgendaSections(
      today: today,
      items: [_task('done', start: today, completed: true)],
    );

    expect(sections, isEmpty);
  });

  test('today items appear under Today day section', () {
    final sections = buildCompactAgendaSections(
      today: today,
      items: [
        _event('standup', start: today.add(const Duration(hours: 9))),
        _task('submit', start: today),
      ],
    );

    expect(sections.single.kind, CompactAgendaSectionKind.day);
    expect(sections.single.day, today);
    expect(sections.single.items.map((item) => item.title), [
      'submit',
      'standup',
    ]);
  });

  test('tomorrow items appear under Tomorrow day section', () {
    final tomorrow = today.add(const Duration(days: 1));
    final sections = buildCompactAgendaSections(
      today: today,
      items: [_task('tomorrow', start: tomorrow)],
    );

    expect(sections.single.day, tomorrow);
    expect(sections.single.items.single.title, 'tomorrow');
  });

  test('future items group by day', () {
    final friday = today.add(const Duration(days: 2));
    final saturday = today.add(const Duration(days: 3));
    final sections = buildCompactAgendaSections(
      today: today,
      items: [
        _event('friday event', start: friday),
        _task('saturday task', start: saturday),
      ],
    );

    expect(sections.map((section) => section.day), [friday, saturday]);
    expect(
      sections.expand((section) => section.items).map((item) => item.title),
      ['friday event', 'saturday task'],
    );
  });

  test('more than 8 overdue tasks are capped', () {
    final sections = buildCompactAgendaSections(
      today: today,
      items: [
        for (var index = 0; index < 10; index += 1)
          _task(
            'overdue $index',
            start: today.subtract(Duration(days: index + 1)),
          ),
      ],
    );

    expect(sections.single.items, hasLength(8));
    expect(sections.single.hasMore, isTrue);
  });

  test('no-date tasks appear in No date section', () {
    final sections = buildCompactAgendaSections(
      today: today,
      items: [_task('someday')],
    );

    expect(sections.single.kind, CompactAgendaSectionKind.noDate);
    expect(sections.single.items.single.title, 'someday');
  });

  test('compact agenda data includes no-date tasks without old events', () {
    final source = File(
      'lib/src/features/schedule/application/compact_agenda_data.dart',
    ).readAsStringSync();

    expect(source, contains('showNoDateTasks: true'));
    expect(source, contains('ScheduleRange(start: DateTime(1), end: today)'));
    expect(source, contains('includeCalendarEvents: false'));
  });
}

TaskScheduleItem _task(
  String title, {
  DateTime? start,
  bool completed = false,
}) {
  return TaskScheduleItem(
    id: title,
    accountId: 'account',
    provider: TaskProvider.google,
    sourceId: 'tasks',
    title: title,
    completed: completed,
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
