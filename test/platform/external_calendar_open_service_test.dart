import 'dart:async';

import 'package:busymax/src/platform/external_calendar_open_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signals readiness and preserves accepted open arrival order', () async {
    const channel = MethodChannel(externalCalendarOpenChannelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final outbound = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      outbound.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final service = ExternalCalendarOpenService(channel: channel);
    addTearDown(service.dispose);

    await service.initialize();
    expect(outbound.single.method, 'ready');
    final received = service.requests.take(3).toList();
    await _deliver(
      messenger,
      const MethodCall('openItem', {
        'kind': 'webcal',
        'value': 'webcal://calendar.example.test/feed',
      }),
    );
    await _deliver(
      messenger,
      const MethodCall('openItem', {'kind': 'ics', 'value': '/tmp/first.ics'}),
    );
    await _deliver(
      messenger,
      const MethodCall('openItem', {'kind': 'ics', 'value': '/tmp/second.ics'}),
    );

    final requests = await received;
    expect(requests.map((request) => request.kind), [
      ExternalCalendarOpenKind.webCal,
      ExternalCalendarOpenKind.icsFile,
      ExternalCalendarOpenKind.icsFile,
    ]);
    expect(requests.map((request) => request.value), [
      'webcal://calendar.example.test/feed',
      '/tmp/first.ics',
      '/tmp/second.ics',
    ]);
  });

  test('ignores unrelated methods, kinds, and empty values', () async {
    const channel = MethodChannel(externalCalendarOpenChannelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final service = ExternalCalendarOpenService(channel: channel);
    addTearDown(service.dispose);
    await service.initialize();
    final received = <ExternalCalendarOpenRequest>[];
    final subscription = service.requests.listen(received.add);
    addTearDown(subscription.cancel);

    await _deliver(messenger, const MethodCall('unrelated'));
    await _deliver(
      messenger,
      const MethodCall('openItem', {'kind': 'https', 'value': 'https://x'}),
    );
    await _deliver(
      messenger,
      const MethodCall('openItem', {'kind': 'ics', 'value': ''}),
    );
    await Future<void>.delayed(Duration.zero);

    expect(received, isEmpty);
  });
}

Future<void> _deliver(TestDefaultBinaryMessenger messenger, MethodCall call) {
  final done = Completer<void>();
  messenger.handlePlatformMessage(
    externalCalendarOpenChannelName,
    const StandardMethodCodec().encodeMethodCall(call),
    (_) => done.complete(),
  );
  return done.future;
}
