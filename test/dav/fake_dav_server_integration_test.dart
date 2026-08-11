import 'dart:convert';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/dav/sync/dav_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/providers/provider_capabilities.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_dav_server.dart';

void main() {
  late FakeDavServer server;

  setUp(() async {
    server = FakeDavServer();
    await server.start();
  });

  tearDown(() => server.close());

  test(
    'socket discovery follows well-known redirect and observes ACL/removal changes',
    () async {
      var result = await _discover(server);

      expect(result.service.principalHref.path, server.principalPath);
      expect(result.service.calendarHomeHref.path, server.calendarHomePath);
      expect(result.collections, hasLength(1));
      expect(result.collections.single.hrefKey, server.collectionPath);
      expect(result.collections.single.eventProjectionEnabled, isTrue);
      expect(result.collections.single.taskProjectionEnabled, isTrue);
      expect(result.collections.single.capabilities.canCreateEvent, isTrue);
      expect(result.collections.single.capabilities.canCreateTask, isTrue);
      expect(server.requests.map((request) => request.method).take(6), [
        'OPTIONS',
        'OPTIONS',
        'PROPFIND',
        'PROPFIND',
        'PROPFIND',
      ]);
      expect(
        server.requests,
        everyElement(
          isA<FakeDavRequestRecord>().having(
            (request) => request.hasBasicAuthorization,
            'Basic authorization present',
            isTrue,
          ),
        ),
      );

      server.collectionReadOnly = true;
      result = await _discover(server);
      expect(result.collections.single.capabilities.isReadOnly, isTrue);
      expect(result.collections.single.capabilities.canCreateEvent, isFalse);
      expect(result.collections.single.capabilities.canCreateTask, isFalse);

      server.collectionRemoved = true;
      result = await _discover(server);
      expect(result.collections, isEmpty);
    },
  );

  test('RFC 6578 pages and multiget commit mixed VEVENT/VTODO data', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _seedCollection(database, server);
    var objectSequence = 0;
    final objectRepository = DavObjectRepository(
      database: database,
      idFactory: () => 'object-${objectSequence += 1}',
    );
    final result =
        await DavSyncEngine(
          database: database,
          objectRepository: objectRepository,
          remoteClient: _collectionClient(server),
          accountId: 'account',
          collectionId: 'collection',
          provider: BusyProvider.nextcloud,
          nowUtc: () => DateTime.utc(2026, 8, 8, 12),
        ).synchronize(
          correlationId: 'fake-sync',
          projectionRangeStartUtc: DateTime.utc(2026, 1),
          projectionRangeEndUtc: DateTime.utc(2027, 1),
        );

    expect(result.pages, 2);
    expect(result.membersSeen, 2);
    expect(result.objectsFetched, 2);
    expect(result.finalCursorValue, server.finalSyncToken);
    expect(await database.select(database.davObjects).get(), hasLength(2));
    expect(await database.select(database.calendarEvents).get(), hasLength(1));
    expect(await database.select(database.tasks).get(), hasLength(1));
    expect(
      (await database.select(database.calendarEvents).getSingle()).title,
      'Server event',
    );
    expect(
      (await database.select(database.tasks).getSingle()).title,
      'Server task',
    );
    final reports = server.requests
        .where((request) => request.method == 'REPORT')
        .toList();
    expect(reports, hasLength(3));
    expect(
      reports.where((request) => request.body.contains('sync-collection')),
      hasLength(2),
    );
    expect(
      reports
          .singleWhere((request) => request.body.contains('calendar-multiget'))
          .depth,
      '1',
    );

    final inventory = await _collectionClient(
      server,
    ).listMemberEtags(correlationId: 'fake-inventory');
    expect(inventory.members, hasLength(2));
  });

  test(
    'conditional writes handle ETag races, rewriting, and unknown outcome',
    () async {
      final client = DavMutationHttpClient(
        transport: server.transport(),
        accountId: 'account',
        collectionId: 'collection',
        credential: server.credential,
      );
      final service = DavConditionalMutationService(
        remoteClient: client,
        nowUtc: () => DateTime.utc(2026, 8, 8, 12),
      );
      final resource = server.resources[server.eventPath]!;
      var baseline = resource.body;
      var etag = resource.etag;
      server.rewriteMutations = true;

      var result = await service.update(
        hrefKey: server.eventPath,
        uri: server.uriFor(server.eventPath),
        baselineEtag: etag,
        baselineRawIcs: baseline,
        patch: _summaryPatch('Canonical update'),
        capabilities: _eventMutationCapabilities,
        correlationId: 'rewrite',
      );
      expect(result.outcome, DavMutationOutcome.succeeded);
      expect(
        result.canonicalObject!.rawIcsBody,
        contains('SUMMARY:Canonical update'),
      );
      expect(
        result.canonicalObject!.rawIcsBody,
        contains('X-SERVER-REWRITE:canonical'),
      );
      expect(
        server.requests
            .singleWhere((request) => request.method == 'PUT')
            .ifMatch,
        etag,
      );

      baseline = server.resources[server.eventPath]!.body;
      etag = server.resources[server.eventPath]!.etag;
      server.raceNextMutation = true;
      result = await service.update(
        hrefKey: server.eventPath,
        uri: server.uriFor(server.eventPath),
        baselineEtag: etag,
        baselineRawIcs: baseline,
        patch: _summaryPatch('After ETag race'),
        capabilities: _eventMutationCapabilities,
        correlationId: 'race',
      );
      expect(result.outcome, DavMutationOutcome.succeeded);
      expect(
        result.canonicalObject!.rawIcsBody,
        contains('SUMMARY:After ETag race'),
      );

      baseline = server.resources[server.eventPath]!.body;
      etag = server.resources[server.eventPath]!.etag;
      server
        ..rewriteMutations = false
        ..dropAfterNextMutation = true;
      result = await service.update(
        hrefKey: server.eventPath,
        uri: server.uriFor(server.eventPath),
        baselineEtag: etag,
        baselineRawIcs: baseline,
        patch: _summaryPatch('Applied before connection drop'),
        capabilities: _eventMutationCapabilities,
        correlationId: 'unknown-outcome',
      );
      expect(result.outcome, DavMutationOutcome.succeeded);
      expect(
        result.canonicalObject!.rawIcsBody,
        contains('SUMMARY:Applied before connection drop'),
      );
    },
  );

  test(
    'status, per-resource, malformed, invalid-token, delay, and drop matrix',
    () async {
      final statusCases = <(int, DavErrorCategory)>[
        (401, DavErrorCategory.davAuthRejected),
        (403, DavErrorCategory.davPermissionDenied),
        (404, DavErrorCategory.davCollectionRemoved),
        (409, DavErrorCategory.davResourceConflict),
        (412, DavErrorCategory.davResourceConflict),
        (423, DavErrorCategory.davResourceConflict),
        (429, DavErrorCategory.davRateLimited),
        (507, DavErrorCategory.davQuotaOrSizeLimit),
        (500, DavErrorCategory.davServerUnavailable),
        (503, DavErrorCategory.davServerUnavailable),
      ];
      for (final entry in statusCases) {
        server.enqueueFault(
          FakeDavFault(
            method: 'PROPFIND',
            path: server.collectionPath,
            statusCode: entry.$1,
            headers: entry.$1 == 429 ? const {'retry-after': '17'} : const {},
          ),
        );
        final error = await _captureDavError(
          _collectionClient(
            server,
            limits: const DavTransportLimits(maximumReadAttempts: 1),
          ).listMemberEtags(correlationId: 'status-${entry.$1}'),
        );
        expect(error.category, entry.$2, reason: 'HTTP ${entry.$1}');
        if (entry.$1 == 429) {
          expect(error.retryAfter, const Duration(seconds: 17));
        }
      }

      server.resources[server.eventPath]!.multistatusStatus = 403;
      var error = await _captureDavError(
        _collectionClient(
          server,
        ).listMemberEtags(correlationId: 'member-status'),
      );
      expect(error.category, DavErrorCategory.davPermissionDenied);
      server.resources[server.eventPath]!.multistatusStatus = null;

      server.enqueueFault(
        FakeDavFault(
          method: 'PROPFIND',
          path: server.collectionPath,
          statusCode: 207,
          body: '<d:multistatus xmlns:d="DAV:"><broken>',
        ),
      );
      error = await _captureDavError(
        _collectionClient(server).listMemberEtags(correlationId: 'malformed'),
      );
      expect(error.category, DavErrorCategory.davProtocolViolation);

      error = await _captureDavError(
        _collectionClient(server).syncCollectionPage(
          syncToken: 'invalid-token',
          correlationId: 'invalid-token',
        ),
      );
      expect(error.category, DavErrorCategory.davSyncTokenInvalid);

      server.enqueueFault(
        FakeDavFault(
          method: 'PROPFIND',
          path: server.collectionPath,
          delay: const Duration(milliseconds: 80),
          statusCode: 207,
        ),
      );
      error = await _captureDavError(
        _collectionClient(
          server,
          limits: const DavTransportLimits(
            connectTimeout: Duration(milliseconds: 10),
            maximumReadAttempts: 1,
          ),
        ).listMemberEtags(correlationId: 'delay'),
      );
      expect(error.category, DavErrorCategory.davTransientNetwork);

      server.enqueueFault(
        FakeDavFault(
          method: 'PROPFIND',
          path: server.collectionPath,
          dropConnection: true,
        ),
      );
      error = await _captureDavError(
        _collectionClient(
          server,
          limits: const DavTransportLimits(maximumReadAttempts: 1),
        ).listMemberEtags(correlationId: 'drop'),
      );
      expect(error.category, DavErrorCategory.davTransientNetwork);
    },
  );
}

Future<DavDiscoveryResult> _discover(FakeDavServer server) =>
    DavDiscoveryService(
      transport: server.transport(),
      profile: server.profile,
      accountAuthority: server.authority,
      accountId: 'account',
      credential: server.credential,
      nowUtc: () => DateTime.utc(2026, 8, 8, 12),
    ).discover(correlationId: 'fake-discovery');

DavCollectionHttpClient _collectionClient(
  FakeDavServer server, {
  DavTransportLimits limits = const DavTransportLimits(),
}) => DavCollectionHttpClient(
  transport: server.transport(limits: limits),
  profile: server.profile,
  accountAuthority: server.authority,
  accountId: 'account',
  collectionId: 'collection',
  collectionUri: server.uriFor(server.collectionPath),
  credential: server.credential,
);

Future<DavException> _captureDavError(Future<Object?> operation) async {
  try {
    await operation;
  } on DavException catch (error) {
    return error;
  }
  throw TestFailure('Expected a DavException.');
}

DavMutationPatch _summaryPatch(String summary) => DavMutationPatch(
  target: const IcalComponentKey(
    componentType: 'VEVENT',
    uid: 'event@example.test',
  ),
  scope: DavMutationScope.object,
  operations: [DavPatchOperation.setText('SUMMARY', summary)],
);

const _eventMutationCapabilities = CollectionCapabilities(
  canRead: true,
  canWriteContent: true,
  canAddMembers: true,
  canDeleteMembers: true,
  supportsEvents: true,
);

Future<void> _seedCollection(AppDatabase database, FakeDavServer server) async {
  const now = '2026-08-08T12:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'account',
          provider: 'nextcloud',
          authority: server.authority.toString(),
          providerAccountId: 'alex',
          credentialKind: 'nextcloud_app_password',
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'collection',
          accountId: 'account',
          hrefKey: server.collectionPath,
          requestUri: server.uriFor(server.collectionPath).toString(),
          displayName: 'Work & Tasks',
          supportedComponentMask: const Value(3),
          supportedReportsJson: Value(
            jsonEncode([
              '{DAV:}sync-collection',
              '{urn:ietf:params:xml:ns:caldav}calendar-multiget',
            ]),
          ),
          currentUserPrivilegesJson: Value(
            jsonEncode(['{DAV:}read', '{DAV:}write-content']),
          ),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(true),
          taskProjectionEnabled: const Value(true),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'dav-calendar-collection',
          accountId: 'account',
          provider: 'nextcloud',
          providerCalendarId: server.collectionPath,
          davCollectionId: const Value('collection'),
          summary: 'Work & Tasks',
          createdAtLocal: DateTime.utc(2026, 8, 8).millisecondsSinceEpoch,
          updatedAtLocal: DateTime.utc(2026, 8, 8).millisecondsSinceEpoch,
        ),
      );
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'account',
          id: 'dav-task-list-collection',
          davCollectionId: const Value('collection'),
          title: 'Work & Tasks',
          rawJson: '{}',
          createdLocalAtUtc: now,
          updatedLocalAtUtc: now,
        ),
      );
}
