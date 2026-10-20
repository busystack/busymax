import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/sync/calendar_pending_ops_replayer.dart';
import 'package:busymax/src/features/sync/calendar_sync_engine.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:busymax/src/features/recurrence/domain/series_timing_change.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/google_calendar/google_calendar_mapper.dart';
import 'package:busymax/src/google_calendar/google_calendar_errors.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/persistence_test_directory.dart';

void main() {
  test(
    'monthly date edit requires approval and adds its new dates before replay',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'account',
              provider: 'google',
              authority: 'https://accounts.google.com',
              providerAccountId: 'fixture',
              credentialKind: 'oauth',
              authState: const Value('signed_in'),
              createdAtUtc: '2026-01-01T00:00:00Z',
              updatedAtUtc: '2026-01-01T00:00:00Z',
            ),
          );
      final server = _GoogleSeriesServer(monthly: true);
      final repository = CalendarRepository(
        database: database,
        now: () => DateTime.utc(2026, 1, 1),
      );
      await repository.upsertSource(
        accountId: 'account',
        source: const CalendarSourceDto(
          provider: BusyProvider.google,
          providerCalendarId: 'calendar',
          summary: 'Fixture',
          timeZone: 'UTC',
          accessRole: 'owner',
        ),
      );
      for (final resource in server.resources.values) {
        await repository.upsertEvent(
          accountId: 'account',
          event: googleCalendarEventFromJson('calendar', resource),
        );
      }
      await repository.saveSyncState(
        accountId: 'account',
        provider: BusyProvider.google,
        syncKind: 'events',
        calendarSourceId: 'account|google|calendar',
        rangeStart: '2026-01-01T00:00:00Z',
        rangeEnd: '2026-08-01T00:00:00Z',
        cursorKind: 'google_sync_token',
        cursorValue: 'baseline',
        full: true,
      );
      final original = (await database.select(database.calendarEvents).get())
          .singleWhere((row) => row.providerEventId == 'old-a');
      final detail = (await repository.loadEventDetail(original.id))!;
      final draft = EventEditorDraft.fromEventDetail(detail).copyWith(
        start: DateTime.utc(2026, 2, 1, 9),
        end: DateTime.utc(2026, 2, 1, 10),
        recurringMutationScope: RecurringEventMutationScope.entireSeries,
      );
      final proposed = (await repository.prepareSeriesTimingChange(draft))!;
      expect(proposed.requiresConfirmation, isTrue);
      expect(proposed.rule.byMonthDay, [1]);
      expect(proposed.rule.count, 4);
      await expectLater(
        repository.updateLocalEvent(draft),
        throwsA(isA<SeriesTimingConfirmationRequired>()),
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final approved = draft.copyWith(seriesTimingApproval: proposed.signature);
      await expectLater(
        repository.updateLocalEvent(
          approved.copyWith(
            start: DateTime.utc(2026, 3, 1, 9),
            end: DateTime.utc(2026, 3, 1, 10),
          ),
        ),
        throwsA(isA<SeriesTimingConfirmationRequired>()),
      );
      await repository.updateLocalEvent(approved);
      Future<void> check() async {
        final active = (await database.select(database.calendarEvents).get())
            .where(
              (row) =>
                  row.providerRecurringEventId != null &&
                  !row.isDeleted &&
                  !row.isCancelled,
            )
            .toList();
        expect(
          active.map(
            (row) => providerDateTimeAsUtcInstant(
              row.startDateTime,
              row.startTimeZone,
            ),
          ),
          unorderedEquals([
            DateTime.utc(2026, 2, 1, 9),
            DateTime.utc(2026, 3, 1, 9),
            DateTime.utc(2026, 4, 1, 9),
            DateTime.utc(2026, 5, 1, 9),
          ]),
        );
      }

      await check();
      final pending = await database.select(database.pendingOps).getSingle();
      await PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncTasks: () async {},
        syncCalendar: () async {},
      ).discard(pending.id);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final restored = (await database.select(database.calendarEvents).get())
          .where(
            (row) =>
                row.providerRecurringEventId != null &&
                !row.isDeleted &&
                !row.isCancelled,
          )
          .toList();
      expect(
        restored.map(
          (row) => providerDateTimeAsUtcInstant(
            row.startDateTime,
            row.startTimeZone,
          ),
        ),
        unorderedEquals([
          DateTime.utc(2026, 1, 31, 9),
          DateTime.utc(2026, 3, 31, 9),
          DateTime.utc(2026, 5, 31, 9),
          DateTime.utc(2026, 7, 31, 9),
        ]),
      );
      await repository.updateLocalEvent(approved);
      await check();
      final client = GoogleCalendarApiClient(
        httpClient: MockClient(server.respond),
        baseUri: Uri.parse('https://calendar.example.test'),
      );
      expect(
        await CalendarPendingOpsReplayer(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 1, 2),
        ).replayDueOps(),
        1,
        reason: (await database.select(database.pendingOps).get())
            .map((op) => op.lastErrorMessage)
            .join('\n'),
      );
      await check();
      expect(
        (await database.select(database.calendarEvents).get()).where(
          (row) =>
              !row.isDeleted && row.providerEventId.startsWith('local:series:'),
        ),
        isEmpty,
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  for (final scope in ['entire', 'following', 'following-first']) {
    final following = scope != 'entire';
    final split = scope == 'following';
    final first = scope == 'following-first';
    for (final interruption
        in first
            ? ['after-master']
            : [
                'none',
                'before-exception',
                'after-master',
                'after-exception',
                'after-cancellation',
                'during-identities',
                if (following) 'after-create',
              ]) {
      test(
        'Google ordinary $scope edit preserves Wednesday, cancellation and association ($interruption)',
        () async {
          final directory = await createPersistenceTestDirectory(
            'busymax-series-timing-',
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

          final server = _GoogleSeriesServer();
          final client = GoogleCalendarApiClient(
            httpClient: MockClient(server.respond),
            baseUri: Uri.parse('https://calendar.example.test'),
          );
          await database
              .into(database.accounts)
              .insert(
                AccountsCompanion.insert(
                  id: 'account',
                  provider: 'google',
                  authority: 'https://accounts.google.com',
                  providerAccountId: 'fixture-account',
                  credentialKind: 'oauth',
                  createdAtUtc: '2026-06-01T00:00:00Z',
                  updatedAtUtc: '2026-06-01T00:00:00Z',
                  email: const Value('me@example.test'),
                  authState: const Value('signed_in'),
                  calendarsEnabled: const Value(true),
                ),
              );
          CalendarRepository repository() => CalendarRepository(
            database: database,
            now: () => DateTime.utc(2026, 6, 1),
          );
          await repository().upsertSource(
            accountId: 'account',
            source: const CalendarSourceDto(
              provider: BusyProvider.google,
              providerCalendarId: 'calendar',
              summary: 'Fixture',
              timeZone: 'UTC',
              accessRole: 'owner',
              dataOwner: 'me@example.test',
            ),
          );
          for (final raw in server.resources.values) {
            await repository().upsertEvent(
              accountId: 'account',
              event: googleCalendarEventFromJson('calendar', raw),
            );
          }
          final selected =
              (await database.select(database.calendarEvents).get())
                  .singleWhere(
                    (row) => row.providerEventId == (first ? 'old-a' : 'old-b'),
                  );
          final detail = (await repository().loadEventDetail(selected.id))!;
          await repository().updateLocalEvent(
            EventEditorDraft.fromEventDetail(detail).copyWith(
              start: DateTime.utc(2026, 6, first ? 2 : 9, 9),
              end: DateTime.utc(2026, 6, first ? 2 : 9, 10),
              recurringMutationScope: following
                  ? RecurringEventMutationScope.thisAndFuture
                  : RecurringEventMutationScope.entireSeries,
            ),
          );
          Future<void> checkOptimistic() async {
            final active =
                (await database.select(database.calendarEvents).get())
                    .where(
                      (row) =>
                          row.providerRecurringEventId != null &&
                          !row.isDeleted &&
                          !row.isCancelled,
                    )
                    .toList();
            expect(active, hasLength(4));
            final exception = active.singleWhere(
              (row) => row.title == 'Moved Wednesday',
            );
            expect(
              providerDateTimeAsUtcInstant(
                exception.startDateTime,
                exception.startTimeZone,
              ),
              DateTime.utc(2026, 6, 17, 13),
            );
            expect(
              providerDateTimeAsUtcInstant(
                exception.endDateTime,
                exception.endTimeZone,
              ),
              DateTime.utc(2026, 6, 17, 15),
            );
            expect(
              active
                  .where(
                    (row) =>
                        row.title != 'Moved Wednesday' &&
                        row.providerEventId != 'old-a',
                  )
                  .map(
                    (row) => providerDateTimeAsUtcInstant(
                      row.startDateTime,
                      row.startTimeZone,
                    )!.weekday,
                  ),
              everyElement(DateTime.tuesday),
            );
            final first = active.singleWhere(
              (row) => row.providerEventId == 'old-a',
            );
            expect(
              providerDateTimeAsUtcInstant(
                first.startDateTime,
                first.startTimeZone,
              )!.weekday,
              split ? DateTime.monday : DateTime.tuesday,
            );
          }

          await checkOptimistic();
          await reopen();
          await checkOptimistic();
          server
            ..failNextExceptionPatch = interruption == 'before-exception'
            ..loseMasterResponse = interruption == 'after-master'
            ..loseExceptionResponse = interruption == 'after-exception'
            ..loseCancellationResponse = interruption == 'after-cancellation'
            ..loseCreateResponse = interruption == 'after-create'
            ..failLastIdentity = interruption == 'during-identities';
          Future<int> replay(DateTime now) => CalendarPendingOpsReplayer(
            database: database,
            client: client,
            accountId: 'account',
            nowUtc: () => now,
          ).replayDueOps();
          if (interruption != 'none') {
            if (interruption == 'before-exception') {
              await expectLater(
                replay(DateTime.utc(2026, 6, 1)),
                throwsA(isA<GoogleCalendarApiError>()),
              );
            } else {
              expect(await replay(DateTime.utc(2026, 6, 1)), 0);
            }
            expect(
              await database.select(database.pendingOps).get(),
              hasLength(1),
            );
            final recovery = await database
                .select(database.pendingOps)
                .getSingle();
            await expectLater(
              PendingOpResolutionService(
                database: database,
                accountId: 'account',
                calendarClient: client,
                syncTasks: () async {},
                syncCalendar: () async {},
              ).discard(recovery.id),
              throwsA(
                isA<StateError>().having(
                  (error) => error.message,
                  'message',
                  contains('preserving its exceptions'),
                ),
              ),
            );
            expect(
              await database.select(database.pendingOps).get(),
              hasLength(1),
            );
            if (interruption == 'during-identities') {
              expect(
                (await database.select(database.calendarEvents).get()).any(
                  (row) => row.id == recovery.eventId,
                ),
                isTrue,
              );
              expect(recovery.eventId, contains('new-b'));
            }
            await reopen();
          }
          expect(
            await replay(DateTime.utc(2026, 6, 2)),
            1,
            reason: (await database.select(database.pendingOps).get())
                .map((op) => op.lastErrorMessage)
                .join('\n'),
          );
          expect(await database.select(database.pendingOps).get(), isEmpty);
          final moved = server.resources.values.singleWhere(
            (raw) =>
                raw['summary'] == 'Moved Wednesday' &&
                raw['status'] != 'cancelled',
          );
          expect((moved['start'] as Map)['dateTime'], '2026-06-17T13:00:00Z');
          expect((moved['end'] as Map)['dateTime'], '2026-06-17T15:00:00Z');
          expect(
            (moved['originalStartTime'] as Map)['dateTime'],
            '2026-06-16T09:00:00.000Z',
          );
          expect(
            moved['recurringEventId'],
            split ? server.newMasterId : 'master',
          );
          expect(moved['extendedProperties'], {
            'private': {'fixture': 'keep'},
          });
          expect(moved['reminders'], {
            'useDefault': false,
            'overrides': [
              {'method': 'popup', 'minutes': 35},
            ],
          });
          expect(server.resources['new-d']!['status'], 'cancelled');
          expect(server.masterPatchCount, 1);
          final sync = CalendarSyncEngine(
            database: database,
            client: client,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 2),
          );
          await sync.fullSync();
          await sync.incrementalSync();
          await reopen();
          final active = (await database.select(database.calendarEvents).get())
              .where(
                (row) =>
                    row.providerRecurringEventId != null &&
                    !row.isDeleted &&
                    !row.isCancelled,
              )
              .toList();
          expect(active, hasLength(4));
          final saved = active.singleWhere(
            (row) => row.title == 'Moved Wednesday',
          );
          expect(saved.providerOriginalStartKey, '2026-06-16T09:00:00.000Z');
          expect(
            saved.providerRecurringEventId,
            split ? server.newMasterId : 'master',
          );
          expect(
            providerDateTimeAsUtcInstant(
              saved.startDateTime,
              saved.startTimeZone,
            ),
            DateTime.utc(2026, 6, 17, 13),
          );
          final ordinary = active.where((row) => row.id != saved.id);
          expect(
            ordinary.map(
              (row) => providerDateTimeAsUtcInstant(
                row.startDateTime,
                row.startTimeZone,
              )!.weekday,
            ),
            split
                ? unorderedEquals([
                    DateTime.monday,
                    DateTime.tuesday,
                    DateTime.tuesday,
                  ])
                : everyElement(DateTime.tuesday),
          );
          expect(active.map((row) => row.syncStatus), everyElement('synced'));
        },
      );
    }
  }
}

/// HTTP fixtures use opaque IDs and explicit recurrence identities. Resolving
/// an instance must go through events.instances; no provider ID encoding is
/// assumed by either the test or production code.
class _GoogleSeriesServer {
  _GoogleSeriesServer({this.monthly = false}) {
    resources['master'] = {
      'id': 'master',
      'iCalUID': 'series@example.test',
      'summary': 'Weekly',
      'etag': '"master-before"',
      'updated': '2026-05-30T00:00:00Z',
      'organizer': {'self': true, 'email': 'me@example.test'},
      'start': {'dateTime': '2026-06-01T09:00:00Z', 'timeZone': 'UTC'},
      'end': {'dateTime': '2026-06-01T10:00:00Z', 'timeZone': 'UTC'},
      'recurrence': ['RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=5'],
    };
    if (monthly) {
      resources['master']!.addAll({
        'start': {'dateTime': '2026-01-31T09:00:00Z', 'timeZone': 'UTC'},
        'end': {'dateTime': '2026-01-31T10:00:00Z', 'timeZone': 'UTC'},
        'recurrence': ['RRULE:FREQ=MONTHLY;BYMONTHDAY=31;COUNT=4'],
      });
      for (final entry in {
        'old-a': 1,
        'old-b': 3,
        'old-c': 5,
        'old-d': 7,
      }.entries) {
        resources[entry.key] = _instance(
          entry.key,
          'master',
          1,
          date: DateTime.utc(2026, entry.value, 31, 9),
        );
      }
      return;
    }
    for (final entry in {
      'old-a': 1,
      'old-b': 8,
      'old-c': 15,
      'old-d': 22,
      'old-e': 29,
    }.entries) {
      resources[entry.key] = _instance(entry.key, 'master', entry.value);
    }
    resources['old-c']!.addAll({
      'summary': 'Moved Wednesday',
      'start': {'dateTime': '2026-06-17T13:00:00Z', 'timeZone': 'UTC'},
      'end': {'dateTime': '2026-06-17T15:00:00Z', 'timeZone': 'UTC'},
      'extendedProperties': {
        'private': {'fixture': 'keep'},
      },
      'reminders': {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 35},
        ],
      },
    });
    resources['old-d']!['status'] = 'cancelled';
  }
  final bool monthly;
  final resources = <String, Map<String, Object?>>{};
  int masterPatchCount = 0;
  bool failNextExceptionPatch = false;
  bool loseMasterResponse = false;
  bool loseExceptionResponse = false;
  bool loseCancellationResponse = false;
  bool loseCreateResponse = false;
  bool failLastIdentity = false;
  String? newMasterId;
  bool get following => newMasterId != null;

  static Map<String, Object?> _instance(
    String id,
    String series,
    int day, {
    DateTime? date,
  }) {
    final start = date ?? DateTime.utc(2026, 6, day, 9);
    return {
      'id': id,
      'iCalUID': 'series@example.test',
      'recurringEventId': series,
      'summary': 'Weekly',
      'status': 'confirmed',
      'etag': '"$id-before"',
      'organizer': {'self': true, 'email': 'me@example.test'},
      'originalStartTime': {'dateTime': start.toIso8601String()},
      'start': {'dateTime': start.toIso8601String(), 'timeZone': 'UTC'},
      'end': {
        'dateTime': start.add(const Duration(hours: 1)).toIso8601String(),
        'timeZone': 'UTC',
      },
    };
  }

  void _generate(String series, {required bool following}) {
    if (monthly) {
      for (final entry in {
        'new-a': 2,
        'new-b': 3,
        'new-c': 4,
        'new-d': 5,
      }.entries) {
        resources[entry.key] = _instance(
          entry.key,
          series,
          1,
          date: DateTime.utc(2026, entry.value, 1, 9),
        );
      }
      for (final id in ['old-a', 'old-b', 'old-c', 'old-d']) {
        resources[id]!['status'] = 'cancelled';
      }
      return;
    }
    for (final entry in {
      'new-a': 2,
      'new-b': 9,
      'new-c': 16,
      'new-d': 23,
      'new-e': 30,
    }.entries) {
      if (following && entry.key == 'new-a') continue;
      resources[entry.key] = _instance(entry.key, series, entry.value);
    }
    for (final id in ['old-a', 'old-b', 'old-c', 'old-d', 'old-e']) {
      if (following && id == 'old-a') continue;
      // Entire-series updates may retain an old detached exception. The
      // replacement must be verified before retiring that exact old resource.
      if (!following && id == 'old-c') continue;
      resources[id]!['status'] = 'cancelled';
    }
  }

  http.Response _json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  Future<http.Response> respond(http.Request request) async {
    final segments = request.url.pathSegments;
    if (segments.last == 'calendarList') {
      return _json({
        'items': [
          {
            'id': 'calendar',
            'summary': 'Fixture',
            'timeZone': 'UTC',
            'accessRole': 'owner',
            'selected': true,
          },
        ],
      });
    }
    final eventIndex = segments.indexOf('events');
    expect(eventIndex, isNonNegative);
    final suffix = segments.skip(eventIndex + 1).toList();
    if (suffix.isEmpty) {
      if (request.method == 'POST') {
        final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
        newMasterId = body['id'] as String;
        if (resources.containsKey(newMasterId)) {
          return _json({
            'error': {'code': 409, 'message': 'Already exists'},
          }, 409);
        }
        resources[newMasterId!] = {
          ...body,
          'etag': '"split"',
          'iCalUID': 'new-series@example.test',
        };
        _generate(newMasterId!, following: true);
        if (loseCreateResponse) {
          loseCreateResponse = false;
          throw http.ClientException('Lost create response');
        }
        return _json(resources[newMasterId!]);
      }
      if (request.url.queryParameters['iCalUID'] != null) {
        expect(request.url.queryParameters['singleEvents'], 'false');
        expect(request.url.queryParameters['showDeleted'], 'true');
        return _json({
          'items': [
            resources['master'],
            if (!monthly) ...[resources['old-c'], resources['old-d']],
          ],
        });
      }
      return _json({
        'items': resources.values
            .where((raw) => raw['recurringEventId'] != null)
            .toList(),
        'nextSyncToken': 'cursor',
      });
    }
    final id = suffix.first;
    if (suffix.length == 2 && suffix.last == 'instances') {
      final original = request.url.queryParameters['originalStart'];
      final values = resources.values.where(
        (raw) =>
            raw['recurringEventId'] == id &&
            (original == null ||
                DateTime.parse(
                      (raw['originalStartTime'] as Map)['dateTime'] as String,
                    ) ==
                    DateTime.parse(original)),
      );
      return _json({'items': values.toList()});
    }
    if (request.method == 'GET') {
      if (id == 'new-e' && failLastIdentity) {
        failLastIdentity = false;
        throw http.ClientException('Interrupted local identity reconciliation');
      }
      final raw = resources[id];
      return raw == null
          ? _json({
              'error': {'code': 404, 'message': 'Missing'},
            }, 404)
          : _json(raw);
    }
    if (request.method == 'DELETE') {
      expect(request.headers['if-match'], resources[id]!['etag']);
      resources[id]!['status'] = 'cancelled';
      resources[id]!['etag'] = '"$id-cancelled"';
      if (loseCancellationResponse) {
        loseCancellationResponse = false;
        throw http.ClientException('Lost cancellation response');
      }
      return http.Response('', 204);
    }
    expect(request.method, 'PATCH');
    expect(request.headers['if-match'], resources[id]!['etag']);
    if (id == 'master') {
      masterPatchCount++;
      final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
      resources[id]!.addAll({
        ...body,
        'etag': '"master-after"',
        'updated': '2026-06-01T00:00:00Z',
      });
      if (body.containsKey('start')) {
        expect(
          (body['recurrence'] as List).single,
          contains(monthly ? 'BYMONTHDAY=1' : 'BYDAY=TU'),
        );
        _generate('master', following: false);
      }
      if (loseMasterResponse) {
        loseMasterResponse = false;
        throw http.ClientException('Lost master response');
      }
      return _json(resources[id]);
    }
    final body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
    expect(body, isNot(contains('originalStartTime')));
    expect(body, isNot(contains('recurringEventId')));
    if (failNextExceptionPatch) {
      failNextExceptionPatch = false;
      return _json({
        'error': {'code': 500, 'message': 'Transient fixture error'},
      }, 500);
    }
    resources[id]!.addAll({...body, 'etag': '"$id-restored"'});
    if (loseExceptionResponse) {
      loseExceptionResponse = false;
      throw http.ClientException('Lost exception response');
    }
    return _json(resources[id]);
  }
}
