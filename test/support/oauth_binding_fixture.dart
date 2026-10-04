import 'dart:convert';

import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const fixtureTenant = '11111111-1111-1111-1111-111111111111';
const fixtureMicrosoftClient = '22222222-2222-2222-2222-222222222222';
String get fixtureMicrosoftIdToken =>
    'header.${base64UrlEncode(utf8.encode(jsonEncode({'tid': fixtureTenant, 'aud': fixtureMicrosoftClient})))}.signature';

/// Seed explicitly known synthetic issuing registrations, using production
/// envelopes and persistence. This is fixture construction, not auth behavior.
Future<AuthorizationPersistence> seedBoundFixtures(SecretStore store) async {
  final db = AppDatabase.memoryForTests();
  addTearDown(db.close);
  final persistence = AuthorizationPersistence(database: db, secrets: store);
  final ids = [
    'account',
    'google:subject',
    'google-a',
    'google-b',
    'microsoft:user',
    'microsoft:user-1',
    'microsoft:account',
  ];
  for (final id in ids) {
    final record = await store.readCredential(id);
    if (record is! OAuthSecretRecord || record is BoundOAuthSecretRecord) {
      continue;
    }
    final subject = id.contains(':') ? id.split(':').last : id;
    await AccountsRepository(database: db).upsertSignedInAccount(
      id: id,
      provider: record.provider,
      providerAccountId: subject,
      tenantId: record.provider == BusyProvider.microsoft
          ? fixtureTenant
          : null,
      grantedScopes: record.tokenSet.scopes.join(' '),
    );
    final BoundOAuthSecretRecord bound = record.provider == BusyProvider.google
        ? GoogleDesktopCredential(
            registration: const GoogleDesktopRegistration(
              clientId: 'client-id.apps.googleusercontent.com',
              projectId: 'fixture-project',
            ),
            tokenSet: record.tokenSet,
            subject: subject,
            generation: 1,
            transitionEligible: false,
          )
        : MicrosoftDesktopCredential(
            registration: MicrosoftPublicRegistration(
              clientId: fixtureMicrosoftClient,
              audience: MicrosoftAudience.personalAndOrganizations,
            ),
            tenantId: fixtureTenant,
            tokenSet: record.tokenSet,
            subject: subject,
            generation: 1,
            transitionEligible: false,
          );
    await persistence.commit(
      accountId: id,
      expectedGeneration: 0,
      candidate: bound,
      requireExisting: true,
      persistAccount: () async {},
    );
  }
  return persistence;
}
