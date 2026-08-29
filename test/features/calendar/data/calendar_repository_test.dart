import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/providers/busy_provider.dart';
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
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'g',
            credentialKind: 'oauth',
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
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Original',
      ),
    );
    await repository.setSourceSelected('google:g|google|calendar-1', false);

    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
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
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Hidden at provider',
        selected: false,
      ),
    );

    final source = await database.select(database.calendarSources).getSingle();
    expect(source.selected, isFalse);
  });

  test('provider upsert preserves the local reminder policy', () async {
    await _upsertSource(repository);
    await repository.setSourceRemindersEnabled(_sourceId, false);

    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Updated by provider',
      ),
    );

    final source = await database.select(database.calendarSources).getSingle();
    expect(source.remindersEnabled, isFalse);
  });

  test('source entity exposes the provider primary-calendar flag', () async {
    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Primary calendar',
        primaryCalendar: true,
      ),
    );

    final sources = await repository.watchSourcesForAccounts(const [
      'google:g',
    ]).first;
    expect(sources.single.primaryCalendar, isTrue);
  });

  test('source entity exposes supported conference solutions', () async {
    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Calendar',
        rawJson: {
          'conferenceProperties': {
            'allowedConferenceSolutionTypes': ['hangoutsMeet'],
          },
        },
      ),
    );

    final sources = await repository.watchSourcesForAccounts(const [
      'google:g',
    ]).first;
    expect(sources.single.allowedConferenceSolutions, ['hangoutsMeet']);
  });

  test(
    'event queue preserves guest delivery and Meet creation intent',
    () async {
      await _upsertSource(repository);
      await repository.createLocalEvent(
        _newEventDraft().copyWith(
          title: 'Planning',
          attendees: const [EventAttendeeDraft(email: 'guest@example.com')],
          createConference: true,
          hideAttendees: true,
        ),
        guestUpdatePolicy: CalendarGuestUpdatePolicy.doNotSend,
      );

      final operation = await database.select(database.pendingOps).getSingle();
      final request = jsonDecode(operation.requestJson) as Map<String, Object?>;
      final conference = request['conferenceJson'] as Map<String, Object?>;
      final createRequest = conference['createRequest'] as Map<String, Object?>;
      final event = await database.select(database.calendarEvents).getSingle();

      expect(
        request[calendarEventGuestUpdatePolicyKey],
        CalendarGuestUpdatePolicy.doNotSend.name,
      );
      expect(createRequest['requestId'], isNotEmpty);
      expect(createRequest['conferenceSolutionKey'], {'type': 'hangoutsMeet'});
      expect(jsonDecode(event.conferenceJson!), conference);
      expect(jsonDecode(event.organizerJson!), {'self': true});
      expect(jsonDecode(event.rawJson!), {'guestsCanSeeOtherGuests': false});
    },
  );

  test('local Microsoft event retains advanced meeting settings', () async {
    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'microsoft-calendar',
        summary: 'Work',
      ),
    );
    await repository.createLocalEvent(
      EventEditorDraft.newEvent(
        accountId: 'google:g',
        sourceId: 'google:g|microsoft|microsoft-calendar',
        providerCalendarId: 'microsoft-calendar',
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
      ).copyWith(
        title: 'Planning',
        importance: 'high',
        responseRequested: false,
        hideAttendees: true,
        allowNewTimeProposals: false,
      ),
    );

    final event = await database.select(database.calendarEvents).getSingle();
    expect(jsonDecode(event.rawJson!), {
      'importance': 'high',
      'responseRequested': false,
      'hideAttendees': true,
      'allowNewTimeProposals': false,
      'isOrganizer': true,
    });
  });

  test(
    'editing hydrates full event detail and preserves untouched provider state',
    () async {
      const recurrence = {
        'pattern': {'type': 'weekly', 'interval': 1},
        'range': {'type': 'noEnd', 'startDate': '2026-06-08'},
      };
      const reminders = {
        'isReminderOn': true,
        'reminderMinutesBeforeStart': 20,
      };
      const attendees = [
        {
          'emailAddress': {'address': 'guest@example.com', 'name': 'Guest'},
          'type': 'optional',
          'status': {'response': 'accepted'},
        },
      ];
      const categories = ['Customer', 'Planning'];
      const organizer = {
        'emailAddress': {
          'address': 'organizer@example.com',
          'name': 'Organizer',
        },
      };
      const creator = {
        'emailAddress': {'address': 'creator@example.com', 'name': 'Creator'},
      };
      const conference = {
        'joinUrl': 'https://teams.microsoft.com/l/meetup-join/example',
        'conferenceId': '123 456 789',
      };
      const attachments = [
        {
          'id': 'attachment-1',
          'name': 'Agenda.pdf',
          'contentType': 'application/pdf',
        },
      ];
      const raw = {
        'id': 'event-1',
        'body': {'contentType': 'html', 'content': '<p>Full meeting notes</p>'},
        'isOrganizer': false,
        'responseStatus': {'response': 'tentativelyAccepted'},
        'importance': 'high',
        'responseRequested': false,
        'hideAttendees': true,
        'allowNewTimeProposals': false,
        'providerOnlyField': {'preserve': true},
      };

      await repository.upsertSource(
        accountId: 'google:g',
        source: const CalendarSourceDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: 'microsoft-calendar',
          summary: 'Work',
          timeZone: 'Pacific Standard Time',
        ),
      );
      await repository.upsertEvent(
        accountId: 'google:g',
        event: const CalendarEventDto(
          provider: BusyProvider.microsoft,
          providerCalendarId: 'microsoft-calendar',
          providerEventId: 'event-1',
          providerRecurringEventId: 'series-1',
          providerOriginalStartKey: '2026-06-08T09:30:00.000',
          etagOrChangeKey: 'change-key-1',
          status: 'confirmed',
          title: 'Planning',
          description: 'Full meeting notes',
          location: 'Conference room 4',
          startDateTime: '2026-06-08T09:30:00.000',
          startTimeZone: 'Pacific Standard Time',
          endDateTime: '2026-06-08T10:30:00.000',
          endTimeZone: 'Pacific Standard Time',
          recurrenceJson: recurrence,
          remindersJson: reminders,
          attendeesJson: attendees,
          categoriesJson: categories,
          organizerJson: organizer,
          creatorJson: creator,
          colorId: 'category-color-1',
          colorHex: '#336699',
          visibility: 'private',
          transparencyOrShowAs: 'tentative',
          eventType: 'seriesMaster',
          webLink: 'https://outlook.office.com/calendar/item/event-1',
          conferenceJson: conference,
          attachmentsJson: attachments,
          createdAtServer: '2026-06-01T12:00:00.000Z',
          updatedAtServer: '2026-06-02T12:00:00.000Z',
          rawJson: raw,
        ),
      );
      final eventId = CalendarRepository.eventId(
        accountId: 'google:g',
        provider: BusyProvider.microsoft,
        providerCalendarId: 'microsoft-calendar',
        providerEventId: 'event-1',
        providerOriginalStartKey: '2026-06-08T09:30:00.000',
      );
      final before = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();

      final detail = await repository.loadEventDetail(eventId);
      expect(detail == null, isFalse);
      expect(
        detail!.webLink,
        'https://outlook.office.com/calendar/item/event-1',
      );
      expect(detail.attachments, attachments);
      expect(detail.creator, creator);
      expect(detail.baselineRaw, raw);

      final draft = EventEditorDraft.fromEventDetail(detail);
      expect(draft.start, DateTime(2026, 6, 8, 9, 30));
      expect(draft.end, DateTime(2026, 6, 8, 10, 30));
      expect(draft.startTimeZone, 'Pacific Standard Time');
      expect(draft.endTimeZone, 'Pacific Standard Time');
      expect(draft.description, 'Full meeting notes');
      expect(draft.descriptionContentType, 'html');
      expect(draft.descriptionHtml, '<p>Full meeting notes</p>');
      expect(draft.recurrence, recurrence);
      expect(draft.reminders, reminders);
      expect(draft.attendees.single.email, 'guest@example.com');
      expect(draft.attendees.single.optional, isTrue);
      expect(draft.attendees.single.responseStatus, 'accepted');
      expect(draft.importance, 'high');
      expect(draft.showAs, 'tentative');
      expect(draft.visibilityOrSensitivity, 'private');
      expect(draft.colorId, 'category-color-1');
      expect(draft.categories, categories);
      expect(draft.conference, conference);
      expect(draft.responseRequested, isFalse);
      expect(draft.hideAttendees, isTrue);
      expect(draft.allowNewTimeProposals, isFalse);
      expect(draft.isOrganizer, isFalse);

      await repository.updateLocalEvent(draft.copyWith(title: 'Updated'));

      final after = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(after.title, 'Updated');
      expect(_untouchedEventState(after), _untouchedEventState(before));
    },
  );

  test('local attendee state retains provider response metadata', () async {
    await _upsertSource(repository);
    await repository.upsertEvent(
      accountId: 'google:g',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        providerEventId: 'event-1',
        title: 'Planning',
        organizerJson: {'email': 'me@example.com', 'self': true},
        attendeesJson: [
          {
            'email': 'me@example.com',
            'self': true,
            'organizer': true,
            'responseStatus': 'accepted',
          },
          {'email': 'guest@example.com', 'responseStatus': 'needsAction'},
        ],
        rawJson: {'id': 'event-1'},
      ),
    );
    final eventId = CalendarRepository.eventId(
      accountId: 'google:g',
      provider: BusyProvider.google,
      providerCalendarId: 'calendar-1',
      providerEventId: 'event-1',
    );

    await repository.updateLocalEvent(
      EventEditorDraft.existing(
        eventId: eventId,
        accountId: 'google:g',
        sourceId: _sourceId,
        providerCalendarId: 'calendar-1',
        title: 'Planning',
        allDay: false,
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
        isOrganizer: true,
        attendees: const [
          EventAttendeeDraft(
            email: 'me@example.com',
            self: true,
            organizer: true,
            responseStatus: 'accepted',
          ),
          EventAttendeeDraft(
            email: 'guest@example.com',
            optional: true,
            responseStatus: 'needsAction',
          ),
        ],
      ).copyWith(attendeesChanged: true),
    );

    final event = await (database.select(
      database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    final localAttendees = jsonDecode(event.attendeesJson!) as List<Object?>;
    final localSelf = (localAttendees.first as Map).cast<String, Object?>();
    final operation = await database.select(database.pendingOps).getSingle();
    final request = jsonDecode(operation.requestJson) as Map<String, Object?>;
    final requestAttendees = request[calendarEventAttendeesField] as List;
    final requestSelf = (requestAttendees.first as Map).cast<String, Object?>();

    expect(localSelf, containsPair('self', true));
    expect(localSelf, containsPair('organizer', true));
    expect(localSelf, containsPair('responseStatus', 'accepted'));
    expect(requestSelf, isNot(contains('self')));
    expect(requestSelf, isNot(contains('organizer')));
  });

  test('Google RSVP is optimistic and queued with the self attendee', () async {
    await _upsertSource(repository);
    await repository.upsertEvent(
      accountId: 'google:g',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        providerEventId: 'event-1',
        title: 'Invitation',
        attendeesJson: [
          {
            'email': 'me@example.com',
            'self': true,
            'responseStatus': 'needsAction',
          },
          {'email': 'guest@example.com', 'responseStatus': 'accepted'},
        ],
        rawJson: {'id': 'event-1'},
      ),
    );
    final eventId = CalendarRepository.eventId(
      accountId: 'google:g',
      provider: BusyProvider.google,
      providerCalendarId: 'calendar-1',
      providerEventId: 'event-1',
    );

    await repository.respondToLocalEvent(
      eventId,
      CalendarInvitationResponse.accept,
    );

    final event = await (database.select(
      database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    final attendees = jsonDecode(event.attendeesJson!) as List<Object?>;
    final self = (attendees.first as Map).cast<String, Object?>();
    final operation = await database.select(database.pendingOps).getSingle();
    final request = jsonDecode(operation.requestJson) as Map<String, Object?>;

    expect(self['responseStatus'], 'accepted');
    expect(operation.operationType, 'event.respond');
    expect(request, {
      'response': 'accept',
      'attendeeEmail': 'me@example.com',
      'sendResponse': true,
    });
  });

  test('provider upsert cannot resurrect a locally deleted source', () async {
    await _upsertSource(repository);
    await repository.deleteLocalSource(_sourceId);

    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
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
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Calendar',
        hidden: true,
      ),
    );

    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        summary: 'Calendar',
        hidden: false,
      ),
    );

    final source = await database.select(database.calendarSources).getSingle();
    expect(source.hidden, isFalse);
  });

  test('deselecting a source leaves its reminders enabled', () async {
    await _seedScheduledEvent(repository, database);
    schedulerCalls = 0;

    await repository.setSourceSelected(_sourceId, false);

    expect(
      await database.select(database.notificationSchedule).get(),
      hasLength(1),
    );
    expect(schedulerCalls, 0);
  });

  test('disabling source reminders removes its scheduled reminders', () async {
    await _seedScheduledEvent(repository, database);
    schedulerCalls = 0;

    await repository.setSourceRemindersEnabled(_sourceId, false);

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
          provider: BusyProvider.google,
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
      provider: BusyProvider.google,
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

Object _untouchedEventState(CalendarEvent event) {
  return (
    id: event.id,
    accountId: event.accountId,
    calendarSourceId: event.calendarSourceId,
    provider: event.provider,
    providerCalendarId: event.providerCalendarId,
    providerEventId: event.providerEventId,
    davCollectionId: event.davCollectionId,
    davObjectId: event.davObjectId,
    davComponentId: event.davComponentId,
    icalUid: event.icalUid,
    recurrenceIdKey: event.recurrenceIdKey,
    occurrenceKey: event.occurrenceKey,
    projectionVersion: event.projectionVersion,
    providerRecurringEventId: event.providerRecurringEventId,
    providerOriginalStartKey: event.providerOriginalStartKey,
    etagOrChangeKey: event.etagOrChangeKey,
    status: event.status,
    description: event.description,
    location: event.location,
    allDay: event.allDay,
    startDate: event.startDate,
    startDateTime: event.startDateTime,
    startTimeZone: event.startTimeZone,
    endDate: event.endDate,
    endDateTime: event.endDateTime,
    endTimeZone: event.endTimeZone,
    recurrenceJson: event.recurrenceJson,
    remindersJson: event.remindersJson,
    attendeesJson: event.attendeesJson,
    categoriesJson: event.categoriesJson,
    organizerJson: event.organizerJson,
    creatorJson: event.creatorJson,
    colorId: event.colorId,
    colorHex: event.colorHex,
    visibility: event.visibility,
    transparencyOrShowAs: event.transparencyOrShowAs,
    eventType: event.eventType,
    webLink: event.webLink,
    conferenceJson: event.conferenceJson,
    attachmentsJson: event.attachmentsJson,
    isCancelled: event.isCancelled,
    isDeleted: event.isDeleted,
    rawJson: event.rawJson,
    createdAtServer: event.createdAtServer,
    updatedAtServer: event.updatedAtServer,
    createdAtLocal: event.createdAtLocal,
    baselineRawJson: event.baselineRawJson,
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
