import '../../l10n/generated/app_localizations.dart';
import '../features/tray/domain/tray_presentation_formatter.dart';
import 'time_format_scope.dart';

BusyMaxTrayPresentationFormatter localizedTrayFormatter(
  AppLocalizations l10n,
  BusyMaxTimeFormatter clock,
) => BusyMaxTrayPresentationFormatter(
  BusyMaxTrayPresentationStrings(
    showBusyMax: l10n.trayShowBusyMax,
    newEvent: l10n.trayNewEvent,
    newTask: l10n.trayNewTask,
    today: l10n.trayToday,
    allDay: l10n.trayAllDay,
    now: l10n.trayNow,
    calendarEvent: l10n.trayCalendarEvent,
    untitledEvent: l10n.trayUntitledEvent,
    nothingElseToday: l10n.trayNothingElseToday,
    openTodayAgenda: l10n.trayOpenTodayAgenda,
    syncNow: l10n.traySyncNow,
    syncing: l10n.traySyncing,
    syncIssue: l10n.accountSyncProblem,
    notConnected: l10n.trayNotConnected,
    notYetSynced: l10n.trayNotYetSynced,
    settings: l10n.traySettings,
    quitBusyMax: l10n.trayQuitBusyMax,
    offline: l10n.networkOffline,
    offlineDescription: l10n.networkOfflineDescription,
    formatTime: clock.format,
    tasksDueToday: l10n.trayTasksDueToday,
    lastSyncedJustNow: l10n.trayLastSyncedJustNow,
    lastSyncedMinutesAgo: l10n.trayLastSyncedMinutesAgo,
    lastSyncedHoursAgo: l10n.trayLastSyncedHoursAgo,
    lastSyncedDaysAgo: l10n.trayLastSyncedDaysAgo,
  ),
);
