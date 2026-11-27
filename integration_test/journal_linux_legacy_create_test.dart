import 'dart:convert';
import 'dart:io';

import 'package:busymax/main_linux.dart' as linux;
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support/journal_workflow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final stage = Platform.environment['BUSYMAX_LINUX_LEGACY_CREATE_STAGE'];
  testWidgets(
    'Linux historical journal creation recovery ($stage)',
    (tester) async {
      expect(Platform.isLinux, isTrue);
      expect(Platform.environment['GDK_BACKEND'], 'x11');
      expect(stage, anyOf('export', 'repair', 'transfer'));
      final profile = Directory(Platform.environment['XDG_DATA_HOME']!);
      final support = (await tester.runAsync(getApplicationSupportDirectory))!;
      expect(support.path, startsWith('${profile.path}/'));
      final databaseFile = File('${support.path}/busymax.sqlite');
      final receipt = File('${profile.path}/journal-export-process');
      final exported = File('${profile.path}/journal-recovery.json');
      if (stage == 'export') {
        expect(databaseFile.existsSync(), isFalse);
        expect(exported.existsSync(), isFalse);
        databaseFile.writeAsBytesSync(
          gzip.decode(
            File('test/journal/fixtures/legacy-create-range-v28.sqlite.gz')
                .readAsBytesSync(),
          ),
        );
      } else {
        expect(int.parse(receipt.readAsStringSync()), isNot(pid));
        expect(databaseFile.existsSync(), isTrue);
        expect(exported.existsSync(), isTrue);
      }

      await tester.runAsync(() => linux.main([]));
      await waitJournalWidget(tester, find.byType(LinuxBusyMaxApp));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LinuxBusyMaxApp)),
        listen: false,
      );
      final database = container.read(databaseProvider);
      final operation = (await tester.runAsync(
        () => database.select(database.pendingOps).getSingle(),
      ))!;
      expect(operation.operationType, 'dav.create');
      expect(operation.attemptCount, 0);
      expect(operation.baselineEtag, isNull);
      container.read(appRouterProvider).go('/journals');
      final label = find.textContaining(RegExp(r'^Series ·'));
      await waitJournalWidget(tester, label);
      await tester.tap(label);

      if (stage == 'transfer') {
        await _transferJournalFiles(tester, profile);
        debugPrint('JOURNAL_LINUX_LEGACY_CREATE transfer PASS');
        await tester.pumpWidget(const SizedBox.shrink());
        return;
      }

      if (stage == 'export') {
        final save = find.text('Export recovery bundle (JSON)');
        await _tap(tester, save);
        await tester.runAsync(() => _saveInGtk(exported));
        await _waitForFile(tester, exported);
      }
      final recovery = jsonDecode(exported.readAsStringSync()) as Map;
      expect(recovery['operationId'], operation.id);
      expect(recovery['requestJson'], operation.requestJson);
      expect(
        recovery['invalidCandidateIcs'],
        (jsonDecode(operation.requestJson) as Map)['rawIcs'],
      );
      if (stage == 'export') {
        expect(
          (await tester.runAsync(
            () => database.select(database.pendingOps).getSingle(),
          ))!,
          operation,
        );
        receipt.writeAsStringSync('$pid');
      } else {
        await _tap(tester, find.text('2. Offline future edit'));
        await _tap(tester, find.text('Queue reviewed journal'));
        await waitJournalWidget(tester, label);
        final committed = (await tester.runAsync(
          () => database.select(database.pendingOps).getSingle(),
        ))!;
        expect(committed.id, operation.id);
        final repository = JournalRepository(database);
        final repaired = (await tester.runAsync(() async {
          final entries = await repository.watchEntries().first;
          return repository.read(
            entries.singleWhere(
              (row) => row.uid != 'sibling' && row.recurrenceIdKey == null,
            ),
          );
        }))!;
        expect(repaired.pendingRecovery, isNull);
        expect(
          repaired.effectiveRawIcs,
          contains('SUMMARY:Offline future edit'),
        );
        expect(
          repaired.effectiveRawIcs,
          isNot(contains('SUMMARY:Original detached entry')),
        );
      }
      debugPrint('JOURNAL_LINUX_LEGACY_CREATE $stage PASS');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: stage == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _tap(WidgetTester tester, Finder control) async {
  await waitJournalWidget(tester, control);
  await tester.ensureVisible(control);
  await tester.tap(control.hitTestable());
  await tester.pump();
}

Future<void> _transferJournalFiles(
  WidgetTester tester,
  Directory profile,
) async {
  const expectedBytes = [0, 1, 128, 255, 10, 13, 42];
  final input = File('${profile.path}/fixture.bin')
    ..writeAsBytesSync(expectedBytes);
  await _tapEditorAction(tester, find.text('Choose file…'));
  await tester.runAsync(() => _selectInGtk(input, saving: false));
  await waitJournalWidget(tester, find.text('fixture.bin'));

  final saved = File('${profile.path}/saved-fixture.bin');
  final attachmentRow = find
      .ancestor(of: find.text('fixture.bin'), matching: find.byType(Wrap))
      .first;
  await _tapEditorAction(
    tester,
    find.descendant(of: attachmentRow, matching: find.text('Save')),
  );
  await tester.runAsync(() => _selectInGtk(saved, saving: true));
  await _waitForFile(tester, saved);
  expect(saved.readAsBytesSync(), expectedBytes);

  await _tapEditorAction(tester, find.widgetWithText(ElevatedButton, 'Save'));
  final label = find.textContaining(RegExp(r'^Series ·'));
  await waitJournalWidget(tester, label);
  await _tap(tester, label);
  await _tapEditorAction(tester, find.text('Export'));
  final exported = File('${profile.path}/roundtrip.ics');
  await tester.runAsync(() => _selectInGtk(exported, saving: true));
  await _waitForFile(tester, exported);
  final content = exported.readAsStringSync().replaceAll(
    RegExp(r'\r?\n[ \t]'),
    '',
  );
  expect(content, contains('BEGIN:VJOURNAL'));
  final attachment = const LineSplitter()
      .convert(content)
      .singleWhere((line) => line.startsWith('ATTACH;'));
  final valueStart = attachment.indexOf(':');
  expect(attachment.substring(0, valueStart), contains('VALUE=BINARY'));
  expect(attachment.substring(0, valueStart), contains('ENCODING=BASE64'));
  expect(base64Decode(attachment.substring(valueStart + 1)), expectedBytes);

  const importedUid = 'linux-journal-file-roundtrip@example.invalid';
  final imported = File('${profile.path}/import-journal.ics')
    ..writeAsStringSync(
      content.replaceAll(
        RegExp(r'^UID:[^\r\n]+', multiLine: true),
        'UID:$importedUid',
      ),
    );
  await _tapEditorAction(tester, find.text('Close'));
  await _tap(tester, find.text('Import .ics file'));
  await tester.runAsync(() => _selectInGtk(imported, saving: false));
  await _tap(tester, find.text('Save'));
  await waitJournalWidget(tester, find.text(importedUid));
  await _tap(tester, find.text('Close'));
  final entries = find.textContaining(RegExp(r'^Series ·'));
  await waitJournalWidget(tester, entries.at(1));
  expect(entries, findsNWidgets(2));
}

Future<void> _tapEditorAction(WidgetTester tester, Finder control) async {
  final editor = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );
  await waitJournalWidget(tester, editor);
  await tester.scrollUntilVisible(control, 210, scrollable: editor.first);
  await _tap(tester, control);
}

Future<void> _waitForFile(WidgetTester tester, File file) async {
  for (var attempt = 0; attempt < 100 && !file.existsSync(); attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(file.existsSync(), isTrue, reason: file.path);
}

Future<void> _saveInGtk(File result) => _selectInGtk(result, saving: true);

Future<void> _selectInGtk(File result, {required bool saving}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  final title = saving ? r'^Save File$' : r'^Open File$';
  while (DateTime.now().isBefore(deadline)) {
    final search = await Process.run('xdotool', [
      'search',
      '--onlyvisible',
      '--name',
      title,
    ]);
    if (search.exitCode != 0) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      continue;
    }
    final window = (search.stdout as String).trim();
    expect(window, matches(RegExp(r'^\d+$')));
    for (final command in [
      ['windowfocus', '--sync', window],
      ['key', '--clearmodifiers', 'ctrl+l'],
      ['key', '--clearmodifiers', 'ctrl+a'],
      ['type', '--clearmodifiers', result.path],
      ['key', '--clearmodifiers', 'Return'],
    ]) {
      expect((await Process.run('xdotool', command)).exitCode, 0);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    final visible = await Process.run('xdotool', [
      'search',
      '--onlyvisible',
      '--name',
      title,
    ]);
    if (visible.exitCode == 0 && (visible.stdout as String).trim() == window) {
      expect(
        (await Process.run('xdotool', [
          'key',
          '--clearmodifiers',
          saving ? 'alt+s' : 'alt+o',
        ])).exitCode,
        0,
      );
    }
    return;
  }
  throw TestFailure('The native GTK file picker did not open.');
}
