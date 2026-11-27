import 'dart:convert';
import 'dart:typed_data';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_window_close.dart';
import 'package:busymax/src/dav/ical/dav_native_import.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/journal/presentation/journal_workspace.dart';
import 'package:busymax/src/journal/presentation/material_journal_controls.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:drift/drift.dart' show Value;
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
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
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
                  exportDraft: (_) async {},
                  pickAttachment: () async => null,
                  saveAttachment: (_) async => null,
                ),
              ),
            ),
          ),
        ),
      );
      await _wait(tester, find.textContaining('Original journal'));
      final import = find.widgetWithText(OutlinedButton, 'Import .ics file');
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
      await tester.tap(import.first);
      await _wait(tester, organizerError);
      expect(reads, 1);
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
