import 'package:busymax/src/platform/windows/windows_time_zone_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

void main() {
  setUpAll(time_zone_data.initializeTimeZones);

  test('accepts IANA and normalizes UTC', () async {
    final iana = WindowsLocalTimeZoneSource(
      load: () async => TimezoneInfo(identifier: 'Asia/Kathmandu'),
    );
    final utc = WindowsLocalTimeZoneSource(
      load: () async => TimezoneInfo(identifier: 'UTC'),
    );

    expect(await iana.currentIanaTimeZone(), 'Asia/Kathmandu');
    expect(await utc.currentIanaTimeZone(), 'Etc/UTC');
  });

  test('maps Windows identifiers and reports unknown values', () async {
    final mapped = WindowsLocalTimeZoneSource(
      load: () async => TimezoneInfo(identifier: 'India Standard Time'),
    );
    final unknown = WindowsLocalTimeZoneSource(
      load: () async => TimezoneInfo(identifier: 'Etc/Unknown'),
    );

    expect(await mapped.currentIanaTimeZone(), 'Asia/Kolkata');
    expect(await unknown.currentIanaTimeZone(), 'Etc/UTC');
    expect(unknown.lastUnrecognizedIdentifier, 'Etc/Unknown');
    expect(
      unknown.diagnostic,
      'local-time-zone/unrecognized=Etc/Unknown; fallback=Etc/UTC',
    );
  });

  test('exposes only allowlisted native failure diagnostics', () async {
    final mappedFailure = WindowsLocalTimeZoneSource(
      load: () async => throw PlatformException(
        code: 'icu-timezone-mapping-failed',
        message: 'sensitive native detail',
      ),
    );
    final unknownFailure = WindowsLocalTimeZoneSource(
      load: () async => throw PlatformException(
        code: 'native-secret-C:/Users/albert',
        message: 'sensitive native detail',
      ),
    );

    expect(await mappedFailure.currentIanaTimeZone(), 'Etc/UTC');
    expect(
      mappedFailure.diagnostic,
      'local-time-zone/icu-timezone-mapping-failed; fallback=Etc/UTC',
    );
    expect(await unknownFailure.currentIanaTimeZone(), 'Etc/UTC');
    expect(
      unknownFailure.diagnostic,
      'local-time-zone/unavailable; fallback=Etc/UTC',
    );
  });

  test('mapped zones retain DST, skipped, ambiguous, and offset behavior', () {
    final pacific = time_zone.getLocation(
      windowsToIanaTimeZones['Pacific Standard Time']!,
    );
    final newfoundland = time_zone.getLocation(
      windowsToIanaTimeZones['Newfoundland Standard Time']!,
    );
    final kathmandu = time_zone.getLocation(
      windowsToIanaTimeZones['Nepal Standard Time']!,
    );

    final winter = time_zone.TZDateTime(pacific, 2026, 1, 15, 12);
    final summer = time_zone.TZDateTime(pacific, 2026, 7, 15, 12);
    expect(winter.timeZoneOffset, const Duration(hours: -8));
    expect(summer.timeZoneOffset, const Duration(hours: -7));

    final skipped = time_zone.TZDateTime(pacific, 2026, 3, 8, 2, 30);
    expect(skipped.hour, 3);
    final ambiguous = time_zone.TZDateTime(pacific, 2026, 11, 1, 1, 30);
    expect(ambiguous.hour, 1);

    expect(
      time_zone.TZDateTime(newfoundland, 2026, 1, 15).timeZoneOffset,
      const Duration(hours: -3, minutes: -30),
    );
    expect(
      time_zone.TZDateTime(kathmandu, 2026, 1, 15).timeZoneOffset,
      const Duration(hours: 5, minutes: 45),
    );
  });
}
