import 'dart:convert';

import '../../db/app_database.dart';
import 'provider_date_time.dart';

/// The local instant used by both the schedule and reminder navigation.
/// CalDAV projections may resolve a resource's own VTIMEZONE definition.
DateTime? calendarEventStartAsLocal(CalendarEvent event) => event.allDay
    ? _date(event.startDate) ?? _date(event.startDateTime)
    : _floatingTemporal(event.rawJson, 'nativeStart') ??
          projectedUtc(event.rawJson, 'startUtc')?.toLocal() ??
          providerDateTimeAsLocal(event.startDateTime, event.startTimeZone);

DateTime? calendarEventEndAsLocal(CalendarEvent event) => event.allDay
    ? _date(event.endDate) ?? _date(event.endDateTime)
    : _floatingTemporal(event.rawJson, 'nativeEnd') ??
          projectedUtc(event.rawJson, 'endUtc')?.toLocal() ??
          providerDateTimeAsLocal(event.endDateTime, event.endTimeZone);

/// Uses the same resolved instants as Schedule projection when deciding which
/// cached events an authoritative UTC provider window may reconcile. All-day
/// values are dates with an exclusive end, not device-local midnight instants.
bool storedCalendarEventOverlapsUtcRange(
  CalendarEvent event,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final start = event.allDay
      ? _dateUtc(event.startDate ?? event.startDateTime)
      : calendarEventStartAsLocal(event)?.toUtc();
  final end = event.allDay
      ? _dateUtc(event.endDate ?? event.endDateTime)
      : calendarEventEndAsLocal(event)?.toUtc();
  if (start == null) return false;
  final effectiveEnd =
      end ??
      start.add(
        event.allDay ? const Duration(days: 1) : const Duration(minutes: 1),
      );
  return effectiveEnd.isAfter(rangeStart.toUtc()) &&
      start.isBefore(rangeEnd.toUtc());
}

DateTime? projectedUtc(String? json, String key) {
  final value = _metadata(json)?[key];
  return value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

DateTime? _floatingTemporal(String? json, String key) {
  final native = _metadata(json)?[key];
  if (native is! Map || native['kind'] != 'floatingDateTime') return null;
  final raw = native['raw'];
  if (raw is! String) return null;
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$')
      .firstMatch(raw);
  return match == null
      ? null
      : DateTime.tryParse(
          '${match[1]}-${match[2]}-${match[3]}T${match[4]}:${match[5]}:${match[6]}',
        );
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

/// Deadline eligibility differs from schedule/reminder navigation: CalDAV
/// stores DTSTART in dueUtc when no DUE exists, but that is not a deadline.
DateTime? taskDeadlineAsLocal(Task task) {
  if (!isVisibleTaskProjection(task)) return null;
  final metadata = _metadata(task.providerMetadataJson);
  if (metadata?['transport'] == 'caldav' && metadata?['nativeDue'] is! Map) {
    return null;
  }
  return taskDueAsLocal(task);
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

DateTime? _dateUtc(String? value) {
  final date = _date(value);
  return date == null ? null : DateTime.utc(date.year, date.month, date.day);
}
