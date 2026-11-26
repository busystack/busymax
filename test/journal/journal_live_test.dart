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
        final homeUri = Uri.parse(
          home.toString().endsWith('/') ? '$home' : '$home/',
        );
        Future<Uri> createCollection(List<String> types) async {
          final uri = homeUri.resolve('journal-qa-${const Uuid().v4()}/');
          final components = types
              .map((type) => '<c:comp name="$type"/>')
              .join();
          final created = await request(
            'MKCALENDAR',
            uri,
            headers: {'Content-Type': 'application/xml; charset=utf-8'},
            body:
                '''
        <c:mkcalendar xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
          <d:set><d:prop><d:displayname>Journal QA</d:displayname>
          <c:supported-calendar-component-set>$components</c:supported-calendar-component-set>
          </d:prop></d:set>
        </c:mkcalendar>''',
          );
          expect(created.statusCode, 201);
          addTearDown(() async {
            final deleted = await request('DELETE', uri);
            expect(deleted.statusCode, anyOf(200, 204));
          });
          return uri;
        }

        final collectionUri = await createCollection(['VJOURNAL']);
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
        Future<void> pull([DavCollection? source]) async {
          final target = source ?? collection;
          await DavSyncEngine(
            database: database,
            objectRepository: DavObjectRepository(database: database),
            remoteClient: DavCollectionHttpClient(
              transport: transport,
              profile: profile,
              accountAuthority: authority,
              accountId: accountId,
              collectionId: target.id,
              collectionUri: Uri.parse(target.requestUri),
              credential: credential,
            ),
            accountId: accountId,
            collectionId: target.id,
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
          body: original.body
              .replaceFirst(
                'SUMMARY:New journal',
                'SUMMARY;LANGUAGE=fr;X-QA=title:',
              )
              .replaceFirst(
                'STATUS:DRAFT',
                'STATUS;X-QA=status:FINAL\r\nX-JOURNAL:preserved',
              )
              .replaceFirst(
                RegExp(r'DTSTAMP:[^\r\n]+'),
                'DTSTAMP:20261125T080000Z\r\nLAST-MODIFIED:20261125T080000Z',
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
        journals = JournalRepository(
          database,
          nowUtc: () => DateTime.utc(2026, 11, 26, 13),
        );
        await journals.edit(await journals.read(entry), [
          DavPatchOperation.setRaw('STATUS', 'DRAFT', preserveParameters: true),
        ]);
        final emptySummary = (await journals.read(entry)).effectiveRawIcs;
        expect(emptySummary, contains('SUMMARY;LANGUAGE=fr;X-QA=title:\r\n'));
        await journals.edit(await journals.read(entry), [
          DavPatchOperation.setText('SUMMARY', 'Edited journal'),
        ]);
        const titleLine = 'SUMMARY;LANGUAGE=fr;X-QA=title:Edited journal';
        const statusLine = 'STATUS;X-QA=status:DRAFT';
        const stamp = 'DTSTAMP:20261126T130000Z';
        const modified = 'LAST-MODIFIED:20261126T130000Z';
        final pendingRevision = (await journals.read(entry)).effectiveRawIcs;
        for (final expected in [titleLine, statusLine, stamp, modified]) {
          expect(pendingRevision, contains(expected));
        }
        await database.close();
        database = AppDatabase(NativeDatabase(file));
        journals = JournalRepository(database);
        expect((await journals.read(entry)).effectiveRawIcs, pendingRevision);
        expect((await replay()).appliedCount, 1);
        final edited = await request('GET', href);
        expect(edited.statusCode, 200);
        for (final expected in [titleLine, statusLine, stamp, modified]) {
          expect(edited.body, contains(expected));
        }
        expect(edited.body, contains('X-JOURNAL:preserved'));
        expect(edited.body, contains('DESCRIPTION:Second body'));
        await journals.deleteResource(await journals.read(entry));
        expect((await replay()).appliedCount, 1);
        expect((await request('GET', href)).statusCode, 404);
        await pull();
        expect(await journals.watchEntries().first, isEmpty);
        if (provider == BusyProvider.caldav) {
          final nestedHref = collectionUri.resolve('nested-status.ics');
          const status =
              'BEGIN:VSTATUS\r\nSTATUS:FINAL\r\n'
              'COMMENT:Journal review\r\nEND:VSTATUS';
          const participant =
              'BEGIN:PARTICIPANT\r\nUID:journal-author\r\n'
              'PARTICIPANT-TYPE:CONTACT\r\nCALENDAR-ADDRESS:mailto:journal@example.invalid\r\n'
              'STATUS:FINAL\r\nBEGIN:VSTATUS\r\nSTATUS:FINAL\r\n'
              'COMMENT:Participant review\r\nEND:VSTATUS\r\nEND:PARTICIPANT';
          const nested =
              'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax//Live fixture//EN\r\n'
              'BEGIN:VJOURNAL\r\nUID:journal-status-test\r\nDTSTAMP:20261125T080000Z\r\n'
              'DTSTART:20261126T090000Z\r\nRRULE:FREQ=DAILY;COUNT=2\r\n'
              'STATUS:DRAFT\r\nEND:VJOURNAL\r\n'
              'BEGIN:VJOURNAL\r\nUID:journal-status-test\r\nDTSTAMP:20261125T080000Z\r\n'
              'RECURRENCE-ID:20261127T090000Z\r\nDTSTART:20261127T100000Z\r\n'
              'STATUS:FINAL\r\n$status\r\n$participant\r\nEND:VJOURNAL\r\nEND:VCALENDAR\r\n';
          final response = await request(
            'PUT',
            nestedHref,
            body: nested,
            headers: {
              'Content-Type': 'text/calendar; charset=utf-8',
              'If-None-Match': '*',
            },
          );
          expect(response.statusCode, 201);
          await pull();
          final rows = await journals
              .watchEntries(collectionId: collection.id)
              .first;
          final master = rows.singleWhere((row) => row.recurrenceIdKey == null);
          final detached = rows.singleWhere(
            (row) => row.recurrenceIdKey != null,
          );
          await journals.edit(await journals.read(master), [
            DavPatchOperation.setText('SUMMARY', 'Master edited offline'),
          ]);
          await journals.edit(await journals.read(detached), [
            DavPatchOperation.setText('SUMMARY', 'Detached edited offline'),
          ]);
          final pending = await database
              .select(database.pendingOps)
              .getSingle();
          expect(pending.attemptCount, 0);
          expect(pending.mutationPatchJson, contains('VSTATUS'));
          final effective = (await journals.read(detached)).effectiveRawIcs;
          expect(effective, contains(status));
          expect(effective, contains(participant));
          await database.close();
          database = AppDatabase(NativeDatabase(file));
          journals = JournalRepository(database);
          expect((await journals.read(detached)).effectiveRawIcs, effective);
          expect((await replay()).appliedCount, 1);
          final persisted = await request('GET', nestedHref);
          expect(persisted.body, effective);
        }
        if (provider == BusyProvider.nextcloud) {
          final corpusPath =
              Platform.environment['BUSYMAX_JOURNAL_CORPUS'] ??
              '../caldav-server/qualification/fixtures/vjournal/admission-v1.json';
          final corpus = jsonDecode(File(corpusPath).readAsStringSync()) as Map;
          const rejectedIds = {
            'J12-link-uid',
            'J12-link-xml',
            'J12-related-uid',
            'J15-start-end',
            'J15-start-duration',
          };
          String journalBody(String uid, List<String> lines) => [
            'BEGIN:VCALENDAR',
            'VERSION:2.0',
            'PRODID:-//BusyMax//Live fixture//EN',
            'BEGIN:VJOURNAL',
            'UID:$uid',
            'DTSTAMP:20261125T080000Z',
            ...lines,
            'END:VJOURNAL',
            'END:VCALENDAR',
            '',
          ].join('\r\n');
          const calendarHeaders = {
            'Content-Type': 'text/calendar; charset=utf-8',
          };
          final targetCreated = await request(
            'PUT',
            collectionUri.resolve('link-target.ics'),
            body: journalBody('target-fixture', [
              'SUMMARY:Same collection link target',
            ]),
            headers: {...calendarHeaders, 'If-None-Match': '*'},
          );
          expect(targetCreated.statusCode, 201);
          final exercised = <String>{};
          for (final item in (corpus['cases'] as List).cast<Map>()) {
            final id = item['id'] as String;
            if (!rejectedIds.contains(id)) continue;
            final lines = (item['journal'] as List).cast<String>();
            final createUid = 'create-$id';
            final original = journalBody(createUid, lines);
            final preview = NextcloudNativeImportPreview.parse(
              IcalDocument.parse(original),
            );
            final enqueued = preview.resources.single.rawIcs;
            expect(enqueued.replaceAll(RegExp(r'\r\n[ \t]'), ''), original);
            final result = (await DavNativeImportService(database).import(
              accountId: accountId,
              collectionId: collection.id,
              preview: preview,
            )).single;
            expect(result.status, NativeImportItemStatus.queued, reason: id);
            final updateUid = 'update-$id';
            final updateHref = collectionUri.resolve('$updateUid.ics');
            expect(
              (await request(
                'PUT',
                updateHref,
                body: journalBody(updateUid, [
                  'SUMMARY:Before rejected update',
                ]),
                headers: {...calendarHeaders, 'If-None-Match': '*'},
              )).statusCode,
              201,
            );
            final previous = await request('GET', updateHref);
            expect(previous.statusCode, 200);
            await pull();
            Future<DavJournalEntry> entryWithUid(String uid) async =>
                (await journals.watchEntries(collectionId: collection.id).first)
                    .singleWhere((entry) => entry.uid == uid);
            final toUpdate = await entryWithUid(updateUid);
            await journals.edit(await journals.read(toUpdate), [
              for (final property in IcalDocument.parse(
                original,
              ).calendarComponents.single.properties)
                if (!const {'UID', 'DTSTAMP'}.contains(property.name))
                  DavPatchOperation.setRaw(
                    property.name,
                    property.rawValue,
                    parameters: property.parameters,
                  ),
            ]);
            final intendedUpdate = (await journals.read(toUpdate))
                .effectiveRawIcs;
            expect((await replay()).appliedCount, 0, reason: id);
            final create = await entryWithUid(createUid);
            for (final entry in [create, toUpdate]) {
              final pending =
                  await (database.select(database.pendingOps)
                        ..where((p) => p.davObjectId.equals(entry.davObjectId)))
                      .getSingle();
              expect(pending.entityType, 'journal');
              expect(pending.state, anyOf('retry', 'failed'), reason: id);
              expect(pending.lastErrorCode, isNotNull, reason: id);
              if (entry.uid == createUid) {
                expect(
                  (await request(
                    'GET',
                    authority.resolve(pending.davMemberHref!),
                  )).statusCode,
                  404,
                  reason: id,
                );
              }
            }
            final after = await request('GET', updateHref);
            expect(after.statusCode, 200);
            expect(after.bodyBytes, previous.bodyBytes, reason: id);
            expect(after.headers['etag'], previous.headers['etag'], reason: id);
            await database.close();
            database = AppDatabase(NativeDatabase(file));
            journals = JournalRepository(database);
            final exported = await DavNativeExportService(database)
                .collection(accountId, collection.id);
            expect(
              exported.singleWhere((item) => item.uid == createUid).rawIcs,
              enqueued,
              reason: id,
            );
            expect(
              exported.singleWhere((item) => item.uid == updateUid).rawIcs,
              intendedUpdate,
              reason: id,
            );
            expect(
              (await journals.read(await entryWithUid(updateUid)))
                  .effectiveRawIcs,
              intendedUpdate,
            );
            exercised.add(id);
          }
          expect(exercised, rejectedIds);

          final mixedUri = await createCollection([
            'VEVENT',
            'VTODO',
            'VJOURNAL',
          ]);
          await DavDiscoveryRepository(
            database: database,
          ).commitSuccessfulInventory(
            await discovery.discover(correlationId: 'journal-mixed-inventory'),
          );
          final mixed = (await journals.watchSources().first).singleWhere(
            (row) => Uri.parse(row.requestUri).path == mixedUri.path,
          );
          expect(mixed.supportedComponentMask, 11);
          for (final component in ['VEVENT', 'VTODO', 'VJOURNAL']) {
            final member = await request(
              'PUT',
              mixedUri.resolve('$component.ics'),
              body:
                  'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax//Live fixture//EN\r\n'
                  'BEGIN:$component\r\nUID:mixed-$component\r\nDTSTAMP:20261125T080000Z\r\n'
                  'DTSTART:20261126T090000Z\r\nEND:$component\r\nEND:VCALENDAR\r\n',
              headers: {
                'Content-Type': 'text/calendar; charset=utf-8',
                'If-None-Match': '*',
              },
            );
            expect(member.statusCode, 201);
          }
          await pull(mixed);
          final members = database.select(database.davObjects)
            ..where((row) => row.collectionId.equals(mixed.id));
          expect(
            (await members.get()).map((row) => row.componentMask),
            unorderedEquals([1, 2, 8]),
          );
          expect(
            (await journals.watchEntries(collectionId: mixed.id).first)
                .single
                .uid,
            'mixed-VJOURNAL',
          );
          final collectionRow = database.select(database.davCollections)
            ..where((row) => row.id.equals(mixed.id));
          final syncToken = (await collectionRow.getSingle()).syncToken;
          expect(syncToken, isNotNull);
          await (database.update(
            database.davCollections,
          )..where((row) => row.id.equals(mixed.id))).write(
            const DavCollectionsCompanion(journalsSelected: Value(false)),
          );
          expect(
            await journals.watchEntries(collectionId: mixed.id).first,
            isEmpty,
          );
          expect(
            (await members.get()).map((row) => row.componentMask),
            unorderedEquals([1, 2, 8]),
          );
          expect((await collectionRow.getSingle()).syncToken, syncToken);
        }
      },
      skip: fixture == null
          ? 'Set BUSYMAX_JOURNAL_LIVE_FIXTURE to private HTTPS fixture configuration.'
          : false,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
