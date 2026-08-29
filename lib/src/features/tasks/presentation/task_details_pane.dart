import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../schedule/presentation/schedule_item_exporter.dart';
import '../../sync/sync_auth_error.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../data/tasks_repository.dart';
import 'task_details_draft.dart';
import 'task_details_editor.dart';

typedef TasksRepositoryForAccount = TasksRepository Function(String accountId);
typedef TaskListsRepositoryForAccount =
    TaskListsRepository Function(String accountId);
typedef TaskMutationCommittedCallback =
    FutureOr<void> Function(String accountId);

class TaskDetailsPane extends ConsumerStatefulWidget {
  const TaskDetailsPane({
    super.key,
    required this.accountId,
    required this.taskListId,
    required this.taskId,
    this.tasksRepositoryForAccount,
    this.taskListsRepositoryForAccount,
    this.onTaskMutationCommitted,
    this.onClose,
    this.onTaskSwitchCancelled,
    this.onDirtyChanged,
    this.dialogBarrierColor,
  });

  final String accountId;
  final String taskListId;
  final String taskId;
  final TasksRepositoryForAccount? tasksRepositoryForAccount;
  final TaskListsRepositoryForAccount? taskListsRepositoryForAccount;
  final TaskMutationCommittedCallback? onTaskMutationCommitted;
  final VoidCallback? onClose;
  final ValueChanged<TaskEntity>? onTaskSwitchCancelled;
  final ValueChanged<bool>? onDirtyChanged;
  final Color? dialogBarrierColor;

  @override
  ConsumerState<TaskDetailsPane> createState() => _TaskDetailsPaneState();
}

class _TaskDetailsPaneState extends ConsumerState<TaskDetailsPane> {
  late String _effectiveAccountId;
  late String _effectiveTaskListId;
  late String _effectiveTaskId;
  TaskEntity? _lastTask;
  List<TaskListEntity> _lastTaskLists = const [];
  AccountEntity? _lastAccount;
  TaskCollectionCapabilities? _lastCapabilities;
  String? _lastLocalTimeZone;
  List<String> _lastCategorySuggestions = const [];
  TasksRepository? _taskStreamRepository;
  String? _taskStreamAccountId;
  String? _taskStreamTaskListId;
  String? _taskStreamTaskId;
  Stream<TaskEntity?>? _taskStream;
  TasksRepository? _hierarchyStreamRepository;
  String? _hierarchyStreamTaskListId;
  String? _hierarchyStreamTaskId;
  Stream<TaskHierarchySnapshot>? _hierarchyStream;
  TaskHierarchySnapshot _lastHierarchy = const TaskHierarchySnapshot(
    parent: null,
    subtasks: [],
  );
  TasksRepository? _categorySuggestionsRepository;
  Stream<List<String>>? _categorySuggestionsStream;
  TaskListsRepository? _listsStreamRepository;
  Stream<List<TaskListEntity>>? _listsStream;
  String? _customTasksRepositoryAccountId;
  TasksRepository? _customTasksRepository;
  String? _customTaskListsRepositoryAccountId;
  TaskListsRepository? _customTaskListsRepository;
  var _editorDirty = false;
  var _confirmingTaskSwitch = false;

  @override
  void initState() {
    super.initState();
    _effectiveAccountId = widget.accountId;
    _effectiveTaskListId = widget.taskListId;
    _effectiveTaskId = widget.taskId;
  }

  @override
  void didUpdateWidget(covariant TaskDetailsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId == widget.accountId &&
        oldWidget.taskListId == widget.taskListId &&
        oldWidget.taskId == widget.taskId) {
      return;
    }
    if (_matchesEffectiveSelection(
      widget.accountId,
      widget.taskListId,
      widget.taskId,
    )) {
      return;
    }

    if (_editorDirty && _lastTask != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          _confirmSelectionChange(
            accountId: widget.accountId,
            taskListId: widget.taskListId,
            taskId: widget.taskId,
          ),
        );
      });
      return;
    }

    _applyEffectiveSelection(
      accountId: widget.accountId,
      taskListId: widget.taskListId,
      taskId: widget.taskId,
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final repository = _tasksRepository(ref, _effectiveAccountId);
    final listsRepository = _taskListsRepository(ref, _effectiveAccountId);
    final localTimeZone = ref.watch(localTimeZoneProvider);
    final accounts = ref.watch(accountsStreamProvider);
    final storedAccount = _accountForId(
      accounts.valueOrNull ?? const [],
      _effectiveAccountId,
    );
    final cachedAccount = _lastAccount?.id == _effectiveAccountId
        ? _lastAccount
        : null;
    final account =
        storedAccount ??
        ((accounts.isLoading || accounts.hasError || _editorDirty)
            ? cachedAccount
            : null);
    final taskStream = _watchTask(repository);
    final hierarchyStream = _watchTaskHierarchy(repository);
    final listsStream = _watchTaskLists(listsRepository);
    final categorySuggestionsStream = _watchCategorySuggestions(repository);
    final davCollections =
        ref.watch(davCollectionsStreamProvider).valueOrNull ?? const [];

    if (account == null) {
      if (accounts.hasValue && !accounts.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onClose?.call(),
        );
      }
      return const SizedBox.shrink();
    }
    final davCapabilities = switch (account.provider) {
      BusyProvider.appleICloud || BusyProvider.nextcloud =>
        ref
            .watch(
              davTaskCollectionCapabilitiesProvider((
                accountId: _effectiveAccountId,
                taskListId: _effectiveTaskListId,
              )),
            )
            .valueOrNull,
      BusyProvider.google ||
      BusyProvider.microsoft ||
      BusyProvider.webCal => null,
    };
    final capabilities = switch (account.provider) {
      BusyProvider.appleICloud ||
      BusyProvider.nextcloud => davCapabilities ?? noTaskCollectionCapabilities,
      BusyProvider.google || BusyProvider.microsoft =>
        adapterDefaultTaskCapabilities(account.provider),
      BusyProvider.webCal => noTaskCollectionCapabilities,
    };

    return StreamBuilder<TaskEntity?>(
      stream: taskStream,
      builder: (context, taskSnapshot) {
        if (taskSnapshot.connectionState == ConnectionState.none ||
            taskSnapshot.connectionState == ConnectionState.waiting) {
          if (_editorDirty && _lastTask != null) {
            return _buildEditor(
              repository: repository,
              task: _lastTask!,
              taskLists: _lastTaskLists,
              capabilities: _lastCapabilities ?? capabilities,
              localTimeZone: _lastLocalTimeZone ?? localTimeZone,
              account: cachedAccount ?? account,
              categorySuggestions: _lastCategorySuggestions,
              hierarchy: _lastHierarchy,
            );
          }
          return const SizedBox.shrink();
        }
        final task = taskSnapshot.data;
        if (task != null &&
            (task.accountId != _effectiveAccountId ||
                task.taskListId != _effectiveTaskListId ||
                task.id != _effectiveTaskId)) {
          return const SizedBox.shrink();
        }
        if (task == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => widget.onClose?.call(),
          );
          return const SizedBox.shrink();
        }
        var effectiveCapabilities =
            task.recurrenceIdKey != null &&
                !capabilities.supportsRecurringTaskOccurrenceEditing
            ? capabilities.asReadOnly()
            : capabilities;
        if (task.davCollectionId != null) {
          final collection = davCollections
              .where((item) => item.id == task.davCollectionId)
              .firstOrNull;
          if (collection?.shared ?? false) {
            final classification =
                task.taskClassification?.trim().toUpperCase() ?? 'PUBLIC';
            effectiveCapabilities = classification == 'PUBLIC'
                ? effectiveCapabilities.withoutClassificationEditing()
                : effectiveCapabilities.asReadOnly();
          }
        }

        return StreamBuilder<TaskHierarchySnapshot>(
          stream: hierarchyStream,
          initialData: _lastHierarchy,
          builder: (context, hierarchySnapshot) {
            final hierarchy = hierarchySnapshot.data ?? _lastHierarchy;
            return StreamBuilder<List<TaskListEntity>>(
              stream: listsStream,
              builder: (context, listsSnapshot) {
                final taskLists =
                    listsSnapshot.data ?? const <TaskListEntity>[];
                return StreamBuilder<List<String>>(
                  stream: categorySuggestionsStream,
                  builder: (context, categorySnapshot) {
                    final categorySuggestions =
                        categorySnapshot.data ?? _lastCategorySuggestions;
                    _lastTask = task;
                    _lastTaskLists = taskLists;
                    _lastAccount = account;
                    _lastCapabilities = effectiveCapabilities;
                    _lastLocalTimeZone = localTimeZone;
                    _lastCategorySuggestions = categorySuggestions;
                    _lastHierarchy = hierarchy;
                    return _buildEditor(
                      repository: repository,
                      task: task,
                      taskLists: taskLists,
                      capabilities: effectiveCapabilities,
                      localTimeZone: localTimeZone,
                      account: account,
                      categorySuggestions: categorySuggestions,
                      hierarchy: hierarchy,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _refreshTask(TasksRepository repository, TaskEntity task) async {
    try {
      await repository.refreshTask(task.taskListId, task.id);
    } on Object catch (error) {
      if (isMissingOAuthTokenError(error)) {
        try {
          await ref
              .read(authRepositoryProvider)
              .markReconnectRequired(task.accountId);
        } on Object {
          // Keep the original refresh failure visible below.
        }
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.refreshFailed(
              syncFailureMessage(
                error,
                networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _saveDraft(
    TasksRepository repository,
    TaskEntity task,
    TaskDetailsDraft draft,
    Map<String, Object?> patch,
  ) async {
    var mutated = false;
    if (patch.isNotEmpty) {
      await repository.patchTask(
        task.taskListId,
        task.id,
        TaskPatchInput(patch),
      );
      mutated = true;
    }
    if (draft.taskListId != task.taskListId) {
      await repository.moveTask(
        TaskMoveInput(
          sourceTaskListId: task.taskListId,
          taskId: task.id,
          destinationTaskListId: draft.taskListId,
        ),
      );
      mutated = true;
    }
    if (mutated) {
      await widget.onTaskMutationCommitted?.call(task.accountId);
    }
  }

  Widget _buildEditor({
    required TasksRepository repository,
    required TaskEntity task,
    required List<TaskListEntity> taskLists,
    required TaskCollectionCapabilities capabilities,
    required String localTimeZone,
    required AccountEntity account,
    required List<String> categorySuggestions,
    required TaskHierarchySnapshot hierarchy,
  }) {
    return TaskDetailsEditor(
      task: task,
      taskLists: taskLists,
      capabilities: capabilities,
      localTimeZone: localTimeZone,
      categorySuggestions: categorySuggestions,
      accountLabel: _accountEditorLabel(context, account),
      onRefresh: () {
        unawaited(_refreshTask(repository, task));
      },
      onSave: (draft, patch) => _saveDraft(repository, task, draft, patch),
      hierarchy: hierarchy,
      onCreateSubtask: (title) => _createSubtask(repository, task, title),
      onHierarchyTaskSelected: (selectedTask) =>
          _selectHierarchyTask(selectedTask),
      onSubtaskCompletionChanged: (subtask, completed) =>
          _setSubtaskCompleted(repository, task, subtask, completed),
      onChecklistSubtaskRenamed: (subtask, title) =>
          _renameChecklistSubtask(repository, task, subtask, title),
      onChecklistSubtaskDeleted: (subtask) =>
          _deleteChecklistSubtask(repository, task, subtask),
      onMoveToTop: () {
        unawaited(_moveToTop(repository, task));
      },
      onDuplicate: () => _duplicateTask(repository, task),
      onExport: () => _exportTask(repository, task),
      onDelete: () async {
        await repository.deleteTask(task.taskListId, task.id);
        await widget.onTaskMutationCommitted?.call(task.accountId);
        widget.onClose?.call();
      },
      onCancel: () => widget.onClose?.call(),
      onSaved: () => widget.onClose?.call(),
      onTaskSwitchCancelled: widget.onTaskSwitchCancelled,
      onDirtyChanged: _setEditorDirty,
      dialogBarrierColor: widget.dialogBarrierColor,
      headerBarService: ref.read(linuxHeaderBarServiceProvider),
    );
  }

  Future<void> _createSubtask(
    TasksRepository repository,
    TaskEntity task,
    String title,
  ) async {
    try {
      await repository.createSubtask(
        taskListId: task.taskListId,
        parentTaskId: task.id,
        title: title,
      );
      await widget.onTaskMutationCommitted?.call(task.accountId);
    } on Object catch (error) {
      _showTaskMutationError(error);
    }
  }

  Future<void> _selectHierarchyTask(TaskEntity task) {
    return _confirmSelectionChange(
      accountId: task.accountId,
      taskListId: task.taskListId,
      taskId: task.id,
    );
  }

  Future<void> _setSubtaskCompleted(
    TasksRepository repository,
    TaskEntity parent,
    TaskSubtaskEntity subtask,
    bool completed,
  ) async {
    try {
      if (subtask.kind == TaskSubtaskKind.task) {
        final task = subtask.task!;
        await repository.patchTask(
          task.taskListId,
          task.id,
          TaskPatchInput({
            'status': completed ? 'completed' : 'needsAction',
            'completed': completed
                ? DateTime.now().toUtc().toIso8601String()
                : null,
          }),
        );
      } else {
        await repository.patchChecklistSubtask(
          taskListId: parent.taskListId,
          parentTaskId: parent.id,
          checklistItemId: subtask.id,
          completed: completed,
        );
      }
      await widget.onTaskMutationCommitted?.call(parent.accountId);
    } on Object catch (error) {
      _showTaskMutationError(error);
    }
  }

  Future<void> _renameChecklistSubtask(
    TasksRepository repository,
    TaskEntity parent,
    TaskSubtaskEntity subtask,
    String title,
  ) async {
    try {
      await repository.patchChecklistSubtask(
        taskListId: parent.taskListId,
        parentTaskId: parent.id,
        checklistItemId: subtask.id,
        title: title,
      );
      await widget.onTaskMutationCommitted?.call(parent.accountId);
    } on Object catch (error) {
      _showTaskMutationError(error);
    }
  }

  Future<void> _deleteChecklistSubtask(
    TasksRepository repository,
    TaskEntity parent,
    TaskSubtaskEntity subtask,
  ) async {
    try {
      await repository.deleteChecklistSubtask(
        taskListId: parent.taskListId,
        parentTaskId: parent.id,
        checklistItemId: subtask.id,
      );
      await widget.onTaskMutationCommitted?.call(parent.accountId);
    } on Object catch (error) {
      _showTaskMutationError(error);
    }
  }

  void _showTaskMutationError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.syncFailed(
            syncFailureMessage(
              error,
              networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _moveToTop(TasksRepository repository, TaskEntity task) async {
    await repository.moveTask(
      TaskMoveInput(sourceTaskListId: task.taskListId, taskId: task.id),
    );
    await widget.onTaskMutationCommitted?.call(task.accountId);
  }

  Future<void> _duplicateTask(
    TasksRepository repository,
    TaskEntity task,
  ) async {
    try {
      await repository.duplicateTask(task.taskListId, task.id);
      await widget.onTaskMutationCommitted?.call(task.accountId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.taskDuplicated)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.taskDuplicateFailed(
              syncFailureMessage(
                error,
                networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _exportTask(TasksRepository repository, TaskEntity task) async {
    try {
      final raw = await repository.nativeTaskExport(task.taskListId, task.id);
      if (raw == null) {
        throw StateError('The native iCalendar task data is unavailable.');
      }
      final file = await exportICalendarWithSaveDialog(
        suggestedName: taskExportFileName(
          title: task.title,
          dueDate: task.dueUtc,
        ),
        calendarData: raw,
      );
      if (file == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.exportedFile(file.path))),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.exportFailed(
              syncFailureMessage(
                error,
                networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
              ),
            ),
          ),
        ),
      );
    }
  }

  void _setEditorDirty(bool dirty) {
    if (!mounted) {
      return;
    }
    _editorDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
  }

  bool _matchesEffectiveSelection(
    String accountId,
    String taskListId,
    String taskId,
  ) {
    return _effectiveAccountId == accountId &&
        _effectiveTaskListId == taskListId &&
        _effectiveTaskId == taskId;
  }

  void _applyEffectiveSelection({
    required String accountId,
    required String taskListId,
    required String taskId,
  }) {
    _effectiveAccountId = accountId;
    _effectiveTaskListId = taskListId;
    _effectiveTaskId = taskId;
    _lastHierarchy = const TaskHierarchySnapshot(parent: null, subtasks: []);
  }

  TasksRepository _tasksRepository(WidgetRef ref, String accountId) {
    final factory = widget.tasksRepositoryForAccount;
    if (factory == null) {
      return ref.watch(tasksRepositoryForAccountProvider(accountId));
    }
    if (_customTasksRepository == null ||
        _customTasksRepositoryAccountId != accountId) {
      _customTasksRepositoryAccountId = accountId;
      _customTasksRepository = factory(accountId);
    }
    return _customTasksRepository!;
  }

  TaskListsRepository _taskListsRepository(WidgetRef ref, String accountId) {
    final factory = widget.taskListsRepositoryForAccount;
    if (factory == null) {
      return ref.watch(taskListsRepositoryForAccountProvider(accountId));
    }
    if (_customTaskListsRepository == null ||
        _customTaskListsRepositoryAccountId != accountId) {
      _customTaskListsRepositoryAccountId = accountId;
      _customTaskListsRepository = factory(accountId);
    }
    return _customTaskListsRepository!;
  }

  Future<void> _confirmSelectionChange({
    required String accountId,
    required String taskListId,
    required String taskId,
  }) async {
    if (_confirmingTaskSwitch ||
        _matchesEffectiveSelection(accountId, taskListId, taskId)) {
      return;
    }
    if (!_editorDirty) {
      setState(() {
        _applyEffectiveSelection(
          accountId: accountId,
          taskListId: taskListId,
          taskId: taskId,
        );
      });
      return;
    }
    _confirmingTaskSwitch = true;
    final previousTask = _lastTask;
    final discard = await showBusyMaxConfirm(
      context,
      title: context.l10n.discardChanges,
      message: context.l10n.discardChangesConfirmation,
      confirmLabel: context.l10n.discardChangesAction,
      destructive: true,
    );
    if (!mounted) {
      return;
    }
    _confirmingTaskSwitch = false;
    if (discard) {
      setState(() {
        _editorDirty = false;
        _applyEffectiveSelection(
          accountId: accountId,
          taskListId: taskListId,
          taskId: taskId,
        );
      });
    } else if (previousTask != null) {
      widget.onTaskSwitchCancelled?.call(previousTask);
    }
  }

  Stream<TaskEntity?> _watchTask(TasksRepository repository) {
    if (!identical(_taskStreamRepository, repository) ||
        _taskStreamAccountId != _effectiveAccountId ||
        _taskStreamTaskListId != _effectiveTaskListId ||
        _taskStreamTaskId != _effectiveTaskId ||
        _taskStream == null) {
      _taskStreamRepository = repository;
      _taskStreamAccountId = _effectiveAccountId;
      _taskStreamTaskListId = _effectiveTaskListId;
      _taskStreamTaskId = _effectiveTaskId;
      _taskStream = repository
          .watchTask(_effectiveTaskListId, _effectiveTaskId)
          .asBroadcastStream();
    }
    return _taskStream!;
  }

  Stream<TaskHierarchySnapshot> _watchTaskHierarchy(
    TasksRepository repository,
  ) {
    if (!identical(_hierarchyStreamRepository, repository) ||
        _hierarchyStreamTaskListId != _effectiveTaskListId ||
        _hierarchyStreamTaskId != _effectiveTaskId ||
        _hierarchyStream == null) {
      _hierarchyStreamRepository = repository;
      _hierarchyStreamTaskListId = _effectiveTaskListId;
      _hierarchyStreamTaskId = _effectiveTaskId;
      _hierarchyStream = repository
          .watchTaskHierarchy(_effectiveTaskListId, _effectiveTaskId)
          .asBroadcastStream();
    }
    return _hierarchyStream!;
  }

  Stream<List<TaskListEntity>> _watchTaskLists(
    TaskListsRepository listsRepository,
  ) {
    if (!identical(_listsStreamRepository, listsRepository) ||
        _listsStream == null) {
      _listsStreamRepository = listsRepository;
      _listsStream = listsRepository.watchTaskLists().asBroadcastStream();
    }
    return _listsStream!;
  }

  Stream<List<String>> _watchCategorySuggestions(TasksRepository repository) {
    if (!identical(_categorySuggestionsRepository, repository) ||
        _categorySuggestionsStream == null) {
      _categorySuggestionsRepository = repository;
      _categorySuggestionsStream = repository
          .watchCategorySuggestions()
          .asBroadcastStream();
    }
    return _categorySuggestionsStream!;
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context, ref);
  }
}

AccountEntity? _accountForId(List<AccountEntity> accounts, String accountId) {
  for (final account in accounts) {
    if (account.id == accountId) {
      return account;
    }
  }
  return null;
}

String _accountEditorLabel(BuildContext context, AccountEntity account) {
  final metadata = _accountMetadata(account);
  final email = _firstDisplayIdentity([
    account.email,
    metadata['email'],
    metadata['mail'],
    metadata['userPrincipalName'],
  ]);
  if (email != null) {
    return email;
  }

  final providerAccountId = account.providerAccountId.trim();
  if (providerAccountId.isNotEmpty && providerAccountId.contains('@')) {
    return providerAccountId;
  }

  final name = _firstDisplayIdentity([
    account.displayName,
    metadata['displayName'],
    metadata['name'],
  ]);
  if (name != null && name != account.provider.displayName.trim()) {
    return name;
  }

  return _providerEditorLabel(context, account.provider);
}

String _providerEditorLabel(BuildContext context, BusyProvider provider) {
  final l10n = context.l10n;
  return switch (provider) {
    BusyProvider.google => l10n.googleTasksProvider,
    BusyProvider.microsoft => l10n.microsoftTodoProvider,
    BusyProvider.appleICloud => 'Apple iCloud',
    BusyProvider.nextcloud => 'Nextcloud Tasks',
    BusyProvider.webCal => 'WebCal',
  };
}

Map<String, String> _accountMetadata(AccountEntity account) {
  final jsonText = account.providerMetadataJson;
  if (jsonText == null || jsonText.trim().isEmpty) {
    return const {};
  }
  try {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      return const {};
    }
    return {
      for (final entry in decoded.entries)
        if (entry.key is String &&
            entry.value is String &&
            (entry.value as String).trim().isNotEmpty)
          entry.key as String: (entry.value as String).trim(),
    };
  } on FormatException {
    return const {};
  }
}

String? _firstDisplayIdentity(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      continue;
    }
    if (trimmed.startsWith('google-') || trimmed.startsWith('microsoft-')) {
      continue;
    }
    return trimmed;
  }
  return null;
}
