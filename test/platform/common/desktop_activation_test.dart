import 'dart:convert';

import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopActivation', () {
    test('round-trips every supported activation shape', () {
      const values = [
        DesktopActivation(kind: DesktopActivationKind.normalLaunch),
        DesktopActivation(kind: DesktopActivationKind.startMinimized),
        DesktopActivation(
          kind: DesktopActivationKind.icsFile,
          value: r'C:\Users\Renée\Calendar\予定.ics',
        ),
        DesktopActivation(
          kind: DesktopActivationKind.webCal,
          value: 'webcal://calendar.example.test/public.ics?token=opaque',
        ),
        DesktopActivation(
          kind: DesktopActivationKind.notification,
          action: 'snooze',
          payload: {
            'notificationScheduleId': 'schedule-42',
            'itemKind': 'event',
            'accountId': 'account-7',
            'itemId': 'event-9',
          },
        ),
      ];

      for (final value in values) {
        final decoded = DesktopActivation.tryDecode(value.encode());
        expect(decoded, isNotNull);
        expect(decoded!.toJson(), value.toJson());
      }
    });

    test('rejects malformed, unknown, and oversized input', () {
      expect(DesktopActivation.tryDecode('{'), isNull);
      expect(
        DesktopActivation.tryDecode(
          jsonEncode({'version': 1, 'kind': 'shellCommand', 'value': 'calc'}),
        ),
        isNull,
      );
      expect(
        DesktopActivation.tryDecode(
          jsonEncode({
            'version': 1,
            'kind': 'normalLaunch',
            'unexpected': 'ignored fields must not relax the model',
          }),
        ),
        isNull,
      );
      expect(
        DesktopActivation.tryDecode(
          jsonEncode({
            'version': 1,
            'kind': 'icsFile',
            'value': r'C:\Temp\notes.txt',
          }),
        ),
        isNull,
      );
      expect(
        DesktopActivation.tryDecode(
          jsonEncode({
            'version': 1,
            'kind': 'webCal',
            'value': 'https://calendar.example.test/feed.ics',
          }),
        ),
        isNull,
      );
      expect(
        DesktopActivation.tryDecode(
          'x' * (DesktopActivation.maximumEncodedBytes + 1),
        ),
        isNull,
      );
    });

    test('requires safe notification action and stable schedule identity', () {
      for (final action in const ['default', 'open', 'snooze', 'dismiss']) {
        expect(
          DesktopActivation(
            kind: DesktopActivationKind.notification,
            action: action,
            payload: const {'notificationScheduleId': 'schedule-42'},
          ).isValid,
          isTrue,
        );
      }
      expect(
        const DesktopActivation(
          kind: DesktopActivationKind.notification,
          action: 'run',
          payload: {'notificationScheduleId': 'schedule-42'},
        ).isValid,
        isFalse,
      );
      expect(
        const DesktopActivation(
          kind: DesktopActivationKind.notification,
          action: 'open',
          payload: {'itemId': 'event-9'},
        ).isValid,
        isFalse,
      );
      expect(
        const DesktopActivation(
          kind: DesktopActivationKind.notification,
          action: 'open',
          payload: {
            'notificationScheduleId': 'schedule-42',
            'command': 'arbitrary commands are not activation data',
          },
        ).isValid,
        isFalse,
      );
    });

    test('only notification body and Open require a visible window', () {
      DesktopActivation notification(String action) => DesktopActivation(
        kind: DesktopActivationKind.notification,
        action: action,
        payload: const {'notificationScheduleId': 'schedule-42'},
      );

      expect(notification('default').requiresVisibleWindow, isTrue);
      expect(notification('open').requiresVisibleWindow, isTrue);
      expect(notification('snooze').requiresVisibleWindow, isFalse);
      expect(notification('dismiss').requiresVisibleWindow, isFalse);
    });
  });
}
