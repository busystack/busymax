import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_window_close.dart';
import 'package:busymax/src/dav/ical/ical_document.dart';
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
import 'package:busymax/src/features/tasks/presentation/task_details_pane.dart';
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
      'R02 ${windows ? 'Windows' : 'Linux'} recurring child result retains the acted occurrence',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = await _Fixture.create(recurringChild: true);
        addTearDown(fixture.database.close);
        final beforeRow =
            (await fixture.database.select(fixture.database.tasks).get())
                .singleWhere((row) => row.icalUid == 'child');
        final before = TaskEntity.fromRow(beforeRow);
        TaskMutationResult? result;
        if (windows) {
          await _openDetails(
            tester,
            fixture,
            onCommitted: (value) => result = value,
          );
        } else {
          await _openLinuxDetails(
            tester,
            fixture,
            onClose: () {},
            onCommitted: (value) => result = value,
          );
        }
        final checkbox = windows
            ? find.byWidgetPredicate(
                (widget) => widget is fluent.Checkbox && widget.content == null,
              )
            : _checkbox('Child', windows: false);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        for (var attempt = 0; attempt < 100 && result == null; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(result, isNotNull);
        expect(result!.taskId, before.id);
        expect(result!.completed, isTrue);
        expect(result!.occurrenceKey, before.occurrenceKey);
        final after = await fixture.repository.readTask(
          fixture.listId,
          before.id,
        );
        expect(after!.status, 'needsAction');
        expect(after.occurrenceKey, isNot(before.occurrenceKey));
        final input =
            (fixture.repository as _RecordingRepository).received.single;
        expect(input.observedOccurrenceKey, before.occurrenceKey);
        await fixture.replay(1, null);
        final resource = fixture.remote.resources.values.singleWhere(
          (resource) => resource.raw.contains('UID:child'),
        );
        expect(
          IcalSemanticDocument.parse(resource.raw).components
              .where((component) => component.recurrenceIdKey != null),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'R02 Windows recurring root Save result retains the acted occurrence',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = await _Fixture.create(recurringParent: true);
      addTearDown(fixture.database.close);
      final before = await fixture.repository.readTask(
        fixture.listId,
        fixture.parentId,
      );
      TaskMutationResult? result;
      await _openDetails(
        tester,
        fixture,
        onCommitted: (value) => result = value,
      );
      await tester.tap(find.widgetWithText(fluent.Checkbox, 'Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(fluent.FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.completed, isTrue);
      expect(result!.occurrenceKey, before!.occurrenceKey);
      final after = await fixture.repository.readTask(
        fixture.listId,
        fixture.parentId,
      );
      expect(after!.status, 'needsAction');
      expect(after.occurrenceKey, isNot(before.occurrenceKey));
      await fixture.replay(2, null);
    },
  );

  for (final completion in [true, false]) {
    testWidgets(
      'R02 Windows stale recurring editor ${completion ? 'completion conflicts' : 'title merges'}',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = await _Fixture.create(recurringParent: true);
        addTearDown(fixture.database.close);
        await _openDetails(tester, fixture);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(fluent.ContentDialog)),
        );
        if (completion) {
          await tester.tap(find.widgetWithText(fluent.Checkbox, 'Completed'));
        } else {
          final title = find.byWidgetPredicate(
            (widget) =>
                widget is fluent.TextBox && widget.controller?.text == 'Parent',
          );
          await tester.enterText(title, 'Independent title');
        }
        await tester.pumpAndSettle();
        await fixture.repository.patchTask(
          fixture.listId,
          fixture.parentId,
          TaskPatchInput.completion(true),
        );
        await fixture.replay(2, null);
        final before = await fixture.repository.readTask(
          fixture.listId,
          fixture.parentId,
        );
        final rawBefore = fixture.remote.resources.values
            .singleWhere((resource) => resource.raw.contains('UID:parent'))
            .raw;
        final historyBefore = IcalSemanticDocument.parse(rawBefore).components
            .where((component) => component.recurrenceIdKey != null)
            .toList();
        expect(historyBefore, hasLength(1));
        final rowsBefore = await fixture.database
            .select(fixture.database.tasks)
            .get();
        await tester.tap(find.widgetWithText(fluent.FilledButton, 'Save'));
        await tester.pumpAndSettle();
        if (completion) {
          expect(find.text(l10n.taskDraftConflict), findsOneWidget);
          expect(find.byType(fluent.ContentDialog), findsOneWidget);
          expect(
            tester
                .widget<fluent.Checkbox>(
                  find.widgetWithText(fluent.Checkbox, 'Completed'),
                )
                .checked,
            isTrue,
          );
          expect(
            await fixture.database.select(fixture.database.tasks).get(),
            rowsBefore,
          );
          expect(
            await fixture.database.select(fixture.database.pendingOps).get(),
            isEmpty,
          );
          expect(fixture.remote.puts, 2);
        } else {
          expect(find.byType(fluent.ContentDialog), findsNothing);
          final after = await fixture.repository.readTask(
            fixture.listId,
            fixture.parentId,
          );
          expect(after!.title, 'Independent title');
          expect(after.microsoftDueDateTime, before!.microsoftDueDateTime);
          expect(after.recurrenceJson, before.recurrenceJson);
          await fixture.replay(1, null);
          final rawAfter = fixture.remote.resources.values
              .singleWhere((resource) => resource.raw.contains('UID:parent'))
              .raw;
          final historyAfter = IcalSemanticDocument.parse(rawAfter).components
              .where((component) => component.recurrenceIdKey != null)
              .toList();
          expect(historyAfter, hasLength(1));
          expect(
            historyAfter.single.semanticHash,
            historyBefore.single.semanticHash,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final windows in [false, true]) {
    for (final initialPercent in windows ? [0, 20] : [20]) {
      for (final concurrent in [
        'cancel',
        'completedTime',
        'notes',
        'unchanged',
      ]) {
        testWidgets(
          'R01 ${windows ? 'Windows checkbox' : 'Linux progress'} $initialPercent protects semantic state ($concurrent)',
          (tester) async {
            tester.view.physicalSize = const Size(1400, 1400);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final fixture = await _Fixture.create();
            addTearDown(fixture.database.close);
            await fixture.projectParent(
              status: initialPercent == 0 ? 'NEEDS-ACTION' : 'IN-PROCESS',
              percent: initialPercent,
              notes: 'Original notes',
            );
            var closed = false;
            if (windows) {
              await _openDetails(tester, fixture);
              final title = find.byWidgetPredicate(
                (widget) =>
                    widget is fluent.TextBox &&
                    widget.controller?.text == 'Parent',
              );
              await tester.enterText(title, 'Retained local title  ');
              await tester.pump();
              await tester.tap(
                find.widgetWithText(fluent.Checkbox, 'Completed'),
              );
            } else {
              await _openLinuxDetails(
                tester,
                fixture,
                onClose: () => closed = true,
              );
              final title = find.byWidgetPredicate(
                (widget) =>
                    widget is TextField &&
                    widget.decoration?.labelText == 'Title',
              );
              await tester.enterText(title, 'Retained local title  ');
              await tester.pump();
              final slider = find.descendant(
                of: find.byKey(const ValueKey('ical-task-progress')),
                matching: find.byType(Slider),
              );
              await tester.ensureVisible(slider);
              await tester.tapAt(tester.getCenter(slider));
              await tester.pumpAndSettle();
              expect(tester.widget<Slider>(slider).value, 50);
            }
            await tester.pumpAndSettle();
            if (concurrent != 'unchanged') {
              await fixture.projectParent(
                status: concurrent == 'cancel'
                    ? 'CANCELLED'
                    : initialPercent == 0
                    ? 'NEEDS-ACTION'
                    : 'IN-PROCESS',
                percent: initialPercent,
                notes: concurrent == 'notes'
                    ? 'Remote notes'
                    : 'Original notes',
                completedAt: concurrent == 'completedTime'
                    ? '20261021T100000Z'
                    : null,
              );
            }
            await tester.pumpAndSettle();
            final rowsBefore =
                (await fixture.database.select(fixture.database.tasks).get())
                    .map((row) => row.toJson())
                    .toList();
            final resourcesBefore =
                (await fixture.database
                        .select(fixture.database.davObjects)
                        .get())
                    .map((row) => row.toJson())
                    .toList();
            final save = windows
                ? find.widgetWithText(fluent.FilledButton, 'Save')
                : find.text('Save');
            final l10n = AppLocalizations.of(
              tester.element(
                windows
                    ? find.byType(fluent.ContentDialog)
                    : find.byType(TaskDetailsPane),
              ),
            );
            await tester.ensureVisible(save);
            if (!windows) {
              final button = find.ancestor(
                of: save,
                matching: find.byType(ElevatedButton),
              );
              expect(
                tester.widget<ElevatedButton>(button).onPressed,
                isNotNull,
              );
            }
            await tester.tap(save);
            for (var attempt = 0; attempt < 100; attempt++) {
              if (closed ||
                  (windows &&
                      find.byType(fluent.ContentDialog).evaluate().isEmpty) ||
                  find.text(l10n.taskDraftConflict).evaluate().isNotEmpty ||
                  find.text(l10n.operationFailed).evaluate().isNotEmpty) {
                break;
              }
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 5)),
              );
              await tester.pump();
            }
            await tester.pumpAndSettle();
            expect(
              (fixture.repository as _RecordingRepository).received,
              hasLength(1),
            );
            final received =
                (fixture.repository as _RecordingRepository).received.single;
            expect(received.observedTask!.percentComplete, initialPercent);
            expect(
              received.observedTask!.providerStatus,
              initialPercent == 0 ? 'NEEDS-ACTION' : 'IN-PROCESS',
            );
            if (windows) {
              expect(received.completionIntent, isTrue);
            } else {
              expect(received.fields['percentComplete'], 50);
              expect(received.fields.containsKey('taskStatus'), isFalse);
            }
            expect(find.text(l10n.operationFailed), findsNothing);
            final conflict =
                concurrent == 'cancel' || concurrent == 'completedTime';
            if (conflict) {
              expect(find.text(l10n.taskDraftConflict), findsOneWidget);
              expect(closed, isFalse);
              expect(
                (await fixture.database.select(fixture.database.tasks).get())
                    .map((row) => row.toJson())
                    .toList(),
                rowsBefore,
              );
              expect(
                (await fixture.database
                        .select(fixture.database.davObjects)
                        .get())
                    .map((row) => row.toJson())
                    .toList(),
                resourcesBefore,
              );
              expect(
                await fixture.database
                    .select(fixture.database.pendingOps)
                    .get(),
                isEmpty,
              );
              expect(
                find.byWidgetPredicate(
                  (widget) => windows
                      ? widget is fluent.TextBox &&
                            widget.controller?.text == 'Retained local title  '
                      : widget is TextField &&
                            widget.controller?.text == 'Retained local title  ',
                ),
                findsOneWidget,
              );
              if (windows) {
                expect(
                  tester
                      .widget<fluent.Checkbox>(
                        find.widgetWithText(fluent.Checkbox, 'Completed'),
                      )
                      .checked,
                  isTrue,
                );
              } else {
                final slider = find.descendant(
                  of: find.byKey(const ValueKey('ical-task-progress')),
                  matching: find.byType(Slider),
                );
                expect(tester.widget<Slider>(slider).value, 50);
              }
              expect(fixture.remote.puts, 0);
            } else {
              final parent = await fixture.repository.readTask(
                fixture.listId,
                fixture.parentId,
              );
              expect(parent!.title, 'Retained local title');
              expect(parent.percentComplete, windows ? 100 : 50);
              expect(
                parent.notes,
                concurrent == 'notes' ? 'Remote notes' : 'Original notes',
              );
              await fixture.replay(windows ? 2 : 1, null);
              final resource = fixture.remote.resources.values.singleWhere(
                (resource) => resource.raw.contains('UID:parent'),
              );
              expect(
                IcalSemanticDocument.parse(resource.raw)
                    .components
                    .single
                    .description,
                parent.notes,
              );
              final component = IcalSemanticDocument.parse(resource.raw)
                  .components
                  .single;
              expect(component.status, windows ? 'COMPLETED' : 'IN-PROCESS');
              expect(component.percentComplete, windows ? 100 : 50);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

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

Future<void> _openLinuxDetails(
  WidgetTester tester,
  _Fixture fixture, {
  required VoidCallback onClose,
  TaskMutationCommittedCallback? onCommitted,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(fixture.database),
        accountsRepositoryProvider.overrideWithValue(
          AccountsRepository(database: fixture.database),
        ),
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
      child: localizedTestApp(
        child: Scaffold(
          body: TaskDetailsPane(
            accountId: DavTaskInventoryFixture.accountId,
            taskListId: fixture.listId,
            taskId: fixture.parentId,
            onClose: onClose,
            onTaskMutationCommitted: onCommitted,
          ),
        ),
      ),
    ),
  );
  for (
    var attempt = 0;
    attempt < 100 &&
        find.byKey(const ValueKey('ical-task-progress')).evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('ical-task-progress')), findsOneWidget);
}

Future<void> _openDetails(
  WidgetTester tester,
  _Fixture fixture, {
  TaskMutationCommittedCallback? onCommitted,
}) async {
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
                  onTaskMutationCommitted: onCommitted,
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
  var externalRevision = 0;

  Future<void> projectParent({
    required String status,
    required int percent,
    String? notes,
    String? completedAt,
  }) async {
    final collection = await database
        .select(database.davCollections)
        .getSingle();
    final object = (await database.select(database.davObjects).get())
        .singleWhere((object) => object.rawIcsBody.contains('UID:parent'));
    final raw =
        DavMutationPatch(
          target: IcalComponentKey(componentType: 'VTODO', uid: 'parent'),
          scope: DavMutationScope.recurrenceMaster,
          operations: [
            DavPatchOperation.setRaw('STATUS', status),
            DavPatchOperation.setRaw('PERCENT-COMPLETE', '$percent'),
            DavPatchOperation.setRaw('COMPLETED', completedAt),
            DavPatchOperation.setText('DESCRIPTION', notes),
          ],
        ).applyTo(
          remote.resources[object.hrefKey]!.raw,
          nowUtc: DateTime.now().toUtc(),
        );
    final etag = '"external-${++externalRevision}"';
    remote.resources[object.hrefKey] = (raw: raw, etag: etag);
    await DavObjectRepository(database: database).commit(
      DavCollectionCommit(
        accountId: DavTaskInventoryFixture.accountId,
        collectionId: collection.id,
        provider: BusyProvider.nextcloud,
        objects: [
          DavPreparedObject.parse(
            hrefKey: object.hrefKey,
            requestUri: Uri.parse(object.requestUri),
            etag: etag,
            contentType: 'text/calendar',
            rawIcsBody: raw,
          ),
        ],
        deletedHrefKeys: const {},
        completeMembership: false,
        membershipHrefKeys: {object.hrefKey},
        finalCursorKind: 'dav_sync_token',
        finalCursorValue: 'external-$externalRevision',
        baselineGeneration: 1,
        completedAtUtc: DateTime.now().toUtc(),
        projectionRangeStartUtc: DateTime.utc(2026),
        projectionRangeEndUtc: DateTime.utc(2027),
      ),
    );
  }

  static Future<_Fixture> create({
    bool recurringParent = false,
    bool recurringChild = false,
  }) async {
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
            if ((recurringParent && !child) || (recurringChild && child))
              'RRULE:FREQ=DAILY;COUNT=3',
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
      _RecordingRepository(
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

class _RecordingRepository extends TasksRepository {
  _RecordingRepository({required super.database, required super.accountId});
  final received = <TaskPatchInput>[];

  @override
  Future<void> patchTask(
    String taskListId,
    String taskId,
    TaskPatchInput input,
  ) {
    received.add(input);
    return super.patchTask(taskListId, taskId, input);
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
