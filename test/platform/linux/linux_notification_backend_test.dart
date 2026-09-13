import 'dart:async';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:busymax/src/platform/linux/linux_notification_backend.dart';
import 'package:desktop_notifications/desktop_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';

void main() {
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
