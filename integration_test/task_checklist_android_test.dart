// Run after task_lifecycle_android_test.dart on the same explicitly designated
// disposable QA emulator with --dart-define=BUSYMAX_TASK_NATIVE_QA=true.
// The private host controller supplies native text/Back and process barriers.
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_background.dart';
import 'package:busymax/src/android/presentation/android_tasks_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_checklist_item.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _account = 'microsoft:task-native-qa';
const _list = 'task-native-qa-checklist-list';
const _task = 'task-native-qa-checklist-task';
const _step = 'step-1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('installed Android offline checklist rename and delete', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    expect(const bool.fromEnvironment('BUSYMAX_TASK_NATIVE_QA'), isTrue);
    final support = await getApplicationSupportDirectory();
    final evidence = Directory('${support.path}/task-checklist-qa');
    await evidence.create(recursive: true);
    final phaseFile = File('${evidence.path}/phase');
    final phase = await phaseFile.exists()
        ? (await phaseFile.readAsString()).trim()
        : 'initial';
    final checklistClient = _OfflineChecklistClient();
    final runtime = await AndroidHeadlessRuntime.create(
      overridesForTesting: (database) => [
        allAccountsSyncRunnerProvider.overrideWithValue(() async {}),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, accountId) =>
              TaskListsRepository(database: database, accountId: accountId),
        ),
        tasksRepositoryForAccountProvider.overrideWith(
          (ref, accountId) => TasksRepository(
            database: database,
            accountId: accountId,
            apiClient: accountId == _account ? checklistClient : null,
          ),
        ),
        microsoftTaskLinkedResourcesProvider.overrideWith(
          (ref, key) async => const [],
        ),
        microsoftTaskAttachmentsProvider.overrideWith(
          (ref, key) async => const [],
        ),
      ],
    );
    try {
      await _assertCoreRetained(runtime.database);
      await _seed(runtime.database);
      if (phase == 'verify') {
        expect(await _items(runtime.database), isEmpty);
        await _assertQueued(runtime.database, deleted: true);
        expect(checklistClient.calls, 0);
        await _receipt(evidence, 'checklist-verified', {
          'phase': phase,
          'coreOperations': 4,
          'checklistOperations': 2,
        });
        return;
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: runtime.container,
          child: const AndroidBusyMaxApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Tasks'),
        ),
      );
      await tester.pumpAndSettle();
      final parent = find.widgetWithText(ListTile, 'Native checklist parent');
      await _wait(tester, () => parent.evaluate().isNotEmpty);
      await tester.tap(parent);
      await _wait(
        tester,
        () => find.byType(AndroidTaskEditor).evaluate().isNotEmpty,
      );
      await _wait(
        tester,
        () =>
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
                .onPressed !=
            null,
      );
      if (phase == 'initial') {
        await _action(tester, 'Rename');
        await _nativeText(tester, evidence, 'rename-cancel', 'Cancelled step');
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect((await _items(runtime.database)).single.title, 'Original step');
        expect(await _ops(runtime.database), isEmpty);

        await _action(tester, 'Rename');
        await _nativeText(
          tester,
          evidence,
          'rename-apply',
          'Native renamed step',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await _waitItems(tester, runtime.database, deleted: false);
        await _wait(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
        await _assertQueued(runtime.database, deleted: false);
        await phaseFile.writeAsString('renamed', flush: true);
      } else {
        expect(phase, 'renamed');
      }
      await _action(tester, 'Delete');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      await _assertQueued(runtime.database, deleted: false);
      expect(
        (await _items(runtime.database)).single.title,
        'Native renamed step',
      );

      await _action(tester, 'Delete');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await _waitItems(tester, runtime.database, deleted: true);
      await _assertQueued(runtime.database, deleted: true);
      await _assertCoreRetained(runtime.database);
      expect(checklistClient.calls, 0);
      await phaseFile.writeAsString('verify', flush: true);
      await _receipt(evidence, 'awaiting-checklist-back', {});
      await _wait(
        tester,
        () => find.byType(AndroidTaskEditor).evaluate().isEmpty,
      );
      await _receipt(evidence, 'checklist-mutated', {
        'coreOperations': 4,
        'checklistOperations': 2,
      });
    } on Object catch (error, stack) {
      await _receipt(evidence, 'failure', {
        'phase': phase,
        'error': '$error',
        'stack': '$stack',
      });
      rethrow;
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await runtime.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

// The repository uses this interface to identify native checklist capability.
// This offline acceptance phase must never dispatch a Graph read or mutation.
class _OfflineChecklistClient extends Fake
    implements TaskRemoteClient, TaskChecklistRemoteClient {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('The offline checklist phase attempted a remote call.');
  }
}

Future<void> _assertCoreRetained(AppDatabase database) async {
  final accounts = await database.select(database.accounts).get();
  expect(
    accounts.map((row) => row.id),
    everyElement(isIn({'google:task-native-qa', _account})),
  );
  final parent = (await database.tasksDao.listTasks(
    'google:task-native-qa',
    'task-native-qa-list',
  )).singleWhere((row) => row.id == 'task-native-qa-parent');
  expect(parent.notes, 'Native retained notes L2');
  expect(parent.status, 'needsAction');
  expect(parent.dueUtc, isNotNull);
  final operations = await (database.select(
    database.pendingOps,
  )..where((row) => row.accountId.equals('google:task-native-qa'))).get();
  expect(operations, hasLength(4));
}

Future<void> _seed(AppDatabase database) async {
  if ((await database.select(database.accounts).get()).any(
    (row) => row.id == _account,
  )) {
    return;
  }
  const stamp = '2026-08-01T00:00:00Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: _account,
          provider: 'microsoft',
          authority: 'https://login.microsoftonline.com/common',
          providerAccountId: 'task-native-qa',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          displayName: const Value('Synthetic checklist QA'),
          createdAtUtc: stamp,
          updatedAtUtc: stamp,
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: _account,
      id: _list,
      title: 'Native checklist list',
      rawJson: '{}',
      createdLocalAtUtc: stamp,
      updatedLocalAtUtc: stamp,
    ),
  );
  await database.tasksDao.upsertTask(
    TasksCompanion.insert(
      accountId: _account,
      taskListId: _list,
      id: _task,
      title: 'Native checklist parent',
      status: const Value('notStarted'),
      rawJson: '{}',
      microsoftChecklistItemsJson: Value(
        jsonEncode([
          {'id': _step, 'displayName': 'Original step', 'isChecked': false},
        ]),
      ),
      createdLocalAtUtc: stamp,
      updatedLocalAtUtc: stamp,
    ),
  );
}

Future<List<TaskChecklistItemEntity>> _items(AppDatabase database) async {
  final row = (await database.tasksDao.listTasks(_account, _list)).single;
  return decodeTaskChecklistItems(row.microsoftChecklistItemsJson);
}

Future<List<PendingOp>> _ops(AppDatabase database) => (database.select(
  database.pendingOps,
)..where((row) => row.accountId.equals(_account))).get();

Future<void> _assertQueued(
  AppDatabase database, {
  required bool deleted,
}) async {
  final operations = await _ops(database);
  expect(operations, hasLength(deleted ? 2 : 1));
  final rename = operations.singleWhere(
    (row) => row.operation == 'patch_task_checklist_item',
  );
  final renamePayload = jsonDecode(rename.requestJson) as Map;
  expect(renamePayload['checklistItemId'], _step);
  expect(renamePayload['body'], {'displayName': 'Native renamed step'});
  if (deleted) {
    final remove = operations.singleWhere(
      (row) => row.operation == 'delete_task_checklist_item',
    );
    expect((jsonDecode(remove.requestJson) as Map)['checklistItemId'], _step);
    expect(remove.dependsOnOpId, rename.id);
  }
  expect(operations.every((row) => row.state == 'pending'), isTrue);
}

Future<void> _waitItems(
  WidgetTester tester,
  AppDatabase database, {
  required bool deleted,
}) async {
  for (var attempt = 0; attempt < 240; attempt++) {
    final items = await _items(database);
    if (deleted ? items.isEmpty : items.single.title == 'Native renamed step') {
      return;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail('The local checklist did not reach the requested state.');
}

Future<void> _action(WidgetTester tester, String action) async {
  final button = find.byKey(const ValueKey('android-checklist-actions-step-1'));
  for (var attempt = 0; attempt < 30 && button.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

Future<void> _nativeText(
  WidgetTester tester,
  Directory evidence,
  String name,
  String text,
) async {
  final field = find.byKey(const ValueKey('android-checklist-title'));
  await _wait(tester, () => field.evaluate().isNotEmpty);
  await tester.tap(field);
  await tester.pumpAndSettle();
  tester
      .state<EditableTextState>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .selectAll(SelectionChangedCause.toolbar);
  await tester.pumpAndSettle();
  final controller = tester.widget<TextField>(field).controller!;
  expect(controller.selection.start, 0);
  expect(controller.selection.end, controller.text.length);
  final marker = File('${evidence.path}/$name-done');
  if (await marker.exists()) await marker.delete();
  await _receipt(evidence, 'awaiting-$name', {'expectedText': text});
  await _wait(tester, marker.existsSync);
  await _wait(tester, () => controller.text == text);
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 240 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(ready(), isTrue);
}

Future<void> _receipt(
  Directory directory,
  String name,
  Map<String, Object?> data,
) =>
    File('${directory.path}/$name.json')
        .writeAsString(jsonEncode({'pid': pid, ...data}), flush: true)
        .then((_) {});
