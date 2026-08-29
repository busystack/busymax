import 'dart:math' as math;

import '../dav_errors.dart';
import 'ical_document.dart';
import 'ical_semantics.dart';
import 'ical_timezone.dart';

const icalOccurrenceProjectionVersion = 1;

final class IcalRecurrenceLimits {
  const IcalRecurrenceLimits({
    this.maximumOccurrences = 10000,
    this.maximumPeriods = 1000000,
    this.maximumRuleValues = 1024,
    this.maximumProjectionRange = const Duration(days: 366 * 20),
  });

  final int maximumOccurrences;
  final int maximumPeriods;
  final int maximumRuleValues;
  final Duration maximumProjectionRange;
}

/// One projected occurrence. [recurrenceId] is the original scheduled start;
/// [start] may differ when an exception moves the occurrence.
final class IcalOccurrence {
  const IcalOccurrence({
    required this.master,
    required this.override,
    required this.inheritedOverride,
    required this.recurrenceId,
    required this.start,
    required this.end,
    required this.occurrenceKey,
  });

  final IcalSemanticComponent master;
  final IcalSemanticComponent? override;
  final IcalSemanticComponent? inheritedOverride;
  final IcalTemporalValue recurrenceId;
  final IcalTemporalValue start;
  final IcalTemporalValue? end;
  final String occurrenceKey;

  IcalSemanticComponent get effectiveComponent =>
      override ?? inheritedOverride ?? master;
  IcalSemanticComponent get identityComponent => override ?? master;
  bool get isException => override != null;
  bool get isCancelled =>
      override?.isCancelled ??
      inheritedOverride?.isCancelled ??
      master.isCancelled;

  String? get summary =>
      override?.summary ?? inheritedOverride?.summary ?? master.summary;
  String? get description =>
      override?.description ??
      inheritedOverride?.description ??
      master.description;
  String? get location =>
      override?.location ?? inheritedOverride?.location ?? master.location;
}

/// Expands an RFC 5545 recurrence set from its authoritative resource.
///
/// The expansion is deliberately range-bound and count-bound. Native DATE,
/// floating, UTC, and TZID wall-clock forms remain intact in the returned
/// values; TZID comparisons use the bundled IANA database when possible.
final class IcalRecurrenceExpander {
  IcalRecurrenceExpander({this.limits = const IcalRecurrenceLimits()});

  final IcalRecurrenceLimits limits;

  /// Returns the next RRULE occurrence after [current].
  ///
  /// Nextcloud Tasks advances a recurring VTODO from its current DTSTART or
  /// DUE and its first RRULE. This helper follows that same rule-local
  /// iteration model without imposing a calendar projection window.
  IcalTemporalValue? nextTaskOccurrence(
    IcalSemanticDocument document, {
    required IcalTemporalValue current,
    required String recurrenceRule,
  }) {
    final resolver = IcalTimeZoneResolver.fromDocument(document);
    final rule = _RecurrenceRule.parse(
      recurrenceRule,
      anchor: current,
      maximumValues: limits.maximumRuleValues,
    );
    var generatedForCount = 0;
    for (var period = 0; period < limits.maximumPeriods; period += 1) {
      final candidates = rule.candidatesForPeriod(current.localValue, period);
      for (final wallValue in candidates) {
        if (wallValue.isBefore(current.localValue)) continue;
        final value = _withWallValue(current, wallValue);
        if (rule.until != null && _afterUntil(value, rule.until!, resolver)) {
          return null;
        }
        generatedForCount += 1;
        if (rule.count != null && generatedForCount > rule.count!) return null;
        if (wallValue.isAfter(current.localValue)) return value;
      }
    }
    throw _limitError(
      'IcalRecurrenceIterationLimitExceeded',
      'A recurrence rule exceeded the safe expansion limit.',
    );
  }

  List<IcalOccurrence> expand(
    IcalSemanticDocument document, {
    required DateTime rangeStartUtc,
    required DateTime rangeEndUtc,
  }) {
    final rangeStart = rangeStartUtc.toUtc();
    final rangeEnd = rangeEndUtc.toUtc();
    if (!rangeEnd.isAfter(rangeStart)) {
      throw ArgumentError('The recurrence projection range must be positive.');
    }
    if (rangeEnd.difference(rangeStart) > limits.maximumProjectionRange) {
      throw _limitError(
        'IcalProjectionRangeLimitExceeded',
        'The requested recurrence projection range is too large.',
      );
    }
    final timeZoneResolver = IcalTimeZoneResolver.fromDocument(document);

    final masters = document.components
        .where((component) => component.recurrenceId == null)
        .toList(growable: false);
    if (masters.length != 1) {
      throw const DavException(
        kind: DavErrorKind.invalidCalendarData,
        code: 'IcalRecurrenceMasterInvariantFailed',
        safeMessage: 'A recurrence set must contain exactly one master.',
      );
    }
    final master = masters.single;
    final anchor = master.start ?? master.due;
    if (anchor == null) return const [];

    final starts = <String, IcalTemporalValue>{
      _temporalIdentity(anchor): anchor,
    };
    for (final ruleText in master.recurrenceRules) {
      final rule = _RecurrenceRule.parse(
        ruleText,
        anchor: anchor,
        maximumValues: limits.maximumRuleValues,
      );
      _addRuleStarts(starts, rule, anchor, rangeEnd, timeZoneResolver);
    }
    for (final property in master.documentComponent.propertiesNamed('RDATE')) {
      for (final value in _parseDateList(property, anchor)) {
        starts[_temporalIdentity(value)] = value;
      }
    }
    for (final property in master.documentComponent.propertiesNamed('EXDATE')) {
      for (final value in _parseDateList(property, anchor)) {
        starts.remove(_temporalIdentity(value));
      }
    }

    final overrides = <String, IcalSemanticComponent>{};
    for (final component in document.components) {
      final recurrenceId = component.recurrenceId;
      if (recurrenceId == null) continue;
      final key = _temporalIdentity(recurrenceId);
      if (overrides.containsKey(key)) {
        throw const DavException(
          kind: DavErrorKind.invalidCalendarData,
          code: 'IcalDuplicateRecurrenceId',
          safeMessage:
              'A recurrence set contains duplicate recurrence exceptions.',
        );
      }
      overrides[key] = component;
      // Retain detached exceptions even when a malformed or changed server
      // rule no longer generates their original RECURRENCE-ID.
      starts.putIfAbsent(key, () => recurrenceId);
    }

    final rangeOverrides =
        overrides.values
            .where((component) => component.recurrenceRange == 'THISANDFUTURE')
            .toList(growable: false)
          ..sort((left, right) => _compareRecurrenceIds(left, right));

    if (starts.length > limits.maximumOccurrences) {
      throw _occurrenceLimitError();
    }
    final masterDuration = _componentDuration(master, timeZoneResolver);
    final result = <IcalOccurrence>[];
    for (final entry in starts.entries) {
      final originalStart = entry.value;
      final exception = overrides[entry.key];
      final inheritedOverride = exception == null
          ? _rangeOverrideFor(originalStart, rangeOverrides)
          : null;
      final effectiveStart =
          exception?.start ??
          exception?.due ??
          _rangeAdjustedStart(originalStart, inheritedOverride) ??
          originalStart;
      final effectiveEnd = exception != null
          ? _occurrenceEnd(exception, effectiveStart, masterDuration)
          : _rangeOccurrenceEnd(
              inheritedOverride,
              effectiveStart,
              masterDuration,
              timeZoneResolver,
            );
      if (!_overlaps(
        effectiveStart,
        effectiveEnd,
        rangeStart,
        rangeEnd,
        timeZoneResolver,
      )) {
        continue;
      }
      result.add(
        IcalOccurrence(
          master: master,
          override: exception,
          inheritedOverride: inheritedOverride,
          recurrenceId: originalStart,
          start: effectiveStart,
          end: effectiveEnd,
          occurrenceKey: entry.key,
        ),
      );
      if (result.length > limits.maximumOccurrences) {
        throw _occurrenceLimitError();
      }
    }
    result.sort(
      (left, right) => icalTemporalToUtc(
        left.start,
        resolver: timeZoneResolver,
      ).compareTo(icalTemporalToUtc(right.start, resolver: timeZoneResolver)),
    );
    return List.unmodifiable(result);
  }

  void _addRuleStarts(
    Map<String, IcalTemporalValue> starts,
    _RecurrenceRule rule,
    IcalTemporalValue anchor,
    DateTime rangeEndUtc,
    IcalTimeZoneResolver timeZoneResolver,
  ) {
    var generatedForCount = 0;
    var reachedEnd = false;
    for (var period = 0; period < limits.maximumPeriods; period += 1) {
      final candidates = rule.candidatesForPeriod(anchor.localValue, period);
      if (candidates.isEmpty &&
          rule.periodStartsAfter(
            period,
            rangeEndUtc,
            anchor,
            timeZoneResolver,
          )) {
        reachedEnd = true;
        break;
      }
      for (final wallValue in candidates) {
        if (wallValue.isBefore(anchor.localValue)) continue;
        final value = _withWallValue(anchor, wallValue);
        if (rule.until != null &&
            _afterUntil(value, rule.until!, timeZoneResolver)) {
          reachedEnd = true;
          break;
        }
        generatedForCount += 1;
        if (rule.count != null && generatedForCount > rule.count!) {
          reachedEnd = true;
          break;
        }
        starts[_temporalIdentity(value)] = value;
        if (starts.length > limits.maximumOccurrences) {
          throw _occurrenceLimitError();
        }
      }
      if (reachedEnd) break;
      if (rule.periodStartsAfter(
        period + 1,
        rangeEndUtc,
        anchor,
        timeZoneResolver,
      )) {
        reachedEnd = true;
        break;
      }
    }
    if (!reachedEnd) {
      throw _limitError(
        'IcalRecurrenceIterationLimitExceeded',
        'A recurrence rule exceeded the safe expansion limit.',
      );
    }
  }
}

enum _Frequency { secondly, minutely, hourly, daily, weekly, monthly, yearly }

final class _ByDay {
  const _ByDay(this.ordinal, this.weekday);

  final int? ordinal;
  final int weekday;
}

final class _RecurrenceRule {
  _RecurrenceRule({
    required this.frequency,
    required this.interval,
    required this.count,
    required this.until,
    required this.weekStart,
    required this.bySecond,
    required this.byMinute,
    required this.byHour,
    required this.byDay,
    required this.byMonthDay,
    required this.byYearDay,
    required this.byWeekNumber,
    required this.byMonth,
    required this.bySetPosition,
  });

  factory _RecurrenceRule.parse(
    String source, {
    required IcalTemporalValue anchor,
    required int maximumValues,
  }) {
    final values = <String, String>{};
    for (final segment in source.split(';')) {
      final separator = segment.indexOf('=');
      if (separator <= 0 || separator == segment.length - 1) {
        throw _invalidRule();
      }
      final key = segment.substring(0, separator).toUpperCase();
      if (values.containsKey(key)) throw _invalidRule();
      values[key] = segment.substring(separator + 1).toUpperCase();
    }
    const supported = {
      'FREQ',
      'UNTIL',
      'COUNT',
      'INTERVAL',
      'BYSECOND',
      'BYMINUTE',
      'BYHOUR',
      'BYDAY',
      'BYMONTHDAY',
      'BYYEARDAY',
      'BYWEEKNO',
      'BYMONTH',
      'BYSETPOS',
      'WKST',
    };
    if (values.keys.any((key) => !supported.contains(key))) {
      throw const DavException(
        kind: DavErrorKind.unsupportedComponent,
        code: 'IcalUnsupportedRecurrencePart',
        safeMessage: 'The recurrence rule uses an unsupported rule part.',
      );
    }
    final frequency = switch (values['FREQ']) {
      'SECONDLY' => _Frequency.secondly,
      'MINUTELY' => _Frequency.minutely,
      'HOURLY' => _Frequency.hourly,
      'DAILY' => _Frequency.daily,
      'WEEKLY' => _Frequency.weekly,
      'MONTHLY' => _Frequency.monthly,
      'YEARLY' => _Frequency.yearly,
      _ => throw _invalidRule(),
    };
    final count = _positiveInteger(values['COUNT']);
    if (count != null && values.containsKey('UNTIL')) throw _invalidRule();
    final interval = _positiveInteger(values['INTERVAL']) ?? 1;
    final byDay = _parseByDay(values['BYDAY'], maximumValues);
    if (frequency == _Frequency.weekly &&
        byDay.any((day) => day.ordinal != null)) {
      throw _invalidRule();
    }
    return _RecurrenceRule(
      frequency: frequency,
      interval: interval,
      count: count,
      until: values['UNTIL'] == null
          ? null
          : _parseTemporalToken(values['UNTIL']!, anchor),
      weekStart: _weekday(values['WKST'] ?? 'MO'),
      bySecond: _integerList(
        values['BYSECOND'],
        minimum: 0,
        maximum: 59,
        maximumValues: maximumValues,
      ),
      byMinute: _integerList(
        values['BYMINUTE'],
        minimum: 0,
        maximum: 59,
        maximumValues: maximumValues,
      ),
      byHour: _integerList(
        values['BYHOUR'],
        minimum: 0,
        maximum: 23,
        maximumValues: maximumValues,
      ),
      byDay: byDay,
      byMonthDay: _integerList(
        values['BYMONTHDAY'],
        minimum: -31,
        maximum: 31,
        disallowZero: true,
        maximumValues: maximumValues,
      ),
      byYearDay: _integerList(
        values['BYYEARDAY'],
        minimum: -366,
        maximum: 366,
        disallowZero: true,
        maximumValues: maximumValues,
      ),
      byWeekNumber: _integerList(
        values['BYWEEKNO'],
        minimum: -53,
        maximum: 53,
        disallowZero: true,
        maximumValues: maximumValues,
      ),
      byMonth: _integerList(
        values['BYMONTH'],
        minimum: 1,
        maximum: 12,
        maximumValues: maximumValues,
      ),
      bySetPosition: _integerList(
        values['BYSETPOS'],
        minimum: -366,
        maximum: 366,
        disallowZero: true,
        maximumValues: maximumValues,
      ),
    );
  }

  final _Frequency frequency;
  final int interval;
  final int? count;
  final IcalTemporalValue? until;
  final int weekStart;
  final List<int> bySecond;
  final List<int> byMinute;
  final List<int> byHour;
  final List<_ByDay> byDay;
  final List<int> byMonthDay;
  final List<int> byYearDay;
  final List<int> byWeekNumber;
  final List<int> byMonth;
  final List<int> bySetPosition;

  List<DateTime> candidatesForPeriod(DateTime start, int period) {
    final candidates = switch (frequency) {
      _Frequency.secondly => _secondCandidates(start, period),
      _Frequency.minutely => _minuteCandidates(start, period),
      _Frequency.hourly => _hourCandidates(start, period),
      _Frequency.daily => _dailyCandidates(start, period),
      _Frequency.weekly => _weeklyCandidates(start, period),
      _Frequency.monthly => _monthlyCandidates(start, period),
      _Frequency.yearly => _yearlyCandidates(start, period),
    };
    final filtered = candidates.where(_matchesAllFilters).toSet().toList()
      ..sort();
    if (bySetPosition.isEmpty) return filtered;
    final selected = <DateTime>{};
    for (final position in bySetPosition) {
      final index = position > 0 ? position - 1 : filtered.length + position;
      if (index >= 0 && index < filtered.length) selected.add(filtered[index]);
    }
    return selected.toList()..sort();
  }

  bool periodStartsAfter(
    int period,
    DateTime rangeEndUtc,
    IcalTemporalValue anchor,
    IcalTimeZoneResolver timeZoneResolver,
  ) {
    final wall = _periodAnchor(anchor.localValue, period);
    return icalTemporalToUtc(
      _withWallValue(anchor, wall),
      resolver: timeZoneResolver,
    ).isAfter(rangeEndUtc);
  }

  DateTime _periodAnchor(DateTime start, int period) => switch (frequency) {
    _Frequency.secondly => start.add(Duration(seconds: period * interval)),
    _Frequency.minutely => start.add(Duration(minutes: period * interval)),
    _Frequency.hourly => start.add(Duration(hours: period * interval)),
    _Frequency.daily => _addDays(start, period * interval),
    _Frequency.weekly => _addDays(start, period * interval * 7),
    _Frequency.monthly => _addMonths(start, period * interval),
    _Frequency.yearly => _addYears(start, period * interval),
  };

  List<DateTime> _secondCandidates(DateTime start, int period) => [
    _periodAnchor(start, period),
  ];

  List<DateTime> _minuteCandidates(DateTime start, int period) {
    final anchor = _periodAnchor(start, period);
    return [
      for (final second in bySecond.isEmpty ? [start.second] : bySecond)
        _wall(
          anchor.year,
          anchor.month,
          anchor.day,
          anchor.hour,
          anchor.minute,
          second,
        ),
    ];
  }

  List<DateTime> _hourCandidates(DateTime start, int period) {
    final anchor = _periodAnchor(start, period);
    return [
      for (final minute in byMinute.isEmpty ? [start.minute] : byMinute)
        for (final second in bySecond.isEmpty ? [start.second] : bySecond)
          _wall(
            anchor.year,
            anchor.month,
            anchor.day,
            anchor.hour,
            minute,
            second,
          ),
    ];
  }

  List<DateTime> _dailyCandidates(DateTime start, int period) {
    final date = _periodAnchor(start, period);
    return _timesForDate(date, start);
  }

  List<DateTime> _weeklyCandidates(DateTime start, int period) {
    final anchor = _periodAnchor(start, period);
    final week = _startOfWeek(anchor, weekStart);
    final weekdays = byDay.isEmpty
        ? [start.weekday]
        : byDay.map((value) => value.weekday).toSet().toList();
    return [
      for (final weekday in weekdays)
        ..._timesForDate(_addDays(week, (weekday - weekStart) % 7), start),
    ];
  }

  List<DateTime> _monthlyCandidates(DateTime start, int period) {
    final anchor = _periodAnchor(start, period);
    if (byMonth.isNotEmpty && !byMonth.contains(anchor.month)) return const [];
    return [
      for (final day in _monthDays(anchor.year, anchor.month, start.day))
        ..._timesForDate(_wall(anchor.year, anchor.month, day), start),
    ];
  }

  List<DateTime> _yearlyCandidates(DateTime start, int period) {
    final anchor = _periodAnchor(start, period);
    final year = anchor.year;
    final dates = <DateTime>[];
    if (byYearDay.isNotEmpty) {
      final days = _daysInYear(year);
      for (final value in byYearDay) {
        final day = value > 0 ? value : days + value + 1;
        if (day >= 1 && day <= days) {
          dates.add(_wall(year).add(Duration(days: day - 1)));
        }
      }
    } else if (byWeekNumber.isNotEmpty) {
      for (var day = 1; day <= _daysInYear(year); day += 1) {
        final date = _wall(year).add(Duration(days: day - 1));
        if (_matchesWeekNumber(date)) dates.add(date);
      }
    } else {
      final months = byMonth.isEmpty ? [start.month] : byMonth;
      for (final month in months) {
        for (final day in _monthDays(year, month, start.day)) {
          dates.add(_wall(year, month, day));
        }
      }
      if (byDay.isNotEmpty && byMonth.isEmpty) {
        dates
          ..clear()
          ..addAll([
            for (var day = 1; day <= _daysInYear(year); day += 1)
              if (_matchesByDayInYear(_wall(year).add(Duration(days: day - 1))))
                _wall(year).add(Duration(days: day - 1)),
          ]);
      }
    }
    return [for (final date in dates) ..._timesForDate(date, start)];
  }

  List<int> _monthDays(int year, int month, int defaultDay) {
    final days = _daysInMonth(year, month);
    final hasDaySelector = byMonthDay.isNotEmpty || byDay.isNotEmpty;
    if (!hasDaySelector) return defaultDay <= days ? [defaultDay] : const [];
    return [
      for (var day = 1; day <= days; day += 1)
        if (_matchesMonthDay(day, days) &&
            _matchesByDayInMonth(_wall(year, month, day)))
          day,
    ];
  }

  List<DateTime> _timesForDate(DateTime date, DateTime start) => [
    for (final hour in byHour.isEmpty ? [start.hour] : byHour)
      for (final minute in byMinute.isEmpty ? [start.minute] : byMinute)
        for (final second in bySecond.isEmpty ? [start.second] : bySecond)
          _wall(date.year, date.month, date.day, hour, minute, second),
  ];

  bool _matchesAllFilters(DateTime date) {
    if (byMonth.isNotEmpty && !byMonth.contains(date.month)) return false;
    if (!_matchesMonthDay(date.day, _daysInMonth(date.year, date.month))) {
      return false;
    }
    if (!_matchesYearDay(date)) return false;
    if (!_matchesWeekNumber(date)) return false;
    if (byHour.isNotEmpty && !byHour.contains(date.hour)) return false;
    if (byMinute.isNotEmpty && !byMinute.contains(date.minute)) return false;
    if (bySecond.isNotEmpty && !bySecond.contains(date.second)) return false;
    if (byDay.isEmpty) return true;
    return switch (frequency) {
      _Frequency.yearly when byMonth.isEmpty => _matchesByDayInYear(date),
      _Frequency.monthly || _Frequency.yearly => _matchesByDayInMonth(date),
      _ => byDay.any((value) => value.weekday == date.weekday),
    };
  }

  bool _matchesMonthDay(int day, int daysInMonth) {
    if (byMonthDay.isEmpty) return true;
    return byMonthDay.any(
      (value) => (value > 0 ? value : daysInMonth + value + 1) == day,
    );
  }

  bool _matchesYearDay(DateTime date) {
    if (byYearDay.isEmpty) return true;
    final ordinal = date.difference(_wall(date.year)).inDays + 1;
    final days = _daysInYear(date.year);
    return byYearDay.any(
      (value) => (value > 0 ? value : days + value + 1) == ordinal,
    );
  }

  bool _matchesWeekNumber(DateTime date) {
    if (byWeekNumber.isEmpty) return true;
    final week = _weekOfYear(date, weekStart);
    if (week.year != date.year) return false;
    final total = _weeksInYear(date.year, weekStart);
    return byWeekNumber.any(
      (value) => (value > 0 ? value : total + value + 1) == week.week,
    );
  }

  bool _matchesByDayInMonth(DateTime date) {
    if (byDay.isEmpty) return true;
    return byDay.any((selector) {
      if (selector.weekday != date.weekday) return false;
      final ordinal = selector.ordinal;
      if (ordinal == null) return true;
      if (ordinal > 0) return ((date.day - 1) ~/ 7) + 1 == ordinal;
      final days = _daysInMonth(date.year, date.month);
      return -(((days - date.day) ~/ 7) + 1) == ordinal;
    });
  }

  bool _matchesByDayInYear(DateTime date) {
    if (byDay.isEmpty) return true;
    return byDay.any((selector) {
      if (selector.weekday != date.weekday) return false;
      final ordinal = selector.ordinal;
      if (ordinal == null) return true;
      final day = date.difference(_wall(date.year)).inDays + 1;
      if (ordinal > 0) return ((day - 1) ~/ 7) + 1 == ordinal;
      final days = _daysInYear(date.year);
      return -(((days - day) ~/ 7) + 1) == ordinal;
    });
  }
}

List<IcalTemporalValue> _parseDateList(
  IcalProperty property,
  IcalTemporalValue anchor,
) {
  final result = <IcalTemporalValue>[];
  for (final rawEntry in property.rawValue.split(',')) {
    final rawStart = rawEntry.split('/').first.trim();
    if (rawStart.isEmpty) throw _invalidRule();
    final parameters = property.parameters.isEmpty
        ? _parametersForPrototype(anchor)
        : property.parameters;
    result.add(
      parseIcalTemporal(
        IcalProperty(
          group: null,
          name: property.name,
          parameters: parameters,
          rawValue: rawStart,
          originalPhysicalLines: const [],
        ),
      )!,
    );
  }
  return result;
}

List<IcalParameter> _parametersForPrototype(IcalTemporalValue prototype) =>
    switch (prototype.kind) {
      IcalTemporalKind.date => const [
        IcalParameter(name: 'VALUE', values: ['DATE'], wasQuoted: false),
      ],
      IcalTemporalKind.tzidDateTime => [
        IcalParameter(
          name: 'TZID',
          values: [prototype.timeZoneId!],
          wasQuoted: false,
        ),
      ],
      IcalTemporalKind.utcDateTime ||
      IcalTemporalKind.floatingDateTime => const [],
    };

IcalTemporalValue _parseTemporalToken(
  String source,
  IcalTemporalValue prototype,
) {
  final parameters = source.endsWith('Z')
      ? const <IcalParameter>[]
      : _parametersForPrototype(prototype);
  return parseIcalTemporal(
    IcalProperty(
      group: null,
      name: 'UNTIL',
      parameters: parameters,
      rawValue: source,
      originalPhysicalLines: const [],
    ),
  )!;
}

IcalTemporalValue _withWallValue(IcalTemporalValue prototype, DateTime wall) =>
    IcalTemporalValue(
      rawValue: _formatWallValue(wall, prototype.kind),
      kind: prototype.kind,
      localValue: wall,
      timeZoneId: prototype.timeZoneId,
    );

String _formatWallValue(DateTime value, IcalTemporalKind kind) {
  String two(int number) => number.toString().padLeft(2, '0');
  final date =
      '${value.year.toString().padLeft(4, '0')}'
      '${two(value.month)}${two(value.day)}';
  if (kind == IcalTemporalKind.date) return date;
  final dateTime =
      '${date}T${two(value.hour)}${two(value.minute)}'
      '${two(value.second)}';
  return kind == IcalTemporalKind.utcDateTime ? '${dateTime}Z' : dateTime;
}

String _temporalIdentity(IcalTemporalValue value) => switch (value.kind) {
  IcalTemporalKind.date => 'DATE:${value.rawValue}',
  IcalTemporalKind.floatingDateTime => 'FLOATING:${value.rawValue}',
  IcalTemporalKind.utcDateTime =>
    'UTC:${icalTemporalToUtc(value).toIso8601String()}',
  IcalTemporalKind.tzidDateTime => 'TZID=${value.timeZoneId}:${value.rawValue}',
};

Duration _componentDuration(
  IcalSemanticComponent component,
  IcalTimeZoneResolver timeZoneResolver,
) {
  if (component.duration != null) return component.duration!.duration;
  final start = component.start ?? component.due;
  final end = component.end;
  if (start == null || end == null) return Duration.zero;
  if (start.kind == IcalTemporalKind.tzidDateTime &&
      end.kind == IcalTemporalKind.tzidDateTime &&
      start.timeZoneId == end.timeZoneId) {
    return end.localValue.difference(start.localValue);
  }
  return icalTemporalToUtc(
    end,
    resolver: timeZoneResolver,
  ).difference(icalTemporalToUtc(start, resolver: timeZoneResolver));
}

IcalTemporalValue? _occurrenceEnd(
  IcalSemanticComponent? exception,
  IcalTemporalValue start,
  Duration masterDuration,
) {
  final explicitEnd = exception?.end;
  if (explicitEnd != null) return explicitEnd;
  final duration = exception?.duration?.duration ?? masterDuration;
  if (duration == Duration.zero) return null;
  return _withWallValue(start, start.localValue.add(duration));
}

int _compareRecurrenceIds(
  IcalSemanticComponent left,
  IcalSemanticComponent right,
) => left.recurrenceId!.localValue.compareTo(right.recurrenceId!.localValue);

IcalSemanticComponent? _rangeOverrideFor(
  IcalTemporalValue recurrenceId,
  List<IcalSemanticComponent> rangeOverrides,
) {
  IcalSemanticComponent? active;
  for (final candidate in rangeOverrides) {
    if (candidate.recurrenceId!.localValue.isAfter(recurrenceId.localValue)) {
      break;
    }
    active = candidate;
  }
  return active;
}

IcalTemporalValue? _rangeAdjustedStart(
  IcalTemporalValue originalStart,
  IcalSemanticComponent? rangeOverride,
) {
  final recurrenceId = rangeOverride?.recurrenceId;
  final rangeStart = rangeOverride?.start ?? rangeOverride?.due;
  if (recurrenceId == null || rangeStart == null) return null;
  final delta = _wallDateTime(
    rangeStart.localValue,
  ).difference(_wallDateTime(recurrenceId.localValue));
  return _withWallValue(
    rangeStart,
    _wallDateTime(originalStart.localValue).add(delta),
  );
}

IcalTemporalValue? _rangeOccurrenceEnd(
  IcalSemanticComponent? rangeOverride,
  IcalTemporalValue start,
  Duration masterDuration,
  IcalTimeZoneResolver timeZoneResolver,
) {
  final hasRangeDuration =
      rangeOverride?.duration != null || rangeOverride?.end != null;
  final duration = hasRangeDuration
      ? _componentDuration(rangeOverride!, timeZoneResolver)
      : masterDuration;
  if (duration == Duration.zero) return null;
  return _withWallValue(start, start.localValue.add(duration));
}

DateTime _wallDateTime(DateTime value) => DateTime.utc(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
  value.second,
  value.millisecond,
  value.microsecond,
);

bool _overlaps(
  IcalTemporalValue start,
  IcalTemporalValue? end,
  DateTime rangeStartUtc,
  DateTime rangeEndUtc,
  IcalTimeZoneResolver timeZoneResolver,
) {
  final startInstant = icalTemporalToUtc(start, resolver: timeZoneResolver);
  final endInstant = end == null
      ? startInstant
      : icalTemporalToUtc(end, resolver: timeZoneResolver);
  if (endInstant == startInstant) {
    return !startInstant.isBefore(rangeStartUtc) &&
        startInstant.isBefore(rangeEndUtc);
  }
  return startInstant.isBefore(rangeEndUtc) &&
      endInstant.isAfter(rangeStartUtc);
}

DateTime icalTemporalToUtc(
  IcalTemporalValue value, {
  IcalTimeZoneResolver? resolver,
}) => (resolver ?? IcalTimeZoneResolver.system()).toUtc(value);

bool _afterUntil(
  IcalTemporalValue value,
  IcalTemporalValue until,
  IcalTimeZoneResolver timeZoneResolver,
) {
  if (until.kind == IcalTemporalKind.date) {
    return value.localValue.isAfter(until.localValue);
  }
  return icalTemporalToUtc(
    value,
    resolver: timeZoneResolver,
  ).isAfter(icalTemporalToUtc(until, resolver: timeZoneResolver));
}

List<int> _integerList(
  String? source, {
  required int minimum,
  required int maximum,
  required int maximumValues,
  bool disallowZero = false,
}) {
  if (source == null) return const [];
  final segments = source.split(',');
  if (segments.isEmpty || segments.length > maximumValues) throw _invalidRule();
  final result = <int>[];
  for (final segment in segments) {
    final value = int.tryParse(segment);
    if (value == null ||
        value < minimum ||
        value > maximum ||
        (disallowZero && value == 0)) {
      throw _invalidRule();
    }
    result.add(value);
  }
  return List.unmodifiable(result);
}

List<_ByDay> _parseByDay(String? source, int maximumValues) {
  if (source == null) return const [];
  final segments = source.split(',');
  if (segments.isEmpty || segments.length > maximumValues) throw _invalidRule();
  return List.unmodifiable([
    for (final segment in segments) _parseOneByDay(segment),
  ]);
}

_ByDay _parseOneByDay(String source) {
  final match = RegExp(
    r'^([+-]?\d{1,2})?(MO|TU|WE|TH|FR|SA|SU)$',
  ).firstMatch(source);
  if (match == null) throw _invalidRule();
  final ordinal = match.group(1) == null ? null : int.parse(match.group(1)!);
  if (ordinal == 0 || (ordinal != null && ordinal.abs() > 53)) {
    throw _invalidRule();
  }
  return _ByDay(ordinal, _weekday(match.group(2)!));
}

int _weekday(String source) => switch (source) {
  'MO' => DateTime.monday,
  'TU' => DateTime.tuesday,
  'WE' => DateTime.wednesday,
  'TH' => DateTime.thursday,
  'FR' => DateTime.friday,
  'SA' => DateTime.saturday,
  'SU' => DateTime.sunday,
  _ => throw _invalidRule(),
};

int? _positiveInteger(String? source) {
  if (source == null) return null;
  final value = int.tryParse(source);
  if (value == null || value <= 0) throw _invalidRule();
  return value;
}

DateTime _wall([
  int year = 0,
  int month = 1,
  int day = 1,
  int hour = 0,
  int minute = 0,
  int second = 0,
]) => DateTime.utc(year, month, day, hour, minute, second);

DateTime _addDays(DateTime source, int days) => _wall(
  source.year,
  source.month,
  source.day + days,
  source.hour,
  source.minute,
  source.second,
);

DateTime _addMonths(DateTime source, int months) {
  final zeroBased = source.year * 12 + source.month - 1 + months;
  final year = zeroBased ~/ 12;
  final month = zeroBased % 12 + 1;
  final day = math.min(source.day, _daysInMonth(year, month));
  return _wall(year, month, day, source.hour, source.minute, source.second);
}

DateTime _addYears(DateTime source, int years) {
  final year = source.year + years;
  final day = math.min(source.day, _daysInMonth(year, source.month));
  return _wall(
    year,
    source.month,
    day,
    source.hour,
    source.minute,
    source.second,
  );
}

DateTime _startOfWeek(DateTime source, int weekStart) =>
    _addDays(source, -((source.weekday - weekStart) % 7));

int _daysInMonth(int year, int month) =>
    _wall(year, month + 1).subtract(const Duration(days: 1)).day;

int _daysInYear(int year) =>
    DateTime.utc(year + 1).difference(_wall(year)).inDays;

({int year, int week}) _weekOfYear(DateTime date, int weekStart) {
  var year = date.year;
  var first = _weekOneStart(year, weekStart);
  if (date.isBefore(first)) {
    year -= 1;
    first = _weekOneStart(year, weekStart);
  } else {
    final next = _weekOneStart(year + 1, weekStart);
    if (!date.isBefore(next)) {
      year += 1;
      first = next;
    }
  }
  return (year: year, week: date.difference(first).inDays ~/ 7 + 1);
}

DateTime _weekOneStart(int year, int weekStart) =>
    _startOfWeek(_wall(year, 1, 4), weekStart);

int _weeksInYear(int year, int weekStart) =>
    _weekOneStart(
      year + 1,
      weekStart,
    ).difference(_weekOneStart(year, weekStart)).inDays ~/
    7;

DavException _invalidRule() => const DavException(
  kind: DavErrorKind.invalidCalendarData,
  code: 'IcalInvalidRecurrenceRule',
  safeMessage: 'An iCalendar component contained an invalid recurrence rule.',
);

DavException _occurrenceLimitError() => _limitError(
  'IcalRecurrenceOccurrenceLimitExceeded',
  'A recurrence set produced too many occurrences.',
);

DavException _limitError(String code, String message) => DavException(
  kind: DavErrorKind.limitExceeded,
  code: code,
  safeMessage: message,
);
