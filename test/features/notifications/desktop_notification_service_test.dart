import 'package:desktop_notifications/desktop_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';

void main() {
  test('notification service does not throw with fake backend', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults(),
    );

    await service.notifySyncFailure('network error');

    expect(backend.notifications, hasLength(1));
  });

  test('sync failure notification redacts OAuth secrets', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(detailedNotifications: true),
    );

    await service.notifySyncFailure(
      'access_token=abc refresh_token=def code_verifier=secret',
    );

    final body = backend.notifications.single.body;
    expect(body, isNot(contains('abc')));
    expect(body, isNot(contains('def')));
    expect(body, isNot(contains('secret')));
    expect(body, contains('[REDACTED]'));
  });

  test('conflict notification respects disabled setting', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(notifyConflicts: false),
    );

    await service.notifyConflict('Remote task changed');

    expect(backend.notifications, isEmpty);
  });

  test('notification strings localize supported locales', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(notifyDueToday: true),
      locale: const Locale('es'),
    );

    await service.notifyDueToday(2);

    expect(backend.notifications.single.summary, 'Tareas que vencen hoy');
  });

  test('reminder notification details are visible by default', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults(),
    );

    await service.notifyTaskReminder('Pay rent', 'Due at 9:00 AM');

    expect(backend.notifications.single.summary, 'Pay rent');
    expect(backend.notifications.single.body, 'Due at 9:00 AM');
  });

  test('reminder notifications are not transient', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults(),
    );

    await service.notifyEventReminder('Standup', 'Starts at 9:00 AM');

    expect(
      backend.notifications.single.hints.map((hint) => hint.key),
      isNot(contains('transient')),
    );
  });

  test('reminder notification default action activates callback', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults(),
    );
    var activated = false;

    await service.notifyEventReminder(
      'Standup',
      'Starts at 9:00',
      onActivated: () async => activated = true,
    );
    await backend.notifications.single.onAction?.call('default');

    expect(backend.notifications.single.actions.single.key, 'default');
    expect(activated, isTrue);
  });

  test('private reminder notifications hide item details', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(
        notificationDetailLevel: NotificationDetailLevel.private,
      ),
    );

    await service.notifyEventReminder('Doctor', 'Clinic');

    expect(backend.notifications.single.summary, 'Event reminder');
    expect(
      backend.notifications.single.body,
      'Details are hidden by privacy settings.',
    );
  });

  test(
    'detailed notification switch overrides private reminder text',
    () async {
      final backend = _FakeNotificationBackend();
      final service = DesktopNotificationService(
        backend: backend,
        settings: AppSettings.defaults().copyWith(
          detailedNotifications: true,
          notificationDetailLevel: NotificationDetailLevel.private,
        ),
      );

      await service.notifyEventReminder('Doctor', 'Clinic');

      expect(backend.notifications.single.summary, 'Doctor');
      expect(backend.notifications.single.body, 'Clinic');
    },
  );
}

class _FakeNotificationBackend implements DesktopNotificationBackend {
  final notifications = <_NotificationRecord>[];

  @override
  Future<void> notify(
    String summary, {
    String body = '',
    List<NotificationHint> hints = const [],
    List<NotificationAction> actions = const [],
    DesktopNotificationActionHandler? onAction,
  }) async {
    notifications.add(
      _NotificationRecord(summary, body, hints, actions, onAction),
    );
  }

  @override
  Future<void> close() async {}
}

class _NotificationRecord {
  const _NotificationRecord(
    this.summary,
    this.body,
    this.hints,
    this.actions,
    this.onAction,
  );

  final String summary;
  final String body;
  final List<NotificationHint> hints;
  final List<NotificationAction> actions;
  final DesktopNotificationActionHandler? onAction;
}
