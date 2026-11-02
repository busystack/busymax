import '../../../providers/busy_provider.dart';
import '../../connectivity/network_connectivity_service.dart';
import '../data/accounts_repository.dart';

enum CalendarCollectionCreationMode {
  unavailable,
  cloudPendingOperation,
  nextcloudDav,
  genericDav,
}

enum TaskListCreationMode {
  unavailable,
  cloudPendingOperation,
  nextcloudDav,
  genericDav,
}

/// Account-level collection creation policy.
///
/// These modes describe how a collection is created. They are intentionally
/// separate from item-level write capabilities such as creating an event or a
/// task inside an existing collection.
final class AccountCollectionCreationCapabilities {
  const AccountCollectionCreationCapabilities({
    required this.calendarMode,
    required this.taskListMode,
    required this.calendarActionEnabled,
    required this.taskListActionEnabled,
  });

  factory AccountCollectionCreationCapabilities.resolve({
    required AccountEntity account,
    required NetworkAvailability networkAvailability,
    bool calendarCreationRunning = false,
    bool taskListCreationRunning = false,
  }) {
    final providerModes = accountCollectionCreationModes(account.provider);
    final genericAllowed =
        account.provider != BusyProvider.caldav ||
        account.caldavCollectionCreationAvailable;
    final calendarMode = account.calendarsEnabled && genericAllowed
        ? providerModes.calendarMode
        : CalendarCollectionCreationMode.unavailable;
    final taskListMode = account.tasksEnabled && genericAllowed
        ? providerModes.taskListMode
        : TaskListCreationMode.unavailable;
    final connected = account.isSignedIn;
    final nextcloudOnline = networkAvailability != NetworkAvailability.offline;
    return AccountCollectionCreationCapabilities(
      calendarMode: calendarMode,
      taskListMode: taskListMode,
      calendarActionEnabled:
          calendarMode != CalendarCollectionCreationMode.unavailable &&
          connected &&
          !calendarCreationRunning &&
          (!const {
                CalendarCollectionCreationMode.nextcloudDav,
                CalendarCollectionCreationMode.genericDav,
              }.contains(calendarMode) ||
              nextcloudOnline),
      taskListActionEnabled:
          taskListMode != TaskListCreationMode.unavailable &&
          connected &&
          !taskListCreationRunning &&
          (!const {
                TaskListCreationMode.nextcloudDav,
                TaskListCreationMode.genericDav,
              }.contains(taskListMode) ||
              nextcloudOnline),
    );
  }

  final CalendarCollectionCreationMode calendarMode;
  final TaskListCreationMode taskListMode;
  final bool calendarActionEnabled;
  final bool taskListActionEnabled;

  bool get supportsCalendarCreation =>
      calendarMode != CalendarCollectionCreationMode.unavailable;
  bool get supportsTaskListCreation =>
      taskListMode != TaskListCreationMode.unavailable;
  bool get hasActions => supportsCalendarCreation || supportsTaskListCreation;
}

final class AccountCollectionCreationModes {
  const AccountCollectionCreationModes({
    required this.calendarMode,
    required this.taskListMode,
  });

  final CalendarCollectionCreationMode calendarMode;
  final TaskListCreationMode taskListMode;
}

AccountCollectionCreationModes accountCollectionCreationModes(
  BusyProvider provider,
) => switch (provider) {
  BusyProvider.google ||
  BusyProvider.microsoft => const AccountCollectionCreationModes(
    calendarMode: CalendarCollectionCreationMode.cloudPendingOperation,
    taskListMode: TaskListCreationMode.cloudPendingOperation,
  ),
  BusyProvider.nextcloud => const AccountCollectionCreationModes(
    calendarMode: CalendarCollectionCreationMode.nextcloudDav,
    taskListMode: TaskListCreationMode.nextcloudDav,
  ),
  BusyProvider.caldav => const AccountCollectionCreationModes(
    calendarMode: CalendarCollectionCreationMode.genericDav,
    taskListMode: TaskListCreationMode.genericDav,
  ),
  BusyProvider.appleICloud ||
  BusyProvider.webCal => const AccountCollectionCreationModes(
    calendarMode: CalendarCollectionCreationMode.unavailable,
    taskListMode: TaskListCreationMode.unavailable,
  ),
};
