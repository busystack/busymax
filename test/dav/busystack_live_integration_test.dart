@Timeout(Duration(minutes: 10))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/storage/dav_collection_capabilities.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/dav/sync/dav_sync_engine.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'support/caldav_fixture.dart';
import 'support/caldav_qa_targets.dart';
import 'support/ical_observance_fixture.dart';

void main() {
  final enabled =
      Platform.environment['BUSYMAX_CALDAV_LIVE'] == '1' &&
      Platform.environment['BUSYMAX_CALDAV_LIFECYCLE'] == '1';
  sharingTests(enabled);
  test(
    'BusyStack 0.1.0: oversized queued resource is rejected atomically and retained locally',
    () async {
      final wire = _PutWire();
      final f = CalDavFixture(
        Uri.parse('https://localhost:18448/dav/'),
        wrapAccountClient: (client) => _PutWireClient(client, wire),
      );
      await f.open();
      try {
        final collection =
            (await f.database.select(f.database.davCollections).get())
                .singleWhere((c) => c.id == f.collectionId);
        expect(collection.maximumResourceSize, 1024 * 1024);
        final list = (await f.database.select(f.database.taskLists).get())
            .singleWhere((l) => l.davCollectionId == f.collectionId);
        await f.tasks.createTask(
          list.id,
          const TaskCreateInput(title: 'Resource limit baseline'),
        );
        await f.synchronize();
        final item = (await f.database.select(f.database.tasks).get())
            .singleWhere((t) => t.davCollectionId == f.collectionId);
        final object = (await f.database.select(f.database.davObjects).get())
            .singleWhere((o) => o.id == item.davObjectId);
        final target = Uri.parse(object.requestUri);
        final before = await f.independentRequest('GET', target);
        // Many individually bounded properties exceed the resource limit
        // without violating BusyMax's separate unfolded-content-line budget.
        final large = task(1992).replaceFirst(
          'END:VTODO',
          '${List.generate(270, (i) => 'X-LARGE-$i:${'x' * 4000}').join('\r\n')}\r\nEND:VTODO',
        );
        await DavPendingOperationQueue(database: f.database).enqueueCreate(
          accountId: f.id,
          collectionId: f.collectionId!,
          object: DavNewObject(
            uid: 'page-1992@example.test',
            initialMemberName: 'oversized.ics',
            rawIcs: large,
            componentType: 'VTODO',
          ),
        );
        await f.synchronize();
        final pending = await f.database
            .select(f.database.pendingOps)
            .getSingle();
        expect(wire.status, 413);
        expect(pending.state, 'failed');
        expect(pending.lastErrorCode, 'DavMaximumResourceSize');
        expect(
          (jsonDecode(pending.requestJson) as Map)['rawIcs'].toString().length,
          large.length,
        );
        expect(pending.requestJson.contains('X-LARGE-269:'), isTrue);
        expect(
          (await f.independentRequest(
            'GET',
            f.createdCollectionUri!.resolve('oversized.ics'),
          )).statusCode,
          404,
        );
        final after = await f.independentRequest('GET', target);
        expect(after.statusCode, 200);
        expect(after.body, before.body);
        expect(after.headers['etag'], before.headers['etag']);
      } finally {
        await f.close();
      }
    },
    skip: enabled
        ? false
        : 'Requires isolated BusyStack resource-limit fixture.',
  );
  test(
    'BusyStack 0.1.0: configured installation prefix, origin well-known and duplicate verified identity',
    () async {
      await control('profile', 'subpath');
      final f = CalDavFixture(
        Uri.parse('https://localhost:18448/calendar/dav/'),
      );
      try {
        await f.open();
        final generation = await f.persistence.generation(f.id);
        await expectLater(
          f.onboarding.connectCalDav(
            serverUrl: 'https://localhost:18448/',
            username: f.username,
            password: f.password,
          ),
          throwsA(
            isA<DavException>().having(
              (e) => e.code,
              'code',
              'DavAccountAlreadyConnected',
            ),
          ),
        );
        expect(
          await f.database.select(f.database.accounts).get(),
          hasLength(1),
        );
        expect(await f.persistence.generation(f.id), generation);
        final service = await f.database
            .select(f.database.davAccountServices)
            .getSingle();
        expect(
          Uri.parse(service.calendarHomeHref!).path,
          startsWith('/calendar/dav/'),
        );
        final list = (await f.database.select(f.database.taskLists).get())
            .singleWhere((l) => l.davCollectionId == f.collectionId);
        await f.tasks.createTask(
          list.id,
          const TaskCreateInput(title: 'Installation prefix task'),
        );
        await f.reopen();
        await f.synchronize();
        final object = (await f.database.select(f.database.davObjects).get())
            .singleWhere((o) => o.collectionId == f.collectionId);
        expect(Uri.parse(object.requestUri).path, startsWith('/calendar/dav/'));
        expect(
          (await f.independentRequest(
            'GET',
            Uri.parse(object.requestUri),
          )).body,
          contains('SUMMARY:Installation prefix task'),
        );
      } finally {
        try {
          await f.close();
        } finally {
          await control('profile', 'default');
        }
      }
    },
    skip: enabled
        ? false
        : 'Requires isolated BusyStack public-URL/context-path profile.',
  );
  test(
    'BusyStack 0.1.0: strict Depth, real 507 pages, restart, interruption and concurrent changes converge',
    () async {
      await control('profile', 'strict');
      final wire = _SyncWire();
      final f = CalDavFixture(
        Uri.parse('https://localhost:18448/dav/'),
        wrapAccountClient: (client) => _SyncWireClient(client, wire),
      );
      try {
        await f.open();
        final base = f.createdCollectionUri!;
        final nonzeroDepth = await f.independentRequest(
          'REPORT',
          base,
          headers: const {'Depth': '1', 'content-type': 'application/xml'},
          body: '<d:sync-collection xmlns:d="DAV:"><d:sync-token/><d:sync-level>1</d:sync-level><d:prop><d:getetag/></d:prop></d:sync-collection>',
        );
        expect(nonzeroDepth.statusCode, 400);
        for (var offset = 0; offset < 75; offset += 3) {
          await Future.wait([
            for (var i = offset; i < offset + 3; i++)
              f
                  .independentRequest(
                    'PUT',
                    base.resolve('page-$i.ics'),
                    body: task(i),
                    headers: const {
                      'content-type': 'text/calendar',
                      'if-none-match': '*',
                    },
                  )
                  .then((r) => expect(r.statusCode, 201)),
          ]);
        }
        DavCollectionHttpClient remote() {
          final profile = davProviderProfile(
            BusyProvider.caldav,
            caldavServer: f.uri,
          );
          return DavCollectionHttpClient(
            transport: DavHttpTransport(
              client: f.client,
              profile: profile,
              accountAuthority: f.uri,
            ),
            profile: profile,
            accountAuthority: f.uri,
            accountId: f.id,
            collectionId: f.collectionId!,
            collectionUri: base,
            credential: DavBasicCredential(
              username: f.username,
              password: f.password,
            ),
            maximumSyncResults: 17,
          );
        }

        DavSyncEngine engine(DavCollectionRemoteClient client) => DavSyncEngine(
          database: f.database,
          objectRepository: DavObjectRepository(database: f.database),
          remoteClient: client,
          accountId: f.id,
          collectionId: f.collectionId!,
          provider: BusyProvider.caldav,
        );
        var pages = 0, truncated = 0;
        final observed = _ObservedRemote(remote(), (page) async {
          pages++;
          expect(page.changedMembers.length, lessThanOrEqualTo(17));
          if (page.truncated) truncated++;
          if (pages == 1) {
            expect(page.truncated, isTrue);
            expect(
              (await f.independentRequest(
                'PUT',
                base.resolve('page-74.ics'),
                body: task(74, title: 'Changed during pagination'),
                headers: const {'content-type': 'text/calendar'},
              )).statusCode,
              anyOf(201, 204),
            );
            expect(
              (await f.independentRequest(
                'PUT',
                base.resolve('concurrent.ics'),
                body: task(999),
                headers: const {
                  'content-type': 'text/calendar',
                  'if-none-match': '*',
                },
              )).statusCode,
              201,
            );
          }
          if (pages == 2) await control('restart');
        });
        final initial = await engine(observed).synchronize(
          correlationId: 'strict-paged-initial',
          forceRebaseline: true,
        );
        expect(initial.pages, greaterThan(1));
        expect(truncated, greaterThan(0));
        expect(initial.membersSeen, 75);
        expect(initial.finalCursorValue, isNotEmpty);
        await engine(remote())
            .synchronize(correlationId: 'paged-concurrent-delta');
        var objects = (await f.database.select(f.database.davObjects).get())
            .where((o) => o.collectionId == f.collectionId && !o.serverDeleted)
            .toList();
        expect(objects, hasLength(76));
        expect(
          objects
              .singleWhere((o) => o.requestUri.endsWith('/page-74.ics'))
              .rawIcsBody,
          contains('Changed during pagination'),
        );
        final repository = DavObjectRepository(database: f.database);
        final before = (await repository.cursor(f.collectionId!))!;
        for (var i = 100; i < 120; i++) {
          expect(
            (await f.independentRequest(
              'PUT',
              base.resolve('page-$i.ics'),
              body: task(i),
              headers: const {
                'content-type': 'text/calendar',
                'if-none-match': '*',
              },
            )).statusCode,
            201,
          );
        }
        var interruptedPages = 0;
        final interrupted = _ObservedRemote(remote(), (page) async {
          if (++interruptedPages == 1) {
            expect(page.truncated, isTrue);
            return;
          }
          throw const DavException(
            kind: DavErrorKind.network,
            code: 'QaInterruptedPage',
            safeMessage: 'QA interrupted after one real page.',
          );
        });
        await expectLater(
          engine(interrupted).synchronize(correlationId: 'interrupted-page'),
          throwsA(isA<DavException>()),
        );
        expect(interruptedPages, 2);
        expect(
          (await repository.cursor(f.collectionId!))!.cursorValue,
          before.cursorValue,
        );
        expect(
          (await f.database.select(f.database.davObjects).get()).where(
            (o) => o.collectionId == f.collectionId && !o.serverDeleted,
          ),
          hasLength(76),
        );
        await f.reopen();
        final resumed = await engine(remote())
            .synchronize(correlationId: 'resumed-after-reopen');
        expect(resumed.pages, greaterThan(1));
        expect(
          (await f.database.select(f.database.davObjects).get()).where(
            (o) => o.collectionId == f.collectionId && !o.serverDeleted,
          ),
          hasLength(96),
        );
        await (f.database.update(
          f.database.syncCursors,
        )..where((r) => r.davCollectionId.equals(f.collectionId!))).write(
          const SyncCursorsCompanion(cursorValue: Value('invalid-qa-token')),
        );
        final baseline = await engine(remote())
            .synchronize(correlationId: 'invalid-token-rebaseline');
        expect(baseline.initialOrRebaseline, isTrue);
        expect(baseline.pages, greaterThan(1));
        expect(baseline.membersSeen, 96);
        expect(wire.depths, isNotEmpty);
        expect(wire.depths, everyElement('0'));
        expect(wire.collection507, greaterThan(0));
      } finally {
        try {
          await f.close();
        } finally {
          await control('profile', 'default');
        }
      }
    },
    skip: enabled ? false : 'Requires isolated BusyStack release and BUSYMAX_CALDAV_LIVE/BUSYMAX_CALDAV_LIFECYCLE=1; run alone.',
  );
  test(
    'BusyStack 0.1.0: transformed timezone PUT retrieves canonical ETag before conditional editing; strict rejection is atomic',
    () async {
      final wire = _PutWire();
      final f = CalDavFixture(
        Uri.parse('https://localhost:18448/dav/'),
        wrapAccountClient: (client) => _PutWireClient(client, wire),
      );
      try {
        await f.open();
        final base = f.createdEventCollectionUri!;
        final collection =
            (await f.database.select(f.database.davCollections).get())
                .singleWhere((c) => c.id == f.eventCollectionId);
        final profile = davProviderProfile(
          BusyProvider.caldav,
          caldavServer: f.uri,
        );
        final remote = DavMutationHttpClient(
          transport: DavHttpTransport(
            client: f.client,
            profile: profile,
            accountAuthority: f.uri,
          ),
          accountId: f.id,
          collectionId: collection.id,
          credential: DavBasicCredential(
            username: f.username,
            password: f.password,
          ),
        );
        final service = DavConditionalMutationService(remoteClient: remote);
        final invalid = timezoneEvent('repaired@example.test', invalid: true);
        final created = await service.create(
          collectionUri: base,
          object: DavNewObject(
            uid: 'repaired@example.test',
            initialMemberName: 'repaired.ics',
            rawIcs: invalid,
            componentType: 'VEVENT',
          ),
          capabilities: collectionCapabilitiesFromStored(collection),
          correlationId: 'transformed-create',
        );
        expect(wire.status, 201);
        expect(wire.etag, isNull);
        expect(wire.lastModified, isNull);
        final stored = await f.independentRequest(
          'GET',
          base.resolve('repaired.ics'),
        );
        expect(stored.statusCode, 200);
        expect(stored.headers['etag'], isNotEmpty);
        expect(stored.body, contains('UNTIL=20271107T090000Z'));
        expect(stored.body, contains('UNTIL=20270314T100000Z'));
        expect(created.outcome, DavMutationOutcome.succeeded);
        expect(created.canonicalObject!.etag, stored.headers['etag']);
        final updated = await service.update(
          hrefKey: base.resolve('repaired.ics').path,
          uri: base.resolve('repaired.ics'),
          baselineEtag: created.canonicalObject!.etag!,
          baselineRawIcs: created.canonicalObject!.rawIcsBody!,
          patch: DavMutationPatch(
            target: const IcalComponentKey(
              componentType: 'VEVENT',
              uid: 'repaired@example.test',
            ),
            scope: DavMutationScope.object,
            operations: [
              DavPatchOperation.setText(
                'SUMMARY',
                'Edited after canonical retrieval',
              ),
            ],
          ),
          capabilities: collectionCapabilitiesFromStored(collection),
          correlationId: 'canonical-update',
        );
        expect(updated.outcome, DavMutationOutcome.succeeded);
        final edited = await f.independentRequest(
          'GET',
          base.resolve('repaired.ics'),
        );
        expect(
          edited.body,
          contains('SUMMARY:Edited after canonical retrieval'),
        );
        expect(edited.body, contains('X-OPAQUE;X-PARAM=exact:preserve'));
        expect(
          (await f.independentRequest(
                'PROPFIND',
                base,
                headers: const {'Depth': '1'},
                body: '<d:propfind xmlns:d="DAV:"><d:prop><d:getetag/></d:prop></d:propfind>',
              )).body.split('repaired.ics').length -
              1,
          1,
        );
        final valid = timezoneEvent('valid@example.test', invalid: false);
        final validCreated = await service.create(
          collectionUri: base,
          object: DavNewObject(
            uid: 'valid@example.test',
            initialMemberName: 'valid.ics',
            rawIcs: valid,
            componentType: 'VEVENT',
          ),
          capabilities: collectionCapabilitiesFromStored(collection),
          correlationId: 'valid-create',
        );
        expect(validCreated.outcome, DavMutationOutcome.succeeded);
        expect(wire.etag, isNotEmpty);
        expect(
          (await f.independentRequest('GET', base.resolve('valid.ics'))).body,
          valid,
        );
        await control('profile', 'no-repair');
        final rejected = await f.independentRequest(
          'PUT',
          base.resolve('must-reject.ics'),
          body: timezoneEvent('strict-invalid@example.test', invalid: true),
          headers: const {
            'content-type': 'text/calendar',
            'if-none-match': '*',
          },
        );
        expect(rejected.statusCode, 403);
        expect(
          (await f.independentRequest(
            'GET',
            base.resolve('must-reject.ics'),
          )).statusCode,
          404,
        );
        final strictValid = timezoneEvent(
          'strict-valid@example.test',
          invalid: false,
        );
        final accepted = await f.independentRequest(
          'PUT',
          base.resolve('strict-valid.ics'),
          body: strictValid,
          headers: const {
            'content-type': 'text/calendar',
            'if-none-match': '*',
          },
        );
        expect(accepted.statusCode, 201);
        expect(accepted.headers['etag'], isNotEmpty);
        expect(
          (await f.independentRequest(
            'GET',
            base.resolve('strict-valid.ics'),
          )).body,
          strictValid,
        );
      } finally {
        try {
          await f.close();
        } finally {
          await control('profile', 'default');
        }
      }
    },
    skip: enabled
        ? false
        : 'Requires isolated BusyStack live lifecycle fixture.',
  );
  test(
    'BusyStack 0.1.0: revocation, expiry and disabling reject held leases and retain queued work',
    () async {
      final f = CalDavFixture(Uri.parse('https://localhost:18448/dav/'));
      await f.open(username: 'disabled');
      try {
        final list = (await f.database.select(f.database.taskLists).get())
            .singleWhere((l) => l.davCollectionId == f.collectionId);
        await f.tasks.createTask(
          list.id,
          const TaskCreateInput(title: 'Credential lifecycle'),
        );
        await f.synchronize();
        final item = (await f.database.select(f.database.tasks).get())
            .singleWhere((t) => t.davCollectionId == f.collectionId)
            .id;
        Future<void> queue(String title) =>
            f.tasks.patchTask(list.id, item, TaskPatchInput({'title': title}));
        Future<void> heldLeaseRejects(
          Future<void> Function() change,
        ) => f.persistence.withCurrentCredential(f.id, (record) async {
          expect(record, isA<CalDavSecretRecord>());
          final secret = record! as CalDavSecretRecord;
          final raw = f.newClient();
          Future<int> probe() async {
            final request = http.Request('PROPFIND', f.uri)
              ..followRedirects = false
              ..headers.addAll({
                'authorization':
                    'Basic ${base64Encode(utf8.encode('${secret.username}:${secret.password}'))}',
                'Depth': '0',
                'content-type': 'application/xml',
              })
              ..body =
                  '<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>';
            return (await http.Response.fromStream(await raw.send(request)))
                .statusCode;
          }

          try {
            expect(await probe(), 207);
            await change();
            expect(await probe(), 401);
            expect(await probe(), 401);
          } finally {
            raw.close();
          }
        });
        Future<void> blocked(String title) async {
          await expectLater(
            f.synchronize(),
            throwsA(
              anyOf(
                isA<DavException>().having(
                  (e) => e.kind,
                  'kind',
                  DavErrorKind.authentication,
                ),
                isA<DavAccountSyncException>().having(
                  (e) => e.failures.map((f) => f.kind).toSet(),
                  'failure kinds',
                  {DavErrorKind.authentication},
                ),
              ),
            ),
          );
          expect(
            await f.database.select(f.database.pendingOps).get(),
            hasLength(1),
          );
          expect(
            (await f.database.select(f.database.tasks).get())
                .singleWhere((t) => t.id == item)
                .title,
            title,
          );
        }

        Future<void> reconnect() async {
          final generation = await f.persistence.generation(f.id);
          f.password = (await calDavQaCredentials(f.uri))['disabled'] as String;
          final result = await f.onboarding.replaceCalDavPassword(
            accountId: f.id,
            password: f.password,
          );
          expect(result.accountId, f.id);
          expect(await f.persistence.generation(f.id), generation + 1);
          await f.reopen();
          await f.synchronize();
          expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
        }

        await queue('Queued during revocation');
        await heldLeaseRejects(() async {
          await manage(['issue', 'disabled', 'BusyMax QA expiry']);
          await manage(['revoke', 'disabled', 'BusyMax QA primary']);
        });
        await blocked('Queued during revocation');
        await reconnect();
        await queue('Queued during expiry');
        await heldLeaseRejects(() => manage(['expire', 'disabled']));
        await blocked('Queued during expiry');
        await manage(['issue', 'disabled', 'BusyMax QA final']);
        await reconnect();
        final stored = (await f.database.select(f.database.tasks).get())
            .singleWhere((t) => t.id == item);
        final object = (await f.database.select(f.database.davObjects).get())
            .singleWhere((o) => o.id == stored.davObjectId);
        expect(
          (await f.independentRequest(
            'GET',
            Uri.parse(object.requestUri),
          )).body,
          contains('SUMMARY:Queued during expiry'),
        );
        await queue('Queued when account disabled');
        // Clean only this test's remote fixtures while the credential is valid.
        // The local pending operation and cached item remain for the assertion.
        for (final target in [
          f.createdCollectionUri!,
          f.createdEventCollectionUri!,
        ]) {
          expect(
            (await f.independentRequest('DELETE', target)).statusCode,
            204,
          );
        }
        f.createdCollectionUri = null;
        f.createdEventCollectionUri = null;
        await heldLeaseRejects(() => manage(['disable', 'disabled']));
        await blocked('Queued when account disabled');
      } finally {
        await f.close();
      }
    },
    skip: enabled ? false : 'Requires freshly provisioned dedicated lifecycle user; disables only that user.',
  );
}

void sharingTests(bool enabled) {
  test(
    'BusyStack 0.1.0: direct and group permissions change without losing queued edits',
    () async {
      final owner = CalDavFixture(Uri.parse('https://localhost:18448/dav/'));
      final reader = CalDavFixture(owner.uri);
      await owner.open(username: 'bob');
      await reader.open();
      final group = 'BusyMax QA group ${DateTime.now().microsecondsSinceEpoch}';
      var groupCreated = false;
      try {
        Future<DavCollection> shared({required bool write}) async {
          await reader.synchronize(full: true);
          final collection =
              (await reader.database
                      .select(reader.database.davCollections)
                      .get())
                  .singleWhere(
                    (c) =>
                        c.displayName == owner.collectionName &&
                        !c.serverMissing,
                  );
          final caps = collectionCapabilitiesFromStored(collection);
          expect(caps.permissionsKnown, isTrue);
          expect(caps.canRead, isTrue);
          expect(caps.canWriteContent, write);
          expect(caps.canAddMembers, write);
          return collection;
        }

        await manage(['share', 'bob', owner.collectionName, 'alice', 'READ']);
        var collection = await shared(write: false);
        final binding = collection.id;
        expect(
          (await reader.independentRequest(
            'PROPFIND',
            Uri.parse(collection.requestUri),
            headers: const {'Depth': '0'},
          )).statusCode,
          207,
        );
        expect(
          (await reader.independentRequest(
            'PUT',
            Uri.parse(collection.requestUri).resolve('read-denied.ics'),
            body: task(991),
            headers: const {
              'content-type': 'text/calendar',
              'if-none-match': '*',
            },
          )).statusCode,
          403,
        );
        await manage(['share', 'bob', owner.collectionName, 'alice', 'WRITE']);
        collection = await shared(write: true);
        expect(collection.id, binding);
        final list =
            (await reader.database.select(reader.database.taskLists).get())
                .singleWhere((l) => l.davCollectionId == binding);
        await reader.tasks.createTask(
          list.id,
          const TaskCreateInput(title: 'Shared write'),
        );
        await reader.synchronize();
        final item = (await reader.database.select(reader.database.tasks).get())
            .singleWhere((t) => t.davCollectionId == binding);
        final object =
            (await reader.database.select(reader.database.davObjects).get())
                .singleWhere((o) => o.id == item.davObjectId);
        final href = Uri.parse(object.requestUri);
        expect(
          (await reader.independentRequest('GET', href)).body,
          contains('SUMMARY:Shared write'),
        );
        await reader.tasks.patchTask(
          list.id,
          item.id,
          const TaskPatchInput({'title': 'Unsent shared edit'}),
        );
        expect(
          (await owner.independentRequest(
            'PUT',
            owner.createdCollectionUri!.resolve('paging-permission.ics'),
            body: task(992),
            headers: const {
              'content-type': 'text/calendar',
              'if-none-match': '*',
            },
          )).statusCode,
          201,
        );
        final profile = davProviderProfile(
          BusyProvider.caldav,
          caldavServer: reader.uri,
        );
        final paged = DavCollectionHttpClient(
          transport: DavHttpTransport(
            client: reader.client,
            profile: profile,
            accountAuthority: reader.uri,
          ),
          profile: profile,
          accountAuthority: reader.uri,
          accountId: reader.id,
          collectionId: binding,
          collectionUri: Uri.parse(collection.requestUri),
          credential: DavBasicCredential(
            username: reader.username,
            password: reader.password,
          ),
          maximumSyncResults: 1,
        );
        final page = await paged.syncCollectionPage(
          syncToken: '',
          correlationId: 'permission-page-first',
        );
        expect(page.truncated, isTrue);
        await manage(['share', 'bob', owner.collectionName, 'alice', 'READ']);
        await expectLater(
          paged.syncCollectionPage(
            syncToken: page.nextSyncToken,
            correlationId: 'permission-page-invalidated',
          ),
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'kind',
              DavErrorKind.invalidSyncToken,
            ),
          ),
        );
        await expectLater(
          reader.synchronize(full: true),
          throwsA(isA<DavAccountSyncException>()),
        );
        expect(
          (await reader.database.select(reader.database.pendingOps).get())
              .single
              .state,
          'permission_blocked',
        );
        expect(
          (await reader.database.select(reader.database.tasks).get())
              .singleWhere((t) => t.id == item.id)
              .title,
          'Unsent shared edit',
        );
        expect(
          (await reader.independentRequest('GET', href)).body,
          contains('SUMMARY:Shared write'),
        );
        await manage(['share', 'bob', owner.collectionName, 'alice', 'REVOKE']);
        try {
          await reader.synchronize(full: true);
        } on DavAccountSyncException {
          /* Retained blocked work. */
        }
        expect((await reader.independentRequest('GET', href)).statusCode, 404);
        expect(
          (await reader.database.select(reader.database.davCollections).get())
              .singleWhere((c) => c.id == binding)
              .serverMissing,
          isTrue,
        );
        expect(
          await reader.database.select(reader.database.pendingOps).get(),
          hasLength(1),
        );
        await manage(['group-create', group, 'alice']);
        groupCreated = true;
        await manage([
          'group-share',
          'bob',
          owner.collectionName,
          group,
          'READ',
        ]);
        // A restored binding still carries the unresolved edit. It must remain
        // blocked while group access grants only reading.
        try {
          await reader.synchronize(full: true);
        } on DavAccountSyncException {
          /* Expected blocked work. */
        }
        collection =
            (await reader.database.select(reader.database.davCollections).get())
                .singleWhere((c) => c.id == binding);
        expect(collection.serverMissing, isFalse);
        expect(
          collectionCapabilitiesFromStored(collection).canWriteContent,
          isFalse,
        );
        await manage([
          'group-share',
          'bob',
          owner.collectionName,
          group,
          'WRITE',
        ]);
        await reader.reopen();
        await reader.synchronize(full: true);
        expect(
          await reader.database.select(reader.database.pendingOps).get(),
          isEmpty,
        );
        expect(
          (await reader.independentRequest('GET', href)).body,
          contains('SUMMARY:Unsent shared edit'),
        );
        await reader.tasks.patchTask(
          list.id,
          item.id,
          const TaskPatchInput({'title': 'Retained after group removal'}),
        );
        await manage(['group-members', group, '']);
        try {
          await reader.synchronize(full: true);
        } on DavAccountSyncException {
          /* Inaccessible pending edit. */
        }
        expect((await reader.independentRequest('GET', href)).statusCode, 404);
        expect(
          await reader.database.select(reader.database.pendingOps).get(),
          hasLength(1),
        );
        expect(
          (await reader.database.select(reader.database.tasks).get())
              .singleWhere((t) => t.id == item.id)
              .title,
          'Retained after group removal',
        );
      } finally {
        if (groupCreated) await manage(['group-delete', group]);
        await reader.close();
        await owner.close();
      }
    },
    skip: enabled
        ? false
        : 'Requires isolated MFA/browser sharing fixture; run alone.',
  );
}

class _PutWire {
  int? status;
  String? etag, lastModified;
}

class _PutWireClient extends http.BaseClient {
  _PutWireClient(this.delegate, this.wire);
  final http.Client delegate;
  final _PutWire wire;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await delegate.send(request);
    if (request.method == 'PUT') {
      wire.status = response.statusCode;
      wire.etag = response.headers['etag'];
      wire.lastModified = response.headers['last-modified'];
    }
    return response;
  }

  @override
  void close() => delegate.close();
}

String task(int id, {String? title}) =>
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Independent BusyMax QA//EN\r\n'
    'BEGIN:VTODO\r\nUID:page-$id@example.test\r\nDTSTAMP:20261102T000000Z\r\nSUMMARY:${title ?? 'Page $id'}\r\n'
    'X-PRESERVE;X-PARAM=opaque:café 日本語\r\nEND:VTODO\r\nEND:VCALENDAR\r\n';

Future<void> control(String action, [String? argument]) async {
  await manage([action, if (argument != null) argument]);
}

Future<void> manage(List<String> arguments) async {
  final result = await Process.run('python3', [
    'test/interop/caldav/busystack-fixture.py',
    ...arguments,
  ]);
  expect(
    result.exitCode,
    0,
    reason: 'Isolated BusyStack fixture control failed: ${result.stderr}',
  );
}

class _ObservedRemote implements DavCollectionRemoteClient {
  _ObservedRemote(this.delegate, this.afterPage);
  final DavCollectionRemoteClient delegate;
  final Future<void> Function(DavSyncPage) afterPage;
  @override
  Future<DavSyncPage> syncCollectionPage({
    required String syncToken,
    required String correlationId,
    DavCancellationToken? cancellationToken,
  }) async {
    final page = await delegate.syncCollectionPage(
      syncToken: syncToken,
      correlationId: correlationId,
      cancellationToken: cancellationToken,
    );
    await afterPage(page);
    return page;
  }

  @override
  Future<DavMemberInventory> listMemberEtags({
    required String correlationId,
    DavCancellationToken? cancellationToken,
  }) => delegate.listMemberEtags(
    correlationId: correlationId,
    cancellationToken: cancellationToken,
  );
  @override
  Future<List<DavFetchedMember>> fetchMembers(
    List<DavRemoteMember> members, {
    required String correlationId,
    required bool useCalendarMultiget,
    DavCancellationToken? cancellationToken,
  }) => delegate.fetchMembers(
    members,
    correlationId: correlationId,
    useCalendarMultiget: useCalendarMultiget,
    cancellationToken: cancellationToken,
  );
}

class _SyncWire {
  final depths = <String?>[];
  int collection507 = 0;
}

class _SyncWireClient extends http.BaseClient {
  _SyncWireClient(this.delegate, this.log);
  final http.Client delegate;
  final _SyncWire log;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final sync =
        request is http.Request &&
        request.method == 'REPORT' &&
        request.body.contains('sync-collection');
    final response = await delegate.send(request);
    if (!sync) return response;
    log.depths.add(request.headers['depth']);
    final bytes = await response.stream.toBytes();
    if (response.statusCode == 207) {
      final xml = XmlDocument.parse(utf8.decode(bytes));
      for (final entry in xml.findAllElements(
        'response',
        namespaceUri: 'DAV:',
      )) {
        final href = entry
            .findElements('href', namespaceUri: 'DAV:')
            .singleOrNull
            ?.innerText;
        final status = entry
            .findElements('status', namespaceUri: 'DAV:')
            .singleOrNull
            ?.innerText;
        if (href != null &&
            request.url.resolve(href).path == request.url.path &&
            status?.contains(' 507 ') == true) {
          log.collection507++;
        }
      }
    }
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
      contentLength: bytes.length,
      request: request,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => delegate.close();
}
