import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_glyphs.dart';
import '../../../app/busymax_shortcuts.dart';
import '../../../app/busymax_yaru_theme.dart';
import '../../../app/linux/linux_page_frame.dart';
import '../../../app/linux/linux_window_host.dart';
import '../../../dav/auth/dav_account_dialogs.dart';
import '../../../dav/dav_errors.dart';
import '../../../dav/http/dav_http_transport.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../accounts/domain/account_connection_state.dart';
import '../../connectivity/network_connectivity_service.dart';
import '../../../google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import '../../../l10n/l10n.dart';
import '../../../microsoft_todo/oauth/microsoft_oauth_service.dart';
import '../../sync/sync_auth_error.dart';

enum _OnboardingStep { accounts, preferences }

enum _OnboardingProvider { google, microsoft, appleICloud, nextcloud }

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  var _step = _OnboardingStep.accounts;
  _OnboardingProvider? _signingInProvider;
  String? _errorMessage;
  var _finishingSetup = false;
  DavCancellationToken? _davCancellation;

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
    return CallbackShortcuts(
      bindings: {BusyMaxShortcutActivators.back: _previousStep},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: LinuxPageFrame(
            header: _OnboardingHeader(
              title: l10n.onboardingSetupTitle,
              canGoBack: canGoBack,
              canContinue: canContinue && !_finishingSetup,
              backLabel: backLabel,
              continueLabel: continueLabel,
              onBack: _previousStep,
              onContinue: _nextStep,
            ),
            body: ColoredBox(
              color: BusyMaxSurfaceColors.of(context).window,
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 720;
                    final horizontalPadding = compact
                        ? BusyMaxSpacing.md
                        : BusyMaxSpacing.xxl;
                    final verticalPadding = compact
                        ? BusyMaxSpacing.md
                        : BusyMaxSpacing.xxl;
                    final availableWidth = math.max(
                      0.0,
                      constraints.maxWidth - horizontalPadding * 2,
                    );
                    final shadowGutter = math.min(
                      BusyMaxSpacing.sm,
                      availableWidth / 2,
                    );
                    final contentRailWidth = math.min<double>(
                      BusyMaxSizes.onboardingContentMaxWidth,
                      math.max(0.0, availableWidth - shadowGutter * 2),
                    );
                    final scrollViewportWidth =
                        contentRailWidth + shadowGutter * 2;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: scrollViewportWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Flexible(
                                child: SingleChildScrollView(
                                  key: const ValueKey(
                                    'onboarding-scroll-viewport',
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: shadowGutter,
                                  ),
                                  child: SizedBox(
                                    key: const ValueKey(
                                      'onboarding-content-rail',
                                    ),
                                    width: contentRailWidth,
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
                                          isAppleSigningIn:
                                              _signingInProvider ==
                                              _OnboardingProvider.appleICloud,
                                          isNextcloudSigningIn:
                                              _signingInProvider ==
                                              _OnboardingProvider.nextcloud,
                                          errorMessage: _errorMessage,
                                          missingConfigMessage: kReleaseMode
                                              ? l10n.providerNotConfigured
                                              : config.missingClientIdMessage,
                                          onAddGoogle: () => _signIn(
                                            _OnboardingProvider.google,
                                          ),
                                          onAddMicrosoft: () => _signIn(
                                            _OnboardingProvider.microsoft,
                                          ),
                                          onAddApple: () => _signIn(
                                            _OnboardingProvider.appleICloud,
                                          ),
                                          onAddNextcloud: () => _signIn(
                                            _OnboardingProvider.nextcloud,
                                          ),
                                          onAddSubscription: () => context.go(
                                            '/settings?page=accounts',
                                          ),
                                          onCancelSignIn: _cancelSignIn,
                                        ),
                                      _OnboardingStep.preferences =>
                                        _PreferencesOnboardingStep(
                                          settings: settings,
                                          settingsController:
                                              settingsController,
                                        ),
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(_OnboardingProvider provider) async {
    if (_signingInProvider != null) {
      return;
    }
    AppleICloudCredentialInput? appleInput;
    String? nextcloudServer;
    if (provider == _OnboardingProvider.appleICloud) {
      appleInput = await showAppleICloudCredentialDialog(context);
      if (appleInput == null || !mounted) return;
    } else if (provider == _OnboardingProvider.nextcloud) {
      nextcloudServer = await showNextcloudServerDialog(context);
      if (nextcloudServer == null || !mounted) return;
    }
    setState(() {
      _signingInProvider = provider;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      String? accountId;
      switch (provider) {
        case _OnboardingProvider.google:
          accountId = (await repository.signIn()).accountId;
        case _OnboardingProvider.microsoft:
          accountId = (await repository.signInWithMicrosoft()).accountId;
        case _OnboardingProvider.appleICloud:
          final cancellation = DavCancellationToken();
          _davCancellation = cancellation;
          accountId =
              (await ref
                      .read(davAccountOnboardingServiceProvider)
                      .connectAppleICloud(
                        email: appleInput!.email,
                        appSpecificPassword: appleInput.password,
                        cancellationToken: cancellation,
                      ))
                  .accountId;
        case _OnboardingProvider.nextcloud:
          final cancellation = DavCancellationToken();
          _davCancellation = cancellation;
          accountId =
              (await ref
                      .read(davAccountOnboardingServiceProvider)
                      .connectNextcloud(
                        enteredServer: nextcloudServer!,
                        cancellationToken: cancellation,
                      ))
                  .accountId;
      }
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
        setState(() {
          _signingInProvider = null;
          _davCancellation = null;
        });
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
        setState(
          () => _errorMessage = syncFailureMessage(
            error,
            networkUnavailableMessage: context.l10n.networkOfflineTryAgain,
          ),
        );
      }
    }
  }

  Future<void> _cancelSignIn() async {
    _davCancellation?.cancel();
    ref.read(davAccountOnboardingServiceProvider).cancelNextcloudLogin();
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

    _finishingSetup = true;
    if (mounted) setState(() {});
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
    required this.isAppleSigningIn,
    required this.isNextcloudSigningIn,
    required this.errorMessage,
    required this.missingConfigMessage,
    required this.onAddGoogle,
    required this.onAddMicrosoft,
    required this.onAddApple,
    required this.onAddNextcloud,
    required this.onAddSubscription,
    required this.onCancelSignIn,
  });

  final List<AccountEntity> accounts;
  final bool googleConfigured;
  final bool microsoftConfigured;
  final bool isGoogleSigningIn;
  final bool isMicrosoftSigningIn;
  final bool isAppleSigningIn;
  final bool isNextcloudSigningIn;
  final String? errorMessage;
  final String missingConfigMessage;
  final VoidCallback onAddGoogle;
  final VoidCallback onAddMicrosoft;
  final VoidCallback onAddApple;
  final VoidCallback onAddNextcloud;
  final VoidCallback onAddSubscription;
  final VoidCallback onCancelSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isSigningIn =
        isGoogleSigningIn ||
        isMicrosoftSigningIn ||
        isAppleSigningIn ||
        isNextcloudSigningIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OnboardingStepHeader(
          title: l10n.onboardingAccountsStepTitle,
          description: l10n.providerConnectionDescription,
        ),
        const SizedBox(height: BusyMaxSpacing.xl),
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
        const SizedBox(height: BusyMaxSpacing.sm),
        Text(
          l10n.googlePermissionsConsentNotice,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
        const SizedBox(height: BusyMaxSpacing.md),
        _ProviderSignInButton(
          label: l10n.addAppleICloudAccount,
          loadingLabel: l10n.waitingForAppleICloud,
          configured: true,
          enabled: !isSigningIn,
          loading: isAppleSigningIn,
          tooltip: l10n.addAppleICloudAccount,
          onPressed: onAddApple,
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        _ProviderSignInButton(
          label: l10n.addNextcloudAccount,
          loadingLabel: l10n.waitingForNextcloud,
          configured: true,
          enabled: !isSigningIn,
          loading: isNextcloudSigningIn,
          tooltip: l10n.addNextcloudAccount,
          onPressed: onAddNextcloud,
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        _ProviderSignInButton(
          label: l10n.addCalendarSubscription,
          loadingLabel: l10n.addCalendarSubscription,
          configured: true,
          enabled: !isSigningIn,
          loading: false,
          tooltip: l10n.calendarSubscriptionsDescription,
          onPressed: onAddSubscription,
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
          BusyMaxPushButton.standard(
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
    final hasIssue = account.hasConnectionIssue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BusyMaxSpacing.xs),
      child: Row(
        children: [
          Icon(
            hasIssue ? YaruIcons.warning : YaruIcons.checkmark,
            size: BusyMaxSizes.iconSm,
            color: hasIssue ? colorScheme.error : colorScheme.primary,
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
                if (hasIssue)
                  Text(
                    _onboardingAccountIssueMessage(context, account),
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

String _onboardingAccountIssueMessage(
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
              title: l10n.runInBackgroundWhenClosed,
              value: settings.runInBackgroundWhenClosed,
              onChanged: settingsController.setRunInBackgroundWhenClosed,
              leading: const Icon(YaruIcons.window),
            ),
            BusyMaxSwitchRow(
              title: l10n.showTrayIcon,
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
            BusyMaxComboRow<NotificationDetailLevel>(
              title: l10n.notificationDetailLevel,
              leading: const Icon(YaruIcons.eye),
              values: NotificationDetailLevel.values,
              selected: settings.notificationDetailLevel,
              labelFor: (value) => _notificationDetailLabel(context, value),
              onSelected: settingsController.setNotificationDetailLevel,
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
    final effectiveTooltip = configured
        ? tooltip
        : context.l10n.providerNotConfigured;
    return BusyMaxGroupedList(
      filled: true,
      children: [
        BusyMaxActionRow(
          title: loading ? loadingLabel : label,
          leading: const Icon(YaruIcons.plus),
          trailing: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  BusyMaxGlyphs.collapsedFor(Directionality.of(context)),
                  size: BusyMaxSizes.iconSm,
                ),
          enabled: enabled,
          tooltip: effectiveTooltip,
          onTap: onPressed,
        ),
      ],
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.title,
    required this.canGoBack,
    required this.canContinue,
    required this.backLabel,
    required this.continueLabel,
    required this.onBack,
    required this.onContinue,
  });

  final String title;
  final bool canGoBack;
  final bool canContinue;
  final String backLabel;
  final String continueLabel;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final metrics = LinuxWindowMetricsScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth =
            constraints.maxWidth +
            metrics.leftControlInset +
            metrics.rightControlInset;
        final railWidth = math.min(
          BusyMaxSizes.onboardingContentMaxWidth,
          constraints.maxWidth,
        );
        final centeredStart =
            (fullWidth - railWidth) / 2 - metrics.leftControlInset;
        final centeredEnd = constraints.maxWidth - centeredStart - railWidth;
        final canCenterWithoutControls = centeredStart >= 0 && centeredEnd >= 0;
        final row = Row(
          children: [
            BusyMaxPushButton.standard(
              key: const ValueKey('onboarding-back-button'),
              onPressed: canGoBack ? onBack : null,
              child: Text(backLabel),
            ),
            Expanded(
              child: LinuxTitlebarGestureRegion(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: busyMaxHeaderTitleStyle(context),
                ),
              ),
            ),
            BusyMaxPushButton.suggested(
              key: const ValueKey('onboarding-continue-button'),
              onPressed: canContinue ? onContinue : null,
              child: Text(continueLabel),
            ),
          ],
        );
        if (!canCenterWithoutControls) return row;
        return Padding(
          padding: EdgeInsets.only(left: centeredStart, right: centeredEnd),
          child: row,
        );
      },
    );
  }
}

String _onboardingErrorMessage(BuildContext context, Object error) {
  if (error is NetworkUnavailableException) {
    return context.l10n.networkOfflineTryAgain;
  }
  if (error is DavException) return error.safeMessage;
  if (error is FormatException) return error.message;
  if (error is SecretStoreException) return error.message;
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
    return secretStorageUnavailableMessage;
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
