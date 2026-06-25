import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../../google_tasks/oauth/oauth_loopback_flow.dart';
import '../../../google_tasks/oauth/oauth_models.dart';
import '../../../google_tasks/oauth/oauth_token_store.dart';
import '../../../l10n/l10n.dart';
import '../../../microsoft_todo/oauth/microsoft_oauth_service.dart';
import '../../../platform/linux_header_bar_service.dart';
import '../../sync/sync_auth_error.dart';

enum _OnboardingStep { accounts, preferences }

enum _OnboardingProvider { google, microsoft }

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  var _step = _OnboardingStep.accounts;
  _OnboardingProvider? _signingInProvider;
  String? _errorMessage;
  var _headerBarReady = false;
  var _nativeHeaderBarAvailable = false;
  StreamSubscription<BusyMaxHeaderBarAction>? _headerBarActions;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeHeaderBar());
  }

  @override
  void dispose() {
    unawaited(_headerBarActions?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountManagementStreamProvider).valueOrNull ?? const [];
    final settings = ref.watch(appSettingsControllerProvider);
    final settingsController = ref.read(appSettingsControllerProvider.notifier);
    final config = ref.watch(buildConfigProvider);
    final l10n = context.l10n;
    final canGoBack =
        _step != _OnboardingStep.accounts && _signingInProvider == null;
    final backLabel = MaterialLocalizations.of(context).backButtonTooltip;
    final continueLabel = _step == _OnboardingStep.preferences
        ? l10n.finishSetup
        : l10n.continueSetup;
    final canContinue =
        _signingInProvider == null &&
        switch (_step) {
          _OnboardingStep.accounts => accounts.any(
            (account) => account.isSignedIn,
          ),
          _OnboardingStep.preferences => true,
        };
    _updateHeaderBar(
      canGoBack: canGoBack,
      canContinue: canContinue,
      backLabel: backLabel,
      continueLabel: continueLabel,
    );

    return Scaffold(
      body: ColoredBox(
        color: BusyMaxSurfaceColors.of(context).view,
        child: SafeArea(
          top: !Platform.isLinux || !_nativeHeaderBarAvailable,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? BusyMaxSpacing.md : BusyMaxSpacing.xl,
                  vertical: compact ? BusyMaxSpacing.md : BusyMaxSpacing.xl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: BusyMaxSurface(
                      filled: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                BusyMaxSpacing.xl,
                                BusyMaxSpacing.xxl,
                                BusyMaxSpacing.xl,
                                BusyMaxSpacing.xxl,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 480,
                                  ),
                                  child: switch (_step) {
                                    _OnboardingStep.accounts =>
                                      _AccountsOnboardingStep(
                                        accounts: accounts,
                                        googleConfigured:
                                            config.hasGoogleOAuthClientId,
                                        microsoftConfigured:
                                            config.hasMicrosoftOAuthClientId,
                                        isGoogleSigningIn:
                                            _signingInProvider ==
                                            _OnboardingProvider.google,
                                        isMicrosoftSigningIn:
                                            _signingInProvider ==
                                            _OnboardingProvider.microsoft,
                                        errorMessage: _errorMessage,
                                        missingConfigMessage: kReleaseMode
                                            ? l10n.providerNotConfigured
                                            : config.missingClientIdMessage,
                                        onAddGoogle: () =>
                                            _signIn(_OnboardingProvider.google),
                                        onAddMicrosoft: () => _signIn(
                                          _OnboardingProvider.microsoft,
                                        ),
                                        onCancelSignIn: _cancelSignIn,
                                      ),
                                    _OnboardingStep.preferences =>
                                      _PreferencesOnboardingStep(
                                        settings: settings,
                                        settingsController: settingsController,
                                      ),
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (_showFlutterFooterFallback)
                            _OnboardingFooter(
                              canGoBack: canGoBack,
                              canContinue: canContinue,
                              backLabel: backLabel,
                              continueLabel: continueLabel,
                              onBack: _previousStep,
                              onContinue: _nextStep,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _initializeHeaderBar() async {
    final service = ref.read(linuxHeaderBarServiceProvider);
    await service.initialize();
    if (!mounted) {
      return;
    }
    _headerBarActions = service.actions.listen(_handleHeaderBarAction);
    setState(() {
      _headerBarReady = true;
      _nativeHeaderBarAvailable = service.isAvailable;
    });
  }

  bool get _showFlutterFooterFallback {
    if (!Platform.isLinux) {
      return true;
    }
    return _headerBarReady && !_nativeHeaderBarAvailable;
  }

  void _updateHeaderBar({
    required bool canGoBack,
    required bool canContinue,
    required String backLabel,
    required String continueLabel,
  }) {
    if (!_headerBarReady && Platform.isLinux) {
      return;
    }
    final title = context.l10n.onboardingSetupTitle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final service = ref.read(linuxHeaderBarServiceProvider);
      unawaited(() async {
        await service.initialize();
        await service.setScheduleControlsVisible(false);
        await service.setBackVisible(false);
        await service.setSidebarVisible(false);
        await service.setTitleRange(title);
        await service.setOnboardingControls(
          visible: true,
          canGoBack: canGoBack,
          canContinue: canContinue,
          backLabel: backLabel,
          continueLabel: continueLabel,
        );
        await service.setCanRefresh(false);
        await service.setCanCreate(false);
        await service.setSearchActive(false);
        await service.setModalBarrierVisible(false);
      }());
    });
  }

  void _handleHeaderBarAction(BusyMaxHeaderBarAction action) {
    if (action == BusyMaxHeaderBarAction.back) {
      _previousStep();
      return;
    }
    if (action == BusyMaxHeaderBarAction.continueSetup) {
      unawaited(_nextStep());
    }
  }

  Future<void> _signIn(_OnboardingProvider provider) async {
    if (_signingInProvider != null) {
      return;
    }
    setState(() {
      _signingInProvider = provider;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      final signedIn = switch (provider) {
        _OnboardingProvider.google => await repository.signIn(),
        _OnboardingProvider.microsoft => await repository.signInWithMicrosoft(),
      };
      final accountId = signedIn.accountId;
      if (accountId != null) {
        unawaited(_runInitialSync(accountId));
      }
    } on Object catch (error) {
      if (error is OAuthException && error.code == 'OAuthSignInCancelled') {
        return;
      }
      if (mounted) {
        setState(() => _errorMessage = _onboardingErrorMessage(context, error));
      }
    } finally {
      if (mounted) {
        setState(() => _signingInProvider = null);
      }
    }
  }

  Future<void> _runInitialSync(String accountId) async {
    try {
      await ref.read(signedInSyncRunnerProvider)(accountId, true);
    } on Object catch (error) {
      if (isMissingOAuthTokenError(error)) {
        try {
          await ref
              .read(authRepositoryProvider)
              .markReconnectRequired(accountId);
        } on Object {
          // Preserve the original sync failure message below.
        }
      }
      if (mounted) {
        setState(() => _errorMessage = syncFailureMessage(error));
      }
    }
  }

  Future<void> _cancelSignIn() async {
    await ref.read(authRepositoryProvider).cancelSignIn();
    if (mounted) {
      setState(() => _signingInProvider = null);
    }
  }

  void _previousStep() {
    if (_step == _OnboardingStep.accounts || _signingInProvider != null) {
      return;
    }
    setState(() => _step = _OnboardingStep.accounts);
  }

  Future<void> _nextStep() async {
    if (_signingInProvider != null) {
      return;
    }
    if (_step == _OnboardingStep.accounts) {
      final accounts = await ref
          .read(accountsRepositoryProvider)
          .listSignedInAccounts();
      if (accounts.isEmpty) {
        return;
      }
      setState(() => _step = _OnboardingStep.preferences);
      return;
    }

    await ref.read(authSessionControllerProvider.notifier).load();
    if (mounted) {
      context.go('/schedule');
    }
  }
}

class _AccountsOnboardingStep extends StatelessWidget {
  const _AccountsOnboardingStep({
    required this.accounts,
    required this.googleConfigured,
    required this.microsoftConfigured,
    required this.isGoogleSigningIn,
    required this.isMicrosoftSigningIn,
    required this.errorMessage,
    required this.missingConfigMessage,
    required this.onAddGoogle,
    required this.onAddMicrosoft,
    required this.onCancelSignIn,
  });

  final List<AccountEntity> accounts;
  final bool googleConfigured;
  final bool microsoftConfigured;
  final bool isGoogleSigningIn;
  final bool isMicrosoftSigningIn;
  final String? errorMessage;
  final String missingConfigMessage;
  final VoidCallback onAddGoogle;
  final VoidCallback onAddMicrosoft;
  final VoidCallback onCancelSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isSigningIn = isGoogleSigningIn || isMicrosoftSigningIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OnboardingStepHeader(
          title: l10n.onboardingAccountsStepTitle,
          description: l10n.connectGoogleAccount,
        ),
        const SizedBox(height: BusyMaxSpacing.xl),
        Text(
          l10n.googlePermissionsConsentNotice,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        _ProviderSignInButton(
          label: l10n.addGoogleAccount,
          loadingLabel: l10n.waitingForGoogleSignIn,
          configured: googleConfigured,
          enabled: !isSigningIn && googleConfigured,
          loading: isGoogleSigningIn,
          tooltip: googleConfigured
              ? l10n.signInWithGoogle
              : l10n.providerNotConfigured,
          onPressed: onAddGoogle,
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        _ProviderSignInButton(
          label: l10n.addMicrosoftAccount,
          loadingLabel: l10n.waitingForMicrosoftSignIn,
          configured: microsoftConfigured,
          enabled: !isSigningIn && microsoftConfigured,
          loading: isMicrosoftSigningIn,
          tooltip: microsoftConfigured
              ? l10n.signInWithMicrosoft
              : l10n.providerNotConfigured,
          onPressed: onAddMicrosoft,
        ),
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: BusyMaxSpacing.lg),
          _SignedInAccountsSummary(accounts: accounts),
        ],
        if (!googleConfigured || !microsoftConfigured) ...[
          const SizedBox(height: BusyMaxSpacing.md),
          YaruInfoBox(
            yaruInfoType: kReleaseMode
                ? YaruInfoType.warning
                : YaruInfoType.information,
            subtitle: SelectableText(missingConfigMessage),
          ),
        ],
        if (isSigningIn) ...[
          const SizedBox(height: BusyMaxSpacing.md),
          BusyMaxPushButton.outlined(
            onPressed: onCancelSignIn,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(YaruIcons.window_close),
                const SizedBox(width: BusyMaxSpacing.sm),
                Text(l10n.cancel),
              ],
            ),
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: BusyMaxSpacing.md),
          Text(errorMessage!, style: TextStyle(color: colorScheme.error)),
        ],
      ],
    );
  }
}

class _SignedInAccountsSummary extends StatelessWidget {
  const _SignedInAccountsSummary({required this.accounts});

  final List<AccountEntity> accounts;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.accounts,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: BusyMaxSpacing.sm),
        for (final account in accounts) _SignedInAccountRow(account: account),
      ],
    );
  }
}

class _SignedInAccountRow extends StatelessWidget {
  const _SignedInAccountRow({required this.account});

  final AccountEntity account;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondary = account.secondaryLabel;
    final needsReconnect = account.needsReconnect;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BusyMaxSpacing.xs),
      child: Row(
        children: [
          Icon(
            needsReconnect ? YaruIcons.warning : YaruIcons.checkmark,
            size: BusyMaxSizes.iconSm,
            color: needsReconnect ? colorScheme.error : colorScheme.primary,
          ),
          const SizedBox(width: BusyMaxSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (needsReconnect)
                  Text(
                    accountReconnectRequiredSyncMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  )
                else if (secondary != null)
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesOnboardingStep extends StatelessWidget {
  const _PreferencesOnboardingStep({
    required this.settings,
    required this.settingsController,
  });

  final AppSettings settings;
  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OnboardingStepHeader(
          title: l10n.onboardingPreferencesStepTitle,
          description: l10n.onboardingPreferencesStepDescription,
        ),
        BusyMaxGroupedList(
          title: l10n.themeSystem,
          filled: true,
          children: [
            BusyMaxComboRow<BusyMaxThemeModePreference>(
              title: l10n.theme,
              leading: const Icon(Icons.tune),
              values: BusyMaxThemeModePreference.values,
              selected: settings.themeModePreference,
              labelFor: (value) => _themeModeLabel(context, value),
              onSelected: settingsController.setThemeModePreference,
            ),
            BusyMaxSwitchRow(
              title: 'Run in background when window is closed',
              value: settings.runInBackgroundWhenClosed,
              onChanged: settingsController.setRunInBackgroundWhenClosed,
              leading: const Icon(YaruIcons.window),
            ),
            BusyMaxSwitchRow(
              title: 'Show tray icon',
              value: settings.showTrayIcon,
              onChanged: settingsController.setShowTrayIcon,
              leading: const Icon(YaruIcons.pin),
            ),
          ],
        ),
        BusyMaxGroupedList(
          title: l10n.notifications,
          filled: true,
          children: [
            BusyMaxSwitchRow(
              title: 'Event reminders',
              value: settings.notifyEventReminders,
              onChanged: settingsController.setNotifyEventReminders,
              leading: const Icon(YaruIcons.calendar_day),
            ),
            BusyMaxSwitchRow(
              title: 'Task reminders',
              value: settings.notifyTaskReminders,
              onChanged: settingsController.setNotifyTaskReminders,
              leading: const Icon(YaruIcons.checkmark),
            ),
            BusyMaxSwitchRow(
              title: l10n.notifySyncFailures,
              value: settings.notifySyncFailures,
              onChanged: settingsController.setNotifySyncFailures,
              leading: const Icon(YaruIcons.sync_error),
            ),
          ],
        ),
        BusyMaxGroupedList(
          title: l10n.privacy,
          filled: true,
          children: [
            BusyMaxSwitchRow(
              title: l10n.detailedNotifications,
              value: settings.detailedNotifications,
              onChanged: settingsController.setDetailedNotifications,
              leading: const Icon(YaruIcons.eye),
            ),
            BusyMaxSwitchRow(
              title: l10n.redactTaskContentInDiagnostics,
              value: settings.redactTaskContentInDiagnostics,
              onChanged: settingsController.setRedactTaskContentInDiagnostics,
              leading: const Icon(YaruIcons.shield_warning),
            ),
          ],
        ),
      ],
    );
  }
}

class _OnboardingStepHeader extends StatelessWidget {
  const _OnboardingStepHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: BusyMaxSpacing.sm),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProviderSignInButton extends StatelessWidget {
  const _ProviderSignInButton({
    required this.label,
    required this.loadingLabel,
    required this.configured,
    required this.enabled,
    required this.loading,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final String loadingLabel;
  final bool configured;
  final bool enabled;
  final bool loading;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final content = BusyMaxPushButton.filled(
      onPressed: enabled ? onPressed : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: BusyMaxSpacing.sm),
          ],
          Flexible(
            child: Text(
              loading ? loadingLabel : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: configured ? tooltip : context.l10n.providerNotConfigured,
      child: content,
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.canGoBack,
    required this.canContinue,
    required this.backLabel,
    required this.continueLabel,
    required this.onBack,
    required this.onContinue,
  });

  final bool canGoBack;
  final bool canContinue;
  final String backLabel;
  final String continueLabel;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BusyMaxSpacing.lg,
        vertical: BusyMaxSpacing.md,
      ),
      child: Row(
        children: [
          BusyMaxPushButton.outlined(
            onPressed: canGoBack ? onBack : null,
            child: Text(backLabel),
          ),
          const Spacer(),
          BusyMaxPushButton.filled(
            onPressed: canContinue ? onContinue : null,
            child: Text(continueLabel),
          ),
        ],
      ),
    );
  }
}

String _onboardingErrorMessage(BuildContext context, Object error) {
  if (error is OAuthException) {
    if (error.code == 'OAuthMissingRequiredScope') {
      return context.l10n.googlePermissionsRequiredRetry;
    }
    if (_isCallbackFailure(error.code)) {
      if (error.message == microsoftSignInCallbackNotReceivedMessage) {
        return error.message;
      }
      return googleSignInCallbackNotReceivedMessage;
    }
    return error.message;
  }
  if (error is PlatformException) {
    return secureTokenStorageUnavailableMessage;
  }
  return error.toString();
}

bool _isCallbackFailure(String code) {
  return code == 'OAuthCallbackTimeout' ||
      code == 'OAuthCallbackListenerClosed' ||
      code == 'OAuthCallbackStateMismatch' ||
      code == 'OAuthCallbackProviderError' ||
      code == 'OAuthCallbackMissingCode' ||
      code == 'OAuthCallbackInvalidPath' ||
      code == 'OAuthCallbackError';
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
