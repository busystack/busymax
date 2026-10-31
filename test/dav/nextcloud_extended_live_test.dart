import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
import 'package:busymax/src/dav/trust/nextcloud_account_http_client.dart';
import 'package:busymax/src/dav/trust/nextcloud_certificate.dart';
import 'package:busymax/src/dav/trust/nextcloud_http_client_factory.dart';
import 'package:busymax/src/dav/trust/nextcloud_trust_policy.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_collection_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_native_import.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_trash_service.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_service.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_collection_mutation_helpers.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';

const _enabledVariable = 'BUSYMAX_NEXTCLOUD_EXTENDED_LIVE';

void main() {
  final enabled = Platform.environment[_enabledVariable] == '1';
  test(
    'real native import queues and commits through account-scoped HTTPS',
    () async {
      final f = await _Fixture.open();
      addTearDown(f.close);
      final object = await f.importEvent();
      final response = await (await f.collections.openContext()).send(
        'GET',
        Uri.parse(object.requestUri),
      );
      expect(response.statusCode, 200);
      expect(response.bodyText, contains(f.uid));
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 with disposable HTTPS live-fixture credentials.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'real trash discovers, restores, and permanently removes its own imported object',
    () async {
      final f = await _Fixture.open();
      addTearDown(f.close);
      final object = await f.importEvent();
      final context = await f.collections.openContext();
      expect(
        (await context.send('DELETE', Uri.parse(object.requestUri))).statusCode,
        204,
      );
      final trash = NextcloudTrashService(f.collections);
      final removed = (await trash.list()).items.singleWhere(
        (i) => i.title == f.title,
      );
      expect(await trash.restore(removed), isNotNull);
      expect(
        (await context.send('GET', Uri.parse(object.requestUri))).statusCode,
        200,
      );
      expect(
        (await context.send('DELETE', Uri.parse(object.requestUri))).statusCode,
        204,
      );
      final deleted = (await trash.list()).items.singleWhere(
        (i) => i.title == f.title,
      );
      await trash.permanentlyDelete(deleted);
      expect(
        (await trash.list()).items.where((i) => i.title == f.title),
        isEmpty,
      );
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 with disposable HTTPS live-fixture credentials.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'real scheduling free-busy and inbox use the scoped account client',
    () async {
      final f = await _Fixture.open();
      addTearDown(f.close);
      final scheduling = NextcloudSchedulingService(f.collections);
      final result = await scheduling.freeBusy(
        collectionId: f.collection.id,
        startUtc: DateTime.utc(2026, 11, 1),
        endUtc: DateTime.utc(2026, 11, 2),
        recipients: [
          Platform.environment['BUSYMAX_NEXTCLOUD_EXTENDED_LIVE_RECIPIENT']!,
        ],
      );
      expect(result, isNotEmpty);
      expect(result.single.status, startsWith('2.'));
      expect(
        await scheduling.inbox(f.collection.id),
        isA<List<NextcloudInboxMessage>>(),
      );
    },
    skip: enabled
        ? false
        : 'Set $_enabledVariable=1 with disposable HTTPS live-fixture credentials.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

final class _Fixture {
  final database = AppDatabase.memoryForTests();
  final secrets = InMemorySecretStore();
  final factory = NextcloudHttpClientFactory(requireNetwork: () async {});
  final standard = http.Client();
  late final AuthorizationPersistence persistence;
  late final NextcloudAccountHttpClient client;
  late final Uri authority;
  late final NextcloudSecretRecord secret;
  late final String id, uid, title;
  late final NextcloudCollectionService collections;
  late final DavCollection collection;
  late final DavHttpTransport transport;
  late final Uri created;
  void Function()? stop;
  static Future<_Fixture> open() async {
    final f = _Fixture();
    try {
      await f.initialize();
      return f;
    } catch (_) {
      await f.close();
      rethrow;
    }
  }

  Future<void> initialize() async {
    String env(String k) => Platform.environment['BUSYMAX_NEXTCLOUD_LIVE_$k']!;
    authority = Uri.parse(normalizeNextcloudServerAuthority(env('URL')));
    id = 'qa-${DateTime.now().microsecondsSinceEpoch}';
    uid = '$id@example.invalid';
    title = 'BusyMax fixture $id';
    final mode =
        Platform.environment['BUSYMAX_NEXTCLOUD_LIVE_TRUST_MODE'] ?? 'standard';
    NextcloudTrustPolicy? policy;
    if (mode != 'standard') {
      final material = File(env('TLS_CERT'));
      if (material.lengthSync() > NextcloudCertificate.maximumBytes) {
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
        certificates: NextcloudCertificate.import(material.readAsBytesSync()),
        generation: id,
      );
    }
    secret = NextcloudSecretRecord(
      canonicalServer: authority,
      loginName: env('USERNAME'),
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
            '<c:mkcalendar xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:d="DAV:"><d:set><d:prop><d:displayname>$title</d:displayname><c:supported-calendar-component-set><c:comp name="VEVENT"/></c:supported-calendar-component-set></d:prop></d:set></c:mkcalendar>',
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
    client = NextcloudAccountHttpClient(
      accountId: id,
      persistence: persistence,
      factory: factory,
      standardClient: standard,
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
      refresh: () async {},
    );
  }

  Future<DavObject> importEvent() async {
    final preview = NextcloudNativeImportPreview.parse(
      IcalDocument.parse(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax QA//EN\r\nBEGIN:VEVENT\r\nUID:$uid\r\nDTSTAMP:20261031T000000Z\r\nDTSTART:20261101T120000Z\r\nDTEND:20261101T130000Z\r\nSUMMARY:$title\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n',
      ),
    );
    final imported = await NextcloudNativeImportService(database)
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
    return database.select(database.davObjects).getSingle();
  }

  Future<void> close() async {
    try {
      await (await collections.openContext()).send('DELETE', created);
    } catch (_) {}
    stop?.call();
    factory.close();
    standard.close();
    await database.close();
  }
}
