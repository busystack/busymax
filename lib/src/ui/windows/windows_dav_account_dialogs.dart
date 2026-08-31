import 'package:fluent_ui/fluent_ui.dart';

import '../../../l10n/generated/app_localizations.dart';

class WindowsAppleCredentialInput {
  const WindowsAppleCredentialInput({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

Future<WindowsAppleCredentialInput?> showWindowsAppleICloudDialog(
  BuildContext context,
) async {
  final email = TextEditingController();
  final password = TextEditingController();
  var validationAttempted = false;
  final result = await showDialog<WindowsAppleCredentialInput>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        final invalid =
            validationAttempted &&
            (email.text.trim().isEmpty || password.text.trim().isEmpty);
        return ContentDialog(
          title: Text(l10n.connectAppleICloudTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoLabel(
                label: l10n.appleAccountEmail,
                child: TextBox(controller: email, autofocus: true),
              ),
              const SizedBox(height: 12),
              InfoLabel(
                label: l10n.appleAppSpecificPassword,
                child: TextBox(
                  controller: password,
                  obscureText: true,
                  enableSuggestions: false,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.appleAppSpecificPasswordHelp,
                style: FluentTheme.of(context).typography.caption,
              ),
              if (invalid) ...[
                const SizedBox(height: 12),
                InfoBar(
                  title: Text(l10n.requiredField),
                  severity: InfoBarSeverity.warning,
                ),
              ],
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (email.text.trim().isEmpty || password.text.trim().isEmpty) {
                  setState(() => validationAttempted = true);
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  WindowsAppleCredentialInput(
                    email: email.text.trim(),
                    password: password.text,
                  ),
                );
              },
              child: Text(l10n.connectAccountAction),
            ),
          ],
        );
      },
    ),
  );
  email.dispose();
  password.dispose();
  return result;
}

Future<String?> showWindowsNextcloudServerDialog(BuildContext context) async {
  final server = TextEditingController();
  var validationAttempted = false;
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        return ContentDialog(
          title: Text(l10n.connectNextcloudTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoLabel(
                label: l10n.nextcloudServerUrl,
                child: TextBox(controller: server, autofocus: true),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.nextcloudServerUrlHelp,
                style: FluentTheme.of(context).typography.caption,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.nextcloudBrowserAuthorizationHelp,
                style: FluentTheme.of(context).typography.caption,
              ),
              if (validationAttempted && server.text.trim().isEmpty) ...[
                const SizedBox(height: 12),
                InfoBar(
                  title: Text(l10n.requiredField),
                  severity: InfoBarSeverity.warning,
                ),
              ],
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (server.text.trim().isEmpty) {
                  setState(() => validationAttempted = true);
                  return;
                }
                Navigator.pop(dialogContext, server.text.trim());
              },
              child: Text(l10n.connectAccountAction),
            ),
          ],
        );
      },
    ),
  );
  server.dispose();
  return result;
}
