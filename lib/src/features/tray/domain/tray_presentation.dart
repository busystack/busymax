import 'package:collection/collection.dart';

import '../../../app/app_settings.dart';
import '../../connectivity/network_connectivity_service.dart';

final class BusyMaxTrayEventEntry {
  const BusyMaxTrayEventEntry({
    required this.eventId,
    required this.accountId,
    required this.calendarSourceId,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
  });

  final String eventId;
  final String accountId;
  final String calendarSourceId;
  final String title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;

  @override
  bool operator ==(Object other) =>
      other is BusyMaxTrayEventEntry &&
      other.eventId == eventId &&
      other.accountId == accountId &&
      other.calendarSourceId == calendarSourceId &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.allDay == allDay;

  @override
  int get hashCode => Object.hash(
    eventId,
    accountId,
    calendarSourceId,
    title,
    start,
    end,
    allDay,
  );
}

final class BusyMaxTrayPresentation {
  const BusyMaxTrayPresentation({
    required this.connectivity,
    required this.synchronizationRunning,
    required this.lastSuccessfulSynchronizationUtc,
    required this.events,
    required this.incompleteTasksDueToday,
    required this.canCreateEvent,
    required this.canCreateTask,
    required this.hasSyncEligibleAccount,
    required this.notificationDetailLevel,
    required this.localNow,
  });

  final NetworkAvailability connectivity;
  final bool synchronizationRunning;
  final DateTime? lastSuccessfulSynchronizationUtc;
  final List<BusyMaxTrayEventEntry> events;
  final int incompleteTasksDueToday;
  final bool canCreateEvent;
  final bool canCreateTask;
  final bool hasSyncEligibleAccount;
  final NotificationDetailLevel notificationDetailLevel;
  final DateTime localNow;

  @override
  bool operator ==(Object other) =>
      other is BusyMaxTrayPresentation &&
      other.connectivity == connectivity &&
      other.synchronizationRunning == synchronizationRunning &&
      other.lastSuccessfulSynchronizationUtc ==
          lastSuccessfulSynchronizationUtc &&
      const ListEquality<BusyMaxTrayEventEntry>().equals(
        other.events,
        events,
      ) &&
      other.incompleteTasksDueToday == incompleteTasksDueToday &&
      other.canCreateEvent == canCreateEvent &&
      other.canCreateTask == canCreateTask &&
      other.hasSyncEligibleAccount == hasSyncEligibleAccount &&
      other.notificationDetailLevel == notificationDetailLevel &&
      other.localNow == localNow;

  @override
  int get hashCode => Object.hash(
    connectivity,
    synchronizationRunning,
    lastSuccessfulSynchronizationUtc,
    const ListEquality<BusyMaxTrayEventEntry>().hash(events),
    incompleteTasksDueToday,
    canCreateEvent,
    canCreateTask,
    hasSyncEligibleAccount,
    notificationDetailLevel,
    localNow,
  );
}

final class BusyMaxTrayEventRowPresentation {
  const BusyMaxTrayEventRowPresentation({
    required this.event,
    required this.label,
  });

  final BusyMaxTrayEventEntry event;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is BusyMaxTrayEventRowPresentation &&
      other.event == event &&
      other.label == label;

  @override
  int get hashCode => Object.hash(event, label);
}

final class BusyMaxTrayMenuPresentation {
  const BusyMaxTrayMenuPresentation({
    required this.showBusyMaxLabel,
    required this.newEventLabel,
    required this.newTaskLabel,
    required this.todayLabel,
    required this.eventRows,
    required this.taskSummaryLabel,
    required this.emptyStateLabel,
    required this.openTodayAgendaLabel,
    required this.syncNowLabel,
    required this.synchronizationStatusLabel,
    required this.settingsLabel,
    required this.quitBusyMaxLabel,
    required this.offlineTitle,
    required this.offlineDescription,
    required this.canCreateEvent,
    required this.canCreateTask,
    required this.canSynchronize,
    required this.offline,
  });

  final String showBusyMaxLabel;
  final String newEventLabel;
  final String newTaskLabel;
  final String todayLabel;
  final List<BusyMaxTrayEventRowPresentation> eventRows;
  final String? taskSummaryLabel;
  final String emptyStateLabel;
  final String openTodayAgendaLabel;
  final String syncNowLabel;
  final String synchronizationStatusLabel;
  final String settingsLabel;
  final String quitBusyMaxLabel;
  final String offlineTitle;
  final String offlineDescription;
  final bool canCreateEvent;
  final bool canCreateTask;
  final bool canSynchronize;
  final bool offline;

  bool get showEmptyState => eventRows.isEmpty && taskSummaryLabel == null;

  @override
  bool operator ==(Object other) =>
      other is BusyMaxTrayMenuPresentation &&
      other.showBusyMaxLabel == showBusyMaxLabel &&
      other.newEventLabel == newEventLabel &&
      other.newTaskLabel == newTaskLabel &&
      other.todayLabel == todayLabel &&
      const ListEquality<BusyMaxTrayEventRowPresentation>().equals(
        other.eventRows,
        eventRows,
      ) &&
      other.taskSummaryLabel == taskSummaryLabel &&
      other.emptyStateLabel == emptyStateLabel &&
      other.openTodayAgendaLabel == openTodayAgendaLabel &&
      other.syncNowLabel == syncNowLabel &&
      other.synchronizationStatusLabel == synchronizationStatusLabel &&
      other.settingsLabel == settingsLabel &&
      other.quitBusyMaxLabel == quitBusyMaxLabel &&
      other.offlineTitle == offlineTitle &&
      other.offlineDescription == offlineDescription &&
      other.canCreateEvent == canCreateEvent &&
      other.canCreateTask == canCreateTask &&
      other.canSynchronize == canSynchronize &&
      other.offline == offline;

  @override
  int get hashCode => Object.hashAll([
    showBusyMaxLabel,
    newEventLabel,
    newTaskLabel,
    todayLabel,
    const ListEquality<BusyMaxTrayEventRowPresentation>().hash(eventRows),
    taskSummaryLabel,
    emptyStateLabel,
    openTodayAgendaLabel,
    syncNowLabel,
    synchronizationStatusLabel,
    settingsLabel,
    quitBusyMaxLabel,
    offlineTitle,
    offlineDescription,
    canCreateEvent,
    canCreateTask,
    canSynchronize,
    offline,
  ]);
}
