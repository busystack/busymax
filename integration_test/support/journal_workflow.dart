import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/linux/linux_header_style.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/domain/account_connection_state.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_toolbar.dart';
import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/journal/presentation/journal_pane.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
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
typedef JournalFileTransfer = Future<String> Function(
  WidgetTester tester,
  String title,
  String importedTitle,
  String importedUid,
  String account,
  String source,
);

enum JournalRestartStage { queue, replay }

void runJournalWorkflow({
  required String platform,
  required String provider,
  required bool Function() isNative,
  required Future<Map<String, Object?>> Function() fixture,
  required Widget Function() app,
  required Future<void> Function(WidgetTester, ProviderContainer) openSchedule,
  required Finder Function(String) input,
  required JournalTestButton button,
  List<Override> Function(AppDatabase)? runtimeOverrides,
  JournalRestartStage? restart,
  Future<Directory> Function()? persistentProfile,
  bool checkConflictChoices = false,
  bool slowCollectionRemoval = false,
  bool checkMove = false,
  JournalFileTransfer? transferFiles,
}) {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final description = restart == null
      ? '$platform journal collection and editor on $provider'
      : '$platform offline journal ${restart.name} across processes on $provider';
  testWidgets(description, (tester) async {
    final markers = <String>[];
    binding.reportData = {'journalTest': description, 'journalCases': markers};
    void record(String name) {
      final marker = 'JOURNAL_WORKFLOW_CASE $provider $name PASS';
      markers.add(marker);
      debugPrint(marker);
    }

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
    final localProfile = persistentProfile == null
        ? null
        : (await tester.runAsync(persistentProfile))!;
    final profileDirectory = localProfile == null
        ? null
        : Directory('${localProfile.path}/$provider');
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
    var online = restart != JournalRestartStage.replay;
    List<ConnectivityResult> connectivity() => [
      online ? ConnectivityResult.wifi : ConnectivityResult.none,
    ];
    final changes = StreamController<List<ConnectivityResult>>.broadcast(
      sync: true,
    );
    final network = NetworkConnectivityMonitor(
      checkConnectivity: () async => connectivity(),
      connectivityChanges: changes.stream,
    );
    await tester.runAsync(network.initialize);
    void setOnline(bool value) {
      online = value;
      changes.add(connectivity());
    }

    final accountClient = _JournalAccountClient(
      ConnectivityAwareHttpClient(
        inner: client(),
        requireNetwork: network.requireNetwork,
      ),
    );
    final peer = client();
    late final ProviderContainer container;
    final collectionName =
        previous?['collectionName'] as String? ??
        'Journal QA ${const Uuid().v4()}';
    final marker = collectionName.split('-').last;
    final offlineCreation = 'Offline new entry $marker';
    final offlineEdit = 'Offline edited entry $marker';
    final offlineDeletion = 'Offline delete control $marker';
    final offlineDraft = 'Offline unsubmitted draft $marker';
    const accountId = 'native-journal-fixture';
    DavCollection? collection;
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

    Future<void> sync({bool full = false}) async {
      if (!online) return;
      await container
          .read(accountSyncOperationsProvider)
          .syncAccount(accountId, full: full);
    }

    Future<void> searchFor(String title, {bool absent = false}) async {
      final search = input('Search');
      await openJournalSearch(tester);
      await waitJournalWidget(tester, search);
      await tester.enterText(search, title);
      await tester.pump(const Duration(milliseconds: 350));
      await waitJournalWidget(tester, find.text(title), absent: absent);
    }

    Future<void> refresh({
      bool confirmPartial = false,
      String Function()? failureContext,
    }) => _refresh(
      tester,
      container,
      confirmPartial: confirmPartial,
      failureContext: failureContext,
    );

    container = ProviderContainer(
      overrides: [
        ...?runtimeOverrides?.call(database),
        if (Platform.isAndroid)
          buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
        initialAppSettingsProvider.overrideWithValue(
          AppSettings.defaults().copyWith(
            scheduleViewMode: ScheduleViewMode.agenda,
            androidScheduleViewMode: ScheduleViewMode.agenda,
          ),
        ),
        databaseProvider.overrideWithValue(database),
        secretStoreProvider.overrideWithValue(secrets),
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        localTimeZoneProvider.overrideWithValue('UTC'),
        networkConnectivityMonitorProvider.overrideWithValue(network),
        davAccountHttpClientProvider.overrideWith((ref, id) => accountClient),
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
        await openSchedule(tester, container);
        await searchFor(offlineCreation);
        await searchFor(offlineEdit);
        await _tapVisible(tester, find.text(offlineEdit));
        await waitJournalWidget(
          tester,
          find.text('Draft saved on this device'),
        );
        expect(inputValue(tester, input('Title')), offlineDraft);
        expect(
          inputValue(tester, input('Description').last),
          'Unsaved description $marker',
        );
        await _editorAction(tester, button('Close', false));
        await searchFor(offlineDeletion, absent: true);
        await tester.enterText(input('Search'), '');
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
        setOnline(true);
        await refresh();
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
          final draft = await database
              .select(database.davJournalDrafts)
              .getSingle();
          expect(draft.contentJson, contains(offlineDraft));
          expect(draft.contentJson, contains('Unsaved description $marker'));
        });
        record('offline-journal-draft-process-restart');
        record('offline-process-restart');
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
      await openSchedule(tester, container);
      await waitJournalWidget(tester, find.byType(JournalPane), absent: true);
      await journalCollectionAction(tester, 'New journal', account: accountId);
      await tester.pump();
      final collectionTitle = input('Title');
      await tester.ensureVisible(collectionTitle);
      await tester.enterText(collectionTitle, collectionName);
      final collectionSave = find.descendant(
        of: find.byType(JournalPane),
        matching: find.text('Create'),
      );
      await _tapVisible(tester, collectionSave);
      await waitJournalWidget(tester, find.byType(JournalPane), absent: true);
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
      record('collection-create');

      await _createScheduleJournal(tester);
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
      await refresh();
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
      record('undated-repeated-description');
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
      await refresh();
      await waitJournalWidget(tester, find.textContaining('Peer edit'));
      await openJournalSearch(tester);
      await tester.enterText(input('Search'), 'second body');
      await waitJournalWidget(tester, find.textContaining('Peer edit'));
      await _tapVisible(tester, find.textContaining('Peer edit'));
      await enterJournalEditor(tester);
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
      await waitJournalWidget(tester, find.text('Peer edit'));
      await _tapVisible(tester, find.textContaining('Peer edit'));
      await enterJournalEditor(tester);
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
      record('editor-draft-close-and-reopen');
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
      await refresh();
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
        record('draft-incomplete-parameter-readback');
      }
      record('peer-refresh-search');

      if (restart == JournalRestartStage.queue) {
        Future<void> create(String title) async {
          await _createScheduleJournal(tester);
          await waitJournalWidget(tester, input('Title'));
          await tester.enterText(input('Title'), title);
          await _editorAction(tester, button('Save', true));
          await searchFor(title);
          await tester.enterText(input('Search'), '');
        }

        await create(offlineDeletion);
        await refresh();
        final deleteControl = (await tester.runAsync(
          () async =>
              (await database.select(database.davObjects).get()).singleWhere(
                (row) =>
                    row.collectionId == collection!.id &&
                    row.requestUri != object.requestUri,
              ),
        ))!;
        setOnline(false);
        await create(offlineCreation);
        await searchFor('Local edit');
        await _tapVisible(tester, find.text('Local edit'));
        await enterJournalEditor(tester);
        await waitJournalWidget(tester, input('Title'));
        await tester.enterText(input('Title'), offlineEdit);
        await _editorAction(tester, button('Save', true));
        await searchFor(offlineEdit);
        await searchFor(offlineDeletion);
        await _tapVisible(tester, find.text(offlineDeletion));
        await enterJournalEditor(tester);
        await waitJournalWidget(tester, input('Title'));
        await _editorAction(tester, button('Delete', false));
        await _editorAction(
          tester,
          button('Delete the entire entry and its recurrence?', false),
        );
        await searchFor(offlineDeletion, absent: true);
        await searchFor(offlineEdit);
        await _tapVisible(tester, find.text(offlineEdit));
        await enterJournalEditor(tester);
        await waitJournalWidget(tester, input('Title'));
        await tester.enterText(input('Title'), offlineDraft);
        final description = input('Description').last;
        await _scrollEditorTo(tester, description);
        await tester.enterText(description, 'Unsaved description $marker');
        await _editorAction(tester, button('Close', false));
        await waitJournalWidget(tester, input('Search'));
        await tester.runAsync(() async {
          expect(
            await database.select(database.pendingOps).get(),
            hasLength(3),
          );
          final draft = await database
              .select(database.davJournalDrafts)
              .getSingle();
          expect(draft.contentJson, contains(offlineDraft));
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
          setOnline(false);
          final current = find.text(currentTitle);
          await waitJournalWidget(tester, current);
          await _tapVisible(tester, current);
          await enterJournalEditor(tester);
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
          setOnline(true);
          accountClient.preconditionFailures.clear();
          await refresh(confirmPartial: number == 2);
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

          final selected = find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data == localTitle || widget.data == remoteTitle),
          );
          await waitJournalWidget(tester, selected);
          await _tapVisible(tester, selected);
          await waitJournalWidget(tester, find.text('Blocked by conflict'));
          expect(find.text(localTitle), findsWidgets);
          expect(find.text(remoteTitle), findsWidgets);
          await _editorAction(tester, button(action, false));
          currentTitle = preserveLocal ? localTitle : remoteTitle;
          if (number == 1) {
            // Keep server adopts the confirmed snapshot locally and sends no write.
            await waitJournalWidget(tester, find.text(currentTitle));
          } else {
            await refresh(
              confirmPartial: true,
              failureContext: () =>
                  '$action did not finish refreshing. DAV ${accountClient.trace}.',
            );
          }
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
        final finalEntry = find.text(currentTitle);
        await waitJournalWidget(tester, finalEntry);
        await _tapVisible(tester, finalEntry);
        await enterJournalEditor(tester);
        await waitJournalWidget(tester, input('Title'));
        await tester.enterText(input('Title'), 'Local edit');
        await _editorAction(tester, button('Save', true));
        await refresh();
        record('journal-content-conflict-choices');
      }

      if (checkMove) {
        // Keep the existing entry in place for the subsequent tombstone check.
        final sourceUri = Uri.parse(collection.requestUri);
        final destinationUri = sourceUri.resolve('../journal-move-$marker/');
        final sourceEntry = sourceUri.resolve('move.ics').toString();
        final destinationEntry = destinationUri.resolve('move.ics').toString();
        final moveTitle = 'Journal move $marker';
        final destinationTitle = 'Move destination $marker';
        await tester.runAsync(() async {
          final createdCollection = await request(
            'MKCALENDAR',
            destinationUri.toString(),
            headers: {'Content-Type': 'application/xml'},
            body:
                '<c:mkcalendar xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:set><d:prop><d:displayname>$destinationTitle</d:displayname><c:supported-calendar-component-set><c:comp name="VJOURNAL"/></c:supported-calendar-component-set></d:prop></d:set></c:mkcalendar>',
          );
          expect(createdCollection.statusCode, 201);
        });
        try {
          final original = (await tester.runAsync(() async {
            final createdEntry = await request(
              'PUT',
              sourceEntry,
              headers: {'Content-Type': 'text/calendar', 'If-None-Match': '*'},
              body: [
                'BEGIN:VCALENDAR',
                'VERSION:2.0',
                'PRODID:-//BusyMax//Native journal MOVE QA//EN',
                'BEGIN:VJOURNAL',
                'UID:journal-move-$marker@example.invalid',
                'DTSTAMP:20261126T000000Z',
                'SUMMARY:$moveTitle',
                'DESCRIPTION:Moved from the journal editor',
                'END:VJOURNAL',
                'END:VCALENDAR',
                '',
              ].join('\r\n'),
            );
            expect(createdEntry.statusCode, 201);
            final fetched = await request('GET', sourceEntry);
            expect(fetched.statusCode, 200);
            await sync(full: true);
            return fetched;
          }))!;
          await searchFor(moveTitle);
          await _tapVisible(tester, find.text(moveTitle));
          await enterJournalEditor(tester);
          await waitJournalWidget(tester, input('Title'));
          await _selectMoveDestination(tester, destinationTitle);
          await waitJournalWidget(tester, find.text(destinationTitle));
          await _editorAction(tester, button('Move journal entry', false));
          await waitJournalWidget(tester, input('Title'), absent: true);
          await refresh();
          await tester.runAsync(() async {
            expect((await request('GET', sourceEntry)).statusCode, 404);
            final moved = await request('GET', destinationEntry);
            expect(moved.statusCode, 200);
            expect(moved.bodyBytes, original.bodyBytes);
            final projected = await database
                .select(database.davJournalEntries)
                .get();
            final entry = projected.singleWhere(
              (row) => row.title == moveTitle,
            );
            expect(entry.collectionId, isNot(collection!.id));
          });
          record('journal-move-readback');
        } finally {
          await tester.runAsync(() async {
            final removed = await request('DELETE', destinationUri.toString());
            expect(removed.statusCode, anyOf(200, 204));
          });
        }
        await searchFor('Local edit');
      }

      const dav = 'DAV:';
      final target = collection.requestUri;
      if (!slowCollectionRemoval) {
        Future<void> scrollToOccurrence(Finder occurrence) async {
          final occurrenceList = find.descendant(
            of: find.byWidgetPredicate(
              (widget) => widget is ListView && widget.primary == false,
            ),
            matching: find.byType(Scrollable),
          );
          await waitJournalWidget(tester, occurrenceList);
          await tester.scrollUntilVisible(
            occurrence,
            100,
            scrollable: occurrenceList,
          );
        }

        // A peer supplies a known series and a link to the journal created
        // above. The native UI opens the link and edits the recurrence.
        final seriesUri = Uri.parse(target).resolve('native-series.ics');
        final month = DateTime.now().toIso8601String().substring(0, 7);
        final prefix = month.replaceAll('-', '');
        final dayOne = '${prefix}01';
        final dayTwo = '${prefix}02';
        const seriesTitle = 'Native recurring journal';
        const occurrenceTitle = 'Native single override';
        const futureTitle = 'Native future override';
        final createdSeries = (await tester.runAsync(
          () => request(
            'PUT',
            seriesUri.toString(),
            headers: const {
              'If-None-Match': '*',
              'Content-Type': 'text/calendar; charset=utf-8',
            },
            body: [
              'BEGIN:VCALENDAR',
              'VERSION:2.0',
              'PRODID:-//BusyMax QA//Native journal recurrence//EN',
              'BEGIN:VJOURNAL',
              'UID:native-series-$marker',
              'DTSTAMP:${dayOne}T090000Z',
              'DTSTART;VALUE=DATE:$dayOne',
              'RRULE:FREQ=DAILY;COUNT=3',
              'SUMMARY:$seriesTitle',
              'RELATED-TO:${object.primaryUid}',
              'END:VJOURNAL',
              'END:VCALENDAR',
              '',
            ].join('\r\n'),
          ),
        ))!;
        expect(createdSeries.statusCode, 201);
        await refresh();
        await searchFor(seriesTitle);
        final series = find.text(seriesTitle);
        await waitJournalWidget(tester, series);
        await _tapVisible(tester, series);
        await enterJournalEditor(tester);
        await waitJournalWidget(tester, input('Title'));
        expect(inputValue(tester, input('Title')), seriesTitle);
        final link = find.text('Open link · Local edit');
        await _editorAction(tester, link);
        await enterJournalEditor(tester);
        await waitJournalWidget(
          tester,
          find.descendant(
            of: input('Title'),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is EditableText &&
                  widget.controller.text == 'Local edit',
            ),
          ),
        );
        await _scrollEditorTo(tester, input('Description').first);
        expect(inputValue(tester, input('Description').first), 'First body');
        await _editorAction(tester, button('Close', false));

        for (final (currentTitle, action, newTitle) in [
          (seriesTitle, 'Edit this occurrence', occurrenceTitle),
          (occurrenceTitle, 'Edit this and future occurrences', futureTitle),
        ]) {
          await waitJournalWidget(tester, series);
          await _tapVisible(tester, series);
          await enterJournalEditor(tester);
          await waitJournalWidget(tester, input('Title'));
          await _editorAction(tester, find.text('Repeat'));
          final occurrence = find.byWidgetPredicate(
            (widget) =>
                widget is Wrap &&
                widget.children.whereType<Text>().any(
                  (label) => label.data == '$dayTwo · $currentTitle',
                ),
          );
          await scrollToOccurrence(occurrence);
          await _tapVisible(
            tester,
            find.descendant(of: occurrence, matching: find.text(action)),
          );
          await waitJournalWidget(tester, input('Title'));
          expect(inputValue(tester, input('Title')), currentTitle);
          await tester.enterText(input('Title'), newTitle);
          await _editorAction(tester, button('Save', true));
          await waitJournalWidget(tester, series);
          await refresh();
          final savedSeries = (await tester.runAsync(
            () => request('GET', seriesUri.toString()),
          ))!;
          expect(savedSeries.statusCode, 200);
          expect(savedSeries.body, contains('SUMMARY:$newTitle'));
          expect(savedSeries.body, contains('RELATED-TO:${object.primaryUid}'));
          final identifiers = savedSeries.body
              .split(RegExp(r'\r?\n'))
              .where((line) => line.startsWith('RECURRENCE-ID'));
          expect(identifiers.single.split(':').last, dayTwo);
          expect(
            identifiers.single.contains('RANGE=THISANDFUTURE'),
            newTitle == futureTitle,
          );
        }
        await _tapVisible(tester, series);
        await enterJournalEditor(tester);
        await waitJournalWidget(tester, input('Title'));
        await _editorAction(tester, find.text('Repeat'));
        await scrollToOccurrence(find.text('$dayOne · $seriesTitle'));
        await scrollToOccurrence(find.text('${prefix}03 · $futureTitle'));
        await _scrollEditorTo(tester, button('Save', true));
        await _tapVisible(
          tester,
          find.descendant(
            of: find.widgetWithText(Wrap, 'Save'),
            matching: button('Close', false),
          ),
        );
        await searchFor('Local edit');
        record('recurrence-and-journal-link-readback');
      }
      if (transferFiles != null) {
        const title = 'Local edit';
        const importedTitle = 'GTK imported journal';
        final importedUid = 'gtk-import-$marker@example.invalid';
        await searchFor(title);
        await tester.enterText(input('Search'), '');
        await _tapVisible(tester, find.text(title));
        await enterJournalEditor(tester);
        final attachment = await transferFiles(
          tester,
          title,
          importedTitle,
          importedUid,
          accountId,
          collection.id,
        );
        await refresh();
        await tester.runAsync(() async {
          final entries = await database.select(database.davObjects).get();
          final imported = entries.singleWhere(
            (row) =>
                row.collectionId == collection!.id &&
                row.primaryUid == importedUid,
          );
          expect(imported.requestUri, isNot(object.requestUri));
          for (final uri in [object.requestUri, imported.requestUri]) {
            final response = await request('GET', uri);
            expect(response.statusCode, 200);
            final content = response.body.replaceAll(RegExp(r'\r?\n[ \t]'), '');
            expect(content, contains('BEGIN:VJOURNAL'));
            expect(content, contains('DESCRIPTION:First body'));
            expect(content, contains('DESCRIPTION:Second body'));
            final property = const LineSplitter()
                .convert(content)
                .singleWhere((line) => line.startsWith('ATTACH;'));
            expect(property, contains('VALUE=BINARY'));
            expect(property, endsWith(':$attachment'));
            if (uri == imported.requestUri) {
              expect(content, contains('SUMMARY:$importedTitle'));
              expect(content, contains('UID:$importedUid'));
            }
          }
        });
        final reviews = (await tester.runAsync(
          () => database.select(database.davJournalDrafts).get(),
        ))!;
        final review = jsonDecode(reviews.single.contentJson) as Map;
        expect(review['format'], 'busymax-journal-import-review');
        // Closing the review preserves it for inspection. Retire the reviewed
        // import explicitly after verifying that the queued resource is remote.
        await journalCollectionAction(
          tester,
          'Import .ics file',
          account: accountId,
          source: collection.id,
        );
        await waitJournalWidget(tester, find.text(importedUid));
        await _editorAction(tester, button('Discard', false));
        await searchFor(importedTitle);
        await searchFor(title);
        record('gtk-journal-files-provider-readback');
      }
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

      await _tapVisible(tester, find.text('Local edit'));
      await enterJournalEditor(tester);
      await waitJournalWidget(tester, input('Title'));
      await _editorAction(tester, button('Delete', false));
      await _editorAction(
        tester,
        button('Delete the entire entry and its recurrence?', false),
      );
      await waitJournalWidget(tester, input('Search'));
      await waitJournalWidget(tester, find.text('Local edit'), absent: true);
      await refresh();
      final deleted = (await tester.runAsync(
        () => request('GET', object.requestUri),
      ))!;
      expect(deleted.statusCode, 404);
      record('delete-readback');
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
      record('delete-sync-tombstone');

      await journalCollectionAction(
        tester,
        'Rename',
        account: accountId,
        source: collection.id,
      );
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
      if (transferFiles != null) {
        final drafts = (await tester.runAsync(
          () => database.select(database.davJournalDrafts).get(),
        ))!;
        expect(
          drafts.map((draft) => draft.id),
          isEmpty,
          reason: 'The completed import review was explicitly discarded.',
        );
      }
      await journalCollectionAction(
        tester,
        'Delete collection',
        account: accountId,
        source: collection.id,
      );
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
            of: find.byType(JournalPane),
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
      await waitJournalWidget(tester, find.byType(JournalPane), absent: true);
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
        record('collection-delete-slow-response');
      }
      record('collection-rename-delete-readback');
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
          await changes.close();
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

Finder journalScheduleSearchInput() {
  if (Platform.isLinux) {
    return find.descendant(
      of: find.byKey(const ValueKey('schedule-header-search-field')),
      matching: find.byType(TextField),
    );
  }
  if (Platform.isWindows) {
    return find.byWidgetPredicate(
      (widget) => widget is fluent.TextBox && widget.placeholder == 'Search',
    );
  }
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == 'Search',
  );
}

Future<void> openJournalSearch(WidgetTester tester) async {
  final input = journalScheduleSearchInput();
  if (Platform.isWindows) {
    await waitJournalWidget(tester, input);
    await tester.tap(input);
  } else if (input.evaluate().isEmpty) {
    final trigger = Platform.isLinux
        ? find.byKey(const ValueKey('schedule-search-button'))
        : find.byTooltip('Search');
    await waitJournalWidget(tester, trigger);
    await tester.tap(trigger);
  }
  await waitJournalWidget(tester, input);
}

Future<void> _closeScheduleSearch(WidgetTester tester) async {
  if (Platform.isWindows) {
    final close = find.byTooltip('Close').hitTestable();
    if (close.evaluate().isNotEmpty) await tester.tap(close);
  } else if (journalScheduleSearchInput().evaluate().isNotEmpty) {
    final trigger = Platform.isLinux
        ? find.byKey(const ValueKey('schedule-search-button'))
        : find.byTooltip('Search');
    await tester.tap(trigger);
    await waitJournalWidget(tester, journalScheduleSearchInput(), absent: true);
  }
  await tester.pump();
}

Future<void> enterJournalEditor(WidgetTester tester) async {
  final pane = find.byType(JournalPane);
  await waitJournalWidget(tester, pane);
  final edit = find.byTooltip('Edit journal entry');
  await waitJournalWidget(
    tester,
    edit,
    failureContext: () => tester
        .widgetList<Text>(
          find.descendant(of: pane, matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .whereType<String>()
        .join(' | '),
  );
  await _tapVisible(tester, edit);
}

Future<void> _createScheduleJournal(WidgetTester tester) async {
  await _closeScheduleSearch(tester);
  if (Platform.isLinux) {
    final trigger = find.byKey(const ValueKey('schedule-create-button'));
    await waitJournalWidget(tester, trigger);
    final menu = tester.widget<BusyMaxLinuxHeaderMenuButton<dynamic>>(trigger);
    final item = menu.entries.singleWhere(
      (item) => item.label == 'New journal entry',
    );
    expect(item.enabled, isTrue);
    (menu as dynamic).onSelected(item.value);
  } else {
    final trigger = Platform.isWindows
        ? find.widgetWithText(fluent.DropDownButton, 'Create')
        : find.byTooltip('Create');
    await waitJournalWidget(tester, trigger);
    await _tapVisible(tester, trigger);
    await waitJournalWidget(tester, find.text('New journal entry'));
    await _tapVisible(tester, find.text('New journal entry'));
  }
  await waitJournalWidget(tester, find.byType(JournalPane));
}

Future<void> journalCollectionAction(
  WidgetTester tester,
  String label, {
  required String account,
  String? source,
}) async {
  await _closeScheduleSearch(tester);
  final options = source == null
      ? find.byKey(ValueKey(('account-collection-options', account)))
      : Platform.isWindows
      ? find.descendant(
          of: find.byKey(ValueKey(('schedule-journal', account, source))),
          matching: find.byTooltip('Options'),
        )
      : find.byKey(ValueKey(('journal-options', source)));
  if (Platform.isAndroid && options.evaluate().isEmpty) {
    await _tapVisible(tester, find.byTooltip('Calendars and task lists'));
  }
  await waitJournalWidget(tester, options);
  if (Platform.isLinux) {
    final menu = tester.widget<BusyMaxMenuButton<dynamic>>(options);
    final item = menu.entries.singleWhere((item) => item.label == label);
    expect(item.enabled, isTrue);
    (menu as dynamic).onSelected(item.value);
  } else {
    await _tapVisible(tester, options);
    await waitJournalWidget(tester, find.text(label));
    await _tapVisible(tester, find.text(label));
  }
  await waitJournalWidget(tester, find.byType(JournalPane));
}

Future<void> _editorAction(WidgetTester tester, Finder action) async {
  if (Platform.isAndroid) {
    // Release the editor's text focus before moving to a footer control.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 250));
  }
  await _scrollEditorTo(tester, action);
  await _tapVisible(tester, action);
}

Future<void> _selectMoveDestination(WidgetTester tester, String title) async {
  const label = 'Move journal entry';
  if (Platform.isAndroid) {
    await _editorAction(tester, find.byKey(const ValueKey((label, ''))));
    final choice = find.text(title).hitTestable();
    await waitJournalWidget(tester, choice);
    await _tapVisible(tester, choice);
    return;
  }
  final picker = find.byWidgetPredicate(
    (widget) => widget is BusyMaxComboRow<String> && widget.title == label,
  );
  await _scrollEditorTo(tester, picker);
  final menu = tester.widget<BusyMaxMenuButton<String>>(
    find.descendant(
      of: picker,
      matching: find.byType(BusyMaxMenuButton<String>),
    ),
  );
  final index = menu.entries.indexWhere((entry) => entry.label == title);
  expect(index, greaterThan(0));
  await _tapVisible(tester, picker);
  await tester.pump();
  await tester.runAsync(() async {
    // The Linux picker uses a GTK menu outside the Flutter widget tree.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final keys = await Process.run('xdotool', [
      'key',
      '--clearmodifiers',
      '--delay',
      '100',
      'Home',
      for (var item = 0; item < index; item++) 'Down',
      'Return',
    ]);
    expect(keys.exitCode, 0);
  });
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
          of: find.byType(JournalPane),
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

Future<void> _refresh(
  WidgetTester tester,
  ProviderContainer container, {
  bool confirmPartial = false,
  String Function()? failureContext,
}) async {
  if (Platform.isLinux) {
    final menu = tester.widget<BusyMaxMainMenuButton>(
      find.byType(BusyMaxMainMenuButton),
    );
    menu.onSelected(ScheduleToolbarMenuAction.refresh);
  } else if (Platform.isWindows) {
    await _tapVisible(tester, find.byTooltip('See more'));
    await waitJournalWidget(tester, find.text('Refresh all'));
    await _tapVisible(tester, find.text('Refresh all'));
  } else {
    final menu = find.byKey(const ValueKey('android-workspace-menu'));
    await _tapVisible(tester, menu);
    await waitJournalWidget(tester, find.text('Refresh all'));
    await _tapVisible(tester, find.text('Refresh all'));
  }
  await tester.pump();
  if (Platform.isAndroid && confirmPartial) {
    final dialog = find.widgetWithText(
      AlertDialog,
      'Refresh partially completed',
    );
    await waitJournalWidget(tester, dialog);
    await _tapVisible(
      tester,
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, 'Retry'),
      ),
    );
  }
  final activity = container.read(accountSyncActivityProvider);
  final deadline = Stopwatch()..start();
  while (activity.busy(allSyncScope) &&
      deadline.elapsed < const Duration(seconds: 90)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(activity.busy(allSyncScope), isFalse, reason: failureContext?.call());
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
