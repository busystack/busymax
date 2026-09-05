import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';

enum _WindowsRecurrenceEnd { never, until, count }

Future<RecurrenceRule?> showWindowsRecurrenceDialog(
  BuildContext context, {
  required RecurrenceRule initial,
  required DateTime baseDate,
  required bool allDay,
  required String timeZone,
  required String providerLabel,
  required RecurrenceRuleLimits limits,
}) {
  var value = initial.isSupported ? initial : const RecurrenceRule.none();
  var end = value.count != null
      ? _WindowsRecurrenceEnd.count
      : value.untilRaw != null
      ? _WindowsRecurrenceEnd.until
      : _WindowsRecurrenceEnd.never;
  var until = DateTime.tryParse(value.untilDateFor(timeZone: timeZone) ?? '');
  return showDialog<RecurrenceRule>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        final valid = limits.supports(value);
        return ContentDialog(
          title: Text(l10n.repeat),
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoLabel(
                  label: l10n.repeat,
                  child: ComboBox<RecurrenceFrequency>(
                    isExpanded: true,
                    value: value.frequency,
                    items: [
                      for (final frequency in RecurrenceFrequency.values)
                        ComboBoxItem(
                          value: frequency,
                          child: Text(_frequencyLabel(l10n, frequency)),
                        ),
                    ],
                    onChanged: (frequency) {
                      if (frequency == null) return;
                      setState(
                        () => value = _ruleForFrequency(frequency, baseDate),
                      );
                    },
                  ),
                ),
                if (value.repeats) ...[
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.repeatEvery,
                    child: NumberBox<int>(
                      value: value.interval,
                      min: 1,
                      max: 366,
                      mode: SpinButtonPlacementMode.inline,
                      onChanged: (interval) {
                        if (interval != null) {
                          setState(
                            () => value = value.copyWith(interval: interval),
                          );
                        }
                      },
                    ),
                  ),
                ],
                if (value.frequency == RecurrenceFrequency.weekly) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.repeatOn,
                    style: FluentTheme.of(context).typography.bodyStrong,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final day in rfcWeekdays)
                        ToggleButton(
                          checked: value.byDay.contains(day),
                          onChanged: (checked) => setState(() {
                            final days = [...value.byDay];
                            if (checked) {
                              if (!days.contains(day)) days.add(day);
                            } else if (days.length > 1) {
                              days.remove(day);
                            }
                            days.sort(
                              (a, b) => rfcWeekdays
                                  .indexOf(a)
                                  .compareTo(rfcWeekdays.indexOf(b)),
                            );
                            value = value.copyWith(byDay: days);
                          }),
                          child: Text(_weekdayLabel(context, day)),
                        ),
                    ],
                  ),
                ],
                if (value.repeats) ...[
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: l10n.repeatEnd,
                    child: ComboBox<_WindowsRecurrenceEnd>(
                      isExpanded: true,
                      value: end,
                      items: [
                        ComboBoxItem(
                          value: _WindowsRecurrenceEnd.never,
                          child: Text(l10n.repeatNever),
                        ),
                        ComboBoxItem(
                          value: _WindowsRecurrenceEnd.until,
                          child: Text(l10n.repeatUntil),
                        ),
                        ComboBoxItem(
                          value: _WindowsRecurrenceEnd.count,
                          child: Text(l10n.repeatAfter),
                        ),
                      ],
                      onChanged: (selection) {
                        if (selection == null) return;
                        setState(() {
                          end = selection;
                          value = switch (selection) {
                            _WindowsRecurrenceEnd.never => value.copyWith(
                              count: null,
                              untilRaw: null,
                            ),
                            _WindowsRecurrenceEnd.until =>
                              value
                                  .copyWith(count: null)
                                  .withUntilDate(
                                    _dateValue(until ?? baseDate),
                                    allDay: allDay,
                                    baseDate: baseDate,
                                    timeZone: timeZone,
                                  ),
                            _WindowsRecurrenceEnd.count => value.copyWith(
                              count: value.count ?? 10,
                              untilRaw: null,
                            ),
                          };
                        });
                      },
                    ),
                  ),
                  if (end == _WindowsRecurrenceEnd.until) ...[
                    const SizedBox(height: 12),
                    DatePicker(
                      selected: until ?? baseDate,
                      startDate: baseDate,
                      onChanged: (date) => setState(() {
                        until = date;
                        value = value.withUntilDate(
                          _dateValue(date),
                          allDay: allDay,
                          baseDate: baseDate,
                          timeZone: timeZone,
                        );
                      }),
                    ),
                  ],
                  if (end == _WindowsRecurrenceEnd.count) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.repeatCount,
                      child: NumberBox<int>(
                        value: value.count ?? 10,
                        min: 1,
                        max: 3500,
                        mode: SpinButtonPlacementMode.inline,
                        onChanged: (count) {
                          if (count != null) {
                            setState(
                              () => value = value.copyWith(count: count),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
                if (!valid) ...[
                  const SizedBox(height: 12),
                  InfoBar(
                    title: Text(
                      l10n.recurrenceUnsupportedByProvider(providerLabel),
                    ),
                    severity: InfoBarSeverity.warning,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: valid
                  ? () => Navigator.pop(dialogContext, value)
                  : null,
              child: Text(l10n.save),
            ),
          ],
        );
      },
    ),
  );
}

RecurrenceRule _ruleForFrequency(
  RecurrenceFrequency frequency,
  DateTime baseDate,
) {
  if (frequency == RecurrenceFrequency.none) {
    return const RecurrenceRule.none();
  }
  return RecurrenceRule(
    frequency: frequency,
    interval: 1,
    byDay: frequency == RecurrenceFrequency.weekly
        ? [_rfcWeekday(baseDate.weekday)]
        : const [],
    byMonth: frequency == RecurrenceFrequency.yearly
        ? [baseDate.month]
        : const [],
    byMonthDay:
        frequency == RecurrenceFrequency.monthly ||
            frequency == RecurrenceFrequency.yearly
        ? [baseDate.day]
        : const [],
    bySetPosition: null,
    count: null,
    untilRaw: null,
    recurrenceDates: const [],
    exceptionDates: const [],
    rawRules: const [],
    isSupported: true,
  );
}

String _frequencyLabel(AppLocalizations l10n, RecurrenceFrequency frequency) =>
    switch (frequency) {
      RecurrenceFrequency.none => l10n.repeatNone,
      RecurrenceFrequency.daily => l10n.repeatDaily,
      RecurrenceFrequency.weekly => l10n.repeatWeekly,
      RecurrenceFrequency.monthly => l10n.repeatMonthly,
      RecurrenceFrequency.yearly => l10n.repeatYearly,
    };

String _rfcWeekday(int weekday) => rfcWeekdays[weekday - 1];

String _weekdayLabel(BuildContext context, String weekday) {
  final day = rfcWeekdays.indexOf(weekday) + 1;
  final date = DateTime(2024, 1, day);
  return DateFormat.E(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(date);
}

String _dateValue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
