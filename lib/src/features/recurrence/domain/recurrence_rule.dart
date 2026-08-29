import 'dart:convert';

import '../../../core/time/provider_date_time.dart';

enum RecurrenceFrequency { none, daily, weekly, monthly, yearly }

/// The recurrence subset BusyMax can edit without losing provider data.
///
/// Rules outside that subset remain available through [rawRules] and are not
/// rewritten. The editable subset covers the RFC 5545 fields shared by the
/// supported calendar and task providers.
final class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    required this.interval,
    required this.byDay,
    required this.byMonth,
    required this.byMonthDay,
    required this.bySetPosition,
    this.weekStart = 'MO',
    required this.count,
    required this.untilRaw,
    required this.recurrenceDates,
    required this.exceptionDates,
    required this.rawRules,
    required this.isSupported,
  });

  const RecurrenceRule.none()
    : frequency = RecurrenceFrequency.none,
      interval = 1,
      byDay = const [],
      byMonth = const [],
      byMonthDay = const [],
      bySetPosition = null,
      weekStart = 'MO',
      count = null,
      untilRaw = null,
      recurrenceDates = const [],
      exceptionDates = const [],
      rawRules = const [],
      isSupported = true;

  factory RecurrenceRule.fromJson(String? source, {DateTime? baseDate}) {
    if (source == null || source.isEmpty) {
      return const RecurrenceRule.none();
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return _unsupported(const [], const [], const []);
      final map = decoded.cast<Object?, Object?>();
      final rules = _strings(map['rules']);
      final dates = _strings(map['dates']);
      final excludedDates = _strings(map['excludedDates']);
      if (rules.isEmpty) {
        return RecurrenceRule(
          frequency: RecurrenceFrequency.none,
          interval: 1,
          byDay: const [],
          byMonth: const [],
          byMonthDay: const [],
          bySetPosition: null,
          weekStart: 'MO',
          count: null,
          untilRaw: null,
          recurrenceDates: dates,
          exceptionDates: excludedDates,
          rawRules: rules,
          isSupported: true,
        );
      }
      if (rules.length != 1) return _unsupported(rules, dates, excludedDates);
      final parts = <String, String>{};
      for (final segment in rules.single.split(';')) {
        final separator = segment.indexOf('=');
        if (separator <= 0 || separator == segment.length - 1) {
          return _unsupported(rules, dates, excludedDates);
        }
        final key = segment.substring(0, separator).toUpperCase();
        if (parts.containsKey(key) || !_supportedParts.contains(key)) {
          return _unsupported(rules, dates, excludedDates);
        }
        parts[key] = segment.substring(separator + 1).toUpperCase();
      }
      final frequency = switch (parts['FREQ']) {
        'DAILY' => RecurrenceFrequency.daily,
        'WEEKLY' => RecurrenceFrequency.weekly,
        'MONTHLY' => RecurrenceFrequency.monthly,
        'YEARLY' => RecurrenceFrequency.yearly,
        _ => null,
      };
      final interval = int.tryParse(parts['INTERVAL'] ?? '1');
      final count = parts['COUNT'] == null
          ? null
          : int.tryParse(parts['COUNT']!);
      final byDay = _csv(parts['BYDAY']);
      final byMonth = _integers(parts['BYMONTH']);
      final byMonthDay = _integers(parts['BYMONTHDAY']);
      final bySetPositions = _integers(parts['BYSETPOS']);
      final weekStart = parts['WKST'] ?? 'MO';
      final until = parts['UNTIL'];
      final valid =
          frequency != null &&
          interval != null &&
          interval >= 1 &&
          interval <= 366 &&
          (count == null || (count >= 1 && count <= 3500)) &&
          !(count != null && until != null) &&
          (until == null || _validUntil(until)) &&
          byMonth.every((value) => value >= 1 && value <= 12) &&
          byMonthDay.every(
            (value) => value != 0 && value >= -31 && value <= 31,
          ) &&
          bySetPositions.length <= 1 &&
          bySetPositions.every(
            (value) => value != 0 && value >= -366 && value <= 366,
          ) &&
          _plainWeekdays.contains(weekStart);
      if (!valid) return _unsupported(rules, dates, excludedDates);
      final supportedFrequency = frequency;
      final supportedInterval = interval;

      final normalized = _normalizeEditorRule(
        frequency: supportedFrequency,
        byDay: byDay,
        byMonth: byMonth,
        byMonthDay: byMonthDay,
        bySetPositions: bySetPositions,
        baseDate: baseDate,
      );
      if (normalized == null) {
        return _unsupported(rules, dates, excludedDates);
      }
      return RecurrenceRule(
        frequency: supportedFrequency,
        interval: supportedInterval,
        byDay: List.unmodifiable(normalized.byDay),
        byMonth: List.unmodifiable(normalized.byMonth),
        byMonthDay: List.unmodifiable(normalized.byMonthDay),
        bySetPosition: normalized.bySetPosition,
        weekStart: weekStart,
        count: count,
        untilRaw: until,
        recurrenceDates: List.unmodifiable(dates),
        exceptionDates: List.unmodifiable(excludedDates),
        rawRules: List.unmodifiable(rules),
        isSupported: true,
      );
    } on Object {
      return _unsupported(const [], const [], const []);
    }
  }

  factory RecurrenceRule.fromIcalendar({
    required List<String> rules,
    List<String> recurrenceDates = const [],
    List<String> exceptionDates = const [],
    DateTime? baseDate,
  }) {
    return RecurrenceRule.fromJson(
      jsonEncode({
        'rules': rules,
        'dates': recurrenceDates,
        'excludedDates': exceptionDates,
      }),
      baseDate: baseDate,
    );
  }

  const RecurrenceRule.unsupported({
    this.rawRules = const [],
    this.recurrenceDates = const [],
    this.exceptionDates = const [],
  }) : frequency = RecurrenceFrequency.none,
       interval = 1,
       byDay = const [],
       byMonth = const [],
       byMonthDay = const [],
       bySetPosition = null,
       weekStart = 'MO',
       count = null,
       untilRaw = null,
       isSupported = false;

  final RecurrenceFrequency frequency;
  final int interval;
  final List<String> byDay;
  final List<int> byMonth;
  final List<int> byMonthDay;
  final int? bySetPosition;
  final String weekStart;
  final int? count;
  final String? untilRaw;
  final List<String> recurrenceDates;
  final List<String> exceptionDates;
  final List<String> rawRules;
  final bool isSupported;

  bool get repeats => frequency != RecurrenceFrequency.none;

  String? get untilDate => untilDateFor();

  String? untilDateFor({String? timeZone}) {
    final value = untilRaw;
    if (value == null || value.length < 8) return null;
    final parsed = _parseUntil(value);
    if (parsed == null) return null;
    final display = value.endsWith('Z')
        ? providerUtcInstantAsWallTime(parsed, timeZone)
        : parsed;
    return '${display.year.toString().padLeft(4, '0')}-'
        '${display.month.toString().padLeft(2, '0')}-'
        '${display.day.toString().padLeft(2, '0')}';
  }

  RecurrenceRule copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    List<String>? byDay,
    List<int>? byMonth,
    List<int>? byMonthDay,
    Object? bySetPosition = _unchanged,
    String? weekStart,
    Object? count = _unchanged,
    Object? untilRaw = _unchanged,
    List<String>? recurrenceDates,
    List<String>? exceptionDates,
  }) => RecurrenceRule(
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    byDay: List.unmodifiable(byDay ?? this.byDay),
    byMonth: List.unmodifiable(byMonth ?? this.byMonth),
    byMonthDay: List.unmodifiable(byMonthDay ?? this.byMonthDay),
    bySetPosition: bySetPosition == _unchanged
        ? this.bySetPosition
        : bySetPosition as int?,
    weekStart: weekStart ?? this.weekStart,
    count: count == _unchanged ? this.count : count as int?,
    untilRaw: untilRaw == _unchanged ? this.untilRaw : untilRaw as String?,
    recurrenceDates: List.unmodifiable(recurrenceDates ?? this.recurrenceDates),
    exceptionDates: List.unmodifiable(exceptionDates ?? this.exceptionDates),
    rawRules: const [],
    isSupported: true,
  );

  RecurrenceRule withUntilDate(
    String? date, {
    required bool allDay,
    bool floating = false,
    DateTime? baseDate,
    String? timeZone,
  }) {
    if (date == null || date.isEmpty) return copyWith(untilRaw: null);
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return this;
    final wall = DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      baseDate?.hour ?? 0,
      baseDate?.minute ?? 0,
      baseDate?.second ?? 0,
    );
    final basic = _basicDate(wall);
    if (allDay) return copyWith(untilRaw: basic);
    if (floating) {
      return copyWith(
        untilRaw:
            '${basic}T'
            '${wall.hour.toString().padLeft(2, '0')}'
            '${wall.minute.toString().padLeft(2, '0')}'
            '${wall.second.toString().padLeft(2, '0')}',
      );
    }
    final utc =
        providerDateTimeAsUtcInstant(wall.toIso8601String(), timeZone) ??
        wall.toUtc();
    return copyWith(
      untilRaw:
          '${_basicDate(utc)}T'
          '${utc.hour.toString().padLeft(2, '0')}'
          '${utc.minute.toString().padLeft(2, '0')}'
          '${utc.second.toString().padLeft(2, '0')}Z',
    );
  }

  String toJsonString() => jsonEncode({
    'rules': repeats ? [toRrule()] : const <String>[],
    'dates': recurrenceDates,
    'excludedDates': exceptionDates,
  });

  String toRrule() {
    if (!isSupported || !repeats) {
      throw StateError('Only a supported repeating rule can be serialized.');
    }
    final result = <String>[
      'FREQ=${frequency.name.toUpperCase()}',
      'INTERVAL=$interval',
      if (byDay.isNotEmpty) 'BYDAY=${byDay.join(',')}',
      if (byMonth.isNotEmpty) 'BYMONTH=${byMonth.join(',')}',
      if (byMonthDay.isNotEmpty) 'BYMONTHDAY=${byMonthDay.join(',')}',
      if (bySetPosition != null) 'BYSETPOS=$bySetPosition',
      if (frequency == RecurrenceFrequency.weekly) 'WKST=$weekStart',
      if (count != null) 'COUNT=$count',
      if (untilRaw != null) 'UNTIL=$untilRaw',
    ];
    return result.join(';');
  }

  @override
  bool operator ==(Object other) {
    return other is RecurrenceRule &&
        other.frequency == frequency &&
        other.interval == interval &&
        _listEquals(other.byDay, byDay) &&
        _listEquals(other.byMonth, byMonth) &&
        _listEquals(other.byMonthDay, byMonthDay) &&
        other.bySetPosition == bySetPosition &&
        other.weekStart == weekStart &&
        other.count == count &&
        other.untilRaw == untilRaw &&
        _listEquals(other.recurrenceDates, recurrenceDates) &&
        _listEquals(other.exceptionDates, exceptionDates) &&
        _listEquals(other.rawRules, rawRules) &&
        other.isSupported == isSupported;
  }

  @override
  int get hashCode => Object.hash(
    frequency,
    interval,
    Object.hashAll(byDay),
    Object.hashAll(byMonth),
    Object.hashAll(byMonthDay),
    bySetPosition,
    weekStart,
    count,
    untilRaw,
    Object.hashAll(recurrenceDates),
    Object.hashAll(exceptionDates),
    Object.hashAll(rawRules),
    isSupported,
  );
}

const _supportedParts = {
  'FREQ',
  'INTERVAL',
  'BYDAY',
  'BYMONTH',
  'BYMONTHDAY',
  'BYSETPOS',
  'WKST',
  'COUNT',
  'UNTIL',
};

const _unchanged = Object();

RecurrenceRule _unsupported(
  List<String> rules,
  List<String> dates,
  List<String> excludedDates,
) => RecurrenceRule(
  frequency: RecurrenceFrequency.none,
  interval: 1,
  byDay: const [],
  byMonth: const [],
  byMonthDay: const [],
  bySetPosition: null,
  weekStart: 'MO',
  count: null,
  untilRaw: null,
  recurrenceDates: List.unmodifiable(dates),
  exceptionDates: List.unmodifiable(excludedDates),
  rawRules: List.unmodifiable(rules),
  isSupported: false,
);

List<String> _strings(Object? source) {
  if (source == null) return const [];
  if (source is! List) throw const FormatException();
  return [for (final value in source) value.toString()];
}

List<String> _csv(String? source) => source == null || source.isEmpty
    ? const []
    : source.split(',').where((value) => value.isNotEmpty).toList();

List<int> _integers(String? source) {
  final values = _csv(source);
  final result = <int>[];
  for (final value in values) {
    final parsed = int.tryParse(value);
    if (parsed == null) throw const FormatException();
    result.add(parsed);
  }
  return result;
}

typedef _NormalizedEditorRule = ({
  List<String> byDay,
  List<int> byMonth,
  List<int> byMonthDay,
  int? bySetPosition,
});

_NormalizedEditorRule? _normalizeEditorRule({
  required RecurrenceFrequency frequency,
  required List<String> byDay,
  required List<int> byMonth,
  required List<int> byMonthDay,
  required List<int> bySetPositions,
  required DateTime? baseDate,
}) {
  switch (frequency) {
    case RecurrenceFrequency.none:
      return null;
    case RecurrenceFrequency.daily:
      if (byDay.isNotEmpty ||
          byMonth.isNotEmpty ||
          byMonthDay.isNotEmpty ||
          bySetPositions.isNotEmpty) {
        return null;
      }
      return (
        byDay: const [],
        byMonth: const [],
        byMonthDay: const [],
        bySetPosition: null,
      );
    case RecurrenceFrequency.weekly:
      if (byMonth.isNotEmpty ||
          byMonthDay.isNotEmpty ||
          bySetPositions.isNotEmpty ||
          byDay.any((value) => !_plainWeekdays.contains(value))) {
        return null;
      }
      return (
        byDay: byDay.isEmpty && baseDate != null
            ? [_weekdayFor(baseDate.weekday)]
            : byDay,
        byMonth: const [],
        byMonthDay: const [],
        bySetPosition: null,
      );
    case RecurrenceFrequency.monthly:
      if (byMonth.isNotEmpty) return null;
      return _normalizeMonthlyOrYearly(
        byDay: byDay,
        byMonth: const [],
        byMonthDay: byMonthDay,
        bySetPositions: bySetPositions,
        defaultMonthDay: baseDate?.day,
      );
    case RecurrenceFrequency.yearly:
      final months = byMonth.isEmpty && baseDate != null
          ? [baseDate.month]
          : byMonth;
      if (months.isEmpty) return null;
      return _normalizeMonthlyOrYearly(
        byDay: byDay,
        byMonth: months,
        byMonthDay: byMonthDay,
        bySetPositions: bySetPositions,
        defaultMonthDay: baseDate?.day,
      );
  }
}

_NormalizedEditorRule? _normalizeMonthlyOrYearly({
  required List<String> byDay,
  required List<int> byMonth,
  required List<int> byMonthDay,
  required List<int> bySetPositions,
  required int? defaultMonthDay,
}) {
  if (byMonthDay.isNotEmpty) {
    if (byDay.isNotEmpty ||
        bySetPositions.isNotEmpty ||
        byMonthDay.any((value) => value < 1 || value > 31)) {
      return null;
    }
    return (
      byDay: const [],
      byMonth: byMonth,
      byMonthDay: byMonthDay,
      bySetPosition: null,
    );
  }

  if (byDay.length == 1 && bySetPositions.isEmpty) {
    final ordinal = RegExp(
      r'^(-?[1-5])(MO|TU|WE|TH|FR|SA|SU)$',
    ).firstMatch(byDay.single);
    if (ordinal != null) {
      final position = int.parse(ordinal.group(1)!);
      if (_editorSetPositions.contains(position)) {
        return (
          byDay: [ordinal.group(2)!],
          byMonth: byMonth,
          byMonthDay: const [],
          bySetPosition: position,
        );
      }
    }
  }

  if (byDay.isNotEmpty &&
      bySetPositions.length == 1 &&
      _allowedEditorByDay(byDay) &&
      _editorSetPositions.contains(bySetPositions.single)) {
    return (
      byDay: byDay,
      byMonth: byMonth,
      byMonthDay: const [],
      bySetPosition: bySetPositions.single,
    );
  }

  if (byDay.isEmpty && bySetPositions.isEmpty && defaultMonthDay != null) {
    return (
      byDay: const [],
      byMonth: byMonth,
      byMonthDay: [defaultMonthDay],
      bySetPosition: null,
    );
  }
  return null;
}

bool _allowedEditorByDay(List<String> values) {
  final sorted = [...values]..sort();
  return _editorDaySets.any((allowed) {
    final candidate = [...allowed]..sort();
    if (candidate.length != sorted.length) return false;
    for (var index = 0; index < sorted.length; index += 1) {
      if (candidate[index] != sorted[index]) return false;
    }
    return true;
  });
}

bool _validUntil(String value) => _parseUntil(value) != null;

DateTime? _parseUntil(String value) {
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$',
  ).firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hasTime = match.group(4) != null;
  final hour = hasTime ? int.parse(match.group(4)!) : 0;
  final minute = hasTime ? int.parse(match.group(5)!) : 0;
  final second = hasTime ? int.parse(match.group(6)!) : 0;
  final parsed = match.group(7) == 'Z'
      ? DateTime.utc(year, month, day, hour, minute, second)
      : DateTime(year, month, day, hour, minute, second);
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      parsed.hour != hour ||
      parsed.minute != minute ||
      parsed.second != second) {
    return null;
  }
  return parsed;
}

String _basicDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}';

String _weekdayFor(int weekday) => _plainWeekdays[(weekday - 1).clamp(0, 6)];

const _plainWeekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
const _editorSetPositions = {1, 2, 3, 4, 5, -2, -1};
const _editorDaySets = <List<String>>[
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

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
