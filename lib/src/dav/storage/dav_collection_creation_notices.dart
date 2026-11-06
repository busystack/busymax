import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../dav_errors.dart';
import '../mutation/dav_collection_creation_failure.dart';

/// Acknowledges presentation only; creation identities, states and diagnostics
/// remain authoritative in the operation journal.
final class DavCollectionCreationNotices {
  DavCollectionCreationNotices(this.database, {DateTime Function()? nowUtc})
    : _nowUtc = nowUtc ?? DateTime.now;

  final AppDatabase database;
  final DateTime Function() _nowUtc;

  Stream<List<DavCollectionCreationFailure>> watch(String accountId) =>
      (database.select(database.davCollectionCreations).join(
            [
              leftOuterJoin(
                database.davCollectionCreationAcknowledgments,
                database.davCollectionCreationAcknowledgments.operationId
                    .equalsExp(database.davCollectionCreations.id),
              ),
            ],
          )..where(database.davCollectionCreations.accountId.equals(accountId)))
          .watch()
          .asyncMap((_) => load(accountId));

  Future<List<DavCollectionCreationFailure>> load(
    String accountId, {
    Map<String, DavException> currentErrors = const {},
  }) async {
    final creations = database.davCollectionCreations;
    final acknowledgments = database.davCollectionCreationAcknowledgments;
    final rows =
        await (database.select(creations).join([
              leftOuterJoin(
                acknowledgments,
                acknowledgments.operationId.equalsExp(creations.id),
              ),
            ])..where(
              creations.accountId.equals(accountId) &
                  creations.state.isIn(const [
                    'prepared',
                    'dispatched',
                    'rejected',
                  ]) &
                  (creations.lastErrorCode.isNotNull() |
                      creations.id.isIn(currentErrors.keys)) &
                  (acknowledgments.operationId.isNull() |
                      creations.state.equals('rejected').not()),
            ))
            .get();
    return [
      for (final row in rows)
        DavCollectionCreationFailure.fromStored(
          row.readTable(creations),
          currentError: currentErrors[row.readTable(creations).id],
        ),
    ];
  }

  Future<bool> acknowledge(String accountId, String operationId) =>
      database.transaction(() async {
        final row =
            await (database.select(database.davCollectionCreations)..where(
                  (r) =>
                      r.id.equals(operationId) &
                      r.accountId.equals(accountId) &
                      r.state.equals('rejected'),
                ))
                .getSingleOrNull();
        if (row == null) return false;
        await database
            .into(database.davCollectionCreationAcknowledgments)
            .insert(
              DavCollectionCreationAcknowledgmentsCompanion.insert(
                operationId: operationId,
                acknowledgedAtUtc: _nowUtc().toUtc().toIso8601String(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        return true;
      });
}
