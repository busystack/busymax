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
