import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CalendarRepository repository;
  late int schedulerCalls;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    schedulerCalls = 0;
    repository = CalendarRepository(
      database: database,
      now: () => DateTime.utc(2026, 6, 8, 8),
      onNotificationScheduleChanged: () async => schedulerCalls += 1,
    );
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'google:g',
            provider: const Value('google'),
            authState: const Value('signed_in'),
            grantedScopes: const Value(''),
            createdAtUtc: '2026-06-08T00:00:00.000Z',
            updatedAtUtc: '2026-06-08T00:00:00.000Z',
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('provider upsert preserves locally deselected source', () async {
    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: TaskProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Original',
      ),
    );
    await repository.setSourceSelected('google:g|google|calendar-1', false);

    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: TaskProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Updated by provider',
        selected: true,
      ),
    );

    final source = await database.select(database.calendarSources).getSingle();
    expect(source.summary, 'Updated by provider');
    expect(source.selected, isFalse);
  });

  test('provider upsert seeds visibility for a new source', () async {
    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: TaskProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Hidden at provider',
        selected: false,
      ),
    );

    final source = await database.select(database.calendarSources).getSingle();
    expect(source.selected, isFalse);
  });

  test('provider upsert cannot resurrect a locally deleted source', () async {
    await _upsertSource(repository);
    await repository.deleteLocalSource(_sourceId);

    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: TaskProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Still returned by provider',
        hidden: false,
        isDeleted: false,
      ),
    );

    final source = await database.select(database.calendarSources).getSingle();
    expect(source.hidden, isTrue);
    expect(source.isDeleted, isTrue);
  });

  test('source stream removes locally tombstoned calendars', () async {
    await _upsertSource(repository);
    expect(
      await repository.watchSourcesForAccounts(const ['google:g']).first,
      hasLength(1),
    );

    await repository.deleteLocalSource(_sourceId);

    expect(
      await repository.watchSourcesForAccounts(const ['google:g']).first,
      isEmpty,
    );
  });

  test('provider hidden state can return to visible', () async {
    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: TaskProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Calendar',
        hidden: true,
      ),
    );

    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: TaskProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Calendar',
        hidden: false,
      ),
    );

    final source = await database.select(database.calendarSources).getSingle();
    expect(source.hidden, isFalse);
  });

  test('deselecting a source immediately removes its reminders', () async {
    await _seedScheduledEvent(repository, database);
    schedulerCalls = 0;

    await repository.setSourceSelected(_sourceId, false);

    expect(await database.select(database.notificationSchedule).get(), isEmpty);
    expect(schedulerCalls, 1);
  });

  test('deleting a source immediately removes its reminders', () async {
    await _seedScheduledEvent(repository, database);
    schedulerCalls = 0;

    await repository.deleteLocalSource(_sourceId);

    expect(await database.select(database.notificationSchedule).get(), isEmpty);
    expect(schedulerCalls, 1);
  });

  test(
    'read-only source rejects event creation before local mutation',
    () async {
      await repository.upsertSource(
        accountId: 'google:g',
        source: const CalendarSourceDto(
          provider: TaskProvider.google,
          providerCalendarId: 'calendar-1',
          summary: 'Shared calendar',
          readOnly: true,
        ),
      );

      await expectLater(
        repository.createLocalEvent(_newEventDraft()),
        throwsA(
          isA<CalendarMutationNotAllowed>().having(
            (error) => error.operation,
            'operation',
            CalendarMutationOperation.createEvent,
          ),
        ),
      );

      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test('read-only source rejects event edits and deletes', () async {
    await _upsertSource(repository);
    await repository.createLocalEvent(_newEventDraft());
    final event = await database.select(database.calendarEvents).getSingle();
    await (database.update(database.calendarSources)
          ..where((row) => row.id.equals(_sourceId)))
        .write(const CalendarSourcesCompanion(readOnly: Value(true)));
    final pendingBefore = await database.select(database.pendingOps).get();

    await expectLater(
      repository.updateLocalEvent(
        EventEditorDraft.existing(
          eventId: event.id,
          accountId: event.accountId,
          sourceId: event.calendarSourceId,
          providerCalendarId: event.providerCalendarId,
          title: 'Updated title',
          allDay: event.allDay,
          start: DateTime.utc(2026, 6, 8, 9),
          end: DateTime.utc(2026, 6, 8, 10),
        ),
      ),
      throwsA(
        isA<CalendarMutationNotAllowed>().having(
          (error) => error.operation,
          'operation',
          CalendarMutationOperation.editEvent,
        ),
      ),
    );
    await expectLater(
      repository.deleteLocalEvent(event.id),
      throwsA(
        isA<CalendarMutationNotAllowed>().having(
          (error) => error.operation,
          'operation',
          CalendarMutationOperation.deleteEvent,
        ),
      ),
    );

    final unchanged = await database
        .select(database.calendarEvents)
        .getSingle();
    expect(unchanged.title, '');
    expect(unchanged.isDeleted, isFalse);
    expect(
      await database.select(database.pendingOps).get(),
      hasLength(pendingBefore.length),
    );
  });
}

const _sourceId = 'google:g|google|calendar-1';

Future<void> _upsertSource(CalendarRepository repository) {
  return repository.upsertSource(
    accountId: 'google:g',
    source: const CalendarSourceDto(
      provider: TaskProvider.google,
      providerCalendarId: 'calendar-1',
      summary: 'Calendar',
    ),
  );
}

EventEditorDraft _newEventDraft() {
  return EventEditorDraft.newEvent(
    accountId: 'google:g',
    sourceId: _sourceId,
    providerCalendarId: 'calendar-1',
    start: DateTime.utc(2026, 6, 8, 9),
    end: DateTime.utc(2026, 6, 8, 10),
  );
}

Future<void> _seedScheduledEvent(
  CalendarRepository repository,
  AppDatabase database,
) async {
  await _upsertSource(repository);
  await repository.createLocalEvent(
    EventEditorDraft.newEvent(
      accountId: 'google:g',
      sourceId: _sourceId,
      providerCalendarId: 'calendar-1',
      start: DateTime.utc(2026, 6, 8, 9),
      end: DateTime.utc(2026, 6, 8, 10),
    ).copyWith(
      title: 'Standup',
      reminders: const {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 10},
        ],
      },
    ),
  );
  expect(
    await database.select(database.notificationSchedule).get(),
    hasLength(1),
  );
}
