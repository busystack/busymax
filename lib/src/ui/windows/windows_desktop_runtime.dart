import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../features/tray/domain/tray_presentation_formatter.dart';
import '../../platform/common/desktop_services.dart';
import '../../platform/windows/windows_tray_service.dart';
import 'windows_event_editor_dialog.dart';
import 'windows_task_editor_dialog.dart';

bool shouldWindowsHideOnClose({
  required bool runInBackgroundWhenClosed,
  required bool trayAvailable,
}) => runInBackgroundWhenClosed && trayAvailable;

class WindowsDesktopRuntime extends ConsumerStatefulWidget {
  const WindowsDesktopRuntime({
    required this.child,
    required this.startMinimizedAtLaunch,
    super.key,
  });

  final Widget child;
  final bool startMinimizedAtLaunch;

  @override
  ConsumerState<WindowsDesktopRuntime> createState() =>
      _WindowsDesktopRuntimeState();
}

class _WindowsDesktopRuntimeState extends ConsumerState<WindowsDesktopRuntime> {
  WindowsTrayService? _tray;
  BusyMaxTrayPresentationFormatter? _formatter;
  Timer? _refreshTimer;
  bool _configurationRunning = false;
  bool _configurationPending = false;
  bool _startMinimizedHandled = false;
  String? _localeTag;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final tray = _tray;
    if (tray != null) unawaited(tray.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_localeTag != locale || _formatter == null) {
      _localeTag = locale;
      _formatter = BusyMaxTrayPresentationFormatter(
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
          notConnected: l10n.trayNotConnected,
          notYetSynced: l10n.trayNotYetSynced,
          settings: l10n.traySettings,
          quitBusyMax: l10n.trayQuitBusyMax,
          offline: l10n.networkOffline,
          offlineDescription: l10n.networkOfflineDescription,
          formatTime: (value) => DateFormat.jm(locale).format(value),
          tasksDueToday: l10n.trayTasksDueToday,
          lastSyncedJustNow: l10n.trayLastSyncedJustNow,
          lastSyncedMinutesAgo: l10n.trayLastSyncedMinutesAgo,
          lastSyncedHoursAgo: l10n.trayLastSyncedHoursAgo,
          lastSyncedDaysAgo: l10n.trayLastSyncedDaysAgo,
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_configure(settings));
    });
    return widget.child;
  }

  Future<void> _configure(AppSettings settings) async {
    if (_configurationRunning) {
      _configurationPending = true;
      return;
    }
    _configurationRunning = true;
    try {
      final needsTray =
          settings.showTrayIcon ||
          settings.runInBackgroundWhenClosed ||
          settings.startMinimizedToTray ||
          widget.startMinimizedAtLaunch;
      final window = ref.read(desktopWindowServiceProvider);
      if (!needsTray) {
        await window.setHideOnClose(false);
        await _tray?.stop();
        ref.read(desktopTrayDiagnosticProvider.notifier).state = null;
        _refreshTimer?.cancel();
        _refreshTimer = null;
        return;
      }
      final tray = _tray ??= WindowsTrayService(
        loadPresentation: () async {
          final presentation = await ref
              .read(trayPresentationServiceProvider)
              .load();
          return _formatter!.format(presentation);
        },
        onCommand: _handleCommand,
        onUnavailable: (errorCode) async {
          ref.read(desktopTrayDiagnosticProvider.notifier).state =
              errorCode ?? 'tray-unavailable';
          // Explorer recovery and native tray failures must never strand an
          // otherwise healthy process with no reachable window.
          await window.setHideOnClose(false);
          await window.showWindow();
        },
      );
      var available = tray.isAvailable || await tray.start();
      if (available) {
        await tray.refresh();
        available = tray.isAvailable;
      }
      await window.setHideOnClose(
        shouldWindowsHideOnClose(
          runInBackgroundWhenClosed: settings.runInBackgroundWhenClosed,
          trayAvailable: available,
        ),
      );
      if (!available) {
        // Never strand a process without either a visible window or tray.
        await window.showWindow();
      } else {
        ref.read(desktopTrayDiagnosticProvider.notifier).state = null;
      }
      _refreshTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) {
          unawaited(_configure(ref.read(appSettingsControllerProvider)));
        }
      });
      if (!_startMinimizedHandled &&
          (widget.startMinimizedAtLaunch || settings.startMinimizedToTray)) {
        _startMinimizedHandled = true;
        if (available) {
          await window.hideWindow();
        } else {
          await window.showWindow();
        }
      }
    } finally {
      _configurationRunning = false;
      if (_configurationPending && mounted) {
        _configurationPending = false;
        unawaited(_configure(ref.read(appSettingsControllerProvider)));
      }
    }
  }

  Future<void> _handleCommand(WindowsTrayCommand command) async {
    final window = ref.read(desktopWindowServiceProvider);
    switch (command) {
      case WindowsTrayCommand.open:
        await window.showWindow();
      case WindowsTrayCommand.newEvent:
        await window.showWindow();
        ref
            .read(desktopNavigationServiceProvider)
            .open(DesktopNavigationDestination.schedule);
        await WidgetsBinding.instance.endOfFrame;
        final context = this.context;
        if (context.mounted) {
          await showWindowsEventEditorDialog(context, ref);
        }
      case WindowsTrayCommand.newTask:
        await window.showWindow();
        ref
            .read(desktopNavigationServiceProvider)
            .open(DesktopNavigationDestination.tasks);
        await WidgetsBinding.instance.endOfFrame;
        final context = this.context;
        if (context.mounted) await showWindowsTaskEditorDialog(context, ref);
      case WindowsTrayCommand.today:
        await window.showWindow();
        ref
            .read(desktopNavigationServiceProvider)
            .open(DesktopNavigationDestination.schedule);
      case WindowsTrayCommand.synchronize:
        await ref.read(allAccountsSyncRunnerProvider)();
        await _tray?.refresh();
      case WindowsTrayCommand.settings:
        await window.showWindow();
        ref
            .read(desktopNavigationServiceProvider)
            .open(DesktopNavigationDestination.settings);
      case WindowsTrayCommand.quit:
        ref.read(notificationSchedulerProvider).stop();
        ref.read(syncSchedulerProvider).stop();
        try {
          await _tray?.stop();
        } on Object {
          // Continue deterministic shutdown even if Explorer is unavailable.
        }
        try {
          await ref.read(desktopNotificationBackendProvider).close();
        } on Object {
          // The package notification host may already be disconnected.
        }
        try {
          await ref.read(databaseProvider).close();
        } on Object {
          // Native quit remains the final step so no invisible process lingers.
        }
        await window.quitApp();
    }
  }
}
