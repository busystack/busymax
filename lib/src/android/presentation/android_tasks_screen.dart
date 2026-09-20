import 'dart:async';
import 'dart:convert';
import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_bootstrap.dart';
import '../../app/common/busymax_mutation_list.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../dav/ical/ical_task_alarm.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/tasks/domain/task_capabilities.dart';
import '../../features/tasks/presentation/task_details_draft.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../l10n/l10n.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/schedule_filters.dart';
import '../../schedule/schedule_item.dart';
import '../../schedule/task_list_mutation_intent.dart';
import '../android_notifications.dart';
import 'android_date_picker.dart';
import 'android_task_motion.dart';

final _androidTasksProvider = FutureProvider.autoDispose
    .family<
      List<TaskScheduleItem>,
      ({
        String query,
        String? accountId,
        String? listId,
        bool completed,
        bool noDate,
      })
    >((ref, key) {
      ref.watch(scheduleDataRevisionProvider);
      final lists =
          ref.watch(scheduleTaskListsProvider).valueOrNull ?? const [];
      final selected = lists
          .where(
            (list) => list.id == key.listId && list.accountId == key.accountId,
          )
          .firstOrNull;
      return ref
          .watch(scheduleRepositoryProvider)
          .listAllTasks(
            filters: ScheduleFilters(
              query: key.query,
              taskCompletion: key.completed
                  ? ScheduleTaskCompletion.all
                  : ScheduleTaskCompletion.open,
              showNoDateTasks: key.noDate,
              taskListFilterActive: selected != null,
              taskListKeys: selected == null
                  ? const {}
                  : {
                      ScheduleTaskListKey(
                        accountId: selected.accountId,
                        taskListId: selected.id,
                      ),
                    },
              includeCalendarEvents: false,
            ),
          );
    });

class AndroidTasksScreen extends ConsumerStatefulWidget {
  const AndroidTasksScreen({super.key});
  @override
  ConsumerState<AndroidTasksScreen> createState() => _AndroidTasksScreenState();
}

enum AndroidTaskEditorAction { created, updated, deleted, moved }

class AndroidTaskEditorResult {
  const AndroidTaskEditorResult({
    required this.action,
    required this.accountId,
    required this.taskListId,
    required this.taskId,
    this.previousTaskListId,
  });

  final AndroidTaskEditorAction action;
  final String accountId;
  final String taskListId;
  final String taskId;
  final String? previousTaskListId;
}

class _AndroidTasksScreenState extends ConsumerState<AndroidTasksScreen> {
  String _query = '';
  String? _accountId;
  String? _listId;
  bool _showCompleted = true;
  bool _showNoDate = true;
  var _mutationGeneration = 0;
  TaskListMutationIntent? _mutationIntent;

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(scheduleTaskListsProvider).valueOrNull ?? const [];
    final accounts =
        ref.watch(accountsStreamProvider).valueOrNull ??
        const <AccountEntity>[];
    final accountLabels = {
      for (final account in accounts) account.id: account.displayLabel,
    };
    final selectedAccount = accounts
        .where((account) => account.id == _accountId)
        .firstOrNull;
    if (_listId != null &&
        !lists.any(
          (list) => list.id == _listId && list.accountId == _accountId,
        )) {
      _accountId = null;
      _listId = null;
    }
    final tasks = ref.watch(
      _androidTasksProvider((
        query: _query,
        accountId: _accountId,
        listId: _listId,
        completed: _showCompleted,
        noDate: _showNoDate,
      )),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tasks),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'clear-completed') {
                unawaited(_clearCompleted());
                return;
              }
              setState(() {
                _mutationIntent = null;
                if (value == 'completed') _showCompleted = !_showCompleted;
                if (value == 'no-date') _showNoDate = !_showNoDate;
              });
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'completed',
                checked: _showCompleted,
                child: Text(context.l10n.completed),
              ),
              CheckedPopupMenuItem(
                value: 'no-date',
                checked: _showNoDate,
                child: Text(context.l10n.noDate),
              ),
              if (_listId != null &&
                  (selectedAccount?.provider == BusyProvider.google ||
                      selectedAccount?.provider == BusyProvider.nextcloud))
                PopupMenuItem(
                  value: 'clear-completed',
                  child: Text(context.l10n.clearCompleted),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                SearchBar(
                  hintText: context.l10n.windowsSearch,
                  leading: const Icon(Icons.search),
                  onChanged: (value) => setState(() {
                    _mutationIntent = null;
                    _query = value;
                  }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _listId == null
                      ? null
                      : _taskListKey(_accountId!, _listId!),
                  decoration: InputDecoration(
                    labelText: context.l10n.list,
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.l10n.allTasks),
                    ),
                    for (final list in lists)
                      DropdownMenuItem(
                        value: _taskListKey(list.accountId, list.id),
                        child: Text(
                          '${list.title} · ${accountLabels[list.accountId] ?? list.accountId}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _mutationIntent = null;
                    if (value == null) {
                      _accountId = null;
                      _listId = null;
                      return;
                    }
                    final separator = value.indexOf('\u0000');
                    _accountId = value.substring(0, separator);
                    _listId = value.substring(separator + 1);
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => BusyMaxMutationList<TaskScheduleItem>(
          items: items,
          mutation: _mutationIntent,
          identityOf: (task) =>
              '${task.accountId}\u0000${task.sourceId}\u0000${task.id}',
          mutationApplied: (task, mutation) =>
              mutation.completed == null ||
              task.completed == mutation.completed,
          onMutationConsumed: (mutation) {
            if (_mutationIntent?.generation == mutation.generation) {
              setState(() => _mutationIntent = null);
            }
          },
          emptyBuilder: (context) => Center(child: Text(context.l10n.noTasks)),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, task, index) {
            final displayedCompleted = _displayedCompletion(task);
            return ListTile(
              contentPadding: EdgeInsets.only(
                left: 8.0 + 16 * task.hierarchyDepth.clamp(0, 3),
                right: 12,
              ),
              leading: IconButton(
                iconSize: 30,
                tooltip: displayedCompleted
                    ? context.l10n.taskStatusCompleted
                    : context.l10n.taskStatusInProcess,
                onPressed: task.capabilities.canEdit
                    ? () => _toggle(task)
                    : null,
                icon: AndroidTaskCompletionIcon(
                  completed: displayedCompleted,
                  size: 30,
                  animate: _animatesCompletion(task),
                ),
              ),
              title: AndroidTaskTitle(
                title: task.title,
                completed: displayedCompleted,
                animate: _animatesCompletion(task),
              ),
              subtitle: Text(
                [
                  task.sourceName ?? task.provider.displayName,
                  if (task.start != null)
                    DateFormat.yMMMd().format(task.start!),
                  if (task.parentTitle != null) task.parentTitle!,
                ].join(' · '),
              ),
              trailing: task.hasSubtasks
                  ? const Icon(Icons.account_tree_outlined)
                  : null,
              onTap: () => _edit(task),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'android-tasks-add',
        onPressed: lists.isEmpty ? null : () => _create(lists),
        tooltip: context.l10n.newTask,
        child: const Icon(Icons.add_task),
      ),
    );
  }

  Future<void> _toggle(TaskScheduleItem task) async {
    setState(() {
      _mutationIntent = TaskListMutationIntent(
        presentation: TaskListMutationPresentation.completion,
        accountId: task.accountId,
        taskListId: task.sourceId,
        taskId: task.id,
        completed: !task.completed,
        generation: ++_mutationGeneration,
      );
    });
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(task.accountId))
          .patchTask(
            task.sourceId,
            task.id,
            TaskPatchInput({
              'status': task.completed ? 'needsAction' : 'completed',
            }),
          );
    } on Object catch (error) {
      if (mounted) {
        setState(() => _mutationIntent = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  bool _animatesCompletion(TaskScheduleItem task) {
    final intent = _mutationIntent;
    return intent?.presentation == TaskListMutationPresentation.completion &&
        intent?.taskKey ==
            '${task.accountId}\u0000${task.sourceId}\u0000${task.id}' &&
        intent?.completed != null;
  }

  bool _displayedCompletion(TaskScheduleItem task) {
    final intent = _mutationIntent;
    if (intent?.presentation == TaskListMutationPresentation.completion &&
        intent?.taskKey ==
            '${task.accountId}\u0000${task.sourceId}\u0000${task.id}' &&
        intent?.completed != null) {
      return intent!.completed!;
    }
    return task.completed;
  }

  Future<void> _clearCompleted() async {
    final accountId = _accountId;
    final listId = _listId;
    if (accountId == null || listId == null) return;
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(accountId))
          .clearCompleted(listId);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _create(List<TaskListEntity> lists) async {
    final current = lists
        .where((list) => list.id == _listId && list.accountId == _accountId)
        .firstOrNull;
    final selected =
        current ??
        await selectAndroidTaskList(
          context,
          lists,
          title: context.l10n.newTask,
          accountLabels: {
            for (final account
                in ref.read(accountsStreamProvider).valueOrNull ??
                    const <AccountEntity>[])
              account.id: account.displayLabel,
          },
        );
    if (selected == null || !mounted) return;
    final accounts =
        ref.read(accountsStreamProvider).valueOrNull ?? const <AccountEntity>[];
    final account = accounts
        .where((value) => value.id == selected.accountId)
        .firstOrNull;
    if (account == null) return;
    final result = await showAndroidTaskEditor(
      context,
      ref,
      creationList: selected,
      creationProvider: account.provider,
    );
    if (result != null && mounted) _consumeEditorResult(result);
  }

  Future<void> _edit(TaskScheduleItem task) async {
    final result = await showAndroidTaskEditor(context, ref, task: task);
    if (result != null && mounted) _consumeEditorResult(result);
  }

  void _consumeEditorResult(AndroidTaskEditorResult result) {
    final presentation = switch (result.action) {
      AndroidTaskEditorAction.created => TaskListMutationPresentation.insertion,
      AndroidTaskEditorAction.deleted ||
      AndroidTaskEditorAction.moved => TaskListMutationPresentation.removal,
      AndroidTaskEditorAction.updated =>
        TaskListMutationPresentation.completion,
    };
    setState(() {
      _mutationIntent = TaskListMutationIntent(
        presentation: presentation,
        accountId: result.accountId,
        taskListId: result.previousTaskListId ?? result.taskListId,
        taskId: result.taskId,
        generation: ++_mutationGeneration,
      );
    });
  }
}

Future<TaskListEntity?> selectAndroidTaskList(
  BuildContext context,
  List<TaskListEntity> lists, {
  required String title,
  Map<String, String> accountLabels = const {},
}) {
  if (lists.length == 1) return Future.value(lists.single);
  return showModalBottomSheet<TaskListEntity>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(title)),
          for (final list in lists)
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: Text(list.title),
              subtitle: Text(accountLabels[list.accountId] ?? list.accountId),
              onTap: () => Navigator.pop(sheetContext, list),
            ),
        ],
      ),
    ),
  );
}

Future<AndroidTaskEditorResult?> showAndroidTaskEditor(
  BuildContext context,
  WidgetRef ref, {
  TaskScheduleItem? task,
  TaskListEntity? creationList,
  BusyProvider? creationProvider,
  DateTime? initialDue,
}) async {
  TaskEntity? entity;
  TaskListEntity? selectedList = creationList;
  if (task != null) {
    entity = await ref
        .read(tasksRepositoryForAccountProvider(task.accountId))
        .watchTask(task.sourceId, task.id)
        .first;
    if (!context.mounted || entity == null) return null;
    selectedList =
        (await ref
                .read(taskListsRepositoryForAccountProvider(task.accountId))
                .listTaskLists())
            .where((list) => list.id == task.sourceId)
            .firstOrNull;
  }
  final account = await ref
      .read(accountsRepositoryProvider)
      .accountById(task?.accountId ?? creationList!.accountId);
  if (!context.mounted) return null;
  return Navigator.of(context).push<AndroidTaskEditorResult>(
    MaterialPageRoute<AndroidTaskEditorResult>(
      fullscreenDialog: true,
      builder: (_) => AndroidTaskEditor(
        accountId: task?.accountId ?? creationList!.accountId,
        provider: task?.provider ?? creationProvider!,
        task: entity,
        creationList: creationList,
        initialDue: initialDue,
        accountLabel: account?.displayLabel,
        listLabel: selectedList?.title,
      ),
    ),
  );
}

class AndroidTaskEditor extends ConsumerStatefulWidget {
  const AndroidTaskEditor({
    super.key,
    required this.accountId,
    required this.provider,
    this.task,
    this.creationList,
    this.initialDue,
    this.accountLabel,
    this.listLabel,
  });
  final String accountId;
  final BusyProvider provider;
  final TaskEntity? task;
  final TaskListEntity? creationList;
  final DateTime? initialDue;
  final String? accountLabel;
  final String? listLabel;
  @override
  ConsumerState<AndroidTaskEditor> createState() => _AndroidTaskEditorState();
}

class _AndroidTaskEditorState extends ConsumerState<AndroidTaskEditor> {
  late TaskDetailsDraft _draft = widget.task == null
      ? TaskDetailsDraft.forCreation(
          taskListId: widget.creationList!.id,
          provider: widget.provider,
          timeZone: ref.read(localTimeZoneProvider),
          due: widget.initialDue,
        )
      : TaskDetailsDraft.fromTask(
          widget.task!,
          ref.read(localTimeZoneProvider),
        );
  late final TextEditingController _title = TextEditingController(
    text: _draft.title,
  );
  late final TextEditingController _notes = TextEditingController(
    text: _draft.notes,
  );
  late final TextEditingController _location = TextEditingController(
    text: _draft.location,
  );
  late final TextEditingController _url = TextEditingController(
    text: _draft.taskUrl,
  );
  late final TextEditingController _categories = TextEditingController(
    text: _draft.categories.join(', '),
  );
  bool _saving = false;
  bool _allowPop = false;
  bool _recoveryLoaded = false;
  bool _recoveryWritesBlocked = false;
  Future<void> _recoveryIo = Future.value();
  Timer? _recoveryTimer;
  late final TaskDetailsDraft _initialDraft = _draft;
  late RecurrenceFrequency _recurrenceFrequency = _taskRecurrence().frequency;

  TaskCollectionCapabilities get _capabilities => switch (widget.provider) {
    BusyProvider.appleICloud || BusyProvider.nextcloud =>
      ref
              .read(
                davTaskCollectionCapabilitiesProvider((
                  accountId: widget.accountId,
                  taskListId: _draft.taskListId,
                )),
              )
              .valueOrNull ??
          noTaskCollectionCapabilities,
    BusyProvider.google ||
    BusyProvider.microsoft => adapterDefaultTaskCapabilities(widget.provider),
    BusyProvider.webCal => noTaskCollectionCapabilities,
  };

  bool get _canWrite => widget.task == null
      ? _capabilities.canCreateTasks
      : _capabilities.canUpdateTasks;

  bool get _hasPendingEdits => !_draft.hasSameValues(_initialDraft);

  String get _recoveryKey =>
      'busymax.android.task-draft.${widget.accountId}.'
      '${widget.task?.id ?? 'new-${_initialDraft.taskListId}'}';

  @override
  void initState() {
    super.initState();
    unawaited(_restoreRecovery());
    _recoveryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_persistRecovery()),
    );
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    if (_recoveryLoaded && _hasPendingEdits && !_allowPop) {
      unawaited(_persistRecovery());
    }
    _title.dispose();
    _notes.dispose();
    _location.dispose();
    _url.dispose();
    _categories.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.provider == BusyProvider.appleICloud ||
        widget.provider == BusyProvider.nextcloud) {
      ref.watch(
        davTaskCollectionCapabilitiesProvider((
          accountId: widget.accountId,
          taskListId: _draft.taskListId,
        )),
      );
    }
    final capabilities = _capabilities;
    final canWrite = _canWrite;
    return PopScope<void>(
      canPop: _allowPop || !_hasPendingEdits,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving || _allowPop) return;
        if (await _confirmDiscardChanges() && mounted) {
          await _clearRecovery(finalCleanup: true);
          if (!mounted) return;
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _saving ? null : _requestClose,
            icon: const Icon(Icons.close),
          ),
          title: Text(
            widget.task == null ? context.l10n.newTask : context.l10n.editTask,
          ),
          actions: [
            TextButton(
              onPressed: _saving || !canWrite ? null : _save,
              child: Text(context.l10n.save),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(widget.listLabel ?? _draft.taskListId),
                subtitle: Text(widget.accountLabel ?? widget.accountId),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              enabled: canWrite,
              autofocus: widget.task == null,
              decoration: InputDecoration(labelText: context.l10n.title),
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(title: v)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              enabled: canWrite,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(labelText: context.l10n.notes),
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(notes: v)),
            ),
            if (capabilities.supportsDueDate)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(context.l10n.dueDate),
                subtitle: Text(_draft.dueDate ?? context.l10n.noDate),
                trailing: _draft.dueDate == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: !canWrite
                            ? null
                            : () => setState(
                                () => _draft = _draft.copyWith(
                                  dueDate: null,
                                  microsoftDueTime: null,
                                ),
                              ),
                      ),
                enabled: canWrite,
                onTap: canWrite ? _pickDue : null,
              ),
            if (capabilities.supportsDueTime && _draft.dueDate != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(context.l10n.endTime),
                subtitle: Text(_draft.microsoftDueTime ?? context.l10n.allDay),
                enabled: canWrite,
                onTap: canWrite ? _pickDueTime : null,
              ),
            if (capabilities.supportsStartDateTime)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow_outlined),
                title: Text(context.l10n.startDate),
                subtitle: Text(
                  _draft.microsoftStartDate ?? context.l10n.noDate,
                ),
                trailing: _draft.microsoftStartDate == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: !canWrite
                            ? null
                            : () => setState(
                                () => _draft = _draft.copyWith(
                                  microsoftStartDate: null,
                                  microsoftStartTime: null,
                                ),
                              ),
                      ),
                enabled: canWrite,
                onTap: canWrite ? _pickStartDate : null,
              ),
            if (capabilities.supportsStartDateTime &&
                _draft.microsoftStartDate != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(context.l10n.startTime),
                subtitle: Text(
                  _draft.microsoftStartTime ?? context.l10n.allDay,
                ),
                enabled: canWrite,
                onTap: canWrite ? _pickStartTime : null,
              ),
            if (capabilities.supportsReminderDateTime &&
                !capabilities.supportsMultipleReminders)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.reminder),
                value: _draft.microsoftReminderEnabled,
                onChanged: !canWrite
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(
                          microsoftReminderEnabled: value,
                          microsoftReminderDate: value
                              ? (_draft.microsoftReminderDate ?? _today())
                              : null,
                          microsoftReminderTime: value
                              ? (_draft.microsoftReminderTime ?? '09:00')
                              : null,
                        ),
                      ),
              ),
            if (capabilities.supportsReminderDateTime &&
                !capabilities.supportsMultipleReminders &&
                _draft.microsoftReminderEnabled) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(context.l10n.reminderDate),
                subtitle: Text(
                  _draft.microsoftReminderDate ?? context.l10n.noDate,
                ),
                enabled: canWrite,
                onTap: canWrite ? _pickReminderDate : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm_outlined),
                title: Text(context.l10n.reminderTime),
                subtitle: Text(
                  _draft.microsoftReminderTime ?? context.l10n.noDate,
                ),
                enabled: canWrite,
                onTap: canWrite ? _pickReminderTime : null,
              ),
            ],
            if (capabilities.supportsImportance)
              DropdownButtonFormField<String>(
                initialValue: _draft.importance,
                decoration: InputDecoration(labelText: context.l10n.importance),
                items: [
                  DropdownMenuItem(
                    value: 'low',
                    child: Text(context.l10n.importanceLow),
                  ),
                  DropdownMenuItem(
                    value: 'normal',
                    child: Text(context.l10n.importanceNormal),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text(context.l10n.importanceHigh),
                  ),
                ],
                onChanged: !canWrite
                    ? null
                    : (v) => setState(
                        () => _draft = _draft.copyWith(importance: v),
                      ),
              ),
            if (capabilities.supportsIcalPriority)
              DropdownButtonFormField<int>(
                initialValue: _draft.icalPriority,
                decoration: InputDecoration(labelText: context.l10n.priority),
                items: [
                  for (var value = 0; value <= 9; value++)
                    DropdownMenuItem(
                      value: value,
                      child: Text(value == 0 ? '0 · —' : '$value'),
                    ),
                ],
                onChanged: !canWrite
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(icalPriority: value),
                      ),
              ),
            if (capabilities.supportsTaskStatus)
              DropdownButtonFormField<String?>(
                initialValue: _draft.taskStatus,
                decoration: InputDecoration(labelText: context.l10n.taskStatus),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(context.l10n.repeatNone),
                  ),
                  DropdownMenuItem(
                    value: 'NEEDS-ACTION',
                    child: Text(context.l10n.taskStatusNeedsAction),
                  ),
                  DropdownMenuItem(
                    value: 'IN-PROCESS',
                    child: Text(context.l10n.taskStatusInProcess),
                  ),
                  DropdownMenuItem(
                    value: 'COMPLETED',
                    child: Text(context.l10n.taskStatusCompleted),
                  ),
                  DropdownMenuItem(
                    value: 'CANCELLED',
                    child: Text(context.l10n.taskStatusCancelled),
                  ),
                ],
                onChanged: !canWrite ? null : (value) => _setTaskStatus(value),
              ),
            if (capabilities.supportsRecurrence) ...[
              const SizedBox(height: 12),
              if (capabilities.supportsAdvancedRecurrence)
                ListTile(
                  key: const ValueKey('android-task-advanced-recurrence'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.repeat),
                  title: Text(context.l10n.repeat),
                  subtitle: Text(
                    _taskRecurrence().isSupported
                        ? _recurrenceLabel(context, _taskRecurrence().frequency)
                        : context.l10n.unsupportedRecurrencePreserved,
                  ),
                  trailing: Icon(
                    _taskRecurrence().isSupported
                        ? Icons.chevron_right
                        : Icons.lock_outline,
                  ),
                  enabled: canWrite && _taskRecurrence().isSupported,
                  onTap: canWrite && _taskRecurrence().isSupported
                      ? _editAdvancedRecurrence
                      : null,
                )
              else
                DropdownButtonFormField<RecurrenceFrequency>(
                  initialValue: _recurrenceFrequency,
                  decoration: InputDecoration(labelText: context.l10n.repeat),
                  items: [
                    for (final frequency in RecurrenceFrequency.values)
                      DropdownMenuItem(
                        value: frequency,
                        child: Text(_recurrenceLabel(context, frequency)),
                      ),
                  ],
                  onChanged: canWrite ? _setRecurrence : null,
                ),
            ],
            if (capabilities.supportsCategories) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _categories,
                enabled: canWrite,
                decoration: InputDecoration(labelText: context.l10n.categories),
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(
                    categories: v
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                  ),
                ),
              ),
            ],
            if (capabilities.supportsLocation) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _location,
                enabled: canWrite,
                decoration: InputDecoration(labelText: context.l10n.location),
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(location: v)),
              ),
            ],
            if (capabilities.supportsUrl) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                enabled: canWrite,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: context.l10n.taskUrl),
                onChanged: (value) =>
                    setState(() => _draft = _draft.copyWith(taskUrl: value)),
              ),
            ],
            if (capabilities.supportsClassification)
              DropdownButtonFormField<String>(
                initialValue: _draft.classification,
                decoration: InputDecoration(
                  labelText: context.l10n.classification,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'PUBLIC',
                    child: Text(context.l10n.classificationPublic),
                  ),
                  DropdownMenuItem(
                    value: 'CONFIDENTIAL',
                    child: Text(context.l10n.classificationConfidential),
                  ),
                  DropdownMenuItem(
                    value: 'PRIVATE',
                    child: Text(context.l10n.classificationPrivate),
                  ),
                ],
                onChanged: !canWrite || !capabilities.canUpdateClassification
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(classification: value),
                      ),
              ),
            if (capabilities.supportsPinning)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.pinTask),
                value: _draft.pinned,
                onChanged: !canWrite
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(pinned: value),
                      ),
              ),
            if (capabilities.supportsSubtaskVisibility) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.hideSubtasks),
                value: _draft.hideSubtasks,
                onChanged: !canWrite
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(hideSubtasks: value),
                      ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.hideClosedSubtasks),
                value: _draft.hideCompletedSubtasks,
                onChanged: !canWrite
                    ? null
                    : (value) => setState(
                        () => _draft = _draft.copyWith(
                          hideCompletedSubtasks: value,
                        ),
                      ),
              ),
            ],
            if (capabilities.supportsMultipleReminders) ...[
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_outlined),
                title: Text(context.l10n.reminderGroup),
                trailing: IconButton(
                  tooltip: context.l10n.addReminder,
                  onPressed: canWrite ? _addAlarm : null,
                  icon: const Icon(Icons.add),
                ),
              ),
              for (var index = 0; index < _draft.alarms.length; index++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_alarmLabel(_draft.alarms[index])),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: !canWrite
                        ? null
                        : () => setState(
                            () => _draft = _draft.copyWith(
                              alarms: [
                                for (var i = 0; i < _draft.alarms.length; i++)
                                  if (i != index) _draft.alarms[i],
                              ],
                            ),
                          ),
                  ),
                ),
            ],
            if (widget.task != null && capabilities.supportsDuplicate)
              OutlinedButton.icon(
                onPressed: _saving || !capabilities.canCreateTasks
                    ? null
                    : _duplicate,
                icon: const Icon(Icons.copy_outlined),
                label: Text(context.l10n.duplicateTask),
              ),
            if (widget.task != null && capabilities.supportsCrossListMove)
              OutlinedButton.icon(
                onPressed: _saving || !capabilities.canUpdateTasks
                    ? null
                    : _moveToList,
                icon: const Icon(Icons.drive_file_move_outline),
                label: Text(context.l10n.list),
              ),
            if (widget.task != null && capabilities.supportsNativeExport)
              OutlinedButton.icon(
                onPressed: _saving ? null : _export,
                icon: const Icon(Icons.file_download_outlined),
                label: Text(context.l10n.export),
              ),
            if (capabilities.supportsPercentComplete)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.completionPercent(_draft.percentComplete)),
                  Slider(
                    value: _draft.percentComplete.toDouble(),
                    max: 100,
                    divisions: 20,
                    onChanged: !canWrite
                        ? null
                        : (v) => _setTaskProgress(v.round()),
                  ),
                ],
              ),
            if (capabilities.supportsCompletedDateTime &&
                (_draft.taskStatus == 'COMPLETED' ||
                    _draft.percentComplete == 100 ||
                    _draft.completedDate != null)) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: Text(context.l10n.completionDate),
                subtitle: Text(_draft.completedDate ?? context.l10n.noDate),
                trailing: _draft.completedDate == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: canWrite ? _clearCompletionDate : null,
                      ),
                enabled: canWrite,
                onTap: canWrite ? _pickCompletionDate : null,
              ),
              if (_draft.completedDate != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(context.l10n.completed),
                  subtitle: Text(_draft.completedTime ?? context.l10n.noDate),
                  enabled: canWrite,
                  onTap: canWrite ? _pickCompletionTime : null,
                ),
            ],
            if (widget.task != null && capabilities.supportsTaskHierarchy) ...[
              const Divider(height: 32),
              StreamBuilder<TaskHierarchySnapshot>(
                stream: ref
                    .read(tasksRepositoryForAccountProvider(widget.accountId))
                    .watchTaskHierarchy(_draft.taskListId, widget.task!.id),
                builder: (context, snapshot) => _taskHierarchySection(
                  snapshot.data ??
                      const TaskHierarchySnapshot(parent: null, subtasks: []),
                  capabilities,
                ),
              ),
            ],
            if (widget.task != null &&
                capabilities.supportsTaskReparenting &&
                (widget.task!.parent != null || widget.task!.parentUid != null))
              OutlinedButton.icon(
                onPressed: _saving || !capabilities.canUpdateTasks
                    ? null
                    : _moveToTop,
                icon: const Icon(Icons.vertical_align_top),
                label: Text(context.l10n.moveToTop),
              ),
            if (widget.task != null && capabilities.canDeleteTasks) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.deleteTask),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDue() async {
    final current = DateTime.tryParse(_draft.dueDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value != null) {
      setState(() => _draft = _draft.copyWith(dueDate: _date(value)));
    }
  }

  Widget _taskHierarchySection(
    TaskHierarchySnapshot hierarchy,
    TaskCollectionCapabilities capabilities,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.subtasks,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (hierarchy.parent case final parent?)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_tree_outlined),
          title: Text(parent.title),
          subtitle: Text(context.l10n.parent),
          onTap: () => _openHierarchyTask(parent),
        ),
      for (final subtask in hierarchy.subtasks)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconButton(
            onPressed: capabilities.canUpdateTasks
                ? () => _toggleSubtask(subtask)
                : null,
            icon: AndroidTaskCompletionIcon(completed: subtask.completed),
          ),
          title: Text(subtask.title),
          trailing: subtask.hasChildren
              ? const Icon(Icons.account_tree_outlined)
              : null,
          onTap: subtask.task == null
              ? null
              : () => _openHierarchyTask(subtask.task!),
        ),
      OutlinedButton.icon(
        onPressed: capabilities.canCreateTasks ? _createSubtask : null,
        icon: const Icon(Icons.add_task),
        label: Text(context.l10n.createSubtask),
      ),
    ],
  );

  Future<void> _openHierarchyTask(TaskEntity task) async {
    await Navigator.of(context).push<AndroidTaskEditorResult>(
      MaterialPageRoute<AndroidTaskEditorResult>(
        fullscreenDialog: true,
        builder: (_) => AndroidTaskEditor(
          accountId: widget.accountId,
          provider: widget.provider,
          task: task,
          accountLabel: widget.accountLabel,
          listLabel: widget.listLabel,
        ),
      ),
    );
  }

  Future<void> _toggleSubtask(TaskSubtaskEntity subtask) async {
    try {
      final repository = ref.read(
        tasksRepositoryForAccountProvider(widget.accountId),
      );
      if (subtask.kind == TaskSubtaskKind.checklistItem) {
        await repository.patchChecklistSubtask(
          taskListId: _draft.taskListId,
          parentTaskId: widget.task!.id,
          checklistItemId: subtask.id,
          completed: !subtask.completed,
        );
      } else {
        await repository.patchTask(
          _draft.taskListId,
          subtask.id,
          TaskPatchInput({
            'status': subtask.completed ? 'needsAction' : 'completed',
          }),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _createSubtask() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.createSubtask),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: context.l10n.title),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(dialogContext, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
            child: Text(context.l10n.create),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null) return;
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .createSubtask(
            taskListId: _draft.taskListId,
            parentTaskId: widget.task!.id,
            title: title,
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _pickDueTime() async {
    final parts = (_draft.microsoftDueTime ?? '09:00').split(':');
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (value != null) {
      setState(
        () => _draft = _draft.copyWith(
          microsoftDueTime:
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  Future<void> _pickStartDate() async {
    final current =
        DateTime.tryParse(_draft.microsoftStartDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value != null) {
      setState(
        () => _draft = _draft.copyWith(microsoftStartDate: _date(value)),
      );
    }
  }

  Future<void> _pickStartTime() async {
    final value = await _pickTime(_draft.microsoftStartTime);
    if (value != null) {
      setState(() => _draft = _draft.copyWith(microsoftStartTime: value));
    }
  }

  Future<void> _pickReminderDate() async {
    final current =
        DateTime.tryParse(_draft.microsoftReminderDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value != null) {
      setState(
        () => _draft = _draft.copyWith(microsoftReminderDate: _date(value)),
      );
    }
  }

  Future<void> _pickReminderTime() async {
    final value = await _pickTime(_draft.microsoftReminderTime);
    if (value != null) {
      setState(() => _draft = _draft.copyWith(microsoftReminderTime: value));
    }
  }

  Future<String?> _pickTime(String? current) async {
    final parts = (current ?? '09:00').split(':');
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    return value == null
        ? null
        : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  void _setTaskStatus(String? status) {
    final now = DateTime.now();
    setState(() {
      _draft = switch (status) {
        'COMPLETED' => _draft.copyWith(
          taskStatus: status,
          percentComplete: 100,
          completedDate: _draft.completedDate ?? _date(now),
          completedTime: _draft.completedTime ?? _clock(now),
        ),
        'IN-PROCESS' => _draft.copyWith(
          taskStatus: status,
          percentComplete: _draft.percentComplete == 0
              ? 1
              : _draft.percentComplete == 100
              ? 99
              : _draft.percentComplete,
          completedDate: null,
          completedTime: null,
        ),
        'NEEDS-ACTION' || null => _draft.copyWith(
          taskStatus: status,
          percentComplete: _draft.percentComplete == 100
              ? 99
              : _draft.percentComplete,
          completedDate: null,
          completedTime: null,
        ),
        'CANCELLED' => _draft.copyWith(taskStatus: status),
        _ => _draft,
      };
    });
  }

  void _setTaskProgress(int percent) {
    final now = DateTime.now();
    setState(() {
      _draft = switch (percent.clamp(0, 100)) {
        100 => _draft.copyWith(
          percentComplete: 100,
          taskStatus: 'COMPLETED',
          completedDate: _draft.completedDate ?? _date(now),
          completedTime: _draft.completedTime ?? _clock(now),
        ),
        0 => _draft.copyWith(
          percentComplete: 0,
          taskStatus: 'NEEDS-ACTION',
          completedDate: null,
          completedTime: null,
        ),
        final value => _draft.copyWith(
          percentComplete: value,
          taskStatus: 'IN-PROCESS',
          completedDate: null,
          completedTime: null,
        ),
      };
    });
  }

  Future<void> _pickCompletionDate() async {
    final current =
        DateTime.tryParse(_draft.completedDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value == null) return;
    setState(
      () => _draft = _draft.copyWith(
        completedDate: _date(value),
        completedTime: _draft.completedTime ?? _clock(DateTime.now()),
        percentComplete: 100,
        taskStatus: 'COMPLETED',
      ),
    );
  }

  Future<void> _pickCompletionTime() async {
    final value = await _pickTime(_draft.completedTime);
    if (value != null) {
      setState(() => _draft = _draft.copyWith(completedTime: value));
    }
  }

  void _clearCompletionDate() => setState(
    () => _draft = _draft.copyWith(
      completedDate: null,
      completedTime: null,
      percentComplete: _draft.percentComplete == 100
          ? 99
          : _draft.percentComplete,
      taskStatus: _draft.percentComplete == 100
          ? 'IN-PROCESS'
          : _draft.taskStatus,
    ),
  );

  Future<void> _addAlarm() async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(context.l10n.absoluteReminder),
              onTap: () => Navigator.pop(sheetContext, 'absolute'),
            ),
            if (_draft.microsoftStartDate != null)
              ListTile(
                leading: const Icon(Icons.play_arrow_outlined),
                title: Text(context.l10n.beforeTaskStarts),
                onTap: () => Navigator.pop(sheetContext, 'start'),
              ),
            if (_draft.dueDate != null)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(context.l10n.beforeTaskDue),
                onTap: () => Navigator.pop(sheetContext, 'due'),
              ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    IcalTaskAlarm? alarm;
    if (mode == 'absolute') {
      final date = await showBusyMaxDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1970),
        lastDate: DateTime(2200),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time == null) return;
      alarm = IcalTaskAlarm.displayAbsolute(
        DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ).toUtc(),
      );
    } else {
      final allDay =
          _draft.microsoftDueTime == null && _draft.microsoftStartTime == null;
      final selection =
          await showDialog<({int amount, String unit, TimeOfDay? time})>(
            context: context,
            builder: (_) => _AndroidRelativeAlarmDialog(allDay: allDay),
          );
      if (selection == null) return;
      final duration = allDay
          ? IcalAllDayAlarmOffset(
              amount: selection.amount,
              unit: selection.unit == 'weeks'
                  ? IcalAllDayAlarmUnit.weeks
                  : IcalAllDayAlarmUnit.days,
              hour: selection.time?.hour ?? 9,
              minute: selection.time?.minute ?? 0,
            ).toDuration()
          : -switch (selection.unit) {
              'weeks' => Duration(days: selection.amount * 7),
              'days' => Duration(days: selection.amount),
              'hours' => Duration(hours: selection.amount),
              _ => Duration(minutes: selection.amount),
            };
      alarm = IcalTaskAlarm.displayRelative(
        duration,
        relatedToDue: mode == 'due',
      );
    }
    setState(
      () => _draft = _draft.copyWith(alarms: [..._draft.alarms, alarm!]),
    );
  }

  String _alarmLabel(IcalTaskAlarm alarm) {
    final absolute = alarm.absoluteUtc;
    if (absolute != null) {
      return DateFormat.yMMMd().add_jm().format(absolute.toLocal());
    }
    return alarm.triggerRaw;
  }

  Future<void> _save() async {
    setState(_syncDraftFromControllers);
    if (!_draftIsValid) return;
    setState(() => _saving = true);
    try {
      final taskId = await _persistTaskDraft();
      if (mounted) {
        await _clearRecovery(finalCleanup: true);
        if (!mounted) return;
        setState(() => _allowPop = true);
        Navigator.pop(
          context,
          AndroidTaskEditorResult(
            action: widget.task == null
                ? AndroidTaskEditorAction.created
                : AndroidTaskEditorAction.updated,
            accountId: widget.accountId,
            taskListId: _draft.taskListId,
            taskId: taskId,
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _syncDraftFromControllers() {
    _draft = _draft.copyWith(
      title: _title.text.trim(),
      notes: _notes.text,
      location: _location.text,
      taskUrl: _url.text.trim(),
      categories: _categories.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }

  bool get _draftIsValid =>
      _draft.title.trim().isNotEmpty &&
      _draft.hasValidTaskUrlFor(_capabilities) &&
      _draft.scheduleIssueFor(_capabilities) == TaskScheduleIssue.none;

  Future<String> _persistTaskDraft() async {
    if (_draft.microsoftReminderEnabled || _draft.alarms.isNotEmpty) {
      await ref
          .read(androidNotificationServiceProvider)
          .requestNotificationPermission();
    }
    final repository = ref.read(
      tasksRepositoryForAccountProvider(widget.accountId),
    );
    if (widget.task == null) {
      return repository.createTask(
        _draft.taskListId,
        _draft.toCreateInput(
          _capabilities,
          localTimeZone: ref.read(localTimeZoneProvider),
        ),
      );
    }
    await repository.patchTask(
      _draft.taskListId,
      _draft.taskId,
      TaskPatchInput(
        _draft.toPatch(
          widget.task!,
          _capabilities,
          localTimeZone: ref.read(localTimeZoneProvider),
        ),
      ),
    );
    return widget.task!.id;
  }

  RecurrenceRule _taskRecurrence() {
    final creation = _draft.creationRecurrence;
    if (creation != null) return creation.rule;
    final raw = _draft.recurrenceJson;
    if (raw == null) return const RecurrenceRule.none();
    try {
      return EventRecurrenceCodec.decode(
        widget.provider,
        jsonDecode(raw),
        baseDate: DateTime.tryParse(_draft.dueDate ?? ''),
      );
    } on Object {
      return const RecurrenceRule.none();
    }
  }

  void _setRecurrence(RecurrenceFrequency? frequency) {
    if (frequency == null) return;
    final base = DateTime.tryParse(_draft.dueDate ?? '') ?? DateTime.now();
    final rule = _simpleTaskRecurrenceRule(frequency, base);
    _applyRecurrence(rule, base);
  }

  Future<void> _editAdvancedRecurrence() async {
    final initial = _taskRecurrence();
    if (!initial.isSupported) return;
    final base =
        DateTime.tryParse(_draft.microsoftStartDate ?? _draft.dueDate ?? '') ??
        DateTime.now();
    final result = await showDialog<RecurrenceRule>(
      context: context,
      builder: (_) => _AndroidRecurrenceDialog(
        initial: initial,
        baseDate: base,
        provider: widget.provider,
        allDay:
            _draft.microsoftDueTime == null &&
            _draft.microsoftStartTime == null,
        timeZone: _draft.microsoftStartTimeZone,
      ),
    );
    if (result != null && mounted) _applyRecurrence(result, base);
  }

  void _applyRecurrence(RecurrenceRule rule, DateTime base) {
    setState(() {
      _recurrenceFrequency = rule.frequency;
      if (widget.task == null) {
        _draft = _draft.copyWith(
          creationRecurrence: (provider: widget.provider, rule: rule),
        );
      } else {
        final encoded = rule.repeats
            ? EventRecurrenceCodec.encode(
                widget.provider,
                rule,
                baseDate: base,
                allDay: _draft.microsoftDueTime == null,
                timeZone: _draft.microsoftDueTimeZone,
                original: _draft.recurrenceJson == null
                    ? null
                    : jsonDecode(_draft.recurrenceJson!),
              )
            : null;
        _draft = _draft.copyWith(
          recurrenceJson: encoded == null ? null : jsonEncode(encoded),
        );
      }
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteTask),
        content: Text(context.l10n.deleteTaskConfirmation(widget.task!.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .deleteTask(widget.task!.taskListId, widget.task!.id);
      if (mounted) {
        await _clearRecovery(finalCleanup: true);
        if (!mounted) return;
        setState(() => _allowPop = true);
        Navigator.pop(
          context,
          AndroidTaskEditorResult(
            action: AndroidTaskEditorAction.deleted,
            accountId: widget.accountId,
            taskListId: widget.task!.taskListId,
            taskId: widget.task!.id,
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _duplicate() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .duplicateTask(_draft.taskListId, widget.task!.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.duplicateTask)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _moveToList() async {
    late final List<TaskListEntity> lists;
    try {
      lists =
          (await ref
                  .read(taskListsRepositoryForAccountProvider(widget.accountId))
                  .listTaskLists())
              .where((list) => list.id != _draft.taskListId)
              .toList();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
      return;
    }
    if (!mounted || lists.isEmpty) return;
    final destination = await selectAndroidTaskList(
      context,
      lists,
      title: context.l10n.list,
      accountLabels: {
        widget.accountId: widget.accountLabel ?? widget.accountId,
      },
    );
    if (destination == null || !mounted) return;
    setState(_syncDraftFromControllers);
    var saveEdits = false;
    if (_hasPendingEdits) {
      final decision = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.discardChanges),
          content: Text(context.l10n.discardChangesConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.discardChangesAction),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      );
      if (decision == null || !mounted) return;
      saveEdits = decision;
      if (saveEdits && !_draftIsValid) return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(
        tasksRepositoryForAccountProvider(widget.accountId),
      );
      if (saveEdits) await _persistTaskDraft();
      await repository.moveTask(
        TaskMoveInput(
          sourceTaskListId: _draft.taskListId,
          destinationTaskListId: destination.id,
          taskId: widget.task!.id,
        ),
      );
      await _clearRecovery(finalCleanup: true);
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.pop(
        context,
        AndroidTaskEditorResult(
          action: AndroidTaskEditorAction.moved,
          accountId: widget.accountId,
          taskListId: destination.id,
          taskId: widget.task!.id,
          previousTaskListId: _draft.taskListId,
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _moveToTop() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .moveTask(
            TaskMoveInput(
              sourceTaskListId: _draft.taskListId,
              taskId: widget.task!.id,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.moveToTop)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export() async {
    try {
      final raw = await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .nativeTaskExport(_draft.taskListId, widget.task!.id);
      if (raw == null) return;
      await BusyMaxAndroidPlatform.instance.createDocument(
        suggestedName: 'task.ics',
        mimeType: 'text/calendar',
        bytes: Uint8List.fromList(utf8.encode(raw)),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed('$error'))),
        );
      }
    }
  }

  Future<void> _requestClose() async {
    if (!_hasPendingEdits || await _confirmDiscardChanges()) {
      if (!mounted) return;
      await _clearRecovery(finalCleanup: true);
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<bool> _confirmDiscardChanges() async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.discardChanges),
          content: Text(context.l10n.discardChangesConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.discardChangesAction),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _restoreRecovery() async {
    try {
      final raw = await ref.read(secureStorageProvider).read(key: _recoveryKey);
      if (raw == null) return;
      final value = jsonDecode(raw);
      if (value is! Map) return;
      final map = value.cast<String, Object?>();
      final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
      if (savedAt == null ||
          DateTime.now().difference(savedAt).abs() > const Duration(days: 14) ||
          map['v'] != 2 ||
          map['baseTitle'] != _initialDraft.title ||
          map['accountId'] != widget.accountId ||
          map['taskListId'] != _initialDraft.taskListId) {
        await _clearRecovery();
        return;
      }
      final alarms = <IcalTaskAlarm>[];
      for (final rawAlarm in map['alarms'] as List? ?? const []) {
        if (rawAlarm is Map) {
          alarms.add(IcalTaskAlarm.fromJson(rawAlarm.cast<String, Object?>()));
        }
      }
      var recovered = _draft.copyWith(
        title: map['title']?.toString() ?? _draft.title,
        notes: map['notes']?.toString() ?? _draft.notes,
        dueDate: map['dueDate'],
        microsoftDueTime: map['dueTime'],
        microsoftDueTimeZone: map['dueTimeZone']?.toString(),
        microsoftStartDate: map['startDate'],
        microsoftStartTime: map['startTime'],
        microsoftStartTimeZone: map['startTimeZone']?.toString(),
        microsoftReminderEnabled:
            map['reminderEnabled'] as bool? ?? _draft.microsoftReminderEnabled,
        microsoftReminderDate: map['reminderDate'],
        microsoftReminderTime: map['reminderTime'],
        microsoftReminderTimeZone: map['reminderTimeZone']?.toString(),
        recurrenceJson: map['recurrenceJson'],
        importance: map['importance']?.toString(),
        categories: (map['categories'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        icalPriority: map['icalPriority'] as int?,
        percentComplete: map['percentComplete'] as int?,
        taskStatus: map['taskStatus'],
        completedDate: map['completedDate'],
        completedTime: map['completedTime'],
        location: map['location']?.toString(),
        taskUrl: map['taskUrl']?.toString(),
        classification: map['classification']?.toString(),
        pinned: map['pinned'] as bool?,
        hideSubtasks: map['hideSubtasks'] as bool?,
        hideCompletedSubtasks: map['hideCompletedSubtasks'] as bool?,
        alarms: alarms,
      );
      RecurrenceRule? creationRule;
      final rawCreationRecurrence = map['creationRecurrence'];
      if (widget.task == null && rawCreationRecurrence is Map) {
        final raw = rawCreationRecurrence;
        final creation = raw.cast<String, Object?>();
        final provider = BusyProvider.values
            .where((value) => value.name == creation['provider'])
            .firstOrNull;
        final base =
            DateTime.tryParse(recovered.dueDate ?? '') ?? DateTime.now();
        creationRule = RecurrenceRule.fromJson(
          creation['rule']?.toString(),
          baseDate: base,
        );
        if (provider != widget.provider || !creationRule.isSupported) {
          await _clearRecovery();
          return;
        }
        recovered = recovered.copyWith(
          creationRecurrence: (provider: provider!, rule: creationRule),
        );
      }
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final recover = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.discardChanges),
          content: Text(context.l10n.discardChangesConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.discardChangesAction),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.nextcloudRestore),
            ),
          ],
        ),
      );
      if (recover != true) {
        await _clearRecovery();
        return;
      }
      if (!mounted) return;
      setState(() {
        _draft = recovered;
        _recurrenceFrequency =
            creationRule?.frequency ?? _taskRecurrence().frequency;
        _title.text = recovered.title;
        _notes.text = recovered.notes;
        _location.text = recovered.location;
        _url.text = recovered.taskUrl;
        _categories.text = recovered.categories.join(', ');
      });
    } on Object {
      // A malformed/locked recovery entry must never block the editor.
    } finally {
      _recoveryLoaded = true;
    }
  }

  Future<void> _persistRecovery() async {
    if (!_recoveryLoaded ||
        !_hasPendingEdits ||
        _allowPop ||
        _recoveryWritesBlocked) {
      return;
    }
    final creationRecurrence = _draft.creationRecurrence;
    final payload = jsonEncode({
      'v': 2,
      'savedAt': DateTime.now().toIso8601String(),
      'baseTitle': _initialDraft.title,
      'accountId': widget.accountId,
      'taskListId': _draft.taskListId,
      'title': _draft.title,
      'notes': _draft.notes,
      'dueDate': _draft.dueDate,
      'dueTime': _draft.microsoftDueTime,
      'dueTimeZone': _draft.microsoftDueTimeZone,
      'startDate': _draft.microsoftStartDate,
      'startTime': _draft.microsoftStartTime,
      'startTimeZone': _draft.microsoftStartTimeZone,
      'reminderEnabled': _draft.microsoftReminderEnabled,
      'reminderDate': _draft.microsoftReminderDate,
      'reminderTime': _draft.microsoftReminderTime,
      'reminderTimeZone': _draft.microsoftReminderTimeZone,
      'recurrenceJson': _draft.recurrenceJson,
      if (creationRecurrence != null)
        'creationRecurrence': {
          'provider': creationRecurrence.provider.name,
          'rule': creationRecurrence.rule.toJsonString(),
        },
      'importance': _draft.importance,
      'categories': _draft.categories,
      'icalPriority': _draft.icalPriority,
      'percentComplete': _draft.percentComplete,
      'taskStatus': _draft.taskStatus,
      'completedDate': _draft.completedDate,
      'completedTime': _draft.completedTime,
      'location': _draft.location,
      'taskUrl': _draft.taskUrl,
      'classification': _draft.classification,
      'pinned': _draft.pinned,
      'hideSubtasks': _draft.hideSubtasks,
      'hideCompletedSubtasks': _draft.hideCompletedSubtasks,
      'alarms': [for (final alarm in _draft.alarms) alarm.toJson()],
    });
    await _enqueueRecovery(() async {
      if (_recoveryWritesBlocked) return;
      await ref
          .read(secureStorageProvider)
          .write(key: _recoveryKey, value: payload);
    });
  }

  Future<void> _clearRecovery({bool finalCleanup = false}) {
    if (finalCleanup) {
      _recoveryWritesBlocked = true;
      _recoveryTimer?.cancel();
    }
    return _enqueueRecovery(
      () => ref.read(secureStorageProvider).delete(key: _recoveryKey),
    );
  }

  Future<void> _enqueueRecovery(Future<void> Function() operation) {
    final result = _recoveryIo.then((_) => operation());
    _recoveryIo = result.catchError((_) {});
    return result.catchError((_) {});
  }
}

class _AndroidRelativeAlarmDialog extends StatefulWidget {
  const _AndroidRelativeAlarmDialog({required this.allDay});

  final bool allDay;

  @override
  State<_AndroidRelativeAlarmDialog> createState() =>
      _AndroidRelativeAlarmDialogState();
}

class _AndroidRelativeAlarmDialogState
    extends State<_AndroidRelativeAlarmDialog> {
  final _amount = TextEditingController(text: '10');
  late String _unit = widget.allDay ? 'days' : 'minutes';
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = widget.allDay
        ? const ['days', 'weeks']
        : const ['minutes', 'hours', 'days', 'weeks'];
    return AlertDialog(
      title: Text(context.l10n.addReminder),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: context.l10n.reminderAmount),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: InputDecoration(labelText: context.l10n.reminderUnit),
            items: [
              for (final unit in units)
                DropdownMenuItem(
                  value: unit,
                  child: Text(switch (unit) {
                    'weeks' => context.l10n.reminderUnitWeeks,
                    'days' => context.l10n.reminderUnitDays,
                    'hours' => context.l10n.reminderUnitHours,
                    _ => context.l10n.reminderUnitMinutes,
                  }),
                ),
            ],
            onChanged: (value) => setState(() => _unit = value ?? _unit),
          ),
          if (widget.allDay)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(context.l10n.reminderTimeOfDay),
              subtitle: Text(_time.format(context)),
              onTap: () async {
                final value = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (value != null) setState(() => _time = value);
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: switch (int.tryParse(_amount.text)) {
            final value? when value >= 0 && value <= 3600 =>
              () => Navigator.pop(context, (
                amount: value,
                unit: _unit,
                time: widget.allDay ? _time : null,
              )),
            _ => null,
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

enum _AndroidRecurrenceEnd { never, until, count }

class _AndroidRecurrenceDialog extends StatefulWidget {
  const _AndroidRecurrenceDialog({
    required this.initial,
    required this.baseDate,
    required this.provider,
    required this.allDay,
    required this.timeZone,
  });

  final RecurrenceRule initial;
  final DateTime baseDate;
  final BusyProvider provider;
  final bool allDay;
  final String? timeZone;

  @override
  State<_AndroidRecurrenceDialog> createState() =>
      _AndroidRecurrenceDialogState();
}

class _AndroidRecurrenceDialogState extends State<_AndroidRecurrenceDialog> {
  late RecurrenceRule _value = widget.initial;
  late _AndroidRecurrenceEnd _end = _value.count != null
      ? _AndroidRecurrenceEnd.count
      : _value.untilRaw != null
      ? _AndroidRecurrenceEnd.until
      : _AndroidRecurrenceEnd.never;
  late final _interval = TextEditingController(text: '${_value.interval}');
  late final _count = TextEditingController(text: '${_value.count ?? 10}');
  late DateTime _until =
      DateTime.tryParse(_value.untilDate ?? '') ??
      DateTime(
        widget.baseDate.year,
        widget.baseDate.month + 1,
        widget.baseDate.day,
      );

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.repeat),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: _value.frequency,
              decoration: InputDecoration(labelText: context.l10n.repeat),
              items: [
                for (final frequency in RecurrenceFrequency.values)
                  DropdownMenuItem(
                    value: frequency,
                    child: Text(_recurrenceLabel(context, frequency)),
                  ),
              ],
              onChanged: (frequency) {
                if (frequency == null) return;
                setState(() {
                  final replacement = _simpleTaskRecurrenceRule(
                    frequency,
                    widget.baseDate,
                  );
                  _value = replacement.copyWith(
                    interval: int.tryParse(_interval.text) ?? 1,
                    count: _value.count,
                    untilRaw: _value.untilRaw,
                  );
                });
              },
            ),
            if (_value.repeats) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _interval,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: context.l10n.repeatEvery,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_value.frequency == RecurrenceFrequency.weekly) ...[
              const SizedBox(height: 16),
              Text(context.l10n.repeatOn),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (var index = 0; index < rfcWeekdays.length; index++)
                    FilterChip(
                      label: Text(
                        DateFormat.E().format(DateTime(2026, 1, 5 + index)),
                      ),
                      selected: _value.byDay.contains(rfcWeekdays[index]),
                      onSelected: (selected) => setState(() {
                        final values = [..._value.byDay];
                        if (selected) {
                          values.add(rfcWeekdays[index]);
                        } else {
                          values.remove(rfcWeekdays[index]);
                        }
                        _value = _value.copyWith(byDay: values);
                      }),
                    ),
                ],
              ),
            ],
            if (_value.frequency == RecurrenceFrequency.monthly ||
                _value.frequency == RecurrenceFrequency.yearly) ...[
              const SizedBox(height: 16),
              Text(context.l10n.repeatDayOfMonth),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  for (var day = 1; day <= 31; day++)
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      label: Text('$day'),
                      selected: _value.byMonthDay.contains(day),
                      onSelected: (selected) => setState(() {
                        final values = [..._value.byMonthDay];
                        if (selected) {
                          values.add(day);
                        } else {
                          values.remove(day);
                        }
                        values.sort();
                        _value = _value.copyWith(
                          byMonthDay: values,
                          byDay: const [],
                          bySetPosition: null,
                        );
                      }),
                    ),
                ],
              ),
            ],
            if (_value.frequency == RecurrenceFrequency.yearly) ...[
              const SizedBox(height: 16),
              Text(context.l10n.repeatMonths),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  for (var month = 1; month <= 12; month++)
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        DateFormat.MMM().format(DateTime(2026, month)),
                      ),
                      selected: _value.byMonth.contains(month),
                      onSelected: (selected) => setState(() {
                        final values = [..._value.byMonth];
                        if (selected) {
                          values.add(month);
                        } else {
                          values.remove(month);
                        }
                        values.sort();
                        _value = _value.copyWith(byMonth: values);
                      }),
                    ),
                ],
              ),
            ],
            if (_value.repeats) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<_AndroidRecurrenceEnd>(
                initialValue: _end,
                decoration: InputDecoration(labelText: context.l10n.repeatEnd),
                items: [
                  DropdownMenuItem(
                    value: _AndroidRecurrenceEnd.never,
                    child: Text(context.l10n.repeatNever),
                  ),
                  DropdownMenuItem(
                    value: _AndroidRecurrenceEnd.until,
                    child: Text(context.l10n.repeatUntil),
                  ),
                  DropdownMenuItem(
                    value: _AndroidRecurrenceEnd.count,
                    child: Text(context.l10n.repeatAfter),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _end = value ?? _AndroidRecurrenceEnd.never),
              ),
              if (_end == _AndroidRecurrenceEnd.count) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _count,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: context.l10n.repeatCount,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_end == _AndroidRecurrenceEnd.until) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(context.l10n.repeatUntil),
                  subtitle: Text(_date(_until)),
                  onTap: _pickUntil,
                ),
              ],
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: _candidate == null
            ? null
            : () => Navigator.pop(context, _candidate),
        child: Text(context.l10n.save),
      ),
    ],
  );

  RecurrenceRule? get _candidate {
    if (!_value.repeats) return const RecurrenceRule.none();
    final interval = int.tryParse(_interval.text);
    if (interval == null || interval < 1 || interval > 366) return null;
    RecurrenceRule result = _value.copyWith(
      interval: interval,
      count: _end == _AndroidRecurrenceEnd.count
          ? int.tryParse(_count.text)
          : null,
      untilRaw: null,
    );
    if (_end == _AndroidRecurrenceEnd.count &&
        (result.count == null || result.count! < 1 || result.count! > 3500)) {
      return null;
    }
    if (_end == _AndroidRecurrenceEnd.until) {
      if (_until.isBefore(
        DateTime(
          widget.baseDate.year,
          widget.baseDate.month,
          widget.baseDate.day,
        ),
      )) {
        return null;
      }
      result = result.withUntilDate(
        _date(_until),
        allDay: widget.allDay,
        floating: !widget.allDay && (widget.timeZone?.trim().isEmpty ?? true),
        baseDate: widget.baseDate,
        timeZone: widget.timeZone,
      );
    }
    return EventRecurrenceCodec.canEncode(widget.provider, result)
        ? result
        : null;
  }

  Future<void> _pickUntil() async {
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: _until,
      firstDate: DateTime(
        widget.baseDate.year,
        widget.baseDate.month,
        widget.baseDate.day,
      ),
      lastDate: DateTime(2200),
    );
    if (value != null) setState(() => _until = value);
  }
}

String _taskListKey(String accountId, String listId) =>
    '$accountId\u0000$listId';

Future<void> showAndroidTaskById(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required String taskId,
}) async {
  final database = ref.read(databaseProvider);
  final row =
      await (database.select(database.tasks)..where(
            (task) =>
                task.accountId.equals(accountId) &
                task.id.equals(taskId) &
                task.pendingDelete.equals(false),
          ))
          .getSingleOrNull();
  final account = await ref
      .read(accountsRepositoryProvider)
      .accountById(accountId);
  final list = row == null
      ? null
      : (await ref
                .read(taskListsRepositoryForAccountProvider(accountId))
                .listTaskLists())
            .where((value) => value.id == row.taskListId)
            .firstOrNull;
  if (!context.mounted || row == null || account == null) return;
  await Navigator.of(context).push<AndroidTaskEditorResult>(
    MaterialPageRoute<AndroidTaskEditorResult>(
      fullscreenDialog: true,
      builder: (_) => AndroidTaskEditor(
        accountId: accountId,
        provider: account.provider,
        task: TaskEntity.fromRow(row),
        accountLabel: account.displayLabel,
        listLabel: list?.title,
      ),
    ),
  );
}

RecurrenceRule _simpleTaskRecurrenceRule(
  RecurrenceFrequency frequency,
  DateTime base,
) {
  final weekday = const [
    'MO',
    'TU',
    'WE',
    'TH',
    'FR',
    'SA',
    'SU',
  ][base.weekday - 1];
  return const RecurrenceRule.none().copyWith(
    frequency: frequency,
    byDay: frequency == RecurrenceFrequency.weekly ? [weekday] : const [],
    byMonthDay:
        frequency == RecurrenceFrequency.monthly ||
            frequency == RecurrenceFrequency.yearly
        ? [base.day]
        : const [],
    byMonth: frequency == RecurrenceFrequency.yearly ? [base.month] : const [],
  );
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _today() => _date(DateTime.now());

String _recurrenceLabel(BuildContext context, RecurrenceFrequency frequency) =>
    switch (frequency) {
      RecurrenceFrequency.none => context.l10n.repeatNone,
      RecurrenceFrequency.daily => context.l10n.repeatDaily,
      RecurrenceFrequency.weekly => context.l10n.repeatWeekly,
      RecurrenceFrequency.monthly => context.l10n.repeatMonthly,
      RecurrenceFrequency.yearly => context.l10n.repeatYearly,
    };
