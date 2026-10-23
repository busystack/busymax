import 'dart:async';
import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/tasks/presentation/desktop_date_time_fields.dart';
import 'package:busymax/src/features/tasks/presentation/new_task_dialog.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_editor.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  for (final invalid in ['url', 'dates']) {
    for (final keyboard in [false, true]) {
      testWidgets(
        'R11 hidden $invalid survives account switching and permits Google ${keyboard ? 'Ctrl+S' : 'Create'}',
        (tester) async {
          final fixture = await _open(
            tester,
            dialog: true,
            secondAccount: true,
            nextcloudFirst: true,
          );
          fixture.lists.emit(fixture.destinations);
          await tester.pumpAndSettle();
          await _typeDraft(tester);
          if (invalid == 'url') {
            final url = find.byKey(const ValueKey('ical-task-url'));
            await tester.ensureVisible(url);
            await tester.enterText(url, 'invalid URL retained  ');
          } else {
            final rows = tester.widgetList<DesktopDateValueRow>(
              find.byType(DesktopDateValueRow),
            );
            rows
                .singleWhere((row) => row.label == 'Start date')
                .onChanged('2026-08-14');
            await tester.pump();
            tester
                .widgetList<DesktopDateValueRow>(
                  find.byType(DesktopDateValueRow),
                )
                .singleWhere((row) => row.label == 'Due date')
                .onChanged('2026-08-12');
          }
          await tester.pumpAndSettle();
          expect(_create(tester).onPressed, isNull);
          await _choose(tester, 'Account', _otherAccountId, settle: false);
          fixture.otherLists!.emit(fixture.otherDestinations!);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('ical-task-url')), findsNothing);
          expect(_create(tester).onPressed, isNotNull);
          // Returning to the provider exposes the preserved invalid content.
          await _choose(tester, 'Account', _accountId, settle: false);
          fixture.lists.emit(fixture.destinations);
          await tester.pumpAndSettle();
          expect(_create(tester).onPressed, isNull);
          if (invalid == 'url') {
            expect(
              tester
                  .widget<TextField>(
                    find.byKey(const ValueKey('ical-task-url')),
                  )
                  .controller!
                  .text,
              'invalid URL retained  ',
            );
          } else {
            final rows = tester.widgetList<DesktopDateValueRow>(
              find.byType(DesktopDateValueRow),
            );
            expect(
              rows.singleWhere((row) => row.label == 'Start date').date,
              '2026-08-14',
            );
            expect(
              rows.singleWhere((row) => row.label == 'Due date').date,
              '2026-08-12',
            );
          }
          await _choose(tester, 'Account', _otherAccountId, settle: false);
          fixture.otherLists!.emit(fixture.otherDestinations!);
          await tester.pumpAndSettle();
          if (keyboard) {
            await tester.tap(_field('Title'));
            await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
            await tester.pumpAndSettle();
          } else {
            await _submit(tester);
          }
          await _expectOneDurableTask(
            fixture,
            accountId: _otherAccountId,
            taskListId: 'other-destination',
          );
          final operation = await fixture.database
              .select(fixture.database.pendingOps)
              .getSingle();
          final body =
              (jsonDecode(operation.requestJson) as Map)['body'] as Map;
          expect(body.keys, isNot(contains('taskUrl')));
          expect(body.keys, isNot(contains('startDateTime')));
          expect(body.keys, isNot(contains('microsoftStartDateTime')));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'new task distinguishes initial list loading from a confirmed empty list',
    (tester) async {
      final fixture = await _open(tester);
      final l10n = _l10n(tester);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(l10n.noTaskListsSynced), findsNothing);
      expect(find.text(l10n.collectionsLoadFailed), findsNothing);
      expect(find.byType(TaskDetailsEditor), findsOneWidget);
      await _typeDraft(tester);
      expect(_create(tester).onPressed, isNull);
      fixture.lists.emit(const []);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(l10n.noTaskListsSynced), findsOneWidget);
      expect(find.text(l10n.collectionsLoadFailed), findsNothing);
      expect(_text(tester, 'Title'), _title);
      expect(_text(tester, 'Notes'), _notes);
      expect(_create(tester).onPressed, isNull);
      expect(
        await fixture.database.select(fixture.database.tasks).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.pendingOps).get(),
        isEmpty,
      );
    },
  );

  testWidgets(
    'initial task-list error preserves the creation draft and Retry enables its destination',
    (tester) async {
      final fixture = await _open(tester);
      final l10n = _l10n(tester);
      await _typeDraft(tester);
      final editor = tester.state(find.byType(TaskDetailsEditor));
      fixture.lists.fail();
      await tester.pumpAndSettle();
      expect(find.text(l10n.collectionsLoadFailed), findsOneWidget);
      expect(find.text(l10n.noTaskListsSynced), findsNothing);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(tester.state(find.byType(TaskDetailsEditor)), same(editor));
      expect(_text(tester, 'Title'), _title);
      expect(_text(tester, 'Notes'), _notes);
      expect(_create(tester).onPressed, isNull);
      fixture.lists.prepareRetry();
      await tester.tap(find.text(l10n.retry));
      await tester.pump();
      fixture.lists.emit(fixture.destinations);
      await tester.pumpAndSettle();
      expect(find.text(l10n.collectionsLoadFailed), findsNothing);
      expect(find.text(l10n.noTaskListsSynced), findsNothing);
      expect(_text(tester, 'Title'), _title);
      expect(_text(tester, 'Notes'), _notes);
      expect(_list(tester).selected, 'destination');
      expect(_create(tester).onPressed, isNotNull);
      await _submit(tester);
      await _expectOneDurableTask(fixture);
    },
  );

  testWidgets(
    'later list error and Retry retain the cached destination and exact dirty draft through dialog Save',
    (tester) async {
      final fixture = await _open(tester, dialog: true);
      final l10n = _l10n(tester);
      fixture.lists.emit(fixture.destinations);
      await tester.pumpAndSettle();
      await _typeDraft(tester);
      final editor = tester.state(find.byType(TaskDetailsEditor));
      expect(_list(tester).selected, 'destination');
      fixture.lists.fail();
      await tester.pumpAndSettle();
      expect(find.text(l10n.collectionsLoadFailed), findsOneWidget);
      expect(find.text(l10n.noTaskListsSynced), findsNothing);
      expect(tester.state(find.byType(TaskDetailsEditor)), same(editor));
      expect(_text(tester, 'Title'), _title);
      expect(_text(tester, 'Notes'), _notes);
      expect(_list(tester).selected, 'destination');
      expect(_create(tester).onPressed, isNotNull);
      fixture.lists.prepareRetry();
      await tester.tap(find.text(l10n.retry));
      await tester.pump();
      expect(_text(tester, 'Title'), _title);
      expect(_text(tester, 'Notes'), _notes);
      expect(_list(tester).selected, 'destination');
      fixture.lists.emit(fixture.destinations.reversed.toList());
      await tester.pumpAndSettle();
      expect(find.text(l10n.collectionsLoadFailed), findsNothing);
      expect(_list(tester).selected, 'destination');
      expect(_text(tester, 'Title'), _title);
      expect(_text(tester, 'Notes'), _notes);
      await _submit(tester);
      await _expectOneDurableTask(fixture);
      expect(find.byType(NewTaskEditorPanel), findsNothing);
      expect(fixture.result?.accountId, _accountId);
      expect(fixture.result?.taskListId, 'destination');
      expect(fixture.result?.committedTaskId, isNotNull);
      expect(
        fixture.result?.committedTaskId,
        (await fixture.database.select(fixture.database.tasks).getSingle()).id,
      );
    },
  );
  testWidgets(
    'changing creation list and account preserves dirty fields, Escape guard and durable ownership',
    (tester) async {
      final fixture = await _open(tester, dialog: true, secondAccount: true);
      fixture.lists.emit(fixture.destinations);
      await tester.pumpAndSettle();
      await _typeDraft(tester);
      await _choose(tester, 'List', 'inbox');
      expect(_text(tester, 'Title'), _title);
      expect(_text(tester, 'Notes'), _notes);
      expect(_list(tester).selected, 'inbox');
      expect(_create(tester).onPressed, isNotNull);
      await _choose(tester, 'Account', _otherAccountId, settle: false);
      expect(
        tester
            .widget<BusyMaxComboRow<String>>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is BusyMaxComboRow<String> &&
                    widget.title == 'Account',
              ),
            )
            .selected,
        _otherAccountId,
      );
      expect(_text(tester, 'Title'), _title);
      expect(_text(tester, 'Notes'), _notes);
      expect(_create(tester).onPressed, isNull);
      fixture.otherLists!.emit(fixture.otherDestinations!);
      await tester.pumpAndSettle();
      await _choose(tester, 'List', 'other-destination');
      expect(_text(tester, 'Title'), _title);
      expect(_text(tester, 'Notes'), _notes);
      expect(_list(tester).selected, 'other-destination');
      expect(_create(tester).onPressed, isNotNull);
      await tester.tap(_field('Title'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(BusyMaxConfirmDialog), findsOneWidget);
      final cancel = find.descendant(
        of: find.byType(BusyMaxConfirmDialog),
        matching: find.text('Cancel'),
      );
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(NewTaskEditorPanel), findsOneWidget);
      expect(_text(tester, 'Title'), _title);
      expect(_text(tester, 'Notes'), _notes);
      expect(_list(tester).selected, 'other-destination');
      await _submit(tester);
      await _expectOneDurableTask(
        fixture,
        accountId: _otherAccountId,
        taskListId: 'other-destination',
      );
      expect(fixture.result?.accountId, _otherAccountId);
      expect(fixture.result?.taskListId, 'other-destination');
    },
  );
}

Future<_Fixture> _open(
  WidgetTester tester, {
  bool dialog = false,
  bool secondAccount = false,
  bool nextcloudFirst = false,
}) async {
  tester.view
    ..physicalSize = const Size(1200, 1100)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final database = AppDatabase.memoryForTests();
  addTearDown(database.close);
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: _accountId,
          provider: nextcloudFirst ? 'nextcloud' : 'google',
          authority: nextcloudFirst
              ? 'https://dav.example.invalid'
              : 'https://accounts.google.com',
          providerAccountId: 'qa',
          credentialKind: nextcloudFirst ? 'nextcloud_app_password' : 'oauth',
          authState: const Value('signed_in'),
          createdAtUtc: '',
          updatedAtUtc: '',
        ),
      );
  for (final (id, title) in [
    ('inbox', 'Inbox'),
    ('destination', 'Selected destination'),
  ]) {
    await database.taskListsDao.upsertTaskList(
      TaskListsCompanion.insert(
        accountId: _accountId,
        id: id,
        title: title,
        rawJson: '{}',
        createdLocalAtUtc: '',
        updatedLocalAtUtc: '',
      ),
    );
  }
  final lists = _ControlledLists(database);
  addTearDown(lists.dispose);
  _ControlledLists? otherLists;
  List<TaskListEntity>? otherDestinations;
  if (secondAccount) {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: _otherAccountId,
            provider: 'google',
            authority: 'https://accounts.google.com',
            providerAccountId: 'other-qa',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: '',
            updatedAtUtc: '',
          ),
        );
    for (final (id, title) in [
      ('other-inbox', 'Other inbox'),
      ('other-destination', 'Other destination'),
    ]) {
      await database.taskListsDao.upsertTaskList(
        TaskListsCompanion.insert(
          accountId: _otherAccountId,
          id: id,
          title: title,
          rawJson: '{}',
          createdLocalAtUtc: '',
          updatedLocalAtUtc: '',
        ),
      );
    }
    otherLists = _ControlledLists(database, accountId: _otherAccountId);
    addTearDown(otherLists.dispose);
    otherDestinations = await TaskListsRepository(
      database: database,
      accountId: _otherAccountId,
    ).listTaskLists();
  }
  final repository = TasksRepository(
    database: database,
    accountId: _accountId,
    nowUtc: () => DateTime.utc(2026, 8, 8),
  );
  final fixture = _Fixture(
    database,
    lists,
    await TaskListsRepository(
      database: database,
      accountId: _accountId,
    ).listTaskLists(),
  );
  fixture
    ..otherLists = otherLists
    ..otherDestinations = otherDestinations;
  final accounts = [
    nextcloudFirst ? _davAccount : _account,
    if (secondAccount) _otherAccount,
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        localTimeZoneProvider.overrideWithValue('UTC'),
        davTaskCollectionCapabilitiesProvider.overrideWith(
          (ref, _) => Stream.value(nextcloudTaskCollectionCapabilities),
        ),
        tasksRepositoryForAccountProvider.overrideWith((ref, accountId) {
          expect(accounts.map((account) => account.id), contains(accountId));
          return accountId == _accountId
              ? repository
              : TasksRepository(
                  database: database,
                  accountId: accountId,
                  nowUtc: () => DateTime.utc(2026, 8, 8),
                );
        }),
        taskListsRepositoryForAccountProvider.overrideWith((ref, accountId) {
          expect(accounts.map((account) => account.id), contains(accountId));
          return accountId == _accountId ? lists : otherLists!;
        }),
      ],
      child: localizedTestApp(
        child: Scaffold(
          body: dialog
              ? Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () async =>
                        fixture.result = await showBusyMaxNewTaskDialog(
                          context,
                          ref: ref,
                          accounts: accounts,
                          initialAccountId: _accountId,
                          initialListId: 'destination',
                        ),
                    child: const Text('Open new task'),
                  ),
                )
              : NewTaskEditorPanel(
                  accounts: accounts,
                  initialAccountId: _accountId,
                  initialListId: 'destination',
                  categorySuggestionsForAccount: (_) => Stream.value(const []),
                  onSubmitted: (draft) async {
                    await repository.createTask(draft.taskListId, draft.input);
                  },
                  onCancel: () {},
                ),
        ),
      ),
    ),
  );
  if (dialog) await tester.tap(find.text('Open new task'));
  await tester.pump();
  return fixture;
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);
String _text(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;
ElevatedButton _create(WidgetTester tester) => tester.widget<ElevatedButton>(
  find.widgetWithText(ElevatedButton, 'Create'),
);
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(NewTaskEditorPanel)));
BusyMaxComboRow<String> _list(WidgetTester tester) =>
    tester.widget<BusyMaxComboRow<String>>(
      find.byWidgetPredicate(
        (widget) => widget is BusyMaxComboRow<String> && widget.title == 'List',
      ),
    );

Future<void> _typeDraft(WidgetTester tester) async {
  await tester.enterText(_field('Title'), _title);
  await tester.ensureVisible(_field('Notes'));
  await tester.enterText(_field('Notes'), _notes);
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
}

Future<void> _choose(
  WidgetTester tester,
  String title,
  String value, {
  bool settle = true,
}) async {
  final row = tester.widget<BusyMaxComboRow<String>>(
    find.byWidgetPredicate(
      (widget) => widget is BusyMaxComboRow<String> && widget.title == title,
    ),
  );
  final selected = find
      .descendant(
        of: find.byWidget(row),
        matching: find.text(row.labelFor(row.selected)),
      )
      .last;
  await tester.ensureVisible(selected);
  const channel = MethodChannel(nativeMenuChannelName);
  var presentations = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    if (call.method == 'dismiss') return true;
    expect(call.method, 'show');
    presentations += 1;
    final entries = (call.arguments as Map)['entries'] as List;
    final index = entries.indexWhere(
      (entry) => (entry as Map)['label'] == row.labelFor(value),
    );
    expect(index, isNonNegative);
    return index;
  });
  try {
    await tester.tap(selected);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(presentations, 1);
  } finally {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  }
}

Future<void> _expectOneDurableTask(
  _Fixture fixture, {
  String accountId = _accountId,
  String taskListId = 'destination',
}) async {
  final task = await fixture.database
      .select(fixture.database.tasks)
      .getSingle();
  final operation = await fixture.database
      .select(fixture.database.pendingOps)
      .getSingle();
  expect(task.accountId, accountId);
  expect(task.taskListId, taskListId);
  expect(task.title, _title.trim());
  expect(task.notes, _notes);
  expect(task.localCreated, isTrue);
  expect(task.localDirty, isTrue);
  expect(operation.operation, 'create_task');
  expect(operation.accountId, accountId);
  expect(operation.taskListId, taskListId);
  expect(operation.taskId, task.id);
  final body = (jsonDecode(operation.requestJson) as Map)['body'] as Map;
  expect(body['title'], _title.trim());
  expect(body['notes'], _notes);
}

class _Fixture {
  _Fixture(this.database, this.lists, this.destinations);
  final AppDatabase database;
  final _ControlledLists lists;
  final List<TaskListEntity> destinations;
  _ControlledLists? otherLists;
  List<TaskListEntity>? otherDestinations;
  NewTaskDraft? result;
}

class _ControlledLists extends TaskListsRepository {
  _ControlledLists(AppDatabase database, {super.accountId = _accountId})
    : super(database: database);
  final _controllers = <StreamController<List<TaskListEntity>>>[
    StreamController.broadcast(sync: true),
  ];
  var watchCalls = 0;
  @override
  Stream<List<TaskListEntity>> watchTaskLists() {
    watchCalls += 1;
    return _controllers.last.stream;
  }

  void emit(List<TaskListEntity> lists) => _controllers.last.add(lists);
  void fail() => _controllers.last.addError(
    StateError('Synthetic task-list read failure'),
  );
  void prepareRetry() =>
      _controllers.add(StreamController.broadcast(sync: true));
  Future<void> dispose() async {
    for (final controller in _controllers) {
      await controller.close();
    }
  }
}

const _accountId = 'google:creation-qa';
const _otherAccountId = 'google:other-creation-qa';
const _title = '  Retained draft title  ';
const _notes = 'Local notes\nsecond line with spaces  ';
const _account = AccountEntity(
  id: _accountId,
  provider: BusyProvider.google,
  authority: 'https://accounts.google.com',
  providerAccountId: 'qa',
  authState: 'signed_in',
  displayName: 'QA primary',
);
const _davAccount = AccountEntity(
  id: _accountId,
  provider: BusyProvider.nextcloud,
  authority: 'https://dav.example.invalid',
  providerAccountId: 'dav-qa',
  authState: 'signed_in',
  displayName: 'QA Nextcloud',
);
const _otherAccount = AccountEntity(
  id: _otherAccountId,
  provider: BusyProvider.google,
  authority: 'https://accounts.google.com',
  providerAccountId: 'other-qa',
  authState: 'signed_in',
  displayName: 'QA second',
);
