import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_glyphs.dart';
import '../../../calendar_providers/calendar_colors.dart';
import '../../../calendar_providers/calendar_provider_capabilities.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_provider.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../webcal/webcal_subscription_service.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_collection_creation_capabilities.dart';
import '../../calendar/data/calendar_collection_creation_service.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../calendar/presentation/calendar_color_dialog.dart';
import '../../sync/sync_auth_error.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../../tasks/domain/task_capabilities.dart';
import 'package:busymax/src/providers/busy_provider.dart';
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
                for (final account in accounts.where(
                  (account) => !account.isSubscription,
                ))
                  _AccountSourcesGroup(
                    key: ValueKey(('schedule-account', account.id)),
                    account: account,
                  ),
                if (accounts.any((account) => account.isSubscription))
                  _SubscriptionSourcesGroup(
                    accounts: [
                      for (final account in accounts)
                        if (account.isSubscription) account,
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends ConsumerWidget {
  const _SourceRow({super.key, required this.account, required this.source});

  final AccountEntity account;
  final CalendarSourceEntity source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerWebUri = scheduleCalendarProviderWebUri(account, source);
    final capabilities = source.capabilities;
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
          key: ValueKey(('calendar-options', source.id)),
          tooltip: context.l10n.options,
          highlightWhenOpen: false,
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                unawaited(_refreshCalendarSource(context, ref, source));
              case 'open':
                if (providerWebUri != null) {
                  unawaited(_openProviderWeb(providerWebUri));
                }
              case 'toggle-reminders':
                unawaited(_setCalendarRemindersEnabled(context, ref, source));
              case 'color':
                unawaited(_changeCalendarColor(context, ref, source));
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
            if (providerWebUri != null)
              BusyMaxMenuEntry(
                value: 'open',
                label: context.l10n.openInProvider,
                icon: Icons.open_in_browser_outlined,
              ),
            BusyMaxMenuEntry(
              value: 'toggle-reminders',
              label:
                  '${context.l10n.eventReminders} — '
                  '${source.remindersEnabled ? context.l10n.onState : context.l10n.off}',
              icon: source.remindersEnabled
                  ? Icons.notifications_outlined
                  : Icons.notifications_off_outlined,
            ),
            BusyMaxMenuEntry(
              value: 'color',
              label: context.l10n.calendarColor,
              icon: Icons.palette_outlined,
              enabled: capabilities.canChangeCalendarColor,
              tooltip: _calendarColorRestriction(context, source),
            ),
            BusyMaxMenuEntry(
              value: 'rename',
              label: capabilities.renameMode == CalendarRenameMode.personal
                  ? context.l10n.setCustomCalendarName
                  : context.l10n.rename,
              icon: Icons.edit_outlined,
              enabled: capabilities.canRenameCalendar,
              tooltip: _calendarRenameRestriction(context, source),
            ),
            BusyMaxMenuEntry(
              value: 'delete',
              label:
                  capabilities.removalMode == CalendarRemovalMode.removeFromList
                  ? context.l10n.removeFromMyCalendars
                  : context.l10n.delete,
              icon: YaruIcons.trash,
              enabled: capabilities.canRemoveCalendar,
              tooltip: _calendarDeleteRestriction(context, source),
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
      child: BusyMaxHeaderIconButton(
        tooltip: tooltip,
        iconSize: BusyMaxSizes.sidebarActionIcon,
        icon: Icon(YaruIcons.checkmark, color: iconColor),
        onPressed: () => onChanged(!value),
        foregroundColor: iconColor,
        backgroundColor: busyMaxSubtleButtonBackground(context),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}

class _AccountSourcesGroup extends ConsumerStatefulWidget {
  const _AccountSourcesGroup({super.key, required this.account});

  final AccountEntity account;

  @override
  ConsumerState<_AccountSourcesGroup> createState() =>
      _AccountSourcesGroupState();
}

class _AccountSourcesGroupState extends ConsumerState<_AccountSourcesGroup> {
  var _expanded = true;
  var _creatingCalendar = false;
  var _creatingTaskList = false;

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
    final networkAvailability =
        ref.watch(networkAvailabilityProvider).valueOrNull ??
        ref.read(networkConnectivityMonitorProvider).availability;
    final capabilities = AccountCollectionCreationCapabilities.resolve(
      account: account,
      networkAvailability: networkAvailability,
      calendarCreationRunning: _creatingCalendar,
      taskListCreationRunning: _creatingTaskList,
    );
    final headerActions = <_AccountHeaderCollectionAction>[
      if (capabilities.supportsCalendarCreation)
        _AccountHeaderCollectionAction(
          action: AccountHeaderCollectionAction.newCalendar,
          enabled: capabilities.calendarActionEnabled,
        ),
      if (capabilities.supportsTaskListCreation)
        _AccountHeaderCollectionAction(
          action: AccountHeaderCollectionAction.newTaskList,
          enabled: capabilities.taskListActionEnabled,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountHeaderRow(
          account: account,
          expanded: _expanded,
          onToggleExpanded: _toggleExpanded,
          actions: headerActions,
          onActionSelected: _handleCollectionAction,
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
                    _TaskListScheduleRow(
                      key: ValueKey((
                        'schedule-task-list',
                        list.accountId,
                        list.id,
                      )),
                      account: account,
                      list: list,
                    ),
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

  Future<void> _handleCollectionAction(
    AccountHeaderCollectionAction action,
  ) async {
    switch (action) {
      case AccountHeaderCollectionAction.newCalendar:
        if (_creatingCalendar) return;
        setState(() => _creatingCalendar = true);
        try {
          await _createAccountCalendar(context, ref, widget.account);
        } finally {
          if (mounted) setState(() => _creatingCalendar = false);
        }
      case AccountHeaderCollectionAction.newTaskList:
        if (_creatingTaskList) return;
        setState(() => _creatingTaskList = true);
        try {
          await _createAccountTaskList(context, ref, widget.account);
        } finally {
          if (mounted) setState(() => _creatingTaskList = false);
        }
    }
  }
}

class _SubscriptionSourcesGroup extends ConsumerWidget {
  const _SubscriptionSourcesGroup({required this.accounts});

  final List<AccountEntity> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountById = {for (final account in accounts) account.id: account};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: BusyMaxSpacing.md,
            top: BusyMaxSpacing.md,
            end: BusyMaxSpacing.md,
            bottom: BusyMaxSpacing.xs,
          ),
          child: Text(
            context.l10n.subscriptions,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        StreamBuilder<List<CalendarSourceEntity>>(
          stream: ref
              .watch(calendarRepositoryProvider)
              .watchSourcesForAccounts(accountById.keys.toList()),
          builder: (context, snapshot) {
            final sources = (snapshot.data ?? const <CalendarSourceEntity>[])
                .where((source) => source.provider == BusyProvider.webCal);
            return Column(
              children: [
                for (final source in sources)
                  _SubscriptionSourceRow(
                    key: ValueKey(('subscription-source', source.id)),
                    source: source,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SubscriptionSourceRow extends ConsumerWidget {
  const _SubscriptionSourceRow({super.key, required this.source});

  final CalendarSourceEntity source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CompactSourceRow(
      title: '${source.summary} · ${context.l10n.readOnlySharedCollection}',
      leading: _SourceDot(seed: source.id, colorHex: source.backgroundColor),
      trailing: _SourceRowActions(
        visibilityButton: _SourceVisibilityButton(
          value: source.selected && !source.hidden,
          semanticLabel: source.summary,
          onChanged: (value) => ref
              .read(calendarRepositoryProvider)
              .setSourceSelected(source.id, value),
        ),
        menuButton: BusyMaxMenuButton<String>(
          tooltip: context.l10n.options,
          highlightWhenOpen: false,
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                unawaited(_refreshSubscriptionSource(context, ref, source));
              case 'rename':
                unawaited(_renameSubscriptionSource(context, ref, source));
              case 'color':
                unawaited(_colorSubscriptionSource(context, ref, source));
              case 'unsubscribe':
                unawaited(_unsubscribeSource(context, ref, source));
            }
          },
          entries: [
            BusyMaxMenuEntry(
              value: 'refresh',
              label: context.l10n.refreshNow,
              icon: YaruIcons.refresh,
            ),
            BusyMaxMenuEntry(
              value: 'rename',
              label: context.l10n.rename,
              icon: Icons.edit_outlined,
            ),
            BusyMaxMenuEntry(
              value: 'color',
              label: context.l10n.calendarColor,
              icon: Icons.palette_outlined,
            ),
            BusyMaxMenuEntry(
              value: 'unsubscribe',
              label: context.l10n.unsubscribe,
              icon: YaruIcons.trash,
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountHeaderRow extends StatelessWidget {
  const _AccountHeaderRow({
    required this.account,
    required this.expanded,
    required this.onToggleExpanded,
    required this.actions,
    required this.onActionSelected,
  });

  final AccountEntity account;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final List<_AccountHeaderCollectionAction> actions;
  final ValueChanged<AccountHeaderCollectionAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryLabel = _accountHeaderSecondaryLabel(account);
    final hasSecondaryLabel =
        secondaryLabel != null && secondaryLabel.isNotEmpty;
    final providerName = _accountProviderName(context, account.provider);
    final accountSemanticsLabel = [
      providerName,
      account.displayLabel,
      if (hasSecondaryLabel) secondaryLabel,
    ].join(', ');
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
            child: Semantics(
              key: ValueKey(('account-identity', account.id)),
              container: true,
              label: accountSemanticsLabel,
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasSecondaryLabel)
                      Text(
                        account.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasSecondaryLabel
                                ? secondaryLabel
                                : account.displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: hasSecondaryLabel
                                ? Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  )
                                : Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        const SizedBox(width: BusyMaxSpacing.xs),
                        _AccountProviderIndicator(
                          key: ValueKey((
                            'account-provider-indicator',
                            account.id,
                          )),
                          provider: account.provider,
                          providerName: providerName,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: BusyMaxSpacing.xs),
          if (actions.isNotEmpty) ...[
            BusyMaxMenuButton<AccountHeaderCollectionAction>(
              key: ValueKey(('account-collection-options', account.id)),
              tooltip: context.l10n.options,
              highlightWhenOpen: false,
              triggerBuilder: (context, trigger) => trigger.anchor(
                child: Semantics(
                  expanded: trigger.isOpen,
                  button: true,
                  child: BusyMaxHeaderIconButton(
                    tooltip: context.l10n.options,
                    iconSize: BusyMaxSizes.sidebarActionIcon,
                    icon: const Icon(YaruIcons.view_more),
                    focusNode: trigger.focusNode,
                    onPressed: trigger.onPressed,
                    foregroundColor: colorScheme.onSurfaceVariant,
                    backgroundColor: busyMaxSubtleButtonBackground(context),
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                ),
              ),
              onSelected: onActionSelected,
              entries: [
                for (final item in actions)
                  BusyMaxMenuEntry(
                    value: item.action,
                    label: switch (item.action) {
                      AccountHeaderCollectionAction.newCalendar =>
                        '${context.l10n.newCalendar}…',
                      AccountHeaderCollectionAction.newTaskList =>
                        '${context.l10n.newTaskList}…',
                    },
                    icon: YaruIcons.plus,
                    enabled: item.enabled,
                  ),
              ],
            ),
            const SizedBox(width: BusyMaxSpacing.xs),
          ],
          BusyMaxHeaderIconButton(
            key: ValueKey(('account-collapse', account.id)),
            tooltip: expanded
                ? MaterialLocalizations.of(context).expandedIconTapHint
                : MaterialLocalizations.of(context).collapsedIconTapHint,
            iconSize: BusyMaxSizes.sidebarActionIcon,
            icon: AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                BusyMaxGlyphs.collapsedFor(Directionality.of(context)),
                size: 16,
              ),
            ),
            onPressed: onToggleExpanded,
            foregroundColor: colorScheme.onSurfaceVariant,
            backgroundColor: busyMaxSubtleButtonBackground(context),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

String? _accountHeaderSecondaryLabel(AccountEntity account) {
  final secondaryLabel = account.secondaryLabel;
  if (secondaryLabel != null && secondaryLabel.isNotEmpty) {
    return secondaryLabel;
  }
  if (account.provider != BusyProvider.nextcloud) return null;

  final authority = Uri.tryParse(account.authority);
  if (authority == null || authority.host.isEmpty) return null;

  final scheme = authority.scheme.toLowerCase();
  final hasDefaultPort =
      (scheme == 'https' && authority.port == 443) ||
      (scheme == 'http' && authority.port == 80);
  if (!authority.hasPort || hasDefaultPort) return authority.host;

  final host = authority.host.contains(':')
      ? '[${authority.host}]'
      : authority.host;
  return '$host:${authority.port}';
}

class _AccountProviderIndicator extends StatelessWidget {
  const _AccountProviderIndicator({
    super.key,
    required this.provider,
    required this.providerName,
  });

  static const double _diameter = 16;

  final BusyProvider provider;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: providerName,
      excludeFromSemantics: true,
      child: SizedBox.square(
        dimension: _diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Center(
            child: Text(
              _accountProviderLetter(provider),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _accountProviderLetter(BusyProvider provider) => switch (provider) {
  BusyProvider.google => 'G',
  BusyProvider.microsoft => 'M',
  BusyProvider.nextcloud => 'N',
  BusyProvider.appleICloud => 'A',
  BusyProvider.webCal => 'W',
};

String _accountProviderName(BuildContext context, BusyProvider provider) =>
    switch (provider) {
      BusyProvider.google => context.l10n.googleProvider,
      BusyProvider.microsoft => context.l10n.microsoftProvider,
      BusyProvider.nextcloud => context.l10n.nextcloudProvider,
      BusyProvider.appleICloud => context.l10n.appleICloudProvider,
      BusyProvider.webCal => 'WebCal',
    };

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
        return Column(
          children: [
            if (sources.isEmpty)
              BusyMaxActionRow(
                title: context.l10n.noCalendarsSynced,
                leading: const Icon(YaruIcons.calendar),
              ),
            for (final source in sources)
              _SourceRow(
                key: ValueKey((
                  'schedule-calendar',
                  source.accountId,
                  source.id,
                )),
                account: account,
                source: source,
              ),
          ],
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
  const _TaskListScheduleRow({
    super.key,
    required this.account,
    required this.list,
  });

  final AccountEntity account;
  final TaskListEntity list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final providerWebUri = scheduleTaskProviderWebUri(account);
    final visible = settings.isTaskListVisibleInSchedule(
      list.accountId,
      list.id,
    );
    final title = scheduleTaskListLabel(context, account, list);
    final davCapabilities = list.davCollectionId == null
        ? null
        : ref
              .watch(
                davTaskCollectionCapabilitiesProvider((
                  accountId: list.accountId,
                  taskListId: list.id,
                )),
              )
              .valueOrNull;
    final canRename = _canRenameTaskList(account, list, davCapabilities);
    final canDelete = _canDeleteTaskList(account, list, davCapabilities);
    final renameRestriction = _taskListRenameRestriction(
      context,
      account,
      list,
      canRename,
    );
    final deleteRestriction = _taskListDeleteRestriction(
      context,
      account,
      list,
      canDelete,
    );
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
          key: ValueKey(('task-list-options', list.accountId, list.id)),
          tooltip: context.l10n.options,
          highlightWhenOpen: false,
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                unawaited(_refreshTaskListAccount(context, ref, account.id));
              case 'open':
                if (providerWebUri != null) {
                  unawaited(_openProviderWeb(providerWebUri));
                }
              case 'toggle-reminders':
                unawaited(_setTaskListRemindersEnabled(context, ref, list));
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
            if (providerWebUri != null)
              BusyMaxMenuEntry(
                value: 'open',
                label: context.l10n.openInProvider,
                icon: Icons.open_in_browser_outlined,
              ),
            BusyMaxMenuEntry(
              value: 'toggle-reminders',
              label:
                  '${context.l10n.taskReminders} — '
                  '${list.remindersEnabled ? context.l10n.onState : context.l10n.off}',
              icon: list.remindersEnabled
                  ? Icons.notifications_outlined
                  : Icons.notifications_off_outlined,
            ),
            BusyMaxMenuEntry(
              value: 'rename',
              label: context.l10n.rename,
              icon: Icons.edit_outlined,
              enabled: canRename,
              tooltip: renameRestriction,
            ),
            BusyMaxMenuEntry(
              value: 'delete',
              label:
                  account.provider == BusyProvider.nextcloud &&
                      list.isShared == true
                  ? context.l10n.unshare
                  : context.l10n.delete,
              icon: YaruIcons.trash,
              enabled: canDelete,
              tooltip: deleteRestriction,
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
String scheduleTaskListLabel(
  BuildContext context,
  AccountEntity account,
  TaskListEntity list,
) {
  final provider = switch (account.provider) {
    BusyProvider.google => context.l10n.googleTasksProvider,
    BusyProvider.microsoft => context.l10n.microsoftTodoProvider,
    BusyProvider.appleICloud => context.l10n.appleICloudTasksProvider,
    BusyProvider.nextcloud => context.l10n.nextcloudTasksProvider,
    BusyProvider.webCal => 'WebCal',
  };
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

@visibleForTesting
Uri? scheduleCalendarProviderWebUri(
  AccountEntity account,
  CalendarSourceEntity source,
) {
  if (source.accountId != account.id || source.provider != account.provider) {
    return null;
  }
  return switch (account.provider) {
    BusyProvider.google => Uri.https('calendar.google.com', '/calendar/u/0/r', {
      'cid': source.providerCalendarId,
    }),
    BusyProvider.microsoft => Uri.https(
      'outlook.live.com',
      '/calendar/0/view/month',
    ),
    BusyProvider.appleICloud => null,
    BusyProvider.nextcloud => _safeAccountWebUri(account.authority),
    BusyProvider.webCal => null,
  };
}

@visibleForTesting
Uri? scheduleTaskProviderWebUri(AccountEntity account) {
  return switch (account.provider) {
    BusyProvider.google => Uri.https('tasks.google.com', '/'),
    BusyProvider.microsoft => Uri.https('to-do.office.com', '/tasks/'),
    BusyProvider.appleICloud => null,
    BusyProvider.nextcloud => _safeAccountWebUri(account.authority),
    BusyProvider.webCal => null,
  };
}

Uri? _safeAccountWebUri(String authority) {
  final uri = Uri.tryParse(authority.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  return uri;
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

bool _canRenameTaskList(
  AccountEntity account,
  TaskListEntity list,
  TaskCollectionCapabilities? davCapabilities,
) {
  if (account.provider == BusyProvider.microsoft) {
    return list.canRenameOrDeleteForMicrosoft;
  }
  if (list.davCollectionId != null) {
    return davCapabilities?.supportsListRename ?? false;
  }
  return true;
}

bool _canDeleteTaskList(
  AccountEntity account,
  TaskListEntity list,
  TaskCollectionCapabilities? davCapabilities,
) {
  if (account.provider == BusyProvider.microsoft) {
    return list.canRenameOrDeleteForMicrosoft;
  }
  if (list.davCollectionId != null) {
    return davCapabilities?.supportsListDelete ?? false;
  }
  return true;
}

String? _taskListRenameRestriction(
  BuildContext context,
  AccountEntity account,
  TaskListEntity list,
  bool enabled,
) {
  if (enabled) return null;
  if (account.provider == BusyProvider.microsoft &&
      !list.canRenameOrDeleteForMicrosoft) {
    return context.l10n.builtInMicrosoftListCannotRenameDelete;
  }
  return context.l10n.readOnlyTaskListCannotRename;
}

String? _taskListDeleteRestriction(
  BuildContext context,
  AccountEntity account,
  TaskListEntity list,
  bool enabled,
) {
  if (enabled) return null;
  if (account.provider == BusyProvider.microsoft &&
      !list.canRenameOrDeleteForMicrosoft) {
    return context.l10n.builtInMicrosoftListCannotRenameDelete;
  }
  return context.l10n.taskListCannotDelete;
}

String? _calendarRenameRestriction(
  BuildContext context,
  CalendarSourceEntity source,
) {
  if (source.capabilities.canRenameCalendar) return null;
  if (!calendarManagementCapabilities(source.provider).supportsRename) {
    return context.l10n.calendarManagementUnsupported;
  }
  return context.l10n.readOnlyCalendar;
}

String? _calendarColorRestriction(
  BuildContext context,
  CalendarSourceEntity source,
) {
  if (source.capabilities.canChangeCalendarColor) return null;
  if (!calendarManagementCapabilities(source.provider).supportsColor) {
    return context.l10n.calendarManagementUnsupported;
  }
  return context.l10n.readOnlyCalendar;
}

String? _calendarDeleteRestriction(
  BuildContext context,
  CalendarSourceEntity source,
) {
  if (source.capabilities.canRemoveCalendar) return null;
  if (!calendarManagementCapabilities(source.provider).supportsDelete) {
    return context.l10n.calendarManagementUnsupported;
  }
  if (source.primaryCalendar) {
    return context.l10n.primaryCalendarCannotDelete;
  }
  return context.l10n.calendarCannotRemove;
}

enum AccountHeaderCollectionAction { newCalendar, newTaskList }

final class _AccountHeaderCollectionAction {
  const _AccountHeaderCollectionAction({
    required this.action,
    required this.enabled,
  });

  final AccountHeaderCollectionAction action;
  final bool enabled;
}

Future<void> _createAccountCalendar(
  BuildContext context,
  WidgetRef ref,
  AccountEntity account,
) async {
  final title = await showBusyMaxTextPrompt(
    context,
    title: context.l10n.newCalendar,
    label: context.l10n.title,
    actionLabel: context.l10n.create,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (!context.mounted || title == null || title.trim().isEmpty) return;
  try {
    final result = await ref
        .read(calendarCollectionCreationServiceProvider)
        .createCalendar(accountId: account.id, title: title);
    if (context.mounted &&
        result.outcome ==
            CalendarCollectionCreationOutcome.createdRefreshPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.calendarCreatedRefreshPending)),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showCalendarMutationFailure(
        context,
        context.l10n.calendarCreateFailed(
          syncFailureMessage(
            error,
            networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
          ),
        ),
      );
    }
  }
}

Future<void> _createAccountTaskList(
  BuildContext context,
  WidgetRef ref,
  AccountEntity account,
) async {
  final title = await showBusyMaxTextPrompt(
    context,
    title: context.l10n.newTaskList,
    label: context.l10n.title,
    actionLabel: context.l10n.create,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (!context.mounted || title == null || title.trim().isEmpty) return;
  try {
    await ref
        .read(taskListsRepositoryForAccountProvider(account.id))
        .createTaskList(title);
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.taskListCreateFailed(
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
}

Future<void> _setCalendarRemindersEnabled(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  try {
    await ref
        .read(calendarRepositoryProvider)
        .setSourceRemindersEnabled(source.id, !source.remindersEnabled);
  } on Object {
    if (context.mounted) {
      _showCalendarMutationFailure(context, context.l10n.operationFailed);
    }
  }
}

Future<void> _setTaskListRemindersEnabled(
  BuildContext context,
  WidgetRef ref,
  TaskListEntity list,
) async {
  try {
    await ref
        .read(taskListsRepositoryForAccountProvider(list.accountId))
        .setRemindersEnabled(list.id, !list.remindersEnabled);
  } on Object {
    if (context.mounted) {
      _showCalendarMutationFailure(context, context.l10n.operationFailed);
    }
  }
}

Future<void> _changeCalendarColor(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  final choice = await showCalendarColorDialog(
    context,
    provider: source.provider,
    currentBackgroundColor: source.backgroundColor,
    currentColorId: source.colorId,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (!context.mounted || choice == null) return;
  try {
    await ref
        .read(calendarRepositoryProvider)
        .setSourceColor(source.id, choice);
    _requestCalendarMutationSync(ref, source.accountId);
  } on Object catch (error) {
    if (context.mounted) {
      _showCalendarMutationFailure(
        context,
        context.l10n.calendarUpdateFailed(
          syncFailureMessage(
            error,
            networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
          ),
        ),
      );
    }
  }
}

Future<void> _renameCalendar(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  final title = await showBusyMaxTextPrompt(
    context,
    title: source.capabilities.renameMode == CalendarRenameMode.personal
        ? context.l10n.setCustomCalendarName
        : context.l10n.rename,
    label: context.l10n.title,
    actionLabel: source.capabilities.renameMode == CalendarRenameMode.personal
        ? context.l10n.setAction
        : context.l10n.rename,
    initialValue: source.summary,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (!context.mounted ||
      title == null ||
      title.trim().isEmpty ||
      title.trim() == source.summary) {
    return;
  }
  try {
    await ref
        .read(calendarRepositoryProvider)
        .renameLocalSource(source.id, title.trim());
    _requestCalendarMutationSync(ref, source.accountId);
  } on Object catch (error) {
    if (context.mounted) {
      _showCalendarMutationFailure(
        context,
        context.l10n.calendarUpdateFailed(
          syncFailureMessage(
            error,
            networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
          ),
        ),
      );
    }
  }
}

Future<void> _deleteCalendar(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  final removeFromList =
      source.capabilities.removalMode == CalendarRemovalMode.removeFromList;
  final confirmed = await showBusyMaxConfirm(
    context,
    title: removeFromList
        ? context.l10n.removeFromMyCalendars
        : context.l10n.delete,
    message: removeFromList
        ? context.l10n.removeCalendarConfirmation(source.summary)
        : context.l10n.deleteCalendarConfirmation(source.summary),
    confirmLabel: removeFromList
        ? context.l10n.removeAction
        : context.l10n.delete,
    destructive: true,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref.read(calendarRepositoryProvider).deleteLocalSource(source.id);
    _requestCalendarMutationSync(ref, source.accountId);
  } on Object catch (error) {
    if (context.mounted) {
      final message =
          error is CalendarMutationNotAllowed &&
              error.reason == CalendarMutationDenialReason.pendingChanges
          ? context.l10n.calendarPendingChangesPreventRemoval
          : context.l10n.calendarDeleteFailed(
              syncFailureMessage(
                error,
                networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
              ),
            );
      _showCalendarMutationFailure(context, message);
    }
  }
}

void _requestCalendarMutationSync(WidgetRef ref, String accountId) {
  ref
      .read(pendingCalendarMutationSyncRequesterForAccountProvider(accountId))
      .request();
}

void _showCalendarMutationFailure(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
  if (!context.mounted ||
      title == null ||
      title.trim().isEmpty ||
      title.trim() == list.title) {
    return;
  }
  try {
    await ref
        .read(taskListsRepositoryForAccountProvider(list.accountId))
        .renameTaskList(list.id, title.trim());
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.taskListRenameFailed(
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
}

Future<void> _deleteTaskList(
  BuildContext context,
  WidgetRef ref,
  TaskListEntity list,
) async {
  final confirmed = await showBusyMaxConfirm(
    context,
    title: list.isShared == true
        ? context.l10n.unshare
        : context.l10n.deleteList,
    message: list.isShared == true
        ? context.l10n.unshareTaskListConfirmation(list.title)
        : context.l10n.deleteTaskListConfirmation(list.title),
    confirmLabel: list.isShared == true
        ? context.l10n.unshare
        : context.l10n.delete,
    destructive: true,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref
        .read(taskListsRepositoryForAccountProvider(list.accountId))
        .deleteTaskList(list.id);
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.taskListDeleteFailed(
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
}

Future<WebCalSubscriptionEntity?> _subscriptionForSource(
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  final subscriptions = await ref
      .read(webCalSubscriptionServiceProvider)
      .listSubscriptions();
  return subscriptions
      .where((subscription) => subscription.calendarSourceId == source.id)
      .firstOrNull;
}

Future<void> _refreshSubscriptionSource(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  try {
    final subscription = await _subscriptionForSource(ref, source);
    if (subscription == null) return;
    await ref
        .read(webCalSubscriptionServiceProvider)
        .refreshSubscription(subscription.id, force: true);
  } on Object catch (error) {
    if (context.mounted) _showWebCalError(context, error);
  }
}

Future<void> _renameSubscriptionSource(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  final name = await showBusyMaxTextPrompt(
    context,
    title: context.l10n.rename,
    label: context.l10n.subscriptionName,
    actionLabel: context.l10n.rename,
    initialValue: source.summary,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (name == null || !context.mounted) return;
  try {
    final subscription = await _subscriptionForSource(ref, source);
    if (subscription == null) return;
    await ref
        .read(webCalSubscriptionServiceProvider)
        .renameSubscription(subscription.id, name);
  } on Object catch (error) {
    if (context.mounted) _showWebCalError(context, error);
  }
}

Future<void> _colorSubscriptionSource(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  final color = await showBusyMaxTextPrompt(
    context,
    title: context.l10n.calendarColor,
    label: context.l10n.subscriptionColor,
    actionLabel: context.l10n.save,
    initialValue: source.backgroundColor,
    message: context.l10n.subscriptionColorHelp,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (color == null || !context.mounted) return;
  try {
    final subscription = await _subscriptionForSource(ref, source);
    if (subscription == null) return;
    await ref
        .read(webCalSubscriptionServiceProvider)
        .changeSubscriptionColor(subscription.id, color);
  } on Object catch (error) {
    if (context.mounted) _showWebCalError(context, error);
  }
}

Future<void> _unsubscribeSource(
  BuildContext context,
  WidgetRef ref,
  CalendarSourceEntity source,
) async {
  final confirmed = await showBusyMaxConfirm(
    context,
    title: context.l10n.unsubscribeCalendarTitle(source.summary),
    message: context.l10n.unsubscribeCalendarConfirmation,
    confirmLabel: context.l10n.unsubscribe,
    destructive: true,
    headerBarService: ref.read(linuxHeaderBarServiceProvider),
  );
  if (!confirmed || !context.mounted) return;
  try {
    final subscription = await _subscriptionForSource(ref, source);
    if (subscription == null) return;
    await ref
        .read(webCalSubscriptionServiceProvider)
        .unsubscribe(subscription.id);
  } on Object catch (error) {
    if (context.mounted) _showWebCalError(context, error);
  }
}

void _showWebCalError(BuildContext context, Object error) {
  final code = switch (error) {
    WebCalSubscriptionException(:final code) => code,
    _ => 'WebCalOperationFailed',
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.subscriptionOperationFailed(code))),
  );
}
