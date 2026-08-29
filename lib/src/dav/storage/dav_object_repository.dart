import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../providers/busy_provider.dart';
import '../dav_errors.dart';
import '../ical/ical_document.dart';
import '../ical/ical_recurrence.dart';
import '../ical/ical_semantics.dart';
import '../ical/ical_timezone.dart';

const davRawObjectParserVersion = 1;
const davProjectionVersion = 2;
const davSyncStateSchemaVersion = 1;

final class DavPreparedObject {
  const DavPreparedObject._({
    required this.hrefKey,
    required this.requestUri,
    required this.etag,
    required this.contentType,
    required this.rawIcsBody,
    required this.rawBodyHash,
    required this.semantic,
  });

  factory DavPreparedObject.parse({
    required String hrefKey,
    required Uri requestUri,
    required String? etag,
    required String? contentType,
    required String rawIcsBody,
    int maximumResourceBytes = 16 * 1024 * 1024,
  }) {
    final trimmedHref = hrefKey.trim();
    if (trimmedHref.isEmpty ||
        !trimmedHref.startsWith('/') ||
        requestUri.userInfo.isNotEmpty ||
        requestUri.hasFragment ||
        requestUri.hasQuery) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavInvalidObjectIdentity',
        safeMessage: 'A DAV object had an invalid resource identity.',
      );
    }
    final bytes = utf8.encode(rawIcsBody);
    if (bytes.length > maximumResourceBytes) {
      throw const DavException(
        kind: DavErrorKind.maximumResourceSize,
        code: 'DavCalendarObjectTooLarge',
        safeMessage: 'A calendar object exceeded the configured size limit.',
      );
    }
    return DavPreparedObject._(
      hrefKey: trimmedHref,
      requestUri: requestUri,
      etag: etag,
      contentType: contentType,
      rawIcsBody: rawIcsBody,
      rawBodyHash: sha256.convert(bytes).toString(),
      semantic: IcalSemanticDocument.parse(rawIcsBody),
    );
  }

  final String hrefKey;
  final Uri requestUri;
  final String? etag;
  final String? contentType;
  final String rawIcsBody;
  final String rawBodyHash;
  final IcalSemanticDocument semantic;
}

final class DavCollectionCommit {
  DavCollectionCommit({
    required this.accountId,
    required this.collectionId,
    required this.provider,
    required this.objects,
    required Set<String> deletedHrefKeys,
    required this.completeMembership,
    required Set<String> membershipHrefKeys,
    required this.finalCursorKind,
    required this.finalCursorValue,
    required this.baselineGeneration,
    required this.completedAtUtc,
    required this.projectionRangeStartUtc,
    required this.projectionRangeEndUtc,
    this.forceReprojection = false,
  }) : deletedHrefKeys = Set.unmodifiable(deletedHrefKeys),
       membershipHrefKeys = Set.unmodifiable(membershipHrefKeys) {
    final objectKeys = objects.map((object) => object.hrefKey).toList();
    if (objectKeys.toSet().length != objectKeys.length ||
        objectKeys.any(this.deletedHrefKeys.contains) ||
        (completeMembership &&
            objectKeys.any((key) => !this.membershipHrefKeys.contains(key)))) {
      throw ArgumentError('The DAV collection commit is internally invalid.');
    }
    if (finalCursorValue.isEmpty || baselineGeneration < 0) {
      throw ArgumentError('The DAV cursor state is invalid.');
    }
  }

  final String accountId;
  final String collectionId;
  final BusyProvider provider;
  final List<DavPreparedObject> objects;
  final Set<String> deletedHrefKeys;
  final bool completeMembership;
  final Set<String> membershipHrefKeys;
  final String finalCursorKind;
  final String finalCursorValue;
  final int baselineGeneration;
  final DateTime completedAtUtc;
  final DateTime projectionRangeStartUtc;
  final DateTime projectionRangeEndUtc;
  final bool forceReprojection;
}

final class DavObjectRepository {
  DavObjectRepository({
    required AppDatabase database,
    String Function()? idFactory,
    IcalRecurrenceExpander? recurrenceExpander,
  }) : _database = database,
       _idFactory = idFactory ?? const Uuid().v4,
       _recurrenceExpander = recurrenceExpander ?? IcalRecurrenceExpander();

  final AppDatabase _database;
  final String Function() _idFactory;
  final IcalRecurrenceExpander _recurrenceExpander;

  Future<DavObject?> objectByHref(String collectionId, String hrefKey) {
    return (_database.select(_database.davObjects)..where(
          (row) =>
              row.collectionId.equals(collectionId) &
              row.hrefKey.equals(hrefKey),
        ))
        .getSingleOrNull();
  }

  Future<List<DavObject>> liveObjects(String collectionId) {
    return (_database.select(_database.davObjects)..where(
          (row) =>
              row.collectionId.equals(collectionId) &
              row.serverDeleted.equals(false),
        ))
        .get();
  }

  Future<SyncCursor?> cursor(String collectionId) {
    return (_database.select(_database.syncCursors)..where(
          (row) =>
              row.davCollectionId.equals(collectionId) &
              row.transport.equals('caldav') &
              row.syncScopeKind.equals('collection'),
        ))
        .getSingleOrNull();
  }

  Future<int> nextBaselineGeneration(String collectionId) async {
    final current = await cursor(collectionId);
    return (current?.baselineGeneration ?? 0) + 1;
  }

  Future<void> markSyncStarted({
    required String accountId,
    required String collectionId,
    required BusyProvider provider,
    required int generation,
  }) async {
    final existing = await cursor(collectionId);
    await _database
        .into(_database.syncCursors)
        .insertOnConflictUpdate(
          SyncCursorsCompanion.insert(
            id: existing?.id ?? 'dav-sync-$collectionId',
            accountId: accountId,
            provider: provider.storageValue,
            transport: 'caldav',
            syncScopeKind: 'collection',
            davCollectionId: Value(collectionId),
            cursorKind: existing?.cursorKind ?? 'snapshot_generation',
            cursorValue: existing?.cursorValue ?? '0',
            baselineGeneration: Value(existing?.baselineGeneration ?? 0),
            inProgressCursor: const Value(null),
            inProgressGeneration: Value(generation),
            lastCompleteSyncAt: Value(existing?.lastCompleteSyncAt),
            lastFailureCode: const Value(null),
            stateSchemaVersion: const Value(davSyncStateSchemaVersion),
          ),
        );
  }

  Future<void> markSyncFailed({
    required String collectionId,
    required String errorCode,
  }) async {
    await (_database.update(_database.syncCursors)..where(
          (row) =>
              row.davCollectionId.equals(collectionId) &
              row.transport.equals('caldav'),
        ))
        .write(
          SyncCursorsCompanion(
            inProgressCursor: const Value(null),
            inProgressGeneration: const Value(null),
            lastFailureCode: Value(errorCode),
          ),
        );
  }

  /// Rebuilds the bounded occurrence/task projections entirely from the raw
  /// local baseline. Advancing the UI horizon never requires a server-wide
  /// download and does not alter the durable transport cursor.
  Future<Set<String>> reprojectCollectionFromStored({
    required String accountId,
    required String collectionId,
    required BusyProvider provider,
    required DateTime projectionRangeStartUtc,
    required DateTime projectionRangeEndUtc,
    DateTime? completedAtUtc,
  }) async {
    final collection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(collectionId))).getSingle();
    if (collection.accountId != accountId) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavCollectionAccountMismatch',
        safeMessage: 'The DAV collection did not belong to the account.',
      );
    }
    final objects = await liveObjects(collectionId);
    final parsed = <String, IcalSemanticDocument>{};
    for (final object in objects) {
      parsed[object.id] = IcalSemanticDocument.parse(object.rawIcsBody);
    }
    final cursorState = await cursor(collectionId);
    final now = (completedAtUtc ?? DateTime.now()).toUtc();
    return _database.transaction(() async {
      final affected = <String>{};
      for (final object in objects) {
        if (await _hasActivePendingOperation(object.id)) continue;
        final componentIds = await _replaceComponentIndex(
          object.id,
          parsed[object.id]!,
        );
        await _replaceProjections(
          commit: DavCollectionCommit(
            accountId: accountId,
            collectionId: collectionId,
            provider: provider,
            objects: const [],
            deletedHrefKeys: const {},
            completeMembership: false,
            membershipHrefKeys: const {},
            finalCursorKind: cursorState?.cursorKind ?? 'snapshot_generation',
            finalCursorValue: cursorState?.cursorValue ?? '0',
            baselineGeneration: cursorState?.baselineGeneration ?? 0,
            completedAtUtc: now,
            projectionRangeStartUtc: projectionRangeStartUtc,
            projectionRangeEndUtc: projectionRangeEndUtc,
          ),
          collection: collection,
          objectId: object.id,
          etag: object.etag,
          semantic: parsed[object.id]!,
          componentIds: componentIds,
        );
        affected.add(object.id);
      }
      await _resolveProjectedTaskParents(collectionId);
      if (cursorState != null) {
        await (_database.update(
          _database.syncCursors,
        )..where((row) => row.id.equals(cursorState.id))).write(
          SyncCursorsCompanion(
            stateJson: Value(
              jsonEncode({
                'projectionRangeStartUtc': projectionRangeStartUtc
                    .toUtc()
                    .toIso8601String(),
                'projectionRangeEndUtc': projectionRangeEndUtc
                    .toUtc()
                    .toIso8601String(),
                'projectionVersion': davProjectionVersion,
              }),
            ),
          ),
        );
      }
      await (_database.update(
        _database.davCollections,
      )..where((row) => row.id.equals(collectionId))).write(
        DavCollectionsCompanion(
          projectionVersion: const Value(davProjectionVersion),
          updatedAtUtc: Value(now.toIso8601String()),
        ),
      );
      return affected;
    });
  }

  /// Rebuilds projections from a validated pending mutation candidate without
  /// replacing the server-confirmed raw body or ETag. The pending operation
  /// remains the durable local overlay and synchronization conflict baseline.
  Future<Set<String>> projectLocalMutationCandidate({
    required String accountId,
    required String collectionId,
    required BusyProvider provider,
    required String objectId,
    required String candidateRawIcs,
    DateTime? projectedAtUtc,
  }) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(accountId))).getSingleOrNull();
    final collection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(collectionId))).getSingleOrNull();
    final object = await (_database.select(
      _database.davObjects,
    )..where((row) => row.id.equals(objectId))).getSingleOrNull();
    if (account == null ||
        collection == null ||
        object == null ||
        account.provider != provider.storageValue ||
        collection.accountId != accountId ||
        object.accountId != accountId ||
        object.collectionId != collectionId ||
        object.serverDeleted) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavLocalCandidateContextInvalid',
        safeMessage: 'The pending DAV projection context was invalid.',
      );
    }
    final semantic = IcalSemanticDocument.parse(candidateRawIcs);
    final now = (projectedAtUtc ?? DateTime.now()).toUtc();
    final cursorState = await cursor(collectionId);
    final projectionRange = _projectionRange(cursorState, now);
    final context = DavCollectionCommit(
      accountId: accountId,
      collectionId: collectionId,
      provider: provider,
      objects: const [],
      deletedHrefKeys: const {},
      completeMembership: false,
      membershipHrefKeys: const {},
      finalCursorKind: cursorState?.cursorKind ?? 'snapshot_generation',
      finalCursorValue: cursorState?.cursorValue ?? '0',
      baselineGeneration: object.baselineGeneration,
      completedAtUtc: now,
      projectionRangeStartUtc: projectionRange.start,
      projectionRangeEndUtc: projectionRange.end,
    );
    return _database.transaction(() async {
      final componentIds = await _replaceComponentIndex(objectId, semantic);
      await _replaceProjections(
        commit: context,
        collection: collection,
        objectId: objectId,
        etag: object.etag,
        semantic: semantic,
        componentIds: componentIds,
      );
      await (_database.update(
        _database.calendarEvents,
      )..where((row) => row.davObjectId.equals(objectId))).write(
        CalendarEventsCompanion(
          syncStatus: const Value('pending'),
          updatedAtLocal: Value(now.millisecondsSinceEpoch),
        ),
      );
      await (_database.update(
        _database.tasks,
      )..where((row) => row.davObjectId.equals(objectId))).write(
        TasksCompanion(
          localDirty: const Value(true),
          updatedLocalAtUtc: Value(now.toIso8601String()),
        ),
      );
      await _resolveProjectedTaskParents(collectionId);
      return {objectId};
    });
  }

  /// Stores the server-confirmed representation from a conditional mutation
  /// without advancing the collection sync cursor. A follow-up incremental
  /// sync remains responsible for obtaining the provider's next opaque token.
  Future<Set<String>> commitConfirmedMutation({
    required String accountId,
    required String collectionId,
    required BusyProvider provider,
    DavPreparedObject? canonicalObject,
    String? deletedHrefKey,
    DateTime? completedAtUtc,
  }) async {
    if ((canonicalObject == null) == (deletedHrefKey == null)) {
      throw ArgumentError(
        'A confirmed mutation must contain exactly one object outcome.',
      );
    }
    final collection = await (_database.select(
      _database.davCollections,
    )..where((row) => row.id.equals(collectionId))).getSingle();
    if (collection.accountId != accountId) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavCollectionAccountMismatch',
        safeMessage: 'The DAV collection did not belong to the account.',
      );
    }
    final cursorState = await cursor(collectionId);
    final now = (completedAtUtc ?? DateTime.now()).toUtc();
    final projectionRange = _projectionRange(cursorState, now);
    final context = DavCollectionCommit(
      accountId: accountId,
      collectionId: collectionId,
      provider: provider,
      objects: const [],
      deletedHrefKeys: const {},
      completeMembership: false,
      membershipHrefKeys: const {},
      finalCursorKind: cursorState?.cursorKind ?? 'snapshot_generation',
      finalCursorValue: cursorState?.cursorValue ?? '0',
      baselineGeneration: cursorState?.baselineGeneration ?? 0,
      completedAtUtc: now,
      projectionRangeStartUtc: projectionRange.start,
      projectionRangeEndUtc: projectionRange.end,
    );
    return _database.transaction(() async {
      if (canonicalObject != null) {
        final id = await _upsertPreparedObject(
          commit: context,
          collection: collection,
          prepared: canonicalObject,
          ignorePendingOperations: true,
        );
        await _resolveProjectedTaskParents(collectionId);
        return {id};
      }
      final object = await objectByHref(collectionId, deletedHrefKey!);
      if (object == null) return const <String>{};
      await _markObjectDeleted(object, context, ignorePendingOperations: true);
      await _resolveProjectedTaskParents(collectionId);
      return {object.id};
    });
  }

  /// Atomically replaces a confirmed source resource with the canonical
  /// resource returned from its destination collection after WebDAV MOVE.
  Future<Set<String>> commitConfirmedMove({
    required String accountId,
    required String sourceCollectionId,
    required String destinationCollectionId,
    required BusyProvider provider,
    required String sourceHrefKey,
    required DavPreparedObject canonicalDestinationObject,
    DateTime? completedAtUtc,
  }) async {
    if (sourceCollectionId == destinationCollectionId) {
      throw ArgumentError('A DAV move requires two different collections.');
    }
    final account = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(accountId))).getSingleOrNull();
    final collections =
        await (_database.select(_database.davCollections)..where(
              (row) =>
                  row.id.isIn([sourceCollectionId, destinationCollectionId]),
            ))
            .get();
    final source = collections
        .where((collection) => collection.id == sourceCollectionId)
        .firstOrNull;
    final destination = collections
        .where((collection) => collection.id == destinationCollectionId)
        .firstOrNull;
    if (account == null ||
        account.provider != provider.storageValue ||
        source == null ||
        destination == null ||
        source.accountId != accountId ||
        destination.accountId != accountId ||
        !_hrefIsMemberOf(
          canonicalDestinationObject.hrefKey,
          destination.hrefKey,
        )) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavMoveContextInvalid',
        safeMessage: 'The confirmed DAV move context was invalid.',
      );
    }
    final now = (completedAtUtc ?? DateTime.now()).toUtc();
    final sourceCursor = await cursor(sourceCollectionId);
    final destinationCursor = await cursor(destinationCollectionId);
    final sourceRange = _projectionRange(sourceCursor, now);
    final destinationRange = _projectionRange(destinationCursor, now);
    final sourceContext = DavCollectionCommit(
      accountId: accountId,
      collectionId: sourceCollectionId,
      provider: provider,
      objects: const [],
      deletedHrefKeys: const {},
      completeMembership: false,
      membershipHrefKeys: const {},
      finalCursorKind: sourceCursor?.cursorKind ?? 'snapshot_generation',
      finalCursorValue: sourceCursor?.cursorValue ?? '0',
      baselineGeneration: sourceCursor?.baselineGeneration ?? 0,
      completedAtUtc: now,
      projectionRangeStartUtc: sourceRange.start,
      projectionRangeEndUtc: sourceRange.end,
    );
    final destinationContext = DavCollectionCommit(
      accountId: accountId,
      collectionId: destinationCollectionId,
      provider: provider,
      objects: const [],
      deletedHrefKeys: const {},
      completeMembership: false,
      membershipHrefKeys: const {},
      finalCursorKind: destinationCursor?.cursorKind ?? 'snapshot_generation',
      finalCursorValue: destinationCursor?.cursorValue ?? '0',
      baselineGeneration: destinationCursor?.baselineGeneration ?? 0,
      completedAtUtc: now,
      projectionRangeStartUtc: destinationRange.start,
      projectionRangeEndUtc: destinationRange.end,
    );
    return _database.transaction(() async {
      final affected = <String>{};
      final sourceObject = await objectByHref(
        sourceCollectionId,
        sourceHrefKey,
      );
      if (sourceObject != null) {
        await _markObjectDeleted(
          sourceObject,
          sourceContext,
          ignorePendingOperations: true,
        );
        affected.add(sourceObject.id);
      }
      final destinationObjectId = await _upsertPreparedObject(
        commit: destinationContext,
        collection: destination,
        prepared: canonicalDestinationObject,
        ignorePendingOperations: true,
      );
      affected.add(destinationObjectId);
      await _resolveProjectedTaskParents(sourceCollectionId);
      await _resolveProjectedTaskParents(destinationCollectionId);
      return affected;
    });
  }

  /// Atomically promotes a fully fetched and parsed collection change set.
  /// Network work and parsing happen before this method is entered, so any
  /// database/projection error rolls back to the prior complete baseline.
  Future<Set<String>> commit(DavCollectionCommit commit) {
    return _database.transaction(() async {
      final account = await (_database.select(
        _database.accounts,
      )..where((row) => row.id.equals(commit.accountId))).getSingleOrNull();
      final collection = await (_database.select(
        _database.davCollections,
      )..where((row) => row.id.equals(commit.collectionId))).getSingleOrNull();
      if (account == null ||
          collection == null ||
          collection.accountId != commit.accountId ||
          account.provider != commit.provider.storageValue) {
        throw const DavException(
          kind: DavErrorKind.protocol,
          code: 'DavCollectionAccountMismatch',
          safeMessage: 'The DAV collection did not belong to the account.',
        );
      }

      final changedObjectIds = <String>{};
      for (final prepared in commit.objects) {
        final objectId = await _upsertPreparedObject(
          commit: commit,
          collection: collection,
          prepared: prepared,
        );
        changedObjectIds.add(objectId);
      }

      final deletedObjectIds = <String>{};
      final explicitDeleted =
          await (_database.select(_database.davObjects)..where(
                (row) =>
                    row.collectionId.equals(commit.collectionId) &
                    row.hrefKey.isIn(commit.deletedHrefKeys),
              ))
              .get();
      for (final object in explicitDeleted) {
        await _markObjectDeleted(object, commit);
        deletedObjectIds.add(object.id);
      }

      if (commit.completeMembership) {
        final allObjects = await (_database.select(
          _database.davObjects,
        )..where((row) => row.collectionId.equals(commit.collectionId))).get();
        for (final object in allObjects) {
          if (commit.membershipHrefKeys.contains(object.hrefKey)) {
            await (_database.update(
              _database.davObjects,
            )..where((row) => row.id.equals(object.id))).write(
              DavObjectsCompanion(
                baselineGeneration: Value(commit.baselineGeneration),
              ),
            );
          } else if (!object.serverDeleted) {
            await _markObjectDeleted(object, commit);
            deletedObjectIds.add(object.id);
          }
        }
      }

      if (commit.forceReprojection) {
        final live =
            await (_database.select(_database.davObjects)..where(
                  (row) =>
                      row.collectionId.equals(commit.collectionId) &
                      row.serverDeleted.equals(false),
                ))
                .get();
        for (final object in live) {
          if (changedObjectIds.contains(object.id) ||
              await _hasActivePendingOperation(object.id)) {
            continue;
          }
          final semantic = IcalSemanticDocument.parse(object.rawIcsBody);
          final componentIds = await _replaceComponentIndex(
            object.id,
            semantic,
          );
          await _replaceProjections(
            commit: commit,
            collection: collection,
            objectId: object.id,
            etag: object.etag,
            semantic: semantic,
            componentIds: componentIds,
          );
          changedObjectIds.add(object.id);
        }
      }

      await _resolveProjectedTaskParents(commit.collectionId);

      final completed = commit.completedAtUtc.toUtc();
      final cursorId = 'dav-sync-${commit.collectionId}';
      await _database
          .into(_database.syncCursors)
          .insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              id: cursorId,
              accountId: commit.accountId,
              provider: commit.provider.storageValue,
              transport: 'caldav',
              syncScopeKind: 'collection',
              davCollectionId: Value(commit.collectionId),
              cursorKind: commit.finalCursorKind,
              cursorValue: commit.finalCursorValue,
              baselineGeneration: Value(commit.baselineGeneration),
              inProgressCursor: const Value(null),
              inProgressGeneration: const Value(null),
              lastCompleteSyncAt: Value(completed.millisecondsSinceEpoch),
              lastFailureCode: const Value(null),
              stateSchemaVersion: const Value(davSyncStateSchemaVersion),
              stateJson: Value(
                jsonEncode({
                  'projectionRangeStartUtc': commit.projectionRangeStartUtc
                      .toUtc()
                      .toIso8601String(),
                  'projectionRangeEndUtc': commit.projectionRangeEndUtc
                      .toUtc()
                      .toIso8601String(),
                  'projectionVersion': davProjectionVersion,
                }),
              ),
            ),
          );
      await (_database.update(
        _database.davCollections,
      )..where((row) => row.id.equals(commit.collectionId))).write(
        DavCollectionsCompanion(
          syncToken: Value(
            commit.finalCursorKind == 'dav_sync_token'
                ? commit.finalCursorValue
                : null,
          ),
          serverMissing: const Value(false),
          lastSyncAtUtc: Value(completed.toIso8601String()),
          parserVersion: const Value(davRawObjectParserVersion),
          projectionVersion: const Value(davProjectionVersion),
          updatedAtUtc: Value(completed.toIso8601String()),
        ),
      );
      await (_database.update(
        _database.accounts,
      )..where((row) => row.id.equals(commit.accountId))).write(
        AccountsCompanion(
          lastSuccessfulSyncAtUtc: Value(completed.toIso8601String()),
          updatedAtUtc: Value(completed.toIso8601String()),
        ),
      );
      return {...changedObjectIds, ...deletedObjectIds};
    });
  }

  Future<String> _upsertPreparedObject({
    required DavCollectionCommit commit,
    required DavCollection collection,
    required DavPreparedObject prepared,
    bool ignorePendingOperations = false,
  }) async {
    final existing =
        await (_database.select(_database.davObjects)..where(
              (row) =>
                  row.collectionId.equals(commit.collectionId) &
                  row.hrefKey.equals(prepared.hrefKey),
            ))
            .getSingleOrNull();
    final objectId = existing?.id ?? _idFactory();
    final now = commit.completedAtUtc.toUtc().toIso8601String();
    final rawChanged = existing?.rawBodyHash != prepared.rawBodyHash;
    final semanticChanged =
        existing?.semanticHash != prepared.semantic.semanticHash;
    await _database
        .into(_database.davObjects)
        .insertOnConflictUpdate(
          DavObjectsCompanion.insert(
            id: objectId,
            accountId: commit.accountId,
            collectionId: commit.collectionId,
            hrefKey: prepared.hrefKey,
            requestUri: prepared.requestUri.toString(),
            etag: Value(prepared.etag),
            contentType: Value(prepared.contentType),
            dominantComponentType: Value(
              prepared.semantic.dominantComponentType,
            ),
            componentMask: Value(prepared.semantic.componentMask),
            primaryUid: Value(prepared.semantic.primaryUid),
            rawIcsBody: prepared.rawIcsBody,
            rawBodyHash: prepared.rawBodyHash,
            semanticHash: Value(prepared.semantic.semanticHash),
            serverDeleted: const Value(false),
            baselineGeneration: Value(commit.baselineGeneration),
            firstSeenAtUtc: existing?.firstSeenAtUtc ?? now,
            lastFetchedAtUtc: now,
            lastChangedAtUtc: rawChanged
                ? now
                : existing?.lastChangedAtUtc ?? now,
            lastParseStatus: const Value('parsed'),
            lastParseErrorCode: const Value(null),
            parserVersion: const Value(davRawObjectParserVersion),
          ),
        );

    if (rawChanged ||
        semanticChanged ||
        existing?.parserVersion != davRawObjectParserVersion ||
        existing?.serverDeleted == true ||
        commit.forceReprojection) {
      final componentIds = await _replaceComponentIndex(
        objectId,
        prepared.semantic,
      );
      if (ignorePendingOperations ||
          !await _hasActivePendingOperation(objectId)) {
        await _replaceProjections(
          commit: commit,
          collection: collection,
          objectId: objectId,
          etag: prepared.etag,
          semantic: prepared.semantic,
          componentIds: componentIds,
        );
      }
    }
    return objectId;
  }

  Future<Map<String, String>> _replaceComponentIndex(
    String objectId,
    IcalSemanticDocument semantic,
  ) async {
    final existing = await (_database.select(
      _database.davObjectComponents,
    )..where((row) => row.davObjectId.equals(objectId))).get();
    final existingIds = {
      for (final row in existing)
        _componentKey(row.componentType, row.uid, row.recurrenceIdKey): row.id,
    };
    final returnedIds = <String>{};
    final result = <String, String>{};
    for (final entry in semantic.buildIndex()) {
      final key = _componentKey(
        entry.componentType,
        entry.uid,
        entry.recurrenceIdKey,
      );
      final id = existingIds[key] ?? _idFactory();
      returnedIds.add(id);
      result[key] = id;
      await _database
          .into(_database.davObjectComponents)
          .insertOnConflictUpdate(
            DavObjectComponentsCompanion.insert(
              id: id,
              davObjectId: objectId,
              componentType: entry.componentType,
              uid: entry.uid,
              recurrenceIdKey: Value(entry.recurrenceIdKey),
              sequence: Value(entry.sequence),
              dtstampUtc: Value(entry.dtstampUtc),
              lastModifiedUtc: Value(entry.lastModifiedUtc),
              semanticHash: entry.semanticHash,
              parserProfileVersion: Value(entry.parserProfileVersion),
            ),
          );
    }
    await (_database.delete(_database.davObjectComponents)..where(
          (row) =>
              row.davObjectId.equals(objectId) & row.id.isNotIn(returnedIds),
        ))
        .go();
    return result;
  }

  Future<void> _replaceProjections({
    required DavCollectionCommit commit,
    required DavCollection collection,
    required String objectId,
    required String? etag,
    required IcalSemanticDocument semantic,
    required Map<String, String> componentIds,
  }) async {
    await _deleteProjections(objectId);
    if (semantic.components.isEmpty) return;
    final componentType = semantic.components.first.componentType;
    if (componentType == 'VEVENT') {
      if (!collection.eventProjectionEnabled) return;
      await _projectEvents(
        commit: commit,
        collection: collection,
        objectId: objectId,
        etag: etag,
        semantic: semantic,
        componentIds: componentIds,
      );
    } else if (componentType == 'VTODO') {
      if (!collection.taskProjectionEnabled) return;
      await _projectTasks(
        commit: commit,
        collection: collection,
        objectId: objectId,
        etag: etag,
        semantic: semantic,
        componentIds: componentIds,
      );
    }
  }

  Future<void> _projectEvents({
    required DavCollectionCommit commit,
    required DavCollection collection,
    required String objectId,
    required String? etag,
    required IcalSemanticDocument semantic,
    required Map<String, String> componentIds,
  }) async {
    final sourceId = 'dav-calendar-${commit.collectionId}';
    final source = await (_database.select(
      _database.calendarSources,
    )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
    if (source == null) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavCalendarProjectionSourceMissing',
        safeMessage: 'The calendar projection source was missing.',
      );
    }
    final occurrences = _recurrenceExpander.expand(
      semantic,
      rangeStartUtc: commit.projectionRangeStartUtc,
      rangeEndUtc: commit.projectionRangeEndUtc,
    );
    final timeZoneResolver = IcalTimeZoneResolver.fromDocument(semantic);
    final recurringUids = {
      for (final component in semantic.components)
        if (component.componentType == 'VEVENT' &&
            (component.recurrenceId != null ||
                component.recurrenceRules.isNotEmpty ||
                component.recurrenceDates.isNotEmpty ||
                component.exceptionDates.isNotEmpty))
          component.uid,
    };
    final now = commit.completedAtUtc.toUtc().millisecondsSinceEpoch;
    for (final occurrence in occurrences) {
      final component = occurrence.effectiveComponent;
      final componentId =
          componentIds[_componentKey(
            component.componentType,
            component.uid!,
            component.recurrenceIdKey,
          )]!;
      final eventId = _stableProjectionId(
        'dav-event',
        '$objectId\u0000${occurrence.occurrenceKey}',
      );
      final allDay = occurrence.start.kind == IcalTemporalKind.date;
      final recurrence = {
        'rules': occurrence.master.recurrenceRules,
        'dates': occurrence.master.recurrenceDates,
        'excludedDates': occurrence.master.exceptionDates,
      };
      final attendees = component.attendees.isEmpty
          ? occurrence.master.attendees
          : component.attendees;
      final organizers = component.organizers.isEmpty
          ? occurrence.master.organizers
          : component.organizers;
      final categories = component.categories.isEmpty
          ? occurrence.master.categories
          : component.categories;
      final alarms = component.alarms.isEmpty
          ? occurrence.master.alarms
          : component.alarms;
      final startUtc = _resolvedTemporalUtc(occurrence.start, timeZoneResolver);
      final endUtc = occurrence.end == null
          ? null
          : _resolvedTemporalUtc(occurrence.end!, timeZoneResolver);
      final projectionJson = jsonEncode({
        'transport': 'caldav',
        'uid': component.uid,
        'occurrenceKey': occurrence.occurrenceKey,
        'nativeStart': _temporalJson(occurrence.start),
        if (occurrence.end != null) 'nativeEnd': _temporalJson(occurrence.end!),
        if (startUtc != null) 'startUtc': startUtc.toIso8601String(),
        if (endUtc != null) 'endUtc': endUtc.toIso8601String(),
        'extensionProperties': {
          ...occurrence.master.extensionProperties,
          ...component.extensionProperties,
        },
      });
      await _database
          .into(_database.calendarEvents)
          .insertOnConflictUpdate(
            CalendarEventsCompanion.insert(
              id: eventId,
              accountId: commit.accountId,
              calendarSourceId: sourceId,
              provider: commit.provider.storageValue,
              providerCalendarId: collection.hrefKey,
              providerEventId: objectId,
              davCollectionId: Value(commit.collectionId),
              davObjectId: Value(objectId),
              davComponentId: Value(componentId),
              icalUid: Value(component.uid),
              recurrenceIdKey: Value(component.recurrenceIdKey),
              occurrenceKey: Value(occurrence.occurrenceKey),
              projectionVersion: const Value(davProjectionVersion),
              providerRecurringEventId: Value(
                recurringUids.contains(occurrence.master.uid)
                    ? occurrence.master.uid
                    : null,
              ),
              providerOriginalStartKey: Value(
                recurringUids.contains(occurrence.master.uid)
                    ? occurrence.occurrenceKey
                    : null,
              ),
              etagOrChangeKey: Value(etag),
              status: Value(component.status ?? occurrence.master.status),
              title: occurrence.summary ?? '',
              description: Value(occurrence.description),
              location: Value(occurrence.location),
              allDay: Value(allDay),
              startDate: Value(
                allDay ? _storageTemporal(occurrence.start) : null,
              ),
              startDateTime: Value(
                allDay ? null : _storageTemporal(occurrence.start),
              ),
              startTimeZone: Value(_timeZoneName(occurrence.start)),
              endDate: Value(
                allDay && occurrence.end != null
                    ? _storageTemporal(occurrence.end!)
                    : null,
              ),
              endDateTime: Value(
                !allDay && occurrence.end != null
                    ? _storageTemporal(occurrence.end!)
                    : null,
              ),
              endTimeZone: Value(
                occurrence.end == null ? null : _timeZoneName(occurrence.end!),
              ),
              recurrenceJson: Value(jsonEncode(recurrence)),
              remindersJson: Value(
                jsonEncode({
                  'minutes': _eventReminderMinutes(alarms),
                  'alarms': _alarmProjection(alarms),
                }),
              ),
              attendeesJson: Value(jsonEncode(attendees)),
              categoriesJson: Value(jsonEncode(categories)),
              organizerJson: Value(
                organizers.isEmpty ? null : jsonEncode(organizers.first),
              ),
              colorHex: Value(collection.color),
              visibility: Value(
                component.classification ?? occurrence.master.classification,
              ),
              transparencyOrShowAs: Value(
                component.transparency ?? occurrence.master.transparency,
              ),
              webLink: Value(
                _propertyRaw(component, 'URL') ??
                    _propertyRaw(occurrence.master, 'URL'),
              ),
              attachmentsJson: Value(
                jsonEncode(
                  _propertyRawValues(component, 'ATTACH').isEmpty
                      ? _propertyRawValues(occurrence.master, 'ATTACH')
                      : _propertyRawValues(component, 'ATTACH'),
                ),
              ),
              isCancelled: Value(occurrence.isCancelled),
              isDeleted: const Value(false),
              rawJson: Value(projectionJson),
              createdAtServer: Value(
                _storageTemporalNullable(
                  component.created ?? occurrence.master.created,
                ),
              ),
              updatedAtServer: Value(
                _storageTemporalNullable(
                  component.lastModified ?? occurrence.master.lastModified,
                ),
              ),
              createdAtLocal: now,
              updatedAtLocal: now,
              syncStatus: const Value('synced'),
              baselineRawJson: Value(projectionJson),
            ),
          );
    }
  }

  Future<void> _projectTasks({
    required DavCollectionCommit commit,
    required DavCollection collection,
    required String objectId,
    required String? etag,
    required IcalSemanticDocument semantic,
    required Map<String, String> componentIds,
  }) async {
    final taskListId = 'dav-task-list-${commit.collectionId}';
    final taskList =
        await (_database.select(_database.taskLists)..where(
              (row) =>
                  row.accountId.equals(commit.accountId) &
                  row.id.equals(taskListId),
            ))
            .getSingleOrNull();
    if (taskList == null) {
      throw const DavException(
        kind: DavErrorKind.protocol,
        code: 'DavTaskProjectionListMissing',
        safeMessage: 'The task-list projection source was missing.',
      );
    }
    final master = semantic.components.firstWhere(
      (component) => component.recurrenceId == null,
    );
    final timeZoneResolver = IcalTimeZoneResolver.fromDocument(semantic);
    final now = commit.completedAtUtc.toUtc().toIso8601String();
    for (final component in semantic.components) {
      final componentId =
          componentIds[_componentKey(
            component.componentType,
            component.uid!,
            component.recurrenceIdKey,
          )]!;
      final taskId = _stableProjectionId(
        'dav-task',
        '$objectId\u0000${component.recurrenceIdKey ?? 'master'}',
      );
      final due = component.due ?? (component == master ? null : master.due);
      final start =
          component.start ?? (component == master ? null : master.start);
      final completed =
          component.completed ??
          (component.taskUiState == IcalTaskUiState.completed
              ? master.completed
              : null);
      final extensions = {
        ...master.extensionProperties,
        ...component.extensionProperties,
      };
      final alarms = component.alarms.isEmpty
          ? master.alarms
          : component.alarms;
      final reminder = _taskReminderProjection(
        alarms,
        start: start,
        due: due,
        timeZoneResolver: timeZoneResolver,
      );
      final startUtc = start == null
          ? null
          : _resolvedTemporalUtc(start, timeZoneResolver);
      final dueUtc = due == null
          ? null
          : _resolvedTemporalUtc(due, timeZoneResolver);
      final metadata = {
        'transport': 'caldav',
        'uid': component.uid,
        if (start != null) 'nativeStart': _temporalJson(start),
        if (due != null) 'nativeDue': _temporalJson(due),
        if (startUtc != null) 'startUtc': startUtc.toIso8601String(),
        if (dueUtc != null) 'dueUtc': dueUtc.toIso8601String(),
        if (component.recurrenceId != null)
          'recurrenceId': _temporalJson(component.recurrenceId!),
        'alarms': _alarmProjection(alarms),
      };
      final taskStatus = switch (component.taskUiState) {
        IcalTaskUiState.completed => 'completed',
        IcalTaskUiState.inProgress => 'inProcess',
        IcalTaskUiState.open => 'needsAction',
        IcalTaskUiState.cancelled => 'cancelled',
      };
      final priority = component.priority ?? master.priority;
      final sortOrder = nextcloudTaskSortOrder(
        component,
        fallback: component == master ? null : master,
      );
      await _database
          .into(_database.tasks)
          .insertOnConflictUpdate(
            TasksCompanion.insert(
              accountId: commit.accountId,
              taskListId: taskListId,
              id: taskId,
              davCollectionId: Value(commit.collectionId),
              davObjectId: Value(objectId),
              davComponentId: Value(componentId),
              icalUid: Value(component.uid),
              recurrenceIdKey: Value(component.recurrenceIdKey),
              icalPriority: Value(priority),
              percentComplete: Value(
                component.percentComplete ?? master.percentComplete,
              ),
              taskLocation: Value(component.location ?? master.location),
              taskUrl: Value(component.url ?? master.url),
              taskClassification: Value(
                component.classification ?? master.classification,
              ),
              taskPinned: Value(_extensionFlag(extensions, 'X-PINNED')),
              taskHideSubtasks: Value(
                _extensionFlag(extensions, 'X-OC-HIDESUBTASKS'),
              ),
              taskHideCompletedSubtasks: Value(
                _extensionFlag(extensions, 'X-OC-HIDECOMPLETEDSUBTASKS'),
              ),
              taskAlarmsJson: Value(jsonEncode(_alarmProjection(alarms))),
              parentUid: Value(component.parentUid ?? master.parentUid),
              sortOrder: Value(sortOrder),
              providerExtensionProjectionJson: Value(jsonEncode(extensions)),
              projectionVersion: const Value(davProjectionVersion),
              kind: const Value('tasks#task'),
              etag: Value(etag),
              title: component.summary ?? master.summary ?? '',
              updatedUtc: Value(
                _storageTemporalNullable(
                  component.lastModified ?? master.lastModified,
                ),
              ),
              parent: Value(component.parentUid ?? master.parentUid),
              position: Value('$sortOrder'),
              notes: Value(component.description ?? master.description),
              status: Value(taskStatus),
              dueUtc: Value(_storageTemporalNullable(due ?? start)),
              microsoftReminderDateTime: Value(reminder?.dateTime),
              microsoftReminderTimeZone: Value(reminder?.timeZone),
              microsoftIsReminderOn: Value(reminder != null),
              completedUtc: Value(_storageTemporalNullable(completed)),
              providerStatus: Value(component.status ?? master.status),
              recurrenceJson: Value(
                jsonEncode({
                  'rules': master.recurrenceRules,
                  'dates': master.recurrenceDates,
                  'excludedDates': master.exceptionDates,
                }),
              ),
              importance: Value(_importanceForIcalPriority(priority)),
              categoriesJson: Value(
                jsonEncode(
                  component.categories.isEmpty
                      ? master.categories
                      : component.categories,
                ),
              ),
              providerMetadataJson: Value(jsonEncode(metadata)),
              deleted: const Value(false),
              hidden: const Value(false),
              rawJson: jsonEncode(metadata),
              serverMissing: const Value(false),
              localDirty: const Value(false),
              pendingDelete: const Value(false),
              pendingMove: const Value(false),
              localCreated: const Value(false),
              lastSyncedAtUtc: Value(now),
              createdLocalAtUtc: now,
              updatedLocalAtUtc: now,
            ),
          );
    }
  }

  Future<void> _markObjectDeleted(
    DavObject object,
    DavCollectionCommit commit, {
    bool ignorePendingOperations = false,
  }) async {
    final now = commit.completedAtUtc.toUtc().toIso8601String();
    await (_database.update(
      _database.davObjects,
    )..where((row) => row.id.equals(object.id))).write(
      DavObjectsCompanion(
        serverDeleted: const Value(true),
        baselineGeneration: Value(commit.baselineGeneration),
        lastChangedAtUtc: Value(now),
      ),
    );
    if (ignorePendingOperations ||
        !await _hasActivePendingOperation(object.id)) {
      await _deleteProjections(object.id);
    } else {
      await (_database.update(_database.calendarEvents)
            ..where((row) => row.davObjectId.equals(object.id)))
          .write(const CalendarEventsCompanion(syncStatus: Value('conflict')));
    }
  }

  Future<void> _resolveProjectedTaskParents(String collectionId) async {
    final tasks = await (_database.select(
      _database.tasks,
    )..where((row) => row.davCollectionId.equals(collectionId))).get();
    final masterIdByUid = <String, String>{};
    for (final task in tasks) {
      final uid = task.icalUid;
      if (uid != null && task.recurrenceIdKey == null) {
        masterIdByUid[uid] = task.id;
      }
    }
    for (final task in tasks) {
      final resolvedParentId = task.parentUid == null
          ? null
          : masterIdByUid[task.parentUid!];
      if (task.parent == resolvedParentId) continue;
      await (_database.update(_database.tasks)..where(
            (row) =>
                row.accountId.equals(task.accountId) &
                row.taskListId.equals(task.taskListId) &
                row.id.equals(task.id),
          ))
          .write(TasksCompanion(parent: Value(resolvedParentId)));
    }
  }

  Future<bool> _hasActivePendingOperation(String objectId) async {
    final pending =
        await (_database.select(_database.pendingOps)..where(
              (row) =>
                  row.davObjectId.equals(objectId) &
                  row.state.isIn(const [
                    'pending',
                    'retry',
                    'in_progress',
                    'blocked',
                    'conflict',
                    'auth_blocked',
                    'permission_blocked',
                  ]),
            ))
            .getSingleOrNull();
    return pending != null;
  }

  Future<void> _deleteProjections(String objectId) async {
    await (_database.delete(
      _database.calendarEvents,
    )..where((row) => row.davObjectId.equals(objectId))).go();
    await (_database.delete(
      _database.tasks,
    )..where((row) => row.davObjectId.equals(objectId))).go();
  }
}

({DateTime start, DateTime end}) _projectionRange(
  SyncCursor? cursor,
  DateTime nowUtc,
) {
  final fallback = (
    start: DateTime.utc(nowUtc.year - 1, nowUtc.month, nowUtc.day),
    end: DateTime.utc(nowUtc.year + 2, nowUtc.month, nowUtc.day),
  );
  final stateJson = cursor?.stateJson;
  if (stateJson == null || stateJson.isEmpty) return fallback;
  try {
    final decoded = jsonDecode(stateJson);
    if (decoded is! Map<String, Object?>) return fallback;
    final startRaw = decoded['projectionRangeStartUtc'];
    final endRaw = decoded['projectionRangeEndUtc'];
    if (startRaw is! String || endRaw is! String) return fallback;
    final start = DateTime.tryParse(startRaw)?.toUtc();
    final end = DateTime.tryParse(endRaw)?.toUtc();
    if (start == null || end == null || !end.isAfter(start)) return fallback;
    return (start: start, end: end);
  } on FormatException {
    return fallback;
  }
}

bool _hrefIsMemberOf(String memberHref, String collectionHref) {
  final prefix = collectionHref.endsWith('/')
      ? collectionHref
      : '$collectionHref/';
  if (!memberHref.startsWith(prefix)) return false;
  final relative = memberHref.substring(prefix.length);
  return relative.isNotEmpty && !relative.contains('/');
}

String _componentKey(String type, String uid, String? recurrenceIdKey) =>
    '$type\u0000$uid\u0000${recurrenceIdKey ?? ''}';

String _stableProjectionId(String prefix, String source) =>
    '$prefix-${sha256.convert(utf8.encode(source))}';

String? _storageTemporalNullable(IcalTemporalValue? value) =>
    value == null ? null : _storageTemporal(value);

String _storageTemporal(IcalTemporalValue value) {
  String two(int number) => number.toString().padLeft(2, '0');
  final wall = value.localValue;
  final date =
      '${wall.year.toString().padLeft(4, '0')}-'
      '${two(wall.month)}-${two(wall.day)}';
  if (value.kind == IcalTemporalKind.date) return date;
  if (value.kind == IcalTemporalKind.utcDateTime) {
    return icalTemporalToUtc(value).toIso8601String();
  }
  return '${date}T${two(wall.hour)}:${two(wall.minute)}:${two(wall.second)}';
}

String? _timeZoneName(IcalTemporalValue value) => switch (value.kind) {
  IcalTemporalKind.utcDateTime => 'UTC',
  IcalTemporalKind.tzidDateTime => value.timeZoneId,
  IcalTemporalKind.date || IcalTemporalKind.floatingDateTime => null,
};

Map<String, Object?> _temporalJson(IcalTemporalValue value) => {
  'raw': value.rawValue,
  'kind': value.kind.name,
  if (value.timeZoneId != null) 'timeZoneId': value.timeZoneId,
};

List<Map<String, Object?>> _alarmProjection(List<IcalComponent> alarms) => [
  for (final alarm in alarms)
    {
      'properties': [
        for (final property in alarm.properties)
          {
            'name': property.name,
            'value': property.rawValue,
            if (property.parameters.isNotEmpty)
              'parameters': [
                for (final parameter in property.parameters)
                  {'name': parameter.name, 'values': parameter.values},
              ],
          },
      ],
    },
];

List<int> _eventReminderMinutes(List<IcalComponent> alarms) {
  final result = <int>[];
  for (final alarm in alarms) {
    final action = alarm.firstProperty('ACTION')?.rawValue.toUpperCase();
    if (action != 'DISPLAY' && action != 'AUDIO') {
      continue;
    }
    final trigger = alarm.firstProperty('TRIGGER');
    if (trigger == null ||
        trigger.parameterValue('RELATED')?.toUpperCase() == 'END') {
      continue;
    }
    try {
      final duration = parseIcalDuration(trigger.rawValue.toUpperCase());
      if (duration == null || !duration.negative) continue;
      final absolute = -duration.duration;
      if (absolute.inSeconds <= 0 || absolute.inSeconds % 60 != 0) continue;
      final minutes = absolute.inMinutes;
      if (!result.contains(minutes)) result.add(minutes);
    } on DavException {
      // Absolute and unsupported trigger forms remain in the raw alarm list.
    }
  }
  return result;
}

({String dateTime, String? timeZone})? _taskReminderProjection(
  List<IcalComponent> alarms, {
  required IcalTemporalValue? start,
  required IcalTemporalValue? due,
  required IcalTimeZoneResolver timeZoneResolver,
}) {
  for (final alarm in alarms) {
    final action = alarm.firstProperty('ACTION')?.rawValue.toUpperCase();
    if (action != 'DISPLAY' && action != 'AUDIO') {
      continue;
    }
    final trigger = alarm.firstProperty('TRIGGER');
    if (trigger == null) continue;
    try {
      final duration = parseIcalDuration(trigger.rawValue.toUpperCase());
      if (duration != null) {
        final relatedToEnd =
            trigger.parameterValue('RELATED')?.toUpperCase() == 'END';
        final reference = relatedToEnd ? due : start;
        if (reference == null) continue;
        final referenceUtc = _resolvedTemporalUtc(reference, timeZoneResolver);
        if (referenceUtc != null) {
          return (
            dateTime: referenceUtc
                .add(duration.duration)
                .toUtc()
                .toIso8601String(),
            timeZone: 'UTC',
          );
        }
        final wall = reference.localValue.add(duration.duration);
        final temporal = IcalTemporalValue(
          rawValue: trigger.rawValue,
          kind: reference.kind == IcalTemporalKind.date
              ? IcalTemporalKind.floatingDateTime
              : reference.kind,
          localValue: wall,
          timeZoneId: reference.timeZoneId,
        );
        return (
          dateTime: _storageTemporal(temporal),
          timeZone: _timeZoneName(temporal),
        );
      }
    } on DavException {
      // The trigger may instead be an absolute DATE-TIME.
    }
    try {
      final absolute = parseIcalTemporal(trigger);
      if (absolute?.kind != IcalTemporalKind.utcDateTime) continue;
      return (dateTime: _storageTemporal(absolute!), timeZone: 'UTC');
    } on DavException {
      // Unsupported alarms remain preserved but are not exposed as editable.
    }
  }
  return null;
}

DateTime? _resolvedTemporalUtc(
  IcalTemporalValue value,
  IcalTimeZoneResolver resolver,
) {
  return switch (value.kind) {
    IcalTemporalKind.utcDateTime || IcalTemporalKind.tzidDateTime =>
      icalTemporalToUtc(value, resolver: resolver),
    IcalTemporalKind.date || IcalTemporalKind.floatingDateTime => null,
  };
}

String? _propertyRaw(IcalSemanticComponent component, String name) =>
    component.documentComponent.firstProperty(name)?.rawValue;

List<String> _propertyRawValues(IcalSemanticComponent component, String name) =>
    component.documentComponent
        .propertiesNamed(name)
        .map((property) => property.rawValue)
        .toList(growable: false);

bool _extensionFlag(Map<String, List<String>> extensions, String name) {
  final value = extensions[name]?.firstOrNull?.trim().toUpperCase();
  return value == 'TRUE' || value == '1';
}

String _importanceForIcalPriority(int? priority) {
  if (priority != null && priority >= 1 && priority <= 4) return 'high';
  if (priority != null && priority >= 6 && priority <= 9) return 'low';
  return 'normal';
}
