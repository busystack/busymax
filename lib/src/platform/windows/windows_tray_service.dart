import 'dart:async';

import 'package:tray_manager/tray_manager.dart';

import '../../features/tray/domain/tray_presentation.dart';
import '../common/desktop_services.dart';

enum WindowsTrayCommand {
  open,
  newEvent,
  newTask,
  today,
  synchronize,
  settings,
  quit,
}

final class WindowsTrayService with TrayListener implements DesktopTrayService {
  WindowsTrayService({
    required Future<BusyMaxTrayMenuPresentation> Function() loadPresentation,
    required Future<void> Function(WindowsTrayCommand command) onCommand,
    this.iconPath = 'assets/windows/busymax_tray.ico',
    this.offlineIconPath = 'assets/windows/busymax_tray_offline.ico',
  }) : _loadPresentation = loadPresentation,
       _onCommand = onCommand;

  final Future<BusyMaxTrayMenuPresentation> Function() _loadPresentation;
  final Future<void> Function(WindowsTrayCommand command) _onCommand;
  final String iconPath;
  final String offlineIconPath;
  bool _available = false;
  bool _listenerAttached = false;

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> start() async {
    if (_available) return true;
    try {
      if (!_listenerAttached) {
        trayManager.addListener(this);
        _listenerAttached = true;
      }
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('BusyMax');
      _available = true;
      await refresh();
      return _available;
    } on Object {
      _removeListener();
      _available = false;
      return false;
    }
  }

  @override
  Future<void> refresh() async {
    if (!_available) return;
    try {
      final presentation = await _loadPresentation();
      await trayManager.setContextMenu(_menu(presentation));
      await trayManager.setToolTip(
        presentation.offline
            ? 'BusyMax — ${presentation.offlineTitle}'
            : 'BusyMax',
      );
      // Reapplying the icon also recovers the tray after Explorer recreates
      // its notification area.
      await trayManager.setIcon(
        presentation.offline ? offlineIconPath : iconPath,
      );
    } on Object {
      _removeListener();
      _available = false;
      try {
        await trayManager.destroy();
      } on Object {
        // Explorer may already have discarded the old tray host.
      }
    }
  }

  Menu _menu(BusyMaxTrayMenuPresentation value) {
    MenuItem item(
      String key,
      String label, {
      bool enabled = true,
      WindowsTrayCommand? command,
    }) => MenuItem(
      key: key,
      label: label,
      disabled: !enabled,
      onClick: command == null ? null : (_) => unawaited(_onCommand(command)),
    );

    return Menu(
      items: [
        item('open', value.showBusyMaxLabel, command: WindowsTrayCommand.open),
        MenuItem.separator(),
        item(
          'new-event',
          value.newEventLabel,
          enabled: value.canCreateEvent,
          command: WindowsTrayCommand.newEvent,
        ),
        item(
          'new-task',
          value.newTaskLabel,
          enabled: value.canCreateTask,
          command: WindowsTrayCommand.newTask,
        ),
        MenuItem.separator(),
        item('today-label', value.todayLabel),
        ...value.eventRows.map(
          (row) => item(
            'event:${row.event.eventId}',
            row.label,
            command: WindowsTrayCommand.today,
          ),
        ),
        if (value.taskSummaryLabel != null)
          item(
            'tasks-today',
            value.taskSummaryLabel!,
            command: WindowsTrayCommand.today,
          ),
        if (value.showEmptyState) item('empty', value.emptyStateLabel),
        item(
          'today',
          value.openTodayAgendaLabel,
          command: WindowsTrayCommand.today,
        ),
        MenuItem.separator(),
        item(
          'sync',
          value.syncNowLabel,
          enabled: value.canSynchronize,
          command: WindowsTrayCommand.synchronize,
        ),
        item('sync-status', value.synchronizationStatusLabel),
        MenuItem.separator(),
        item(
          'settings',
          value.settingsLabel,
          command: WindowsTrayCommand.settings,
        ),
        item('quit', value.quitBusyMaxLabel, command: WindowsTrayCommand.quit),
      ],
    );
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_onCommand(WindowsTrayCommand.open));
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    // MenuItem callbacks are used so the adapter also works on plugin builds
    // that do not emit this listener callback on Windows.
  }

  @override
  Future<void> stop() async {
    _removeListener();
    try {
      await trayManager.destroy();
    } on Object {
      // Quit must not be blocked by an unavailable Explorer tray host.
    }
    _available = false;
  }

  void _removeListener() {
    if (!_listenerAttached) return;
    trayManager.removeListener(this);
    _listenerAttached = false;
  }
}
