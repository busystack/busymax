import 'dart:typed_data';

import 'package:busystack_contacts/carddav.dart';
import 'package:busystack_contacts/google.dart';
import 'package:busystack_contacts/microsoft.dart';
import 'package:busystack_dav/carddav.dart';
import 'package:busymax/src/contacts/read_only_contacts_provider.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

import '../support/contacts_fixture.dart';
import '../support/dav_contacts_fixture.dart';

class _Spy extends Mock implements ContactsProvider {}

void effective(ContactSource source) {
  expect(source.capabilities.create, isFalse);
  expect(source.capabilities.update, isFalse);
  expect(source.capabilities.delete, isFalse);
  expect(source.capabilities.photoWrite, isFalse);
  expect(source.canRename, isFalse);
  expect(source.canRemove, isFalse);
}

Future<void> rejectMutations(
  ContactsProvider provider,
  ContactSource source,
  ContactRecord record,
  List<ContactProviderAction> actions,
) async {
  final token = ContactsCancellationToken();
  const patch = ContactPatch(
    name: FieldEdit.set(ContactName(display: 'Changed')),
  );
  final denied = throwsA(
    isA<ContactsException>().having(
      (error) => error.code,
      'code',
      'busymax-contacts-read-only',
    ),
  );
  for (final attempt in [
    () => provider.create(source, patch, 'id', token, fullVcard: rawCard),
    () => provider.update(source, record, patch, token),
    () => provider.delete(source, record, token),
    () => provider.setPhoto(
      source,
      record,
      Uint8List.fromList([1]),
      'image/png',
      token,
    ),
    for (final action in actions) () => provider.action(action, token),
  ]) {
    await expectLater(attempt(), denied);
  }
}

void main() {
  test(
    'policy preserves unreadable source metadata and delegates read ownership',
    () async {
      final spy = _Spy();
      final token = ContactsCancellationToken();
      const source = ContactSource(
        accountId: 'a',
        id: 'book',
        provider: ContactProviderKind.carddav,
        kind: ContactSourceKind.carddavAddressBook,
        name: 'Book',
        remotePath: 'https://example.test/book/',
        parentId: 'parent',
        versions: ['3.0', '4.0'],
        supportsSync: true,
        maximumResourceBytes: 10000,
        canRename: true,
        canRemove: true,
        capabilities: ContactCapabilities(
          read: false,
          create: true,
          update: true,
          delete: true,
          photoRead: true,
          photoWrite: true,
          fields: {ContactField.name},
          limits: {ContactField.emails: 3},
        ),
      );
      final identity = ContactIdentity(
        accountId: 'a',
        provider: source.provider,
        sourceId: source.id,
        remoteId: 'one.vcf',
      );
      final vcard = parseVcard(rawCard);
      final record = CardDavContactRecord(
        identity: identity,
        vcard: vcard,
        revision: '"one"',
        projection: projectVcard(identity, vcard),
      );
      final batch = ContactsPage(
        records: [record],
        nextPage: 'page2',
        cursor: 'cursor',
        deleted: [identity],
        fullEnumeration: true,
      );
      final bytes = Uint8List.fromList([1, 2]);
      final mutation = ContactMutation(
        id: 'uncertain',
        accountId: 'a',
        sourceKey: source.key,
        kind: ContactMutationKind.create,
        state: ContactMutationState.unknown,
        createdAt: DateTime.utc(2026),
      );
      final action = CardDavBookAction(
        CardDavBookOperation.delete,
        uri: Uri.parse('https://example.test/book/'),
      );
      when(() => spy.accountId).thenReturn('a');
      when(() => spy.kind).thenReturn(source.provider);
      when(() => spy.discover(token)).thenAnswer((_) async => [source]);
      when(
        () =>
            spy.page(source, cursor: 'cursor', page: 'p', cancellation: token),
      ).thenAnswer((_) async => batch);
      when(() => spy.get(source, identity, token))
          .thenAnswer((_) async => record);
      when(() => spy.photo(source, record, token))
          .thenAnswer((_) async => bytes);
      when(() => spy.findCreated(source, mutation, token))
          .thenAnswer((_) async => record);
      when(() => spy.decodeAction(action.toJson().cast())).thenReturn(action);
      final boundary = ReadOnlyContactsProvider(spy);
      expect(boundary.accountId, 'a');
      expect(boundary.kind, source.provider);
      final normalized = (await boundary.discover(token)).single;
      effective(normalized);
      expect(normalized.capabilities.read, isFalse);
      expect(normalized.toJson(), {
        ...source.toJson(),
        'rename': false,
        'remove': false,
        'capabilities': {
          ...source.capabilities.toJson(),
          'create': false,
          'update': false,
          'delete': false,
          'photoWrite': false,
        },
      });
      expect(
        await boundary.page(
          source,
          cursor: 'cursor',
          page: 'p',
          cancellation: token,
        ),
        same(batch),
      );
      expect(await boundary.get(source, identity, token), same(record));
      expect(await boundary.photo(source, record, token), same(bytes));
      expect(await boundary.findCreated(source, mutation, token), same(record));
      expect(boundary.decodeAction(action.toJson().cast()), same(action));
      await rejectMutations(boundary, source, record, [action]);
      // The spy has no mutation stubs: any delegate call would fail this contract.
      verifyNever(() => spy.delete(source, record, token));
      boundary.close();
      verify(() => spy.close()).called(1);
    },
  );
  for (final kind in [
    ContactProviderKind.google,
    ContactProviderKind.microsoft,
    ContactProviderKind.carddav,
  ]) {
    test(
      'actual $kind write-capable provider reads and rejects every mutation without transport',
      () async {
        final fixture = ContactsFixture(AppDatabase.memoryForTests());
        addTearDown(fixture.close);
        final dav = DavFixture();
        final account = ContactAccount(
          id: 'broad',
          provider: kind,
          displayName: 'Broad',
          subject: 'owner',
          grantedScopes: {
            kind == ContactProviderKind.google
                ? 'https://www.googleapis.com/auth/contacts'
                : kind == ContactProviderKind.microsoft
                ? 'Contacts.ReadWrite'
                : 'carddav:write',
          },
        );
        final provider = kind == ContactProviderKind.carddav
            ? CardDavContactsProvider(
                accountId: account.id,
                cachedRecord: (_) async => null,
                client: CardDavClient(
                  DavResourceClient(
                    accountId: account.id,
                    authority: server,
                    transport: DavHttpTransport(
                      profile: const DavProviderProfile(),
                      client: MockClient(dav.respond),
                      accountAuthority: server,
                    ),
                    credentialProvider: () async =>
                        DavBasicCredential(username: 'u', password: 'p'),
                  ),
                ),
              )
            : fixture.provider(account);
        final token = ContactsCancellationToken();
        final rawSources = await provider.discover(token);
        expect(rawSources.any((source) => source.capabilities.create), isTrue);
        final boundary = ReadOnlyContactsProvider(provider);
        addTearDown(boundary.close);
        final sources = await boundary.discover(token);
        for (final source in sources) {
          effective(source);
        }
        final source = rawSources.firstWhere(
          (source) => source.capabilities.create,
        );
        final batch = await boundary.page(source, cancellation: token);
        final record = batch.records.first;
        expect(record.identity.accountId, account.id);
        expect(record.revision, isNotEmpty);
        final before = fixture.requests.length + dav.requests.length;
        await rejectMutations(boundary, source, record, [
          if (kind == ContactProviderKind.google)
            boundary.decodeAction({
              'type': 'googleFields',
              'identity': record.identity.toJson(),
              'revision': record.revision,
              'replacement': {'resourceName': record.identity.remoteId},
              'fields': ['names'],
            }),
          if (kind == ContactProviderKind.google)
            for (final operation in GoogleGroupOperation.values)
              GoogleGroupAction(
                operation,
                resourceName: 'contactGroups/one',
                name: 'Changed',
              ),
          if (kind == ContactProviderKind.microsoft) ...[
            for (final operation in MicrosoftFolderOperation.values)
              MicrosoftFolderAction(
                operation,
                folderId: 'one',
                name: 'Changed',
              ),
            MicrosoftFieldsAction(
              identity: record.identity,
              baseRevision: record.revision,
            ),
          ],
          if (kind == ContactProviderKind.carddav)
            for (final operation in CardDavBookOperation.values)
              CardDavBookAction(
                operation,
                uri: server.resolve('books/u/book/'),
                name: 'Changed',
              ),
        ]);
        expect(fixture.requests.length + dav.requests.length, before);
        expect(dav.puts, 0);
      },
    );
  }
}
