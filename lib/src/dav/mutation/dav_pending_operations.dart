import 'dart:convert';
import '../../features/maps/data/location_resolution_repository.dart';
import '../../features/maps/domain/location_result.dart';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../calendar_providers/calendar_mutation.dart';
import '../../db/app_database.dart';
import '../../features/accounts/domain/account_connection_state.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../ical/ical_document.dart';
import '../ical/ical_semantics.dart';
import '../ical/ical_timezone.dart';
import '../storage/dav_collection_capabilities.dart';
import '../storage/dav_object_repository.dart';
import '../nextcloud/nextcloud_scheduling_policy.dart';
import '../sync/dav_collection_remote_client.dart';
import 'dav_conditional_mutation_service.dart';
import 'dav_mutation_patch.dart';
import 'dav_pending_operation_selection.dart';

const davPendingOperationSchemaVersion = 1;
const davPartialMoveRetryClassification = 'partial_move';
const _davMoveMayHaveCompletedRequestKey = 'moveMayHaveCompleted';

bool isDavPartiallyCompletedMove(PendingOp operation) =>
    operation.operationType == 'dav.move' &&
    (operation.retryClassification == davPartialMoveRetryClassification ||
        operation.lastErrorCode == davPartialMoveFailureCode ||
        _requestMarksMoveMayHaveCompleted(operation.requestJson));

bool _davOperationNeedsReconciliation(PendingOp operation) =>
    operation.attemptCount > 0 ||
    operation.state == DavPendingState.inProgress.storageValue ||
    operation.retryClassification == 'manual_retry' ||
    operation.retryClassification == 'credential_replaced' ||
    isDavPartiallyCompletedMove(operation);

bool _davMoveNeedsReconciliation(PendingOp operation) =>
    operation.operationType == 'dav.move' &&
    _davOperationNeedsReconciliation(operation);

const _davMutationPutRejectedMessage =
    'The DAV server could not update the object.';

enum DavPendingOperationType { create, update, delete, move }

enum DavPendingState {
  pending,
  retry,
  inProgress,
  conflict,
  authBlocked,
  permissionBlocked,
  failed,
}

extension on DavPendingState {
  String get storageValue => switch (this) {
    DavPendingState.pending => 'pending',
    DavPendingState.retry => 'retry',
    DavPendingState.inProgress => 'in_progress',
    DavPendingState.conflict => 'conflict',
    DavPendingState.authBlocked => 'auth_blocked',
    DavPendingState.permissionBlocked => 'permission_blocked',
    DavPendingState.failed => 'failed',
  };
}

final class DavPendingOperationQueue {
  DavPendingOperationQueue({
    required AppDatabase database,
    String Function()? idFactory,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _idFactory = idFactory ?? const Uuid().v4,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final String Function() _idFactory;
  final DateTime Function() _nowUtc;

  Future<String> enqueueCreate({
    required String accountId,
    required String collectionId,
    required DavNewObject object,
    String? localProjectionId,
    String? localObjectId,
    String? dependsOnOperationId,
  }) async {
    final context = await _context(accountId, collectionId);
    if (object.suppressScheduling &&
        context.provider != BusyProvider.nextcloud) {
      throw _invalidPendingOperation();
    }
    final capabilities = collectionCapabilitiesFromStored(context.collection);
    final isEvent = _componentIsEvent(object.componentType);
    final canCreate = isEvent
        ? capabilities.canCreateEvent
        : capabilities.canCreateTask;
    if (!canCreate) throw _permissionError();
    if (localObjectId != null) {
      final local = await _objectContext(
        accountId,
        collectionId,
        localObjectId,
      );
      if (local.object.etag != null || local.object.primaryUid != object.uid) {
        throw _invalidPendingOperation();
      }
    }
    final memberUri = _memberUri(
      Uri.parse(context.collection.requestUri),
      object.initialMemberName,
    );
    final parsed = IcalSemanticDocument.parse(object.rawIcs);
    if (parsed.primaryUid != object.uid ||
        parsed.components.any(
          (component) => component.componentType != object.componentType,
        )) {
      throw _invalidPendingOperation();
    }
    _validateTaskTemporalRange(parsed);
    await _validateScheduling(
      context,
      null,
      object.rawIcs,
      silent: object.suppressScheduling,
    );
    final id = _idFactory();
    final now = _nowUtc().toUtc().toIso8601String();
    await _database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: id,
        accountId: accountId,
        provider: Value(context.provider.storageValue),
        entityType: _entityType(object.componentType),
        operation: 'dav_create',
        operationType: const Value('dav.create'),
        davCollectionId: Value(collectionId),
        davObjectId: Value(localObjectId),
        davCollectionHref: Value(context.collection.hrefKey),
        davMemberHref: Value(memberUri.path),
        mutationPatchSchemaVersion: const Value(
          davPendingOperationSchemaVersion,
        ),
        targetComponentKey: Value(
          _componentKeyJson(
            IcalComponentKey(
              componentType: object.componentType.toUpperCase(),
              uid: object.uid,
            ),
          ),
        ),
        mutationScope: Value(DavMutationScope.object.name),
        retryClassification: const Value('conditional_create'),
        localTempId: Value(object.uid),
        eventId: Value(isEvent ? localProjectionId : null),
        taskId: Value(isEvent ? null : localProjectionId),
        dependsOnOpId: Value(dependsOnOperationId),
        requestJson: jsonEncode({
          'schemaVersion': davPendingOperationSchemaVersion,
          'uid': object.uid,
          'initialMemberName': object.initialMemberName,
          'rawIcs': object.rawIcs,
          'componentType': object.componentType.toUpperCase(),
          if (object.suppressScheduling) 'suppressScheduling': true,
        }),
        state: Value(DavPendingState.pending.storageValue),
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    return id;
  }

  Future<String> enqueueUpdate({
    required String accountId,
    required String collectionId,
    required String objectId,
    required DavMutationPatch patch,
    String? dependsOnOperationId,
  }) async {
    final nowUtc = _nowUtc().toUtc();
    final materializedPatch = patch.materialize(nowUtc);
    final context = await _objectContext(accountId, collectionId, objectId);
    final capabilities = collectionCapabilitiesFromStored(context.collection);
    final event = _componentIsEvent(patch.target.componentType);
    if (event ? !capabilities.canUpdateEvent : !capabilities.canUpdateTask) {
      throw _permissionError();
    }
    final etag = context.object.etag;
    final unsent = await _activeObjectOperation(objectId);
    if (etag == null && unsent != null && isDavCreateLocallyEditable(unsent)) {
      await _writeCreatePatch(unsent, patch);
      return unsent.id;
    }
    if (etag == null || etag.isEmpty || context.object.serverDeleted) {
      throw _invalidPendingOperation();
    }
    final existing = await _activeObjectOperation(objectId);
    if (existing != null) {
      if (dependsOnOperationId != null &&
          existing.dependsOnOpId != null &&
          existing.dependsOnOpId != dependsOnOperationId) {
        throw _operationAlreadyPending();
      }
      final coalesced = _coalesceUnsentUpdate(
        existing,
        materializedPatch,
        baselineEtag: etag,
        nowUtc: nowUtc,
      );
      if (coalesced != null) {
        // Coalesced operations are always replayed against the original
        // server-confirmed baseline. Validate that exact durable candidate.
        final candidate = coalesced.applyTo(
          _required(existing.baselineRawIcs),
          nowUtc: nowUtc,
        );
        _validateTaskTemporalRange(IcalSemanticDocument.parse(candidate));
        await _validateScheduling(
          context,
          context.object.rawIcsBody,
          candidate,
        );
        await (_database.update(
          _database.pendingOps,
        )..where((row) => row.id.equals(existing.id))).write(
          PendingOpsCompanion(
            mutationPatchJson: Value(coalesced.toJsonString()),
            mutationPatchSchemaVersion: Value(coalesced.schemaVersion),
            targetComponentKey: Value(_componentKeyJson(coalesced.target)),
            mutationScope: Value(coalesced.scope.name),
            dependsOnOpId: existing.dependsOnOpId == null
                ? Value(dependsOnOperationId)
                : const Value.absent(),
            updatedAtUtc: Value(nowUtc.toIso8601String()),
          ),
        );
        return existing.id;
      }
      throw _operationAlreadyPending();
    }

    final candidate = materializedPatch.applyTo(
      context.object.rawIcsBody,
      nowUtc: nowUtc,
    );
    _validateTaskTemporalRange(IcalSemanticDocument.parse(candidate));
    await _validateScheduling(context, context.object.rawIcsBody, candidate);

    final id = _idFactory();
    final now = nowUtc.toIso8601String();
    await _database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: id,
        accountId: accountId,
        provider: Value(context.provider.storageValue),
        entityType: _entityType(patch.target.componentType),
        operation: 'dav_update',
        operationType: const Value('dav.update'),
        davCollectionId: Value(collectionId),
        davCollectionHref: Value(context.collection.hrefKey),
        davObjectId: Value(objectId),
        davMemberHref: Value(context.object.hrefKey),
        baselineEtag: Value(etag),
        baselineRawIcs: Value(context.object.rawIcsBody),
        mutationPatchJson: Value(materializedPatch.toJsonString()),
        mutationPatchSchemaVersion: Value(materializedPatch.schemaVersion),
        targetComponentKey: Value(_componentKeyJson(patch.target)),
        mutationScope: Value(patch.scope.name),
        retryClassification: const Value('conditional_update'),
        dependsOnOpId: Value(dependsOnOperationId),
        requestJson: '{}',
        state: Value(DavPendingState.pending.storageValue),
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    return id;
  }

  /// Returns the server baseline plus any provably-unsent update for local
  /// editor patch construction. An operation that may have reached the server
  /// is deliberately not editable until replay reconciles its outcome.
  Future<String> editableRawIcsForObject({
    required String accountId,
    required String collectionId,
    required String objectId,
  }) async {
    final context = await _objectContext(accountId, collectionId, objectId);
    final existing = await _activeObjectOperation(objectId);
    if (existing == null) return context.object.rawIcsBody;
    if (isDavCreateLocallyEditable(existing)) {
      return _decodeCreate(existing.requestJson).rawIcs;
    }
    final safelyEditable =
        existing.operationType == 'dav.update' &&
        existing.state == DavPendingState.pending.storageValue &&
        existing.attemptCount == 0 &&
        existing.baselineEtag == context.object.etag &&
        existing.baselineRawIcs != null;
    if (!safelyEditable) throw _operationAlreadyPending();
    return _decodePatch(
      existing,
    ).applyTo(existing.baselineRawIcs!, nowUtc: _nowUtc().toUtc());
  }

  /// Reading an export is safe even while an immutable operation is replaying.
  Future<String> exportRawIcsForObject({
    required String accountId,
    required String collectionId,
    required String objectId,
  }) async {
    final context = await _objectContext(accountId, collectionId, objectId);
    final operation = await _effectiveObjectOperation(objectId);
    if (operation?.operationType == 'dav.create') {
      return _decodeCreate(operation!.requestJson).rawIcs;
    }
    if (operation?.operationType == 'dav.update') {
      return _decodePatch(
        operation!,
      ).applyTo(_required(operation.baselineRawIcs), nowUtc: _nowUtc().toUtc());
    }
    if (operation?.operationType == 'dav.move') {
      return _moveCandidateRaw(operation!, _nowUtc());
    }
    return context.object.rawIcsBody;
  }

  /// Applies a typed patch to a create that is still entirely local.
  ///
  /// This is deliberately limited to an operation that has never been sent,
  /// or one the server explicitly rejected before creating the resource.
  /// Unknown-outcome creates remain immutable until replay reconciles them.
  Future<bool> updateUnsentCreate({
    required String accountId,
    required String collectionId,
    required String localProjectionId,
    required DavMutationPatch patch,
  }) async {
    await _context(accountId, collectionId);
    final operation = await _editableCreate(
      accountId: accountId,
      collectionId: collectionId,
      localProjectionId: localProjectionId,
    );
    if (operation == null) return false;
    await _writeCreatePatch(operation, patch);
    return true;
  }

  Future<void> _writeCreatePatch(
    PendingOp operation,
    DavMutationPatch patch,
  ) async {
    final object = _decodeCreate(operation.requestJson);
    if (patch.target.componentType.toUpperCase() !=
            object.componentType.toUpperCase() ||
        patch.target.uid != object.uid) {
      throw _invalidPendingOperation();
    }
    final nowUtc = _nowUtc().toUtc();
    final materialized = patch.materialize(nowUtc);
    final updatedRaw = materialized.applyTo(object.rawIcs, nowUtc: nowUtc);
    _validateTaskTemporalRange(IcalSemanticDocument.parse(updatedRaw));
    await _validateScheduling(
      await _context(operation.accountId, _required(operation.davCollectionId)),
      object.rawIcs,
      updatedRaw,
      silent: object.suppressScheduling,
    );
    await (_database.update(
      _database.pendingOps,
    )..where((row) => row.id.equals(operation.id))).write(
      PendingOpsCompanion(
        requestJson: Value(
          jsonEncode({
            'schemaVersion': davPendingOperationSchemaVersion,
            'uid': object.uid,
            'initialMemberName': object.initialMemberName,
            'rawIcs': updatedRaw,
            'componentType': object.componentType.toUpperCase(),
            if (object.suppressScheduling) 'suppressScheduling': true,
          }),
        ),
        state: Value(DavPendingState.pending.storageValue),
        retryClassification: const Value('conditional_create'),
        nextAttemptAtUtc: const Value(null),
        lastErrorCode: const Value(null),
        lastErrorMessage: const Value(null),
        lastError: const Value(null),
        updatedAtUtc: Value(nowUtc.toIso8601String()),
      ),
    );
  }

  /// Cancels a create only while it is provably unsent.
  Future<bool> cancelUnsentCreate({
    required String accountId,
    required String collectionId,
    required String localProjectionId,
  }) async {
    await _context(accountId, collectionId);
    final operation = await _editableCreate(
      accountId: accountId,
      collectionId: collectionId,
      localProjectionId: localProjectionId,
    );
    if (operation == null) return false;
    await _database.pendingOpsDao.deleteOp(operation.id);
    return true;
  }

  /// Makes a Diagnostics retry eligible for the DAV replayer without
  /// bypassing conflict, credential, permission, or unknown-outcome recovery.
  Future<void> retryBlockedOperation({
    required String accountId,
    required String operationId,
  }) async {
    final operation = await _database.pendingOpsDao.getOp(operationId);
    if (operation == null) return;
    if (operation.accountId != accountId || !isDavPendingOperation(operation)) {
      throw StateError('The DAV operation is not available for recovery.');
    }
    switch (operation.state) {
      case 'failed':
        if (operation.retryClassification != 'permanent' &&
            operation.retryClassification !=
                davPartialMoveRetryClassification) {
          throw StateError(
            'This DAV failure cannot be retried without reconciliation.',
          );
        }
        final updated = await _database.pendingOpsDao
            .retryFailedDavOperationNow(
              operation,
              _nowUtc().toUtc(),
              requestJson: isDavPartiallyCompletedMove(operation)
                  ? _markMoveMayHaveCompleted(operation.requestJson)
                  : null,
            );
        if (!updated) {
          throw StateError(
            'The DAV operation changed before it could be retried.',
          );
        }
      case 'pending' || 'retry' || 'in_progress':
        await _database.pendingOpsDao.retryNow(operation.id, _nowUtc().toUtc());
      case 'conflict':
        throw StateError(
          'Resolve this DAV conflict from the conflict review before retrying.',
        );
      case 'auth_blocked':
        throw StateError(
          'Reconnect this DAV account before retrying its pending changes.',
        );
      case 'permission_blocked':
        throw StateError(
          'Refresh this DAV account after its permissions change before '
          'retrying.',
        );
      default:
        throw StateError('This DAV operation cannot be retried safely.');
    }
  }

  /// Discards one recoverable DAV intent and its still-unattempted dependents,
  /// removing local creations or restoring confirmed server projections.
  Future<bool> discardBlockedOperation({
    required String accountId,
    required String operationId,
    DateTime? partialMoveReconciledAfterUtc,
  }) {
    return _database.transaction(() async {
      final selected = await _database.pendingOpsDao.getOp(operationId);
      if (selected == null) return false;
      if (selected.accountId != accountId || !isDavPendingOperation(selected)) {
        throw StateError('The DAV operation is not available for recovery.');
      }
      _ensureDavDiscardable(selected);
      final partialMoveAtDestination = isDavPartiallyCompletedMove(selected)
          ? await _reconciledPartialMoveIsAtDestination(
              selected,
              reconciledAfterUtc: partialMoveReconciledAfterUtc,
            )
          : false;
      final operations = await _davDependentClosure(selected);
      for (final dependent in operations.skip(1)) {
        if (!isDavPendingOperation(dependent) ||
            dependent.state != DavPendingState.pending.storageValue ||
            dependent.attemptCount != 0) {
          throw StateError(
            'A dependent DAV operation cannot be discarded safely.',
          );
        }
      }

      final createdObjectIds = {
        for (final operation in operations)
          if (operation.operationType == 'dav.create' &&
              operation.davObjectId != null)
            operation.davObjectId!,
      };
      final restoreObjectIds = {
        for (final operation in operations)
          if (operation.operationType != 'dav.create' &&
              operation.davObjectId != null &&
              !(partialMoveAtDestination && operation.id == selected.id) &&
              !createdObjectIds.contains(operation.davObjectId))
            operation.davObjectId!,
      };
      final operationIds = {for (final operation in operations) operation.id};
      final now = _nowUtc().toUtc();
      await (_database.delete(
        _database.pendingOps,
      )..where((row) => row.id.isIn(operationIds))).go();
      for (final operation in operations.where(
        (operation) => operation.operationType == 'dav.create',
      )) {
        if (operation.eventId != null) {
          await (_database.delete(_database.calendarEvents)..where(
                (row) =>
                    row.accountId.equals(accountId) &
                    row.id.equals(operation.eventId!),
              ))
              .go();
        }
        if (operation.taskId != null) {
          await (_database.delete(_database.tasks)..where(
                (row) =>
                    row.accountId.equals(accountId) &
                    row.id.equals(operation.taskId!),
              ))
              .go();
        }
      }
      for (final objectId in createdObjectIds) {
        final object = await (_database.select(
          _database.davObjects,
        )..where((row) => row.id.equals(objectId))).getSingleOrNull();
        if (object == null ||
            object.accountId != accountId ||
            object.etag != null) {
          throw StateError(
            'A pending DAV creation cannot be discarded safely.',
          );
        }
        await (_database.delete(
          _database.calendarEvents,
        )..where((row) => row.davObjectId.equals(objectId))).go();
        await (_database.delete(
          _database.tasks,
        )..where((row) => row.davObjectId.equals(objectId))).go();
        await (_database.delete(
          _database.davObjects,
        )..where((row) => row.id.equals(objectId))).go();
      }
      final repository = DavObjectRepository(database: _database);
      for (final objectId in restoreObjectIds) {
        await repository.restoreServerProjectionAfterDiscard(
          accountId: accountId,
          objectId: objectId,
          restoredAtUtc: now,
        );
      }
      return restoreObjectIds.isNotEmpty;
    });
  }

  void _ensureDavDiscardable(PendingOp operation) {
    if (operation.operationType == 'dav.create') {
      if (!isDavCreateLocallyEditable(operation)) {
        throw StateError(
          'This DAV creation cannot be discarded until its outcome is known.',
        );
      }
      return;
    }
    if (operation.state == DavPendingState.conflict.storageValue) {
      throw StateError(
        'Resolve this DAV conflict from the conflict review before discarding.',
      );
    }
    if (operation.state == DavPendingState.inProgress.storageValue ||
        operation.state == DavPendingState.retry.storageValue ||
        operation.state == 'blocked') {
      throw StateError(
        'This DAV operation cannot be discarded until its outcome is known.',
      );
    }
    if (operation.state == DavPendingState.pending.storageValue &&
        operation.attemptCount != 0) {
      throw StateError(
        'This DAV operation cannot be discarded until its outcome is known.',
      );
    }
    if (operation.state == DavPendingState.failed.storageValue &&
        operation.retryClassification != 'permanent' &&
        operation.retryClassification != davPartialMoveRetryClassification) {
      throw StateError(
        'This DAV failure cannot be discarded without reconciliation.',
      );
    }
    if (operation.state != DavPendingState.pending.storageValue &&
        operation.state != DavPendingState.failed.storageValue &&
        operation.state != DavPendingState.authBlocked.storageValue &&
        operation.state != DavPendingState.permissionBlocked.storageValue) {
      throw StateError('This DAV operation cannot be discarded safely.');
    }
  }

  Future<List<PendingOp>> _davDependentClosure(PendingOp selected) async {
    final unresolved =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.accountId.equals(selected.accountId) &
                  row.state.isIn(davUnresolvedPendingStates),
            ))
            .get();
    final result = <PendingOp>[selected];
    final ids = <String>{selected.id};
    var index = 0;
    while (index < result.length) {
      final parent = result[index++].id;
      for (final operation in unresolved) {
        if (operation.dependsOnOpId == parent && ids.add(operation.id)) {
          result.add(operation);
        }
      }
    }
    return result;
  }

  Future<bool> _reconciledPartialMoveIsAtDestination(
    PendingOp operation, {
    required DateTime? reconciledAfterUtc,
  }) async {
    final sourceCollectionId = operation.davCollectionId;
    final destinationCollectionId = operation.destinationCollectionId;
    final destinationHref = operation.destinationMemberHref;
    final objectId = operation.davObjectId;
    if (operation.operationType != 'dav.move' ||
        sourceCollectionId == null ||
        destinationCollectionId == null ||
        destinationHref == null ||
        objectId == null ||
        reconciledAfterUtc == null) {
      throw StateError(
        'The partially completed DAV move must be synchronized before it can '
        'be discarded.',
      );
    }
    final cursors =
        await (_database.select(_database.syncCursors)..where(
              (row) =>
                  row.accountId.equals(operation.accountId) &
                  row.davCollectionId.isIn([
                    sourceCollectionId,
                    destinationCollectionId,
                  ]) &
                  row.transport.equals('caldav') &
                  row.syncScopeKind.equals('collection'),
            ))
            .get();
    final reconciledAt = reconciledAfterUtc.toUtc().millisecondsSinceEpoch;
    final cursorByCollection = {
      for (final cursor in cursors) cursor.davCollectionId: cursor,
    };
    if (cursorByCollection[sourceCollectionId]?.lastCompleteSyncAt == null ||
        cursorByCollection[destinationCollectionId]?.lastCompleteSyncAt ==
            null ||
        cursorByCollection[sourceCollectionId]!.lastCompleteSyncAt! <
            reconciledAt ||
        cursorByCollection[destinationCollectionId]!.lastCompleteSyncAt! <
            reconciledAt) {
      throw StateError(
        'The partially completed DAV move could not be reconciled.',
      );
    }
    final source = await (_database.select(
      _database.davObjects,
    )..where((row) => row.id.equals(objectId))).getSingleOrNull();
    final destination =
        await (_database.select(_database.davObjects)..where(
              (row) =>
                  row.accountId.equals(operation.accountId) &
                  row.collectionId.equals(destinationCollectionId) &
                  row.hrefKey.equals(destinationHref) &
                  row.serverDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (source != null && !source.serverDeleted && destination == null) {
      return false;
    }
    if (source == null ||
        !source.serverDeleted ||
        destination == null ||
        destination.etag == null ||
        source.primaryUid == null ||
        source.primaryUid != destination.primaryUid ||
        source.dominantComponentType != destination.dominantComponentType) {
      throw StateError(
        'The partially completed DAV move remains ambiguous after '
        'synchronization.',
      );
    }
    return true;
  }

  Future<String> enqueueDelete({
    required String accountId,
    required String collectionId,
    required String objectId,
    required IcalComponentKey target,
    DavMutationScope scope = DavMutationScope.object,
    String? dependsOnOperationId,
  }) async {
    final context = await _objectContext(accountId, collectionId, objectId);
    final capabilities = collectionCapabilitiesFromStored(context.collection);
    final event = _componentIsEvent(target.componentType);
    if (event ? !capabilities.canDeleteEvent : !capabilities.canDeleteTask) {
      throw _permissionError();
    }
    final etag = context.object.etag;
    final unsent = await _activeObjectOperation(objectId);
    if (etag == null && unsent != null && isDavCreateLocallyEditable(unsent)) {
      await _database.transaction(() async {
        await _database.pendingOpsDao.deleteOp(unsent.id);
        await (_database.delete(
          _database.calendarEvents,
        )..where((r) => r.davObjectId.equals(objectId))).go();
        await (_database.delete(
          _database.tasks,
        )..where((r) => r.davObjectId.equals(objectId))).go();
        await (_database.delete(
          _database.davObjects,
        )..where((r) => r.id.equals(objectId))).go();
      });
      return unsent.id;
    }
    if (etag == null || etag.isEmpty || context.object.serverDeleted) {
      throw _invalidPendingOperation();
    }
    final existingOperation = await _activeObjectOperation(objectId);
    if (existingOperation != null) {
      final cancellableUpdate =
          existingOperation.operationType == 'dav.update' &&
          existingOperation.state == DavPendingState.pending.storageValue &&
          existingOperation.attemptCount == 0;
      if (!cancellableUpdate) throw _operationAlreadyPending();
      await _database.pendingOpsDao.deleteOp(existingOperation.id);
    }
    final semantic = IcalSemanticDocument.parse(context.object.rawIcsBody);
    await _validateScheduling(context, context.object.rawIcsBody, null);
    if (!_containsTarget(semantic, target)) throw _invalidPendingOperation();
    final id = _idFactory();
    final now = _nowUtc().toUtc().toIso8601String();
    await _database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: id,
        accountId: accountId,
        provider: Value(context.provider.storageValue),
        entityType: _entityType(target.componentType),
        operation: 'dav_delete',
        operationType: const Value('dav.delete'),
        davCollectionId: Value(collectionId),
        davCollectionHref: Value(context.collection.hrefKey),
        davObjectId: Value(objectId),
        davMemberHref: Value(context.object.hrefKey),
        baselineEtag: Value(etag),
        baselineRawIcs: Value(context.object.rawIcsBody),
        mutationPatchSchemaVersion: const Value(
          davPendingOperationSchemaVersion,
        ),
        targetComponentKey: Value(_componentKeyJson(target)),
        mutationScope: Value(scope.name),
        retryClassification: const Value('conditional_delete'),
        dependsOnOpId: Value(dependsOnOperationId),
        requestJson: jsonEncode({'isEvent': event}),
        state: Value(DavPendingState.pending.storageValue),
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    return id;
  }

  Future<String> enqueueMove({
    required String accountId,
    required String sourceCollectionId,
    required String destinationCollectionId,
    required String objectId,
    required IcalComponentKey target,
    String? localProjectionId,
    DavMutationPatch? postMovePatch,
    String? dependsOnOperationId,
  }) async {
    final source = await _objectContext(
      accountId,
      sourceCollectionId,
      objectId,
    );
    final destination = await _context(accountId, destinationCollectionId);
    final providerSupportsMove =
        source.provider == BusyProvider.nextcloud ||
        source.provider == BusyProvider.appleICloud;
    if (!providerSupportsMove ||
        destination.provider != source.provider ||
        source.collection.id == destination.collection.id) {
      throw _invalidPendingOperation();
    }
    final sourceCapabilities = collectionCapabilitiesFromStored(
      source.collection,
    );
    final destinationCapabilities = collectionCapabilitiesFromStored(
      destination.collection,
    );
    final event = _componentIsEvent(target.componentType);
    final canDelete = event
        ? sourceCapabilities.canDeleteEvent
        : sourceCapabilities.canDeleteTask;
    final canCreate = event
        ? destinationCapabilities.canCreateEvent
        : destinationCapabilities.canCreateTask;
    final canUpdate = event
        ? destinationCapabilities.canUpdateEvent
        : destinationCapabilities.canUpdateTask;
    if (!canDelete ||
        !canCreate ||
        (postMovePatch != null && !canUpdate) ||
        source.object.serverDeleted ||
        source.object.etag == null ||
        source.object.etag!.isEmpty) {
      throw _permissionError();
    }

    final sourceUri = Uri.tryParse(source.object.requestUri);
    final destinationCollectionUri = Uri.tryParse(
      destination.collection.requestUri,
    );
    if (sourceUri == null || destinationCollectionUri == null) {
      throw _invalidPendingOperation();
    }
    final destinationUri = _moveDestinationUri(
      sourceUri,
      destinationCollectionUri,
    );
    final existing = await _activeObjectOperation(objectId);
    var dependency = dependsOnOperationId;
    var intendedSourceRaw = source.object.rawIcsBody;
    if (existing != null) {
      final isEditableUpdate =
          existing.operationType == 'dav.update' &&
          existing.state == DavPendingState.pending.storageValue &&
          existing.attemptCount == 0 &&
          existing.baselineRawIcs != null;
      if (!isEditableUpdate) throw _operationAlreadyPending();
      if (dependency != null &&
          existing.dependsOnOpId != null &&
          existing.dependsOnOpId != dependency) {
        throw _operationAlreadyPending();
      }
      if (dependency != null && existing.dependsOnOpId == null) {
        await (_database.update(_database.pendingOps)
              ..where((row) => row.id.equals(existing.id)))
            .write(PendingOpsCompanion(dependsOnOpId: Value(dependency)));
      }
      intendedSourceRaw = _decodePatch(
        existing,
      ).applyTo(existing.baselineRawIcs!, nowUtc: _nowUtc().toUtc());
      dependency = existing.id;
    }
    final semantic = IcalSemanticDocument.parse(intendedSourceRaw);
    if (!_containsTarget(semantic, target)) throw _invalidPendingOperation();
    final nowUtc = _nowUtc().toUtc();
    final materializedPatch = postMovePatch?.materialize(nowUtc);
    if (source.provider == BusyProvider.nextcloud && event) {
      final policy = await NextcloudSchedulingPolicy.load(
        _database,
        source.collection,
      );
      policy.validateMoveTo(
        await NextcloudSchedulingPolicy.load(_database, destination.collection),
        intendedSourceRaw,
        materializedPatch?.applyTo(intendedSourceRaw, nowUtc: nowUtc) ??
            intendedSourceRaw,
      );
    }
    if (materializedPatch != null) {
      if (!_sameTarget(materializedPatch.target, target)) {
        throw _invalidPendingOperation();
      }
      _validateTaskTemporalRange(
        IcalSemanticDocument.parse(
          materializedPatch.applyTo(intendedSourceRaw, nowUtc: nowUtc),
        ),
      );
    }

    final id = _idFactory();
    final now = nowUtc.toIso8601String();
    await _database.pendingOpsDao.enqueue(
      PendingOpsCompanion.insert(
        id: id,
        accountId: accountId,
        provider: Value(source.provider.storageValue),
        entityType: _entityType(target.componentType),
        operation: 'dav_move',
        operationType: const Value('dav.move'),
        davCollectionId: Value(sourceCollectionId),
        davCollectionHref: Value(source.collection.hrefKey),
        davObjectId: Value(objectId),
        davMemberHref: Value(source.object.hrefKey),
        baselineEtag: Value(source.object.etag),
        baselineRawIcs: Value(intendedSourceRaw),
        mutationPatchJson: Value(materializedPatch?.toJsonString()),
        mutationPatchSchemaVersion: Value(materializedPatch?.schemaVersion),
        targetComponentKey: Value(_componentKeyJson(target)),
        mutationScope: Value(
          materializedPatch?.scope.name ?? DavMutationScope.object.name,
        ),
        destinationCollectionId: Value(destinationCollectionId),
        destinationCollectionHref: Value(destination.collection.hrefKey),
        destinationMemberHref: Value(destinationUri.path),
        retryClassification: const Value('conditional_move'),
        taskId: Value(event ? null : localProjectionId),
        eventId: Value(event ? localProjectionId : null),
        dependsOnOpId: Value(dependency),
        requestJson: jsonEncode({
          'isEvent': event,
          'destinationRequestUri': destinationUri.toString(),
        }),
        state: Value(DavPendingState.pending.storageValue),
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    return id;
  }

  Future<_DavContext> _context(String accountId, String collectionId) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(accountId))).getSingleOrNull();
    final collection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
    if (account == null ||
        collection == null ||
        collection.accountId != accountId ||
        collection.deleted ||
        collection.serverMissing) {
      throw _invalidPendingOperation();
    }
    final provider = BusyProviderCodec.requireStorageValue(account.provider);
    if (provider != BusyProvider.appleICloud &&
        provider != BusyProvider.nextcloud) {
      throw _invalidPendingOperation();
    }
    return _DavContext(
      account: account,
      collection: collection,
      provider: provider,
    );
  }

  Future<void> _validateScheduling(
    _DavContext context,
    String? baseline,
    String? candidate, {
    bool silent = false,
  }) async {
    if (context.provider != BusyProvider.nextcloud) return;
    (await NextcloudSchedulingPolicy.load(
      _database,
      context.collection,
    )).validateChange(
      baseline: baseline,
      candidate: candidate,
      silentImport: silent,
    );
  }

  Future<_DavObjectContext> _objectContext(
    String accountId,
    String collectionId,
    String objectId,
  ) async {
    final context = await _context(accountId, collectionId);
    final object = await (_database.select(
      _database.davObjects,
    )..where((row) => row.id.equals(objectId))).getSingleOrNull();
    if (object == null ||
        object.accountId != accountId ||
        object.collectionId != collectionId) {
      throw _invalidPendingOperation();
    }
    return _DavObjectContext(
      account: context.account,
      collection: context.collection,
      provider: context.provider,
      object: object,
    );
  }

  Future<PendingOp?> _activeObjectOperation(String objectId) {
    return (_database.select(_database.pendingOps)
          ..where(
            (row) =>
                row.davObjectId.equals(objectId) &
                row.state.isIn(const [
                  'pending',
                  'retry',
                  'in_progress',
                  'conflict',
                  'auth_blocked',
                  'permission_blocked',
                ]),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAtUtc)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<PendingOp?> _effectiveObjectOperation(String objectId) async {
    final operations = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.davObjectId.equals(objectId))).get();
    return effectiveDavPendingOperation(operations, objectId);
  }

  Future<PendingOp?> _editableCreate({
    required String accountId,
    required String collectionId,
    required String localProjectionId,
  }) {
    return (_database.select(_database.pendingOps)
          ..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.davCollectionId.equals(collectionId) &
                row.operationType.equals('dav.create') &
                row.state.isIn(const ['pending', 'failed']) &
                row.attemptCount.equals(0) &
                (row.eventId.equals(localProjectionId) |
                    row.taskId.equals(localProjectionId)),
          )
          ..limit(1))
        .getSingleOrNull()
        .then((operation) {
          if (operation == null || !isDavCreateLocallyEditable(operation)) {
            return null;
          }
          return operation;
        });
  }
}

/// Whether a local DAV create may be rewritten or cancelled without risking a
/// duplicate remote object.
///
/// A pending, never-attempted create is entirely local. A permanently failed
/// create is also safe only when the stored message proves that the server
/// returned an explicit rejection to the PUT itself (rather than a later GET
/// failing after the object may already have been created).
bool isDavCreateLocallyEditable(PendingOp operation) {
  if (operation.operationType != 'dav.create' || operation.attemptCount != 0) {
    return false;
  }
  if (operation.state == DavPendingState.pending.storageValue) {
    return true;
  }
  return operation.state == DavPendingState.failed.storageValue &&
      operation.retryClassification == 'permanent' &&
      operation.lastErrorMessage == _davMutationPutRejectedMessage;
}

typedef DavMutationServiceFactory =
    Future<DavConditionalMutationService> Function({
      required Account account,
      required DavCollection collection,
    });

typedef DavPendingOperationFailureHandler =
    Future<void> Function(PendingOp operation, DavException error);

final class DavReplaySummary {
  const DavReplaySummary({
    required this.appliedCount,
    required this.conflictCount,
    required this.retryCount,
    required this.mutatedCollectionIds,
    required this.affectedObjectIds,
    required this.paused,
  });

  final int appliedCount;
  final int conflictCount;
  final int retryCount;
  final Set<String> mutatedCollectionIds;
  final Set<String> affectedObjectIds;
  final bool paused;
}

final class DavPendingOperationsReplayer {
  DavPendingOperationsReplayer({
    required AppDatabase database,
    required String accountId,
    required DavMutationServiceFactory serviceFactory,
    DavObjectRepository? objectRepository,
    Future<void> Function(Set<String> objectIds)? rebuildNotifications,
    Future<void> Function(Set<String> collectionIds)? requestFollowUpSync,
    DavPendingOperationFailureHandler? onPermanentFailure,
    String Function()? idFactory,
    DateTime Function()? nowUtc,
    Random? random,
  }) : _database = database,
       _accountId = accountId,
       _serviceFactory = serviceFactory,
       _objectRepository =
           objectRepository ?? DavObjectRepository(database: database),
       _rebuildNotifications = rebuildNotifications,
       _requestFollowUpSync = requestFollowUpSync,
       _onPermanentFailure = onPermanentFailure,
       _idFactory = idFactory ?? const Uuid().v4,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _random = random ?? Random.secure();

  final AppDatabase _database;
  final String _accountId;
  final DavMutationServiceFactory _serviceFactory;
  final DavObjectRepository _objectRepository;
  final Future<void> Function(Set<String>)? _rebuildNotifications;
  final Future<void> Function(Set<String>)? _requestFollowUpSync;
  final DavPendingOperationFailureHandler? _onPermanentFailure;
  final String Function() _idFactory;
  final DateTime Function() _nowUtc;
  final Random _random;

  Future<DavReplaySummary> replayDueOperations() async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).getSingleOrNull();
    if (account == null || !_mayReplay(account.authState)) {
      return const DavReplaySummary(
        appliedCount: 0,
        conflictCount: 0,
        retryCount: 0,
        mutatedCollectionIds: {},
        affectedObjectIds: {},
        paused: true,
      );
    }
    final now = _nowUtc().toUtc();
    final query = _database.select(_database.pendingOps)
      ..where(
        (row) =>
            row.accountId.equals(_accountId) &
            row.state.isIn(const ['pending', 'retry', 'in_progress']) &
            (row.nextAttemptAtUtc.isNull() |
                row.nextAttemptAtUtc.isSmallerOrEqualValue(
                  now.toIso8601String(),
                )),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.createdAtUtc)]);
    final operations = _dependencyOrder(
      (await query.get()).where(isDavPendingOperation).toList(),
    );
    var applied = 0;
    var conflicts = 0;
    var retries = 0;
    var paused = false;
    final changedObjects = <String>{};
    final changedCollections = <String>{};

    for (final listed in operations) {
      final op = await _database.pendingOpsDao.getOp(listed.id);
      if (op == null || !isDavPendingOperation(op)) continue;
      if (op.dependsOnOpId != null && await _opExists(op.dependsOnOpId!)) {
        continue;
      }
      if (_copyConfirmationMissing(op)) {
        final error = const DavException(
          kind: DavErrorKind.protocol,
          code: 'DavEventCopyNotConfirmed',
          safeMessage:
              'The destination event was not confirmed, so the original was kept.',
        );
        await _markFailed(op, error);
        await _reportPermanentFailure(op, error);
        continue;
      }
      try {
        await _markInProgress(op);
        final result = await _replay(op);
        if (result.outcome == DavMutationOutcome.conflict) {
          await _recordConflict(op, result);
          conflicts += 1;
          continue;
        }
        final affected = await _commitSuccess(op, result);
        changedObjects.addAll(affected);
        changedCollections.add(op.davCollectionId!);
        if (op.destinationCollectionId != null) {
          changedCollections.add(op.destinationCollectionId!);
        }
        applied += 1;
      } on DavException catch (error) {
        switch (error.category) {
          case DavErrorCategory.davAuthRejected ||
              DavErrorCategory.davCredentialsRevoked:
            await _pauseForAuthentication(op, error);
            paused = true;
          case DavErrorCategory.davPermissionDenied ||
              DavErrorCategory.davReadOnly:
            await _pauseForPermission(op, error);
            paused = true;
          case DavErrorCategory.davResourceConflict ||
              DavErrorCategory.davUidConflict:
            await _recordExceptionConflict(op, error);
            conflicts += 1;
          case DavErrorCategory.davTransientNetwork ||
              DavErrorCategory.davServerUnavailable ||
              DavErrorCategory.davRateLimited:
            await _scheduleRetry(op, error);
            retries += 1;
          case _:
            await _markFailed(op, error);
            await _reportPermanentFailure(op, error);
        }
        if (paused) break;
      } on Object {
        await _scheduleRetry(
          op,
          const DavException(
            kind: DavErrorKind.network,
            code: 'DavPendingReplayUnexpectedFailure',
            safeMessage: 'The pending DAV operation could not be replayed.',
          ),
        );
        retries += 1;
      }
    }

    if (changedObjects.isNotEmpty && _rebuildNotifications != null) {
      await _rebuildNotifications(changedObjects);
    }
    if (changedCollections.isNotEmpty && _requestFollowUpSync != null) {
      await _requestFollowUpSync(changedCollections);
    }
    return DavReplaySummary(
      appliedCount: applied,
      conflictCount: conflicts,
      retryCount: retries,
      mutatedCollectionIds: Set.unmodifiable(changedCollections),
      affectedObjectIds: Set.unmodifiable(changedObjects),
      paused: paused,
    );
  }

  Future<DavMutationResult> _replay(PendingOp op) async {
    final collection = await _requiredCollection(op);
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).getSingle();
    final capabilities = collectionCapabilitiesFromStored(collection);
    final reconcileFirst = _davOperationNeedsReconciliation(op);
    final allowDeletedMoveSource =
        op.operationType == 'dav.move' && reconcileFirst;
    if (op.operationType == 'dav.move') {
      await _requiredMoveSource(
        op,
        collection,
        allowServerDeleted: allowDeletedMoveSource,
      );
    }
    if (account.provider == 'nextcloud') {
      final policy = await NextcloudSchedulingPolicy.load(
        _database,
        collection,
      );
      switch (op.operationType) {
        case 'dav.create':
          final created = _decodeCreate(op.requestJson);
          policy.validateChange(
            candidate: created.rawIcs,
            silentImport: created.suppressScheduling,
          );
        case 'dav.update':
          final baseline = _required(op.baselineRawIcs);
          policy.validateChange(
            baseline: baseline,
            candidate: _decodePatch(op).applyTo(baseline, nowUtc: _nowUtc()),
          );
        case 'dav.delete':
          policy.validateChange(baseline: _required(op.baselineRawIcs));
        case 'dav.move':
          final destination = await _requiredDestinationCollection(op);
          final baseline = _required(op.baselineRawIcs);
          policy.validateMoveTo(
            await NextcloudSchedulingPolicy.load(_database, destination),
            baseline,
            _decodeOptionalMovePatch(
                  op,
                )?.applyTo(baseline, nowUtc: _nowUtc()) ??
                baseline,
          );
      }
    }
    final service = await _serviceFactory(
      account: account,
      collection: collection,
    );
    final correlationId = _idFactory();
    final objectUri = op.operationType == 'dav.create'
        ? null
        : await _requiredObjectUri(
            op,
            collection,
            allowServerDeleted: allowDeletedMoveSource,
          );
    final destinationCollection = op.operationType == 'dav.move'
        ? await _requiredDestinationCollection(op)
        : null;
    return switch (op.operationType) {
      'dav.create' => service.create(
        collectionUri: Uri.parse(collection.requestUri),
        object: _decodeCreate(op.requestJson),
        capabilities: capabilities,
        correlationId: correlationId,
        reconcileFirst: reconcileFirst,
      ),
      'dav.update' => service.update(
        hrefKey: _required(op.davMemberHref),
        uri: objectUri!,
        baselineEtag: _required(op.baselineEtag),
        baselineRawIcs: _required(op.baselineRawIcs),
        patch: _decodePatch(op),
        capabilities: capabilities,
        correlationId: correlationId,
        reconcileFirst: reconcileFirst,
      ),
      'dav.delete' => service.delete(
        hrefKey: _required(op.davMemberHref),
        uri: objectUri!,
        baselineEtag: _required(op.baselineEtag),
        baselineRawIcs: _required(op.baselineRawIcs),
        isEvent: _deleteIsEvent(op),
        capabilities: capabilities,
        correlationId: correlationId,
      ),
      'dav.move' => service.move(
        sourceHrefKey: _required(op.davMemberHref),
        sourceUri: objectUri!,
        destinationHrefKey: _required(op.destinationMemberHref),
        destinationUri: _moveDestinationRequestUri(op, destinationCollection!),
        baselineEtag: _required(op.baselineEtag),
        baselineRawIcs: _required(op.baselineRawIcs),
        isEvent: _deleteIsEvent(op),
        sourceCapabilities: capabilities,
        destinationCapabilities: collectionCapabilitiesFromStored(
          destinationCollection,
        ),
        correlationId: correlationId,
        postMovePatch: _decodeOptionalMovePatch(op),
        reconcileFirst: reconcileFirst,
      ),
      _ => throw _invalidPendingOperation(),
    };
  }

  Future<Set<String>> _commitSuccess(
    PendingOp op,
    DavMutationResult result,
  ) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).getSingle();
    final provider = BusyProviderCodec.requireStorageValue(account.provider);
    final canonical = result.canonicalObject;
    if (op.operationType == 'dav.create' &&
        op.davObjectId != null &&
        canonical != null &&
        canonical.hrefKey != op.davMemberHref) {
      // A filename collision may allocate another member name, but it must
      // not give an imported recurrence set a second local object identity.
      await (_database.update(_database.davObjects)..where(
            (r) =>
                r.id.equals(op.davObjectId!) &
                r.accountId.equals(_accountId) &
                r.collectionId.equals(_required(op.davCollectionId)) &
                r.etag.isNull(),
          ))
          .write(
            DavObjectsCompanion(
              hrefKey: Value(canonical.hrefKey),
              requestUri: Value(canonical.requestUri.toString()),
            ),
          );
    }
    late final Set<String> affected;
    if (op.operationType == 'dav.move') {
      if (canonical == null) throw _invalidPendingOperation();
      final destination = await _requiredDestinationCollection(op);
      affected = await _objectRepository.commitConfirmedMove(
        accountId: _accountId,
        sourceCollectionId: _required(op.davCollectionId),
        destinationCollectionId: destination.id,
        provider: provider,
        sourceHrefKey: _required(op.davMemberHref),
        canonicalDestinationObject: DavPreparedObject.parse(
          hrefKey: canonical.hrefKey,
          requestUri: canonical.requestUri,
          etag: canonical.etag,
          contentType: canonical.contentType,
          rawIcsBody: _required(canonical.rawIcsBody),
          maximumResourceBytes:
              destination.maximumResourceSize ?? 16 * 1024 * 1024,
        ),
        completedAtUtc: _nowUtc(),
      );
    } else {
      affected = canonical == null
          ? await _objectRepository.commitConfirmedMutation(
              accountId: _accountId,
              collectionId: _required(op.davCollectionId),
              provider: provider,
              deletedHrefKey: _required(op.davMemberHref),
              completedAtUtc: _nowUtc(),
            )
          : await _objectRepository.commitConfirmedMutation(
              accountId: _accountId,
              collectionId: _required(op.davCollectionId),
              provider: provider,
              canonicalObject: DavPreparedObject.parse(
                hrefKey: canonical.hrefKey,
                requestUri: canonical.requestUri,
                etag: canonical.etag,
                contentType: canonical.contentType,
                rawIcsBody: _required(canonical.rawIcsBody),
                maximumResourceBytes:
                    (await _requiredCollection(op)).maximumResourceSize ??
                    16 * 1024 * 1024,
              ),
              completedAtUtc: _nowUtc(),
            );
    }
    await _confirmDependentCopyDeletes(op, canonical?.hrefKey);
    await _database.pendingOpsDao.deleteOp(op.id);
    if (op.operationType == 'dav.create') {
      final resolutions = LocationResolutionRepository(_database);
      if (op.eventId != null) {
        final old =
            await (_database.select(_database.calendarEvents)..where(
                  (r) =>
                      r.accountId.equals(_accountId) & r.id.equals(op.eventId!),
                ))
                .getSingleOrNull();
        if (old != null && old.icalUid != null) {
          final rows =
              await (_database.select(_database.calendarEvents)..where(
                    (r) =>
                        r.accountId.equals(_accountId) &
                        r.calendarSourceId.equals(old.calendarSourceId) &
                        r.icalUid.equals(old.icalUid!) &
                        r.davObjectId.isNotNull(),
                  ))
                  .get();
          final matches = rows
              .where(
                (row) => old.providerRecurringEventId == null
                    ? row.recurrenceIdKey == old.recurrenceIdKey
                    : row.occurrenceKey == old.occurrenceKey,
              )
              .toList();
          if (matches.length == 1) {
            final row = matches.single;
            await resolutions.transfer(
              LocationItemIdentity(
                kind: LocationItemKind.event,
                accountId: _accountId,
                sourceId: old.calendarSourceId,
                itemId: old.id,
              ),
              LocationItemIdentity(
                kind: LocationItemKind.event,
                accountId: _accountId,
                sourceId: row.calendarSourceId,
                itemId: row.id,
              ),
            );
          }
        }
      }
      if (op.taskId != null) {
        final old =
            await (_database.select(_database.tasks)..where(
                  (r) =>
                      r.accountId.equals(_accountId) &
                      r.id.equals(op.taskId!) &
                      r.davCollectionId.equals(op.davCollectionId!),
                ))
                .getSingleOrNull();
        if (old != null && old.icalUid != null) {
          final rows =
              await (_database.select(_database.tasks)..where(
                    (r) =>
                        r.accountId.equals(_accountId) &
                        r.taskListId.equals(old.taskListId) &
                        r.icalUid.equals(old.icalUid!) &
                        r.davObjectId.isNotNull(),
                  ))
                  .get();
          final matches = rows
              .where((row) => row.recurrenceIdKey == old.recurrenceIdKey)
              .toList();
          if (matches.length == 1) {
            final row = matches.single;
            await resolutions.transfer(
              LocationItemIdentity(
                kind: LocationItemKind.task,
                accountId: _accountId,
                sourceId: old.taskListId,
                itemId: old.id,
              ),
              LocationItemIdentity(
                kind: LocationItemKind.task,
                accountId: _accountId,
                sourceId: row.taskListId,
                itemId: row.id,
              ),
            );
          }
        }
      }
      if (op.eventId != null) {
        await (_database.delete(_database.calendarEvents)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.id.equals(op.eventId!) &
                  row.davObjectId.isNull(),
            ))
            .go();
      }
      if (op.taskId != null) {
        await (_database.delete(_database.tasks)..where(
              (row) =>
                  row.accountId.equals(_accountId) &
                  row.id.equals(op.taskId!) &
                  row.davObjectId.isNull(),
            ))
            .go();
      }
    }
    await _setAccountState(AccountConnectionState.connected);
    return affected;
  }

  Future<void> _confirmDependentCopyDeletes(
    PendingOp completedCreate,
    String? destinationHref,
  ) async {
    if (completedCreate.operationType != 'dav.create' ||
        completedCreate.eventId == null) {
      return;
    }
    final dependents = await (_database.select(
      _database.pendingOps,
    )..where((row) => row.dependsOnOpId.equals(completedCreate.id))).get();
    for (final dependent in dependents) {
      final request = _requestObject(dependent);
      if (request[calendarEventCopyConfirmationRequiredKey] != true) continue;
      request[calendarEventCopyConfirmedKey] = true;
      if (destinationHref != null) {
        request[calendarEventCopyDestinationEventIdKey] = destinationHref;
      }
      await (_database.update(_database.pendingOps)
            ..where((row) => row.id.equals(dependent.id)))
          .write(PendingOpsCompanion(requestJson: Value(jsonEncode(request))));
    }
  }

  Future<void> _recordConflict(PendingOp op, DavMutationResult result) async {
    final analysis = result.conflict;
    if (analysis == null) throw _invalidPendingOperation();
    await _insertConflict(
      op,
      code: analysis.conflictCode ?? 'DavResourceConflict',
      localCandidateRawIcs: result.localCandidateRawIcs ?? _localCandidate(op),
      remote: result.conflictRemoteObject,
    );
  }

  Future<void> _recordExceptionConflict(PendingOp op, DavException error) =>
      _insertConflict(
        op,
        code: error.code,
        localCandidateRawIcs: _localCandidate(op),
        remote: null,
      );

  Future<void> _insertConflict(
    PendingOp op, {
    required String code,
    required String localCandidateRawIcs,
    required DavFetchedMember? remote,
  }) async {
    final snapshotId = _idFactory();
    final now = _nowUtc().toUtc().toIso8601String();
    await _database.transaction(() async {
      await _database
          .into(_database.davConflictSnapshots)
          .insert(
            DavConflictSnapshotsCompanion.insert(
              id: snapshotId,
              accountId: _accountId,
              davCollectionId: Value(op.davCollectionId),
              davObjectId: Value(op.davObjectId),
              baselineEtag: Value(op.baselineEtag),
              baselineRawIcs: op.baselineRawIcs ?? '',
              localCandidateRawIcs: localCandidateRawIcs,
              remoteEtag: Value(remote?.etag),
              remoteRawIcs: remote?.rawIcsBody ?? '',
              conflictCode: code,
              createdAtUtc: now,
            ),
          );
      await (_database.update(
        _database.pendingOps,
      )..where((row) => row.id.equals(op.id))).write(
        PendingOpsCompanion(
          state: Value(DavPendingState.conflict.storageValue),
          conflictState: const Value('unresolved'),
          conflictSnapshotId: Value(snapshotId),
          retryClassification: const Value('manual_conflict_resolution'),
          nextAttemptAtUtc: const Value('9999-12-31T23:59:59.999Z'),
          lastErrorCode: Value(code),
          lastErrorMessage: const Value(
            'A remote edit conflicts with this change.',
          ),
          updatedAtUtc: Value(now),
        ),
      );
    });
  }

  Future<void> _pauseForAuthentication(PendingOp op, DavException error) async {
    await _setAccountState(AccountConnectionState.reauthenticationRequired);
    await _block(
      op,
      state: DavPendingState.authBlocked,
      classification: 'authentication',
      error: error,
    );
  }

  Future<void> _pauseForPermission(PendingOp op, DavException error) async {
    await _setAccountState(AccountConnectionState.permissionChanged);
    if (op.davCollectionId != null) {
      await (_database.update(
        _database.davCollections,
      )..where((row) => row.id.equals(op.davCollectionId!))).write(
        DavCollectionsCompanion(
          readOnly: const Value(true),
          updatedAtUtc: Value(_nowUtc().toUtc().toIso8601String()),
        ),
      );
    }
    await _block(
      op,
      state: DavPendingState.permissionBlocked,
      classification: 'permission',
      error: error,
    );
  }

  Future<void> _markFailed(PendingOp op, DavException error) => _block(
    op,
    state: DavPendingState.failed,
    classification:
        op.operationType == 'dav.move' &&
            (error.code == davPartialMoveFailureCode ||
                _davMoveNeedsReconciliation(op))
        ? davPartialMoveRetryClassification
        : 'permanent',
    error: error,
  );

  Future<void> _reportPermanentFailure(
    PendingOp operation,
    DavException error,
  ) async {
    try {
      await _onPermanentFailure?.call(operation, error);
    } on Object {
      // Reporting must not change the durable mutation outcome.
    }
  }

  Future<void> _block(
    PendingOp op, {
    required DavPendingState state,
    required String classification,
    required DavException error,
  }) {
    final now = _nowUtc().toUtc().toIso8601String();
    final preservePartialMove =
        error.code == davPartialMoveFailureCode ||
        _davMoveNeedsReconciliation(op);
    return (_database.update(
      _database.pendingOps,
    )..where((row) => row.id.equals(op.id))).write(
      PendingOpsCompanion(
        state: Value(state.storageValue),
        retryClassification: Value(classification),
        nextAttemptAtUtc: const Value('9999-12-31T23:59:59.999Z'),
        lastErrorCode: Value(error.code),
        lastErrorMessage: Value(error.safeMessage),
        requestJson: preservePartialMove
            ? Value(_markMoveMayHaveCompleted(op.requestJson))
            : const Value.absent(),
        updatedAtUtc: Value(now),
      ),
    );
  }

  Future<void> _scheduleRetry(PendingOp op, DavException error) async {
    final attempt = op.attemptCount + 1;
    final exponentialSeconds = min(3600, 1 << min(attempt, 11));
    final jitterMilliseconds = _random.nextInt(1000);
    final delay =
        error.retryAfter ??
        Duration(seconds: exponentialSeconds, milliseconds: jitterMilliseconds);
    final now = _nowUtc().toUtc();
    final preservePartialMove =
        error.code == davPartialMoveFailureCode ||
        _davMoveNeedsReconciliation(op);
    await (_database.update(
      _database.pendingOps,
    )..where((row) => row.id.equals(op.id))).write(
      PendingOpsCompanion(
        state: Value(DavPendingState.retry.storageValue),
        attemptCount: Value(attempt),
        nextAttemptAtUtc: Value(now.add(delay).toIso8601String()),
        retryClassification: const Value('transient'),
        lastErrorCode: Value(error.code),
        lastErrorMessage: Value(error.safeMessage),
        requestJson: preservePartialMove
            ? Value(_markMoveMayHaveCompleted(op.requestJson))
            : const Value.absent(),
        updatedAtUtc: Value(now.toIso8601String()),
      ),
    );
    await _setAccountState(AccountConnectionState.temporarilyUnavailable);
  }

  Future<void> _markInProgress(PendingOp op) {
    return (_database.update(
      _database.pendingOps,
    )..where((row) => row.id.equals(op.id))).write(
      PendingOpsCompanion(
        state: Value(DavPendingState.inProgress.storageValue),
        nextAttemptAtUtc: const Value(null),
        requestJson: op.operationType == 'dav.move'
            ? Value(_markMoveMayHaveCompleted(op.requestJson))
            : const Value.absent(),
        updatedAtUtc: Value(_nowUtc().toUtc().toIso8601String()),
      ),
    );
  }

  Future<void> _setAccountState(AccountConnectionState state) {
    return (_database.update(
      _database.accounts,
    )..where((row) => row.id.equals(_accountId))).write(
      AccountsCompanion(
        authState: Value(state.storageValue),
        updatedAtUtc: Value(_nowUtc().toUtc().toIso8601String()),
      ),
    );
  }

  Future<bool> _opExists(String id) async =>
      await _database.pendingOpsDao.getOp(id) != null;

  bool _copyConfirmationMissing(PendingOp op) {
    final request = _requestObject(op);
    return request[calendarEventCopyConfirmationRequiredKey] == true &&
        request[calendarEventCopyConfirmedKey] != true;
  }

  Map<String, Object?> _requestObject(PendingOp op) {
    final decoded = jsonDecode(op.requestJson);
    return decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{};
  }

  Future<DavCollection> _requiredCollection(PendingOp op) async {
    final id = _required(op.davCollectionId);
    final collection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (collection == null ||
        collection.accountId != _accountId ||
        collection.deleted ||
        collection.serverMissing) {
      throw const DavException(
        kind: DavErrorKind.notFound,
        code: 'DavCollectionRemoved',
        safeMessage: 'The DAV collection is no longer available.',
      );
    }
    return collection;
  }

  Future<DavCollection> _requiredDestinationCollection(PendingOp op) async {
    final id = _required(op.destinationCollectionId);
    final collection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (collection == null ||
        collection.accountId != _accountId ||
        collection.deleted ||
        collection.serverMissing ||
        collection.hrefKey != op.destinationCollectionHref) {
      throw const DavException(
        kind: DavErrorKind.notFound,
        code: 'DavMoveDestinationRemoved',
        safeMessage: 'The destination DAV collection is no longer available.',
      );
    }
    return collection;
  }

  Future<DavObject> _requiredObject(
    PendingOp op,
    DavCollection collection, {
    bool allowServerDeleted = false,
  }) async {
    final objectId = _required(op.davObjectId);
    final object = await (_database.select(
      _database.davObjects,
    )..where((row) => row.id.equals(objectId))).getSingleOrNull();
    if (object == null ||
        object.accountId != _accountId ||
        object.collectionId != collection.id ||
        object.hrefKey != op.davMemberHref ||
        (object.serverDeleted && !allowServerDeleted)) {
      throw _invalidPendingOperation();
    }
    return object;
  }

  Future<DavObject> _requiredMoveSource(
    PendingOp op,
    DavCollection collection, {
    required bool allowServerDeleted,
  }) async {
    if (op.operationType != 'dav.move') throw _invalidPendingOperation();
    final object = await _requiredObject(
      op,
      collection,
      allowServerDeleted: allowServerDeleted,
    );
    final baseline = IcalSemanticDocument.parse(_required(op.baselineRawIcs));
    final expectedComponentType = _deleteIsEvent(op) ? 'VEVENT' : 'VTODO';
    if (baseline.primaryUid == null ||
        baseline.components.isEmpty ||
        baseline.components.any(
          (component) =>
              component.uid != baseline.primaryUid ||
              component.componentType != expectedComponentType,
        ) ||
        object.primaryUid != baseline.primaryUid ||
        object.dominantComponentType != expectedComponentType) {
      throw _invalidPendingOperation();
    }
    return object;
  }

  Future<Uri> _requiredObjectUri(
    PendingOp op,
    DavCollection collection, {
    bool allowServerDeleted = false,
  }) async {
    final href = _required(op.davMemberHref);
    final collectionHref = _required(op.davCollectionHref);
    if (!href.startsWith(collectionHref)) throw _invalidPendingOperation();
    final object = await _requiredObject(
      op,
      collection,
      allowServerDeleted: allowServerDeleted,
    );
    // The canonical request URI is persisted with the raw baseline and avoids
    // reconstructing a potentially path-prefixed Nextcloud installation URL.
    final uri = Uri.tryParse(object.requestUri);
    final collectionUri = Uri.tryParse(collection.requestUri);
    if (uri == null ||
        collectionUri == null ||
        uri.scheme != collectionUri.scheme ||
        uri.host != collectionUri.host ||
        uri.port != collectionUri.port ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != href) {
      throw _invalidPendingOperation();
    }
    return uri;
  }

  Uri _moveDestinationRequestUri(PendingOp op, DavCollection destination) {
    try {
      final decoded = jsonDecode(op.requestJson);
      if (decoded is! Map) throw _invalidPendingOperation();
      final raw = decoded['destinationRequestUri'];
      if (raw is! String || raw.isEmpty) throw _invalidPendingOperation();
      final uri = Uri.parse(raw);
      final collectionUri = Uri.parse(destination.requestUri);
      final href = _required(op.destinationMemberHref);
      if (uri.scheme != collectionUri.scheme ||
          uri.host != collectionUri.host ||
          uri.port != collectionUri.port ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          uri.path != href ||
          !_hrefIsDirectMember(href, destination.hrefKey)) {
        throw _invalidPendingOperation();
      }
      return uri;
    } on DavException {
      rethrow;
    } on Object {
      throw _invalidPendingOperation();
    }
  }

  String _localCandidate(PendingOp op) {
    if (op.operationType == 'dav.create') {
      return _decodeCreate(op.requestJson).rawIcs;
    }
    if (op.operationType == 'dav.update') {
      return _decodePatch(
        op,
      ).applyTo(_required(op.baselineRawIcs), nowUtc: _nowUtc().toUtc());
    }
    if (op.operationType == 'dav.move') {
      return _moveCandidateRaw(op, _nowUtc().toUtc());
    }
    return op.baselineRawIcs ?? '';
  }
}

class _DavContext {
  const _DavContext({
    required this.account,
    required this.collection,
    required this.provider,
  });

  final Account account;
  final DavCollection collection;
  final BusyProvider provider;
}

final class _DavObjectContext extends _DavContext {
  const _DavObjectContext({
    required super.account,
    required super.collection,
    required super.provider,
    required this.object,
  });

  final DavObject object;
}

void _validateTaskTemporalRange(IcalSemanticDocument document) {
  IcalTimeZoneResolver? resolver;
  for (final component in document.components) {
    if (component.componentType != 'VTODO') {
      continue;
    }
    final start = component.start;
    final due = component.due;
    if (start == null || due == null) {
      continue;
    }
    if (start.isDate != due.isDate) {
      throw const DavException(
        kind: DavErrorKind.invalidCalendarData,
        code: 'DavTaskTemporalTypeMismatch',
        safeMessage:
            'Task start and due values must both be all-day or both include '
            'a time.',
      );
    }
    final effectiveResolver = resolver ??= IcalTimeZoneResolver.fromDocument(
      document,
    );
    if (effectiveResolver.toUtc(due).isBefore(effectiveResolver.toUtc(start))) {
      throw const DavException(
        kind: DavErrorKind.invalidCalendarData,
        code: 'DavTaskDueBeforeStart',
        safeMessage: 'A task cannot be due before it starts.',
      );
    }
  }
}

DavMutationPatch? _coalesceUnsentUpdate(
  PendingOp existing,
  DavMutationPatch patch, {
  required String baselineEtag,
  required DateTime nowUtc,
}) {
  if (existing.operationType != 'dav.update' ||
      existing.state != DavPendingState.pending.storageValue ||
      existing.attemptCount != 0 ||
      existing.baselineEtag != baselineEtag ||
      existing.mutationPatchJson == null) {
    return null;
  }
  final previous = DavMutationPatch.fromJsonString(existing.mutationPatchJson!);
  if (!_sameTarget(previous.target, patch.target) ||
      (previous.scope != patch.scope &&
          !(previous.scope == DavMutationScope.occurrence &&
              patch.scope == DavMutationScope.recurrenceException))) {
    if (previous.target.uid != patch.target.uid ||
        previous.target.componentType != patch.target.componentType ||
        existing.baselineRawIcs == null) {
      return null;
    }
    // Multiple offline occurrence edits still lock and replay one backing
    // resource. Materialize each delta against the effective local candidate.
    final beforeRaw = previous.applyTo(
      existing.baselineRawIcs!,
      nowUtc: nowUtc,
    );
    final before = IcalSemanticDocument.parse(beforeRaw);
    final after = IcalSemanticDocument.parse(
      patch.applyTo(beforeRaw, nowUtc: nowUtc),
    );
    String key(IcalSemanticComponent component) =>
        '${component.componentType}\u0000${component.uid}\u0000${component.recurrenceIdKey ?? ''}';
    final beforeByKey = {for (final c in before.components) key(c): c};
    final afterByKey = {for (final c in after.components) key(c): c};
    final changes = <DavPatchOperation>[];
    for (final identity in {...beforeByKey.keys, ...afterByKey.keys}) {
      final old = beforeByKey[identity], updated = afterByKey[identity];
      if (old?.semanticHash == updated?.semanticHash) continue;
      if (old != null) {
        changes.add(
          DavPatchOperation.removeComponent(
            componentKey: IcalComponentKey(
              componentType: old.componentType,
              uid: old.uid!,
              recurrenceIdKey: old.recurrenceIdKey,
            ),
          ),
        );
      }
      if (updated != null) {
        changes.add(DavPatchOperation.addComponent(updated.documentComponent));
      }
    }
    return DavMutationPatch(
      target: previous.target,
      scope: DavMutationScope.object,
      operations: [...previous.operations, ...changes],
    );
  }
  final sameScope = previous.scope == patch.scope;
  final editsLocallyAddedOccurrence =
      previous.scope == DavMutationScope.occurrence &&
      patch.scope == DavMutationScope.recurrenceException &&
      previous.operations.any(
        (operation) => operation.type == DavPatchOperationType.addComponent,
      );
  if (!sameScope && !editsLocallyAddedOccurrence) return null;
  return DavMutationPatch(
    target: patch.target,
    // A detached exception that has not been sent is still one occurrence
    // mutation. Folding its subsequent property edits into that add operation
    // does not merge independent recurrence scopes.
    scope: previous.scope,
    operations: [...previous.operations, ...patch.operations],
  );
}

bool _sameTarget(IcalComponentKey left, IcalComponentKey right) =>
    left.componentType == right.componentType &&
    left.uid == right.uid &&
    left.recurrenceIdKey == right.recurrenceIdKey;

bool _containsTarget(IcalSemanticDocument document, IcalComponentKey target) =>
    document.components.any(
      (component) =>
          component.componentType == target.componentType.toUpperCase() &&
          component.uid == target.uid &&
          component.recurrenceIdKey == target.recurrenceIdKey,
    );

DavMutationPatch _decodePatch(PendingOp op) {
  if (op.mutationPatchSchemaVersion != davMutationPatchSchemaVersion ||
      op.mutationPatchJson == null) {
    throw _invalidPendingOperation();
  }
  final patch = DavMutationPatch.fromJsonString(op.mutationPatchJson!);
  if (op.targetComponentKey != _componentKeyJson(patch.target) ||
      op.mutationScope != patch.scope.name) {
    throw _invalidPendingOperation();
  }
  return patch;
}

DavMutationPatch? _decodeOptionalMovePatch(PendingOp op) {
  if (op.operationType != 'dav.move') throw _invalidPendingOperation();
  if (op.mutationPatchJson == null) return null;
  return _decodePatch(op);
}

String _moveCandidateRaw(PendingOp op, DateTime nowUtc) {
  final baseline = _required(op.baselineRawIcs);
  final patch = _decodeOptionalMovePatch(op);
  return patch == null
      ? baseline
      : patch.applyTo(baseline, nowUtc: nowUtc.toUtc());
}

bool _requestMarksMoveMayHaveCompleted(String source) {
  try {
    final decoded = jsonDecode(source);
    return decoded is Map &&
        decoded[_davMoveMayHaveCompletedRequestKey] == true;
  } on Object {
    return false;
  }
}

String _markMoveMayHaveCompleted(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) return source;
    return jsonEncode({...decoded, _davMoveMayHaveCompletedRequestKey: true});
  } on Object {
    return source;
  }
}

DavNewObject _decodeCreate(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw _invalidPendingOperation();
    final json = decoded.cast<String, Object?>();
    if (json['schemaVersion'] != davPendingOperationSchemaVersion) {
      throw _invalidPendingOperation();
    }
    final uid = _jsonString(json, 'uid');
    final rawIcs = _jsonString(json, 'rawIcs');
    final componentType = _jsonString(json, 'componentType').toUpperCase();
    if (json.containsKey('suppressScheduling') &&
        json['suppressScheduling'] is! bool) {
      throw _invalidPendingOperation();
    }
    final semantic = IcalSemanticDocument.parse(rawIcs);
    if (semantic.primaryUid != uid ||
        semantic.components.any(
          (component) => component.componentType != componentType,
        )) {
      throw _invalidPendingOperation();
    }
    return DavNewObject(
      uid: uid,
      initialMemberName: _jsonString(json, 'initialMemberName'),
      rawIcs: rawIcs,
      componentType: componentType,
      suppressScheduling: json['suppressScheduling'] == true,
    );
  } on DavException {
    rethrow;
  } on Object {
    throw _invalidPendingOperation();
  }
}

bool _deleteIsEvent(PendingOp op) {
  try {
    final decoded = jsonDecode(op.requestJson);
    if (decoded is! Map || decoded['isEvent'] is! bool) {
      throw _invalidPendingOperation();
    }
    return decoded['isEvent']! as bool;
  } on DavException {
    rethrow;
  } on Object {
    throw _invalidPendingOperation();
  }
}

String _componentKeyJson(IcalComponentKey key) => jsonEncode({
  'componentType': key.componentType.toUpperCase(),
  'uid': key.uid,
  if (key.recurrenceIdKey != null) 'recurrenceIdKey': key.recurrenceIdKey,
});

String _entityType(String componentType) =>
    _componentIsEvent(componentType) ? 'event' : 'task';

bool _componentIsEvent(String componentType) =>
    switch (componentType.toUpperCase()) {
      'VEVENT' => true,
      'VTODO' => false,
      _ => throw _invalidPendingOperation(),
    };

List<PendingOp> _dependencyOrder(List<PendingOp> source) {
  final remaining = [...source];
  final ordered = <PendingOp>[];
  while (remaining.isNotEmpty) {
    final remainingIds = {for (final operation in remaining) operation.id};
    final index = remaining.indexWhere(
      (operation) =>
          operation.dependsOnOpId == null ||
          !remainingIds.contains(operation.dependsOnOpId),
    );
    if (index < 0) {
      // A corrupt cycle remains blocked by the durable dependency checks and
      // will not be sent out of order.
      ordered.addAll(remaining);
      break;
    }
    ordered.add(remaining.removeAt(index));
  }
  return ordered;
}

bool _mayReplay(String storageState) {
  final state = AccountConnectionStateCodec.parse(storageState);
  return state == AccountConnectionState.connected ||
      state == AccountConnectionState.temporarilyUnavailable;
}

String _required(String? value) {
  if (value == null || value.isEmpty) throw _invalidPendingOperation();
  return value;
}

String _jsonString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw _invalidPendingOperation();
  return value;
}

Uri _memberUri(Uri collectionUri, String memberName) {
  if (!RegExp(r'^[A-Za-z0-9-]+[.]ics$').hasMatch(memberName)) {
    throw _invalidPendingOperation();
  }
  final base = collectionUri.path.endsWith('/')
      ? collectionUri
      : collectionUri.replace(path: '${collectionUri.path}/');
  return base.resolve(memberName);
}

Uri _moveDestinationUri(Uri sourceUri, Uri destinationCollectionUri) {
  if (sourceUri.scheme != destinationCollectionUri.scheme ||
      sourceUri.host != destinationCollectionUri.host ||
      sourceUri.port != destinationCollectionUri.port ||
      sourceUri.userInfo.isNotEmpty ||
      destinationCollectionUri.userInfo.isNotEmpty ||
      sourceUri.hasQuery ||
      destinationCollectionUri.hasQuery ||
      sourceUri.hasFragment ||
      destinationCollectionUri.hasFragment ||
      sourceUri.pathSegments.isEmpty) {
    throw _invalidPendingOperation();
  }
  final memberName = sourceUri.pathSegments.last;
  if (memberName.isEmpty ||
      memberName == '.' ||
      memberName == '..' ||
      memberName.contains('/')) {
    throw _invalidPendingOperation();
  }
  final base = destinationCollectionUri.toString().endsWith('/')
      ? destinationCollectionUri.toString()
      : '${destinationCollectionUri.toString()}/';
  final destination = Uri.parse('$base${Uri.encodeComponent(memberName)}');
  if (!_hrefIsDirectMember(destination.path, destinationCollectionUri.path)) {
    throw _invalidPendingOperation();
  }
  return destination;
}

bool _hrefIsDirectMember(String memberHref, String collectionHref) {
  final prefix = collectionHref.endsWith('/')
      ? collectionHref
      : '$collectionHref/';
  if (!memberHref.startsWith(prefix)) return false;
  final relative = memberHref.substring(prefix.length);
  return relative.isNotEmpty && !relative.contains('/');
}

DavException _invalidPendingOperation() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'DavPendingOperationInvalid',
  safeMessage: 'A pending DAV operation was invalid.',
);

DavException _operationAlreadyPending() => const DavException(
  kind: DavErrorKind.conflict,
  code: 'DavPendingMutationAlreadyExists',
  safeMessage: 'This DAV object already has a pending change.',
);

DavException _permissionError() => const DavException(
  kind: DavErrorKind.authorization,
  code: 'DavReadOnly',
  safeMessage: 'This DAV collection does not allow that change.',
);
