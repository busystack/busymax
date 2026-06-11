import 'dart:async';
import 'dart:io';

import 'package:xdg_status_notifier_item/xdg_status_notifier_item.dart';

import 'linux_window_service.dart';

const String busyMaxApplicationId = 'io.busystack.busymax';

class BusyMaxTrayLabels {
  const BusyMaxTrayLabels({
    required this.openBusyMax,
    required this.agenda,
    required this.quitBusyMax,
  });

  final String openBusyMax;
  final String agenda;
  final String quitBusyMax;

  @override
  bool operator ==(Object other) {
    return other is BusyMaxTrayLabels &&
        other.openBusyMax == openBusyMax &&
        other.agenda == agenda &&
        other.quitBusyMax == quitBusyMax;
  }

  @override
  int get hashCode => Object.hash(openBusyMax, agenda, quitBusyMax);
}

class BusyMaxTrayService {
  BusyMaxTrayService({
    required LinuxWindowService windowService,
    required BusyMaxTrayLabels labels,
    required Future<void> Function() onOpenAgenda,
    Future<void> Function()? onBeforeQuit,
  }) : _windowService = windowService,
       _labels = labels,
       _onOpenAgenda = onOpenAgenda,
       _onBeforeQuit = onBeforeQuit;

  final LinuxWindowService _windowService;
  final Future<void> Function() _onOpenAgenda;
  final Future<void> Function()? _onBeforeQuit;
  BusyMaxTrayLabels _labels;

  StatusNotifierItemClient? _client;
  bool _available = false;

  bool get available => _available;

  Future<void> start() async {
    if (_client != null) {
      return;
    }
    final client = StatusNotifierItemClient(
      id: busyMaxApplicationId,
      title: 'BusyMax',
      iconName: _trayIconName(),
      menu: buildBusyMaxTrayMenu(
        labels: _labels,
        onOpenBusyMax: _show,
        onOpenAgenda: _showAgenda,
        onQuit: _quit,
      ),
      onActivate: (_, _) => _show(),
    );
    try {
      await client.connect();
      _client = client;
      _available = true;
    } on Object {
      _available = false;
      await client.close();
    }
  }

  Future<void> stop() async {
    final client = _client;
    _client = null;
    _available = false;
    await client?.close();
  }

  Future<void> updateLabels(BusyMaxTrayLabels labels) async {
    if (_labels == labels) {
      return;
    }
    _labels = labels;
    await _updateMenu();
  }

  Future<void> _updateMenu() async {
    final client = _client;
    if (client == null) {
      return;
    }
    await client.updateMenu(
      buildBusyMaxTrayMenu(
        labels: _labels,
        onOpenBusyMax: _show,
        onOpenAgenda: _showAgenda,
        onQuit: _quit,
      ),
    );
  }

  Future<void> _show() {
    return _windowService.showWindow();
  }

  Future<void> _showAgenda() {
    return _onOpenAgenda();
  }

  Future<void> _quit() async {
    await _onBeforeQuit?.call();
    await stop();
    await _windowService.quitApp();
  }
}

DBusMenuItem buildBusyMaxTrayMenu({
  required BusyMaxTrayLabels labels,
  required Future<void> Function() onOpenBusyMax,
  required Future<void> Function() onOpenAgenda,
  required Future<void> Function() onQuit,
}) {
  return DBusMenuItem(
    children: [
      DBusMenuItem(label: labels.openBusyMax, onClicked: onOpenBusyMax),
      DBusMenuItem(label: labels.agenda, onClicked: onOpenAgenda),
      DBusMenuItem(label: labels.quitBusyMax, onClicked: onQuit),
    ],
  );
}

String _trayIconName() {
  final executableDir = File(Platform.resolvedExecutable).parent;
  final bundledLogo = File(
    '${executableDir.path}/data/flutter_assets/assets/branding/busymax-logo.png',
  );
  if (bundledLogo.existsSync()) {
    return bundledLogo.path;
  }
  return busyMaxApplicationId;
}
