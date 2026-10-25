import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:xdg_status_notifier_item/xdg_status_notifier_item.dart'
    as upstream;

/// Application menu identity is independent of the library's layout positions.
class ApplicationTrayItem extends upstream.DBusMenuItem {
  ApplicationTrayItem({
    required this.id,
    super.type,
    super.enabled,
    super.visible,
    super.label,
    super.toggleState,
    super.toggleType,
    List<ApplicationTrayItem> children = const [],
    super.onAboutToShow,
    super.onOpened,
    super.onClosed,
    super.onClicked,
  }) : super(children: children);

  ApplicationTrayItem.separator({required int id, bool visible = true})
    : this(id: id, type: 'separator', visible: visible);

  final int id;

  @override
  List<ApplicationTrayItem> get children =>
      super.children.cast<ApplicationTrayItem>();
}

const _menuInterface = 'com.canonical.dbusmenu';
const _notifierInterface = 'org.kde.StatusNotifierItem';

/// Composes the unmodified library's public menu serializer with application
/// identities, bounded protocol validation, and application callback isolation.
/// No library source, private member, or allocation-order assumption is used.
class ApplicationTrayMenu extends DBusObject {
  ApplicationTrayMenu(super.path, ApplicationTrayItem menu) {
    _replace(menu);
  }

  late upstream.DBusMenuObject _delegate;
  late ApplicationTrayItem _menu;
  Future<_Layout>? _layout;
  int _revision = 1;

  void _replace(ApplicationTrayItem menu) {
    final ids = <int>{};
    void validate(ApplicationTrayItem item) {
      if (item.id < 0 || !ids.add(item.id)) {
        throw ArgumentError('Menu IDs must be unique and nonnegative');
      }
      for (final child in item.children) {
        validate(child);
      }
    }

    validate(menu);
    if (menu.id != 0) throw ArgumentError('The menu root must have ID zero');
    _menu = menu;
    _delegate = upstream.DBusMenuObject(path, menu);
    _layout = null;
  }

  Future<void> update(ApplicationTrayItem menu) async {
    _replace(menu);
    _revision++;
    await emitSignal(_menuInterface, 'LayoutUpdated', [
      DBusUint32(_revision),
      const DBusInt32(0),
    ]);
  }

  Future<_Layout> _snapshot() => _layout ??= _Layout.read(_delegate, _menu);

  @override
  List<DBusIntrospectInterface> introspect() {
    final original = _delegate.introspect().single;
    return [
      DBusIntrospectInterface(
        _menuInterface,
        methods: [
          ...original.methods,
          DBusIntrospectMethod(
            'GetGroupProperties',
            args: [
              DBusIntrospectArgument(
                DBusSignature('ai'),
                DBusArgumentDirection.in_,
              ),
              DBusIntrospectArgument(
                DBusSignature('as'),
                DBusArgumentDirection.in_,
              ),
              DBusIntrospectArgument(
                DBusSignature('a(ia{sv})'),
                DBusArgumentDirection.out,
              ),
            ],
          ),
        ],
        signals: original.signals,
        properties: original.properties,
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface != _menuInterface) {
      return DBusMethodErrorResponse.unknownProperty();
    }
    final value = switch (name) {
      'Version' => const DBusUint32(3),
      'Status' => const DBusString('normal'),
      'TextDirection' => const DBusString('ltr'),
      'IconThemePath' => DBusArray.string([]),
      _ => null,
    };
    return value == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface != _menuInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    return DBusGetAllPropertiesResponse({
      for (final name in [
        'Version',
        'Status',
        'TextDirection',
        'IconThemePath',
      ])
        name: (await getProperty(
          interface,
          name,
        )).returnValues.single.asVariant(),
    });
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != _menuInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final signature = switch (methodCall.name) {
      'GetLayout' => 'iias',
      'GetProperty' => 'is',
      'GetGroupProperties' => 'aias',
      'Event' => 'isvu',
      'EventGroup' => 'a(isvu)',
      'AboutToShow' => 'i',
      'AboutToShowGroup' => 'ai',
      _ => null,
    };
    if (signature == null) return DBusMethodErrorResponse.unknownMethod();
    if (methodCall.signature != DBusSignature(signature)) {
      return DBusMethodErrorResponse.invalidArgs();
    }
    final layout = await _snapshot();
    final values = methodCall.values;
    if (methodCall.name == 'EventGroup') {
      if (values.single.asArray().length > 1024) {
        return DBusMethodErrorResponse.invalidArgs();
      }
      final failed = <int>[];
      for (final event in values.single.asArray()) {
        final parts = event.asStruct();
        if (await _event(layout, parts) is DBusMethodErrorResponse) {
          failed.add(parts.first.asInt32());
        }
      }
      return DBusMethodSuccessResponse([DBusArray.int32(failed)]);
    }
    if (methodCall.name == 'AboutToShowGroup') {
      final ids = values.single.asInt32Array();
      if (ids.length > 1024) return DBusMethodErrorResponse.invalidArgs();
      final changed = <int>[], failed = <int>[];
      for (final id in ids) {
        final result = await _aboutToShow(layout, id);
        if (result is DBusMethodErrorResponse) {
          failed.add(id);
        } else if (result.returnValues.single.asBoolean()) {
          changed.add(id);
        }
      }
      return DBusMethodSuccessResponse([
        DBusArray.int32(changed),
        DBusArray.int32(failed),
      ]);
    }
    if (methodCall.name == 'GetGroupProperties') {
      final requested = values.first.asInt32Array();
      if (requested.length > 1024) return DBusMethodErrorResponse.invalidArgs();
      final names = values.last.asStringArray();
      final rows = <DBusValue>[];
      for (final id in requested.isEmpty ? layout.items.keys : requested) {
        final props = layout.properties[id];
        if (props == null) continue;
        rows.add(
          DBusStruct([
            DBusInt32(id),
            DBusDict.stringVariant({
              for (final entry in props.entries)
                if (names.isEmpty || names.contains(entry.key))
                  entry.key: entry.value,
            }),
          ]),
        );
      }
      return DBusMethodSuccessResponse([
        DBusArray(DBusSignature('(ia{sv})'), rows),
      ]);
    }
    final id = values.first.asInt32();
    if (!layout.items.containsKey(id)) {
      return DBusMethodErrorResponse('com.canonical.dbusmenu.UnknownId');
    }
    if (methodCall.name == 'Event') return _event(layout, values);
    if (methodCall.name == 'AboutToShow') return _aboutToShow(layout, id);
    if (methodCall.name == 'GetProperty') {
      final value = layout.properties[id]![values.last.asString()];
      return value == null
          ? DBusMethodErrorResponse('com.canonical.dbusmenu.UnknownProperty')
          : DBusMethodSuccessResponse([DBusVariant(value)]);
    }
    final depth = values[1].asInt32();
    final names = values[2].asStringArray();
    DBusValue project(ApplicationTrayItem item, int remaining) => DBusStruct([
      DBusInt32(item.id),
      DBusDict.stringVariant({
        for (final entry in layout.properties[item.id]!.entries)
          if (names.isEmpty || names.contains(entry.key))
            entry.key: entry.value,
      }),
      DBusArray.variant(
        remaining == 0
            ? []
            : [
                for (final child in item.children)
                  project(child, remaining < 0 ? -1 : remaining - 1),
              ],
      ),
    ]);
    return DBusMethodSuccessResponse([
      DBusUint32(_revision),
      project(layout.items[id]!, depth),
    ]);
  }

  Future<DBusMethodResponse> _aboutToShow(_Layout layout, int id) async {
    final item = layout.items[id];
    if (item == null) {
      return DBusMethodErrorResponse('com.canonical.dbusmenu.UnknownId');
    }
    try {
      return DBusMethodSuccessResponse([
        DBusBoolean(await item.onAboutToShow?.call() ?? false),
      ]);
    } on Object {
      return DBusMethodErrorResponse.failed('Menu refresh failed');
    }
  }

  Future<DBusMethodResponse> _event(
    _Layout layout,
    List<DBusValue> values,
  ) async {
    final item = layout.items[values.first.asInt32()];
    if (item == null) {
      return DBusMethodErrorResponse('com.canonical.dbusmenu.UnknownId');
    }
    final event = values[1].asString();
    if (event == 'clicked' &&
        (item.enabled == false ||
            item.visible == false ||
            item.type == 'separator')) {
      return DBusMethodErrorResponse.failed('Menu item is unavailable');
    }
    try {
      switch (event) {
        case 'clicked':
          await item.onClicked?.call();
        case 'opened':
          await item.onOpened?.call();
        case 'closed':
          await item.onClosed?.call();
      }
      return DBusMethodSuccessResponse();
    } on Object {
      // Exceptions from application actions cannot escape into the bus dispatch
      // loop or disclose private application data in a protocol error.
      return DBusMethodErrorResponse.failed('Menu action failed');
    }
  }
}

class _Layout {
  final items = <int, ApplicationTrayItem>{};
  final properties = <int, Map<String, DBusValue>>{};

  static Future<_Layout> read(
    upstream.DBusMenuObject delegate,
    ApplicationTrayItem root,
  ) async {
    final response = await delegate.handleMethodCall(
      DBusMethodCall(
        sender: null,
        interface: _menuInterface,
        name: 'GetLayout',
        values: [const DBusInt32(0), const DBusInt32(-1), DBusArray.string([])],
      ),
    );
    final result = _Layout();
    void bind(ApplicationTrayItem item, DBusValue value) {
      final parts = value.asStruct();
      result.items[item.id] = item;
      result.properties[item.id] = parts[1].asStringVariantDict();
      final children = parts[2].asArray();
      if (children.length != item.children.length) {
        throw StateError('Invalid upstream menu layout');
      }
      for (var index = 0; index < children.length; index++) {
        bind(item.children[index], children[index].asVariant());
      }
    }

    bind(root, response.returnValues[1]);
    return result;
  }
}

/// Registers the official upstream client through public D-Bus extension points.
/// BusyStack owns only its presentation and menu protocol adapter.
class ApplicationTrayClient {
  ApplicationTrayClient({
    required String id,
    String title = '',
    String iconName = '',
    String toolTipTitle = '',
    String toolTipDescription = '',
    String xAyatanaLabel = '',
    String xAyatanaLabelGuide = '',
    bool itemIsMenu = false,
    DBusObjectPath? menuPath,
    required ApplicationTrayItem menu,
    void Function(String)? diagnosticLog,
    Future<void> Function(int, int)? onContextMenu,
    Future<void> Function(int, int)? onActivate,
    Future<void> Function(int, int)? onSecondaryActivate,
    DBusAddress? busAddress,
  }) : menuPath = menuPath ?? DBusObjectPath('/StatusNotifierItem/menu'),
       _menu = ApplicationTrayMenu(
         menuPath ?? DBusObjectPath('/StatusNotifierItem/menu'),
         menu,
       ) {
    _presentation = _Presentation(this.menuPath, {
      'Title': DBusString(title),
      'IconName': DBusString(iconName),
      'ItemIsMenu': DBusBoolean(itemIsMenu),
      'Menu': this.menuPath,
      'XAyatanaLabel': DBusString(xAyatanaLabel),
      'XAyatanaLabelGuide': DBusString(xAyatanaLabelGuide),
      'ToolTip': _tooltip(iconName, toolTipTitle, toolTipDescription),
    });
    _bus = _ApplicationTrayBus(
      busAddress ??
          DBusAddress(
            Platform.environment['DBUS_SESSION_BUS_ADDRESS'] ??
                'unix:path=/run/user/${_currentUid()}/bus',
          ),
      menu: _menu,
      presentation: _presentation,
    );
    _upstream = upstream.StatusNotifierItemClient(
      id: id,
      title: title,
      iconName: iconName,
      menu: menu,
      bus: _bus,
      onContextMenu: onContextMenu,
      onActivate: onActivate,
      onSecondaryActivate: onSecondaryActivate,
    );
  }

  final DBusObjectPath menuPath;
  final ApplicationTrayMenu _menu;
  late final _Presentation _presentation;
  late final _ApplicationTrayBus _bus;
  late final upstream.StatusNotifierItemClient _upstream;
  DBusObjectPath get itemPath => _presentation.path;
  String get busName => 'org.kde.StatusNotifierItem-$pid-1';
  String get title => _presentation.values['Title']!.asString();
  String get iconName => _presentation.values['IconName']!.asString();
  String get xAyatanaLabel => _presentation.values['XAyatanaLabel']!.asString();
  String get xAyatanaLabelGuide =>
      _presentation.values['XAyatanaLabelGuide']!.asString();
  String get toolTipTitle =>
      _presentation.values['ToolTip']!.asStruct()[2].asString();
  String get toolTipDescription =>
      _presentation.values['ToolTip']!.asStruct()[3].asString();

  Future<void> connect() => _upstream.connect();
  Future<void> close() => _bus.close();
  Future<void> updateMenu(ApplicationTrayItem menu) => _menu.update(menu);
  Future<void> updateIconName(String iconName) =>
      updatePresentation(iconName: iconName);
  Future<void> updateXAyatanaLabel(
    String label, {
    required String guide,
  }) async {
    _presentation.values.addAll({
      'XAyatanaLabel': DBusString(label),
      'XAyatanaLabelGuide': DBusString(guide),
    });
    await _presentation.emitSignal(_notifierInterface, 'XAyatanaNewLabel', [
      DBusString(label),
      DBusString(guide),
    ]);
    await _presentation.emitPropertiesChanged(
      _notifierInterface,
      changedProperties: {
        'XAyatanaLabel': DBusString(label),
        'XAyatanaLabelGuide': DBusString(guide),
      },
    );
  }

  Future<void> updatePresentation({
    String? title,
    String? iconName,
    String? toolTipTitle,
    String? toolTipDescription,
  }) async {
    final changed = <String, DBusValue>{
      if (title != null) 'Title': DBusString(title),
      if (iconName != null) 'IconName': DBusString(iconName),
      'ToolTip': _tooltip(
        iconName ?? this.iconName,
        toolTipTitle ?? this.toolTipTitle,
        toolTipDescription ?? this.toolTipDescription,
      ),
    };
    _presentation.values.addAll(changed);
    for (final name in ['Title', 'IconName', 'ToolTip']) {
      if (changed.containsKey(name)) {
        await _presentation.emitSignal(
          _notifierInterface,
          name == 'IconName' ? 'NewIcon' : 'New$name',
        );
      }
    }
    await _presentation.emitPropertiesChanged(
      _notifierInterface,
      changedProperties: changed,
    );
  }

  static DBusValue _tooltip(String icon, String title, String description) =>
      DBusStruct([
        DBusString(icon),
        DBusArray(DBusSignature('(iiay)'), []),
        DBusString(title),
        DBusString(description),
      ]);
}

class _ApplicationTrayBus extends DBusClient {
  _ApplicationTrayBus(
    super.address, {
    required this.menu,
    required this.presentation,
  });
  final ApplicationTrayMenu menu;
  final _Presentation presentation;

  @override
  Future<void> registerObject(DBusObject object) {
    if (object is upstream.DBusMenuObject) return super.registerObject(menu);
    if (object.path == presentation.path) {
      presentation.delegate = object;
      return super.registerObject(presentation);
    }
    return super.registerObject(object);
  }
}

class _Presentation extends DBusObject {
  _Presentation(DBusObjectPath menuPath, this.values)
    : super(DBusObjectPath('/StatusNotifierItem'));
  final Map<String, DBusValue> values;
  DBusObject? delegate;

  @override
  List<DBusIntrospectInterface> introspect() {
    final original = delegate!.introspect().single;
    return [
      DBusIntrospectInterface(
        _notifierInterface,
        methods: original.methods,
        signals: [
          for (final name in ['NewTitle', 'NewIcon', 'NewToolTip'])
            DBusIntrospectSignal(name),
          DBusIntrospectSignal(
            'XAyatanaNewLabel',
            args: [
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.out,
              ),
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.out,
              ),
            ],
          ),
        ],
        properties: [
          for (final property in original.properties)
            if (property.name != 'ToolTip') property,
          DBusIntrospectProperty(
            'ToolTip',
            DBusSignature('(sa(iiay)ss)'),
            access: DBusPropertyAccess.read,
          ),
          for (final name in ['XAyatanaLabel', 'XAyatanaLabelGuide'])
            DBusIntrospectProperty(
              name,
              DBusSignature('s'),
              access: DBusPropertyAccess.read,
            ),
        ],
      ),
    ];
  }

  String _upstreamInterface(String name) =>
      name == _notifierInterface ? 'org.freedesktop.StatusNotifierItem' : name;

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface != _notifierInterface &&
        interface != 'org.freedesktop.StatusNotifierItem') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final value = values[name];
    return value != null
        ? DBusGetPropertyResponse(value)
        : delegate!.getProperty(_upstreamInterface(interface), name);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface != _notifierInterface &&
        interface != 'org.freedesktop.StatusNotifierItem') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    final original = (await delegate!.getAllProperties(
      _upstreamInterface(interface),
    )).returnValues.single.asStringVariantDict();
    return DBusGetAllPropertiesResponse({...original, ...values});
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != _notifierInterface &&
        methodCall.interface != 'org.freedesktop.StatusNotifierItem') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    try {
      return await delegate!.handleMethodCall(
        DBusMethodCall(
          sender: methodCall.sender,
          interface: _upstreamInterface(methodCall.interface!),
          name: methodCall.name,
          values: methodCall.values,
          noReplyExpected: methodCall.noReplyExpected,
          noAutoStart: methodCall.noAutoStart,
          allowInteractiveAuthorization:
              methodCall.allowInteractiveAuthorization,
        ),
      );
    } on Object {
      return DBusMethodErrorResponse.failed('Tray action failed');
    }
  }
}

int _currentUid() {
  final entry = File('/proc/self/status')
      .readAsLinesSync()
      .firstWhere((line) => line.startsWith('Uid:'));
  return int.parse(entry.split(RegExp(r'\s+'))[1]);
}
