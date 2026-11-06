import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'caldav_credential_input.dart';

typedef CalDavDialogBuilder = Widget Function(
  BuildContext context,
  Widget fields,
  VoidCallback submit,
);

/// Shared validation for the existing Linux and Android dialog compositions.
final class CalDavCredentialForm extends StatefulWidget {
  const CalDavCredentialForm({
    super.key,
    required this.builder,
    this.fixedServer,
    this.fixedUsername,
  });
  final CalDavDialogBuilder builder;
  final String? fixedServer;
  final String? fixedUsername;
  @override
  State<CalDavCredentialForm> createState() => _CalDavCredentialFormState();
}

class _CalDavCredentialFormState extends State<CalDavCredentialForm> {
  final _form = GlobalKey<FormState>();
  late final _server = TextEditingController(text: widget.fixedServer);
  late final _username = TextEditingController(text: widget.fixedUsername);
  final _password = TextEditingController();
  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final value = CalDavCredentialInput(
      serverUrl: _server.text.trim(),
      username: _username.text,
      password: _password.text,
    );
    if (value.isValid) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return widget.builder(
      context,
      Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.caldavHttpsHelp),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('caldav-server-field'),
              controller: _server,
              readOnly: widget.fixedServer != null,
              autofocus: widget.fixedServer == null,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.caldavServerUrl),
              validator: (value) =>
                  CalDavCredentialInput.isSafeServer(value ?? '')
                  ? null
                  : l10n.caldavInvalidServerUrl,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('caldav-username-field'),
              controller: _username,
              readOnly: widget.fixedUsername != null,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.caldavUsername),
              validator: (value) =>
                  value == null ||
                      value.trim().isEmpty ||
                      value.contains(':') ||
                      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)
                  ? l10n.requiredField
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('caldav-password-field'),
              controller: _password,
              autofocus: widget.fixedServer != null,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(labelText: l10n.caldavPassword),
              validator: (value) =>
                  value == null ||
                      value.isEmpty ||
                      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)
                  ? l10n.requiredField
                  : null,
            ),
          ],
        ),
      ),
      _submit,
    );
  }
}

Future<CalDavCredentialInput?> showMaterialCalDavCredentialDialog(
  BuildContext context, {
  String? fixedServer,
  String? fixedUsername,
}) => showDialog<CalDavCredentialInput>(
  context: context,
  barrierDismissible: false,
  builder: (_) => CalDavCredentialForm(
    fixedServer: fixedServer,
    fixedUsername: fixedUsername,
    builder: (context, fields, submit) => AlertDialog(
      title: Text(context.l10n.registrationSetupTitle('CalDAV')),
      content: SingleChildScrollView(child: fields),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: submit,
          child: Text(context.l10n.connectAccountAction),
        ),
      ],
    ),
  ),
);
