import 'dart:async';

import 'package:flutter/foundation.dart';

enum TaskMutationKind {
  updated,
  deleted,
  duplicated,
  createdSubtask,
  completion,
  checklistUpdated,
  checklistDeleted,
  reordered,
  moved,
}

@immutable
class TaskMutationResult {
  const TaskMutationResult({
    required this.kind,
    required this.accountId,
    required this.taskListId,
    required this.taskId,
    this.checklistItemId,
    this.createdTaskId,
    this.completed,
    this.occurrenceKey,
  });

  final TaskMutationKind kind;
  final String accountId;
  final String taskListId;
  final String taskId;
  final String? checklistItemId;
  final String? createdTaskId;
  final bool? completed;

  /// The occurrence acted on, before a recurring master advances.
  final String? occurrenceKey;
}

typedef TaskMutationCommittedCallback = FutureOr<void> Function(
  TaskMutationResult result,
);
