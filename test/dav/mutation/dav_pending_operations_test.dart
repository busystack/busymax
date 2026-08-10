import 'dart:convert';
import 'dart:math';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DavObjectRepository objectRepository;
  late DavPendingOperationQueue queue;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    var objectId = 0;
    objectRepository = DavObjectRepository(
      database: database,
      idFactory: () => 'raw-object-${objectId += 1}',
    );
    await _seed(database, objectRepository);
    queue = DavPendingOperationQueue(
      database: database,
      idFactory: () => 'pending-op',
      nowUtc: () => _now,
    );
  });

  tearDown(() => database.close());

  test(
    'queue retains exact baseline and safely coalesces unsent patches',
    () async {
      final object = await database.select(database.davObjects).getSingle();
      final first = await queue.enqueueUpdate(
        accountId: 'account',
        collectionId: 'collection',
        objectId: object.id,
        patch: _patch('SUMMARY', 'Local title'),
      );
      final second = await queue.enqueueUpdate(
        accountId: 'account',
        collectionId: 'collection',
        objectId: object.id,
        patch: _patch('LOCATION', 'Local room'),
      );

      expect(second, first);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.baselineEtag, 'W/"baseline"');
      expect(pending.baselineRawIcs, _event('Baseline'));
      expect(pending.davCollectionHref, _collectionHref);
      expect(pending.davMemberHref, _eventHref);
      expect(pending.targetComponentKey, contains('event@example.test'));
      expect(pending.mutationScope, 'object');
      expect(pending.requestJson, '{}');
      expect(pending.requestJson, isNot(contains('Authorization')));
      final decoded = DavMutationPatch.fromJsonString(
        pending.mutationPatchJson!,
      );
      expect(decoded.operations, hasLength(2));
      expect(
        decoded.applyTo(pending.baselineRawIcs!, nowUtc: _now),
        allOf(contains('SUMMARY:Local title'), contains('LOCATION:Local room')),
      );
    },
  );

  test(
    'a new replayer instance adopts canonical update after restart',
    () async {
      final object = await database.select(database.davObjects).getSingle();
      await queue.enqueueUpdate(
        accountId: 'account',
        collectionId: 'collection',
        objectId: object.id,
        patch: _patch('SUMMARY', 'After restart'),
      );
      String? sentCandidate;
      final remote = _FakeMutationRemote(
        put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
          expect(ifMatch, 'W/"baseline"');
          expect(ifNoneMatch, isFalse);
          sentCandidate = rawIcs;
          return _success;
        },
        fetcher: (href) async => _live(href, '"canonical"', sentCandidate!),
      );
      final notificationObjects = <String>{};
      final followUpCollections = <String>{};
      // Constructed after enqueue to model process/service reconstruction.
      final replayer = DavPendingOperationsReplayer(
        database: database,
        accountId: 'account',
        objectRepository: objectRepository,
        serviceFactory: ({required account, required collection}) async =>
            DavConditionalMutationService(remoteClient: remote),
        rebuildNotifications: (ids) async => notificationObjects.addAll(ids),
        requestFollowUpSync: (ids) async => followUpCollections.addAll(ids),
        idFactory: () => 'correlation',
        nowUtc: () => _now,
        random: Random(1),
      );

      final result = await replayer.replayDueOperations();

      expect(result.appliedCount, 1);
      expect(result.mutatedCollectionIds, {'collection'});
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final stored = await database.select(database.davObjects).getSingle();
      expect(stored.etag, '"canonical"');
      expect(stored.rawIcsBody, contains('SUMMARY:After restart'));
      expect(
        (await database.select(database.calendarEvents).getSingle()).title,
        'After restart',
      );
      expect(
        (await database.select(database.syncCursors).getSingle()).cursorValue,
        'token-1',
      );
      expect(notificationObjects, {stored.id});
      expect(followUpCollections, {'collection'});
    },
  );

  test('overlapping ETag edit persists all three conflict snapshots', () async {
    final object = await database.select(database.davObjects).getSingle();
    await queue.enqueueUpdate(
      accountId: 'account',
      collectionId: 'collection',
      objectId: object.id,
      patch: _patch('SUMMARY', 'Local'),
    );
    final remote = _FakeMutationRemote(
      put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async =>
          _precondition,
      fetcher: (href) async => _live(href, '"remote"', _event('Remote')),
    );
    final replayer = _replayer(database, objectRepository, remote);

    final result = await replayer.replayDueOperations();

    expect(result.conflictCount, 1);
    final pending = await database.select(database.pendingOps).getSingle();
    expect(pending.state, 'conflict');
    expect(pending.conflictState, 'unresolved');
    final snapshot = await database
        .select(database.davConflictSnapshots)
        .getSingle();
    expect(snapshot.baselineEtag, 'W/"baseline"');
    expect(snapshot.baselineRawIcs, _event('Baseline'));
    expect(snapshot.localCandidateRawIcs, contains('SUMMARY:Local'));
    expect(snapshot.remoteEtag, '"remote"');
    expect(snapshot.remoteRawIcs, _event('Remote'));
    expect(snapshot.conflictCode, 'DavConflictOverlappingProperties');
    expect(
      (await database.select(database.davObjects).getSingle()).rawIcsBody,
      _event('Baseline'),
    );
  });

  test('revoked credential pauses replay and preserves pending work', () async {
    final object = await database.select(database.davObjects).getSingle();
    await queue.enqueueUpdate(
      accountId: 'account',
      collectionId: 'collection',
      objectId: object.id,
      patch: _patch('SUMMARY', 'Keep locally'),
    );
    final remote = _FakeMutationRemote(
      put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
        throw const DavException(
          kind: DavErrorKind.authentication,
          code: 'DavCredentialsRevoked',
          safeMessage: 'The DAV credential was rejected.',
        );
      },
    );

    final result = await _replayer(
      database,
      objectRepository,
      remote,
    ).replayDueOperations();

    expect(result.paused, isTrue);
    final account = await database.select(database.accounts).getSingle();
    expect(account.authState, 'reauth_required');
    final pending = await database.select(database.pendingOps).getSingle();
    expect(pending.state, 'auth_blocked');
    expect(pending.baselineRawIcs, _event('Baseline'));
    expect(await database.select(database.davObjects).get(), hasLength(1));
  });

  test('permission change blocks mutation before a network write', () async {
    final object = await database.select(database.davObjects).getSingle();
    await queue.enqueueUpdate(
      accountId: 'account',
      collectionId: 'collection',
      objectId: object.id,
      patch: _patch('SUMMARY', 'No longer allowed'),
    );
    await database
        .update(database.davCollections)
        .write(const DavCollectionsCompanion(readOnly: Value(true)));
    var writes = 0;
    final remote = _FakeMutationRemote(
      put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
        writes += 1;
        return _success;
      },
    );

    final result = await _replayer(
      database,
      objectRepository,
      remote,
    ).replayDueOperations();

    expect(result.paused, isTrue);
    expect(writes, 0);
    expect(
      (await database.select(database.accounts).getSingle()).authState,
      'permission_changed',
    );
    expect(
      (await database.select(database.pendingOps).getSingle()).state,
      'permission_blocked',
    );
  });

  test('permanent replay failure is reported after it is stored', () async {
    final object = await database.select(database.davObjects).getSingle();
    await queue.enqueueUpdate(
      accountId: 'account',
      collectionId: 'collection',
      objectId: object.id,
      patch: _patch('SUMMARY', 'Rejected'),
    );
    final reported = <DavException>[];
    final remote = _FakeMutationRemote(
      put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
        throw const DavException(
          kind: DavErrorKind.invalidCalendarData,
          code: 'DavMalformedResource',
          safeMessage: 'The DAV server rejected the calendar data.',
          statusCode: 415,
        );
      },
    );
    final replayer = DavPendingOperationsReplayer(
      database: database,
      accountId: 'account',
      objectRepository: objectRepository,
      serviceFactory: ({required account, required collection}) async =>
          DavConditionalMutationService(remoteClient: remote),
      onPermanentFailure: (operation, error) async => reported.add(error),
      idFactory: () => 'failure-correlation',
      nowUtc: () => _now,
    );

    await replayer.replayDueOperations();

    final pending = await database.select(database.pendingOps).getSingle();
    expect(pending.state, 'failed');
    expect(pending.lastErrorCode, 'DavMalformedResource');
    expect(reported, hasLength(1));
    expect(reported.single.statusCode, 415);
  });

  test('queue rejects a VTODO due before its start', () async {
    await expectLater(
      queue.enqueueCreate(
        accountId: 'account',
        collectionId: 'collection',
        object: DavNewObject(
          uid: 'invalid-task@example.test',
          initialMemberName: 'invalid-task.ics',
          rawIcs: _task(
            uid: 'invalid-task@example.test',
            start: 'DTSTART;VALUE=DATE:20260810',
            due: 'DUE;VALUE=DATE:20260809',
          ),
          componentType: 'VTODO',
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

    expect(await database.select(database.pendingOps).get(), isEmpty);
  });

  test('queue rejects mixed all-day and timed VTODO ranges', () async {
    await expectLater(
      queue.enqueueCreate(
        accountId: 'account',
        collectionId: 'collection',
        object: DavNewObject(
          uid: 'mixed-task@example.test',
          initialMemberName: 'mixed-task.ics',
          rawIcs: _task(
            uid: 'mixed-task@example.test',
            start: 'DTSTART;TZID=America/Vancouver:20260810T090000',
            due: 'DUE;VALUE=DATE:20260810',
          ),
          componentType: 'VTODO',
        ),
      ),
      throwsA(
        isA<DavException>().having(
          (error) => error.code,
          'code',
          'DavTaskTemporalTypeMismatch',
        ),
      ),
    );
  });

  test('an explicitly rejected create can be corrected and requeued', () async {
    const projectionId = 'local-task';
    const uid = 'rejected-task@example.test';
    await queue.enqueueCreate(
      accountId: 'account',
      collectionId: 'collection',
      localProjectionId: projectionId,
      object: DavNewObject(
        uid: uid,
        initialMemberName: 'rejected-task.ics',
        rawIcs: _task(
          uid: uid,
          start: 'DTSTART;VALUE=DATE:20260809',
          due: 'DUE;VALUE=DATE:20260810',
        ),
        componentType: 'VTODO',
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

    final updated = await queue.updateUnsentCreate(
      accountId: 'account',
      collectionId: 'collection',
      localProjectionId: projectionId,
      patch: DavMutationPatch(
        target: const IcalComponentKey(componentType: 'VTODO', uid: uid),
        scope: DavMutationScope.object,
        operations: [DavPatchOperation.setText('SUMMARY', 'Corrected task')],
      ),
    );

    expect(updated, isTrue);
    final pending = await database.select(database.pendingOps).getSingle();
    expect(pending.state, 'pending');
    expect(pending.retryClassification, 'conditional_create');
    expect(pending.nextAttemptAtUtc, isNull);
    expect(pending.lastErrorCode, isNull);
    expect(pending.lastErrorMessage, isNull);
    expect(pending.requestJson, contains('SUMMARY:Corrected task'));
  });

  test(
    'MOVE replays to the same filename and commits destination projection',
    () async {
      await _seedDestination(database);
      final source = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(_eventHref))).getSingle();

      await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: source.id,
        target: _target,
      );

      final operation = await database.select(database.pendingOps).getSingle();
      const destinationHref = '/remote.php/dav/calendars/alex/home/event.ics';
      expect(operation.operationType, 'dav.move');
      expect(operation.destinationCollectionId, 'destination');
      expect(operation.destinationMemberHref, destinationHref);
      expect(operation.requestJson, contains('event.ics'));
      var moves = 0;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async {
              moves += 1;
              expect(sourceUri.path, _eventHref);
              expect(destinationUri.path, destinationHref);
              expect(ifMatch, 'W/"baseline"');
              return _success;
            },
        fetcher: (href) async {
          expect(href, destinationHref);
          return _live(href, '"moved"', _event('Baseline'));
        },
      );

      final result = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(moves, 1);
      expect(result.appliedCount, 1);
      expect(result.mutatedCollectionIds, {'collection', 'destination'});
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final objects = await database.select(database.davObjects).get();
      expect(
        objects.singleWhere((object) => object.id == source.id).serverDeleted,
        isTrue,
      );
      final moved = objects.singleWhere(
        (object) => object.collectionId == 'destination',
      );
      expect(moved.hrefKey, destinationHref);
      expect(moved.serverDeleted, isFalse);
      final event = await database.select(database.calendarEvents).getSingle();
      expect(event.calendarSourceId, 'dav-calendar-destination');
      expect(event.davCollectionId, 'destination');
    },
  );

  test('conditional create and delete use confirmed server state', () async {
    final createdBody = _eventWithUid('Created', 'created@example.test');
    await queue.enqueueCreate(
      accountId: 'account',
      collectionId: 'collection',
      object: DavNewObject(
        uid: 'created@example.test',
        initialMemberName: 'opaque-file.ics',
        rawIcs: createdBody,
        componentType: 'VEVENT',
      ),
    );
    final createRemote = _FakeMutationRemote(
      put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
        expect(ifNoneMatch, isTrue);
        expect(ifMatch, isNull);
        return _success;
      },
      fetcher: (href) async => _live(href, '"created"', createdBody),
    );
    await _replayer(
      database,
      objectRepository,
      createRemote,
    ).replayDueOperations();
    expect(await database.select(database.davObjects).get(), hasLength(2));
    expect(await database.select(database.pendingOps).get(), isEmpty);

    final baseline = await (database.select(
      database.davObjects,
    )..where((row) => row.hrefKey.equals(_eventHref))).getSingle();
    await queue.enqueueDelete(
      accountId: 'account',
      collectionId: 'collection',
      objectId: baseline.id,
      target: _target,
    );
    var deletes = 0;
    final deleteRemote = _FakeMutationRemote(
      delete: ({required ifMatch}) async {
        deletes += 1;
        expect(ifMatch, 'W/"baseline"');
        return _success;
      },
    );
    await _replayer(
      database,
      objectRepository,
      deleteRemote,
    ).replayDueOperations();

    expect(deletes, 1);
    expect(
      (await (database.select(
        database.davObjects,
      )..where((row) => row.id.equals(baseline.id))).getSingle()).serverDeleted,
      isTrue,
    );
  });
}

DavPendingOperationsReplayer _replayer(
  AppDatabase database,
  DavObjectRepository repository,
  DavMutationRemoteClient remote,
) => DavPendingOperationsReplayer(
  database: database,
  accountId: 'account',
  objectRepository: repository,
  serviceFactory: ({required account, required collection}) async =>
      DavConditionalMutationService(remoteClient: remote),
  idFactory: () => 'generated-conflict-id',
  nowUtc: () => _now,
  random: Random(1),
);

typedef _Put =
    Future<DavConditionalResponse> Function({
      required String rawIcs,
      required String? ifMatch,
      required bool ifNoneMatch,
    });
typedef _Delete =
    Future<DavConditionalResponse> Function({required String ifMatch});
typedef _Move =
    Future<DavConditionalResponse> Function({
      required Uri sourceUri,
      required Uri destinationUri,
      required String ifMatch,
    });
typedef _Fetch = Future<DavFetchedMember> Function(String href);

final class _FakeMutationRemote implements DavMutationRemoteClient {
  const _FakeMutationRemote({this.put, this.delete, this.move, this.fetcher});

  final _Put? put;
  final _Delete? delete;
  final _Move? move;
  final _Fetch? fetcher;

  @override
  Future<DavConditionalResponse> conditionalPut({
    required Uri uri,
    required String rawIcs,
    required String correlationId,
    String? ifMatch,
    bool ifNoneMatch = false,
  }) => put!(rawIcs: rawIcs, ifMatch: ifMatch, ifNoneMatch: ifNoneMatch);

  @override
  Future<DavConditionalResponse> conditionalDelete({
    required Uri uri,
    required String ifMatch,
    required String correlationId,
  }) => delete!(ifMatch: ifMatch);

  @override
  Future<DavConditionalResponse> conditionalMove({
    required Uri sourceUri,
    required Uri destinationUri,
    required String ifMatch,
    required String correlationId,
  }) => move!(
    sourceUri: sourceUri,
    destinationUri: destinationUri,
    ifMatch: ifMatch,
  );

  @override
  Future<DavFetchedMember> fetch({
    required String hrefKey,
    required Uri uri,
    required String correlationId,
  }) => fetcher!(hrefKey);
}

const _success = DavConditionalResponse(
  status: DavConditionalStatus.success,
  statusCode: 204,
  etag: null,
);
const _precondition = DavConditionalResponse(
  status: DavConditionalStatus.preconditionFailed,
  statusCode: 412,
  etag: null,
);

DavFetchedMember _live(String href, String etag, String body) =>
    DavFetchedMember.live(
      hrefKey: href,
      requestUri: Uri.parse('https://cloud.example.test$href'),
      etag: etag,
      contentType: 'text/calendar',
      rawIcsBody: body,
    );

DavMutationPatch _patch(String property, String value) => DavMutationPatch(
  target: _target,
  scope: DavMutationScope.object,
  operations: [DavPatchOperation.setText(property, value)],
);

const _target = IcalComponentKey(
  componentType: 'VEVENT',
  uid: 'event@example.test',
);
const _collectionHref = '/remote.php/dav/calendars/alex/work/';
const _eventHref = '${_collectionHref}event.ics';
final _now = DateTime.utc(2026, 8, 8, 12);

Future<void> _seed(AppDatabase database, DavObjectRepository repository) async {
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
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'collection',
          accountId: 'account',
          hrefKey: _collectionHref,
          requestUri: 'https://cloud.example.test$_collectionHref',
          displayName: 'Work',
          supportedComponentMask: const Value(3),
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
          id: 'dav-calendar-collection',
          accountId: 'account',
          provider: 'nextcloud',
          providerCalendarId: _collectionHref,
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
  await repository.commit(
    DavCollectionCommit(
      accountId: 'account',
      collectionId: 'collection',
      provider: BusyProvider.nextcloud,
      objects: [
        DavPreparedObject.parse(
          hrefKey: _eventHref,
          requestUri: Uri.parse('https://cloud.example.test$_eventHref'),
          etag: 'W/"baseline"',
          contentType: 'text/calendar',
          rawIcsBody: _event('Baseline'),
        ),
      ],
      deletedHrefKeys: const {},
      completeMembership: true,
      membershipHrefKeys: const {_eventHref},
      finalCursorKind: 'dav_sync_token',
      finalCursorValue: 'token-1',
      baselineGeneration: 1,
      completedAtUtc: _now,
      projectionRangeStartUtc: DateTime.utc(2025),
      projectionRangeEndUtc: DateTime.utc(2029),
    ),
  );
}

Future<void> _seedDestination(AppDatabase database) async {
  const now = '2026-08-08T12:00:00.000Z';
  const href = '/remote.php/dav/calendars/alex/home/';
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'destination',
          accountId: 'account',
          hrefKey: href,
          requestUri: 'https://cloud.example.test$href',
          displayName: 'Home',
          supportedComponentMask: const Value(3),
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
          id: 'dav-calendar-destination',
          accountId: 'account',
          provider: 'nextcloud',
          providerCalendarId: href,
          davCollectionId: const Value('destination'),
          summary: 'Home',
          createdAtLocal: _now.millisecondsSinceEpoch,
          updatedAtLocal: _now.millisecondsSinceEpoch,
        ),
      );
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: 'dav-task-list-destination',
          davCollectionId: const Value('destination'),
          title: 'Home',
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
}

String _event(String summary) => _eventWithUid(summary, 'event@example.test');

String _task({
  required String uid,
  required String start,
  required String due,
}) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VTODO\r
UID:$uid\r
DTSTAMP:20260808T120000Z\r
$start\r
$due\r
SUMMARY:Task\r
END:VTODO\r
END:VCALENDAR\r
''';

String _eventWithUid(String summary, String uid) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:$uid\r
DTSTART:20260808T090000Z\r
DTEND:20260808T100000Z\r
SUMMARY:$summary\r
LOCATION:Baseline room\r
END:VEVENT\r
END:VCALENDAR\r
''';
