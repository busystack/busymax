import 'dart:io';

import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/process_time_zone.dart';

void main() {
  group('event timezone resolution inside the host DST gap', () {
    late ProcessTimeZone hostZone;
    setUp(() {
      hostZone = ProcessTimeZone();
      hostZone.set('America/Vancouver');
      expect(DateTime(2026, 3, 8, 2, 30).hour, isNot(2));
    });
    tearDown(() => hostZone.restore());

    for (final zone in ['Asia/Tokyo', 'Tokyo Standard Time', 'UTC']) {
      test(
        'offset-less timestamps resolve in $zone before host conversion',
        () {
          final instant = zone == 'UTC'
              ? DateTime.utc(2026, 3, 8, 2, 30)
              : DateTime.utc(2026, 3, 7, 17, 30);
          expect(
            providerDateTimeAsUtcInstant('2026-03-08T02:30:00', zone),
            instant,
          );
          expect(
            providerDateTimeAsLocal('2026-03-08T02:30:00', zone),
            instant.toLocal(),
          );
        },
      );
    }

    test(
      'inline offsets remain authoritative regardless of the separate zone',
      () {
        for (final value in [
          '2026-03-08T02:30:00+09:00',
          '2026-03-08T02:30:00+0900',
          '2026-03-08T02:30:00+09',
          '2026-03-07T17:30:00Z',
        ]) {
          final instant = DateTime.utc(2026, 3, 7, 17, 30);
          expect(
            providerDateTimeAsUtcInstant(value, 'America/Vancouver'),
            instant,
          );
          expect(
            providerDateTimeAsLocal(value, 'America/Vancouver'),
            DateTime(2026, 3, 7, 9, 30),
          );
        }
      },
    );

    test(
      'missing and unknown zones retain host-local fallback and date-only behavior',
      () {
        for (final zone in [null, 'Unknown/Zone']) {
          final local = DateTime(2026, 3, 8, 2, 30);
          expect(providerDateTimeAsLocal('2026-03-08T02:30:00', zone), local);
          expect(
            providerDateTimeAsUtcInstant('2026-03-08T02:30:00', zone),
            local.toUtc(),
          );
        }
        expect(
          providerDateTimeAsLocal('2026-03-08', 'Asia/Tokyo'),
          DateTime(2026, 3, 8),
        );
        expect(
          providerDateTimeAsUtcInstant('2026-03-08', 'Asia/Tokyo'),
          DateTime(2026, 3, 8).toUtc(),
        );
        expect(providerDateTimeAsLocal('invalid', 'Asia/Tokyo'), isNull);
        expect(providerDateTimeAsUtcInstant(null, 'Asia/Tokyo'), isNull);
      },
    );
  }, skip: !(Platform.isLinux || Platform.isMacOS));

  test('UTC provider dateTime without offset is treated as a UTC instant', () {
    expect(
      providerDateTimeAsUtcInstant('2026-06-08T13:15:00', 'UTC'),
      DateTime.utc(2026, 6, 8, 13, 15),
    );
    expect(
      providerDateTimeAsLocal('2026-06-08T13:15:00', 'UTC'),
      DateTime.utc(2026, 6, 8, 13, 15).toLocal(),
    );
  });

  test(
    'IANA provider dateTime resolves for scheduling without changing wall-time display',
    () {
      final expected = DateTime.utc(2026, 6, 8, 13, 2);
      expect(
        providerDateTimeAsUtcInstant(
          '2026-06-08T06:02:00',
          'America/Vancouver',
        ),
        expected,
      );
      expect(
        providerDateTimeAsLocal('2026-06-08T06:02:00', 'America/Vancouver'),
        DateTime(2026, 6, 8, 6, 2),
      );
      expect(
        providerDateTimeIsInstant('2026-06-08T06:02:00', 'America/Vancouver'),
        isFalse,
      );
    },
  );

  test('date-only provider values are not shifted across time zones', () {
    expect(providerDateTimeAsLocal('2026-06-04', 'UTC'), DateTime(2026, 6, 4));
    expect(providerDateTimeIsInstant('2026-06-04', 'UTC'), isFalse);
  });

  test('editor wall time respects UTC, offsets, and IANA zones', () {
    expect(
      providerDateTimeAsWallTime('2026-06-08T09:00:00Z', 'UTC'),
      DateTime.utc(2026, 6, 8, 9),
    );
    expect(
      providerDateTimeAsWallTime(
        '2026-06-08T09:00:00-07:00',
        'America/Vancouver',
      ),
      DateTime(2026, 6, 8, 9),
    );
    expect(
      providerDateTimeAsWallTime('2026-06-08T16:00:00Z', 'America/Vancouver'),
      DateTime(2026, 6, 8, 9),
    );
  });
}
