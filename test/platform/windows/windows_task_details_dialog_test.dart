import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/maps/application/external_location_launcher.dart';
import 'package:busymax/src/features/maps/data/location_resolution_repository.dart';
import 'package:busymax/src/features/maps/domain/geographic_point.dart';
import 'package:busymax/src/features/maps/domain/location_result.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/ui/windows/windows_task_details_dialog.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

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

  testWidgets(
    'Fluent read-only task opens a supplemental-only saved point without writes',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'nextcloud:n',
              provider: 'nextcloud',
              authority: 'https://cloud.example.test',
              providerAccountId: 'n',
              credentialKind: 'nextcloud_app_password',
              authState: const Value('signed_in'),
              createdAtUtc: _now,
              updatedAtUtc: _now,
            ),
          );
      await database.taskListsDao.upsertTaskList(
        TaskListsCompanion.insert(
          accountId: 'nextcloud:n',
          id: 'list-1',
          title: 'Tasks',
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
      await database.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: 'nextcloud:n',
          taskListId: 'list-1',
          id: 'task-location',
          title: 'Coordinate-only task',
          taskLocation: const Value(''),
          rawJson: '{}',
          createdLocalAtUtc: _now,
          updatedLocalAtUtc: _now,
        ),
      );
      const identity = LocationItemIdentity(
        kind: LocationItemKind.task,
        accountId: 'nextcloud:n',
        sourceId: 'list-1',
        itemId: 'task-location',
      );
      final point = GeographicPoint(latitude: 0, longitude: -123.12);
      await LocationResolutionRepository(database).apply(
        identity,
        '',
        LocationChange.replace(
          LocationResult(
            label: 'Imported point',
            point: point,
            source: 'ical',
            attribution: 'Imported iCalendar GEO',
          ),
        ),
      );
      expect(
        await LocationResolutionRepository(database).load(identity, ''),
        isNotNull,
      );
      final tasksBefore = await database.select(database.tasks).get();
      final savedTask = TaskEntity.fromRow(tasksBefore.single);
      final resolutionsBefore = await database
          .select(database.locationResolutions)
          .get();
      final pendingBefore = await database.select(database.pendingOps).get();
      final launches = <Uri>[];
      final launcher = ExternalLocationLauncher(
        platform: () => ExternalLocationPlatform.windows,
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          expect(mode, LaunchMode.externalApplication);
          launches.add(uri);
          return true;
        },
      );
      final tasks = _LocationTasksRepository(database, savedTask);
      final lists = TaskListsRepository(
        database: database,
        accountId: 'nextcloud:n',
      );
      Object? openError;
      bool? openResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            accountsRepositoryProvider.overrideWithValue(
              _NextcloudAccountsRepository(database),
            ),
            localTimeZoneProvider.overrideWithValue('Etc/UTC'),
            tasksRepositoryForAccountProvider.overrideWith(
              (ref, accountId) => tasks,
            ),
            taskListsRepositoryForAccountProvider.overrideWith(
              (ref, accountId) => lists,
            ),
            davTaskCollectionCapabilitiesProvider.overrideWith(
              (ref, key) async =>
                  nextcloudTaskCollectionCapabilities.asReadOnly(),
            ),
          ],
          child: FluentApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Button(
                onPressed: () async {
                  try {
                    openResult = await showWindowsTaskDetailsDialog(
                      context,
                      ref,
                      const TaskScheduleItem(
                        id: 'task-location',
                        accountId: 'nextcloud:n',
                        provider: BusyProvider.nextcloud,
                        sourceId: 'list-1',
                        title: 'Coordinate-only task',
                        completed: false,
                        allDay: true,
                      ),
                      externalLocationLauncher: launcher,
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
        var attempt = 0;
        attempt < 20 && find.byType(ContentDialog).evaluate().isEmpty;
        attempt += 1
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(openError, isNull);
      expect(openResult, isNull);
      expect(find.byType(ContentDialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('windows-task-details-location-field')),
        findsOneWidget,
      );
      expect(find.text('Show on map'), findsOneWidget);
      final openButton = find.byKey(
        const ValueKey('windows-task-location-open'),
      );
      await tester.ensureVisible(openButton);
      await tester.pumpAndSettle();
      await tester.tap(openButton);
      await tester.pumpAndSettle();
      expect(launches, hasLength(1));
      expect(launches.single.scheme, 'https');
      expect(launches.single.path, '/maps/search/');
      expect(launches.single.queryParameters['query'], '0.0,-123.12');
      expect(await database.select(database.tasks).get(), tasksBefore);
      expect(
        await database.select(database.locationResolutions).get(),
        resolutionsBefore,
      );
      expect(await database.select(database.pendingOps).get(), pendingBefore);
      await tester.tap(find.widgetWithText(Button, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(openResult, isFalse);
    },
  );
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

class _NextcloudAccountsRepository extends AccountsRepository {
  _NextcloudAccountsRepository(AppDatabase database)
    : super(database: database);

  @override
  Stream<List<AccountEntity>> watchAccounts() => Stream.value(const [
    AccountEntity(
      id: 'nextcloud:n',
      provider: BusyProvider.nextcloud,
      authority: 'https://cloud.example.test',
      providerAccountId: 'n',
      authState: accountAuthStateSignedIn,
    ),
  ]);
}

class _LocationTasksRepository extends TasksRepository {
  _LocationTasksRepository(AppDatabase database, this.task)
    : super(database: database, accountId: 'nextcloud:n');

  final TaskEntity task;

  @override
  Stream<TaskEntity?> watchTask(String taskListId, String taskId) =>
      Stream.value(task);

  @override
  Stream<TaskHierarchySnapshot> watchTaskHierarchy(
    String taskListId,
    String taskId,
  ) => Stream.value(const TaskHierarchySnapshot(parent: null, subtasks: []));
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
