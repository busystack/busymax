import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_bootstrap.dart';
import '../../dav/dav_errors.dart';
import '../../dav/http/dav_http_transport.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../providers/busy_provider.dart';
import 'windows_dav_account_dialogs.dart';

class WindowsSignInPage extends ConsumerStatefulWidget {
  const WindowsSignInPage({super.key, this.addingAccount = false});

  final bool addingAccount;

  @override
  ConsumerState<WindowsSignInPage> createState() => _WindowsSignInPageState();
}

class _WindowsSignInPageState extends ConsumerState<WindowsSignInPage> {
  BusyProvider? _connectingDavProvider;
  DavCancellationToken? _davCancellation;
  String? _davError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authSessionControllerProvider);
    final config = ref.watch(buildConfigProvider);
    if (session.isSignedIn && !widget.addingAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/schedule');
      });
    }
    final busy =
        session.status == AuthSessionStatus.signingIn ||
        _connectingDavProvider != null;
    return NavigationView(
      content: ScaffoldPage(
        content: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: Image.asset(
                      'assets/branding/busymax-logo.png',
                      width: 96,
                      height: 96,
                      semanticLabel: l10n.appTitle,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.onboardingSetupTitle,
                    textAlign: TextAlign.center,
                    style: FluentTheme.of(context).typography.title,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.providerConnectionDescription,
                    textAlign: TextAlign.center,
                  ),
                  if (session.message != null || _davError != null) ...[
                    const SizedBox(height: 16),
                    InfoBar(
                      title: Text(_davError ?? session.message!),
                      severity: InfoBarSeverity.error,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy || !config.hasGoogleOAuthClientId
                        ? null
                        : () => _signIn(
                            ref
                                .read(authSessionControllerProvider.notifier)
                                .signIn,
                          ),
                    child: Text(l10n.signInWithGoogle),
                  ),
                  const SizedBox(height: 8),
                  Button(
                    onPressed: busy || !config.hasMicrosoftOAuthClientId
                        ? null
                        : () => _signIn(
                            ref
                                .read(authSessionControllerProvider.notifier)
                                .signInWithMicrosoft,
                          ),
                    child: Text(l10n.signInWithMicrosoft),
                  ),
                  const SizedBox(height: 8),
                  Button(
                    onPressed: busy
                        ? null
                        : () => _connectDav(BusyProvider.appleICloud),
                    child: Text(l10n.addAppleICloudAccount),
                  ),
                  const SizedBox(height: 8),
                  Button(
                    onPressed: busy
                        ? null
                        : () => _connectDav(BusyProvider.nextcloud),
                    child: Text(l10n.addNextcloudAccount),
                  ),
                  if (busy) ...[
                    const SizedBox(height: 20),
                    const Center(child: ProgressRing()),
                    const SizedBox(height: 12),
                    Button(
                      onPressed: _cancelConnection,
                      child: Text(l10n.cancel),
                    ),
                  ],
                  if (widget.addingAccount && !busy) ...[
                    const SizedBox(height: 8),
                    Button(
                      onPressed: () => context.go('/settings'),
                      child: Text(l10n.cancel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(Future<void> Function() action) async {
    setState(() => _davError = null);
    try {
      await action();
    } finally {
      if (mounted) {
        try {
          await ref.read(desktopWindowServiceProvider).showWindow();
        } on Object {
          // Authentication state remains authoritative if foregrounding is
          // temporarily denied by Windows.
        }
      }
    }
    if (!mounted) return;
    if (ref.read(authSessionControllerProvider).isSignedIn) {
      context.go(widget.addingAccount ? '/settings' : '/schedule');
    }
  }

  Future<void> _connectDav(BusyProvider provider) async {
    WindowsAppleCredentialInput? apple;
    String? server;
    if (provider == BusyProvider.appleICloud) {
      apple = await showWindowsAppleICloudDialog(context);
    } else {
      server = await showWindowsNextcloudServerDialog(context);
    }
    if (!mounted ||
        (provider == BusyProvider.appleICloud && apple == null) ||
        (provider == BusyProvider.nextcloud && server == null)) {
      return;
    }
    setState(() {
      _connectingDavProvider = provider;
      _davError = null;
    });
    final cancellation = DavCancellationToken();
    _davCancellation = cancellation;
    try {
      final onboarding = ref.read(davAccountOnboardingServiceProvider);
      if (provider == BusyProvider.appleICloud) {
        await onboarding.connectAppleICloud(
          email: apple!.email,
          appSpecificPassword: apple.password,
          cancellationToken: cancellation,
        );
      } else {
        await onboarding.connectNextcloud(
          enteredServer: server!,
          cancellationToken: cancellation,
        );
      }
      await ref.read(authSessionControllerProvider.notifier).load();
      if (mounted) {
        context.go(widget.addingAccount ? '/settings' : '/schedule');
      }
    } on Object catch (error) {
      if (error is DavException && error.kind == DavErrorKind.cancelled) return;
      if (mounted) {
        setState(() => _davError = authErrorMessage(error));
      }
    } finally {
      _davCancellation = null;
      if (mounted) setState(() => _connectingDavProvider = null);
    }
  }

  Future<void> _cancelConnection() async {
    if (_connectingDavProvider != null) {
      _davCancellation?.cancel();
      if (_connectingDavProvider == BusyProvider.nextcloud) {
        ref.read(davAccountOnboardingServiceProvider).cancelNextcloudLogin();
      }
      if (mounted) setState(() => _connectingDavProvider = null);
      return;
    }
    await ref.read(authSessionControllerProvider.notifier).cancelSignIn();
  }
}
