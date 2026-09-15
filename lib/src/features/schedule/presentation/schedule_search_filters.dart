import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';
import '../../../app/busymax_design.dart';

import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_search_criteria.dart';
import '../../../schedule/schedule_filters.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../task_lists/data/task_lists_repository.dart';
import 'schedule_search_labels.dart';

/// Compact Yaru search controls for the existing Schedule sidebar.
/// This widget only emits immutable criteria; it never writes source settings.
class ScheduleSearchFilters extends StatelessWidget {
  const ScheduleSearchFilters({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onClear,
    required this.accounts,
    required this.sources,
    required this.taskLists,
  });
  final ScheduleSearchCriteria value;
  final ValueChanged<ScheduleSearchCriteria> onChanged;
  final VoidCallback onClear;
  final List<AccountEntity> accounts;
  final List<CalendarSourceEntity> sources;
  final List<TaskListEntity> taskLists;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      key: const ValueKey('schedule-search-filters'),
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Text(l.searchFilters, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        _select(
          l.searchType,
          value.type,
          ScheduleSearchType.values,
          (v) => searchTypeLabel(l, v),
          (v) => onChanged(value.copyWith(type: v)),
        ),
        _select(
          l.searchDate,
          value.date,
          ScheduleSearchDate.values,
          (v) => searchDateLabel(l, v),
          (v) => onChanged(value.copyWith(date: v)),
        ),
        if (value.date == ScheduleSearchDate.custom) ...[
          _date(
            context,
            l.startDate,
            value.customStart ?? value.referenceDate,
            true,
          ),
          _date(
            context,
            l.endDate,
            value.customEnd ?? value.referenceDate,
            false,
          ),
        ],
        if (value.includesTasks) ...[
          _select(
            l.searchTaskStatus,
            value.taskCompletion,
            ScheduleTaskCompletion.values,
            (v) => searchCompletionLabel(l, v),
            (v) => onChanged(value.copyWith(taskCompletion: v)),
          ),
          _select(
            l.searchTaskDue,
            value.taskDueState,
            ScheduleTaskDueState.values,
            (v) => searchDueLabel(l, v),
            (v) => onChanged(value.copyWith(taskDueState: v)),
          ),
        ],
        if (value.includesEvents)
          _text(
            l.searchPerson,
            value.person,
            (v) => onChanged(value.copyWith(person: v)),
          ),
        _text(
          l.location,
          value.location,
          (v) => onChanged(value.copyWith(location: v)),
        ),
        Text(l.searchSources, style: Theme.of(context).textTheme.titleSmall),
        for (final account in accounts) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 12, bottom: 4),
            child: Text(
              account.displayLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          if (value.includesEvents)
            for (final source in sources.where(
              (s) => s.accountId == account.id && !s.isDeleted,
            ))
              YaruCheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(source.summary),
                secondary: const Icon(Icons.calendar_month_outlined, size: 18),
                value: value.sourceIds.contains(source.id),
                onChanged: (selected) {
                  final ids = {...value.sourceIds};
                  if (selected == true) {
                    ids.add(source.id);
                  } else {
                    ids.remove(source.id);
                  }
                  onChanged(value.copyWith(sourceIds: ids));
                },
              ),
          if (value.includesTasks)
            for (final list in taskLists.where(
              (s) => s.accountId == account.id && !s.pendingDelete,
            ))
              YaruCheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(list.title),
                secondary: const Icon(Icons.checklist, size: 18),
                value: value.taskListKeys.contains(
                  ScheduleTaskListKey(
                    accountId: list.accountId,
                    taskListId: list.id,
                  ),
                ),
                onChanged: (selected) {
                  final keys = {...value.taskListKeys};
                  final key = ScheduleTaskListKey(
                    accountId: list.accountId,
                    taskListId: list.id,
                  );
                  if (selected == true) {
                    keys.add(key);
                  } else {
                    keys.remove(key);
                  }
                  onChanged(value.copyWith(taskListKeys: keys));
                },
              ),
        ],
        if (!value.hasSources)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
            child: Text(l.searchNoSources),
          ),
        const SizedBox(height: 12),
        TextButton(onPressed: onClear, child: Text(l.searchClearFilters)),
      ],
    );
  }

  Widget _select<T>(
    String label,
    T selected,
    List<T> values,
    String Function(T) name,
    ValueChanged<T> changed,
  ) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 12),
    child: BusyMaxComboRow<T>(
      title: label,
      values: values,
      selected: selected,
      labelFor: name,
      onSelected: changed,
    ),
  );

  Widget _text(String label, String text, ValueChanged<String> changed) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 16),
        child: _SearchFilterText(label: label, value: text, onChanged: changed),
      );

  Widget _date(
    BuildContext context,
    String label,
    DateTime date,
    bool start,
  ) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 8),
    child: OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
        );
        if (picked == null) return;
        final from = start ? picked : value.customStart ?? value.referenceDate;
        final to = start ? value.customEnd ?? value.referenceDate : picked;
        onChanged(
          value.copyWith(
            customStart: from.isAfter(to) ? picked : from,
            customEnd: to.isBefore(from) ? picked : to,
          ),
        );
      },
      child: Text(
        '$label: ${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(date)}',
      ),
    ),
  );
}

class _SearchFilterText extends StatefulWidget {
  const _SearchFilterText({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  State<_SearchFilterText> createState() => _SearchFilterTextState();
}

class _SearchFilterTextState extends State<_SearchFilterText> {
  late final _controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant _SearchFilterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(labelText: widget.label),
    onChanged: widget.onChanged,
  );
}
