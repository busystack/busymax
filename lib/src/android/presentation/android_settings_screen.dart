import '../../l10n/ical_import_report_description.dart';
import '../../schedule/schedule_task_list_actions.dart';
import '../../features/auth/application/account_connection.dart';
import '../../features/auth/application/account_removal.dart';
import '../../webcal/webcal_uri.dart';
import '../../schedule/schedule_creation_destinations.dart';
import '../../schedule/schedule_projection.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../calendar_providers/calendar_mutation.dart';
import '../../schedule/schedule_provider_links.dart';
import 'android_nextcloud_collection_screen.dart';
import '../../l10n/time_format_scope.dart';
export '../android_local_network_access.dart'
    show isAndroidLocalNetworkHost, requiresAndroidLocalNetworkAccess;
import '../android_local_network_access.dart';
import '../../features/sync/all_accounts_sync_scheduler.dart';
import 'android_nextcloud_certificate_dialog.dart';
import '../../ui/common/nextcloud_certificate_review.dart';
import 'android_contacts_settings.dart';
import '../../l10n/oauth_error_description.dart';

import 'package:busymax/src/core/auth/authorization_attempt.dart';

import '../../l10n/registration_description.dart';
import 'android_registration_setup_dialog.dart';
import '../../core/auth/oauth_registration.dart';

import 'dart:async';

import '../../features/settings/presentation/account_collection_creation_feedback.dart';

import 'dart:convert';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_bootstrap.dart';
import '../../calendar_providers/calendar_colors.dart';
import '../../dav/dav_errors.dart';
import '../../dav/auth/caldav_material_dialog.dart';
import '../../dav/http/dav_http_transport.dart';
import '../../dav/mutation/dav_conflict_repository.dart';
import '../../dav/nextcloud/nextcloud_collection_controller.dart';
import '../../dav/nextcloud/nextcloud_sharing_service.dart';
import '../../dav/nextcloud/nextcloud_trash_service.dart';
import '../../dav/nextcloud/nextcloud_trash_session.dart';
import '../../dav/nextcloud/nextcloud_federation_controller.dart';
import '../../l10n/nextcloud_collection_error_description.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/accounts/domain/account_collection_creation_capabilities.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/calendar/data/cloud_calendar_sharing_service.dart';
import '../../features/calendar/data/microsoft_shared_calendar_service.dart';
import 'android_cloud_calendar_sharing_content.dart';
import '../../features/sync/sync_auth_error.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../features/tasks/domain/task_capabilities.dart';
import '../../ical/ical_import_service.dart';
import '../../ical/ical_import_session.dart';
import '../../ical/ical_ingestion.dart';
import '../../l10n/app_locale.dart';
import '../../l10n/l10n.dart';
import '../../l10n/week_preferences_scope.dart';
import '../../providers/busy_provider.dart';
import '../../webcal/webcal_subscription_service.dart';
import '../android_notifications.dart';
import 'android_diagnostics_screen.dart';
import 'android_nextcloud_scheduling_screen.dart';

part 'android_source_actions.dart';

enum AndroidSettingsCategory {
  system,
  accounts,
  schedule,
  notifications,
  privacy,
  diagnostics,
}

String androidSettingsCategoryLabel(
  BuildContext context,
  AndroidSettingsCategory category,
) => switch (category) {
  AndroidSettingsCategory.system => context.l10n.settingsSystem,
  AndroidSettingsCategory.accounts => context.l10n.accounts,
  AndroidSettingsCategory.schedule => context.l10n.scheduleSection,
  AndroidSettingsCategory.notifications => context.l10n.notifications,
  AndroidSettingsCategory.privacy => context.l10n.privacy,
  AndroidSettingsCategory.diagnostics => context.l10n.diagnostics,
};

class _AndroidSettingsCategories extends StatelessWidget {
  const _AndroidSettingsCategories({
    required this.category,
    required this.sections,
    required this.onOpen,
  });
  final AndroidSettingsCategory category;
  final Map<AndroidSettingsCategory, List<Widget>> sections;
  final ValueChanged<AndroidSettingsCategory> onOpen;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final content = ListView(
        key: PageStorageKey(category),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 48),
        children: sections[category] ?? const [],
      );
      if (constraints.maxWidth >= 760) {
        return Row(
          children: [
            SizedBox(
              width: 220,
              child: ListView(
                children: [
                  for (final value in AndroidSettingsCategory.values)
                    ListTile(
                      selected: value == category,
                      title: Text(androidSettingsCategoryLabel(context, value)),
                      onTap: () => onOpen(value),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        );
      }
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<AndroidSettingsCategory>(
              key: ValueKey('android-settings-category-${category.name}'),
              isExpanded: true,
              initialValue: category,
              decoration: InputDecoration(labelText: context.l10n.settings),
              items: [
                for (final value in AndroidSettingsCategory.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(androidSettingsCategoryLabel(context, value)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onOpen(value);
                }
              },
            ),
          ),
          Expanded(child: content),
        ],
      );
    },
  );
}

class AndroidSettingsScreen extends ConsumerStatefulWidget {
  const AndroidSettingsScreen({
    super.key,
    this.category,
    this.notificationAccountId,
    this.notificationConflicts = false,
  });
  final AndroidSettingsCategory? category;
  final String? notificationAccountId;
  final bool notificationConflicts;

  @override
  ConsumerState<AndroidSettingsScreen> createState() =>
      _AndroidSettingsScreenState();
}

class _AndroidSettingsScreenState extends ConsumerState<AndroidSettingsScreen> {
  late AndroidSettingsCategory _selectedCategory =
      widget.category ??
      (widget.notificationConflicts
          ? AndroidSettingsCategory.diagnostics
          : AndroidSettingsCategory.system);
  @override
  void dispose() {
    _authorizationCancellation?.cancel();
    _sharedConsentCancellation?.cancel();
    super.dispose();
  }

  bool _syncing = false;
  BusyProvider? _connecting;
  AuthorizationCancellation? _authorizationCancellation;
  AuthorizationCancellation? _sharedConsentCancellation;
  final _removing = <String>{};

  @override
  Widget build(BuildContext context) {
    final allAccounts = ref.watch(accountManagementStreamProvider);
    final accounts = (allAccounts.valueOrNull ?? const <AccountEntity>[])
        .where(
          (account) =>
              widget.notificationAccountId == null ||
              account.id == widget.notificationAccountId,
        )
        .toList();
    final sourceState = ref.watch(calendarSourcesStreamProvider);
    final listState = ref.watch(scheduleTaskListsProvider);
    final sources = (sourceState.valueOrNull ?? const <CalendarSourceEntity>[])
        .where(
          (source) =>
              widget.notificationAccountId == null ||
              source.accountId == widget.notificationAccountId,
        )
        .toList();
    final lists = (listState.valueOrNull ?? const <TaskListEntity>[])
        .where(
          (list) =>
              widget.notificationAccountId == null ||
              list.accountId == widget.notificationAccountId,
        )
        .toList();
    final subscriptions =
        ref.watch(webCalSubscriptionsProvider).valueOrNull ?? const [];
    final conflicts =
        ref.watch(davConflictsStreamProvider).valueOrNull ?? const [];
    final settings = ref.watch(appSettingsControllerProvider);

    final category = _selectedCategory;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.notificationAccountId != null
              ? accounts.firstOrNull?.displayLabel ?? context.l10n.accounts
              : context.l10n.settings,
        ),
      ),
      body: Column(
        children: [
          if (ref.watch(appSettingsPersistenceFailedProvider))
            MaterialBanner(
              content: Text(context.l10n.settingsSaveFailed),
              actions: [
                TextButton(
                  onPressed: () => unawaited(
                    ref
                        .read(appSettingsControllerProvider.notifier)
                        .retrySave(),
                  ),
                  child: Text(context.l10n.retry),
                ),
              ],
            ),
          Expanded(
            child:
                widget.notificationAccountId != null &&
                    !widget.notificationConflicts &&
                    accounts.isNotEmpty
                ? _accountDetails(accounts.first, sources, lists)
                : _AndroidSettingsCategories(
                    category: category,
                    onOpen: (category) =>
                        setState(() => _selectedCategory = category),
                    sections: {
                      AndroidSettingsCategory.system: [
                        _Section(
                          title: context.l10n.appearance,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.palette_outlined),
                              title: Text(context.l10n.theme),
                              subtitle:
                                  DropdownButton<BusyMaxThemeModePreference>(
                                    isExpanded: true,
                                    value: settings.themeModePreference,
                                    onChanged: (value) {
                                      if (value != null) {
                                        unawaited(
                                          ref
                                              .read(
                                                appSettingsControllerProvider
                                                    .notifier,
                                              )
                                              .setThemeModePreference(value),
                                        );
                                      }
                                    },
                                    items: [
                                      DropdownMenuItem(
                                        value:
                                            BusyMaxThemeModePreference.system,
                                        child: Text(context.l10n.themeSystem),
                                      ),
                                      DropdownMenuItem(
                                        value: BusyMaxThemeModePreference.light,
                                        child: Text(context.l10n.themeLight),
                                      ),
                                      DropdownMenuItem(
                                        value: BusyMaxThemeModePreference.dark,
                                        child: Text(context.l10n.themeDark),
                                      ),
                                    ],
                                  ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.language),
                              title: Text(context.l10n.currentLocale),
                              subtitle: DropdownButton<String>(
                                isExpanded: true,
                                value: settings.localeTag ?? 'system',
                                onChanged: (value) => unawaited(
                                  ref
                                      .read(
                                        appSettingsControllerProvider.notifier,
                                      )
                                      .setLocaleTag(
                                        value == 'system' ? null : value,
                                      ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'system',
                                    child: Text(context.l10n.themeSystem),
                                  ),
                                  for (final option in busyMaxLocaleOptions)
                                    DropdownMenuItem(
                                      value: option.tag,
                                      child: Text(option.endonym),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      AndroidSettingsCategory.accounts: [
                        _Section(
                          title: context.l10n.addAccount,
                          children: [
                            if (_connecting != null)
                              ListTile(
                                title: Text(
                                  context.l10n.cancelAccountConnection,
                                ),
                                onTap: () {
                                  _authorizationCancellation?.cancel();
                                  setState(() => _connecting = null);
                                },
                              ),
                            _AccountButtons(
                              connecting: _connecting,
                              onConnect: (provider) =>
                                  unawaited(_connect(provider)),
                            ),
                          ],
                        ),
                        _Section(
                          title: context.l10n.accounts,
                          children: [
                            if (allAccounts.isLoading)
                              const LinearProgressIndicator(),
                            if (allAccounts.hasError)
                              ListTile(
                                title: Text(context.l10n.collectionsLoadFailed),
                                trailing: TextButton(
                                  onPressed: () => ref.invalidate(
                                    accountManagementStreamProvider,
                                  ),
                                  child: Text(context.l10n.retry),
                                ),
                              ),
                            for (final account in accounts.where(
                              (a) => !a.isSubscription,
                            ))
                              ListTile(
                                key: ValueKey('account-entry-${account.id}'),
                                leading: Icon(_providerIcon(account.provider)),
                                title: Text(account.displayLabel),
                                subtitle: Text(_accountSubtitle(account)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => AndroidSettingsScreen(
                                      notificationAccountId: account.id,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const AndroidContactsSettings(),
                        _Section(
                          title: context.l10n.importIcsFile,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.file_open_outlined),
                              title: Text(context.l10n.importIcsFile),
                              subtitle: Text(
                                context.l10n.calendarImportDescription,
                              ),
                              onTap: () =>
                                  unawaited(showAndroidIcsImport(context, ref)),
                            ),
                          ],
                        ),
                        _Section(
                          title: context.l10n.calendarSubscriptions,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.add_link),
                              title: Text(context.l10n.addCalendarSubscription),
                              subtitle: Text(
                                context.l10n.calendarSubscriptionsDescription,
                              ),
                              onTap: () => unawaited(_addSubscription()),
                            ),
                            for (final subscription in subscriptions)
                              ListTile(
                                leading: Icon(
                                  Icons.public,
                                  color: _subscriptionColor(subscription),
                                ),
                                title: Text(subscription.name),
                                subtitle: Text(
                                  [
                                    context.l10n.subscriptionSafeOrigin(
                                      subscription.safeOrigin,
                                    ),
                                    context.l10n.subscriptionReadOnly,
                                    subscription.lastSuccessfulSyncAtUtc == null
                                        ? context.l10n.syncNoRecord
                                        : context.l10n.subscriptionLastRefresh(
                                            DateFormat.yMd().add_Hm().format(
                                              subscription
                                                  .lastSuccessfulSyncAtUtc!
                                                  .toLocal(),
                                            ),
                                          ),
                                    context.l10n.subscriptionNextRefresh(
                                      DateFormat.yMd().add_Hm().format(
                                        subscription.nextRefreshAtUtc.toLocal(),
                                      ),
                                    ),
                                    if (subscription.lastFailureCode != null)
                                      context.l10n.subscriptionStatusIssue(
                                        subscription.lastFailureCode!,
                                      ),
                                  ].join('\n'),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) => unawaited(
                                    _subscriptionAction(subscription, value),
                                  ),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'refresh',
                                      child: Text(context.l10n.refreshNow),
                                    ),
                                    PopupMenuItem(
                                      value: 'color',
                                      child: Text(
                                        context.l10n.subscriptionColor,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'frequency',
                                      child: Text(
                                        context.l10n.subscriptionRefreshMode,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Text(context.l10n.rename),
                                    ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text(context.l10n.unsubscribe),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                      AndroidSettingsCategory.schedule: [
                        _Section(
                          title: context.l10n.scheduleSection,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.schedule),
                              title: Text(context.l10n.timeFormat),
                              subtitle:
                                  DropdownButton<BusyMaxTimeFormatPreference>(
                                    isExpanded: true,
                                    value: settings.timeFormatPreference,
                                    onChanged: (value) {
                                      if (value != null) {
                                        unawaited(
                                          ref
                                              .read(
                                                appSettingsControllerProvider
                                                    .notifier,
                                              )
                                              .setTimeFormatPreference(value),
                                        );
                                      }
                                    },
                                    items: [
                                      DropdownMenuItem(
                                        value:
                                            BusyMaxTimeFormatPreference.system,
                                        child: Text(context.l10n.themeSystem),
                                      ),
                                      DropdownMenuItem(
                                        value: BusyMaxTimeFormatPreference
                                            .twelveHour,
                                        child: Text(
                                          context.l10n.timeFormatTwelveHour,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: BusyMaxTimeFormatPreference
                                            .twentyFourHour,
                                        child: Text(
                                          context.l10n.timeFormatTwentyFourHour,
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.calendar_view_week_outlined,
                              ),
                              title: Text(context.l10n.firstDayOfWeek),
                              subtitle: DropdownButtonHideUnderline(
                                child:
                                    DropdownButton<
                                      BusyMaxFirstDayOfWeekPreference
                                    >(
                                      isExpanded: true,
                                      value: settings.firstDayOfWeekPreference,
                                      onChanged: (value) {
                                        if (value != null) {
                                          unawaited(
                                            ref
                                                .read(
                                                  appSettingsControllerProvider
                                                      .notifier,
                                                )
                                                .setFirstDayOfWeekPreference(
                                                  value,
                                                ),
                                          );
                                        }
                                      },
                                      items: [
                                        for (final value
                                            in BusyMaxFirstDayOfWeekPreference
                                                .values)
                                          DropdownMenuItem(
                                            value: value,
                                            child: Text(
                                              busyMaxFirstDayOfWeekPreferenceLabel(
                                                context,
                                                value,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                              ),
                            ),
                            ListTile(
                              title: Text(context.l10n.defaultCalendar),
                              subtitle: DropdownButton<CreationDestination>(
                                isExpanded: true,
                                value:
                                    sources.any(
                                      (s) =>
                                          s.id ==
                                              settings.defaultCalendar?.id &&
                                          s.accountId ==
                                              settings
                                                  .defaultCalendar
                                                  ?.accountId &&
                                          s.capabilities.canCreateEvents,
                                    )
                                    ? settings.defaultCalendar
                                    : null,
                                hint: Text(context.l10n.lastUsed),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(context.l10n.lastUsed),
                                  ),
                                  for (final source in sources.where(
                                    (s) => s.capabilities.canCreateEvents,
                                  ))
                                    DropdownMenuItem(
                                      value: CreationDestination(
                                        accountId: source.accountId,
                                        id: source.id,
                                      ),
                                      child: Text(
                                        '${source.summary} · ${source.authenticatedAccountEmail ?? source.accountId}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (value) => ref
                                    .read(
                                      appSettingsControllerProvider.notifier,
                                    )
                                    .setDefaultCalendar(value),
                              ),
                            ),
                            ListTile(
                              title: Text(context.l10n.defaultTaskList),
                              subtitle: DropdownButton<CreationDestination>(
                                isExpanded: true,
                                value:
                                    lists.any(
                                      (l) =>
                                          l.id ==
                                              settings.defaultTaskList?.id &&
                                          l.accountId ==
                                              settings
                                                  .defaultTaskList
                                                  ?.accountId &&
                                          ref.watch(
                                            scheduleTaskListCreateEligibleProvider(
                                              l,
                                            ),
                                          ),
                                    )
                                    ? settings.defaultTaskList
                                    : null,
                                hint: Text(context.l10n.lastUsed),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(context.l10n.lastUsed),
                                  ),
                                  for (final list in lists.where(
                                    (list) => ref.watch(
                                      scheduleTaskListCreateEligibleProvider(
                                        list,
                                      ),
                                    ),
                                  ))
                                    DropdownMenuItem(
                                      value: CreationDestination(
                                        accountId: list.accountId,
                                        id: list.id,
                                      ),
                                      child: Text(
                                        '${list.title} · ${accounts.where((a) => a.id == list.accountId).firstOrNull?.selectorLabel ?? list.accountId}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (value) => ref
                                    .read(
                                      appSettingsControllerProvider.notifier,
                                    )
                                    .setDefaultTaskList(value),
                              ),
                            ),
                            ListTile(
                              title: Text(context.l10n.scheduleDayStartsAt),
                              subtitle: Text(
                                _scheduleMinuteLabel(
                                  context,
                                  settings.scheduleDayStartMinute,
                                ),
                              ),
                              onTap: () => _pickDayBoundary(true),
                            ),
                            ListTile(
                              title: Text(context.l10n.scheduleDayEndsAt),
                              subtitle: Text(
                                _scheduleMinuteLabel(
                                  context,
                                  settings.scheduleDayEndMinute,
                                ),
                              ),
                              onTap: () => _pickDayBoundary(false),
                            ),
                          ],
                        ),
                      ],
                      AndroidSettingsCategory.notifications: [
                        _Section(
                          title: context.l10n.notifications,
                          children: [
                            _NotificationSwitch(
                              title: context.l10n.eventReminders,
                              value: settings.notifyEventReminders,
                              onChanged: (value) => _setNotificationSetting(
                                value,
                                ref
                                    .read(
                                      appSettingsControllerProvider.notifier,
                                    )
                                    .setNotifyEventReminders,
                              ),
                            ),
                            _NotificationSwitch(
                              title: context.l10n.taskReminders,
                              value: settings.notifyTaskReminders,
                              onChanged: (value) => _setNotificationSetting(
                                value,
                                ref
                                    .read(
                                      appSettingsControllerProvider.notifier,
                                    )
                                    .setNotifyTaskReminders,
                              ),
                            ),
                            SwitchListTile(
                              secondary: const Icon(Icons.today_outlined),
                              title: Text(context.l10n.notifyDueToday),
                              value: settings.notifyDueToday,
                              onChanged: (value) => unawaited(
                                _setNotificationSetting(
                                  value,
                                  ref
                                      .read(
                                        appSettingsControllerProvider.notifier,
                                      )
                                      .setNotifyDueToday,
                                ),
                              ),
                            ),
                            _NotificationSwitch(
                              title: context.l10n.notifySyncFailures,
                              value: settings.notifySyncFailures,
                              onChanged: (value) => _setNotificationSetting(
                                value,
                                ref
                                    .read(
                                      appSettingsControllerProvider.notifier,
                                    )
                                    .setNotifySyncFailures,
                              ),
                            ),
                            _NotificationSwitch(
                              title: context.l10n.notifyConflicts,
                              value: settings.notifyConflicts,
                              onChanged: (value) => _setNotificationSetting(
                                value,
                                ref
                                    .read(
                                      appSettingsControllerProvider.notifier,
                                    )
                                    .setNotifyConflicts,
                              ),
                            ),
                            SwitchListTile(
                              secondary: const Icon(
                                Icons.visibility_off_outlined,
                              ),
                              title: Text(context.l10n.notificationDetailLevel),
                              subtitle: Text(
                                context.l10n.notificationDetailPrivate,
                              ),
                              value:
                                  settings.notificationDetailLevel ==
                                  NotificationDetailLevel.private,
                              onChanged: (value) => unawaited(
                                ref
                                    .read(
                                      appSettingsControllerProvider.notifier,
                                    )
                                    .setNotificationDetailLevel(
                                      value
                                          ? NotificationDetailLevel.private
                                          : NotificationDetailLevel.normal,
                                    )
                                    .then(
                                      (_) => ref
                                          .read(notificationReconcilerProvider)
                                          .reconcile(),
                                    ),
                              ),
                            ),
                            ValueListenableBuilder<
                              AndroidNotificationReadiness
                            >(
                              valueListenable: ref
                                  .read(androidNotificationServiceProvider)
                                  .readiness,
                              builder: (context, status, _) => Column(
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons.notifications_outlined,
                                    ),
                                    title: Text(context.l10n.notifications),
                                    subtitle: Text(
                                      [
                                        if (status.failed ||
                                            !status.initialized ||
                                            status.notificationsAllowed == null)
                                          context.l10n.notificationsUnknown
                                        else if (status.notificationsAllowed ==
                                                false ||
                                            status.remindersAllowed == false ||
                                            status.summariesAllowed == false ||
                                            status.statusAllowed == false)
                                          context.l10n.notificationsBlocked
                                        else
                                          context.l10n.notificationsAllowed,
                                        if (status.remindersAllowed == false)
                                          context.l10n.reminders,
                                        if (status.summariesAllowed == false)
                                          context.l10n.notifyDueToday,
                                        if (status.statusAllowed == false)
                                          context.l10n.sync,
                                      ].join('\n'),
                                    ),
                                    onTap: () => BusyMaxAndroidPlatform.instance
                                        .openNotificationSettings(),
                                    trailing: TextButton(
                                      onPressed: () => unawaited(
                                        BusyMaxAndroidPlatform.instance
                                            .openNotificationSettings(),
                                      ),
                                      child: Text(context.l10n.settingsSystem),
                                    ),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.alarm_outlined),
                                    title: Text(context.l10n.reminders),
                                    subtitle: Text(
                                      status.exactAlarms
                                          ? context.l10n.notificationExactAlarms
                                          : context
                                                .l10n
                                                .notificationInexactAlarms,
                                    ),
                                    trailing: status.exactAlarms
                                        ? null
                                        : TextButton(
                                            onPressed: () => unawaited(
                                              _requestExactAlarms(),
                                            ),
                                            child: Text(
                                              context.l10n.settingsSystem,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            ListTile(
                              title: Text(context.l10n.dailySummaryTime),
                              subtitle: Text(context.l10n.dailySummaryScope),
                              trailing: Text(settings.dueTodayNotificationTime),
                              enabled: settings.notifyDueToday,
                              onTap: _pickSummaryTime,
                            ),
                            SwitchListTile(
                              secondary: const Icon(Icons.bedtime_outlined),
                              title: Text(context.l10n.quietHours),
                              subtitle: Text(
                                context.l10n.quietHoursDescription,
                              ),
                              value: settings.quietHoursEnabled,
                              onChanged: (value) => unawaited(
                                ref
                                    .read(
                                      appSettingsControllerProvider.notifier,
                                    )
                                    .setQuietHoursEnabled(value)
                                    .then(
                                      (_) => ref
                                          .read(notificationReconcilerProvider)
                                          .reconcile(),
                                    ),
                              ),
                            ),
                            ...[
                              ListTile(
                                leading: const Icon(Icons.nights_stay_outlined),
                                title: Text(context.l10n.quietHoursStart),
                                enabled: settings.quietHoursEnabled,
                                trailing: Text(settings.quietHoursStart),
                                onTap: () => unawaited(_pickQuietTime(true)),
                              ),
                              ListTile(
                                leading: const Icon(Icons.wb_sunny_outlined),
                                title: Text(context.l10n.quietHoursEnd),
                                enabled: settings.quietHoursEnabled,
                                trailing: Text(settings.quietHoursEnd),
                                onTap: () => unawaited(_pickQuietTime(false)),
                              ),
                            ],
                          ],
                        ),
                      ],
                      AndroidSettingsCategory.privacy: [
                        _Section(
                          title: context.l10n.privacy,
                          children: [
                            SwitchListTile(
                              secondary: const Icon(Icons.shield_outlined),
                              title: Text(
                                context.l10n.redactTaskContentInDiagnostics,
                              ),
                              value: settings.redactTaskContentInDiagnostics,
                              onChanged: (value) => unawaited(
                                ref
                                    .read(
                                      appSettingsControllerProvider.notifier,
                                    )
                                    .setRedactTaskContentInDiagnostics(value),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.privacy_tip_outlined),
                              title: Text(context.l10n.privacy),
                              enabled: ref
                                  .read(buildConfigProvider)
                                  .privacyPolicyUrl
                                  .isNotEmpty,
                              onTap: () =>
                                  unawaited(_openConfiguredLink('privacy')),
                            ),
                          ],
                        ),
                      ],
                      AndroidSettingsCategory.diagnostics: [
                        _Section(
                          title: context.l10n.sync,
                          children: [
                            ListTile(
                              leading: _syncing
                                  ? const SizedBox.square(
                                      dimension: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync),
                              title: Text(context.l10n.sync),
                              enabled: !_syncing,
                              onTap: _syncing
                                  ? null
                                  : () => unawaited(_syncAll()),
                            ),
                            ListTile(
                              leading: const Icon(Icons.sync_problem_outlined),
                              title: Text(context.l10n.forceFullResync),
                              subtitle: Text(
                                context.l10n.forceFullResyncDescription,
                              ),
                              enabled: !_syncing,
                              onTap: _syncing
                                  ? null
                                  : () => unawaited(_syncAll(full: true)),
                            ),
                          ],
                        ),
                        _Section(
                          title: context.l10n.syncConflicts,
                          children: [
                            if (conflicts.isEmpty)
                              ListTile(
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(
                                  context.l10n.noBlockedPendingOperations,
                                ),
                              ),
                            for (final conflict in conflicts.where(
                              (conflict) =>
                                  widget.notificationAccountId == null ||
                                  conflict.accountId ==
                                      widget.notificationAccountId,
                            ))
                              ListTile(
                                leading: const Icon(Icons.warning_amber),
                                title: Text(conflict.itemTitle),
                                subtitle: Text(
                                  '${conflict.accountLabel} · ${conflict.collectionName}\n${conflict.localEditSummary}',
                                ),
                                isThreeLine: true,
                                onTap: () =>
                                    unawaited(_resolveConflict(conflict)),
                              ),
                          ],
                        ),
                        AndroidDiagnosticsScreen(
                          accountId: widget.notificationAccountId,
                          embedded: true,
                        ),
                      ],
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _accountDetails(
    AccountEntity account,
    List<CalendarSourceEntity> sources,
    List<TaskListEntity> lists,
  ) {
    final conflicts = ref.watch(davConflictsStreamProvider).valueOrNull ?? [];
    final collections =
        (ref.watch(davCollectionsStreamProvider).valueOrNull ?? []).where(
          (c) =>
              c.accountId == account.id &&
              (c.supportsEvents || c.supportsTasks),
        );
    final pendingInvitations =
        ref
            .watch(nextcloudPendingInvitationCountProvider(account.id))
            .valueOrNull ??
        0;
    return ListView(
      key: PageStorageKey('account-${account.id}'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 48),
      children: [
        _Section(
          title: account.provider.displayName,
          children: [
            ListTile(
              leading: Icon(_providerIcon(account.provider)),
              title: Text(account.displayLabel),
              subtitle: Text(_accountSubtitle(account)),
            ),
            ListTile(
              key: ValueKey('account-recovery-${account.id}'),
              leading: Icon(
                account.needsReconnect ? Icons.key_outlined : Icons.refresh,
              ),
              title: Text(
                account.needsReconnect
                    ? context.l10n.reconnectAccount
                    : context.l10n.refreshAll,
              ),
              enabled:
                  !_syncing &&
                  _connecting == null &&
                  (account.isSyncEligible || account.needsReconnect),
              onTap: () => unawaited(
                account.needsReconnect
                    ? _connect(account.provider, account)
                    : _syncAccount(account.id),
              ),
            ),
            ExpansionTile(
              key: PageStorageKey(('account-sync-details', account.id)),
              title: Text(context.l10n.sync),
              children: [
                _AndroidAccountSyncStatus(
                  account: account,
                  onRefresh: (calendar) => _refreshDomain(account, calendar),
                ),
              ],
            ),
          ],
        ),
        if (account.provider.isDav &&
            ref
                .watch(accountCollectionCreationFailuresProvider(account.id))
                .isNotEmpty)
          AccountCollectionCreationFeedback(
            accountId: account.id,
            dismissButtonBuilder: (_, onPressed, label) =>
                TextButton(onPressed: onPressed, child: Text(label)),
          ),
        _Section(
          title: context.l10n.collectionSettings,
          children: [
            if (account.isSignedIn &&
                account.calendarsEnabled &&
                accountCollectionCreationModes(account.provider).calendarMode !=
                    CalendarCollectionCreationMode.unavailable)
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: Text(context.l10n.newCalendar),
                onTap: () =>
                    unawaited(_createCollection([account], calendar: true)),
              ),
            if (account.isSignedIn &&
                account.tasksEnabled &&
                accountCollectionCreationModes(account.provider).taskListMode !=
                    TaskListCreationMode.unavailable)
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: Text(context.l10n.newTaskList),
                onTap: () =>
                    unawaited(_createCollection([account], calendar: false)),
              ),
            if (!account.provider.isDav) ...[
              for (final source in sources)
                Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.calendar_today_outlined,
                        color: _settingsSourceColor(source),
                      ),
                      title: Text(source.summary),
                      subtitle: Text(
                        [
                          if (source.primaryCalendar) context.l10n.calendar,
                          if (!source.capabilities.canEditEvents)
                            context.l10n.readOnlySharedCollection,
                          if (source.hidden) context.l10n.off,
                          if (source.accessRole == 'unavailable')
                            context.l10n.collectionsUnavailable,
                        ].join(' · '),
                      ),
                      onTap: () => unawaited(_editCalendarSource(source)),
                    ),
                    SwitchListTile(
                      title: Text(context.l10n.showInSchedule),
                      value: source.selected && !source.hidden,
                      onChanged: source.hidden
                          ? null
                          : (value) => unawaited(
                              ref
                                  .read(calendarRepositoryProvider)
                                  .setSourceSelected(source.id, value),
                            ),
                    ),
                    if (account.provider == BusyProvider.google)
                      AndroidCalendarProviderVisibility(
                        source: source,
                        showSourceName: false,
                      ),
                  ],
                ),
              for (final list in lists)
                Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.checklist_outlined),
                      title: Text(list.title),
                      onTap: () => unawaited(_editTaskList(list, [account])),
                    ),
                    SwitchListTile(
                      title: Text(context.l10n.showInSchedule),
                      value: ref
                          .watch(appSettingsControllerProvider)
                          .isTaskListVisibleInSchedule(list.accountId, list.id),
                      onChanged: (value) => unawaited(
                        ref
                            .read(appSettingsControllerProvider.notifier)
                            .setTaskListVisibleInSchedule(
                              accountId: list.accountId,
                              taskListId: list.id,
                              visible: value,
                            ),
                      ),
                    ),
                  ],
                ),
            ],
            for (final collection in collections)
              Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(collection.name),
                    subtitle: Text(
                      collection.readOnly
                          ? context.l10n.readOnlySharedCollection
                          : collection.capabilities.permissionsKnown
                          ? context.l10n.collectionSettings
                          : context.l10n.davPermissionsUnknown,
                    ),
                    onTap: () => account.provider == BusyProvider.nextcloud
                        ? Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => AndroidNextcloudCollectionScreen(
                                accountId: account.id,
                                collectionId: collection.id,
                              ),
                            ),
                          )
                        : _selectCalDavCollection(collection.id),
                  ),
                  if (collection.supportsEvents)
                    SwitchListTile(
                      title: Text(
                        collection.supportsTasks
                            ? context.l10n.calendarContent
                            : context.l10n.showInSchedule,
                      ),
                      value: collection.eventsSelected,
                      onChanged: (value) => unawaited(
                        ref
                            .read(davSettingsRepositoryProvider)
                            .setEventsSelected(collection.id, value),
                      ),
                    ),
                  if (collection.supportsTasks)
                    SwitchListTile(
                      title: Text(
                        collection.supportsEvents
                            ? context.l10n.taskContent
                            : context.l10n.showInSchedule,
                      ),
                      value: collection.tasksSelected,
                      onChanged: (value) => unawaited(
                        ref
                            .read(davSettingsRepositoryProvider)
                            .setTasksSelected(collection.id, value),
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (conflicts.any((c) => c.accountId == account.id))
          _Section(
            title: context.l10n.syncConflicts,
            children: [
              for (final conflict in conflicts.where(
                (c) => c.accountId == account.id,
              ))
                ListTile(
                  title: Text(conflict.itemTitle),
                  subtitle: Text(conflict.collectionName),
                  onTap: () => unawaited(_resolveConflict(conflict)),
                ),
            ],
          ),
        if (account.provider == BusyProvider.microsoft && account.isSignedIn)
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(context.l10n.openSharedCalendar),
            onTap: () => unawaited(_openSharedCalendar(account.id)),
          ),
        if (sources.any(CloudCalendarSharingService.canManageSource))
          ListTile(
            key: Key('android-manage-sharing-${account.id}'),
            leading: const Icon(Icons.people_outline),
            title: Text(context.l10n.manageCalendarSharing),
            onTap: () => unawaited(
              _manageCalendarSharing(
                sources
                    .where(CloudCalendarSharingService.canManageSource)
                    .toList(),
              ),
            ),
          ),
        if (account.provider == BusyProvider.nextcloud) ...[
          if (ref.watch(nextcloudFederationAvailableProvider(account.id)))
            ListTile(
              leading: const Icon(Icons.mark_email_unread_outlined),
              title: Text(
                '${context.l10n.nextcloudFederationInvitations} ($pendingInvitations)',
              ),
              enabled: ref.watch(
                nextcloudFederationAvailableProvider(account.id),
              ),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      AndroidNextcloudFederationScreen(accountId: account.id),
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(context.l10n.nextcloudTrash),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    AndroidNextcloudTrashScreen(accountId: account.id),
              ),
            ),
          ),
        ],
        AndroidContactsSettings(accountId: account.id),
        ExpansionTile(
          key: PageStorageKey(('account-advanced', account.id)),
          title: Text(context.l10n.advancedSection),
          children: [
            if (account.provider == BusyProvider.nextcloud ||
                account.provider == BusyProvider.caldav)
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(context.l10n.privateServerCertificates),
                onTap: () => manageNextcloudCertificates(
                  ref,
                  account.id,
                  (data) => mounted
                      ? showAndroidNextcloudCertificate(context, data)
                      : Future.value(null),
                ),
              ),
            if (account.provider == BusyProvider.google ||
                account.provider == BusyProvider.microsoft)
              _AndroidRegistrationCard(
                account: account,
                onMigrate: () => _connect(account.provider, account, true),
              ),
            ListTile(
              title: Text(context.l10n.reconnectAccount),
              onTap: () => unawaited(_connect(account.provider, account)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.person_remove_outlined),
          title: Text(context.l10n.removeAccount),
          enabled: !_removing.contains(account.id),
          onTap: () => unawaited(_removeAccount(account)),
        ),
      ],
    );
  }

  Color _subscriptionColor(WebCalSubscriptionEntity subscription) {
    final color = int.tryParse(
      subscription.color?.replaceAll('#', '') ?? '',
      radix: 16,
    );
    return color == null
        ? ScheduleProjection.deterministicSourceColor(
            subscription.calendarSourceId,
            Theme.of(context).brightness,
          )
        : Color(0xff000000 | color);
  }

  Color _settingsSourceColor(CalendarSourceEntity source) {
    final hex = calendarSourceBackgroundColorHex(
      provider: source.provider,
      backgroundColor: source.backgroundColor,
      colorId: source.colorId,
    );
    return hex == null
        ? ScheduleProjection.deterministicSourceColor(
            source.id,
            Theme.of(context).brightness,
          )
        : Color(0xff000000 | int.parse(hex.replaceAll('#', ''), radix: 16));
  }

  String _accountSubtitle(AccountEntity account) {
    final state = account.isSignedIn
        ? context.l10n.signedInAccount
        : account.needsReconnect
        ? context.l10n.accountReconnectRequired
        : account.authState;
    final activity = ref.watch(accountSyncActivityProvider);
    final failures = [
      for (final domain in ['calendar', 'tasks', 'dav'])
        if (activity.failure(account.id, domain) case final error?)
          syncFailureMessage(
            error,
            networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
          ),
    ];
    final sources = ref.watch(calendarSourcesStreamProvider);
    final lists = ref.watch(scheduleTaskListsProvider);
    final discovery = account.provider.isDav
        ? ref.watch(davAccountDiscoveryProvider(account.id))
        : null;
    final collections = ref.watch(davCollectionsStreamProvider);
    final inventoryFailed =
        sources.hasError ||
        lists.hasError ||
        discovery?.hasError == true ||
        collections.hasError;
    final unavailable =
        (sources.valueOrNull ?? []).any(
          (s) => s.accountId == account.id && s.accessRole == 'unavailable',
        ) ||
        (collections.valueOrNull ?? []).any(
          (c) => c.accountId == account.id && c.syncErrorCode != null,
        ) ||
        discovery?.valueOrNull?.lastDiscoveryErrorCode != null;
    return [
      '${account.provider.displayName} · $state',
      if (inventoryFailed) context.l10n.collectionsLoadFailed,
      if (unavailable) context.l10n.cachedSyncError,
      ...failures.toSet(),
      if (account.provider.isDav && account.lastSuccessfulSyncAtUtc != null)
        context.l10n.davLastSuccessfulSync(
          DateFormat.yMd().add_jm().format(
            account.lastSuccessfulSyncAtUtc!.toLocal(),
          ),
        ),
    ].join('\n');
  }

  Future<void> _connect(
    BusyProvider provider, [
    AccountEntity? reconnecting,
    bool replaceRegistration = false,
  ]) async {
    if (_connecting != null ||
        _authorizationCancellation?.isCancelled == false) {
      return;
    }
    final ownedCancellation = AuthorizationCancellation();
    _authorizationCancellation = ownedCancellation;
    final davCancellation = DavCancellationToken();
    unawaited(ownedCancellation.signal.then((_) => davCancellation.cancel()));
    try {
      String? email;
      String? password;
      String? server;
      if (provider == BusyProvider.caldav) {
        final input = await showMaterialCalDavCredentialDialog(
          context,
          fixedServer: reconnecting?.authority,
          fixedUsername: reconnecting?.providerAccountId,
        );
        if (input == null || !mounted) {
          return;
        }
        server = input.serverUrl;
        email = input.username;
        password = input.password;
      } else if (provider == BusyProvider.appleICloud) {
        final input = await _appleCredentials(reconnecting?.email);
        if (input == null) {
          return;
        }
        (email, password) = input;
      } else if (provider == BusyProvider.nextcloud) {
        server = await _textPrompt(
          title: context.l10n.registrationSetupTitle(
            BusyProvider.nextcloud.displayName,
          ),
          label: context.l10n.nextcloudServerUrl,
          initialValue: reconnecting?.authority,
          helper: context.l10n.nextcloudBrowserAuthorizationHelp,
        );
        if (server == null || !mounted) {
          return;
        }
      }
      if (server != null) {
        if (!await _ensureLocalNetworkAccess(server)) {
          return;
        }
      }
      if (!mounted) {
        return;
      }
      AuthorizationRequest? request;
      if (provider == BusyProvider.microsoft) {
        if (reconnecting != null && !replaceRegistration) {
          request = AuthorizationRequest.reconnect(reconnecting.id);
        } else {
          final handle = await showAndroidRegistrationSetup(
            context,
            ref,
            provider,
          );
          if (handle == null || !mounted) {
            return;
          }
          request = reconnecting == null
              ? AuthorizationRequest.newConnection(handle)
              : AuthorizationRequest.replace(reconnecting.id, handle);
        }
      } else if (provider == BusyProvider.google && reconnecting != null) {
        request = AuthorizationRequest.reconnect(reconnecting.id);
      }
      setState(() => _connecting = provider);
      if (!mounted || ownedCancellation.isCancelled) {
        return;
      }
      request = (request ?? const AuthorizationRequest.newConnection(null))
          .withCancellation(ownedCancellation);
      try {
        String? accountId;
        switch (provider) {
          case BusyProvider.google:
            accountId =
                (await ref
                        .read(authRepositoryProvider)
                        .signIn(request: request))
                    .accountId;
          case BusyProvider.microsoft:
            accountId =
                (await ref
                        .read(authRepositoryProvider)
                        .signInWithMicrosoft(request: request))
                    .accountId;
          case BusyProvider.appleICloud:
            final service = ref.read(davAccountOnboardingServiceProvider);
            accountId = reconnecting == null
                ? (await service.connectAppleICloud(
                    email: email!,
                    appSpecificPassword: password!,
                    cancellationToken: davCancellation,
                  )).accountId
                : (await service.replaceAppleAppSpecificPassword(
                    accountId: reconnecting.id,
                    appSpecificPassword: password!,
                    cancellationToken: davCancellation,
                  )).accountId;
          case BusyProvider.nextcloud:
            final service = ref.read(davAccountOnboardingServiceProvider);
            accountId = reconnecting == null
                ? (await service.connectNextcloud(
                    reviewCanonicalServer: (entered, canonical) => mounted
                        ? showAndroidNextcloudCanonicalServer(
                            context,
                            entered,
                            canonical,
                          )
                        : Future.value(false),
                    reviewCertificate: (challenge, owner) =>
                        reviewNextcloudCertificate(
                          challenge,
                          owner,
                          (data) => mounted
                              ? showAndroidNextcloudCertificate(context, data)
                              : Future.value(null),
                        ),
                    enteredServer: server!,
                    cancellationToken: davCancellation,
                  )).accountId
                : (await service.reconnectNextcloud(
                    reviewCanonicalServer: (entered, canonical) => mounted
                        ? showAndroidNextcloudCanonicalServer(
                            context,
                            entered,
                            canonical,
                          )
                        : Future.value(false),
                    reviewCertificate: (challenge, owner) =>
                        reviewNextcloudCertificate(
                          challenge,
                          owner,
                          (data) => mounted
                              ? showAndroidNextcloudCertificate(context, data)
                              : Future.value(null),
                        ),
                    accountId: reconnecting.id,
                    enteredServer: server!,
                    cancellationToken: davCancellation,
                  )).accountId;
          case BusyProvider.caldav:
            final service = ref.read(davAccountOnboardingServiceProvider);
            accountId = reconnecting == null
                ? (await service.connectCalDav(
                    serverUrl: server!,
                    username: email!,
                    password: password!,
                    reviewCertificate: (challenge, owner) =>
                        reviewNextcloudCertificate(
                          challenge,
                          owner,
                          (data) => mounted
                              ? showAndroidNextcloudCertificate(context, data)
                              : Future.value(null),
                          caldavService: true,
                        ),
                    cancellationToken: davCancellation,
                  )).accountId
                : (await service.replaceCalDavPassword(
                    accountId: reconnecting.id,
                    password: password!,
                    reviewCertificate: (challenge, owner) =>
                        reviewNextcloudCertificate(
                          challenge,
                          owner,
                          (data) => mounted
                              ? showAndroidNextcloudCertificate(context, data)
                              : Future.value(null),
                          caldavService: true,
                        ),
                    cancellationToken: davCancellation,
                  )).accountId;
          case BusyProvider.webCal:
            return;
        }
        if (accountId != null &&
            mounted &&
            identical(_authorizationCancellation, ownedCancellation)) {
          await finishAccountConnection(
            accountId: accountId,
            cancellation: ownedCancellation,
            session: ref.read(authSessionControllerProvider.notifier),
            synchronize: () => _syncAccount(accountId!),
            onFollowUpFailure: (error) {
              if (mounted) {
                _message(
                  context.l10n.syncFailed(
                    localizedAuthorizationError(context.l10n, error),
                  ),
                );
              }
            },
          );
        }
      } on Object catch (error) {
        if (accountConnectionWasCancelled(error)) return;
        if (mounted &&
            identical(_authorizationCancellation, ownedCancellation)) {
          _message(localizedAuthorizationError(context.l10n, error));
        }
      } finally {
        if (mounted &&
            identical(_authorizationCancellation, ownedCancellation)) {
          setState(() => _connecting = null);
        }
      }
    } finally {
      ownedCancellation.cancel();
      if (identical(_authorizationCancellation, ownedCancellation)) {
        _authorizationCancellation = null;
        if (mounted) {
          setState(() => _connecting = null);
        }
      }
    }
  }

  Future<(String, String)?> _appleCredentials(String? fixedEmail) {
    return showDialog<(String, String)>(
      context: context,
      builder: (_) => _AndroidAppleCredentialsDialog(fixedEmail: fixedEmail),
    );
  }

  Future<void> _removeAccount(AccountEntity account) async {
    final l10n = context.l10n;
    var revoke = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.removeAccountTitle(account.displayLabel)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.removeAccountConfirmation),
              if (account.provider == BusyProvider.nextcloud)
                Text(context.l10n.nextcloudRemovalAuthorizationDescription),
              if (account.provider == BusyProvider.google)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.revokeGoogleAccess),
                  subtitle: Text(context.l10n.revokeGoogleAccessDescription),
                  value: revoke,
                  onChanged: (value) =>
                      setDialogState(() => revoke = value == true),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.removeAccountAction),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _removing.add(account.id));
    try {
      final outcome = await removeBusyMaxAccount(
        accountId: account.id,
        provider: account.provider,
        revokeGoogleAuthorization: revoke,
        auth: () => ref.read(authRepositoryProvider),
        dav: () => ref.read(davAccountOnboardingServiceProvider),
        guardOAuthRemoval: (remove) =>
            ref.read(crossEngineAccountGateProvider).run(account.id, remove),
      );
      final warning = localizedAccountRemovalWarning(l10n, outcome);
      if (mounted && warning != null) {
        _message(warning);
      }
      await ref.read(notificationReconcilerProvider).reconcile();
      if (mounted && widget.notificationAccountId == account.id) {
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      _message(localizedAccountRemovalError(l10n, error));
    } finally {
      if (mounted) {
        setState(() => _removing.remove(account.id));
      }
    }
  }

  Future<void> _pickDayBoundary(bool start) async {
    final settings = ref.read(appSettingsControllerProvider);
    final value = start
        ? settings.scheduleDayStartMinute
        : settings.scheduleDayEndMinute;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60 % 24, minute: value % 60),
    );
    if (time == null || !mounted) {
      return;
    }
    final minute = time.hour * 60 + time.minute;
    final controller = ref.read(appSettingsControllerProvider.notifier);
    if (start) {
      await controller.setScheduleDayStartMinute(minute);
    } else {
      await controller.setScheduleDayEndMinute(minute == 0 ? 1440 : minute);
    }
  }

  Future<void> _syncAll({bool full = false}) async {
    final l10n = context.l10n;
    setState(() => _syncing = true);
    try {
      final accounts = await ref
          .read(accountsRepositoryProvider)
          .listSyncEligibleAccounts();
      final blocked = <String>{};
      for (final account in accounts) {
        if ((account.provider == BusyProvider.caldav ||
                account.provider == BusyProvider.nextcloud) &&
            !await _ensureLocalNetworkAccess(account.authority)) {
          blocked.add(account.id);
        }
      }
      if (blocked.isEmpty && !full) {
        await ref.read(allAccountsSyncRunnerProvider)();
      } else {
        await runAllSyncEligibleAccountSync(
          listSyncEligibleAccounts: () async => [
            for (final account in accounts)
              if (!blocked.contains(account.id)) account,
          ],
          syncAccount: (id) => ref.read(signedInSyncRunnerProvider)(id, full),
          rethrowFirstFailure: true,
          onSyncFailure: (error) => ref
              .read(operationalNotificationReporterProvider)
              .notifySyncFailure(error),
        );
      }
      await ref.read(notificationReconcilerProvider).reconcile();
      if (blocked.isEmpty) {
        _message(l10n.syncComplete);
      }
    } on Object catch (error) {
      _message(
        l10n.syncFailed(
          syncFailureMessage(
            error,
            networkUnavailableMessage: l10n.networkOfflineTryAgain,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _refreshDomain(AccountEntity account, bool calendar) async {
    final current = await ref
        .read(accountsRepositoryProvider)
        .accountById(account.id);
    if (!mounted || current?.isSyncEligible != true) {
      return;
    }
    if (current!.provider.isDav &&
        !await _ensureLocalNetworkAccess(current.authority)) {
      return;
    }
    try {
      final operations = ref.read(accountSyncOperationsProvider);
      if (calendar) {
        await operations.syncCalendar(account.id, full: false);
      } else {
        await operations.syncTasks(account.id, full: false);
      }
    } on Object catch (error) {
      _message('$error');
    }
  }

  Future<void> _syncAccount(String accountId) async {
    final l10n = context.l10n;
    try {
      final account = await ref
          .read(accountsRepositoryProvider)
          .accountById(accountId);
      if (account?.isSyncEligible != true) {
        if (account?.needsReconnect == true) {
          _message(l10n.syncFailed(accountReconnectRequiredSyncMessage));
        }
        return;
      }
      if ((account!.provider == BusyProvider.caldav ||
              account.provider == BusyProvider.nextcloud) &&
          !await _ensureLocalNetworkAccess(account.authority)) {
        return;
      }
      await ref.read(signedInSyncRunnerProvider)(accountId, true);
      await ref.read(notificationReconcilerProvider).reconcile();
      _message(l10n.syncComplete);
    } on Object catch (error) {
      _message(
        l10n.syncFailed(
          syncFailureMessage(
            error,
            networkUnavailableMessage: l10n.networkOfflineTryAgain,
          ),
        ),
      );
    }
  }

  /// Foreground recovery for retained accounts, including permission revoked
  /// after onboarding. Background synchronization never requests permission.
  Future<bool> _ensureLocalNetworkAccess(String server) =>
      ensureAndroidLocalNetworkAccess(context, server);

  Future<void> _openSharedCalendar(String accountId) async {
    _sharedConsentCancellation?.cancel();
    final cancellation = AuthorizationCancellation();
    _sharedConsentCancellation = cancellation;
    try {
      final controller = TextEditingController();
      final l10n = context.l10n;
      final owner = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.openSharedCalendar),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.calendarOwnerEmail),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(l10n.openSharedCalendar),
            ),
          ],
        ),
      );
      controller.dispose();
      if (!mounted || owner == null || owner.trim().isEmpty) {
        return;
      }
      try {
        final result = await ref
            .read(microsoftSharedCalendarServiceProvider)
            .openPrimaryCalendar(
              accountId: accountId,
              owner: owner,
              cancellation: cancellation,
            );
        if (result.outcome ==
            MicrosoftSharedCalendarOpenOutcome.rangeUnavailable) {
          _message(l10n.scheduleRangeIncomplete);
        }
      } on Object catch (error) {
        _message(l10n.calendarUpdateFailed('$error'));
      }
    } finally {
      cancellation.cancel();
      if (identical(_sharedConsentCancellation, cancellation)) {
        _sharedConsentCancellation = null;
      }
    }
  }

  Future<void> _manageCalendarSharing(
    List<CalendarSourceEntity> sources,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.manageCalendarSharing),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: CloudCalendarSharingContent(sources: sources),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCalDavCollection(String id) =>
      showAndroidDavCollectionSelection(context, ref, id);

  Future<void> _editCalendarSource(CalendarSourceEntity source) =>
      showAndroidCalendarSourceActions(context, ref, source);

  Future<void> _editTaskList(
    TaskListEntity list,
    List<AccountEntity> accounts,
  ) => showAndroidTaskListActions(context, ref, list, accounts);

  Future<void> _createCollection(
    List<AccountEntity> accounts, {
    required bool calendar,
  }) async {
    final l10n = context.l10n;
    final eligible = accounts
        .where((account) {
          final modes = accountCollectionCreationModes(account.provider);
          return account.isSignedIn &&
              (calendar
                  ? account.calendarsEnabled &&
                        modes.calendarMode !=
                            CalendarCollectionCreationMode.unavailable
                  : account.tasksEnabled &&
                        modes.taskListMode != TaskListCreationMode.unavailable);
        })
        .toList(growable: false);
    if (eligible.isEmpty) {
      return;
    }
    final account = eligible.length == 1
        ? eligible.single
        : await showModalBottomSheet<AccountEntity>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      calendar
                          ? context.l10n.newCalendar
                          : context.l10n.newTaskList,
                    ),
                  ),
                  for (final candidate in eligible)
                    ListTile(
                      leading: Icon(_providerIcon(candidate.provider)),
                      title: Text(candidate.displayLabel),
                      subtitle: Text(candidate.provider.displayName),
                      onTap: () => Navigator.pop(sheetContext, candidate),
                    ),
                ],
              ),
            ),
          );
    if (account == null || !mounted) {
      return;
    }
    final title = await _textPrompt(
      title: calendar ? l10n.newCalendar : l10n.newTaskList,
      label: l10n.title,
    );
    if (title == null || !mounted) {
      return;
    }
    try {
      if (calendar) {
        final result = await ref
            .read(calendarCollectionCreationServiceProvider)
            .createCalendar(accountId: account.id, title: title);
        if (account.provider == BusyProvider.caldav && result.refreshPending) {
          _message(l10n.davRefreshPending);
        }
      } else {
        await ref
            .read(taskListsRepositoryForAccountProvider(account.id))
            .createTaskList(title);
      }
    } on DavRefreshPending {
      _message(l10n.davRefreshPending);
    } on Object catch (error) {
      if (error is DavException &&
          error.code == 'DavCollectionCreationPending') {
        _message(l10n.davCollectionCreationPending);
        return;
      }

      final message = syncFailureMessage(
        error,
        networkUnavailableMessage: l10n.networkOfflineTryAgain,
      );
      _message(
        calendar
            ? l10n.calendarCreateFailed(message)
            : l10n.taskListCreateFailed(message),
      );
    }
  }

  Future<void> _addSubscription() async {
    final url = TextEditingController(),
        name = TextEditingController(),
        color = TextEditingController();
    var mode = WebCalRefreshMode.automatic;
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            String? origin;
            try {
              origin = normalizeWebCalUri(url.text).safeOrigin.toString();
            } on FormatException {
              /* Validate on submission. */
            }
            return AlertDialog(
              title: Text(context.l10n.addCalendarSubscription),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: url,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: context.l10n.subscriptionUrl,
                        helperText: context.l10n.subscriptionUrlHelp,
                      ),
                      onChanged: (_) => setDialogState(() => error = null),
                    ),
                    if (origin != null)
                      Text(context.l10n.subscriptionSafeOrigin(origin)),
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: context.l10n.subscriptionName,
                      ),
                    ),
                    TextField(
                      controller: color,
                      decoration: InputDecoration(
                        labelText: context.l10n.subscriptionColor,
                        helperText: context.l10n.subscriptionColorHelp,
                      ),
                    ),
                    DropdownButtonFormField<WebCalRefreshMode>(
                      initialValue: mode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.subscriptionRefreshMode,
                      ),
                      items: [
                        for (final value in WebCalRefreshMode.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(switch (value) {
                              WebCalRefreshMode.automatic =>
                                context.l10n.subscriptionAutomatic,
                              WebCalRefreshMode.hourly =>
                                context.l10n.subscriptionHourly,
                              WebCalRefreshMode.sixHours =>
                                context.l10n.subscriptionSixHours,
                              WebCalRefreshMode.daily =>
                                context.l10n.subscriptionDaily,
                            }),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          mode = value;
                        }
                      },
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      normalizeWebCalUri(url.text);
                    } on FormatException {
                      setDialogState(
                        () => error = context.l10n.subscriptionUrlInvalid,
                      );
                      return;
                    }
                    if (color.text.trim().isNotEmpty &&
                        !RegExp(r'^#[0-9a-fA-F]{6}$')
                            .hasMatch(color.text.trim())) {
                      setDialogState(
                        () => error = context.l10n.subscriptionColorInvalid,
                      );
                      return;
                    }
                    try {
                      await ref
                          .read(webCalSubscriptionServiceProvider)
                          .addSubscription(
                            subscriptionUrl: url.text,
                            localName: name.text,
                            color: color.text.trim().isEmpty
                                ? null
                                : color.text.trim(),
                            refreshMode: mode,
                          );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } on Object catch (failure) {
                      if (context.mounted) {
                        setDialogState(
                          () => error = context.l10n
                              .subscriptionOperationFailed('$failure'),
                        );
                      }
                    }
                  },
                  child: Text(context.l10n.addSubscriptionAction),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      url.dispose();
      name.dispose();
      color.dispose();
    }
  }

  Future<void> _subscriptionAction(
    WebCalSubscriptionEntity subscription,
    String action,
  ) => _AndroidSourceActions(
    context,
    ref,
  )._subscriptionAction(subscription, action);

  Future<void> _resolveConflict(DavConflictEntity conflict) async {
    final l10n = context.l10n;
    final resolution = await showModalBottomSheet<DavConflictResolution>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(context.l10n.syncConflicts),
                subtitle: Text(conflict.itemTitle),
              ),
              if (conflict.canKeepServer)
                ListTile(
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: Text(context.l10n.keepServerVersion),
                  onTap: () =>
                      Navigator.pop(context, DavConflictResolution.keepServer),
                ),
              if (conflict.canReapplyLocal)
                ListTile(
                  leading: const Icon(Icons.redo),
                  title: Text(context.l10n.reapplyLocalChange),
                  onTap: () => Navigator.pop(
                    context,
                    DavConflictResolution.reapplyLocal,
                  ),
                ),
              if (conflict.canDuplicate)
                ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: Text(context.l10n.duplicateLocalItem),
                  onTap: () => Navigator.pop(
                    context,
                    DavConflictResolution.duplicateLocal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (resolution == null || !mounted) {
      return;
    }
    final needsConsent =
        resolution == DavConflictResolution.duplicateLocal &&
        conflict.duplicationRequiresSchedulingConsent;
    if (needsConsent) {
      final allowed = await _confirm(
        l10n.duplicateLocalItem,
        l10n.caldavConflictDuplicationSchedulingWarning,
        l10n.duplicateLocalItem,
      );
      if (!allowed || !mounted) {
        return;
      }
    }
    try {
      await ref
          .read(davConflictResolutionServiceProvider)
          .resolve(conflict.id, resolution, allowScheduling: needsConsent);
      await ref.read(signedInSyncRunnerProvider)(conflict.accountId, false);
    } on Object {
      _message(l10n.conflictResolutionFailed);
    }
  }

  Future<void> _setNotificationSetting(
    bool enabled,
    Future<void> Function(bool) save,
  ) async {
    if (enabled) {
      final granted = await ref
          .read(androidNotificationServiceProvider)
          .requestNotificationPermission();
      if (!granted && mounted) {
        _message(context.l10n.notificationsBlocked);
      }
    }
    await save(enabled);
    await ref.read(notificationReconcilerProvider).reconcile();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _requestExactAlarms() async {
    await ref
        .read(androidNotificationServiceProvider)
        .requestExactAlarmPermission();
    await ref.read(notificationReconcilerProvider).reconcile();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickSummaryTime() async {
    final parts = ref
        .read(appSettingsControllerProvider)
        .dueTodayNotificationTime
        .split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (selected == null) {
      return;
    }
    await ref
        .read(appSettingsControllerProvider.notifier)
        .setDueTodayNotificationTime(
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
        );
    await ref.read(notificationReconcilerProvider).reconcile();
  }

  Future<void> _pickQuietTime(bool start) async {
    final settings = ref.read(appSettingsControllerProvider);
    final raw = start ? settings.quietHoursStart : settings.quietHoursEnd;
    final parts = raw.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 0,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    if (picked == null) {
      return;
    }
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final controller = ref.read(appSettingsControllerProvider.notifier);
    if (start) {
      await controller.setQuietHoursStart(value);
    } else {
      await controller.setQuietHoursEnd(value);
    }
    await ref.read(notificationReconcilerProvider).reconcile();
  }

  Future<void> _openConfiguredLink(String kind) async {
    final config = ref.read(buildConfigProvider);
    final raw = switch (kind) {
      'privacy' => config.privacyPolicyUrl,
      'support' => config.supportUrl,
      _ => config.homepageUrl,
    };
    final uri = Uri.tryParse(raw);
    if (uri != null) {
      await BusyMaxAndroidPlatform.instance.launchExternalUri(uri);
    }
  }

  Future<String?> _textPrompt({
    required String title,
    required String label,
    String? initialValue,
    String? helper,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _AndroidTextPromptDialog(
        title: title,
        label: label,
        initialValue: initialValue,
        helper: helper,
      ),
    );
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  void _message(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AndroidTextPromptDialog extends StatefulWidget {
  const _AndroidTextPromptDialog({
    required this.title,
    required this.label,
    this.initialValue,
    this.helper,
  });

  final String title;
  final String label;
  final String? initialValue;
  final String? helper;

  @override
  State<_AndroidTextPromptDialog> createState() =>
      _AndroidTextPromptDialogState();
}

class _AndroidTextPromptDialogState extends State<_AndroidTextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.pop(context, text);
            }
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

class _AndroidAppleCredentialsDialog extends StatefulWidget {
  const _AndroidAppleCredentialsDialog({this.fixedEmail});

  final String? fixedEmail;

  @override
  State<_AndroidAppleCredentialsDialog> createState() =>
      _AndroidAppleCredentialsDialogState();
}

class _AndroidAppleCredentialsDialogState
    extends State<_AndroidAppleCredentialsDialog> {
  late final TextEditingController _email = TextEditingController(
    text: widget.fixedEmail,
  );
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.connectAppleICloudTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            enabled: widget.fixedEmail == null,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.l10n.appleAccountEmail,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.l10n.appleAppSpecificPassword,
              helperText: context.l10n.appleAppSpecificPasswordHelp,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _email.text.trim().isEmpty || _password.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (
                  _email.text.trim(),
                  _password.text.trim(),
                )),
          child: Text(context.l10n.connectAccountAction),
        ),
      ],
    );
  }
}

class AndroidNextcloudSharingScreen extends ConsumerStatefulWidget {
  const AndroidNextcloudSharingScreen({
    super.key,
    required this.accountId,
    required this.collectionId,
    required this.title,
  });

  final String accountId;
  final String collectionId;
  final String title;

  @override
  ConsumerState<AndroidNextcloudSharingScreen> createState() =>
      _AndroidNextcloudSharingScreenState();
}

class _AndroidNextcloudSharingScreenState
    extends ConsumerState<AndroidNextcloudSharingScreen> {
  final _search = TextEditingController();
  late final _model = NextcloudCollectionController(
    ref.read(nextcloudSharingServiceProvider(widget.accountId)),
    widget.collectionId,
  );

  bool get _canChange => !_model.busy && !_model.refreshPending;

  @override
  void initState() {
    super.initState();
    _model.addListener(_changed);
    unawaited(_model.load());
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _search.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _findRecipients() async {
    final query = _search.text.trim();
    if (_canChange && query.isNotEmpty) await _model.search(query);
  }

  Future<void> _changeShare(
    NextcloudShareRecipient recipient,
    bool? writable, {
    bool fromSearch = false,
  }) async {
    if (!_canChange ||
        _model.state?.canShare != true ||
        (fromSearch && !_model.recipients.contains(recipient))) {
      return;
    }
    await _model.share(recipient, writable);
    if (mounted && !_model.failed) _search.clear();
  }

  Future<void> _setPublished(bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.nextcloudPublish),
          content: Text(context.l10n.nextcloudPublishWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.nextcloudPublish),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    if (!mounted || !_canChange || _model.state?.canPublish != true) return;
    await _model.publish(value);
  }

  @override
  Widget build(BuildContext context) {
    final state = _model.state;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _model.busy && state == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _model.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_model.error case final error?)
                    ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text(context.l10n.operationFailed),
                      subtitle: Text(
                        localizedNextcloudCollectionError(context.l10n, error),
                      ),
                    ),
                  if (_model.refreshPending)
                    ListTile(title: Text(context.l10n.nextcloudRefreshPending)),
                  if (state?.canPublish ?? false)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.public),
                      title: Text(
                        state!.publishUrl == null
                            ? context.l10n.nextcloudPublish
                            : context.l10n.nextcloudUnpublish,
                      ),
                      subtitle: state.publishUrl == null
                          ? null
                          : SelectableText(state.publishUrl.toString()),
                      value: state.publishUrl != null,
                      onChanged: _canChange ? _setPublished : null,
                    ),
                  if (state?.canShare ?? false) ...[
                    TextField(
                      controller: _search,
                      enabled: _canChange,
                      onChanged: (_) => _model.clearSearch(),
                      decoration: InputDecoration(
                        labelText: context.l10n.nextcloudRecipientSearch,
                        suffixIcon: IconButton(
                          onPressed: _canChange ? _findRecipients : null,
                          icon: const Icon(Icons.search),
                        ),
                      ),
                      onSubmitted: (_) => unawaited(_findRecipients()),
                    ),
                    if (_model.searching) const LinearProgressIndicator(),
                    for (final recipient in _model.recipients)
                      ListTile(
                        leading: Icon(
                          recipient.group ? Icons.groups : Icons.person_outline,
                        ),
                        title: Text(recipient.label),
                        trailing: PopupMenuButton<bool>(
                          enabled: _canChange,
                          onSelected: (value) => unawaited(
                            _changeShare(recipient, value, fromSearch: true),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: false,
                              child: Text(context.l10n.nextcloudReadAccess),
                            ),
                            PopupMenuItem(
                              value: true,
                              child: Text(context.l10n.nextcloudWriteAccess),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const Divider(height: 32),
                  for (final share
                      in state?.shares ?? const <NextcloudCollectionShare>[])
                    ListTile(
                      leading: Icon(
                        share.recipient.group
                            ? Icons.groups
                            : Icons.person_outline,
                      ),
                      title: Text(share.recipient.label),
                      subtitle: Text(
                        share.recipient.federated
                            ? context.l10n.nextcloudFederationGrant
                            : share.writable
                            ? context.l10n.nextcloudWriteAccess
                            : context.l10n.nextcloudReadAccess,
                      ),
                      trailing: PopupMenuButton<String>(
                        enabled: _canChange && state?.canShare == true,
                        onSelected: (value) => unawaited(
                          _changeShare(share.recipient, switch (value) {
                            'read' => false,
                            'write' => true,
                            _ => null,
                          }),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'read',
                            child: Text(context.l10n.nextcloudReadAccess),
                          ),
                          PopupMenuItem(
                            value: 'write',
                            child: Text(context.l10n.nextcloudWriteAccess),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(context.l10n.nextcloudRevokeShare),
                          ),
                        ],
                      ),
                    ),
                  if (state != null &&
                      state.shares.isEmpty &&
                      _model.recipients.isEmpty)
                    ListTile(title: Text(context.l10n.nextcloudNoRecipients)),
                  if (_model.busy)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
    );
  }
}

class AndroidNextcloudTrashScreen extends ConsumerStatefulWidget {
  const AndroidNextcloudTrashScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AndroidNextcloudTrashScreen> createState() =>
      _AndroidNextcloudTrashScreenState();
}

class _AndroidNextcloudTrashScreenState
    extends ConsumerState<AndroidNextcloudTrashScreen> {
  late final _session = NextcloudTrashSession(
    ref.read(nextcloudTrashServiceProvider(widget.accountId)),
  );

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    unawaited(_session.load());
  }

  void _onSessionChanged() => setState(() {});

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  Future<void> _act(NextcloudTrashItem item, {required bool permanent}) async {
    if (permanent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.nextcloudPermanentDelete),
          content: Text(context.l10n.nextcloudPermanentDeleteWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.nextcloudPermanentDelete),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    if (!mounted) return;
    await _session.mutate(item, permanent: permanent);
  }

  @override
  Widget build(BuildContext context) {
    final items = _session.listing?.items ?? const <NextcloudTrashItem>[];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nextcloudTrash)),
      body: RefreshIndicator(
        onRefresh: _session.load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                children: [
                  if (_session.error != null)
                    ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text(context.l10n.operationFailed),
                      subtitle: Text(
                        localizedNextcloudCollectionError(
                          context.l10n,
                          _session.error,
                        ),
                      ),
                    ),
                  if (_session.refreshPending)
                    ListTile(title: Text(context.l10n.nextcloudRefreshPending)),
                  if (_session.listing?.retentionSeconds case final seconds?)
                    ListTile(
                      title: Text(
                        seconds == 0
                            ? context.l10n.nextcloudTrashDisabled
                            : context.l10n.nextcloudTrashRetention(
                                (seconds / 86400).ceil(),
                              ),
                      ),
                    ),
                  if (!_session.busy && items.isEmpty && _session.error == null)
                    ListTile(title: Text(context.l10n.nextcloudTrashEmpty)),
                  if (_session.busy) const LinearProgressIndicator(),
                ],
              );
            }
            final item = items[index - 1];
            return ListTile(
              leading: Icon(switch (item.kind) {
                NextcloudTrashKind.unknownObject => Icons.description_outlined,
                NextcloudTrashKind.event => Icons.event_outlined,
                NextcloudTrashKind.task => Icons.task_alt_outlined,
                NextcloudTrashKind.calendar => Icons.calendar_month_outlined,
                NextcloudTrashKind.taskList => Icons.checklist_outlined,
                NextcloudTrashKind.mixedCollection =>
                  Icons.folder_copy_outlined,
              }),
              title: Text(item.title),
              subtitle: _session.loadingDetails(item.href)
                  ? const LinearProgressIndicator()
                  : item.deletedAt == null
                  ? null
                  : Text(item.deletedAt!),
              trailing: PopupMenuButton<String>(
                key: ValueKey(('nextcloud-trash-menu', item.href.toString())),
                onSelected: (value) => unawaited(
                  value == 'details'
                      ? _session.details(item)
                      : _act(item, permanent: value == 'delete'),
                ),
                enabled: !_session.busy,
                itemBuilder: (context) => [
                  if (item.isObject && !item.contentLoaded)
                    PopupMenuItem(
                      value: 'details',
                      enabled: !_session.loadingDetails(item.href),
                      child: Text(context.l10n.show),
                    ),
                  if (_session.canMutate && item.canRestore)
                    PopupMenuItem(
                      value: 'restore',
                      child: Text(context.l10n.nextcloudRestore),
                    ),
                  if (_session.canMutate && item.canPermanentlyDelete)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.l10n.nextcloudPermanentDelete),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AndroidAccountSyncStatus extends ConsumerWidget {
  const _AndroidAccountSyncStatus({
    required this.account,
    required this.onRefresh,
  });
  final AccountEntity account;
  final ValueChanged<bool> onRefresh;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(accountSyncActivityProvider);
    final times = ref.watch(accountDomainSyncTimesProvider(account.id));
    final collections = ref.watch(davCollectionsStreamProvider);
    final discovery = account.provider.isDav
        ? ref.watch(davAccountDiscoveryProvider(account.id))
        : null;
    Widget domain(bool calendar) {
      final name = calendar ? 'calendar' : 'tasks';
      final selected = collections.valueOrNull
          ?.where(
            (c) =>
                c.accountId == account.id &&
                (calendar
                    ? c.supportsEvents && c.eventsSelected
                    : c.supportsTasks && c.tasksSelected),
          )
          .toList();
      var last = times.valueOrNull?[name];
      if (account.provider.isDav &&
          selected?.isNotEmpty == true &&
          selected!.every((c) => c.lastSyncAtUtc != null)) {
        last = selected
            .map((c) => c.lastSyncAtUtc!)
            .reduce((a, b) => a.isBefore(b) ? a : b);
      }
      final running = activity.isRunning(
        account.id,
        account.provider.isDav ? 'dav' : name,
      );
      final error = activity.failure(
        account.id,
        account.provider.isDav ? 'dav' : name,
      );
      final failed =
          times.hasError || collections.hasError || discovery?.hasError == true;
      final loading = account.provider.isDav
          ? collections.isLoading || discovery?.isLoading == true
          : times.isLoading;
      final collectionError =
          discovery?.valueOrNull?.lastDiscoveryErrorCode != null ||
          selected?.any((c) => c.syncErrorCode != null) == true;
      final sourceUnavailable =
          calendar &&
          (ref.watch(calendarSourcesStreamProvider).valueOrNull ?? []).any(
            (s) => s.accountId == account.id && s.accessRole == 'unavailable',
          );
      final status = running
          ? context.l10n.traySyncing
          : error != null
          ? syncFailureMessage(
              error,
              networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
            )
          : failed
          ? context.l10n.collectionsLoadFailed
          : collectionError || sourceUnavailable
          ? context.l10n.cachedSyncError
          : loading
          ? context.l10n.collectionsLoading
          : last == null
          ? context.l10n.syncNoRecord
          : null;
      return ListTile(
        title: Text(
          calendar ? context.l10n.calendarContent : context.l10n.taskContent,
        ),
        subtitle: Text(
          [
            if (status != null) status,
            if (last != null)
              context.l10n.davLastSuccessfulSync(
                DateFormat.yMd().add_Hm().format(last.toLocal()),
              ),
          ].join('\n'),
        ),
        leading: Icon(
          error != null || failed || collectionError || sourceUnavailable
              ? Icons.warning_amber
              : calendar
              ? Icons.calendar_month
              : Icons.checklist,
        ),
        trailing: IconButton(
          tooltip: calendar
              ? context.l10n.refreshCalendar
              : context.l10n.refreshList,
          onPressed: !account.isSyncEligible || running
              ? null
              : () => onRefresh(calendar),
          icon: const Icon(Icons.refresh),
        ),
      );
    }

    return Column(
      children: [
        if (account.calendarsEnabled) domain(true),
        if (account.tasksEnabled) domain(false),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ...children,
        ],
      ),
    ),
  );
}

class _AccountButtons extends StatelessWidget {
  const _AccountButtons({required this.connecting, required this.onConnect});
  final BusyProvider? connecting;
  final ValueChanged<BusyProvider> onConnect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _button(
          context,
          BusyProvider.nextcloud,
          context.l10n.addNextcloudAccount,
        ),
        _button(context, BusyProvider.caldav, context.l10n.addCalDavAccount),
        _button(context, BusyProvider.google, context.l10n.addGoogleAccount),
        _button(
          context,
          BusyProvider.microsoft,
          context.l10n.addMicrosoftAccount,
        ),
        _button(
          context,
          BusyProvider.appleICloud,
          context.l10n.addAppleICloudAccount,
        ),
      ],
    ),
  );

  Widget _button(BuildContext context, BusyProvider provider, String label) =>
      FutureBuilder<bool>(
        future: switch (provider) {
          BusyProvider.google =>
            BusyMaxAndroidPlatform.instance.googleAuthorizationAvailable(),
          BusyProvider.microsoft =>
            BusyMaxAndroidPlatform.instance.microsoftAuthorizationAvailable(),
          _ => Future.value(true),
        },
        builder: (context, snapshot) {
          final available = snapshot.data ?? false;
          return OutlinedButton.icon(
            onPressed: connecting == null && available
                ? () => onConnect(provider)
                : null,
            icon: connecting == provider
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_providerIcon(provider)),
            label: Text(label),
          );
        },
      );
}

class _NotificationSwitch extends StatelessWidget {
  const _NotificationSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: const Icon(Icons.notifications_outlined),
    title: Text(title),
    value: value,
    onChanged: onChanged,
  );
}

IconData _providerIcon(BusyProvider provider) => switch (provider) {
  BusyProvider.google => Icons.g_mobiledata,
  BusyProvider.microsoft => Icons.window,
  BusyProvider.appleICloud => Icons.cloud_outlined,
  BusyProvider.nextcloud => Icons.cloud_sync_outlined,
  BusyProvider.webCal => Icons.public,
  BusyProvider.caldav => Icons.calendar_month_outlined,
};

Color _colorFromHex(String value) =>
    Color(0xff000000 | int.parse(value.replaceFirst('#', ''), radix: 16));

Future<void> showAndroidIcsImport(
  BuildContext context,
  WidgetRef ref, {
  AndroidDocument? document,
}) async {
  try {
    final selected =
        document ??
        await BusyMaxAndroidPlatform.instance.openDocument(
          maximumBytes: icalIngestionDecodedBodyLimit,
        );
    if (selected == null || !context.mounted) {
      return;
    }
    final service = ref.read(icalImportServiceProvider);
    final preview = service.parsePreview(selected.bytes);
    final destinations = await service.writableDestinations();
    if (!context.mounted) {
      return;
    }
    final session = IcalImportSession(preview, destinations);
    final selection = await showDialog<IcalImportSelection>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.importIcsPreview),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  session.native
                      ? context.l10n.nextcloudImportItems(
                          preview.nativePreview.resources.length,
                        )
                      : context.l10n.importEventsFound(preview.eventCount),
                ),
                if (session.native) ...[
                  Text(
                    session.destination?.provider == BusyProvider.nextcloud
                        ? context.l10n.nextcloudNativeImport
                        : context.l10n.caldavNativeImport,
                  ),
                  if (preview.nativePreview.schedulingMethod != null)
                    Text(context.l10n.nextcloudImportMethod),
                ] else if (preview.fieldsThatWillBeOmitted.isNotEmpty)
                  Text(
                    context.l10n.importFieldsOmitted(
                      (preview.fieldsThatWillBeOmitted.toList()..sort()).join(
                        ', ',
                      ),
                    ),
                  ),
                if (preview.invalidEventCount > 0)
                  Text(
                    context.l10n.importInvalidEvents(preview.invalidEventCount),
                  ),
                const SizedBox(height: 16),
                if (destinations.isEmpty)
                  Text(context.l10n.noWritableCalendars)
                else
                  DropdownButtonFormField<CalendarSourceEntity>(
                    isExpanded: true,
                    initialValue: session.destination,
                    decoration: InputDecoration(
                      labelText: context.l10n.importDestinationCalendar,
                    ),
                    items: [
                      for (final source in destinations)
                        DropdownMenuItem(
                          value: source,
                          child: Text(
                            '${source.summary} · ${source.authenticatedAccountEmail ?? source.accountId}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      session.destination = value;
                    }),
                  ),
                if (session.schedulingConsentRequired)
                  CheckboxListTile(
                    key: const ValueKey('caldav-import-scheduling-consent'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.caldavImportSchedulingWarning),
                    value: session.allowScheduling,
                    onChanged: (value) => setDialogState(
                      () => session.allowScheduling = value == true,
                    ),
                  ),
                if (session.native)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.nextcloudImportCopies),
                    value: session.newCopies,
                    onChanged: (value) =>
                        setDialogState(() => session.newCopies = value == true),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: session.selection == null
                  ? null
                  : () => Navigator.pop(dialogContext, session.selection),
              child: Text(context.l10n.importIcsConfirm),
            ),
          ],
        ),
      ),
    );
    if (selection == null || !context.mounted) {
      return;
    }
    final report = await service.importSelection(preview, selection);
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.importIcsComplete),
        content: Text(localizedIcalImportReport(context.l10n, report)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  } on Object catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.importIcsFailed('$error'))),
    );
  }
}

class _AndroidRegistrationCard extends ConsumerWidget {
  const _AndroidRegistrationCard({
    required this.account,
    required this.onMigrate,
  });
  final AccountEntity account;
  final VoidCallback onMigrate;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref
        .watch(registrationSummariesProvider)
        .valueOrNull?[account.id];
    if (summary == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(l10n.registrationDescription(summary)),
            if (summary.showRetirementNotice) ...[
              Text(
                l10n.registrationRetirementNotice(
                  account.provider.displayName,
                  l10n.registrationMicrosoftApp,
                ),
              ),
              Text(l10n.registrationContinue),
            ],
            if (account.provider == BusyProvider.microsoft)
              TextButton(
                onPressed: onMigrate,
                child: Text(
                  summary.showRetirementNotice
                      ? l10n.registrationMigrate
                      : l10n.registrationReplace,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AndroidNextcloudFederationScreen extends ConsumerStatefulWidget {
  const AndroidNextcloudFederationScreen({super.key, required this.accountId});
  final String accountId;
  @override
  ConsumerState<AndroidNextcloudFederationScreen> createState() =>
      _AndroidNextcloudFederationScreenState();
}

class _AndroidNextcloudFederationScreenState
    extends ConsumerState<AndroidNextcloudFederationScreen> {
  late final NextcloudFederationController model;
  @override
  void initState() {
    super.initState();
    model = NextcloudFederationController(
      ref.read(nextcloudFederationServiceProvider(widget.accountId)),
    )..addListener(_changed);
    unawaited(model.load());
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = !model.busy && model.error == null && !model.refreshPending;
    return PopScope(
      canPop: !model.busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.nextcloudFederationInvitations),
          actions: [
            IconButton(
              tooltip: l10n.refresh,
              onPressed: model.busy ? null : model.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: model.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (model.busy) const LinearProgressIndicator(),
              if (model.error != null)
                ListTile(
                  title: Text(
                    localizedNextcloudCollectionError(l10n, model.error),
                  ),
                ),
              if (model.refreshPending)
                ListTile(title: Text(l10n.nextcloudRefreshPending)),
              if (model.invitations?.isEmpty == true)
                ListTile(title: Text(l10n.nextcloudFederationEmpty)),
              for (final invitation in model.invitations ?? [])
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(invitation.displayName),
                        subtitle: Text(invitation.sharedBy),
                      ),
                      OverflowBar(
                        children: [
                          FilledButton(
                            key: ValueKey(
                              'nextcloud-federation-accept-${invitation.id}',
                            ),
                            onPressed: enabled
                                ? () => model.respond(invitation, accept: true)
                                : null,
                            child: Text(l10n.acceptInvitation),
                          ),
                          TextButton(
                            key: ValueKey(
                              'nextcloud-federation-decline-${invitation.id}',
                            ),
                            onPressed: enabled
                                ? () => model.respond(invitation, accept: false)
                                : null,
                            child: Text(l10n.declineInvitation),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _scheduleMinuteLabel(BuildContext context, int value) => value == 1440
    ? '24:00'
    : BusyMaxTimeFormatScope.of(context)
          .format(DateTime(2026, 1, 1, value ~/ 60, value % 60));
