import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:busymax/src/platform/linux/linux_notification_backend.dart';
import 'package:desktop_notifications/desktop_notifications.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';

void main() {
  test('server absence preserves pending operations until recovery', () async {
    final directory = await Directory.systemTemp.createTemp(
      'busymax-no-server-',
    );
    final server = DBusServer();
    final address = await server.listenAddress(
      DBusAddress.unix(path: '${directory.path}/bus'),
    );
    final daemon = DBusClient(address);
    final object = _NotificationDaemon();
    await daemon.registerObject(object);
    final file = File('${directory.path}/ids.json');
    final backend = FreedesktopNotificationBackend(
      bus: DBusClient(address),
      identityFile: file,
    );
    addTearDown(() async {
      await backend.close();
      await daemon.close();
      await server.close();
      await directory.delete(recursive: true);
    });
    final states = <bool>[];
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults(),
      onDeliveryStateChanged: states.add,
    );
    const id = 'event|source|generation';
    await service.reconcileReminderIdentities({id});
    expect(states, [false]);
    expect(
      (await service.notifyEventReminder('Pending', '', stableId: id)).status,
      ReminderDeliveryStatus.failed,
    );
    expect(await file.exists(), isFalse);

    await daemon.requestName('org.freedesktop.Notifications');
    expect(
      (await service.notifyEventReminder('Pending', '', stableId: id)).status,
      ReminderDeliveryStatus.delivered,
    );
    final persisted = await file.readAsString();
    await daemon.releaseName('org.freedesktop.Notifications');
    await service.reconcileReminderIdentities({});
    expect(await service.cancelReminder(id), isFalse);
    expect(object.closeCalls, 0);
    expect(await file.readAsString(), persisted);

    // The same owner recovering must retain, then withdraw, its native ID.
    await daemon.requestName('org.freedesktop.Notifications');
    expect(await backend.knownReminderDeliveryIds(), {id});
    await service.retryReminderCancellations();
    expect(object.closeCalls, 1);
    expect(await backend.knownReminderDeliveryIds(), isEmpty);
    expect((jsonDecode(await file.readAsString()) as Map)['ids'], isEmpty);
    await service.retryReminderCancellations();
    expect(object.closeCalls, 1);
  }, skip: !Platform.isLinux);

  test('persisted IDs restore only for the same notification server', () async {
    final directory = await Directory.systemTemp.createTemp(
      'busymax-server-id-',
    );
    final server = DBusServer();
    final address = await server.listenAddress(
      DBusAddress.unix(path: '${directory.path}/bus'),
    );
    final daemon = DBusClient(address);
    final replacementDaemon = DBusClient(address);
    final original = _NotificationDaemon()..capabilities = ['body-markup'];
    final replacement = _NotificationDaemon();
    await daemon.registerObject(original);
    await replacementDaemon.registerObject(replacement);
    await daemon.requestName('org.freedesktop.Notifications');
    final file = File('${directory.path}/ids.json');
    final backend = FreedesktopNotificationBackend(
      bus: DBusClient(address),
      identityFile: file,
    );
    final restored = FreedesktopNotificationBackend(
      bus: DBusClient(address),
      identityFile: file,
    );
    addTearDown(() async {
      await backend.close();
      await restored.close();
      await daemon.close();
      await replacementDaemon.close();
      await server.close();
      await directory.delete(recursive: true);
    });
    const request = BusyMaxNotificationRequest(
      stableId: 'task|source|generation',
      title: 'Persistent identity',
      body: 'One & two',
    );
    await backend.notify(request);
    expect(original.body, 'One &amp; two');
    expect(await restored.knownReminderDeliveryIds(), {request.stableId});
    final persisted = await file.readAsString();
    await daemon.releaseName('org.freedesktop.Notifications');
    await expectLater(restored.knownReminderDeliveryIds(), throwsStateError);
    expect(await file.readAsString(), persisted);

    await replacementDaemon.requestName('org.freedesktop.Notifications');
    // A replacement server may reuse ID 1 for another application's post.
    await backend.cancel(request.stableId);
    await restored.cancel(request.stableId);
    expect(original.closeCalls, 0);
    expect(replacement.closeCalls, 0);
    expect(await backend.knownReminderDeliveryIds(), isEmpty);
    await backend.notify(request);
    expect(replacement.replacesId, 0);
    expect(replacement.body, 'One & two');
    expect(await backend.knownReminderDeliveryIds(), {request.stableId});
    await backend.cancel(request.stableId);
    expect(replacement.closeCalls, 1);
    expect(await backend.knownReminderDeliveryIds(), isEmpty);
  }, skip: !Platform.isLinux);

  test('native withdrawal uses the same D-Bus sender as delivery and retries failure', () async {
    final directory = await Directory.systemTemp.createTemp(
      'busymax-notification-bus-',
    );
    final server = DBusServer();
    final address = await server.listenAddress(
      DBusAddress.unix(path: '${directory.path}/bus'),
    );
    final daemon = DBusClient(address);
    final object = _NotificationDaemon();
    await daemon.registerObject(object);
    await daemon.requestName('org.freedesktop.Notifications');
    final backend = FreedesktopNotificationBackend(
      bus: DBusClient(address),
      identityFile: File('${directory.path}/ids.json'),
    );
    addTearDown(() async {
      await backend.close();
      await daemon.close();
      await server.close();
      await directory.delete(recursive: true);
    });
    await backend.probe();
    await backend.notify(
      const BusyMaxNotificationRequest(
        stableId: 'event|source|generation',
        title: 'Native path',
      ),
    );
    object.failClose = true;
    await expectLater(
      backend.cancel('event|source|generation'),
      throwsA(isA<DBusMethodResponseException>()),
    );
    expect(await backend.knownReminderDeliveryIds(), {
      'event|source|generation',
    });
    object.failClose = false;
    await backend.cancel('event|source|generation');
    expect(object.closedBy, object.submittedBy);
    expect(object.closeCalls, 2);
    expect(await backend.knownReminderDeliveryIds(), isEmpty);
  }, skip: !Platform.isLinux);

  for (final route in ['due-today', 'sync-failure', 'conflict']) {
    test(
      '$route default action shows the window and opens its destination',
      () async {
        final client = _Client();
        final backend = FreedesktopNotificationBackend(client: client);
        final window = _Window();
        final navigation = QueuedDesktopNavigationService();
        final settings = AppSettings.defaults().copyWith(notifyDueToday: true);
        final container = ProviderContainer(
          overrides: [
            appSettingsControllerProvider.overrideWith(
              (ref) => AppSettingsController(
                MemorySettingsStore(),
                initialSettings: settings,
              ),
            ),
            desktopNotificationBackendProvider.overrideWithValue(backend),
            desktopWindowServiceProvider.overrideWithValue(window),
            desktopNavigationServiceProvider.overrideWithValue(navigation),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(navigation.dispose);
        final destination = navigation.requests.first;
        final service = container.read(desktopNotificationServiceProvider);
        switch (route) {
          case 'due-today':
            await service.notifyDueToday(2);
          case 'sync-failure':
            await service.notifySyncFailure(StateError('unavailable'));
          case 'conflict':
            await service.notifyConflict('Changed remotely');
        }
        expect(client.actions.map((action) => action.key), ['default']);
        client.notifications.single.actionResult.complete('default');
        expect(
          (await destination.timeout(const Duration(seconds: 1))).destination,
          route == 'due-today'
              ? DesktopNavigationDestination.tasks
              : DesktopNavigationDestination.settings,
        );
        expect(window.shown, 1);
      },
    );
  }

  for (final markup in [false, true]) {
    test(
      'plain preview uses escaping only when body markup is supported ($markup)',
      () async {
        final client = _Client()..capabilities = [if (markup) 'body-markup'];
        final backend = FreedesktopNotificationBackend(client: client);
        await backend.notify(
          const BusyMaxNotificationRequest(
            stableId: 'preview',
            title: 'Title',
            body: 'One & two\n2 < 3 > 1',
          ),
        );
        expect(
          client.body,
          markup ? 'One &amp; two\n2 &lt; 3 &gt; 1' : 'One & two\n2 < 3 > 1',
        );
      },
    );
  }

  test(
    'failed close retains the native handle for another cancellation',
    () async {
      final client = _Client();
      final backend = FreedesktopNotificationBackend(client: client);
      await backend.notify(
        const BusyMaxNotificationRequest(stableId: 'reminder', title: 'Title'),
      );
      final notification = client.notifications.single;
      notification.closeError = StateError('temporary failure');
      await expectLater(backend.cancel('reminder'), throwsStateError);
      notification.closeError = null;
      await backend.cancel('reminder');
      expect(notification.closeCalls, 2);
      await backend.cancel('reminder');
      expect(notification.closeCalls, 2);
    },
  );

  test(
    'an old notification closing does not discard its replacement handle',
    () async {
      final client = _Client();
      final backend = FreedesktopNotificationBackend(client: client);
      const request = BusyMaxNotificationRequest(
        stableId: 'reminder',
        title: 'Title',
      );
      await backend.notify(request);
      final old = client.notifications.single;
      await backend.notify(request);
      expect(client.replacesId, old.id);
      old.closed.complete(NotificationClosedReason.values.first);
      await Future<void>.delayed(Duration.zero);
      await backend.cancel('reminder');
      expect(client.notifications.last.closeCalls, 1);
      expect(old.closeCalls, 0);
    },
  );
}

class _NotificationDaemon extends DBusObject {
  _NotificationDaemon()
    : super(DBusObjectPath('/org/freedesktop/Notifications'));
  String? submittedBy;
  String? closedBy;
  bool failClose = false;
  int closeCalls = 0;
  List<String> capabilities = ['actions', 'body'];
  String? body;
  int? replacesId;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    switch (call.name) {
      case 'GetCapabilities':
        return DBusMethodSuccessResponse([DBusArray.string(capabilities)]);
      case 'Notify':
        submittedBy = call.sender;
        replacesId = (call.values[1] as DBusUint32).value;
        body = (call.values[4] as DBusString).value;
        return DBusMethodSuccessResponse([DBusUint32(1)]);
      case 'CloseNotification':
        closeCalls++;
        closedBy = call.sender;
        if (failClose || closedBy != submittedBy) {
          return DBusMethodErrorResponse(
            'org.freedesktop.DBus.Error.InvalidArgs',
            [DBusString('Invalid notification ID')],
          );
        }
        return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

class _Client extends Fake implements NotificationsClient {
  List<String> capabilities = ['body-markup'];
  final notifications = <_Notification>[];
  String? body;
  int? replacesId;
  List<NotificationAction> actions = [];

  @override
  Future<List<String>> getCapabilities() async => capabilities;

  @override
  Future<Notification> notify(
    String summary, {
    String body = '',
    String appName = '',
    String appIcon = '',
    int expireTimeoutMs = -1,
    int replacesId = 0,
    List<NotificationHint> hints = const [],
    List<NotificationAction> actions = const [],
  }) async {
    this.body = body;
    this.replacesId = replacesId;
    this.actions = actions;
    final notification = _Notification(notifications.length + 1);
    notifications.add(notification);
    return notification;
  }
}

class _Notification extends Fake implements Notification {
  _Notification(this.id);
  @override
  final int id;
  final actionResult = Completer<String>();
  final closed = Completer<NotificationClosedReason>();
  Object? closeError;
  int closeCalls = 0;

  @override
  Future<String> get action => actionResult.future;
  @override
  Future<NotificationClosedReason> get closeReason => closed.future;
  @override
  Future<void> close() async {
    closeCalls++;
    if (closeError != null) throw closeError!;
  }
}

class _Window extends Fake implements DesktopWindowService {
  int shown = 0;
  @override
  Future<void> showWindow() async {
    shown++;
  }
}
