import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';
import 'package:xdg_status_notifier_item/xdg_status_notifier_item.dart';

import '../core/logging/redacting_logger.dart';
import '../features/tray/domain/tray_presentation.dart';

const String busyMaxApplicationId = 'io.busystack.busymax';
const String busyMaxTrayMenuPath = '/StatusNotifierItem/menu';

abstract final class BusyMaxTrayMenuIds {
  static const root = 0;
  static const showBusyMax = 1;
  static const firstSeparator = 2;
  static const newEvent = 3;
  static const newTask = 4;
  static const secondSeparator = 5;
  static const today = 6;
  static const firstEvent = 7;
  static const secondEvent = 8;
  static const thirdEvent = 9;
  static const tasksDueToday = 10;
  static const emptyToday = 11;
  static const openTodayAgenda = 12;
  static const thirdSeparator = 13;
  static const syncNow = 14;
  static const synchronizationStatus = 15;
  static const fourthSeparator = 16;
  static const settings = 17;
  static const quitBusyMax = 18;

  static const orderedChildren = <int>[
    showBusyMax,
    firstSeparator,
    newEvent,
    newTask,
    secondSeparator,
    today,
    firstEvent,
    secondEvent,
    thirdEvent,
    tasksDueToday,
    emptyToday,
    openTodayAgenda,
    thirdSeparator,
    syncNow,
    synchronizationStatus,
    fourthSeparator,
    settings,
    quitBusyMax,
  ];
}

final class BusyMaxTrayActions {
  const BusyMaxTrayActions({
    required this.showBusyMax,
    required this.newEvent,
    required this.newTask,
    required this.openEvent,
    required this.openTasksDueToday,
    required this.openTodayAgenda,
    required this.synchronize,
    required this.openSettings,
    required this.quitBusyMax,
  });

  final Future<void> Function() showBusyMax;
  final Future<void> Function() newEvent;
  final Future<void> Function() newTask;
  final Future<void> Function(BusyMaxTrayEventEntry event) openEvent;
  final Future<void> Function() openTasksDueToday;
  final Future<void> Function() openTodayAgenda;
  final Future<void> Function() synchronize;
  final Future<void> Function() openSettings;
  final Future<void> Function() quitBusyMax;
}

final class BusyMaxTrayServiceConfiguration {
  const BusyMaxTrayServiceConfiguration({
    required this.initialPresentation,
    required this.loadPresentation,
    required this.actions,
  });

  final BusyMaxTrayMenuPresentation initialPresentation;
  final Future<BusyMaxTrayMenuPresentation> Function() loadPresentation;
  final BusyMaxTrayActions actions;
}

typedef BusyMaxTrayMenuUpdater =
    Future<void> Function(
      DBusMenuItem menu,
      BusyMaxTrayMenuPresentation presentation,
    );

final class BusyMaxTrayMenuController {
  BusyMaxTrayMenuController({
    required BusyMaxTrayMenuPresentation initialPresentation,
    required Future<BusyMaxTrayMenuPresentation> Function() loadPresentation,
    required BusyMaxTrayActions actions,
    void Function(Object error)? onLoadFailure,
  }) : _presentation = initialPresentation,
       _loadPresentation = loadPresentation,
       _actions = actions,
       _onLoadFailure = onLoadFailure;

  final Future<BusyMaxTrayMenuPresentation> Function() _loadPresentation;
  final BusyMaxTrayActions _actions;
  final void Function(Object error)? _onLoadFailure;
  BusyMaxTrayMenuPresentation _presentation;
  BusyMaxTrayMenuUpdater? _updater;
  Future<bool>? _activeRefresh;

  BusyMaxTrayMenuPresentation get presentation => _presentation;

  DBusMenuItem get menu => buildBusyMaxTrayMenu(
    presentation: _presentation,
    actions: _actions,
    onAboutToShow: refresh,
  );

  void attachUpdater(BusyMaxTrayMenuUpdater? updater) {
    _updater = updater;
  }

  Future<bool> refresh() {
    final active = _activeRefresh;
    if (active != null) return active;
    final refresh = _loadAndPublish();
    _activeRefresh = refresh;
    return refresh.whenComplete(() {
      if (identical(_activeRefresh, refresh)) _activeRefresh = null;
    });
  }

  Future<bool> _loadAndPublish() async {
    try {
      final next = await _loadPresentation();
      if (next == _presentation) return false;
      final menu = buildBusyMaxTrayMenu(
        presentation: next,
        actions: _actions,
        onAboutToShow: refresh,
      );
      await _updater?.call(menu, next);
      _presentation = next;
      return true;
    } on Object catch (error) {
      _onLoadFailure?.call(error);
      return false;
    }
  }
}

class BusyMaxTrayService {
  BusyMaxTrayService({required BusyMaxTrayServiceConfiguration configuration})
    : _actions = configuration.actions {
    _menuControllerWithLogging = BusyMaxTrayMenuController(
      initialPresentation: configuration.initialPresentation,
      loadPresentation: configuration.loadPresentation,
      actions: configuration.actions,
      onLoadFailure: _logPresentationLoadFailure,
    );
  }

  final BusyMaxTrayActions _actions;
  late final BusyMaxTrayMenuController _menuControllerWithLogging;
  final RedactingLogger _logger = RedactingLogger(Logger('BusyMaxTrayService'));

  StatusNotifierItemClient? _client;
  bool _available = false;

  BusyMaxTrayMenuController get _controller => _menuControllerWithLogging;

  bool get available => _available;

  Future<void> start() async {
    _logger.fine('Tray service start requested: snap=${_isRunningInSnap()}');
    if (_client != null) {
      _logger.fine('Tray initialization skipped: existing_client=true');
      return;
    }
    await _controller.refresh();
    final exportedPresentation = _controller.presentation;
    final menu = _controller.menu;
    final iconName = _trayIconName(offline: exportedPresentation.offline);
    _logger.fine(
      'DBus menu creation completed: path=$busyMaxTrayMenuPath '
      'items=${menu.children.length} '
      'ids=${menu.children.map((item) => item.id).join(',')}',
    );
    final client = StatusNotifierItemClient(
      id: busyMaxApplicationId,
      title: _trayTitle(exportedPresentation),
      iconName: iconName,
      toolTipTitle: _trayTitle(exportedPresentation),
      toolTipDescription: _trayToolTipDescription(exportedPresentation),
      itemIsMenu: true,
      menuPath: DBusObjectPath(busyMaxTrayMenuPath),
      menu: menu,
      diagnosticLog: (message) =>
          _logger.fine(_sanitizeForLog('StatusNotifier diagnostic: $message')),
      onActivate: (x, y) => handleActivate(),
      onSecondaryActivate: (x, y) => handleSecondaryActivate(),
    );
    try {
      await client.connect();
      _client = client;
      _available = true;
      _controller.attachUpdater(_publishPresentation);
      if (_controller.presentation != exportedPresentation) {
        await _publishPresentation(_controller.menu, _controller.presentation);
      }
      final menuVerified = await _verifyMenuExported();
      _logger.fine(
        'StatusNotifier registration succeeded: snap=${_isRunningInSnap()} '
        'bus_name=${client.busName} item_path=${client.itemPath.value} '
        'menu_path=${client.menuPath.value} menu_exported=$menuVerified '
        'menu_items=${menu.children.length}',
      );
    } on Object catch (error) {
      _controller.attachUpdater(null);
      _client = null;
      _available = false;
      _logger.warning(
        'StatusNotifier registration failed: snap=${_isRunningInSnap()} '
        'error_type=${error.runtimeType}',
      );
      await client.close();
    }
  }

  Future<void> stop() async {
    _controller.attachUpdater(null);
    final client = _client;
    _client = null;
    _available = false;
    await client?.close();
  }

  Future<bool> refreshPresentation() => _controller.refresh();

  Future<void> handleActivate() => _runLoggedTrayAction(
    logger: _logger,
    action: 'StatusNotifierItem activation callback',
    callback: _actions.showBusyMax,
  );

  Future<void> handleSecondaryActivate() => _runLoggedTrayAction(
    logger: _logger,
    action: 'StatusNotifierItem secondary activation callback',
    callback: _actions.openTodayAgenda,
  );

  Future<void> _publishPresentation(
    DBusMenuItem menu,
    BusyMaxTrayMenuPresentation presentation,
  ) async {
    final client = _client;
    if (client == null) return;
    await client.updateMenu(menu);
    await client.updatePresentation(
      title: _trayTitle(presentation),
      iconName: _trayIconName(offline: presentation.offline),
      toolTipTitle: _trayTitle(presentation),
      toolTipDescription: _trayToolTipDescription(presentation),
    );
  }

  String _trayTitle(BusyMaxTrayMenuPresentation presentation) =>
      presentation.offline
      ? 'BusyMax — ${presentation.offlineTitle}'
      : 'BusyMax';

  String _trayToolTipDescription(BusyMaxTrayMenuPresentation presentation) =>
      presentation.offline ? presentation.offlineDescription : '';

  void _logPresentationLoadFailure(Object error) {
    _logger.warning(
      'Tray presentation refresh failed: error_type=${error.runtimeType}',
    );
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
        'error_type=${error.runtimeType}',
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
  required BusyMaxTrayMenuPresentation presentation,
  required BusyMaxTrayActions actions,
  Future<bool> Function()? onAboutToShow,
}) {
  final eventRows = presentation.eventRows;
  return DBusMenuItem(
    id: BusyMaxTrayMenuIds.root,
    enabled: true,
    visible: true,
    onAboutToShow: onAboutToShow,
    children: [
      _actionItem(
        id: BusyMaxTrayMenuIds.showBusyMax,
        label: presentation.showBusyMaxLabel,
        callback: actions.showBusyMax,
      ),
      DBusMenuItem.separator(id: BusyMaxTrayMenuIds.firstSeparator),
      _actionItem(
        id: BusyMaxTrayMenuIds.newEvent,
        label: presentation.newEventLabel,
        enabled: presentation.canCreateEvent,
        callback: actions.newEvent,
      ),
      _actionItem(
        id: BusyMaxTrayMenuIds.newTask,
        label: presentation.newTaskLabel,
        enabled: presentation.canCreateTask,
        callback: actions.newTask,
      ),
      DBusMenuItem.separator(id: BusyMaxTrayMenuIds.secondSeparator),
      DBusMenuItem(
        id: BusyMaxTrayMenuIds.today,
        enabled: false,
        visible: true,
        label: presentation.todayLabel,
      ),
      for (var index = 0; index < 3; index += 1)
        _eventSlot(
          id: BusyMaxTrayMenuIds.firstEvent + index,
          row: index < eventRows.length ? eventRows[index] : null,
          actions: actions,
        ),
      _actionItem(
        id: BusyMaxTrayMenuIds.tasksDueToday,
        label: presentation.taskSummaryLabel ?? '',
        visible: presentation.taskSummaryLabel != null,
        enabled: presentation.taskSummaryLabel != null,
        callback: actions.openTasksDueToday,
      ),
      DBusMenuItem(
        id: BusyMaxTrayMenuIds.emptyToday,
        enabled: false,
        visible: presentation.showEmptyState,
        label: presentation.emptyStateLabel,
      ),
      _actionItem(
        id: BusyMaxTrayMenuIds.openTodayAgenda,
        label: presentation.openTodayAgendaLabel,
        callback: actions.openTodayAgenda,
      ),
      DBusMenuItem.separator(id: BusyMaxTrayMenuIds.thirdSeparator),
      _actionItem(
        id: BusyMaxTrayMenuIds.syncNow,
        label: presentation.syncNowLabel,
        enabled: presentation.canSynchronize,
        callback: actions.synchronize,
      ),
      DBusMenuItem(
        id: BusyMaxTrayMenuIds.synchronizationStatus,
        enabled: false,
        visible: true,
        label: presentation.synchronizationStatusLabel,
      ),
      DBusMenuItem.separator(id: BusyMaxTrayMenuIds.fourthSeparator),
      _actionItem(
        id: BusyMaxTrayMenuIds.settings,
        label: presentation.settingsLabel,
        callback: actions.openSettings,
      ),
      _actionItem(
        id: BusyMaxTrayMenuIds.quitBusyMax,
        label: presentation.quitBusyMaxLabel,
        callback: actions.quitBusyMax,
      ),
    ],
  );
}

DBusMenuItem _eventSlot({
  required int id,
  required BusyMaxTrayEventRowPresentation? row,
  required BusyMaxTrayActions actions,
}) {
  return DBusMenuItem(
    id: id,
    enabled: row != null,
    visible: row != null,
    label: row?.label ?? '',
    onClicked: row == null
        ? null
        : () => _runLoggedTrayAction(
            logger: RedactingLogger(Logger('BusyMaxTrayService')),
            action: 'Tray event slot callback',
            callback: () => actions.openEvent(row.event),
          ),
  );
}

DBusMenuItem _actionItem({
  required int id,
  required String label,
  required Future<void> Function() callback,
  bool enabled = true,
  bool visible = true,
}) {
  return DBusMenuItem(
    id: id,
    enabled: enabled,
    visible: visible,
    label: label,
    onClicked: enabled && visible
        ? () => _runLoggedTrayAction(
            logger: RedactingLogger(Logger('BusyMaxTrayService')),
            action: 'Tray menu callback',
            callback: callback,
          )
        : null,
  );
}

Future<void> _runLoggedTrayAction({
  required RedactingLogger logger,
  required String action,
  required Future<void> Function() callback,
}) async {
  logger.fine('Tray callback fired: action="$action"');
  try {
    await callback();
    logger.fine('Tray callback completed: action="$action"');
  } on Object catch (error) {
    logger.warning(
      'Tray callback failed: action="$action" error_type=${error.runtimeType}',
    );
  }
}

String _trayIconName({required bool offline}) {
  final executableDir = File(Platform.resolvedExecutable).parent;
  if (offline) {
    final bundledOfflineLogo = File(
      '${executableDir.path}/data/flutter_assets/assets/branding/'
      'busymax-logo-offline.svg',
    );
    if (bundledOfflineLogo.existsSync()) return bundledOfflineLogo.path;
  }
  final bundledLogo = File(
    '${executableDir.path}/data/flutter_assets/assets/branding/busymax-logo.svg',
  );
  if (bundledLogo.existsSync()) return bundledLogo.path;
  return busyMaxApplicationId;
}

bool _isRunningInSnap() => Platform.environment['SNAP']?.isNotEmpty ?? false;

String _sanitizeForLog(Object? value) {
  return redactForLog(value).replaceAll(RegExp(r'\s+'), ' ').trim();
}
