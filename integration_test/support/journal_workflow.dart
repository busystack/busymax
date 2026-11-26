import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/dav/sync/dav_account_sync_engine.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/domain/account_connection_state.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/sync/domain_sync_schedule.dart';
import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';

import '../../test/support/memory_settings_store.dart';
import 'caldav_native_secret_store.dart';

typedef JournalTestButton = Finder Function(String label, bool primary);

enum JournalRestartStage { queue, replay }

void runJournalWorkflow({
  required String platform,
  required String provider,
  required bool Function() isNative,
  required Future<Map<String, Object?>> Function() fixture,
  required Widget Function() app,
  required Future<void> Function(WidgetTester, ProviderContainer) openJournals,
  required Finder Function(String) input,
  required JournalTestButton button,
  required Finder Function() enabledRefresh,
  JournalRestartStage? restart,
  Directory? persistentProfile,
}) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final description = restart == null
      ? '$platform journal collection and editor on $provider'
      : '$platform offline journal ${restart.name} across processes on $provider';
  testWidgets(description, (tester) async {
    expect(isNative(), isTrue);
    final profile = (await tester.runAsync(fixture))!;
    final authority = Uri.parse(profile['authority'] as String);
    expect(authority.scheme, 'https');
    final username = profile['username'] as String;
    final password = profile['password'] as String;
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
          ..setTrustedCertificatesBytes(utf8.encode(profile['ca'] as String)),
      ),
    );
    final profileDirectory = persistentProfile == null
        ? null
        : Directory('${persistentProfile.path}/$provider');
    final receipt = profileDirectory == null
        ? null
        : File('${profileDirectory.path}/journal-restart.json');
    final previous = restart == JournalRestartStage.replay
        ? (jsonDecode(receipt!.readAsStringSync()) as Map)
              .cast<String, Object?>()
        : null;
    if (restart == JournalRestartStage.queue) {
      expect(receipt!.existsSync(), isFalse);
      profileDirectory!.createSync(recursive: true);
    }
    final database = AppDatabase(
      profileDirectory == null
          ? NativeDatabase.memory()
          : NativeDatabase(File('${profileDirectory.path}/journal.sqlite')),
    );
    final SecretStore secrets = profileDirectory == null
        ? InMemorySecretStore()
        : SecureSecretStore(
            CalDavQaSecureStorage(
              'busymax.qa.journal.${sha256.convert(utf8.encode(profileDirectory.path))}.$provider.',
            ),
          );
    final accountClient = client();
    final peer = client();
    final network = NetworkConnectivityMonitor.withoutPlatformObservation();
    final collectionName =
        previous?['collectionName'] as String? ??
        'Journal QA ${const Uuid().v4()}';
    const accountId = 'native-journal-fixture';
    DavCollection? collection;
    var online = restart != JournalRestartStage.replay;
    var savedForRestart = false;
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
      if (!online) return;
      await DavAccountSyncEngine(
        database: database,
        secretStore: secrets,
        httpClient: accountClient,
        accountId: accountId,
      ).synchronize(full: full, collectionId: collectionId);
    }

    final container = ProviderContainer(
      overrides: [
        if (Platform.isAndroid)
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
      if (restart == JournalRestartStage.replay) {
        expect(previous!['pid'], isNot(pid));
        await tester.runAsync(() async {
          final credential = await secrets.readCredential(accountId);
          expect(credential, isA<DavCertificateCredential>());
          collection = (await database.select(database.davCollections).get())
              .singleWhere((row) => row.id == previous['collectionId']);
          expect(
            await database.select(database.pendingOps).get(),
            hasLength(3),
          );
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: app()),
        );
        await openJournals(tester, container);
        await waitJournalWidget(
          tester,
          find.textContaining('Offline new entry'),
        );
        expect(find.textContaining('Offline edited entry'), findsOneWidget);
        expect(find.textContaining('Offline delete control'), findsNothing);
        final editedHref = previous['editedHref'] as String;
        final deletedHref = previous['deletedHref'] as String;
        final previousEdit = (await tester.runAsync(
          () => request('GET', editedHref),
        ))!;
        expect(previousEdit.body, contains('SUMMARY:Local edit'));
        expect(
          (await tester.runAsync(() => request('GET', deletedHref)))!
              .statusCode,
          200,
        );
        online = true;
        await _refresh(tester, enabledRefresh());
        await waitJournalWidget(
          tester,
          find.textContaining('Pending sync'),
          absent: true,
        );
        await tester.runAsync(() async {
          final after = await request('GET', editedHref);
          expect(after.statusCode, 200);
          expect(after.body, contains('SUMMARY:Offline edited entry'));
          expect(after.body, contains('DESCRIPTION:Second body'));
          expect((await request('GET', deletedHref)).statusCode, 404);
          final rows = (await database.select(database.davObjects).get()).where(
            (object) =>
                object.collectionId == collection!.id &&
                object.requestUri != editedHref &&
                object.requestUri != deletedHref,
          );
          final created = await request('GET', rows.single.requestUri);
          expect(created.statusCode, 200);
          expect(created.body, contains('SUMMARY:Offline new entry'));
          expect(await database.select(database.pendingOps).get(), isEmpty);
        });
        debugPrint(
          'JOURNAL_WORKFLOW_CASE $provider offline-process-restart PASS',
        );
        return;
      }
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
                authState: Value(AccountConnectionState.connected.storageValue),
                createdAtUtc: '2026-11-26T00:00:00Z',
                updatedAtUtc: '2026-11-26T00:00:00Z',
              ),
            );
        await secrets.saveCredential(accountId, secret);
        await sync(full: true);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: app()),
      );
      await openJournals(tester, container);
      await waitJournalWidget(tester, find.text('New journal collection'));
      await tester.tap(find.text('New journal collection'));
      await tester.pump();
      await tester.enterText(input('Title'), collectionName);
      await tester.tap(find.text('Save'));
      await waitJournalWidget(tester, find.text('Save'), absent: true);
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
      debugPrint('JOURNAL_WORKFLOW_CASE $provider collection-create PASS');

      await tester.tap(find.text('New entry'));
      await waitJournalWidget(tester, input('Title'));
      await tester.enterText(input('Title'), 'Journal café');
      await tester.tap(find.text('Add description'));
      await tester.pump();
      await tester.enterText(input('Description').first, 'First body');
      await tester.ensureVisible(find.text('Add description'));
      await tester.tap(find.text('Add description'));
      await tester.pump();
      await tester.ensureVisible(input('Description').last);
      await tester.enterText(input('Description').last, 'Second body');
      await _editorAction(tester, button('Save', true));
      await waitJournalWidget(tester, find.textContaining('Journal café'));
      await _refresh(tester, enabledRefresh());
      await waitJournalWidget(
        tester,
        find.textContaining('Pending sync'),
        absent: true,
      );

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
      debugPrint(
        'JOURNAL_WORKFLOW_CASE $provider undated-repeated-description PASS',
      );
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
      await _refresh(tester, enabledRefresh());
      await waitJournalWidget(tester, find.textContaining('Peer edit'));
      await tester.enterText(input('Search'), 'second body');
      await waitJournalWidget(tester, find.textContaining('Peer edit'));
      await tester.tap(find.textContaining('Peer edit'));
      await waitJournalWidget(tester, input('Title'));
      await tester.enterText(input('Title'), 'Local edit');
      await _editorAction(tester, button('Close', false));
      await waitJournalWidget(tester, input('Search'));
      expect(inputValue(tester, input('Search')), 'second body');
      expect(find.textContaining('Peer edit'), findsOneWidget);
      await tester.tap(find.textContaining('Peer edit'));
      await waitJournalWidget(tester, input('Title'));
      expect(inputValue(tester, input('Title')), 'Local edit');
      debugPrint(
        'JOURNAL_WORKFLOW_CASE $provider editor-draft-close-and-reopen PASS',
      );
      await _editorAction(tester, button('Save', true));
      await waitJournalWidget(tester, find.textContaining('Local edit'));
      expect(inputValue(tester, input('Search')), 'second body');
      await tester.enterText(input('Search'), 'absent from journal');
      await waitJournalWidget(
        tester,
        find.textContaining('Local edit'),
        absent: true,
      );
      await tester.enterText(input('Search'), '');
      await waitJournalWidget(tester, find.textContaining('Local edit'));
      await _refresh(tester, enabledRefresh());
      final edited = (await tester.runAsync(
        () => request('GET', object.requestUri),
      ))!;
      expect(edited.statusCode, 200);
      expect(edited.body, contains('SUMMARY:Local edit'));
      expect(edited.body, contains('DESCRIPTION:First body'));
      expect(edited.body, contains('DESCRIPTION:Second body'));
      debugPrint('JOURNAL_WORKFLOW_CASE $provider peer-refresh-search PASS');

      if (restart == JournalRestartStage.queue) {
        Future<void> create(String title) async {
          await waitJournalWidget(tester, find.text('New entry'));
          await tester.tap(find.text('New entry'));
          await waitJournalWidget(tester, input('Title'));
          await tester.enterText(input('Title'), title);
          await _editorAction(tester, button('Save', true));
          await waitJournalWidget(tester, find.textContaining(title));
        }

        await create('Offline delete control');
        await _refresh(tester, enabledRefresh());
        final deleteControl = (await tester.runAsync(
          () async =>
              (await database.select(database.davObjects).get()).singleWhere(
                (row) =>
                    row.collectionId == collection!.id &&
                    row.requestUri != object.requestUri,
              ),
        ))!;
        online = false;
        await create('Offline new entry');
        await tester.tap(find.textContaining('Local edit'));
        await waitJournalWidget(tester, input('Title'));
        await tester.enterText(input('Title'), 'Offline edited entry');
        await _editorAction(tester, button('Save', true));
        await waitJournalWidget(
          tester,
          find.textContaining('Offline edited entry'),
        );
        await tester.tap(find.textContaining('Offline delete control'));
        await waitJournalWidget(tester, input('Title'));
        await _editorAction(tester, button('Delete', false));
        await _editorAction(
          tester,
          button('Delete the entire entry and its recurrence?', false),
        );
        await waitJournalWidget(
          tester,
          find.textContaining('Offline delete control'),
          absent: true,
        );
        await tester.runAsync(() async {
          expect(
            await database.select(database.pendingOps).get(),
            hasLength(3),
          );
          await receipt!.writeAsString(
            jsonEncode({
              'pid': pid,
              'collectionId': collection!.id,
              'collectionName': collectionName,
              'editedHref': object.requestUri,
              'deletedHref': deleteControl.requestUri,
            }),
            flush: true,
          );
        });
        savedForRestart = true;
        debugPrint(
          'JOURNAL_RESTART_CASE $provider queued-for-new-process PASS',
        );
        return;
      }

      await tester.tap(find.textContaining('Local edit'));
      await waitJournalWidget(tester, input('Title'));
      await _editorAction(tester, button('Delete', false));
      await _editorAction(
        tester,
        button('Delete the entire entry and its recurrence?', false),
      );
      await waitJournalWidget(tester, input('Search'));
      await waitJournalWidget(
        tester,
        find.textContaining('Local edit'),
        absent: true,
      );
      await _refresh(tester, enabledRefresh());
      final deleted = (await tester.runAsync(
        () => request('GET', object.requestUri),
      ))!;
      expect(deleted.statusCode, 404);
      debugPrint('JOURNAL_WORKFLOW_CASE $provider delete-readback PASS');
    } finally {
      await tester.pumpWidget(const SizedBox());
      tester.testTextInput.unregister();
      container.dispose();
      await tester.runAsync(() async {
        try {
          collection ??= (await database.select(database.davCollections).get())
              .where((row) => row.displayName == collectionName)
              .firstOrNull;
          if (!savedForRestart && collection != null) {
            final response = await request('DELETE', collection!.requestUri);
            expect(response.statusCode, anyOf(200, 204));
          }
          if (!savedForRestart && profileDirectory != null) {
            await secrets.deleteCredential(accountId);
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

String inputValue(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .controller
    .text;

Future<Map<String, Object?>> desktopJournalFixture(String provider) async {
  final path = Platform.environment['BUSYMAX_JOURNAL_LIVE_FIXTURE'];
  if (path == null || path.isEmpty) {
    throw StateError('Set BUSYMAX_JOURNAL_LIVE_FIXTURE.');
  }
  final all = jsonDecode(await File(path).readAsString()) as Map;
  final profile = (all[provider] as Map).cast<String, Object?>();
  return {
    ...profile,
    'ca': await File(profile['caFile'] as String).readAsString(),
  };
}

Finder journalMaterialInput(String label) => find.byWidgetPredicate(
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

Future<void> _refresh(WidgetTester tester, Finder enabled) async {
  await waitJournalWidget(tester, enabled);
  await tester.tap(enabled);
  await tester.pump();
  await waitJournalWidget(tester, enabled);
}

Future<void> waitJournalWidget(
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
