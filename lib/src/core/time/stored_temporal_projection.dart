import 'dart:convert';

import '../../db/app_database.dart';
import 'provider_date_time.dart';

/// The local instant used by both the schedule and reminder navigation.
/// CalDAV projections may resolve a resource's own VTIMEZONE definition.
DateTime? calendarEventStartAsLocal(CalendarEvent event) => event.allDay
    ? _date(event.startDate) ?? _date(event.startDateTime)
    : projectedUtc(event.rawJson, 'startUtc')?.toLocal() ??
          providerDateTimeAsLocal(event.startDateTime, event.startTimeZone);

DateTime? calendarEventEndAsLocal(CalendarEvent event) => event.allDay
    ? _date(event.endDate) ?? _date(event.endDateTime)
    : projectedUtc(event.rawJson, 'endUtc')?.toLocal() ??
          providerDateTimeAsLocal(event.endDateTime, event.endTimeZone);

DateTime? projectedUtc(String? json, String key) {
  final value = _metadata(json)?[key];
  return value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

/// Dates and floating times retain their written calendar day. Zoned times
/// use the resolved instant, including custom CalDAV timezone definitions.
DateTime? taskDueAsLocal(Task task) {
  final metadata = _metadata(task.providerMetadataJson);
  // CalDAV's dueUtc storage projection falls back to DTSTART without DUE.
  final prefix = metadata?['nativeDue'] is Map ? 'due' : 'start';
  final native = metadata?[prefix == 'due' ? 'nativeDue' : 'nativeStart'];
  if (native is Map) {
    final raw = native['raw'];
    final kind = native['kind'];
    if (raw is String) {
      final match = RegExp(
        r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})Z?)?$',
      ).firstMatch(raw);
      if (match != null) {
        final date = '${match[1]}-${match[2]}-${match[3]}';
        if (kind == 'date') return DateTime.tryParse(date);
        final wall =
            '$date'
            'T${match[4]}:${match[5]}:${match[6]}';
        if (kind == 'floatingDateTime') return DateTime.tryParse(wall);
        return projectedUtc(
              task.providerMetadataJson,
              '${prefix}Utc',
            )?.toLocal() ??
            providerDateTimeAsLocal(
              wall,
              kind == 'utcDateTime' ? 'UTC' : native['timeZoneId']?.toString(),
            );
      }
    }
  }
  return providerDateTimeAsLocal(task.dueUtc, null);
}

Map<Object?, Object?>? _metadata(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final decoded = jsonDecode(json);
    return decoded is Map ? decoded : null;
  } on FormatException {
    return null;
  }
}

DateTime? _date(String? value) => value == null || value.length < 10
    ? null
    : DateTime.tryParse(value.substring(0, 10));
