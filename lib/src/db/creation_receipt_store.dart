import 'package:drift/drift.dart';

import 'app_database.dart';

enum CreationKind { event, task }

/// Keeps submission identity separate from an item's mutable provider identity.
final class CreationReceiptStore {
  const CreationReceiptStore(this._database);

  final AppDatabase _database;

  Future<bool> hasCommitted(CreationKind kind, String id) async =>
      (await _receipt(kind, id).getSingleOrNull())?.resultId != null;

  Future<({String resultId, bool created})> createOnce({
    required CreationKind kind,
    required String id,
    required Future<String> Function() create,
  }) => _database.transaction(() async {
    // Start with a write so two connections cannot both read an empty receipt
    // and attempt to promote their read transactions to writers.
    await _database
        .into(_database.creationReceipts)
        .insert(
          CreationReceiptsCompanion.insert(kind: kind.name, creationId: id),
          mode: InsertMode.insertOrIgnore,
        );
    final receipt = _receipt(kind, id);
    final existing = await receipt.getSingle();
    if (existing.resultId case final resultId?) {
      return (resultId: resultId, created: false);
    }

    final resultId = await create();
    await (_database.update(_database.creationReceipts)..where(
          (row) => row.kind.equals(kind.name) & row.creationId.equals(id),
        ))
        .write(CreationReceiptsCompanion(resultId: Value(resultId)));
    return (resultId: resultId, created: true);
  });

  SimpleSelectStatement<$CreationReceiptsTable, CreationReceipt> _receipt(
    CreationKind kind,
    String id,
  ) => _database.select(_database.creationReceipts)
    ..where((row) => row.kind.equals(kind.name) & row.creationId.equals(id));
}
