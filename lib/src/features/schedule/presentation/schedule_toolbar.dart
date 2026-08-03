import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_glyphs.dart';
import '../../../app/busymax_shortcuts.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/localized_formatters.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_view_mode.dart';

enum ScheduleToolbarMenuAction {
  refresh,
  settings,
  keyboardShortcuts,
  reportIssue,
  about,
}

enum _ScheduleCreateAction { event, task }

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
    required this.canCreateEvent,
    required this.canCreateTask,
    required this.onCreateEvent,
    required this.onCreateTask,
    required this.onRefresh,
    this.canRefresh = true,
    this.canShowSidebar = false,
    this.sidebarVisible = false,
    this.onToggleSidebar,
    this.onSearch,
    this.onMenuSelected,
    this.createMenuController,
  });

  final ScheduleViewMode mode;
  final ScheduleRange range;
  final DateTime selectedDate;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<ScheduleViewMode> onModeChanged;
  final bool canCreateEvent;
  final bool canCreateTask;
  final VoidCallback onCreateEvent;
  final VoidCallback onCreateTask;
  final VoidCallback onRefresh;
  final bool canRefresh;
  final bool canShowSidebar;
  final bool sidebarVisible;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onSearch;
  final ValueChanged<ScheduleToolbarMenuAction>? onMenuSelected;
  final BusyMaxMenuController? createMenuController;

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
                  tooltip: _shortcutTooltip(
                    sidebarVisible
                        ? context.l10n.hideSidebar
                        : context.l10n.showSidebar,
                    BusyMaxShortcutLabels.sidebar,
                  ),
                  icon: Icon(
                    sidebarVisible
                        ? Icons.vertical_split
                        : Icons.vertical_split_outlined,
                  ),
                  onPressed: onToggleSidebar,
                ),
              Tooltip(
                message: _shortcutTooltip(
                  context.l10n.today,
                  BusyMaxShortcutLabels.today,
                ),
                child: BusyMaxPushButton.standard(
                  onPressed: onToday,
                  child: Text(context.l10n.today),
                ),
              ),
              const SizedBox(width: BusyMaxSpacing.sm),
              if (showPaging) ...[
                YaruIconButton(
                  tooltip: _shortcutTooltip(
                    MaterialLocalizations.of(context).previousPageTooltip,
                    BusyMaxShortcutLabels.previousPeriod,
                  ),
                  icon: Icon(
                    BusyMaxGlyphs.previousFor(Directionality.of(context)),
                  ),
                  onPressed: onPrevious,
                ),
                YaruIconButton(
                  tooltip: _shortcutTooltip(
                    MaterialLocalizations.of(context).nextPageTooltip,
                    BusyMaxShortcutLabels.nextPeriod,
                  ),
                  icon: Icon(BusyMaxGlyphs.nextFor(Directionality.of(context))),
                  onPressed: onNext,
                ),
                const SizedBox(width: BusyMaxSpacing.sm),
              ],
              Expanded(
                child: _fittingRangeTitle(
                  context,
                  _rangeLabel(context, mode, range, selectedDate),
                ),
              ),
              BusyMaxMenuButton<ScheduleViewMode>(
                tooltip: _shortcutTooltip(
                  _modeLabel(context, mode),
                  BusyMaxShortcutLabels.forViewMode(mode),
                ),
                icon: Icon(_modeIcon(mode)),
                entries: [
                  for (final value in ScheduleViewMode.values)
                    BusyMaxMenuEntry(
                      value: value,
                      label: _modeLabel(context, value),
                      icon: _modeIcon(value),
                      selected: mode == value,
                      shortcut: BusyMaxShortcutLabels.forViewMode(value),
                    ),
                ],
                onSelected: onModeChanged,
              ),
              if (onSearch != null)
                YaruIconButton(
                  tooltip: _shortcutTooltip(
                    MaterialLocalizations.of(context).searchFieldLabel,
                    BusyMaxShortcutLabels.search,
                  ),
                  icon: const Icon(YaruIcons.search),
                  onPressed: onSearch,
                ),
              BusyMaxMenuButton<_ScheduleCreateAction>(
                tooltip: context.l10n.create,
                icon: const Icon(YaruIcons.plus),
                controller: createMenuController,
                enabled: canCreateEvent || canCreateTask,
                entries: [
                  BusyMaxMenuEntry(
                    value: _ScheduleCreateAction.event,
                    label: context.l10n.createEventAtTime,
                    icon: Icons.event_outlined,
                    enabled: canCreateEvent,
                    shortcut: BusyMaxShortcutLabels.newEvent,
                  ),
                  BusyMaxMenuEntry(
                    value: _ScheduleCreateAction.task,
                    label: context.l10n.createTaskAtDate,
                    icon: Icons.task_alt_outlined,
                    enabled: canCreateTask,
                    shortcut: BusyMaxShortcutLabels.newTask,
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case _ScheduleCreateAction.event:
                      onCreateEvent();
                    case _ScheduleCreateAction.task:
                      onCreateTask();
                  }
                },
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
                      shortcut: BusyMaxShortcutLabels.settings,
                    ),
                    BusyMaxMenuEntry(
                      value: ScheduleToolbarMenuAction.keyboardShortcuts,
                      label: context.l10n.keyboardShortcuts,
                      icon: Icons.keyboard_alt_outlined,
                      shortcut: BusyMaxShortcutLabels.keyboardShortcuts,
                    ),
                    BusyMaxMenuEntry(
                      value: ScheduleToolbarMenuAction.reportIssue,
                      label: context.l10n.reportAnIssue,
                      icon: YaruIcons.warning,
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

Widget _fittingRangeTitle(BuildContext context, String title) {
  final style = busyMaxHeaderTitleStyle(context);
  return LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final titleFits = painter.width <= constraints.maxWidth;
      painter.dispose();
      if (!titleFits) {
        return const SizedBox.shrink();
      }
      return Text(title, maxLines: 1, style: style);
    },
  );
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
    ScheduleViewMode.week => localizedScheduleRangeLabel(locale, range),
  };
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

String _shortcutTooltip(String label, String shortcut) => '$label ($shortcut)';
