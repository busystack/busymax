import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'search matches event title, location, description, and calendar name',
    () {
      final item = CalendarScheduleItem(
        id: 'event-1',
        accountId: 'google:g',
        provider: TaskProvider.google,
        sourceId: 'cal-1',
        providerCalendarId: 'cal-1',
        title: 'Design review',
        allDay: false,
        location: 'Conference room',
        description: 'Discuss launch plan',
        sourceName: 'Work calendar',
        accountEmail: 'person@example.com',
      );

      expect(matchesScheduleQuery(item, 'design'), isTrue);
      expect(matchesScheduleQuery(item, 'conference'), isTrue);
      expect(matchesScheduleQuery(item, 'launch'), isTrue);
      expect(matchesScheduleQuery(item, 'work calendar'), isTrue);
      expect(matchesScheduleQuery(item, 'google person@example.com'), isTrue);
    },
  );

  test(
    'search matches task notes, list name, provider, and multi-term query',
    () {
      const item = TaskScheduleItem(
        id: 'task-1',
        accountId: 'microsoft:m',
        provider: TaskProvider.microsoft,
        sourceId: 'list-1',
        title: 'Submit report',
        completed: false,
        allDay: true,
        notes: 'Include budget appendix',
        sourceName: 'Finance tasks',
        accountDisplayName: 'Ada Lovelace',
      );

      expect(matchesScheduleQuery(item, 'budget'), isTrue);
      expect(matchesScheduleQuery(item, 'finance'), isTrue);
      expect(matchesScheduleQuery(item, 'microsoft'), isTrue);
      expect(matchesScheduleQuery(item, 'ada report'), isTrue);
      expect(matchesScheduleQuery(item, 'missing report'), isFalse);
    },
  );

  test(
    'repository search is not limited to the current visible range',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _seedSearchDatabase(database);

      final repository = ScheduleRepository(database);
      final items = await repository.listItems(
        range: ScheduleRange.day(DateTime(2026, 1, 1)),
        filters: const ScheduleFilters(
          accountIds: {'account'},
          query: 'future budget',
          showCompletedTasks: true,
        ),
      );

      expect(items.map((item) => item.title), ['Future budget review']);
    },
  );

  test(
    'Microsoft all-day calendar event appears from Graph dateTime fields',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _insertScheduleAccount(database, provider: TaskProvider.microsoft);
      final calendarRepository = CalendarRepository(
        database: database,
        now: () => DateTime.utc(2026, 6, 9),
      );
      await calendarRepository.upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: TaskProvider.microsoft,
          providerCalendarId: 'calendar',
          summary: 'Work',
        ),
      );
      await calendarRepository.upsertEvent(
        accountId: 'account',
        event: const CalendarEventDto(
          provider: TaskProvider.microsoft,
          providerCalendarId: 'calendar',
          providerEventId: 'event',
          title: 'Company holiday',
          allDay: true,
          startDateTime: '2026-06-11T00:00:00.0000000',
          endDateTime: '2026-06-12T00:00:00.0000000',
        ),
      );

      final items = await ScheduleRepository(database).listItems(
        range: ScheduleRange.day(DateTime(2026, 6, 11)),
        filters: const ScheduleFilters(
          accountIds: {'account'},
          includeTasks: false,
        ),
      );

      expect(items, hasLength(1));
      final event = items.single as CalendarScheduleItem;
      expect(event.title, 'Company holiday');
      expect(event.allDay, isTrue);
      expect(event.start, DateTime(2026, 6, 11));
      expect(event.end, DateTime(2026, 6, 12));
    },
  );

  test('Microsoft task with start and due appears on start day', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: TaskProvider.microsoft);
    await _insertTaskList(database);
    await database
        .into(database.tasks)
        .insert(
          TasksCompanion.insert(
            accountId: 'account',
            taskListId: 'inbox',
            id: 'ms-task',
            title: 'Prepare report',
            status: const Value('needsAction'),
            dueUtc: const Value('2026-06-12'),
            microsoftDueDateTime: const Value('2026-06-12T17:00:00'),
            microsoftStartDateTime: const Value('2026-06-11T09:00:00'),
            rawJson: '{}',
            createdLocalAtUtc: _now,
            updatedLocalAtUtc: _now,
          ),
        );

    final repository = ScheduleRepository(database);
    final startDayItems = await repository.listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 11)),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeCalendarEvents: false,
      ),
    );
    final dueDayItems = await repository.listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 12)),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeCalendarEvents: false,
      ),
    );

    expect(startDayItems, hasLength(1));
    final task = startDayItems.single as TaskScheduleItem;
    expect(task.start, DateTime(2026, 6, 11, 9));
    expect(task.end, DateTime(2026, 6, 11, 9, 30));
    expect(task.allDay, isFalse);
    expect(dueDayItems, isEmpty);
  });

  test('Microsoft task with midnight due appears as timed slot', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: TaskProvider.microsoft);
    await _insertTaskList(database);
    await database
        .into(database.tasks)
        .insert(
          TasksCompanion.insert(
            accountId: 'account',
            taskListId: 'inbox',
            id: 'ms-all-day-task',
            title: 'File expenses',
            status: const Value('needsAction'),
            dueUtc: const Value('2026-06-12'),
            microsoftDueDateTime: const Value('2026-06-12T00:00:00'),
            rawJson: '{}',
            createdLocalAtUtc: _now,
            updatedLocalAtUtc: _now,
          ),
        );

    final items = await ScheduleRepository(database).listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 12)),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeCalendarEvents: false,
      ),
    );

    expect(items, hasLength(1));
    final task = items.single as TaskScheduleItem;
    expect(task.title, 'File expenses');
    expect(task.allDay, isFalse);
    expect(task.start, DateTime(2026, 6, 12));
    expect(task.end, DateTime(2026, 6, 12, 0, 30));
  });

  test('Microsoft task with date-only due appears as all-day', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: TaskProvider.microsoft);
    await _insertTaskList(database);
    await database
        .into(database.tasks)
        .insert(
          TasksCompanion.insert(
            accountId: 'account',
            taskListId: 'inbox',
            id: 'ms-all-day-task',
            title: 'File expenses',
            status: const Value('needsAction'),
            dueUtc: const Value('2026-06-12'),
            microsoftDueDateTime: const Value('2026-06-12'),
            rawJson: '{}',
            createdLocalAtUtc: _now,
            updatedLocalAtUtc: _now,
          ),
        );

    final items = await ScheduleRepository(database).listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 12)),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeCalendarEvents: false,
      ),
    );

    expect(items, hasLength(1));
    final task = items.single as TaskScheduleItem;
    expect(task.title, 'File expenses');
    expect(task.allDay, isTrue);
    expect(task.start, DateTime(2026, 6, 12));
    expect(task.end, DateTime(2026, 6, 13));
  });

  test('repository limits no-date task bucket', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: TaskProvider.google);
    await _insertTaskList(database);
    for (var index = 0; index < 10; index += 1) {
      await _insertTask(
        database,
        id: 'no-date-$index',
        title: 'Someday $index',
      );
    }

    final repository = ScheduleRepository(database);
    final firstPage = await repository.listNoDateTasks(
      limit: 8,
      filters: const ScheduleFilters(
        accountIds: {'account'},
        taskListFilterActive: true,
        taskListIds: {'inbox'},
      ),
    );
    final expandedPage = await repository.listNoDateTasks(
      limit: 12,
      filters: const ScheduleFilters(
        accountIds: {'account'},
        taskListFilterActive: true,
        taskListIds: {'inbox'},
      ),
    );

    expect(firstPage.items, hasLength(8));
    expect(firstPage.hasMore, isTrue);
    expect(firstPage.items.every((item) => item.start == null), isTrue);
    expect(expandedPage.items, hasLength(10));
    expect(expandedPage.hasMore, isFalse);
  });

  test('repository limits overdue task bucket', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: TaskProvider.google);
    await _insertTaskList(database);
    for (var index = 0; index < 10; index += 1) {
      final due = DateTime(2026, 6, 9).subtract(Duration(days: index));
      await _insertTask(
        database,
        id: 'overdue-$index',
        title: 'Overdue $index',
        dueUtc: _dateOnly(due),
      );
    }
    await _insertTask(
      database,
      id: 'today',
      title: 'Today',
      dueUtc: '2026-06-10',
    );
    await _insertTask(database, id: 'no-date', title: 'Someday');

    final repository = ScheduleRepository(database);
    final firstPage = await repository.listOverdueTasks(
      before: DateTime(2026, 6, 10),
      limit: 8,
      filters: const ScheduleFilters(
        accountIds: {'account'},
        taskListFilterActive: true,
        taskListIds: {'inbox'},
      ),
    );
    final expandedPage = await repository.listOverdueTasks(
      before: DateTime(2026, 6, 10),
      limit: 12,
      filters: const ScheduleFilters(
        accountIds: {'account'},
        taskListFilterActive: true,
        taskListIds: {'inbox'},
      ),
    );

    expect(firstPage.items, hasLength(8));
    expect(firstPage.hasMore, isTrue);
    expect(firstPage.items.every((item) => item.start != null), isTrue);
    expect(
      firstPage.items,
      isNot(
        contains(
          predicate<TaskScheduleItem>((item) {
            return item.title == 'Today' || item.title == 'Someday';
          }),
        ),
      ),
    );
    expect(expandedPage.items, hasLength(10));
    expect(expandedPage.hasMore, isFalse);
  });
}

Future<void> _seedSearchDatabase(AppDatabase database) async {
  await _insertScheduleAccount(database, provider: TaskProvider.google);
  await _insertTaskList(database);
  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          accountId: 'account',
          taskListId: 'inbox',
          id: 'future-task',
          title: 'Future budget review',
          status: const Value('needsAction'),
          dueUtc: const Value('2026-02-15T00:00:00.000Z'),
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
}

Future<void> _insertScheduleAccount(
  AppDatabase database, {
  required TaskProvider provider,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: Value(provider.storageValue),
          displayName: const Value('Ada Lovelace'),
          email: const Value('ada@example.com'),
          authState: const Value('signed_in'),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
}

Future<void> _insertTaskList(AppDatabase database) {
  return database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: 'inbox',
          title: 'Inbox',
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
}

Future<void> _insertTask(
  AppDatabase database, {
  required String id,
  required String title,
  String? dueUtc,
}) {
  return database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          accountId: 'account',
          taskListId: 'inbox',
          id: id,
          title: title,
          status: const Value('needsAction'),
          dueUtc: Value(dueUtc),
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
}

String _dateOnly(DateTime date) {
  return [
    date.year.toString().padLeft(4, '0'),
    date.month.toString().padLeft(2, '0'),
    date.day.toString().padLeft(2, '0'),
  ].join('-');
}

const _now = '2026-01-01T00:00:00.000Z';
