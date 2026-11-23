import '../../../l10n/nextcloud_collection_error_description.dart';
import '../../../schedule/schedule_task_list_actions.dart';
import '../../../schedule/schedule_provider_links.dart';
export '../../../schedule/schedule_provider_links.dart';
import '../../sync/sync_request.dart';
import '../../sync/linux_sync_feedback.dart';
import '../../../platform/gtk_animation_settings_service.dart';
import '../../../l10n/oauth_error_description.dart';

import 'dart:async';
import 'dart:math' as math;

import '../../../dav/presentation/nextcloud_collection_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_glyphs.dart';
import '../../../calendar_providers/calendar_colors.dart';
import '../../../calendar_providers/calendar_provider_capabilities.dart';
import '../../../dav/dav_errors.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';
import '../../../schedule/schedule_sidebar_order.dart';
import '../../../schedule/schedule_sidebar_sources.dart';
import '../../../schedule/schedule_sidebar_visibility_icon.dart';
import '../../../schedule/schedule_source_visibility.dart';
import '../../../webcal/webcal_subscription_service.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_collection_creation_capabilities.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../connectivity/network_connectivity_service.dart';
import '../../calendar/presentation/calendar_color_dialog.dart';
import '../../sync/sync_auth_error.dart';
import '../../task_lists/data/task_lists_repository.dart';

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
    this.showEndBorder = true,
    this.onAddAccount,
  });

  final DateTime selectedDate;
  final int firstWeekday;
  final List<ScheduleItem> items;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<DateTime> onYearSelected;
  final ValueChanged<DateTime> onWeekSelected;
  final bool showEndBorder;
  final VoidCallback? onAddAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sidebarOrderRegistrationProvider);
    final inventory = ref.watch(accountsStreamProvider);
    final showAddAccount =
        inventory.hasValue &&
        !inventory.isLoading &&
        !inventory.hasError &&
        !inventory.requireValue.any((account) => !account.isSubscription);
    final accounts = ref
        .watch(appSettingsControllerProvider)
        .sidebarOrder
        .apply(
          SidebarOrderSection.accounts,
          ref.watch(accountsStreamProvider).valueOrNull ??
              const <AccountEntity>[],
          (account) => account.id,
        );
    final siblingIds = [
      for (final account in accounts)
        if (!account.isSubscription) account.id,
    ];
    return BusyMaxSidebarSurface(
      showEndBorder: showEndBorder,
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
                if (showAddAccount)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BusyMaxSpacing.md,
                      vertical: BusyMaxSpacing.sm,
                    ),
                    child: BusyMaxPushButton.standard(
                      key: const ValueKey('schedule-add-account'),
                      onPressed: onAddAccount,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(YaruIcons.plus, size: BusyMaxSizes.iconSm),
                          const SizedBox(width: BusyMaxSpacing.sm),
                          Flexible(child: Text(context.l10n.addAccount)),
                        ],
                      ),
                    ),
                  ),
                for (final account in accounts.where(
                  (account) => !account.isSubscription,
                ))
                  _AccountSourcesGroup(
                    key: ValueKey(('schedule-account', account.id)),
                    account: account,
                    siblingIds: siblingIds,
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
  const _SourceRow({
    super.key,
    required this.account,
    required this.source,
    required this.siblingIds,
  });

  final AccountEntity account;
  final CalendarSourceEntity source;
  final List<String> siblingIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerWebUri = scheduleCalendarProviderWebUri(account, source);
    final capabilities = source.capabilities;
    return _CompactSourceRow(
      title: source.summary,
      leading: _CalendarScheduleVisibilityIcon(
        source: source,
        colorHex: calendarSourceBackgroundColorHex(
          provider: source.provider,
          backgroundColor: source.backgroundColor,
          colorId: source.colorId,
        ),
      ),
      trailing: BusyMaxMenuButton<String>(
        key: ValueKey(('calendar-options', source.id)),
        tooltip: context.l10n.options,
        highlightWhenOpen: false,
        triggerBuilder: _sidebarOptionsTrigger,
        onSelected: (value) {
          switch (value) {
            case 'move-up' || 'move-down':
              _moveSidebarItem(
                ref,
                SidebarOrderSection.calendars,
                source.id,
                value,
                siblingIds,
                accountId: account.id,
              );
            case 'refresh':
              unawaited(
                refreshFromLinux(
                  context,
                  ref,
                  calendarSyncScope(source.accountId, source.id),
                ),
              );
            case 'open':
              if (providerWebUri != null) {
                unawaited(_openProviderWeb(providerWebUri));
              }
            case 'toggle-reminders':
              unawaited(_setCalendarRemindersEnabled(context, ref, source));
            case 'color':
              unawaited(_changeCalendarColor(context, ref, source));
            case 'collection-settings':
              unawaited(
                showLinuxNextcloudCollectionDialog(
                  context,
                  accountId: source.accountId,
                  collectionId: source.davCollectionId!,
                ),
              );
            case 'rename':
              unawaited(_renameCalendar(context, ref, source));
            case 'delete':
              unawaited(_deleteCalendar(context, ref, source));
          }
        },
        entries: [
          if (source.provider == BusyProvider.nextcloud &&
              source.davCollectionId != null)
            BusyMaxMenuEntry(
              value: 'collection-settings',
              label: context.l10n.nextcloudCollectionSettings,
              icon: Icons.settings_outlined,
            ),
          ..._movementEntries(context, source.id, siblingIds),
          BusyMaxMenuEntry(
            value: 'refresh',
            label: context.l10n.refreshCalendar,
            icon: YaruIcons.refresh,
            enabled:
                account.isSyncEligible &&
                !ref
                    .watch(accountSyncActivityProvider)
                    .busy(calendarSyncScope(source.accountId, source.id)),
            tooltip: account.needsReconnect
                ? accountReconnectRequiredSyncMessage
                : null,
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
                ? (source.provider == BusyProvider.nextcloud
                      ? context.l10n.nextcloudRemoveShared
                      : context.l10n.removeFromMyCalendars)
                : context.l10n.delete,
            icon: YaruIcons.trash,
            enabled: capabilities.canRemoveCalendar,
            tooltip: _calendarDeleteRestriction(context, source),
            destructive: true,
          ),
        ],
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

Widget _sidebarVisibilityButton(
  BuildContext context,
  Widget icon,
  String tooltip,
  VoidCallback? onPressed,
) => BusyMaxHeaderIconButton(
  tooltip: tooltip,
  icon: icon,
  onPressed: onPressed,
  fixedSize: const Size.square(BusyMaxSizes.sidebarActionButton),
  iconSize: 26,
  backgroundColor: busyMaxSubtleButtonBackground(context),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
);

Widget _sidebarOptionsTrigger(
  BuildContext context,
  BusyMaxMenuTriggerDetails trigger,
) => trigger.anchor(
  child: Semantics(
    expanded: trigger.isOpen,
    child: BusyMaxHeaderIconButton(
      tooltip: context.l10n.options,
      iconSize: BusyMaxSizes.sidebarActionIcon,
      icon: const Icon(YaruIcons.view_more),
      focusNode: trigger.focusNode,
      onPressed: trigger.onPressed,
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      backgroundColor: busyMaxSubtleButtonBackground(context),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  ),
);

class _AccountSourcesGroup extends ConsumerStatefulWidget {
  const _AccountSourcesGroup({
    super.key,
    required this.account,
    required this.siblingIds,
  });

  final AccountEntity account;
  final List<String> siblingIds;

  @override
  ConsumerState<_AccountSourcesGroup> createState() =>
      _AccountSourcesGroupState();
}

class _AccountSourcesGroupState extends ConsumerState<_AccountSourcesGroup>
    with SingleTickerProviderStateMixin {
  var _expanded = true;
  var _creatingCalendar = false;
  var _creatingTaskList = false;
  late final AnimationController _expansion = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: 1,
  );
  bool _disableAnimations = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled) _expansion.value = _expanded ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(covariant _AccountSourcesGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.id != widget.account.id) {
      _expanded = true;
      _expansion.value = 1;
    }
  }

  @override
  void dispose() {
    _expansion.dispose();
    super.dispose();
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
      _AccountHeaderCollectionAction(
        action: AccountHeaderCollectionAction.refresh,
        separatorBefore:
            capabilities.supportsCalendarCreation ||
            capabilities.supportsTaskListCreation,
        enabled:
            account.hasConnectionIssue ||
            account.isSyncEligible &&
                networkAvailability != NetworkAvailability.offline,
      ),
      const _AccountHeaderCollectionAction(
        action: AccountHeaderCollectionAction.settings,
        enabled: true,
      ),
      if (account.provider == BusyProvider.nextcloud)
        _AccountHeaderCollectionAction(
          action: AccountHeaderCollectionAction.trash,
          enabled: networkAvailability != NetworkAvailability.offline,
        ),
      _AccountHeaderCollectionAction(
        action: AccountHeaderCollectionAction.moveUp,
        separatorBefore: true,
        enabled: widget.siblingIds.indexOf(account.id) > 0,
      ),
      _AccountHeaderCollectionAction(
        action: AccountHeaderCollectionAction.moveDown,
        enabled:
            widget.siblingIds.indexOf(account.id) <
            widget.siblingIds.length - 1,
      ),
    ];
    final children = Column(
      children: [
        _AccountCalendarSources(account: account),
        Builder(
          builder: (context) {
            final lists = ref
                .watch(appSettingsControllerProvider)
                .sidebarOrder
                .apply(
                  SidebarOrderSection.taskLists,
                  ref.watch(sidebarTaskListsProvider(account.id)).valueOrNull ??
                      const <TaskListEntity>[],
                  (list) => list.id,
                  accountId: account.id,
                );
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
                    siblingIds: lists.map((list) => list.id).toList(),
                  ),
              ],
            );
          },
        ),
      ],
    );
    return AnimatedBuilder(
      animation: _expansion,
      child: children,
      builder: (context, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AccountHeaderRow(
            account: account,
            expanded: _expanded,
            expansionProgress: _expansion.value,
            onToggleExpanded: _toggleExpanded,
            actions: headerActions,
            onActionSelected: _handleCollectionAction,
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: _expansion.value,
              child: IgnorePointer(
                ignoring: !_expanded,
                child: ExcludeFocus(
                  excluding: !_expanded,
                  child: ExcludeSemantics(
                    excluding: !_expanded,
                    child: TickerMode(enabled: _expanded, child: child!),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    final target = _expanded ? 1.0 : 0.0;
    if (_disableAnimations) {
      _expansion.value = target;
      return;
    }
    final distance = (target - _expansion.value).abs();
    if (distance == 0) return;
    _expansion.animateTo(
      target,
      duration: BusyMaxMotion.accountDisclosure * distance,
      curve: BusyMaxMotion.presentationCurve,
    );
  }

  Future<void> _handleCollectionAction(
    AccountHeaderCollectionAction action,
  ) async {
    switch (action) {
      case AccountHeaderCollectionAction.refresh:
        await refreshFromLinux(
          context,
          ref,
          accountSyncScope(widget.account.id),
        );
      case AccountHeaderCollectionAction.settings:
        await context.push<void>(
          Uri(
            path: '/settings',
            queryParameters: {
              'page': 'accounts',
              'accountDetail': widget.account.id,
            },
          ).toString(),
        );
      case AccountHeaderCollectionAction.trash:
        await showLinuxNextcloudTrashDialog(
          context,
          accountId: widget.account.id,
        );
      case AccountHeaderCollectionAction.moveUp:
      case AccountHeaderCollectionAction.moveDown:
        _moveSidebarItem(
          ref,
          SidebarOrderSection.accounts,
          widget.account.id,
          action == AccountHeaderCollectionAction.moveUp
              ? 'move-up'
              : 'move-down',
          widget.siblingIds,
        );
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
    final sources = ref
        .watch(appSettingsControllerProvider)
        .sidebarOrder
        .apply(
          SidebarOrderSection.subscriptions,
          ref.watch(sidebarSubscriptionSourcesProvider).valueOrNull ??
              const <CalendarSourceEntity>[],
          (source) => source.id,
        );
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
        Column(
          children: [
            for (final source in sources)
              _SubscriptionSourceRow(
                key: ValueKey(('subscription-source', source.id)),
                source: source,
                siblingIds: sources.map((source) => source.id).toList(),
              ),
          ],
        ),
      ],
    );
  }
}

class _SubscriptionSourceRow extends ConsumerWidget {
  const _SubscriptionSourceRow({
    super.key,
    required this.source,
    required this.siblingIds,
  });

  final CalendarSourceEntity source;
  final List<String> siblingIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CompactSourceRow(
      title: '${source.summary} · ${context.l10n.readOnlySharedCollection}',
      leading: _CalendarScheduleVisibilityIcon(
        source: source,
        colorHex: source.backgroundColor,
      ),
      trailing: BusyMaxMenuButton<String>(
        key: ValueKey(('subscription-options', source.id)),
        tooltip: context.l10n.options,
        highlightWhenOpen: false,
        triggerBuilder: _sidebarOptionsTrigger,
        onSelected: (value) {
          switch (value) {
            case 'move-up' || 'move-down':
              _moveSidebarItem(
                ref,
                SidebarOrderSection.subscriptions,
                source.id,
                value,
                siblingIds,
              );
            case 'refresh':
              unawaited(
                refreshFromLinux(
                  context,
                  ref,
                  calendarSyncScope(source.accountId, source.id),
                ),
              );
            case 'rename':
              unawaited(_renameSubscriptionSource(context, ref, source));
            case 'color':
              unawaited(_colorSubscriptionSource(context, ref, source));
            case 'unsubscribe':
              unawaited(_unsubscribeSource(context, ref, source));
          }
        },
        entries: [
          ..._movementEntries(context, source.id, siblingIds),
          BusyMaxMenuEntry(
            value: 'refresh',
            label: context.l10n.refreshCalendar,
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
    );
  }
}

class _AccountHeaderRow extends ConsumerWidget {
  const _AccountHeaderRow({
    required this.account,
    required this.expanded,
    required this.expansionProgress,
    required this.onToggleExpanded,
    required this.actions,
    required this.onActionSelected,
  });

  final AccountEntity account;
  final bool expanded;
  final double expansionProgress;
  final VoidCallback onToggleExpanded;
  final List<_AccountHeaderCollectionAction> actions;
  final ValueChanged<AccountHeaderCollectionAction> onActionSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = account.provider == BusyProvider.nextcloud
        ? ref
                  .watch(nextcloudPendingInvitationCountProvider(account.id))
                  .valueOrNull ??
              0
        : 0;
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryLabel = scheduleAccountSecondaryLabel(account);
    final hasSecondaryLabel =
        secondaryLabel != null && secondaryLabel.isNotEmpty;
    final providerName = _accountProviderName(context, account.provider);
    final visibility = ScheduleAccountVisibility.fromSources(
      accountId: account.id,
      settings: ref.watch(appSettingsControllerProvider),
      calendars: account.calendarsEnabled
          ? ref.watch(sidebarCalendarSourcesProvider(account.id)).valueOrNull ??
                const <CalendarSourceEntity>[]
          : const <CalendarSourceEntity>[],
      taskLists:
          ref.watch(sidebarTaskListsProvider(account.id)).valueOrNull ??
          const <TaskListEntity>[],
    );
    final visible = visibility != ScheduleAccountVisibility.hidden;
    final accountSemanticsLabel = [
      providerName,
      account.displayLabel,
      if (hasSecondaryLabel) secondaryLabel,
      if (pending > 0)
        '${context.l10n.nextcloudFederationInvitations} ($pending)',
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
          ScheduleSidebarVisibilityIcon(
            key: ValueKey(('account-visibility', account.id)),
            scope: accountSyncScope(account.id),
            label: '$providerName, ${account.displayLabel}',
            actionLabel: scheduleAccountVisibilityAction(context, visibility),
            accountVisibility: visibility,
            visible: visible,
            color: colorScheme.onSurfaceVariant,
            animate:
                ref.watch(gtkAnimationsEnabledProvider).valueOrNull != false,
            buttonBuilder: _sidebarVisibilityButton,
            warningIcon: YaruIcons.warning,
            icon: _AccountProviderIndicator(
              key: ValueKey(('account-provider-indicator', account.id)),
              provider: account.provider,
            ),
            onPressed: () => unawaited(
              ref
                  .read(appSettingsControllerProvider.notifier)
                  .setAccountVisibleInSchedule(
                    accountId: account.id,
                    visible: !visible,
                  ),
            ),
          ),
          const SizedBox(width: BusyMaxSpacing.md),
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
                    Text(
                      account.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (hasSecondaryLabel)
                      Text(
                        secondaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    if (pending > 0)
                      Text(
                        '${context.l10n.nextcloudFederationInvitations} ($pending)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: BusyMaxSpacing.xs),
          BusyMaxHeaderIconButton(
            key: ValueKey(('account-collapse', account.id)),
            tooltip: expanded
                ? MaterialLocalizations.of(context).expandedIconTapHint
                : MaterialLocalizations.of(context).collapsedIconTapHint,
            iconSize: BusyMaxSizes.sidebarActionIcon,
            icon: Transform.rotate(
              angle:
                  expansionProgress *
                  math.pi /
                  2 *
                  (Directionality.of(context) == TextDirection.rtl ? -1 : 1),
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
          const SizedBox(width: BusyMaxSpacing.xs),
          BusyMaxMenuButton<AccountHeaderCollectionAction>(
            key: ValueKey(('account-collection-options', account.id)),
            tooltip: context.l10n.options,
            highlightWhenOpen: false,
            triggerBuilder: _sidebarOptionsTrigger,
            onSelected: onActionSelected,
            entries: [
              for (final item in actions)
                BusyMaxMenuEntry(
                  value: item.action,
                  label: switch (item.action) {
                    AccountHeaderCollectionAction.refresh =>
                      context.l10n.refreshAccount,
                    AccountHeaderCollectionAction.settings =>
                      context.l10n.scheduleAccountSettings,
                    AccountHeaderCollectionAction.trash =>
                      context.l10n.nextcloudTrash,
                    AccountHeaderCollectionAction.newCalendar =>
                      '${context.l10n.newCalendar}…',
                    AccountHeaderCollectionAction.newTaskList =>
                      '${context.l10n.newTaskList}…',
                    AccountHeaderCollectionAction.moveUp => context.l10n.moveUp,
                    AccountHeaderCollectionAction.moveDown =>
                      context.l10n.moveDown,
                  },
                  icon: switch (item.action) {
                    AccountHeaderCollectionAction.refresh => YaruIcons.refresh,
                    AccountHeaderCollectionAction.settings =>
                      YaruIcons.settings,
                    AccountHeaderCollectionAction.trash => YaruIcons.trash,
                    AccountHeaderCollectionAction.moveUp => Icons.arrow_upward,
                    AccountHeaderCollectionAction.moveDown =>
                      Icons.arrow_downward,
                    AccountHeaderCollectionAction.newCalendar =>
                      YaruIcons.calendar_new,
                    AccountHeaderCollectionAction.newTaskList =>
                      YaruIcons.unordered_list_new,
                  },
                  separatorBefore: item.separatorBefore,
                  enabled: item.enabled,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountProviderIndicator extends StatelessWidget {
  const _AccountProviderIndicator({super.key, required this.provider});

  static const double _diameter = 16;

  final BusyProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: _diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Text(
            scheduleAccountProviderLetter(provider),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

String _accountProviderName(BuildContext context, BusyProvider provider) =>
    switch (provider) {
      BusyProvider.google => context.l10n.googleProvider,
      BusyProvider.microsoft => context.l10n.microsoftProvider,
      BusyProvider.nextcloud => context.l10n.nextcloudProvider,
      BusyProvider.appleICloud => context.l10n.appleICloudProvider,
      BusyProvider.webCal => 'WebCal',
      BusyProvider.caldav => 'CalDAV',
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

    final sources = ref
        .watch(appSettingsControllerProvider)
        .sidebarOrder
        .apply(
          SidebarOrderSection.calendars,
          calendarSourcesShownInSidebar(
            ref.watch(sidebarCalendarSourcesProvider(account.id)).valueOrNull ??
                const <CalendarSourceEntity>[],
          ),
          (source) => source.id,
          accountId: account.id,
        );
    return Column(
      children: [
        if (sources.isEmpty)
          BusyMaxActionRow(
            title: context.l10n.noCalendarsSynced,
            leading: const Icon(YaruIcons.calendar),
          ),
        for (final source in sources)
          _SourceRow(
            key: ValueKey(('schedule-calendar', source.accountId, source.id)),
            account: account,
            source: source,
            siblingIds: sources.map((source) => source.id).toList(),
          ),
      ],
    );
  }
}

class _CalendarScheduleVisibilityIcon extends ConsumerWidget {
  const _CalendarScheduleVisibilityIcon({
    required this.source,
    required this.colorHex,
  });

  final CalendarSourceEntity source;
  final String? colorHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountVisible = ref
        .watch(appSettingsControllerProvider)
        .isAccountVisibleInSchedule(source.accountId);
    final visible =
        accountVisible &&
        source.selected &&
        isScheduleCalendarAvailable(source);
    final actionable = accountVisible && isScheduleCalendarAvailable(source);
    final color =
        _colorFromHex(colorHex) ??
        ScheduleProjection.deterministicSourceColor(
          source.id,
          Theme.of(context).colorScheme.brightness,
        );
    return ScheduleSidebarVisibilityIcon(
      key: ValueKey(('calendar-visibility', source.id)),
      scope: calendarSyncScope(source.accountId, source.id),
      label: source.summary,
      actionLabel: scheduleCollectionVisibilityAction(
        context,
        calendar: true,
        accountVisible: accountVisible,
        visible: visible,
      ),
      visible: visible,
      color: color,
      animate: ref.watch(gtkAnimationsEnabledProvider).valueOrNull != false,
      buttonBuilder: _sidebarVisibilityButton,
      warningIcon: YaruIcons.warning,
      icon: Icon(YaruIcons.calendar, size: 16, color: color),
      onPressed: actionable
          ? () => unawaited(
              ref
                  .read(calendarRepositoryProvider)
                  .setSourceSelected(source.id, !visible),
            )
          : null,
    );
  }
}

class _TaskListScheduleRow extends ConsumerWidget {
  const _TaskListScheduleRow({
    super.key,
    required this.account,
    required this.list,
    required this.siblingIds,
  });

  final AccountEntity account;
  final TaskListEntity list;
  final List<String> siblingIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final providerWebUri = scheduleTaskProviderWebUri(account);
    final accountVisible = settings.isAccountVisibleInSchedule(list.accountId);
    final visible =
        accountVisible &&
        settings.isTaskListVisibleInSchedule(list.accountId, list.id);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final normalizedTitle = list.title.trim();
    final title = normalizedTitle.isEmpty
        ? context.l10n.sourceTaskList
        : normalizedTitle;
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
    final canRename = canRenameScheduleTaskList(
      account.provider,
      list,
      davCapabilities,
    );
    final canDelete = canDeleteScheduleTaskList(
      account.provider,
      list,
      davCapabilities,
    );
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
      leading: ScheduleSidebarVisibilityIcon(
        key: ValueKey(('task-list-visibility', list.accountId, list.id)),
        scope: taskListSyncScope(list.accountId, list.id),
        label: title,
        actionLabel: scheduleCollectionVisibilityAction(
          context,
          calendar: false,
          accountVisible: accountVisible,
          visible: visible,
        ),
        visible: visible,
        color: color,
        animate: ref.watch(gtkAnimationsEnabledProvider).valueOrNull != false,
        buttonBuilder: _sidebarVisibilityButton,
        warningIcon: YaruIcons.warning,
        icon: Icon(YaruIcons.task_list, size: 16, color: color),
        onPressed: accountVisible && !list.pendingDelete
            ? () => unawaited(
                ref
                    .read(appSettingsControllerProvider.notifier)
                    .setTaskListVisibleInSchedule(
                      accountId: list.accountId,
                      taskListId: list.id,
                      visible: !visible,
                    ),
              )
            : null,
      ),
      trailing: BusyMaxMenuButton<String>(
        key: ValueKey(('task-list-options', list.accountId, list.id)),
        tooltip: context.l10n.options,
        highlightWhenOpen: false,
        triggerBuilder: _sidebarOptionsTrigger,
        onSelected: (value) {
          switch (value) {
            case 'move-up' || 'move-down':
              _moveSidebarItem(
                ref,
                SidebarOrderSection.taskLists,
                list.id,
                value,
                siblingIds,
                accountId: account.id,
              );
            case 'refresh':
              unawaited(
                refreshFromLinux(
                  context,
                  ref,
                  taskListSyncScope(list.accountId, list.id),
                ),
              );
            case 'open':
              if (providerWebUri != null) {
                unawaited(_openProviderWeb(providerWebUri));
              }
            case 'toggle-reminders':
              unawaited(_setTaskListRemindersEnabled(context, ref, list));
            case 'rename':
              if (canRename) unawaited(_renameTaskList(context, ref, list));
            case 'collection-settings':
              unawaited(
                showLinuxNextcloudCollectionDialog(
                  context,
                  accountId: list.accountId,
                  collectionId: list.davCollectionId!,
                ),
              );
            case 'delete':
              if (canDelete) unawaited(_deleteTaskList(context, ref, list));
          }
        },
        entries: [
          ..._movementEntries(context, list.id, siblingIds),
          if (account.provider == BusyProvider.nextcloud &&
              list.davCollectionId != null)
            BusyMaxMenuEntry(
              value: 'collection-settings',
              label: context.l10n.nextcloudCollectionSettings,
              icon: Icons.settings_outlined,
            ),
          BusyMaxMenuEntry(
            value: 'refresh',
            label: context.l10n.refreshList,
            icon: YaruIcons.refresh,
            enabled:
                account.isSyncEligible &&
                !ref
                    .watch(accountSyncActivityProvider)
                    .busy(taskListSyncScope(list.accountId, list.id)),
            tooltip: account.needsReconnect
                ? accountReconnectRequiredSyncMessage
                : null,
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
    );
  }
}

Color? _colorFromHex(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final hex = value.replaceFirst('#', '');
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xff000000 | parsed);
}

Future<void> _openProviderWeb(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
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

enum AccountHeaderCollectionAction {
  refresh,
  settings,
  trash,
  newCalendar,
  newTaskList,
  moveUp,
  moveDown,
}

List<BusyMaxMenuEntry<String>> _movementEntries(
  BuildContext context,
  String id,
  List<String> siblings,
) => [
  BusyMaxMenuEntry(
    value: 'move-up',
    label: context.l10n.moveUp,
    icon: Icons.arrow_upward,
    enabled: siblings.indexOf(id) > 0,
  ),
  BusyMaxMenuEntry(
    value: 'move-down',
    label: context.l10n.moveDown,
    icon: Icons.arrow_downward,
    enabled:
        siblings.contains(id) && siblings.indexOf(id) < siblings.length - 1,
  ),
];

void _moveSidebarItem(
  WidgetRef ref,
  SidebarOrderSection section,
  String id,
  String action,
  List<String> siblings, {
  String? accountId,
}) {
  unawaited(
    ref
        .read(appSettingsControllerProvider.notifier)
        .moveSidebarItem(
          section,
          id,
          action == 'move-up' ? -1 : 1,
          siblings,
          accountId: accountId,
        ),
  );
}

final class _AccountHeaderCollectionAction {
  const _AccountHeaderCollectionAction({
    required this.action,
    required this.enabled,
    this.separatorBefore = false,
  });

  final bool separatorBefore;
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
  );
  if (!context.mounted || title == null || title.trim().isEmpty) return;
  try {
    final result = await ref
        .read(calendarCollectionCreationServiceProvider)
        .createCalendar(accountId: account.id, title: title);
    if (context.mounted && result.refreshPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.calendarCreatedRefreshPending)),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showCalendarMutationFailure(
        context,
        context.l10n.calendarCreateFailed(
          localizedSyncFailureMessage(
            context.l10n,
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
  );
  if (!context.mounted || title == null || title.trim().isEmpty) return;
  try {
    await ref
        .read(taskListsRepositoryForAccountProvider(account.id))
        .createTaskList(title);
  } on Object catch (error) {
    if (context.mounted) {
      if (localizedCollectionRefreshPending(context.l10n, error)
          case final warning?) {
        _showCalendarMutationFailure(context, warning);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.taskListCreateFailed(
              localizedSyncFailureMessage(
                context.l10n,
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
  );
  if (!context.mounted || choice == null) return;
  try {
    await ref
        .read(calendarRepositoryProvider)
        .setSourceColor(source.id, choice);
    _requestCalendarMutationSync(ref, source.accountId);
  } on Object catch (error) {
    if (context.mounted) {
      if (localizedCollectionRefreshPending(context.l10n, error)
          case final warning?) {
        _showCalendarMutationFailure(context, warning);
        return;
      }
      _showCalendarMutationFailure(
        context,
        context.l10n.calendarUpdateFailed(
          localizedSyncFailureMessage(
            context.l10n,
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
      if (localizedCollectionRefreshPending(context.l10n, error)
          case final warning?) {
        _showCalendarMutationFailure(context, warning);
        return;
      }
      _showCalendarMutationFailure(
        context,
        context.l10n.calendarUpdateFailed(
          localizedSyncFailureMessage(
            context.l10n,
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
        ? (source.provider == BusyProvider.nextcloud
              ? context.l10n.nextcloudRemoveShared
              : context.l10n.removeFromMyCalendars)
        : context.l10n.delete,
    message: removeFromList
        ? context.l10n.removeCalendarConfirmation(source.summary)
        : source.isMixedDavCollection
        ? context.l10n.nextcloudRemoveMixed
        : context.l10n.deleteCalendarConfirmation(source.summary),
    confirmLabel: removeFromList
        ? context.l10n.removeAction
        : context.l10n.delete,
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref.read(calendarRepositoryProvider).deleteLocalSource(source.id);
    _requestCalendarMutationSync(ref, source.accountId);
  } on Object catch (error) {
    if (context.mounted) {
      if (localizedCollectionRefreshPending(context.l10n, error)
          case final warning?) {
        _showCalendarMutationFailure(context, warning);
        return;
      }
      final message =
          (error is CalendarMutationNotAllowed &&
                  error.reason ==
                      CalendarMutationDenialReason.pendingChanges) ||
              isDavCollectionPendingChangesError(error)
          ? context.l10n.calendarPendingChangesPreventRemoval
          : context.l10n.calendarDeleteFailed(
              localizedSyncFailureMessage(
                context.l10n,
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
      if (localizedCollectionRefreshPending(context.l10n, error)
          case final warning?) {
        _showCalendarMutationFailure(context, warning);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.taskListRenameFailed(
              localizedSyncFailureMessage(
                context.l10n,
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
        ? (list.davCollectionId != null
              ? context.l10n.nextcloudRemoveShared
              : context.l10n.unshare)
        : context.l10n.deleteList,
    message: list.isShared == true
        ? context.l10n.unshareTaskListConfirmation(list.title)
        : list.isMixedDavCollection
        ? context.l10n.nextcloudRemoveMixed
        : context.l10n.deleteTaskListConfirmation(list.title),
    confirmLabel: list.isShared == true
        ? context.l10n.unshare
        : context.l10n.delete,
    destructive: true,
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
      if (localizedCollectionRefreshPending(context.l10n, error)
          case final warning?) {
        _showCalendarMutationFailure(context, warning);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDavCollectionPendingChangesError(error)
                ? context.l10n.taskListPendingChangesPreventRemoval
                : context.l10n.taskListDeleteFailed(
                    localizedSyncFailureMessage(
                      context.l10n,
                      error,
                      networkUnavailableMessage:
                          context.l10n.networkOfflineTryAgain,
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
