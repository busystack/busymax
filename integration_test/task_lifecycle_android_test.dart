// Run only on an explicitly designated disposable Android emulator with
// --dart-define=BUSYMAX_TASK_NATIVE_QA=true. The host sends real Back/input
// events at the receipt barriers and force-stops/relaunches the QA package.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_background.dart';
import 'package:busymax/src/android/presentation/android_tasks_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _account = 'google:task-native-qa';
const _list = 'task-native-qa-list';
const _parent = 'task-native-qa-parent';
String get _recoveryKey =>
    'busymax.android.task-draft.v2.'
    '${base64Url.encode(utf8.encode(jsonEncode([_account, _list, _parent])))}';
const _notes = 'Native retained notes L2';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('installed Android task lifecycle across process recreation', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    expect(const bool.fromEnvironment('BUSYMAX_TASK_NATIVE_QA'), isTrue);
    final support = await getApplicationSupportDirectory();
    final evidence = Directory('${support.path}/task-lifecycle-qa');
    await evidence.create(recursive: true);
    final phaseFile = File('${evidence.path}/phase');
    final phase = await phaseFile.exists()
        ? (await phaseFile.readAsString()).trim()
        : 'prepare';
    final diagnostics = <String, Object?>{};
    late _NativeTaskRepository repository;
    final runtime = await AndroidHeadlessRuntime.create(
      overridesForTesting: (database) => [
        allAccountsSyncRunnerProvider.overrideWithValue(() async {}),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, accountId) =>
              TaskListsRepository(database: database, accountId: accountId),
        ),
        tasksRepositoryForAccountProvider.overrideWith(
          (ref, accountId) => repository = _NativeTaskRepository(
            database: database,
            accountId: accountId,
          ),
        ),
      ],
    );
    try {
      await _seed(runtime.database);
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
      await _waitFor(tester, find.widgetWithText(ListTile, 'Native parent'));
      await tester.pumpAndSettle();
      final storage = runtime.container.read(secureStorageProvider);
      if (phase == 'verify-final') {
        final row = (await runtime.database.tasksDao.listTasks(
          _account,
          _list,
        )).singleWhere((row) => row.id == _parent);
        expect(row.notes, _notes);
        expect(row.status, 'needsAction');
        expect(row.dueUtc, isNotNull);
        expect(await storage.read(key: _recoveryKey), isNull);
        expect(
          await runtime.database.select(runtime.database.pendingOps).get(),
          hasLength(4),
        );
        await _receipt(evidence, 'final-restarted', {'phase': phase});
        return;
      }
      await tester.tap(find.widgetWithText(ListTile, 'Native parent'));
      await _waitFor(tester, find.byType(AndroidTaskEditor));
      await tester.pumpAndSettle();
      if (phase == 'prepare') {
        // A previous failed QA assertion may leave a genuine recovery record.
        // Restore it through the product UI instead of clearing draft data.
        await _waitUntil(
          tester,
          () =>
              find.text('Restore').evaluate().isNotEmpty ||
              tester
                      .widget<TextButton>(
                        find.widgetWithText(TextButton, 'Save'),
                      )
                      .onPressed !=
                  null,
        );
        if (find.text('Restore').evaluate().isNotEmpty) {
          await tester.tap(find.text('Restore'));
          await tester.pumpAndSettle();
        }
        await _waitWritable(tester);
        await _nativeTextInput(
          tester,
          evidence,
          name: 'initial-notes',
          field: find.widgetWithText(TextField, 'Notes'),
          text: 'Native retained notes L1',
        );
        await _waitForRecovery(
          tester,
          () => storage.read(key: _recoveryKey),
          notes: 'Native retained notes L1',
        );
        final child = find.widgetWithText(ListTile, 'Native child');
        await _scrollTo(tester, child);
        await tester.tap(child);
        await tester.pumpAndSettle();
        final parent = find.byWidgetPredicate(
          (widget) =>
              widget is ListTile &&
              widget.title is Text &&
              (widget.title! as Text).data == 'Native parent',
        );
        await _scrollTo(tester, parent);
        await tester.tap(parent);
        await tester.pumpAndSettle();
        expect(
          find.byType(AndroidTaskEditor, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Restore'), findsNothing);
        await _top(tester);
        await _waitWritable(tester);
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
              .controller!
              .text,
          'Native retained notes L1',
        );
        await _nativeTextInput(
          tester,
          evidence,
          name: 'notes-input',
          field: find.widgetWithText(TextField, 'Notes'),
          text: _notes,
        );
        diagnostics['notesImmediatelyAfterNativeInput'] = tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .controller!
            .text;
        diagnostics['saveEnabledAfterNativeInput'] =
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
                .onPressed !=
            null;
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
              .controller!
              .text,
          _notes,
        );
        await _waitForRecovery(
          tester,
          () => storage.read(key: _recoveryKey),
          notes: _notes,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 500));
        await _receipt(evidence, 'awaiting-back', {});
        await _waitFor(tester, find.widgetWithText(TextButton, 'Cancel'));
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(find.text(_notes), findsOneWidget);
        expect(
          await runtime.database.select(runtime.database.pendingOps).get(),
          isEmpty,
        );
        await phaseFile.writeAsString('restore', flush: true);
        await _receipt(evidence, 'prepared', {
          'recoveryNotes': (jsonDecode(
            (await storage.read(key: _recoveryKey))!,
          ) as Map)['notes'],
          'editorOwners': find
              .byType(AndroidTaskEditor, skipOffstage: false)
              .evaluate()
              .length,
        });
        // The host intentionally force-stops this process after the durable
        // receipt. This phase must not be reported as a completed test run.
        for (var second = 0; second < 120; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        fail('The host did not force-stop the prepared QA process.');
      }
      expect(phase, 'restore');
      await _waitFor(tester, find.text('Restore'));
      expect(find.text('Restore'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      await _waitWritable(tester);
      expect(find.text(_notes), findsOneWidget);
      final title = find.widgetWithText(TextField, 'Title');
      await _nativeTextInput(
        tester,
        evidence,
        name: 'title-clear',
        field: title,
        text: '',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(title).decoration!.errorText, isNotEmpty);
      expect(find.text(_notes), findsOneWidget);
      expect(
        await runtime.database.select(runtime.database.pendingOps).get(),
        isEmpty,
      );
      await _nativeTextInput(
        tester,
        evidence,
        name: 'title-correction',
        field: title,
        text: 'Native parent',
      );
      repository.armFailure();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await _waitUntil(tester, () => repository.received!.isCompleted);
      expect(repository.submitted!['notes'], _notes);
      await tester.pump();
      expect(tester.widget<TextField>(title).enabled, isFalse);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .enabled,
        isFalse,
      );
      await tester.tap(title);
      await _receipt(evidence, 'awaiting-busy-input', {});
      await _waitUntil(
        tester,
        () => File('${evidence.path}/busy-input-done').existsSync(),
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .controller!
            .text,
        _notes,
      );
      expect(tester.widget<TextField>(title).controller!.text, 'Native parent');
      repository.release!.complete();
      await _waitFor(
        tester,
        find.textContaining('Native QA persistence failure'),
      );
      await tester.pumpAndSettle();
      await _waitWritable(tester);
      expect(
        find.textContaining('Native QA persistence failure'),
        findsOneWidget,
      );
      expect(find.text(_notes), findsOneWidget);
      expect(
        await runtime.database.select(runtime.database.pendingOps).get(),
        isEmpty,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      await _waitUntil(
        tester,
        () => find.byType(AndroidTaskEditor).evaluate().isEmpty,
      );
      expect(await storage.read(key: _recoveryKey), isNull);
      expect(
        await runtime.database.select(runtime.database.pendingOps).get(),
        hasLength(1),
      );
      final row = (await runtime.database.tasksDao.listTasks(
        _account,
        _list,
      )).singleWhere((row) => row.id == _parent);
      expect(row.notes, _notes);
      expect(repository.calls, 2);
      await tester.tap(find.widgetWithText(ListTile, 'Native parent'));
      await _waitFor(tester, find.byType(AndroidTaskEditor));
      await tester.pumpAndSettle();
      await _waitWritable(tester);
      final due = find.widgetWithText(ListTile, 'Due date');
      await _scrollTo(tester, due);
      await tester.tap(due);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final now = DateTime.now();
      final selectedDay = now.day < 28 ? now.day + 1 : now.day - 1;
      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.text('$selectedDay'),
            )
            .last,
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      await _waitUntil(
        tester,
        () => find.byType(AndroidTaskEditor).evaluate().isEmpty,
      );
      for (final completed in [true, false]) {
        final tile = find.widgetWithText(ListTile, 'Native parent');
        await tester.tap(
          find.descendant(of: tile, matching: find.byType(IconButton)).first,
        );
        await tester.pumpAndSettle();
        final status = completed ? 'completed' : 'needsAction';
        var observedStatus = '';
        for (var attempt = 0; attempt < 240; attempt++) {
          observedStatus = (await runtime.database.tasksDao.listTasks(
            _account,
            _list,
          )).singleWhere((row) => row.id == _parent).status!;
          if (observedStatus == status) break;
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(observedStatus, status);
        await tester.pumpAndSettle();
      }
      expect(
        await runtime.database.select(runtime.database.pendingOps).get(),
        hasLength(4),
      );
      await phaseFile.writeAsString('verify-final', flush: true);
      await _receipt(evidence, 'restored-and-saved', {
        'notes': row.notes,
        'repositoryCalls': repository.calls,
        'pendingOperations': 4,
      });
    } on Object catch (error, stack) {
      final notesField = find.widgetWithText(TextField, 'Notes');
      if (notesField.evaluate().isNotEmpty) {
        diagnostics['notesEnabledAtFailure'] = tester
            .widget<TextField>(notesField)
            .enabled;
        diagnostics['notesAtFailure'] = tester
            .widget<TextField>(notesField)
            .controller!
            .text;
        final save = find.widgetWithText(TextButton, 'Save');
        final canSubmit = tester.widget<TextButton>(save).onPressed != null;
        diagnostics['saveEnabledAtFailure'] = canSubmit;
        if (phase == 'prepare' &&
            diagnostics['notesAtFailure'] == _notes &&
            canSubmit) {
          // Diagnose a real model/storage mismatch without committing work.
          repository.armFailure();
          await tester.tap(save);
          await _waitUntil(tester, () => repository.received!.isCompleted);
          diagnostics['submittedAfterStorageFailure'] = repository.submitted;
          repository.release!.complete();
          await tester.pumpAndSettle();
        }
      }
      await _receipt(evidence, 'failure', {
        'phase': phase,
        'error': '$error',
        'stack': '$stack',
        ...diagnostics,
      });
      rethrow;
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await runtime.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _seed(AppDatabase database) async {
  final accounts = await database.select(database.accounts).get();
  if (accounts.isNotEmpty) {
    expect(accounts.map((account) => account.id), [_account]);
    return;
  }
  const stamp = '2026-08-01T00:00:00Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: _account,
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'task-native-qa',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          displayName: const Value('Synthetic task QA'),
          createdAtUtc: stamp,
          updatedAtUtc: stamp,
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: _account,
      id: _list,
      title: 'Native QA list',
      rawJson: '{}',
      createdLocalAtUtc: stamp,
      updatedLocalAtUtc: stamp,
    ),
  );
  for (final child in [false, true]) {
    final id = child ? 'task-native-qa-child' : _parent;
    final title = child ? 'Native child' : 'Native parent';
    await database.tasksDao.upsertTask(
      TasksCompanion.insert(
        accountId: _account,
        taskListId: _list,
        id: id,
        title: title,
        parent: Value(child ? _parent : null),
        status: const Value('needsAction'),
        rawJson: jsonEncode({
          'id': id,
          'title': title,
          'status': 'needsAction',
        }),
        createdLocalAtUtc: stamp,
        updatedLocalAtUtc: stamp,
      ),
    );
  }
}

Future<void> _receipt(
  Directory directory,
  String name,
  Map<String, Object?> values,
) =>
    File('${directory.path}/$name.json')
        .writeAsString(jsonEncode({'pid': pid, ...values}), flush: true)
        .then((_) {});

Future<void> _waitUntil(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 240 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(ready(), isTrue);
}

Future<void> _waitFor(WidgetTester tester, Finder finder) =>
    _waitUntil(tester, () => finder.evaluate().isNotEmpty);

Future<void> _nativeTextInput(
  WidgetTester tester,
  Directory evidence, {
  required String name,
  required Finder field,
  required String text,
}) async {
  final marker = File('${evidence.path}/$name-done');
  if (await marker.exists()) await marker.delete();
  expect(tester.widget<TextField>(field).enabled, isTrue);
  await tester.tap(field);
  await tester.pumpAndSettle();
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  // Selection preparation changes no draft content. All text changes below
  // arrive through real Android key events from the private QA controller.
  tester
      .state<EditableTextState>(editable)
      .selectAll(SelectionChangedCause.toolbar);
  await tester.pumpAndSettle();
  final controller = tester.widget<TextField>(field).controller!;
  expect(controller.selection.start, 0);
  expect(controller.selection.end, controller.text.length);
  await _receipt(evidence, 'awaiting-$name', {
    'expectedText': text,
    'selectedCharacters': controller.selection.end,
  });
  await _waitUntil(tester, marker.existsSync);
  await _waitUntil(tester, () => controller.text == text);
  expect(controller.text, text);
}

Future<void> _waitForRecovery(
  WidgetTester tester,
  Future<String?> Function() read, {
  required String notes,
}) async {
  String? recoveredNotes;
  for (var attempt = 0; attempt < 240; attempt++) {
    final raw = await read();
    recoveredNotes = raw == null ? null : (jsonDecode(raw) as Map)['notes'];
    if (recoveredNotes == notes) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(recoveredNotes, notes);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -450));
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _top(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  final list = find.byType(ListView).last;
  for (var attempt = 0; attempt < 30; attempt++) {
    final position = tester.widget<ListView>(list).controller!.position;
    if (position.pixels <= 0) break;
    await tester.drag(list, const Offset(0, 500));
    await tester.pumpAndSettle();
  }
  await tester.pumpAndSettle();
  expect(tester.widget<ListView>(list).controller!.position.pixels, 0);
}

Future<void> _waitWritable(WidgetTester tester) => _waitUntil(
  tester,
  () =>
      tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
              .onPressed !=
          null &&
      tester
              .widget<TextField>(find.widgetWithText(TextField, 'Title'))
              .enabled ==
          true &&
      tester
              .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
              .enabled ==
          true,
);

class _NativeTaskRepository extends TasksRepository {
  _NativeTaskRepository({required super.database, required super.accountId});
  Completer<void>? received;
  Completer<void>? release;
  Map<String, Object?>? submitted;
  var calls = 0;

  void armFailure() {
    received = Completer<void>();
    release = Completer<void>();
  }

  @override
  Future<void> patchTask(
    String taskListId,
    String taskId,
    TaskPatchInput input,
  ) async {
    calls++;
    final barrier = release;
    if (barrier != null) {
      submitted = Map.of(input.fields);
      received!.complete();
      await barrier.future;
      release = null;
      throw StateError('Native QA persistence failure');
    }
    await super.patchTask(taskListId, taskId, input);
  }
}
