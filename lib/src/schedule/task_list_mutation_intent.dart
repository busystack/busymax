import 'package:flutter/foundation.dart';

enum TaskListMutationPresentation { insertion, removal, completion }

@immutable
class TaskListMutationIntent {
  const TaskListMutationIntent({
    required this.presentation,
    required this.accountId,
    required this.taskListId,
    required this.taskId,
    required this.generation,
    this.checklistItemId,
    this.completed,
  });

  final TaskListMutationPresentation presentation;
  final String accountId;
  final String taskListId;
  final String taskId;
  final String? checklistItemId;
  final bool? completed;
  final int generation;

  String get taskKey => '$accountId\u0000$taskListId\u0000$taskId';
}
