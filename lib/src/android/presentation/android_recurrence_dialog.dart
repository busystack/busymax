import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../l10n/l10n.dart';

enum _RecurrenceEnd { never, date, count }

/// Material editor for the same provider-safe recurrence subset used on desktop.
/// Unsupported source rules are shown as such and remain untouched until the
/// user deliberately selects a new frequency.
Future<RecurrenceRule?> showAndroidRecurrenceDialog(
  BuildContext context, {
  required RecurrenceRule initial,
  required DateTime baseDate,
  required bool allDay,
  required String? timeZone,
  required RecurrenceRuleLimits limits,
  required String providerLabel,
}) {
  var rule = initial;
  var end = rule.count != null
      ? _RecurrenceEnd.count
      : rule.untilRaw != null
      ? _RecurrenceEnd.date
      : _RecurrenceEnd.never;
  var until = DateTime.tryParse(rule.untilDateFor(timeZone: timeZone) ?? '');
  return showDialog<RecurrenceRule>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = context.l10n;
        final valid = rule.isSupported && limits.supports(rule);
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
                      if (frequency == null) return;
                      setState(() {
                        if (rule.isSupported && frequency == rule.frequency) {
                          return;
                        }
                        rule = androidRuleForFrequency(frequency, baseDate);
                        end = _RecurrenceEnd.never;
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
                        if (value != null) {
                          setState(() => rule = rule.copyWith(interval: value));
                        }
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
                                  Localizations.localeOf(
                                    context,
                                  ).toLanguageTag(),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<_RecurrenceEnd>(
                      isExpanded: true,
                      initialValue: end,
                      decoration: InputDecoration(labelText: l10n.repeatEnd),
                      items: [
                        DropdownMenuItem(
                          value: _RecurrenceEnd.never,
                          child: Text(l10n.repeatNever),
                        ),
                        DropdownMenuItem(
                          value: _RecurrenceEnd.date,
                          child: Text(l10n.repeatUntil),
                        ),
                        DropdownMenuItem(
                          value: _RecurrenceEnd.count,
                          child: Text(l10n.repeatAfter),
                        ),
                      ],
                      onChanged: (selection) {
                        if (selection == null) return;
                        setState(() {
                          end = selection;
                          rule = switch (selection) {
                            _RecurrenceEnd.never => rule.copyWith(
                              count: null,
                              untilRaw: null,
                            ),
                            _RecurrenceEnd.date =>
                              rule
                                  .copyWith(count: null)
                                  .withUntilDate(
                                    _dateValue(until ?? baseDate),
                                    allDay: allDay,
                                    baseDate: baseDate,
                                    timeZone: timeZone,
                                  ),
                            _RecurrenceEnd.count => rule.copyWith(
                              count: rule.count ?? 10,
                              untilRaw: null,
                            ),
                          };
                        });
                      },
                    ),
                    if (end == _RecurrenceEnd.date)
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          DateFormat.yMd(
                            Localizations.localeOf(context).toLanguageTag(),
                          ).format(until ?? baseDate),
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: until ?? baseDate,
                            firstDate: baseDate,
                            lastDate: DateTime(2100),
                          );
                          if (date == null) return;
                          setState(() {
                            until = date;
                            rule = rule.withUntilDate(
                              _dateValue(date),
                              allDay: allDay,
                              baseDate: baseDate,
                              timeZone: timeZone,
                            );
                          });
                        },
                      ),
                    if (end == _RecurrenceEnd.count)
                      TextFormField(
                        initialValue: '${rule.count ?? 10}',
                        decoration: InputDecoration(
                          labelText: l10n.repeatCount,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (text) {
                          final value = int.tryParse(text);
                          if (value != null) {
                            setState(() => rule = rule.copyWith(count: value));
                          }
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

RecurrenceRule androidRuleForFrequency(
  RecurrenceFrequency frequency,
  DateTime base,
) => const RecurrenceRule.none().copyWith(
  frequency: frequency,
  byDay: frequency == RecurrenceFrequency.weekly
      ? [rfcWeekdays[base.weekday - 1]]
      : const [],
  byMonthDay:
      frequency == RecurrenceFrequency.monthly ||
          frequency == RecurrenceFrequency.yearly
      ? [base.day]
      : const [],
  byMonth: frequency == RecurrenceFrequency.yearly ? [base.month] : const [],
);

String _dateValue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
