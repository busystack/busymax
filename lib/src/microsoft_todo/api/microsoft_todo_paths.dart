String microsoftMePath() => '/me';

String microsoftTaskListsPath() => '/me/todo/lists';

String microsoftTaskListsDeltaPath() => '/me/todo/lists/delta';

String microsoftTaskListPath(String taskListId) {
  return '/me/todo/lists/${Uri.encodeComponent(taskListId)}';
}

String microsoftTasksPath(String taskListId) {
  return '${microsoftTaskListPath(taskListId)}/tasks';
}

String microsoftTasksDeltaPath(String taskListId) {
  return '${microsoftTasksPath(taskListId)}/delta';
}

String microsoftTaskPath(String taskListId, String taskId) {
  return '${microsoftTasksPath(taskListId)}/${Uri.encodeComponent(taskId)}';
}
