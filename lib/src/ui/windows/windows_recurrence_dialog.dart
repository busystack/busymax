import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../features/recurrence/domain/recurrence_editing.dart';

Future<RecurrenceRule?> showWindowsRecurrenceDialog(
  BuildContext context, {
  required RecurrenceRule initial,
  required DateTime baseDate,
  required bool allDay,
  required String timeZone,
  required String providerLabel,
  required RecurrenceRuleLimits limits,
  bool floating = false,
}) {
  var value = initial;
  var intervalInputValid = true;
  var countInputValid = true;
  var until = DateTime.tryParse(value.untilDateFor(timeZone: timeZone) ?? '');
  return showDialog<RecurrenceRule>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        final end = value.endMode;
        final providerSupported = limits.supports(value);
        final valid =
            providerSupported &&
            (!value.repeats || intervalInputValid) &&
            (end != RecurrenceEnd.count || countInputValid);
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
                    value: value.isSupported ? value.frequency : null,
                    items: [
                      for (final frequency in RecurrenceFrequency.values)
                        ComboBoxItem(
                          value: frequency,
                          child: Text(_frequencyLabel(l10n, frequency)),
                        ),
                    ],
                    onChanged: (frequency) {
                      if (frequency == null) return;
                      if (value.isSupported && frequency == value.frequency) {
                        return;
                      }
                      setState(() {
                        value = value.withFrequency(frequency, baseDate);
                        intervalInputValid = true;
                        countInputValid = true;
                      });
                    },
                  ),
                ),
                if (value.isSupported && value.repeats) ...[
                  const SizedBox(height: 12),
                  InfoLabel(
                    label: l10n.repeatEvery,
                    child: NumberBox<int>(
                      key: ValueKey((value.frequency, 'interval')),
                      value: value.interval,
                      min: 1,
                      max: 366,
                      mode: SpinButtonPlacementMode.inline,
                      onChanged: (interval) => setState(() {
                        intervalInputValid = interval != null;
                        if (interval != null) {
                          value = value.copyWith(interval: interval);
                        }
                      }),
                    ),
                  ),
                ],
                if (value.isSupported &&
                    value.frequency == RecurrenceFrequency.weekly) ...[
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
                if (value.isSupported && value.repeats) ...[
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: l10n.repeatEnd,
                    child: ComboBox<RecurrenceEnd>(
                      isExpanded: true,
                      value: end,
                      items: [
                        ComboBoxItem(
                          value: RecurrenceEnd.never,
                          child: Text(l10n.repeatNever),
                        ),
                        ComboBoxItem(
                          value: RecurrenceEnd.until,
                          child: Text(l10n.repeatUntil),
                        ),
                        ComboBoxItem(
                          value: RecurrenceEnd.count,
                          child: Text(l10n.repeatAfter),
                        ),
                      ],
                      onChanged: (selection) {
                        if (selection == null) return;
                        setState(() {
                          countInputValid = true;
                          value = value.withEndMode(
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
                  ),
                  if (end == RecurrenceEnd.until) ...[
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
                          floating: floating,
                        );
                      }),
                    ),
                  ],
                  if (end == RecurrenceEnd.count) ...[
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: l10n.repeatCount,
                      child: NumberBox<int>(
                        key: ValueKey((value.frequency, 'count')),
                        value: value.count ?? 10,
                        min: 1,
                        max: 3500,
                        mode: SpinButtonPlacementMode.inline,
                        onChanged: (count) => setState(() {
                          countInputValid = count != null;
                          if (count != null) {
                            value = value.copyWith(count: count);
                          }
                        }),
                      ),
                    ),
                  ],
                ],
                if (!providerSupported) ...[
                  const SizedBox(height: 12),
                  InfoBar(
                    title: Text(
                      value.isSupported
                          ? l10n.recurrenceUnsupportedByProvider(providerLabel)
                          : l10n.unsupportedRecurrencePreserved,
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

String _frequencyLabel(AppLocalizations l10n, RecurrenceFrequency frequency) =>
    switch (frequency) {
      RecurrenceFrequency.none => l10n.repeatNone,
      RecurrenceFrequency.daily => l10n.repeatDaily,
      RecurrenceFrequency.weekly => l10n.repeatWeekly,
      RecurrenceFrequency.monthly => l10n.repeatMonthly,
      RecurrenceFrequency.yearly => l10n.repeatYearly,
    };

String _weekdayLabel(BuildContext context, String weekday) {
  final day = rfcWeekdays.indexOf(weekday) + 1;
  final date = DateTime(2024, 1, day);
  return DateFormat.E(Localizations.localeOf(context).toLanguageTag())
      .format(date);
}

String _dateValue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
