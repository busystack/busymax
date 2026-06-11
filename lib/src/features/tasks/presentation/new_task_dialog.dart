import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../google_tasks/api/google_tasks_json.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../../task_providers/task_provider.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../data/tasks_repository.dart';
import 'task_details_draft.dart';
import 'task_details_editor.dart';

class NewTaskDraft {
  const NewTaskDraft({
    required this.accountId,
    required this.taskListId,
    required this.input,
  });

  final String accountId;
  final String taskListId;
  final TaskCreateInput input;

  String get title => input.title;
  DateTime? get dueUtc => input.dueUtc;
  List<String> get categories => input.categories;
}

Future<NewTaskDraft?> showBusyMaxNewTaskDialog(
  BuildContext context, {
  required WidgetRef ref,
  required List<AccountEntity> accounts,
  required String? initialAccountId,
  required String? initialListId,
  DateTime? initialDueUtc,
  LinuxHeaderBarService? headerBarService,
}) {
  return showBusyMaxModalEditorDialog<NewTaskDraft>(
    context,
    headerBarService: headerBarService,
    maxWidth: 640,
    maxHeight: 760,
    builder: (dialogContext) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _NewTaskDialog(
        accounts: accounts,
        initialAccountId: initialAccountId,
        initialListId: initialListId,
        initialDueUtc: initialDueUtc,
      ),
    ),
  );
}

class _NewTaskDialog extends ConsumerStatefulWidget {
  const _NewTaskDialog({
    required this.accounts,
    this.initialAccountId,
    this.initialListId,
    this.initialDueUtc,
  });

  final List<AccountEntity> accounts;
  final String? initialAccountId;
  final String? initialListId;
  final DateTime? initialDueUtc;

  @override
  ConsumerState<_NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends ConsumerState<_NewTaskDialog> {
  String? _accountId;
  String? _taskListId;
  TaskDetailsDraft? _draftSnapshot;

  @override
  void initState() {
    super.initState();
    _accountId =
        widget.accounts.any((account) => account.id == widget.initialAccountId)
        ? widget.initialAccountId
        : widget.accounts.first.id;
    _taskListId = widget.initialListId;
  }

  @override
  Widget build(BuildContext context) {
    final accountId = _accountId ?? widget.accounts.first.id;
    final account = _accountForId(accountId);
    final provider = account?.provider ?? TaskProvider.google;
    final capabilities = capabilitiesForProvider(provider);
    final localTimeZone = ref.watch(localTimeZoneProvider);
    final repository = ref.watch(
      taskListsRepositoryForAccountProvider(accountId),
    );
    final tasksRepository = ref.watch(
      tasksRepositoryForAccountProvider(accountId),
    );

    return StreamBuilder<List<String>>(
      stream: tasksRepository.watchCategorySuggestions(),
      builder: (context, categorySnapshot) {
        final categorySuggestions = categorySnapshot.data ?? const <String>[];
        return StreamBuilder<List<TaskListEntity>>(
          stream: repository.watchTaskLists(),
          builder: (context, snapshot) {
            final taskLists = snapshot.data ?? const <TaskListEntity>[];
            final effectiveListId = _effectiveListId(taskLists);
            final editorTask = _newTaskEntity(
              accountId: accountId,
              taskListId: effectiveListId ?? '',
              initialDueUtc: widget.initialDueUtc,
            );
            final initialDraft = _initialDraftFor(
              editorTask,
              effectiveListId,
              localTimeZone,
            );

            return TaskDetailsEditor(
              key: ValueKey('new-task-editor-$accountId-$effectiveListId'),
              task: editorTask,
              taskLists: taskLists,
              capabilities: capabilities,
              localTimeZone: localTimeZone,
              initialDraft: initialDraft,
              editorTitle: context.l10n.newTask,
              saveLabel: context.l10n.create,
              accountLabel: _accountEditorLabel(context, account, provider),
              accountIds: [for (final account in widget.accounts) account.id],
              selectedAccountId: accountId,
              accountLabelFor: _accountLabel,
              accountSecondaryLabelFor: _accountSecondaryLabel,
              onAccountSelected: _selectAccount,
              allowTaskListSelection: true,
              showAdvancedActions: false,
              showDeleteAction: false,
              confirmTaskSwitch: false,
              categorySuggestions: categorySuggestions,
              canSaveDraft: (draft) => draft.taskListId.isNotEmpty,
              onDraftChanged: (draft) {
                _draftSnapshot = draft;
              },
              onRefresh: () {},
              onSave: (draft, _) =>
                  _submit(draft, capabilities, localTimeZone: localTimeZone),
              onCreateSubtask: (_) {},
              onMoveToTop: () {},
              onDelete: () async {},
              onCancel: () => Navigator.of(context).pop(),
            );
          },
        );
      },
    );
  }

  String? _effectiveListId(List<TaskListEntity> taskLists) {
    final snapshotListId = _draftSnapshot?.taskListId;
    if (taskLists.any((list) => list.id == snapshotListId)) {
      return snapshotListId;
    }
    if (taskLists.any((list) => list.id == _taskListId)) {
      return _taskListId;
    }
    if (taskLists.isEmpty) {
      return null;
    }
    return taskLists.first.id;
  }

  TaskDetailsDraft? _initialDraftFor(
    TaskEntity editorTask,
    String? effectiveListId,
    String localTimeZone,
  ) {
    final snapshot = _draftSnapshot;
    if (snapshot != null) {
      return snapshot.copyWith(taskListId: effectiveListId ?? '');
    }
    return TaskDetailsDraft.fromTask(
      editorTask,
      localTimeZone,
    ).copyWith(taskListId: effectiveListId ?? '');
  }

  TaskEntity _newTaskEntity({
    required String accountId,
    required String taskListId,
    required DateTime? initialDueUtc,
  }) {
    return TaskEntity(
      accountId: accountId,
      taskListId: taskListId,
      id: 'new-task',
      title: '',
      notes: '',
      status: 'needsAction',
      dueUtc: initialDueUtc == null
          ? null
          : encodeGoogleDateOnly(initialDueUtc),
      localDirty: false,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      updatedLocalAtUtc: '',
    );
  }

  AccountEntity? _accountForId(String accountId) {
    for (final account in widget.accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }

  String _accountLabel(String accountId) {
    return _accountForId(accountId)?.displayLabel ?? accountId;
  }

  String? _accountSecondaryLabel(String accountId) {
    return _accountForId(accountId)?.secondaryLabel;
  }

  String _accountEditorLabel(
    BuildContext context,
    AccountEntity? account,
    TaskProvider provider,
  ) {
    final label = account?.displayLabel.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return provider.displayName;
  }

  void _selectAccount(String value) {
    if (value == _accountId) {
      return;
    }
    final provider = _accountForId(value)?.provider ?? TaskProvider.google;
    final capabilities = capabilitiesForProvider(provider);
    setState(() {
      _accountId = value;
      _taskListId = null;
      if (!capabilities.supportsCategories && _draftSnapshot != null) {
        _draftSnapshot = _draftSnapshot!.copyWith(categories: const []);
      }
    });
  }

  Future<void> _submit(
    TaskDetailsDraft draft,
    TaskProviderCapabilities capabilities, {
    required String localTimeZone,
  }) async {
    final accountId = _accountId;
    if (accountId == null ||
        draft.taskListId.isEmpty ||
        draft.title.trim().isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      NewTaskDraft(
        accountId: accountId,
        taskListId: draft.taskListId,
        input: draft.toCreateInput(capabilities, localTimeZone: localTimeZone),
      ),
    );
  }
}
