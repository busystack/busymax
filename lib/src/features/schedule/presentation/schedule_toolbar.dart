import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_view_mode.dart';

enum ScheduleToolbarMenuAction { refresh, settings, keyboardShortcuts, about }

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
    required this.canCreate,
    required this.onCreate,
    required this.onRefresh,
    this.canRefresh = true,
    this.canShowSidebar = false,
    this.sidebarVisible = false,
    this.onToggleSidebar,
    this.onSearch,
    this.onMenuSelected,
  });

  final ScheduleViewMode mode;
  final ScheduleRange range;
  final DateTime selectedDate;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<ScheduleViewMode> onModeChanged;
  final bool canCreate;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;
  final bool canRefresh;
  final bool canShowSidebar;
  final bool sidebarVisible;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onSearch;
  final ValueChanged<ScheduleToolbarMenuAction>? onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final showPaging = mode != ScheduleViewMode.agenda;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SizedBox(
          height: BusyMaxSizes.toolbarHeight,
          child: Row(
            children: [
              const SizedBox(width: BusyMaxSpacing.sm),
              if (canShowSidebar && onToggleSidebar != null)
                YaruIconButton(
                  tooltip: context.l10n.toggleSidebar,
                  icon: Icon(
                    sidebarVisible
                        ? Icons.vertical_split
                        : Icons.vertical_split_outlined,
                  ),
                  onPressed: onToggleSidebar,
                ),
              BusyMaxPushButton.outlined(
                onPressed: onToday,
                child: Text(context.l10n.today),
              ),
              const SizedBox(width: BusyMaxSpacing.sm),
              if (showPaging) ...[
                YaruIconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).previousPageTooltip,
                  icon: const Icon(YaruIcons.arrow_left),
                  onPressed: onPrevious,
                ),
                YaruIconButton(
                  tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                  icon: const Icon(YaruIcons.arrow_right),
                  onPressed: onNext,
                ),
                const SizedBox(width: BusyMaxSpacing.sm),
              ],
              Expanded(
                child: Text(
                  _rangeLabel(context, mode, range, selectedDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              BusyMaxMenuButton<ScheduleViewMode>(
                tooltip: _modeLabel(context, mode),
                icon: Icon(_modeIcon(mode)),
                entries: [
                  for (final value in ScheduleViewMode.values)
                    BusyMaxMenuEntry(
                      value: value,
                      label: _modeLabel(context, value),
                      icon: _modeIcon(value),
                      checked: mode == value,
                    ),
                ],
                onSelected: onModeChanged,
              ),
              if (onSearch != null)
                YaruIconButton(
                  tooltip: MaterialLocalizations.of(context).searchFieldLabel,
                  icon: const Icon(YaruIcons.search),
                  onPressed: onSearch,
                ),
              YaruIconButton(
                tooltip: context.l10n.create,
                icon: const Icon(YaruIcons.plus),
                onPressed: canCreate ? onCreate : null,
              ),
              if (!compact)
                YaruIconButton(
                  tooltip: context.l10n.refreshAll,
                  icon: const Icon(YaruIcons.refresh),
                  onPressed: canRefresh ? onRefresh : null,
                ),
              if (onMenuSelected != null)
                BusyMaxMenuButton<ScheduleToolbarMenuAction>(
                  tooltip: context.l10n.mainMenu,
                  entries: [
                    if (compact)
                      BusyMaxMenuEntry(
                        value: ScheduleToolbarMenuAction.refresh,
                        label: context.l10n.refreshAll,
                        icon: YaruIcons.refresh,
                        enabled: canRefresh,
                      ),
                    BusyMaxMenuEntry(
                      value: ScheduleToolbarMenuAction.settings,
                      label: context.l10n.settings,
                      icon: YaruIcons.settings,
                    ),
                    BusyMaxMenuEntry(
                      value: ScheduleToolbarMenuAction.keyboardShortcuts,
                      label: context.l10n.keyboardShortcuts,
                      icon: Icons.keyboard_alt_outlined,
                    ),
                    BusyMaxMenuEntry(
                      value: ScheduleToolbarMenuAction.about,
                      label: context.l10n.aboutBusyMax,
                      icon: Icons.info_outline,
                    ),
                  ],
                  onSelected: onMenuSelected!,
                ),
              const SizedBox(width: BusyMaxSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

IconData _modeIcon(ScheduleViewMode mode) {
  return switch (mode) {
    ScheduleViewMode.day => Icons.calendar_view_day_outlined,
    ScheduleViewMode.week => Icons.view_week_outlined,
    ScheduleViewMode.month => Icons.calendar_view_month,
    ScheduleViewMode.year => Icons.calendar_today_outlined,
    ScheduleViewMode.agenda => Icons.view_agenda_outlined,
  };
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
    ScheduleViewMode.agenda => context.l10n.viewAgenda,
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
