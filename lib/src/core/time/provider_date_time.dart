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

/// Parses a provider timestamp as the wall-clock value shown by an editor.
///
/// Explicit offsets already carry their wall time. UTC instants are converted
/// to [timeZone] when it is an IANA zone. Zone-less provider values are wall
/// times already and must not be shifted by the machine's local zone.
DateTime? providerDateTimeAsWallTime(String? value, String? timeZone) {
  if (value == null || value.isEmpty) return null;
  if (!value.contains('T')) {
    return DateTime.tryParse(
      value.length >= 10 ? value.substring(0, 10) : value,
    );
  }
  if (RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value)) {
    return DateTime.tryParse(
      value.replaceFirst(RegExp(r'[+-]\d{2}:?\d{2}$'), ''),
    );
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  if (parsed.isUtc) {
    return providerUtcInstantAsWallTime(parsed, timeZone);
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
  return parsed;
}

bool providerDateTimeIsInstant(String? value, String? timeZone) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null || value == null || !value.contains('T')) {
    return false;
  }
  return parsed.isUtc || isUtcTimeZone(timeZone);
}

DateTime providerUtcInstantAsWallTime(DateTime value, String? timeZone) {
  final instant = value.toUtc();
  if (isUtcTimeZone(timeZone)) return instant;
  final location = _timeZoneLocation(timeZone);
  if (location == null) return instant.toLocal();
  final zoned = time_zone.TZDateTime.from(instant, location);
  return DateTime(
    zoned.year,
    zoned.month,
    zoned.day,
    zoned.hour,
    zoned.minute,
    zoned.second,
    zoned.millisecond,
    zoned.microsecond,
  );
}

bool isUtcTimeZone(String? timeZone) {
  final normalizedZone = timeZone?.trim().toLowerCase();
  return normalizedZone == 'utc' ||
      normalizedZone == 'etc/utc' ||
      normalizedZone == 'gmt' ||
      normalizedZone == 'etc/gmt';
}

DateTime? _providerWallTimeAsUtc(DateTime wall, String? timeZoneId) {
  final location = _timeZoneLocation(timeZoneId);
  if (location == null) return null;
  try {
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
  } on ArgumentError {
    return null;
  }
}

time_zone.Location? _timeZoneLocation(String? timeZoneId) {
  final id = timeZoneId?.trim();
  if (id == null || id.isEmpty) return null;
  if (!_timeZonesInitialized) {
    time_zone_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }
  try {
    return time_zone.getLocation(id);
  } on time_zone.LocationNotFoundException {
    // Some providers use platform-specific zone labels. Preserve their prior
    // local-wall-time behavior when no IANA definition is available.
    return null;
  }
}
