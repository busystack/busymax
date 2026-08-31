import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:busymax/src/platform/windows/windows_activation_service.dart';
import 'package:busymax/src/platform/windows/windows_window_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'notification forwarder sends one validated encoded activation',
    () async {
      const channel = MethodChannel(windowsDesktopChannelName);
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const activation = DesktopActivation(
        kind: DesktopActivationKind.notification,
        action: 'snooze',
        payload: {
          'notificationScheduleId': 'schedule-42',
          'itemKind': 'event',
          'accountId': 'account-7',
          'sourceId': 'calendar-3',
          'itemId': 'event-9',
        },
      );

      expect(await forwardWindowsActivationToPrimary(activation), isTrue);
      expect(received?.method, 'forwardActivation');
      expect(
        DesktopActivation.tryDecode(received?.arguments as String)?.toJson(),
        activation.toJson(),
      );
    },
  );

  test(
    'notification forwarder rejects invalid activation before IPC',
    () async {
      const channel = MethodChannel(windowsDesktopChannelName);
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls += 1;
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const activation = DesktopActivation(
        kind: DesktopActivationKind.notification,
        action: 'open',
        payload: {
          'notificationScheduleId': 'schedule-42',
          'command': 'not permitted',
        },
      );

      expect(await forwardWindowsActivationToPrimary(activation), isFalse);
      expect(calls, 0);
    },
  );
}
