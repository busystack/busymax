import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/platform/application_tray.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';

DBusMethodCall request(String name, List<DBusValue> values) => DBusMethodCall(
  sender: 'fixture',
  interface: 'com.canonical.dbusmenu',
  name: name,
  values: values,
);

DBusStruct click(int id) => DBusStruct([
  DBusInt32(id),
  const DBusString('clicked'),
  const DBusVariant(DBusInt32(0)),
  const DBusUint32(0),
]);

void main() {
  test(
    'stable IDs survive topology changes, filters and late events',
    () async {
      final clicked = <String>[];
      final menu = ApplicationTrayMenu(
        DBusObjectPath('/fixture'),
        ApplicationTrayItem(
          id: 0,
          children: [
            ApplicationTrayItem(
              id: 91,
              label: 'Old',
              onClicked: () async => clicked.add('old'),
            ),
          ],
        ),
      );
      final first = await menu.handleMethodCall(
        request('GetLayout', [
          const DBusInt32(0),
          const DBusInt32(-1),
          DBusArray.string(['label']),
        ]),
      );
      expect(first.returnValues.first.asUint32(), 1);
      await menu.update(
        ApplicationTrayItem(
          id: 0,
          children: [
            ApplicationTrayItem(
              id: 72,
              label: 'New',
              enabled: true,
              onClicked: () async => clicked.add('new'),
            ),
          ],
        ),
      );
      final layout = await menu.handleMethodCall(
        request('GetLayout', [
          const DBusInt32(0),
          const DBusInt32(-1),
          DBusArray.string(['label']),
        ]),
      );
      expect(layout.returnValues.first.asUint32(), 2);
      final child = layout.returnValues[1]
          .asStruct()[2]
          .asArray()
          .single
          .asVariant()
          .asStruct();
      expect(child[0].asInt32(), 72);
      expect(child[1].asStringVariantDict(), {
        'label': const DBusString('New'),
      });
      final response = await menu.handleMethodCall(
        request('EventGroup', [
          DBusArray(DBusSignature('(isvu)'), [click(91), click(72), click(-1)]),
        ]),
      );
      expect(response.returnValues.single.asInt32Array(), [91, -1]);
      expect(clicked, ['new']);
    },
  );

  test(
    'invalid identities, signatures, disabled actions and failures are safe',
    () async {
      var clicked = 0;
      expect(
        () => ApplicationTrayMenu(
          DBusObjectPath('/fixture'),
          ApplicationTrayItem(
            id: 0,
            children: [ApplicationTrayItem(id: 1), ApplicationTrayItem(id: 1)],
          ),
        ),
        throwsArgumentError,
      );
      final menu = ApplicationTrayMenu(
        DBusObjectPath('/fixture'),
        ApplicationTrayItem(
          id: 0,
          children: [
            ApplicationTrayItem(
              id: 72,
              enabled: false,
              onClicked: () async {
                clicked++;
              },
            ),
            ApplicationTrayItem(
              id: 81,
              onClicked: () async => throw StateError('private detail'),
            ),
            ApplicationTrayItem(
              id: 93,
              onClicked: () async {
                clicked++;
              },
            ),
          ],
        ),
      );
      final malformed = await menu.handleMethodCall(
        request('Event', [const DBusString('invalid')]),
      );
      expect(malformed, isA<DBusMethodErrorResponse>());
      final response = await menu.handleMethodCall(
        request('EventGroup', [
          DBusArray(DBusSignature('(isvu)'), [click(72), click(81), click(93)]),
        ]),
      );
      expect(response.returnValues.single.asInt32Array(), [72, 81]);
      expect(clicked, 1);
      final error = await menu.handleMethodCall(
        request('Event', click(81).asStruct()),
      );
      expect(error.toString(), isNot(contains('private detail')));
    },
  );

  test(
    'real private bus exports Ubuntu menu, presentation, signals and actions',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'busymax-tray-bus-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final daemon = await Process.start('dbus-daemon', [
        '--session',
        '--nofork',
        '--print-address=1',
        '--address=unix:path=${directory.path}/bus',
      ]);
      final daemonErrors = daemon.stderr.drain<void>();
      addTearDown(() async {
        daemon.kill();
        await daemon.exitCode.timeout(const Duration(seconds: 5));
        await daemonErrors;
      });
      final address = DBusAddress(
        await daemon.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 5)),
      );
      final observer = DBusClient(address);
      addTearDown(observer.close);
      final watcher = _Watcher();
      await observer.registerObject(watcher);
      expect(
        await observer.requestName('org.kde.StatusNotifierWatcher'),
        DBusRequestNameReply.primaryOwner,
      );
      var activated = 0, clicked = 0;
      final client = ApplicationTrayClient(
        id: 'io.busystack.fixture',
        title: 'Initial',
        iconName: 'icon',
        itemIsMenu: true,
        busAddress: address,
        onActivate: (_, _) async {
          activated++;
        },
        menu: ApplicationTrayItem(
          id: 0,
          children: [
            ApplicationTrayItem(
              id: 82,
              label: 'Open',
              onClicked: () async {
                clicked++;
              },
            ),
          ],
        ),
      );
      addTearDown(client.close);
      await client.connect();
      expect(
        await watcher.registration.future.timeout(const Duration(seconds: 5)),
        client.busName,
      );
      final item = DBusRemoteObject(
        observer,
        name: client.busName,
        path: client.itemPath,
      );
      expect(
        (await item.getProperty(
          'org.kde.StatusNotifierItem',
          'Menu',
        )).asObjectPath(),
        client.menuPath,
      );
      expect(
        (await item.getProperty(
          'org.kde.StatusNotifierItem',
          'ItemIsMenu',
        )).asBoolean(),
        isTrue,
      );
      final tooltip = await item.getProperty(
        'org.kde.StatusNotifierItem',
        'ToolTip',
      );
      expect(tooltip.signature, DBusSignature('(sa(iiay)ss)'));
      await item.callMethod('org.kde.StatusNotifierItem', 'Activate', [
        const DBusInt32(0),
        const DBusInt32(0),
      ]);
      expect(activated, 1);
      final menu = DBusRemoteObject(
        observer,
        name: client.busName,
        path: client.menuPath,
      );
      final layout = await menu.callMethod(
        'com.canonical.dbusmenu',
        'GetLayout',
        [const DBusInt32(0), const DBusInt32(-1), DBusArray.string([])],
      );
      expect(
        layout.returnValues[1]
            .asStruct()[2]
            .asArray()
            .single
            .asVariant()
            .asStruct()[0]
            .asInt32(),
        82,
      );
      await menu.callMethod('com.canonical.dbusmenu', 'EventGroup', [
        DBusArray(DBusSignature('(isvu)'), [click(82)]),
      ]);
      expect(clicked, 1);
      final signal = DBusRemoteObjectSignalStream(
        object: item,
        interface: 'org.kde.StatusNotifierItem',
        name: 'NewTitle',
      ).first;
      await item.getProperty('org.kde.StatusNotifierItem', 'Title');
      await client.updatePresentation(
        title: 'Updated',
        toolTipTitle: 'Updated',
      );
      await signal.timeout(const Duration(seconds: 5));
      expect(
        (await item.getProperty(
          'org.kde.StatusNotifierItem',
          'Title',
        )).asString(),
        'Updated',
      );
      final xml = await item.introspect();
      expect(
        xml.interfaces.any(
          (value) => value.name == 'org.kde.StatusNotifierItem',
        ),
        isTrue,
      );
    },
    skip: !Platform.isLinux,
  );
}

class _Watcher extends DBusObject {
  _Watcher() : super(DBusObjectPath('/StatusNotifierWatcher'));
  final registration = Completer<String>();
  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == 'org.kde.StatusNotifierWatcher' &&
        methodCall.name == 'RegisterStatusNotifierItem' &&
        methodCall.signature == DBusSignature('s')) {
      registration.complete(methodCall.values.single.asString());
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}
