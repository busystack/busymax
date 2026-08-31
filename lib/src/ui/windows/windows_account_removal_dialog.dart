import 'package:fluent_ui/fluent_ui.dart';

import '../../../l10n/generated/app_localizations.dart';

class WindowsAccountRemovalOptions {
  const WindowsAccountRemovalOptions({required this.revokeGoogleAuthorization});

  final bool revokeGoogleAuthorization;
}

Future<WindowsAccountRemovalOptions?> showWindowsAccountRemovalDialog(
  BuildContext context, {
  required String accountLabel,
  required bool canRevokeGoogleAuthorization,
}) {
  var revoke = false;
  return showDialog<WindowsAccountRemovalOptions>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final l10n = AppLocalizations.of(context);
        return ContentDialog(
          title: Text(l10n.removeAccountTitle(accountLabel)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.removeAccountConfirmation),
              if (canRevokeGoogleAuthorization) ...[
                const SizedBox(height: 16),
                Checkbox(
                  checked: revoke,
                  onChanged: (value) => setState(() => revoke = value ?? false),
                  content: Text(l10n.revokeGoogleAccess),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.revokeGoogleAccessDescription,
                  style: FluentTheme.of(context).typography.caption,
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
              onPressed: () => Navigator.pop(
                dialogContext,
                WindowsAccountRemovalOptions(revokeGoogleAuthorization: revoke),
              ),
              child: Text(l10n.removeAccountAction),
            ),
          ],
        );
      },
    ),
  );
}
