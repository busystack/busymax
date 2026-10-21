import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';

import 'authorization_transition_test.dart'
    show Harness, owned, msOwned, fixtureIdToken;

void main() {
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    for (final recovery in [false, true]) {
      test(
        '$provider valid contacts grant is reused; forced recovery=$recovery validates the parent',
        () async {
          final h = Harness();
          addTearDown(() async {
            h.staging.dispose();
            await h.db.close();
          });
          final id = provider == BusyProvider.google
              ? 'opaque'
              : 'microsoft:ms-user';
          if (provider == BusyProvider.google) {
            await h.seed();
            await h.makeGoogleUserOwned();
          } else {
            await h.seedMicrosoft(shared: false);
          }
          final before =
              await h.secrets.readCredential(id) as BoundOAuthSecretRecord;
          final scope = provider == BusyProvider.google
              ? googleContactsReadScope
              : 'Contacts.Read';
          await h.secrets.saveCredential(
            id,
            before.withTokens(
              before.tokenSet.copyWith(
                scopes: {...before.tokenSet.scopes, scope},
              ),
            ),
          );
          if (recovery) await h.repository.markReconnectRequired(id);
          h.beforeRequest = (request) async {
            if (request.method != 'POST') return null;
            return http.Response(
              jsonEncode({
                'access_token': 'contacts-recovered',
                'refresh_token': 'contacts-refresh',
                'expires_in': 3600,
                'scope': h.flow.lastScope,
                if (provider == BusyProvider.microsoft)
                  'id_token': fixtureIdToken(
                    Uri.splitQueryString(request.body)['client_id']!,
                  ),
              }),
              200,
            );
          };
          var persisted = 0;
          if (provider == BusyProvider.google) {
            await h.google.authorizeGoogleContacts(
              id,
              forceAuthorization: recovery,
              persistContacts: () async {
                persisted++;
              },
            );
          } else {
            await h.microsoft.authorizeMicrosoftContacts(
              id,
              forceAuthorization: recovery,
              persistContacts: () async {
                persisted++;
              },
            );
          }
          expect(persisted, 1);
          expect(h.flow.clients.length, recovery ? 1 : 0);
          expect((await h.accounts.accountById(id))!.isSignedIn, isTrue);
          final after =
              await h.secrets.readCredential(id) as BoundOAuthSecretRecord;
          expect(after.subject, before.subject);
          expect(after.registration.clientId, before.registration.clientId);
        },
      );
    }
    test(
      '$provider revoked contacts grant is not accepted from stored scopes',
      () async {
        final h = Harness();
        addTearDown(() async {
          h.staging.dispose();
          await h.db.close();
        });
        final id = provider == BusyProvider.google
            ? 'opaque'
            : 'microsoft:ms-user';
        if (provider == BusyProvider.google) {
          await h.seed();
          await h.makeGoogleUserOwned();
        } else {
          await h.seedMicrosoft(shared: false);
        }
        final original =
            await h.secrets.readCredential(id) as BoundOAuthSecretRecord;
        final expired = original.withTokens(
          original.tokenSet.copyWith(
            expiresAtUtc: DateTime.utc(2000),
            scopes: {
              ...original.tokenSet.scopes,
              provider == BusyProvider.google
                  ? googleContactsReadScope
                  : 'Contacts.Read',
            },
          ),
        );
        await h.secrets.saveCredential(id, expired);
        h.mode = 'legacy-client-rejected';
        var persisted = false;
        final operation = provider == BusyProvider.google
            ? h.google.authorizeGoogleContacts(
                id,
                persistContacts: () async {
                  persisted = true;
                },
              )
            : h.microsoft.authorizeMicrosoftContacts(
                id,
                persistContacts: () async {
                  persisted = true;
                },
              );
        await expectLater(operation, throwsA(isA<OAuthException>()));
        expect(persisted, isFalse);
        expect(
          (await h.secrets.readCredential(id))!.toJson(),
          expired.toJson(),
        );
        expect(h.flow.clients, isEmpty);
        // Reconnect performs authorization even when the old record names contacts scopes.
        h.mode = 'cancel';
        final reconnect = provider == BusyProvider.google
            ? h.google.authorizeGoogleContacts(id, forceAuthorization: true)
            : h.microsoft.authorizeMicrosoftContacts(
                id,
                forceAuthorization: true,
              );
        await expectLater(reconnect, throwsA(isA<OAuthException>()));
        expect(h.flow.clients, hasLength(1));
        expect(
          (await h.secrets.readCredential(id))!.toJson(),
          expired.toJson(),
        );
      },
    );
  }
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    for (final action in [
      'first-sign-in',
      'first-contacts',
      'reconnect',
      'replace',
      if (provider == BusyProvider.microsoft) ...[
        'category',
        'shared-calendar',
      ],
    ]) {
      test(
        '$provider $action inspects the actual outbound PKCE authorization URL',
        () async {
          final h = Harness();
          addTearDown(() async {
            h.staging.dispose();
            await h.db.close();
          });
          final id = provider == BusyProvider.google
              ? 'opaque'
              : 'microsoft:ms-user';
          if (action != 'first-sign-in') {
            if (provider == BusyProvider.google) {
              await h.seed();
            } else {
              await h.seedMicrosoft(shared: false);
            }
            if (action != 'first-contacts') {
              final credential =
                  await h.secrets.readCredential(id) as BoundOAuthSecretRecord;
              final scopes = {
                ...credential.tokenSet.scopes,
                provider == BusyProvider.google
                    ? googleContactsWriteScope
                    : 'Contacts.ReadWrite',
                if (provider == BusyProvider.microsoft) ...[
                  if (action != 'shared-calendar') microsoftSharedCalendarScope,
                  if (action != 'category') microsoftCategoryScope,
                ],
              };
              await h.secrets.saveCredential(
                id,
                credential.withTokens(
                  credential.tokenSet.copyWith(scopes: scopes),
                ),
              );
            }
          }
          Uri? captured;
          final flow = OAuthLoopbackFlow(
            authorizationLauncher: (uri) async {
              captured = uri;
              return false; // No provider/account is contacted by this regression.
            },
          );
          final google = OAuthService(
            config: h.buildConfig,
            httpClient: h.client,
            tokenStore: h.secrets,
            persistence: h.persistence,
            registrations: h.staging,
            loopbackFlow: flow,
          );
          final microsoft = MicrosoftOAuthService(
            config: h.buildConfig,
            httpClient: h.client,
            tokenStore: h.secrets,
            persistence: h.persistence,
            registrations: h.staging,
            loopbackFlow: flow,
          );
          Future<Object?> request() {
            if (action == 'first-contacts') {
              return provider == BusyProvider.google
                  ? google.authorizeGoogleContacts(id)
                  : microsoft.authorizeMicrosoftContacts(id);
            }
            if (action == 'category') {
              return microsoft.authorizeCategoryAccess(id);
            }
            if (action == 'shared-calendar') {
              return microsoft.authorizeSharedCalendarAccess(id);
            }
            final registration = provider == BusyProvider.google
                ? h.staging.stage(owned)
                : h.staging.stageMicrosoft(
                    clientId: msOwned,
                    audience: MicrosoftAudience.personalAndOrganizations,
                  );
            final intent = action == 'first-sign-in'
                ? AuthorizationRequest.newConnection(registration)
                : action == 'replace'
                ? AuthorizationRequest.replace(id, registration)
                : AuthorizationRequest.reconnect(id);
            return provider == BusyProvider.google
                ? google.connectGoogle(intent)
                : microsoft.connectMicrosoft(intent);
          }

          await expectLater(request(), throwsA(isA<OAuthException>()));
          expect(captured, isNotNull);
          final params = captured!.queryParameters;
          final requested = params['scope']!.split(' ').toSet();
          expect(params['code_challenge_method'], 'S256');
          expect(params['code_challenge'], isNotEmpty);
          expect(params['redirect_uri'], startsWith('http://'));
          expect(params, isNot(contains('include_granted_scopes')));
          if (provider == BusyProvider.google) {
            expect(requested, containsAll(googleBusyMaxOAuthScope.split(' ')));
            expect(requested, isNot(contains(googleContactsWriteScope)));
            expect(
              requested.contains(googleContactsReadScope),
              action != 'first-sign-in',
            );
          } else {
            expect(requested, containsAll(microsoftTodoOAuthScopes.split(' ')));
            expect(requested, isNot(contains(microsoftContactsWriteScope)));
            expect(requested, isNot(contains('Contacts.ReadWrite')));
            expect(
              requested.contains(microsoftContactsReadScope),
              action != 'first-sign-in',
            );
            if (action == 'category' ||
                action == 'shared-calendar' ||
                action == 'reconnect' ||
                action == 'replace') {
              expect(
                requested,
                containsAll([
                  microsoftSharedCalendarScope,
                  microsoftCategoryScope,
                ]),
              );
            }
          }
          expect(h.requests, isEmpty);
        },
      );
    }
  }
}
