import 'dart:convert';

import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:busymax/src/dav/ical/ical_task_alarm.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/ui/windows/windows_task_details_dialog.dart';
import 'package:busymax/src/ui/windows/windows_time_picker.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final due in [null, '2026-06-08', '2026-06-07']) {
    testWidgets(
      'existing Microsoft task enables a future reminder at 14:00 (due $due)',
      (tester) async {
        final now = DateTime.utc(2026, 6, 8, 14);
        final repository = await _open(tester, due: due, now: () => now);
        await _enable(tester);
        final picker = tester.widget<WindowsTimePicker>(
          find.byType(WindowsTimePicker).last,
        );
        expect(picker.selected!.hour, 14);
        expect(picker.selected!.minute, 10);
        await _save(tester);
        expect(repository.patches.single['microsoftIsReminderOn'], isTrue);
        final timestamp =
            repository.patches.single['microsoftReminderDateTime'] as Map;
        expect(
          providerDateTimeAsUtcInstant(
            timestamp['dateTime'] as String,
            timestamp['timeZone'] as String,
          ),
          now.add(const Duration(minutes: 10)),
        );
      },
    );
  }

  for (final minute in [59, 60]) {
    testWidgets(
      'existing Microsoft reminder validates in its selected zone ($minute)',
      (tester) async {
        // 09:00 Vancouver is 16:00 UTC. Compare instants, not written fields.
        var now = DateTime.utc(2026, 6, 8, 16, 0, 59);
        final repository = await _open(
          tester,
          now: () => now,
          reminderZone: 'America/Vancouver',
        );
        await _enable(tester);
        tester
            .widget<WindowsTimePicker>(find.byType(WindowsTimePicker).last)
            .onChanged!(DateTime(2026, 6, 8, 8, minute));
        await tester.pumpAndSettle();
        await _save(tester);
        if (minute == 59) {
          expect(
            find.text('Choose the current minute or a future reminder time.'),
            findsOneWidget,
          );
          expect(repository.patches, isEmpty);
        } else {
          expect(repository.patches, hasLength(1));
        }
        now = now.add(const Duration(seconds: 2));
      },
    );
  }

  testWidgets(
    'an unrelated title edit preserves an imported historical reminder',
    (tester) async {
      final repository = await _open(
        tester,
        now: () => DateTime.utc(2026, 6, 8, 14),
        historical: true,
      );
      final title = find.byWidgetPredicate(
        (widget) =>
            widget is TextBox && widget.controller?.text == 'Existing task',
      );
      await tester.enterText(title, 'Edited title');
      await _save(tester);
      expect(repository.patches.single, {'title': 'Edited title'});
    },
  );

  testWidgets(
    'enabling a saved disabled reminder refreshes its obsolete default',
    (tester) async {
      final now = DateTime.utc(2026, 6, 8, 14);
      final repository = await _open(
        tester,
        now: () => now,
        historical: true,
        reminderEnabled: false,
      );
      await _enable(tester);
      final picker = tester.widget<WindowsTimePicker>(
        find.byType(WindowsTimePicker).last,
      );
      expect(picker.selected!.hour, 14);
      expect(picker.selected!.minute, 10);
      await _save(tester);
      expect(repository.patches, hasLength(1));
    },
  );

  testWidgets(
    'saving just after the selected minute starts keeps the reminder',
    (tester) async {
      var now = DateTime.utc(2026, 6, 8, 14, 0, 59);
      final repository = await _open(tester, now: () => now);
      await _enable(tester);
      tester
          .widget<WindowsTimePicker>(find.byType(WindowsTimePicker).last)
          .onChanged!(DateTime(2026, 6, 8, 14, 1));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 2));
      await _save(tester);
      expect(repository.patches, hasLength(1));
    },
  );

  testWidgets(
    'editing an existing DAV absolute alarm validates and preserves its sibling',
    (tester) async {
      final now = DateTime.utc(2026, 6, 8, 14);
      final previous = IcalTaskAlarm.displayAbsolute(
        now.subtract(const Duration(days: 2)),
      );
      final sibling = IcalTaskAlarm.displayRelative(
        const Duration(minutes: -30),
        relatedToDue: true,
      );
      final repository = await _open(
        tester,
        provider: BusyProvider.nextcloud,
        now: () => now,
        alarms: [previous, sibling],
      );
      final alarm = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.onPressed != null &&
            widget.trailing is IconButton,
      );
      await tester.ensureVisible(alarm.first);
      await tester.pumpAndSettle();
      await tester.tap(alarm.first);
      await tester.pumpAndSettle();
      final past = now.subtract(const Duration(minutes: 2)).toLocal();
      tester.widget<DatePicker>(find.byType(DatePicker).last).onChanged!(past);
      await tester.pumpAndSettle();
      tester
          .widget<WindowsTimePicker>(find.byType(WindowsTimePicker).last)
          .onChanged!(past);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Choose the current minute or a future reminder time.'),
        findsOneWidget,
      );
      final future = now.add(const Duration(minutes: 1)).toLocal();
      tester
          .widget<WindowsTimePicker>(find.byType(WindowsTimePicker).last)
          .onChanged!(future);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();
      await _save(tester);
      final saved = decodeIcalTaskAlarms(
        jsonEncode(repository.patches.single['taskAlarms']),
      );
      expect(saved, hasLength(2));
      expect(saved.first.absoluteUtc, now.add(const Duration(minutes: 1)));
      expect(saved.last.toJson(), sibling.toJson());
    },
  );

  testWidgets(
    'existing DAV Add uses invocation time and rejects a changed past absolute alarm',
    (tester) async {
      var now = DateTime.utc(2026, 6, 8, 14);
      final repository = await _open(
        tester,
        provider: BusyProvider.nextcloud,
        due: '2026-06-07',
        now: () => now,
      );
      // Time passes while the details dialog is open.
      now = now.add(const Duration(hours: 2));
      final add = find.widgetWithText(Button, 'Add Reminder');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      final picker = tester.widget<WindowsTimePicker>(
        find.byType(WindowsTimePicker).last,
      );
      final expected = now.add(const Duration(minutes: 10)).toLocal();
      expect(picker.selected!.hour, expected.hour);
      expect(picker.selected!.minute, expected.minute);
      tester.widget<DatePicker>(find.byType(DatePicker).last).onChanged!(
        now.toLocal().subtract(const Duration(days: 1)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Choose the current minute or a future reminder time.'),
        findsOneWidget,
      );
      expect(repository.patches, isEmpty);
      tester.widget<DatePicker>(find.byType(DatePicker).last).onChanged!(
        expected,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();
      await _save(tester);
      final alarms = decodeIcalTaskAlarms(
        jsonEncode(repository.patches.single['taskAlarms']),
      );
      expect(alarms.single.absoluteUtc, now.add(const Duration(minutes: 10)));
    },
  );
}

Future<_Tasks> _open(
  WidgetTester tester, {
  String? due,
  required DateTime Function() now,
  String reminderZone = 'UTC',
  bool historical = false,
  bool reminderEnabled = true,
  BusyProvider provider = BusyProvider.microsoft,
  List<IcalTaskAlarm> alarms = const [],
}) async {
  tester.view
    ..physicalSize = const Size(1400, 1100)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final database = AppDatabase.memoryForTests();
  addTearDown(database.close);
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'a',
          provider: provider.storageValue,
          authority: 'https://qa.invalid',
          providerAccountId: 'qa',
          credentialKind: provider == BusyProvider.nextcloud
              ? 'nextcloud_app_password'
              : 'oauth',
          authState: const Value('signed_in'),
          createdAtUtc: '',
          updatedAtUtc: '',
        ),
      );
  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          accountId: 'a',
          id: 'list',
          title: 'Tasks',
          rawJson: '{}',
          createdLocalAtUtc: '',
          updatedLocalAtUtc: '',
        ),
      );
  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          accountId: 'a',
          taskListId: 'list',
          id: 'task',
          title: 'Existing task',
          dueUtc: Value(due),
          rawJson: '{}',
          createdLocalAtUtc: '',
          updatedLocalAtUtc: '',
          microsoftIsReminderOn: Value(historical && reminderEnabled),
          microsoftReminderDateTime: Value(
            historical ? '2026-06-01T09:00:00' : null,
          ),
          microsoftReminderTimeZone: Value(reminderZone),
          taskAlarmsJson: Value(
            alarms.isEmpty ? null : encodeIcalTaskAlarms(alarms),
          ),
        ),
      );
  final repository = _Tasks(
    database,
    TaskEntity.fromRow(await database.select(database.tasks).getSingle()),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        localTimeZoneProvider.overrideWithValue('Etc/UTC'),
        accountsRepositoryProvider.overrideWithValue(
          _Accounts(database, provider),
        ),
        tasksRepositoryForAccountProvider.overrideWith((ref, _) => repository),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, _) => TaskListsRepository(database: database, accountId: 'a'),
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
            child: const Text('Open details'),
            onPressed: () => showWindowsTaskDetailsDialog(
              context,
              ref,
              TaskScheduleItem(
                id: 'task',
                accountId: 'a',
                provider: provider,
                sourceId: 'list',
                title: 'Existing task',
                completed: false,
                allDay: true,
              ),
              now: now,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open details'));
  await tester.pumpAndSettle();
  expect(find.byType(ContentDialog), findsOneWidget);
  return repository;
}

Future<void> _enable(WidgetTester tester) async {
  final expander = find.byKey(const ValueKey('task-reminders-recurrence'));
  await tester.ensureVisible(expander);
  if (!tester.widget<Expander>(expander).initiallyExpanded) {
    final header = find.byWidget(tester.widget<Expander>(expander).header);
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
  }
  final toggle = find.widgetWithText(ToggleSwitch, 'Reminder');
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Save').last;
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

class _Tasks extends TasksRepository {
  _Tasks(AppDatabase database, this.task)
    : super(database: database, accountId: 'a');
  final TaskEntity task;
  @override
  Stream<TaskEntity?> watchTask(String taskListId, String taskId) =>
      Stream.value(task);
  @override
  Stream<TaskHierarchySnapshot> watchTaskHierarchy(
    String taskListId,
    String taskId,
  ) => Stream.value(const TaskHierarchySnapshot(parent: null, subtasks: []));
  final patches = <Map<String, Object?>>[];
  @override
  Future<void> patchTask(
    String taskListId,
    String taskId,
    TaskPatchInput input,
  ) async {
    patches.add(input.fields);
  }
}

class _Accounts extends AccountsRepository {
  _Accounts(AppDatabase database, this.provider) : super(database: database);
  final BusyProvider provider;
  @override
  Stream<List<AccountEntity>> watchAccounts() => Stream.value([
    AccountEntity(
      id: 'a',
      provider: provider,
      authority: 'https://qa.invalid',
      providerAccountId: 'qa',
      authState: accountAuthStateSignedIn,
    ),
  ]);
}
