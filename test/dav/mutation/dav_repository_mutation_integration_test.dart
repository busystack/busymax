import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/calendar_providers/calendar_mutation.dart';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/ical/ical_recurrence.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/calendar/domain/event_timing_policy.dart';
import 'package:busymax/src/features/recurrence/domain/series_timing_change.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:busymax/src/features/maps/data/location_resolution_repository.dart';
import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:busymax/src/core/time/stored_temporal_projection.dart';
import 'package:busymax/src/schedule/schedule_event_rescheduling.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/persistence_test_directory.dart';

void main() {
  late AppDatabase database;
  late DavObjectRepository objectRepository;
  late CalendarRepository calendarRepository;
  late TasksRepository tasksRepository;
  late int notificationChanges;
  Directory? persistenceDirectory;
  late int objectSequence;

  void attachRepositories() {
    objectRepository = DavObjectRepository(
      database: database,
      idFactory: () => 'dav-object-${objectSequence += 1}',
    );
    calendarRepository = CalendarRepository(
      database: database,
      now: () => _now,
      localTimeZone: 'America/Vancouver',
      onNotificationScheduleChanged: () async => notificationChanges += 1,
    );
    tasksRepository = TasksRepository(
      database: database,
      accountId: _accountId,
      nowUtc: () => _now,
      onNotificationScheduleChanged: () async => notificationChanges += 1,
    );
  }

  Future<void> reopen() async {
    await database.close();
    database = AppDatabase(
      NativeDatabase(File('${persistenceDirectory!.path}/busymax.sqlite')),
    );
    attachRepositories();
  }

  Future<void> usePersistentFixture() async {
    persistenceDirectory = await createPersistenceTestDirectory(
      'busymax-dav-lifecycle-',
    );
    await reopen();
    await _seedDavAccount(database);
  }

  Future<void> replayResource(String candidate) async {
    var puts = 0;
    final transport = DavHttpTransport(
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          expect(request.headers['if-match'], '"one"');
          expect(request.body, candidate);
          puts++;
          return http.Response('', 204, headers: {'etag': '"returned"'});
        }
        expect(request.method, 'GET');
        return http.Response(
          candidate,
          200,
          headers: {'etag': '"returned"', 'content-type': 'text/calendar'},
        );
      }),
      profile: davProviderProfile(
        BusyProvider.nextcloud,
        nextcloudServer: Uri.parse('https://cloud.example.test'),
      ),
      accountAuthority: Uri.parse('https://cloud.example.test'),
    );
    final result = await DavPendingOperationsReplayer(
      database: database,
      accountId: _accountId,
      objectRepository: objectRepository,
      nowUtc: () => _now,
      serviceFactory: ({required account, required collection}) async =>
          DavConditionalMutationService(
            remoteClient: DavMutationHttpClient(
              transport: transport,
              accountId: _accountId,
              collectionId: _collectionId,
              credential: DavBasicCredential(
                username: 'alex',
                password: 'fixture-password',
              ),
            ),
            nowUtc: () => _now,
          ),
    ).replayDueOperations();
    expect(result.appliedCount, 1);
    expect(result.conflictCount, 0);
    expect(puts, 1);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  }

  setUp(() async {
    persistenceDirectory = null;
    objectSequence = 0;
    notificationChanges = 0;
    database = AppDatabase(NativeDatabase.memory());
    attachRepositories();
    await _seedDavAccount(database);
  });

  tearDown(() async {
    await database.close();
    await persistenceDirectory?.delete(recursive: true);
  });

  for (final deadline in [false, true]) {
    test(
      'pending DAV task retains explicit deadline eligibility ($deadline)',
      () async {
        await usePersistentFixture();
        await tasksRepository.createTask(
          _taskListId,
          TaskCreateInput(
            title: 'Pending task',
            fields: {
              'microsoftStartDateTime': '2026-08-10',
              if (deadline) 'microsoftDueDateTime': '2026-08-11',
            },
          ),
        );
        await reopen();
        final task = await database.select(database.tasks).getSingle();
        expect(
          taskDeadlineAsLocal(task),
          deadline ? DateTime(2026, 8, 11) : isNull,
        );
        expect(await database.select(database.pendingOps).get(), hasLength(1));
        if (deadline) {
          await tasksRepository.patchTask(
            _taskListId,
            task.id,
            const TaskPatchInput({'microsoftDueDateTime': null}),
          );
          await reopen();
          final cleared = await database.select(database.tasks).getSingle();
          expect(taskDeadlineAsLocal(cleared), isNull);
          expect(taskDueAsLocal(cleared), DateTime(2026, 8, 10));
        }
      },
    );
  }

  test('pending DAV recurring completion advances the active projection before replay', () async {
    await usePersistentFixture();
    await tasksRepository.createTask(
      _taskListId,
      const TaskCreateInput(
        title: 'Pending recurring',
        fields: {
          'microsoftDueDateTime': '2026-08-10',
          'recurrence': {
            'rules': ['FREQ=DAILY;COUNT=2'],
            'dates': <String>[],
            'excludedDates': <String>[],
          },
        },
      ),
    );
    final task = await database.select(database.tasks).getSingle();
    await tasksRepository.patchTask(
      _taskListId,
      task.id,
      const TaskPatchInput({'status': 'completed'}),
    );
    await reopen();
    final next = await database.select(database.tasks).getSingle();
    expect(next.status, 'needsAction');
    expect(taskDeadlineAsLocal(next), DateTime(2026, 8, 11));
    expect(await database.select(database.pendingOps).get(), hasLength(1));
  });

  for (final following in [false, true]) {
    test(
      'cleared ${following ? 'following' : 'detached'} occurrence alarms stay cleared through resource projection',
      () async {
        await usePersistentFixture();
        final baseline = _recurringEventResource().replaceFirst(
          'X-SERIES-KEEP:opaque',
          'X-SERIES-KEEP:opaque\r\nBEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT10M\r\nDESCRIPTION:Reminder\r\nEND:VALARM',
        );
        const href = '${_collectionHref}alarms.ics';
        await _commitObjects(objectRepository, [
          _prepared(href: href, etag: '"one"', body: baseline),
        ]);
        final occurrence =
            (await database.select(database.calendarEvents).get()).singleWhere(
              (row) => row.occurrenceKey!.contains('2026-08-10T09:00:00'),
            );
        await calendarRepository.updateLocalEvent(
          _draftForEvent(occurrence).copyWith(
            reminders: {'minutes': <int>[]},
            recurringMutationScope: following
                ? RecurringEventMutationScope.thisAndFuture
                : RecurringEventMutationScope.singleOccurrence,
          ),
        );
        final candidate = await _serializedPendingDavMutation(
          database,
          baseline,
        );
        final exception = IcalSemanticDocument.parse(candidate).components
            .singleWhere(
              (component) =>
                  component.recurrenceId?.rawValue == '20260810T090000Z',
            );
        expect(exception.alarms, isEmpty);
        Future<void> check() async {
          final events = await database.select(database.calendarEvents).get();
          expect(
            (jsonDecode(
              events
                  .singleWhere((row) => row.id == occurrence.id)
                  .remindersJson!,
            ) as Map)['alarms'],
            isEmpty,
          );
          await NotificationScheduleService(
            database: database,
            nowUtc: () => DateTime.utc(2026, 8, 8, 8),
          ).rebuildUpcomingEventNotifications(_accountId);
          final reminders = await database
              .select(database.notificationSchedule)
              .get();
          expect(
            reminders.where((row) => row.sourceId == occurrence.id),
            isEmpty,
          );
          expect(reminders, isNotEmpty);
        }

        await check();
        await reopen();
        await check();
        await replayResource(candidate);
        await reopen();
        await check();
      },
    );
  }

  for (final rule in [
    'FREQ=DAILY;UNTIL=20260810',
    'FREQ=DAILY;COUNT=1',
    'FREQ=DAILY;COUNT=2',
  ]) {
    test(
      'recurring task completion projects the current actionable state for $rule',
      () async {
        await usePersistentFixture();
        final baseline = _taskResource(
          uid: 'final-task',
          summary: 'Recurring',
          extra: [
            'DTSTART;VALUE=DATE:20260809',
            'DUE;VALUE=DATE:20260810',
            'RRULE:$rule',
            'STATUS:NEEDS-ACTION',
          ],
        );
        const href = '${_collectionHref}final-task.ics';
        await _commitObjects(objectRepository, [
          _prepared(href: href, etag: '"one"', body: baseline),
        ]);
        final masterId = (await database.select(database.tasks).getSingle()).id;
        await tasksRepository.patchTask(
          _taskListId,
          masterId,
          const TaskPatchInput({'status': 'completed'}),
        );
        final master = (await database.select(database.tasks).get())
            .singleWhere((row) => row.recurrenceIdKey == null);
        final exhausted = !rule.endsWith('COUNT=2');
        expect(master.status, exhausted ? 'completed' : 'needsAction');
        final candidate = await _serializedPendingDavMutation(
          database,
          baseline,
        );
        final semantic = IcalSemanticDocument.parse(candidate);
        expect(semantic.components, hasLength(2));
        if (rule.contains('UNTIL')) {
          expect(
            semantic.components
                .singleWhere((row) => row.recurrenceId == null)
                .status,
            'NEEDS-ACTION',
          );
          await tasksRepository.patchTask(
            _taskListId,
            masterId,
            const TaskPatchInput({'status': 'completed'}),
          );
        }
        await reopen();
        await replayResource(candidate);
        await reopen();
        expect(
          (await database.select(database.tasks).get())
              .singleWhere((row) => row.id == masterId)
              .status,
          exhausted ? 'completed' : 'needsAction',
        );
        if (exhausted) {
          final editedCompletion = DateTime.utc(2026, 8, 8, 7);
          await tasksRepository.patchTask(
            _taskListId,
            masterId,
            TaskPatchInput({
              'completedAtUtc': editedCompletion.toIso8601String(),
            }),
          );
          expect(
            DateTime.parse(
              (await database.select(database.tasks).get())
                  .singleWhere((row) => row.id == masterId)
                  .completedUtc!,
            ),
            editedCompletion,
          );
          await tasksRepository.patchTask(
            _taskListId,
            masterId,
            const TaskPatchInput({'status': 'needsAction'}),
          );
          expect(
            (await database.select(database.tasks).get())
                .singleWhere((row) => row.id == masterId)
                .status,
            isNot('completed'),
          );
          await reopen();
          final taskTrees = await database.tasksDao.watchAllTaskTrees([
            _accountId,
          ]).first;
          expect(
            taskTrees.where(
              (row) => !['completed', 'cancelled'].contains(row.task.status),
            ),
            hasLength(1),
          );
          final openItems = await ScheduleRepository(database).listItems(
            range: ScheduleRange(
              start: DateTime(2026, 8),
              end: DateTime(2026, 9),
            ),
            filters: const ScheduleFilters(
              taskCompletion: ScheduleTaskCompletion.open,
            ),
          );
          expect(openItems.whereType<TaskScheduleItem>(), hasLength(1));
          await tasksRepository.patchTask(
            _taskListId,
            masterId,
            const TaskPatchInput({'status': 'completed'}),
          );
          expect(
            (await database.select(database.tasks).get())
                .singleWhere((row) => row.id == masterId)
                .status,
            'completed',
          );
          expect(await database.select(database.tasks).get(), hasLength(2));
        }
      },
    );
  }

  for (final remove in [false, true]) {
    test(
      'Nextcloud ${remove ? 'removes' : 'adds'} URI ATTACH through DAV queue',
      () async {
        final baseline = _ical([
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'BEGIN:VEVENT',
          'UID:attachment@example.test',
          'DTSTART:20260810T090000Z',
          'DTEND:20260810T100000Z',
          'SUMMARY:Attachment event',
          'X-CUSTOM;X-KEEP=one:untouched',
          'ATTACH;VALUE=BINARY;ENCODING=BASE64:YWJj',
          'ATTACH;FMTTYPE=application/pdf:https://files.example/old.pdf',
          'END:VEVENT',
          'END:VCALENDAR',
        ]);
        await _commitObjects(objectRepository, [
          _prepared(
            href: '${_collectionHref}attachment.ics',
            etag: '"attachment"',
            body: baseline,
          ),
        ]);
        final event = await database
            .select(database.calendarEvents)
            .getSingle();
        final detail = await calendarRepository
            .changeNextcloudUriAttachmentReference(
              accountId: _accountId,
              eventId: event.id,
              addUrl: remove ? null : 'https://files.example/new.pdf',
              removeUrl: remove ? 'https://files.example/old.pdf' : null,
            );
        final operation = await database
            .select(database.pendingOps)
            .getSingle();
        expect(operation.operationType, 'dav.update');
        final candidate = DavMutationPatch.fromJsonString(
          operation.mutationPatchJson!,
        ).applyTo(baseline, nowUtc: _now);
        expect(candidate, contains('ATTACH;VALUE=BINARY;ENCODING=BASE64:YWJj'));
        expect(candidate, contains('X-CUSTOM;X-KEEP=one:untouched'));
        expect(candidate.contains('https://files.example/old.pdf'), !remove);
        expect(candidate.contains('https://files.example/new.pdf'), !remove);
        expect(
          jsonEncode(detail!.attachments),
          remove ? isNot(contains('old.pdf')) : contains('new.pdf'),
        );
      },
    );
  }

  test('timing-only occurrence exception retains guests, alarms and opaque provider fields', () async {
    await _seedScheduling(database, 'owner@example.test');
    final baseline = _recurringEventResource().replaceFirst(
      'X-SERIES-KEEP:opaque',
      'X-SERIES-KEEP:opaque\r\nATTENDEE;CN=Guest:mailto:guest@example.test\r\n'
          'ORGANIZER:mailto:owner@example.test\r\nATTACH:https://example.test/agenda.pdf\r\n'
          'X-ALT-DESC;FMTTYPE=text/html:<p>Full HTML</p>\r\nBEGIN:VALARM\r\n'
          'ACTION:DISPLAY\r\nTRIGGER:-PT10M\r\nDESCRIPTION:Reminder\r\nEND:VALARM',
    );
    await _commitObjects(objectRepository, [
      _prepared(
        href: '${_collectionHref}timing-series.ics',
        etag: '"timing"',
        body: baseline,
      ),
    ]);
    final row = (await database.select(database.calendarEvents).get())
        .singleWhere(
          (row) => row.occurrenceKey!.contains('2026-08-10T09:00:00'),
        );
    final detail = (await calendarRepository.loadEventDetail(row.id))!;
    await calendarRepository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail).copyWith(
        start: DateTime.utc(2026, 8, 10, 13),
        end: DateTime.utc(2026, 8, 10, 14),
        recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
      ),
      timingBaseline: EventTimingBaseline.fromDetail(detail),
    );
    final operation = await database.select(database.pendingOps).getSingle();
    final candidate = DavMutationPatch.fromJsonString(
      operation.mutationPatchJson!,
    ).applyTo(baseline, nowUtc: _now);
    final exception = IcalSemanticDocument.parse(candidate).components
        .singleWhere(
          (component) => component.recurrenceId?.rawValue == '20260810T090000Z',
        );
    expect(exception.start!.rawValue, '20260810T130000Z');
    expect(exception.attendees, hasLength(1));
    expect(exception.organizers, hasLength(1));
    expect(exception.alarms, hasLength(1));
    expect(
      exception.documentComponent.firstProperty('ATTACH')!.rawValue,
      'https://example.test/agenda.pdf',
    );
    expect(
      exception.documentComponent.firstProperty('X-ALT-DESC')!.rawValue,
      '<p>Full HTML</p>',
    );
    expect(exception.documentComponent.firstProperty('RRULE'), isNull);
    expect(candidate, contains('SUMMARY:Existing exception'));
    expect(
      (await calendarRepository.loadEventDetail(row.id))!
          .providerOriginalStartKey,
      detail.providerOriginalStartKey,
    );
  });

  for (final floating in [false, true]) {
    test(
      'rescheduling preserves ${floating ? 'floating' : 'embedded custom-zone'} DAV representation',
      () async {
        final zone = floating ? '' : ';TZID=Custom/Office';
        final body = _ical([
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'PRODID:-//BusyMax test//EN',
          if (!floating) ...[
            'BEGIN:VTIMEZONE',
            'TZID:Custom/Office',
            'BEGIN:STANDARD',
            'DTSTART:20200101T000000',
            'TZOFFSETFROM:+0545',
            'TZOFFSETTO:+0545',
            'END:STANDARD',
            'END:VTIMEZONE',
          ],
          'BEGIN:VEVENT',
          'UID:reschedule-zone',
          'DTSTAMP:20260808T080000Z',
          'DTSTART$zone:20260808T090000',
          'DTEND$zone:20260808T100000',
          'SUMMARY:Zoned',
          'X-KEEP:opaque',
          'END:VEVENT',
          'END:VCALENDAR',
        ]);
        await _commitObjects(objectRepository, [
          _prepared(
            href: '${_collectionHref}zone-event.ics',
            etag: '"zone"',
            body: body,
          ),
        ]);
        final row = await database.select(database.calendarEvents).getSingle();
        final detail = (await calendarRepository.loadEventDetail(row.id))!;
        final start = floating
            ? DateTime(2026, 8, 8, 11)
            : DateTime.utc(2026, 8, 8, 5, 15).toLocal();
        final item = CalendarScheduleItem(
          id: detail.id,
          accountId: detail.accountId,
          provider: detail.provider,
          sourceId: detail.sourceId,
          providerCalendarId: detail.providerCalendarId,
          title: detail.title,
          allDay: false,
          start: providerDateTimeAsLocal(
            detail.startDateTime,
            detail.startTimeZone,
          ),
          end: providerDateTimeAsLocal(detail.endDateTime, detail.endTimeZone),
          timingBaseline: EventTimingBaseline.fromDetail(detail),
        );
        final result =
            await ScheduleReschedulingCoordinator(
              repository: calendarRepository,
              chooseScope: (_, _) async => null,
              chooseGuestUpdates: (_) async =>
                  throw StateError('DAV organizer is nullable'),
              requestSync: (_) async {},
            ).commit(
              ScheduleRescheduleRequest(
                item: item,
                interval: ScheduleInterval(
                  start,
                  start.add(const Duration(hours: 1)),
                ),
              ),
            );
        expect(result, ScheduleRescheduleResult.saved);
        final pending = await database.select(database.pendingOps).getSingle();
        final candidate = DavMutationPatch.fromJsonString(
          pending.mutationPatchJson!,
        ).applyTo(body, nowUtc: _now);
        expect(candidate, contains('DTSTART$zone:20260808T110000'));
        expect(candidate, contains('DTEND$zone:20260808T120000'));
        expect(candidate, contains('X-KEEP:opaque'));
        expect(candidate.contains('BEGIN:VTIMEZONE'), !floating);
        final savedRow = await database
            .select(database.calendarEvents)
            .getSingle();
        final saved = (await calendarRepository.loadEventDetail(savedRow.id))!;
        expect(saved.startTimeZone, detail.startTimeZone);
        expect(saved.endTimeZone, detail.endTimeZone);
      },
    );
  }

  test(
    'event create, unsent update, and delete remain one local unit',
    () async {
      await calendarRepository.createLocalEvent(
        _newEventDraft().copyWith(
          title: 'Local event',
          description: 'Initial notes',
          categories: const ['Work'],
        ),
      );

      var events = await database.select(database.calendarEvents).get();
      var operations = await database.select(database.pendingOps).get();
      expect(events, hasLength(1));
      expect(events.single.id, startsWith('dav-local-event-'));
      expect(events.single.davCollectionId, _collectionId);
      expect(events.single.davObjectId, isNull);
      expect(events.single.syncStatus, 'pending');
      expect(operations, hasLength(1));
      expect(operations.single.operationType, 'dav.create');
      expect(operations.single.eventId, events.single.id);
      expect(_createRaw(operations.single), contains('SUMMARY:Local event'));
      expect(_createRaw(operations.single), contains('CATEGORIES:Work'));

      await calendarRepository.updateLocalEvent(
        _draftForEvent(events.single)
            .copyWith(title: 'Edited before upload', location: 'Room 4'),
      );

      events = await database.select(database.calendarEvents).get();
      operations = await database.select(database.pendingOps).get();
      expect(events.single.title, 'Edited before upload');
      expect(events.single.location, 'Room 4');
      expect(operations, hasLength(1));
      expect(operations.single.operationType, 'dav.create');
      expect(
        _createRaw(operations.single),
        contains('SUMMARY:Edited before upload'),
      );
      expect(_createRaw(operations.single), contains('LOCATION:Room 4'));

      await calendarRepository.deleteLocalEvent(events.single.id);

      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(notificationChanges, 3);
    },
  );

  test(
    'confirmed event update retains raw baseline and unknown data',
    () async {
      const href = '${_collectionHref}confirmed-event.ics';
      final baseline = _eventResource(
        uid: 'confirmed-event@example.test',
        summary: 'Server title',
        extra: const ['X-KEEP-EXACT;X-QUOTE="a,b":opaque'],
      );
      await _commitObjects(objectRepository, [
        _prepared(href: href, etag: 'W/"event-etag"', body: baseline),
      ]);
      var event = await database.select(database.calendarEvents).getSingle();
      expect(event.providerRecurringEventId, isNull);

      await calendarRepository.updateLocalEvent(
        _draftForEvent(event).copyWith(title: 'Local title'),
      );

      var operation = await database.select(database.pendingOps).getSingle();
      expect(operation.operationType, 'dav.update');
      expect(operation.baselineEtag, 'W/"event-etag"');
      expect(operation.baselineRawIcs, baseline);
      final patch = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      );
      final candidate = patch.applyTo(operation.baselineRawIcs!, nowUtc: _now);
      expect(candidate, contains('SUMMARY:Local title'));
      expect(candidate, contains('X-KEEP-EXACT;X-QUOTE="a,b":opaque'));

      event = await database.select(database.calendarEvents).getSingle();
      expect(event.title, 'Local title');
      expect(event.syncStatus, 'pending');

      await calendarRepository.deleteLocalEvent(event.id);

      operation = await database.select(database.pendingOps).getSingle();
      expect(operation.operationType, 'dav.delete');
      expect(operation.baselineEtag, 'W/"event-etag"');
      expect(operation.baselineRawIcs, baseline);
      expect(
        (await database.select(database.calendarEvents).getSingle()).isDeleted,
        isTrue,
      );
    },
  );

  test('same-account Nextcloud event move uses WebDAV MOVE', () async {
    await _seedDestinationCalendar(database);
    const href = '${_collectionHref}move-event.ics';
    const keep = 'X-KEEP-EXACT;X-QUOTE="a,b":opaque';
    const alarm = [
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:Imported reminder',
      'TRIGGER:-PT17M',
      'X-ALARM-KEEP:opaque',
      'END:VALARM',
    ];
    final baseline = _eventResource(
      uid: 'move-event@example.test',
      summary: 'Server title',
      extra: const [keep, ...alarm],
    );
    await _commitObjects(objectRepository, [
      _prepared(href: href, etag: '"move-event"', body: baseline),
    ]);
    final event = await database.select(database.calendarEvents).getSingle();

    await calendarRepository.updateLocalEvent(
      _draftForEvent(event).copyWith(
        sourceId: _destinationCalendarSourceId,
        providerCalendarId: _destinationCollectionHref,
        title: 'Moved title',
      ),
    );

    final operation = await database.select(database.pendingOps).getSingle();
    expect(operation.operationType, 'dav.move');
    expect(operation.davCollectionId, _collectionId);
    expect(operation.destinationCollectionId, _destinationCollectionId);
    expect(operation.baselineRawIcs, baseline);
    final patch = DavMutationPatch.fromJsonString(operation.mutationPatchJson!);
    final movedRaw = patch.applyTo(operation.baselineRawIcs!, nowUtc: _now);
    expect(movedRaw, contains('SUMMARY:Moved title'));
    expect(movedRaw, contains(keep));
    expect(movedRaw, contains(alarm.join('\r\n')));

    final projected = await database
        .select(database.calendarEvents)
        .getSingle();
    expect(projected.calendarSourceId, _destinationCalendarSourceId);
    expect(projected.providerCalendarId, _destinationCollectionHref);
    expect(projected.davCollectionId, _destinationCollectionId);
    expect(projected.syncStatus, 'pending');
  });

  test(
    'DAV event attendee mutation is rejected without local side effects',
    () async {
      await expectLater(
        calendarRepository.createLocalEvent(
          _newEventDraft().copyWith(
            title: 'Invitation',
            attendees: const [EventAttendeeDraft(email: 'guest@example.test')],
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );

      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test(
    'Nextcloud meeting creation retains participant parameters while pending',
    () async {
      await _seedScheduling(database, 'owner@example.test');
      await calendarRepository.createLocalEvent(
        _newEventDraft().copyWith(
          title: 'Meeting',
          attendees: const [
            EventAttendeeDraft(
              email: 'guest@example.test',
              displayName: 'Guest',
              optional: true,
            ),
          ],
        ),
      );
      final event = await database.select(database.calendarEvents).getSingle();
      final detail = (await calendarRepository.loadEventDetail(event.id))!;
      final draft = EventEditorDraft.fromEventDetail(detail);
      expect(draft.attendees.single.email, 'guest@example.test');
      expect(draft.attendees.single.optional, isTrue);
      expect(draft.isOrganizer, isTrue);
      expect(event.syncStatus, 'pending');
      final operation = await database.select(database.pendingOps).getSingle();
      final request = jsonDecode(operation.requestJson) as Map;
      expect(request.toString(), contains('mailto:owner@example.test'));
      expect(request.toString(), contains('ROLE=OPT-PARTICIPANT'));
      expect(request['suppressScheduling'], isNot(true));
    },
  );

  test(
    'Nextcloud occurrence reply persists only self response and requires scope',
    () async {
      await _seedScheduling(database, 'guest@example.test');
      final baseline = _recurringEventResource().replaceFirst(
        'X-SERIES-KEEP:opaque',
        'X-SERIES-KEEP:opaque\r\nORGANIZER:mailto:owner@example.test\r\n'
            'ATTENDEE;CN=Guest;ROLE=OPT-PARTICIPANT;PARTSTAT=NEEDS-ACTION;X-KEEP=yes:mailto:guest@example.test',
      );
      await _commitObjects(objectRepository, [
        _prepared(
          href: '${_collectionHref}reply.ics',
          etag: '"meeting"',
          body: baseline,
        ),
      ]);
      final event = (await database.select(database.calendarEvents).get())
          .singleWhere((e) => e.occurrenceKey!.contains('2026-08-10T09:00:00'));
      await expectLater(
        calendarRepository.respondToLocalEvent(
          event.id,
          CalendarInvitationResponse.accept,
        ),
        throwsUnsupportedError,
      );
      expect(await database.select(database.pendingOps).get(), isEmpty);
      await calendarRepository.respondToLocalEvent(
        event.id,
        CalendarInvitationResponse.accept,
        recurringScope: RecurringEventMutationScope.singleOccurrence,
      );
      final operation = await database.select(database.pendingOps).getSingle();
      final candidate = IcalSemanticDocument.parse(
        DavMutationPatch.fromJsonString(operation.mutationPatchJson!)
            .applyTo(baseline, nowUtc: _now),
      );
      final exception = candidate.components.singleWhere(
        (c) => c.recurrenceId?.rawValue == '20260810T090000Z',
      );
      expect(
        exception.documentComponent
            .firstProperty('ATTENDEE')!
            .parameterValue('PARTSTAT'),
        'ACCEPTED',
      );
      expect(
        exception.documentComponent
            .firstProperty('ATTENDEE')!
            .parameterValue('X-KEEP'),
        'yes',
      );
      expect(
        exception.documentComponent
            .firstProperty('ATTENDEE')!
            .parameterValue('ROLE'),
        'OPT-PARTICIPANT',
      );
      expect(exception.sequence, candidate.components.first.sequence);
      expect(
        candidate.components.first.documentComponent
            .firstProperty('ATTENDEE')!
            .parameterValue('PARTSTAT'),
        'NEEDS-ACTION',
      );
      expect(operation.operationType, 'dav.update');
      expect(
        (await database.select(database.calendarEvents).get()).where(
          (e) => e.syncStatus == 'pending',
        ),
        isNotEmpty,
      );
    },
  );

  test(
    'several offline occurrence edits serialize as one resource mutation',
    () async {
      final baseline = _recurringEventResource();
      await _commitObjects(objectRepository, [
        _prepared(
          href: '${_collectionHref}offline-series.ics',
          etag: '"series"',
          body: baseline,
        ),
      ]);
      for (final (day, title) in [
        (10, 'First change'),
        (9, 'Second change'),
        (10, 'First revised'),
      ]) {
        final event = (await database.select(database.calendarEvents).get())
            .singleWhere(
              (e) => e.occurrenceKey!.contains(
                '2026-08-${day.toString().padLeft(2, '0')}T09:00:00',
              ),
            );
        final detail = (await calendarRepository.loadEventDetail(event.id))!;
        await calendarRepository.updateLocalEvent(
          EventEditorDraft.fromEventDetail(detail).copyWith(
            title: title,
            recurringMutationScope:
                RecurringEventMutationScope.singleOccurrence,
          ),
        );
      }
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.baselineEtag, '"series"');
      final saved = IcalSemanticDocument.parse(
        DavMutationPatch.fromJsonString(pending.mutationPatchJson!)
            .applyTo(baseline, nowUtc: _now),
      );
      expect(
        saved.components
            .singleWhere((c) => c.recurrenceId?.rawValue == '20260810T090000Z')
            .summary,
        'First revised',
      );
      expect(
        saved.components
            .singleWhere((c) => c.recurrenceId?.rawValue == '20260809T090000Z')
            .summary,
        'Second change',
      );
      expect(saved.components.first.summary, 'Server series');
    },
  );

  test('one generated occurrence edit adds a detached exception', () async {
    const href = '${_collectionHref}recurring-event.ics';
    final baseline = _recurringEventResource();
    await _commitObjects(objectRepository, [
      _prepared(href: href, etag: '"series-etag"', body: baseline),
    ]);
    final occurrence = (await database.select(database.calendarEvents).get())
        .singleWhere(
          (event) => event.occurrenceKey!.contains('2026-08-10T09:00:00'),
        );

    await calendarRepository.updateLocalEvent(
      _draftForEvent(occurrence).copyWith(
        title: 'Only this occurrence',
        start: DateTime.utc(2026, 8, 10, 13),
        end: DateTime.utc(2026, 8, 10, 14),
        recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
      ),
    );

    final operation = await database.select(database.pendingOps).getSingle();
    expect(operation.operationType, 'dav.update');
    expect(operation.baselineRawIcs, baseline);
    final patch = DavMutationPatch.fromJsonString(operation.mutationPatchJson!);
    expect(patch.scope, DavMutationScope.occurrence);
    final candidate = patch.applyTo(baseline, nowUtc: _now);
    final semantic = IcalSemanticDocument.parse(candidate);
    expect(semantic.components, hasLength(3));
    final exception = semantic.components.singleWhere(
      (component) => component.recurrenceId?.rawValue == '20260810T090000Z',
    );
    expect(exception.summary, 'Only this occurrence');
    expect(exception.start?.rawValue, '20260810T130000Z');
    expect(candidate, contains('X-SERIES-KEEP:opaque'));
    expect(candidate, contains('SUMMARY:Existing exception'));

    final projected = (await database.select(database.calendarEvents).get())
        .singleWhere(
          (event) => event.occurrenceKey!.contains('2026-08-10T09:00:00'),
        );
    expect(projected.title, 'Only this occurrence');
    expect(projected.startDateTime, '2026-08-10T13:00:00.000Z');
    expect(projected.syncStatus, 'pending');

    await calendarRepository.updateLocalEvent(
      _draftForEvent(projected).copyWith(
        title: 'Edited again before sync',
        start: DateTime.utc(2026, 8, 10, 15),
        end: DateTime.utc(2026, 8, 10, 16),
        recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
      ),
    );

    final coalescedOperation = await database
        .select(database.pendingOps)
        .getSingle();
    final coalescedPatch = DavMutationPatch.fromJsonString(
      coalescedOperation.mutationPatchJson!,
    );
    expect(coalescedPatch.scope, DavMutationScope.occurrence);
    final coalescedCandidate = coalescedPatch.applyTo(baseline, nowUtc: _now);
    final coalescedException = IcalSemanticDocument.parse(coalescedCandidate)
        .components
        .singleWhere(
          (component) => component.recurrenceId?.rawValue == '20260810T090000Z',
        );
    expect(coalescedException.summary, 'Edited again before sync');
    expect(coalescedException.start?.rawValue, '20260810T150000Z');
    expect(
      RegExp('RECURRENCE-ID:20260810T090000Z').allMatches(coalescedCandidate),
      hasLength(1),
    );
  });

  test('existing detached exception is patched in place', () async {
    const href = '${_collectionHref}recurring-exception.ics';
    final baseline = _recurringEventResource();
    await _commitObjects(objectRepository, [
      _prepared(href: href, etag: '"series-etag"', body: baseline),
    ]);
    final occurrence = (await database.select(database.calendarEvents).get())
        .singleWhere((event) => event.recurrenceIdKey != null);

    await calendarRepository.updateLocalEvent(
      _draftForEvent(occurrence).copyWith(
        title: 'Edited exception',
        recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
      ),
    );

    final operation = await database.select(database.pendingOps).getSingle();
    final patch = DavMutationPatch.fromJsonString(operation.mutationPatchJson!);
    expect(patch.scope, DavMutationScope.recurrenceException);
    final candidate = patch.applyTo(baseline, nowUtc: _now);
    expect(
      RegExp('RECURRENCE-ID:20260809T090000Z').allMatches(candidate),
      hasLength(1),
    );
    expect(candidate, contains('SUMMARY:Edited exception'));
    expect(candidate, contains('X-SERIES-KEEP:opaque'));
  });

  test(
    'clearing an existing located exception preserves an inheritance barrier',
    () async {
      final baseline = _recurringEventResource()
          .replaceFirst(
            'SUMMARY:Server series',
            'SUMMARY:Server series\r\nLOCATION:Series room\r\nGEO:49.2827;-123.1207',
          )
          .replaceFirst(
            'SUMMARY:Existing exception',
            'SUMMARY:Existing exception\r\nLOCATION:Exception room\r\nGEO:48.4284;-123.3656',
          );
      await _commitObjects(objectRepository, [
        _prepared(
          href: '${_collectionHref}located-exception.ics',
          etag: '"located"',
          body: baseline,
        ),
      ]);
      final row = (await database.select(database.calendarEvents).get())
          .singleWhere((event) => event.recurrenceIdKey != null);
      final detail = (await calendarRepository.loadEventDetail(row.id))!;

      await calendarRepository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(
          clearLocation: true,
          recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
        ),
      );

      final operation = await database.select(database.pendingOps).getSingle();
      final serialized = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      ).applyTo(baseline, nowUtc: _now);
      final document = IcalSemanticDocument.parse(serialized);
      final exception = document.components.singleWhere(
        (component) => component.recurrenceIdKey != null,
      );
      expect(
        exception.documentComponent.firstProperty('LOCATION'),
        isA<IcalProperty>(),
      );
      expect(exception.location, '');
      expect(exception.documentComponent.firstProperty('GEO'), isNull);

      final projected = IcalRecurrenceExpander().expand(
        document,
        rangeStartUtc: DateTime.utc(2026, 8, 9),
        rangeEndUtc: DateTime.utc(2026, 8, 10),
      );
      expect(projected.single.location, '');
      expect(projected.single.locationPoint, isNull);
      expect(serialized, isNot(contains('LOCATION:Exception room')));
      expect(
        serialized.split('RECURRENCE-ID:20260809T090000Z').last,
        isNot(contains('LOCATION:Series room')),
      );
    },
  );

  test('clearing a sparse existing exception blocks inherited location', () async {
    final baseline = _recurringEventResource().replaceFirst(
      'SUMMARY:Server series',
      'SUMMARY:Server series\r\nLOCATION:Series room\r\nGEO:49.2827;-123.1207',
    );
    await _commitObjects(objectRepository, [
      _prepared(
        href: '${_collectionHref}sparse-located-exception.ics',
        etag: '"sparse-located"',
        body: baseline,
      ),
    ]);
    final row = (await database.select(database.calendarEvents).get())
        .singleWhere((event) => event.recurrenceIdKey != null);
    final detail = (await calendarRepository.loadEventDetail(row.id))!;
    expect(detail.location, 'Series room');
    expect(detail.locationPoint?.latitude, 49.2827);

    await calendarRepository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail).copyWith(
        clearLocation: true,
        recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
      ),
    );

    final serialized = await _serializedPendingDavMutation(database, baseline);
    final document = IcalSemanticDocument.parse(serialized);
    final exception = document.components.singleWhere(
      (component) => component.recurrenceIdKey != null,
    );
    expect(exception.documentComponent.firstProperty('LOCATION'), isNotNull);
    expect(exception.location, '');
    expect(exception.documentComponent.firstProperty('GEO'), isNull);
    final projected = IcalRecurrenceExpander().expand(
      document,
      rangeStartUtc: DateTime.utc(2026, 8, 9),
      rangeEndUtc: DateTime.utc(2026, 8, 10),
    );
    expect(projected.single.location, '');
    expect(projected.single.locationPoint, isNull);
  });

  test('title-only sparse exception edit keeps location inheritance live', () async {
    final baseline = _recurringEventResource().replaceFirst(
      'SUMMARY:Server series',
      'SUMMARY:Server series\r\nLOCATION:Series room\r\nGEO:49.2827;-123.1207',
    );
    await _commitObjects(objectRepository, [
      _prepared(
        href: '${_collectionHref}sparse-title-location.ics',
        etag: '"sparse-title"',
        body: baseline,
      ),
    ]);
    final row = (await database.select(database.calendarEvents).get())
        .singleWhere((event) => event.recurrenceIdKey != null);
    final detail = (await calendarRepository.loadEventDetail(row.id))!;
    expect(detail.location, 'Series room');

    await calendarRepository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail).copyWith(
        title: 'Renamed exception',
        recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
      ),
    );

    final serialized = await _serializedPendingDavMutation(database, baseline);
    final editedDocument = IcalSemanticDocument.parse(serialized);
    final exception = editedDocument.components.singleWhere(
      (component) => component.recurrenceIdKey != null,
    );
    expect(exception.summary, 'Renamed exception');
    expect(exception.documentComponent.firstProperty('LOCATION'), isNull);
    expect(exception.documentComponent.firstProperty('GEO'), isNull);

    final masterChanged = serialized.replaceFirst(
      'LOCATION:Series room\r\nGEO:49.2827;-123.1207',
      'LOCATION:New series room\r\nGEO:48.4284;-123.3656',
    );
    final projected = IcalRecurrenceExpander().expand(
      IcalSemanticDocument.parse(masterChanged),
      rangeStartUtc: DateTime.utc(2026, 8, 9),
      rangeEndUtc: DateTime.utc(2026, 8, 10),
    );
    expect(projected.single.location, 'New series room');
    expect(
      projected.single.locationPoint,
      GeographicPoint(latitude: 48.4284, longitude: -123.3656),
    );
  });

  test('new occurrence clear creates an explicit inheritance boundary', () async {
    final baseline = _recurringEventResource().replaceFirst(
      'SUMMARY:Server series',
      'SUMMARY:Server series\r\nLOCATION:Series room\r\nGEO:49.2827;-123.1207',
    );
    await _commitObjects(objectRepository, [
      _prepared(
        href: '${_collectionHref}new-clear-exception.ics',
        etag: '"new-clear"',
        body: baseline,
      ),
    ]);
    final row = (await database.select(database.calendarEvents).get())
        .singleWhere(
          (event) => event.occurrenceKey!.contains('2026-08-10T09:00:00'),
        );
    final detail = (await calendarRepository.loadEventDetail(row.id))!;

    await calendarRepository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail).copyWith(
        clearLocation: true,
        recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
      ),
    );

    final document = IcalSemanticDocument.parse(
      await _serializedPendingDavMutation(database, baseline),
    );
    final exception = document.components.singleWhere(
      (component) => component.recurrenceId?.rawValue == '20260810T090000Z',
    );
    expect(exception.location, '');
    expect(exception.documentComponent.firstProperty('LOCATION'), isNotNull);
    expect(exception.documentComponent.firstProperty('GEO'), isNull);
    final projected = IcalRecurrenceExpander().expand(
      document,
      rangeStartUtc: DateTime.utc(2026, 8, 10),
      rangeEndUtc: DateTime.utc(2026, 8, 11),
    );
    expect(projected.single.location, '');
    expect(projected.single.locationPoint, isNull);
  });

  test('this-and-future clear keeps an empty ranged LOCATION', () async {
    final baseline = _recurringEventResource().replaceFirst(
      'SUMMARY:Server series',
      'SUMMARY:Server series\r\nLOCATION:Series room\r\nGEO:49.2827;-123.1207',
    );
    await _commitObjects(objectRepository, [
      _prepared(
        href: '${_collectionHref}range-clear-location.ics',
        etag: '"range-clear"',
        body: baseline,
      ),
    ]);
    final row = (await database.select(database.calendarEvents).get())
        .singleWhere(
          (event) => event.occurrenceKey!.contains('2026-08-10T09:00:00'),
        );
    final detail = (await calendarRepository.loadEventDetail(row.id))!;

    await calendarRepository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail).copyWith(
        clearLocation: true,
        recurringMutationScope: RecurringEventMutationScope.thisAndFuture,
      ),
    );

    final document = IcalSemanticDocument.parse(
      await _serializedPendingDavMutation(database, baseline),
    );
    final range = document.components.singleWhere(
      (component) => component.recurrenceRange == 'THISANDFUTURE',
    );
    expect(range.location, '');
    expect(range.documentComponent.firstProperty('LOCATION'), isNotNull);
    expect(range.documentComponent.firstProperty('GEO'), isNull);
  });

  test(
    'replacing an exception writes the new venue and raw GEO point',
    () async {
      final baseline = _recurringEventResource()
          .replaceFirst(
            'SUMMARY:Server series',
            'SUMMARY:Server series\r\nLOCATION:Series room\r\nGEO:49.2827;-123.1207',
          )
          .replaceFirst(
            'SUMMARY:Existing exception',
            'SUMMARY:Existing exception\r\nLOCATION:Old exception\r\nGEO:48.4284;-123.3656',
          );
      await _commitObjects(objectRepository, [
        _prepared(
          href: '${_collectionHref}replace-exception-location.ics',
          etag: '"replace-location"',
          body: baseline,
        ),
      ]);
      final row = (await database.select(database.calendarEvents).get())
          .singleWhere((event) => event.recurrenceIdKey != null);
      final detail = (await calendarRepository.loadEventDetail(row.id))!;
      final selection = LocationResult(
        label: 'New exception',
        point: GeographicPoint(latitude: 0, longitude: -77.0365),
      );

      await calendarRepository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(detail).copyWith(
          location: selection.label,
          locationChange: LocationChange.replace(selection),
          recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
        ),
      );

      final serialized = await _serializedPendingDavMutation(
        database,
        baseline,
      );
      final document = IcalSemanticDocument.parse(serialized);
      final exception = document.components.singleWhere(
        (component) => component.recurrenceIdKey != null,
      );
      expect(exception.location, 'New exception');
      expect(
        exception.documentComponent.firstProperty('GEO')?.rawValue,
        '0.0;-77.0365',
      );
      final projected = IcalRecurrenceExpander().expand(
        document,
        rangeStartUtc: DateTime.utc(2026, 8, 9),
        rangeEndUtc: DateTime.utc(2026, 8, 10),
      );
      expect(projected.single.location, 'New exception');
      expect(projected.single.locationPoint, selection.point);
      expect(
        await database.select(database.locationResolutions).get(),
        isEmpty,
      );
    },
  );

  test('timing-only exception edit preserves inherited location data', () async {
    final baseline = _recurringEventResource().replaceFirst(
      'SUMMARY:Server series',
      'SUMMARY:Server series\r\nLOCATION:Series room\r\nGEO:49.2827;-123.1207',
    );
    await _commitObjects(objectRepository, [
      _prepared(
        href: '${_collectionHref}timing-preserves-location.ics',
        etag: '"timing-location"',
        body: baseline,
      ),
    ]);
    final row = (await database.select(database.calendarEvents).get())
        .singleWhere(
          (event) => event.occurrenceKey!.contains('2026-08-10T09:00:00'),
        );
    final detail = (await calendarRepository.loadEventDetail(row.id))!;

    await calendarRepository.updateLocalEvent(
      EventEditorDraft.fromEventDetail(detail).copyWith(
        start: DateTime.utc(2026, 8, 10, 13),
        end: DateTime.utc(2026, 8, 10, 14),
        recurringMutationScope: RecurringEventMutationScope.singleOccurrence,
      ),
      timingBaseline: EventTimingBaseline.fromDetail(detail),
    );

    final document = IcalSemanticDocument.parse(
      await _serializedPendingDavMutation(database, baseline),
    );
    final projected = IcalRecurrenceExpander().expand(
      document,
      rangeStartUtc: DateTime.utc(2026, 8, 10),
      rangeEndUtc: DateTime.utc(2026, 8, 11),
    );
    expect(projected.single.location, 'Series room');
    expect(projected.single.locationPoint?.latitude, 49.2827);
    expect(projected.single.locationPoint?.longitude, -123.1207);
  });

  test(
    'this-and-following DAV edit projects the RFC range immediately',
    () async {
      const href = '${_collectionHref}range-edit.ics';
      final baseline = _recurringEventResource();
      await _commitObjects(objectRepository, [
        _prepared(href: href, etag: '"series-etag"', body: baseline),
      ]);
      final occurrence = (await database.select(database.calendarEvents).get())
          .singleWhere((event) => event.recurrenceIdKey != null);

      await calendarRepository.updateLocalEvent(
        _draftForEvent(occurrence).copyWith(
          title: 'Changed following events',
          start: DateTime.utc(2026, 8, 9, 13),
          end: DateTime.utc(2026, 8, 9, 14),
          recurringMutationScope: RecurringEventMutationScope.thisAndFuture,
        ),
      );

      final operation = await database.select(database.pendingOps).getSingle();
      final patch = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      );
      final candidate = patch.applyTo(baseline, nowUtc: _now);
      final range = IcalSemanticDocument.parse(candidate).components
          .singleWhere((component) => component.recurrenceId != null);
      expect(range.recurrenceRange, 'THISANDFUTURE');

      final projected = await database.select(database.calendarEvents).get();
      final target = projected.singleWhere(
        (event) => event.occurrenceKey!.contains('2026-08-09T09:00:00'),
      );
      final following = projected.singleWhere(
        (event) => event.occurrenceKey!.contains('2026-08-10T09:00:00'),
      );
      expect(target.title, 'Changed following events');
      expect(target.startDateTime, '2026-08-09T13:00:00.000Z');
      expect(following.title, 'Changed following events');
      expect(following.startDateTime, '2026-08-10T13:00:00.000Z');
      expect(following.recurrenceIdKey, isNull);
    },
  );

  test('ordinary weekly series edit preserves a rescheduled Wednesday and cancellation through replay, sync and restart', () async {
    await usePersistentFixture();
    const href = '${_collectionHref}weekly-timing.ics';
    final baseline = _ical(const [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//BusyMax integration test//EN',
      'BEGIN:VEVENT',
      'UID:weekly@example.test',
      'DTSTAMP:20260808T110000Z',
      'DTSTART:20260803T090000Z',
      'DTEND:20260803T100000Z',
      'RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=5',
      'SUMMARY:Weekly',
      'X-SERIES-KEEP:opaque',
      'END:VEVENT',
      'BEGIN:VEVENT',
      'UID:weekly@example.test',
      'RECURRENCE-ID:20260810T090000Z',
      'DTSTAMP:20260808T110000Z',
      'DTSTART:20260812T130000Z',
      'DTEND:20260812T150000Z',
      'SUMMARY:Moved Wednesday',
      'X-EXCEPTION-KEEP:opaque',
      'END:VEVENT',
      'BEGIN:VEVENT',
      'UID:weekly@example.test',
      'RECURRENCE-ID:20260817T090000Z',
      'DTSTAMP:20260808T110000Z',
      'DTSTART:20260817T090000Z',
      'DTEND:20260817T100000Z',
      'STATUS:CANCELLED',
      'END:VEVENT',
      'END:VCALENDAR',
    ]);
    await _commitObjects(objectRepository, [
      _prepared(href: href, etag: '"one"', body: baseline),
    ]);
    final row = (await database.select(database.calendarEvents).get())
        .singleWhere(
          (event) => event.occurrenceKey!.contains('2026-08-03T09:00:00'),
        );
    await calendarRepository.updateLocalEvent(
      _draftForEvent(row).copyWith(
        start: DateTime.utc(2026, 8, 4, 9),
        end: DateTime.utc(2026, 8, 4, 10),
        recurringMutationScope: RecurringEventMutationScope.entireSeries,
      ),
    );
    final candidate = await _serializedPendingDavMutation(database, baseline);
    final semantic = IcalSemanticDocument.parse(candidate);
    final exception = semantic.components.singleWhere(
      (c) => c.summary == 'Moved Wednesday',
    );
    expect(exception.recurrenceId!.rawValue, '20260811T090000Z');
    expect(exception.start!.rawValue, '20260812T130000Z');
    expect(exception.end!.rawValue, '20260812T150000Z');
    expect(
      semantic.components
          .singleWhere((c) => c.status == 'CANCELLED')
          .recurrenceId!
          .rawValue,
      '20260818T090000Z',
    );
    expect(candidate, contains('X-EXCEPTION-KEEP:opaque'));
    Future<void> check() async {
      final events = (await database.select(database.calendarEvents).get())
          .where((event) => !event.isDeleted && !event.isCancelled)
          .toList();
      final moved = events.singleWhere(
        (event) => event.title == 'Moved Wednesday',
      );
      expect(
        DateTime.parse(moved.startDateTime!),
        DateTime.utc(2026, 8, 12, 13),
      );
      expect(DateTime.parse(moved.endDateTime!), DateTime.utc(2026, 8, 12, 15));
      expect(
        events
            .where((event) => event.title != 'Moved Wednesday')
            .map((event) => DateTime.parse(event.startDateTime!).weekday),
        everyElement(DateTime.tuesday),
      );
      expect(
        events.where((event) => DateTime.parse(event.startDateTime!).day == 18),
        isEmpty,
      );
      expect(
        events.where((event) => DateTime.parse(event.startDateTime!).day == 11),
        isEmpty,
      );
    }

    await check();
    await reopen();
    await check();
    await replayResource(candidate);
    await _commitObjects(objectRepository, [
      _prepared(href: href, etag: '"returned"', body: candidate),
    ]);
    await reopen();
    await check();
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test('ordinary all-day series edit keeps a rescheduled exception and cancellation dates', () async {
    await usePersistentFixture();
    const href = '${_collectionHref}all-day-series.ics';
    final baseline = _ical(const [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//BusyMax fixture//EN',
      'BEGIN:VEVENT',
      'UID:all-day-series',
      'DTSTAMP:20260101T000000Z',
      'DTSTART;VALUE=DATE:20260601',
      'DTEND;VALUE=DATE:20260602',
      'RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=3',
      'SUMMARY:Regular',
      'END:VEVENT',
      'BEGIN:VEVENT',
      'UID:all-day-series',
      'RECURRENCE-ID;VALUE=DATE:20260608',
      'DTSTAMP:20260101T000000Z',
      'DTSTART;VALUE=DATE:20260610',
      'DTEND;VALUE=DATE:20260612',
      'SUMMARY:Moved Wednesday',
      'END:VEVENT',
      'BEGIN:VEVENT',
      'UID:all-day-series',
      'RECURRENCE-ID;VALUE=DATE:20260615',
      'DTSTAMP:20260101T000000Z',
      'DTSTART;VALUE=DATE:20260615',
      'DTEND;VALUE=DATE:20260616',
      'STATUS:CANCELLED',
      'END:VEVENT',
      'END:VCALENDAR',
    ]);
    await _commitObjects(objectRepository, [
      _prepared(href: href, etag: '"one"', body: baseline),
    ]);
    final selected = (await database.select(database.calendarEvents).get())
        .singleWhere((row) => row.startDate == '2026-06-01');
    await calendarRepository.updateLocalEvent(
      _draftForEvent(selected).copyWith(
        start: DateTime.utc(2026, 6, 2),
        end: DateTime.utc(2026, 6, 3),
        recurringMutationScope: RecurringEventMutationScope.entireSeries,
      ),
    );
    final candidate = await _serializedPendingDavMutation(database, baseline);
    final parsed = IcalSemanticDocument.parse(candidate);
    expect(
      parsed.components
          .singleWhere((c) => c.summary == 'Moved Wednesday')
          .recurrenceId!
          .rawValue,
      '20260609',
    );
    expect(
      parsed.components
          .singleWhere((c) => c.status == 'CANCELLED')
          .recurrenceId!
          .rawValue,
      '20260616',
    );
    Future<void> check() async {
      final active = (await database.select(database.calendarEvents).get())
          .where((row) => !row.isDeleted && !row.isCancelled)
          .toList();
      expect(active, hasLength(2));
      expect(
        active.map((row) => row.startDate),
        unorderedEquals(['2026-06-02', '2026-06-10']),
      );
      final moved = active.singleWhere((row) => row.title == 'Moved Wednesday');
      expect(moved.endDate, '2026-06-12');
      expect(moved.allDay, isTrue);
    }

    await check();
    await replayResource(candidate);
    await reopen();
    await check();
  });

  for (final duration in ['P1D', 'PT24H']) {
    test(
      'ordinary zoned series edit preserves $duration and exception schedule across DST and restart',
      () async {
        await usePersistentFixture();
        const href = '${_collectionHref}dst-series.ics';
        final baseline = _ical([
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'PRODID:-//BusyMax fixture//EN',
          'BEGIN:VEVENT',
          'UID:dst-series',
          'DTSTAMP:20260101T000000Z',
          'DTSTART;TZID=America/Vancouver:20260302T013000',
          'DURATION:$duration',
          'RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=3',
          'SUMMARY:Regular',
          'END:VEVENT',
          'BEGIN:VEVENT',
          'UID:dst-series',
          'RECURRENCE-ID;TZID=America/Vancouver:20260316T013000',
          'DTSTAMP:20260101T000000Z',
          'DTSTART;TZID=America/Vancouver:20260318T130000',
          'DTEND;TZID=America/Vancouver:20260318T150000',
          'SUMMARY:Moved Wednesday',
          'X-KEEP:opaque',
          'END:VEVENT',
          'END:VCALENDAR',
        ]);
        await _commitObjects(objectRepository, [
          _prepared(href: href, etag: '"one"', body: baseline),
        ]);
        final selected = (await database.select(database.calendarEvents).get())
            .singleWhere((row) => row.startDateTime == '2026-03-02T01:30:00');
        final detail = (await calendarRepository.loadEventDetail(selected.id))!;
        await calendarRepository.updateLocalEvent(
          EventEditorDraft.fromEventDetail(detail).copyWith(
            start: providerCivilDateTime(DateTime.utc(2026, 3, 1, 1, 30)),
            end: providerCivilDateTime(DateTime.utc(2026, 3, 2, 1, 30)),
            recurringMutationScope: RecurringEventMutationScope.entireSeries,
          ),
        );
        final candidate = await _serializedPendingDavMutation(
          database,
          baseline,
        );
        expect(candidate, contains('DURATION:$duration'));
        final parsed = IcalSemanticDocument.parse(candidate);
        final exception = parsed.components.singleWhere(
          (c) => c.recurrenceId != null,
        );
        expect(exception.recurrenceId!.rawValue, '20260315T013000');
        expect(exception.start!.rawValue, '20260318T130000');
        expect(exception.end!.rawValue, '20260318T150000');
        Future<void> check() async {
          final rows = await database.select(database.calendarEvents).get();
          final dst = rows.singleWhere(
            (row) => row.startDateTime == '2026-03-08T01:30:00',
          );
          expect(dst.startTimeZone, 'America/Vancouver');
          expect(
            dst.endDateTime,
            duration == 'P1D' ? '2026-03-09T01:30:00' : '2026-03-09T02:30:00',
          );
          expect(
            providerDateTimeAsUtcInstant(dst.endDateTime, dst.endTimeZone)!
                .difference(
                  providerDateTimeAsUtcInstant(
                    dst.startDateTime,
                    dst.startTimeZone,
                  )!,
                )
                .inHours,
            duration == 'P1D' ? 23 : 24,
          );
          expect(
            rows
                .singleWhere((row) => row.title == 'Moved Wednesday')
                .startDateTime,
            '2026-03-18T13:00:00',
          );
        }

        await check();
        await reopen();
        await check();
        await replayResource(candidate);
        await reopen();
        await check();
      },
    );
  }

  test('a ranged exception with varying monthly offsets requires a decision before mutation', () async {
    const href = '${_collectionHref}ranged-series.ics';
    final baseline = _ical(const [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//BusyMax fixture//EN',
      'BEGIN:VEVENT',
      'UID:ranged-series',
      'DTSTAMP:20260101T000000Z',
      'DTSTART:20260126T090000Z',
      'DTEND:20260126T100000Z',
      'RRULE:FREQ=MONTHLY;BYDAY=-1MO;COUNT=8',
      'SUMMARY:Regular',
      'END:VEVENT',
      'BEGIN:VEVENT',
      'UID:ranged-series',
      'RECURRENCE-ID;RANGE=THISANDFUTURE:20260223T090000Z',
      'DTSTAMP:20260101T000000Z',
      'DTSTART:20260225T090000Z',
      'DTEND:20260225T100000Z',
      'SUMMARY:Following Wednesdays',
      'END:VEVENT',
      'END:VCALENDAR',
    ]);
    await _commitObjects(objectRepository, [
      _prepared(href: href, etag: '"one"', body: baseline),
    ]);
    final selected = (await database.select(database.calendarEvents).get())
        .singleWhere(
          (row) => row.occurrenceKey!.contains('2026-01-26T09:00:00'),
        );
    final draft = _draftForEvent(selected).copyWith(
      start: DateTime.utc(2026, 1, 27, 9),
      end: DateTime.utc(2026, 1, 27, 10),
      recurringMutationScope: RecurringEventMutationScope.entireSeries,
    );
    await expectLater(
      calendarRepository.prepareSeriesTimingChange(draft),
      throwsA(isA<SeriesTimingDecisionRequired>()),
    );
    await expectLater(
      calendarRepository.updateLocalEvent(draft),
      throwsA(isA<SeriesTimingDecisionRequired>()),
    );
    expect(await database.select(database.pendingOps).get(), isEmpty);
    expect(
      (await database.select(database.calendarEvents).get())
          .singleWhere((row) => row.id == selected.id)
          .startDateTime,
      '2026-01-26T09:00:00.000Z',
    );
  });

  test(
    'entire-series edit patches the master anchor and preserves exceptions',
    () async {
      const href = '${_collectionHref}whole-series.ics';
      final baseline = _recurringEventResource();
      await _commitObjects(objectRepository, [
        _prepared(href: href, etag: '"series-etag"', body: baseline),
      ]);
      final occurrence = (await database.select(database.calendarEvents).get())
          .singleWhere(
            (event) => event.occurrenceKey!.contains('2026-08-10T09:00:00'),
          );

      await calendarRepository.updateLocalEvent(
        _draftForEvent(occurrence).copyWith(
          title: 'Renamed series',
          start: DateTime.utc(2026, 8, 10, 10),
          end: DateTime.utc(2026, 8, 10, 11),
          recurringMutationScope: RecurringEventMutationScope.entireSeries,
        ),
      );

      final operation = await database.select(database.pendingOps).getSingle();
      final patch = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      );
      expect(patch.scope, DavMutationScope.recurrenceMaster);
      final candidate = patch.applyTo(baseline, nowUtc: _now);
      final semantic = IcalSemanticDocument.parse(candidate);
      final master = semantic.components.singleWhere(
        (component) => component.recurrenceId == null,
      );
      expect(master.start?.rawValue, '20260808T100000Z');
      expect(master.end?.rawValue, '20260808T110000Z');
      expect(master.summary, 'Renamed series');
      final exception = semantic.components.singleWhere(
        (component) => component.recurrenceId != null,
      );
      expect(exception.recurrenceId?.rawValue, '20260809T100000Z');
      expect(exception.start?.rawValue, '20260809T110000Z');
      expect(exception.summary, 'Existing exception');
      expect(candidate, contains('X-SERIES-KEEP:opaque'));
    },
  );

  test(
    'one-occurrence delete adds a cancelled exception, not a DELETE',
    () async {
      const href = '${_collectionHref}cancel-occurrence.ics';
      final baseline = _recurringEventResource();
      await _commitObjects(objectRepository, [
        _prepared(href: href, etag: '"series-etag"', body: baseline),
      ]);
      final occurrence = (await database.select(database.calendarEvents).get())
          .singleWhere(
            (event) => event.occurrenceKey!.contains('2026-08-10T09:00:00'),
          );

      await calendarRepository.deleteLocalEvent(
        occurrence.id,
        recurringScope: RecurringEventMutationScope.singleOccurrence,
      );

      final operation = await database.select(database.pendingOps).getSingle();
      expect(operation.operationType, 'dav.update');
      final patch = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      );
      final candidate = patch.applyTo(baseline, nowUtc: _now);
      final cancelled = IcalSemanticDocument.parse(candidate).components
          .singleWhere(
            (component) =>
                component.recurrenceId?.rawValue == '20260810T090000Z',
          );
      expect(cancelled.status, 'CANCELLED');
      expect(candidate, contains('SUMMARY:Existing exception'));
      final projected = (await database.select(database.calendarEvents).get())
          .singleWhere(
            (event) => event.occurrenceKey!.contains('2026-08-10T09:00:00'),
          );
      expect(projected.isCancelled, isTrue);
    },
  );

  test('this-and-following DAV delete cancels the projected range', () async {
    const href = '${_collectionHref}range-delete.ics';
    final baseline = _recurringEventResource();
    await _commitObjects(objectRepository, [
      _prepared(href: href, etag: '"series-etag"', body: baseline),
    ]);
    final occurrence = (await database.select(database.calendarEvents).get())
        .singleWhere((event) => event.recurrenceIdKey != null);

    await calendarRepository.deleteLocalEvent(
      occurrence.id,
      recurringScope: RecurringEventMutationScope.thisAndFuture,
    );

    final operation = await database.select(database.pendingOps).getSingle();
    expect(operation.operationType, 'dav.update');
    final candidate = DavMutationPatch.fromJsonString(
      operation.mutationPatchJson!,
    ).applyTo(baseline, nowUtc: _now);
    final exception = IcalSemanticDocument.parse(candidate).components
        .singleWhere((component) => component.recurrenceId != null);
    expect(exception.status, 'CANCELLED');
    expect(exception.recurrenceRange, 'THISANDFUTURE');

    final projected = await database.select(database.calendarEvents).get();
    expect(
      projected
          .where(
            (event) =>
                event.occurrenceKey!.contains('2026-08-09T09:00:00') ||
                event.occurrenceKey!.contains('2026-08-10T09:00:00'),
          )
          .every((event) => event.isCancelled),
      isTrue,
    );
  });

  test(
    'event delete removes only VEVENT when an unknown sibling is present',
    () async {
      const href = '${_collectionHref}mixed-event.ics';
      final baseline = _eventWithUnknownSibling();
      await _commitObjects(objectRepository, [
        _prepared(href: href, etag: '"mixed-event"', body: baseline),
      ]);
      final event = await database.select(database.calendarEvents).getSingle();

      await calendarRepository.deleteLocalEvent(event.id);

      final operation = await database.select(database.pendingOps).getSingle();
      expect(operation.operationType, 'dav.update');
      final candidate = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      ).applyTo(baseline, nowUtc: _now);
      expect(candidate, isNot(contains('BEGIN:VEVENT')));
      expect(candidate, contains('BEGIN:X-BUSYMAX-OPAQUE'));
      expect(candidate, contains('X-KEEP:untouched'));
      expect(IcalSemanticDocument.parse(candidate).components, isEmpty);
      expect(await database.select(database.calendarEvents).get(), isEmpty);
    },
  );

  test(
    'task create can be completed, reopened, and cancelled while unsent',
    () async {
      await tasksRepository.createTask(
        _taskListId,
        const TaskCreateInput(
          title: 'Local task',
          fields: {
            'title': 'Local task',
            'microsoftDueDateTime': {
              'dateTime': '2026-08-09T09:30:00',
              'timeZone': 'America/Vancouver',
            },
            'microsoftDueTimeZone': 'America/Vancouver',
            'categories': ['Work'],
          },
        ),
      );

      var task = await database.select(database.tasks).getSingle();
      var operation = await database.select(database.pendingOps).getSingle();
      expect(task.id, startsWith('dav-local-task-'));
      expect(task.davCollectionId, _collectionId);
      expect(task.davObjectId, isNull);
      final expectedSortOrder = _now
          .difference(DateTime.utc(2001, 1, 1))
          .inSeconds;
      expect(task.sortOrder, expectedSortOrder);
      expect(task.position, '$expectedSortOrder');
      expect(operation.operationType, 'dav.create');
      expect(operation.taskId, task.id);
      expect(_createRaw(operation), contains('BEGIN:VTODO'));
      expect(_createRaw(operation), contains('DUE;TZID=America/Vancouver'));

      await tasksRepository.patchTask(
        _taskListId,
        task.id,
        const TaskPatchInput({'status': 'completed'}),
      );
      task = await database.select(database.tasks).getSingle();
      operation = await database.select(database.pendingOps).getSingle();
      expect(task.status, 'completed');
      expect(task.providerStatus, 'COMPLETED');
      expect(task.percentComplete, 100);
      expect(task.completedUtc, _now.toIso8601String());
      expect(_createRaw(operation), contains('STATUS:COMPLETED'));
      expect(_createRaw(operation), contains('PERCENT-COMPLETE:100'));
      expect(_createRaw(operation), contains('COMPLETED:20260808T120000Z'));

      await tasksRepository.patchTask(
        _taskListId,
        task.id,
        const TaskPatchInput({'status': 'needsAction'}),
      );
      task = await database.select(database.tasks).getSingle();
      operation = await database.select(database.pendingOps).getSingle();
      expect(task.completedUtc, isNull);
      expect(task.percentComplete, 99);
      expect(_createRaw(operation), contains('STATUS:NEEDS-ACTION'));
      expect(_createRaw(operation), contains('PERCENT-COMPLETE:99'));
      expect(_createRaw(operation), isNot(contains('COMPLETED:')));

      await tasksRepository.deleteTask(_taskListId, task.id);
      expect(await database.select(database.tasks).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
    },
  );

  test('task create rolls back when due precedes start', () async {
    await expectLater(
      tasksRepository.createTask(
        _taskListId,
        const TaskCreateInput(
          title: 'Invalid range',
          fields: {
            'title': 'Invalid range',
            'microsoftDueDateTime': {
              'dateTime': '2026-08-09',
              'timeZone': 'America/Vancouver',
            },
            'microsoftDueTimeZone': 'America/Vancouver',
            'microsoftStartDateTime': {
              'dateTime': '2026-08-10',
              'timeZone': 'America/Vancouver',
            },
            'microsoftStartTimeZone': 'America/Vancouver',
          },
        ),
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavTaskDueBeforeStart',
        ),
      ),
    );

    expect(await database.select(database.tasks).get(), isEmpty);
    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test('DAV task creation writes GEO natively without a supplement', () async {
    final point = GeographicPoint(latitude: 0, longitude: -123.12);

    await tasksRepository.createTask(
      _taskListId,
      TaskCreateInput(
        title: 'Located task',
        fields: const {'title': 'Located task', 'location': 'Head office'},
        locationChange: LocationChange.replace(
          LocationResult(
            label: 'Long resolved label',
            point: point,
            source: 'ical',
          ),
        ),
      ),
    );

    final task = await database.select(database.tasks).getSingle();
    final operation = await database.select(database.pendingOps).getSingle();
    expect(task.taskLocation, 'Head office');
    expect(task.locationLatitude, point.latitude);
    expect(task.locationLongitude, point.longitude);
    expect(_createRaw(operation), contains('LOCATION:Head office'));
    expect(_createRaw(operation), contains('GEO:0.0;-123.12'));
    expect(await database.select(database.locationResolutions).get(), isEmpty);
  });

  test('rejected local task create can be corrected and requeued', () async {
    await tasksRepository.createTask(
      _taskListId,
      const TaskCreateInput(
        title: 'Rejected task',
        fields: {
          'title': 'Rejected task',
          'microsoftDueDateTime': {
            'dateTime': '2026-08-10',
            'timeZone': 'America/Vancouver',
          },
          'microsoftDueTimeZone': 'America/Vancouver',
          'microsoftStartDateTime': {
            'dateTime': '2026-08-09',
            'timeZone': 'America/Vancouver',
          },
          'microsoftStartTimeZone': 'America/Vancouver',
        },
      ),
    );
    await database
        .update(database.pendingOps)
        .write(
          const PendingOpsCompanion(
            state: Value('failed'),
            retryClassification: Value('permanent'),
            nextAttemptAtUtc: Value('9999-12-31T23:59:59.999Z'),
            lastErrorCode: Value('DavMalformedResource'),
            lastErrorMessage: Value(
              'The DAV server could not update the object.',
            ),
          ),
        );
    final localTask = await database.select(database.tasks).getSingle();

    await tasksRepository.patchTask(
      _taskListId,
      localTask.id,
      const TaskPatchInput({'title': 'Corrected task'}),
    );

    final operation = await database.select(database.pendingOps).getSingle();
    expect(operation.state, 'pending');
    expect(operation.lastErrorCode, isNull);
    expect(_createRaw(operation), contains('SUMMARY:Corrected task'));
    expect(
      (await database.select(database.tasks).getSingle()).title,
      'Corrected task',
    );
  });

  test('confirmed task updates preserve extensions and exact ETag', () async {
    const href = '${_collectionHref}confirmed-task.ics';
    final baseline = _taskResource(
      uid: 'confirmed-task@example.test',
      summary: 'Server task',
      extra: const ['X-UNKNOWN-TASK;P="q,r":retain-me'],
    );
    await _commitObjects(objectRepository, [
      _prepared(href: href, etag: '"task-etag"', body: baseline),
    ]);
    var task = await database.select(database.tasks).getSingle();

    await tasksRepository.patchTask(
      _taskListId,
      task.id,
      const TaskPatchInput({'title': 'Local task', 'status': 'completed'}),
    );

    var operation = await database.select(database.pendingOps).getSingle();
    expect(operation.operationType, 'dav.update');
    expect(operation.baselineEtag, '"task-etag"');
    expect(operation.baselineRawIcs, baseline);
    var patch = DavMutationPatch.fromJsonString(operation.mutationPatchJson!);
    var candidate = patch.applyTo(operation.baselineRawIcs!, nowUtc: _later);
    expect(candidate, contains('SUMMARY:Local task'));
    expect(candidate, contains('COMPLETED:20260808T120000Z'));
    expect(candidate, contains('X-UNKNOWN-TASK;P="q,r":retain-me'));

    task = await database.select(database.tasks).getSingle();
    await tasksRepository.patchTask(
      _taskListId,
      task.id,
      const TaskPatchInput({'status': 'needsAction'}),
    );
    operation = await database.select(database.pendingOps).getSingle();
    patch = DavMutationPatch.fromJsonString(operation.mutationPatchJson!);
    candidate = patch.applyTo(operation.baselineRawIcs!, nowUtc: _later);
    expect(candidate, contains('SUMMARY:Local task'));
    expect(candidate, contains('STATUS:NEEDS-ACTION'));
    expect(candidate, isNot(contains('COMPLETED:')));
    expect(candidate, contains('X-UNKNOWN-TASK;P="q,r":retain-me'));

    task = await database.select(database.tasks).getSingle();
    await tasksRepository.deleteTask(_taskListId, task.id);
    operation = await database.select(database.pendingOps).getSingle();
    expect(operation.operationType, 'dav.delete');
    expect(operation.baselineEtag, '"task-etag"');
    expect(operation.baselineRawIcs, baseline);
  });

  test(
    'task delete removes only VTODO when an unknown sibling is present',
    () async {
      const href = '${_collectionHref}mixed-task.ics';
      final baseline = _taskWithUnknownSibling();
      await _commitObjects(objectRepository, [
        _prepared(href: href, etag: '"mixed-task"', body: baseline),
      ]);
      final task = await database.select(database.tasks).getSingle();

      await tasksRepository.deleteTask(_taskListId, task.id);

      final operation = await database.select(database.pendingOps).getSingle();
      expect(operation.operationType, 'dav.update');
      final candidate = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      ).applyTo(baseline, nowUtc: _now);
      expect(candidate, isNot(contains('BEGIN:VTODO')));
      expect(candidate, contains('BEGIN:X-BUSYMAX-OPAQUE'));
      expect(candidate, contains('X-KEEP:untouched'));
      expect(IcalSemanticDocument.parse(candidate).components, isEmpty);
      expect(await database.select(database.tasks).get(), isEmpty);
    },
  );

  test('task hierarchy resolves IDs and prevents cycles', () async {
    const parentHref = '${_collectionHref}parent.ics';
    const childHref = '${_collectionHref}child.ics';
    await _commitObjects(objectRepository, [
      _prepared(
        href: parentHref,
        etag: '"parent"',
        body: _taskResource(uid: 'parent@example.test', summary: 'Parent'),
      ),
      _prepared(
        href: childHref,
        etag: '"child"',
        body: _taskResource(
          uid: 'child@example.test',
          summary: 'Child',
          extra: const ['RELATED-TO;RELTYPE=PARENT:parent@example.test'],
        ),
      ),
    ]);
    final rows = await database.select(database.tasks).get();
    final parent = rows.singleWhere(
      (task) => task.icalUid == 'parent@example.test',
    );
    var child = rows.singleWhere(
      (task) => task.icalUid == 'child@example.test',
    );
    expect(child.parentUid, parent.icalUid);
    expect(child.parent, parent.id);

    await expectLater(
      tasksRepository.moveTask(
        TaskMoveInput(
          sourceTaskListId: _taskListId,
          taskId: parent.id,
          parentTaskId: child.id,
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );

    await tasksRepository.moveTask(
      TaskMoveInput(sourceTaskListId: _taskListId, taskId: child.id),
    );
    child =
        await (database.select(database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) & row.id.equals(child.id),
            ))
            .getSingle();
    expect(child.parent, isNull);
    expect(child.parentUid, isNull);
    final operations = await database.select(database.pendingOps).get();
    expect(operations, hasLength(2));
    final childOperation = operations.singleWhere(
      (operation) => operation.davMemberHref == childHref,
    );
    final childPatch = DavMutationPatch.fromJsonString(
      childOperation.mutationPatchJson!,
    );
    final childCandidate = childPatch.applyTo(
      childOperation.baselineRawIcs!,
      nowUtc: _now,
    );
    expect(childCandidate, isNot(contains('RELATED-TO;RELTYPE=PARENT')));
    expect(childCandidate, contains('X-APPLE-SORT-ORDER:0'));
    final parentOperation = operations.singleWhere(
      (operation) => operation.davMemberHref == parentHref,
    );
    final parentCandidate = DavMutationPatch.fromJsonString(
      parentOperation.mutationPatchJson!,
    ).applyTo(parentOperation.baselineRawIcs!, nowUtc: _now);
    expect(parentCandidate, contains('X-APPLE-SORT-ORDER:1'));
  });

  test('deleting a parent queues every child before the parent', () async {
    const parentHref = '${_collectionHref}delete-parent.ics';
    const childHref = '${_collectionHref}delete-child.ics';
    await _commitObjects(objectRepository, [
      _prepared(
        href: parentHref,
        etag: '"parent"',
        body: _taskResource(
          uid: 'delete-parent@example.test',
          summary: 'Parent',
        ),
      ),
      _prepared(
        href: childHref,
        etag: '"child"',
        body: _taskResource(
          uid: 'delete-child@example.test',
          summary: 'Child',
          extra: const ['RELATED-TO;RELTYPE=PARENT:delete-parent@example.test'],
        ),
      ),
    ]);
    final parent = (await database.select(database.tasks).get()).singleWhere(
      (task) => task.icalUid == 'delete-parent@example.test',
    );

    await tasksRepository.deleteTask(_taskListId, parent.id);

    final operations = await database.select(database.pendingOps).get();
    expect(operations, hasLength(2));
    final childDelete = operations.singleWhere(
      (operation) => operation.davMemberHref == childHref,
    );
    final parentDelete = operations.singleWhere(
      (operation) => operation.davMemberHref == parentHref,
    );
    expect(childDelete.dependsOnOpId, isNull);
    expect(parentDelete.dependsOnOpId, childDelete.id);
    expect(
      (await database.select(database.tasks).get()).every(
        (task) => task.pendingDelete,
      ),
      isTrue,
    );
  });

  test(
    'duplicate recursively preserves task data and reparents children',
    () async {
      const parentHref = '${_collectionHref}duplicate-parent.ics';
      const childHref = '${_collectionHref}duplicate-child.ics';
      await _commitObjects(objectRepository, [
        _prepared(
          href: parentHref,
          etag: '"duplicate-parent"',
          body: _taskResource(
            uid: 'duplicate-parent@example.test',
            summary: 'Duplicate parent',
            extra: const [
              'CREATED:20260801T120000Z',
              'PRIORITY:3',
              'LOCATION:Room 4',
              'URL:https://cloud.example.test/tasks/parent',
              'CATEGORIES:Work,Planning',
              'X-KEEP:opaque',
            ],
          ),
        ),
        _prepared(
          href: childHref,
          etag: '"duplicate-child"',
          body: _taskResource(
            uid: 'duplicate-child@example.test',
            summary: 'Duplicate child',
            extra: const [
              'CREATED:20260801T120100Z',
              'RELATED-TO:duplicate-parent@example.test',
            ],
          ),
        ),
      ]);
      final sourceParent = (await database.select(database.tasks).get())
          .singleWhere(
            (task) => task.icalUid == 'duplicate-parent@example.test',
          );
      final rememberedPoint = GeographicPoint(
        latitude: 49.28,
        longitude: -123.12,
      );
      await LocationResolutionRepository(database).apply(
        LocationItemIdentity(
          kind: LocationItemKind.task,
          accountId: sourceParent.accountId,
          sourceId: sourceParent.taskListId,
          itemId: sourceParent.id,
        ),
        'Room 4',
        LocationChange.replace(
          LocationResult(
            label: 'Room 4, long resolved label',
            point: rememberedPoint,
            source: 'legacy-provider',
            attribution: 'Existing provenance',
          ),
        ),
      );

      final duplicateParentId = await tasksRepository.duplicateTask(
        _taskListId,
        sourceParent.id,
      );

      final tasks = await database.select(database.tasks).get();
      expect(tasks, hasLength(4));
      final duplicateParent = tasks.singleWhere(
        (task) => task.id == duplicateParentId,
      );
      final duplicateChild = tasks.singleWhere(
        (task) => task.localCreated && task.parent == duplicateParentId,
      );
      expect(duplicateChild.parentUid, duplicateParent.icalUid);
      final expectedSortOrder = _now
          .difference(DateTime.utc(2001, 1, 1))
          .inSeconds;
      expect(duplicateParent.sortOrder, expectedSortOrder);
      expect(duplicateChild.sortOrder, expectedSortOrder);
      expect(duplicateParent.taskLocation, 'Room 4');
      expect(duplicateParent.locationLatitude, rememberedPoint.latitude);
      expect(duplicateParent.locationLongitude, rememberedPoint.longitude);

      final operations = await database.select(database.pendingOps).get();
      expect(operations, hasLength(2));
      final parentCreate = operations.singleWhere(
        (operation) => operation.taskId == duplicateParent.id,
      );
      final childCreate = operations.singleWhere(
        (operation) => operation.taskId == duplicateChild.id,
      );
      expect(parentCreate.operationType, 'dav.create');
      expect(childCreate.operationType, 'dav.create');
      expect(childCreate.dependsOnOpId, parentCreate.id);
      expect(_createRaw(parentCreate), contains('PRIORITY:3'));
      expect(_createRaw(parentCreate), contains('LOCATION:Room 4'));
      expect(_createRaw(parentCreate), contains('GEO:49.28;-123.12'));
      expect(_createRaw(parentCreate), contains('X-KEEP:opaque'));
      final supplements = await database
          .select(database.locationResolutions)
          .get();
      expect(supplements, hasLength(1));
      expect(supplements.single.itemId, sourceParent.id);
      expect(
        IcalSemanticDocument.parse(_createRaw(childCreate))
            .components
            .single
            .parentUid,
        duplicateParent.icalUid,
      );
    },
  );

  test('native task export includes the current pending overlay', () async {
    const href = '${_collectionHref}export.ics';
    final baseline = _taskResource(
      uid: 'export@example.test',
      summary: 'Original title',
      extra: const ['X-KEEP:opaque'],
    );
    await _commitObjects(objectRepository, [
      _prepared(href: href, etag: '"export"', body: baseline),
    ]);
    final task = await database.select(database.tasks).getSingle();

    expect(
      await tasksRepository.nativeTaskExport(_taskListId, task.id),
      baseline,
    );

    await tasksRepository.patchTask(
      _taskListId,
      task.id,
      const TaskPatchInput({'title': 'Pending title'}),
    );
    final exported = await tasksRepository.nativeTaskExport(
      _taskListId,
      task.id,
    );
    expect(exported, contains('SUMMARY:Pending title'));
    expect(exported, contains('X-KEEP:opaque'));
  });

  test('cross-list move queues a child-first DAV subtree move', () async {
    await _seedDestinationTaskList(database);
    const parentHref = '${_collectionHref}move-parent.ics';
    const childHref = '${_collectionHref}move-child.ics';
    await _commitObjects(objectRepository, [
      _prepared(
        href: parentHref,
        etag: '"move-parent"',
        body: _taskResource(
          uid: 'move-parent@example.test',
          summary: 'Move parent',
        ),
      ),
      _prepared(
        href: childHref,
        etag: '"move-child"',
        body: _taskResource(
          uid: 'move-child@example.test',
          summary: 'Move child',
          extra: const ['RELATED-TO;RELTYPE=PARENT:move-parent@example.test'],
        ),
      ),
    ]);
    final sourceTasks = await database.select(database.tasks).get();
    final parent = sourceTasks.singleWhere(
      (task) => task.icalUid == 'move-parent@example.test',
    );
    final child = sourceTasks.singleWhere(
      (task) => task.icalUid == 'move-child@example.test',
    );

    await tasksRepository.moveTask(
      TaskMoveInput(
        sourceTaskListId: _taskListId,
        taskId: parent.id,
        destinationTaskListId: _destinationTaskListId,
      ),
    );

    final operations = await database.select(database.pendingOps).get();
    expect(operations, hasLength(2));
    final childMove = operations.singleWhere(
      (operation) => operation.taskId == child.id,
    );
    final parentMove = operations.singleWhere(
      (operation) => operation.taskId == parent.id,
    );
    expect(childMove.operationType, 'dav.move');
    expect(parentMove.operationType, 'dav.move');
    expect(childMove.destinationCollectionId, _destinationCollectionId);
    expect(parentMove.destinationCollectionId, _destinationCollectionId);
    expect(childMove.dependsOnOpId, isNull);
    expect(parentMove.dependsOnOpId, childMove.id);

    final moved = await database.select(database.tasks).get();
    expect(
      moved.every((task) => task.taskListId == _destinationTaskListId),
      isTrue,
    );
    expect(
      moved.every((task) => task.davCollectionId == _destinationCollectionId),
      isTrue,
    );
    expect(moved.singleWhere((task) => task.id == child.id).parent, parent.id);
  });

  test('clear completed queues Nextcloud closed root task trees', () async {
    const completedHref = '${_collectionHref}completed.ics';
    const statusOnlyHref = '${_collectionHref}status-only.ics';
    const completedDateOnlyHref = '${_collectionHref}completed-date-only.ics';
    const cancelledHref = '${_collectionHref}cancelled.ics';
    const percentOnlyHref = '${_collectionHref}percent-only.ics';
    const openParentHref = '${_collectionHref}open-parent.ics';
    const closedChildHref = '${_collectionHref}closed-child.ics';
    await _commitObjects(objectRepository, [
      _prepared(
        href: completedHref,
        etag: '"completed"',
        body: _taskResource(
          uid: 'completed@example.test',
          summary: 'Completed',
          extra: const [
            'STATUS:COMPLETED',
            'PERCENT-COMPLETE:100',
            'COMPLETED:20260808T110000Z',
          ],
        ),
      ),
      _prepared(
        href: statusOnlyHref,
        etag: '"status-only"',
        body: _taskResource(
          uid: 'status-only@example.test',
          summary: 'Status only',
          extra: const ['STATUS:COMPLETED', 'PERCENT-COMPLETE:50'],
        ),
      ),
      _prepared(
        href: completedDateOnlyHref,
        etag: '"completed-date-only"',
        body: _taskResource(
          uid: 'completed-date-only@example.test',
          summary: 'Completed date only',
          extra: const ['COMPLETED:20260808T120000Z'],
        ),
      ),
      _prepared(
        href: cancelledHref,
        etag: '"cancelled"',
        body: _taskResource(
          uid: 'cancelled@example.test',
          summary: 'Cancelled',
          extra: const ['STATUS:CANCELLED'],
        ),
      ),
      _prepared(
        href: percentOnlyHref,
        etag: '"percent-only"',
        body: _taskResource(
          uid: 'percent-only@example.test',
          summary: 'Percent only',
          extra: const ['PERCENT-COMPLETE:100'],
        ),
      ),
      _prepared(
        href: openParentHref,
        etag: '"open-parent"',
        body: _taskResource(
          uid: 'open-parent@example.test',
          summary: 'Open parent',
        ),
      ),
      _prepared(
        href: closedChildHref,
        etag: '"closed-child"',
        body: _taskResource(
          uid: 'closed-child@example.test',
          summary: 'Closed child',
          extra: const [
            'RELATED-TO:open-parent@example.test',
            'STATUS:COMPLETED',
          ],
        ),
      ),
    ]);

    await tasksRepository.clearCompleted(_taskListId);

    final operations = await database.select(database.pendingOps).get();
    expect(operations, hasLength(4));
    expect(
      operations.every((operation) => operation.operationType == 'dav.delete'),
      isTrue,
    );
    expect(operations.map((operation) => operation.davMemberHref).toSet(), {
      completedHref,
      statusOnlyHref,
      completedDateOnlyHref,
      cancelledHref,
    });
    final tasks = await database.select(database.tasks).get();
    bool pendingDelete(String uid) =>
        tasks.singleWhere((task) => task.icalUid == uid).pendingDelete;
    expect(pendingDelete('completed@example.test'), isTrue);
    expect(pendingDelete('status-only@example.test'), isTrue);
    expect(pendingDelete('completed-date-only@example.test'), isTrue);
    expect(pendingDelete('cancelled@example.test'), isTrue);
    expect(pendingDelete('percent-only@example.test'), isFalse);
    expect(pendingDelete('open-parent@example.test'), isFalse);
    expect(pendingDelete('closed-child@example.test'), isFalse);
  });
}

EventEditorDraft _newEventDraft() => EventEditorDraft.newEvent(
  accountId: _accountId,
  sourceId: _sourceId,
  providerCalendarId: _collectionHref,
  start: DateTime.utc(2026, 8, 8, 9),
  end: DateTime.utc(2026, 8, 8, 10),
);

EventEditorDraft _draftForEvent(CalendarEvent event) =>
    EventEditorDraft.existing(
      eventId: event.id,
      accountId: event.accountId,
      sourceId: event.calendarSourceId,
      providerCalendarId: event.providerCalendarId,
      providerRecurringEventId: event.providerRecurringEventId,
      title: event.title,
      allDay: event.allDay,
      start: event.allDay
          ? DateTime.parse(event.startDate!)
          : DateTime.parse(event.startDateTime!),
      end: event.allDay
          ? DateTime.parse(event.endDate!)
          : DateTime.parse(event.endDateTime!),
      startTimeZone: event.startTimeZone,
      endTimeZone: event.endTimeZone,
      description: event.description,
      location: event.location,
      recurrence: event.recurrenceJson == null
          ? null
          : jsonDecode(event.recurrenceJson!),
      reminders: event.remindersJson == null
          ? null
          : jsonDecode(event.remindersJson!),
      categories: event.categoriesJson == null
          ? const []
          : (jsonDecode(event.categoriesJson!) as List).cast<String>(),
      showAs: event.transparencyOrShowAs,
      visibilityOrSensitivity: event.visibility,
    );

String _createRaw(PendingOp operation) =>
    (jsonDecode(operation.requestJson) as Map)['rawIcs']! as String;

Future<String> _serializedPendingDavMutation(
  AppDatabase database,
  String baseline,
) async {
  final operation = await database.select(database.pendingOps).getSingle();
  return DavMutationPatch.fromJsonString(operation.mutationPatchJson!)
      .applyTo(baseline, nowUtc: _now);
}

DavPreparedObject _prepared({
  required String href,
  required String etag,
  required String body,
}) => DavPreparedObject.parse(
  hrefKey: href,
  requestUri: Uri.parse('https://cloud.example.test$href'),
  etag: etag,
  contentType: 'text/calendar; charset=utf-8',
  rawIcsBody: body,
);

Future<void> _commitObjects(
  DavObjectRepository repository,
  List<DavPreparedObject> objects,
) {
  return repository.commit(
    DavCollectionCommit(
      accountId: _accountId,
      collectionId: _collectionId,
      provider: BusyProvider.nextcloud,
      objects: objects,
      deletedHrefKeys: const {},
      completeMembership: true,
      membershipHrefKeys: {for (final object in objects) object.hrefKey},
      finalCursorKind: 'dav_sync_token',
      finalCursorValue: 'sync-token-1',
      baselineGeneration: 1,
      completedAtUtc: _now,
      projectionRangeStartUtc: DateTime.utc(2025),
      projectionRangeEndUtc: DateTime.utc(2028),
    ),
  );
}

Future<void> _seedDavAccount(AppDatabase database) async {
  final now = _now.toIso8601String();
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: _accountId,
          provider: 'nextcloud',
          authority: 'https://cloud.example.test',
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
          authState: const Value('signed_in'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: _collectionId,
          accountId: _accountId,
          hrefKey: _collectionHref,
          requestUri: 'https://cloud.example.test$_collectionHref',
          displayName: 'Work',
          supportedComponentMask: const Value(3),
          supportedReportsJson: Value(
            jsonEncode([
              '{DAV:}sync-collection',
              '{urn:ietf:params:xml:ns:caldav}calendar-multiget',
              '{urn:ietf:params:xml:ns:caldav}calendar-query',
            ]),
          ),
          currentUserPrivilegesJson: Value(
            jsonEncode(['{DAV:}read', '{DAV:}write']),
          ),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(true),
          taskProjectionEnabled: const Value(true),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: _sourceId,
          accountId: _accountId,
          provider: 'nextcloud',
          providerCalendarId: _collectionHref,
          davCollectionId: const Value(_collectionId),
          summary: 'Work',
          createdAtLocal: _now.millisecondsSinceEpoch,
          updatedAtLocal: _now.millisecondsSinceEpoch,
        ),
      );
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: _accountId,
          id: _taskListId,
          davCollectionId: const Value(_collectionId),
          title: 'Work',
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
}

Future<void> _seedScheduling(AppDatabase database, String email) async {
  final principal = Uri.parse(
    'https://cloud.example.test/remote.php/dav/principals/users/alex/',
  );
  final home = Uri.parse(
    'https://cloud.example.test/remote.php/dav/calendars/alex/',
  );
  await database
      .into(database.davAccountServices)
      .insertOnConflictUpdate(
        DavAccountServicesCompanion.insert(
          accountId: _accountId,
          canonicalServiceUri: 'https://cloud.example.test/remote.php/dav/',
          canonicalOrigin: 'https://cloud.example.test',
          principalHref: Value(principal.toString()),
          calendarHomeHref: Value(home.toString()),
          capabilitiesJson: Value(
            jsonEncode({
              'serverFeatures': ['calendar-auto-schedule'],
              'principalContexts': [
                DavPrincipalContext(
                  principalHref: principal,
                  calendarHomeHref: home,
                  calendarUserAddresses: [Uri.parse('mailto:$email')],
                  scheduleOutboxHref: home.resolve('outbox/'),
                  scheduleInboxHref: home.resolve('inbox/'),
                  outboxPrivileges: {
                    '{urn:ietf:params:xml:ns:caldav}schedule-send',
                  },
                ).toJson(),
              ],
            }),
          ),
          discoveredAtUtc: _now.toIso8601String(),
        ),
      );
}

Future<void> _seedDestinationTaskList(AppDatabase database) async {
  final now = _now.toIso8601String();
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: _destinationCollectionId,
          accountId: _accountId,
          hrefKey: _destinationCollectionHref,
          requestUri: 'https://cloud.example.test$_destinationCollectionHref',
          displayName: 'Home',
          supportedComponentMask: const Value(2),
          supportedReportsJson: Value(
            jsonEncode([
              '{DAV:}sync-collection',
              '{urn:ietf:params:xml:ns:caldav}calendar-multiget',
            ]),
          ),
          currentUserPrivilegesJson: Value(
            jsonEncode(['{DAV:}read', '{DAV:}write']),
          ),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(false),
          taskProjectionEnabled: const Value(true),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: _accountId,
          id: _destinationTaskListId,
          davCollectionId: const Value(_destinationCollectionId),
          title: 'Home',
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
}

Future<void> _seedDestinationCalendar(AppDatabase database) async {
  final now = _now.toIso8601String();
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: _destinationCollectionId,
          accountId: _accountId,
          hrefKey: _destinationCollectionHref,
          requestUri: 'https://cloud.example.test$_destinationCollectionHref',
          displayName: 'Home',
          supportedComponentMask: const Value(1),
          supportedReportsJson: Value(
            jsonEncode([
              '{DAV:}sync-collection',
              '{urn:ietf:params:xml:ns:caldav}calendar-multiget',
            ]),
          ),
          currentUserPrivilegesJson: Value(
            jsonEncode(['{DAV:}read', '{DAV:}write']),
          ),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(true),
          taskProjectionEnabled: const Value(false),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: _destinationCalendarSourceId,
          accountId: _accountId,
          provider: 'nextcloud',
          providerCalendarId: _destinationCollectionHref,
          davCollectionId: const Value(_destinationCollectionId),
          summary: 'Home',
          createdAtLocal: _now.millisecondsSinceEpoch,
          updatedAtLocal: _now.millisecondsSinceEpoch,
        ),
      );
}

String _eventResource({
  required String uid,
  required String summary,
  List<String> extra = const [],
}) => _ical([
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//BusyMax integration test//EN',
  'BEGIN:VEVENT',
  'UID:$uid',
  'DTSTAMP:20260808T110000Z',
  'DTSTART:20260808T090000Z',
  'DTEND:20260808T100000Z',
  'SUMMARY:$summary',
  ...extra,
  'END:VEVENT',
  'END:VCALENDAR',
]);

String _recurringEventResource() => _ical(const [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//BusyMax integration test//EN',
  'BEGIN:VEVENT',
  'UID:series@example.test',
  'DTSTAMP:20260808T110000Z',
  'DTSTART:20260808T090000Z',
  'DTEND:20260808T100000Z',
  'RRULE:FREQ=DAILY;COUNT=3',
  'SUMMARY:Server series',
  'X-SERIES-KEEP:opaque',
  'END:VEVENT',
  'BEGIN:VEVENT',
  'UID:series@example.test',
  'RECURRENCE-ID:20260809T090000Z',
  'DTSTAMP:20260808T110000Z',
  'DTSTART:20260809T110000Z',
  'DTEND:20260809T120000Z',
  'SUMMARY:Existing exception',
  'X-EXCEPTION-KEEP:opaque',
  'END:VEVENT',
  'END:VCALENDAR',
]);

String _eventWithUnknownSibling() => _ical(const [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//BusyMax integration test//EN',
  'BEGIN:VEVENT',
  'UID:mixed-event@example.test',
  'DTSTAMP:20260808T110000Z',
  'DTSTART:20260808T090000Z',
  'DTEND:20260808T100000Z',
  'SUMMARY:Projected event',
  'END:VEVENT',
  'BEGIN:X-BUSYMAX-OPAQUE',
  'X-KEEP:untouched',
  'END:X-BUSYMAX-OPAQUE',
  'END:VCALENDAR',
]);

String _taskResource({
  required String uid,
  required String summary,
  List<String> extra = const [],
}) => _ical([
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//BusyMax integration test//EN',
  'BEGIN:VTODO',
  'UID:$uid',
  'DTSTAMP:20260808T110000Z',
  'SUMMARY:$summary',
  ...extra,
  'END:VTODO',
  'END:VCALENDAR',
]);

String _taskWithUnknownSibling() => _ical(const [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//BusyMax integration test//EN',
  'BEGIN:VTODO',
  'UID:mixed-task@example.test',
  'DTSTAMP:20260808T110000Z',
  'SUMMARY:Projected task',
  'END:VTODO',
  'BEGIN:X-BUSYMAX-OPAQUE',
  'X-KEEP:untouched',
  'END:X-BUSYMAX-OPAQUE',
  'END:VCALENDAR',
]);

String _ical(List<String> lines) => '${lines.join('\r\n')}\r\n';

const _accountId = 'nextcloud:alex';
const _collectionId = 'collection';
const _collectionHref = '/remote.php/dav/calendars/alex/work/';
const _sourceId = 'dav-calendar-collection';
const _taskListId = 'dav-task-list-collection';
const _destinationCollectionId = 'destination-collection';
const _destinationCollectionHref = '/remote.php/dav/calendars/alex/home/';
const _destinationTaskListId = 'dav-task-list-destination-collection';
const _destinationCalendarSourceId = 'dav-calendar-destination-collection';
final _now = DateTime.utc(2026, 8, 8, 12);
final _later = DateTime.utc(2026, 8, 9, 12);
