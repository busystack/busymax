import 'dart:convert';

import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'initial and token syncs request expanded recurring instances',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) {
        requests.add(request);
        return _json({
          'items': <Object?>[],
          'nextSyncToken': requests.length == 1
              ? 'next-sync-token-1'
              : 'next-sync-token-2',
        });
      });
      final rangeStart = DateTime.utc(2026, 7, 1);
      final rangeEnd = DateTime.utc(2026, 8, 1);

      await client.syncEvents(
        calendarId: 'calendar@example.com',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      await client.syncEvents(
        calendarId: 'calendar@example.com',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        syncTokenOrDeltaLink: 'next-sync-token-1',
      );

      expect(requests, hasLength(2));
      expect(requests[0].url.queryParameters, {
        'timeMin': '2026-07-01T00:00:00.000Z',
        'timeMax': '2026-08-01T00:00:00.000Z',
        'singleEvents': 'true',
        'showDeleted': 'true',
        'maxResults': '2500',
      });
      expect(requests[1].url.queryParameters, {
        'singleEvents': 'true',
        'showDeleted': 'true',
        'maxResults': '2500',
        'syncToken': 'next-sync-token-1',
      });
    },
  );

  test(
    'recurring instances synchronized by Google populate the schedule',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'account',
              provider: const Value('google'),
              authState: const Value('signed_in'),
              grantedScopes: const Value(''),
              createdAtUtc: '2026-07-01T00:00:00.000Z',
              updatedAtUtc: '2026-07-01T00:00:00.000Z',
            ),
          );
      late http.Request eventsRequest;
      final client = _client((request) {
        if (request.url.path == '/calendar/v3/users/me/calendarList') {
          return _json({
            'items': [
              {
                'id': 'calendar@example.com',
                'summary': 'Work',
                'primary': true,
                'selected': true,
                'accessRole': 'owner',
                'timeZone': 'America/Vancouver',
              },
            ],
          });
        }
        eventsRequest = request;
        final expandsInstances =
            request.url.queryParameters['singleEvents'] == 'true';
        return _json({
          'items': expandsInstances
              ? [_instance('instance-1', 14), _instance('instance-2', 21)]
              : [_recurringMaster()],
          'nextSyncToken': 'sync-token-1',
        });
      });

      await CalendarSyncEngine(
        database: database,
        client: client,
        accountId: 'account',
        nowUtc: () => DateTime.utc(2026, 7, 10),
      ).incrementalSync();

      expect(eventsRequest.url.queryParameters['singleEvents'], 'true');
      final rows = await database.select(database.calendarEvents).get();
      expect(rows, hasLength(2));
      expect(
        rows.map((row) => row.providerRecurringEventId),
        everyElement('series-1'),
      );
      expect(rows.map((row) => row.providerOriginalStartKey).toSet(), {
        '2026-07-14T09:00:00-07:00',
        '2026-07-21T09:00:00-07:00',
      });

      final schedule = await ScheduleRepository(database).listItems(
        range: ScheduleRange(
          start: DateTime(2026, 7, 13),
          end: DateTime(2026, 7, 22),
        ),
      );
      expect(schedule.map((item) => item.title), [
        'Weekly planning',
        'Weekly planning',
      ]);
      expect(schedule.map((item) => item.start), [
        DateTime.parse('2026-07-14T09:00:00-07:00').toLocal(),
        DateTime.parse('2026-07-21T09:00:00-07:00').toLocal(),
      ]);
    },
  );
}

GoogleCalendarApiClient _client(
  http.Response Function(http.Request request) handler,
) {
  return GoogleCalendarApiClient(
    httpClient: MockClient((request) async => handler(request)),
    baseUri: Uri.parse('https://www.googleapis.com'),
    authorizationHeaderProvider: () async => 'Bearer token',
  );
}

http.Response _json(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'Content-Type': 'application/json'},
  );
}

Map<String, Object?> _instance(String id, int day) {
  final dayValue = day.toString().padLeft(2, '0');
  final start = '2026-07-${dayValue}T09:00:00-07:00';
  return {
    'id': id,
    'status': 'confirmed',
    'summary': 'Weekly planning',
    'recurringEventId': 'series-1',
    'originalStartTime': {'dateTime': start, 'timeZone': 'America/Vancouver'},
    'start': {'dateTime': start, 'timeZone': 'America/Vancouver'},
    'end': {
      'dateTime': '2026-07-${dayValue}T10:00:00-07:00',
      'timeZone': 'America/Vancouver',
    },
    'updated': '2026-07-10T00:00:00Z',
  };
}

Map<String, Object?> _recurringMaster() {
  return {
    'id': 'series-1',
    'status': 'confirmed',
    'summary': 'Weekly planning',
    'recurrence': ['RRULE:FREQ=WEEKLY'],
    'start': {
      'dateTime': '2026-07-14T09:00:00-07:00',
      'timeZone': 'America/Vancouver',
    },
    'end': {
      'dateTime': '2026-07-14T10:00:00-07:00',
      'timeZone': 'America/Vancouver',
    },
    'updated': '2026-07-10T00:00:00Z',
  };
}
