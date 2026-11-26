import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_repository.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/ical/dav_native_export.dart';
import 'package:busymax/src/dav/ical/dav_native_import.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/dav/sync/dav_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/features/accounts/domain/account_connection_state.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:uuid/uuid.dart';

void main() {
  final fixture = Platform.environment['BUSYMAX_JOURNAL_LIVE_FIXTURE'];
  for (final provider in [BusyProvider.caldav, BusyProvider.nextcloud]) {
    test(
      'journal durable CRUD with independent HTTPS readback on ${provider.name}',
      () async {
        final specs = jsonDecode(File(fixture!).readAsStringSync()) as Map;
        final spec = specs[provider.storageValue] as Map;
        final authority = Uri.parse(spec['authority'] as String);
        expect(authority.scheme, 'https');
        final principal = spec['username'] as String;
        final password = spec['password'] as String;
        final ca = spec['caFile'] as String;
        http.Client client() => IOClient(
          HttpClient(
            context: SecurityContext(withTrustedRoots: true)
              ..setTrustedCertificates(ca),
          ),
        );
        final accountClient = client();
        final peer = client();
        addTearDown(accountClient.close);
        addTearDown(peer.close);
        final auth = base64Encode(utf8.encode('$principal:$password'));
        Future<http.Response> request(
          String method,
          Uri target, {
          String? body,
          Map<String, String> headers = const {},
        }) async {
          expect(target.origin, authority.origin);
          final message = http.Request(method, target)
            ..followRedirects = false
            ..headers.addAll({'Authorization': 'Basic $auth', ...headers});
          if (body != null) message.body = body;
          return http.Response.fromStream(await peer.send(message));
        }

        const accountId = 'live-journal-test';
        final directory = await Directory.systemTemp.createTemp(
          'journal-live-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/app.db');
        var database = AppDatabase(NativeDatabase(file));
        addTearDown(() => database.close());
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: accountId,
                provider: provider.storageValue,
                authority: authority.toString(),
                providerAccountId: principal,
                credentialKind: provider == BusyProvider.caldav
                    ? 'caldav_password'
                    : 'nextcloud_app_password',
                authState: Value(AccountConnectionState.connected.storageValue),
                createdAtUtc: '2026-11-26T00:00:00Z',
                updatedAtUtc: '2026-11-26T00:00:00Z',
              ),
            );
        final profile = davProviderProfile(
          provider,
          caldavServer: authority,
          nextcloudServer: authority,
        );
        final credential = DavBasicCredential(
          username: principal,
          password: password,
        );
        final transport = DavHttpTransport(
          client: accountClient,
          profile: profile,
          accountAuthority: authority,
        );
        final discovery = DavDiscoveryService(
          transport: transport,
          profile: profile,
          accountAuthority: authority,
          accountId: accountId,
          credential: credential,
        );
        final home = (await discovery.discover(correlationId: 'journal-home'))
            .service
            .calendarHomeHref;
        final collectionUri = Uri.parse(
          home.toString().endsWith('/') ? '$home' : '$home/',
        ).resolve('journal-qa-${const Uuid().v4()}/');
        final created = await request(
          'MKCALENDAR',
          collectionUri,
          headers: {'Content-Type': 'application/xml; charset=utf-8'},
          body: '''
        <c:mkcalendar xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
          <d:set><d:prop><d:displayname>Journal QA</d:displayname>
          <c:supported-calendar-component-set><c:comp name="VJOURNAL"/></c:supported-calendar-component-set>
          </d:prop></d:set>
        </c:mkcalendar>''',
        );
        expect(created.statusCode, 201);
        addTearDown(() async {
          final deleted = await request('DELETE', collectionUri);
          expect(deleted.statusCode, anyOf(200, 204));
        });
        await DavDiscoveryRepository(database: database)
            .commitSuccessfulInventory(
              await discovery.discover(correlationId: 'journal-inventory'),
            );
        final collection =
            (await JournalRepository(
              database,
            ).watchSources().first).singleWhere(
              (row) => Uri.parse(row.requestUri).path == collectionUri.path,
            );
        Future<void> pull() async {
          await DavSyncEngine(
            database: database,
            objectRepository: DavObjectRepository(database: database),
            remoteClient: DavCollectionHttpClient(
              transport: transport,
              profile: profile,
              accountAuthority: authority,
              accountId: accountId,
              collectionId: collection.id,
              collectionUri: collectionUri,
              credential: credential,
            ),
            accountId: accountId,
            collectionId: collection.id,
            provider: provider,
          ).synchronize(correlationId: 'journal-pull');
        }

        Future<DavReplaySummary> replay() => DavPendingOperationsReplayer(
          database: database,
          accountId: accountId,
          serviceFactory: ({required account, required collection}) async =>
              DavConditionalMutationService(
                remoteClient: DavMutationHttpClient(
                  transport: transport,
                  accountId: account.id,
                  collectionId: collection.id,
                  credential: credential,
                ),
              ),
        ).replayDueOperations();
        await pull();
        var journals = JournalRepository(database);
        await journals.create(
          collection,
          title: 'New journal',
          status: 'DRAFT',
          descriptions: [
            const DavRawPropertyValue(value: 'First body'),
            const DavRawPropertyValue(value: 'Second body'),
          ],
        );
        expect(await database.select(database.pendingOps).get(), hasLength(1));
        await database.close();
        database = AppDatabase(NativeDatabase(file));
        journals = JournalRepository(database);
        expect(
          (await journals.watchEntries(collectionId: collection.id).first)
              .single
              .title,
          'New journal',
        );
        expect((await replay()).appliedCount, 1);
        final object = await database.select(database.davObjects).getSingle();
        final href = Uri.parse(object.requestUri);
        final original = await request('GET', href);
        expect(original.statusCode, 200);
        expect(original.headers['etag'], object.etag);
        expect(original.body, contains('BEGIN:VJOURNAL'));
        expect(original.body, contains('DESCRIPTION:First body'));
        expect(original.body, contains('DESCRIPTION:Second body'));
        final peerEdit = await request(
          'PUT',
          href,
          body: original.body.replaceFirst(
            'STATUS:DRAFT',
            'STATUS:FINAL\r\nX-JOURNAL:preserved',
          ),
          headers: {
            'Content-Type': 'text/calendar; charset=utf-8',
            'If-Match': original.headers['etag']!,
          },
        );
        expect(peerEdit.statusCode, 204);
        await pull();
        final entry =
            (await journals.watchEntries(search: 'second body').first).single;
        expect(entry.status, 'FINAL');
        await journals.edit(await journals.read(entry), [
          DavPatchOperation.setText('SUMMARY', 'Edited journal'),
        ]);
        expect((await replay()).appliedCount, 1);
        final edited = await request('GET', href);
        expect(edited.body, contains('SUMMARY:Edited journal'));
        expect(edited.body, contains('X-JOURNAL:preserved'));
        expect(edited.body, contains('DESCRIPTION:Second body'));
        await journals.deleteResource(await journals.read(entry));
        expect((await replay()).appliedCount, 1);
        expect((await request('GET', href)).statusCode, 404);
        await pull();
        expect(await journals.watchEntries().first, isEmpty);
        if (provider == BusyProvider.nextcloud) {
          const period = 'RDATE;VALUE=PERIOD:20261127T090000Z/PT2H';
          const original =
              'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax//Live fixture//EN\r\n'
              'BEGIN:VJOURNAL\r\nUID:journal-period-live-test\r\n'
              'DTSTAMP:20261125T080000Z\r\nDTSTART:20261126T090000Z\r\n'
              '$period\r\nEND:VJOURNAL\r\nEND:VCALENDAR\r\n';
          final result = (await DavNativeImportService(database).import(
            accountId: accountId,
            collectionId: collection.id,
            preview: NextcloudNativeImportPreview.parse(
              IcalDocument.parse(original),
            ),
          )).single;
          expect(result.status, NativeImportItemStatus.queued);
          expect((await replay()).appliedCount, 0);
          final pending = await database
              .select(database.pendingOps)
              .getSingle();
          expect(pending.entityType, 'journal');
          final retained = (await DavNativeExportService(
            database,
          ).collection(accountId, collection.id)).single;
          expect(retained.rawIcs, original);
          final rejected = await request(
            'GET',
            authority.resolve(pending.davMemberHref!),
          );
          expect(rejected.statusCode, 404);
        }
      },
      skip: fixture == null
          ? 'Set BUSYMAX_JOURNAL_LIVE_FIXTURE to private HTTPS fixture configuration.'
          : false,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
