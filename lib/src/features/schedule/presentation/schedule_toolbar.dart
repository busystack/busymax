import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_view_mode.dart';

class ScheduleToolbar extends StatelessWidget {
  const ScheduleToolbar({
    super.key,
    required this.mode,
    required this.range,
    required this.selectedDate,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
    required this.onModeChanged,
    required this.onRefresh,
  });

  final ScheduleViewMode mode;
  final ScheduleRange range;
  final DateTime selectedDate;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<ScheduleViewMode> onModeChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: BusyMaxSizes.toolbarHeight,
      child: Row(
        children: [
          const SizedBox(width: BusyMaxSpacing.sm),
          BusyMaxPushButton.outlined(
            onPressed: onToday,
            child: Text(context.l10n.today),
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
          YaruIconButton(
            tooltip: MaterialLocalizations.of(context).previousPageTooltip,
            icon: const Icon(YaruIcons.arrow_left),
            onPressed: onPrevious,
          ),
          YaruIconButton(
            tooltip: MaterialLocalizations.of(context).nextPageTooltip,
            icon: const Icon(YaruIcons.arrow_right),
            onPressed: onNext,
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
          Expanded(
            child: Text(
              _rangeLabel(context, mode, range, selectedDate),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in ScheduleViewMode.values)
                    Padding(
                      padding: const EdgeInsets.only(right: BusyMaxSpacing.xs),
                      child: BusyMaxPushButton.outlined(
                        onPressed: mode == value
                            ? null
                            : () => onModeChanged(value),
                        child: Text(_modeLabel(context, value)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          YaruIconButton(
            tooltip: context.l10n.refreshAll,
            icon: const Icon(YaruIcons.refresh),
            onPressed: onRefresh,
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
        ],
      ),
    );
  }
}

String _rangeLabel(
  BuildContext context,
  ScheduleViewMode mode,
  ScheduleRange range,
  DateTime selectedDate,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return switch (mode) {
    ScheduleViewMode.day => DateFormat.yMMMMEEEEd(locale).format(selectedDate),
    ScheduleViewMode.month => DateFormat.yMMMM(locale).format(selectedDate),
    ScheduleViewMode.year => DateFormat.y(locale).format(selectedDate),
    ScheduleViewMode.agenda => _weekRange(locale, range),
    ScheduleViewMode.week => _weekRange(locale, range),
  };
}

String _weekRange(String locale, ScheduleRange range) {
  final end = range.end.subtract(const Duration(days: 1));
  if (range.start.year == end.year && range.start.month == end.month) {
    return '${DateFormat.MMMd(locale).format(range.start)}-${DateFormat.d(locale).format(end)}, ${DateFormat.y(locale).format(end)}';
  }
  if (range.start.year == end.year) {
    return '${DateFormat.MMMd(locale).format(range.start)} - ${DateFormat.MMMd(locale).format(end)}, ${DateFormat.y(locale).format(end)}';
  }
  return '${DateFormat.yMMMd(locale).format(range.start)} - ${DateFormat.yMMMd(locale).format(end)}';
}

String _modeLabel(BuildContext context, ScheduleViewMode mode) {
  return switch (mode) {
    ScheduleViewMode.day => context.l10n.viewDay,
    ScheduleViewMode.week => context.l10n.viewWeek,
    ScheduleViewMode.month => context.l10n.viewMonth,
    ScheduleViewMode.year => context.l10n.viewYear,
    ScheduleViewMode.agenda => context.l10n.viewAgenda,
  };
}
