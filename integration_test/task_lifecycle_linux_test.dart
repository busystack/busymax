import 'dart:async';
import 'dart:io';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/app/linux/linux_window_host.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_editor.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_scope.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';
import 'package:yaru/yaru.dart';

import '../test/support/memory_settings_store.dart';

// Explicit native acceptance with synthetic providers and an isolated profile.
// Neither the owner's database/keyring nor any live task endpoint is opened.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Linux native task create, identity acknowledgment, dirty Escape and retry',
    (tester) async {
      final root = Platform.environment['BUSYMAX_ACCEPTANCE_ROOT'];
      expect(root, isNotNull);
      expect(Platform.environment['XDG_DATA_HOME'], '$root/data');
      await tester.runAsync(YaruWindowTitleBar.ensureInitialized);
      final database = AppDatabase.memoryForTests();
      final provider = _NativeTaskProvider();
      final repository = _NativeTasksRepository(database, provider);
      final replayer = PendingOpsReplayer(
        database: database,
        apiClient: provider,
        accountId: 'qa',
      );
      await tester.runAsync(() async {
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'qa',
                provider: 'google',
                authority: 'https://accounts.google.com',
                providerAccountId: 'synthetic-native',
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                createdAtUtc: '',
                updatedAtUtc: '',
              ),
            );
        await database.taskListsDao.upsertTaskList(
          TaskListsCompanion.insert(
            accountId: 'qa',
            id: 'inbox',
            title: 'QA Inbox',
            rawJson: '{}',
            createdLocalAtUtc: '',
            updatedLocalAtUtc: '',
          ),
        );
      });
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
          accountsStreamProvider.overrideWith(
            (ref) => Stream.value(const [
              AccountEntity(
                id: 'qa',
                provider: BusyProvider.google,
                authority: 'https://accounts.google.com',
                providerAccountId: 'synthetic-native',
                authState: 'signed_in',
                displayName: 'Synthetic QA',
              ),
            ]),
          ),
          activeAccountProvider.overrideWithValue('qa'),
          localTimeZoneProvider.overrideWithValue('UTC'),
          localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          tasksRepositoryForAccountProvider.overrideWith(
            (ref, id) => repository,
          ),
          taskListsRepositoryForAccountProvider.overrideWith(
            (ref, id) => TaskListsRepository(database: database, accountId: id),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              ...GlobalUbuntuLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: BusyMaxYaruTheme.build(
              brightness: Brightness.light,
              accentColor: YaruColors.orange,
            ),
            builder: (context, child) => LinuxWindowHost(child: child!),
            home: const ScheduleWorkspace(initialScope: ScheduleScope.tasks),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pumpAndSettle();
      final title = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Title',
      );
      final notes = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Notes',
      );
      expect(title, findsOneWidget);
      await tester.enterText(title, 'Native QA task');
      if (notes.evaluate().isEmpty) {
        await tester.tap(find.text('Details'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Created notes');
      await tester.pump();
      await _control(tester, LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      final temporary = (await tester.runAsync(
        () => database.select(database.tasks).getSingle(),
      ))!;
      expect(temporary.id, startsWith('local-task-'));

      provider.createGate = Completer<void>();
      late Future<int> acknowledging;
      await tester.runAsync(() async {
        acknowledging = replayer.replayDueOps();
        await provider.createReceived.future;
      });
      await tester.tap(find.text('Native QA task'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Task'));
      await tester.pumpAndSettle();
      expect(title, findsOneWidget);
      await tester.enterText(title, 'Native edited title');
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Exact draft after acknowledgment');
      await tester.pump();
      await tester.runAsync(() async {
        provider.createGate!.complete();
        await acknowledging;
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(title).controller!.text,
        'Native edited title',
      );
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Exact draft after acknowledgment',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(title).controller!.text,
        'Native edited title',
      );
      repository.failNextPatch = true;
      await _control(tester, LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      expect(find.text('Operation failed'), findsOneWidget);
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Exact draft after acknowledgment',
      );
      await _control(tester, LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      await tester.runAsync(() async {
        final operation = await database
            .select(database.pendingOps)
            .getSingle();
        expect(operation.taskId, 'server-task');
        expect(operation.requestJson, isNot(contains(temporary.id)));
        await replayer.replayDueOps();
        expect(provider.state['title'], 'Native edited title');
        expect(provider.state['notes'], 'Exact draft after acknowledgment');
        expect(await database.select(database.pendingOps).get(), isEmpty);
      });
      // Ctrl+F is owned by the existing workspace and remains reachable after Save.
      await _control(tester, LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final alpha = {
          'id': 'server-alpha',
          'title': 'Alpha sibling',
          'status': 'needsAction',
          'position': '0001',
          'updated': DateTime.now().toUtc().toIso8601String(),
        };
        provider.tasks['server-alpha'] = alpha;
        await database.tasksDao.upsertTask(
          taskFromDto(
            'qa',
            'inbox',
            TaskDto.fromJson(alpha),
            DateTime.now().toUtc().toIso8601String(),
          ),
        );
      });
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Alpha sibling')).dy,
        lessThan(tester.getTopLeft(find.text('Native edited title')).dy),
      );
      await _openTask(tester, 'Native edited title');
      await tester.ensureVisible(notes);
      await tester.tap(notes);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(find.text('Delete "Native edited title"?'), findsNothing);
      await tester.enterText(notes, 'Exact draft after acknowledgment');
      await tester.pump();
      _focusEditor(tester);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(find.text('Delete "Native edited title"?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => database.select(database.pendingOps).get()),
        isEmpty,
      );

      final createChild = find.byKey(const ValueKey('create-subtask-action'));
      await tester.ensureVisible(createChild);
      await tester.tap(createChild);
      await tester.pumpAndSettle();
      expect(find.text('New subtask'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Native child');
      await tester.pump();
      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final child = (await database.tasksDao.listTasks(
          'qa',
          'inbox',
        )).singleWhere((task) => task.title == 'Native child');
        expect(child.parent, 'server-task');
        expect(await replayer.replayDueOps(), 2);
        expect(provider.tasks['server-child']!['parent'], 'server-task');
      });
      await tester.pumpAndSettle();
      final childRow = find.byKey(const ValueKey('subtask-task-server-child'));
      await tester.ensureVisible(childRow);
      await tester.tap(childRow);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(title).controller!.text, 'Native child');
      final moveToTop = find.text('Move to top');
      await tester.ensureVisible(moveToTop);
      await tester.tap(moveToTop);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(await replayer.replayDueOps(), 1);
        expect(provider.tasks['server-child']!['parent'], isNull);
      });
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(
        tester.getTopLeft(find.text('Native child')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha sibling')).dy),
      );
      await _openTask(tester, 'Native child');
      _focusEditor(tester);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(find.text('Delete "Native child"?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(await replayer.replayDueOps(), 1);
        expect(provider.tasks.containsKey('server-child'), isFalse);
        expect(await database.select(database.pendingOps).get(), isEmpty);
      });
      await tester.pumpAndSettle();
      expect(find.text('Native child'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.runAsync(database.close);
    },
    skip: !Platform.isLinux,
  );
}

Future<void> _openTask(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Edit Task'));
  await tester.pumpAndSettle();
}

void _focusEditor(WidgetTester tester) {
  tester
      .widget<Focus>(
        find.descendant(
          of: find.byType(TaskDetailsEditor),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Focus &&
                widget.focusNode?.debugLabel == 'Task editor shortcuts',
          ),
        ),
      )
      .focusNode!
      .requestFocus();
}

Future<void> _control(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

class _NativeTasksRepository extends TasksRepository {
  _NativeTasksRepository(AppDatabase db, TaskRemoteClient provider)
    : super(database: db, accountId: 'qa', apiClient: provider);
  var failNextPatch = false;
  @override
  Future<void> patchTask(String list, String id, TaskPatchInput input) {
    if (failNextPatch) {
      failNextPatch = false;
      return Future.error(StateError('synthetic local failure'));
    }
    return super.patchTask(list, id, input);
  }
}

class _NativeTaskProvider implements TaskRemoteClient {
  final createReceived = Completer<void>();
  Completer<void>? createGate;
  final tasks = <String, Map<String, Object?>>{};
  Map<String, Object?> get state => tasks['server-task']!;
  var _creates = 0;
  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    if (!createReceived.isCompleted) createReceived.complete();
    await createGate?.future;
    final id = ++_creates == 1 ? 'server-task' : 'server-child';
    final task = <String, Object?>{
      'id': id,
      'parent': parentTaskId,
      'position': '0002',
      'updated': DateTime.now().toUtc().toIso8601String(),
      ...create.fields,
    };
    tasks[id] = task;
    return TaskDto.fromJson(task);
  }

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async => TaskDto.fromJson(tasks[taskId]!);
  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    final task = tasks[taskId]!;
    task.addAll(patch.fields);
    task['updated'] = DateTime.now().toUtc().toIso8601String();
    return TaskDto.fromJson(task);
  }

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) async {
    final task = tasks[taskId]!
      ..['parent'] = parentTaskId
      ..['position'] = '0000'
      ..['updated'] = DateTime.now().toUtc().toIso8601String();
    return TaskDto.fromJson(task);
  }

  @override
  Future<void> deleteTask({
    required String taskListId,
    required String taskId,
  }) async {
    tasks.remove(taskId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
