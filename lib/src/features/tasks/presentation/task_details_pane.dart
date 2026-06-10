import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';
import '../../../task_providers/task_provider.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../data/tasks_repository.dart';
import 'task_details_draft.dart';
import 'task_details_editor.dart';

class TaskDetailsPane extends ConsumerStatefulWidget {
  const TaskDetailsPane({
    super.key,
    required this.accountId,
    required this.taskListId,
    required this.taskId,
    this.onClose,
    this.onTaskSwitchCancelled,
    this.onDirtyChanged,
  });

  final String accountId;
  final String taskListId;
  final String taskId;
  final VoidCallback? onClose;
  final ValueChanged<TaskEntity>? onTaskSwitchCancelled;
  final ValueChanged<bool>? onDirtyChanged;

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
  TaskProviderCapabilities? _lastCapabilities;
  String? _lastLocalTimeZone;
  TasksRepository? _taskStreamRepository;
  String? _taskStreamAccountId;
  String? _taskStreamTaskListId;
  String? _taskStreamTaskId;
  Stream<TaskEntity?>? _taskStream;
  TaskListsRepository? _listsStreamRepository;
  Stream<List<TaskListEntity>>? _listsStream;
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
    final repository = ref.watch(
      tasksRepositoryForAccountProvider(_effectiveAccountId),
    );
    final listsRepository = ref.watch(
      taskListsRepositoryForAccountProvider(_effectiveAccountId),
    );
    final localTimeZone = ref.watch(localTimeZoneProvider);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final account = _accountForId(accounts, _effectiveAccountId);
    final provider =
        account?.provider ?? _providerForAccountId(_effectiveAccountId);
    final capabilities = capabilitiesForProvider(provider);
    final taskStream = _watchTask(repository);
    final listsStream = _watchTaskLists(listsRepository);

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
              account: _lastAccount,
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

        return StreamBuilder<List<TaskListEntity>>(
          stream: listsStream,
          builder: (context, listsSnapshot) {
            final taskLists = listsSnapshot.data ?? const <TaskListEntity>[];
            _lastTask = task;
            _lastTaskLists = taskLists;
            _lastAccount = account;
            _lastCapabilities = capabilities;
            _lastLocalTimeZone = localTimeZone;
            return _buildEditor(
              repository: repository,
              task: task,
              taskLists: taskLists,
              capabilities: capabilities,
              localTimeZone: localTimeZone,
              account: account,
            );
          },
        );
      },
    );
  }

  Future<void> _saveDraft(
    TasksRepository repository,
    TaskEntity task,
    TaskDetailsDraft draft,
    Map<String, Object?> patch,
  ) async {
    if (patch.isNotEmpty) {
      await repository.patchTask(
        task.taskListId,
        task.id,
        TaskPatchInput(patch),
      );
    }
    if (draft.taskListId != task.taskListId) {
      await repository.moveTask(
        TaskMoveInput(
          sourceTaskListId: task.taskListId,
          taskId: task.id,
          destinationTaskListId: draft.taskListId,
        ),
      );
    }
  }

  Widget _buildEditor({
    required TasksRepository repository,
    required TaskEntity task,
    required List<TaskListEntity> taskLists,
    required TaskProviderCapabilities capabilities,
    required String localTimeZone,
    required AccountEntity? account,
  }) {
    return TaskDetailsEditor(
      task: task,
      taskLists: taskLists,
      capabilities: capabilities,
      localTimeZone: localTimeZone,
      accountLabel: _accountEditorLabel(
        context,
        account,
        account?.provider ?? _providerForAccountId(_effectiveAccountId),
      ),
      onRefresh: () {
        unawaited(repository.refreshTask(task.taskListId, task.id));
      },
      onSave: (draft, patch) => _saveDraft(repository, task, draft, patch),
      onCreateSubtask: (title) {
        unawaited(
          repository.createTask(
            task.taskListId,
            TaskCreateInput(title: title, parentTaskId: task.id),
          ),
        );
      },
      onMoveToTop: () {
        unawaited(
          repository.moveTask(
            TaskMoveInput(sourceTaskListId: task.taskListId, taskId: task.id),
          ),
        );
      },
      onDelete: () async {
        await repository.deleteTask(task.taskListId, task.id);
        widget.onClose?.call();
      },
      onCancel: () => widget.onClose?.call(),
      onSaved: () => widget.onClose?.call(),
      onTaskSwitchCancelled: widget.onTaskSwitchCancelled,
      onDirtyChanged: _setEditorDirty,
    );
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
    _confirmingTaskSwitch = true;
    final previousTask = _lastTask;
    final discard = await showBusyMaxConfirm(
      context,
      title: context.l10n.discardChanges,
      message: context.l10n.discardChangesConfirmation,
      confirmLabel: context.l10n.discard,
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

TaskProvider _providerForAccountId(String accountId) {
  return accountId.startsWith('microsoft:')
      ? TaskProvider.microsoft
      : TaskProvider.google;
}

String _accountEditorLabel(
  BuildContext context,
  AccountEntity? account,
  TaskProvider provider,
) {
  if (account == null) {
    return _providerEditorLabel(context, provider);
  }

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

  final providerAccountId = account.providerAccountId?.trim();
  if (providerAccountId != null &&
      providerAccountId.isNotEmpty &&
      providerAccountId.contains('@')) {
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

String _providerEditorLabel(BuildContext context, TaskProvider provider) {
  final l10n = context.l10n;
  return switch (provider) {
    TaskProvider.google => l10n.googleTasksProvider,
    TaskProvider.microsoft => l10n.microsoftTodoProvider,
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
