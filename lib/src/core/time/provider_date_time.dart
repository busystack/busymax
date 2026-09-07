import 'package:timezone/data/latest_all.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;
import 'windows_time_zone_ids.dart';

var _timeZonesInitialized = false;

final _civilLocation = time_zone.Location('BusyMax/Civil', const [], const [], [
  const time_zone.TimeZone(Duration.zero, isDst: false, abbreviation: 'civil'),
]);

/// Host-independent wall-field arithmetic. This is not an instant; serialize
/// it with [providerWallTimeIso8601String], not DateTime.toIso8601String.
DateTime providerCivilDateTime(DateTime value) => time_zone.TZDateTime.from(
  DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  ),
  _civilLocation,
);

String providerWallTimeIso8601String(DateTime value) => DateTime.utc(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
  value.second,
  value.millisecond,
  value.microsecond,
).toIso8601String().replaceFirst(RegExp(r'Z$'), '');

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
  return _providerWallTimeAsUtc(parsed, timeZone)?.toLocal() ?? parsed;
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

/// Parses wall fields into a neutral civil value, without first constructing a
/// host-local DateTime (which could normalize a time in the host's DST gap).
/// Explicit offsets retain their written fields; Z instants use the event zone.
DateTime? providerDateTimeAsCivilTime(String? value, String? timeZone) {
  if (value == null || value.isEmpty) return null;
  if (!value.contains('T')) {
    final date = value.length >= 10 ? value.substring(0, 10) : value;
    final parsed = DateTime.tryParse('${date}T00:00:00Z');
    return parsed == null ? null : providerCivilDateTime(parsed);
  }
  if (value.endsWith('Z') || value.endsWith('z')) {
    final instant = DateTime.tryParse(value);
    if (instant == null) return null;
    final location = _timeZoneLocation(timeZone);
    return providerCivilDateTime(
      isUtcTimeZone(timeZone)
          ? instant
          : location == null
          ? instant.toLocal()
          : time_zone.TZDateTime.from(instant, location),
    );
  }
  final fields = value.replaceFirst(RegExp(r'[+-]\d{2}:?\d{2}$'), '');
  final parsed = DateTime.tryParse('${fields}Z');
  return parsed == null ? null : providerCivilDateTime(parsed);
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

/// A real zoned DateTime, retaining the offset even in a host-zone DST gap.
/// Unknown explicit zones must not silently acquire the machine's timezone.
DateTime providerInstantInTimeZone(DateTime instant, String? zone) {
  if (isUtcTimeZone(zone)) return instant.toUtc();
  if (zone == null || zone.isEmpty) return instant.toLocal();
  final location = _timeZoneLocation(zone);
  if (location == null) throw UnsupportedError('Unknown event timezone: $zone');
  return time_zone.TZDateTime.from(instant, location);
}

/// Resolves a civil displayed value before a preview is shown. Returning the
/// resolved instant lets preview and persistence agree across DST gaps/folds.
DateTime providerWallTimeToInstant(DateTime wall, String? zone) {
  if (isUtcTimeZone(zone)) {
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
      wall.millisecond,
      wall.microsecond,
    );
  }
  if (zone == null || zone.isEmpty) {
    return DateTime(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
      wall.millisecond,
      wall.microsecond,
    ).toUtc();
  }
  final instant = _providerWallTimeAsUtc(wall, zone);
  if (instant == null) throw UnsupportedError('Unknown event timezone: $zone');
  return instant;
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
    return time_zone.getLocation(windowsToIanaTimeZones[id] ?? id);
  } on time_zone.LocationNotFoundException {
    // Some providers use platform-specific zone labels. Preserve their prior
    // local-wall-time behavior when no IANA definition is available.
    return null;
  }
}
