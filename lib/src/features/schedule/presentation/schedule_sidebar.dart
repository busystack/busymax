import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_design.dart';
import '../../../calendar_providers/calendar_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../sync/sync_auth_error.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../../../task_providers/task_provider.dart';
import 'mini_calendar.dart';

class ScheduleSidebar extends ConsumerWidget {
  const ScheduleSidebar({
    super.key,
    required this.selectedDate,
    required this.firstWeekday,
    required this.items,
    required this.onDateSelected,
    required this.onMonthSelected,
    required this.onYearSelected,
    required this.onWeekSelected,
  });

  final DateTime selectedDate;
  final int firstWeekday;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<DateTime> onYearSelected;
  final ValueChanged<DateTime> onWeekSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    return BusyMaxSidebarSurface(
      child: Column(
        children: [
          MiniCalendar(
            selectedDate: selectedDate,
            firstWeekday: firstWeekday,
            items: items,
            onSelected: onDateSelected,
            onMonthSelected: onMonthSelected,
            onYearSelected: onYearSelected,
            onWeekSelected: onWeekSelected,
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: BusyMaxSpacing.sm),
              children: [
                for (final account in accounts)
                  _AccountSourcesGroup(account: account),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends ConsumerWidget {
  const _SourceRow({required this.source});

  final CalendarSourceEntity source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CompactSourceRow(
      title: source.summary,
      leading: _SourceDot(
        seed: source.id,
        colorHex: calendarSourceBackgroundColorHex(
          provider: source.provider,
          backgroundColor: source.backgroundColor,
          colorId: source.colorId,
        ),
      ),
      trailing: _SourceRowActions(
        visibilityButton: _SourceVisibilityButton(
          value: source.selected && !source.hidden,
          semanticLabel: source.summary,
          onChanged: (value) {
            ref
                .read(calendarRepositoryProvider)
                .setSourceSelected(source.id, value);
          },
        ),
        menuButton: BusyMaxMenuButton<String>(
          tooltip: context.l10n.options,
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                unawaited(_refreshCalendarSource(context, ref, source));
              case 'open':
                unawaited(_openProviderWeb(_calendarWebUri(source)));
              case 'rename':
                unawaited(_renameCalendar(context, ref, source));
              case 'delete':
                unawaited(_deleteCalendar(context, ref, source));
            }
          },
          entries: [
            BusyMaxMenuEntry(
              value: 'refresh',
              label: context.l10n.refreshCalendar,
              icon: YaruIcons.refresh,
            ),
            BusyMaxMenuEntry(
              value: 'open',
              label: context.l10n.openInProvider,
              icon: Icons.open_in_browser_outlined,
            ),
            BusyMaxMenuEntry(
              value: 'rename',
              label: context.l10n.rename,
              icon: Icons.edit_outlined,
              enabled: !source.readOnly,
              tooltip: source.readOnly ? context.l10n.readOnlyCalendar : null,
            ),
            BusyMaxMenuEntry(
              value: 'delete',
              label: context.l10n.delete,
              icon: YaruIcons.trash,
              enabled: !source.readOnly,
              tooltip: source.readOnly ? context.l10n.readOnlyCalendar : null,
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactSourceRow extends StatelessWidget {
  const _CompactSourceRow({
    required this.title,
    required this.trailing,
    this.leading,
  });

  final String title;
  final Widget? leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: BusyMaxSizes.sidebarRowHeight,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: BusyMaxSpacing.md,
          end: BusyMaxSpacing.xs,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: BusyMaxSpacing.md),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: BusyMaxSpacing.xs),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SourceRowActions extends StatelessWidget {
  const _SourceRowActions({
    required this.visibilityButton,
    required this.menuButton,
  });

  final Widget visibilityButton;
  final Widget menuButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [visibilityButton, menuButton],
    );
  }
}

class _SourceVisibilityButton extends StatelessWidget {
  const _SourceVisibilityButton({
    required this.value,
    required this.semanticLabel,
    required this.onChanged,
  });

  final bool value;
  final String semanticLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sidebarBackground = BusyMaxSurfaceColors.of(context).sidebar;
    final activeIconColor = colorScheme.onSurfaceVariant;
    final inactiveIconColor = Color.lerp(
      sidebarBackground,
      activeIconColor,
      0.42,
    )!;
    final iconColor = value ? activeIconColor : inactiveIconColor;
    final tooltip = value ? context.l10n.hide : context.l10n.show;
    return Semantics(
      label: semanticLabel,
      checked: value,
      button: true,
      onTap: () => onChanged(!value),
      child: YaruIconButton(
        tooltip: tooltip,
        iconSize: BusyMaxSizes.sidebarActionIcon,
        icon: Icon(YaruIcons.checkmark, color: iconColor),
        onPressed: () => onChanged(!value),
        style: busyMaxHeaderIconButtonStyle(
          foregroundColor: iconColor,
          backgroundColor: busyMaxSubtleButtonBackground(context),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }
}

class _AccountSourcesGroup extends ConsumerStatefulWidget {
  const _AccountSourcesGroup({required this.account});

  final AccountEntity account;

  @override
  ConsumerState<_AccountSourcesGroup> createState() =>
      _AccountSourcesGroupState();
}

class _AccountSourcesGroupState extends ConsumerState<_AccountSourcesGroup> {
  var _expanded = true;

  @override
  void didUpdateWidget(covariant _AccountSourcesGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.id != widget.account.id) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountHeaderRow(
          account: account,
          expanded: _expanded,
          onToggleExpanded: _toggleExpanded,
        ),
        if (_expanded) ...[
          _AccountCalendarSources(account: account),
          StreamBuilder<List<TaskListEntity>>(
            stream: ref
                .watch(taskListsRepositoryForAccountProvider(account.id))
                .watchTaskLists(),
            builder: (context, snapshot) {
              final lists = snapshot.data ?? const <TaskListEntity>[];
              if (lists.isEmpty) {
                return BusyMaxActionRow(title: context.l10n.noTaskListsSynced);
              }
              return Column(
                children: [
                  for (final list in lists)
                    _TaskListScheduleRow(account: account, list: list),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }
}

class _AccountHeaderRow extends StatelessWidget {
  const _AccountHeaderRow({
    required this.account,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final AccountEntity account;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryLabel = account.secondaryLabel;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: BusyMaxSpacing.md,
        top: BusyMaxSpacing.sm,
        end: BusyMaxSpacing.xs,
        bottom: BusyMaxSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (secondaryLabel != null && secondaryLabel.isNotEmpty)
                  Text(
                    secondaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: BusyMaxSpacing.xs),
          YaruIconButton(
            tooltip: expanded
                ? MaterialLocalizations.of(context).expandedIconTapHint
                : MaterialLocalizations.of(context).collapsedIconTapHint,
            iconSize: BusyMaxSizes.sidebarActionIcon,
            icon: AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 160),
              child: const Icon(YaruIcons.pan_end, size: 16),
            ),
            onPressed: onToggleExpanded,
            style: busyMaxHeaderIconButtonStyle(
              foregroundColor: colorScheme.onSurfaceVariant,
              backgroundColor: busyMaxSubtleButtonBackground(context),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCalendarSources extends ConsumerWidget {
  const _AccountCalendarSources({required this.account});

  final AccountEntity account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!account.calendarsEnabled) {
      return BusyMaxActionRow(
        title: context.l10n.calendars,
        leading: const Icon(YaruIcons.calendar),
        subtitle: context.l10n.off,
      );
    }

    return StreamBuilder<List<CalendarSourceEntity>>(
      stream: ref.watch(calendarRepositoryProvider).watchSourcesForAccounts([
        account.id,
      ]),
      builder: (context, snapshot) {
        final sources = snapshot.data ?? const <CalendarSourceEntity>[];
        if (sources.isEmpty) {
          return BusyMaxActionRow(
            title: context.l10n.noCalendarsSynced,
            leading: const Icon(YaruIcons.calendar),
          );
        }
        return Column(
          children: [for (final source in sources) _SourceRow(source: source)],
        );
      },
    );
  }
}

class _SourceDot extends StatelessWidget {
  const _SourceDot({this.seed, this.colorHex, this.color});

  final String? seed;
  final String? colorHex;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        _colorFromHex(colorHex) ??
        ScheduleProjection.deterministicSourceColor(
          seed ?? '',
          Theme.of(context).colorScheme.brightness,
        );
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: resolvedColor, shape: BoxShape.circle),
    );
  }
}

class _TaskListScheduleRow extends ConsumerWidget {
  const _TaskListScheduleRow({required this.account, required this.list});

  final AccountEntity account;
  final TaskListEntity list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final visible = settings.isTaskListVisibleInSchedule(
      list.accountId,
      list.id,
    );
    final title = _taskListLabel(context, account, list);
    return _CompactSourceRow(
      title: title,
      leading: _SourceDot(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      trailing: _SourceRowActions(
        visibilityButton: _SourceVisibilityButton(
          value: visible,
          semanticLabel: title,
          onChanged: (value) {
            ref
                .read(appSettingsControllerProvider.notifier)
                .setTaskListVisibleInSchedule(
                  accountId: list.accountId,
                  taskListId: list.id,
                  visible: value,
                );
          },
        ),
        menuButton: BusyMaxMenuButton<String>(
          tooltip: context.l10n.options,
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                unawaited(_refreshTaskListAccount(context, ref, account.id));
              case 'open':
                unawaited(_openProviderWeb(_taskProviderWebUri(account)));
              case 'rename':
                unawaited(_renameTaskList(context, ref, list));
              case 'delete':
                unawaited(_deleteTaskList(context, ref, list));
            }
          },
          entries: [
            BusyMaxMenuEntry(
              value: 'refresh',
              label: context.l10n.refreshList,
              icon: YaruIcons.refresh,
            ),
            BusyMaxMenuEntry(
              value: 'open',
              label: context.l10n.openInProvider,
              icon: Icons.open_in_browser_outlined,
            ),
            BusyMaxMenuEntry(
              value: 'rename',
              label: context.l10n.rename,
              icon: Icons.edit_outlined,
              enabled: _canRenameOrDeleteTaskList(account, list),
              tooltip: _canRenameOrDeleteTaskList(account, list)
                  ? null
                  : context.l10n.builtInMicrosoftListCannotRenameDelete,
            ),
            BusyMaxMenuEntry(
              value: 'delete',
              label: context.l10n.delete,
              icon: YaruIcons.trash,
              enabled: _canRenameOrDeleteTaskList(account, list),
              tooltip: _canRenameOrDeleteTaskList(account, list)
                  ? null
                  : context.l10n.builtInMicrosoftListCannotRenameDelete,
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

String _taskListLabel(
  BuildContext context,
  AccountEntity account,
  TaskListEntity list,
) {
  final provider = account.provider == BusyProvider.google
      ? context.l10n.googleTasksProvider
      : context.l10n.microsoftTodoProvider;
  final title = list.title.trim();
  if (title.isEmpty ||
      title.toLowerCase() == provider.toLowerCase() ||
      title.toLowerCase() == account.provider.displayName.toLowerCase()) {
    return provider;
  }
  return '$provider · $title';
}

Color? _colorFromHex(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final hex = value.replaceFirst('#', '');
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xff000000 | parsed);
}

Uri _calendarWebUri(CalendarSourceEntity source) {
  if (source.provider == TaskProvider.google) {
    return Uri.https('calendar.google.com', '/calendar/u/0/r', {
      'cid': source.providerCalendarId,
    });
  }
  return Uri.https('outlook.live.com', '/calendar/0/view/month');
}

Uri _taskProviderWebUri(AccountEntity account) {
  if (account.provider == TaskProvider.google) {
    return Uri.https('tasks.google.com', '/');
  }
  return Uri.https('to-do.office.com', '/tasks/');
}

Future<void> _openProviderWeb(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _refreshCalendarSource(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  try {
    await ref
        .read(accountSyncOperationsProvider)
        .syncCalendar(source.accountId, full: false);
  } on Object catch (error) {
    if (!context.mounted) {
      return;
    }
    await _handleRefreshFailure(context, ref, source.accountId, error);
  }
}

Future<void> _refreshTaskListAccount(
  BuildContext context,
  WidgetRef ref,
  String accountId,
) async {
  try {
    await ref
        .read(accountSyncOperationsProvider)
        .syncTasks(accountId, full: false);
  } on Object catch (error) {
    if (!context.mounted) {
      return;
    }
    await _handleRefreshFailure(context, ref, accountId, error);
  }
}

Future<void> _handleRefreshFailure(
  BuildContext context,
  WidgetRef ref,
  String accountId,
  Object error,
) async {
  try {
    if (isMissingOAuthTokenError(error)) {
      await ref.read(authRepositoryProvider).markReconnectRequired(accountId);
    }
  } on Object {
    // Keep the original refresh failure visible even if cleanup fails.
  }
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.l10n.refreshFailed(syncFailureMessage(error))),
    ),
  );
}

bool _canRenameOrDeleteTaskList(AccountEntity account, TaskListEntity list) {
  if (account.provider == TaskProvider.microsoft) {
    return list.canRenameOrDeleteForMicrosoft;
  }
  return true;
}

Future<void> _renameCalendar(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  final title = await showBusyMaxTextPrompt(
    context,
    title: context.l10n.rename,
    label: context.l10n.title,
    actionLabel: context.l10n.rename,
    initialValue: source.summary,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (title == null || title.trim().isEmpty || title.trim() == source.summary) {
    return;
  }
  await ref
      .read(calendarRepositoryProvider)
      .renameLocalSource(source.id, title.trim());
}

Future<void> _deleteCalendar(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  final confirmed = await showBusyMaxConfirm(
    context,
    title: context.l10n.delete,
    message: context.l10n.deleteCalendarConfirmation(source.summary),
    confirmLabel: context.l10n.delete,
    destructive: true,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (!confirmed) {
    return;
  }
  await ref.read(calendarRepositoryProvider).deleteLocalSource(source.id);
}

Future<void> _renameTaskList(
  BuildContext context,
  WidgetRef ref,
  TaskListEntity list,
) async {
  final title = await showBusyMaxTextPrompt(
    context,
    title: context.l10n.renameList,
    label: context.l10n.title,
    actionLabel: context.l10n.rename,
    initialValue: list.title,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (title == null || title.trim().isEmpty || title.trim() == list.title) {
    return;
  }
  await ref
      .read(taskListsRepositoryForAccountProvider(list.accountId))
      .renameTaskList(list.id, title.trim());
}

Future<void> _deleteTaskList(
  BuildContext context,
  WidgetRef ref,
  TaskListEntity list,
) async {
  final confirmed = await showBusyMaxConfirm(
    context,
    title: context.l10n.deleteList,
    message: context.l10n.deleteListConfirmation(list.title),
    confirmLabel: context.l10n.delete,
    destructive: true,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (!confirmed) {
    return;
  }
  await ref
      .read(taskListsRepositoryForAccountProvider(list.accountId))
      .deleteTaskList(list.id);
}
