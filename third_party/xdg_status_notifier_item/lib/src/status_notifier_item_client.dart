import 'dart:async';
import 'dart:io';
import 'package:dbus/dbus.dart';

import 'dbus_menu_object.dart';

typedef StatusNotifierDiagnosticLog = void Function(String message);

const _kdeStatusNotifierItemInterface = 'org.kde.StatusNotifierItem';
const _freedesktopStatusNotifierItemInterface =
    'org.freedesktop.StatusNotifierItem';
const defaultStatusNotifierMenuPath = DBusObjectPath.unchecked(
  '/StatusNotifierItem/menu',
);

/// Category for notifier items.
enum StatusNotifierItemCategory {
  applicationStatus,
  communications,
  systemServices,
  hardware,
}

/// Status for notifier items.
enum StatusNotifierItemStatus { passive, active }

String _encodeCategory(StatusNotifierItemCategory value) =>
    {
      StatusNotifierItemCategory.applicationStatus: 'ApplicationStatus',
      StatusNotifierItemCategory.communications: 'Communications',
      StatusNotifierItemCategory.systemServices: 'SystemServices',
      StatusNotifierItemCategory.hardware: 'Hardware',
    }[value] ??
    '';

String _encodeStatus(StatusNotifierItemStatus value) =>
    {
      StatusNotifierItemStatus.passive: 'Passive',
      StatusNotifierItemStatus.active: 'Active',
    }[value] ??
    '';

class _StatusNotifierItemObject extends DBusObject {
  final StatusNotifierItemCategory category;
  final String id;
  String title;
  StatusNotifierItemStatus status;
  final int windowId;
  String iconName;
  String overlayIconName;
  String attentionIconName;
  String attentionMovieName;
  final bool itemIsMenu;
  final DBusObjectPath menu;
  Future<void> Function(int x, int y)? onContextMenu;
  Future<void> Function(int x, int y)? onActivate;
  Future<void> Function(int x, int y)? onSecondaryActivate;
  Future<void> Function(int delta, String orientation)? onScroll;
  final StatusNotifierDiagnosticLog? diagnosticLog;

  _StatusNotifierItemObject({
    this.category = StatusNotifierItemCategory.applicationStatus,
    required this.id,
    this.title = '',
    this.status = StatusNotifierItemStatus.active,
    this.windowId = 0,
    this.iconName = '',
    this.overlayIconName = '',
    this.attentionIconName = '',
    this.attentionMovieName = '',
    this.itemIsMenu = false,
    this.menu = DBusObjectPath.root,
    this.onContextMenu,
    this.onActivate,
    this.onSecondaryActivate,
    this.onScroll,
    this.diagnosticLog,
  }) : super(DBusObjectPath('/StatusNotifierItem'));

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      _introspectStatusNotifierInterface(_kdeStatusNotifierItemInterface),
      _introspectStatusNotifierInterface(
        _freedesktopStatusNotifierItemInterface,
      ),
    ];
  }

  DBusIntrospectInterface _introspectStatusNotifierInterface(String name) {
    return DBusIntrospectInterface(
      name,
      methods: [
        DBusIntrospectMethod(
          'ContextMenu',
          args: [
            DBusIntrospectArgument(
              DBusSignature('i'),
              DBusArgumentDirection.in_,
              name: 'x',
            ),
            DBusIntrospectArgument(
              DBusSignature('i'),
              DBusArgumentDirection.in_,
              name: 'y',
            ),
          ],
        ),
        DBusIntrospectMethod(
          'Activate',
          args: [
            DBusIntrospectArgument(
              DBusSignature('i'),
              DBusArgumentDirection.in_,
              name: 'x',
            ),
            DBusIntrospectArgument(
              DBusSignature('i'),
              DBusArgumentDirection.in_,
              name: 'y',
            ),
          ],
        ),
        DBusIntrospectMethod(
          'SecondaryActivate',
          args: [
            DBusIntrospectArgument(
              DBusSignature('i'),
              DBusArgumentDirection.in_,
              name: 'x',
            ),
            DBusIntrospectArgument(
              DBusSignature('i'),
              DBusArgumentDirection.in_,
              name: 'y',
            ),
          ],
        ),
        DBusIntrospectMethod(
          'Scroll',
          args: [
            DBusIntrospectArgument(
              DBusSignature('i'),
              DBusArgumentDirection.in_,
              name: 'delta',
            ),
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.in_,
              name: 'orientation',
            ),
          ],
        ),
        DBusIntrospectMethod(
          'ProvideXdgActivationToken',
          args: [
            DBusIntrospectArgument(
              DBusSignature('s'),
              DBusArgumentDirection.in_,
              name: 'token',
            ),
          ],
        ),
      ],
      signals: [],
      properties: [
        DBusIntrospectProperty(
          'Category',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'Id',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'Title',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'Status',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'WindowId',
          DBusSignature('i'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'IconName',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'IconPixmap',
          DBusSignature('a(iiay)'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'OverlayIconName',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'OverlayIconPixmap',
          DBusSignature('a(iiay)'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'AttentionIconName',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'AttentionIconPixmap',
          DBusSignature('a(iiay)'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'AttentionMovieName',
          DBusSignature('s'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'ToolTip',
          DBusSignature('(sa(iiay))'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'ItemIsMenu',
          DBusSignature('b'),
          access: DBusPropertyAccess.read,
        ),
        DBusIntrospectProperty(
          'Menu',
          DBusSignature('o'),
          access: DBusPropertyAccess.read,
        ),
      ],
    );
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (!_isStatusNotifierInterface(methodCall.interface)) {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (methodCall.name) {
      case 'ContextMenu':
        if (methodCall.signature != DBusSignature('ii')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        var x = methodCall.values[0].asInt32();
        var y = methodCall.values[1].asInt32();
        _logStatusNotifierCall(methodCall, 'x=$x y=$y');
        await onContextMenu?.call(x, y);
        return DBusMethodSuccessResponse();
      case 'Activate':
        if (methodCall.signature != DBusSignature('ii')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        var x = methodCall.values[0].asInt32();
        var y = methodCall.values[1].asInt32();
        _logStatusNotifierCall(methodCall, 'x=$x y=$y');
        await onActivate?.call(x, y);
        return DBusMethodSuccessResponse();
      case 'SecondaryActivate':
        if (methodCall.signature != DBusSignature('ii')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        var x = methodCall.values[0].asInt32();
        var y = methodCall.values[1].asInt32();
        _logStatusNotifierCall(methodCall, 'x=$x y=$y');
        await onSecondaryActivate?.call(x, y);
        return DBusMethodSuccessResponse();
      case 'Scroll':
        if (methodCall.signature != DBusSignature('is')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        var delta = methodCall.values[0].asInt32();
        var orientation = methodCall.values[1].asString();
        _logStatusNotifierCall(
          methodCall,
          'delta=$delta orientation=$orientation',
        );
        await onScroll?.call(delta, orientation);
        return DBusMethodSuccessResponse();
      case 'ProvideXdgActivationToken':
        if (methodCall.signature != DBusSignature('s')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        _logStatusNotifierCall(methodCall, 'token=<redacted>');
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (!_isStatusNotifierInterface(interface)) {
      return DBusMethodErrorResponse.unknownProperty();
    }

    switch (name) {
      case 'Category':
        return DBusGetPropertyResponse(DBusString(_encodeCategory(category)));
      case 'Id':
        return DBusGetPropertyResponse(DBusString(id));
      case 'Title':
        return DBusGetPropertyResponse(DBusString(title));
      case 'Status':
        return DBusGetPropertyResponse(DBusString(_encodeStatus(status)));
      case 'WindowId':
        return DBusGetPropertyResponse(DBusInt32(windowId));
      case 'IconName':
        return DBusGetPropertyResponse(DBusString(iconName));
      case 'IconPixmap':
        return DBusGetPropertyResponse(DBusArray(DBusSignature('(iiay)'), []));
      case 'OverlayIconName':
        return DBusGetPropertyResponse(DBusString(overlayIconName));
      case 'OverlayIconPixmap':
        return DBusGetPropertyResponse(DBusArray(DBusSignature('(iiay)'), []));
      case 'AttentionIconName':
        return DBusGetPropertyResponse(DBusString(attentionIconName));
      case 'AttentionIconPixmap':
        return DBusGetPropertyResponse(DBusArray(DBusSignature('(iiay)'), []));
      case 'AttentionMovieName':
        return DBusGetPropertyResponse(DBusString(attentionMovieName));
      case 'ToolTip':
        return DBusGetPropertyResponse(
          DBusStruct([
            DBusString(''),
            DBusArray(DBusSignature('(iiay)'), []),
            DBusString(''),
            DBusString(''),
          ]),
        );
      case 'ItemIsMenu':
        return DBusGetPropertyResponse(DBusBoolean(itemIsMenu));
      case 'Menu':
        return DBusGetPropertyResponse(menu);
      default:
        return DBusMethodErrorResponse.unknownProperty();
    }
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (!_isStatusNotifierInterface(interface)) {
      return DBusMethodErrorResponse.unknownProperty();
    }
    return DBusGetAllPropertiesResponse({
      'Category': DBusString(_encodeCategory(category)),
      'Id': DBusString(id),
      'Title': DBusString(title),
      'Status': DBusString(_encodeStatus(status)),
      'WindowId': DBusInt32(windowId),
      'IconName': DBusString(iconName),
      'IconPixmap': DBusArray(DBusSignature('(iiay)'), []),
      'OverlayIconName': DBusString(overlayIconName),
      'OverlayIconPixmap': DBusArray(DBusSignature('(iiay)'), []),
      'AttentionIconName': DBusString(attentionIconName),
      'AttentionIconPixmap': DBusArray(DBusSignature('(iiay)'), []),
      'AttentionMovieName': DBusString(attentionMovieName),
      'ToolTip': DBusStruct([
        DBusString(''),
        DBusArray(DBusSignature('(iiay)'), []),
        DBusString(''),
        DBusString(''),
      ]),
      'ItemIsMenu': DBusBoolean(itemIsMenu),
      'Menu': menu,
    });
  }

  bool _isStatusNotifierInterface(String? interface) {
    return interface == _kdeStatusNotifierItemInterface ||
        interface == _freedesktopStatusNotifierItemInterface;
  }

  void _logStatusNotifierCall(DBusMethodCall methodCall, String detail) {
    diagnosticLog?.call(
      'StatusNotifierItem.${methodCall.name} received: '
      'interface=${methodCall.interface} signature=${methodCall.signature} '
      '$detail',
    );
  }
}

/// A client that registers status notifier items.
class StatusNotifierItemClient {
  /// The bus this client is connected to.
  final DBusClient _bus;
  final bool _closeBus;
  final StatusNotifierDiagnosticLog? _diagnosticLog;

  late final DBusMenuObject _menuObject;
  late final _StatusNotifierItemObject _notifierItemObject;
  late final String _busName;

  // FIXME: status enum
  /// Creates a new status notifier item client. If [bus] is provided connect to the given D-Bus server.
  StatusNotifierItemClient({
    required String id,
    StatusNotifierItemCategory category =
        StatusNotifierItemCategory.applicationStatus,
    String title = '',
    StatusNotifierItemStatus status = StatusNotifierItemStatus.active,
    int windowId = 0,
    String iconName = '',
    String overlayIconName = '',
    String attentionIconName = '',
    String attentionMovieName = '',
    bool itemIsMenu = false,
    DBusObjectPath menuPath = defaultStatusNotifierMenuPath,
    required DBusMenuItem menu,
    Future<void> Function(int x, int y)? onContextMenu,
    Future<void> Function(int x, int y)? onActivate,
    Future<void> Function(int x, int y)? onSecondaryActivate,
    Future<void> Function(int delta, String orientation)? onScroll,
    StatusNotifierDiagnosticLog? diagnosticLog,
    DBusClient? bus,
  })  : _bus = bus ?? DBusClient.session(),
        _closeBus = bus == null,
        _diagnosticLog = diagnosticLog {
    _busName = 'org.kde.StatusNotifierItem-$pid-1';
    _menuObject = DBusMenuObject(
      menuPath,
      menu,
      diagnosticLog: diagnosticLog,
    );
    _notifierItemObject = _StatusNotifierItemObject(
      id: id,
      category: category,
      title: title,
      status: status,
      windowId: windowId,
      iconName: iconName,
      overlayIconName: overlayIconName,
      attentionIconName: attentionIconName,
      attentionMovieName: attentionMovieName,
      itemIsMenu: itemIsMenu,
      menu: _menuObject.path,
      onContextMenu: onContextMenu,
      onActivate: onActivate,
      onSecondaryActivate: onSecondaryActivate,
      onScroll: onScroll,
      diagnosticLog: diagnosticLog,
    );
  }

  String get busName => _busName;

  DBusObjectPath get menuPath => _menuObject.path;

  DBusObjectPath get itemPath => _notifierItemObject.path;

  // Connect to D-Bus and register this notifier item.
  Future<void> connect() async {
    _log(
      'StatusNotifierItem registration starting: bus_name=$_busName '
      'item_path=${itemPath.value} menu_path=${menuPath.value}',
    );
    DBusRequestNameReply requestResult;
    try {
      requestResult = await _bus.requestName(_busName);
    } on Object catch (error) {
      _log('StatusNotifierItem bus name request failed: error=$error');
      rethrow;
    }
    if (requestResult != DBusRequestNameReply.primaryOwner) {
      _log(
        'StatusNotifierItem registration failed: '
        'request_result=$requestResult',
      );
      throw StateError(
        'Unable to own StatusNotifierItem bus name: $requestResult',
      );
    }
    _log('StatusNotifierItem bus name acquired: bus_name=$_busName');

    // Register the menu.
    try {
      _log('DBus menu registration starting: path=${menuPath.value}');
      await _bus.registerObject(_menuObject);
      _log('DBus menu registration succeeded: path=${menuPath.value}');
    } on Object catch (error) {
      _log(
        'DBus menu registration failed: path=${menuPath.value} error=$error',
      );
      rethrow;
    }

    // Put the item on the bus.
    try {
      _log(
          'StatusNotifierItem object registration starting: path=${itemPath.value}');
      await _bus.registerObject(_notifierItemObject);
      _log(
          'StatusNotifierItem object registration succeeded: path=${itemPath.value}');
    } on Object catch (error) {
      _log(
        'StatusNotifierItem object registration failed: '
        'path=${itemPath.value} error=$error',
      );
      rethrow;
    }

    // Register the item.
    try {
      await _bus.callMethod(
        destination: 'org.kde.StatusNotifierWatcher',
        path: DBusObjectPath('/StatusNotifierWatcher'),
        interface: 'org.kde.StatusNotifierWatcher',
        name: 'RegisterStatusNotifierItem',
        values: [DBusString(_busName)],
        replySignature: DBusSignature.empty,
      );
      _log('StatusNotifierItem registration succeeded: bus_name=$_busName');
    } on Object catch (error) {
      _log(
        'StatusNotifierItem watcher registration failed: '
        'bus_name=$_busName error=$error',
      );
      rethrow;
    }
  }

  /// Updates the menu shown.
  Future<void> updateMenu(DBusMenuItem menu) async {
    await _menuObject.update(menu);
  }

  /// Terminates all active connections. If a client remains unclosed, the Dart process may not terminate.
  Future<void> close() async {
    if (_closeBus) {
      await _bus.close();
    }
  }

  void _log(String message) {
    _diagnosticLog?.call(message);
  }
}
