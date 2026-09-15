import 'dart:convert';
import 'package:busymax/src/schedule/schedule_search_match.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';

import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shared search criteria', () {
    final today = DateTime(2026, 6, 12);
    final range = ScheduleRange.day(today);
    final event = CalendarScheduleItem(
      id: 'meeting',
      accountId: 'account',
      provider: BusyProvider.microsoft,
      sourceId: 'calendar',
      providerCalendarId: 'calendar',
      title: 'Review',
      allDay: false,
      start: DateTime(2026, 6, 11, 12),
      end: DateTime(2026, 6, 12, 14),
      location: 'Office north',
      description: '<p>Launch brief</p>',
      categories: const ['Planning'],
      attendees: const [
        {
          'displayName': 'Alex Smith',
          'email': 'alex@example.com',
          'responseStatus': 'accepted',
        },
        {
          'emailAddress': {
            'name': 'Robin Jones',
            'address': 'robin@example.com',
          },
          'status': {'response': 'tentative'},
        },
      ],
      organizer: const {'name': 'Morgan Lee', 'email': 'morgan@example.com'},
    );
    TaskScheduleItem task({
      bool completed = false,
      DateTime? due,
      DateTime? start,
    }) => TaskScheduleItem(
      id: 'task',
      accountId: 'account',
      provider: BusyProvider.microsoft,
      sourceId: 'list',
      title: 'Report',
      completed: completed,
      allDay: true,
      start: start,
      due: due,
      location: 'Office south',
      notes: 'Budget appendix',
    );
    bool matches(ScheduleItem item, ScheduleFilters filters) =>
        matchesScheduleFilters(item, filters, range: range);

    for (final term in [
      'Alex Smith',
      'alex@example.com',
      'Robin Jones',
      'robin@example.com',
      'Morgan Lee',
      'morgan@example.com',
    ]) {
      test('identity text and Person match $term', () {
        expect(matchesScheduleQuery(event, term), isTrue);
        expect(matches(event, ScheduleFilters(person: term)), isTrue);
        expect(matches(task(), ScheduleFilters(person: term)), isFalse);
      });
    }
    for (final nested in [false, true]) {
      test('Person terms must identify one attendee (nested: $nested)', () {
        Map<String, Object?> identity(String name, String email) => nested
            ? {
                'emailAddress': {'name': name, 'address': email},
              }
            : {'displayName': name, 'email': email};
        final participants = CalendarScheduleItem(
          id: 'participants',
          accountId: 'account',
          provider: BusyProvider.microsoft,
          sourceId: 'calendar',
          providerCalendarId: 'calendar',
          title: 'Meeting',
          allDay: true,
          attendees: [
            identity('Alex Jones', 'alex@example.com'),
            identity('Robin Smith', 'robin@example.com'),
          ],
          organizer: identity('Morgan Lee', 'morgan@example.com'),
        );
        bool personMatches(String person) => matches(
          participants,
          ScheduleFilters(ignoreDateRange: true, person: person),
        );
        expect(personMatches('Alex Smith'), isFalse);
        expect(personMatches('Morgan Jones'), isFalse);
        expect(personMatches('Alex robin@example.com'), isFalse);
        expect(personMatches('ALEX Jones'), isTrue);
        expect(personMatches('Alex alex@example.com'), isTrue);
        expect(personMatches('Morgan morgan@example.com'), isTrue);
        // Free text deliberately keeps its cross-field matching semantics.
        expect(matchesScheduleQuery(participants, 'Alex Smith'), isTrue);
      });
    }
    test('Person context describes the matching participant', () {
      const participants = CalendarScheduleItem(
        id: 'participants',
        accountId: 'account',
        provider: BusyProvider.microsoft,
        sourceId: 'calendar',
        providerCalendarId: 'calendar',
        title: 'Meeting',
        allDay: true,
        organizer: {'name': 'Alex Jones', 'email': 'jones@example.com'},
        attendees: [
          {'name': 'Alex Smith', 'email': 'smith@example.com'},
        ],
      );
      final snippet = scheduleMatchContext(
        participants,
        '',
        person: 'Alex Smith',
      );
      expect(snippet, contains('Alex Smith'));
      expect(snippet, isNot(contains('Jones')));
    });
    test('long snippets include the match within bounded text', () {
      for (final padding in [0, 200]) {
        final item = TaskScheduleItem(
          id: 'long-notes',
          accountId: 'account',
          provider: BusyProvider.microsoft,
          sourceId: 'list',
          title: 'Report',
          completed: false,
          allDay: true,
          notes: '${'x' * padding} needle ${'y' * 200}',
        );
        final snippet = scheduleMatchContext(item, 'needle')!;
        expect(snippet, contains('needle'));
        expect(snippet.length, lessThanOrEqualTo(142));
      }
    });
    test(
      'identity extraction ignores response metadata and handles organizer emailAddress',
      () {
        expect(matchesScheduleQuery(event, 'accepted'), isFalse);
        expect(matchesScheduleQuery(event, 'tentative'), isFalse);
        const nested = CalendarScheduleItem(
          id: 'nested',
          accountId: 'a',
          provider: BusyProvider.microsoft,
          sourceId: 's',
          providerCalendarId: 's',
          title: 'Meeting',
          allDay: true,
          organizer: {
            'emailAddress': {
              'name': 'Chris Green',
              'address': 'chris@example.com',
            },
          },
        );
        expect(
          matchesScheduleQuery(nested, 'Chris Green chris@example.com'),
          isTrue,
        );
        expect(
          matches(event, const ScheduleFilters(person: 'unknown')),
          isFalse,
        );
        expect(
          matches(
            task(),
            const ScheduleFilters(
              includeCalendarEvents: false,
              person: 'ignored',
            ),
          ),
          isTrue,
        );
      },
    );
    test('task location and cross-field words remain searchable', () {
      expect(matchesScheduleQuery(task(), 'REPORT office appendix'), isTrue);
      expect(matchesScheduleQuery(event, 'review north alex planning'), isTrue);
    });
    test('dedicated Location only constrains location fields', () {
      expect(matches(event, const ScheduleFilters(location: 'OFFICE')), isTrue);
      expect(
        matches(task(), const ScheduleFilters(location: 'office')),
        isTrue,
      );
      expect(
        matches(event, const ScheduleFilters(location: 'Review')),
        isFalse,
      );
      expect(
        matches(task(), const ScheduleFilters(location: 'Budget')),
        isFalse,
      );
    });
    test('type includes All, Events only and Tasks only', () {
      for (final type in ScheduleSearchType.values) {
        final criteria = ScheduleSearchCriteria(
          type: type,
          referenceDate: today,
          firstWeekday: DateTime.sunday,
          sourceIds: {'calendar'},
          taskListKeys: {
            const ScheduleTaskListKey(accountId: 'account', taskListId: 'list'),
          },
        );
        expect(
          matches(event, criteria.filters('')),
          type != ScheduleSearchType.tasks,
        );
        expect(
          matches(task(), criteria.filters('')),
          type != ScheduleSearchType.events,
        );
      }
    });
    test('bounded date uses overlap and actual task due', () {
      const filters = ScheduleFilters(useTaskDueDate: true);
      expect(matches(event, filters), isTrue);
      expect(
        matches(task(due: today, start: DateTime(2026, 6, 1)), filters),
        isTrue,
      );
      expect(
        matches(task(due: DateTime(2026, 6, 13), start: today), filters),
        isFalse,
      );
      expect(matches(task(start: today), filters), isFalse);
    });
    test(
      'Overdue excludes completed, future and undated tasks, preserves events',
      () {
        final filters = ScheduleFilters(
          ignoreDateRange: true,
          taskCompletion: ScheduleTaskCompletion.all,
          taskDueState: ScheduleTaskDueState.overdue,
          referenceDate: today,
        );
        expect(matches(task(due: DateTime(2026, 6, 11)), filters), isTrue);
        expect(
          matches(task(due: DateTime(2026, 6, 11), completed: true), filters),
          isFalse,
        );
        expect(matches(task(due: today), filters), isFalse);
        expect(matches(task(due: DateTime(2026, 6, 13)), filters), isFalse);
        expect(matches(task(start: DateTime(2026, 6, 1)), filters), isFalse);
        expect(matches(event, filters), isTrue);
      },
    );
    test('No due date is independent of start metadata and events', () {
      const filters = ScheduleFilters(
        ignoreDateRange: true,
        taskDueState: ScheduleTaskDueState.noDueDate,
      );
      expect(matches(task(start: today), filters), isTrue);
      expect(matches(task(due: today), filters), isFalse);
      expect(matches(event, filters), isTrue);
    });
    test('snippet prefers location and person and never exposes HTML', () {
      expect(scheduleMatchContext(event, 'north launch'), 'Office north');
      expect(scheduleMatchContext(event, 'alex'), contains('Alex'));
      expect(scheduleMatchContext(event, 'launch'), 'Launch brief');
      expect(scheduleMatchContext(event, 'review'), isNull);
      expect(
        scheduleMatchContext(event, '', location: 'office'),
        'Office north',
      );
      expect(
        scheduleMatchContext(event, '', person: 'morgan'),
        contains('Morgan'),
      );
    });
    test(
      'criteria copy sets, have value equality and respect week start and inclusive custom end',
      () {
        final ids = {'a', 'b'};
        final first = ScheduleSearchCriteria(
          referenceDate: today,
          firstWeekday: DateTime.sunday,
          sourceIds: ids,
          taskListKeys: {},
        );
        ids.clear();
        expect(first.sourceIds, {'a', 'b'});
        final equal = first.copyWith(sourceIds: {'b', 'a'});
        expect(first, equal);
        expect(first.hashCode, equal.hashCode);
        expect(first.copyWith(person: 'Alex'), isNot(first));
        expect(
          first
              .copyWith(person: 'Alex')
              .copyWith(type: ScheduleSearchType.tasks)
              .person,
          isEmpty,
        );
        expect(
          first.copyWith(date: ScheduleSearchDate.thisWeek).range!.start,
          DateTime(2026, 6, 7),
        );
        final custom = first
            .copyWith(
              date: ScheduleSearchDate.custom,
              customStart: today,
              customEnd: DateTime(2026, 6, 14),
            )
            .range!;
        expect(custom.start, today);
        expect(custom.end, DateTime(2026, 6, 15));
      },
    );
  });

  for (final completion in ScheduleTaskCompletion.values) {
    test('repository task completion ${completion.name}', () async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      await _insertScheduleAccount(db, provider: BusyProvider.google);
      await _insertTaskList(db);
      await _insertTask(db, id: 'open', title: 'Open');
      await _insertTask(db, id: 'done', title: 'Done');
      await (db.update(db.tasks)..where((t) => t.id.equals('done'))).write(
        const TasksCompanion(status: Value('completed')),
      );
      final items = await ScheduleRepository(db).listItems(
        range: ScheduleRange.day(DateTime(2026)),
        filters: ScheduleFilters(
          ignoreDateRange: true,
          taskCompletion: completion,
        ),
      );
      expect(items.map((i) => i.id).toSet(), switch (completion) {
        ScheduleTaskCompletion.open => {'open'},
        ScheduleTaskCompletion.completed => {'done'},
        ScheduleTaskCompletion.all => {'open', 'done'},
      });
    });
  }
  test(
    'repository Microsoft due uses later due day and due timezone rather than start',
    () async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      await _insertScheduleAccount(db, provider: BusyProvider.microsoft);
      await _insertTaskList(db);
      await _insertTask(db, id: 'ms', title: 'Report');
      await db
          .update(db.tasks)
          .write(
            const TasksCompanion(
              microsoftStartDateTime: Value('2026-06-10T09:00:00'),
              microsoftDueDateTime: Value('2026-06-12T12:00:00'),
              microsoftDueTimeZone: Value('Pacific Standard Time'),
            ),
          );
      final repo = ScheduleRepository(db);
      const filters = ScheduleFilters(useTaskDueDate: true, query: 'report');
      expect(
        await repo.listItems(
          range: ScheduleRange.day(DateTime(2026, 6, 10)),
          filters: filters,
        ),
        isEmpty,
      );
      final items = await repo.listItems(
        range: ScheduleRange.day(DateTime(2026, 6, 12)),
        filters: filters,
      );
      expect(items, hasLength(1));
      expect(
        (items.single as TaskScheduleItem).due,
        DateTime.utc(2026, 6, 12, 19).toLocal(),
      );
    },
  );
  test(
    'repository DAV DTSTART-only legacy dueUtc does not become an actual due',
    () async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      await _insertDavScheduleFixture(db, authState: 'signed_in');
      await _insertDavTask(
        db,
        id: 'start-only',
        title: 'Start only',
        dueUtc: '2026-06-10',
        providerMetadata: {
          'nativeStart': {'raw': '20260610', 'kind': 'date'},
        },
      );
      final repo = ScheduleRepository(db);
      final items = await repo.listItems(
        range: ScheduleRange.day(DateTime(2026, 6, 10)),
        filters: const ScheduleFilters(
          ignoreDateRange: true,
          useTaskDueDate: true,
          taskDueState: ScheduleTaskDueState.noDueDate,
        ),
      );
      expect(items, hasLength(1));
      expect((items.single as TaskScheduleItem).due, isNull);
      expect(items.single.start, DateTime(2026, 6, 10));
      expect(
        await repo.listItems(
          range: ScheduleRange.day(DateTime(2026, 6, 10)),
          filters: const ScheduleFilters(useTaskDueDate: true),
        ),
        isEmpty,
      );
    },
  );
  test(
    'repository bounded text does not leak and Any date skips projection coverage',
    () async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      await _seedSearchDatabase(db);
      var calls = 0;
      final repo = ScheduleRepository(
        db,
        ensureProjectionCoverage: (_) async {
          calls++;
        },
      );
      final range = ScheduleRange.day(DateTime(2026, 1, 1));
      expect(
        await repo.listItems(
          range: range,
          filters: const ScheduleFilters(query: 'future budget'),
        ),
        isEmpty,
      );
      expect(calls, 1);
      expect(
        await repo.listItems(
          range: range,
          filters: const ScheduleFilters(
            query: 'future budget',
            ignoreDateRange: true,
          ),
        ),
        hasLength(1),
      );
      expect(calls, 1);
      expect(
        await repo.listItems(
          range: ScheduleRange.day(DateTime(2026, 2, 15)),
          filters: const ScheduleFilters(
            query: 'future budget',
            useTaskDueDate: true,
          ),
        ),
        hasLength(1),
      );
    },
  );
  test(
    'repository date filter includes spanning events and excludes boundary and outside events',
    () async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      await _insertScheduleAccount(db, provider: BusyProvider.google);
      final calendar = CalendarRepository(database: db);
      await calendar.upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: BusyProvider.google,
          providerCalendarId: 'calendar',
          summary: 'Work',
        ),
      );
      for (final entry in [
        ('inside', '2026-06-12', '2026-06-13'),
        ('overlap', '2026-06-11', '2026-06-14'),
        ('outside', '2026-06-13', '2026-06-14'),
        ('ends-at-start', '2026-06-11', '2026-06-12'),
      ]) {
        await calendar.upsertEvent(
          accountId: 'account',
          event: CalendarEventDto(
            provider: BusyProvider.google,
            providerCalendarId: 'calendar',
            providerEventId: entry.$1,
            title: entry.$1,
            allDay: true,
            startDate: entry.$2,
            endDate: entry.$3,
          ),
        );
      }
      final items = await ScheduleRepository(db).listItems(
        range: ScheduleRange.day(DateTime(2026, 6, 12)),
        filters: const ScheduleFilters(includeTasks: false),
      );
      expect(items.map((i) => i.title).toSet(), {'inside', 'overlap'});
    },
  );

  test(
    'search matches event title, location, description, and calendar name',
    () {
      final item = CalendarScheduleItem(
        id: 'event-1',
        accountId: 'google:g',
        provider: BusyProvider.google,
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
        provider: BusyProvider.microsoft,
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
          ignoreDateRange: true,
          taskCompletion: ScheduleTaskCompletion.all,
        ),
      );

      expect(items.map((item) => item.title), ['Future budget review']);
    },
  );

  test('all-task query is not limited by year or an arbitrary page', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.google);
    await _insertTaskList(database);
    await _insertTask(
      database,
      id: 'past',
      title: 'Past task',
      dueUtc: '2020-01-02',
    );
    await _insertTask(
      database,
      id: 'future',
      title: 'Future task',
      dueUtc: '2040-03-04',
    );
    for (var index = 0; index < 501; index += 1) {
      await _insertTask(
        database,
        id: 'undated-$index',
        title: 'Undated $index',
      );
    }

    final tasks = await ScheduleRepository(database).listAllTasks(
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeCalendarEvents: false,
        taskCompletion: ScheduleTaskCompletion.all,
        showNoDateTasks: true,
      ),
    );

    expect(tasks, hasLength(503));
    expect(tasks.map((item) => item.id), containsAll(['past', 'future']));
    expect(tasks.where((item) => item.start == null), hasLength(501));
  });

  test(
    'repository ensures calendar projection coverage before reading',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final requestedRange = ScheduleRange.day(DateTime(2035, 8, 29));
      ScheduleRange? ensuredRange;
      final repository = ScheduleRepository(
        database,
        ensureProjectionCoverage: (range) async => ensuredRange = range,
      );

      await repository.listItems(
        range: requestedRange,
        filters: const ScheduleFilters(includeTasks: false),
      );

      expect(ensuredRange, requestedRange);
    },
  );

  test(
    'Microsoft all-day calendar event appears from Graph dateTime fields',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _insertScheduleAccount(database, provider: BusyProvider.microsoft);
      final calendarRepository = CalendarRepository(
        database: database,
        now: () => DateTime.utc(2026, 6, 9),
      );
      await calendarRepository.upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: 'calendar',
          summary: 'Work',
        ),
      );
      await calendarRepository.upsertEvent(
        accountId: 'account',
        event: const CalendarEventDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: 'calendar',
          providerEventId: 'event',
          title: 'Company holiday',
          allDay: true,
          startDateTime: '2026-06-11T00:00:00.0000000',
          endDateTime: '2026-06-12T00:00:00.0000000',
          remindersJson: {
            'isReminderOn': true,
            'reminderMinutesBeforeStart': 30,
          },
          categoriesJson: ['Holiday', 'Company'],
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
      expect(event.reminderMinutesBeforeStart, [30]);
      expect(event.categories, ['Holiday', 'Company']);
    },
  );

  test('events from a deleted calendar source are excluded', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.microsoft);
    final calendarRepository = CalendarRepository(database: database);
    await calendarRepository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'calendar',
        summary: 'Deleted calendar',
      ),
    );
    await calendarRepository.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'calendar',
        providerEventId: 'event',
        title: 'Pending local edit',
        startDateTime: '2026-06-11T09:00:00.000Z',
        endDateTime: '2026-06-11T10:00:00.000Z',
      ),
    );
    await (database.update(database.calendarSources)
          ..where((row) => row.providerCalendarId.equals('calendar')))
        .write(const CalendarSourcesCompanion(isDeleted: Value(true)));
    await (database.update(database.calendarEvents)
          ..where((row) => row.providerEventId.equals('event')))
        .write(const CalendarEventsCompanion(syncStatus: Value('pending')));

    final items = await ScheduleRepository(database).listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 11)),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeTasks: false,
      ),
    );

    expect(items, isEmpty);
  });

  test('Microsoft timed calendar event projects its display times', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.microsoft);
    final calendarRepository = CalendarRepository(
      database: database,
      now: () => DateTime.utc(2026, 6, 9),
    );
    await calendarRepository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'calendar',
        summary: 'Work',
      ),
    );
    await calendarRepository.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'calendar',
        providerEventId: 'event',
        providerRecurringEventId: 'series-master',
        title: 'Planning',
        startDateTime: '2026-06-11T04:20:00.0000000',
        startTimeZone: 'Pacific Standard Time',
        endDateTime: '2026-06-11T04:50:00.0000000',
        endTimeZone: 'Pacific Standard Time',
      ),
    );

    final expectedStart = DateTime.utc(2026, 6, 11, 11, 20).toLocal();
    final expectedEnd = DateTime.utc(2026, 6, 11, 11, 50).toLocal();

    final items = await ScheduleRepository(database).listItems(
      range: ScheduleRange.day(expectedStart),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeTasks: false,
      ),
    );

    expect(items, hasLength(1));
    final event = items.single as CalendarScheduleItem;
    expect(event.providerRecurringEventId, 'series-master');
    expect(event.start, expectedStart);
    expect(event.end, expectedEnd);
  });

  test('Google RFC3339 offsets convert to local display time', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.google);
    final calendarRepository = CalendarRepository(
      database: database,
      now: () => DateTime.utc(2026, 6, 9),
    );
    await calendarRepository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        summary: 'Work',
      ),
    );
    await calendarRepository.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        providerEventId: 'event',
        title: 'Planning',
        startDateTime: '2026-06-11T09:00:00-04:00',
        startTimeZone: 'America/New_York',
        endDateTime: '2026-06-11T10:00:00-04:00',
        endTimeZone: 'America/New_York',
      ),
    );

    final expectedStart = DateTime.utc(2026, 6, 11, 13).toLocal();
    final expectedEnd = DateTime.utc(2026, 6, 11, 14).toLocal();
    final items = await ScheduleRepository(database).listItems(
      range: ScheduleRange.day(expectedStart),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeTasks: false,
      ),
    );

    expect(items, hasLength(1));
    final event = items.single as CalendarScheduleItem;
    expect(event.start, expectedStart);
    expect(event.end, expectedEnd);
  });

  test('UTC calendar instants convert to local display time', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.google);
    final calendarRepository = CalendarRepository(
      database: database,
      now: () => DateTime.utc(2026, 6, 9),
    );
    await calendarRepository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        summary: 'Work',
      ),
    );
    await calendarRepository.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        providerEventId: 'event',
        title: 'Planning',
        startDateTime: '2026-06-11T13:00:00Z',
        endDateTime: '2026-06-11T14:00:00Z',
      ),
    );

    final expectedStart = DateTime.utc(2026, 6, 11, 13).toLocal();
    final expectedEnd = DateTime.utc(2026, 6, 11, 14).toLocal();
    final items = await ScheduleRepository(database).listItems(
      range: ScheduleRange.day(expectedStart),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeTasks: false,
      ),
    );

    expect(items, hasLength(1));
    final event = items.single as CalendarScheduleItem;
    expect(event.start, expectedStart);
    expect(event.end, expectedEnd);
  });

  test('calendar event projects attendees for event details', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.google);
    final calendarRepository = CalendarRepository(
      database: database,
      now: () => DateTime.utc(2026, 6, 9),
    );
    await calendarRepository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        summary: 'Work',
      ),
    );
    await calendarRepository.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        providerEventId: 'event',
        title: 'Weekly planning',
        startDateTime: '2026-06-11T09:00:00-07:00',
        startTimeZone: 'America/Vancouver',
        endDateTime: '2026-06-11T10:00:00-07:00',
        endTimeZone: 'America/Vancouver',
        recurrenceJson: ['RRULE:FREQ=WEEKLY'],
        attendeesJson: [
          {
            'email': 'guest@example.com',
            'displayName': 'Guest',
            'optional': true,
          },
        ],
      ),
    );

    final items = await ScheduleRepository(database).listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 11)),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeTasks: false,
      ),
    );

    final event = items.single as CalendarScheduleItem;
    expect(event.attendees, [
      {'email': 'guest@example.com', 'displayName': 'Guest', 'optional': true},
    ]);
  });

  test('Google invitation and Meet data reach the schedule item', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.google);
    final calendarRepository = CalendarRepository(database: database);
    await calendarRepository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        summary: 'Work',
      ),
    );
    await calendarRepository.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        providerEventId: 'invitation',
        title: 'Design review',
        startDateTime: '2026-06-11T09:00:00-07:00',
        endDateTime: '2026-06-11T10:00:00-07:00',
        organizerJson: {
          'email': 'organizer@example.com',
          'displayName': 'Organizer',
          'self': false,
        },
        attendeesJson: [
          {
            'email': 'me@example.com',
            'self': true,
            'responseStatus': 'tentative',
          },
          {
            'email': 'guest@example.com',
            'optional': true,
            'responseStatus': 'accepted',
          },
        ],
        conferenceJson: {
          'entryPoints': [
            {
              'entryPointType': 'video',
              'uri': 'https://meet.google.com/abc-defg-hij',
            },
          ],
        },
        rawJson: {'guestsCanSeeOtherGuests': false},
      ),
    );

    final items = await ScheduleRepository(database).listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 11)),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeTasks: false,
      ),
    );
    final event = items.single as CalendarScheduleItem;

    expect(event.organizer?['email'], 'organizer@example.com');
    expect(event.isOrganizer, isFalse);
    expect(event.guestsCanModify, isFalse);
    expect(event.locked, isFalse);
    expect(event.capabilities.canEdit, isFalse);
    expect(event.currentUserResponse, 'tentative');
    expect(event.canRespondToInvitation, isTrue);
    expect(event.joinMeetingUrl, 'https://meet.google.com/abc-defg-hij');
  });

  test(
    'Google event editability honors organizer, guest, and lock state',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _insertScheduleAccount(database, provider: BusyProvider.google);
      final calendarRepository = CalendarRepository(database: database);
      await calendarRepository.upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: BusyProvider.google,
          providerCalendarId: 'calendar',
          summary: 'Work',
        ),
      );
      for (final event in const [
        CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'calendar',
          providerEventId: 'owned',
          title: 'Owned event',
          startDateTime: '2026-06-11T09:00:00-07:00',
          endDateTime: '2026-06-11T10:00:00-07:00',
          organizerJson: {'self': true},
          rawJson: {'id': 'owned'},
        ),
        CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'calendar',
          providerEventId: 'guest-editable',
          title: 'Guest-editable event',
          startDateTime: '2026-06-11T11:00:00-07:00',
          endDateTime: '2026-06-11T12:00:00-07:00',
          organizerJson: {'self': false},
          rawJson: {'id': 'guest-editable', 'guestsCanModify': true},
        ),
        CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'calendar',
          providerEventId: 'locked',
          title: 'Locked event',
          startDateTime: '2026-06-11T13:00:00-07:00',
          endDateTime: '2026-06-11T14:00:00-07:00',
          organizerJson: {'self': true},
          rawJson: {'id': 'locked', 'locked': true},
        ),
      ]) {
        await calendarRepository.upsertEvent(
          accountId: 'account',
          event: event,
        );
      }

      final items = await ScheduleRepository(database).listItems(
        range: ScheduleRange.day(DateTime(2026, 6, 11)),
        filters: const ScheduleFilters(
          accountIds: {'account'},
          includeTasks: false,
        ),
      );
      final byTitle = {
        for (final item in items.whereType<CalendarScheduleItem>())
          item.title: item,
      };

      expect(byTitle['Owned event']!.capabilities.canEdit, isTrue);
      expect(byTitle['Guest-editable event']!.capabilities.canEdit, isTrue);
      expect(byTitle['Locked event']!.capabilities.canEdit, isFalse);
      expect(byTitle['Locked event']!.capabilities.canDelete, isTrue);
    },
  );

  test('Microsoft invitation and Teams data reach the schedule item', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.microsoft);
    final calendarRepository = CalendarRepository(database: database);
    await calendarRepository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'calendar',
        summary: 'Work',
      ),
    );
    await calendarRepository.upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'calendar',
        providerEventId: 'invitation',
        title: 'Design review',
        startDateTime: '2026-06-11T09:00:00',
        endDateTime: '2026-06-11T10:00:00',
        organizerJson: {
          'emailAddress': {
            'address': 'organizer@example.com',
            'name': 'Organizer',
          },
        },
        attendeesJson: [
          {
            'emailAddress': {'address': 'guest@example.com'},
            'type': 'required',
            'status': {'response': 'accepted'},
          },
        ],
        conferenceJson: {
          'joinUrl': 'https://teams.microsoft.com/l/meetup-join/example',
        },
        rawJson: {
          'isOrganizer': false,
          'responseStatus': {'response': 'notResponded'},
          'importance': 'high',
          'responseRequested': true,
          'hideAttendees': true,
          'allowNewTimeProposals': false,
        },
      ),
    );

    final items = await ScheduleRepository(database).listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 11)),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeTasks: false,
      ),
    );
    final event = items.single as CalendarScheduleItem;

    expect(event.currentUserResponse, 'notResponded');
    expect(event.canRespondToInvitation, isTrue);
    expect(
      event.joinMeetingUrl,
      'https://teams.microsoft.com/l/meetup-join/example',
    );
  });

  test(
    'Google calendar event default reminders appear on schedule item',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _insertScheduleAccount(database, provider: BusyProvider.google);
      final calendarRepository = CalendarRepository(
        database: database,
        now: () => DateTime.utc(2026, 6, 9),
      );
      await calendarRepository.upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: BusyProvider.google,
          providerCalendarId: 'calendar',
          summary: 'Work',
          rawJson: {
            'id': 'calendar',
            'defaultReminders': [
              {'method': 'popup', 'minutes': 15},
            ],
          },
        ),
      );
      await calendarRepository.upsertEvent(
        accountId: 'account',
        event: const CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'calendar',
          providerEventId: 'event',
          title: 'Planning',
          startDateTime: '2026-06-11T09:00:00',
          endDateTime: '2026-06-11T10:00:00',
          remindersJson: {'useDefault': true},
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
      expect(event.reminderMinutesBeforeStart, [15]);
    },
  );

  test('Microsoft task with start and due appears on start day', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.microsoft);
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
    await _insertScheduleAccount(database, provider: BusyProvider.microsoft);
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
            microsoftIsReminderOn: const Value(true),
            microsoftReminderDateTime: const Value('2026-06-12T08:30:00'),
            categoriesJson: const Value('["Expenses","Work"]'),
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
    expect(task.reminder, DateTime(2026, 6, 12, 8, 30));
    expect(task.categories, ['Expenses', 'Work']);
  });

  test('Microsoft UTC task reminder appears as local display time', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.microsoft);
    await _insertTaskList(database);
    await database
        .into(database.tasks)
        .insert(
          TasksCompanion.insert(
            accountId: 'account',
            taskListId: 'inbox',
            id: 'ms-utc-reminder-task',
            title: 'File expenses',
            status: const Value('needsAction'),
            dueUtc: const Value('2026-06-12'),
            microsoftDueDateTime: const Value('2026-06-12'),
            microsoftIsReminderOn: const Value(true),
            microsoftReminderDateTime: const Value('2026-06-12T13:02:00'),
            microsoftReminderTimeZone: const Value('UTC'),
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

    final task = items.single as TaskScheduleItem;
    expect(task.reminder, DateTime.utc(2026, 6, 12, 13, 2).toLocal());
  });

  test('Microsoft task with date-only due appears as all-day', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.microsoft);
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
    await _insertScheduleAccount(database, provider: BusyProvider.google);
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
      filters: ScheduleFilters(
        accountIds: {'account'},
        taskListFilterActive: true,
        taskListKeys: {
          ScheduleTaskListKey(accountId: 'account', taskListId: 'inbox'),
        },
      ),
    );
    final expandedPage = await repository.listNoDateTasks(
      limit: 12,
      filters: ScheduleFilters(
        accountIds: {'account'},
        taskListFilterActive: true,
        taskListKeys: {
          ScheduleTaskListKey(accountId: 'account', taskListId: 'inbox'),
        },
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
    await _insertScheduleAccount(database, provider: BusyProvider.google);
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
      filters: ScheduleFilters(
        accountIds: {'account'},
        taskListFilterActive: true,
        taskListKeys: {
          ScheduleTaskListKey(accountId: 'account', taskListId: 'inbox'),
        },
      ),
    );
    final expandedPage = await repository.listOverdueTasks(
      before: DateTime(2026, 6, 10),
      limit: 12,
      filters: ScheduleFilters(
        accountIds: {'account'},
        taskListFilterActive: true,
        taskListKeys: {
          ScheduleTaskListKey(accountId: 'account', taskListId: 'inbox'),
        },
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

  test(
    'task-list filters keep equal provider list IDs account-qualified',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      for (final accountId in ['account-a', 'account-b']) {
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: accountId,
                provider: 'google',
                authority: 'https://accounts.google.com',
                providerAccountId: accountId,
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                createdAtUtc: _now,
                updatedAtUtc: _now,
              ),
            );
        await database.taskListsDao.upsertTaskList(
          TaskListsCompanion.insert(
            accountId: accountId,
            id: 'inbox',
            title: 'Inbox',
            rawJson: '{}',
            createdLocalAtUtc: _now,
            updatedLocalAtUtc: _now,
          ),
        );
        await database.tasksDao.upsertTask(
          TasksCompanion.insert(
            accountId: accountId,
            taskListId: 'inbox',
            id: 'shared-id',
            title: 'Task from $accountId',
            status: const Value('needsAction'),
            dueUtc: const Value('2026-06-12'),
            rawJson: '{}',
            createdLocalAtUtc: _now,
            updatedLocalAtUtc: _now,
          ),
        );
      }

      final items = await ScheduleRepository(database).listItems(
        range: ScheduleRange.day(DateTime(2026, 6, 12)),
        filters: ScheduleFilters(
          accountIds: const {'account-a', 'account-b'},
          taskListFilterActive: true,
          taskListKeys: {
            ScheduleTaskListKey(accountId: 'account-a', taskListId: 'inbox'),
          },
          includeCalendarEvents: false,
          showNoDateTasks: false,
        ),
      );

      expect(items.map((item) => item.title), ['Task from account-a']);
    },
  );

  test('deep-link target waits for a live account-qualified task', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account-a',
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'account-a',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );
    await database.taskListsDao.upsertTaskList(
      TaskListsCompanion.insert(
        accountId: 'account-a',
        id: 'inbox',
        title: 'Inbox',
        rawJson: '{}',
        createdLocalAtUtc: _now,
        updatedLocalAtUtc: _now,
      ),
    );
    final repository = ScheduleRepository(database);
    final targetFuture = repository
        .watchTaskTarget(
          accountId: 'account-a',
          taskListId: 'inbox',
          taskId: 'late-task',
        )
        .where((target) => target != null)
        .cast<ScheduleTaskTarget>()
        .first;

    await database.tasksDao.upsertTask(
      TasksCompanion.insert(
        accountId: 'account-a',
        taskListId: 'inbox',
        id: 'late-task',
        title: 'Synced later',
        status: const Value('needsAction'),
        rawJson: '{}',
        createdLocalAtUtc: _now,
        updatedLocalAtUtc: _now,
      ),
    );

    expect(
      await targetFuture,
      const ScheduleTaskTarget(
        accountId: 'account-a',
        taskListId: 'inbox',
        taskId: 'late-task',
      ),
    );
    await (database.update(database.tasks)..where(
          (row) =>
              row.accountId.equals('account-a') &
              row.taskListId.equals('inbox') &
              row.id.equals('late-task'),
        ))
        .write(const TasksCompanion(hidden: Value(true)));
    expect(
      await repository.findTaskTarget(
        accountId: 'account-a',
        taskListId: 'inbox',
        taskId: 'late-task',
      ),
      null,
    );
  });

  test('repository hides unavailable tasks', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.google);
    await _insertTaskList(database);
    await _insertTask(
      database,
      id: 'visible-day',
      title: 'Visible day',
      dueUtc: '2026-06-12',
    );
    await _insertTask(
      database,
      id: 'missing-day',
      title: 'Missing day',
      dueUtc: '2026-06-12',
      serverMissing: true,
    );
    await _insertTask(
      database,
      id: 'deleted-day',
      title: 'Deleted day',
      dueUtc: '2026-06-12',
      deleted: true,
    );
    await _insertTask(
      database,
      id: 'hidden-day',
      title: 'Hidden day',
      dueUtc: '2026-06-12',
      hidden: true,
    );
    await _insertTask(
      database,
      id: 'visible-no-date',
      title: 'Visible no date',
    );
    await _insertTask(
      database,
      id: 'missing-no-date',
      title: 'Missing no date',
      serverMissing: true,
    );
    await _insertTask(
      database,
      id: 'visible-overdue',
      title: 'Visible overdue',
      dueUtc: '2026-06-09',
    );
    await _insertTask(
      database,
      id: 'missing-overdue',
      title: 'Missing overdue',
      dueUtc: '2026-06-09',
      serverMissing: true,
    );

    final repository = ScheduleRepository(database);
    final dayItems = await repository.listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 12)),
      filters: const ScheduleFilters(
        accountIds: {'account'},
        includeCalendarEvents: false,
        showNoDateTasks: false,
      ),
    );
    final noDateItems = await repository.listNoDateTasks(
      limit: 10,
      filters: const ScheduleFilters(accountIds: {'account'}),
    );
    final overdueItems = await repository.listOverdueTasks(
      before: DateTime(2026, 6, 10),
      limit: 10,
      filters: const ScheduleFilters(accountIds: {'account'}),
    );

    expect(dayItems.map((item) => item.title), ['Visible day']);
    expect(noDateItems.items.map((item) => item.title), ['Visible no date']);
    expect(overdueItems.items.map((item) => item.title), ['Visible overdue']);
  });

  test(
    'DAV task selection and cached connection states govern visibility',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _insertDavScheduleFixture(
        database,
        authState: 'reauth_required',
        tasksSelected: false,
      );
      await _insertDavTask(
        database,
        id: 'cached-task',
        title: 'Cached task',
        dueUtc: '2026-06-12',
        providerMetadata: {
          'nativeDue': {'raw': '20260612', 'kind': 'date'},
        },
      );

      final repository = ScheduleRepository(database);
      const filters = ScheduleFilters(
        accountIds: {'dav-account'},
        includeCalendarEvents: false,
        showNoDateTasks: false,
      );
      expect(
        await repository.listItems(
          range: ScheduleRange.day(DateTime(2026, 6, 12)),
          filters: filters,
        ),
        isEmpty,
      );

      await (database.update(database.davCollections)
            ..where((row) => row.id.equals('dav-collection')))
          .write(const DavCollectionsCompanion(tasksSelected: Value(true)));
      final visible = await repository.listItems(
        range: ScheduleRange.day(DateTime(2026, 6, 12)),
        filters: filters,
      );
      expect(visible.map((item) => item.title), ['Cached task']);
      expect(visible.single.capabilities.canEdit, isTrue);
      expect(
        await repository.findTaskTarget(
          accountId: 'dav-account',
          taskListId: 'dav-list',
          taskId: 'cached-task',
        ),
        const ScheduleTaskTarget(
          accountId: 'dav-account',
          taskListId: 'dav-list',
          taskId: 'cached-task',
        ),
      );

      await (database.update(
        database.davCollections,
      )..where((row) => row.id.equals('dav-collection'))).write(
        const DavCollectionsCompanion(
          currentUserPrivilegesJson: Value('["{DAV:}read"]'),
          readOnly: Value(true),
        ),
      );
      final readOnly = await repository.listItems(
        range: ScheduleRange.day(DateTime(2026, 6, 12)),
        filters: filters,
      );
      expect(readOnly.single.capabilities.canEdit, isFalse);
      expect(readOnly.single.capabilities.canDelete, isFalse);
    },
  );

  test('DAV DTSTART retains timed task scheduling semantics', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertDavScheduleFixture(
      database,
      authState: 'temporarily_unavailable',
    );
    await _insertDavTask(
      database,
      id: 'timed-task',
      title: 'Timed DAV task',
      dueUtc: '2026-06-12T17:00:00',
      providerMetadata: {
        'nativeStart': {'raw': '20260611T093000', 'kind': 'floatingDateTime'},
        'nativeDue': {'raw': '20260612T170000', 'kind': 'floatingDateTime'},
      },
    );

    final repository = ScheduleRepository(database);
    const filters = ScheduleFilters(
      accountIds: {'dav-account'},
      includeCalendarEvents: false,
      showNoDateTasks: false,
    );
    final startDay = await repository.listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 11)),
      filters: filters,
    );
    final dueDay = await repository.listItems(
      range: ScheduleRange.day(DateTime(2026, 6, 12)),
      filters: filters,
    );

    expect(startDay, hasLength(1));
    final task = startDay.single as TaskScheduleItem;
    expect(task.start, DateTime(2026, 6, 11, 9, 30));
    expect(task.end, DateTime(2026, 6, 11, 10));
    expect(task.allDay, isFalse);
    expect(dueDay, isEmpty);
  });

  test('no-date task bucket resolves and orders Google hierarchy', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertScheduleAccount(database, provider: BusyProvider.google);
    await _insertTaskList(database);
    await _insertTask(database, id: 'child', title: 'Child', parent: 'parent');
    await _insertTask(database, id: 'parent', title: 'Parent');

    final page = await ScheduleRepository(database).listNoDateTasks(
      limit: 10,
      filters: const ScheduleFilters(accountIds: {'account'}),
    );

    expect(page.items.map((item) => item.id), ['parent', 'child']);
    expect(page.items.first.hasSubtasks, isTrue);
    expect(page.items.last.parentId, 'parent');
    expect(page.items.last.parentTitle, 'Parent');
    expect(page.items.last.hierarchyDepth, 1);
  });

  test(
    'agenda ancestor closure restores a parent outside a bounded bucket',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await _insertDavScheduleFixture(database, authState: 'signed_in');
      for (var index = 0; index < 8; index += 1) {
        await _insertDavTask(
          database,
          id: 'older-$index',
          title: 'Older $index',
          dueUtc: '2026-06-0${index + 1}',
          providerMetadata: {
            'nativeDue': {'raw': '2026060${index + 1}', 'kind': 'date'},
          },
        );
      }
      await _insertDavTask(
        database,
        id: 'parent-object',
        title: 'Parent',
        dueUtc: '2026-06-09',
        icalUid: 'parent-uid',
        providerMetadata: const {
          'nativeDue': {'raw': '20260609', 'kind': 'date'},
        },
      );
      await _insertDavTask(
        database,
        id: 'child-object',
        title: 'Child',
        parentUid: 'parent-uid',
      );

      final repository = ScheduleRepository(database);
      final filters = ScheduleFilters(
        accountIds: {'dav-account'},
        taskListFilterActive: true,
        taskListKeys: {
          ScheduleTaskListKey(accountId: 'dav-account', taskListId: 'dav-list'),
        },
      );
      final overdue = await repository.listOverdueTasks(
        before: DateTime(2026, 6, 10),
        limit: 8,
        filters: filters,
      );
      final noDate = await repository.listNoDateTasks(
        limit: 8,
        filters: filters,
      );
      final boundedItems = <ScheduleItem>[...overdue.items, ...noDate.items];

      expect(overdue.hasMore, isTrue);
      expect(
        boundedItems.map((item) => item.id),
        isNot(contains('parent-object')),
      );
      expect(boundedItems.map((item) => item.id), contains('child-object'));

      final agendaItems = await repository.includeTaskAncestors(
        boundedItems,
        filters: filters,
      );
      final child = agendaItems.whereType<TaskScheduleItem>().singleWhere(
        (item) => item.id == 'child-object',
      );
      final parent = agendaItems.whereType<TaskScheduleItem>().singleWhere(
        (item) => item.id == 'parent-object',
      );
      expect(child.parentId, parent.id);
      expect(parent.hasSubtasks, isTrue);
    },
  );
}

Future<void> _insertDavScheduleFixture(
  AppDatabase database, {
  required String authState,
  bool tasksSelected = true,
}) async {
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'dav-account',
          provider: BusyProvider.nextcloud.storageValue,
          authority: 'https://cloud.example.test',
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
          authState: Value(authState),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'dav-collection',
          accountId: 'dav-account',
          hrefKey: '/remote.php/dav/calendars/alex/tasks/',
          requestUri:
              'https://cloud.example.test/remote.php/dav/calendars/alex/tasks/',
          displayName: 'Tasks',
          supportedComponentMask: const Value(2),
          currentUserPrivilegesJson: const Value(
            '["{DAV:}read","{DAV:}write"]',
          ),
          readOnly: const Value(false),
          taskProjectionEnabled: const Value(true),
          tasksSelected: Value(tasksSelected),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'dav-account',
          id: 'dav-list',
          davCollectionId: const Value('dav-collection'),
          title: 'Tasks',
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
}

Future<void> _insertDavTask(
  AppDatabase database, {
  required String id,
  required String title,
  String? dueUtc,
  Map<String, Object?> providerMetadata = const {},
  String? icalUid,
  String? parentUid,
}) {
  return database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          accountId: 'dav-account',
          taskListId: 'dav-list',
          id: id,
          davCollectionId: const Value('dav-collection'),
          title: title,
          status: const Value('needsAction'),
          dueUtc: Value(dueUtc),
          providerMetadataJson: Value(jsonEncode(providerMetadata)),
          icalUid: Value(icalUid),
          parentUid: Value(parentUid),
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
}

Future<void> _seedSearchDatabase(AppDatabase database) async {
  await _insertScheduleAccount(database, provider: BusyProvider.google);
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
  required BusyProvider provider,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: provider.storageValue,
          authority: provider == BusyProvider.microsoft
              ? 'https://login.microsoftonline.com/common'
              : 'https://accounts.google.com',
          providerAccountId: 'account',
          credentialKind: 'oauth',
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
  bool serverMissing = false,
  bool? deleted,
  bool? hidden,
  String? parent,
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
          serverMissing: Value(serverMissing),
          deleted: Value(deleted),
          hidden: Value(hidden),
          parent: Value(parent),
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
