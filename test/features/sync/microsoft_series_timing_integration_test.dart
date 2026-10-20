import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/sync/calendar_pending_ops_replayer.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_mapper.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_event_rescheduling.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/persistence_test_directory.dart';

void main() {
  for (final limitation in [
    'none',
    'properties',
    'drag',
    'cancellation',
    'attachment',
    'meeting',
    'boundary',
  ]) {
    test(
      'Microsoft series timing preserves provider state ($limitation)',
      () async {
        final directory = await createPersistenceTestDirectory(
          'busymax-ms-series-',
        );
        AppDatabase open() => AppDatabase(
          NativeDatabase(File('${directory.path}/fixture.sqlite')),
        );
        var database = open();
        addTearDown(() async {
          await database.close();
          await directory.delete(recursive: true);
        });
        Future<void> reopen() async {
          await database.close();
          database = open();
        }

        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'account',
                provider: 'microsoft',
                authority: 'https://login.microsoftonline.com/common',
                providerAccountId: 'fixture',
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                email: const Value('me@example.test'),
                calendarsEnabled: const Value(true),
                createdAtUtc: '2026-06-01T00:00:00Z',
                updatedAtUtc: '2026-06-01T00:00:00Z',
              ),
            );
        final server = _MicrosoftSeriesServer(limitation);
        final client = MicrosoftCalendarApiClient(
          httpClient: MockClient(server.respond),
          baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
          responseTimeZone: _zone,
        );
        CalendarRepository repository() => CalendarRepository(
          database: database,
          now: () => DateTime.utc(2026, 6, 1),
        );
        await repository().upsertSource(
          accountId: 'account',
          source: const CalendarSourceDto(
            provider: BusyProvider.microsoft,
            providerCalendarId: 'calendar',
            summary: 'Fixture',
            timeZone: _zone,
          ),
        );
        for (final resource in server.resources.values) {
          await repository().upsertEvent(
            accountId: 'account',
            event: microsoftCalendarEventFromJson('calendar', resource),
          );
        }
        final selected = (await database.select(database.calendarEvents).get())
            .singleWhere((row) => row.providerEventId == 'old-b');
        final detail = (await repository().loadEventDetail(selected.id))!;
        final draft = EventEditorDraft.fromEventDetail(detail).copyWith(
          start: providerCivilDateTime(DateTime.utc(2026, 6, 9, 9)),
          end: providerCivilDateTime(DateTime.utc(2026, 6, 9, 10)),
          recurringMutationScope: RecurringEventMutationScope.entireSeries,
        );
        final drag = limitation == 'drag';
        if (drag) {
          final item =
              (await ScheduleRepository(database).listItems(
                    range: ScheduleRange(
                      start: DateTime.utc(2026, 6),
                      end: DateTime.utc(2026, 7),
                    ),
                  ))
                  .whereType<CalendarScheduleItem>()
                  .singleWhere((item) => item.id == selected.id);
          expect(
            await ScheduleReschedulingCoordinator(
              repository: repository(),
              chooseScope: (_, _) async =>
                  RecurringEventMutationScope.entireSeries,
              chooseGuestUpdates: (_) async => throw StateError('No guests'),
              requestSync: (_) async {},
            ).commit(
              ScheduleRescheduleRequest(
                item: item,
                interval: ScheduleInterval(
                  providerWallTimeToInstant(draft.start!, _zone),
                  providerWallTimeToInstant(draft.end!, _zone),
                ),
              ),
            ),
            ScheduleRescheduleResult.saved,
          );
        } else {
          await repository().updateLocalEvent(draft);
        }
        await reopen();
        final result = await CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 2),
        ).replayDueOps();
        if (!['none', 'properties', 'drag'].contains(limitation)) {
          expect(result, 0);
          expect(
            server.patchCount,
            0,
            reason: 'Provider limitations must be checked before the master is changed.',
          );
          final pending = await database
              .select(database.pendingOps)
              .getSingle();
          expect(
            pending.lastErrorCode,
            'series_exception_preservation_required',
          );
          expect(pending.nextAttemptAtUtc, startsWith('9999-12-31'));
          final original = server.resources['old-c']!;
          expect(
            (original['start'] as Map)['dateTime'],
            limitation == 'boundary'
                ? '2026-06-09T13:00:00'
                : '2026-06-17T13:00:00',
          );
          await reopen();
          expect(
            await database.select(database.pendingOps).get(),
            hasLength(1),
          );
          return;
        }
        expect(
          result,
          1,
          reason: (await database.select(database.pendingOps).get())
              .map((op) => op.lastErrorMessage)
              .join('\n'),
        );
        final exception = server.resources['new-c']!;
        expect(exception['originalStart'], '2026-06-16T16:00:00.000Z');
        expect(
          DateTime.parse((exception['start'] as Map)['dateTime'] as String),
          DateTime(2026, 6, drag ? 18 : 17, 13),
        );
        expect(
          DateTime.parse((exception['end'] as Map)['dateTime'] as String),
          DateTime(2026, 6, drag ? 18 : 17, 15),
        );
        expect(exception['body'], {
          'contentType': 'html',
          'content': '<p>Keep exception details</p>',
        });
        expect(exception['categories'], ['Exception category']);
        expect(server.resources['old-c']!['isCancelled'], isTrue);
        if (limitation == 'properties') {
          expect(server.resources['new-b']!['subject'], 'Customized title');
          expect(
            (server.resources['new-b']!['start'] as Map)['dateTime'],
            '2026-06-09T09:00:00.000',
          );
          expect(
            (server.resources['new-e']!['start'] as Map)['dateTime'],
            '2026-06-30T09:00:00.000',
          );
          expect(server.resources['new-e']!['isReminderOn'], isTrue);
          expect(server.resources['new-e']!['reminderMinutesBeforeStart'], 45);
        }
        await CalendarSyncEngine(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 2),
        ).fullSync();
        await reopen();
        final active = (await database.select(database.calendarEvents).get())
            .where(
              (row) =>
                  row.providerRecurringEventId != null &&
                  !row.isDeleted &&
                  !row.isCancelled,
            )
            .toList();
        expect(active, hasLength(5));
        final moved = active.singleWhere(
          (row) => row.title == 'Moved Wednesday',
        );
        expect(moved.providerOriginalStartKey, '2026-06-16T16:00:00.000Z');
        expect(
          providerDateTimeAsUtcInstant(
            moved.startDateTime,
            moved.startTimeZone,
          ),
          DateTime.utc(2026, 6, drag ? 18 : 17, 20),
        );
        expect(
          providerDateTimeAsUtcInstant(moved.endDateTime, moved.endTimeZone),
          DateTime.utc(2026, 6, drag ? 18 : 17, 22),
        );
        expect(
          active
              .where((row) => row.id != moved.id)
              .map(
                (row) => providerDateTimeAsCivilTime(
                  row.startDateTime,
                  row.startTimeZone,
                )!.weekday,
              ),
          everyElement(DateTime.tuesday),
        );
        expect(await database.select(database.pendingOps).get(), isEmpty);
        if (limitation == 'properties') {
          expect(
            active.singleWhere((row) => row.providerEventId == 'new-b').title,
            'Customized title',
          );
          expect(
            jsonDecode(
              active
                  .singleWhere((row) => row.providerEventId == 'new-e')
                  .remindersJson!,
            ),
            {'isReminderOn': true, 'reminderMinutesBeforeStart': 45},
          );
        }
      },
    );
  }
}

const _zone = 'Pacific Standard Time';

class _MicrosoftSeriesServer {
  _MicrosoftSeriesServer(this.limitation) {
    resources['master'] = {
      'id': 'master',
      'type': 'seriesMaster',
      'subject': 'Weekly',
      'changeKey': 'master-before',
      'lastModifiedDateTime': '2026-05-30T00:00:00Z',
      'isOrganizer': true,
      'isAllDay': false,
      'start': {'dateTime': '2026-06-01T09:00:00', 'timeZone': _zone},
      'end': {'dateTime': '2026-06-01T10:00:00', 'timeZone': _zone},
      'body': {'contentType': 'html', 'content': '<p>Keep master body</p>'},
      'recurrence': {
        'pattern': {
          'type': 'weekly',
          'interval': 1,
          'daysOfWeek': ['monday'],
          'firstDayOfWeek': 'monday',
        },
        'range': {
          'type': 'numbered',
          'startDate': '2026-06-01',
          'numberOfOccurrences': 5,
          'recurrenceTimeZone': _zone,
        },
      },
    };
    for (final entry in {
      'old-a': 1,
      'old-b': 8,
      'old-c': 15,
      'old-d': 22,
      'old-e': 29,
    }.entries) {
      resources[entry.key] = _instance(entry.key, entry.value);
    }
    if (limitation == 'properties') {
      resources['old-b']!.addAll({
        'type': 'exception',
        'subject': 'Customized title',
      });
      resources['old-e']!.addAll({
        'type': 'exception',
        'isReminderOn': true,
        'reminderMinutesBeforeStart': 45,
      });
    }
    resources['old-c']!.addAll({
      'type': 'exception',
      'subject': 'Moved Wednesday',
      'start': {
        'dateTime': limitation == 'boundary'
            ? '2026-06-09T13:00:00'
            : '2026-06-17T13:00:00',
        'timeZone': _zone,
      },
      'end': {
        'dateTime': limitation == 'boundary'
            ? '2026-06-09T15:00:00'
            : '2026-06-17T15:00:00',
        'timeZone': _zone,
      },
      'body': {
        'contentType': 'html',
        'content': '<p>Keep exception details</p>',
      },
      'categories': ['Exception category'],
      'hasAttachments': limitation == 'attachment',
      'isOnlineMeeting': limitation == 'meeting',
    });
  }
  final String limitation;
  final resources = <String, Map<String, Object?>>{};
  int patchCount = 0;
  static Map<String, Object?> _instance(String id, int day) => {
    'id': id,
    'type': 'occurrence',
    'seriesMasterId': 'master',
    'subject': 'Weekly',
    'isAllDay': false,
    'changeKey': '$id-before',
    'lastModifiedDateTime': '2026-05-30T00:00:00Z',
    'originalStart': providerWallTimeToInstant(
      DateTime.utc(2026, 6, day, 9),
      _zone,
    ).toIso8601String(),
    'start': {
      'dateTime': providerWallTimeIso8601String(DateTime.utc(2026, 6, day, 9)),
      'timeZone': _zone,
    },
    'end': {
      'dateTime': providerWallTimeIso8601String(DateTime.utc(2026, 6, day, 10)),
      'timeZone': _zone,
    },
    'body': {'contentType': 'html', 'content': '<p>Keep master body</p>'},
  };
  http.Response _json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  Future<http.Response> respond(http.Request request) async {
    final segments = request.url.pathSegments;
    if (segments.last == 'calendars') {
      return _json({
        'value': [
          {'id': 'calendar', 'name': 'Fixture', 'canEdit': true},
        ],
      });
    }
    if (segments.last == 'calendarView') {
      return _json({
        'value': resources.values
            .where(
              (raw) =>
                  raw['seriesMasterId'] == 'master' &&
                  raw['isCancelled'] != true,
            )
            .toList(),
      });
    }
    final eventIndex = segments.indexOf('events');
    expect(eventIndex, isNonNegative);
    final suffix = segments.skip(eventIndex + 1).toList();
    final id = suffix.first;
    if (suffix.last == 'instances') {
      return _json({
        'value': resources.values
            .where(
              (raw) =>
                  raw['seriesMasterId'] == 'master' &&
                  raw['isCancelled'] != true,
            )
            .toList(),
      });
    }
    if (request.method == 'GET') {
      final raw = resources[id];
      if (request.url.queryParameters.containsKey(r'$expand')) {
        expect(request.url.queryParameters[r'$expand'], 'exceptionOccurrences');
        expect(
          request.url.queryParameters[r'$select'],
          contains('cancelledOccurrences'),
        );
        return _json({
          ...raw!,
          'exceptionOccurrences': resources.values
              .where(
                (raw) =>
                    raw['type'] == 'exception' && raw['isCancelled'] != true,
              )
              .toList(),
          'cancelledOccurrences': limitation == 'cancellation'
              ? ['opaque-cancelled-occurrence']
              : <String>[],
        });
      }
      return _json(raw);
    }
    if (request.method == 'DELETE') {
      expect(id, 'old-c');
      resources[id]!['isCancelled'] = true;
      return http.Response('', 204);
    }
    expect(request.method, 'PATCH');
    patchCount++;
    final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
    expect(body, isNot(contains('originalStart')));
    expect(body, isNot(contains('seriesMasterId')));
    if (id == 'master') {
      expect(body, isNot(contains('body')));
      expect(((body['recurrence'] as Map)['pattern'] as Map)['daysOfWeek'], [
        'tuesday',
      ]);
      expect(
        ((body['recurrence'] as Map)['range'] as Map)['startDate'],
        '2026-06-02',
      );
      for (final entry in {
        'new-a': 2,
        'new-b': 9,
        'new-c': 16,
        'new-d': 23,
        'new-e': 30,
      }.entries) {
        resources[entry.key] = _instance(entry.key, entry.value);
      }
      for (final id in ['old-a', 'old-b', 'old-d', 'old-e']) {
        resources[id]!['isCancelled'] = true;
      }
    } else {
      resources[id]!['type'] = 'exception';
    }
    resources[id]!.addAll({
      ...body,
      'changeKey': '$id-after',
      'lastModifiedDateTime': '2026-06-01T00:00:00Z',
    });
    return _json(resources[id]);
  }
}
