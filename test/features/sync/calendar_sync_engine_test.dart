import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/calendar_providers/calendar_provider_capabilities.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('same-month sync reuses its cursor and one sync-state row', () async {
    const source = CalendarSourceDto(
      provider: TaskProvider.google,
      providerCalendarId: 'cal-1',
      summary: 'Work',
      primaryCalendar: true,
    );
    await _insertAccount(database, provider: TaskProvider.google);
    await _insertSource(database, source);
    await database
        .into(database.calendarSyncStates)
        .insert(
          CalendarSyncStatesCompanion.insert(
            id:
                'account|google|events|account|google|cal-1|'
                '2025-07-01T00:00:00.000Z|2028-08-01T00:00:00.000Z',
            accountId: 'account',
            provider: 'google',
            syncKind: 'events',
            calendarSourceId: const Value('account|google|cal-1'),
            rangeStart: const Value('2025-07-01T00:00:00.000Z'),
            rangeEnd: const Value('2028-08-01T00:00:00.000Z'),
            googleSyncToken: const Value('legacy-token'),
          ),
        );
    final client = _FakeCalendarClient(
      provider: TaskProvider.google,
      calendars: const [source],
      pages: const [
        CalendarSyncPageDto(
          events: [],
          nextSyncTokenOrDeltaLink: 'google-token-1',
        ),
        CalendarSyncPageDto(
          events: [],
          nextSyncTokenOrDeltaLink: 'google-token-2',
        ),
      ],
    );
    var now = DateTime.utc(2026, 7, 2, 8, 30);
    final engine = CalendarSyncEngine(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => now,
    );

    await engine.incrementalSync();
    now = DateTime.utc(2026, 7, 31, 23, 59);
    await engine.incrementalSync();

    expect(client.syncCalls.map((call) => call.syncTokenOrDeltaLink), [
      null,
      'google-token-1',
    ]);
    for (final call in client.syncCalls) {
      expect(call.rangeStart, DateTime.utc(2025, 7));
      expect(call.rangeEnd, DateTime.utc(2028, 8));
      expect(call.primaryCalendar, isTrue);
    }
    final states = await database.select(database.calendarSyncStates).get();
    expect(states, hasLength(1));
    expect(states.single.id, 'account|google|events|account|google|cal-1');
    expect(states.single.googleSyncToken, 'google-token-2');
    expect(states.single.rangeStart, '2025-07-01T00:00:00.000Z');
    expect(states.single.rangeEnd, '2028-08-01T00:00:00.000Z');
  });

  test('a new month rebases the cursor without adding a state row', () async {
    const source = CalendarSourceDto(
      provider: TaskProvider.google,
      providerCalendarId: 'cal-1',
      summary: 'Work',
    );
    await _insertAccount(database, provider: TaskProvider.google);
    final client = _FakeCalendarClient(
      provider: TaskProvider.google,
      calendars: const [source],
      pages: const [
        CalendarSyncPageDto(
          events: [],
          nextSyncTokenOrDeltaLink: 'google-token-july',
        ),
        CalendarSyncPageDto(
          events: [],
          nextSyncTokenOrDeltaLink: 'google-token-august',
        ),
      ],
    );
    var now = DateTime.utc(2026, 7, 31, 23, 59);
    final engine = CalendarSyncEngine(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => now,
    );

    await engine.incrementalSync();
    now = DateTime.utc(2026, 8, 1);
    await engine.incrementalSync();

    expect(client.syncCalls.map((call) => call.syncTokenOrDeltaLink), [
      null,
      null,
    ]);
    expect(client.syncCalls[0].rangeStart, DateTime.utc(2025, 7));
    expect(client.syncCalls[0].rangeEnd, DateTime.utc(2028, 8));
    expect(client.syncCalls[1].rangeStart, DateTime.utc(2025, 8));
    expect(client.syncCalls[1].rangeEnd, DateTime.utc(2028, 9));
    final states = await database.select(database.calendarSyncStates).get();
    expect(states, hasLength(1));
    expect(states.single.googleSyncToken, 'google-token-august');
    expect(states.single.rangeStart, '2025-08-01T00:00:00.000Z');
    expect(states.single.rangeEnd, '2028-09-01T00:00:00.000Z');
  });

  test('no-cursor baseline reconciles a missing provider event', () async {
    const source = CalendarSourceDto(
      provider: TaskProvider.google,
      providerCalendarId: 'cal-1',
      summary: 'Work',
    );
    await _insertAccount(database, provider: TaskProvider.google);
    await _insertSource(database, source);
    final eventId = await _insertEvent(
      database,
      provider: TaskProvider.google,
      providerCalendarId: source.providerCalendarId,
    );
    final client = _FakeCalendarClient(
      provider: TaskProvider.google,
      calendars: const [source],
      pages: const [
        CalendarSyncPageDto(
          events: [],
          nextSyncTokenOrDeltaLink: 'google-token-1',
        ),
      ],
    );

    await CalendarSyncEngine(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 7, 10),
    ).incrementalSync();

    final event = await (database.select(
      database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    expect(event.isDeleted, isTrue);
  });

  test('empty cursor delta does not delete unchanged local events', () async {
    const source = CalendarSourceDto(
      provider: TaskProvider.google,
      providerCalendarId: 'cal-1',
      summary: 'Work',
    );
    await _insertAccount(database, provider: TaskProvider.google);
    await _insertSource(database, source);
    final eventId = await _insertEvent(
      database,
      provider: TaskProvider.google,
      providerCalendarId: source.providerCalendarId,
    );
    await CalendarRepository(database: database).saveSyncState(
      accountId: 'account',
      provider: TaskProvider.google,
      syncKind: 'events',
      calendarSourceId: CalendarRepository.sourceId(
        accountId: 'account',
        provider: TaskProvider.google,
        providerCalendarId: source.providerCalendarId,
      ),
      rangeStart: '2025-07-01T00:00:00.000Z',
      rangeEnd: '2028-08-01T00:00:00.000Z',
      googleSyncToken: 'google-token-1',
      full: true,
    );
    final client = _FakeCalendarClient(
      provider: TaskProvider.google,
      calendars: const [source],
      pages: const [
        CalendarSyncPageDto(
          events: [],
          nextSyncTokenOrDeltaLink: 'google-token-2',
        ),
      ],
    );

    await CalendarSyncEngine(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 7, 10),
    ).incrementalSync();

    final event = await (database.select(
      database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    expect(client.syncCalls.single.syncTokenOrDeltaLink, 'google-token-1');
    expect(event.isDeleted, isFalse);
  });

  test(
    'Microsoft primary sync persists and reuses the terminal delta link',
    () async {
      const source = CalendarSourceDto(
        provider: TaskProvider.microsoft,
        providerCalendarId: 'cal-primary',
        summary: 'Calendar',
        primaryCalendar: true,
      );
      const nextLink = 'https://graph.example/delta?page=2';
      const firstDeltaLink = 'https://graph.example/delta?state=one';
      const secondDeltaLink = 'https://graph.example/delta?state=two';
      await _insertAccount(database, provider: TaskProvider.microsoft);
      final client = _FakeCalendarClient(
        provider: TaskProvider.microsoft,
        calendars: const [source],
        pages: const [
          CalendarSyncPageDto(events: [], nextPageTokenOrUrl: nextLink),
          CalendarSyncPageDto(
            events: [],
            nextSyncTokenOrDeltaLink: firstDeltaLink,
          ),
          CalendarSyncPageDto(
            events: [],
            nextSyncTokenOrDeltaLink: secondDeltaLink,
          ),
        ],
      );
      final engine = CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 7, 10),
      );

      await engine.incrementalSync();
      await engine.incrementalSync();

      expect(client.syncCalls.map((call) => call.syncTokenOrDeltaLink), [
        null,
        nextLink,
        firstDeltaLink,
      ]);
      expect(
        client.syncCalls.map((call) => call.primaryCalendar),
        everyElement(isTrue),
      );
      final states = await database.select(database.calendarSyncStates).get();
      expect(states, hasLength(1));
      expect(states.single.microsoftDeltaLink, secondDeltaLink);
    },
  );

  test(
    'Microsoft non-primary incremental sync reconciles each full snapshot',
    () async {
      const source = CalendarSourceDto(
        provider: TaskProvider.microsoft,
        providerCalendarId: 'cal-secondary',
        summary: 'Shared',
        primaryCalendar: false,
      );
      await _insertAccount(database, provider: TaskProvider.microsoft);
      await _insertSource(database, source);
      final eventId = await _insertEvent(
        database,
        provider: TaskProvider.microsoft,
        providerCalendarId: source.providerCalendarId,
      );
      await CalendarRepository(database: database).saveSyncState(
        accountId: 'account',
        provider: TaskProvider.microsoft,
        syncKind: 'events',
        calendarSourceId: CalendarRepository.sourceId(
          accountId: 'account',
          provider: TaskProvider.microsoft,
          providerCalendarId: source.providerCalendarId,
        ),
        rangeStart: '2025-07-01T00:00:00.000Z',
        rangeEnd: '2028-08-01T00:00:00.000Z',
        microsoftDeltaLink: 'https://graph.example/primary-delta',
        full: true,
      );
      final providerEvent = _event(
        provider: TaskProvider.microsoft,
        providerCalendarId: source.providerCalendarId,
      );
      final client = _FakeCalendarClient(
        provider: TaskProvider.microsoft,
        calendars: const [source],
        pages: [
          CalendarSyncPageDto(events: [providerEvent]),
          const CalendarSyncPageDto(events: []),
        ],
      );
      final engine = CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 7, 10),
      );

      await engine.incrementalSync();
      var event = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(event.isDeleted, isFalse);

      await engine.incrementalSync();

      event = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(event.isDeleted, isTrue);
      expect(client.syncCalls.map((call) => call.primaryCalendar), [
        false,
        false,
      ]);
      expect(client.syncCalls.map((call) => call.syncTokenOrDeltaLink), [
        null,
        null,
      ]);
    },
  );
}

Future<void> _insertAccount(
  AppDatabase database, {
  required BusyProvider provider,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: Value(provider.storageValue),
          authState: const Value('signed_in'),
          grantedScopes: const Value(''),
          createdAtUtc: '2026-07-01T00:00:00.000Z',
          updatedAtUtc: '2026-07-01T00:00:00.000Z',
        ),
      );
}

Future<void> _insertSource(AppDatabase database, CalendarSourceDto source) {
  return CalendarRepository(
    database: database,
  ).upsertSource(accountId: 'account', source: source);
}

Future<String> _insertEvent(
  AppDatabase database, {
  required BusyProvider provider,
  required String providerCalendarId,
}) async {
  final event = _event(
    provider: provider,
    providerCalendarId: providerCalendarId,
  );
  await CalendarRepository(
    database: database,
  ).upsertEvent(accountId: 'account', event: event);
  return CalendarRepository.eventId(
    accountId: 'account',
    provider: provider,
    providerCalendarId: providerCalendarId,
    providerEventId: event.providerEventId,
  );
}

CalendarEventDto _event({
  required BusyProvider provider,
  required String providerCalendarId,
}) {
  return CalendarEventDto(
    provider: provider,
    providerCalendarId: providerCalendarId,
    providerEventId: 'event-1',
    title: 'Planning',
    startDateTime: '2026-07-15T09:00:00.000Z',
    endDateTime: '2026-07-15T10:00:00.000Z',
    updatedAtServer: '2026-07-01T00:00:00.000Z',
    rawJson: const {
      'id': 'event-1',
      'summary': 'Planning',
      'updated': '2026-07-01T00:00:00.000Z',
    },
  );
}

class _SyncCall {
  const _SyncCall({
    required this.rangeStart,
    required this.rangeEnd,
    required this.syncTokenOrDeltaLink,
    required this.primaryCalendar,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String? syncTokenOrDeltaLink;
  final bool primaryCalendar;
}

class _FakeCalendarClient implements CloudCalendarClient {
  _FakeCalendarClient({
    required this.provider,
    required this.calendars,
    required List<CalendarSyncPageDto> pages,
  }) : _pages = List.of(pages);

  @override
  final BusyProvider provider;
  final List<CalendarSourceDto> calendars;
  final List<CalendarSyncPageDto> _pages;
  final List<_SyncCall> syncCalls = [];

  @override
  CalendarProviderCapabilities get capabilities =>
      provider == TaskProvider.microsoft
      ? microsoftCalendarProviderCapabilities
      : googleCalendarProviderCapabilities;

  @override
  Future<List<CalendarSourceDto>> listCalendars() async => calendars;

  @override
  Future<CalendarSyncPageDto> syncEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? syncTokenOrDeltaLink,
    bool primaryCalendar = false,
  }) async {
    syncCalls.add(
      _SyncCall(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        syncTokenOrDeltaLink: syncTokenOrDeltaLink,
        primaryCalendar: primaryCalendar,
      ),
    );
    if (_pages.isEmpty) {
      throw StateError('No fake calendar sync page remains.');
    }
    return _pages.removeAt(0);
  }

  @override
  Future<CalendarSourceDto> createCalendar(CalendarMutation mutation) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCalendar(String calendarId) {
    throw UnimplementedError();
  }

  @override
  Future<List<BusySlotDto>> freeBusy({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CalendarEventDto> createEvent({
    required String calendarId,
    required CalendarEventMutation mutation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CalendarEventDto> getEvent({
    required String calendarId,
    required String eventId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CalendarEventDto>> listEventInstances({
    required String calendarId,
    required String recurringEventId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CalendarEventDto>> listEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? pageTokenOrUrl,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CalendarSourceDto> updateCalendar(
    String calendarId,
    CalendarMutation mutation,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CalendarEventDto> updateEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
  }) {
    throw UnimplementedError();
  }
}
