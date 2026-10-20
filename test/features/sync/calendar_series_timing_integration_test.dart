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
      final item =
          (await ScheduleRepository(database).listItems(
                range: ScheduleRange(
                  start: DateTime.utc(2026, 1),
                  end: DateTime.utc(2026, 8),
                ),
              ))
              .whereType<CalendarScheduleItem>()
              .singleWhere((item) => item.id == original.id);
      var confirmations = 0;
      for (final confirm in [false, true]) {
        expect(
          await ScheduleReschedulingCoordinator(
            repository: repository,
            chooseScope: (_, _) async =>
                RecurringEventMutationScope.entireSeries,
            chooseGuestUpdates: (_) async => throw StateError('No guests'),
            confirmSeriesTimingChange: (change, scope) async {
              confirmations++;
              expect(change.requiresConfirmation, isTrue);
              expect(change.shiftExceptions, isTrue);
              expect(change.originalRule.byMonthDay, [31]);
              expect(change.rule.byMonthDay, [1]);
              expect(change.previewRule(following: false).count, 4);
              expect(await database.select(database.pendingOps).get(), isEmpty);
              return confirm;
            },
            requestSync: (_) async {},
          ).commit(
            ScheduleRescheduleRequest(
              item: item,
              interval: ScheduleInterval(draft.start!, draft.end!),
            ),
          ),
          confirm
              ? ScheduleRescheduleResult.saved
              : ScheduleRescheduleResult.cancelled,
        );
      }
      expect(confirmations, 2);
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

  for (final (drag, interruption) in [
    (false, 'none'),
    (false, 'after-create'),
    (true, 'none'),
  ]) {
    test(
      drag
          ? 'Google coordinator weekday drag keeps its recurrence through sync and restart'
          : 'Google following clock edit keeps the final UNTIL occurrence ($interruption)',
      () async {
        final directory = await createPersistenceTestDirectory(
          'busymax-until-',
        );
        AppDatabase open() => AppDatabase(
          NativeDatabase(File('${directory.path}/fixture.sqlite')),
        );
        var database = open();
        addTearDown(() async {
          await database.close();
          await directory.delete(recursive: true);
        });
        final server = _GoogleSeriesServer(
          clockOnlyUntil: !drag,
          noExceptions: drag,
        );
        final client = GoogleCalendarApiClient(
          httpClient: MockClient(server.respond),
          baseUri: Uri.parse('https://calendar.example.test'),
        );
        CalendarRepository repository() => CalendarRepository(
          database: database,
          now: () => DateTime.utc(2026, 6, 1),
        );
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
                calendarsEnabled: const Value(true),
                createdAtUtc: '2026-06-01T00:00:00Z',
                updatedAtUtc: '2026-06-01T00:00:00Z',
              ),
            );
        await repository().upsertSource(
          accountId: 'account',
          source: const CalendarSourceDto(
            provider: BusyProvider.google,
            providerCalendarId: 'calendar',
            summary: 'Fixture',
            timeZone: 'UTC',
            accessRole: 'owner',
          ),
        );
        for (final raw in server.resources.values) {
          await repository().upsertEvent(
            accountId: 'account',
            event: googleCalendarEventFromJson('calendar', raw),
          );
        }
        final selected = (await database.select(database.calendarEvents).get())
            .singleWhere((row) => row.providerEventId == 'old-b');
        final detail = (await repository().loadEventDetail(selected.id))!;
        final draft = EventEditorDraft.fromEventDetail(detail).copyWith(
          start: DateTime.utc(2026, 6, drag ? 9 : 8, drag ? 9 : 10),
          end: DateTime.utc(2026, 6, drag ? 9 : 8, drag ? 10 : 11),
          recurringMutationScope: drag
              ? RecurringEventMutationScope.entireSeries
              : RecurringEventMutationScope.thisAndFuture,
        );
        final plan = (await repository().prepareSeriesTimingChange(draft))!;
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
                interval: ScheduleInterval(draft.start!, draft.end!),
              ),
            ),
            ScheduleRescheduleResult.saved,
          );
        } else {
          expect(plan.rule.untilRaw, '20260629T100000Z');
          await repository().updateLocalEvent(draft);
        }
        Future<void> check() async {
          final active = (await database.select(database.calendarEvents).get())
              .where(
                (row) =>
                    row.providerRecurringEventId != null &&
                    !row.isDeleted &&
                    !row.isCancelled,
              );
          expect(
            active.map(
              (row) => providerDateTimeAsUtcInstant(
                row.startDateTime,
                row.startTimeZone,
              ),
            ),
            unorderedEquals([
              if (drag) ...[
                for (final day in [2, 9, 16, 23, 30])
                  DateTime.utc(2026, 6, day, 9),
              ] else ...[
                DateTime.utc(2026, 6, 1, 9),
                for (final day in [8, 15, 22, 29])
                  DateTime.utc(2026, 6, day, 10),
              ],
            ]),
          );
        }

        await check();
        await database.close();
        database = open();
        if (interruption == 'after-create') {
          server.loseCreateResponse = true;
          expect(
            await CalendarPendingOpsReplayer(
              database: database,
              client: client,
              accountId: 'account',
              nowUtc: () => DateTime.utc(2026, 6, 1),
            ).replayDueOps(),
            0,
          );
          expect(
            await database.select(database.pendingOps).get(),
            hasLength(1),
          );
          await database.close();
          database = open();
        }
        expect(
          await CalendarPendingOpsReplayer(
            database: database,
            client: client,
            accountId: 'account',
            nowUtc: () => DateTime.utc(2026, 6, 2),
          ).replayDueOps(),
          1,
          reason: (await database.select(database.pendingOps).get())
              .map((op) => op.lastErrorMessage)
              .join('\n'),
        );
        final replacement =
            server.resources[drag ? 'master' : server.newMasterId]!;
        expect(
          (replacement['recurrence'] as List).single,
          contains(drag ? 'BYDAY=TU' : 'UNTIL=20260629T100000Z'),
        );
        expect(
          (replacement['recurrence'] as List).single,
          drag ? contains('COUNT=5') : isNot(contains('COUNT=')),
        );
        expect(server.masterPatchCount, 1);
        await check();
        final sync = CalendarSyncEngine(
          database: database,
          client: client,
          accountId: 'account',
          nowUtc: () => DateTime.utc(2026, 6, 2),
        );
        await sync.fullSync();
        await sync.incrementalSync();
        await database.close();
        database = open();
        await check();
        expect(await database.select(database.pendingOps).get(), isEmpty);
      },
    );
  }

  for (final (scope, workflow) in [
    for (final scope in ['entire', 'following', 'following-first'])
      (scope, 'editor'),
    for (final scope in ['entire', 'following']) (scope, 'properties'),
    for (final scope in ['entire', 'following']) (scope, 'drag'),
  ]) {
    final drag = workflow == 'drag';
    final properties = workflow == 'properties';
    final following = scope != 'entire';
    final split = scope == 'following';
    final first = scope == 'following-first';
    for (final interruption
        in workflow != 'editor'
            ? [
                'none',
                'after-exception',
                if (properties) ...[
                  'after-properties',
                  'after-properties-conflict',
                ],
              ]
            : first
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
        'Google $workflow $scope edit preserves exception schedules and association ($interruption)',
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

          final server = _GoogleSeriesServer(nonTimingExceptions: properties);
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
          final draft = EventEditorDraft.fromEventDetail(detail).copyWith(
            start: DateTime.utc(2026, 6, first ? 2 : 9, 9),
            end: DateTime.utc(2026, 6, first ? 2 : 9, 10),
            recurringMutationScope: following
                ? RecurringEventMutationScope.thisAndFuture
                : RecurringEventMutationScope.entireSeries,
          );
          if (drag) {
            final item =
                (await ScheduleRepository(database).listItems(
                      range: ScheduleRange(
                        start: DateTime.utc(2026, 6, 1),
                        end: DateTime.utc(2026, 7, 1),
                      ),
                    ))
                    .whereType<CalendarScheduleItem>()
                    .singleWhere((item) => item.id == selected.id);
            expect(
              await ScheduleReschedulingCoordinator(
                repository: repository(),
                chooseScope: (_, _) async => draft.recurringMutationScope,
                chooseGuestUpdates: (_) async => throw StateError('No guests'),
                requestSync: (_) async {},
              ).commit(
                ScheduleRescheduleRequest(
                  item: item,
                  interval: ScheduleInterval(draft.start!, draft.end!),
                ),
              ),
              ScheduleRescheduleResult.saved,
            );
          } else {
            await repository().updateLocalEvent(draft);
          }
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
              DateTime.utc(2026, 6, drag ? 18 : 17, 13),
            );
            expect(
              providerDateTimeAsUtcInstant(
                exception.endDateTime,
                exception.endTimeZone,
              ),
              DateTime.utc(2026, 6, drag ? 18 : 17, 15),
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
            ..loseNonTimingResponse = interruption.startsWith(
              'after-properties',
            )
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
          if (interruption == 'after-properties-conflict') {
            server.resources['new-b']!.addAll({
              'summary': 'Further remote edit',
              'etag': '"new-b-remote"',
            });
            expect(await replay(DateTime.utc(2026, 6, 2)), 0);
            final pending = await database
                .select(database.pendingOps)
                .getSingle();
            expect(pending.lastErrorCode, 'conflict');
            expect(pending.requestJson, contains('Customized title'));
            expect(
              server.resources['new-b']!['summary'],
              'Further remote edit',
            );
            expect(server.resources['new-b']!['etag'], '"new-b-remote"');
            await reopen();
            expect(await replay(DateTime.utc(2026, 6, 3)), 0);
            expect(
              await database.select(database.pendingOps).get(),
              hasLength(1),
            );
            return;
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
          expect(
            DateTime.parse((moved['start'] as Map)['dateTime'] as String),
            DateTime.utc(2026, 6, drag ? 18 : 17, 13),
          );
          expect(
            DateTime.parse((moved['end'] as Map)['dateTime'] as String),
            DateTime.utc(2026, 6, drag ? 18 : 17, 15),
          );
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
          if (properties) {
            final title = server.resources['new-b']!;
            expect(title['summary'], 'Customized title');
            expect(
              DateTime.parse((title['start'] as Map)['dateTime'] as String),
              DateTime.utc(2026, 6, 9, 9),
            );
            final reminder = server.resources['new-e']!;
            expect(
              reminder['reminders'],
              server.resources['old-e']!['reminders'],
            );
            expect(
              DateTime.parse((reminder['start'] as Map)['dateTime'] as String),
              DateTime.utc(2026, 6, 30, 9),
            );
            for (final (id, day) in [('new-b', 9), ('new-e', 30)]) {
              final patch = server.exceptionPatches[id]!;
              expect(
                DateTime.parse((patch['start'] as Map)['dateTime'] as String),
                DateTime.utc(2026, 6, day, 9),
              );
              expect(
                DateTime.parse((patch['end'] as Map)['dateTime'] as String),
                DateTime.utc(2026, 6, day, 10),
              );
            }
          }
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
            DateTime.utc(2026, 6, drag ? 18 : 17, 13),
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
          if (properties) {
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
              server.resources['old-e']!['reminders'],
            );
          }
        },
      );
    }
  }
}

/// HTTP fixtures use opaque IDs and explicit recurrence identities. Resolving
/// an instance must go through events.instances; no provider ID encoding is
/// assumed by either the test or production code.
class _GoogleSeriesServer {
  _GoogleSeriesServer({
    this.monthly = false,
    this.clockOnlyUntil = false,
    this.nonTimingExceptions = false,
    this.noExceptions = false,
  }) {
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
    if (clockOnlyUntil) {
      resources['master']!['recurrence'] = [
        'RRULE:FREQ=WEEKLY;BYDAY=MO;UNTIL=20260629T090000Z',
      ];
      return;
    }
    if (noExceptions) return;
    if (nonTimingExceptions) {
      resources['old-b']!['summary'] = 'Customized title';
      resources['old-e']!['reminders'] = {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 45},
        ],
      };
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
  final bool clockOnlyUntil;
  final bool nonTimingExceptions;
  final bool noExceptions;
  final resources = <String, Map<String, Object?>>{};
  final exceptionPatches = <String, Map<String, Object?>>{};
  int masterPatchCount = 0;
  bool failNextExceptionPatch = false;
  bool loseMasterResponse = false;
  bool loseExceptionResponse = false;
  bool loseNonTimingResponse = false;
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
    if (clockOnlyUntil) {
      final master = resources[series]!;
      final start = DateTime.parse(
        (master['start'] as Map)['dateTime'] as String,
      );
      final rule = (master['recurrence'] as List).single as String;
      final until = DateTime.parse(
        RegExp(r'UNTIL=([^;]+)').firstMatch(rule)![1]!,
      );
      // An independent bounded fixture for the documented weekly UTC rule:
      // UNTIL includes candidates equal to the boundary, never later ones.
      for (final entry in {
        'new-b': 8,
        'new-c': 15,
        'new-d': 22,
        'new-e': 29,
      }.entries) {
        final candidate = DateTime.utc(2026, 6, entry.value, start.hour);
        if (!candidate.isBefore(start) && !candidate.isAfter(until)) {
          resources[entry.key] = _instance(
            entry.key,
            series,
            entry.value,
            date: candidate,
          );
        }
      }
      for (final id in ['old-b', 'old-c', 'old-d', 'old-e']) {
        resources[id]!['status'] = 'cancelled';
      }
      return;
    }
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
      if (!following && id == 'old-c' && !noExceptions) continue;
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
        expect(
          (body['recurrence'] as List).single,
          contains(clockOnlyUntil ? 'BYDAY=MO' : 'BYDAY=TU'),
        );
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
            if (!monthly && !clockOnlyUntil && !noExceptions) ...[
              resources['old-c'],
              resources['old-d'],
              if (nonTimingExceptions) ...[
                resources['old-b'],
                resources['old-e'],
              ],
            ],
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
    exceptionPatches[id] = body;
    expect(body, isNot(contains('originalStartTime')));
    expect(body, isNot(contains('recurringEventId')));
    if (failNextExceptionPatch) {
      failNextExceptionPatch = false;
      return _json({
        'error': {'code': 500, 'message': 'Transient fixture error'},
      }, 500);
    }
    resources[id]!.addAll({...body, 'etag': '"$id-restored"'});
    // A provider response may normalize equivalent RFC3339 representations.
    // Preserve the written request separately so retry tests cross this real
    // transport boundary instead of relying on byte-identical echoed JSON.
    for (final field in ['start', 'end']) {
      final temporal = resources[id]![field];
      if (temporal is Map && temporal['dateTime'] is String) {
        resources[id]![field] = {
          ...temporal,
          'dateTime': DateTime.parse(temporal['dateTime'] as String)
              .toUtc()
              .toIso8601String()
              .replaceFirst('.000Z', 'Z'),
        };
      }
    }
    if (loseExceptionResponse) {
      loseExceptionResponse = false;
      throw http.ClientException('Lost exception response');
    }
    if (loseNonTimingResponse && id == 'new-b') {
      loseNonTimingResponse = false;
      throw http.ClientException('Lost title-only exception response');
    }
    return _json(resources[id]);
  }
}
