import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('non-UTC provider dateTime without offset keeps wall time', () {
    expect(
      providerDateTimeAsLocal('2026-06-08T06:02:00', 'America/Vancouver'),
      DateTime(2026, 6, 8, 6, 2),
    );
  });

  test('date-only provider values are not shifted across time zones', () {
    expect(providerDateTimeAsLocal('2026-06-04', 'UTC'), DateTime(2026, 6, 4));
    expect(providerDateTimeIsInstant('2026-06-04', 'UTC'), isFalse);
  });
}
