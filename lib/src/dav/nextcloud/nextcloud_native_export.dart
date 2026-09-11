import 'dart:convert';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../ical/ical_semantics.dart';
import '../mutation/dav_pending_operation_selection.dart';
import '../mutation/dav_pending_operations.dart';
import '../storage/dav_collection_capabilities.dart';
import 'nextcloud_native_import.dart';

/// A consistent, account-scoped snapshot of effective local resources. Each
/// resource is exported separately, so different embedded definitions using the
/// same TZID and unrelated calendar-level extensions are never flattened.
final class NextcloudNativeExportService {
  const NextcloudNativeExportService(this.database);
  final AppDatabase database;

  Future<List<NativeImportResource>> collection(
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
    if (account.provider != 'nextcloud' ||
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
    for (final object in objects) {
      final operation = effectiveByObject[object.id];
      if (operation?.operationType == 'dav.delete' ||
          (operation?.operationType == 'dav.move' &&
              operation?.destinationCollectionId != collectionId)) {
        continue;
      }
      final raw = await queue.exportRawIcsForObject(
        accountId: accountId,
        collectionId: object.collectionId,
        objectId: object.id,
      );
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
      resources.add(_pendingCreationResource(op));
    }
    return List.unmodifiable(resources);
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
