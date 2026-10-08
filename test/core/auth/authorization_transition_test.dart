import '../../support/desktop_registration_config.dart';
import '../../support/native_registration_reader_fixture.dart';

import 'package:busymax/src/core/auth/authorization_attempt.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/auth/registration_staging.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart' hide AuthorizationCommit;
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const original = GoogleDesktopRegistration(
  clientId: 'original.apps.googleusercontent.com',
  projectId: 'original-project',
  origin: RegistrationOrigin.retiringShared,
);
const owned = GoogleDesktopRegistration(
  clientId: 'owned.apps.googleusercontent.com',
  projectId: 'owned-project',
);
const tenant = '11111111-1111-1111-1111-111111111111';
const msOwned = '33333333-3333-3333-3333-333333333333';
const config = BuildConfig(
  googleOAuthClientId: 'original.apps.googleusercontent.com',
  googleOAuthClientSecret: '',
  microsoftOAuthClientId: '22222222-2222-2222-2222-222222222222',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);
OAuthTokenSet tokens([String refresh = 'working-refresh']) => OAuthTokenSet(
  accessToken: 'working-access',
  refreshToken: refresh,
  tokenType: 'Bearer',
  expiresAtUtc: DateTime.utc(2040),
  scopes: {googleTasksReadWriteScope, googleCalendarReadWriteScope},
);
String fixtureIdToken(String client) =>
    'header.${base64UrlEncode(utf8.encode(jsonEncode({'tid': tenant, 'aud': client})))}.signature';

void main() {
  test(
    'import paths accept native Windows drives without accepting URI sources',
    () {
      expect(
        isSupportedRegistrationFilePath(
          r'C:\Users\fixture\desktop.json',
          windows: true,
        ),
        true,
      );
      expect(
        isSupportedRegistrationFilePath(
          'D:/fixture/desktop.json',
          windows: true,
        ),
        true,
      );
      for (final path in [
        'file:///C:/desktop.json',
        'https://example.invalid/desktop.json',
        r'\\server\share\desktop.json',
        r'C:relative.json',
      ]) {
        expect(isSupportedRegistrationFilePath(path, windows: true), false);
      }
      expect(
        isSupportedRegistrationFilePath('/tmp/desktop.json', windows: false),
        true,
      );
    },
  );
  late Harness h;
  setUp(() {
    h = Harness();
  });
  tearDown(() async {
    h.staging.dispose();
    await h.db.close();
  });
  for (final origin in [
    RegistrationOrigin.busyMaxManaged,
    RegistrationOrigin.userProvided,
  ]) {
    for (final audience in [
      MicrosoftAudience.organizations,
      MicrosoftAudience.tenant,
    ]) {
      test(
        '$origin $audience binding survives a changed managed build',
        () async {
          h.staging.dispose();
          await h.db.close();
          h = Harness(
            buildConfig: syntheticDesktopConfig(
              later: true,
              originalMicrosoftAuthority: 'consumers',
            ),
          );
          final issuingRegistration = MicrosoftPublicRegistration(
            clientId: origin == RegistrationOrigin.busyMaxManaged
                ? syntheticDesktopConfig().busyMaxMicrosoftOAuthClientId
                : msOwned,
            audience: audience,
            tenantId: audience == MicrosoftAudience.tenant ? tenant : null,
            origin: origin,
          );
          await h.seedMicrosoft(
            shared: false,
            registration: issuingRegistration,
          );
          const id = 'microsoft:ms-user';
          final saved = (await h.secrets.readCredential(id))!;
          await h.secrets.saveCredential(
            id,
            SecretRecord.fromJson(jsonDecode(jsonEncode(saved.toJson()))),
          );

          await h.microsoft.refreshTokenForAccount(id);
          await h.microsoft.connectMicrosoft(
            AuthorizationRequest.reconnect(id),
          );
          expect(h.requests.where((r) => r.method == 'POST'), isNotEmpty);
          expect(
            h.requests
                .where((r) => r.method == 'POST')
                .every(
                  (r) =>
                      r.url.path.startsWith(
                        '/${issuingRegistration.authorityTenant}/',
                      ) &&
                      Uri.splitQueryString(r.body)['client_id'] ==
                          issuingRegistration.clientId,
                ),
            isTrue,
          );
          expect(h.flow.clients, [issuingRegistration.clientId]);
          final finalRecord =
              await h.secrets.readCredential(id) as BoundOAuthSecretRecord;
          final registration =
              finalRecord.registration as MicrosoftPublicRegistration;
          expect(registration.clientId, issuingRegistration.clientId);
          expect(registration.audience, audience);
          expect(registration.tenantId, issuingRegistration.tenantId);
          expect(registration.origin, origin);
          expect(
            h.staging.stageBusyMax(BusyProvider.microsoft).summary.authority,
            'common',
          );
        },
      );
    }
  }
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    test(
      '$provider managed credentials remain account-bound after restart and a changed build',
      () async {
        h.staging.dispose();
        await h.db.close();
        h = Harness(buildConfig: syntheticDesktopConfig());
        final handle = h.staging.stageBusyMax(provider);
        if (provider == BusyProvider.google) {
          await h.repository.signIn(
            request: AuthorizationRequest.newConnection(handle),
          );
        } else {
          await h.repository.signInWithMicrosoft(
            request: AuthorizationRequest.newConnection(handle),
          );
        }
        final id = provider == BusyProvider.google
            ? 'google:subject'
            : 'microsoft:ms-user';
        final saved =
            await h.secrets.readCredential(id) as BoundOAuthSecretRecord;
        // Exercise the secure envelope decoder rather than retain an in-memory object.
        await h.secrets.saveCredential(
          id,
          SecretRecord.fromJson(jsonDecode(jsonEncode(saved.toJson()))),
        );
        expect((await h.summary(id)).origin, RegistrationOrigin.busyMaxManaged);
        expect((await h.summary(id)).showRetirementNotice, isFalse);
        final later = syntheticDesktopConfig(later: true);
        final laterStaging = RegistrationStaging(later);
        addTearDown(laterStaging.dispose);
        final restartedPersistence = AuthorizationPersistence(
          database: h.db,
          secrets: h.secrets,
        );
        if (provider == BusyProvider.google) {
          final restarted = OAuthService(
            config: later,
            httpClient: h.client,
            tokenStore: h.secrets,
            loopbackFlow: h.flow,
            registrations: laterStaging,
            persistence: restartedPersistence,
          );
          await restarted.refreshTokenForAccount(id);
          await restarted.connectGoogle(AuthorizationRequest.reconnect(id));
        } else {
          final restarted = MicrosoftOAuthService(
            config: later,
            httpClient: h.client,
            tokenStore: h.secrets,
            loopbackFlow: h.flow,
            registrations: laterStaging,
            persistence: restartedPersistence,
          );
          await restarted.refreshTokenForAccount(id);
          await restarted.connectMicrosoft(AuthorizationRequest.reconnect(id));
          await restarted.authorizeCategoryAccess(id);
          await restarted.authorizeSharedCalendarAccess(id);
          expect(h.flow.lastScope, contains(microsoftCategoryScope));
          expect(h.flow.lastScope, contains(microsoftSharedCalendarScope));
          expect(
            h.requests
                .where((r) => r.method == 'POST')
                .every((r) => r.url.path.startsWith('/common/')),
            isTrue,
          );
        }
        final issuingClient = handle.summary.clientId;
        expect(h.flow.clients.every((c) => c == issuingClient), isTrue);
        expect(
          h.requests
              .where((r) => r.method == 'POST')
              .every(
                (r) =>
                    Uri.splitQueryString(r.body)['client_id'] == issuingClient,
              ),
          isTrue,
        );
        final finalRecord =
            await h.secrets.readCredential(id) as BoundOAuthSecretRecord;
        expect(finalRecord.registration.clientId, issuingClient);
        expect(
          finalRecord.registration.summary().origin,
          RegistrationOrigin.busyMaxManaged,
        );
      },
    );
    test(
      '$provider explicit replacement can select a managed registration without changing account identity',
      () async {
        h.staging.dispose();
        await h.db.close();
        h = Harness(buildConfig: syntheticDesktopConfig());
        if (provider == BusyProvider.google) {
          await h.seed();
        } else {
          await h.seedMicrosoft(shared: true);
        }
        final id = provider == BusyProvider.google
            ? 'opaque'
            : 'microsoft:ms-user';
        final before = await h.accounts.accountById(id);
        final selected = h.staging.stageBusyMax(provider);
        if (provider == BusyProvider.google) {
          await h.repository.signIn(
            request: AuthorizationRequest.replace(id, selected),
          );
        } else {
          await h.repository.signInWithMicrosoft(
            request: AuthorizationRequest.replace(id, selected),
          );
        }
        final after = await h.accounts.accountById(id);
        expect(after!.providerAccountId, before!.providerAccountId);
        expect(after.tasksEnabled, before.tasksEnabled);
        expect(await h.persistence.generation(id), 2);
        expect((await h.summary(id)).origin, RegistrationOrigin.busyMaxManaged);
        expect((await h.summary(id)).showRetirementNotice, isFalse);
        expect(h.flow.clients.single, selected.summary.clientId);
      },
    );
    test(
      '$provider active build never promotes an existing original credential',
      () async {
        h.staging.dispose();
        await h.db.close();
        h = Harness(buildConfig: syntheticDesktopConfig());
        if (provider == BusyProvider.google) {
          await h.seed();
        } else {
          await h.seedMicrosoft(shared: true);
        }
        final id = provider == BusyProvider.google
            ? 'opaque'
            : 'microsoft:ms-user';
        final existing = provider == BusyProvider.google
            ? await h.google.boundCredentialForAccount(id)
            : await h.microsoft.boundCredentialForAccount(id);
        expect(
          existing.registration.summary().origin,
          RegistrationOrigin.retiringShared,
        );
        expect(
          existing.registration.clientId,
          provider == BusyProvider.google
              ? config.googleOAuthClientId
              : config.microsoftOAuthClientId,
        );
        if (provider == BusyProvider.google) {
          await h.google.connectGoogle(AuthorizationRequest.reconnect(id));
        } else {
          await h.microsoft.connectMicrosoft(
            AuthorizationRequest.reconnect(id),
          );
        }
        expect(h.flow.clients.single, existing.registration.clientId);
        expect(
          (await h.secrets.readCredential(id) as BoundOAuthSecretRecord)
              .registration
              .summary()
              .origin,
          RegistrationOrigin.retiringShared,
        );
      },
    );
  }

  test(
    'a symlink substituted after path preparation cannot be imported',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'busymax-config-substitution-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final selected = File('${directory.path}/selected.json');
      final substitute = File('${directory.path}/substitute.json');
      final fixture = await File('test/fixtures/oauth/desktop_synthetic.json')
          .readAsString();
      await selected.writeAsString(fixture);
      await substitute.writeAsString(fixture);
      final staging = RegistrationStaging(
        config,
        fileReader: await buildNativeRegistrationReader(),
        beforeConfigurationOpen: () async {
          await selected.delete();
          await Link(selected.path).create(substitute.path);
        },
      );
      addTearDown(staging.dispose);
      await expectLater(
        staging.importGoogle(XFile(selected.path)),
        throwsA(
          isA<OAuthException>().having(
            (error) => error.code,
            'actual object rejected',
            'OAuthUnsupportedFileSource',
          ),
        ),
      );
    },
    // Includes a cold CMake/MSVC build on Windows CI.
    timeout: const Timeout(Duration(minutes: 2)),
  );
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    test(
      'cancellation before recovery finishes prevents later desktop dispatch: $provider',
      () async {
        final request = provider == BusyProvider.google
            ? AuthorizationRequest.newConnection(h.staging.stage(owned))
            : AuthorizationRequest.newConnection(
                h.staging.stageMicrosoft(
                  clientId: msOwned,
                  audience: MicrosoftAudience.personalAndOrganizations,
                ),
              );
        final operation = provider == BusyProvider.google
            ? h.repository.signIn(request: request)
            : h.repository.signInWithMicrosoft(request: request);
        final rejected = expectLater(
          operation,
          throwsA(
            isA<OAuthException>().having(
              (e) => e.classification,
              'cancelled',
              OAuthFailureKind.cancelled,
            ),
          ),
        );
        await h.repository.cancelSignIn();
        await rejected;
        expect(h.flow.clients, isEmpty);
        expect(h.requests, isEmpty);
        expect(await h.accounts.listVisibleAccounts(), isEmpty);
      },
    );
  }
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    for (final shared in [false, true]) {
      for (final scenario in [
        (400, 'invalid_client', OAuthFailureKind.configuration),
        (400, 'invalid_scope', OAuthFailureKind.configuration),
        (400, 'invalid_grant', OAuthFailureKind.authorizationCode),
        (429, 'invalid_grant', OAuthFailureKind.throttled),
        (503, 'invalid_grant', OAuthFailureKind.temporary),
        (400, 'unknown-sensitive-value', OAuthFailureKind.temporary),
      ]) {
        test(
          'complete replacement preserves original after exchange ${scenario.$1}/${scenario.$2} $provider shared=$shared',
          () async {
            final id = provider == BusyProvider.google
                ? 'opaque'
                : 'microsoft:ms-user';
            if (provider == BusyProvider.google) {
              await h.seed();
              if (!shared) await h.makeGoogleUserOwned();
            } else {
              await h.seedMicrosoft(shared: shared);
            }
            final before = (await h.secrets.readCredential(id))!.toJson();
            final previousGeneration = await h.persistence.generation(id);
            h.beforeRequest = (r) async => r.method == 'POST'
                ? http.Response(
                    jsonEncode({
                      'error': scenario.$2,
                      'error_description': 'sensitive-description',
                    }),
                    scenario.$1,
                    headers: {'retry-after': '7200'},
                  )
                : null;
            AuthorizationRequest request() => AuthorizationRequest.replace(
              id,
              provider == BusyProvider.google
                  ? h.staging.stage(owned)
                  : h.staging.stageMicrosoft(
                      clientId: msOwned,
                      audience: MicrosoftAudience.personalAndOrganizations,
                    ),
            );
            Future<AuthSessionState> connect(AuthorizationRequest r) =>
                provider == BusyProvider.google
                ? h.repository.signIn(request: r)
                : h.repository.signInWithMicrosoft(request: r);
            await expectLater(
              connect(request()),
              throwsA(
                isA<OAuthAuthorizationException>()
                    .having(
                      (e) => e.classification,
                      'safe recovery',
                      scenario.$3,
                    )
                    .having(
                      (e) => e.toString(),
                      'redaction',
                      isNot(contains('sensitive')),
                    )
                    .having(
                      (e) => e.retryAfter,
                      'timing',
                      const Duration(hours: 2),
                    ),
              ),
            );
            expect(h.requests.length, 1);
            expect((await h.secrets.readCredential(id))!.toJson(), before);
            expect(await h.persistence.generation(id), previousGeneration);
            expect((await h.summary(id)).showRetirementNotice, shared);
            h.beforeRequest = null;
            await connect(request());
            expect(await h.persistence.generation(id), previousGeneration + 1);
            expect((await h.summary(id)).showRetirementNotice, false);
          },
        );
      }
    }
  }
  for (final shared in [false, true]) {
    test(
      'optional Microsoft consent captures cancellation during binding preparation shared=$shared',
      () async {
        await h.seedMicrosoft(shared: shared);
        final before = (await h.secrets.readCredential('microsoft:ms-user'))!
            .toJson();
        final cancellation = AuthorizationCancellation();
        final work = h.microsoft.authorizeCategoryAccess(
          'microsoft:ms-user',
          cancellation: cancellation,
        );
        final failed = expectLater(
          work,
          throwsA(
            isA<OAuthException>().having(
              (e) => e.classification,
              'cancelled',
              OAuthFailureKind.cancelled,
            ),
          ),
        );
        cancellation.cancel();
        await failed;
        expect(h.flow.clients, isEmpty);
        expect(h.requests, isEmpty);
        expect(
          (await h.secrets.readCredential('microsoft:ms-user'))!.toJson(),
          before,
        );
        await h.microsoft.authorizeCategoryAccess('microsoft:ms-user');
        expect(
          (await h.secrets.readCredential(
            'microsoft:ms-user',
          ) as MicrosoftDesktopCredential).tokenSet.scopes,
          contains(microsoftCategoryScope),
        );
      },
    );
  }
  test('shared compiled values never give new accounts a shortcut', () async {
    await expectLater(h.google.signIn(), throwsA(isA<OAuthException>()));
    await expectLater(h.microsoft.signIn(), throwsA(isA<OAuthException>()));
    expect(h.requests, isEmpty);
    expect(await h.accounts.listVisibleAccounts(), isEmpty);
  });
  test('normal legacy binding during consent does not advance authorization generation', () async {
    await h.seed();
    await h.db.delete(h.db.authorizationGenerations).go();
    await h.db.delete(h.db.accountAuthorizations).go();
    await h.secrets.saveCredential(
      'opaque',
      OAuthSecretRecord(provider: BusyProvider.google, tokenSet: tokens()),
    );
    h.flow.barrier = Completer<void>();
    final migration = h.repository.signIn(
      request: AuthorizationRequest.replace('opaque', h.staging.stage(owned)),
    );
    await h.flow.started.future;
    final originalBound = await h.google.boundCredentialForAccount('opaque');
    expect(originalBound.generation, 0);
    expect(await h.persistence.generation('opaque'), 0);
    expect(
      SecretRecord.fromJson(originalBound.toJson()),
      isA<GoogleDesktopCredential>(),
    );
    h.flow.barrier!.complete();
    await migration;
    final migrated =
        await h.secrets.readCredential('opaque') as GoogleDesktopCredential;
    expect(migrated.generation, 1);
    expect(migrated.registration.clientId, owned.clientId);
    expect(migrated.transitionEligible, false);
  });
  test(
    'committed binding receipt recovers without rolling back generation zero',
    () async {
      await h.seed();
      await h.db.delete(h.db.authorizationGenerations).go();
      await h.db.delete(h.db.accountAuthorizations).go();
      await h.secrets.saveCredential(
        'opaque',
        OAuthSecretRecord(provider: BusyProvider.google, tokenSet: tokens()),
      );
      await h.db.customStatement(
        "CREATE TRIGGER retain_receipt BEFORE DELETE ON authorization_commits BEGIN SELECT RAISE(ABORT, 'injected cleanup'); END",
      );
      await h.google.boundCredentialForAccount('opaque');
      final journal =
          (await h.db.select(h.db.authorizationCommits).get()).single;
      expect(
        AuthorizationRecoveryState.decode(journal.previousNativeBindingJson)
            .committed,
        true,
      );
      await h.db.customStatement('DROP TRIGGER retain_receipt');
      final restarted = AuthorizationPersistence(
        database: h.db,
        secrets: h.secrets,
      );
      await restarted.recover();
      expect(await restarted.generation('opaque'), 0);
      final accepted =
          await h.secrets.readCredential('opaque') as GoogleDesktopCredential;
      expect(accepted.tokenSet.refreshToken, 'candidate-refresh');
      expect(await h.db.select(h.db.authorizationCommits).get(), isEmpty);
    },
  );
  test(
    'uncommitted generation-zero binding recovers the latest raw record',
    () async {
      await h.seed();
      await h.db.delete(h.db.authorizationGenerations).go();
      await h.db.delete(h.db.accountAuthorizations).go();
      final originalRaw = OAuthSecretRecord(
        provider: BusyProvider.google,
        tokenSet: tokens('latest-working-rotation'),
      );
      await h.secrets.saveCredential(
        'busymax.authorization.rollback:opaque',
        originalRaw,
      );
      await h.db
          .into(h.db.authorizationCommits)
          .insert(
            AuthorizationCommitsCompanion.insert(
              accountId: 'opaque',
              generation: 0,
              hadCredential: true,
              previousNativeBindingJson: Value(
                const AuthorizationRecoveryState(committed: false).encode(),
              ),
            ),
          );
      await h.secrets.saveCredential(
        'opaque',
        GoogleDesktopCredential(
          registration: original,
          tokenSet: tokens('provisional-refresh'),
          subject: 'subject',
          generation: 0,
          transitionEligible: true,
        ),
      );
      final restarted = AuthorizationPersistence(
        database: h.db,
        secrets: h.secrets,
      );
      await restarted.recover();
      final recovered =
          await h.secrets.readCredential('opaque') as OAuthSecretRecord;
      expect(recovered, isNot(isA<BoundOAuthSecretRecord>()));
      expect(recovered.tokenSet.refreshToken, 'latest-working-rotation');
      expect(await h.db.select(h.db.authorizationCommits).get(), isEmpty);
      expect(await restarted.generation('opaque'), 0);
    },
  );
  for (final shared in [true, false]) {
    test('cancelled preparation lets durable recovery finish shared=$shared', () async {
      await h.seed();
      if (!shared) await h.makeGoogleUserOwned();
      final originalRecord = (await h.secrets.readCredential('opaque'))!;
      await h.secrets.saveCredential(
        'busymax.authorization.rollback:opaque',
        originalRecord,
      );
      await h.db
          .into(h.db.authorizationCommits)
          .insert(
            AuthorizationCommitsCompanion.insert(
              accountId: 'opaque',
              generation: await h.persistence.generation('opaque'),
              hadCredential: true,
              previousNativeBindingJson: Value(
                const AuthorizationRecoveryState(committed: false).encode(),
              ),
            ),
          );
      final entered = Completer<void>();
      final release = Completer<void>();
      h.secrets.beforeSave = (id, _) async {
        if (id == 'opaque') {
          entered.complete();
          await release.future;
        }
      };
      final cancellation = AuthorizationCancellation();
      final connection = h.repository.signIn(
        request: AuthorizationRequest.reconnect('opaque')
            .withCancellation(cancellation),
      );
      final rejected = expectLater(
        connection,
        throwsA(
          isA<OAuthException>().having(
            (e) => e.classification,
            'kind',
            OAuthFailureKind.cancelled,
          ),
        ),
      );
      await entered.future;
      cancellation.cancel();
      await rejected;
      expect(h.flow.started.isCompleted, false);
      expect(h.requests, isEmpty);
      h.secrets.beforeSave = null;
      release.complete();
      // Recovery retains its serialized owner even after the UI stops waiting.
      await h.persistence.run('opaque', () async {});
      expect(await h.db.select(h.db.authorizationCommits).get(), isEmpty);
      expect(
        (await h.secrets.readCredential('opaque'))!.toJson(),
        originalRecord.toJson(),
      );
      await h.repository.signIn(
        request: AuthorizationRequest.reconnect('opaque'),
      );
      expect((await h.summary('opaque')).showRetirementNotice, shared);
    });
    test(
      'cancel after coherent commit cannot undo accepted connection shared=$shared',
      () async {
        await h.seed();
        if (!shared) await h.makeGoogleUserOwned();
        final cancellation = AuthorizationCancellation();
        final entered = Completer<void>();
        final release = Completer<void>();
        h.secrets.beforeDelete = (id) async {
          if (id == 'busymax.authorization.rollback:opaque') {
            entered.complete();
            await release.future;
          }
        };
        final before = await h.persistence.generation('opaque');
        final connection = h.repository.signIn(
          request: AuthorizationRequest.replace(
            'opaque',
            h.staging.stage(owned),
          ).withCancellation(cancellation),
        );
        await entered.future;
        expect(cancellation.wasCommitted, true);
        cancellation.cancel();
        expect(cancellation.isCancelled, false);
        h.secrets.beforeDelete = null;
        release.complete();
        await connection;
        expect(await h.persistence.generation('opaque'), before + 1);
        expect((await h.summary('opaque')).showRetirementNotice, false);
        expect(await h.db.select(h.db.authorizationCommits).get(), isEmpty);
      },
    );
  }
  test(
    'unknown recovery receipt version preserves the account and journal',
    () async {
      await h.seed();
      await h.db
          .into(h.db.authorizationCommits)
          .insert(
            AuthorizationCommitsCompanion.insert(
              accountId: 'opaque',
              generation: 2,
              hadCredential: true,
              previousNativeBindingJson: const Value(
                '{"version":999,"committed":true}',
              ),
            ),
          );
      await expectLater(
        h.persistence.recover(),
        throwsA(isA<SecretStoreCorruptException>()),
      );
      expect(
        await h.secrets.readCredential('opaque'),
        isA<GoogleDesktopCredential>(),
      );
      expect((await h.accounts.accountById('opaque'))!.isSignedIn, true);
      expect(await h.db.select(h.db.authorizationCommits).get(), hasLength(1));
    },
  );
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    test(
      '${provider.name} legacy token cooldown is persisted without claiming issuer',
      () async {
        const id = 'unbound-cooldown-account';
        await h.accounts.upsertSignedInAccount(
          id: id,
          provider: provider,
          providerAccountId: id,
          grantedScopes: '',
        );
        await h.db
            .into(h.db.oAuthTransitionAccounts)
            .insert(OAuthTransitionAccountsCompanion.insert(accountId: id));
        await h.secrets.saveCredential(
          id,
          OAuthSecretRecord(provider: provider, tokenSet: tokens()),
        );
        h.mode = 'legacy-throttled';
        Future<BoundOAuthSecretRecord> bind() => provider == BusyProvider.google
            ? h.google.boundCredentialForAccount(id)
            : h.microsoft.boundCredentialForAccount(id);
        for (var i = 0; i < 2; i++) {
          await expectLater(
            bind(),
            throwsA(
              isA<OAuthRefreshException>().having(
                (error) => error.classification,
                'kind',
                OAuthFailureKind.throttled,
              ),
            ),
          );
        }
        expect(h.requests, hasLength(1));
        expect(await h.persistence.generation(id), 0);
        expect(await h.db.select(h.db.accountAuthorizations).get(), isEmpty);
        expect(
          await h.secrets.readCredential(id),
          isNot(isA<BoundOAuthSecretRecord>()),
        );
        final cooldown =
            (await h.db.select(h.db.domainSyncSchedules).get()).single;
        expect(
          DateTime.parse(cooldown.cooldownUntilUtc!)
              .difference(DateTime.now().toUtc()),
          greaterThan(const Duration(minutes: 119)),
        );
      },
    );
  }
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    test(
      '${provider.name} rejected legacy refresh leaves provenance unresolved',
      () async {
        const id = 'unidentified-local-key';
        await h.accounts.upsertSignedInAccount(
          id: id,
          provider: provider,
          providerAccountId: id,
          grantedScopes: '',
        );
        await h.db
            .into(h.db.oAuthTransitionAccounts)
            .insert(OAuthTransitionAccountsCompanion.insert(accountId: id));
        await h.secrets.saveCredential(
          id,
          OAuthSecretRecord(provider: provider, tokenSet: tokens()),
        );
        h.mode = 'legacy-client-rejected';
        await expectLater(
          provider == BusyProvider.google
              ? h.google.boundCredentialForAccount(id)
              : h.microsoft.boundCredentialForAccount(id),
          throwsA(
            isA<OAuthException>().having(
              (error) => error.classification,
              'kind',
              OAuthFailureKind.configuration,
            ),
          ),
        );
        final preserved = await h.secrets.readCredential(id);
        expect(preserved, isA<OAuthSecretRecord>());
        expect(preserved, isNot(isA<BoundOAuthSecretRecord>()));
        expect((await h.accounts.accountById(id))!.isSignedIn, true);
        expect(await h.persistence.generation(id), 0);
        expect(await h.db.select(h.db.accountAuthorizations).get(), isEmpty);
        expect(h.requests, hasLength(1));
        expect(
          Uri.splitQueryString(h.requests.single.body)['client_id'],
          provider == BusyProvider.google
              ? config.googleOAuthClientId
              : config.microsoftOAuthClientId,
        );
      },
    );
  }
  test('legacy token-derived Google ID survives binding and blocks duplicate onboarding', () async {
    const id = 'legacy-token-derived-local-key';
    await h.accounts.upsertSignedInAccount(
      id: id,
      provider: BusyProvider.google,
      providerAccountId: id,
      grantedScopes: googleBusyMaxOAuthScope,
      tasksEnabled: false,
    );
    await h.db
        .into(h.db.oAuthTransitionAccounts)
        .insert(OAuthTransitionAccountsCompanion.insert(accountId: id));
    await h.secrets.saveCredential(
      id,
      OAuthSecretRecord(provider: BusyProvider.google, tokenSet: tokens()),
    );
    final bound = await h.google.boundCredentialForAccount(id);
    expect(bound.subject, 'subject');
    expect(bound.registration.origin, RegistrationOrigin.retiringShared);
    final account = (await h.accounts.accountById(id))!;
    expect(account.id, id);
    expect(account.providerAccountId, 'subject');
    expect(account.tasksEnabled, false);
    await expectLater(
      h.repository.signIn(
        request: AuthorizationRequest.newConnection(h.staging.stage(owned)),
      ),
      throwsA(
        isA<OAuthException>().having(
          (error) => error.code,
          'code',
          'OAuthAccountAlreadyConnected',
        ),
      ),
    );
    expect((await h.accounts.listVisibleAccounts()).map((a) => a.id), [id]);
    expect(
      (await h.secrets.readCredential(
        id,
      ) as GoogleDesktopCredential).registration.clientId,
      original.clientId,
    );
  });
  test(
    'new setup stages credentials until identity and repository commit',
    () async {
      final candidate = await h.google.connectGoogle(
        AuthorizationRequest.newConnection(h.staging.stage(owned)),
      );
      expect(await h.secrets.readCredential(candidate.accountId), isNull);
      await candidate.commit!(
        () => h.accounts.upsertSignedInAccount(
          id: candidate.accountId,
          provider: BusyProvider.google,
          providerAccountId: 'subject',
          grantedScopes: googleBusyMaxOAuthScope,
        ),
      );
      final saved = await h.secrets.readCredential(
        'google:subject',
      ) as GoogleDesktopCredential;
      expect(saved.registration.clientId, owned.clientId);
      expect(saved.transitionEligible, false);
      expect(
        Uri.splitQueryString(h.requests.first.body)['client_id'],
        owned.clientId,
      );
    },
  );
  test('targeted migration preserves opaque ID, data and enabled domains across restart', () async {
    await h.seed();
    await h.repository.signIn(
      request: AuthorizationRequest.replace('opaque', h.staging.stage(owned)),
    );
    final account = await h.accounts.accountById('opaque');
    expect(account!.providerAccountId, 'subject');
    expect(account.tasksEnabled, false);
    final saved =
        await h.secrets.readCredential('opaque') as GoogleDesktopCredential;
    expect(saved.registration.clientId, owned.clientId);
    expect(saved.transitionEligible, false);
    expect(await h.accounts.accountById('google:subject'), isNull);
    final summary = await h.db.select(h.db.accountAuthorizations).getSingle();
    expect(
      decodeRegistrationSummary(summary.summaryJson)!.showRetirementNotice,
      false,
    );
    expect(
      SecretRecord.fromJson(saved.toJson()),
      isA<GoogleDesktopCredential>(),
    );
  });
  for (final failure in [
    'wrong-account',
    'missing-scope',
    'offline-missing',
    'cancel',
  ]) {
    test('$failure preserves working credentials and warning', () async {
      await h.seed();
      h.mode = failure;
      await expectLater(
        h.repository.signIn(
          request: AuthorizationRequest.replace(
            'opaque',
            h.staging.stage(owned),
          ),
        ),
        throwsA(isA<OAuthException>()),
      );
      final saved =
          await h.secrets.readCredential('opaque') as GoogleDesktopCredential;
      expect(saved.tokenSet.refreshToken, 'working-refresh');
      expect(saved.registration.clientId, original.clientId);
      expect((await h.accounts.accountById('opaque'))!.isSignedIn, true);
      expect(
        saved.registration
            .summary(transitionEligible: saved.transitionEligible)
            .showRetirementNotice,
        true,
      );
      expect(h.requests.any((r) => r.url.path.contains('revoke')), false);
    });
  }
  test(
    'normal refresh during consent preserves latest same-client rotated token',
    () async {
      await h.seed();
      h.mode = 'offline-missing';
      h.flow.barrier = Completer<void>();
      final pending = h.repository.signIn(
        request: const AuthorizationRequest.reconnect('opaque'),
      );
      await h.flow.started.future;
      await h.persistence.writeRefresh(
        'opaque',
        1,
        (await h.secrets.readCredential('opaque') as GoogleDesktopCredential)
            .withTokens(tokens('rotated-latest')),
      );
      h.flow.barrier!.complete();
      await pending;
      expect(
        (await h.secrets.readCredential(
          'opaque',
        ) as GoogleDesktopCredential).tokenSet.refreshToken,
        'rotated-latest',
      );
    },
  );
  test(
    'database failure after secure write restores latest accepted refresh',
    () async {
      await h.seed();
      final candidate = await h.google.connectGoogle(
        AuthorizationRequest.replace('opaque', h.staging.stage(owned)),
      );
      await h.persistence.writeRefresh(
        'opaque',
        1,
        (await h.secrets.readCredential('opaque') as GoogleDesktopCredential)
            .withTokens(tokens('rotated-latest')),
      );
      await expectLater(
        candidate.commit!(() async {
          throw StateError('injected DB failure');
        }),
        throwsStateError,
      );
      expect(
        (await h.secrets.readCredential(
          'opaque',
        ) as GoogleDesktopCredential).tokenSet.refreshToken,
        'rotated-latest',
      );
      expect(await h.persistence.generation('opaque'), 1);
      expect(await h.db.select(h.db.authorizationCommits).get(), isEmpty);
    },
  );
  test(
    'secure storage failure rolls back without removing working account',
    () async {
      await h.seed();
      h.secrets.failActiveOnce = true;
      await expectLater(
        h.repository.signIn(
          request: AuthorizationRequest.replace(
            'opaque',
            h.staging.stage(owned),
          ),
        ),
        throwsA(isA<SecretStoreException>()),
      );
      expect(
        (await h.secrets.readCredential(
          'opaque',
        ) as GoogleDesktopCredential).registration.clientId,
        original.clientId,
      );
      await h.persistence.recover();
      expect(await h.persistence.generation('opaque'), 1);
    },
  );
  test(
    'restart between secure and database writes recovers idempotently',
    () async {
      await h.seed();
      final old = await h.secrets.readCredential('opaque');
      await h.secrets.saveCredential(
        'busymax.authorization.rollback:opaque',
        old!,
      );
      await h.db
          .into(h.db.authorizationCommits)
          .insert(
            AuthorizationCommitsCompanion.insert(
              accountId: 'opaque',
              generation: 2,
              hadCredential: true,
              previousNativeBindingJson: Value(
                const AuthorizationRecoveryState(committed: false).encode(),
              ),
            ),
          );
      await h.secrets.saveCredential(
        'opaque',
        GoogleDesktopCredential(
          registration: owned,
          tokenSet: tokens(),
          subject: 'subject',
          generation: 2,
          transitionEligible: false,
        ),
      );
      final restarted = AuthorizationPersistence(
        database: h.db,
        secrets: h.secrets,
      );
      await restarted.recover();
      await restarted.recover();
      expect(
        (await h.secrets.readCredential(
          'opaque',
        ) as GoogleDesktopCredential).registration.clientId,
        original.clientId,
      );
    },
  );
  test(
    'removal invalidates outstanding consent without resurrection',
    () async {
      await h.seed();
      h.flow.barrier = Completer<void>();
      final pending = h.repository.signIn(
        request: AuthorizationRequest.replace('opaque', h.staging.stage(owned)),
      );
      await h.flow.started.future;
      await h.repository.removeAccount(accountId: 'opaque');
      h.flow.barrier!.complete();
      await expectLater(pending, throwsA(isA<OAuthException>()));
      expect(await h.secrets.readCredential('opaque'), isNull);
      expect(await h.accounts.accountById('opaque'), isNull);
    },
  );
  test('new consent resolving to existing identity never replaces its registration', () async {
    await h.seed();
    await expectLater(
      h.repository.signIn(
        request: AuthorizationRequest.newConnection(h.staging.stage(owned)),
      ),
      throwsA(
        isA<OAuthException>().having(
          (e) => e.code,
          'code',
          'OAuthAccountAlreadyConnected',
        ),
      ),
    );
    expect(
      (await h.secrets.readCredential(
        'opaque',
      ) as GoogleDesktopCredential).registration.clientId,
      original.clientId,
    );
  });
  test('credential readers cannot select a provisional secure write', () async {
    await h.seed();
    final candidate = await h.google.connectGoogle(
      AuthorizationRequest.replace('opaque', h.staging.stage(owned)),
    );
    final written = Completer<void>();
    final release = Completer<void>();
    final committed = candidate.commit!(() async {
      written.complete();
      await release.future;
    });
    await written.future;
    var completed = false;
    final selected = h.persistence.readCurrentCredential('opaque').then((
      record,
    ) {
      completed = true;
      return record;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, false);
    release.complete();
    await committed;
    expect(
      (await selected as GoogleDesktopCredential).registration.clientId,
      owned.clientId,
    );
  });
  test('routine save helper retains versioned binding', () async {
    await h.seed();
    await h.secrets.saveOAuthTokenSet(
      'opaque',
      BusyProvider.google,
      tokens('rotated'),
    );
    final saved =
        await h.secrets.readCredential('opaque') as GoogleDesktopCredential;
    expect(saved.generation, 1);
    expect(saved.subject, 'subject');
    expect(saved.registration.clientId, original.clientId);
  });
  test(
    'stale authorization failure cannot disconnect a migrated account',
    () async {
      await h.seed();
      await h.repository.signIn(
        request: AuthorizationRequest.replace('opaque', h.staging.stage(owned)),
      );
      await h.repository.markReconnectRequired(
        'opaque',
        authorizationGeneration: 1,
      );
      expect((await h.accounts.accountById('opaque'))!.isSignedIn, true);
      expect(
        (await h.secrets.readCredential(
          'opaque',
        ) as GoogleDesktopCredential).registration.clientId,
        owned.clientId,
      );
    },
  );
  test(
    'failed account deletion preserves authorization and its generation',
    () async {
      await h.seed();
      await h.db.customStatement(
        "CREATE TRIGGER reject_removal BEFORE DELETE ON accounts BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(
        h.repository.removeAccount(accountId: 'opaque'),
        throwsA(isA<Exception>()),
      );
      expect(await h.persistence.generation('opaque'), 1);
      expect(
        (await h.secrets.readCredential(
          'opaque',
        ) as GoogleDesktopCredential).tokenSet.refreshToken,
        'working-refresh',
      );
      expect((await h.accounts.accountById('opaque'))!.isSignedIn, true);
    },
  );
  test(
    'Microsoft refresh and optional consent use selected public client',
    () async {
      final handle = h.staging.stageMicrosoft(
        clientId: msOwned,
        audience: MicrosoftAudience.personalAndOrganizations,
      );
      await h.repository.signInWithMicrosoft(
        request: AuthorizationRequest.newConnection(handle),
      );
      await h.microsoft.refreshTokenForAccount('microsoft:ms-user');
      await h.microsoft.authorizeCategoryAccess('microsoft:ms-user');
      expect(h.flow.clients, [msOwned, msOwned]);
      expect(h.flow.lastScope, contains(microsoftCategoryScope));
      await h.microsoft.authorizeSharedCalendarAccess('microsoft:ms-user');
      expect(h.flow.clients, [msOwned, msOwned, msOwned]);
      expect(h.flow.lastScope, contains(microsoftSharedCalendarScope));
      final posted = h.requests.where((r) => r.method == 'POST');
      expect(
        posted.every(
          (r) => Uri.splitQueryString(r.body)['client_id'] == msOwned,
        ),
        true,
      );
      expect(posted.any((r) => r.body.contains('client_secret')), false);
      final saved = await h.secrets.readCredential(
        'microsoft:ms-user',
      ) as MicrosoftDesktopCredential;
      expect(saved.registration.clientId, msOwned);
      expect(saved.tenantId, tenant);
    },
  );
  test(
    'Microsoft replacement retains preferences changed during secure write',
    () async {
      const id = 'microsoft:ms-user';
      await h.repository.signInWithMicrosoft(
        request: AuthorizationRequest.newConnection(
          h.staging.stageMicrosoft(
            clientId: msOwned,
            audience: MicrosoftAudience.personalAndOrganizations,
          ),
        ),
      );
      h.secrets.beforeSave = (key, record) async {
        if (key == id &&
            record is MicrosoftDesktopCredential &&
            record.generation == 2) {
          await (h.db.update(
            h.db.accounts,
          )..where((row) => row.id.equals(id))).write(
            const AccountsCompanion(
              tasksEnabled: Value(false),
              calendarsEnabled: Value(false),
            ),
          );
        }
      };
      await h.repository.signInWithMicrosoft(
        request: AuthorizationRequest.replace(
          id,
          h.staging.stageMicrosoft(
            clientId: '44444444-4444-4444-4444-444444444444',
            audience: MicrosoftAudience.personalAndOrganizations,
          ),
        ),
      );
      final account = (await h.accounts.accountById(id))!;
      expect(account.tasksEnabled, false);
      expect(account.calendarsEnabled, false);
      expect(await h.persistence.generation(id), 2);
      expect(
        (await h.secrets.readCredential(
          id,
        ) as MicrosoftDesktopCredential).registration.clientId,
        '44444444-4444-4444-4444-444444444444',
      );
    },
  );
  test('known shared imports cannot disguise continued use', () async {
    final parsed = parseGoogleDesktopConfiguration(
      utf8.encode(
        jsonEncode({
          'installed': {
            'client_id': original.clientId,
            'project_id': 'pretend-owned-project',
          },
        }),
      ),
      config,
    );
    expect(parsed.origin, RegistrationOrigin.retiringShared);
    await expectLater(
      h.google.connectGoogle(
        AuthorizationRequest.newConnection(h.staging.stage(parsed)),
      ),
      throwsA(isA<OAuthException>()),
    );
  });
  test(
    'import ignores supplied destinations, snapshots file, and consumes staging once',
    () async {
      final dir = await Directory.systemTemp.createTemp('busymax-import-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/client.json');
      await file.writeAsString(
        jsonEncode({
          'installed': {
            'client_id': owned.clientId,
            'client_secret': 'fixture-secret',
            'project_id': owned.projectId,
            'token_uri': 'https://evil.example/token',
            'auth_uri': 'https://evil.example/auth',
            'redirect_uris': ['https://evil.example/'],
          },
        }),
      );
      final importer = RegistrationStaging(
        config,
        fileReader: await buildNativeRegistrationReader(),
      );
      addTearDown(importer.dispose);
      final handle = await importer.importGoogle(XFile(file.path));
      await file.delete();
      expect(handle.summary.clientId, owned.clientId);
      expect(handle.summary.toString(), isNot(contains('fixture-secret')));
      expect(importer.consume(handle), isA<GoogleDesktopRegistration>());
      expect(() => importer.consume(handle), throwsA(isA<OAuthException>()));
    },
    // Includes a cold CMake/MSVC build on Windows CI.
    timeout: const Timeout(Duration(minutes: 2)),
  );
  for (final data in [
    {'web': {}},
    {'type': 'service_account'},
    {
      'installed': {'client_id': 42, 'project_id': 'valid-project'},
    },
    {
      'installed': {
        'client_id': owned.clientId,
        'project_id': 'valid-project',
        'client_secret': false,
      },
    },
  ]) {
    test(
      'reject malformed or wrong-client JSON $data',
      () => expect(
        () => parseGoogleDesktopConfiguration(
          utf8.encode(jsonEncode(data)),
          config,
        ),
        throwsA(isA<OAuthException>()),
      ),
    );
  }
}

class Harness {
  Harness({this.buildConfig = config}) {
    staging = RegistrationStaging(buildConfig);
    persistence = AuthorizationPersistence(database: db, secrets: secrets);
    client = MockClient((request) async {
      requests.add(request);
      final injected = await beforeRequest?.call(request);
      if (injected != null) return injected;
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode(
            request.url.host == 'graph.microsoft.com'
                ? {'id': 'ms-user', 'displayName': 'Fixture'}
                : {
                    'sub': mode == 'wrong-account' ? 'other' : 'subject',
                    'email': 'fixture@example.invalid',
                  },
          ),
          200,
        );
      }
      final params = Uri.splitQueryString(request.body);
      if (mode == 'legacy-client-rejected') {
        return http.Response(jsonEncode({'error': 'invalid_grant'}), 400);
      }
      if (mode == 'legacy-throttled') {
        return http.Response(
          jsonEncode({'error': 'invalid_grant'}),
          429,
          headers: {'retry-after': '7200'},
        );
      }
      return http.Response(
        jsonEncode({
          'access_token': 'candidate-access',
          'expires_in': 3600,
          if (mode != 'offline-missing') 'refresh_token': 'candidate-refresh',
          if (request.url.host == 'login.microsoftonline.com')
            'id_token': fixtureIdToken(params['client_id']!),
          'scope': mode == 'missing-scope'
              ? googleTasksReadWriteScope
              : request.url.host == 'login.microsoftonline.com'
              ? (params['grant_type'] == 'refresh_token'
                    ? microsoftTodoOAuthScopes
                    : flow.lastScope)
              : googleBusyMaxOAuthScope,
        }),
        200,
      );
    });
    google = OAuthService(
      config: buildConfig,
      httpClient: client,
      tokenStore: secrets,
      loopbackFlow: flow,
      registrations: staging,
      persistence: persistence,
    );
    microsoft = MicrosoftOAuthService(
      config: buildConfig,
      httpClient: client,
      tokenStore: secrets,
      loopbackFlow: flow,
      registrations: staging,
      persistence: persistence,
    );
    repository = AuthRepository(
      oAuth: google,
      microsoftOAuth: microsoft,
      database: db,
      authorizationPersistence: persistence,
    );
    flow.cancelled = () => mode == 'cancel';
  }
  final db = AppDatabase.memoryForTests();
  final secrets = FailureStore();
  final BuildConfig buildConfig;
  late final http.Client client;
  late final RegistrationStaging staging;
  final flow = ControlledFlow();
  final requests = <http.Request>[];
  String mode = 'success';
  Future<http.Response?> Function(http.Request)? beforeRequest;
  late final AuthorizationPersistence persistence;
  late final OAuthService google;
  late final MicrosoftOAuthService microsoft;
  late final AuthRepository repository;
  AccountsRepository get accounts => AccountsRepository(database: db);
  Future<RegistrationSummary> summary(String id) async {
    final row = await (db.select(
      db.accountAuthorizations,
    )..where((r) => r.accountId.equals(id))).getSingle();
    return decodeRegistrationSummary(row.summaryJson)!;
  }

  Future<void> makeGoogleUserOwned() => persistence.commit(
    accountId: 'opaque',
    expectedGeneration: 1,
    candidate: GoogleDesktopCredential(
      registration: owned,
      tokenSet: tokens(),
      subject: 'subject',
      generation: 2,
      transitionEligible: false,
    ),
    requireExisting: true,
    persistAccount: () async {},
  );
  Future<void> seedMicrosoft({
    required bool shared,
    MicrosoftPublicRegistration? registration,
  }) async {
    final id = 'microsoft:ms-user';
    await accounts.upsertSignedInAccount(
      id: id,
      provider: BusyProvider.microsoft,
      providerAccountId: 'ms-user',
      tenantId: tenant,
      grantedScopes: microsoftTodoOAuthScopes,
    );
    if (shared) {
      await db
          .into(db.oAuthTransitionAccounts)
          .insert(OAuthTransitionAccountsCompanion.insert(accountId: id));
    }
    await persistence.commit(
      accountId: id,
      expectedGeneration: 0,
      candidate: MicrosoftDesktopCredential(
        registration:
            registration ??
            MicrosoftPublicRegistration(
              clientId: shared ? config.microsoftOAuthClientId : msOwned,
              audience: MicrosoftAudience.personalAndOrganizations,
              origin: shared
                  ? RegistrationOrigin.retiringShared
                  : RegistrationOrigin.userProvided,
            ),
        subject: 'ms-user',
        tenantId: tenant,
        generation: 1,
        transitionEligible: shared,
        tokenSet: tokens().copyWith(
          scopes: microsoftTodoOAuthScopes.split(' ').toSet(),
        ),
      ),
      requireExisting: true,
      persistAccount: () async {},
    );
  }

  Future<void> seed() async {
    await accounts.upsertSignedInAccount(
      id: 'opaque',
      provider: BusyProvider.google,
      providerAccountId: 'subject',
      grantedScopes: googleBusyMaxOAuthScope,
      tasksEnabled: false,
    );
    await db
        .into(db.oAuthTransitionAccounts)
        .insert(OAuthTransitionAccountsCompanion.insert(accountId: 'opaque'));
    await db
        .into(db.authorizationGenerations)
        .insert(
          AuthorizationGenerationsCompanion.insert(
            accountId: 'opaque',
            generation: 1,
          ),
        );
    final record = GoogleDesktopCredential(
      registration: original,
      tokenSet: tokens(),
      subject: 'subject',
      generation: 1,
      transitionEligible: true,
    );
    await secrets.saveCredential('opaque', record);
    await db
        .into(db.accountAuthorizations)
        .insert(
          AccountAuthorizationsCompanion.insert(
            accountId: 'opaque',
            generation: 1,
            summaryJson: jsonEncode(
              summaryJson(
                record.registration.summary(transitionEligible: true),
              ),
            ),
          ),
        );
  }
}

class FailureStore extends InMemorySecretStore {
  bool failActiveOnce = false;
  Future<void> Function(String id)? beforeDelete;
  @override
  Future<void> deleteCredential(String id) async {
    await beforeDelete?.call(id);
    await super.deleteCredential(id);
  }

  Future<void> Function(String id, SecretRecord record)? beforeSave;
  @override
  Future<void> saveCredential(String id, SecretRecord record) async {
    await beforeSave?.call(id, record);
    await super.saveCredential(id, record);
  }

  @override
  Future<void> setActiveAccountId(String id) async {
    if (failActiveOnce) {
      failActiveOnce = false;
      throw const SecretStoreException(
        'injected',
        'Secure storage unavailable.',
      );
    }
    await super.setActiveAccountId(id);
  }
}

class ControlledFlow extends OAuthLoopbackFlow {
  ControlledFlow() : super(authorizationLauncher: (_) async => false);
  Completer<void>? barrier;
  final started = Completer<void>();
  bool Function()? cancelled;
  String lastScope = '';
  final clients = <String>[];
  @override
  Future<OAuthLoopbackResult> start({
    required Uri authorizationEndpoint,
    required String clientId,
    required String scope,
    String redirectHost = '127.0.0.1',
    String signInCancelledMessage = '',
    String callbackNotReceivedMessage = '',
    String serverStartFailureMessage = '',
    String browserLaunchFailureMessage = '',
    Map<String, String> extraAuthorizationParameters = const {},
    String? loginHint,
    AuthorizationAttempt? attempt,
  }) async {
    clients.add(clientId);
    lastScope = scope;
    if (!started.isCompleted) started.complete();
    if (barrier != null) {
      if (attempt == null) {
        await barrier!.future;
      } else {
        await attempt.wait(barrier!.future);
      }
    }
    attempt?.check();
    if (cancelled?.call() == true) {
      throw const OAuthException('OAuthSignInCancelled', 'Cancelled.');
    }
    return OAuthLoopbackResult(
      callback: OAuthCallbackResult(code: 'fixture-code', scope: scope),
      redirectUri: 'http://$redirectHost:4321/',
      codeVerifier: 'fixture-verifier',
    );
  }
}
