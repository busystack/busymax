import 'dart:async';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_window_close.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_scope.dart';
import 'package:busymax/src/ui/common/schedule/schedule_interactions.dart';
import 'package:busymax/src/ui/windows/windows_schedule_day_week_view.dart';
import 'package:busymax/src/ui/windows/windows_schedule_page.dart';
import 'package:busymax/src/ui/windows/windows_tasks_page.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../support/dav_task_inventory_fixture.dart';
import '../../../support/memory_settings_store.dart';
import '../../../support/stateful_task_dav_remote.dart';
import '../../../test_localized_app.dart';

void main() {
  for (final windows in [false, true]) {
    for (final count in [3, 1, null]) {
      testWidgets(
        'R02 ${windows ? 'Windows Tasks' : 'Linux agenda'} settles ${count == null ? 'ordinary' : 'COUNT=$count'} completion',
        (tester) async {
          final fixture = await _Fixture.create(count: count);
          addTearDown(fixture.database.close);
          await _mount(tester, fixture, windows: windows);
          final checkbox = _checkbox(fixture, windows: windows);
          await _until(tester, checkbox);
          if (windows) {
            await tester.tap(find.widgetWithText(fluent.Checkbox, 'Completed'));
            await tester.pumpAndSettle();
          }
          final staleAction = _action(tester, checkbox, windows: windows);
          await tester.tap(checkbox);
          await tester.pumpAndSettle();
          await _expectOccurrence(fixture, count: count, completions: 1);
          expect(_checked(tester, checkbox, windows: windows), count != 3);
          if (count == 3) {
            // A callback retained from the old open row cannot act on D+1.
            final pendingBefore =
                (await fixture.database
                        .select(fixture.database.pendingOps)
                        .get())
                    .map((op) => op.toJson())
                    .toList();
            final rowsBefore =
                (await fixture.database.select(fixture.database.tasks).get())
                    .map((task) => task.toJson())
                    .toList();
            staleAction(true);
            await tester.pumpAndSettle();
            await _expectOccurrence(fixture, count: count, completions: 1);
            expect(
              (await fixture.database.select(fixture.database.pendingOps).get())
                  .map((op) => op.toJson())
                  .toList(),
              pendingBefore,
            );
            expect(
              (await fixture.database.select(fixture.database.tasks).get())
                  .map((task) => task.toJson())
                  .toList(),
              rowsBefore,
            );
            expect(_checked(tester, checkbox, windows: windows), isFalse);
            // Let the existing Fluent error feedback dismiss after the rejected
            // stale action; it owns a three-second presentation timer.
            if (windows) {
              await tester.pump(const Duration(seconds: 4));
              await tester.pumpAndSettle();
            }
            await tester.tap(checkbox);
            await tester.pumpAndSettle();
            await _expectOccurrence(fixture, count: count, completions: 2);
            expect(_checked(tester, checkbox, windows: windows), isFalse);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'R02 ${windows ? 'Windows Tasks' : 'Linux agenda'} blocks a second in-flight occurrence action',
      (tester) async {
        final fixture = await _Fixture.create(count: 3);
        addTearDown(fixture.database.close);
        fixture.repository.blockNext = true;
        await _mount(tester, fixture, windows: windows);
        final checkbox = _checkbox(fixture, windows: windows);
        await _until(tester, checkbox);
        final action = _action(tester, checkbox, windows: windows);
        action(true);
        await tester.pump();
        expect(fixture.repository.entered.isCompleted, isTrue);
        action(true);
        await tester.pump();
        expect(fixture.repository.calls, 1);
        fixture.repository.release.complete();
        await tester.pumpAndSettle();
        await _expectOccurrence(fixture, count: 3, completions: 1);
        expect(_checked(tester, checkbox, windows: windows), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final mode in ['day', 'week']) {
    testWidgets(
      'R04 Windows $mode planner checkbox uses DAV percentage hierarchy',
      (tester) async {
        final fixture = await _Fixture.create(hierarchy: true);
        addTearDown(fixture.database.close);
        await _mount(tester, fixture, windows: true, plannerMode: mode);
        await _until(tester, find.byType(WindowsScheduleDayWeekView));
        Finder checkbox(String title) => find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(ScheduleEventInteraction),
          ),
          matching: find.byType(fluent.Checkbox),
        );
        await _until(tester, checkbox('Parent'));
        await tester.tap(checkbox('Parent'));
        await tester.pumpAndSettle();
        await fixture.expectHierarchy('completed', 'completed');
        await fixture.replay();
        await tester.tap(checkbox('Parent'));
        await tester.pumpAndSettle();
        await fixture.expectHierarchy('needsAction', 'completed');
        await fixture.replay();
        // Reset both using the already approved percentage completion lifecycle.
        await fixture.repository.patchTask(
          fixture.listId,
          fixture.parentId,
          TaskPatchInput.completion(true),
        );
        await _mount(
          tester,
          fixture,
          windows: true,
          plannerMode: mode,
          generation: 1,
        );
        await _until(tester, checkbox('Child'));
        await tester.tap(checkbox('Child'));
        await tester.pumpAndSettle();
        await fixture.expectHierarchy('needsAction', 'needsAction');
        await fixture.replay();
        final fresh = ScheduleRepository(fixture.database);
        final reloaded = await fresh.listAllTasks();
        expect(
          reloaded
              .where((task) => task.id == fixture.parentId)
              .single
              .completed,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    testWidgets(
      'R04 Windows planner retains ${provider.name} checkbox payload',
      (tester) async {
        final fixture = await _Fixture.cloud(provider);
        addTearDown(fixture.database.close);
        await _mount(tester, fixture, windows: true, plannerMode: 'day');
        final checkbox = find.descendant(
          of: find.ancestor(
            of: find.text('Parent'),
            matching: find.byType(ScheduleEventInteraction),
          ),
          matching: find.byType(fluent.Checkbox),
        );
        await _until(tester, checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        final op = await fixture.database
            .select(fixture.database.pendingOps)
            .getSingle();
        final input = fixture.repository.lastInput!;
        expect(input.fields.keys.toSet(), {'status', 'completed'});
        expect(input.fields['status'], 'completed');
        expect(
          DateTime.tryParse(input.fields['completed'] as String),
          isNotNull,
        );
        expect(op.operation, 'patch_task');
        expect(
          (await fixture.repository.readTask(
            fixture.listId,
            fixture.parentId,
          ))!.status,
          'completed',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'D02 Windows planner completion failure retains row and reports failure',
    (tester) async {
      final fixture = await _Fixture.create(hierarchy: true);
      addTearDown(fixture.database.close);
      fixture.repository.failNext = StateError('Synthetic precommit failure');
      await _mount(tester, fixture, windows: true, plannerMode: 'day');
      final checkbox = find.descendant(
        of: find.ancestor(
          of: find.text('Parent'),
          matching: find.byType(ScheduleEventInteraction),
        ),
        matching: find.byType(fluent.Checkbox),
      );
      await _until(tester, checkbox);
      final before =
          (await fixture.database.select(fixture.database.tasks).get())
              .map((task) => task.toJson())
              .toList();
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(fluent.InfoBar, 'Operation failed'),
        findsOneWidget,
      );
      expect(
        (await fixture.database.select(fixture.database.tasks).get())
            .map((task) => task.toJson())
            .toList(),
        before,
      );
      expect(
        await fixture.database.select(fixture.database.pendingOps).get(),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      await fixture.expectHierarchy('completed', 'completed');
      expect(
        await fixture.database.select(fixture.database.pendingOps).get(),
        hasLength(2),
      );
    },
  );
}

Finder _checkbox(_Fixture fixture, {required bool windows}) => find.descendant(
  of: find.byKey(
    windows
        ? ValueKey((
            'mutation-cell',
            '${DavTaskInventoryFixture.accountId}\u0000${fixture.listId}\u0000${fixture.parentId}',
          ))
        : ValueKey(
            'agenda-mutation-${DavTaskInventoryFixture.accountId}\u0000${fixture.listId}\u0000${fixture.parentId}',
          ),
  ),
  matching: find.byType(windows ? fluent.Checkbox : YaruCheckbox),
);

bool _checked(WidgetTester tester, Finder checkbox, {required bool windows}) =>
    windows
    ? tester.widget<fluent.Checkbox>(checkbox).checked!
    : tester.widget<YaruCheckbox>(checkbox).value!;

ValueChanged<bool?> _action(
  WidgetTester tester,
  Finder checkbox, {
  required bool windows,
}) => windows
    ? tester.widget<fluent.Checkbox>(checkbox).onChanged!
    : tester.widget<YaruCheckbox>(checkbox).onChanged!;

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsOneWidget);
  await tester.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester tester,
  _Fixture fixture, {
  required bool windows,
  String? plannerMode,
  int generation = 0,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey('completion-$generation'),
      overrides: [
        databaseProvider.overrideWithValue(fixture.database),
        accountsRepositoryProvider.overrideWithValue(
          AccountsRepository(database: fixture.database),
        ),
        activeAccountProvider.overrideWithValue(
          DavTaskInventoryFixture.accountId,
        ),
        localTimeZoneProvider.overrideWithValue('UTC'),
        localSettingsStoreProvider.overrideWithValue(
          MemorySettingsStore({'scheduleViewMode': plannerMode ?? 'agenda'}),
        ),
        scheduleRepositoryProvider.overrideWithValue(
          ScheduleRepository(fixture.database),
        ),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, id) =>
              TaskListsRepository(database: fixture.database, accountId: id),
        ),
        tasksRepositoryForAccountProvider.overrideWith(
          (ref, _) => fixture.repository,
        ),
        davTaskCollectionCapabilitiesProvider.overrideWith(
          (ref, _) => Stream.value(nextcloudTaskCollectionCapabilities),
        ),
      ],
      child: windows
          ? fluent.FluentApp(
              localizationsDelegates: const [AppLocalizations.delegate],
              supportedLocales: AppLocalizations.supportedLocales,
              home: plannerMode == null
                  ? const WindowsTasksPage()
                  : const WindowsSchedulePage(),
            )
          : localizedTestApp(
              child: BusyMaxWindowCloseScope(
                coordinator: BusyMaxWindowCloseCoordinator(),
                child: const ScheduleWorkspace(
                  initialScope: ScheduleScope.tasks,
                ),
              ),
            ),
    ),
  );
}

Future<void> _expectOccurrence(
  _Fixture fixture, {
  required int? count,
  required int completions,
}) async {
  final raw = await fixture.editable('parent');
  final components = IcalSemanticDocument.parse(raw).components;
  final master = components.singleWhere(
    (component) => component.recurrenceId == null,
  );
  final advanced = count != null && count > 1;
  expect(
    components.where((component) => component.recurrenceId != null),
    hasLength(count == null ? 0 : completions),
  );
  expect(
    master.recurrenceRules,
    count == null
        ? isEmpty
        : ['FREQ=DAILY;COUNT=${count - (advanced ? completions : 0)}'],
  );
  expect(
    master.due!.rawValue,
    _date(fixture.day.add(Duration(days: advanced ? completions : 0))),
  );
  final current = (await fixture.repository.readTask(
    fixture.listId,
    fixture.parentId,
  ))!;
  expect(current.status, advanced ? 'needsAction' : 'completed');
  expect(
    master.taskUiState,
    advanced ? IcalTaskUiState.open : IcalTaskUiState.completed,
  );
  expect(raw, contains('X-KEEP:opaque'));
}

String _date(DateTime date) =>
    '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

class _Fixture {
  _Fixture(
    this.database,
    this.repository,
    this.listId,
    this.parentId,
    this.day,
  );
  final AppDatabase database;
  final _GatedRepository repository;
  final String listId;
  final String parentId;
  final DateTime day;
  StatefulTaskDavRemote? _remote;

  static Future<_Fixture> cloud(BusyProvider provider) async {
    final database = AppDatabase.memoryForTests();
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: DavTaskInventoryFixture.accountId,
            provider: provider.storageValue,
            authority: 'https://qa.example.invalid',
            providerAccountId: 'qa',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            createdAtUtc: '',
            updatedAtUtc: '',
          ),
        );
    await database.taskListsDao.upsertTaskList(
      TaskListsCompanion.insert(
        accountId: DavTaskInventoryFixture.accountId,
        id: 'cloud-list',
        title: 'Cloud list',
        rawJson: '{}',
        createdLocalAtUtc: '',
        updatedLocalAtUtc: '',
      ),
    );
    final day = DateUtils.dateOnly(DateTime.now());
    await database.tasksDao.upsertTask(
      TasksCompanion.insert(
        accountId: DavTaskInventoryFixture.accountId,
        taskListId: 'cloud-list',
        id: 'parent',
        title: 'Parent',
        status: const Value('needsAction'),
        dueUtc: Value(day.toUtc().toIso8601String()),
        rawJson: '{}',
        createdLocalAtUtc: '',
        updatedLocalAtUtc: '',
      ),
    );
    return _Fixture(
      database,
      _GatedRepository(database),
      'cloud-list',
      'parent',
      day,
    );
  }

  static Future<_Fixture> create({int? count, bool hierarchy = false}) async {
    final database = AppDatabase.memoryForTests();
    final inventory = DavTaskInventoryFixture(database);
    await inventory.seedAccount();
    await inventory.commit(writable: true);
    final collection = await database
        .select(database.davCollections)
        .getSingle();
    final list = await database.select(database.taskLists).getSingle();
    final day = DateUtils.dateOnly(DateTime.now())
        .add(Duration(days: hierarchy ? 0 : 1));
    final objects = [
      for (final child in [false, if (hierarchy) true])
        DavPreparedObject.parse(
          hrefKey: '${collection.hrefKey}${child ? 'child' : 'parent'}.ics',
          requestUri: Uri.parse(collection.requestUri)
              .resolve('${child ? 'child' : 'parent'}.ics'),
          etag: '"baseline"',
          contentType: 'text/calendar',
          rawIcsBody: [
            'BEGIN:VCALENDAR',
            'VERSION:2.0',
            'PRODID:-//BusyMax completion QA//EN',
            'BEGIN:VTODO',
            'UID:${child ? 'child' : 'parent'}',
            'SUMMARY:${child ? 'Child' : 'Parent'}',
            if (child) 'RELATED-TO:parent',
            'DTSTAMP:20261022T120000Z',
            'DUE;VALUE=DATE:${_date(day)}',
            if (count != null) 'RRULE:FREQ=DAILY;COUNT=$count',
            'STATUS:NEEDS-ACTION',
            'PERCENT-COMPLETE:0',
            'X-KEEP:opaque',
            'END:VTODO',
            'END:VCALENDAR',
            '',
          ].join('\r\n'),
        ),
    ];
    await DavObjectRepository(database: database).commit(
      DavCollectionCommit(
        accountId: DavTaskInventoryFixture.accountId,
        collectionId: collection.id,
        provider: BusyProvider.nextcloud,
        objects: objects,
        deletedHrefKeys: const {},
        completeMembership: true,
        membershipHrefKeys: objects.map((object) => object.hrefKey).toSet(),
        finalCursorKind: 'dav_sync_token',
        finalCursorValue: 'fixture',
        baselineGeneration: 1,
        completedAtUtc: DateTime.now().toUtc(),
        projectionRangeStartUtc: DateTime.utc(day.year),
        projectionRangeEndUtc: DateTime.utc(day.year + 1),
      ),
    );
    final parent = (await database.select(database.tasks).get()).singleWhere(
      (task) => task.icalUid == 'parent',
    );
    final fixture = _Fixture(
      database,
      _GatedRepository(database),
      list.id,
      parent.id,
      day,
    );
    fixture._remote = StatefulTaskDavRemote(
      await database.select(database.davObjects).get(),
    );
    return fixture;
  }

  Future<String> editable(String uid) async {
    final task = (await database.select(database.tasks).get()).singleWhere(
      (task) => task.icalUid == uid && task.recurrenceIdKey == null,
    );
    return DavPendingOperationQueue(database: database).editableRawIcsForObject(
      accountId: task.accountId,
      collectionId: task.davCollectionId!,
      objectId: task.davObjectId!,
    );
  }

  Future<void> expectHierarchy(String parent, String child) async {
    final tasks = await database.select(database.tasks).get();
    expect(
      tasks.singleWhere((task) => task.icalUid == 'parent').status,
      parent,
    );
    expect(tasks.singleWhere((task) => task.icalUid == 'child').status, child);
    for (final (uid, status) in [('parent', parent), ('child', child)]) {
      expect(
        IcalSemanticDocument.parse(await editable(uid))
            .components
            .single
            .status,
        status == 'completed' ? 'COMPLETED' : 'NEEDS-ACTION',
      );
    }
  }

  Future<void> replay() async {
    final summary = await DavPendingOperationsReplayer(
      database: database,
      accountId: DavTaskInventoryFixture.accountId,
      objectRepository: DavObjectRepository(database: database),
      serviceFactory: ({required account, required collection}) async =>
          DavConditionalMutationService(remoteClient: _remote!),
    ).replayDueOperations();
    expect(summary.appliedCount, greaterThan(0));
    expect(summary.conflictCount, 0);
    expect(await database.select(database.pendingOps).get(), isEmpty);
    for (final resource in _remote!.resources.values) {
      final component = IcalSemanticDocument.parse(resource.raw)
          .components
          .single;
      final current = (await database.select(database.tasks).get()).singleWhere(
        (task) => task.icalUid == component.uid,
      );
      expect(
        current.status,
        component.taskUiState == IcalTaskUiState.completed
            ? 'completed'
            : 'needsAction',
      );
    }
  }
}

class _GatedRepository extends TasksRepository {
  _GatedRepository(AppDatabase database)
    : super(database: database, accountId: DavTaskInventoryFixture.accountId);
  bool blockNext = false;
  Object? failNext;
  var calls = 0;
  TaskPatchInput? lastInput;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> patchTask(
    String taskListId,
    String taskId,
    TaskPatchInput input,
  ) async {
    calls++;
    lastInput = input;
    if (failNext case final error?) {
      failNext = null;
      throw error;
    }
    if (blockNext) {
      blockNext = false;
      entered.complete();
      await release.future;
    }
    return super.patchTask(taskListId, taskId, input);
  }
}
