import 'package:timezone/data/latest_all.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

var _timeZonesInitialized = false;

DateTime? providerDateTimeAsLocal(String? value, String? timeZone) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) {
    return null;
  }
  if (value == null || !value.contains('T')) {
    return parsed;
  }
  if (parsed.isUtc) {
    return parsed.toLocal();
  }
  if (isUtcTimeZone(timeZone)) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }
  return parsed;
}

DateTime? providerDateTimeAsUtcInstant(String? value, String? timeZone) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) {
    return null;
  }
  if (value == null || !value.contains('T')) {
    return parsed.toUtc();
  }
  if (parsed.isUtc) {
    return parsed.toUtc();
  }
  if (isUtcTimeZone(timeZone)) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }
  final zoned = _providerWallTimeAsUtc(parsed, timeZone);
  if (zoned != null) {
    return zoned;
  }
  return parsed.toUtc();
}

bool providerDateTimeIsInstant(String? value, String? timeZone) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null || value == null || !value.contains('T')) {
    return false;
  }
  return parsed.isUtc || isUtcTimeZone(timeZone);
}

bool isUtcTimeZone(String? timeZone) {
  final normalizedZone = timeZone?.trim().toLowerCase();
  return normalizedZone == 'utc' ||
      normalizedZone == 'etc/utc' ||
      normalizedZone == 'gmt' ||
      normalizedZone == 'etc/gmt';
}

DateTime? _providerWallTimeAsUtc(DateTime wall, String? timeZoneId) {
  final id = timeZoneId?.trim();
  if (id == null || id.isEmpty) return null;
  if (!_timeZonesInitialized) {
    time_zone_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }
  try {
    final location = time_zone.getLocation(id);
    final instant = time_zone.TZDateTime(
      location,
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
      wall.millisecond,
      wall.microsecond,
    ).toUtc();
    return DateTime.fromMillisecondsSinceEpoch(
      instant.millisecondsSinceEpoch,
      isUtc: true,
    );
  } on time_zone.LocationNotFoundException {
    // Some providers use platform-specific zone labels. Preserve their prior
    // local-wall-time behavior when no IANA definition is available.
    return null;
  }
}
