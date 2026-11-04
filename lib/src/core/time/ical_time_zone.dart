import 'package:timezone/timezone.dart' as tz;

import 'provider_date_time.dart';
import 'windows_time_zone_ids.dart';
import 'tz_continuations_2026f.dart';

/// Shared, lossless IANA time-zone serialization for DAV writes and exports.
DateTime ianaWallFromInstant(DateTime instant, String zone) {
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

DateTime ianaInstantFromWall(DateTime wall, String zone) {
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
          final resolved = ianaWallFromInstant(instant, zone);
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
  final seconds = value.inSeconds;
  final absolute = seconds.abs();
  return '${seconds < 0 ? '-' : '+'}${(absolute ~/ 3600).toString().padLeft(2, '0')}'
      '${(absolute ~/ 60 % 60).toString().padLeft(2, '0')}'
      '${absolute % 60 == 0 ? '' : (absolute % 60).toString().padLeft(2, '0')}';
}

List<String> icalTimeZoneLines(String zone, {required int firstYear}) {
  providerInstantInTimeZone(DateTime.utc(2026), zone);
  final location = tz.getLocation(zone);
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
  }) {
    lines.addAll([
      'BEGIN:${to.isDst ? 'DAYLIGHT' : 'STANDARD'}',
      'DTSTART:${_wall(wall)}',
      'TZOFFSETFROM:${_offset(from.offset)}',
      'TZOFFSETTO:${_offset(to.offset)}',
      'TZNAME:${_text(to.abbreviation)}',
      if (rule != null) 'RRULE:$rule',
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
    final rules = first.rule.icalRules;
    if (rules != null) {
      for (final rule in rules) {
        final start = group
            .where((entry) => rule.matches(entry.wall))
            .firstOrNull;
        if (start == null) continue;
        observance(start.from, start.to, start.wall, rule: rule.text);
      }
    } else {
      // Every Gregorian date rule repeats after 400 years. Unusual Julian or
      // boundary-crossing rules can use one recurring observance per phase,
      // without enumerating the rest of iCalendar's representable lifetime.
      final end = DateTime.utc(
        first.wall.year + 400,
        first.wall.month,
        first.wall.day,
        first.wall.hour,
        first.wall.minute,
        first.wall.second,
      );
      for (final entry in group.where((entry) => entry.wall.isBefore(end))) {
        observance(
          entry.from,
          entry.to,
          entry.wall,
          rule:
              'FREQ=YEARLY;INTERVAL=400;BYMONTH=${entry.wall.month}'
              ';BYMONTHDAY=${entry.wall.day}',
        );
      }
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
    final source = tzContinuations2026f[zone];
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
    // One full Gregorian cycle includes every phase needed by compact rules,
    // including rare transitions that move into an adjacent month.
    final lastYear = (lastAt.year + 400).clamp(1, 9999);
    for (var year = lastAt.year; year <= lastYear; year++) {
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

  List<_IcalRulePart>? get icalRules {
    final match = RegExp(r'^M(\d{1,2})\.(\d)\.(\d)$').firstMatch(date);
    if (match == null) return null;
    final month = int.parse(match.group(1)!);
    final week = int.parse(match.group(2)!);
    final dayShift = (seconds / 86400).floor();
    final clock = seconds % 86400;
    final day = (int.parse(match.group(3)!) + dayShift) % 7;
    final weekday = const ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'][day];
    final time =
        ';BYHOUR=${clock ~/ 3600};BYMINUTE=${clock ~/ 60 % 60};BYSECOND=${clock % 60}';
    if (dayShift == 0) {
      return [
        _IcalRulePart(
          'FREQ=YEARLY;BYMONTH=$month;BYDAY=${week == 5 ? -1 : week}$weekday$time',
          month,
          const [],
        ),
      ];
    }
    final minimumDays = DateTime.utc(2001, month + 1, 0).day;
    final parts = <_IcalRulePart>[];
    void part(int targetMonth, List<int> days) {
      if (days.isEmpty) return;
      parts.add(
        _IcalRulePart(
          'FREQ=YEARLY;BYMONTH=$targetMonth;BYMONTHDAY=${days.join(',')};BYDAY=$weekday$time',
          targetMonth,
          days,
        ),
      );
    }

    // Shift the seven-day window selecting the POSIX weekday, keeping a last
    // weekday relative to month end. Split windows crossing a month boundary.
    final low = (week == 5 ? -7 : 1 + (week - 1) * 7) + dayShift;
    final high = low + 6;
    if (week == 5) {
      if (low < -minimumDays || high >= minimumDays) return null;
      part(month, [for (var d = low; d <= high && d < 0; d++) d]);
      part(month % 12 + 1, [
        for (var d = low < 0 ? 0 : low; d <= high; d++) d + 1,
      ]);
    } else {
      if (low < -minimumDays || high > minimumDays) return null;
      part((month + 10) % 12 + 1, [
        for (var d = low; d <= high && d <= 0; d++) d - 1,
      ]);
      part(month, [for (var d = low < 1 ? 1 : low; d <= high; d++) d]);
    }
    return parts;
  }
}

final class _IcalRulePart {
  const _IcalRulePart(this.text, this.month, this.days);
  final String text;
  final int month;
  final List<int> days;

  bool matches(DateTime wall) =>
      wall.month == month &&
      (days.isEmpty ||
          days.any(
            (day) =>
                wall.day ==
                (day > 0
                    ? day
                    : DateTime.utc(wall.year, wall.month + 1, 0).day + day + 1),
          ));
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

String _text(String value) => value
    .replaceAll('\\', r'\\')
    .replaceAll('\r', '')
    .replaceAll('\n', r'\n')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,');
