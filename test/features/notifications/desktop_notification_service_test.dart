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
}

class _FakeNotificationBackend implements DesktopNotificationBackend {
  final notifications = <_NotificationRecord>[];

  @override
  Future<void> notify(
    String summary, {
    String body = '',
    List<NotificationHint> hints = const [],
  }) async {
    notifications.add(_NotificationRecord(summary, body));
  }

  @override
  Future<void> close() async {}
}

class _NotificationRecord {
  const _NotificationRecord(this.summary, this.body);

  final String summary;
  final String body;
}
