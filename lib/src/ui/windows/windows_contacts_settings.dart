import '../../l10n/l10n.dart';

import 'dart:async';

import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_bootstrap.dart';
import '../../providers/busy_provider.dart';

import 'package:fluent_ui/fluent_ui.dart';

class WindowsContactsSettings extends ConsumerStatefulWidget {
  const WindowsContactsSettings({super.key});
  @override
  ConsumerState<WindowsContactsSettings> createState() =>
      _WindowsContactsSettingsState();
}

class _WindowsContactsSettingsState
    extends ConsumerState<WindowsContactsSettings> {
  bool _pending = false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ContactsException
              ? error.code
              : context.l10n.operationFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  bool _writable(ContactAccount account) => account.grantedScopes.any(
    (s) => [
      'contacts.readwrite',
      'carddav:write',
      'https://www.googleapis.com/auth/contacts',
    ].contains(s.toLowerCase()),
  );
  Widget _action(String label, Future<void> Function() action) => Button(
    onPressed: _pending ? null : () => unawaited(_run(action)),
    child: Text(label),
  );

  Future<void> _add(bool nextcloud) async {
    final input = await showDialog<_DavInput>(
      context: context,
      builder: (_) => _DavDialog(nextcloud: nextcloud),
    );
    if (!mounted || input == null) return;
    {
      final controller = ref.read(busyMaxContactsControllerProvider);
      final id = const Uuid().v7();
      if (nextcloud) {
        await controller.addNextcloudContactsOnly(
          id: id,
          label: input.label,
          server: Uri.parse(input.server),
          readOnly: input.readOnly,
        );
      } else {
        await controller.addCardDavContactsOnly(
          id: id,
          label: input.label,
          server: Uri.parse(input.server),
          username: input.username,
          password: input.password,
          readOnly: input.readOnly,
        );
      }
    }
  }

  Future<void> _reconnect(ContactAccount account) async {
    final controller = ref.read(busyMaxContactsControllerProvider);
    final parent = await controller.store.linkedBusyMaxAccount(account.id);
    if (parent != null ||
        account.provider != ContactProviderKind.carddav ||
        await controller.isIndependentNextcloud(account.id)) {
      await controller.reconnectContactsAccount(account.id);
      return;
    }
    if (!mounted) return;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DavReconnectDialog(),
    );
    if (!mounted || password == null) return;
    await controller.reconnectDavContactsOnly(account.id, password: password);
  }

  @override
  Widget build(BuildContext context) {
    final parents =
        ref.watch(accountManagementStreamProvider).valueOrNull ?? const [];
    final accounts =
        ref.watch(busyMaxContactAccountsProvider).valueOrNull ??
        const <ContactAccount>[];
    final sources =
        ref.watch(busyMaxContactSourceSettingsProvider).valueOrNull ?? const [];
    final controller = ref.read(busyMaxContactsControllerProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.contactsTitle),
            if (accounts.isEmpty) Text(context.l10n.contactsLinkedDescription),
            for (final parent in parents.where(
              (p) => [
                BusyProvider.google,
                BusyProvider.microsoft,
                BusyProvider.nextcloud,
              ].contains(p.provider),
            )) ...[
              Text('${context.l10n.contactsTitle}: ${parent.displayLabel}'),
              Text(context.l10n.contactsReadPermissionDescription),
              _action(
                context.l10n.contactsEnableSuggestions,
                () => parent.provider == BusyProvider.nextcloud
                    ? controller.enableLinkedNextcloudContacts(parent.id)
                    : controller.enableLinkedContacts(parent.id),
              ),
              Text(context.l10n.contactsWritePermissionDescription),
              _action(
                context.l10n.contactsEnableEditing,
                () => parent.provider == BusyProvider.nextcloud
                    ? controller.enableLinkedNextcloudContacts(
                        parent.id,
                        writable: true,
                      )
                    : controller.enableLinkedContacts(
                        parent.id,
                        writable: true,
                      ),
              ),
            ],
            Wrap(
              spacing: 8,
              children: [
                _action(context.l10n.contactsAddCardDav, () => _add(false)),
                _action(context.l10n.contactsAddNextcloud, () => _add(true)),
              ],
            ),
            for (final account in accounts) ...[
              Text(
                '${account.displayName} · ${_writable(account) ? context.l10n.contactsReadWriteAccess : context.l10n.readOnlySharedCollection} · ${account.enabled ? context.l10n.contactsSuggestionsEnabled : context.l10n.off}',
              ),
              if (account.errorCode != null) Text(account.errorCode!),
              Wrap(
                spacing: 8,
                children: [
                  _action(
                    context.l10n.connectAccountAction,
                    () => _reconnect(account),
                  ),
                  if (account.provider == ContactProviderKind.carddav &&
                      !account.id.startsWith('contacts:') &&
                      !_writable(account))
                    _action(
                      context.l10n.contactsEnableEditing,
                      () => controller.reconnectDavContactsOnly(
                        account.id,
                        readOnly: false,
                      ),
                    ),
                  _action(
                    context.l10n.contactsDisableForAccount,
                    () => controller.disableContactsAccount(account.id),
                  ),
                  _action(
                    context.l10n.removeAction,
                    () => controller.removeContactsAccount(account.id),
                  ),
                ],
              ),
            ],
            for (final setting in sources)
              ToggleSwitch(
                key: ValueKey('contacts-source:${setting.source.key}'),
                checked: setting.enabled,
                content: Text(setting.source.name),
                onChanged: _pending
                    ? null
                    : (enabled) => unawaited(
                        _run(
                          () => controller.setSourceEnabled(
                            setting.source.key,
                            enabled: enabled,
                          ),
                        ),
                      ),
              ),
            if (_pending) const ProgressRing(),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    );
  }
}

final class _DavInput {
  const _DavInput(
    this.label,
    this.server,
    this.username,
    this.password,
    this.readOnly,
  );
  final String label, server, username, password;
  final bool readOnly;
}

class _DavDialog extends StatefulWidget {
  const _DavDialog({required this.nextcloud});
  final bool nextcloud;
  @override
  State<_DavDialog> createState() => _DavDialogState();
}

class _DavDialogState extends State<_DavDialog> {
  final _label = TextEditingController();
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _readOnly = true;
  String? _error;
  @override
  void dispose() {
    _label.dispose();
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final uri = Uri.tryParse(_server.text.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        _label.text.trim().isEmpty ||
        !widget.nextcloud &&
            (_username.text.isEmpty || _password.text.isEmpty)) {
      setState(() => _error = context.l10n.contactsReadPermissionDescription);
      return;
    }
    Navigator.pop(
      context,
      _DavInput(
        _label.text.trim(),
        uri.toString(),
        _username.text,
        _password.text,
        _readOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ContentDialog(
    title: Text(
      widget.nextcloud
          ? context.l10n.contactsAddNextcloud
          : context.l10n.contactsAddCardDav,
    ),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoLabel(
            label: context.l10n.subscriptionName,
            child: TextBox(controller: _label, obscureText: false),
          ),
          InfoLabel(
            label: context.l10n.contactsServerUrlLabel,
            child: TextBox(controller: _server, obscureText: false),
          ),
          if (!widget.nextcloud)
            InfoLabel(
              label: context.l10n.contactsUsernameLabel,
              child: TextBox(controller: _username, obscureText: false),
            ),
          if (!widget.nextcloud)
            InfoLabel(
              label: context.l10n.contactsPasswordLabel,
              child: TextBox(controller: _password, obscureText: true),
            ),
          ToggleSwitch(
            checked: _readOnly,
            content: Text(context.l10n.readOnlySharedCollection),
            onChanged: (value) => setState(() => _readOnly = value),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      Button(
        child: Text(context.l10n.cancel),
        onPressed: () => Navigator.pop(context),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(context.l10n.connectAccountAction),
      ),
    ],
  );
}

class _DavReconnectDialog extends StatefulWidget {
  const _DavReconnectDialog();
  @override
  State<_DavReconnectDialog> createState() => _DavReconnectDialogState();
}

class _DavReconnectDialogState extends State<_DavReconnectDialog> {
  final _password = TextEditingController();
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ContentDialog(
    title: Text(context.l10n.connectAccountAction),
    content: TextBox(
      controller: _password,
      obscureText: true,
      placeholder: context.l10n.contactsPasswordLabel,
    ),
    actions: [
      Button(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      Button(
        onPressed: () {
          if (_password.text.isNotEmpty) Navigator.pop(context, _password.text);
        },
        child: Text(context.l10n.connectAccountAction),
      ),
    ],
  );
}
