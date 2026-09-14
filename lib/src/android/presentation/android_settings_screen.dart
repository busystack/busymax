import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/app_bootstrap.dart';
import '../../calendar_providers/calendar_colors.dart';
import '../../core/auth/oauth_models.dart';
import '../../dav/dav_errors.dart';
import '../../dav/mutation/dav_conflict_repository.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/accounts/domain/account_collection_creation_capabilities.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/task_lists/data/task_lists_repository.dart';
import '../../features/tasks/domain/task_capabilities.dart';
import '../../ical/ical_import_service.dart';
import '../../ical/ical_ingestion.dart';
import '../../l10n/app_locale.dart';
import '../../l10n/l10n.dart';
import '../../providers/busy_provider.dart';
import '../../webcal/webcal_subscription_service.dart';
import '../android_background.dart';
import '../android_notifications.dart';

class AndroidSettingsScreen extends ConsumerStatefulWidget {
  const AndroidSettingsScreen({super.key});

  @override
  ConsumerState<AndroidSettingsScreen> createState() =>
      _AndroidSettingsScreenState();
}

class _AndroidSettingsScreenState extends ConsumerState<AndroidSettingsScreen> {
  bool _syncing = false;
  BusyProvider? _connecting;
  final _removing = <String>{};

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountManagementStreamProvider).valueOrNull ?? const [];
    final sources =
        ref.watch(calendarSourcesStreamProvider).valueOrNull ?? const [];
    final lists = ref.watch(scheduleTaskListsProvider).valueOrNull ?? const [];
    final subscriptions =
        ref.watch(webCalSubscriptionsProvider).valueOrNull ?? const [];
    final conflicts =
        ref.watch(davConflictsStreamProvider).valueOrNull ?? const [];
    final settings = ref.watch(appSettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          _Section(
            title: context.l10n.accounts,
            children: [
              if (accounts.isEmpty)
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(context.l10n.providerConnectionDescription),
                ),
              for (final account in accounts)
                ListTile(
                  leading: Icon(_providerIcon(account.provider)),
                  title: Text(account.displayLabel),
                  subtitle: Text(_accountSubtitle(account)),
                  trailing: _removing.contains(account.id)
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'sync') {
                              unawaited(_syncAccount(account.id));
                            } else if (value == 'reconnect') {
                              unawaited(_connect(account.provider, account));
                            } else if (value == 'remove') {
                              unawaited(_removeAccount(account));
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'sync',
                              child: Text(context.l10n.sync),
                            ),
                            if (account.needsReconnect)
                              PopupMenuItem(
                                value: 'reconnect',
                                child: Text(context.l10n.connectAccountAction),
                              ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(context.l10n.removeAccount),
                            ),
                          ],
                        ),
                ),
              const Divider(height: 1),
              _AccountButtons(
                connecting: _connecting,
                onConnect: (provider) => unawaited(_connect(provider)),
              ),
            ],
          ),
          _Section(
            title: context.l10n.collectionSettings,
            children: [
              if (accounts.any(
                (account) =>
                    account.isSignedIn &&
                    account.calendarsEnabled &&
                    accountCollectionCreationModes(
                          account.provider,
                        ).calendarMode !=
                        CalendarCollectionCreationMode.unavailable,
              ))
                ListTile(
                  leading: const Icon(Icons.add_box_outlined),
                  title: Text(context.l10n.newCalendar),
                  onTap: () =>
                      unawaited(_createCollection(accounts, calendar: true)),
                ),
              if (accounts.any(
                (account) =>
                    account.isSignedIn &&
                    account.tasksEnabled &&
                    accountCollectionCreationModes(
                          account.provider,
                        ).taskListMode !=
                        TaskListCreationMode.unavailable,
              ))
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: Text(context.l10n.newTaskList),
                  onTap: () =>
                      unawaited(_createCollection(accounts, calendar: false)),
                ),
              if (sources.isEmpty && lists.isEmpty)
                ListTile(title: Text(context.l10n.noCalendarsSynced)),
              for (final source in sources)
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(source.summary),
                  subtitle: Text(source.provider.displayName),
                  trailing: Switch(
                    value: source.selected,
                    onChanged: (value) => unawaited(
                      ref
                          .read(calendarRepositoryProvider)
                          .setSourceSelected(source.id, value),
                    ),
                  ),
                  onTap: () => unawaited(_editCalendarSource(source)),
                ),
              for (final list in lists)
                ListTile(
                  leading: const Icon(Icons.checklist_outlined),
                  title: Text(list.title),
                  subtitle: Text(context.l10n.showInSchedule),
                  trailing: Switch(
                    value: settings.isTaskListVisibleInSchedule(
                      list.accountId,
                      list.id,
                    ),
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
                  onTap: () => unawaited(_editTaskList(list, accounts)),
                ),
            ],
          ),
          _Section(
            title: context.l10n.calendarSubscriptions,
            children: [
              ListTile(
                leading: const Icon(Icons.add_link),
                title: Text(context.l10n.addCalendarSubscription),
                subtitle: Text(context.l10n.calendarSubscriptionsDescription),
                onTap: () => unawaited(_addSubscription()),
              ),
              for (final subscription in subscriptions)
                ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(subscription.name),
                  subtitle: Text(
                    subscription.lastFailureCode == null
                        ? context.l10n.subscriptionSafeOrigin(
                            subscription.safeOrigin,
                          )
                        : context.l10n.subscriptionStatusIssue(
                            subscription.lastFailureCode!,
                          ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        unawaited(_subscriptionAction(subscription, value)),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'refresh',
                        child: Text(context.l10n.refreshNow),
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
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: Text(context.l10n.importIcsFile),
                subtitle: Text(context.l10n.calendarImportDescription),
                onTap: () => unawaited(showAndroidIcsImport(context, ref)),
              ),
            ],
          ),
          _Section(
            title: context.l10n.appearance,
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(context.l10n.theme),
                trailing: DropdownButton<BusyMaxThemeModePreference>(
                  value: settings.themeModePreference,
                  onChanged: (value) {
                    if (value != null) {
                      unawaited(
                        ref
                            .read(appSettingsControllerProvider.notifier)
                            .setThemeModePreference(value),
                      );
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: BusyMaxThemeModePreference.system,
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
                trailing: DropdownButton<String>(
                  value: settings.localeTag ?? 'system',
                  onChanged: (value) => unawaited(
                    ref
                        .read(appSettingsControllerProvider.notifier)
                        .setLocaleTag(value == 'system' ? null : value),
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
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(context.l10n.timeFormat),
                trailing: DropdownButton<BusyMaxTimeFormatPreference>(
                  value: settings.timeFormatPreference,
                  onChanged: (value) {
                    if (value != null) {
                      unawaited(
                        ref
                            .read(appSettingsControllerProvider.notifier)
                            .setTimeFormatPreference(value),
                      );
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: BusyMaxTimeFormatPreference.system,
                      child: Text(context.l10n.themeSystem),
                    ),
                    DropdownMenuItem(
                      value: BusyMaxTimeFormatPreference.twelveHour,
                      child: Text(context.l10n.timeFormatTwelveHour),
                    ),
                    DropdownMenuItem(
                      value: BusyMaxTimeFormatPreference.twentyFourHour,
                      child: Text(context.l10n.timeFormatTwentyFourHour),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _Section(
            title: context.l10n.notifications,
            children: [
              _NotificationSwitch(
                title: context.l10n.eventReminders,
                value: settings.notifyEventReminders,
                onChanged: (value) => _setNotificationSetting(
                  value,
                  ref
                      .read(appSettingsControllerProvider.notifier)
                      .setNotifyEventReminders,
                ),
              ),
              _NotificationSwitch(
                title: context.l10n.taskReminders,
                value: settings.notifyTaskReminders,
                onChanged: (value) => _setNotificationSetting(
                  value,
                  ref
                      .read(appSettingsControllerProvider.notifier)
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
                        .read(appSettingsControllerProvider.notifier)
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
                      .read(appSettingsControllerProvider.notifier)
                      .setNotifySyncFailures,
                ),
              ),
              _NotificationSwitch(
                title: context.l10n.notifyConflicts,
                value: settings.notifyConflicts,
                onChanged: (value) => _setNotificationSetting(
                  value,
                  ref
                      .read(appSettingsControllerProvider.notifier)
                      .setNotifyConflicts,
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined),
                title: Text(context.l10n.notificationDetailLevel),
                subtitle: Text(context.l10n.notificationDetailPrivate),
                value:
                    settings.notificationDetailLevel ==
                    NotificationDetailLevel.private,
                onChanged: (value) => unawaited(
                  ref
                      .read(appSettingsControllerProvider.notifier)
                      .setNotificationDetailLevel(
                        value
                            ? NotificationDetailLevel.private
                            : NotificationDetailLevel.normal,
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.alarm),
                title: Text(context.l10n.reminders),
                subtitle: Text(
                  ref
                      .read(androidNotificationServiceProvider)
                      .precisionDiagnostic,
                ),
                trailing: TextButton(
                  onPressed: () => unawaited(_requestExactAlarms()),
                  child: Text(context.l10n.settingsSystem),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.bedtime_outlined),
                title: Text(context.l10n.quietHours),
                subtitle: Text(context.l10n.quietHoursDescription),
                value: settings.quietHoursEnabled,
                onChanged: (value) => unawaited(
                  ref
                      .read(appSettingsControllerProvider.notifier)
                      .setQuietHoursEnabled(value)
                      .then(
                        (_) => ref
                            .read(notificationReconcilerProvider)
                            .reconcile(),
                      ),
                ),
              ),
              if (settings.quietHoursEnabled) ...[
                ListTile(
                  leading: const Icon(Icons.nights_stay_outlined),
                  title: Text(context.l10n.quietHoursStart),
                  trailing: Text(settings.quietHoursStart),
                  onTap: () => unawaited(_pickQuietTime(true)),
                ),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: Text(context.l10n.quietHoursEnd),
                  trailing: Text(settings.quietHoursEnd),
                  onTap: () => unawaited(_pickQuietTime(false)),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(context.l10n.notifications),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => unawaited(
                  BusyMaxAndroidPlatform.instance.openNotificationSettings(),
                ),
              ),
            ],
          ),
          _Section(
            title: context.l10n.sync,
            children: [
              ListTile(
                leading: _syncing
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                title: Text(context.l10n.sync),
                subtitle: Text(context.l10n.davCachedOfflineNotice),
                enabled: !_syncing,
                onTap: _syncing ? null : () => unawaited(_syncAll()),
              ),
              ListTile(
                leading: const Icon(Icons.battery_saver_outlined),
                title: Text(context.l10n.runInBackgroundWhenClosed),
                subtitle: Text(context.l10n.launchAtLoginDescription),
                onTap: () => unawaited(enqueueImmediateBusyMaxSync()),
              ),
            ],
          ),
          _Section(
            title: context.l10n.syncConflicts,
            children: [
              if (conflicts.isEmpty)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(context.l10n.noBlockedPendingOperations),
                ),
              for (final conflict in conflicts)
                ListTile(
                  leading: const Icon(Icons.warning_amber),
                  title: Text(conflict.itemTitle),
                  subtitle: Text(
                    '${conflict.accountLabel} · ${conflict.collectionName}\n${conflict.localEditSummary}',
                  ),
                  isThreeLine: true,
                  onTap: () => unawaited(_resolveConflict(conflict)),
                ),
            ],
          ),
          _Section(
            title: context.l10n.privacy,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.shield_outlined),
                title: Text(context.l10n.redactTaskContentInDiagnostics),
                value: settings.redactTaskContentInDiagnostics,
                onChanged: (value) => unawaited(
                  ref
                      .read(appSettingsControllerProvider.notifier)
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
                onTap: () => unawaited(_openConfiguredLink('privacy')),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: Text(context.l10n.website),
                enabled: ref.read(buildConfigProvider).supportUrl.isNotEmpty,
                onTap: () => unawaited(_openConfiguredLink('support')),
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(context.l10n.website),
                onTap: () => unawaited(_openConfiguredLink('homepage')),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.l10n.aboutBusyMax),
                subtitle: Text(context.l10n.aboutBusyMaxDescription),
                onTap: _showAbout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _accountSubtitle(AccountEntity account) {
    final state = account.isSignedIn
        ? context.l10n.signedInAccount
        : account.authState;
    final synced = account.lastSuccessfulSyncAtUtc;
    return synced == null
        ? '${account.provider.displayName} · $state'
        : '${account.provider.displayName} · $state\n${context.l10n.davLastSuccessfulSync(DateFormat.yMd().add_jm().format(synced.toLocal()))}';
  }

  Future<void> _connect(
    BusyProvider provider, [
    AccountEntity? reconnecting,
  ]) async {
    if (_connecting != null) return;
    String? email;
    String? password;
    String? server;
    if (provider == BusyProvider.appleICloud) {
      final input = await _appleCredentials(reconnecting?.email);
      if (input == null) return;
      (email, password) = input;
    } else if (provider == BusyProvider.nextcloud) {
      server = await _textPrompt(
        title: context.l10n.connectNextcloudTitle,
        label: context.l10n.nextcloudServerUrl,
        initialValue: reconnecting?.authority,
        helper: context.l10n.nextcloudBrowserAuthorizationHelp,
      );
      if (server == null) return;
      final uri = Uri.tryParse(server);
      if (uri != null && _isLocalHost(uri.host)) {
        await BusyMaxAndroidPlatform.instance.requestLocalNetworkAccess();
      }
    }
    setState(() => _connecting = provider);
    try {
      String? accountId;
      switch (provider) {
        case BusyProvider.google:
          accountId =
              (await ref.read(authRepositoryProvider).signIn()).accountId;
        case BusyProvider.microsoft:
          accountId =
              (await ref.read(authRepositoryProvider).signInWithMicrosoft())
                  .accountId;
        case BusyProvider.appleICloud:
          final service = ref.read(davAccountOnboardingServiceProvider);
          accountId = reconnecting == null
              ? (await service.connectAppleICloud(
                  email: email!,
                  appSpecificPassword: password!,
                )).accountId
              : (await service.replaceAppleAppSpecificPassword(
                  accountId: reconnecting.id,
                  appSpecificPassword: password!,
                )).accountId;
        case BusyProvider.nextcloud:
          final service = ref.read(davAccountOnboardingServiceProvider);
          accountId = reconnecting == null
              ? (await service.connectNextcloud(
                  enteredServer: server!,
                )).accountId
              : (await service.reconnectNextcloud(
                  accountId: reconnecting.id,
                  enteredServer: server!,
                )).accountId;
        case BusyProvider.webCal:
          return;
      }
      if (accountId != null) unawaited(_syncAccount(accountId));
    } on Object catch (error) {
      if (error is OAuthException && error.code == 'OAuthSignInCancelled') {
        return;
      }
      if (error is DavException && error.kind == DavErrorKind.cancelled) return;
      _message('$error');
    } finally {
      if (mounted) setState(() => _connecting = null);
    }
  }

  Future<(String, String)?> _appleCredentials(String? fixedEmail) async {
    final email = TextEditingController(text: fixedEmail);
    final password = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.connectAppleICloudTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              enabled: fixedEmail == null,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.l10n.appleAccountEmail,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.appleAppSpecificPassword,
                helperText: context.l10n.appleAppSpecificPasswordHelp,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (email.text.trim().isNotEmpty &&
                  password.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, (
                  email.text.trim(),
                  password.text.trim(),
                ));
              }
            },
            child: Text(context.l10n.connectAccountAction),
          ),
        ],
      ),
    );
    email.dispose();
    password.dispose();
    return result;
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
    if (confirmed != true) return;
    setState(() => _removing.add(account.id));
    try {
      await ref.read(crossEngineAccountGateProvider).run(account.id, () async {
        if (account.provider == BusyProvider.appleICloud ||
            account.provider == BusyProvider.nextcloud) {
          await ref
              .read(davAccountOnboardingServiceProvider)
              .removeAccount(account.id);
        } else {
          await ref
              .read(authRepositoryProvider)
              .removeAccount(
                accountId: account.id,
                revokeAuthorization: revoke,
              );
        }
      });
      await ref.read(notificationReconcilerProvider).reconcile();
    } on Object {
      _message(l10n.removeAccountFailed);
    } finally {
      if (mounted) setState(() => _removing.remove(account.id));
    }
  }

  Future<void> _syncAll() async {
    final l10n = context.l10n;
    setState(() => _syncing = true);
    try {
      await ref.read(allAccountsSyncRunnerProvider)();
      await ref.read(notificationReconcilerProvider).reconcile();
      _message(l10n.syncComplete);
    } on Object catch (error) {
      _message(l10n.syncFailed('$error'));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _syncAccount(String accountId) async {
    final l10n = context.l10n;
    try {
      await ref.read(signedInSyncRunnerProvider)(accountId, true);
      await ref.read(notificationReconcilerProvider).reconcile();
      _message(l10n.syncComplete);
    } on Object catch (error) {
      _message(l10n.syncFailed('$error'));
    }
  }

  Future<void> _editCalendarSource(CalendarSourceEntity source) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(source.summary)),
            if (source.capabilities.canRenameCalendar)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.l10n.rename),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
            if (source.capabilities.canChangeCalendarColor)
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(context.l10n.calendarColor),
                onTap: () => Navigator.pop(context, 'color'),
              ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(context.l10n.reminders),
              onTap: () => Navigator.pop(context, 'reminders'),
            ),
            if (source.provider == BusyProvider.nextcloud &&
                source.davCollectionId != null)
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: Text(context.l10n.export),
                onTap: () => Navigator.pop(context, 'export'),
              ),
            if (source.capabilities.canRemoveCalendar)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(context.l10n.delete),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'rename') {
        final name = await _textPrompt(
          title: l10n.calendar,
          label: l10n.setCustomCalendarName,
          initialValue: source.summary,
        );
        if (name != null && name != source.summary) {
          await ref
              .read(calendarRepositoryProvider)
              .renameLocalSource(source.id, name);
        }
      } else if (action == 'reminders') {
        final reminders = await _booleanPrompt(
          l10n.reminders,
          source.remindersEnabled,
        );
        if (reminders == null) return;
        await ref
            .read(calendarRepositoryProvider)
            .setSourceRemindersEnabled(source.id, reminders);
      } else if (action == 'color') {
        final choice = await _selectCalendarColor(source);
        if (choice == null) return;
        await ref
            .read(calendarRepositoryProvider)
            .setSourceColor(source.id, choice);
      } else if (action == 'export') {
        await _exportCollection(source.accountId, source.davCollectionId!);
      } else if (action == 'delete') {
        final remove =
            source.capabilities.removalMode ==
            CalendarRemovalMode.removeFromList;
        final confirmed = await _confirm(
          remove ? l10n.removeFromMyCalendars : l10n.delete,
          remove
              ? l10n.removeCalendarConfirmation(source.summary)
              : l10n.deleteCalendarConfirmation(source.summary),
          remove ? l10n.removeAction : l10n.delete,
        );
        if (!confirmed) return;
        await ref.read(calendarRepositoryProvider).deleteLocalSource(source.id);
      }
    } on Object catch (error) {
      _message(l10n.calendarUpdateFailed('$error'));
    }
  }

  Future<void> _editTaskList(
    TaskListEntity list,
    List<AccountEntity> accounts,
  ) async {
    final l10n = context.l10n;
    final account = accounts
        .where((item) => item.id == list.accountId)
        .firstOrNull;
    final davCapabilities = list.davCollectionId == null
        ? null
        : await ref.read(
            davTaskCollectionCapabilitiesProvider((
              accountId: list.accountId,
              taskListId: list.id,
            )).future,
          );
    if (!mounted) return;
    final capabilities = list.davCollectionId != null
        ? davCapabilities ?? noTaskCollectionCapabilities
        : account == null
        ? noTaskCollectionCapabilities
        : adapterDefaultTaskCapabilities(account.provider);
    final canRename = account?.provider == BusyProvider.microsoft
        ? list.canRenameOrDeleteForMicrosoft
        : capabilities.supportsListRename;
    final canDelete = account?.provider == BusyProvider.microsoft
        ? list.canRenameOrDeleteForMicrosoft
        : capabilities.supportsListDelete;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(list.title)),
            if (canRename)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.l10n.rename),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(context.l10n.reminders),
              onTap: () => Navigator.pop(context, 'reminders'),
            ),
            if (list.davCollectionId != null &&
                capabilities.supportsNativeExport)
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: Text(context.l10n.export),
                onTap: () => Navigator.pop(context, 'export'),
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(context.l10n.deleteList),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'rename') {
        final name = await _textPrompt(
          title: l10n.taskLists,
          label: l10n.list,
          initialValue: list.title,
        );
        if (name != null && name != list.title) {
          await ref
              .read(taskListsRepositoryForAccountProvider(list.accountId))
              .renameTaskList(list.id, name);
        }
      } else if (action == 'reminders') {
        final reminders = await _booleanPrompt(
          l10n.reminders,
          list.remindersEnabled,
        );
        if (reminders == null) return;
        await ref
            .read(taskListsRepositoryForAccountProvider(list.accountId))
            .setRemindersEnabled(list.id, reminders);
      } else if (action == 'export') {
        await _exportCollection(list.accountId, list.davCollectionId!);
      } else if (action == 'delete') {
        final confirmed = await _confirm(
          l10n.deleteList,
          list.isMixedDavCollection
              ? l10n.nextcloudRemoveMixed
              : l10n.deleteTaskListConfirmation(list.title),
          l10n.delete,
        );
        if (!confirmed) return;
        await ref
            .read(taskListsRepositoryForAccountProvider(list.accountId))
            .deleteTaskList(list.id);
      }
    } on Object catch (error) {
      _message(l10n.taskListRenameFailed('$error'));
    }
  }

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
    if (eligible.isEmpty) return;
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
    if (account == null || !mounted) return;
    final title = await _textPrompt(
      title: calendar ? l10n.newCalendar : l10n.newTaskList,
      label: l10n.title,
    );
    if (title == null || !mounted) return;
    try {
      if (calendar) {
        await ref
            .read(calendarCollectionCreationServiceProvider)
            .createCalendar(accountId: account.id, title: title);
      } else {
        await ref
            .read(taskListsRepositoryForAccountProvider(account.id))
            .createTaskList(title);
      }
    } on Object catch (error) {
      _message(
        calendar
            ? l10n.calendarCreateFailed('$error')
            : l10n.taskListCreateFailed('$error'),
      );
    }
  }

  Future<CalendarColorChoice?> _selectCalendarColor(
    CalendarSourceEntity source,
  ) {
    final choices = calendarColorChoices(source.provider);
    return showModalBottomSheet<CalendarColorChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(context.l10n.calendarColor)),
            for (var index = 0; index < choices.length; index++)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _colorFromHex(
                    choices[index].backgroundColor,
                  ),
                ),
                title: Text(context.l10n.calendarColorOption(index + 1)),
                trailing:
                    choices[index].backgroundColor.toLowerCase() ==
                        source.backgroundColor?.toLowerCase()
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(sheetContext, choices[index]),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCollection(String accountId, String collectionId) async {
    final l10n = context.l10n;
    final resources = await ref
        .read(nextcloudNativeExportServiceProvider)
        .collection(accountId, collectionId);
    final folder = await BusyMaxAndroidPlatform.instance.exportDocumentTree(
      folderName:
          'BusyMax-export-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      resources: [
        for (var index = 0; index < resources.length; index++)
          AndroidExportResource(
            name: 'resource-${index + 1}.ics',
            bytes: Uint8List.fromList(utf8.encode(resources[index].rawIcs)),
          ),
      ],
    );
    if (folder != null) _message(l10n.exportedFile(folder));
  }

  Future<void> _addSubscription() async {
    final l10n = context.l10n;
    final url = await _textPrompt(
      title: l10n.addCalendarSubscription,
      label: l10n.subscriptionUrl,
      helper: l10n.subscriptionUrlHelp,
    );
    if (url == null) return;
    final name = await _textPrompt(
      title: l10n.addCalendarSubscription,
      label: l10n.subscriptionName,
    );
    try {
      await ref
          .read(webCalSubscriptionServiceProvider)
          .addSubscription(subscriptionUrl: url, localName: name);
    } on Object catch (error) {
      _message(l10n.subscriptionOperationFailed('$error'));
    }
  }

  Future<void> _subscriptionAction(
    WebCalSubscriptionEntity subscription,
    String action,
  ) async {
    final l10n = context.l10n;
    try {
      final service = ref.read(webCalSubscriptionServiceProvider);
      if (action == 'refresh') {
        await service.refreshSubscription(subscription.id, force: true);
      } else if (action == 'rename') {
        final name = await _textPrompt(
          title: l10n.rename,
          label: l10n.subscriptionName,
          initialValue: subscription.name,
        );
        if (name != null) {
          await service.renameSubscription(subscription.id, name);
        }
      } else if (action == 'remove') {
        final confirmed = await _confirm(
          l10n.unsubscribeCalendarTitle(subscription.name),
          l10n.unsubscribeCalendarConfirmation,
          l10n.unsubscribe,
        );
        if (confirmed) {
          await ref
              .read(crossEngineAccountGateProvider)
              .run(
                subscription.accountId,
                () => service.unsubscribe(subscription.id),
              );
        }
      }
    } on Object catch (error) {
      _message(l10n.subscriptionOperationFailed('$error'));
    }
  }

  Future<void> _resolveConflict(DavConflictEntity conflict) async {
    final l10n = context.l10n;
    final resolution = await showModalBottomSheet<DavConflictResolution>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
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
                onTap: () =>
                    Navigator.pop(context, DavConflictResolution.reapplyLocal),
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
    );
    if (resolution == null) return;
    try {
      await ref
          .read(davConflictResolutionServiceProvider)
          .resolve(conflict.id, resolution);
      await ref
          .read(accountSyncOperationsProvider)
          .syncAccount(conflict.accountId, full: false);
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
      if (!granted) return;
    }
    await save(enabled);
    await ref.read(notificationReconcilerProvider).reconcile();
    if (mounted) setState(() {});
  }

  Future<void> _requestExactAlarms() async {
    await ref
        .read(androidNotificationServiceProvider)
        .requestExactAlarmPermission();
    await ref.read(notificationReconcilerProvider).reconcile();
    if (mounted) setState(() {});
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
    if (picked == null) return;
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

  Future<void> _showAbout() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final build = info.buildNumber.trim();
    showAboutDialog(
      context: context,
      applicationName: info.appName.isEmpty ? 'BusyMax' : info.appName,
      applicationVersion: build.isEmpty
          ? info.version
          : '${info.version}+$build',
      applicationLegalese: '© BusyStack',
    );
  }

  Future<String?> _textPrompt({
    required String title,
    required String label,
    String? initialValue,
    String? helper,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label, helperText: helper),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(dialogContext, text);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<bool?> _booleanPrompt(String title, bool value) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(context.l10n.notificationDetailLevel),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.hide),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.show),
          ),
        ],
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

  bool _isLocalHost(String host) {
    final value = host.toLowerCase();
    if (value == 'localhost' || value.endsWith('.local')) return true;
    final parts = value.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    return parts[0] == 10 ||
        (parts[0] == 192 && parts[1] == 168) ||
        (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31);
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        _button(
          context,
          BusyProvider.nextcloud,
          context.l10n.addNextcloudAccount,
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
    if (selected == null || !context.mounted) return;
    final service = ref.read(icalImportServiceProvider);
    final preview = service.parsePreview(selected.bytes);
    final destinations = await service.writableDestinations();
    if (!context.mounted) return;
    CalendarSourceEntity? destination = destinations.firstOrNull;
    var newCopies = false;
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
                Text(context.l10n.importEventsFound(preview.eventCount)),
                if (preview.invalidEventCount > 0)
                  Text(
                    context.l10n.importInvalidEvents(preview.invalidEventCount),
                  ),
                const SizedBox(height: 16),
                if (destinations.isEmpty)
                  Text(context.l10n.noWritableCalendars)
                else
                  DropdownButtonFormField<CalendarSourceEntity>(
                    initialValue: destination,
                    decoration: InputDecoration(
                      labelText: context.l10n.importDestinationCalendar,
                    ),
                    items: [
                      for (final source in destinations)
                        DropdownMenuItem(
                          value: source,
                          child: Text(source.summary),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => destination = value),
                  ),
                if (destination?.provider == BusyProvider.nextcloud)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.nextcloudImportCopies),
                    value: newCopies,
                    onChanged: (value) =>
                        setDialogState(() => newCopies = value == true),
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
              onPressed: destination == null
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      IcalImportSelection(destination!, newCopies: newCopies),
                    ),
              child: Text(context.l10n.importIcsConfirm),
            ),
          ],
        ),
      ),
    );
    if (selection == null || !context.mounted) return;
    final report = await service.importPreview(
      preview: preview,
      destination: selection.destination,
      nativeDuplicates: selection.duplicatePolicy,
      normalizeNativeSchedulingMethod:
          selection.destination.provider == BusyProvider.nextcloud,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.importIcsComplete),
        content: Text(
          [
            context.l10n.importQueued(report.queued),
            context.l10n.importDuplicatesSkipped(report.duplicatesSkipped),
            context.l10n.importUnsupportedSets(
              report.unsupportedRecurrenceSets.length,
            ),
            context.l10n.importInvalidEvents(report.invalidEvents),
          ].join('\n'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  } on Object catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.importIcsFailed('$error'))),
    );
  }
}
