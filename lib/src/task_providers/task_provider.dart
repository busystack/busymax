enum TaskProvider { google, microsoft }

typedef BusyProvider = TaskProvider;

extension TaskProviderParsing on TaskProvider {
  String get storageValue => switch (this) {
    TaskProvider.google => 'google',
    TaskProvider.microsoft => 'microsoft',
  };

  String get displayName => switch (this) {
    TaskProvider.google => 'Google',
    TaskProvider.microsoft => 'Microsoft',
  };

  static TaskProvider fromStorageValue(String? value) {
    return switch (value) {
      'microsoft' => TaskProvider.microsoft,
      _ => TaskProvider.google,
    };
  }
}

class TaskProviderCapabilities {
  const TaskProviderCapabilities({
    required this.supportsDueDate,
    required this.supportsDueTime,
    required this.supportsStartDateTime,
    required this.supportsReminderDateTime,
    required this.supportsRecurrence,
    required this.supportsImportance,
    required this.supportsCategories,
    required this.supportsTaskHierarchy,
    required this.supportsCrossListMove,
    required this.supportsClearCompleted,
    required this.supportsHiddenTasks,
    required this.supportsAssignedTasks,
    required this.supportsListRename,
    required this.supportsListDelete,
  });

  final bool supportsDueDate;
  final bool supportsDueTime;
  final bool supportsStartDateTime;
  final bool supportsReminderDateTime;
  final bool supportsRecurrence;
  final bool supportsImportance;
  final bool supportsCategories;
  final bool supportsTaskHierarchy;
  final bool supportsCrossListMove;
  final bool supportsClearCompleted;
  final bool supportsHiddenTasks;
  final bool supportsAssignedTasks;
  final bool supportsListRename;
  final bool supportsListDelete;
}

const googleTaskProviderCapabilities = TaskProviderCapabilities(
  supportsDueDate: true,
  supportsDueTime: false,
  supportsStartDateTime: false,
  supportsReminderDateTime: false,
  supportsRecurrence: false,
  supportsImportance: false,
  supportsCategories: false,
  supportsTaskHierarchy: true,
  supportsCrossListMove: true,
  supportsClearCompleted: true,
  supportsHiddenTasks: true,
  supportsAssignedTasks: true,
  supportsListRename: true,
  supportsListDelete: true,
);

const microsoftTaskProviderCapabilities = TaskProviderCapabilities(
  supportsDueDate: true,
  supportsDueTime: true,
  supportsStartDateTime: true,
  supportsReminderDateTime: true,
  supportsRecurrence: true,
  supportsImportance: true,
  supportsCategories: true,
  supportsTaskHierarchy: false,
  supportsCrossListMove: false,
  supportsClearCompleted: false,
  supportsHiddenTasks: false,
  supportsAssignedTasks: false,
  supportsListRename: true,
  supportsListDelete: true,
);

TaskProviderCapabilities capabilitiesForProvider(TaskProvider provider) {
  return switch (provider) {
    TaskProvider.google => googleTaskProviderCapabilities,
    TaskProvider.microsoft => microsoftTaskProviderCapabilities,
  };
}
