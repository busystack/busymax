import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:busymax/src/contacts/busymax_contacts_controller.dart';
import 'package:busymax/src/contacts/busymax_contacts_store.dart';
import 'package:busymax/src/core/auth/account_token_broker.dart';
import 'package:busymax/src/core/auth/authorization_attempt.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  test('actual attendee lookup filters disabled sources and exclusions before limit', () async {
    final database = AppDatabase.memoryForTests();
    final store = BusyMaxContactsStore(database);
    final controller = BusyMaxContactsController(
      store: store,
      accounts: AccountsRepository(database: database),
      authorization: _UnusedAuthorization(),
      httpClient: MockClient((_) async => throw StateError('no network')),
      readDavSecret: (_) async => null,
      writeDavSecret: (_, _) async {},
      deleteDavSecret: (_) async {},
      readLinkedDavCredential: (_) async => null,
      launchBrowser: (_) async => false,
      syncInterval: const Duration(days: 1),
    );
    addTearDown(() async {
      await controller.close();
      await database.close();
    });
    // Start with an empty directory so background synchronization has no
    // provider to contact. The records below then exercise the same cached
    // lookup called by all three production event editors.
    await controller.start();
    await store.write((transaction) async {
      await transaction.putAccount(_account);
      await transaction.putSource(_source('disabled'));
      await transaction.putSource(_source('enabled'));
      for (var i = 0; i < 12; i++) {
        await transaction.putContact(
          _record('disabled', 'disabled-$i', 'alex-$i@example.test'),
        );
      }
      await transaction.putContact(
        _record('enabled', 'selected', 'selected@example.test'),
      );
      await transaction.putContact(
        _record('enabled', 'excluded', 'excluded@example.test'),
      );
    });
    await store.setSourceEnabled(_source('disabled').key, enabled: false);

    final suggestions = await controller.suggestAttendees(
      'e',
      excludedAddresses: const {'excluded@example.test'},
      limit: 1,
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.email, 'selected@example.test');
    expect(suggestions.single.displayName, 'Selected Person');
    expect(suggestions.single.identities.single.sourceId, 'enabled');
  });
}

const _account = ContactAccount(
  id: 'contacts-only',
  provider: ContactProviderKind.carddav,
  displayName: 'Contacts',
  subject: 'alex',
  grantedScopes: {'carddav:read'},
);

ContactSource _source(String id) => ContactSource(
  accountId: _account.id,
  id: id,
  provider: ContactProviderKind.carddav,
  kind: ContactSourceKind.carddavAddressBook,
  name: id,
  remotePath: 'https://contacts.example.test/$id/',
  capabilities: ContactCapabilities(
    create: false,
    update: false,
    delete: false,
    photoRead: false,
    photoWrite: false,
    fields: ContactField.values.toSet(),
  ),
);

CardDavContactRecord _record(String sourceId, String remoteId, String email) {
  final identity = ContactIdentity(
    accountId: _account.id,
    provider: ContactProviderKind.carddav,
    sourceId: sourceId,
    remoteId: remoteId,
  );
  final name = remoteId == 'selected' ? 'Selected Person' : 'Alex $remoteId';
  final vcard = newVcard(
    ContactPatch(
      name: FieldEdit.set(ContactName(display: name)),
      emails: FieldEdit.set([ContactValue(email)]),
    ),
    uid: remoteId,
  );
  return CardDavContactRecord(
    identity: identity,
    vcard: vcard,
    revision: '"one"',
    projection: projectVcard(identity, vcard),
  );
}

final class _UnusedAuthorization implements ContactsAuthorizationBroker {
  @override
  Future<void> authorizeContacts(
    BusyProvider provider,
    String accountId, {
    required bool writable,
    AuthorizationCancellation? cancellation,
    Future<void> Function()? persistContacts,
  }) => throw StateError('authorization is not used by cached lookup');

  @override
  Future<String> contactsAuthorizationHeader(
    BusyProvider provider,
    String accountId, {
    required bool writable,
    String? claims,
  }) => throw StateError('authorization is not used by cached lookup');
}
