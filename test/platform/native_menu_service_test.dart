import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('busymax_test/native_menus');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends the anchor and semantic entries to the native host', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return 1;
        });
    const service = NativeMenuService(channel: channel);
    final session = NativeMenuSession();

    final result = await service.show(
      session: session,
      anchor: const Rect.fromLTWH(24, 36, 140, 34),
      entries: const [
        NativeMenuEntry(label: 'Personal'),
        NativeMenuEntry(label: 'Work'),
        NativeMenuEntry(label: 'Archived', enabled: false),
      ],
    );

    expect(result.available, isTrue);
    expect(result.selectedIndex, 1);
    expect(receivedCall?.method, 'show');
    expect(receivedCall?.arguments, {
      'sessionId': session.id,
      'anchor': {'x': 24.0, 'y': 36.0, 'width': 140.0, 'height': 34.0},
      'entries': [
        {'label': 'Personal', 'enabled': true, 'selected': false},
        {'label': 'Work', 'enabled': true, 'selected': false},
        {'label': 'Archived', 'enabled': false, 'selected': false},
      ],
      'focusFirst': false,
    });
  });

  test('can request keyboard focus for the first native menu entry', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return null;
        });
    const service = NativeMenuService(channel: channel);

    await service.show(
      session: NativeMenuSession(),
      anchor: const Rect.fromLTWH(0, 0, 100, 34),
      entries: const [NativeMenuEntry(label: 'Event')],
      focusFirst: true,
    );

    expect(receivedCall?.arguments, containsPair('focusFirst', true));
  });

  test('distinguishes menu dismissal from an unavailable host', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    const service = NativeMenuService(channel: channel);

    final result = await service.show(
      session: NativeMenuSession(),
      anchor: const Rect.fromLTWH(0, 0, 100, 34),
      entries: const [NativeMenuEntry(label: 'Event')],
    );

    expect(result.available, isTrue);
    expect(result.selectedIndex, isNull);
  });

  test('reports unavailable when the native channel is missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw MissingPluginException(),
        );
    const service = NativeMenuService(channel: channel);

    final result = await service.show(
      session: NativeMenuSession(),
      anchor: const Rect.fromLTWH(0, 0, 100, 34),
      entries: const [NativeMenuEntry(label: 'Event')],
    );

    expect(result.available, isFalse);
    expect(result.selectedIndex, isNull);
  });

  test('reports unavailable when the native host is unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'unavailable'),
        );
    const service = NativeMenuService(channel: channel);

    final result = await service.show(
      session: NativeMenuSession(),
      anchor: const Rect.fromLTWH(0, 0, 100, 34),
      entries: const [NativeMenuEntry(label: 'Event')],
    );

    expect(result.available, isFalse);
    expect(result.selectedIndex, isNull);
  });

  test('surfaces native menu protocol failures', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'invalid-arguments'),
        );
    const service = NativeMenuService(channel: channel);

    expect(
      () => service.show(
        session: NativeMenuSession(),
        anchor: const Rect.fromLTWH(0, 0, 100, 34),
        entries: const [NativeMenuEntry(label: 'Event')],
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid-arguments',
        ),
      ),
    );
  });

  test('asks the native host to dismiss only its own menu', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return true;
        });
    const service = NativeMenuService(channel: channel);
    final session = NativeMenuSession();

    expect(await service.dismiss(session), isTrue);
    expect(receivedCall?.method, 'dismiss');
    expect(receivedCall?.arguments, {'sessionId': session.id});
  });

  test('dismiss is safe when native menus are unavailable', () async {
    const service = NativeMenuService(channel: channel);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException(),
    );
    expect(await service.dismiss(NativeMenuSession()), isFalse);

    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    expect(await service.dismiss(NativeMenuSession()), isFalse);

    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await service.dismiss(NativeMenuSession()), isFalse);
  });
}
