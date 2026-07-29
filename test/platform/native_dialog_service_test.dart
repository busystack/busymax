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

  test('passes timezone content to the native chooser', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return 'America/Vancouver';
        });
    const service = NativeDialogService(channel: channel);

    final result = await service.selectTimeZone(
      title: 'Select Timezone',
      searchPlaceholder: 'Search locations',
      noResultsLabel: 'No locations found',
      selectedTimeZone: 'Etc/UTC',
      options: const [
        NativeTimeZoneOption(
          id: 'America/Vancouver',
          region: 'America',
          name: 'Vancouver',
          englishName: 'Vancouver',
          title: 'Vancouver (PDT)',
          subtitle: 'America/Vancouver - CA',
          searchText: 'Vancouver\nAmerica/Vancouver\nCA',
        ),
      ],
    );

    expect(result.available, isTrue);
    expect(result.selectedTimeZone, 'America/Vancouver');
    expect(receivedCall?.method, 'selectTimeZone');
    expect(receivedCall?.arguments, {
      'title': 'Select Timezone',
      'searchPlaceholder': 'Search locations',
      'noResultsLabel': 'No locations found',
      'selectedTimeZone': 'Etc/UTC',
      'options': [
        {
          'id': 'America/Vancouver',
          'region': 'America',
          'name': 'Vancouver',
          'englishName': 'Vancouver',
          'title': 'Vancouver (PDT)',
          'subtitle': 'America/Vancouver - CA',
          'searchText': 'Vancouver\nAmerica/Vancouver\nCA',
        },
      ],
    });
  });

  test(
    'distinguishes native timezone cancellation from unavailable host',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      const service = NativeDialogService(channel: channel);

      final result = await service.selectTimeZone(
        title: 'Select Timezone',
        searchPlaceholder: 'Search locations',
        noResultsLabel: 'No locations found',
        selectedTimeZone: 'Etc/UTC',
        options: const [
          NativeTimeZoneOption(
            id: 'Etc/UTC',
            region: 'UTC',
            name: 'UTC',
            englishName: 'UTC',
            title: 'UTC (UTC)',
            subtitle: 'Etc/UTC',
            searchText: 'UTC\nEtc/UTC',
          ),
        ],
      );

      expect(result.available, isTrue);
      expect(result.selectedTimeZone, isNull);
    },
  );
}
