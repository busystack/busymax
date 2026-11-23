import '../../features/sync/sync_request.dart';
import 'windows_sync_feedback.dart';
import '../../l10n/nextcloud_collection_error_description.dart';
import '../../schedule/schedule_task_list_actions.dart';
import '../../l10n/dav_collection_error_description.dart';

import 'dart:async';

import 'windows_nextcloud_dialogs.dart';
import 'windows_dav_account_dialogs.dart';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../calendar_providers/calendar_colors.dart';
import '../../dav/dav_errors.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/accounts/domain/account_collection_creation_capabilities.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/connectivity/network_connectivity_service.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/schedule_sidebar_order.dart';
import '../../schedule/schedule_sidebar_sources.dart';
import '../../schedule/schedule_sidebar_visibility_icon.dart';
import '../../schedule/schedule_source_visibility.dart';
import '../common/busymax_glyph.dart';
import 'windows_busymax_glyphs.dart';

class WindowsScheduleSourcePane extends ConsumerStatefulWidget {
  const WindowsScheduleSourcePane({
    required this.firstWeekday,
    required this.selectedDate,
    required this.accounts,
    required this.calendarSources,
    required this.taskLists,
    required this.selectedCalendarSourceIds,
    required this.onDateSelected,
    required this.onCalendarVisibilityChanged,
    required this.onTaskListVisibilityChanged,
    required this.onSourcesChanged,
    this.onAddAccount,
    this.onAccountSettings,
    this.accountInventoryResolved = true,
    super.key,
  });

  final DateTime selectedDate;
  final int firstWeekday;
  final List<AccountEntity> accounts;
  final List<CalendarSourceEntity> calendarSources;
  final List<TaskListEntity> taskLists;
  final Set<String> selectedCalendarSourceIds;
  final ValueChanged<DateTime> onDateSelected;
  final void Function(CalendarSourceEntity source, bool visible)
  onCalendarVisibilityChanged;
  final void Function(TaskListEntity list, bool visible)
  onTaskListVisibilityChanged;
  final VoidCallback onSourcesChanged;
  final VoidCallback? onAddAccount;
  final ValueChanged<String>? onAccountSettings;
  final bool accountInventoryResolved;

  @override
  ConsumerState<WindowsScheduleSourcePane> createState() =>
      _WindowsScheduleSourcePaneState();
}

class _WindowsScheduleSourcePaneState
    extends ConsumerState<WindowsScheduleSourcePane> {
  final _snapshots = StreamController<WindowsScheduleSourcePane>();
  late final StreamSubscription<WindowsScheduleSourcePane> _snapshotListener;

  @override
  void initState() {
    super.initState();
    _snapshotListener = _snapshots.stream.listen(_registerSnapshot);
    _snapshots.add(widget);
  }

  void _registerSnapshot(WindowsScheduleSourcePane snapshot) {
    final controller = ref.read(appSettingsControllerProvider.notifier);
    unawaited(
      controller.registerSidebarIds(
        SidebarOrderSection.accounts,
        snapshot.accounts.map((account) => account.id),
      ),
    );
    for (final account in snapshot.accounts) {
      unawaited(
        controller.registerSidebarIds(
          SidebarOrderSection.calendars,
          snapshot.calendarSources
              .where((source) => source.accountId == account.id)
              .map((source) => source.id),
          accountId: account.id,
        ),
      );
      unawaited(
        controller.registerSidebarIds(
          SidebarOrderSection.taskLists,
          snapshot.taskLists
              .where((list) => list.accountId == account.id)
              .map((list) => list.id),
          accountId: account.id,
        ),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_snapshotListener.cancel());
    unawaited(_snapshots.close());
    super.dispose();
  }

  late DateTime _displayedMonth = DateTime(
    widget.selectedDate.year,
    widget.selectedDate.month,
  );

  @override
  void didUpdateWidget(covariant WindowsScheduleSourcePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _snapshots.add(widget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      _displayedMonth = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final settings = ref.watch(appSettingsControllerProvider);
    final order = settings.sidebarOrder;
    final orderedAccounts = order.apply(
      SidebarOrderSection.accounts,
      widget.accounts,
      (account) => account.id,
    );
    final authenticationAccounts = orderedAccounts
        .where((account) => !account.isSubscription)
        .toList();
    final subscriptionAccounts = orderedAccounts
        .where((account) => account.isSubscription)
        .toList();
    final accounts = [...authenticationAccounts, ...subscriptionAccounts];
    final authenticationIds = authenticationAccounts
        .map((account) => account.id)
        .toList();
    final subscriptionIds = subscriptionAccounts
        .map((account) => account.id)
        .toList();
    return ColoredBox(
      color: FluentTheme.of(context).cardColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _MiniMonth(
              firstWeekday: widget.firstWeekday,
              displayedMonth: _displayedMonth,
              selectedDate: widget.selectedDate,
              locale: locale,
              onPrevious: () => setState(() {
                _displayedMonth = DateTime(
                  _displayedMonth.year,
                  _displayedMonth.month - 1,
                );
              }),
              onNext: () => setState(() {
                _displayedMonth = DateTime(
                  _displayedMonth.year,
                  _displayedMonth.month + 1,
                );
              }),
              onSelected: widget.onDateSelected,
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (widget.accountInventoryResolved &&
                    authenticationAccounts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Button(
                      key: const ValueKey('schedule-add-account'),
                      onPressed: widget.onAddAccount,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(windowsBusyMaxGlyph(BusyMaxGlyph.add)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(l10n.addAccount)),
                        ],
                      ),
                    ),
                  ),
                for (final account in accounts) ...[
                  if (account.isSubscription &&
                      account.id == subscriptionIds.first)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        14,
                        10,
                        8,
                        4,
                      ),
                      child: Text(
                        l10n.subscriptions,
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                    ),
                  _AccountHeader(
                    online:
                        (ref.watch(networkAvailabilityProvider).valueOrNull ??
                            ref
                                .read(networkConnectivityMonitorProvider)
                                .availability) !=
                        NetworkAvailability.offline,
                    key: ValueKey(('schedule-account', account.id)),
                    account: account,
                    visibility: ScheduleAccountVisibility.fromSources(
                      accountId: account.id,
                      settings: settings,
                      calendars: _calendarsFor(account.id),
                      taskLists: _taskListsFor(account.id),
                      selectedCalendarIds: widget.selectedCalendarSourceIds,
                    ),
                    onAccountSettings: widget.onAccountSettings == null
                        ? null
                        : () => widget.onAccountSettings!(account.id),
                    movementItems: _movementItems(
                      context,
                      SidebarOrderSection.accounts,
                      account.id,
                      account.isSubscription
                          ? subscriptionIds
                          : authenticationIds,
                    ),
                    capabilities: AccountCollectionCreationCapabilities.resolve(
                      account: account,
                      networkAvailability:
                          ref.watch(networkAvailabilityProvider).valueOrNull ??
                          ref
                              .read(networkConnectivityMonitorProvider)
                              .availability,
                    ),
                    onCreateCalendar: () => unawaited(_createCalendar(account)),
                    onCreateTaskList: () => unawaited(_createTaskList(account)),
                  ),
                  for (final source in _calendarsFor(account.id))
                    _VisibilityRow(
                      key: ValueKey((
                        'schedule-calendar',
                        account.id,
                        source.id,
                      )),
                      icon: BusyMaxGlyph.calendar,
                      scope: calendarSyncScope(source.accountId, source.id),
                      iconColor: _calendarSourceColor(source),
                      title: source.summary,
                      selected: widget.selectedCalendarSourceIds.contains(
                        source.id,
                      ),
                      accountVisible: settings.isAccountVisibleInSchedule(
                        account.id,
                      ),
                      onChanged: (value) =>
                          widget.onCalendarVisibilityChanged(source, value),
                      menuItems: _calendarMenuItems(context, source),
                    ),
                  for (final list in _taskListsFor(account.id))
                    _VisibilityRow(
                      key: ValueKey((
                        'schedule-task-list',
                        account.id,
                        list.id,
                      )),
                      icon: BusyMaxGlyph.task,
                      scope: taskListSyncScope(list.accountId, list.id),
                      title: list.title,
                      selected: settings.isTaskListVisibleInSchedule(
                        list.accountId,
                        list.id,
                      ),
                      accountVisible: settings.isAccountVisibleInSchedule(
                        account.id,
                      ),
                      onChanged: (value) =>
                          widget.onTaskListVisibilityChanged(list, value),
                      menuItems: _taskListMenuItems(context, account, list),
                    ),
                ],
                if (accounts.isNotEmpty &&
                    widget.calendarSources.isEmpty &&
                    widget.taskLists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.scheduleNoSources),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<CalendarSourceEntity> _calendarsFor(String accountId) => ref
      .read(appSettingsControllerProvider)
      .sidebarOrder
      .apply(
        SidebarOrderSection.calendars,
        calendarSourcesShownInSidebar(
          widget.calendarSources,
          accountId: accountId,
        ),
        (source) => source.id,
        accountId: accountId,
      );

  List<TaskListEntity> _taskListsFor(String accountId) => ref
      .read(appSettingsControllerProvider)
      .sidebarOrder
      .apply(
        SidebarOrderSection.taskLists,
        widget.taskLists.where(
          (list) => list.accountId == accountId && !list.pendingDelete,
        ),
        (list) => list.id,
        accountId: accountId,
      );

  List<MenuFlyoutItem> _movementItems(
    BuildContext context,
    SidebarOrderSection section,
    String id,
    List<String> siblings, {
    String? accountId,
  }) {
    final order = ref.read(appSettingsControllerProvider).sidebarOrder;
    final l10n = AppLocalizations.of(context);
    return [
      for (final offset in [-1, 1])
        MenuFlyoutItem(
          leading: Icon(
            offset == -1 ? FluentIcons.up : FluentIcons.down,
            size: 16,
          ),
          text: Text(offset == -1 ? l10n.moveUp : l10n.moveDown),
          onPressed: order.canMove(id, offset, siblings)
              ? () => unawaited(
                  ref
                      .read(appSettingsControllerProvider.notifier)
                      .moveSidebarItem(
                        section,
                        id,
                        offset,
                        siblings,
                        accountId: accountId,
                      ),
                )
              : null,
        ),
    ];
  }

  List<MenuFlyoutItem> _calendarMenuItems(
    BuildContext context,
    CalendarSourceEntity source,
  ) {
    final l10n = AppLocalizations.of(context);
    final scope = calendarSyncScope(source.accountId, source.id);
    return [
      MenuFlyoutItem(
        text: Text(l10n.refreshCalendar),
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.refresh)),
        onPressed: ref.watch(accountSyncActivityProvider).busy(scope)
            ? null
            : () => unawaited(refreshWindowsScope(context, ref, scope)),
      ),
      if ((source.provider == BusyProvider.nextcloud ||
              source.provider == BusyProvider.caldav) &&
          source.davCollectionId != null)
        MenuFlyoutItem(
          text: Text(l10n.nextcloudCollectionSettings),
          onPressed: () => unawaited(
            source.provider == BusyProvider.caldav
                ? showWindowsCalDavCollectionDialog(
                    context,
                    source.davCollectionId!,
                  )
                : showWindowsNextcloudCollectionDialog(
                    context,
                    accountId: source.accountId,
                    collectionId: source.davCollectionId!,
                  ),
          ),
        ),
      ..._movementItems(
        context,
        SidebarOrderSection.calendars,
        source.id,
        _calendarsFor(source.accountId).map((source) => source.id).toList(),
        accountId: source.accountId,
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.reminder)),
        text: Text(
          '${l10n.eventReminders} — '
          '${source.remindersEnabled ? l10n.onState : l10n.off}',
        ),
        onPressed: () => unawaited(_toggleCalendarReminders(source)),
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.settings)),
        text: Text(l10n.calendarColor),
        onPressed: source.capabilities.canChangeCalendarColor
            ? () => unawaited(_changeCalendarColor(source))
            : null,
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.edit)),
        text: Text(l10n.rename),
        onPressed: source.capabilities.canRenameCalendar
            ? () => unawaited(_renameCalendar(source))
            : null,
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.delete)),
        text: Text(
          source.capabilities.removalMode == CalendarRemovalMode.removeFromList
              ? (source.provider == BusyProvider.nextcloud
                    ? l10n.nextcloudRemoveShared
                    : l10n.removeFromMyCalendars)
              : l10n.delete,
        ),
        onPressed: source.capabilities.canRemoveCalendar
            ? () => unawaited(_deleteCalendar(source))
            : null,
      ),
    ];
  }

  List<MenuFlyoutItem> _taskListMenuItems(
    BuildContext context,
    AccountEntity account,
    TaskListEntity list,
  ) {
    final l10n = AppLocalizations.of(context);
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
    final scope = taskListSyncScope(list.accountId, list.id);
    return [
      MenuFlyoutItem(
        text: Text(l10n.refreshList),
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.refresh)),
        onPressed: ref.watch(accountSyncActivityProvider).busy(scope)
            ? null
            : () => unawaited(refreshWindowsScope(context, ref, scope)),
      ),
      if ((account.provider == BusyProvider.nextcloud ||
              account.provider == BusyProvider.caldav) &&
          list.davCollectionId != null)
        MenuFlyoutItem(
          text: Text(l10n.nextcloudCollectionSettings),
          onPressed: () => unawaited(
            account.provider == BusyProvider.caldav
                ? showWindowsCalDavCollectionDialog(
                    context,
                    list.davCollectionId!,
                  )
                : showWindowsNextcloudCollectionDialog(
                    context,
                    accountId: list.accountId,
                    collectionId: list.davCollectionId!,
                  ),
          ),
        ),
      ..._movementItems(
        context,
        SidebarOrderSection.taskLists,
        list.id,
        _taskListsFor(account.id).map((list) => list.id).toList(),
        accountId: account.id,
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.reminder)),
        text: Text(
          '${l10n.taskReminders} — '
          '${list.remindersEnabled ? l10n.onState : l10n.off}',
        ),
        onPressed: () => unawaited(_toggleTaskListReminders(list)),
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.edit)),
        text: Text(l10n.rename),
        onPressed: canRename ? () => unawaited(_renameTaskList(list)) : null,
      ),
      MenuFlyoutItem(
        leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.delete)),
        text: Text(
          list.isShared == true
              ? (list.davCollectionId != null
                    ? l10n.nextcloudRemoveShared
                    : l10n.unshare)
              : l10n.deleteList,
        ),
        onPressed: canDelete ? () => unawaited(_deleteTaskList(list)) : null,
      ),
    ];
  }

  Future<void> _createCalendar(AccountEntity account) async {
    final title = await _textPrompt(
      title: AppLocalizations.of(context).newCalendar,
      actionLabel: AppLocalizations.of(context).create,
    );
    if (title == null || !mounted) return;
    await _runMutation(() async {
      final result = await ref
          .read(calendarCollectionCreationServiceProvider)
          .createCalendar(accountId: account.id, title: title);
      if (result.refreshPending && mounted) {
        await _showMessage(
          AppLocalizations.of(context).calendarCreatedRefreshPending,
        );
      }
    });
  }

  Future<void> _createTaskList(AccountEntity account) async {
    final title = await _textPrompt(
      title: AppLocalizations.of(context).newTaskList,
      actionLabel: AppLocalizations.of(context).create,
    );
    if (title == null || !mounted) return;
    await _runMutation(
      () => ref
          .read(taskListsRepositoryForAccountProvider(account.id))
          .createTaskList(title),
    );
  }

  Future<void> _toggleCalendarReminders(CalendarSourceEntity source) =>
      _runMutation(
        () => ref
            .read(calendarRepositoryProvider)
            .setSourceRemindersEnabled(source.id, !source.remindersEnabled),
      );

  Future<void> _toggleTaskListReminders(TaskListEntity list) => _runMutation(
    () => ref
        .read(taskListsRepositoryForAccountProvider(list.accountId))
        .setRemindersEnabled(list.id, !list.remindersEnabled),
  );

  Future<void> _changeCalendarColor(CalendarSourceEntity source) async {
    final choices = calendarColorChoices(source.provider);
    final choice = await showDialog<CalendarColorChoice>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(AppLocalizations.of(context).calendarColor),
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        content: ListView(
          shrinkWrap: true,
          children: [
            for (var index = 0; index < choices.length; index += 1)
              ListTile(
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _colorFromHex(choices[index].backgroundColor),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context).calendarColorOption(index + 1),
                ),
                trailing: _isCurrentCalendarColor(source, choices[index])
                    ? Icon(windowsBusyMaxGlyph(BusyMaxGlyph.check))
                    : null,
                onPressed: () => Navigator.pop(dialogContext, choices[index]),
              ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).cancel),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    await _runCalendarMutation(
      source.accountId,
      () => ref
          .read(calendarRepositoryProvider)
          .setSourceColor(source.id, choice),
    );
  }

  Future<void> _renameCalendar(CalendarSourceEntity source) async {
    final title = await _textPrompt(
      title: source.capabilities.renameMode == CalendarRenameMode.personal
          ? AppLocalizations.of(context).setCustomCalendarName
          : AppLocalizations.of(context).rename,
      actionLabel: AppLocalizations.of(context).rename,
      initialValue: source.summary,
    );
    if (title == null || title == source.summary || !mounted) return;
    await _runCalendarMutation(
      source.accountId,
      () => ref
          .read(calendarRepositoryProvider)
          .renameLocalSource(source.id, title),
    );
  }

  Future<void> _deleteCalendar(CalendarSourceEntity source) async {
    final l10n = AppLocalizations.of(context);
    final removeFromList =
        source.capabilities.removalMode == CalendarRemovalMode.removeFromList;
    final confirmed = await _confirm(
      title: removeFromList
          ? (source.provider == BusyProvider.nextcloud
                ? l10n.nextcloudRemoveShared
                : l10n.removeFromMyCalendars)
          : l10n.delete,
      message: removeFromList
          ? l10n.removeCalendarConfirmation(source.summary)
          : source.isMixedDavCollection
          ? l10n.nextcloudRemoveMixed
          : l10n.deleteCalendarConfirmation(source.summary),
      actionLabel: removeFromList ? l10n.removeAction : l10n.delete,
    );
    if (!confirmed || !mounted) return;
    await _runCalendarMutation(
      source.accountId,
      () => ref.read(calendarRepositoryProvider).deleteLocalSource(source.id),
      pendingChangesMessage: l10n.calendarPendingChangesPreventRemoval,
    );
  }

  Future<void> _renameTaskList(TaskListEntity list) async {
    final l10n = AppLocalizations.of(context);
    final title = await _textPrompt(
      title: l10n.renameList,
      actionLabel: l10n.rename,
      initialValue: list.title,
    );
    if (title == null || title == list.title || !mounted) return;
    await _runMutation(
      () => ref
          .read(taskListsRepositoryForAccountProvider(list.accountId))
          .renameTaskList(list.id, title),
    );
  }

  Future<void> _deleteTaskList(TaskListEntity list) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: list.isShared == true
          ? (list.davCollectionId != null
                ? l10n.nextcloudRemoveShared
                : l10n.unshare)
          : l10n.deleteList,
      message: list.isShared == true
          ? l10n.unshareTaskListConfirmation(list.title)
          : list.isMixedDavCollection
          ? l10n.nextcloudRemoveMixed
          : l10n.deleteTaskListConfirmation(list.title),
      actionLabel: list.isShared == true ? l10n.unshare : l10n.delete,
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      () => ref
          .read(taskListsRepositoryForAccountProvider(list.accountId))
          .deleteTaskList(list.id),
      pendingChangesMessage: l10n.taskListPendingChangesPreventRemoval,
    );
  }

  Future<void> _runCalendarMutation(
    String accountId,
    Future<void> Function() operation, {
    String? pendingChangesMessage,
  }) => _runMutation(() async {
    await operation();
    ref
        .read(pendingCalendarMutationSyncRequesterForAccountProvider(accountId))
        .request();
  }, pendingChangesMessage: pendingChangesMessage);

  Future<void> _runMutation(
    Future<void> Function() operation, {
    String? pendingChangesMessage,
  }) async {
    try {
      await operation();
      if (mounted) widget.onSourcesChanged();
    } on Object catch (error) {
      if (!mounted) return;
      if (localizedCollectionRefreshPending(AppLocalizations.of(context), error)
          case final warning?) {
        await _showMessage(warning);
        return;
      }
      if (mounted) {
        await _showMessage(
          pendingChangesMessage != null &&
                  isDavCollectionPendingChangesError(error)
              ? pendingChangesMessage
              : error is DavException
              ? localizedDavCollectionError(AppLocalizations.of(context), error)
              : AppLocalizations.of(context).operationFailed,
        );
      }
    }
  }

  Future<String?> _textPrompt({
    required String title,
    required String actionLabel,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ContentDialog(
        title: Text(title),
        content: InfoLabel(
          label: AppLocalizations.of(context).title,
          child: TextBox(controller: controller, autofocus: true),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return value == null || value.trim().isEmpty ? null : value.trim();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ContentDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(actionLabel),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _showMessage(String message) => showDialog<void>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppLocalizations.of(context).close),
        ),
      ],
    ),
  );
}

Widget _windowsVisibilityButton(
  BuildContext context,
  Widget icon,
  String tooltip,
  VoidCallback? onPressed,
) => Tooltip(
  message: tooltip,
  child: SizedBox.square(
    dimension: 26,
    child: IconButton(
      onPressed: onPressed,
      icon: icon,
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
    ),
  ),
);

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader({
    super.key,
    required this.account,
    required this.visibility,
    required this.capabilities,
    required this.onCreateCalendar,
    required this.onCreateTaskList,
    required this.onAccountSettings,
    required this.movementItems,
    required this.online,
  });

  final AccountEntity account;
  final ScheduleAccountVisibility visibility;
  final AccountCollectionCreationCapabilities capabilities;
  final VoidCallback onCreateCalendar;
  final VoidCallback onCreateTaskList;
  final VoidCallback? onAccountSettings;
  final List<MenuFlyoutItem> movementItems;
  final bool online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = FluentTheme.of(context);
    final color = theme.resources.textFillColorSecondary;
    final secondaryLabel = scheduleAccountSecondaryLabel(account);
    final invitations = account.provider == BusyProvider.nextcloud
        ? ref
                  .watch(nextcloudPendingInvitationCountProvider(account.id))
                  .valueOrNull ??
              0
        : 0;
    final hasCreation =
        capabilities.supportsCalendarCreation ||
        capabilities.supportsTaskListCreation;
    final visible = visibility != ScheduleAccountVisibility.hidden;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 4),
      child: Row(
        children: [
          if (!account.isSubscription) ...[
            ScheduleSidebarVisibilityIcon(
              key: ValueKey(('account-visibility', account.id)),
              scope: accountSyncScope(account.id),
              label: '${account.provider.displayName}, ${account.displayLabel}',
              actionLabel: scheduleAccountVisibilityAction(context, visibility),
              accountVisibility: visibility,
              visible: visible,
              color: color,
              buttonBuilder: _windowsVisibilityButton,
              warningIcon: FluentIcons.warning,
              icon: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.resources.controlStrokeColorDefault,
                  ),
                ),
                child: Text(
                  scheduleAccountProviderLetter(account.provider),
                  style: theme.typography.caption?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body,
                ),
                if (secondaryLabel != null)
                  Text(
                    secondaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption?.copyWith(color: color),
                  ),
                if (invitations > 0)
                  Text(
                    '${l10n.nextcloudFederationInvitations} ($invitations)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption?.copyWith(color: color),
                  ),
              ],
            ),
          ),
          _windowsSidebarOptions(context, [
            if (capabilities.supportsCalendarCreation)
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.add_event, size: 16),
                text: Text(l10n.newCalendar),
                onPressed: capabilities.calendarActionEnabled
                    ? onCreateCalendar
                    : null,
              ),
            if (capabilities.supportsTaskListCreation)
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.task_add, size: 16),
                text: Text(l10n.newTaskList),
                onPressed: capabilities.taskListActionEnabled
                    ? onCreateTaskList
                    : null,
              ),
            if (hasCreation) const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              text: Text(l10n.refreshAccount),
              leading: Icon(
                windowsBusyMaxGlyph(BusyMaxGlyph.refresh),
                size: 16,
              ),
              onPressed: () => unawaited(
                refreshWindowsScope(context, ref, accountSyncScope(account.id)),
              ),
            ),
            if (!account.isSubscription)
              MenuFlyoutItem(
                text: Text(l10n.scheduleAccountSettings),
                leading: Icon(
                  windowsBusyMaxGlyph(BusyMaxGlyph.settings),
                  size: 16,
                ),
                onPressed: onAccountSettings,
              ),
            if (account.provider == BusyProvider.nextcloud)
              MenuFlyoutItem(
                text: Text(l10n.nextcloudTrash),
                leading: const Icon(FluentIcons.delete, size: 16),
                onPressed: online
                    ? () => unawaited(
                        showWindowsNextcloudTrashDialog(
                          context,
                          accountId: account.id,
                        ),
                      )
                    : null,
              ),
            const MenuFlyoutSeparator(),
            ...movementItems,
          ]),
        ],
      ),
    );
  }
}

Widget _windowsSidebarOptions(
  BuildContext context,
  List<MenuFlyoutItemBase> items,
) => Tooltip(
  message: AppLocalizations.of(context).options,
  child: DropDownButton(
    title: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.more), size: 16),
    items: items,
  ),
);

class _VisibilityRow extends StatelessWidget {
  const _VisibilityRow({
    super.key,
    required this.icon,
    required this.scope,
    required this.title,
    required this.selected,
    required this.accountVisible,
    required this.onChanged,
    required this.menuItems,
    this.iconColor,
  });

  final BusyMaxGlyph icon;
  final SyncScope scope;
  final Color? iconColor;
  final String title;
  final bool selected;
  final bool accountVisible;
  final ValueChanged<bool> onChanged;
  final List<MenuFlyoutItem> menuItems;

  @override
  Widget build(BuildContext context) {
    final visible = accountVisible && selected;
    final color =
        iconColor ?? FluentTheme.of(context).resources.textFillColorSecondary;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 3, 8, 3),
      child: Row(
        children: [
          ScheduleSidebarVisibilityIcon(
            scope: scope,
            label: title,
            actionLabel: scheduleCollectionVisibilityAction(
              context,
              calendar: icon == BusyMaxGlyph.calendar,
              accountVisible: accountVisible,
              visible: visible,
            ),
            visible: visible,
            color: color,
            buttonBuilder: _windowsVisibilityButton,
            warningIcon: FluentIcons.warning,
            icon: Icon(windowsBusyMaxGlyph(icon), size: 16, color: color),
            onPressed: accountVisible ? () => onChanged(!visible) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          _windowsSidebarOptions(context, menuItems),
        ],
      ),
    );
  }
}

Color? _calendarSourceColor(CalendarSourceEntity source) {
  final colorHex = calendarSourceBackgroundColorHex(
    provider: source.provider,
    backgroundColor: source.backgroundColor,
    colorId: source.colorId,
  );
  return colorHex == null ? null : _colorFromHex(colorHex);
}

Color _colorFromHex(String source) {
  final hex = source.trim().replaceFirst('#', '');
  final parsed = int.tryParse(hex, radix: 16);
  return Color(parsed == null ? 0xFF0078D4 : 0xFF000000 | parsed);
}

bool _isCurrentCalendarColor(
  CalendarSourceEntity source,
  CalendarColorChoice choice,
) => switch (source.provider) {
  BusyProvider.google =>
    source.backgroundColor?.toLowerCase() ==
        choice.backgroundColor.toLowerCase(),
  BusyProvider.microsoft => source.colorId == choice.providerValue,
  _ => false,
};

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.displayedMonth,
    required this.firstWeekday,
    required this.selectedDate,
    required this.locale,
    required this.onPrevious,
    required this.onNext,
    required this.onSelected,
  });

  final DateTime displayedMonth;
  final int firstWeekday;
  final DateTime selectedDate;
  final String locale;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(displayedMonth.year, displayedMonth.month);
    final gridStart = DateTime(
      first.year,
      first.month,
      first.day - ((first.weekday - firstWeekday) % DateTime.daysPerWeek),
    );
    final days = [
      for (var offset = 0; offset < 42; offset += 1)
        DateTime(gridStart.year, gridStart.month, gridStart.day + offset),
    ];
    final weekdayBase = DateTime(2026, 1, 5 + firstWeekday - 1);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat.yMMMM(locale).format(displayedMonth),
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
            ),
            IconButton(
              icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.previous)),
              onPressed: onPrevious,
            ),
            IconButton(
              icon: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.next)),
              onPressed: onNext,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var index = 0; index < 7; index += 1)
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat.E(locale)
                        .format(weekdayBase.add(Duration(days: index))),
                    maxLines: 1,
                    style: FluentTheme.of(context).typography.caption,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        for (var week = 0; week < 6; week += 1)
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday += 1)
                Expanded(
                  child: _MiniDayButton(
                    day: days[week * 7 + weekday],
                    inMonth:
                        days[week * 7 + weekday].month == displayedMonth.month,
                    selected: _sameDay(days[week * 7 + weekday], selectedDate),
                    onSelected: onSelected,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _MiniDayButton extends StatelessWidget {
  const _MiniDayButton({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.onSelected,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: 26,
      child: Center(child: Text('${day.day}')),
    );
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Opacity(
        opacity: inMonth || selected ? 1 : 0.55,
        child: selected
            ? FilledButton(onPressed: () => onSelected(day), child: child)
            : Button(onPressed: () => onSelected(day), child: child),
      ),
    );
  }
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
