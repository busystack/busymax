import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('busymax.android.test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'googleAuthorizationAvailable' => false,
        'microsoftAuthorizationAvailable' => true,
        'authorizeMicrosoftSilent' => <String, Object?>{
          'accessToken': 'short-lived-access-token',
          'scopes': <String>['Tasks.ReadWrite'],
          'nativeAccountId': 'native-account-2',
          'username': 'second@example.test',
          'authority': 'organizations',
          'expiresAtEpochMillis': 1893456000000,
        },
        'readDocumentUri' => <String, Object?>{
          'uri': 'content://documents/event.ics',
          'name': 'event.ics',
          'mimeType': 'text/calendar',
          'bytes': Uint8List.fromList(<int>[66, 69, 71, 73, 78]),
        },
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('reports provider availability independently', () async {
    final platform = BusyMaxAndroidPlatform(methodChannel: channel);

    expect(await platform.googleAuthorizationAvailable(), isFalse);
    expect(await platform.microsoftAuthorizationAvailable(), isTrue);
  });

  test(
    'silent Microsoft authorization remains bound to the requested account',
    () async {
      final platform = BusyMaxAndroidPlatform(methodChannel: channel);

      final token = await platform.authorizeMicrosoftSilently(
        accountId: 'domain-account-2',
        scopes: const <String>['Tasks.ReadWrite'],
      );

      expect(token.nativeAccountId, 'native-account-2');
      expect(token.username, 'second@example.test');
      expect(
        calls.single.arguments,
        containsPair('accountId', 'domain-account-2'),
      );
    },
  );

  test(
    'incoming documents remain bounded content URIs, not file paths',
    () async {
      final platform = BusyMaxAndroidPlatform(methodChannel: channel);

      final document = await platform.readDocumentUri(
        Uri.parse('content://documents/event.ics'),
        maximumBytes: 1024,
      );

      expect(document.uri.scheme, 'content');
      expect(document.name, 'event.ics');
      expect(calls.single.arguments, containsPair('maximumBytes', 1024));
    },
  );
}
