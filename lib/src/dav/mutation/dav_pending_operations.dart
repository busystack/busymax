import 'dart:convert';
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
import '../sync/dav_collection_remote_client.dart';
import 'dav_conditional_mutation_service.dart';
import 'dav_mutation_patch.dart';

const davPendingOperationSchemaVersion = 1;

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
    String? dependsOnOperationId,
  }) async {
    final context = await _context(accountId, collectionId);
    final capabilities = collectionCapabilitiesFromStored(context.collection);
    final isEvent = _componentIsEvent(object.componentType);
    final canCreate = isEvent
        ? capabilities.canCreateEvent
        : capabilities.canCreateTask;
    if (!canCreate) throw _permissionError();
    final memberUri = _memberUri(
      Uri.parse(context.collection.requestUri),
      object.initialMemberName,
    );
    final parsed = IcalSemanticDocument.parse(object.rawIcs);
    if (parsed.primaryUid != object.uid ||
        parsed.components.every(
          (component) => component.componentType != object.componentType,
        )) {
      throw _invalidPendingOperation();
    }
    _validateTaskTemporalRange(parsed);
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
      );
      if (coalesced != null) {
        // Coalesced operations are always replayed against the original
        // server-confirmed baseline. Validate that exact durable candidate.
        final candidate = coalesced.applyTo(
          _required(existing.baselineRawIcs),
          nowUtc: nowUtc,
        );
        _validateTaskTemporalRange(IcalSemanticDocument.parse(candidate));
        await (_database.update(
          _database.pendingOps,
        )..where((row) => row.id.equals(existing.id))).write(
          PendingOpsCompanion(
            mutationPatchJson: Value(coalesced.toJsonString()),
            mutationPatchSchemaVersion: Value(coalesced.schemaVersion),
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
    return true;
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
      (await query.get()).where(_isDavOperation).toList(),
    );
    var applied = 0;
    var conflicts = 0;
    var retries = 0;
    var paused = false;
    final changedObjects = <String>{};
    final changedCollections = <String>{};

    for (final listed in operations) {
      final op = await _database.pendingOpsDao.getOp(listed.id);
      if (op == null || !_isDavOperation(op)) continue;
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
    final service = await _serviceFactory(
      account: account,
      collection: collection,
    );
    final correlationId = _idFactory();
    final objectUri = op.operationType == 'dav.create'
        ? null
        : await _requiredObjectUri(op, collection);
    final destinationCollection = op.operationType == 'dav.move'
        ? await _requiredDestinationCollection(op)
        : null;
    final sourceObject = op.operationType == 'dav.move'
        ? await _requiredObject(op, collection)
        : null;
    return switch (op.operationType) {
      'dav.create' => service.create(
        collectionUri: Uri.parse(collection.requestUri),
        object: _decodeCreate(op.requestJson),
        capabilities: capabilities,
        correlationId: correlationId,
      ),
      'dav.update' => service.update(
        hrefKey: _required(op.davMemberHref),
        uri: objectUri!,
        baselineEtag: _required(op.baselineEtag),
        baselineRawIcs: _required(op.baselineRawIcs),
        patch: _decodePatch(op),
        capabilities: capabilities,
        correlationId: correlationId,
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
        baselineEtag: _required(sourceObject!.etag),
        baselineRawIcs: sourceObject.rawIcsBody,
        isEvent: _deleteIsEvent(op),
        sourceCapabilities: capabilities,
        destinationCapabilities: collectionCapabilitiesFromStored(
          destinationCollection,
        ),
        correlationId: correlationId,
        postMovePatch: _decodeOptionalMovePatch(op),
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
    classification: 'permanent',
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
    return (_database.update(
      _database.pendingOps,
    )..where((row) => row.id.equals(op.id))).write(
      PendingOpsCompanion(
        state: Value(state.storageValue),
        retryClassification: Value(classification),
        nextAttemptAtUtc: const Value('9999-12-31T23:59:59.999Z'),
        lastErrorCode: Value(error.code),
        lastErrorMessage: Value(error.safeMessage),
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
    DavCollection collection,
  ) async {
    final objectId = _required(op.davObjectId);
    final object = await (_database.select(
      _database.davObjects,
    )..where((row) => row.id.equals(objectId))).getSingleOrNull();
    if (object == null ||
        object.accountId != _accountId ||
        object.collectionId != collection.id ||
        object.hrefKey != op.davMemberHref ||
        object.serverDeleted) {
      throw _invalidPendingOperation();
    }
    return object;
  }

  Future<Uri> _requiredObjectUri(PendingOp op, DavCollection collection) async {
    final href = _required(op.davMemberHref);
    final collectionHref = _required(op.davCollectionHref);
    if (!href.startsWith(collectionHref)) throw _invalidPendingOperation();
    final object = await _requiredObject(op, collection);
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
}) {
  if (existing.operationType != 'dav.update' ||
      existing.state != DavPendingState.pending.storageValue ||
      existing.attemptCount != 0 ||
      existing.baselineEtag != baselineEtag ||
      existing.mutationPatchJson == null) {
    return null;
  }
  final previous = DavMutationPatch.fromJsonString(existing.mutationPatchJson!);
  if (!_sameTarget(previous.target, patch.target)) {
    return null;
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
    final semantic = IcalSemanticDocument.parse(rawIcs);
    if (semantic.primaryUid != uid ||
        semantic.components.every(
          (component) => component.componentType != componentType,
        )) {
      throw _invalidPendingOperation();
    }
    return DavNewObject(
      uid: uid,
      initialMemberName: _jsonString(json, 'initialMemberName'),
      rawIcs: rawIcs,
      componentType: componentType,
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

bool _isDavOperation(PendingOp op) =>
    op.operationType == 'dav.create' ||
    op.operationType == 'dav.update' ||
    op.operationType == 'dav.delete' ||
    op.operationType == 'dav.move';

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
