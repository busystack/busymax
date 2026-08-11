import 'package:flutter/material.dart';

import '../../app/busymax_design.dart';
import '../../app/busymax_dialogs.dart';
import '../../l10n/l10n.dart';
import '../../platform/linux_header_bar_service.dart';

final class AppleICloudCredentialInput {
  AppleICloudCredentialInput({required this.email, required this.password});

  final String email;
  final String password;

  @override
  String toString() =>
      'AppleICloudCredentialInput(email: [REDACTED], password: [REDACTED])';
}

Future<AppleICloudCredentialInput?> showAppleICloudCredentialDialog(
  BuildContext context, {
  String? fixedEmail,
  LinuxHeaderBarService? headerBarService,
}) {
  return showBusyMaxModalDialog<AppleICloudCredentialInput>(
    context,
    headerBarService: headerBarService,
    barrierDismissible: false,
    builder: (context) => _AppleCredentialDialog(fixedEmail: fixedEmail),
  );
}

Future<String?> showNextcloudServerDialog(
  BuildContext context, {
  String? initialServer,
  LinuxHeaderBarService? headerBarService,
}) {
  return showBusyMaxModalDialog<String>(
    context,
    headerBarService: headerBarService,
    barrierDismissible: false,
    builder: (context) => _NextcloudServerDialog(initialServer: initialServer),
  );
}

final class _AppleCredentialDialog extends StatefulWidget {
  const _AppleCredentialDialog({required this.fixedEmail});

  final String? fixedEmail;

  @override
  State<_AppleCredentialDialog> createState() => _AppleCredentialDialogState();
}

final class _AppleCredentialDialogState extends State<_AppleCredentialDialog> {
  late final TextEditingController _email = TextEditingController(
    text: widget.fixedEmail ?? '',
  );
  final TextEditingController _password = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  var _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final emailMissing = _submitted && _email.text.trim().isEmpty;
    final passwordMissing = _submitted && _password.text.trim().isEmpty;
    return BusyMaxDialogShell(
      title: l10n.connectAppleICloudTitle,
      maxWidth: 520,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        BusyMaxPushButton.suggested(
          onPressed: _submit,
          child: Text(l10n.connectAccountAction),
        ),
      ],
      children: [
        Text(l10n.appleAppSpecificPasswordHelp),
        const SizedBox(height: BusyMaxSpacing.md),
        TextField(
          key: const Key('apple-account-email-field'),
          controller: _email,
          focusNode: _emailFocus,
          autofocus: widget.fixedEmail == null,
          readOnly: widget.fixedEmail != null,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.appleAccountEmail,
            errorText: emailMissing ? l10n.requiredField : null,
          ),
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        Semantics(
          textField: true,
          label: l10n.appleAppSpecificPassword,
          child: TextField(
            key: const Key('apple-app-specific-password-field'),
            controller: _password,
            focusNode: _passwordFocus,
            autofocus: widget.fixedEmail != null,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.appleAppSpecificPassword,
              errorText: passwordMissing ? l10n.requiredField : null,
            ),
          ),
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        Text(
          l10n.appleAppSpecificPasswordResetWarning,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: BusyMaxSpacing.sm),
        Text(
          l10n.davCachedOfflineNotice,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _submit() {
    setState(() => _submitted = true);
    final email = _email.text.trim();
    final password = _password.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    Navigator.of(
      context,
    ).pop(AppleICloudCredentialInput(email: email, password: password));
  }
}

final class _NextcloudServerDialog extends StatefulWidget {
  const _NextcloudServerDialog({required this.initialServer});

  final String? initialServer;

  @override
  State<_NextcloudServerDialog> createState() => _NextcloudServerDialogState();
}

final class _NextcloudServerDialogState extends State<_NextcloudServerDialog> {
  late final TextEditingController _server = TextEditingController(
    text: widget.initialServer ?? '',
  );
  var _submitted = false;

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BusyMaxDialogShell(
      title: l10n.connectNextcloudTitle,
      maxWidth: 520,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        BusyMaxPushButton.suggested(
          onPressed: _submit,
          child: Text(l10n.connectAccountAction),
        ),
      ],
      children: [
        TextField(
          key: const Key('nextcloud-server-field'),
          controller: _server,
          autofocus: true,
          keyboardType: TextInputType.url,
          autofillHints: const [AutofillHints.url],
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.nextcloudServerUrl,
            hintText: 'https://cloud.example.com/remote.php/dav',
            helperText: l10n.nextcloudServerUrlHelp,
            helperMaxLines: 2,
            errorText: _submitted && _server.text.trim().isEmpty
                ? l10n.requiredField
                : null,
          ),
        ),
        const SizedBox(height: BusyMaxSpacing.md),
        Text(l10n.nextcloudBrowserAuthorizationHelp),
        const SizedBox(height: BusyMaxSpacing.sm),
        Text(
          l10n.davCachedOfflineNotice,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _submit() {
    setState(() => _submitted = true);
    final server = _server.text.trim();
    if (server.isEmpty) return;
    Navigator.of(context).pop(server);
  }
}
