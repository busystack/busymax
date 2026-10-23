import 'dart:convert';

import '../../db/app_database.dart';

const taskBarrierOperationIdsKey = '_busymaxTaskBarrierOpIds';

/// A successful empty-response Google clear establishes hidden=true, without
/// returning the task's new revision. A later whole-list removal must still
/// compare every semantic field against its approved snapshot.
const acknowledgedTaskHiddenEffectKey = '_busymaxAcknowledgedHiddenEffect';

/// Optimistic moves can put the local row in the destination before the
/// provider has removed it from the source. Both collections remain affected
/// until every operation in the chain has been acknowledged or discarded.
bool taskOperationTouchesList(PendingOp operation, String taskListId) {
  if (operation.entityType != 'task' &&
      operation.entityType != 'task_checklist_item') {
    return false;
  }
  if (operation.taskListId == taskListId) return true;
  if (operation.operation != 'move_task') return false;
  final request = jsonDecode(operation.requestJson);
  return request is Map && request['destinationTasklist'] == taskListId;
}
