import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_collection_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_federation_service.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/db/native_database_connection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/persistence_test_directory.dart';
import 'nextcloud_admin_fixture.dart';

void main() {
  for (final supported in [true, false]) {
    test(
      'independent connections preserve newer ${supported ? 'count' : 'unsupported discovery'} after reopen',
      () async {
        final directory = await createPersistenceTestDirectory('federation-');
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/app.sqlite');
        Future<AppDatabase> open() async =>
            AppDatabase(await openNativeDatabase(file, android: true));
        final fixture = NextcloudAdminFixture(database: await open());
        addTearDown(fixture.close);
        await fixture.seed();
        await fixture.database
            .update(fixture.database.accounts)
            .write(
              const AccountsCompanion(
                providerMetadataJson: Value('{"unrelated":"preserved"}'),
              ),
            );
        var otherDatabase = await open();
        addTearDown(() => otherDatabase.close());
        final newer = NextcloudFederationService(
          NextcloudCollectionService(
            database: otherDatabase,
            secrets: fixture.secrets,
            client: fixture.client,
            accountId: 'account',
            requireNetwork: () async {},
            refresh: () async {},
          ),
        );
        final older = NextcloudFederationService(fixture.collections);
        final started = Completer<void>(), release = Completer<void>();
        var first = true;
        fixture.beforeResponse = (request) async {
          if (request.url.path.contains('federated_calendars') && first) {
            first = false;
            started.complete();
            await release.future;
            fixture.federationInvitations.add({
              'id': 7,
              'displayName': 'Older invitation',
              'sharedBy': 'owner@cloud.test',
              'sharedByDisplayName': 'Owner',
              'remoteUrl': 'https://untrusted.test/never-request',
              'permissions': 31,
              'components': 'VEVENT',
            });
          }
        };
        final oldResult = older.pending(refreshDiscovery: false);
        addTearDown(() async {
          if (!release.isCompleted) release.complete();
          await oldResult;
        });
        await started.future;
        fixture.serverMajor = supported ? 34 : 31;
        if (supported) {
          expect(await newer.pending(refreshDiscovery: false), isEmpty);
        } else {
          await expectLater(
            newer.pending(refreshDiscovery: false),
            throwsA(
              isA<DavException>().having(
                (error) => error.code,
                'code',
                'NextcloudFederationUnsupported',
              ),
            ),
          );
        }
        // Closing the newer connection ensures freshness is durable rather than
        // shared between service objects or database executors in memory.
        await otherDatabase.close();
        otherDatabase = await open();
        final before = await otherDatabase
            .select(otherDatabase.accounts)
            .getSingle();
        final summary = federationSummary(before.providerMetadataJson);
        expect(summary['available'], supported);
        expect(summary['count'], supported ? 0 : null);
        release.complete();
        expect(await oldResult, hasLength(1));
        final after = await otherDatabase
            .select(otherDatabase.accounts)
            .getSingle();
        expect(federationSummary(after.providerMetadataJson), summary);
        expect(
          jsonDecode(after.providerMetadataJson!)['unrelated'],
          'preserved',
        );
      },
    );
  }
}
