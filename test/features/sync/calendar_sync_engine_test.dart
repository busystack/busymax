import 'dart:async';
import 'dart:convert';
import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import '../../support/recording_notification_backend.dart';
import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/calendar_providers/calendar_provider_capabilities.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/features/sync/cloud_calendar_range_coverage_service.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_shared_calendar_address.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  for (final incremental in [false, true]) {
    for (final cancelled in [false, true]) {
      test(
        '${incremental ? 'incremental' : 'full'} calendar sync reconciles ${cancelled ? 'cancellation' : 'rescheduling'} after a page failure',
        () async {
          final now = DateTime.utc(2026, 7, 15, 8);
          const source = CalendarSourceDto(
            provider: BusyProvider.google,
            providerCalendarId: 'cal-1',
            summary: 'Work',
          );
          await _insertAccount(database, provider: BusyProvider.google);
          await _insertSource(database, source);
          await _insertEvent(
            database,
            provider: BusyProvider.google,
            providerCalendarId: 'cal-1',
            remindersJson: {
              'overrides': [
                {'method': 'popup', 'minutes': 10},
              ],
            },
          );
          await NotificationScheduleService(
            database: database,
            nowUtc: () => now,
          ).rebuildUpcomingEventNotifications('account');
          expect(
            await database.select(database.notificationSchedule).get(),
            hasLength(1),
          );
          final client = _FakeCalendarClient(
            provider: BusyProvider.google,
            calendars: [source],
            pages: [
              CalendarSyncPageDto(
                events: [
                  CalendarEventDto(
                    provider: BusyProvider.google,
                    providerCalendarId: 'cal-1',
                    providerEventId: 'event-1',
                    title: 'Changed',
                    isCancelled: cancelled,
                    startDateTime: '2026-07-15T11:00:00Z',
                    endDateTime: '2026-07-15T12:00:00Z',
                    remindersJson: {
                      'overrides': [
                        {'method': 'popup', 'minutes': 10},
                      ],
                    },
                    rawJson: const {},
                  ),
                ],
                nextPageTokenOrUrl: 'later-page',
              ),
            ],
          );
          var reconciled = 0;
          final engine = CalendarSyncEngine(
            database: database,
            client: client,
            accountId: 'account',
            nowUtc: () => now,
            onNotificationScheduleChanged: () async {
              reconciled++;
            },
          );
          await expectLater(
            incremental ? engine.incrementalSync() : engine.fullSync(),
            throwsStateError,
          );
          expect(client.syncCalls, hasLength(2));
          expect(
            (await database.select(database.calendarEvents).get())
                .single
                .isCancelled,
            cancelled,
          );
          final reminders = await database
              .select(database.notificationSchedule)
              .get();
          if (cancelled) {
            expect(reminders, isEmpty);
          } else {
            expect(
              reminders.single.scheduledAtUtc,
              DateTime.utc(2026, 7, 15, 10, 50).millisecondsSinceEpoch,
            );
          }
          expect(reconciled, 2);
        },
      );
    }
  }

  for (final incremental in [false, true]) {
    for (final disabled in [false, true]) {
      test(
        'event alarm ${disabled ? 'removed' : 'moved'} during pending ${incremental ? 'incremental' : 'full'} sync cannot fire at its former time',
        () async {
          var now = DateTime.utc(2026, 7, 15, 8);
          const source = CalendarSourceDto(
            provider: BusyProvider.google,
            providerCalendarId: 'cal-1',
            summary: 'Work',
          );
          await _insertAccount(database, provider: BusyProvider.google);
          await _insertSource(database, source);
          await _insertEvent(
            database,
            provider: BusyProvider.google,
            providerCalendarId: 'cal-1',
            remindersJson: {
              'overrides': [
                {'method': 'popup', 'minutes': 10},
              ],
            },
          );
          await NotificationScheduleService(
            database: database,
            nowUtc: () => now,
          ).rebuildUpcomingEventNotifications('account');
          final client = _FakeCalendarClient(
            provider: BusyProvider.google,
            calendars: [source],
            pages: [
              CalendarSyncPageDto(
                events: [
                  CalendarEventDto(
                    provider: BusyProvider.google,
                    providerCalendarId: 'cal-1',
                    providerEventId: 'event-1',
                    title: 'Changed',
                    startDateTime: '2026-07-15T11:00:00Z',
                    endDateTime: '2026-07-15T12:00:00Z',
                    remindersJson: {
                      'overrides': [
                        if (!disabled) {'method': 'popup', 'minutes': 10},
                      ],
                    },
                    rawJson: const {},
                  ),
                ],
                nextPageTokenOrUrl: 'held',
              ),
            ],
          );
          client.secondPageStarted = Completer<void>();
          client.secondPageRelease = Completer<void>();
          final engine = CalendarSyncEngine(
            database: database,
            client: client,
            accountId: 'account',
            nowUtc: () => now,
          );
          final sync = expectLater(
            incremental ? engine.incrementalSync() : engine.fullSync(),
            throwsStateError,
          );
          await client.secondPageStarted!.future;
          final backend = RecordingNotificationBackend();
          final scheduler = NotificationScheduler(
            database: database,
            notifications: DesktopNotificationService(
              backend: backend,
              settings: AppSettings.defaults(),
            ),
            nowUtc: () => now,
          );
          addTearDown(scheduler.stop);
          try {
            expect(
              (await database.select(database.calendarEvents).getSingle())
                  .startDateTime,
              '2026-07-15T11:00:00Z',
            );
            now = DateTime.utc(2026, 7, 15, 8, 50);
            await scheduler.checkNow();
            expect(backend.requests, isEmpty);
            now = DateTime.utc(2026, 7, 15, 10, 50);
            await scheduler.checkNow();
            expect(backend.requests, hasLength(disabled ? 0 : 1));
          } finally {
            client.secondPageRelease!.complete();
            await sync;
          }
        },
      );
    }
  }

  for (final incremental in [false, true]) {
    test(
      'event reminder moved earlier during pending ${incremental ? 'incremental' : 'full'} sync fires once at its new time',
      () async {
        var now = DateTime.utc(2026, 7, 15, 8, 59);
        const source = CalendarSourceDto(
          provider: BusyProvider.google,
          providerCalendarId: 'cal-1',
          summary: 'Work',
        );
        await _insertAccount(database, provider: BusyProvider.google);
        await _insertSource(database, source);
        await _insertEvent(
          database,
          provider: BusyProvider.google,
          providerCalendarId: 'cal-1',
          remindersJson: {
            'overrides': [
              {'method': 'popup', 'minutes': 10},
            ],
          },
        );
        await database
            .update(database.calendarEvents)
            .write(
              const CalendarEventsCompanion(
                startDateTime: Value('2026-07-15T11:10:00Z'),
                endDateTime: Value('2026-07-15T12:10:00Z'),
              ),
            );
        await NotificationScheduleService(
          database: database,
          nowUtc: () => now,
        ).rebuildUpcomingEventNotifications('account');
        expect(
          (await database.select(database.notificationSchedule).getSingle())
              .scheduledAtUtc,
          DateTime.utc(2026, 7, 15, 11).millisecondsSinceEpoch,
        );
        final client = _FakeCalendarClient(
          provider: BusyProvider.google,
          calendars: [source],
          pages: const [
            CalendarSyncPageDto(
              events: [
                CalendarEventDto(
                  provider: BusyProvider.google,
                  providerCalendarId: 'cal-1',
                  providerEventId: 'event-1',
                  title: 'Changed',
                  startDateTime: '2026-07-15T09:10:00Z',
                  endDateTime: '2026-07-15T10:10:00Z',
                  remindersJson: {
                    'overrides': [
                      {'method': 'popup', 'minutes': 10},
                    ],
                  },
                  rawJson: {},
                ),
              ],
              nextPageTokenOrUrl: 'held',
            ),
          ],
        );
        client.secondPageStarted = Completer<void>();
        client.secondPageRelease = Completer<void>();
        final engine = CalendarSyncEngine(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => now,
        );
        final sync = expectLater(
          incremental ? engine.incrementalSync() : engine.fullSync(),
          throwsStateError,
        );
        await client.secondPageStarted!.future;
        expect(
          (await database.select(database.notificationSchedule).getSingle())
              .scheduledAtUtc,
          DateTime.utc(2026, 7, 15, 9).millisecondsSinceEpoch,
        );
        final backend = RecordingNotificationBackend();
        final scheduler = NotificationScheduler(
          database: database,
          notifications: DesktopNotificationService(
            backend: backend,
            settings: AppSettings.defaults(),
          ),
          nowUtc: () => now,
        );
        addTearDown(scheduler.stop);
        try {
          now = DateTime.utc(2026, 7, 15, 9);
          await scheduler.checkNow();
          expect(backend.requests, hasLength(1));
          now = DateTime.utc(2026, 7, 15, 11);
          await scheduler.checkNow();
          expect(backend.requests, hasLength(1));
        } finally {
          client.secondPageRelease!.complete();
          await sync;
        }
      },
    );
  }

  test('same-month sync reuses its cursor and one sync-state row', () async {
    const source = CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: 'cal-1',
      summary: 'Work',
      primaryCalendar: true,
    );
    await _insertAccount(database, provider: BusyProvider.google);
    await _insertSource(database, source);
    await database
        .into(database.syncCursors)
        .insert(
          SyncCursorsCompanion.insert(
            id:
                'account|google|events|account|google|cal-1|'
                '2025-07-01T00:00:00.000Z|2028-08-01T00:00:00.000Z',
            accountId: 'account',
            provider: 'google',
            transport: 'rest',
            syncScopeKind: 'events',
            cursorKind: 'google_sync_token',
            cursorValue: 'legacy-token',
            projectionSourceId: const Value('account|google|cal-1'),
            rangeStart: const Value('2025-07-01T00:00:00.000Z'),
            rangeEnd: const Value('2028-08-01T00:00:00.000Z'),
          ),
        );
    final client = _FakeCalendarClient(
      provider: BusyProvider.google,
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
    final states = await database.select(database.syncCursors).get();
    expect(states, hasLength(1));
    expect(states.single.id, 'account|google|events|account|google|cal-1');
    expect(states.single.cursorKind, 'google_sync_token');
    expect(states.single.cursorValue, 'google-token-2');
    expect(states.single.rangeStart, '2025-07-01T00:00:00.000Z');
    expect(states.single.rangeEnd, '2028-08-01T00:00:00.000Z');
  });

  test('a new month rebases the cursor without adding a state row', () async {
    const source = CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: 'cal-1',
      summary: 'Work',
    );
    await _insertAccount(database, provider: BusyProvider.google);
    final client = _FakeCalendarClient(
      provider: BusyProvider.google,
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
    final states = await database.select(database.syncCursors).get();
    expect(states, hasLength(1));
    expect(states.single.cursorValue, 'google-token-august');
    expect(states.single.rangeStart, '2025-08-01T00:00:00.000Z');
    expect(states.single.rangeEnd, '2028-09-01T00:00:00.000Z');
  });

  test(
    'legacy Google state without expansion marker establishes a new baseline',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        summary: 'Work',
      );
      await _insertAccount(database, provider: BusyProvider.google);
      await _insertSource(database, source);
      final repository = CalendarRepository(database: database);
      await repository.saveSyncState(
        accountId: 'account',
        provider: BusyProvider.google,
        syncKind: 'events',
        calendarSourceId: CalendarRepository.sourceId(
          accountId: 'account',
          provider: BusyProvider.google,
          providerCalendarId: source.providerCalendarId,
        ),
        rangeStart: '2025-07-01T00:00:00.000Z',
        rangeEnd: '2028-08-01T00:00:00.000Z',
        cursorKind: 'google_sync_token',
        cursorValue: 'legacy-unexpanded-token',
        full: true,
      );
      final client = _FakeCalendarClient(
        provider: BusyProvider.google,
        calendars: const [source],
        pages: const [
          CalendarSyncPageDto(
            events: [],
            nextSyncTokenOrDeltaLink: 'expanded-token-1',
          ),
          CalendarSyncPageDto(
            events: [],
            nextSyncTokenOrDeltaLink: 'expanded-token-2',
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
        'expanded-token-1',
      ]);
      final state = await repository.syncState(
        accountId: 'account',
        provider: BusyProvider.google,
        syncKind: 'events',
        calendarSourceId: CalendarRepository.sourceId(
          accountId: 'account',
          provider: BusyProvider.google,
          providerCalendarId: source.providerCalendarId,
        ),
      );
      expect(state, isNot(equals(null)));
      expect(state!.cursorValue, 'expanded-token-2');
      expect(state.stateJson, _expandedGoogleState);
    },
  );

  test(
    'incremental Google instances retire their synchronized recurrence master',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        summary: 'Work',
      );
      await _insertAccount(database, provider: BusyProvider.google);
      await _insertSource(database, source);
      final repository = CalendarRepository(database: database);
      const master = CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        providerEventId: 'series-1',
        title: 'Weekly planning',
        startDateTime: '2026-07-14T09:00:00.000Z',
        endDateTime: '2026-07-14T10:00:00.000Z',
        recurrenceJson: ['RRULE:FREQ=WEEKLY'],
        updatedAtServer: '2026-07-01T00:00:00.000Z',
        rawJson: {
          'id': 'series-1',
          'summary': 'Weekly planning',
          'recurrence': ['RRULE:FREQ=WEEKLY'],
        },
      );
      await repository.saveSyncState(
        accountId: 'account',
        provider: BusyProvider.google,
        syncKind: 'events',
        calendarSourceId: CalendarRepository.sourceId(
          accountId: 'account',
          provider: BusyProvider.google,
          providerCalendarId: source.providerCalendarId,
        ),
        rangeStart: '2025-07-01T00:00:00.000Z',
        rangeEnd: '2028-08-01T00:00:00.000Z',
        cursorKind: 'google_sync_token',
        cursorValue: 'expanded-token-1',
        stateJson: _expandedGoogleState,
        full: true,
      );
      const instance = CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        providerEventId: 'instance-1',
        providerRecurringEventId: 'series-1',
        providerOriginalStartKey: '2026-07-14T09:00:00.000Z',
        title: 'Weekly planning',
        startDateTime: '2026-07-14T09:00:00.000Z',
        endDateTime: '2026-07-14T10:00:00.000Z',
        updatedAtServer: '2026-07-10T00:00:00.000Z',
        rawJson: {
          'id': 'instance-1',
          'recurringEventId': 'series-1',
          'originalStartTime': {'dateTime': '2026-07-14T09:00:00.000Z'},
        },
      );
      final client = _FakeCalendarClient(
        provider: BusyProvider.google,
        calendars: const [source],
        eventsById: const {'series-1': master},
        pages: const [
          CalendarSyncPageDto(
            events: [instance],
            nextSyncTokenOrDeltaLink: 'expanded-token-2',
          ),
        ],
      );

      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 7, 10),
      ).incrementalSync();

      expect(client.syncCalls.single.syncTokenOrDeltaLink, 'expanded-token-1');
      final masterId = CalendarRepository.eventId(
        accountId: 'account',
        provider: BusyProvider.google,
        providerCalendarId: source.providerCalendarId,
        providerEventId: master.providerEventId,
      );
      final instanceId = CalendarRepository.eventId(
        accountId: 'account',
        provider: BusyProvider.google,
        providerCalendarId: source.providerCalendarId,
        providerEventId: instance.providerEventId,
        providerOriginalStartKey: instance.providerOriginalStartKey,
      );
      final events = await database.select(database.calendarEvents).get();
      final masterRow = events.singleWhere((event) => event.id == masterId);
      final instanceRow = events.singleWhere((event) => event.id == instanceId);
      expect(masterRow.isDeleted, isTrue);
      expect(instanceRow.isDeleted, isFalse);
      expect(instanceRow.providerRecurringEventId, master.providerEventId);

      await repository.deleteLocalEvent(
        instanceId,
        recurringScope: RecurringEventMutationScope.entireSeries,
      );
      final operation = await database.select(database.pendingOps).getSingle();
      expect(operation.baselineUpdatedUtc, master.updatedAtServer);
      expect(operation.baselineRawJson, contains('"id":"series-1"'));
    },
  );

  test(
    'Microsoft calendar-view occurrences hydrate their master for whole-series mutations',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'cal-1',
        summary: 'Work',
      );
      await _insertAccount(database, provider: BusyProvider.microsoft);
      const master = CalendarEventDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'cal-1',
        providerEventId: 'series-1',
        title: 'Weekly planning',
        startDateTime: '2026-07-14T09:00:00.000Z',
        endDateTime: '2026-07-14T10:00:00.000Z',
        recurrenceJson: {
          'pattern': {'type': 'weekly', 'interval': 1},
          'range': {'type': 'noEnd', 'startDate': '2026-07-14'},
        },
        eventType: 'seriesMaster',
        updatedAtServer: '2026-07-01T00:00:00.000Z',
        rawJson: {
          'id': 'series-1',
          'subject': 'Weekly planning',
          'type': 'seriesMaster',
          'lastModifiedDateTime': '2026-07-01T00:00:00.000Z',
        },
      );
      const occurrence = CalendarEventDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'cal-1',
        providerEventId: 'occurrence-1',
        providerRecurringEventId: 'series-1',
        providerOriginalStartKey: '2026-07-14T09:00:00.000Z',
        title: 'Weekly planning',
        startDateTime: '2026-07-14T09:00:00.000Z',
        endDateTime: '2026-07-14T10:00:00.000Z',
        eventType: 'occurrence',
        updatedAtServer: '2026-07-10T00:00:00.000Z',
        rawJson: {
          'id': 'occurrence-1',
          'seriesMasterId': 'series-1',
          'originalStart': '2026-07-14T09:00:00.000Z',
          'type': 'occurrence',
          'lastModifiedDateTime': '2026-07-10T00:00:00.000Z',
          'isOrganizer': true,
        },
      );
      final client = _FakeCalendarClient(
        provider: BusyProvider.microsoft,
        calendars: const [source],
        eventsById: const {'series-1': master},
        pages: const [
          CalendarSyncPageDto(events: [occurrence]),
        ],
      );

      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 7, 10),
      ).fullSync();

      final occurrenceId = CalendarRepository.eventId(
        accountId: 'account',
        provider: BusyProvider.microsoft,
        providerCalendarId: source.providerCalendarId,
        providerEventId: occurrence.providerEventId,
        providerOriginalStartKey: occurrence.providerOriginalStartKey,
      );
      final masterId = CalendarRepository.eventId(
        accountId: 'account',
        provider: BusyProvider.microsoft,
        providerCalendarId: source.providerCalendarId,
        providerEventId: master.providerEventId,
      );
      final storedMaster = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(masterId))).getSingle();
      expect(storedMaster.isDeleted, isTrue);
      expect(storedMaster.updatedAtServer, master.updatedAtServer);
      expect((jsonDecode(storedMaster.rawJson!) as Map)['id'], 'series-1');
      final repository = CalendarRepository(database: database);
      final detail = await repository.loadEventDetail(occurrenceId);
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail!).copyWith(
          title: 'Renamed series',
          recurringMutationScope: RecurringEventMutationScope.entireSeries,
        ),
      );
      await repository.deleteLocalEvent(
        occurrenceId,
        recurringScope: RecurringEventMutationScope.entireSeries,
      );

      final operations = await (database.select(
        database.pendingOps,
      )..orderBy([(row) => OrderingTerm.asc(row.createdAtUtc)])).get();
      expect(operations, hasLength(2));
      expect(operations.map((operation) => operation.operationType), [
        'event.patch',
        'event.delete',
      ]);
      expect(
        operations.map((operation) => operation.baselineUpdatedUtc),
        everyElement(master.updatedAtServer),
      );
      expect(
        operations.map(
          (operation) => (jsonDecode(operation.baselineRawJson!) as Map)['id'],
        ),
        everyElement(master.providerEventId),
      );
    },
  );

  test('no-cursor baseline reconciles a missing provider event', () async {
    const source = CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: 'cal-1',
      summary: 'Work',
    );
    await _insertAccount(database, provider: BusyProvider.google);
    await _insertSource(database, source);
    final eventId = await _insertEvent(
      database,
      provider: BusyProvider.google,
      providerCalendarId: source.providerCalendarId,
    );
    final client = _FakeCalendarClient(
      provider: BusyProvider.google,
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
      provider: BusyProvider.google,
      providerCalendarId: 'cal-1',
      summary: 'Work',
    );
    await _insertAccount(database, provider: BusyProvider.google);
    await _insertSource(database, source);
    final eventId = await _insertEvent(
      database,
      provider: BusyProvider.google,
      providerCalendarId: source.providerCalendarId,
    );
    await CalendarRepository(database: database).saveSyncState(
      accountId: 'account',
      provider: BusyProvider.google,
      syncKind: 'events',
      calendarSourceId: CalendarRepository.sourceId(
        accountId: 'account',
        provider: BusyProvider.google,
        providerCalendarId: source.providerCalendarId,
      ),
      rangeStart: '2025-07-01T00:00:00.000Z',
      rangeEnd: '2028-08-01T00:00:00.000Z',
      cursorKind: 'google_sync_token',
      cursorValue: 'google-token-1',
      stateJson: _expandedGoogleState,
      full: true,
    );
    final client = _FakeCalendarClient(
      provider: BusyProvider.google,
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
    'Microsoft full sync tombstones calendars absent from the collection',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'cal-deleted',
        summary: 'Deleted in Outlook',
      );
      await _insertAccount(database, provider: BusyProvider.microsoft);
      await _insertSource(database, source);
      final eventId = await _insertEvent(
        database,
        provider: BusyProvider.microsoft,
        providerCalendarId: source.providerCalendarId,
        remindersJson: const {
          'isReminderOn': true,
          'reminderMinutesBeforeStart': 30,
        },
      );
      final notificationService = NotificationScheduleService(
        database: database,
        nowUtc: () => DateTime.utc(2026, 7, 10),
      );
      await notificationService.rebuildUpcomingEventNotifications('account');
      expect(
        await database.select(database.notificationSchedule).get(),
        hasLength(1),
      );

      await CalendarSyncEngine(
        database: database,
        client: _FakeCalendarClient(
          provider: BusyProvider.microsoft,
          calendars: const [],
          pages: const [],
        ),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 7, 10),
      ).fullSync();

      final storedSource =
          await (database.select(
                database.calendarSources,
              )..where((row) => row.id.equals('account|microsoft|cal-deleted')))
              .getSingle();
      final storedEvent = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(storedSource.isDeleted, isTrue);
      expect(storedSource.hidden, isTrue);
      expect(storedEvent.isDeleted, isTrue);
      expect(
        await database.select(database.notificationSchedule).get(),
        isEmpty,
      );
    },
  );

  test(
    'owner-context calendar remains after /me snapshot and uses range view',
    () async {
      await _insertAccount(database, provider: BusyProvider.microsoft);
      final key = const MicrosoftSharedPrimaryCalendarAddress(
        owner: 'owner@example.com',
        graphCalendarId: 'owner-calendar',
      ).sourceCalendarId;
      await _insertSource(
        database,
        CalendarSourceDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: key,
          summary: 'Owner',
          primaryCalendar: false,
          readOnly: true,
        ),
      );
      final requests = <http.Request>[];
      final client = MicrosoftCalendarApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/v1.0/me/calendars') {
            return http.Response(
              jsonEncode({
                'value': [
                  {
                    'id': 'recipient-local',
                    'name': 'Local share',
                    'canEdit': false,
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/calendar')) {
            return http.Response(
              jsonEncode({
                'id': 'owner-calendar',
                'name': 'Owner',
                'canEdit': false,
                'isDefaultCalendar': true,
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'value': <Object>[]}), 200);
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        responseTimeZone: 'UTC',
      );
      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 7, 10),
      ).fullSync();
      final sources = await database.select(database.calendarSources).get();
      expect(sources, hasLength(2));
      expect(
        sources
            .where((source) => source.providerCalendarId == key)
            .single
            .isDeleted,
        isFalse,
      );
      expect(
        requests.any(
          (request) => request.url.path.contains(
            '/users/owner%40example.com/calendars/owner-calendar/calendarView',
          ),
        ),
        isTrue,
      );
      expect(
        requests.any(
          (request) => request.url.path.contains(
            '/me/calendars/recipient-local/calendarView',
          ),
        ),
        isTrue,
      );
      expect(
        requests.any(
          (request) => request.url.path.contains(
            '/users/owner%40example.com/calendarView/delta',
          ),
        ),
        isFalse,
      );
    },
  );

  test('removing an opened owner calendar wins an in-flight refresh', () async {
    await _insertAccount(database, provider: BusyProvider.microsoft);
    final key = const MicrosoftSharedPrimaryCalendarAddress(
      owner: 'owner@example.com',
      graphCalendarId: 'owner-calendar',
    ).sourceCalendarId;
    final repository = CalendarRepository(database: database);
    final source = CalendarSourceDto(
      provider: BusyProvider.microsoft,
      providerCalendarId: key,
      summary: 'Owner',
      readOnly: true,
      isRemovable: true,
    );
    await repository.upsertSource(accountId: 'account', source: source);
    final entered = Completer<void>();
    final release = Completer<void>();
    final requests = <http.Request>[];
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/v1.0/me/calendars') {
          return http.Response(jsonEncode({'value': <Object>[]}), 200);
        }
        if (request.url.path.endsWith('/calendar')) {
          entered.complete();
          await release.future;
          return http.Response(
            jsonEncode({
              'id': 'owner-calendar',
              'name': 'Owner',
              'canEdit': true,
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'value': <Object>[]}), 200);
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
    );
    final engine = CalendarSyncEngine(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 7, 10),
    );
    final running = engine.fullSync();
    await entered.future;
    await repository.deleteLocalSource('account|microsoft|$key');
    release.complete();
    await running;
    expect(
      (await database.select(database.calendarSources).getSingle()).isDeleted,
      isTrue,
    );
    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(
      requests.where((request) => request.url.path.contains('calendarView')),
      isEmpty,
    );
    await engine.fullSync();
    expect(
      requests.where((request) => request.url.path.endsWith('/calendar')),
      hasLength(1),
    );
    await repository.upsertSource(
      accountId: 'account',
      source: source,
      reopenLocallyRemovedOwner: true,
    );
    expect(
      (await database.select(database.calendarSources).get()),
      hasLength(1),
    );
    expect(
      (await database.select(database.calendarSources).getSingle()).isDeleted,
      isFalse,
    );
  });

  test(
    'Google full sync tombstones calendars absent from the calendar list',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-deleted',
        summary: 'Deleted in Google Calendar',
      );
      await _insertAccount(database, provider: BusyProvider.google);
      await _insertSource(database, source);
      final eventId = await _insertEvent(
        database,
        provider: BusyProvider.google,
        providerCalendarId: source.providerCalendarId,
      );

      await CalendarSyncEngine(
        database: database,
        client: _FakeCalendarClient(
          provider: BusyProvider.google,
          calendars: const [],
          pages: const [],
        ),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 7, 10),
      ).fullSync();

      final storedSource =
          await (database.select(database.calendarSources)
                ..where((row) => row.id.equals('account|google|cal-deleted')))
              .getSingle();
      final storedEvent = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(storedSource.isDeleted, isTrue);
      expect(storedSource.hidden, isTrue);
      expect(storedEvent.isDeleted, isTrue);
    },
  );

  test(
    'Microsoft incremental reconciliation preserves a queued calendar create',
    () async {
      const missingSource = CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'cal-deleted',
        summary: 'Deleted in Outlook',
      );
      await _insertAccount(database, provider: BusyProvider.microsoft);
      await _insertSource(database, missingSource);
      final repository = CalendarRepository(database: database);
      final localSourceId = await repository.createLocalSource(
        accountId: 'account',
        summary: 'Offline calendar',
      );
      await (database.update(
        database.pendingOps,
      )..where((row) => row.calendarSourceId.equals(localSourceId))).write(
        const PendingOpsCompanion(
          nextAttemptAtUtc: Value('9999-12-31T00:00:00.000Z'),
        ),
      );

      await CalendarSyncEngine(
        database: database,
        client: _FakeCalendarClient(
          provider: BusyProvider.microsoft,
          calendars: const [],
          pages: const [],
        ),
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 7, 10),
      ).incrementalSync();

      final sources = await database.select(database.calendarSources).get();
      expect(
        sources.singleWhere((source) => source.id == localSourceId).isDeleted,
        isFalse,
      );
      expect(
        sources
            .singleWhere((source) => source.providerCalendarId == 'cal-deleted')
            .isDeleted,
        isTrue,
      );
      expect(
        await (database.select(
          database.pendingOps,
        )..where((row) => row.calendarSourceId.equals(localSourceId))).get(),
        hasLength(1),
      );
    },
  );

  test(
    'Microsoft primary sync persists and reuses the terminal delta link',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'cal-primary',
        summary: 'Calendar',
        primaryCalendar: true,
      );
      const nextLink = 'https://graph.example/delta?page=2';
      const firstDeltaLink = 'https://graph.example/delta?state=one';
      const secondDeltaLink = 'https://graph.example/delta?state=two';
      await _insertAccount(database, provider: BusyProvider.microsoft);
      final client = _FakeCalendarClient(
        provider: BusyProvider.microsoft,
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
      final states = await database.select(database.syncCursors).get();
      expect(states, hasLength(1));
      expect(states.single.cursorKind, 'microsoft_delta_link');
      expect(states.single.cursorValue, secondDeltaLink);
    },
  );

  test(
    'Microsoft non-primary incremental sync reconciles each full snapshot',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'cal-secondary',
        summary: 'Shared',
        primaryCalendar: false,
      );
      await _insertAccount(database, provider: BusyProvider.microsoft);
      await _insertSource(database, source);
      final eventId = await _insertEvent(
        database,
        provider: BusyProvider.microsoft,
        providerCalendarId: source.providerCalendarId,
      );
      await CalendarRepository(database: database).saveSyncState(
        accountId: 'account',
        provider: BusyProvider.microsoft,
        syncKind: 'events',
        calendarSourceId: CalendarRepository.sourceId(
          accountId: 'account',
          provider: BusyProvider.microsoft,
          providerCalendarId: source.providerCalendarId,
        ),
        rangeStart: '2025-07-01T00:00:00.000Z',
        rangeEnd: '2028-08-01T00:00:00.000Z',
        cursorKind: 'microsoft_delta_link',
        cursorValue: 'https://graph.example/primary-delta',
        full: true,
      );
      final providerEvent = _event(
        provider: BusyProvider.microsoft,
        providerCalendarId: source.providerCalendarId,
      );
      final client = _FakeCalendarClient(
        provider: BusyProvider.microsoft,
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

  test('range snapshot is separate from the baseline cursor', () async {
    const source = CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: 'cal-1',
      summary: 'Work',
    );
    await _insertAccount(database, provider: BusyProvider.google);
    await _insertSource(database, source);
    final sourceId = CalendarRepository.sourceId(
      accountId: 'account',
      provider: BusyProvider.google,
      providerCalendarId: 'cal-1',
    );
    final repository = CalendarRepository(database: database);
    await repository.saveSyncState(
      accountId: 'account',
      provider: BusyProvider.google,
      syncKind: 'events',
      calendarSourceId: sourceId,
      cursorKind: 'google_sync_token',
      cursorValue: 'baseline-token',
    );
    final client = _FakeCalendarClient(
      provider: BusyProvider.google,
      calendars: const [source],
      pages: const [],
      onListEvents: (_, _, _) async => [
        const CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'cal-1',
          providerEventId: 'old',
          title: 'Old event',
          startDateTime: '2020-01-10T10:00:00Z',
          endDateTime: '2020-01-10T11:00:00Z',
        ),
      ],
    );
    await CalendarSyncEngine(
      database: database,
      client: client,
      accountId: 'account',
    ).retrieveMonth(DateTime.utc(2020));

    expect(client.listCalls, [DateTime.utc(2020)]);
    expect(
      (await repository.syncState(
        accountId: 'account',
        provider: BusyProvider.google,
        syncKind: 'events',
        calendarSourceId: sourceId,
      ))?.cursorValue,
      'baseline-token',
    );
    expect(
      (await database.select(database.calendarEvents).get()).single.title,
      'Old event',
    );
    expect(
      await repository.syncState(
        accountId: 'account',
        provider: BusyProvider.google,
        syncKind: 'events_range_2020_1',
        calendarSourceId: sourceId,
      ),
      isA<SyncCursor>(),
    );
  });

  test(
    'failed range retrieval retains cached events and no coverage',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'cal-1',
        summary: 'Work',
      );
      await _insertAccount(database, provider: BusyProvider.microsoft);
      await _insertSource(database, source);
      final eventId = await _insertEvent(
        database,
        provider: BusyProvider.microsoft,
        providerCalendarId: 'cal-1',
      );
      final client = _FakeCalendarClient(
        provider: BusyProvider.microsoft,
        calendars: const [source],
        pages: const [],
        onListEvents: (_, _, _) async => throw StateError('page two failed'),
      );
      final engine = CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
      );
      await expectLater(
        engine.retrieveMonth(DateTime.utc(2026, 7)),
        throwsStateError,
      );
      expect(
        (await (database.select(
          database.calendarEvents,
        )..where((row) => row.id.equals(eventId))).getSingle()).isDeleted,
        isFalse,
      );
      expect(await database.select(database.syncCursors).get(), isEmpty);
    },
  );

  test(
    'overlapping range requests share a month and reuse fresh coverage',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        summary: 'Work',
      );
      await _insertAccount(database, provider: BusyProvider.google);
      await _insertSource(database, source);
      final release = Completer<List<CalendarEventDto>>();
      final client = _FakeCalendarClient(
        provider: BusyProvider.google,
        calendars: const [source],
        pages: const [],
        onListEvents: (_, _, _) => release.future,
      );
      final coverage = CloudCalendarRangeCoverageService(
        database: database,
        nowUtc: () => DateTime.utc(2026, 7, 15),
        engineForAccount: (_, _) => CalendarSyncEngine(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 7, 15),
        ),
      );
      final first = coverage.ensureRange(
        DateTime.utc(2026, 7, 3),
        DateTime.utc(2026, 7, 12),
      );
      final second = coverage.ensureRange(
        DateTime.utc(2026, 7, 10),
        DateTime.utc(2026, 7, 20),
      );
      await Future<void>.delayed(Duration.zero);
      expect(client.listCalls, [DateTime.utc(2026, 7)]);
      release.complete([]);
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(
        await coverage.ensureRange(
          DateTime.utc(2026, 7, 21),
          DateTime.utc(2026, 7, 22),
        ),
        isTrue,
      );
      expect(client.listCalls, hasLength(1));
    },
  );

  test(
    'explicit search source retrieves an unselected cloud calendar',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'search-only',
        summary: 'Search only',
      );
      await _insertAccount(database, provider: BusyProvider.google);
      await _insertSource(database, source);
      final sourceId = CalendarRepository.sourceId(
        accountId: 'account',
        provider: BusyProvider.google,
        providerCalendarId: 'search-only',
      );
      await (database.update(
        database.calendarSources,
      )..where((row) => row.id.equals(sourceId))).write(
        const CalendarSourcesCompanion(
          selected: Value(false),
          hidden: Value(true),
        ),
      );
      final client = _FakeCalendarClient(
        provider: BusyProvider.google,
        calendars: const [source],
        pages: const [],
        onListEvents: (calendarId, _, _) async => [
          CalendarEventDto(
            provider: BusyProvider.google,
            providerCalendarId: calendarId,
            providerEventId: 'older-event',
            title: 'Older event',
            startDateTime: '2020-01-10T10:00:00Z',
            endDateTime: '2020-01-10T11:00:00Z',
          ),
        ],
      );
      final coverage = CloudCalendarRangeCoverageService(
        database: database,
        engineForAccount: (_, _) => CalendarSyncEngine(
          database: database,
          client: client,
          accountId: 'account',
        ),
      );

      expect(
        await coverage.ensureRange(
          DateTime.utc(2020, 1, 1),
          DateTime.utc(2020, 2, 1),
          sourceIds: {sourceId},
          sourceFilterActive: true,
        ),
        isTrue,
      );
      expect(client.listCalls, [DateTime.utc(2020)]);
      expect(
        (await database.select(database.calendarEvents).get()).single.title,
        'Older event',
      );
      expect(
        (await (database.select(
          database.calendarSources,
        )..where((row) => row.id.equals(sourceId))).getSingle()).selected,
        isFalse,
      );
    },
  );

  test(
    'changing explicit sources does not inherit an in-flight month',
    () async {
      const firstSource = CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'first',
        summary: 'First',
      );
      const secondSource = CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'second',
        summary: 'Second',
      );
      await _insertAccount(database, provider: BusyProvider.google);
      await _insertSource(database, firstSource);
      await _insertSource(database, secondSource);
      String sourceId(String calendarId) => CalendarRepository.sourceId(
        accountId: 'account',
        provider: BusyProvider.google,
        providerCalendarId: calendarId,
      );
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<List<CalendarEventDto>>();
      final client = _FakeCalendarClient(
        provider: BusyProvider.google,
        calendars: const [firstSource, secondSource],
        pages: const [],
        onListEvents: (calendarId, _, _) {
          if (calendarId == 'first') {
            firstStarted.complete();
            return releaseFirst.future;
          }
          return Future.value(const []);
        },
      );
      final coverage = CloudCalendarRangeCoverageService(
        database: database,
        engineForAccount: (_, _) => CalendarSyncEngine(
          database: database,
          client: client,
          accountId: 'account',
        ),
      );
      final first = coverage.ensureRange(
        DateTime.utc(2020, 1),
        DateTime.utc(2020, 2),
        sourceIds: {sourceId('first')},
        sourceFilterActive: true,
      );
      await firstStarted.future;
      expect(
        await coverage
            .ensureRange(
              DateTime.utc(2020, 1),
              DateTime.utc(2020, 2),
              sourceIds: {sourceId('second')},
              sourceFilterActive: true,
            )
            .timeout(const Duration(seconds: 3)),
        isTrue,
      );
      expect(client.listCalendarIds, containsAll(['first', 'second']));
      releaseFirst.complete(const []);
      expect(await first, isTrue);
    },
  );

  test('an unrelated account failure cannot fail an explicit source', () async {
    const selected = CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: 'selected',
      summary: 'Selected',
    );
    const unrelated = CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: 'unrelated',
      summary: 'Unrelated',
    );
    await _insertAccount(database, provider: BusyProvider.google);
    await _insertSource(database, selected);
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'other-account',
            provider: BusyProvider.google.storageValue,
            authority: 'https://accounts.google.com',
            providerAccountId: 'other-account',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            grantedScopes: const Value(''),
            createdAtUtc: '2026-07-01T00:00:00.000Z',
            updatedAtUtc: '2026-07-01T00:00:00.000Z',
          ),
        );
    await CalendarRepository(
      database: database,
    ).upsertSource(accountId: 'other-account', source: unrelated);
    final selectedId = CalendarRepository.sourceId(
      accountId: 'account',
      provider: BusyProvider.google,
      providerCalendarId: 'selected',
    );
    final requestedClient = _FakeCalendarClient(
      provider: BusyProvider.google,
      calendars: const [selected],
      pages: const [],
      onListEvents: (_, _, _) async => const [],
    );
    final unrelatedClient = _FakeCalendarClient(
      provider: BusyProvider.google,
      calendars: const [unrelated],
      pages: const [],
      onListEvents: (_, _, _) async => throw StateError('unrelated failure'),
    );
    final coverage = CloudCalendarRangeCoverageService(
      database: database,
      engineForAccount: (accountId, _) => CalendarSyncEngine(
        database: database,
        client: accountId == 'account' ? requestedClient : unrelatedClient,
        accountId: accountId,
      ),
    );
    expect(
      await coverage.ensureRange(
        DateTime.utc(2020, 1),
        DateTime.utc(2020, 2),
        sourceIds: {selectedId},
        sourceFilterActive: true,
      ),
      isTrue,
    );
    expect(requestedClient.listCalls, hasLength(1));
    expect(unrelatedClient.listCalls, isEmpty);
  });

  test(
    'range reconciliation deletes only clean missing events inside month',
    () async {
      const source = CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        summary: 'Work',
      );
      await _insertAccount(database, provider: BusyProvider.google);
      await _insertSource(database, source);
      final repository = CalendarRepository(database: database);
      Future<void> insert(String id, String start) => repository.upsertEvent(
        accountId: 'account',
        event: CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'cal-1',
          providerEventId: id,
          title: id,
          startDateTime: start,
          endDateTime: DateTime.parse(
            start,
          ).add(const Duration(hours: 1)).toIso8601String(),
          rawJson: {'id': id},
        ),
      );
      await insert('missing-july', '2026-07-04T09:00:00Z');
      await insert('dirty-july', '2026-07-05T09:00:00Z');
      await insert('outside-august', '2026-08-04T09:00:00Z');
      await (database.update(
        database.calendarEvents,
      )..where((row) => row.providerEventId.equals('dirty-july'))).write(
        const CalendarEventsCompanion(syncStatus: Value('pending_update')),
      );
      final client = _FakeCalendarClient(
        provider: BusyProvider.google,
        calendars: const [source],
        pages: const [],
        onListEvents: (_, _, _) async => const [],
      );
      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
      ).retrieveMonth(DateTime.utc(2026, 7));
      final rows = await database.select(database.calendarEvents).get();
      final byId = {for (final row in rows) row.providerEventId: row};
      expect(byId['missing-july']!.isDeleted, isTrue);
      expect(byId['dirty-july']!.isDeleted, isFalse);
      expect(byId['outside-august']!.isDeleted, isFalse);
    },
  );

  test('month reconciliation resolves offset-free provider zone', () async {
    const source = CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: 'cal-1',
      summary: 'Work',
    );
    await _insertAccount(database, provider: BusyProvider.google);
    await _insertSource(database, source);
    await CalendarRepository(database: database).upsertEvent(
      accountId: 'account',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        providerEventId: 'cross-month-zone',
        title: 'Cross month',
        startDateTime: '2026-07-31T14:00:00',
        startTimeZone: 'Pacific/Pago_Pago',
        endDateTime: '2026-07-31T15:00:00',
        endTimeZone: 'Pacific/Pago_Pago',
      ),
    );
    final client = _FakeCalendarClient(
      provider: BusyProvider.google,
      calendars: const [source],
      pages: const [],
      onListEvents: (_, _, _) async => const [],
    );
    await CalendarSyncEngine(
      database: database,
      client: client,
      accountId: 'account',
    ).retrieveMonth(DateTime.utc(2026, 8));
    expect(
      (await database.select(database.calendarEvents).get()).single.isDeleted,
      isTrue,
    );
  });
}

const _expandedGoogleState = '{"singleEvents":true,"version":1}';

Future<void> _insertAccount(
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
  Object? remindersJson,
}) async {
  final event = _event(
    provider: provider,
    providerCalendarId: providerCalendarId,
    remindersJson: remindersJson,
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
  Object? remindersJson,
}) {
  return CalendarEventDto(
    provider: provider,
    providerCalendarId: providerCalendarId,
    providerEventId: 'event-1',
    title: 'Planning',
    startDateTime: '2026-07-15T09:00:00.000Z',
    endDateTime: '2026-07-15T10:00:00.000Z',
    remindersJson: remindersJson,
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
    this.eventsById = const {},
    this.onListEvents,
  }) : _pages = List.of(pages);

  @override
  final BusyProvider provider;
  final List<CalendarSourceDto> calendars;
  final Map<String, CalendarEventDto> eventsById;
  final Future<List<CalendarEventDto>> Function(
    String calendarId,
    DateTime start,
    DateTime end,
  )?
  onListEvents;
  final List<DateTime> listCalls = [];
  final List<String> listCalendarIds = [];
  final List<CalendarSyncPageDto> _pages;
  final List<_SyncCall> syncCalls = [];
  Completer<void>? secondPageStarted;
  Completer<void>? secondPageRelease;

  @override
  CalendarProviderCapabilities get capabilities =>
      provider == BusyProvider.microsoft
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
    if (syncCalls.length == 2) {
      secondPageStarted?.complete();
      await secondPageRelease?.future;
    }
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
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
    String? ifMatch,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CalendarEventDto> moveEvent({
    required String sourceCalendarId,
    required String eventId,
    required String destinationCalendarId,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CalendarEventDto> getEvent({
    required String calendarId,
    required String eventId,
  }) async {
    final event = eventsById[eventId];
    if (event == null) {
      throw StateError('No fake event exists for $eventId.');
    }
    return event;
  }

  @override
  Future<List<CalendarEventDto>> listEventInstances({
    required String calendarId,
    required String recurringEventId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return Future.value(const []);
  }

  @override
  Future<List<CalendarEventDto>> listEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? pageTokenOrUrl,
  }) {
    listCalls.add(rangeStart);
    listCalendarIds.add(calendarId);
    return onListEvents?.call(calendarId, rangeStart, rangeEnd) ??
        Future.value(const []);
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
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
    String? ifMatch,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CalendarEventDto?> respondToEvent({
    required String calendarId,
    required String eventId,
    required CalendarInvitationResponse response,
    String? attendeeEmail,
    bool sendResponse = true,
  }) {
    throw UnimplementedError();
  }
}
