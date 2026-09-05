import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/notifications/desktop_notification_backend.dart';
import '../../l10n/app_locale.dart';
import '../../platform/common/desktop_services.dart';
import '../../providers/busy_provider.dart';
import '../../webcal/webcal_subscription_service.dart';
import '../common/busymax_glyph.dart';
import 'windows_account_removal_dialog.dart';
import 'windows_busymax_glyphs.dart';
import 'windows_calendar_activation_flows.dart';
import 'windows_diagnostics_dialog.dart';
import 'windows_feedback_dialog.dart';
import 'windows_keyboard_shortcuts_dialog.dart';

const _busyMaxRepositoryUrl = 'https://github.com/busystack/busymax/';
const _apacheLicenseUrl = 'https://www.apache.org/licenses/LICENSE-2.0';
const _systemLocaleTag = 'system';

class WindowsSettingsPage extends ConsumerWidget {
  const WindowsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);
    final autostart = ref.watch(launchAtLoginStateProvider);
    final accounts = ref.watch(accountManagementStreamProvider);
    final subscriptions = ref.watch(webCalSubscriptionsProvider);
    final config = ref.watch(buildConfigProvider);
    final notificationReadiness = ref.watch(
      desktopNotificationReadinessProvider,
    );
    return ScaffoldPage.scrollable(
      header: PageHeader(title: Text(l10n.settings)),
      children: [
        _SectionTitle(l10n.appearance),
        Card(
          child: _SettingsRow(
            icon: BusyMaxGlyph.settings,
            title: l10n.theme,
            child: ComboBox<BusyMaxThemeModePreference>(
              value: settings.themeModePreference,
              items: [
                ComboBoxItem(
                  value: BusyMaxThemeModePreference.system,
                  child: Text(l10n.themeSystem),
                ),
                ComboBoxItem(
                  value: BusyMaxThemeModePreference.light,
                  child: Text(l10n.themeLight),
                ),
                ComboBoxItem(
                  value: BusyMaxThemeModePreference.dark,
                  child: Text(l10n.themeDark),
                ),
              ],
              onChanged: (value) {
                if (value != null) controller.setThemeModePreference(value);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(l10n.scheduleDisplaySettings),
        Card(
          child: Column(
            children: [
              _SettingsRow(
                icon: BusyMaxGlyph.calendar,
                title: l10n.scheduleDayStartsAt,
                child: TimePicker(
                  selected: _minuteDateTime(settings.scheduleDayStartMinute),
                  onChanged: (value) => controller.setScheduleDayStartMinute(
                    value.hour * 60 + value.minute,
                  ),
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.calendar,
                title: l10n.scheduleDayEndsAt,
                child: TimePicker(
                  selected: _minuteDateTime(settings.scheduleDayEndMinute),
                  onChanged: (value) => controller.setScheduleDayEndMinute(
                    value.hour == 0 && value.minute == 0
                        ? 24 * 60
                        : value.hour * 60 + value.minute,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(l10n.settingsSystem),
        Card(
          child: Column(
            children: [
              _SettingsRow(
                icon: BusyMaxGlyph.settings,
                title: l10n.currentLocale,
                child: ComboBox<String>(
                  value: settings.localeTag ?? _systemLocaleTag,
                  items: [
                    ComboBoxItem(
                      value: _systemLocaleTag,
                      child: Text(l10n.themeSystem),
                    ),
                    for (final option in busyMaxLocaleOptions)
                      ComboBoxItem(
                        value: option.tag,
                        child: Text(option.endonym),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.setLocaleTag(
                        value == _systemLocaleTag ? null : value,
                      );
                    }
                  },
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.more,
                title: l10n.runInBackgroundWhenClosed,
                child: ToggleSwitch(
                  checked: settings.runInBackgroundWhenClosed,
                  onChanged: controller.setRunInBackgroundWhenClosed,
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.information,
                title: l10n.showTrayIcon,
                child: ToggleSwitch(
                  checked: settings.showTrayIcon,
                  onChanged: controller.setShowTrayIcon,
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.signOut,
                title: l10n.startMinimizedToTray,
                child: ToggleSwitch(
                  checked: settings.startMinimizedToTray,
                  onChanged: controller.setStartMinimizedToTray,
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.sync,
                title: l10n.launchAtLogin,
                subtitle: _autostartDescription(l10n, autostart),
                child: autostart.when(
                  loading: () => const ProgressRing(),
                  error: (_, _) =>
                      Icon(windowsBusyMaxGlyph(BusyMaxGlyph.warning)),
                  data: (state) => ToggleSwitch(
                    checked: state == DesktopAutostartState.enabled,
                    onChanged:
                        state == DesktopAutostartState.disabledByUser ||
                            state == DesktopAutostartState.disabledByPolicy ||
                            state == DesktopAutostartState.unavailable
                        ? null
                        : (enabled) => unawaited(
                            _setWindowsAutostart(context, ref, enabled),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InfoBar(
          title: Text(l10n.windowsReminderExitNotice),
          severity: InfoBarSeverity.info,
        ),
        const SizedBox(height: 20),
        _SectionTitle(l10n.notifications),
        if (!notificationReadiness.canNotify) ...[
          WindowsNotificationReadinessInfoBar(readiness: notificationReadiness),
          const SizedBox(height: 8),
        ],
        Card(
          child: Column(
            children: [
              _SettingsRow(
                icon: BusyMaxGlyph.reminder,
                title: l10n.eventReminders,
                child: ToggleSwitch(
                  checked: settings.notifyEventReminders,
                  onChanged: controller.setNotifyEventReminders,
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.task,
                title: l10n.taskReminders,
                child: ToggleSwitch(
                  checked: settings.notifyTaskReminders,
                  onChanged: controller.setNotifyTaskReminders,
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.today,
                title: l10n.notifyDueToday,
                child: ToggleSwitch(
                  checked: settings.notifyDueToday,
                  onChanged: controller.setNotifyDueToday,
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.sync,
                title: l10n.notifySyncFailures,
                child: ToggleSwitch(
                  checked: settings.notifySyncFailures,
                  onChanged: controller.setNotifySyncFailures,
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.warning,
                title: l10n.notifyConflicts,
                child: ToggleSwitch(
                  checked: settings.notifyConflicts,
                  onChanged: controller.setNotifyConflicts,
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.privacy,
                title: l10n.notificationDetailLevel,
                child: ComboBox<NotificationDetailLevel>(
                  value: settings.notificationDetailLevel,
                  items: [
                    ComboBoxItem(
                      value: NotificationDetailLevel.private,
                      child: Text(l10n.notificationDetailPrivate),
                    ),
                    ComboBoxItem(
                      value: NotificationDetailLevel.normal,
                      child: Text(l10n.notificationDetailNormal),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      controller.setNotificationDetailLevel(value);
                    }
                  },
                ),
              ),
              const Divider(),
              _SettingsRow(
                icon: BusyMaxGlyph.reminder,
                title: l10n.quietHours,
                subtitle: l10n.quietHoursDescription,
                child: ToggleSwitch(
                  checked: settings.quietHoursEnabled,
                  onChanged: controller.setQuietHoursEnabled,
                ),
              ),
              if (settings.quietHoursEnabled) ...[
                const Divider(),
                _SettingsRow(
                  icon: BusyMaxGlyph.previous,
                  title: l10n.quietHoursStart,
                  child: TimePicker(
                    selected: _timeStringDateTime(settings.quietHoursStart),
                    onChanged: (value) =>
                        controller.setQuietHoursStart(_timeString(value)),
                  ),
                ),
                const Divider(),
                _SettingsRow(
                  icon: BusyMaxGlyph.next,
                  title: l10n.quietHoursEnd,
                  child: TimePicker(
                    selected: _timeStringDateTime(settings.quietHoursEnd),
                    onChanged: (value) =>
                        controller.setQuietHoursEnd(_timeString(value)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(l10n.privacy),
        Card(
          child: _SettingsRow(
            icon: BusyMaxGlyph.privacy,
            title: l10n.redactTaskContentInDiagnostics,
            child: ToggleSwitch(
              checked: settings.redactTaskContentInDiagnostics,
              onChanged: controller.setRedactTaskContentInDiagnostics,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(l10n.accounts),
        Card(
          child: accounts.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: ProgressRing()),
            ),
            error: (_, _) => InfoBar(
              title: Text(l10n.operationFailed),
              severity: InfoBarSeverity.error,
            ),
            data: (values) => Column(
              children: [
                ListTile(
                  leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.add)),
                  title: Text(l10n.connectAccountAction),
                  onPressed: () => context.go('/sign-in?add=true'),
                ),
                if (values.isNotEmpty) const Divider(),
                for (var index = 0; index < values.length; index++) ...[
                  ListTile(
                    leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.account)),
                    title: Text(
                      values[index].displayName ??
                          values[index].email ??
                          values[index].id,
                    ),
                    subtitle: Text(values[index].provider.storageValue),
                    trailing: DropDownButton(
                      title: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.more)),
                      items: [
                        MenuFlyoutItem(
                          leading: Icon(
                            windowsBusyMaxGlyph(BusyMaxGlyph.delete),
                          ),
                          text: Text(l10n.removeAccount),
                          onPressed: () => unawaited(
                            _removeWindowsAccount(context, ref, values[index]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != values.length - 1) const Divider(),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(l10n.calendarImport),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.calendar)),
                title: Text(l10n.importIcsFile),
                subtitle: Text(l10n.calendarImportDescription),
                onPressed: () => showWindowsIcsImportFlow(context, ref),
              ),
              const Divider(),
              ListTile(
                leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.add)),
                title: Text(l10n.addCalendarSubscription),
                subtitle: Text(l10n.calendarSubscriptionsDescription),
                onPressed: () =>
                    showWindowsWebCalSubscriptionFlow(context, ref),
              ),
              ...subscriptions.maybeWhen(
                data: (values) => [
                  for (final subscription in values) ...[
                    const Divider(),
                    ListTile(
                      leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.calendar)),
                      title: Text(subscription.name),
                      subtitle: Text(subscription.safeOrigin),
                      trailing: DropDownButton(
                        title: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.more)),
                        items: [
                          MenuFlyoutItem(
                            leading: Icon(
                              windowsBusyMaxGlyph(BusyMaxGlyph.refresh),
                            ),
                            text: Text(l10n.refresh),
                            onPressed: () => unawaited(
                              _refreshWindowsSubscription(
                                context,
                                ref,
                                subscription,
                              ),
                            ),
                          ),
                          MenuFlyoutItem(
                            leading: Icon(
                              windowsBusyMaxGlyph(BusyMaxGlyph.edit),
                            ),
                            text: Text(l10n.rename),
                            onPressed: () => unawaited(
                              _renameWindowsSubscription(
                                context,
                                ref,
                                subscription,
                              ),
                            ),
                          ),
                          MenuFlyoutItem(
                            leading: Icon(
                              windowsBusyMaxGlyph(BusyMaxGlyph.settings),
                            ),
                            text: Text(l10n.calendarColor),
                            onPressed: () => unawaited(
                              _colorWindowsSubscription(
                                context,
                                ref,
                                subscription,
                              ),
                            ),
                          ),
                          MenuFlyoutItem(
                            leading: Icon(
                              windowsBusyMaxGlyph(BusyMaxGlyph.delete),
                            ),
                            text: Text(l10n.unsubscribe),
                            onPressed: () => unawaited(
                              _unsubscribeWindowsSubscription(
                                context,
                                ref,
                                subscription,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                orElse: () => const <Widget>[],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(l10n.aboutBusyMax),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.information)),
                title: Text(l10n.aboutBusyMax),
                subtitle: Text(l10n.aboutBusyMaxDescription),
                onPressed: () => showWindowsAboutDialog(
                  context,
                  packageVersion: config.windowsPackageVersion,
                  privacyPolicyUrl: config.privacyPolicyUrl,
                  supportUrl: config.supportUrl,
                  homepageUrl: config.homepageUrl,
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.privacy)),
                title: Text(l10n.privacy),
                onPressed: _httpsUri(config.privacyPolicyUrl) == null
                    ? null
                    : () => launchUrl(_httpsUri(config.privacyPolicyUrl)!),
              ),
              const Divider(),
              ListTile(
                leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.feedback)),
                title: Text(l10n.sendFeedback),
                onPressed: () => showWindowsFeedbackDialog(context, ref),
              ),
              const Divider(),
              ListTile(
                leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.diagnostics)),
                title: Text(l10n.diagnostics),
                onPressed: () => showWindowsDiagnosticsDialog(context, ref),
              ),
              const Divider(),
              ListTile(
                leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.more)),
                title: Text(l10n.keyboardShortcuts),
                onPressed: () => showWindowsKeyboardShortcutsDialog(context),
              ),
              const Divider(),
              ListTile(
                leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.feedback)),
                title: Text(l10n.windowsSupport),
                onPressed: _httpsUri(config.supportUrl) == null
                    ? null
                    : () => launchUrl(_httpsUri(config.supportUrl)!),
              ),
              const Divider(),
              ListTile(
                leading: Icon(windowsBusyMaxGlyph(BusyMaxGlyph.information)),
                title: Text(l10n.website),
                onPressed: _httpsUri(config.homepageUrl) == null
                    ? null
                    : () => launchUrl(_httpsUri(config.homepageUrl)!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class WindowsNotificationReadinessInfoBar extends StatelessWidget {
  const WindowsNotificationReadinessInfoBar({
    required this.readiness,
    super.key,
  });

  final DesktopNotificationReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unpackaged =
        readiness.state ==
        DesktopNotificationReadinessState.unavailableUnpackaged;
    return InfoBar(
      title: Text(l10n.windowsNotificationsUnavailable),
      content: Text(
        unpackaged
            ? l10n.windowsNotificationsUnpackaged
            : l10n.windowsNotificationsInstalledFailure,
      ),
      severity: unpackaged ? InfoBarSeverity.warning : InfoBarSeverity.error,
    );
  }
}

Future<void> _setWindowsAutostart(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  try {
    await ref.read(desktopAutostartServiceProvider).setEnabled(enabled);
    ref.invalidate(launchAtLoginStateProvider);
  } on Object {
    ref.invalidate(launchAtLoginStateProvider);
    if (context.mounted) {
      await _showWindowsMessage(
        context,
        AppLocalizations.of(context).launchAtLoginFailed,
      );
    }
  }
}

Future<void> _removeWindowsAccount(
  BuildContext context,
  WidgetRef ref,
  AccountEntity account,
) async {
  final l10n = AppLocalizations.of(context);
  final options = await showWindowsAccountRemovalDialog(
    context,
    accountLabel: account.displayLabel,
    canRevokeGoogleAuthorization:
        account.provider == BusyProvider.google && account.isSignedIn,
  );
  if (options == null || !context.mounted) return;
  try {
    final isDav =
        account.provider == BusyProvider.appleICloud ||
        account.provider == BusyProvider.nextcloud;
    final authResult = isDav
        ? null
        : await ref
              .read(authRepositoryProvider)
              .removeAccount(
                accountId: account.id,
                revokeAuthorization: options.revokeGoogleAuthorization,
              );
    final davResult = isDav
        ? await ref
              .read(davAccountOnboardingServiceProvider)
              .removeAccount(account.id)
        : null;
    final remaining = await ref
        .read(accountsRepositoryProvider)
        .listVisibleAccounts();
    ref.read(selectedAccountIdProvider.notifier).state =
        remaining.firstOrNull?.id;
    await ref.read(authSessionControllerProvider.notifier).load();
    if (!context.mounted) return;
    if (authResult?.authorizationRevocationFailed ?? false) {
      await _showWindowsMessage(context, l10n.accountRemovedGoogleRevokeFailed);
    } else if (davResult?.remoteRevocationAttempted == true &&
        !davResult!.remoteRevocationSucceeded) {
      await _showWindowsMessage(
        context,
        l10n.nextcloudAccountRemovedRevokeFailed,
      );
    }
    if (remaining.isEmpty && context.mounted) context.go('/sign-in');
  } on Object {
    if (context.mounted) {
      await _showWindowsMessage(context, l10n.removeAccountFailed);
    }
  }
}

Future<void> _refreshWindowsSubscription(
  BuildContext context,
  WidgetRef ref,
  WebCalSubscriptionEntity subscription,
) => _runWindowsSubscriptionOperation(
  context,
  () => ref
      .read(webCalSubscriptionServiceProvider)
      .refreshSubscription(subscription.id, force: true),
);

Future<void> _renameWindowsSubscription(
  BuildContext context,
  WidgetRef ref,
  WebCalSubscriptionEntity subscription,
) async {
  final l10n = AppLocalizations.of(context);
  final value = await _showWindowsTextPrompt(
    context,
    title: l10n.rename,
    label: l10n.subscriptionName,
    initialValue: subscription.name,
    actionLabel: l10n.rename,
  );
  if (value == null || !context.mounted) return;
  await _runWindowsSubscriptionOperation(
    context,
    () => ref
        .read(webCalSubscriptionServiceProvider)
        .renameSubscription(subscription.id, value),
  );
}

Future<void> _colorWindowsSubscription(
  BuildContext context,
  WidgetRef ref,
  WebCalSubscriptionEntity subscription,
) async {
  final l10n = AppLocalizations.of(context);
  final value = await _showWindowsTextPrompt(
    context,
    title: l10n.calendarColor,
    label: l10n.subscriptionColor,
    initialValue: subscription.color ?? '',
    actionLabel: l10n.save,
    message: l10n.subscriptionColorHelp,
  );
  if (value == null || !context.mounted) return;
  await _runWindowsSubscriptionOperation(
    context,
    () => ref
        .read(webCalSubscriptionServiceProvider)
        .changeSubscriptionColor(subscription.id, value),
  );
}

Future<void> _unsubscribeWindowsSubscription(
  BuildContext context,
  WidgetRef ref,
  WebCalSubscriptionEntity subscription,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ContentDialog(
      title: Text(l10n.unsubscribeCalendarTitle(subscription.name)),
      content: Text(l10n.unsubscribeCalendarConfirmation),
      actions: [
        Button(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.unsubscribe),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await _runWindowsSubscriptionOperation(
    context,
    () => ref
        .read(webCalSubscriptionServiceProvider)
        .unsubscribe(subscription.id),
  );
}

Future<void> _runWindowsSubscriptionOperation(
  BuildContext context,
  Future<void> Function() operation,
) async {
  try {
    await operation();
  } on Object {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      await _showWindowsMessage(
        context,
        l10n.subscriptionOperationFailed(l10n.operationFailed),
      );
    }
  }
}

Future<String?> _showWindowsTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String initialValue,
  required String actionLabel,
  String? message,
}) async {
  final controller = TextEditingController(text: initialValue);
  final value = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ContentDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) ...[Text(message), const SizedBox(height: 12)],
          InfoLabel(
            label: label,
            child: TextBox(controller: controller, autofocus: true),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppLocalizations.of(dialogContext).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

Future<void> _showWindowsMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => ContentDialog(
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).close),
        ),
      ],
    ),
  );
}

String _autostartDescription(
  AppLocalizations l10n,
  AsyncValue<DesktopAutostartState> value,
) => value.maybeWhen(
  data: (state) => switch (state) {
    DesktopAutostartState.disabledByUser => l10n.windowsStartupDisabledByUser,
    DesktopAutostartState.disabledByPolicy =>
      l10n.windowsStartupDisabledByPolicy,
    DesktopAutostartState.unavailable => l10n.windowsStartupUnavailable,
    _ => l10n.launchAtLoginDescription,
  },
  orElse: () => l10n.launchAtLoginDescription,
);

Uri? _httpsUri(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri?.scheme == 'https' && uri!.host.isNotEmpty ? uri : null;
}

DateTime _minuteDateTime(int minute) =>
    DateTime(2000, 1, 1, (minute ~/ 60) % 24, minute % 60);

DateTime _timeStringDateTime(String value) {
  final parts = value.split(':');
  return DateTime(
    2000,
    1,
    1,
    parts.isEmpty ? 0 : int.tryParse(parts[0]) ?? 0,
    parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0,
  );
}

String _timeString(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 8),
    child: Text(text, style: FluentTheme.of(context).typography.subtitle),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final BusyMaxGlyph icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final compact = constraints.maxWidth < 520 || textScale > 1.3;
      final label = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(windowsBusyMaxGlyph(icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: FluentTheme.of(context).typography.caption,
                  ),
              ],
            ),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.all(16),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label,
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: child,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 16),
                  child,
                ],
              ),
      );
    },
  );
}

Future<void> showWindowsAboutDialog(
  BuildContext context, {
  required String packageVersion,
  required String privacyPolicyUrl,
  required String supportUrl,
  required String homepageUrl,
}) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return ContentDialog(
        title: Text(l10n.aboutBusyMax),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.aboutBusyMaxDescription),
            const SizedBox(height: 12),
            Text('${l10n.windowsProductVersionLabel}: ${packageInfo.version}'),
            Text(
              '${l10n.windowsPackageVersionLabel}: '
              '${packageVersion.isEmpty ? l10n.windowsUnpackaged : packageVersion}',
            ),
            const SizedBox(height: 12),
            Text('Copyright © 2026 BusyStack'),
            Text(l10n.apacheLicenseName),
            const SizedBox(height: 8),
            HyperlinkButton(
              onPressed: () =>
                  unawaited(launchUrl(Uri.parse(_apacheLicenseUrl))),
              child: Text(l10n.license),
            ),
            HyperlinkButton(
              onPressed: () =>
                  unawaited(launchUrl(Uri.parse(_busyMaxRepositoryUrl))),
              child: Text(l10n.sourceCode),
            ),
            if (_httpsUri(privacyPolicyUrl) case final privacyUri?)
              HyperlinkButton(
                onPressed: () => unawaited(launchUrl(privacyUri)),
                child: Text(l10n.privacy),
              ),
            if (_httpsUri(supportUrl) case final supportUri?)
              HyperlinkButton(
                onPressed: () => unawaited(launchUrl(supportUri)),
                child: Text(l10n.windowsSupport),
              ),
            if (_httpsUri(homepageUrl) case final homepageUri?)
              HyperlinkButton(
                onPressed: () => unawaited(launchUrl(homepageUri)),
                child: Text(l10n.website),
              ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => unawaited(showWindowsLicensesDialog(context)),
            child: Text(l10n.windowsThirdPartyLicenses),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      );
    },
  );
}

Future<void> showWindowsLicensesDialog(BuildContext context) async {
  final entries = await LicenseRegistry.licenses.toList();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => ContentDialog(
      title: Text(AppLocalizations.of(context).windowsThirdPartyLicenses),
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
      content: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Expander(
            header: Text(entry.packages.join(', ')),
            content: SelectableText(
              entry.paragraphs.map((paragraph) => paragraph.text).join('\n\n'),
            ),
          );
        },
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).close),
        ),
      ],
    ),
  );
}
