import 'package:busymax/src/l10n/week_preferences_scope.dart';
import 'package:busymax/src/platform/linux_first_weekday_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Linux notification causes a complete native reread', (
    tester,
  ) async {
    const methods = MethodChannel('busymax_test/linux_weekday_methods');
    const events = EventChannel('busymax_test/linux_weekday_events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MockStreamHandlerEventSink? sink;
    var weekday = DateTime.monday;
    var reads = 0;
    var nativeCancels = 0;
    var streamCancels = 0;
    messenger.setMockMethodCallHandler(methods, (call) async {
      switch (call.method) {
        case 'getFirstWeekday':
          reads++;
          return weekday;
        case 'cancelFirstWeekdayReads':
          nativeCancels++;
          return null;
        default:
          fail('Unexpected Linux weekday method: ${call.method}');
      }
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, eventSink) {
          sink = eventSink;
        },
        onCancel: (arguments) {
          streamCancels++;
        },
      ),
    );
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(methods, null)
        ..setMockStreamHandler(events, null);
    });

    final controller = BusyMaxSystemFirstWeekdayController(
      const LinuxFirstWeekdaySource(channel: methods, events: events),
    );
    await tester.pump();
    expect(controller.value, DateTime.monday);
    expect(reads, 1);
    expect(sink, isNotNull);

    weekday = DateTime.sunday;
    sink!.success(null);
    await tester.pump();
    expect(controller.value, DateTime.sunday);
    expect(reads, 2);

    controller.dispose();
    await tester.pump();
    expect(nativeCancels, 1);
    expect(streamCancels, 1);
    sink!.success(null);
    await tester.pump();
    expect(reads, 2);
    expect(tester.takeException(), isNull);
  });

  test('Linux native failures stay on the unavailable-data path', () async {
    const missing = MethodChannel('busymax_test/linux_weekday_missing');
    const failed = MethodChannel('busymax_test/linux_weekday_failed');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(missing, (call) async {
      throw MissingPluginException();
    });
    messenger.setMockMethodCallHandler(failed, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(missing, null)
        ..setMockMethodCallHandler(failed, null);
    });

    expect(
      await const LinuxFirstWeekdaySource(channel: missing).read(),
      isNull,
    );
    expect(await const LinuxFirstWeekdaySource(channel: failed).read(), isNull);
  });
}
