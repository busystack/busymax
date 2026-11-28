import 'dart:convert';
import 'dart:io';

import 'package:busymax/main_linux.dart' as linux;
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/domain/account_connection_state.dart';
import 'package:busymax/src/journal/journal_repository.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'support/journal_linux_files.dart';
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
      if (stage == 'transfer') {
        // Exercise ordinary source actions on an active, offline account.
        // Export and repair use the original signed-out fixture.
        await tester.runAsync(
          () =>
              (database.update(
                    database.accounts,
                  )..where((account) => account.id.equals(operation.accountId)))
                  .write(
                    AccountsCompanion(
                      authState: Value(
                        AccountConnectionState
                            .temporarilyUnavailable
                            .storageValue,
                      ),
                    ),
                  ),
        );
      }
      container.read(appRouterProvider).go('/schedule');
      await openJournalSearch(tester);
      await tester.enterText(journalScheduleSearchInput(), 'Series');
      final label = journalResultTitle('Series');
      await waitJournalWidget(tester, label);
      await tester.tap(label);

      if (stage == 'transfer') {
        await enterJournalEditor(tester);
        await transferLinuxJournalFiles(
          tester,
          profile,
          title: 'Series',
          importedTitle: 'GTK imported series',
          importedUid: 'linux-journal-file-roundtrip@example.invalid',
          account: operation.accountId,
          source: (await tester.runAsync(() async {
            final entries = await JournalRepository(database).listEntries();
            return entries.firstWhere((entry) => entry.title == 'Series');
          }))!.collectionId,
        );
        debugPrint('JOURNAL_LINUX_LEGACY_CREATE transfer PASS');
        await tester.pumpWidget(const SizedBox.shrink());
        return;
      }

      if (stage == 'export') {
        final save = find.text('Export recovery bundle (JSON)');
        await tapLinuxJournalControl(tester, save);
        await tester.runAsync(
          () => selectLinuxJournalFile(exported, saving: true),
        );
        await waitForLinuxJournalFile(tester, exported);
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
        await tapLinuxJournalControl(
          tester,
          find.text('2. Offline future edit'),
        );
        await tapLinuxJournalControl(
          tester,
          find.text('Queue reviewed journal'),
        );
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
