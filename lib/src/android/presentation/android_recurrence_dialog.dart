import '../../features/recurrence/domain/recurrence_ordinal_choices.dart';
import '../../l10n/localized_formatters.dart';
import 'android_date_picker.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../features/recurrence/domain/recurrence_editing.dart';
import '../../l10n/l10n.dart';

/// Material editor for the same provider-safe recurrence subset used on desktop.
/// Unsupported source rules remain visible and locked.
Future<RecurrenceRule?> showAndroidRecurrenceDialog(
  BuildContext context, {
  required RecurrenceRule initial,
  required DateTime baseDate,
  required bool allDay,
  required String? timeZone,
  required RecurrenceRuleLimits limits,
  required String providerLabel,
  bool floating = false,
}) {
  var rule = initial;
  var until = DateTime.tryParse(rule.untilDateFor(timeZone: timeZone) ?? '');
  var intervalInputValid = true;
  var countInputValid = true;
  return showDialog<RecurrenceRule>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = context.l10n;
        final end = rule.endMode;
        final valid =
            rule.isSupported &&
            limits.supports(rule) &&
            intervalInputValid &&
            (end != RecurrenceEnd.count || countInputValid);
        return AlertDialog(
          title: Text(l10n.repeat),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!rule.isSupported)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        l10n.unsupportedRecurrencePreserved,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  DropdownButtonFormField<RecurrenceFrequency>(
                    isExpanded: true,
                    key: ValueKey(rule.frequency),
                    initialValue: rule.isSupported ? rule.frequency : null,
                    decoration: InputDecoration(labelText: l10n.repeat),
                    items: [
                      for (final frequency in RecurrenceFrequency.values)
                        DropdownMenuItem(
                          value: frequency,
                          child: Text(switch (frequency) {
                            RecurrenceFrequency.none => l10n.repeatNone,
                            RecurrenceFrequency.daily => l10n.repeatDaily,
                            RecurrenceFrequency.weekly => l10n.repeatWeekly,
                            RecurrenceFrequency.monthly => l10n.repeatMonthly,
                            RecurrenceFrequency.yearly => l10n.repeatYearly,
                          }),
                        ),
                    ],
                    onChanged: (frequency) {
                      if (frequency == null ||
                          (rule.isSupported && frequency == rule.frequency)) {
                        return;
                      }
                      setState(() {
                        rule = rule.withFrequency(frequency, baseDate);
                        intervalInputValid = true;
                        countInputValid = true;
                      });
                    },
                  ),
                  if (rule.isSupported && rule.repeats) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: ValueKey(
                        'android-recurrence-interval-${rule.frequency}',
                      ),
                      initialValue: '${rule.interval}',
                      decoration: InputDecoration(labelText: l10n.repeatEvery),
                      keyboardType: TextInputType.number,
                      onChanged: (text) {
                        final value = int.tryParse(text);
                        setState(() {
                          intervalInputValid =
                              value != null && value > 0 && value <= 366;
                          if (intervalInputValid) {
                            rule = rule.copyWith(interval: value);
                          }
                        });
                      },
                    ),
                    if (rule.frequency == RecurrenceFrequency.weekly) ...[
                      const SizedBox(height: 12),
                      Text(l10n.repeatOn),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (
                            var index = 0;
                            index < rfcWeekdays.length;
                            index++
                          )
                            FilterChip(
                              label: Text(
                                DateFormat.E(
                                  Localizations.localeOf(context)
                                      .toLanguageTag(),
                                ).format(DateTime(2024, 1, index + 1)),
                              ),
                              selected: rule.byDay.contains(rfcWeekdays[index]),
                              onSelected: (selected) => setState(() {
                                final days = [...rule.byDay];
                                if (selected) {
                                  days.add(rfcWeekdays[index]);
                                } else if (days.length > 1) {
                                  days.remove(rfcWeekdays[index]);
                                }
                                days.sort(
                                  (a, b) => rfcWeekdays
                                      .indexOf(a)
                                      .compareTo(rfcWeekdays.indexOf(b)),
                                );
                                rule = rule.copyWith(byDay: days);
                              }),
                            ),
                        ],
                      ),
                    ],
                    if (rule.frequency == RecurrenceFrequency.monthly ||
                        rule.frequency == RecurrenceFrequency.yearly) ...[
                      const SizedBox(height: 12),
                      Text(l10n.repeatDayOfMonth),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (var day = 1; day <= 31; day++)
                            FilterChip(
                              label: Text('$day'),
                              selected: rule.byMonthDay.contains(day),
                              onSelected: rule.bySetPosition != null
                                  ? null
                                  : (selected) => setState(() {
                                      final days = limits.allowMultipleMonthDays
                                          ? [...rule.byMonthDay]
                                          : <int>[];
                                      if (selected ||
                                          !limits.allowMultipleMonthDays) {
                                        days.add(day);
                                      } else if (days.length > 1) {
                                        days.remove(day);
                                      }
                                      days.sort();
                                      rule = rule.copyWith(
                                        byMonthDay: days,
                                        byDay: const [],
                                        bySetPosition: null,
                                      );
                                    }),
                            ),
                        ],
                      ),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        key: ValueKey('ordinal-${rule.bySetPosition}'),
                        initialValue: rule.bySetPosition ?? 0,
                        decoration: InputDecoration(
                          labelText: l10n.repeatOrdinal,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 0,
                            child: Text(l10n.repeatSpecificDays),
                          ),
                          for (final position in [1, 2, 3, 4, 5, -2, -1])
                            if (limits.ordinalPositions.contains(position))
                              DropdownMenuItem(
                                value: position,
                                child: Text(switch (position) {
                                  1 => l10n.repeatFirst,
                                  2 => l10n.repeatSecond,
                                  3 => l10n.repeatThird,
                                  4 => l10n.repeatFourth,
                                  5 => l10n.repeatFifth,
                                  -2 => l10n.repeatSecondToLast,
                                  _ => l10n.repeatLast,
                                }),
                              ),
                        ],
                        onChanged: (position) => setState(() {
                          rule = position == 0
                              ? rule.copyWith(
                                  bySetPosition: null,
                                  byDay: const [],
                                  byMonthDay: [baseDate.day],
                                )
                              : rule.copyWith(
                                  bySetPosition: position,
                                  byDay: rule.byDay.isEmpty
                                      ? [rfcWeekdays[baseDate.weekday - 1]]
                                      : rule.byDay,
                                  byMonthDay: const [],
                                  byMonth: rule.byMonth.length > 1
                                      ? [rule.byMonth.first]
                                      : rule.byMonth,
                                );
                        }),
                      ),
                      if (rule.bySetPosition != null)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          key: ValueKey(
                            'ordinal-days-${recurrenceOrdinalChoiceKey(rule.byDay)}',
                          ),
                          initialValue: recurrenceOrdinalChoiceKey(rule.byDay),
                          decoration: InputDecoration(labelText: l10n.repeatOn),
                          items: [
                            for (final choice in recurrenceOrdinalChoices)
                              DropdownMenuItem(
                                value: choice.key,
                                child: Text(switch (choice.key) {
                                  'day' => l10n.repeatAnyDay,
                                  'weekday' => l10n.repeatWeekday,
                                  'weekend' => l10n.repeatWeekendDay,
                                  _ => localizedWeekdayLabel(
                                    Localizations.localeOf(context)
                                        .toLanguageTag(),
                                    DateTime(
                                      2024,
                                      1,
                                      rfcWeekdays.indexOf(choice.key) + 1,
                                    ),
                                    abbreviated: false,
                                  ),
                                }),
                              ),
                          ],
                          onChanged: (key) => setState(
                            () => rule = rule.copyWith(
                              byDay: recurrenceOrdinalChoices
                                  .firstWhere((choice) => choice.key == key)
                                  .days,
                            ),
                          ),
                        ),
                    ],
                    if (rule.frequency == RecurrenceFrequency.yearly) ...[
                      const SizedBox(height: 12),
                      Text(l10n.repeatMonths),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (var month = 1; month <= 12; month++)
                            FilterChip(
                              label: Text(
                                DateFormat.MMM().format(DateTime(2024, month)),
                              ),
                              selected: rule.byMonth.contains(month),
                              onSelected: (selected) => setState(() {
                                final months =
                                    limits.allowMultipleMonths &&
                                        rule.bySetPosition == null
                                    ? [...rule.byMonth]
                                    : <int>[];
                                if (selected || months.isEmpty) {
                                  months.add(month);
                                } else if (months.length > 1) {
                                  months.remove(month);
                                }
                                months.sort();
                                rule = rule.copyWith(byMonth: months);
                              }),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RecurrenceEnd>(
                      key: const ValueKey('android-recurrence-end'),
                      isExpanded: true,
                      initialValue: end,
                      decoration: InputDecoration(labelText: l10n.repeatEnd),
                      items: [
                        DropdownMenuItem(
                          value: RecurrenceEnd.never,
                          child: Text(l10n.repeatNever),
                        ),
                        DropdownMenuItem(
                          value: RecurrenceEnd.until,
                          child: Text(l10n.repeatUntil),
                        ),
                        DropdownMenuItem(
                          value: RecurrenceEnd.count,
                          child: Text(l10n.repeatAfter),
                        ),
                      ],
                      onChanged: (selection) {
                        if (selection == null) {
                          return;
                        }
                        setState(() {
                          countInputValid = true;
                          rule = rule.withEndMode(
                            selection,
                            baseDate: baseDate,
                            allDay: allDay,
                            timeZone: timeZone,
                            floating: floating,
                            defaultUntil: _dateValue(until ?? baseDate),
                          );
                        });
                      },
                    ),
                    if (end == RecurrenceEnd.until)
                      TextButton.icon(
                        key: const ValueKey('android-recurrence-until'),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          DateFormat.yMd(
                            Localizations.localeOf(context).toLanguageTag(),
                          ).format(until ?? baseDate),
                        ),
                        onPressed: () async {
                          final date = await showBusyMaxDatePicker(
                            context: context,
                            initialDate: (until ?? baseDate).isBefore(baseDate)
                                ? baseDate
                                : until ?? baseDate,
                            firstDate: baseDate,
                            lastDate: DateTime(9999, 12, 31),
                          );
                          if (date == null) {
                            return;
                          }
                          setState(() {
                            until = date;
                            rule = rule.withUntilDate(
                              _dateValue(date),
                              allDay: allDay,
                              floating: floating,
                              baseDate: baseDate,
                              timeZone: timeZone,
                            );
                          });
                        },
                      ),
                    if (end == RecurrenceEnd.count)
                      TextFormField(
                        key: ValueKey(
                          'android-recurrence-count-${rule.frequency}',
                        ),
                        initialValue: '${rule.count ?? 10}',
                        decoration: InputDecoration(
                          labelText: l10n.repeatCount,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (text) {
                          final value = int.tryParse(text);
                          setState(() {
                            countInputValid =
                                value != null && value > 0 && value <= 3500;
                            if (countInputValid) {
                              rule = rule.copyWith(count: value);
                            }
                          });
                        },
                      ),
                  ],
                  if (rule.isSupported && !valid)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        l10n.recurrenceUnsupportedByProvider(providerLabel),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: valid
                  ? () => Navigator.pop(dialogContext, rule)
                  : null,
              child: Text(l10n.save),
            ),
          ],
        );
      },
    ),
  );
}

String _dateValue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
