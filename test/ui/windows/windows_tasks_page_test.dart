import 'package:busymax/src/providers/busy_provider.dart';
import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/ui/windows/windows_tasks_page.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'signed-out and authenticated empty Tasks have different messages',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      await _mount(tester, db);
      await _until(tester, find.text('Sign in to view tasks.'));
      await _account(db, 'personal');
      await _until(tester, find.text('No tasks yet'));
      expect(find.text('Sign in to view tasks.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'background writes refresh open Tasks; inline completion and filtering persist',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      await _account(db, 'personal');
      await _mount(tester, db);
      await _until(tester, find.text('No tasks yet'));
      await _task(db, 'parent', 'Parent task');
      await _task(db, 'child', 'Child task', parent: 'parent');
      await _until(tester, find.text('Child task'));
      final parent = find.widgetWithText(ListTile, 'Parent task').first;
      final child = find.widgetWithText(ListTile, 'Child task');
      expect(
        tester.getTopLeft(child).dx,
        greaterThan(tester.getTopLeft(parent).dx),
      );
      await (db.update(db.tasks)..where((row) => row.id.equals('child'))).write(
        const TasksCompanion(title: Value('Synced title')),
      );
      await _until(tester, find.text('Synced title'));
      final complete = find.byWidgetPredicate(
        (w) => w is Checkbox && w.semanticLabel == 'Synced title',
      );
      await tester.tap(complete);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('Synced title'), findsNothing);
      final saved = await (db.select(
        db.tasks,
      )..where((row) => row.id.equals('child'))).getSingle();
      expect(saved.status, 'completed');
      expect(find.byType(ContentDialog), findsNothing);
      await tester.tap(find.widgetWithText(Checkbox, 'Completed'));
      await _until(tester, find.text('Synced title'));
      expect(tester.widget<Checkbox>(complete).checked, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'account-qualified list scope uses full identity and creation keeps that list',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      await _account(db, 'personal');
      await _account(db, 'work');
      await _task(db, 'one', 'Personal task');
      await _task(db, 'two', 'Work task', account: 'work');
      await _mount(tester, db);
      await _until(tester, find.text('Work task'));
      final listFilter = find.byType(ComboBox<ScheduleTaskListKey>);
      await tester.tap(listFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google · work@example.test · Tasks').last);
      await tester.pumpAndSettle();
      expect(find.text('Personal task'), findsNothing);
      expect(find.text('Work task'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('New task'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await _until(tester, find.byType(ComboBox<TaskListEntity>));
      final selected = tester
          .widget<ComboBox<TaskListEntity>>(
            find.byType(ComboBox<TaskListEntity>),
          )
          .value!;
      expect(selected.accountId, 'work');
      expect(selected.id, 'list');
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'search is debounced, retains rows while refreshing, and distinguishes no results',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      await _account(db, 'personal');
      await _task(db, 'one', 'Existing task');
      final repository = _ControlledRepository(db);
      await _mount(tester, db, repository: repository);
      await _until(tester, find.text('Existing task'));
      final initialLoads = repository.loads;
      repository.pending = Completer<List<TaskScheduleItem>>();
      await tester.enterText(find.byType(TextBox), 'x');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextBox), 'xyz');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.loads, initialLoads);
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.loads, initialLoads + 1);
      expect(find.text('Existing task'), findsOneWidget);
      repository.pending!.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No matching events or tasks'), findsOneWidget);
      expect(find.text('Sign in to view tasks.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'initial loading resolves to a task whose read-only completion is disabled',
    (tester) async {
      final db = AppDatabase.memoryForTests();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
      await _account(db, 'personal');
      final repository = _ControlledRepository(db)
        ..pending = Completer<List<TaskScheduleItem>>();
      await _mount(tester, db, repository: repository);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(ProgressRing), findsOneWidget);
      repository.pending!.complete(const [
        TaskScheduleItem(
          id: 'locked',
          accountId: 'personal',
          sourceId: 'list',
          provider: BusyProvider.google,
          title: 'Shared read-only task',
          completed: false,
          allDay: true,
          capabilities: ScheduleItemCapabilities.readOnly,
        ),
      ]);
      await _until(tester, find.text('Shared read-only task'));
      final control = tester.widget<Checkbox>(
        find.byWidgetPredicate(
          (w) => w is Checkbox && w.semanticLabel == 'Shared read-only task',
        ),
      );
      expect(control.onChanged, isNull);
      expect(await db.select(db.pendingOps).get(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('load failure exposes retry and recovers', (tester) async {
    final db = AppDatabase.memoryForTests();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
    await _account(db, 'personal');
    final repository = _ControlledRepository(db)..fail = true;
    await _mount(tester, db, repository: repository);
    await _until(tester, find.text('Retry'));
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await _until(tester, find.text('No tasks yet'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final removeAccount in [false, true]) {
    testWidgets(
      'removing the selected ${removeAccount ? 'account' : 'list'} reconciles scope',
      (tester) async {
        final db = AppDatabase.memoryForTests();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await db.close();
        });
        await _account(db, 'personal');
        await _account(db, 'work');
        await _task(db, 'one', 'Personal task');
        await _task(db, 'two', 'Work task', account: 'work');
        final repository = _ControlledRepository(db);
        await _mount(tester, db, repository: repository);
        await _until(tester, find.text('Work task'));
        if (removeAccount) {
          await tester.tap(find.byType(ComboBox<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Google · work@example.test').last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byType(ComboBox<ScheduleTaskListKey>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Google · work@example.test · Tasks').last);
        await tester.pumpAndSettle();
        expect(find.text('Personal task'), findsNothing);

        if (removeAccount) {
          await (db.delete(
            db.accounts,
          )..where((row) => row.id.equals('work'))).go();
        } else {
          await (db.delete(
            db.taskLists,
          )..where((row) => row.accountId.equals('work'))).go();
        }
        await _until(tester, find.text('Personal task'));
        expect(
          tester.widget<ComboBox<String>>(find.byType(ComboBox<String>)).value,
          isNull,
        );
        expect(
          tester
              .widget<ComboBox<ScheduleTaskListKey>>(
                find.byType(ComboBox<ScheduleTaskListKey>),
              )
              .value,
          isNull,
        );
        expect(repository.lastFilters!.accountIds, isEmpty);
        expect(repository.lastFilters!.taskListKeys, isEmpty);
        expect(repository.lastFilters!.taskListFilterActive, isFalse);
      },
    );
  }

  testWidgets('list scope survives a pending refresh', (tester) async {
    final db = AppDatabase.memoryForTests();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
    await _account(db, 'personal');
    await _account(db, 'work');
    await _task(db, 'one', 'Personal task');
    await _task(db, 'two', 'Work task', account: 'work');
    final lists = _ControlledListsRepository(db, 'work');
    final repository = _ControlledRepository(db);
    await _mount(tester, db, repository: repository, listsRepository: lists);
    await _until(tester, find.text('Work task'));
    await tester.tap(find.byType(ComboBox<ScheduleTaskListKey>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google · work@example.test · Tasks').last);
    await tester.pumpAndSettle();
    lists.pending = Completer<List<TaskListEntity>>();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WindowsTasksPage)),
    );
    container.invalidate(scheduleTaskListsProvider);
    await tester.pump();
    expect(container.read(scheduleTaskListsProvider).isLoading, isTrue);
    expect(
      tester
          .widget<ComboBox<ScheduleTaskListKey>>(
            find.byType(ComboBox<ScheduleTaskListKey>),
          )
          .value
          ?.accountId,
      'work',
    );
    expect(find.text('Personal task'), findsNothing);
    expect(repository.lastFilters!.taskListKeys.single.accountId, 'work');
    lists.pending!.complete(await lists.loadNormally());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ComboBox<ScheduleTaskListKey>>(
            find.byType(ComboBox<ScheduleTaskListKey>),
          )
          .value
          ?.accountId,
      'work',
    );
  });

  testWidgets('Retry reloads a failed list dependency and recovers', (
    tester,
  ) async {
    final db = AppDatabase.memoryForTests();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
    await _account(db, 'personal');
    await _task(db, 'one', 'Existing task');
    final lists = _ControlledListsRepository(db, 'personal')..fail = true;
    await _mount(tester, db, listsRepository: lists);
    await _until(tester, find.text('Retry'));
    final attempts = lists.loads;
    lists.fail = false;
    await tester.tap(find.text('Retry'));
    await _until(tester, find.text('Existing task'));
    expect(lists.loads, greaterThan(attempts));
    expect(find.text('Retry'), findsNothing);
    final filter = tester.widget<ComboBox<ScheduleTaskListKey>>(
      find.byType(ComboBox<ScheduleTaskListKey>),
    );
    expect(
      filter.items!.any((item) => item.value?.accountId == 'personal'),
      isTrue,
    );
  });

  testWidgets('Retry resubscribes to a failed account stream', (tester) async {
    final db = AppDatabase.memoryForTests();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
    await _account(db, 'personal');
    await _task(db, 'one', 'Existing task');
    var fail = true;
    var subscriptions = 0;
    Stream<List<AccountEntity>> loadAccounts() {
      subscriptions++;
      return fail
          ? Stream.error(StateError('accounts unavailable'))
          : AccountsRepository(database: db).watchAccounts();
    }

    await _mount(tester, db, accountsStream: loadAccounts);
    await _until(tester, find.text('Retry'));
    final attempts = subscriptions;
    fail = false;
    await tester.tap(find.text('Retry'));
    await _until(tester, find.text('Existing task'));
    expect(subscriptions, greaterThan(attempts));
    expect(find.text('Retry'), findsNothing);
  });
}

Future<void> _mount(
  WidgetTester tester,
  AppDatabase db, {
  ScheduleRepository? repository,
  _ControlledListsRepository? listsRepository,
  Stream<List<AccountEntity>> Function()? accountsStream,
}) async {
  tester.view.reset();
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (accountsStream != null)
          accountsStreamProvider.overrideWith((ref) => accountsStream()),
        databaseProvider.overrideWithValue(db),
        localTimeZoneProvider.overrideWithValue('UTC'),
        accountsRepositoryProvider.overrideWithValue(
          AccountsRepository(database: db),
        ),
        scheduleRepositoryProvider.overrideWithValue(
          repository ?? ScheduleRepository(db),
        ),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, id) => listsRepository?.accountId == id
              ? listsRepository!
              : TaskListsRepository(database: db, accountId: id),
        ),
        tasksRepositoryForAccountProvider.overrideWith(
          (ref, id) => TasksRepository(database: db, accountId: id),
        ),
      ],
      child: FluentApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WindowsTasksPage(),
      ),
    ),
  );
}

Future<void> _account(AppDatabase db, String id) async {
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: '$id@example.test',
          email: Value('$id@example.test'),
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          createdAtUtc: _now,
          updatedAtUtc: _now,
        ),
      );
  await db.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: id,
      id: 'list',
      title: 'Tasks',
      rawJson: '{}',
      createdLocalAtUtc: _now,
      updatedLocalAtUtc: _now,
    ),
  );
}

Future<void> _task(
  AppDatabase db,
  String id,
  String title, {
  String account = 'personal',
  String? parent,
}) => db.tasksDao.upsertTask(
  TasksCompanion.insert(
    accountId: account,
    taskListId: 'list',
    id: id,
    title: title,
    parent: Value(parent),
    rawJson: '{}',
    createdLocalAtUtc: _now,
    updatedLocalAtUtc: _now,
  ),
);

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsWidgets);
  await tester.pumpAndSettle();
}

class _ControlledRepository extends ScheduleRepository {
  _ControlledRepository(super.database);
  var loads = 0;
  var fail = false;
  Completer<List<TaskScheduleItem>>? pending;
  ScheduleFilters? lastFilters;
  @override
  Future<List<TaskScheduleItem>> listAllTasks({
    ScheduleFilters filters = const ScheduleFilters(),
  }) {
    loads++;
    lastFilters = filters;
    if (fail) return Future.error(StateError('load failed'));
    return pending?.future ?? super.listAllTasks(filters: filters);
  }
}

class _ControlledListsRepository extends TaskListsRepository {
  _ControlledListsRepository(AppDatabase db, this.accountId)
    : super(database: db, accountId: accountId);

  final String accountId;
  var fail = false;
  var loads = 0;
  Completer<List<TaskListEntity>>? pending;

  Future<List<TaskListEntity>> loadNormally() => super.listTaskLists();

  @override
  Future<List<TaskListEntity>> listTaskLists() {
    loads++;
    if (fail) return Future.error(StateError('lists unavailable'));
    return pending?.future ?? loadNormally();
  }
}

const _now = '2026-09-01T12:00:00Z';
