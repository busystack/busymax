import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_dav_context.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_federation_service.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(fixture.requests, hasLength(3));
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
