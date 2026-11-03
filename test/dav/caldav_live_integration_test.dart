@Timeout(Duration(minutes: 5))
library;

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/io_client.dart';

import 'nextcloud_live_integration_test.dart' show DavLiveFixture;
import 'support/caldav_fixture.dart';
import 'support/caldav_qa_targets.dart';

import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/dav/mutation/dav_collection_administration.dart';
import 'package:busymax/src/dav/xml/dav_xml.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' show Value;
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_sync_engine.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/dav/ical/dav_native_import.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/storage/dav_collection_capabilities.dart';
import 'package:xml/xml.dart';
import 'package:busymax/src/dav/http/dav_account_http_client.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';

void main() {
  final enabled = Platform.environment['BUSYMAX_CALDAV_LIVE'] == '1';
  final lifecycle =
      enabled && Platform.environment['BUSYMAX_CALDAV_LIFECYCLE'] == '1';
  for (final server in {
    'Radicale 3.9.0 HTTPS root': 'https://localhost:18443/',
    'Radicale 3.9.0 HTTPS installation':
        'https://localhost:18445/installation/',
    'Baikal 0.13.0 HTTPS direct': 'https://localhost:18444/dav.php/',
    'Baikal 0.13.0 HTTPS well-known': 'https://localhost:18444/',
    'Baikal 0.13.0 HTTPS installation':
        'https://localhost:18447/baikal/dav.php/',
    'Baikal 0.13.0 HTTPS installation base': 'https://localhost:18447/baikal/',
    'BusyStack 0.1.0 HTTPS direct': 'https://localhost:18448/dav/',
    'BusyStack 0.1.0 HTTPS well-known': 'https://localhost:18448/',
  }.entries) {
    test(
      '${server.key}: BusyMax discovers the actual authenticated inventory',
      () async {
        final credentials = await calDavQaCredentials(Uri.parse(server.value));
        final uri = Uri.parse(server.value);
        final profile = DavProviderProfile(
          provider: BusyProvider.caldav,
          bootstrapUri: uri,
          calendarEnabled: true,
          tasksEnabled: true,
          allowCollectionMutations: true,
          allowSchedulingMutations: false,
          allowMove: false,
          allowInsecureLoopbackForTesting: true,
        );
        final context = SecurityContext(withTrustedRoots: true)
          ..setTrustedCertificates('test/interop/caldav/.runtime/ca.pem');
        final client = IOClient(HttpClient(context: context));
        addTearDown(client.close);
        final result = await DavDiscoveryService(
          transport: DavHttpTransport(
            client: client,
            profile: profile,
            accountAuthority: uri,
          ),
          profile: profile,
          accountAuthority: uri,
          accountId: 'qa',
          credential: DavBasicCredential(
            username: 'alice',
            password: credentials['alice'] as String,
          ),
        ).discover(correlationId: 'generic-live-discovery');
        final events = result.collections.singleWhere(
          (c) => c.hrefKey.endsWith('/events/'),
        );
        final tasks = result.collections.singleWhere(
          (c) => c.hrefKey.endsWith('/tasks/'),
        );
        final mixed = result.collections
            .where((c) => c.hrefKey.endsWith('/mixed/'))
            .firstOrNull;
        final restricted = result.collections.singleWhere(
          (c) =>
              c.hrefKey.endsWith('/restricted/') ||
              c.displayName == 'BusyMax QA restricted',
        );
        expect(restricted.capabilities.permissionsKnown, isTrue);
        expect(events.eventProjectionEnabled, isTrue);
        expect(events.taskProjectionEnabled, isFalse);
        expect(tasks.eventProjectionEnabled, isFalse);
        expect(tasks.taskProjectionEnabled, isTrue);
        if (calDavQaSupportsMixed(uri)) {
          expect(mixed, isNotNull);
          expect(
            mixed!.eventProjectionEnabled && mixed.taskProjectionEnabled,
            isTrue,
          );
        } else {
          expect(mixed, isNull);
        }
        expect(restricted.capabilities.canWriteContent, isFalse);
        expect(restricted.capabilities.canRead, isTrue);
        expect(
          result.collections.every((c) => !c.capabilities.canSchedule),
          isTrue,
        );
      },
      skip: enabled ? false : 'Set BUSYMAX_CALDAV_LIVE=1 with the isolated Docker fixtures running.',
    );
  }
  for (final server in calDavQaTargets.entries) {
    test(
      '${server.key}: rejected creation in a read-only namespace survives restart without blocking event/task sync',
      () async {
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        Future<void> productionSync({bool full = false}) async {
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(f.database),
              secretStoreProvider.overrideWithValue(f.secrets),
              davAccountHttpClientProvider(f.id).overrideWithValue(f.client),
              networkConnectivityMonitorProvider.overrideWith((ref) {
                final monitor =
                    NetworkConnectivityMonitor.withoutPlatformObservation();
                ref.onDispose(monitor.dispose);
                return monitor;
              }),
              notificationReconcilerProvider.overrideWithValue(
                CallbackNotificationReconciler(() async {}),
              ),
            ],
          );
          try {
            await container
                .read(accountSyncOperationsProvider)
                .syncAccount(f.id, full: full);
            final activity = container.read(accountSyncActivityProvider);
            expect(activity.failure(f.id, 'dav'), isNull);
            final rejected =
                (await f.database
                        .select(f.database.davCollectionCreations)
                        .get())
                    .where((row) => row.state == 'rejected')
                    .toList();
            expect(
              activity.collectionCreationFailures(f.id).keys.toSet(),
              rejected.map((row) => row.id).toSet(),
            );
            expect(
              activity
                  .collectionCreationFailures(f.id)
                  .values
                  .every(
                    (notice) =>
                        !notice.pending && notice.error.statusCode == 403,
                  ),
              isTrue,
            );
          } finally {
            container.dispose();
          }
        }

        final restricted =
            (await f.database.select(f.database.davCollections).get())
                .singleWhere(
                  (c) =>
                      c.displayName == 'BusyMax QA restricted' ||
                      c.hrefKey.endsWith('/restricted/'),
                );
        final parent = Uri.parse(restricted.requestUri);
        // Model the selected creation namespace being read-only. The server's
        // real advertised privileges and real authenticated responses remain
        // authoritative; normal account discovery is restored by the sync below.
        for (final component in ['VEVENT', 'VTODO']) {
          await (f.database.update(
            f.database.davAccountServices,
          )..where((r) => r.accountId.equals(f.id))).write(
            DavAccountServicesCompanion(
              calendarHomeHref: Value(parent.toString()),
            ),
          );
          await expectLater(
            f.administration.create('${f.collectionName} denied $component', {
              component,
            }),
            throwsA(
              isA<DavException>().having(
                (e) => e.statusCode,
                'permission denial',
                403,
              ),
            ),
          );
          final rejected =
              (await f.database.select(f.database.davCollectionCreations).get())
                  .lastWhere(
                    (o) => o.displayName.endsWith('denied $component'),
                  );
          expect(rejected.state, 'rejected');
          expect(rejected.lastErrorStatus, 403);
          final absent = await f.independentRequest(
            'PROPFIND',
            Uri.parse(rejected.targetUri),
            headers: const {'Depth': '0', 'content-type': 'application/xml'},
            body: '<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>',
          );
          expect(absent.statusCode, anyOf(403, 404));
          debugPrint(
            '${server.key}: $component creation rejected 403; target probe ${absent.statusCode}; journal=rejected',
          );
          await f.reopen();
          await productionSync(full: true);
          expect(
            (await f.database.select(f.database.davCollectionCreations).get())
                .singleWhere((o) => o.id == rejected.id)
                .state,
            'rejected',
          );
        }
        for (var round = 1; round <= 3; round++) {
          for (final component in ['VEVENT', 'VTODO']) {
            final base = component == 'VEVENT'
                ? (f.createdEventCollectionUri ?? f.createdCollectionUri!)
                : f.createdCollectionUri!;
            final target = base.resolve('post-denial-$component.ics');
            final body =
                'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax//QA//EN\r\nBEGIN:$component\r\nUID:post-denial-$component-${f.collectionName}\r\nDTSTAMP:20261102T000000Z\r\nDTSTART:20261103T120000Z\r\nSUMMARY:After denial $round $component\r\nEND:$component\r\nEND:VCALENDAR\r\n';
            final response = await f.independentRequest(
              'PUT',
              target,
              headers: const {'content-type': 'text/calendar'},
              body: body,
            );
            expect(response.statusCode, anyOf(201, 204));
            expect(
              (await f.independentRequest('GET', target)).body,
              contains('After denial $round $component'),
            );
          }
          await productionSync();
          expect(
            (await f.database.select(f.database.calendarEvents).get()).any(
              (e) => e.title == 'After denial $round VEVENT',
            ),
            isTrue,
          );
          expect(
            (await f.database.select(f.database.tasks).get()).any(
              (t) => t.title == 'After denial $round VTODO',
            ),
            isTrue,
          );
          final objects = (await f.database.select(f.database.davObjects).get())
              .where((o) => o.requestUri.contains('/post-denial-'));
          expect(objects.length, 2);
          expect(objects.every((o) => o.etag?.isNotEmpty == true), isTrue);
          expect(
            (await f.database.select(f.database.accounts).getSingle())
                .authState,
            'signed_in',
          );
        }
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: live TLS, origin protection, response budgets and XML limits',
      () async {
        final credentials = await calDavQaCredentials(Uri.parse(server.value));
        final authority = Uri.parse(server.value);
        final tls = SecurityContext(withTrustedRoots: true)
          ..setTrustedCertificates('test/interop/caldav/.runtime/ca.pem');
        final client = _RecordingClient(IOClient(HttpClient(context: tls)));
        addTearDown(client.close);
        final credential = DavBasicCredential(
          username: 'alice',
          password: credentials['alice'] as String,
        );
        final profile = davProviderProfile(
          BusyProvider.caldav,
          caldavServer: authority,
        );
        final transport = DavHttpTransport(
          client: client,
          profile: profile,
          accountAuthority: authority,
        );
        for (final path in ['cross-origin', 'downgrade']) {
          await expectLater(
            transport.send(
              DavRequest(
                method: 'PROPFIND',
                uri: authority.resolve('/security/$path'),
                accountId: 'security',
                correlationId: 'security-$path',
                redirectPolicy: DavRedirectPolicy.discovery,
              ),
              credential: credential,
            ),
            throwsA(
              isA<DavException>().having(
                (e) => e.kind,
                'kind',
                DavErrorKind.redirectRejected,
              ),
            ),
          );
        }
        expect(
          client.targets.every((uri) => uri.origin == authority.origin),
          isTrue,
        );
        final untrusted = Uri.parse('https://localhost:18446/');
        final untrustedProfile = davProviderProfile(
          BusyProvider.caldav,
          caldavServer: untrusted,
        );
        await expectLater(
          DavHttpTransport(
            client: client,
            profile: untrustedProfile,
            accountAuthority: untrusted,
          ).send(
            DavRequest(
              method: 'PROPFIND',
              uri: untrusted,
              accountId: 'security',
              correlationId: 'invalid-tls',
            ),
            credential: credential,
          ),
          throwsA(
            isA<DavException>().having((e) => e.kind, 'kind', DavErrorKind.tls),
          ),
        );
        // Trust that fixture certificate only in a second private context so
        // hostname rejection is exercised independently of chain rejection.
        final wrongHostContext = SecurityContext(
          withTrustedRoots: false,
        )..setTrustedCertificates('test/interop/caldav/.runtime/untrusted.pem');
        final wrongHostClient = IOClient(HttpClient(context: wrongHostContext));
        addTearDown(wrongHostClient.close);
        await expectLater(
          DavHttpTransport(
            client: wrongHostClient,
            profile: untrustedProfile,
            accountAuthority: untrusted,
          ).send(
            DavRequest(
              method: 'PROPFIND',
              uri: untrusted,
              accountId: 'security',
              correlationId: 'invalid-tls-hostname',
            ),
            credential: credential,
          ),
          throwsA(
            isA<DavException>().having((e) => e.kind, 'kind', DavErrorKind.tls),
          ),
        );
        final request = DavRequest.xml(
          method: 'PROPFIND',
          uri: authority,
          accountId: 'security',
          correlationId: 'bounded-xml',
          headers: const {'Depth': '0'},
          body: '<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>',
        );
        await expectLater(
          DavHttpTransport(
            client: client,
            profile: profile,
            accountAuthority: authority,
            limits: const DavTransportLimits(maximumResponseBytes: 64),
          ).send(request, credential: credential),
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'kind',
              DavErrorKind.responseTooLarge,
            ),
          ),
        );
        final response = await transport.send(request, credential: credential);
        expect(
          () =>
              const DavXmlParser(limits: DavXmlLimits(maximumDepth: 2))
                  .parseMultistatus(response.bodyBytes),
          throwsA(isA<DavException>()),
        );
        for (final user in ['alice', 'unknown-user']) {
          final rejected = await transport.send(
            request,
            credential: DavBasicCredential(
              username: user,
              password: 'invalid-qa-password',
            ),
          );
          expect(rejected.statusCode, 401);
        }
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: recurring task completion advances the master and retains completed occurrence history',
      () async {
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        final target = f.createdCollectionUri!.resolve(
          'recurring-completion.ics',
        );
        const body =
            'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Independent BusyMax QA//EN\r\n'
            'BEGIN:VTODO\r\nUID:recurring-completion@example.invalid\r\nDTSTAMP:20261102T000000Z\r\n'
            'DUE;VALUE=DATE:20261103\r\nRRULE:FREQ=DAILY;COUNT=3\r\nSTATUS:NEEDS-ACTION\r\n'
            'SUMMARY:Recurring completion\r\nX-COMPLETION:preserve\r\nEND:VTODO\r\nEND:VCALENDAR\r\n';
        expect(
          (await f.independentRequest(
            'PUT',
            target,
            body: body,
            headers: const {
              'content-type': 'text/calendar',
              'if-none-match': '*',
            },
          )).statusCode,
          201,
        );
        await f.synchronize();
        final task = (await f.database.select(f.database.tasks).get())
            .singleWhere((t) => t.davCollectionId == f.collectionId);
        await f.tasks.patchTask(
          task.taskListId,
          task.id,
          TaskPatchInput.completion(true),
        );
        await f.reopen();
        await f.synchronize();
        final remote = await f.independentRequest('GET', target);
        expect(remote.statusCode, 200);
        final document = IcalSemanticDocument.parse(remote.body);
        final master = document.components.singleWhere(
          (c) => c.recurrenceId == null,
        );
        final history = document.components.singleWhere(
          (c) => c.recurrenceId != null,
        );
        expect(master.due!.rawValue, '20261104');
        expect(master.recurrenceRules, ['FREQ=DAILY;COUNT=2']);
        expect(history.status, 'COMPLETED');
        expect(history.completed, isNotNull);
        expect(remote.body, contains('X-COMPLETION:preserve'));
        expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
        final current = (await f.database.select(f.database.tasks).get())
            .singleWhere((t) => t.id == task.id);
        expect(current.status, 'needsAction');
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: UID collision probe records upstream behavior and preserves the original',
      () async {
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        final list = (await f.database.select(f.database.taskLists).get())
            .singleWhere((l) => l.davCollectionId == f.collectionId);
        await f.tasks.createTask(
          list.id,
          const TaskCreateInput(title: 'UID original'),
        );
        await f.synchronize();
        final object = (await f.database.select(f.database.davObjects).get())
            .singleWhere((o) => o.collectionId == f.collectionId);
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
          collectionId: f.collectionId!,
          credential: DavBasicCredential(
            username: f.username,
            password: f.password,
          ),
        );
        final duplicate = f.createdCollectionUri!.resolve('duplicate-uid.ics');
        try {
          final response = await remote.conditionalPut(
            uri: duplicate,
            rawIcs: object.rawIcsBody,
            correlationId: 'live-no-uid-conflict',
            ifNoneMatch: true,
          );
          expect(response.status, DavConditionalStatus.success);
          expect(
            (await f.independentRequest('GET', duplicate)).body,
            object.rawIcsBody,
          );
          // This is an upstream compliance observation, not an advertised
          // BusyMax operation. Import deduplication is qualified separately.
          debugPrint(
            'BUSYMAX_CALDAV_UPSTREAM_UID_NOT_ENFORCED ${server.key} ${response.statusCode}',
          );
          expect(
            (await f.independentRequest('DELETE', duplicate)).statusCode,
            anyOf(200, 204),
          );
        } on DavException catch (error) {
          expect(error.kind, DavErrorKind.uidConflict);
          debugPrint(
            'BUSYMAX_CALDAV_UPSTREAM_UID_REJECTED ${server.key} ${error.statusCode}',
          );
        }
        expect(
          (await f.independentRequest(
            'GET',
            Uri.parse(object.requestUri),
          )).body,
          object.rawIcsBody,
        );
        expect((await f.independentRequest('GET', duplicate)).statusCode, 404);
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: account removal during active synchronization cannot resurrect account data or credentials',
      () async {
        final barrier = _ResponseBarrier();
        final f = CalDavFixture(
          Uri.parse(server.value),
          wrapAccountClient: (client) => _BarrierClient(client, barrier),
        );
        await f.open();
        addTearDown(f.close);
        barrier.method = 'REPORT';
        Object? synchronizationFailure;
        final sync = f.synchronize(full: true).catchError((Object error) {
          synchronizationFailure = error;
        });
        await barrier.started.future;
        var removed = false;
        final removal = f.onboarding
            .removeAccount(f.id)
            .then((_) => removed = true);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          removed,
          isFalse,
        ); // Authorization writer waits for the active lease.
        barrier.release.complete();
        await removal;
        await sync;
        if (synchronizationFailure != null) {
          expect(
            synchronizationFailure,
            anyOf(isA<DavAccountSyncException>(), isA<DavException>()),
          );
        }
        expect(await f.database.select(f.database.accounts).get(), isEmpty);
        expect(await f.database.select(f.database.davObjects).get(), isEmpty);
        expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
        expect(await f.secrets.readCredential(f.id), isNull);
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: cancellation during real credential validation preserves the active generation',
      () async {
        final barrier = _ResponseBarrier();
        final f = CalDavFixture(
          Uri.parse(server.value),
          wrapDiscoveryClient: (client) => _BarrierClient(client, barrier),
        );
        await f.open();
        addTearDown(f.close);
        final generation = await f.persistence.generation(f.id);
        barrier.method = 'PROPFIND';
        final cancellation = DavCancellationToken();
        final pending = f.onboarding.replaceCalDavPassword(
          accountId: f.id,
          password: f.password,
          cancellationToken: cancellation,
        );
        final rejected = expectLater(
          pending,
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'kind',
              DavErrorKind.cancelled,
            ),
          ),
        );
        try {
          await barrier.started.future;
          cancellation.cancel();
          await rejected.timeout(const Duration(seconds: 5));
          expect(barrier.release.isCompleted, isFalse);
          expect(await f.persistence.generation(f.id), generation);
          expect(
            await f.database.select(f.database.accounts).get(),
            hasLength(1),
          );
        } finally {
          barrier.release.complete();
        }
        await f.synchronize();
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: two accounts isolate credential leases and removing one preserves the other',
      () async {
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        final credentials = await calDavQaCredentials(
          f.uri,
          directory: f.fixtureDirectory,
        );
        final bob = (await f.onboarding.connectCalDav(
          serverUrl: server.value,
          username: 'bob',
          password: credentials['bob'] as String,
        )).accountId;
        final aliceSecret = (await f.persistence.readCurrentCredential(f.id))!
            .toJson();
        var dispatches = 0;
        final client = DavAccountHttpClient(
          accountId: bob,
          persistence: f.persistence,
          createClient: (_) {
            dispatches++;
            return f.newClient();
          },
        );
        addTearDown(client.close);
        final wrong = http.Request('GET', f.createdCollectionUri!)
          ..headers['authorization'] =
              'Basic ${base64Encode(utf8.encode('alice:${f.password}'))}';
        await expectLater(
          client.send(wrong),
          throwsA(isA<SecretStoreException>()),
        );
        expect(dispatches, 0);
        final valid = http.Request('PROPFIND', f.uri)
          ..headers.addAll({
            'authorization':
                'Basic ${base64Encode(utf8.encode('bob:${credentials['bob']}'))}',
            'Depth': '0',
          })
          ..body =
              '<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>';
        final response = await http.Response.fromStream(
          await client.send(valid),
        );
        expect(response.statusCode, 207);
        final bobService =
            (await f.database.select(f.database.davAccountServices).get())
                .singleWhere((s) => s.accountId == bob);
        final principal = XmlDocument.parse(response.body)
            .findAllElements('current-user-principal', namespaceUri: 'DAV:')
            .single
            .findElements('href', namespaceUri: 'DAV:')
            .single
            .innerText;
        expect(f.uri.resolve(principal), Uri.parse(bobService.principalHref!));
        expect(dispatches, 1);
        final list = (await f.database.select(f.database.taskLists).get())
            .singleWhere((l) => l.davCollectionId == f.collectionId);
        await f.tasks.createTask(
          list.id,
          const TaskCreateInput(title: 'Alice private task'),
        );
        await f.synchronize();
        final object = (await f.database.select(f.database.davObjects).get())
            .singleWhere((o) => o.collectionId == f.collectionId);
        final privateRequest = http.Request('GET', Uri.parse(object.requestUri))
          ..headers['authorization'] =
              'Basic ${base64Encode(utf8.encode('bob:${credentials['bob']}'))}';
        expect(
          (await http.Response.fromStream(await client.send(privateRequest)))
              .statusCode,
          anyOf(403, 404),
        );
        await f.onboarding.removeAccount(bob);
        expect(
          (await f.database.select(f.database.accounts).getSingle()).id,
          f.id,
        );
        expect(
          (await f.persistence.readCurrentCredential(f.id))!.toJson(),
          aliceSecret,
        );
        expect(await f.secrets.readCredential(bob), isNull);
        await f.synchronize();
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: server-side collection deletion retains cached resources and unresolved edits',
      () async {
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        final list = (await f.database.select(f.database.taskLists).get())
            .singleWhere((l) => l.davCollectionId == f.collectionId);
        await f.tasks.createTask(
          list.id,
          const TaskCreateInput(title: 'Remote collection deletion baseline'),
        );
        await f.synchronize();
        final task = (await f.database.select(f.database.tasks).get())
            .singleWhere((t) => t.davCollectionId == f.collectionId);
        final raw = (await f.database.select(f.database.davObjects).get())
            .singleWhere((o) => o.id == task.davObjectId);
        await f.tasks.patchTask(
          list.id,
          task.id,
          const TaskPatchInput({'title': 'Unresolved edit must survive'}),
        );
        expect(
          (await f.independentRequest(
            'DELETE',
            f.createdCollectionUri!,
          )).statusCode,
          anyOf(200, 204),
        );
        try {
          await f.synchronize(full: true);
        } on DavAccountSyncException {
          /* The server rejection remains visible. */
        }
        expect(
          await f.database.select(f.database.pendingOps).get(),
          hasLength(1),
        );
        expect(
          (await f.database.select(f.database.davObjects).get())
              .singleWhere((o) => o.id == raw.id)
              .rawIcsBody,
          raw.rawIcsBody,
        );
        expect(
          (await f.database.select(f.database.davCollections).get())
              .singleWhere((c) => c.id == f.collectionId)
              .serverMissing,
          isTrue,
        );
        await f.reopen();
        expect(
          await f.database.select(f.database.pendingOps).get(),
          hasLength(1),
        );
        expect(
          (await f.database.select(f.database.tasks).get()).any(
            (t) => t.id == task.id,
          ),
          isTrue,
        );
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: absent optional ACL permits a guarded attempt while real 403 preserves queued data',
      () async {
        final f = CalDavFixture(
          Uri.parse(server.value),
          wrapAccountClient: _AbsentAclClient.new,
        );
        await f.open();
        addTearDown(f.close);
        final restricted =
            (await f.database.select(f.database.davCollections).get())
                .singleWhere(
                  (c) =>
                      c.hrefKey.endsWith('/restricted/') ||
                      c.displayName == 'BusyMax QA restricted',
                );
        final caps = collectionCapabilitiesFromStored(restricted);
        expect(caps.permissionsKnown, isFalse);
        expect(caps.canRead, isTrue);
        expect(caps.canWriteContent, isFalse);
        expect(caps.canAttemptCreateTask, isTrue);
        final list = (await f.database.select(f.database.taskLists).get())
            .singleWhere((l) => l.davCollectionId == restricted.id);
        await f.tasks.createTask(
          list.id,
          const TaskCreateInput(title: 'Denied task stays local'),
        );
        await expectLater(
          f.synchronize(),
          throwsA(
            isA<DavAccountSyncException>().having(
              (e) =>
                  e.failures.any((f) => f.kind == DavErrorKind.authorization),
              'authorization failure',
              isTrue,
            ),
          ),
        );
        final pending = await f.database
            .select(f.database.pendingOps)
            .getSingle();
        expect(pending.state, 'permission_blocked');
        expect(pending.requestJson, contains('Denied task stays local'));
        expect(
          (await f.database.select(f.database.tasks).get()).any(
            (t) => t.title == 'Denied task stays local',
          ),
          isTrue,
        );
        expect(
          (await f.database.select(f.database.accounts).getSingle()).authState,
          'permission_changed',
        );
        await f.reopen();
        expect(
          await f.database.select(f.database.pendingOps).getSingle(),
          pending,
        );
        final inventory = await f.independentRequest(
          'PROPFIND',
          Uri.parse(restricted.requestUri),
          headers: const {'Depth': '1'},
          body: '<d:propfind xmlns:d="DAV:"><d:prop><d:getetag/></d:prop></d:propfind>',
        );
        expect(inventory.statusCode, 207);
        expect(inventory.body, isNot(contains('.ics')));
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: native event/task import/export preserves complete resources and duplicate identity',
      () async {
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        final preview = NextcloudNativeImportPreview.parse(
          IcalDocument.parse(
            _bulkItem(10000).replaceFirst(
              'END:VCALENDAR',
              'BEGIN:VTODO\r\nUID:import-task@example.invalid\r\nDTSTAMP:20261102T000000Z\r\nSUMMARY:Imported task\r\n'
                  'DTSTART;VALUE=DATE:20261103\r\nDUE;VALUE=DATE:20261104\r\nRRULE:FREQ=DAILY;COUNT=3\r\n'
                  'RDATE;VALUE=DATE:20261106\r\nEXDATE;VALUE=DATE:20261104\r\n'
                  'CATEGORIES:Unicode café,日本語\r\nX-IMPORT;X-UNKNOWN=exact:preserve\r\nEND:VTODO\r\n'
                  'BEGIN:VTODO\r\nUID:import-task@example.invalid\r\nDTSTAMP:20261102T000000Z\r\n'
                  'RECURRENCE-ID;VALUE=DATE:20261105\r\nDTSTART;VALUE=DATE:20261105\r\nDUE;VALUE=DATE:20261107\r\n'
                  'SUMMARY:Modified task occurrence\r\nX-EXCEPTION:preserve\r\nEND:VTODO\r\nEND:VCALENDAR',
            ),
          ),
        );
        final imported = await f.importResources(preview);
        expect(
          imported.map((i) => i.status),
          everyElement(NativeImportItemStatus.queued),
        );
        expect(imported, hasLength(2));
        final offline = await f.exportResources();
        expect(offline, hasLength(2));
        expect(
          offline.singleWhere((r) => r.componentType == 'VTODO').rawIcs,
          contains('X-IMPORT;X-UNKNOWN=exact:preserve'),
        );
        await f.reopen();
        await f.synchronize();
        expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
        final task = (await f.database.select(f.database.tasks).get())
            .singleWhere(
              (t) =>
                  t.davCollectionId == f.collectionId &&
                  t.recurrenceIdKey == null,
            );
        await f.tasks.patchTask(
          task.taskListId,
          task.id,
          const TaskPatchInput({'title': 'Edited recurrence master'}),
        );
        await f.synchronize();
        final duplicates = await f.importResources(preview);
        expect(
          duplicates.map((i) => i.status),
          everyElement(NativeImportItemStatus.duplicate),
        );
        final export = await f.exportResources();
        expect(export, hasLength(2));
        final exportedTask = export
            .singleWhere((r) => r.componentType == 'VTODO')
            .rawIcs;
        expect(exportedTask, contains('SUMMARY:Edited recurrence master'));
        expect(exportedTask, contains('RDATE;VALUE=DATE:20261106'));
        expect(exportedTask, contains('EXDATE;VALUE=DATE:20261104'));
        expect(exportedTask, contains('RECURRENCE-ID;VALUE=DATE:20261105'));
        expect(exportedTask, contains('X-EXCEPTION:preserve'));
        for (final object
            in (await f.database.select(f.database.davObjects).get()).where(
              (o) => o.collectionId == f.collectionId,
            )) {
          final remote = await f.independentRequest(
            'GET',
            Uri.parse(object.requestUri),
          );
          expect(remote.statusCode, 200);
          expect(
            remote.body,
            export.singleWhere((r) => r.uid == object.primaryUid).rawIcs,
          );
        }
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: real password rotation and server restart preserve queued work and account identity',
      () async {
        final serverName = server.key.startsWith('Radicale')
            ? 'radicale'
            : server.key.startsWith('BusyStack')
            ? 'busystack'
            : 'baikal';
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        final oldPassword = f.password;
        final generation = await f.persistence.generation(f.id);
        final list = (await f.database.select(f.database.taskLists).get())
            .singleWhere((l) => l.davCollectionId == f.collectionId);
        await f.tasks.createTask(
          list.id,
          const TaskCreateInput(title: 'Before server restart'),
        );
        await f.synchronize();
        final task = (await f.database.select(f.database.tasks).get())
            .singleWhere((t) => t.davCollectionId == f.collectionId);
        await f.tasks.patchTask(
          list.id,
          task.id,
          const TaskPatchInput({'title': 'Queued across restart'}),
        );
        await _control('restart', serverName);
        await _ready(f);
        await f.reopen();
        await f.synchronize();
        expect(
          (await f.database.select(f.database.tasks).get())
              .singleWhere((t) => t.id == task.id)
              .title,
          'Queued across restart',
        );
        expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
        await f.tasks.patchTask(
          list.id,
          task.id,
          const TaskPatchInput({'title': 'Queued across password replacement'}),
        );
        try {
          await _control('rotate', serverName);
          // Restarted servers must accept the connection before testing the old
          // password's authoritative 401 response.
          final replacement = jsonDecode(
            await File('test/interop/caldav/.runtime/rotation-$serverName.json')
                .readAsString(),
          ) as Map;
          f.password = replacement['password'] as String;
          await _ready(f);
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
                .singleWhere((t) => t.id == task.id)
                .title,
            'Queued across password replacement',
          );
          final reconnected = await f.onboarding.replaceCalDavPassword(
            accountId: f.id,
            password: f.password,
          );
          expect(reconnected.accountId, f.id);
          expect(await f.persistence.generation(f.id), generation + 1);
          await f.reopen();
          await f.synchronize();
          expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
          final object = (await f.database.select(f.database.davObjects).get())
              .singleWhere((o) => o.id == task.davObjectId);
          expect(
            (await f.independentRequest(
              'GET',
              Uri.parse(object.requestUri),
            )).body,
            contains('SUMMARY:Queued across password replacement'),
          );
        } finally {
          if (serverName != 'busystack') {
            await _control('restore', serverName);
            f.password = oldPassword;
            await _ready(f);
          }
        }
      },
      skip: lifecycle ? false : 'Set BUSYMAX_CALDAV_LIFECYCLE=1; changes/restarts only the isolated fixtures. Run without other live tests.',
      timeout: const Timeout(Duration(minutes: 5)),
    );
    test(
      '${server.key}: large inventory converges using sync tokens and forced ETag fallback',
      () async {
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        const count = 240;
        final base = f.createdCollectionUri!;
        for (var start = 0; start < count; start += 3) {
          await Future.wait([
            for (var i = start; i < start + 3; i++)
              f
                  .independentRequest(
                    'PUT',
                    base.resolve('bulk-$i.ics'),
                    body: _bulkItem(
                      i,
                      onlyComponent: calDavQaSupportsMixed(f.uri)
                          ? null
                          : 'VTODO',
                    ),
                    headers: const {
                      'content-type': 'text/calendar; charset=utf-8',
                      'if-none-match': '*',
                    },
                  )
                  .then((r) => expect(r.statusCode, 201)),
          ]);
        }
        await f.synchronize();
        expect(
          (await f.database.select(f.database.davObjects).get()).where(
            (o) => o.collectionId == f.collectionId && !o.serverDeleted,
          ),
          hasLength(count),
        );
        expect(
          (await f.database.select(f.database.calendarEvents).get()).where(
            (e) => e.davCollectionId == f.collectionId,
          ),
          hasLength(calDavQaSupportsMixed(f.uri) ? count ~/ 2 : 0),
        );
        expect(
          (await f.database.select(f.database.tasks).get()).where(
            (t) => t.davCollectionId == f.collectionId,
          ),
          hasLength(calDavQaSupportsMixed(f.uri) ? count ~/ 2 : count),
        );
        await f.reopen();
        final c = (await f.database.select(f.database.davCollections).get())
            .singleWhere((c) => c.id == f.collectionId);
        final reports =
            (jsonDecode(c.supportedReportsJson) as List).cast<String>()
              ..remove('{DAV:}sync-collection');
        await (f.database.update(
          f.database.davCollections,
        )..where((r) => r.id.equals(c.id))).write(
          DavCollectionsCompanion(
            supportedReportsJson: Value(jsonEncode(reports)),
          ),
        );
        final profile = davProviderProfile(
          BusyProvider.caldav,
          caldavServer: f.uri,
        );
        final remote = DavCollectionHttpClient(
          transport: DavHttpTransport(
            client: f.client,
            profile: profile,
            accountAuthority: f.uri,
          ),
          profile: profile,
          accountAuthority: f.uri,
          accountId: f.id,
          collectionId: c.id,
          collectionUri: base,
          credential: DavBasicCredential(
            username: f.username,
            password: f.password,
          ),
        );
        final fallback = DavSyncEngine(
          database: f.database,
          objectRepository: DavObjectRepository(database: f.database),
          remoteClient: remote,
          accountId: f.id,
          collectionId: c.id,
          provider: BusyProvider.caldav,
          limits: const DavSyncLimits(maximumMembersPerMultiget: 17),
        );
        final baseline = await fallback.synchronize(
          correlationId: 'live-forced-etag',
        );
        expect(baseline.usedSyncCollection, isFalse);
        expect(baseline.membersSeen, count);
        final current = await f.independentRequest(
          'GET',
          base.resolve('bulk-0.ics'),
        );
        expect(
          (await f.independentRequest(
            'PUT',
            base.resolve('bulk-0.ics'),
            body: current.body.replaceFirst(
              'SUMMARY:Bulk 0',
              'SUMMARY:Remote bulk update',
            ),
            headers: {
              'content-type': 'text/calendar',
              'if-match': current.headers['etag']!,
            },
          )).statusCode,
          anyOf(201, 204),
        );
        expect(
          (await f.independentRequest(
            'DELETE',
            base.resolve('bulk-1.ics'),
          )).statusCode,
          anyOf(200, 204),
        );
        expect(
          (await f.independentRequest(
            'PUT',
            base.resolve('bulk-$count.ics'),
            body: _bulkItem(
              count,
              onlyComponent: calDavQaSupportsMixed(f.uri) ? null : 'VTODO',
            ),
            headers: const {
              'content-type': 'text/calendar',
              'if-none-match': '*',
            },
          )).statusCode,
          201,
        );
        final delta = await fallback.synchronize(
          correlationId: 'live-etag-delta',
        );
        expect(delta.usedSyncCollection, isFalse);
        expect(delta.objectsFetched, 2);
        expect(
          (await f.database.select(f.database.davObjects).get())
              .singleWhere(
                (o) =>
                    o.collectionId == c.id &&
                    o.requestUri == base.resolve('bulk-1.ics').toString(),
              )
              .serverDeleted,
          isTrue,
        );
        final updatedTitles = [
          ...(await f.database.select(f.database.calendarEvents).get())
              .where((e) => e.davCollectionId == f.collectionId)
              .map((e) => e.title),
          ...(await f.database.select(f.database.tasks).get())
              .where((t) => t.davCollectionId == f.collectionId)
              .map((t) => t.title),
        ];
        expect(updatedTitles, contains('Remote bulk update'));
        expect(
          (await f.database.select(f.database.davObjects).get()).where(
            (o) => o.collectionId == c.id && !o.serverDeleted,
          ),
          hasLength(count),
        );
        await f.synchronize(); // Restore actual advertised sync-collection and converge again.
        expect(
          (await f.database.select(f.database.davObjects).get()).where(
            (o) => o.collectionId == c.id && !o.serverDeleted,
          ),
          hasLength(count),
        );
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
      timeout: const Timeout(Duration(minutes: 5)),
    );
    test(
      '${server.key}: committed writes with lost responses reconcile without duplicate mutation',
      () async {
        final faults = _LostResponses();
        final f = CalDavFixture(
          Uri.parse(server.value),
          wrapAccountClient: (client) => _LossClient(client, faults),
        );
        await f.open();
        addTearDown(f.close);
        final list = (await f.database.select(f.database.taskLists).get())
            .singleWhere((l) => l.davCollectionId == f.collectionId);
        faults.arm('PUT');
        await f.tasks.createTask(
          list.id,
          const TaskCreateInput(title: 'Lost create response'),
        );
        await f.synchronize();
        expect(faults.lost, 1);
        expect(faults.mutationCalls, 1);
        expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
        var task = (await f.database.select(f.database.tasks).get())
            .singleWhere((t) => t.davCollectionId == f.collectionId);
        final object = (await f.database.select(f.database.davObjects).get())
            .singleWhere((o) => o.id == task.davObjectId);
        expect(
          (await f.independentRequest(
            'GET',
            Uri.parse(object.requestUri),
          )).body,
          contains('SUMMARY:Lost create response'),
        );
        faults.arm('PUT');
        await f.tasks.patchTask(
          list.id,
          task.id,
          const TaskPatchInput({'title': 'Lost update response'}),
        );
        await f.reopen();
        await f.synchronize();
        expect(faults.lost, 1);
        expect(faults.mutationCalls, 1);
        expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
        expect(
          (await f.independentRequest(
            'GET',
            Uri.parse(object.requestUri),
          )).body,
          contains('SUMMARY:Lost update response'),
        );
        task = (await f.database.select(f.database.tasks).get()).singleWhere(
          (t) => t.davCollectionId == f.collectionId,
        );
        faults.arm('DELETE');
        await f.tasks.deleteTask(list.id, task.id);
        await f.synchronize();
        expect(faults.lost, 1);
        expect(faults.mutationCalls, 1);
        expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
        expect(
          (await f.independentRequest(
            'GET',
            Uri.parse(object.requestUri),
          )).statusCode,
          404,
        );
        for (final method in ['MKCALENDAR', 'PROPPATCH', 'DELETE']) {
          faults.arm(method);
          if (method == 'MKCALENDAR') {
            expect(
              await f.administration.create('${f.collectionName}-lost', const {
                'VTODO',
              }),
              DavCollectionAdministrationOutcome.reconciled,
            );
          } else {
            final collection =
                (await f.database.select(f.database.davCollections).get())
                    .singleWhere(
                      (c) => c.displayName == '${f.collectionName}-lost',
                    );
            if (method == 'PROPPATCH') {
              expect(
                await f.administration.update(collection.id, {
                  const DavPropertyName(
                    caldavNamespace,
                    'calendar-description',
                  ): 'Lost property response',
                }),
                DavCollectionAdministrationOutcome.committed,
              );
            } else {
              expect(
                await f.administration.remove(collection.id),
                DavCollectionAdministrationOutcome.committed,
              );
            }
          }
          expect(faults.lost, 1);
          expect(faults.mutationCalls, 1);
        }
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
      timeout: const Timeout(Duration(minutes: 5)),
    );
    test(
      '${server.key}: collection component sets, metadata, guarded task hierarchy movement and deletion',
      () async {
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        final other = <String>[];
        try {
          for (final components in [
            const {'VEVENT'},
            const {'VTODO'},
            if (calDavQaSupportsMixed(f.uri)) const {'VEVENT', 'VTODO'},
          ]) {
            final name = '${f.collectionName}-${components.join('-')}';
            expect(
              await f.administration.create(name, components),
              DavCollectionAdministrationOutcome.committed,
            );
            final c = (await f.database.select(f.database.davCollections).get())
                .singleWhere((c) => c.displayName == name);
            other.add(c.id);
            expect(c.eventProjectionEnabled, components.contains('VEVENT'));
            expect(c.taskProjectionEnabled, components.contains('VTODO'));
            expect(
              await f.administration.update(c.id, {
                const DavPropertyName(caldavNamespace, 'calendar-description'):
                    'Unicode café 日本語',
                const DavPropertyName(appleIcalNamespace, 'calendar-color'):
                    '#AABBCCFF',
              }),
              DavCollectionAdministrationOutcome.committed,
            );
          }
          final sourceList =
              (await f.database.select(f.database.taskLists).get()).singleWhere(
                (l) => l.davCollectionId == f.collectionId,
              );
          final destination =
              (await f.database.select(f.database.taskLists).get()).singleWhere(
                (l) => l.davCollectionId == other[1],
              );
          final parent = await f.tasks.createTask(
            sourceList.id,
            const TaskCreateInput(title: 'Move parent'),
          );
          await f.tasks.createTask(
            sourceList.id,
            TaskCreateInput(title: 'Move child', parentTaskId: parent),
          );
          await f.synchronize();
          final tasks = (await f.database.select(f.database.tasks).get())
              .where((t) => t.davCollectionId == f.collectionId)
              .toList();
          final parentTask = tasks.singleWhere((t) => t.title == 'Move parent');
          final before = (await f.database.select(f.database.davObjects).get())
              .where((o) => o.collectionId == f.collectionId)
              .toList();
          await f.tasks.moveTask(
            TaskMoveInput(
              sourceTaskListId: sourceList.id,
              taskId: parentTask.id,
              destinationTaskListId: destination.id,
            ),
          );
          await f.reopen();
          await f.synchronize();
          final moved = (await f.database.select(f.database.tasks).get())
              .where((t) => t.davCollectionId == other[1] && t.deleted != true)
              .toList();
          expect(moved, hasLength(2));
          expect(
            moved.singleWhere((t) => t.title == 'Move child').parent,
            moved.singleWhere((t) => t.title == 'Move parent').id,
          );
          for (final old in before) {
            expect(
              (await f.independentRequest(
                'GET',
                Uri.parse(old.requestUri),
              )).statusCode,
              404,
            );
          }
          expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
        } finally {
          for (final id in other.reversed) {
            await f.administration.remove(id);
          }
        }
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
      timeout: const Timeout(Duration(minutes: 5)),
    );
    test(
      '${server.key}: bad credentials and rejected reconnect preserve cached state and active generation',
      () async {
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        final generation = await f.persistence.generation(f.id);
        final inventory =
            (await f.database.select(f.database.davCollections).get())
                .map((c) => c.id)
                .toSet();
        await expectLater(
          f.onboarding.replaceCalDavPassword(
            accountId: f.id,
            password: 'invalid-qa-password',
          ),
          throwsA(
            isA<DavException>().having(
              (e) => e.kind,
              'kind',
              DavErrorKind.authentication,
            ),
          ),
        );
        expect(await f.persistence.generation(f.id), generation);
        expect(
          (await f.persistence.readCurrentCredential(
            f.id,
          ) as CalDavSecretRecord).password,
          f.password,
        );
        expect(
          (await f.database.select(f.database.davCollections).get())
              .map((c) => c.id)
              .toSet(),
          inventory,
        );
        await f.reopen();
        await f.synchronize();
      },
      skip: enabled ? false : 'Requires isolated HTTPS Docker fixtures.',
    );
    test(
      '${server.key}: BusyMax account/repositories converge across offline work and application database restart',
      () async {
        final f = CalDavFixture(Uri.parse(server.value));
        await f.open();
        addTearDown(f.close);
        var source = (await f.database.select(f.database.calendarSources).get())
            .singleWhere((s) => s.davCollectionId == f.eventCollectionId);
        var list = (await f.database.select(f.database.taskLists).get())
            .singleWhere((s) => s.davCollectionId == f.collectionId);
        await f.calendars.createLocalEvent(
          EventEditorDraft.newEvent(
            accountId: f.id,
            sourceId: source.id,
            providerCalendarId: source.providerCalendarId,
            start: DateTime(2027, 3, 14, 9),
            end: DateTime(2027, 3, 14, 10),
          ).copyWith(
            title: 'BusyMax café 日本語',
            description: 'Preserved description',
            location: 'Room 1',
          ),
        );
        await f.tasks.createTask(
          list.id,
          const TaskCreateInput(
            title: 'BusyMax task',
            fields: {'microsoftDueDateTime': '2027-03-15', 'priority': 3},
          ),
        );
        expect(
          await f.database.select(f.database.pendingOps).get(),
          hasLength(2),
        );
        await f.reopen();
        expect(
          await f.database.select(f.database.pendingOps).get(),
          hasLength(2),
        );
        await f.synchronize();
        expect(await f.database.select(f.database.pendingOps).get(), isEmpty);
        var event = (await f.database.select(f.database.calendarEvents).get())
            .singleWhere((e) => e.davCollectionId == f.eventCollectionId);
        var task = (await f.database.select(f.database.tasks).get())
            .singleWhere((t) => t.davCollectionId == f.collectionId);
        final eventObject =
            (await f.database.select(f.database.davObjects).get()).singleWhere(
              (o) => o.id == event.davObjectId,
            );
        final taskObject =
            (await f.database.select(f.database.davObjects).get()).singleWhere(
              (o) => o.id == task.davObjectId,
            );
        final eventUri = Uri.parse(eventObject.requestUri),
            taskUri = Uri.parse(taskObject.requestUri);
        final remoteEvent = await f.independentRequest('GET', eventUri);
        final remoteTask = await f.independentRequest('GET', taskUri);
        expect(remoteEvent.statusCode, 200);
        expect(remoteTask.statusCode, 200);
        expect(remoteEvent.body, contains('SUMMARY:BusyMax café 日本語'));
        expect(remoteTask.body, contains('DUE;VALUE=DATE:20270315'));
        final eventChanged = remoteEvent.body
            .replaceFirst(
              'SUMMARY:BusyMax café 日本語',
              'SUMMARY:Independent change',
            )
            .replaceFirst(
              'END:VEVENT',
              'ATTENDEE;CN=Guest:mailto:guest@example.test\r\nORGANIZER:mailto:alice@example.test\r\nX-ROUNDTRIP;X-OPAQUE=exact:value\r\nEND:VEVENT',
            );
        final taskChanged = remoteTask.body
            .replaceFirst('SUMMARY:BusyMax task', 'SUMMARY:Independent task')
            .replaceFirst(
              'END:VTODO',
              'X-ROUNDTRIP;X-OPAQUE=exact:task-value\r\nEND:VTODO',
            );
        expect(
          (await f.independentRequest(
            'PUT',
            eventUri,
            body: eventChanged,
            headers: {
              'content-type': 'text/calendar; charset=utf-8',
              'if-match': remoteEvent.headers['etag']!,
            },
          )).statusCode,
          anyOf(201, 204),
        );
        expect(
          (await f.independentRequest(
            'PUT',
            taskUri,
            body: taskChanged,
            headers: {
              'content-type': 'text/calendar; charset=utf-8',
              'if-match': remoteTask.headers['etag']!,
            },
          )).statusCode,
          anyOf(201, 204),
        );
        await f.reopen();
        await f.synchronize();
        event = (await f.database.select(f.database.calendarEvents).get())
            .singleWhere((e) => e.davCollectionId == f.eventCollectionId);
        task = (await f.database.select(f.database.tasks).get()).singleWhere(
          (t) => t.davCollectionId == f.collectionId,
        );
        expect(event.title, 'Independent change');
        expect(task.title, 'Independent task');
        final detail = (await f.calendars.loadEventDetail(event.id))!;
        await f.calendars.updateLocalEvent(
          EventEditorDraft.fromEventDetail(detail)
              .copyWith(title: 'BusyMax final event'),
        );
        await f.tasks.patchTask(
          task.taskListId,
          task.id,
          const TaskPatchInput({
            'title': 'BusyMax final task',
            'status': 'completed',
          }),
        );
        await f.synchronize();
        final finalEvent = await f.independentRequest('GET', eventUri);
        final finalTask = await f.independentRequest('GET', taskUri);
        expect(finalEvent.body, contains('SUMMARY:BusyMax final event'));
        expect(finalEvent.body, contains('X-ROUNDTRIP;X-OPAQUE=exact:value'));
        expect(finalEvent.body, contains('mailto:guest@example.test'));
        expect(
          finalEvent.body,
          contains('ORGANIZER:mailto:alice@example.test'),
        );
        expect(
          finalTask.body,
          contains('X-ROUNDTRIP;X-OPAQUE=exact:task-value'),
        );
        expect(finalTask.body, contains('STATUS:COMPLETED'));
        await f.tasks.patchTask(
          task.taskListId,
          task.id,
          const TaskPatchInput({'status': 'needsAction'}),
        );
        await f.synchronize();
        expect(
          (await f.independentRequest('GET', taskUri)).body,
          isNot(contains('STATUS:COMPLETED')),
        );
        await f.calendars.deleteLocalEvent(event.id);
        await f.tasks.deleteTask(task.taskListId, task.id);
        await f.reopen();
        await f.synchronize();
        expect((await f.independentRequest('GET', eventUri)).statusCode, 404);
        expect((await f.independentRequest('GET', taskUri)).statusCode, 404);
        final outcome = await f.administration.update(f.collectionId!, {
          const DavPropertyName(davNamespace, 'displayname'):
              '${f.collectionName} renamed',
        });
        expect(outcome, DavCollectionAdministrationOutcome.committed);
        expect(
          (await f.database.select(f.database.davCollections).get())
              .singleWhere((c) => c.id == f.collectionId)
              .displayName,
          '${f.collectionName} renamed',
        );
      },
      skip: enabled
          ? false
          : 'Set BUSYMAX_CALDAV_LIVE=1 with isolated HTTPS Docker fixtures.',
      timeout: const Timeout(Duration(minutes: 5)),
    );
    test(
      '${server.key}: generic VEVENT, VTODO, ETags, conflicts, sync and recovery round trips',
      () async {
        final credentials = await calDavQaCredentials(Uri.parse(server.value));
        final tls = SecurityContext(withTrustedRoots: true)
          ..setTrustedCertificates('test/interop/caldav/.runtime/ca.pem');
        final fixture = DavLiveFixture.generic(
          authority: Uri.parse(server.value),
          username: 'alice',
          password: credentials['alice'] as String,
          client: IOClient(HttpClient(context: tls)),
        );
        addTearDown(fixture.close);
        final initial = await fixture.discover('generic-roundtrip-discovery');
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        final home = initial.service.calendarHomeHref;
        final eventUri = home.resolve('busymax-qa-events-$suffix/');
        final taskUri = home.resolve('busymax-qa-tasks-$suffix/');
        await fixture.createCollection(
          eventUri,
          displayName: 'BusyMax QA events',
          component: 'VEVENT',
          color: '#3A7BFFFF',
        );
        fixture.registerCollectionForCleanup(eventUri);
        await fixture.createCollection(
          taskUri,
          displayName: 'BusyMax QA tasks',
          component: 'VTODO',
          color: '#7457D5FF',
        );
        fixture.registerCollectionForCleanup(taskUri);
        final discovery = await fixture.discover('generic-roundtrip-inventory');
        final events = discovery.collections.singleWhere(
          (c) => c.requestUri == eventUri,
        );
        final tasks = discovery.collections.singleWhere(
          (c) => c.requestUri == taskUri,
        );
        await fixture.verifyEvents(events, suffix);
        await fixture.verifyTasks(tasks, suffix);
        await fixture.verifyTransientReadRecovery(discovery);
        await fixture.verifyProductionSyncEngine(events, discovery);
      },
      skip: enabled ? false : 'Set BUSYMAX_CALDAV_LIVE=1 with the isolated Docker fixtures running.',
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.delegate);
  final http.Client delegate;
  final targets = <Uri>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    targets.add(request.url);
    return delegate.send(request);
  }

  @override
  void close() => delegate.close();
}

String _bulkItem(int index, {String? onlyComponent}) {
  final component = onlyComponent ?? (index.isEven ? 'VEVENT' : 'VTODO');
  return 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Independent BusyMax QA//EN\r\n'
      'BEGIN:$component\r\nUID:bulk-$index@example.invalid\r\nDTSTAMP:20261102T000000Z\r\n'
      '${component == 'VEVENT' ? 'DTSTART:20261103T090000Z\r\nDTEND:20261103T100000Z\r\n' : 'DUE;VALUE=DATE:20261103\r\n'}'
      'SUMMARY:Bulk $index\r\nX-BULK;X-OPAQUE=exact:$index\r\nEND:$component\r\nEND:VCALENDAR\r\n';
}

Future<void> _control(String action, String server) async {
  final result = await Process.run('python3', [
    'test/interop/caldav/control.py',
    action,
    server,
  ]);
  expect(result.exitCode, 0, reason: 'Isolated fixture control failed.');
}

Future<void> _ready(CalDavFixture fixture) async {
  for (var i = 0; i < 60; i++) {
    try {
      final response = await fixture.independentRequest(
        'PROPFIND',
        fixture.uri,
        body: '<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>',
        headers: const {'Depth': '0'},
      );
      if (response.statusCode == 207) return;
    } on Object {
      /* A restarted fixture can briefly refuse the connection. */
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  fail('Isolated server did not regain authenticated DAV readiness.');
}

class _LostResponses {
  String? method;
  int lost = 0, mutationCalls = 0;
  void arm(String method) {
    this.method = method;
    lost = 0;
    mutationCalls = 0;
  }
}

class _ResponseBarrier {
  String? method;
  final started = Completer<void>(), release = Completer<void>();
}

class _BarrierClient extends http.BaseClient {
  _BarrierClient(this.delegate, this.barrier);
  final http.Client delegate;
  final _ResponseBarrier barrier;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await delegate.send(request);
    if (request.method != barrier.method || barrier.started.isCompleted) {
      return response;
    }
    final bytes = await response.stream.toBytes();
    barrier.started.complete();
    await barrier.release.future;
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() => delegate.close();
}

/// Gateway fault fixture: only the optional ACL property is made unavailable.
/// Reads and writes still reach the real server, whose authorization is intact.
class _AbsentAclClient extends http.BaseClient {
  _AbsentAclClient(this.delegate);
  final http.Client delegate;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await delegate.send(request);
    if (request.method != 'PROPFIND' || response.statusCode != 207) {
      return response;
    }
    final bytes = await response.stream.toBytes();
    final document = XmlDocument.parse(utf8.decode(bytes));
    for (final property
        in document.descendantElements
            .where(
              (e) =>
                  e.name.namespaceUri == davNamespace &&
                  e.name.local == 'current-user-privilege-set',
            )
            .toList()) {
      property.parent!.children.remove(property);
    }
    final body = utf8.encode(document.toXmlString());
    return http.StreamedResponse(
      Stream.value(body),
      response.statusCode,
      headers: {...response.headers}..remove('content-length'),
      request: request,
    );
  }

  @override
  void close() => delegate.close();
}

/// A failed gateway response after the unmodified server committed its method.
/// Requests still use production authorization leasing and DAV transport.
class _LossClient extends http.BaseClient {
  _LossClient(this.delegate, this.faults);
  final http.Client delegate;
  final _LostResponses faults;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final observe = request.method == faults.method;
    if (observe) faults.mutationCalls++;
    final response = await delegate.send(request);
    if (observe && faults.lost == 0 && response.statusCode < 300) {
      await response.stream.drain<void>();
      faults.lost++;
      throw http.ClientException(
        'QA gateway response lost after upstream commit',
        request.url,
      );
    }
    return response;
  }

  @override
  void close() => delegate.close();
}
