import '../../../l10n/oauth_error_description.dart';
import '../../../l10n/contacts_error_description.dart';

import 'package:busymax/src/core/auth/authorization_attempt.dart';

import '../../../l10n/registration_description.dart';
import '../../auth/presentation/registration_setup_dialog.dart';
import '../../../core/auth/oauth_registration.dart';

import 'package:busymax/src/l10n/time_format_scope.dart';
import 'package:busymax/src/l10n/week_preferences_scope.dart';

import 'dart:async';
import 'dart:convert';

import '../../../calendar_providers/calendar_mutation.dart';
import '../../../db/app_database.dart' show PendingOp;
import '../../../microsoft_calendar/microsoft_shared_calendar_address.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:yaru/yaru.dart';
import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:uuid/uuid.dart';

import '../../../app/busymax_about_dialog.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/common/busymax_motion_widgets.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_keyboard_shortcuts_dialog.dart';
import '../../../app/busymax_layout.dart';
import '../../../app/busymax_shortcuts.dart';
import '../../../app/linux/linux_page_frame.dart';
import '../../../app/linux/linux_header_style.dart';
import '../../../core/logging/redacting_logger.dart';
import '../../../contacts/busymax_contacts_controller.dart';
import '../../../dav/auth/dav_account_dialogs.dart';
import '../../../dav/presentation/nextcloud_collection_dialog.dart';
import '../../../dav/dav_errors.dart';
import '../../../dav/http/dav_http_transport.dart';
import '../../../dav/mutation/dav_conflict_repository.dart';
import '../../../dav/storage/dav_settings_repository.dart';

import 'package:busymax/src/core/auth/oauth_models.dart';

import '../../../l10n/app_locale.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/common/desktop_services.dart';
import '../../../platform/gtk_header_icon_service.dart';
import '../../../webcal/webcal_subscription_service.dart';
import '../../../webcal/webcal_uri.dart';

import 'package:busymax/src/providers/busy_provider.dart';

import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_connection_state.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../calendar/data/microsoft_shared_calendar_service.dart';
import '../../calendar/data/cloud_calendar_sharing_service.dart';
import '../../calendar/presentation/cloud_calendar_sharing_content.dart';
import '../../calendar/presentation/ical_import_flow.dart';
import '../../connectivity/network_connectivity_service.dart';
import '../../diagnostics/presentation/diagnostics_screen.dart';
import '../../feedback/presentation/feedback_dialog.dart';
import '../../sync/sync_auth_error.dart';
import 'account_settings_feedback.dart';
import '../../task_lists/data/task_lists_repository.dart';
import '../../tasks/presentation/desktop_date_time_fields.dart';
import '../../tasks/domain/task_capabilities.dart';
import '../../schedule/presentation/schedule_toolbar.dart';
import 'account_removal_dialog.dart';
import 'launch_at_login_refresh.dart';

final _settingsLogger = RedactingLogger(Logger('SettingsScreen'));
const _systemLocaleTag = 'system';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.initialPage = SettingsPage.system,
    this.reconnectAccountId,
    this.notificationAccountId,
  });

  final String? reconnectAccountId;
  final String? notificationAccountId;

  final SettingsPage initialPage;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late var _page = widget.initialPage;
  ({String id, bool contactsOnly})? _accountDetails;
  final _contentScroll = ScrollController();
  final _headerBackFocus = FocusNode(debugLabel: 'settings-back');
  final _accountEntryFocus = <String, FocusNode>{};
  double _accountsOverviewOffset = 0;
  String? _originatingAccountEntry;
  int _accountNavigationGeneration = 0;
  BusyProvider? _connectingProvider;
  AuthorizationCancellation? _authorizationCancellation;
  AuthorizationCancellation? _sharedConsentCancellation;
  DavCancellationToken? _davCancellation;
  final _removingAccountIds = <String>{};
  final _registrationRecoveryIds = <String>{};
  final _refreshingAccountIds = <String>{};
  BusyMaxContactsController? _contactOperationsController;
  final _busySubscriptionIds = <String>{};
  final _busyContactAccountIds = <String>{};
  late final LaunchAtLoginRefreshObserver _autostartRefresh;

  String? _handledRecovery;
  Future<void> _openRequestedRecovery() async {
    final id = widget.reconnectAccountId;
    if (id == null || id == _handledRecovery) return;
    _handledRecovery = id;
    final navigationGeneration = _accountNavigationGeneration;
    final account = await ref.read(accountsRepositoryProvider).accountById(id);
    if (!mounted || navigationGeneration != _accountNavigationGeneration) {
      return;
    }
    if (account != null) {
      _openAccountDetails(account.id);
      await _connectAccount(account.provider, reconnecting: account);
    }
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final uri = GoRouterState.of(context).uri;
    if (uri.path == '/settings' && uri.queryParameters['reconnect'] == id) {
      final query = {...uri.queryParameters}..remove('reconnect');
      unawaited(router.replace(uri.replace(queryParameters: query).toString()));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openRequestedRecovery(),
    );
    _autostartRefresh = LaunchAtLoginRefreshObserver(
      () => ref.invalidate(launchAtLoginStateProvider),
    );
  }

  @override
  void dispose() {
    _authorizationCancellation?.cancel();
    _sharedConsentCancellation?.cancel();
    _autostartRefresh.dispose();
    _davCancellation?.cancel();
    for (final id in _busyContactAccountIds) {
      _contactOperationsController?.cancelEnrollment(id);
    }
    _contentScroll.dispose();
    _headerBackFocus.dispose();
    for (final node in _accountEntryFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reconnectAccountId != oldWidget.reconnectAccountId) {
      if (widget.reconnectAccountId == null) _handledRecovery = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openRequestedRecovery(),
      );
    }
    if (oldWidget.initialPage != widget.initialPage &&
        _page != widget.initialPage) {
      _abandonAccountAuthorization();
      _accountDetails = null;
      _page = widget.initialPage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedAccount = ref.watch(selectedAccountProvider);
    final accounts =
        ref.watch(accountManagementStreamProvider).valueOrNull ?? const [];
    final allAccounts =
        ref.watch(accountsStreamProvider).valueOrNull ??
        const <AccountEntity>[];
    final davCollections =
        ref.watch(davCollectionsStreamProvider).valueOrNull ?? const [];
    final davConflicts =
        ref.watch(davConflictsStreamProvider).valueOrNull ?? const [];
    final calendarSources =
        ref.watch(calendarSourcesStreamProvider).valueOrNull ?? const [];
    final taskLists = _page == SettingsPage.schedule
        ? ref.watch(scheduleTaskListsProvider).valueOrNull ??
              const <TaskListEntity>[]
        : const <TaskListEntity>[];
    final subscriptions =
        ref.watch(webCalSubscriptionsProvider).valueOrNull ?? const [];
    final contactAccounts =
        ref.watch(busyMaxContactAccountsProvider).valueOrNull ??
        const <ContactAccount>[];
    final contactSources =
        ref.watch(busyMaxContactSourceSettingsProvider).valueOrNull ??
        const <BusyMaxContactSourceSetting>[];
    final config = ref.watch(buildConfigProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final launchAtLogin = ref.watch(launchAtLoginStateProvider);
    final changingAutostart = ref.watch(launchAtLoginControllerProvider);
    final settingsController = ref.read(appSettingsControllerProvider.notifier);
    final themeController = ref.read(busyMaxThemeControllerProvider);
    final l10n = context.l10n;
    final detailAccount = _accountDetails?.contactsOnly == false
        ? accounts.where((a) => a.id == _accountDetails!.id).firstOrNull
        : null;
    final detailContact = _accountDetails?.contactsOnly == true
        ? contactAccounts.where((a) => a.id == _accountDetails!.id).firstOrNull
        : null;
    final title = _page == SettingsPage.accounts && _accountDetails != null
        ? detailAccount?.displayLabel ??
              detailContact?.displayName ??
              l10n.accounts
        : _settingsPageLabel(context, _page);
    ref.listen(accountManagementStreamProvider, (_, next) {
      final target = _accountDetails;
      if (target != null &&
          !target.contactsOnly &&
          next.hasValue &&
          !next.isLoading &&
          !next.hasError &&
          !next.requireValue.any((a) => a.id == target.id)) {
        _returnAfterAccountDisappeared(target.id);
      }
    });
    ref.listen(busyMaxContactAccountsProvider, (_, next) {
      final target = _accountDetails;
      if (target != null &&
          target.contactsOnly &&
          next.hasValue &&
          !next.isLoading &&
          !next.hasError &&
          !next.requireValue.any((a) => a.id == target.id)) {
        _returnAfterAccountDisappeared(target.id);
      }
    });
    final hasSyncEligibleAccounts = allAccounts.any(
      (account) => account.isSyncEligible,
    );
    final writableCalendars = writableCalendarSources(calendarSources);
    final writableTaskLists = <TaskListEntity>[
      for (final list in taskLists)
        if (!list.pendingDelete &&
            _canCreateTasksInList(ref, allAccounts, list))
          list,
    ];
    final calendarOptions = {
      for (final source in writableCalendars)
        CreationDestination(
          accountId: source.accountId,
          id: source.id,
        ): '${source.summary} · ${_settingsAccountLabel(allAccounts, source.accountId)}',
    };
    final taskListOptions = {
      for (final list in writableTaskLists)
        CreationDestination(
          accountId: list.accountId,
          id: list.id,
        ): '${list.title} · ${_settingsAccountLabel(allAccounts, list.accountId)}',
    };

    final pageBody = switch (_page) {
      SettingsPage.accounts => _AccountManagementSection(
        selectedAccountId: _accountDetails?.contactsOnly == false
            ? _accountDetails?.id
            : null,
        selectedContactAccountId: _accountDetails?.contactsOnly == true
            ? _accountDetails?.id
            : null,
        onOpenAccount: _openAccountDetails,
        onOpenContactAccount: (id) =>
            _openAccountDetails(id, contactsOnly: true),
        entryFocusNode: (id) => _accountEntryFocus.putIfAbsent(
          id,
          () => FocusNode(debugLabel: 'account-entry-$id'),
        ),
        accounts: _selectedAccountFirst(accounts, selectedAccount?.id),
        googleConfigured: config.googleSetupAvailable,
        microsoftConfigured: config.microsoftSetupAvailable,
        connectingProvider: _connectingProvider,
        onAddGoogle: () => unawaited(_connectAccount(BusyProvider.google)),
        onAddMicrosoft: () =>
            unawaited(_connectAccount(BusyProvider.microsoft)),
        onOpenSharedCalendar: (account) =>
            unawaited(_openSharedCalendar(account)),
        onManageCalendarSharing: (account) =>
            unawaited(_manageCalendarSharing(account, calendarSources)),
        onAddApple: () => unawaited(_connectAccount(BusyProvider.appleICloud)),
        onAddNextcloud: () =>
            unawaited(_connectAccount(BusyProvider.nextcloud)),
        onCancelConnection: _cancelAccountConnection,
        onMigrate: (account) => unawaited(
          _connectAccount(
            account.provider,
            reconnecting: account,
            replaceRegistration: true,
          ),
        ),
        onReconnect: (account) =>
            unawaited(_connectAccount(account.provider, reconnecting: account)),
        removingAccountIds: _removingAccountIds,
        registrationRecoveryIds: _registrationRecoveryIds,
        refreshingAccountIds: _refreshingAccountIds,
        onRetryContacts: (contact) => unawaited(_retryContacts(contact)),
        onReconnectContacts: (contact) =>
            unawaited(_reconnectContacts(contact)),
        onRemoveAccount: (account) =>
            unawaited(_removeAccount(context, ref, account)),
        contactAccounts: contactAccounts,
        contactSources: contactSources,
        busyContactAccountIds: _busyContactAccountIds,
        onEnableContacts: (account) => unawaited(_enableContacts(account)),
        onDisableContacts: (account) => unawaited(_disableContacts(account.id)),
        onSourceEnabled: (sourceKey, enabled) => ref
            .read(busyMaxContactsControllerProvider)
            .setSourceEnabled(sourceKey, enabled: enabled),
        onAddCardDavContacts: () => unawaited(_addCardDavContacts()),
        onAddNextcloudContacts: () => unawaited(_addNextcloudContacts()),
        onRemoveContactsOnly: (account) =>
            unawaited(_disableContacts(account.id)),
        davCollections: davCollections,
        calendarSources: calendarSources,
        onCalendarSelected: (source, selected) => unawaited(
          ref
              .read(calendarRepositoryProvider)
              .setSourceSelected(source.id, selected),
        ),
        onCalendarProviderVisibilityChanged: (source, visible) =>
            unawaited(_setCalendarProviderVisibility(source, visible)),
        davConflicts: davConflicts,
        onRefreshCollections: (account) =>
            unawaited(_refreshCollections(account)),
        onEventsSelected: (collection, selected) => unawaited(
          ref
              .read(davSettingsRepositoryProvider)
              .setEventsSelected(collection.id, selected),
        ),
        onTasksSelected: (collection, selected) => unawaited(
          ref
              .read(davSettingsRepositoryProvider)
              .setTasksSelected(collection.id, selected),
        ),
        onResolveConflict: (conflict, resolution) =>
            unawaited(_resolveConflict(conflict, resolution)),
        onImportIcs: () => unawaited(showIcsImportFlow(context, ref)),
        subscriptions: subscriptions,
        busySubscriptionIds: _busySubscriptionIds,
        onAddSubscription: () => unawaited(_addSubscription()),
        onRefreshSubscription: (subscription) =>
            unawaited(_refreshSubscription(subscription)),
        onRenameSubscription: (subscription) =>
            unawaited(_renameSubscription(subscription)),
        onChangeSubscriptionColor: (subscription) =>
            unawaited(_changeSubscriptionColor(subscription)),
        onUnsubscribe: (subscription) => unawaited(_unsubscribe(subscription)),
      ),
      SettingsPage.schedule => _SettingsPageLayout(
        children: [
          BusyMaxGroupedList(
            title: l10n.newEventsAndTasks,
            titleStyle: _settingsSectionHeaderStyle(context),
            filled: true,
            children: [
              BusyMaxComboRow<CreationDestination?>(
                title: l10n.defaultCalendar,
                leading: const Icon(YaruIcons.calendar),
                values: [null, ...calendarOptions.keys],
                selected: calendarOptions.containsKey(settings.defaultCalendar)
                    ? settings.defaultCalendar
                    : null,
                labelFor: (value) =>
                    value == null ? l10n.lastUsed : calendarOptions[value]!,
                onSelected: settingsController.setDefaultCalendar,
              ),
              BusyMaxComboRow<CreationDestination?>(
                title: l10n.defaultTaskList,
                leading: const Icon(YaruIcons.checkmark),
                values: [null, ...taskListOptions.keys],
                selected: taskListOptions.containsKey(settings.defaultTaskList)
                    ? settings.defaultTaskList
                    : null,
                labelFor: (value) =>
                    value == null ? l10n.lastUsed : taskListOptions[value]!,
                onSelected: settingsController.setDefaultTaskList,
              ),
            ],
          ),
          BusyMaxGroupedList(
            title: l10n.scheduleDisplaySettings,
            titleStyle: _settingsSectionHeaderStyle(context),
            description: l10n.scheduleDisplayHoursDescription,
            filled: true,
            children: [
              BusyMaxComboRow<BusyMaxTimeFormatPreference>(
                title: l10n.timeFormat,
                leading: const Icon(YaruIcons.clock),
                values: BusyMaxTimeFormatPreference.values,
                selected: settings.timeFormatPreference,
                labelFor: (value) => switch (value) {
                  BusyMaxTimeFormatPreference.system => l10n.themeSystem,
                  BusyMaxTimeFormatPreference.twelveHour =>
                    l10n.timeFormatTwelveHour,
                  BusyMaxTimeFormatPreference.twentyFourHour =>
                    l10n.timeFormatTwentyFourHour,
                },
                onSelected: settingsController.setTimeFormatPreference,
              ),
              BusyMaxComboRow<BusyMaxFirstDayOfWeekPreference>(
                title: l10n.firstDayOfWeek,
                leading: const Icon(YaruIcons.calendar),
                values: BusyMaxFirstDayOfWeekPreference.values,
                selected: settings.firstDayOfWeekPreference,
                labelFor: (value) =>
                    busyMaxFirstDayOfWeekPreferenceLabel(context, value),
                onSelected: settingsController.setFirstDayOfWeekPreference,
              ),
              BusyMaxComboRow<int>(
                title: l10n.scheduleDayStartsAt,
                leading: const Icon(YaruIcons.calendar_day),
                values: _scheduleDayStartValues(settings),
                selected: settings.scheduleDayStartMinute,
                labelFor: (value) => _timeOfDayLabel(context, value),
                onSelected: settingsController.setScheduleDayStartMinute,
              ),
              BusyMaxComboRow<int>(
                title: l10n.scheduleDayEndsAt,
                leading: const Icon(YaruIcons.clock),
                values: _scheduleDayEndValues(settings),
                selected: settings.scheduleDayEndMinute,
                labelFor: (value) => _timeOfDayLabel(context, value),
                onSelected: settingsController.setScheduleDayEndMinute,
              ),
            ],
          ),
        ],
      ),
      SettingsPage.system => _SettingsPageLayout(
        children: [
          BusyMaxGroupedList(
            filled: true,
            children: [
              BusyMaxComboRow<String>(
                title: l10n.currentLocale,
                leading: const Icon(Icons.language),
                values: [
                  _systemLocaleTag,
                  for (final option in busyMaxLocaleOptions) option.tag,
                ],
                selected: settings.localeTag ?? _systemLocaleTag,
                labelFor: (tag) => tag == _systemLocaleTag
                    ? l10n.themeSystem
                    : busyMaxLocaleEndonym(tag),
                onSelected: (tag) => settingsController.setLocaleTag(
                  tag == _systemLocaleTag ? null : tag,
                ),
              ),
              BusyMaxSwitchRow(
                title: l10n.showTrayIcon,
                value: settings.showTrayIcon,
                onChanged: settingsController.setShowTrayIcon,
                leading: const Icon(YaruIcons.pin),
              ),
              BusyMaxSwitchRow(
                title: l10n.runInBackgroundWhenClosed,
                subtitle: settings.showTrayIcon ? null : l10n.requiresTrayIcon,
                value: settings.runInBackgroundWhenClosed,
                enabled: settings.showTrayIcon,
                onChanged: settingsController.setRunInBackgroundWhenClosed,
                leading: const Icon(YaruIcons.window),
              ),
              BusyMaxSwitchRow(
                title: l10n.startMinimizedToTray,
                subtitle: settings.showTrayIcon ? null : l10n.requiresTrayIcon,
                value: settings.startMinimizedToTray,
                enabled: settings.showTrayIcon,
                onChanged: settingsController.setStartMinimizedToTray,
                leading: const Icon(YaruIcons.window_minimize),
              ),
              BusyMaxSwitchRow(
                key: const ValueKey('launch-at-login-switch'),
                title: l10n.launchAtLogin,
                subtitle: launchAtLogin.hasError
                    ? l10n.launchAtLoginReadFailed
                    : launchAtLogin.valueOrNull ==
                          DesktopAutostartState.enabledExternally
                    ? l10n.launchAtLoginManagedExternally
                    : launchAtLogin.valueOrNull ==
                          DesktopAutostartState.unavailable
                    ? l10n.launchAtLoginUnavailable
                    : l10n.launchAtLoginDescription,
                value: launchAtLogin.valueOrNull?.isEnabled ?? false,
                enabled:
                    !changingAutostart &&
                    !launchAtLogin.isLoading &&
                    !launchAtLogin.hasError &&
                    (launchAtLogin.valueOrNull?.canChange ?? false),
                onChanged: (enabled) =>
                    unawaited(_setLaunchAtLogin(context, enabled)),
                leading: changingAutostart || launchAtLogin.isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.power_settings_new_outlined),
              ),
              if (launchAtLogin.hasError)
                BusyMaxActionRow(
                  title: l10n.retry,
                  enabled: !changingAutostart && !launchAtLogin.isLoading,
                  onTap: () => ref.invalidate(launchAtLoginStateProvider),
                ),
              BusyMaxComboRow<BusyMaxThemeModePreference>(
                title: l10n.theme,
                leading: const Icon(Icons.tune),
                values: BusyMaxThemeModePreference.values,
                selected: settings.themeModePreference,
                labelFor: (value) => _themeModeLabel(context, value),
                onSelected: themeController.setThemeMode,
              ),
            ],
          ),
        ],
      ),
      SettingsPage.notifications => _SettingsPageLayout(
        children: [
          Text(l10n.windowsReminderExitNotice),
          Text(l10n.notificationsUnknown),
          BusyMaxGroupedList(
            filled: true,
            children: [
              BusyMaxSwitchRow(
                title: l10n.eventReminders,
                value: settings.notifyEventReminders,
                onChanged: settingsController.setNotifyEventReminders,
                leading: const Icon(YaruIcons.calendar_day),
              ),
              BusyMaxSwitchRow(
                title: l10n.taskReminders,
                value: settings.notifyTaskReminders,
                onChanged: settingsController.setNotifyTaskReminders,
                leading: const Icon(YaruIcons.checkmark),
              ),
              BusyMaxSwitchRow(
                title: l10n.notifyDueToday,
                subtitle: l10n.dailySummaryScope,
                value: settings.notifyDueToday,
                onChanged: settingsController.setNotifyDueToday,
                leading: const Icon(YaruIcons.calendar_day),
              ),
              DesktopTimeValueRow(
                label: l10n.dailySummaryTime,
                time: settings.dueTodayNotificationTime,
                enabled: settings.notifyDueToday,
                allowEmpty: false,
                onChanged: (time) {
                  if (time != null) {
                    unawaited(
                      settingsController.setDueTodayNotificationTime(time),
                    );
                  }
                },
              ),
              BusyMaxSwitchRow(
                title: l10n.notifySyncFailures,
                value: settings.notifySyncFailures,
                onChanged: settingsController.setNotifySyncFailures,
                leading: const Icon(YaruIcons.sync_error),
              ),
              BusyMaxSwitchRow(
                title: l10n.notifyConflicts,
                value: settings.notifyConflicts,
                onChanged: settingsController.setNotifyConflicts,
                leading: const Icon(YaruIcons.warning),
              ),
              BusyMaxComboRow<NotificationDetailLevel>(
                title: l10n.notificationDetailLevel,
                leading: const Icon(YaruIcons.eye),
                values: NotificationDetailLevel.values,
                selected: settings.notificationDetailLevel,
                labelFor: (value) => _notificationDetailLabel(context, value),
                onSelected: settingsController.setNotificationDetailLevel,
              ),
              BusyMaxSwitchRow(
                title: l10n.quietHours,
                subtitle: l10n.quietHoursDescription,
                value: settings.quietHoursEnabled,
                onChanged: settingsController.setQuietHoursEnabled,
                leading: const Icon(YaruIcons.clear_night),
              ),
              DesktopTimeValueRow(
                label: l10n.quietHoursStart,
                time: settings.quietHoursStart,
                enabled: settings.quietHoursEnabled,
                allowEmpty: false,
                onChanged: (time) {
                  if (time != null) {
                    unawaited(settingsController.setQuietHoursStart(time));
                  }
                },
              ),
              DesktopTimeValueRow(
                label: l10n.quietHoursEnd,
                time: settings.quietHoursEnd,
                enabled: settings.quietHoursEnabled,
                allowEmpty: false,
                onChanged: (time) {
                  if (time != null) {
                    unawaited(settingsController.setQuietHoursEnd(time));
                  }
                },
              ),
            ],
          ),
        ],
      ),
      SettingsPage.privacy => _SettingsPageLayout(
        children: [
          BusyMaxGroupedList(
            filled: true,
            children: [
              BusyMaxSwitchRow(
                title: l10n.redactTaskContentInDiagnostics,
                value: settings.redactTaskContentInDiagnostics,
                onChanged: settingsController.setRedactTaskContentInDiagnostics,
                leading: const Icon(YaruIcons.shield_warning),
              ),
            ],
          ),
        ],
      ),
      SettingsPage.diagnostics => _SettingsPageLayout(
        children: [
          BusyMaxGroupedList(
            key: const ValueKey('diagnostics-full-resync-section'),
            title: l10n.sync,
            titleStyle: _settingsSectionHeaderStyle(context),
            description: l10n.forceFullResyncDescription,
            filled: true,
            children: [
              BusyMaxActionRow(
                title: l10n.forceFullResync,
                leading: const Icon(YaruIcons.sync),
                enabled: hasSyncEligibleAccounts,
                onTap: !hasSyncEligibleAccounts
                    ? null
                    : () => _forceFullResync(context, ref),
              ),
            ],
          ),
          const SizedBox(height: BusyMaxSpacing.lg),
          if (davConflicts.any(
            (conflict) =>
                widget.notificationAccountId == null ||
                conflict.accountId == widget.notificationAccountId,
          ))
            _DavConflictsCard(
              conflicts: davConflicts
                  .where(
                    (conflict) =>
                        widget.notificationAccountId == null ||
                        conflict.accountId == widget.notificationAccountId,
                  )
                  .toList(),
              onResolve: (conflict, resolution) =>
                  unawaited(_resolveConflict(conflict, resolution)),
            ),
          DiagnosticsPanel(
            scrollable: false,
            accountId: widget.notificationAccountId,
            sectionHeaderStyle: _settingsSectionHeaderStyle(context),
          ),
        ],
      ),
    };

    return CallbackShortcuts(
      bindings: {BusyMaxShortcutActivators.back: _goBack},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: BusyMaxSurfaceColors.of(context).window,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final showSidebar = BusyMaxLayoutRules.showSettingsSidebar(
                constraints.maxWidth,
              );
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ref.watch(appSettingsPersistenceFailedProvider))
                    MaterialBanner(
                      content: Text(l10n.settingsSaveFailed),
                      actions: [
                        BusyMaxPushButton.standard(
                          onPressed: () =>
                              unawaited(settingsController.retrySave()),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  if (!showSidebar)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        BusyMaxSpacing.lg,
                        BusyMaxSpacing.md,
                        BusyMaxSpacing.lg,
                        0,
                      ),
                      child: _SettingsPageSelector(
                        selected: _page,
                        onSelected: _selectPage,
                      ),
                    ),
                  Expanded(
                    child: BusyMaxClamp(
                      controller: _contentScroll,
                      maxWidth: 760,
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: BusyMaxKeyedCrossfade(
                        transitionKey: _page,
                        child: pageBody,
                      ),
                    ),
                  ),
                ],
              );
              return LinuxPageFrame(
                header: _SettingsHeader(
                  title: title,
                  backFocusNode: _headerBackFocus,
                  onBack: _goBack,
                  onMenuSelected: _handleMenuAction,
                ),
                body: content,
                sidebarHeader: const BusyMaxLinuxBrandHeader(),
                sidebarBody: _SettingsSidebar(
                  selected: _page,
                  onSelected: _selectPage,
                ),
                sidebarAvailable: showSidebar,
                sidebarExpanded: true,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _enableContacts(AccountEntity account) =>
      _runContactOperation(account.id, () async {
        final controller = ref.read(busyMaxContactsControllerProvider);
        if (account.provider == BusyProvider.nextcloud) {
          await controller.enableLinkedNextcloudContacts(account.id);
        } else {
          await controller.enableLinkedContacts(account.id);
        }
      });

  Future<void> _disableContacts(String id) =>
      _runContactOperation(id, () async {
        final controller = ref.read(busyMaxContactsControllerProvider);
        if (id.startsWith('contacts:')) {
          await controller.disableContactsAccount(id);
        } else {
          final confirmed = await showBusyMaxConfirm(
            context,
            title: context.l10n.removeAccount,
            message: context.l10n.contactsOnlyDescription,
            confirmLabel: context.l10n.removeAction,
            destructive: true,
          );
          if (!confirmed || !mounted) return;
          await controller.removeContactsAccount(id);
        }
      });

  Future<void> _addCardDavContacts() async {
    final input = await showBusyMaxModalDialog<_CardDavContactsInput>(
      context,
      barrierDismissible: false,
      builder: (_) => const _CardDavContactsDialog(),
    );
    if (input == null || !mounted) return;
    final id = const Uuid().v7();
    await _runContactOperation(id, () async {
      await ref
          .read(busyMaxContactsControllerProvider)
          .addCardDavContactsOnly(
            id: id,
            label: input.label,
            server: input.server,
            username: input.username,
            password: input.password,
          );
    });
  }

  Future<void> _addNextcloudContacts() async {
    final server = await showNextcloudServerDialog(context);
    if (server == null || !mounted) return;
    final id = const Uuid().v7();
    await _runContactOperation(id, () async {
      await ref
          .read(busyMaxContactsControllerProvider)
          .addNextcloudContactsOnly(
            id: id,
            label: context.l10n.nextcloudProvider,
            server: Uri.parse(server),
          );
    });
  }

  Future<void> _retryContacts(ContactAccount contact) => _runContactOperation(
    contact.id,
    () => ref
        .read(busyMaxContactsControllerProvider)
        .synchronizeAccount(contact.id),
  );

  Future<void> _reconnectContacts(ContactAccount contact) async {
    // Preparation can outlive its account view before any enrollment exists
    // for navigation to cancel. Own the intent from the first storage read.
    final navigationGeneration = _accountNavigationGeneration;
    bool ownsIntent() =>
        mounted && navigationGeneration == _accountNavigationGeneration;
    final controller = ref.read(busyMaxContactsControllerProvider);
    final parentId = await controller.store.linkedBusyMaxAccount(contact.id);
    if (!ownsIntent()) return;
    if (parentId != null && contact.provider == ContactProviderKind.carddav) {
      final parent = await ref
          .read(accountsRepositoryProvider)
          .accountById(parentId);
      if (!ownsIntent() || parent == null) return;
      if (await _connectAccount(parent.provider, reconnecting: parent) &&
          ownsIntent()) {
        await _enableContacts(parent);
      }
      return;
    }
    String? password;
    if (parentId == null) {
      final nextcloud = await controller.isIndependentNextcloud(contact.id);
      if (!mounted || !ownsIntent()) return;
      if (!nextcloud) {
        password = await showBusyMaxTextPrompt(
          context,
          title: context.l10n.reconnectAccount,
          label: context.l10n.contactsPasswordLabel,
          actionLabel: context.l10n.reconnectAccount,
          obscureText: true,
        );
        if (!ownsIntent() || password == null) return;
      }
    }
    if (!ownsIntent()) return;
    await _runContactOperation(
      contact.id,
      () => password != null
          ? controller.reconnectDavContactsOnly(contact.id, password: password)
          : controller.reconnectContactsAccount(contact.id),
    );
  }

  Future<void> _runContactOperation(
    String id,
    Future<void> Function() operation,
  ) async {
    if (_busyContactAccountIds.contains(id)) return;
    final navigationGeneration = _accountNavigationGeneration;
    _contactOperationsController = ref.read(busyMaxContactsControllerProvider);
    setState(() => _busyContactAccountIds.add(id));
    try {
      await operation();
    } on Object catch (error) {
      _settingsLogger.warning(
        'Contacts configuration failed: ${redactForLog(error)}',
      );
      if (mounted && navigationGeneration == _accountNavigationGeneration) {
        final target = _accountDetails;
        if (target?.contactsOnly == false &&
            error is OAuthException &&
            const [
              OAuthFailureKind.registrationUnavailable,
              OAuthFailureKind.clientRejected,
              OAuthFailureKind.configuration,
            ].contains(error.classification) &&
            (id == target!.id ||
                id ==
                    BusyMaxContactsController.linkedContactAccountId(
                      target.id,
                    ))) {
          setState(() => _registrationRecoveryIds.add(target.id));
        }
        _showMessage(context, localizedContactsError(context.l10n, error));
      }
    } finally {
      if (mounted) setState(() => _busyContactAccountIds.remove(id));
    }
  }

  Future<void> _addSubscription({String? initialUrl}) async {
    await showAddCalendarSubscriptionFlow(context, ref, initialUrl: initialUrl);
  }

  Future<void> _refreshSubscription(
    WebCalSubscriptionEntity subscription,
  ) async {
    await _runSubscriptionOperation(subscription.id, () async {
      await ref
          .read(webCalSubscriptionServiceProvider)
          .refreshSubscription(subscription.id, force: true);
    });
  }

  Future<void> _renameSubscription(
    WebCalSubscriptionEntity subscription,
  ) async {
    final value = await showBusyMaxTextPrompt(
      context,
      title: context.l10n.rename,
      label: context.l10n.subscriptionName,
      actionLabel: context.l10n.rename,
      initialValue: subscription.name,
    );
    if (value == null || !mounted) return;
    await _runSubscriptionOperation(subscription.id, () async {
      await ref
          .read(webCalSubscriptionServiceProvider)
          .renameSubscription(subscription.id, value);
    });
  }

  Future<void> _changeSubscriptionColor(
    WebCalSubscriptionEntity subscription,
  ) async {
    final value = await showBusyMaxTextPrompt(
      context,
      title: context.l10n.calendarColor,
      label: context.l10n.subscriptionColor,
      actionLabel: context.l10n.save,
      initialValue: subscription.color,
      message: context.l10n.subscriptionColorHelp,
    );
    if (value == null || !mounted) return;
    await _runSubscriptionOperation(subscription.id, () async {
      await ref
          .read(webCalSubscriptionServiceProvider)
          .changeSubscriptionColor(subscription.id, value);
    });
  }

  Future<void> _unsubscribe(WebCalSubscriptionEntity subscription) async {
    final confirmed = await showBusyMaxConfirm(
      context,
      title: context.l10n.unsubscribeCalendarTitle(subscription.name),
      message: context.l10n.unsubscribeCalendarConfirmation,
      confirmLabel: context.l10n.unsubscribe,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _runSubscriptionOperation(subscription.id, () async {
      await ref
          .read(webCalSubscriptionServiceProvider)
          .unsubscribe(subscription.id);
    });
  }

  Future<void> _runSubscriptionOperation(
    String subscriptionId,
    Future<void> Function() operation,
  ) async {
    if (_busySubscriptionIds.contains(subscriptionId)) return;
    setState(() => _busySubscriptionIds.add(subscriptionId));
    try {
      await operation();
    } on Object catch (error) {
      if (mounted) _showSubscriptionError(error);
    } finally {
      if (mounted) setState(() => _busySubscriptionIds.remove(subscriptionId));
    }
  }

  void _showSubscriptionError(Object error) {
    final code = switch (error) {
      WebCalSubscriptionException(:final code) => code,
      WebCalUriException(:final code) => code,
      _ => 'WebCalOperationFailed',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.subscriptionOperationFailed(code))),
    );
  }

  Future<void> _setLaunchAtLogin(BuildContext context, bool enabled) async {
    try {
      await ref
          .read(launchAtLoginControllerProvider.notifier)
          .setEnabled(enabled);
    } on Object catch (error) {
      _settingsLogger.warning(
        'Could not update launch-at-login setting: ${redactForLog(error)}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.launchAtLoginFailed)),
        );
      }
    }
  }

  void _handleMenuAction(ScheduleToolbarMenuAction action) {
    switch (action) {
      case ScheduleToolbarMenuAction.refresh:
        return;
      case ScheduleToolbarMenuAction.settings:
        _selectPage(SettingsPage.system);
      case ScheduleToolbarMenuAction.keyboardShortcuts:
        unawaited(showBusyMaxKeyboardShortcutsDialog(context));
      case ScheduleToolbarMenuAction.reportIssue:
        unawaited(
          showBusyMaxFeedbackDialog(
            context,
            submissionService: ref.read(feedbackSubmissionServiceProvider),
          ),
        );
      case ScheduleToolbarMenuAction.about:
        unawaited(showBusyMaxAboutDialog(context));
    }
  }

  void _goBack() {
    if (_page == SettingsPage.accounts && _accountDetails != null) {
      _showAccountsOverview();
      return;
    }
    _abandonAccountAuthorization();
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/schedule');
  }

  void _selectPage(SettingsPage page) {
    if (_page != page) {
      _abandonAccountAuthorization();
      _accountDetails = null;
      if (page == SettingsPage.system) {
        ref.invalidate(launchAtLoginStateProvider);
      }
      setState(() => _page = page);
      _restoreAccountScroll(
        page == SettingsPage.accounts ? _accountsOverviewOffset : 0,
      );
    }
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final uri = GoRouterState.of(context).uri;
    if (uri.path != '/settings') {
      return;
    }
    final routePage = uri.queryParameters['page'];
    if (routePage == settingsPageRouteValue(page)) {
      return;
    }
    unawaited(
      router.replace(
        uri
            .replace(
              queryParameters: {
                ...uri.queryParameters,
                'page': settingsPageRouteValue(page),
              },
            )
            .toString(),
      ),
    );
  }

  void _abandonAccountAuthorization() {
    _accountNavigationGeneration++;
    _cancelAccountConnection();
    _sharedConsentCancellation?.cancel();
    for (final id in _busyContactAccountIds) {
      _contactOperationsController?.cancelEnrollment(id);
    }
  }

  void _openAccountDetails(String id, {bool contactsOnly = false}) {
    if (_page == SettingsPage.accounts &&
        _accountDetails == null &&
        _contentScroll.hasClients) {
      _accountsOverviewOffset = _contentScroll.offset;
    }
    _abandonAccountAuthorization();
    _originatingAccountEntry = '${contactsOnly ? 'contacts' : 'account'}:$id';
    setState(() {
      _page = SettingsPage.accounts;
      _accountDetails = (id: id, contactsOnly: contactsOnly);
    });
    _restoreAccountScroll(0, focus: _headerBackFocus);
  }

  void _showAccountsOverview() {
    _abandonAccountAuthorization();
    setState(() => _accountDetails = null);
    _restoreAccountScroll(
      _accountsOverviewOffset,
      focus: _accountEntryFocus[_originatingAccountEntry],
    );
  }

  void _returnAfterAccountDisappeared(String id) {
    final generation = _accountNavigationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _accountNavigationGeneration ||
          _accountDetails?.id != id) {
        return;
      }
      final remaining =
          (ref.read(accountManagementStreamProvider).valueOrNull ??
                  const <AccountEntity>[])
              .where((a) => a.id != id)
              .toList();
      final contacts =
          ref.read(busyMaxContactAccountsProvider).valueOrNull ??
          const <ContactAccount>[];
      final independent =
          ref.read(independentContactAccountIdsProvider).valueOrNull ??
          const <String>{};
      final contact = contacts
          .where((c) => c.id != id && independent.contains(c.id))
          .firstOrNull;
      _originatingAccountEntry = remaining.isNotEmpty
          ? 'account:${remaining.first.id}'
          : contact != null
          ? 'contacts:${contact.id}'
          : 'add-account';
      _showAccountsOverview();
    });
  }

  void _restoreAccountScroll(double offset, {FocusNode? focus}) {
    final generation = _accountNavigationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _accountNavigationGeneration) return;
      if (_contentScroll.hasClients) {
        _contentScroll.jumpTo(
          offset.clamp(0, _contentScroll.position.maxScrollExtent).toDouble(),
        );
      }
      if (focus?.context != null) focus!.requestFocus();
    });
  }

  Future<bool> _connectAccount(
    BusyProvider provider, {
    AccountEntity? reconnecting,
    bool replaceRegistration = false,
  }) async {
    if (_connectingProvider != null ||
        _authorizationCancellation?.isCancelled == false) {
      return false;
    }
    var addSeparate = false;
    var connected = false;
    final ownedCancellation = AuthorizationCancellation();
    _authorizationCancellation = ownedCancellation;
    try {
      AppleICloudCredentialInput? appleInput;
      String? nextcloudServer;
      if (provider == BusyProvider.appleICloud) {
        appleInput = await showAppleICloudCredentialDialog(
          context,
          fixedEmail: reconnecting?.email ?? reconnecting?.providerAccountId,
        );
        if (appleInput == null || !mounted || ownedCancellation.isCancelled) {
          return false;
        }
      } else if (provider == BusyProvider.nextcloud) {
        nextcloudServer = await showNextcloudServerDialog(
          context,
          initialServer: reconnecting?.authority,
        );
        if (nextcloudServer == null ||
            !mounted ||
            ownedCancellation.isCancelled) {
          return false;
        }
      }
      AuthorizationRequest? request;
      if (provider == BusyProvider.google ||
          provider == BusyProvider.microsoft) {
        if (reconnecting != null && !replaceRegistration) {
          request = AuthorizationRequest.reconnect(reconnecting.id);
        } else {
          final handle = await showRegistrationSetup(
            context,
            ref,
            provider,
            accountLabel: reconnecting == null
                ? null
                : reconnecting.email ??
                      reconnecting.displayName ??
                      reconnecting.id,
          );
          if (handle == null || !mounted) return false;
          request = reconnecting == null
              ? AuthorizationRequest.newConnection(handle)
              : AuthorizationRequest.replace(reconnecting.id, handle);
        }
      }
      if (!mounted ||
          !identical(_authorizationCancellation, ownedCancellation) ||
          ownedCancellation.isCancelled) {
        return false;
      }
      final repository = ref.read(authRepositoryProvider);
      final runSync = ref.read(signedInSyncRunnerProvider);
      final sessionController = ref.read(
        authSessionControllerProvider.notifier,
      );
      setState(() => _connectingProvider = provider);
      if (!mounted || ownedCancellation.isCancelled) return false;
      request = (request ?? const AuthorizationRequest.newConnection(null))
          .withCancellation(ownedCancellation);
      try {
        String? accountId;
        switch (provider) {
          case BusyProvider.google:
            accountId = (await repository.signIn(request: request)).accountId;
          case BusyProvider.microsoft:
            accountId = (await repository.signInWithMicrosoft(request: request))
                .accountId;
          case BusyProvider.appleICloud:
            final cancellation = DavCancellationToken();
            _davCancellation = cancellation;
            final onboarding = ref.read(davAccountOnboardingServiceProvider);
            accountId = reconnecting == null
                ? (await onboarding.connectAppleICloud(
                    email: appleInput!.email,
                    appSpecificPassword: appleInput.password,
                    cancellationToken: cancellation,
                  )).accountId
                : (await onboarding.replaceAppleAppSpecificPassword(
                    accountId: reconnecting.id,
                    appSpecificPassword: appleInput!.password,
                    cancellationToken: cancellation,
                  )).accountId;
          case BusyProvider.nextcloud:
            final cancellation = DavCancellationToken();
            _davCancellation = cancellation;
            final onboarding = ref.read(davAccountOnboardingServiceProvider);
            accountId = reconnecting == null
                ? (await onboarding.connectNextcloud(
                    enteredServer: nextcloudServer!,
                    cancellationToken: cancellation,
                  )).accountId
                : (await onboarding.reconnectNextcloud(
                    accountId: reconnecting.id,
                    enteredServer: nextcloudServer!,
                    cancellationToken: cancellation,
                  )).accountId;
          case BusyProvider.webCal:
            throw StateError(
              'WebCal subscriptions use the calendar subscription dialog.',
            );
        }
        if (accountId != null) {
          ownedCancellation.committed();
          connected = true;
          if (mounted) {
            setState(() => _registrationRecoveryIds.remove(accountId));
          }
          unawaited(_syncConnectedAccount(runSync, accountId));
          await sessionController.reconcileConnectedAccount(accountId);
        }
      } on Object catch (error) {
        if ((error is OAuthException && error.code == 'OAuthSignInCancelled') ||
            (error is DavException && error.kind == DavErrorKind.cancelled)) {
          return false;
        }
        if (mounted &&
            identical(_authorizationCancellation, ownedCancellation) &&
            !ownedCancellation.isCancelled &&
            error is OAuthException &&
            provider == BusyProvider.google &&
            error.classification == OAuthFailureKind.identityUnverified) {
          addSeparate =
              await showBusyMaxModalDialog<bool>(
                context,
                builder: (dialogContext) => BusyMaxDialogShell(
                  title: context.l10n.reconnectGoogleAccount,
                  maxWidth: 560,
                  actions: [
                    BusyMaxPushButton.standard(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(context.l10n.cancel),
                    ),
                    BusyMaxPushButton.suggested(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(context.l10n.addSeparateGoogleAccount),
                    ),
                  ],
                  children: [
                    Text(
                      context.l10n.reconnectSelectedAccount(
                        reconnecting!.email ??
                            reconnecting.displayName ??
                            reconnecting.id,
                      ),
                    ),
                    Text(context.l10n.googleIdentityUnverified),
                  ],
                ),
              ) ??
              false;
        } else if (mounted &&
            identical(_authorizationCancellation, ownedCancellation) &&
            !ownedCancellation.isCancelled) {
          if (reconnecting != null &&
              error is OAuthException &&
              (error.classification ==
                      OAuthFailureKind.registrationUnavailable ||
                  error.classification == OAuthFailureKind.clientRejected ||
                  error.classification == OAuthFailureKind.configuration)) {
            setState(() => _registrationRecoveryIds.add(reconnecting.id));
          }
          _showMessage(context, _accountConnectionErrorMessage(context, error));
        }
      } finally {
        if (mounted &&
            identical(_authorizationCancellation, ownedCancellation)) {
          setState(() {
            _connectingProvider = null;
            _davCancellation = null;
          });
        }
      }
    } finally {
      ownedCancellation.cancel();
      if (identical(_authorizationCancellation, ownedCancellation)) {
        _authorizationCancellation = null;
        if (mounted) setState(() => _connectingProvider = null);
      }
    }
    if (addSeparate && mounted) return _connectAccount(BusyProvider.google);
    return connected;
  }

  void _cancelAccountConnection() {
    if (_authorizationCancellation?.wasCommitted == true) return;
    _authorizationCancellation?.cancel();
    setState(() => _connectingProvider = null);
    _davCancellation?.cancel();
  }

  Future<void> _syncConnectedAccount(
    SignedInSyncRunner runSync,
    String accountId,
  ) async {
    try {
      await runSync(accountId, true);
    } on Object catch (error) {
      if (mounted &&
          _page == SettingsPage.accounts &&
          (_accountDetails == null || _accountDetails?.id == accountId)) {
        _showMessage(
          context,
          context.l10n.syncFailed(
            AccountSettingsFeedback.fromError(context.l10n, error).message,
          ),
        );
      }
    }
  }

  Future<void> _removeAccount(
    BuildContext context,
    WidgetRef ref,
    AccountEntity account,
  ) async {
    if (_removingAccountIds.contains(account.id)) {
      return;
    }

    final options = await showBusyMaxAccountRemovalDialog(
      context,
      accountLabel: _accountIdentityLabel(context, account),
      revokeNextcloudAppPassword: account.provider == BusyProvider.nextcloud,
      canRevokeGoogleAuthorization:
          account.provider == BusyProvider.google && account.isSignedIn,
    );
    if (!context.mounted || options == null) {
      return;
    }

    setState(() => _removingAccountIds.add(account.id));
    try {
      final dav =
          account.provider == BusyProvider.appleICloud ||
          account.provider == BusyProvider.nextcloud;
      final result = dav
          ? null
          : await ref
                .read(authRepositoryProvider)
                .removeAccount(
                  accountId: account.id,
                  revokeAuthorization: options.revokeGoogleAuthorization,
                );
      final davResult = dav
          ? await ref
                .read(davAccountOnboardingServiceProvider)
                .removeAccount(account.id)
          : null;
      if (context.mounted) {
        final presenting =
            _page == SettingsPage.accounts &&
            (_accountDetails == null || _accountDetails?.id == account.id);
        if (presenting && (result?.authorizationRevocationFailed ?? false)) {
          _showMessage(context, context.l10n.accountRemovedGoogleRevokeFailed);
        } else if (presenting &&
            davResult?.remoteRevocationAttempted == true &&
            !davResult!.remoteRevocationSucceeded) {
          _showMessage(
            context,
            context.l10n.nextcloudAccountRemovedRevokeFailed,
          );
        }
        await _afterAccountRemoved(context, ref, account.id);
        if (mounted && _accountDetails?.id == account.id) {
          _returnAfterAccountDisappeared(account.id);
        }
      }
    } on Object catch (error) {
      _settingsLogger.warning('Account removal failed: $error');
      if (context.mounted &&
          _page == SettingsPage.accounts &&
          (_accountDetails == null || _accountDetails?.id == account.id)) {
        _showMessage(
          context,
          localizedAccountRemovalError(context.l10n, error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _removingAccountIds.remove(account.id));
      }
    }
  }

  Future<void> _forceFullResync(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(accountsRepositoryProvider);
      final accounts = await repository.listSyncEligibleAccounts();
      if (accounts.isEmpty) {
        return;
      }
      final runSync = ref.read(signedInSyncRunnerProvider);
      for (final account in accounts) {
        final stillEligible = (await repository.listSyncEligibleAccounts()).any(
          (current) => current.id == account.id,
        );
        if (!stillEligible) {
          continue;
        }
        await runSync(account.id, true);
      }
      if (context.mounted) {
        _showMessage(context, context.l10n.syncComplete);
      }
    } on Object catch (error) {
      if (context.mounted) {
        _showMessage(
          context,
          context.l10n.syncFailed(
            AccountSettingsFeedback.fromError(context.l10n, error).message,
          ),
        );
      }
    }
  }

  Future<void> _refreshCollections(AccountEntity account) async {
    if (_refreshingAccountIds.contains(account.id)) return;
    final navigationGeneration = _accountNavigationGeneration;
    setState(() => _refreshingAccountIds.add(account.id));
    try {
      var current = await ref
          .read(accountsRepositoryProvider)
          .accountById(account.id);
      if (current?.provider == BusyProvider.nextcloud &&
          (current?.connectionState ==
                  AccountConnectionState.permissionChanged ||
              current?.connectionState ==
                  AccountConnectionState.unsupportedServerProfile)) {
        await ref
            .read(davAccountOnboardingServiceProvider)
            .revalidateAccount(account.id);
        if (!mounted) return;
        current = await ref
            .read(accountsRepositoryProvider)
            .accountById(account.id);
      }
      if (current?.isSyncEligible != true) {
        if (current?.needsReconnect == true && mounted) {
          _showMessage(
            context,
            context.l10n.syncFailed(accountReconnectRequiredSyncMessage),
          );
        }
        return;
      }
      await ref.read(signedInSyncRunnerProvider)(account.id, true);
      if (mounted && navigationGeneration == _accountNavigationGeneration) {
        _showMessage(context, context.l10n.syncComplete);
      }
    } on Object catch (error) {
      if (mounted && navigationGeneration == _accountNavigationGeneration) {
        _showMessage(
          context,
          context.l10n.syncFailed(
            AccountSettingsFeedback.fromError(context.l10n, error).message,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingAccountIds.remove(account.id));
    }
  }

  Future<void> _openSharedCalendar(AccountEntity account) async {
    _sharedConsentCancellation?.cancel();
    final cancellation = AuthorizationCancellation();
    _sharedConsentCancellation = cancellation;
    try {
      final owner = await showBusyMaxTextPrompt(
        context,
        title: context.l10n.openSharedCalendar,
        label: context.l10n.calendarOwnerEmail,
        message: context.l10n.openSharedPrimaryDescription,
        actionLabel: context.l10n.openSharedCalendar,
      );
      if (!mounted || owner == null || owner.trim().isEmpty) return;
      try {
        final result = await ref
            .read(microsoftSharedCalendarServiceProvider)
            .openPrimaryCalendar(
              accountId: account.id,
              owner: owner,
              cancellation: cancellation,
            );
        if (mounted &&
            result.outcome ==
                MicrosoftSharedCalendarOpenOutcome.rangeUnavailable) {
          _showMessage(context, context.l10n.scheduleRangeIncomplete);
        }
      } on Object catch (error) {
        if (mounted) {
          _showMessage(
            context,
            context.l10n.calendarUpdateFailed(
              AccountSettingsFeedback.fromError(context.l10n, error).message,
            ),
          );
        }
      }
    } finally {
      cancellation.cancel();
      if (identical(_sharedConsentCancellation, cancellation)) {
        _sharedConsentCancellation = null;
      }
    }
  }

  Future<void> _manageCalendarSharing(
    AccountEntity account,
    List<CalendarSourceEntity> sources,
  ) async {
    final eligible = [
      for (final source in sources)
        if (source.accountId == account.id &&
            CloudCalendarSharingService.canManageSource(source))
          source,
    ];
    await showBusyMaxModalDialog<void>(
      context,
      builder: (_) => BusyMaxDialogShell(
        title: context.l10n.manageCalendarSharing,
        maxWidth: 580,
        actions: [
          BusyMaxPushButton.suggested(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
        ],
        children: [CloudCalendarSharingContent(sources: eligible)],
      ),
    );
  }

  Future<void> _setCalendarProviderVisibility(
    CalendarSourceEntity source,
    bool visible,
  ) async {
    try {
      await ref
          .read(calendarRepositoryProvider)
          .setSourceProviderHidden(source.id, !visible);
      ref
          .read(
            pendingCalendarMutationSyncRequesterForAccountProvider(
              source.accountId,
            ),
          )
          .request();
    } on Object catch (error) {
      _settingsLogger.warning('Calendar provider visibility failed: $error');
      if (mounted) {
        _showMessage(
          context,
          context.l10n.calendarUpdateFailed(
            AccountSettingsFeedback.fromError(context.l10n, error).message,
          ),
        );
      }
    }
  }

  Future<void> _resolveConflict(
    DavConflictEntity conflict,
    DavConflictResolution resolution,
  ) async {
    try {
      await ref
          .read(davConflictResolutionServiceProvider)
          .resolve(conflict.id, resolution);
      await ref.read(signedInSyncRunnerProvider)(conflict.accountId, false);
    } on Object catch (error) {
      _settingsLogger.warning('DAV conflict resolution failed: $error');
      if (mounted) {
        _showMessage(context, context.l10n.conflictResolutionFailed);
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({required this.selected, required this.onSelected});

  final SettingsPage selected;
  final ValueChanged<SettingsPage> onSelected;

  @override
  Widget build(BuildContext context) {
    return BusyMaxSidebarSurface(
      showEndBorder: false,
      child: BusyMaxSidebarNavigation(
        children: [
          for (final page in SettingsPage.values)
            BusyMaxSidebarNavigationTile(
              key: ValueKey('settings-navigation-${page.name}'),
              selected: page == selected,
              leading: Icon(_settingsPageIcon(page)),
              title: Text(_settingsPageLabel(context, page)),
              onTap: () => onSelected(page),
            ),
        ],
      ),
    );
  }
}

class _SettingsPageSelector extends StatelessWidget {
  const _SettingsPageSelector({
    required this.selected,
    required this.onSelected,
  });

  final SettingsPage selected;
  final ValueChanged<SettingsPage> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('settings-page-selector'),
      width: double.infinity,
      child: BusyMaxMenuButton<SettingsPage>(
        tooltip: _settingsPageLabel(context, selected),
        entries: [
          for (final page in SettingsPage.values)
            BusyMaxMenuEntry(
              value: page,
              label: _settingsPageLabel(context, page),
              icon: _settingsPageIcon(page),
              role: BusyMaxMenuEntryRole.radio,
              selected: page == selected,
            ),
        ],
        onSelected: onSelected,
        triggerBuilder: (context, trigger) {
          return trigger.anchor(
            child: Semantics(
              expanded: trigger.isOpen,
              child: BusyMaxPushButton.standard(
                onPressed: trigger.onPressed,
                focusNode: trigger.focusNode,
                child: Row(
                  children: [
                    Icon(_settingsPageIcon(selected)),
                    const SizedBox(width: BusyMaxSpacing.sm),
                    Expanded(
                      child: Text(
                        _settingsPageLabel(context, selected),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(YaruIcons.pan_down),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.title,
    required this.backFocusNode,
    required this.onBack,
    required this.onMenuSelected,
  });

  final String title;
  final FocusNode backFocusNode;
  final VoidCallback onBack;
  final ValueChanged<ScheduleToolbarMenuAction> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return BusyMaxLinuxHeaderLayout(
      leading: BusyMaxLinuxHeaderControlGroup(
        children: [
          BusyMaxLinuxHeaderIconButton(
            key: const ValueKey('settings-header-back-button'),
            focusNode: backFocusNode,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: BusyMaxLinuxHeaderIcon.back,
            onPressed: onBack,
          ),
        ],
      ),
      title: BusyMaxLinuxHeaderTitle(
        title,
        key: const ValueKey('settings-header-title'),
      ),
      trailing: BusyMaxLinuxHeaderControlGroup(
        children: [
          BusyMaxMainMenuButton(
            settingsSelected: true,
            onSelected: onMenuSelected,
          ),
        ],
      ),
    );
  }
}

TextStyle _settingsSectionHeaderStyle(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
    color: theme.colorScheme.onSurface,
    fontWeight: FontWeight.bold,
  );
}

String _settingsAccountLabel(List<AccountEntity> accounts, String accountId) {
  for (final account in accounts) {
    if (account.id == accountId) return account.displayLabel;
  }
  return accountId;
}

bool _canCreateTasksInList(
  WidgetRef ref,
  List<AccountEntity> accounts,
  TaskListEntity list,
) {
  for (final account in accounts) {
    if (account.id != list.accountId || !account.isTaskCapable) continue;
    if (account.provider == BusyProvider.nextcloud) {
      return ref
              .watch(
                davTaskCollectionCapabilitiesProvider((
                  accountId: list.accountId,
                  taskListId: list.id,
                )),
              )
              .valueOrNull
              ?.canCreateTasks ==
          true;
    }
    return adapterDefaultTaskCapabilities(account.provider).canCreateTasks;
  }
  return false;
}

class _SettingsPageLayout extends StatelessWidget {
  const _SettingsPageLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

enum SettingsPage {
  system,
  accounts,
  schedule,
  notifications,
  privacy,
  diagnostics,
}

SettingsPage settingsPageFromRouteValue(String? value) {
  return switch (value) {
    'accounts' => SettingsPage.accounts,
    'schedule' => SettingsPage.schedule,
    'system' => SettingsPage.system,
    'notifications' => SettingsPage.notifications,
    'privacy' => SettingsPage.privacy,
    'diagnostics' => SettingsPage.diagnostics,
    _ => SettingsPage.system,
  };
}

String settingsPageRouteValue(SettingsPage page) => page.name;

String _settingsPageLabel(BuildContext context, SettingsPage page) {
  final l10n = context.l10n;
  return switch (page) {
    SettingsPage.accounts => l10n.accounts,
    SettingsPage.schedule => l10n.scheduleSettings,
    SettingsPage.system => l10n.settingsSystem,
    SettingsPage.notifications => l10n.notifications,
    SettingsPage.privacy => l10n.privacy,
    SettingsPage.diagnostics => l10n.diagnostics,
  };
}

IconData _settingsPageIcon(SettingsPage page) {
  return switch (page) {
    SettingsPage.accounts => YaruIcons.user,
    SettingsPage.schedule => YaruIcons.calendar_day,
    SettingsPage.system => YaruIcons.desktop,
    SettingsPage.notifications => YaruIcons.bell,
    SettingsPage.privacy => YaruIcons.shield_warning,
    SettingsPage.diagnostics => YaruIcons.monitor,
  };
}

List<int> _scheduleDayStartValues(AppSettings settings) {
  return [
    for (var minute = 0; minute < 24 * 60; minute += 60)
      if (minute < settings.scheduleDayEndMinute) minute,
  ];
}

List<int> _scheduleDayEndValues(AppSettings settings) {
  return [
    for (var minute = 60; minute <= 24 * 60; minute += 60)
      if (minute > settings.scheduleDayStartMinute) minute,
  ];
}

String _timeOfDayLabel(BuildContext context, int minute) =>
    formatScheduleBoundary(context, minute);

class _AccountManagementSection extends ConsumerWidget {
  const _AccountManagementSection({
    required this.selectedAccountId,
    required this.selectedContactAccountId,
    required this.onOpenAccount,
    required this.onOpenContactAccount,
    required this.entryFocusNode,
    required this.accounts,
    required this.googleConfigured,
    required this.microsoftConfigured,
    required this.connectingProvider,
    required this.onAddGoogle,
    required this.onAddMicrosoft,
    required this.onOpenSharedCalendar,
    required this.onManageCalendarSharing,
    required this.onAddApple,
    required this.onAddNextcloud,
    required this.onCancelConnection,
    required this.onReconnect,
    required this.onMigrate,
    required this.removingAccountIds,
    required this.registrationRecoveryIds,
    required this.refreshingAccountIds,
    required this.onRetryContacts,
    required this.onReconnectContacts,
    required this.onRemoveAccount,
    required this.contactAccounts,
    required this.contactSources,
    required this.busyContactAccountIds,
    required this.onEnableContacts,
    required this.onDisableContacts,
    required this.onSourceEnabled,
    required this.onAddCardDavContacts,
    required this.onAddNextcloudContacts,
    required this.onRemoveContactsOnly,
    required this.davCollections,
    required this.calendarSources,
    required this.onCalendarSelected,
    required this.onCalendarProviderVisibilityChanged,
    required this.davConflicts,
    required this.onRefreshCollections,
    required this.onEventsSelected,
    required this.onTasksSelected,
    required this.onResolveConflict,
    required this.onImportIcs,
    required this.subscriptions,
    required this.busySubscriptionIds,
    required this.onAddSubscription,
    required this.onRefreshSubscription,
    required this.onRenameSubscription,
    required this.onChangeSubscriptionColor,
    required this.onUnsubscribe,
  });

  final List<AccountEntity> accounts;
  final String? selectedAccountId, selectedContactAccountId;
  final ValueChanged<String> onOpenAccount, onOpenContactAccount;
  final FocusNode Function(String id) entryFocusNode;
  final bool googleConfigured;
  final bool microsoftConfigured;
  final BusyProvider? connectingProvider;
  final VoidCallback onAddGoogle;
  final VoidCallback onAddMicrosoft;
  final void Function(AccountEntity account) onOpenSharedCalendar;
  final void Function(AccountEntity account) onManageCalendarSharing;
  final VoidCallback onAddApple;
  final VoidCallback onAddNextcloud;
  final VoidCallback onCancelConnection;
  final void Function(AccountEntity account) onReconnect;
  final void Function(AccountEntity account) onMigrate;
  final Set<String> removingAccountIds;
  final Set<String> registrationRecoveryIds, refreshingAccountIds;
  final void Function(ContactAccount) onRetryContacts, onReconnectContacts;
  final void Function(AccountEntity account) onRemoveAccount;
  final List<ContactAccount> contactAccounts;
  final List<BusyMaxContactSourceSetting> contactSources;
  final Set<String> busyContactAccountIds;
  final void Function(AccountEntity account) onEnableContacts;
  final void Function(ContactAccount account) onDisableContacts;
  final Future<void> Function(String sourceKey, bool enabled) onSourceEnabled;
  final VoidCallback onAddCardDavContacts;
  final VoidCallback onAddNextcloudContacts;
  final void Function(ContactAccount account) onRemoveContactsOnly;
  final List<DavCollectionSettingsEntity> davCollections;
  final List<CalendarSourceEntity> calendarSources;
  final void Function(CalendarSourceEntity source, bool selected)
  onCalendarSelected;
  final void Function(CalendarSourceEntity source, bool visible)
  onCalendarProviderVisibilityChanged;
  final List<DavConflictEntity> davConflicts;
  final void Function(AccountEntity account) onRefreshCollections;
  final void Function(DavCollectionSettingsEntity collection, bool selected)
  onEventsSelected;
  final void Function(DavCollectionSettingsEntity collection, bool selected)
  onTasksSelected;
  final void Function(
    DavConflictEntity conflict,
    DavConflictResolution resolution,
  )
  onResolveConflict;
  final VoidCallback onImportIcs;
  final List<WebCalSubscriptionEntity> subscriptions;
  final Set<String> busySubscriptionIds;
  final VoidCallback onAddSubscription;
  final void Function(WebCalSubscriptionEntity subscription)
  onRefreshSubscription;
  final void Function(WebCalSubscriptionEntity subscription)
  onRenameSubscription;
  final void Function(WebCalSubscriptionEntity subscription)
  onChangeSubscriptionColor;
  final void Function(WebCalSubscriptionEntity subscription) onUnsubscribe;

  List<Widget> _contactConnectionOptions(
    BuildContext context,
    AccountEntity account,
  ) {
    final contact = contactAccounts
        .where(
          (c) =>
              c.id ==
              BusyMaxContactsController.linkedContactAccountId(account.id),
        )
        .firstOrNull;
    if (contact == null) return const [];
    final busy =
        busyContactAccountIds.contains(account.id) ||
        busyContactAccountIds.contains(contact.id);
    return [
      BusyMaxActionRow(
        title: context.l10n.contactsRetrySync,
        leading: const Icon(YaruIcons.sync),
        onTap: busy || !contact.enabled ? null : () => onRetryContacts(contact),
      ),
      BusyMaxActionRow(
        title:
            '${context.l10n.reconnectAccount} · ${context.l10n.contactsTitle}',
        leading: const Icon(YaruIcons.refresh),
        onTap: busy ? null : () => onReconnectContacts(contact),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final connecting = connectingProvider != null;
    final overview =
        selectedAccountId == null && selectedContactAccountId == null;
    return _SettingsPageLayout(
      children: [
        if (!overview && connecting)
          BusyMaxGroupedList(
            filled: true,
            children: [
              BusyMaxActionRow(
                title: l10n.cancelAccountConnection,
                leading: const Icon(YaruIcons.window_close),
                onTap: onCancelConnection,
              ),
            ],
          ),
        if (overview) ...[
          BusyMaxGroupedList(
            title: l10n.addAccount,
            titleStyle: _settingsAccountSubsectionStyle(context),
            filled: true,
            children: [
              BusyMaxActionRow(
                key: const ValueKey('add-account-nextcloud'),
                focusNode: entryFocusNode('add-account'),
                title: connectingProvider == BusyProvider.nextcloud
                    ? l10n.waitingForNextcloud
                    : l10n.addNextcloudAccount,
                leading: const Icon(YaruIcons.plus),
                onTap: connecting ? null : onAddNextcloud,
              ),
              BusyMaxActionRow(
                title: connectingProvider == BusyProvider.google
                    ? l10n.waitingForGoogleSignIn
                    : l10n.addGoogleAccount,
                subtitle: googleConfigured ? null : l10n.providerNotConfigured,
                leading: const Icon(YaruIcons.plus),
                onTap: connecting || !googleConfigured ? null : onAddGoogle,
              ),
              BusyMaxActionRow(
                title: connectingProvider == BusyProvider.microsoft
                    ? l10n.waitingForMicrosoftSignIn
                    : l10n.addMicrosoftAccount,
                subtitle: microsoftConfigured
                    ? null
                    : l10n.providerNotConfigured,
                leading: const Icon(YaruIcons.plus),
                onTap: connecting || !microsoftConfigured
                    ? null
                    : onAddMicrosoft,
              ),
              BusyMaxActionRow(
                title: connectingProvider == BusyProvider.appleICloud
                    ? l10n.waitingForAppleICloud
                    : l10n.addAppleICloudAccount,
                leading: const Icon(YaruIcons.plus),
                onTap: connecting ? null : onAddApple,
              ),
              if (connecting)
                BusyMaxActionRow(
                  title: l10n.cancelAccountConnection,
                  leading: const Icon(YaruIcons.window_close),
                  onTap: onCancelConnection,
                ),
            ],
          ),
          _AccountsLoadState(state: ref.watch(accountManagementStreamProvider)),
          if (accounts.isNotEmpty)
            BusyMaxGroupedList(
              title: l10n.connectedAccounts,
              titleStyle: _settingsAccountSubsectionStyle(context),
              filled: true,
              children: [
                for (final account in accounts)
                  _AccountOverviewRow(
                    key: ValueKey('account-entry-${account.id}'),
                    account: account,
                    focusNode: entryFocusNode('account:${account.id}'),
                    onOpen: () => onOpenAccount(account.id),
                  ),
              ],
            ),
        ],
        if (selectedAccountId != null &&
            !accounts.any((a) => a.id == selectedAccountId))
          _AccountsLoadState(state: ref.watch(accountManagementStreamProvider)),
        for (final account in accounts.where((a) => a.id == selectedAccountId))
          _AccountSettingsGroup(
            key: ValueKey('account-detail-${account.id}'),
            account: account,
            actions: _AccountManagementCard(
              account: account,
              removing: removingAccountIds.contains(account.id),
              onReconnect: connecting || removingAccountIds.contains(account.id)
                  ? null
                  : () => onReconnect(account),
              refreshing: refreshingAccountIds.contains(account.id),
              onRefreshCollections:
                  !refreshingAccountIds.contains(account.id) &&
                      (account.isSyncEligible ||
                          account.provider == BusyProvider.nextcloud &&
                              (account.connectionState ==
                                      AccountConnectionState
                                          .permissionChanged ||
                                  account.connectionState ==
                                      AccountConnectionState
                                          .unsupportedServerProfile))
                  ? () => onRefreshCollections(account)
                  : null,
              registrationRecovery: registrationRecoveryIds.contains(
                account.id,
              ),
              onReplaceRegistration: () => onMigrate(account),
            ),
            subsections: [
              _AccountSyncStatusCard(account: account),
              if (account.calendarsEnabled &&
                  (account.provider == BusyProvider.google ||
                      account.provider == BusyProvider.microsoft))
                _CalendarSettingsCard(
                  account: account,
                  sources: [
                    for (final source in calendarSources)
                      if (source.accountId == account.id) source,
                  ],
                  onSelected: onCalendarSelected,
                  onProviderVisibilityChanged:
                      onCalendarProviderVisibilityChanged,
                ),
              if (account.provider == BusyProvider.appleICloud ||
                  account.provider == BusyProvider.nextcloud)
                _DavCollectionsCard(
                  account: account,
                  collections: [
                    for (final collection in davCollections)
                      if (collection.accountId == account.id &&
                          (collection.supportsEvents ||
                              collection.supportsTasks))
                        collection,
                  ],
                  onEventsSelected: onEventsSelected,
                  onTasksSelected: onTasksSelected,
                ),
              if (davConflicts.any(
                (conflict) => conflict.accountId == account.id,
              ))
                _DavConflictsCard(
                  conflicts: [
                    for (final conflict in davConflicts)
                      if (conflict.accountId == account.id) conflict,
                  ],
                  onResolve: onResolveConflict,
                ),
              if (account.provider == BusyProvider.nextcloud)
                BusyMaxGroupedList(
                  filled: true,
                  children: [
                    BusyMaxActionRow(
                      title: context.l10n.nextcloudTrash,
                      leading: const Icon(YaruIcons.trash),
                      onTap: () => showLinuxNextcloudTrashDialog(
                        context,
                        accountId: account.id,
                      ),
                    ),
                  ],
                ),

              if (account.provider == BusyProvider.google ||
                  account.provider == BusyProvider.microsoft ||
                  account.provider == BusyProvider.nextcloud)
                _ContactsSettingsCard(
                  onReplaceRegistration: () => onMigrate(account),
                  account: account,
                  contactAccount: contactAccounts
                      .where(
                        (candidate) =>
                            candidate.id ==
                            BusyMaxContactsController.linkedContactAccountId(
                              account.id,
                            ),
                      )
                      .firstOrNull,
                  sources: [
                    for (final setting in contactSources)
                      if (setting.source.accountId ==
                          BusyMaxContactsController.linkedContactAccountId(
                            account.id,
                          ))
                        setting,
                  ],
                  busy:
                      busyContactAccountIds.contains(account.id) ||
                      busyContactAccountIds.contains(
                        BusyMaxContactsController.linkedContactAccountId(
                          account.id,
                        ),
                      ),
                  onEnableRead: () => onEnableContacts(account),
                  onRetry: onRetryContacts,
                  onReconnect: onReconnectContacts,
                  onDisable: () {
                    final contact = contactAccounts
                        .where(
                          (candidate) =>
                              candidate.id ==
                              BusyMaxContactsController.linkedContactAccountId(
                                account.id,
                              ),
                        )
                        .firstOrNull;
                    if (contact != null) onDisableContacts(contact);
                  },
                  onSourceEnabled: onSourceEnabled,
                ),
              if (account.provider == BusyProvider.microsoft &&
                  account.isSignedIn)
                BusyMaxGroupedList(
                  filled: true,
                  children: [
                    BusyMaxActionRow(
                      title: context.l10n.openSharedCalendar,
                      leading: const Icon(YaruIcons.calendar),
                      onTap: () => onOpenSharedCalendar(account),
                    ),
                  ],
                ),
              if (account.isSignedIn &&
                  calendarSources.any(
                    (source) =>
                        source.accountId == account.id &&
                        CloudCalendarSharingService.canManageSource(source),
                  ))
                BusyMaxGroupedList(
                  filled: true,
                  children: [
                    BusyMaxActionRow(
                      title: context.l10n.manageCalendarSharing,
                      leading: const Icon(YaruIcons.user),
                      onTap: () => onManageCalendarSharing(account),
                    ),
                  ],
                ),
              if (account.provider == BusyProvider.google ||
                  account.provider == BusyProvider.microsoft)
                _RegistrationAccountCard(
                  account: account,
                  onReconnect:
                      connecting || removingAccountIds.contains(account.id)
                      ? null
                      : () => onReconnect(account),
                  onMigrate: () => onMigrate(account),
                  additionalRows: _contactConnectionOptions(context, account),
                ),
              if (account.provider == BusyProvider.nextcloud ||
                  account.provider == BusyProvider.appleICloud)
                Padding(
                  padding: const EdgeInsets.only(top: BusyMaxSpacing.lg),
                  child: YaruExpandable(
                    key: ValueKey('account-advanced-${account.id}'),
                    header: Text(
                      l10n.advancedSection,
                      style: _settingsSectionHeaderStyle(context),
                    ),
                    expandIconSemanticLabel: l10n.advancedSection,
                    child: BusyMaxGroupedList(
                      filled: true,
                      children: [
                        BusyMaxActionRow(
                          key: ValueKey('reconnect-account-${account.id}'),
                          title: l10n.reconnectAccount,
                          leading: const Icon(YaruIcons.refresh),
                          onTap:
                              connecting ||
                                  removingAccountIds.contains(account.id)
                              ? null
                              : () => onReconnect(account),
                        ),
                        ..._contactConnectionOptions(context, account),
                      ],
                    ),
                  ),
                ),
              BusyMaxGroupedList(
                filled: true,
                children: [
                  BusyMaxActionRow(
                    key: ValueKey('remove-account-${account.id}'),
                    title: removingAccountIds.contains(account.id)
                        ? l10n.removingAccount
                        : l10n.removeAccount,
                    subtitle: l10n.removeAccountDescription,
                    leading: Icon(
                      YaruIcons.trash,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    enabled: !removingAccountIds.contains(account.id),
                    onTap: removingAccountIds.contains(account.id)
                        ? null
                        : () => onRemoveAccount(account),
                  ),
                ],
              ),
            ],
          ),
        if (selectedAccountId == null)
          _ContactsOnlySettingsCard(
            key: ValueKey(
              'contact-details-${selectedContactAccountId ?? 'overview'}',
            ),
            selectedAccountId: selectedContactAccountId,
            onOpenAccount: onOpenContactAccount,
            entryFocusNode: entryFocusNode,
            accountState: ref.watch(busyMaxContactAccountsProvider),
            independentIds: ref.watch(independentContactAccountIdsProvider),
            sources: contactSources,
            busyAccountIds: busyContactAccountIds,
            onAddCardDav: onAddCardDavContacts,
            onAddNextcloud: onAddNextcloudContacts,
            onRemove: onRemoveContactsOnly,
            onRetry: onRetryContacts,
            onReconnect: onReconnectContacts,
            onSourceEnabled: onSourceEnabled,
          ),
        if (overview) _CalendarImportCard(onImport: onImportIcs),
        if (overview)
          _CalendarSubscriptionsCard(
            subscriptions: subscriptions,
            busySubscriptionIds: busySubscriptionIds,
            onAdd: onAddSubscription,
            onRefresh: onRefreshSubscription,
            onRename: onRenameSubscription,
            onChangeColor: onChangeSubscriptionColor,
            onUnsubscribe: onUnsubscribe,
          ),
      ],
    );
  }
}

class _AccountsLoadState extends StatelessWidget {
  const _AccountsLoadState({required this.state});
  final AsyncValue<List<AccountEntity>> state;
  @override
  Widget build(BuildContext context) => state.hasError
      ? BusyMaxActionRow(
          title: context.l10n.accountsLoadFailed,
          leading: const Icon(YaruIcons.warning),
        )
      : state.isLoading
      ? BusyMaxActionRow(
          title: context.l10n.accountsLoading,
          leading: const YaruCircularProgressIndicator(),
        )
      : const SizedBox.shrink();
}

AccountSettingsFeedback? _primaryAccountFeedback(
  BuildContext context,
  WidgetRef ref,
  AccountEntity account,
) {
  final l10n = context.l10n;
  if (account.needsReconnect) {
    return AccountSettingsFeedback(
      AccountSettingsFailure.authorization,
      l10n.accountReconnectRequired,
      AccountSettingsRecovery.reconnect,
    );
  }
  if (account.connectionState == AccountConnectionState.permissionChanged) {
    return AccountSettingsFeedback(
      AccountSettingsFailure.permissions,
      l10n.davPermissionChanged,
      account.provider == BusyProvider.nextcloud
          ? AccountSettingsRecovery.revalidate
          : AccountSettingsRecovery.reconnect,
    );
  }
  if (account.connectionState ==
      AccountConnectionState.unsupportedServerProfile) {
    return AccountSettingsFeedback(
      AccountSettingsFailure.configuration,
      l10n.davUnsupportedServer,
      AccountSettingsRecovery.revalidate,
    );
  }
  if (account.provider == BusyProvider.nextcloud ||
      account.provider == BusyProvider.appleICloud) {
    final failure = ref
        .watch(accountSyncActivityProvider)
        .failure(account.id, 'dav');
    if (failure != null) {
      return AccountSettingsFeedback.fromError(l10n, failure);
    }
    final discovery = ref.watch(davAccountDiscoveryProvider(account.id));
    if (discovery.valueOrNull?.lastDiscoveryErrorCode case final code?) {
      return AccountSettingsFeedback.fromDavCode(l10n, code);
    }
    if (discovery.hasError) {
      return AccountSettingsFeedback.fromError(l10n, discovery.error!);
    }
  }
  if ((account.provider == BusyProvider.google ||
          account.provider == BusyProvider.microsoft) &&
      account.connectionState ==
          AccountConnectionState.temporarilyUnavailable) {
    final activity = ref.watch(accountSyncActivityProvider);
    final calendar = activity.failure(account.id, 'calendar');
    final tasks = activity.failure(account.id, 'tasks');
    if (calendar != null || tasks != null) {
      // Only the same recorded failure establishes a shared account problem.
      // Independent service outcomes keep their own messages and actions.
      return calendar != null && identical(calendar, tasks)
          ? AccountSettingsFeedback.fromError(l10n, calendar)
          : null;
    }
  }
  return account.connectionState ==
          AccountConnectionState.temporarilyUnavailable
      ? AccountSettingsFeedback(
          AccountSettingsFailure.temporary,
          l10n.accountSyncProblem,
          AccountSettingsRecovery.retry,
        )
      : null;
}

class _AccountOverviewRow extends ConsumerWidget {
  const _AccountOverviewRow({
    super.key,
    required this.account,
    required this.focusNode,
    required this.onOpen,
  });
  final AccountEntity account;
  final FocusNode focusNode;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final feedback = _primaryAccountFeedback(context, ref, account);
    final activity = ref.watch(accountSyncActivityProvider);
    final dav =
        account.provider == BusyProvider.nextcloud ||
        account.provider == BusyProvider.appleICloud;
    final running = [
      'dav',
      'calendar',
      'tasks',
    ].any((d) => activity.isRunning(account.id, d));
    final loading = dav
        ? ref.watch(davCollectionsStreamProvider).isLoading ||
              ref.watch(davAccountDiscoveryProvider(account.id)).isLoading
        : ref.watch(calendarSourcesStreamProvider).isLoading ||
              ref.watch(accountDomainSyncTimesProvider(account.id)).isLoading;
    final inventoryFailed = dav
        ? ref.watch(davCollectionsStreamProvider).hasError ||
              ref.watch(davAccountDiscoveryProvider(account.id)).hasError
        : ref.watch(calendarSourcesStreamProvider).hasError ||
              ref.watch(accountDomainSyncTimesProvider(account.id)).hasError;
    final visibilityFailed =
        account.provider == BusyProvider.google &&
        (ref.watch(calendarSourcesStreamProvider).valueOrNull ?? const [])
            .where((source) => source.accountId == account.id)
            .any((source) {
              final state = ref.watch(
                calendarVisibilityOperationProvider(source.id),
              );
              final operation = state.valueOrNull;
              return state.hasError ||
                  operation != null &&
                      (operation.lastErrorCode != null ||
                          !const [
                            'pending',
                            'in_progress',
                          ].contains(operation.state));
            });
    final domainFailure =
        [
          'calendar',
          'tasks',
        ].any((d) => activity.failure(account.id, d) != null) ||
        ref
                .watch(davCollectionsStreamProvider)
                .valueOrNull
                ?.any(
                  (c) => c.accountId == account.id && c.syncErrorCode != null,
                ) ==
            true ||
        ref
                .watch(calendarSourcesStreamProvider)
                .valueOrNull
                ?.any(
                  (s) =>
                      s.accountId == account.id &&
                      s.accessRole == 'unavailable',
                ) ==
            true;
    final status = running
        ? l10n.traySyncing
        : feedback != null
        ? switch (feedback.kind) {
            AccountSettingsFailure.authorization => l10n.accountReconnectStatus,
            AccountSettingsFailure.registration =>
              l10n.accountRegistrationStatus,
            _ => feedback.message,
          }
        : loading
        ? l10n.collectionsLoading
        : domainFailure || inventoryFailed || visibilityFailed
        ? l10n.accountSyncProblem
        : l10n.accountReadyToSync;
    return BusyMaxActionRow(
      focusNode: focusNode,
      title: _accountIdentityLabel(context, account),
      titleWidget: Text(_accountIdentityLabel(context, account)),
      subtitle: '${_accountProviderLabel(context, account.provider)} · $status',
      subtitleWidget: Text(
        '${_accountProviderLabel(context, account.provider)} · $status',
      ),
      leading: Icon(
        feedback != null || domainFailure || inventoryFailed || visibilityFailed
            ? YaruIcons.warning
            : YaruIcons.user,
      ),
      trailing: Icon(
        Directionality.of(context) == TextDirection.rtl
            ? YaruIcons.pan_start
            : YaruIcons.pan_end,
      ),
      onTap: onOpen,
    );
  }
}

class _IndependentContactOverviewRow extends ConsumerWidget {
  const _IndependentContactOverviewRow({
    super.key,
    required this.account,
    required this.focusNode,
    required this.onOpen,
    required this.busy,
  });
  final ContactAccount account;
  final FocusNode focusNode;
  final VoidCallback onOpen;
  final bool busy;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final server = ref.watch(independentContactServerProvider(account.id));
    final status = busy
        ? l10n.traySyncing
        : server.isLoading
        ? l10n.accountsLoading
        : !account.enabled
        ? l10n.contactsSuggestionsDisabled
        : account.errorCode != null
        ? _contactErrorMessage(context, account.errorCode!)
        : l10n.contactsSuggestionsEnabled;
    final identity = [
      account.subject,
      if (server.valueOrNull != null) server.valueOrNull.toString(),
      if (server.hasError) l10n.oauthSecureStorageUnavailable,
      status,
    ].where((s) => s.isNotEmpty).join(' · ');
    return BusyMaxActionRow(
      focusNode: focusNode,
      title: account.displayName,
      titleWidget: Text(account.displayName),
      subtitle: identity,
      subtitleWidget: Text(identity),
      leading: const Icon(YaruIcons.user),
      trailing: Icon(
        Directionality.of(context) == TextDirection.rtl
            ? YaruIcons.pan_start
            : YaruIcons.pan_end,
      ),
      onTap: onOpen,
    );
  }
}

class _IndependentContactIdentity extends ConsumerWidget {
  const _IndependentContactIdentity({required this.account});
  final ContactAccount account;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(independentContactServerProvider(account.id));
    return server.when(
      data: (uri) =>
          uri == null ? const SizedBox.shrink() : Text(uri.toString()),
      loading: () => Text(context.l10n.accountsLoading),
      error: (_, _) => Text(context.l10n.oauthSecureStorageUnavailable),
    );
  }
}

class _AccountSyncStatusCard extends ConsumerWidget {
  const _AccountSyncStatusCard({required this.account});
  final AccountEntity account;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final activity = ref.watch(accountSyncActivityProvider);
    final times = ref.watch(accountDomainSyncTimesProvider(account.id));
    final dav =
        account.provider == BusyProvider.nextcloud ||
        account.provider == BusyProvider.appleICloud;
    final collections = ref.watch(davCollectionsStreamProvider);
    final discoveryFailed =
        dav &&
        ref
                .watch(davAccountDiscoveryProvider(account.id))
                .valueOrNull
                ?.lastDiscoveryErrorCode !=
            null;
    Widget domain(String domain, String label) {
      final selected = collections.valueOrNull
          ?.where(
            (c) =>
                c.accountId == account.id &&
                (domain == 'calendar'
                    ? c.supportsEvents && c.eventsSelected
                    : c.supportsTasks && c.tasksSelected),
          )
          .toList();
      DateTime? last = times.valueOrNull?[domain];
      if (dav &&
          selected?.isNotEmpty == true &&
          selected!.every((c) => c.lastSyncAtUtc != null)) {
        last = selected
            .map((c) => c.lastSyncAtUtc!)
            .reduce((a, b) => a.isBefore(b) ? a : b);
      }
      final running = activity.isRunning(account.id, dav ? 'dav' : domain);
      final error = dav ? null : activity.failure(account.id, domain);
      final calendarUnavailable =
          domain == 'calendar' &&
          ref
                  .watch(calendarSourcesStreamProvider)
                  .valueOrNull
                  ?.any(
                    (s) =>
                        s.accountId == account.id &&
                        s.accessRole == 'unavailable',
                  ) ==
              true;
      final collectionError =
          discoveryFailed ||
          dav && selected?.any((c) => c.syncErrorCode != null) == true;
      final loadFailed =
          (dav ? collections.hasError : times.hasError) ||
          domain == 'calendar' &&
              ref.watch(calendarSourcesStreamProvider).hasError;
      final loading = dav ? collections.isLoading : times.isLoading;
      final message = running
          ? l10n.traySyncing
          : error != null
          ? AccountSettingsFeedback.fromError(l10n, error).message
          : loadFailed
          ? l10n.collectionsLoadFailed
          : collectionError || calendarUnavailable
          ? l10n.cachedSyncError
          : loading
          ? l10n.collectionsLoading
          : l10n.syncNoRecord;
      final subtitle = [
        if (running ||
            loading ||
            loadFailed ||
            error != null ||
            collectionError ||
            calendarUnavailable ||
            last == null)
          message,
        if (last != null)
          l10n.davLastSuccessfulSync(_formatDavDateTime(context, last)),
      ].join('\n');
      return BusyMaxActionRow(
        key: ValueKey('account-sync-$domain-${account.id}'),
        title: label,
        subtitle: subtitle,
        subtitleWidget: Text(subtitle),
        leading: Icon(
          error != null || collectionError || calendarUnavailable || loadFailed
              ? YaruIcons.warning
              : domain == 'calendar'
              ? YaruIcons.calendar
              : YaruIcons.checkmark,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: BusyMaxSpacing.lg),
      child: YaruExpandable(
        key: ValueKey('account-sync-details-${account.id}'),
        header: Text(
          l10n.accountSyncDetails,
          style: _settingsSectionHeaderStyle(context),
        ),
        expandIconSemanticLabel: l10n.accountSyncDetails,
        child: BusyMaxGroupedList(
          filled: true,
          children: [
            BusyMaxActionRow(
              title: l10n.davConnectionState,
              subtitle: _accountConnectionStateLabel(context, account),
            ),
            if (account.calendarsEnabled) domain('calendar', l10n.calendar),
            if (account.isTaskCapable) domain('tasks', l10n.tasks),
          ],
        ),
      ),
    );
  }
}

class _AccountSettingsGroup extends StatelessWidget {
  const _AccountSettingsGroup({
    super.key,
    required this.account,
    required this.actions,
    required this.subsections,
  });

  final AccountEntity account;
  final Widget actions;
  final List<Widget> subsections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            key: ValueKey('settings-account-heading-${account.id}'),
            _accountProviderLabel(context, account.provider),
            style: _settingsSectionHeaderStyle(context),
          ),
        ),
        const SizedBox(height: BusyMaxSpacing.xs),
        Text(_accountIdentityLabel(context, account)),
        actions,
        ...subsections,
      ],
    );
  }
}

AccountSettingsRecovery _contactRecovery(String? code) {
  if (code == 'reconnect-required' || code == 'linked-parent-removed') {
    return AccountSettingsRecovery.reconnect;
  }
  final parts = code?.split(':') ?? const <String>[];
  if (parts.length < 2) return AccountSettingsRecovery.retry;
  if (parts.first == 'contacts') {
    return const ['authentication', 'permission'].contains(parts[1])
        ? AccountSettingsRecovery.reconnect
        : AccountSettingsRecovery.retry;
  }
  if (parts.first == 'oauth') {
    final kind = OAuthFailureKind.values
        .where((k) => k.name == parts[1])
        .firstOrNull;
    return switch (kind) {
      OAuthFailureKind.registrationUnavailable ||
      OAuthFailureKind.clientRejected ||
      OAuthFailureKind.configuration =>
        AccountSettingsRecovery.replaceRegistration,
      OAuthFailureKind.expiredGrant ||
      OAuthFailureKind.permission ||
      OAuthFailureKind.wrongAccount ||
      OAuthFailureKind.identityUnverified => AccountSettingsRecovery.reconnect,
      _ => AccountSettingsRecovery.retry,
    };
  }
  return AccountSettingsRecovery.retry;
}

String _contactErrorMessage(BuildContext context, String code) {
  final parts = code.split(':');
  if (parts.length >= 2 &&
      (parts.first == 'contacts' && parts[1] == 'offline' ||
          parts.first == 'oauth' &&
              const ['network', 'timeout'].contains(parts[1]))) {
    return context.l10n.accountServiceUnreachable;
  }
  return _contactRecovery(code) == AccountSettingsRecovery.replaceRegistration
      ? context.l10n.accountRegistrationStatus
      : localizedContactsStatus(context.l10n, code);
}

class _ContactsSettingsCard extends ConsumerWidget {
  const _ContactsSettingsCard({
    required this.account,
    required this.contactAccount,
    required this.sources,
    required this.busy,
    required this.onEnableRead,
    required this.onDisable,
    required this.onSourceEnabled,
    required this.onRetry,
    required this.onReconnect,
    required this.onReplaceRegistration,
  });

  final AccountEntity account;
  final ContactAccount? contactAccount;
  final List<BusyMaxContactSourceSetting> sources;
  final bool busy;
  final VoidCallback onEnableRead;
  final VoidCallback onReplaceRegistration;
  final VoidCallback onDisable;
  final Future<void> Function(String sourceKey, bool enabled) onSourceEnabled;
  final void Function(ContactAccount) onRetry, onReconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = contactAccount;
    final l10n = context.l10n;
    final contactState = ref.watch(busyMaxContactAccountsProvider);
    final sourceState = ref.watch(busyMaxContactSourceSettingsProvider);
    if (contactState.isLoading && !contactState.hasValue) {
      return BusyMaxGroupedList(
        title: l10n.contactsTitle,
        filled: true,
        children: [BusyMaxActionRow(title: l10n.accountsLoading)],
      );
    }
    if (contactState.hasError && !contactState.hasValue) {
      return BusyMaxGroupedList(
        title: l10n.contactsTitle,
        filled: true,
        children: [
          BusyMaxActionRow(
            title: l10n.contactsSyncFailed,
            onTap: () => ref.invalidate(busyMaxContactAccountsProvider),
          ),
        ],
      );
    }
    final recovery = _contactRecovery(contact?.errorCode);
    final needsRecovery =
        contact?.enabled == true && contact?.errorCode != null;
    return BusyMaxGroupedList(
      title: l10n.contactsTitle,
      titleStyle: _settingsAccountSubsectionStyle(context),
      description: l10n.accountContactSuggestions,
      filled: true,
      children: [
        if (busy)
          BusyMaxActionRow(
            title: l10n.traySyncing,
            leading: const YaruCircularProgressIndicator(),
          ),
        if (contact == null)
          BusyMaxActionRow(
            key: ValueKey('enable-contacts-read-${account.id}'),
            title: l10n.contactsEnableSuggestions,
            subtitle: account.provider == BusyProvider.nextcloud
                ? l10n.contactsReadOnlyUse
                : l10n.contactsReadPermissionDescription,
            leading: const Icon(YaruIcons.user),
            onTap: busy ? null : onEnableRead,
          )
        else ...[
          BusyMaxSwitchRow(
            key: ValueKey('enable-contacts-read-${account.id}'),
            title: l10n.contactsEnableSuggestions,
            subtitle: l10n.contactsReadOnlyUse,
            value: contact.enabled,
            enabled: !busy,
            leading: const Icon(YaruIcons.user),
            onChanged: (enabled) => enabled ? onEnableRead() : onDisable(),
          ),
          if (needsRecovery)
            BusyMaxActionRow(
              title: _contactErrorMessage(context, contact.errorCode!),
              titleWidget: Text(
                _contactErrorMessage(context, contact.errorCode!),
              ),
              leading: const Icon(YaruIcons.warning),
              trailing: BusyMaxPushButton.standard(
                key: ValueKey('reconnect-contacts-${account.id}'),
                onPressed: busy
                    ? null
                    : recovery == AccountSettingsRecovery.replaceRegistration
                    ? onReplaceRegistration
                    : recovery == AccountSettingsRecovery.reconnect
                    ? () => onReconnect(contact)
                    : () => onRetry(contact),
                child: Text(
                  recovery == AccountSettingsRecovery.replaceRegistration
                      ? l10n.registrationReplace
                      : recovery == AccountSettingsRecovery.reconnect
                      ? l10n.reconnectAccount
                      : l10n.contactsRetrySync,
                ),
              ),
            ),
          if (sourceState.hasError)
            BusyMaxActionRow(
              title: l10n.contactsSourcesUnavailable,
              trailing: BusyMaxPushButton.standard(
                onPressed: () =>
                    ref.invalidate(busyMaxContactSourceSettingsProvider),
                child: Text(l10n.retry),
              ),
            ),
          if (sources.isEmpty && !needsRecovery && !sourceState.hasError)
            BusyMaxActionRow(
              title: sourceState.isLoading
                  ? l10n.collectionsLoading
                  : l10n.contactsNoAddressBooks,
            ),
          for (final setting in sources)
            _ContactSourceSettingsRow(
              setting: setting,
              onChanged: (enabled) =>
                  onSourceEnabled(setting.source.key, enabled),
            ),
        ],
      ],
    );
  }
}

class _ContactsOnlySettingsCard extends ConsumerWidget {
  const _ContactsOnlySettingsCard({
    super.key,
    required this.selectedAccountId,
    required this.onOpenAccount,
    required this.entryFocusNode,
    required this.accountState,
    required this.independentIds,
    required this.sources,
    required this.busyAccountIds,
    required this.onAddCardDav,
    required this.onAddNextcloud,
    required this.onRemove,
    required this.onSourceEnabled,
    required this.onRetry,
    required this.onReconnect,
  });
  final String? selectedAccountId;
  final ValueChanged<String> onOpenAccount;
  final FocusNode Function(String) entryFocusNode;
  final AsyncValue<List<ContactAccount>> accountState;
  final AsyncValue<Set<String>> independentIds;
  final List<BusyMaxContactSourceSetting> sources;
  final Set<String> busyAccountIds;
  final VoidCallback onAddCardDav, onAddNextcloud;
  final void Function(ContactAccount) onRemove, onRetry, onReconnect;
  final Future<void> Function(String, bool) onSourceEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Cached values remain useful during refresh and failure. An unavailable
    // inventory still has its own status; it is never a successful empty list.
    final accounts = [
      for (final account in accountState.valueOrNull ?? <ContactAccount>[])
        if (independentIds.valueOrNull?.contains(account.id) == true) account,
    ];
    final accountsFailed = accountState.hasError && !accountState.isLoading;
    final independentIdsFailed =
        independentIds.hasError && !independentIds.isLoading;
    final inventoryFailed = accountsFailed || independentIdsFailed;
    final inventoryLoading = accountState.isLoading || independentIds.isLoading;
    void retryInventory() {
      if (accountsFailed) {
        ref.invalidate(busyMaxContactAccountsProvider);
      }
      if (independentIdsFailed) {
        ref.invalidate(independentContactAccountIdsProvider);
      }
    }

    Widget inventoryFailure() => BusyMaxActionRow(
      key: const ValueKey('contacts-inventory-error'),
      title: l10n.contactsAccountsUnavailable,
      leading: const Icon(YaruIcons.warning),
      trailing: BusyMaxPushButton.standard(
        key: const ValueKey('contacts-inventory-retry'),
        onPressed: retryInventory,
        child: Text(l10n.retry),
      ),
    );
    if (selectedAccountId != null) {
      final sourceState = ref.watch(busyMaxContactSourceSettingsProvider);
      final account = accounts
          .where((a) => a.id == selectedAccountId)
          .firstOrNull;
      if (account == null) {
        return inventoryFailed
            ? inventoryFailure()
            : BusyMaxActionRow(title: l10n.accountsLoading);
      }
      final busy = busyAccountIds.contains(account.id);
      final recovery = _contactRecovery(account.errorCode);
      final reconnect =
          !account.enabled || recovery != AccountSettingsRecovery.retry;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              account.displayName,
              style: _settingsSectionHeaderStyle(context),
            ),
          ),
          const SizedBox(height: BusyMaxSpacing.xs),
          Text(account.subject),
          _IndependentContactIdentity(account: account),
          BusyMaxGroupedList(
            title: l10n.contactsTitle,
            description: l10n.contactsOnlyDescription,
            filled: true,
            children: [
              if (busy)
                BusyMaxActionRow(
                  title: l10n.traySyncing,
                  leading: const YaruCircularProgressIndicator(),
                ),
              if (!account.enabled || account.errorCode != null)
                BusyMaxActionRow(
                  title: account.errorCode == null
                      ? l10n.contactsSuggestionsDisabled
                      : _contactErrorMessage(context, account.errorCode!),
                  titleWidget: Text(
                    account.errorCode == null
                        ? l10n.contactsSuggestionsDisabled
                        : _contactErrorMessage(context, account.errorCode!),
                  ),
                  leading: Icon(
                    account.errorCode == null
                        ? YaruIcons.user
                        : YaruIcons.warning,
                  ),
                  trailing: BusyMaxPushButton.standard(
                    key: ValueKey('contact-account-recovery-${account.id}'),
                    onPressed: busy
                        ? null
                        : reconnect
                        ? () => onReconnect(account)
                        : () => onRetry(account),
                    child: Text(
                      reconnect
                          ? l10n.reconnectAccount
                          : l10n.contactsRetrySync,
                    ),
                  ),
                ),
              for (final setting in sources.where(
                (s) => s.source.accountId == account.id,
              ))
                _ContactSourceSettingsRow(
                  setting: setting,
                  onChanged: (enabled) =>
                      onSourceEnabled(setting.source.key, enabled),
                ),
              if (sourceState.hasError)
                BusyMaxActionRow(
                  title: l10n.contactsSourcesUnavailable,
                  trailing: BusyMaxPushButton.standard(
                    onPressed: () =>
                        ref.invalidate(busyMaxContactSourceSettingsProvider),
                    child: Text(l10n.retry),
                  ),
                ),
              if (account.enabled &&
                  account.errorCode == null &&
                  !sourceState.hasError &&
                  !sources.any((s) => s.source.accountId == account.id))
                BusyMaxActionRow(
                  title: sourceState.isLoading
                      ? l10n.collectionsLoading
                      : l10n.contactsNoAddressBooks,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: BusyMaxSpacing.lg),
            child: YaruExpandable(
              header: Text(
                l10n.advancedSection,
                style: _settingsSectionHeaderStyle(context),
              ),
              key: ValueKey('contact-account-advanced-${account.id}'),
              expandIconSemanticLabel: l10n.advancedSection,
              child: BusyMaxGroupedList(
                filled: true,
                children: [
                  BusyMaxActionRow(
                    title: l10n.reconnectAccount,
                    leading: const Icon(YaruIcons.refresh),
                    onTap: busy ? null : () => onReconnect(account),
                  ),
                  BusyMaxActionRow(
                    title: l10n.contactsRetrySync,
                    leading: const Icon(YaruIcons.sync),
                    onTap: busy || !account.enabled
                        ? null
                        : () => onRetry(account),
                  ),
                ],
              ),
            ),
          ),
          BusyMaxGroupedList(
            filled: true,
            children: [
              BusyMaxActionRow(
                key: ValueKey('remove-contacts-only-${account.id}'),
                title: l10n.removeAction,
                leading: Icon(
                  YaruIcons.trash,
                  color: Theme.of(context).colorScheme.error,
                ),
                onTap: busy ? null : () => onRemove(account),
              ),
            ],
          ),
        ],
      );
    }
    return BusyMaxGroupedList(
      title: l10n.contactsIndependentAccounts,
      titleStyle: _settingsSectionHeaderStyle(context),
      description: l10n.contactsOnlyDescription,
      filled: true,
      children: [
        BusyMaxActionRow(
          key: const ValueKey('add-carddav-contacts'),
          title: l10n.contactsAddCardDav,
          leading: const Icon(YaruIcons.plus),
          onTap: onAddCardDav,
        ),
        BusyMaxActionRow(
          key: const ValueKey('add-nextcloud-contacts'),
          title: l10n.contactsAddNextcloud,
          leading: const Icon(YaruIcons.plus),
          onTap: onAddNextcloud,
        ),
        if (inventoryLoading)
          BusyMaxActionRow(
            key: const ValueKey('contacts-inventory-loading'),
            title: l10n.accountsLoading,
          ),
        if (inventoryFailed) inventoryFailure(),
        for (final account in accounts)
          _IndependentContactOverviewRow(
            key: ValueKey('contact-account-entry-${account.id}'),
            account: account,
            busy: busyAccountIds.contains(account.id),
            focusNode: entryFocusNode('contacts:${account.id}'),
            onOpen: () => onOpenAccount(account.id),
          ),
      ],
    );
  }
}

class _ContactSourceSettingsRow extends StatefulWidget {
  const _ContactSourceSettingsRow({
    required this.setting,
    required this.onChanged,
  });
  final BusyMaxContactSourceSetting setting;
  final Future<void> Function(bool) onChanged;
  @override
  State<_ContactSourceSettingsRow> createState() =>
      _ContactSourceSettingsRowState();
}

class _ContactSourceSettingsRowState extends State<_ContactSourceSettingsRow> {
  bool _pending = false;
  late bool _value = widget.setting.enabled;
  String? _error;
  @override
  void didUpdateWidget(covariant _ContactSourceSettingsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting.enabled != widget.setting.enabled) {
      _value = widget.setting.enabled;
    }
  }

  Future<void> _toggle(bool value) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.onChanged(value);
      if (mounted) setState(() => _value = value);
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.contactsPreferenceFailed);
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => BusyMaxActionRow(
    title: widget.setting.source.name,
    subtitle: _error ?? context.l10n.contactsUseForAttendees,
    leading: const Icon(YaruIcons.user),
    trailing: _pending
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(),
          )
        : YaruSwitch(
            key: ValueKey('contact-source-${widget.setting.source.key}'),
            value: _value,
            onChanged: (value) => unawaited(_toggle(value)),
          ),
  );
}

TextStyle? _settingsAccountSubsectionStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurface,
    fontWeight: FontWeight.bold,
  );
}

class _CalendarSettingsCard extends ConsumerWidget {
  const _CalendarSettingsCard({
    required this.sources,
    required this.account,
    required this.onSelected,
    required this.onProviderVisibilityChanged,
  });

  final List<CalendarSourceEntity> sources;
  final AccountEntity account;
  final void Function(CalendarSourceEntity source, bool selected) onSelected;
  final void Function(CalendarSourceEntity source, bool visible)
  onProviderVisibilityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(calendarSourcesStreamProvider);
    final showsProviderVisibility = sources.any(
      (source) => source.provider == BusyProvider.google,
    );
    return BusyMaxGroupedList(
      title: l10n.calendars,
      titleStyle: _settingsAccountSubsectionStyle(context),
      filled: true,
      description: showsProviderVisibility ? l10n.googleVisibilityHelp : null,
      children: sources.isEmpty
          ? [
              BusyMaxActionRow(
                title: _collectionEmptyMessage(
                  context,
                  ref,
                  account: account,
                  loading: ref.watch(calendarSourcesStreamProvider).isLoading,
                  failed: ref.watch(calendarSourcesStreamProvider).hasError,
                ),
                leading: const Icon(YaruIcons.calendar),
              ),
            ]
          : [
              if (state.hasError)
                BusyMaxActionRow(
                  title: l10n.collectionsLoadFailed,
                  titleWidget: Text(l10n.collectionsLoadFailed),
                  leading: const Icon(YaruIcons.warning),
                ),
              if (state.isLoading)
                BusyMaxActionRow(
                  title: l10n.collectionsLoading,
                  leading: const YaruCircularProgressIndicator(),
                ),
              for (final source in sources)
                _CalendarSettingsRow(
                  key: ValueKey('settings-calendar-row-${source.id}'),
                  source: source,
                  onSelected: onSelected,
                  onProviderVisibilityChanged: onProviderVisibilityChanged,
                ),
            ],
    );
  }
}

class _CalendarSettingsRow extends ConsumerStatefulWidget {
  const _CalendarSettingsRow({
    super.key,
    required this.source,
    required this.onSelected,
    required this.onProviderVisibilityChanged,
  });
  final CalendarSourceEntity source;
  final void Function(CalendarSourceEntity, bool) onSelected;
  final void Function(CalendarSourceEntity, bool) onProviderVisibilityChanged;
  @override
  ConsumerState<_CalendarSettingsRow> createState() =>
      _CalendarSettingsRowState();
}

class _CalendarSettingsRowState extends ConsumerState<_CalendarSettingsRow> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final l10n = context.l10n;
    final google = source.provider == BusyProvider.google;
    final operationState = google
        ? ref.watch(calendarVisibilityOperationProvider(source.id))
        : null;
    final pending = operationState?.valueOrNull;
    final failed =
        pending != null &&
        (pending.lastErrorCode != null ||
            !const ['pending', 'in_progress'].contains(pending.state));
    var confirmedHidden = source.hidden;
    if (failed) {
      final request = jsonDecode(pending.requestJson) as Map;
      final previous = request[calendarPatchPreviousValuesKey];
      final baseline = jsonDecode(pending.baselineRawJson ?? '{}') as Map;
      confirmedHidden = previous is Map && previous['hidden'] is bool
          ? previous['hidden'] as bool
          : baseline['hidden'] == true;
    }
    final shared =
        MicrosoftSharedPrimaryCalendarAddress.parse(
              source.providerCalendarId,
            ) !=
            null ||
        source.dataOwner != null &&
            source.authenticatedAccountEmail != null &&
            source.dataOwner!.toLowerCase() !=
                source.authenticatedAccountEmail!.toLowerCase();
    final details = [
      if (shared) l10n.sharedCollection,
      if (source.readOnly) l10n.readOnlySharedCollection,
      if (source.accessRole == 'unavailable') l10n.sharedCalendarUnavailable,
    ].join(' · ');
    final localValue = source.selected && !source.hidden;
    void selectLocal(bool value) => widget.onSelected(source, value);
    Widget localVisibilityControl() => Semantics(
      label: '${l10n.showInBusyMax} · ${source.summary}',
      child: BusyMaxYaruFocusBorder(
        builder: (context, focusNode) => YaruSwitch(
          key: ValueKey('settings-calendar-schedule-${source.id}'),
          value: localValue,
          focusNode: focusNode,
          hasFocusBorder: false,
          onChanged: source.hidden ? null : selectLocal,
        ),
      ),
    );
    final localRow = BusyMaxActionRow(
      title: google ? l10n.showInBusyMax : source.summary,
      titleWidget: Text(google ? l10n.showInBusyMax : source.summary),
      subtitle: google || details.isEmpty ? null : details,
      subtitleWidget: google || details.isEmpty ? null : Text(details),
      leading: google
          ? null
          : _DavCollectionIndicator(color: source.backgroundColor),
      onTap: source.hidden ? null : () => selectLocal(!localValue),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          localVisibilityControl(),
          if (source.provider == BusyProvider.microsoft &&
              source.capabilities.removalMode ==
                  CalendarRemovalMode.removeFromList)
            YaruIconButton(
              key: ValueKey('settings-calendar-remove-${source.id}'),
              tooltip: '${l10n.removeFromMyCalendars} · ${source.summary}',
              icon: const Icon(YaruIcons.trash),
              onPressed: () => _removeSharedCalendar(context),
            ),
        ],
      ),
    );
    if (!google) return localRow;
    final busyVisibility =
        operationState!.isLoading && !operationState.hasValue;
    final visibilityLoadFailed = operationState.hasError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _expanded,
          child: YaruExpandable(
            key: ValueKey('settings-calendar-expander-${source.id}'),
            isExpanded: _expanded,
            onChange: (value) => setState(() => _expanded = value),
            expandIconSemanticLabel: source.summary,
            header: BusyMaxActionRow(
              title: source.summary,
              titleWidget: Text(source.summary),
              subtitle: details.isEmpty ? null : details,
              subtitleWidget: details.isEmpty ? null : Text(details),
              leading: _DavCollectionIndicator(color: source.backgroundColor),
            ),
            child: Column(
              children: [
                localRow,
                BusyMaxActionRow(
                  title: l10n.showInGoogleCalendarList,
                  titleWidget: Text(l10n.showInGoogleCalendarList),
                  subtitle: source.primaryCalendar
                      ? l10n.primaryCalendarVisibilityExplanation
                      : null,
                  subtitleWidget: source.primaryCalendar
                      ? Text(l10n.primaryCalendarVisibilityExplanation)
                      : null,
                  trailing: Semantics(
                    label:
                        '${l10n.showInGoogleCalendarList} · ${source.summary}',
                    child: BusyMaxYaruFocusBorder(
                      builder: (context, focusNode) => YaruSwitch(
                        key: ValueKey(
                          'settings-calendar-provider-${source.id}',
                        ),
                        value: !confirmedHidden,
                        focusNode: focusNode,
                        hasFocusBorder: false,
                        onChanged:
                            source.capabilities.canChangeProviderVisibility &&
                                !failed &&
                                !busyVisibility &&
                                !visibilityLoadFailed
                            ? (visible) => widget.onProviderVisibilityChanged(
                                source,
                                visible,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (busyVisibility)
          BusyMaxActionRow(
            title: l10n.collectionsLoading,
            leading: const YaruCircularProgressIndicator(),
          ),
        if (visibilityLoadFailed)
          BusyMaxActionRow(
            title: l10n.accountSyncProblem,
            trailing: BusyMaxPushButton.standard(
              onPressed: () => ref.invalidate(
                calendarVisibilityOperationProvider(source.id),
              ),
              child: Text(l10n.retry),
            ),
          ),
        if (pending != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BusyMaxSpacing.md,
              BusyMaxSpacing.xs,
              BusyMaxSpacing.md,
              BusyMaxSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  failed
                      ? l10n.calendarRemoteFailed
                      : l10n.calendarRemotePending,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (failed)
                  _CalendarVisibilityRecoveryActions(
                    key: ValueKey('visibility-recovery-${pending.id}'),
                    source: source,
                    operation: pending,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _removeSharedCalendar(BuildContext context) async {
    final source = widget.source;
    final l10n = context.l10n;
    final confirmed = await showBusyMaxConfirm(
      context,
      title: l10n.removeFromMyCalendars,
      message: l10n.removeOpenedSharedCalendarConfirmation(source.summary),
      confirmLabel: l10n.removeAction,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(calendarRepositoryProvider).deleteLocalSource(source.id);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AccountSettingsFeedback.fromError(l10n, error).message,
            ),
          ),
        );
      }
    }
  }
}

class _CalendarVisibilityRecoveryActions extends ConsumerStatefulWidget {
  const _CalendarVisibilityRecoveryActions({
    super.key,
    required this.source,
    required this.operation,
  });
  final CalendarSourceEntity source;
  final PendingOp operation;

  @override
  ConsumerState<_CalendarVisibilityRecoveryActions> createState() =>
      _CalendarVisibilityRecoveryActionsState();
}

class _CalendarVisibilityRecoveryActionsState
    extends ConsumerState<_CalendarVisibilityRecoveryActions> {
  bool _busy = false;

  Future<void> _resolve({required bool discard}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      // Discard restores the entire merged patch. List every affected setting,
      // including personal settings queued alongside visibility.
      final request = jsonDecode(widget.operation.requestJson) as Map;
      final settings = [
        if (request.containsKey('summary')) l10n.title,
        if (request.containsKey('backgroundColor') ||
            request.containsKey('foregroundColor') ||
            request.containsKey('colorId'))
          l10n.calendarColor,
        if (request.containsKey('hidden')) l10n.showInGoogleCalendarList,
      ];
      if (discard &&
          !await showBusyMaxConfirm(
            context,
            title: l10n.discardPendingOperation,
            message: l10n.discardCalendarSettingsConfirmation(
              widget.source.summary,
              settings.map((setting) => '• $setting').join('\n'),
            ),
            confirmLabel: l10n.discard,
          )) {
        return;
      }
      if (!mounted) return;
      final service = ref.read(
        pendingOpResolutionServiceForAccountProvider(widget.source.accountId),
      );
      if (discard) {
        await service.discard(widget.operation.id);
      } else {
        await service.retryNow(widget.operation.id);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AccountSettingsFeedback.fromError(l10n, error).message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: BusyMaxSpacing.sm),
      child: Wrap(
        spacing: BusyMaxSpacing.sm,
        runSpacing: BusyMaxSpacing.sm,
        children: [
          BusyMaxPushButton.standard(
            key: ValueKey(
              'settings-calendar-visibility-retry-${widget.source.id}',
            ),
            onPressed: _busy ? null : () => _resolve(discard: false),
            child: Text(
              l10n.retry,
              semanticsLabel: '${l10n.retry} · ${widget.source.summary}',
            ),
          ),
          BusyMaxPushButton.standard(
            key: ValueKey(
              'settings-calendar-visibility-discard-${widget.source.id}',
            ),
            onPressed: _busy ? null : () => _resolve(discard: true),
            child: Text(
              l10n.discard,
              semanticsLabel: '${l10n.discard} · ${widget.source.summary}',
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarImportCard extends StatelessWidget {
  const _CalendarImportCard({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return BusyMaxGroupedList(
      title: context.l10n.calendarImport,
      titleStyle: _settingsSectionHeaderStyle(context),
      description: context.l10n.calendarImportDescription,
      filled: true,
      children: [
        BusyMaxActionRow(
          key: const ValueKey('import-ics-file'),
          title: context.l10n.importIcsFile,
          leading: const Icon(YaruIcons.document_open),
          onTap: onImport,
        ),
      ],
    );
  }
}

class _CalendarSubscriptionsCard extends StatelessWidget {
  const _CalendarSubscriptionsCard({
    required this.subscriptions,
    required this.busySubscriptionIds,
    required this.onAdd,
    required this.onRefresh,
    required this.onRename,
    required this.onChangeColor,
    required this.onUnsubscribe,
  });

  final List<WebCalSubscriptionEntity> subscriptions;
  final Set<String> busySubscriptionIds;
  final VoidCallback onAdd;
  final void Function(WebCalSubscriptionEntity) onRefresh;
  final void Function(WebCalSubscriptionEntity) onRename;
  final void Function(WebCalSubscriptionEntity) onChangeColor;
  final void Function(WebCalSubscriptionEntity) onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BusyMaxGroupedList(
          title: l10n.calendarSubscriptions,
          titleStyle: _settingsSectionHeaderStyle(context),
          description: l10n.calendarSubscriptionsDescription,
          filled: true,
          children: [
            BusyMaxActionRow(
              key: const ValueKey('add-calendar-subscription'),
              title: l10n.addCalendarSubscription,
              leading: const Icon(YaruIcons.plus),
              onTap: onAdd,
            ),
          ],
        ),
        for (final subscription in subscriptions)
          BusyMaxGroupedList(
            key: ValueKey('calendar-subscription-${subscription.id}'),
            filled: true,
            children: [
              BusyMaxActionRow(
                title: subscription.name,
                subtitle: subscription.safeOrigin,
                leading: _DavCollectionIndicator(color: subscription.color),
              ),
              BusyMaxActionRow(
                title: l10n.subscriptionReadOnly,
                subtitle: _subscriptionTiming(context, subscription),
                leading: const Icon(YaruIcons.lock),
              ),
              BusyMaxActionRow(
                title: subscription.lastFailureCode == null
                    ? l10n.subscriptionStatusHealthy
                    : l10n.subscriptionStatusIssue(
                        subscription.lastFailureCode!,
                      ),
                subtitle: l10n.subscriptionNextRefresh(
                  _formatDavDateTime(context, subscription.nextRefreshAtUtc),
                ),
                leading: Icon(
                  subscription.lastFailureCode == null
                      ? YaruIcons.checkmark
                      : YaruIcons.warning,
                ),
              ),
              BusyMaxActionRow(
                title: l10n.refreshNow,
                leading: const Icon(YaruIcons.sync),
                onTap: busySubscriptionIds.contains(subscription.id)
                    ? null
                    : () => onRefresh(subscription),
              ),
              BusyMaxActionRow(
                title: l10n.rename,
                leading: const Icon(YaruIcons.pen),
                onTap: busySubscriptionIds.contains(subscription.id)
                    ? null
                    : () => onRename(subscription),
              ),
              BusyMaxActionRow(
                title: l10n.calendarColor,
                leading: const Icon(YaruIcons.color_select),
                onTap: busySubscriptionIds.contains(subscription.id)
                    ? null
                    : () => onChangeColor(subscription),
              ),
              BusyMaxActionRow(
                title: l10n.unsubscribe,
                leading: Icon(
                  YaruIcons.trash,
                  color: Theme.of(context).colorScheme.error,
                ),
                destructive: true,
                onTap: busySubscriptionIds.contains(subscription.id)
                    ? null
                    : () => onUnsubscribe(subscription),
              ),
            ],
          ),
      ],
    );
  }
}

String _subscriptionTiming(
  BuildContext context,
  WebCalSubscriptionEntity subscription,
) {
  final last = subscription.lastSuccessfulSyncAtUtc;
  return last == null
      ? context.l10n.subscriptionNeverRefreshed
      : context.l10n.subscriptionLastRefresh(_formatDavDateTime(context, last));
}

final class _CardDavContactsInput {
  const _CardDavContactsInput({
    required this.label,
    required this.server,
    required this.username,
    required this.password,
  });

  final String label;
  final Uri server;
  final String username;
  final String password;
}

class _CardDavContactsDialog extends StatefulWidget {
  const _CardDavContactsDialog();

  @override
  State<_CardDavContactsDialog> createState() => _CardDavContactsDialogState();
}

class _CardDavContactsDialogState extends State<_CardDavContactsDialog> {
  final _label = TextEditingController();
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final controller in [_label, _server, _username, _password]) {
      controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final controller in [_label, _server, _username, _password]) {
      controller
        ..removeListener(_changed)
        ..dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  Uri? get _validServer {
    final value = Uri.tryParse(_server.text.trim());
    return value != null &&
            value.scheme == 'https' &&
            value.host.isNotEmpty &&
            value.userInfo.isEmpty &&
            !value.hasQuery &&
            !value.hasFragment
        ? value
        : null;
  }

  bool get _valid =>
      _label.text.trim().isNotEmpty &&
      _validServer != null &&
      _username.text.isNotEmpty &&
      _password.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BusyMaxDialogShell(
      title: l10n.contactsAddCardDav,
      maxWidth: BusyMaxSizes.compactDetailsWidth,
      // The shared shell names the content list `children`; its action bar is
      // intentionally specified afterwards for visual reading order.
      // ignore: sort_child_properties_last
      children: [
        TextField(
          key: const ValueKey('carddav-contacts-label'),
          controller: _label,
          decoration: InputDecoration(labelText: l10n.subscriptionName),
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        TextField(
          key: const ValueKey('carddav-contacts-server'),
          controller: _server,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: l10n.contactsServerUrlLabel),
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        TextField(
          key: const ValueKey('carddav-contacts-username'),
          controller: _username,
          decoration: InputDecoration(labelText: l10n.contactsUsernameLabel),
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        TextField(
          key: const ValueKey('carddav-contacts-password'),
          controller: _password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(labelText: l10n.contactsPasswordLabel),
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        Text(l10n.contactsReadOnlyUse),
      ],
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        BusyMaxPushButton.suggested(
          key: const ValueKey('confirm-carddav-contacts'),
          onPressed: !_valid
              ? null
              : () => Navigator.of(context).pop(
                  _CardDavContactsInput(
                    label: _label.text.trim(),
                    server: _validServer!,
                    username: _username.text,
                    password: _password.text,
                  ),
                ),
          child: Text(l10n.connectAccountAction),
        ),
      ],
    );
  }
}

final class _WebCalAddInput {
  const _WebCalAddInput({
    required this.url,
    required this.name,
    required this.color,
    required this.refreshMode,
  });

  final String url;
  final String? name;
  final String? color;
  final WebCalRefreshMode refreshMode;
}

class _WebCalAddDialog extends StatefulWidget {
  const _WebCalAddDialog({this.initialUrl});

  final String? initialUrl;

  @override
  State<_WebCalAddDialog> createState() => _WebCalAddDialogState();
}

class _WebCalAddDialogState extends State<_WebCalAddDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _nameController;
  late final TextEditingController _colorController;
  var _refreshMode = WebCalRefreshMode.automatic;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl)
      ..addListener(_changed);
    _nameController = TextEditingController();
    _colorController = TextEditingController()..addListener(_changed);
  }

  @override
  void dispose() {
    _urlController
      ..removeListener(_changed)
      ..dispose();
    _nameController.dispose();
    _colorController
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  NormalizedWebCalUri? get _normalized {
    try {
      return normalizeWebCalUri(_urlController.text);
    } on FormatException {
      return null;
    }
  }

  bool get _colorValid {
    final value = _colorController.text.trim();
    return value.isEmpty || RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final normalized = _normalized;
    return BusyMaxDialogShell(
      title: l10n.addCalendarSubscription,
      maxWidth: BusyMaxSizes.compactDetailsWidth,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        BusyMaxPushButton.suggested(
          key: const ValueKey('confirm-add-subscription'),
          onPressed: normalized == null || !_colorValid
              ? null
              : () => Navigator.of(context).pop(
                  _WebCalAddInput(
                    url: _urlController.text,
                    name: _nameController.text.trim().isEmpty
                        ? null
                        : _nameController.text.trim(),
                    color: _colorController.text.trim().isEmpty
                        ? null
                        : _colorController.text.trim(),
                    refreshMode: _refreshMode,
                  ),
                ),
          child: Text(l10n.addSubscriptionAction),
        ),
      ],
      children: [
        BusyMaxGroupedList(
          filled: true,
          children: [
            YaruListTile.square(
              title: TextField(
                key: const ValueKey('subscription-url'),
                controller: _urlController,
                autofocus: true,
                decoration: busyMaxGroupedTextFieldDecoration(
                  context,
                  labelText: l10n.subscriptionUrl,
                  errorText:
                      _urlController.text.trim().isNotEmpty &&
                          normalized == null
                      ? l10n.subscriptionUrlInvalid
                      : null,
                ).copyWith(helperText: l10n.subscriptionUrlHelp),
              ),
            ),
            YaruListTile.square(
              title: TextField(
                controller: _nameController,
                decoration: busyMaxGroupedTextFieldDecoration(
                  context,
                  labelText: l10n.subscriptionName,
                ),
              ),
            ),
            YaruListTile.square(
              title: TextField(
                controller: _colorController,
                decoration: busyMaxGroupedTextFieldDecoration(
                  context,
                  labelText: l10n.subscriptionColor,
                  errorText: _colorValid ? null : l10n.subscriptionColorInvalid,
                ).copyWith(helperText: l10n.subscriptionColorHelp),
              ),
            ),
            BusyMaxComboRow<WebCalRefreshMode>(
              title: l10n.subscriptionRefreshMode,
              values: WebCalRefreshMode.values,
              selected: _refreshMode,
              labelFor: (mode) => _refreshModeLabel(context, mode),
              onSelected: (value) => setState(() => _refreshMode = value),
            ),
          ],
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        Text(
          normalized == null
              ? l10n.subscriptionSafeOriginUnavailable
              : l10n.subscriptionSafeOrigin(normalized.safeOrigin.toString()),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

String _refreshModeLabel(BuildContext context, WebCalRefreshMode mode) =>
    switch (mode) {
      WebCalRefreshMode.automatic => context.l10n.subscriptionAutomatic,
      WebCalRefreshMode.hourly => context.l10n.subscriptionHourly,
      WebCalRefreshMode.sixHours => context.l10n.subscriptionSixHours,
      WebCalRefreshMode.daily => context.l10n.subscriptionDaily,
    };

Future<void> showAddCalendarSubscriptionFlow(
  BuildContext context,
  WidgetRef ref, {
  String? initialUrl,
}) async {
  final input = await showBusyMaxModalDialog<_WebCalAddInput>(
    context,
    barrierDismissible: false,
    builder: (dialogContext) => _WebCalAddDialog(initialUrl: initialUrl),
  );
  if (input == null || !context.mounted) return;
  try {
    await ref
        .read(webCalSubscriptionServiceProvider)
        .addSubscription(
          subscriptionUrl: input.url,
          localName: input.name,
          color: input.color,
          refreshMode: input.refreshMode,
        );
  } on Object catch (error) {
    if (!context.mounted) return;
    final code = switch (error) {
      WebCalSubscriptionException(:final code) => code,
      WebCalUriException(:final code) => code,
      _ => 'WebCalOperationFailed',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.subscriptionOperationFailed(code))),
    );
  }
}

class _AccountManagementCard extends ConsumerWidget {
  const _AccountManagementCard({
    required this.account,
    required this.removing,
    required this.refreshing,
    required this.onReconnect,
    required this.onRefreshCollections,
    required this.registrationRecovery,
    required this.onReplaceRegistration,
  });
  final AccountEntity account;
  final bool removing, refreshing, registrationRecovery;
  final VoidCallback? onReconnect, onRefreshCollections;
  final VoidCallback onReplaceRegistration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final primary = registrationRecovery
        ? AccountSettingsFeedback(
            AccountSettingsFailure.registration,
            l10n.accountRegistrationStatus,
            AccountSettingsRecovery.replaceRegistration,
          )
        : _primaryAccountFeedback(context, ref, account);
    final activity = ref.watch(accountSyncActivityProvider);
    VoidCallback? recovery(AccountSettingsRecovery action, {String? domain}) =>
        switch (action) {
          AccountSettingsRecovery.reconnect => onReconnect,
          AccountSettingsRecovery.replaceRegistration => onReplaceRegistration,
          AccountSettingsRecovery.revalidate =>
            account.provider == BusyProvider.nextcloud
                ? onRefreshCollections
                : onReconnect,
          AccountSettingsRecovery.retry =>
            domain == null
                ? onRefreshCollections
                : () async {
                    try {
                      final operations = ref.read(
                        accountSyncOperationsProvider,
                      );
                      if (domain == 'calendar') {
                        await operations.syncCalendar(account.id, full: false);
                      } else {
                        await operations.syncTasks(account.id, full: false);
                      }
                    } on Object catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AccountSettingsFeedback.fromError(
                                context.l10n,
                                error,
                              ).message,
                            ),
                          ),
                        );
                      }
                    }
                  },
        };
    String recoveryLabel(AccountSettingsRecovery action) => switch (action) {
      AccountSettingsRecovery.reconnect => l10n.reconnectAccount,
      AccountSettingsRecovery.replaceRegistration => l10n.registrationReplace,
      AccountSettingsRecovery.revalidate =>
        account.provider == BusyProvider.nextcloud
            ? l10n.revalidateAccount
            : l10n.reconnectAccount,
      AccountSettingsRecovery.retry => l10n.retry,
    };
    Widget failureRow(AccountSettingsFeedback feedback, {String? domain}) =>
        BusyMaxActionRow(
          key: ValueKey(
            domain == null
                ? 'account-primary-feedback-${account.id}'
                : 'account-domain-feedback-$domain-${account.id}',
          ),
          title: domain == null
              ? feedback.message
              : domain == 'calendar'
              ? l10n.calendar
              : l10n.tasks,
          titleWidget: domain == null ? Text(feedback.message) : null,
          subtitle: domain == null ? null : feedback.message,
          subtitleWidget: domain == null ? null : Text(feedback.message),
          leading: const Icon(YaruIcons.warning),
          trailing: BusyMaxPushButton.standard(
            key: ValueKey(
              registrationRecovery && domain == null
                  ? 'replace-registration-recovery-${account.id}'
                  : domain == null
                  ? 'account-recovery-${account.id}'
                  : 'account-domain-recovery-$domain-${account.id}',
            ),
            onPressed:
                removing ||
                    refreshing ||
                    domain != null && activity.isRunning(account.id, domain)
                ? null
                : recovery(feedback.recovery, domain: domain),
            child: Text(
              refreshing ? l10n.traySyncing : recoveryLabel(feedback.recovery),
            ),
          ),
        );
    return BusyMaxGroupedList(
      filled: true,
      children: [
        if (primary != null)
          failureRow(primary)
        else ...[
          BusyMaxActionRow(
            title: refreshing ? l10n.traySyncing : l10n.refreshNow,
            leading: const Icon(YaruIcons.sync),
            onTap: removing || refreshing ? null : onRefreshCollections,
          ),
          if (account.provider == BusyProvider.google ||
              account.provider == BusyProvider.microsoft)
            for (final domain in [
              if (account.calendarsEnabled) 'calendar',
              if (account.isTaskCapable) 'tasks',
            ])
              if (activity.failure(account.id, domain) case final error?)
                failureRow(
                  AccountSettingsFeedback.fromError(l10n, error),
                  domain: domain,
                ),
        ],
      ],
    );
  }
}

String _collectionEmptyMessage(
  BuildContext context,
  WidgetRef ref, {
  required AccountEntity account,
  required bool loading,
  required bool failed,
}) {
  final activity = ref.watch(accountSyncActivityProvider);
  final dav =
      account.provider == BusyProvider.nextcloud ||
      account.provider == BusyProvider.appleICloud;
  if (failed) return context.l10n.collectionsLoadFailed;
  if (loading || activity.isRunning(account.id, dav ? 'dav' : 'calendar')) {
    return context.l10n.collectionsLoading;
  }
  if (account.hasConnectionIssue) {
    return _accountConnectionIssueMessage(context, account);
  }
  final error = activity.failure(account.id, dav ? 'dav' : 'calendar');
  if (error != null) {
    return AccountSettingsFeedback.fromError(context.l10n, error).message;
  }
  final discovery = dav
      ? ref.watch(davAccountDiscoveryProvider(account.id))
      : null;
  if (discovery?.hasError == true ||
      discovery?.valueOrNull?.lastDiscoveryErrorCode != null) {
    return context.l10n.collectionsLoadFailed;
  }
  if (discovery?.isLoading == true) return context.l10n.collectionsLoading;
  final discovered = dav
      ? discovery?.valueOrNull != null
      : ref
                .watch(accountDomainSyncTimesProvider(account.id))
                .valueOrNull?['calendar'] !=
            null;
  return !discovered
      ? context.l10n.collectionsNotDiscovered
      : context.l10n.collectionsEmpty;
}

class _DavCollectionsCard extends ConsumerWidget {
  const _DavCollectionsCard({
    required this.account,
    required this.collections,
    required this.onEventsSelected,
    required this.onTasksSelected,
  });
  final AccountEntity account;
  final List<DavCollectionSettingsEntity> collections;
  final void Function(DavCollectionSettingsEntity, bool) onEventsSelected,
      onTasksSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(davCollectionsStreamProvider);
    final feedback = _primaryAccountFeedback(context, ref, account);
    return BusyMaxGroupedList(
      title: context.l10n.collectionSettings,
      titleStyle: _settingsAccountSubsectionStyle(context),
      filled: true,
      children: [
        if (collections.isEmpty)
          BusyMaxActionRow(
            title: feedback != null
                ? context.l10n.collectionsUnavailable
                : _collectionEmptyMessage(
                    context,
                    ref,
                    account: account,
                    loading: state.isLoading,
                    failed: state.hasError,
                  ),
            leading: const Icon(YaruIcons.calendar),
          ),
        if (collections.isNotEmpty && state.hasError)
          BusyMaxActionRow(title: context.l10n.collectionsLoadFailed),
        if (collections.isNotEmpty && state.isLoading)
          BusyMaxActionRow(title: context.l10n.collectionsLoading),
        for (final collection in collections)
          _DavCollectionItem(
            key: ValueKey('dav-collection-${collection.id}'),
            collection: collection,
            sharedFailure: feedback,
            onEventsSelected: onEventsSelected,
            onTasksSelected: onTasksSelected,
          ),
      ],
    );
  }
}

class _DavCollectionItem extends StatefulWidget {
  const _DavCollectionItem({
    super.key,
    required this.collection,
    required this.onEventsSelected,
    required this.onTasksSelected,
    this.sharedFailure,
  });
  final DavCollectionSettingsEntity collection;
  final AccountSettingsFeedback? sharedFailure;
  final void Function(DavCollectionSettingsEntity, bool) onEventsSelected,
      onTasksSelected;
  @override
  State<_DavCollectionItem> createState() => _DavCollectionItemState();
}

class _DavCollectionItemState extends State<_DavCollectionItem> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final l10n = context.l10n;
    final error = collection.syncErrorCode == null
        ? null
        : AccountSettingsFeedback.fromDavCode(l10n, collection.syncErrorCode!);
    final subtitle = [
      _davCollectionDetails(context, collection),
      if (error != null && error.kind != widget.sharedFailure?.kind)
        error.message,
    ].join(' · ');
    final settings = collection.provider != BusyProvider.nextcloud
        ? null
        : YaruIconButton(
            key: ValueKey('dav-collection-settings-${collection.id}'),
            tooltip: '${l10n.nextcloudCollectionSettings} · ${collection.name}',
            icon: const Icon(YaruIcons.settings),
            onPressed: () => showLinuxNextcloudCollectionDialog(
              context,
              accountId: collection.accountId,
              collectionId: collection.id,
            ),
          );
    if (!(collection.supportsEvents && collection.supportsTasks)) {
      return Row(
        children: [
          Expanded(
            child: BusyMaxSwitchRow(
              key: ValueKey(
                '${collection.supportsEvents ? 'dav-events-toggle' : 'dav-tasks-toggle'}-${collection.id}',
              ),
              title: collection.name,
              subtitle: subtitle,
              leading: _DavCollectionIndicator(color: collection.color),
              value: collection.supportsEvents
                  ? collection.eventsSelected
                  : collection.tasksSelected,
              onChanged: (selected) => collection.supportsEvents
                  ? widget.onEventsSelected(collection, selected)
                  : widget.onTasksSelected(collection, selected),
            ),
          ),
          if (settings != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: BusyMaxSpacing.md),
              child: settings,
            ),
        ],
      );
    }
    return Semantics(
      expanded: _expanded,
      child: YaruExpandable(
        key: ValueKey('dav-collection-expander-${collection.id}'),
        isExpanded: _expanded,
        onChange: (expanded) => setState(() => _expanded = expanded),
        expandIconSemanticLabel: collection.name,
        header: BusyMaxActionRow(
          title: collection.name,
          titleWidget: Text(collection.name),
          subtitle: subtitle,
          subtitleWidget: Text(subtitle),
          leading: _DavCollectionIndicator(color: collection.color),
          trailing: settings,
        ),
        child: Column(
          children: [
            BusyMaxSwitchRow(
              key: ValueKey('dav-events-toggle-${collection.id}'),
              title: l10n.calendarContent,
              value: collection.eventsSelected,
              onChanged: (selected) =>
                  widget.onEventsSelected(collection, selected),
              leading: const Icon(YaruIcons.calendar),
            ),
            BusyMaxSwitchRow(
              key: ValueKey('dav-tasks-toggle-${collection.id}'),
              title: l10n.taskContent,
              value: collection.tasksSelected,
              onChanged: (selected) =>
                  widget.onTasksSelected(collection, selected),
              leading: const Icon(YaruIcons.checkmark),
            ),
          ],
        ),
      ),
    );
  }
}

class _DavCollectionIndicator extends StatelessWidget {
  const _DavCollectionIndicator({required this.color});

  final String? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: BusyMaxSizes.iconSm,
        height: BusyMaxSizes.iconSm,
        decoration: BoxDecoration(
          color: _parseDavColor(color) ?? Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _DavConflictsCard extends StatelessWidget {
  const _DavConflictsCard({required this.conflicts, required this.onResolve});

  final List<DavConflictEntity> conflicts;
  final void Function(
    DavConflictEntity conflict,
    DavConflictResolution resolution,
  )
  onResolve;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BusyMaxGroupedList(
      title: l10n.syncConflicts,
      titleStyle: _settingsAccountSubsectionStyle(context),
      filled: true,
      children: [
        for (final conflict in conflicts) ...[
          BusyMaxActionRow(
            key: ValueKey('dav-conflict-${conflict.id}'),
            title: conflict.itemTitle,
            subtitle: [
              '${conflict.collectionName} · ${conflict.accountLabel}',
              if (conflict.remoteChangedAtUtc != null)
                l10n.remoteChangedAt(
                  _formatDavDateTime(context, conflict.remoteChangedAtUtc!),
                ),
              l10n.localPendingEdit(conflict.localEditSummary),
            ].join('\n'),
            leading: Icon(
              YaruIcons.warning,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          if (conflict.canKeepServer)
            BusyMaxActionRow(
              title: l10n.keepServerVersion,
              leading: const Icon(YaruIcons.download),
              onTap: () =>
                  onResolve(conflict, DavConflictResolution.keepServer),
            ),
          if (conflict.canReapplyLocal)
            BusyMaxActionRow(
              title: l10n.reapplyLocalChange,
              leading: const Icon(YaruIcons.sync),
              onTap: () =>
                  onResolve(conflict, DavConflictResolution.reapplyLocal),
            ),
          if (conflict.canDuplicate)
            BusyMaxActionRow(
              title: l10n.duplicateLocalItem,
              leading: const Icon(YaruIcons.copy),
              onTap: () =>
                  onResolve(conflict, DavConflictResolution.duplicateLocal),
            ),
        ],
      ],
    );
  }
}

Future<void> _afterAccountRemoved(
  BuildContext context,
  WidgetRef ref,
  String removedAccountId,
) async {
  final accounts = await ref
      .read(accountsRepositoryProvider)
      .listVisibleAccounts();
  final remaining = accounts
      .where((account) => account.id != removedAccountId)
      .toList();

  if (remaining.isEmpty) {
    ref.read(selectedAccountIdProvider.notifier).state = null;
    await ref.read(authSessionControllerProvider.notifier).load();
    return;
  }

  final selected = ref.read(selectedAccountIdProvider);
  if (selected == removedAccountId || !remaining.any((a) => a.id == selected)) {
    ref.read(selectedAccountIdProvider.notifier).state = remaining.first.id;
  }
  await ref.read(authSessionControllerProvider.notifier).load();
}

List<AccountEntity> _selectedAccountFirst(
  List<AccountEntity> accounts,
  String? selectedAccountId,
) {
  return [
    ...accounts.where((account) => account.id == selectedAccountId),
    ...accounts.where((account) => account.id != selectedAccountId),
  ];
}

String _accountConnectionErrorMessage(BuildContext context, Object error) {
  if (error is DavException && error.code == 'DavAccountAlreadyConnected') {
    return context.l10n.accountAlreadyConnected;
  }
  if (error is DavException) {
    return AccountSettingsFeedback.fromError(context.l10n, error).message;
  }
  if (error is NetworkUnavailableException) {
    return context.l10n.networkOfflineTryAgain;
  }
  if (error is OAuthException && error.code == 'OAuthMissingRequiredScope') {
    return context.l10n.googlePermissionsRequiredRetry;
  }
  return localizedAuthorizationError(context.l10n, error);
}

String _themeModeLabel(
  BuildContext context,
  BusyMaxThemeModePreference preference,
) {
  final l10n = context.l10n;
  return switch (preference) {
    BusyMaxThemeModePreference.system => l10n.themeSystem,
    BusyMaxThemeModePreference.light => l10n.themeLight,
    BusyMaxThemeModePreference.dark => l10n.themeDark,
  };
}

String _notificationDetailLabel(
  BuildContext context,
  NotificationDetailLevel level,
) {
  final l10n = context.l10n;
  return switch (level) {
    NotificationDetailLevel.private => l10n.notificationDetailPrivate,
    NotificationDetailLevel.normal => l10n.notificationDetailNormal,
  };
}

String _accountIdentityLabel(BuildContext context, AccountEntity account) {
  final name = account.displayName?.trim();
  final address = account.email?.trim();
  if (account.provider == BusyProvider.nextcloud) {
    return [
      if (name != null && name.isNotEmpty && name != account.providerAccountId)
        name,
      account.providerAccountId,
      account.authority,
    ].join(' · ');
  }
  if (name != null && name.isNotEmpty) {
    if (address != null && address.isNotEmpty && address != name) {
      return '$name · $address';
    }
    return name;
  }
  if (address != null && address.isNotEmpty) {
    return address;
  }
  return context.l10n.signedInAccount;
}

String _accountProviderLabel(BuildContext context, BusyProvider provider) {
  return switch (provider) {
    BusyProvider.google => context.l10n.googleProvider,
    BusyProvider.microsoft => context.l10n.microsoftProvider,
    BusyProvider.appleICloud => context.l10n.appleICloudProvider,
    BusyProvider.nextcloud => context.l10n.nextcloudProvider,
    BusyProvider.webCal => 'WebCal',
  };
}

String _accountConnectionIssueMessage(
  BuildContext context,
  AccountEntity account,
) => switch (account.connectionState) {
  AccountConnectionState.reauthenticationRequired =>
    account.provider == BusyProvider.google
        ? context.l10n.googleReconnectRequired
        : context.l10n.accountReconnectRequired,
  AccountConnectionState.temporarilyUnavailable =>
    context.l10n.davTemporarilyUnavailable,
  AccountConnectionState.permissionChanged => context.l10n.davPermissionChanged,
  AccountConnectionState.unsupportedServerProfile =>
    context.l10n.davUnsupportedServer,
  AccountConnectionState.connected ||
  AccountConnectionState.connecting ||
  AccountConnectionState.signedOut => '',
};

String _accountConnectionStateLabel(
  BuildContext context,
  AccountEntity account,
) => switch (account.connectionState) {
  AccountConnectionState.connected => context.l10n.davConnected,
  AccountConnectionState.connecting => context.l10n.davConnecting,
  AccountConnectionState.reauthenticationRequired =>
    context.l10n.davReauthenticationRequired,
  AccountConnectionState.temporarilyUnavailable =>
    context.l10n.davTemporarilyUnavailable,
  AccountConnectionState.permissionChanged => context.l10n.davPermissionChanged,
  AccountConnectionState.unsupportedServerProfile =>
    context.l10n.davUnsupportedServer,
  AccountConnectionState.signedOut => context.l10n.davSignedOut,
};

String _davCollectionDetails(
  BuildContext context,
  DavCollectionSettingsEntity collection,
) {
  final l10n = context.l10n;
  final support = switch ((
    collection.supportsEvents,
    collection.supportsTasks,
  )) {
    (true, true) => l10n.collectionSupportsEventsAndTasks,
    (true, false) => l10n.collectionSupportsEvents,
    (false, true) => l10n.collectionSupportsTasks,
    _ => l10n.collectionSettings,
  };
  final details = <String>[support];
  if (collection.readOnly) {
    details.add(l10n.readOnlySharedCollection);
  }
  if (collection.shared) {
    details.add(l10n.sharedCollection);
  }
  return details.join(' · ');
}

String _formatDavDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return formatClockDateTime(context, local, material.formatMediumDate(local));
}

Color? _parseDavColor(String? source) {
  final value = source?.trim().replaceFirst('#', '');
  if (value == null) return null;
  final normalized = switch (value.length) {
    6 => 'FF$value',
    // CalDAV calendar-color uses RRGGBBAA, while Flutter expects AARRGGBB.
    8 => '${value.substring(6, 8)}${value.substring(0, 6)}',
    _ => null,
  };
  if (normalized == null) return null;
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? null : Color(parsed);
}

class _RegistrationAccountCard extends ConsumerWidget {
  const _RegistrationAccountCard({
    required this.account,
    required this.onMigrate,
    required this.onReconnect,
    this.additionalRows = const [],
  });
  final AccountEntity account;
  final VoidCallback onMigrate;
  final VoidCallback? onReconnect;
  final List<Widget> additionalRows;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(registrationSummariesProvider);
    final summary = summaries.valueOrNull?[account.id];
    final l10n = context.l10n;
    return YaruExpandable(
      key: ValueKey('account-advanced-${account.id}'),
      header: Text(
        l10n.advancedSection,
        style: _settingsSectionHeaderStyle(context),
      ),
      expandIconSemanticLabel: l10n.advancedSection,
      child: BusyMaxGroupedList(
        filled: true,
        children: [
          BusyMaxActionRow(
            key: ValueKey('reconnect-account-${account.id}'),
            title: l10n.reconnectAccount,
            leading: const Icon(YaruIcons.refresh),
            onTap: onReconnect,
          ),
          BusyMaxActionRow(
            title: summaries.isLoading
                ? l10n.accountLoadingSignInSettings
                : summaries.hasError
                ? l10n.oauthSecureStorageUnavailable
                : summary == null
                ? l10n.registrationUnresolved
                : l10n.registrationDescription(summary),
            subtitle: summary?.showRetirementNotice == true
                ? l10n.registrationRetirementNotice(
                    account.provider.displayName,
                    account.provider == BusyProvider.google
                        ? l10n.registrationGoogleProject
                        : l10n.registrationMicrosoftApp,
                  )
                : null,
          ),
          BusyMaxActionRow(
            title: summary?.showRetirementNotice == true
                ? l10n.registrationMigrate
                : l10n.registrationReplace,
            onTap: onMigrate,
          ),
          ...additionalRows,
        ],
      ),
    );
  }
}
