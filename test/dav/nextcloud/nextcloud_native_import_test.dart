import 'dart:convert';

import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_native_import.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/accounts/domain/account_connection_state.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'nextcloud_admin_fixture.dart';

void main() {
  late NextcloudAdminFixture fixture;
  late NextcloudNativeImportService importer;
  late NextcloudNativeImportPreview preview;
  final now = DateTime.utc(2026, 9, 5);
  setUp(() async {
    fixture = NextcloudAdminFixture();
    await fixture.seed();
    final db = fixture.database;
    await db
        .update(db.accounts)
        .write(
          AccountsCompanion(
            authState: Value(AccountConnectionState.connected.storageValue),
          ),
        );
    await (db.update(
      db.davCollections,
    )..where((r) => r.id.equals('collection'))).write(
      const DavCollectionsCompanion(
        readOnly: Value(false),
        currentUserPrivilegesJson: Value('["{DAV:}all"]'),
      ),
    );
    await db
        .into(db.calendarSources)
        .insert(
          CalendarSourcesCompanion.insert(
            id: 'dav-calendar-collection',
            accountId: 'account',
            provider: 'nextcloud',
            providerCalendarId: NextcloudAdminFixture.collection,
            summary: 'Work',
            davCollectionId: const Value('collection'),
            createdAtLocal: 0,
            updatedAtLocal: 0,
          ),
        );
    await db
        .into(db.taskLists)
        .insert(
          TaskListsCompanion.insert(
            accountId: 'account',
            id: 'dav-task-list-collection',
            davCollectionId: const Value('collection'),
            title: 'Work',
            rawJson: '{}',
            createdLocalAtUtc: now.toIso8601String(),
            updatedLocalAtUtc: now.toIso8601String(),
          ),
        );
    var id = 0;
    importer = NextcloudNativeImportService(
      db,
      nowUtc: () => now,
      idFactory: () => 'import-${id++}',
    );
    preview = NextcloudNativeImportPreview.parse(IcalDocument.parse(_raw));
  });
  tearDown(() => fixture.close());
  Future<List<NativeImportItemResult>> import({bool copies = false}) =>
      importer.import(
        accountId: 'account',
        collectionId: 'collection',
        preview: preview,
        normalizeSchedulingMethod: true,
        duplicates: copies
            ? NativeImportDuplicates.newCopies
            : NativeImportDuplicates.skip,
      );

  test(
    'native preview groups types and recurrence sets without mutating input',
    () {
      expect(preview.resources, hasLength(3));
      expect(preview.schedulingMethod, 'PUBLISH');
      final event = preview.resources.singleWhere(
        (r) => r.componentType == 'VEVENT',
      );
      expect(IcalSemanticDocument.parse(event.rawIcs).components, hasLength(2));
      expect(
        event.rawIcs,
        allOf(
          contains('VTIMEZONE'),
          contains('X-UNKNOWN;X-PARAM=keep:opaque'),
          contains('ATTENDEE;ROLE=OPT-PARTICIPANT'),
          isNot(contains('METHOD:')),
        ),
      );
      expect(fixture.requests, isEmpty);
    },
  );
  test(
    'silent native import retains rich pending resources and duplicate identities',
    () async {
      final results = await import();
      expect(
        results.every((r) => r.status == NativeImportItemStatus.queued),
        isTrue,
      );
      final db = fixture.database;
      final operations = await db.select(db.pendingOps).get();
      expect(operations, hasLength(3));
      expect(
        operations.every(
          (op) =>
              (jsonDecode(op.requestJson) as Map)['suppressScheduling'] ==
                  true &&
              op.davObjectId != null,
        ),
        isTrue,
      );
      expect(
        (await db.select(db.tasks).get()).map((t) => t.parentUid),
        contains('parent'),
      );
      final events = await db.select(db.calendarEvents).get();
      expect(events, hasLength(2));
      expect(events.every((e) => e.syncStatus == 'pending'), isTrue);
      final exported = await CalendarRepository(
        database: db,
      ).nativeEventExport(events.last.id);
      expect(
        exported,
        allOf(
          contains('RECURRENCE-ID'),
          contains('UID:meeting'),
          contains('VALARM'),
          contains('VTIMEZONE'),
        ),
      );
      expect(
        (await import()).every(
          (r) => r.status == NativeImportItemStatus.duplicate,
        ),
        isTrue,
      );
      expect(fixture.requests, isEmpty);
    },
  );
  test('new copies rewrite task parent identities together', () async {
    await import(copies: true);
    final tasks = await fixture.database.select(fixture.database.tasks).get();
    final parent = tasks.singleWhere((t) => t.title == 'Parent');
    final child = tasks.singleWhere((t) => t.title == 'Child');
    expect(parent.icalUid, isNot('parent'));
    expect(child.parentUid, parent.icalUid);
    expect(child.parent, parent.id);
  });
  test(
    'unsent native resources can be edited and exported while replay is pending',
    () async {
      await import();
      final db = fixture.database;
      final eventObject = (await db.select(db.davObjects).get()).singleWhere(
        (o) => o.primaryUid == 'meeting',
      );
      final queue = DavPendingOperationQueue(database: db, nowUtc: () => now);
      await queue.enqueueUpdate(
        accountId: 'account',
        collectionId: 'collection',
        objectId: eventObject.id,
        patch: DavMutationPatch(
          target: const IcalComponentKey(
            componentType: 'VEVENT',
            uid: 'meeting',
          ),
          scope: DavMutationScope.recurrenceMaster,
          operations: [
            DavPatchOperation.setText('SUMMARY', 'Edited before upload'),
          ],
        ),
      );
      await (db.update(db.pendingOps)
            ..where((r) => r.davObjectId.equals(eventObject.id)))
          .write(const PendingOpsCompanion(state: Value('in_progress')));
      final raw = await queue.exportRawIcsForObject(
        accountId: 'account',
        collectionId: 'collection',
        objectId: eventObject.id,
      );
      expect(raw, contains('SUMMARY:Edited before upload'));
      expect(
        (jsonDecode(
              (await (db.select(db.pendingOps)
                        ..where((r) => r.davObjectId.equals(eventObject.id)))
                      .getSingle())
                  .requestJson,
            )
            as Map)['suppressScheduling'],
        isTrue,
      );
    },
  );
  test(
    'a normal inventory cannot erase unuploaded imported resources',
    () async {
      await import();
      await DavObjectRepository(database: fixture.database).commit(
        DavCollectionCommit(
          accountId: 'account',
          collectionId: 'collection',
          provider: BusyProvider.nextcloud,
          objects: [],
          deletedHrefKeys: {},
          completeMembership: true,
          membershipHrefKeys: {},
          finalCursorKind: 'sync_token',
          finalCursorValue: 'token',
          baselineGeneration: 1,
          completedAtUtc: now,
          projectionRangeStartUtc: now.subtract(const Duration(days: 30)),
          projectionRangeEndUtc: now.add(const Duration(days: 90)),
        ),
      );
      expect(
        (await fixture.database.select(fixture.database.davObjects).get())
            .every((o) => !o.serverDeleted),
        isTrue,
      );
      expect(
        await fixture.database.select(fixture.database.pendingOps).get(),
        hasLength(3),
      );
    },
  );
  test(
    'a reconstructed replayer sends the per-import header and exact create condition',
    () async {
      await import();
      final stored = <String, String>{};
      final puts = <http.Request>[];
      // Use the production HTTP mutation client with an injected fake transport.
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          puts.add(request);
          stored[request.url.path] = request.body;
          return http.Response('', 201, headers: {'etag': '"server"'});
        }
        if (request.method == 'GET') {
          final body = stored[request.url.path];
          return http.Response(
            body ?? '',
            body == null ? 404 : 200,
            headers: {'etag': '"server"'},
          );
        }
        throw StateError('Unexpected test request');
      });
      addTearDown(client.close);
      final context = await fixture.collections.openContext();
      // Reuse authenticated transport construction, without owning the sync client.
      final remote = DavMutationHttpClient(
        transport: DavHttpTransport(
          client: client,
          profile: context.profile,
          accountAuthority: context.authority,
        ),
        accountId: 'account',
        collectionId: 'collection',
        credential: context.credential,
      );
      final result = await DavPendingOperationsReplayer(
        database: fixture.database,
        accountId: 'account',
        objectRepository: DavObjectRepository(database: fixture.database),
        serviceFactory: ({required account, required collection}) async =>
            DavConditionalMutationService(remoteClient: remote),
        nowUtc: () => now,
      ).replayDueOperations();
      expect(
        result.appliedCount,
        3,
        reason:
            (await fixture.database.select(fixture.database.pendingOps).get())
                .map((op) => '${op.state}: ${op.lastErrorCode}')
                .join(', '),
      );
      expect(puts, hasLength(3));
      expect(
        puts.every(
          (r) =>
              r.headers['x-nc-scheduling'] == 'false' &&
              r.headers['if-none-match'] == '*',
        ),
        isTrue,
      );
      expect(
        await fixture.database.select(fixture.database.pendingOps).get(),
        isEmpty,
      );
      final confirmed = await fixture.database.select(fixture.database.davObjects).get();
      expect(confirmed, hasLength(3));
      expect(confirmed.every((o) => o.etag == '"server"'), isTrue);
      await remote.conditionalPut(uri: Uri.parse(confirmed.first.requestUri), rawIcs: confirmed.first.rawIcsBody, correlationId: 'ordinary-edit', ifMatch: '"server"');
      expect(puts.last.headers['x-nc-scheduling'], isNull, reason: 'Import suppression must never leak to ordinary edits.');
    },
  );
}

const _raw = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//QA//EN
METHOD:PUBLISH
BEGIN:VTIMEZONE
TZID:QA/Fixed
BEGIN:STANDARD
DTSTART:19700101T000000
TZOFFSETFROM:+0200
TZOFFSETTO:+0200
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
UID:meeting
DTSTAMP:20260901T000000Z
DTSTART;TZID=QA/Fixed:20260906T100000
DTEND;TZID=QA/Fixed:20260906T110000
RRULE:FREQ=DAILY;COUNT=2
SUMMARY:Meeting
ORGANIZER:mailto:alex@example.test
ATTENDEE;ROLE=OPT-PARTICIPANT:mailto:bob@example.test
X-UNKNOWN;X-PARAM=keep:opaque
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER:-PT10M
DESCRIPTION:Reminder
END:VALARM
END:VEVENT
BEGIN:VEVENT
UID:meeting
RECURRENCE-ID;TZID=QA/Fixed:20260907T100000
DTSTAMP:20260901T000000Z
DTSTART;TZID=QA/Fixed:20260907T120000
DTEND;TZID=QA/Fixed:20260907T130000
SUMMARY:Exception
END:VEVENT
BEGIN:VTODO
UID:parent
DTSTAMP:20260901T000000Z
SUMMARY:Parent
END:VTODO
BEGIN:VTODO
UID:child
DTSTAMP:20260901T000000Z
SUMMARY:Child
RELATED-TO:parent
X-PINNED:1
END:VTODO
END:VCALENDAR
''';
