import 'package:busymax/src/core/auth/oauth_models.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_loopback_flow.dart';
import 'package:busymax/src/google_tasks/oauth/oauth_service.dart';
import 'package:busymax/src/microsoft_todo/oauth/microsoft_oauth_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/google_tasks/api/google_tasks_api_surface.dart';

import 'authorization_transition_test.dart' show Harness, owned, msOwned;

void main() {
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
