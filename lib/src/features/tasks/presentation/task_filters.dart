import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';
import '../../../task_providers/task_provider.dart';
import '../data/tasks_repository.dart';
import 'tasks_selection_state.dart';

final taskViewFilterProvider = StateProvider<TaskViewFilter>(
  (ref) => const TaskViewFilter(),
);

final visibleTaskFilterCapabilitiesProvider =
    Provider<TaskProviderCapabilities>((ref) {
      final allTasksMode = ref.watch(allTasksModeProvider);
      if (!allTasksMode) {
        return ref.watch(selectedAccountCapabilitiesProvider);
      }

      final accounts =
          ref.watch(accountsStreamProvider).valueOrNull ?? const [];
      final providers = accounts.map((account) => account.provider).toSet();
      final capabilities = providers.map(capabilitiesForProvider).toList();

      return TaskProviderCapabilities(
        supportsDueDate: capabilities.any((item) => item.supportsDueDate),
        supportsDueTime: capabilities.any((item) => item.supportsDueTime),
        supportsStartDateTime: capabilities.any(
          (item) => item.supportsStartDateTime,
        ),
        supportsReminderDateTime: capabilities.any(
          (item) => item.supportsReminderDateTime,
        ),
        supportsRecurrence: capabilities.any((item) => item.supportsRecurrence),
        supportsImportance: capabilities.any((item) => item.supportsImportance),
        supportsCategories: capabilities.any((item) => item.supportsCategories),
        supportsTaskHierarchy: capabilities.any(
          (item) => item.supportsTaskHierarchy,
        ),
        supportsCrossListMove: capabilities.any(
          (item) => item.supportsCrossListMove,
        ),
        supportsClearCompleted: capabilities.any(
          (item) => item.supportsClearCompleted,
        ),
        supportsHiddenTasks: capabilities.any(
          (item) => item.supportsHiddenTasks,
        ),
        supportsAssignedTasks: capabilities.any(
          (item) => item.supportsAssignedTasks,
        ),
        supportsListRename: capabilities.any((item) => item.supportsListRename),
        supportsListDelete: capabilities.any((item) => item.supportsListDelete),
      );
    });

class TaskFiltersBar extends ConsumerStatefulWidget {
  const TaskFiltersBar({super.key});

  @override
  ConsumerState<TaskFiltersBar> createState() => _TaskFiltersBarState();
}

class _TaskFiltersBarState extends ConsumerState<TaskFiltersBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(taskViewFilterProvider);
    final notifier = ref.read(taskViewFilterProvider.notifier);
    final capabilities = ref.watch(visibleTaskFilterCapabilitiesProvider);
    final l10n = context.l10n;

    if (_searchController.text != filter.searchQuery) {
      _searchController.value = TextEditingValue(
        text: filter.searchQuery,
        selection: TextSelection.collapsed(offset: filter.searchQuery.length),
      );
    }

    return Row(
      children: [
        Expanded(
          child: BusyMaxSearchField(
            controller: _searchController,
            autofocus: false,
            hintText: l10n.searchTasks,
            onClear: () {
              notifier.state = filter.copyWith(searchQuery: '');
            },
            onChanged: (value) {
              notifier.state = filter.copyWith(searchQuery: value);
            },
          ),
        ),
        const SizedBox(width: BusyMaxSpacing.sm),
        BusyMaxMenuButton<_FilterToggle>(
          tooltip: l10n.advancedFilters,
          onSelected: (toggle) {
            switch (toggle) {
              case _FilterToggle.completed:
                notifier.state = filter.copyWith(
                  showCompleted: !filter.showCompleted,
                );
                break;
              case _FilterToggle.hidden:
                notifier.state = filter.copyWith(
                  showHidden: !filter.showHidden,
                );
                break;
              case _FilterToggle.assigned:
                notifier.state = filter.copyWith(
                  showAssigned: !filter.showAssigned,
                );
                break;
            }
          },
          entries: [
            BusyMaxMenuEntry(
              value: _FilterToggle.completed,
              label: l10n.showCompleted,
              checked: filter.showCompleted,
            ),
            BusyMaxMenuEntry(
              value: _FilterToggle.hidden,
              label: l10n.showHidden,
              checked: filter.showHidden,
              enabled: capabilities.supportsHiddenTasks,
            ),
            BusyMaxMenuEntry(
              value: _FilterToggle.assigned,
              label: l10n.showAssigned,
              checked: filter.showAssigned,
              enabled: capabilities.supportsAssignedTasks,
            ),
          ],
        ),
      ],
    );
  }
}

extension TaskViewFilterCopy on TaskViewFilter {
  TaskViewFilter copyWith({
    bool? showCompleted,
    bool? showDeleted,
    bool? showHidden,
    bool? showAssigned,
    String? searchQuery,
    DateTime? completedMin,
    DateTime? completedMax,
    DateTime? dueMin,
    DateTime? dueMax,
    DateTime? updatedMin,
  }) {
    return TaskViewFilter(
      showCompleted: showCompleted ?? this.showCompleted,
      showDeleted: showDeleted ?? this.showDeleted,
      showHidden: showHidden ?? this.showHidden,
      showAssigned: showAssigned ?? this.showAssigned,
      searchQuery: searchQuery ?? this.searchQuery,
      completedMin: completedMin ?? this.completedMin,
      completedMax: completedMax ?? this.completedMax,
      dueMin: dueMin ?? this.dueMin,
      dueMax: dueMax ?? this.dueMax,
      updatedMin: updatedMin ?? this.updatedMin,
    );
  }
}

enum _FilterToggle { completed, hidden, assigned }
