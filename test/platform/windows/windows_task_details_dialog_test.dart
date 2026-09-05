import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
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
  testWidgets('Fluent task details exposes hierarchy and list workflows', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account-1',
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'owner@example.test',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: _now,
            updatedAtUtc: _now,
          ),
        );
    for (final (id, title) in [('list-1', 'Inbox'), ('list-2', 'Work')]) {
      await database.taskListsDao.upsertTaskList(
        TaskListsCompanion.insert(
          accountId: 'account-1',
          id: id,
          title: title,
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
    }
    final tasks = _TestTasksRepository(database);
    final lists = TaskListsRepository(
      database: database,
      accountId: 'account-1',
      nowUtc: () => DateTime.utc(2026, 8, 31),
    );
    Object? openError;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          accountsRepositoryProvider.overrideWithValue(
            _TestAccountsRepository(database),
          ),
          localTimeZoneProvider.overrideWithValue('Etc/UTC'),
          tasksRepositoryForAccountProvider.overrideWith(
            (ref, accountId) => tasks,
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
                    const TaskScheduleItem(
                      id: 'parent',
                      accountId: 'account-1',
                      provider: BusyProvider.google,
                      sourceId: 'list-1',
                      title: 'Parent',
                      completed: false,
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
    await tester.pumpAndSettle();

    expect(openError, isNull);
    expect(find.byType(ContentDialog), findsOneWidget);
    expect(find.text('Subtasks'), findsOneWidget);
    expect(find.text('Existing child'), findsOneWidget);
    expect(find.text('Move to top'), findsOneWidget);
    expect(find.byType(ComboBox<String>), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextBox, 'Create subtask'),
      'New child',
    );
    await tester.pump();
    final createButton = find.widgetWithText(Button, 'Create subtask');
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text('New child'), findsOneWidget);
    expect(tasks.createdSubtaskTitles, ['New child']);
    final existingChild = find.text('Existing child');
    await tester.ensureVisible(existingChild);
    await tester.tap(existingChild);
    await tester.pumpAndSettle();
    expect(tasks.watchedTaskIds.last, 'child');

    final titleField = find.byWidgetPredicate(
      (widget) =>
          widget is TextBox && widget.controller?.text == 'Existing child',
    );
    await tester.enterText(titleField, 'Edited child');
    await tester.pump();
    final parentRow = find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.title is Text &&
          (widget.title! as Text).data == 'Parent',
    );
    await tester.tap(parentRow);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(tasks.watchedTaskIds.last, 'child');

    await tester.tap(find.widgetWithText(Button, 'Cancel').last);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    await tester.tap(parentRow);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard').last);
    await tester.pumpAndSettle();
    expect(tasks.watchedTaskIds.last, 'parent');
    expect(tester.takeException(), isNull);
  });
}

class _TestAccountsRepository extends AccountsRepository {
  _TestAccountsRepository(AppDatabase database) : super(database: database);

  @override
  Stream<List<AccountEntity>> watchAccounts() => Stream.value(const [
    AccountEntity(
      id: 'account-1',
      provider: BusyProvider.google,
      authority: 'https://accounts.google.com',
      providerAccountId: 'owner@example.test',
      authState: accountAuthStateSignedIn,
    ),
  ]);
}

class _TestTasksRepository extends TasksRepository {
  _TestTasksRepository(AppDatabase database)
    : super(database: database, accountId: 'account-1');

  final createdSubtaskTitles = <String>[];
  final watchedTaskIds = <String>[];
  final _parent = const TaskEntity(
    accountId: 'account-1',
    taskListId: 'list-1',
    id: 'parent',
    title: 'Parent',
    localDirty: false,
    pendingDelete: false,
    pendingMove: false,
    rawJson: '{}',
    updatedLocalAtUtc: _now,
  );
  final _children = <TaskSubtaskEntity>[
    TaskSubtaskEntity.task(
      const TaskEntity(
        accountId: 'account-1',
        taskListId: 'list-1',
        id: 'child',
        title: 'Existing child',
        localDirty: false,
        pendingDelete: false,
        pendingMove: false,
        rawJson: '{}',
        updatedLocalAtUtc: _now,
      ),
      hasChildren: false,
    ),
  ];

  @override
  Stream<TaskEntity?> watchTask(String taskListId, String taskId) {
    watchedTaskIds.add(taskId);
    if (taskId == 'parent') return Stream.value(_parent);
    return Stream.value(
      _children.where((subtask) => subtask.id == taskId).firstOrNull?.task,
    );
  }

  @override
  Stream<TaskHierarchySnapshot> watchTaskHierarchy(
    String taskListId,
    String taskId,
  ) => Stream.value(
    taskId == 'parent'
        ? TaskHierarchySnapshot(parent: null, subtasks: List.of(_children))
        : TaskHierarchySnapshot(parent: _parent, subtasks: const []),
  );

  @override
  Future<void> createSubtask({
    required String taskListId,
    required String parentTaskId,
    required String title,
  }) async {
    createdSubtaskTitles.add(title);
    _children.add(
      TaskSubtaskEntity.task(
        TaskEntity(
          accountId: 'account-1',
          taskListId: taskListId,
          id: 'new-child',
          title: title,
          localDirty: true,
          pendingDelete: false,
          pendingMove: false,
          rawJson: '{}',
          updatedLocalAtUtc: _now,
        ),
        hasChildren: false,
      ),
    );
  }
}

const _now = '2026-08-31T00:00:00.000Z';
