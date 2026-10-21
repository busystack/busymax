import 'dart:convert';

import 'package:busystack_contacts/google.dart';
import 'package:busystack_contacts/microsoft.dart';
import 'package:busymax/src/contacts/busymax_contacts_controller.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contacts_fixture.dart';
import '../support/dav_contacts_fixture.dart';
import 'read_only_contacts_provider_test.dart' show effective;

void main() {
  test('reenabling linked Nextcloud suggestions preserves legacy markers and the parent app password', () async {
    final db = AppDatabase.memoryForTests();
    final credential = BusyMaxLinkedDavCredential(
      server: server,
      username: 'actual-user',
      password: 'original-app-password',
    );
    final f = ContactsFixture(
      db,
      realDav: true,
      linkedDavCredential: credential,
    );
    addTearDown(f.close);
    final dav = DavFixture();
    f.respondDav = dav.respond;
    await f.accounts.upsertSignedInAccount(
      id: 'nextcloud',
      provider: BusyProvider.nextcloud,
      providerAccountId: 'actual-user',
      authority: server.toString(),
      displayName: 'Parent Nextcloud',
      grantedScopes: '',
    );
    const id = 'contacts:nextcloud';
    await f.store.saveLinkedAccount(
      account: ContactAccount(
        id: id,
        provider: ContactProviderKind.carddav,
        displayName: 'Legacy Nextcloud',
        subject: credential.username,
        grantedScopes: const {'carddav:write'},
        generation: 4,
      ),
      busyMaxAccountId: 'nextcloud',
      reuseAuthorization: true,
    );
    await f.controller.start();
    await f.controller.synchronizeAccount(id);
    final source = (await f.controller.sourceSettings()).first.source;
    await f.store.setSourceEnabled(source.key, enabled: false);
    final queued = ContactMutation(
      id: 'legacy-linked-queued',
      accountId: id,
      sourceKey: source.key,
      kind: ContactMutationKind.providerAction,
      state: ContactMutationState.queued,
      createdAt: DateTime.utc(2026),
      payload: const {'type': 'historical', 'evidence': 'retain'},
    );
    await f.store.write((tx) => tx.putMutation(queued));
    await f.controller.enableLinkedNextcloudContacts('nextcloud');
    await f.controller.synchronizeAccount(id);
    final account = (await f.store.read((tx) => tx.account(id)))!;
    expect(account.id, id);
    expect(account.subject, credential.username);
    expect(account.generation, 5);
    expect(account.grantedScopes, {'carddav:write'});
    expect(await f.store.sourceEnabled(source.key), isFalse);
    expect(
      (await f.store.read((tx) => tx.mutations(accountId: id)))
          .singleWhere((mutation) => mutation.id == queued.id)
          .toJson(),
      queued.toJson(),
    );
    for (final setting in await f.controller.sourceSettings()) {
      effective(setting.source);
    }
    expect(f.davSecrets, isEmpty);
    await f.controller.removeContactsAccount(id);
    expect(await f.accounts.accountById('nextcloud'), isNotNull);
    expect(
      dav.requests.where(
        (r) =>
            ['PUT', 'DELETE', 'MKCOL', 'PROPPATCH', 'POST'].contains(r.method),
      ),
      isEmpty,
    );
    expect(dav.card, rawCard);
    expect(credential.password, 'original-app-password');
  });
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    for (final factory in [true, false]) {
      test(
        '$provider factory=$factory broad grants remain read-only across enrollment/rebind/restart/timer',
        () async {
          final db = AppDatabase.memoryForTests();
          final f = ContactsFixture(db, realDav: !factory);
          await f.addParent(provider);
          final grant = provider == BusyProvider.google
              ? 'https://www.googleapis.com/auth/contacts'
              : 'Contacts.ReadWrite';
          f.consentScopes = provider == BusyProvider.google
              ? 'calendar tasks $grant'
              : 'Calendars.ReadWrite Tasks.ReadWrite $grant';
          await f.controller.enableLinkedContacts(provider.name);
          final id = 'contacts:${provider.name}';
          await f.controller.synchronizeAccount(id);
          final source = (await f.controller.sourceSettings()).first.source;
          final record = (await f.store.read((tx) => tx.contacts())).first;
          final native = record.toJson();
          final account = (await f.store.read((tx) => tx.account(id)))!;
          final cursor = (await f.store.read((tx) => tx.syncState(source.key)))!
              .cursor;
          effective(source);
          expect(account.grantedScopes, contains(grant));
          await f.store.setSourceEnabled(source.key, enabled: false);
          final journals = <String, Map<String, Object?>>{};
          await f.store.write((tx) async {
            for (final state in [
              ContactMutationState.queued,
              ContactMutationState.executing,
              ContactMutationState.unknown,
              ContactMutationState.conflict,
            ]) {
              final mutation = ContactMutation(
                id: state.name,
                accountId: id,
                sourceKey: source.key,
                kind: ContactMutationKind.providerAction,
                state: state,
                createdAt: DateTime.utc(2026),
                errorCode: 'keep-${state.name}',
                payload: const {
                  'type': 'historical',
                  'evidence': 'remote outcome uncertain',
                },
              );
              journals[state.name] = mutation.toJson();
              await tx.putMutation(mutation);
            }
          });
          // Schema-20 persisted source from an earlier writable build.
          final old = {
            ...source.toJson(),
            'rename': true,
            'remove': true,
            'capabilities': {
              ...source.capabilities.toJson(),
              'create': true,
              'update': true,
              'delete': true,
              'photoWrite': true,
            },
          };
          await db.customStatement(
            'UPDATE bm_contact_sources SET data = ? WHERE source_key = ?',
            [jsonEncode(old), source.key],
          );
          await f.controller.close();
          final restarted = ContactsFixture(
            db,
            realDav: !factory,
            syncInterval: const Duration(milliseconds: 30),
          );
          addTearDown(restarted.close);
          restarted.offline = true;
          for (final setting in await restarted.controller.sourceSettings()) {
            effective(setting.source);
          }
          await restarted.controller.start();
          expect(await restarted.controller.suggestAttendees('ada'), isEmpty);
          expect(await restarted.store.sourceEnabled(source.key), isFalse);
          expect(
            {
              ...(await restarted.store.read((tx) => tx.account(id)))!.toJson(),
              'error': null,
            },
            {...account.toJson(), 'error': null},
          );
          expect(
            (await restarted.store.read((tx) => tx.contact(record.identity)))!
                .toJson(),
            native,
          );
          expect(
            (await restarted.store.read((tx) => tx.syncState(source.key)))!
                .cursor,
            cursor,
          );
          final row = await db
              .customSelect('SELECT data FROM bm_contact_sources')
              .getSingle();
          effective(
            ContactSource.fromJson(
              (jsonDecode(row.read<String>('data')) as Map).cast(),
            ),
          );
          restarted.offline = false;
          await restarted.controller.synchronizeAccount(id);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          for (final mutation in await restarted.store.read(
            (tx) => tx.mutations(),
          )) {
            if (mutation.id == 'executing') {
              expect(mutation.state, ContactMutationState.unknown);
              expect(mutation.errorCode, 'interrupted-after-dispatch');
              final expected = {
                ...journals[mutation.id]!,
                'state': 'unknown',
                'error': 'interrupted-after-dispatch',
              };
              expect(mutation.toJson(), expected);
            } else {
              expect(mutation.toJson(), journals[mutation.id]);
            }
          }
          await restarted.store.setSourceEnabled(source.key, enabled: true);
          await restarted.controller.reconnectContactsAccount(id);
          await restarted.controller.synchronizeAccount(id);
          for (final setting in await restarted.controller.sourceSettings()) {
            effective(setting.source);
          }
          final before = restarted.requests.length;
          for (final call in [
            () => restarted.controller.directory.create(
              source.key,
              const ContactPatch(),
            ),
            () => restarted.controller.directory.update(
              record,
              const ContactPatch(
                name: FieldEdit.set(ContactName(display: 'Changed')),
              ),
            ),
            () => restarted.controller.directory.delete(record),
            () => restarted.controller.directory.setPhoto(
              record,
              null,
              'image/png',
            ),
          ]) {
            await expectLater(call(), throwsA(isA<ContactsException>()));
          }
          final rejectedAction = await restarted.controller.directory
              .providerAction(
                id,
                provider == BusyProvider.google
                    ? const GoogleGroupAction(
                        GoogleGroupOperation.create,
                        name: 'New',
                      )
                    : const MicrosoftFolderAction(
                        MicrosoftFolderOperation.create,
                        name: 'New',
                      ),
              );
          expect(rejectedAction.state, ContactMutationState.failed);
          expect(rejectedAction.errorCode, 'busymax-contacts-read-only');
          expect(
            restarted.requests
                .skip(before)
                .where((request) => request.method != 'GET'),
            isEmpty,
          );
          expect(
            restarted.requests.where((request) => request.method != 'GET'),
            isEmpty,
          );
          expect(
            (await restarted.store.read((tx) => tx.mutations()))
                .where((m) => journals.containsKey(m.id)),
            hasLength(4),
          );
        },
      );
    }
  }
  test('old DAV password/config and writable markers survive offline restart and read-only reconnect', () async {
    final db = AppDatabase.memoryForTests();
    final f = ContactsFixture(db, realDav: true);
    final dav = DavFixture();
    f.respondDav = dav.respond;
    final account = await f.controller.addCardDavContactsOnly(
      id: 'legacy-dav',
      label: 'DAV',
      server: server,
      username: 'actual-user',
      password: 'original-password',
    );
    final config = jsonDecode(f.davSecrets[account.id]!) as Map;
    config['readOnly'] = false;
    final encoded = jsonEncode(config);
    f.davSecrets[account.id] = encoded;
    await f.store.write(
      (tx) => tx.putAccount(
        ContactAccount(
          id: account.id,
          provider: account.provider,
          displayName: account.displayName,
          subject: account.subject,
          grantedScopes: const {'carddav:write'},
        ),
      ),
    );
    final records = (await f.store.read((tx) => tx.contacts()))
        .map((c) => c.toJson())
        .toList();
    await f.controller.close();
    final restarted = ContactsFixture(db, realDav: true);
    addTearDown(restarted.close);
    restarted.davSecrets.addAll(f.davSecrets);
    restarted.respondDav = dav.respond;
    dav.offline = true;
    await restarted.controller.start();
    expect(restarted.davSecrets[account.id], encoded);
    expect(
      (await restarted.store.read((tx) => tx.contacts()))
          .map((c) => c.toJson()),
      records,
    );
    for (final setting in await restarted.controller.sourceSettings()) {
      effective(setting.source);
    }
    dav.offline = false;
    await restarted.controller.reconnectDavContactsOnly(account.id);
    await restarted.controller.synchronizeAccount(account.id);
    expect(restarted.davSecrets[account.id], encoded);
    expect(
      (await restarted.store.read((tx) => tx.account(account.id)))!
          .grantedScopes,
      {'carddav:write'},
    );
    expect(dav.puts, 0);
    await restarted.controller.removeContactsAccount(account.id);
    expect(
      dav.requests.where(
        (r) => ['PUT', 'DELETE', 'MKCOL', 'PROPPATCH'].contains(r.method),
      ),
      isEmpty,
    );
    expect(dav.card, rawCard);
  });
}
