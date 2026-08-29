import 'dart:async';
import 'dart:io';

import 'package:busymax/src/features/tray/domain/tray_presentation.dart';
import 'package:busymax/src/platform/busymax_tray_service.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xdg_status_notifier_item/xdg_status_notifier_item.dart';

void main() {
  test('every presentation retains the fixed hierarchy and ID sequence', () {
    final presentations = [
      _presentation(),
      _presentation(events: [_row('one')]),
      _presentation(
        events: [_row('one'), _row('two'), _row('three')],
        taskSummary: '3 tasks due today',
      ),
      _presentation(
        offline: true,
        canCreateEvent: false,
        canCreateTask: false,
        canSynchronize: false,
      ),
    ];

    for (final presentation in presentations) {
      final menu = buildBusyMaxTrayMenu(
        presentation: presentation,
        actions: _Actions().value,
      );
      expect(menu.id, BusyMaxTrayMenuIds.root);
      expect(
        menu.children.map((item) => item.id),
        BusyMaxTrayMenuIds.orderedChildren,
      );
      expect(menu.children, hasLength(18));
      expect(
        menu.children
            .where((item) => item.type == 'separator')
            .map((item) => item.id),
        [2, 5, 13, 16],
      );
      expect(
        menu.children.where((item) => item.type == 'separator'),
        everyElement(
          isA<DBusMenuItem>().having((item) => item.visible, 'visible', isTrue),
        ),
      );
      expect(_item(menu, BusyMaxTrayMenuIds.today).enabled, isFalse);
      expect(_item(menu, BusyMaxTrayMenuIds.today).visible, isTrue);
    }
  });

  test('unused slots become invisible and task and empty rows are correct', () {
    final oneEvent = buildBusyMaxTrayMenu(
      presentation: _presentation(events: [_row('event')]),
      actions: _Actions().value,
    );
    expect(_item(oneEvent, 7).visible, isTrue);
    expect(_item(oneEvent, 8).visible, isFalse);
    expect(_item(oneEvent, 9).visible, isFalse);
    expect(_item(oneEvent, 10).visible, isFalse);
    expect(_item(oneEvent, 11).visible, isFalse);

    final taskOnly = buildBusyMaxTrayMenu(
      presentation: _presentation(taskSummary: '1 task due today'),
      actions: _Actions().value,
    );
    expect(_item(taskOnly, 10).visible, isTrue);
    expect(_item(taskOnly, 10).enabled, isTrue);
    expect(_item(taskOnly, 11).visible, isFalse);

    final empty = buildBusyMaxTrayMenu(
      presentation: _presentation(),
      actions: _Actions().value,
    );
    expect(_item(empty, 10).visible, isFalse);
    expect(_item(empty, 11).visible, isTrue);
    expect(_item(empty, 11).enabled, isFalse);
  });

  test('creation and synchronization enabled states follow presentation', () {
    final disabled = buildBusyMaxTrayMenu(
      presentation: _presentation(
        canCreateEvent: false,
        canCreateTask: false,
        canSynchronize: false,
      ),
      actions: _Actions().value,
    );
    expect(_item(disabled, 3).enabled, isFalse);
    expect(_item(disabled, 4).enabled, isFalse);
    expect(_item(disabled, 14).enabled, isFalse);
    expect(_item(disabled, 15).enabled, isFalse);

    final enabled = buildBusyMaxTrayMenu(
      presentation: _presentation(),
      actions: _Actions().value,
    );
    expect(_item(enabled, 3).enabled, isTrue);
    expect(_item(enabled, 4).enabled, isTrue);
    expect(_item(enabled, 14).enabled, isTrue);
  });

  test('event callback is rebound to the current slot identity', () async {
    final opened = <String>[];
    var next = _presentation(events: [_row('first')]);
    final actions = _Actions(
      onOpenEvent: (event) async {
        opened.add(event.eventId);
      },
    );
    final controller = BusyMaxTrayMenuController(
      initialPresentation: next,
      loadPresentation: () async => next,
      actions: actions.value,
    );
    final object = DBusMenuObject(
      DBusObjectPath(busyMaxTrayMenuPath),
      controller.menu,
    );
    controller.attachUpdater((menu, presentation) => object.update(menu));

    await _click(object, BusyMaxTrayMenuIds.firstEvent);
    next = _presentation(events: [_row('second')]);
    expect(await controller.refresh(), isTrue);
    await _click(object, BusyMaxTrayMenuIds.firstEvent);

    expect(opened, ['first', 'second']);
  });

  test(
    'AboutToShow updates properties and unchanged loads return false',
    () async {
      var loads = 0;
      var next = _presentation();
      final controller = BusyMaxTrayMenuController(
        initialPresentation: next,
        loadPresentation: () async {
          loads += 1;
          return next;
        },
        actions: _Actions().value,
      );
      final object = DBusMenuObject(
        DBusObjectPath(busyMaxTrayMenuPath),
        controller.menu,
      );
      var updates = 0;
      controller.attachUpdater((menu, presentation) {
        updates += 1;
        return object.update(menu);
      });

      final unchanged = await _aboutToShow(object);
      expect(unchanged, isFalse);
      expect(updates, 0);
      next = _presentation(events: [_row('updated')]);
      final changed = await _aboutToShow(object);
      expect(changed, isTrue);
      expect(updates, 1);
      final label = await _property(
        object,
        BusyMaxTrayMenuIds.firstEvent,
        'label',
      );
      expect(label.asString(), '10:30 · updated');
      expect(loads, 2);
    },
  );

  test('simultaneous presentation loads are coalesced', () async {
    var loads = 0;
    final completer = Completer<BusyMaxTrayMenuPresentation>();
    final controller = BusyMaxTrayMenuController(
      initialPresentation: _presentation(),
      loadPresentation: () {
        loads += 1;
        return completer.future;
      },
      actions: _Actions().value,
    );

    final first = controller.refresh();
    final second = controller.refresh();
    completer.complete(_presentation(events: [_row('loaded')]));

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(loads, 1);
  });

  test('load failure retains the previous menu and core actions', () async {
    final failures = <Object>[];
    final initial = _presentation(events: [_row('retained')]);
    final controller = BusyMaxTrayMenuController(
      initialPresentation: initial,
      loadPresentation: () async => throw StateError('local load failed'),
      actions: _Actions().value,
      onLoadFailure: failures.add,
    );

    expect(await controller.refresh(), isFalse);
    expect(controller.presentation, initial);
    expect(_item(controller.menu, 1).enabled, isTrue);
    expect(_item(controller.menu, 17).enabled, isTrue);
    expect(_item(controller.menu, 18).enabled, isTrue);
    expect(failures.single, isA<StateError>());
  });

  test('AboutToShow performs no synchronization', () async {
    var syncs = 0;
    final actions = _Actions(onSynchronize: () async => syncs += 1);
    final controller = BusyMaxTrayMenuController(
      initialPresentation: _presentation(),
      loadPresentation: () async => _presentation(),
      actions: actions.value,
    );
    final object = DBusMenuObject(
      DBusObjectPath(busyMaxTrayMenuPath),
      controller.menu,
    );

    await _aboutToShow(object);

    expect(syncs, 0);
  });

  test('Activate restores and SecondaryActivate opens today agenda', () async {
    var shown = 0;
    var agendas = 0;
    final actions = _Actions(
      onShow: () async => shown += 1,
      onAgenda: () async => agendas += 1,
    );
    final service = BusyMaxTrayService(
      configuration: BusyMaxTrayServiceConfiguration(
        initialPresentation: _presentation(),
        loadPresentation: () async => _presentation(),
        actions: actions.value,
      ),
    );

    await service.handleActivate();
    await service.handleSecondaryActivate();

    expect(shown, 1);
    expect(agendas, 1);
    final source = File(
      'lib/src/platform/busymax_tray_service.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('onContextMenu:')));
  });

  test('Quit invokes the existing application quit callback', () async {
    var quits = 0;
    final menu = buildBusyMaxTrayMenu(
      presentation: _presentation(),
      actions: _Actions(onQuit: () async => quits += 1).value,
    );

    await _item(menu, BusyMaxTrayMenuIds.quitBusyMax).onClicked?.call();

    expect(quits, 1);
  });

  test('a disappeared event fails safely when its row is activated', () async {
    final menu = buildBusyMaxTrayMenu(
      presentation: _presentation(events: [_row('removed')]),
      actions: _Actions(
        onOpenEvent: (_) async => throw StateError('event disappeared'),
      ).value,
    );

    await expectLater(
      _item(menu, BusyMaxTrayMenuIds.firstEvent).onClicked?.call(),
      completes,
    );
  });

  test('DBus layout exports all fixed IDs and properties', () async {
    final object = DBusMenuObject(
      DBusObjectPath(busyMaxTrayMenuPath),
      buildBusyMaxTrayMenu(
        presentation: _presentation(events: [_row('event')]),
        actions: _Actions().value,
      ),
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
    final root = layout.returnValues[1].asStruct();
    final children = root[2]
        .asArray()
        .map((child) => child.asVariant().asStruct())
        .toList();

    expect(root[0].asInt32(), BusyMaxTrayMenuIds.root);
    expect(
      children.map((child) => child[0].asInt32()),
      BusyMaxTrayMenuIds.orderedChildren,
    );
    expect(
      children
          .singleWhere(
            (child) => child[0].asInt32() == BusyMaxTrayMenuIds.today,
          )[1]
          .asStringVariantDict()['enabled']
          ?.asBoolean(),
      isFalse,
    );
  });

  test('offline tray icon remains the bundled grayscale asset', () {
    final asset = File('assets/branding/busymax-logo-offline.svg');
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(asset.existsSync(), isTrue);
    expect(asset.readAsStringSync(), contains('BusyMax offline'));
    expect(asset.readAsStringSync(), isNot(contains('#950BfF')));
    expect(pubspec, contains('assets/branding/busymax-logo-offline.svg'));
  });

  test('status notifier presentation can update before registration', () async {
    final bus = DBusClient(
      DBusAddress.unix(path: '/tmp/busymax-status-notifier-test-bus'),
    );
    final client = StatusNotifierItemClient(
      id: busyMaxApplicationId,
      title: 'BusyMax',
      iconName: 'busymax-color',
      toolTipTitle: 'BusyMax',
      toolTipDescription: '',
      menu: buildBusyMaxTrayMenu(
        presentation: _presentation(),
        actions: _Actions().value,
      ),
      bus: bus,
    );
    addTearDown(bus.close);

    await client.updatePresentation(
      title: 'BusyMax — Offline',
      iconName: 'busymax-offline',
      toolTipTitle: 'BusyMax — Offline',
      toolTipDescription: 'Changes will sync when connected.',
    );

    expect(client.title, 'BusyMax — Offline');
    expect(client.iconName, 'busymax-offline');
    expect(client.toolTipTitle, 'BusyMax — Offline');
    expect(client.toolTipDescription, 'Changes will sync when connected.');
  });

  test('Linux desktop identity matches the displayed BusyMax window', () {
    final desktop = File(
      'linux/io.busystack.busymax.desktop',
    ).readAsStringSync();
    final cmake = File('linux/CMakeLists.txt').readAsStringSync();
    final runner = File('linux/runner/my_application.cc').readAsStringSync();

    expect(busyMaxApplicationId, 'io.busystack.busymax');
    expect(busyMaxTrayMenuPath, '/StatusNotifierItem/menu');
    expect(desktop, contains('Name=BusyMax'));
    expect(desktop, contains('Icon=io.busystack.busymax'));
    expect(desktop, contains('StartupWMClass=io.busystack.busymax'));
    expect(
      cmake,
      contains(r'"${CMAKE_CURRENT_SOURCE_DIR}/io.busystack.busymax.desktop"'),
    );
    expect(runner, contains('G_APPLICATION_HANDLES_OPEN'));
    expect(runner, isNot(contains('G_APPLICATION_NON_UNIQUE')));
    expect(runner, contains('static void restore_main_window'));
  });

  test('vendored DBus implementation retains Ubuntu menu support', () {
    final source = File(
      'third_party/xdg_status_notifier_item/lib/src/dbus_menu_object.dart',
    ).readAsStringSync();
    final notifier = File(
      'third_party/xdg_status_notifier_item/lib/src/status_notifier_item_client.dart',
    ).readAsStringSync();

    expect(source, contains('var values = event.asStruct();'));
    expect(source, contains(r'DBusMenu.${methodCall.name} received'));
    expect(source, contains('GetGroupProperties'));
    expect(source, contains('DBusMenu.AboutToShow details'));
    expect(source, contains('_itemsById[id]'));
    expect(notifier, contains("'/StatusNotifierItem/menu'"));
    expect(notifier, contains('org.kde.StatusNotifierItem'));
    expect(notifier, contains('Future<void> updatePresentation'));
  });
}

DBusMenuItem _item(DBusMenuItem menu, int id) {
  return menu.children.singleWhere((item) => item.id == id);
}

Future<void> _click(DBusMenuObject object, int id) async {
  await object.handleMethodCall(
    DBusMethodCall(
      sender: 'test',
      interface: 'com.canonical.dbusmenu',
      name: 'Event',
      values: [
        DBusInt32(id),
        const DBusString('clicked'),
        const DBusVariant(DBusInt32(0)),
        const DBusUint32(0),
      ],
    ),
  );
}

Future<bool> _aboutToShow(DBusMenuObject object) async {
  final response = await object.handleMethodCall(
    DBusMethodCall(
      sender: 'test',
      interface: 'com.canonical.dbusmenu',
      name: 'AboutToShow',
      values: [const DBusInt32(BusyMaxTrayMenuIds.root)],
    ),
  );
  return response.returnValues.single.asBoolean();
}

Future<DBusValue> _property(DBusMenuObject object, int id, String name) async {
  final response = await object.handleMethodCall(
    DBusMethodCall(
      sender: 'test',
      interface: 'com.canonical.dbusmenu',
      name: 'GetProperty',
      values: [DBusInt32(id), DBusString(name)],
    ),
  );
  return response.returnValues.single.asVariant();
}

BusyMaxTrayEventRowPresentation _row(String id) {
  return BusyMaxTrayEventRowPresentation(
    event: BusyMaxTrayEventEntry(
      eventId: id,
      accountId: 'account',
      calendarSourceId: 'calendar',
      title: id,
      start: DateTime(2026, 8, 29, 10, 30),
      end: DateTime(2026, 8, 29, 11),
      allDay: false,
    ),
    label: '10:30 · $id',
  );
}

BusyMaxTrayMenuPresentation _presentation({
  List<BusyMaxTrayEventRowPresentation> events = const [],
  String? taskSummary,
  bool canCreateEvent = true,
  bool canCreateTask = true,
  bool canSynchronize = true,
  bool offline = false,
}) {
  return BusyMaxTrayMenuPresentation(
    showBusyMaxLabel: 'Show BusyMax',
    newEventLabel: 'New event…',
    newTaskLabel: 'New task…',
    todayLabel: 'Today',
    eventRows: events,
    taskSummaryLabel: taskSummary,
    emptyStateLabel: 'Nothing else today',
    openTodayAgendaLabel: 'Open today’s agenda',
    syncNowLabel: 'Sync now',
    synchronizationStatusLabel: offline
        ? 'Offline — Changes will sync when connected.'
        : 'Last synced just now',
    settingsLabel: 'Settings',
    quitBusyMaxLabel: 'Quit BusyMax',
    offlineTitle: 'Offline',
    offlineDescription: 'Changes will sync when connected.',
    canCreateEvent: canCreateEvent,
    canCreateTask: canCreateTask,
    canSynchronize: canSynchronize,
    offline: offline,
  );
}

final class _Actions {
  _Actions({
    Future<void> Function()? onShow,
    Future<void> Function(BusyMaxTrayEventEntry event)? onOpenEvent,
    Future<void> Function()? onAgenda,
    Future<void> Function()? onSynchronize,
    Future<void> Function()? onQuit,
  }) : value = BusyMaxTrayActions(
         showBusyMax: onShow ?? _noop,
         newEvent: _noop,
         newTask: _noop,
         openEvent: onOpenEvent ?? _noopEvent,
         openTasksDueToday: _noop,
         openTodayAgenda: onAgenda ?? _noop,
         synchronize: onSynchronize ?? _noop,
         openSettings: _noop,
         quitBusyMax: onQuit ?? _noop,
       );

  final BusyMaxTrayActions value;
}

Future<void> _noop() async {}
Future<void> _noopEvent(BusyMaxTrayEventEntry event) async {}
