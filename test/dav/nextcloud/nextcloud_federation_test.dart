import 'dart:async';
import 'dart:convert';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_dav_context.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_federation_service.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nextcloud_admin_fixture.dart';

void main() {
  late NextcloudAdminFixture fixture;
  late NextcloudFederationService service;
  setUp(() async {
    fixture = NextcloudAdminFixture();
    await fixture.seed();
    service = NextcloudFederationService(fixture.collections);
    fixture.federationInvitations.add({
      'id': 7,
      'displayName': 'Remote team',
      'sharedBy': 'owner@cloud.test/subpath',
      'sharedByDisplayName': 'Owner',
      'remoteUrl': 'https://untrusted.test/never-request',
      'permissions': 31,
      'components': 'VEVENT,VTODO',
    });
  });
  tearDown(() => fixture.close());

  test(
    'overlapping optional discovery coalesces and retains its cache',
    () async {
      final started = Completer<void>(), release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      fixture.beforeResponse = (request) async {
        if (request.url.path.endsWith('/cloud/capabilities')) {
          if (!started.isCompleted) started.complete();
          await release.future;
        }
      };
      final first = service.discoverPending();
      await started.future;
      final second = service.discoverPending(force: true);
      expect(identical(first, second), isTrue);
      release.complete();
      await Future.wait([first, second]);
      final requests = fixture.requests.length;
      await service.discoverPending();
      expect(fixture.requests.length, requests);
      await service.discoverPending(force: true);
      expect(fixture.requests.length, greaterThan(requests));
    },
  );

  test(
    'a slow optional inventory cannot overwrite a newer invitation count',
    () async {
      final started = Completer<void>(), release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final invitation = Map<String, Object?>.from(
        fixture.federationInvitations.single,
      );
      var first = true;
      fixture.beforeResponse = (request) async {
        if (request.url.path.contains('federated_calendars') && first) {
          first = false;
          started.complete();
          await release.future;
          // Return the older request's captured server snapshot after the fresh read.
          fixture.federationInvitations.add(invitation);
        }
      };
      final old = service.pending(refreshDiscovery: false);
      await started.future;
      fixture.federationInvitations.clear();
      expect(await service.pending(refreshDiscovery: false), isEmpty);
      release.complete();
      expect(await old, hasLength(1));
      final account = await fixture.database
          .select(fixture.database.accounts)
          .getSingle();
      expect(federationSummary(account.providerMetadataJson)['count'], 0);
    },
  );

  for (final scenario in [
    'old-server',
    'incoming-disabled',
    'ocm-disabled',
    'missing-route',
  ]) {
    test(
      '$scenario hides unsupported federation and never publishes a zero count',
      () async {
        await service.pending();
        fixture.requests.clear();
        fixture.serverMajor = scenario == 'old-server' ? 31 : 34;
        fixture.incomingFederation = scenario != 'incoming-disabled';
        fixture.ocmEnabled = scenario != 'ocm-disabled';
        fixture.federationEndpointStatus = scenario == 'missing-route'
            ? 404
            : null;
        await service.discoverPending(force: true);
        final account = await fixture.database
            .select(fixture.database.accounts)
            .getSingle();
        final summary = federationSummary(account.providerMetadataJson);
        expect(summary['available'], isFalse);
        expect(summary.containsKey('count'), isFalse);
        expect(
          fixture.requests.where(
            (r) => r.url.path.contains('federated_calendars'),
          ),
          hasLength(scenario == 'missing-route' ? 1 : 0),
        );
        await expectLater(
          service.pending(),
          throwsA(
            isA<DavException>().having(
              (e) => e.code,
              'code',
              'NextcloudFederationUnsupported',
            ),
          ),
        );
      },
    );
  }

  test(
    'a capability discovery failure cannot invent successful empty discovery',
    () async {
      fixture.capabilitiesStatus = 503;
      await expectLater(service.pending(), throwsA(isA<DavException>()));
      final account = await fixture.database
          .select(fixture.database.accounts)
          .getSingle();
      expect(federationSummary(account.providerMetadataJson), isEmpty);
      expect(
        fixture.requests.where(
          (r) => r.url.path.contains('federated_calendars'),
        ),
        isEmpty,
      );
    },
  );

  test('availability distinguishes unknown, supported zero, unsupported and stale authorization', () async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(fixture.database)],
    );
    addTearDown(container.dispose);
    final count = nextcloudPendingInvitationCountProvider('account');
    final subscription = container.listen(count, (_, _) {});
    addTearDown(subscription.close);
    Future<void> waitForCount(int? expected) {
      final ready = Completer<void>();
      final listener = container.listen(count, (_, next) {
        if (next is AsyncData<int?> &&
            next.value == expected &&
            !ready.isCompleted) {
          ready.complete();
        }
      }, fireImmediately: true);
      return ready.future
          .timeout(const Duration(seconds: 5))
          .whenComplete(listener.close);
    }

    expect(await container.read(count.future), isNull);
    expect(
      container.read(nextcloudFederationAvailableProvider('account')),
      isFalse,
    );
    fixture.federationInvitations.clear();
    await service.discoverPending(force: true);
    await waitForCount(0);
    expect(
      container.read(nextcloudFederationAvailableProvider('account')),
      isTrue,
    );
    fixture.incomingFederation = false;
    await service.discoverPending(force: true);
    await waitForCount(null);
    expect(
      container.read(nextcloudFederationAvailableProvider('account')),
      isFalse,
    );
    fixture.incomingFederation = true;
    await service.discoverPending(force: true);
    await waitForCount(0);
    await fixture.database
        .into(fixture.database.authorizationGenerations)
        .insert(
          AuthorizationGenerationsCompanion.insert(
            accountId: 'account',
            generation: 9,
          ),
        );
    await waitForCount(null);
    expect(
      container.read(nextcloudFederationAvailableProvider('account')),
      isFalse,
    );
    expect(
      jsonDecode(
        (await fixture.database.select(fixture.database.accounts).getSingle())
            .providerMetadataJson!,
      )['federation']['count'],
      0,
    );
  });

  test(
    'normal refresh persists a private count and coalesces passive discovery',
    () async {
      await service.discoverPending();
      var account = await fixture.database
          .select(fixture.database.accounts)
          .getSingle();
      expect(federationSummary(account.providerMetadataJson)['count'], 1);
      expect(account.providerMetadataJson, isNot(contains('Remote team')));
      expect(account.providerMetadataJson, isNot(contains('untrusted.test')));
      final count = fixture.requests.length;
      await NextcloudFederationService(fixture.collections).discoverPending();
      expect(fixture.requests, hasLength(count));
      fixture.federationInvitations.clear();
      await service.discoverPending(force: true);
      account = await fixture.database
          .select(fixture.database.accounts)
          .getSingle();
      expect(federationSummary(account.providerMetadataJson)['count'], 0);
    },
  );

  test('offline discovery retains last count and stale responses cannot publish it', () async {
    await service.pending();
    fixture.ocsHttpStatus = 503;
    await expectLater(service.pending(), throwsA(isA<DavException>()));
    var account = await fixture.database
        .select(fixture.database.accounts)
        .getSingle();
    expect(federationSummary(account.providerMetadataJson)['count'], 1);
    fixture.ocsHttpStatus = 200;
    fixture.beforeResponse = (request) async {
      if (request.url.path.contains('federated_calendars')) {
        await fixture.database
            .into(fixture.database.authorizationGenerations)
            .insertOnConflictUpdate(
              AuthorizationGenerationsCompanion.insert(
                accountId: 'account',
                generation: 99,
              ),
            );
      }
    };
    fixture.federationInvitations.clear();
    await service.pending();
    account = await fixture.database
        .select(fixture.database.accounts)
        .getSingle();
    expect(
      federationSummary(account.providerMetadataJson)['generation'],
      isNot(99),
    );
    expect(federationSummary(account.providerMetadataJson)['count'], 1);
    fixture.beforeResponse = null;
    await service.discoverPending();
    account = await fixture.database
        .select(fixture.database.accounts)
        .getSingle();
    expect(federationSummary(account.providerMetadataJson)['generation'], 99);
    expect(federationSummary(account.providerMetadataJson)['count'], 0);
  });

  test(
    'pending accept and decline use only the owning installation OCS API',
    () async {
      final invitation = (await service.pending()).single;
      expect(invitation.permissions, 31);
      expect(
        await service.accept(invitation),
        NextcloudMutationOutcome.committed,
      );
      expect(fixture.refreshes, 1);
      expect(await service.pending(), isEmpty);
      expect(
        fixture.requests.every((r) => r.url.host == 'cloud.example.test'),
        isTrue,
      );
      expect(
        fixture.requests.where((r) => r.method == 'POST').single.url.path,
        '/ocs/v2.php/apps/dav/api/v1/federated_calendars/pending/7',
      );
      expect(fixture.requests.last.headers['ocs-apirequest'], 'true');
      await expectLater(
        service.decline(invitation),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'NextcloudFederationInvitationExpired',
          ),
        ),
      );
      fixture.federationInvitations.add({
        'id': 8,
        'displayName': 'Decline',
        'sharedBy': 'owner@cloud.test',
        'sharedByDisplayName': 'Owner',
        'remoteUrl': 'https://untrusted.test/never-request',
        'permissions': 1,
        'components': 'VEVENT',
      });
      await service.decline((await service.pending()).single);
      expect(
        fixture.requests.where((r) => r.method == 'DELETE').single.url.path,
        endsWith('/pending/8'),
      );
    },
  );

  test(
    'HTTP success cannot override failed OCS semantics or malformed data',
    () async {
      fixture.ocsStatus = 403;
      await expectLater(
        service.pending(),
        throwsA(
          isA<DavException>().having(
            (e) => e.kind,
            'kind',
            DavErrorKind.authorization,
          ),
        ),
      );
      fixture.ocsStatus = 200;
      fixture.malformedOcs = true;
      await expectLater(service.pending(), throwsA(isA<DavException>()));
      fixture.malformedOcs = false;
      fixture.ocsHttpStatus = 302;
      await expectLater(service.pending(), throwsA(isA<DavException>()));
      expect(
        fixture.requests.where(
          (r) => r.url.path.contains('federated_calendars'),
        ),
        hasLength(3),
      );
    },
  );

  test(
    'changed permissions invalidate a selected invitation before mutation',
    () async {
      final invitation = (await service.pending()).single;
      fixture.federationInvitations.single['permissions'] = 1;
      await expectLater(
        service.accept(invitation),
        throwsA(
          isA<DavException>().having(
            (e) => e.code,
            'code',
            'NextcloudFederationInvitationChanged',
          ),
        ),
      );
      expect(fixture.requests.every((r) => r.method == 'GET'), isTrue);
    },
  );

  test(
    'accept committed with a failed refresh reports refresh pending',
    () async {
      final invitation = (await service.pending()).single;
      fixture.failRefresh = true;
      expect(
        await service.accept(invitation),
        NextcloudMutationOutcome.refreshPending,
      );
      expect(await service.pending(), isEmpty);
      expect(fixture.requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );

  test('authorization replacement during fresh invitation read prevents a stale action', () async {
    final invitation = (await service.pending()).single;
    fixture.beforeResponse = (_) async {
      fixture.beforeResponse = null;
      await fixture.database
          .into(fixture.database.authorizationGenerations)
          .insert(
            AuthorizationGenerationsCompanion.insert(
              accountId: 'account',
              generation: 1,
            ),
          );
    };
    await expectLater(
      service.accept(invitation),
      throwsA(
        isA<DavException>().having(
          (e) => e.code,
          'code',
          'NextcloudFederationIdentityChanged',
        ),
      ),
    );
    expect(fixture.requests.every((r) => r.method == 'GET'), isTrue);
  });
}
