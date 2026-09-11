import 'dart:convert';
import 'dart:math';

import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/ical/ical_task_alarm.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_conflict_repository.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/maps/application/external_location_launcher.dart';
import 'package:busymax/src/features/maps/application/location_destination_resolver.dart';
import 'package:busymax/src/features/maps/data/location_resolution_repository.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/notifications/notification_scheduler.dart';
import 'package:busymax/src/features/sync/pending_op_resolution_service.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

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

  test(
    'Keep server preserves both identities after a MOVE destination collision',
    () async {
      await _seedDestination(database);
      final sourceObject = await database
          .select(database.davObjects)
          .getSingle();
      final sourceEvent = await database
          .select(database.calendarEvents)
          .getSingle();
      const destinationHref = '/remote.php/dav/calendars/alex/home/event.ics';
      final destinationRaw = _eventWithUid(
        'Unrelated destination',
        'destination-event@example.test',
      );
      await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: sourceObject.id,
        localProjectionId: sourceEvent.id,
        target: _target,
      );
      var moveRequests = 0;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async {
              moveRequests += 1;
              expect(sourceUri.path, _eventHref);
              expect(destinationUri.path, destinationHref);
              expect(ifMatch, 'W/"baseline"');
              return _precondition;
            },
        fetcher: (href) async => href == destinationHref
            ? _live(href, '"destination"', destinationRaw)
            : _live(href, 'W/"baseline"', _event('Baseline')),
      );

      final replay = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(replay.conflictCount, 1);
      final conflict = await DavConflictRepository(
        database: database,
      ).watchUnresolved().first;
      expect(conflict.single.conflictCode, 'DavConflictMoveDestinationExists');
      expect(conflict.single.canKeepServer, isTrue);
      expect(conflict.single.canReapplyLocal, isFalse);

      await DavConflictResolutionService(
        database: database,
        objectRepository: objectRepository,
        nowUtc: () => _now,
      ).resolve(conflict.single.id, DavConflictResolution.keepServer);

      expect(moveRequests, 1);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final source = await (database.select(
        database.davObjects,
      )..where((row) => row.collectionId.equals('collection'))).getSingle();
      final destination = await (database.select(
        database.davObjects,
      )..where((row) => row.collectionId.equals('destination'))).getSingle();
      expect(source.hrefKey, _eventHref);
      expect(source.requestUri, 'https://cloud.example.test$_eventHref');
      expect(source.primaryUid, 'event@example.test');
      expect(source.rawIcsBody, _event('Baseline'));
      expect(source.etag, 'W/"baseline"');
      expect(destination.hrefKey, destinationHref);
      expect(
        destination.requestUri,
        'https://cloud.example.test$destinationHref',
      );
      expect(destination.primaryUid, 'destination-event@example.test');
      expect(destination.rawIcsBody, destinationRaw);
      expect(destination.etag, '"destination"');
      final events = await database.select(database.calendarEvents).get();
      expect(events.map((event) => event.title).toSet(), {
        'Baseline',
        'Unrelated destination',
      });
      expect(
        (await database.select(database.davConflictSnapshots).getSingle())
            .resolution,
        DavConflictResolution.keepServer.name,
      );
    },
  );

  test(
    'Keep server accepts a remotely changed MOVE destination under its identity',
    () async {
      await _seedDestination(database);
      final source = await database.select(database.davObjects).getSingle();
      final operationId = await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: source.id,
        target: _target,
        postMovePatch: _patch('SUMMARY', 'Intended title'),
      );
      const destinationHref = '/remote.php/dav/calendars/alex/home/event.ics';
      var sourceExists = true;
      String? destinationRaw;
      var destinationEtag = '"moved"';
      var moves = 0;
      var puts = 0;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async {
              moves += 1;
              sourceExists = false;
              destinationRaw = _event('Baseline');
              return _success;
            },
        put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
          puts += 1;
          expect(rawIcs, contains('SUMMARY:Intended title'));
          throw const DavException(
            kind: DavErrorKind.invalidCalendarData,
            code: 'DavMalformedResource',
            safeMessage: 'The destination patch was rejected.',
            statusCode: 415,
          );
        },
        fetcher: (href) async {
          if (href == destinationHref && destinationRaw != null) {
            return _live(href, destinationEtag, destinationRaw!);
          }
          if (href == _eventHref && sourceExists) {
            return _live(href, 'W/"baseline"', _event('Baseline'));
          }
          return _missing(href);
        },
      );
      final replayer = _replayer(database, objectRepository, remote);

      await replayer.replayDueOperations();
      final failed = await database.pendingOpsDao.getOp(operationId);
      expect(failed?.state, 'failed');
      expect(failed?.retryClassification, davPartialMoveRetryClassification);
      expect(moves, 1);
      expect(puts, 1);

      destinationRaw = _event('Changed by another client');
      destinationEtag = '"changed-remotely"';
      await PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncTasks: () async => fail('An event move must not sync tasks.'),
        syncCalendar: () async {
          final result = await replayer.replayDueOperations();
          expect(result.conflictCount, 1);
        },
        nowUtc: () => _now,
      ).retryNow(operationId);

      final conflicts = await DavConflictRepository(
        database: database,
      ).watchUnresolved().first;
      expect(conflicts, hasLength(1));
      expect(
        conflicts.single.conflictCode,
        'DavConflictMoveDestinationChanged',
      );
      expect(conflicts.single.canKeepServer, isTrue);
      expect(conflicts.single.canDuplicate, isTrue);

      await DavConflictResolutionService(
        database: database,
        objectRepository: objectRepository,
        nowUtc: () => _now,
      ).resolve(conflicts.single.id, DavConflictResolution.keepServer);

      expect(moves, 1);
      expect(puts, 1);
      expect(await database.pendingOpsDao.getOp(operationId), isNull);
      final sourceAfter = await (database.select(
        database.davObjects,
      )..where((row) => row.id.equals(source.id))).getSingle();
      expect(sourceAfter.serverDeleted, isTrue);
      final destination = await (database.select(
        database.davObjects,
      )..where((row) => row.collectionId.equals('destination'))).getSingle();
      expect(destination.hrefKey, destinationHref);
      expect(
        destination.requestUri,
        'https://cloud.example.test$destinationHref',
      );
      expect(destination.primaryUid, 'event@example.test');
      expect(destination.etag, '"changed-remotely"');
      expect(destination.rawIcsBody, _event('Changed by another client'));
      final events = await database.select(database.calendarEvents).get();
      expect(events, hasLength(1));
      expect(events.single.calendarSourceId, 'dav-calendar-destination');
      expect(events.single.title, 'Changed by another client');
    },
  );

  test(
    'Keep server resolves a MOVE whose source and destination are absent',
    () async {
      await _seedDestination(database);
      final source = await database.select(database.davObjects).getSingle();
      final operationId = await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: source.id,
        target: _target,
      );
      var moves = 0;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async {
              moves += 1;
              return _precondition;
            },
        fetcher: (href) async => _missing(href),
      );

      final result = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(result.conflictCount, 1);
      final conflict = await DavConflictRepository(
        database: database,
      ).watchUnresolved().first;
      expect(conflict.single.conflictCode, 'DavConflictMoveSourceRemoved');
      expect(conflict.single.canKeepServer, isTrue);
      expect(conflict.single.canDuplicate, isTrue);

      await DavConflictResolutionService(
        database: database,
        objectRepository: objectRepository,
        nowUtc: () => _now,
      ).resolve(conflict.single.id, DavConflictResolution.keepServer);

      expect(moves, 1);
      expect(await database.pendingOpsDao.getOp(operationId), isNull);
      expect(
        (await (database.select(
          database.davObjects,
        )..where((row) => row.id.equals(source.id))).getSingle()).serverDeleted,
        isTrue,
      );
      expect(
        await (database.select(
          database.davObjects,
        )..where((row) => row.collectionId.equals('destination'))).get(),
        isEmpty,
      );
      expect(await database.select(database.calendarEvents).get(), isEmpty);
    },
  );

  test(
    'Keep server resolves a MOVE retry limit using the retained source',
    () async {
      await _seedDestination(database);
      final source = await database.select(database.davObjects).getSingle();
      final operationId = await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: source.id,
        target: _target,
      );
      var moves = 0;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async {
              moves += 1;
              return _precondition;
            },
        fetcher: (href) async => href == _eventHref
            ? _live(href, '"latest-source"', _event('Baseline'))
            : _missing(href),
      );

      final result = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(result.conflictCount, 1);
      final conflict = await DavConflictRepository(
        database: database,
      ).watchUnresolved().first;
      expect(conflict.single.conflictCode, 'DavConflictRetryLimitExceeded');
      expect(conflict.single.canKeepServer, isTrue);
      expect(conflict.single.canDuplicate, isTrue);

      await DavConflictResolutionService(
        database: database,
        objectRepository: objectRepository,
        nowUtc: () => _now,
      ).resolve(conflict.single.id, DavConflictResolution.keepServer);

      expect(moves, 3);
      expect(await database.pendingOpsDao.getOp(operationId), isNull);
      final retained = await (database.select(
        database.davObjects,
      )..where((row) => row.id.equals(source.id))).getSingle();
      expect(retained.serverDeleted, isFalse);
      expect(retained.collectionId, 'collection');
      expect(retained.hrefKey, _eventHref);
      expect(retained.etag, '"latest-source"');
      expect(retained.primaryUid, 'event@example.test');
    },
  );

  test(
    'Keep server cancels an unattempted task subtree after child MOVE collision',
    () async {
      await _seedDestination(database);
      const parentUid = 'parent@example.test';
      const childUid = 'child@example.test';
      const parentHref = '${_collectionHref}parent-task.ics';
      const childHref = '${_collectionHref}child-task.ics';
      const destinationChildHref =
          '/remote.php/dav/calendars/alex/home/child-task.ics';
      final parentRaw = _task(
        uid: parentUid,
        start: 'DTSTART:20260809T090000Z',
        due: 'DUE:20260809T100000Z',
      );
      final childRaw = _taskWithParent(childUid, 'Child task');
      await _commitMembers(
        objectRepository,
        collectionId: 'collection',
        objects: [
          _preparedMember(href: parentHref, etag: '"parent"', body: parentRaw),
          _preparedMember(href: childHref, etag: '"child"', body: childRaw),
        ],
      );
      final sourceTasks = await database.tasksDao.listTasks(
        'account',
        'dav-task-list-collection',
      );
      final parent = sourceTasks.singleWhere(
        (task) => task.icalUid == parentUid,
      );
      final child = sourceTasks.singleWhere((task) => task.icalUid == childUid);
      await TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => _now,
      ).moveTask(
        TaskMoveInput(
          sourceTaskListId: 'dav-task-list-collection',
          destinationTaskListId: 'dav-task-list-destination',
          taskId: parent.id,
        ),
      );
      final operations = await database.select(database.pendingOps).get();
      final childMove = operations.singleWhere(
        (operation) => operation.taskId == child.id,
      );
      final parentMove = operations.singleWhere(
        (operation) => operation.taskId == parent.id,
      );
      expect(parentMove.dependsOnOpId, childMove.id);
      expect(parentMove.createdAtUtc, childMove.createdAtUtc);

      final unrelatedRaw = _task(
        uid: 'unrelated-destination@example.test',
        start: 'DTSTART:20260810T090000Z',
        due: 'DUE:20260810T100000Z',
      );
      var moves = 0;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async {
              moves += 1;
              expect(sourceUri.path, childHref);
              expect(destinationUri.path, destinationChildHref);
              return _precondition;
            },
        fetcher: (href) async {
          if (href == destinationChildHref) {
            return _live(href, '"unrelated"', unrelatedRaw);
          }
          if (href == childHref) {
            return _live(href, '"child"', childRaw);
          }
          return _missing(href);
        },
      );
      final replayer = _replayer(database, objectRepository, remote);
      final firstReplay = await replayer.replayDueOperations();
      expect(firstReplay.conflictCount, 1);
      expect(moves, 1);
      expect(
        (await database.pendingOpsDao.getOp(childMove.id))?.state,
        'conflict',
      );
      expect(
        (await database.pendingOpsDao.getOp(parentMove.id))?.state,
        'pending',
      );

      final conflict = await DavConflictRepository(
        database: database,
      ).watchUnresolved().first;
      expect(conflict.single.conflictCode, 'DavConflictMoveDestinationExists');
      final resolutionService = DavConflictResolutionService(
        database: database,
        objectRepository: objectRepository,
        nowUtc: () => _now,
      );
      await (database.update(database.pendingOps)
            ..where((row) => row.id.equals(parentMove.id)))
          .write(const PendingOpsCompanion(attemptCount: Value(1)));
      await expectLater(
        resolutionService.resolve(
          conflict.single.id,
          DavConflictResolution.keepServer,
        ),
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'DavConflictResolutionUnavailable',
          ),
        ),
      );
      expect(await database.select(database.pendingOps).get(), hasLength(2));
      expect(
        await (database.select(
          database.davObjects,
        )..where((row) => row.collectionId.equals('destination'))).get(),
        isEmpty,
      );

      await (database.update(database.pendingOps)
            ..where((row) => row.id.equals(parentMove.id)))
          .write(const PendingOpsCompanion(attemptCount: Value(0)));
      await resolutionService.resolve(
        conflict.single.id,
        DavConflictResolution.keepServer,
      );

      expect(await database.select(database.pendingOps).get(), isEmpty);
      final secondReplay = await replayer.replayDueOperations();
      expect(secondReplay.appliedCount, 0);
      expect(moves, 1);
      final restoredSourceTasks = await database.tasksDao.listTasks(
        'account',
        'dav-task-list-collection',
      );
      expect(restoredSourceTasks.map((task) => task.icalUid).toSet(), {
        parentUid,
        childUid,
      });
      final restoredParent = restoredSourceTasks.singleWhere(
        (task) => task.icalUid == parentUid,
      );
      final restoredChild = restoredSourceTasks.singleWhere(
        (task) => task.icalUid == childUid,
      );
      expect(restoredChild.parent, restoredParent.id);
      expect(restoredChild.parentUid, parentUid);
      final destinationTasks = await database.tasksDao.listTasks(
        'account',
        'dav-task-list-destination',
      );
      expect(destinationTasks, hasLength(1));
      expect(
        destinationTasks.single.icalUid,
        'unrelated-destination@example.test',
      );
      final destinationObject = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(destinationChildHref))).getSingle();
      expect(destinationObject.collectionId, 'destination');
      expect(
        destinationObject.primaryUid,
        'unrelated-destination@example.test',
      );
      expect(destinationObject.etag, '"unrelated"');
      expect(destinationObject.rawIcsBody, unrelatedRaw);
    },
  );

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
        .write(
          const DavCollectionsCompanion(
            readOnly: Value(true),
            currentUserPrivilegesJson: Value(
              '["{DAV:}read","{DAV:}write-properties"]',
            ),
          ),
        );
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

  test(
    'Diagnostics retry makes a failed DAV update perform a real replay',
    () async {
      final object = await database.select(database.davObjects).getSingle();
      await queue.enqueueUpdate(
        accountId: 'account',
        collectionId: 'collection',
        objectId: object.id,
        patch: _patch('SUMMARY', 'Recovered update'),
      );
      var writes = 0;
      String? sentCandidate;
      final remote = _FakeMutationRemote(
        put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
          writes += 1;
          if (writes == 1) {
            throw const DavException(
              kind: DavErrorKind.invalidCalendarData,
              code: 'DavMalformedResource',
              safeMessage: 'The DAV server could not update the object.',
              statusCode: 415,
            );
          }
          sentCandidate = rawIcs;
          return _success;
        },
        fetcher: (href) async => writes == 1
            ? _live(href, 'W/"baseline"', _event('Baseline'))
            : _live(href, '"recovered"', sentCandidate!),
      );
      final replayer = _replayer(database, objectRepository, remote);
      await replayer.replayDueOperations();
      final failed = await database.select(database.pendingOps).getSingle();
      expect(failed.state, 'failed');
      expect(
        await database.pendingOpsDao.watchBlockedOps('account').first,
        hasLength(1),
      );

      var calendarSyncs = 0;
      final recovery = PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncTasks: () async => fail('An event retry must not run task sync.'),
        syncCalendar: () async {
          calendarSyncs += 1;
          final result = await replayer.replayDueOperations();
          expect(result.appliedCount, 1);
        },
        nowUtc: () => _now,
      );

      await recovery.retryNow(failed.id);

      expect(calendarSyncs, 1);
      expect(writes, 2);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(
        await database.pendingOpsDao.watchBlockedOps('account').first,
        isEmpty,
      );
      expect(
        (await database.select(database.calendarEvents).getSingle()).title,
        'Recovered update',
      );
    },
  );

  test(
    'Diagnostics retry reconciles a created DAV resource before another PUT',
    () async {
      const uid = 'created-before-fetch-failure@example.test';
      final raw = _eventWithUid('Created once', uid);
      await queue.enqueueCreate(
        accountId: 'account',
        collectionId: 'collection',
        object: DavNewObject(
          uid: uid,
          initialMemberName: 'created-before-fetch-failure.ics',
          rawIcs: raw,
          componentType: 'VEVENT',
        ),
      );
      var puts = 0;
      var fetches = 0;
      var allocatedNames = 0;
      final remote = _FakeMutationRemote(
        put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
          puts += 1;
          expect(ifMatch, isNull);
          expect(ifNoneMatch, isTrue);
          return _success;
        },
        fetcher: (href) async {
          fetches += 1;
          if (fetches == 1) {
            throw const DavException(
              kind: DavErrorKind.protocol,
              code: 'DavMutationFetchMissingEtag',
              safeMessage: 'The DAV object response omitted its ETag.',
            );
          }
          return _live(href, '"created"', raw);
        },
      );
      final replayer = DavPendingOperationsReplayer(
        database: database,
        accountId: 'account',
        objectRepository: objectRepository,
        serviceFactory: ({required account, required collection}) async =>
            DavConditionalMutationService(
              remoteClient: remote,
              memberIdFactory: () {
                allocatedNames += 1;
                return 'unexpected-name';
              },
            ),
        idFactory: () => 'create-recovery-correlation',
        nowUtc: () => _now,
        random: Random(1),
      );

      await replayer.replayDueOperations();
      final failed = await database.select(database.pendingOps).getSingle();
      expect(failed.state, 'failed');
      expect(failed.attemptCount, 0);
      expect(failed.lastErrorCode, 'DavMutationFetchMissingEtag');

      await PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncTasks: () async => fail('An event retry must not sync tasks.'),
        syncCalendar: () async {
          final retrying = await database.pendingOpsDao.getOp(failed.id);
          expect(retrying?.attemptCount, 0);
          expect(retrying?.retryClassification, 'manual_retry');
          final result = await replayer.replayDueOperations();
          expect(result.appliedCount, 1);
        },
        nowUtc: () => _now,
      ).retryNow(failed.id);

      expect(puts, 1);
      expect(fetches, 2);
      expect(allocatedNames, 0);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      final created =
          await (database.select(database.davObjects)..where(
                (row) => row.hrefKey.equals(
                  '${_collectionHref}created-before-fetch-failure.ics',
                ),
              ))
              .getSingle();
      expect(created.etag, '"created"');
      expect(created.primaryUid, uid);
    },
  );

  test(
    'Diagnostics leaves DAV conflicts blocked for conflict review',
    () async {
      final object = await database.select(database.davObjects).getSingle();
      await queue.enqueueUpdate(
        accountId: 'account',
        collectionId: 'collection',
        objectId: object.id,
        patch: _patch('SUMMARY', 'Conflicting update'),
      );
      await database
          .update(database.pendingOps)
          .write(
            const PendingOpsCompanion(
              state: Value('conflict'),
              retryClassification: Value('manual_conflict_resolution'),
              nextAttemptAtUtc: Value('9999-12-31T23:59:59.999Z'),
              lastErrorCode: Value('DavResourceConflict'),
            ),
          );
      final before = await database.select(database.pendingOps).getSingle();
      var syncs = 0;
      final recovery = PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncTasks: () async => syncs += 1,
        syncCalendar: () async => syncs += 1,
        nowUtc: () => _now,
      );

      await expectLater(
        recovery.retryNow(before.id),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('conflict review'),
          ),
        ),
      );

      expect(await database.select(database.pendingOps).getSingle(), before);
      expect(
        await database.pendingOpsDao.watchBlockedOps('account').first,
        hasLength(1),
      );
      expect(syncs, 0);
    },
  );

  test('Diagnostics discard restores a failed DAV update baseline', () async {
    final object = await database.select(database.davObjects).getSingle();
    await queue.enqueueUpdate(
      accountId: 'account',
      collectionId: 'collection',
      objectId: object.id,
      patch: _patch('SUMMARY', 'Discard this update'),
    );
    final operation = await database.select(database.pendingOps).getSingle();
    final candidate = DavMutationPatch.fromJsonString(
      operation.mutationPatchJson!,
    ).applyTo(operation.baselineRawIcs!, nowUtc: _now);
    await objectRepository.projectLocalMutationCandidate(
      accountId: 'account',
      collectionId: 'collection',
      provider: BusyProvider.nextcloud,
      objectId: object.id,
      candidateRawIcs: candidate,
      projectedAtUtc: _now,
    );
    expect(
      (await database.select(database.calendarEvents).getSingle()).title,
      'Discard this update',
    );
    final remote = _FakeMutationRemote(
      put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
        throw const DavException(
          kind: DavErrorKind.invalidCalendarData,
          code: 'DavMalformedResource',
          safeMessage: 'The DAV server could not update the object.',
          statusCode: 415,
        );
      },
    );
    await _replayer(database, objectRepository, remote).replayDueOperations();
    expect(
      (await database.select(database.pendingOps).getSingle()).state,
      'failed',
    );

    var syncs = 0;
    await PendingOpResolutionService(
      database: database,
      accountId: 'account',
      syncTasks: () async => fail('An event discard must not sync tasks.'),
      syncCalendar: () async => syncs += 1,
      nowUtc: () => _now,
    ).discard(operation.id);

    expect(await database.select(database.pendingOps).get(), isEmpty);
    final restored = await database.select(database.calendarEvents).getSingle();
    expect(restored.title, 'Baseline');
    expect(restored.syncStatus, 'synced');
    expect(syncs, 1);
  });

  test(
    'Diagnostics discard removes a rejected local DAV task and dependents',
    () async {
      var schedulerNow = _now;
      final reminderAt = _now.add(const Duration(hours: 1));
      final notificationBackend = _RecordingNotificationBackend();
      final scheduler = NotificationScheduler(
        database: database,
        notifications: DesktopNotificationService(
          backend: notificationBackend,
          settings: AppSettings.defaults(),
        ),
        nowUtc: () => schedulerNow,
      );
      addTearDown(scheduler.stop);
      final tasks = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => _now,
      );
      await tasks.createTask(
        'dav-task-list-collection',
        TaskCreateInput(
          title: 'Rejected local task',
          fields: {
            'taskAlarms': [IcalTaskAlarm.displayAbsolute(reminderAt).toJson()],
          },
        ),
      );
      final task = (await database.tasksDao.listTasks(
        'account',
        'dav-task-list-collection',
      )).single;
      final create = await database.select(database.pendingOps).getSingle();
      expect(create.operationType, 'dav.create');
      expect(create.taskListId, isNull);
      expect(create.taskId, task.id);
      expect(
        await database.select(database.notificationSchedule).get(),
        hasLength(1),
      );
      final dependentId =
          await DavPendingOperationQueue(
            database: database,
            idFactory: () => 'dependent-create',
            nowUtc: () => _now,
          ).enqueueCreate(
            accountId: 'account',
            collectionId: 'collection',
            object: DavNewObject(
              uid: 'dependent@example.test',
              initialMemberName: 'dependent.ics',
              rawIcs: _task(
                uid: 'dependent@example.test',
                start: 'DTSTART;VALUE=DATE:20260809',
                due: 'DUE;VALUE=DATE:20260810',
              ),
              componentType: 'VTODO',
            ),
            dependsOnOperationId: create.id,
          );
      var writes = 0;
      final remote = _FakeMutationRemote(
        put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
          writes += 1;
          throw const DavException(
            kind: DavErrorKind.invalidCalendarData,
            code: 'DavMalformedResource',
            safeMessage: 'The DAV server could not update the object.',
            statusCode: 415,
          );
        },
      );
      await _replayer(database, objectRepository, remote).replayDueOperations();
      final failed = await database.pendingOpsDao.getOp(create.id);
      expect(failed?.state, 'failed');
      expect(
        await database.pendingOpsDao.getOp(dependentId),
        isNot(equals(null)),
      );
      expect(writes, 1);

      var syncs = 0;
      await PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncTasks: () async => syncs += 1,
        syncCalendar: () async => fail('A task discard must not sync events.'),
        onNotificationScheduleChanged: scheduler.checkNow,
        nowUtc: () => _now,
      ).discard(create.id);

      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(
        await database.tasksDao.listTasks(
          'account',
          'dav-task-list-collection',
        ),
        isEmpty,
      );
      expect(
        await database.select(database.notificationSchedule).get(),
        isEmpty,
      );
      schedulerNow = reminderAt.add(const Duration(minutes: 1));
      await scheduler.checkNow();
      expect(notificationBackend.requests, isEmpty);
      expect(syncs, 0);
      expect(writes, 1);
    },
  );

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
      final sourceEvent = await database
          .select(database.calendarEvents)
          .getSingle();
      final remembered = LocationResult(
        label: 'Original resolved room',
        point: GeographicPoint(latitude: 49.2827, longitude: -123.1207),
        source: 'legacy-import',
        attribution: 'Original provider',
      );
      await LocationResolutionRepository(database).apply(
        LocationItemIdentity(
          kind: LocationItemKind.event,
          accountId: 'account',
          sourceId: sourceEvent.calendarSourceId,
          itemId: sourceEvent.id,
        ),
        sourceEvent.location!,
        LocationChange.replace(remembered),
      );

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
      final resolutions = await database
          .select(database.locationResolutions)
          .get();
      expect(resolutions, hasLength(1));
      expect(resolutions.single.sourceId, 'dav-calendar-destination');
      expect(resolutions.single.itemId, event.id);
      expect(resolutions.single.label, remembered.label);
      expect(resolutions.single.source, remembered.source);
      expect(resolutions.single.attribution, remembered.attribution);
      expect(
        await LocationResolutionRepository(database).load(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: 'account',
            sourceId: event.calendarSourceId,
            itemId: event.id,
          ),
          event.location!,
        ),
        remembered,
      );
    },
  );

  test(
    'Diagnostics discard reconciles a move completed before its patch failed',
    () async {
      await _seedDestination(database);
      const uid = 'partial-move-task@example.test';
      const sourceHref = '${_collectionHref}partial-move-task.ics';
      const destinationHref =
          '/remote.php/dav/calendars/alex/home/partial-move-task.ics';
      final sourceRaw = _taskWithParent(uid, 'Parented task');
      await objectRepository.commitConfirmedMutation(
        accountId: 'account',
        collectionId: 'collection',
        provider: BusyProvider.nextcloud,
        canonicalObject: _preparedMember(
          href: sourceHref,
          etag: '"task-source"',
          body: sourceRaw,
        ),
        completedAtUtc: _now,
      );
      final task = (await database.tasksDao.listTasks(
        'account',
        'dav-task-list-collection',
      )).single;
      expect(task.parentUid, 'parent@example.test');
      await TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => _now,
      ).moveTask(
        TaskMoveInput(
          sourceTaskListId: 'dav-task-list-collection',
          destinationTaskListId: 'dav-task-list-destination',
          taskId: task.id,
        ),
      );
      final locallyMoved = (await database.tasksDao.listTasks(
        'account',
        'dav-task-list-destination',
      )).single;
      expect(locallyMoved.parentUid, isNull);

      var sourceExists = true;
      String? destinationRaw;
      var moves = 0;
      var destinationPatchPuts = 0;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async {
              moves += 1;
              expect(sourceUri.path, sourceHref);
              expect(destinationUri.path, destinationHref);
              sourceExists = false;
              destinationRaw = sourceRaw;
              return _success;
            },
        put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
          destinationPatchPuts += 1;
          expect(ifMatch, '"task-destination"');
          expect(ifNoneMatch, isFalse);
          expect(rawIcs, isNot(contains('RELATED-TO')));
          throw const DavException(
            kind: DavErrorKind.invalidCalendarData,
            code: 'DavMalformedResource',
            safeMessage: 'The DAV server rejected the destination task.',
            statusCode: 415,
          );
        },
        fetcher: (href) async {
          if (href == sourceHref) {
            return sourceExists
                ? _live(href, '"task-source"', sourceRaw)
                : _missing(href);
          }
          if (href == destinationHref && destinationRaw != null) {
            return _live(href, '"task-destination"', destinationRaw!);
          }
          return _missing(href);
        },
      );
      final replayer = _replayer(database, objectRepository, remote);
      await replayer.replayDueOperations();
      final failed = await database.select(database.pendingOps).getSingle();
      expect(failed.operationType, 'dav.move');
      expect(failed.state, 'failed');
      expect(failed.retryClassification, davPartialMoveRetryClassification);
      expect(failed.lastErrorCode, davPartialMoveFailureCode);
      expect(moves, 1);
      expect(destinationPatchPuts, 1);

      await expectLater(
        PendingOpResolutionService(
          database: database,
          accountId: 'account',
          syncCalendar: () async => fail('A task move must use task sync.'),
          syncTasks: () async => throw StateError('Synchronization failed.'),
          nowUtc: () => _now,
        ).discard(failed.id),
        throwsA(isA<StateError>()),
      );
      expect(
        (await database.pendingOpsDao.getOp(failed.id))?.retryClassification,
        davPartialMoveRetryClassification,
      );

      final reconciledAt = _now.add(const Duration(minutes: 1));
      var syncs = 0;
      await PendingOpResolutionService(
        database: database,
        accountId: 'account',
        syncCalendar: () async => fail('A task move must use task sync.'),
        syncTasks: () async {
          syncs += 1;
          final retained = await database.pendingOpsDao.getOp(failed.id);
          expect(
            retained?.retryClassification,
            davPartialMoveRetryClassification,
          );
          await objectRepository.commit(
            DavCollectionCommit(
              accountId: 'account',
              collectionId: 'collection',
              provider: BusyProvider.nextcloud,
              objects: const [],
              deletedHrefKeys: const {},
              completeMembership: true,
              membershipHrefKeys: const {_eventHref},
              finalCursorKind: 'dav_sync_token',
              finalCursorValue: 'source-after-partial-move',
              baselineGeneration: 2,
              completedAtUtc: reconciledAt,
              projectionRangeStartUtc: DateTime.utc(2025),
              projectionRangeEndUtc: DateTime.utc(2029),
            ),
          );
          await objectRepository.commit(
            DavCollectionCommit(
              accountId: 'account',
              collectionId: 'destination',
              provider: BusyProvider.nextcloud,
              objects: [
                _preparedMember(
                  href: destinationHref,
                  etag: '"task-destination"',
                  body: destinationRaw!,
                ),
              ],
              deletedHrefKeys: const {},
              completeMembership: true,
              membershipHrefKeys: const {destinationHref},
              finalCursorKind: 'dav_sync_token',
              finalCursorValue: 'destination-after-partial-move',
              baselineGeneration: 1,
              completedAtUtc: reconciledAt,
              projectionRangeStartUtc: DateTime.utc(2025),
              projectionRangeEndUtc: DateTime.utc(2029),
            ),
          );
        },
        nowUtc: () => reconciledAt,
      ).discard(failed.id);

      expect(syncs, 1);
      expect(moves, 1);
      expect(destinationPatchPuts, 1);
      expect(sourceExists, isFalse);
      expect(destinationRaw, contains('RELATED-TO:parent@example.test'));
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(
        await database.tasksDao.listTasks(
          'account',
          'dav-task-list-collection',
        ),
        isEmpty,
      );
      final reconciledTask = (await database.tasksDao.listTasks(
        'account',
        'dav-task-list-destination',
      )).single;
      expect(reconciledTask.parentUid, 'parent@example.test');
      expect(reconciledTask.title, 'Parented task');
      final sourceObject = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(sourceHref))).getSingle();
      expect(sourceObject.serverDeleted, isTrue);
      final destinationObject = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(destinationHref))).getSingle();
      expect(destinationObject.collectionId, 'destination');
      expect(destinationObject.serverDeleted, isFalse);
    },
  );

  test(
    'failed move reconciliation retains its partial remote outcome marker',
    () async {
      await _seedDestination(database);
      final source = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(_eventHref))).getSingle();
      final operationId = await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: source.id,
        target: _target,
      );
      await (database.update(
        database.pendingOps,
      )..where((row) => row.id.equals(operationId))).write(
        PendingOpsCompanion(
          state: const Value('failed'),
          retryClassification: const Value(davPartialMoveRetryClassification),
          nextAttemptAtUtc: const Value('9999-12-31T23:59:59.999Z'),
          lastErrorCode: const Value(davPartialMoveFailureCode),
          lastErrorMessage: const Value('The destination update was rejected.'),
        ),
      );

      await queue.retryBlockedOperation(
        accountId: 'account',
        operationId: operationId,
      );
      final retried = await database.pendingOpsDao.getOp(operationId);
      expect(retried?.state, 'retry');
      expect(retried?.retryClassification, 'manual_retry');
      expect(retried?.lastErrorCode, null);
      expect(isDavPartiallyCompletedMove(retried!), isTrue);
      expect(retried.requestJson, contains('moveMayHaveCompleted'));

      await (database.update(database.davObjects)
            ..where((row) => row.id.equals(source.id)))
          .write(const DavObjectsCompanion(serverDeleted: Value(true)));
      var moves = 0;
      var fetches = 0;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async {
              moves += 1;
              return _success;
            },
        fetcher: (href) async {
          fetches += 1;
          throw const DavException(
            kind: DavErrorKind.invalidCalendarData,
            code: 'DavMalformedResource',
            safeMessage: 'The destination resource could not be read.',
          );
        },
      );

      await _replayer(database, objectRepository, remote).replayDueOperations();

      expect(moves, 0);
      expect(fetches, 1);
      final stillBlocked = await database.pendingOpsDao.getOp(operationId);
      expect(stillBlocked?.state, 'failed');
      expect(
        stillBlocked?.retryClassification,
        davPartialMoveRetryClassification,
      );
      expect(stillBlocked?.lastErrorCode, davPartialMoveFailureCode);
      expect(isDavPartiallyCompletedMove(stillBlocked!), isTrue);
      expect(stillBlocked.requestJson, contains('moveMayHaveCompleted'));
    },
  );

  test(
    'move marker survives a local commit failure after remote success',
    () async {
      await _seedDestination(database);
      final source = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(_eventHref))).getSingle();
      final operationId = await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: source.id,
        target: _target,
      );
      await database.customStatement('''
CREATE TRIGGER fail_confirmed_move_commit
BEFORE UPDATE OF server_deleted ON dav_objects
WHEN NEW.server_deleted = 1
BEGIN
  SELECT RAISE(ABORT, 'forced move commit failure');
END
''');
      const destinationHref = '/remote.php/dav/calendars/alex/home/event.ics';
      var remoteMoved = false;
      var moves = 0;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async {
              moves += 1;
              remoteMoved = true;
              return _success;
            },
        fetcher: (href) async {
          if (href == destinationHref && remoteMoved) {
            return _live(href, '"destination"', _event('Baseline'));
          }
          if (href == _eventHref && !remoteMoved) {
            return _live(href, 'W/"baseline"', _event('Baseline'));
          }
          return _missing(href);
        },
      );

      final firstReplay = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(firstReplay.appliedCount, 0);
      expect(firstReplay.retryCount, 1);
      expect(moves, 1);
      final awaitingLocalCommit = await database.pendingOpsDao.getOp(
        operationId,
      );
      expect(awaitingLocalCommit?.state, 'retry');
      expect(awaitingLocalCommit?.attemptCount, 1);
      expect(isDavPartiallyCompletedMove(awaitingLocalCommit!), isTrue);
      expect(awaitingLocalCommit.requestJson, contains('moveMayHaveCompleted'));
      expect(
        (await (database.select(
          database.davObjects,
        )..where((row) => row.id.equals(source.id))).getSingle()).serverDeleted,
        isFalse,
      );

      await database.customStatement('DROP TRIGGER fail_confirmed_move_commit');
      await (database.update(database.davObjects)
            ..where((row) => row.id.equals(source.id)))
          .write(const DavObjectsCompanion(serverDeleted: Value(true)));
      await queue.retryBlockedOperation(
        accountId: 'account',
        operationId: operationId,
      );
      final secondReplay = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(secondReplay.appliedCount, 1);
      expect(moves, 1);
      expect(await database.pendingOpsDao.getOp(operationId), null);
      final destination = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(destinationHref))).getSingle();
      expect(destination.collectionId, 'destination');
      expect(destination.serverDeleted, isFalse);
    },
  );

  test(
    'confirmed recurring event move restores only matching occurrence points',
    () async {
      await _seedDestination(database);
      final recurring = _recurringEvent();
      await objectRepository.commitConfirmedMutation(
        accountId: 'account',
        collectionId: 'collection',
        provider: BusyProvider.nextcloud,
        canonicalObject: _preparedMember(
          href: _eventHref,
          etag: '"recurring"',
          body: recurring,
        ),
        completedAtUtc: _now,
      );
      const unrelatedHref = '/remote.php/dav/calendars/alex/home/unrelated.ics';
      await _commitMembers(
        objectRepository,
        collectionId: 'destination',
        objects: [
          _preparedMember(
            href: unrelatedHref,
            etag: '"unrelated"',
            body: _eventWithUid('Unrelated', 'unrelated@example.test'),
          ),
        ],
      );

      final sourceObject = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(_eventHref))).getSingle();
      final sourceEvents = await (database.select(
        database.calendarEvents,
      )..where((row) => row.davObjectId.equals(sourceObject.id))).get();
      expect(sourceEvents, hasLength(2));
      final originalPoints = <String, GeographicPoint>{};
      for (var index = 0; index < sourceEvents.length; index += 1) {
        final event = sourceEvents[index];
        final point = GeographicPoint(
          latitude: 49.0 + index,
          longitude: -123.0 - index,
        );
        originalPoints[event.occurrenceKey!] = point;
        await LocationResolutionRepository(database).apply(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: 'account',
            sourceId: event.calendarSourceId,
            itemId: event.id,
          ),
          event.location!,
          LocationChange.replace(
            LocationResult(
              label: 'Occurrence $index',
              point: point,
              source: 'calendar-import',
              attribution: 'Provider $index',
            ),
          ),
        );
      }
      final unrelated = (await database.select(database.calendarEvents).get())
          .singleWhere((event) => event.icalUid == 'unrelated@example.test');
      final unrelatedPoint = GeographicPoint(latitude: 12.5, longitude: -77.25);
      await LocationResolutionRepository(database).apply(
        LocationItemIdentity(
          kind: LocationItemKind.event,
          accountId: 'account',
          sourceId: unrelated.calendarSourceId,
          itemId: unrelated.id,
        ),
        unrelated.location!,
        LocationChange.replace(
          LocationResult(
            label: 'Unrelated point',
            point: unrelatedPoint,
            source: 'unrelated-source',
          ),
        ),
      );

      await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: sourceObject.id,
        target: const IcalComponentKey(
          componentType: 'VEVENT',
          uid: 'series@example.test',
        ),
      );
      const destinationHref = '/remote.php/dav/calendars/alex/home/event.ics';
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async => _success,
        fetcher: (href) async => _live(href, '"moved"', recurring),
      );

      final result = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(result.appliedCount, 1);
      final destinationObject =
          await (database.select(database.davObjects)..where(
                (row) =>
                    row.collectionId.equals('destination') &
                    row.hrefKey.equals(destinationHref),
              ))
              .getSingle();
      final movedEvents = await (database.select(
        database.calendarEvents,
      )..where((row) => row.davObjectId.equals(destinationObject.id))).get();
      expect(movedEvents, hasLength(2));
      for (final event in movedEvents) {
        final resolved = await LocationResolutionRepository(database).load(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: 'account',
            sourceId: event.calendarSourceId,
            itemId: event.id,
          ),
          event.location!,
        );
        expect(resolved?.point, originalPoints[event.occurrenceKey]);
      }
      expect(
        (await LocationResolutionRepository(database).load(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: 'account',
            sourceId: unrelated.calendarSourceId,
            itemId: unrelated.id,
          ),
          unrelated.location!,
        ))?.point,
        unrelatedPoint,
      );
      final supplements = await database
          .select(database.locationResolutions)
          .get();
      expect(supplements, hasLength(3));
      expect(
        supplements.where((row) => row.sourceId == 'dav-calendar-collection'),
        isEmpty,
      );
    },
  );

  test(
    'confirmed event move preserves a supplement outside destination range',
    () async {
      await _seedDestination(database);
      await _commitMembers(
        objectRepository,
        collectionId: 'destination',
        objects: const [],
        projectionRangeEndUtc: DateTime.utc(2027, 1),
      );
      final futureEvent = _futureEvent();
      await objectRepository.commitConfirmedMutation(
        accountId: 'account',
        collectionId: 'collection',
        provider: BusyProvider.nextcloud,
        canonicalObject: _preparedMember(
          href: _eventHref,
          etag: '"future"',
          body: futureEvent,
        ),
        completedAtUtc: _now,
      );
      final sourceObject = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(_eventHref))).getSingle();
      final sourceEvent = await (database.select(
        database.calendarEvents,
      )..where((row) => row.davObjectId.equals(sourceObject.id))).getSingle();
      final remembered = LocationResult(
        label: 'Imported future point',
        point: GeographicPoint(latitude: 49.25, longitude: -123.1),
        source: 'calendar-import',
        attribution: 'Future calendar export',
      );
      await LocationResolutionRepository(database).apply(
        LocationItemIdentity(
          kind: LocationItemKind.event,
          accountId: 'account',
          sourceId: sourceEvent.calendarSourceId,
          itemId: sourceEvent.id,
        ),
        sourceEvent.location!,
        LocationChange.replace(remembered),
      );
      await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: sourceObject.id,
        target: const IcalComponentKey(
          componentType: 'VEVENT',
          uid: 'future-event@example.test',
        ),
      );
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async => _success,
        fetcher: (href) async => _live(href, '"future-moved"', futureEvent),
      );

      final replay = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(replay.appliedCount, 1);
      final destinationObject =
          await (database.select(database.davObjects)..where(
                (row) =>
                    row.collectionId.equals('destination') &
                    row.serverDeleted.equals(false),
              ))
              .getSingle();
      Future<void> expectRemembered() async {
        final event =
            await (database.select(
                  database.calendarEvents,
                )..where((row) => row.davObjectId.equals(destinationObject.id)))
                .getSingle();
        expect(event.startDateTime, startsWith('2028-06-15'));
        expect(
          await LocationResolutionRepository(database).load(
            LocationItemIdentity(
              kind: LocationItemKind.event,
              accountId: 'account',
              sourceId: event.calendarSourceId,
              itemId: event.id,
            ),
            event.location!,
          ),
          remembered,
        );
      }

      await expectRemembered();
      await objectRepository.reprojectCollectionFromStored(
        accountId: 'account',
        collectionId: 'destination',
        provider: BusyProvider.nextcloud,
        projectionRangeStartUtc: DateTime.utc(2025),
        projectionRangeEndUtc: DateTime.utc(2027, 1),
        completedAtUtc: _now,
      );
      await expectRemembered();
      final resolutions = await database
          .select(database.locationResolutions)
          .get();
      expect(resolutions, hasLength(1));
      expect(resolutions.single.sourceId, 'dav-calendar-destination');
      expect(resolutions.single.source, remembered.source);
      expect(resolutions.single.attribution, remembered.attribution);
    },
  );

  test(
    'confirmed recurring move retains supplements across projection ranges',
    () async {
      await _seedDestination(database);
      await _commitMembers(
        objectRepository,
        collectionId: 'destination',
        objects: const [],
        projectionRangeEndUtc: DateTime.utc(2027, 1),
      );
      final recurring = _recurringEventAcrossRanges();
      await objectRepository.commitConfirmedMutation(
        accountId: 'account',
        collectionId: 'collection',
        provider: BusyProvider.nextcloud,
        canonicalObject: _preparedMember(
          href: _eventHref,
          etag: '"range-series"',
          body: recurring,
        ),
        completedAtUtc: _now,
      );
      final sourceObject = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(_eventHref))).getSingle();
      final sourceEvents = await (database.select(
        database.calendarEvents,
      )..where((row) => row.davObjectId.equals(sourceObject.id))).get();
      expect(sourceEvents, hasLength(3));
      final remembered = <String, LocationResult>{};
      for (var index = 0; index < sourceEvents.length; index += 1) {
        final event = sourceEvents[index];
        final result = LocationResult(
          label: 'Annual occurrence $index',
          point: GeographicPoint(
            latitude: 48.0 + index,
            longitude: -122.0 - index,
          ),
          source: 'annual-import-$index',
          attribution: 'Annual source $index',
        );
        remembered[event.occurrenceKey!] = result;
        await LocationResolutionRepository(database).apply(
          LocationItemIdentity(
            kind: LocationItemKind.event,
            accountId: 'account',
            sourceId: event.calendarSourceId,
            itemId: event.id,
          ),
          event.location!,
          LocationChange.replace(result),
        );
      }
      await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: sourceObject.id,
        target: const IcalComponentKey(
          componentType: 'VEVENT',
          uid: 'annual-range@example.test',
        ),
      );
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async => _success,
        fetcher: (href) async => _live(href, '"range-moved"', recurring),
      );

      final replay = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(replay.appliedCount, 1);
      final destinationObject =
          await (database.select(database.davObjects)..where(
                (row) =>
                    row.collectionId.equals('destination') &
                    row.serverDeleted.equals(false),
              ))
              .getSingle();
      Future<void> expectRememberedOccurrences() async {
        final events = await (database.select(
          database.calendarEvents,
        )..where((row) => row.davObjectId.equals(destinationObject.id))).get();
        expect(events, hasLength(3));
        for (final event in events) {
          expect(
            await LocationResolutionRepository(database).load(
              LocationItemIdentity(
                kind: LocationItemKind.event,
                accountId: 'account',
                sourceId: event.calendarSourceId,
                itemId: event.id,
              ),
              event.location!,
            ),
            remembered[event.occurrenceKey],
          );
        }
      }

      await expectRememberedOccurrences();
      await objectRepository.reprojectCollectionFromStored(
        accountId: 'account',
        collectionId: 'destination',
        provider: BusyProvider.nextcloud,
        projectionRangeStartUtc: DateTime.utc(2025),
        projectionRangeEndUtc: DateTime.utc(2027, 1),
        completedAtUtc: _now,
      );
      await expectRememberedOccurrences();
      final resolutions = await database
          .select(database.locationResolutions)
          .get();
      expect(resolutions, hasLength(3));
      expect(
        resolutions.map((row) => row.source).toSet(),
        remembered.values.map((value) => value.source).toSet(),
      );
      expect(
        resolutions.map((row) => row.attribution).toSet(),
        remembered.values.map((value) => value.attribution).toSet(),
      );
    },
  );

  test(
    'confirmed move restoration failure rolls back source replacement',
    () async {
      await _seedDestination(database);
      final sourceObject = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(_eventHref))).getSingle();
      final sourceEvent = await database
          .select(database.calendarEvents)
          .getSingle();
      final remembered = LocationResult(
        label: 'Rollback room',
        point: GeographicPoint(latitude: 48.4284, longitude: -123.3656),
        source: 'rollback-import',
        attribution: 'Kept provenance',
      );
      final sourceIdentity = LocationItemIdentity(
        kind: LocationItemKind.event,
        accountId: 'account',
        sourceId: sourceEvent.calendarSourceId,
        itemId: sourceEvent.id,
      );
      await LocationResolutionRepository(database).apply(
        sourceIdentity,
        sourceEvent.location!,
        LocationChange.replace(remembered),
      );
      await queue.enqueueMove(
        accountId: 'account',
        sourceCollectionId: 'collection',
        destinationCollectionId: 'destination',
        objectId: sourceObject.id,
        target: _target,
      );
      await database.customStatement('''
      CREATE TRIGGER fail_confirmed_move_resolution
      BEFORE INSERT ON location_resolutions
      WHEN NEW.source_id = 'dav-calendar-destination'
      BEGIN
        SELECT RAISE(ABORT, 'forced destination restoration failure');
      END
    ''');
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async => _success,
        fetcher: (href) async => _live(href, '"moved"', _event('Baseline')),
      );

      final result = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(result.appliedCount, 0);
      expect(result.retryCount, 1);
      expect(
        (await (database.select(
              database.davObjects,
            )..where((row) => row.id.equals(sourceObject.id))).getSingle())
            .serverDeleted,
        isFalse,
      );
      expect(
        await (database.select(
          database.davObjects,
        )..where((row) => row.collectionId.equals('destination'))).get(),
        isEmpty,
      );
      expect(
        await database.select(database.calendarEvents).get(),
        hasLength(1),
      );
      expect(
        await LocationResolutionRepository(
          database,
        ).load(sourceIdentity, sourceEvent.location!),
        remembered,
      );
    },
  );

  test(
    'recurring task move projects each component point before and after replay',
    () async {
      await _seedDestination(database);
      const taskHref = '${_collectionHref}recurring-task.ics';
      final recurringTask = _recurringTask();
      await _commitMembers(
        objectRepository,
        collectionId: 'collection',
        objects: [
          _preparedMember(
            href: taskHref,
            etag: '"task-baseline"',
            body: recurringTask,
          ),
        ],
      );
      final sourceObject = await (database.select(
        database.davObjects,
      )..where((row) => row.hrefKey.equals(taskHref))).getSingle();
      final sourceTasks = await (database.select(
        database.tasks,
      )..where((row) => row.davObjectId.equals(sourceObject.id))).get();
      final master = sourceTasks.singleWhere(
        (task) => task.recurrenceIdKey == null,
      );
      final masterPoint = GeographicPoint(
        latitude: 49.2827,
        longitude: -123.1207,
      );
      final exceptionPoint = GeographicPoint(
        latitude: 48.4284,
        longitude: -123.3656,
      );
      await LocationResolutionRepository(database).apply(
        LocationItemIdentity(
          kind: LocationItemKind.task,
          accountId: 'account',
          sourceId: master.taskListId,
          itemId: master.id,
        ),
        master.taskLocation!,
        LocationChange.replace(
          LocationResult(
            label: 'Imported master point',
            point: masterPoint,
            source: 'calendar-import',
            attribution: 'Original feed',
          ),
        ),
      );

      final beforeOpening = await _locationState(database);
      final destination =
          await LocationDestinationResolver(
            LocationResolutionRepository(database),
          ).resolveSaved(
            location: master.taskLocation!,
            identity: LocationItemIdentity(
              kind: LocationItemKind.task,
              accountId: 'account',
              sourceId: master.taskListId,
              itemId: master.id,
            ),
          );
      final launched = <Uri>[];
      final openResult = await ExternalLocationLauncher(
        platform: () => ExternalLocationPlatform.windows,
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          launched.add(uri);
          return true;
        },
      ).open(destination);
      expect(openResult, ExternalLocationLaunchResult.opened);
      expect(
        launched.single.queryParameters['query'],
        masterPoint.directionsValue,
      );
      expect(await _locationState(database), beforeOpening);

      final tasksRepository = TasksRepository(
        database: database,
        accountId: 'account',
        nowUtc: () => _now,
      );
      await tasksRepository.moveTask(
        TaskMoveInput(
          sourceTaskListId: 'dav-task-list-collection',
          taskId: master.id,
          destinationTaskListId: 'dav-task-list-destination',
        ),
      );

      Future<void> expectProjectedPoints(String objectId) async {
        final tasks = await (database.select(
          database.tasks,
        )..where((row) => row.davObjectId.equals(objectId))).get();
        expect(tasks, hasLength(4));
        expect(
          tasks.every((task) => task.taskListId == 'dav-task-list-destination'),
          isTrue,
        );
        final movedMaster = tasks.singleWhere(
          (task) => task.recurrenceIdKey == null,
        );
        expect(movedMaster.locationLatitude, masterPoint.latitude);
        expect(movedMaster.locationLongitude, masterPoint.longitude);
        final differentPoint = tasks.singleWhere(
          (task) => task.title == 'Exception with point',
        );
        expect(differentPoint.locationLatitude, exceptionPoint.latitude);
        expect(differentPoint.locationLongitude, exceptionPoint.longitude);
        final differentLocation = tasks.singleWhere(
          (task) => task.title == 'Exception without point',
        );
        expect(differentLocation.taskLocation, 'Remote office');
        expect(differentLocation.locationLatitude, isNull);
        expect(differentLocation.locationLongitude, isNull);
        final inherited = tasks.singleWhere(
          (task) => task.title == 'Inherited exception',
        );
        expect(inherited.taskLocation, 'Head office');
        expect(inherited.locationLatitude, masterPoint.latitude);
        expect(inherited.locationLongitude, masterPoint.longitude);
      }

      await expectProjectedPoints(sourceObject.id);
      final pending = await database.select(database.pendingOps).getSingle();
      expect(pending.operationType, 'dav.move');
      final optimisticRaw = DavMutationPatch.fromJsonString(
        pending.mutationPatchJson!,
      ).applyTo(pending.baselineRawIcs!, nowUtc: _now);
      final optimistic = IcalSemanticDocument.parse(optimisticRaw);
      expect(
        optimistic.components
            .singleWhere((component) => component.recurrenceIdKey == null)
            .locationPoint,
        masterPoint,
      );
      expect(
        optimistic.components
            .singleWhere(
              (component) => component.summary == 'Exception with point',
            )
            .locationPoint,
        exceptionPoint,
      );
      expect(
        optimistic.components
            .singleWhere(
              (component) => component.summary == 'Exception without point',
            )
            .locationPoint,
        isNull,
      );

      var serverRaw = recurringTask;
      final remote = _FakeMutationRemote(
        move:
            ({
              required sourceUri,
              required destinationUri,
              required ifMatch,
            }) async => _success,
        put: ({required rawIcs, required ifMatch, required ifNoneMatch}) async {
          serverRaw = rawIcs;
          return _success;
        },
        fetcher: (href) async => _live(href, '"task-moved"', serverRaw),
      );

      final replay = await _replayer(
        database,
        objectRepository,
        remote,
      ).replayDueOperations();

      expect(replay.appliedCount, 1);
      final destinationObject =
          await (database.select(database.davObjects)..where(
                (row) =>
                    row.collectionId.equals('destination') &
                    row.hrefKey.equals(
                      '/remote.php/dav/calendars/alex/home/recurring-task.ics',
                    ),
              ))
              .getSingle();
      await expectProjectedPoints(destinationObject.id);
      final supplements = await database
          .select(database.locationResolutions)
          .get();
      expect(supplements, hasLength(1));
      expect(supplements.single.sourceId, 'dav-task-list-destination');
      expect(supplements.single.source, 'calendar-import');
      expect(supplements.single.attribution, 'Original feed');

      await objectRepository.reprojectCollectionFromStored(
        accountId: 'account',
        collectionId: 'destination',
        provider: BusyProvider.nextcloud,
        projectionRangeStartUtc: DateTime.utc(2025),
        projectionRangeEndUtc: DateTime.utc(2029),
        completedAtUtc: _now,
      );
      await expectProjectedPoints(destinationObject.id);
      expect(
        await database.select(database.locationResolutions).get(),
        hasLength(1),
      );
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

final class _RecordingNotificationBackend
    implements DesktopNotificationBackend {
  final requests = <BusyMaxNotificationRequest>[];

  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    requests.add(request);
  }

  @override
  Future<void> cancel(String stableId) async {}

  @override
  Future<void> close() async {}
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

DavFetchedMember _missing(String href) => DavFetchedMember.missing(
  hrefKey: href,
  requestUri: Uri.parse('https://cloud.example.test$href'),
);

DavPreparedObject _preparedMember({
  required String href,
  required String etag,
  required String body,
}) => DavPreparedObject.parse(
  hrefKey: href,
  requestUri: Uri.parse('https://cloud.example.test$href'),
  etag: etag,
  contentType: 'text/calendar',
  rawIcsBody: body,
);

Future<void> _commitMembers(
  DavObjectRepository repository, {
  required String collectionId,
  required List<DavPreparedObject> objects,
  DateTime? projectionRangeStartUtc,
  DateTime? projectionRangeEndUtc,
}) {
  return repository.commit(
    DavCollectionCommit(
      accountId: 'account',
      collectionId: collectionId,
      provider: BusyProvider.nextcloud,
      objects: objects,
      deletedHrefKeys: const {},
      completeMembership: false,
      membershipHrefKeys: const {},
      finalCursorKind: 'dav_sync_token',
      finalCursorValue: 'token-1',
      baselineGeneration: 1,
      completedAtUtc: _now,
      projectionRangeStartUtc: projectionRangeStartUtc ?? DateTime.utc(2025),
      projectionRangeEndUtc: projectionRangeEndUtc ?? DateTime.utc(2029),
    ),
  );
}

Future<List<Map<String, Object?>>> _locationState(AppDatabase database) async {
  final rows = <Map<String, Object?>>[];
  for (final table in const ['tasks', 'location_resolutions', 'pending_ops']) {
    final values = await database
        .customSelect('SELECT * FROM $table ORDER BY 1')
        .get();
    rows.addAll(values.map((row) => {'table': table, ...row.data}));
  }
  return rows;
}

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

String _futureEvent() => '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:future-event@example.test\r
DTSTAMP:20260808T120000Z\r
DTSTART:20280615T090000Z\r
DTEND:20280615T100000Z\r
SUMMARY:Future event\r
LOCATION:Future office\r
END:VEVENT\r
END:VCALENDAR\r
''';

String _recurringEventAcrossRanges() => '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:annual-range@example.test\r
DTSTAMP:20260808T120000Z\r
DTSTART:20260615T090000Z\r
DTEND:20260615T100000Z\r
RRULE:FREQ=YEARLY;COUNT=3\r
SUMMARY:Annual range event\r
LOCATION:Annual office\r
END:VEVENT\r
END:VCALENDAR\r
''';

String _recurringEvent() => '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VEVENT\r
UID:series@example.test\r
DTSTAMP:20260808T120000Z\r
DTSTART:20260808T090000Z\r
DTEND:20260808T100000Z\r
RRULE:FREQ=DAILY;COUNT=2\r
SUMMARY:Recurring event\r
LOCATION:Baseline room\r
END:VEVENT\r
END:VCALENDAR\r
''';

String _recurringTask() => '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VTODO\r
UID:recurring-task@example.test\r
DTSTAMP:20260808T120000Z\r
DTSTART:20260808T090000Z\r
DUE:20260808T100000Z\r
RRULE:FREQ=DAILY;COUNT=4\r
SUMMARY:Master task\r
LOCATION:Head office\r
END:VTODO\r
BEGIN:VTODO\r
UID:recurring-task@example.test\r
RECURRENCE-ID:20260809T090000Z\r
DTSTAMP:20260808T120000Z\r
DTSTART:20260809T090000Z\r
DUE:20260809T100000Z\r
SUMMARY:Exception with point\r
LOCATION:Branch office\r
GEO:48.4284;-123.3656\r
END:VTODO\r
BEGIN:VTODO\r
UID:recurring-task@example.test\r
RECURRENCE-ID:20260810T090000Z\r
DTSTAMP:20260808T120000Z\r
DTSTART:20260810T090000Z\r
DUE:20260810T100000Z\r
SUMMARY:Exception without point\r
LOCATION:Remote office\r
END:VTODO\r
BEGIN:VTODO\r
UID:recurring-task@example.test\r
RECURRENCE-ID:20260811T090000Z\r
DTSTAMP:20260808T120000Z\r
DTSTART:20260811T090000Z\r
DUE:20260811T100000Z\r
SUMMARY:Inherited exception\r
END:VTODO\r
END:VCALENDAR\r
''';

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

String _taskWithParent(String uid, String summary) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax Test//EN\r
BEGIN:VTODO\r
UID:$uid\r
DTSTAMP:20260808T120000Z\r
DUE:20260809T120000Z\r
SUMMARY:$summary\r
RELATED-TO:parent@example.test\r
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
