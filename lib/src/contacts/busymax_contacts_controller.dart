import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:busystack_contacts/carddav.dart';
import 'package:busystack_contacts/google.dart';
import 'package:busystack_contacts/microsoft.dart';
import 'package:busystack_dav/carddav.dart';
import 'package:busystack_dav/nextcloud.dart';
import 'package:busystack_graph/busystack_graph.dart';
import 'package:http/http.dart' as http;

import '../core/auth/account_token_broker.dart';
import '../core/auth/authorization_attempt.dart';
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
    this.providerFactory,
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
  final ContactsProvider Function(ContactAccount)? providerFactory;

  final Map<String, Future<void>> _syncing = <String, Future<void>>{};
  Timer? _timer;
  Future<void>? _startFuture;
  Future<void>? _closeFuture;
  bool _closed = false;
  final Set<Future<void>> _background = {};
  final Map<String, _ContactsEnrollment> _enrollments = {};
  final Logger _log = Logger('busymax.contacts');

  void _launch(Future<void> Function() action) {
    if (_closed) return;
    late final Future<void> observed;
    observed = Future<void>.sync(action)
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            if (error is ContactsException &&
                error.kind == ContactsFailure.cancelled) {
              return;
            }
            _log.warning('Scheduled contacts work failed', error, stack);
          },
        )
        .whenComplete(() => _background.remove(observed));
    _background.add(observed);
  }

  Future<void> _drain(Iterable<Future<void>> work) => Future.wait(
    work.map(
      (future) => future.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      ),
    ),
  );

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
    if (contactAccounts.any((account) => account.enabled)) {
      _ensureScheduling();
      _launch(synchronizeAll);
    }
  }

  void startInBackground() => _launch(start);
  void _ensureScheduling() {
    if (!_closed && _timer == null) {
      _timer = Timer.periodic(syncInterval, (_) => _launch(synchronizeAll));
    }
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
    final currentSelection = await store.selection(
      busyMaxAccountId: busyMaxAccountId,
    );
    return recipients
        .where(
          (recipient) => recipient.identities.any(
            (identity) =>
                currentSelection.accountIds.contains(identity.accountId) &&
                currentSelection.sourceKeys.contains(
                  jsonEncode([
                    identity.accountId,
                    identity.provider.name,
                    identity.sourceId,
                  ]),
                ),
          ),
        )
        .map(
          (recipient) => BusyMaxContactSuggestion(
            displayName: recipient.name,
            email: recipient.email,
            identities: recipient.identities,
          ),
        )
        .toList(growable: false);
  }

  Future<bool> suggestionEligible(
    BusyMaxContactSuggestion suggestion, {
    required String busyMaxAccountId,
  }) async {
    if (_closed) return false;
    final selected = await store.selection(busyMaxAccountId: busyMaxAccountId);
    for (final identity in suggestion.identities) {
      final key = jsonEncode([
        identity.accountId,
        identity.provider.name,
        identity.sourceId,
      ]);
      if (!selected.accountIds.contains(identity.accountId) ||
          !selected.sourceKeys.contains(key)) {
        continue;
      }
      final record = await store.read((tx) => tx.contact(identity));
      if (record?.projection.emails.any(
            (email) =>
                email.value.toLowerCase() == suggestion.email.toLowerCase(),
          ) ==
          true) {
        return true;
      }
    }
    return false;
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

  Future<T> _enroll<T>(
    String key,
    Future<T> Function(_ContactsEnrollment) action,
  ) async {
    if (_closed) {
      throw const ContactsException(ContactsFailure.cancelled, 'closed');
    }
    if (_enrollments.containsKey(key)) {
      throw const ContactsException(
        ContactsFailure.cancelled,
        'enrollment-in-progress',
      );
    }
    final attempt = _ContactsEnrollment();
    _enrollments[key] = attempt;
    try {
      return await action(attempt);
    } finally {
      attempt.cancel();
      _enrollments.remove(key);
      attempt.done.complete();
    }
  }

  Future<void> _cancelEnrollment(String key) async {
    final attempt = _enrollments[key];
    if (attempt == null) return;
    attempt.cancel();
    await attempt.done.future;
  }

  void _checkEnrollment(_ContactsEnrollment attempt) {
    if (_closed || attempt.cancelled) {
      throw const ContactsException(
        ContactsFailure.cancelled,
        'stale-enrollment',
      );
    }
  }

  Future<void> enableLinkedContacts(
    String busyMaxAccountId, {
    bool writable = false,
  }) => _enroll(linkedContactAccountId(busyMaxAccountId), (attempt) async {
    await start();
    _checkEnrollment(attempt);
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
    var contactAccount = ContactAccount(
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
      cancellation: attempt.authorization,
      persistContacts: () async {
        _checkEnrollment(attempt);
        final granted = await accounts.accountById(busyMaxAccountId);
        if (granted == null ||
            granted.providerAccountId != parent.providerAccountId ||
            granted.provider != parent.provider ||
            granted.tenantId != parent.tenantId) {
          throw const ContactsException(
            ContactsFailure.cancelled,
            'parent-account-changed',
          );
        }
        final scopes = granted.grantedScopes
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toSet();
        if (!scopes.any(
          (scope) =>
              scope.toLowerCase() == grantedScopes.single.toLowerCase() ||
              !writable &&
                  scope.toLowerCase() ==
                      (provider == ContactProviderKind.google
                          ? googleContactsWriteScope
                          : 'contacts.readwrite'),
        )) {
          throw const ContactsException(
            ContactsFailure.permission,
            'contacts-permission-not-granted',
          );
        }
        contactAccount = ContactAccount(
          id: contactAccount.id,
          provider: contactAccount.provider,
          displayName: contactAccount.displayName,
          subject: contactAccount.subject,
          grantedScopes: scopes,
          generation: contactAccount.generation,
        );
        await store.persistLinkedAccount(
          account: contactAccount,
          busyMaxAccountId: busyMaxAccountId,
          reuseAuthorization: true,
        );
      },
    );
    _checkEnrollment(attempt);
    store.contactConfigurationChanged();
    if (previous?.enabled == true) await _detachForReplacement(contactId);
    _checkEnrollment(attempt);
    try {
      await _bind(contactAccount);
    } on Object {
      await store.write(
        (tx) => tx.putAccount(
          contactAccount.copy(enabled: false, errorCode: 'reconnect-required'),
        ),
      );
      rethrow;
    }
    _ensureScheduling();
    _launch(() => synchronizeAccount(contactId));
  });

  Future<void> _detachForReplacement(String id) async {
    await directory.detach(id);
    final running = _syncing[id];
    if (running != null) {
      try {
        await running;
      } on Object {
        /* The original caller owns the error. */
      }
    }
  }

  Future<void> enableLinkedNextcloudContacts(
    String busyMaxAccountId, {
    bool writable = false,
  }) => _enroll(linkedContactAccountId(busyMaxAccountId), (attempt) async {
    await start();
    _checkEnrollment(attempt);
    final parent = await accounts.accountById(busyMaxAccountId);
    if (parent == null || parent.provider != BusyProvider.nextcloud) {
      throw StateError('The selected Nextcloud account is unavailable.');
    }
    final credential = await readLinkedDavCredential(busyMaxAccountId);
    if (credential == null) {
      throw StateError('The selected Nextcloud credential is unavailable.');
    }
    _checkEnrollment(attempt);
    final current = await accounts.accountById(busyMaxAccountId);
    if (current?.providerAccountId != parent.providerAccountId ||
        current?.provider != parent.provider) {
      throw const ContactsException(
        ContactsFailure.cancelled,
        'parent-account-changed',
      );
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
    await store.saveLinkedAccount(
      account: contactAccount,
      busyMaxAccountId: busyMaxAccountId,
      reuseAuthorization: true,
    );
    if (previous?.enabled == true) await _detachForReplacement(contactId);
    _checkEnrollment(attempt);
    await _bind(contactAccount);
    _ensureScheduling();
    _launch(() => synchronizeAccount(contactId));
  });

  Future<ContactAccount> addCardDavContactsOnly({
    required String id,
    required String label,
    required Uri server,
    required String username,
    required String password,
    bool readOnly = false,
    bool nextcloud = false,
  }) => _enroll(
    id,
    (attempt) => _addCardDav(
      attempt,
      id: id,
      label: label,
      server: server,
      username: username,
      password: password,
      readOnly: readOnly,
      nextcloud: nextcloud,
    ),
  );

  Future<ContactAccount> _addCardDav(
    _ContactsEnrollment attempt, {
    required String id,
    required String label,
    required Uri server,
    required String username,
    required String password,
    required bool readOnly,
    required bool nextcloud,
  }) async {
    await start();
    _checkEnrollment(attempt);
    _requireDavServer(server);
    if (await store.read((tx) => tx.account(id)) != null) {
      throw StateError('Contacts account already exists');
    }
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
    var durable = false;
    try {
      _checkEnrollment(attempt);
      await writeDavSecret(id, secret);
      _checkEnrollment(attempt);
      await store.write((tx) => tx.putAccount(account));
      durable = true;
      _checkEnrollment(attempt);
      await _bind(account);
      _ensureScheduling();
      await synchronizeAccount(id);
      return account;
    } on Object catch (error, stack) {
      try {
        if (durable) {
          await directory.disconnect(id);
          await store.write((tx) async {
            final current = await tx.account(id);
            if (current != null) {
              await tx.putAccount(
                current.copy(errorCode: 'reconnect-required'),
              );
            }
          });
        } else {
          await deleteDavSecret(id);
        }
      } on Object catch (cleanup, cleanupStack) {
        _log.warning(
          'Contacts enrollment cleanup failed',
          cleanup,
          cleanupStack,
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<ContactAccount> addNextcloudContactsOnly({
    required String id,
    required String label,
    required Uri server,
    bool readOnly = false,
  }) => _enroll(id, (attempt) async {
    final cancellation = DavCancellationToken();
    final flow = NextcloudLoginFlowV2(
      server: server,
      launchBrowser: launchBrowser,
      client: httpClient,
    );
    attempt.onCancel = () {
      cancellation.cancel();
      flow.close();
    };
    try {
      final credential = await flow.authenticate(cancellation);
      _checkEnrollment(attempt);
      return await _addCardDav(
        attempt,
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
  });

  Future<void> synchronizeAll() async {
    if (_closed) return;
    final accounts = await store.read((tx) => tx.accounts());
    await Future.wait([
      for (final account in accounts.where((value) => value.enabled))
        synchronizeAccount(account.id),
    ]);
  }

  Future<void> synchronizeAccount(String id) => _syncing.putIfAbsent(
    id,
    () => _synchronize(id).whenComplete(() {
      _syncing.remove(id);
    }),
  );

  Future<void> _synchronize(String id) async {
    final captured = await store.read((tx) => tx.account(id));
    try {
      final sources = await directory.discover(id);
      await directory.resumeQueued(id);
      for (final source in sources) {
        if (_closed) {
          throw const ContactsException(ContactsFailure.cancelled, 'closed');
        }
        final current = await store.read((tx) => tx.account(id));
        if (current?.generation != captured?.generation ||
            current?.enabled != true) {
          throw const ContactsException(
            ContactsFailure.cancelled,
            'stale-account-operation',
          );
        }
        if (source.capabilities.read) await directory.synchronize(source.key);
      }
      await _setAccountError(id, captured?.generation, null);
    } on Object catch (error, stack) {
      if (!(error is ContactsException &&
          error.kind == ContactsFailure.cancelled)) {
        try {
          await _setAccountError(
            id,
            captured?.generation,
            error is ContactsException ? error.code : 'contacts-sync-failed',
          );
        } on Object catch (cleanup, cleanupStack) {
          _log.warning(
            'Could not persist contacts failure status',
            cleanup,
            cleanupStack,
          );
        }
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> _setAccountError(String id, int? generation, String? error) =>
      store.write((tx) async {
        final account = await tx.account(id);
        if (account != null &&
            account.enabled &&
            account.generation == generation) {
          await tx.putAccount(account.copy(errorCode: error));
        }
      });

  Future<void> _bind(ContactAccount account) async {
    if (_closed) {
      throw const ContactsException(ContactsFailure.cancelled, 'closed');
    }
    if (providerFactory != null) {
      directory.bind(
        providerFactory!(account),
        accountGeneration: account.generation,
      );
      return;
    }
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
          accountGeneration: account.generation,
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
          accountGeneration: account.generation,
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
        directory.bind(
          _davProvider(account, config),
          accountGeneration: account.generation,
        );
    }
  }

  CardDavContactsProvider _davProvider(
    ContactAccount account,
    Map<String, dynamic> config,
  ) {
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
    return CardDavContactsProvider(
      accountId: account.id,
      client: CardDavClient(resources),
      cachedRecord: (identity) => store.read((tx) => tx.contact(identity)),
      readOnly: config['readOnly'] == true,
    );
  }

  Future<void> removeLinkedAccount(String busyMaxAccountId) async {
    final id = linkedContactAccountId(busyMaxAccountId);
    await _cancelEnrollment(id);
    final account = await store.read((tx) => tx.account(id));
    if (account == null) return;
    await directory.disconnect(id, remove: true);
  }

  /// Cancels and drains provider work before the parent authorization is
  /// removed. Data is retained, disabled and recoverable until the parent's
  /// database transaction commits.
  Future<void> prepareLinkedAccountRemoval(String busyMaxAccountId) async {
    final id = linkedContactAccountId(busyMaxAccountId);
    await _cancelEnrollment(id);
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
    await _cancelEnrollment(id);
    final account = await store.read((tx) => tx.account(id));
    if (account == null || account.enabled) return;
    final restored = account.copy(
      enabled: true,
      generation: account.generation + 1,
    );
    await store.write((tx) => tx.putAccount(restored));
    await _bind(restored);
    _launch(() => synchronizeAccount(id));
  }

  void linkedAccountRemovalCommitted() => store.contactConfigurationChanged();

  Future<void> removeContactsAccount(String id) async {
    await _cancelEnrollment(id);
    final account = await store.read((tx) => tx.account(id));
    if (account == null) return;
    await directory.disconnect(id, remove: true);
    if (account.provider == ContactProviderKind.carddav) {
      await deleteDavSecret(id);
    }
  }

  Future<void> disableContactsAccount(String id) async {
    await _cancelEnrollment(id);
    await directory.disconnect(id);
  }

  Future<bool> isIndependentNextcloud(String id) async {
    final encoded = await readDavSecret(id);
    return encoded != null && (jsonDecode(encoded) as Map)['nextcloud'] == true;
  }

  Future<void> reconnectContactsAccount(String id) async {
    final account = await store.read((tx) => tx.account(id));
    if (account == null) throw StateError('Contacts account unavailable');
    final parent = await store.linkedBusyMaxAccount(id);
    final writable = account.grantedScopes.any(
      (s) =>
          s.toLowerCase() == 'contacts.readwrite' ||
          s == googleContactsWriteScope ||
          s == 'carddav:write',
    );
    if (parent != null) {
      if (account.provider == ContactProviderKind.carddav) {
        await enableLinkedNextcloudContacts(parent, writable: writable);
      } else {
        await enableLinkedContacts(parent, writable: writable);
      }
      return;
    }
    await reconnectDavContactsOnly(id);
  }

  Future<void> reconnectDavContactsOnly(
    String id, {
    String? password,
    bool? readOnly,
  }) => _enroll(id, (attempt) async {
    await start();
    _checkEnrollment(attempt);
    final previous = await store.read((tx) => tx.account(id));
    final encoded = await readDavSecret(id);
    if (previous == null ||
        previous.provider != ContactProviderKind.carddav ||
        encoded == null ||
        await store.linkedBusyMaxAccount(id) != null) {
      throw StateError('Independent DAV account unavailable');
    }
    final config = (jsonDecode(encoded) as Map).cast<String, dynamic>();
    if (password != null) {
      if (password.isEmpty) {
        throw const ContactsException(
          ContactsFailure.validation,
          'password-required',
        );
      }
      config['password'] = password;
    } else if (config['nextcloud'] == true && readOnly == null) {
      final token = DavCancellationToken();
      final flow = NextcloudLoginFlowV2(
        server: Uri.parse(config['server'] as String),
        client: httpClient,
        launchBrowser: launchBrowser,
      );
      attempt.onCancel = () {
        token.cancel();
        flow.close();
      };
      try {
        final result = await flow.authenticate(token);
        _checkEnrollment(attempt);
        if (result.loginName != config['username'] ||
            result.server.origin !=
                Uri.parse(config['server'] as String).origin) {
          throw const ContactsException(
            ContactsFailure.authentication,
            'wrong-contact-identity',
          );
        }
        config['password'] = result.appPassword;
      } finally {
        flow.close();
      }
    }
    if (readOnly != null) config['readOnly'] = readOnly;
    final replacement = ContactAccount(
      id: previous.id,
      provider: previous.provider,
      displayName: previous.displayName,
      subject: previous.subject,
      enabled: true,
      generation: previous.generation + 1,
      grantedScopes: {
        config['readOnly'] == true ? 'carddav:read' : 'carddav:write',
      },
    );
    final provider = _davProvider(replacement, config);
    final cancellation = ContactsCancellationToken();
    attempt.onCancel = cancellation.cancel;
    try {
      if ((await provider.discover(cancellation)).isEmpty) {
        throw const ContactsException(
          ContactsFailure.permission,
          'no-readable-address-books',
        );
      }
    } finally {
      provider.close();
    }
    _checkEnrollment(attempt);
    final next = jsonEncode(config);
    var durable = false;
    try {
      await writeDavSecret(id, next);
      _checkEnrollment(attempt);
      await store.write((tx) => tx.putAccount(replacement));
      durable = true;
      await _detachForReplacement(id);
      _checkEnrollment(attempt);
      await _bind(replacement);
    } on Object catch (error, stack) {
      try {
        if (!durable) {
          await writeDavSecret(id, encoded);
        } else {
          await directory.detach(id);
          await store.write(
            (tx) => tx.putAccount(
              replacement.copy(enabled: false, errorCode: 'reconnect-required'),
            ),
          );
        }
      } on Object catch (cleanup, cleanupStack) {
        _log.warning('DAV reconnect cleanup failed', cleanup, cleanupStack);
      }
      Error.throwWithStackTrace(error, stack);
    }
    _ensureScheduling();
    await synchronizeAccount(id);
  });

  Future<void> setSourceEnabled(String sourceKey, {required bool enabled}) {
    return store.setSourceEnabled(sourceKey, enabled: enabled);
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closed = true;
    _timer?.cancel();
    Object? failure;
    StackTrace? failureStack;
    Future<void> cleanup(Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (error, stack) {
        failure ??= error;
        failureStack ??= stack;
        _log.warning('Contacts shutdown cleanup failed', error, stack);
      }
    }

    final attempts = _enrollments.values.toList();
    for (final attempt in attempts) {
      attempt.cancel();
    }
    await cleanup(
      () => Future.wait(attempts.map((attempt) => attempt.done.future)),
    );
    if (_startFuture != null) await cleanup(() => _drain([_startFuture!]));
    await cleanup(directory.close);
    await cleanup(() => _drain([..._syncing.values, ..._background]));
    await cleanup(store.close);
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
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

final class _ContactsEnrollment {
  final AuthorizationCancellation authorization = AuthorizationCancellation();
  final Completer<void> done = Zone.root.run(Completer<void>.new);
  bool cancelled = false;
  void Function()? onCancel;
  void cancel() {
    cancelled = true;
    authorization.cancel();
    onCancel?.call();
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
