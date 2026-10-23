import 'dart:convert';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/tasks/presentation/new_task_dialog.dart';
import 'package:busymax/src/features/tasks/presentation/task_details_draft.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/dav_task_inventory_fixture.dart';
import '../../../test_localized_app.dart';

void main() {
  for (final retained in ['location', 'recurrence']) {
    testWidgets(
      'R11 Nextcloud $retained is retained but omitted from Google creation',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final db = AppDatabase.memoryForTests();
        addTearDown(db.close);
        final inventory = DavTaskInventoryFixture(db);
        await inventory.seedAccount();
        await inventory.commit(writable: true);
        final nextcloudList = await db.select(db.taskLists).getSingle();
        const now = '2026-10-22T12:00:00.000Z';
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'google:qa',
                provider: 'google',
                authority: 'https://accounts.google.com',
                providerAccountId: 'qa',
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                displayName: const Value('QA Google'),
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
        await db.taskListsDao.upsertTaskList(
          TaskListsCompanion.insert(
            accountId: 'google:qa',
            id: 'google-list',
            title: 'Google list',
            rawJson: '{}',
            createdLocalAtUtc: now,
            updatedLocalAtUtc: now,
          ),
        );
        final accounts = (await db.select(db.accounts).get())
            .map(AccountEntity.fromRow)
            .toList();
        final google = _RecordingCreationRepository(
          database: db,
          accountId: 'google:qa',
        );
        final lists = <String, _SnapshotLists>{};
        for (final account in accounts) {
          lists[account.id] = _SnapshotLists(
            database: db,
            accountId: account.id,
            snapshot: await TaskListsRepository(
              database: db,
              accountId: account.id,
            ).listTaskLists(),
          );
        }
        NewTaskDraft? result;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              accountsRepositoryProvider.overrideWithValue(
                AccountsRepository(database: db),
              ),
              localTimeZoneProvider.overrideWithValue('UTC'),
              taskListsRepositoryForAccountProvider.overrideWith(
                (ref, id) => lists[id]!,
              ),
              tasksRepositoryForAccountProvider.overrideWith(
                (ref, id) => id == 'google:qa'
                    ? google
                    : TasksRepository(database: db, accountId: id),
              ),
              davTaskCollectionCapabilitiesProvider.overrideWith(
                (ref, _) => Stream.value(nextcloudTaskCollectionCapabilities),
              ),
            ],
            child: localizedTestApp(
              child: Scaffold(
                body: NewTaskEditorPanel(
                  accounts: accounts,
                  initialAccountId: DavTaskInventoryFixture.accountId,
                  initialListId: nextcloudList.id,
                  initialDueUtc: DateTime.utc(2026, 10, 22),
                  categorySuggestionsForAccount: (_) => Stream.value(const []),
                  onSubmitted: (draft) async {
                    expect(draft.accountId, 'google:qa');
                    final id = await google.createTask(
                      draft.taskListId,
                      draft.input,
                    );
                    result = NewTaskDraft(
                      accountId: draft.accountId,
                      taskListId: draft.taskListId,
                      input: draft.input,
                      committedTaskId: id,
                    );
                  },
                  onCancel: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'Title',
        );
        await tester.enterText(title, 'Supported Google task');
        await tester.pump();
        if (retained == 'location') {
          final location = find.byKey(
            const ValueKey('ical-task-location-field'),
          );
          await tester.ensureVisible(location);
          await tester.enterText(location, 'QA place');
          await tester.pumpAndSettle();
        } else {
          final recurrence = find.byKey(const ValueKey('ical-task-recurrence'));
          await tester.ensureVisible(recurrence);
          await tester.tap(recurrence);
          await tester.pumpAndSettle();
          await _choose<RecurrenceFrequency>(
            tester,
            'Repeat',
            RecurrenceFrequency.daily,
          );
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
        }
        await _choose<String>(tester, 'Account', 'google:qa');
        expect(
          find.byKey(const ValueKey('ical-task-location-field')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('ical-task-recurrence')),
          findsNothing,
        );
        await _choose<String>(
          tester,
          'Account',
          DavTaskInventoryFixture.accountId,
        );
        if (retained == 'location') {
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const ValueKey('ical-task-location-field')),
                )
                .controller!
                .text,
            'QA place',
          );
        } else {
          expect(find.text('Daily'), findsOneWidget);
        }
        await _choose<String>(tester, 'Account', 'google:qa');
        final create = find.widgetWithText(ElevatedButton, 'Create');
        expect(tester.widget<ElevatedButton>(create).onPressed, isNotNull);
        await tester.ensureVisible(create);
        await tester.tap(create);
        for (
          var attempt = 0;
          attempt < 100 && result == null && google.failure == null;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(google.received, hasLength(1));
        expect(
          google.failure,
          isNull,
          reason:
              'Google creation must commit after unsupported fields hide; '
              'local task rows: ${(await db.select(db.tasks).get()).length}, '
              'pending operations: ${(await db.select(db.pendingOps).get()).length}',
        );
        expect(google.received.single.locationChange.changed, isFalse);
        expect(result, isNotNull);
        final task = await db.select(db.tasks).getSingle();
        expect(task.accountId, 'google:qa');
        expect(task.taskListId, 'google-list');
        expect(task.title, 'Supported Google task');
        final operation = await db.select(db.pendingOps).getSingle();
        final body = ((jsonDecode(operation.requestJson) as Map)['body'] as Map)
            .cast<String, Object?>();
        expect(body['title'], 'Supported Google task');
        expect(
          body.keys.toSet().difference({'title', 'due', 'notes'}),
          isEmpty,
        );
        expect(body.containsKey('recurrence'), isFalse);
        expect(body.containsKey('location'), isFalse);
        expect(body.containsKey('locationPoint'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('R11 creation recurrence with an unsupported destination is explicitly protected', () {
    final validNextcloud = TaskDetailsDraft.forCreation(
      taskListId: 'nextcloud-list',
      provider: BusyProvider.nextcloud,
      timeZone: 'UTC',
      title: 'Recurring task',
      due: DateTime(2026, 10, 22),
      recurrence: const RecurrenceRule.none().copyWith(
        frequency: RecurrenceFrequency.daily,
      ),
    );
    expect(
      validNextcloud
          .toCreateInput(
            nextcloudTaskCollectionCapabilities,
            localTimeZone: 'UTC',
          )
          .fields
          .containsKey('recurrence'),
      isTrue,
    );
    expect(
      validNextcloud.recurrenceIssueFor(googleTaskCollectionCapabilities),
      TaskRecurrenceIssue.unsupportedDestination,
    );
    expect(
      () => validNextcloud.toCreateInput(
        googleTaskCollectionCapabilities,
        localTimeZone: 'UTC',
      ),
      throwsStateError,
    );
  });
}

Future<void> _choose<T>(WidgetTester tester, String title, T value) async {
  final row = tester.widget<BusyMaxComboRow<T>>(
    find.byWidgetPredicate(
      (widget) => widget is BusyMaxComboRow<T> && widget.title == title,
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
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    if (call.method == 'dismiss') return true;
    expect(call.method, 'show');
    final entries = (call.arguments as Map)['entries'] as List;
    final index = entries.indexWhere(
      (entry) => (entry as Map)['label'] == row.labelFor(value),
    );
    expect(index, isNonNegative);
    return index;
  });
  try {
    await tester.tap(selected);
    await tester.pumpAndSettle();
  } finally {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  }
}

class _RecordingCreationRepository extends TasksRepository {
  _RecordingCreationRepository({
    required super.database,
    required super.accountId,
  });
  final received = <TaskCreateInput>[];
  Object? failure;

  @override
  Future<String> createTask(String taskListId, TaskCreateInput input) async {
    received.add(input);
    try {
      return await super.createTask(taskListId, input);
    } on Object catch (error) {
      failure = error;
      rethrow;
    }
  }
}

class _SnapshotLists extends TaskListsRepository {
  _SnapshotLists({
    required super.database,
    required super.accountId,
    required this.snapshot,
  });

  final List<TaskListEntity> snapshot;

  @override
  Stream<List<TaskListEntity>> watchTaskLists() => Stream.value(snapshot);
}
