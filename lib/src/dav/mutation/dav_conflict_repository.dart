import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../ical/ical_document.dart';
import '../ical/ical_semantics.dart';
import '../storage/dav_object_repository.dart';
import 'dav_conditional_mutation_service.dart';
import 'dav_mutation_patch.dart';
import 'dav_pending_operations.dart';

enum DavConflictResolution { keepServer, reapplyLocal, duplicateLocal }

final class DavConflictEntity {
  const DavConflictEntity({
    required this.id,
    required this.accountId,
    required this.provider,
    required this.accountLabel,
    required this.collectionName,
    required this.itemTitle,
    required this.componentType,
    required this.remoteChangedAtUtc,
    required this.localEditSummary,
    required this.conflictCode,
    required this.canKeepServer,
    required this.canReapplyLocal,
    required this.canDuplicate,
  });

  final String id;
  final String accountId;
  final BusyProvider provider;
  final String accountLabel;
  final String collectionName;
  final String itemTitle;
  final String componentType;
  final DateTime? remoteChangedAtUtc;
  final String localEditSummary;
  final String conflictCode;
  final bool canKeepServer;
  final bool canReapplyLocal;
  final bool canDuplicate;
}

final class DavConflictRepository {
  DavConflictRepository({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Stream<List<DavConflictEntity>> watchUnresolved() {
    final query =
        _database.select(_database.davConflictSnapshots).join([
            innerJoin(
              _database.accounts,
              _database.accounts.id.equalsExp(
                _database.davConflictSnapshots.accountId,
              ),
            ),
            leftOuterJoin(
              _database.davCollections,
              _database.davCollections.id.equalsExp(
                _database.davConflictSnapshots.davCollectionId,
              ),
            ),
            leftOuterJoin(
              _database.pendingOps,
              _database.pendingOps.conflictSnapshotId.equalsExp(
                _database.davConflictSnapshots.id,
              ),
            ),
          ])
          ..where(_database.davConflictSnapshots.resolvedAtUtc.isNull())
          ..orderBy([
            OrderingTerm.desc(_database.davConflictSnapshots.createdAtUtc),
          ]);
    return query.watch().map((rows) {
      return [
        for (final row in rows)
          _entity(
            row.readTable(_database.davConflictSnapshots),
            row.readTable(_database.accounts),
            row.readTableOrNull(_database.davCollections),
            row.readTableOrNull(_database.pendingOps),
          ),
      ];
    });
  }
}

final class DavConflictResolutionService {
  DavConflictResolutionService({
    required AppDatabase database,
    DavObjectRepository? objectRepository,
    DavPendingOperationQueue? pendingQueue,
    Future<void> Function(String accountId, Set<String> objectIds)?
    rebuildNotifications,
    String Function()? idFactory,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _objectRepository =
           objectRepository ?? DavObjectRepository(database: database),
       _pendingQueue =
           pendingQueue ?? DavPendingOperationQueue(database: database),
       _rebuildNotifications = rebuildNotifications,
       _idFactory = idFactory ?? const Uuid().v4,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final DavObjectRepository _objectRepository;
  final DavPendingOperationQueue _pendingQueue;
  final Future<void> Function(String, Set<String>)? _rebuildNotifications;
  final String Function() _idFactory;
  final DateTime Function() _nowUtc;

  Future<void> resolve(String snapshotId, DavConflictResolution resolution) {
    return switch (resolution) {
      DavConflictResolution.keepServer => _keepServer(snapshotId),
      DavConflictResolution.reapplyLocal => _reapplyLocal(snapshotId),
      DavConflictResolution.duplicateLocal => _duplicateLocal(snapshotId),
    };
  }

  Future<void> _keepServer(String snapshotId) async {
    final context = await _context(snapshotId);
    final moveOutcome = _moveConflictOutcome(
      context.operation,
      context.snapshot.conflictCode,
    );
    switch (moveOutcome) {
      case _MoveConflictOutcome.notMove:
        await _adoptRemote(context, DavConflictResolution.keepServer);
      case _MoveConflictOutcome.sourceRetained:
        await _resolveChangedSourceMove(
          context,
          DavConflictResolution.keepServer,
        );
      case _MoveConflictOutcome.destinationCollision:
        await _resolveMoveDestinationCollision(
          context,
          DavConflictResolution.keepServer,
        );
      case _MoveConflictOutcome.destinationChanged:
        await _resolveCompletedMove(context, DavConflictResolution.keepServer);
      case _MoveConflictOutcome.sourceRemoved:
        await _resolveRemovedMove(context, DavConflictResolution.keepServer);
      case _MoveConflictOutcome.unavailable:
        throw _resolutionUnavailable();
    }
  }

  Future<void> _resolveMoveDestinationCollision(
    _ResolutionContext context,
    DavConflictResolution resolution,
  ) async {
    if (!_isMoveDestinationCollision(context)) {
      throw _resolutionUnavailable();
    }
    final provider = BusyProviderCodec.requireStorageValue(
      context.account.provider,
    );
    final now = _nowUtc().toUtc();
    await _database.transaction(() async {
      final operation = await _currentConflictOperation(context);
      final move = await _validatedMoveContext(
        context,
        operation,
        requireRemote: true,
      );
      final dependents = await _unattemptedMoveDependents(operation);
      final restoredSources = <DavObject>[move.source];
      for (final dependent in dependents) {
        restoredSources.add(await _validatedMoveSource(dependent));
      }
      await _objectRepository.commitConfirmedMutation(
        accountId: context.snapshot.accountId,
        collectionId: move.destination.id,
        provider: provider,
        canonicalObject: move.canonicalDestination,
        completedAtUtc: now,
      );
      await (_database.delete(_database.pendingOps)..where(
            (row) => row.id.isIn([
              operation.id,
              for (final dependent in dependents) dependent.id,
            ]),
          ))
          .go();
      for (final restoredSource in {
        for (final object in restoredSources) object.id: object,
      }.values) {
        await _objectRepository.restoreServerProjectionAfterDiscard(
          accountId: context.snapshot.accountId,
          objectId: restoredSource.id,
          restoredAtUtc: now,
        );
      }
      await _markSnapshotResolved(
        context.snapshot.id,
        resolution,
        now.toIso8601String(),
      );
    });
  }

  Future<void> _resolveChangedSourceMove(
    _ResolutionContext context,
    DavConflictResolution resolution,
  ) async {
    final provider = BusyProviderCodec.requireStorageValue(
      context.account.provider,
    );
    final now = _nowUtc().toUtc();
    await _database.transaction(() async {
      final operation = await _currentConflictOperation(context);
      final canonical = await _validatedCanonicalSource(context, operation);
      final dependents = await _unattemptedMoveDependents(operation);
      final restoredSources = <DavObject>[];
      for (final dependent in dependents) {
        restoredSources.add(await _validatedMoveSource(dependent));
      }
      await (_database.delete(_database.pendingOps)..where(
            (row) => row.id.isIn([
              operation.id,
              for (final dependent in dependents) dependent.id,
            ]),
          ))
          .go();
      await _objectRepository.commitConfirmedMutation(
        accountId: context.snapshot.accountId,
        collectionId: context.collection.id,
        provider: provider,
        canonicalObject: canonical,
        completedAtUtc: now,
      );
      for (final restoredSource in {
        for (final object in restoredSources) object.id: object,
      }.values) {
        await _objectRepository.restoreServerProjectionAfterDiscard(
          accountId: context.snapshot.accountId,
          objectId: restoredSource.id,
          restoredAtUtc: now,
        );
      }
      await _markSnapshotResolved(
        context.snapshot.id,
        resolution,
        now.toIso8601String(),
      );
    });
  }

  Future<void> _resolveCompletedMove(
    _ResolutionContext context,
    DavConflictResolution resolution,
  ) async {
    final provider = BusyProviderCodec.requireStorageValue(
      context.account.provider,
    );
    final now = _nowUtc().toUtc();
    await _database.transaction(() async {
      final operation = await _currentConflictOperation(context);
      final move = await _validatedMoveContext(
        context,
        operation,
        requireRemote: true,
      );
      final canonical = move.canonicalDestination!;
      final sameSourceIdentity = _hasObjectIdentity(canonical, move.source);
      await _database.pendingOpsDao.deleteOp(operation.id);
      if (sameSourceIdentity) {
        await _objectRepository.commitConfirmedMove(
          accountId: context.snapshot.accountId,
          sourceCollectionId: context.collection.id,
          destinationCollectionId: move.destination.id,
          provider: provider,
          sourceHrefKey: move.source.hrefKey,
          canonicalDestinationObject: canonical,
          completedAtUtc: now,
        );
      } else {
        await _objectRepository.commitConfirmedMutation(
          accountId: context.snapshot.accountId,
          collectionId: move.destination.id,
          provider: provider,
          canonicalObject: canonical,
          completedAtUtc: now,
        );
        await _objectRepository.commitConfirmedMutation(
          accountId: context.snapshot.accountId,
          collectionId: context.collection.id,
          provider: provider,
          deletedHrefKey: move.source.hrefKey,
          completedAtUtc: now,
        );
      }
      await _markSnapshotResolved(
        context.snapshot.id,
        resolution,
        now.toIso8601String(),
      );
    });
  }

  Future<void> _resolveRemovedMove(
    _ResolutionContext context,
    DavConflictResolution resolution,
  ) async {
    if (context.snapshot.remoteEtag != null ||
        context.snapshot.remoteRawIcs.isNotEmpty) {
      throw _resolutionUnavailable();
    }
    final provider = BusyProviderCodec.requireStorageValue(
      context.account.provider,
    );
    final now = _nowUtc().toUtc();
    await _database.transaction(() async {
      final operation = await _currentConflictOperation(context);
      final move = await _validatedMoveContext(
        context,
        operation,
        requireRemote: false,
      );
      await _database.pendingOpsDao.deleteOp(operation.id);
      await _objectRepository.commitConfirmedMutation(
        accountId: context.snapshot.accountId,
        collectionId: context.collection.id,
        provider: provider,
        deletedHrefKey: move.source.hrefKey,
        completedAtUtc: now,
      );
      await _objectRepository.commitConfirmedMutation(
        accountId: context.snapshot.accountId,
        collectionId: move.destination.id,
        provider: provider,
        deletedHrefKey: move.destinationUri.path,
        completedAtUtc: now,
      );
      await _markSnapshotResolved(
        context.snapshot.id,
        resolution,
        now.toIso8601String(),
      );
    });
  }

  Future<void> _adoptRemote(
    _ResolutionContext context,
    DavConflictResolution resolution,
  ) async {
    final snapshot = context.snapshot;
    final object = context.object;
    if (object == null ||
        object.accountId != snapshot.accountId ||
        object.collectionId != context.collection.id ||
        object.hrefKey != context.operation.davMemberHref ||
        context.collection.accountId != snapshot.accountId ||
        context.collection.hrefKey != context.operation.davCollectionHref ||
        snapshot.remoteEtag == null ||
        snapshot.remoteRawIcs.isEmpty) {
      throw _resolutionUnavailable();
    }
    final provider = BusyProviderCodec.requireStorageValue(
      context.account.provider,
    );
    final canonical = DavPreparedObject.parse(
      hrefKey: object.hrefKey,
      requestUri: Uri.parse(object.requestUri),
      etag: snapshot.remoteEtag,
      contentType: object.contentType,
      rawIcsBody: snapshot.remoteRawIcs,
      maximumResourceBytes:
          context.collection.maximumResourceSize ?? 16 * 1024 * 1024,
    );
    if (canonical.semantic.primaryUid != object.primaryUid ||
        canonical.semantic.components.any(
          (component) =>
              component.uid != object.primaryUid ||
              component.componentType != object.dominantComponentType,
        )) {
      throw _resolutionUnavailable();
    }
    final changedObjectIds = await _objectRepository.commitConfirmedMutation(
      accountId: snapshot.accountId,
      collectionId: context.collection.id,
      provider: provider,
      canonicalObject: canonical,
      completedAtUtc: _nowUtc(),
    );
    await _finish(context, resolution);
    if (changedObjectIds.isNotEmpty) {
      await _rebuildNotifications?.call(snapshot.accountId, changedObjectIds);
    }
  }

  Future<void> _reapplyLocal(String snapshotId) async {
    final context = await _context(snapshotId);
    final snapshot = context.snapshot;
    final operation = context.operation;
    if (snapshot.remoteEtag == null ||
        snapshot.remoteRawIcs.isEmpty ||
        operation.mutationPatchJson == null) {
      throw _resolutionUnavailable();
    }
    final patch = DavMutationPatch.fromJsonString(operation.mutationPatchJson!);
    patch.applyTo(snapshot.remoteRawIcs, nowUtc: _nowUtc());
    final now = _nowUtc().toIso8601String();
    await _database.transaction(() async {
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(operation.id))).write(
        PendingOpsCompanion(
          baselineEtag: Value(snapshot.remoteEtag),
          baselineRawIcs: Value(snapshot.remoteRawIcs),
          state: const Value('pending'),
          conflictState: const Value(null),
          conflictSnapshotId: const Value(null),
          retryClassification: const Value('conditional_update'),
          attemptCount: const Value(0),
          nextAttemptAtUtc: const Value(null),
          lastErrorCode: const Value(null),
          lastErrorMessage: const Value(null),
          updatedAtUtc: Value(now),
        ),
      );
      await _markSnapshotResolved(
        snapshot.id,
        DavConflictResolution.reapplyLocal,
        now,
      );
    });
  }

  Future<void> _duplicateLocal(String snapshotId) async {
    final context = await _context(snapshotId);
    final moveOutcome = _moveConflictOutcome(
      context.operation,
      context.snapshot.conflictCode,
    );
    if (moveOutcome == _MoveConflictOutcome.unavailable) {
      throw _resolutionUnavailable();
    }
    final local = context.snapshot.localCandidateRawIcs;
    if (local.isEmpty) throw _resolutionUnavailable();
    final duplicated = _duplicateResource(
      local,
      uid: '${_idFactory()}@busymax.local',
      nowUtc: _nowUtc(),
    );
    final semantic = IcalSemanticDocument.parse(duplicated);
    final componentType = semantic.components.first.componentType;
    final uid = semantic.primaryUid!;
    await _database.transaction(() async {
      await _pendingQueue.enqueueCreate(
        accountId: context.snapshot.accountId,
        collectionId: context.collection.id,
        object: DavNewObject(
          uid: uid,
          initialMemberName: '${_idFactory()}.ics',
          rawIcs: duplicated,
          componentType: componentType,
        ),
      );
      switch (moveOutcome) {
        case _MoveConflictOutcome.destinationCollision:
          await _resolveMoveDestinationCollision(
            context,
            DavConflictResolution.duplicateLocal,
          );
        case _MoveConflictOutcome.destinationChanged:
          await _resolveCompletedMove(
            context,
            DavConflictResolution.duplicateLocal,
          );
        case _MoveConflictOutcome.sourceRemoved:
          await _resolveRemovedMove(
            context,
            DavConflictResolution.duplicateLocal,
          );
        case _MoveConflictOutcome.sourceRetained:
          await _resolveChangedSourceMove(
            context,
            DavConflictResolution.duplicateLocal,
          );
        case _MoveConflictOutcome.notMove:
          if (context.snapshot.remoteEtag != null &&
              context.snapshot.remoteRawIcs.isNotEmpty &&
              context.object != null) {
            await _adoptRemote(context, DavConflictResolution.duplicateLocal);
          } else {
            await _finish(context, DavConflictResolution.duplicateLocal);
          }
        case _MoveConflictOutcome.unavailable:
          throw _resolutionUnavailable();
      }
    });
  }

  Future<DavPreparedObject> _validatedCanonicalSource(
    _ResolutionContext context,
    PendingOp operation,
  ) async {
    if (_moveConflictOutcome(operation, context.snapshot.conflictCode) !=
        _MoveConflictOutcome.sourceRetained) {
      throw _resolutionUnavailable();
    }
    final source = await _validatedMoveSource(operation);
    if (context.object?.id != source.id ||
        context.snapshot.remoteEtag == null ||
        context.snapshot.remoteRawIcs.isEmpty) {
      throw _resolutionUnavailable();
    }
    final canonical = DavPreparedObject.parse(
      hrefKey: source.hrefKey,
      requestUri: Uri.parse(source.requestUri),
      etag: context.snapshot.remoteEtag,
      contentType: source.contentType,
      rawIcsBody: context.snapshot.remoteRawIcs,
      maximumResourceBytes:
          context.collection.maximumResourceSize ?? 16 * 1024 * 1024,
    );
    if (!_hasObjectIdentity(canonical, source)) {
      throw _resolutionUnavailable();
    }
    return canonical;
  }

  Future<_ValidatedMoveContext> _validatedMoveContext(
    _ResolutionContext context,
    PendingOp operation, {
    required bool requireRemote,
  }) async {
    if (context.account.id != context.snapshot.accountId ||
        operation.accountId != context.snapshot.accountId ||
        context.collection.accountId != context.snapshot.accountId ||
        context.collection.hrefKey != operation.davCollectionHref) {
      throw _resolutionUnavailable();
    }
    final outcome = _moveConflictOutcome(
      operation,
      context.snapshot.conflictCode,
    );
    final allowServerDeleted =
        outcome == _MoveConflictOutcome.destinationChanged ||
        outcome == _MoveConflictOutcome.sourceRemoved;
    final source = await _validatedMoveSource(
      operation,
      allowServerDeleted: allowServerDeleted,
    );
    if (context.object?.id != source.id ||
        context.collection.id != source.collectionId) {
      throw _resolutionUnavailable();
    }
    final destinationId = operation.destinationCollectionId;
    final destination = destinationId == null
        ? null
        : await (_database.select(
            _database.davCollections,
          )..where((row) => row.id.equals(destinationId))).getSingleOrNull();
    if (destination == null ||
        destination.accountId != context.snapshot.accountId ||
        destination.deleted ||
        destination.serverMissing ||
        destination.hrefKey != operation.destinationCollectionHref) {
      throw _resolutionUnavailable();
    }
    final destinationUri = _validatedMoveDestinationUri(operation, destination);
    DavPreparedObject? canonicalDestination;
    if (requireRemote) {
      if (context.snapshot.remoteEtag == null ||
          context.snapshot.remoteRawIcs.isEmpty) {
        throw _resolutionUnavailable();
      }
      canonicalDestination = DavPreparedObject.parse(
        hrefKey: destinationUri.path,
        requestUri: destinationUri,
        etag: context.snapshot.remoteEtag,
        contentType: source.contentType,
        rawIcsBody: context.snapshot.remoteRawIcs,
        maximumResourceBytes:
            destination.maximumResourceSize ?? 16 * 1024 * 1024,
      );
    }
    return _ValidatedMoveContext(
      source: source,
      destination: destination,
      destinationUri: destinationUri,
      canonicalDestination: canonicalDestination,
    );
  }

  Future<PendingOp> _currentConflictOperation(
    _ResolutionContext context,
  ) async {
    final current = await _database.pendingOpsDao.getOp(context.operation.id);
    if (current == null ||
        current.accountId != context.snapshot.accountId ||
        current.state != 'conflict' ||
        current.conflictState != 'unresolved' ||
        current.conflictSnapshotId != context.snapshot.id ||
        current.updatedAtUtc != context.operation.updatedAtUtc ||
        current.requestJson != context.operation.requestJson ||
        current.davCollectionId != context.operation.davCollectionId ||
        current.davObjectId != context.operation.davObjectId ||
        current.davMemberHref != context.operation.davMemberHref ||
        current.destinationCollectionId !=
            context.operation.destinationCollectionId ||
        current.destinationMemberHref !=
            context.operation.destinationMemberHref) {
      throw _resolutionUnavailable();
    }
    return current;
  }

  Future<DavObject> _validatedMoveSource(
    PendingOp operation, {
    bool allowServerDeleted = false,
  }) async {
    final sourceCollectionId = operation.davCollectionId;
    final sourceObjectId = operation.davObjectId;
    final destinationCollectionId = operation.destinationCollectionId;
    if (operation.operationType != 'dav.move' ||
        operation.accountId.isEmpty ||
        sourceCollectionId == null ||
        sourceObjectId == null ||
        destinationCollectionId == null ||
        sourceCollectionId == destinationCollectionId ||
        operation.davCollectionHref == null ||
        operation.davMemberHref == null ||
        operation.destinationCollectionHref == null ||
        operation.destinationMemberHref == null ||
        operation.baselineEtag == null ||
        operation.baselineEtag!.isEmpty ||
        operation.baselineRawIcs == null ||
        operation.baselineRawIcs!.isEmpty) {
      throw _resolutionUnavailable();
    }
    final sourceCollection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(sourceCollectionId))).getSingleOrNull();
    final destination =
        await (_database.select(_database.davCollections)
              ..where((row) => row.id.equals(destinationCollectionId)))
            .getSingleOrNull();
    final source = await (_database.select(
      _database.davObjects,
    )..where((row) => row.id.equals(sourceObjectId))).getSingleOrNull();
    if (sourceCollection == null ||
        destination == null ||
        source == null ||
        sourceCollection.accountId != operation.accountId ||
        destination.accountId != operation.accountId ||
        source.accountId != operation.accountId ||
        source.collectionId != sourceCollectionId ||
        sourceCollection.hrefKey != operation.davCollectionHref ||
        destination.hrefKey != operation.destinationCollectionHref ||
        source.hrefKey != operation.davMemberHref ||
        sourceCollection.deleted ||
        sourceCollection.serverMissing ||
        destination.deleted ||
        destination.serverMissing ||
        (source.serverDeleted && !allowServerDeleted) ||
        !_isExactCollectionMember(source, sourceCollection)) {
      throw _resolutionUnavailable();
    }
    _validatedMoveDestinationUri(operation, destination);
    final baseline = _trySemantic(operation.baselineRawIcs!);
    final target = _tryComponentIdentity(operation.targetComponentKey);
    if (baseline == null ||
        target == null ||
        baseline.primaryUid != source.primaryUid ||
        target.uid != source.primaryUid ||
        target.componentType != source.dominantComponentType ||
        baseline.components.any(
          (component) =>
              component.uid != source.primaryUid ||
              component.componentType != source.dominantComponentType,
        )) {
      throw _resolutionUnavailable();
    }
    return source;
  }

  Future<List<PendingOp>> _unattemptedMoveDependents(PendingOp selected) async {
    final accountOperations = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.accountId.equals(selected.accountId))).get();
    final dependents = <PendingOp>[];
    final dependencyIds = <String>{selected.id};
    var added = true;
    while (added) {
      added = false;
      for (final operation in accountOperations) {
        if (dependencyIds.contains(operation.id) ||
            !dependencyIds.contains(operation.dependsOnOpId)) {
          continue;
        }
        if (operation.operationType != 'dav.move' ||
            operation.state != 'pending' ||
            operation.attemptCount != 0) {
          throw _resolutionUnavailable();
        }
        dependencyIds.add(operation.id);
        dependents.add(operation);
        added = true;
      }
    }
    return dependents;
  }

  Future<_ResolutionContext> _context(String snapshotId) async {
    final snapshot =
        await (_database.select(_database.davConflictSnapshots)..where(
              (row) => row.id.equals(snapshotId) & row.resolvedAtUtc.isNull(),
            ))
            .getSingleOrNull();
    if (snapshot == null) throw _resolutionUnavailable();
    final operation =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.conflictSnapshotId.equals(snapshotId) &
                  row.state.equals('conflict'),
            ))
            .getSingleOrNull();
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(snapshot.accountId))).getSingleOrNull();
    final collectionId = snapshot.davCollectionId;
    final collection = collectionId == null
        ? null
        : await (_database.select(
            _database.davCollections,
          )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
    final objectId = snapshot.davObjectId;
    final object = objectId == null
        ? null
        : await (_database.select(
            _database.davObjects,
          )..where((row) => row.id.equals(objectId))).getSingleOrNull();
    if (operation == null || account == null || collection == null) {
      throw _resolutionUnavailable();
    }
    return _ResolutionContext(
      snapshot: snapshot,
      operation: operation,
      account: account,
      collection: collection,
      object: object,
    );
  }

  Future<void> _finish(
    _ResolutionContext context,
    DavConflictResolution resolution,
  ) async {
    final now = _nowUtc().toIso8601String();
    await _database.transaction(() async {
      await _database.pendingOpsDao.deleteOp(context.operation.id);
      await _markSnapshotResolved(context.snapshot.id, resolution, now);
    });
  }

  Future<void> _markSnapshotResolved(
    String id,
    DavConflictResolution resolution,
    String now,
  ) {
    return (_database.update(
      _database.davConflictSnapshots,
    )..where((row) => row.id.equals(id))).write(
      DavConflictSnapshotsCompanion(
        resolvedAtUtc: Value(now),
        resolution: Value(resolution.name),
      ),
    );
  }
}

final class _ResolutionContext {
  const _ResolutionContext({
    required this.snapshot,
    required this.operation,
    required this.account,
    required this.collection,
    required this.object,
  });

  final DavConflictSnapshot snapshot;
  final PendingOp operation;
  final Account account;
  final DavCollection collection;
  final DavObject? object;
}

final class _ValidatedMoveContext {
  const _ValidatedMoveContext({
    required this.source,
    required this.destination,
    required this.destinationUri,
    required this.canonicalDestination,
  });

  final DavObject source;
  final DavCollection destination;
  final Uri destinationUri;
  final DavPreparedObject? canonicalDestination;
}

enum _MoveConflictOutcome {
  notMove,
  sourceRetained,
  destinationCollision,
  destinationChanged,
  sourceRemoved,
  unavailable,
}

_MoveConflictOutcome _moveConflictOutcome(
  PendingOp? operation,
  String conflictCode,
) {
  if (operation?.operationType != 'dav.move') {
    return _MoveConflictOutcome.notMove;
  }
  return switch (conflictCode) {
    'DavConflictStaleMove' => _MoveConflictOutcome.sourceRetained,
    'DavConflictMoveDestinationExists' =>
      _MoveConflictOutcome.destinationCollision,
    'DavConflictMoveDestinationChanged' =>
      _MoveConflictOutcome.destinationChanged,
    'DavConflictMoveSourceRemoved' => _MoveConflictOutcome.sourceRemoved,
    _ => _MoveConflictOutcome.unavailable,
  };
}

bool _isMoveDestinationCollision(_ResolutionContext context) =>
    _moveConflictOutcome(context.operation, context.snapshot.conflictCode) ==
    _MoveConflictOutcome.destinationCollision;

bool _hasObjectIdentity(DavPreparedObject canonical, DavObject object) =>
    canonical.semantic.primaryUid == object.primaryUid &&
    canonical.semantic.components.every(
      (component) =>
          component.uid == object.primaryUid &&
          component.componentType == object.dominantComponentType,
    );

({String componentType, String uid})? _tryComponentIdentity(String? source) {
  if (source == null) return null;
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map ||
        decoded['componentType'] is! String ||
        decoded['uid'] is! String) {
      return null;
    }
    final componentType = (decoded['componentType']! as String).toUpperCase();
    final uid = decoded['uid']! as String;
    if ((componentType != 'VEVENT' && componentType != 'VTODO') ||
        uid.isEmpty) {
      return null;
    }
    return (componentType: componentType, uid: uid);
  } on Object {
    return null;
  }
}

bool _isExactCollectionMember(DavObject object, DavCollection collection) {
  final objectUri = Uri.tryParse(object.requestUri);
  final collectionUri = Uri.tryParse(collection.requestUri);
  if (objectUri == null || collectionUri == null) return false;
  final collectionHref = collection.hrefKey.endsWith('/')
      ? collection.hrefKey
      : '${collection.hrefKey}/';
  final relativeHref = object.hrefKey.startsWith(collectionHref)
      ? object.hrefKey.substring(collectionHref.length)
      : '';
  return objectUri.scheme == collectionUri.scheme &&
      objectUri.host == collectionUri.host &&
      objectUri.port == collectionUri.port &&
      objectUri.userInfo.isEmpty &&
      !objectUri.hasQuery &&
      !objectUri.hasFragment &&
      objectUri.path == object.hrefKey &&
      relativeHref.isNotEmpty &&
      !relativeHref.contains('/');
}

Uri _validatedMoveDestinationUri(
  PendingOp operation,
  DavCollection destination,
) {
  try {
    final decoded = jsonDecode(operation.requestJson);
    if (decoded is! Map) throw _resolutionUnavailable();
    final raw = decoded['destinationRequestUri'];
    final memberHref = operation.destinationMemberHref;
    if (raw is! String || raw.isEmpty || memberHref == null) {
      throw _resolutionUnavailable();
    }
    final uri = Uri.parse(raw);
    final collectionUri = Uri.parse(destination.requestUri);
    final collectionHref = destination.hrefKey.endsWith('/')
        ? destination.hrefKey
        : '${destination.hrefKey}/';
    final relativeHref = memberHref.startsWith(collectionHref)
        ? memberHref.substring(collectionHref.length)
        : '';
    if (uri.scheme != collectionUri.scheme ||
        uri.host != collectionUri.host ||
        uri.port != collectionUri.port ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != memberHref ||
        relativeHref.isEmpty ||
        relativeHref.contains('/')) {
      throw _resolutionUnavailable();
    }
    return uri;
  } on DavException {
    rethrow;
  } on Object {
    throw _resolutionUnavailable();
  }
}

DavConflictEntity _entity(
  DavConflictSnapshot snapshot,
  Account account,
  DavCollection? collection,
  PendingOp? operation,
) {
  final local = _trySemantic(snapshot.localCandidateRawIcs);
  final remote = _trySemantic(snapshot.remoteRawIcs);
  final component =
      local?.components.firstOrNull ?? remote?.components.firstOrNull;
  final provider = BusyProviderCodec.requireStorageValue(account.provider);
  final patch = operation?.mutationPatchJson == null
      ? null
      : _tryPatch(operation!.mutationPatchJson!);
  final hasRemote =
      snapshot.remoteEtag != null && snapshot.remoteRawIcs.isNotEmpty;
  final moveOutcome = _moveConflictOutcome(operation, snapshot.conflictCode);
  final keepServerAvailable = switch (moveOutcome) {
    _MoveConflictOutcome.sourceRemoved => true,
    _MoveConflictOutcome.unavailable => false,
    _ => hasRemote,
  };
  return DavConflictEntity(
    id: snapshot.id,
    accountId: snapshot.accountId,
    provider: provider,
    accountLabel: _accountLabel(account, provider),
    collectionName: collection?.displayName ?? provider.displayName,
    itemTitle: component?.summary?.trim().isNotEmpty == true
        ? component!.summary!.trim()
        : '(untitled)',
    componentType: component?.componentType ?? operation?.entityType ?? 'item',
    remoteChangedAtUtc: _remoteChangedAt(remote),
    localEditSummary: _editSummary(operation, patch),
    conflictCode: snapshot.conflictCode,
    canKeepServer: keepServerAvailable,
    canReapplyLocal:
        operation?.operationType == 'dav.update' &&
        snapshot.remoteEtag != null &&
        snapshot.remoteRawIcs.isNotEmpty &&
        patch != null,
    canDuplicate:
        snapshot.localCandidateRawIcs.isNotEmpty &&
        moveOutcome != _MoveConflictOutcome.unavailable,
  );
}

IcalSemanticDocument? _trySemantic(String source) {
  if (source.isEmpty) return null;
  try {
    return IcalSemanticDocument.parse(source);
  } on Object {
    return null;
  }
}

DavMutationPatch? _tryPatch(String source) {
  try {
    return DavMutationPatch.fromJsonString(source);
  } on Object {
    return null;
  }
}

DateTime? _remoteChangedAt(IcalSemanticDocument? document) {
  if (document == null) return null;
  final component = document.components.first;
  final temporal = component.lastModified ?? component.dtstamp;
  if (temporal == null) return null;
  final raw = temporal.rawValue;
  if (!raw.endsWith('Z') || raw.length < 16) return null;
  return DateTime.tryParse(
    '${raw.substring(0, 4)}-${raw.substring(4, 6)}-'
    '${raw.substring(6, 8)}T${raw.substring(9, 11)}:'
    '${raw.substring(11, 13)}:${raw.substring(13, 15)}Z',
  );
}

String _editSummary(PendingOp? operation, DavMutationPatch? patch) {
  if (operation == null) return 'Pending DAV change';
  if (operation.operationType == 'dav.create') return 'Create item';
  if (operation.operationType == 'dav.delete') return 'Delete item';
  final names = patch?.changedProperties.toList();
  names?.sort();
  return names == null || names.isEmpty
      ? 'Update item'
      : 'Update ${names.join(', ')}';
}

String _accountLabel(Account account, BusyProvider provider) {
  final display = account.displayName?.trim();
  if (display != null && display.isNotEmpty) return display;
  final email = account.email?.trim();
  if (email != null && email.isNotEmpty) return email;
  return provider.displayName;
}

String _duplicateResource(
  String source, {
  required String uid,
  required DateTime nowUtc,
}) {
  final document = IcalDocument.parse(source);
  final stamp = _utcIcal(nowUtc);
  for (final component in document.calendarComponents.where(
    (component) => component.name == 'VEVENT' || component.name == 'VTODO',
  )) {
    final uidProperty = component.firstProperty('UID');
    if (uidProperty == null) throw _resolutionUnavailable();
    uidProperty
      ..rawValue = uid
      ..isDirty = true;
    final stampProperty = component.firstProperty('DTSTAMP');
    if (stampProperty != null) {
      stampProperty
        ..rawValue = stamp
        ..isDirty = true;
    }
    component.structurallyDirty = true;
  }
  document.root.structurallyDirty = true;
  final serialized = document.serialize();
  IcalSemanticDocument.parse(serialized);
  return serialized;
}

String _utcIcal(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

DavException _resolutionUnavailable() => const DavException(
  kind: DavErrorKind.conflict,
  code: 'DavConflictResolutionUnavailable',
  safeMessage: 'That conflict resolution is not available for this item.',
);
