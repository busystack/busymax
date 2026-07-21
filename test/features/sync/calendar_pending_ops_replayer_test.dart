import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/calendar_providers/calendar_provider_capabilities.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/sync/calendar_pending_ops_replayer.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/google_calendar/google_calendar_errors.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late _FakeCalendarClient client;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    client = _FakeCalendarClient();
    await _insertAccount(database);
    await CalendarRepository(database: database).upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: TaskProvider.google,
        providerCalendarId: 'cal-1',
        summary: 'Work',
        timeZone: 'America/Vancouver',
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'event create pending op calls provider createEvent and deletes op',
    () async {
      await CalendarRepository(database: database).createLocalEvent(
        EventEditorDraft.newEvent(
          accountId: 'account',
          sourceId: 'account|google|cal-1',
          providerCalendarId: 'cal-1',
          start: DateTime.utc(2026, 6, 8, 9),
          end: DateTime.utc(2026, 6, 8, 10),
        ).copyWith(title: 'Planning'),
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      ).replayDueOps();

      expect(applied, 1);
      expect(client.calls, ['createEvent:cal-1:Planning']);
      expect(
        await database.pendingOpsDao.pendingOpsForReplay('account', _later),
        isEmpty,
      );
      final rows = await database.select(database.calendarEvents).get();
      expect(rows.single.providerEventId, 'server-event-1');
      expect(rows.single.startTimeZone, 'America/Vancouver');
      expect(rows.single.endTimeZone, 'America/Vancouver');
      expect(client.createdMutations.single.startTimeZone, 'America/Vancouver');
      expect(client.createdMutations.single.endTimeZone, 'America/Vancouver');
    },
  );

  test(
    'local Google event create uses app local timezone over UTC source',
    () async {
      await CalendarRepository(database: database).upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: TaskProvider.google,
          providerCalendarId: 'cal-1',
          summary: 'Work',
          timeZone: 'UTC',
        ),
      );

      await CalendarRepository(
        database: database,
        localTimeZone: 'America/Vancouver',
      ).createLocalEvent(
        EventEditorDraft.newEvent(
          accountId: 'account',
          sourceId: 'account|google|cal-1',
          providerCalendarId: 'cal-1',
          start: DateTime(2026, 6, 8, 9),
          end: DateTime(2026, 6, 8, 10),
        ).copyWith(title: 'Planning'),
      );

      final event = await database.select(database.calendarEvents).getSingle();
      final op = await database.select(database.pendingOps).getSingle();
      final request = jsonDecode(op.requestJson) as Map<String, Object?>;

      expect(event.startTimeZone, 'America/Vancouver');
      expect(event.endTimeZone, 'America/Vancouver');
      expect(request['startTimeZone'], 'America/Vancouver');
      expect(request['endTimeZone'], 'America/Vancouver');
    },
  );

  test(
    'local Google event edit uses app local timezone over UTC event',
    () async {
      await CalendarRepository(database: database).upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: TaskProvider.google,
          providerCalendarId: 'cal-1',
          summary: 'Work',
          timeZone: 'UTC',
        ),
      );
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-event',
        startTimeZone: 'UTC',
        endTimeZone: 'UTC',
      );

      await CalendarRepository(
        database: database,
        localTimeZone: 'America/Vancouver',
      ).updateLocalEvent(
        EventEditorDraft.existing(
          eventId: eventId,
          accountId: 'account',
          sourceId: 'account|google|cal-1',
          providerCalendarId: 'cal-1',
          title: 'Patched',
          allDay: false,
          start: DateTime(2026, 6, 8, 9),
          end: DateTime(2026, 6, 8, 10),
          startTimeZone: 'UTC',
          endTimeZone: 'UTC',
        ),
      );

      final event = await (database.select(
        database.calendarEvents,
      )..where((table) => table.id.equals(eventId))).getSingle();
      final op =
          await (database.select(database.pendingOps)
                ..where((table) => table.operationType.equals('event.patch')))
              .getSingle();
      final request = jsonDecode(op.requestJson) as Map<String, Object?>;

      expect(event.startTimeZone, 'America/Vancouver');
      expect(event.endTimeZone, 'America/Vancouver');
      expect(request['startTimeZone'], 'America/Vancouver');
      expect(request['endTimeZone'], 'America/Vancouver');
    },
  );

  test(
    'existing event identity cannot move between accounts or calendars',
    () async {
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'microsoft-account',
              provider: const Value('microsoft'),
              authState: const Value('signed_in'),
              grantedScopes: const Value(''),
              createdAtUtc: '2026-06-08T00:00:00.000Z',
              updatedAtUtc: '2026-06-08T00:00:00.000Z',
            ),
          );
      await CalendarRepository(database: database).upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: TaskProvider.google,
          providerCalendarId: 'cal-2',
          summary: 'Personal',
          timeZone: 'America/Vancouver',
        ),
      );
      await CalendarRepository(database: database).upsertSource(
        accountId: 'microsoft-account',
        source: const CalendarSourceDto(
          provider: TaskProvider.microsoft,
          providerCalendarId: 'ms-cal-1',
          summary: 'Outlook',
          timeZone: 'America/Vancouver',
        ),
      );
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-event',
      );
      final repository = CalendarRepository(database: database);
      final changedIdentities =
          <({String accountId, String sourceId, String providerCalendarId})>[
            (
              accountId: 'other-account',
              sourceId: 'account|google|cal-1',
              providerCalendarId: 'cal-1',
            ),
            (
              accountId: 'account',
              sourceId: 'account|google|cal-2',
              providerCalendarId: 'cal-1',
            ),
            (
              accountId: 'account',
              sourceId: 'account|google|cal-1',
              providerCalendarId: 'cal-2',
            ),
            (
              accountId: 'account',
              sourceId: 'account|google|cal-2',
              providerCalendarId: 'cal-2',
            ),
            (
              accountId: 'microsoft-account',
              sourceId: 'microsoft-account|microsoft|ms-cal-1',
              providerCalendarId: 'ms-cal-1',
            ),
          ];

      for (final identity in changedIdentities) {
        await expectLater(
          repository.updateLocalEvent(
            EventEditorDraft.existing(
              eventId: eventId,
              accountId: identity.accountId,
              sourceId: identity.sourceId,
              providerCalendarId: identity.providerCalendarId,
              title: 'Moved',
              allDay: false,
              start: DateTime.utc(2026, 6, 8, 9),
              end: DateTime.utc(2026, 6, 8, 10),
            ),
          ),
          throwsA(isA<UnsupportedError>()),
        );

        final event = await (database.select(
          database.calendarEvents,
        )..where((table) => table.id.equals(eventId))).getSingle();
        expect(event.accountId, 'account');
        expect(event.calendarSourceId, 'account|google|cal-1');
        expect(event.providerCalendarId, 'cal-1');
        expect(event.title, 'Base');
        expect(event.syncStatus, 'synced');
        expect(await database.select(database.pendingOps).get(), isEmpty);
      }
    },
  );

  test('recurrence edits cannot target an individual occurrence', () async {
    final eventId = await _insertEvent(
      database,
      providerEventId: 'occurrence-1',
      providerRecurringEventId: 'series-master',
    );
    final draft = EventEditorDraft.existing(
      eventId: eventId,
      providerRecurringEventId: 'series-master',
      accountId: 'account',
      sourceId: 'account|google|cal-1',
      providerCalendarId: 'cal-1',
      title: 'Weekly planning',
      allDay: false,
      start: DateTime.utc(2026, 6, 8, 9),
      end: DateTime.utc(2026, 6, 8, 10),
    ).copyWith(clearRecurrence: true);

    await expectLater(
      CalendarRepository(database: database).updateLocalEvent(draft),
      throwsA(isA<UnsupportedError>()),
    );
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test(
    'blocked Google create with missing time zone is replayed with source zone',
    () async {
      await _enqueueEventOp(
        database,
        id: 'op-1',
        operation: 'create',
        operationType: 'event.create',
        eventId: 'local-event',
        request: {
          'title': 'Planning',
          'allDay': false,
          'start': '2026-06-08T09:00:00.000',
          'end': '2026-06-08T10:00:00.000',
        },
        baselineUpdatedUtc: null,
      );
      await database.pendingOpsDao.updateAttempt(
        id: 'op-1',
        attemptCount: 1,
        nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
        lastErrorCode: 'GoogleCalendarApiError',
        lastErrorMessage: 'Missing time zone definition for start time.',
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      ).replayDueOps();

      expect(applied, 1);
      expect(client.calls, ['createEvent:cal-1:Planning']);
      expect(client.createdMutations.single.startTimeZone, 'America/Vancouver');
      expect(client.createdMutations.single.endTimeZone, 'America/Vancouver');
      expect(
        await database.pendingOpsDao.pendingOpsForReplay('account', _later),
        isEmpty,
      );
    },
  );

  test(
    'calendar op poisoned by task replay is recovered without operation type',
    () async {
      await database.pendingOpsDao.enqueue(
        PendingOpsCompanion.insert(
          id: 'op-poisoned',
          accountId: 'account',
          provider: const Value('google'),
          entityType: 'calendar',
          operation: 'patch',
          calendarSourceId: const Value('account|google|cal-1'),
          providerCalendarId: const Value('cal-1'),
          requestJson: jsonEncode({'summary': 'Renamed'}),
          createdAtUtc: '2026-06-08T00:00:00.000Z',
          updatedAtUtc: '2026-06-08T00:00:00.000Z',
        ),
      );
      await database.pendingOpsDao.updateAttempt(
        id: 'op-poisoned',
        attemptCount: 1,
        nextAttemptAtUtc: DateTime.utc(9999, 12, 31),
        lastErrorCode: 'unknown_operation',
        lastErrorMessage: 'patch',
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      ).replayDueOps();

      expect(applied, 1);
      expect(client.calls, ['updateCalendar:cal-1:Renamed']);
      expect(await database.pendingOpsDao.getOp('op-poisoned'), equals(null));
    },
  );

  test(
    'event patch calls provider updateEvent with provider_event_id',
    () async {
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-event',
      );
      await _enqueueEventOp(
        database,
        id: 'op-1',
        operation: 'patch',
        operationType: 'event.patch',
        eventId: eventId,
        request: {'title': 'Patched'},
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      ).replayDueOps();

      expect(applied, 1);
      expect(client.calls, [
        'getEvent:cal-1:provider-event',
        'updateEvent:cal-1:provider-event:Patched',
      ]);
      expect(client.updatedMutations.single.title, 'Patched');
      expect(client.updatedMutations.single.startTimeZone, 'America/Vancouver');
      expect(client.updatedMutations.single.endTimeZone, 'America/Vancouver');
      expect(
        await database.pendingOpsDao.pendingOpsForReplay('account', _later),
        isEmpty,
      );
    },
  );

  test(
    'back-to-back local event patches replay in order without self-conflict',
    () async {
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-event',
      );
      client
        ..persistEventUpdates = true
        ..remoteEvent = client._event('provider-event', title: 'Base');
      final repository = CalendarRepository(
        database: database,
        now: () => DateTime.utc(2026, 6, 8),
      );

      for (final title in ['First local title', 'Second local title']) {
        await repository.updateLocalEvent(
          EventEditorDraft.existing(
            eventId: eventId,
            accountId: 'account',
            sourceId: 'account|google|cal-1',
            providerCalendarId: 'cal-1',
            title: title,
            allDay: false,
            start: DateTime.utc(2026, 6, 8, 9),
            end: DateTime.utc(2026, 6, 8, 10),
          ),
        );
      }

      final queued = await database.pendingOpsDao.pendingOpsForReplay(
        'account',
        _later,
      );
      expect(queued, hasLength(2));
      expect(queued.first.dependsOnOpId, equals(null));
      expect(queued.last.dependsOnOpId, queued.first.id);
      expect(
        queued.map((op) => op.baselineUpdatedUtc),
        everyElement('2026-06-08T00:00:00.000Z'),
      );
      expect(
        queued.map((op) => op.baselineRawJson),
        everyElement(
          '{"id":"provider-event","summary":"Base",'
          '"updated":"2026-06-08T00:00:00.000Z"}',
        ),
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 9),
      ).replayDueOps();

      expect(applied, 2);
      expect(client.updatedMutations.map((mutation) => mutation.title), [
        'First local title',
        'Second local title',
      ]);
      expect(client.remoteEvent!.title, 'Second local title');
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final local = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(local.title, 'Second local title');
      expect(local.syncStatus, 'synced');
    },
  );

  test(
    'earlier local event patch does not hide a later-field remote conflict',
    () async {
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-event',
      );
      client
        ..persistEventUpdates = true
        ..remoteEvent = client._event(
          'provider-event',
          title: 'Base',
          location: 'Remote room',
          updatedAtServer: '2026-06-08T00:05:00.000Z',
        );
      await _enqueueEventOp(
        database,
        id: 'op-1',
        operation: 'patch',
        operationType: 'event.patch',
        eventId: eventId,
        request: {'title': 'Local title'},
        baselineRawJson:
            '{"id":"provider-event","summary":"Base",'
            '"location":"Base room",'
            '"updated":"2026-06-08T00:00:00.000Z"}',
      );
      await _enqueueEventOp(
        database,
        id: 'op-2',
        operation: 'patch',
        operationType: 'event.patch',
        eventId: eventId,
        request: {'location': 'Local room'},
        dependsOnOpId: 'op-1',
        baselineRawJson:
            '{"id":"provider-event","summary":"Base",'
            '"location":"Base room",'
            '"updated":"2026-06-08T00:00:00.000Z"}',
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 9),
      ).replayDueOps();

      expect(applied, 1);
      expect(client.updatedMutations.map((mutation) => mutation.title), [
        'Local title',
      ]);
      expect(client.remoteEvent!.title, 'Local title');
      expect(client.remoteEvent!.location, 'Remote room');
      final op = await database.pendingOpsDao.getOp('op-2');
      expect(op!.lastErrorCode, 'conflict');
      expect(op.lastErrorMessage, contains('location'));
    },
  );

  test('event delete pending op calls provider deleteEvent', () async {
    final eventId = await _insertEvent(
      database,
      providerEventId: 'provider-event',
    );
    await _enqueueEventOp(
      database,
      id: 'op-1',
      operation: 'delete',
      operationType: 'event.delete',
      eventId: eventId,
      request: const {},
    );

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    final row = await (database.select(
      database.calendarEvents,
    )..where((table) => table.id.equals(eventId))).getSingle();
    expect(applied, 1);
    expect(client.calls, [
      'getEvent:cal-1:provider-event',
      'deleteEvent:cal-1:provider-event',
    ]);
    expect(row.isDeleted, isTrue);
  });

  test('provider missing delete is treated as success', () async {
    client.deleteError = const GoogleCalendarApiError(
      statusCode: 404,
      code: 'NOT_FOUND',
      message: 'Missing',
    );
    final eventId = await _insertEvent(
      database,
      providerEventId: 'provider-event',
    );
    await _enqueueEventOp(
      database,
      id: 'op-1',
      operation: 'delete',
      operationType: 'event.delete',
      eventId: eventId,
      request: const {},
      baselineUpdatedUtc: null,
    );

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    expect(applied, 1);
    expect(
      await database.pendingOpsDao.pendingOpsForReplay('account', _later),
      isEmpty,
    );
  });

  test('local event delete returns account id for immediate sync', () async {
    final eventId = await _insertEvent(
      database,
      providerEventId: 'provider-event',
    );

    final accountId = await CalendarRepository(
      database: database,
    ).deleteLocalEvent(eventId);

    expect(accountId, 'account');
    final pending = await database.pendingOpsDao.pendingOpsForReplay(
      'account',
      _later,
    );
    expect(pending.single.operationType, 'event.delete');
  });

  test('calendar patch pending op calls provider updateCalendar', () async {
    await database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: 'op-calendar-patch',
        accountId: 'account',
        provider: const Value('google'),
        entityType: 'calendar',
        operation: 'patch',
        operationType: const Value('calendar.patch'),
        calendarSourceId: const Value('account|google|cal-1'),
        providerCalendarId: const Value('cal-1'),
        requestJson: '{"summary":"Renamed"}',
        createdAtUtc: '2026-06-08T00:00:00.000Z',
        updatedAtUtc: '2026-06-08T00:00:00.000Z',
      ),
    );

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    expect(applied, 1);
    expect(client.calls, ['updateCalendar:cal-1:Renamed']);
    expect(
      await database.pendingOpsDao.pendingOpsForReplay('account', _later),
      isEmpty,
    );
  });

  test('calendar delete pending op calls provider deleteCalendar', () async {
    await database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: 'op-calendar-delete',
        accountId: 'account',
        provider: const Value('google'),
        entityType: 'calendar',
        operation: 'delete',
        operationType: const Value('calendar.delete'),
        calendarSourceId: const Value('account|google|cal-1'),
        providerCalendarId: const Value('cal-1'),
        requestJson: '{}',
        createdAtUtc: '2026-06-08T00:00:00.000Z',
        updatedAtUtc: '2026-06-08T00:00:00.000Z',
      ),
    );

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    final source = await (database.select(
      database.calendarSources,
    )..where((table) => table.id.equals('account|google|cal-1'))).getSingle();
    expect(applied, 1);
    expect(client.calls, ['deleteCalendar:cal-1']);
    expect(source.isDeleted, isTrue);
  });

  test('sync engine replays pending event ops before pull sync', () async {
    await CalendarRepository(database: database).createLocalEvent(
      EventEditorDraft.newEvent(
        accountId: 'account',
        sourceId: 'account|google|cal-1',
        providerCalendarId: 'cal-1',
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
      ).copyWith(title: 'Planning'),
    );

    await CalendarSyncEngine(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).fullSync();

    expect(client.calls.take(2), [
      'createEvent:cal-1:Planning',
      'listCalendars',
    ]);
  });

  test(
    'transient patch failure does not let pull overwrite the pending edit',
    () async {
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-event',
      );
      await CalendarRepository(database: database).updateLocalEvent(
        EventEditorDraft.existing(
          eventId: eventId,
          accountId: 'account',
          sourceId: 'account|google|cal-1',
          providerCalendarId: 'cal-1',
          title: 'Optimistic planning',
          allDay: false,
          start: DateTime.utc(2026, 6, 8, 9),
          end: DateTime.utc(2026, 6, 8, 10),
          location: 'Local room',
        ),
      );
      final pendingId =
          (await database.select(database.pendingOps).getSingle()).id;
      final optimisticBeforeSync = await (database.select(
        database.calendarEvents,
      )..where((table) => table.id.equals(eventId))).getSingle();
      client.transientUpdateFailures = 1;
      client.syncEvent = client._event(
        'provider-event',
        title: 'Stale provider title',
        location: 'Remote room',
        etagOrChangeKey: 'remote-etag',
        updatedAtServer: '2026-06-08T01:00:00.000Z',
      );

      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      ).fullSync();

      final pendingAfterFailure = await database.pendingOpsDao.getOp(pendingId);
      final localAfterPull = await (database.select(
        database.calendarEvents,
      )..where((table) => table.id.equals(eventId))).getSingle();
      expect(client.calls, contains('syncEvents:cal-1'));
      expect(pendingAfterFailure, isNot(equals(null)));
      expect(pendingAfterFailure!.attemptCount, 1);
      expect(pendingAfterFailure.nextAttemptAtUtc, isNot(equals(null)));
      expect(localAfterPull.title, 'Optimistic planning');
      expect(localAfterPull.location, 'Local room');
      expect(localAfterPull.syncStatus, 'pending');
      expect(localAfterPull.rawJson, optimisticBeforeSync.rawJson);
      expect(
        localAfterPull.baselineRawJson,
        optimisticBeforeSync.baselineRawJson,
      );
      expect(
        localAfterPull.updatedAtServer,
        optimisticBeforeSync.updatedAtServer,
      );
      expect(localAfterPull.etagOrChangeKey, equals(null));
      expect(
        localAfterPull.updatedAtLocal,
        optimisticBeforeSync.updatedAtLocal,
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 9),
      ).replayDueOps();

      final localAfterRetry = await (database.select(
        database.calendarEvents,
      )..where((table) => table.id.equals(eventId))).getSingle();
      expect(applied, 1);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(localAfterRetry.title, 'Optimistic planning');
      expect(localAfterRetry.location, 'Local room');
      expect(localAfterRetry.syncStatus, 'synced');
    },
  );

  test('full refresh marks missing synced event deleted', () async {
    final eventId = await _insertEvent(
      database,
      providerEventId: 'provider-event',
    );
    var schedulerCalls = 0;

    await CalendarSyncEngine(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
      onNotificationScheduleChanged: () async => schedulerCalls += 1,
    ).fullSync();

    final row = await (database.select(
      database.calendarEvents,
    )..where((table) => table.id.equals(eventId))).getSingle();
    expect(row.isDeleted, isTrue);
    expect(schedulerCalls, 1);
  });

  test('full refresh does not remove pending local dirty event', () async {
    final eventId = await _insertEvent(
      database,
      providerEventId: 'provider-event',
    );
    await (database.update(database.calendarEvents)
          ..where((table) => table.id.equals(eventId)))
        .write(const CalendarEventsCompanion(syncStatus: Value('pending')));

    await CalendarSyncEngine(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).fullSync();

    final row = await (database.select(
      database.calendarEvents,
    )..where((table) => table.id.equals(eventId))).getSingle();
    expect(row.isDeleted, isFalse);
  });

  test('unknown calendar operation is blocked, not retried forever', () async {
    await database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: 'op-unknown',
        accountId: 'account',
        provider: const Value('google'),
        entityType: 'calendar',
        operation: 'frob',
        operationType: const Value('calendar.frob'),
        requestJson: '{}',
        createdAtUtc: '2026-06-08T00:00:00.000Z',
        updatedAtUtc: '2026-06-08T00:00:00.000Z',
      ),
    );

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    final op = await database.pendingOpsDao.getOp('op-unknown');
    expect(applied, 0);
    expect(op!.nextAttemptAtUtc, startsWith('9999-12-31'));
    expect(op.lastErrorCode, 'unknown_calendar_operation');
  });
}

Future<void> _insertAccount(AppDatabase database) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: const Value('google'),
          authState: const Value('signed_in'),
          grantedScopes: const Value(''),
          createdAtUtc: '2026-06-08T00:00:00.000Z',
          updatedAtUtc: '2026-06-08T00:00:00.000Z',
        ),
      );
}

Future<String> _insertEvent(
  AppDatabase database, {
  required String providerEventId,
  String? providerRecurringEventId,
  String? startTimeZone,
  String? endTimeZone,
}) async {
  final event = CalendarEventDto(
    provider: TaskProvider.google,
    providerCalendarId: 'cal-1',
    providerEventId: providerEventId,
    providerRecurringEventId: providerRecurringEventId,
    title: 'Base',
    startDateTime: '2026-06-08T09:00:00.000Z',
    startTimeZone: startTimeZone,
    endDateTime: '2026-06-08T10:00:00.000Z',
    endTimeZone: endTimeZone,
    updatedAtServer: '2026-06-08T00:00:00.000Z',
    rawJson: {
      'id': providerEventId,
      'summary': 'Base',
      'updated': '2026-06-08T00:00:00.000Z',
    },
  );
  await CalendarRepository(
    database: database,
  ).upsertEvent(accountId: 'account', event: event);
  return CalendarRepository.eventId(
    accountId: 'account',
    provider: TaskProvider.google,
    providerCalendarId: 'cal-1',
    providerEventId: providerEventId,
  );
}

Future<void> _enqueueEventOp(
  AppDatabase database, {
  required String id,
  required String operation,
  required String operationType,
  required String eventId,
  required Map<String, Object?> request,
  String? dependsOnOpId,
  String? baselineUpdatedUtc = '2026-06-08T00:00:00.000Z',
  String baselineRawJson =
      '{"id":"provider-event","summary":"Base",'
      '"updated":"2026-06-08T00:00:00.000Z"}',
}) {
  return database.pendingOpsDao.enqueue(
    PendingOpsCompanion.insert(
      id: id,
      accountId: 'account',
      provider: const Value('google'),
      entityType: 'event',
      operation: operation,
      operationType: Value(operationType),
      calendarSourceId: const Value('account|google|cal-1'),
      providerCalendarId: const Value('cal-1'),
      eventId: Value(eventId),
      dependsOnOpId: Value(dependsOnOpId),
      requestJson: jsonEncode(request),
      baselineUpdatedUtc: Value(baselineUpdatedUtc),
      baselineRawJson: Value(baselineRawJson),
      createdAtUtc: '2026-06-08T00:00:00.000Z',
      updatedAtUtc: '2026-06-08T00:00:00.000Z',
    ),
  );
}

final _later = DateTime.utc(2026, 6, 9);

class _FakeCalendarClient implements CloudCalendarClient {
  final calls = <String>[];
  final createdMutations = <CalendarEventMutation>[];
  final updatedMutations = <CalendarEventMutation>[];
  int _createdCount = 0;
  int transientUpdateFailures = 0;
  CalendarEventDto? syncEvent;
  CalendarEventDto? remoteEvent;
  bool persistEventUpdates = false;
  int _eventUpdateRevision = 0;
  GoogleCalendarApiError? deleteError;

  @override
  BusyProvider get provider => TaskProvider.google;

  @override
  CalendarProviderCapabilities get capabilities =>
      googleCalendarProviderCapabilities;

  @override
  Future<List<CalendarSourceDto>> listCalendars() async {
    calls.add('listCalendars');
    return const [
      CalendarSourceDto(
        provider: TaskProvider.google,
        providerCalendarId: 'cal-1',
        summary: 'Work',
      ),
    ];
  }

  @override
  Future<CalendarEventDto> createEvent({
    required String calendarId,
    required CalendarEventMutation mutation,
  }) async {
    calls.add('createEvent:$calendarId:${mutation.title}');
    createdMutations.add(mutation);
    _createdCount += 1;
    return _event(
      'server-event-$_createdCount',
      title: mutation.title ?? '',
      startTimeZone: mutation.startTimeZone,
      endTimeZone: mutation.endTimeZone,
    );
  }

  @override
  Future<CalendarEventDto> updateEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
  }) async {
    calls.add('updateEvent:$calendarId:$eventId:${mutation.title}');
    updatedMutations.add(mutation);
    if (transientUpdateFailures > 0) {
      transientUpdateFailures -= 1;
      throw const GoogleCalendarApiError(
        statusCode: 500,
        code: 'backendError',
        message: 'Temporary provider failure',
      );
    }
    final current = remoteEvent;
    final event = _event(
      eventId,
      title: persistEventUpdates
          ? mutation.title ?? current?.title ?? ''
          : mutation.title ?? '',
      location: persistEventUpdates
          ? mutation.location ?? current?.location
          : mutation.location,
      updatedAtServer: persistEventUpdates
          ? DateTime.utc(
              2026,
              6,
              8,
              0,
              ++_eventUpdateRevision + 5,
            ).toIso8601String()
          : '2026-06-08T00:00:00.000Z',
      startTimeZone: mutation.startTimeZone,
      endTimeZone: mutation.endTimeZone,
    );
    if (persistEventUpdates) {
      remoteEvent = event;
    }
    return event;
  }

  @override
  Future<CalendarEventDto> getEvent({
    required String calendarId,
    required String eventId,
  }) async {
    calls.add('getEvent:$calendarId:$eventId');
    return remoteEvent ?? _event(eventId, title: 'Base');
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async {
    calls.add('deleteEvent:$calendarId:$eventId');
    final error = deleteError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<CalendarSyncPageDto> syncEvents({
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? syncTokenOrDeltaLink,
    bool primaryCalendar = false,
  }) async {
    calls.add('syncEvents:$calendarId');
    return CalendarSyncPageDto(
      events: [
        if (syncEvent case final event?) event,
        if (_createdCount > 0)
          _event('server-event-$_createdCount', title: 'Planning'),
      ],
    );
  }

  CalendarEventDto _event(
    String id, {
    required String title,
    String? location,
    String? etagOrChangeKey,
    String updatedAtServer = '2026-06-08T00:00:00.000Z',
    String? startTimeZone,
    String? endTimeZone,
  }) {
    return CalendarEventDto(
      provider: TaskProvider.google,
      providerCalendarId: 'cal-1',
      providerEventId: id,
      etagOrChangeKey: etagOrChangeKey,
      title: title,
      location: location,
      startDateTime: '2026-06-08T09:00:00.000Z',
      startTimeZone: startTimeZone,
      endDateTime: '2026-06-08T10:00:00.000Z',
      endTimeZone: endTimeZone,
      updatedAtServer: updatedAtServer,
      rawJson: {
        'id': id,
        'summary': title,
        if (location != null) 'location': location,
        if (etagOrChangeKey != null) 'etag': etagOrChangeKey,
        'updated': updatedAtServer,
      },
    );
  }

  @override
  Future<CalendarSourceDto> createCalendar(CalendarMutation mutation) async {
    calls.add('createCalendar:${mutation.summary}');
    return CalendarSourceDto(
      provider: TaskProvider.google,
      providerCalendarId: 'cal-created',
      summary: mutation.summary ?? 'Calendar',
    );
  }

  @override
  Future<void> deleteCalendar(String calendarId) async {
    calls.add('deleteCalendar:$calendarId');
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
  ) async {
    calls.add('updateCalendar:$calendarId:${mutation.summary}');
    return CalendarSourceDto(
      provider: TaskProvider.google,
      providerCalendarId: calendarId,
      summary: mutation.summary ?? 'Calendar',
    );
  }
}
