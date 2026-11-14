import 'dart:io';

import 'package:busystack_contacts/busystack_contacts.dart';
import 'package:busymax/src/android/android_local_network_access.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/contacts_fixture.dart';
import '../../support/dav_contacts_fixture.dart';
import '../../support/persistence_test_directory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('headless contacts revocation retains account, credentials and cache across restart while public accounts continue', () async {
    // Keep real SQLite files and durability while avoiding host journal latency.
    final directory = await createPersistenceTestDirectory(
      'busymax-contact-permission-',
    );
    addTearDown(() => directory.delete(recursive: true));
    var granted = true, prompts = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('io.busystack.busymax/android');
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'requiresLocalNetworkAccess':
          return (call.arguments as Map)['host'] == 'blocked.example.test';
        case 'hasLocalNetworkAccess':
          return granted;
        case 'requestLocalNetworkAccess':
          prompts++;
          return granted;
        default:
          throw StateError('Unexpected ${call.method}');
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    ContactsFixture open() {
      final f = ContactsFixture(
        AppDatabase(NativeDatabase(File('${directory.path}/qa.sqlite'))),
        realDav: true,
        requireDavServerAccess: requireAndroidContactsServerAccess,
      );
      final dav = DavFixture();
      f.respondDav = dav.respond;
      return f;
    }

    var f = open();
    addTearDown(() => f.close());
    for (final id in ['blocked', 'public']) {
      await f.controller.addCardDavContactsOnly(
        id: id,
        label: id,
        server: Uri.parse('https://$id.example.test/nextcloud/'),
        username: 'qa-$id',
        password: 'synthetic',
      );
    }
    await f.controller.synchronizeAll();
    final before = await f.store.read((tx) => tx.account('blocked'));
    final cached = (await f.store.read((tx) => tx.contacts()))
        .where((r) => r.identity.accountId == 'blocked')
        .map((r) => r.toJson())
        .toList();
    final secrets = Map<String, String>.from(f.davSecrets);
    granted = false;
    f.requests.clear();
    await expectLater(
      f.controller.synchronizeAll(),
      throwsA(
        isA<ContactsException>().having(
          (e) => e.code,
          'code',
          'android-local-network-required',
        ),
      ),
    );
    expect(
      f.requests.where((r) => r.url.host == 'blocked.example.test'),
      isEmpty,
    );
    expect(
      f.requests.where((r) => r.url.host == 'public.example.test'),
      isNotEmpty,
    );
    expect(prompts, 0);
    expect(f.davSecrets, secrets);
    expect(
      (await f.store.read((tx) => tx.contacts()))
          .where((r) => r.identity.accountId == 'blocked')
          .map((r) => r.toJson()),
      cached,
    );
    await f.close();
    f = open()..davSecrets.addAll(secrets);
    await f.controller.start();
    await expectLater(
      f.controller.synchronizeAccount('blocked'),
      throwsA(isA<ContactsException>()),
    );
    expect(
      f.requests.where((r) => r.url.host == 'blocked.example.test'),
      isEmpty,
    );
    expect(prompts, 0);
    expect(
      (await f.store.read((tx) => tx.account('blocked')))!.generation,
      before!.generation,
    );
    granted = true;
    await f.controller.synchronizeAccount('blocked');
    expect(
      f.requests.where((r) => r.url.host == 'blocked.example.test'),
      isNotEmpty,
    );
    expect(
      (await f.store.read((tx) => tx.account('blocked')))!.errorCode,
      isNull,
    );
    expect(f.davSecrets, secrets);
  });
}
