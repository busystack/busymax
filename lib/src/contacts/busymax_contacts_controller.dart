import '../dav/trust/nextcloud_leased_http_client.dart';
import '../features/sync/account_sync_operations.dart';
import '../dav/trust/nextcloud_http_client_factory.dart';
import '../dav/trust/nextcloud_trust_policy.dart';
import '../dav/auth/dav_account_onboarding_service.dart'
    show NextcloudTrustReviewer;

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
import '../core/auth/oauth_models.dart';
import '../core/secrets/secret_store.dart';
import '../core/auth/microsoft_graph_scopes.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../google_tasks/oauth/oauth_service.dart';
import '../providers/busy_provider.dart';
import '../providers/account_authority.dart';
import 'busymax_contacts_store.dart';
import 'read_only_contacts_provider.dart';

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
    ContactsProvider Function(ContactAccount)? providerFactory,
    this.readAuthorizationGeneration,
    this.reconnectLinkedDavAccount,
    this.nextcloudClients,
    this.linkedNextcloudClient,
    this.accountGate = const InProcessAccountGate(),
  }) : _providerFactory = providerFactory,
       directory = ContactsDirectory(store: store);

  final BusyMaxContactsStore store;
  final AccountsRepository accounts;
  final ContactsAuthorizationBroker authorization;
  final http.Client httpClient;
  final CrossEngineAccountGate accountGate;
  final NextcloudHttpClientFactory? nextcloudClients;
  final http.Client Function(String)? linkedNextcloudClient;
  final DavContactSecretReader readDavSecret;
  final DavContactSecretWriter writeDavSecret;
  final DavContactSecretDeleter deleteDavSecret;
  final Future<BusyMaxLinkedDavCredential?> Function(String accountId)
  readLinkedDavCredential;
  final Future<bool> Function(Uri) launchBrowser;
  final Duration syncInterval;
  final ContactsDirectory directory;
  final ContactsProvider Function(ContactAccount)? _providerFactory;
  final Future<int> Function(String accountId)? readAuthorizationGeneration;
  final Future<void> Function(
    String accountId,
    AuthorizationCancellation cancellation,
  )?
  reconnectLinkedDavAccount;

  final Map<String, Future<void>> _syncing = <String, Future<void>>{};
  Timer? _timer;
  Future<void>? _startFuture;
  Future<void>? _closeFuture;
  bool _closed = false;
  final Set<Future<void>> _background = {};
  final Map<String, _ContactsEnrollment> _enrollments = {};
  final Map<String, _LinkedAccountRemoval> _linkedRemovals = {};
  final Map<String, int> _boundGenerations = {};
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
    await store.normalizeReadOnlySources();
    await directory.restore();
    final contactAccounts = await store.read((tx) => tx.accounts());
    for (final account in contactAccounts) {
      if (!account.enabled) continue;
      try {
        await _bind(account);
      } on Object catch (error) {
        await store.write((tx) async {
          final current = await tx.account(account.id);
          if (current != null) {
            await tx.putAccount(
              current.copy(
                errorCode: error is NextcloudCertificateException
                    ? error.code
                    : 'reconnect-required',
              ),
            );
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
    if (_linkedRemovals.containsKey(key)) {
      throw const ContactsException(
        ContactsFailure.cancelled,
        'parent-account-removing',
      );
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

  void cancelEnrollment(String id) {
    _enrollments[id]?.cancel();
    _enrollments[linkedContactAccountId(id)]?.cancel();
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
    bool forceAuthorization = false,
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
        ? <String>{googleContactsReadScope}
        : <String>{'Contacts.Read'};
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
      cancellation: attempt.authorization,
      forceAuthorization: forceAuthorization,
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
            // The shared contacts adapter consumes short Graph scope names;
            // parent metadata and credentials retain the provider's grant text.
            .map(
              (scope) =>
                  provider == ContactProviderKind.microsoft &&
                      scope.toLowerCase().startsWith(
                        'https://graph.microsoft.com/',
                      )
                  ? scope.substring('https://graph.microsoft.com/'.length)
                  : scope,
            )
            .toSet();
        if (!scopes.any(
          (scope) =>
              microsoftGraphScopeName(scope) ==
                  microsoftGraphScopeName(grantedScopes.single) ||
              microsoftGraphScopeName(scope) ==
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
    attempt.committed = true;
    if (_closed) return;
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
    await _detachBinding(id);
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
    bool reconnect = false,
  }) => _enroll(linkedContactAccountId(busyMaxAccountId), (attempt) async {
    await start();
    _checkEnrollment(attempt);
    if (reconnect) {
      final recover = reconnectLinkedDavAccount;
      if (recover == null) {
        throw const ContactsException(
          ContactsFailure.authentication,
          'reconnect-parent-account',
        );
      }
      await recover(busyMaxAccountId, attempt.authorization);
      attempt.committed = true;
      if (_closed) return;
    }
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
      grantedScopes: previous?.grantedScopes ?? <String>{'carddav:read'},
      generation: (previous?.generation ?? -1) + 1,
    );
    await store.saveLinkedAccount(
      account: contactAccount,
      busyMaxAccountId: busyMaxAccountId,
      reuseAuthorization: true,
      validate: () => _checkEnrollment(attempt),
    );
    attempt.committed = true;
    if (_closed) return;
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
    required bool nextcloud,
    NextcloudTrustPolicy? trustPolicy,
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
      grantedScopes: <String>{'carddav:read'},
    );
    final secret = jsonEncode(<String, Object?>{
      'version': 1,
      'server': server.toString(),
      'username': credential.username,
      'password': password,
      'readOnly': true,
      'nextcloud': nextcloud,
      if (trustPolicy != null)
        'trustPolicy': trustPolicy.bind('contacts:$id').toJson(),
      if (nextcloud) 'authorizationGeneration': account.generation,
    });
    if (nextcloud) {
      final candidate = _davProvider(
        account,
        (jsonDecode(secret) as Map).cast<String, dynamic>(),
        validationOnly: true,
      );
      final validation = ContactsCancellationToken();
      attempt.onCancel = validation.cancel;
      try {
        if ((await candidate.discover(validation)).isEmpty) {
          throw const ContactsException(
            ContactsFailure.permission,
            'no-readable-address-books',
          );
        }
        _checkEnrollment(attempt);
      } finally {
        candidate.close();
      }
    }
    var durable = false;
    try {
      _checkEnrollment(attempt);
      await _commitDavContactSecret(
        account,
        secret,
        null,
        null,
        () => _checkEnrollment(attempt),
      );
      durable = true;
      attempt.committed = true;
      if (_closed) return account;
      _checkEnrollment(attempt);
      await _bind(account);
      _ensureScheduling();
      await synchronizeAccount(id);
      return account;
    } on Object catch (error, stack) {
      try {
        if (durable) {
          _boundGenerations.remove(id);
          await directory.disconnect(id);
          await store.write((tx) async {
            final current = await tx.account(id);
            if (current != null) {
              await tx.putAccount(
                current.copy(errorCode: 'reconnect-required'),
              );
            }
          });
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
    NextcloudTrustReviewer? reviewCertificate,
  }) => _enroll(id, (attempt) async {
    final cancellation = DavCancellationToken();
    final owner =
        'contacts-onboarding:$id:${DateTime.now().microsecondsSinceEpoch}';
    NextcloudTrustPolicy? policy;
    Future<NextcloudLoginCredential> authenticate() async {
      final scoped = nextcloudClients?.create(
        owner: owner,
        authority: server,
        policy: policy,
      );
      final flow = NextcloudLoginFlowV2(
        server: server,
        launchBrowser: launchBrowser,
        client: scoped ?? httpClient,
      );
      attempt.onCancel = () {
        cancellation.cancel();
        flow.close();
        scoped?.close();
      };
      try {
        return await flow.authenticate(cancellation);
      } finally {
        flow.close();
        scoped?.close();
      }
    }

    try {
      NextcloudLoginCredential credential;
      try {
        credential = await authenticate();
      } on NextcloudCertificateException catch (challenge) {
        if (reviewCertificate == null) rethrow;
        policy = await reviewCertificate(challenge, owner);
        _checkEnrollment(attempt);
        cancellation.throwIfCancelled();
        if (policy == null) rethrow;
        policy.requireScope(owner, server);
        credential = await authenticate();
      }
      _checkEnrollment(attempt);
      if (normalizeNextcloudServerAuthority(server.toString()) !=
          normalizeNextcloudServerAuthority(credential.server.toString())) {
        throw const FormatException(
          'Untrusted Nextcloud canonical installation.',
        );
      }
      return await _addCardDav(
        attempt,
        id: id,
        label: label,
        server: credential.server,
        username: credential.loginName,
        password: credential.appPassword,
        nextcloud: true,
        trustPolicy: policy,
      );
    } finally {
      nextcloudClients?.invalidate(owner);
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
      if (captured?.provider == ContactProviderKind.carddav &&
          captured?.enabled == true &&
          _boundGenerations[id] != captured!.generation) {
        await _detachBinding(id);
        await _bind(captured);
      }
      if (_linkedRemovals[id] case final removal? when !removal.recovered) {
        throw const ContactsException(
          ContactsFailure.cancelled,
          'account-removal-in-progress',
        );
      }
      if (captured?.errorCode?.contains('NextcloudCertificate') == true) {
        throw ContactsException(
          ContactsFailure.protocol,
          captured!.errorCode!.split(':').last,
        );
      }
      if (captured?.errorCode == 'contacts-removal-recovery-required') {
        throw const ContactsException(
          ContactsFailure.unknownOutcome,
          'contacts-removal-recovery-required',
        );
      }
      final sources = await directory.discover(id);
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
            error is ContactsException
                ? error.code == 'contacts-removal-recovery-required' ||
                          error.code.startsWith('oauth:')
                      ? error.code
                      : 'contacts:${error.kind.name}:${error.code}'
                : 'contacts-sync-failed',
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

  Future<void> _bind(
    ContactAccount account, {
    void Function()? validateBinding,
  }) async {
    if (_closed) {
      throw const ContactsException(ContactsFailure.cancelled, 'closed');
    }
    if (_providerFactory != null) {
      validateBinding?.call();
      _bindProvider(
        _providerFactory(account),
        accountGeneration: account.generation,
      );
      _boundGenerations[account.id] = account.generation;
      return;
    }
    switch (account.provider) {
      case ContactProviderKind.google:
        final parentId = await store.linkedBusyMaxAccount(account.id);
        if (parentId == null) throw StateError('Google contacts link missing.');
        validateBinding?.call();
        _bindProvider(
          GoogleContactsProvider(
            accountId: account.id,
            authorizedClient: _BusyMaxGoogleContactsClient(
              authorization: authorization,
              accountId: parentId,
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
        validateBinding?.call();
        _bindProvider(
          MicrosoftContactsProvider(
            accountId: account.id,
            graph: GraphClient(
              httpClient: httpClient,
              tokenProvider: ({claims}) async => GraphAuthorization(
                (await _contactsAuthorizationHeader(
                  authorization,
                  BusyProvider.microsoft,
                  parentId,
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
        if (parentId == null && await store.hasAccountLink(account.id)) {
          throw const ContactsException(
            ContactsFailure.authentication,
            'linked-parent-removed',
          );
        }
        final linked = parentId == null
            ? null
            : await readLinkedDavCredential(parentId);
        if (parentId != null && linked == null) {
          throw const ContactsException(
            ContactsFailure.authentication,
            'linked-parent-authorization-unavailable',
          );
        }
        final encoded = linked == null ? await readDavSecret(account.id) : null;
        if (linked == null && encoded == null) {
          throw StateError('CardDAV credential missing.');
        }
        final config = encoded == null
            ? <String, dynamic>{
                'version': 1,
                'server': linked!.server.toString(),
                'username': linked.username,
                'readOnly': true,
                'nextcloud': true,
              }
            : _acceptedDavConfig(encoded, account);
        if (config['version'] != 1) {
          throw const FormatException('Unsupported CardDAV credential.');
        }
        validateBinding?.call();
        _bindProvider(
          _davProvider(
            account,
            config,
            scopedClient: parentId == null
                ? null
                : linkedNextcloudClient?.call(parentId),
            linkedCredential: parentId == null
                ? null
                : () => _currentLinkedDavCredential(
                    account,
                    parentId,
                    Uri.parse(config['server'] as String),
                    config['username'] as String,
                  ),
          ),
          accountGeneration: account.generation,
        );
    }
    _boundGenerations[account.id] = account.generation;
  }

  void _bindProvider(
    ContactsProvider provider, {
    required int accountGeneration,
  }) {
    directory.bind(
      ReadOnlyContactsProvider(provider),
      accountGeneration: accountGeneration,
    );
  }

  Future<void> _detachBinding(String id) {
    _boundGenerations.remove(id);
    return directory.detach(id);
  }

  CardDavContactsProvider _davProvider(
    ContactAccount account,
    Map<String, dynamic> config, {
    Future<DavBasicCredential> Function()? linkedCredential,
    http.Client? scopedClient,
    bool validationOnly = false,
    int? expectedDurableGeneration,
  }) {
    final server = Uri.parse(config['server'] as String);
    _requireDavServer(server);
    final profile = config['nextcloud'] == true
        ? const DavProviderProfile.nextcloud()
        : const DavProviderProfile();
    http.Client client =
        scopedClient ??
        (config['nextcloud'] == true && nextcloudClients != null
            ? nextcloudClients!.create(
                owner: 'contacts:${account.id}',
                authority: server,
                policy: config.containsKey('trustPolicy')
                    ? NextcloudTrustPolicy.fromJson(config['trustPolicy'])
                    : null,
              )
            : httpClient);
    if (config['nextcloud'] == true &&
        scopedClient == null &&
        nextcloudClients != null) {
      client = NextcloudLeasedHttpClient(
        delegate: client,
        runLease: (work) => accountGate.run('contacts:${account.id}', work),
        validate: () async {
          final current = await store.read((tx) => tx.account(account.id));
          if (_closed ||
              (validationOnly
                  ? current?.generation != expectedDurableGeneration
                  : current?.enabled != true ||
                        current?.generation != account.generation)) {
            throw const ContactsException(
              ContactsFailure.cancelled,
              'stale-nextcloud-contacts-policy',
            );
          }
        },
      );
    }
    final resources = DavResourceClient(
      accountId: account.id,
      authority: server,
      profile: profile,
      transport: DavHttpTransport(
        client: client,
        profile: profile,
        accountAuthority: server,
      ),
      streaming: DavTransferClient(
        client: client,
        authority: server,
        profile: profile,
      ),
      credentialProvider:
          linkedCredential ??
          () async => DavBasicCredential(
            username: config['username'] as String,
            password: config['password'] as String,
          ),
    );
    return CardDavContactsProvider(
      accountId: account.id,
      client: CardDavClient(resources),
      cachedRecord: (identity) => store.read((tx) => tx.contact(identity)),
      readOnly: true,
      disposeTransport: identical(client, httpClient) ? null : client.close,
    );
  }

  /// Linked contacts reuse the accepted parent credential for every request.
  /// Never retain an app password across parent reconnects, or fall back to an
  /// independent contact secret when a linked parent's authorization is gone.
  Future<DavBasicCredential> _currentLinkedDavCredential(
    ContactAccount account,
    String parentId,
    Uri server,
    String username,
  ) async {
    final credential = await readLinkedDavCredential(parentId);
    final current = await store.read((tx) => tx.account(account.id));
    if (_closed ||
        current?.enabled != true ||
        current?.generation != account.generation ||
        await store.linkedBusyMaxAccount(account.id) != parentId) {
      throw const ContactsException(
        ContactsFailure.cancelled,
        'stale-linked-contact-binding',
      );
    }
    final parent = await accounts.accountById(parentId);
    final expectedAuthority = normalizeAccountAuthority(
      BusyProvider.nextcloud,
      authority: server.toString(),
    );
    final expectedSubject = normalizeProviderAccountId(
      BusyProvider.nextcloud,
      account.subject,
    );
    if (credential == null ||
        normalizeProviderAccountId(BusyProvider.nextcloud, username) !=
            expectedSubject ||
        parent?.provider != BusyProvider.nextcloud ||
        parent?.authority != expectedAuthority ||
        parent?.providerAccountId != expectedSubject ||
        normalizeAccountAuthority(
              BusyProvider.nextcloud,
              authority: credential.server.toString(),
            ) !=
            expectedAuthority ||
        normalizeProviderAccountId(
              BusyProvider.nextcloud,
              credential.username,
            ) !=
            expectedSubject) {
      throw const ContactsException(
        ContactsFailure.authentication,
        'linked-parent-authorization-unavailable',
      );
    }
    return DavBasicCredential(
      username: credential.username,
      password: credential.password,
    );
  }

  Future<void> removeLinkedAccount(String busyMaxAccountId) async {
    final id = linkedContactAccountId(busyMaxAccountId);
    _linkedRemovals[id]?.recoverable = false;
    await _cancelEnrollment(id);
    final account = await store.read((tx) => tx.account(id));
    if (account == null) return;
    _boundGenerations.remove(id);
    nextcloudClients?.invalidate('contacts:$id');
    await directory.disconnect(id, remove: true);
  }

  /// Cancels and drains provider work before the parent authorization is
  /// removed. Data is retained, disabled and recoverable until the parent's
  /// database transaction commits.
  void beginLinkedAccountRemoval(String busyMaxAccountId) {
    final id = linkedContactAccountId(busyMaxAccountId);
    if (_linkedRemovals.containsKey(id)) {
      throw StateError('Parent removal already owns this contacts account.');
    }
    _linkedRemovals[id] = _LinkedAccountRemoval();
    // Invalidate synchronously. A staged enrollment may already own, or be
    // queued for, authorization serialization; preparation drains it only
    // after that boundary is released.
    _enrollments[id]?.cancel();
  }

  Future<void> prepareLinkedAccountRemoval(String busyMaxAccountId) async {
    final id = linkedContactAccountId(busyMaxAccountId);
    // Direct callers also claim ownership before awaiting. Production claims
    // it when parent removal starts, before queuing authorization work.
    if (!_linkedRemovals.containsKey(id)) {
      beginLinkedAccountRemoval(busyMaxAccountId);
    }
    final removal = _linkedRemovals[id]!;
    if (removal.prepared) {
      throw StateError('Contacts removal already prepared.');
    }
    removal.prepared = true;
    removal.parent = await accounts.accountById(busyMaxAccountId);
    removal.authorizationGeneration = await readAuthorizationGeneration?.call(
      busyMaxAccountId,
    );
    await _cancelEnrollment(id);
    final account = await store.read((tx) => tx.account(id));
    removal.original = account;
    removal.hadBinding = _boundGenerations[id] == account?.generation;
    if (account?.enabled == true) {
      // Detach/drain network work first. Change the setting only if this attempt
      // still owns the exact account that it observed.
      removal.detachmentStarted = true;
      await _detachBinding(id);
      await _drain([if (_syncing[id] case final running?) running]);
      removal.detachmentCompleted = true;
      // A successful statement is not a committed transaction. Keep the
      // original binding receipt even if this write or its COMMIT rolls back.
      removal.changed = await store.write<ContactAccount?>((tx) async {
        final current = await tx.account(id);
        if (removal.recoverable &&
            identical(_linkedRemovals[id], removal) &&
            current?.generation == account!.generation &&
            current?.enabled == true) {
          final disabled = current!.copy(
            enabled: false,
            generation: current.generation + 1,
          );
          await tx.putAccount(disabled);
          return disabled;
        }
        return null;
      });
    }
  }

  /// Called inside the parent's account-removal database transaction.
  Future<void> persistLinkedAccountRemoval(String busyMaxAccountId) =>
      store.persistRemoveAccount(linkedContactAccountId(busyMaxAccountId));

  Future<void> restoreLinkedAccountAfterFailedRemoval(
    String busyMaxAccountId,
  ) async {
    final id = linkedContactAccountId(busyMaxAccountId);
    final removal = _linkedRemovals[id];
    final original = removal?.original;
    if (removal == null ||
        !removal.recoverable ||
        removal.recovered ||
        _closed ||
        original?.enabled != true ||
        !removal.detachmentStarted) {
      return;
    }
    final parent = await accounts.accountById(busyMaxAccountId);
    if (parent == null ||
        parent.provider != removal.parent?.provider ||
        parent.providerAccountId != removal.parent?.providerAccountId ||
        parent.tenantId != removal.parent?.tenantId ||
        parent.authority != removal.parent?.authority ||
        parent.credentialKind != removal.parent?.credentialKind ||
        parent.authState != removal.parent?.authState ||
        parent.grantedScopes != removal.parent?.grantedScopes ||
        await readAuthorizationGeneration?.call(busyMaxAccountId) !=
            removal.authorizationGeneration) {
      return;
    }
    final expected = removal.changed ?? original!;
    bool owns(ContactAccount? current) =>
        removal.recoverable &&
        identical(_linkedRemovals[id], removal) &&
        current != null &&
        jsonEncode(current.toJson()) == jsonEncode(expected.toJson());
    if (!owns(await store.read((tx) => tx.account(id)))) return;
    // detach removes the runtime binding before its journal transaction. If
    // that transaction failed, finish its existing uncertain-outcome handling
    // before allowing any provider work; never replay an executing mutation.
    if (!removal.detachmentCompleted) {
      try {
        await _detachBinding(id);
        await _drain([if (_syncing[id] case final running?) running]);
        removal.detachmentCompleted = true;
      } on Object {
        await store.write((tx) async {
          final current = await tx.account(id);
          if (owns(current)) {
            await tx.putAccount(
              current!.copy(errorCode: 'contacts-removal-recovery-required'),
            );
          }
        });
        rethrow;
      }
    }
    final restored = await store.write<ContactAccount?>((tx) async {
      final current = await tx.account(id);
      if (!owns(current)) return null;
      if (removal.changed == null) {
        // SQL rollback already retained the enabled setting and generation.
        return current;
      }
      final restored = current!.copy(
        enabled: true,
        generation: current.generation + 1,
        errorCode: original?.errorCode,
      );
      await tx.putAccount(restored);
      return restored;
    });
    if (restored == null) return;
    // A newer user action may run while the write completes. Never rebind it.
    final current = await store.read((tx) => tx.account(id));
    if (!removal.recoverable ||
        !identical(_linkedRemovals[id], removal) ||
        current?.generation != restored.generation ||
        current?.enabled != true) {
      return;
    }
    if (!removal.hadBinding) {
      removal.recovered = true;
      return;
    }
    await _bind(
      restored,
      validateBinding: () {
        if (!removal.recoverable || !identical(_linkedRemovals[id], removal)) {
          throw const ContactsException(
            ContactsFailure.cancelled,
            'stale-removal-recovery',
          );
        }
      },
    );
    if (!removal.recoverable) return;
    removal.recovered = true;
    _ensureScheduling();
    _launch(() => synchronizeAccount(id));
  }

  void finishLinkedAccountRemoval(String busyMaxAccountId) {
    _linkedRemovals.remove(linkedContactAccountId(busyMaxAccountId));
  }

  void linkedAccountRemovalCommitted() => store.contactConfigurationChanged();

  Future<void> removeContactsAccount(String id) async {
    _linkedRemovals[id]?.recoverable = false;
    await _cancelEnrollment(id);
    final account = await store.read((tx) => tx.account(id));
    if (account == null) return;
    _boundGenerations.remove(id);
    await _detachForReplacement(id);
    await accountGate.run('contacts:$id', () async {
      nextcloudClients?.invalidate('contacts:$id');
      await directory.disconnect(id, remove: true);
      if (account.provider == ContactProviderKind.carddav) {
        await deleteDavSecret(id);
      }
    });
  }

  Future<void> disableContactsAccount(String id) async {
    _linkedRemovals[id]?.recoverable = false;
    await _cancelEnrollment(id);
    _boundGenerations.remove(id);
    await directory.disconnect(id);
  }

  Map<String, dynamic> _acceptedDavConfig(
    String encoded,
    ContactAccount account,
  ) {
    var config = (jsonDecode(encoded) as Map).cast<String, dynamic>();
    if (config.containsKey('authorizationGeneration') &&
        config['authorizationGeneration'] != account.generation) {
      final previous = config['_previous'];
      if (previous is! Map ||
          (previous['authorizationGeneration'] ?? 0) != account.generation) {
        throw const FormatException(
          'Contacts authorization recovery required.',
        );
      }
      config = previous.cast<String, dynamic>();
    }
    if (config.containsKey('trustPolicy') &&
        config['authorizationGeneration'] is! int) {
      config['trustPolicy'] = <String, Object?>{'version': 0, 'invalid': true};
    }
    return Map.of(config)..remove('_previous');
  }

  Future<void> _commitDavContactSecret(
    ContactAccount account,
    String next,
    String? previous,
    int? expectedGeneration,
    void Function() validate,
  ) => accountGate.run('contacts:${account.id}', () async {
    final current = await store.read((tx) => tx.account(account.id));
    if (current?.generation != expectedGeneration) {
      throw const ContactsException(
        ContactsFailure.cancelled,
        'stale-contacts-authorization',
      );
    }
    validate();
    try {
      await writeDavSecret(account.id, next);
      if (await readDavSecret(account.id) != next) {
        throw const FormatException('Contacts credential write failed.');
      }
      validate();
      await store.write((tx) async {
        validate();
        await tx.putAccount(account);
        validate();
      });
    } on Object {
      if (previous == null) {
        await deleteDavSecret(account.id);
      } else {
        await writeDavSecret(account.id, previous);
      }
      rethrow;
    }
  });

  Future<(Uri, NextcloudTrustPolicy?, int)> privateTrustSnapshot(
    String id,
  ) async {
    final account = await store.read((tx) => tx.account(id));
    final encoded = await readDavSecret(id);
    if (account == null || encoded == null || await store.hasAccountLink(id)) {
      throw const FormatException('Independent Nextcloud account unavailable.');
    }
    final config = _acceptedDavConfig(encoded, account);
    if (config['nextcloud'] != true) {
      throw const FormatException('Nextcloud account required.');
    }
    return (
      Uri.parse(config['server'] as String),
      config.containsKey('trustPolicy')
          ? NextcloudTrustPolicy.fromJson(config['trustPolicy'])
          : null,
      account.generation,
    );
  }

  Future<void> replacePrivateTrust(
    String id,
    int generation,
    NextcloudTrustPolicy? policy,
  ) => reconnectDavContactsOnly(
    id,
    replaceTrust: true,
    trustPolicy: policy,
    expectedGeneration: generation,
  );

  Future<bool> isIndependentNextcloud(String id) async {
    final encoded = await readDavSecret(id);
    return encoded != null && (jsonDecode(encoded) as Map)['nextcloud'] == true;
  }

  Future<Uri?> independentServer(String id) async {
    if (await store.hasAccountLink(id)) return null;
    final encoded = await readDavSecret(id);
    if (encoded == null) return null;
    final server = Uri.parse((jsonDecode(encoded) as Map)['server'] as String);
    _requireDavServer(server);
    return Uri(
      scheme: server.scheme,
      host: server.host,
      port: server.hasPort ? server.port : null,
      path: server.path,
    );
  }

  Future<void> reconnectContactsAccount(String id) async {
    final account = await store.read((tx) => tx.account(id));
    if (account == null) throw StateError('Contacts account unavailable');
    final parent = await store.linkedBusyMaxAccount(id);
    if (parent == null && await store.hasAccountLink(id)) {
      throw const ContactsException(
        ContactsFailure.authentication,
        'linked-parent-removed',
      );
    }
    if (parent != null) {
      if (account.provider == ContactProviderKind.carddav) {
        await enableLinkedNextcloudContacts(parent, reconnect: true);
      } else {
        await enableLinkedContacts(parent, forceAuthorization: true);
      }
      return;
    }
    await reconnectDavContactsOnly(id);
  }

  Future<void> reconnectDavContactsOnly(
    String id, {
    String? password,
    bool replaceTrust = false,
    NextcloudTrustPolicy? trustPolicy,
    int? expectedGeneration,
  }) => _enroll(id, (attempt) async {
    await start();
    _checkEnrollment(attempt);
    final previous = await store.read((tx) => tx.account(id));
    final encoded = await readDavSecret(id);
    if (previous == null ||
        previous.provider != ContactProviderKind.carddav ||
        encoded == null ||
        await store.hasAccountLink(id)) {
      throw StateError('Independent DAV account unavailable');
    }
    final config = _acceptedDavConfig(encoded, previous);
    if (expectedGeneration != null &&
        previous.generation != expectedGeneration) {
      throw const ContactsException(
        ContactsFailure.cancelled,
        'stale-certificate-approval',
      );
    }
    if (replaceTrust) {
      if (config['nextcloud'] != true) {
        throw const FormatException('Nextcloud account required.');
      }
      trustPolicy?.requireScope(
        'contacts:$id',
        Uri.parse(config['server'] as String),
      );
      config.remove('trustPolicy');
      if (trustPolicy != null) config['trustPolicy'] = trustPolicy.toJson();
    } else if (password != null) {
      if (password.isEmpty) {
        throw const ContactsException(
          ContactsFailure.validation,
          'password-required',
        );
      }
      config['password'] = password;
    } else if (config['nextcloud'] == true) {
      final token = DavCancellationToken();
      http.Client? reconnectClient = nextcloudClients?.create(
        owner: 'contacts:$id',
        authority: Uri.parse(config['server'] as String),
        policy: config.containsKey('trustPolicy')
            ? NextcloudTrustPolicy.fromJson(config['trustPolicy'])
            : null,
      );
      if (reconnectClient != null) {
        reconnectClient = NextcloudLeasedHttpClient(
          delegate: reconnectClient,
          runLease: (work) => accountGate.run('contacts:$id', work),
          validate: () async {
            if ((await store.read((tx) => tx.account(id)))?.generation !=
                previous.generation) {
              throw const ContactsException(
                ContactsFailure.cancelled,
                'stale-nextcloud-contact-login',
              );
            }
          },
        );
      }
      final flow = NextcloudLoginFlowV2(
        server: Uri.parse(config['server'] as String),
        client: reconnectClient ?? httpClient,
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
            normalizeNextcloudServerAuthority(result.server.toString()) !=
                normalizeNextcloudServerAuthority(config['server'] as String)) {
          throw const ContactsException(
            ContactsFailure.authentication,
            'wrong-contact-identity',
          );
        }
        config['password'] = result.appPassword;
      } finally {
        flow.close();
        reconnectClient?.close();
      }
    }
    final replacement = ContactAccount(
      id: previous.id,
      provider: previous.provider,
      displayName: previous.displayName,
      subject: previous.subject,
      enabled: true,
      generation: previous.generation + 1,
      grantedScopes: previous.grantedScopes,
    );
    final provider = _davProvider(
      replacement,
      config,
      validationOnly: true,
      expectedDurableGeneration: previous.generation,
    );
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
    if (config['nextcloud'] == true) {
      final acceptedPrevious = _acceptedDavConfig(encoded, previous)
        ..['authorizationGeneration'] = previous.generation;
      config['authorizationGeneration'] = replacement.generation;
      // One accepted snapshot, including accounts predating this envelope.
      // Never accumulate obsolete credentials/policies in nested histories.
      config['_previous'] = acceptedPrevious;
    }
    final next = jsonEncode(config);
    var durable = false;
    await _detachForReplacement(id);
    try {
      await _commitDavContactSecret(
        replacement,
        next,
        encoded,
        previous.generation,
        () => _checkEnrollment(attempt),
      );
      durable = true;
      attempt.committed = true;
      if (_closed) return;
      await _detachForReplacement(id);
      _checkEnrollment(attempt);
      await _bind(replacement);
    } on Object catch (error, stack) {
      try {
        if (!durable) {
          if (!_closed &&
              (await store.read((tx) => tx.account(id)))?.generation ==
                  previous.generation) {
            await _bind(previous);
          }
        } else {
          await _detachBinding(id);
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

final class _LinkedAccountRemoval {
  AccountEntity? parent;
  int? authorizationGeneration;
  ContactAccount? original;
  ContactAccount? changed;
  bool hadBinding = false;
  bool detachmentStarted = false;
  bool detachmentCompleted = false;
  bool recoverable = true;
  bool prepared = false;
  bool recovered = false;
}

final class _ContactsEnrollment {
  final AuthorizationCancellation authorization = AuthorizationCancellation();
  final Completer<void> done = Zone.root.run(Completer<void>.new);
  bool cancelled = false;
  bool committed = false;
  void Function()? onCancel;
  void cancel() {
    if (committed) return;
    cancelled = true;
    authorization.cancel();
    onCancel?.call();
  }
}

final class _BusyMaxGoogleContactsClient extends http.BaseClient {
  _BusyMaxGoogleContactsClient({
    required this.authorization,
    required this.accountId,
    required this.inner,
  });

  final ContactsAuthorizationBroker authorization;
  final String accountId;
  final http.Client inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['authorization'] = await _contactsAuthorizationHeader(
      authorization,
      BusyProvider.google,
      accountId,
    );
    return inner.send(request);
  }

  // The app owns the shared HTTP client.
  @override
  void close() {}
}

// Preserve app-owned authorization classifications at the provider boundary.
// The shared adapters otherwise intentionally reduce unknown token errors.
Future<String> _contactsAuthorizationHeader(
  ContactsAuthorizationBroker authorization,
  BusyProvider provider,
  String id, {
  String? claims,
}) async {
  try {
    return await authorization.contactsAuthorizationHeader(
      provider,
      id,
      claims: claims,
    );
  } on OAuthException catch (error) {
    _throwContactsAuthorizationFailure(provider, error.classification);
  } on SecretStoreException {
    _throwContactsAuthorizationFailure(provider, OAuthFailureKind.storage);
  }
}

Never _throwContactsAuthorizationFailure(
  BusyProvider provider,
  OAuthFailureKind kind,
) {
  final failure = switch (kind) {
    OAuthFailureKind.cancelled => ContactsFailure.cancelled,
    OAuthFailureKind.permission => ContactsFailure.permission,
    OAuthFailureKind.network ||
    OAuthFailureKind.timeout => ContactsFailure.offline,
    OAuthFailureKind.throttled => ContactsFailure.throttled,
    OAuthFailureKind.temporary ||
    OAuthFailureKind.authorizationCode ||
    OAuthFailureKind.alreadyConnected => ContactsFailure.server,
    _ => ContactsFailure.authentication,
  };
  final code = 'oauth:${kind.name}';
  if (provider == BusyProvider.microsoft) {
    throw GraphException(switch (failure) {
      ContactsFailure.cancelled => GraphFailure.cancelled,
      ContactsFailure.permission => GraphFailure.permission,
      ContactsFailure.offline => GraphFailure.connectivity,
      ContactsFailure.throttled => GraphFailure.throttled,
      ContactsFailure.server => GraphFailure.server,
      _ => GraphFailure.authentication,
    }, code);
  }
  throw ContactsException(failure, code);
}
