import '../../db/app_database.dart';

const davActivePendingStates = <String>[
  'pending',
  'retry',
  'in_progress',
  'blocked',
  'conflict',
  'auth_blocked',
  'permission_blocked',
];

const davUnresolvedPendingStates = <String>[
  ...davActivePendingStates,
  'failed',
];

bool isDavPendingOperation(PendingOp operation) =>
    operation.operationType == 'dav.create' ||
    operation.operationType == 'dav.update' ||
    operation.operationType == 'dav.delete' ||
    operation.operationType == 'dav.move';

/// Selects the final effective operation in a dependency chain for one object.
///
/// Creation time and operation IDs provide deterministic fallback ordering for
/// malformed or disconnected queues, but a valid chain is selected by its
/// terminal dependency rather than either value.
PendingOp? effectiveDavPendingOperation(
  Iterable<PendingOp> source,
  String objectId,
) => _effectiveDavOperation(source, objectId, davActivePendingStates);

/// Selects the final retained local operation for native export.
///
/// Failed operations remain durable until the user explicitly resolves or
/// discards them. They are therefore part of an export snapshot even though
/// they are not eligible for automatic replay.
PendingOp? effectiveDavExportOperation(
  Iterable<PendingOp> source,
  String objectId,
) => _effectiveDavOperation(source, objectId, davUnresolvedPendingStates);

PendingOp? _effectiveDavOperation(
  Iterable<PendingOp> source,
  String objectId,
  List<String> states,
) {
  final operations =
      source
          .where(
            (operation) =>
                operation.davObjectId == objectId &&
                isDavPendingOperation(operation) &&
                states.contains(operation.state),
          )
          .toList(growable: false)
        ..sort((left, right) {
          final created = left.createdAtUtc.compareTo(right.createdAtUtc);
          return created != 0 ? created : left.id.compareTo(right.id);
        });
  if (operations.isEmpty) return null;
  final dependedOnIds = {
    for (final operation in operations) operation.dependsOnOpId,
  }..remove(null);
  final terminal = operations
      .where((operation) => !dependedOnIds.contains(operation.id))
      .toList(growable: false);
  return terminal.length == 1 ? terminal.single : operations.last;
}
