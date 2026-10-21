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
  });

  final String? reconnectAccountId;

  final SettingsPage initialPage;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late var _page = widget.initialPage;
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
    final account = await ref.read(accountsRepositoryProvider).accountById(id);
    if (mounted && account != null) {
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
    if (oldWidget.initialPage != widget.initialPage) {
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
    final title = _settingsPageLabel(context, _page);
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
                value: settings.notifyDueToday,
                onChanged: settingsController.setNotifyDueToday,
                leading: const Icon(YaruIcons.calendar_day),
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
          DiagnosticsPanel(
            scrollable: false,
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
    final controller = ref.read(busyMaxContactsControllerProvider);
    final parentId = await controller.store.linkedBusyMaxAccount(contact.id);
    if (!mounted) return;
    if (parentId != null && contact.provider == ContactProviderKind.carddav) {
      final parent = await ref
          .read(accountsRepositoryProvider)
          .accountById(parentId);
      if (!mounted || parent == null) return;
      if (await _connectAccount(parent.provider, reconnecting: parent) &&
          mounted) {
        await _enableContacts(parent);
      }
      return;
    }
    String? password;
    if (parentId == null &&
        !await controller.isIndependentNextcloud(contact.id)) {
      if (!mounted) return;
      password = await showBusyMaxTextPrompt(
        context,
        title: context.l10n.reconnectAccount,
        label: context.l10n.contactsPasswordLabel,
        actionLabel: context.l10n.reconnectAccount,
        obscureText: true,
      );
      if (!mounted || password == null) return;
    }
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
    _contactOperationsController = ref.read(busyMaxContactsControllerProvider);
    setState(() => _busyContactAccountIds.add(id));
    try {
      await operation();
    } on Object catch (error) {
      _settingsLogger.warning(
        'Contacts configuration failed: ${redactForLog(error)}',
      );
      if (mounted) {
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
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/schedule');
  }

  void _selectPage(SettingsPage page) {
    if (_page != page) {
      if (page == SettingsPage.system) {
        ref.invalidate(launchAtLoginStateProvider);
      }
      setState(() => _page = page);
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
            identical(_authorizationCancellation, ownedCancellation)) {
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
      if (mounted) {
        _showMessage(
          context,
          context.l10n.syncFailed(
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
        if (result?.authorizationRevocationFailed ?? false) {
          _showMessage(context, context.l10n.accountRemovedGoogleRevokeFailed);
        } else if (davResult?.remoteRevocationAttempted == true &&
            !davResult!.remoteRevocationSucceeded) {
          _showMessage(
            context,
            context.l10n.nextcloudAccountRemovedRevokeFailed,
          );
        }
        await _afterAccountRemoved(context, ref, account.id);
      }
    } on Object catch (error) {
      _settingsLogger.warning('Account removal failed: $error');
      if (context.mounted) {
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

  Future<void> _refreshCollections(AccountEntity account) async {
    if (_refreshingAccountIds.contains(account.id)) return;
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
      if (mounted) _showMessage(context, context.l10n.syncComplete);
    } on Object catch (error) {
      if (mounted) {
        _showMessage(
          context,
          context.l10n.syncFailed(
            localizedSyncFailureMessage(
              context.l10n,
              error,
              networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
            ),
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
          _showMessage(context, context.l10n.calendarUpdateFailed('$error'));
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
    required this.onBack,
    required this.onMenuSelected,
  });

  final String title;
  final VoidCallback onBack;
  final ValueChanged<ScheduleToolbarMenuAction> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return BusyMaxLinuxHeaderLayout(
      leading: BusyMaxLinuxHeaderControlGroup(
        children: [
          BusyMaxLinuxHeaderIconButton(
            key: const ValueKey('settings-header-back-button'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final connecting = connectingProvider != null;
    return _SettingsPageLayout(
      children: [
        BusyMaxGroupedList(
          title: l10n.addAccount,
          filled: true,
          children: [
            BusyMaxActionRow(
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
              subtitle: microsoftConfigured ? null : l10n.providerNotConfigured,
              leading: const Icon(YaruIcons.plus),
              onTap: connecting || !microsoftConfigured ? null : onAddMicrosoft,
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
          Padding(
            padding: const EdgeInsets.only(top: BusyMaxSpacing.lg),
            child: Text(
              l10n.connectedAccounts,
              style: _settingsSectionHeaderStyle(context),
            ),
          ),
        for (final account in accounts)
          _AccountSettingsGroup(
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
                  onMigrate: () => onMigrate(account),
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
        _ContactsOnlySettingsCard(
          accounts: [
            for (final account in contactAccounts)
              if (ref
                      .watch(independentContactAccountIdsProvider)
                      .valueOrNull
                      ?.contains(account.id) ==
                  true)
                account,
          ],
          sources: contactSources,
          busyAccountIds: busyContactAccountIds,
          onAddCardDav: onAddCardDavContacts,
          onAddNextcloud: onAddNextcloudContacts,
          onRemove: onRemoveContactsOnly,
          onRetry: onRetryContacts,
          onReconnect: onReconnectContacts,
          onSourceEnabled: onSourceEnabled,
        ),
        _CalendarImportCard(onImport: onImportIcs),
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

class _IndependentContactIdentity extends ConsumerWidget {
  const _IndependentContactIdentity({required this.account});
  final ContactAccount account;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(independentContactServerProvider(account.id));
    return server.when(
      data: (uri) => uri == null
          ? const SizedBox.shrink()
          : BusyMaxActionRow(
              title: uri.toString(),
              leading: const Icon(Icons.cloud_outlined),
            ),
      loading: () => BusyMaxActionRow(title: context.l10n.accountsLoading),
      error: (_, _) =>
          BusyMaxActionRow(title: context.l10n.oauthSecureStorageUnavailable),
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
      final error = activity.failure(account.id, dav ? 'dav' : domain);
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
          ? localizedSyncFailureMessage(l10n, error)
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

    return BusyMaxGroupedList(
      filled: true,
      children: [
        if (account.calendarsEnabled) domain('calendar', l10n.calendar),
        if (account.isTaskCapable) domain('tasks', l10n.tasks),
      ],
    );
  }
}

class _AccountSettingsGroup extends StatelessWidget {
  const _AccountSettingsGroup({
    required this.account,
    required this.actions,
    required this.subsections,
  });

  final AccountEntity account;
  final Widget actions;
  final List<Widget> subsections;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BusyMaxSpacing.lg),
      child: BusyMaxSurface(
        filled: false,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        child: Padding(
          padding: const EdgeInsets.all(BusyMaxSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BusyMaxSpacing.xs,
                ),
                child: Column(
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
                    Text(
                      _accountIdentityLabel(context, account),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              actions,
              if (subsections.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: subsections,
                ),
            ],
          ),
        ),
      ),
    );
  }
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
  });

  final AccountEntity account;
  final ContactAccount? contactAccount;
  final List<BusyMaxContactSourceSetting> sources;
  final bool busy;
  final VoidCallback onEnableRead;
  final VoidCallback onDisable;
  final Future<void> Function(String sourceKey, bool enabled) onSourceEnabled;
  final void Function(ContactAccount) onRetry, onReconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = contactAccount;
    final l10n = context.l10n;
    final contactState = ref.watch(busyMaxContactAccountsProvider);
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
    return BusyMaxGroupedList(
      title: l10n.contactsTitle,
      titleStyle: _settingsAccountSubsectionStyle(context),
      description: account.provider == BusyProvider.nextcloud
          ? l10n.contactsNextcloudReuse
          : l10n.contactsLinkedDescription,
      filled: true,
      children: contact == null
          ? [
              BusyMaxActionRow(
                key: ValueKey('enable-contacts-read-${account.id}'),
                title: l10n.contactsEnableSuggestions,
                subtitle: account.provider == BusyProvider.nextcloud
                    ? l10n.contactsReadOnlyUse
                    : l10n.contactsReadPermissionDescription,
                leading: const Icon(YaruIcons.user),
                onTap: busy ? null : onEnableRead,
              ),
            ]
          : [
              if (busy)
                BusyMaxActionRow(
                  title: l10n.traySyncing,
                  leading: const YaruCircularProgressIndicator(),
                ),
              BusyMaxActionRow(
                title: !contact.enabled
                    ? l10n.contactsSuggestionsDisabled
                    : contact.errorCode == null
                    ? l10n.contactsSuggestionsEnabled
                    : localizedContactsStatus(l10n, contact.errorCode!),
                subtitle: l10n.contactsReadOnlyUse,
                leading: Icon(
                  contact.errorCode == null
                      ? YaruIcons.checkmark
                      : YaruIcons.warning,
                ),
              ),
              BusyMaxActionRow(
                key: ValueKey('reconnect-contacts-${account.id}'),
                title: !contact.enabled
                    ? l10n.contactsEnableSuggestions
                    : l10n.reconnectAccount,
                leading: const Icon(YaruIcons.sync),
                onTap: busy
                    ? null
                    : !contact.enabled
                    ? onEnableRead
                    : () => onReconnect(contact),
              ),
              BusyMaxActionRow(
                title: l10n.contactsRetrySync,
                leading: const Icon(YaruIcons.sync),
                onTap: busy || !contact.enabled ? null : () => onRetry(contact),
              ),
              for (final setting in sources)
                _ContactSourceSettingsRow(
                  setting: setting,
                  onChanged: (enabled) =>
                      onSourceEnabled(setting.source.key, enabled),
                ),
              if (contact.enabled)
                BusyMaxActionRow(
                  key: ValueKey('disable-contacts-${account.id}'),
                  title: l10n.contactsDisableForAccount,
                  leading: Icon(
                    YaruIcons.trash,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  destructive: true,
                  onTap: busy ? null : onDisable,
                ),
            ],
    );
  }
}

class _ContactsOnlySettingsCard extends ConsumerWidget {
  const _ContactsOnlySettingsCard({
    required this.accounts,
    required this.sources,
    required this.busyAccountIds,
    required this.onAddCardDav,
    required this.onAddNextcloud,
    required this.onRemove,
    required this.onSourceEnabled,
    required this.onRetry,
    required this.onReconnect,
  });

  final List<ContactAccount> accounts;
  final List<BusyMaxContactSourceSetting> sources;
  final Set<String> busyAccountIds;
  final VoidCallback onAddCardDav;
  final VoidCallback onAddNextcloud;
  final void Function(ContactAccount account) onRemove;
  final Future<void> Function(String sourceKey, bool enabled) onSourceEnabled;
  final void Function(ContactAccount) onRetry, onReconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
        for (final account in accounts) ...[
          BusyMaxActionRow(
            title: account.displayName,
            subtitle: [
              account.subject,
              if (!account.enabled)
                l10n.contactsSuggestionsDisabled
              else if (account.errorCode != null)
                localizedContactsStatus(l10n, account.errorCode!)
              else
                l10n.contactsReadOnlyUse,
            ].where((s) => s.isNotEmpty).join(' · '),
            leading: const Icon(YaruIcons.user),
          ),
          _IndependentContactIdentity(account: account),
          BusyMaxActionRow(
            title: l10n.reconnectAccount,
            leading: const Icon(YaruIcons.refresh),
            onTap: busyAccountIds.contains(account.id)
                ? null
                : () => onReconnect(account),
          ),
          BusyMaxActionRow(
            title: l10n.contactsRetrySync,
            leading: const Icon(YaruIcons.sync),
            onTap: busyAccountIds.contains(account.id) || !account.enabled
                ? null
                : () => onRetry(account),
          ),
          for (final setting in sources)
            if (setting.source.accountId == account.id)
              _ContactSourceSettingsRow(
                setting: setting,
                onChanged: (enabled) =>
                    onSourceEnabled(setting.source.key, enabled),
              ),
          BusyMaxActionRow(
            key: ValueKey('remove-contacts-only-${account.id}'),
            title: l10n.removeAction,
            leading: Icon(
              YaruIcons.trash,
              color: Theme.of(context).colorScheme.error,
            ),
            destructive: true,
            onTap: busyAccountIds.contains(account.id)
                ? null
                : () => onRemove(account),
          ),
        ],
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
              _CalendarSettingsColumnHeader(
                showsProviderVisibility: showsProviderVisibility,
              ),
              for (final source in sources)
                _CalendarSettingsRow(
                  source: source,
                  showsProviderVisibility: showsProviderVisibility,
                  onSelected: onSelected,
                  onProviderVisibilityChanged: onProviderVisibilityChanged,
                ),
            ],
    );
  }
}

const _calendarSettingsColumnWidth = 132.0;

class _CalendarSettingsColumnHeader extends StatelessWidget {
  const _CalendarSettingsColumnHeader({required this.showsProviderVisibility});

  final bool showsProviderVisibility;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BusyMaxSpacing.md,
        BusyMaxSpacing.sm,
        BusyMaxSpacing.md,
        BusyMaxSpacing.xs,
      ),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          _CalendarSettingsColumnLabel(
            key: const ValueKey('settings-calendar-column-schedule'),
            label: l10n.showInBusyMax,
            style: style,
          ),
          if (showsProviderVisibility)
            _CalendarSettingsColumnLabel(
              key: const ValueKey('settings-calendar-column-provider'),
              label: l10n.showInGoogleCalendarList,
              style: style,
            ),
        ],
      ),
    );
  }
}

class _CalendarSettingsColumnLabel extends StatelessWidget {
  const _CalendarSettingsColumnLabel({
    super.key,
    required this.label,
    required this.style,
  });

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _calendarSettingsColumnWidth,
      child: Text(
        label,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

class _CalendarSettingsRow extends ConsumerWidget {
  const _CalendarSettingsRow({
    required this.source,
    required this.showsProviderVisibility,
    required this.onSelected,
    required this.onProviderVisibilityChanged,
  });

  final CalendarSourceEntity source;
  final bool showsProviderVisibility;
  final void Function(CalendarSourceEntity source, bool selected) onSelected;
  final void Function(CalendarSourceEntity source, bool visible)
  onProviderVisibilityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canChangeProviderVisibility =
        source.capabilities.canChangeProviderVisibility;
    final pending = source.provider == BusyProvider.google
        ? ref.watch(calendarVisibilityOperationProvider(source.id)).valueOrNull
        : null;
    final failedVisibility =
        pending != null &&
        (pending.lastErrorCode != null ||
            !const ['pending', 'in_progress'].contains(pending.state));
    var confirmedHidden = source.hidden;
    if (failedVisibility) {
      final request = jsonDecode(pending.requestJson) as Map;
      final previous = request[calendarPatchPreviousValuesKey];
      final baseline = jsonDecode(pending.baselineRawJson ?? '{}') as Map;
      confirmedHidden = previous is Map && previous['hidden'] is bool
          ? previous['hidden'] as bool
          : baseline['hidden'] == true;
    }
    final unavailable = source.accessRole == 'unavailable';
    final shared =
        MicrosoftSharedPrimaryCalendarAddress.parse(
              source.providerCalendarId,
            ) !=
            null ||
        source.dataOwner != null &&
            source.authenticatedAccountEmail != null &&
            source.dataOwner!.toLowerCase() !=
                source.authenticatedAccountEmail!.toLowerCase();
    return Semantics(
      container: true,
      label: source.summary,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          BusyMaxSpacing.md,
          BusyMaxSpacing.xs,
          BusyMaxSpacing.md,
          BusyMaxSpacing.xs,
        ),
        child: Row(
          children: [
            _DavCollectionIndicator(color: source.backgroundColor),
            const SizedBox(width: BusyMaxSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (shared)
                    Text(
                      l10n.sharedCollection,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (source.readOnly)
                    Text(
                      l10n.readOnlySharedCollection,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (unavailable)
                    Text(
                      l10n.sharedCalendarUnavailable,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (pending != null)
                    Text(
                      failedVisibility
                          ? l10n.calendarRemoteFailed
                          : l10n.calendarRemotePending,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (failedVisibility)
                    _CalendarVisibilityRecoveryActions(
                      key: ValueKey('visibility-recovery-${pending.id}'),
                      source: source,
                      operation: pending,
                    ),
                  if (source.provider == BusyProvider.google &&
                      source.primaryCalendar)
                    Text(
                      l10n.primaryCalendarVisibilityExplanation,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            _CalendarSettingsSwitchCell(
              message: '${l10n.showInBusyMax} · ${source.summary}',
              child: BusyMaxYaruFocusBorder(
                builder: (context, focusNode) => YaruSwitch(
                  key: ValueKey('settings-calendar-schedule-${source.id}'),
                  value: source.selected && !source.hidden,
                  focusNode: focusNode,
                  hasFocusBorder: false,
                  onChanged: source.hidden
                      ? null
                      : (selected) => onSelected(source, selected),
                ),
              ),
            ),
            if (showsProviderVisibility)
              _CalendarSettingsSwitchCell(
                message: '${l10n.showInGoogleCalendarList} · ${source.summary}',
                child: BusyMaxYaruFocusBorder(
                  builder: (context, focusNode) => YaruSwitch(
                    key: ValueKey('settings-calendar-provider-${source.id}'),
                    value: !confirmedHidden,
                    focusNode: focusNode,
                    hasFocusBorder: false,
                    onChanged: canChangeProviderVisibility && !failedVisibility
                        ? (visible) =>
                              onProviderVisibilityChanged(source, visible)
                        : null,
                  ),
                ),
              ),
            if (source.provider == BusyProvider.microsoft &&
                source.capabilities.removalMode ==
                    CalendarRemovalMode.removeFromList)
              YaruIconButton(
                key: ValueKey('settings-calendar-remove-${source.id}'),
                tooltip: l10n.removeFromMyCalendars,
                icon: const Icon(YaruIcons.trash),
                onPressed: () async {
                  final confirmed = await showBusyMaxConfirm(
                    context,
                    title: l10n.removeFromMyCalendars,
                    message: l10n.removeOpenedSharedCalendarConfirmation(
                      source.summary,
                    ),
                    confirmLabel: l10n.removeAction,
                  );
                  if (!confirmed || !context.mounted) return;
                  try {
                    await ref
                        .read(calendarRepositoryProvider)
                        .deleteLocalSource(source.id);
                  } on Object catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.calendarUpdateFailed('$error')),
                        ),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
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
          SnackBar(content: Text(localizedSyncFailureMessage(l10n, error))),
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

class _CalendarSettingsSwitchCell extends StatelessWidget {
  const _CalendarSettingsSwitchCell({
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _calendarSettingsColumnWidth,
      child: Center(
        child: Semantics(
          label: message,
          child: Tooltip(message: message, child: child),
        ),
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
          leading: const Icon(Icons.file_open_outlined),
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
                leading: const Icon(Icons.lock_outline),
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
                leading: const Icon(Icons.edit_outlined),
                onTap: busySubscriptionIds.contains(subscription.id)
                    ? null
                    : () => onRename(subscription),
              ),
              BusyMaxActionRow(
                title: l10n.calendarColor,
                leading: const Icon(Icons.palette_outlined),
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

class _AccountManagementCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final revalidate =
        account.provider == BusyProvider.nextcloud &&
        (account.connectionState == AccountConnectionState.permissionChanged ||
            account.connectionState ==
                AccountConnectionState.unsupportedServerProfile);
    return BusyMaxGroupedList(
      filled: true,
      children: [
        BusyMaxActionRow(
          title: l10n.davConnectionState,
          subtitle: _accountConnectionStateLabel(context, account),
          leading: Icon(
            account.hasConnectionIssue
                ? YaruIcons.warning
                : YaruIcons.checkmark,
          ),
        ),
        if (account.hasConnectionIssue)
          BusyMaxActionRow(
            title: _accountConnectionIssueMessage(context, account),
            titleWidget: Text(_accountConnectionIssueMessage(context, account)),
            leading: const Icon(YaruIcons.warning),
          ),
        if (registrationRecovery)
          BusyMaxActionRow(
            key: ValueKey('replace-registration-recovery-${account.id}'),
            title: l10n.registrationReplace,
            subtitle: l10n.registrationRecoveryDescription,
            subtitleWidget: Text(l10n.registrationRecoveryDescription),
            leading: const Icon(YaruIcons.warning),
            onTap: removing ? null : onReplaceRegistration,
          ),
        BusyMaxActionRow(
          key: ValueKey('reconnect-account-${account.id}'),
          title: l10n.reconnectAccount,
          leading: const Icon(YaruIcons.refresh),
          onTap: removing ? null : onReconnect,
        ),
        if (onRefreshCollections != null || refreshing)
          BusyMaxActionRow(
            title: refreshing
                ? l10n.traySyncing
                : revalidate
                ? l10n.revalidateAccount
                : account.provider == BusyProvider.nextcloud ||
                      account.provider == BusyProvider.appleICloud
                ? l10n.refreshCollections
                : l10n.refreshNow,
            leading: const Icon(YaruIcons.sync),
            onTap: removing ? null : onRefreshCollections,
          ),
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
  if (error != null) return localizedSyncFailureMessage(context.l10n, error);
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
    return BusyMaxGroupedList(
      title: context.l10n.collectionSettings,
      titleStyle: _settingsAccountSubsectionStyle(context),
      filled: true,
      children: [
        if (collections.isEmpty)
          BusyMaxActionRow(
            title: _collectionEmptyMessage(
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
        for (final collection in collections)
          _DavCollectionItem(
            key: ValueKey('dav-collection-${collection.id}'),
            collection: collection,
            onEventsSelected: onEventsSelected,
            onTasksSelected: onTasksSelected,
          ),
      ],
    );
  }
}

class _DavCollectionItem extends StatelessWidget {
  const _DavCollectionItem({
    super.key,
    required this.collection,
    required this.onEventsSelected,
    required this.onTasksSelected,
  });
  final DavCollectionSettingsEntity collection;
  final void Function(DavCollectionSettingsEntity, bool) onEventsSelected,
      onTasksSelected;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BusyMaxActionRow(
        title: collection.name,
        subtitle: _davCollectionDetails(context, collection),
        leading: _DavCollectionIndicator(color: collection.color),
        trailing: collection.provider != BusyProvider.nextcloud
            ? null
            : YaruIconButton(
                key: ValueKey('dav-collection-settings-${collection.id}'),
                tooltip:
                    '${context.l10n.nextcloudCollectionSettings} · ${collection.name}',
                icon: Icon(
                  Icons.settings_outlined,
                  semanticLabel:
                      '${context.l10n.nextcloudCollectionSettings} · ${collection.name}',
                ),
                onPressed: () => showLinuxNextcloudCollectionDialog(
                  context,
                  accountId: collection.accountId,
                  collectionId: collection.id,
                ),
              ),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.only(start: BusyMaxSpacing.xxl),
        child: Column(
          children: [
            if (collection.supportsEvents)
              BusyMaxSwitchRow(
                key: ValueKey('dav-events-toggle-${collection.id}'),
                title: context.l10n.calendarContent,
                value: collection.eventsSelected,
                onChanged: (selected) => onEventsSelected(collection, selected),
                leading: const Icon(YaruIcons.calendar),
              ),
            if (collection.supportsTasks)
              BusyMaxSwitchRow(
                key: ValueKey('dav-tasks-toggle-${collection.id}'),
                title: context.l10n.taskContent,
                value: collection.tasksSelected,
                onChanged: (selected) => onTasksSelected(collection, selected),
                leading: const Icon(YaruIcons.checkmark),
              ),
          ],
        ),
      ),
    ],
  );
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
              leading: const Icon(Icons.cloud_download_outlined),
              onTap: () =>
                  onResolve(conflict, DavConflictResolution.keepServer),
            ),
          if (conflict.canReapplyLocal)
            BusyMaxActionRow(
              title: l10n.reapplyLocalChange,
              leading: const Icon(Icons.cloud_upload_outlined),
              onTap: () =>
                  onResolve(conflict, DavConflictResolution.reapplyLocal),
            ),
          if (conflict.canDuplicate)
            BusyMaxActionRow(
              title: l10n.duplicateLocalItem,
              leading: const Icon(Icons.copy_outlined),
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
    return '${name ?? account.providerAccountId} · ${account.authority}';
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
  if (collection.syncErrorCode case final errorCode?) {
    details.add(l10n.collectionSyncError(errorCode));
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
  });
  final AccountEntity account;
  final VoidCallback onMigrate;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(registrationSummariesProvider);
    final summary = summaries.valueOrNull?[account.id];
    final l10n = context.l10n;
    return YaruExpandable(
      key: ValueKey('account-advanced-${account.id}'),
      header: Text(l10n.advancedSection),
      expandIconSemanticLabel: l10n.advancedSection,
      child: BusyMaxGroupedList(
        filled: true,
        children: [
          BusyMaxActionRow(
            title: summaries.isLoading
                ? l10n.traySyncing
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
        ],
      ),
    );
  }
}
