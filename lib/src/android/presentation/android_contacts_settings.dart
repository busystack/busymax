import '../android_local_network_access.dart';
import 'android_editor_group.dart';
import '../../contacts/busymax_contacts_controller.dart'
    show BusyMaxContactSourceSetting;
import 'android_nextcloud_certificate_dialog.dart';
import '../../ui/common/nextcloud_certificate_review.dart';
import '../../l10n/l10n.dart';
import '../../l10n/contacts_error_description.dart';

import 'dart:async';

import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_bootstrap.dart';
import '../../providers/busy_provider.dart';

import 'package:flutter/material.dart';

final _androidLinkedContactsProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, accountId) async {
      final accounts = await ref.watch(busyMaxContactAccountsProvider.future);
      final store = ref.watch(busyMaxContactsControllerProvider).store;
      final ids = <String>{};
      for (final account in accounts) {
        if (await store.linkedBusyMaxAccount(account.id) == accountId) {
          ids.add(account.id);
        }
      }
      return ids;
    });

final _androidIndependentContactsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final accounts = await ref.watch(busyMaxContactAccountsProvider.future);
      final store = ref.watch(busyMaxContactsControllerProvider).store;
      final ids = <String>{};
      for (final account in accounts) {
        if (await store.linkedBusyMaxAccount(account.id) == null) {
          ids.add(account.id);
        }
      }
      return ids;
    });

class AndroidContactsSettings extends ConsumerStatefulWidget {
  const AndroidContactsSettings({
    super.key,
    this.accountId,
    this.independentAccountId,
  });
  final String? accountId;
  final String? independentAccountId;
  @override
  ConsumerState<AndroidContactsSettings> createState() =>
      _AndroidContactsSettingsState();
}

class _AndroidContactsSettingsState
    extends ConsumerState<AndroidContactsSettings> {
  bool _pending = false;
  final _servers = <String, Future<Uri?>>{};
  final _nextcloud = <String, Future<bool>>{};
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    if (_pending) {
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = localizedContactsError(context.l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _pending = false);
      }
    }
  }

  Widget _action(String label, Future<void> Function() action) => TextButton(
    onPressed: _pending ? null : () => unawaited(_run(action)),
    child: Text(label),
  );

  Future<void> _add(bool nextcloud) async {
    final input = await showDialog<_DavInput>(
      context: context,
      builder: (_) => _DavDialog(nextcloud: nextcloud),
    );
    if (!mounted || input == null) {
      return;
    }
    if (!await ensureAndroidLocalNetworkAccess(context, input.server) ||
        !mounted) {
      return;
    }
    {
      final controller = ref.read(busyMaxContactsControllerProvider);
      final id = const Uuid().v7();
      if (nextcloud) {
        await controller.addNextcloudContactsOnly(
          reviewCanonicalServer: (entered, canonical) async {
            if (!mounted ||
                !await showAndroidNextcloudCanonicalServer(
                  context,
                  entered,
                  canonical,
                ) ||
                !mounted) {
              return false;
            }
            return ensureAndroidLocalNetworkAccess(
              context,
              canonical.toString(),
            );
          },
          reviewCertificate: (challenge, owner) => reviewNextcloudCertificate(
            challenge,
            owner,
            (data) => mounted
                ? showAndroidNextcloudCertificate(context, data)
                : Future.value(null),
          ),
          id: id,
          label: input.label,
          server: Uri.parse(input.server),
        );
      } else {
        await controller.addCardDavContactsOnly(
          id: id,
          label: input.label,
          server: Uri.parse(input.server),
          username: input.username,
          password: input.password,
        );
      }
    }
  }

  Future<void> _reconnect(ContactAccount account) async {
    final controller = ref.read(busyMaxContactsControllerProvider);
    if (!await _ensureAccountAccess(account) || !mounted) {
      return;
    }
    final parent = await controller.store.linkedBusyMaxAccount(account.id);
    if (parent != null ||
        account.provider != ContactProviderKind.carddav ||
        await controller.isIndependentNextcloud(account.id)) {
      await controller.reconnectContactsAccount(account.id);
      return;
    }
    if (!mounted) {
      return;
    }
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DavReconnectDialog(),
    );
    if (!mounted || password == null) {
      return;
    }
    await controller.reconnectDavContactsOnly(account.id, password: password);
  }

  Future<bool> _ensureAccountAccess(ContactAccount account) async {
    if (account.provider != ContactProviderKind.carddav) {
      return true;
    }
    final controller = ref.read(busyMaxContactsControllerProvider);
    final parentId = await controller.store.linkedBusyMaxAccount(account.id);
    final parent = parentId == null
        ? null
        : await ref.read(accountsRepositoryProvider).accountById(parentId);
    final server =
        parent?.authority ??
        (await controller.independentServer(account.id))?.toString();
    return mounted &&
        (server == null ||
            await ensureAndroidLocalNetworkAccess(context, server));
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(busyMaxContactAccountsProvider);
    final sourcesState = ref.watch(busyMaxContactSourceSettingsProvider);
    final parents =
        (ref.watch(accountManagementStreamProvider).valueOrNull ?? const [])
            .where((a) => widget.accountId != null && a.id == widget.accountId)
            .toList();
    final linked = widget.accountId == null
        ? null
        : ref.watch(_androidLinkedContactsProvider(widget.accountId!));
    final accounts = (accountsState.valueOrNull ?? const <ContactAccount>[])
        .where(
          (a) => widget.independentAccountId != null
              ? a.id == widget.independentAccountId
              : linked?.valueOrNull?.contains(a.id) == true,
        )
        .toList();
    final sources = (sourcesState.valueOrNull ?? const [])
        .where(
          (s) => widget.independentAccountId != null
              ? s.source.accountId == widget.independentAccountId
              : linked?.valueOrNull?.contains(s.source.accountId) == true,
        )
        .toList();
    final controller = ref.read(busyMaxContactsControllerProvider);
    if (widget.accountId == null && widget.independentAccountId == null) {
      final ids = ref.watch(_androidIndependentContactsProvider);
      return Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(title: Text(context.l10n.contactsTitle)),
            if (accountsState.isLoading || ids.isLoading)
              const LinearProgressIndicator(),
            for (final account
                in accountsState.valueOrNull ?? <ContactAccount>[])
              if (ids.valueOrNull?.contains(account.id) == true)
                ListTile(
                  leading: const Icon(Icons.contacts_outlined),
                  title: Text(account.displayName),
                  subtitle: Text(
                    account.errorCode != null
                        ? localizedContactsStatus(
                            context.l10n,
                            account.errorCode!,
                          )
                        : account.enabled
                        ? context.l10n.contactsSuggestionsEnabled
                        : context.l10n.off,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(account.displayName)),
                        body: SingleChildScrollView(
                          child: AndroidContactsSettings(
                            independentAccountId: account.id,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            Wrap(
              spacing: 8,
              children: [
                _action(context.l10n.contactsAddCardDav, () => _add(false)),
                _action(context.l10n.contactsAddNextcloud, () => _add(true)),
              ],
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.contactsTitle),
            if (accountsState.isLoading ||
                sourcesState.isLoading ||
                linked?.isLoading == true)
              const LinearProgressIndicator(),
            if (accountsState.hasError ||
                sourcesState.hasError ||
                linked?.hasError == true)
              ListTile(
                title: Text(context.l10n.collectionsLoadFailed),
                subtitle: Text(
                  localizedContactsError(
                    context.l10n,
                    accountsState.error ?? sourcesState.error ?? linked!.error!,
                  ),
                ),
                trailing: TextButton(
                  onPressed: () {
                    ref.invalidate(busyMaxContactAccountsProvider);
                    ref.invalidate(busyMaxContactSourceSettingsProvider);
                    if (widget.accountId != null) {
                      ref.invalidate(
                        _androidLinkedContactsProvider(widget.accountId!),
                      );
                    }
                  },
                  child: Text(context.l10n.retry),
                ),
              ),
            if (accounts.isEmpty &&
                !accountsState.isLoading &&
                !accountsState.hasError &&
                linked?.isLoading != true)
              Text(context.l10n.contactsLinkedDescription),
            for (final parent in parents.where(
              (p) => [
                BusyProvider.google,
                BusyProvider.microsoft,
                BusyProvider.nextcloud,
              ].contains(p.provider),
            )) ...[
              Text('${context.l10n.contactsTitle}: ${parent.displayLabel}'),
              Text(
                parent.provider == BusyProvider.nextcloud
                    ? context.l10n.contactsNextcloudReuse
                    : context.l10n.contactsReadPermissionDescription,
              ),
              _action(
                context.l10n.contactsEnableSuggestions,
                () => parent.provider == BusyProvider.nextcloud
                    ? () async {
                        if (await ensureAndroidLocalNetworkAccess(
                              context,
                              parent.authority,
                            ) &&
                            mounted) {
                          await controller.enableLinkedNextcloudContacts(
                            parent.id,
                          );
                        }
                      }()
                    : controller.enableLinkedContacts(parent.id),
              ),
            ],
            for (final account in accounts)
              _contactDetails(
                account,
                sources.where((s) => s.source.accountId == account.id).toList(),
              ),
            if (_pending) const CircularProgressIndicator(),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    );
  }

  Widget _contactDetails(
    ContactAccount account,
    List<BusyMaxContactSourceSetting> sources,
  ) {
    final controller = ref.read(busyMaxContactsControllerProvider);
    final independent = widget.independentAccountId != null;
    Future<void> sync() async {
      if (await _ensureAccountAccess(account) && mounted) {
        await controller.synchronizeAccount(account.id);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AndroidEditorGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.contacts_outlined),
              title: Text(account.displayName),
              subtitle: Text(
                '${context.l10n.contactsReadOnlyUse} · ${account.enabled ? context.l10n.contactsSuggestionsEnabled : context.l10n.off}',
              ),
            ),
            if (independent && account.provider == ContactProviderKind.carddav)
              FutureBuilder<Uri?>(
                future: _servers.putIfAbsent(
                  account.id,
                  () => controller.independentServer(account.id),
                ),
                builder: (context, snapshot) => snapshot.data == null
                    ? const SizedBox.shrink()
                    : ListTile(
                        title: Text(context.l10n.contactsServerUrlLabel),
                        subtitle: Text(snapshot.data.toString()),
                      ),
              ),
            if (account.errorCode != null) ...[
              ListTile(
                title: Text(
                  localizedContactsStatus(context.l10n, account.errorCode!),
                ),
              ),
              _action(context.l10n.contactsRetrySync, sync),
            ],
            _action(
              context.l10n.contactsDisableForAccount,
              () => controller.disableContactsAccount(account.id),
            ),
          ],
        ),
        AndroidEditorGroup(
          title: context.l10n.contactsTitle,
          children: [
            Text(context.l10n.contactsUseForAttendees),
            for (final setting in sources)
              SwitchListTile(
                key: ValueKey('contacts-source:${setting.source.key}'),
                title: Text(setting.source.name),
                subtitle: Text(context.l10n.contactsUseForAttendees),
                value: setting.enabled,
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
          ],
        ),
        AndroidEditorGroup(
          title: context.l10n.advancedSection,
          expanded: false,
          children: [
            if (account.provider == ContactProviderKind.carddav) ...[
              _action(context.l10n.localNetworkAccessRequired, () async {
                await ensureAndroidLocalNetworkAccess(
                  context,
                  '',
                  review: true,
                );
              }),
              FutureBuilder<bool>(
                future: _nextcloud.putIfAbsent(
                  account.id,
                  () => controller.isIndependentNextcloud(account.id),
                ),
                builder: (context, snapshot) => snapshot.data == true
                    ? _action(context.l10n.privateServerCertificates, () async {
                        if (!await _ensureAccountAccess(account) || !mounted) {
                          return;
                        }
                        await manageNextcloudCertificates(
                          ref,
                          account.id,
                          (data) => mounted
                              ? showAndroidNextcloudCertificate(context, data)
                              : Future.value(null),
                          contactsOnly: true,
                        );
                      })
                    : const SizedBox.shrink(),
              ),
            ],
            _action(context.l10n.reconnectAccount, () => _reconnect(account)),
            if (account.enabled && account.errorCode == null)
              _action(context.l10n.contactsRetrySync, sync),
          ],
        ),
        AndroidEditorGroup(
          children: [
            _action(context.l10n.removeAction, () async {
              await controller.removeContactsAccount(account.id);
              if (mounted && independent) Navigator.pop(context);
            }),
          ],
        ),
      ],
    );
  }
}

final class _DavInput {
  const _DavInput(this.label, this.server, this.username, this.password);
  final String label, server, username, password;
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.nextcloud
          ? context.l10n.contactsAddNextcloud
          : context.l10n.contactsAddCardDav,
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            obscureText: false,
            decoration: InputDecoration(
              labelText: context.l10n.subscriptionName,
            ),
          ),
          TextField(
            controller: _server,
            obscureText: false,
            decoration: InputDecoration(
              labelText: context.l10n.contactsServerUrlLabel,
            ),
          ),
          if (!widget.nextcloud)
            TextField(
              controller: _username,
              obscureText: false,
              decoration: InputDecoration(
                labelText: context.l10n.contactsUsernameLabel,
              ),
            ),
          if (!widget.nextcloud)
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.contactsPasswordLabel,
              ),
            ),
          Text(context.l10n.contactsReadOnlyUse),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.connectAccountAction),
    content: TextField(
      controller: _password,
      obscureText: true,
      decoration: InputDecoration(
        labelText: context.l10n.contactsPasswordLabel,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: () {
          if (_password.text.isNotEmpty) {
            Navigator.pop(context, _password.text);
          }
        },
        child: Text(context.l10n.connectAccountAction),
      ),
    ],
  );
}
