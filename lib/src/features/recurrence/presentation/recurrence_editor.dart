import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/localized_formatters.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../tasks/presentation/desktop_date_time_fields.dart';
import '../domain/event_recurrence_codec.dart';
import '../domain/recurrence_rule.dart';

Future<RecurrenceRule?> showRecurrenceEditorDialog(
  BuildContext context, {
  required RecurrenceRule initial,
  required bool allDay,
  required DateTime baseDate,
  required DateTime minimumDate,
  required bool useNativeDatePicker,
  bool floating = false,
  String? timeZone,
  RecurrenceRuleLimits limits = RecurrenceRuleLimits.rfc5545,
  Color? barrierColor,
  LinuxHeaderBarService? headerBarService,
}) {
  return showBusyMaxModalEditorDialog<RecurrenceRule>(
    context,
    barrierColor: barrierColor,
    headerBarService: headerBarService,
    maxWidth: 620,
    maxHeight: 820,
    builder: (context) => RecurrenceEditorDialog(
      initial: initial,
      allDay: allDay,
      baseDate: baseDate,
      minimumDate: minimumDate,
      floating: floating,
      timeZone: timeZone,
      limits: limits,
      useNativeDatePicker: useNativeDatePicker,
    ),
  );
}

String recurrenceRuleSummary(
  BuildContext context,
  RecurrenceRule recurrence, {
  String? timeZone,
}) {
  if (!recurrence.repeats) return context.l10n.repeatNone;
  final l10n = context.l10n;
  var summary = recurrence.interval == 1
      ? switch (recurrence.frequency) {
          RecurrenceFrequency.daily => l10n.repeatDaily,
          RecurrenceFrequency.weekly => l10n.repeatWeekly,
          RecurrenceFrequency.monthly => l10n.repeatMonthly,
          RecurrenceFrequency.yearly => l10n.repeatYearly,
          RecurrenceFrequency.none => l10n.repeatNone,
        }
      : switch (recurrence.frequency) {
          RecurrenceFrequency.daily => l10n.repeatEveryDays(
            recurrence.interval,
          ),
          RecurrenceFrequency.weekly => l10n.repeatEveryWeeks(
            recurrence.interval,
          ),
          RecurrenceFrequency.monthly => l10n.repeatEveryMonths(
            recurrence.interval,
          ),
          RecurrenceFrequency.yearly => l10n.repeatEveryYears(
            recurrence.interval,
          ),
          RecurrenceFrequency.none => l10n.repeatNone,
        };
  var yearlyMonthPlacedInSummary = false;
  if (recurrence.frequency == RecurrenceFrequency.weekly &&
      recurrence.byDay.isNotEmpty) {
    final days = recurrence.byDay
        .map((day) => _localizedInlineWeekday(context, day))
        .join(', ');
    summary =
        '$summary${l10n.repeatSummarySeparator}${l10n.repeatOnDaysSummary(days)}';
  } else if ((recurrence.frequency == RecurrenceFrequency.monthly ||
          recurrence.frequency == RecurrenceFrequency.yearly) &&
      recurrence.byMonthDay.isNotEmpty) {
    final monthDayValues = recurrence.byMonthDay
        .map(
          (day) => l10n.repeatMonthDayValue(_localizedDayNumber(context, day)),
        )
        .toList(growable: false);
    if (recurrence.frequency == RecurrenceFrequency.yearly &&
        recurrence.byMonth.isNotEmpty) {
      final monthValues = recurrence.byMonth
          .map((month) => _localizedYearlyMonth(context, month))
          .toList(growable: false);
      final monthDays = _localizedRecurrenceList(
        monthDayValues,
        pair: l10n.repeatYearlyMonthDayListPair,
        start: l10n.repeatYearlyMonthDayListStart,
      );
      final months = _localizedRecurrenceList(
        monthValues,
        pair: l10n.repeatYearlyMonthListPair,
        start: l10n.repeatYearlyMonthListStart,
      );
      summary = switch ((monthValues.length, monthDayValues.length)) {
        (1, 1) => l10n.repeatYearlyOnMonthDaySummary(
          summary,
          months,
          monthDays,
        ),
        (1, _) => l10n.repeatYearlyOnMonthDaysSummary(
          summary,
          months,
          monthDays,
        ),
        (_, 1) => l10n.repeatYearlyInMonthsOnMonthDaySummary(
          summary,
          months,
          monthDays,
        ),
        _ => l10n.repeatYearlyInMonthsOnMonthDaysSummary(
          summary,
          months,
          monthDays,
        ),
      };
      yearlyMonthPlacedInSummary = true;
    } else {
      final monthDays = monthDayValues.join(l10n.repeatMonthDayListSeparator);
      final monthDaysSummary = recurrence.byMonthDay.length == 1
          ? l10n.repeatOnMonthDaysSummary(monthDays)
          : l10n.repeatOnMonthDaysSummaryMultiple(monthDays);
      summary = '$summary${l10n.repeatSummarySeparator}$monthDaysSummary';
    }
  } else if (recurrence.bySetPosition case final position?) {
    final days = _localizedOrdinalDaySummary(context, recurrence.byDay);
    if (recurrence.frequency == RecurrenceFrequency.yearly &&
        recurrence.byMonth.isNotEmpty) {
      final monthValues = recurrence.byMonth
          .map((month) => _localizedYearlyMonth(context, month))
          .toList(growable: false);
      final months = _localizedRecurrenceList(
        monthValues,
        pair: l10n.repeatYearlyMonthListPair,
        start: l10n.repeatYearlyMonthListStart,
      );
      summary = monthValues.length == 1
          ? l10n.repeatYearlyOnOrdinalSummary(
              summary,
              months,
              _ordinalPositionKey(position),
              days,
            )
          : l10n.repeatYearlyInMonthsOnOrdinalSummary(
              summary,
              months,
              _ordinalPositionKey(position),
              days,
            );
      yearlyMonthPlacedInSummary = true;
    } else {
      final ordinalSummary = l10n.repeatOnOrdinalSummary(
        _ordinalPositionKey(position),
        days,
      );
      summary = '$summary${l10n.repeatSummarySeparator}$ordinalSummary';
    }
  }
  if (recurrence.frequency == RecurrenceFrequency.yearly &&
      recurrence.byMonth.isNotEmpty &&
      !yearlyMonthPlacedInSummary) {
    final monthValues = recurrence.byMonth
        .map((month) => _localizedYearlyMonth(context, month))
        .toList(growable: false);
    final months = _localizedRecurrenceList(
      monthValues,
      pair: l10n.repeatYearlyMonthListPair,
      start: l10n.repeatYearlyMonthListStart,
    );
    summary = '$summary ${l10n.repeatInMonthsSummary(months)}';
  }
  if (recurrence.count != null) {
    return '$summary · ${l10n.repeatTimesSummary(recurrence.count!)}';
  }
  final until = recurrence.untilDateFor(timeZone: timeZone);
  if (until == null) return summary;
  final date = DateTime.tryParse(until);
  final label = date == null
      ? until
      : MaterialLocalizations.of(context).formatMediumDate(date);
  return '$summary · ${l10n.repeatUntilSummary(label)}';
}

class RecurrenceEditorDialog extends StatefulWidget {
  const RecurrenceEditorDialog({
    super.key,
    required this.initial,
    required this.allDay,
    required this.baseDate,
    required this.minimumDate,
    required this.floating,
    required this.useNativeDatePicker,
    required this.limits,
    this.timeZone,
  });

  final RecurrenceRule initial;
  final bool allDay;
  final DateTime baseDate;
  final DateTime minimumDate;
  final bool floating;
  final bool useNativeDatePicker;
  final RecurrenceRuleLimits limits;
  final String? timeZone;

  @override
  State<RecurrenceEditorDialog> createState() => _RecurrenceEditorDialogState();
}

enum _RecurrenceEnd { never, until, count }

class _RecurrenceEditorDialogState extends State<RecurrenceEditorDialog> {
  late RecurrenceRule _value;
  late _RecurrenceEnd _end;
  late final TextEditingController _intervalController;
  late final TextEditingController _countController;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.isSupported
        ? widget.initial
        : const RecurrenceRule.none();
    _end = _value.count != null
        ? _RecurrenceEnd.count
        : _value.untilRaw != null
        ? _RecurrenceEnd.until
        : _RecurrenceEnd.never;
    _intervalController = TextEditingController(text: '${_value.interval}');
    _countController = TextEditingController(text: '${_value.count ?? 10}');
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repeats = _value.repeats;
    return BusyMaxModalEditorScaffold(
      title: l10n.repeat,
      cancelLabel: l10n.cancel,
      saveLabel: l10n.save,
      onCancel: () => Navigator.pop(context),
      onSave: _isValid ? () => Navigator.pop(context, _value) : null,
      contentMaxWidth: 560,
      children: [
        BusyMaxGroupedList(
          filled: true,
          children: [
            BusyMaxComboRow<RecurrenceFrequency>(
              title: l10n.repeat,
              values: RecurrenceFrequency.values,
              selected: _value.frequency,
              labelFor: _frequencyLabel,
              onSelected: _setFrequency,
            ),
            if (repeats)
              YaruListTile.square(
                title: TextField(
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: busyMaxGroupedTextFieldDecoration(
                    context,
                    labelText: l10n.repeatEvery,
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    setState(() {
                      if (parsed != null && parsed >= 1 && parsed <= 366) {
                        _value = _value.copyWith(interval: parsed);
                      }
                    });
                  },
                ),
              ),
          ],
        ),
        if (_value.frequency == RecurrenceFrequency.weekly)
          BusyMaxGroupedList(
            title: l10n.repeatOn,
            filled: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(BusyMaxSpacing.md),
                child: YaruChoiceChipBar(
                  style: YaruChoiceChipBarStyle.wrap,
                  labels: [
                    for (final day in rfcWeekdays)
                      Text(
                        _localizedStandaloneWeekday(
                          context,
                          day,
                          abbreviated: true,
                        ),
                      ),
                  ],
                  isSelected: [
                    for (final day in rfcWeekdays) _value.byDay.contains(day),
                  ],
                  selectedFirst: false,
                  clearOnSelect: false,
                  onSelected: (index) {
                    final day = rfcWeekdays[index];
                    _toggleWeekday(day, !_value.byDay.contains(day));
                  },
                ),
              ),
            ],
          ),
        if (_value.frequency == RecurrenceFrequency.monthly ||
            _value.frequency == RecurrenceFrequency.yearly)
          BusyMaxGroupedList(
            title: l10n.repeatDayOfMonth,
            filled: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(BusyMaxSpacing.md),
                child: YaruChoiceChipBar(
                  style: YaruChoiceChipBarStyle.wrap,
                  labels: [
                    for (var day = 1; day <= 31; day += 1)
                      Text(_localizedDayNumber(context, day)),
                  ],
                  isSelected: [
                    for (var day = 1; day <= 31; day += 1)
                      _value.byMonthDay.contains(day),
                  ],
                  selectedFirst: false,
                  clearOnSelect: false,
                  onSelected: _value.bySetPosition == null
                      ? (index) {
                          final day = index + 1;
                          _toggleMonthDay(
                            day,
                            !_value.byMonthDay.contains(day),
                          );
                        }
                      : null,
                ),
              ),
              BusyMaxComboRow<int>(
                title: l10n.repeatOrdinal,
                values: [
                  0,
                  for (final position in _ordinalPositions)
                    if (widget.limits.ordinalPositions.contains(position))
                      position,
                ],
                selected: _value.bySetPosition ?? 0,
                labelFor: (value) => value == 0
                    ? l10n.repeatSpecificDays
                    : _localizedOrdinal(context, value),
                onSelected: _setOrdinal,
              ),
              if (_value.bySetPosition != null)
                BusyMaxComboRow<String>(
                  title: l10n.repeatOn,
                  values: [for (final choice in _ordinalDayChoices) choice.key],
                  selected: _ordinalDayChoiceKey(_value.byDay),
                  labelFor: (value) => _localizedOrdinalDayChoice(
                    context,
                    _ordinalDayChoices
                        .firstWhere((choice) => choice.key == value)
                        .days,
                  ),
                  onSelected: (value) {
                    final days = _ordinalDayChoices
                        .firstWhere((choice) => choice.key == value)
                        .days;
                    setState(() => _value = _value.copyWith(byDay: days));
                  },
                ),
            ],
          ),
        if (_value.frequency == RecurrenceFrequency.yearly)
          BusyMaxGroupedList(
            title: l10n.repeatMonths,
            filled: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(BusyMaxSpacing.md),
                child: YaruChoiceChipBar(
                  style: YaruChoiceChipBarStyle.wrap,
                  labels: [
                    for (var month = 1; month <= 12; month += 1)
                      Text(_localizedStandaloneMonth(context, month)),
                  ],
                  isSelected: [
                    for (var month = 1; month <= 12; month += 1)
                      _value.byMonth.contains(month),
                  ],
                  selectedFirst: false,
                  clearOnSelect: false,
                  onSelected: (index) {
                    final month = index + 1;
                    _toggleMonth(month, !_value.byMonth.contains(month));
                  },
                ),
              ),
            ],
          ),
        if (repeats)
          BusyMaxGroupedList(
            filled: true,
            children: [
              BusyMaxComboRow<_RecurrenceEnd>(
                title: l10n.repeatEnd,
                values: _RecurrenceEnd.values,
                selected: _end,
                labelFor: (value) => switch (value) {
                  _RecurrenceEnd.never => l10n.repeatNever,
                  _RecurrenceEnd.until => l10n.repeatUntil,
                  _RecurrenceEnd.count => l10n.repeatAfter,
                },
                onSelected: _setEnd,
              ),
              if (_end == _RecurrenceEnd.until)
                DesktopDateValueRow(
                  label: l10n.repeatUntil,
                  date:
                      _value.untilDateFor(timeZone: widget.timeZone) ??
                      _dateString(_oneMonthAfter(widget.baseDate)),
                  useNativePicker: widget.useNativeDatePicker,
                  onChanged: _setUntilDate,
                ),
              if (_end == _RecurrenceEnd.count)
                YaruListTile.square(
                  title: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: busyMaxGroupedTextFieldDecoration(
                      context,
                      labelText: l10n.repeatCount,
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      setState(() {
                        if (parsed != null && parsed >= 1 && parsed <= 3500) {
                          _value = _value.copyWith(count: parsed);
                        }
                      });
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }

  bool get _isValid {
    if (!_value.repeats) return true;
    final interval = int.tryParse(_intervalController.text);
    if (interval == null || interval < 1 || interval > 366) return false;
    if (_value.frequency == RecurrenceFrequency.weekly &&
        _value.byDay.isEmpty) {
      return false;
    }
    if ((_value.frequency == RecurrenceFrequency.monthly ||
            _value.frequency == RecurrenceFrequency.yearly) &&
        _value.byMonthDay.isEmpty &&
        (_value.bySetPosition == null || _value.byDay.isEmpty)) {
      return false;
    }
    if (_value.frequency == RecurrenceFrequency.yearly &&
        _value.byMonth.isEmpty) {
      return false;
    }
    if (_end == _RecurrenceEnd.until && _value.untilRaw == null) return false;
    if (_end == _RecurrenceEnd.count) {
      final count = int.tryParse(_countController.text);
      if (count == null || count < 1 || count > 3500) return false;
    }
    return widget.limits.supports(_value);
  }

  void _setFrequency(RecurrenceFrequency frequency) {
    final base = widget.baseDate;
    setState(() {
      _value = switch (frequency) {
        RecurrenceFrequency.none => _value.copyWith(
          frequency: frequency,
          byDay: const [],
          byMonth: const [],
          byMonthDay: const [],
          bySetPosition: null,
          count: null,
          untilRaw: null,
        ),
        RecurrenceFrequency.weekly => _value.copyWith(
          frequency: frequency,
          byDay: [_weekdayCode(base.weekday)],
          byMonth: const [],
          byMonthDay: const [],
          bySetPosition: null,
        ),
        RecurrenceFrequency.monthly => _value.copyWith(
          frequency: frequency,
          byDay: const [],
          byMonth: const [],
          byMonthDay: [base.day],
          bySetPosition: null,
        ),
        RecurrenceFrequency.yearly => _value.copyWith(
          frequency: frequency,
          byDay: const [],
          byMonth: [base.month],
          byMonthDay: [base.day],
          bySetPosition: null,
        ),
        RecurrenceFrequency.daily => _value.copyWith(
          frequency: frequency,
          byDay: const [],
          byMonth: const [],
          byMonthDay: const [],
          bySetPosition: null,
        ),
      };
    });
  }

  void _toggleWeekday(String day, bool selected) {
    final values = [..._value.byDay];
    if (selected) {
      if (!values.contains(day)) values.add(day);
    } else if (values.length > 1) {
      values.remove(day);
    }
    values.sort(
      (left, right) =>
          rfcWeekdays.indexOf(left).compareTo(rfcWeekdays.indexOf(right)),
    );
    setState(() => _value = _value.copyWith(byDay: values));
  }

  void _toggleMonthDay(int day, bool selected) {
    var values = [..._value.byMonthDay];
    if (!widget.limits.allowMultipleMonthDays) {
      values = [day];
    } else if (selected) {
      if (!values.contains(day)) values.add(day);
    } else if (values.length > 1) {
      values.remove(day);
    }
    values.sort();
    setState(() {
      _value = _value.copyWith(
        byMonthDay: values,
        byDay: const [],
        bySetPosition: null,
      );
    });
  }

  void _toggleMonth(int month, bool selected) {
    var values = [..._value.byMonth];
    if (!widget.limits.allowMultipleMonths) {
      values = [month];
    } else if (selected) {
      if (!values.contains(month)) values.add(month);
    } else if (values.length > 1) {
      values.remove(month);
    }
    values.sort();
    setState(() => _value = _value.copyWith(byMonth: values));
  }

  void _setOrdinal(int? value) {
    setState(() {
      if (value == null || value == 0) {
        _value = _value.copyWith(
          bySetPosition: null,
          byDay: const [],
          byMonthDay: _value.byMonthDay.isEmpty
              ? [widget.baseDate.day]
              : [_value.byMonthDay.first],
        );
      } else {
        _value = _value.copyWith(
          bySetPosition: value,
          byDay: _value.byDay.isEmpty
              ? [_weekdayCode(widget.baseDate.weekday)]
              : _value.byDay,
          byMonthDay: const [],
        );
      }
    });
  }

  void _setEnd(_RecurrenceEnd value) {
    setState(() {
      _end = value;
      _value = switch (value) {
        _RecurrenceEnd.never => _value.copyWith(count: null, untilRaw: null),
        _RecurrenceEnd.count => _value.copyWith(
          count: int.tryParse(_countController.text) ?? 10,
          untilRaw: null,
        ),
        _RecurrenceEnd.until =>
          _value
              .copyWith(count: null)
              .withUntilDate(
                _value.untilDateFor(timeZone: widget.timeZone) ??
                    _dateString(_oneMonthAfter(widget.baseDate)),
                allDay: widget.allDay,
                floating: widget.floating,
                baseDate: widget.baseDate,
                timeZone: widget.timeZone,
              ),
      };
    });
  }

  void _setUntilDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return;
    final firstDate = DateTime(
      widget.minimumDate.year,
      widget.minimumDate.month,
      widget.minimumDate.day,
    );
    if (date.isBefore(firstDate)) return;
    setState(() {
      _value = _value.withUntilDate(
        _dateString(date),
        allDay: widget.allDay,
        floating: widget.floating,
        baseDate: widget.baseDate,
        timeZone: widget.timeZone,
      );
    });
  }

  String _frequencyLabel(RecurrenceFrequency frequency) => switch (frequency) {
    RecurrenceFrequency.none => context.l10n.repeatNone,
    RecurrenceFrequency.daily => context.l10n.repeatDaily,
    RecurrenceFrequency.weekly => context.l10n.repeatWeekly,
    RecurrenceFrequency.monthly => context.l10n.repeatMonthly,
    RecurrenceFrequency.yearly => context.l10n.repeatYearly,
  };
}

const _ordinalPositions = [1, 2, 3, 4, 5, -2, -1];

typedef _OrdinalDayChoice = ({String key, List<String> days});

const _ordinalDayChoices = <_OrdinalDayChoice>[
  (key: 'MO', days: ['MO']),
  (key: 'TU', days: ['TU']),
  (key: 'WE', days: ['WE']),
  (key: 'TH', days: ['TH']),
  (key: 'FR', days: ['FR']),
  (key: 'SA', days: ['SA']),
  (key: 'SU', days: ['SU']),
  (key: 'day', days: ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']),
  (key: 'weekday', days: ['MO', 'TU', 'WE', 'TH', 'FR']),
  (key: 'weekend', days: ['SA', 'SU']),
];

String _weekdayCode(int weekday) => rfcWeekdays[(weekday - 1).clamp(0, 6)];

String _ordinalDayChoiceKey(List<String> days) {
  for (final choice in _ordinalDayChoices) {
    if (_sameDaySet(choice.days, days)) return choice.key;
  }
  return days.firstOrNull ?? 'MO';
}

DateTime? _weekdayDate(String day) {
  final index = rfcWeekdays.indexOf(day);
  if (index < 0) return null;
  return DateTime(2024, 1, 1 + index);
}

String _localizedStandaloneWeekday(
  BuildContext context,
  String day, {
  required bool abbreviated,
}) {
  final date = _weekdayDate(day);
  if (date == null) return day;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return localizedWeekdayLabel(locale, date, abbreviated: abbreviated);
}

String _localizedInlineWeekday(BuildContext context, String day) {
  final date = _weekdayDate(day);
  if (date == null) return day;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return localizedInlineWeekday(locale, date);
}

String _localizedStandaloneMonth(BuildContext context, int month) {
  if (month < 1 || month > 12) return '$month';
  final locale = Localizations.localeOf(context).toLanguageTag();
  return localizedMonthLabel(locale, DateTime(2024, month), abbreviated: true);
}

String _localizedDayNumber(BuildContext context, int day) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return localizedNumber(locale, day);
}

String _localizedRecurrenceList(
  List<String> values, {
  required String Function(String first, String second) pair,
  required String Function(String first, String rest) start,
}) {
  assert(values.isNotEmpty);
  if (values.length == 1) return values.single;

  var result = pair(values[values.length - 2], values.last);
  for (var index = values.length - 3; index >= 0; index -= 1) {
    result = start(values[index], result);
  }
  return result;
}

String _localizedInlineMonth(BuildContext context, int month) {
  if (month < 1 || month > 12) return '$month';
  final locale = Localizations.localeOf(context).toLanguageTag();
  return localizedInlineMonth(locale, DateTime(2024, month), abbreviated: true);
}

String _localizedYearlyMonth(BuildContext context, int month) {
  final localizedMonth = _localizedInlineMonth(context, month);
  return context.l10n.repeatYearlyMonthValue(
    localizedMonth,
    _recurrenceMonthKey(month),
  );
}

String _recurrenceMonthKey(int month) => switch (month) {
  1 => 'jan',
  2 => 'feb',
  3 => 'mar',
  4 => 'apr',
  5 => 'may',
  6 => 'jun',
  7 => 'jul',
  8 => 'aug',
  9 => 'sep',
  10 => 'oct',
  11 => 'nov',
  12 => 'dec',
  _ => 'other',
};

String _localizedOrdinal(BuildContext context, int value) => switch (value) {
  1 => context.l10n.repeatFirst,
  2 => context.l10n.repeatSecond,
  3 => context.l10n.repeatThird,
  4 => context.l10n.repeatFourth,
  5 => context.l10n.repeatFifth,
  -2 => context.l10n.repeatSecondToLast,
  -1 => context.l10n.repeatLast,
  _ => '$value',
};

String _ordinalPositionKey(int value) => switch (value) {
  1 => 'first',
  2 => 'second',
  3 => 'third',
  4 => 'fourth',
  5 => 'fifth',
  -2 => 'secondToLast',
  -1 => 'last',
  _ => '$value',
};

String _localizedOrdinalDayChoice(BuildContext context, List<String> days) {
  if (days.length == 1) {
    return _localizedStandaloneWeekday(
      context,
      days.single,
      abbreviated: false,
    );
  }
  if (_sameDaySet(days, _ordinalDayChoices[7].days)) {
    return context.l10n.repeatAnyDay;
  }
  if (_sameDaySet(days, _ordinalDayChoices[8].days)) {
    return context.l10n.repeatWeekday;
  }
  if (_sameDaySet(days, _ordinalDayChoices[9].days)) {
    return context.l10n.repeatWeekendDay;
  }
  return days
      .map(
        (day) => _localizedStandaloneWeekday(context, day, abbreviated: false),
      )
      .join(', ');
}

String _localizedOrdinalDaySummary(BuildContext context, List<String> days) {
  if (days.length == 1) {
    return _localizedInlineWeekday(context, days.single);
  }
  if (_sameDaySet(days, _ordinalDayChoices[7].days)) {
    return context.l10n.repeatAnyDay;
  }
  if (_sameDaySet(days, _ordinalDayChoices[8].days)) {
    return context.l10n.repeatWeekday;
  }
  if (_sameDaySet(days, _ordinalDayChoices[9].days)) {
    return context.l10n.repeatWeekendDay;
  }
  return days.map((day) => _localizedInlineWeekday(context, day)).join(', ');
}

bool _sameDaySet(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  final leftValues = {...left};
  return leftValues.length == left.length && leftValues.containsAll(right);
}

DateTime _oneMonthAfter(DateTime value) {
  final firstOfTarget = DateTime(value.year, value.month + 1);
  final lastDay = DateTime(firstOfTarget.year, firstOfTarget.month + 1, 0).day;
  final day = value.day > lastDay ? lastDay : value.day;
  return DateTime(firstOfTarget.year, firstOfTarget.month, day);
}

String _dateString(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
