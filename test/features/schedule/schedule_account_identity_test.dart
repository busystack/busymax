import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_sidebar_sources.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (provider, name, email, authority, expected) in [
    (BusyProvider.google, 'Work', null, 'https://accounts.google.com', null),
    (
      BusyProvider.google,
      'Work',
      'me@example.com',
      'https://accounts.google.com',
      'me@example.com',
    ),
    (
      BusyProvider.microsoft,
      null,
      'me@example.com',
      'https://login.microsoftonline.com/common',
      null,
    ),
    (
      BusyProvider.nextcloud,
      'Work',
      null,
      'https://cloud.example.test:443/dav/',
      'cloud.example.test',
    ),
    (
      BusyProvider.nextcloud,
      'Work',
      null,
      'https://cloud.example.test:8443/dav/',
      'cloud.example.test:8443',
    ),
    (
      BusyProvider.nextcloud,
      'Work',
      null,
      'https://[2001:db8::1]:8443/dav/',
      '[2001:db8::1]:8443',
    ),
    (
      BusyProvider.nextcloud,
      'Work',
      'me@example.com',
      'https://cloud.example.test/dav/',
      'me@example.com',
    ),
    (BusyProvider.caldav, 'Work', null, 'https://dav.example.test/', null),
  ]) {
    test('sidebar identity: $provider, $name, $email, $authority', () {
      expect(
        scheduleAccountSecondaryLabel(
          AccountEntity(
            id: 'account',
            provider: provider,
            authority: authority,
            providerAccountId: 'me',
            authState: accountAuthStateSignedIn,
            displayName: name,
            email: email,
          ),
        ),
        expected,
      );
    });
  }
}
