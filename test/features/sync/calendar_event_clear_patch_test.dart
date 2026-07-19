import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/sync/calendar_pending_ops_replayer.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/task_providers/task_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final provider in [TaskProvider.google, TaskProvider.microsoft]) {
    test(
      '${provider.storageValue} event edit explicitly clears recurrence only',
      () async {
        final result = await _editAndReplay(
          provider: provider,
          clearRecurrence: true,
        );

        expect(result.queuedRequest, contains('recurrenceJson'));
        expect(result.queuedRequest, isNot(contains('attendeesJson')));
        expect(result.applied, 1);
        expect(result.patchRequest.method, 'PATCH');
        expect(
          result.patchRequest.url.path,
          provider == TaskProvider.google
              ? '/calendar/v3/calendars/cal-1/events/event-1'
              : '/v1.0/me/calendars/cal-1/events/event-1',
        );
        final body = (jsonDecode(result.patchRequest.body) as Map)
            .cast<String, Object?>();
        expect(body, contains('recurrence'));
        expect(
          body['recurrence'],
          provider == TaskProvider.google ? <Object?>[] : null,
        );
        expect(body, isNot(contains('attendees')));
        _expectUnrelatedOptionalFieldsOmitted(body);
      },
    );

    test(
      '${provider.storageValue} event edit explicitly clears final attendee only',
      () async {
        final result = await _editAndReplay(
          provider: provider,
          clearAttendees: true,
        );

        expect(result.queuedRequest, contains('attendeesJson'));
        expect(result.queuedRequest, isNot(contains('recurrenceJson')));
        expect(result.applied, 1);
        expect(result.patchRequest.method, 'PATCH');
        final body = (jsonDecode(result.patchRequest.body) as Map)
            .cast<String, Object?>();
        expect(body['attendees'], <Object?>[]);
        expect(body, isNot(contains('recurrence')));
        _expectUnrelatedOptionalFieldsOmitted(body);
      },
    );
  }
}

void _expectUnrelatedOptionalFieldsOmitted(Map<String, Object?> body) {
  expect(body, isNot(contains('description')));
  expect(body, isNot(contains('location')));
  expect(body, isNot(contains('colorId')));
  expect(body, isNot(contains('categories')));
  expect(body, isNot(contains('conferenceData')));
  expect(body, isNot(contains('onlineMeetingProvider')));
}

Future<
  ({int applied, Map<String, Object?> queuedRequest, http.Request patchRequest})
>
_editAndReplay({
  required TaskProvider provider,
  bool clearRecurrence = false,
  bool clearAttendees = false,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: Value(provider.storageValue),
          authState: const Value('signed_in'),
          createdAtUtc: '2026-06-08T00:00:00.000Z',
          updatedAtUtc: '2026-06-08T00:00:00.000Z',
        ),
      );
  final repository = CalendarRepository(
    database: database,
    now: () => DateTime.utc(2026, 6, 8),
  );
  await repository.upsertSource(
    accountId: 'account',
    source: CalendarSourceDto(
      provider: provider,
      providerCalendarId: 'cal-1',
      summary: 'Work',
      timeZone: 'UTC',
    ),
  );
  final recurrence = provider == TaskProvider.google
      ? <Object?>['RRULE:FREQ=WEEKLY']
      : <String, Object?>{
          'pattern': {
            'type': 'weekly',
            'interval': 1,
            'daysOfWeek': ['monday'],
          },
          'range': {
            'type': 'noEnd',
            'startDate': '2026-06-08',
            'recurrenceTimeZone': 'UTC',
          },
        };
  final attendees = provider == TaskProvider.google
      ? <Object?>[
          {'email': 'guest@example.com', 'displayName': 'Guest'},
        ]
      : <Object?>[
          {
            'emailAddress': {'address': 'guest@example.com', 'name': 'Guest'},
            'type': 'required',
          },
        ];
  await repository.upsertEvent(
    accountId: 'account',
    event: CalendarEventDto(
      provider: provider,
      providerCalendarId: 'cal-1',
      providerEventId: 'event-1',
      title: 'Planning',
      startDateTime: '2026-06-08T09:00:00.000Z',
      startTimeZone: 'UTC',
      endDateTime: '2026-06-08T10:00:00.000Z',
      endTimeZone: 'UTC',
      recurrenceJson: recurrence,
      attendeesJson: attendees,
      updatedAtServer: '2026-06-08T00:00:00.000Z',
      rawJson: _eventJson(
        provider,
        edited: false,
        includeRecurrence: true,
        includeAttendees: true,
      ),
    ),
  );
  final eventId = CalendarRepository.eventId(
    accountId: 'account',
    provider: provider,
    providerCalendarId: 'cal-1',
    providerEventId: 'event-1',
  );
  final originalDraft = EventEditorDraft.existing(
    eventId: eventId,
    accountId: 'account',
    sourceId: CalendarRepository.sourceId(
      accountId: 'account',
      provider: provider,
      providerCalendarId: 'cal-1',
    ),
    providerCalendarId: 'cal-1',
    title: 'Planning',
    allDay: false,
    start: DateTime.utc(2026, 6, 8, 9),
    end: DateTime.utc(2026, 6, 8, 10),
    startTimeZone: 'UTC',
    endTimeZone: 'UTC',
    recurrence: recurrence,
    attendees: const [
      EventAttendeeDraft(email: 'guest@example.com', displayName: 'Guest'),
    ],
  );
  await repository.updateLocalEvent(
    originalDraft.copyWith(
      title: 'Edited planning',
      clearRecurrence: clearRecurrence,
      attendees: clearAttendees ? const [] : null,
    ),
  );

  final op = await database.select(database.pendingOps).getSingle();
  final queuedRequest = (jsonDecode(op.requestJson) as Map)
      .cast<String, Object?>();
  late http.Request patchRequest;
  Future<http.Response> handler(http.Request request) async {
    if (request.method == 'PATCH') {
      patchRequest = request;
    }
    return http.Response(
      jsonEncode(
        _eventJson(
          provider,
          edited: request.method == 'PATCH',
          includeRecurrence: request.method != 'PATCH' || !clearRecurrence,
          includeAttendees: request.method != 'PATCH' || !clearAttendees,
        ),
      ),
      200,
      headers: {'Content-Type': 'application/json'},
    );
  }

  final CloudCalendarClient client = provider == TaskProvider.google
      ? GoogleCalendarApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('https://www.googleapis.com'),
          authorizationHeaderProvider: () async => 'Bearer token',
        )
      : MicrosoftCalendarApiClient(
          httpClient: MockClient(handler),
          baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
          responseTimeZone: 'UTC',
          authorizationHeaderProvider: () async => 'Bearer token',
        );
  final applied = await CalendarPendingOpsReplayer(
    database: database,
    client: client,
    accountId: 'account',
    nowUtc: () => DateTime.utc(2026, 6, 8),
  ).replayDueOps();

  return (
    applied: applied,
    queuedRequest: queuedRequest,
    patchRequest: patchRequest,
  );
}

Map<String, Object?> _eventJson(
  TaskProvider provider, {
  required bool edited,
  required bool includeRecurrence,
  required bool includeAttendees,
}) {
  return provider == TaskProvider.google
      ? _googleEventJson(
          edited: edited,
          includeRecurrence: includeRecurrence,
          includeAttendees: includeAttendees,
        )
      : _microsoftEventJson(
          edited: edited,
          includeRecurrence: includeRecurrence,
          includeAttendees: includeAttendees,
        );
}

Map<String, Object?> _googleEventJson({
  required bool edited,
  required bool includeRecurrence,
  required bool includeAttendees,
}) {
  return {
    'id': 'event-1',
    'status': 'confirmed',
    'summary': edited ? 'Edited planning' : 'Planning',
    'start': {'dateTime': '2026-06-08T09:00:00.000Z', 'timeZone': 'UTC'},
    'end': {'dateTime': '2026-06-08T10:00:00.000Z', 'timeZone': 'UTC'},
    if (includeRecurrence) 'recurrence': ['RRULE:FREQ=WEEKLY'],
    if (includeAttendees)
      'attendees': [
        {'email': 'guest@example.com', 'displayName': 'Guest'},
      ],
    'updated': '2026-06-08T00:00:00.000Z',
  };
}

Map<String, Object?> _microsoftEventJson({
  required bool edited,
  required bool includeRecurrence,
  required bool includeAttendees,
}) {
  return {
    'id': 'event-1',
    'subject': edited ? 'Edited planning' : 'Planning',
    'isAllDay': false,
    'start': {'dateTime': '2026-06-08T09:00:00.000Z', 'timeZone': 'UTC'},
    'end': {'dateTime': '2026-06-08T10:00:00.000Z', 'timeZone': 'UTC'},
    if (includeRecurrence)
      'recurrence': {
        'pattern': {
          'type': 'weekly',
          'interval': 1,
          'daysOfWeek': ['monday'],
        },
        'range': {
          'type': 'noEnd',
          'startDate': '2026-06-08',
          'recurrenceTimeZone': 'UTC',
        },
      },
    if (includeAttendees)
      'attendees': [
        {
          'emailAddress': {'address': 'guest@example.com', 'name': 'Guest'},
          'type': 'required',
        },
      ],
    'lastModifiedDateTime': '2026-06-08T00:00:00.000Z',
  };
}
