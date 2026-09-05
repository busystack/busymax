import 'dart:convert';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DavObjectRepository objectRepository;
  late CalendarRepository calendarRepository;
  late TasksRepository tasksRepository;
  late int notificationChanges;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    var objectSequence = 0;
    objectRepository = DavObjectRepository(
      database: database,
      idFactory: () => 'dav-object-${objectSequence += 1}',
    );
    notificationChanges = 0;
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
    await _seedDavAccount(database);
  });

  tearDown(() => database.close());

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
        _draftForEvent(
          events.single,
        ).copyWith(title: 'Edited before upload', location: 'Room 4'),
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
      final range = IcalSemanticDocument.parse(
        candidate,
      ).components.singleWhere((component) => component.recurrenceId != null);
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
      expect(exception.recurrenceId?.rawValue, '20260809T090000Z');
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
    final exception = IcalSemanticDocument.parse(
      candidate,
    ).components.singleWhere((component) => component.recurrenceId != null);
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
      expect(_createRaw(parentCreate), contains('X-KEEP:opaque'));
      expect(
        IcalSemanticDocument.parse(
          _createRaw(childCreate),
        ).components.single.parentUid,
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
