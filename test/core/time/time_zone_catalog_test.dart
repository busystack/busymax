import 'package:busymax/src/core/time/time_zone_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('timezone catalog preserves unknown existing identifiers', () {
    final location = BusyMaxTimeZoneCatalog.location('Custom/Office_Time');

    expect(location.id, 'Custom/Office_Time');
    expect(location.region, 'Custom');
    expect(location.name, 'Office Time');
    expect(location.code, 'Custom/Office_Time');
  });
}
