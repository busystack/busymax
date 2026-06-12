import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_layout.dart';
import '../../../core/logging/redacting_logger.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../sync/sync_engine.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../../task_lists/presentation/task_lists_sidebar.dart';
import '../data/tasks_repository.dart';
import 'task_details_pane.dart';
import 'task_filters.dart';
import 'new_task_dialog.dart';
import 'tasks_selection_state.dart';
import 'task_tree_view.dart';

class TasksWorkspace extends ConsumerStatefulWidget {
  const TasksWorkspace({super.key, this.selectedListId, this.selectedTaskId});

  final String? selectedListId;
  final String? selectedTaskId;

  @override
  ConsumerState<TasksWorkspace> createState() => _TasksWorkspaceState();
}

class _TasksWorkspaceState extends ConsumerState<TasksWorkspace> {
  _TaskDetailsTarget? _detailsTarget;
  var _detailsDirty = false;
  late final LinuxHeaderBarService _headerBarService;

  @override
  void initState() {
    super.initState();
    _headerBarService = ref.read(linuxHeaderBarServiceProvider);
    _scheduleRouteSelectionSeed();
  }

  @override
  void didUpdateWidget(covariant TasksWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedListId != widget.selectedListId ||
        oldWidget.selectedTaskId != widget.selectedTaskId) {
      _scheduleRouteSelectionSeed();
    }
  }

  @override
  void dispose() {
    if (_detailsTarget != null) {
      unawaited(_headerBarService.setModalBarrierVisible(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTasksMode = ref.watch(allTasksModeProvider);
    final selectedListId = ref.watch(selectedTaskListIdProvider);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);
    final showAllTasks =
        widget.selectedListId == null &&
        (selectedListId == null || allTasksMode);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final showSidebar = BusyMaxLayoutRules.showSidebar(width);
          final taskContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TasksToolbar(
                selectedListId: selectedListId,
                showAllTasks: showAllTasks,
              ),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: TaskFiltersBar(),
              ),
              const Divider(height: 1),
              Expanded(
                child: TaskTreeView(
                  taskListId: selectedListId,
                  showAllTasks: showAllTasks,
                  selectedTaskId: selectedTaskId,
                  onOpenTask: _openTaskDetails,
                  onCreateTask: () => _createTaskFromWorkspace(
                    context,
                    ref,
                    selectedListId: selectedListId,
                  ),
                  onRefreshAll: showAllTasks
                      ? () => _refreshAllAccounts(context, ref)
                      : null,
                ),
              ),
            ],
          );
          final workspaceContent = showSidebar
              ? YaruPanedView(
                  pane: const TaskListsSidebar(),
                  page: taskContent,
                  layoutDelegate: const YaruResizablePaneDelegate(
                    initialPaneSize: BusyMaxSizes.sidebarWidth,
                    minPaneSize: BusyMaxSizes.sidebarWidth,
                    minPageSize: BusyMaxLayoutRules.taskPageMinWidth,
                    paneSide: YaruPaneSide.start,
                  ),
                )
              : taskContent;
          final workspace = _TaskContentWithDetailsOverlay(
            taskContent: workspaceContent,
            target: _detailsTarget,
            onClose: _closeTaskDetails,
            onDirtyChanged: (dirty) {
              _detailsDirty = dirty;
            },
            onTaskSwitchCancelled: _restoreTaskSelection,
          );
          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                unawaited(_requestCloseTaskDetails(context));
              },
            },
            child: Focus(autofocus: true, child: workspace),
          );
        },
      ),
    );
  }

  void _scheduleRouteSelectionSeed() {
    final routeListId = widget.selectedListId;
    final routeTaskId = widget.selectedTaskId;
    if (routeListId == null && routeTaskId == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(selectedTaskListIdProvider.notifier).state = routeListId;
      ref.read(selectedTaskIdProvider.notifier).state = routeTaskId;
      ref.read(allTasksModeProvider.notifier).state = routeListId == null;
    });
  }

  void _restoreTaskSelection(TaskEntity task) {
    ref.read(selectedAccountIdProvider.notifier).state = task.accountId;
    ref.read(selectedTaskListIdProvider.notifier).state = task.taskListId;
    ref.read(selectedTaskIdProvider.notifier).state = task.id;
    setState(() {
      _detailsTarget = _TaskDetailsTarget(
        accountId: task.accountId,
        taskListId: task.taskListId,
        taskId: task.id,
      );
      _detailsDirty = false;
    });
    unawaited(_headerBarService.setModalBarrierVisible(true));
  }

  void _openTaskDetails(
    TaskEntity task,
    String taskListId,
    bool stayInAllTasksMode,
  ) {
    ref.read(selectedAccountIdProvider.notifier).state = task.accountId;
    ref.read(selectedTaskListIdProvider.notifier).state = taskListId;
    ref.read(selectedTaskIdProvider.notifier).state = task.id;
    ref.read(allTasksModeProvider.notifier).state = stayInAllTasksMode;
    setState(() {
      _detailsTarget = _TaskDetailsTarget(
        accountId: task.accountId,
        taskListId: taskListId,
        taskId: task.id,
      );
      _detailsDirty = false;
    });
    unawaited(_headerBarService.setModalBarrierVisible(true));
  }

  void _closeTaskDetails() {
    if (_detailsTarget == null) {
      return;
    }
    setState(() {
      _detailsTarget = null;
      _detailsDirty = false;
    });
    unawaited(_headerBarService.setModalBarrierVisible(false));
  }

  Future<void> _requestCloseTaskDetails(BuildContext context) async {
    if (_detailsTarget == null) {
      return;
    }
    if (_detailsDirty) {
      final discard = await showBusyMaxConfirm(
        context,
        title: context.l10n.discardChanges,
        message: context.l10n.discardChangesConfirmation,
        confirmLabel: context.l10n.discard,
        destructive: true,
      );
      if (!discard || !mounted) {
        return;
      }
    }
    _closeTaskDetails();
  }
}

class _TaskDetailsTarget {
  const _TaskDetailsTarget({
    required this.accountId,
    required this.taskListId,
    required this.taskId,
  });

  final String accountId;
  final String taskListId;
  final String taskId;
}

class _TaskContentWithDetailsOverlay extends StatelessWidget {
  const _TaskContentWithDetailsOverlay({
    required this.taskContent,
    required this.target,
    required this.onClose,
    required this.onDirtyChanged,
    required this.onTaskSwitchCancelled,
  });

  final Widget taskContent;
  final _TaskDetailsTarget? target;
  final VoidCallback onClose;
  final ValueChanged<bool> onDirtyChanged;
  final ValueChanged<TaskEntity> onTaskSwitchCancelled;

  @override
  Widget build(BuildContext context) {
    final target = this.target;
    if (target == null) {
      return taskContent;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = (constraints.maxWidth - 24)
            .clamp(0, BusyMaxSizes.compactDetailsWidth)
            .toDouble();
        final minWidth = maxWidth < 560 ? maxWidth : 560.0;
        return Stack(
          children: [
            taskContent,
            ModalBarrier(
              color: busyMaxModalBarrierColor(context),
              dismissible: false,
            ),
            Center(
              child: BusyMaxModalEditorSurface(
                minWidth: minWidth,
                maxWidth: maxWidth,
                maxHeight: constraints.maxHeight - 24,
                child: TaskDetailsPane(
                  accountId: target.accountId,
                  taskListId: target.taskListId,
                  taskId: target.taskId,
                  onClose: onClose,
                  onDirtyChanged: onDirtyChanged,
                  onTaskSwitchCancelled: onTaskSwitchCancelled,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TasksToolbar extends ConsumerWidget {
  const _TasksToolbar({
    required this.selectedListId,
    required this.showAllTasks,
  });

  final String? selectedListId;
  final bool showAllTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksRepository = ref.watch(tasksRepositoryProvider);
    final listsRepository = ref.watch(taskListsRepositoryProvider);
    final syncEngine = ref.watch(syncEngineProvider);
    final syncEngineForAccount = ref.watch(syncEngineForAccountFactoryProvider);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final capabilities = ref.watch(selectedAccountCapabilitiesProvider);
    final hasList = selectedListId != null && !showAllTasks;
    final hasAccounts = accounts.isNotEmpty;
    final refreshLabel = showAllTasks
        ? context.l10n.refreshAll
        : context.l10n.refreshList;
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactActions = constraints.maxWidth < 720;
        return _ToolbarTitle(
          selectedListId: selectedListId,
          showAllTasks: showAllTasks,
          repository: listsRepository,
          actions: [
            BusyMaxToolbarButton(
              compact: compactActions,
              primary: true,
              tooltip: l10n.newTask,
              label: l10n.newTask,
              icon: YaruIcons.plus,
              onPressed: showAllTasks
                  ? hasAccounts
                        ? () => _createTaskFromWorkspace(
                            context,
                            ref,
                            selectedListId: selectedListId,
                          )
                        : null
                  : !hasList || tasksRepository == null
                  ? null
                  : () => _createTaskFromWorkspace(
                      context,
                      ref,
                      selectedListId: selectedListId,
                    ),
            ),
            if (!showAllTasks && capabilities.supportsClearCompleted)
              BusyMaxToolbarButton(
                compact: compactActions,
                tooltip: l10n.clearCompleted,
                label: l10n.clearCompleted,
                icon: Icons.cleaning_services,
                onPressed: !hasList || tasksRepository == null
                    ? null
                    : () => tasksRepository.clearCompleted(selectedListId!),
              ),
            BusyMaxToolbarButton(
              compact: compactActions,
              tooltip: refreshLabel,
              label: refreshLabel,
              icon: YaruIcons.refresh,
              onPressed: showAllTasks
                  ? hasAccounts
                        ? () => _refreshAll(
                            context,
                            accounts,
                            syncEngineForAccount,
                          )
                        : null
                  : !hasList || syncEngine == null
                  ? null
                  : () => _refreshList(context, syncEngine),
            ),
          ],
        );
      },
    );
  }
}

class _ToolbarTitle extends StatelessWidget {
  const _ToolbarTitle({
    required this.selectedListId,
    required this.showAllTasks,
    required this.repository,
    required this.actions,
  });

  final String? selectedListId;
  final bool showAllTasks;
  final TaskListsRepository? repository;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (showAllTasks) {
      return BusyMaxToolbar(title: context.l10n.allTasks, actions: actions);
    }

    final listId = selectedListId;
    final listsRepository = repository;
    if (listId == null || listsRepository == null) {
      return BusyMaxToolbar(title: context.l10n.tasks, actions: actions);
    }

    return StreamBuilder<TaskListEntity?>(
      stream: listsRepository.watchTaskList(listId),
      builder: (context, snapshot) {
        final title = snapshot.data?.title ?? listId;
        return BusyMaxToolbar(
          title: context.l10n.tasksInList(title),
          actions: actions,
        );
      },
    );
  }
}

Future<void> _createTaskFromWorkspace(
  BuildContext context,
  WidgetRef ref, {
  required String? selectedListId,
}) async {
  final accounts = ref.read(accountsStreamProvider).valueOrNull ?? const [];
  if (accounts.isEmpty) {
    return;
  }
  final draft = await showBusyMaxNewTaskDialog(
    context,
    ref: ref,
    accounts: accounts,
    initialAccountId: ref.read(selectedAccountProvider)?.id,
    initialListId: selectedListId,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (draft == null) {
    return;
  }
  await ref
      .read(tasksRepositoryForAccountProvider(draft.accountId))
      .createTask(draft.taskListId, draft.input);
}

Future<void> _refreshList(BuildContext context, SyncEngine syncEngine) async {
  try {
    await syncEngine.incrementalSync();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.listRefreshed)));
  } on Object catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.refreshFailed(redactForLog(error)))),
    );
  }
}

Future<void> _refreshAllAccounts(BuildContext context, WidgetRef ref) async {
  final accounts = ref.read(accountsStreamProvider).valueOrNull ?? const [];
  if (accounts.isEmpty) {
    return;
  }
  await _refreshAll(
    context,
    accounts,
    ref.read(syncEngineForAccountFactoryProvider),
  );
}

Future<void> _refreshAll(
  BuildContext context,
  List<AccountEntity> accounts,
  SyncEngineForAccountFactory syncEngineForAccount,
) async {
  try {
    for (final account in accounts) {
      await syncEngineForAccount(account.id).incrementalSync();
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.allTasksRefreshed)));
  } on Object catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.refreshFailed(redactForLog(error)))),
    );
  }
}
