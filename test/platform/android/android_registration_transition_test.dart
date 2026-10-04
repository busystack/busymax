import 'package:busymax/src/core/auth/authorization_attempt.dart';
import 'dart:convert';
import 'dart:async';
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/android/android_authorization.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/auth/registration_staging.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart' hide AuthorizationCommit;
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/auth/data/auth_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const clientA = '22222222-2222-2222-2222-222222222222';
const clientB = '33333333-3333-3333-3333-333333333333';
const tenant = '11111111-1111-1111-1111-111111111111';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('busymax.registration.test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppDatabase db;
  late InMemorySecretStore secrets;
  late RegistrationStaging staging;
  late AndroidAuthorizationBroker broker;
  late AuthRepository repository;
  late List<MethodCall> calls;
  late Map<String, Map<String, Object?>> bindings;
  var wrongAccount = false;
  Completer<void>? interactiveStarted;
  Completer<void>? interactiveRelease;
  Completer<void>? identityStarted;
  Completer<void>? identityRelease;
  Completer<void>? silentStarted;
  Completer<void>? silentRelease;
  setUp(() {
    db = AppDatabase.memoryForTests();
    secrets = InMemorySecretStore();
    staging = RegistrationStaging(BuildConfig.forAndroid());
    calls = [];
    bindings = {};
    wrongAccount = false;
    interactiveStarted = null;
    interactiveRelease = null;
    identityStarted = null;
    identityRelease = null;
    silentStarted = null;
    silentRelease = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = (call.arguments as Map?) ?? {};
      switch (call.method) {
        case 'acquireAccountGate':
          return 'lease';
        case 'releaseAccountGate':
          return null;
        case 'microsoftRegistrationIdentity':
          return {
            'packageName': 'io.busystack.busymax',
            'signatureHash': 'synthetic-signature',
            'redirectUri': 'msauth://io.busystack.busymax/synthetic-signature',
            'retiringClientId': clientA,
          };
        case 'bindAuthorization':
          bindings[args['accountId'] as String] = Map<String, Object?>.from(
            args,
          );
          return null;
        case 'readAuthorizationBinding':
          return bindings[args['accountId']];
        case 'clearAuthorizationBinding':
          bindings.remove(args['accountId']);
          return null;
        case 'cancelInteractiveAuthorization':
          return null;
        case 'authorizeMicrosoftInteractive':
          final wait = interactiveRelease;
          if (interactiveStarted != null && !interactiveStarted!.isCompleted) {
            interactiveStarted!.complete();
          }
          await wait?.future;
          return {
            'nativeAccountId': wrongAccount
                ? 'wrong'
                : 'native-${args['clientId']}',
            'accessToken': wrongAccount ? 'wrong' : 'token-${args['clientId']}',
            'authority': 'https://login.microsoftonline.com/$tenant',
            'scopes': args['scopes'],
          };
        case 'authorizeMicrosoftSilent':
          final selected = Map<String, Object?>.from(
            bindings[args['accountId']]!,
          );
          if (args['clientId'] != null) {
            selected['clientId'] = args['clientId'];
            selected['nativeAccountId'] = args['nativeAccountId'];
            selected['authority'] = args['authority'];
          }
          silentStarted?.complete();
          if (silentRelease != null) await silentRelease!.future;
          return {
            'nativeAccountId': selected['nativeAccountId'],
            'accessToken': 'token-${selected['clientId']}',
            'authority': selected['authority'],
            'scopes': args['scopes'],
          };
        default:
          throw StateError('Unexpected channel method ${call.method}');
      }
    });
    broker = AndroidAuthorizationBroker(
      platform: BusyMaxAndroidPlatform(methodChannel: channel),
      config: BuildConfig.forAndroid(),
      secretStore: secrets,
      database: db,
      registrations: staging,
      httpClient: MockClient((r) async {
        if (identityStarted != null && !identityStarted!.isCompleted) {
          identityStarted!.complete();
        }
        await identityRelease?.future;
        return http.Response(
          jsonEncode({
            'id': r.headers['authorization'] == 'Bearer wrong'
                ? 'different'
                : 'subject',
            'displayName': 'Fixture',
          }),
          200,
        );
      }),
    );
    repository = AuthRepository(
      oAuth: broker,
      microsoftOAuth: broker,
      database: db,
      authorizationPersistence: broker.persistence,
    );
  });
  tearDown(() async {
    staging.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    await db.close();
  });
  RegistrationHandle own() => staging.stageMicrosoft(
    clientId: clientB,
    audience: MicrosoftAudience.personalAndOrganizations,
    platform: AuthenticationPlatform.android,
  );
  Future<void> seedShared() async {
    await AccountsRepository(database: db).upsertSignedInAccount(
      id: 'opaque',
      provider: BusyProvider.microsoft,
      providerAccountId: 'subject',
      tenantId: tenant,
      grantedScopes: 'User.Read Tasks.ReadWrite Calendars.ReadWrite',
    );
    await db
        .into(db.oAuthTransitionAccounts)
        .insert(OAuthTransitionAccountsCompanion.insert(accountId: 'opaque'));
    bindings['opaque'] = {
      'nativeAccountId': 'original-native',
      'clientId': clientA,
      'authorityTenant': 'common',
      'authority': 'https://login.microsoftonline.com/$tenant',
      'originalRegistration': true,
    };
    await broker.nativeCredential('opaque', BusyProvider.microsoft);
  }

  test(
    'Android cancellation captured before recovery prevents later native dispatch and fresh retry succeeds',
    () async {
      final cancellation = AuthorizationCancellation();
      final operation = repository.signInWithMicrosoft(
        request: AuthorizationRequest.newConnection(
          own(),
          cancellation: cancellation,
        ),
      );
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
      cancellation.cancel();
      await rejected;
      expect(
        calls.where((c) => c.method == 'authorizeMicrosoftInteractive'),
        isEmpty,
      );
      expect(await db.select(db.accounts).get(), isEmpty);
      await repository.signInWithMicrosoft(
        request: AuthorizationRequest.newConnection(own()),
      );
      expect(
        calls.where((c) => c.method == 'authorizeMicrosoftInteractive'),
        hasLength(1),
      );
    },
  );
  for (final shared in [false, true]) {
    for (final phase in ['identity', 'native']) {
      test(
        'Android cancelled $phase result cannot replace selected registration shared=$shared',
        () async {
          await seedShared();
          if (!shared) {
            await repository.signInWithMicrosoft(
              request: AuthorizationRequest.replace('opaque', own()),
            );
          }
          final before = (await secrets.readCredential('opaque'))!.toJson();
          final entered = Completer<void>(), release = Completer<void>();
          if (phase == 'native') {
            interactiveStarted = entered;
            interactiveRelease = release;
          } else {
            identityStarted = entered;
            identityRelease = release;
          }
          final cancellation = AuthorizationCancellation();
          final old = repository.signInWithMicrosoft(
            request: AuthorizationRequest.replace(
              'opaque',
              own(),
              cancellation: cancellation,
            ),
          );
          final rejected = expectLater(
            old,
            throwsA(
              isA<OAuthException>().having(
                (e) => e.classification,
                'cancelled',
                OAuthFailureKind.cancelled,
              ),
            ),
          );
          await entered.future;
          cancellation.cancel();
          await rejected;
          final attempt =
              calls
                      .lastWhere(
                        (c) => c.method == 'authorizeMicrosoftInteractive',
                      )
                      .arguments
                  as Map;
          if (phase == 'native') {
            expect(
              calls
                  .lastWhere(
                    (c) => c.method == 'cancelInteractiveAuthorization',
                  )
                  .arguments,
              containsPair(
                'authorizationAttemptId',
                attempt['authorizationAttemptId'],
              ),
            );
          }
          // A new invocation is dispatched while the cancelled native result is
          // still pending; its cancellation identity remains independent.
          interactiveStarted = null;
          interactiveRelease = null;
          identityStarted = null;
          identityRelease = null;
          await repository.signInWithMicrosoft(
            request: AuthorizationRequest.reconnect('opaque'),
          );
          release.complete();
          final after =
              await secrets.readCredential('opaque')
                  as MicrosoftAndroidCredential;
          expect(after.registration.clientId, shared ? clientA : clientB);
          expect(after.summary.showRetirementNotice, shared);
          expect(after.generation, (before['generation'] as int) + 1);
        },
      );
    }
  }
  test(
    'original native binding upgrades idempotently and user-owned migration selects its own MSAL registration',
    () async {
      await seedShared();
      final original =
          await secrets.readCredential('opaque') as MicrosoftAndroidCredential;
      expect(original.summary.showRetirementNotice, true);
      await broker.nativeCredential('opaque', BusyProvider.microsoft);
      await repository.signInWithMicrosoft(
        request: AuthorizationRequest.replace('opaque', own()),
      );
      final migrated =
          await secrets.readCredential('opaque') as MicrosoftAndroidCredential;
      expect(migrated.registration.clientId, clientB);
      expect(migrated.summary.showRetirementNotice, false);
      expect(bindings['opaque']!['clientId'], clientB);
      expect(migrated.toJson().keys, isNot(contains('refreshToken')));
      await broker.authorizationHeader(BusyProvider.microsoft, 'opaque');
      await broker.authorizeCategoryAccess('opaque');
      expect(bindings['opaque']!['clientId'], clientB);
      expect(
        calls
            .where((c) => c.method == 'authorizeMicrosoftInteractive')
            .every((c) => (c.arguments as Map)['clientId'] == clientB),
        true,
      );
      expect(calls.any((c) => c.method == 'removeAuthorization'), false);
      expect(
        await AccountsRepository(database: db).accountById('microsoft:subject'),
        isNull,
      );
    },
  );
  test(
    'late original-client silent result cannot replace migrated token selection',
    () async {
      await seedShared();
      silentStarted = Completer<void>();
      silentRelease = Completer<void>();
      final pending = broker.authorizationHeader(
        BusyProvider.microsoft,
        'opaque',
      );
      final rejected = expectLater(
        pending,
        throwsA(
          isA<OAuthException>().having(
            (error) => error.classification,
            'kind',
            OAuthFailureKind.stale,
          ),
        ),
      );
      await silentStarted!.future;
      final originalCall = calls.lastWhere(
        (c) => c.method == 'authorizeMicrosoftSilent',
      );
      expect((originalCall.arguments as Map)['clientId'], clientA);
      expect(
        (originalCall.arguments as Map)['nativeAccountId'],
        'original-native',
      );
      await repository.signInWithMicrosoft(
        request: AuthorizationRequest.replace('opaque', own()),
      );
      silentRelease!.complete();
      await rejected;
      interactiveStarted = null;
      interactiveRelease = null;
      identityStarted = null;
      identityRelease = null;
      silentStarted = null;
      silentRelease = null;
      expect(
        await broker.authorizationHeader(BusyProvider.microsoft, 'opaque'),
        'Bearer token-$clientB',
      );
      final currentCall = calls.lastWhere(
        (c) => c.method == 'authorizeMicrosoftSilent',
      );
      expect((currentCall.arguments as Map)['clientId'], clientB);
      expect(calls.any((c) => c.method == 'removeAuthorization'), false);
    },
  );
  test(
    'native wrong-account migration preserves the previous binding and warning',
    () async {
      await seedShared();
      wrongAccount = true;
      await expectLater(
        repository.signInWithMicrosoft(
          request: AuthorizationRequest.replace('opaque', own()),
        ),
        throwsA(isA<Exception>()),
      );
      expect(bindings['opaque']!['clientId'], clientA);
      expect(
        (await secrets.readCredential('opaque') as MicrosoftAndroidCredential)
            .summary
            .showRetirementNotice,
        true,
      );
    },
  );
  test(
    'new Android Microsoft setup cannot disguise the original native registration',
    () async {
      final handle = staging.stageMicrosoft(
        clientId: clientA,
        audience: MicrosoftAudience.personalAndOrganizations,
        platform: AuthenticationPlatform.android,
      );
      await expectLater(
        repository.signInWithMicrosoft(
          request: AuthorizationRequest.newConnection(handle),
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        calls.any((c) => c.method == 'authorizeMicrosoftInteractive'),
        false,
      );
      expect(await db.select(db.accounts).get(), isEmpty);
    },
  );
  test(
    'user-owned Android Microsoft setup needs no shared build client or exported native tokens',
    () async {
      await repository.signInWithMicrosoft(
        request: AuthorizationRequest.newConnection(own()),
      );
      final saved =
          await secrets.readCredential('microsoft:subject')
              as MicrosoftAndroidCredential;
      expect(saved.registration.clientId, clientB);
      expect(saved.summary.showRetirementNotice, false);
      expect(saved.toJson().keys, isNot(contains('accessToken')));
      await broker.authorizationHeader(
        BusyProvider.microsoft,
        'microsoft:subject',
      );
      expect(bindings['microsoft:subject']!['clientId'], clientB);
    },
  );
  test(
    'native Google origin never offers a Desktop migration or retirement notice',
    () {
      const saved = GoogleAndroidCredential(
        nativeAccountId: 'native',
        subject: 'subject',
        generation: 1,
      );
      expect(saved.summary.origin, RegistrationOrigin.nativeGoogleAndroid);
      expect(saved.summary.showRetirementNotice, false);
      expect(
        SecretRecord.fromJson(saved.toJson()),
        isA<GoogleAndroidCredential>(),
      );
    },
  );
  test(
    'database failure restores an unresolved native alias after candidate binding',
    () async {
      await seedShared();
      await secrets.deleteCredential('opaque');
      bindings['opaque']!['originalRegistration'] = false;
      final previous = Map<String, Object?>.from(bindings['opaque']!);
      await db.customStatement(
        "CREATE TRIGGER reject_candidate BEFORE UPDATE ON accounts BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(
        repository.signInWithMicrosoft(
          request: AuthorizationRequest.replace('opaque', own()),
        ),
        throwsA(isA<Exception>()),
      );
      expect(
        bindings['opaque']!['nativeAccountId'],
        previous['nativeAccountId'],
      );
      expect(bindings['opaque']!['clientId'], clientA);
      expect(await secrets.readCredential('opaque'), isNull);
      expect(await broker.persistence!.generation('opaque'), 0);
      expect(
        (await AccountsRepository(
          database: db,
        ).accountById('opaque'))!.providerAccountId,
        'subject',
      );
      expect(calls.any((c) => c.method == 'removeAuthorization'), false);
    },
  );
  test(
    'silent acquisition repairs stale alias from secure registration binding',
    () async {
      await seedShared();
      await repository.signInWithMicrosoft(
        request: AuthorizationRequest.replace('opaque', own()),
      );
      bindings['opaque']!['clientId'] = clientA;
      await broker.authorizationHeader(BusyProvider.microsoft, 'opaque');
      expect(bindings['opaque']!['clientId'], clientB);
      final selected =
          calls
                  .lastWhere(
                    (call) => call.method == 'authorizeMicrosoftSilent',
                  )
                  .arguments
              as Map;
      expect(selected['accountId'], 'opaque');
      expect(selected['clientId'], clientB);
      expect(selected['nativeAccountId'], 'native-$clientB');
    },
  );
}
