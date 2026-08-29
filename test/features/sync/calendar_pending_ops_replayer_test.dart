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
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_errors.dart';
import 'package:busymax/src/providers/busy_provider.dart';
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
      expect(client.guestUpdatePolicies.single, CalendarGuestUpdatePolicy.send);
    },
  );

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
    expect(
      deleteRequest[calendarEventCopyDestinationEventIdKey],
      contains('server-event-1'),
    );

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
      'listEventInstances:cal-1:series-master',
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
}) async {
  final date = day.toString().padLeft(2, '0');
  final start = '2026-06-${date}T09:00:00.000Z';
  final end = '2026-06-${date}T10:00:00.000Z';
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
      organizerJson: const {'self': true},
      startDateTime: start,
      startTimeZone: 'UTC',
      endDateTime: end,
      endTimeZone: 'UTC',
      updatedAtServer: '2026-05-30T00:00:00.000Z',
      rawJson: {
        'id': providerEventId,
        'summary': 'Base',
        'recurringEventId': 'series-master',
        'originalStartTime': {'dateTime': start},
        'start': {'dateTime': start, 'timeZone': 'UTC'},
        'end': {'dateTime': end, 'timeZone': 'UTC'},
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

CalendarEventDto _googleSeriesMaster() {
  const start = '2026-06-01T09:00:00.000Z';
  const end = '2026-06-01T10:00:00.000Z';
  const recurrence = ['RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=MO;COUNT=5'];
  return const CalendarEventDto(
    provider: BusyProvider.google,
    providerCalendarId: 'cal-1',
    providerEventId: 'series-master',
    title: 'Base',
    organizerJson: {'self': true},
    startDateTime: start,
    startTimeZone: 'UTC',
    endDateTime: end,
    endTimeZone: 'UTC',
    recurrenceJson: recurrence,
    updatedAtServer: '2026-05-30T00:00:00.000Z',
    rawJson: {
      'id': 'series-master',
      'summary': 'Base',
      'start': {'dateTime': start, 'timeZone': 'UTC'},
      'end': {'dateTime': end, 'timeZone': 'UTC'},
      'recurrence': recurrence,
      'updated': '2026-05-30T00:00:00.000Z',
    },
  );
}

CalendarEventDto _googleSeriesInstance({required int day}) {
  final date = day.toString().padLeft(2, '0');
  final start = '2026-06-${date}T09:00:00.000Z';
  final end = '2026-06-${date}T10:00:00.000Z';
  return CalendarEventDto(
    provider: BusyProvider.google,
    providerCalendarId: 'cal-1',
    providerEventId: 'instance-$date',
    providerRecurringEventId: 'series-master',
    providerOriginalStartKey: start,
    title: 'Base',
    organizerJson: const {'self': true},
    startDateTime: start,
    startTimeZone: 'UTC',
    endDateTime: end,
    endTimeZone: 'UTC',
    rawJson: {
      'id': 'instance-$date',
      'recurringEventId': 'series-master',
      'originalStartTime': {'dateTime': start},
      'start': {'dateTime': start, 'timeZone': 'UTC'},
      'end': {'dateTime': end, 'timeZone': 'UTC'},
    },
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

class _FakeCalendarClient
    implements CloudCalendarClient, CalendarListManagementClient {
  final calls = <String>[];
  final createdMutations = <CalendarEventMutation>[];
  final updatedMutations = <CalendarEventMutation>[];
  final guestUpdatePolicies = <CalendarGuestUpdatePolicy>[];
  final invitationResponses = <CalendarInvitationResponse>[];
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
    _createdCount += 1;
    return _event(
      'server-event-$_createdCount',
      title: mutation.title ?? '',
      providerCalendarId: calendarId,
      startTimeZone: mutation.startTimeZone,
      endTimeZone: mutation.endTimeZone,
    );
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
      providerCalendarId: calendarId,
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
    String providerCalendarId = 'cal-1',
    String? location,
    String? etagOrChangeKey,
    String updatedAtServer = '2026-06-08T00:00:00.000Z',
    String? startTimeZone,
    String? endTimeZone,
  }) {
    return CalendarEventDto(
      provider: BusyProvider.google,
      providerCalendarId: providerCalendarId,
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
}
