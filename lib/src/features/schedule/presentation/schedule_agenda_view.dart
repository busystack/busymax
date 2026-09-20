import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_glyphs.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/localized_formatters.dart';
import '../../tasks/domain/task_checklist_item.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_range.dart';
import '../../../schedule/schedule_sorting.dart';
import '../../../schedule/task_list_mutation_intent.dart';
import 'schedule_event_block.dart';
import 'schedule_search_result_text.dart';
import '../../../schedule/schedule_search_criteria.dart';
import 'schedule_item_selection.dart';

class ScheduleAgendaView extends StatefulWidget {
  const ScheduleAgendaView({
    super.key,
    required this.range,
    required this.items,
    required this.onItemSelected,
    required this.onTaskCompletionChanged,
    this.onChecklistItemCompletionChanged,
    this.hasMoreOverdueTasks = false,
    this.hasMoreNoDateTasks = false,
    this.onLoadMore,
    this.onLoadMoreOverdue,
    this.onLoadMoreNoDate,
    this.onItemAnchorAvailable,
    this.searchCriteria,
    this.searchQuery = '',
    this.taskListMutationIntent,
    this.onTaskListMutationConsumed,
  });

  final ScheduleSearchCriteria? searchCriteria;
  final String searchQuery;
  final ScheduleRange range;
  final List<ScheduleItem> items;
  final ScheduleItemSelectionCallback onItemSelected;
  final void Function(TaskScheduleItem item, bool completed)
  onTaskCompletionChanged;
  final void Function(
    TaskScheduleItem parent,
    TaskChecklistItemEntity item,
    bool completed,
  )?
  onChecklistItemCompletionChanged;
  final bool hasMoreOverdueTasks;
  final bool hasMoreNoDateTasks;
  final VoidCallback? onLoadMore;
  final VoidCallback? onLoadMoreOverdue;
  final VoidCallback? onLoadMoreNoDate;
  final ScheduleItemAnchorCallback? onItemAnchorAvailable;
  final TaskListMutationIntent? taskListMutationIntent;
  final ValueChanged<TaskListMutationIntent>? onTaskListMutationConsumed;

  @override
  State<ScheduleAgendaView> createState() => _ScheduleAgendaViewState();
}

class _ScheduleAgendaViewState extends State<ScheduleAgendaView> {
  var _loadMoreArmed = true;
  final _outgoingTasks = <String, ({TaskScheduleItem item, int index})>{};
  final _exitingTaskKeys = <String>{};
  final _exitingMutations = <String, TaskListMutationIntent>{};
  final _enteringTaskKeys = <String>{};
  int? _handledMutationGeneration;

  @override
  void didUpdateWidget(covariant ScheduleAgendaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range.end != widget.range.end) {
      _loadMoreArmed = true;
    }
    _reconcileMutation(oldWidget);
  }

  void _reconcileMutation(ScheduleAgendaView oldWidget) {
    final intent = widget.taskListMutationIntent;
    if (intent == null || _handledMutationGeneration == intent.generation) {
      return;
    }
    bool matches(TaskScheduleItem task) =>
        task.accountId == intent.accountId &&
        task.sourceId == intent.taskListId &&
        task.id == intent.taskId;
    final current = widget.items.whereType<TaskScheduleItem>().where(matches);
    if (intent.presentation == TaskListMutationPresentation.insertion) {
      if (current.isEmpty) return;
      _handledMutationGeneration = intent.generation;
      _enteringTaskKeys.add(intent.taskKey);
      _notifyMutationConsumed(intent);
      return;
    }
    if (current.isNotEmpty) {
      final task = current.first;
      if (intent.presentation == TaskListMutationPresentation.completion &&
          intent.completed != null) {
        final checklistItemId = intent.checklistItemId;
        if (checklistItemId == null) {
          if (task.completed != intent.completed) return;
        } else {
          final checklistItem = task.checklistItems
              .where((item) => item.id == checklistItemId)
              .firstOrNull;
          if (checklistItem?.completed != intent.completed) return;
        }
      }
      _handledMutationGeneration = intent.generation;
      _notifyMutationConsumed(intent);
      return;
    }
    final oldIndex = oldWidget.items.indexWhere(
      (item) => item is TaskScheduleItem && matches(item),
    );
    if (oldIndex < 0) return;
    final oldTask = oldWidget.items[oldIndex] as TaskScheduleItem;
    _handledMutationGeneration = intent.generation;
    _outgoingTasks[intent.taskKey] = (item: oldTask, index: oldIndex);
    _exitingTaskKeys.add(intent.taskKey);
    _exitingMutations[intent.taskKey] = intent;
  }

  void _notifyMutationConsumed(TaskListMutationIntent intent) {
    final callback = widget.onTaskListMutationConsumed;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(intent);
    });
  }

  bool _handleScroll(ScrollNotification notification) {
    final onLoadMore = widget.onLoadMore;
    if (!_loadMoreArmed || onLoadMore == null) {
      return false;
    }
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.metrics.extentAfter > 1) {
      return false;
    }
    _loadMoreArmed = false;
    onLoadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final presentedItems = List<ScheduleItem>.of(widget.items);
    for (final outgoing in _outgoingTasks.values) {
      if (presentedItems.any(
        (item) =>
            item is TaskScheduleItem &&
            _agendaTaskKey(item) == _agendaTaskKey(outgoing.item),
      )) {
        continue;
      }
      presentedItems.insert(
        outgoing.index.clamp(0, presentedItems.length),
        outgoing.item,
      );
    }
    final sections = widget.searchCriteria == null
        ? _ordinarySections(context, presentedItems)
        : _searchSections(context, presentedItems);
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: ColoredBox(
        color: BusyMaxSurfaceColors.of(context).window,
        child: ListView(
          key: widget.searchCriteria == null
              ? null
              : const ValueKey('schedule-search-results'),
          padding: const EdgeInsets.fromLTRB(
            BusyMaxSpacing.lg,
            BusyMaxSpacing.md,
            BusyMaxSpacing.lg,
            BusyMaxSpacing.xl,
          ),
          children: [
            for (final section in sections)
              if (section.children.isNotEmpty)
                BusyMaxGroupedList(
                  title: section.title,
                  filled: true,
                  children: section.children,
                ),
          ],
        ),
      ),
    );
  }

  List<_AgendaSection> _ordinarySections(
    BuildContext context,
    List<ScheduleItem> items,
  ) {
    final dated = items.where((item) => item.start != null).toList();
    final noDateTasks = ScheduleProjection.noDateTasks(items);
    final groups = ScheduleProjection.groupByDay(dated);
    final rangeStart = ScheduleProjection.day(widget.range.start);
    final rangeEnd = ScheduleProjection.day(widget.range.end);
    final overdueTasks = dated.whereType<TaskScheduleItem>().where((item) {
      final start = item.start;
      return start != null &&
          !item.completed &&
          ScheduleProjection.day(start).isBefore(rangeStart);
    }).toList()..sort(compareScheduleItems);
    final orderedOverdueTasks = ScheduleProjection.arrangeHierarchy(
      overdueTasks,
    );
    final hierarchy = _AgendaHierarchyIndex(items);
    final emittedTasks = <String>{};
    final overdueEntries = _entriesFor(
      orderedOverdueTasks,
      hierarchy,
      emittedTasks,
    );
    final noDateEntries = _entriesFor(noDateTasks, hierarchy, emittedTasks);
    final days =
        groups.keys
            .where((day) => !day.isBefore(rangeStart) && day.isBefore(rangeEnd))
            .toList()
          ..sort();
    final dayEntries = <DateTime, List<Widget>>{
      for (final day in days)
        day: _entriesFor(groups[day]!, hierarchy, emittedTasks),
    };
    return [
      if (overdueEntries.isNotEmpty || widget.hasMoreOverdueTasks)
        _AgendaSection(
          title: context.l10n.overdue,
          children: [
            ...overdueEntries,
            if (widget.hasMoreOverdueTasks && widget.onLoadMoreOverdue != null)
              _AgendaLoadMoreRow(
                title: context.l10n.agendaLoadMoreOverdue,
                onTap: widget.onLoadMoreOverdue!,
              ),
          ],
        ),
      if (noDateEntries.isNotEmpty || widget.hasMoreNoDateTasks)
        _AgendaSection(
          title: context.l10n.noDate,
          children: [
            ...noDateEntries,
            if (widget.hasMoreNoDateTasks && widget.onLoadMoreNoDate != null)
              _AgendaLoadMoreRow(
                title: context.l10n.agendaLoadMoreNoDate,
                onTap: widget.onLoadMoreNoDate!,
              ),
          ],
        ),
      for (final day in days)
        _AgendaSection(
          title: _dayLabel(context, day),
          children: dayEntries[day]!,
        ),
    ];
  }

  List<_AgendaSection> _searchSections(
    BuildContext context,
    List<ScheduleItem> items,
  ) {
    final orderedItems = List<ScheduleItem>.of(items)
      ..sort(compareScheduleSearchResultPresentation);
    final datedGroups = <DateTime, List<ScheduleItem>>{};
    final undated = <ScheduleItem>[];
    for (final item in orderedItems) {
      final displayDate = scheduleSearchResultDisplayDate(item);
      if (displayDate == null) {
        undated.add(item);
      } else {
        datedGroups
            .putIfAbsent(ScheduleProjection.day(displayDate), () => [])
            .add(item);
      }
    }
    return [
      for (final entry in datedGroups.entries)
        _AgendaSection(
          title: _dayLabel(context, entry.key),
          children: _entriesFor(
            entry.value,
            _AgendaHierarchyIndex(entry.value),
            <String>{},
          ),
        ),
      if (undated.isNotEmpty)
        _AgendaSection(
          title: context.l10n.noDate,
          children: _entriesFor(
            undated,
            _AgendaHierarchyIndex(undated),
            <String>{},
          ),
        ),
    ];
  }

  List<Widget> _entriesFor(
    List<ScheduleItem> items,
    _AgendaHierarchyIndex hierarchy,
    Set<String> emitted,
  ) {
    final entries = <Widget>[];
    final emittedDetachedParents = <String>{};
    for (final item in items) {
      if (item is! TaskScheduleItem) {
        entries.add(_standaloneRow(item));
        continue;
      }

      final key = _agendaTaskKey(item);
      if (emitted.contains(key)) continue;
      final parentKey = _agendaParentKey(item);
      if (parentKey != null && hierarchy.tasks.containsKey(parentKey)) {
        continue;
      }
      if (parentKey == null) {
        entries.add(_taskGroup(item, hierarchy.children, emitted));
        continue;
      }
      if (!emittedDetachedParents.add(parentKey)) continue;
      final detachedRoots = [
        for (final candidate in items.whereType<TaskScheduleItem>())
          if (_agendaParentKey(candidate) == parentKey) candidate,
      ];
      entries.add(
        _detachedTaskGroup(detachedRoots, hierarchy.children, emitted),
      );
    }

    for (final task in items.whereType<TaskScheduleItem>()) {
      if (!emitted.contains(_agendaTaskKey(task)) && hierarchy.isCyclic(task)) {
        entries.add(_detachedTaskGroup([task], hierarchy.children, emitted));
      }
    }
    return entries;
  }

  Widget _standaloneRow(ScheduleItem item, {bool animateMutation = true}) {
    void select(BuildContext context, [Offset? globalPosition]) =>
        widget.onItemSelected(context, item, globalPosition);
    final task = item is TaskScheduleItem ? item : null;
    final row = _AgendaRow(
      item: item,
      completedOverride: _completionOverride(task),
      animateCompletion: _completionOverride(task) != null,
      searchCriteria: widget.searchCriteria,
      searchQuery: widget.searchQuery,
      onAnchorAvailable: widget.onItemAnchorAvailable,
      onTap: select,
      onTaskCompletionChanged: task == null
          ? null
          : (completed) => widget.onTaskCompletionChanged(task, completed),
    );
    return animateMutation && task != null ? _wrapTaskMutation(task, row) : row;
  }

  bool? _completionOverride(TaskScheduleItem? task) {
    final intent = widget.taskListMutationIntent;
    if (task == null ||
        intent == null ||
        intent.presentation != TaskListMutationPresentation.completion ||
        intent.checklistItemId != null ||
        intent.taskKey != _agendaTaskKey(task)) {
      return null;
    }
    return intent.completed;
  }

  Widget _wrapTaskMutation(TaskScheduleItem task, Widget child) {
    final key = _agendaTaskKey(task);
    return _AgendaMutationTransition(
      key: ValueKey('agenda-mutation-$key'),
      entering: _enteringTaskKeys.contains(key),
      exiting: _exitingTaskKeys.contains(key),
      onFinished: () {
        if (!mounted) return;
        setState(() {
          _enteringTaskKeys.remove(key);
          if (_exitingTaskKeys.remove(key)) {
            _outgoingTasks.remove(key);
            final intent = _exitingMutations.remove(key);
            if (intent != null) _notifyMutationConsumed(intent);
          }
        });
      },
      child: child,
    );
  }

  Widget _taskGroup(
    TaskScheduleItem root,
    Map<String, List<TaskScheduleItem>> children,
    Set<String> emitted,
  ) {
    emitted.add(_agendaTaskKey(root));
    final group = Column(
      key: ValueKey(
        'agenda-task-group-${root.accountId}-${root.sourceId}-${root.id}',
      ),
      mainAxisSize: MainAxisSize.min,
      children: [
        _standaloneRow(root, animateMutation: false),
        ..._nestedRows(root, children, emitted, hierarchyRoot: root, depth: 1),
      ],
    );
    return _wrapTaskMutation(root, group);
  }

  Widget _detachedTaskGroup(
    List<TaskScheduleItem> roots,
    Map<String, List<TaskScheduleItem>> children,
    Set<String> emitted,
  ) {
    final visibleRoots = [
      for (final root in roots)
        if (!emitted.contains(_agendaTaskKey(root))) root,
    ];
    String? parentTitle;
    for (final root in visibleRoots) {
      final candidate = root.parentTitle?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        parentTitle = candidate;
        break;
      }
    }
    final nestedRows = <Widget>[];
    for (final root in visibleRoots) {
      if (!emitted.add(_agendaTaskKey(root))) continue;
      nestedRows.add(
        _nestedTaskRow(root, hierarchyRoot: root, depth: 1, showSource: true),
      );
      nestedRows.addAll(
        _nestedRows(root, children, emitted, hierarchyRoot: root, depth: 2),
      );
    }
    final firstRoot = roots.first;
    return Column(
      key: ValueKey(
        'agenda-detached-task-group-${firstRoot.accountId}-${firstRoot.sourceId}-'
        '${firstRoot.parentId ?? firstRoot.id}',
      ),
      mainAxisSize: MainAxisSize.min,
      children: [
        _AgendaParentContext(title: parentTitle),
        ...nestedRows,
      ],
    );
  }

  List<Widget> _nestedRows(
    TaskScheduleItem parent,
    Map<String, List<TaskScheduleItem>> children,
    Set<String> emitted, {
    required TaskScheduleItem hierarchyRoot,
    required int depth,
  }) {
    final rows = <Widget>[
      for (final checklistItem in parent.checklistItems)
        _nestedChecklistRow(parent, checklistItem, depth: depth),
    ];
    for (final child in children[_agendaTaskKey(parent)] ?? const []) {
      if (!emitted.add(_agendaTaskKey(child))) continue;
      rows.add(
        _nestedTaskRow(child, hierarchyRoot: hierarchyRoot, depth: depth),
      );
      rows.addAll(
        _nestedRows(
          child,
          children,
          emitted,
          hierarchyRoot: hierarchyRoot,
          depth: depth + 1,
        ),
      );
    }
    return rows;
  }

  Widget _nestedTaskRow(
    TaskScheduleItem task, {
    required TaskScheduleItem hierarchyRoot,
    required int depth,
    bool showSource = false,
  }) {
    final completionOverride = _completionOverride(task);
    final row = _AgendaSubtaskRow(
      key: ValueKey(
        'agenda-subtask-${task.accountId}-${task.sourceId}-${task.id}',
      ),
      depth: depth,
      title: task.title,
      completed: completionOverride ?? task.completed,
      animateCompletion: completionOverride != null,
      subtitleBuilder: (context) {
        final searchCriteria = widget.searchCriteria;
        if (searchCriteria != null) {
          return scheduleSearchResultText(
            context,
            task,
            searchCriteria,
            widget.searchQuery,
          );
        }
        final values = [
          _nestedTaskScheduleLabel(context, task, hierarchyRoot),
          if (showSource) ScheduleProjection.sourceLabelForScheduleItem(task),
        ].where((value) => value.trim().isNotEmpty);
        return values.join(' - ');
      },
      onAnchorAvailable: widget.onItemAnchorAvailable == null
          ? null
          : (context) => widget.onItemAnchorAvailable!(task, context),
      onTap: (context, [globalPosition]) =>
          widget.onItemSelected(context, task, globalPosition),
      onCompletionChanged: (completed) =>
          widget.onTaskCompletionChanged(task, completed),
    );
    return _wrapTaskMutation(task, row);
  }

  Widget _nestedChecklistRow(
    TaskScheduleItem parent,
    TaskChecklistItemEntity item, {
    required int depth,
  }) {
    final completionOverride = _checklistCompletionOverride(parent, item);
    return _AgendaSubtaskRow(
      key: ValueKey('agenda-checklist-${parent.id}-${item.id}'),
      depth: depth,
      title: item.title,
      completed: completionOverride ?? item.completed,
      animateCompletion: completionOverride != null,
      onTap: (context, [globalPosition]) =>
          widget.onItemSelected(context, parent, globalPosition),
      onCompletionChanged: widget.onChecklistItemCompletionChanged == null
          ? null
          : (completed) => widget.onChecklistItemCompletionChanged!(
              parent,
              item,
              completed,
            ),
    );
  }

  bool? _checklistCompletionOverride(
    TaskScheduleItem parent,
    TaskChecklistItemEntity item,
  ) {
    final intent = widget.taskListMutationIntent;
    if (intent == null ||
        intent.presentation != TaskListMutationPresentation.completion ||
        intent.taskKey != _agendaTaskKey(parent) ||
        intent.checklistItemId != item.id) {
      return null;
    }
    return intent.completed;
  }
}

class _AgendaSection {
  const _AgendaSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;
}

class _AgendaLoadMoreRow extends StatelessWidget {
  const _AgendaLoadMoreRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BusyMaxActionRow(
      title: title,
      leading: const Icon(YaruIcons.plus, size: BusyMaxSizes.iconSm),
      onTap: onTap,
    );
  }
}

class _AgendaMutationTransition extends StatefulWidget {
  const _AgendaMutationTransition({
    super.key,
    required this.entering,
    required this.exiting,
    required this.onFinished,
    required this.child,
  });

  final bool entering;
  final bool exiting;
  final VoidCallback onFinished;
  final Widget child;

  @override
  State<_AgendaMutationTransition> createState() =>
      _AgendaMutationTransitionState();
}

class _AgendaMutationTransitionState extends State<_AgendaMutationTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: widget.entering ? 0 : 1,
  );
  bool _disableAnimations = false;
  bool _finishScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled && (widget.entering || widget.exiting)) {
        _controller.value = widget.exiting ? 0 : 1;
        _finishAfterFrame();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _AgendaMutationTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entering != widget.entering ||
        oldWidget.exiting != widget.exiting) {
      _run();
    }
  }

  Future<void> _run() async {
    if (!mounted || (!widget.entering && !widget.exiting)) return;
    final target = widget.exiting ? 0.0 : 1.0;
    if (_disableAnimations) {
      _controller.value = target;
      _finishAfterFrame();
      return;
    } else {
      await _controller.animateTo(
        target,
        duration: BusyMaxMotion.taskListMutation,
        curve: BusyMaxMotion.presentationCurve,
      );
    }
    if (mounted) widget.onFinished();
  }

  void _finishAfterFrame() {
    if (_finishScheduled) return;
    _finishScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _finishScheduled = false;
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: widget.exiting,
    child: ExcludeFocus(
      excluding: widget.exiting,
      child: ExcludeSemantics(
        excluding: widget.exiting,
        child: ClipRect(
          child: SizeTransition(
            sizeFactor: _controller,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: _controller, child: widget.child),
          ),
        ),
      ),
    ),
  );
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.item,
    required this.onTap,
    this.onAnchorAvailable,
    this.searchCriteria,
    this.searchQuery = '',
    this.onTaskCompletionChanged,
    this.completedOverride,
    this.animateCompletion = false,
  });

  final ScheduleSearchCriteria? searchCriteria;
  final String searchQuery;
  final ScheduleItem item;
  final ScheduleItemTapCallback onTap;
  final ScheduleItemAnchorCallback? onAnchorAvailable;
  final ValueChanged<bool>? onTaskCompletionChanged;
  final bool? completedOverride;
  final bool animateCompletion;

  @override
  Widget build(BuildContext context) {
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    final completed = completedOverride ?? task?.completed ?? false;
    final onAnchorAvailable = this.onAnchorAvailable;
    if (onAnchorAvailable != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          onAnchorAvailable(item, context);
        }
      });
    }

    return BusyMaxActionRow(
      title: item.title,
      titleWidget: _AgendaItemTitle(
        item: item,
        completedOverride: completedOverride,
        animateCompletion: animateCompletion,
      ),
      subtitleWidget: searchCriteria == null
          ? _AgendaItemSubtitle(item: item)
          : Text(
              scheduleSearchResultText(
                context,
                item,
                searchCriteria!,
                searchQuery,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      leading: _AgendaItemMarker(item: item),
      trailing: task == null
          ? null
          : BusyMaxYaruFocusBorder(
              builder: (context, focusNode) => YaruCheckbox(
                value: completed,
                focusNode: focusNode,
                hasFocusBorder: false,
                onChanged: onTaskCompletionChanged == null
                    ? null
                    : (value) => onTaskCompletionChanged!(value ?? false),
              ),
            ),
      onActivated: onTap,
    );
  }
}

class _AgendaParentContext extends StatelessWidget {
  const _AgendaParentContext({required this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    final label = title == null
        ? context.l10n.subtasks
        : '${context.l10n.parent}: $title';
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BusyMaxSpacing.md,
        BusyMaxSpacing.sm,
        BusyMaxSpacing.md,
        BusyMaxSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: BusyMaxSizes.iconSm,
            color: colors.mutedForeground,
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaSubtaskRow extends StatelessWidget {
  const _AgendaSubtaskRow({
    super.key,
    required this.depth,
    required this.title,
    required this.completed,
    required this.onTap,
    this.subtitleBuilder,
    this.onAnchorAvailable,
    this.onCompletionChanged,
    this.animateCompletion = false,
  });

  final int depth;
  final String title;
  final bool completed;
  final ScheduleItemTapCallback onTap;
  final String Function(BuildContext context)? subtitleBuilder;
  final ValueChanged<BuildContext>? onAnchorAvailable;
  final ValueChanged<bool>? onCompletionChanged;
  final bool animateCompletion;

  @override
  Widget build(BuildContext context) {
    final onAnchorAvailable = this.onAnchorAvailable;
    if (onAnchorAvailable != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onAnchorAvailable(context);
      });
    }
    final colors = BusyMaxSurfaceColors.of(context);
    final indentationLevel = depth.clamp(1, 12).toInt();
    final subtitle = subtitleBuilder?.call(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: BusyMaxSpacing.lg + (indentationLevel - 1) * BusyMaxSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: colors.cardShade)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: BusyMaxSpacing.xs),
          child: BusyMaxActionRow(
            title: title,
            titleWidget: AnimatedDefaultTextStyle(
              duration:
                  MediaQuery.disableAnimationsOf(context) || !animateCompletion
                  ? Duration.zero
                  : BusyMaxMotion.taskCompletion,
              curve: BusyMaxMotion.presentationCurve,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                decoration: completed ? TextDecoration.lineThrough : null,
                color: completed
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
              ),
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            subtitle: subtitle,
            leading: Icon(
              BusyMaxGlyphs.subdirectoryFor(Directionality.of(context)),
              size: BusyMaxSizes.iconSm,
              color: colors.mutedForeground,
            ),
            trailing: BusyMaxYaruFocusBorder(
              builder: (context, focusNode) => YaruCheckbox(
                value: completed,
                focusNode: focusNode,
                hasFocusBorder: false,
                onChanged: onCompletionChanged == null
                    ? null
                    : (value) => onCompletionChanged!(value ?? false),
              ),
            ),
            onActivated: onTap,
          ),
        ),
      ),
    );
  }
}

class _AgendaItemMarker extends StatelessWidget {
  const _AgendaItemMarker({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final isTask = item.kind == ScheduleItemKind.task;
    final color = isTask
        ? BusyMaxSurfaceColors.of(context).mutedForeground
        : ScheduleProjection.colorForItem(
            item,
            Theme.of(context).colorScheme.brightness,
          );
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    final icon = task?.parentId != null
        ? BusyMaxGlyphs.subdirectoryFor(Directionality.of(context))
        : task?.hasSubtasks == true
        ? Icons.account_tree_outlined
        : isTask
        ? YaruIcons.task_list
        : YaruIcons.calendar;
    return Icon(icon, size: BusyMaxSizes.iconSm, color: color);
  }
}

class _AgendaItemTitle extends StatelessWidget {
  const _AgendaItemTitle({
    required this.item,
    this.completedOverride,
    this.animateCompletion = false,
  });

  final ScheduleItem item;
  final bool? completedOverride;
  final bool animateCompletion;

  @override
  Widget build(BuildContext context) {
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    final completed = completedOverride ?? task?.completed == true;
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedDefaultTextStyle(
      duration: MediaQuery.disableAnimationsOf(context) || !animateCompletion
          ? Duration.zero
          : BusyMaxMotion.taskCompletion,
      curve: BusyMaxMotion.presentationCurve,
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontWeight: FontWeight.w600,
        decoration: completed ? TextDecoration.lineThrough : null,
        color: completed ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
      ),
      child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class _AgendaItemSubtitle extends StatelessWidget {
  const _AgendaItemSubtitle({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    final values = [
      scheduleTimeRange(context, item),
      if (task?.parentTitle != null)
        '${context.l10n.parent}: ${task!.parentTitle}',
      ScheduleProjection.sourceLabelForScheduleItem(item),
    ].where((value) => value.trim().isNotEmpty).join(' - ');
    return Text(
      values,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: BusyMaxSurfaceColors.of(context).mutedForeground,
      ),
    );
  }
}

String _dayLabel(BuildContext context, DateTime day) {
  if (DateUtils.isSameDay(day, DateTime.now())) {
    return context.l10n.today;
  }
  if (DateUtils.isSameDay(day, DateTime.now().add(const Duration(days: 1)))) {
    return context.l10n.tomorrow;
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  return localizedDayHeading(locale, day);
}

String _nestedTaskScheduleLabel(
  BuildContext context,
  TaskScheduleItem task,
  TaskScheduleItem hierarchyRoot,
) {
  final start = task.start;
  final rootStart = hierarchyRoot.start;
  if (start == null) {
    return rootStart == null ? '' : context.l10n.noDate;
  }
  if (rootStart != null && DateUtils.isSameDay(start, rootStart)) {
    return scheduleTimeRange(context, task);
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = DateFormat.yMMMd(locale).format(start);
  if (task.allDay) return date;
  final time = scheduleTimeRange(context, task);
  return time.trim().isEmpty ? date : '$date - $time';
}

String _agendaTaskKey(TaskScheduleItem task) =>
    '${task.accountId}\u0000${task.sourceId}\u0000${task.id}';

String? _agendaParentKey(TaskScheduleItem task) {
  final parentId = task.parentId;
  if (parentId == null || parentId.isEmpty) return null;
  return '${task.accountId}\u0000${task.sourceId}\u0000$parentId';
}

class _AgendaHierarchyIndex {
  _AgendaHierarchyIndex(List<ScheduleItem> items)
    : tasks = {
        for (final task in items.whereType<TaskScheduleItem>())
          _agendaTaskKey(task): task,
      } {
    for (final task in tasks.values) {
      final parentKey = _agendaParentKey(task);
      if (parentKey != null && tasks.containsKey(parentKey)) {
        children.putIfAbsent(parentKey, () => []).add(task);
      }
    }
  }

  final Map<String, TaskScheduleItem> tasks;
  final Map<String, List<TaskScheduleItem>> children = {};

  bool isCyclic(TaskScheduleItem task) {
    final visited = <String>{};
    TaskScheduleItem? current = task;
    while (current != null) {
      final key = _agendaTaskKey(current);
      if (!visited.add(key)) return true;
      final parentKey = _agendaParentKey(current);
      if (parentKey == null) return false;
      current = tasks[parentKey];
    }
    return false;
  }
}
