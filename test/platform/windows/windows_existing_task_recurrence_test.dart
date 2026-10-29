import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/ical/ical_semantics.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/ui/windows/windows_task_details_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dav_task_inventory_fixture.dart';

void main() {
  testWidgets(
    'Windows duration validation retains the draft and explains the start transition',
    (tester) async {
      final fixture = await _open(tester, startOnlyDuration: true);
      final title = find.byWidgetPredicate(
        (widget) =>
            widget is TextBox &&
            widget.controller?.text == 'Existing recurring task',
      );
      await tester.enterText(title, 'Retained duration draft');
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ContentDialog)),
      );
      final start = find.byWidgetPredicate(
        (widget) =>
            widget is InfoLabel &&
            widget.label.toPlainText() == l10n.startDateTime,
      );
      final clear = find
          .descendant(of: start, matching: find.byType(IconButton))
          .last;
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      await _save(tester);
      expect(find.text(l10n.taskDurationRequiresStart), findsOneWidget);
      expect(find.byType(ContentDialog), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextBox &&
              widget.controller?.text == 'Retained duration draft',
        ),
        findsOneWidget,
      );
      expect(
        await fixture.database.select(fixture.database.pendingOps).get(),
        isEmpty,
      );
      expect(
        (await fixture.database.select(fixture.database.davObjects).getSingle())
            .rawIcsBody,
        fixture.raw,
      );
      expect(
        (await fixture.database.select(fixture.database.tasks).getSingle())
            .title,
        'Existing recurring task',
      );
      tester.widget<DatePicker>(find.byType(DatePicker).first).onChanged!(
        DateTime(2026, 8, 12),
      );
      await tester.pumpAndSettle();
      await _save(tester);
      final operation = await fixture.database
          .select(fixture.database.pendingOps)
          .getSingle();
      final candidate = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      ).applyTo(operation.baselineRawIcs!, nowUtc: _now);
      expect(candidate, contains('SUMMARY:Retained duration draft'));
      expect(candidate, contains('DUE;VALUE=DATE:20260812'));
      expect(candidate, isNot(contains('DURATION:')));
      expect(candidate, isNot(contains('DTSTART:')));
    },
  );

  testWidgets(
    'existing Windows DAV task edits interval and count into the durable resource',
    (tester) async {
      final fixture = await _open(tester);
      await _advanced(tester);
      expect(find.byType(ContentDialog), findsNWidgets(2));
      await _number(tester, 'Interval', '3');
      await _number(tester, 'Occurrences', '7');
      await _save(tester);
      await _save(tester);
      final operation = await fixture.database
          .select(fixture.database.pendingOps)
          .getSingle();
      final candidate = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      ).applyTo(operation.baselineRawIcs!, nowUtc: _now);
      expect(
        IcalSemanticDocument.parse(candidate).components.single.recurrenceRules,
        ['FREQ=DAILY;INTERVAL=3;COUNT=7'],
      );
      expect(candidate, contains('UID:recurrence-task'));
      expect(candidate, contains('X-KEEP:opaque'));
      expect(candidate, contains('BEGIN:VALARM'));
      final row = await fixture.database
          .select(fixture.database.tasks)
          .getSingle();
      final recurrence = RecurrenceRule.fromJson(row.recurrenceJson);
      expect(recurrence.interval, 3);
      expect(recurrence.count, 7);
      expect(row.localDirty, isTrue);
    },
  );

  testWidgets(
    'existing Windows DAV timed end date keeps the occurrence clock',
    (tester) async {
      final fixture = await _open(tester);
      await _advanced(tester);
      final ending = find.text('After a number of occurrences');
      await tester.tap(ending);
      await tester.pumpAndSettle();
      await tester.tap(find.text('On date').last);
      await tester.pumpAndSettle();
      tester.widget<DatePicker>(find.byType(DatePicker).last).onChanged!(
        DateTime(2026, 8, 12),
      );
      await tester.pumpAndSettle();
      await _save(tester);
      await _save(tester);
      final operation = await fixture.database
          .select(fixture.database.pendingOps)
          .getSingle();
      final candidate = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      ).applyTo(operation.baselineRawIcs!, nowUtc: _now);
      final recurrence = RecurrenceRule.fromJson(
        (await fixture.database.select(fixture.database.tasks).getSingle())
            .recurrenceJson,
      );
      expect(recurrence.untilRaw, '20260812T090000Z');
      expect(recurrence.count, isNull);
      expect(candidate, contains('UNTIL=20260812T090000Z'));
    },
  );

  for (final rename in [false, true]) {
    testWidgets(
      'existing Windows DAV recurrence stays exact after unchanged editor Save (rename $rename)',
      (tester) async {
        final fixture = await _open(
          tester,
          rule: 'FREQ=DAILY;COUNT=5;INTERVAL=2',
        );
        await _advanced(tester);
        await _save(tester);
        if (rename) {
          final title = find.byWidgetPredicate(
            (widget) =>
                widget is TextBox &&
                widget.controller?.text == 'Existing recurring task',
          );
          await tester.ensureVisible(title);
          await tester.enterText(title, 'Renamed task');
        }
        await _save(tester);
        final operations = await fixture.database
            .select(fixture.database.pendingOps)
            .get();
        if (rename) {
          expect(operations, hasLength(1));
          final operation = operations.single;
          final candidate = DavMutationPatch.fromJsonString(
            operation.mutationPatchJson!,
          ).applyTo(operation.baselineRawIcs!, nowUtc: _now);
          expect(
            candidate,
            contains('RRULE:FREQ=DAILY;COUNT=5;INTERVAL=2\r\n'),
          );
          expect(candidate, contains('SUMMARY:Renamed task'));
        } else {
          expect(operations, isEmpty);
        }
        expect(
          (await fixture.database
                  .select(fixture.database.davObjects)
                  .getSingle())
              .rawIcsBody,
          fixture.raw,
        );
      },
    );
  }

  testWidgets(
    'existing Windows DAV unsupported recurrence remains protected during a title edit',
    (tester) async {
      final fixture = await _open(tester, rule: 'FREQ=HOURLY;INTERVAL=3');
      await _expand(tester);
      final advanced = find.byKey(const ValueKey('task-advanced-recurrence'));
      await tester.ensureVisible(advanced);
      expect(tester.widget<Button>(advanced).onPressed, isNull);
      expect(
        find.text(
          AppLocalizations.of(tester.element(advanced))
              .unsupportedRecurrencePreserved,
        ),
        findsOneWidget,
      );
      final title = find.byWidgetPredicate(
        (widget) =>
            widget is TextBox &&
            widget.controller?.text == 'Existing recurring task',
      );
      await tester.ensureVisible(title);
      await tester.enterText(title, 'Renamed unsupported task');
      await _save(tester);
      final operation = await fixture.database
          .select(fixture.database.pendingOps)
          .getSingle();
      final candidate = DavMutationPatch.fromJsonString(
        operation.mutationPatchJson!,
      ).applyTo(operation.baselineRawIcs!, nowUtc: _now);
      expect(candidate, contains('RRULE:FREQ=HOURLY;INTERVAL=3\r\n'));
      expect(candidate, contains('SUMMARY:Renamed unsupported task'));
    },
  );
}

Future<({AppDatabase database, String raw})> _open(
  WidgetTester tester, {
  String rule = 'FREQ=DAILY;INTERVAL=2;COUNT=5',
  bool startOnlyDuration = false,
}) async {
  tester.view
    ..physicalSize = const Size(1400, 1100)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final database = AppDatabase.memoryForTests();
  addTearDown(database.close);
  final inventory = DavTaskInventoryFixture(database);
  await inventory.seedAccount();
  await inventory.commit(writable: true);
  final collection = await database.select(database.davCollections).getSingle();
  final taskList = await database.select(database.taskLists).getSingle();
  final raw = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//BusyMax recurrence QA//EN',
    'BEGIN:VTODO',
    'UID:recurrence-task',
    'DTSTAMP:20260808T000000Z',
    'SUMMARY:Existing recurring task',
    if (startOnlyDuration) ...[
      'DTSTART:20260808T090000Z',
      'DURATION:PT2H',
    ] else
      'DUE:20260808T090000Z',
    'RRULE:$rule',
    'X-KEEP:opaque',
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'TRIGGER;RELATED=END:-PT15M',
    'DESCRIPTION:Reminder',
    'END:VALARM',
    'END:VTODO',
    'END:VCALENDAR',
    '',
  ].join('\r\n');
  final object = DavPreparedObject.parse(
    hrefKey: '${collection.hrefKey}recurrence.ics',
    requestUri: Uri.parse(collection.requestUri).resolve('recurrence.ics'),
    etag: '"original"',
    contentType: 'text/calendar',
    rawIcsBody: raw,
  );
  await DavObjectRepository(database: database).commit(
    DavCollectionCommit(
      accountId: DavTaskInventoryFixture.accountId,
      collectionId: collection.id,
      provider: BusyProvider.nextcloud,
      objects: [object],
      deletedHrefKeys: const {},
      completeMembership: true,
      membershipHrefKeys: {object.hrefKey},
      finalCursorKind: 'dav_sync_token',
      finalCursorValue: 'qa-token',
      baselineGeneration: 1,
      completedAtUtc: _now,
      projectionRangeStartUtc: DateTime.utc(2026),
      projectionRangeEndUtc: DateTime.utc(2027),
    ),
  );
  final task = await database.select(database.tasks).getSingle();
  final repository = TasksRepository(
    database: database,
    accountId: DavTaskInventoryFixture.accountId,
    nowUtc: () => _now,
  );
  Object? openError;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        localTimeZoneProvider.overrideWithValue('UTC'),
        accountsRepositoryProvider.overrideWithValue(
          AccountsRepository(database: database),
        ),
        tasksRepositoryForAccountProvider.overrideWith((ref, _) => repository),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, _) => TaskListsRepository(
            database: database,
            accountId: DavTaskInventoryFixture.accountId,
          ),
        ),
        davTaskCollectionCapabilitiesProvider.overrideWith(
          (ref, _) => Stream.value(nextcloudTaskCollectionCapabilities),
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
                  TaskScheduleItem(
                    id: task.id,
                    accountId: task.accountId,
                    sourceId: taskList.id,
                    provider: BusyProvider.nextcloud,
                    title: task.title,
                    completed: false,
                    allDay: false,
                  ),
                  now: () => _now,
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
    attempt < 30 &&
        find.byType(ContentDialog).evaluate().isEmpty &&
        openError == null;
    attempt += 1
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(openError, isNull);
  expect(find.byType(ContentDialog), findsOneWidget);
  return (database: database, raw: raw);
}

Future<void> _expand(WidgetTester tester) async {
  final expander = find.byKey(const ValueKey('task-reminders-recurrence'));
  await tester.ensureVisible(expander);
  final widget = tester.widget<Expander>(expander);
  if (!widget.initiallyExpanded) {
    await tester.tap(find.byWidget(widget.header));
    await tester.pumpAndSettle();
  }
}

Future<void> _advanced(WidgetTester tester) async {
  await _expand(tester);
  final advanced = find.byKey(const ValueKey('task-advanced-recurrence'));
  expect(advanced, findsOneWidget);
  await tester.ensureVisible(advanced);
  await tester.tap(advanced);
  await tester.pumpAndSettle();
}

Future<void> _number(WidgetTester tester, String label, String value) async {
  final field = find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is InfoLabel && widget.label.toPlainText() == label,
    ),
    matching: find.byType(TextBox),
  );
  await tester.enterText(field, value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Save').last;
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

final _now = DateTime.utc(2026, 8, 8, 8);
