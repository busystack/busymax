import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selector label keeps identical emails distinct across providers', () {
    const google = AccountEntity(
      id: 'google-account',
      provider: BusyProvider.google,
      authority: 'https://accounts.google.com',
      providerAccountId: 'google-user',
      authState: accountAuthStateSignedIn,
      displayName: 'Personal account',
      email: 'user@example.test',
    );
    const nextcloud = AccountEntity(
      id: 'nextcloud-account',
      provider: BusyProvider.nextcloud,
      authority: 'https://cloud.example.test',
      providerAccountId: 'nextcloud-user',
      authState: accountAuthStateSignedIn,
      displayName: 'Personal account',
      email: 'user@example.test',
    );

    expect(google.selectorLabel, 'Google · user@example.test');
    expect(nextcloud.selectorLabel, 'Nextcloud · user@example.test');
  });

  test('Nextcloud selector falls back to profile name and server', () {
    const account = AccountEntity(
      id: 'nextcloud-account',
      provider: BusyProvider.nextcloud,
      authority: 'https://cloud.example.test:8443',
      providerAccountId: 'nextcloud-user',
      authState: accountAuthStateSignedIn,
      displayName: 'Personal account',
    );

    expect(
      account.selectorLabel,
      'Nextcloud · Personal account · cloud.example.test:8443',
    );
  });

  test('selector falls back to the provider when identity is unavailable', () {
    const account = AccountEntity(
      id: 'google-account',
      provider: BusyProvider.google,
      authority: 'https://accounts.google.com',
      providerAccountId: 'google-user',
      authState: accountAuthStateSignedIn,
    );

    expect(account.selectorLabel, 'Google');
  });

  test(
    'subscription predicates separate auth, task, schedule, and sync use',
    () {
      const account = AccountEntity(
        id: 'webcal-account-sub',
        provider: BusyProvider.webCal,
        authority: 'https://calendar.example.test',
        providerAccountId: 'fingerprint',
        credentialKind: CredentialKind.webCalSubscription,
        authState: accountAuthStateSignedIn,
        displayName: 'Subscription',
        tasksEnabled: false,
      );

      expect(account.isSubscription, isTrue);
      expect(account.isAuthenticationAccount, isFalse);
      expect(account.isTaskCapable, isFalse);
      expect(account.isScheduleVisible, isTrue);
      expect(account.isSyncEligible, isTrue);
    },
  );

  test(
    'subscription is sync-visible but excluded from auth account queries',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'webcal-account-sub',
              provider: 'webcal',
              authority: 'https://calendar.example.test',
              providerAccountId: 'fingerprint',
              credentialKind: 'webcal_subscription',
              authState: const Value(accountAuthStateSignedIn),
              calendarsEnabled: const Value(true),
              tasksEnabled: const Value(false),
              grantedScopes: const Value(''),
              createdAtUtc: '2026-08-29T00:00:00.000Z',
              updatedAtUtc: '2026-08-29T00:00:00.000Z',
            ),
          );
      final repository = AccountsRepository(database: database);

      expect(
        (await repository.watchAccounts().first).single.isSubscription,
        isTrue,
      );
      expect(await repository.watchVisibleAccounts().first, isEmpty);
      expect(await repository.listVisibleAccounts(), isEmpty);
      expect(await repository.listSignedInAccounts(), isEmpty);
      expect(
        (await repository.listSyncEligibleAccounts()).single.provider,
        BusyProvider.webCal,
      );
    },
  );

  test('rejects a credential kind that does not match the provider', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = AccountsRepository(database: database);

    await expectLater(
      repository.upsertSignedInAccount(
        id: 'invalid',
        provider: BusyProvider.google,
        grantedScopes: '',
        credentialKind: CredentialKind.webCalSubscription,
      ),
      throwsArgumentError,
    );
    expect(await database.select(database.accounts).get(), isEmpty);
  });
}
