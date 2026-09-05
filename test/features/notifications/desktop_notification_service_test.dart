import 'dart:async';
import 'dart:io';

import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/features/notifications/desktop_notification_service.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('unknown sync failure uses a controlled generic message', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults(),
      locale: const Locale('en'),
    );

    await service.notifySyncFailure(
      StateError('database_path=/private exception details'),
    );

    expect(backend.notifications, hasLength(1));
    expect(
      backend.notifications.single.body,
      'Background sync failed. This account is temporarily unavailable.',
    );
    expect(backend.notifications.single.body, isNot(contains('database_path')));
  });

  test('sync failure notification never includes raw exception text', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(
        notificationDetailLevel: NotificationDetailLevel.normal,
      ),
      locale: const Locale('en'),
    );

    await service.notifySyncFailure(
      'access_token=abc refresh_token=def code_verifier=secret',
    );

    final body = backend.notifications.single.body;
    expect(body, isNot(contains('abc')));
    expect(body, isNot(contains('def')));
    expect(body, isNot(contains('secret')));
    expect(body, contains('This account is temporarily unavailable.'));
  });

  test('offline transport failures do not create notifications', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults(),
    );

    await service.notifySyncFailure(
      http.ClientException(
        'Connection failed',
        Uri.parse('https://example.invalid'),
      ),
    );
    await service.notifySyncFailure(
      const SocketException('Network is unreachable'),
    );
    await service.notifySyncFailure(TimeoutException('Request timed out'));

    expect(backend.notifications, isEmpty);
  });

  test('account authentication failures request reconnection', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults(),
      locale: const Locale('en'),
    );

    await service.notifySyncFailure(
      const OAuthException(
        'OAuthMissingToken',
        'No OAuth token is available for this account.',
      ),
    );

    expect(
      backend.notifications.single.body,
      'Background sync failed. '
      'Reconnect this account to resume synchronization.',
    );
  });

  test('permission failures use a controlled permission message', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults(),
      locale: const Locale('en'),
    );

    await service.notifySyncFailure(
      const TaskRemoteError(
        statusCode: 403,
        message: 'provider payload with private details',
      ),
    );

    expect(
      backend.notifications.single.body,
      'Background sync failed. '
      'Server permissions changed. Pending edits are paused.',
    );
    expect(
      backend.notifications.single.body,
      isNot(contains('provider payload')),
    );
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

  test('notification strings use the Estonian ARB catalog', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(notifyDueToday: true),
      locale: const Locale('et'),
    );

    await service.notifyDueToday(2);

    expect(backend.notifications.single.summary, 'Täna tähtuvad ülesanded');
    expect(backend.notifications.single.body, '2 ülesannet tähtub täna.');
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
      locale: const Locale('pt', 'PT'),
    );

    await service.notifyDueToday(2);

    expect(backend.notifications.single.summary, 'Tarefas com prazo para hoje');
    expect(
      backend.notifications.single.body,
      'Há 2 tarefas com prazo para hoje.',
    );
  });

  test('notification strings use the Italian ARB catalog', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(notifyDueToday: true),
      locale: const Locale('it'),
    );

    await service.notifyDueToday(2);

    expect(backend.notifications.single.summary, 'Attività in scadenza oggi');
    expect(backend.notifications.single.body, '2 attività scadono oggi.');
  });

  test('notification strings use the Vietnamese ARB catalog', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(notifyDueToday: true),
      locale: const Locale('vi'),
    );

    await service.notifyDueToday(2);

    expect(backend.notifications.single.summary, 'Công việc đến hạn hôm nay');
    expect(
      backend.notifications.single.body,
      'Có 2 công việc đến hạn hôm nay.',
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

  test('notification strings use Arabic plural rules', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(notifyDueToday: true),
      locale: const Locale('ar'),
    );

    for (final count in [1, 2, 3, 11]) {
      await service.notifyDueToday(count);
    }

    expect(backend.notifications.map((notification) => notification.body), [
      'هناك مهمة واحدة مستحقة اليوم.',
      'هناك مهمتان مستحقتان اليوم.',
      'هناك \u20683\u2069 مهام مستحقة اليوم.',
      'هناك \u206811\u2069 مهمة مستحقة اليوم.',
    ]);
  });

  test('notification strings use Persian plural rules', () async {
    final backend = _FakeNotificationBackend();
    final service = DesktopNotificationService(
      backend: backend,
      settings: AppSettings.defaults().copyWith(notifyDueToday: true),
      locale: const Locale('fa'),
    );

    for (final count in [1, 2]) {
      await service.notifyDueToday(count);
    }

    expect(
      backend.notifications.map((notification) => notification.summary),
      everyElement('کارهای دارای سررسید امروز'),
    );
    expect(backend.notifications.map((notification) => notification.body), [
      'امروز یک کار سررسید دارد.',
      'امروز \u2068۲\u2069 کار سررسید دارند.',
    ]);
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

    expect(backend.notifications.single.transient, isFalse);
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
    await backend.notifications.single.onAction?.call(
      'default',
      backend.notifications.single.payload,
    );

    expect(backend.notifications.single.actions.single.id, 'default');
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

      await service.notifySyncFailure(
        const OAuthException('OAuthMissingToken', 'Private server response'),
      );

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

    const actionableFailure = OAuthException(
      'OAuthMissingToken',
      'No token is available.',
    );
    await quietService.notifySyncFailure(actionableFailure);
    await awakeService.notifySyncFailure(actionableFailure);

    expect(quietBackend.notifications, isEmpty);
    expect(awakeBackend.notifications, hasLength(1));
  });
}

class _FakeNotificationBackend implements DesktopNotificationBackend {
  final notifications = <_NotificationRecord>[];

  @override
  Future<void> notify(
    BusyMaxNotificationRequest request, {
    DesktopNotificationActionHandler? onAction,
  }) async {
    notifications.add(_NotificationRecord(request, onAction));
  }

  @override
  Future<void> cancel(String stableId) async {}

  @override
  Future<void> close() async {}
}

class _NotificationRecord {
  const _NotificationRecord(this.request, this.onAction);

  final BusyMaxNotificationRequest request;
  final DesktopNotificationActionHandler? onAction;

  String get summary => request.title;
  String get body => request.body;
  bool get transient => request.transient;
  Map<String, String>? get payload => request.payload;
  List<BusyMaxNotificationAction> get actions => request.actions;
}
