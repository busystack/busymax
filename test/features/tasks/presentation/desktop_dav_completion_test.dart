import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_window_close.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/sync/dav_collection_remote_client.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_scope.dart';
import 'package:busymax/src/ui/windows/windows_task_details_dialog.dart';
import 'package:busymax/src/ui/windows/windows_tasks_page.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../support/dav_task_inventory_fixture.dart';
import '../../../support/memory_settings_store.dart';
import '../../../test_localized_app.dart';

void main() {
  for (final windows in [false, true]) {
    testWidgets(
      '${windows ? 'Windows' : 'Linux'} root and subtask checkboxes use the DAV percentage lifecycle',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = await _Fixture.create();
        addTearDown(fixture.database.close);
        await _mount(tester, fixture, windows: windows);
        await _until(tester, _checkbox('Parent', windows: windows));
        if (windows) {
          await tester.tap(find.widgetWithText(fluent.Checkbox, 'Completed'));
          await tester.pumpAndSettle();
        }

        // The real root row must complete its ordinary child as well.
        await tester.tap(_checkbox('Parent', windows: windows));
        await tester.pumpAndSettle();
        await fixture.expectLocal('completed', percent: 100);
        await fixture.replay(2, 'COMPLETED');
        await tester.pumpAndSettle();
        expect(_checked(tester, 'Parent', windows: windows), isTrue);
        expect(_checked(tester, 'Child', windows: windows), isTrue);

        // Reopening through the actual child row must reopen its ancestor.
        await tester.tap(_checkbox('Child', windows: windows));
        await tester.pumpAndSettle();
        await fixture.expectLocal('needsAction', percent: null);
        await fixture.replay(2, 'NEEDS-ACTION');
        await tester.pumpAndSettle();
        expect(_checked(tester, 'Parent', windows: windows), isFalse);
        expect(_checked(tester, 'Child', windows: windows), isFalse);

        // Explicit status retains the pinned old-state behavior: an open
        // descendant stays open. The subsequent root checkbox must not cancel it.
        await fixture.repository.patchTask(
          fixture.listId,
          fixture.parentId,
          const TaskPatchInput({'taskStatus': 'COMPLETED'}),
        );
        await fixture.replay(1, null);
        await tester.pumpAndSettle();
        // Windows task lists refresh by command; remount against the persisted
        // provider state, as reopening a view would, before the next checkbox.
        await _mount(tester, fixture, windows: windows, generation: 1);
        await _until(tester, _checkbox('Child', windows: windows));
        if (windows) {
          await tester.tap(find.widgetWithText(fluent.Checkbox, 'Completed'));
          await tester.pumpAndSettle();
        }
        expect(_checked(tester, 'Parent', windows: windows), isTrue);
        expect(_checked(tester, 'Child', windows: windows), isFalse);
        await tester.tap(_checkbox('Parent', windows: windows));
        await tester.pumpAndSettle();
        await fixture.expectLocal('needsAction', percent: null);
        await fixture.replay(1, 'NEEDS-ACTION');

        // Cancellation remains an explicit, separate lifecycle operation.
        await fixture.repository.patchTask(
          fixture.listId,
          fixture.parentId,
          const TaskPatchInput({'taskStatus': 'CANCELLED'}),
        );
        await fixture.expectLocal('cancelled', percent: null);
        await fixture.replay(2, 'CANCELLED');
        expect(fixture.remote.puts, 8);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final action in [
    'completed',
    'needsAction',
    'cancelled',
    'inProcess',
    'percent',
  ]) {
    testWidgets('Windows explicit status retains its lifecycle ($action)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      if (action == 'needsAction' ||
          action == 'inProcess' ||
          action == 'percent') {
        await fixture.repository.patchTask(
          fixture.listId,
          fixture.parentId,
          const TaskPatchInput({'taskStatus': 'COMPLETED'}),
        );
        await fixture.replay(1, null);
      }
      await _openDetails(tester, fixture);
      if (action == 'percent') {
        await _expandSecondary(tester);
        final slider = find.byType(fluent.Slider).first;
        await tester.ensureVisible(slider);
        await tester.tapAt(tester.getCenter(slider));
        await tester.pumpAndSettle();
        expect(tester.widget<fluent.Slider>(slider).value, 50);
      } else {
        await _status(tester, switch (action) {
          'completed' => 'Completed',
          'needsAction' => 'Needs action',
          'inProcess' => 'In progress',
          _ => 'Cancelled',
        });
      }
      final save = find.widgetWithText(fluent.FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(fluent.ContentDialog), findsNothing);
      final rows = await fixture.database.select(fixture.database.tasks).get();
      final parent = rows.singleWhere((row) => row.icalUid == 'parent');
      final child = rows.singleWhere((row) => row.icalUid == 'child');
      expect(parent.status, switch (action) {
        'completed' => 'completed',
        'needsAction' => 'needsAction',
        'inProcess' || 'percent' => 'inProcess',
        _ => 'cancelled',
      });
      if (action == 'inProcess') expect(parent.percentComplete, 1);
      if (action == 'percent') expect(parent.percentComplete, 50);
      expect(child.status, switch (action) {
        'completed' => 'completed',
        'cancelled' => 'cancelled',
        _ => 'needsAction',
      });
      final count = action == 'completed' || action == 'cancelled' ? 2 : 1;
      await fixture.replay(count, null);
      for (final resource in fixture.remote.resources.values) {
        final component = IcalSemanticDocument.parse(resource.raw)
            .components
            .single;
        final local = rows.singleWhere((row) => row.icalUid == component.uid);
        expect(component.status ?? 'NEEDS-ACTION', switch (local.status) {
          'completed' => 'COMPLETED',
          'cancelled' => 'CANCELLED',
          'inProcess' => 'IN-PROCESS',
          _ => 'NEEDS-ACTION',
        });
        expect(resource.raw, contains('X-KEEP:opaque'));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Windows details checkbox completes and reopens its root', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);
    for (final completed in [true, false]) {
      await _openDetails(tester, fixture);
      await tester.tap(find.widgetWithText(fluent.Checkbox, 'Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(fluent.FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final rows = await fixture.database.select(fixture.database.tasks).get();
      final parent = rows.singleWhere((row) => row.icalUid == 'parent');
      final child = rows.singleWhere((row) => row.icalUid == 'child');
      expect(parent.status, completed ? 'completed' : 'needsAction');
      expect(parent.percentComplete, completed ? 100 : null);
      expect(child.status, 'completed');
      expect(child.percentComplete, 100);
      await fixture.replay(completed ? 2 : 1, null);
    }
    expect(fixture.remote.puts, 3);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openDetails(WidgetTester tester, _Fixture fixture) async {
  Object? openError;
  final task = await fixture.repository.readTask(
    fixture.listId,
    fixture.parentId,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(fixture.database),
        localTimeZoneProvider.overrideWithValue('UTC'),
        tasksRepositoryForAccountProvider.overrideWith(
          (ref, _) => fixture.repository,
        ),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, _) => TaskListsRepository(
            database: fixture.database,
            accountId: DavTaskInventoryFixture.accountId,
          ),
        ),
        davTaskCollectionCapabilitiesProvider.overrideWith(
          (ref, _) => Stream.value(nextcloudTaskCollectionCapabilities),
        ),
      ],
      child: fluent.FluentApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => fluent.Button(
            onPressed: () async {
              try {
                await showWindowsTaskDetailsDialog(
                  context,
                  ref,
                  TaskScheduleItem(
                    id: task!.id,
                    accountId: task.accountId,
                    sourceId: task.taskListId,
                    provider: BusyProvider.nextcloud,
                    title: task.title,
                    completed: task.status == 'completed',
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
  for (
    var attempt = 0;
    attempt < 50 &&
        find.byType(fluent.ContentDialog).evaluate().isEmpty &&
        openError == null;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(openError, isNull);
  expect(find.byType(fluent.ContentDialog), findsOneWidget);
}

Future<void> _status(WidgetTester tester, String label) async {
  await _expandSecondary(tester);
  final info = find.byWidgetPredicate(
    (widget) =>
        widget is fluent.InfoLabel && widget.label.toPlainText() == 'Status',
  );
  final combo = find.descendant(
    of: info,
    matching: find.byType(fluent.ComboBox<String>),
  );
  await tester.ensureVisible(combo);
  await tester.tap(combo);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _expandSecondary(WidgetTester tester) async {
  final expander = find.byKey(const ValueKey('task-secondary-properties'));
  await tester.ensureVisible(expander);
  final expanderWidget = tester.widget<fluent.Expander>(expander);
  if (!expanderWidget.initiallyExpanded) {
    await tester.tap(find.byWidget(expanderWidget.header));
    await tester.pumpAndSettle();
  }
}

Finder _checkbox(String title, {required bool windows}) => windows
    ? find.byWidgetPredicate(
        (widget) => widget is fluent.Checkbox && widget.semanticLabel == title,
      )
    : find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is BusyMaxActionRow && widget.title == title,
        ),
        matching: find.byType(YaruCheckbox),
      );

bool _checked(WidgetTester tester, String title, {required bool windows}) =>
    windows
    ? tester.widget<fluent.Checkbox>(_checkbox(title, windows: true)).checked!
    : tester.widget<YaruCheckbox>(_checkbox(title, windows: false)).value!;

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
  int generation = 0,
}) async {
  final database = fixture.database;
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey('${windows ? 'windows' : 'linux'}-$generation'),
      overrides: [
        databaseProvider.overrideWithValue(database),
        accountsRepositoryProvider.overrideWithValue(
          AccountsRepository(database: database),
        ),
        activeAccountProvider.overrideWithValue(
          DavTaskInventoryFixture.accountId,
        ),
        localTimeZoneProvider.overrideWithValue('UTC'),
        localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
        scheduleRepositoryProvider.overrideWithValue(
          ScheduleRepository(database),
        ),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, id) => TaskListsRepository(database: database, accountId: id),
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
              home: const WindowsTasksPage(),
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

class _Fixture {
  _Fixture(
    this.database,
    this.repository,
    this.listId,
    this.parentId,
    this.remote,
  );

  final AppDatabase database;
  final TasksRepository repository;
  final String listId;
  final String parentId;
  final _StatefulRemote remote;

  static Future<_Fixture> create() async {
    final database = AppDatabase.memoryForTests();
    final inventory = DavTaskInventoryFixture(database);
    await inventory.seedAccount();
    await inventory.commit(writable: true);
    final collection = await database
        .select(database.davCollections)
        .getSingle();
    final list = await database.select(database.taskLists).getSingle();
    final today = DateTime.now().toUtc();
    final date =
        '${today.year}${today.month.toString().padLeft(2, '0')}'
        '${today.day.toString().padLeft(2, '0')}';
    final objects = [
      for (final child in [false, true])
        DavPreparedObject.parse(
          hrefKey: '${collection.hrefKey}${child ? 'child' : 'parent'}.ics',
          requestUri: Uri.parse(collection.requestUri)
              .resolve('${child ? 'child' : 'parent'}.ics'),
          etag: '"${child ? 'child' : 'parent'}"',
          contentType: 'text/calendar',
          rawIcsBody: [
            'BEGIN:VCALENDAR',
            'VERSION:2.0',
            'PRODID:-//BusyMax checkbox QA//EN',
            'BEGIN:VTODO',
            'UID:${child ? 'child' : 'parent'}',
            'SUMMARY:${child ? 'Child' : 'Parent'}',
            if (child) 'RELATED-TO:parent',
            'DTSTAMP:20261022T120000Z',
            'DUE;VALUE=DATE:$date',
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
        finalCursorValue: 'checkbox-qa',
        baselineGeneration: 1,
        completedAtUtc: today,
        projectionRangeStartUtc: DateTime.utc(today.year),
        projectionRangeEndUtc: DateTime.utc(today.year + 1),
      ),
    );
    final tasks = await database.select(database.tasks).get();
    return _Fixture(
      database,
      TasksRepository(
        database: database,
        accountId: DavTaskInventoryFixture.accountId,
      ),
      list.id,
      tasks.singleWhere((task) => task.icalUid == 'parent').id,
      _StatefulRemote(await database.select(database.davObjects).get()),
    );
  }

  Future<void> expectLocal(String status, {required int? percent}) async {
    final rows = await database.select(database.tasks).get();
    expect(rows, hasLength(2));
    expect(rows.every((row) => row.status == status), isTrue);
    expect(rows.every((row) => row.percentComplete == percent), isTrue);
    final operations = await database.select(database.pendingOps).get();
    expect(operations, isNotEmpty);
    for (final operation in operations) {
      final raw = DavMutationPatch.fromJsonString(operation.mutationPatchJson!)
          .applyTo(operation.baselineRawIcs!, nowUtc: DateTime.now().toUtc());
      expect(raw, contains('X-KEEP:opaque'));
      expect(
        IcalSemanticDocument.parse(raw).components.single.status,
        switch (status) {
          'completed' => 'COMPLETED',
          'cancelled' => 'CANCELLED',
          _ => 'NEEDS-ACTION',
        },
      );
    }
  }

  Future<void> replay(int count, String? expectedStatus) async {
    final summary = await DavPendingOperationsReplayer(
      database: database,
      accountId: DavTaskInventoryFixture.accountId,
      objectRepository: DavObjectRepository(database: database),
      serviceFactory: ({required account, required collection}) async =>
          DavConditionalMutationService(remoteClient: remote),
    ).replayDueOperations();
    expect(summary.appliedCount, count);
    expect(summary.conflictCount, 0);
    expect(await database.select(database.pendingOps).get(), isEmpty);
    if (expectedStatus != null) {
      expect(
        remote.resources.values.every(
          (resource) =>
              IcalSemanticDocument.parse(resource.raw)
                  .components
                  .single
                  .status ==
              expectedStatus,
        ),
        isTrue,
      );
    }
  }
}

class _StatefulRemote implements DavMutationRemoteClient {
  _StatefulRemote(List<DavObject> objects)
    : resources = {
        for (final object in objects)
          object.hrefKey: (raw: object.rawIcsBody, etag: object.etag!),
      };

  final Map<String, ({String raw, String etag})> resources;
  var puts = 0;

  @override
  Future<DavConditionalResponse> conditionalPut({
    required Uri uri,
    required String rawIcs,
    required String correlationId,
    String? ifMatch,
    bool ifNoneMatch = false,
  }) async {
    if (ifNoneMatch || resources[uri.path]?.etag != ifMatch) {
      return const DavConditionalResponse(
        status: DavConditionalStatus.preconditionFailed,
        statusCode: 412,
        etag: null,
      );
    }
    final etag = '"checkbox-${++puts}"';
    resources[uri.path] = (raw: rawIcs, etag: etag);
    return DavConditionalResponse(
      status: DavConditionalStatus.success,
      statusCode: 204,
      etag: etag,
    );
  }

  @override
  Future<DavFetchedMember> fetch({
    required String hrefKey,
    required Uri uri,
    required String correlationId,
  }) async {
    final resource = resources[hrefKey]!;
    return DavFetchedMember.live(
      hrefKey: hrefKey,
      requestUri: uri,
      etag: resource.etag,
      contentType: 'text/calendar',
      rawIcsBody: resource.raw,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
