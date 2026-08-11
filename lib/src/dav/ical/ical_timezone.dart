import 'package:timezone/data/latest_all.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../dav_errors.dart';
import 'ical_document.dart';
import 'ical_semantics.dart';

/// Resolves native iCalendar temporal values without flattening their wire
/// representation. Embedded VTIMEZONE definitions take precedence over the
/// bundled IANA database so provider-supplied custom zone identifiers and
/// historical rules remain meaningful during occurrence projection.
final class IcalTimeZoneResolver {
  IcalTimeZoneResolver._(this._zones) {
    time_zone_data.initializeTimeZones();
  }

  factory IcalTimeZoneResolver.fromDocument(IcalSemanticDocument document) {
    final zones = <String, _TimeZoneDefinition>{};
    for (final component in document.timeZones) {
      final definition = _TimeZoneDefinition.parse(component);
      if (zones.containsKey(definition.id)) {
        throw _invalidTimeZone('IcalDuplicateTimeZone');
      }
      zones[definition.id] = definition;
    }
    return IcalTimeZoneResolver._(Map.unmodifiable(zones));
  }

  factory IcalTimeZoneResolver.system() =>
      IcalTimeZoneResolver._(const <String, _TimeZoneDefinition>{});

  final Map<String, _TimeZoneDefinition> _zones;

  DateTime toUtc(IcalTemporalValue value) {
    if (value.kind == IcalTemporalKind.utcDateTime) {
      return value.localValue.toUtc();
    }
    if (value.kind == IcalTemporalKind.tzidDateTime) {
      final id = value.timeZoneId;
      if (id == null || id.isEmpty) throw _invalidTimeZone();
      final embedded = _zones[id];
      if (embedded != null) {
        return embedded.toUtc(value.localValue);
      }
      try {
        final location = time_zone.getLocation(id);
        final wall = value.localValue;
        return time_zone.TZDateTime(
          location,
          wall.year,
          wall.month,
          wall.day,
          wall.hour,
          wall.minute,
          wall.second,
        ).toUtc();
      } on time_zone.LocationNotFoundException {
        throw const DavException(
          kind: DavErrorKind.unsupportedComponent,
          code: 'IcalUnknownTimeZone',
          safeMessage:
              'An iCalendar value used a time zone that could not be resolved.',
        );
      }
    }
    final wall = value.localValue;
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    );
  }
}

final class _TimeZoneDefinition {
  const _TimeZoneDefinition({required this.id, required this.observances});

  factory _TimeZoneDefinition.parse(IcalComponent component) {
    final id = component.firstProperty('TZID')?.decodedTextValue.trim();
    if (id == null || id.isEmpty) throw _invalidTimeZone();
    final observances = <_TimeZoneObservance>[];
    for (final child in component.components) {
      if (child.name != 'STANDARD' && child.name != 'DAYLIGHT') continue;
      observances.add(_TimeZoneObservance.parse(child));
    }
    if (observances.isEmpty) throw _invalidTimeZone();
    return _TimeZoneDefinition(
      id: id,
      observances: List.unmodifiable(observances),
    );
  }

  final String id;
  final List<_TimeZoneObservance> observances;

  DateTime toUtc(DateTime wall) {
    final transitions = <_TimeZoneTransition>[];
    for (final observance in observances) {
      transitions.addAll(observance.transitionsThrough(wall.year + 1));
    }
    if (transitions.isEmpty) throw _invalidTimeZone();
    transitions.sort((left, right) => left.localAt.compareTo(right.localAt));
    _TimeZoneTransition? effective;
    for (final transition in transitions) {
      if (transition.localAt.isAfter(wall)) break;
      effective = transition;
    }
    final offset = effective?.offsetTo ?? transitions.first.offsetFrom;
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    ).subtract(offset);
  }
}

final class _TimeZoneObservance {
  const _TimeZoneObservance({
    required this.start,
    required this.offsetFrom,
    required this.offsetTo,
    required this.rule,
    required this.additionalDates,
  });

  factory _TimeZoneObservance.parse(IcalComponent component) {
    final startProperty = component.firstProperty('DTSTART');
    final from = component.firstProperty('TZOFFSETFROM')?.rawValue.trim();
    final to = component.firstProperty('TZOFFSETTO')?.rawValue.trim();
    if (startProperty == null || from == null || to == null) {
      throw _invalidTimeZone();
    }
    final temporal = parseIcalTemporal(startProperty);
    if (temporal == null ||
        temporal.kind != IcalTemporalKind.floatingDateTime) {
      throw _invalidTimeZone();
    }
    final rules = component.propertiesNamed('RRULE').toList(growable: false);
    if (rules.length > 1) throw _invalidTimeZone();
    final dates = <DateTime>[];
    for (final property in component.propertiesNamed('RDATE')) {
      for (final token in property.rawValue.split(',')) {
        if (token.contains('/')) throw _unsupportedTimeZoneRule();
        final parsed = parseIcalTemporal(
          IcalProperty(
            group: null,
            name: 'RDATE',
            parameters: property.parameters,
            rawValue: token.trim(),
            originalPhysicalLines: const [],
          ),
        );
        if (parsed == null ||
            parsed.kind != IcalTemporalKind.floatingDateTime) {
          throw _invalidTimeZone();
        }
        dates.add(parsed.localValue);
      }
    }
    return _TimeZoneObservance(
      start: temporal.localValue,
      offsetFrom: _parseUtcOffset(from),
      offsetTo: _parseUtcOffset(to),
      rule: rules.isEmpty ? null : _TimeZoneYearlyRule.parse(rules.single),
      additionalDates: List.unmodifiable(dates),
    );
  }

  final DateTime start;
  final Duration offsetFrom;
  final Duration offsetTo;
  final _TimeZoneYearlyRule? rule;
  final List<DateTime> additionalDates;

  List<_TimeZoneTransition> transitionsThrough(int lastYear) {
    final values = <DateTime>{start, ...additionalDates};
    final yearlyRule = rule;
    if (yearlyRule != null) {
      if (lastYear - start.year > 1000) {
        throw const DavException(
          kind: DavErrorKind.limitExceeded,
          code: 'IcalTimeZoneTransitionLimitExceeded',
          safeMessage:
              'An embedded time zone exceeded the safe transition limit.',
        );
      }
      var emitted = 0;
      var stop = false;
      for (var year = start.year; year <= lastYear && !stop; year += 1) {
        if ((year - start.year) % yearlyRule.interval != 0) continue;
        for (final candidate in yearlyRule.candidates(start, year)) {
          if (candidate.isBefore(start)) continue;
          if (yearlyRule.isAfterUntil(candidate, offsetFrom)) {
            stop = true;
            break;
          }
          emitted += 1;
          if (yearlyRule.count != null && emitted > yearlyRule.count!) {
            stop = true;
            break;
          }
          values.add(candidate);
          if (values.length > 4096) {
            throw const DavException(
              kind: DavErrorKind.limitExceeded,
              code: 'IcalTimeZoneTransitionLimitExceeded',
              safeMessage:
                  'An embedded time zone exceeded the safe transition limit.',
            );
          }
        }
      }
    }
    return [
      for (final value in values)
        if (value.year <= lastYear)
          _TimeZoneTransition(
            localAt: value,
            offsetFrom: offsetFrom,
            offsetTo: offsetTo,
          ),
    ];
  }
}

final class _TimeZoneTransition {
  const _TimeZoneTransition({
    required this.localAt,
    required this.offsetFrom,
    required this.offsetTo,
  });

  final DateTime localAt;
  final Duration offsetFrom;
  final Duration offsetTo;
}

final class _TimeZoneYearlyRule {
  const _TimeZoneYearlyRule({
    required this.interval,
    required this.count,
    required this.until,
    required this.untilIsUtc,
    required this.months,
    required this.monthDays,
    required this.weekDays,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.setPositions,
  });

  factory _TimeZoneYearlyRule.parse(IcalProperty property) {
    final fields = <String, String>{};
    for (final segment in property.rawValue.split(';')) {
      final separator = segment.indexOf('=');
      if (separator <= 0 || separator == segment.length - 1) {
        throw _invalidTimeZone();
      }
      final name = segment.substring(0, separator).toUpperCase();
      if (fields.containsKey(name)) throw _invalidTimeZone();
      fields[name] = segment.substring(separator + 1).toUpperCase();
    }
    const supported = {
      'FREQ',
      'UNTIL',
      'COUNT',
      'INTERVAL',
      'BYMONTH',
      'BYMONTHDAY',
      'BYDAY',
      'BYHOUR',
      'BYMINUTE',
      'BYSECOND',
      'BYSETPOS',
      'WKST',
    };
    if (fields.keys.any((key) => !supported.contains(key)) ||
        fields['FREQ'] != 'YEARLY') {
      throw _unsupportedTimeZoneRule();
    }
    final untilSource = fields['UNTIL'];
    final until = untilSource == null
        ? null
        : _parseRuleDateTime(untilSource.replaceFirst(RegExp(r'Z$'), ''));
    return _TimeZoneYearlyRule(
      interval: _positive(fields['INTERVAL']) ?? 1,
      count: _positive(fields['COUNT']),
      until: until,
      untilIsUtc: untilSource?.endsWith('Z') ?? false,
      months: _integers(fields['BYMONTH'], 1, 12),
      monthDays: _integers(fields['BYMONTHDAY'], -31, 31, noZero: true),
      weekDays: _weekDays(fields['BYDAY']),
      hours: _integers(fields['BYHOUR'], 0, 23),
      minutes: _integers(fields['BYMINUTE'], 0, 59),
      seconds: _integers(fields['BYSECOND'], 0, 59),
      setPositions: _integers(fields['BYSETPOS'], -366, 366, noZero: true),
    );
  }

  final int interval;
  final int? count;
  final DateTime? until;
  final bool untilIsUtc;
  final List<int> months;
  final List<int> monthDays;
  final List<_TimeZoneWeekDay> weekDays;
  final List<int> hours;
  final List<int> minutes;
  final List<int> seconds;
  final List<int> setPositions;

  List<DateTime> candidates(DateTime prototype, int year) {
    final result = <DateTime>[];
    final selectedMonths = months.isEmpty ? [prototype.month] : months;
    for (final month in selectedMonths) {
      final days = _candidateDays(prototype, year, month);
      final selectedHours = hours.isEmpty ? [prototype.hour] : hours;
      final selectedMinutes = minutes.isEmpty ? [prototype.minute] : minutes;
      final selectedSeconds = seconds.isEmpty ? [prototype.second] : seconds;
      for (final day in days) {
        for (final hour in selectedHours) {
          for (final minute in selectedMinutes) {
            for (final second in selectedSeconds) {
              result.add(DateTime.utc(year, month, day, hour, minute, second));
            }
          }
        }
      }
    }
    result.sort();
    if (setPositions.isEmpty) return result;
    final selected = <DateTime>[];
    for (final position in setPositions) {
      final index = position > 0 ? position - 1 : result.length + position;
      if (index >= 0 && index < result.length) selected.add(result[index]);
    }
    return selected;
  }

  List<int> _candidateDays(DateTime prototype, int year, int month) {
    final maximum = _daysInMonth(year, month);
    Iterable<int> values;
    if (monthDays.isNotEmpty) {
      values = monthDays.map((day) => day > 0 ? day : maximum + day + 1);
    } else if (weekDays.isNotEmpty) {
      final days = <int>[];
      for (final weekDay in weekDays) {
        if (weekDay.ordinal == null) {
          for (var day = 1; day <= maximum; day += 1) {
            if (DateTime.utc(year, month, day).weekday == weekDay.weekday) {
              days.add(day);
            }
          }
        } else {
          final day = _ordinalWeekDay(
            year,
            month,
            weekDay.weekday,
            weekDay.ordinal!,
          );
          if (day != null) days.add(day);
        }
      }
      values = days;
    } else {
      values = [prototype.day];
    }
    final filtered =
        values
            .where((day) => day >= 1 && day <= maximum)
            .where(
              (day) =>
                  weekDays.isEmpty ||
                  weekDays.any(
                    (rule) =>
                        DateTime.utc(year, month, day).weekday == rule.weekday,
                  ),
            )
            .toSet()
            .toList()
          ..sort();
    return filtered;
  }

  bool isAfterUntil(DateTime local, Duration offsetFrom) {
    final limit = until;
    if (limit == null) return false;
    if (!untilIsUtc) return local.isAfter(limit);
    final instant = local.subtract(offsetFrom);
    return instant.isAfter(limit);
  }
}

final class _TimeZoneWeekDay {
  const _TimeZoneWeekDay(this.ordinal, this.weekday);

  final int? ordinal;
  final int weekday;
}

Duration _parseUtcOffset(String source) {
  final match = RegExp(r'^([+-])(\d{2})(\d{2})(\d{2})?$').firstMatch(source);
  if (match == null) throw _invalidTimeZone();
  final hours = int.parse(match.group(2)!);
  final minutes = int.parse(match.group(3)!);
  final seconds = int.tryParse(match.group(4) ?? '') ?? 0;
  if (hours > 23 || minutes > 59 || seconds > 59) {
    throw _invalidTimeZone();
  }
  final total = Duration(hours: hours, minutes: minutes, seconds: seconds);
  return match.group(1) == '-' ? -total : total;
}

List<int> _integers(
  String? source,
  int minimum,
  int maximum, {
  bool noZero = false,
}) {
  if (source == null) return const [];
  final result = <int>[];
  for (final token in source.split(',')) {
    final value = int.tryParse(token);
    if (value == null ||
        value < minimum ||
        value > maximum ||
        (noZero && value == 0)) {
      throw _invalidTimeZone();
    }
    result.add(value);
    if (result.length > 366) throw _unsupportedTimeZoneRule();
  }
  return List.unmodifiable(result);
}

int? _positive(String? source) {
  if (source == null) return null;
  final value = int.tryParse(source);
  if (value == null || value <= 0) throw _invalidTimeZone();
  return value;
}

List<_TimeZoneWeekDay> _weekDays(String? source) {
  if (source == null) return const [];
  final result = <_TimeZoneWeekDay>[];
  const weekdays = {
    'MO': DateTime.monday,
    'TU': DateTime.tuesday,
    'WE': DateTime.wednesday,
    'TH': DateTime.thursday,
    'FR': DateTime.friday,
    'SA': DateTime.saturday,
    'SU': DateTime.sunday,
  };
  for (final token in source.split(',')) {
    final match = RegExp(r'^([+-]?\d{1,2})?([A-Z]{2})$').firstMatch(token);
    final weekday = match == null ? null : weekdays[match.group(2)];
    final ordinal = int.tryParse(match?.group(1) ?? '');
    if (weekday == null || ordinal == 0 || (ordinal?.abs() ?? 0) > 53) {
      throw _invalidTimeZone();
    }
    result.add(_TimeZoneWeekDay(ordinal, weekday));
  }
  return List.unmodifiable(result);
}

int? _ordinalWeekDay(int year, int month, int weekday, int ordinal) {
  final maximum = _daysInMonth(year, month);
  if (ordinal > 0) {
    final firstWeekday = DateTime.utc(year, month).weekday;
    final first = 1 + (weekday - firstWeekday) % 7;
    final day = first + (ordinal - 1) * 7;
    return day <= maximum ? day : null;
  }
  final lastWeekday = DateTime.utc(year, month, maximum).weekday;
  final last = maximum - (lastWeekday - weekday) % 7;
  final day = last + (ordinal + 1) * 7;
  return day >= 1 ? day : null;
}

int _daysInMonth(int year, int month) =>
    DateTime.utc(year, month + 1).subtract(const Duration(days: 1)).day;

DateTime _parseRuleDateTime(String source) {
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$',
  ).firstMatch(source);
  if (match == null) throw _invalidTimeZone();
  final parts = [
    for (var index = 1; index <= 6; index += 1) int.parse(match.group(index)!),
  ];
  final value = DateTime.utc(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  if (value.year != parts[0] ||
      value.month != parts[1] ||
      value.day != parts[2] ||
      value.hour != parts[3] ||
      value.minute != parts[4] ||
      value.second != parts[5]) {
    throw _invalidTimeZone();
  }
  return value;
}

DavException _invalidTimeZone([
  String code = 'IcalInvalidTimeZoneDefinition',
]) => DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: code,
  safeMessage: 'An embedded iCalendar time zone was invalid.',
);

DavException _unsupportedTimeZoneRule() => const DavException(
  kind: DavErrorKind.unsupportedComponent,
  code: 'IcalUnsupportedTimeZoneRule',
  safeMessage: 'An embedded iCalendar time zone used an unsupported rule.',
);
