import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/calendar_providers/calendar_colors.dart';
import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/schedule/schedule_sidebar_order.dart';
import 'package:busymax/src/calendar_providers/calendar_create_identity.dart';
import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/calendar_providers/calendar_provider_capabilities.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/calendar/domain/event_timing_policy.dart';
import 'package:busymax/src/features/sync/calendar_pending_ops_replayer.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:busymax/src/features/maps/data/location_resolution_repository.dart';
import 'package:busymax/src/features/maps/application/location_destination_resolver.dart';
import 'package:busymax/src/google_calendar/google_calendar_errors.dart';
import 'package:busymax/src/ical/ical_import_service.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_errors.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';
import '../../support/process_time_zone.dart';

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
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        summary: 'Work',
        timeZone: 'America/Vancouver',
        dataOwner: 'me@example.com',
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'guarded timing edit replays exact endpoints and guest policy without moving ownership',
    () async {
      final repository = CalendarRepository(database: database);
      final id = await _insertEvent(
        database,
        providerEventId: 'drag-event',
        startTimeZone: 'UTC',
        endTimeZone: 'UTC',
      );
      final detail = (await repository.loadEventDetail(id))!;
      client.remoteEvent = client._event(
        'drag-event',
        title: 'Base',
        organizerJson: const {'self': true},
      );
      client.persistEventUpdates = true;
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(
          start: DateTime.utc(2026, 6, 8, 14, 15),
          end: DateTime.utc(2026, 6, 8, 15, 45),
        ),
        timingBaseline: EventTimingBaseline.fromDetail(detail),
        guestUpdatePolicy: CalendarGuestUpdatePolicy.doNotSend,
      );
      final replay = CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 9),
      );
      expect(await replay.replayDueOps(), 1);
      expect(await replay.replayDueOps(), 0);
      final mutation = client.updatedMutations.single;
      expect(
        DateTime.parse(mutation.startDateTime!),
        DateTime.utc(2026, 6, 8, 14, 15),
      );
      expect(
        DateTime.parse(mutation.endDateTime!),
        DateTime.utc(2026, 6, 8, 15, 45),
      );
      expect(mutation.title, equals(null));
      expect(client.guestUpdatePolicies, [CalendarGuestUpdatePolicy.doNotSend]);
      final saved = (await repository.loadEventDetail(id))!;
      expect(saved.startDateTime, client.remoteEvent!.startDateTime);
      expect(saved.endDateTime, client.remoteEvent!.endDateTime);
      expect(saved.sourceId, detail.sourceId);
      expect(saved.accountId, detail.accountId);
      expect(saved.providerCalendarId, detail.providerCalendarId);
      expect(saved.title, 'Base');
    },
  );

  for (final throughEngine in [false, true]) {
    for (final failSettings in [false, true]) {
      test(
        'calendar ID callback follows commit (engine=$throughEngine, failure=$failSettings)',
        () async {
          final settings = AppSettingsController(MemorySettingsStore());
          addTearDown(settings.dispose);
          final temporaryId = await CalendarRepository(
            database: database,
            now: () => DateTime.utc(2026, 6, 8),
          ).createLocalSource(accountId: 'account', summary: 'Project');
          const serverId = 'account|google|cal-created';
          await settings.registerSidebarIds(SidebarOrderSection.calendars, [
            'before',
            temporaryId,
            'after',
            serverId,
          ], accountId: 'account');
          var callbackCount = 0;
          var committed = false;
          Future<void> replaced(String oldId, String newId) async {
            callbackCount++;
            final ids = (await database.select(database.calendarSources).get())
                .map((source) => source.id);
            committed =
                oldId == temporaryId &&
                newId == serverId &&
                !ids.contains(oldId) &&
                ids.contains(newId);
            await settings.replaceSidebarId(
              SidebarOrderSection.calendars,
              oldId,
              newId,
              accountId: 'account',
            );
            if (failSettings) throw StateError('settings unavailable');
          }

          final replayer = CalendarPendingOpsReplayer(
            database: database,
            client: client,
            accountId: 'account',
            onCalendarSourceIdReplaced: replaced,
            nowUtc: () => DateTime.utc(2026, 6, 8),
          );
          if (throughEngine) {
            await CalendarSyncEngine(
              database: database,
              client: client,
              accountId: 'account',
              onCalendarSourceIdReplaced: replaced,
              nowUtc: () => DateTime.utc(2026, 6, 8),
            ).fullSync();
          } else {
            expect(await replayer.replayDueOps(), 1);
          }
          expect(committed, isTrue);
          expect(callbackCount, 1);
          expect(
            settings.state.sidebarOrder.calendarSourceIdsByAccount['account'],
            ['before', serverId, 'after'],
          );
          expect(await replayer.replayDueOps(), 0);
          expect(
            client.calls.where((call) => call.startsWith('createCalendar:')),
            ['createCalendar:Project'],
          );
        },
      );
    }
  }

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
      expect(
        rows.single.providerEventId,
        client.createdMutations.single.providerEventId,
      );
      expect(rows.single.startTimeZone, 'America/Vancouver');
      expect(rows.single.endTimeZone, 'America/Vancouver');
      expect(client.createdMutations.single.startTimeZone, 'America/Vancouver');
      expect(client.createdMutations.single.endTimeZone, 'America/Vancouver');
      expect(client.guestUpdatePolicies.single, CalendarGuestUpdatePolicy.send);
    },
  );

  test('concurrent replayers dispatch a queued event create once', () async {
    await CalendarRepository(database: database).createLocalEvent(
      EventEditorDraft.newEvent(
        accountId: 'account',
        sourceId: 'account|google|cal-1',
        providerCalendarId: 'cal-1',
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
      ).copyWith(title: 'Planning'),
    );
    final createGate = Completer<void>();
    client.createEventGate = createGate;

    CalendarPendingOpsReplayer replayer() => CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    );

    final first = replayer().replayDueOps();
    await _waitFor(() => client.calls.length == 1);
    final second = replayer().replayDueOps();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(client.calls, ['createEvent:cal-1:Planning']);

    createGate.complete();
    expect(await first, 1);
    expect(await second, 0);
    expect(client.calls, ['createEvent:cal-1:Planning']);
  });

  test('Google create retry reuses its ID and reconciles a 409', () async {
    final repository = CalendarRepository(database: database);
    final operationId = await repository.createLocalEvent(
      EventEditorDraft.newEvent(
        accountId: 'account',
        sourceId: 'account|google|cal-1',
        providerCalendarId: 'cal-1',
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
      ).copyWith(title: 'Planning'),
    );
    final expectedEventId = googleCalendarCreateEventId(operationId);
    final queued = await database.pendingOpsDao.getOp(operationId);
    expect(
      jsonDecode(queued!.requestJson),
      containsPair(calendarEventGoogleCreateIdKey, expectedEventId),
    );
    client.createEventResponseError = StateError('response lost');

    final firstApplied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();
    final secondApplied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 9),
    ).replayDueOps();

    expect(firstApplied, 0);
    expect(secondApplied, 1);
    expect(
      client.createdMutations.map((mutation) => mutation.providerEventId),
      [expectedEventId, expectedEventId],
    );
    expect(client.distinctCreatedEventCount, 1);
    expect(client.calls, [
      'createEvent:cal-1:Planning',
      'createEvent:cal-1:Planning',
      'getEvent:cal-1:$expectedEventId',
    ]);
    final local = await database.select(database.calendarEvents).getSingle();
    expect(local.providerEventId, expectedEventId);
    expect(await database.pendingOpsDao.getOp(operationId), equals(null));
  });

  test('Microsoft create retry reuses its transaction ID', () async {
    final repository = CalendarRepository(database: database);
    await repository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'cal-ms',
        summary: 'Microsoft calendar',
      ),
    );
    final operationId = await repository.createLocalEvent(
      EventEditorDraft.newEvent(
        accountId: 'account',
        sourceId: 'account|microsoft|cal-ms',
        providerCalendarId: 'cal-ms',
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
      ).copyWith(title: 'Planning'),
    );
    final expectedTransactionId = microsoftCalendarCreateTransactionId(
      operationId,
    );
    final queued = await database.pendingOpsDao.getOp(operationId);
    expect(
      jsonDecode(queued!.requestJson),
      containsPair(
        calendarEventMicrosoftTransactionIdKey,
        expectedTransactionId,
      ),
    );
    final microsoftClient = _FakeMicrosoftCalendarClient()
      ..createEventResponseError = StateError('response lost');

    final firstApplied = await CalendarPendingOpsReplayer(
      database: database,
      client: microsoftClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();
    final secondApplied = await CalendarPendingOpsReplayer(
      database: database,
      client: microsoftClient,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 9),
    ).replayDueOps();

    expect(firstApplied, 0);
    expect(secondApplied, 1);
    expect(
      microsoftClient.createdMutations.map(
        (mutation) => mutation.transactionId,
      ),
      [expectedTransactionId, expectedTransactionId],
    );
    expect(microsoftClient.distinctCreatedEventCount, 1);
    expect(microsoftClient.calls, [
      'createEvent:cal-ms:Planning',
      'createEvent:cal-ms:Planning',
    ]);
    final local = await (database.select(
      database.calendarEvents,
    )..where((row) => row.provider.equals('microsoft'))).getSingle();
    expect(local.providerEventId, 'server-event-1');
    expect(await database.pendingOpsDao.getOp(operationId), equals(null));
  });

  test('event replay preserves a do-not-send guest update choice', () async {
    await CalendarRepository(database: database).createLocalEvent(
      EventEditorDraft.newEvent(
        accountId: 'account',
        sourceId: 'account|google|cal-1',
        providerCalendarId: 'cal-1',
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
      ).copyWith(title: 'Private draft'),
      guestUpdatePolicy: CalendarGuestUpdatePolicy.doNotSend,
    );

    await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    expect(client.guestUpdatePolicies, [CalendarGuestUpdatePolicy.doNotSend]);
  });

  test(
    'invitation response pending op calls the dedicated provider action',
    () async {
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-event',
      );
      await _enqueueEventOp(
        database,
        id: 'respond-op',
        operation: 'respond',
        operationType: 'event.respond',
        eventId: eventId,
        request: const {
          'response': 'tentative',
          'attendeeEmail': 'me@example.com',
          'sendResponse': true,
        },
        baselineUpdatedUtc: null,
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      ).replayDueOps();

      expect(applied, 1);
      expect(client.invitationResponses, [
        CalendarInvitationResponse.tentative,
      ]);
      expect(
        client.calls,
        contains('respondToEvent:cal-1:provider-event:me@example.com'),
      );
    },
  );

  test(
    'local Google event create uses app local timezone over UTC source',
    () async {
      await CalendarRepository(database: database).upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: BusyProvider.google,
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
    'title-only Google edit preserves the explicit UTC representation',
    () async {
      await CalendarRepository(database: database).upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: BusyProvider.google,
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

      final repository = CalendarRepository(
        database: database,
        localTimeZone: 'America/Vancouver',
      );
      final detail = await repository.loadEventDetail(eventId);
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail!).copyWith(title: 'Patched'),
      );

      final event = await (database.select(
        database.calendarEvents,
      )..where((table) => table.id.equals(eventId))).getSingle();
      final op =
          await (database.select(database.pendingOps)
                ..where((table) => table.operationType.equals('event.patch')))
              .getSingle();
      final request = jsonDecode(op.requestJson) as Map<String, Object?>;

      expect(event.startDateTime, '2026-06-08T09:00:00.000Z');
      expect(event.endDateTime, '2026-06-08T10:00:00.000Z');
      expect(event.startTimeZone, 'UTC');
      expect(event.endTimeZone, 'UTC');
      expect(request, {
        'title': 'Patched',
        calendarEventGuestUpdatePolicyKey: 'send',
      });
    },
  );

  test('same-account Google move uses the native provider operation', () async {
    final repository = CalendarRepository(database: database);
    await repository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-2',
        summary: 'Personal',
        timeZone: 'America/Vancouver',
      ),
    );
    final eventId = await _insertEvent(
      database,
      providerEventId: 'provider-event',
      startTimeZone: 'UTC',
      endTimeZone: 'UTC',
    );

    await repository.updateLocalEvent(
      EventEditorDraft.existing(
        eventId: eventId,
        accountId: 'account',
        sourceId: 'account|google|cal-2',
        providerCalendarId: 'cal-2',
        title: 'Moved',
        allDay: false,
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
        startTimeZone: 'UTC',
        endTimeZone: 'UTC',
      ),
      guestUpdatePolicy: CalendarGuestUpdatePolicy.doNotSend,
    );

    final queued = await (database.select(
      database.pendingOps,
    )..orderBy([(row) => OrderingTerm.asc(row.createdAtUtc)])).get();
    expect(queued.map((op) => op.operationType), ['event.move', 'event.patch']);
    expect(queued.last.dependsOnOpId, queued.first.id);

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    expect(applied, 2);
    expect(client.calls, [
      'getEvent:cal-1:provider-event',
      'moveEvent:cal-1:provider-event:cal-2',
      'updateEvent:cal-2:provider-event:Moved',
    ]);
    expect(
      client.guestUpdatePolicies,
      everyElement(CalendarGuestUpdatePolicy.doNotSend),
    );
    final event = await database.select(database.calendarEvents).getSingle();
    expect(event.providerCalendarId, 'cal-2');
    expect(event.calendarSourceId, 'account|google|cal-2');
    expect(event.title, 'Moved');
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test('calendar-only Google move does not rewrite event fields', () async {
    final repository = CalendarRepository(database: database);
    await repository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-2',
        summary: 'Personal',
        timeZone: 'America/Vancouver',
      ),
    );
    final eventId = await _insertEvent(
      database,
      providerEventId: 'provider-event',
      startTimeZone: 'UTC',
      endTimeZone: 'UTC',
    );

    await repository.updateLocalEvent(
      EventEditorDraft.existing(
        eventId: eventId,
        accountId: 'account',
        sourceId: 'account|google|cal-2',
        providerCalendarId: 'cal-2',
        title: 'Base',
        allDay: false,
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
        startTimeZone: 'UTC',
        endTimeZone: 'UTC',
      ),
    );

    final queued = await database.select(database.pendingOps).get();
    expect(queued, hasLength(1));
    expect(queued.single.operationType, 'event.move');

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    expect(applied, 1);
    expect(client.calls, [
      'getEvent:cal-1:provider-event',
      'moveEvent:cal-1:provider-event:cal-2',
    ]);
  });

  test('native Google move rejects a pending-created destination', () async {
    final repository = CalendarRepository(database: database);
    final destinationId = await repository.createLocalSource(
      accountId: 'account',
      summary: 'Pending destination',
    );
    final destination = await (database.select(
      database.calendarSources,
    )..where((row) => row.id.equals(destinationId))).getSingle();
    final eventId = await _insertEvent(
      database,
      providerEventId: 'provider-event',
    );

    await expectLater(
      repository.updateLocalEvent(
        EventEditorDraft.existing(
          eventId: eventId,
          accountId: 'account',
          sourceId: destination.id,
          providerCalendarId: destination.providerCalendarId,
          title: 'Moved',
          allDay: false,
          start: DateTime.utc(2026, 6, 8, 9),
          end: DateTime.utc(2026, 6, 8, 10),
        ),
      ),
      throwsA(
        isA<CalendarMutationNotAllowed>()
            .having(
              (error) => error.operation,
              'operation',
              CalendarMutationOperation.moveEvent,
            )
            .having(
              (error) => error.reason,
              'reason',
              CalendarMutationDenialReason.destinationPendingCreate,
            ),
      ),
    );

    final operations = await database.select(database.pendingOps).get();
    expect(operations, hasLength(1));
    expect(operations.single.operationType, 'calendar.create');
    expect(
      (await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle()).syncStatus,
      'synced',
    );

    await repository.deleteLocalSource(destinationId);

    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(
      await (database.select(
        database.calendarSources,
      )..where((row) => row.id.equals(destinationId))).getSingleOrNull(),
      equals(null),
    );
    expect(
      (await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle()).syncStatus,
      'synced',
    );
  });

  test(
    'same-account copy move rejects a pending-created destination',
    () async {
      final repository = CalendarRepository(database: database);
      final destinationId = await repository.createLocalSource(
        accountId: 'account',
        summary: 'Pending destination',
      );
      final destination = await (database.select(
        database.calendarSources,
      )..where((row) => row.id.equals(destinationId))).getSingle();
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-occurrence',
        providerRecurringEventId: 'provider-series',
      );

      await expectLater(
        repository.updateLocalEvent(
          EventEditorDraft.existing(
            eventId: eventId,
            providerRecurringEventId: 'provider-series',
            recurringMutationScope:
                RecurringEventMutationScope.singleOccurrence,
            accountId: 'account',
            sourceId: destination.id,
            providerCalendarId: destination.providerCalendarId,
            title: 'Copied occurrence',
            allDay: false,
            start: DateTime.utc(2026, 6, 8, 9),
            end: DateTime.utc(2026, 6, 8, 10),
          ),
        ),
        throwsA(
          isA<CalendarMutationNotAllowed>().having(
            (error) => error.reason,
            'reason',
            CalendarMutationDenialReason.destinationPendingCreate,
          ),
        ),
      );

      final createOperation = await database
          .select(database.pendingOps)
          .getSingle();
      await repository.discardPendingCalendarCreation(createOperation);

      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(
        await (database.select(
          database.calendarSources,
        )..where((row) => row.id.equals(destinationId))).getSingleOrNull(),
        equals(null),
      );
      final original = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(original.syncStatus, 'synced');
      expect(original.isDeleted, isFalse);
    },
  );

  test(
    'cross-account copy move rejects a pending-created destination',
    () async {
      await _insertDestinationGoogleAccount(database);
      final repository = CalendarRepository(database: database);
      final destinationId = await repository.createLocalSource(
        accountId: 'destination-account',
        summary: 'Pending destination',
      );
      final destination = await (database.select(
        database.calendarSources,
      )..where((row) => row.id.equals(destinationId))).getSingle();
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-event',
      );

      await expectLater(
        repository.updateLocalEvent(
          EventEditorDraft.existing(
            eventId: eventId,
            accountId: 'destination-account',
            sourceId: destination.id,
            providerCalendarId: destination.providerCalendarId,
            title: 'Cross-account copy',
            allDay: false,
            start: DateTime.utc(2026, 6, 8, 9),
            end: DateTime.utc(2026, 6, 8, 10),
          ),
        ),
        throwsA(
          isA<CalendarMutationNotAllowed>().having(
            (error) => error.reason,
            'reason',
            CalendarMutationDenialReason.destinationPendingCreate,
          ),
        ),
      );

      final operations = await database.select(database.pendingOps).get();
      expect(operations, hasLength(1));
      expect(operations.single.operationType, 'calendar.create');
      expect(operations.single.accountId, 'destination-account');
      final original = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(original.syncStatus, 'synced');
      expect(original.isDeleted, isFalse);
    },
  );

  test('native Google series move removes stale source occurrences', () async {
    final repository = CalendarRepository(database: database);
    await repository.upsertSource(
      accountId: 'account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-2',
        summary: 'Personal',
        timeZone: 'UTC',
      ),
    );
    await repository.upsertEvent(
      accountId: 'account',
      event: _googleSeriesMaster(),
    );
    final occurrenceId = await _insertGoogleOccurrence(repository, day: 8);
    await _insertGoogleOccurrence(repository, day: 15);
    client.remoteEvent = _googleSeriesMaster();

    await repository.updateLocalEvent(
      EventEditorDraft.existing(
        eventId: occurrenceId,
        providerRecurringEventId: 'series-master',
        recurringMutationScope: RecurringEventMutationScope.entireSeries,
        accountId: 'account',
        sourceId: 'account|google|cal-2',
        providerCalendarId: 'cal-2',
        title: 'Base',
        allDay: false,
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
        startTimeZone: 'UTC',
        endTimeZone: 'UTC',
      ),
    );

    final operation = await database.select(database.pendingOps).getSingle();
    expect(operation.operationType, 'event.move');
    expect(
      (jsonDecode(operation.requestJson)
          as Map<String, Object?>)[calendarEventRecurringScopeKey],
      RecurringEventMutationScope.entireSeries.name,
    );

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    expect(applied, 1);
    expect(client.calls, ['moveEvent:cal-1:series-master:cal-2']);
    final events = await database.select(database.calendarEvents).get();
    expect(
      events.where((event) => event.providerCalendarId == 'cal-1'),
      isEmpty,
    );
    expect(events, hasLength(1));
    expect(events.single.providerCalendarId, 'cal-2');
    expect(events.single.providerEventId, 'series-master');
  });

  test(
    'cross-provider move queues copy before deleting the original',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final repository = CalendarRepository(database: database);
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-event',
      );
      await repository.updateLocalEvent(
        EventEditorDraft.existing(
          eventId: eventId,
          accountId: 'microsoft-account',
          sourceId: 'microsoft-account|microsoft|ms-cal-1',
          providerCalendarId: 'ms-cal-1',
          title: 'Copied meeting',
          allDay: false,
          start: DateTime.utc(2026, 6, 8, 9),
          end: DateTime.utc(2026, 6, 8, 10),
          attendees: const [
            EventAttendeeDraft(email: 'me@example.com', self: true),
            EventAttendeeDraft(
              email: 'guest@example.com',
              responseStatus: 'accepted',
            ),
          ],
          conference: const {'conferenceId': 'old-meeting'},
        ),
      );

      final operations = await database.select(database.pendingOps).get();
      final create = operations.singleWhere(
        (op) => op.operationType == 'event.create',
      );
      final delete = operations.singleWhere(
        (op) => op.operationType == 'event.delete',
      );
      expect(create.accountId, 'microsoft-account');
      expect(delete.accountId, 'account');
      expect(delete.dependsOnOpId, create.id);
      final createRequest =
          jsonDecode(create.requestJson) as Map<String, Object?>;
      final attendees = createRequest[calendarEventAttendeesField] as List;
      expect(attendees, hasLength(1));
      expect((attendees.single as Map)['emailAddress'], {
        'address': 'guest@example.com',
      });
      expect(createRequest, isNot(contains('conferenceJson')));

      final original = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(original.isDeleted, isFalse);
      final copy = await (database.select(
        database.calendarEvents,
      )..where((row) => row.accountId.equals('microsoft-account'))).getSingle();
      expect(copy.title, 'Copied meeting');
      expect(copy.conferenceJson, equals(null));
    },
  );

  test(
    'copying a locally resolved Google event preserves its Microsoft pin',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final repository = CalendarRepository(database: database);
      final eventId = await _insertEvent(
        database,
        providerEventId: 'located-google-event',
      );
      await (database.update(database.calendarEvents)
            ..where((row) => row.id.equals(eventId)))
          .write(const CalendarEventsCompanion(location: Value('Same room')));
      final originalIdentity = LocationItemIdentity(
        kind: LocationItemKind.event,
        accountId: 'account',
        sourceId: 'account|google|cal-1',
        itemId: eventId,
      );
      final selection = LocationResult(
        label: 'Same room',
        point: GeographicPoint(latitude: 49.2827, longitude: -123.1207),
        address: const {'city': 'Vancouver'},
      );
      await LocationResolutionRepository(
        database,
      ).apply(originalIdentity, 'Same room', LocationChange.replace(selection));
      final detail = (await repository.loadEventDetail(eventId))!;

      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(
          accountId: 'microsoft-account',
          sourceId: 'microsoft-account|microsoft|ms-cal-1',
          providerCalendarId: 'ms-cal-1',
        ),
      );

      final destination = await (database.select(
        database.calendarEvents,
      )..where((row) => row.accountId.equals('microsoft-account'))).getSingle();
      expect(destination.locationLatitude, 49.2827);
      expect(destination.locationLongitude, -123.1207);
      final operation = await (database.select(
        database.pendingOps,
      )..where((row) => row.operationType.equals('event.create'))).getSingle();
      final request = jsonDecode(operation.requestJson) as Map;
      expect(
        (request['structuredLocation'] as Map)['coordinates'],
        selection.point.toJson(),
      );
      final destinationIdentity = LocationItemIdentity(
        kind: LocationItemKind.event,
        accountId: destination.accountId,
        sourceId: destination.calendarSourceId,
        itemId: destination.id,
      );
      final remembered = await LocationResolutionRepository(
        database,
      ).load(destinationIdentity, 'Same room');
      expect(remembered, isNull);
      final resolved =
          await LocationDestinationResolver(
            LocationResolutionRepository(database),
          ).resolveSaved(
            location: destination.location ?? '',
            nativePoint: GeographicPoint.tryParse(
              latitude: destination.locationLatitude,
              longitude: destination.locationLongitude,
            ),
            identity: destinationIdentity,
          );
      expect(resolved?.point, selection.point);
    },
  );

  test(
    'copying native Microsoft coordinates to Google remembers the pin',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final repository = CalendarRepository(database: database);
      final microsoftClient = _FakeMicrosoftCalendarClient();
      final nativeLocation = <String, Object?>{
        'displayName': 'Native room',
        'coordinates': {'latitude': 0.0, 'longitude': -123.0},
        'address': {'city': 'Vancouver'},
      };
      await repository.upsertEvent(
        accountId: 'microsoft-account',
        event: microsoftClient.microsoftEvent(
          'native-ms-event',
          location: nativeLocation,
          locations: [nativeLocation],
        ),
      );
      final sourceId = CalendarRepository.eventId(
        accountId: 'microsoft-account',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'ms-cal-1',
        providerEventId: 'native-ms-event',
      );
      final detail = (await repository.loadEventDetail(sourceId))!;

      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(
          accountId: 'account',
          sourceId: 'account|google|cal-1',
          providerCalendarId: 'cal-1',
        ),
      );

      final destination =
          await (database.select(database.calendarEvents)..where(
                (row) =>
                    row.accountId.equals('account') &
                    row.syncStatus.equals('pending'),
              ))
              .getSingle();
      expect(destination.location, 'Native room');
      expect(destination.locationLatitude, isNull);
      expect(destination.locationLongitude, isNull);
      final create =
          await (database.select(database.pendingOps)..where(
                (row) =>
                    row.accountId.equals('account') &
                    row.operationType.equals('event.create'),
              ))
              .getSingle();
      expect(
        jsonDecode(create.requestJson),
        isNot(contains('structuredLocation')),
      );
      final remembered = await LocationResolutionRepository(database).load(
        LocationItemIdentity(
          kind: LocationItemKind.event,
          accountId: destination.accountId,
          sourceId: destination.calendarSourceId,
          itemId: destination.id,
        ),
        'Native room',
      );
      expect(remembered?.point, GeographicPoint(latitude: 0, longitude: -123));
    },
  );

  test(
    'recurring Google import keeps its supplemental point after create and expanded sync',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp(
        'busymax-google-series-location-',
      );
      final databaseFile = File('${directory.path}/busymax.sqlite');
      database = AppDatabase(NativeDatabase(databaseFile));
      await _insertAccount(database);
      await CalendarRepository(database: database).upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: BusyProvider.google,
          providerCalendarId: 'cal-1',
          summary: 'Work',
          timeZone: 'America/Vancouver',
          dataOwner: 'me@example.com',
        ),
      );
      final repository = CalendarRepository(
        database: database,
        now: () => DateTime.utc(2026, 8, 29),
      );
      final importService = IcalImportService(
        database: database,
        calendarRepository: repository,
      );
      final preview = importService.parsePreview(
        utf8.encode(
          _icalCalendar('''
BEGIN:VEVENT
UID:recurring-location-import
DTSTART:20260830T160000Z
DTEND:20260830T170000Z
SUMMARY:Imported series
LOCATION:Room 2
GEO:49.2827;-123.1207
RRULE:FREQ=WEEKLY;COUNT=2
END:VEVENT
'''),
        ),
      );

      final report = await importService.importPreview(
        preview: preview,
        destination: (await importService.writableDestinations()).single,
      );
      expect(report.queued, 1);
      expect(
        await database.select(database.locationResolutions).get(),
        hasLength(1),
      );

      client.createEventOverride = (calendarId, mutation) => CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: calendarId,
        providerEventId: mutation.providerEventId!,
        title: mutation.title!,
        location: mutation.location,
        startDateTime: mutation.startDateTime,
        startTimeZone: mutation.startTimeZone,
        endDateTime: mutation.endDateTime,
        endTimeZone: mutation.endTimeZone,
        recurrenceJson: mutation.recurrence,
        rawJson: {
          'id': mutation.providerEventId,
          'summary': mutation.title,
          'location': mutation.location,
          'start': {
            'dateTime': mutation.startDateTime,
            'timeZone': mutation.startTimeZone,
          },
          'end': {
            'dateTime': mutation.endDateTime,
            'timeZone': mutation.endTimeZone,
          },
          'recurrence': mutation.recurrence,
        },
      );
      expect(
        await CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 8, 29),
        ).replayDueOps(),
        1,
      );

      final master = await database.select(database.calendarEvents).getSingle();
      expect(master.providerRecurringEventId, isNull);
      expect(master.recurrenceJson, isNotNull);
      final confirmedResolutions = await database
          .select(database.locationResolutions)
          .get();
      expect(confirmedResolutions, hasLength(2));
      expect(
        confirmedResolutions
            .where((row) => row.kind == LocationItemKind.event.name)
            .single
            .itemId,
        master.id,
      );
      expect(
        confirmedResolutions
            .where((row) => row.kind == googleSeriesLocationResolutionKind)
            .single
            .itemId,
        master.providerEventId,
      );

      CalendarEventDto occurrence({
        required String id,
        required String originalStart,
      }) => CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        providerEventId: id,
        providerRecurringEventId: master.providerEventId,
        providerOriginalStartKey: originalStart,
        title: 'Imported series',
        location: 'Room 2',
        startDateTime: originalStart,
        startTimeZone: 'UTC',
        endDateTime: DateTime.parse(
          originalStart,
        ).add(const Duration(hours: 1)).toIso8601String(),
        endTimeZone: 'UTC',
        rawJson: {
          'id': id,
          'recurringEventId': master.providerEventId,
          'originalStartTime': {'dateTime': originalStart},
          'summary': 'Imported series',
          'location': 'Room 2',
        },
      );

      client.syncEventsOverride = [
        occurrence(
          id: 'import-instance-1',
          originalStart: '2026-08-30T16:00:00.000Z',
        ),
      ];
      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 8, 29),
      ).fullSync();

      final events = await database.select(database.calendarEvents).get();
      expect(
        events.singleWhere((event) => event.id == master.id).isDeleted,
        isTrue,
      );
      final instances = events
          .where(
            (event) => event.providerRecurringEventId == master.providerEventId,
          )
          .toList();
      expect(instances, hasLength(1));
      expect(
        instances,
        everyElement(
          isNot(predicate<CalendarEvent>((event) => event.isDeleted)),
        ),
      );
      final rememberedBeforeResolution = await database
          .select(database.locationResolutions)
          .get();
      expect(rememberedBeforeResolution, hasLength(1));
      expect(
        rememberedBeforeResolution.single.kind,
        googleSeriesLocationResolutionKind,
      );
      expect(rememberedBeforeResolution.single.itemId, master.providerEventId);
      expect(
        rememberedBeforeResolution,
        everyElement(
          isA<LocationResolution>()
              .having((row) => row.latitude, 'latitude', 49.2827)
              .having((row) => row.longitude, 'longitude', -123.1207)
              .having((row) => row.source, 'source', 'ical')
              .having(
                (row) => row.attribution,
                'attribution',
                'Imported iCalendar GEO',
              ),
        ),
      );

      final resolver = LocationDestinationResolver(
        LocationResolutionRepository(database),
      );
      for (final instance in instances) {
        final resolved = await resolver.resolveSaved(
          location: instance.location ?? '',
          identity: LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: instance.accountId,
            sourceId: instance.calendarSourceId,
            itemId: instance.id,
          ),
        );
        expect(
          resolved?.point,
          GeographicPoint(latitude: 49.2827, longitude: -123.1207),
        );
      }
      expect(
        await database.select(database.locationResolutions).get(),
        rememberedBeforeResolution,
      );

      await database.close();
      database = AppDatabase(NativeDatabase(databaseFile));
      final reopenedResolver = LocationDestinationResolver(
        LocationResolutionRepository(database),
      );

      client.syncEventsOverride = [
        occurrence(
          id: 'import-instance-later',
          originalStart: '2026-09-06T16:00:00.000Z',
        ),
      ];
      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 9, 5),
      ).fullSync();
      final later = (await database.select(database.calendarEvents).get())
          .singleWhere(
            (event) => event.providerEventId == 'import-instance-later',
          );
      expect(
        (await reopenedResolver.resolveSaved(
          location: later.location ?? '',
          identity: LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: later.accountId,
            sourceId: later.calendarSourceId,
            itemId: later.id,
          ),
        ))?.point,
        GeographicPoint(latitude: 49.2827, longitude: -123.1207),
      );
      expect(
        await database.select(database.locationResolutions).get(),
        rememberedBeforeResolution,
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);

      await database.close();
      database = AppDatabase(NativeDatabase.memory());
      await directory.delete(recursive: true);
    },
  );

  test('explicit replacement and clear win while copying an event', () async {
    await _insertMicrosoftAccountAndSource(database);
    final repository = CalendarRepository(database: database);

    final replacementEventId = await _insertEvent(
      database,
      providerEventId: 'move-explicit-replacement',
    );
    await (database.update(database.calendarEvents)
          ..where((row) => row.id.equals(replacementEventId)))
        .write(const CalendarEventsCompanion(location: Value('Old room')));
    final originalIdentity = LocationItemIdentity(
      kind: LocationItemKind.event,
      accountId: 'account',
      sourceId: 'account|google|cal-1',
      itemId: replacementEventId,
    );
    await LocationResolutionRepository(database).apply(
      originalIdentity,
      'Old room',
      LocationChange.replace(
        LocationResult(
          label: 'Old room',
          point: GeographicPoint(latitude: 1, longitude: 2),
        ),
      ),
    );
    var detail = (await repository.loadEventDetail(replacementEventId))!;
    final replacement = LocationResult(
      label: 'New room',
      point: GeographicPoint(latitude: 3, longitude: 4),
    );
    await repository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail).copyWith(
        accountId: 'microsoft-account',
        sourceId: 'microsoft-account|microsoft|ms-cal-1',
        providerCalendarId: 'ms-cal-1',
        location: replacement.label,
        locationChange: LocationChange.replace(replacement),
      ),
    );
    var destinations = await (database.select(
      database.calendarEvents,
    )..where((row) => row.accountId.equals('microsoft-account'))).get();
    expect(destinations.single.locationLatitude, replacement.point.latitude);
    expect(destinations.single.locationLongitude, replacement.point.longitude);

    final clearEventId = await _insertEvent(
      database,
      providerEventId: 'move-explicit-clear',
    );
    await (database.update(
      database.calendarEvents,
    )..where((row) => row.id.equals(clearEventId))).write(
      const CalendarEventsCompanion(
        location: Value('Located'),
        locationLatitude: Value(5),
        locationLongitude: Value(6),
      ),
    );
    detail = (await repository.loadEventDetail(clearEventId))!;
    await repository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail).copyWith(
        accountId: 'microsoft-account',
        sourceId: 'microsoft-account|microsoft|ms-cal-1',
        providerCalendarId: 'ms-cal-1',
        clearLocation: true,
        locationChange: const LocationChange.clear(),
      ),
    );
    destinations = await (database.select(
      database.calendarEvents,
    )..where((row) => row.accountId.equals('microsoft-account'))).get();
    final cleared = destinations.singleWhere(
      (event) => event.location == null || event.location!.isEmpty,
    );
    expect(cleared.locationLatitude, isNull);
    expect(cleared.locationLongitude, isNull);
    expect(
      await LocationResolutionRepository(database).load(
        LocationItemIdentity(
          kind: LocationItemKind.event,
          accountId: cleared.accountId,
          sourceId: cleared.calendarSourceId,
          itemId: cleared.id,
        ),
        '',
      ),
      isNull,
    );
  });

  test(
    'copy move repin never overwrites a same-label destination event',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final repository = CalendarRepository(database: database);
      final unrelatedId = await _insertEvent(
        database,
        providerEventId: 'unrelated-destination',
      );
      await (database.update(database.calendarEvents)
            ..where((row) => row.id.equals(unrelatedId)))
          .write(const CalendarEventsCompanion(location: Value('Shared hall')));
      final unrelatedIdentity = LocationItemIdentity(
        kind: LocationItemKind.event,
        accountId: 'account',
        sourceId: 'account|google|cal-1',
        itemId: unrelatedId,
      );
      final unrelatedSelection = LocationResult(
        label: 'Shared hall',
        point: GeographicPoint(latitude: 1, longitude: 2),
      );
      await LocationResolutionRepository(database).apply(
        unrelatedIdentity,
        'Shared hall',
        LocationChange.replace(unrelatedSelection),
      );

      const providerEventId = 'microsoft-source-event';
      await repository.upsertEvent(
        accountId: 'microsoft-account',
        event: const CalendarEventDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: 'ms-cal-1',
          providerEventId: providerEventId,
          title: 'Moved meeting',
          location: 'Shared hall',
          organizerJson: {'self': true},
          startDateTime: '2026-06-08T09:00:00.000Z',
          endDateTime: '2026-06-08T10:00:00.000Z',
          updatedAtServer: '2026-06-08T00:00:00.000Z',
          rawJson: {
            'id': providerEventId,
            'subject': 'Moved meeting',
            'location': {'displayName': 'Shared hall'},
          },
        ),
      );
      final sourceId = CalendarRepository.eventId(
        accountId: 'microsoft-account',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'ms-cal-1',
        providerEventId: providerEventId,
      );
      final detail = (await repository.loadEventDetail(sourceId))!;
      final replacement = LocationResult(
        label: 'Shared hall',
        point: GeographicPoint(latitude: 3, longitude: 4),
      );

      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(
          accountId: 'account',
          sourceId: 'account|google|cal-1',
          providerCalendarId: 'cal-1',
          locationChange: LocationChange.replace(replacement),
        ),
      );

      expect(
        await LocationResolutionRepository(
          database,
        ).load(unrelatedIdentity, 'Shared hall'),
        unrelatedSelection,
      );
      final copied =
          (await (database.select(database.calendarEvents)..where(
                    (row) =>
                        row.accountId.equals('account') &
                        row.providerEventId.like('local:%'),
                  ))
                  .get())
              .single;
      expect(
        await LocationResolutionRepository(database).load(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: copied.accountId,
            sourceId: copied.calendarSourceId,
            itemId: copied.id,
          ),
          'Shared hall',
        ),
        replacement,
      );
    },
  );

  test(
    'failed move setup rolls back its destination and keeps source selection',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final repository = CalendarRepository(database: database);
      final eventId = await _insertEvent(
        database,
        providerEventId: 'move-setup-failure',
      );
      await (database.update(database.calendarEvents)
            ..where((row) => row.id.equals(eventId)))
          .write(const CalendarEventsCompanion(location: Value('Source room')));
      final sourceIdentity = LocationItemIdentity(
        kind: LocationItemKind.event,
        accountId: 'account',
        sourceId: 'account|google|cal-1',
        itemId: eventId,
      );
      final selection = LocationResult(
        label: 'Source room',
        point: GeographicPoint(latitude: 7, longitude: 8),
      );
      await LocationResolutionRepository(
        database,
      ).apply(sourceIdentity, 'Source room', LocationChange.replace(selection));
      await database.customStatement('''
      CREATE TRIGGER fail_move_delete
      BEFORE INSERT ON pending_ops
      WHEN NEW.operation_type = 'event.delete'
      BEGIN
        SELECT RAISE(ABORT, 'simulated move setup failure');
      END
    ''');
      final detail = (await repository.loadEventDetail(eventId))!;

      await expectLater(
        repository.updateLocalEvent(
          EventEditorDraft.fromEventDetail(detail).copyWith(
            accountId: 'microsoft-account',
            sourceId: 'microsoft-account|microsoft|ms-cal-1',
            providerCalendarId: 'ms-cal-1',
          ),
        ),
        throwsA(anything),
      );

      expect(
        await (database.select(
          database.calendarEvents,
        )..where((row) => row.accountId.equals('microsoft-account'))).get(),
        isEmpty,
      );
      expect(
        await LocationResolutionRepository(
          database,
        ).load(sourceIdentity, 'Source room'),
        isNotNull,
      );
      expect(
        await (database.select(
          database.pendingOps,
        )..where((row) => row.operationType.equals('event.create'))).get(),
        isEmpty,
      );
    },
  );

  test(
    'destination ID reconciliation retains the moved remembered point',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final repository = CalendarRepository(database: database);
      final eventId = await _insertEvent(
        database,
        providerEventId: 'move-and-reconcile-location',
      );
      await (database.update(database.calendarEvents)
            ..where((row) => row.id.equals(eventId)))
          .write(const CalendarEventsCompanion(location: Value('Mapped room')));
      final sourceIdentity = LocationItemIdentity(
        kind: LocationItemKind.event,
        accountId: 'account',
        sourceId: 'account|google|cal-1',
        itemId: eventId,
      );
      final selection = LocationResult(
        label: 'Mapped room',
        point: GeographicPoint(latitude: 9, longitude: 10),
      );
      await LocationResolutionRepository(
        database,
      ).apply(sourceIdentity, 'Mapped room', LocationChange.replace(selection));
      final detail = (await repository.loadEventDetail(eventId))!;
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(
          accountId: 'microsoft-account',
          sourceId: 'microsoft-account|microsoft|ms-cal-1',
          providerCalendarId: 'ms-cal-1',
        ),
      );
      final temporary = await (database.select(
        database.calendarEvents,
      )..where((row) => row.accountId.equals('microsoft-account'))).getSingle();
      expect(temporary.id, contains('local:'));
      final microsoftClient = _FakeMicrosoftCalendarClient();

      expect(
        await CalendarPendingOpsReplayer(
          database: database,
          client: microsoftClient,
          accountId: 'microsoft-account',
          nowUtc: () => DateTime.utc(2026, 6, 9),
        ).replayDueOps(),
        1,
      );

      final destination = await (database.select(
        database.calendarEvents,
      )..where((row) => row.accountId.equals('microsoft-account'))).getSingle();
      expect(destination.providerEventId, 'server-event-1');
      expect(destination.id, isNot(temporary.id));
      expect(destination.locationLatitude, selection.point.latitude);
      expect(destination.locationLongitude, selection.point.longitude);
      final destinationIdentity = LocationItemIdentity(
        kind: LocationItemKind.event,
        accountId: destination.accountId,
        sourceId: destination.calendarSourceId,
        itemId: destination.id,
      );
      expect(
        await LocationResolutionRepository(
          database,
        ).load(destinationIdentity, 'Mapped room'),
        isNull,
      );
      final resolved =
          await LocationDestinationResolver(
            LocationResolutionRepository(database),
          ).resolveSaved(
            location: destination.location ?? '',
            nativePoint: GeographicPoint.tryParse(
              latitude: destination.locationLatitude,
              longitude: destination.locationLongitude,
            ),
            identity: destinationIdentity,
          );
      expect(resolved?.point, selection.point);
      expect(
        await LocationResolutionRepository(database).load(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: temporary.accountId,
            sourceId: temporary.calendarSourceId,
            itemId: temporary.id,
          ),
          'Mapped room',
        ),
        isNull,
      );
    },
  );

  test(
    'cross-provider single occurrence is copied without recurrence',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final repository = CalendarRepository(database: database);
      final eventId = await _insertEvent(
        database,
        providerEventId: 'provider-occurrence',
        providerRecurringEventId: 'provider-series',
      );

      await repository.updateLocalEvent(
        EventEditorDraft.existing(
          eventId: eventId,
          providerRecurringEventId: 'provider-series',
          recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
          accountId: 'microsoft-account',
          sourceId: 'microsoft-account|microsoft|ms-cal-1',
          providerCalendarId: 'ms-cal-1',
          title: 'Copied occurrence',
          allDay: false,
          start: DateTime.utc(2026, 6, 8, 9),
          end: DateTime.utc(2026, 6, 8, 10),
          recurrence: const ['RRULE:FREQ=WEEKLY;BYHOUR=9'],
        ),
      );

      final operations = await database.select(database.pendingOps).get();
      final create = operations.singleWhere(
        (op) => op.operationType == 'event.create',
      );
      final delete = operations.singleWhere(
        (op) => op.operationType == 'event.delete',
      );
      final createRequest =
          jsonDecode(create.requestJson) as Map<String, Object?>;
      final deleteRequest =
          jsonDecode(delete.requestJson) as Map<String, Object?>;
      expect(createRequest[calendarEventRecurrenceField], equals(null));
      expect(
        deleteRequest[calendarEventRecurringScopeKey],
        RecurringEventMutationScope.singleOccurrence.name,
      );
    },
  );

  test('cross-account move deletes only after the copy is confirmed', () async {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'destination-account',
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'destination-google-account',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            grantedScopes: const Value(''),
            createdAtUtc: '2026-06-08T00:00:00.000Z',
            updatedAtUtc: '2026-06-08T00:00:00.000Z',
          ),
        );
    final repository = CalendarRepository(database: database);
    await repository.upsertSource(
      accountId: 'destination-account',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'destination-cal',
        summary: 'Destination',
        timeZone: 'America/Vancouver',
      ),
    );
    final eventId = await _insertEvent(
      database,
      providerEventId: 'provider-event',
    );
    await repository.updateLocalEvent(
      EventEditorDraft.existing(
        eventId: eventId,
        accountId: 'destination-account',
        sourceId: 'destination-account|google|destination-cal',
        providerCalendarId: 'destination-cal',
        title: 'Cross-account copy',
        allDay: false,
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
      ),
    );

    final sourceReplayBeforeCopy = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();
    expect(sourceReplayBeforeCopy, 0);
    expect(client.calls, isEmpty);

    final copied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'destination-account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();
    expect(copied, 1);
    var deleteOperation = await (database.select(
      database.pendingOps,
    )..where((row) => row.operationType.equals('event.delete'))).getSingle();
    var deleteRequest =
        jsonDecode(deleteOperation.requestJson) as Map<String, Object?>;
    expect(deleteRequest[calendarEventCopyConfirmedKey], isTrue);
    expect(deleteRequest[calendarEventCopyDestinationEventIdKey], isNotEmpty);

    client.calls.clear();
    final deleted = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();
    expect(deleted, 1);
    expect(client.calls, [
      'getEvent:cal-1:provider-event',
      'deleteEvent:cal-1:provider-event',
    ]);
    expect(
      (await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle()).isDeleted,
      isTrue,
    );
  });

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
      expect(client.updatedMutations.single.startTimeZone, equals(null));
      expect(client.updatedMutations.single.endTimeZone, equals(null));
      expect(
        await database.pendingOpsDao.pendingOpsForReplay('account', _later),
        isEmpty,
      );
    },
  );

  test('zoned guarded series edit replays the same civil delta', () async {
    final repository = CalendarRepository(database: database);
    final id = await _insertGoogleOccurrence(repository, day: 8);
    await database
        .update(database.calendarEvents)
        .write(
          const CalendarEventsCompanion(
            startTimeZone: Value('America/Vancouver'),
            endTimeZone: Value('America/Vancouver'),
          ),
        );
    final detail = (await repository.loadEventDetail(id))!;
    await repository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail).copyWith(
        start: providerInstantInTimeZone(
          DateTime.utc(2026, 6, 8, 11),
          'America/Vancouver',
        ),
        end: providerInstantInTimeZone(
          DateTime.utc(2026, 6, 8, 12),
          'America/Vancouver',
        ),
        recurringMutationScope: RecurringEventMutationScope.entireSeries,
      ),
      timingBaseline: EventTimingBaseline.fromDetail(detail),
    );
    client.remoteEvent = _googleSeriesMaster(timeZone: 'America/Vancouver');
    expect(
      await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      ).replayDueOps(),
      1,
    );
    // UTC instants are projected in Vancouver, from 02:00 to 04:00 local.
    expect(
      client.updatedMutations.single.startDateTime,
      '2026-06-01T04:00:00.000',
    );
    expect(
      client.updatedMutations.single.endDateTime,
      '2026-06-01T05:00:00.000',
    );
  });

  for (final encoding in ['offset', 'instant', 'floating']) {
    test(
      'series projection and replay preserve Tokyo wall fields in host DST gap ($encoding)',
      () async {
        final hostZone = ProcessTimeZone();
        hostZone.set('America/Vancouver');
        addTearDown(hostZone.restore);
        expect(
          DateTime(2026, 3, 8, 2, 30).hour,
          isNot(2),
          reason:
              'The host must actually normalize this nonexistent local time.',
        );
        const zone = 'Asia/Tokyo';
        String timestamp(int day, int hour) => switch (encoding) {
          'offset' =>
            '2026-03-${day.toString().padLeft(2, '0')}T0$hour:30:00+09:00',
          'instant' => DateTime.utc(
            2026,
            3,
            day,
            hour - 9,
            30,
          ).toIso8601String(),
          _ => '2026-03-${day.toString().padLeft(2, '0')}T0$hour:30:00',
        };
        final repository = CalendarRepository(database: database);
        final ids = <String>[];
        for (final day in [8, 15]) {
          ids.add(
            await _insertGoogleOccurrence(
              repository,
              day: day,
              start: timestamp(day, 2),
              end: timestamp(day, 3),
              timeZone: zone,
            ),
          );
        }
        final detail = (await repository.loadEventDetail(ids.first))!;
        await repository.updateLocalEvent(
          EventEditorDraft.fromEventDetail(detail).copyWith(
            start: providerInstantInTimeZone(
              DateTime.utc(2026, 3, 7, 18, 30),
              zone,
            ),
            end: providerInstantInTimeZone(
              DateTime.utc(2026, 3, 7, 19, 30),
              zone,
            ),
            recurringMutationScope: RecurringEventMutationScope.entireSeries,
          ),
          timingBaseline: EventTimingBaseline.fromDetail(detail),
        );
        for (var index = 0; index < ids.length; index++) {
          final saved = (await repository.loadEventDetail(ids[index]))!;
          final day = index == 0 ? '08' : '15';
          expect(saved.startDateTime, '2026-03-${day}T03:30:00.000');
          expect(saved.endDateTime, '2026-03-${day}T04:30:00.000');
          expect(saved.syncStatus, 'pending');
        }
        client
          ..remoteEvent = _googleSeriesMaster(
            timeZone: zone,
            start: timestamp(1, 2),
            end: timestamp(1, 3),
          )
          ..persistEventUpdates = true;
        expect(
          await CalendarPendingOpsReplayer(
            database: database,
            client: client,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 8),
          ).replayDueOps(),
          1,
        );
        expect(client.remoteEvent!.startDateTime, '2026-03-01T03:30:00.000');
        expect(client.remoteEvent!.endDateTime, '2026-03-01T04:30:00.000');
        final rows = await database.select(database.calendarEvents).get();
        expect(rows.map((row) => row.syncStatus), everyElement('synced'));
      },
      skip: !(Platform.isLinux || Platform.isMacOS),
    );
  }

  test('entire-series edit patches the recurring master', () async {
    final repository = CalendarRepository(database: database);
    final ids = <String>[];
    for (final day in [1, 8, 15]) {
      ids.add(await _insertGoogleOccurrence(repository, day: day));
    }
    final detail = await repository.loadEventDetail(ids[1]);
    await repository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail!).copyWith(
        title: 'Renamed series',
        start: DateTime(2026, 6, 8, 11),
        end: DateTime(2026, 6, 8, 12),
        recurringMutationScope: RecurringEventMutationScope.entireSeries,
      ),
    );
    client.remoteEvent = _googleSeriesMaster();

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    expect(applied, 1);
    expect(client.calls, [
      'getEvent:cal-1:series-master',
      'updateEvent:cal-1:series-master:Renamed series',
    ]);
    expect(client.updatedMutations.single.title, 'Renamed series');
    expect(
      client.updatedMutations.single.startDateTime,
      '2026-06-01T11:00:00.000',
    );
    expect(
      client.updatedMutations.single.endDateTime,
      '2026-06-01T12:00:00.000',
    );
    expect(client.updatedMutations.single.recurrence, const [
      'RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=MO;WKST=MO;COUNT=5',
    ]);
    final rows = await database.select(database.calendarEvents).get();
    expect(rows.map((row) => row.syncStatus), everyElement('synced'));
  });

  test(
    'entire-series retry does not apply the occurrence delta twice',
    () async {
      final repository = CalendarRepository(database: database);
      final ids = <String>[];
      for (final day in [1, 8, 15]) {
        ids.add(await _insertGoogleOccurrence(repository, day: day));
      }
      final detail = await repository.loadEventDetail(ids[1]);
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail!).copyWith(
          start: DateTime(2026, 6, 8, 11),
          end: DateTime(2026, 6, 8, 12),
          recurringMutationScope: RecurringEventMutationScope.entireSeries,
        ),
      );
      client
        ..remoteEvent = _googleSeriesMaster()
        ..transientUpdateFailures = 1;

      final firstApplied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      ).replayDueOps();
      final secondApplied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 9),
      ).replayDueOps();

      expect(firstApplied, 0);
      expect(secondApplied, 1);
      expect(client.updatedMutations, hasLength(2));
      expect(
        client.updatedMutations.map((mutation) => mutation.startDateTime),
        everyElement('2026-06-01T11:00:00.000'),
      );
      expect(
        client.updatedMutations.map((mutation) => mutation.endDateTime),
        everyElement('2026-06-01T12:00:00.000'),
      );
      expect(
        client.calls.where((call) => call.startsWith('getEvent:')),
        hasLength(1),
      );
    },
  );

  for (final differentOccurrence in [false, true]) {
    test(
      'two queued series moves ${differentOccurrence ? 'from different occurrences' : 'from the same occurrence'} retain the interval and pending projection',
      () async {
        final repository = CalendarRepository(database: database);
        final ids = [
          await _insertGoogleOccurrence(repository, day: 8),
          await _insertGoogleOccurrence(repository, day: 15),
        ];
        for (var move = 0; move < 2; move++) {
          final id = ids[differentOccurrence ? move : 0];
          final detail = (await repository.loadEventDetail(id))!;
          final day = differentOccurrence && move == 1 ? 15 : 8;
          await repository.updateLocalEvent(
            EventEditorDraft.fromEventDetail(detail).copyWith(
              start: DateTime.utc(2026, 6, day, 10 + move),
              end: DateTime.utc(2026, 6, day, 11 + move),
              recurringMutationScope: RecurringEventMutationScope.entireSeries,
            ),
          );
        }
        final ops = await database.select(database.pendingOps).get();
        final second = ops.singleWhere((op) => op.dependsOnOpId != null);
        final first = ops.singleWhere((op) => op.id != second.id);
        expect(second.dependsOnOpId, first.id);
        final request = jsonDecode(second.requestJson) as Map;
        final baseline = request[calendarEventTimingBaselineKey] as Map;
        expect(
          providerDateTimeAsCivilTime(baseline['start'] as String, 'UTC')!.hour,
          10,
        );
        expect(
          providerDateTimeAsCivilTime(baseline['end'] as String, 'UTC')!.hour,
          11,
        );
        expect(
          providerDateTimeAsCivilTime(
            request[calendarEventOriginalStartKey] as String,
            'UTC',
          )!.hour,
          9,
        );
        await (database.update(
          database.pendingOps,
        )..where((row) => row.id.equals(second.id))).write(
          const PendingOpsCompanion(
            nextAttemptAtUtc: Value('2026-06-09T00:00:00.000Z'),
          ),
        );
        client
          ..remoteEvent = _googleSeriesMaster()
          ..persistEventUpdates = true;
        Future<int> replay(int day) => CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, day),
        ).replayDueOps();
        expect(await replay(8), 1);
        expect(client.remoteEvent!.startDateTime, '2026-06-01T10:00:00.000');
        expect(client.remoteEvent!.endDateTime, '2026-06-01T11:00:00.000');
        for (final id in ids) {
          final detail = (await repository.loadEventDetail(id))!;
          expect(detail.syncStatus, 'pending');
          expect(
            providerDateTimeAsCivilTime(detail.startDateTime, 'UTC')!.hour,
            11,
          );
          expect(
            providerDateTimeAsCivilTime(detail.endDateTime, 'UTC')!.hour,
            12,
          );
        }
        expect(await replay(9), 1);
        expect(client.remoteEvent!.startDateTime, '2026-06-01T11:00:00.000');
        expect(client.remoteEvent!.endDateTime, '2026-06-01T12:00:00.000');
        expect(await database.select(database.pendingOps).get(), isEmpty);
        final rows = await database.select(database.calendarEvents).get();
        expect(rows.map((row) => row.syncStatus), everyElement('synced'));
      },
    );
  }

  test('Google this-and-following edit trims and splits the series', () async {
    final repository = CalendarRepository(database: database);
    final ids = <String>[];
    for (final day in [1, 8, 15]) {
      ids.add(await _insertGoogleOccurrence(repository, day: day));
    }
    final detail = await repository.loadEventDetail(ids[2]);
    await repository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail!).copyWith(
        title: 'New series title',
        recurringMutationScope: RecurringEventMutationScope.thisAndFuture,
      ),
    );
    client
      ..remoteEvent = _googleSeriesMaster()
      ..eventInstances = [
        _googleSeriesInstance(day: 1),
        _googleSeriesInstance(day: 8),
        _googleSeriesInstance(day: 15),
      ];
    final operation = await database.select(database.pendingOps).getSingle();

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    expect(applied, 1);
    expect(client.calls, [
      'getEvent:cal-1:series-master',
      'listAllEventInstances:cal-1:series-master',
      'updateEvent:cal-1:series-master:null',
      'createEvent:cal-1:New series title',
    ]);
    expect(client.updatedMutations.single.recurrence, const [
      'RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=MO;WKST=MO;'
          'UNTIL=20260615T085959Z',
    ]);
    final split = client.createdMutations.single;
    expect(split.title, 'New series title');
    expect(split.startDateTime, '2026-06-15T09:00:00.000Z');
    expect(split.endDateTime, '2026-06-15T10:00:00.000Z');
    expect(split.recurrence, const [
      'RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=MO;WKST=MO;COUNT=3',
    ]);
    expect(split.providerEventId, operation.id.replaceAll('-', ''));
    expect(split.providerRaw?['id'], 'series-master');
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test(
    'Google count split includes a moved earlier occurrence across retry',
    () async {
      final repository = CalendarRepository(database: database);
      await _insertGoogleOccurrence(repository, day: 1);
      final targetId = await _insertGoogleOccurrence(repository, day: 15);
      final detail = (await repository.loadEventDetail(targetId))!;
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(
          title: 'New series title',
          recurringMutationScope: RecurringEventMutationScope.thisAndFuture,
        ),
      );
      final operation = await database.select(database.pendingOps).getSingle();
      final splitSeriesId = operation.id.replaceAll('-', '').toLowerCase();
      client
        ..remoteEvent = _googleSeriesMaster()
        ..eventInstances = [
          _googleSeriesInstance(day: 1),
          _googleSeriesInstance(
            day: 8,
            actualStart: DateTime.utc(2026, 7, 1, 9),
          ),
          _googleSeriesInstance(day: 15),
          _googleSeriesInstance(day: 22),
          _googleSeriesInstance(day: 29),
        ]
        ..createEventResponseError = StateError('response lost');

      // Google applies these bounds to effective event times. The June 8
      // occurrence is therefore absent even though its original identity is
      // before the June 15 split.
      final bounded = await client.listEventInstances(
        calendarId: 'cal-1',
        recurringEventId: 'series-master',
        rangeStart: DateTime.utc(2026, 5, 31),
        rangeEnd: DateTime.utc(2026, 6, 16),
      );
      expect(bounded.map((event) => event.providerOriginalStartKey), [
        '2026-06-01T09:00:00.000Z',
        '2026-06-15T09:00:00.000Z',
      ]);
      client.calls.clear();

      expect(
        await CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 8),
        ).replayDueOps(),
        0,
      );
      expect(client.createdMutations.single.recurrence, const [
        'RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=MO;WKST=MO;COUNT=3',
      ]);
      client.eventInstances = const [];

      expect(
        await CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 9),
        ).replayDueOps(),
        1,
      );
      expect(client.distinctCreatedEventCount, 1);
      expect(client.createdMutations, hasLength(2));
      expect(
        client.createdMutations.map((mutation) => mutation.recurrence),
        everyElement(
          equals(const [
            'RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=MO;WKST=MO;COUNT=3',
          ]),
        ),
      );
      expect(
        client.calls.where(
          (call) => call == 'listAllEventInstances:cal-1:series-master',
        ),
        hasLength(1),
      );
      expect(_weeklyOccurrenceStarts(client.createdMutations.last), [
        DateTime.utc(2026, 6, 15, 9),
        DateTime.utc(2026, 6, 22, 9),
        DateTime.utc(2026, 6, 29, 9),
      ]);
      expect(
        client.createdMutations.map((mutation) => mutation.providerEventId),
        everyElement(splitSeriesId),
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test(
    'Google following title/time split copies the series point once across retry and sync',
    () async {
      final repository = CalendarRepository(database: database);
      final ids = <String>[];
      for (final day in [1, 8, 15]) {
        ids.add(
          await _insertGoogleOccurrence(
            repository,
            day: day,
            location: 'Room 2',
          ),
        );
      }
      await _insertGoogleSeriesResolution(database);
      final detail = await repository.loadEventDetail(ids[1]);
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail!).copyWith(
          title: 'New series title',
          start: DateTime.utc(2026, 6, 8, 10),
          end: DateTime.utc(2026, 6, 8, 11),
          recurringMutationScope: RecurringEventMutationScope.thisAndFuture,
        ),
      );
      final operation = await database.select(database.pendingOps).getSingle();
      final splitSeriesId = operation.id.replaceAll('-', '').toLowerCase();
      client
        ..remoteEvent = _googleSeriesMaster(location: 'Room 2')
        ..eventInstances = [
          _googleSeriesInstance(day: 1, location: 'Room 2'),
          _googleSeriesInstance(day: 8, location: 'Room 2'),
          _googleSeriesInstance(day: 15, location: 'Room 2'),
        ]
        ..createEventResponseError = StateError('response lost');

      expect(
        await CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 8),
        ).replayDueOps(),
        0,
      );
      expect(
        (await database.select(database.locationResolutions).get()).map(
          (row) => row.itemId,
        ),
        ['series-master'],
      );

      expect(
        await CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 9),
        ).replayDueOps(),
        1,
      );
      expect(client.distinctCreatedEventCount, 1);
      expect(
        client.createdMutations.map((mutation) => mutation.providerEventId),
        [splitSeriesId, splitSeriesId],
      );
      final seriesResolutions = await database
          .select(database.locationResolutions)
          .get();
      expect(seriesResolutions, hasLength(2));
      expect(seriesResolutions.map((row) => row.itemId).toSet(), {
        'series-master',
        splitSeriesId,
      });
      expect(
        seriesResolutions,
        everyElement(
          isA<LocationResolution>()
              .having((row) => row.locationText, 'location', 'Room 2')
              .having((row) => row.latitude, 'latitude', 49.2827)
              .having((row) => row.longitude, 'longitude', -123.1207)
              .having((row) => row.source, 'source', 'ical')
              .having(
                (row) => row.attribution,
                'attribution',
                'Imported iCalendar GEO',
              ),
        ),
      );

      client.syncEventsOverride = [
        _googleSeriesInstance(day: 1, location: 'Room 2'),
        _googleSeriesInstance(
          day: 8,
          id: 'split-instance-08',
          seriesId: splitSeriesId,
          title: 'New series title',
          location: 'Room 2',
          startHour: 10,
        ),
        _googleSeriesInstance(
          day: 15,
          id: 'split-instance-15',
          seriesId: splitSeriesId,
          title: 'New series title',
          location: 'Room 2',
          startHour: 10,
        ),
      ];
      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 10),
      ).fullSync();

      final active = (await database.select(database.calendarEvents).get())
          .where((event) => !event.isDeleted)
          .toList();
      expect(active, hasLength(3));
      expect(active.map((event) => event.providerRecurringEventId).toSet(), {
        'series-master',
        splitSeriesId,
      });
      for (final event in active) {
        final resolved = await LocationResolutionRepository(database).load(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: event.accountId,
            sourceId: event.calendarSourceId,
            itemId: event.id,
          ),
          event.location ?? '',
        );
        expect(
          resolved,
          isA<LocationResult>()
              .having(
                (result) => result.point,
                'point',
                GeographicPoint(latitude: 49.2827, longitude: -123.1207),
              )
              .having((result) => result.source, 'source', 'ical')
              .having(
                (result) => result.attribution,
                'attribution',
                'Imported iCalendar GEO',
              ),
        );
      }
      expect(
        await CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 11),
        ).replayDueOps(),
        0,
      );
      expect(
        await database.select(database.locationResolutions).get(),
        hasLength(2),
      );
    },
  );

  test(
    'Google following location split keeps only the earlier series point',
    () async {
      final repository = CalendarRepository(database: database);
      final ids = <String>[];
      for (final day in [1, 8, 15]) {
        ids.add(
          await _insertGoogleOccurrence(
            repository,
            day: day,
            location: 'Room 2',
          ),
        );
      }
      await _insertGoogleSeriesResolution(database);
      final detail = await repository.loadEventDetail(ids[1]);
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail!).copyWith(
          location: 'New room',
          recurringMutationScope: RecurringEventMutationScope.thisAndFuture,
        ),
      );
      final operation = await database.select(database.pendingOps).getSingle();
      final splitSeriesId = operation.id.replaceAll('-', '').toLowerCase();
      expect(
        (await database.select(database.locationResolutions).get())
            .single
            .itemId,
        'series-master',
      );
      client
        ..remoteEvent = _googleSeriesMaster(location: 'Room 2')
        ..eventInstances = [
          _googleSeriesInstance(day: 1, location: 'Room 2'),
          _googleSeriesInstance(day: 8, location: 'Room 2'),
          _googleSeriesInstance(day: 15, location: 'Room 2'),
        ];

      expect(
        await CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 8),
        ).replayDueOps(),
        1,
      );
      final resolutions = await database
          .select(database.locationResolutions)
          .get();
      expect(resolutions, hasLength(1));
      expect(resolutions.single.itemId, 'series-master');

      client.syncEventsOverride = [
        _googleSeriesInstance(day: 1, location: 'Room 2'),
        _googleSeriesInstance(
          day: 8,
          id: 'new-room-instance-08',
          seriesId: splitSeriesId,
          location: 'New room',
        ),
        _googleSeriesInstance(
          day: 15,
          id: 'new-room-instance-15',
          seriesId: splitSeriesId,
          location: 'New room',
        ),
      ];
      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 10),
      ).fullSync();

      final active = (await database.select(database.calendarEvents).get())
          .where((event) => !event.isDeleted)
          .toList();
      final earlier = active.singleWhere(
        (event) => event.providerRecurringEventId == 'series-master',
      );
      final future = active.where(
        (event) => event.providerRecurringEventId == splitSeriesId,
      );
      expect(future, hasLength(2));
      expect(
        await LocationResolutionRepository(database).load(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: earlier.accountId,
            sourceId: earlier.calendarSourceId,
            itemId: earlier.id,
          ),
          'Room 2',
        ),
        isNotNull,
      );
      for (final event in future) {
        expect(
          await LocationResolutionRepository(database).load(
            LocationItemIdentity(
              kind: LocationItemKind.event,
              accountId: event.accountId,
              sourceId: event.calendarSourceId,
              itemId: event.id,
            ),
            'New room',
          ),
          isNull,
        );
      }
      expect(
        (await database.select(database.locationResolutions).get()).map(
          (row) => row.itemId,
        ),
        ['series-master'],
      );
    },
  );

  test('Google this-and-following delete trims the old series', () async {
    final repository = CalendarRepository(database: database);
    final ids = <String>[];
    for (final day in [1, 8, 15]) {
      ids.add(await _insertGoogleOccurrence(repository, day: day));
    }
    await repository.deleteLocalEvent(
      ids[1],
      recurringScope: RecurringEventMutationScope.thisAndFuture,
    );
    client.remoteEvent = _googleSeriesMaster();

    final applied = await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    expect(applied, 1);
    expect(client.calls, [
      'getEvent:cal-1:series-master',
      'updateEvent:cal-1:series-master:null',
    ]);
    expect(client.updatedMutations.single.recurrence, const [
      'RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=MO;WKST=MO;'
          'UNTIL=20260608T085959Z',
    ]);
    final rows =
        await (database.select(database.calendarEvents)..orderBy([
              (row) => OrderingTerm.asc(row.providerOriginalStartKey),
            ]))
            .get();
    expect(rows.map((row) => row.isDeleted), [false, true, true]);
    expect(rows.map((row) => row.syncStatus), everyElement('synced'));
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

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

  test(
    'Microsoft same-label coordinate changes conflict before replacement',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final microsoftClient = _FakeMicrosoftCalendarClient();
      final repository = CalendarRepository(
        database: database,
        now: () => DateTime.utc(2026, 6, 8),
      );
      final baselineLocation = <String, Object?>{
        'displayName': 'Harbour room',
        'coordinates': {'latitude': 49.28, 'longitude': -123.12},
        'address': {'city': 'Vancouver'},
      };
      final baseline = microsoftClient.microsoftEvent(
        'ms-event',
        location: baselineLocation,
        locations: [
          baselineLocation,
          {
            'displayName': 'Overflow room',
            'locationEmailAddress': 'overflow@example.test',
          },
        ],
      );
      await repository.upsertEvent(
        accountId: 'microsoft-account',
        event: baseline,
      );
      final eventId = CalendarRepository.eventId(
        accountId: 'microsoft-account',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'ms-cal-1',
        providerEventId: 'ms-event',
      );
      final detail = (await repository.loadEventDetail(eventId))!;
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(
          locationChange: LocationChange.replace(
            LocationResult(
              label: 'Harbour room',
              point: GeographicPoint(latitude: 49.29, longitude: -123.11),
            ),
          ),
        ),
      );
      microsoftClient.remoteEvent = microsoftClient.microsoftEvent(
        'ms-event',
        location: {
          ...baselineLocation,
          'coordinates': {'latitude': 49.30, 'longitude': -123.10},
        },
        locations: [baselineLocation],
        updatedAtServer: '2026-06-08T00:05:00.000Z',
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: microsoftClient,
        accountId: 'microsoft-account',
        nowUtc: () => DateTime.utc(2026, 6, 9),
      ).replayDueOps();

      expect(applied, 0);
      expect(microsoftClient.updatedMutations, isEmpty);
      final operation = await database.select(database.pendingOps).getSingle();
      expect(operation.lastErrorCode, 'conflict');
      expect(operation.lastErrorMessage, contains('location'));
    },
  );

  test(
    'Microsoft remote address and locations changes block a local clear',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final microsoftClient = _FakeMicrosoftCalendarClient();
      final repository = CalendarRepository(database: database);
      final location = <String, Object?>{
        'displayName': 'Harbour room',
        'coordinates': {'latitude': 49.28, 'longitude': -123.12},
        'address': {'city': 'Vancouver', 'street': '1 Main Street'},
      };
      final baseline = microsoftClient.microsoftEvent(
        'ms-clear-conflict',
        location: location,
        locations: [location],
      );
      await repository.upsertEvent(
        accountId: 'microsoft-account',
        event: baseline,
      );
      final eventId = CalendarRepository.eventId(
        accountId: 'microsoft-account',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'ms-cal-1',
        providerEventId: 'ms-clear-conflict',
      );
      final detail = (await repository.loadEventDetail(eventId))!;
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(clearLocation: true),
      );
      final queued = await database.select(database.pendingOps).getSingle();
      final request = jsonDecode(queued.requestJson) as Map;
      expect(request['structuredLocation'], {'displayName': ''});
      microsoftClient.remoteEvent = microsoftClient.microsoftEvent(
        'ms-clear-conflict',
        location: {
          ...location,
          'address': {'city': 'Victoria', 'street': '2 Other Street'},
        },
        locations: [
          location,
          {
            'displayName': 'Remote room collection entry',
            'locationEmailAddress': 'room@example.test',
          },
        ],
        updatedAtServer: '2026-06-08T00:05:00.000Z',
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: microsoftClient,
        accountId: 'microsoft-account',
        nowUtc: () => DateTime.utc(2026, 6, 9),
      ).replayDueOps();

      expect(applied, 0);
      expect(microsoftClient.updatedMutations, isEmpty);
      expect(
        (await database.select(database.pendingOps).getSingle()).lastErrorCode,
        'conflict',
      );
    },
  );

  test(
    'Microsoft unrelated title edit preserves a remote structured location',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final microsoftClient = _FakeMicrosoftCalendarClient()
        ..persistEventUpdates = true;
      final repository = CalendarRepository(database: database);
      final baselineLocation = <String, Object?>{
        'displayName': 'Room',
        'coordinates': {'latitude': 1.0, 'longitude': 2.0},
        'address': {'city': 'Original city'},
      };
      await repository.upsertEvent(
        accountId: 'microsoft-account',
        event: microsoftClient.microsoftEvent(
          'ms-title-only',
          location: baselineLocation,
          locations: [baselineLocation],
        ),
      );
      final eventId = CalendarRepository.eventId(
        accountId: 'microsoft-account',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'ms-cal-1',
        providerEventId: 'ms-title-only',
      );
      final detail = (await repository.loadEventDetail(eventId))!;
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(title: 'Local title'),
      );
      final remoteLocation = <String, Object?>{
        'displayName': 'Remote room',
        'coordinates': {'latitude': 3.0, 'longitude': 4.0},
        'address': {'city': 'Remote city'},
        'locationEmailAddress': 'room@example.test',
      };
      microsoftClient.remoteEvent = microsoftClient.microsoftEvent(
        'ms-title-only',
        location: remoteLocation,
        locations: [remoteLocation],
        updatedAtServer: '2026-06-08T00:05:00.000Z',
      );

      expect(
        await CalendarPendingOpsReplayer(
          database: database,
          client: microsoftClient,
          accountId: 'microsoft-account',
          nowUtc: () => DateTime.utc(2026, 6, 9),
        ).replayDueOps(),
        1,
      );

      final mutation = microsoftClient.updatedMutations.single;
      expect(mutation.title, 'Local title');
      expect(mutation.location, isNull);
      expect(mutation.structuredLocation, isNull);
      final saved = (await repository.loadEventDetail(eventId))!;
      expect(saved.location, 'Remote room');
      expect(saved.locationPoint, GeographicPoint(latitude: 3, longitude: 4));
      expect(saved.locationAddress?['city'], 'Remote city');
    },
  );

  test(
    'Microsoft dependent pin replacements rebase the complete state',
    () async {
      await _insertMicrosoftAccountAndSource(database);
      final microsoftClient = _FakeMicrosoftCalendarClient()
        ..persistEventUpdates = true;
      final repository = CalendarRepository(database: database);
      final baselineLocation = <String, Object?>{
        'displayName': 'Same room',
        'coordinates': {'latitude': 1.0, 'longitude': 2.0},
        'address': {'city': 'Base city'},
      };
      final baseline = microsoftClient.microsoftEvent(
        'ms-dependent-locations',
        location: baselineLocation,
        locations: [baselineLocation],
      );
      microsoftClient.remoteEvent = baseline;
      await repository.upsertEvent(
        accountId: 'microsoft-account',
        event: baseline,
      );
      final eventId = CalendarRepository.eventId(
        accountId: 'microsoft-account',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'ms-cal-1',
        providerEventId: 'ms-dependent-locations',
      );
      var detail = (await repository.loadEventDetail(eventId))!;
      final first = LocationResult(
        label: 'Same room',
        point: GeographicPoint(latitude: 3, longitude: 4),
        address: const {'city': 'First city'},
      );
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(
          detail,
        ).copyWith(locationChange: LocationChange.replace(first)),
      );
      detail = (await repository.loadEventDetail(eventId))!;
      final second = LocationResult(
        label: 'Same room',
        point: GeographicPoint(latitude: 5, longitude: 6),
        address: const {'city': 'Second city'},
      );
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(
          detail,
        ).copyWith(locationChange: LocationChange.replace(second)),
      );

      final replayer = CalendarPendingOpsReplayer(
        database: database,
        client: microsoftClient,
        accountId: 'microsoft-account',
        nowUtc: () => DateTime.utc(2026, 6, 9),
      );
      expect(await replayer.replayDueOps(), 2);
      expect(await replayer.replayDueOps(), 0);

      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(
        microsoftClient.updatedMutations.map(
          (mutation) => GeographicPoint.fromJson(
            mutation.structuredLocation?['coordinates'],
          ),
        ),
        [first.point, second.point],
      );
      final saved = (await repository.loadEventDetail(eventId))!;
      expect(saved.locationPoint, second.point);
      expect(saved.locationAddress?['city'], 'Second city');
    },
  );

  test(
    'discarding a rebased blocked edit restores the complete remote event',
    () async {
      final repository = CalendarRepository(
        database: database,
        now: () => DateTime.utc(2026, 6, 8),
      );
      final baseEvent = client._event(
        'provider-event',
        title: 'Base title',
        description: 'Planning description',
        location: 'Base room',
        remindersJson: const {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': 30},
          ],
        },
        organizerJson: const {'self': true},
      );
      await repository.upsertEvent(accountId: 'account', event: baseEvent);
      final eventId = CalendarRepository.eventId(
        accountId: 'account',
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        providerEventId: 'provider-event',
      );

      var detail = await repository.loadEventDetail(eventId);
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(
          detail!,
        ).copyWith(title: 'First local title'),
      );
      detail = await repository.loadEventDetail(eventId);
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(
          detail!,
        ).copyWith(location: 'Second local room'),
      );

      client
        ..persistEventUpdates = true
        ..remoteEvent = client._event(
          'provider-event',
          title: 'Base title',
          description: 'Planning description',
          location: 'Remote room',
          remindersJson: baseEvent.remindersJson,
          organizerJson: baseEvent.organizerJson,
          updatedAtServer: '2026-06-08T00:05:00.000Z',
        );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8, 1),
      ).replayDueOps();

      expect(applied, 1);
      final blocked = await database.select(database.pendingOps).getSingle();
      expect(blocked.lastErrorCode, 'conflict');
      expect(
        (jsonDecode(blocked.baselineRawJson!) as Map).containsKey(
          calendarEventSemanticBaselineKey,
        ),
        isTrue,
      );
      client.getEventError = StateError('Provider temporarily unavailable');
      final failingResolutionService = PendingOpResolutionService(
        database: database,
        calendarClient: client,
        accountId: 'account',
        syncTasks: () async {},
        syncCalendar: () async {},
        nowUtc: () => DateTime.utc(2026, 6, 8),
      );
      await expectLater(
        failingResolutionService.discard(blocked.id),
        throwsA(isA<StateError>()),
      );
      expect(
        await database.pendingOpsDao.getOp(blocked.id),
        isNot(equals(null)),
      );
      expect(
        (await (database.select(
          database.calendarEvents,
        )..where((row) => row.id.equals(eventId))).getSingle()).location,
        'Second local room',
      );
      client.getEventError = null;
      final getCallsBeforeDiscard = client.calls
          .where((call) => call == 'getEvent:cal-1:provider-event')
          .length;
      var calendarSyncCalls = 0;
      final resolutionService = PendingOpResolutionService(
        database: database,
        calendarClient: client,
        accountId: 'account',
        syncTasks: () async {},
        syncCalendar: () async => calendarSyncCalls += 1,
        nowUtc: () => DateTime.utc(2026, 6, 8),
      );

      await resolutionService.discard(blocked.id);

      expect(
        client.calls
            .where((call) => call == 'getEvent:cal-1:provider-event')
            .length,
        getCallsBeforeDiscard + 1,
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(calendarSyncCalls, 1);
      final restored = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(restored.title, 'First local title');
      expect(restored.description, 'Planning description');
      expect(restored.location, 'Remote room');
      expect(restored.startDateTime, '2026-06-08T09:00:00.000Z');
      expect(restored.endDateTime, '2026-06-08T10:00:00.000Z');
      expect(restored.startTimeZone, 'UTC');
      expect(restored.endTimeZone, 'UTC');
      expect(restored.remindersJson, jsonEncode(baseEvent.remindersJson));
      expect(restored.organizerJson, jsonEncode(baseEvent.organizerJson));
      expect(restored.syncStatus, 'synced');
      expect(restored.isDeleted, isFalse);

      final notification = await database
          .select(database.notificationSchedule)
          .getSingle();
      expect(notification.sourceId, eventId);
      expect(notification.title, 'First local title');
      expect(
        notification.scheduledAtUtc,
        DateTime.utc(2026, 6, 8, 8, 30).millisecondsSinceEpoch,
      );
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

  test('entire-series delete marks the master and every occurrence', () async {
    final repository = CalendarRepository(database: database);
    await repository.upsertEvent(
      accountId: 'account',
      event: _googleSeriesMaster(),
    );
    final occurrenceId = await _insertGoogleOccurrence(repository, day: 8);
    await _insertGoogleOccurrence(repository, day: 15);

    await repository.deleteLocalEvent(
      occurrenceId,
      recurringScope: RecurringEventMutationScope.entireSeries,
    );
    await CalendarPendingOpsReplayer(
      database: database,
      client: client,
      accountId: 'account',
      nowUtc: () => DateTime.utc(2026, 6, 8),
    ).replayDueOps();

    expect(client.calls, ['deleteEvent:cal-1:series-master']);
    final rows = await database.select(database.calendarEvents).get();
    expect(rows, hasLength(3));
    expect(rows.map((row) => row.isDeleted), everyElement(isTrue));
    expect(rows.map((row) => row.syncStatus), everyElement('synced'));
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

  test(
    'calendar patch edited in flight remains queued and is replayed',
    () async {
      final repository = CalendarRepository(database: database);
      const sourceId = 'account|google|cal-1';
      await repository.renameLocalSource(sourceId, 'First rename');
      final patchGate = Completer<void>();
      client.calendarPatchGate = patchGate;

      CalendarPendingOpsReplayer replayer() => CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      );

      final firstReplay = replayer().replayDueOps();
      await _waitFor(
        () => client.calls.contains('updateCalendar:cal-1:First rename'),
      );

      await repository.renameLocalSource(sourceId, 'Second rename');
      patchGate.complete();

      expect(await firstReplay, 1);
      final pendingAfterFirst = await database.pendingOpsDao
          .pendingOpsForReplay('account', _later);
      expect(pendingAfterFirst, hasLength(1));
      expect(
        jsonDecode(pendingAfterFirst.single.requestJson),
        containsPair('summary', 'Second rename'),
      );
      expect(
        (await database.select(database.calendarSources).getSingle()).summary,
        'Second rename',
      );

      client.calendarPatchGate = null;
      expect(await replayer().replayDueOps(), 1);

      expect(client.calls, [
        'updateCalendar:cal-1:First rename',
        'updateCalendar:cal-1:Second rename',
      ]);
      expect(
        await database.pendingOpsDao.pendingOpsForReplay('account', _later),
        isEmpty,
      );
      expect(
        (await database.select(database.calendarSources).getSingle()).summary,
        'Second rename',
      );
    },
  );

  test(
    'personal Google calendar patch updates the CalendarList entry',
    () async {
      await database.pendingOpsDao.enqueue(
        PendingOpsCompanion.insert(
          id: 'op-calendar-personal-patch',
          accountId: 'account',
          provider: const Value('google'),
          entityType: 'calendar',
          operation: 'patch',
          operationType: const Value('calendar.patch'),
          calendarSourceId: const Value('account|google|cal-1'),
          providerCalendarId: const Value('cal-1'),
          requestJson:
              '{"summary":"My work","_calendarMutationScope":"personal"}',
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
      expect(client.calls, ['updateCalendarListEntry:cal-1:My work']);
    },
  );

  test(
    'calendar create remaps dependent event work to the server id',
    () async {
      final repository = CalendarRepository(
        database: database,
        now: () => DateTime.utc(2026, 6, 8),
      );
      final temporarySourceId = await repository.createLocalSource(
        accountId: 'account',
        summary: 'Project',
      );
      final temporarySource = await (database.select(
        database.calendarSources,
      )..where((row) => row.id.equals(temporarySourceId))).getSingle();
      await repository.createLocalEvent(
        EventEditorDraft.newEvent(
          accountId: 'account',
          sourceId: temporarySourceId,
          providerCalendarId: temporarySource.providerCalendarId,
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

      expect(applied, 2);
      expect(client.calls, [
        'createCalendar:Project',
        'createEvent:cal-created:Planning',
      ]);
      final sources = await database.select(database.calendarSources).get();
      expect(
        sources.map((source) => source.providerCalendarId),
        containsAll(<String>['cal-1', 'cal-created']),
      );
      expect(sources.any((source) => source.id == temporarySourceId), isFalse);
      final event = await database.select(database.calendarEvents).getSingle();
      expect(event.providerCalendarId, 'cal-created');
      expect(event.calendarSourceId, 'account|google|cal-created');
      expect(
        await database.pendingOpsDao.pendingOpsForReplay('account', _later),
        isEmpty,
      );
    },
  );

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

  test('calendar remove pending op deletes the CalendarList entry', () async {
    await (database.update(
      database.calendarSources,
    )..where((row) => row.id.equals('account|google|cal-1'))).write(
      const CalendarSourcesCompanion(dataOwner: Value('other@example.com')),
    );
    await database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: 'op-calendar-remove',
        accountId: 'account',
        provider: const Value('google'),
        entityType: 'calendar',
        operation: 'remove',
        operationType: const Value('calendar.remove'),
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

    expect(applied, 1);
    expect(client.calls, ['deleteCalendarListEntry:cal-1']);
    expect(
      (await database.select(database.calendarSources).getSingle()).isDeleted,
      isTrue,
    );
  });

  test(
    'calendar color edited in flight remains queued and is replayed',
    () async {
      final repository = CalendarRepository(database: database);
      const sourceId = 'account|google|cal-1';
      final firstColor = googleCalendarColorChoices[0];
      final secondColor = googleCalendarColorChoices[1];
      await repository.setSourceColor(sourceId, firstColor);
      final patchGate = Completer<void>();
      client.calendarPatchGate = patchGate;

      CalendarPendingOpsReplayer replayer() => CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      );

      final firstReplay = replayer().replayDueOps();
      await _waitFor(() => client.calendarMutations.length == 1);

      await repository.setSourceColor(sourceId, secondColor);
      patchGate.complete();

      expect(await firstReplay, 1);
      final pendingAfterFirst = await database.pendingOpsDao
          .pendingOpsForReplay('account', _later);
      expect(pendingAfterFirst, hasLength(1));
      expect(
        jsonDecode(pendingAfterFirst.single.requestJson),
        containsPair('backgroundColor', secondColor.backgroundColor),
      );
      expect(
        (await database.select(database.calendarSources).getSingle())
            .backgroundColor,
        secondColor.backgroundColor,
      );

      client.calendarPatchGate = null;
      expect(await replayer().replayDueOps(), 1);

      expect(
        client.calendarMutations.map((mutation) => mutation.backgroundColor),
        [firstColor.backgroundColor, secondColor.backgroundColor],
      );
      expect(
        await database.pendingOpsDao.pendingOpsForReplay('account', _later),
        isEmpty,
      );
      expect(
        (await database.select(database.calendarSources).getSingle())
            .backgroundColor,
        secondColor.backgroundColor,
      );
    },
  );

  test(
    'Google calendar delete rejected with 403 restores the source',
    () async {
      await (database.update(database.calendarSources)
            ..where((row) => row.id.equals('account|google|cal-1')))
          .write(const CalendarSourcesCompanion(hidden: Value(true)));
      await CalendarRepository(
        database: database,
      ).deleteLocalSource('account|google|cal-1');
      client.calendarDeleteError = const GoogleCalendarApiError(
        statusCode: 403,
        code: 'forbidden',
        message: 'Permission denied',
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      ).replayDueOps();

      final source = await database
          .select(database.calendarSources)
          .getSingle();
      final operation = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(source.isDeleted, isFalse);
      expect(source.hidden, isTrue);
      expect(operation.nextAttemptAtUtc, startsWith('9999-12-31'));
    },
  );

  test(
    'Google CalendarList removal rejected with 403 restores the source',
    () async {
      await (database.update(
        database.calendarSources,
      )..where((row) => row.id.equals('account|google|cal-1'))).write(
        const CalendarSourcesCompanion(dataOwner: Value('other@example.com')),
      );
      await CalendarRepository(
        database: database,
      ).deleteLocalSource('account|google|cal-1');
      client.calendarListDeleteError = const GoogleCalendarApiError(
        statusCode: 403,
        code: 'forbidden',
        message: 'Permission denied',
      );

      final applied = await CalendarPendingOpsReplayer(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 6, 8),
      ).replayDueOps();

      final source = await database
          .select(database.calendarSources)
          .getSingle();
      final operation = await database.select(database.pendingOps).getSingle();
      expect(applied, 0);
      expect(source.isDeleted, isFalse);
      expect(source.hidden, isFalse);
      expect(operation.nextAttemptAtUtc, startsWith('9999-12-31'));
    },
  );

  for (final statusCode in [400, 403]) {
    test(
      'Microsoft calendar delete rejected with $statusCode restores the source',
      () async {
        await _insertMicrosoftAccountAndSource(database, isRemovable: true);
        const sourceId = 'microsoft-account|microsoft|ms-cal-1';
        await CalendarRepository(
          database: database,
        ).deleteLocalSource(sourceId);
        final microsoftClient = _FakeMicrosoftCalendarClient()
          ..calendarDeleteError = MicrosoftCalendarApiError(
            statusCode: statusCode,
            code: 'ErrorAccessDenied',
            message: 'Permission denied',
          );

        final applied = await CalendarPendingOpsReplayer(
          database: database,
          client: microsoftClient,
          accountId: 'microsoft-account',
          nowUtc: () => DateTime.utc(2026, 6, 8),
        ).replayDueOps();

        final source = await (database.select(
          database.calendarSources,
        )..where((row) => row.id.equals(sourceId))).getSingle();
        final operation =
            await (database.select(database.pendingOps)
                  ..where((row) => row.accountId.equals('microsoft-account')))
                .getSingle();
        expect(applied, 0);
        expect(source.isDeleted, isFalse);
        expect(source.hidden, isFalse);
        expect(operation.nextAttemptAtUtc, startsWith('9999-12-31'));
      },
    );
  }

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
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'google-account',
          credentialKind: 'oauth',
          email: const Value('me@example.com'),
          authState: const Value('signed_in'),
          grantedScopes: const Value(''),
          createdAtUtc: '2026-06-08T00:00:00.000Z',
          updatedAtUtc: '2026-06-08T00:00:00.000Z',
        ),
      );
}

Future<void> _insertDestinationGoogleAccount(AppDatabase database) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'destination-account',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'destination-google-account',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          grantedScopes: const Value(''),
          createdAtUtc: '2026-06-08T00:00:00.000Z',
          updatedAtUtc: '2026-06-08T00:00:00.000Z',
        ),
      );
}

Future<void> _insertMicrosoftAccountAndSource(
  AppDatabase database, {
  bool? isRemovable,
}) async {
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'microsoft-account',
          provider: 'microsoft',
          authority: 'https://login.microsoftonline.com/common',
          providerAccountId: 'microsoft-account',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          grantedScopes: const Value(''),
          createdAtUtc: '2026-06-08T00:00:00.000Z',
          updatedAtUtc: '2026-06-08T00:00:00.000Z',
        ),
      );
  await CalendarRepository(database: database).upsertSource(
    accountId: 'microsoft-account',
    source: CalendarSourceDto(
      provider: BusyProvider.microsoft,
      providerCalendarId: 'ms-cal-1',
      summary: 'Outlook',
      timeZone: 'America/Vancouver',
      isRemovable: isRemovable,
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
    provider: BusyProvider.google,
    providerCalendarId: 'cal-1',
    providerEventId: providerEventId,
    providerRecurringEventId: providerRecurringEventId,
    title: 'Base',
    organizerJson: const {'self': true},
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
    provider: BusyProvider.google,
    providerCalendarId: 'cal-1',
    providerEventId: providerEventId,
  );
}

Future<String> _insertGoogleOccurrence(
  CalendarRepository repository, {
  required int day,
  String? start,
  String? end,
  String timeZone = 'UTC',
  String? location,
}) async {
  final date = day.toString().padLeft(2, '0');
  start ??= '2026-06-${date}T09:00:00.000Z';
  end ??= '2026-06-${date}T10:00:00.000Z';
  final providerEventId = 'occurrence-$date';
  await repository.upsertEvent(
    accountId: 'account',
    event: CalendarEventDto(
      provider: BusyProvider.google,
      providerCalendarId: 'cal-1',
      providerEventId: providerEventId,
      providerRecurringEventId: 'series-master',
      providerOriginalStartKey: start,
      title: 'Base',
      location: location,
      organizerJson: const {'self': true},
      startDateTime: start,
      startTimeZone: timeZone,
      endDateTime: end,
      endTimeZone: timeZone,
      updatedAtServer: '2026-05-30T00:00:00.000Z',
      rawJson: {
        'id': providerEventId,
        'summary': 'Base',
        if (location != null) 'location': location,
        'recurringEventId': 'series-master',
        'originalStartTime': {'dateTime': start},
        'start': {'dateTime': start, 'timeZone': timeZone},
        'end': {'dateTime': end, 'timeZone': timeZone},
        'updated': '2026-05-30T00:00:00.000Z',
      },
    ),
  );
  return CalendarRepository.eventId(
    accountId: 'account',
    provider: BusyProvider.google,
    providerCalendarId: 'cal-1',
    providerEventId: providerEventId,
    providerOriginalStartKey: start,
  );
}

Future<void> _insertGoogleSeriesResolution(AppDatabase database) => database
    .into(database.locationResolutions)
    .insert(
      LocationResolutionsCompanion.insert(
        kind: googleSeriesLocationResolutionKind,
        accountId: 'account',
        sourceId: 'account|google|cal-1',
        itemId: 'series-master',
        locationText: 'Room 2',
        label: 'Room 2',
        latitude: 49.2827,
        longitude: -123.1207,
        source: 'ical',
        attribution: 'Imported iCalendar GEO',
      ),
    );

CalendarEventDto _googleSeriesMaster({
  String timeZone = 'UTC',
  String start = '2026-06-01T09:00:00.000Z',
  String end = '2026-06-01T10:00:00.000Z',
  String? location,
}) {
  const recurrence = ['RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=MO;COUNT=5'];
  return CalendarEventDto(
    provider: BusyProvider.google,
    providerCalendarId: 'cal-1',
    providerEventId: 'series-master',
    title: 'Base',
    location: location,
    organizerJson: {'self': true},
    startDateTime: start,
    startTimeZone: timeZone,
    endDateTime: end,
    endTimeZone: timeZone,
    recurrenceJson: recurrence,
    updatedAtServer: '2026-05-30T00:00:00.000Z',
    rawJson: {
      'id': 'series-master',
      'summary': 'Base',
      if (location != null) 'location': location,
      'start': {'dateTime': start, 'timeZone': timeZone},
      'end': {'dateTime': end, 'timeZone': timeZone},
      'recurrence': recurrence,
      'updated': '2026-05-30T00:00:00.000Z',
    },
  );
}

CalendarEventDto _googleSeriesInstance({
  required int day,
  String? id,
  String seriesId = 'series-master',
  String title = 'Base',
  String? location,
  int startHour = 9,
  DateTime? actualStart,
}) {
  final date = day.toString().padLeft(2, '0');
  final originalStart = '2026-06-${date}T09:00:00.000Z';
  final start =
      actualStart?.toIso8601String() ??
      '2026-06-${date}T${startHour.toString().padLeft(2, '0')}:00:00.000Z';
  final end = DateTime.parse(
    start,
  ).add(const Duration(hours: 1)).toIso8601String();
  final eventId = id ?? 'instance-$date';
  return CalendarEventDto(
    provider: BusyProvider.google,
    providerCalendarId: 'cal-1',
    providerEventId: eventId,
    providerRecurringEventId: seriesId,
    providerOriginalStartKey: originalStart,
    title: title,
    location: location,
    organizerJson: const {'self': true},
    startDateTime: start,
    startTimeZone: 'UTC',
    endDateTime: end,
    endTimeZone: 'UTC',
    rawJson: {
      'id': eventId,
      'recurringEventId': seriesId,
      'originalStartTime': {'dateTime': originalStart},
      'summary': title,
      if (location != null) 'location': location,
      'start': {'dateTime': start, 'timeZone': 'UTC'},
      'end': {'dateTime': end, 'timeZone': 'UTC'},
    },
  );
}

List<DateTime> _weeklyOccurrenceStarts(CalendarEventMutation mutation) {
  final recurrence = (mutation.recurrence as List?)
      ?.map((value) => value.toString())
      .firstWhere((value) => value.startsWith('RRULE:'), orElse: () => '');
  final countMatch = RegExp(
    r'(?:^|;)COUNT=(\d+)(?:;|$)',
  ).firstMatch(recurrence ?? '');
  final count = int.parse(countMatch!.group(1)!);
  final start = DateTime.parse(mutation.startDateTime!);
  return List.generate(
    count,
    (index) => start.add(Duration(days: 7 * index)),
    growable: false,
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

String _icalCalendar(String components) =>
    'BEGIN:VCALENDAR\r\n'
    'VERSION:2.0\r\n'
    'PRODID:-//BusyMax Test//EN\r\n'
    '${components.trim().replaceAll('\n', '\r\n')}\r\n'
    'END:VCALENDAR\r\n';

class _FakeCalendarClient
    implements
        CloudCalendarClient,
        CompleteRecurringInstanceClient,
        CalendarListManagementClient {
  final calls = <String>[];
  final createdMutations = <CalendarEventMutation>[];
  final updatedMutations = <CalendarEventMutation>[];
  final calendarMutations = <CalendarMutation>[];
  final guestUpdatePolicies = <CalendarGuestUpdatePolicy>[];
  final invitationResponses = <CalendarInvitationResponse>[];
  final Map<String, CalendarEventDto> _createdEventsByIdentity = {};
  int _createdCount = 0;
  int transientUpdateFailures = 0;
  CalendarEventDto? syncEvent;
  CalendarEventDto? remoteEvent;
  List<CalendarEventDto> eventInstances = const [];
  bool persistEventUpdates = false;
  int _eventUpdateRevision = 0;
  GoogleCalendarApiError? deleteError;
  Object? calendarDeleteError;
  GoogleCalendarApiError? calendarListDeleteError;
  Completer<void>? createEventGate;
  Completer<void>? calendarPatchGate;
  Object? createEventResponseError;
  Object? getEventError;
  CalendarEventDto Function(String calendarId, CalendarEventMutation mutation)?
  createEventOverride;
  List<CalendarEventDto>? syncEventsOverride;

  int get distinctCreatedEventCount => _createdEventsByIdentity.length;

  @override
  BusyProvider get provider => BusyProvider.google;

  @override
  CalendarProviderCapabilities get capabilities =>
      googleCalendarProviderCapabilities;

  @override
  Future<List<CalendarSourceDto>> listCalendars() async {
    calls.add('listCalendars');
    return const [
      CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'cal-1',
        summary: 'Work',
      ),
    ];
  }

  @override
  Future<CalendarEventDto> createEvent({
    required String calendarId,
    required CalendarEventMutation mutation,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    calls.add('createEvent:$calendarId:${mutation.title}');
    createdMutations.add(mutation);
    guestUpdatePolicies.add(guestUpdatePolicy);
    await createEventGate?.future;
    final identity = provider == BusyProvider.google
        ? mutation.providerEventId
        : mutation.transactionId;
    final existing = identity == null
        ? null
        : _createdEventsByIdentity[identity];
    if (existing != null) {
      if (provider == BusyProvider.google) {
        throw const GoogleCalendarApiError(
          statusCode: 409,
          code: 'ALREADY_EXISTS',
          message: 'The requested identifier already exists.',
        );
      }
      return existing;
    }
    _createdCount += 1;
    final event =
        createEventOverride?.call(calendarId, mutation) ??
        _event(
          provider == BusyProvider.google && identity != null
              ? identity
              : 'server-event-$_createdCount',
          title: mutation.title ?? '',
          providerCalendarId: calendarId,
          location: mutation.location,
          startTimeZone: mutation.startTimeZone,
          endTimeZone: mutation.endTimeZone,
        );
    if (identity != null) {
      _createdEventsByIdentity[identity] = event;
    }
    final responseError = createEventResponseError;
    createEventResponseError = null;
    if (responseError != null) throw responseError;
    return event;
  }

  @override
  Future<CalendarEventDto> updateEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    calls.add('updateEvent:$calendarId:$eventId:${mutation.title}');
    updatedMutations.add(mutation);
    guestUpdatePolicies.add(guestUpdatePolicy);
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
      description: persistEventUpdates
          ? mutation.description ?? current?.description
          : mutation.description,
      location: persistEventUpdates
          ? mutation.location ?? current?.location
          : mutation.location,
      remindersJson: persistEventUpdates
          ? mutation.reminders ?? current?.remindersJson
          : mutation.reminders,
      organizerJson: persistEventUpdates ? current?.organizerJson : null,
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
      providerCalendarId: calendarId,
      startDateTime: mutation.startDateTime ?? current?.startDateTime,
      endDateTime: mutation.endDateTime ?? current?.endDateTime,
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
    final error = getEventError;
    if (error != null) throw error;
    for (final created in _createdEventsByIdentity.values) {
      if (created.providerEventId == eventId) return created;
    }
    final remote = remoteEvent;
    if (remote != null) return remote;
    return _event(eventId, title: 'Base');
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String eventId,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    calls.add('deleteEvent:$calendarId:$eventId');
    guestUpdatePolicies.add(guestUpdatePolicy);
    final error = deleteError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<CalendarEventDto> moveEvent({
    required String sourceCalendarId,
    required String eventId,
    required String destinationCalendarId,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    calls.add('moveEvent:$sourceCalendarId:$eventId:$destinationCalendarId');
    guestUpdatePolicies.add(guestUpdatePolicy);
    return _event(
      eventId,
      title: remoteEvent?.title ?? 'Base',
      providerCalendarId: destinationCalendarId,
    );
  }

  @override
  Future<CalendarEventDto?> respondToEvent({
    required String calendarId,
    required String eventId,
    required CalendarInvitationResponse response,
    String? attendeeEmail,
    bool sendResponse = true,
  }) async {
    calls.add('respondToEvent:$calendarId:$eventId:$attendeeEmail');
    invitationResponses.add(response);
    return _event(eventId, title: 'Base');
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
      events:
          syncEventsOverride ??
          [
            if (syncEvent case final event?) event,
            if (_createdCount > 0)
              _event('server-event-$_createdCount', title: 'Planning'),
          ],
    );
  }

  CalendarEventDto _event(
    String id, {
    required String title,
    String providerCalendarId = 'cal-1',
    String? description,
    String? location,
    Object? remindersJson,
    Object? organizerJson,
    String? etagOrChangeKey,
    String updatedAtServer = '2026-06-08T00:00:00.000Z',
    String? startTimeZone,
    String? endTimeZone,
    String? startDateTime,
    String? endDateTime,
  }) {
    return CalendarEventDto(
      provider: provider,
      providerCalendarId: providerCalendarId,
      providerEventId: id,
      etagOrChangeKey: etagOrChangeKey,
      title: title,
      description: description,
      location: location,
      startDateTime: startDateTime ?? '2026-06-08T09:00:00.000Z',
      startTimeZone: startTimeZone ?? 'UTC',
      endDateTime: endDateTime ?? '2026-06-08T10:00:00.000Z',
      endTimeZone: endTimeZone ?? 'UTC',
      remindersJson: remindersJson,
      organizerJson: organizerJson,
      updatedAtServer: updatedAtServer,
      rawJson: {
        'id': id,
        'summary': title,
        if (description != null) 'description': description,
        if (location != null) 'location': location,
        if (etagOrChangeKey != null) 'etag': etagOrChangeKey,
        'start': {
          'dateTime': startDateTime ?? '2026-06-08T09:00:00.000Z',
          'timeZone': startTimeZone ?? 'UTC',
        },
        'end': {
          'dateTime': endDateTime ?? '2026-06-08T10:00:00.000Z',
          'timeZone': endTimeZone ?? 'UTC',
        },
        if (remindersJson != null) 'reminders': remindersJson,
        if (organizerJson != null) 'organizer': organizerJson,
        'updated': updatedAtServer,
      },
    );
  }

  @override
  Future<CalendarSourceDto> createCalendar(CalendarMutation mutation) async {
    calls.add('createCalendar:${mutation.summary}');
    return CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: 'cal-created',
      summary: mutation.summary ?? 'Calendar',
    );
  }

  @override
  Future<void> deleteCalendar(String calendarId) async {
    calls.add('deleteCalendar:$calendarId');
    final error = calendarDeleteError;
    if (error != null) throw error;
  }

  @override
  Future<void> deleteCalendarListEntry(String calendarId) async {
    calls.add('deleteCalendarListEntry:$calendarId');
    final error = calendarListDeleteError;
    if (error != null) throw error;
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
  }) async {
    calls.add('listEventInstances:$calendarId:$recurringEventId');
    return eventInstances
        .where((instance) {
          final start = DateTime.tryParse(
            instance.startDateTime ?? instance.startDate ?? '',
          );
          final end = DateTime.tryParse(
            instance.endDateTime ?? instance.endDate ?? '',
          );
          return start != null &&
              end != null &&
              end.isAfter(rangeStart) &&
              start.isBefore(rangeEnd);
        })
        .toList(growable: false);
  }

  @override
  Future<List<CalendarEventDto>> listAllEventInstances({
    required String calendarId,
    required String recurringEventId,
  }) async {
    calls.add('listAllEventInstances:$calendarId:$recurringEventId');
    return eventInstances;
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
    calendarMutations.add(mutation);
    await calendarPatchGate?.future;
    return CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: calendarId,
      summary: mutation.summary ?? 'Calendar',
      dataOwner: 'me@example.com',
    );
  }

  @override
  Future<CalendarSourceDto> updateCalendarListEntry(
    String calendarId,
    CalendarMutation mutation,
  ) async {
    calls.add('updateCalendarListEntry:$calendarId:${mutation.summary}');
    calendarMutations.add(mutation);
    await calendarPatchGate?.future;
    return CalendarSourceDto(
      provider: BusyProvider.google,
      providerCalendarId: calendarId,
      summary: mutation.summary ?? 'Calendar',
      dataOwner: 'me@example.com',
    );
  }
}

class _FakeMicrosoftCalendarClient extends _FakeCalendarClient {
  @override
  BusyProvider get provider => BusyProvider.microsoft;

  @override
  CalendarProviderCapabilities get capabilities =>
      microsoftCalendarProviderCapabilities;

  @override
  Future<CalendarEventDto> createEvent({
    required String calendarId,
    required CalendarEventMutation mutation,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    calls.add('createEvent:$calendarId:${mutation.title}');
    createdMutations.add(mutation);
    guestUpdatePolicies.add(guestUpdatePolicy);
    await createEventGate?.future;
    final identity = mutation.transactionId;
    final existing = identity == null
        ? null
        : _createdEventsByIdentity[identity];
    if (existing != null) return existing;
    _createdCount += 1;
    final location = mutation.structuredLocation;
    final event = microsoftEvent(
      'server-event-$_createdCount',
      title: mutation.title ?? '',
      location: location,
      locations: location == null ? const [] : [location],
      providerCalendarId: calendarId,
    );
    if (identity != null) _createdEventsByIdentity[identity] = event;
    final responseError = createEventResponseError;
    createEventResponseError = null;
    if (responseError != null) throw responseError;
    return event;
  }

  @override
  Future<CalendarEventDto> updateEvent({
    required String calendarId,
    required String eventId,
    required CalendarEventMutation mutation,
    CalendarGuestUpdatePolicy guestUpdatePolicy =
        CalendarGuestUpdatePolicy.send,
  }) async {
    calls.add('updateEvent:$calendarId:$eventId:${mutation.title}');
    updatedMutations.add(mutation);
    guestUpdatePolicies.add(guestUpdatePolicy);
    final current = remoteEvent;
    final currentRaw = current?.rawJson ?? const <String, Object?>{};
    final currentLocation = currentRaw['location'] is Map
        ? Map<String, Object?>.from(currentRaw['location'] as Map)
        : null;
    final currentLocations = [
      for (final value in currentRaw['locations'] as List? ?? const [])
        if (value is Map) Map<String, Object?>.from(value),
    ];
    final replacement = mutation.structuredLocation;
    final event = microsoftEvent(
      eventId,
      title: mutation.title ?? current?.title ?? '',
      location: replacement ?? currentLocation,
      locations: replacement == null ? currentLocations : [replacement],
      providerCalendarId: calendarId,
      updatedAtServer: DateTime.utc(
        2026,
        6,
        8,
        0,
        ++_eventUpdateRevision + 5,
      ).toIso8601String(),
    );
    if (persistEventUpdates) remoteEvent = event;
    return event;
  }

  CalendarEventDto microsoftEvent(
    String id, {
    String title = 'Base',
    Map<String, Object?>? location,
    List<Map<String, Object?>> locations = const [],
    String providerCalendarId = 'ms-cal-1',
    String updatedAtServer = '2026-06-08T00:00:00.000Z',
  }) {
    return CalendarEventDto(
      provider: BusyProvider.microsoft,
      providerCalendarId: providerCalendarId,
      providerEventId: id,
      title: title,
      location: location?['displayName']?.toString(),
      locationPoint: GeographicPoint.fromJson(location?['coordinates']),
      locationAddress: location?['address'] is Map
          ? Map<String, Object?>.from(location!['address'] as Map)
          : null,
      startDateTime: '2026-06-08T09:00:00.000Z',
      startTimeZone: 'UTC',
      endDateTime: '2026-06-08T10:00:00.000Z',
      endTimeZone: 'UTC',
      updatedAtServer: updatedAtServer,
      rawJson: {
        'id': id,
        'subject': title,
        'start': {'dateTime': '2026-06-08T09:00:00.000Z', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-06-08T10:00:00.000Z', 'timeZone': 'UTC'},
        if (location != null) 'location': location,
        'locations': locations,
        'lastModifiedDateTime': updatedAtServer,
      },
    );
  }
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for condition.');
}
