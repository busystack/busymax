import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as paths;

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

final class WindowsTrayService implements DesktopTrayService {
  WindowsTrayService({
    required Future<BusyMaxTrayMenuPresentation> Function() loadPresentation,
    required Future<void> Function(WindowsTrayCommand command) onCommand,
    this.onUnavailable,
    this.iconPath = 'assets/windows/busymax_tray.ico',
    this.offlineIconPath = 'assets/windows/busymax_tray_offline.ico',
  }) : _loadPresentation = loadPresentation,
       _onCommand = onCommand;

  final Future<BusyMaxTrayMenuPresentation> Function() _loadPresentation;
  final Future<void> Function(WindowsTrayCommand command) _onCommand;
  final Future<void> Function(String? errorCode)? onUnavailable;
  final String iconPath;
  final String offlineIconPath;
  bool _available = false;
  bool _healthHandlerAttached = false;
  String? _lastFailure;
  final _logger = Logger('busymax.windows.tray');
  static const _healthChannel = MethodChannel('busymax/windows/tray');
  final Map<int, WindowsTrayCommand> _commands = {};

  String _assetPath(String asset) {
    if (paths.isAbsolute(asset) || paths.split(asset).contains('..')) {
      throw ArgumentError.value(asset, 'asset', 'Expected a bundled asset');
    }
    return paths.join(
      paths.dirname(Platform.resolvedExecutable),
      'data',
      'flutter_assets',
      asset,
    );
  }

  @override
  bool get isAvailable => _available;

  String? get lastFailure => _lastFailure;

  @override
  Future<bool> start() async {
    if (_available) return true;
    try {
      if (!_healthHandlerAttached) {
        _healthChannel.setMethodCallHandler(_handleHealthEvent);
        _healthHandlerAttached = true;
      }
      await _healthChannel.invokeMethod<void>('setIcon', _assetPath(iconPath));
      await _healthChannel.invokeMethod<void>('setToolTip', 'BusyMax');
      _available = true;
      _lastFailure = null;
      await refresh();
      return _available;
    } on Object {
      _lastFailure = 'tray-initialization-failed';
      _logger.warning('The Windows tray could not be initialized.');
      _available = false;
      try {
        await _healthChannel.invokeMethod<void>('destroy');
      } on Object {
        // A failed installation may have no notification-area host to remove.
      }
      await onUnavailable?.call(_lastFailure);
      return false;
    }
  }

  @override
  Future<void> refresh() async {
    if (!_available) return;
    try {
      final presentation = await _loadPresentation();
      await _healthChannel.invokeMethod<void>('setMenu', _menu(presentation));
      await _healthChannel.invokeMethod<void>(
        'setToolTip',
        presentation.offline
            ? 'BusyMax — ${presentation.offlineTitle}'
            : 'BusyMax',
      );
      // Reapplying the icon also recovers the tray after Explorer recreates
      // its notification area.
      await _healthChannel.invokeMethod<void>(
        'setIcon',
        _assetPath(presentation.offline ? offlineIconPath : iconPath),
      );
    } on Object {
      _lastFailure = 'tray-refresh-failed';
      _logger.warning('The Windows tray could not be refreshed.');
      _available = false;
      try {
        await _healthChannel.invokeMethod<void>('destroy');
      } on Object {
        // Explorer may already have discarded the old tray host.
      }
      await onUnavailable?.call(_lastFailure);
    }
  }

  Future<Object?> _handleHealthEvent(MethodCall call) async {
    if (call.method == 'open') {
      await _onCommand(WindowsTrayCommand.open);
      return null;
    }
    if (call.method == 'command') {
      final command = _commands[call.arguments];
      if (command != null) await _onCommand(command);
      return null;
    }
    if (call.method == 'onMenuFailure') {
      _lastFailure = 'tray-menu-display-failed';
      await onUnavailable?.call(_lastFailure);
      return null;
    }
    if (call.method != 'onTrayAvailabilityChanged') return null;
    final arguments = call.arguments;
    if (arguments is! Map) return null;
    final available = arguments['available'] == true;
    _available = available;
    if (available) {
      _lastFailure = null;
      return null;
    }
    final error = arguments['errorCode'];
    _lastFailure =
        error is String &&
            error.length <= 96 &&
            RegExp(r'^tray-[a-z0-9-]+$').hasMatch(error)
        ? error
        : 'tray-native-recovery-failed';
    _logger.warning('The Windows tray became unavailable.');
    await onUnavailable?.call(_lastFailure);
    return null;
  }

  List<Map<String, Object>> _menu(BusyMaxTrayMenuPresentation value) {
    _commands.clear();
    var nextId = 0x5100;
    Map<String, Object> separator() => {
      'id': nextId++,
      'label': '',
      'disabled': true,
      'separator': true,
    };
    Map<String, Object> item(
      String key,
      String label, {
      bool enabled = true,
      WindowsTrayCommand? command,
    }) {
      // An event-list refresh must never turn a queued Settings activation
      // into another command because the number of agenda rows changed.
      final id = command == null ? nextId++ : 0x5000 + command.index;
      if (command != null && enabled) _commands[id] = command;
      return {
        'id': id,
        'key': key,
        'label': label,
        'disabled': !enabled || command == null,
        'separator': false,
      };
    }

    return [
      item('open', value.showBusyMaxLabel, command: WindowsTrayCommand.open),
      separator(),
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
      separator(),
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
      separator(),
      item(
        'sync',
        value.syncNowLabel,
        enabled: value.canSynchronize,
        command: WindowsTrayCommand.synchronize,
      ),
      item('sync-status', value.synchronizationStatusLabel),
      separator(),
      item(
        'settings',
        value.settingsLabel,
        command: WindowsTrayCommand.settings,
      ),
      item('quit', value.quitBusyMaxLabel, command: WindowsTrayCommand.quit),
    ];
  }

  @override
  Future<void> stop() async {
    try {
      await _healthChannel.invokeMethod<void>('destroy');
    } on Object {
      // Quit must not be blocked by an unavailable Explorer tray host.
    }
    _available = false;
    _commands.clear();
    if (_healthHandlerAttached) {
      _healthChannel.setMethodCallHandler(null);
      _healthHandlerAttached = false;
    }
  }
}
