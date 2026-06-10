String encodePathSegment(String value) => Uri.encodeComponent(value);

String taskListPath(String taskListId) {
  return '/tasks/v1/users/@me/lists/${encodePathSegment(taskListId)}';
}

String taskListsPath() => '/tasks/v1/users/@me/lists';

String tasksPath(String taskListId) {
  return '/tasks/v1/lists/${encodePathSegment(taskListId)}/tasks';
}

String taskPath(String taskListId, String taskId) {
  return '${tasksPath(taskListId)}/${encodePathSegment(taskId)}';
}

String taskMovePath(String taskListId, String taskId) {
  return '${taskPath(taskListId, taskId)}/move';
}

String tasksClearPath(String taskListId) {
  return '/tasks/v1/lists/${encodePathSegment(taskListId)}/clear';
}
