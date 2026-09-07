import 'dart:convert';

import 'package:drift/drift.dart';

import '../../db/app_database.dart';
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
                  r.state.isIn(const [
                    'pending',
                    'retry',
                    'in_progress',
                    'conflict',
                    'auth_blocked',
                    'permission_blocked',
                  ]),
            ))
            .get();
    final movingIn = {
      for (final op in operations)
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
      final operation = operations
          .where((op) => op.davObjectId == object.id)
          .firstOrNull;
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
    for (final op in operations.where(
      (op) =>
          op.operationType == 'dav.create' &&
          op.davCollectionId == collectionId &&
          op.davObjectId == null,
    )) {
      final request = jsonDecode(op.requestJson) as Map;
      resources.add(
        NativeImportResource(
          request['uid'] as String,
          request['componentType'] as String,
          request['rawIcs'] as String,
        ),
      );
    }
    return List.unmodifiable(resources);
  });
}
