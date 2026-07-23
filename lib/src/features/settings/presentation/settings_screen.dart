import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_about_dialog.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../app/busymax_keyboard_shortcuts_dialog.dart';
import '../../../app/busymax_layout.dart';
import '../../../google_tasks/oauth/oauth_models.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../../task_providers/task_provider.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../diagnostics/presentation/diagnostics_screen.dart';
import '../../sync/sync_auth_error.dart';
import '../../tasks/presentation/desktop_date_time_fields.dart';
import '../../tasks/presentation/tasks_selection_state.dart';

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
  TaskProvider? _connectingProvider;

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
        onAddGoogle: () => unawaited(_connectAccount(TaskProvider.google)),
        onAddMicrosoft: () =>
            unawaited(_connectAccount(TaskProvider.microsoft)),
        onReconnect: (account) => unawaited(_connectAccount(account.provider)),
        onCreateTaskList: (accountId) =>
            _createTaskList(context, ref, accountId),
        onSignOut: (accountId) => _signOut(context, ref, accountId),
        onDisconnect: (accountId) => _disconnect(context, ref, accountId),
        onDeleteLocalData: (accountId) =>
            _deleteLocalData(context, ref, accountId),
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
          BusyMaxActionRow(
            title: l10n.currentLocale,
            leading: const Icon(Icons.language),
            subtitle: Localizations.localeOf(context).toLanguageTag(),
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
      backgroundColor: BusyMaxSurfaceColors.of(context).view,
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
    if (action == BusyMaxHeaderBarAction.aboutBusyMax) {
      unawaited(
        showBusyMaxAboutDialog(
          context,
          feedbackSubmissionService: ref.read(
            feedbackSubmissionServiceProvider,
          ),
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

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    String accountId,
  ) async {
    await ref.read(authRepositoryProvider).signOut(accountId: accountId);
    if (context.mounted) {
      await _afterAccountRemoved(context, ref, accountId);
    }
  }

  Future<void> _connectAccount(TaskProvider provider) async {
    if (_connectingProvider != null) {
      return;
    }
    final repository = ref.read(authRepositoryProvider);
    final runSync = ref.read(signedInSyncRunnerProvider);
    setState(() => _connectingProvider = provider);
    try {
      final signedIn = switch (provider) {
        TaskProvider.google => await repository.signIn(),
        TaskProvider.microsoft => await repository.signInWithMicrosoft(),
      };
      final accountId = signedIn.accountId;
      if (accountId != null) {
        unawaited(_syncConnectedAccount(runSync, accountId));
      }
    } on Object catch (error) {
      if (error is OAuthException && error.code == 'OAuthSignInCancelled') {
        return;
      }
      if (mounted) {
        _showMessage(context, _accountConnectionErrorMessage(context, error));
      }
    } finally {
      if (mounted) {
        setState(() => _connectingProvider = null);
      }
    }
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

  Future<void> _disconnect(
    BuildContext context,
    WidgetRef ref,
    String accountId,
  ) async {
    await ref
        .read(authRepositoryProvider)
        .revokeAndSignOut(accountId: accountId);
    if (context.mounted) {
      await _afterAccountRemoved(context, ref, accountId);
    }
  }

  Future<void> _deleteLocalData(
    BuildContext context,
    WidgetRef ref,
    String accountId,
  ) async {
    final confirmed = await showBusyMaxConfirm(
      context,
      title: context.l10n.deleteLocalData,
      message: context.l10n.deleteLocalDataConfirmation,
      confirmLabel: context.l10n.delete,
      destructive: true,
      headerBarService: ref.read(linuxHeaderBarServiceProvider),
    );
    if (!context.mounted || !confirmed) {
      return;
    }

    if (context.mounted) {
      await ref
          .read(authRepositoryProvider)
          .deleteLocalAccountData(accountId: accountId);
      if (context.mounted) {
        await _afterAccountRemoved(context, ref, accountId);
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

    await ref
        .read(taskListsRepositoryForAccountProvider(accountId))
        .createTaskList(title.trim());
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
    final sidebarColor = BusyMaxSurfaceColors.of(context).sidebar;
    return BusyMaxSidebarSurface(
      child: YaruNavigationPageTheme(
        data: YaruNavigationPageThemeData(
          sideBarColor: sidebarColor,
          railPadding: const EdgeInsets.symmetric(
            horizontal: BusyMaxSpacing.xs,
            vertical: BusyMaxSpacing.md,
          ),
        ),
        child: YaruNavigationRail(
          length: SettingsPage.values.length,
          selectedIndex: SettingsPage.values.indexOf(selected),
          onDestinationSelected: (index) =>
              onSelected(SettingsPage.values[index]),
          itemBuilder: (context, index, isSelected) {
            final page = SettingsPage.values[index];
            return Semantics(
              key: ValueKey('settings-navigation-${page.name}'),
              container: true,
              selected: isSelected,
              child: YaruNavigationRailItem(
                style: YaruNavigationRailStyle.labelledExtended,
                width: BusyMaxSizes.sidebarWidth - 2 * BusyMaxSpacing.xs,
                extendedSelectedIndicator: true,
                icon: Icon(_settingsPageIcon(page)),
                label: Text(_settingsPageLabel(context, page)),
              ),
            );
          },
        ),
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
        minMenuWidth: BusyMaxSizes.sidebarWidth,
        menuPosition: null,
        entries: [
          for (final page in SettingsPage.values)
            BusyMaxMenuEntry(
              value: page,
              label: _settingsPageLabel(context, page),
              icon: _settingsPageIcon(page),
              checked: page == selected,
            ),
        ],
        onSelected: onSelected,
        triggerBuilder: (context, onPressed, focusNode) {
          return BusyMaxPushButton.standard(
            onPressed: onPressed,
            focusNode: focusNode,
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
            icon: const Icon(YaruIcons.go_previous),
            onPressed: onBack,
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
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
    title: context.l10n.newList,
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
    required this.onReconnect,
    required this.onCreateTaskList,
    required this.onSignOut,
    required this.onDisconnect,
    required this.onDeleteLocalData,
  });

  final List<AccountEntity> accounts;
  final bool googleConfigured;
  final bool microsoftConfigured;
  final TaskProvider? connectingProvider;
  final VoidCallback onAddGoogle;
  final VoidCallback onAddMicrosoft;
  final void Function(AccountEntity account) onReconnect;
  final void Function(String accountId) onCreateTaskList;
  final void Function(String accountId) onSignOut;
  final void Function(String accountId) onDisconnect;
  final void Function(String accountId) onDeleteLocalData;

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
            if (googleConfigured)
              BusyMaxActionRow(
                title: connectingProvider == TaskProvider.google
                    ? l10n.waitingForGoogleSignIn
                    : l10n.addGoogleAccount,
                leading: const Icon(YaruIcons.plus),
                onTap: connecting ? null : onAddGoogle,
              ),
            if (microsoftConfigured)
              BusyMaxActionRow(
                title: connectingProvider == TaskProvider.microsoft
                    ? l10n.waitingForMicrosoftSignIn
                    : l10n.addMicrosoftAccount,
                leading: const Icon(YaruIcons.plus),
                onTap: connecting ? null : onAddMicrosoft,
              ),
            if (accounts.isEmpty)
              BusyMaxActionRow(
                title: l10n.account,
                subtitle: l10n.connectGoogleAccount,
                leading: const Icon(YaruIcons.user),
              ),
          ],
        ),
        for (final account in accounts)
          _AccountManagementCard(
            account: account,
            onReconnect: connecting ? null : () => onReconnect(account),
            onCreateTaskList: () => onCreateTaskList(account.id),
            onSignOut: () => onSignOut(account.id),
            onDisconnect: () => onDisconnect(account.id),
            onDeleteLocalData: () => onDeleteLocalData(account.id),
          ),
      ],
    );
  }
}

class _AccountManagementCard extends StatelessWidget {
  const _AccountManagementCard({
    required this.account,
    required this.onReconnect,
    required this.onCreateTaskList,
    required this.onSignOut,
    required this.onDisconnect,
    required this.onDeleteLocalData,
  });

  final AccountEntity account;
  final VoidCallback? onReconnect;
  final VoidCallback onCreateTaskList;
  final VoidCallback onSignOut;
  final VoidCallback onDisconnect;
  final VoidCallback onDeleteLocalData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BusyMaxGroupedList(
      title: _providerLabel(context, account.provider),
      description: _accountIdentityLabel(context, account),
      filled: true,
      children: [
        if (account.needsReconnect)
          BusyMaxActionRow(
            title: accountReconnectRequiredActionLabel,
            subtitle: accountReconnectRequiredSyncMessage,
            leading: Icon(
              YaruIcons.refresh,
              color: Theme.of(context).colorScheme.error,
            ),
            onTap: onReconnect,
          )
        else ...[
          BusyMaxActionRow(
            title: l10n.newList,
            leading: const Icon(YaruIcons.plus),
            onTap: onCreateTaskList,
          ),
          BusyMaxActionRow(
            title: l10n.signOutThisAccount,
            leading: const Icon(YaruIcons.log_out),
            onTap: onSignOut,
          ),
        ],
        BusyMaxActionRow(
          title: l10n.disconnectThisAccount,
          leading: const Icon(YaruIcons.insert_link),
          onTap: onDisconnect,
        ),
        BusyMaxActionRow(
          title: l10n.deleteLocalDataForThisAccount,
          leading: Icon(
            YaruIcons.trash,
            color: Theme.of(context).colorScheme.error,
          ),
          destructive: true,
          onTap: onDeleteLocalData,
        ),
      ],
    );
  }
}

Future<void> _afterAccountRemoved(
  BuildContext context,
  WidgetRef ref,
  String removedAccountId,
) async {
  ref.read(selectedTaskListIdProvider.notifier).state = null;
  ref.read(selectedTaskIdProvider.notifier).state = null;
  ref.read(allTasksModeProvider.notifier).state = true;

  final accounts = await ref
      .read(accountsRepositoryProvider)
      .listSignedInAccounts();
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

String _providerLabel(BuildContext context, TaskProvider provider) {
  return switch (provider) {
    TaskProvider.google => context.l10n.googleTasksProvider,
    TaskProvider.microsoft => context.l10n.microsoftTodoProvider,
  };
}
