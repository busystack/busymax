import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/domain/account_connection_state.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/sync/domain_sync_schedule.dart';
import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';

import '../test/support/memory_settings_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final provider in ['caldav', 'nextcloud']) {
    testWidgets('Linux journal collection and editor on $provider', (
      tester,
    ) async {
      final path = Platform.environment['BUSYMAX_JOURNAL_LIVE_FIXTURE'];
      if (path == null || path.isEmpty) {
        throw StateError('Set BUSYMAX_JOURNAL_LIVE_FIXTURE.');
      }
      final fixture =
          (jsonDecode(File(path).readAsStringSync()) as Map)[provider] as Map;
      final authority = Uri.parse(fixture['authority'] as String);
      expect(authority.scheme, 'https');
      final username = fixture['username'] as String;
      final password = fixture['password'] as String;
      http.Client client() => IOClient(
        HttpClient(
          context: SecurityContext(withTrustedRoots: true)
            ..setTrustedCertificates(fixture['caFile'] as String),
        ),
      );
      final database = AppDatabase(NativeDatabase.memory());
      final secrets = InMemorySecretStore();
      final accountClient = client();
      final peer = client();
      final network = NetworkConnectivityMonitor.withoutPlatformObservation();
      final collectionName = 'Journal QA ${const Uuid().v4()}';
      const accountId = 'native-journal-fixture';
      DavCollection? collection;
      Future<http.Response> request(
        String method,
        String target, {
        String? body,
        Map<String, String> headers = const {},
      }) async {
        final uri = Uri.parse(target);
        expect(uri.origin, authority.origin);
        final auth = base64Encode(utf8.encode('$username:$password'));
        final message = http.Request(method, uri)
          ..followRedirects = false
          ..headers.addAll({'Authorization': 'Basic $auth', ...headers});
        if (body != null) message.body = body;
        return http.Response.fromStream(await peer.send(message));
      }

      Future<void> sync({bool full = false, String? collectionId}) async {
        await DavAccountSyncEngine(
          database: database,
          secretStore: secrets,
          httpClient: accountClient,
          accountId: accountId,
        ).synchronize(full: full, collectionId: collectionId);
      }

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          secretStoreProvider.overrideWithValue(secrets),
          localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          localTimeZoneProvider.overrideWithValue('UTC'),
          networkConnectivityMonitorProvider.overrideWithValue(network),
          davAccountHttpClientProvider.overrideWith((ref, id) => accountClient),
          signedInSyncRunnerProvider.overrideWithValue(
            (_, full) => sync(full: full),
          ),
          manualSyncRunnerProvider.overrideWithValue((
            scope, {
            strategy = SyncStrategy.ordinary,
          }) async {
            await sync(collectionId: scope.resourceId);
            return SyncOutcome((
              scope: scope,
              origin: SyncTrigger.manual,
              strategy: strategy,
            ), SyncDisposition.completed);
          }),
        ],
      );
      tester.testTextInput.register();
      try {
        await tester.runAsync(() async {
          await database
              .into(database.accounts)
              .insert(
                AccountsCompanion.insert(
                  id: accountId,
                  provider: provider,
                  authority: authority.toString(),
                  providerAccountId: username,
                  credentialKind: provider == 'caldav'
                      ? 'caldav_password'
                      : 'nextcloud_app_password',
                  authState: Value(
                    AccountConnectionState.connected.storageValue,
                  ),
                  createdAtUtc: '2026-11-26T00:00:00Z',
                  updatedAtUtc: '2026-11-26T00:00:00Z',
                ),
              );
          await secrets.saveCredential(
            accountId,
            provider == 'caldav'
                ? CalDavSecretRecord(
                    serviceAuthority: authority,
                    username: username,
                    password: password,
                  )
                : NextcloudSecretRecord(
                    canonicalServer: authority,
                    loginName: username,
                    appPassword: password,
                  ),
          );
          await sync(full: true);
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const LinuxBusyMaxApp(),
          ),
        );
        container.read(appRouterProvider).go('/journals');
        await _until(tester, find.text('New journal collection'));
        await tester.tap(find.text('New journal collection'));
        await tester.pump();
        await tester.enterText(_input('Title'), collectionName);
        await tester.tap(find.text('Save'));
        await _until(tester, find.text('Save'), absent: true);
        collection = await tester.runAsync(
          () async => (await database.select(database.davCollections).get())
              .singleWhere((row) => row.displayName == collectionName),
        );
        expect(collection!.supportedComponentMask, 8);
        final remote = (await tester.runAsync(
          () => request(
            'PROPFIND',
            collection!.requestUri,
            headers: const {'Depth': '0', 'Content-Type': 'application/xml'},
            body: '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:supported-calendar-component-set/></d:prop></d:propfind>',
          ),
        ))!;
        expect(remote.statusCode, 207);
        expect(remote.body, contains('VJOURNAL'));

        await tester.tap(find.text('New journal'));
        await _until(tester, _input('Title'));
        await tester.enterText(_input('Title'), 'Journal café');
        await tester.tap(find.text('Add description'));
        await tester.pump();
        await tester.enterText(_input('Description').first, 'First body');
        await tester.ensureVisible(find.text('Add description'));
        await tester.tap(find.text('Add description'));
        await tester.pump();
        await tester.ensureVisible(_input('Description').last);
        await tester.enterText(_input('Description').last, 'Second body');
        final save = find.widgetWithText(BusyMaxPushButton, 'Save');
        await tester.scrollUntilVisible(save, 300);
        await tester.tap(save);
        await _until(tester, find.textContaining('Journal café'));
        await tester.tap(find.text('Refresh'));
        await _until(tester, find.textContaining('Pending sync'), absent: true);

        final object = (await tester.runAsync(
          () async => (await database.select(database.davObjects).get())
              .singleWhere((row) => row.collectionId == collection!.id),
        ))!;
        final created = (await tester.runAsync(
          () => request('GET', object.requestUri),
        ))!;
        expect(created.statusCode, 200);
        expect(created.body, contains('BEGIN:VJOURNAL'));
        expect(created.body, contains('DESCRIPTION:First body'));
        expect(created.body, contains('DESCRIPTION:Second body'));
        expect(created.body, isNot(contains('DTSTART')));
        final peerChange = created.body.replaceFirst(
          'SUMMARY:Journal café',
          'SUMMARY:Peer edit',
        );
        expect(peerChange, isNot(created.body));
        final changed = (await tester.runAsync(
          () => request(
            'PUT',
            object.requestUri,
            body: peerChange,
            headers: {
              'Content-Type': 'text/calendar; charset=utf-8',
              'If-Match': created.headers['etag']!,
            },
          ),
        ))!;
        expect(changed.statusCode, anyOf(200, 204));
        await tester.tap(find.text('Refresh'));
        await _until(tester, find.textContaining('Peer edit'));
        await tester.enterText(_input('Search'), 'second body');
        await _until(tester, find.textContaining('Peer edit'));
      } finally {
        await tester.pumpWidget(const SizedBox());
        tester.testTextInput.unregister();
        container.dispose();
        await tester.runAsync(() async {
          try {
            collection ??=
                (await database.select(database.davCollections).get())
                    .where((row) => row.displayName == collectionName)
                    .firstOrNull;
            if (collection != null) {
              final response = await request('DELETE', collection!.requestUri);
              expect(response.statusCode, anyOf(200, 204));
            }
          } finally {
            accountClient.close();
            peer.close();
            await network.dispose();
            await database.close();
          }
        });
      }
    });
  }
}

Finder _input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _until(
  WidgetTester tester,
  Finder finder, {
  bool absent = false,
}) async {
  for (var attempt = 0; attempt < 240; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty == absent) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(finder, absent ? findsNothing : findsWidgets);
}
