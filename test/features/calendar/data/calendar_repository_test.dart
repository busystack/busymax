import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_colors.dart';
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
            email: const Value('me@example.com'),
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
    'calendar creation is optimistic and queued for offline replay',
    () async {
      final sourceId = await repository.createLocalSource(
        accountId: 'google:g',
        summary: 'Project',
      );

      final source = await database
          .select(database.calendarSources)
          .getSingle();
      final operation = await database.select(database.pendingOps).getSingle();
      expect(source.id, sourceId);
      expect(source.providerCalendarId, startsWith('local:'));
      expect(source.summary, 'Project');
      expect(operation.operationType, 'calendar.create');
      expect(operation.calendarSourceId, sourceId);
      expect(operation.providerCalendarId, source.providerCalendarId);
      expect(jsonDecode(operation.requestJson), {'summary': 'Project'});
      final entity = (await repository.watchSourcesForAccounts(const [
        'google:g',
      ]).first).single;
      expect(entity.pendingCreate, isTrue);
      expect(entity.capabilities.renameMode, CalendarRenameMode.global);
      expect(entity.capabilities.canRemoveCalendar, isTrue);
    },
  );

  test('event creation waits for its locally created calendar', () async {
    final sourceId = await repository.createLocalSource(
      accountId: 'google:g',
      summary: 'Project',
    );
    final source = await database.select(database.calendarSources).getSingle();
    final calendarCreate = await database
        .select(database.pendingOps)
        .getSingle();

    await repository.createLocalEvent(
      EventEditorDraft.newEvent(
        accountId: 'google:g',
        sourceId: sourceId,
        providerCalendarId: source.providerCalendarId,
        start: DateTime.utc(2026, 6, 8, 9),
        end: DateTime.utc(2026, 6, 8, 10),
      ).copyWith(title: 'Planning'),
    );

    final operations = await database.select(database.pendingOps).get();
    final eventCreate = operations.singleWhere(
      (operation) => operation.operationType == 'event.create',
    );
    expect(eventCreate.dependsOnOpId, calendarCreate.id);
  });

  test('renaming an unsynced calendar updates its create operation', () async {
    final sourceId = await repository.createLocalSource(
      accountId: 'google:g',
      summary: 'Initial name',
    );

    await repository.renameLocalSource(sourceId, 'Final name');

    final source = await database.select(database.calendarSources).getSingle();
    final operation = await database.select(database.pendingOps).getSingle();
    expect(source.summary, 'Final name');
    expect(operation.operationType, 'calendar.create');
    expect(jsonDecode(operation.requestJson), {'summary': 'Final name'});
  });

  test('calendar color is projected locally and queued by provider', () async {
    await _upsertSource(repository);
    const choice = CalendarColorChoice(
      providerValue: '#3584e4',
      backgroundColor: '#3584e4',
    );

    await repository.setSourceColor(_sourceId, choice);

    final source = await database.select(database.calendarSources).getSingle();
    final operation = await database.select(database.pendingOps).getSingle();
    expect(source.backgroundColor, '#3584e4');
    expect(source.foregroundColor, '#000000');
    expect(source.colorId, null);
    expect(operation.operationType, 'calendar.patch');
    expect(jsonDecode(operation.requestJson), {
      'backgroundColor': '#3584e4',
      'foregroundColor': '#000000',
      calendarMutationScopeKey: calendarMutationScopePersonal,
      calendarPatchPreviousValuesKey: {
        'backgroundColor': null,
        'foregroundColor': null,
        'colorId': null,
      },
    });
  });

  test('deleting an unsynced calendar cancels its pending work', () async {
    final sourceId = await repository.createLocalSource(
      accountId: 'google:g',
      summary: 'Temporary',
    );

    await repository.deleteLocalSource(sourceId);

    expect(await database.select(database.calendarSources).get(), isEmpty);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test(
    'calendar removal waits for pending event mutations without losing them',
    () async {
      await _upsertSource(repository);
      await repository.createLocalEvent(
        _newEventDraft().copyWith(title: 'Pending event'),
      );
      final pendingBefore = await database.select(database.pendingOps).get();

      await expectLater(
        repository.deleteLocalSource(_sourceId),
        throwsA(
          isA<CalendarMutationNotAllowed>()
              .having(
                (error) => error.operation,
                'operation',
                CalendarMutationOperation.deleteCalendar,
              )
              .having(
                (error) => error.reason,
                'reason',
                CalendarMutationDenialReason.pendingChanges,
              ),
        ),
      );

      final source = await database
          .select(database.calendarSources)
          .getSingle();
      final event = await database.select(database.calendarEvents).getSingle();
      final pendingAfter = await database.select(database.pendingOps).get();
      expect(source.isDeleted, isFalse);
      expect(source.hidden, isFalse);
      expect(event.syncStatus, 'pending');
      expect(
        pendingAfter.map((operation) => operation.id),
        pendingBefore.map((operation) => operation.id),
      );
      expect(pendingAfter.single.operationType, 'event.create');
    },
  );

  test('DAV calendar management is rejected before local mutation', () async {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'nextcloud:n',
            provider: 'nextcloud',
            authority: 'https://cloud.example.test',
            providerAccountId: 'n',
            credentialKind: 'nextcloud_app_password',
            authState: const Value('signed_in'),
            grantedScopes: const Value(''),
            createdAtUtc: '2026-06-08T00:00:00.000Z',
            updatedAtUtc: '2026-06-08T00:00:00.000Z',
          ),
        );
    await expectLater(
      repository.createLocalSource(
        accountId: 'nextcloud:n',
        summary: 'New calendar',
      ),
      throwsA(
        isA<CalendarMutationNotAllowed>().having(
          (error) => error.operation,
          'operation',
          CalendarMutationOperation.createCalendar,
        ),
      ),
    );
    await repository.upsertSource(
      accountId: 'nextcloud:n',
      source: const CalendarSourceDto(
        provider: BusyProvider.nextcloud,
        providerCalendarId: '/calendars/n/work/',
        summary: 'Work',
      ),
    );
    final source = await database.select(database.calendarSources).getSingle();

    await expectLater(
      repository.renameLocalSource(source.id, 'Renamed'),
      throwsA(
        isA<CalendarMutationNotAllowed>().having(
          (error) => error.operation,
          'operation',
          CalendarMutationOperation.renameCalendar,
        ),
      ),
    );
    await expectLater(
      repository.deleteLocalSource(source.id),
      throwsA(
        isA<CalendarMutationNotAllowed>().having(
          (error) => error.operation,
          'operation',
          CalendarMutationOperation.deleteCalendar,
        ),
      ),
    );

    final unchanged = await database
        .select(database.calendarSources)
        .getSingle();
    expect(unchanged.summary, 'Work');
    expect(unchanged.isDeleted, isFalse);
    expect(await database.select(database.pendingOps).get(), isEmpty);
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

      await repository.updateLocalEvent(
        draft.copyWith(
          title: 'Updated',
          recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
        ),
      );

      final after = await (database.select(
        database.calendarEvents,
      )..where((row) => row.id.equals(eventId))).getSingle();
      expect(after.title, 'Updated');
      expect(_untouchedEventState(after), _untouchedEventState(before));
    },
  );

  test(
    'Google invitation edit permissions are enforced before mutation',
    () async {
      await _upsertSource(repository);
      await repository.upsertEvent(
        accountId: 'google:g',
        event: const CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'calendar-1',
          providerEventId: 'invitation',
          title: 'Invitation',
          startDateTime: '2026-06-08T09:00:00-07:00',
          endDateTime: '2026-06-08T10:00:00-07:00',
          organizerJson: {'email': 'owner@example.com', 'self': false},
          attendeesJson: [
            {
              'email': 'me@example.com',
              'self': true,
              'responseStatus': 'needsAction',
            },
          ],
          rawJson: {'id': 'invitation'},
        ),
      );
      final eventId = CalendarRepository.eventId(
        accountId: 'google:g',
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        providerEventId: 'invitation',
      );
      final detail = await repository.loadEventDetail(eventId);

      await expectLater(
        repository.updateLocalEvent(
          EventEditorDraft.fromEventDetail(
            detail!,
          ).copyWith(title: 'Unauthorized edit'),
        ),
        throwsA(isA<CalendarMutationNotAllowed>()),
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect((await repository.loadEventDetail(eventId))!.title, 'Invitation');

      await repository.respondToLocalEvent(
        eventId,
        CalendarInvitationResponse.accept,
      );
      final responseOp = await database.select(database.pendingOps).getSingle();
      expect(responseOp.operationType, 'event.respond');
    },
  );

  test(
    'Google guest event editing does not grant attendee management',
    () async {
      await _upsertSource(repository);
      await repository.upsertEvent(
        accountId: 'google:g',
        event: const CalendarEventDto(
          provider: BusyProvider.google,
          providerCalendarId: 'calendar-1',
          providerEventId: 'guest-editable',
          title: 'Shared planning',
          startDateTime: '2026-06-08T09:00:00-07:00',
          endDateTime: '2026-06-08T10:00:00-07:00',
          organizerJson: {'email': 'owner@example.com', 'self': false},
          attendeesJson: [
            {'email': 'me@example.com', 'self': true},
          ],
          rawJson: {
            'id': 'guest-editable',
            'guestsCanModify': true,
            'guestsCanInviteOthers': false,
          },
        ),
      );
      final eventId = CalendarRepository.eventId(
        accountId: 'google:g',
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        providerEventId: 'guest-editable',
      );
      final detail = await repository.loadEventDetail(eventId);
      final draft = EventEditorDraft.fromEventDetail(detail!);

      expect(detail.guestsCanInviteOthers, isFalse);
      expect(draft.canManageAttendees, isFalse);
      await expectLater(
        repository.updateLocalEvent(
          draft.copyWith(
            attendees: const [
              EventAttendeeDraft(email: 'me@example.com', self: true),
              EventAttendeeDraft(email: 'new@example.com'),
            ],
          ),
        ),
        throwsA(isA<CalendarMutationNotAllowed>()),
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);

      await repository.updateLocalEvent(
        draft.copyWith(title: 'Allowed title edit'),
      );
      expect(
        (await repository.loadEventDetail(eventId))!.title,
        'Allowed title edit',
      );
    },
  );

  test('title-only recurring Google edit preserves explicit UTC', () async {
    await _upsertSource(repository);
    const recurrence = ['RRULE:FREQ=WEEKLY;BYDAY=MO'];
    await repository.upsertEvent(
      accountId: 'google:g',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        providerEventId: 'utc-series',
        title: 'UTC series',
        startDateTime: '2026-06-08T09:00:00Z',
        startTimeZone: 'UTC',
        endDateTime: '2026-06-08T10:00:00Z',
        endTimeZone: 'UTC',
        recurrenceJson: recurrence,
        organizerJson: {'self': true},
        updatedAtServer: '2026-06-01T00:00:00Z',
        rawJson: {
          'id': 'utc-series',
          'summary': 'UTC series',
          'start': {'dateTime': '2026-06-08T09:00:00Z', 'timeZone': 'UTC'},
          'end': {'dateTime': '2026-06-08T10:00:00Z', 'timeZone': 'UTC'},
          'recurrence': recurrence,
          'organizer': {'self': true},
          'updated': '2026-06-01T00:00:00Z',
        },
      ),
    );
    final eventId = CalendarRepository.eventId(
      accountId: 'google:g',
      provider: BusyProvider.google,
      providerCalendarId: 'calendar-1',
      providerEventId: 'utc-series',
    );
    final detail = await repository.loadEventDetail(eventId);

    await repository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail!).copyWith(title: 'Renamed'),
    );

    final event = await (database.select(
      database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    final operation = await database.select(database.pendingOps).getSingle();
    final request = jsonDecode(operation.requestJson) as Map<String, Object?>;
    expect(request, {
      'title': 'Renamed',
      calendarEventGuestUpdatePolicyKey: 'send',
    });
    expect(event.startDateTime, '2026-06-08T09:00:00Z');
    expect(event.endDateTime, '2026-06-08T10:00:00Z');
    expect(event.startTimeZone, 'UTC');
    expect(event.endTimeZone, 'UTC');
    expect(event.recurrenceJson, jsonEncode(recurrence));
  });

  test('title-only Google edit preserves offset-only timestamps', () async {
    await _upsertSource(repository);
    await repository.upsertEvent(
      accountId: 'google:g',
      event: const CalendarEventDto(
        provider: BusyProvider.google,
        providerCalendarId: 'calendar-1',
        providerEventId: 'offset-event',
        title: 'Offset event',
        startDateTime: '2026-06-08T09:00:00+02:00',
        endDateTime: '2026-06-08T10:00:00+02:00',
        organizerJson: {'self': true},
        updatedAtServer: '2026-06-01T00:00:00Z',
        rawJson: {
          'id': 'offset-event',
          'summary': 'Offset event',
          'start': {'dateTime': '2026-06-08T09:00:00+02:00'},
          'end': {'dateTime': '2026-06-08T10:00:00+02:00'},
          'organizer': {'self': true},
          'updated': '2026-06-01T00:00:00Z',
        },
      ),
    );
    final eventId = CalendarRepository.eventId(
      accountId: 'google:g',
      provider: BusyProvider.google,
      providerCalendarId: 'calendar-1',
      providerEventId: 'offset-event',
    );
    final detail = await repository.loadEventDetail(eventId);

    await repository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail!).copyWith(title: 'Renamed'),
    );

    final event = await (database.select(
      database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    final operation = await database.select(database.pendingOps).getSingle();
    final request = jsonDecode(operation.requestJson) as Map<String, Object?>;
    expect(request.keys, {'title', calendarEventGuestUpdatePolicyKey});
    expect(event.startDateTime, '2026-06-08T09:00:00+02:00');
    expect(event.endDateTime, '2026-06-08T10:00:00+02:00');
    expect(event.startTimeZone, equals(null));
    expect(event.endTimeZone, equals(null));
  });

  test('title-only Microsoft edit omits structured location', () async {
    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'microsoft-calendar',
        summary: 'Outlook',
      ),
    );
    const raw = {
      'id': 'structured-location',
      'subject': 'Site visit',
      'location': {
        'displayName': 'Main office',
        'locationType': 'businessAddress',
        'address': {
          'street': '1 Example Street',
          'city': 'Vancouver',
          'countryOrRegion': 'Canada',
        },
        'coordinates': {'latitude': 49.2827, 'longitude': -123.1207},
      },
      'start': {
        'dateTime': '2026-06-08T09:00:00',
        'timeZone': 'Pacific Standard Time',
      },
      'end': {
        'dateTime': '2026-06-08T10:00:00',
        'timeZone': 'Pacific Standard Time',
      },
      'updated': '2026-06-01T00:00:00Z',
    };
    await repository.upsertEvent(
      accountId: 'google:g',
      event: const CalendarEventDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'microsoft-calendar',
        providerEventId: 'structured-location',
        title: 'Site visit',
        location: 'Main office',
        startDateTime: '2026-06-08T09:00:00',
        startTimeZone: 'Pacific Standard Time',
        endDateTime: '2026-06-08T10:00:00',
        endTimeZone: 'Pacific Standard Time',
        updatedAtServer: '2026-06-01T00:00:00Z',
        rawJson: raw,
      ),
    );
    final eventId = CalendarRepository.eventId(
      accountId: 'google:g',
      provider: BusyProvider.microsoft,
      providerCalendarId: 'microsoft-calendar',
      providerEventId: 'structured-location',
    );
    final detail = await repository.loadEventDetail(eventId);

    await repository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail!).copyWith(title: 'Renamed'),
    );

    final event = await (database.select(
      database.calendarEvents,
    )..where((row) => row.id.equals(eventId))).getSingle();
    final operation = await database.select(database.pendingOps).getSingle();
    final request = jsonDecode(operation.requestJson) as Map<String, Object?>;
    expect(request, {
      'title': 'Renamed',
      calendarEventGuestUpdatePolicyKey: 'send',
    });
    expect(event.location, 'Main office');
    expect(jsonDecode(event.rawJson!), raw);
  });

  test(
    'entire-series edit targets the master and projects every occurrence',
    () async {
      await _upsertSource(repository);
      final eventIds = <String>[];
      for (final day in [1, 8, 15]) {
        eventIds.add(await _upsertGoogleOccurrence(repository, day: day));
      }
      final detail = await repository.loadEventDetail(eventIds[1]);

      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail!).copyWith(
          title: 'Renamed series',
          recurringMutationScope: RecurringEventMutationScope.entireSeries,
        ),
      );

      final rows =
          await (database.select(database.calendarEvents)..orderBy([
                (row) => OrderingTerm.asc(row.providerOriginalStartKey),
              ]))
              .get();
      expect(rows.map((row) => row.title), everyElement('Renamed series'));
      expect(rows.map((row) => row.syncStatus), everyElement('pending'));
      final operation = await database.select(database.pendingOps).getSingle();
      final request = jsonDecode(operation.requestJson) as Map<String, Object?>;
      expect(request, {
        calendarEventGuestUpdatePolicyKey: 'send',
        'title': 'Renamed series',
        calendarEventRecurringScopeKey: 'entireSeries',
        calendarEventTargetProviderIdKey: 'series-master',
        calendarEventOriginalStartKey: '2026-06-08T09:00:00.000Z',
        calendarEventOriginalEndKey: '2026-06-08T10:00:00.000Z',
      });
      expect(operation.baselineUpdatedUtc, equals(null));
      expect(operation.baselineRawJson, equals(null));
    },
  );

  test(
    'this-and-following edit projects only the target and later rows',
    () async {
      await _upsertSource(repository);
      final eventIds = <String>[];
      for (final day in [1, 8, 15]) {
        eventIds.add(await _upsertGoogleOccurrence(repository, day: day));
      }
      final detail = await repository.loadEventDetail(eventIds[1]);

      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail!).copyWith(
          location: 'New room',
          recurringMutationScope: RecurringEventMutationScope.thisAndFuture,
        ),
      );

      final rows =
          await (database.select(database.calendarEvents)..orderBy([
                (row) => OrderingTerm.asc(row.providerOriginalStartKey),
              ]))
              .get();
      expect(rows.map((row) => row.location), [null, 'New room', 'New room']);
      expect(rows.map((row) => row.syncStatus), [
        'synced',
        'pending',
        'pending',
      ]);
      final operation = await database.select(database.pendingOps).getSingle();
      final request = jsonDecode(operation.requestJson) as Map<String, Object?>;
      expect(request[calendarEventRecurringScopeKey], 'thisAndFuture');
      expect(request[calendarEventTargetProviderIdKey], 'series-master');
      expect(request['location'], 'New room');
      expect(request, isNot(contains('start')));
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

  test(
    'provider upsert restores a source after removal work is gone',
    () async {
      await _upsertSource(repository);
      await repository.deleteLocalSource(_sourceId);
      final operation = await database.select(database.pendingOps).getSingle();
      expect(jsonDecode(operation.requestJson), {
        calendarRemovalPreviousHiddenKey: false,
      });
      await database.pendingOpsDao.deleteOp(operation.id);

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

      final source = await database
          .select(database.calendarSources)
          .getSingle();
      expect(source.hidden, isFalse);
      expect(source.isDeleted, isFalse);
    },
  );

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

  test('shared Google calendar removal queues CalendarList deletion', () async {
    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: BusyProvider.google,
        providerCalendarId: 'shared@example.com',
        summary: 'Shared',
        readOnly: true,
        dataOwner: 'owner@example.com',
      ),
    );
    const sourceId = 'google:g|google|shared@example.com';

    await repository.deleteLocalSource(sourceId);

    final operation = await database.select(database.pendingOps).getSingle();
    expect(operation.operation, 'remove');
    expect(operation.operationType, 'calendar.remove');
    expect(operation.providerCalendarId, 'shared@example.com');
  });

  test(
    'shared read-only Google calendar uses personal name and color updates',
    () async {
      await repository.upsertSource(
        accountId: 'google:g',
        source: const CalendarSourceDto(
          provider: BusyProvider.google,
          providerCalendarId: 'shared@example.com',
          summary: 'Shared',
          readOnly: true,
          dataOwner: 'owner@example.com',
        ),
      );
      const sourceId = 'google:g|google|shared@example.com';

      await repository.renameLocalSource(sourceId, 'My shared calendar');
      await repository.setSourceColor(
        sourceId,
        calendarColorChoices(BusyProvider.google).first,
      );

      final operation = await database.select(database.pendingOps).getSingle();
      final request = jsonDecode(operation.requestJson) as Map<String, Object?>;
      expect(request['summary'], 'My shared calendar');
      expect(request[calendarMutationScopeKey], calendarMutationScopePersonal);
      expect(request['backgroundColor'], isA<String>());
    },
  );

  test('Microsoft calendar deletion requires isRemovable', () async {
    await repository.upsertSource(
      accountId: 'google:g',
      source: const CalendarSourceDto(
        provider: BusyProvider.microsoft,
        providerCalendarId: 'not-removable',
        summary: 'Editable shared calendar',
        readOnly: false,
        isRemovable: false,
      ),
    );

    await expectLater(
      repository.deleteLocalSource('google:g|microsoft|not-removable'),
      throwsA(isA<CalendarMutationNotAllowed>()),
    );
    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(
      (await database.select(database.calendarSources).getSingle()).isDeleted,
      isFalse,
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
      dataOwner: 'me@example.com',
    ),
  );
}

Future<String> _upsertGoogleOccurrence(
  CalendarRepository repository, {
  required int day,
}) async {
  final date = day.toString().padLeft(2, '0');
  final start = '2026-06-${date}T09:00:00.000Z';
  final end = '2026-06-${date}T10:00:00.000Z';
  final providerEventId = 'occurrence-$date';
  await repository.upsertEvent(
    accountId: 'google:g',
    event: CalendarEventDto(
      provider: BusyProvider.google,
      providerCalendarId: 'calendar-1',
      providerEventId: providerEventId,
      providerRecurringEventId: 'series-master',
      providerOriginalStartKey: start,
      title: 'Weekly planning',
      organizerJson: const {'self': true},
      startDateTime: start,
      startTimeZone: 'UTC',
      endDateTime: end,
      endTimeZone: 'UTC',
      updatedAtServer: '2026-05-30T00:00:00.000Z',
      rawJson: {
        'id': providerEventId,
        'summary': 'Weekly planning',
        'recurringEventId': 'series-master',
        'originalStartTime': {'dateTime': start},
        'start': {'dateTime': start, 'timeZone': 'UTC'},
        'end': {'dateTime': end, 'timeZone': 'UTC'},
        'updated': '2026-05-30T00:00:00.000Z',
      },
    ),
  );
  return CalendarRepository.eventId(
    accountId: 'google:g',
    provider: BusyProvider.google,
    providerCalendarId: 'calendar-1',
    providerEventId: providerEventId,
    providerOriginalStartKey: start,
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
  await database.delete(database.pendingOps).go();
  await database
      .update(database.calendarEvents)
      .write(const CalendarEventsCompanion(syncStatus: Value('synced')));
  expect(
    await database.select(database.notificationSchedule).get(),
    hasLength(1),
  );
}
