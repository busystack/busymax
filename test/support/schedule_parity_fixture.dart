import 'package:busymax/src/db/app_database.dart';
import 'package:drift/drift.dart';

Future<void> seedScheduleParityFixture(
  AppDatabase database, {
  String notes = 'Parity fixture notes',
}) async {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day - 1, 23);
  final end = DateTime(today.year, today.month, today.day, 1);
  const timestamp = '2026-09-14T00:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'google:populated',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'populated',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          displayName: const Value('Calendar Account'),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'calendar',
          accountId: 'google:populated',
          provider: 'google',
          providerCalendarId: 'calendar',
          summary: 'Populated calendar',
          backgroundColor: const Value('#4285f4'),
          selected: const Value(true),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'google:populated',
      id: 'visible-list',
      title: 'Visible tasks',
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    ),
  );
  await database.tasksDao.upsertTask(
    TasksCompanion.insert(
      accountId: 'google:populated',
      taskListId: 'visible-list',
      id: 'date-only-task',
      title: 'Date-only task',
      notes: Value(notes),
      dueUtc: Value(
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}',
      ),
      status: const Value('needsAction'),
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    ),
  );
  await database
      .into(database.calendarEvents)
      .insert(
        CalendarEventsCompanion.insert(
          id: 'overnight',
          accountId: 'google:populated',
          calendarSourceId: 'calendar',
          provider: 'google',
          providerCalendarId: 'calendar',
          providerEventId: 'overnight',
          title: 'Overnight event',
          startDateTime: Value(start.toIso8601String()),
          endDateTime: Value(end.toIso8601String()),
          rawJson: const Value('{}'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  await database
      .into(database.calendarEvents)
      .insert(
        CalendarEventsCompanion.insert(
          id: 'invitation',
          accountId: 'google:populated',
          calendarSourceId: 'calendar',
          provider: 'google',
          providerCalendarId: 'calendar',
          providerEventId: 'invitation',
          title: 'Invitation event',
          allDay: const Value(true),
          startDate: Value(
            DateTime(
              today.year,
              today.month,
              today.day,
            ).toIso8601String().substring(0, 10),
          ),
          endDate: Value(
            DateTime(
              today.year,
              today.month,
              today.day + 1,
            ).toIso8601String().substring(0, 10),
          ),
          attendeesJson: const Value(
            '[{"email":"me@example.com","self":true,"responseStatus":"needsAction"}]',
          ),
          organizerJson: const Value(
            '{"email":"organizer@example.com","self":false}',
          ),
          rawJson: const Value('{}'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  for (var index = 1; index <= 4; index++) {
    await database
        .into(database.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: 'all-day-$index',
            accountId: 'google:populated',
            calendarSourceId: 'calendar',
            provider: 'google',
            providerCalendarId: 'calendar',
            providerEventId: 'all-day-$index',
            title: 'All-day event $index',
            allDay: const Value(true),
            startDate: Value(
              '${today.year.toString().padLeft(4, '0')}-'
              '${today.month.toString().padLeft(2, '0')}-'
              '${today.day.toString().padLeft(2, '0')}',
            ),
            endDate: Value(
              DateTime(
                today.year,
                today.month,
                today.day + 1,
              ).toIso8601String().substring(0, 10),
            ),
            rawJson: const Value('{}'),
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
  }
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'hidden-calendar',
          accountId: 'google:populated',
          provider: 'google',
          providerCalendarId: 'hidden-calendar',
          summary: 'Hidden calendar',
          backgroundColor: const Value('#e67c73'),
          selected: const Value(false),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  await database
      .into(database.calendarEvents)
      .insert(
        CalendarEventsCompanion.insert(
          id: 'hidden-event',
          accountId: 'google:populated',
          calendarSourceId: 'hidden-calendar',
          provider: 'google',
          providerCalendarId: 'hidden-calendar',
          providerEventId: 'hidden-event',
          title: 'Hidden event',
          startDateTime: Value(start.toIso8601String()),
          endDateTime: Value(end.toIso8601String()),
          rawJson: const Value('{}'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'google:populated',
      id: 'hidden-list',
      title: 'Hidden tasks',
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    ),
  );
  await database.tasksDao.upsertTask(
    TasksCompanion.insert(
      accountId: 'google:populated',
      taskListId: 'hidden-list',
      id: 'hidden-task',
      title: 'Hidden task',
      dueUtc: Value(
        DateTime.utc(today.year, today.month, today.day, 12).toIso8601String(),
      ),
      status: const Value('needsAction'),
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    ),
  );
}

Future<void> seedScheduleParityStress(AppDatabase db) async {
  await seedScheduleParityFixture(
    db,
    notes: List.generate(30, (i) => 'Project notes, line ${i + 1}.').join('\n'),
  );
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  const stamp = '2026-01-01T00:00:00Z';
  for (var i = 0; i < 12; i++) {
    for (final overdue in [true, false]) {
      await db.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: 'google:populated',
          taskListId: 'visible-list',
          id: '${overdue ? 'old' : 'undated'}-$i',
          title: overdue
              ? 'Overdue follow-up $i'
              : 'Unscheduled preparation $i',
          dueUtc: Value(overdue ? '2001-01-01' : null),
          status: const Value('needsAction'),
          rawJson: '{}',
          createdLocalAtUtc: stamp,
          updatedLocalAtUtc: stamp,
        ),
      );
    }
  }
  for (var i = 0; i < 12; i++) {
    final start = today.add(
      Duration(days: i % 4, hours: 9 + i % 3, minutes: 15 * (i % 2)),
    );
    await db
        .into(db.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: 'meeting-$i',
            accountId: 'google:populated',
            calendarSourceId: 'calendar',
            provider: 'google',
            providerCalendarId: 'calendar',
            providerEventId: 'meeting-$i',
            title: 'Project review ${i + 1} with the product team',
            startDateTime: Value(start.toIso8601String()),
            endDateTime: Value(
              start.add(const Duration(hours: 2)).toIso8601String(),
            ),
            description: const Value(
              'Review the mobile calendar and tasks workflow together.',
            ),
            organizerJson: const Value(
              '{"email":"me@example.com","self":true}',
            ),
            rawJson: const Value('{}'),
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
  }
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'microsoft:parity',
          provider: 'microsoft',
          authority: 'https://login.microsoftonline.com/common',
          providerAccountId: 'parity',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          displayName: const Value('Second account'),
          email: const Value('second@example.com'),
          createdAtUtc: stamp,
          updatedAtUtc: stamp,
        ),
      );
  await db.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'microsoft:parity',
      id: 'visible-list',
      title: 'Visible tasks',
      rawJson: '{}',
      createdLocalAtUtc: stamp,
      updatedLocalAtUtc: stamp,
    ),
  );
  await db.tasksDao.upsertTask(
    TasksCompanion.insert(
      accountId: 'microsoft:parity',
      taskListId: 'visible-list',
      id: 'checklist',
      title: 'Prepare release checklist',
      microsoftDueDateTime: Value(
        '${today.toIso8601String().substring(0, 10)}T12:00:00',
      ),
      microsoftDueTimeZone: const Value('UTC'),
      status: const Value('notStarted'),
      microsoftChecklistItemsJson: const Value(
        '[{"id":"step-1","displayName":"Review task hierarchy","isChecked":false},{"id":"step-2","displayName":"Confirm accessibility","isChecked":true}]',
      ),
      rawJson: '{}',
      createdLocalAtUtc: stamp,
      updatedLocalAtUtc: stamp,
    ),
  );
  for (final child in [false, true]) {
    await db.tasksDao.upsertTask(
      TasksCompanion.insert(
        accountId: 'google:populated',
        taskListId: 'visible-list',
        id: child ? 'child' : 'parent',
        title: child ? 'Confirm release notes' : 'Plan release',
        parent: Value(child ? 'parent' : null),
        dueUtc: Value(today.toIso8601String().substring(0, 10)),
        status: const Value('needsAction'),
        rawJson: '{}',
        createdLocalAtUtc: stamp,
        updatedLocalAtUtc: stamp,
      ),
    );
  }
}
