import 'package:busymax/src/core/time/linux_gweather_location_source.dart';
import 'package:busymax/src/core/time/time_zone_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    BusyMaxTimeZoneCatalog.setSystemLocationsForTesting(const [
      BusyMaxSystemTimeZoneLocation(
        name: 'Seattle',
        englishName: 'Seattle',
        countryCode: 'US',
        timeZoneId: 'America/Los_Angeles',
      ),
      BusyMaxSystemTimeZoneLocation(
        name: 'Miami',
        englishName: 'Miami',
        countryCode: 'US',
        timeZoneId: 'America/New_York',
      ),
      BusyMaxSystemTimeZoneLocation(
        name: 'Osaka',
        englishName: 'Osaka',
        countryCode: 'JP',
        timeZoneId: 'Asia/Tokyo',
      ),
      BusyMaxSystemTimeZoneLocation(
        name: 'Montréal',
        englishName: 'Montreal',
        countryCode: 'CA',
        timeZoneId: 'America/Toronto',
      ),
      BusyMaxSystemTimeZoneLocation(
        name: 'Vancouver',
        englishName: 'Vancouver',
        countryCode: 'CA',
        timeZoneId: 'America/Vancouver',
      ),
      BusyMaxSystemTimeZoneLocation(
        name: 'Burnaby',
        englishName: 'Burnaby',
        countryCode: 'CA',
        timeZoneId: 'America/Vancouver',
      ),
      BusyMaxSystemTimeZoneLocation(
        name: 'Victoria',
        englishName: 'Victoria',
        countryCode: 'CA',
        timeZoneId: 'America/Vancouver',
      ),
      BusyMaxSystemTimeZoneLocation(
        name: 'Victoria Falls',
        englishName: 'Victoria Falls',
        countryCode: 'ZW',
        timeZoneId: 'Africa/Harare',
      ),
    ]);
  });

  tearDown(() {
    BusyMaxTimeZoneCatalog.setSystemLocationsForTesting(null);
  });

  test('timezone catalog searches IANA locations with current codes', () {
    final results = BusyMaxTimeZoneCatalog.search('Vancouver');
    final vancouver = results.singleWhere(
      (location) => location.id == 'America/Vancouver',
    );

    expect(vancouver.region, 'America');
    expect(vancouver.name, 'Vancouver');
    expect(vancouver.code, isNotEmpty);
    expect(vancouver.displayLabel, 'America/Vancouver (${vancouver.code})');
  });

  test('timezone catalog includes the complete IANA location set', () {
    final america = BusyMaxTimeZoneCatalog.search('America');
    final montreal = america.singleWhere(
      (location) => location.id == 'America/Montreal',
    );
    final easternAliases = BusyMaxTimeZoneCatalog.search('Eastern');

    expect(america.length, greaterThan(80));
    expect(montreal.region, 'America');
    expect(montreal.name, 'Montreal');
    expect(montreal.code, isNotEmpty);
    expect(
      easternAliases.map((location) => location.id),
      containsAll(<String>['Canada/Eastern', 'US/Eastern']),
    );
  });

  test('location search resolves ordinary cities to IANA timezones', () async {
    final seattle = await BusyMaxTimeZoneCatalog.searchLocations('Seattle');
    final miami = await BusyMaxTimeZoneCatalog.searchLocations('Miami');
    final osaka = await BusyMaxTimeZoneCatalog.searchLocations('Osaka');

    expect(
      seattle
          .where((result) => result.name == 'Seattle')
          .map((result) => result.location.id),
      contains('America/Los_Angeles'),
    );
    expect(
      miami
          .where((result) => result.name == 'Miami')
          .map((result) => result.location.id),
      contains('America/New_York'),
    );
    expect(
      osaka
          .where((result) => result.name == 'Osaka')
          .map((result) => result.location.id),
      contains('Asia/Tokyo'),
    );
  });

  test(
    'location search matches English forms of localized system names',
    () async {
      final results = await BusyMaxTimeZoneCatalog.searchLocations('Montreal');
      final montreal = results.firstWhere(
        (result) =>
            result.name == 'Montréal' &&
            result.location.id == 'America/Toronto',
      );

      expect(montreal.countryCode, 'CA');
      expect(montreal.subtitle, 'America/Toronto - CA');
    },
  );

  test('city search does not match every city in the same timezone', () {
    final results = BusyMaxTimeZoneCatalog.searchPreparedLocations('Vancouver');
    final burnaby = BusyMaxTimeZoneCatalog.preparedLocationOptions.firstWhere(
      (result) => result.name == 'Burnaby',
    );

    expect(results, hasLength(1));
    expect(results.single.name, 'Vancouver');
    expect(results.single.location.id, 'America/Vancouver');
    expect(burnaby.searchText.toLowerCase(), isNot(contains('vancouver')));
  });

  test('exact city matches rank before prefixes in other regions', () {
    final results = BusyMaxTimeZoneCatalog.searchPreparedLocations('Victoria');
    final exactIndex = results.indexWhere(
      (result) => result.name == 'Victoria',
    );
    final prefixIndex = results.indexWhere(
      (result) => result.name == 'Victoria Falls',
    );

    expect(exactIndex, 0);
    expect(prefixIndex, greaterThan(exactIndex));
  });

  test('timezone catalog preserves unknown existing identifiers', () {
    final location = BusyMaxTimeZoneCatalog.location('Custom/Office_Time');

    expect(location.id, 'Custom/Office_Time');
    expect(location.region, 'Custom');
    expect(location.name, 'Office Time');
    expect(location.code, 'Custom/Office_Time');
  });
}
