import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/ui/windows/windows_task_details_dialog.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    for (final staleScheduleCompletion in [false, true]) {
      testWidgets(
        '${provider.name} loaded completion survives title Save (schedule completed $staleScheduleCompletion)',
        (tester) async {
          final database = AppDatabase(NativeDatabase.memory());
          var databaseClosed = false;
          addTearDown(() async {
            if (!databaseClosed) await database.close();
          });
          const now = '2026-10-22T12:00:00.000Z';
          await database
              .into(database.accounts)
              .insert(
                AccountsCompanion.insert(
                  id: 'account',
                  provider: provider.storageValue,
                  authority: 'https://accounts.google.com',
                  providerAccountId: 'qa@example.test',
                  credentialKind: 'oauth',
                  authState: const Value('signed_in'),
                  createdAtUtc: now,
                  updatedAtUtc: now,
                ),
              );
          await database.taskListsDao.upsertTaskList(
            TaskListsCompanion.insert(
              accountId: 'account',
              id: 'list',
              title: 'Inbox',
              rawJson: '{}',
              createdLocalAtUtc: now,
              updatedLocalAtUtc: now,
            ),
          );
          await database.tasksDao.upsertTask(
            TasksCompanion.insert(
              accountId: 'account',
              taskListId: 'list',
              id: 'task',
              title: 'Loaded title',
              status: const Value('completed'),
              completedUtc: const Value(now),
              updatedUtc: const Value(now),
              rawJson: jsonEncode({
                'id': 'task',
                'title': 'Loaded title',
                'status': 'completed',
                'completed': now,
                'updated': now,
              }),
              createdLocalAtUtc: now,
              updatedLocalAtUtc: now,
            ),
          );
          final repository = TasksRepository(
            database: database,
            accountId: 'account',
          );
          final lists = TaskListsRepository(
            database: database,
            accountId: 'account',
          );
          Object? openError;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(database),
                localTimeZoneProvider.overrideWithValue('Etc/UTC'),
                tasksRepositoryForAccountProvider.overrideWith(
                  (ref, accountId) => repository,
                ),
                taskListsRepositoryForAccountProvider.overrideWith(
                  (ref, accountId) => lists,
                ),
              ],
              child: FluentApp(
                localizationsDelegates: const [AppLocalizations.delegate],
                supportedLocales: AppLocalizations.supportedLocales,
                home: Consumer(
                  builder: (context, ref, _) => Button(
                    onPressed: () async {
                      try {
                        await showWindowsTaskDetailsDialog(
                          context,
                          ref,
                          TaskScheduleItem(
                            id: 'task',
                            accountId: 'account',
                            provider: provider,
                            sourceId: 'list',
                            title: 'Loaded title',
                            completed: staleScheduleCompletion,
                            allDay: true,
                          ),
                        );
                      } on Object catch (error) {
                        openError = error;
                      }
                    },
                    child: const Text('Open details'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open details'));
          for (
            var i = 0;
            i < 20 && find.byType(ContentDialog).evaluate().isEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          await tester.pumpAndSettle();
          expect(openError, isNull);
          expect(find.byType(ContentDialog), findsOneWidget);
          final title = find.byWidgetPredicate(
            (widget) =>
                widget is TextBox && widget.controller?.text == 'Loaded title',
          );
          await tester.enterText(title, 'Local title');
          final save = find.widgetWithText(FilledButton, 'Save');
          await tester.ensureVisible(save);
          await tester.tap(save);
          for (
            var i = 0;
            i < 20 && find.byType(ContentDialog).evaluate().isNotEmpty;
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
          await tester.pumpAndSettle();
          final task = (await tester.runAsync(
            () => database.select(database.tasks).getSingle(),
          ))!;
          final pending = (await tester.runAsync(
            () => database.select(database.pendingOps).getSingle(),
          ))!;
          expect(task.title, 'Local title');
          expect(task.status, 'completed');
          expect(jsonDecode(pending.requestJson), {'title': 'Local title'});
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 1));
          await tester.runAsync(database.close);
          databaseClosed = true;
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
