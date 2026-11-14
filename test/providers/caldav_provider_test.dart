import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/providers/account_authority.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';

void main() {
  test(
    'mixed collection warnings include RFC default and additional components',
    () {
      for (final mask in [1, 2, 3, 31]) {
        final source = CalendarSourceEntity(
          id: 'collection',
          accountId: 'account',
          provider: BusyProvider.caldav,
          providerCalendarId: '/mixed/',
          summary: 'Mixed',
          selected: true,
          hidden: false,
          readOnly: false,
          isDeleted: false,
          davEffectivePermissions: {'supportedComponentMask': mask},
        );
        expect(source.isMixedDavCollection, mask & 3 == 3);
      }
    },
  );
  test('CalDAV URL identity retains encoded paths, custom ports and trailing slash', () {
    expect(
      normalizeCalDavAuthority('HTTPS://DAV.Example.test:8443/install/a%2Fb/'),
      'https://dav.example.test:8443/install/a%2Fb/',
    );
    expect(
      normalizeCalDavAuthority('https://dav.example.test'),
      'https://dav.example.test/',
    );
    expect(
      normalizeCalDavAuthority('https://dav.example.test/dav'),
      'https://dav.example.test/dav',
    );
    for (final url in [
      'http://dav.example.test/',
      '//dav.example.test/',
      'dav.example.test',
      'https://user:secret@dav.example.test/',
      'https://dav.example.test/#secret',
      'https://dav.example.test/?secret',
      'https://dav.example.test/a\\b',
      'https://dav.example.test/%zz',
      'https://dav.example.test:0/',
      'https://dav.example.test:65536/',
    ]) {
      expect(
        () => normalizeCalDavAuthority(url),
        throwsA(isA<InvalidAccountAuthorityException>()),
      );
    }
  });

  test('generic discovery and credential forwarding are scoped to the HTTPS origin', () {
    final authority = Uri.parse('https://example.test:8443/install/dav.php/');
    final profile = davProviderProfile(
      BusyProvider.caldav,
      caldavServer: authority,
    );
    expect(
      davWellKnownUri(profile).toString(),
      'https://example.test:8443/.well-known/caldav',
    );
    expect(
      profile.isTrustedCredentialDestination(
        Uri.parse('https://example.test:8443/principals/user/'),
        accountAuthority: authority,
      ),
      isTrue,
    );
    for (final url in [
      'https://other.test:8443/',
      'http://example.test:8443/',
      'https://example.test/',
      'https://user@example.test:8443/',
    ]) {
      expect(
        profile.isTrustedCredentialDestination(
          Uri.parse(url),
          accountAuthority: authority,
        ),
        isFalse,
      );
    }
    expect(profile.allowSchedulingMutations, isFalse);
    expect(providerProfiles[BusyProvider.caldav]!.allowsGenericServer, isTrue);
    expect(providerProfiles[BusyProvider.caldav]!.allowsInsecureHttp, isFalse);
  });

  test(
    'CalDAV secrets round trip with exact password and redact all fields',
    () {
      final secret = CalDavSecretRecord(
        serviceAuthority: Uri.parse('https://example.test/a%2Fb/'),
        username: 'user',
        password: ' password with spaces ',
      );
      final decoded =
          SecretRecord.fromJson(secret.toJson()) as CalDavSecretRecord;
      expect(
        decoded.serviceAuthority.toString(),
        'https://example.test/a%2Fb/',
      );
      expect(decoded.password, ' password with spaces ');
      expect(decoded.kind, CredentialKind.caldavPassword);
      expect(decoded.toString(), isNot(contains('password with spaces')));
      expect(decoded.toString(), isNot(contains('example.test')));
      expect(
        () => SecretRecord.fromJson({
          ...secret.toJson(),
          'provider': 'nextcloud',
        }),
        throwsA(isA<SecretStoreCorruptException>()),
      );
      for (final username in ['', 'user:injected', 'user\nheader']) {
        expect(
          () => CalDavSecretRecord(
            serviceAuthority: Uri.parse('https://example.test/'),
            username: username,
            password: 'secret',
          ),
          throwsA(isA<SecretStoreCorruptException>()),
        );
      }
    },
  );

  test('unadvertised permissions are distinct from permitted and denied', () {
    const unknown = CollectionCapabilities(
      permissionsKnown: false,
      canRead: true,
      supportsEvents: true,
      supportsTasks: true,
    );
    expect(unknown.canWriteContent, isFalse);
    expect(unknown.canCreateEvent, isFalse);
    expect(unknown.isReadOnly, isFalse);
    expect(unknown.canAttemptCreateEvent, isTrue);
    expect(unknown.canAttemptUpdateTask, isTrue);
    const denied = CollectionCapabilities(supportsEvents: true, canRead: true);
    expect(denied.isReadOnly, isTrue);
    expect(denied.canAttemptCreateEvent, isFalse);
    const subscribed = CollectionCapabilities(
      permissionsKnown: false,
      allowsItemMutations: false,
      supportsEvents: true,
    );
    expect(subscribed.canAttemptUpdateEvent, isFalse);
  });
}
