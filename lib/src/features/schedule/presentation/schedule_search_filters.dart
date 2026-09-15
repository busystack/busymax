import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_filters.dart';
import '../../../schedule/schedule_search_criteria.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../../tasks/presentation/desktop_date_time_fields.dart';
import 'schedule_search_labels.dart';

/// BusyMax/Yaru search controls for the existing Schedule sidebar or dialog.
///
/// This widget emits immutable criteria only. Source switches never write the
/// persistent Calendar or Task List visibility settings.
class ScheduleSearchFilters extends StatelessWidget {
  const ScheduleSearchFilters({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onClear,
    required this.accounts,
    required this.sources,
    required this.taskLists,
    this.sidebar = true,
  });

  final ScheduleSearchCriteria value;
  final ValueChanged<ScheduleSearchCriteria> onChanged;
  final VoidCallback onClear;
  final List<AccountEntity> accounts;
  final List<CalendarSourceEntity> sources;
  final List<TaskListEntity> taskLists;

  /// Whether this presentation owns the standard Schedule sidebar surface.
  ///
  /// The narrow dialog sets this to false because [BusyMaxDialogShell] owns
  /// its surface and scrolling.
  final bool sidebar;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final children = <Widget>[
      BusyMaxGroupedList(
        title: sidebar ? l10n.searchFilters : null,
        filled: true,
        children: [
          BusyMaxComboRow<ScheduleSearchType>(
            title: l10n.searchType,
            values: ScheduleSearchType.values,
            selected: value.type,
            labelFor: (type) => searchTypeLabel(l10n, type),
            onSelected: (type) => onChanged(value.copyWith(type: type)),
          ),
          BusyMaxComboRow<ScheduleSearchDate>(
            title: l10n.searchDate,
            values: ScheduleSearchDate.values,
            selected: value.date,
            labelFor: (date) => searchDateLabel(l10n, date),
            onSelected: (date) => onChanged(value.copyWith(date: date)),
          ),
          if (value.date == ScheduleSearchDate.custom) ...[
            _dateRow(
              l10n.startDate,
              value.customStart ?? value.referenceDate,
              start: true,
            ),
            _dateRow(
              l10n.endDate,
              value.customEnd ?? value.referenceDate,
              start: false,
            ),
          ],
          if (value.includesTasks) ...[
            BusyMaxComboRow<ScheduleTaskCompletion>(
              title: l10n.searchTaskStatus,
              values: ScheduleTaskCompletion.values,
              selected: value.taskCompletion,
              labelFor: (completion) => searchCompletionLabel(l10n, completion),
              onSelected: (completion) =>
                  onChanged(value.copyWith(taskCompletion: completion)),
            ),
            BusyMaxComboRow<ScheduleTaskDueState>(
              title: l10n.searchTaskDue,
              values: ScheduleTaskDueState.values,
              selected: value.taskDueState,
              labelFor: (dueState) => searchDueLabel(l10n, dueState),
              onSelected: (dueState) =>
                  onChanged(value.copyWith(taskDueState: dueState)),
            ),
          ],
        ],
      ),
      BusyMaxGroupedList(
        filled: true,
        children: [
          if (value.includesEvents)
            _SearchFilterTextRow(
              key: const ValueKey('schedule-search-person'),
              label: l10n.searchPerson,
              value: value.person,
              icon: YaruIcons.user,
              onChanged: (person) => onChanged(value.copyWith(person: person)),
            ),
          _SearchFilterTextRow(
            key: const ValueKey('schedule-search-location'),
            label: l10n.location,
            value: value.location,
            icon: Icons.location_on_outlined,
            onChanged: (location) =>
                onChanged(value.copyWith(location: location)),
          ),
        ],
      ),
      ..._sourceGroups(),
      if (!value.hasSources)
        BusyMaxGroupedList(
          title: l10n.searchSources,
          filled: true,
          children: [
            YaruListTile.square(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.searchNoSources),
            ),
          ],
        ),
      BusyMaxGroupedList(
        filled: true,
        children: [
          BusyMaxActionRow(
            key: const ValueKey('schedule-search-clear-filters'),
            title: l10n.searchClearFilters,
            leading: const Icon(YaruIcons.refresh),
            onTap: onClear,
          ),
        ],
      ),
      const SizedBox(height: BusyMaxSpacing.lg),
    ];

    if (!sidebar) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return BusyMaxSidebarSurface(
      child: ListView(
        key: const ValueKey('schedule-search-filters'),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BusyMaxSpacing.sm,
        ),
        children: children,
      ),
    );
  }

  List<Widget> _sourceGroups() {
    final groups = <Widget>[];
    for (final account in accounts) {
      final rows = <Widget>[
        if (value.includesEvents)
          for (final source in sources.where(
            (source) => source.accountId == account.id && !source.isDeleted,
          ))
            BusyMaxSwitchRow(
              key: ValueKey(('schedule-search-source', source.id)),
              title: source.summary,
              value: value.sourceIds.contains(source.id),
              leading: const Icon(YaruIcons.calendar),
              onChanged: (selected) {
                final ids = {...value.sourceIds};
                if (selected) {
                  ids.add(source.id);
                } else {
                  ids.remove(source.id);
                }
                onChanged(value.copyWith(sourceIds: ids));
              },
            ),
        if (value.includesTasks)
          for (final list in taskLists.where(
            (list) => list.accountId == account.id && !list.pendingDelete,
          ))
            BusyMaxSwitchRow(
              key: ValueKey((
                'schedule-search-task-list',
                list.accountId,
                list.id,
              )),
              title: list.title,
              value: value.taskListKeys.contains(
                ScheduleTaskListKey(
                  accountId: list.accountId,
                  taskListId: list.id,
                ),
              ),
              leading: const Icon(YaruIcons.task_list),
              onChanged: (selected) {
                final keys = {...value.taskListKeys};
                final key = ScheduleTaskListKey(
                  accountId: list.accountId,
                  taskListId: list.id,
                );
                if (selected) {
                  keys.add(key);
                } else {
                  keys.remove(key);
                }
                onChanged(value.copyWith(taskListKeys: keys));
              },
            ),
      ];
      if (rows.isEmpty) {
        continue;
      }
      groups.add(
        BusyMaxGroupedList(
          title: account.displayLabel,
          filled: true,
          children: rows,
        ),
      );
    }

    return groups;
  }

  Widget _dateRow(String label, DateTime date, {required bool start}) {
    return DesktopDateValueRow(
      label: label,
      date: encodeDateOnly(date),
      useNativePicker: true,
      onChanged: (date) {
        final picked = DateTime.parse(date);
        final from = start ? picked : value.customStart ?? value.referenceDate;
        final to = start ? value.customEnd ?? value.referenceDate : picked;
        onChanged(
          value.copyWith(
            customStart: from.isAfter(to) ? picked : from,
            customEnd: to.isBefore(from) ? picked : to,
          ),
        );
      },
    );
  }
}

class _SearchFilterTextRow extends StatefulWidget {
  const _SearchFilterTextRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final String value;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchFilterTextRow> createState() => _SearchFilterTextRowState();
}

class _SearchFilterTextRowState extends State<_SearchFilterTextRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _SearchFilterTextRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text == widget.value) {
      return;
    }
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YaruListTile.square(
      leading: Icon(widget.icon),
      title: TextField(
        controller: _controller,
        decoration: busyMaxGroupedTextFieldDecoration(
          context,
          labelText: widget.label,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
