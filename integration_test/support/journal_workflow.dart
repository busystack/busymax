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
import 'package:busymax/src/journal/presentation/journal_workspace.dart';
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
import 'package:xml/xml.dart';

import '../../test/support/memory_settings_store.dart';
import '../../test/support/journal_http_trace.dart';
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
  List<Override> Function(AppDatabase)? runtimeOverrides,
  JournalRestartStage? restart,
  Directory? persistentProfile,
  bool checkConflictChoices = false,
  bool slowCollectionRemoval = false,
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
    final accountClient = _JournalAccountClient(client());
    final peer = client();
    final network = NetworkConnectivityMonitor.withoutPlatformObservation();
    final collectionName =
        previous?['collectionName'] as String? ??
        'Journal QA ${const Uuid().v4()}';
    final marker = collectionName.split('-').last;
    final offlineCreation = 'Offline new entry $marker';
    final offlineEdit = 'Offline edited entry $marker';
    final offlineDeletion = 'Offline delete control $marker';
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
        ...?runtimeOverrides?.call(database),
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
        await waitJournalWidget(tester, find.textContaining(offlineCreation));
        expect(find.textContaining(offlineEdit), findsOneWidget);
        expect(find.textContaining(offlineDeletion), findsNothing);
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
          expect(after.body, contains('SUMMARY:$offlineEdit'));
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
          expect(created.body, contains('SUMMARY:$offlineCreation'));
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
      await _tapVisible(tester, find.text('New journal collection'));
      await tester.pump();
      final collectionTitle = input('Title');
      await tester.ensureVisible(collectionTitle);
      await tester.enterText(collectionTitle, collectionName);
      final collectionSave = find.text('Save');
      await _tapVisible(tester, collectionSave);
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

      await _tapVisible(tester, find.text('New entry'));
      await waitJournalWidget(tester, input('Title'));
      await tester.enterText(input('Title'), 'Journal café');
      final addDescription = find.text('Add description');
      await _editorAction(tester, addDescription);
      await tester.pump();
      await _scrollEditorTo(tester, addDescription);
      final firstDescription = input('Description').last;
      await _scrollEditorTo(tester, firstDescription, delta: -160);
      await tester.enterText(firstDescription, 'First body');
      await _editorAction(tester, addDescription);
      await tester.pump();
      await _scrollEditorTo(tester, addDescription);
      final secondDescription = input('Description').last;
      await _scrollEditorTo(tester, secondDescription, delta: -160);
      expect(inputValue(tester, secondDescription), isEmpty);
      await tester.enterText(secondDescription, 'Second body');
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
        'SUMMARY:Peer edit${restart == null ? '\r\nCOMMENT:Peer comment\r\nCONTACT:Peer contact' : ''}',
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
      await _tapVisible(tester, find.textContaining('Peer edit'));
      await waitJournalWidget(tester, input('Title'));
      await tester.enterText(input('Title'), 'Local edit');
      if (restart == null) {
        await _editorAction(tester, button('Journal details', false));
        await tester.pump();
        await tester.ensureVisible(input('COMMENT'));
        await tester.enterText(input('COMMENT'), 'Edited comment');
        await _editorAction(tester, button('Add parameter', false).first);
        await tester.pump();
        await tester.ensureVisible(input('Parameter values, one per line'));
        await tester.enterText(
          input('Parameter values, one per line'),
          'preserved',
        );
        await tester.ensureVisible(input('CONTACT'));
        await tester.enterText(input('CONTACT'), 'Later unfinished contact');
      }
      await _editorAction(tester, button('Close', false));
      await waitJournalWidget(tester, input('Search'));
      expect(inputValue(tester, input('Search')), 'second body');
      expect(find.textContaining('Peer edit'), findsOneWidget);
      await _tapVisible(tester, find.textContaining('Peer edit'));
      await waitJournalWidget(tester, input('Title'));
      expect(inputValue(tester, input('Title')), 'Local edit');
      if (restart == null) {
        await _editorAction(tester, button('Journal details', false));
        await tester.pump();
        expect(inputValue(tester, input('COMMENT')), 'Edited comment');
        expect(
          inputValue(tester, input('CONTACT')),
          'Later unfinished contact',
        );
        expect(inputValue(tester, input('Parameter name')), '');
        expect(
          inputValue(tester, input('Parameter values, one per line')),
          'preserved',
        );
        await tester.ensureVisible(input('Parameter name'));
        await tester.enterText(input('Parameter name'), 'X-DRAFT-TEST');
      }
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
      if (restart == null) {
        expect(
          edited.body,
          contains('COMMENT;X-DRAFT-TEST=preserved:Edited comment'),
        );
        expect(edited.body, contains('CONTACT:Later unfinished contact'));
        debugPrint(
          'JOURNAL_WORKFLOW_CASE $provider draft-incomplete-parameter-readback PASS',
        );
      }
      debugPrint('JOURNAL_WORKFLOW_CASE $provider peer-refresh-search PASS');

      if (restart == JournalRestartStage.queue) {
        Future<void> create(String title) async {
          await waitJournalWidget(tester, find.text('New entry'));
          await _tapVisible(tester, find.text('New entry'));
          await waitJournalWidget(tester, input('Title'));
          await tester.enterText(input('Title'), title);
          await _editorAction(tester, button('Save', true));
          await waitJournalWidget(tester, find.textContaining(title));
        }

        await create(offlineDeletion);
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
        await create(offlineCreation);
        await _tapVisible(tester, find.textContaining('Local edit'));
        await waitJournalWidget(tester, input('Title'));
        await tester.enterText(input('Title'), offlineEdit);
        await _editorAction(tester, button('Save', true));
        await waitJournalWidget(tester, find.textContaining(offlineEdit));
        await _tapVisible(tester, find.textContaining(offlineDeletion));
        await waitJournalWidget(tester, input('Title'));
        await _editorAction(tester, button('Delete', false));
        await _editorAction(
          tester,
          button('Delete the entire entry and its recurrence?', false),
        );
        await waitJournalWidget(
          tester,
          find.textContaining(offlineDeletion),
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

      if (checkConflictChoices) {
        var currentTitle = 'Local edit';
        for (final (number, action, preserveLocal) in [
          (1, 'Keep server version', false),
          (2, 'Review and reapply local change', true),
          (3, 'Duplicate as new item', false),
        ]) {
          final before = (await tester.runAsync(
            () => request('GET', object.requestUri),
          ))!;
          expect(before.statusCode, 200);
          expect(before.body, contains('SUMMARY:$currentTitle\r\n'));
          final localTitle = 'Local conflict choice $number';
          final remoteTitle = 'Remote conflict choice $number';
          online = false;
          final current = find.textContaining('$currentTitle ·');
          await waitJournalWidget(tester, current);
          await _tapVisible(tester, current);
          await waitJournalWidget(tester, input('Title'));
          await tester.enterText(input('Title'), localTitle);
          await _editorAction(tester, button('Save', true));
          await waitJournalWidget(tester, find.textContaining(localTitle));
          final changed = (await tester.runAsync(
            () => request(
              'PUT',
              object.requestUri,
              body: before.body.replaceFirst(
                'SUMMARY:$currentTitle\r\n',
                'SUMMARY:$remoteTitle\r\n',
              ),
              headers: {
                'Content-Type': 'text/calendar; charset=utf-8',
                'If-Match': before.headers['etag']!,
              },
            ),
          ))!;
          expect(changed.statusCode, anyOf(200, 204));
          online = true;
          accountClient.preconditionFailures.clear();
          await _refresh(tester, enabledRefresh());
          expect(
            accountClient.preconditionFailures,
            contains((
              uri: Uri.parse(object.requestUri),
              etag: before.headers['etag']!,
            )),
          );
          final conflict = (await tester.runAsync(
            () async =>
                (await database.select(database.davConflictSnapshots).get())
                    .singleWhere((row) => row.resolvedAtUtc == null),
          ))!;
          expect(conflict.baselineRawIcs, contains('SUMMARY:$currentTitle'));
          expect(
            conflict.localCandidateRawIcs,
            contains('SUMMARY:$localTitle'),
          );
          expect(conflict.remoteRawIcs, contains('SUMMARY:$remoteTitle'));
          final remoteAfterConflict = (await tester.runAsync(
            () => request('GET', object.requestUri),
          ))!;
          expect(remoteAfterConflict.body, contains('SUMMARY:$remoteTitle'));

          final selected = find.textContaining(
            RegExp('^(?:$localTitle|$remoteTitle) ·'),
          );
          await waitJournalWidget(tester, selected);
          await _tapVisible(tester, selected);
          await waitJournalWidget(tester, find.text('Blocked by conflict'));
          expect(find.text(localTitle), findsWidgets);
          expect(find.text(remoteTitle), findsWidgets);
          await _editorAction(tester, button(action, false));
          await _refresh(tester, enabledRefresh());
          currentTitle = preserveLocal ? localTitle : remoteTitle;
          final resolved = (await tester.runAsync(
            () => request('GET', object.requestUri),
          ))!;
          expect(resolved.statusCode, 200);
          expect(resolved.body, contains('SUMMARY:$currentTitle\r\n'));
          expect(resolved.body, contains('DESCRIPTION:First body'));
          expect(resolved.body, contains('DESCRIPTION:Second body'));
          if (number == 3) {
            final duplicate = (await tester.runAsync(
              () async => (await database.select(database.davObjects).get())
                  .singleWhere(
                    (row) =>
                        row.collectionId == collection!.id &&
                        !row.serverDeleted &&
                        row.requestUri != object.requestUri,
                  ),
            ))!;
            final copy = (await tester.runAsync(
              () => request('GET', duplicate.requestUri),
            ))!;
            expect(copy.statusCode, 200);
            expect(copy.body, contains('SUMMARY:$localTitle'));
            expect(copy.body, contains('DESCRIPTION:First body'));
            expect(copy.body, contains('DESCRIPTION:Second body'));
            expect(duplicate.primaryUid, isNot(object.primaryUid));
          }
        }
        final finalEntry = find.textContaining('$currentTitle ·');
        await waitJournalWidget(tester, finalEntry);
        await _tapVisible(tester, finalEntry);
        await waitJournalWidget(tester, input('Title'));
        await tester.enterText(input('Title'), 'Local edit');
        await _editorAction(tester, button('Save', true));
        await _refresh(tester, enabledRefresh());
        debugPrint(
          'JOURNAL_WORKFLOW_CASE $provider journal-content-conflict-choices PASS',
        );
      }

      const dav = 'DAV:';
      final target = collection.requestUri;
      final beforeDelete = (await tester.runAsync(
        () => request(
          'PROPFIND',
          target,
          headers: const {'Depth': '0', 'Content-Type': 'application/xml'},
          body:
              '<d:propfind xmlns:d="$dav"><d:prop><d:sync-token/></d:prop></d:propfind>',
        ),
      ))!;
      expect(beforeDelete.statusCode, 207);
      final syncToken = XmlDocument.parse(beforeDelete.body)
          .findAllElements('sync-token', namespaceUri: dav)
          .single
          .innerText;
      expect(syncToken, isNotEmpty);

      await _tapVisible(tester, find.textContaining('Local edit'));
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
      final delta = (await tester.runAsync(
        () => request(
          'REPORT',
          target,
          headers: const {'Depth': '0', 'Content-Type': 'application/xml'},
          body:
              '<d:sync-collection xmlns:d="$dav">'
              '<d:sync-token>${XmlText(syncToken).toXmlString()}</d:sync-token>'
              '<d:sync-level>1</d:sync-level><d:prop><d:getetag/></d:prop></d:sync-collection>',
        ),
      ))!;
      expect(delta.statusCode, 207);
      final deletedPath = Uri.parse(object.requestUri).path;
      final tombstone = XmlDocument.parse(delta.body)
          .findAllElements('response', namespaceUri: dav)
          .singleWhere(
            (member) =>
                Uri.parse(
                  member
                      .findElements('href', namespaceUri: dav)
                      .single
                      .innerText,
                ).path ==
                deletedPath,
          );
      expect(
        tombstone.findElements('status', namespaceUri: dav).single.innerText,
        matches(RegExp(r'^HTTP/\S+ 404\b')),
      );
      debugPrint('JOURNAL_WORKFLOW_CASE $provider delete-sync-tombstone PASS');

      final rename = button('Rename', false);
      await waitJournalWidget(tester, rename);
      await _tapVisible(tester, rename);
      await waitJournalWidget(tester, input('Title'));
      final renamed = '$collectionName renamed';
      await tester.enterText(input('Title'), renamed);
      await _tapVisible(tester, button('Save', true));
      await waitJournalWidget(tester, button('Save', true), absent: true);
      final renamedRemote = (await tester.runAsync(
        () => request(
          'PROPFIND',
          target,
          headers: const {'Depth': '0', 'Content-Type': 'application/xml'},
          body:
              '<d:propfind xmlns:d="$dav"><d:prop><d:displayname/></d:prop></d:propfind>',
        ),
      ))!;
      expect(renamedRemote.statusCode, 207);
      expect(
        XmlDocument.parse(renamedRemote.body)
            .findAllElements('displayname', namespaceUri: dav)
            .single
            .innerText,
        renamed,
      );
      await _tapVisible(tester, button('Delete collection', false));
      final confirmation = find.text(
        provider == 'nextcloud'
            ? 'Delete "$renamed"?'
            : 'Permanently delete this collection and all its contents?',
      );
      await waitJournalWidget(tester, confirmation);
      accountClient.trace.clear();
      if (slowCollectionRemoval) {
        accountClient.delayRemovalResponses = true;
      }
      await _tapVisible(tester, button('Delete', false));
      await waitJournalWidget(
        tester,
        confirmation,
        absent: true,
        timeout: const Duration(minutes: 2),
        failureContext: () {
          final statuses = find.descendant(
            of: find.byType(JournalWorkspace),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.liveRegion == true,
            ),
          );
          final messages = statuses.evaluate().map((element) {
            final child = (element.widget as Semantics).child;
            return child is Text ? child.data : null;
          }).whereType<String>();
          return 'Journal status ${messages.join(', ')}. DAV requests '
              '${accountClient.trace}. Delayed responses '
              '${accountClient.delayedRemovalMethods}.';
        },
      );
      await waitJournalWidget(tester, enabledRefresh());
      const nc = 'http://nextcloud.com/ns';
      final removed = (await tester.runAsync(
        () => request(
          'PROPFIND',
          target,
          headers: const {'Depth': '0', 'Content-Type': 'application/xml'},
          body:
              '<d:propfind xmlns:d="$dav" xmlns:nc="$nc"><d:prop><nc:deleted-at/></d:prop></d:propfind>',
        ),
      ))!;
      if (provider == 'nextcloud' && removed.statusCode == 207) {
        final deletion = XmlDocument.parse(removed.body)
            .findAllElements('deleted-at', namespaceUri: nc)
            .single
            .innerText;
        expect(DateTime.tryParse(deletion), isNotNull);
      } else {
        expect(removed.statusCode, 404);
      }
      expect(
        await tester.runAsync(() async {
          final local = await (database.select(
            database.davCollections,
          )..where((row) => row.id.equals(collection!.id))).getSingleOrNull();
          return local != null &&
              local.journalProjectionEnabled &&
              !local.deleted &&
              !local.serverMissing;
        }),
        isFalse,
      );
      collection = null;
      if (slowCollectionRemoval) {
        expect(accountClient.delayedRemovalMethods, hasLength(5));
        expect(accountClient.delayedRemovalMethods, contains('DELETE'));
        debugPrint(
          'JOURNAL_WORKFLOW_CASE $provider collection-delete-slow-response PASS',
        );
      }
      debugPrint(
        'JOURNAL_WORKFLOW_CASE $provider collection-rename-delete-readback PASS',
      );
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

final class _JournalAccountClient extends http.BaseClient {
  _JournalAccountClient(this.delegate);

  final http.Client delegate;
  final preconditionFailures = <({Uri uri, String etag})>[];
  final trace = JournalHttpTrace();
  bool delayRemovalResponses = false;
  final delayedRemovalMethods = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await trace.send(delegate, request);
    if (delayRemovalResponses && delayedRemovalMethods.length < 5) {
      // The removal and its refresh make several requests. Successful
      // responses within their individual deadlines can outlast a short UI wait.
      delayedRemovalMethods.add(request.method);
      await Future<void>.delayed(const Duration(seconds: 12));
    }
    if (request.method == 'PUT' && response.statusCode == 412) {
      final etag = request.headers.entries
          .where((entry) => entry.key.toLowerCase() == 'if-match')
          .firstOrNull
          ?.value;
      if (etag != null) {
        preconditionFailures.add((uri: request.url, etag: etag));
      }
    }
    return response;
  }

  @override
  void close() => delegate.close();
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
  if (Platform.isAndroid) {
    // Release the editor's text focus before moving to a footer control.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 250));
  }
  await _scrollEditorTo(tester, action);
  await _tapVisible(tester, action);
}

Future<void> _scrollEditorTo(
  WidgetTester tester,
  Finder target, {
  double delta = 300,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pump();
  final visible = target.hitTestable();
  await waitJournalWidget(tester, visible);
  await tester.tap(visible);
}

Future<void> _refresh(WidgetTester tester, Finder enabled) async {
  await waitJournalWidget(tester, enabled);
  await _tapVisible(tester, enabled);
  await tester.pump();
  await waitJournalWidget(tester, enabled);
}

Future<void> waitJournalWidget(
  WidgetTester tester,
  Finder finder, {
  bool absent = false,
  Duration? timeout,
  String Function()? failureContext,
}) async {
  final elapsed = Stopwatch()..start();
  for (
    var attempt = 0;
    timeout == null ? attempt < 240 : elapsed.elapsed < timeout;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty == absent) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(
    finder,
    absent ? findsNothing : findsWidgets,
    reason: failureContext?.call(),
  );
}
