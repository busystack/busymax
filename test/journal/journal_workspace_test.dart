import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_window_close.dart';
import 'package:busymax/src/dav/ical/dav_native_import.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_import_review.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/journal/presentation/journal_workspace.dart';
import 'package:busymax/src/journal/presentation/material_journal_controls.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Finder field(String name) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == name,
);

Future<void> setupSource(AppDatabase db) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'qa',
          provider: 'caldav',
          authority: 'https://example.invalid/',
          providerAccountId: 'qa',
          credentialKind: 'caldav_password',
          authState: const Value('signed_in'),
          createdAtUtc: 'now',
          updatedAtUtc: 'now',
        ),
      );
  await db
      .into(db.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'source',
          accountId: 'qa',
          hrefKey: '/dav/journals/',
          requestUri: 'https://example.invalid/dav/journals/',
          displayName: 'Fixture journal',
          journalProjectionEnabled: const Value(true),
          journalInventoryComplete: const Value(true),
          currentUserPrivilegesJson: const Value('["{DAV:}all"]'),
          supportedComponentMask: const Value(8),
          createdAtUtc: 'now',
          updatedAtUtc: 'now',
        ),
      );
}

void main() {
  testWidgets(
    'historical journal updates offer bundle export and reviewed reapply',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'journal-workspace-recovery',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/legacy.db');
      file.writeAsBytesSync(
        gzip.decode(
          File('test/journal/fixtures/legacy-range-v28.sqlite.gz')
              .readAsBytesSync(),
        ),
      );
      final database = AppDatabase.memoryForTests();
      addTearDown(database.close);
      final baseline = await tester.runAsync(() async {
        final fixture = AppDatabase(NativeDatabase(file));
        try {
          await database
              .into(database.accounts)
              .insert(await fixture.select(fixture.accounts).getSingle());
          await database
              .into(database.davCollections)
              .insert(await fixture.select(fixture.davCollections).getSingle());
          for (final row in await fixture.select(fixture.davObjects).get()) {
            await database.into(database.davObjects).insert(row);
          }
          for (final row
              in await fixture.select(fixture.davObjectComponents).get()) {
            await database.into(database.davObjectComponents).insert(row);
          }
          for (final row
              in await fixture.select(fixture.davJournalEntries).get()) {
            await database.into(database.davJournalEntries).insert(row);
          }
          final operation = await fixture
              .select(fixture.pendingOps)
              .getSingle();
          await database.into(database.pendingOps).insert(operation);
          return operation;
        } finally {
          await fixture.close();
        }
      });
      String? recoveryFile;
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: JournalWorkspace(
                controls: const MaterialJournalControls(),
                files: JournalFileActions(
                  read: () async => null,
                  export: (_) async {},
                  pickAttachment: () async => null,
                  saveAttachment: (_) async => null,
                  exportDraft: (raw) async => recoveryFile = raw,
                ),
              ),
            ),
          ),
        ),
      );
      final note = find.textContaining(RegExp(r'^Series ·'));
      await _wait(tester, note);
      await tester.tap(note);
      final recovery = find.text('Export recovery bundle (JSON)');
      await _wait(tester, recovery);
      await tester.ensureVisible(recovery);
      await tester.tap(recovery);
      await _settle(tester);
      final exported = jsonDecode(recoveryFile!) as Map;
      expect(exported['mutationPatchJson'], baseline!.mutationPatchJson);
      expect(exported['baselineIcs'], baseline.baselineRawIcs);
      expect(
        exported['invalidCandidateIcs'],
        contains('SUMMARY:Offline future edit'),
      );
      expect(
        exported['invalidCandidateIcs'],
        contains('SUMMARY:Original detached entry'),
      );
      final apply = find.widgetWithText(FilledButton, 'Queue reviewed journal');
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      final choice = find.text('2. Offline future edit');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await _wait(tester, note);
      final repaired = await tester.runAsync(
        () => database.select(database.pendingOps).getSingle(),
      );
      expect(repaired!.id, baseline.id);
      expect(repaired.mutationPatchJson, contains('Offline future edit'));
      expect(
        repaired.mutationPatchJson,
        isNot(contains('Original detached entry')),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'journal collection controls remain reachable with a narrow keyboard viewport',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      await tester.runAsync(() => setupSource(db));
      await tester.binding.setSurfaceSize(const Size(320, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewInsets: const EdgeInsets.only(bottom: 190),
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: const Scaffold(
              body: JournalWorkspace(controls: MaterialJournalControls()),
            ),
          ),
        ),
      );
      final create = find
          .byWidgetPredicate(
            (widget) =>
                widget is OutlinedButton &&
                widget.onPressed != null &&
                widget.child is Text &&
                (widget.child as Text).data == 'New journal collection',
          )
          .hitTestable();
      await _wait(tester, create);
      await tester.tap(create);
      await tester.pump();
      final title = field('Title');
      await _wait(tester, title);
      await tester.ensureVisible(title);
      await tester.enterText(title, 'Narrow collection');
      await tester.pump();
      final save = find.widgetWithText(OutlinedButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pump();
      expect(save.hitTestable(), findsOneWidget);
      expect(
        tester.widget<TextField>(title).controller?.text,
        'Narrow collection',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'journal import reviews partial outcomes and retries only failures',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      await tester.runAsync(() async {
        await setupSource(db);
        await DavNativeImportService(db).import(
          accountId: 'qa',
          collectionId: 'source',
          preview: NextcloudNativeImportPreview.parse(
            IcalDocument.parse(
              [
                'BEGIN:VCALENDAR',
                'VERSION:2.0',
                'PRODID:-//BusyMax//Import review test//EN',
                'BEGIN:VJOURNAL',
                'UID:known-journal@example.invalid',
                'DTSTAMP:20261125T120000Z',
                'ORGANIZER:mailto:owner@example.invalid',
                'SUMMARY:Original journal',
                'END:VJOURNAL',
                'END:VCALENDAR',
                '',
              ].join('\r\n'),
            ),
          ),
        );
      });
      final message = [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//BusyMax//Import review test//EN',
        'METHOD:PUBLISH',
        for (final (uid, summary) in [
          ('known-journal@example.invalid', 'Mismatched organizer'),
          ('new-journal@example.invalid', 'Successful sibling'),
        ]) ...[
          'BEGIN:VJOURNAL',
          'UID:$uid',
          'DTSTAMP:20261126T120000Z',
          'ORGANIZER:mailto:other@example.invalid',
          'DTSTART:20261126T090000Z',
          'DESCRIPTION:Reviewed body',
          'SUMMARY:$summary',
          'END:VJOURNAL',
        ],
        'END:VCALENDAR',
        '',
      ].join('\r\n');
      var reads = 0;
      String? recoveryExport;
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget app() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: JournalWorkspace(
              controls: const MaterialJournalControls(),
              files: JournalFileActions(
                read: () async {
                  reads++;
                  return Uint8List.fromList(utf8.encode(message));
                },
                export: (_) async {},
                exportDraft: (value) async {
                  recoveryExport = value;
                },
                pickAttachment: () async => null,
                saveAttachment: (_) async => null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await _wait(tester, find.textContaining('Original journal'));
      final import = find.byWidgetPredicate(
        (widget) =>
            widget is OutlinedButton &&
            widget.onPressed != null &&
            widget.child is Text &&
            (widget.child as Text).data == 'Import .ics file',
      );
      await _wait(tester, import);
      await tester.tap(import.first);
      await _wait(tester, find.text('Successful sibling'));
      await tester.tap(find.text('Save'));
      final organizerError = find.textContaining('organizer differs');
      await _wait(tester, organizerError);
      expect(find.text('new-journal@example.invalid'), findsOneWidget);
      expect(find.text('Successful sibling'), findsNothing);
      await tester.tap(find.text('Close'));
      await _wait(tester, import);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(app());
      await _wait(tester, import);
      await tester.tap(import.first);
      await _wait(tester, organizerError);
      expect(reads, 1);
      await tester.tap(find.text('Export recovery bundle (JSON)'));
      await _settle(tester);
      expect(
        JournalImportReview.decode(recoveryExport!).sourceBytes,
        utf8.encode(message),
      );
      await tester.tap(find.text('Save'));
      await _settle(tester);
      expect(organizerError, findsOneWidget);
      final entries = await tester.runAsync(
        () => JournalRepository(db).watchEntries().first,
      );
      expect(
        entries!.map((entry) => entry.title),
        unorderedEquals(['Original journal', 'Successful sibling']),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'journal import review reopens with queued IDs and exact unsent input',
    () async {
      final directory = await Directory.systemTemp.createTemp('journal-review');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/review.sqlite');
      var database = AppDatabase(NativeDatabase(file));
      addTearDown(() => database.close());
      await setupSource(database);
      var reviews = JournalImportReviewRepository(JournalRepository(database));
      const raw =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//BusyMax//QA//EN\r\n'
          'BEGIN:VJOURNAL\r\nUID:valid\r\nDTSTAMP:20261126T090000Z\r\n'
          'SUMMARY:Retained input\r\nEND:VJOURNAL\r\nEND:VCALENDAR\r\n';
      final source = await database.select(database.davCollections).getSingle();
      await reviews.begin(
        source,
        JournalImportReview(
          NextcloudNativeImportPreview.parse(IcalDocument.parse(raw)),
          utf8.encode(raw),
        ),
      );
      final open = (await reviews.watch().first)!;
      final expectedBody = open.preview.resources.single.rawIcs;
      expect(open.destinationId, source.id);
      await database.customStatement('''
        CREATE TRIGGER fail_review_update BEFORE UPDATE ON dav_journal_drafts
        BEGIN SELECT RAISE(ABORT, 'fixture write failure'); END
      ''');
      await expectLater(reviews.queue(open, source), throwsException);
      expect(await database.select(database.pendingOps).get(), isEmpty);
      expect((await reviews.watch().first)!.encode(), open.encode());
      await database.customStatement('DROP TRIGGER fail_review_update');
      await reviews.queue(open, source);
      await expectLater(reviews.queue(open, source), throwsException);
      final queued = (await database.select(database.pendingOps).get()).single;
      await database.close();
      database = AppDatabase(NativeDatabase(file));
      reviews = JournalImportReviewRepository(JournalRepository(database));
      final resumed = (await reviews.watch().first)!;
      expect(resumed.sourceBytes, utf8.encode(raw));
      expect(resumed.preview.resources.single.rawIcs, expectedBody);
      expect(resumed.destinationId, source.id);
      expect(resumed.results.single.status, NativeImportItemStatus.queued);
      expect(resumed.results.single.operationId, queued.id);
      expect(resumed.remaining(source.id).resources, isEmpty);
      await reviews.discard(resumed);
      expect(await reviews.watch().first, isNull);
      expect(
        (await database.select(database.pendingOps).get()).single.id,
        queued.id,
      );
    },
  );

  testWidgets(
    'a stale journal exposes the complete draft and current version in JSON',
    (tester) async {
      final database = AppDatabase.memoryForTests();
      addTearDown(database.close);
      final repository = JournalRepository(database);
      await tester.runAsync(() async {
        await setupSource(database);
        await repository.create(
          (await repository.watchSources().first).single,
          title: 'Saved journal',
        );
        final row = (await repository.watchEntries().first).single;
        await repository.saveDraft(
          id: 'entry:${row.componentId}',
          collectionId: 'source',
          baselineDigest: 'prior-digest',
          contentJson: jsonEncode({
            'title': 'Retained title',
            'date': '20261126',
            'mode': 'date',
            'status': 'FINAL',
            'zone': '',
            'frequency': '',
            'DESCRIPTION': [
              {'value': 'Retained body', 'parameters': []},
            ],
            'ATTACH': [
              {
                'value': 'https://example.invalid/draft-attachment',
                'parameters': [],
              },
            ],
            'details': [
              {
                'name': 'LINK',
                'value': 'https://example.invalid/edited',
                'parameters': [
                  {
                    'name': 'VALUE',
                    'values': ['URI'],
                    'wasQuoted': false,
                  },
                ],
              },
              {
                'name': 'RRULE',
                'value': 'FREQ=DAILY;COUNT=3',
                'parameters': [],
              },
            ],
            'children': [
              {
                'name': 'VSTATUS',
                'children': [
                  {'property': 'STATUS', 'value': 'FINAL', 'parameters': []},
                  {
                    'property': 'COMMENT',
                    'value': 'Retained status comment',
                    'parameters': [],
                  },
                ],
              },
            ],
          }),
        );
      });
      String? exported;
      await tester.binding.setSurfaceSize(const Size(1100, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: JournalWorkspace(
                controls: const MaterialJournalControls(),
                files: JournalFileActions(
                  read: () async => null,
                  export: (_) async {},
                  exportDraft: (value) async {
                    exported = value;
                  },
                  pickAttachment: () async => null,
                  saveAttachment: (_) async => null,
                ),
              ),
            ),
          ),
        ),
      );
      final saved = find.textContaining('Saved journal');
      await _wait(tester, saved);
      await tester.tap(saved);
      await _wait(tester, find.text('Retained title'));
      expect(field('Title'), findsNothing);
      final export = find.text('Export JSON');
      await tester.scrollUntilVisible(
        export,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(export);
      await _settle(tester);
      final recovery = (jsonDecode(exported!) as Map).cast<String, Object?>();
      expect(recovery['format'], 'busymax-journal-draft');
      expect(recovery['savedIcalendar'], contains('SUMMARY:Saved journal'));
      final editor = (jsonDecode(recovery['editorStateJson'] as String) as Map)
          .cast<String, Object?>();
      expect(
        jsonEncode(editor['details']),
        contains('https://example.invalid/edited'),
      );
      expect(jsonEncode(editor['details']), contains('FREQ=DAILY;COUNT=3'));
      expect(
        jsonEncode(editor['children']),
        contains('Retained status comment'),
      );
      expect(jsonEncode(editor['DESCRIPTION']), contains('Retained body'));
      expect(jsonEncode(editor['ATTACH']), contains('draft-attachment'));
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await _wait(tester, saved);
      const unknownDraft =
          '{"version":9000,"unrecognized":{"early":"keep",'
          '"later":["keep", "\\n"]}}';
      final id = await tester.runAsync(() async {
        final row = (await repository.watchEntries().first).single;
        final id = 'entry:${row.componentId}';
        await repository.saveDraft(
          id: id,
          collectionId: 'source',
          baselineDigest: 'prior-digest',
          contentJson: unknownDraft,
        );
        return id;
      });
      await tester.tap(saved);
      await _wait(
        tester,
        find.text('The journal draft could not be saved on this device.'),
      );
      expect(field('Title'), findsNothing);
      await tester.ensureVisible(export);
      await tester.tap(export);
      await _settle(tester);
      expect((jsonDecode(exported!) as Map)['editorStateJson'], unknownDraft);
      final untouched = await tester.runAsync(() => repository.readDraft(id!));
      expect(untouched!.contentJson, unknownDraft);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed journal draft saves block close, system back and route exit',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(db.close);
      await tester.runAsync(() async {
        await setupSource(db);
        await db.customStatement(
          'CREATE TEMP TRIGGER journal_draft_fail BEFORE INSERT ON dav_journal_drafts '
          "BEGIN SELECT RAISE(ABORT, 'fixture draft write failure'); END",
        );
      });
      final coordinator = BusyMaxWindowCloseCoordinator();
      final router = GoRouter(
        initialLocation: '/journals',
        routes: [
          GoRoute(
            path: '/journals',
            onExit: (_, _) => coordinator.requestClose(),
            builder: (_, _) => Scaffold(
              body: JournalWorkspace(
                controls: const MaterialJournalControls(),
                navigationCoordinator: coordinator,
              ),
            ),
          ),
          GoRoute(path: '/away', builder: (_, _) => const Text('Away')),
        ],
      );
      addTearDown(router.dispose);
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      final newEntry = find.byWidgetPredicate(
        (widget) =>
            widget is FilledButton &&
            widget.onPressed != null &&
            widget.child is Text &&
            (widget.child as Text).data == 'New entry',
      );
      await _wait(tester, newEntry);
      await tester.tap(newEntry);
      await _wait(tester, field('Title'));
      await tester.enterText(field('Title'), 'Unsaved exact text');
      final writeFailed = find.text(
        'The journal draft could not be saved on this device.',
      );
      await _wait(tester, writeFailed);
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await _settle(tester);
      expect(field('Title'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(field('Title'), findsOneWidget);
      router.go('/away');
      await _settle(tester);
      expect(find.text('Away'), findsNothing);
      expect(
        tester.widget<TextField>(field('Title')).controller!.text,
        'Unsaved exact text',
      );
      await tester.runAsync(
        () => db.customStatement('DROP TRIGGER journal_draft_fail'),
      );
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await _wait(tester, find.text('Draft saved on this device'));
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await _wait(tester, newEntry);
      await tester.tap(newEntry);
      await _wait(tester, field('Title'));
      expect(
        tester.widget<TextField>(field('Title')).controller!.text,
        'Unsaved exact text',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _wait(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await _settle(tester);
  }
  expect(finder, findsWidgets);
}
