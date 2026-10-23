import 'package:busymax/src/core/auth/authorization_attempt.dart';

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
import '../../dav/dav_errors.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../features/tasks/data/tasks_repository.dart';
import '../../features/tasks/domain/task_capabilities.dart';
import '../../features/tasks/domain/task_source_links.dart';
import '../../features/tasks/presentation/task_details_draft.dart';
import '../../features/tasks/presentation/task_recurrence.dart';
import '../../features/recurrence/domain/event_recurrence_codec.dart';
import '../../features/recurrence/domain/recurrence_rule.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../features/schedule/presentation/attachment_download.dart';
import '../../features/schedule/presentation/attachment_upload_coordinator.dart';
import '../../microsoft_todo/api/microsoft_todo_api_client.dart';
import '../../microsoft_todo/api/microsoft_todo_api_models.dart';
import '../../microsoft_calendar/microsoft_calendar_models.dart';
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
        DateTime? notificationDate,
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
              query: key.notificationDate == null ? key.query : '',
              notificationDeadline: key.notificationDate,
              taskCompletion: key.notificationDate != null
                  ? ScheduleTaskCompletion.open
                  : key.completed
                  ? ScheduleTaskCompletion.all
                  : ScheduleTaskCompletion.open,
              showNoDateTasks: key.noDate,
              taskListFilterActive:
                  key.notificationDate == null && selected != null,
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
  const AndroidTasksScreen({super.key, this.notificationDate});
  final DateTime? notificationDate;
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
    this.completed,
  });

  final AndroidTaskEditorAction action;
  final String accountId;
  final String taskListId;
  final String taskId;
  final String? previousTaskListId;
  final bool? completed;
}

class _AndroidTasksScreenState extends ConsumerState<AndroidTasksScreen> {
  String _query = '';
  String? _accountId;
  String? _listId;
  bool _showCompleted = true;
  bool _showNoDate = true;
  var _mutationGeneration = 0;
  bool _clearingCompleted = false;
  TaskListMutationIntent? _mutationIntent;

  @override
  Widget build(BuildContext context) {
    final listsState = ref.watch(scheduleTaskListsProvider);
    final lists = listsState.valueOrNull ?? const [];
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
        !listsState.isLoading &&
        !listsState.hasError &&
        !lists.any(
          (list) => list.id == _listId && list.accountId == _accountId,
        )) {
      _accountId = null;
      _listId = null;
    }
    final taskQuery = (
      query: _query,
      accountId: _accountId,
      listId: _listId,
      completed: _showCompleted,
      noDate: _showNoDate,
      notificationDate: widget.notificationDate,
    );
    final tasks = ref.watch(_androidTasksProvider(taskQuery));
    void retry() {
      ref.invalidate(scheduleTaskListsProvider);
      ref.invalidate(_androidTasksProvider(taskQuery));
    }

    Widget loadFailure() => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.collectionsLoadFailed),
          TextButton(onPressed: retry, child: Text(context.l10n.retry)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.notificationDate == null
              ? context.l10n.tasks
              : '${context.l10n.dueDate} · ${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(widget.notificationDate!)}',
        ),
        actions: [
          if (widget.notificationDate == null)
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
        bottom: widget.notificationDate != null
            ? null
            : PreferredSize(
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
      body: Column(
        children: [
          if (listsState.hasError || (tasks.hasError && tasks.hasValue))
            loadFailure(),
          Expanded(
            child: tasks.when(
              skipError: tasks.hasValue,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: loadFailure()),
              data: (items) => BusyMaxMutationList<TaskScheduleItem>(
                items: items,
                mutation: _mutationIntent,
                identityOf: (task) =>
                    '${task.accountId}\u0000${task.sourceId}\u0000${task.id}',
                mutationApplied: (task, mutation) =>
                    mutation.completed == null ||
                    task.completed == mutation.completed,
                onMutationConsumed: (mutation) {
                  if (!mounted) return;
                  if (_mutationIntent?.generation == mutation.generation) {
                    setState(() => _mutationIntent = null);
                  }
                },
                emptyBuilder: (context) =>
                    Center(child: Text(context.l10n.noTasks)),
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
                        if (task.cancelled) context.l10n.taskStatusCancelled,
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
          ),
        ],
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
            TaskPatchInput.completion(
              !task.completed,
              includeCompletedTimestamp: false,
            ),
          );
    } on Object catch (error) {
      if (mounted) {
        setState(() => _mutationIntent = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
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
    if (accountId == null || listId == null || _clearingCompleted) return;
    setState(() => _clearingCompleted = true);
    try {
      final repository = ref.read(tasksRepositoryForAccountProvider(accountId));
      final count = await repository.countClearCompleted(listId);
      if (!mounted) return;
      final account =
          (ref.read(accountsStreamProvider).valueOrNull ??
                  const <AccountEntity>[])
              .where((value) => value.id == accountId)
              .firstOrNull;
      final list =
          (ref.read(scheduleTaskListsProvider).valueOrNull ??
                  const <TaskListEntity>[])
              .where(
                (value) => value.accountId == accountId && value.id == listId,
              )
              .firstOrNull;
      if (account == null || list == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.clearCompleted),
          content: Text(
            account.provider == BusyProvider.google
                ? context.l10n.clearCompletedGoogleConfirmation(
                    list.title,
                    account.displayLabel,
                    count,
                  )
                : context.l10n.clearCompletedNextcloudConfirmation(
                    list.title,
                    account.displayLabel,
                    count,
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.clearCompleted),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await repository.clearCompleted(listId);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _clearingCompleted = false);
    }
  }

  Future<void> _create(List<TaskListEntity> lists) async {
    final current = lists
        .where((list) => list.id == _listId && list.accountId == _accountId)
        .firstOrNull;
    final settings = ref.read(appSettingsControllerProvider);
    final selected =
        current ??
        preferredCreationDestination(
          lists,
          selected: settings.defaultTaskList,
          lastUsed: settings.lastUsedTaskList,
          destinationOf: (list) =>
              CreationDestination(accountId: list.accountId, id: list.id),
        ) ??
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
      onMutationStarted: _consumeEditorResult,
      onMutationCommitted: _consumeEditorResult,
      onMutationFailed: _clearEditorMutation,
    );
    // The callbacks report the mutation before route cleanup can delay it.
    if (result == null) return;
  }

  Future<void> _edit(TaskScheduleItem task) async {
    await showAndroidTaskEditor(
      context,
      ref,
      task: task,
      onMutationStarted: _consumeEditorResult,
      onMutationCommitted: _consumeEditorResult,
      onMutationFailed: _clearEditorMutation,
    );
  }

  void _consumeEditorResult(AndroidTaskEditorResult result) {
    final presentation = switch (result.action) {
      AndroidTaskEditorAction.created => TaskListMutationPresentation.insertion,
      AndroidTaskEditorAction.deleted ||
      AndroidTaskEditorAction.moved => TaskListMutationPresentation.removal,
      AndroidTaskEditorAction.updated =>
        TaskListMutationPresentation.completion,
    };
    final taskListId = result.previousTaskListId ?? result.taskListId;
    final current = _mutationIntent;
    if (current?.presentation == presentation &&
        current?.accountId == result.accountId &&
        current?.taskListId == taskListId &&
        current?.taskId == result.taskId &&
        current?.completed == result.completed) {
      return;
    }
    setState(() {
      _mutationIntent = TaskListMutationIntent(
        presentation: presentation,
        accountId: result.accountId,
        taskListId: taskListId,
        taskId: result.taskId,
        completed: result.completed,
        generation: ++_mutationGeneration,
      );
    });
  }

  void _clearEditorMutation() {
    if (mounted) setState(() => _mutationIntent = null);
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
  ValueChanged<AndroidTaskEditorResult>? onMutationStarted,
  ValueChanged<AndroidTaskEditorResult>? onMutationCommitted,
  VoidCallback? onMutationFailed,
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
        onMutationStarted: onMutationStarted,
        onMutationCommitted: onMutationCommitted,
        onMutationFailed: onMutationFailed,
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
    this.onMutationStarted,
    this.onMutationCommitted,
    this.onMutationFailed,
  });
  final String accountId;
  final BusyProvider provider;
  final TaskEntity? task;
  final TaskListEntity? creationList;
  final DateTime? initialDue;
  final String? accountLabel;
  final String? listLabel;
  final ValueChanged<AndroidTaskEditorResult>? onMutationStarted;
  final ValueChanged<AndroidTaskEditorResult>? onMutationCommitted;
  final VoidCallback? onMutationFailed;
  @override
  ConsumerState<AndroidTaskEditor> createState() => _AndroidTaskEditorState();
}

class _AndroidTaskEditorState extends ConsumerState<AndroidTaskEditor> {
  AuthorizationCancellation? _consentCancellation;

  Future<List<TaskSourceLink>>? _linkedResourcesFuture;
  Future<List<MicrosoftTodoAttachmentDto>>? _attachmentsFuture;
  bool _attachmentBusy = false;
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
  bool _showValidation = false;
  final _titleFocus = FocusNode();
  final _formScroll = ScrollController();
  final _titleFieldKey = GlobalKey();
  final _urlFieldKey = GlobalKey();
  var _validationGeneration = 0;
  final _urlFocus = FocusNode();
  final _timingFeedbackKey = GlobalKey();
  late TaskEntity? _observedTask = widget.task;
  TaskEntity? _recoveryComparisonTask;
  bool _recoveryBaselineUnavailable = false;
  String? _recoveryOriginalBaseTitle;
  bool _allowPop = false;
  bool _recoveryLoaded = false;
  String? _recoverySourceKey;
  bool _recoveredConcurrentState = false;
  String? _pendingMoveDestinationId;
  bool _recoveryWritesBlocked = false;
  Future<void> _recoveryIo = Future.value();
  Timer? _recoveryTimer;
  late TaskDetailsDraft _initialDraft = _draft;
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

  bool get _canWrite =>
      !_saving &&
      _recoveryLoaded &&
      (widget.task == null
          ? _capabilities.canCreateTasks
          : _capabilities.canUpdateTasks);

  bool get _hasDraftEdits => !_draft.hasSameValues(_initialDraft);

  bool get _hasPendingEdits =>
      _hasDraftEdits || _pendingMoveDestinationId != null;

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
    _consentCancellation?.cancel();
    _recoveryTimer?.cancel();
    if (_recoveryLoaded && _hasPendingEdits && !_allowPop) {
      unawaited(_persistRecovery());
    }
    _formScroll.dispose();
    _titleFocus.dispose();
    _urlFocus.dispose();
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
      canPop: _allowPop || (!_saving && !_hasPendingEdits),
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
          controller: _formScroll,
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(widget.listLabel ?? _draft.taskListId),
                subtitle: Text(widget.accountLabel ?? widget.accountId),
              ),
            ),
            if (widget.provider == BusyProvider.google && widget.task != null)
              for (final link in widget.task!.googleSourceLinks)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: Text(
                    link.label?.isNotEmpty == true
                        ? link.label!
                        : context.l10n.openInProvider,
                  ),
                  subtitle: Text(link.url),
                  onTap: () async {
                    if (!await openScheduleWebLink(link.url) &&
                        context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.eventLinkOpenFailed),
                        ),
                      );
                    }
                  },
                ),
            if (widget.provider == BusyProvider.microsoft &&
                widget.task != null)
              Column(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      final key = (
                        accountId: widget.accountId,
                        taskListId: _draft.taskListId,
                        taskId: (_observedTask?.id ?? widget.task!.id),
                      );
                      ref.invalidate(microsoftTaskLinkedResourcesProvider(key));
                      _linkedResourcesFuture = ref.read(
                        microsoftTaskLinkedResourcesProvider(key).future,
                      );
                    }),
                    child: Text(context.l10n.linkedResources),
                  ),
                  if (_linkedResourcesFuture case final future?)
                    FutureBuilder<List<TaskSourceLink>>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(context.l10n.operationFailed);
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        if (snapshot.data!.isEmpty) {
                          return Text(context.l10n.noLinkedResources);
                        }
                        return Column(
                          children: [
                            for (final link in snapshot.data!)
                              ListTile(
                                leading: const Icon(Icons.open_in_new),
                                title: Text(
                                  link.label?.isNotEmpty == true
                                      ? link.label!
                                      : context.l10n.openInProvider,
                                ),
                                subtitle: Text(link.url),
                                onTap: () async {
                                  if (!await openScheduleWebLink(link.url) &&
                                      context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.l10n.eventLinkOpenFailed,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            if (widget.provider == BusyProvider.microsoft &&
                widget.task != null)
              Column(
                children: [
                  TextButton(
                    key: const Key('task-attachments-load'),
                    onPressed: () => setState(() {
                      final key = (
                        accountId: widget.accountId,
                        taskListId: _draft.taskListId,
                        taskId: (_observedTask?.id ?? widget.task!.id),
                      );
                      ref.invalidate(microsoftTaskAttachmentsProvider(key));
                      _attachmentsFuture = ref.read(
                        microsoftTaskAttachmentsProvider(key).future,
                      );
                    }),
                    child: Text(context.l10n.attachments),
                  ),
                  if (canWrite &&
                      !widget.task!.pendingDelete &&
                      !(_observedTask?.id ?? widget.task!.id).startsWith(
                        'local-task-',
                      ))
                    TextButton.icon(
                      onPressed:
                          _attachmentBusy ||
                              !ref
                                  .watch(attachmentUploadCoordinatorProvider)
                                  .canSubmit(
                                    AttachmentUploadCoordinator.taskKey(
                                      widget.accountId,
                                      _draft.taskListId,
                                      (_observedTask?.id ?? widget.task!.id),
                                    ),
                                  )
                          ? null
                          : _uploadTaskAttachment,
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.attachments),
                    ),
                  if (ref
                          .watch(attachmentUploadCoordinatorProvider)
                          .retryAfter(
                            AttachmentUploadCoordinator.taskKey(
                              widget.accountId,
                              _draft.taskListId,
                              (_observedTask?.id ?? widget.task!.id),
                            ),
                          ) !=
                      null)
                    Text(context.l10n.attachmentUploadRateLimited),
                  if (ref
                      .watch(attachmentUploadCoordinatorProvider)
                      .needsReconciliation(
                        AttachmentUploadCoordinator.taskKey(
                          widget.accountId,
                          _draft.taskListId,
                          (_observedTask?.id ?? widget.task!.id),
                        ),
                      )) ...[
                    Text(
                      ref
                                  .watch(attachmentUploadCoordinatorProvider)
                                  .confirmedId(
                                    AttachmentUploadCoordinator.taskKey(
                                      widget.accountId,
                                      _draft.taskListId,
                                      (_observedTask?.id ?? widget.task!.id),
                                    ),
                                  ) ==
                              null
                          ? context.l10n.attachmentUploadUnresolved
                          : context.l10n.completed,
                    ),
                    TextButton(
                      onPressed: _attachmentBusy ? null : _reconcileTaskUpload,
                      child: Text(context.l10n.refresh),
                    ),
                    if (ref
                        .watch(attachmentUploadCoordinatorProvider)
                        .hasResumableSession(
                          AttachmentUploadCoordinator.taskKey(
                            widget.accountId,
                            _draft.taskListId,
                            (_observedTask?.id ?? widget.task!.id),
                          ),
                        ))
                      TextButton(
                        onPressed: _attachmentBusy ? null : _cancelTaskUpload,
                        child: Text(context.l10n.cancel),
                      ),
                    if (ref
                        .watch(attachmentUploadCoordinatorProvider)
                        .canResolveManually(
                          AttachmentUploadCoordinator.taskKey(
                            widget.accountId,
                            _draft.taskListId,
                            (_observedTask?.id ?? widget.task!.id),
                          ),
                        )) ...[
                      TextButton(
                        onPressed: _attachmentBusy
                            ? null
                            : () => _resolveTaskUpload(exists: true),
                        child: Text(context.l10n.completed),
                      ),
                      TextButton(
                        onPressed: _attachmentBusy
                            ? null
                            : () => _resolveTaskUpload(exists: false),
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ],
                  if (_attachmentsFuture case final future?)
                    FutureBuilder<List<MicrosoftTodoAttachmentDto>>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(context.l10n.attachmentsNotLoaded);
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        if (snapshot.data!.isEmpty) {
                          return Text(context.l10n.noneValue);
                        }
                        return Column(
                          children: [
                            for (final attachment in snapshot.data!)
                              ListTile(
                                leading: const Icon(Icons.attach_file),
                                title: Text(attachment.name),
                                subtitle: attachment.size == null
                                    ? null
                                    : Text('${attachment.size} B'),
                                trailing:
                                    canWrite &&
                                        !widget.task!.pendingDelete &&
                                        !(_observedTask?.id ?? widget.task!.id)
                                            .startsWith('local-task-')
                                    ? IconButton(
                                        tooltip: context.l10n.delete,
                                        onPressed: _attachmentBusy
                                            ? null
                                            : () => _deleteTaskAttachment(
                                                attachment,
                                              ),
                                        icon: const Icon(Icons.delete_outline),
                                      )
                                    : null,
                                onTap: attachment.isFile
                                    ? () => _downloadTaskAttachment(attachment)
                                    : null,
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              key: _titleFieldKey,
              controller: _title,
              focusNode: _titleFocus,
              enabled: canWrite,
              autofocus: widget.task == null,
              decoration: InputDecoration(
                labelText: context.l10n.title,
                errorText: _showValidation && _draft.title.trim().isEmpty
                    ? context.l10n.invalidCollectionValue
                    : null,
              ),
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(title: v)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              enabled:
                  canWrite &&
                  !(widget.task?.googleAssignment.isFromDocument ?? false),
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(labelText: context.l10n.notes),
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(notes: v)),
            ),
            if (_showValidation &&
                _draft.scheduleIssueFor(capabilities) != TaskScheduleIssue.none)
              Padding(
                key: _timingFeedbackKey,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _draft.scheduleIssueFor(capabilities) ==
                          TaskScheduleIssue.dueBeforeStart
                      ? context.l10n.taskDueBeforeStart
                      : context.l10n.taskStartDueTimeModeMismatch,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
                    : (value) => _setReminderEnabled(value),
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
              if (widget.provider == BusyProvider.microsoft)
                _microsoftCategories(canWrite),
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
                key: _urlFieldKey,
                controller: _url,
                focusNode: _urlFocus,
                enabled: canWrite,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: context.l10n.taskUrl,
                  errorText:
                      _showValidation &&
                          !_draft.hasValidTaskUrlFor(capabilities)
                      ? context.l10n.invalidTaskUrl
                      : null,
                ),
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
                    .watchTaskHierarchy(
                      _draft.taskListId,
                      (_observedTask?.id ?? widget.task!.id),
                    ),
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
    if (!_canWrite) return;
    final current = DateTime.tryParse(_draft.dueDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value != null && mounted && _canWrite) {
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
          onTap: _canWrite ? () => _openHierarchyTask(parent) : null,
        ),
      for (final subtask in hierarchy.subtasks)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconButton(
            onPressed: _canWrite && capabilities.canUpdateTasks
                ? () => _toggleSubtask(subtask)
                : null,
            icon: AndroidTaskCompletionIcon(completed: subtask.completed),
          ),
          title: Text(subtask.title),
          trailing: subtask.kind == TaskSubtaskKind.checklistItem
              ? PopupMenuButton<String>(
                  key: ValueKey('android-checklist-actions-${subtask.id}'),
                  enabled: _canWrite && capabilities.canUpdateTasks,
                  onSelected: (action) {
                    if (action == 'edit') {
                      unawaited(_editChecklistSubtask(subtask));
                    }
                    if (action == 'delete') {
                      unawaited(_deleteChecklistSubtask(subtask));
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(context.l10n.rename),
                    ),
                    if (capabilities.canDeleteTasks)
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(context.l10n.delete),
                      ),
                  ],
                )
              : subtask.hasChildren
              ? const Icon(Icons.account_tree_outlined)
              : null,
          onTap: !_canWrite || subtask.task == null
              ? null
              : () => _openHierarchyTask(subtask.task!),
        ),
      OutlinedButton.icon(
        onPressed:
            _canWrite &&
                capabilities.canCreateTasks &&
                !(widget.task?.googleAssignment.isAssigned ?? false)
            ? _createSubtask
            : null,
        icon: const Icon(Icons.add_task),
        label: Text(context.l10n.createSubtask),
      ),
    ],
  );

  Future<void> _openHierarchyTask(TaskEntity task) async {
    if (!_canWrite) return;
    await Navigator.of(context).push<AndroidTaskEditorResult>(
      MaterialPageRoute<AndroidTaskEditorResult>(
        fullscreenDialog: true,
        builder: (_) => AndroidTaskEditor(
          accountId: widget.accountId,
          provider: widget.provider,
          task: task,
          accountLabel: widget.accountLabel,
          listLabel: widget.listLabel,
          onMutationStarted: widget.onMutationStarted,
          onMutationCommitted: widget.onMutationCommitted,
          onMutationFailed: widget.onMutationFailed,
        ),
      ),
    );
  }

  Future<void> _toggleSubtask(TaskSubtaskEntity subtask) async {
    if (!_canWrite) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(
        tasksRepositoryForAccountProvider(widget.accountId),
      );
      if (subtask.kind == TaskSubtaskKind.checklistItem) {
        await repository.patchChecklistSubtask(
          taskListId: _draft.taskListId,
          parentTaskId: (_observedTask?.id ?? widget.task!.id),
          checklistItemId: subtask.id,
          observedItem: subtask.checklistItem,
          completed: !subtask.completed,
        );
      } else {
        await repository.patchTask(
          _draft.taskListId,
          subtask.id,
          TaskPatchInput.completion(
            !subtask.completed,
            includeCompletedTimestamp: false,
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editChecklistSubtask(TaskSubtaskEntity subtask) async {
    if (!_canWrite) return;
    final controller = TextEditingController(text: subtask.title);
    var busy = false;
    String? error;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (busy) return;
            final title = controller.text.trim();
            if (title.isEmpty) {
              setDialogState(() => error = context.l10n.invalidCollectionValue);
              return;
            }
            setDialogState(() {
              busy = true;
              error = null;
            });
            setState(() => _saving = true);
            try {
              await ref
                  .read(tasksRepositoryForAccountProvider(widget.accountId))
                  .patchChecklistSubtask(
                    taskListId: _draft.taskListId,
                    parentTaskId: _observedTask?.id ?? widget.task!.id,
                    checklistItemId: subtask.id,
                    observedItem: subtask.checklistItem,
                    title: title,
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } on Object catch (failure) {
              if (dialogContext.mounted) {
                setDialogState(() {
                  busy = false;
                  error = '$failure';
                });
              }
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          }

          return PopScope<void>(
            canPop: !busy,
            child: AlertDialog(
              title: Text(context.l10n.rename),
              content: TextField(
                key: const ValueKey('android-checklist-title'),
                controller: controller,
                autofocus: true,
                enabled: !busy,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.title,
                  errorText: error,
                ),
                onSubmitted: (_) => unawaited(save()),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(context.l10n.save),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    controller.dispose();
  }

  Future<void> _deleteChecklistSubtask(TaskSubtaskEntity subtask) async {
    if (!_canWrite) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.delete),
        content: Text(context.l10n.deleteTaskConfirmation(subtask.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_canWrite) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .deleteChecklistSubtask(
            taskListId: _draft.taskListId,
            parentTaskId: _observedTask?.id ?? widget.task!.id,
            checklistItemId: subtask.id,
            observedItem: subtask.checklistItem,
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createSubtask() async {
    if (!_canWrite) return;
    if (widget.task?.googleAssignment.isAssigned ?? false) return;
    final controller = TextEditingController();
    final route = DialogRoute<String>(
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
    final title = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    controller.dispose();
    if (title == null || !mounted || !_canWrite) return;
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .createSubtask(
            taskListId: _draft.taskListId,
            parentTaskId: (_observedTask?.id ?? widget.task!.id),
            title: title,
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _pickDueTime() async {
    if (!_canWrite) return;
    final parts = (_draft.microsoftDueTime ?? '09:00').split(':');
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (value != null && mounted && _canWrite) {
      setState(
        () => _draft = _draft.copyWith(
          microsoftDueTime:
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  Future<void> _pickStartDate() async {
    if (!_canWrite) return;
    final current =
        DateTime.tryParse(_draft.microsoftStartDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value != null && mounted && _canWrite) {
      setState(
        () => _draft = _draft.copyWith(microsoftStartDate: _date(value)),
      );
    }
  }

  Future<void> _pickStartTime() async {
    if (!_canWrite) return;
    final value = await _pickTime(_draft.microsoftStartTime);
    if (value != null && mounted && _canWrite) {
      setState(() => _draft = _draft.copyWith(microsoftStartTime: value));
    }
  }

  void _setReminderEnabled(bool enabled) {
    final String zone =
        _draft.microsoftReminderTimeZone ?? ref.read(localTimeZoneProvider);
    final value = TaskDetailsDraft.newReminderDefault(
      dueDate: _draft.dueDate,
      timeZone: zone,
      now: DateTime.now(),
    );
    setState(
      () => _draft = _draft.copyWith(
        microsoftReminderEnabled: enabled,
        microsoftReminderDate: enabled ? _date(value) : null,
        microsoftReminderTime: enabled ? _clock(value) : null,
        microsoftReminderTimeZone: zone,
      ),
    );
  }

  Future<void> _pickReminderDate() async {
    if (!_canWrite) return;
    final current =
        DateTime.tryParse(_draft.microsoftReminderDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value != null && mounted && _canWrite) {
      setState(
        () => _draft = _draft.copyWith(microsoftReminderDate: _date(value)),
      );
    }
  }

  Future<void> _pickReminderTime() async {
    if (!_canWrite) return;
    final value = await _pickTime(_draft.microsoftReminderTime);
    if (value != null && mounted && _canWrite) {
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
    if (!_canWrite) return;
    final current =
        DateTime.tryParse(_draft.completedDate ?? '') ?? DateTime.now();
    final value = await showBusyMaxDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(2200),
    );
    if (value == null || !mounted || !_canWrite) return;
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
    if (!_canWrite) return;
    final value = await _pickTime(_draft.completedTime);
    if (value != null && mounted && _canWrite) {
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
    if (!_canWrite) return;
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
    if (mode == null || !mounted || !_canWrite) return;
    IcalTaskAlarm? alarm;
    if (mode == 'absolute') {
      final initial = DateTime.now().add(const Duration(minutes: 10));
      final date = await showBusyMaxDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1970),
        lastDate: DateTime(2200),
      );
      if (date == null || !mounted || !_canWrite) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !mounted || !_canWrite) return;
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
      if (selection == null || !mounted || !_canWrite) return;
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

  Widget _microsoftCategories(bool canWrite) {
    final catalog = ref.watch(
      microsoftMasterCategoriesProvider(widget.accountId),
    );
    return catalog.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => TextButton(
        onPressed: () async {
          _consentCancellation?.cancel();
          final consent = AuthorizationCancellation();
          _consentCancellation = consent;
          try {
            try {
              await ref
                  .read(microsoftCategoryAuthorizationProvider)
                  ?.authorizeCategoryAccess(
                    widget.accountId,
                    cancellation: consent,
                  );
              if (!mounted || consent.isCancelled) return;
              if (mounted) {
                ref.invalidate(
                  microsoftMasterCategoriesProvider(widget.accountId),
                );
              }
            } on Object {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.outlookCategoriesUnavailable),
                  ),
                );
              }
            }
          } finally {
            consent.cancel();
            if (identical(_consentCancellation, consent)) {
              _consentCancellation = null;
            }
          }
        },
        child: Text(context.l10n.loadOutlookCategories),
      ),
      data: (categories) => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final category in categories)
            FilterChip(
              label: Text(category.displayName),
              avatar: microsoftCategorySwatchArgb(category.color) == null
                  ? null
                  : CircleAvatar(
                      backgroundColor: Color(
                        microsoftCategorySwatchArgb(category.color)!,
                      ),
                      radius: 7,
                    ),
              selected: _draft.categories.contains(category.displayName),
              onSelected: !canWrite
                  ? null
                  : (selected) {
                      final values = [..._draft.categories];
                      if (selected) {
                        if (!values.contains(category.displayName)) {
                          values.add(category.displayName);
                        }
                      } else {
                        values.remove(category.displayName);
                      }
                      setState(() {
                        _categories.text = values.join(', ');
                        _draft = _draft.copyWith(categories: values);
                      });
                    },
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_canWrite) return;
    if (_pendingMoveDestinationId != null) {
      await _moveToList();
      return;
    }
    if (_draft.hasNewPastReminder(
      original: widget.task,
      capabilities: _capabilities,
      localTimeZone: ref.read(localTimeZoneProvider),
      now: DateTime.now(),
    )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.reminderTimeInPast)));
      return;
    }
    setState(_syncDraftFromControllers);
    if (!_validateDraft()) return;
    if (_recoveryBaselineUnavailable && _hasDraftEdits) {
      _showRecoveryBaselineReview();
      return;
    }
    setState(() => _saving = true);
    final existing = widget.task;
    final pendingResult = existing == null
        ? null
        : AndroidTaskEditorResult(
            action: AndroidTaskEditorAction.updated,
            accountId: widget.accountId,
            taskListId: _draft.taskListId,
            taskId: existing.id,
            completed: _draftCompletion,
          );
    if (pendingResult != null) {
      widget.onMutationStarted?.call(pendingResult);
    }
    var mutationPersisted = false;
    try {
      final taskId = await _persistTaskDraft();
      mutationPersisted = true;
      final result = AndroidTaskEditorResult(
        action: pendingResult?.action ?? AndroidTaskEditorAction.created,
        accountId: widget.accountId,
        taskListId: _draft.taskListId,
        taskId: taskId,
        completed: pendingResult?.completed,
      );
      widget.onMutationCommitted?.call(result);
      if (mounted) {
        await _clearRecovery(finalCleanup: true);
        if (!mounted) return;
        setState(() => _allowPop = true);
        Navigator.pop(context, result);
      }
    } on Object catch (error) {
      if (pendingResult != null && !mutationPersisted) {
        widget.onMutationFailed?.call();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_taskMutationError(error)),
            action:
                error is TaskDraftConflictException && !error.current.localDirty
                ? SnackBarAction(
                    label: context.l10n.keepServerVersion,
                    onPressed: () => unawaited(_useLatestTask()),
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showRecoveryBaselineReview() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.taskDraftConflict),
        action: SnackBarAction(
          label: context.l10n.keepServerVersion,
          onPressed: () => unawaited(_useLatestTask()),
        ),
      ),
    );
  }

  Future<void> _useLatestTask() async {
    if (!_canWrite ||
        !await _confirmDiscardChanges() ||
        !mounted ||
        !_canWrite) {
      return;
    }
    setState(() => _saving = true);
    try {
      final latest = await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .readTask(_draft.taskListId, _draft.taskId);
      if (!mounted) return;
      if (latest == null || latest.localDirty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              latest == null
                  ? context.l10n.taskUnavailableDraftRetained
                  : context.l10n.taskDraftConflict,
            ),
          ),
        );
        return;
      }
      setState(() {
        _observedTask = latest;
        _recoveryComparisonTask = null;
        _recoveryBaselineUnavailable = false;
        _recoveryOriginalBaseTitle = null;
        _draft = TaskDetailsDraft.fromTask(
          latest,
          ref.read(localTimeZoneProvider),
        );
        _initialDraft = _draft;
        _pendingMoveDestinationId = null;
        _showValidation = false;
        _recurrenceFrequency = _taskRecurrence().frequency;
        _syncControllersFromDraft();
      });
      await _clearRecovery();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_taskMutationError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _taskMutationError(Object error) => switch (error) {
    TaskDraftConflictException() => context.l10n.taskDraftConflict,
    DavException(code: 'DavTaskDurationRequiresStart') =>
      context.l10n.taskDurationRequiresStart,
    _ => '$error',
  };

  bool? get _draftCompletion {
    final original = widget.task;
    if (original == null) return null;
    final originalCompleted =
        original.status?.toLowerCase() == 'completed' ||
        original.status?.toUpperCase() == 'COMPLETED' ||
        original.percentComplete == 100;
    final completed =
        _draft.taskStatus?.toUpperCase() == 'COMPLETED' ||
        _draft.percentComplete == 100;
    return completed == originalCompleted ? null : completed;
  }

  void _syncControllersFromDraft() {
    _title.text = _draft.title;
    _notes.text = _draft.notes;
    _location.text = _draft.location;
    _url.text = _draft.taskUrl;
    _categories.text = _draft.categories.join(', ');
  }

  void _syncDraftFromControllers() {
    _draft = _draft.copyWith(
      title: _title.text,
      notes: _notes.text,
      location: _location.text,
      taskUrl: _url.text,
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

  bool _validateDraft() {
    if (_draftIsValid) return true;
    setState(() => _showValidation = true);
    if (_draft.title.trim().isEmpty) {
      unawaited(_revealInvalidField(_titleFieldKey, _titleFocus));
    } else if (!_draft.hasValidTaskUrlFor(_capabilities)) {
      unawaited(_revealInvalidField(_urlFieldKey, _urlFocus));
    } else {
      unawaited(_revealInvalidField(_timingFeedbackKey, null));
    }
    return false;
  }

  Future<void> _revealInvalidField(GlobalKey key, FocusNode? focus) async {
    final generation = ++_validationGeneration;
    bool active() => mounted && !_saving && generation == _validationGeneration;
    await WidgetsBinding.instance.endOfFrame;
    if (!active() || !_formScroll.hasClients) return;
    if (key.currentContext == null) {
      _formScroll.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
    }
    // The form lazily builds its fields. Walk the bounded editor until the
    // invalid field is mounted, then use its real geometry to reveal it.
    for (
      var attempt = 0;
      attempt < 40 && active() && key.currentContext == null;
      attempt++
    ) {
      final position = _formScroll.position;
      final next = (position.pixels + 400)
          .clamp(0, position.maxScrollExtent)
          .toDouble();
      if (next <= position.pixels) break;
      _formScroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!active()) return;
    final field = key.currentContext;
    if (field != null && field.mounted) {
      await Scrollable.ensureVisible(
        field,
        alignment: 0.1,
        duration: const Duration(milliseconds: 150),
      );
      if (active()) focus?.requestFocus();
    }
  }

  Future<String> _persistTaskDraft() async {
    final changed = widget.task == null
        ? null
        : _draft.toPatch(
            _observedTask!,
            _capabilities,
            localTimeZone: ref.read(localTimeZoneProvider),
          );
    if ((_draft.microsoftReminderEnabled || _draft.alarms.isNotEmpty) &&
        (changed == null ||
            changed.containsKey('microsoftReminderDateTime') ||
            changed.containsKey('taskAlarmsJson'))) {
      final notifications = ref.read(androidNotificationServiceProvider);
      final granted = await notifications.requestNotificationPermission();
      final readiness = notifications.readiness.value;
      if ((!granted || !readiness.remindersReady) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !granted ||
                      readiness.notificationsAllowed == false ||
                      readiness.remindersAllowed == false
                  ? context.l10n.notificationsBlocked
                  : context.l10n.notificationsUnknown,
            ),
            action: SnackBarAction(
              label: context.l10n.settingsSystem,
              onPressed: () =>
                  BusyMaxAndroidPlatform.instance.openNotificationSettings(),
            ),
          ),
        );
      }
    }
    final repository = ref.read(
      tasksRepositoryForAccountProvider(widget.accountId),
    );
    if (widget.task == null) {
      final id = await repository.createTask(
        _draft.taskListId,
        _draft.toCreateInput(
          _capabilities,
          localTimeZone: ref.read(localTimeZoneProvider),
        ),
      );
      unawaited(
        ref
            .read(appSettingsControllerProvider.notifier)
            .rememberTaskList(
              CreationDestination(
                accountId: widget.accountId,
                id: _draft.taskListId,
              ),
            ),
      );
      return id;
    }
    await repository.patchTask(
      _draft.taskListId,
      _draft.taskId,
      TaskPatchInput(
        _draft.toPatch(
          _observedTask!,
          _capabilities,
          localTimeZone: ref.read(localTimeZoneProvider),
        ),
        observedTask: _observedTask,
      ),
    );
    final committed = await repository.readTask(
      _draft.taskListId,
      _draft.taskId,
    );
    if (committed != null) {
      _observedTask = committed;
      _draft = TaskDetailsDraft.fromTask(
        committed,
        ref.read(localTimeZoneProvider),
      );
      _syncControllersFromDraft();
      _recoveryComparisonTask = null;
      _recoveryBaselineUnavailable = false;
      _recoveryOriginalBaseTitle = null;
      _initialDraft = _draft;
    }
    return committed?.id ?? (_observedTask?.id ?? widget.task!.id);
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
        baseDate: widget.provider == BusyProvider.nextcloud
            ? _recurrenceReference?.dateTime
            : DateTime.tryParse(_draft.dueDate ?? ''),
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

  TaskRecurrenceReference? get _recurrenceReference =>
      taskDraftRecurrenceReference(
        _draft,
        localTimeZone: ref.read(localTimeZoneProvider),
      );

  Future<void> _editAdvancedRecurrence() async {
    if (!_canWrite) return;
    final initial = _taskRecurrence();
    if (!initial.isSupported) return;
    final reference = _recurrenceReference;
    final base = reference?.dateTime ?? DateTime.now();
    final result = await showDialog<RecurrenceRule>(
      context: context,
      builder: (_) => _AndroidRecurrenceDialog(
        initial: initial,
        baseDate: base,
        provider: widget.provider,
        allDay: reference?.allDay ?? true,
        timeZone: reference?.timeZone,
      ),
    );
    if (result != null &&
        mounted &&
        _canWrite &&
        result.toJsonString() != initial.toJsonString()) {
      _applyRecurrence(result, base);
    }
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
                allDay: _recurrenceReference?.allDay ?? true,
                timeZone: _recurrenceReference?.timeZone,
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
    if (!_canWrite) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteTask),
        content: Text(
          widget.task!.googleAssignment.isAssigned
              ? '${context.l10n.deleteTaskConfirmation(widget.task!.title)}\n\n${context.l10n.deleteAssignedTaskWarning}'
              : context.l10n.deleteTaskConfirmation(widget.task!.title),
        ),
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
    if (confirmed != true || !mounted || !_canWrite) return;
    setState(() => _saving = true);
    final result = AndroidTaskEditorResult(
      action: AndroidTaskEditorAction.deleted,
      accountId: widget.accountId,
      taskListId: _draft.taskListId,
      taskId: (_observedTask?.id ?? widget.task!.id),
    );
    widget.onMutationStarted?.call(result);
    var mutationPersisted = false;
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .deleteTask(
            _draft.taskListId,
            (_observedTask?.id ?? widget.task!.id),
            confirmedAssignedSourceDeletion:
                widget.task!.googleAssignment.isAssigned,
          );
      mutationPersisted = true;
      widget.onMutationCommitted?.call(result);
      if (mounted) {
        await _clearRecovery(finalCleanup: true);
        if (!mounted) return;
        setState(() => _allowPop = true);
        Navigator.pop(context, result);
      }
    } on Object catch (error) {
      if (!mutationPersisted) widget.onMutationFailed?.call();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _duplicate() async {
    if (!_canWrite) return;
    setState(() => _saving = true);
    try {
      final duplicateId = await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .duplicateTask(
            _draft.taskListId,
            (_observedTask?.id ?? widget.task!.id),
          );
      widget.onMutationCommitted?.call(
        AndroidTaskEditorResult(
          action: AndroidTaskEditorAction.created,
          accountId: widget.accountId,
          taskListId: _draft.taskListId,
          taskId: duplicateId,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.duplicateTask)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _moveToList() async {
    if (!_canWrite) return;
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
      return;
    }
    if (!mounted || !_canWrite || lists.isEmpty) return;
    final previousDestination = lists
        .where((list) => list.id == _pendingMoveDestinationId)
        .firstOrNull;
    final destination =
        previousDestination ??
        await selectAndroidTaskList(
          context,
          lists,
          title: context.l10n.list,
          accountLabels: {
            widget.accountId: widget.accountLabel ?? widget.accountId,
          },
        );
    if (destination == null || !mounted || !_canWrite) return;
    setState(_syncDraftFromControllers);
    var saveEdits = false;
    if (_hasDraftEdits) {
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
      if (saveEdits && !_validateDraft()) return;
      if (saveEdits && _recoveryBaselineUnavailable) {
        _showRecoveryBaselineReview();
        return;
      }
    }
    setState(() {
      _pendingMoveDestinationId = destination.id;
      _saving = true;
    });
    final result = AndroidTaskEditorResult(
      action: AndroidTaskEditorAction.moved,
      accountId: widget.accountId,
      taskListId: destination.id,
      taskId: (_observedTask?.id ?? widget.task!.id),
      previousTaskListId: _draft.taskListId,
    );
    widget.onMutationStarted?.call(result);
    var mutationPersisted = false;
    var patchPersisted = false;
    try {
      final repository = ref.read(
        tasksRepositoryForAccountProvider(widget.accountId),
      );
      if (saveEdits) {
        await _persistTaskDraft();
        patchPersisted = true;
        await _persistRecovery();
      }
      await repository.moveTask(
        TaskMoveInput(
          sourceTaskListId: _draft.taskListId,
          destinationTaskListId: destination.id,
          taskId: (_observedTask?.id ?? widget.task!.id),
        ),
      );
      mutationPersisted = true;
      final committedResult = AndroidTaskEditorResult(
        action: result.action,
        accountId: result.accountId,
        taskListId: result.taskListId,
        taskId: _observedTask?.id ?? result.taskId,
        previousTaskListId: result.previousTaskListId,
      );
      widget.onMutationCommitted?.call(committedResult);
      await _clearRecovery(finalCleanup: true);
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.pop(context, committedResult);
    } on Object catch (error) {
      if (!mutationPersisted) widget.onMutationFailed?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              patchPersisted
                  ? context.l10n.taskMoveAfterSaveFailed
                  : _taskMutationError(error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _moveToTop() async {
    if (!_canWrite) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .moveTask(
            TaskMoveInput(
              sourceTaskListId: _draft.taskListId,
              taskId: (_observedTask?.id ?? widget.task!.id),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.moveToTop)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadTaskAttachment() async {
    final task = widget.task;
    if (task == null ||
        task.pendingDelete ||
        task.id.startsWith('local-task-')) {
      return;
    }
    final document = await BusyMaxAndroidPlatform.instance.openDocument(
      mimeTypes: const ['*/*'],
      maximumBytes: 25 * 1024 * 1024,
    );
    if (document == null || !mounted) return;
    final name = safeAttachmentFileName(document.name ?? '');
    if (name == null) {
      _attachmentError(const FormatException('Invalid attachment name.'));
      return;
    }
    setState(() => _attachmentBusy = true);
    try {
      final client = ref.read(
        microsoftTodoApiClientForAccountProvider(widget.accountId),
      );
      if (client is! MicrosoftTodoAttachmentsApiClient) {
        throw StateError('Microsoft task attachments are unavailable.');
      }
      await ref
          .read(attachmentUploadCoordinatorProvider)
          .uploadTask(
            client: client as MicrosoftTodoAttachmentsApiClient,
            accountId: widget.accountId,
            taskListId: task.taskListId,
            taskId: task.id,
            name: name,
            contentType: document.mimeType ?? 'application/octet-stream',
            bytes: document.bytes,
          );
      _reloadTaskAttachments();
    } on Object catch (error) {
      _reloadTaskAttachments();
      _attachmentError(error);
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<void> _reconcileTaskUpload() async {
    final task = widget.task;
    if (task == null) return;
    setState(() => _attachmentBusy = true);
    try {
      final client = ref.read(
        microsoftTodoApiClientForAccountProvider(widget.accountId),
      );
      if (client is! MicrosoftTodoAttachmentsApiClient) return;
      await ref
          .read(attachmentUploadCoordinatorProvider)
          .reconcileTask(
            client: client as MicrosoftTodoAttachmentsApiClient,
            accountId: widget.accountId,
            taskListId: task.taskListId,
            taskId: task.id,
          );
      _reloadTaskAttachments();
    } on Object catch (error) {
      _attachmentError(error);
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<void> _cancelTaskUpload() async {
    final task = widget.task;
    if (task == null) return;
    setState(() => _attachmentBusy = true);
    try {
      final client = ref.read(
        microsoftTodoApiClientForAccountProvider(widget.accountId),
      );
      if (client is! MicrosoftTodoAttachmentsApiClient) return;
      await ref
          .read(attachmentUploadCoordinatorProvider)
          .cancelTask(
            client: client as MicrosoftTodoAttachmentsApiClient,
            accountId: widget.accountId,
            taskListId: task.taskListId,
            taskId: task.id,
          );
      _reloadTaskAttachments();
    } on Object catch (error) {
      _attachmentError(error);
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  Future<void> _resolveTaskUpload({required bool exists}) async {
    final task = widget.task;
    if (task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(exists ? context.l10n.completed : context.l10n.retry),
        content: Text(context.l10n.attachmentUploadUnresolved),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(exists ? context.l10n.completed : context.l10n.retry),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(attachmentUploadCoordinatorProvider)
        .resolveUncertainManually(
          AttachmentUploadCoordinator.taskKey(
            widget.accountId,
            task.taskListId,
            task.id,
          ),
          exists: exists,
        );
    _reloadTaskAttachments();
  }

  Future<void> _deleteTaskAttachment(
    MicrosoftTodoAttachmentDto attachment,
  ) async {
    final task = widget.task;
    if (task == null ||
        task.pendingDelete ||
        task.id.startsWith('local-task-')) {
      return;
    }
    setState(() => _attachmentBusy = true);
    try {
      final client = ref.read(
        microsoftTodoApiClientForAccountProvider(widget.accountId),
      );
      if (client is! MicrosoftTodoAttachmentsApiClient) {
        throw StateError('Microsoft task attachments are unavailable.');
      }
      await (client as MicrosoftTodoAttachmentsApiClient).deleteTaskAttachment(
        taskListId: task.taskListId,
        taskId: task.id,
        attachmentId: attachment.id,
      );
      ref
          .read(attachmentUploadCoordinatorProvider)
          .attachmentRemoved(
            AttachmentUploadCoordinator.taskKey(
              widget.accountId,
              task.taskListId,
              task.id,
            ),
            attachment.id,
          );
      _reloadTaskAttachments();
    } on Object catch (error) {
      _attachmentError(error);
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  void _reloadTaskAttachments() {
    final task = widget.task;
    if (task == null) return;
    final key = (
      accountId: widget.accountId,
      taskListId: task.taskListId,
      taskId: task.id,
    );
    ref.invalidate(microsoftTaskAttachmentsProvider(key));
    final future = ref.read(microsoftTaskAttachmentsProvider(key).future);
    if (mounted) {
      setState(() {
        _attachmentsFuture = future;
      });
    }
  }

  void _attachmentError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.exportFailed('$error'))),
    );
  }

  Future<void> _downloadTaskAttachment(
    MicrosoftTodoAttachmentDto attachment,
  ) async {
    final task = widget.task;
    final name = safeAttachmentFileName(attachment.name);
    if (task == null || !attachment.isFile || name == null) return;
    try {
      final client = ref.read(
        microsoftTodoApiClientForAccountProvider(widget.accountId),
      );
      if (client is! MicrosoftTodoAttachmentsApiClient) {
        throw StateError('Microsoft task attachments are unavailable.');
      }
      final bytes = await (client as MicrosoftTodoAttachmentsApiClient)
          .downloadTaskAttachment(
            taskListId: task.taskListId,
            taskId: task.id,
            attachmentId: attachment.id,
          );
      await BusyMaxAndroidPlatform.instance.createDocument(
        suggestedName: name,
        mimeType: attachment.contentType ?? 'application/octet-stream',
        bytes: Uint8List.fromList(bytes),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed('$error'))),
        );
      }
    }
  }

  Future<void> _export() async {
    try {
      final raw = await ref
          .read(tasksRepositoryForAccountProvider(widget.accountId))
          .nativeTaskExport(
            _draft.taskListId,
            (_observedTask?.id ?? widget.task!.id),
          );
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
    if (_saving) return;
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
      final storage = ref.read(secureStorageProvider);
      String? raw;
      final keys = <String>{_recoveryKey};
      final task = widget.task;
      if (task != null) {
        for (final identity in task.identityIds) {
          keys.add('busymax.android.task-draft.${widget.accountId}.$identity');
        }
      }
      for (final key in keys) {
        raw = await storage.read(key: key);
        if (raw != null) {
          _recoverySourceKey = key;
          break;
        }
      }
      if (raw == null) return;
      final value = jsonDecode(raw);
      if (value is! Map) return;
      final map = value.cast<String, Object?>();
      final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
      if (savedAt == null ||
          DateTime.now().difference(savedAt).abs() > const Duration(days: 14) ||
          map['v'] != 2 ||
          map['accountId'] != widget.accountId ||
          (widget.task == null &&
              map['taskListId'] != _initialDraft.taskListId) ||
          (widget.task != null &&
              map['taskId'] != null &&
              !widget.task!.matchesIdentity(map['taskId'].toString()))) {
        await _clearRecovery();
        return;
      }
      TaskEntity? recoveredObserved;
      final rawObserved = map['observedTask'];
      _recoveryBaselineUnavailable = widget.task != null && rawObserved is! Map;
      _recoveryOriginalBaseTitle = map['baseTitle'] as String?;
      if (widget.task != null && rawObserved is Map) {
        recoveredObserved = TaskEntity.fromDraftBaselineJson(
          rawObserved.cast<String, Object?>(),
        );
        if (recoveredObserved.accountId != widget.accountId ||
            !widget.task!.matchesIdentity(recoveredObserved.id)) {
          await _clearRecovery();
          return;
        }
      }
      final rawComparison = map['originalObservedTask'];
      _recoveryComparisonTask = rawComparison is Map
          ? TaskEntity.fromDraftBaselineJson(
              rawComparison.cast<String, Object?>(),
            )
          : recoveredObserved;
      final currentValues = _recoveryValues(_draft);
      final baselineValues = recoveredObserved == null
          ? {...currentValues, 'title': map['baseTitle']}
          : _recoveryValues(
              TaskDetailsDraft.fromTask(
                recoveredObserved,
                ref.read(localTimeZoneProvider),
              ),
            );
      final restoredValues = <String, Object?>{...currentValues};
      for (final key in currentValues.keys) {
        if (map.containsKey(key) &&
            jsonEncode(map[key]) != jsonEncode(baselineValues[key])) {
          restoredValues[key] = map[key];
        }
      }
      if (recoveredObserved != null && widget.task != null) {
        final original = recoveredObserved.toDraftBaselineJson();
        final composed = widget.task!.toDraftBaselineJson();
        for (final field in ['rawJson', 'etag', 'updatedUtc']) {
          composed[field] = original[field];
        }
        const groups = <String, List<String>>{
          'title': ['title'],
          'notes': ['notes', 'bodyContent', 'bodyContentType'],
          'dueDate': ['dueUtc', 'microsoftDueDateTime', 'microsoftDueTimeZone'],
          'dueTime': ['dueUtc', 'microsoftDueDateTime', 'microsoftDueTimeZone'],
          'dueTimeZone': [
            'dueUtc',
            'microsoftDueDateTime',
            'microsoftDueTimeZone',
          ],
          'startDate': ['microsoftStartDateTime', 'microsoftStartTimeZone'],
          'startTime': ['microsoftStartDateTime', 'microsoftStartTimeZone'],
          'startTimeZone': ['microsoftStartDateTime', 'microsoftStartTimeZone'],
          'reminderEnabled': [
            'microsoftIsReminderOn',
            'microsoftReminderDateTime',
            'microsoftReminderTimeZone',
          ],
          'reminderDate': [
            'microsoftIsReminderOn',
            'microsoftReminderDateTime',
            'microsoftReminderTimeZone',
          ],
          'reminderTime': [
            'microsoftIsReminderOn',
            'microsoftReminderDateTime',
            'microsoftReminderTimeZone',
          ],
          'reminderTimeZone': [
            'microsoftIsReminderOn',
            'microsoftReminderDateTime',
            'microsoftReminderTimeZone',
          ],
          'recurrenceJson': ['recurrenceJson'],
          'importance': ['importance'],
          'categories': ['categoriesJson'],
          'icalPriority': ['icalPriority'],
          'percentComplete': [
            'percentComplete',
            'providerStatus',
            'status',
            'completedUtc',
          ],
          'taskStatus': [
            'percentComplete',
            'providerStatus',
            'status',
            'completedUtc',
          ],
          'completedDate': [
            'percentComplete',
            'providerStatus',
            'status',
            'completedUtc',
          ],
          'completedTime': [
            'percentComplete',
            'providerStatus',
            'status',
            'completedUtc',
          ],
          'location': ['taskLocation', 'locationLatitude', 'locationLongitude'],
          'taskUrl': ['taskUrl'],
          'classification': ['taskClassification'],
          'pinned': ['taskPinned'],
          'hideSubtasks': ['taskHideSubtasks'],
          'hideCompletedSubtasks': ['taskHideCompletedSubtasks'],
          'alarms': ['taskAlarmsJson'],
        };
        for (final entry in groups.entries) {
          if (map.containsKey(entry.key) &&
              jsonEncode(map[entry.key]) !=
                  jsonEncode(baselineValues[entry.key])) {
            for (final field in entry.value) {
              composed[field] = original[field];
            }
          }
        }
        recoveredObserved = TaskEntity.fromDraftBaselineJson(composed);
      }
      _recoveredConcurrentState =
          widget.task != null &&
          (map['baseTitle'] != _initialDraft.title ||
              map['taskListId'] != _initialDraft.taskListId ||
              (recoveredObserved != null &&
                  jsonEncode(baselineValues) != jsonEncode(currentValues)));
      final values = widget.task == null ? map : restoredValues;
      final alarms = <IcalTaskAlarm>[];
      for (final rawAlarm in values['alarms'] as List? ?? const []) {
        if (rawAlarm is Map) {
          alarms.add(IcalTaskAlarm.fromJson(rawAlarm.cast<String, Object?>()));
        }
      }
      var recovered = _draft.copyWith(
        observedTask: recoveredObserved ?? _observedTask,
        title: values['title']?.toString() ?? _draft.title,
        notes: values['notes']?.toString() ?? _draft.notes,
        dueDate: values['dueDate'],
        microsoftDueTime: values['dueTime'],
        microsoftDueTimeZone: values['dueTimeZone']?.toString(),
        microsoftStartDate: values['startDate'],
        microsoftStartTime: values['startTime'],
        microsoftStartTimeZone: values['startTimeZone']?.toString(),
        microsoftReminderEnabled:
            values['reminderEnabled'] as bool? ??
            _draft.microsoftReminderEnabled,
        microsoftReminderDate: values['reminderDate'],
        microsoftReminderTime: values['reminderTime'],
        microsoftReminderTimeZone: values['reminderTimeZone']?.toString(),
        recurrenceJson: values['recurrenceJson'],
        importance: values['importance']?.toString(),
        categories: (values['categories'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        icalPriority: values['icalPriority'] as int?,
        percentComplete: values['percentComplete'] as int?,
        taskStatus: values['taskStatus'],
        completedDate: values['completedDate'],
        completedTime: values['completedTime'],
        location: values['location']?.toString(),
        taskUrl: values['taskUrl']?.toString(),
        classification: values['classification']?.toString(),
        pinned: values['pinned'] as bool?,
        hideSubtasks: values['hideSubtasks'] as bool?,
        hideCompletedSubtasks: values['hideCompletedSubtasks'] as bool?,
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
          content: Text(
            _recoveredConcurrentState
                ? context.l10n.taskDraftConflict
                : context.l10n.discardChangesConfirmation,
          ),
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
        _observedTask = recoveredObserved ?? _observedTask;
        _pendingMoveDestinationId = map['pendingMoveDestinationId'] as String?;
        if (_pendingMoveDestinationId == recovered.taskListId) {
          _pendingMoveDestinationId = null;
        }
        _draft = recovered;
        _recurrenceFrequency =
            creationRule?.frequency ?? _taskRecurrence().frequency;
        _syncControllersFromDraft();
      });
    } on Object {
      // A malformed/locked recovery entry must never block the editor.
    } finally {
      if (mounted) {
        setState(() => _recoveryLoaded = true);
      } else {
        _recoveryLoaded = true;
      }
    }
  }

  Map<String, Object?> _recoveryValues(TaskDetailsDraft draft) => {
    'title': draft.title,
    'notes': draft.notes,
    'dueDate': draft.dueDate,
    'dueTime': draft.microsoftDueTime,
    'dueTimeZone': draft.microsoftDueTimeZone,
    'startDate': draft.microsoftStartDate,
    'startTime': draft.microsoftStartTime,
    'startTimeZone': draft.microsoftStartTimeZone,
    'reminderEnabled': draft.microsoftReminderEnabled,
    'reminderDate': draft.microsoftReminderDate,
    'reminderTime': draft.microsoftReminderTime,
    'reminderTimeZone': draft.microsoftReminderTimeZone,
    'recurrenceJson': draft.recurrenceJson,
    'importance': draft.importance,
    'categories': draft.categories,
    'icalPriority': draft.icalPriority,
    'percentComplete': draft.percentComplete,
    'taskStatus': draft.taskStatus,
    'completedDate': draft.completedDate,
    'completedTime': draft.completedTime,
    'location': draft.location,
    'taskUrl': draft.taskUrl,
    'classification': draft.classification,
    'pinned': draft.pinned,
    'hideSubtasks': draft.hideSubtasks,
    'hideCompletedSubtasks': draft.hideCompletedSubtasks,
    'alarms': [for (final alarm in draft.alarms) alarm.toJson()],
  };

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
      'baseTitle': _recoveryBaselineUnavailable
          ? _recoveryOriginalBaseTitle ?? _initialDraft.title
          : _observedTask?.title ?? _initialDraft.title,
      'accountId': widget.accountId,
      'taskListId': _draft.taskListId,
      if (_pendingMoveDestinationId != null)
        'pendingMoveDestinationId': _pendingMoveDestinationId,
      ..._recoveryValues(_draft),
      if (creationRecurrence != null)
        'creationRecurrence': {
          'provider': creationRecurrence.provider.name,
          'rule': creationRecurrence.rule.toJsonString(),
        },
      if (_observedTask != null && !_recoveryBaselineUnavailable)
        'observedTask': _observedTask!.toDraftBaselineJson(),
      if (_recoveryComparisonTask != null)
        'originalObservedTask': _recoveryComparisonTask!.toDraftBaselineJson(),
      if (widget.task != null) 'taskId': _observedTask?.id ?? widget.task!.id,
    });
    await _enqueueRecovery(() async {
      if (_recoveryWritesBlocked) return;
      await ref
          .read(secureStorageProvider)
          .write(key: _recoveryKey, value: payload);
      if (_recoverySourceKey != null && _recoverySourceKey != _recoveryKey) {
        await ref.read(secureStorageProvider).delete(key: _recoverySourceKey!);
      }
    });
  }

  Future<void> _clearRecovery({bool finalCleanup = false}) {
    if (finalCleanup) {
      _recoveryWritesBlocked = true;
      _recoveryTimer?.cancel();
    }
    return _enqueueRecovery(() async {
      await ref.read(secureStorageProvider).delete(key: _recoveryKey);
      if (_recoverySourceKey != null && _recoverySourceKey != _recoveryKey) {
        await ref.read(secureStorageProvider).delete(key: _recoverySourceKey!);
      }
    });
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
  bool _endingChanged = false;
  late final _interval = TextEditingController(text: '${_value.interval}');
  late final _count = TextEditingController(text: '${_value.count ?? 10}');
  late DateTime _until =
      DateTime.tryParse(_value.untilDateFor(timeZone: widget.timeZone) ?? '') ??
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
                key: const ValueKey('android-task-recurrence-end'),
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
                onChanged: (value) => setState(() {
                  _endingChanged = true;
                  _end = value ?? _AndroidRecurrenceEnd.never;
                }),
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
                  key: const ValueKey('android-task-recurrence-until'),
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
    if (_end == _AndroidRecurrenceEnd.until &&
        !_endingChanged &&
        widget.initial.untilRaw != null) {
      result = result.copyWith(untilRaw: widget.initial.untilRaw);
    } else if (_end == _AndroidRecurrenceEnd.until) {
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
    if (value != null && mounted) {
      setState(() {
        _endingChanged = true;
        _until = value;
      });
    }
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

String _recurrenceLabel(BuildContext context, RecurrenceFrequency frequency) =>
    switch (frequency) {
      RecurrenceFrequency.none => context.l10n.repeatNone,
      RecurrenceFrequency.daily => context.l10n.repeatDaily,
      RecurrenceFrequency.weekly => context.l10n.repeatWeekly,
      RecurrenceFrequency.monthly => context.l10n.repeatMonthly,
      RecurrenceFrequency.yearly => context.l10n.repeatYearly,
    };
