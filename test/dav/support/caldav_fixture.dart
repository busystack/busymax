import 'dart:convert';

import 'caldav_qa_targets.dart';

import 'package:busymax/src/dav/ical/dav_native_import.dart';
import 'package:busymax/src/dav/ical/dav_native_export.dart';

import 'dart:io';

import 'package:busymax/src/core/auth/authorization_persistence.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/auth/dav_account_onboarding_service.dart';
import 'package:busymax/src/dav/auth/nextcloud_login_flow_v2.dart';
import 'package:busymax/src/dav/dav_provider_profile.dart';
import 'package:busymax/src/dav/discovery/dav_discovery_service.dart';
import 'package:busymax/src/dav/http/dav_account_http_client.dart';
import 'package:busymax/src/dav/http/dav_http_transport.dart';
import 'package:busymax/src/dav/mutation/dav_collection_administration.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Disposable production repositories, onboarding, leasing and sync against a
/// real Docker server. Only this fixture's client trusts its generated QA CA.
final class CalDavFixture {
  CalDavFixture(
    this.uri, {
    String? fixtureDirectory,
    this.onStage,
    this.wrapAccountClient,
    this.wrapDiscoveryClient,
    SecretStore? secretStore,
  }) : fixtureDirectory =
           fixtureDirectory ??
           Platform.environment['BUSYMAX_CALDAV_FIXTURE_DIR'] ??
           '${Directory.current.path}/test/interop/caldav/.runtime',
       secrets = secretStore ?? InMemorySecretStore();
  final Uri uri;
  final String fixtureDirectory;
  final void Function(String)? onStage;
  final http.Client Function(http.Client)? wrapAccountClient;
  final http.Client Function(http.Client)? wrapDiscoveryClient;
  late Directory directory;
  late AppDatabase database;
  final SecretStore secrets;
  late AuthorizationPersistence persistence;
  late DavAccountHttpClient client;
  late http.Client independent;
  late DavAccountOnboardingService onboarding;
  late String id, password, collectionName;
  String? collectionId;
  String? eventCollectionId;
  Uri? createdCollectionUri;
  Uri? createdEventCollectionUri;
  String username = 'alice';
  bool _storageOpened = false,
      _networkOpened = false,
      _accountCreated = false,
      _accountAttached = false;

  http.Client newClient() {
    final context = SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificates('$fixtureDirectory/ca.pem');
    return IOClient(HttpClient(context: context));
  }

  Future<void> open({String username = 'alice'}) async {
    try {
      await _open(username: username);
    } catch (error, stack) {
      try {
        await close();
      } on Object {
        /* Keep the setup failure. */
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> _open({required String username}) async {
    onStage?.call('reading fixture');
    this.username = username;
    password =
        (await calDavQaCredentials(uri, directory: fixtureDirectory))[username]
            as String;
    directory = await Directory.systemTemp.createTemp('busymax-caldav-qa-');
    database = AppDatabase(
      NativeDatabase(File('${directory.path}/busymax.sqlite')),
    );
    _storageOpened = true;
    final discoveryClient = newClient();
    independent = wrapDiscoveryClient?.call(discoveryClient) ?? discoveryClient;
    _networkOpened = true;
    onStage?.call('opening database');
    _attach();
    await database.customSelect('SELECT 1').get();
    onStage?.call('onboarding');
    final result = await onboarding.connectCalDav(
      serverUrl: uri.toString(),
      username: username,
      password: password,
    );
    id = result.accountId;
    _accountCreated = true;
    _attachAccount();
    onStage?.call('initial account synchronization');
    await synchronize(full: true);
    collectionName = 'BusyMax QA ${DateTime.now().microsecondsSinceEpoch}';
    onStage?.call('creating test collection');
    final mixed = calDavQaSupportsMixed(uri);
    final creation = await administration.create(
      collectionName,
      mixed ? const {'VEVENT', 'VTODO'} : const {'VTODO'},
    );
    if (creation != DavCollectionAdministrationOutcome.committed) {
      throw StateError('QA collection refresh failed');
    }
    final created = (await database.select(database.davCollections).get())
        .singleWhere((c) => c.displayName == collectionName);
    collectionId = created.id;
    createdCollectionUri = Uri.parse(created.requestUri);
    eventCollectionId = collectionId;
    if (!mixed) {
      await administration.create('$collectionName events', const {'VEVENT'});
      final events = (await database.select(database.davCollections).get())
          .singleWhere((c) => c.displayName == '$collectionName events');
      eventCollectionId = events.id;
      createdEventCollectionUri = Uri.parse(events.requestUri);
    }
  }

  void _attach() {
    persistence = AuthorizationPersistence(
      database: database,
      secrets: secrets,
    );
    onboarding = DavAccountOnboardingService(
      database: database,
      secretStore: secrets,
      authorizationPersistence: persistence,
      nextcloudLoginFlow: NextcloudLoginFlowV2(client: independent),
      discover:
          ({
            required accountId,
            required provider,
            required accountAuthority,
            required credential,
            cancellationToken,
          }) {
            final profile = davProviderProfile(
              provider,
              caldavServer: accountAuthority,
            );
            return DavDiscoveryService(
              transport: DavHttpTransport(
                client: independent,
                profile: profile,
                accountAuthority: accountAuthority,
              ),
              profile: profile,
              accountAuthority: accountAuthority,
              accountId: accountId,
              credential: credential,
            ).discover(
              correlationId: 'generic-account-onboarding',
              cancellationToken: cancellationToken,
            );
          },
    );
  }

  void _attachAccount() {
    client = DavAccountHttpClient(
      accountId: id,
      persistence: persistence,
      createClient: (_) {
        final client = newClient();
        return wrapAccountClient?.call(client) ?? client;
      },
    );
    _accountAttached = true;
  }

  DavCollectionAdministration get administration => DavCollectionAdministration(
    database: database,
    secrets: secrets,
    client: client,
    accountId: id,
    refresh: () => synchronize(full: true),
    requireNetwork: () async {},
  );
  CalendarRepository get calendars => CalendarRepository(
    database: database,
    localTimeZone: 'America/Vancouver',
    genericCollections: (_) => administration,
  );
  TasksRepository get tasks =>
      TasksRepository(database: database, accountId: id);

  Future<void> synchronize({bool full = false}) async {
    await DavAccountSyncEngine(
      database: database,
      secretStore: secrets,
      httpClient: client,
      accountId: id,
    ).synchronize(full: full);
  }

  Future<void> reopen() async {
    client.close();
    await database.close();
    // Rehydrate serialized credentials, not the previous object instance.
    final record = await secrets.readCredential(id);
    await secrets.saveCredential(
      id,
      SecretRecord.fromJson(
        jsonDecode(jsonEncode(record!.toJson())) as Map<String, Object?>,
      ),
    );
    database = AppDatabase(
      NativeDatabase(File('${directory.path}/busymax.sqlite')),
    );
    _attach();
    _attachAccount();
    await persistence.recover();
  }

  /// No secrets are written to the receipt. A separate native process must
  /// reopen the production secure store to attach to this private QA database.
  Map<String, Object?> restartReceipt() => {
    'databaseDirectory': directory.path,
    'id': id,
    'collectionName': collectionName,
    'collectionId': collectionId,
    'eventCollectionId': eventCollectionId,
    'createdCollectionUri': createdCollectionUri?.toString(),
    'createdEventCollectionUri': createdEventCollectionUri?.toString(),
    'username': username,
  };

  Future<void> suspendForProcessRestart() async {
    client.close();
    independent.close();
    await database.close();
  }

  Future<void> restoreAfterProcessRestart(Map<String, dynamic> receipt) async {
    directory = Directory(receipt['databaseDirectory'] as String);
    id = receipt['id'] as String;
    username = receipt['username'] as String;
    collectionName = receipt['collectionName'] as String;
    collectionId = receipt['collectionId'] as String;
    eventCollectionId = receipt['eventCollectionId'] as String;
    createdCollectionUri = Uri.parse(receipt['createdCollectionUri'] as String);
    createdEventCollectionUri = switch (receipt['createdEventCollectionUri']) {
      final String value => Uri.parse(value),
      _ => null,
    };
    database = AppDatabase(
      NativeDatabase(File('${directory.path}/busymax.sqlite')),
    );
    _storageOpened = true;
    independent = newClient();
    _networkOpened = true;
    _attach();
    await persistence.recover();
    final record =
        await persistence.readCurrentCredential(id) as CalDavSecretRecord;
    if (record.serviceAuthority != uri || record.username != username) {
      throw StateError(
        'Native QA receipt does not match the secure credential',
      );
    }
    password = record.password;
    _accountCreated = true;
    _attachAccount();
  }

  Future<http.Response> independentRequest(
    String method,
    Uri target, {
    String? body,
    Map<String, String> headers = const {},
  }) async {
    final request = http.Request(method, target)..followRedirects = false;
    request.headers.addAll({
      'authorization':
          'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      ...headers,
    });
    if (body != null) request.body = body;
    return http.Response.fromStream(await independent.send(request));
  }

  Future<List<NativeImportItemResult>> importResources(
    NextcloudNativeImportPreview preview,
  ) async {
    final importer = DavNativeImportService(database);
    if (collectionId == eventCollectionId) {
      return importer.import(
        accountId: id,
        collectionId: collectionId!,
        preview: preview,
      );
    }
    final results = <NativeImportItemResult>[];
    for (final entry in {
      eventCollectionId!: 'VEVENT',
      collectionId!: 'VTODO',
    }.entries) {
      results.addAll(
        await importer.import(
          accountId: id,
          collectionId: entry.key,
          preview: NextcloudNativeImportPreview(
            preview.resources
                .where((r) => r.componentType == entry.value)
                .toList(),
            const [],
            preview.schedulingMethod,
          ),
        ),
      );
    }
    return results;
  }

  Future<List<NativeImportResource>> exportResources() async {
    final result = <NativeImportResource>[];
    for (final collection in {collectionId!, eventCollectionId!}) {
      result.addAll(
        await DavNativeExportService(database).collection(id, collection),
      );
    }
    return result;
  }

  Future<void> close() async {
    try {
      // Fixture teardown owns this uniquely named remote collection. It also
      // cleans up after tests deliberately retaining blocked local work; product
      // collection deletion correctly refuses such queued changes.
      for (final target in [
        createdCollectionUri,
        createdEventCollectionUri,
      ].whereType<Uri>()) {
        final response = await independentRequest('DELETE', target);
        if (![200, 204, 404, 410].contains(response.statusCode)) {
          throw StateError(
            'QA remote cleanup rejected: ${response.statusCode}',
          );
        }
      }
      if (_accountCreated) await onboarding.removeAccount(id);
    } finally {
      if (_accountAttached) client.close();
      if (_networkOpened) independent.close();
      if (_storageOpened) {
        await database.close();
        await directory.delete(recursive: true);
      }
    }
  }
}
