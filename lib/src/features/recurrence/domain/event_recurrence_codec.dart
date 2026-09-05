import '../../../providers/busy_provider.dart';
import 'recurrence_rule.dart';

final class RecurrenceRuleLimits {
  const RecurrenceRuleLimits({
    required this.ordinalPositions,
    required this.allowMultipleMonthDays,
    required this.allowMultipleMonths,
  });

  static const rfc5545 = RecurrenceRuleLimits(
    ordinalPositions: {1, 2, 3, 4, 5, -2, -1},
    allowMultipleMonthDays: true,
    allowMultipleMonths: true,
  );

  static const microsoftGraph = RecurrenceRuleLimits(
    ordinalPositions: {1, 2, 3, 4, -1},
    allowMultipleMonthDays: false,
    allowMultipleMonths: false,
  );

  final Set<int> ordinalPositions;
  final bool allowMultipleMonthDays;
  final bool allowMultipleMonths;

  bool supports(RecurrenceRule rule) {
    if (!rule.isSupported || rule.interval < 1 || rule.interval > 366) {
      return false;
    }
    if (!rule.repeats) return true;
    if (rule.count case final count? when count < 1 || count > 3500) {
      return false;
    }
    if (rule.count != null && rule.untilRaw != null) return false;
    if (!rfcWeekdays.contains(rule.weekStart) ||
        rule.byDay.toSet().length != rule.byDay.length ||
        rule.byMonth.toSet().length != rule.byMonth.length ||
        rule.byMonthDay.toSet().length != rule.byMonthDay.length ||
        rule.byMonth.any((value) => value < 1 || value > 12) ||
        rule.byMonthDay.any((value) => value < 1 || value > 31)) {
      return false;
    }
    switch (rule.frequency) {
      case RecurrenceFrequency.none:
        return true;
      case RecurrenceFrequency.daily:
        return rule.byDay.isEmpty &&
            rule.byMonth.isEmpty &&
            rule.byMonthDay.isEmpty &&
            rule.bySetPosition == null;
      case RecurrenceFrequency.weekly:
        return rule.byDay.isNotEmpty &&
            rule.byDay.every(rfcWeekdays.contains) &&
            rule.byMonth.isEmpty &&
            rule.byMonthDay.isEmpty &&
            rule.bySetPosition == null;
      case RecurrenceFrequency.monthly:
        return rule.byMonth.isEmpty && _supportsMonthlyShape(rule);
      case RecurrenceFrequency.yearly:
        return rule.byMonth.isNotEmpty &&
            (allowMultipleMonths || rule.byMonth.length == 1) &&
            (rule.bySetPosition == null || rule.byMonth.length == 1) &&
            _supportsMonthlyShape(rule);
    }
  }

  bool _supportsMonthlyShape(RecurrenceRule rule) {
    if (rule.byMonthDay.isNotEmpty) {
      return rule.byDay.isEmpty &&
          rule.bySetPosition == null &&
          (allowMultipleMonthDays || rule.byMonthDay.length == 1);
    }
    final position = rule.bySetPosition;
    return position != null &&
        ordinalPositions.contains(position) &&
        rule.byDay.isNotEmpty &&
        _isEditableOrdinalDaySet(rule.byDay);
  }
}

abstract final class EventRecurrenceCodec {
  static RecurrenceRuleLimits limitsFor(BusyProvider provider) {
    return provider == BusyProvider.microsoft
        ? RecurrenceRuleLimits.microsoftGraph
        : RecurrenceRuleLimits.rfc5545;
  }

  static RecurrenceRule decode(
    BusyProvider provider,
    Object? value, {
    DateTime? baseDate,
  }) {
    return switch (provider) {
      BusyProvider.microsoft => _decodeMicrosoft(value, baseDate: baseDate),
      BusyProvider.google ||
      BusyProvider.appleICloud ||
      BusyProvider.nextcloud ||
      BusyProvider.webCal => _decodeIcalendar(value, baseDate: baseDate),
    };
  }

  static bool canEncode(BusyProvider provider, RecurrenceRule rule) {
    if (provider == BusyProvider.webCal) return false;
    return limitsFor(provider).supports(rule);
  }

  static Object? encode(
    BusyProvider provider,
    RecurrenceRule rule, {
    required DateTime baseDate,
    required bool allDay,
    String? timeZone,
    Object? original,
  }) {
    if (!canEncode(provider, rule)) {
      throw StateError(
        '${provider.displayName} cannot represent this recurrence rule.',
      );
    }
    if (!rule.repeats) return null;
    return switch (provider) {
      BusyProvider.google => <String>[
        'RRULE:${rule.toRrule()}',
        ..._googleAncillaryLines(original),
      ],
      BusyProvider.appleICloud || BusyProvider.nextcloud => {
        'rules': [rule.toRrule()],
        'dates': const <String>[],
        'excludedDates': const <String>[],
      },
      BusyProvider.microsoft => _encodeMicrosoft(
        rule,
        baseDate: baseDate,
        timeZone: timeZone,
        original: original,
      ),
      BusyProvider.webCal => throw StateError(
        'WebCal subscriptions are read-only.',
      ),
    };
  }
}

RecurrenceRule _decodeIcalendar(Object? value, {DateTime? baseDate}) {
  if (value == null) return const RecurrenceRule.none();
  final rules = <String>[];
  final dates = <String>[];
  final excludedDates = <String>[];
  if (value is List) {
    for (final item in value) {
      final line = item.toString().trim();
      final separator = line.indexOf(':');
      if (separator <= 0 || separator == line.length - 1) {
        return RecurrenceRule.unsupported(rawRules: [line]);
      }
      final property = line.substring(0, separator).toUpperCase();
      final propertyName = property.split(';').first;
      final rawValue = line.substring(separator + 1);
      switch (propertyName) {
        case 'RRULE':
          rules.add(rawValue);
        case 'RDATE':
          dates.add(line);
        case 'EXDATE':
          excludedDates.add(line);
        default:
          return RecurrenceRule.unsupported(rawRules: [line]);
      }
    }
  } else if (value is Map) {
    try {
      rules.addAll(_stringList(value['rules']));
      dates.addAll(_stringList(value['dates']));
      excludedDates.addAll(_stringList(value['excludedDates']));
    } on FormatException {
      return const RecurrenceRule.unsupported();
    }
  } else {
    return const RecurrenceRule.unsupported();
  }
  if (dates.isNotEmpty || excludedDates.isNotEmpty) {
    return RecurrenceRule.unsupported(
      rawRules: rules,
      recurrenceDates: dates,
      exceptionDates: excludedDates,
    );
  }
  return RecurrenceRule.fromIcalendar(rules: rules, baseDate: baseDate);
}

RecurrenceRule _decodeMicrosoft(Object? value, {DateTime? baseDate}) {
  if (value == null) return const RecurrenceRule.none();
  if (value is! Map) return const RecurrenceRule.unsupported();
  final patternValue = value['pattern'];
  final rangeValue = value['range'];
  if (patternValue is! Map || rangeValue is! Map) {
    return const RecurrenceRule.unsupported();
  }
  final pattern = patternValue.cast<Object?, Object?>();
  final range = rangeValue.cast<Object?, Object?>();
  final type = pattern['type']?.toString();
  final interval = _positiveInt(pattern['interval']);
  if (interval == null) return const RecurrenceRule.unsupported();
  final graphDays = _stringListOrEmpty(pattern['daysOfWeek']);
  final byDay = <String>[
    for (final day in graphDays)
      if (_graphDayToRfc(day) case final value?) value,
  ];
  if (byDay.length != graphDays.length) {
    return const RecurrenceRule.unsupported();
  }
  final frequency = switch (type) {
    'daily' => RecurrenceFrequency.daily,
    'weekly' => RecurrenceFrequency.weekly,
    'absoluteMonthly' || 'relativeMonthly' => RecurrenceFrequency.monthly,
    'absoluteYearly' || 'relativeYearly' => RecurrenceFrequency.yearly,
    _ => null,
  };
  if (frequency == null) return const RecurrenceRule.unsupported();
  final relative = type == 'relativeMonthly' || type == 'relativeYearly';
  final absolute = type == 'absoluteMonthly' || type == 'absoluteYearly';
  final dayOfMonth = _positiveInt(pattern['dayOfMonth']);
  final month = _positiveInt(pattern['month']);
  final position = relative
      ? _graphIndex(pattern['index']?.toString() ?? 'first')
      : null;
  final rangeType = range['type']?.toString();
  final startDate = _basicDateOrNull(range['startDate']?.toString());
  final count = rangeType == 'numbered'
      ? _positiveInt(range['numberOfOccurrences'])
      : null;
  final endDate = rangeType == 'endDate'
      ? _basicDateOrNull(range['endDate']?.toString())
      : null;
  if (!const {'noEnd', 'numbered', 'endDate'}.contains(rangeType) ||
      startDate == null ||
      (rangeType == 'numbered' && count == null) ||
      (rangeType == 'endDate' &&
          (endDate == null || endDate.compareTo(startDate) < 0))) {
    return const RecurrenceRule.unsupported();
  }
  final weekStart = type == 'weekly'
      ? _graphDayToRfc(pattern['firstDayOfWeek']?.toString() ?? 'sunday')
      : 'MO';
  if (weekStart == null) return const RecurrenceRule.unsupported();
  final rule = RecurrenceRule(
    frequency: frequency,
    interval: interval,
    byDay: type == 'weekly' || relative ? List.unmodifiable(byDay) : const [],
    byMonth: type == 'absoluteYearly' || type == 'relativeYearly'
        ? [if (month != null) month]
        : const [],
    byMonthDay: absolute ? [if (dayOfMonth != null) dayOfMonth] : const [],
    bySetPosition: position,
    weekStart: weekStart,
    count: count,
    untilRaw: endDate,
    recurrenceDates: const [],
    exceptionDates: const [],
    rawRules: const [],
    isSupported: true,
  );
  if (!RecurrenceRuleLimits.microsoftGraph.supports(rule)) {
    return const RecurrenceRule.unsupported();
  }
  return rule;
}

Map<String, Object?> _encodeMicrosoft(
  RecurrenceRule rule, {
  required DateTime baseDate,
  required String? timeZone,
  required Object? original,
}) {
  final relative = rule.bySetPosition != null;
  final type = switch (rule.frequency) {
    RecurrenceFrequency.daily => 'daily',
    RecurrenceFrequency.weekly => 'weekly',
    RecurrenceFrequency.monthly =>
      relative ? 'relativeMonthly' : 'absoluteMonthly',
    RecurrenceFrequency.yearly =>
      relative ? 'relativeYearly' : 'absoluteYearly',
    RecurrenceFrequency.none => throw StateError(
      'A non-repeating rule cannot be encoded.',
    ),
  };
  final pattern = <String, Object?>{
    'type': type,
    'interval': rule.interval,
    if (rule.frequency == RecurrenceFrequency.weekly) ...{
      'daysOfWeek': rule.byDay.map(_rfcDayToGraph).toList(),
      'firstDayOfWeek': _rfcDayToGraph(rule.weekStart),
    },
    if (rule.frequency == RecurrenceFrequency.monthly && !relative)
      'dayOfMonth': rule.byMonthDay.single,
    if (rule.frequency == RecurrenceFrequency.yearly) ...{
      'month': rule.byMonth.single,
      if (!relative) 'dayOfMonth': rule.byMonthDay.single,
    },
    if (relative) ...{
      'daysOfWeek': rule.byDay.map(_rfcDayToGraph).toList(),
      'index': _rfcPositionToGraph(rule.bySetPosition!),
    },
  };
  final endDate = rule.untilDateFor(timeZone: timeZone);
  final recurrenceTimeZone = _microsoftRecurrenceTimeZone(original);
  final range = <String, Object?>{
    'type': rule.count != null
        ? 'numbered'
        : endDate != null
        ? 'endDate'
        : 'noEnd',
    'startDate': _isoDate(baseDate),
    if (rule.count != null) 'numberOfOccurrences': rule.count,
    if (rule.count == null && endDate != null) 'endDate': endDate,
    if (recurrenceTimeZone != null) 'recurrenceTimeZone': recurrenceTimeZone,
  };
  return {'pattern': pattern, 'range': range};
}

String? _microsoftRecurrenceTimeZone(Object? original) {
  if (original is! Map) return null;
  final range = original['range'];
  if (range is! Map) return null;
  final value = range['recurrenceTimeZone']?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

List<String> _googleAncillaryLines(Object? original) {
  if (original is! List) return const [];
  return [
    for (final item in original)
      if (!item.toString().trimLeft().toUpperCase().startsWith('RRULE:'))
        item.toString(),
  ];
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException();
  return [for (final item in value) item.toString()];
}

List<String> _stringListOrEmpty(Object? value) {
  try {
    return _stringList(value);
  } on FormatException {
    return const [];
  }
}

int? _positiveInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

String? _basicDateOrNull(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || _isoDate(parsed) != value) return null;
  return '${parsed.year.toString().padLeft(4, '0')}'
      '${parsed.month.toString().padLeft(2, '0')}'
      '${parsed.day.toString().padLeft(2, '0')}';
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String? _graphDayToRfc(String value) => switch (value.toLowerCase()) {
  'monday' => 'MO',
  'tuesday' => 'TU',
  'wednesday' => 'WE',
  'thursday' => 'TH',
  'friday' => 'FR',
  'saturday' => 'SA',
  'sunday' => 'SU',
  _ => null,
};

String _rfcDayToGraph(String value) => switch (value) {
  'MO' => 'monday',
  'TU' => 'tuesday',
  'WE' => 'wednesday',
  'TH' => 'thursday',
  'FR' => 'friday',
  'SA' => 'saturday',
  'SU' => 'sunday',
  _ => throw StateError('Invalid RFC weekday: $value'),
};

int? _graphIndex(String? value) => switch (value) {
  'first' => 1,
  'second' => 2,
  'third' => 3,
  'fourth' => 4,
  'last' => -1,
  _ => null,
};

String _rfcPositionToGraph(int value) => switch (value) {
  1 => 'first',
  2 => 'second',
  3 => 'third',
  4 => 'fourth',
  -1 => 'last',
  _ => throw StateError('Invalid Microsoft recurrence position: $value'),
};

bool _isEditableOrdinalDaySet(List<String> values) {
  return ordinalDaySets.any((candidate) => _sameSet(values, candidate));
}

bool _sameSet(List<String> left, List<String> right) {
  return left.length == right.length &&
      left.toSet().length == left.length &&
      left.toSet().containsAll(right);
}

const rfcWeekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

const ordinalDaySets = <List<String>>[
  ['MO'],
  ['TU'],
  ['WE'],
  ['TH'],
  ['FR'],
  ['SA'],
  ['SU'],
  ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'],
  ['MO', 'TU', 'WE', 'TH', 'FR'],
  ['SA', 'SU'],
];
