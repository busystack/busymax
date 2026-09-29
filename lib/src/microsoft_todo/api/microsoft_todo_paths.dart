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

String microsoftLinkedResourcesPath(String taskListId, String taskId) {
  return '${microsoftTaskPath(taskListId, taskId)}/linkedResources';
}

String microsoftTaskAttachmentsPath(String taskListId, String taskId) =>
    '${microsoftTaskPath(taskListId, taskId)}/attachments';

String microsoftTaskAttachmentPath(
  String taskListId,
  String taskId,
  String attachmentId,
) =>
    '${microsoftTaskAttachmentsPath(taskListId, taskId)}/'
    '${Uri.encodeComponent(attachmentId)}';

String microsoftChecklistItemsPath(String taskListId, String taskId) {
  return '${microsoftTaskPath(taskListId, taskId)}/checklistItems';
}

String microsoftChecklistItemPath(
  String taskListId,
  String taskId,
  String checklistItemId,
) {
  return '${microsoftChecklistItemsPath(taskListId, taskId)}/'
      '${Uri.encodeComponent(checklistItemId)}';
}
