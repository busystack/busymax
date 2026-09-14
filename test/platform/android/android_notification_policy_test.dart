import 'dart:convert';

import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/app/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
  });

  test('notification IDs are stable and avoid IDs already in use', () {
    final first = allocateAndroidNotificationId('schedule-a', <int>{});

    expect(allocateAndroidNotificationId('schedule-a', <int>{}), first);
    expect(
      allocateAndroidNotificationId('schedule-a', <int>{first}),
      isNot(first),
    );
    expect(first, greaterThan(0));
  });

  test('overnight quiet hours move a reminder to the next quiet-hours end', () {
    final settings = AppSettings.defaults().copyWith(
      quietHoursEnabled: true,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:00',
    );
    final requested = DateTime.utc(2026, 1, 1, 23).millisecondsSinceEpoch;

    final scheduled = applyAndroidQuietHours(requested, settings);

    expect(
      DateTime.fromMillisecondsSinceEpoch(scheduled, isUtc: true),
      DateTime.utc(2026, 1, 2, 7),
    );
  });

  test('activation payload parsing rejects incomplete data', () {
    expect(parseAndroidReminderActivation('{"schedule":"only"}'), isNull);
    final activation = parseAndroidReminderActivation(
      jsonEncode(<String, Object>{
        'v': 1,
        'schedule': 'schedule-1',
        'generation': 'generation-4',
        'type': 'task',
        'account': 'account-2',
        'source': 'task-7',
      }),
    );
    expect(activation?.itemId, 'task-7');
    expect(activation?.generation, 'generation-4');
  });
}
