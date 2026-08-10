import 'dart:convert';

enum IcalTaskRecurrenceFrequency { none, daily, weekly, monthly, yearly }

/// The recurrence subset exposed by Nextcloud Tasks 0.18.x.
///
/// Rules outside that subset remain available through [rawRules] and are not
/// rewritten. Supported rules cover frequency, interval, BYDAY, BYMONTH,
/// BYMONTHDAY, BYSETPOS, COUNT, and UNTIL.
final class IcalTaskRecurrence {
  const IcalTaskRecurrence({
    required this.frequency,
    required this.interval,
    required this.byDay,
    required this.byMonth,
    required this.byMonthDay,
    required this.bySetPosition,
    required this.count,
    required this.untilRaw,
    required this.recurrenceDates,
    required this.exceptionDates,
    required this.rawRules,
    required this.isSupported,
  });

  const IcalTaskRecurrence.none()
    : frequency = IcalTaskRecurrenceFrequency.none,
      interval = 1,
      byDay = const [],
      byMonth = const [],
      byMonthDay = const [],
      bySetPosition = null,
      count = null,
      untilRaw = null,
      recurrenceDates = const [],
      exceptionDates = const [],
      rawRules = const [],
      isSupported = true;

  factory IcalTaskRecurrence.fromJson(String? source, {DateTime? baseDate}) {
    if (source == null || source.isEmpty) {
      return const IcalTaskRecurrence.none();
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) return _unsupported(const [], const [], const []);
      final map = decoded.cast<Object?, Object?>();
      final rules = _strings(map['rules']);
      final dates = _strings(map['dates']);
      final excludedDates = _strings(map['excludedDates']);
      if (rules.isEmpty) {
        return IcalTaskRecurrence(
          frequency: IcalTaskRecurrenceFrequency.none,
          interval: 1,
          byDay: const [],
          byMonth: const [],
          byMonthDay: const [],
          bySetPosition: null,
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
        'DAILY' => IcalTaskRecurrenceFrequency.daily,
        'WEEKLY' => IcalTaskRecurrenceFrequency.weekly,
        'MONTHLY' => IcalTaskRecurrenceFrequency.monthly,
        'YEARLY' => IcalTaskRecurrenceFrequency.yearly,
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
          );
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
      return IcalTaskRecurrence(
        frequency: supportedFrequency,
        interval: supportedInterval,
        byDay: List.unmodifiable(normalized.byDay),
        byMonth: List.unmodifiable(normalized.byMonth),
        byMonthDay: List.unmodifiable(normalized.byMonthDay),
        bySetPosition: normalized.bySetPosition,
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

  final IcalTaskRecurrenceFrequency frequency;
  final int interval;
  final List<String> byDay;
  final List<int> byMonth;
  final List<int> byMonthDay;
  final int? bySetPosition;
  final int? count;
  final String? untilRaw;
  final List<String> recurrenceDates;
  final List<String> exceptionDates;
  final List<String> rawRules;
  final bool isSupported;

  bool get repeats => frequency != IcalTaskRecurrenceFrequency.none;

  String? get untilDate {
    final value = untilRaw;
    if (value == null || value.length < 8) return null;
    final parsed = _parseUntil(value);
    if (parsed == null) return null;
    final display = value.endsWith('Z') ? parsed.toLocal() : parsed;
    return '${display.year.toString().padLeft(4, '0')}-'
        '${display.month.toString().padLeft(2, '0')}-'
        '${display.day.toString().padLeft(2, '0')}';
  }

  IcalTaskRecurrence copyWith({
    IcalTaskRecurrenceFrequency? frequency,
    int? interval,
    List<String>? byDay,
    List<int>? byMonth,
    List<int>? byMonthDay,
    Object? bySetPosition = _unchanged,
    Object? count = _unchanged,
    Object? untilRaw = _unchanged,
    List<String>? recurrenceDates,
    List<String>? exceptionDates,
  }) => IcalTaskRecurrence(
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    byDay: List.unmodifiable(byDay ?? this.byDay),
    byMonth: List.unmodifiable(byMonth ?? this.byMonth),
    byMonthDay: List.unmodifiable(byMonthDay ?? this.byMonthDay),
    bySetPosition: bySetPosition == _unchanged
        ? this.bySetPosition
        : bySetPosition as int?,
    count: count == _unchanged ? this.count : count as int?,
    untilRaw: untilRaw == _unchanged ? this.untilRaw : untilRaw as String?,
    recurrenceDates: List.unmodifiable(recurrenceDates ?? this.recurrenceDates),
    exceptionDates: List.unmodifiable(exceptionDates ?? this.exceptionDates),
    rawRules: const [],
    isSupported: true,
  );

  IcalTaskRecurrence withUntilDate(String? date, {required bool allDay}) {
    if (date == null || date.isEmpty) return copyWith(untilRaw: null);
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return this;
    final localDate = DateTime(parsed.year, parsed.month, parsed.day);
    final basic = _basicDate(localDate);
    if (allDay) return copyWith(untilRaw: basic);
    final utc = localDate.toUtc();
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
      if (count != null) 'COUNT=$count',
      if (untilRaw != null) 'UNTIL=$untilRaw',
    ];
    return result.join(';');
  }
}

const _supportedParts = {
  'FREQ',
  'INTERVAL',
  'BYDAY',
  'BYMONTH',
  'BYMONTHDAY',
  'BYSETPOS',
  'COUNT',
  'UNTIL',
};

const _unchanged = Object();

IcalTaskRecurrence _unsupported(
  List<String> rules,
  List<String> dates,
  List<String> excludedDates,
) => IcalTaskRecurrence(
  frequency: IcalTaskRecurrenceFrequency.none,
  interval: 1,
  byDay: const [],
  byMonth: const [],
  byMonthDay: const [],
  bySetPosition: null,
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
  required IcalTaskRecurrenceFrequency frequency,
  required List<String> byDay,
  required List<int> byMonth,
  required List<int> byMonthDay,
  required List<int> bySetPositions,
  required DateTime? baseDate,
}) {
  switch (frequency) {
    case IcalTaskRecurrenceFrequency.none:
      return null;
    case IcalTaskRecurrenceFrequency.daily:
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
    case IcalTaskRecurrenceFrequency.weekly:
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
    case IcalTaskRecurrenceFrequency.monthly:
      if (byMonth.isNotEmpty) return null;
      return _normalizeMonthlyOrYearly(
        byDay: byDay,
        byMonth: const [],
        byMonthDay: byMonthDay,
        bySetPositions: bySetPositions,
        defaultMonthDay: baseDate?.day,
      );
    case IcalTaskRecurrenceFrequency.yearly:
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
