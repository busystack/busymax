import '../../../app/app_settings.dart';
import '../../connectivity/network_connectivity_service.dart';
import 'tray_presentation.dart';

final class BusyMaxTrayPresentationStrings {
  const BusyMaxTrayPresentationStrings({
    required this.showBusyMax,
    required this.newEvent,
    required this.newTask,
    required this.today,
    required this.allDay,
    required this.now,
    required this.calendarEvent,
    required this.untitledEvent,
    required this.nothingElseToday,
    required this.openTodayAgenda,
    required this.syncNow,
    required this.syncing,
    required this.notConnected,
    required this.notYetSynced,
    required this.settings,
    required this.quitBusyMax,
    required this.offline,
    required this.offlineDescription,
    required this.formatTime,
    required this.tasksDueToday,
    required this.lastSyncedJustNow,
    required this.lastSyncedMinutesAgo,
    required this.lastSyncedHoursAgo,
    required this.lastSyncedDaysAgo,
  });

  final String showBusyMax;
  final String newEvent;
  final String newTask;
  final String today;
  final String allDay;
  final String now;
  final String calendarEvent;
  final String untitledEvent;
  final String nothingElseToday;
  final String openTodayAgenda;
  final String syncNow;
  final String syncing;
  final String notConnected;
  final String notYetSynced;
  final String settings;
  final String quitBusyMax;
  final String offline;
  final String offlineDescription;
  final String Function(DateTime value) formatTime;
  final String Function(int count) tasksDueToday;
  final String lastSyncedJustNow;
  final String Function(int count) lastSyncedMinutesAgo;
  final String Function(int count) lastSyncedHoursAgo;
  final String Function(int count) lastSyncedDaysAgo;
}

final class BusyMaxTrayPresentationFormatter {
  const BusyMaxTrayPresentationFormatter(this.strings);

  final BusyMaxTrayPresentationStrings strings;

  BusyMaxTrayMenuPresentation format(BusyMaxTrayPresentation presentation) {
    final eventRows = [
      for (final event in presentation.events)
        BusyMaxTrayEventRowPresentation(
          event: event,
          label: _eventLabel(event, presentation),
        ),
    ];
    final offline = presentation.connectivity == NetworkAvailability.offline;
    return BusyMaxTrayMenuPresentation(
      showBusyMaxLabel: strings.showBusyMax,
      newEventLabel: strings.newEvent,
      newTaskLabel: strings.newTask,
      todayLabel: strings.today,
      eventRows: List.unmodifiable(eventRows),
      taskSummaryLabel: presentation.incompleteTasksDueToday == 0
          ? null
          : strings.tasksDueToday(presentation.incompleteTasksDueToday),
      emptyStateLabel: strings.nothingElseToday,
      openTodayAgendaLabel: strings.openTodayAgenda,
      syncNowLabel: strings.syncNow,
      synchronizationStatusLabel: _synchronizationStatus(presentation),
      settingsLabel: strings.settings,
      quitBusyMaxLabel: strings.quitBusyMax,
      offlineTitle: strings.offline,
      offlineDescription: strings.offlineDescription,
      canCreateEvent: presentation.canCreateEvent,
      canCreateTask: presentation.canCreateTask,
      canSynchronize:
          presentation.connectivity == NetworkAvailability.online &&
          presentation.hasSyncEligibleAccount &&
          !presentation.synchronizationRunning,
      offline: offline,
    );
  }

  String _eventLabel(
    BusyMaxTrayEventEntry event,
    BusyMaxTrayPresentation presentation,
  ) {
    final prefix = event.allDay
        ? strings.allDay
        : _isInProgress(event, presentation.localNow)
        ? strings.now
        : strings.formatTime(event.start);
    final title =
        presentation.notificationDetailLevel == NotificationDetailLevel.private
        ? strings.calendarEvent
        : _sanitizeTitle(event.title);
    return _truncate('$prefix · $title', 100);
  }

  String _sanitizeTitle(String source) {
    final withoutControls = source.replaceAll(
      RegExp(r'[\u0000-\u001f\u007f-\u009f]'),
      ' ',
    );
    final collapsed = withoutControls.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.isEmpty ? strings.untitledEvent : collapsed;
  }

  String _synchronizationStatus(BusyMaxTrayPresentation presentation) {
    if (presentation.connectivity == NetworkAvailability.offline) {
      return '${strings.offline} — ${strings.offlineDescription}';
    }
    if (presentation.synchronizationRunning) return strings.syncing;
    if (!presentation.hasSyncEligibleAccount) return strings.notConnected;
    final lastSync = presentation.lastSuccessfulSynchronizationUtc;
    if (lastSync == null) return strings.notYetSynced;
    final elapsed = presentation.localNow.toUtc().difference(lastSync);
    if (elapsed <= Duration.zero || elapsed.inMinutes < 1) {
      return strings.lastSyncedJustNow;
    }
    if (elapsed.inHours < 1) {
      return strings.lastSyncedMinutesAgo(elapsed.inMinutes);
    }
    if (elapsed.inDays < 1) {
      return strings.lastSyncedHoursAgo(elapsed.inHours);
    }
    return strings.lastSyncedDaysAgo(elapsed.inDays);
  }
}

bool _isInProgress(BusyMaxTrayEventEntry event, DateTime now) {
  final end = event.end;
  return !event.start.isAfter(now) && end != null && end.isAfter(now);
}

String _truncate(String value, int maximumRunes) {
  final runes = value.runes.toList(growable: false);
  if (runes.length <= maximumRunes) return value;
  return '${String.fromCharCodes(runes.take(maximumRunes - 1))}…';
}
