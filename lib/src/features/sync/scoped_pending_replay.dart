import 'dart:convert';

import '../../db/app_database.dart';

/// Select roots from the whole durable queue so a dependency can remain a
/// barrier even when it is outside the due-time candidate set.
Future<Set<String>> scopedReplayIds(
  AppDatabase database,
  String accountId,
  bool Function(PendingOp) touchesTarget, {
  bool Function(PendingOp)? followsSelectedCopy,
  Iterable<String> Function(PendingOp)? prerequisites,
}) async {
  final operations = await (database.select(
    database.pendingOps,
  )..where((row) => row.accountId.equals(accountId))).get();
  final byId = {for (final op in operations) op.id: op};
  final ids = <String>{};
  void include(String id) {
    final op = byId[id];
    if (op == null || !ids.add(id)) return;
    if (op.dependsOnOpId case final parent?) include(parent);
    if (prerequisites != null) {
      for (final required in prerequisites(op)) {
        include(required);
      }
    }
  }

  for (final op in operations.where(touchesTarget)) {
    include(op.id);
  }
  for (final op in operations) {
    if (ids.contains(op.dependsOnOpId) &&
        followsSelectedCopy?.call(op) == true) {
      include(op.id);
    }
  }
  // A cross-account copy successor cannot run under this account's lease.
  if (followsSelectedCopy != null && ids.isNotEmpty) {
    final dependents = await (database.select(
      database.pendingOps,
    )..where((row) => row.dependsOnOpId.isIn(ids))).get();
    ids.addAll(dependents.where(followsSelectedCopy).map((op) => op.id));
  }
  return ids;
}

Future<bool> hasScopedPendingReplay(
  AppDatabase database,
  Set<String> selectedIds,
) async {
  if (selectedIds.isEmpty) return false;
  final rows =
      await (database.select(database.pendingOps)
            ..where((row) => row.id.isIn(selectedIds))
            ..limit(1))
          .get();
  return rows.isNotEmpty;
}

Map<String, dynamic> pendingReplayPayload(PendingOp op) {
  try {
    final payload = jsonDecode(op.requestJson);
    if (payload is Map<String, dynamic>) return payload;
  } on FormatException {
    // The existing replayer classifies malformed requests.
  }
  return const {};
}
