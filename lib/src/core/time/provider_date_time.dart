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
