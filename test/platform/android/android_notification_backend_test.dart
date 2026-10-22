import 'package:busymax/src/android/android_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'initialize' ? true : null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('production plugin guard crossing posts the same eligible occurrence immediately', () async {
    final backend = FlutterAndroidNotificationBackend();
    await backend.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
    calls.clear();
    await backend.zonedSchedule(
      id: 42,
      title: 'Meeting',
      body: '09:00 · Office',
      scheduledDate: tz.TZDateTime.from(
        DateTime.now().subtract(const Duration(seconds: 1)),
        tz.UTC,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          androidReminderChannelId,
          'Reminders',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'same bounded action identity',
    );
    expect(calls.map((call) => call.method), ['show']);
    expect((calls.single.arguments as Map)['id'], 42);
    expect(
      (calls.single.arguments as Map)['payload'],
      'same bounded action identity',
    );
  });

  test('adapter preserves future alarms and does not hide unrelated validation errors', () async {
    final backend = FlutterAndroidNotificationBackend();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        androidReminderChannelId,
        'Reminders',
      ),
    );
    final future = tz.TZDateTime.from(
      DateTime.now().add(const Duration(days: 1)),
      tz.UTC,
    );
    await backend.zonedSchedule(
      id: 43,
      scheduledDate: future,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    expect(calls.map((call) => call.method), ['zonedSchedule']);
    calls.clear();
    await expectLater(
      backend.zonedSchedule(
        id: 0x80000000,
        scheduledDate: future,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      ),
      throwsArgumentError,
    );
    expect(calls, isEmpty);
  });
}
