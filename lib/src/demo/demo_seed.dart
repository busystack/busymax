import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../google_tasks/api/google_tasks_api_surface.dart';

const busyMaxDemoAccountId = 'demo-google-account';
const busyMaxDemoWorkCalendarId = 'demo-calendar-work';
const busyMaxDemoPersonalCalendarId = 'demo-calendar-personal';
const busyMaxDemoInboxId = 'demo-list-inbox';
const busyMaxDemoPersonalTasksId = 'demo-list-personal';

Future<void> seedBusyMaxDemoData(AppDatabase database, {DateTime? now}) async {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final timestamp = current.toUtc().toIso8601String();
  final localTimestamp = current.millisecondsSinceEpoch;

  await database.transaction(() async {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: busyMaxDemoAccountId,
            provider: const Value('google'),
            providerAccountId: const Value('demo-user'),
            displayName: const Value('Alex Morgan'),
            email: const Value('alex@example.com'),
            authState: const Value(accountAuthStateSignedIn),
            grantedScopes: Value(googleBusyMaxOAuthScopes.join(' ')),
            createdAtUtc: timestamp,
            updatedAtUtc: timestamp,
            lastSuccessfulSyncAtUtc: Value(timestamp),
            lastFullSyncAtUtc: Value(timestamp),
          ),
        );

    for (final source in [
      (
        id: busyMaxDemoWorkCalendarId,
        providerId: 'work@example.com',
        summary: 'Work',
        primary: true,
        color: '#3584E4',
      ),
      (
        id: busyMaxDemoPersonalCalendarId,
        providerId: 'personal@example.com',
        summary: 'Personal',
        primary: false,
        color: '#9141AC',
      ),
    ]) {
      await database
          .into(database.calendarSources)
          .insert(
            CalendarSourcesCompanion.insert(
              id: source.id,
              accountId: busyMaxDemoAccountId,
              provider: 'google',
              providerCalendarId: source.providerId,
              summary: source.summary,
              primaryCalendar: Value(source.primary),
              backgroundColor: Value(source.color),
              foregroundColor: const Value('#FFFFFF'),
              accessRole: const Value('owner'),
              rawJson: Value(
                jsonEncode({
                  'id': source.providerId,
                  'summary': source.summary,
                  'backgroundColor': source.color,
                  'foregroundColor': '#FFFFFF',
                  'accessRole': 'owner',
                }),
              ),
              createdAtLocal: localTimestamp,
              updatedAtLocal: localTimestamp,
            ),
          );
    }

    final events = <_DemoEvent>[
      _DemoEvent.timed(
        id: 'demo-event-planning',
        sourceId: busyMaxDemoWorkCalendarId,
        providerCalendarId: 'work@example.com',
        title: 'Product planning',
        day: today,
        startHour: 9,
        duration: const Duration(hours: 1),
        description: 'Review the roadmap and agree on this week’s priorities.',
        location: 'Meeting room Cedar',
      ),
      _DemoEvent.timed(
        id: 'demo-event-design-review',
        sourceId: busyMaxDemoWorkCalendarId,
        providerCalendarId: 'work@example.com',
        title: 'Design review',
        day: today,
        startHour: 11,
        startMinute: 30,
        duration: const Duration(minutes: 45),
        description: 'Final accessibility and interaction review.',
      ),
      _DemoEvent.allDay(
        id: 'demo-event-focus',
        sourceId: busyMaxDemoPersonalCalendarId,
        providerCalendarId: 'personal@example.com',
        title: 'Focus day',
        day: today,
      ),
      _DemoEvent.timed(
        id: 'demo-event-customer',
        sourceId: busyMaxDemoWorkCalendarId,
        providerCalendarId: 'work@example.com',
        title: 'Customer check-in',
        day: _calendarDay(today, 1),
        startHour: 14,
        duration: const Duration(minutes: 30),
        description: 'Walk through the new scheduling workflow.',
      ),
      _DemoEvent.timed(
        id: 'demo-event-gym',
        sourceId: busyMaxDemoPersonalCalendarId,
        providerCalendarId: 'personal@example.com',
        title: 'Gym',
        day: _calendarDay(today, 2),
        startHour: 18,
        duration: const Duration(hours: 1),
      ),
      _DemoEvent.allDay(
        id: 'demo-event-release',
        sourceId: busyMaxDemoWorkCalendarId,
        providerCalendarId: 'work@example.com',
        title: 'Release milestone',
        day: _calendarDay(today, 6),
      ),
    ];
    for (final event in events) {
      await database
          .into(database.calendarEvents)
          .insert(event.toCompanion(localTimestamp));
    }

    for (final list in [
      (id: busyMaxDemoInboxId, title: 'Inbox', kind: 'tasks#taskList'),
      (
        id: busyMaxDemoPersonalTasksId,
        title: 'Personal',
        kind: 'tasks#taskList',
      ),
    ]) {
      await database
          .into(database.taskLists)
          .insert(
            TaskListsCompanion.insert(
              accountId: busyMaxDemoAccountId,
              id: list.id,
              kind: Value(list.kind),
              title: list.title,
              rawJson: jsonEncode({
                'id': list.id,
                'kind': list.kind,
                'title': list.title,
              }),
              lastSyncedAtUtc: Value(timestamp),
              createdLocalAtUtc: timestamp,
              updatedLocalAtUtc: timestamp,
            ),
          );
    }

    final tasks = <_DemoTask>[
      _DemoTask(
        id: 'demo-task-prototype',
        listId: busyMaxDemoInboxId,
        title: 'Polish calendar prototype',
        notes: 'Check keyboard navigation and both color schemes.',
        due: today,
        position: '0001',
      ),
      _DemoTask(
        id: 'demo-task-notes',
        listId: busyMaxDemoInboxId,
        title: 'Send meeting notes',
        due: today,
        position: '0002',
      ),
      _DemoTask(
        id: 'demo-task-release',
        listId: busyMaxDemoInboxId,
        title: 'Prepare release checklist',
        due: _calendarDay(today, 2),
        position: '0003',
      ),
      _DemoTask(
        id: 'demo-task-expenses',
        listId: busyMaxDemoPersonalTasksId,
        title: 'Submit expenses',
        due: _calendarDay(today, -1),
        position: '0001',
      ),
      const _DemoTask(
        id: 'demo-task-reading',
        listId: busyMaxDemoPersonalTasksId,
        title: 'Choose next book',
        position: '0002',
      ),
      _DemoTask(
        id: 'demo-task-groceries',
        listId: busyMaxDemoPersonalTasksId,
        title: 'Pick up groceries',
        due: _calendarDay(today, 1),
        position: '0003',
        completed: true,
      ),
    ];
    for (final task in tasks) {
      await database.into(database.tasks).insert(task.toCompanion(timestamp));
    }
  });
}

class _DemoEvent {
  const _DemoEvent._({
    required this.id,
    required this.sourceId,
    required this.providerCalendarId,
    required this.title,
    required this.allDay,
    this.start,
    this.end,
    this.startDate,
    this.endDate,
    this.description,
    this.location,
  });

  factory _DemoEvent.timed({
    required String id,
    required String sourceId,
    required String providerCalendarId,
    required String title,
    required DateTime day,
    required int startHour,
    required Duration duration,
    int startMinute = 0,
    String? description,
    String? location,
  }) {
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      startHour,
      startMinute,
    );
    return _DemoEvent._(
      id: id,
      sourceId: sourceId,
      providerCalendarId: providerCalendarId,
      title: title,
      allDay: false,
      start: start,
      end: start.add(duration),
      description: description,
      location: location,
    );
  }

  factory _DemoEvent.allDay({
    required String id,
    required String sourceId,
    required String providerCalendarId,
    required String title,
    required DateTime day,
  }) {
    return _DemoEvent._(
      id: id,
      sourceId: sourceId,
      providerCalendarId: providerCalendarId,
      title: title,
      allDay: true,
      startDate: _date(day),
      endDate: _date(_calendarDay(day, 1)),
    );
  }

  final String id;
  final String sourceId;
  final String providerCalendarId;
  final String title;
  final bool allDay;
  final DateTime? start;
  final DateTime? end;
  final String? startDate;
  final String? endDate;
  final String? description;
  final String? location;

  CalendarEventsCompanion toCompanion(int timestamp) {
    return CalendarEventsCompanion.insert(
      id: id,
      accountId: busyMaxDemoAccountId,
      calendarSourceId: sourceId,
      provider: 'google',
      providerCalendarId: providerCalendarId,
      providerEventId: id,
      title: title,
      status: const Value('confirmed'),
      description: Value(description),
      location: Value(location),
      allDay: Value(allDay),
      startDate: Value(startDate),
      startDateTime: Value(start?.toIso8601String()),
      endDate: Value(endDate),
      endDateTime: Value(end?.toIso8601String()),
      remindersJson: const Value('{"useDefault":false,"overrides":[]}'),
      rawJson: Value(
        jsonEncode({
          'id': id,
          'summary': title,
          'status': 'confirmed',
          'start': allDay
              ? {'date': startDate}
              : {'dateTime': start?.toIso8601String()},
          'end': allDay
              ? {'date': endDate}
              : {'dateTime': end?.toIso8601String()},
        }),
      ),
      createdAtLocal: timestamp,
      updatedAtLocal: timestamp,
    );
  }
}

class _DemoTask {
  const _DemoTask({
    required this.id,
    required this.listId,
    required this.title,
    required this.position,
    this.notes,
    this.due,
    this.completed = false,
  });

  final String id;
  final String listId;
  final String title;
  final String position;
  final String? notes;
  final DateTime? due;
  final bool completed;

  TasksCompanion toCompanion(String timestamp) {
    final dueDate = due == null ? null : _date(due!);
    return TasksCompanion.insert(
      accountId: busyMaxDemoAccountId,
      taskListId: listId,
      id: id,
      kind: const Value('tasks#task'),
      title: title,
      position: Value(position),
      notes: Value(notes),
      status: Value(completed ? 'completed' : 'needsAction'),
      dueUtc: Value(dueDate),
      completedUtc: Value(completed ? timestamp : null),
      rawJson: jsonEncode({
        'id': id,
        'kind': 'tasks#task',
        'title': title,
        if (notes != null) 'notes': notes,
        if (dueDate != null) 'due': dueDate,
        'status': completed ? 'completed' : 'needsAction',
      }),
      lastSyncedAtUtc: Value(timestamp),
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    );
  }
}

DateTime _calendarDay(DateTime day, int offset) {
  return DateTime(day.year, day.month, day.day + offset);
}

String _date(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
