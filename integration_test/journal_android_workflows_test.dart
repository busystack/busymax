import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/config/build_config.dart';
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
  const provider = String.fromEnvironment('BUSYMAX_JOURNAL_PROVIDER');
  const encoded = String.fromEnvironment('BUSYMAX_JOURNAL_NATIVE_FIXTURE');
  if (!const {'caldav', 'nextcloud'}.contains(provider) || encoded.isEmpty) {
    throw StateError(
      'Configure the Android journal provider and private fixture.',
    );
  }
  {
    testWidgets('Android journal collection and editor on $provider', (
      tester,
    ) async {
      expect(Platform.isAndroid, isTrue);
      final fixture = jsonDecode(utf8.decode(base64Decode(encoded))) as Map;
      final authority = Uri.parse(fixture['authority'] as String);
      expect(authority.scheme, 'https');
      final username = fixture['username'] as String;
      final password = fixture['password'] as String;
      final SecretRecord secret = provider == 'caldav'
          ? CalDavSecretRecord(
              serviceAuthority: authority,
              username: username,
              password: password,
            )
          : NextcloudSecretRecord(
              canonicalServer: authority,
              loginName: username,
              appPassword: password,
            );
      final credentialAuthority =
          (secret as DavCertificateCredential).certificateAuthority;
      http.Client client() => IOClient(
        HttpClient(
          context: SecurityContext(withTrustedRoots: true)
            ..setTrustedCertificatesBytes(utf8.encode(fixture['ca'] as String)),
        ),
      );
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('journal-android-'),
      ))!;
      final database = AppDatabase(
        NativeDatabase(File('${directory.path}/qa.sqlite')),
      );
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
          buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
          initialAppSettingsProvider.overrideWithValue(AppSettings.defaults()),
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
                  authority: credentialAuthority.toString(),
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
          await secrets.saveCredential(accountId, secret);
          await sync(full: true);
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const AndroidBusyMaxApp(),
          ),
        );
        final menu = find.byKey(const ValueKey('android-workspace-menu'));
        await _until(tester, menu);
        await tester.tap(menu);
        await _until(tester, find.text('Journals'));
        await tester.tap(find.text('Journals'));
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

        await tester.tap(find.text('New entry'));
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
        await _editorAction(tester, find.widgetWithText(FilledButton, 'Save'));
        await _until(tester, find.textContaining('Journal café'));
        await _refresh(tester);
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
        await _refresh(tester);
        await _until(tester, find.textContaining('Peer edit'));
        await tester.enterText(_input('Search'), 'second body');
        await _until(tester, find.textContaining('Peer edit'));
        await tester.tap(find.textContaining('Peer edit'));
        await _until(tester, _input('Title'));
        await tester.enterText(_input('Title'), 'Local edit');
        await _editorAction(
          tester,
          find.widgetWithText(OutlinedButton, 'Close'),
        );
        await _until(tester, _input('Search'));
        expect(
          tester.widget<TextField>(_input('Search')).controller?.text,
          'second body',
        );
        expect(find.textContaining('Peer edit'), findsOneWidget);
        await tester.tap(find.textContaining('Peer edit'));
        await _until(tester, _input('Title'));
        expect(
          tester.widget<TextField>(_input('Title')).controller?.text,
          'Local edit',
        );
        await _editorAction(tester, find.widgetWithText(FilledButton, 'Save'));
        await _until(tester, find.textContaining('Local edit'));
        expect(
          tester.widget<TextField>(_input('Search')).controller?.text,
          'second body',
        );
        await tester.enterText(_input('Search'), 'absent from journal');
        await _until(tester, find.textContaining('Local edit'), absent: true);
        await tester.enterText(_input('Search'), '');
        await _until(tester, find.textContaining('Local edit'));
        await _refresh(tester);
        final edited = (await tester.runAsync(
          () => request('GET', object.requestUri),
        ))!;
        expect(edited.statusCode, 200);
        expect(edited.body, contains('SUMMARY:Local edit'));
        expect(edited.body, contains('DESCRIPTION:First body'));
        expect(edited.body, contains('DESCRIPTION:Second body'));

        await tester.tap(find.textContaining('Local edit'));
        await _until(tester, _input('Title'));
        await _editorAction(
          tester,
          find.widgetWithText(OutlinedButton, 'Delete'),
        );
        await _editorAction(
          tester,
          find.widgetWithText(
            OutlinedButton,
            'Delete the entire entry and its recurrence?',
          ),
        );
        await _until(tester, _input('Search'));
        await _until(tester, find.textContaining('Local edit'), absent: true);
        await _refresh(tester);
        final deleted = (await tester.runAsync(
          () => request('GET', object.requestUri),
        ))!;
        expect(deleted.statusCode, 404);
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
            await directory.delete(recursive: true);
          }
        });
      }
    });
  }
}

Finder _input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _editorAction(WidgetTester tester, Finder action) async {
  await tester.scrollUntilVisible(
    action,
    300,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(action);
}

Future<void> _refresh(WidgetTester tester) async {
  final enabled = find.byWidgetPredicate(
    (widget) =>
        widget is OutlinedButton &&
        widget.onPressed != null &&
        widget.child is Text &&
        (widget.child as Text).data == 'Refresh',
  );
  await _until(tester, enabled);
  await tester.tap(enabled);
  await tester.pump();
  await _until(tester, enabled);
}

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
