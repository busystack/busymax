import 'package:busymax/src/platform/windows/windows_clock_preference.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Windows clock initializes, deduplicates and refreshes on resume',
    () async {
      const channel = MethodChannel('busymax/windows_clock');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var system = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getUses24HourClock');
        return system;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final source = WindowsClockPreference();
      addTearDown(source.dispose);
      final changes = <bool?>[];
      source.addListener(() => changes.add(source.value));
      await source.refresh();
      expect(source.value, false);
      await source.refresh();
      expect(changes, [false]);
      system = true;
      source.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(source.value, true);
      expect(changes, [false, true]);
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('clockChanged', false),
        ),
        (_) {},
      );
      expect(changes, [false, true, false]);
    },
  );
}
