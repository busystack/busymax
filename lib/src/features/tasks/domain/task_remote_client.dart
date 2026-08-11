import 'task_remote_models.dart';

/// Remote task boundary shared by Google Tasks and Microsoft To Do.
/// DAV tasks use the resource-oriented DAV synchronization engine.
abstract interface class TaskRemoteClient {
  Future<void> deleteTaskList(String taskListId);
  Future<TaskListDto> getTaskList(String taskListId);
  Future<TaskListDto> createTaskList({required String title});
  Future<TaskListsPageDto> listTaskListsPage({
    int maxResults = 1000,
    String? pageToken,
  });
  Future<TaskListDto> patchTaskList(String taskListId, TaskListPatch patch);
  Future<TaskListDto> updateTaskList(
    String taskListId,
    TaskListPut replacement,
  );

  Future<void> clearCompletedTasks(String taskListId);
  Future<void> deleteTask({required String taskListId, required String taskId});
  Future<TaskDto> getTask({required String taskListId, required String taskId});
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  });
  Future<TasksPageDto> listTasksPage({
    required String taskListId,
    DateTime? completedMax,
    DateTime? completedMin,
    DateTime? dueMax,
    DateTime? dueMin,
    int maxResults = 100,
    String? pageToken,
    bool showCompleted = true,
    bool showDeleted = false,
    bool showHidden = false,
    DateTime? updatedMin,
    bool showAssigned = false,
  });
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  });
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  });
  Future<TaskDto> updateTask({
    required String taskListId,
    required String taskId,
    required TaskPut replacement,
  });
}

/// Child-item boundary used by providers whose subtasks are not task
/// resources. Microsoft Graph models Microsoft To Do steps as checklistItem
/// children of a todoTask.
abstract interface class TaskChecklistRemoteClient {
  Future<TaskChecklistItemsPageDto> listChecklistItemsPage({
    required String taskListId,
    required String taskId,
    String? pageToken,
  });

  Future<TaskChecklistItemDto> createChecklistItem({
    required String taskListId,
    required String taskId,
    required String title,
    bool completed = false,
  });

  Future<TaskChecklistItemDto> updateChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
    String? title,
    bool? completed,
  });

  Future<void> deleteChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
  });
}
