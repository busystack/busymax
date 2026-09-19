import 'package:busymax/src/platform/windows/windows_clock_preference.dart';
import 'package:busymax/src/l10n/week_preferences_scope.dart';
import 'package:busymax/src/platform/windows/windows_first_weekday_source.dart';
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

  test(
    'Windows weekday uses a separate channel and refresh lifecycle',
    () async {
      const channel = MethodChannel('busymax/windows_weekday');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var system = DateTime.wednesday;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getFirstWeekday');
        return system;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final controller = BusyMaxSystemFirstWeekdayController(
        WindowsFirstWeekdaySource(),
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(controller.value, DateTime.wednesday);

      system = DateTime.sunday;
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('weekdayChanged', DateTime.sunday),
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.value, DateTime.sunday);

      system = DateTime.friday;
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(controller.value, DateTime.friday);
    },
  );

  test(
    'disposing Windows weekday source removes its channel handler',
    () async {
      const channel = MethodChannel('busymax_test/windows_weekday_dispose');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final source = WindowsFirstWeekdaySource(channel: channel);
      var changes = 0;
      final subscription = source.changes.listen((_) => changes++);

      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('weekdayChanged', DateTime.monday),
        ),
        (_) {},
      );
      expect(changes, 1);

      source.dispose();
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('weekdayChanged', DateTime.sunday),
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(changes, 1);
      await subscription.cancel();
    },
  );
}
