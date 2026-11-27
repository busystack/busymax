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
      expect(stage, anyOf('export', 'repair'));
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

      if (stage == 'export') {
        final save = find.text('Export recovery bundle (JSON)');
        await _tap(tester, save);
        await tester.runAsync(() => _saveInGtk(exported));
        for (
          var attempt = 0;
          attempt < 100 && !exported.existsSync();
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
        }
        expect(
          exported.existsSync(),
          isTrue,
          reason: 'GTK must save the selected recovery file.',
        );
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

Future<void> _saveInGtk(File result) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    final search = await Process.run('xdotool', [
      'search',
      '--onlyvisible',
      '--name',
      r'^Save File$',
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
      r'^Save File$',
    ]);
    if (visible.exitCode == 0 && (visible.stdout as String).trim() == window) {
      expect(
        (await Process.run('xdotool', [
          'key',
          '--clearmodifiers',
          'alt+s',
        ])).exitCode,
        0,
      );
    }
    return;
  }
  throw TestFailure('The native GTK save picker did not open.');
}
