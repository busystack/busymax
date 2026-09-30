import '../../../calendar_providers/calendar_sync_dto.dart';
import '../../../core/time/provider_date_time.dart';
import '../../../core/time/windows_time_zone_ids.dart';
import '../../../google_calendar/google_calendar_api_client.dart';
import '../../../microsoft_calendar/microsoft_calendar_api_client.dart';
import '../../../providers/busy_provider.dart';
import '../../recurrence/domain/event_recurrence_codec.dart';

/// Only offer a series backup when the authoritative resource can be read.
/// WebCal projections and unsynced cloud creates can still export an
/// occurrence, but must not be presented as complete series exports.
bool canExportAuthoritativeEventSeries({
  required BusyProvider provider,
  required String? providerEventId,
  required String? davCollectionId,
}) => switch (provider) {
  BusyProvider.google || BusyProvider.microsoft =>
    providerEventId != null && providerEventId.isNotEmpty,
  BusyProvider.nextcloud || BusyProvider.appleICloud =>
    davCollectionId != null && davCollectionId.isNotEmpty,
  _ => false,
};

/// Reads the provider's complete master/exception set before serializing it.
/// A finite schedule cache is never treated as an authoritative series backup.
Future<String> exportGoogleEventSeries({
  required GoogleCalendarApiClient client,
  required String calendarId,
  required String eventId,
  required DateTime nowUtc,
}) async {
  final selected = await client.getEvent(
    calendarId: calendarId,
    eventId: eventId,
  );
  final masterId =
      selected.providerRecurringEventId ?? selected.providerEventId;
  final master = masterId == selected.providerEventId
      ? selected
      : await client.getEvent(calendarId: calendarId, eventId: masterId);
  final uid = _uid(master);
  List<Map<String, Object?>>? defaultReminders;
  if (master.remindersJson is Map &&
      (master.remindersJson as Map)['useDefault'] == true) {
    final calendars = await client.listCalendars();
    final matching = calendars
        .where((source) => source.providerCalendarId == calendarId)
        .toList();
    if (matching.length != 1 ||
        matching.single.rawJson['defaultReminders'] is! List) {
      throw const FormatException(
        'Google calendar default reminders are unavailable.',
      );
    }
    final raw = matching.single.rawJson['defaultReminders'] as List;
    if (raw.any((value) => value is! Map)) {
      throw const FormatException('Malformed Google default reminders.');
    }
    defaultReminders = [
      for (final value in raw) Map<String, Object?>.from(value as Map),
    ];
  }
  final members = await client.eventsWithICalUid(
    calendarId: calendarId,
    iCalUid: uid,
    includeCancelled: true,
  );
  final authoritativeMaster = members
      .where(
        (event) =>
            event.providerEventId == masterId &&
            event.providerRecurringEventId == null,
      )
      .toList();
  if (authoritativeMaster.length != 1) {
    throw const FormatException(
      'The complete Google series master is unavailable.',
    );
  }
  return cloudSeriesToICalendar(
    master: authoritativeMaster.single,
    exceptions: members
        .where((event) => event.providerRecurringEventId == masterId)
        .toList(),
    googleDefaultReminders: defaultReminders,
    nowUtc: nowUtc,
  );
}

Future<String> exportMicrosoftEventSeries({
  required MicrosoftCalendarApiClient client,
  required String calendarId,
  required String eventId,
  required DateTime nowUtc,
}) async {
  final selected = await client.getEvent(
    calendarId: calendarId,
    eventId: eventId,
  );
  final masterId =
      selected.providerRecurringEventId ?? selected.providerEventId;
  final master = masterId == selected.providerEventId
      ? selected
      : await client.getEvent(calendarId: calendarId, eventId: masterId);
  if (master.recurrenceJson == null) {
    throw const FormatException('The Microsoft series master is unavailable.');
  }
  final snapshot = await client.getSeriesExceptionSnapshot(
    calendarId: calendarId,
    recurringEventId: masterId,
  );
  final exceptions = <CalendarEventDto>[];
  for (final partial in snapshot.exceptions) {
    if (partial.providerEventId.isEmpty) {
      throw const FormatException(
        'A Microsoft series exception has no identity.',
      );
    }
    exceptions.add(
      await client.getEvent(
        calendarId: calendarId,
        eventId: partial.providerEventId,
      ),
    );
  }
  return cloudSeriesToICalendar(
    master: master,
    exceptions: exceptions,
    cancelledOccurrenceIds: snapshot.cancelledIds,
    nowUtc: nowUtc,
  );
}

String cloudSeriesToICalendar({
  required CalendarEventDto master,
  required List<CalendarEventDto> exceptions,
  Set<String> cancelledOccurrenceIds = const {},
  List<Map<String, Object?>>? googleDefaultReminders,
  required DateTime nowUtc,
}) {
  final uid = _uid(master);
  if (master.providerRecurringEventId != null) {
    throw const FormatException(
      'A recurrence instance cannot be a series master.',
    );
  }
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//BusyMax//BusyMax//EN',
    'CALSCALE:GREGORIAN',
    ..._eventLines(
      master,
      uid: uid,
      nowUtc: nowUtc,
      googleDefaultReminders: googleDefaultReminders,
    ),
  ];
  final seenOriginals = <String>{};
  for (final exception in exceptions) {
    if (exception.providerRecurringEventId != master.providerEventId) {
      throw const FormatException(
        'An exception belongs to a different series.',
      );
    }
    final original = exception.providerOriginalStartKey;
    if (original == null || original.isEmpty || !seenOriginals.add(original)) {
      throw const FormatException(
        'A series exception has an ambiguous original start.',
      );
    }
    lines.addAll(
      _eventLines(
        exception,
        uid: uid,
        nowUtc: nowUtc,
        originalStart: original,
        googleDefaultReminders: googleDefaultReminders,
      ),
    );
  }
  for (final id in cancelledOccurrenceIds) {
    final match = RegExp(r'\.(\d{4}-\d{2}-\d{2})$').firstMatch(id);
    if (match == null) {
      throw const FormatException(
        'A cancelled occurrence has no usable original date.',
      );
    }
    final date = match.group(1)!;
    final original = master.allDay
        ? date
        : '$date${_wallTimeSuffix(master.startDateTime)}';
    if (!seenOriginals.add(original)) continue;
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${_text(uid)}',
      'DTSTAMP:${_utc(nowUtc)}',
      _dateLine('RECURRENCE-ID', original, master.startTimeZone, master.allDay),
      'STATUS:CANCELLED',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  return '${lines.join('\r\n')}\r\n';
}

List<String> _eventLines(
  CalendarEventDto event, {
  required String uid,
  required DateTime nowUtc,
  String? originalStart,
  List<Map<String, Object?>>? googleDefaultReminders,
}) {
  final lines = <String>[
    'BEGIN:VEVENT',
    'UID:${_text(uid)}',
    'DTSTAMP:${_utc(nowUtc)}',
  ];
  if (originalStart != null) {
    lines.add(
      _dateLine(
        'RECURRENCE-ID',
        originalStart,
        event.startTimeZone,
        event.allDay,
      ),
    );
  }
  if (event.isCancelled) {
    lines.add('STATUS:CANCELLED');
  } else {
    final start = event.allDay ? event.startDate : event.startDateTime;
    final end = event.allDay ? event.endDate : event.endDateTime;
    if (start == null || end == null) {
      throw const FormatException('A series event is missing its interval.');
    }
    lines.add(_dateLine('DTSTART', start, event.startTimeZone, event.allDay));
    lines.add(_dateLine('DTEND', end, event.endTimeZone, event.allDay));
    lines.add('SUMMARY:${_text(event.title)}');
    if (event.description?.isNotEmpty == true) {
      lines.add('DESCRIPTION:${_text(event.description!)}');
    }
    if (event.location?.isNotEmpty == true) {
      lines.add('LOCATION:${_text(event.location!)}');
    }
    if (event.categoriesJson is List) {
      final categories = (event.categoriesJson as List)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toList();
      if (categories.isNotEmpty) {
        lines.add('CATEGORIES:${categories.map(_text).join(',')}');
      }
    }
    final classification = switch (event.visibility?.toLowerCase()) {
      'private' || 'personal' => 'PRIVATE',
      'confidential' => 'CONFIDENTIAL',
      'public' || 'normal' => 'PUBLIC',
      _ => null,
    };
    if (classification != null) lines.add('CLASS:$classification');
    final transparent = switch (event.transparencyOrShowAs?.toLowerCase()) {
      'transparent' || 'free' => true,
      'opaque' || 'busy' => false,
      _ => null,
    };
    if (transparent != null) {
      lines.add('TRANSP:${transparent ? 'TRANSPARENT' : 'OPAQUE'}');
    }
    if (_safeHttps(event.webLink)) {
      lines.add('URL:${event.webLink}');
    }
    if (event.provider == BusyProvider.google &&
        event.attachmentsJson is List) {
      for (final attachment in event.attachmentsJson as List) {
        if (attachment is! Map) continue;
        final url = attachment['fileUrl']?.toString();
        if (_safeHttps(url)) lines.add('ATTACH:$url');
      }
    }
    if (event.recurrenceJson != null) {
      if (event.provider == BusyProvider.google) {
        final recurrence = event.recurrenceJson;
        if (recurrence is! List || recurrence.any((line) => line is! String)) {
          throw const FormatException('Unsupported Google recurrence data.');
        }
        for (final line in recurrence) {
          final value = line as String;
          if (!RegExp(
            r'^(RRULE|EXRULE|RDATE|EXDATE)(;[^:\r\n]*)?:[^\r\n]+$',
            caseSensitive: false,
          ).hasMatch(value)) {
            throw const FormatException('Unsupported Google recurrence line.');
          }
          lines.add(value);
        }
      } else if (event.provider == BusyProvider.microsoft) {
        final startCivil = providerDateTimeAsWallTime(
          start,
          event.startTimeZone,
        );
        if (startCivil == null) {
          throw const FormatException('Invalid series start.');
        }
        final rule = EventRecurrenceCodec.decode(
          event.provider,
          event.recurrenceJson,
          baseDate: startCivil,
        );
        if (!rule.isSupported || !rule.repeats) {
          throw const FormatException(
            'Microsoft recurrence cannot be exported safely.',
          );
        }
        lines.add('RRULE:${rule.toRrule()}');
      }
    }
    lines.addAll(_attendeeLines(event));
    lines.addAll(_reminderLines(event, googleDefaultReminders));
  }
  lines.add('END:VEVENT');
  return lines;
}

List<String> _attendeeLines(CalendarEventDto event) {
  final result = <String>[];
  final organizer = event.organizerJson;
  if (organizer is Map) {
    final address =
        organizer['email'] ??
        (organizer['emailAddress'] is Map
            ? (organizer['emailAddress'] as Map)['address']
            : null);
    if (address is String && _safeEmail(address)) {
      result.add('ORGANIZER:mailto:$address');
    }
  }
  final attendees = event.attendeesJson;
  if (attendees is List) {
    for (final value in attendees) {
      if (value is! Map) continue;
      final address =
          value['email'] ??
          (value['emailAddress'] is Map
              ? (value['emailAddress'] as Map)['address']
              : null);
      if (address is! String || !_safeEmail(address)) continue;
      final optional = value['optional'] == true || value['type'] == 'optional';
      final response =
          value['responseStatus']?.toString() ??
          (value['status'] is Map
              ? (value['status'] as Map)['response']?.toString()
              : null);
      final partstat = switch (response) {
        'accepted' => 'ACCEPTED',
        'declined' => 'DECLINED',
        'tentative' || 'tentativelyAccepted' => 'TENTATIVE',
        'needsAction' || 'notResponded' => 'NEEDS-ACTION',
        _ => null,
      };
      final name =
          value['displayName']?.toString() ??
          (value['emailAddress'] is Map
              ? (value['emailAddress'] as Map)['name']?.toString()
              : null);
      result.add(
        'ATTENDEE${optional ? ';ROLE=OPT-PARTICIPANT' : ''}'
        '${partstat == null ? '' : ';PARTSTAT=$partstat'}'
        '${name == null || name.isEmpty ? '' : ';CN=${_parameter(name)}'}'
        ':mailto:$address',
      );
    }
  }
  return result;
}

List<String> _reminderLines(
  CalendarEventDto event,
  List<Map<String, Object?>>? googleDefaultReminders,
) {
  final data = event.remindersJson;
  final minutes = <int>[];
  if (event.provider == BusyProvider.google && data is Map) {
    final overrides = data['useDefault'] == true
        ? googleDefaultReminders
        : data['overrides'];
    if (data['useDefault'] == true && overrides == null) {
      throw const FormatException('Google default reminders are unavailable.');
    }
    if (overrides is List) {
      for (final item in overrides) {
        if (item is! Map ||
            item['method'] != 'popup' ||
            item['minutes'] is! int) {
          throw const FormatException('Unsupported Google reminder format.');
        }
        minutes.add(item['minutes'] as int);
      }
    } else if (overrides != null) {
      throw const FormatException('Malformed Google reminder collection.');
    }
  } else if (event.provider == BusyProvider.microsoft &&
      data is Map &&
      data['isReminderOn'] == true &&
      data['reminderMinutesBeforeStart'] is int) {
    minutes.add(data['reminderMinutesBeforeStart'] as int);
  }
  return [
    for (final value in minutes)
      if (value >= 0) ...[
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'TRIGGER:-PT${value}M',
        'DESCRIPTION:${_text(event.title)}',
        'END:VALARM',
      ],
  ];
}

String _uid(CalendarEventDto event) {
  final value =
      event.rawJson[event.provider == BusyProvider.google
          ? 'iCalUID'
          : 'uid'] ??
      event.rawJson['iCalUId'];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException(
      'The provider did not return an iCalendar UID.',
    );
  }
  return value.trim();
}

String _dateLine(String key, String value, String? zone, bool allDay) {
  if (allDay) {
    final date = DateTime.tryParse(
      value.length >= 10 ? value.substring(0, 10) : value,
    );
    if (date == null) throw const FormatException('Invalid all-day date.');
    return '$key;VALUE=DATE:${_date(date)}';
  }
  final wall = providerDateTimeAsWallTime(value, zone);
  if (wall == null) throw const FormatException('Invalid event date-time.');
  final safeZone = windowsToIanaTimeZones[zone] ?? zone?.trim();
  if (safeZone != null &&
      safeZone.isNotEmpty &&
      !isUtcTimeZone(safeZone) &&
      RegExp(r'^[A-Za-z0-9_+./-]+$').hasMatch(safeZone)) {
    providerInstantInTimeZone(DateTime.utc(2026), safeZone);
    return '$key;TZID=$safeZone:${_wall(wall)}';
  }
  if (safeZone != null && safeZone.isNotEmpty && !isUtcTimeZone(safeZone)) {
    throw const FormatException('Unsupported event timezone.');
  }
  if (safeZone == null &&
      !RegExp(r'(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$').hasMatch(value)) {
    throw const FormatException(
      'A floating provider time cannot be exported safely.',
    );
  }
  final instant = providerDateTimeAsUtcInstant(value, zone);
  if (instant == null) throw const FormatException('Unknown event timezone.');
  return '$key:${_utc(instant)}';
}

String _wallTimeSuffix(String? value) {
  if (value == null) throw const FormatException('Series start is missing.');
  final match = RegExp(r'T(\d{2}:\d{2}:\d{2})').firstMatch(value);
  if (match == null) {
    throw const FormatException('Series start time is invalid.');
  }
  return 'T${match.group(1)}';
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}';

String _wall(DateTime value) =>
    '${_date(value)}T'
    '${value.hour.toString().padLeft(2, '0')}'
    '${value.minute.toString().padLeft(2, '0')}'
    '${value.second.toString().padLeft(2, '0')}';

String _utc(DateTime value) => '${_wall(value.toUtc())}Z';

String _text(String value) => value
    .replaceAll('\\', r'\\')
    .replaceAll('\r', '')
    .replaceAll('\n', r'\n')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,');

String _parameter(String value) => '"${_text(value).replaceAll('"', r'\"')}"';

bool _safeEmail(String value) =>
    RegExp(r'^[^\s@:/]+@[^\s@:/]+\.[^\s@:/]+$').hasMatch(value);

bool _safeHttps(String? value) {
  final uri = Uri.tryParse(value ?? '');
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !value!.contains(RegExp(r'[\r\n]'));
}
