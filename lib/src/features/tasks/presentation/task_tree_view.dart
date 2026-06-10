import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/app_bootstrap.dart';
import '../../../google_tasks/api/google_tasks_json.dart';
import '../../../l10n/l10n.dart';
import '../../../task_providers/task_provider.dart';
import '../data/tasks_repository.dart';
import 'desktop_date_time_fields.dart';
import 'task_filters.dart';
import 'task_row.dart';
import 'tasks_selection_state.dart';

class TaskTreeView extends ConsumerWidget {
  const TaskTreeView({
    super.key,
    required this.taskListId,
    required this.showAllTasks,
    this.selectedTaskId,
    this.onOpenTask,
    this.onCreateTask,
    this.onRefreshAll,
  });

  final String? taskListId;
  final bool showAllTasks;
  final String? selectedTaskId;
  final void Function(
    TaskEntity task,
    String taskListId,
    bool stayInAllTasksMode,
  )?
  onOpenTask;
  final VoidCallback? onCreateTask;
  final VoidCallback? onRefreshAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTaskListId = taskListId;
    final repository = ref.watch(tasksRepositoryProvider);
    final filter = ref.watch(taskViewFilterProvider);
    final l10n = context.l10n;
    if (repository == null) {
      return Center(child: Text(l10n.signInToViewTasks));
    }

    if (showAllTasks) {
      final accounts =
          ref.watch(accountsStreamProvider).valueOrNull ?? const [];
      if (accounts.isEmpty) {
        return BusyMaxEmptyState(
          icon: YaruIcons.user,
          title: l10n.signInToViewTasks,
        );
      }
      return StreamBuilder<List<TaskTreeGroup>>(
        stream: repository.watchAllTaskTreeGroups([
          for (final account in accounts) account.id,
        ], filter),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data ?? const <TaskTreeGroup>[];
          if (groups.isEmpty) {
            if (filter.searchQuery.trim().isNotEmpty) {
              return _SearchEmptyState(label: l10n.noTasks);
            }
            return BusyMaxEmptyState(
              icon: YaruIcons.task_list,
              title: l10n.noTasksYet,
              message: l10n.noTasksYetMessage,
              actions: [
                if (onCreateTask != null)
                  BusyMaxToolbarButton(
                    icon: YaruIcons.plus,
                    label: l10n.newTask,
                    tooltip: l10n.newTask,
                    primary: true,
                    onPressed: onCreateTask,
                  ),
                if (onRefreshAll != null)
                  BusyMaxToolbarButton(
                    icon: YaruIcons.refresh,
                    label: l10n.refreshAll,
                    tooltip: l10n.refreshAll,
                    onPressed: onRefreshAll,
                  ),
              ],
            );
          }
          final entries = _sortedAllTaskEntries(groups);
          final sections = _bucketAllTaskEntries(context, entries);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: BusyMaxSpacing.sm),
            children: [
              for (final section in sections) ...[
                _TaskSectionHeader(section.title),
                for (final entry in section.entries)
                  _TaskNodeTile(
                    node: entry.node,
                    taskListId: entry.group.taskListId,
                    selectedTaskId: selectedTaskId,
                    capabilities: capabilitiesForProvider(entry.group.provider),
                    stayInAllTasksMode: true,
                    sourceLabel: entry.sourceLabel,
                    onOpenTask: onOpenTask,
                  ),
              ],
            ],
          );
        },
      );
    }

    if (selectedTaskListId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.selectOrCreateTaskList),
        ),
      );
    }

    return StreamBuilder<List<TaskTreeNode>>(
      stream: repository.watchTaskTree(selectedTaskListId, filter),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final nodes = snapshot.data ?? const <TaskTreeNode>[];
        if (nodes.isEmpty) {
          if (filter.searchQuery.trim().isNotEmpty) {
            return _SearchEmptyState(label: l10n.noTasks);
          }
          return BusyMaxEmptyState(
            icon: YaruIcons.task_list,
            title: l10n.noTasksInList,
            actions: [
              if (onCreateTask != null)
                BusyMaxToolbarButton(
                  icon: YaruIcons.plus,
                  label: l10n.newTask,
                  tooltip: l10n.newTask,
                  primary: true,
                  onPressed: onCreateTask,
                ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: BusyMaxSpacing.sm),
          children: [
            for (final node in nodes)
              _TaskNodeTile(
                node: node,
                taskListId: selectedTaskListId,
                selectedTaskId: selectedTaskId,
                capabilities: ref.watch(selectedAccountCapabilitiesProvider),
                stayInAllTasksMode: false,
                onOpenTask: onOpenTask,
              ),
          ],
        );
      },
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AllTaskNodeEntry {
  const _AllTaskNodeEntry({required this.group, required this.node});

  final TaskTreeGroup group;
  final TaskTreeNode node;

  String get sourceLabel =>
      '${group.provider.displayName} · ${group.accountLabel} · ${group.taskListTitle}';
}

class _AllTasksSection {
  const _AllTasksSection({required this.title, required this.entries});

  final String title;
  final List<_AllTaskNodeEntry> entries;
}

List<_AllTaskNodeEntry> _sortedAllTaskEntries(List<TaskTreeGroup> groups) {
  final entries = [
    for (final group in groups)
      for (final node in group.nodes)
        _AllTaskNodeEntry(group: group, node: node),
  ];
  entries.sort(_compareAllTaskEntries);
  return entries;
}

int _compareAllTaskEntries(_AllTaskNodeEntry left, _AllTaskNodeEntry right) {
  final dueComparison = _compareNullableDate(
    _sortDate(left.node.task),
    _sortDate(right.node.task),
  );
  if (dueComparison != 0) {
    return dueComparison;
  }

  return _compareStrings(
    [
      left.node.task.title,
      left.group.provider.displayName,
      left.group.accountLabel,
      left.group.taskListTitle,
      left.node.task.id,
    ],
    [
      right.node.task.title,
      right.group.provider.displayName,
      right.group.accountLabel,
      right.group.taskListTitle,
      right.node.task.id,
    ],
  );
}

List<_AllTasksSection> _bucketAllTaskEntries(
  BuildContext context,
  List<_AllTaskNodeEntry> entries,
) {
  final buckets = <_TaskDueBucket, List<_AllTaskNodeEntry>>{
    for (final bucket in _TaskDueBucket.values) bucket: [],
  };
  for (final entry in entries) {
    buckets[_bucketFor(entry.node.task)]!.add(entry);
  }

  final l10n = context.l10n;
  final titles = {
    _TaskDueBucket.overdue: l10n.overdue,
    _TaskDueBucket.today: l10n.today,
    _TaskDueBucket.tomorrow: l10n.tomorrow,
    _TaskDueBucket.upcoming: l10n.upcoming,
    _TaskDueBucket.noDate: l10n.noDate,
    _TaskDueBucket.completed: l10n.completed,
  };

  return [
    for (final bucket in _TaskDueBucket.values)
      if (buckets[bucket]!.isNotEmpty)
        _AllTasksSection(title: titles[bucket]!, entries: buckets[bucket]!),
  ];
}

enum _TaskDueBucket { overdue, today, tomorrow, upcoming, noDate, completed }

_TaskDueBucket _bucketFor(TaskEntity task) {
  if (task.status == 'completed') {
    return _TaskDueBucket.completed;
  }
  final due = _sortDate(task);
  if (due == null) {
    return _TaskDueBucket.noDate;
  }
  final today = DateTime.now();
  final dueDate = DateTime(due.year, due.month, due.day);
  final todayDate = DateTime(today.year, today.month, today.day);
  if (dueDate.isBefore(todayDate)) {
    return _TaskDueBucket.overdue;
  }
  if (isSameDate(dueDate, todayDate)) {
    return _TaskDueBucket.today;
  }
  if (isSameDate(dueDate, todayDate.add(const Duration(days: 1)))) {
    return _TaskDueBucket.tomorrow;
  }
  return _TaskDueBucket.upcoming;
}

DateTime? _sortDate(TaskEntity task) {
  final due = task.dueUtc;
  if (due == null || due.isEmpty) {
    return null;
  }
  return DateTime.tryParse(due);
}

int _compareNullableDate(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

int _compareStrings(List<String> left, List<String> right) {
  for (var index = 0; index < left.length; index += 1) {
    final comparison = left[index].toLowerCase().compareTo(
      right[index].toLowerCase(),
    );
    if (comparison != 0) {
      return comparison;
    }
  }
  return 0;
}

class _TaskNodeTile extends ConsumerWidget {
  const _TaskNodeTile({
    required this.node,
    required this.taskListId,
    required this.selectedTaskId,
    required this.capabilities,
    required this.stayInAllTasksMode,
    this.onOpenTask,
    this.sourceLabel,
    this.depth = 0,
  });

  final TaskTreeNode node;
  final String taskListId;
  final String? selectedTaskId;
  final TaskProviderCapabilities capabilities;
  final bool stayInAllTasksMode;
  final void Function(
    TaskEntity task,
    String taskListId,
    bool stayInAllTasksMode,
  )?
  onOpenTask;
  final String? sourceLabel;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = node.task;
    final completed = task.status == 'completed';
    final repository = ref.watch(
      tasksRepositoryForAccountProvider(task.accountId),
    );
    final localTimeZone = ref.watch(localTimeZoneProvider);
    final l10n = context.l10n;

    final selected = task.id == selectedTaskId;
    final dueDate = formatDesktopDate(context, task.dueUtc);
    final source = sourceLabel;

    final metadata = [
      if (dueDate.isNotEmpty) dueDate,
      if (source != null) source,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BusyMaxTaskRow(
          key: ValueKey('task-row-${task.accountId}/$taskListId/${task.id}'),
          selected: selected,
          depth: depth,
          completed: completed,
          title: task.title,
          metadata: metadata.isEmpty ? null : metadata,
          onTap: () {
            ref.read(selectedAccountIdProvider.notifier).state = task.accountId;
            ref.read(selectedTaskListIdProvider.notifier).state = taskListId;
            ref.read(selectedTaskIdProvider.notifier).state = task.id;
            ref.read(allTasksModeProvider.notifier).state = stayInAllTasksMode;
            onOpenTask?.call(task, taskListId, stayInAllTasksMode);
          },
          checkbox: YaruCheckbox(
            value: completed,
            onChanged: (value) {
              final status = value == true ? 'completed' : 'needsAction';
              final fields = <String, Object?>{
                'status': status,
                'completed': value == true
                    ? DateTime.now().toUtc().toIso8601String()
                    : null,
              };
              if (capabilities.supportsDueTime) {
                final timeZone =
                    task.microsoftCompletedTimeZone ?? localTimeZone;
                fields['microsoftCompletedTimeZone'] = timeZone;
                fields['microsoftCompletedDateTime'] = value == true
                    ? _graphDateTimeNow(timeZone)
                    : null;
              }
              repository.patchTask(taskListId, task.id, TaskPatchInput(fields));
            },
          ),
          trailing: task.localDirty || task.pendingMove
              ? Tooltip(
                  message: l10n.pendingSync,
                  child: const Icon(Icons.sync_problem, size: 16),
                )
              : null,
        ),
        for (final child in node.children)
          _TaskNodeTile(
            node: child,
            taskListId: taskListId,
            selectedTaskId: selectedTaskId,
            capabilities: capabilities,
            stayInAllTasksMode: stayInAllTasksMode,
            onOpenTask: onOpenTask,
            sourceLabel: sourceLabel,
            depth: depth + 1,
          ),
      ],
    );
  }
}

class _TaskSectionHeader extends StatelessWidget {
  const _TaskSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BusyMaxSpacing.lg,
        BusyMaxSpacing.md,
        BusyMaxSpacing.lg,
        BusyMaxSpacing.xs,
      ),
      child: Text(title, style: busyMaxSectionHeaderStyle(context)),
    );
  }
}

Map<String, Object?> _graphDateTimeNow(String timeZone) {
  final now = DateTime.now();
  final date = encodeGoogleDateOnly(now);
  final time =
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';
  return {'dateTime': '${date}T$time', 'timeZone': timeZone};
}
