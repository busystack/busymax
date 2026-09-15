import 'package:fluent_ui/fluent_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../features/schedule/presentation/schedule_search_labels.dart';
import '../../schedule/schedule_search_criteria.dart';
import '../../schedule/schedule_filters.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';

class WindowsScheduleSearchPane extends StatelessWidget {
  const WindowsScheduleSearchPane({
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
    final l = AppLocalizations.of(context);
    return ListView(
      key: const ValueKey('windows-search-filters'),
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Text(
          l.searchFilters,
          style: FluentTheme.of(context).typography.subtitle,
        ),
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
          _date(l.startDate, value.customStart ?? value.referenceDate, true),
          _date(l.endDate, value.customEnd ?? value.referenceDate, false),
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
        Text(
          l.searchSources,
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        for (final account in accounts) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 12, bottom: 8),
            child: Text(
              account.displayLabel,
              style: FluentTheme.of(context).typography.bodyStrong,
            ),
          ),
          if (value.includesEvents)
            for (final source in sources.where(
              (s) => s.accountId == account.id && !s.isDeleted,
            ))
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: _sourceToggle(
                  source.summary,
                  BusyMaxGlyph.calendar,
                  checked: value.sourceIds.contains(source.id),
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
              ),
          if (value.includesTasks)
            for (final list in taskLists.where(
              (s) => s.accountId == account.id && !s.pendingDelete,
            ))
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: _sourceToggle(
                  list.title,
                  BusyMaxGlyph.task,
                  checked: value.taskListKeys.contains(
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
              ),
        ],
        if (!value.hasSources)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
            child: Text(l.searchNoSources),
          ),
        const SizedBox(height: 12),
        Button(onPressed: onClear, child: Text(l.searchClearFilters)),
      ],
    );
  }

  Widget _sourceToggle(
    String title,
    BusyMaxGlyph glyph, {
    required bool checked,
    required ValueChanged<bool?> onChanged,
  }) => LayoutBuilder(
    builder: (context, constraints) => Checkbox(
      checked: checked,
      onChanged: onChanged,
      content: SizedBox(
        width: (constraints.maxWidth - 36).clamp(0, double.infinity),
        child: Row(
          children: [
            Icon(windowsBusyMaxGlyph(glyph), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _select<T>(
    String label,
    T selected,
    List<T> values,
    String Function(T) name,
    ValueChanged<T> changed,
  ) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 12),
    child: InfoLabel(
      label: label,
      child: ComboBox<T>(
        isExpanded: true,
        value: selected,
        items: [
          for (final v in values) ComboBoxItem(value: v, child: Text(name(v))),
        ],
        onChanged: (v) {
          if (v != null) changed(v);
        },
      ),
    ),
  );
  Widget _text(String label, String text, ValueChanged<String> changed) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 16),
        child: _FilterText(label: label, value: text, onChanged: changed),
      );
  Widget _date(String label, DateTime date, bool start) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 12),
    child: InfoLabel(
      label: label,
      child: DatePicker(
        startDate: DateTime(1900),
        endDate: DateTime(2200),
        selected: date,
        onChanged: (picked) {
          final day = DateTime(picked.year, picked.month, picked.day);
          final from = start ? day : value.customStart ?? value.referenceDate;
          final to = start ? value.customEnd ?? value.referenceDate : day;
          onChanged(
            value.copyWith(
              customStart: from.isAfter(to) ? day : from,
              customEnd: to.isBefore(from) ? day : to,
            ),
          );
        },
      ),
    ),
  );
}

class _FilterText extends StatefulWidget {
  const _FilterText({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  State<_FilterText> createState() => _FilterTextState();
}

class _FilterTextState extends State<_FilterText> {
  late final _controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant _FilterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InfoLabel(
    label: widget.label,
    child: TextBox(controller: _controller, onChanged: widget.onChanged),
  );
}
