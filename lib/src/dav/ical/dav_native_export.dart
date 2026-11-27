import 'dart:convert';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../journal/journal_component.dart';
import '../dav_errors.dart';
import '../ical/ical_semantics.dart';
import '../mutation/dav_pending_operation_selection.dart';
import '../mutation/dav_pending_operations.dart';
import '../storage/dav_collection_capabilities.dart';
import 'dav_native_import.dart';

final class DavCollectionExport {
  const DavCollectionExport(
    this.resources,
    this.pendingJournalRecoveries,
    this.excludedJournalCount,
  );

  final List<NativeImportResource> resources;
  final List<DavJournalPendingRecovery> pendingJournalRecoveries;
  final int excludedJournalCount;
}

/// A consistent, account-scoped snapshot of effective local resources. Each
/// resource is exported separately, so different embedded definitions using the
/// same TZID and unrelated calendar-level extensions are never flattened.
final class DavNativeExportService {
  const DavNativeExportService(this.database);
  final AppDatabase database;

  Future<List<NativeImportResource>> collection(
    String accountId,
    String collectionId,
  ) async {
    final snapshot = await collectionForReview(accountId, collectionId);
    if (snapshot.excludedJournalCount > 0) {
      throw StateError('Review excluded pending journals before exporting.');
    }
    return snapshot.resources;
  }

  Future<DavCollectionExport> collectionForReview(
    String accountId,
    String collectionId,
  ) => database.transaction(() async {
    final account = await (database.select(
      database.accounts,
    )..where((r) => r.id.equals(accountId))).getSingle();
    final source =
        await (database.select(database.davCollections)..where(
              (r) => r.id.equals(collectionId) & r.accountId.equals(accountId),
            ))
            .getSingle();
    if (!const {'nextcloud', 'caldav'}.contains(account.provider) ||
        !collectionCapabilitiesFromStored(source).canRead) {
      throw StateError('This calendar is not available for native export.');
    }
    final operations =
        await (database.select(database.pendingOps)..where(
              (r) =>
                  r.accountId.equals(accountId) &
                  r.state.isIn(davUnresolvedPendingStates),
            ))
            .get();
    final unanchoredCreations =
        await (database.select(database.pendingOps)..where(
              (r) =>
                  r.accountId.equals(accountId) &
                  r.davCollectionId.equals(collectionId) &
                  r.operationType.equals('dav.create') &
                  r.davObjectId.isNull() &
                  r.state.isIn(davUnresolvedPendingStates),
            ))
            .get();
    final effectiveByObject = <String, PendingOp>{};
    for (final objectId in operations.map((op) => op.davObjectId).nonNulls) {
      final effective = effectiveDavExportOperation(operations, objectId);
      if (effective != null) effectiveByObject[objectId] = effective;
    }
    final movingIn = {
      for (final op in effectiveByObject.values)
        if (op.operationType == 'dav.move' &&
            op.destinationCollectionId == collectionId &&
            op.davObjectId != null)
          op.davObjectId!,
    };
    final objects =
        await (database.select(database.davObjects)..where(
              (r) =>
                  r.accountId.equals(accountId) &
                  r.serverDeleted.equals(false) &
                  (r.collectionId.equals(collectionId) | r.id.isIn(movingIn)),
            ))
            .get();
    final queue = DavPendingOperationQueue(database: database);
    final resources = <NativeImportResource>[];
    final recoveries = <DavJournalPendingRecovery>[];
    var excludedJournalCount = 0;
    for (final object in objects) {
      final operation = effectiveByObject[object.id];
      if (operation?.operationType == 'dav.delete' ||
          (operation?.operationType == 'dav.move' &&
              operation?.destinationCollectionId != collectionId)) {
        continue;
      }
      final String raw;
      try {
        raw = await queue.exportRawIcsForObject(
          accountId: accountId,
          collectionId: object.collectionId,
          objectId: object.id,
        );
      } on DavException catch (error) {
        if (error.code != duplicateJournalPositionCode) rethrow;
        excludedJournalCount += 1;
        final recovery = await queue.journalRecoveryForObject(
          accountId: accountId,
          collectionId: object.collectionId,
          objectId: object.id,
        );
        if (recovery != null) recoveries.add(recovery);
        continue;
      }
      resources.add(
        NativeImportResource(
          object.primaryUid ?? object.id,
          object.dominantComponentType ?? '',
          raw,
        ),
      );
    }
    // Normal editor-created resources can have a projection but no raw-object
    // anchor until their first server PUT. They belong in the same export.
    for (final op in unanchoredCreations) {
      final resource = _pendingCreationResource(op);
      if (resource.componentType == 'VJOURNAL') {
        try {
          JournalComponent.validateAuthored(
            IcalSemanticDocument.parse(resource.rawIcs),
          );
        } on DavException catch (error) {
          if (error.code != duplicateJournalPositionCode) rethrow;
          excludedJournalCount += 1;
          final recovery = await queue.journalRecoveryForUnanchoredCreate(op);
          if (recovery != null) recoveries.add(recovery);
          continue;
        }
      }
      resources.add(resource);
    }
    return DavCollectionExport(
      List.unmodifiable(resources),
      List.unmodifiable(recoveries),
      excludedJournalCount,
    );
  });
}

NativeImportResource _pendingCreationResource(PendingOp operation) {
  try {
    final decoded = jsonDecode(operation.requestJson);
    if (decoded is! Map) throw const FormatException();
    final uid = decoded['uid'];
    final componentType = decoded['componentType'];
    final rawIcs = decoded['rawIcs'];
    if (uid is! String ||
        uid.trim().isEmpty ||
        componentType is! String ||
        componentType.trim().isEmpty ||
        rawIcs is! String ||
        rawIcs.trim().isEmpty) {
      throw const FormatException();
    }
    final parsed = IcalSemanticDocument.parse(rawIcs);
    if (parsed.primaryUid != uid ||
        parsed.components.isEmpty ||
        parsed.components.any(
          (component) => component.componentType != componentType,
        )) {
      throw const FormatException();
    }
    return NativeImportResource(uid, componentType, rawIcs);
  } on Object {
    throw StateError(
      'Pending local creation ${operation.id} could not be included in the '
      'native export.',
    );
  }
}
