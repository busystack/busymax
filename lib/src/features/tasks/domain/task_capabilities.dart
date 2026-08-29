import '../../../providers/busy_provider.dart';

/// Task operations available for a concrete list or DAV collection.
class TaskCollectionCapabilities {
  const TaskCollectionCapabilities({
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
    this.canCreateTasks = true,
    this.canUpdateTasks = true,
    this.canDeleteTasks = true,
    this.supportsRecurringTaskOccurrenceEditing = false,
    this.supportsIcalPriority = false,
    this.supportsPercentComplete = false,
    this.supportsTaskStatus = false,
    this.supportsCompletedDateTime = false,
    this.supportsLocation = false,
    this.supportsUrl = false,
    this.supportsClassification = false,
    this.supportsMultipleReminders = false,
    this.supportsAdvancedRecurrence = false,
    this.supportsPinning = false,
    this.supportsSubtaskVisibility = false,
    this.supportsDuplicate = false,
    this.supportsNativeExport = false,
    this.supportsTaskReparenting = false,
    this.canUpdateClassification = true,
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
  final bool canCreateTasks;
  final bool canUpdateTasks;
  final bool canDeleteTasks;
  final bool supportsRecurringTaskOccurrenceEditing;
  final bool supportsIcalPriority;
  final bool supportsPercentComplete;
  final bool supportsTaskStatus;
  final bool supportsCompletedDateTime;
  final bool supportsLocation;
  final bool supportsUrl;
  final bool supportsClassification;
  final bool supportsMultipleReminders;
  final bool supportsAdvancedRecurrence;
  final bool supportsPinning;
  final bool supportsSubtaskVisibility;
  final bool supportsDuplicate;
  final bool supportsNativeExport;
  final bool supportsTaskReparenting;
  final bool canUpdateClassification;

  TaskCollectionCapabilities asReadOnly() => TaskCollectionCapabilities(
    supportsDueDate: supportsDueDate,
    supportsDueTime: supportsDueTime,
    supportsStartDateTime: supportsStartDateTime,
    supportsReminderDateTime: supportsReminderDateTime,
    supportsRecurrence: supportsRecurrence,
    supportsImportance: supportsImportance,
    supportsCategories: supportsCategories,
    supportsTaskHierarchy: supportsTaskHierarchy,
    supportsCrossListMove: false,
    supportsClearCompleted: false,
    supportsHiddenTasks: supportsHiddenTasks,
    supportsAssignedTasks: supportsAssignedTasks,
    supportsListRename: false,
    supportsListDelete: false,
    canCreateTasks: false,
    canUpdateTasks: false,
    canDeleteTasks: false,
    supportsIcalPriority: supportsIcalPriority,
    supportsPercentComplete: supportsPercentComplete,
    supportsTaskStatus: supportsTaskStatus,
    supportsCompletedDateTime: supportsCompletedDateTime,
    supportsLocation: supportsLocation,
    supportsUrl: supportsUrl,
    supportsClassification: supportsClassification,
    supportsMultipleReminders: supportsMultipleReminders,
    supportsAdvancedRecurrence: supportsAdvancedRecurrence,
    supportsPinning: supportsPinning,
    supportsSubtaskVisibility: supportsSubtaskVisibility,
    supportsDuplicate: supportsDuplicate,
    supportsNativeExport: supportsNativeExport,
    supportsTaskReparenting: supportsTaskReparenting,
    canUpdateClassification: false,
  );

  TaskCollectionCapabilities withoutClassificationEditing() =>
      TaskCollectionCapabilities(
        supportsDueDate: supportsDueDate,
        supportsDueTime: supportsDueTime,
        supportsStartDateTime: supportsStartDateTime,
        supportsReminderDateTime: supportsReminderDateTime,
        supportsRecurrence: supportsRecurrence,
        supportsImportance: supportsImportance,
        supportsCategories: supportsCategories,
        supportsTaskHierarchy: supportsTaskHierarchy,
        supportsCrossListMove: supportsCrossListMove,
        supportsClearCompleted: supportsClearCompleted,
        supportsHiddenTasks: supportsHiddenTasks,
        supportsAssignedTasks: supportsAssignedTasks,
        supportsListRename: supportsListRename,
        supportsListDelete: supportsListDelete,
        canCreateTasks: canCreateTasks,
        canUpdateTasks: canUpdateTasks,
        canDeleteTasks: canDeleteTasks,
        supportsRecurringTaskOccurrenceEditing:
            supportsRecurringTaskOccurrenceEditing,
        supportsIcalPriority: supportsIcalPriority,
        supportsPercentComplete: supportsPercentComplete,
        supportsTaskStatus: supportsTaskStatus,
        supportsCompletedDateTime: supportsCompletedDateTime,
        supportsLocation: supportsLocation,
        supportsUrl: supportsUrl,
        supportsClassification: supportsClassification,
        supportsMultipleReminders: supportsMultipleReminders,
        supportsAdvancedRecurrence: supportsAdvancedRecurrence,
        supportsPinning: supportsPinning,
        supportsSubtaskVisibility: supportsSubtaskVisibility,
        supportsDuplicate: supportsDuplicate,
        supportsNativeExport: supportsNativeExport,
        supportsTaskReparenting: supportsTaskReparenting,
        canUpdateClassification: false,
      );
}

const googleTaskCollectionCapabilities = TaskCollectionCapabilities(
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
  supportsTaskReparenting: true,
);

const microsoftTaskCollectionCapabilities = TaskCollectionCapabilities(
  supportsDueDate: true,
  supportsDueTime: true,
  supportsStartDateTime: true,
  supportsReminderDateTime: true,
  supportsRecurrence: true,
  supportsImportance: true,
  supportsCategories: true,
  supportsTaskHierarchy: true,
  supportsCrossListMove: false,
  supportsClearCompleted: false,
  supportsHiddenTasks: false,
  supportsAssignedTasks: false,
  supportsListRename: true,
  supportsListDelete: true,
);

const nextcloudTaskCollectionCapabilities = TaskCollectionCapabilities(
  supportsDueDate: true,
  supportsDueTime: true,
  supportsStartDateTime: true,
  supportsReminderDateTime: true,
  supportsRecurrence: true,
  supportsImportance: true,
  supportsCategories: true,
  supportsTaskHierarchy: true,
  supportsCrossListMove: true,
  supportsClearCompleted: true,
  supportsHiddenTasks: false,
  supportsAssignedTasks: false,
  supportsListRename: true,
  supportsListDelete: true,
  supportsIcalPriority: true,
  supportsPercentComplete: true,
  supportsTaskStatus: true,
  supportsCompletedDateTime: true,
  supportsLocation: true,
  supportsUrl: true,
  supportsClassification: true,
  supportsMultipleReminders: true,
  supportsAdvancedRecurrence: true,
  supportsPinning: true,
  supportsSubtaskVisibility: true,
  supportsDuplicate: true,
  supportsNativeExport: true,
  supportsTaskReparenting: true,
);

const noTaskCollectionCapabilities = TaskCollectionCapabilities(
  supportsDueDate: false,
  supportsDueTime: false,
  supportsStartDateTime: false,
  supportsReminderDateTime: false,
  supportsRecurrence: false,
  supportsImportance: false,
  supportsCategories: false,
  supportsTaskHierarchy: false,
  supportsCrossListMove: false,
  supportsClearCompleted: false,
  supportsHiddenTasks: false,
  supportsAssignedTasks: false,
  supportsListRename: false,
  supportsListDelete: false,
  canCreateTasks: false,
  canUpdateTasks: false,
  canDeleteTasks: false,
);

/// Adapter defaults used until list-specific capabilities are available.
TaskCollectionCapabilities adapterDefaultTaskCapabilities(
  BusyProvider provider,
) => switch (provider) {
  BusyProvider.google => googleTaskCollectionCapabilities,
  BusyProvider.microsoft => microsoftTaskCollectionCapabilities,
  BusyProvider.appleICloud => noTaskCollectionCapabilities,
  BusyProvider.nextcloud => nextcloudTaskCollectionCapabilities,
  BusyProvider.webCal => noTaskCollectionCapabilities,
};
