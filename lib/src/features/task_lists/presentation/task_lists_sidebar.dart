import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../features/accounts/data/accounts_repository.dart';
import '../../../l10n/l10n.dart';
import '../../../task_providers/task_provider.dart';
import '../../tasks/presentation/tasks_selection_state.dart';
import '../data/task_lists_repository.dart';

class TaskListsSidebar extends ConsumerWidget {
  const TaskListsSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedListId = ref.watch(selectedTaskListIdProvider);
    final selectedAccount = ref.watch(selectedAccountProvider);
    final allTasksMode = ref.watch(allTasksModeProvider);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final l10n = context.l10n;

    return SizedBox(
      width: BusyMaxSizes.sidebarWidth,
      child: Material(
        color: BusyMaxSurfaceColors.of(context).sidebar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SidebarHeader(),
            const Divider(height: 1),
            Expanded(
              child: accounts.isEmpty
                  ? Center(child: Text(l10n.signInToViewTaskLists))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        BusyMaxSpacing.sm,
                        BusyMaxSpacing.sm,
                        BusyMaxSpacing.sm,
                        BusyMaxSpacing.sm,
                      ),
                      children: [
                        _AllTasksRow(
                          selected: allTasksMode,
                          onTap: () => _selectAllTasks(ref),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            BusyMaxSpacing.sm,
                            BusyMaxSpacing.lg,
                            BusyMaxSpacing.sm,
                            BusyMaxSpacing.xs,
                          ),
                          child: Text(
                            l10n.accounts,
                            style: busyMaxSectionHeaderStyle(context),
                          ),
                        ),
                        for (final account in accounts)
                          _AccountTaskListsSection(
                            key: ValueKey(account.id),
                            account: account,
                            repository: ref.watch(
                              taskListsRepositoryForAccountProvider(account.id),
                            ),
                            selected:
                                !allTasksMode &&
                                account.id == selectedAccount?.id,
                            selectedListId:
                                !allTasksMode &&
                                    account.id == selectedAccount?.id
                                ? selectedListId
                                : null,
                            onSelectList: (list) =>
                                _selectTaskList(ref, account.id, list.id),
                            onCreateList: (repository) =>
                                _createList(context, repository),
                            onRenameList: (repository, list) =>
                                _renameList(context, repository, list),
                            onDeleteList: (repository, list) =>
                                _deleteList(context, ref, repository, list),
                          ),
                      ],
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BusyMaxSpacing.sm,
                BusyMaxSpacing.sm,
                BusyMaxSpacing.sm,
                BusyMaxSpacing.sm,
              ),
              child: _SidebarFooterButton(
                icon: YaruIcons.settings,
                label: l10n.settings,
                onTap: () => context.go('/settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameList(
    BuildContext context,
    TaskListsRepository repository,
    TaskListEntity list,
  ) async {
    final title = await showBusyMaxTextPrompt(
      context,
      title: context.l10n.renameList,
      label: context.l10n.title,
      actionLabel: context.l10n.rename,
      initialValue: list.title,
    );
    if (title == null || title.trim().isEmpty || title.trim() == list.title) {
      return;
    }
    await repository.renameTaskList(list.id, title.trim());
  }

  Future<void> _createList(
    BuildContext context,
    TaskListsRepository repository,
  ) async {
    final title = await showBusyMaxTextPrompt(
      context,
      title: context.l10n.newList,
      label: context.l10n.title,
      actionLabel: context.l10n.create,
    );
    if (title == null || title.trim().isEmpty) {
      return;
    }
    await repository.createTaskList(title.trim());
  }

  Future<void> _deleteList(
    BuildContext context,
    WidgetRef ref,
    TaskListsRepository repository,
    TaskListEntity list,
  ) async {
    final confirmed = await showBusyMaxConfirm(
      context,
      title: context.l10n.deleteList,
      message: context.l10n.deleteListConfirmation(list.title),
      confirmLabel: context.l10n.delete,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await repository.deleteTaskList(list.id);
    final selectedListId = ref.read(selectedTaskListIdProvider);
    if (selectedListId == list.id) {
      ref.read(selectedTaskListIdProvider.notifier).state = null;
      ref.read(selectedTaskIdProvider.notifier).state = null;
      ref.read(allTasksModeProvider.notifier).state = true;
    }
  }

  void _selectAllTasks(WidgetRef ref) {
    ref.read(selectedTaskListIdProvider.notifier).state = null;
    ref.read(selectedTaskIdProvider.notifier).state = null;
    ref.read(allTasksModeProvider.notifier).state = true;
  }

  void _selectTaskList(WidgetRef ref, String accountId, String taskListId) {
    final currentAccountId = ref.read(selectedAccountProvider)?.id;
    if (currentAccountId != accountId) {
      ref.read(selectedAccountIdProvider.notifier).state = accountId;
      unawaited(ref.read(signedInSyncRunnerProvider)(accountId, false));
    }

    ref.read(selectedTaskListIdProvider.notifier).state = taskListId;
    ref.read(selectedTaskIdProvider.notifier).state = null;
    ref.read(allTasksModeProvider.notifier).state = false;
  }
}

class _AccountTaskListsSection extends StatefulWidget {
  const _AccountTaskListsSection({
    super.key,
    required this.account,
    required this.repository,
    required this.selected,
    required this.selectedListId,
    required this.onSelectList,
    required this.onCreateList,
    required this.onRenameList,
    required this.onDeleteList,
  });

  final AccountEntity account;
  final TaskListsRepository repository;
  final bool selected;
  final String? selectedListId;
  final void Function(TaskListEntity list) onSelectList;
  final Future<void> Function(TaskListsRepository repository) onCreateList;
  final Future<void> Function(
    TaskListsRepository repository,
    TaskListEntity list,
  )
  onRenameList;
  final Future<void> Function(
    TaskListsRepository repository,
    TaskListEntity list,
  )
  onDeleteList;

  @override
  State<_AccountTaskListsSection> createState() =>
      _AccountTaskListsSectionState();
}

class _AccountTaskListsSectionState extends State<_AccountTaskListsSection> {
  late Stream<List<TaskListEntity>> _taskLists;
  var _expanded = true;

  @override
  void initState() {
    super.initState();
    _taskLists = _watchTaskLists();
  }

  @override
  void didUpdateWidget(covariant _AccountTaskListsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.account.id != widget.account.id) {
      _taskLists = _watchTaskLists();
      _expanded = true;
    }
  }

  Stream<List<TaskListEntity>> _watchTaskLists() {
    return widget.repository.watchTaskLists();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AccountSectionHeader(
            account: widget.account,
            expanded: _expanded,
            onCreateList: () => widget.onCreateList(widget.repository),
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
          ),
          StreamBuilder<List<TaskListEntity>>(
            stream: _taskLists,
            builder: (context, snapshot) {
              if (!_expanded) {
                return const SizedBox.shrink();
              }

              final lists = snapshot.data ?? const [];
              if (lists.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(48, 6, 10, 8),
                  child: Text(
                    l10n.noTaskListsSynced,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final list in lists) _buildListRow(list)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListRow(TaskListEntity list) {
    final isMicrosoft = widget.account.provider == TaskProvider.microsoft;
    final canRenameDelete = !isMicrosoft || list.canRenameOrDeleteForMicrosoft;
    return _TaskListRow(
      list: list,
      selected: widget.selected && list.id == widget.selectedListId,
      isMicrosoft: isMicrosoft,
      canRenameDelete: canRenameDelete,
      onTap: () => widget.onSelectList(list),
      onRename: canRenameDelete
          ? () => widget.onRenameList(widget.repository, list)
          : null,
      onDelete: canRenameDelete
          ? () => widget.onDeleteList(widget.repository, list)
          : null,
    );
  }
}

class _AllTasksRow extends StatelessWidget {
  const _AllTasksRow({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SidebarSelectableTile(
      selected: selected,
      padding: EdgeInsets.zero,
      onTap: onTap,
      leading: const Icon(Icons.all_inbox, size: 18),
      title: Text(context.l10n.allTasks),
    );
  }
}

class _AccountSectionHeader extends StatelessWidget {
  const _AccountSectionHeader({
    required this.account,
    required this.expanded,
    required this.onTap,
    required this.onCreateList,
  });

  final AccountEntity account;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onCreateList;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: YaruListTile(
        onTap: onTap,
        leading: Icon(_providerIcon(account.provider), size: 18),
        title: Text(
          _providerHeaderLabel(context, account.provider),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _accountIdentityLabel(context, account),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            YaruIconButton(
              tooltip: context.l10n.newList,
              iconSize: 28,
              icon: const Icon(YaruIcons.plus),
              onPressed: onCreateList,
            ),
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 160),
              child: const Icon(YaruIcons.pan_end, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarSelectableTile extends StatelessWidget {
  const _SidebarSelectableTile({
    required this.selected,
    required this.title,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  final bool selected;
  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: YaruSelectableContainer(
        selected: selected,
        selectionColor: Theme.of(context).listTileTheme.selectedTileColor,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: YaruListTile(leading: leading, title: title, trailing: trailing),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logo = Image.asset(
            'assets/branding/busymax-logo.svg',
            width: 26,
            height: 26,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(YaruIcons.task_list_filled, size: 26),
          );
          if (constraints.maxWidth < 74) {
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: FittedBox(fit: BoxFit.scaleDown, child: logo),
            );
          }

          return Row(
            children: [
              logo,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.appTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskListRow extends StatelessWidget {
  const _TaskListRow({
    required this.list,
    required this.selected,
    required this.isMicrosoft,
    required this.canRenameDelete,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final TaskListEntity list;
  final bool selected;
  final bool isMicrosoft;
  final bool canRenameDelete;
  final VoidCallback onTap;
  final Future<void> Function()? onRename;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SidebarSelectableTile(
      selected: selected,
      padding: const EdgeInsets.only(
        left: 34,
        top: BusyMaxSpacing.xxs,
        bottom: BusyMaxSpacing.xxs,
      ),
      onTap: onTap,
      leading: Icon(
        list.localDirty ? YaruIcons.sync_error : YaruIcons.task_list,
        size: 17,
      ),
      title: Text(list.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMicrosoft && list.isMicrosoftBuiltIn)
            Tooltip(
              message: l10n.builtInMicrosoftListCannotRenameDelete,
              child: SizedBox(
                width: 58,
                child: BusyMaxInlineBadge(
                  label: l10n.builtInMicrosoftList,
                  tooltip: l10n.builtInMicrosoftListCannotRenameDelete,
                ),
              ),
            ),
          if (list.pendingDelete)
            const Icon(YaruIcons.trash, size: 16)
          else
            Opacity(
              opacity: 0.72,
              child: BusyMaxMenuButton<_TaskListAction>(
                tooltip: l10n.listActions,
                onSelected: (action) {
                  switch (action) {
                    case _TaskListAction.rename:
                      if (canRenameDelete) {
                        onRename?.call();
                      }
                      break;
                    case _TaskListAction.delete:
                      if (canRenameDelete) {
                        onDelete?.call();
                      }
                      break;
                  }
                },
                entries: [
                  BusyMaxMenuEntry(
                    value: _TaskListAction.rename,
                    label: l10n.rename,
                    icon: Icons.edit_outlined,
                    enabled: canRenameDelete,
                  ),
                  BusyMaxMenuEntry(
                    value: _TaskListAction.delete,
                    label: l10n.delete,
                    icon: YaruIcons.trash,
                    enabled: canRenameDelete,
                    destructive: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _TaskListAction { rename, delete }

class _SidebarFooterButton extends StatelessWidget {
  const _SidebarFooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return YaruListTile(
      titleText: label,
      leading: Icon(icon, size: 17),
      onTap: onTap,
    );
  }
}

IconData _providerIcon(TaskProvider? provider) {
  return switch (provider) {
    TaskProvider.microsoft => Icons.account_circle_outlined,
    TaskProvider.google => YaruIcons.globe,
    null => YaruIcons.user,
  };
}

String _providerHeaderLabel(BuildContext context, TaskProvider provider) {
  final l10n = context.l10n;
  return switch (provider) {
    TaskProvider.google => l10n.googleTasksProvider,
    TaskProvider.microsoft => l10n.microsoftTodoProvider,
  };
}

String _accountIdentityLabel(BuildContext context, AccountEntity account) {
  final metadata = _accountMetadata(account);
  final name = _firstAccountIdentityValue([
    account.displayName,
    metadata['displayName'],
    metadata['name'],
  ]);
  final email = _firstAccountIdentityValue([
    account.email,
    metadata['email'],
    metadata['mail'],
    metadata['userPrincipalName'],
  ]);
  final providerName = account.provider.displayName.trim();

  if (name != null &&
      name.isNotEmpty &&
      email != null &&
      email.isNotEmpty &&
      name != email) {
    return '$name · $email';
  }

  if (email != null && email.isNotEmpty) {
    return email;
  }

  final providerAccountId = account.providerAccountId?.trim();
  if (providerAccountId != null &&
      providerAccountId.isNotEmpty &&
      providerAccountId.contains('@')) {
    return providerAccountId;
  }

  if (name != null && name.isNotEmpty && name != providerName) {
    return name;
  }

  return context.l10n.signedInAccount;
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

String? _firstAccountIdentityValue(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}
