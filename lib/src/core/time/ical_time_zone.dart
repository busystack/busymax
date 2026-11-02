import 'package:timezone/timezone.dart' as tz;

import 'provider_date_time.dart';
import 'windows_time_zone_ids.dart';
import 'tz_continuations_2025c.dart';

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
  final minutes = value.inMinutes;
  final absolute = minutes.abs();
  return '${minutes < 0 ? '-' : '+'}${(absolute ~/ 60).toString().padLeft(2, '0')}'
      '${(absolute % 60).toString().padLeft(2, '0')}';
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
