import 'dart:convert';

import 'package:busymax/src/android/android_authorization.dart';
import 'package:busymax/src/contacts/busymax_contacts_controller.dart';
import 'package:busymax/src/contacts/busymax_contacts_store.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const tenant = '11111111-1111-1111-1111-111111111111';
const client = '33333333-3333-3333-3333-333333333333';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('busymax.contacts.real-native-broker.test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    for (final scenario in [
      'first-read',
      'broader-only',
      'both',
      'partial',
      'wrong-account',
      'cancel',
      'persistence',
    ]) {
      test(
        '$provider real native broker $scenario commits truthful grants and read-only link atomically',
        () async {
          final db = AppDatabase.memoryForTests();
          final secrets = InMemorySecretStore();
          final accounts = AccountsRepository(database: db);
          final contactStore = BusyMaxContactsStore(db);
          final id = provider.name;
          final base = provider == BusyProvider.google
              ? [googleTasksReadWriteScope, googleCalendarReadWriteScope]
              : ['User.Read', 'Tasks.ReadWrite', 'Calendars.ReadWrite'];
          final read = provider == BusyProvider.google
              ? googleContactsReadScope
              : 'Contacts.Read';
          final write = provider == BusyProvider.google
              ? googleContactsWriteScope
              : 'Contacts.ReadWrite';
          final broad = scenario == 'broader-only' || scenario == 'both';
          final returned = [
            ...base,
            if (provider == BusyProvider.microsoft) ...[
              'Calendars.ReadWrite.Shared',
              'MailboxSettings.Read',
            ],
            if (scenario != 'partial' && scenario != 'broader-only') read,
            if (broad) write,
          ];
          final bindings = <String, Object?>{};
          final calls = <MethodCall>[];
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
                  'signatureHash': 'synthetic',
                  'redirectUri': 'msauth://io.busystack.busymax/synthetic',
                  'retiringClientId': '22222222-2222-2222-2222-222222222222',
                };
              case 'readAuthorizationBinding':
                return bindings.isEmpty ? null : bindings;
              case 'bindAuthorization':
                bindings.addAll(Map<String, Object?>.from(args));
                return null;
              case 'clearAuthorizationBinding':
                bindings.clear();
                return null;
              case 'cancelInteractiveAuthorization':
                return null;
              case 'authorizeGoogleInteractive':
              case 'authorizeMicrosoftInteractive':
              case 'authorizeGoogleSilent':
              case 'authorizeMicrosoftSilent':
                final requested = (args['scopes'] as List).cast<String>();
                expect(requested, containsAll(base));
                expect(requested, contains(read));
                expect(requested, isNot(contains(write)));
                if (scenario == 'cancel') {
                  throw PlatformException(code: 'android/auth-cancelled');
                }
                return {
                  'nativeAccountId': 'native',
                  'accessToken': scenario == 'wrong-account'
                      ? 'wrong'
                      : 'native-token',
                  'authority': 'https://login.microsoftonline.com/$tenant',
                  'scopes': returned,
                };
              default:
                throw StateError('Unexpected ${call.method}');
            }
          });
          final transport = MockClient(
            (r) async => http.Response(
              jsonEncode(
                r.url.host == 'people.googleapis.com'
                    ? {
                        'connections': [],
                        'contactGroups': [],
                        'nextSyncToken': 'sync',
                      }
                    : r.url.path.contains('/contacts') ||
                          r.url.path.contains('contactFolders')
                    ? {'value': []}
                    : provider == BusyProvider.google
                    ? {
                        'sub': r.headers['authorization'] == 'Bearer wrong'
                            ? 'wrong'
                            : 'owner',
                      }
                    : {
                        'id': r.headers['authorization'] == 'Bearer wrong'
                            ? 'wrong'
                            : 'owner',
                      },
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          );
          final broker = AndroidAuthorizationBroker(
            platform: BusyMaxAndroidPlatform(methodChannel: channel),
            config: BuildConfig.forAndroid(),
            secretStore: secrets,
            database: db,
            httpClient: transport,
          );
          final controller = BusyMaxContactsController(
            store: contactStore,
            accounts: accounts,
            authorization: broker,
            httpClient: transport,
            readDavSecret: (_) async => null,
            writeDavSecret: (_, _) async {},
            deleteDavSecret: (_) async {},
            readLinkedDavCredential: (_) async => null,
            launchBrowser: (_) async => false,
            readAuthorizationGeneration: broker.persistence!.generation,
          );
          addTearDown(() async {
            await controller.close();
            await db.close();
            messenger.setMockMethodCallHandler(channel, null);
          });
          final initial = [...base, if (broad) ...returned.skip(base.length)];
          await accounts.upsertSignedInAccount(
            id: id,
            provider: provider,
            providerAccountId: 'owner',
            tenantId: provider == BusyProvider.microsoft ? tenant : null,
            grantedScopes: initial.join(' '),
          );
          final NativeOAuthCredential credential =
              provider == BusyProvider.google
              ? const GoogleAndroidCredential(
                  nativeAccountId: 'native',
                  subject: 'owner',
                  generation: 1,
                )
              : MicrosoftAndroidCredential(
                  nativeAccountId: 'native',
                  subject: 'owner',
                  generation: 1,
                  tenantId: tenant,
                  authority: 'https://login.microsoftonline.com/$tenant',
                  transitionEligible: false,
                  registration: MicrosoftPublicRegistration(
                    clientId: client,
                    audience: MicrosoftAudience.personalAndOrganizations,
                    platform: AuthenticationPlatform.android,
                  ),
                );
          await broker.persistence!.commit(
            accountId: id,
            expectedGeneration: 0,
            candidate: credential,
            requireExisting: true,
            persistAccount: () async {},
          );
          if (scenario == 'persistence') {
            await db.customStatement(
              "CREATE TRIGGER reject_contact_link BEFORE INSERT ON bm_contact_account_links BEGIN SELECT RAISE(ABORT,'fixture persistence'); END",
            );
          }
          final failed = [
            'partial',
            'wrong-account',
            'cancel',
            'persistence',
          ].contains(scenario);
          if (failed) {
            await expectLater(
              controller.enableLinkedContacts(id),
              throwsA(isA<Object>()),
            );
            expect(
              (await accounts.accountById(id))!.grantedScopes,
              initial.join(' '),
            );
            expect(
              await contactStore.read((tx) => tx.account('contacts:$id')),
              isNull,
            );
            expect(
              (await broker.persistence!.readCurrentCredential(
                id,
              ) as NativeOAuthCredential).generation,
              1,
            );
          } else {
            await controller.enableLinkedContacts(id);
            await controller.synchronizeAccount('contacts:$id');
            final contact = (await contactStore.read(
              (tx) => tx.account('contacts:$id'),
            ))!;
            expect(
              contact.grantedScopes,
              anyOf(contains(read), contains(write)),
            );
            expect(contact.grantedScopes.contains(write), broad);
            final parent = (await accounts.accountById(id))!.grantedScopes
                .split(' ')
                .toSet();
            expect(parent, {
              for (final scope in returned)
                provider == BusyProvider.microsoft
                    ? 'https://graph.microsoft.com/$scope'
                    : scope,
            });
            final interactives = calls.where(
              (c) => c.method.endsWith('Interactive'),
            );
            expect(interactives.length, broad ? 0 : 1);
            expect(
              (await broker.persistence!.readCurrentCredential(
                id,
              ) as NativeOAuthCredential).generation,
              broad ? 1 : 2,
            );
          }
          expect(
            calls.where((c) => c.method == 'removeAuthorization'),
            isEmpty,
          );
        },
      );
    }
  }
}
