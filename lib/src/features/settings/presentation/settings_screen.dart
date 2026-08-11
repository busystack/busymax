import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_about_dialog.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_glyphs.dart';
import '../../../app/busymax_keyboard_shortcuts_dialog.dart';
import '../../../app/busymax_layout.dart';
import '../../../core/logging/redacting_logger.dart';
import '../../../dav/auth/dav_account_dialogs.dart';
import '../../../dav/dav_errors.dart';
import '../../../dav/http/dav_http_transport.dart';
import '../../../dav/mutation/dav_conflict_repository.dart';
import '../../../dav/storage/dav_settings_repository.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import '../../../l10n/app_locale.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_connection_state.dart';
import '../../auth/data/auth_repository.dart';
import '../../diagnostics/presentation/diagnostics_screen.dart';
import '../../feedback/presentation/feedback_dialog.dart';
import '../../sync/sync_auth_error.dart';
import '../../tasks/presentation/desktop_date_time_fields.dart';
import 'account_removal_dialog.dart';

final _settingsLogger = RedactingLogger(Logger('SettingsScreen'));
const _systemLocaleTag = 'system';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialPage = SettingsPage.accounts});

  final SettingsPage initialPage;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late var _page = widget.initialPage;
  late final LinuxHeaderBarSession _headerBarSession;
  StreamSubscription<BusyMaxHeaderBarAction>? _headerBarActions;
  var _headerBarReady = false;
  var _nativeHeaderBarAvailable = false;
  BusyProvider? _connectingProvider;
  DavCancellationToken? _davCancellation;
  final _removingAccountIds = <String>{};

  @override
  void initState() {
    super.initState();
    _headerBarSession = ref.read(linuxHeaderBarServiceProvider).claimSession();
    _headerBarActions = _headerBarSession.actions.listen(
      _handleHeaderBarAction,
    );
    unawaited(_initializeHeaderBar());
  }

  @override
  void dispose() {
    _davCancellation?.cancel();
    _headerBarSession.dispose();
    unawaited(_headerBarActions?.cancel());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPage != widget.initialPage) {
      _page = widget.initialPage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedAccount = ref.watch(selectedAccountProvider);
    final accounts =
        ref.watch(accountManagementStreamProvider).valueOrNull ?? const [];
    final davCollections =
        ref.watch(davCollectionsStreamProvider).valueOrNull ?? const [];
    final davConflicts =
        ref.watch(davConflictsStreamProvider).valueOrNull ?? const [];
    final config = ref.watch(buildConfigProvider);
    final settings = ref.watch(appSettingsControllerProvider);
    final settingsController = ref.read(appSettingsControllerProvider.notifier);
    final themeController = ref.read(busyMaxThemeControllerProvider);
    final l10n = context.l10n;
    final title = _settingsPageLabel(context, _page);

    final pageBody = switch (_page) {
      SettingsPage.accounts => _AccountManagementSection(
        accounts: _selectedAccountFirst(accounts, selectedAccount?.id),
        googleConfigured: config.hasGoogleOAuthClientId,
        microsoftConfigured: config.hasMicrosoftOAuthClientId,
        connectingProvider: _connectingProvider,
        onAddGoogle: () => unawaited(_connectAccount(BusyProvider.google)),
        onAddMicrosoft: () =>
            unawaited(_connectAccount(BusyProvider.microsoft)),
        onAddApple: () => unawaited(_connectAccount(BusyProvider.appleICloud)),
        onAddNextcloud: () =>
            unawaited(_connectAccount(BusyProvider.nextcloud)),
        onCancelConnection: _cancelAccountConnection,
        onReconnect: (account) =>
            unawaited(_connectAccount(account.provider, reconnecting: account)),
        onCreateTaskList: (accountId) =>
            _createTaskList(context, ref, accountId),
        removingAccountIds: _removingAccountIds,
        onRemoveAccount: (account) =>
            unawaited(_removeAccount(context, ref, account)),
        davCollections: davCollections,
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
      ),
      SettingsPage.schedule => BusyMaxGroupedList(
        title: l10n.scheduleDisplaySettings,
        description: l10n.scheduleDisplayHoursDescription,
        filled: true,
        children: [
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
      SettingsPage.system => BusyMaxGroupedList(
        title: l10n.themeSystem,
        filled: true,
        children: [
          BusyMaxActionRow(
            title: l10n.manualFullSync,
            leading: const Icon(YaruIcons.sync),
            enabled: accounts.isNotEmpty,
            onTap: accounts.isEmpty
                ? null
                : () => _fullSync(context, ref, accounts),
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
          BusyMaxComboRow<BusyMaxThemeModePreference>(
            title: l10n.theme,
            leading: const Icon(Icons.tune),
            values: BusyMaxThemeModePreference.values,
            selected: settings.themeModePreference,
            labelFor: (value) => _themeModeLabel(context, value),
            onSelected: themeController.setThemeMode,
          ),
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
        ],
      ),
      SettingsPage.notifications => BusyMaxGroupedList(
        title: l10n.notifications,
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
      SettingsPage.privacy => BusyMaxGroupedList(
        title: l10n.privacy,
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
      SettingsPage.diagnostics => const DiagnosticsPanel(scrollable: false),
    };

    return Scaffold(
      backgroundColor: BusyMaxSurfaceColors.of(context).window,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showSidebar = BusyMaxLayoutRules.showSettingsSidebar(
            constraints.maxWidth,
          );
          _updateSettingsHeaderBar(
            context,
            title,
            settings: settings,
            showSidebar: showSidebar,
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showFallbackHeader)
                _SettingsFallbackHeader(title: title, onBack: _goBack),
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
                  child: pageBody,
                ),
              ),
            ],
          );
          if (!showSidebar) {
            return content;
          }
          return Row(
            children: [
              SizedBox(
                width: BusyMaxSizes.sidebarWidth,
                child: _SettingsSidebar(
                  selected: _page,
                  onSelected: _selectPage,
                ),
              ),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  bool get _showFallbackHeader {
    if (!Platform.isLinux) {
      return true;
    }
    return _headerBarReady && !_nativeHeaderBarAvailable;
  }

  Future<void> _initializeHeaderBar() async {
    await _headerBarSession.initialize();
    if (!mounted) {
      return;
    }
    setState(() {
      _headerBarReady = true;
      _nativeHeaderBarAvailable = _headerBarSession.isAvailable;
    });
    if (_headerBarSession.isAvailable) {
      unawaited(
        _headerBarSession.setOnboardingControls(
          visible: false,
          canGoBack: false,
          canContinue: false,
          backLabel: '',
          continueLabel: '',
          force: true,
        ),
      );
    }
  }

  void _handleHeaderBarAction(BusyMaxHeaderBarAction action) {
    if (!_headerBarSession.isCurrent) {
      return;
    }
    if (action == BusyMaxHeaderBarAction.back) {
      _goBack();
      return;
    }
    if (action == BusyMaxHeaderBarAction.settings) {
      _selectPage(SettingsPage.accounts);
      return;
    }
    if (action == BusyMaxHeaderBarAction.keyboardShortcuts) {
      unawaited(
        showBusyMaxKeyboardShortcutsDialog(
          context,
          headerBarService: ref.read(linuxHeaderBarServiceProvider),
        ),
      );
      return;
    }
    if (action == BusyMaxHeaderBarAction.reportIssue) {
      unawaited(
        showBusyMaxFeedbackDialog(
          context,
          submissionService: ref.read(feedbackSubmissionServiceProvider),
          headerBarService: ref.read(linuxHeaderBarServiceProvider),
        ),
      );
      return;
    }
    if (action == BusyMaxHeaderBarAction.aboutBusyMax) {
      unawaited(
        showBusyMaxAboutDialog(
          context,
          headerBarService: ref.read(linuxHeaderBarServiceProvider),
        ),
      );
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
      setState(() => _page = page);
    }
    final router = GoRouter.maybeOf(context);
    final uri = router?.state.uri;
    if (router == null || uri == null || uri.path != '/settings') {
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

  void _updateSettingsHeaderBar(
    BuildContext context,
    String title, {
    required AppSettings settings,
    required bool showSidebar,
  }) {
    if (!_nativeHeaderBarAvailable) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        _headerBarSession.updateState(
          BusyMaxHeaderBarState(
            title: title,
            viewMode: settings.scheduleViewMode,
            canRefresh: false,
            canCreateEvent: false,
            canCreateTask: false,
            searchActive: false,
            searchQuery: '',
            canShowSidebar: showSidebar,
            sidebarVisible: showSidebar,
            navigationVisible: false,
            scheduleControlsVisible: false,
            backVisible: true,
          ),
        ),
      );
    });
  }

  Future<void> _connectAccount(
    BusyProvider provider, {
    AccountEntity? reconnecting,
  }) async {
    if (_connectingProvider != null) {
      return;
    }
    AppleICloudCredentialInput? appleInput;
    String? nextcloudServer;
    if (provider == BusyProvider.appleICloud) {
      appleInput = await showAppleICloudCredentialDialog(
        context,
        fixedEmail: reconnecting?.email ?? reconnecting?.providerAccountId,
        headerBarService: ref.read(linuxHeaderBarServiceProvider),
      );
      if (appleInput == null || !mounted) return;
    } else if (provider == BusyProvider.nextcloud) {
      nextcloudServer = await showNextcloudServerDialog(
        context,
        initialServer: reconnecting?.authority,
        headerBarService: ref.read(linuxHeaderBarServiceProvider),
      );
      if (nextcloudServer == null || !mounted) return;
    }
    final repository = ref.read(authRepositoryProvider);
    final runSync = ref.read(signedInSyncRunnerProvider);
    setState(() => _connectingProvider = provider);
    try {
      String? accountId;
      switch (provider) {
        case BusyProvider.google:
          accountId = (await repository.signIn()).accountId;
        case BusyProvider.microsoft:
          accountId = (await repository.signInWithMicrosoft()).accountId;
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
      }
      if (accountId != null) {
        unawaited(_syncConnectedAccount(runSync, accountId));
      }
    } on Object catch (error) {
      if ((error is OAuthException && error.code == 'OAuthSignInCancelled') ||
          (error is DavException && error.kind == DavErrorKind.cancelled)) {
        return;
      }
      if (mounted) {
        _showMessage(context, _accountConnectionErrorMessage(context, error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _connectingProvider = null;
          _davCancellation = null;
        });
      }
    }
  }

  void _cancelAccountConnection() {
    _davCancellation?.cancel();
    ref.read(davAccountOnboardingServiceProvider).cancelNextcloudLogin();
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
          context.l10n.syncFailed(syncFailureMessage(error)),
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
      accountLabel: account.displayLabel,
      canRevokeGoogleAuthorization:
          account.provider == BusyProvider.google && account.isSignedIn,
      headerBarService: ref.read(linuxHeaderBarServiceProvider),
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
        _showMessage(context, context.l10n.removeAccountFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _removingAccountIds.remove(account.id));
      }
    }
  }

  Future<void> _createTaskList(
    BuildContext context,
    WidgetRef ref,
    String accountId,
  ) async {
    final title = await _taskListTitleDialog(
      context,
      ref.read(linuxHeaderBarServiceProvider),
    );
    if (title == null || title.trim().isEmpty) {
      return;
    }

    try {
      await ref
          .read(taskListsRepositoryForAccountProvider(accountId))
          .createTaskList(title.trim());
    } on Object catch (error) {
      _settingsLogger.warning('Task-list creation failed: $error');
      if (context.mounted) {
        _showMessage(
          context,
          context.l10n.taskListCreateFailed(syncFailureMessage(error)),
        );
      }
    }
  }

  Future<void> _fullSync(
    BuildContext context,
    WidgetRef ref,
    List<AccountEntity> accounts,
  ) async {
    if (accounts.isEmpty) {
      return;
    }

    try {
      final runSync = ref.read(signedInSyncRunnerProvider);
      for (final account in accounts) {
        await runSync(account.id, true);
      }
      if (context.mounted) {
        _showMessage(context, context.l10n.syncComplete);
      }
    } on Object catch (error) {
      if (context.mounted) {
        _showMessage(
          context,
          context.l10n.syncFailed(syncFailureMessage(error)),
        );
      }
    }
  }

  Future<void> _refreshCollections(AccountEntity account) async {
    try {
      await ref.read(signedInSyncRunnerProvider)(account.id, true);
      if (mounted) _showMessage(context, context.l10n.syncComplete);
    } on Object catch (error) {
      if (mounted) {
        _showMessage(
          context,
          context.l10n.syncFailed(syncFailureMessage(error)),
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
      await ref
          .read(accountSyncOperationsProvider)
          .syncAccount(conflict.accountId, full: false);
    } on Object catch (error) {
      _settingsLogger.warning('DAV conflict resolution failed: $error');
      if (mounted) {
        _showMessage(context, context.l10n.conflictResolutionFailed);
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({required this.selected, required this.onSelected});

  final SettingsPage selected;
  final ValueChanged<SettingsPage> onSelected;

  @override
  Widget build(BuildContext context) {
    return BusyMaxSidebarSurface(
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

class _SettingsFallbackHeader extends StatelessWidget {
  const _SettingsFallbackHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: BusyMaxSizes.toolbarHeight,
      child: Row(
        children: [
          const SizedBox(width: BusyMaxSpacing.sm),
          YaruIconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(BusyMaxGlyphs.backFor(Directionality.of(context))),
            onPressed: onBack,
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: busyMaxHeaderTitleStyle(context),
            ),
          ),
          const SizedBox(width: BusyMaxSizes.headerIconButton),
          const SizedBox(width: BusyMaxSpacing.md),
        ],
      ),
    );
  }
}

enum SettingsPage {
  accounts,
  schedule,
  system,
  notifications,
  privacy,
  diagnostics,
}

SettingsPage settingsPageFromRouteValue(String? value) {
  return switch (value) {
    'schedule' => SettingsPage.schedule,
    'system' => SettingsPage.system,
    'notifications' => SettingsPage.notifications,
    'privacy' => SettingsPage.privacy,
    'diagnostics' => SettingsPage.diagnostics,
    _ => SettingsPage.accounts,
  };
}

String settingsPageRouteValue(SettingsPage page) => page.name;

String _settingsPageLabel(BuildContext context, SettingsPage page) {
  final l10n = context.l10n;
  return switch (page) {
    SettingsPage.accounts => l10n.accounts,
    SettingsPage.schedule => l10n.scheduleSettings,
    SettingsPage.system => l10n.themeSystem,
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

String _timeOfDayLabel(BuildContext context, int minute) {
  if (minute == 24 * 60) {
    return '24:00';
  }
  final time = TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
  return MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

Future<String?> _taskListTitleDialog(
  BuildContext context,
  LinuxHeaderBarService headerBarService,
) {
  return showBusyMaxTextPrompt(
    context,
    title: context.l10n.newTaskList,
    label: context.l10n.title,
    actionLabel: context.l10n.create,
    headerBarService: headerBarService,
  );
}

class _AccountManagementSection extends StatelessWidget {
  const _AccountManagementSection({
    required this.accounts,
    required this.googleConfigured,
    required this.microsoftConfigured,
    required this.connectingProvider,
    required this.onAddGoogle,
    required this.onAddMicrosoft,
    required this.onAddApple,
    required this.onAddNextcloud,
    required this.onCancelConnection,
    required this.onReconnect,
    required this.onCreateTaskList,
    required this.removingAccountIds,
    required this.onRemoveAccount,
    required this.davCollections,
    required this.davConflicts,
    required this.onRefreshCollections,
    required this.onEventsSelected,
    required this.onTasksSelected,
    required this.onResolveConflict,
  });

  final List<AccountEntity> accounts;
  final bool googleConfigured;
  final bool microsoftConfigured;
  final BusyProvider? connectingProvider;
  final VoidCallback onAddGoogle;
  final VoidCallback onAddMicrosoft;
  final VoidCallback onAddApple;
  final VoidCallback onAddNextcloud;
  final VoidCallback onCancelConnection;
  final void Function(AccountEntity account) onReconnect;
  final void Function(String accountId) onCreateTaskList;
  final Set<String> removingAccountIds;
  final void Function(AccountEntity account) onRemoveAccount;
  final List<DavCollectionSettingsEntity> davCollections;
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connecting = connectingProvider != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BusyMaxGroupedList(
          title: l10n.account,
          filled: true,
          children: [
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
            BusyMaxActionRow(
              title: connectingProvider == BusyProvider.nextcloud
                  ? l10n.waitingForNextcloud
                  : l10n.addNextcloudAccount,
              leading: const Icon(YaruIcons.plus),
              onTap: connecting ? null : onAddNextcloud,
            ),
            if (connecting)
              BusyMaxActionRow(
                title: l10n.cancelAccountConnection,
                leading: const Icon(YaruIcons.window_close),
                onTap: onCancelConnection,
              ),
            if (accounts.isEmpty)
              BusyMaxActionRow(
                title: l10n.account,
                subtitle: l10n.connectGoogleAccount,
                leading: const Icon(YaruIcons.user),
              ),
          ],
        ),
        for (final account in accounts) ...[
          _AccountManagementCard(
            account: account,
            removing: removingAccountIds.contains(account.id),
            onReconnect: connecting || removingAccountIds.contains(account.id)
                ? null
                : () => onReconnect(account),
            onCreateTaskList:
                account.provider == BusyProvider.google ||
                    account.provider == BusyProvider.microsoft ||
                    account.provider == BusyProvider.nextcloud
                ? () => onCreateTaskList(account.id)
                : null,
            onRefreshCollections:
                account.provider == BusyProvider.appleICloud ||
                    account.provider == BusyProvider.nextcloud
                ? () => onRefreshCollections(account)
                : null,
            onRemoveAccount: () => onRemoveAccount(account),
          ),
          if (account.provider == BusyProvider.appleICloud ||
              account.provider == BusyProvider.nextcloud)
            _DavCollectionsCard(
              collections: [
                for (final collection in davCollections)
                  if (collection.accountId == account.id &&
                      (collection.supportsEvents || collection.supportsTasks))
                    collection,
              ],
              onEventsSelected: onEventsSelected,
              onTasksSelected: onTasksSelected,
            ),
          if (davConflicts.any((conflict) => conflict.accountId == account.id))
            _DavConflictsCard(
              conflicts: [
                for (final conflict in davConflicts)
                  if (conflict.accountId == account.id) conflict,
              ],
              onResolve: onResolveConflict,
            ),
        ],
      ],
    );
  }
}

class _AccountManagementCard extends StatelessWidget {
  const _AccountManagementCard({
    required this.account,
    required this.removing,
    required this.onReconnect,
    required this.onCreateTaskList,
    required this.onRefreshCollections,
    required this.onRemoveAccount,
  });

  final AccountEntity account;
  final bool removing;
  final VoidCallback? onReconnect;
  final VoidCallback? onCreateTaskList;
  final VoidCallback? onRefreshCollections;
  final VoidCallback onRemoveAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BusyMaxGroupedList(
      title: _accountProviderLabel(context, account.provider),
      description: _accountIdentityLabel(context, account),
      filled: true,
      children: [
        if (account.provider == BusyProvider.nextcloud)
          BusyMaxActionRow(
            title: l10n.nextcloudProvider,
            subtitle: l10n.nextcloudServerHost(
              Uri.tryParse(account.authority)?.host ?? account.authority,
            ),
            leading: const Icon(Icons.cloud_outlined),
          ),
        if (account.provider == BusyProvider.appleICloud ||
            account.provider == BusyProvider.nextcloud)
          BusyMaxActionRow(
            title: l10n.davConnectionState,
            subtitle: _accountConnectionStateLabel(context, account),
            leading: Icon(
              account.hasConnectionIssue
                  ? YaruIcons.warning
                  : YaruIcons.checkmark,
            ),
          ),
        if (account.provider == BusyProvider.appleICloud ||
            account.provider == BusyProvider.nextcloud)
          BusyMaxActionRow(
            title: account.lastSuccessfulSyncAtUtc == null
                ? l10n.davNeverSynced
                : l10n.davLastSuccessfulSync(
                    _formatDavDateTime(
                      context,
                      account.lastSuccessfulSyncAtUtc!,
                    ),
                  ),
            leading: const Icon(YaruIcons.sync),
          ),
        if (account.hasConnectionIssue)
          BusyMaxActionRow(
            title: account.needsReconnect
                ? accountReconnectRequiredActionLabel
                : _accountConnectionIssueMessage(context, account),
            subtitle: _accountConnectionIssueMessage(context, account),
            leading: Icon(
              YaruIcons.refresh,
              color: Theme.of(context).colorScheme.error,
            ),
            onTap: account.needsReconnect ? onReconnect : null,
          )
        else if (onCreateTaskList != null) ...[
          BusyMaxActionRow(
            title: l10n.newTaskList,
            leading: const Icon(YaruIcons.plus),
            onTap: removing ? null : onCreateTaskList,
          ),
        ],
        if (onRefreshCollections != null)
          BusyMaxActionRow(
            title: l10n.refreshCollections,
            leading: const Icon(YaruIcons.sync),
            onTap: removing ? null : onRefreshCollections,
          ),
        BusyMaxActionRow(
          title: removing ? l10n.removingAccount : l10n.removeAccount,
          subtitle: l10n.removeAccountDescription,
          leading: Icon(
            YaruIcons.trash,
            color: Theme.of(context).colorScheme.error,
          ),
          destructive: true,
          onTap: removing ? null : onRemoveAccount,
        ),
      ],
    );
  }
}

class _DavCollectionsCard extends StatelessWidget {
  const _DavCollectionsCard({
    required this.collections,
    required this.onEventsSelected,
    required this.onTasksSelected,
  });

  final List<DavCollectionSettingsEntity> collections;
  final void Function(DavCollectionSettingsEntity collection, bool selected)
  onEventsSelected;
  final void Function(DavCollectionSettingsEntity collection, bool selected)
  onTasksSelected;

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    return BusyMaxGroupedList(
      title: l10n.collectionSettings,
      filled: true,
      children: [
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
  final void Function(DavCollectionSettingsEntity collection, bool selected)
  onEventsSelected;
  final void Function(DavCollectionSettingsEntity collection, bool selected)
  onTasksSelected;

  @override
  Widget build(BuildContext context) {
    final supportsEvents = collection.supportsEvents;
    final supportsTasks = collection.supportsTasks;
    final details = _davCollectionDetails(context, collection);
    final indicator = _DavCollectionIndicator(color: collection.color);

    if (supportsEvents && !supportsTasks) {
      return BusyMaxSwitchRow(
        key: ValueKey('dav-events-toggle-${collection.id}'),
        title: collection.name,
        subtitle: details,
        value: collection.eventsSelected,
        onChanged: (selected) => onEventsSelected(collection, selected),
        leading: indicator,
      );
    }

    if (supportsTasks && !supportsEvents) {
      return BusyMaxSwitchRow(
        key: ValueKey('dav-tasks-toggle-${collection.id}'),
        title: collection.name,
        subtitle: details,
        value: collection.tasksSelected,
        onChanged: (selected) => onTasksSelected(collection, selected),
        leading: indicator,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BusyMaxActionRow(
          title: collection.name,
          subtitle: details,
          leading: indicator,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: BusyMaxSpacing.xxl),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: BusyMaxSpacing.xs,
              ),
              child: Column(
                children: [
                  BusyMaxSwitchRow(
                    key: ValueKey('dav-events-toggle-${collection.id}'),
                    title: context.l10n.calendarContent,
                    value: collection.eventsSelected,
                    onChanged: (selected) =>
                        onEventsSelected(collection, selected),
                    leading: const Icon(YaruIcons.calendar),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  BusyMaxSwitchRow(
                    key: ValueKey('dav-tasks-toggle-${collection.id}'),
                    title: context.l10n.taskContent,
                    value: collection.tasksSelected,
                    onChanged: (selected) =>
                        onTasksSelected(collection, selected),
                    leading: const Icon(YaruIcons.checkmark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    if (context.mounted) {
      context.go('/sign-in');
    }
    return;
  }

  ref.read(selectedAccountIdProvider.notifier).state = remaining.first.id;
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
  if (error is OAuthException && error.code == 'OAuthMissingRequiredScope') {
    return context.l10n.googlePermissionsRequiredRetry;
  }
  return authErrorMessage(error);
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
  };
}

String _accountConnectionIssueMessage(
  BuildContext context,
  AccountEntity account,
) => switch (account.connectionState) {
  AccountConnectionState.reauthenticationRequired =>
    context.l10n.davReauthenticationRequired,
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
  return '${material.formatMediumDate(local)} '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
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
