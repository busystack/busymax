import 'dart:async';
import 'dart:convert';

import 'package:busystack_contacts/carddav.dart';
import 'package:busystack_contacts/google.dart';
import 'package:busystack_contacts/microsoft.dart';
import 'package:busystack_dav/carddav.dart';
import 'package:busystack_dav/nextcloud.dart';
import 'package:busystack_graph/busystack_graph.dart';
import 'package:http/http.dart' as http;

import '../core/auth/account_token_broker.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../google_tasks/oauth/oauth_service.dart';
import '../providers/busy_provider.dart';
import 'busymax_contacts_store.dart';

typedef DavContactSecretReader = Future<String?> Function(String accountId);
typedef DavContactSecretWriter = Future<void> Function(
  String accountId,
  String value,
);
typedef DavContactSecretDeleter = Future<void> Function(String accountId);

final class BusyMaxLinkedDavCredential {
  const BusyMaxLinkedDavCredential({
    required this.server,
    required this.username,
    required this.password,
  });

  final Uri server;
  final String username;
  final String password;
}

final class BusyMaxContactSuggestion {
  const BusyMaxContactSuggestion({
    required this.displayName,
    required this.email,
    required this.identities,
  });

  final String displayName;
  final String email;
  final List<ContactIdentity> identities;
}

final class BusyMaxContactSourceSetting {
  const BusyMaxContactSourceSetting({
    required this.source,
    required this.enabled,
  });

  final ContactSource source;
  final bool enabled;
}

/// App-owned lifecycle and authorization adapter around the shared contacts
/// directory. Provider HTTP, normalization, sync and mutation behavior remain
/// in busystack_contacts; BusyMax owns its database, credentials and schedule.
final class BusyMaxContactsController {
  BusyMaxContactsController({
    required this.store,
    required this.accounts,
    required this.authorization,
    required this.httpClient,
    required this.readDavSecret,
    required this.writeDavSecret,
    required this.deleteDavSecret,
    required this.readLinkedDavCredential,
    required this.launchBrowser,
    this.syncInterval = const Duration(minutes: 15),
  }) : directory = ContactsDirectory(store: store);

  final BusyMaxContactsStore store;
  final AccountsRepository accounts;
  final ContactsAuthorizationBroker authorization;
  final http.Client httpClient;
  final DavContactSecretReader readDavSecret;
  final DavContactSecretWriter writeDavSecret;
  final DavContactSecretDeleter deleteDavSecret;
  final Future<BusyMaxLinkedDavCredential?> Function(String accountId)
  readLinkedDavCredential;
  final Future<bool> Function(Uri) launchBrowser;
  final Duration syncInterval;
  final ContactsDirectory directory;

  final Map<String, Future<void>> _syncing = <String, Future<void>>{};
  Timer? _timer;
  Future<void>? _startFuture;
  Future<void>? _closeFuture;
  bool _closed = false;

  Stream<void> get changes => store.changes;

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    await directory.restore();
    final contactAccounts = await store.read((tx) => tx.accounts());
    for (final account in contactAccounts) {
      if (!account.enabled) continue;
      try {
        await _bind(account);
      } on Object {
        await store.write((tx) async {
          final current = await tx.account(account.id);
          if (current != null) {
            await tx.putAccount(current.copy(errorCode: 'reconnect-required'));
          }
        });
      }
    }
    if (_closed) return;
    _timer = Timer.periodic(syncInterval, (_) => unawaited(synchronizeAll()));
    unawaited(synchronizeAll());
  }

  Future<List<BusyMaxContactSuggestion>> suggestAttendees(
    String query, {
    String? busyMaxAccountId,
    Set<String> excludedAddresses = const <String>{},
    int limit = 8,
  }) async {
    await start();
    final selection = await store.selection(busyMaxAccountId: busyMaxAccountId);
    if (selection.accountIds.isEmpty) return const [];
    final recipients = await directory.suggestRecipients(
      query.trim(),
      accountIds: selection.accountIds,
      sourceKeys: selection.sourceKeys,
      excludedAddresses: excludedAddresses,
      limit: limit,
    );
    return recipients
        .map(
          (recipient) => BusyMaxContactSuggestion(
            displayName: recipient.name,
            email: recipient.email,
            identities: recipient.identities,
          ),
        )
        .toList(growable: false);
  }

  Future<List<BusyMaxContactSourceSetting>> sourceSettings() async {
    final sources = await store.read((tx) => tx.sources());
    return Future.wait([
      for (final source in sources)
        store
            .sourceEnabled(source.key)
            .then(
              (enabled) =>
                  BusyMaxContactSourceSetting(source: source, enabled: enabled),
            ),
    ]);
  }

  Future<void> enableLinkedContacts(
    String busyMaxAccountId, {
    bool writable = false,
  }) async {
    await start();
    final parent = await accounts.accountById(busyMaxAccountId);
    if (parent == null ||
        parent.provider != BusyProvider.google &&
            parent.provider != BusyProvider.microsoft) {
      throw StateError('Only Google and Microsoft accounts can reuse OAuth.');
    }
    final contactId = linkedContactAccountId(busyMaxAccountId);
    final previous = await store.read((tx) => tx.account(contactId));
    final provider = parent.provider == BusyProvider.google
        ? ContactProviderKind.google
        : ContactProviderKind.microsoft;
    final grantedScopes = parent.provider == BusyProvider.google
        ? <String>{
            writable ? googleContactsWriteScope : googleContactsReadScope,
          }
        : <String>{writable ? 'Contacts.ReadWrite' : 'Contacts.Read'};
    final contactAccount = ContactAccount(
      id: contactId,
      provider: provider,
      displayName: parent.displayLabel,
      subject: parent.providerAccountId,
      grantedScopes: grantedScopes,
      generation: (previous?.generation ?? -1) + 1,
    );
    await authorization.authorizeContacts(
      parent.provider,
      busyMaxAccountId,
      writable: writable,
      persistContacts: () => store.persistLinkedAccount(
        account: contactAccount,
        busyMaxAccountId: busyMaxAccountId,
        reuseAuthorization: true,
      ),
    );
    store.contactConfigurationChanged();
    if (previous?.enabled == true) await directory.disconnect(contactId);
    await _bind(contactAccount);
    unawaited(synchronizeAccount(contactId));
  }

  Future<void> enableLinkedNextcloudContacts(
    String busyMaxAccountId, {
    bool writable = false,
  }) async {
    await start();
    final parent = await accounts.accountById(busyMaxAccountId);
    if (parent == null || parent.provider != BusyProvider.nextcloud) {
      throw StateError('The selected Nextcloud account is unavailable.');
    }
    final credential = await readLinkedDavCredential(busyMaxAccountId);
    if (credential == null) {
      throw StateError('The selected Nextcloud credential is unavailable.');
    }
    final contactId = linkedContactAccountId(busyMaxAccountId);
    final previous = await store.read((tx) => tx.account(contactId));
    final contactAccount = ContactAccount(
      id: contactId,
      provider: ContactProviderKind.carddav,
      displayName: parent.displayLabel,
      subject: credential.username,
      grantedScopes: <String>{
        if (writable) 'carddav:write' else 'carddav:read',
      },
      generation: (previous?.generation ?? -1) + 1,
    );
    if (previous?.enabled == true) await directory.disconnect(contactId);
    await store.saveLinkedAccount(
      account: contactAccount,
      busyMaxAccountId: busyMaxAccountId,
      reuseAuthorization: true,
    );
    await _bind(contactAccount);
    unawaited(synchronizeAccount(contactId));
  }

  Future<ContactAccount> addCardDavContactsOnly({
    required String id,
    required String label,
    required Uri server,
    required String username,
    required String password,
    bool readOnly = false,
    bool nextcloud = false,
  }) async {
    await start();
    _requireDavServer(server);
    final credential = DavBasicCredential(
      username: username,
      password: password,
    );
    final account = ContactAccount(
      id: id,
      provider: ContactProviderKind.carddav,
      displayName: label,
      subject: username,
      grantedScopes: <String>{
        if (readOnly) 'carddav:read' else 'carddav:write',
      },
    );
    final secret = jsonEncode(<String, Object?>{
      'version': 1,
      'server': server.toString(),
      'username': credential.username,
      'password': password,
      'readOnly': readOnly,
      'nextcloud': nextcloud,
    });
    await writeDavSecret(id, secret);
    try {
      await store.write((tx) => tx.putAccount(account));
      await _bind(account);
      await synchronizeAccount(id);
      return account;
    } on Object {
      await directory.disconnect(id, remove: true);
      await deleteDavSecret(id);
      rethrow;
    }
  }

  Future<ContactAccount> addNextcloudContactsOnly({
    required String id,
    required String label,
    required Uri server,
    bool readOnly = false,
  }) async {
    final cancellation = DavCancellationToken();
    final flow = NextcloudLoginFlowV2(
      server: server,
      launchBrowser: launchBrowser,
      client: httpClient,
    );
    try {
      final credential = await flow.authenticate(cancellation);
      return await addCardDavContactsOnly(
        id: id,
        label: label,
        server: credential.server,
        username: credential.loginName,
        password: credential.appPassword,
        readOnly: readOnly,
        nextcloud: true,
      );
    } finally {
      flow.close();
    }
  }

  Future<void> synchronizeAll() async {
    if (_closed) return;
    final accounts = await store.read((tx) => tx.accounts());
    for (final account in accounts.where((value) => value.enabled)) {
      unawaited(synchronizeAccount(account.id));
    }
  }

  Future<void> synchronizeAccount(String id) => _syncing.putIfAbsent(
    id,
    () => _synchronize(id).whenComplete(() => _syncing.remove(id)),
  );

  Future<void> _synchronize(String id) async {
    try {
      final sources = await directory.discover(id);
      await directory.resumeQueued(id);
      for (final source in sources) {
        if (_closed) return;
        if (source.capabilities.read) await directory.synchronize(source.key);
      }
      await _setAccountError(id, null);
    } on Object {
      await _setAccountError(id, 'contacts-sync-failed');
      rethrow;
    }
  }

  Future<void> _setAccountError(String id, String? error) => store.write((
    tx,
  ) async {
    final account = await tx.account(id);
    if (account != null) await tx.putAccount(account.copy(errorCode: error));
  });

  Future<void> _bind(ContactAccount account) async {
    switch (account.provider) {
      case ContactProviderKind.google:
        final parentId = await store.linkedBusyMaxAccount(account.id);
        if (parentId == null) throw StateError('Google contacts link missing.');
        directory.bind(
          GoogleContactsProvider(
            accountId: account.id,
            authorizedClient: _BusyMaxGoogleContactsClient(
              authorization: authorization,
              accountId: parentId,
              writable: account.grantedScopes.contains(
                googleContactsWriteScope,
              ),
              inner: httpClient,
            ),
            grantedScopes: account.grantedScopes,
            publicPhotoClient: httpClient,
          ),
        );
      case ContactProviderKind.microsoft:
        final parentId = await store.linkedBusyMaxAccount(account.id);
        if (parentId == null) {
          throw StateError('Microsoft contacts link missing.');
        }
        final parent = await accounts.accountById(parentId);
        final writable = account.grantedScopes.any(
          (scope) => scope.toLowerCase() == 'contacts.readwrite',
        );
        directory.bind(
          MicrosoftContactsProvider(
            accountId: account.id,
            graph: GraphClient(
              httpClient: httpClient,
              tokenProvider: ({claims}) async => GraphAuthorization(
                (await authorization.contactsAuthorizationHeader(
                  BusyProvider.microsoft,
                  parentId,
                  writable: writable,
                  claims: claims,
                )).replaceFirst(RegExp(r'^Bearer '), ''),
                grantedScopes: account.grantedScopes,
              ),
            ),
            grantedScopes: account.grantedScopes,
            personalAccount:
                parent?.tenantId == '9188040d-6c67-4c5b-b112-36a304b66dad',
          ),
        );
      case ContactProviderKind.carddav:
        final parentId = await store.linkedBusyMaxAccount(account.id);
        final linked = parentId == null
            ? null
            : await readLinkedDavCredential(parentId);
        final encoded = linked == null ? await readDavSecret(account.id) : null;
        if (linked == null && encoded == null) {
          throw StateError('CardDAV credential missing.');
        }
        final config = encoded == null
            ? <String, dynamic>{
                'version': 1,
                'server': linked!.server.toString(),
                'username': linked.username,
                'password': linked.password,
                'readOnly': !account.grantedScopes.contains('carddav:write'),
                'nextcloud': true,
              }
            : (jsonDecode(encoded) as Map).cast<String, dynamic>();
        if (config['version'] != 1) {
          throw const FormatException('Unsupported CardDAV credential.');
        }
        final server = Uri.parse(config['server'] as String);
        _requireDavServer(server);
        final profile = config['nextcloud'] == true
            ? const DavProviderProfile.nextcloud()
            : const DavProviderProfile();
        final resources = DavResourceClient(
          accountId: account.id,
          authority: server,
          profile: profile,
          transport: DavHttpTransport(
            client: httpClient,
            profile: profile,
            accountAuthority: server,
          ),
          streaming: DavTransferClient(
            client: httpClient,
            authority: server,
            profile: profile,
          ),
          credentialProvider: () async => DavBasicCredential(
            username: config['username'] as String,
            password: config['password'] as String,
          ),
        );
        directory.bind(
          CardDavContactsProvider(
            accountId: account.id,
            client: CardDavClient(resources),
            cachedRecord: (identity) =>
                store.read((tx) => tx.contact(identity)),
            readOnly: config['readOnly'] == true,
          ),
        );
    }
  }

  Future<void> removeLinkedAccount(String busyMaxAccountId) async {
    final id = linkedContactAccountId(busyMaxAccountId);
    final account = await store.read((tx) => tx.account(id));
    if (account == null) return;
    await directory.disconnect(id, remove: true);
  }

  /// Cancels and drains provider work before the parent authorization is
  /// removed. Data is retained, disabled and recoverable until the parent's
  /// database transaction commits.
  Future<void> prepareLinkedAccountRemoval(String busyMaxAccountId) async {
    final id = linkedContactAccountId(busyMaxAccountId);
    final account = await store.read((tx) => tx.account(id));
    if (account?.enabled == true) await directory.disconnect(id);
  }

  /// Called inside the parent's account-removal database transaction.
  Future<void> persistLinkedAccountRemoval(String busyMaxAccountId) =>
      store.persistRemoveAccount(linkedContactAccountId(busyMaxAccountId));

  Future<void> restoreLinkedAccountAfterFailedRemoval(
    String busyMaxAccountId,
  ) async {
    final id = linkedContactAccountId(busyMaxAccountId);
    final account = await store.read((tx) => tx.account(id));
    if (account == null || account.enabled) return;
    final restored = account.copy(
      enabled: true,
      generation: account.generation + 1,
    );
    await store.write((tx) => tx.putAccount(restored));
    await _bind(restored);
    unawaited(synchronizeAccount(id));
  }

  void linkedAccountRemovalCommitted() => store.contactConfigurationChanged();

  Future<void> removeContactsAccount(String id) async {
    final account = await store.read((tx) => tx.account(id));
    if (account == null) return;
    await directory.disconnect(id, remove: true);
    if (account.provider == ContactProviderKind.carddav) {
      await deleteDavSecret(id);
    }
  }

  Future<void> setSourceEnabled(String sourceKey, {required bool enabled}) {
    return store.setSourceEnabled(sourceKey, enabled: enabled);
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closed = true;
    _timer?.cancel();
    await directory.close();
    await Future.wait(_syncing.values.toList());
    await store.close();
  }

  static String linkedContactAccountId(String busyMaxAccountId) =>
      'contacts:$busyMaxAccountId';

  static void _requireDavServer(Uri server) {
    if (server.scheme != 'https' ||
        server.host.isEmpty ||
        server.userInfo.isNotEmpty ||
        server.hasFragment) {
      throw const FormatException('An HTTPS CardDAV server is required.');
    }
  }
}

final class _BusyMaxGoogleContactsClient extends http.BaseClient {
  _BusyMaxGoogleContactsClient({
    required this.authorization,
    required this.accountId,
    required this.writable,
    required this.inner,
  });

  final ContactsAuthorizationBroker authorization;
  final String accountId;
  final bool writable;
  final http.Client inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['authorization'] = await authorization
        .contactsAuthorizationHeader(
          BusyProvider.google,
          accountId,
          writable: writable,
        );
    return inner.send(request);
  }

  // The app owns the shared HTTP client.
  @override
  void close() {}
}
