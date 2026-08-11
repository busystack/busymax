import 'dart:io';

import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/auth/dav_account_onboarding_service.dart';
import 'package:busymax/src/dav/auth/nextcloud_login_flow_v2.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_models.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _enabledVariable = 'BUSYMAX_ICLOUD_LIVE';

void main() {
  final enabled = Platform.environment[_enabledVariable] == '1';

  test(
    'real Apple iCloud Calendar preserves discovery and event semantics',
    () async {
      final fixture = _LiveICloudFixture.fromEnvironment();
      addTearDown(fixture.close);

      final first = await fixture.discover('icloud-live-discovery-1');
      final second = await fixture.discover('icloud-live-discovery-2');
      expect(first.provider, BusyProvider.appleICloud);
      expect(first.service.calendarHomeHref, second.service.calendarHomeHref);
      expect(
        first.collections.map((collection) => collection.hrefKey).toSet(),
        second.collections.map((collection) => collection.hrefKey).toSet(),
      );
      expect(
        fixture.profile.isTrustedCredentialDestination(
          first.service.canonicalServiceUri,
          accountAuthority: fixture.authority,
        ),
        isTrue,
      );

      final eventCollections = first.collections
          .where((collection) => collection.eventProjectionEnabled)
          .toList();
      expect(
        eventCollections.length,
        greaterThanOrEqualTo(2),
        reason: 'Prepare at least two calendars in the dedicated QA account.',
      );
      final writable = eventCollections.firstWhere(
        (collection) => collection.capabilities.canCreateEvent,
      );
      expect(writable.capabilities.isReadOnly, isFalse);
      expect(writable.color, isNotNull);

      if (_enabledFlag('BUSYMAX_ICLOUD_LIVE_EXPECT_SHARED_WRITABLE')) {
        expect(
          eventCollections.any(
            (collection) =>
                collection.capabilities.canCreateEvent &&
                !_samePrincipal(
                  collection.ownerHref,
                  first.service.principalHref,
                ),
          ),
          isTrue,
          reason: 'Prepare a writable calendar shared into the QA account.',
        );
      }
      if (_enabledFlag('BUSYMAX_ICLOUD_LIVE_EXPECT_SHARED_READ_ONLY')) {
        expect(
          eventCollections.any(
            (collection) => collection.capabilities.isReadOnly,
          ),
          isTrue,
          reason: 'Prepare a read-only shared/subscribed QA calendar.',
        );
      }

      await fixture.verifyEvents(writable);
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 and the BUSYMAX_ICLOUD_LIVE_* credential '
              'variables to run the Apple iCloud integration test.',
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'real iCloud onboarding, credential replacement, and local removal are atomic',
    () async {
      final fixture = _LiveICloudFixture.fromEnvironment();
      addTearDown(fixture.close);
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final secrets = InMemorySecretStore();
      var nextId = 0;
      final service = DavAccountOnboardingService(
        database: database,
        secretStore: secrets,
        nextcloudLoginFlow: _unusedNextcloudLoginFlow(),
        idFactory: () => 'icloud-live-${nextId += 1}',
        discover:
            ({
              required accountId,
              required provider,
              required accountAuthority,
              required credential,
              cancellationToken,
            }) => fixture.discover(
              'icloud-live-onboarding',
              accountId: accountId,
              credential: credential,
            ),
      );

      final connected = await service.connectAppleICloud(
        email: fixture.credential.username,
        appSpecificPassword: fixture.credential.password,
      );
      expect(await database.select(database.accounts).get(), hasLength(1));
      expect(
        await database.select(database.davAccountServices).get(),
        hasLength(1),
      );
      expect(await secrets.readCredential(connected.accountId), isNotNull);
      await database
          .into(database.pendingOps)
          .insert(
            PendingOpsCompanion.insert(
              id: 'icloud-live-pending',
              accountId: connected.accountId,
              provider: const Value('apple_icloud'),
              entityType: 'event',
              operation: 'dav_update',
              operationType: const Value('dav.update'),
              requestJson: '{}',
              createdAtUtc: '2026-08-09T12:00:00.000Z',
              updatedAtUtc: '2026-08-09T12:00:00.000Z',
            ),
          );

      await service.replaceAppleAppSpecificPassword(
        accountId: connected.accountId,
        appSpecificPassword: fixture.credential.password,
      );
      expect(await database.select(database.pendingOps).get(), hasLength(1));
      expect(
        (await database.select(database.accounts).getSingle()).authState,
        'signed_in',
      );

      final removed = await service.removeAccount(connected.accountId);
      expect(removed.remoteRevocationAttempted, isFalse);
      expect(await database.select(database.accounts).get(), isEmpty);
      expect(await database.select(database.davAccountServices).get(), isEmpty);
      expect(await database.select(database.davCollections).get(), isEmpty);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect(await secrets.readCredential(connected.accountId), isNull);
      expect(await secrets.readActiveAccountId(), isNull);
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 and the BUSYMAX_ICLOUD_LIVE_* credential '
              'variables to run the Apple iCloud integration test.',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

final class _LiveICloudFixture {
  _LiveICloudFixture({
    required this.authority,
    required this.profile,
    required this.credential,
    required this.client,
    required this.transport,
  });

  factory _LiveICloudFixture.fromEnvironment() {
    final username = _requiredEnvironment('BUSYMAX_ICLOUD_LIVE_USERNAME');
    final password = _requiredEnvironment('BUSYMAX_ICLOUD_LIVE_PASSWORD');
    final profile = davProviderProfile(BusyProvider.appleICloud);
    final authority = profile.bootstrapUri;
    final client = http.Client();
    return _LiveICloudFixture(
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
  final Set<Uri> _objectsToDelete = {};

  Future<DavDiscoveryResult> discover(
    String correlationId, {
    String accountId = 'apple-icloud-live',
    DavBasicCredential? credential,
  }) => DavDiscoveryService(
    transport: transport,
    profile: profile,
    accountAuthority: authority,
    accountId: accountId,
    credential: credential ?? this.credential,
  ).discover(correlationId: correlationId);

  Future<void> verifyEvents(DavCollectionDiscovery collection) async {
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final mutations = _mutationService('icloud-events');
    final created = <DavFetchedMember>[];

    final uid = 'busymax-icloud-$suffix@example.invalid';
    var result = await mutations.create(
      collectionUri: collection.requestUri,
      object: DavNewObject(
        uid: uid,
        initialMemberName: 'busymax-icloud-$suffix.ics',
        rawIcs: _complexEvent(uid),
        componentType: 'VEVENT',
      ),
      capabilities: collection.capabilities,
      correlationId: 'icloud-live-complex-create',
    );
    expect(result.outcome, DavMutationOutcome.succeeded);
    var current = result.canonicalObject!;
    created.add(current);
    _objectsToDelete.add(current.requestUri);
    _expectComplexPreservation(current.rawIcsBody!);

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
      final variantUid = 'busymax-icloud-${variant.$1}-$suffix@example.invalid';
      final variantResult = await mutations.create(
        collectionUri: collection.requestUri,
        object: DavNewObject(
          uid: variantUid,
          initialMemberName: 'busymax-icloud-${variant.$1}-$suffix.ics',
          rawIcs: _simpleEvent(
            uid: variantUid,
            summary: 'BusyMax iCloud ${variant.$1}',
            startLine: variant.$3,
            endLine: variant.$4,
          ),
          componentType: 'VEVENT',
        ),
        capabilities: collection.capabilities,
        correlationId: 'icloud-live-${variant.$1}-create',
      );
      expect(variantResult.outcome, DavMutationOutcome.succeeded);
      final canonical = variantResult.canonicalObject!;
      created.add(canonical);
      _objectsToDelete.add(canonical.requestUri);
      expect(
        IcalSemanticDocument.parse(
          canonical.rawIcsBody!,
        ).components.single.start!.kind,
        variant.$2,
      );
    }

    final original = current;
    final remoteUpdate = await _mutationClient('icloud-events').conditionalPut(
      uri: original.requestUri,
      rawIcs: DavMutationPatch(
        target: IcalComponentKey(componentType: 'VEVENT', uid: uid),
        scope: DavMutationScope.recurrenceMaster,
        operations: [
          DavPatchOperation.setText('LOCATION', 'Apple-side location'),
        ],
      ).applyTo(original.rawIcsBody!, nowUtc: DateTime.utc(2026, 8, 9, 12)),
      correlationId: 'icloud-live-out-of-band-update',
      ifMatch: original.etag,
    );
    expect(remoteUpdate.status, DavConditionalStatus.success);

    result = await mutations.update(
      hrefKey: original.hrefKey,
      uri: original.requestUri,
      baselineEtag: original.etag!,
      baselineRawIcs: original.rawIcsBody!,
      patch: DavMutationPatch(
        target: IcalComponentKey(componentType: 'VEVENT', uid: uid),
        scope: DavMutationScope.recurrenceMaster,
        operations: [
          DavPatchOperation.setText('SUMMARY', 'BusyMax iCloud merged title'),
        ],
      ),
      capabilities: collection.capabilities,
      correlationId: 'icloud-live-disjoint-merge',
    );
    expect(result.outcome, DavMutationOutcome.succeeded);
    current = result.canonicalObject!;
    expect(current.rawIcsBody, contains('SUMMARY:BusyMax iCloud merged title'));
    expect(current.rawIcsBody, contains('LOCATION:Apple-side location'));
    _expectComplexPreservation(current.rawIcsBody!);

    final conflictBaseline = current;
    final conflictUpdate = await _mutationClient('icloud-events')
        .conditionalPut(
          uri: current.requestUri,
          rawIcs: DavMutationPatch(
            target: IcalComponentKey(componentType: 'VEVENT', uid: uid),
            scope: DavMutationScope.recurrenceMaster,
            operations: [
              DavPatchOperation.setText('SUMMARY', 'Apple conflicting title'),
            ],
          ).applyTo(current.rawIcsBody!, nowUtc: DateTime.utc(2026, 8, 9, 12)),
          correlationId: 'icloud-live-conflicting-out-of-band-update',
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
      correlationId: 'icloud-live-explicit-conflict',
    );
    expect(result.outcome, DavMutationOutcome.conflict);
    expect(
      result.conflictRemoteObject!.rawIcsBody,
      contains('SUMMARY:Apple conflicting title'),
    );
    created[0] = result.conflictRemoteObject!;

    for (final object in created) {
      final deletion = await mutations.delete(
        hrefKey: object.hrefKey,
        uri: object.requestUri,
        baselineEtag: object.etag!,
        baselineRawIcs: object.rawIcsBody!,
        isEvent: true,
        capabilities: collection.capabilities,
        correlationId: 'icloud-live-delete',
      );
      expect(deletion.outcome, DavMutationOutcome.succeeded);
      _objectsToDelete.remove(object.requestUri);
    }
  }

  DavMutationHttpClient _mutationClient(String id) => DavMutationHttpClient(
    transport: transport,
    accountId: 'apple-icloud-live',
    collectionId: id,
    credential: credential,
  );

  DavConditionalMutationService _mutationService(String id) =>
      DavConditionalMutationService(
        remoteClient: _mutationClient(id),
        nowUtc: () => DateTime.utc(2026, 8, 9, 12),
      );

  Future<void> close() async {
    for (final uri in _objectsToDelete) {
      try {
        await transport.send(
          DavRequest(
            method: 'DELETE',
            uri: uri,
            accountId: 'apple-icloud-live',
            correlationId: 'icloud-live-cleanup',
          ),
          credential: credential,
        );
      } on Object {
        // Best effort: every fixture UID and member name is unique and safe to
        // locate manually in the dedicated QA calendar after a failed run.
      }
    }
    client.close();
  }
}

NextcloudLoginFlowV2 _unusedNextcloudLoginFlow() => NextcloudLoginFlowV2(
  client: MockClient((_) async => http.Response('', 500)),
  browserLauncher: (_) async => false,
);

bool _samePrincipal(String? ownerHref, Uri principalHref) {
  if (ownerHref == null || ownerHref.trim().isEmpty) return false;
  final owner = Uri.tryParse(ownerHref);
  return (owner?.path ?? ownerHref) == principalHref.path;
}

void _expectComplexPreservation(String rawIcs) {
  expect(rawIcs, contains('RRULE:FREQ=WEEKLY;COUNT=4'));
  expect(rawIcs, contains('EXDATE;TZID=America/Vancouver:20260816T090000'));
  expect(rawIcs, contains('RDATE;TZID=America/Vancouver:20260906T090000'));
  expect(rawIcs, contains('RECURRENCE-ID;TZID=America/Vancouver'));
  expect(rawIcs, contains('STATUS:CANCELLED'));
  expect(rawIcs, contains('CATEGORIES:BusyMax,iCloud'));
  expect(rawIcs, contains('X-BUSYMAX-ICLOUD-QA;X-PARAM="alpha,beta":opaque'));
  expect('BEGIN:VALARM'.allMatches(rawIcs), hasLength(2));
  expect(rawIcs, contains('ACTION:AUDIO'));
}

String _complexEvent(String uid) =>
    '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//BusyMax//iCloud Integration Test//EN\r
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
DTSTAMP:20260809T120000Z\r
DTSTART;TZID=America/Vancouver:20260809T090000\r
DTEND;TZID=America/Vancouver:20260809T100000\r
RRULE:FREQ=WEEKLY;COUNT=4\r
EXDATE;TZID=America/Vancouver:20260816T090000\r
RDATE;TZID=America/Vancouver:20260906T090000\r
SUMMARY:BusyMax iCloud event\r
CATEGORIES:BusyMax,iCloud\r
X-BUSYMAX-ICLOUD-QA;X-PARAM="alpha,beta":opaque\r
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
DTSTAMP:20260809T120000Z\r
RECURRENCE-ID;TZID=America/Vancouver:20260823T090000\r
DTSTART;TZID=America/Vancouver:20260823T110000\r
DTEND;TZID=America/Vancouver:20260823T120000\r
SUMMARY:BusyMax moved exception\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:$uid\r
DTSTAMP:20260809T120000Z\r
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
PRODID:-//BusyMax//iCloud Integration Test//EN\r
BEGIN:VEVENT\r
UID:$uid\r
DTSTAMP:20260809T120000Z\r
$startLine\r
$endLine\r
SUMMARY:$summary\r
END:VEVENT\r
END:VCALENDAR\r
''';

bool _enabledFlag(String name) => Platform.environment[name] == '1';

String _requiredEnvironment(String name) {
  final value = Platform.environment[name]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('$name is required when $_enabledVariable=1.');
  }
  return value;
}
