import 'dart:io';

import 'package:busymax/src/platform/busymax_tray_service.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xdg_status_notifier_item/xdg_status_notifier_item.dart';

void main() {
  test('tray menu contains only app, agenda, and exit actions', () async {
    var openedApp = false;
    var openedAgenda = false;
    var quit = false;

    final menu = buildBusyMaxTrayMenu(
      labels: _labels,
      onOpenBusyMax: () async {
        openedApp = true;
      },
      onOpenAgenda: () async {
        openedAgenda = true;
      },
      onQuit: () async {
        quit = true;
      },
    );

    expect(menu.children, hasLength(3));
    expect(menu.id, 0);
    expect(menu.children.map((item) => item.id), [1, 2, 3]);
    expect(menu.children.map((item) => item.label), [
      'Open BusyMax',
      'Agenda',
      'Exit',
    ]);
    expect(menu.enabled, isTrue);
    expect(menu.visible, isTrue);
    expect(menu.children.every((item) => item.enabled == true), isTrue);
    expect(menu.children.every((item) => item.visible == true), isTrue);
    expect(menu.children.every((item) => item.children.isEmpty), isTrue);

    await menu.children[0].onClicked?.call();
    await menu.children[1].onClicked?.call();
    await menu.children[2].onClicked?.call();

    expect(openedApp, isTrue);
    expect(openedAgenda, isTrue);
    expect(quit, isTrue);
  });

  test('tray menu id 2 invokes Agenda callback', () async {
    var openedAgenda = false;
    final menu = buildBusyMaxTrayMenu(
      labels: _labels,
      onOpenBusyMax: () async {},
      onOpenAgenda: () async {
        openedAgenda = true;
      },
      onQuit: () async {},
    );

    final agendaItem = menu.children.singleWhere((item) => item.id == 2);
    await agendaItem.onClicked?.call();

    expect(agendaItem.label, 'Agenda');
    expect(agendaItem.children, isEmpty);
    expect(openedAgenda, isTrue);
  });

  test('application id uses Busystack reverse DNS id', () {
    expect(busyMaxApplicationId, 'io.busystack.busymax');
    expect(busyMaxTrayMenuPath, '/StatusNotifierItem/menu');
  });

  test('Linux desktop identity matches the displayed BusyMax window', () {
    final desktop = File(
      'linux/io.busystack.busymax.desktop',
    ).readAsStringSync();
    final cmake = File('linux/CMakeLists.txt').readAsStringSync();
    final runner = File('linux/runner/my_application.cc').readAsStringSync();

    expect(desktop, contains('Name=BusyMax'));
    expect(desktop, contains('Icon=io.busystack.busymax'));
    expect(desktop, contains('StartupWMClass=io.busystack.busymax'));
    expect(
      cmake,
      contains(r'"${CMAKE_CURRENT_SOURCE_DIR}/io.busystack.busymax.desktop"'),
    );
    expect(
      cmake,
      contains(
        r'"${CMAKE_CURRENT_SOURCE_DIR}/io.busystack.busymax.metainfo.xml"',
      ),
    );
    expect(
      cmake,
      contains(
        r'"${CMAKE_CURRENT_SOURCE_DIR}/../assets/branding/busymax-logo.svg"',
      ),
    );
    expect(cmake, contains('share/icons/hicolor/scalable/apps'));
    expect(cmake, contains('RENAME "io.busystack.busymax.svg"'));
    const pngExtension = 'png';
    expect(cmake, isNot(contains('.$pngExtension')));
    final iconFileName =
        '${busyMaxApplicationId.split('.').last}.$pngExtension';
    for (final size in [64, 128, 256]) {
      final path = [
        'linux',
        'runner',
        'resources',
        'icons',
        '${size}x$size',
        'apps',
        iconFileName,
      ].join(Platform.pathSeparator);
      expect(File(path).existsSync(), isFalse);
    }
    expect(
      runner,
      contains(
        'gtk_window_set_wmclass(window, APPLICATION_ID, APPLICATION_ID);',
      ),
    );
    expect(runner, contains('static_cast<GApplicationFlags>(0)'));
    expect(runner, isNot(contains('G_APPLICATION_NON_UNIQUE')));
    expect(runner, contains('static void restore_main_window'));
    expect(runner, contains('gtk_widget_show(GTK_WIDGET(self->main_window));'));
    expect(runner, contains('gtk_window_deiconify(self->main_window);'));
    expect(
      runner,
      contains(
        'gtk_window_present_with_time(self->main_window, GDK_CURRENT_TIME);',
      ),
    );
    expect(runner, contains('restore_main_window(self);'));
    expect(runner, contains('BusyMax native showWindow method call received'));
    expect(
      runner,
      contains('BusyMax native showWindow invoked: main_window_null=%s'),
    );
    expect(runner, contains('BusyMax native hideWindow invoked'));
    expect(
      runner,
      contains('BusyMax native hideWindow invocation: source=delete-event'),
    );
    expect(runner, contains('BusyMax native quit invocation: method=quitApp'));
    expect(
      runner,
      contains(
        'if (application_icon == nullptr) {\n'
        '    gtk_window_set_icon_name(window, APPLICATION_ID);\n'
        '  }',
      ),
    );
  });

  test('agenda action opens compact agenda without restoring main first', () {
    final source = File(
      'lib/src/platform/busymax_tray_service.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _showAgenda()'));
    expect(source, contains('return _onOpenAgenda();'));
    expect(source, isNot(contains('BusyMaxTrayAgendaMenu')));
    expect(source, isNot(contains('BusyMaxTrayAgendaEntry')));
    expect(source, contains('StatusNotifierItem activation callback'));
    expect(source, contains('Tray service start requested'));
    expect(source, contains('Tray initialization starting'));
    expect(source, contains('StatusNotifier registration succeeded'));
    expect(source, contains('StatusNotifier registration failed'));
    expect(source, contains('DBus menu creation starting'));
    expect(source, contains('DBus menu creation completed'));
    expect(source, contains('menuPath: DBusObjectPath(busyMaxTrayMenuPath)'));
    expect(source, contains('itemIsMenu: true'));
    expect(source, contains('Tray menu DBus verification succeeded'));
    expect(source, contains('Tray callback fired'));
    expect(source, contains('Tray menu "Open BusyMax" callback'));
    expect(source, contains('Tray menu "Agenda" callback'));
    expect(source, contains('Tray menu "Quit" callback'));
    expect(source, contains('return _windowService.showWindow();'));
    expect(
      source,
      isNot(
        contains(
          'await _windowService.showWindow();\n'
          '    await _onOpenAgenda();',
        ),
      ),
    );
    expect(source, contains('await _onBeforeQuit?.call();'));
  });

  test('DBus menu exposes layout, properties, and routes stable IDs', () async {
    var openedApp = false;
    var quit = false;
    final logs = <String>[];

    final object = DBusMenuObject(
      DBusObjectPath(busyMaxTrayMenuPath),
      buildBusyMaxTrayMenu(
        labels: _labels,
        onOpenBusyMax: () async {
          openedApp = true;
        },
        onOpenAgenda: () async {},
        onQuit: () async {
          quit = true;
        },
      ),
      diagnosticLog: logs.add,
    );

    final layout = await object.handleMethodCall(
      DBusMethodCall(
        sender: 'test',
        interface: 'com.canonical.dbusmenu',
        name: 'GetLayout',
        values: [
          const DBusInt32(0),
          const DBusInt32(-1),
          DBusArray.string(const []),
        ],
      ),
    );
    expect(layout, isA<DBusMethodSuccessResponse>());
    final root = layout.returnValues[1].asStruct();
    expect(root[0].asInt32(), 0);
    final children = root[2]
        .asArray()
        .map((child) => child.asVariant().asStruct())
        .toList();
    expect(children.map((child) => child[0].asInt32()).toList(), [1, 2, 3]);
    for (final child in children) {
      final properties = child[1].asStringVariantDict();
      expect(properties['label']?.asString(), isNotEmpty);
      expect(properties['enabled']?.asBoolean(), isTrue);
      expect(properties['visible']?.asBoolean(), isTrue);
      expect(properties, isNot(contains('children-display')));
    }

    final groupProperties = await object.handleMethodCall(
      DBusMethodCall(
        sender: 'test',
        interface: 'com.canonical.dbusmenu',
        name: 'GetGroupProperties',
        values: [
          DBusArray.int32([1, 2, 3]),
          DBusArray.string(const []),
        ],
      ),
    );
    expect(groupProperties, isA<DBusMethodSuccessResponse>());
    final groupedItems = groupProperties.returnValues.single.asArray();
    expect(groupedItems.map((item) => item.asStruct()[0].asInt32()).toList(), [
      1,
      2,
      3,
    ]);

    final openProperties = groupedItems.first
        .asStruct()[1]
        .asStringVariantDict();
    expect(openProperties['label']?.asString(), 'Open BusyMax');
    expect(openProperties['enabled']?.asBoolean(), isTrue);
    expect(openProperties['visible']?.asBoolean(), isTrue);

    final labelProperty = await object.handleMethodCall(
      DBusMethodCall(
        sender: 'test',
        interface: 'com.canonical.dbusmenu',
        name: 'GetProperty',
        values: [const DBusInt32(1), const DBusString('label')],
      ),
    );
    expect(labelProperty, isA<DBusMethodSuccessResponse>());
    expect(
      labelProperty.returnValues.single.asVariant().asString(),
      'Open BusyMax',
    );

    final aboutToShow = await object.handleMethodCall(
      DBusMethodCall(
        sender: 'test',
        interface: 'com.canonical.dbusmenu',
        name: 'AboutToShow',
        values: [const DBusInt32(1)],
      ),
    );
    expect(aboutToShow, isA<DBusMethodSuccessResponse>());
    expect(aboutToShow.returnValues.single.asBoolean(), isFalse);

    final aboutToShowGroup = await object.handleMethodCall(
      DBusMethodCall(
        sender: 'test',
        interface: 'com.canonical.dbusmenu',
        name: 'AboutToShowGroup',
        values: [
          DBusArray.int32([1, 2, 99]),
        ],
      ),
    );
    expect(aboutToShowGroup, isA<DBusMethodSuccessResponse>());
    expect(aboutToShowGroup.returnValues[0].asInt32Array(), isEmpty);
    expect(aboutToShowGroup.returnValues[1].asInt32Array(), [99]);

    final version = await object.getProperty(
      'com.canonical.dbusmenu',
      'Version',
    );
    expect(version, isA<DBusGetPropertyResponse>());
    expect(version.returnValues.single.asVariant().asUint32(), greaterThan(0));
    final status = await object.getProperty('com.canonical.dbusmenu', 'Status');
    expect(status.returnValues.single.asVariant().asString(), 'normal');
    final textDirection = await object.getProperty(
      'com.canonical.dbusmenu',
      'TextDirection',
    );
    expect(textDirection.returnValues.single.asVariant().asString(), 'ltr');
    final iconThemePath = await object.getProperty(
      'com.canonical.dbusmenu',
      'IconThemePath',
    );
    expect(
      iconThemePath.returnValues.single.asVariant().asStringArray(),
      isEmpty,
    );

    final event = await object.handleMethodCall(
      DBusMethodCall(
        sender: 'test',
        interface: 'com.canonical.dbusmenu',
        name: 'Event',
        values: [
          const DBusInt32(1),
          const DBusString('clicked'),
          const DBusVariant(DBusInt32(0)),
          const DBusUint32(0),
        ],
      ),
    );
    expect(event, isA<DBusMethodSuccessResponse>());
    expect(openedApp, isTrue);

    final eventGroup = await object.handleMethodCall(
      DBusMethodCall(
        sender: 'test',
        interface: 'com.canonical.dbusmenu',
        name: 'EventGroup',
        values: [
          DBusArray(DBusSignature('(isvu)'), [
            DBusStruct([
              const DBusInt32(3),
              const DBusString('clicked'),
              const DBusVariant(DBusInt32(0)),
              const DBusUint32(0),
            ]),
          ]),
        ],
      ),
    );
    expect(eventGroup, isA<DBusMethodSuccessResponse>());
    expect(eventGroup.returnValues.single.asInt32Array(), isEmpty);
    expect(quit, isTrue);
    expect(logs, contains(startsWith('DBusMenu.GetLayout received')));
    expect(logs, contains(startsWith('DBusMenu.GetGroupProperties received')));
    expect(logs, contains(startsWith('DBusMenu.GetProperty received')));
    expect(logs, contains(startsWith('DBusMenu.AboutToShow received')));
    expect(logs, contains(startsWith('DBusMenu.AboutToShowGroup received')));
    expect(logs, contains(startsWith('DBusMenu.Event received')));
    expect(logs, contains(startsWith('DBusMenu.EventGroup received')));
  });

  test('patched status notifier and DBus menu handle Ubuntu tray calls', () {
    final source = File(
      'third_party/xdg_status_notifier_item/lib/src/dbus_menu_object.dart',
    ).readAsStringSync();
    final statusNotifier = File(
      'third_party/xdg_status_notifier_item/lib/src/status_notifier_item_client.dart',
    ).readAsStringSync();

    expect(source, contains('var values = event.asStruct();'));
    expect(source, contains(r'DBusMenu.${methodCall.name} received'));
    expect(source, contains('GetGroupProperties'));
    expect(source, contains('DBusMenu.GetLayout details'));
    expect(source, contains('DBusMenu.GetProperty details'));
    expect(source, contains('DBusMenu.AboutToShow details'));
    expect(source, contains('DBusMenu.AboutToShowGroup details'));
    expect(source, contains("DBusString('normal')"));
    expect(source, contains("DBusString('ltr')"));
    expect(source, contains('DBusArray.string(const [])'));
    expect(source, contains('_itemsById[id]'));
    expect(statusNotifier, contains("'/StatusNotifierItem/menu'"));
    expect(statusNotifier, contains('org.kde.StatusNotifierItem'));
    expect(statusNotifier, contains('org.freedesktop.StatusNotifierItem'));
    expect(
      statusNotifier,
      contains(r'StatusNotifierItem.${methodCall.name} received'),
    );
  });
}

const _labels = BusyMaxTrayLabels(
  openBusyMax: 'Open BusyMax',
  agenda: 'Agenda',
  quitBusyMax: 'Exit',
);
