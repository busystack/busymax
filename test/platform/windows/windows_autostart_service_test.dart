import 'package:busymax/src/platform/common/desktop_services.dart';
import 'package:busymax/src/platform/windows/windows_autostart_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('busymax/autostart-test');
  const service = WindowsAutostartService(channel: channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final state in DesktopAutostartState.values) {
    test('maps and enforces Windows startup state ${state.name}', () async {
      var writes = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getStartupTaskState') return state.name;
        writes++;
        return null;
      });
      expect(await service.state(), state);
      if (state.canChange) {
        await service.setEnabled(!state.isEnabled);
        expect(writes, 1);
      } else {
        await expectLater(
          service.setEnabled(!state.isEnabled),
          throwsUnsupportedError,
        );
        expect(writes, 0);
      }
    });
  }

  test('state lookup errors remain failures', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'startup_task_failed'),
    );
    await expectLater(service.state(), throwsA(isA<PlatformException>()));
  });

  test('missing plugin remains unavailable', () async {
    expect(await service.state(), DesktopAutostartState.unavailable);
  });
}
