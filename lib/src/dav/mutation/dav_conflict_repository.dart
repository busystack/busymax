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
    String Function()? idFactory,
    DateTime Function()? nowUtc,
  }) : _database = database,
       _objectRepository =
           objectRepository ?? DavObjectRepository(database: database),
       _pendingQueue =
           pendingQueue ?? DavPendingOperationQueue(database: database),
       _idFactory = idFactory ?? const Uuid().v4,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final DavObjectRepository _objectRepository;
  final DavPendingOperationQueue _pendingQueue;
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
    await _adoptRemote(context, DavConflictResolution.keepServer);
  }

  Future<void> _adoptRemote(
    _ResolutionContext context,
    DavConflictResolution resolution,
  ) async {
    final snapshot = context.snapshot;
    final object = context.object;
    if (object == null ||
        snapshot.remoteEtag == null ||
        snapshot.remoteRawIcs.isEmpty) {
      throw _resolutionUnavailable();
    }
    final provider = BusyProviderCodec.requireStorageValue(
      context.account.provider,
    );
    await _objectRepository.commitConfirmedMutation(
      accountId: snapshot.accountId,
      collectionId: context.collection.id,
      provider: provider,
      canonicalObject: DavPreparedObject.parse(
        hrefKey: object.hrefKey,
        requestUri: Uri.parse(object.requestUri),
        etag: snapshot.remoteEtag,
        contentType: object.contentType,
        rawIcsBody: snapshot.remoteRawIcs,
        maximumResourceBytes:
            context.collection.maximumResourceSize ?? 16 * 1024 * 1024,
      ),
      completedAtUtc: _nowUtc(),
    );
    await _finish(context, resolution);
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
    if (context.snapshot.remoteEtag != null &&
        context.snapshot.remoteRawIcs.isNotEmpty &&
        context.object != null) {
      await _adoptRemote(context, DavConflictResolution.duplicateLocal);
      return;
    }
    await _finish(context, DavConflictResolution.duplicateLocal);
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
    canKeepServer:
        snapshot.remoteEtag != null && snapshot.remoteRawIcs.isNotEmpty,
    canReapplyLocal:
        operation?.operationType == 'dav.update' &&
        snapshot.remoteEtag != null &&
        snapshot.remoteRawIcs.isNotEmpty &&
        patch != null,
    canDuplicate: snapshot.localCandidateRawIcs.isNotEmpty,
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
