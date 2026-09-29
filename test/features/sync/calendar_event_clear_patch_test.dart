import 'dart:convert';

import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/sync/calendar_pending_ops_replayer.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
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
          provider == BusyProvider.google
              ? '/calendar/v3/calendars/cal-1/events/event-1'
              : '/v1.0/me/calendars/cal-1/events/event-1',
        );
        final body = (jsonDecode(result.patchRequest.body) as Map)
            .cast<String, Object?>();
        expect(body, contains('recurrence'));
        expect(
          body['recurrence'],
          provider == BusyProvider.google ? <Object?>[] : null,
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

  test(
    'Microsoft plain edit replays new body and retains Teams link',
    () async {
      final result = await _editAndReplay(
        provider: BusyProvider.microsoft,
        editedDescription: 'Updated agenda',
        onlineMeeting: true,
      );
      final body = (jsonDecode(result.patchRequest.body) as Map)
          .cast<String, Object?>();
      final outgoing = (body['body'] as Map).cast<String, Object?>();
      expect(outgoing['contentType'], 'html');
      expect(outgoing['content'], contains('Updated agenda'));
      expect(
        outgoing['content'],
        contains('https://teams.microsoft.com/l/meetup-join/example'),
      );
      expect(outgoing['content'], isNot(contains('Original agenda')));
      expect(result.queuedRequest, contains('descriptionHtml'));
    },
  );

  test('Microsoft unrelated edit does not replace HTML body', () async {
    final result = await _editAndReplay(
      provider: BusyProvider.microsoft,
      onlineMeeting: true,
    );
    final body = (jsonDecode(result.patchRequest.body) as Map)
        .cast<String, Object?>();
    expect(body, isNot(contains('body')));
  });

  test('Microsoft formatting-only edit reaches provider', () async {
    final result = await _editAndReplay(
      provider: BusyProvider.microsoft,
      onlineMeeting: true,
      editedDescriptionHtml: '<p><strong>Original agenda</strong></p>',
    );
    final body = (jsonDecode(result.patchRequest.body) as Map)
        .cast<String, Object?>();
    final outgoing = (body['body'] as Map).cast<String, Object?>();
    expect(outgoing['content'], contains('<strong>Original agenda</strong>'));
    expect(outgoing['content'], contains('Join Teams meeting'));
  });

  test('Microsoft explicit clear retains Teams meeting information', () async {
    final result = await _editAndReplay(
      provider: BusyProvider.microsoft,
      onlineMeeting: true,
      clearDescription: true,
    );
    final body = (jsonDecode(result.patchRequest.body) as Map)
        .cast<String, Object?>();
    final outgoing = (body['body'] as Map).cast<String, Object?>();
    expect(outgoing['content'], isNot(contains('Original agenda')));
    expect(outgoing['content'], contains('Join Teams meeting'));
  });
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
  required BusyProvider provider,
  bool clearRecurrence = false,
  bool clearAttendees = false,
  String? editedDescription,
  String? editedDescriptionHtml,
  bool clearDescription = false,
  bool onlineMeeting = false,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  await database
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
  final recurrence = provider == BusyProvider.google
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
  final attendees = provider == BusyProvider.google
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
      description: onlineMeeting ? 'Original agenda' : null,
      conferenceJson: onlineMeeting
          ? const {
              'joinUrl': 'https://teams.microsoft.com/l/meetup-join/example',
            }
          : null,
      organizerJson: provider == BusyProvider.google
          ? const {'self': true}
          : null,
      updatedAtServer: '2026-06-08T00:00:00.000Z',
      rawJson: {
        ..._eventJson(
          provider,
          edited: false,
          includeRecurrence: true,
          includeAttendees: true,
        ),
        if (onlineMeeting)
          'body': {
            'contentType': 'html',
            'content':
                '<p>Original agenda</p><div><a href="https://teams.microsoft.com/l/meetup-join/example">Join Teams meeting</a></div>',
          },
      },
    ),
  );
  final eventId = CalendarRepository.eventId(
    accountId: 'account',
    provider: provider,
    providerCalendarId: 'cal-1',
    providerEventId: 'event-1',
  );
  final originalDraft = EventEditorDraft.fromEventDetail(
    (await repository.loadEventDetail(eventId))!,
  );
  await repository.updateLocalEvent(
    originalDraft.copyWith(
      title: 'Edited planning',
      description: editedDescription,
      descriptionHtml: editedDescriptionHtml,
      clearDescription: clearDescription,
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

  final CloudCalendarClient client = provider == BusyProvider.google
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
  BusyProvider provider, {
  required bool edited,
  required bool includeRecurrence,
  required bool includeAttendees,
}) {
  return provider == BusyProvider.google
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
    'organizer': {'self': true},
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
