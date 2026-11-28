import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/journal/presentation/journal_pane.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journal_workflow.dart';

const linuxJournalAttachment = <int>[0, 1, 128, 255, 10, 13, 42];

Future<void> transferLinuxJournalFiles(
  WidgetTester tester,
  Directory profile, {
  required String title,
  required String importedTitle,
  required String importedUid,
  required String account,
  required String source,
}) async {
  final input = File('${profile.path}/fixture.bin')
    ..writeAsBytesSync(linuxJournalAttachment);
  await _tapEditorAction(tester, find.text('Choose file…'));
  await tester.runAsync(() => selectLinuxJournalFile(input, saving: false));
  await waitJournalWidget(tester, find.text('fixture.bin'));

  final saved = File('${profile.path}/saved-fixture.bin');
  final attachmentRow = find
      .ancestor(of: find.text('fixture.bin'), matching: find.byType(Wrap))
      .first;
  await _tapEditorAction(
    tester,
    find.descendant(of: attachmentRow, matching: find.text('Save')),
  );
  await tester.runAsync(() => selectLinuxJournalFile(saved, saving: true));
  await waitForLinuxJournalFile(tester, saved);
  expect(saved.readAsBytesSync(), linuxJournalAttachment);

  await _tapEditorAction(tester, find.widgetWithText(ElevatedButton, 'Save'));
  final label = journalResultTitle(title);
  await waitJournalWidget(tester, label);
  await tapLinuxJournalControl(tester, label);
  await tapLinuxJournalControl(tester, find.byTooltip('Export'));
  final exported = File('${profile.path}/roundtrip.ics');
  await tester.runAsync(() => selectLinuxJournalFile(exported, saving: true));
  await waitForLinuxJournalFile(tester, exported);
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
  expect(
    base64Decode(attachment.substring(valueStart + 1)),
    linuxJournalAttachment,
  );

  final imported = File('${profile.path}/import-journal.ics')
    ..writeAsStringSync(
      content
          .replaceAll(
            RegExp(r'^UID:[^\r\n]+', multiLine: true),
            'UID:$importedUid',
          )
          .replaceAll(
            RegExp(r'^SUMMARY:[^\r\n]+', multiLine: true),
            'SUMMARY:$importedTitle',
          ),
    );
  final pane = find.byType(JournalPane);
  await tapLinuxJournalControl(
    tester,
    find.descendant(of: pane, matching: find.byTooltip('Close')),
  );
  await waitJournalWidget(tester, pane, absent: true);
  await journalCollectionAction(
    tester,
    'Import .ics file',
    account: account,
    source: source,
  );
  await tester.runAsync(() => selectLinuxJournalFile(imported, saving: false));
  await tapLinuxJournalControl(
    tester,
    find.descendant(
      of: pane,
      matching: find.widgetWithText(ElevatedButton, 'Save'),
    ),
  );
  await waitJournalWidget(tester, find.text(importedUid));
  await tapLinuxJournalControl(
    tester,
    find.descendant(
      of: pane,
      matching: find.widgetWithText(FilledButton, 'Close'),
    ),
  );
  await openJournalSearch(tester);
  await tester.enterText(journalScheduleSearchInput(), importedTitle);
  await waitJournalWidget(tester, journalResultTitle(importedTitle));
}

Future<void> _tapEditorAction(WidgetTester tester, Finder control) async {
  final editor = find.descendant(
    of: find.byType(JournalPane),
    matching: find.byType(Scrollable),
  );
  await waitJournalWidget(tester, editor);
  await tester.scrollUntilVisible(control, 210, scrollable: editor.first);
  await tapLinuxJournalControl(tester, control);
}

Future<void> waitForLinuxJournalFile(WidgetTester tester, File file) async {
  for (var attempt = 0; attempt < 100 && !file.existsSync(); attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(file.existsSync(), isTrue, reason: file.path);
}

Future<void> selectLinuxJournalFile(File result, {required bool saving}) async {
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

Future<void> tapLinuxJournalControl(WidgetTester tester, Finder control) async {
  await waitJournalWidget(tester, control);
  await tester.ensureVisible(control);
  final visible = control.hitTestable();
  await waitJournalWidget(tester, visible);
  await tester.tap(visible);
  await tester.pump();
}
