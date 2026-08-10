import 'dart:convert';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DavObjectRepository repository;
  var nextId = 0;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DavObjectRepository(
      database: database,
      idFactory: () => 'generated-${nextId += 1}',
    );
    await _seedCollection(database);
  });

  tearDown(() => database.close());

  test(
    'stores exact raw event and atomically builds recurrence projections',
    () async {
      final raw = _recurringEvent(summary: 'Original', unknown: 'keep-me');
      final prepared = DavPreparedObject.parse(
        hrefKey: '/remote.php/dav/calendars/alex/work/event.ics',
        requestUri: Uri.parse(
          'https://cloud.example.test/remote.php/dav/calendars/alex/work/event.ics',
        ),
        etag: 'W/"opaque-etag"',
        contentType: 'text/calendar; charset=utf-8',
        rawIcsBody: raw,
      );

      await repository.commit(
        _commit(
          objects: [prepared],
          membership: {prepared.hrefKey},
          cursor: 'https://cloud.example.test/sync/1',
        ),
      );

      final object = await database.select(database.davObjects).getSingle();
      expect(object.rawIcsBody, raw);
      expect(object.etag, 'W/"opaque-etag"');
      expect(object.rawIcsBody, contains('X-UNKNOWN:keep-me'));
      expect(object.serverDeleted, isFalse);
      expect(
        await database.select(database.davObjectComponents).get(),
        hasLength(2),
      );
      final events = await database.select(database.calendarEvents).get();
      expect(events, hasLength(3));
      expect(events.map((event) => event.title), contains('Moved'));
      expect(events.every((event) => event.davObjectId == object.id), isTrue);
      expect(
        events.every((event) => event.startTimeZone == 'America/Vancouver'),
        isTrue,
      );
      expect(
        events.every(
          (event) =>
              event.remindersJson?.contains('"minutes":[10,30]') ?? false,
        ),
        isTrue,
      );
      expect(events.first.remindersJson, contains('AUDIO'));
      final cursor = await database.select(database.syncCursors).getSingle();
      expect(cursor.cursorValue, 'https://cloud.example.test/sync/1');
      expect(cursor.baselineGeneration, 1);
    },
  );

  test(
    'server-only folding changes replace raw baseline without data loss',
    () async {
      final first = DavPreparedObject.parse(
        hrefKey: _eventHref,
        requestUri: Uri.parse('https://cloud.example.test$_eventHref'),
        etag: '"one"',
        contentType: 'text/calendar',
        rawIcsBody: _simpleEvent('A long summary that can be folded'),
      );
      await repository.commit(
        _commit(objects: [first], membership: {_eventHref}, cursor: 'token-1'),
      );
      final originalId =
          (await database.select(database.davObjects).getSingle()).id;
      final rewrittenBody = _simpleEvent('A long summary that can be folded')
          .replaceFirst(
            'SUMMARY:A long summary that can be folded',
            'SUMMARY:A long summary that can be\r\n  folded',
          );
      final rewritten = DavPreparedObject.parse(
        hrefKey: _eventHref,
        requestUri: Uri.parse('https://cloud.example.test$_eventHref'),
        etag: '"two"',
        contentType: 'text/calendar',
        rawIcsBody: rewrittenBody,
      );

      await repository.commit(
        _commit(
          objects: [rewritten],
          membership: {_eventHref},
          cursor: 'token-2',
          generation: 2,
        ),
      );

      final object = await database.select(database.davObjects).getSingle();
      expect(object.id, originalId);
      expect(object.rawIcsBody, rewrittenBody);
      expect(object.etag, '"two"');
      expect(object.semanticHash, first.semantic.semanticHash);
      expect(
        await database.select(database.calendarEvents).get(),
        hasLength(1),
      );
    },
  );

  test('complete membership deletes only after successful promotion', () async {
    final first = DavPreparedObject.parse(
      hrefKey: _eventHref,
      requestUri: Uri.parse('https://cloud.example.test$_eventHref'),
      etag: '"one"',
      contentType: 'text/calendar',
      rawIcsBody: _simpleEvent('Existing'),
    );
    await repository.commit(
      _commit(objects: [first], membership: {_eventHref}, cursor: 'token-1'),
    );

    await repository.commit(
      _commit(
        objects: const [],
        membership: const {},
        cursor: 'token-2',
        generation: 2,
      ),
    );

    final object = await database.select(database.davObjects).getSingle();
    expect(object.serverDeleted, isTrue);
    expect(object.rawIcsBody, first.rawIcsBody);
    expect(await database.select(database.calendarEvents).get(), isEmpty);
    expect(
      (await database.select(database.syncCursors).getSingle()).cursorValue,
      'token-2',
    );
  });

  test(
    'projection failure rolls raw object and final cursor back together',
    () async {
      final first = DavPreparedObject.parse(
        hrefKey: _eventHref,
        requestUri: Uri.parse('https://cloud.example.test$_eventHref'),
        etag: '"one"',
        contentType: 'text/calendar',
        rawIcsBody: _simpleEvent('Baseline'),
      );
      await repository.commit(
        _commit(objects: [first], membership: {_eventHref}, cursor: 'token-1'),
      );
      final changed = DavPreparedObject.parse(
        hrefKey: _eventHref,
        requestUri: Uri.parse('https://cloud.example.test$_eventHref'),
        etag: '"two"',
        contentType: 'text/calendar',
        rawIcsBody: _simpleEvent('Changed'),
      );

      await expectLater(
        repository.commit(
          _commit(
            objects: [changed],
            membership: {_eventHref},
            cursor: 'token-2',
            generation: 2,
            rangeEnd: DateTime.utc(2055),
          ),
        ),
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'IcalProjectionRangeLimitExceeded',
          ),
        ),
      );

      final object = await database.select(database.davObjects).getSingle();
      expect(object.rawIcsBody, first.rawIcsBody);
      expect(object.etag, '"one"');
      expect(
        (await database.select(database.syncCursors).getSingle()).cursorValue,
        'token-1',
      );
    },
  );

  test('projects Nextcloud task semantics and extension fields', () async {
    final task = DavPreparedObject.parse(
      hrefKey: '/remote.php/dav/calendars/alex/work/task.ics',
      requestUri: Uri.parse(
        'https://cloud.example.test/remote.php/dav/calendars/alex/work/task.ics',
      ),
      etag: '"task-etag"',
      contentType: 'text/calendar',
      rawIcsBody: _task,
    );

    await repository.commit(
      _commit(objects: [task], membership: {task.hrefKey}, cursor: 'token-1'),
    );

    final projected = await database.select(database.tasks).getSingle();
    expect(projected.title, 'Child task');
    expect(projected.parentUid, 'parent-uid');
    // Keep the wire UID even when the referenced parent is not present, but do
    // not expose an unresolved UID through the projection-ID relationship.
    expect(projected.parent, null);
    expect(projected.icalPriority, 1);
    expect(projected.percentComplete, 50);
    expect(projected.sortOrder, 42);
    expect(projected.position, '42');
    expect(projected.providerStatus, 'IN-PROCESS');
    expect(projected.status, 'inProcess');
    expect(projected.taskLocation, 'Room 4');
    expect(projected.taskUrl, 'https://cloud.example.test/tasks/child');
    expect(projected.taskClassification, 'PRIVATE');
    expect(projected.taskPinned, isTrue);
    expect(projected.taskHideSubtasks, isTrue);
    expect(projected.taskHideCompletedSubtasks, isTrue);
    expect(jsonDecode(projected.categoriesJson!), ['Work', 'Personal']);
    expect(projected.providerExtensionProjectionJson, contains('X-PINNED'));
    expect(projected.providerMetadataJson, contains('nativeDue'));
    expect(projected.providerMetadataJson, contains('nativeStart'));
    expect(projected.microsoftIsReminderOn, isTrue);
    expect(projected.microsoftReminderDateTime, '2026-08-09T23:00:00.000Z');
    expect(projected.microsoftReminderTimeZone, 'UTC');
    expect(projected.providerMetadataJson, contains('AUDIO'));

    final entity = TaskEntity.fromRow(projected);
    expect(entity.microsoftStartDateTime, '2026-08-09T16:00:00Z');
    expect(entity.microsoftStartTimeZone, 'UTC');
    expect(entity.microsoftDueDateTime, '2026-08-09T17:00:00');
    expect(entity.microsoftDueTimeZone, 'America/Vancouver');
  });

  test('uses the Nextcloud CREATED fallback for task sort order', () async {
    final task = DavPreparedObject.parse(
      hrefKey: '/remote.php/dav/calendars/alex/work/created-order.ics',
      requestUri: Uri.parse(
        'https://cloud.example.test/remote.php/dav/calendars/alex/work/created-order.ics',
      ),
      etag: '"created-order"',
      contentType: 'text/calendar',
      rawIcsBody: _taskWithoutExplicitOrder,
    );

    await repository.commit(
      _commit(objects: [task], membership: {task.hrefKey}, cursor: 'token-1'),
    );

    final projected = await database.select(database.tasks).getSingle();
    final expected = DateTime.utc(
      2026,
      8,
      9,
      12,
    ).difference(DateTime.utc(2001, 1, 1)).inSeconds;
    expect(projected.sortOrder, expected);
    expect(projected.position, '$expected');
  });

  test('advances occurrence horizon from stored raw data only', () async {
    final future = DavPreparedObject.parse(
      hrefKey: _eventHref,
      requestUri: Uri.parse('https://cloud.example.test$_eventHref'),
      etag: '"future"',
      contentType: 'text/calendar',
      rawIcsBody: _simpleEvent(
        'Future',
        start: '20300101T090000Z',
        end: '20300101T100000Z',
      ),
    );
    await repository.commit(
      _commit(objects: [future], membership: {_eventHref}, cursor: 'token-1'),
    );
    expect(await database.select(database.davObjects).get(), hasLength(1));
    expect(await database.select(database.calendarEvents).get(), isEmpty);

    await repository.reprojectCollectionFromStored(
      accountId: 'account',
      collectionId: 'collection',
      provider: BusyProvider.nextcloud,
      projectionRangeStartUtc: DateTime.utc(2029),
      projectionRangeEndUtc: DateTime.utc(2031),
      completedAtUtc: _now,
    );

    expect(await database.select(database.calendarEvents).get(), hasLength(1));
    expect(
      (await database.select(database.syncCursors).getSingle()).cursorValue,
      'token-1',
    );
  });
}

const _eventHref = '/remote.php/dav/calendars/alex/work/event.ics';
final _now = DateTime.utc(2026, 8, 8, 12);

DavCollectionCommit _commit({
  required List<DavPreparedObject> objects,
  required Set<String> membership,
  required String cursor,
  int generation = 1,
  DateTime? rangeEnd,
}) => DavCollectionCommit(
  accountId: 'account',
  collectionId: 'collection',
  provider: BusyProvider.nextcloud,
  objects: objects,
  deletedHrefKeys: const {},
  completeMembership: true,
  membershipHrefKeys: membership,
  finalCursorKind: 'dav_sync_token',
  finalCursorValue: cursor,
  baselineGeneration: generation,
  completedAtUtc: _now,
  projectionRangeStartUtc: DateTime.utc(2025),
  projectionRangeEndUtc: rangeEnd ?? DateTime.utc(2029),
);

Future<void> _seedCollection(AppDatabase database) async {
  const now = '2026-08-08T12:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'nextcloud',
          authority: 'https://cloud.example.test',
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
          authState: const Value('signed_in'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  const href = '/remote.php/dav/calendars/alex/work/';
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'collection',
          accountId: 'account',
          hrefKey: href,
          requestUri: 'https://cloud.example.test$href',
          displayName: 'Work',
          supportedComponentMask: const Value(3),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(true),
          taskProjectionEnabled: const Value(true),
          color: const Value('#123456'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'dav-calendar-collection',
          accountId: 'account',
          provider: 'nextcloud',
          providerCalendarId: href,
          davCollectionId: const Value('collection'),
          summary: 'Work',
          createdAtLocal: _now.millisecondsSinceEpoch,
          updatedAtLocal: _now.millisecondsSinceEpoch,
        ),
      );
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: 'dav-task-list-collection',
          davCollectionId: const Value('collection'),
          title: 'Work',
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
}

String _simpleEvent(
  String summary, {
  String start = '20260808T090000Z',
  String end = '20260808T100000Z',
}) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:simple@example.test\r
DTSTART:$start\r
DTEND:$end\r
SUMMARY:$summary\r
END:VEVENT\r
END:VCALENDAR\r
''';

String _recurringEvent({required String summary, required String unknown}) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:recurring@example.test\r
DTSTART;TZID=America/Vancouver:20260803T090000\r
DTEND;TZID=America/Vancouver:20260803T100000\r
RRULE:FREQ=WEEKLY;COUNT=3\r
SUMMARY:$summary\r
X-UNKNOWN:$unknown\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER:-PT10M\r
DESCRIPTION:First\r
END:VALARM\r
BEGIN:VALARM\r
ACTION:AUDIO\r
TRIGGER:-PT5M\r
END:VALARM\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER:-PT30M\r
DESCRIPTION:Second\r
END:VALARM\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:recurring@example.test\r
RECURRENCE-ID;TZID=America/Vancouver:20260810T090000\r
DTSTART;TZID=America/Vancouver:20260810T110000\r
DTEND;TZID=America/Vancouver:20260810T120000\r
SUMMARY:Moved\r
END:VEVENT\r
END:VCALENDAR\r
''';

const _task = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//Nextcloud Tasks//EN\r
BEGIN:VTODO\r
UID:child-uid\r
SUMMARY:Child task\r
DESCRIPTION:Details\r
DTSTART:20260809T160000Z\r
DUE;TZID=America/Vancouver:20260809T170000\r
STATUS:IN-PROCESS\r
PERCENT-COMPLETE:50\r
PRIORITY:1\r
CATEGORIES:Work,Personal\r
LOCATION:Room 4\r
URL:https://cloud.example.test/tasks/child\r
CLASS:PRIVATE\r
RELATED-TO:parent-uid\r
X-APPLE-SORT-ORDER:42\r
X-PINNED:true\r
X-OC-HIDESUBTASKS:1\r
X-OC-HIDECOMPLETEDSUBTASKS:1\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER;VALUE=DATE-TIME:20260809T230000Z\r
DESCRIPTION:Task reminder\r
END:VALARM\r
BEGIN:VALARM\r
ACTION:AUDIO\r
TRIGGER:-PT5M\r
END:VALARM\r
END:VTODO\r
END:VCALENDAR\r
''';

const _taskWithoutExplicitOrder = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//Nextcloud Tasks//EN\r
BEGIN:VTODO\r
UID:created-order@example.test\r
CREATED:20260809T120000Z\r
SUMMARY:Created order\r
END:VTODO\r
END:VCALENDAR\r
''';
