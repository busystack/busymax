import 'dart:io';

import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_repository.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/dav/sync/dav_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _enabledVariable = 'BUSYMAX_NEXTCLOUD_LIVE';

void main() {
  final enabled = Platform.environment[_enabledVariable] == '1';
  final largeEnabled =
      enabled && Platform.environment['BUSYMAX_NEXTCLOUD_LIVE_LARGE'] == '1';
  final restartStage =
      Platform.environment['BUSYMAX_NEXTCLOUD_LIVE_RESTART_STAGE'];

  test(
    'exact Nextcloud server preserves DAV calendar and task semantics',
    () async {
      final fixture = _LiveNextcloudFixture.fromEnvironment();
      addTearDown(fixture.close);

      final initialDiscovery = await fixture.discover('live-discovery');
      expect(initialDiscovery.service.calendarHomeHref.path, isNotEmpty);

      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      final eventSlug = 'busymax-qa-events-$suffix';
      final taskSlug = 'busymax-qa-tasks-$suffix';
      final eventUri = _collectionChild(
        initialDiscovery.service.calendarHomeHref,
        eventSlug,
      );
      final taskUri = _collectionChild(
        initialDiscovery.service.calendarHomeHref,
        taskSlug,
      );
      await fixture.createCollection(
        eventUri,
        displayName: 'BusyMax QA Events',
        component: 'VEVENT',
        color: '#3A7BFFFF',
      );
      fixture.registerCollectionForCleanup(eventUri);
      await fixture.createCollection(
        taskUri,
        displayName: 'BusyMax QA Tasks',
        component: 'VTODO',
        color: '#7457D5FF',
      );
      fixture.registerCollectionForCleanup(taskUri);

      final discovery = await fixture.discover('live-rediscovery');
      final eventCollection = _collectionBySlug(discovery, eventSlug);
      final taskCollection = _collectionBySlug(discovery, taskSlug);
      expect(eventCollection.eventProjectionEnabled, isTrue);
      expect(eventCollection.capabilities.canCreateEvent, isTrue);
      expect(eventCollection.color?.toUpperCase(), '#3A7BFFFF');
      expect(taskCollection.taskProjectionEnabled, isTrue);
      expect(taskCollection.capabilities.canCreateTask, isTrue);
      expect(taskCollection.color?.toUpperCase(), '#7457D5FF');

      await fixture.verifyTransientReadRecovery(discovery);
      await fixture.verifyEvents(eventCollection, suffix);
      await fixture.verifyTasks(taskCollection, suffix);
      await fixture.verifyProductionSyncEngine(eventCollection, discovery);
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 and the BUSYMAX_NEXTCLOUD_LIVE_* '
              'credential variables to run the isolated live-server tests.',
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'large Nextcloud collection synchronizes and deletes without truncation',
    () async {
      final fixture = _LiveNextcloudFixture.fromEnvironment();
      addTearDown(fixture.close);
      final discovery = await fixture.discover('live-large-discovery');
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      final slug = 'busymax-qa-large-$suffix';
      final collectionUri = _collectionChild(
        discovery.service.calendarHomeHref,
        slug,
      );
      await fixture.createCollection(
        collectionUri,
        displayName: 'BusyMax QA Large',
        component: 'VEVENT',
        color: '#2563EBFF',
      );
      fixture.registerCollectionForCleanup(collectionUri);
      final collection = _collectionBySlug(
        await fixture.discover('live-large-rediscovery'),
        slug,
      );

      await fixture.verifyLargeCollection(collection, suffix, memberCount: 128);
    },
    skip: largeEnabled
        ? false
        : 'Set BUSYMAX_NEXTCLOUD_LIVE_LARGE=1 with the live-server '
              'variables to run the 128-member collection test.',
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'prepare a durable Nextcloud object for server restart',
    () async {
      final fixture = _LiveNextcloudFixture.fromEnvironment();
      addTearDown(fixture.close);
      final slug = _requiredEnvironment('BUSYMAX_NEXTCLOUD_LIVE_RESTART_ID');
      final discovery = await fixture.discover(
        'live-restart-prepare-discovery',
      );
      final collectionUri = _collectionChild(
        discovery.service.calendarHomeHref,
        slug,
      );
      await fixture.createCollection(
        collectionUri,
        displayName: 'BusyMax QA Restart',
        component: 'VEVENT',
        color: '#0891B2FF',
      );
      final collection = _collectionBySlug(
        await fixture.discover('live-restart-prepare-rediscovery'),
        slug,
      );
      await fixture.prepareRestartObject(collection, slug);
    },
    skip: enabled && restartStage == 'prepare'
        ? false
        : 'Set the live restart stage to prepare to create the durable probe.',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'rediscover and mutate the durable object after server restart',
    () async {
      final fixture = _LiveNextcloudFixture.fromEnvironment();
      addTearDown(fixture.close);
      final slug = _requiredEnvironment('BUSYMAX_NEXTCLOUD_LIVE_RESTART_ID');
      final collection = _collectionBySlug(
        await fixture.discover('live-restart-verify-discovery'),
        slug,
      );
      await fixture.verifyRestartObject(collection, slug);
      await fixture.deleteCollection(collection.requestUri);
    },
    skip: enabled && restartStage == 'verify'
        ? false
        : 'Set the live restart stage to verify after restarting the server.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

final class _LiveNextcloudFixture {
  _LiveNextcloudFixture({
    required this.authority,
    required this.profile,
    required this.credential,
    required this.client,
    required this.transport,
  });

  factory _LiveNextcloudFixture.fromEnvironment() {
    final url = _requiredEnvironment('BUSYMAX_NEXTCLOUD_LIVE_URL');
    final username = _requiredEnvironment('BUSYMAX_NEXTCLOUD_LIVE_USERNAME');
    final password = _requiredEnvironment('BUSYMAX_NEXTCLOUD_LIVE_PASSWORD');
    final authority = Uri.parse(url);
    if (!authority.hasScheme || authority.host.isEmpty) {
      throw StateError('The live Nextcloud URL is not an absolute URI.');
    }
    final insecureLoopback =
        authority.scheme == 'http' &&
        const {'127.0.0.1', '::1', 'localhost'}.contains(authority.host);
    final profile = DavProviderProfile(
      provider: BusyProvider.nextcloud,
      bootstrapUri: authority,
      calendarEnabled: true,
      tasksEnabled: true,
      allowCollectionMutations: false,
      allowSchedulingMutations: false,
      allowMove: false,
      allowInsecureLoopbackForTesting: insecureLoopback,
    );
    final client = http.Client();
    return _LiveNextcloudFixture(
      authority: authority,
      profile: profile,
      credential: DavBasicCredential(username: username, password: password),
      client: client,
      transport: DavHttpTransport(
        client: client,
        profile: profile,
        accountAuthority: authority,
      ),
    );
  }

  final Uri authority;
  final DavProviderProfile profile;
  final DavBasicCredential credential;
  final http.Client client;
  final DavHttpTransport transport;
  final List<Uri> _collectionsToDelete = [];

  Future<DavDiscoveryResult> discover(String correlationId) =>
      DavDiscoveryService(
        transport: transport,
        profile: profile,
        accountAuthority: authority,
        accountId: 'nextcloud-live',
        credential: credential,
      ).discover(correlationId: correlationId);

  void registerCollectionForCleanup(Uri uri) {
    _collectionsToDelete.add(uri);
  }

  Future<void> createCollection(
    Uri uri, {
    required String displayName,
    required String component,
    required String color,
  }) async {
    final response = await transport.send(
      DavRequest.xml(
        method: 'MKCALENDAR',
        uri: uri,
        accountId: 'nextcloud-live',
        correlationId: 'live-create-collection',
        retryClass: DavRetryClass.never,
        body:
            '''<?xml version="1.0" encoding="utf-8"?>
<c:mkcalendar xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:a="http://apple.com/ns/ical/">
  <d:set><d:prop>
    <d:resourcetype><d:collection/><c:calendar/></d:resourcetype>
    <d:displayname>$displayName</d:displayname>
    <c:supported-calendar-component-set><c:comp name="$component"/></c:supported-calendar-component-set>
    <a:calendar-color>$color</a:calendar-color>
  </d:prop></d:set>
</c:mkcalendar>''',
      ),
      credential: credential,
    );
    expect(response.statusCode, anyOf(201, 204));
  }

  Future<void> verifyEvents(
    DavCollectionDiscovery collection,
    String suffix,
  ) async {
    final remote = _collectionClient(collection, 'events');
    final mutations = _mutationService('events');
    final emptyPage = await remote.syncCollectionPage(
      syncToken: '',
      correlationId: 'live-events-empty-sync',
    );
    expect(emptyPage.changedMembers, isEmpty);
    var syncToken = emptyPage.nextSyncToken;

    final uid = 'busymax-live-event-$suffix@example.invalid';
    final event = DavNewObject(
      uid: uid,
      initialMemberName: 'busymax-event-$suffix.ics',
      componentType: 'VEVENT',
      rawIcs: _recurringEvent(uid),
    );
    var result = await mutations.create(
      collectionUri: collection.requestUri,
      object: event,
      capabilities: collection.capabilities,
      correlationId: 'live-event-create',
    );
    expect(result.outcome, DavMutationOutcome.succeeded);
    var current = result.canonicalObject!;
    _expectEventPreservation(current.rawIcsBody!);

    final variants = <DavFetchedMember>[];
    for (final variant in [
      (
        'all-day',
        IcalTemporalKind.date,
        'DTSTART;VALUE=DATE:20260812',
        'DTEND;VALUE=DATE:20260813',
      ),
      (
        'floating',
        IcalTemporalKind.floatingDateTime,
        'DTSTART:20260813T090000',
        'DTEND:20260813T100000',
      ),
      (
        'utc',
        IcalTemporalKind.utcDateTime,
        'DTSTART:20260814T160000Z',
        'DTEND:20260814T170000Z',
      ),
    ]) {
      final variantUid = 'busymax-live-${variant.$1}-$suffix@example.invalid';
      final variantResult = await mutations.create(
        collectionUri: collection.requestUri,
        object: DavNewObject(
          uid: variantUid,
          initialMemberName: 'busymax-${variant.$1}-$suffix.ics',
          rawIcs: _simpleEvent(
            uid: variantUid,
            summary: 'BusyMax ${variant.$1} event',
            startLine: variant.$3,
            endLine: variant.$4,
          ),
          componentType: 'VEVENT',
        ),
        capabilities: collection.capabilities,
        correlationId: 'live-${variant.$1}-event-create',
      );
      expect(variantResult.outcome, DavMutationOutcome.succeeded);
      final canonical = variantResult.canonicalObject!;
      expect(
        IcalSemanticDocument.parse(
          canonical.rawIcsBody!,
        ).components.single.start!.kind,
        variant.$2,
      );
      variants.add(canonical);
    }

    var page = await remote.syncCollectionPage(
      syncToken: syncToken,
      correlationId: 'live-event-create-sync',
    );
    expect(page.changedMembers, hasLength(4));
    expect(
      page.changedMembers.map((member) => member.hrefKey),
      contains(current.hrefKey),
    );
    syncToken = page.nextSyncToken;
    final fetched = await remote.fetchMembers(
      page.changedMembers,
      correlationId: 'live-event-multiget',
      useCalendarMultiget: true,
    );
    expect(fetched, hasLength(4));
    expect(
      fetched.any(
        (member) => member.rawIcsBody!.contains('SUMMARY:BusyMax live event'),
      ),
      isTrue,
    );

    final original = current;
    final remoteLocationPatch = DavMutationPatch(
      target: IcalComponentKey(componentType: 'VEVENT', uid: uid),
      scope: DavMutationScope.recurrenceMaster,
      operations: [
        DavPatchOperation.setText('LOCATION', 'Nextcloud-side location'),
      ],
    );
    final directUpdate = await _mutationClient('events').conditionalPut(
      uri: current.requestUri,
      rawIcs: remoteLocationPatch.applyTo(
        current.rawIcsBody!,
        nowUtc: DateTime.utc(2026, 8, 8, 12, 34, 56),
      ),
      correlationId: 'live-event-out-of-band-update',
      ifMatch: current.etag,
    );
    expect(directUpdate.status, DavConditionalStatus.success);

    result = await mutations.update(
      hrefKey: original.hrefKey,
      uri: original.requestUri,
      baselineEtag: original.etag!,
      baselineRawIcs: original.rawIcsBody!,
      patch: DavMutationPatch(
        target: IcalComponentKey(componentType: 'VEVENT', uid: uid),
        scope: DavMutationScope.recurrenceMaster,
        operations: [
          DavPatchOperation.setText('SUMMARY', 'BusyMax merged title'),
        ],
      ),
      capabilities: collection.capabilities,
      correlationId: 'live-event-disjoint-merge',
    );
    expect(result.outcome, DavMutationOutcome.succeeded);
    current = result.canonicalObject!;
    expect(current.rawIcsBody, contains('SUMMARY:BusyMax merged title'));
    expect(current.rawIcsBody, contains('LOCATION:Nextcloud-side location'));
    _expectEventPreservation(current.rawIcsBody!);

    final conflictBaseline = current;
    final remoteSummaryPatch = DavMutationPatch(
      target: IcalComponentKey(componentType: 'VEVENT', uid: uid),
      scope: DavMutationScope.recurrenceMaster,
      operations: [
        DavPatchOperation.setText('SUMMARY', 'Nextcloud conflicting title'),
      ],
    );
    final conflictUpdate = await _mutationClient('events').conditionalPut(
      uri: current.requestUri,
      rawIcs: remoteSummaryPatch.applyTo(
        current.rawIcsBody!,
        nowUtc: DateTime.utc(2026, 8, 8, 12, 34, 56),
      ),
      correlationId: 'live-event-conflicting-out-of-band-update',
      ifMatch: current.etag,
    );
    expect(conflictUpdate.status, DavConditionalStatus.success);
    result = await mutations.update(
      hrefKey: conflictBaseline.hrefKey,
      uri: conflictBaseline.requestUri,
      baselineEtag: conflictBaseline.etag!,
      baselineRawIcs: conflictBaseline.rawIcsBody!,
      patch: DavMutationPatch(
        target: IcalComponentKey(componentType: 'VEVENT', uid: uid),
        scope: DavMutationScope.recurrenceMaster,
        operations: [
          DavPatchOperation.setText('SUMMARY', 'BusyMax conflicting title'),
        ],
      ),
      capabilities: collection.capabilities,
      correlationId: 'live-event-explicit-conflict',
    );
    expect(result.outcome, DavMutationOutcome.conflict);
    expect(
      result.conflictRemoteObject!.rawIcsBody,
      contains('SUMMARY:Nextcloud conflicting title'),
    );
    current = result.conflictRemoteObject!;

    page = await remote.syncCollectionPage(
      syncToken: syncToken,
      correlationId: 'live-event-update-sync',
    );
    expect(
      page.changedMembers.map((member) => member.hrefKey),
      contains(current.hrefKey),
    );
    syncToken = page.nextSyncToken;

    for (final object in [current, ...variants]) {
      final deletion = await mutations.delete(
        hrefKey: object.hrefKey,
        uri: object.requestUri,
        baselineEtag: object.etag!,
        baselineRawIcs: object.rawIcsBody!,
        isEvent: true,
        capabilities: collection.capabilities,
        correlationId: 'live-event-delete',
      );
      expect(deletion.outcome, DavMutationOutcome.succeeded);
    }
    page = await remote.syncCollectionPage(
      syncToken: syncToken,
      correlationId: 'live-event-delete-sync',
    );
    expect(
      page.deletedHrefKeys,
      containsAll([
        current.hrefKey,
        ...variants.map((object) => object.hrefKey),
      ]),
    );

    final invalidTokenError = await _captureDavError(
      remote.syncCollectionPage(
        syncToken: 'https://busymax.invalid/sync-token/does-not-exist',
        correlationId: 'live-invalid-sync-token',
      ),
    );
    expect(invalidTokenError.kind, DavErrorKind.invalidSyncToken);
  }

  Future<void> verifyTransientReadRecovery(DavDiscoveryResult discovery) async {
    for (final statusCode in const [429, 503, 500]) {
      final injected = _InjectedStatusClient(
        delegate: client,
        statusCode: statusCode,
      );
      final delays = <Duration>[];
      final retryingTransport = DavHttpTransport(
        client: injected,
        profile: profile,
        accountAuthority: authority,
        delay: (duration) async => delays.add(duration),
      );
      final response = await retryingTransport.send(
        DavRequest.xml(
          method: 'PROPFIND',
          uri: discovery.service.calendarHomeHref,
          accountId: 'nextcloud-live',
          correlationId: 'live-injected-retry-$statusCode',
          headers: const {'depth': '0'},
          body: '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>''',
        ),
        credential: credential,
      );
      expect(response.statusCode, 207);
      expect(injected.calls, 2);
      expect(delays, hasLength(1));
      if (statusCode == 429 || statusCode == 503) {
        expect(delays.single, Duration.zero);
      }
    }
  }

  Future<void> verifyTasks(
    DavCollectionDiscovery collection,
    String suffix,
  ) async {
    final remote = _collectionClient(collection, 'tasks');
    final mutations = _mutationService('tasks');
    var page = await remote.syncCollectionPage(
      syncToken: '',
      correlationId: 'live-tasks-empty-sync',
    );
    expect(page.changedMembers, isEmpty);
    var syncToken = page.nextSyncToken;

    final parentUid = 'busymax-live-parent-$suffix@example.invalid';
    final parentResult = await mutations.create(
      collectionUri: collection.requestUri,
      object: DavNewObject(
        uid: parentUid,
        initialMemberName: 'busymax-parent-$suffix.ics',
        rawIcs: _parentTask(parentUid),
        componentType: 'VTODO',
      ),
      capabilities: collection.capabilities,
      correlationId: 'live-parent-task-create',
    );
    expect(parentResult.outcome, DavMutationOutcome.succeeded);
    var parent = parentResult.canonicalObject!;

    final childUid = 'busymax-live-child-$suffix@example.invalid';
    var result = await mutations.create(
      collectionUri: collection.requestUri,
      object: DavNewObject(
        uid: childUid,
        initialMemberName: 'busymax-child-$suffix.ics',
        rawIcs: _childTask(childUid, parentUid),
        componentType: 'VTODO',
      ),
      capabilities: collection.capabilities,
      correlationId: 'live-child-task-create',
    );
    expect(result.outcome, DavMutationOutcome.succeeded);
    var child = result.canonicalObject!;
    _expectTaskPreservation(child.rawIcsBody!, parentUid);

    page = await remote.syncCollectionPage(
      syncToken: syncToken,
      correlationId: 'live-task-create-sync',
    );
    expect(page.changedMembers, hasLength(2));
    syncToken = page.nextSyncToken;
    final fetched = await remote.fetchMembers(
      page.changedMembers,
      correlationId: 'live-task-multiget',
      useCalendarMultiget: true,
    );
    expect(fetched, hasLength(2));

    for (final percent in const [55, 100, 0]) {
      result = await mutations.update(
        hrefKey: child.hrefKey,
        uri: child.requestUri,
        baselineEtag: child.etag!,
        baselineRawIcs: child.rawIcsBody!,
        patch: DavMutationPatch(
          target: IcalComponentKey(componentType: 'VTODO', uid: childUid),
          scope: DavMutationScope.object,
          operations: [DavPatchOperation.setTaskProgress(percent)],
        ),
        capabilities: collection.capabilities,
        correlationId: 'live-task-progress-$percent',
      );
      expect(result.outcome, DavMutationOutcome.succeeded);
      child = result.canonicalObject!;
      final semantic = IcalSemanticDocument.parse(
        child.rawIcsBody!,
      ).components.single;
      expect(semantic.percentComplete, percent);
      if (percent == 100) {
        expect(semantic.status, 'COMPLETED');
        expect(semantic.completed, isNotNull);
      } else {
        expect(semantic.completed, isNull);
      }
      _expectTaskPreservation(child.rawIcsBody!, parentUid);
    }

    page = await remote.syncCollectionPage(
      syncToken: syncToken,
      correlationId: 'live-task-update-sync',
    );
    expect(
      page.changedMembers.map((member) => member.hrefKey),
      contains(child.hrefKey),
    );
    syncToken = page.nextSyncToken;

    for (final entry in [(child, false), (parent, false)]) {
      final deletion = await mutations.delete(
        hrefKey: entry.$1.hrefKey,
        uri: entry.$1.requestUri,
        baselineEtag: entry.$1.etag!,
        baselineRawIcs: entry.$1.rawIcsBody!,
        isEvent: entry.$2,
        capabilities: collection.capabilities,
        correlationId: 'live-task-delete',
      );
      expect(deletion.outcome, DavMutationOutcome.succeeded);
    }
    page = await remote.syncCollectionPage(
      syncToken: syncToken,
      correlationId: 'live-task-delete-sync',
    );
    expect(page.deletedHrefKeys, containsAll([child.hrefKey, parent.hrefKey]));
  }

  Future<void> verifyLargeCollection(
    DavCollectionDiscovery collection,
    String suffix, {
    required int memberCount,
  }) async {
    final remote = _collectionClient(collection, 'large');
    final mutationClient = _mutationClient('large');
    final emptyPage = await remote.syncCollectionPage(
      syncToken: '',
      correlationId: 'live-large-empty-sync',
    );
    expect(emptyPage.changedMembers, isEmpty);

    final collectionBase = collection.requestUri.path.endsWith('/')
        ? collection.requestUri
        : collection.requestUri.replace(path: '${collection.requestUri.path}/');
    for (var index = 0; index < memberCount; index += 1) {
      final response = await mutationClient.conditionalPut(
        uri: collectionBase.resolve('busymax-large-$index-$suffix.ics'),
        rawIcs: _simpleEvent(
          uid: 'busymax-large-$index-$suffix@example.invalid',
          summary: 'BusyMax large event $index',
          startLine:
              'DTSTART:20260901T${(index % 20).toString().padLeft(2, '0')}0000Z',
          endLine:
              'DTEND:20260901T${((index % 20) + 1).toString().padLeft(2, '0')}0000Z',
        ),
        correlationId: 'live-large-create-$index',
        ifNoneMatch: true,
      );
      expect(response.status, DavConditionalStatus.success);
    }

    final page = await remote.syncCollectionPage(
      syncToken: emptyPage.nextSyncToken,
      correlationId: 'live-large-create-sync',
    );
    expect(page.changedMembers, hasLength(memberCount));
    expect(page.truncated, isFalse);
    final inventory = await remote.listMemberEtags(
      correlationId: 'live-large-inventory',
    );
    expect(inventory.members, hasLength(memberCount));

    var fetchedCount = 0;
    for (var offset = 0; offset < inventory.members.length; offset += 32) {
      final end = offset + 32 < inventory.members.length
          ? offset + 32
          : inventory.members.length;
      final fetched = await remote.fetchMembers(
        inventory.members.sublist(offset, end),
        correlationId: 'live-large-multiget-$offset',
        useCalendarMultiget: true,
      );
      expect(fetched, everyElement(isA<DavFetchedMember>()));
      fetchedCount += fetched.length;
    }
    expect(fetchedCount, memberCount);

    for (final member in inventory.members) {
      final response = await mutationClient.conditionalDelete(
        uri: member.requestUri,
        ifMatch: member.etag,
        correlationId: 'live-large-delete',
      );
      expect(response.status, DavConditionalStatus.success);
    }
    final deletionPage = await remote.syncCollectionPage(
      syncToken: page.nextSyncToken,
      correlationId: 'live-large-delete-sync',
    );
    expect(deletionPage.deletedHrefKeys, hasLength(memberCount));
  }

  Future<void> verifyProductionSyncEngine(
    DavCollectionDiscovery collection,
    DavDiscoveryResult discovery,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    try {
      const seededAt = '2026-08-09T12:00:00.000Z';
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: discovery.accountId,
              provider: BusyProvider.nextcloud.storageValue,
              authority: authority.toString(),
              providerAccountId: credential.username,
              credentialKind: 'nextcloud_app_password',
              authState: const Value('signed_in'),
              createdAtUtc: seededAt,
              updatedAtUtc: seededAt,
            ),
          );
      await DavDiscoveryRepository(
        database: database,
      ).commitSuccessfulInventory(discovery);
      final storedCollection = await (database.select(
        database.davCollections,
      )..where((row) => row.hrefKey.equals(collection.hrefKey))).getSingle();
      var nextObjectId = 0;
      final objectRepository = DavObjectRepository(
        database: database,
        idFactory: () => 'live-object-${nextObjectId += 1}',
      );
      var notificationRebuilds = 0;
      final delegate = _collectionClient(collection, 'production-engine');

      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      await _createEngineEvent(
        collection,
        suffix: '$suffix-initial',
        summary: 'BusyMax engine baseline',
      );
      final initial = await DavSyncEngine(
        database: database,
        objectRepository: objectRepository,
        remoteClient: delegate,
        accountId: discovery.accountId,
        collectionId: storedCollection.id,
        provider: BusyProvider.nextcloud,
        onNotificationsNeedRebuild: (_) async => notificationRebuilds += 1,
      ).synchronize(correlationId: 'live-engine-initial');
      expect(initial.initialOrRebaseline, isTrue);
      expect(initial.objectsFetched, 1);
      expect(
        await database.select(database.calendarEvents).get(),
        hasLength(1),
      );
      expect(notificationRebuilds, 1);

      final cursor = await database.select(database.syncCursors).getSingle();
      const invalidToken =
          'https://busymax.invalid/sync-token/full-engine-rebaseline';
      await (database.update(database.syncCursors)
            ..where((row) => row.id.equals(cursor.id)))
          .write(const SyncCursorsCompanion(cursorValue: Value(invalidToken)));
      await _createEngineEvent(
        collection,
        suffix: '$suffix-rebaseline',
        summary: 'BusyMax engine rebaseline',
      );
      var observedSafeRebaseline = false;
      final observingRemote = _ObservedLiveRemoteClient(
        delegate: delegate,
        beforeSync: (token) async {
          if (token != '') return;
          expect(
            await database.select(database.davObjects).get(),
            hasLength(1),
          );
          expect(
            (await database.select(database.syncCursors).getSingle())
                .cursorValue,
            invalidToken,
          );
          observedSafeRebaseline = true;
        },
      );
      final rebaseline = await DavSyncEngine(
        database: database,
        objectRepository: objectRepository,
        remoteClient: observingRemote,
        accountId: discovery.accountId,
        collectionId: storedCollection.id,
        provider: BusyProvider.nextcloud,
        onNotificationsNeedRebuild: (_) async => notificationRebuilds += 1,
      ).synchronize(correlationId: 'live-engine-rebaseline');
      expect(observingRemote.requestedTokens.first, invalidToken);
      expect(observingRemote.requestedTokens.last, '');
      expect(observedSafeRebaseline, isTrue);
      expect(rebaseline.initialOrRebaseline, isTrue);
      expect(
        await database.select(database.calendarEvents).get(),
        hasLength(2),
      );
      expect(notificationRebuilds, 2);

      final committedCursor =
          (await database.select(database.syncCursors).getSingle()).cursorValue;
      await _createEngineEvent(
        collection,
        suffix: '$suffix-interrupted-a',
        summary: 'BusyMax interrupted A',
      );
      await _createEngineEvent(
        collection,
        suffix: '$suffix-interrupted-b',
        summary: 'BusyMax interrupted B',
      );
      final failingRemote = _ObservedLiveRemoteClient(
        delegate: delegate,
        failFetchCall: 2,
      );
      await expectLater(
        DavSyncEngine(
          database: database,
          objectRepository: objectRepository,
          remoteClient: failingRemote,
          accountId: discovery.accountId,
          collectionId: storedCollection.id,
          provider: BusyProvider.nextcloud,
          limits: const DavSyncLimits(maximumMembersPerMultiget: 1),
        ).synchronize(correlationId: 'live-engine-interrupted-fetch'),
        throwsA(
          isA<DavException>().having(
            (error) => error.code,
            'code',
            'InjectedLiveLaterFetchFailure',
          ),
        ),
      );
      expect(failingRemote.fetchCalls, 2);
      expect(
        await database.select(database.calendarEvents).get(),
        hasLength(2),
      );
      final preservedCursor = await database
          .select(database.syncCursors)
          .getSingle();
      expect(preservedCursor.cursorValue, committedCursor);
      expect(preservedCursor.lastFailureCode, 'InjectedLiveLaterFetchFailure');
      expect(preservedCursor.inProgressGeneration, isNull);

      final remoteBeforeQueue = await delegate.listMemberEtags(
        correlationId: 'live-offline-before-queue',
      );
      var nextPendingId = 0;
      final queuedUid = 'busymax-live-queued-$suffix@example.invalid';
      await DavPendingOperationQueue(
        database: database,
        idFactory: () => 'live-pending-${nextPendingId += 1}',
        nowUtc: () => DateTime.utc(2026, 8, 9, 12),
      ).enqueueCreate(
        accountId: discovery.accountId,
        collectionId: storedCollection.id,
        object: DavNewObject(
          uid: queuedUid,
          initialMemberName: 'busymax-live-queued-$suffix.ics',
          rawIcs: _simpleEvent(
            uid: queuedUid,
            summary: 'BusyMax queued offline',
            startLine: 'DTSTART:20260904T160000Z',
            endLine: 'DTEND:20260904T170000Z',
          ),
          componentType: 'VEVENT',
        ),
      );
      expect(await database.select(database.pendingOps).get(), hasLength(1));
      expect(
        await database.select(database.calendarEvents).get(),
        hasLength(2),
      );
      expect(
        (await delegate.listMemberEtags(
          correlationId: 'live-offline-after-queue',
        )).members.length,
        remoteBeforeQueue.members.length,
      );

      final replayNotificationObjects = <String>{};
      final replayFollowUpCollections = <String>{};
      var nextReplayId = 0;
      final replay = await DavPendingOperationsReplayer(
        database: database,
        accountId: discovery.accountId,
        objectRepository: objectRepository,
        serviceFactory: ({required account, required collection}) async =>
            _mutationService('live-offline-replay'),
        rebuildNotifications: (ids) async =>
            replayNotificationObjects.addAll(ids),
        requestFollowUpSync: (ids) async =>
            replayFollowUpCollections.addAll(ids),
        idFactory: () => 'live-replay-${nextReplayId += 1}',
        nowUtc: () => DateTime.utc(2026, 8, 9, 12),
      ).replayDueOperations();
      expect(replay.appliedCount, 1);
      expect(replay.paused, isFalse);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(
        (await database.select(database.calendarEvents).get()).map(
          (event) => event.title,
        ),
        contains('BusyMax queued offline'),
      );
      expect(replayNotificationObjects, hasLength(1));
      expect(replayFollowUpCollections, {storedCollection.id});
      expect(
        (await delegate.listMemberEtags(
          correlationId: 'live-offline-after-replay',
        )).members.length,
        remoteBeforeQueue.members.length + 1,
      );

      final baselineEvent =
          (await database.select(database.calendarEvents).get()).singleWhere(
            (event) => event.title == 'BusyMax engine baseline',
          );
      await DavPendingOperationQueue(
        database: database,
        idFactory: () => 'live-revoked-pending',
        nowUtc: () => DateTime.utc(2026, 8, 9, 12),
      ).enqueueUpdate(
        accountId: discovery.accountId,
        collectionId: storedCollection.id,
        objectId: baselineEvent.davObjectId!,
        patch: DavMutationPatch(
          target: IcalComponentKey(
            componentType: 'VEVENT',
            uid: baselineEvent.icalUid!,
          ),
          scope: DavMutationScope.object,
          operations: [
            DavPatchOperation.setText('SUMMARY', 'Must remain queued'),
          ],
        ),
      );
      final rejectedCredential = DavBasicCredential(
        username: credential.username,
        password: '${credential.password}-revoked',
      );
      final rejectedReplay = await DavPendingOperationsReplayer(
        database: database,
        accountId: discovery.accountId,
        objectRepository: objectRepository,
        serviceFactory: ({required account, required collection}) async =>
            DavConditionalMutationService(
              remoteClient: DavMutationHttpClient(
                transport: transport,
                accountId: discovery.accountId,
                collectionId: collection.id,
                credential: rejectedCredential,
              ),
            ),
        idFactory: () => 'live-rejected-replay',
        nowUtc: () => DateTime.utc(2026, 8, 9, 12),
      ).replayDueOperations();
      expect(rejectedReplay.paused, isTrue);
      expect(
        (await database.select(database.accounts).getSingle()).authState,
        'reauth_required',
      );
      final authBlocked = await database
          .select(database.pendingOps)
          .getSingle();
      expect(authBlocked.state, 'auth_blocked');
      expect(authBlocked.lastErrorCode, isNotNull);
      expect(await database.select(database.davObjects).get(), hasLength(3));
      expect(
        (await database.select(database.calendarEvents).get()).map(
          (event) => event.title,
        ),
        isNot(contains('Must remain queued')),
      );
    } finally {
      await database.close();
    }
  }

  Future<void> _createEngineEvent(
    DavCollectionDiscovery collection, {
    required String suffix,
    required String summary,
  }) async {
    final uid = 'busymax-live-engine-$suffix@example.invalid';
    final result = await _mutationService('production-engine').create(
      collectionUri: collection.requestUri,
      object: DavNewObject(
        uid: uid,
        initialMemberName: 'busymax-engine-$suffix.ics',
        rawIcs: _simpleEvent(
          uid: uid,
          summary: summary,
          startLine: 'DTSTART:20260903T160000Z',
          endLine: 'DTEND:20260903T170000Z',
        ),
        componentType: 'VEVENT',
      ),
      capabilities: collection.capabilities,
      correlationId: 'live-engine-create',
    );
    expect(result.outcome, DavMutationOutcome.succeeded);
  }

  Future<void> prepareRestartObject(
    DavCollectionDiscovery collection,
    String restartId,
  ) async {
    final remote = _collectionClient(collection, 'restart');
    final emptyPage = await remote.syncCollectionPage(
      syncToken: '',
      correlationId: 'live-restart-empty-sync',
    );
    expect(emptyPage.changedMembers, isEmpty);
    final uid = '$restartId@example.invalid';
    final result = await _mutationService('restart').create(
      collectionUri: collection.requestUri,
      object: DavNewObject(
        uid: uid,
        initialMemberName: '$restartId.ics',
        rawIcs: _simpleEvent(
          uid: uid,
          summary: 'BusyMax before restart',
          startLine: 'DTSTART:20260902T160000Z',
          endLine: 'DTEND:20260902T170000Z',
        ),
        componentType: 'VEVENT',
      ),
      capabilities: collection.capabilities,
      correlationId: 'live-restart-create',
    );
    expect(result.outcome, DavMutationOutcome.succeeded);
    final page = await remote.syncCollectionPage(
      syncToken: emptyPage.nextSyncToken,
      correlationId: 'live-restart-create-sync',
    );
    expect(page.changedMembers, hasLength(1));
  }

  Future<void> verifyRestartObject(
    DavCollectionDiscovery collection,
    String restartId,
  ) async {
    final remote = _collectionClient(collection, 'restart');
    final page = await remote.syncCollectionPage(
      syncToken: '',
      correlationId: 'live-restart-post-restart-sync',
    );
    expect(page.changedMembers, hasLength(1));
    final fetched = await remote.fetchMembers(
      page.changedMembers,
      correlationId: 'live-restart-post-restart-fetch',
      useCalendarMultiget: true,
    );
    var current = fetched.single;
    expect(current.rawIcsBody, contains('SUMMARY:BusyMax before restart'));
    final uid = '$restartId@example.invalid';
    final update = await _mutationService('restart').update(
      hrefKey: current.hrefKey,
      uri: current.requestUri,
      baselineEtag: current.etag!,
      baselineRawIcs: current.rawIcsBody!,
      patch: DavMutationPatch(
        target: IcalComponentKey(componentType: 'VEVENT', uid: uid),
        scope: DavMutationScope.object,
        operations: [
          DavPatchOperation.setText('SUMMARY', 'BusyMax after restart'),
        ],
      ),
      capabilities: collection.capabilities,
      correlationId: 'live-restart-update',
    );
    expect(update.outcome, DavMutationOutcome.succeeded);
    current = update.canonicalObject!;
    expect(current.rawIcsBody, contains('SUMMARY:BusyMax after restart'));
    final deletion = await _mutationService('restart').delete(
      hrefKey: current.hrefKey,
      uri: current.requestUri,
      baselineEtag: current.etag!,
      baselineRawIcs: current.rawIcsBody!,
      isEvent: true,
      capabilities: collection.capabilities,
      correlationId: 'live-restart-delete',
    );
    expect(deletion.outcome, DavMutationOutcome.succeeded);
  }

  Future<void> deleteCollection(Uri uri) async {
    final response = await transport.send(
      DavRequest(
        method: 'DELETE',
        uri: uri,
        accountId: 'nextcloud-live',
        correlationId: 'live-restart-delete-collection',
      ),
      credential: credential,
    );
    expect(response.statusCode, 204);
  }

  DavCollectionHttpClient _collectionClient(
    DavCollectionDiscovery collection,
    String id,
  ) => DavCollectionHttpClient(
    transport: transport,
    profile: profile,
    accountAuthority: authority,
    accountId: 'nextcloud-live',
    collectionId: id,
    collectionUri: collection.requestUri,
    credential: credential,
  );

  DavMutationHttpClient _mutationClient(String id) => DavMutationHttpClient(
    transport: transport,
    accountId: 'nextcloud-live',
    collectionId: id,
    credential: credential,
  );

  DavConditionalMutationService _mutationService(String id) =>
      DavConditionalMutationService(
        remoteClient: _mutationClient(id),
        nowUtc: () => DateTime.utc(2026, 8, 8, 12, 34, 56),
      );

  Future<void> close() async {
    for (final uri in _collectionsToDelete.reversed) {
      try {
        await transport.send(
          DavRequest(
            method: 'DELETE',
            uri: uri,
            accountId: 'nextcloud-live',
            correlationId: 'live-cleanup',
          ),
          credential: credential,
        );
      } on Object {
        // Cleanup is best effort; the unique QA-only collection can be removed
        // with `occ dav:delete-calendar` after diagnosing a failed run.
      }
    }
    client.close();
  }
}

final class _ObservedLiveRemoteClient implements DavCollectionRemoteClient {
  _ObservedLiveRemoteClient({
    required this.delegate,
    this.beforeSync,
    this.failFetchCall,
  });

  final DavCollectionRemoteClient delegate;
  final Future<void> Function(String syncToken)? beforeSync;
  final int? failFetchCall;
  final List<String> requestedTokens = [];
  int fetchCalls = 0;

  @override
  Future<DavSyncPage> syncCollectionPage({
    required String syncToken,
    required String correlationId,
    DavCancellationToken? cancellationToken,
  }) async {
    requestedTokens.add(syncToken);
    await beforeSync?.call(syncToken);
    return delegate.syncCollectionPage(
      syncToken: syncToken,
      correlationId: correlationId,
      cancellationToken: cancellationToken,
    );
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
  }) {
    fetchCalls += 1;
    if (fetchCalls == failFetchCall) {
      throw const DavException(
        kind: DavErrorKind.server,
        code: 'InjectedLiveLaterFetchFailure',
        safeMessage: 'Injected integration-test failure.',
      );
    }
    return delegate.fetchMembers(
      members,
      correlationId: correlationId,
      useCalendarMultiget: useCalendarMultiget,
      cancellationToken: cancellationToken,
    );
  }
}

final class _InjectedStatusClient extends http.BaseClient {
  _InjectedStatusClient({required this.delegate, required this.statusCode});

  final http.Client delegate;
  final int statusCode;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    calls += 1;
    if (calls == 1) {
      return Future.value(
        http.StreamedResponse(
          const Stream<List<int>>.empty(),
          statusCode,
          headers: statusCode == 429 || statusCode == 503
              ? const {'retry-after': '0'}
              : const {},
          request: request,
        ),
      );
    }
    return delegate.send(request);
  }

  @override
  void close() {
    // The fixture owns the shared delegate.
  }
}

DavCollectionDiscovery _collectionBySlug(
  DavDiscoveryResult discovery,
  String slug,
) => discovery.collections.singleWhere(
  (collection) => collection.requestUri.pathSegments.contains(slug),
);

Uri _collectionChild(Uri home, String slug) {
  final basePath = home.path.endsWith('/') ? home.path : '${home.path}/';
  return home.replace(path: '$basePath$slug/', query: null, fragment: null);
}

Future<DavException> _captureDavError(Future<Object?> operation) async {
  try {
    await operation;
  } on DavException catch (error) {
    return error;
  }
  throw TestFailure('Expected a DavException.');
}

void _expectEventPreservation(String rawIcs) {
  expect(rawIcs, contains('RRULE:FREQ=WEEKLY;COUNT=3'));
  expect(rawIcs, contains('EXDATE;TZID=America/Vancouver:20260816T090000'));
  expect(rawIcs, contains('RECURRENCE-ID;TZID=America/Vancouver'));
  expect(rawIcs, contains('X-BUSYMAX-QA;X-PARAM="alpha,beta":opaque'));
  expect('BEGIN:VALARM'.allMatches(rawIcs), hasLength(2));
  expect(rawIcs, contains('ACTION:AUDIO'));
  expect(rawIcs, contains('STATUS:CANCELLED'));
}

void _expectTaskPreservation(String rawIcs, String parentUid) {
  expect(
    IcalSemanticDocument.parse(rawIcs).components.single.parentUid,
    parentUid,
  );
  expect(rawIcs, contains('X-APPLE-SORT-ORDER:42'));
  expect(rawIcs, contains('X-OC-HIDESUBTASKS:1'));
  expect(rawIcs, contains('RRULE:FREQ=DAILY;COUNT=2'));
  expect(rawIcs, contains('X-BUSYMAX-TASK-QA:opaque'));
  expect(rawIcs, contains('BEGIN:VALARM'));
}

String _recurringEvent(String uid) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax//Nextcloud Integration Test//EN\r
BEGIN:VTIMEZONE\r
TZID:America/Vancouver\r
BEGIN:STANDARD\r
DTSTART:20251102T020000\r
TZOFFSETFROM:-0700\r
TZOFFSETTO:-0800\r
TZNAME:PST\r
END:STANDARD\r
BEGIN:DAYLIGHT\r
DTSTART:20260308T020000\r
TZOFFSETFROM:-0800\r
TZOFFSETTO:-0700\r
TZNAME:PDT\r
END:DAYLIGHT\r
END:VTIMEZONE\r
BEGIN:VEVENT\r
UID:$uid\r
DTSTAMP:20260808T120000Z\r
DTSTART;TZID=America/Vancouver:20260809T090000\r
DTEND;TZID=America/Vancouver:20260809T100000\r
RRULE:FREQ=WEEKLY;COUNT=3\r
EXDATE;TZID=America/Vancouver:20260816T090000\r
SUMMARY:BusyMax live event\r
CATEGORIES:BusyMax,CalDAV\r
X-BUSYMAX-QA;X-PARAM="alpha,beta":opaque\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER:-PT15M\r
DESCRIPTION:Visible reminder\r
END:VALARM\r
BEGIN:VALARM\r
ACTION:AUDIO\r
TRIGGER:-PT5M\r
ATTACH:Glass\r
X-ALARM-QA:opaque\r
END:VALARM\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:$uid\r
DTSTAMP:20260808T120000Z\r
RECURRENCE-ID;TZID=America/Vancouver:20260823T090000\r
DTSTART;TZID=America/Vancouver:20260823T110000\r
DTEND;TZID=America/Vancouver:20260823T120000\r
SUMMARY:BusyMax moved exception\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:$uid\r
DTSTAMP:20260808T120000Z\r
RECURRENCE-ID;TZID=America/Vancouver:20260830T090000\r
DTSTART;TZID=America/Vancouver:20260830T090000\r
DTEND;TZID=America/Vancouver:20260830T100000\r
STATUS:CANCELLED\r
SUMMARY:BusyMax cancelled exception\r
END:VEVENT\r
END:VCALENDAR\r
''';

String _simpleEvent({
  required String uid,
  required String summary,
  required String startLine,
  required String endLine,
}) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax//Nextcloud Integration Test//EN\r
BEGIN:VEVENT\r
UID:$uid\r
DTSTAMP:20260808T120000Z\r
$startLine\r
$endLine\r
SUMMARY:$summary\r
END:VEVENT\r
END:VCALENDAR\r
''';

String _parentTask(String uid) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax//Nextcloud Integration Test//EN\r
BEGIN:VTODO\r
UID:$uid\r
DTSTAMP:20260808T120000Z\r
DTSTART:20260809T160000Z\r
DUE:20260809T170000Z\r
SUMMARY:BusyMax parent task\r
STATUS:NEEDS-ACTION\r
PERCENT-COMPLETE:0\r
PRIORITY:3\r
CATEGORIES:BusyMax,Parent\r
END:VTODO\r
END:VCALENDAR\r
''';

String _childTask(String uid, String parentUid) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax//Nextcloud Integration Test//EN\r
BEGIN:VTODO\r
UID:$uid\r
DTSTAMP:20260808T120000Z\r
DTSTART;VALUE=DATE:20260810\r
DUE;VALUE=DATE:20260811\r
SUMMARY:BusyMax child task\r
STATUS:NEEDS-ACTION\r
PERCENT-COMPLETE:0\r
PRIORITY:5\r
CATEGORIES:BusyMax,Child\r
RELATED-TO;RELTYPE=PARENT:$parentUid\r
RRULE:FREQ=DAILY;COUNT=2\r
X-APPLE-SORT-ORDER:42\r
X-OC-HIDESUBTASKS:1\r
X-BUSYMAX-TASK-QA:opaque\r
BEGIN:VALARM\r
ACTION:DISPLAY\r
TRIGGER:-PT30M\r
DESCRIPTION:Task reminder\r
END:VALARM\r
END:VTODO\r
END:VCALENDAR\r
''';

String _requiredEnvironment(String name) {
  final value = Platform.environment[name]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('$name is required when $_enabledVariable=1.');
  }
  return value;
}
