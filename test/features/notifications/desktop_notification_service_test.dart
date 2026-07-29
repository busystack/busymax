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
      settings: AppSettings.defaults().copyWith(
        notificationDetailLevel: NotificationDetailLevel.normal,
      ),
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

  test('notification strings use the Finnish ARB catalog', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(notifyDueToday: true),
      locale: const Locale('fi'),
    );

    await service.notifyDueToday(2);

    expect(backend.notifications.single.summary, 'Tänään erääntyvät tehtävät');
    expect(backend.notifications.single.body, '2 tehtävää erääntyy tänään.');
  });

  test('notification strings use Russian plural rules', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(notifyDueToday: true),
      locale: const Locale('ru'),
    );

    await service.notifyDueToday(22);

    expect(backend.notifications.single.summary, 'Задачи на сегодня');
    expect(
      backend.notifications.single.body,
      'Сегодня нужно выполнить 22 задачи.',
    );
  });

  test('notification strings use the Portuguese ARB catalog', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(notifyDueToday: true),
      locale: const Locale('pt'),
    );

    await service.notifyDueToday(2);

    expect(backend.notifications.single.summary, 'Tarefas com prazo para hoje');
    expect(
      backend.notifications.single.body,
      'Há 2 tarefas com prazo para hoje.',
    );
  });

  test('notification strings use the new Asian ARB catalogs', () async {
    final cases = <({Locale locale, String summary, String body})>[
      (
        locale: const Locale('hi'),
        summary: 'आज देय कार्य',
        body: 'आज 2 कार्य देय हैं।',
      ),
      (
        locale: const Locale('ja'),
        summary: '今日が期限のタスク',
        body: '今日が期限のタスクが2件あります。',
      ),
      (
        locale: const Locale('ko'),
        summary: '오늘 마감인 할 일',
        body: '오늘 마감인 할 일이 2개 있습니다.',
      ),
      (
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        summary: '今天到期的任务',
        body: '今天有 2 项任务到期。',
      ),
      (
        locale: const Locale('zh', 'TW'),
        summary: '今天到期的待辦事項',
        body: '今天有 2 項待辦事項到期。',
      ),
    ];

    for (final testCase in cases) {
      final backend = _FakeNotificationBackend();
      final service = DesktopNotificationService(
        backend: backend,
        settings: AppSettings.defaults().copyWith(notifyDueToday: true),
        locale: testCase.locale,
      );

      await service.notifyDueToday(2);

      expect(backend.notifications.single.summary, testCase.summary);
      expect(backend.notifications.single.body, testCase.body);
    }
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
    'private detail level also hides diagnostic notification text',
    () async {
      final backend = _FakeNotificationBackend();
      final service = DesktopNotificationService(
        backend: backend,
        settings: AppSettings.defaults().copyWith(
          notificationDetailLevel: NotificationDetailLevel.private,
        ),
      );

      await service.notifySyncFailure('Private server response');

      expect(backend.notifications.single.body, isNot(contains('Private')));
      expect(
        backend.notifications.single.body,
        contains('Details are hidden by privacy settings.'),
      );
    },
  );

  test('configured overnight quiet hours use an end-exclusive range', () async {
    final settings = AppSettings.defaults().copyWith(
      quietHoursEnabled: true,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:00',
    );
    final quietBackend = _FakeNotificationBackend();
    final quietService = DesktopNotificationService(
      backend: quietBackend,
      settings: settings,
      now: () => DateTime(2026, 1, 1, 23, 30),
    );
    final awakeBackend = _FakeNotificationBackend();
    final awakeService = DesktopNotificationService(
      backend: awakeBackend,
      settings: settings,
      now: () => DateTime(2026, 1, 2, 7),
    );

    await quietService.notifySyncFailure('Offline');
    await awakeService.notifySyncFailure('Offline');

    expect(quietBackend.notifications, isEmpty);
    expect(awakeBackend.notifications, hasLength(1));
  });
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
