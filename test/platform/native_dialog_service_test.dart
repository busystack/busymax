import 'package:busymax/src/platform/native_dialog_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('busymax_test/native_dialogs');
  const groupedListStyle = NativeGroupedListStyle(
    surfaceColor: Color(0xFF444444),
    dividerColor: Color(0x5C000000),
    sectionHeaderColor: Color(0xFFCCCCCC),
    primaryTextColor: Color(0xFFEFEFEF),
    secondaryTextColor: Color(0xFFBBBBBB),
    hoverColor: Color(0x1FFFFFFF),
    shadowColor: Color(0xFF000000),
    outlineColor: Color(0x1FFFFFFF),
    highContrast: false,
    radius: 8,
    sectionTopSpacing: 16,
    sectionHorizontalPadding: 4,
    titleBottomSpacing: 8,
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
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
      groupedListStyle: groupedListStyle,
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
      'groupedListStyle': {
        'surfaceColor': '#444444',
        'dividerColor': 'rgba(0,0,0,0.36)',
        'sectionHeaderColor': '#CCCCCC',
        'primaryTextColor': '#EFEFEF',
        'secondaryTextColor': '#BBBBBB',
        'hoverColor': 'rgba(255,255,255,0.12)',
        'shadowColor': '#000000',
        'outlineColor': 'rgba(255,255,255,0.12)',
        'highContrast': false,
        'radius': 8,
        'sectionTopSpacing': 16,
        'sectionHorizontalPadding': 4,
        'titleBottomSpacing': 8,
      },
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
        groupedListStyle: groupedListStyle,
      );

      expect(result.available, isTrue);
      expect(result.selectedTimeZone, isNull);
    },
  );
}
