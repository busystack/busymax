import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/ui/windows/windows_task_details_dialog.dart';
import 'package:busymax/src/ui/windows/windows_task_editor_dialog.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'a retained Nextcloud recurrence is safe and actionable after switching to Microsoft',
    (tester) async {
      final db = await _mount(tester);
      await tester.enterText(find.byType(TextBox).first, 'Twice monthly');
      await tester.tap(find.byKey(const ValueKey('task-reminders-recurrence')));
      await tester.pumpAndSettle();
      final repeat = find.widgetWithText(Button, 'None');
      await tester.ensureVisible(repeat);
      await tester.tap(repeat);
      await tester.pumpAndSettle();
      // Exercise the creation dialog's recurrence-result boundary with the full
      // rule accepted by Nextcloud's limits, without depending on picker layout.
      final rule = RecurrenceRule.fromIcalendar(
        rules: ['FREQ=MONTHLY;BYMONTHDAY=1,15'],
      );
      Navigator.of(
        tester.element(find.byType(ComboBox<RecurrenceFrequency>)),
      ).pop(rule);
      await tester.pumpAndSettle();
      await _selectList(tester, 'microsoft');
      expect(tester.takeException(), isNull);
      final warning = find.text(
        'This list cannot use this repeat pattern. Change the pattern or choose another list.',
      );
      expect(warning, findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
            .onPressed,
        isNull,
      );
      expect(await db.select(db.pendingOps).get(), isEmpty);

      // Returning to Nextcloud must restore the entire pattern.
      await _selectList(tester, 'nextcloud');
      expect(warning, findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
            .onPressed,
        isNotNull,
      );
      await _selectList(tester, 'microsoft');
      final fix = find.descendant(
        of: find.ancestor(of: warning, matching: find.byType(InfoBar)),
        matching: find.byType(Button),
      );
      await tester.ensureVisible(fix);
      await tester.tap(fix);
      await tester.pumpAndSettle();
      // Cancelling the compatibility action must keep the incompatible rule.
      await tester.tap(find.widgetWithText(Button, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(warning, findsOneWidget);
      await tester.tap(fix);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ComboBox<RecurrenceFrequency>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('None').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();
      expect(warning, findsNothing);
      await _save(tester);
      final saved = await db.select(db.tasks).getSingle();
      expect(saved.accountId, 'microsoft');
      expect(saved.title, 'Twice monthly');
      expect(saved.recurrenceJson, isNull);
    },
  );

  testWidgets(
    'a hidden invalid Nextcloud URL does not block Google creation and survives returning',
    (tester) async {
      final db = await _mount(tester);
      await tester.enterText(find.byType(TextBox).first, 'Keep my task');
      final organization = find.byKey(
        const ValueKey('task-secondary-properties'),
      );
      await tester.ensureVisible(organization);
      await tester.tap(organization);
      await tester.pumpAndSettle();
      final url = find.descendant(
        of: find.widgetWithText(InfoLabel, 'URL'),
        matching: find.byType(TextBox),
      );
      await tester.ensureVisible(url);
      await tester.enterText(url, 'example.test/retained');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
            .onPressed,
        isNull,
      );
      await _selectList(tester, 'google');
      expect(url, findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
            .onPressed,
        isNotNull,
      );
      await _selectList(tester, 'nextcloud');
      expect(
        tester.widget<TextBox>(url).controller!.text,
        'example.test/retained',
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
            .onPressed,
        isNull,
      );
      await _selectList(tester, 'google');
      await _save(tester);
      final task = await db.select(db.tasks).getSingle();
      expect(task.accountId, 'google');
      expect(task.title, 'Keep my task');
      expect(task.taskUrl, isNull);
      final operation = await db.select(db.pendingOps).getSingle();
      final body = (jsonDecode(operation.requestJson) as Map)['body'];
      expect(body, containsPair('title', 'Keep my task'));
      expect(body, isNot(contains('taskUrl')));
      expect(tester.takeException(), isNull);
    },
  );

  for (final existing in [false, true]) {
    testWidgets(
      'notes-only ${existing ? 'existing' : 'new'} task edits block back dismissal and keep text',
      (tester) async {
        final db = await _mount(
          tester,
          existing: existing,
          initialAccount: 'google',
        );
        final notes = find.byWidgetPredicate(
          (widget) =>
              widget is TextBox && widget.maxLines == (existing ? 5 : 4),
        );
        await tester.ensureVisible(notes);
        await tester.enterText(notes, 'Notes that must survive');
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsOneWidget);
        await tester.tap(find.widgetWithText(Button, 'Cancel').last);
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsNothing);
        expect(
          tester.widget<TextBox>(notes).controller!.text,
          'Notes that must survive',
        );
        expect(find.byType(ContentDialog), findsOneWidget);
        expect(await db.select(db.pendingOps).get(), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _selectList(WidgetTester tester, String accountId) async {
  final selector = find.byType(ComboBox<TaskListEntity>);
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  final label =
      tester
              .widget<ComboBox<TaskListEntity>>(selector)
              .items!
              .singleWhere((item) => item.value!.accountId == accountId)
              .child
          as Text;
  await tester.tap(find.text(label.data!).last);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
  expect(find.byType(ContentDialog), findsNothing);
}

Future<AppDatabase> _mount(
  WidgetTester tester, {
  bool existing = false,
  String initialAccount = 'nextcloud',
}) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase.memoryForTests();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
  for (final provider in ['nextcloud', 'microsoft', 'google']) {
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: provider,
            provider: provider,
            authority: 'https://example.test',
            providerAccountId: '$provider@example.test',
            email: Value('$provider@example.test'),
            credentialKind: provider == 'nextcloud'
                ? 'nextcloud_app_password'
                : 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );
    await db.taskListsDao.upsertTaskList(
      TaskListsCompanion.insert(
        accountId: provider,
        id: 'list',
        title: 'Tasks',
        rawJson: '{}',
        createdLocalAtUtc: _now,
        updatedLocalAtUtc: _now,
      ),
    );
  }
  if (existing) {
    await db.tasksDao.upsertTask(
      TasksCompanion.insert(
        accountId: 'google',
        taskListId: 'list',
        id: 'task',
        title: 'Existing task',
        rawJson: '{}',
        createdLocalAtUtc: _now,
        updatedLocalAtUtc: _now,
      ),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountsRepositoryProvider.overrideWithValue(
          AccountsRepository(database: db),
        ),
        localTimeZoneProvider.overrideWithValue('UTC'),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, id) => TaskListsRepository(database: db, accountId: id),
        ),
        tasksRepositoryForAccountProvider.overrideWith(
          (ref, id) => TasksRepository(database: db, accountId: id),
        ),
        davTaskCollectionCapabilitiesProvider.overrideWith(
          (ref, key) async => nextcloudTaskCollectionCapabilities,
        ),
      ],
      child: FluentApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => Button(
            onPressed: () async {
              if (existing) {
                await showWindowsTaskDetailsDialog(
                  context,
                  ref,
                  const TaskScheduleItem(
                    id: 'task',
                    accountId: 'google',
                    sourceId: 'list',
                    provider: BusyProvider.google,
                    title: 'Existing task',
                    completed: false,
                    allDay: true,
                  ),
                );
              } else {
                await showWindowsTaskEditorDialog(
                  context,
                  ref,
                  initialAccountId: initialAccount,
                  initialDate: initialAccount == 'nextcloud'
                      ? DateTime(2026, 9, 1)
                      : null,
                );
              }
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await tester.tap(find.text('Open'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
  expect(find.byType(ContentDialog), findsOneWidget);
  return db;
}

const _now = '2026-09-01T12:00:00Z';
