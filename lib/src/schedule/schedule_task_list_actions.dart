import '../features/task_lists/data/task_lists_repository.dart';
import '../features/tasks/domain/task_capabilities.dart';
import '../providers/busy_provider.dart';

bool canRenameScheduleTaskList(
  BusyProvider? provider,
  TaskListEntity list,
  TaskCollectionCapabilities? davCapabilities,
) {
  if (provider == null || list.pendingDelete) return false;
  if (provider == BusyProvider.microsoft) {
    return list.canRenameOrDeleteForMicrosoft;
  }
  if (list.davCollectionId != null) {
    return davCapabilities?.supportsListRename ?? false;
  }
  return adapterDefaultTaskCapabilities(provider).supportsListRename;
}

bool canDeleteScheduleTaskList(
  BusyProvider? provider,
  TaskListEntity list,
  TaskCollectionCapabilities? davCapabilities,
) {
  if (provider == null || list.pendingDelete) return false;
  if (provider == BusyProvider.microsoft) {
    return list.canRenameOrDeleteForMicrosoft;
  }
  if (provider == BusyProvider.caldav &&
      (list.isShared == true || list.davCollectionId == null)) {
    return false;
  }
  if (list.davCollectionId != null) {
    return davCapabilities?.supportsListDelete ?? false;
  }
  return adapterDefaultTaskCapabilities(provider).supportsListDelete;
}
