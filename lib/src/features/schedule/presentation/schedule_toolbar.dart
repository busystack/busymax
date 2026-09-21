import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_shortcuts.dart';
import '../../../app/linux/linux_header_style.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/localized_formatters.dart';
import '../../../platform/gtk_header_icon_service.dart';
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
        return BusyMaxLinuxHeaderLayout(
          leading: BusyMaxLinuxHeaderControlGroup(
            key: const ValueKey('schedule-header-leading-actions'),
            children: [
              if (canShowSidebar && onToggleSidebar != null)
                BusyMaxLinuxHeaderIconButton(
                  key: const ValueKey('schedule-sidebar-button'),
                  tooltip: _shortcutTooltip(
                    sidebarVisible
                        ? context.l10n.hideSidebar
                        : context.l10n.showSidebar,
                    BusyMaxShortcutLabels.sidebar,
                  ),
                  icon: BusyMaxLinuxHeaderIcon.sidebar,
                  selected: sidebarVisible,
                  onPressed: onToggleSidebar,
                ),
              BusyMaxLinuxHeaderIconButton(
                key: const ValueKey('schedule-today-button'),
                tooltip: _shortcutTooltip(
                  context.l10n.today,
                  BusyMaxShortcutLabels.today,
                ),
                semanticLabel: context.l10n.today,
                icon: BusyMaxLinuxHeaderIcon.today,
                onPressed: onToday,
              ),
              if (showPaging) ...[
                BusyMaxLinuxHeaderIconButton(
                  key: const ValueKey('schedule-previous-button'),
                  tooltip: _shortcutTooltip(
                    MaterialLocalizations.of(context).previousPageTooltip,
                    BusyMaxShortcutLabels.previousPeriod,
                  ),
                  icon: BusyMaxLinuxHeaderIcon.previous,
                  onPressed: onPrevious,
                ),
                BusyMaxLinuxHeaderIconButton(
                  key: const ValueKey('schedule-next-button'),
                  tooltip: _shortcutTooltip(
                    MaterialLocalizations.of(context).nextPageTooltip,
                    BusyMaxShortcutLabels.nextPeriod,
                  ),
                  icon: BusyMaxLinuxHeaderIcon.next,
                  onPressed: onNext,
                ),
              ],
            ],
          ),
          title: _fittingRangeTitle(
            context,
            localizedScheduleHeading(
              Localizations.localeOf(context).toLanguageTag(),
              mode,
              range,
              selectedDate,
              agendaLabel: context.l10n.viewAgenda,
            ),
          ),
          trailing: BusyMaxLinuxHeaderControlGroup(
            key: const ValueKey('schedule-header-trailing-actions'),
            children: [
              BusyMaxLinuxViewMenuButton<ScheduleViewMode>(
                key: const ValueKey('schedule-view-button'),
                tooltip: _shortcutTooltip(
                  _modeLabel(context, mode),
                  BusyMaxShortcutLabels.forViewMode(mode),
                ),
                icon: _modeHeaderIcon(mode),
                entries: [
                  for (final value in ScheduleViewMode.values)
                    BusyMaxMenuEntry(
                      value: value,
                      label: _modeLabel(context, value),
                      icon: _modeMenuIcon(value),
                      role: BusyMaxMenuEntryRole.radio,
                      selected: mode == value,
                      shortcut: BusyMaxShortcutLabels.forViewMode(value),
                    ),
                ],
                onSelected: onModeChanged,
              ),
              BusyMaxLinuxHeaderMenuButton<_ScheduleCreateAction>(
                key: const ValueKey('schedule-create-button'),
                tooltip: context.l10n.create,
                icon: BusyMaxLinuxHeaderIcon.create,
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
                BusyMaxLinuxHeaderIconButton(
                  key: const ValueKey('schedule-refresh-button'),
                  tooltip: context.l10n.refreshAll,
                  icon: BusyMaxLinuxHeaderIcon.refresh,
                  onPressed: canRefresh ? onRefresh : null,
                ),
              if (onSearch != null)
                BusyMaxLinuxHeaderIconButton(
                  key: const ValueKey('schedule-search-button'),
                  tooltip: _shortcutTooltip(
                    MaterialLocalizations.of(context).searchFieldLabel,
                    BusyMaxShortcutLabels.search,
                  ),
                  icon: BusyMaxLinuxHeaderIcon.search,
                  onPressed: onSearch,
                ),
              if (onMenuSelected != null)
                BusyMaxMainMenuButton(
                  includeRefresh: compact,
                  canRefresh: canRefresh,
                  onSelected: onMenuSelected!,
                ),
            ],
          ),
        );
      },
    );
  }
}

class BusyMaxMainMenuButton extends StatelessWidget {
  const BusyMaxMainMenuButton({
    super.key,
    required this.onSelected,
    this.includeRefresh = false,
    this.canRefresh = false,
    this.settingsSelected = false,
  });

  final ValueChanged<ScheduleToolbarMenuAction> onSelected;
  final bool includeRefresh;
  final bool canRefresh;
  final bool settingsSelected;

  @override
  Widget build(BuildContext context) {
    return BusyMaxLinuxHeaderMenuButton<ScheduleToolbarMenuAction>(
      key: const ValueKey('busymax-main-menu-button'),
      tooltip: context.l10n.mainMenu,
      icon: BusyMaxLinuxHeaderIcon.mainMenu,
      entries: [
        if (includeRefresh)
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
          enabled: !settingsSelected,
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
      onSelected: onSelected,
    );
  }
}

Widget _fittingRangeTitle(BuildContext context, String title) {
  final style = busyMaxLinuxHeaderTitleStyle(context);
  return LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final titleFits =
          painter.width + BusyMaxSpacing.md * 2 <= constraints.maxWidth;
      painter.dispose();
      if (!titleFits) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: BusyMaxSpacing.md),
        child: Text(title, maxLines: 1, style: style),
      );
    },
  );
}

BusyMaxLinuxHeaderIcon _modeHeaderIcon(ScheduleViewMode mode) {
  return switch (mode) {
    ScheduleViewMode.day => BusyMaxLinuxHeaderIcon.viewDay,
    ScheduleViewMode.week => BusyMaxLinuxHeaderIcon.viewWeek,
    ScheduleViewMode.month => BusyMaxLinuxHeaderIcon.viewMonth,
    ScheduleViewMode.year => BusyMaxLinuxHeaderIcon.viewYear,
    ScheduleViewMode.agenda => BusyMaxLinuxHeaderIcon.viewAgenda,
  };
}

IconData _modeMenuIcon(ScheduleViewMode mode) {
  return switch (mode) {
    ScheduleViewMode.day => Icons.calendar_view_day_outlined,
    ScheduleViewMode.week => Icons.view_week_outlined,
    ScheduleViewMode.month => Icons.calendar_view_month,
    ScheduleViewMode.year => Icons.calendar_today_outlined,
    ScheduleViewMode.agenda => Icons.view_agenda_outlined,
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
