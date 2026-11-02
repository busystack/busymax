import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:http/http.dart' as http;
import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/providers/account_authority.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_repository.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/http/dav_account_http_client.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_collection_service.dart';
import 'package:busymax/src/dav/ical/dav_native_import.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_collection_mutation_helpers.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';

/// Disposable accounts only. Uses production discovery, account-scoped TLS,
/// the normal mutation queue, and the complete account synchronization engine.
final class NextcloudExtendedFixture {
  NextcloudExtendedFixture({Map<String, String>? environment})
    : environment = environment ?? Platform.environment;
  final Map<String, String> environment;
  final database = AppDatabase.memoryForTests();
  final secrets = InMemorySecretStore();
  final factory = NextcloudHttpClientFactory(requireNetwork: () async {});
  final standard = http.Client();
  late final AuthorizationPersistence persistence;
  late final DavAccountHttpClient client;
  late final Uri authority;
  late final NextcloudSecretRecord secret;
  late final String id, uid, title;
  late final NextcloudCollectionService collections;
  late final DavCollection collection;
  late final DavHttpTransport transport;
  late final Uri created;
  void Function()? stop;
  static Future<NextcloudExtendedFixture> open({
    List<String> components = const ['VEVENT'],
    String? username,
    String prefix = 'BUSYMAX_NEXTCLOUD_LIVE',
    Map<String, String>? environment,
  }) async {
    final f = NextcloudExtendedFixture(environment: environment);
    try {
      await f.initialize(
        components: components,
        username: username,
        prefix: prefix,
      );
      return f;
    } catch (_) {
      await f.close();
      rethrow;
    }
  }

  Future<void> initialize({
    required List<String> components,
    String? username,
    String prefix = 'BUSYMAX_NEXTCLOUD_LIVE',
  }) async {
    String env(String k) => environment['${prefix}_$k']!;
    authority = Uri.parse(normalizeNextcloudServerAuthority(env('URL')));
    id = 'qa-${DateTime.now().microsecondsSinceEpoch}';
    uid = '$id@example.invalid';
    title = 'BusyMax fixture $id';
    final mode = environment['${prefix}_TRUST_MODE'] ?? 'standard';
    NextcloudTrustPolicy? policy;
    if (mode != 'standard') {
      final pem = environment['${prefix}_TLS_CERT_PEM'];
      final material = pem == null
          ? File(env('TLS_CERT')).readAsBytesSync()
          : utf8.encode(pem);
      if (material.length > NextcloudCertificate.maximumBytes) {
        throw StateError('Oversized disposable certificate fixture.');
      }
      policy = NextcloudTrustPolicy.approve(
        owner: id,
        installation: authority,
        mode: switch (mode) {
          'private_ca' => NextcloudTrustMode.privateCa,
          'pinned_leaf' => NextcloudTrustMode.pinnedLeaf,
          _ => throw StateError('Unsupported live trust mode.'),
        },
        certificates: NextcloudCertificate.import(material),
        generation: id,
      );
    }
    secret = NextcloudSecretRecord(
      canonicalServer: authority,
      loginName: username ?? env('USERNAME'),
      appPassword: env('PASSWORD'),
      trustPolicy: policy,
    );
    persistence = AuthorizationPersistence(
      database: database,
      secrets: secrets,
    );
    stop = persistence.observeNextcloudInvalidation(factory.invalidate);
    final profile = davProviderProfile(
      BusyProvider.nextcloud,
      nextcloudServer: authority,
    );
    final raw = factory.create(owner: id, authority: authority, policy: policy);
    final basic = DavBasicCredential(
      username: secret.loginName,
      password: secret.appPassword,
    );
    final temporary = DavHttpTransport(
      client: raw,
      profile: profile,
      accountAuthority: authority,
    );
    addTearDown(raw.close);
    final first = await DavDiscoveryService(
      transport: temporary,
      profile: profile,
      accountAuthority: authority,
      accountId: id,
      credential: basic,
    ).discover(correlationId: id);
    created = davCollectionUri(first.service.calendarHomeHref)
        .resolve('busymax-$id/');
    final response = await temporary.send(
      DavRequest.xml(
        method: 'MKCALENDAR',
        uri: created,
        accountId: id,
        correlationId: id,
        body:
            '<c:mkcalendar xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:"><d:set><d:prop><d:displayname>$title</d:displayname><c:supported-calendar-component-set>${components.map((c) => '<c:comp name="$c"/>').join()}</c:supported-calendar-component-set></d:prop></d:set></c:mkcalendar>',
      ),
      credential: basic,
    );
    expect(
      response.statusCode,
      201,
      reason: 'Disposable calendar creation: ${response.bodyText}',
    );
    final discovery = await DavDiscoveryService(
      transport: temporary,
      profile: profile,
      accountAuthority: authority,
      accountId: id,
      credential: basic,
    ).discover(correlationId: id);
    await persistence.commit(
      accountId: id,
      expectedGeneration: 0,
      candidate: secret,
      persistAccount: () async {
        await AccountsRepository(database: database).upsertSignedInAccount(
          id: id,
          provider: BusyProvider.nextcloud,
          providerAccountId: secret.loginName,
          authority: authority.toString(),
          credentialKind: secret.kind,
          displayName: 'Isolated QA',
          grantedScopes: '',
        );
        await DavDiscoveryRepository(database: database)
            .commitSuccessfulInventory(discovery);
      },
    );
    raw.close();
    client = DavAccountHttpClient(
      accountId: id,
      persistence: persistence,
      createClient: (record) {
        final secret = record as NextcloudSecretRecord;
        return factory.create(
          owner: id,
          authority: secret.canonicalServer,
          policy: secret.trustPolicy,
        );
      },
    );
    transport = DavHttpTransport(
      client: client,
      profile: profile,
      accountAuthority: authority,
    );
    collection = await (database.select(
      database.davCollections,
    )..where((r) => r.requestUri.equals(created.toString()))).getSingle();
    collections = NextcloudCollectionService(
      database: database,
      secrets: secrets,
      client: client,
      accountId: id,
      requireNetwork: () async {},
      refresh: synchronize,
    );
  }

  Future<DavObject> importEvent() async {
    final preview = NextcloudNativeImportPreview.parse(
      IcalDocument.parse(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VEVENT\r\nUID:$uid\r\nDTSTAMP:20261031T000000Z\r\nDTSTART:20261101T120000Z\r\nDTEND:20261101T130000Z\r\nSUMMARY:$title\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      ),
    );
    final imported = await DavNativeImportService(database)
        .import(accountId: id, collectionId: collection.id, preview: preview);
    expect(imported.single.status, NativeImportItemStatus.queued);
    final replay = await DavPendingOperationsReplayer(
      database: database,
      accountId: id,
      objectRepository: DavObjectRepository(database: database),
      serviceFactory: ({required account, required collection}) async =>
          DavConditionalMutationService(
            remoteClient: DavMutationHttpClient(
              transport: transport,
              accountId: id,
              collectionId: collection.id,
              credential: DavBasicCredential(
                username: secret.loginName,
                password: secret.appPassword,
              ),
            ),
          ),
    ).replayDueOperations();
    expect(replay.appliedCount, 1);
    return (database.select(database.davObjects)..where(
          (r) =>
              r.collectionId.equals(collection.id) & r.primaryUid.equals(uid),
        ))
        .getSingle();
  }

  Future<void> synchronize() async {
    await DavAccountSyncEngine(
      database: database,
      secretStore: secrets,
      httpClient: client,
      accountId: id,
    ).synchronize(full: true);
  }

  Future<DavObject> importRaw(String raw, {String? objectUid}) async {
    final preview = NextcloudNativeImportPreview.parse(IcalDocument.parse(raw));
    final result = await DavNativeImportService(database)
        .import(accountId: id, collectionId: collection.id, preview: preview);
    expect(result.single.status, NativeImportItemStatus.queued);
    await synchronize();
    return (database.select(database.davObjects)..where(
          (r) =>
              r.collectionId.equals(collection.id) &
              r.primaryUid.equals(objectUid ?? uid),
        ))
        .getSingle();
  }

  Future<DavObject> meetingObject(String meetingUid) async {
    final objects =
        await (database.select(database.davObjects)..where(
              (r) =>
                  r.primaryUid.equals(meetingUid) &
                  r.serverDeleted.equals(false),
            ))
            .get();
    final calendars =
        await (database.select(database.davCollections)..where(
              (r) =>
                  r.eventProjectionEnabled.equals(true) &
                  r.serverMissing.equals(false),
            ))
            .get();
    return objects.singleWhere(
      (o) => calendars.any((c) => c.id == o.collectionId),
    );
  }

  Future<void> close() async {
    try {
      await (await collections.openContext()).send(
        'DELETE',
        created,
        headers: const {
          'X-NC-CalDAV-No-Trashbin': '1',
          'X-NC-Scheduling': 'false',
        },
      );
    } catch (_) {}
    stop?.call();
    factory.close();
    standard.close();
    await database.close();
  }
}
