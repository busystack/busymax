import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
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
}
