import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/account_authority.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider identity has stable storage values', () {
    expect(BusyProvider.values, [
      BusyProvider.google,
      BusyProvider.microsoft,
      BusyProvider.appleICloud,
      BusyProvider.nextcloud,
      BusyProvider.webCal,
    ]);
    expect(BusyProvider.values.map((provider) => provider.storageValue), [
      'google',
      'microsoft',
      'apple_icloud',
      'nextcloud',
      'webcal',
    ]);
  });

  test('stored provider parsing is total and never falls back', () {
    expect(
      BusyProviderCodec.parseStorageValue('google'),
      isA<SupportedBusyProvider>().having(
        (result) => result.value,
        'value',
        BusyProvider.google,
      ),
    );
    expect(
      BusyProviderCodec.parseStorageValue('GOOGLE'),
      isA<UnsupportedStoredProvider>(),
    );
    expect(
      BusyProviderCodec.parseStorageValue('caldav'),
      isA<UnsupportedStoredProvider>(),
    );
    expect(
      () => BusyProviderCodec.requireStorageValue(null),
      throwsA(isA<UnsupportedStoredProviderException>()),
    );
  });

  test('authorities are deterministic and provider-specific', () {
    expect(
      normalizeAccountAuthority(BusyProvider.google, authority: 'ignored'),
      googleAccountAuthority,
    );
    expect(
      normalizeAccountAuthority(BusyProvider.microsoft, tenantId: 'TENANT-ID'),
      '$microsoftAuthorityOrigin/tenant-id',
    );
    expect(
      normalizeAccountAuthority(BusyProvider.appleICloud),
      appleICloudAccountAuthority,
    );
    expect(
      normalizeAccountAuthority(
        BusyProvider.nextcloud,
        authority: 'https://Cloud.Example.test/nextcloud///',
      ),
      'https://cloud.example.test/nextcloud',
    );
    expect(
      normalizeProviderAccountId(
        BusyProvider.appleICloud,
        ' User@Example.COM ',
      ),
      'user@example.com',
    );
  });

  test('Nextcloud authority rejects unsafe or ambiguous server values', () {
    for (final value in [
      'http://cloud.example.test',
      'https://user@cloud.example.test',
      'https://cloud.example.test/path?credential=value',
      'https://cloud.example.test/path#fragment',
      'not a URI',
    ]) {
      expect(
        () => normalizeNextcloudServerAuthority(value),
        throwsA(isA<InvalidAccountAuthorityException>()),
        reason: value,
      );
    }
  });

  test('effective collection capabilities require both ACL and component', () {
    const readOnly = CollectionCapabilities(
      canRead: true,
      supportsEvents: true,
      supportsTasks: true,
    );
    expect(readOnly.isReadOnly, isTrue);
    expect(readOnly.canCreateEvent, isFalse);
    expect(readOnly.canUpdateTask, isFalse);

    const writableEvents = CollectionCapabilities(
      canRead: true,
      canWriteContent: true,
      canAddMembers: true,
      canDeleteMembers: true,
      supportsEvents: true,
    );
    expect(writableEvents.canCreateEvent, isTrue);
    expect(writableEvents.canDeleteEvent, isTrue);
    expect(writableEvents.canCreateTask, isFalse);
  });

  test('same Nextcloud login is unique per normalized authority', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const now = '2026-08-08T00:00:00.000Z';

    Future<void> insert(String id, String authority) {
      return database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: id,
              provider: 'nextcloud',
              authority: authority,
              providerAccountId: 'alex',
              credentialKind: 'nextcloud_app_password',
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
    }

    await insert('account-a', 'https://one.example.test');
    await insert('account-b', 'https://two.example.test');
    await expectLater(
      insert('account-c', 'https://one.example.test'),
      throwsA(anything),
    );
    expect(await database.select(database.accounts).get(), hasLength(2));
  });
}
