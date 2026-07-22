import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../core/logging/redacting_logger.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/main_window_command_client.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../task_providers/task_provider.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../calendar/presentation/event_editor.dart';
import '../../calendar/presentation/event_editor_draft.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../../tasks/data/tasks_repository.dart';
import '../../tasks/presentation/new_task_dialog.dart';
import '../../tasks/presentation/task_details_pane.dart';
import '../application/compact_agenda_controller.dart';
import '../application/compact_agenda_data.dart';
import '../application/compact_agenda_sections.dart';
import 'compact_agenda_formatting.dart';
import 'schedule_item_details_popover.dart';
import 'schedule_item_exporter.dart';

typedef CompactAgendaTaskCompletionCallback =
    Future<void> Function(TaskScheduleItem item, bool completed);

const _compactAgendaMinimumLayoutSize = Size(320, 480);

class CompactAgendaPanel extends ConsumerStatefulWidget {
  const CompactAgendaPanel({
    super.key,
    this.data,
    this.onOpenBusyMax,
    this.onNewTask,
    this.onRefresh,
    this.onHide,
    this.onOpenItem,
    this.onTaskCompletionChanged,
  });

  final AsyncValue<CompactAgendaData>? data;
  final Future<void> Function()? onOpenBusyMax;
  final Future<void> Function()? onNewTask;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onHide;
  final Future<void> Function(ScheduleItem item)? onOpenItem;
  final CompactAgendaTaskCompletionCallback? onTaskCompletionChanged;

  @override
  ConsumerState<CompactAgendaPanel> createState() => _CompactAgendaPanelState();
}

class _CompactAgendaPanelState extends ConsumerState<CompactAgendaPanel> {
  final _mutatingTaskKeys = <String>{};
  var _loadedDays = compactAgendaInitialDays;
  var _overdueLimit = compactAgendaInitialOverdueLimit;
  var _noDateLimit = compactAgendaInitialNoDateLimit;
  var _loadMoreArmed = true;
  DateTime? _lastLoadedRangeEnd;
  CompactAgendaData? _lastAgendaData;
  bool _bodyScrolledUnderHeader = false;
  bool _bodyScrolledUnderFooter = false;
  bool _creatingTask = false;
  bool _creatingEvent = false;
  TaskScheduleItem? _editingTask;
  EventEditorDraft? _editingEventDraft;

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final AsyncValue<CompactAgendaData> watchedData =
        widget.data ?? ref.watch(compactAgendaDataForQueryProvider(_query));
    final currentData = watchedData.valueOrNull;
    if (currentData != null) {
      _lastAgendaData = currentData;
      if (_lastLoadedRangeEnd != currentData.range.end) {
        _lastLoadedRangeEnd = currentData.range.end;
        _loadMoreArmed = true;
      }
    }
    final data = watchedData.isLoading && _lastAgendaData != null
        ? AsyncData(_lastAgendaData!)
        : watchedData;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _HideIntent(),
        SingleActivator(LogicalKeyboardKey.keyR, control: true):
            _RefreshIntent(),
      },
      child: Actions(
        actions: {
          _HideIntent: CallbackAction<_HideIntent>(
            onInvoke: (_) {
              unawaited(_hide());
              return null;
            },
          ),
          _RefreshIntent: CallbackAction<_RefreshIntent>(
            onInvoke: (_) {
              unawaited(_refresh());
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <
                      _compactAgendaMinimumLayoutSize.width ||
                  constraints.maxHeight <
                      _compactAgendaMinimumLayoutSize.height) {
                return const SizedBox.expand();
              }

              final child = _editingTask != null
                  ? _CompactAgendaTaskEditorView(
                      item: _editingTask!,
                      onClose: _closeTaskEditor,
                    )
                  : _creatingEvent || _editingEventDraft != null
                  ? _CompactAgendaEventEditorView(
                      initialDraft: _editingEventDraft,
                      categorySuggestionsByAccount:
                          _categorySuggestionsByAccount(),
                      onCancel: _closeEventEditor,
                      onSave: _saveEvent,
                      onDelete: _deleteEvent,
                    )
                  : _creatingTask
                  ? _CompactAgendaNewTaskView(
                      onCancel: _closeNewTaskEditor,
                      onSubmitted: _createTask,
                    )
                  : Column(
                      children: [
                        _CompactAgendaHeader(
                          data: data.valueOrNull,
                          onRefresh: _refresh,
                          onHide: _hide,
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              NotificationListener<ScrollMetricsNotification>(
                                onNotification:
                                    _handleScrollMetricsNotification,
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: _handleScrollNotification,
                                  child: ColoredBox(
                                    color: colorScheme.surface,
                                    child: _body(data),
                                  ),
                                ),
                              ),
                              _CompactAgendaScrollShadow(
                                visible: _bodyScrolledUnderHeader,
                                below: true,
                              ),
                              _CompactAgendaScrollShadow(
                                visible: _bodyScrolledUnderFooter,
                                below: false,
                              ),
                            ],
                          ),
                        ),
                        _CompactAgendaBottomBar(
                          onNewEvent: _newEvent,
                          onNewTask: _newTask,
                        ),
                      ],
                    );

              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(BusyMaxRadius.window),
                  boxShadow: BusyMaxShadow.windowShadowsFor(context),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BusyMaxRadius.window),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.card,
                      border: Border.all(color: colors.border),
                    ),
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(AsyncValue<CompactAgendaData> data) {
    return data.when(
      loading: () => const _CompactAgendaLoadingState(),
      error: (error, stackTrace) => _CompactAgendaMessageState(
        icon: Icons.event_busy_outlined,
        title: context.l10n.trayAgendaError,
        message: redactForLog(error),
        primaryLabel: context.l10n.compactAgendaRetry,
        onPrimary: _refresh,
        secondaryLabel: context.l10n.compactAgendaOpenBusyMax,
        onSecondary: _openBusyMax,
      ),
      data: (agenda) {
        if (!agenda.hasSignedInAccounts) {
          _scheduleScrollChromeReset();
          return _CompactAgendaMessageState(
            icon: Icons.login,
            title: context.l10n.trayAgendaSignInRequired,
            primaryLabel: context.l10n.compactAgendaOpenBusyMax,
            onPrimary: _openBusyMax,
          );
        }
        if (!agenda.hasSources) {
          _scheduleScrollChromeReset();
          return _CompactAgendaMessageState(
            icon: Icons.event_busy_outlined,
            title: context.l10n.trayAgendaNoSources,
            primaryLabel: context.l10n.compactAgendaOpenBusyMax,
            onPrimary: _openBusyMax,
          );
        }
        if (agenda.items.isEmpty) {
          _scheduleScrollChromeReset();
          return _CompactAgendaMessageState(
            icon: Icons.event_available,
            title: context.l10n.compactAgendaClear,
            message: context.l10n.noEventsOrTasks,
          );
        }
        return _sections(agenda);
      },
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    _updateScrollChrome(notification.metrics);
    _maybeLoadMore(notification.metrics);
    return false;
  }

  bool _handleScrollMetricsNotification(
    ScrollMetricsNotification notification,
  ) {
    _updateScrollChrome(notification.metrics);
    return false;
  }

  void _updateScrollChrome(ScrollMetrics metrics) {
    final pixels = metrics.pixels.clamp(0.0, metrics.maxScrollExtent);
    final scrolledFromTop = pixels > 0.5;
    final canScrollFurtherDown = metrics.maxScrollExtent - pixels > 0.5;
    _setScrollChrome(
      header: scrolledFromTop,
      footer: scrolledFromTop && canScrollFurtherDown,
    );
  }

  void _scheduleScrollChromeReset() {
    if (!_bodyScrolledUnderHeader && !_bodyScrolledUnderFooter) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setScrollChrome(header: false, footer: false);
      }
    });
  }

  void _setScrollChrome({required bool header, required bool footer}) {
    if (_bodyScrolledUnderHeader == header &&
        _bodyScrolledUnderFooter == footer) {
      return;
    }
    setState(() {
      _bodyScrolledUnderHeader = header;
      _bodyScrolledUnderFooter = footer;
    });
  }

  void _maybeLoadMore(ScrollMetrics metrics) {
    if (widget.data != null ||
        !_loadMoreArmed ||
        metrics.axis != Axis.vertical ||
        metrics.extentAfter > 1) {
      return;
    }
    final agenda = _lastAgendaData;
    if (agenda == null || !agenda.hasSignedInAccounts || !agenda.hasSources) {
      return;
    }
    _loadMoreArmed = false;
    setState(() {
      _loadedDays += compactAgendaPageDays;
    });
  }

  Widget _sections(CompactAgendaData data) {
    final sections = buildCompactAgendaSections(
      today: data.today,
      end: data.range.end,
      items: data.items,
      overdueLimit: _overdueLimit,
      noDateLimit: _noDateLimit,
      hasMoreOverdueTasks: data.hasMoreOverdueTasks,
      hasMoreNoDateTasks: data.hasMoreNoDateTasks,
    );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        BusyMaxSpacing.md,
        BusyMaxSpacing.sm,
        BusyMaxSpacing.md,
        BusyMaxSpacing.md,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return _CompactAgendaSectionView(
          section: section,
          today: data.today,
          mutatingTaskKeys: _mutatingTaskKeys,
          onOpenItem: _openItem,
          onTaskCompletionChanged: _setTaskCompleted,
          onLoadMoreOverdue: _loadMoreOverdue,
          onLoadMoreNoDate: _loadMoreNoDate,
        );
      },
    );
  }

  void _loadMoreOverdue() {
    setState(() {
      _overdueLimit += compactAgendaOverduePageSize;
    });
  }

  void _loadMoreNoDate() {
    setState(() {
      _noDateLimit += compactAgendaNoDatePageSize;
    });
  }

  Future<void> _openBusyMax() async {
    final callback = widget.onOpenBusyMax;
    if (callback != null) {
      await callback();
      return;
    }
    await const MainWindowCommandClient().openMain();
    await windowManager.hide();
  }

  Future<void> _newTask() async {
    final callback = widget.onNewTask;
    if (callback != null) {
      await callback();
      return;
    }
    setState(() {
      _creatingTask = true;
      _creatingEvent = false;
      _editingTask = null;
      _editingEventDraft = null;
      _bodyScrolledUnderHeader = false;
      _bodyScrolledUnderFooter = false;
    });
  }

  Future<void> _newEvent() async {
    setState(() {
      _creatingEvent = true;
      _creatingTask = false;
      _editingTask = null;
      _editingEventDraft = null;
      _bodyScrolledUnderHeader = false;
      _bodyScrolledUnderFooter = false;
    });
  }

  void _closeNewTaskEditor() {
    if (!_creatingTask) {
      return;
    }
    setState(() {
      _creatingTask = false;
    });
  }

  Future<void> _createTask(NewTaskDraft draft) async {
    await ref
        .read(compactAgendaControllerProvider)
        .createTask(
          accountId: draft.accountId,
          taskListId: draft.taskListId,
          input: draft.input,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _creatingTask = false;
    });
    _invalidateAgendaData();
  }

  void _openTaskEditor(TaskScheduleItem item) {
    setState(() {
      _editingTask = item;
      _creatingTask = false;
      _creatingEvent = false;
      _editingEventDraft = null;
      _bodyScrolledUnderHeader = false;
      _bodyScrolledUnderFooter = false;
    });
  }

  void _closeTaskEditor() {
    if (_editingTask == null) {
      return;
    }
    setState(() {
      _editingTask = null;
    });
    _invalidateAgendaData();
  }

  void _openEventEditor(CalendarScheduleItem item) {
    setState(() {
      _editingEventDraft = _eventDraftFromItem(item);
      _creatingEvent = false;
      _creatingTask = false;
      _editingTask = null;
      _bodyScrolledUnderHeader = false;
      _bodyScrolledUnderFooter = false;
    });
  }

  void _closeEventEditor() {
    if (!_creatingEvent && _editingEventDraft == null) {
      return;
    }
    setState(() {
      _creatingEvent = false;
      _editingEventDraft = null;
    });
    _invalidateAgendaData();
  }

  Future<void> _saveEvent(EventEditorDraft draft) async {
    await ref.read(compactAgendaControllerProvider).saveEvent(draft);
    if (!mounted) {
      return;
    }
    setState(() {
      _creatingEvent = false;
      _editingEventDraft = null;
    });
    _invalidateAgendaData();
  }

  Future<void> _deleteEvent(String eventId) async {
    await ref.read(compactAgendaControllerProvider).deleteEvent(eventId);
    if (!mounted) {
      return;
    }
    setState(() {
      _creatingEvent = false;
      _editingEventDraft = null;
    });
    _invalidateAgendaData();
  }

  Future<void> _refresh() async {
    final callback = widget.onRefresh;
    if (callback != null) {
      await callback();
      return;
    }
    _invalidateAgendaData();
  }

  Future<void> _hide() async {
    final callback = widget.onHide;
    if (callback != null) {
      await callback();
      return;
    }
    await windowManager.hide();
  }

  Future<void> _openItem(
    BuildContext anchorContext,
    ScheduleItem item, [
    Offset? globalPosition,
  ]) async {
    final callback = widget.onOpenItem;
    if (callback != null) {
      await callback(item);
      return;
    }
    final action = await showScheduleItemDetailsPopover(
      context: context,
      anchorContext: anchorContext,
      item: item,
      anchorPoint: globalPosition,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case ScheduleItemDetailsAction.export:
        await _exportItem(item);
      case ScheduleItemDetailsAction.edit:
        if (item is TaskScheduleItem) {
          _openTaskEditor(item);
        } else if (item is CalendarScheduleItem) {
          _openEventEditor(item);
        } else {
          await const MainWindowCommandClient().openScheduleItem(item);
          await windowManager.hide();
        }
      case ScheduleItemDetailsAction.delete:
        await _deleteItem(item);
    }
  }

  Future<void> _exportItem(ScheduleItem item) async {
    try {
      final file = await exportScheduleItemWithSaveDialog(item);
      if (file == null || !mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.exportedFile(file.path))),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.exportFailed(redactForLog(error)))),
      );
    }
  }

  Future<void> _deleteItem(ScheduleItem item) async {
    final confirmed = await showBusyMaxConfirm(
      context,
      title: item is CalendarScheduleItem
          ? context.l10n.deleteEvent
          : context.l10n.deleteTask,
      message: item is TaskScheduleItem
          ? context.l10n.deleteTaskConfirmation(item.title)
          : 'Delete "${item.title}"?',
      confirmLabel: context.l10n.delete,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    try {
      if (item is CalendarScheduleItem) {
        await _deleteEvent(item.id);
      } else if (item is TaskScheduleItem) {
        await ref.read(compactAgendaControllerProvider).deleteTask(item);
      }
      if (!mounted) {
        return;
      }
      _invalidateAgendaData();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(redactForLog(error))));
    }
  }

  Future<void> _setTaskCompleted(TaskScheduleItem item, bool completed) async {
    final key = compactAgendaTaskMutationKey(item);
    if (_mutatingTaskKeys.contains(key)) {
      return;
    }
    setState(() => _mutatingTaskKeys.add(key));
    try {
      final callback = widget.onTaskCompletionChanged;
      if (callback != null) {
        await callback(item, completed);
      } else {
        await ref
            .read(compactAgendaControllerProvider)
            .setTaskCompleted(item, completed);
      }
      _invalidateAgendaData();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(redactForLog(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _mutatingTaskKeys.remove(key));
      }
    }
  }

  void _invalidateAgendaData() {
    ref.invalidate(compactAgendaDataProvider);
    ref.invalidate(compactAgendaDataForQueryProvider(_query));
  }

  CompactAgendaQuery get _query {
    return CompactAgendaQuery(
      futureDays: _loadedDays,
      overdueLimit: _overdueLimit,
      noDateLimit: _noDateLimit,
    );
  }

  EventEditorDraft _eventDraftFromItem(CalendarScheduleItem item) {
    return EventEditorDraft.existing(
      eventId: item.id,
      accountId: item.accountId,
      sourceId: item.sourceId,
      providerCalendarId: item.providerCalendarId,
      providerRecurringEventId: item.providerRecurringEventId,
      title: item.title,
      allDay: item.allDay,
      start: item.editorStart ?? item.start,
      end: item.editorEnd ?? item.end,
      startTimeZone: item.startTimeZone,
      endTimeZone: item.endTimeZone,
      location: item.location,
      description: item.description,
      descriptionContentType: item.descriptionContentType,
      descriptionHtml: item.descriptionHtml,
      recurrence: item.recurrence,
      attendees: [
        for (final attendee in item.attendees)
          EventAttendeeDraft.fromJson(attendee),
      ],
      reminders: _eventRemindersForEdit(
        item.provider,
        item.reminderMinutesBeforeStart,
      ),
      categories: item.categories,
    );
  }

  Map<String, List<String>> _categorySuggestionsByAccount() {
    final byAccount = <String, Set<String>>{};
    for (final item in _lastAgendaData?.items ?? const <ScheduleItem>[]) {
      if (item.categories.isEmpty) {
        continue;
      }
      byAccount
          .putIfAbsent(item.accountId, () => <String>{})
          .addAll(
            item.categories
                .map((category) => category.trim())
                .where((category) => category.isNotEmpty),
          );
    }
    return {
      for (final entry in byAccount.entries)
        entry.key: (entry.value.toList()..sort()),
    };
  }
}

EventEditorDraft _newEventDraft(List<CalendarSourceEntity> sources) {
  final source = sources.first;
  final start = _defaultNewEventStart();
  return EventEditorDraft.newEvent(
    accountId: source.accountId,
    sourceId: source.id,
    providerCalendarId: source.providerCalendarId,
    start: start,
    end: start.add(const Duration(hours: 1)),
  );
}

DateTime _defaultNewEventStart() {
  final now = DateTime.now();
  final base = DateTime(now.year, now.month, now.day, now.hour);
  return now.minute < 30
      ? base.add(const Duration(minutes: 30))
      : base.add(const Duration(hours: 1));
}

List<CalendarSourceEntity> _editableSources(
  List<CalendarSourceEntity> sources, {
  required String? currentSourceId,
}) {
  final visibleEditable = [
    for (final source in sources)
      if (!source.isDeleted &&
          !source.hidden &&
          source.selected &&
          (!source.readOnly || source.id == currentSourceId))
        source,
  ];
  if (visibleEditable.isNotEmpty) {
    return visibleEditable;
  }
  return [
    for (final source in sources)
      if (!source.isDeleted &&
          !source.hidden &&
          (!source.readOnly || source.id == currentSourceId))
        source,
  ];
}

Object? _eventRemindersForEdit(BusyProvider provider, List<int> minutes) {
  final normalized = [
    for (final value in minutes)
      if (value > 0) value,
  ];
  if (normalized.isEmpty) {
    return null;
  }
  if (provider == TaskProvider.google) {
    return {
      'useDefault': false,
      'overrides': [
        for (final minutes in normalized)
          {'method': 'popup', 'minutes': minutes},
      ],
    };
  }
  return {'isReminderOn': true, 'reminderMinutesBeforeStart': normalized.first};
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

class _CompactAgendaHeader extends StatelessWidget {
  const _CompactAgendaHeader({
    required this.data,
    required this.onRefresh,
    required this.onHide,
  });

  final CompactAgendaData? data;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onHide;

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    final subtitle = compactAgendaTodaySubtitle(
      context,
      data?.today ?? DateTime.now(),
    );
    return DragToMoveArea(
      child: Container(
        height: 56,
        key: const ValueKey('compactAgendaHeader'),
        padding: const EdgeInsets.symmetric(horizontal: BusyMaxSpacing.md),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.compactAgendaTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            _CompactHeaderButton(
              tooltip: context.l10n.compactAgendaRefresh,
              icon: Icons.refresh,
              onPressed: () => unawaited(onRefresh()),
            ),
            const SizedBox(width: BusyMaxSpacing.xs),
            YaruWindowControl(
              type: YaruWindowControlType.close,
              semanticLabel: context.l10n.compactAgendaHide,
              onTap: () => unawaited(onHide()),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactHeaderButton extends StatelessWidget {
  const _CompactHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return YaruIconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: BusyMaxSizes.iconMd,
      onPressed: onPressed,
      style: busyMaxHeaderIconButtonStyle(
        foregroundColor: BusyMaxSurfaceColors.of(context).foreground,
        backgroundColor: busyMaxSubtleButtonBackground(context),
      ),
    );
  }
}

class _CompactAgendaTaskEditorView extends ConsumerWidget {
  const _CompactAgendaTaskEditorView({
    required this.item,
    required this.onClose,
  });

  final TaskScheduleItem item;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.read(databaseProvider);
    final controller = ref.read(compactAgendaControllerProvider);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: TaskDetailsPane(
        accountId: item.accountId,
        taskListId: item.sourceId,
        taskId: item.id,
        tasksRepositoryForAccount: (accountId) =>
            TasksRepository(database: database, accountId: accountId),
        taskListsRepositoryForAccount: (accountId) =>
            TaskListsRepository(database: database, accountId: accountId),
        onTaskMutationCommitted: controller.taskMutated,
        onClose: onClose,
        dialogBarrierColor: Colors.transparent,
      ),
    );
  }
}

class _CompactAgendaEventEditorView extends ConsumerStatefulWidget {
  const _CompactAgendaEventEditorView({
    required this.initialDraft,
    required this.categorySuggestionsByAccount,
    required this.onCancel,
    required this.onSave,
    required this.onDelete,
  });

  final EventEditorDraft? initialDraft;
  final Map<String, List<String>> categorySuggestionsByAccount;
  final VoidCallback onCancel;
  final Future<void> Function(EventEditorDraft draft) onSave;
  final Future<void> Function(String eventId) onDelete;

  @override
  ConsumerState<_CompactAgendaEventEditorView> createState() =>
      _CompactAgendaEventEditorViewState();
}

class _CompactAgendaEventEditorViewState
    extends ConsumerState<_CompactAgendaEventEditorView> {
  late final CalendarRepository _repository;
  Stream<List<CalendarSourceEntity>>? _sourcesStream;
  List<String>? _sourceAccountIds;

  @override
  void initState() {
    super.initState();
    _repository = CalendarRepository(
      database: ref.read(databaseProvider),
      localTimeZone: ref.read(localTimeZoneProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsStreamProvider);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: accounts.when(
        loading: () => const _CompactAgendaLoadingState(),
        error: (error, stackTrace) => _CompactAgendaMessageState(
          icon: Icons.event_busy_outlined,
          title: context.l10n.trayAgendaError,
          message: redactForLog(error),
          primaryLabel: context.l10n.cancel,
          onPrimary: () async => widget.onCancel(),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return _CompactAgendaMessageState(
              icon: Icons.login,
              title: context.l10n.trayAgendaSignInRequired,
              primaryLabel: context.l10n.cancel,
              onPrimary: () async => widget.onCancel(),
            );
          }
          final accountIds = [for (final account in accounts) account.id];
          return StreamBuilder<List<CalendarSourceEntity>>(
            stream: _watchSources(accountIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const _CompactAgendaLoadingState();
              }
              final sources = _editableSources(
                snapshot.data ?? const <CalendarSourceEntity>[],
                currentSourceId: widget.initialDraft?.sourceId,
              );
              if (sources.isEmpty) {
                return _CompactAgendaMessageState(
                  icon: Icons.event_busy_outlined,
                  title: context.l10n.trayAgendaNoSources,
                  primaryLabel: context.l10n.cancel,
                  onPrimary: () async => widget.onCancel(),
                );
              }
              final draft = widget.initialDraft ?? _newEventDraft(sources);
              return EventEditor(
                initialDraft: draft,
                sources: sources,
                categorySuggestionsByAccount:
                    widget.categorySuggestionsByAccount,
                onCancel: widget.onCancel,
                onSave: (draft) => unawaited(_save(draft)),
                onDelete: draft.eventId == null
                    ? null
                    : (eventId) => unawaited(_delete(eventId)),
              );
            },
          );
        },
      ),
    );
  }

  Stream<List<CalendarSourceEntity>> _watchSources(List<String> accountIds) {
    if (_sourcesStream == null ||
        _sourceAccountIds == null ||
        !_listEquals(_sourceAccountIds!, accountIds)) {
      _sourceAccountIds = accountIds;
      _sourcesStream = _repository
          .watchSourcesForAccounts(accountIds)
          .asBroadcastStream();
    }
    return _sourcesStream!;
  }

  Future<void> _save(EventEditorDraft draft) async {
    try {
      await widget.onSave(draft);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(redactForLog(error))));
    }
  }

  Future<void> _delete(String eventId) async {
    try {
      await widget.onDelete(eventId);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(redactForLog(error))));
    }
  }
}

class _CompactAgendaNewTaskView extends ConsumerWidget {
  const _CompactAgendaNewTaskView({
    required this.onCancel,
    required this.onSubmitted,
  });

  final VoidCallback onCancel;
  final Future<void> Function(NewTaskDraft draft) onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: accounts.when(
        loading: () => const _CompactAgendaLoadingState(),
        error: (error, stackTrace) => _CompactAgendaMessageState(
          icon: Icons.event_busy_outlined,
          title: context.l10n.trayAgendaError,
          message: redactForLog(error),
          primaryLabel: context.l10n.cancel,
          onPrimary: () async => onCancel(),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return _CompactAgendaMessageState(
              icon: Icons.login,
              title: context.l10n.trayAgendaSignInRequired,
              primaryLabel: context.l10n.cancel,
              onPrimary: () async => onCancel(),
            );
          }
          return NewTaskEditorPanel(
            accounts: accounts,
            categorySuggestionsForAccount: (accountId) => TasksRepository(
              database: ref.read(databaseProvider),
              accountId: accountId,
            ).watchCategorySuggestions(),
            onSubmitted: onSubmitted,
            onCancel: onCancel,
          );
        },
      ),
    );
  }
}

class _CompactAgendaLoadingState extends StatelessWidget {
  const _CompactAgendaLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(BusyMaxSpacing.md),
            itemCount: 4,
            separatorBuilder: (_, _) =>
                const SizedBox(height: BusyMaxSpacing.sm),
            itemBuilder: (context, index) => const _SkeletonRow(),
          ),
        ),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    return Container(
      height: 62,
      padding: const EdgeInsets.all(BusyMaxSpacing.md),
      decoration: BoxDecoration(
        color: colors.control,
        borderRadius: BorderRadius.circular(BusyMaxRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FractionallySizedBox(
            widthFactor: 0.68,
            child: Container(height: 10, color: colors.controlHover),
          ),
          const SizedBox(height: BusyMaxSpacing.sm),
          FractionallySizedBox(
            widthFactor: 0.42,
            child: Container(height: 8, color: colors.controlHover),
          ),
        ],
      ),
    );
  }
}

class _CompactAgendaMessageState extends StatelessWidget {
  const _CompactAgendaMessageState({
    required this.icon,
    required this.title,
    this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? primaryLabel;
  final Future<void> Function()? onPrimary;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = BusyMaxSurfaceColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - BusyMaxSpacing.xl * 2)
                  .clamp(0.0, double.infinity)
                  .toDouble()
            : 0.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(BusyMaxSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 34, color: colors.mutedForeground),
                  const SizedBox(height: BusyMaxSpacing.md),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message != null && message!.isNotEmpty) ...[
                    const SizedBox(height: BusyMaxSpacing.sm),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                  if (primaryLabel != null || secondaryLabel != null) ...[
                    const SizedBox(height: BusyMaxSpacing.lg),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: BusyMaxSpacing.sm,
                      runSpacing: BusyMaxSpacing.sm,
                      children: [
                        if (primaryLabel != null)
                          BusyMaxPushButton.filled(
                            onPressed: onPrimary == null
                                ? null
                                : () => unawaited(onPrimary!()),
                            child: Text(primaryLabel!),
                          ),
                        if (secondaryLabel != null)
                          BusyMaxPushButton.outlined(
                            onPressed: onSecondary == null
                                ? null
                                : () => unawaited(onSecondary!()),
                            child: Text(secondaryLabel!),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompactAgendaSectionView extends StatelessWidget {
  const _CompactAgendaSectionView({
    required this.section,
    required this.today,
    required this.mutatingTaskKeys,
    required this.onOpenItem,
    required this.onTaskCompletionChanged,
    required this.onLoadMoreOverdue,
    required this.onLoadMoreNoDate,
  });

  final CompactAgendaSection section;
  final DateTime today;
  final Set<String> mutatingTaskKeys;
  final Future<void> Function(
    BuildContext anchorContext,
    ScheduleItem item, [
    Offset? globalPosition,
  ])
  onOpenItem;
  final CompactAgendaTaskCompletionCallback onTaskCompletionChanged;
  final VoidCallback onLoadMoreOverdue;
  final VoidCallback onLoadMoreNoDate;

  @override
  Widget build(BuildContext context) {
    final title = switch (section.kind) {
      CompactAgendaSectionKind.overdue => context.l10n.compactAgendaOverdue,
      CompactAgendaSectionKind.day => compactAgendaDayLabel(
        context,
        today: today,
        day: section.day ?? today,
      ),
      CompactAgendaSectionKind.noDate => context.l10n.noDate,
    };
    return BusyMaxGroupedList(
      title: title,
      filled: true,
      children: [
        for (final item in section.items)
          _CompactAgendaRow(
            item: item,
            today: today,
            mutating:
                item is TaskScheduleItem &&
                mutatingTaskKeys.contains(compactAgendaTaskMutationKey(item)),
            onOpenItem: onOpenItem,
            onTaskCompletionChanged: onTaskCompletionChanged,
          ),
        if (section.hasMore)
          _MoreBucketRow(
            title: switch (section.kind) {
              CompactAgendaSectionKind.overdue =>
                context.l10n.agendaLoadMoreOverdue,
              CompactAgendaSectionKind.noDate =>
                context.l10n.agendaLoadMoreNoDate,
              CompactAgendaSectionKind.day =>
                context.l10n.agendaLoadMoreOverdue,
            },
            onLoadMore: switch (section.kind) {
              CompactAgendaSectionKind.overdue => onLoadMoreOverdue,
              CompactAgendaSectionKind.noDate => onLoadMoreNoDate,
              CompactAgendaSectionKind.day => onLoadMoreOverdue,
            },
          ),
      ],
    );
  }
}

class _CompactAgendaRow extends StatelessWidget {
  const _CompactAgendaRow({
    required this.item,
    required this.today,
    required this.mutating,
    required this.onOpenItem,
    required this.onTaskCompletionChanged,
  });

  final ScheduleItem item;
  final DateTime today;
  final bool mutating;
  final Future<void> Function(
    BuildContext anchorContext,
    ScheduleItem item, [
    Offset? globalPosition,
  ])
  onOpenItem;
  final CompactAgendaTaskCompletionCallback onTaskCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    return AnimatedOpacity(
      opacity: mutating ? 0.48 : 1,
      duration: const Duration(milliseconds: 120),
      child: BusyMaxActionRow(
        title: item.title,
        titleWidget: _CompactAgendaRowTitle(item: item),
        subtitleWidget: _CompactAgendaRowSubtitle(item: item, today: today),
        leading: _CompactAgendaRowMarker(item: item),
        trailing: task == null
            ? null
            : YaruCheckbox(
                value: task.completed,
                onChanged: mutating
                    ? null
                    : (value) => unawaited(
                        onTaskCompletionChanged(task, value ?? false),
                      ),
              ),
        enabled: !mutating,
        onActivated: (rowContext, globalPosition) =>
            unawaited(onOpenItem(rowContext, item, globalPosition)),
      ),
    );
  }
}

class _CompactAgendaRowMarker extends StatelessWidget {
  const _CompactAgendaRowMarker({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final isTask = item.kind == ScheduleItemKind.task;
    final color = BusyMaxSurfaceColors.of(context).mutedForeground;
    final icon = isTask ? YaruIcons.task_list : YaruIcons.calendar;
    return Icon(icon, size: BusyMaxSizes.iconSm, color: color);
  }
}

class _CompactAgendaRowTitle extends StatelessWidget {
  const _CompactAgendaRowTitle({required this.item});

  final ScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final task = item is TaskScheduleItem ? item as TaskScheduleItem : null;
    return Text(
      item.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        decoration: task?.completed == true ? TextDecoration.lineThrough : null,
      ),
    );
  }
}

class _CompactAgendaRowSubtitle extends StatelessWidget {
  const _CompactAgendaRowSubtitle({required this.item, required this.today});

  final ScheduleItem item;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyMaxSurfaceColors.of(context);
    final source = ScheduleProjection.sourceLabelForScheduleItem(item);
    final meta = compactAgendaItemMeta(context, item, today: today);
    final event = item is CalendarScheduleItem
        ? item as CalendarScheduleItem
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          [if (meta.isNotEmpty) meta, source].join(' - '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: surfaceColors.mutedForeground),
        ),
        if (event?.location?.trim().isNotEmpty == true)
          Text(
            event!.location!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: surfaceColors.mutedForeground,
            ),
          ),
      ],
    );
  }
}

class _MoreBucketRow extends StatelessWidget {
  const _MoreBucketRow({required this.title, required this.onLoadMore});

  final String title;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return BusyMaxActionRow(
      title: title,
      leading: const Icon(YaruIcons.plus, size: BusyMaxSizes.iconSm),
      onTap: onLoadMore,
    );
  }
}

class _CompactAgendaBottomBar extends StatelessWidget {
  const _CompactAgendaBottomBar({
    required this.onNewEvent,
    required this.onNewTask,
  });

  final Future<void> Function() onNewEvent;
  final Future<void> Function() onNewTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('compactAgendaFooter'),
      padding: const EdgeInsets.all(BusyMaxSpacing.md),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
      child: Row(
        children: [
          Expanded(
            child: BusyMaxPushButton.filled(
              onPressed: () => unawaited(onNewEvent()),
              child: Text(context.l10n.newEvent),
            ),
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
          Expanded(
            child: BusyMaxPushButton.filled(
              onPressed: () => unawaited(onNewTask()),
              child: Text(context.l10n.compactAgendaNewTask),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactAgendaScrollShadow extends StatelessWidget {
  const _CompactAgendaScrollShadow({
    required this.visible,
    required this.below,
  });

  final bool visible;
  final bool below;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        key: ValueKey(
          below
              ? 'compactAgendaTopScrollShadow'
              : 'compactAgendaBottomScrollShadow',
        ),
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: Align(
          alignment: below ? Alignment.topCenter : Alignment.bottomCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: BusyMaxShadow.edgeShadowsFor(context, below: below),
            ),
            child: const SizedBox(width: double.infinity, height: 1),
          ),
        ),
      ),
    );
  }
}

class _HideIntent extends Intent {
  const _HideIntent();
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}
