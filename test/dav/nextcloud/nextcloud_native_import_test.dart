import 'dart:convert';

import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_native_import.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_native_export.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/accounts/domain/account_connection_state.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

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
  Future<List<http.Request>> permanentlyRejectPendingMutation() async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method != 'PUT') {
        throw StateError('Unexpected ${request.method} request.');
      }
      return http.Response('', 415);
    });
    addTearDown(client.close);
    final context = await fixture.collections.openContext();
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
      idFactory: () => 'rejected-create',
      nowUtc: () => now,
    ).replayDueOperations();
    expect(result.appliedCount, 0);
    expect(result.retryCount, 0);
    return requests;
  }

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
    final operations = await fixture.database
        .select(fixture.database.pendingOps)
        .get();
    final parentOp = operations.singleWhere(
      (o) => (jsonDecode(o.requestJson) as Map)['uid'] == parent.icalUid,
    );
    final childOp = operations.singleWhere(
      (o) => (jsonDecode(o.requestJson) as Map)['uid'] == child.icalUid,
    );
    expect(childOp.dependsOnOpId, parentOp.id);
  });
  test(
    'native collection export snapshots pending raw resources without network or mutations',
    () async {
      await import();
      final db = fixture.database;
      final before = await db.select(db.pendingOps).get();
      final snapshot = await NextcloudNativeExportService(
        db,
      ).collection('account', 'collection');
      expect(snapshot, hasLength(3));
      expect(
        snapshot.singleWhere((r) => r.uid == 'meeting').rawIcs,
        allOf(
          contains('X-UNKNOWN;X-PARAM=keep:opaque'),
          contains('RECURRENCE-ID'),
          contains('VTIMEZONE'),
        ),
      );
      expect(
        snapshot.singleWhere((r) => r.uid == 'child').rawIcs,
        contains('RELATED-TO:parent'),
      );
      expect(await db.select(db.pendingOps).get(), before);
      expect(fixture.requests, isEmpty);
      await expectLater(
        NextcloudNativeExportService(
          db,
        ).collection('another-account', 'collection'),
        throwsStateError,
      );
    },
  );
  test(
    'collection export uses the final update then move task candidate',
    () async {
      final db = fixture.database;
      await _seedDestinationTaskList(db, now);
      const href = '${NextcloudAdminFixture.collection}moved-task.ics';
      await DavObjectRepository(database: db).commit(
        DavCollectionCommit(
          accountId: 'account',
          collectionId: 'collection',
          provider: BusyProvider.nextcloud,
          objects: [
            DavPreparedObject.parse(
              hrefKey: href,
              requestUri: Uri.parse('${NextcloudAdminFixture.origin}$href'),
              etag: '"task-baseline"',
              contentType: 'text/calendar',
              rawIcsBody: _movableTask,
            ),
          ],
          deletedHrefKeys: const {},
          completeMembership: false,
          membershipHrefKeys: const {},
          finalCursorKind: 'dav_sync_token',
          finalCursorValue: 'token-1',
          baselineGeneration: 1,
          completedAtUtc: now,
          projectionRangeStartUtc: DateTime.utc(2025),
          projectionRangeEndUtc: DateTime.utc(2028),
        ),
      );
      final repository = TasksRepository(
        database: db,
        accountId: 'account',
        uuid: _SequenceUuid(const ['z-update-operation', 'a-move-operation']),
        nowUtc: () => now,
      );
      final task = (await db.tasksDao.listTasks(
        'account',
        'dav-task-list-collection',
      )).single;
      expect(task.parentUid, 'parent@example.test');

      await repository.updateTaskFull(
        'dav-task-list-collection',
        task.id,
        const TaskPutInput({'title': 'Final offline title'}),
      );
      await repository.moveTask(
        TaskMoveInput(
          sourceTaskListId: 'dav-task-list-collection',
          destinationTaskListId: 'dav-task-list-destination',
          taskId: task.id,
        ),
      );
      final operationsBefore = await db.select(db.pendingOps).get();
      final update = operationsBefore.singleWhere(
        (operation) => operation.operationType == 'dav.update',
      );
      final move = operationsBefore.singleWhere(
        (operation) => operation.operationType == 'dav.move',
      );
      expect(move.dependsOnOpId, update.id);
      expect(update.id, 'z-update-operation');
      expect(move.id, 'a-move-operation');
      expect(move.createdAtUtc, update.createdAtUtc);
      final tasksBefore = await db.select(db.tasks).get();
      final objectsBefore = await db.select(db.davObjects).get();

      final source = await NextcloudNativeExportService(
        db,
      ).collection('account', 'collection');
      final destination = await NextcloudNativeExportService(
        db,
      ).collection('account', 'destination');

      expect(source, isEmpty);
      final exported = destination.single;
      final component = IcalSemanticDocument.parse(
        exported.rawIcs,
      ).components.single;
      expect(exported.uid, 'moved-task@example.test');
      expect(component.summary, 'Final offline title');
      expect(component.parentUid, isNull);
      expect(exported.rawIcs, isNot(contains('RELATED-TO')));
      expect(await db.select(db.pendingOps).get(), operationsBefore);
      expect(await db.select(db.tasks).get(), tasksBefore);
      expect(await db.select(db.davObjects).get(), objectsBefore);
      expect(fixture.requests, isEmpty);
    },
  );
  test(
    'collection export retains an editor event after permanent create rejection',
    () async {
      final db = fixture.database;
      await CalendarRepository(
        database: db,
        now: () => now,
        localTimeZone: 'UTC',
      ).createLocalEvent(
        EventEditorDraft.newEvent(
          accountId: 'account',
          sourceId: 'dav-calendar-collection',
          providerCalendarId: NextcloudAdminFixture.collection,
          start: DateTime.utc(2026, 9, 6, 10),
          end: DateTime.utc(2026, 9, 6, 11),
        ).copyWith(
          title: 'Locally retained event',
          description: 'Must survive export',
        ),
      );
      final queued = await db.select(db.pendingOps).getSingle();
      final request = jsonDecode(queued.requestJson) as Map;
      final uid = request['uid']! as String;
      expect(queued.davObjectId, isNull);
      expect(request.containsKey('suppressScheduling'), isFalse);

      final providerRequests = await permanentlyRejectPendingMutation();
      final failedBefore = await db.select(db.pendingOps).getSingle();
      final eventBefore = await db.select(db.calendarEvents).getSingle();
      expect(failedBefore.state, 'failed');
      expect(failedBefore.lastErrorCode, 'DavMalformedResource');
      expect(providerRequests, hasLength(1));

      final snapshot = await NextcloudNativeExportService(
        db,
      ).collection('account', 'collection');

      final resource = snapshot.single;
      final component = IcalSemanticDocument.parse(
        resource.rawIcs,
      ).components.single;
      expect(resource.uid, uid);
      expect(resource.componentType, 'VEVENT');
      expect(component.uid, uid);
      expect(component.summary, 'Locally retained event');
      expect(component.description, 'Must survive export');
      expect(await db.select(db.pendingOps).getSingle(), failedBefore);
      expect(await db.select(db.calendarEvents).getSingle(), eventBefore);
      expect(await db.select(db.davObjects).get(), isEmpty);
      expect(providerRequests, hasLength(1));
    },
  );
  test(
    'collection export retains an editor task after permanent create rejection',
    () async {
      final db = fixture.database;
      await TasksRepository(
        database: db,
        accountId: 'account',
        nowUtc: () => now,
      ).createTask(
        'dav-task-list-collection',
        const TaskCreateInput(
          title: 'Locally retained task',
          notes: 'Must survive export',
        ),
      );
      final queued = await db.select(db.pendingOps).getSingle();
      final request = jsonDecode(queued.requestJson) as Map;
      final uid = request['uid']! as String;
      expect(queued.davObjectId, isNull);
      expect(request.containsKey('suppressScheduling'), isFalse);

      final providerRequests = await permanentlyRejectPendingMutation();
      final failedBefore = await db.select(db.pendingOps).getSingle();
      final taskBefore = await db.select(db.tasks).getSingle();
      expect(failedBefore.state, 'failed');
      expect(failedBefore.lastErrorCode, 'DavMalformedResource');
      expect(providerRequests, hasLength(1));

      final snapshot = await NextcloudNativeExportService(
        db,
      ).collection('account', 'collection');

      final resource = snapshot.single;
      final component = IcalSemanticDocument.parse(
        resource.rawIcs,
      ).components.single;
      expect(resource.uid, uid);
      expect(resource.componentType, 'VTODO');
      expect(component.uid, uid);
      expect(component.summary, 'Locally retained task');
      expect(component.description, 'Must survive export');
      expect(await db.select(db.pendingOps).getSingle(), failedBefore);
      expect(await db.select(db.tasks).getSingle(), taskBefore);
      expect(await db.select(db.davObjects).get(), isEmpty);
      expect(providerRequests, hasLength(1));
    },
  );
  test('collection export reports a malformed retained creation', () async {
    final db = fixture.database;
    await TasksRepository(
      database: db,
      accountId: 'account',
      nowUtc: () => now,
    ).createTask(
      'dav-task-list-collection',
      const TaskCreateInput(title: 'Corrupt retained task'),
    );
    final operation = await db.select(db.pendingOps).getSingle();
    await (db.update(
      db.pendingOps,
    )..where((row) => row.id.equals(operation.id))).write(
      const PendingOpsCompanion(
        state: Value('failed'),
        requestJson: Value('{"uid":"incomplete"}'),
      ),
    );

    await expectLater(
      NextcloudNativeExportService(db).collection('account', 'collection'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(operation.id),
        ),
      ),
    );
  });
  test(
    'failed existing event edit remains in individual and collection export',
    () async {
      final db = fixture.database;
      await _seedConfirmedResource(
        db,
        now,
        href: _existingEventHref,
        etag: '"event-server"',
        rawIcs: _existingEvent,
      );
      final repository = CalendarRepository(
        database: db,
        now: () => now,
        localTimeZone: 'UTC',
      );
      final event = await db.select(db.calendarEvents).getSingle();
      final detail = await repository.loadEventDetail(event.id);
      await repository.updateLocalEvent(
        EventEditorDraft.fromEventDetail(
          detail!,
        ).copyWith(title: 'Retained local event edit'),
      );

      final providerRequests = await permanentlyRejectPendingMutation();
      final operationBefore = await db.select(db.pendingOps).getSingle();
      final eventBefore = await db.select(db.calendarEvents).getSingle();
      final objectBefore = await db.select(db.davObjects).getSingle();
      expect(operationBefore.state, 'failed');
      expect(operationBefore.operationType, 'dav.update');
      expect(eventBefore.title, 'Retained local event edit');
      expect(providerRequests, hasLength(1));

      final individual =
          await DavPendingOperationQueue(
            database: db,
            nowUtc: () => now,
          ).exportRawIcsForObject(
            accountId: 'account',
            collectionId: 'collection',
            objectId: objectBefore.id,
          );
      final collection = await NextcloudNativeExportService(
        db,
      ).collection('account', 'collection');

      expect(
        IcalSemanticDocument.parse(individual).components.single.summary,
        'Retained local event edit',
      );
      expect(collection, hasLength(1));
      expect(collection.single.uid, 'existing-event@example.test');
      expect(
        IcalSemanticDocument.parse(
          collection.single.rawIcs,
        ).components.single.summary,
        'Retained local event edit',
      );
      expect(await db.select(db.pendingOps).getSingle(), operationBefore);
      expect(await db.select(db.calendarEvents).getSingle(), eventBefore);
      expect(await db.select(db.davObjects).getSingle(), objectBefore);
      expect(providerRequests, hasLength(1));
    },
  );
  test(
    'failed existing task edit remains in individual and collection export',
    () async {
      final db = fixture.database;
      await _seedConfirmedResource(
        db,
        now,
        href: _existingTaskHref,
        etag: '"task-server"',
        rawIcs: _existingTask,
      );
      final task = await db.select(db.tasks).getSingle();
      await TasksRepository(
        database: db,
        accountId: 'account',
        nowUtc: () => now,
      ).updateTaskFull(
        'dav-task-list-collection',
        task.id,
        const TaskPutInput({'title': 'Retained local task edit'}),
      );

      final providerRequests = await permanentlyRejectPendingMutation();
      final operationBefore = await db.select(db.pendingOps).getSingle();
      final taskBefore = await db.select(db.tasks).getSingle();
      final objectBefore = await db.select(db.davObjects).getSingle();
      expect(operationBefore.state, 'failed');
      expect(operationBefore.operationType, 'dav.update');
      expect(taskBefore.title, 'Retained local task edit');
      expect(providerRequests, hasLength(1));

      final individual =
          await DavPendingOperationQueue(
            database: db,
            nowUtc: () => now,
          ).exportRawIcsForObject(
            accountId: 'account',
            collectionId: 'collection',
            objectId: objectBefore.id,
          );
      final collection = await NextcloudNativeExportService(
        db,
      ).collection('account', 'collection');

      expect(
        IcalSemanticDocument.parse(individual).components.single.summary,
        'Retained local task edit',
      );
      expect(collection, hasLength(1));
      expect(collection.single.uid, 'existing-task@example.test');
      expect(
        IcalSemanticDocument.parse(
          collection.single.rawIcs,
        ).components.single.summary,
        'Retained local task edit',
      );
      expect(await db.select(db.pendingOps).getSingle(), operationBefore);
      expect(await db.select(db.tasks).getSingle(), taskBefore);
      expect(await db.select(db.davObjects).getSingle(), objectBefore);
      expect(providerRequests, hasLength(1));
    },
  );
  test(
    'native task import rejects cycles and missing parents without orphan rows',
    () async {
      final cyclic = _raw.replaceFirst(
        'SUMMARY:Parent',
        'RELATED-TO:child\r\nSUMMARY:Parent',
      );
      final results = await importer.import(
        accountId: 'account',
        collectionId: 'collection',
        preview: NextcloudNativeImportPreview.parse(IcalDocument.parse(cyclic)),
        duplicates: NativeImportDuplicates.newCopies,
        normalizeSchedulingMethod: true,
      );
      expect(
        results
            .where((r) => r.componentType == 'VTODO')
            .every((r) => r.status == NativeImportItemStatus.failed),
        isTrue,
      );
      expect(
        await fixture.database.select(fixture.database.tasks).get(),
        isEmpty,
      );
      final missing = _raw.replaceFirst(
        'RELATED-TO:parent',
        'RELATED-TO:missing',
      );
      final more = await importer.import(
        accountId: 'account',
        collectionId: 'collection',
        preview: NextcloudNativeImportPreview.parse(
          IcalDocument.parse(missing),
        ),
        normalizeSchedulingMethod: true,
      );
      expect(
        more.singleWhere((r) => r.uid == 'child').status,
        NativeImportItemStatus.failed,
      );
    },
  );
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
      final confirmed = await fixture.database
          .select(fixture.database.davObjects)
          .get();
      expect(confirmed, hasLength(3));
      expect(confirmed.every((o) => o.etag == '"server"'), isTrue);
      await remote.conditionalPut(
        uri: Uri.parse(confirmed.first.requestUri),
        rawIcs: confirmed.first.rawIcsBody,
        correlationId: 'ordinary-edit',
        ifMatch: '"server"',
      );
      expect(
        puts.last.headers['x-nc-scheduling'],
        isNull,
        reason: 'Import suppression must never leak to ordinary edits.',
      );
    },
  );
}

Future<void> _seedConfirmedResource(
  AppDatabase database,
  DateTime now, {
  required String href,
  required String etag,
  required String rawIcs,
}) {
  return DavObjectRepository(database: database).commit(
    DavCollectionCommit(
      accountId: 'account',
      collectionId: 'collection',
      provider: BusyProvider.nextcloud,
      objects: [
        DavPreparedObject.parse(
          hrefKey: href,
          requestUri: Uri.parse('${NextcloudAdminFixture.origin}$href'),
          etag: etag,
          contentType: 'text/calendar',
          rawIcsBody: rawIcs,
        ),
      ],
      deletedHrefKeys: const {},
      completeMembership: false,
      membershipHrefKeys: const {},
      finalCursorKind: 'dav_sync_token',
      finalCursorValue: 'token-1',
      baselineGeneration: 1,
      completedAtUtc: now,
      projectionRangeStartUtc: DateTime.utc(2025),
      projectionRangeEndUtc: DateTime.utc(2028),
    ),
  );
}

Future<void> _seedDestinationTaskList(
  AppDatabase database,
  DateTime now,
) async {
  const href = '${NextcloudAdminFixture.home}destination/';
  final timestamp = now.toIso8601String();
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'destination',
          accountId: 'account',
          hrefKey: href,
          requestUri: '${NextcloudAdminFixture.origin}$href',
          displayName: 'Destination',
          supportedComponentMask: const Value(3),
          currentUserPrivilegesJson: const Value('["{DAV:}all"]'),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(true),
          taskProjectionEnabled: const Value(true),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: 'dav-task-list-destination',
          davCollectionId: const Value('destination'),
          title: 'Destination',
          rawJson: '{}',
          createdLocalAtUtc: timestamp,
          updatedLocalAtUtc: timestamp,
        ),
      );
}

final class _SequenceUuid extends Uuid {
  _SequenceUuid(List<String> values) : _values = values.iterator;

  final Iterator<String> _values;

  @override
  String v4({Map<String, dynamic>? options, V4Options? config}) {
    if (!_values.moveNext()) throw StateError('No test UUID remains.');
    return _values.current;
  }
}

const _existingEventHref =
    '${NextcloudAdminFixture.collection}existing-event.ics';
const _existingTaskHref =
    '${NextcloudAdminFixture.collection}existing-task.ics';

const _existingEvent = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//BusyMax Test//EN
BEGIN:VEVENT
UID:existing-event@example.test
DTSTART:20260906T100000Z
DTEND:20260906T110000Z
SUMMARY:Server event
END:VEVENT
END:VCALENDAR
''';

const _existingTask = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//BusyMax Test//EN
BEGIN:VTODO
UID:existing-task@example.test
DUE:20260906T120000Z
SUMMARY:Server task
END:VTODO
END:VCALENDAR
''';

const _movableTask = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//BusyMax Test//EN
BEGIN:VTODO
UID:moved-task@example.test
DTSTAMP:20260905T120000Z
SUMMARY:Original title
DESCRIPTION:Move-specific fields must be exported
RELATED-TO:parent@example.test
END:VTODO
END:VCALENDAR
''';

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
