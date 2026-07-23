import 'package:busymax/src/platform/native_dialog_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('busymax_test/native_dialogs');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('passes semantic confirmation data to the native host', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return true;
        });
    const service = NativeDialogService(channel: channel);

    final result = await service.confirm(
      title: 'Discard changes?',
      message: 'Unsaved changes will be lost.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Discard',
      destructive: true,
    );

    expect(result.available, isTrue);
    expect(result.confirmed, isTrue);
    expect(receivedCall?.method, 'confirm');
    expect(receivedCall?.arguments, {
      'title': 'Discard changes?',
      'message': 'Unsaved changes will be lost.',
      'cancelLabel': 'Cancel',
      'confirmLabel': 'Discard',
      'destructive': true,
    });
  });

  test('distinguishes native cancellation from an unavailable host', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);
    const service = NativeDialogService(channel: channel);

    final result = await service.confirm(
      title: 'Continue?',
      message: 'Confirm this action.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Continue',
      destructive: false,
    );

    expect(result.available, isTrue);
    expect(result.confirmed, isFalse);
  });

  test('reports unavailable when the native channel is missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw MissingPluginException(),
        );
    const service = NativeDialogService(channel: channel);

    final result = await service.confirm(
      title: 'Continue?',
      message: 'Confirm this action.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Continue',
      destructive: false,
    );

    expect(result.available, isFalse);
    expect(result.confirmed, isFalse);
  });
}
