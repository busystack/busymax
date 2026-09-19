import 'package:busymax/src/l10n/week_preferences_scope.dart';
import 'package:busymax/src/platform/android/android_first_weekday_source.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android setting event and resume each perform a fresh read', () async {
    const methods = MethodChannel('busymax_test/android_weekday_methods');
    const events = EventChannel('busymax_test/android_weekday_events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MockStreamHandlerEventSink? sink;
    var weekday = DateTime.monday;
    var reads = 0;
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'getFirstWeekday');
      reads++;
      return weekday;
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, eventSink) {
          sink = eventSink;
        },
      ),
    );
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(methods, null)
        ..setMockStreamHandler(events, null);
    });

    final source = AndroidFirstWeekdaySource(
      platform: BusyMaxAndroidPlatform(methodChannel: methods, events: events),
    );
    final controller = BusyMaxSystemFirstWeekdayController(source);
    await pumpEventQueue();
    expect(controller.value, DateTime.monday);
    expect(reads, 1);

    weekday = DateTime.thursday;
    sink!.success(<String, Object?>{'kind': 'systemSettingsChanged'});
    await pumpEventQueue();
    expect(reads, 2);
    expect(controller.value, DateTime.thursday);

    weekday = DateTime.saturday;
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(controller.value, DateTime.saturday);
    expect(reads, 3);

    controller.dispose();
    sink!.success(<String, Object?>{'kind': 'systemSettingsChanged'});
    await pumpEventQueue();
    expect(reads, 3);
  });
}
