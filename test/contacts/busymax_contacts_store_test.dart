import 'dart:async';

import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:busymax/src/contacts/busymax_contacts_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BusyMaxContactsStore store;

  setUp(() async {
    database = AppDatabase.memoryForTests();
    store = BusyMaxContactsStore(database);
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'calendar-account',
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'subject',
            credentialKind: 'oauth',
            createdAtUtc: '2026-10-06T00:00:00.000Z',
            updatedAtUtc: '2026-10-06T00:00:00.000Z',
          ),
        );
  });

  tearDown(() async {
    await store.close();
    await database.close();
  });

  test('data and cursor commit atomically across awaited operations', () async {
    await store.write((transaction) async {
      await transaction.putAccount(_account('contacts'));
      await Future<void>.delayed(Duration.zero);
      await transaction.putSource(_source('contacts'));
      await transaction.putContact(_record('contacts', 'one'));
      await transaction.putSyncState(
        ContactSyncState(
          sourceKey: _source('contacts').key,
          cursor: 'cursor-1',
        ),
      );
    });

    expect(await store.read((transaction) => transaction.count()), 1);
    expect(
      (await store.read(
        (transaction) => transaction.syncState(_source('contacts').key),
      ))?.cursor,
      'cursor-1',
    );
  });

  test('delayed write failure rolls back records and cursor', () async {
    await store.write((transaction) async {
      await transaction.putAccount(_account('contacts'));
      await transaction.putSource(_source('contacts'));
    });

    await expectLater(
      store.write((transaction) async {
        await transaction.putContact(_record('contacts', 'rolled-back'));
        await Future<void>.delayed(Duration.zero);
        await transaction.putSyncState(
          ContactSyncState(
            sourceKey: _source('contacts').key,
            cursor: 'must-not-commit',
          ),
        );
        throw StateError('fixture rollback');
      }),
      throwsStateError,
    );

    expect(await store.read((transaction) => transaction.count()), 0);
    expect(
      await store.read(
        (transaction) => transaction.syncState(_source('contacts').key),
      ),
      isNull,
    );
  });

  test(
    'linked and contacts-only sources retain independent eligibility',
    () async {
      await store.saveLinkedAccount(
        account: _account('linked'),
        busyMaxAccountId: 'calendar-account',
        reuseAuthorization: true,
      );
      await store.write((transaction) async {
        await transaction.putSource(_source('linked'));
        await transaction.putAccount(_account('standalone'));
        await transaction.putSource(_source('standalone'));
      });

      var selection = await store.selection(
        busyMaxAccountId: 'calendar-account',
      );
      expect(selection.accountIds, {'linked', 'standalone'});
      expect(selection.sourceKeys, {
        _source('linked').key,
        _source('standalone').key,
      });

      await store.setSourceEnabled(_source('linked').key, enabled: false);
      selection = await store.selection(busyMaxAccountId: 'calendar-account');
      expect(selection.accountIds, {'standalone'});
      expect(selection.sourceKeys, {_source('standalone').key});
      expect(await store.linkedBusyMaxAccount('linked'), 'calendar-account');
    },
  );

  test(
    'closing drains an awaited transaction without closing BusyMax DB',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final operation = store.write((transaction) async {
        await transaction.putAccount(_account('contacts'));
        entered.complete();
        await release.future;
        await transaction.putSource(_source('contacts'));
      });
      await entered.future;
      final closing = store.close();
      release.complete();
      await Future.wait<void>([operation, closing]);

      expect(
        await database
            .customSelect('SELECT count(*) AS total FROM accounts')
            .getSingle()
            .then((row) => row.read<int>('total')),
        1,
      );
    },
  );
  test(
    'failing transaction still closes changes and retains the application DB',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var notifications = 0;
      final subscription = store.changes.listen((_) => notifications++);
      final streamDone = subscription.asFuture<void>();
      final operation = store.write((tx) async {
        entered.complete();
        await release.future;
        throw StateError('delayed rollback');
      });
      final failure = expectLater(operation, throwsStateError);
      await entered.future;
      final closing = store.close();
      release.complete();
      await failure;
      await closing.timeout(const Duration(seconds: 3));
      await streamDone;
      expect(notifications, 0);
      await expectLater(
        store.setSourceEnabled('missing', enabled: false),
        throwsStateError,
      );
      expect(await database.customSelect('SELECT 1').getSingle(), isNotNull);
      await store.close();
    },
  );
  test(
    'preferences notify only after commit and preserve the value on failure',
    () async {
      await store.write((tx) async {
        await tx.putAccount(_account('contacts'));
        await tx.putSource(_source('contacts'));
      });
      var notifications = 0;
      final subscription = store.changes.listen((_) => notifications++);
      addTearDown(subscription.cancel);
      await store.setSourceEnabled(_source('contacts').key, enabled: false);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      expect(await store.sourceEnabled(_source('contacts').key), false);
      await database.customStatement(
        "CREATE TRIGGER fail_preference BEFORE UPDATE ON bm_contact_source_preferences BEGIN SELECT RAISE(ABORT, 'fixture'); END",
      );
      await expectLater(
        store.setSourceEnabled(_source('contacts').key, enabled: true),
        throwsA(anything),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      expect(await store.sourceEnabled(_source('contacts').key), false);
    },
  );
}

ContactAccount _account(String id) => ContactAccount(
  id: id,
  provider: ContactProviderKind.carddav,
  displayName: id,
  subject: id,
  grantedScopes: const {'dav:read', 'dav:write'},
);

ContactSource _source(String accountId) => ContactSource(
  accountId: accountId,
  id: 'book',
  provider: ContactProviderKind.carddav,
  kind: ContactSourceKind.carddavAddressBook,
  name: 'Address book',
  remotePath: 'https://contacts.example.test/book/',
  capabilities: ContactCapabilities(
    create: true,
    update: true,
    delete: true,
    photoRead: true,
    photoWrite: true,
    fields: ContactField.values.toSet(),
  ),
);

CardDavContactRecord _record(String accountId, String id) {
  final identity = ContactIdentity(
    accountId: accountId,
    provider: ContactProviderKind.carddav,
    sourceId: 'book',
    remoteId: id,
  );
  final vcard = newVcard(
    ContactPatch(
      name: FieldEdit.set(ContactName(display: 'Contact $id')),
      emails: FieldEdit.set([ContactValue('$id@example.test')]),
    ),
    uid: id,
  );
  return CardDavContactRecord(
    identity: identity,
    vcard: vcard,
    revision: '"one"',
    projection: projectVcard(identity, vcard),
  );
}
