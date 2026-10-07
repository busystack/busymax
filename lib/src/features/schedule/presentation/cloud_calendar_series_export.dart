import '../../../calendar_providers/calendar_sync_dto.dart';
import '../../../core/time/provider_date_time.dart';
import '../../../core/time/windows_time_zone_ids.dart';
import '../../../google_calendar/google_calendar_api_client.dart';
import '../../../microsoft_calendar/microsoft_calendar_api_client.dart';
import '../../../providers/busy_provider.dart';
import '../../recurrence/domain/event_recurrence_codec.dart';
import 'package:timezone/timezone.dart' as tz;

import 'tz_continuations_2025c.dart';

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
  final exceptions = members
      .where((event) => event.providerRecurringEventId == masterId)
      .toList();
  List<Map<String, Object?>>? defaultReminders;
  if ([authoritativeMaster.single, ...exceptions].any(
    (event) =>
        !event.isCancelled &&
        event.remindersJson is Map &&
        (event.remindersJson as Map)['useDefault'] == true,
  )) {
    final calendars = await client.listCalendars();
    final matching = calendars
        .where((source) => source.providerCalendarId == calendarId)
        .toList();
    if (matching.length != 1) {
      throw const FormatException(
        'Google calendar default reminders are unavailable.',
      );
    }
    final rawValue = matching.single.rawJson['defaultReminders'];
    if (rawValue != null && rawValue is! List) {
      throw const FormatException('Malformed Google default reminders.');
    }
    final raw = rawValue as List? ?? const [];
    if (raw.any((value) => value is! Map)) {
      throw const FormatException('Malformed Google default reminders.');
    }
    defaultReminders = [
      for (final value in raw) Map<String, Object?>.from(value as Map),
    ];
  }
  return cloudSeriesToICalendar(
    master: authoritativeMaster.single,
    exceptions: exceptions,
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
  final microsoftZone = master.provider == BusyProvider.microsoft
      ? _microsoftSeriesZone(master)
      : null;
  final eventLines = <String>[
    ..._eventLines(
      master,
      uid: uid,
      nowUtc: nowUtc,
      googleDefaultReminders: googleDefaultReminders,
      microsoftSeriesZone: microsoftZone,
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
    eventLines.addAll(
      _eventLines(
        exception,
        uid: uid,
        nowUtc: nowUtc,
        // Identity keeps the master's time type when an exception changes its
        // interval or a cancelled resource omits its start entirely.
        recurrenceIdLine: _dateLine(
          'RECURRENCE-ID',
          original,
          master.startTimeZone,
          master.allDay,
          targetZone: microsoftZone,
        ),
        microsoftSeriesZone: microsoftZone,
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
    final masterStart = master.startDateTime;
    final original = master.allDay
        ? date
        : '$date${_wallTimeSuffix(_seriesWallValue(masterStart, master.startTimeZone, microsoftZone))}';
    if (!seenOriginals.add(original)) continue;
    eventLines.addAll([
      'BEGIN:VEVENT',
      'UID:${_text(uid)}',
      'DTSTAMP:${_utc(nowUtc)}',
      _dateLine(
        'RECURRENCE-ID',
        original,
        microsoftZone ?? master.startTimeZone,
        master.allDay,
      ),
      'STATUS:CANCELLED',
      'END:VEVENT',
    ]);
  }
  final referencedZones = RegExp(
    r';TZID=([^:]+):',
  ).allMatches(eventLines.join('\n')).map((match) => match.group(1)!).toSet();
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//BusyMax//BusyMax//EN',
    'CALSCALE:GREGORIAN',
    for (final zone in referencedZones) ..._vtimezoneLines(zone, master),
    ...eventLines,
  ];
  lines.add('END:VCALENDAR');
  return '${lines.join('\r\n')}\r\n';
}

List<String> _eventLines(
  CalendarEventDto event, {
  required String uid,
  required DateTime nowUtc,
  String? recurrenceIdLine,
  String? microsoftSeriesZone,
  List<Map<String, Object?>>? googleDefaultReminders,
}) {
  final lines = <String>[
    'BEGIN:VEVENT',
    'UID:${_text(uid)}',
    'DTSTAMP:${_utc(nowUtc)}',
  ];
  if (recurrenceIdLine != null) lines.add(recurrenceIdLine);
  if (event.isCancelled) {
    lines.add('STATUS:CANCELLED');
  } else {
    final start = event.allDay ? event.startDate : event.startDateTime;
    final end = event.allDay ? event.endDate : event.endDateTime;
    if (start == null || end == null) {
      throw const FormatException('A series event is missing its interval.');
    }
    lines.add(
      _dateLine(
        'DTSTART',
        start,
        event.startTimeZone,
        event.allDay,
        targetZone: microsoftSeriesZone,
      ),
    );
    lines.add(
      _dateLine(
        'DTEND',
        end,
        event.endTimeZone,
        event.allDay,
        targetZone: microsoftSeriesZone,
      ),
    );
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
          _seriesWallValue(start, event.startTimeZone, microsoftSeriesZone),
          microsoftSeriesZone ?? event.startTimeZone,
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
        final endDate = rule.untilRaw;
        final exportRule =
            !event.allDay &&
                endDate != null &&
                RegExp(r'^\d{8}$').hasMatch(endDate)
            ? rule.copyWith(
                untilRaw: _microsoftTimedUntil(
                  endDate,
                  startCivil,
                  microsoftSeriesZone ?? event.startTimeZone,
                ),
              )
            : rule;
        lines.add('RRULE:${exportRule.toRrule()}');
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

String? _microsoftSeriesZone(CalendarEventDto master) {
  final recurrence = master.recurrenceJson;
  final range = recurrence is Map ? recurrence['range'] : null;
  final declared = range is Map
      ? range['recurrenceTimeZone']?.toString()
      : null;
  final zone = declared?.trim().isNotEmpty == true
      ? declared!.trim()
      : master.rawJson['originalStartTimeZone']?.toString() ??
            master.startTimeZone;
  if (zone == null || zone.trim().isEmpty) {
    throw const FormatException(
      'The Microsoft recurrence timezone is unavailable.',
    );
  }
  final normalized = windowsToIanaTimeZones[zone] ?? zone;
  providerInstantInTimeZone(DateTime.utc(2026), normalized);
  return normalized;
}

String _seriesWallValue(String? value, String? sourceZone, String? targetZone) {
  if (value == null) throw const FormatException('Series time is missing.');
  if (targetZone == null || !value.contains('T')) return value;
  final instant = _exportInstant(value, sourceZone);
  if (instant == null) throw const FormatException('Invalid series time.');
  return providerWallTimeIso8601String(
    _exportWallFromInstant(instant, targetZone),
  );
}

String _microsoftTimedUntil(
  String basicDate,
  DateTime startCivil,
  String? zone,
) {
  if (zone == null || zone.trim().isEmpty) {
    throw const FormatException('A timed recurrence needs its timezone.');
  }
  final year = int.parse(basicDate.substring(0, 4));
  final month = int.parse(basicDate.substring(4, 6));
  final day = int.parse(basicDate.substring(6, 8));
  final wall = DateTime.utc(
    year,
    month,
    day,
    startCivil.hour,
    startCivil.minute,
    startCivil.second,
  );
  if (wall.year != year || wall.month != month || wall.day != day) {
    throw const FormatException('Invalid Microsoft recurrence end date.');
  }
  return _utc(_exportInstantFromWall(wall, zone));
}

DateTime? _exportInstant(String? value, String? zone) {
  if (value == null ||
      zone == null ||
      !value.contains('T') ||
      RegExp(r'(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$').hasMatch(value)) {
    return providerDateTimeAsUtcInstant(value, zone);
  }
  final wall = providerDateTimeAsWallTime(value, zone);
  return wall == null ? null : _exportInstantFromWall(wall, zone);
}

DateTime _exportWallFromInstant(DateTime instant, String zone) {
  zone = windowsToIanaTimeZones[zone] ?? zone;
  providerInstantInTimeZone(DateTime.utc(2026), zone);
  final location = tz.getLocation(zone);
  final last = location.transitionAt.lastOrNull;
  if (last == null || instant.millisecondsSinceEpoch <= last) {
    return providerInstantInTimeZone(instant, zone);
  }
  final offset = _PosixContinuation.parse(zone).zoneAt(instant).offset;
  return DateTime.fromMillisecondsSinceEpoch(
    instant.millisecondsSinceEpoch + offset.inMilliseconds,
    isUtc: true,
  );
}

DateTime _exportInstantFromWall(DateTime wall, String zone) {
  zone = windowsToIanaTimeZones[zone] ?? zone;
  providerInstantInTimeZone(DateTime.utc(2026), zone);
  final location = tz.getLocation(zone);
  final last = location.transitionAt.lastOrNull;
  if (last == null ||
      wall.year <=
          DateTime.fromMillisecondsSinceEpoch(last, isUtc: true).year) {
    return providerWallTimeToInstant(wall, zone);
  }
  final continuation = _PosixContinuation.parse(zone);
  final civil = DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  );
  final possible =
      [
          continuation.standard,
          if (continuation.daylight case final daylight?) daylight,
        ].map((candidate) => civil.subtract(candidate.offset)).where((instant) {
          final resolved = _exportWallFromInstant(instant, zone);
          return resolved.year == wall.year &&
              resolved.month == wall.month &&
              resolved.day == wall.day &&
              resolved.hour == wall.hour &&
              resolved.minute == wall.minute &&
              resolved.second == wall.second;
        }).toList()
        ..sort();
  if (possible.isEmpty) {
    throw FormatException(
      'Timezone $zone cannot resolve the recurrence wall time.',
    );
  }
  return possible.first;
}

String _offset(Duration value) {
  final minutes = value.inMinutes;
  final absolute = minutes.abs();
  return '${minutes < 0 ? '-' : '+'}${(absolute ~/ 60).toString().padLeft(2, '0')}'
      '${(absolute % 60).toString().padLeft(2, '0')}';
}

List<String> _vtimezoneLines(String zone, CalendarEventDto master) {
  providerInstantInTimeZone(DateTime.utc(2026), zone);
  final location = tz.getLocation(zone);
  final start = master.allDay ? master.startDate : master.startDateTime;
  final firstYear = (DateTime.tryParse(start ?? '')?.year ?? 2026) - 1;
  final firstInstant = DateTime.utc(firstYear, 1, 1);
  final initial =
      location.transitionAt.isNotEmpty &&
          firstInstant.millisecondsSinceEpoch > location.transitionAt.last
      ? _PosixContinuation.parse(zone).zoneAt(firstInstant)
      : location.timeZone(firstInstant.millisecondsSinceEpoch);
  final lines = <String>['BEGIN:VTIMEZONE', 'TZID:$zone'];
  void observance(
    tz.TimeZone from,
    tz.TimeZone to,
    DateTime wall, {
    String? rule,
    List<DateTime> extraDates = const [],
  }) {
    lines.addAll([
      'BEGIN:${to.isDst ? 'DAYLIGHT' : 'STANDARD'}',
      'DTSTART:${_wall(wall)}',
      'TZOFFSETFROM:${_offset(from.offset)}',
      'TZOFFSETTO:${_offset(to.offset)}',
      'TZNAME:${_text(to.abbreviation)}',
      if (rule != null) 'RRULE:$rule',
      for (var i = 0; i < extraDates.length; i += 3)
        'RDATE:${extraDates.skip(i).take(3).map(_wall).join(',')}',
      'END:${to.isDst ? 'DAYLIGHT' : 'STANDARD'}',
    ]);
  }

  observance(initial, initial, firstInstant.add(initial.offset));
  DateTime? lastTransition;
  for (var i = 0; i < location.transitionAt.length; i++) {
    final at = DateTime.fromMillisecondsSinceEpoch(
      location.transitionAt[i],
      isUtc: true,
    );
    if (at.year < firstYear || at.year > 9998) continue;
    final from = location.timeZone(at.millisecondsSinceEpoch - 1);
    final to = location.zones[location.transitionZone[i]];
    lastTransition = at;
    if (from.offset == to.offset) continue;
    final wall = at.add(from.offset);
    observance(from, to, wall);
  }
  // The compiled timezone TZF stops at its last explicit transition. Its
  // matching IANA TZif footer is the authoritative rule beyond that point;
  // historical patterns cannot distinguish discontinued DST from truncation.
  final continuation = _PosixContinuation.parse(zone);
  final lastAt = lastTransition ?? DateTime.utc(firstYear - 1);
  final current = location.timeZone(lastAt.millisecondsSinceEpoch + 1);
  final next = continuation.transitionsAfter(lastAt);
  if (next.isNotEmpty && current.offset != next.first.from.offset) {
    throw FormatException('Timezone $zone continuation does not match tzdata.');
  }
  for (final group in [
    next.where((entry) => entry.to.isDst).toList(),
    next.where((entry) => !entry.to.isDst).toList(),
  ]) {
    if (group.isEmpty) continue;
    final first = group.first;
    final rule = first.rule.icalRule;
    if (rule != null) {
      observance(first.from, first.to, first.wall, rule: rule);
    } else {
      // POSIX permits transition clocks outside 00:00–23:59 and Julian
      // day rules. Enumerating those exact dates through iCalendar's final
      // representable year avoids fabricating an inexact yearly RRULE.
      observance(
        first.from,
        first.to,
        first.wall,
        extraDates: [for (final entry in group.skip(1)) entry.wall],
      );
    }
  }
  lines.add('END:VTIMEZONE');
  return lines;
}

typedef _FutureTransition = ({
  DateTime at,
  DateTime wall,
  tz.TimeZone from,
  tz.TimeZone to,
  _PosixDateRule rule,
});

final class _PosixContinuation {
  const _PosixContinuation(this.standard, this.daylight, this.start, this.end);

  factory _PosixContinuation.parse(String zone) {
    final source = tzContinuations2025c[zone];
    if (source == null) {
      throw FormatException('No IANA continuation for $zone.');
    }
    final match = RegExp(
      r'^(<[^>]+>|[A-Za-z]{3,})([+-]?\d+(?::\d{1,2}){0,2})'
      r'(?:(<[^>]+>|[A-Za-z]{3,})([+-]?\d+(?::\d{1,2}){0,2})?)?'
      r'(?:,([^,]+),([^,]+))?$',
    ).firstMatch(source);
    if (match == null) {
      throw FormatException('Invalid IANA continuation for $zone.');
    }
    String name(String raw) =>
        raw.startsWith('<') ? raw.substring(1, raw.length - 1) : raw;
    final standardOffset = -_posixSeconds(match.group(2)!);
    final standard = tz.TimeZone(
      Duration(seconds: standardOffset),
      isDst: false,
      abbreviation: name(match.group(1)!),
    );
    if (match.group(3) == null) {
      return _PosixContinuation(standard, null, null, null);
    }
    if (match.group(5) == null || match.group(6) == null) {
      throw FormatException('Incomplete IANA continuation for $zone.');
    }
    final daylight = tz.TimeZone(
      Duration(
        seconds: match.group(4) == null
            ? standardOffset + 3600
            : -_posixSeconds(match.group(4)!),
      ),
      isDst: true,
      abbreviation: name(match.group(3)!),
    );
    return _PosixContinuation(
      standard,
      daylight,
      _PosixDateRule.parse(match.group(5)!),
      _PosixDateRule.parse(match.group(6)!),
    );
  }

  final tz.TimeZone standard;
  final tz.TimeZone? daylight;
  final _PosixDateRule? start;
  final _PosixDateRule? end;

  /// TZif v3 specifies this sentinel pair as daylight saving in effect all
  /// year: January 1 00:00 through December 31 24:00 plus the DST difference.
  bool get allYearDaylight =>
      daylight != null &&
      start?.date == '0' &&
      start?.seconds == 0 &&
      end?.date == 'J365' &&
      end?.seconds == 86400 + (daylight!.offset - standard.offset).inSeconds;

  tz.TimeZone zoneAt(DateTime instant) {
    if (daylight == null) return standard;
    if (allYearDaylight) return daylight!;
    final transitions = <_FutureTransition>[];
    for (var year = instant.year - 1; year <= instant.year + 1; year++) {
      if (year < 1 || year > 9999) continue;
      for (final pair in [
        (start!, standard, daylight!),
        (end!, daylight!, standard),
      ]) {
        final (rule, from, to) = pair;
        final wall = rule.wall(year);
        transitions.add((
          at: wall.subtract(from.offset),
          wall: wall,
          from: from,
          to: to,
          rule: rule,
        ));
      }
    }
    transitions.sort((a, b) => a.at.compareTo(b.at));
    tz.TimeZone current = standard;
    for (final transition in transitions) {
      if (transition.at.isAfter(instant)) break;
      current = transition.to;
    }
    return current;
  }

  List<_FutureTransition> transitionsAfter(DateTime lastAt) {
    if (daylight == null) return const [];
    if (allYearDaylight) return const [];
    final result = <_FutureTransition>[];
    for (var year = lastAt.year; year <= 9999; year++) {
      for (final pair in [
        (start!, standard, daylight!),
        (end!, daylight!, standard),
      ]) {
        final (rule, from, to) = pair;
        final wall = rule.wall(year);
        if (wall.year > 9999) continue;
        final at = wall.subtract(from.offset);
        if (!at.isAfter(lastAt)) continue;
        result.add((at: at, wall: wall, from: from, to: to, rule: rule));
      }
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }
}

int _posixSeconds(String source) {
  final sign = source.startsWith('-') ? -1 : 1;
  final parts = source
      .replaceFirst(RegExp(r'^[+-]'), '')
      .split(':')
      .map(int.parse)
      .toList();
  if (parts.length > 3 || parts.skip(1).any((value) => value > 59)) {
    throw const FormatException('Invalid POSIX timezone offset.');
  }
  return sign *
      (parts[0] * 3600 +
          (parts.length > 1 ? parts[1] * 60 : 0) +
          (parts.length > 2 ? parts[2] : 0));
}

final class _PosixDateRule {
  const _PosixDateRule(this.date, this.seconds);

  factory _PosixDateRule.parse(String value) {
    final parts = value.split('/');
    if (parts.length > 2) {
      throw const FormatException('Invalid POSIX transition.');
    }
    return _PosixDateRule(
      parts[0],
      parts.length == 2 ? _posixSeconds(parts[1]) : 7200,
    );
  }

  final String date;
  final int seconds;

  DateTime wall(int year) {
    final monthRule = RegExp(r'^M(\d{1,2})\.(\d)\.(\d)$').firstMatch(date);
    DateTime day;
    if (monthRule != null) {
      final month = int.parse(monthRule.group(1)!);
      final week = int.parse(monthRule.group(2)!);
      final weekday = int.parse(monthRule.group(3)!);
      if (month < 1 || month > 12 || week < 1 || week > 5 || weekday > 6) {
        throw const FormatException('Invalid POSIX month rule.');
      }
      final first = DateTime.utc(year, month, 1);
      var d = 1 + (weekday - first.weekday % 7 + 7) % 7 + (week - 1) * 7;
      if (week == 5 && d > DateTime.utc(year, month + 1, 0).day) d -= 7;
      day = DateTime.utc(year, month, d);
    } else if (date.startsWith('J')) {
      final n = int.parse(date.substring(1));
      if (n < 1 || n > 365) {
        throw const FormatException('Invalid POSIX Julian rule.');
      }
      final leap =
          DateTime.utc(
            year,
            3,
            1,
          ).difference(DateTime.utc(year, 1, 1)).inDays ==
          60;
      day = DateTime.utc(year, 1, 1 + n - 1 + (leap && n >= 60 ? 1 : 0));
    } else {
      final n = int.parse(date);
      if (n < 0 || n > 365) {
        throw const FormatException('Invalid POSIX day rule.');
      }
      day = DateTime.utc(year, 1, 1 + n);
    }
    return day.add(Duration(seconds: seconds));
  }

  String? get icalRule {
    final match = RegExp(r'^M(\d{1,2})\.(\d)\.(\d)$').firstMatch(date);
    if (match == null || seconds < 0 || seconds >= 86400) return null;
    final week = int.parse(match.group(2)!);
    final weekday = const [
      'SU',
      'MO',
      'TU',
      'WE',
      'TH',
      'FR',
      'SA',
    ][int.parse(match.group(3)!)];
    return 'FREQ=YEARLY;BYMONTH=${match.group(1)};BYDAY=${week == 5 ? -1 : week}$weekday'
        ';BYHOUR=${seconds ~/ 3600};BYMINUTE=${seconds ~/ 60 % 60};BYSECOND=${seconds % 60}';
  }
}

String _dateLine(
  String key,
  String value,
  String? zone,
  bool allDay, {
  String? targetZone,
}) {
  if (allDay) {
    final localized = targetZone != null && value.contains('T')
        ? _exportWallFromInstant(_exportInstant(value, zone)!, targetZone)
        : null;
    final date =
        localized ??
        DateTime.tryParse(value.length >= 10 ? value.substring(0, 10) : value);
    if (date == null) throw const FormatException('Invalid all-day date.');
    return '$key;VALUE=DATE:${_date(date)}';
  }
  final effectiveValue = _seriesWallValue(value, zone, targetZone);
  final effectiveZone = targetZone ?? zone;
  final wall = providerDateTimeAsWallTime(effectiveValue, effectiveZone);
  if (wall == null) throw const FormatException('Invalid event date-time.');
  final safeZone =
      windowsToIanaTimeZones[effectiveZone] ?? effectiveZone?.trim();
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
      !RegExp(r'(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$').hasMatch(effectiveValue)) {
    throw const FormatException(
      'A floating provider time cannot be exported safely.',
    );
  }
  final instant = _exportInstant(effectiveValue, effectiveZone);
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
