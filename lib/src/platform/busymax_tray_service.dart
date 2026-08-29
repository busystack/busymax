import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';
import 'package:xdg_status_notifier_item/xdg_status_notifier_item.dart';

import '../core/logging/redacting_logger.dart';
import 'linux_window_service.dart';

const String busyMaxApplicationId = 'io.busystack.busymax';
const String busyMaxTrayMenuPath = '/StatusNotifierItem/menu';
const int _busyMaxTrayRootMenuId = 0;
const int _busyMaxTrayOpenMenuId = 1;
const int _busyMaxTrayAgendaMenuId = 2;
const int _busyMaxTrayQuitMenuId = 3;
const int _busyMaxTrayOfflineMenuId = 4;

class BusyMaxTrayLabels {
  const BusyMaxTrayLabels({
    required this.openBusyMax,
    required this.agenda,
    required this.quitBusyMax,
    required this.offline,
    required this.offlineDescription,
  });

  final String openBusyMax;
  final String agenda;
  final String quitBusyMax;
  final String offline;
  final String offlineDescription;

  @override
  bool operator ==(Object other) {
    return other is BusyMaxTrayLabels &&
        other.openBusyMax == openBusyMax &&
        other.agenda == agenda &&
        other.quitBusyMax == quitBusyMax &&
        other.offline == offline &&
        other.offlineDescription == offlineDescription;
  }

  @override
  int get hashCode => Object.hash(
    openBusyMax,
    agenda,
    quitBusyMax,
    offline,
    offlineDescription,
  );
}

class BusyMaxTrayService {
  BusyMaxTrayService({
    required LinuxWindowService windowService,
    required BusyMaxTrayLabels labels,
    required Future<void> Function() onOpenAgenda,
  }) : _windowService = windowService,
       _labels = labels,
       _onOpenAgenda = onOpenAgenda;

  final LinuxWindowService _windowService;
  final Future<void> Function() _onOpenAgenda;
  BusyMaxTrayLabels _labels;
  final RedactingLogger _logger = RedactingLogger(Logger('BusyMaxTrayService'));

  StatusNotifierItemClient? _client;
  bool _available = false;
  bool _offline = false;

  bool get available => _available;

  Future<void> start() async {
    _logger.fine('Tray service start requested: snap=${_isRunningInSnap()}');
    if (_client != null) {
      _logger.fine('Tray initialization skipped: existing_client=true');
      return;
    }
    final iconName = _trayIconName(offline: _offline);
    final initialLabels = _labels;
    final initialOffline = _offline;
    _logger.fine(
      'DBus menu creation starting: path=$busyMaxTrayMenuPath '
      'root_id=$_busyMaxTrayRootMenuId '
      'open_id=$_busyMaxTrayOpenMenuId agenda_id=$_busyMaxTrayAgendaMenuId '
      'quit_id=$_busyMaxTrayQuitMenuId',
    );
    final menu = buildBusyMaxTrayMenu(
      labels: _labels,
      offline: _offline,
      onOpenBusyMax: _show,
      onOpenAgenda: _showAgenda,
      onQuit: _quit,
    );
    _logger.fine(
      'DBus menu creation completed: path=$busyMaxTrayMenuPath '
      'items=${menu.children.length} '
      'ids=${menu.children.map((item) => item.id).join(',')}',
    );
    _logger.fine(
      'Tray initialization starting: snap=${_isRunningInSnap()} '
      'icon=${_sanitizeIconForLog(iconName)} menu_items=${menu.children.length}',
    );
    final client = StatusNotifierItemClient(
      id: busyMaxApplicationId,
      title: _trayTitle,
      iconName: iconName,
      toolTipTitle: _trayTitle,
      toolTipDescription: _trayToolTipDescription,
      itemIsMenu: true,
      menuPath: DBusObjectPath(busyMaxTrayMenuPath),
      menu: menu,
      diagnosticLog: (message) =>
          _logger.fine(_sanitizeForLog('StatusNotifier diagnostic: $message')),
      onContextMenu: (x, y) async {
        _logger.fine(
          'Tray context menu callback fired: snap=${_isRunningInSnap()} '
          'x=$x y=$y fallback=showWindow',
        );
        await _showFromStatusNotifierActivation(
          action: 'StatusNotifierItem context menu callback',
        );
      },
      onActivate: (x, y) {
        _logger.fine(
          'Tray activation callback fired: snap=${_isRunningInSnap()} '
          'x=$x y=$y',
        );
        return _showFromStatusNotifierActivation(
          action: 'StatusNotifierItem activation callback',
        );
      },
      onSecondaryActivate: (x, y) async {
        _logger.fine(
          'Tray secondary activation callback fired: snap=${_isRunningInSnap()} '
          'x=$x y=$y fallback=showWindow',
        );
        await _showFromStatusNotifierActivation(
          action: 'StatusNotifierItem secondary activation callback',
        );
      },
    );
    try {
      await client.connect();
      _client = client;
      _available = true;
      if (_labels != initialLabels || _offline != initialOffline) {
        await _updateClientPresentation();
        await _updateMenu();
      }
      final menuVerified = await _verifyMenuExported();
      _logger.fine(
        'StatusNotifier registration succeeded: snap=${_isRunningInSnap()} '
        'bus_name=${client.busName} item_path=${client.itemPath.value} '
        'menu_path=${client.menuPath.value} menu_exported=$menuVerified '
        'menu_items=${menu.children.length}',
      );
    } on Object catch (error) {
      _client = null;
      _available = false;
      _logger.warning(
        'StatusNotifier registration failed: snap=${_isRunningInSnap()} '
        'error=${_sanitizeForLog(error)}',
      );
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
    _logger.fine('Tray labels updating');
    await _updateClientPresentation();
    await _updateMenu();
  }

  Future<void> updateOfflineState(bool offline) async {
    if (_offline == offline) {
      return;
    }
    _offline = offline;
    _logger.fine('Tray connectivity presentation updating: offline=$offline');
    await _updateClientPresentation();
    await _updateMenu();
  }

  String get _trayTitle =>
      _offline ? 'BusyMax — ${_labels.offline}' : 'BusyMax';

  String get _trayToolTipDescription =>
      _offline ? _labels.offlineDescription : '';

  Future<void> _updateClientPresentation() async {
    final client = _client;
    if (client == null) {
      return;
    }
    await client.updatePresentation(
      title: _trayTitle,
      iconName: _trayIconName(offline: _offline),
      toolTipTitle: _trayTitle,
      toolTipDescription: _trayToolTipDescription,
    );
  }

  Future<void> _updateMenu() async {
    final client = _client;
    if (client == null) {
      return;
    }
    final menu = buildBusyMaxTrayMenu(
      labels: _labels,
      offline: _offline,
      onOpenBusyMax: _show,
      onOpenAgenda: _showAgenda,
      onQuit: _quit,
    );
    await client.updateMenu(menu);
    _logger.fine(
      'Tray menu update completed: menu_items=${menu.children.length}',
    );
  }

  Future<void> _showFromStatusNotifierActivation({required String action}) {
    return _runLoggedTrayAction(
      logger: _logger,
      action: action,
      callback: _show,
    );
  }

  Future<void> _show() {
    _logger.fine(
      'Tray restore requested: action=showWindow target=main_window',
    );
    return _windowService.showWindow();
  }

  Future<void> _showAgenda() {
    return _onOpenAgenda();
  }

  Future<void> _quit() async {
    _logger.fine('Tray quit requested: action=quitApp');
    unawaited(_stopAfterQuitRequest());
    await _windowService.quitApp();
  }

  Future<void> _stopAfterQuitRequest() async {
    try {
      await stop();
      _logger.fine('Tray client close completed after quit request');
    } on Object catch (error) {
      _logger.warning(
        'Tray client close failed after quit request: '
        'error=${_sanitizeForLog(error)}',
      );
    }
  }

  Future<bool> _verifyMenuExported() async {
    final bus = DBusClient.session();
    try {
      final response = await bus
          .callMethod(
            destination: 'org.kde.StatusNotifierItem-$pid-1',
            path: DBusObjectPath(busyMaxTrayMenuPath),
            interface: 'com.canonical.dbusmenu',
            name: 'GetLayout',
            values: [
              const DBusInt32(0),
              const DBusInt32(-1),
              DBusArray.string(const []),
            ],
            replySignature: DBusSignature('u(ia{sv}av)'),
          )
          .timeout(const Duration(seconds: 2));
      final layout = response.returnValues[1].asStruct();
      final children = layout.length >= 3 ? layout[2].asArray() : <DBusValue>[];
      final childIds = children
          .map((child) => _asMenuLayoutStruct(child)[0].asInt32())
          .join(',');
      _logger.fine(
        'Tray menu DBus verification succeeded: path=$busyMaxTrayMenuPath '
        'children=${children.length} child_ids=$childIds',
      );
      return children.isNotEmpty;
    } on Object catch (error) {
      _logger.warning(
        'Tray menu DBus verification failed: path=$busyMaxTrayMenuPath '
        'error=${_sanitizeForLog(error)}',
      );
      return false;
    } finally {
      await bus.close();
    }
  }
}

List<DBusValue> _asMenuLayoutStruct(DBusValue value) {
  if (value.signature == DBusSignature('v')) {
    return value.asVariant().asStruct();
  }
  return value.asStruct();
}

DBusMenuItem buildBusyMaxTrayMenu({
  required BusyMaxTrayLabels labels,
  bool offline = false,
  required Future<void> Function() onOpenBusyMax,
  required Future<void> Function() onOpenAgenda,
  required Future<void> Function() onQuit,
}) {
  return DBusMenuItem(
    id: _busyMaxTrayRootMenuId,
    enabled: true,
    visible: true,
    children: [
      if (offline)
        DBusMenuItem(
          id: _busyMaxTrayOfflineMenuId,
          enabled: false,
          visible: true,
          label: '${labels.offline} — ${labels.offlineDescription}',
        ),
      DBusMenuItem(
        id: _busyMaxTrayOpenMenuId,
        enabled: true,
        visible: true,
        label: labels.openBusyMax,
        onClicked: () => _runLoggedTrayAction(
          logger: RedactingLogger(Logger('BusyMaxTrayService')),
          action: 'Tray menu "Open BusyMax" callback',
          callback: onOpenBusyMax,
        ),
      ),
      DBusMenuItem(
        id: _busyMaxTrayAgendaMenuId,
        enabled: true,
        visible: true,
        label: labels.agenda,
        onClicked: () => _runLoggedTrayAction(
          logger: RedactingLogger(Logger('BusyMaxTrayService')),
          action: 'Tray menu "Agenda" callback',
          callback: onOpenAgenda,
        ),
      ),
      DBusMenuItem(
        id: _busyMaxTrayQuitMenuId,
        enabled: true,
        visible: true,
        label: labels.quitBusyMax,
        onClicked: () => _runLoggedTrayAction(
          logger: RedactingLogger(Logger('BusyMaxTrayService')),
          action: 'Tray menu "Quit" callback',
          callback: onQuit,
        ),
      ),
    ],
  );
}

Future<void> _runLoggedTrayAction({
  required RedactingLogger logger,
  required String action,
  required Future<void> Function() callback,
}) async {
  logger.fine(
    'Tray callback fired: action="$action" snap=${_isRunningInSnap()}',
  );
  try {
    await callback();
    logger.fine('Tray callback completed: action="$action"');
  } on Object catch (error) {
    logger.warning(
      'Tray callback failed: action="$action" error=${_sanitizeForLog(error)}',
    );
    rethrow;
  }
}

String _trayIconName({required bool offline}) {
  final executableDir = File(Platform.resolvedExecutable).parent;
  if (offline) {
    final bundledOfflineLogo = File(
      '${executableDir.path}/data/flutter_assets/assets/branding/'
      'busymax-logo-offline.svg',
    );
    if (bundledOfflineLogo.existsSync()) {
      return bundledOfflineLogo.path;
    }
  }
  final bundledLogo = File(
    '${executableDir.path}/data/flutter_assets/assets/branding/busymax-logo.svg',
  );
  if (bundledLogo.existsSync()) {
    return bundledLogo.path;
  }
  return busyMaxApplicationId;
}

bool _isRunningInSnap() => Platform.environment['SNAP']?.isNotEmpty ?? false;

String _sanitizeForLog(Object? value) {
  return redactForLog(value).replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _sanitizeIconForLog(String iconName) {
  if (iconName == busyMaxApplicationId) {
    return busyMaxApplicationId;
  }
  final basename = iconName.split(Platform.pathSeparator).last;
  return basename.isEmpty ? '<path>' : basename;
}
