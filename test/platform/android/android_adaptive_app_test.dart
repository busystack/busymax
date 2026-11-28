import 'package:busymax/src/ui/common/schedule/schedule_day_week_view.dart'
    as shared_planner;
import 'package:busymax/src/android/presentation/android_editor_group.dart';
import 'package:busymax/src/dav/ical/ical_task_alarm.dart';
import 'package:busymax/src/ui/common/schedule/schedule_interactions.dart';

import '../../support/schedule_parity_fixture.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_workspace_navigation.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/android/presentation/android_availability_dialog.dart';
import 'package:busymax/src/android/presentation/android_diagnostics_screen.dart';
import 'package:busymax/src/android/presentation/android_feedback_screen.dart';
import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/android/presentation/android_schedule_search_filters.dart';
import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:busymax/src/android/presentation/android_tasks_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/dav/mutation/dav_pending_operations.dart';
import 'package:busymax/src/dav/mutation/dav_conditional_mutation_service.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/domain/event_editor_draft.dart';
import 'package:busymax/src/features/feedback/data/feedback_api_client.dart';
import 'package:busymax/src/features/feedback/data/feedback_submission.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/features/notifications/notification_schedule_service.dart';
import 'package:busymax/src/features/schedule/application/attachment_upload_coordinator.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/sync/pending_mutation_sync_requester.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/google_calendar/google_calendar_models.dart';
import 'package:busymax/src/l10n/l10n.dart';
import 'package:busymax/src/l10n/localized_formatters.dart';
import 'package:busymax/src/l10n/week_preferences_scope.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_api_client.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_calendar_models.dart';
import 'package:busymax/src/microsoft_calendar/microsoft_shared_calendar_address.dart';
import 'package:busymax/src/microsoft_todo/api/microsoft_todo_api_client.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/features/tasks/domain/task_checklist_item.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_client.dart';
import 'package:busymax/src/features/tasks/domain/task_remote_models.dart';
import 'package:busymax/src/features/sync/pending_ops_replayer.dart';
import 'package:busymax/src/features/sync/calendar_pending_ops_replayer.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_sidebar_visibility_icon.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/memory_settings_store.dart';
import '../../support/stateful_task_dav_remote.dart';
import '../../test_localized_app.dart';

final _longScheduleDetailsNotes = List.generate(
  60,
  (index) => 'Full task note line ${index + 1}',
).join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android foreground refresh can finish after the shell closes', (
    tester,
  ) async {
    final syncStarted = Completer<void>();
    final syncFinished = Completer<void>();
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      onForegroundSync: () {
        syncStarted.complete();
        return syncFinished.future;
      },
    );
    addTearDown(harness.dispose);
    expect(syncStarted.isCompleted, isTrue);

    await tester.pumpWidget(const SizedBox());
    syncFinished.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Schedule can hide an account or open its settings without collapsing it',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(420, 900);
      addTearDown(tester.view.reset);
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        populated: true,
      );
      addTearDown(harness.dispose);
      const accountId = 'google:populated';
      await tester.tap(find.byIcon(Icons.view_sidebar_outlined).first);
      await tester.pumpAndSettle();
      final toggle = find.byKey(
        const ValueKey(('account-visibility', accountId)),
      );
      final list = find.byKey(
        const ValueKey(('task-list-visibility', accountId, 'visible-list')),
      );
      final calendar = find.byKey(
        const ValueKey(('calendar-visibility', 'calendar')),
      );
      final options = find.byKey(
        const ValueKey(('account-collection-options', accountId)),
      );
      final collapse = find.byKey(
        const ValueKey(('account-collapse', accountId)),
      );
      final sheet = tester.getRect(find.byType(BottomSheet));
      Finder tile(Finder leading) =>
          find.ancestor(of: leading, matching: find.byType(ListTile)).first;
      for (final (leading, title, menu) in [
        (toggle, 'Calendar Account', options),
        (
          calendar,
          'Populated calendar',
          find.descendant(
            of: tile(calendar),
            matching: find.byTooltip('Options'),
          ),
        ),
        (
          list,
          'Visible tasks',
          find.descendant(of: tile(list), matching: find.byTooltip('Options')),
        ),
      ]) {
        final leadingBounds = tester.getRect(leading);
        final menuBounds = tester.getRect(menu);
        final titleBounds = tester.getRect(
          find.descendant(of: tile(leading), matching: find.text(title)),
        );
        expect(leadingBounds.size, const Size.square(48));
        expect(menuBounds.size, leadingBounds.size);
        expect(leadingBounds.left - sheet.left, 2);
        expect(sheet.right - menuBounds.right, 2);
        final sourceIcon = tester
            .widget<ScheduleSidebarVisibilityIcon>(leading)
            .icon;
        final more = find.descendant(
          of: menu,
          matching: find.byIcon(Icons.more_vert),
        );
        expect(tester.getCenter(find.byWidget(sourceIcon)).dx - sheet.left, 18);
        expect(sheet.right - tester.getCenter(more).dx, 18);
        expect(titleBounds.left - leadingBounds.right, 8);
      }
      expect(tester.getRect(options).left - tester.getRect(collapse).right, 4);
      expect(tester.getSize(toggle).shortestSide, greaterThanOrEqualTo(48));
      expect(list, findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(list, findsOneWidget);
      expect(
        tester.widget<ScheduleSidebarVisibilityIcon>(list).onPressed,
        isNull,
      );
      expect(
        harness.container
            .read(appSettingsControllerProvider)
            .isAccountVisibleInSchedule(accountId),
        isFalse,
      );
      await tester.tap(options);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_upward), findsWidgets);
      expect(find.byIcon(Icons.arrow_downward), findsWidgets);
      await tester.tap(find.text('Account settings'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AndroidSettingsScreen>(find.byType(AndroidSettingsScreen))
            .accountDetailId,
        accountId,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(toggle.hitTestable(), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ScheduleSidebarVisibilityIcon>(list).visible,
        isTrue,
      );
    },
  );

  testWidgets(
    'task notification search restores the prior normal calendar date',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults().copyWith(
          androidScheduleViewMode: ScheduleViewMode.day,
        ),
        seedDatabase: (db) async {
          await seedScheduleParityFixture(db);
          await (db.update(db.tasks)
                ..where((row) => row.id.equals('date-only-task')))
              .write(const TasksCompanion(dueUtc: Value('2001-01-01')));
        },
      );
      addTearDown(harness.dispose);
      final before = tester
          .widget<shared_planner.ScheduleDayWeekView>(
            find.byType(shared_planner.ScheduleDayWeekView),
          )
          .selectedDate;
      harness.container
          .read(androidWorkspaceRequestProvider.notifier)
          .state = AndroidWorkspaceRequest(
        date: DateTime.now(),
        itemId: 'date-only-task',
        accountId: 'google:populated',
        taskListId: 'visible-list',
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit Task'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final restored = tester
          .widget<shared_planner.ScheduleDayWeekView>(
            find.byType(shared_planner.ScheduleDayWeekView),
          )
          .selectedDate;
      expect(DateUtils.dateOnly(restored), DateUtils.dateOnly(before));
      expect(
        harness.container
            .read(appSettingsControllerProvider)
            .androidScheduleViewMode,
        ScheduleViewMode.day,
      );
      await harness.dispose();
    },
  );

  testWidgets(
    'event destination change saves the live unsaved reminder edits',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        populated: true,
        notificationBackend: _PermissionOnlyNotifications(),
        onCalendarSync: (_) async {},
      );
      addTearDown(harness.dispose);
      final repository = harness.container.read(calendarRepositoryProvider);
      await tester.runAsync(
        () => repository.upsertSource(
          accountId: 'google:populated',
          source: const CalendarSourceDto(
            provider: BusyProvider.google,
            providerCalendarId: 'reminder-target',
            summary: 'Reminder destination',
            accessRole: 'owner',
          ),
        ),
      );
      final sources = await tester.runAsync(
        () => repository.watchSourcesForAccounts(['google:populated']).first,
      );
      final availableSources = sources!;
      final original = availableSources.firstWhere((s) => s.id == 'calendar');
      final target = availableSources.firstWhere(
        (s) => s.providerCalendarId == 'reminder-target',
      );
      final start = DateTime.now();
      final draft =
          EventEditorDraft.newEvent(
            accountId: original.accountId,
            sourceId: original.id,
            providerCalendarId: original.providerCalendarId,
            start: start,
            end: start.add(const Duration(hours: 1)),
          ).copyWith(
            title: 'Reminder draft transition',
            reminders: {
              'useDefault': false,
              'overrides': [
                {'method': 'popup', 'minutes': 10},
              ],
            },
          );
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  AndroidEventEditor(sources: availableSources, draft: draft),
            ),
          );
      await tester.pumpAndSettle();
      final reminder = find.byKey(const ValueKey('android-event-popup-0'));
      await _scrollUntilBuilt(tester, reminder);
      await tester.tap(reminder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('60 minutes before').hitTestable().last);
      await tester.pumpAndSettle();
      final destination = find.byKey(
        ValueKey('android-event-calendar-${original.id}'),
      );
      await tester.ensureVisible(destination);
      await tester.pumpAndSettle();
      await tester.tap(destination);
      await tester.pumpAndSettle();
      await tester.tap(find.text(target.summary).hitTestable().last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await _pumpUntilFound(tester, find.byType(AndroidScheduleScreen));
      final saved = await tester.runAsync(
        () =>
            (harness.database.select(harness.database.calendarEvents)
                  ..where((r) => r.title.equals('Reminder draft transition')))
                .getSingle(),
      );
      expect(saved!.calendarSourceId, target.id);
      expect(jsonDecode(saved.remindersJson!), {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 60},
        ],
      });
      await harness.dispose();
    },
  );

  testWidgets(
    'compact source calendar retains scaled headings and seven date columns',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 500);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        populated: true,
      );
      addTearDown(harness.dispose);
      await tester.tap(find.byTooltip('Calendars and task lists'));
      await tester.pumpAndSettle();
      expect(find.text('${DateTime.now().year}'), findsWidgets);
      expect(find.textContaining('https://accounts.google.com'), findsNothing);
      final provider = tester.widget<ScheduleSidebarVisibilityIcon>(
        find.byKey(const ValueKey(('account-visibility', 'google:populated'))),
      );
      expect(provider.label, startsWith('Google,'));
      expect((provider.icon as Icon).icon, Icons.g_mobiledata);
      expect(tester.takeException(), isNull);
      await harness.dispose();
    },
  );

  testWidgets('Month overflow completion rebuilds before the second toggle', (
    tester,
  ) async {
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.month,
      ),
      seedDatabase: (db) async {
        await seedScheduleParityFixture(db);
        await db.delete(db.calendarEvents).go();
        final today = DateTime.now().toIso8601String().substring(0, 10);
        for (var i = 0; i < 12; i++) {
          await db
              .into(db.calendarEvents)
              .insert(
                CalendarEventsCompanion.insert(
                  id: 'overflow-$i',
                  accountId: 'google:populated',
                  calendarSourceId: 'calendar',
                  provider: 'google',
                  providerCalendarId: 'calendar',
                  providerEventId: 'overflow-$i',
                  title: 'Overflow event $i',
                  allDay: const Value(true),
                  startDate: Value(today),
                  rawJson: const Value('{}'),
                  createdAtLocal: 1,
                  updatedAtLocal: 1,
                ),
              );
        }
      },
    );
    addTearDown(harness.dispose);
    final more = find
        .byWidgetPredicate(
          (widget) =>
              widget is TextButton &&
              widget.child is Text &&
              RegExp(r'^\+?\d+ more$')
                  .hasMatch((widget.child as Text).data ?? ''),
        )
        .hitTestable();
    expect(more, findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    final row = find.widgetWithText(ListTile, 'Date-only task');
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(_completionControl(row));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(_completionControl(row)).value, isTrue);
    expect(
      (await harness.database.tasksDao.listTasks(
        'google:populated',
        'visible-list',
      )).single.status,
      'completed',
    );
    await tester.tap(_completionControl(row));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(_completionControl(row)).value, isFalse);
    final stored = (await harness.database.tasksDao.listTasks(
      'google:populated',
      'visible-list',
    )).single;
    expect(stored.status, 'needsAction');
    await tester.tap(find.text('Date-only task'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('android-schedule-details-scroll')),
      findsOneWidget,
    );

    await harness.dispose();
  });

  testWidgets(
    'read-only remembered task destination falls back to writable choices',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        davTaskCapabilities: nextcloudTaskCollectionCapabilities.asReadOnly(),
        seedDatabase: (db) async {
          await _seedAndroidEditorTask(db);
          await seedScheduleParityFixture(db);
        },
      );
      addTearDown(harness.dispose);
      await harness.container
          .read(appSettingsControllerProvider.notifier)
          .setDefaultTaskList(
            const CreationDestination(
              accountId: 'nextcloud:android-editor',
              id: 'editor-list',
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'New task'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsNothing);
      expect(find.text('Editor tasks'), findsNothing);
      await tester.tap(find.text('Visible tasks'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AndroidTaskEditor>(find.byType(AndroidTaskEditor))
            .accountId,
        'google:populated',
      );

      await harness.dispose();
    },
  );

  for (final seconds in [45, 90]) {
    testWidgets(
      'accepting an existing $seconds second task alarm preserves precision',
      (tester) async {
        late TaskEntity task;
        final harness = await _pumpApp(
          tester,
          AppSettings.defaults(),
          seedDatabase: (db) async {
            task = await _seedAndroidEditorTask(
              db,
              start: '2026-11-15T09:00:00',
              due: '2026-11-15T10:00:00',
            );
            await (db.update(
              db.tasks,
            )..where((row) => row.accountId.equals(task.accountId))).write(
              TasksCompanion(
                taskAlarmsJson: Value(
                  encodeIcalTaskAlarms([
                    IcalTaskAlarm.displayRelative(
                      Duration(seconds: -seconds),
                      relatedToDue: false,
                    ),
                  ]),
                ),
              ),
            );
            task = TaskEntity.fromRow(
              (await db.tasksDao.listTasks(
                task.accountId,
                task.taskListId,
              )).single,
            );
          },
        );
        addTearDown(harness.dispose);
        await _openAndroidTaskEditor(tester, task, BusyProvider.nextcloud);
        final alarm = find.textContaining('$seconds Seconds');
        await _scrollUntilBuilt(tester, alarm);
        await tester.ensureVisible(alarm);
        await tester.tap(alarm);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(ListTile, 'Before the task starts'),
        );
        await tester.pumpAndSettle();
        expect(find.text('$seconds'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        final saved = (await harness.database.tasksDao.listTasks(
          task.accountId,
          task.taskListId,
        )).single;
        expect(
          decodeIcalTaskAlarms(saved.taskAlarmsJson).single.relativeOffset,
          Duration(seconds: -seconds),
        );

        await harness.dispose();
      },
    );
  }

  const platformChannel = MethodChannel('io.busystack.busymax/android');
  const eventChannel = MethodChannel('io.busystack.busymax/events');
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, String> secureStorage;
  late bool remainingRecoveryDeletesFail;

  setUp(() {
    secureStorage = {};
    remainingRecoveryDeletesFail = false;
    messenger.setMockMethodCallHandler(platformChannel, (call) async {
      return switch (call.method) {
        'takeInitialActivation' => null,
        'googleAuthorizationAvailable' => false,
        'microsoftAuthorizationAvailable' => false,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(eventChannel, (_) async => null);
    messenger.setMockMethodCallHandler(secureStorageChannel, (call) async {
      final arguments = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
      final key = arguments['key']?.toString();
      return switch (call.method) {
        'read' => key == null ? null : secureStorage[key],
        'write' => () {
          if (key != null) {
            secureStorage[key] = arguments['value']?.toString() ?? '';
          }
          return null;
        }(),
        'delete' => () {
          if (remainingRecoveryDeletesFail &&
              key != null &&
              secureStorage.containsKey(key)) {
            throw PlatformException(code: 'test-delete-failed');
          }
          if (key != null) {
            secureStorage.remove(key);
          }
          return null;
        }(),
        'deleteAll' => () {
          secureStorage.clear();
          return null;
        }(),
        'containsKey' => key != null && secureStorage.containsKey(key),
        'readAll' => secureStorage,
        _ => null,
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(platformChannel, null);
    messenger.setMockMethodCallHandler(eventChannel, null);
    messenger.setMockMethodCallHandler(secureStorageChannel, null);
  });

  for (final resume in [false, true]) {
    testWidgets(
      'Settings observes external DAV journals and collections after ${resume ? 'resume' : 'dataChanged'}',
      (tester) async {
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busymax-ui-db-'),
        ))!;
        final file = File('${directory.path}/state.sqlite');
        final foreground = AppDatabase(NativeDatabase(file));
        final background = AppDatabase(NativeDatabase(file));
        final harness = (await tester.runAsync(
          () => _pumpApp(
            tester,
            AppSettings.defaults(),
            databaseOverride: foreground,
            seedDatabase: (db) async {
              await db
                  .into(db.accounts)
                  .insert(
                    AccountsCompanion.insert(
                      id: 'caldav',
                      provider: 'caldav',
                      authority: 'https://example.test/',
                      providerAccountId: 'user',
                      credentialKind: 'caldav_password',
                      createdAtUtc: 'now',
                      updatedAtUtc: 'now',
                    ),
                  );
              await db
                  .into(db.davCollectionCreations)
                  .insert(
                    DavCollectionCreationsCompanion.insert(
                      id: 'creation',
                      accountId: 'caldav',
                      authority: 'https://example.test/',
                      homeUri: 'https://example.test/calendars/',
                      targetUri: 'https://example.test/calendars/new/',
                      displayName: 'Background request',
                      componentsJson: '["VEVENT"]',
                      state: const Value('dispatched'),
                      lastErrorCode: const Value('DavUncertain'),
                      createdAtUtc: 'now',
                    ),
                  );
            },
          ),
        ))!;
        addTearDown(
          () => tester.runAsync(() async {
            await background.close();
            await harness.dispose();
            await directory.delete(recursive: true);
          }),
        );

        await _openAndroidSettings(tester);
        await tester.pumpAndSettle();
        final noticeSubscription = harness.container.listen(
          accountCollectionCreationFailuresProvider('caldav'),
          (_, _) {},
        );
        addTearDown(noticeSubscription.close);
        await tester.pump();
        for (
          var attempt = 0;
          attempt < 20 &&
              !harness.container
                  .read(storedDavCollectionCreationNoticesProvider('caldav'))
                  .hasValue;
          attempt++
        ) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        expect(
          harness.container
              .read(accountCollectionCreationFailuresProvider('caldav'))
              .values
              .single
              .pending,
          isTrue,
        );
        await tester.runAsync(() async {
          await background
              .into(background.davCollections)
              .insert(
                DavCollectionsCompanion.insert(
                  id: 'new',
                  accountId: 'caldav',
                  hrefKey: '/calendars/new/',
                  requestUri: 'https://example.test/calendars/new/',
                  displayName: 'Discovered in background',
                  supportedComponentMask: const Value(1),
                  createdAtUtc: 'now',
                  updatedAtUtc: 'now',
                ),
              );
          await background
              .update(background.davCollectionCreations)
              .write(
                const DavCollectionCreationsCompanion(
                  state: Value('rejected'),
                  lastErrorCode: Value('DavPermissionDenied'),
                  lastErrorKind: Value('authorization'),
                  lastErrorStatus: Value(403),
                ),
              );
        });
        if (resume) {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        } else {
          await messenger.handlePlatformMessage(
            'io.busystack.busymax/events',
            const StandardMethodCodec().encodeSuccessEnvelope({
              'type': 'dataChanged',
              'data': <String, Object?>{},
            }),
            (_) {},
          );
        }
        await tester.pump();
        for (var attempt = 0; attempt < 20; attempt++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          final notices = harness.container
              .read(storedDavCollectionCreationNoticesProvider('caldav'))
              .valueOrNull;
          if (harness.container
                      .read(davCollectionsStreamProvider)
                      .valueOrNull
                      ?.isNotEmpty ==
                  true &&
              notices?.singleOrNull?.pending == false) {
            break;
          }
        }
        await tester.pumpAndSettle();
        expect(
          harness.container
              .read(davCollectionsStreamProvider)
              .value!
              .single
              .name,
          'Discovered in background',
        );
        expect(
          harness.container
              .read(accountCollectionCreationFailuresProvider('caldav'))
              .values
              .single
              .pending,
          isFalse,
        );
        expect(find.byType(AndroidSettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('clean Android workspace uses the Linux view default', (
    tester,
  ) async {
    final settings = AppSettings.defaults();
    final harness = await _pumpApp(tester, settings);
    addTearDown(harness.dispose);
    expect(settings.scheduleViewMode, ScheduleViewMode.week);
    expect(
      find.byKey(const ValueKey('android-week-time-grid')),
      findsOneWidget,
    );
    await harness.container
        .read(appSettingsControllerProvider.notifier)
        .setAndroidScheduleViewMode(ScheduleViewMode.month);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('android-month-grid')), findsOneWidget);
    await harness.container
        .read(appSettingsControllerProvider.notifier)
        .reload();
    await tester.pumpAndSettle();
    expect(
      harness.container
          .read(appSettingsControllerProvider)
          .androidScheduleViewMode,
      ScheduleViewMode.month,
    );

    await harness.dispose();
  });

  testWidgets(
    'all-time task search includes hidden lists and restores the workspace',
    (tester) async {
      final settings = AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.month,
        taskListScheduleVisibility: {'google:populated::hidden-list': false},
      );
      final harness = await _pumpApp(tester, settings, populated: true);
      addTearDown(harness.dispose);
      expect(find.text('Hidden task'), findsNothing);
      await _openAndroidScheduleScreen(tester);
      expect(find.text('Hidden task'), findsOneWidget);
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      final filters = tester.widget<AndroidScheduleSearchFilters>(
        find.byType(AndroidScheduleSearchFilters),
      );
      expect(filters.value.type, ScheduleSearchType.tasks);
      expect(filters.value.date, ScheduleSearchDate.any);
      expect(
        filters.value.taskListKeys,
        contains(
          const ScheduleTaskListKey(
            accountId: 'google:populated',
            taskListId: 'hidden-list',
          ),
        ),
      );
      filters.onChanged(filters.value.copyWith(taskListKeys: {}));
      await tester.pumpAndSettle();
      expect(
        harness.container
            .read(appSettingsControllerProvider)
            .taskListScheduleVisibility,
        settings.taskListScheduleVisibility,
      );
      tester
          .widget<AndroidScheduleSearchFilters>(
            find.byType(AndroidScheduleSearchFilters),
          )
          .onClear();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AndroidScheduleSearchFilters>(
              find.byType(AndroidScheduleSearchFilters),
            )
            .value
            .taskListKeys,
        filters.value.taskListKeys
            .where((key) => key.taskListId != 'hidden-list')
            .toSet(),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('android-month-grid')), findsOneWidget);
      expect(find.text('Hidden task'), findsNothing);

      await harness.dispose();
    },
  );

  testWidgets('daily summary opens task scope in the retained workspace', (
    tester,
  ) async {
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      seedDatabase: seedScheduleParityStress,
    );
    addTearDown(harness.dispose);
    harness.container.read(androidWorkspaceRequestProvider.notifier).state =
        AndroidWorkspaceRequest(date: DateTime.now(), summary: true);
    await tester.pumpAndSettle();
    expect(find.byType(AndroidScheduleScreen), findsOneWidget);
    expect(find.byType(AndroidTaskEditor), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Date-only task'), findsOneWidget);
    expect(find.text('Overdue follow-up 0'), findsNothing);
    expect(find.text('Hidden task'), findsOneWidget);
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AndroidScheduleSearchFilters>(
            find.byType(AndroidScheduleSearchFilters),
          )
          .value
          .type,
      ScheduleSearchType.tasks,
    );

    await harness.dispose();
  });

  for (final selected in [true, false]) {
    testWidgets(
      'a validated reminder opens a task with DAV visibility $selected',
      (tester) async {
        final backend = _ReminderTapBackend();
        const account = 'nextcloud:android-editor';
        const list = 'editor-list';
        const task = 'editor-task';
        final day = DateTime.now().toIso8601String().substring(0, 10);
        final alarm = encodeIcalTaskAlarms([
          IcalTaskAlarm.displayAbsolute(
            DateTime.now().toUtc().add(const Duration(minutes: 10)),
          ),
        ]);
        final harness = await _pumpApp(
          tester,
          AppSettings.defaults(),
          notificationBackend: backend,
          seedDatabase: (db) async {
            await _seedAndroidEditorTask(db, due: day);
            await _seedAndroidDavMoveDestination(db, account);
            await (db.update(db.davCollections)
                  ..where((row) => row.id.equals('editor-destination')))
                .write(DavCollectionsCompanion(tasksSelected: Value(selected)));
            await (db.update(
              db.taskLists,
            )..where((row) => row.id.equals(list))).write(
              const TaskListsCompanion(
                davCollectionId: Value('editor-destination'),
              ),
            );
            final projection = (await db.tasksDao.listTasks(
              account,
              list,
            )).single;
            await db.tasksDao.upsertTask(
              projection
                  .toCompanion(true)
                  .copyWith(taskAlarmsJson: Value(alarm)),
            );
            await db.tasksDao.upsertTask(
              projection
                  .toCompanion(true)
                  .copyWith(
                    taskListId: const Value('dav-task-list-editor-destination'),
                    title: const Value('Other task with the same provider ID'),
                    taskAlarmsJson: Value(alarm),
                  ),
            );
            await NotificationScheduleService(database: db)
                .rebuildUpcomingTaskNotifications(account);
          },
        );
        addTearDown(harness.dispose);
        await harness.container
            .read(androidNotificationServiceProvider)
            .initialize(timeZoneId: 'UTC');
        final db = harness.database;
        final row = (await db.select(db.notificationSchedule).get())
            .singleWhere((entry) => entry.id == 'task|$account|$list|$task');
        final items = await harness.container
            .read(scheduleRepositoryProvider)
            .listItems(
              range: ScheduleRange.day(DateTime.now()),
              filters: const ScheduleFilters(
                ignoreDateRange: true,
                includeCalendarEvents: false,
              ),
            );
        expect(items.any((item) => item.title == 'Editable task'), selected);

        final details = find.byKey(
          const ValueKey('android-schedule-details-scroll'),
        );
        backend.tap(row, accountId: 'nextcloud:someone-else');
        await tester.pumpAndSettle();
        expect(details, findsNothing);
        expect(
          find.textContaining('This reminder is no longer available.'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        backend.tap(row);
        await tester.pumpAndSettle();
        expect(details, findsOneWidget);
        expect(
          find.descendant(of: details, matching: find.text('Editable task')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: details,
            matching: find.text('Other task with the same provider ID'),
          ),
          findsNothing,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await db.tasksDao.deleteTask(account, list, task);
        backend.tap(row);
        await tester.pumpAndSettle();
        expect(details, findsNothing);
        expect(
          find.textContaining('This reminder is no longer available.'),
          findsOneWidget,
        );
        await harness.dispose();
      },
    );
  }

  testWidgets('item deep link previews then edits one task in the workspace', (
    tester,
  ) async {
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      populated: true,
    );
    addTearDown(harness.dispose);
    harness.container
        .read(androidWorkspaceRequestProvider.notifier)
        .state = AndroidWorkspaceRequest(
      date: DateTime.now(),
      itemId: 'date-only-task',
      accountId: 'google:populated',
      taskListId: 'visible-list',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('android-schedule-details-scroll')),
      findsOneWidget,
    );
    expect(find.byType(AndroidTaskEditor), findsNothing);
    final details = find.byKey(
      const ValueKey('android-schedule-details-scroll'),
    );
    expect(
      find.descendant(of: details, matching: find.textContaining(' · All day')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: details, matching: find.textContaining('12:00 AM')),
      findsNothing,
    );
    await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
    expect(
      find.byType(AndroidScheduleScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(AndroidTaskEditor, skipOffstage: false), findsOneWidget);

    await harness.dispose();
  });

  testWidgets('event activation leaves all-time task search for its Day view', (
    tester,
  ) async {
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.month,
        taskListScheduleVisibility: {'google:populated::hidden-list': false},
      ),
      seedDatabase: seedScheduleParityStress,
    );
    addTearDown(harness.dispose);
    await _openAndroidScheduleScreen(tester);
    expect(find.byTooltip('Filters'), findsOneWidget);
    harness.container
        .read(androidWorkspaceRequestProvider.notifier)
        .state = AndroidWorkspaceRequest(
      date: DateTime.now().add(const Duration(days: 40)),
      itemId: 'meeting-0',
      accountId: 'google:populated',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('android-schedule-details-scroll')),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Calendars and task lists'), findsOneWidget);
    expect(find.byTooltip('Filters'), findsNothing);
    expect(find.text('Day'), findsOneWidget);
    final settings = harness.container.read(appSettingsControllerProvider);
    expect(settings.androidScheduleViewMode, ScheduleViewMode.day);
    expect(
      settings.taskListScheduleVisibility['google:populated::hidden-list'],
      isFalse,
    );

    await harness.dispose();
  });

  testWidgets('Agenda has a stable heading without date or period paging', (
    tester,
  ) async {
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.month,
      ),
      seedDatabase: seedScheduleParityStress,
    );
    addTearDown(harness.dispose);
    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();
    await harness.container
        .read(appSettingsControllerProvider.notifier)
        .setAndroidScheduleViewMode(ScheduleViewMode.agenda);
    await tester.pumpAndSettle();
    final heading = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Agenda'),
    );
    expect(heading, findsNWidgets(2));
    expect(find.byTooltip('Previous page'), findsNothing);
    expect(find.byTooltip('Next page'), findsNothing);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('Overdue follow-up 0'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets('Month displays task titles and completes a task from its cell', (
    tester,
  ) async {
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.month,
        taskListScheduleVisibility: {'google:populated::hidden-list': false},
      ),
      seedDatabase: (db) async {
        await seedScheduleParityFixture(db);
        await db.delete(db.calendarEvents).go();
      },
    );
    addTearDown(harness.dispose);
    expect(find.text('Date-only task'), findsWidgets);
    final completion = find.byType(Checkbox).first;
    await tester.ensureVisible(completion);
    await tester.pumpAndSettle();
    expect(find.text('Date-only task'), findsWidgets);
    await tester.tap(completion);
    await tester.pumpAndSettle();
    final row = (await harness.database.tasksDao.listTasks(
      'google:populated',
      'visible-list',
    )).single;
    expect(row.status, 'completed');
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets(
    'Year day, week and month controls keep their distinct meanings',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults().copyWith(
          androidScheduleViewMode: ScheduleViewMode.year,
        ),
      );
      addTearDown(harness.dispose);
      final day = DateTime(DateTime.now().year, 1, 14);
      final date = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == DateFormat.yMMMMEEEEd().format(day),
      );
      await tester.ensureVisible(date);
      await tester.pumpAndSettle();
      await tester.tap(date);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('android-day-time-grid')),
        findsOneWidget,
      );
      expect(find.text(localizedDayHeading('en', day)), findsOneWidget);
      await harness.container
          .read(appSettingsControllerProvider.notifier)
          .setAndroidScheduleViewMode(ScheduleViewMode.year);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Week 1').first),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Week 1').first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('android-week-time-grid')),
        findsOneWidget,
      );
      await harness.container
          .read(appSettingsControllerProvider.notifier)
          .setAndroidScheduleViewMode(ScheduleViewMode.year);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, 'January ${DateTime.now().year}').first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('android-month-grid')), findsOneWidget);

      await harness.dispose();
    },
  );

  testWidgets(
    'default task destination and editor changes retain the new draft',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults().copyWith(
          defaultTaskList: const CreationDestination(
            accountId: 'google:populated',
            id: 'hidden-list',
          ),
        ),
        populated: true,
      );
      addTearDown(harness.dispose);
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'New task'));
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      expect(find.widgetWithText(ListTile, 'Hidden tasks'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Retained across destinations',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Hidden tasks'));
      await tester.tap(find.widgetWithText(ListTile, 'Hidden tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visible tasks').last);
      await tester.pumpAndSettle();
      expect(find.text('Retained across destinations'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Visible tasks'), findsOneWidget);
      expect(
        harness.container
            .read(appSettingsControllerProvider)
            .defaultTaskList
            ?.id,
        'hidden-list',
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android event calendar movement queues the supported native move',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        populated: true,
        onCalendarSync: (_) async {},
      );
      addTearDown(harness.dispose);
      final sources = await harness.container.read(
        calendarSourcesStreamProvider.future,
      );
      await (harness.database.update(
        harness.database.calendarEvents,
      )..where((event) => event.id.equals('overnight'))).write(
        const CalendarEventsCompanion(
          organizerJson: Value('{"email":"me@example.com","self":true}'),
          rawJson: Value(
            '{"organizer":{"email":"me@example.com","self":true},"eventType":"default"}',
          ),
        ),
      );
      final detail = await harness.container
          .read(calendarRepositoryProvider)
          .loadEventDetail('overnight');
      expect(detail, isNotNull);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => AndroidEventEditor(
                sources: sources,
                draft: EventEditorDraft.fromEventDetail(detail!),
              ),
            ),
          );
      await tester.pumpAndSettle();
      final calendar = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Calendar',
      );
      expect(
        tester.widget<DropdownButtonFormField<String>>(calendar).onChanged,
        isNotNull,
      );
      tester.widget<DropdownButtonFormField<String>>(calendar).onChanged!(
        'hidden-calendar',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Moved from Android',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidEventEditor), findsNothing);
      final operations = await harness.database
          .select(harness.database.pendingOps)
          .get();
      expect(
        operations.where((op) => op.operationType == 'event.move'),
        hasLength(1),
      );
      final move = jsonDecode(
        operations
            .singleWhere((op) => op.operationType == 'event.move')
            .requestJson,
      ) as Map;
      expect(move.values, contains('hidden-calendar'));
      expect(move.values, contains('send'));

      await harness.dispose();
    },
  );

  testWidgets(
    'Agenda loads additional task buckets and completes checklist steps inline',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults().copyWith(
          androidScheduleViewMode: ScheduleViewMode.agenda,
        ),
        seedDatabase: seedScheduleParityStress,
        taskRepository: (db, id) => TasksRepository(
          database: db,
          accountId: id,
          apiClient: id.startsWith('microsoft:')
              ? _AndroidChecklistClient()
              : null,
        ),
      );
      addTearDown(harness.dispose);
      expect(find.byTooltip('Previous'), findsNothing);
      expect(find.text('Overdue follow-up 0'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Load more overdue tasks'),
        400,
        maxScrolls: 50,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Load more overdue tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more overdue tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Load more overdue tasks'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Load more no-date tasks'),
        400,
        maxScrolls: 50,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Load more no-date tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more no-date tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Load more no-date tasks'), findsNothing);
      final step = find.widgetWithText(ListTile, 'Review task hierarchy');
      await tester.scrollUntilVisible(
        step,
        -400,
        maxScrolls: 40,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position;
      final beforeCompletion = position.pixels;
      await tester.tap(_completionControl(step));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(beforeCompletion, 1));
      expect(tester.widget<Checkbox>(_completionControl(step)).value, isTrue);
      final operations = await harness.database
          .select(harness.database.pendingOps)
          .get();
      expect(
        operations.where((op) => op.operation.contains('checklist')),
        hasLength(1),
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Day scrolling stays inert and a deliberate duration opens the complete event editor',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults().copyWith(
          androidScheduleViewMode: ScheduleViewMode.day,
          defaultCalendar: const CreationDestination(
            accountId: 'google:populated',
            id: 'calendar',
          ),
        ),
        populated: true,
      );
      addTearDown(harness.dispose);
      final interaction = tester.state<ScheduleInteractionRegionState>(
        find.byType(ScheduleInteractionRegion),
      );
      Offset point() {
        final coordinates = interaction.widget.coordinates!,
            planner = coordinates.planner!;
        return coordinates.box!.localToGlobal(
          Offset(
            coordinates.gutterWidth + planner.dayWidth * .55,
            coordinates.gridTop +
                8 +
                2 * 60 * planner.heightPerMinute -
                planner.mainVerticalController.offset,
          ),
        );
      }

      await tester.dragFrom(point(), const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidEventEditor), findsNothing);
      final gesture = await tester.startGesture(point());
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 54));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'New event'), findsNothing);
      final draft = tester
          .widget<AndroidEventEditor>(find.byType(AndroidEventEditor))
          .draft;
      expect(draft.start?.hour, 2);
      expect(draft.start?.minute, 0);
      expect(draft.end!.difference(draft.start!), const Duration(minutes: 60));
      expect(draft.sourceId, 'calendar');

      await harness.dispose();
    },
  );

  testWidgets(
    'compact Android shell retains one workspace and accessible taps',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(AndroidScheduleScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await harness.dispose();
    },
  );

  testWidgets('wide Android workspace keeps sources in dark RTL mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final settings = AppSettings.defaults().copyWith(
      localeTag: 'ar',
      themeModePreference: BusyMaxThemeModePreference.dark,
    );
    final harness = await _pumpApp(tester, settings);
    addTearDown(harness.dispose);

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      Directionality.of(tester.element(find.byType(AndroidHomeShell))),
      TextDirection.rtl,
    );
    expect(
      Theme.of(tester.element(find.byType(AndroidHomeShell))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets(
    'Arabic workspace headings use the Linux locale and date context',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults().copyWith(
          localeTag: 'ar',
          androidScheduleViewMode: ScheduleViewMode.day,
        ),
        seedDatabase: seedScheduleParityStress,
      );
      addTearDown(harness.dispose);
      final selectedDate = tester
          .widget<shared_planner.ScheduleDayWeekView>(
            find.byType(shared_planner.ScheduleDayWeekView),
          )
          .selectedDate;
      final context = tester.element(find.byType(AndroidScheduleScreen));
      final range = ScheduleRange.week(
        selectedDate,
        firstWeekday: BusyMaxWeekPreferencesScope.firstWeekdayOf(context),
      );
      for (final mode in ScheduleViewMode.values) {
        await harness.container
            .read(appSettingsControllerProvider.notifier)
            .setAndroidScheduleViewMode(mode);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(
              localizedScheduleHeading(
                'ar',
                mode,
                range,
                selectedDate,
                agendaLabel: context.l10n.viewAgenda,
              ),
            ),
          ),
          findsWidgets,
          reason: 'The visible $mode title must retain the Linux date context.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('full period title remains reachable at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 500);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.day,
      ),
    );
    addTearDown(harness.dispose);
    final date = tester
        .widget<shared_planner.ScheduleDayWeekView>(
          find.byType(shared_planner.ScheduleDayWeekView),
        )
        .selectedDate;
    final label = localizedDayHeading('en', date);
    expect(find.byTooltip(label), findsOneWidget);
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(label),
    );
    final scroll = tester.state<ScrollableState>(
      find.ancestor(of: title, matching: find.byType(Scrollable)).first,
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byTooltip(label), const Offset(-140, 0));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact shell tolerates 200 percent text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);

    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('Android Settings fits and persists first weekday', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => const AndroidSettingsScreen(
              category: AndroidSettingsCategory.schedule,
            ),
          ),
        );
    await tester.pumpAndSettle();
    final label = find.text('First day of the week');
    await _scrollUntilBuilt(tester, label);
    expect(label, findsOneWidget);
    final dropdown = tester
        .widget<DropdownButton<BusyMaxFirstDayOfWeekPreference>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is DropdownButton<BusyMaxFirstDayOfWeekPreference>,
          ),
        );
    expect(dropdown.isExpanded, isTrue);
    dropdown.onChanged!(BusyMaxFirstDayOfWeekPreference.thursday);
    await tester.pumpAndSettle();
    expect(
      harness.container
          .read(appSettingsControllerProvider)
          .firstDayOfWeekPreference,
      BusyMaxFirstDayOfWeekPreference.thursday,
    );
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('required Android viewport matrix renders every destination', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    const viewports = <(Size, double)>[
      (Size(360, 800), 1),
      (Size(412, 915), 1.3),
      (Size(800, 1280), 2),
      (Size(915, 412), 1.3),
      (Size(320, 500), 2),
    ];

    for (final (size, textScale) in viewports) {
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      tester.binding.handleTextScaleFactorChanged();
      final harness = await _pumpApp(tester, AppSettings.defaults());
      expect(
        tester.takeException(),
        isNull,
        reason:
            'destination 0 at ${size.width}x${size.height} '
            'and text scale $textScale',
      );
      await _openAndroidScheduleScreen(tester);
      expect(tester.takeException(), isNull);
      await _openAndroidSettings(tester);
      expect(tester.takeException(), isNull);
      await harness.dispose();
    }
  });

  testWidgets('populated Android calendar modes render real event data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.day,
        taskListScheduleVisibility: {'google:populated::hidden-list': false},
      ),
      populated: true,
    );
    addTearDown(harness.dispose);
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const ValueKey('schedule-all-day-scroll')), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('schedule-all-day-resize-handle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Date-only task'), findsWidgets);
    expect(find.text('Hidden task'), findsNothing);
    for (final mode in ScheduleViewMode.values) {
      await tester.tap(find.byTooltip('View'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckedPopupMenuItem<ScheduleViewMode> &&
              widget.value == mode,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        harness.container
            .read(appSettingsControllerProvider)
            .androidScheduleViewMode,
        mode,
      );
      expect(tester.takeException(), isNull, reason: mode.name);
    }
    await tester.tap(find.text('Date-only task').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('android-schedule-details-scroll')),
      findsOneWidget,
    );
    expect(find.byTooltip('Edit Task'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
    'period navigation keeps the time grid mounted while destination loads',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final destination = Completer<void>();
      DateTime? initialRangeEnd;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults().copyWith(
          androidScheduleViewMode: ScheduleViewMode.day,
        ),
        populated: true,
        scheduleProjectionCoverage: (range, _) async {
          initialRangeEnd ??= range.end;
          if (range.end != initialRangeEnd) {
            await destination.future;
          }
        },
      );
      addTearDown(harness.dispose);

      final grid = find.byKey(const ValueKey('android-day-time-grid'));
      expect(grid, findsOneWidget);
      final verticalScrollables = find.descendant(
        of: grid,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      final originalScrollable = tester
          .stateList<ScrollableState>(verticalScrollables)
          .reduce(
            (left, right) =>
                left.position.maxScrollExtent > right.position.maxScrollExtent
                ? left
                : right,
          );
      originalScrollable.position.jumpTo(240);
      await tester.pump();
      final originalOffset = originalScrollable.position.pixels;
      expect(originalOffset, greaterThan(0));

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(grid, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .stateList<ScrollableState>(verticalScrollables)
            .any((state) => identical(state, originalScrollable)),
        isTrue,
      );
      expect(originalScrollable.position.pixels, closeTo(originalOffset, .01));

      await tester.pump(const Duration(milliseconds: 180));
      expect(grid, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      destination.complete();
      await tester.pumpAndSettle();
      expect(grid, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .stateList<ScrollableState>(verticalScrollables)
            .any((state) => identical(state, originalScrollable)),
        isTrue,
      );
      expect(originalScrollable.position.pixels, closeTo(originalOffset, .01));

      await harness.dispose();
    },
  );

  testWidgets('Agenda loading hides its empty message until data resolves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final destination = Completer<void>();
    var waiting = false;
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.agenda,
      ),
      seedDatabase: (database) async {
        await _seedPopulatedSchedule(database);
        await database.delete(database.calendarEvents).go();
        await database.delete(database.tasks).go();
      },
      scheduleProjectionCoverage: (range, _) async {
        if (waiting) {
          await destination.future;
        }
      },
    );
    addTearDown(harness.dispose);

    expect(find.text('No events, tasks, or journal entries'), findsOneWidget);
    waiting = true;
    await tester.tap(find.byKey(const ValueKey('android-workspace-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No events, tasks, or journal entries'), findsNothing);

    destination.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No events, tasks, or journal entries'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
    'long schedule details remain scrollable across constrained viewports',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const viewports = [
        (Size(412, 915), 1.0, 'phone'),
        (Size(700, 320), 1.0, 'short landscape'),
        (Size(390, 844), 2.0, 'enlarged text'),
      ];

      for (final (size, textScale, label) in viewports) {
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        tester.binding.handleMetricsChanged();
        tester.binding.handleTextScaleFactorChanged();
        final harness = await _pumpApp(
          tester,
          AppSettings.defaults().copyWith(
            androidScheduleViewMode: ScheduleViewMode.day,
          ),
          populated: true,
        );
        try {
          await _openAndroidScheduleScreen(tester);
          final task = find.text('Date-only task');
          await _scrollUntilBuilt(tester, task);
          await tester.ensureVisible(task);
          await tester.tap(task);
          await tester.pumpAndSettle();

          final details = find.byKey(
            const ValueKey('android-schedule-details-scroll'),
          );
          final edit = find.byTooltip('Edit Task');
          expect(details, findsOneWidget, reason: label);
          expect(find.text(_longScheduleDetailsNotes), findsOneWidget);
          expect(edit, findsOneWidget, reason: label);
          await tester.ensureVisible(edit);
          await tester.pumpAndSettle();
          expect(edit.hitTestable(), findsOneWidget, reason: label);
          expect(tester.takeException(), isNull, reason: label);
        } finally {
          await harness.dispose();
        }
      }
    },
  );

  testWidgets('Android invitation response queues the provider payload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var syncRequests = 0;
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.day,
      ),
      populated: true,
      onCalendarSync: (_) async => syncRequests += 1,
    );
    addTearDown(harness.dispose);

    await _openAndroidItemSearch(tester, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invitation event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );

    final event = await (harness.database.select(
      harness.database.calendarEvents,
    )..where((row) => row.id.equals('invitation'))).getSingle();
    final attendees = jsonDecode(event.attendeesJson!) as List<Object?>;
    expect((attendees.single as Map)['responseStatus'], 'accepted');
    final operation = await harness.database
        .select(harness.database.pendingOps)
        .getSingle();
    expect(operation.operationType, 'event.respond');
    expect(jsonDecode(operation.requestJson), {
      'response': 'accept',
      'attendeeEmail': 'me@example.com',
      'sendResponse': true,
    });
    expect(syncRequests, 1);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('read-only Android invitation shows details and meeting access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.day,
      ),
      populated: true,
    );
    addTearDown(harness.dispose);
    await (harness.database.update(harness.database.calendarSources)
          ..where((row) => row.id.equals('calendar')))
        .write(const CalendarSourcesCompanion(readOnly: Value(true)));
    await (harness.database.update(
      harness.database.calendarEvents,
    )..where((row) => row.id.equals('invitation'))).write(
      const CalendarEventsCompanion(
        description: Value('Agenda and notes'),
        startTimeZone: Value('Pacific/Honolulu'),
        endTimeZone: Value('Asia/Tokyo'),
        rawJson: Value('{"hangoutLink":"https://meet.google.com/room"}'),
        webLink: Value('https://calendar.google.com/event'),
        attachmentsJson: Value(
          '[{"fileUrl":"https://drive.example/agenda",'
          '"title":"Agenda attachment"}]',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openAndroidItemSearch(tester, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invitation event'));
    await tester.pumpAndSettle();
    expect(find.text('Agenda and notes'), findsOneWidget);
    expect(find.text('Organizer: organizer@example.com'), findsOneWidget);
    expect(find.text('Join meeting'), findsOneWidget);
    expect(find.textContaining('Pacific/Honolulu'), findsNothing);
    expect(find.textContaining('Asia/Tokyo'), findsNothing);
    expect(find.text('Event link'), findsOneWidget);
    expect(find.text('Agenda attachment'), findsOneWidget);
    expect(find.text('Edit Event'), findsNothing);
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    messenger.setMockMethodCallHandler(launcherChannel, (_) async => false);
    addTearDown(
      () => messenger.setMockMethodCallHandler(launcherChannel, null),
    );
    await tester.tap(find.text('Join meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the meeting link.'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets(
    'Android recurring event export chooses occurrence or authoritative series',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateTime.now();
      final day =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final next = today.add(const Duration(days: 1));
      final nextDay =
          '${next.year.toString().padLeft(4, '0')}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
      final master = <String, Object?>{
        'id': 'invitation',
        'iCalUID': 'series@example.test',
        'summary': 'Invitation event',
        'start': {'date': day},
        'end': {'date': nextDay},
        'recurrence': ['RRULE:FREQ=DAILY;COUNT=2'],
        'reminders': {'useDefault': false, 'overrides': <Object>[]},
      };
      final client = GoogleCalendarApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/events/invitation')) {
            return http.Response(jsonEncode(master), 200);
          }
          if (request.url.path.endsWith('/events')) {
            expect(request.url.queryParameters['showDeleted'], 'true');
            return http.Response(
              jsonEncode({
                'items': [master],
              }),
              200,
            );
          }
          return http.Response('unexpected export request', 404);
        }),
        baseUri: Uri.parse('https://www.googleapis.com'),
      );
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults().copyWith(
          androidScheduleViewMode: ScheduleViewMode.day,
        ),
        populated: true,
        googleSharingClient: client,
      );
      addTearDown(harness.dispose);
      await (harness.database.update(
        harness.database.calendarEvents,
      )..where((row) => row.id.equals('invitation'))).write(
        const CalendarEventsCompanion(
          recurrenceJson: Value('["RRULE:FREQ=DAILY;COUNT=2"]'),
        ),
      );
      await tester.pumpAndSettle();
      await _openAndroidItemSearch(tester, '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invitation event'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Export'));
      await tester.pumpAndSettle();
      expect(find.text('This event'), findsOneWidget);
      expect(find.text('Entire series'), findsOneWidget);
      String? exported;
      messenger.setMockMethodCallHandler(platformChannel, (call) async {
        if (call.method == 'createDocument') {
          final args = (call.arguments as Map).cast<String, Object?>();
          exported = utf8.decode((args['bytes'] as List).cast<int>());
          return 'content://test/export.ics';
        }
        return null;
      });
      await tester.tap(find.text('Entire series'));
      await tester.pumpAndSettle();
      expect(exported, contains('UID:series@example.test'));
      expect(exported, contains('RRULE:FREQ=DAILY;COUNT=2'));
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  testWidgets('Android timed detail labels projected local time correctly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.day,
        timeFormatPreference: BusyMaxTimeFormatPreference.twentyFourHour,
      ),
      populated: true,
      localTimeZone: 'Etc/UTC',
    );
    addTearDown(harness.dispose);
    final today = DateTime.now();
    final noon = DateTime(today.year, today.month, today.day, 12).toUtc();
    await (harness.database.update(
      harness.database.calendarEvents,
    )..where((row) => row.id.equals('overnight'))).write(
      CalendarEventsCompanion(
        startDateTime: Value(noon.toIso8601String()),
        endDateTime: Value(
          noon.add(const Duration(hours: 1)).toIso8601String(),
        ),
        startTimeZone: const Value('Pacific/Honolulu'),
        endTimeZone: const Value('Asia/Tokyo'),
      ),
    );
    await tester.pumpAndSettle();
    final eventLabel = find
        .textContaining('Overnight event')
        .hitTestable()
        .first;
    final label = find.textContaining('Overnight event').first;
    await tester.ensureVisible(label);
    await tester.pumpAndSettle();
    await tester.tap(eventLabel);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final details = find.byKey(
      const ValueKey('android-schedule-details-scroll'),
    );
    expect(
      details,
      findsOneWidget,
      reason: 'the detail sheet opened before timezone assertions',
    );
    await tester.drag(details, const Offset(0, -250));
    await tester.pumpAndSettle();
    final localNoon = noon.toLocal();
    final expectedZone = localNoon.timeZoneOffset == Duration.zero
        ? ' · UTC'
        : localNoon.timeZoneName.trim();
    expect(
      find.descendant(of: details, matching: find.textContaining(expectedZone)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: details,
        matching: find.textContaining(
          '${localNoon.hour.toString().padLeft(2, '0')}:00',
        ),
      ),
      findsWidgets,
      reason: find
          .descendant(of: details, matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .join(' | '),
    );
    expect(find.textContaining('Pacific/Honolulu'), findsNothing);
    expect(find.textContaining('Asia/Tokyo'), findsNothing);

    await harness.dispose();
  });

  testWidgets('notification event with no writable source opens read-only', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    final now = DateTime.now();

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidEventEditor(
              sources: const [],
              draft: EventEditorDraft.existing(
                eventId: 'read-only-event',
                accountId: 'webcal:read-only',
                sourceId: 'read-only-source',
                providerCalendarId: 'read-only-source',
                title: 'Read-only event',
                allDay: false,
                start: now,
                end: now.add(const Duration(hours: 1)),
              ),
            ),
          ),
        );
    await tester.pumpAndSettle();

    final save = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(save.onPressed, isNull);
    expect(find.text('Read-only event'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets(
    'Google event editor exposes guest availability with an error path',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final now = DateTime.now();
      const source = CalendarSourceEntity(
        id: 'calendar',
        accountId: 'google:editable',
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        summary: 'Editable calendar',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
      );
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => AndroidEventEditor(
                sources: const [source],
                draft: EventEditorDraft.existing(
                  eventId: 'availability-event',
                  accountId: source.accountId,
                  sourceId: source.id,
                  providerCalendarId: source.providerCalendarId,
                  title: 'Availability event',
                  allDay: false,
                  start: now,
                  end: now.add(const Duration(hours: 1)),
                  attendees: const [
                    EventAttendeeDraft(email: 'guest@example.com'),
                  ],
                ),
              ),
            ),
          );
      await tester.pumpAndSettle();
      final action = find.text('Check guest availability');
      await _scrollUntilBuilt(tester, action);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.byType(AndroidGuestAvailabilityDialog), findsOneWidget);
      expect(
        find.textContaining('Availability is unavailable'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await harness.dispose();
    },
  );

  testWidgets(
    'Google guest availability shows failures and missing results as unknown',
    (tester) async {
      final client = GoogleCalendarApiClient(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'calendars': {
                'free@example.com': {'busy': <Object?>[]},
                'failed@example.com': {
                  'errors': [
                    {'domain': 'global', 'reason': 'notFound'},
                  ],
                  'busy': <Object?>[],
                },
              },
            }),
            200,
            headers: {'Content-Type': 'application/json'},
          ),
        ),
        baseUri: Uri.parse('https://www.googleapis.com'),
        authorizationHeaderProvider: () async => 'Bearer token',
      );
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        calendarClient: client,
      );
      addTearDown(harness.dispose);
      final now = DateTime.now();
      const source = CalendarSourceEntity(
        id: 'calendar',
        accountId: 'google:editable',
        provider: BusyProvider.google,
        providerCalendarId: 'calendar',
        summary: 'Editable calendar',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
      );
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => AndroidEventEditor(
                sources: const [source],
                draft: EventEditorDraft.existing(
                  eventId: 'availability-event',
                  accountId: source.accountId,
                  sourceId: source.id,
                  providerCalendarId: source.providerCalendarId,
                  title: 'Availability event',
                  allDay: false,
                  start: now,
                  end: now.add(const Duration(hours: 1)),
                  attendees: const [
                    EventAttendeeDraft(email: 'free@example.com'),
                    EventAttendeeDraft(email: 'failed@example.com'),
                    EventAttendeeDraft(email: 'missing@example.com'),
                  ],
                ),
              ),
            ),
          );
      await tester.pumpAndSettle();
      final action = find.text('Check guest availability');
      await _scrollUntilBuilt(tester, action);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(
        find.text('No busy periods reported for this interval'),
        findsOneWidget,
      );
      expect(find.text('Availability unknown'), findsNWidgets(2));
      final dialog = find.byType(AndroidGuestAvailabilityDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('free@example.com')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('failed@example.com')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('missing@example.com')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await harness.dispose();
    },
  );

  testWidgets('C Android Google availability resolves event wall time', (
    tester,
  ) async {
    Map<String, dynamic>? requestBody;
    final client = GoogleCalendarApiClient(
      httpClient: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'calendars': {
              'guest@example.com': {'busy': <Object>[]},
            },
          }),
          200,
        );
      }),
      baseUri: Uri.parse('https://www.googleapis.com'),
      authorizationHeaderProvider: () async => 'Bearer token',
    );
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      calendarClient: client,
    );
    addTearDown(harness.dispose);
    final draft = EventEditorDraft.existing(
      eventId: 'event',
      accountId: 'google:editable',
      sourceId: 'calendar',
      providerCalendarId: 'calendar',
      title: 'Meeting',
      allDay: false,
      start: DateTime(2026, 7, 15, 9),
      end: DateTime(2026, 7, 15, 10),
      startTimeZone: 'America/Los_Angeles',
      endTimeZone: 'America/Los_Angeles',
      attendees: const [EventAttendeeDraft(email: 'guest@example.com')],
    );
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAndroidGuestAvailabilityDialog(
              context,
              accountId: draft.accountId,
              provider: BusyProvider.google,
              draft: draft,
            ),
            child: const Text('Open availability'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open availability'));
    await tester.pumpAndSettle();
    expect(requestBody?['timeMin'], '2026-07-15T16:00:00.000Z');
    expect(requestBody?['timeMax'], '2026-07-15T17:00:00.000Z');

    await harness.dispose();
  });

  testWidgets('Google all-day availability uses selected calendar timezone', (
    tester,
  ) async {
    Map<String, dynamic>? requestBody;
    late EventEditorDraft draft;
    late String calendarTimeZone;
    final client = GoogleCalendarApiClient(
      httpClient: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'calendars': {
              'guest@example.com': {'busy': <Object>[]},
            },
          }),
          200,
        );
      }),
      baseUri: Uri.parse('https://www.googleapis.com'),
      authorizationHeaderProvider: () async => 'Bearer token',
    );
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      calendarClient: client,
      seedDatabase: (database) async {
        await database
            .into(database.accounts)
            .insert(
              AccountsCompanion.insert(
                id: 'google:editable',
                provider: 'google',
                authority: 'https://accounts.google.com',
                providerAccountId: 'me@example.com',
                credentialKind: 'oauth',
                authState: const Value('signed_in'),
                createdAtUtc: '2026-07-01T00:00:00Z',
                updatedAtUtc: '2026-07-01T00:00:00Z',
              ),
            );
        final repository = CalendarRepository(database: database);
        await repository.upsertSource(
          accountId: 'google:editable',
          source: const CalendarSourceDto(
            provider: BusyProvider.google,
            providerCalendarId: 'calendar',
            summary: 'Tokyo',
            timeZone: 'Asia/Tokyo',
            accessRole: 'owner',
          ),
        );
        await repository.upsertEvent(
          accountId: 'google:editable',
          event: const CalendarEventDto(
            provider: BusyProvider.google,
            providerCalendarId: 'calendar',
            providerEventId: 'all-day',
            title: 'All day',
            allDay: true,
            startDate: '2026-07-15',
            endDate: '2026-07-16',
            attendeesJson: [
              {'email': 'guest@example.com'},
            ],
          ),
        );
        final detail = await repository.loadEventDetail(
          (await database.select(database.calendarEvents).getSingle()).id,
        );
        draft = EventEditorDraft.fromEventDetail(detail!);
        calendarTimeZone = CalendarSourceEntity.fromRow(
          await database.select(database.calendarSources).getSingle(),
        ).timeZone!;
      },
    );
    addTearDown(harness.dispose);
    expect(draft.startTimeZone, isNull);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAndroidGuestAvailabilityDialog(
              context,
              accountId: draft.accountId,
              provider: BusyProvider.google,
              draft: draft,
              calendarTimeZone: calendarTimeZone,
            ),
            child: const Text('Open availability'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open availability'));
    await tester.pumpAndSettle();
    expect(requestBody?['timeMin'], '2026-07-14T15:00:00.000Z');
    expect(requestBody?['timeMax'], '2026-07-15T15:00:00.000Z');

    await harness.dispose();
  });

  testWidgets('Microsoft guest availability preserves mixed results', (
    tester,
  ) async {
    final client = MicrosoftCalendarApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'value': [
              {'scheduleId': 'free@example.com', 'scheduleItems': []},
              {
                'scheduleId': 'denied@example.com',
                'error': {'responseCode': '5003', 'message': 'No access'},
              },
            ],
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        ),
      ),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      responseTimeZone: 'UTC',
      accountTenantId: '11111111-2222-4333-8444-555555555555',
      authorizationHeaderProvider: () async => 'Bearer test-token',
    );
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      calendarClient: client,
    );
    addTearDown(harness.dispose);
    await harness.database
        .into(harness.database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'microsoft:editable',
            provider: 'microsoft',
            authority: 'https://login.microsoftonline.com/common',
            providerAccountId: 'editable',
            credentialKind: 'oauth',
            authState: const Value('signed_in'),
            tenantId: const Value('11111111-2222-4333-8444-555555555555'),
            createdAtUtc: '2026-09-14T00:00:00.000Z',
            updatedAtUtc: '2026-09-14T00:00:00.000Z',
          ),
        );
    await tester.pumpAndSettle();
    final now = DateTime.now();
    const source = CalendarSourceEntity(
      id: 'calendar',
      accountId: 'microsoft:editable',
      provider: BusyProvider.microsoft,
      providerCalendarId: 'calendar',
      summary: 'Editable calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidEventEditor(
              sources: const [source],
              draft: EventEditorDraft.existing(
                eventId: 'availability-event',
                accountId: source.accountId,
                sourceId: source.id,
                providerCalendarId: source.providerCalendarId,
                title: 'Availability event',
                allDay: false,
                start: now,
                end: now.add(const Duration(hours: 1)),
                attendees: const [
                  EventAttendeeDraft(email: 'free@example.com'),
                  EventAttendeeDraft(email: 'denied@example.com'),
                  EventAttendeeDraft(email: 'missing@example.com'),
                ],
              ),
            ),
          ),
        );
    await tester.pumpAndSettle();
    final action = find.text('Check guest availability');
    await _scrollUntilBuilt(tester, action);
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();
    await _pumpAndSettleGraphIo(tester);
    expect(
      find.text('No busy periods reported for this interval'),
      findsOneWidget,
    );
    expect(find.text('Availability unknown'), findsNWidgets(2));
    final dialog = find.byType(AndroidGuestAvailabilityDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('denied@example.com')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('missing@example.com')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('Android Settings exposes diagnostics and feedback routes', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'BusyMax',
      packageName: 'io.busystack.busymax',
      version: '0.2.4',
      buildNumber: '4',
      buildSignature: '',
    );
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    await _openAndroidSettings(tester);
    await tester.pumpAndSettle();

    final nextcloud = find.text('Add Nextcloud account');
    await _scrollUntilBuilt(tester, nextcloud);
    await tester.tap(nextcloud);
    await tester.pumpAndSettle();
    expect(find.text('Set up Nextcloud'), findsOneWidget);
    expect(find.text('Connect Nextcloud'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    final apple = find.text('Add Apple iCloud Calendar account');
    await _scrollUntilBuilt(tester, apple);
    await tester.tap(apple);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Apple Account email'),
      'qa@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'App-specific password'),
      'test-password',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => const AndroidSettingsScreen(
              category: AndroidSettingsCategory.diagnostics,
            ),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.byType(AndroidDiagnosticsScreen), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('android-workspace-menu')));
    await tester.pumpAndSettle();
    final about = find.text('About BusyMax');
    await _scrollUntilBuilt(tester, about);
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(find.text('0.2.4'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AboutDialog),
        matching: find.textContaining('+'),
      ),
      findsNothing,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('android-workspace-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send feedback').last);
    await tester.pumpAndSettle();
    expect(find.byType(AndroidFeedbackScreen), findsOneWidget);
    expect(find.text('Detailed message'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('read-only task disables save and omits delete', (tester) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    const task = TaskEntity(
      accountId: 'webcal:read-only',
      taskListId: 'read-only-list',
      id: 'read-only-task',
      title: 'Read-only task',
      localDirty: false,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      updatedLocalAtUtc: '2026-09-14T00:00:00.000Z',
    );

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => const AndroidTaskEditor(
              accountId: 'webcal:read-only',
              provider: BusyProvider.webCal,
              task: task,
              accountLabel: 'Read-only account',
              listLabel: 'Read-only list',
            ),
          ),
        );
    await tester.pumpAndSettle();

    final save = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(save.onPressed, isNull);
    expect(find.text('Delete task'), findsNothing);
    expect(find.text('Read-only list'), findsOneWidget);
    expect(find.text('Read-only list'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('assigned task deletion warns and cancellation changes nothing', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    const task = TaskEntity(
      accountId: 'google:assigned',
      taskListId: 'assigned-list',
      id: 'assigned-task',
      title: 'Assigned task',
      localDirty: false,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      assignmentInfoJson: '{"surfaceType":"DOCUMENT","linkToTask":"https://docs.google.com/document/d/example"}',
      updatedLocalAtUtc: '2026-09-14T00:00:00.000Z',
    );
    var mutationStarted = false;
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidTaskEditor(
              accountId: task.accountId,
              provider: BusyProvider.google,
              task: task,
              accountLabel: 'Assigned account',
              listLabel: 'Assigned list',
              onMutationStarted: (_) => mutationStarted = true,
            ),
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('Open in provider'), findsOneWidget);
    expect(
      find.text('https://docs.google.com/document/d/example'),
      findsOneWidget,
    );
    final editorList = find.descendant(
      of: find.byType(AndroidTaskEditor),
      matching: find.byType(ListView),
    );
    for (
      var step = 0;
      step < 40 && find.text('Delete Task').evaluate().isEmpty;
      step++
    ) {
      await tester.drag(editorList, const Offset(0, -400));
      await tester.pump();
    }
    expect(find.text('Delete Task'), findsOneWidget);
    await tester.ensureVisible(find.text('Delete Task'));
    await tester.tap(find.text('Delete Task'));
    await tester.pumpAndSettle();
    expect(find.textContaining('original task'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(mutationStarted, isFalse);
    expect(find.byType(AndroidTaskEditor), findsOneWidget);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets(
    'Microsoft task linked resources load only after opening detail',
    (tester) async {
      var requests = 0;
      final todoClient = MicrosoftTodoRestApiClient(
        httpClient: MockClient((request) async {
          requests++;
          if (request.url.path.endsWith('/attachments')) {
            return http.Response(
              jsonEncode({
                'value': [
                  {
                    'id': 'attachment-1',
                    'name': 'Notes.txt',
                    'size': 12,
                    '@odata.type': '#microsoft.graph.taskFileAttachment',
                  },
                ],
              }),
              200,
            );
          }
          expect(
            request.url.path,
            '/v1.0/me/todo/lists/list-1/tasks/task-1/linkedResources',
          );
          return http.Response(
            jsonEncode({
              'value': [
                {
                  'id': 'resource-1',
                  'applicationName': 'Planner',
                  'displayName': 'Launch plan',
                  'webUrl': 'https://example.test/plan',
                },
                {
                  'id': 'resource-2',
                  'applicationName': 'Outlook',
                  'displayName': 'Message',
                  'webUrl': 'javascript:alert(1)',
                },
              ],
            }),
            200,
          );
        }),
        baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
        authorizationHeaderProvider: () async => 'Bearer token',
      );
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        todoClient: todoClient,
      );
      addTearDown(harness.dispose);
      const task = TaskEntity(
        accountId: 'microsoft:account',
        taskListId: 'list-1',
        id: 'task-1',
        title: 'Task',
        localDirty: false,
        pendingDelete: false,
        pendingMove: false,
        rawJson: '{}',
        updatedLocalAtUtc: '2026-09-14T00:00:00.000Z',
      );
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => const AndroidTaskEditor(
                accountId: 'microsoft:account',
                provider: BusyProvider.microsoft,
                task: task,
              ),
            ),
          );
      await tester.pumpAndSettle();
      expect(requests, 0);
      await tester.tap(find.text('Linked resources'));
      await _pumpAndSettleGraphIo(tester);
      expect(requests, 1);
      expect(find.text('Launch plan · Planner'), findsOneWidget);
      expect(find.text('Message · Outlook'), findsNothing);
      await tester.tap(find.byKey(const Key('task-attachments-load')));
      await _pumpAndSettleGraphIo(tester);
      expect(requests, 2);
      expect(find.text('Notes.txt'), findsOneWidget);
      expect(find.text('Task'), findsWidgets);
      expect(tester.takeException(), isNull);

      await harness.dispose();
    },
  );

  testWidgets('Android task detail keeps an uncertain upload blocked', (
    tester,
  ) async {
    var posts = 0;
    final todoClient = MicrosoftTodoRestApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'value': []}), 200);
        }
        posts++;
        throw http.ClientException('direct response lost');
      }),
      baseUri: Uri.parse('https://graph.microsoft.com/v1.0'),
      authorizationHeaderProvider: () async => 'Bearer token',
    );
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      todoClient: todoClient,
    );
    addTearDown(harness.dispose);
    final coordinator = harness.container.read(
      attachmentUploadCoordinatorProvider,
    );
    const accountId = 'microsoft:account';
    const taskListId = 'list-1';
    const taskId = 'task-1';
    final key = AttachmentUploadCoordinator.taskKey(
      accountId,
      taskListId,
      taskId,
    );
    await tester.runAsync(
      () => expectLater(
        coordinator.uploadTask(
          client: todoClient,
          accountId: accountId,
          taskListId: taskListId,
          taskId: taskId,
          name: 'notes.txt',
          contentType: 'text/plain',
          bytes: [1],
        ),
        throwsA(isA<AttachmentUploadUnresolvedException>()),
      ),
    );
    expect(
      await tester.runAsync(
        () => coordinator.reconcileTask(
          client: todoClient,
          accountId: accountId,
          taskListId: taskListId,
          taskId: taskId,
        ),
      ),
      AttachmentUploadStatus.unresolved,
    );
    const task = TaskEntity(
      accountId: accountId,
      taskListId: taskListId,
      id: taskId,
      title: 'Task',
      localDirty: false,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      updatedLocalAtUtc: '2026-09-14T00:00:00.000Z',
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => const AndroidTaskEditor(
              accountId: accountId,
              provider: BusyProvider.microsoft,
              task: task,
            ),
          ),
        );
    await tester.pumpAndSettle();
    expect(coordinator.canSubmit(key), isFalse);
    final retry = find.text('Retry');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(coordinator.canSubmit(key), isFalse);
    expect(posts, 1);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(coordinator.canSubmit(key), isFalse);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('modified Android event requires discard confirmation', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    final now = DateTime.now();
    const source = CalendarSourceEntity(
      id: 'calendar',
      accountId: 'google:editable',
      provider: BusyProvider.google,
      providerCalendarId: 'calendar',
      summary: 'Editable calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidEventEditor(
              sources: const [source],
              draft: EventEditorDraft.existing(
                eventId: 'editable-event',
                accountId: source.accountId,
                sourceId: source.id,
                providerCalendarId: source.providerCalendarId,
                title: 'Original title',
                allDay: false,
                start: now,
                end: now.add(const Duration(hours: 1)),
              ),
            ),
          ),
        );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Changed title');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Changed title'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(AndroidEventEditor), findsNothing);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('modified Android task requires discard confirmation', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    const task = TaskEntity(
      accountId: 'google:editable',
      taskListId: 'editable-list',
      id: 'editable-task',
      title: 'Original task',
      localDirty: false,
      pendingDelete: false,
      pendingMove: false,
      rawJson: '{}',
      updatedLocalAtUtc: '2026-09-14T00:00:00.000Z',
    );

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => const AndroidTaskEditor(
              accountId: 'google:editable',
              provider: BusyProvider.google,
              task: task,
              accountLabel: 'Editable account',
              listLabel: 'Editable list',
            ),
          ),
        );
    await tester.pumpAndSettle();

    final editorTextFields = find.descendant(
      of: find.byType(AndroidTaskEditor),
      matching: find.byType(TextField),
    );
    await tester.enterText(editorTextFields.first, 'Changed task');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Changed task'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(AndroidTaskEditor), findsNothing);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  for (final (label, fieldIndex) in const [
    ('Location', 1),
    ('Description', 2),
    ('Guests', 3),
    ('Categories', 4),
  ]) {
    testWidgets('system Back protects event $label edits', (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final now = DateTime.now();
      final source = CalendarSourceEntity(
        id: 'calendar',
        accountId: 'google:editable',
        provider: label == 'Categories'
            ? BusyProvider.microsoft
            : BusyProvider.google,
        providerCalendarId: 'calendar',
        summary: 'Editable calendar',
        selected: true,
        hidden: false,
        readOnly: false,
        isDeleted: false,
      );
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => AndroidEventEditor(
                sources: [source],
                draft: EventEditorDraft.existing(
                  eventId: 'event-$fieldIndex',
                  accountId: source.accountId,
                  sourceId: source.id,
                  providerCalendarId: source.providerCalendarId,
                  title: 'System Back event',
                  allDay: false,
                  start: now,
                  end: now.add(const Duration(hours: 1)),
                ),
              ),
            ),
          );
      await tester.pumpAndSettle();

      late Finder field;
      final editedValue = label == 'Guests'
          ? 'edited@example.test'
          : 'Edited $label';
      if (label == 'Categories') {
        await _setAndroidCategories(tester, [editedValue]);
        field = find.byType(AndroidCategoryEditor);
      } else if (label == 'Guests') {
        final add = find.widgetWithText(TextButton, 'Add Guest');
        await _scrollUntilBuilt(tester, add);
        await tester.tap(add);
        await tester.pumpAndSettle();
        field = find.widgetWithText(TextField, 'Add guest email');
        await tester.enterText(field, editedValue);
        await tester.tap(find.widgetWithText(TextButton, 'Add Guest').last);
        await tester.pumpAndSettle();
        field = find.byKey(
          const ValueKey('android-event-guest-edited@example.test'),
        );
      } else {
        final labelText = find.descendant(
          of: find.byType(AndroidEventEditor),
          matching: find.text(label),
        );
        await _scrollUntilBuilt(tester, labelText);
        field = find.ancestor(
          of: labelText,
          matching: label == 'Description'
              ? find.byType(TextField)
              : find.byType(TextFormField),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, editedValue);
      }
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidEventEditor), findsOneWidget);
      expect(
        find.descendant(of: field, matching: find.text(editedValue)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await harness.dispose();

      await harness.dispose();
    });
  }

  for (final label in const [
    'Title',
    'Notes',
    'Categories',
    'Location',
    'URL',
  ]) {
    testWidgets('system Back protects task $label edits', (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      const task = TaskEntity(
        accountId: 'nextcloud:editable',
        taskListId: 'editable-list',
        id: 'editable-task',
        title: 'System Back task',
        localDirty: false,
        pendingDelete: false,
        pendingMove: false,
        rawJson: '{}',
        updatedLocalAtUtc: '2026-09-14T00:00:00.000Z',
      );
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => const AndroidTaskEditor(
                accountId: 'nextcloud:editable',
                provider: BusyProvider.nextcloud,
                task: task,
                accountLabel: 'Editable account',
                listLabel: 'Editable list',
              ),
            ),
          );
      await tester.pumpAndSettle();

      if (label == 'Categories') {
        await _setAndroidCategories(tester, ['Edited $label']);
      } else {
        final field = find.widgetWithText(TextField, label);
        await _scrollUntilBuilt(tester, field);
        await tester.enterText(field, 'Edited $label');
      }
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsOneWidget);
      expect(find.text('Edited $label'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await harness.dispose();
    });
  }

  for (final kind in ['event', 'task']) {
    for (final synchronized in [false, true]) {
      testWidgets(
        'Android suppresses a committed $kind recovery after failed cleanup '
        '(synchronized: $synchronized)',
        (tester) async {
          final directory = Directory.systemTemp.createTempSync(
            'busymax-create-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final file = File('${directory.path}/busymax.sqlite');
          AppDatabase openDatabase() => AppDatabase(
            DatabaseConnection(
              NativeDatabase(file),
              closeStreamsSynchronously: true,
            ),
          );
          final event = kind == 'event';
          final accountId = event ? 'google:administration' : 'google:move';
          final title = 'Recovered $kind';
          final source = CalendarSourceEntity(
            id: CalendarRepository.sourceId(
              accountId: 'google:administration',
              provider: BusyProvider.google,
              providerCalendarId: 'administration-calendar',
            ),
            accountId: 'google:administration',
            provider: BusyProvider.google,
            providerCalendarId: 'administration-calendar',
            summary: 'Administration calendar',
            selected: true,
            hidden: false,
            readOnly: false,
            isDeleted: false,
          );
          final harness = await _pumpApp(
            tester,
            AppSettings.defaults(),
            databaseOverride: openDatabase(),
            seedDatabase: event
                ? (db) => _seedCalendarAdministration(db, sourceId: source.id)
                : _seedMovableTask,
            onCalendarSync: (_) async {},
          );
          addTearDown(harness.dispose);
          final eventDraft = EventEditorDraft.newEvent(
            accountId: source.accountId,
            sourceId: source.id,
            providerCalendarId: source.providerCalendarId,
            start: DateTime(2026, 9, 14, 9),
            end: DateTime(2026, 9, 14, 10),
          );
          const taskEditor = AndroidTaskEditor(
            accountId: 'google:move',
            provider: BusyProvider.google,
            creationList: TaskListEntity(
              accountId: 'google:move',
              id: 'source-list',
              title: 'Source list',
              localDirty: false,
              pendingDelete: false,
              rawJson: '{}',
            ),
            accountLabel: 'Move account',
            listLabel: 'Source list',
          );
          final editor = find.byType(
            event ? AndroidEventEditor : AndroidTaskEditor,
          );
          final save = find.widgetWithText(TextButton, 'Save');
          Future<void> openEditor() async {
            unawaited(
              tester
                  .state<NavigatorState>(find.byType(Navigator).first)
                  .push<void>(
                    MaterialPageRoute(
                      builder: (_) => event
                          ? AndroidEventEditor(
                              sources: [source],
                              draft: eventDraft,
                            )
                          : taskEditor,
                    ),
                  ),
            );
            await tester.pumpAndSettle();
            expect(editor, findsOneWidget);
          }

          Future<void> expectSingleCreation(
            AppDatabase database,
            int outboxCount,
          ) async {
            if (event) {
              expect(
                await (database.select(
                  database.calendarEvents,
                )..where((row) => row.title.equals(title))).get(),
                hasLength(1),
              );
            } else {
              expect(
                await (database.select(
                  database.tasks,
                )..where((row) => row.title.equals(title))).get(),
                hasLength(1),
              );
            }
            expect(
              await database.select(database.pendingOps).get(),
              hasLength(outboxCount),
            );
          }

          await openEditor();
          final titleField = event
              ? find.byType(TextFormField).first
              : find.widgetWithText(TextField, 'Title');
          await tester.enterText(titleField, title);
          await tester.pump(const Duration(milliseconds: 1100));
          await tester.pumpAndSettle();
          final recovery = secureStorage.entries.singleWhere(
            (entry) => entry.key.startsWith('busymax.android.$kind-draft.'),
          );
          final id =
              (jsonDecode(recovery.value) as Map)['creationId'] as String;
          expect(id, isNotEmpty);

          // Restore the persisted draft before saving, so this exercises the
          // actual recovery binding and its submitted identity.
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator).first,
          );
          navigator.removeRoute(ModalRoute.of(tester.element(editor))!);
          await tester.pumpAndSettle();
          await openEditor();
          await tester.tap(find.text('Restore'));
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
          remainingRecoveryDeletesFail = true;
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(editor, findsNothing);
          expect(secureStorage, contains(recovery.key));
          await expectSingleCreation(harness.database, 1);

          if (synchronized) {
            if (event) {
              final client = GoogleCalendarApiClient(
                baseUri: Uri.parse('https://www.googleapis.com'),
                httpClient: MockClient((request) async {
                  expect(request.method, 'POST');
                  return http.Response(request.body, 200);
                }),
              );
              final replayed = await CalendarPendingOpsReplayer(
                database: harness.database,
                client: client,
                accountId: accountId,
              ).replayDueOps();
              expect(
                replayed,
                1,
                reason:
                    (await harness.database
                            .select(harness.database.pendingOps)
                            .get())
                        .toString(),
              );
            } else {
              final client = _AndroidTaskIdentityClient()
                ..releaseCreation.complete();
              expect(
                await PendingOpsReplayer(
                  database: harness.database,
                  apiClient: client,
                  accountId: accountId,
                ).replayDueOps(),
                1,
              );
            }
            await expectSingleCreation(harness.database, 0);
          }

          await harness.dispose();
          final restarted = await _pumpApp(
            tester,
            AppSettings.defaults(),
            databaseOverride: openDatabase(),
            onCalendarSync: (_) async {},
          );
          addTearDown(restarted.dispose);
          await openEditor();
          expect(find.text('Restore'), findsNothing);
          expect(find.text(title), findsNothing);
          expect(secureStorage, contains(recovery.key));
          if (event) {
            expect(tester.widget<TextButton>(save).onPressed, isNull);
          } else {
            await tester.tap(save);
            await tester.pumpAndSettle();
            expect(editor, findsOneWidget);
          }

          // Submission also refuses to create again if the same draft was
          // already open when its first editor committed.
          final database = restarted.database;
          final receipt = await database
              .select(database.creationReceipts)
              .getSingle();
          expect(receipt.creationId, id);
          final result = event
              ? await restarted.container
                    .read(calendarRepositoryProvider)
                    .createLocalEvent(
                      eventDraft.copyWith(title: title),
                      creationId: id,
                    )
              : await restarted.container
                    .read(tasksRepositoryForAccountProvider(accountId))
                    .createTask(
                      'source-list',
                      TaskCreateInput(title: title, creationId: id),
                    );
          expect(result, receipt.resultId);
          await expectSingleCreation(restarted.database, synchronized ? 0 : 1);
          await restarted.dispose();
        },
      );
    }
  }

  testWidgets('event recovery restores its changed account and calendar', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    final now = DateTime.now();
    const sourceA = CalendarSourceEntity(
      id: 'calendar-a',
      accountId: 'google:a',
      provider: BusyProvider.google,
      providerCalendarId: 'provider-a',
      summary: 'Calendar A',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );
    const sourceB = CalendarSourceEntity(
      id: 'calendar-b',
      accountId: 'google:b',
      provider: BusyProvider.google,
      providerCalendarId: 'provider-b',
      summary: 'Calendar B',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );
    final initial = EventEditorDraft.newEvent(
      accountId: sourceA.accountId,
      sourceId: sourceA.id,
      providerCalendarId: sourceA.providerCalendarId,
      start: now,
      end: now.add(const Duration(hours: 1)),
    ).copyWith(showAs: 'opaque', visibilityOrSensitivity: 'private');
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    void open(EventEditorDraft draft) => navigator.push<void>(
      MaterialPageRoute(
        builder: (_) =>
            AndroidEventEditor(sources: const [sourceA, sourceB], draft: draft),
      ),
    );
    open(initial);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('google:b').last);
    await tester.enterText(find.byType(TextFormField).first, 'Recovered event');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    const key = 'busymax.android.event-draft.google:a.new-calendar-a';
    final saved = (jsonDecode(secureStorage[key]!) as Map)
        .cast<String, Object?>();
    expect(saved['accountId'], sourceB.accountId);
    expect(saved['sourceId'], sourceB.id);
    expect(saved['providerCalendarId'], sourceB.providerCalendarId);
    expect(saved['v'], 3);
    expect(saved['eventId'], isNull);
    expect(saved['start'], initial.start!.toIso8601String());

    final route = ModalRoute.of(
      tester.element(find.byType(AndroidEventEditor)),
    )!;
    navigator.removeRoute(route);
    await tester.pumpAndSettle();
    final reopenedOnAnotherDate = EventEditorDraft.newEvent(
      accountId: sourceA.accountId,
      sourceId: sourceA.id,
      providerCalendarId: sourceA.providerCalendarId,
      start: now.add(const Duration(days: 3)),
      end: now.add(const Duration(days: 3, hours: 1)),
    );
    open(reopenedOnAnotherDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(find.text('Recovered event'), findsOneWidget);
    expect(find.text('Calendar B'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    final rewritten = (jsonDecode(secureStorage[key]!) as Map)
        .cast<String, Object?>();
    expect(rewritten['showAs'], initial.showAs);
    expect(rewritten['visibility'], initial.visibilityOrSensitivity);
    expect(rewritten['start'], initial.start!.toIso8601String());
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('event recovery preserves a recurring mutation scope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(823, 384);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    final now = DateTime.now();
    const source = CalendarSourceEntity(
      id: 'calendar',
      accountId: 'google:a',
      provider: BusyProvider.google,
      providerCalendarId: 'provider-a',
      summary: 'Calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidEventEditor(
              sources: const [source],
              draft: EventEditorDraft.existing(
                eventId: 'occurrence',
                providerRecurringEventId: 'series',
                accountId: source.accountId,
                sourceId: source.id,
                providerCalendarId: source.providerCalendarId,
                title: 'Recurring event',
                allDay: false,
                start: now,
                end: now.add(const Duration(hours: 1)),
              ),
            ),
          ),
        );
    await tester.pumpAndSettle();
    final scopeAction = find.text(
      'Choose whether this change applies to the entire series, only this occurrence, or this and following events.',
    );
    await _scrollUntilBuilt(tester, scopeAction);
    await Scrollable.ensureVisible(
      tester.element(scopeAction),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(scopeAction);
    await tester.pumpAndSettle();
    expect(find.text('Entire series').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('This event'));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    const key = 'busymax.android.event-draft.google:a.occurrence';
    final saved = (jsonDecode(secureStorage[key]!) as Map)
        .cast<String, Object?>();
    expect(saved['recurringMutationScope'], 'singleOccurrence');
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('synced occurrence retains recurrence and scope controls', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    const source = CalendarSourceEntity(
      id: 'calendar',
      accountId: 'google:a',
      provider: BusyProvider.google,
      providerCalendarId: 'provider-a',
      summary: 'Calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );
    final start = DateTime(2026, 8, 3, 9);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidEventEditor(
              sources: const [source],
              draft: EventEditorDraft.existing(
                eventId: 'occurrence',
                providerRecurringEventId: 'series',
                accountId: source.accountId,
                sourceId: source.id,
                providerCalendarId: source.providerCalendarId,
                title: 'Occurrence',
                allDay: false,
                start: start,
                end: start.add(const Duration(hours: 1)),
              ),
            ),
          ),
        );
    await tester.pumpAndSettle();
    final scopeAction = find.text(
      'Choose whether this change applies to the entire series, only this occurrence, or this and following events.',
    );
    await _scrollUntilBuilt(tester, scopeAction);
    expect(
      find.byKey(const ValueKey('android-event-recurrence')),
      findsNothing,
    );
    expect(scopeAction, findsOneWidget);

    await harness.dispose();
  });

  testWidgets('task recovery retains full creation recurrence semantics', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    const list = TaskListEntity(
      accountId: 'nextcloud:editable',
      id: 'list-a',
      title: 'Tasks',
      localDirty: false,
      pendingDelete: false,
      rawJson: '{}',
    );
    final rule = RecurrenceRule.fromIcalendar(
      rules: const ['FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=8'],
      baseDate: DateTime(2026, 9, 14),
    );
    const key = 'busymax.android.task-draft.nextcloud:editable.new-list-a';
    secureStorage[key] = jsonEncode({
      'v': 2,
      'savedAt': DateTime.now().toIso8601String(),
      'baseTitle': '',
      'accountId': 'nextcloud:editable',
      'taskListId': 'list-a',
      'title': 'Recovered repeating task',
      'notes': '',
      'dueDate': '2026-09-14',
      'dueTime': '09:00',
      'dueTimeZone': 'America/Vancouver',
      'startDate': '2026-09-14',
      'startTime': '08:00',
      'startTimeZone': 'America/Vancouver',
      'reminderEnabled': true,
      'reminderDate': '2026-09-14',
      'reminderTime': '07:30',
      'reminderTimeZone': 'America/Vancouver',
      'creationRecurrence': {
        'provider': 'nextcloud',
        'rule': rule.toJsonString(),
      },
      'importance': 'normal',
      'categories': <String>[],
      'icalPriority': 0,
      'percentComplete': 0,
      'classification': 'PUBLIC',
      'pinned': false,
      'hideSubtasks': false,
      'hideCompletedSubtasks': false,
      'alarms': <Object>[],
    });
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => const AndroidTaskEditor(
              accountId: 'nextcloud:editable',
              provider: BusyProvider.nextcloud,
              creationList: list,
              accountLabel: 'Editable account',
              listLabel: 'Tasks',
            ),
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered repeating task'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'Keep it');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(secureStorage, isNot(contains(key)));
    final saved = secureStorage.entries
        .where(
          (entry) => entry.key.startsWith('busymax.android.task-draft.v2.new.'),
        )
        .map(
          (entry) => (jsonDecode(entry.value) as Map).cast<String, Object?>(),
        )
        .where(
          (record) =>
              record['accountId'] == list.accountId &&
              record['taskListId'] == list.id,
        )
        .single;
    expect(saved['v'], 2);
    expect(saved['notes'], 'Keep it');
    final creation = (saved['creationRecurrence']! as Map)
        .cast<String, Object?>();
    final recoveredRule = RecurrenceRule.fromJson(
      creation['rule']?.toString(),
      baseDate: DateTime(2026, 9, 14),
    );
    expect(recoveredRule.frequency, rule.frequency);
    expect(recoveredRule.interval, 2);
    expect(recoveredRule.byDay, ['MO', 'WE']);
    expect(recoveredRule.count, 8);
    expect(recoveredRule.untilRaw, isNull);
    expect(saved['dueTimeZone'], 'America/Vancouver');
    expect(saved['startTimeZone'], 'America/Vancouver');
    expect(saved['reminderTimeZone'], 'America/Vancouver');
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets(
    'Android task save locks the submitted draft until persistence finishes',
    (tester) async {
      final received = Completer<void>();
      final release = Completer<void>();
      late _GatedTaskRepository repository;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) =>
            repository = _GatedTaskRepository(
              database: database,
              accountId: accountId,
              received: received,
              release: release,
            ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openMovableTaskEditor(tester, _movableTask());
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Submitted title',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();
      await received.future;
      expect(repository.submittedFields, {'title': 'Submitted title'});
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Title'))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
      release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsNothing);
      final row = await _taskRow(harness.database, 'source-list');
      expect(row!.title, 'Submitted title');
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        hasLength(1),
      );

      await harness.dispose();
    },
  );

  testWidgets('Android empty task title shows feedback and retains draft', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    await _seedMovableTask(harness.database);
    await _openMovableTaskEditor(tester, _movableTask());
    await tester.enterText(
      find.widgetWithText(TextField, 'Notes'),
      'Retain these notes',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Title'), '');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Correct this value before saving.'), findsOneWidget);
    expect(find.text('Retain these notes'), findsOneWidget);
    expect(find.byType(AndroidTaskEditor), findsOneWidget);
    expect(
      await harness.database.select(harness.database.pendingOps).get(),
      isEmpty,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Corrected title',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AndroidTaskEditor), findsNothing);
    expect(
      await harness.database.select(harness.database.pendingOps).get(),
      hasLength(1),
    );

    await harness.dispose();
  });

  for (final keepServer in [false, true]) {
    testWidgets(
      'Android preserves timed due date after '
      '${keepServer ? 'accepting the server version' : 'merging a recovered draft'}',
      (tester) async {
        final harness = await _pumpApp(
          tester,
          AppSettings.defaults(),
          localTimeZone: 'UTC',
        );
        addTearDown(harness.dispose);
        final task = await _seedAndroidEditorTask(
          harness.database,
          provider: BusyProvider.microsoft,
          due: '2026-08-12',
        );
        final database = harness.database;
        Future<Task> readTask() async => (await database.tasksDao.listTasks(
          task.accountId,
          task.taskListId,
        )).single;
        final allDay = find.widgetWithText(SwitchListTile, 'All day');
        final dueTime = find.widgetWithText(ListTile, 'Due time');
        final save = find.widgetWithText(TextButton, 'Save');

        await _openAndroidTaskEditor(tester, task, BusyProvider.microsoft);
        await _scrollUntilBuilt(tester, allDay);
        expect(tester.widget<SwitchListTile>(allDay).value, isTrue);
        final field = find.widgetWithText(
          TextField,
          keepServer ? 'Title' : 'Notes',
        );
        await _scrollUntilBuilt(tester, field);
        await tester.enterText(field, 'Local draft text');
        await tester.pump(const Duration(milliseconds: 1100));
        if (!keepServer) {
          final key = _scopedTaskRecoveryKey(
            task.accountId,
            task.taskListId,
            task.id,
          );
          expect(jsonDecode(secureStorage[key]!)['scheduledAllDay'], isTrue);
          final editor = tester.element(find.byType(AndroidTaskEditor));
          // Simulate the editor disappearing without an explicit discard.
          Navigator.of(editor).removeRoute(ModalRoute.of(editor)!);
          await tester.pumpAndSettle();
        }
        await (database.update(
          database.tasks,
        )..where((row) => row.accountId.equals(task.accountId))).write(
          const TasksCompanion(
            title: Value('Remote title'),
            rawJson: Value('{"id":"editor-task","title":"Remote title"}'),
            microsoftDueDateTime: Value('2026-08-12T16:45:00'),
          ),
        );
        if (keepServer) {
          await tester.tap(save);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Keep server version').hitTestable());
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
          await tester.pumpAndSettle();
        } else {
          await _openAndroidTaskEditor(
            tester,
            TaskEntity.fromRow(await readTask()),
            BusyProvider.microsoft,
          );
          await tester.tap(find.text('Restore'));
          await tester.pumpAndSettle();
        }

        await _scrollUntilBuilt(tester, allDay);
        expect(tester.widget<SwitchListTile>(allDay).value, isFalse);
        await _scrollUntilBuilt(tester, dueTime);
        expect(
          find.descendant(of: dueTime, matching: find.text('16:45')),
          findsOneWidget,
        );
        final dueDate = find.widgetWithText(ListTile, 'Due date');
        await _scrollUntilBuilt(tester, dueDate);
        await tester.tap(dueDate.hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byType(DatePickerDialog),
                matching: find.text('13'),
              )
              .hitTestable(),
        );
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.byType(AndroidTaskEditor), findsNothing);
        final stored = await readTask();
        expect(stored.title, 'Remote title');
        expect(stored.notes ?? '', keepServer ? '' : 'Local draft text');
        expect(stored.microsoftDueDateTime, '2026-08-13T16:45:00');

        await _openAndroidTaskEditor(
          tester,
          TaskEntity.fromRow(stored),
          BusyProvider.microsoft,
        );
        await _scrollUntilBuilt(tester, allDay);
        expect(tester.widget<SwitchListTile>(allDay).value, isFalse);
        await tester.tap(allDay.hitTestable());
        await tester.pumpAndSettle();
        expect(dueTime, findsNothing);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final dateOnly = await readTask();
        expect(dateOnly.microsoftDueDateTime, '2026-08-13');
        await _openAndroidTaskEditor(
          tester,
          TaskEntity.fromRow(dateOnly),
          BusyProvider.microsoft,
        );
        await _scrollUntilBuilt(tester, allDay);
        expect(tester.widget<SwitchListTile>(allDay).value, isTrue);
        expect(dueTime, findsNothing);
        await harness.dispose();
      },
    );
  }

  testWidgets('an undated recovered task remembers the timed-date preference', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    final task = await _seedAndroidEditorTask(
      harness.database,
      provider: BusyProvider.microsoft,
    );
    await _openAndroidTaskEditor(tester, task, BusyProvider.microsoft);
    final allDay = find.widgetWithText(SwitchListTile, 'All day');
    await _scrollUntilBuilt(tester, allDay);
    await tester.tap(allDay.hitTestable());
    final notes = find.widgetWithText(TextField, 'Notes');
    await _scrollUntilBuilt(tester, notes);
    await tester.enterText(notes, 'Undated draft');
    await tester.pump(const Duration(milliseconds: 1100));
    final editor = tester.element(find.byType(AndroidTaskEditor));
    Navigator.of(editor).removeRoute(ModalRoute.of(editor)!);
    await tester.pumpAndSettle();

    await _openAndroidTaskEditor(tester, task, BusyProvider.microsoft);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await _scrollUntilBuilt(tester, allDay);
    expect(tester.widget<SwitchListTile>(allDay).value, isFalse);
    final dueTime = find.widgetWithText(ListTile, 'Due time');
    expect(dueTime, findsNothing);

    final dueDate = find.widgetWithText(ListTile, 'Due date');
    await _scrollUntilBuilt(tester, dueDate);
    await tester.tap(dueDate.hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _scrollUntilBuilt(tester, dueTime);
    expect(
      find.descendant(of: dueTime, matching: find.text('09:00')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    final row = (await harness.database.tasksDao.listTasks(
      task.accountId,
      task.taskListId,
    )).single;
    expect(row.notes, 'Undated draft');
    expect(row.microsoftDueDateTime, endsWith('T09:00:00'));
    await harness.dispose();
  });

  testWidgets(
    'Android task recovery retains notes after a remote rename and movement',
    (tester) async {
      final client = _AndroidRecoveryMoveClient();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => TasksRepository(
          database: database,
          accountId: accountId,
          apiClient: client,
        ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openMovableTaskEditor(tester, _movableTask());
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Unsaved recovery notes',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final key = _scopedTaskRecoveryKey(
        'google:move',
        'source-list',
        'move-task',
      );
      final stored = secureStorage[key]!;
      // End the first editor session, then perform the supported repository
      // move and acknowledge it. A second independently inserted equal-ID
      // source/destination row does not establish task movement.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final repository = harness.container.read(
        tasksRepositoryForAccountProvider('google:move'),
      );
      await repository.moveTask(
        const TaskMoveInput(
          sourceTaskListId: 'source-list',
          destinationTaskListId: 'destination-list',
          taskId: 'move-task',
        ),
      );
      expect(
        await PendingOpsReplayer(
          database: harness.database,
          apiClient: client,
          accountId: 'google:move',
        ).replayDueOps(),
        1,
      );
      expect(await _taskRow(harness.database, 'source-list'), isNull);
      client.rename('Remote renamed title');
      await harness.database.tasksDao.upsertTask(
        taskFromDto(
          'google:move',
          'destination-list',
          await client.getTask(
            taskListId: 'destination-list',
            taskId: 'move-task',
          ),
          '2026-09-16T00:00:00.000Z',
        ),
      );
      final accounts = await harness.database
          .select(harness.database.accounts)
          .get();
      final lists = await harness.database
          .select(harness.database.taskLists)
          .get();
      final tasks = await harness.database.select(harness.database.tasks).get();
      expect(
        TaskEntity.fromRow(tasks.single).previousTaskListIds,
        contains('source-list'),
      );
      await harness.dispose();
      await tester.pumpAndSettle();
      secureStorage[key] = stored;
      final changedHarness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        seedDatabase: (database) async {
          for (final account in accounts) {
            await database
                .into(database.accounts)
                .insert(account.toCompanion(true));
          }
          for (final list in lists) {
            await database.taskListsDao.upsertTaskList(list.toCompanion(true));
          }
          for (final task in tasks) {
            await database.tasksDao.upsertTask(task.toCompanion(true));
          }
        },
      );
      addTearDown(changedHarness.dispose);
      final changedRow = await _taskRow(
        changedHarness.database,
        'destination-list',
      );
      await _openMovableTaskEditor(tester, TaskEntity.fromRow(changedRow!));
      expect(find.text('Restore'), findsOneWidget);
      expect(secureStorage, contains(key));
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Remote renamed title'), findsOneWidget);
      expect(find.text('Unsaved recovery notes'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final saved = await _taskRow(changedHarness.database, 'destination-list');
      expect(saved!.title, 'Remote renamed title');
      expect(saved.notes, 'Unsaved recovery notes');
      expect(secureStorage, isNot(contains(key)));
      final operation = await changedHarness.database
          .select(changedHarness.database.pendingOps)
          .getSingle();
      expect(operation.taskListId, 'destination-list');
      expect(jsonDecode(operation.requestJson), {
        'notes': 'Unsaved recovery notes',
      });
      expect(
        await PendingOpsReplayer(
          database: changedHarness.database,
          apiClient: client,
          accountId: 'google:move',
        ).replayDueOps(),
        1,
      );
      expect(client.task['title'], 'Remote renamed title');
      expect(client.task['notes'], 'Unsaved recovery notes');
      expect(client.mutations, [
        'move:source-list:destination-list',
        'patch:destination-list',
      ]);

      await harness.dispose();
    },
  );

  testWidgets(
    'Android task save failure keeps exact fields and permits one retry',
    (tester) async {
      final received = Completer<void>();
      final release = Completer<void>();
      late _GatedTaskRepository repository;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) =>
            repository = _GatedTaskRepository(
              database: database,
              accountId: accountId,
              received: received,
              release: release,
              failFirst: true,
            ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openMovableTaskEditor(tester, _movableTask());
      const notes = 'Exact unsaved notes\nSecond line  ';
      await tester.enterText(find.widgetWithText(TextField, 'Notes'), notes);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();
      await received.future;
      release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .controller!
            .text,
        notes,
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .enabled,
        isTrue,
      );
      expect(find.textContaining('Local persistence failed'), findsOneWidget);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final recovered = jsonDecode(
        secureStorage[_scopedTaskRecoveryKey(
          'google:move',
          'source-list',
          'move-task',
        )]!,
      ) as Map;
      expect(recovered['notes'], notes);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.byType(AndroidTaskEditor), findsNothing);
      expect((await _taskRow(harness.database, 'source-list'))!.notes, notes);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        hasLength(1),
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android ignores a date picker result after repository submission',
    (tester) async {
      final received = Completer<void>();
      final release = Completer<void>();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => _GatedTaskRepository(
          database: database,
          accountId: accountId,
          received: received,
          release: release,
        ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openMovableTaskEditor(tester, _movableTask());
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Submitted before picker',
      );
      final save = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed!;
      await tester.tap(find.widgetWithText(ListTile, 'Due date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      save();
      await tester.pump();
      await received.future;
      await tester.tap(find.text('20').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      release.complete();
      await tester.pumpAndSettle();
      final row = await _taskRow(harness.database, 'source-list');
      expect(row!.title, 'Submitted before picker');
      expect(row.dueUtc, isNull);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        hasLength(1),
      );

      await harness.dispose();
    },
  );

  for (final issue in ['url', 'range', 'modes']) {
    testWidgets('Android explains invalid task $issue and queues no mutation', (
      tester,
    ) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final task = await _seedAndroidEditorTask(
        harness.database,
        taskUrl: issue == 'url' ? 'relative/path' : null,
        due: issue == 'range'
            ? '2026-08-01T09:00:00'
            : issue == 'modes'
            ? '2026-08-02'
            : null,
        start: issue == 'range' || issue == 'modes'
            ? '2026-08-02T09:00:00'
            : null,
      );
      await _openAndroidTaskEditor(tester, task, BusyProvider.nextcloud);
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Retained invalid draft',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final expected = switch (issue) {
        'url' => 'Enter an absolute URL, including its scheme.',
        'range' => 'Due must not be before start.',
        _ => 'Set times for both start and due, or make the task all day.',
      };
      expect(find.text(expected), findsOneWidget);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      expect(find.byType(AndroidTaskEditor), findsOneWidget);

      await harness.dispose();
    });
  }

  testWidgets(
    'hidden unsupported Google fields do not invalidate a task save',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final task = await _seedAndroidEditorTask(
        harness.database,
        provider: BusyProvider.google,
        taskUrl: 'relative/path',
        due: '2026-08-01T09:00:00',
        start: '2026-08-02T09:00:00',
      );
      await _openAndroidTaskEditor(tester, task, BusyProvider.google);
      expect(find.widgetWithText(TextField, 'URL'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Google allowed change',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsNothing);
      final operations = await harness.database
          .select(harness.database.pendingOps)
          .get();
      expect(operations, hasLength(1));
      expect(jsonDecode(operations.single.requestJson), {
        'title': 'Google allowed change',
      });

      await harness.dispose();
    },
  );

  testWidgets(
    'Android task advanced recurrence unchanged Save preserves exact timed UNTIL',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      const raw =
          '{"rules":["FREQ=DAILY;UNTIL=20260812T090000Z"],"dates":[],"excludedDates":[]}';
      final task = await _seedAndroidEditorTask(
        harness.database,
        due: '2026-08-01T09:00:00',
        recurrence: raw,
      );
      await _openAndroidTaskEditor(tester, task, BusyProvider.nextcloud);
      final recurrence = find.byKey(
        const ValueKey('android-task-advanced-recurrence'),
      );
      await _scrollUntilBuilt(tester, recurrence);
      await tester.tap(recurrence);
      await tester.pumpAndSettle();
      expect(find.text('8/12/2026'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsNothing);
      final row = (await harness.database.tasksDao.listTasks(
        task.accountId,
        task.taskListId,
      )).single;
      expect(row.recurrenceJson, raw);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  for (final anchor in ['due', 'start', 'date']) {
    testWidgets(
      'Android task advanced recurrence UNTIL keeps the $anchor anchor',
      (tester) async {
        final harness = await _pumpApp(tester, AppSettings.defaults());
        addTearDown(harness.dispose);
        final task = await _seedAndroidEditorTask(
          harness.database,
          due: anchor == 'due'
              ? '2026-08-01T09:00:00'
              : anchor == 'date'
              ? '2026-08-01'
              : null,
          start: anchor == 'start' ? '2026-08-01T09:00:00' : null,
          recurrence: '{"rules":["FREQ=DAILY"],"dates":[],"excludedDates":[]}',
        );
        await _openAndroidTaskEditor(tester, task, BusyProvider.nextcloud);
        final recurrence = find.byKey(
          const ValueKey('android-task-advanced-recurrence'),
        );
        await _scrollUntilBuilt(tester, recurrence);
        await tester.tap(recurrence);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('android-recurrence-end')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('On date').last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('android-recurrence-until')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Switch to input'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).last, '08/12/2026');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        final row = (await harness.database.tasksDao.listTasks(
          task.accountId,
          task.taskListId,
        )).single;
        final rule = RecurrenceRule.fromJson(
          row.recurrenceJson,
          baseDate: DateTime(2026, 8, 1, 9),
        );
        expect(
          rule.untilRaw,
          anchor == 'date' ? '20260812' : '20260812T090000Z',
        );
        expect(
          await harness.database.select(harness.database.pendingOps).get(),
          hasLength(1),
        );

        await harness.dispose();
      },
    );
  }

  testWidgets(
    'Android Clear completed confirms the selected Google list and cancellation queues nothing',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await (harness.database.update(harness.database.tasks)
            ..where((row) => row.id.equals('move-task')))
          .write(const TasksCompanion(status: Value('completed')));
      await _openAndroidScheduleScreen(tester);
      final list = (await harness.container.read(
        scheduleTaskListsProvider.future,
      )).firstWhere((l) => l.id == 'source-list');
      Future<void> openActions() async {
        final screen = tester.state<ConsumerState<AndroidScheduleScreen>>(
          find.byType(AndroidScheduleScreen),
        );
        unawaited(
          showAndroidTaskListActions(
            screen.context,
            screen.ref,
            list,
            await harness.container.read(accountsStreamProvider.future),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openActions();
      await tester.ensureVisible(find.text('Clear completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear completed'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Google Tasks will clear or hide'),
        findsOneWidget,
      );
      expect(find.textContaining('Source list'), findsWidgets);
      expect(find.textContaining('Currently completed: 1'), findsOneWidget);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await openActions();
      await tester.ensureVisible(find.text('Clear completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear completed'));
      await tester.pumpAndSettle();
      final operations = await harness.database
          .select(harness.database.pendingOps)
          .get();
      expect(operations.single.operation, 'clear_completed_tasks');
      expect(operations.single.taskListId, 'source-list');

      await harness.dispose();
    },
  );

  testWidgets(
    'Android Nextcloud Clear completed counts root trees once and warns about descendants',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final root = await _seedAndroidEditorTask(harness.database);
      await harness.database
          .into(harness.database.davCollections)
          .insert(
            DavCollectionsCompanion.insert(
              id: 'android-dav',
              accountId: root.accountId,
              hrefKey: '/tasks/',
              requestUri: 'https://example.test/tasks/',
              displayName: 'Editor tasks',
              supportedComponentMask: const Value(2),
              createdAtUtc: '2026-08-01T00:00:00Z',
              updatedAtUtc: '2026-08-01T00:00:00Z',
            ),
          );
      await (harness.database.update(
        harness.database.taskLists,
      )..where((row) => row.accountId.equals(root.accountId))).write(
        const TaskListsCompanion(davCollectionId: Value('android-dav')),
      );
      await (harness.database.update(
        harness.database.tasks,
      )..where((row) => row.accountId.equals(root.accountId))).write(
        const TasksCompanion(
          davCollectionId: Value('android-dav'),
          icalUid: Value('root-uid'),
          status: Value('completed'),
          providerStatus: Value('COMPLETED'),
        ),
      );
      for (final id in ['child', 'history-1', 'history-2']) {
        await harness.database.tasksDao.upsertTask(
          TasksCompanion.insert(
            accountId: root.accountId,
            taskListId: root.taskListId,
            id: id,
            title: id,
            rawJson: '{}',
            davCollectionId: const Value('android-dav'),
            icalUid: const Value('child-uid'),
            parent: Value(root.id),
            parentUid: const Value('root-uid'),
            recurrenceIdKey: Value(id == 'child' ? null : id),
            status: const Value('completed'),
            createdLocalAtUtc: '2026-08-01T00:00:00Z',
            updatedLocalAtUtc: '2026-08-01T00:00:00Z',
          ),
        );
      }
      await _openAndroidScheduleScreen(tester);
      final list = (await harness.container.read(
        scheduleTaskListsProvider.future,
      )).single;
      final screen = tester.state<ConsumerState<AndroidScheduleScreen>>(
        find.byType(AndroidScheduleScreen),
      );
      unawaited(
        showAndroidTaskListActions(
          screen.context,
          screen.ref,
          list,
          await harness.container.read(accountsStreamProvider.future),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clear completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear completed'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Delete 1 closed root task trees'),
        findsOneWidget,
      );
      expect(
        find.textContaining('descendants will also be deleted'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android checklist rename keeps an offline draft when remote rename conflicts',
    (tester) async {
      final client = _AndroidChecklistClient();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => TasksRepository(
          database: database,
          accountId: accountId,
          apiClient: client,
        ),
      );
      addTearDown(harness.dispose);
      final task = await _seedAndroidChecklistTask(harness.database, client);
      await _openAndroidTaskEditor(tester, task, BusyProvider.microsoft);
      await _openChecklistAction(tester, 'Rename');
      await tester.enterText(
        find.byKey(const ValueKey('android-checklist-title')),
        'Cancelled rename',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await _openChecklistAction(tester, 'Rename');
      await tester.enterText(
        find.byKey(const ValueKey('android-checklist-title')),
        'Offline rename',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      client.items['step-1']!['displayName'] = 'Remote rename';
      final applied = await PendingOpsReplayer(
        database: harness.database,
        apiClient: client,
        accountId: task.accountId,
      ).replayDueOps();
      await tester.pumpAndSettle();
      expect(applied, 0);
      expect(client.mutations, isEmpty);
      expect(client.items['step-1']!['displayName'], 'Remote rename');
      final row = (await harness.database.tasksDao.listTasks(
        task.accountId,
        task.taskListId,
      )).single;
      expect(
        decodeTaskChecklistItems(row.microsoftChecklistItemsJson).first.title,
        'Offline rename',
      );
      final op =
          (await harness.database.select(harness.database.pendingOps).get())
              .single;
      expect(op.state, 'pending');
      expect(op.lastErrorCode, 'conflict');
      expect(DateTime.parse(op.nextAttemptAtUtc!).year, 9999);
      expect((jsonDecode(op.requestJson) as Map)['body'], {
        'displayName': 'Offline rename',
      });
      expect(client.readPages, greaterThanOrEqualTo(2));
      await tester.pump(const Duration(milliseconds: 1));

      await harness.dispose();
    },
  );

  testWidgets(
    'Android checklist completion merges a remote rename and sibling edits',
    (tester) async {
      final client = _AndroidChecklistClient();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => TasksRepository(
          database: database,
          accountId: accountId,
          apiClient: client,
        ),
      );
      addTearDown(harness.dispose);
      final task = await _seedAndroidChecklistTask(harness.database, client);
      await _openAndroidTaskEditor(tester, task, BusyProvider.microsoft);
      final step = find.widgetWithText(ListTile, 'Original step');
      await _scrollUntilBuilt(tester, step);
      await tester.tap(_completionControl(step));
      await tester.pumpAndSettle();
      client.items['step-1']!['displayName'] = 'Remote rename';
      client.items['step-2']!['displayName'] = 'Remote sibling';
      expect(
        await PendingOpsReplayer(
          database: harness.database,
          apiClient: client,
          accountId: task.accountId,
        ).replayDueOps(),
        1,
      );
      await tester.pumpAndSettle();
      expect(client.items['step-1']!['displayName'], 'Remote rename');
      expect(client.items['step-1']!['isChecked'], isTrue);
      expect(client.items['step-2']!['displayName'], 'Remote sibling');
      expect(client.mutations, ['patch:step-1']);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await tester.pump(const Duration(milliseconds: 1));

      await harness.dispose();
    },
  );

  testWidgets(
    'Android checklist deletion confirms and retains the pending delete on remote edit',
    (tester) async {
      final client = _AndroidChecklistClient();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => TasksRepository(
          database: database,
          accountId: accountId,
          apiClient: client,
        ),
      );
      addTearDown(harness.dispose);
      final task = await _seedAndroidChecklistTask(harness.database, client);
      await _openAndroidTaskEditor(tester, task, BusyProvider.microsoft);
      await _openChecklistAction(tester, 'Delete');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await _openChecklistAction(tester, 'Delete');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      client.items['step-1']!['displayName'] = 'Remote changed step';
      expect(
        await PendingOpsReplayer(
          database: harness.database,
          apiClient: client,
          accountId: task.accountId,
        ).replayDueOps(),
        0,
      );
      expect(client.mutations, isEmpty);
      expect(client.items, contains('step-1'));
      final op =
          (await harness.database.select(harness.database.pendingOps).get())
              .single;
      expect(op.operation, 'delete_task_checklist_item');
      expect(op.state, 'pending');
      expect(op.lastErrorCode, 'conflict');
      expect(DateTime.parse(op.nextAttemptAtUtc!).year, 9999);
      final row = (await harness.database.tasksDao.listTasks(
        task.accountId,
        task.taskListId,
      )).single;
      expect(
        decodeTaskChecklistItems(row.microsoftChecklistItemsJson)
            .map((item) => item.id),
        isNot(contains('step-1')),
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android task list initial error has localized Retry and recovers',
    (tester) async {
      late _AndroidRetryScheduleRepository schedule;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        scheduleRepository: (database) =>
            schedule = _AndroidRetryScheduleRepository(database)..fail = true,
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openAndroidScheduleScreen(tester);
      expect(
        find.text(
          'Collections could not be loaded. Cached data is retained; retry synchronization.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('test task query failure'), findsNothing);
      schedule.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Original move task'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      await harness.dispose();
    },
  );

  for (final editCategories in [false, true]) {
    testWidgets(
      'Android DAV unrelated task title edit retains comma categories (edit categories: $editCategories)',
      (tester) async {
        final harness = await _pumpApp(tester, AppSettings.defaults());
        addTearDown(harness.dispose);
        final parent = await _seedAndroidDavTree(
          harness.database,
          categories: r'one\,two,雪',
        );
        await _openAndroidTaskEditor(tester, parent, BusyProvider.nextcloud);
        await tester.enterText(
          find.widgetWithText(TextField, 'Title'),
          'Unrelated task title',
        );
        if (editCategories) {
          await _setAndroidCategories(tester, ['Work', 'Personal']);
        }
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AndroidTaskEditor), findsNothing);
        final operations = await harness.database
            .select(harness.database.pendingOps)
            .get();
        expect(operations, hasLength(1));
        final operation = operations.single;
        final queuedBody = DavMutationPatch.fromJsonString(
          operation.mutationPatchJson!,
        ).applyTo(operation.baselineRawIcs!, nowUtc: DateTime.now().toUtc());
        expect(queuedBody, contains('SUMMARY:Unrelated task title'));
        expect(
          queuedBody,
          contains(
            editCategories
                ? 'CATEGORIES:Work,Personal'
                : r'CATEGORIES:one\,two,雪',
          ),
        );

        await harness.dispose();
      },
    );
  }

  testWidgets(
    'Android Tasks reconciles an advancing recurring occurrence to its open master',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final parent = await _seedAndroidDavTree(
        harness.database,
        recurringCount: 3,
      );
      await _openAndroidScheduleScreen(tester);
      final tile = _androidMutationTile(parent);
      final staleToggle = _completionAction(tester, tile)!;
      await tester.tap(_completionControl(tile));
      await tester.pumpAndSettle();
      final rows = await harness.database.tasksDao.listTasks(
        parent.accountId,
        parent.taskListId,
      );
      final master = rows.singleWhere((row) => row.id == parent.id);
      expect(master.status, 'needsAction');
      expect(master.recurrenceJson, contains('COUNT=2'));
      expect(
        rows.where(
          (row) => row.icalUid == parent.icalUid && row.recurrenceIdKey != null,
        ),
        hasLength(1),
      );
      expect(tester.widget<Checkbox>(_completionControl(tile)).value, isFalse);
      expect(tester.widget<Checkbox>(_completionControl(tile)).value, isFalse);
      final acknowledgedOperations = await harness.database
          .select(harness.database.pendingOps)
          .get();
      staleToggle();
      await tester.pumpAndSettle();
      var currentRows = await harness.database.tasksDao.listTasks(
        parent.accountId,
        parent.taskListId,
      );
      expect(
        currentRows.singleWhere((row) => row.id == parent.id).dueUtc,
        master.dueUtc,
      );
      expect(
        currentRows.where(
          (row) => row.icalUid == parent.icalUid && row.recurrenceIdKey != null,
        ),
        hasLength(1),
      );
      expect(
        (await harness.database.select(harness.database.pendingOps).get()).map(
          (op) => op.mutationPatchJson,
        ),
        acknowledgedOperations.map((op) => op.mutationPatchJson),
      );
      await tester.tap(_completionControl(tile));
      await tester.pumpAndSettle();
      currentRows = await harness.database.tasksDao.listTasks(
        parent.accountId,
        parent.taskListId,
      );
      expect(
        currentRows.singleWhere((row) => row.id == parent.id).recurrenceJson,
        contains('COUNT=1'),
      );
      expect(
        currentRows.where(
          (row) => row.icalUid == parent.icalUid && row.recurrenceIdKey != null,
        ),
        hasLength(2),
      );
      expect(tester.widget<Checkbox>(_completionControl(tile)).value, isFalse);
      await tester.tap(_completionControl(tile));
      await tester.pumpAndSettle();
      currentRows = await harness.database.tasksDao.listTasks(
        parent.accountId,
        parent.taskListId,
      );
      expect(
        currentRows.singleWhere((row) => row.id == parent.id).status,
        'completed',
      );
      expect(tester.widget<Checkbox>(_completionControl(tile)).value, isTrue);

      await harness.dispose();
    },
  );

  testWidgets(
    'Android Tasks ignores a second activation while an occurrence is persisting',
    (tester) async {
      final received = Completer<void>();
      final release = Completer<void>();
      late _GatedTaskRepository repository;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) =>
            repository = _GatedTaskRepository(
              database: database,
              accountId: accountId,
              received: received,
              release: release,
            ),
      );
      addTearDown(harness.dispose);
      final parent = await _seedAndroidDavTree(
        harness.database,
        recurringCount: 3,
      );
      await _openAndroidScheduleScreen(tester);
      final toggle = find
          .descendant(
            of: find.widgetWithText(ListTile, 'Parent'),
            matching: find.byType(Checkbox),
          )
          .first;
      await tester.tap(toggle);
      await tester.pump();
      expect(received.isCompleted, isTrue);
      await tester.tap(toggle);
      await tester.pump();
      final callsWhileBlocked = repository.calls;
      release.complete();
      await tester.pumpAndSettle();
      expect(callsWhileBlocked, 1);
      final rows = await harness.database.tasksDao.listTasks(
        parent.accountId,
        parent.taskListId,
      );
      expect(
        rows.singleWhere((row) => row.id == parent.id).recurrenceJson,
        contains('COUNT=2'),
      );
      expect(
        rows.where(
          (row) => row.icalUid == parent.icalUid && row.recurrenceIdKey != null,
        ),
        hasLength(1),
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android recurring editor completion cannot advance an occurrence newer than its draft',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final parent = await _seedAndroidDavTree(
        harness.database,
        recurringCount: 3,
      );
      await _openAndroidTaskEditor(tester, parent, BusyProvider.nextcloud);
      final progress = find.byType(Slider);
      await _scrollUntilBuilt(tester, progress);
      tester.widget<Slider>(progress).onChanged!(100);
      await tester.pump();
      await harness.container
          .read(tasksRepositoryForAccountProvider(parent.accountId))
          .patchTask(
            parent.taskListId,
            parent.id,
            TaskPatchInput.completion(
              true,
              observedOccurrenceKey: parent.occurrenceKey,
            ),
          );
      final before = await harness.database.tasksDao.listTasks(
        parent.accountId,
        parent.taskListId,
      );
      final advanced = before.singleWhere((row) => row.id == parent.id);
      expect(advanced.recurrenceJson, contains('COUNT=2'));
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final after = await harness.database.tasksDao.listTasks(
        parent.accountId,
        parent.taskListId,
      );
      expect(
        after.singleWhere((row) => row.id == parent.id).dueUtc,
        advanced.dueUtc,
      );
      expect(
        after.singleWhere((row) => row.id == parent.id).recurrenceJson,
        contains('COUNT=2'),
      );
      expect(
        after.where(
          (row) => row.icalUid == parent.icalUid && row.recurrenceIdKey != null,
        ),
        hasLength(1),
      );
      expect(find.byType(AndroidTaskEditor), findsOneWidget);
      expect(
        find.text(
          tester.element(find.byType(AndroidTaskEditor)).l10n.taskDraftConflict,
        ),
        findsOneWidget,
      );

      await harness.dispose();
    },
  );

  for (final surface in ['editor', 'Tasks', 'Schedule', 'hierarchy']) {
    testWidgets(
      'Android stale occurrence conflicts use the selected locale in $surface',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late TaskEntity parent;
        late TaskEntity target;
        final harness = await _pumpApp(
          tester,
          AppSettings.defaults().copyWith(
            localeTag: 'de',
            androidScheduleViewMode: ScheduleViewMode.agenda,
          ),
          seedDatabase: (database) async {
            parent = await _seedAndroidDavTree(
              database,
              recurringCount: 3,
              recurringChild: surface == 'hierarchy',
            );
            target = surface == 'hierarchy'
                ? TaskEntity.fromRow(
                    (await database.tasksDao.listTasks(
                      parent.accountId,
                      parent.taskListId,
                    )).singleWhere((row) => row.icalUid == 'child-uid'),
                  )
                : parent;
          },
        );
        addTearDown(harness.dispose);
        final remote = StatefulTaskDavRemote(
          await harness.database.select(harness.database.davObjects).get(),
        );
        if (surface != 'Schedule') {
          await _openAndroidScheduleScreen(tester);
        }
        VoidCallback? staleToggle;
        if (surface == 'editor' || surface == 'hierarchy') {
          await tester.tap(_androidMutationTile(parent));
          await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
          if (surface == 'editor') {
            await _scrollUntilBuilt(tester, find.byType(Slider));
            tester.widget<Slider>(find.byType(Slider)).onChanged!(100);
            await tester.pump();
          } else {
            final child = find.widgetWithText(ListTile, 'Child');
            await _scrollUntilBuilt(tester, child);
            staleToggle = _completionAction(tester, child)!;
          }
        } else {
          final tile = surface == 'Tasks'
              ? _androidMutationTile(parent)
              : find.widgetWithText(ListTile, 'Parent');
          staleToggle = _completionAction(tester, tile)!;
        }
        final localized = tester.element(find.byType(Scaffold).last).l10n;
        expect(localized.editTask, isNot('Edit Task'));
        expect(
          localized.taskDraftConflict,
          isNot(
            'This task changed since you opened it. Your edits are retained. Review the latest task before retrying.',
          ),
        );
        await harness.container
            .read(tasksRepositoryForAccountProvider(target.accountId))
            .patchTask(
              target.taskListId,
              target.id,
              TaskPatchInput.completion(
                true,
                observedOccurrenceKey: target.occurrenceKey,
              ),
            );
        final summary = await DavPendingOperationsReplayer(
          database: harness.database,
          accountId: target.accountId,
          serviceFactory: ({required account, required collection}) async =>
              DavConditionalMutationService(remoteClient: remote),
        ).replayDueOperations();
        expect(summary.appliedCount, surface == 'hierarchy' ? 1 : 2);
        expect(summary.conflictCount, 0);
        expect(
          await harness.database.select(harness.database.pendingOps).get(),
          isEmpty,
        );
        final before = await harness.database.tasksDao.listTasks(
          target.accountId,
          target.taskListId,
        );
        final advanced = before.singleWhere((row) => row.id == target.id);
        expect(advanced.recurrenceJson, contains('COUNT=2'));
        expect(
          before.where(
            (row) =>
                row.icalUid == target.icalUid && row.recurrenceIdKey != null,
          ),
          hasLength(1),
        );
        final providerBefore = Map.of(remote.resources);
        if (surface == 'editor') {
          await tester.tap(find.widgetWithText(TextButton, localized.save));
        } else {
          staleToggle!();
        }
        await tester.pumpAndSettle();
        expect(
          await harness.database.tasksDao.listTasks(
            target.accountId,
            target.taskListId,
          ),
          before,
        );
        expect(
          await harness.database.select(harness.database.pendingOps).get(),
          isEmpty,
        );
        expect(remote.resources, providerBefore);
        if (surface == 'editor') {
          expect(find.byType(AndroidTaskEditor), findsOneWidget);
          await _scrollUntilBuilt(tester, find.byType(Slider));
          expect(tester.widget<Slider>(find.byType(Slider)).value, 100);
        }
        expect(
          find.text(localized.taskDraftConflict),
          findsOneWidget,
          reason: find
              .byType(SnackBar)
              .evaluate()
              .map(
                (element) =>
                    ((element.widget as SnackBar).content as Text).data,
              )
              .join(' | '),
        );
        expect(
          find.text('This task now represents another occurrence.'),
          findsNothing,
        );

        await harness.dispose();
      },
    );
  }

  for (final scenario in [
    'stale completion',
    'stale completion with explicit status',
    'notes after advancement',
    'completion without advancement',
  ]) {
    testWidgets(
      'R03 verified DAV move preserves the observed occurrence for $scenario',
      (tester) async {
        late _ObservedTaskDraftRepository observedRepository;
        final harness = await _pumpApp(
          tester,
          AppSettings.defaults(),
          taskRepository: (database, accountId) =>
              observedRepository = _ObservedTaskDraftRepository(
                database: database,
                accountId: accountId,
              ),
        );
        addTearDown(harness.dispose);
        final advanceBeforeMove = scenario != 'completion without advancement';
        final notesOnly = scenario == 'notes after advancement';
        final until = _icalDate(DateTime.now().add(const Duration(days: 9)));
        final parent = await _seedAndroidDavTree(
          harness.database,
          recurringRule: 'FREQ=DAILY;UNTIL=$until',
          explicitParentStatus: scenario.endsWith('explicit status'),
        );
        expect(
          parent.providerStatus,
          scenario.endsWith('explicit status') ? 'NEEDS-ACTION' : isNull,
        );
        expect(parent.percentComplete ?? 0, 0);
        await _seedAndroidDavMoveDestination(
          harness.database,
          parent.accountId,
        );
        final remote = StatefulTaskDavRemote(
          await harness.database.select(harness.database.davObjects).get(),
        );
        final repository = harness.container.read(
          tasksRepositoryForAccountProvider(parent.accountId),
        );
        Future<void> replay(int expected) async {
          final summary = await DavPendingOperationsReplayer(
            database: harness.database,
            accountId: parent.accountId,
            serviceFactory: ({required account, required collection}) async =>
                DavConditionalMutationService(remoteClient: remote),
          ).replayDueOperations();
          expect(summary.appliedCount, expected);
          expect(summary.conflictCount, 0);
          expect(summary.retryCount, 0);
          expect(
            await harness.database.select(harness.database.pendingOps).get(),
            isEmpty,
          );
        }

        await _openAndroidScheduleScreen(tester);
        await tester.tap(_androidMutationTile(parent));
        await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
        if (notesOnly) {
          await tester.enterText(
            find.widgetWithText(TextField, 'Notes'),
            'Exact notes for the observed occurrence',
          );
        } else {
          final progress = find.byType(Slider);
          await _scrollUntilBuilt(tester, progress);
          tester.widget<Slider>(progress).onChanged!(100);
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 1100));
        Map<String, Object?> recordFor(String listId) => secureStorage.entries
            .where(
              (entry) => entry.key.startsWith('busymax.android.task-draft.'),
            )
            .map(
              (entry) =>
                  (jsonDecode(entry.value) as Map).cast<String, Object?>(),
            )
            .singleWhere(
              (record) =>
                  record['accountId'] == parent.accountId &&
                  record['taskListId'] == listId,
            );
        Map<String, Object?> draftValues(Map<String, Object?> record) => {
          for (final entry in record.entries)
            if (!const {
              'savedAt',
              'taskListId',
              'taskId',
              'observedTask',
              'originalObservedTask',
            }.contains(entry.key))
              entry.key: entry.value,
        };
        final originalRecovery = recordFor(parent.taskListId);
        if (advanceBeforeMove) {
          await repository.patchTask(
            parent.taskListId,
            parent.id,
            TaskPatchInput.completion(
              true,
              observedOccurrenceKey: parent.occurrenceKey,
            ),
          );
          await replay(2);
          expect(remote.puts, 2);
        }
        final sourceRows = await harness.database.tasksDao.listTasks(
          parent.accountId,
          parent.taskListId,
        );
        final beforeMove = sourceRows.singleWhere(
          (row) => row.icalUid == parent.icalUid && row.recurrenceIdKey == null,
        );
        expect(beforeMove.recurrenceJson, contains('FREQ=DAILY;UNTIL=$until'));
        expect(beforeMove.recurrenceJson, isNot(contains('COUNT')));
        if (advanceBeforeMove) {
          expect(beforeMove.dueUtc, isNot(parent.dueUtc));
          expect(
            sourceRows.where(
              (row) =>
                  row.icalUid == parent.icalUid && row.recurrenceIdKey != null,
            ),
            hasLength(1),
          );
          if (!scenario.endsWith('explicit status')) {
            expect(beforeMove.providerStatus, parent.providerStatus);
            expect(
              beforeMove.percentComplete ?? 0,
              parent.percentComplete ?? 0,
            );
          }
        }
        await repository.moveTask(
          TaskMoveInput(
            sourceTaskListId: parent.taskListId,
            destinationTaskListId: 'dav-task-list-editor-destination',
            taskId: beforeMove.id,
          ),
        );
        await replay(2);
        expect(remote.moves, 2);
        expect(
          await harness.database.tasksDao.listTasks(
            parent.accountId,
            parent.taskListId,
          ),
          isEmpty,
        );
        final movedRows = await harness.database.tasksDao.listTasks(
          parent.accountId,
          'dav-task-list-editor-destination',
        );
        final moved = TaskEntity.fromRow(
          movedRows.singleWhere(
            (row) =>
                row.icalUid == parent.icalUid && row.recurrenceIdKey == null,
          ),
        );
        expect(moved.previousTaskListIds, contains(parent.taskListId));
        expect(moved.matchesIdentity(parent.id), isTrue);
        expect(moved.id, isNot(parent.id));
        expect(moved.dueUtc, beforeMove.dueUtc);
        final remoteBeforeSave = Map.of(remote.resources);
        await tester.pumpAndSettle();
        final movedTile = find.descendant(
          of: find.byType(AndroidScheduleScreen, skipOffstage: false).last,
          matching: _androidMutationTile(moved, skipOffstage: false),
          skipOffstage: false,
        );
        tester.widget<ListTile>(movedTile).onTap!();
        for (var attempt = 0; attempt < 20; attempt++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        }
        await tester.pumpAndSettle();
        expect(
          find.byType(AndroidTaskEditor, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Restore'), findsNothing);
        if (!notesOnly) {
          await _scrollUntilBuilt(tester, find.byType(Slider));
          expect(tester.widget<Slider>(find.byType(Slider)).value, 100);
        }
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        final afterRows = await harness.database.tasksDao.listTasks(
          parent.accountId,
          moved.taskListId,
        );
        final afterMaster = afterRows.singleWhere(
          (row) => row.icalUid == parent.icalUid && row.recurrenceIdKey == null,
        );
        final afterHistory = afterRows.where(
          (row) => row.icalUid == parent.icalUid && row.recurrenceIdKey != null,
        );
        if (scenario.startsWith('stale completion')) {
          expect(afterMaster.dueUtc, moved.dueUtc);
          expect(afterHistory, hasLength(1));
          expect(afterMaster.status, 'needsAction');
          expect(
            await harness.database.select(harness.database.pendingOps).get(),
            isEmpty,
          );
          expect(remote.resources, remoteBeforeSave);
          expect(find.byType(AndroidTaskEditor), findsOneWidget);
          expect(
            observedRepository.lastError,
            isA<TaskOccurrenceChangedException>(),
          );
          expect(
            observedRepository.lastInput!.observedOccurrenceKey,
            parent.occurrenceKey,
          );
          final retainedObserved = observedRepository.lastInput!.observedTask!;
          expect(retainedObserved.id, moved.id);
          expect(retainedObserved.taskListId, moved.taskListId);
          expect(retainedObserved.matchesIdentity(parent.id), isTrue);
          expect(
            retainedObserved.previousTaskListIds,
            contains(parent.taskListId),
          );
          expect(
            (jsonDecode(retainedObserved.providerMetadataJson!)
                as Map)['nativeDue'],
            (jsonDecode(parent.providerMetadataJson!) as Map)['nativeDue'],
          );
          expect(
            find.text(
              tester
                  .element(find.byType(AndroidTaskEditor))
                  .l10n
                  .taskDraftConflict,
            ),
            findsOneWidget,
          );
          await _scrollUntilBuilt(tester, find.byType(Slider));
          expect(tester.widget<Slider>(find.byType(Slider)).value, 100);
          await tester.pump(const Duration(milliseconds: 1100));
          final retainedRecovery = recordFor(moved.taskListId);
          expect(draftValues(retainedRecovery), draftValues(originalRecovery));
          expect(retainedRecovery['taskId'], moved.id);
          final retainedBaseline = TaskEntity.fromDraftBaselineJson(
            (retainedRecovery['observedTask'] as Map).cast<String, Object?>(),
          );
          expect(retainedBaseline.occurrenceKey, parent.occurrenceKey);
          expect(retainedBaseline.matchesIdentity(parent.id), isTrue);
          expect(
            retainedBaseline.previousTaskListIds,
            contains(parent.taskListId),
          );
          expect(
            secureStorage,
            isNot(
              contains(
                _scopedTaskRecoveryKey(
                  parent.accountId,
                  parent.taskListId,
                  parent.id,
                ),
              ),
            ),
          );
        } else {
          expect(find.byType(AndroidTaskEditor), findsNothing);
          if (notesOnly) {
            expect(
              afterMaster.notes,
              'Exact notes for the observed occurrence',
            );
            expect(afterMaster.dueUtc, moved.dueUtc);
            expect(afterHistory, hasLength(1));
            await replay(1);
          } else {
            expect(afterMaster.dueUtc, isNot(moved.dueUtc));
            expect(afterHistory, hasLength(1));
            await replay(2);
          }
          expect(
            remote.resources.values
                .singleWhere((value) => value.raw.contains('UID:parent-uid'))
                .raw,
            notesOnly
                ? contains(
                    'DESCRIPTION:Exact notes for the observed occurrence',
                  )
                : contains('RECURRENCE-ID'),
          );
          expect(
            secureStorage.keys.where(
              (key) => key.startsWith('busymax.android.task-draft.'),
            ),
            isEmpty,
          );
        }

        await harness.dispose();
      },
    );
  }

  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    testWidgets(
      'Android Schedule ${provider.name} checkbox retains the status-only completion payload',
      (tester) async {
        final received = Completer<void>();
        final release = Completer<void>();
        late _GatedTaskRepository repository;
        late TaskEntity task;
        final harness = await _pumpApp(
          tester,
          AppSettings.defaults().copyWith(
            androidScheduleViewMode: ScheduleViewMode.agenda,
          ),
          seedDatabase: (database) async {
            task = await _seedAndroidEditorTask(database, provider: provider);
          },
          taskRepository: (database, accountId) =>
              repository = _GatedTaskRepository(
                database: database,
                accountId: accountId,
                received: received,
                release: release,
              ),
        );
        addTearDown(harness.dispose);
        final tile = find.widgetWithText(ListTile, 'Editable task');
        await tester.tap(_completionControl(tile));
        await tester.pump();
        expect(received.isCompleted, isTrue);
        expect(repository.submittedFields, {'status': 'completed'});
        release.complete();
        await tester.pumpAndSettle();
        var ops = await harness.database
            .select(harness.database.pendingOps)
            .get();
        expect(jsonDecode(ops.single.requestJson), {'status': 'completed'});
        await tester.tap(_completionControl(tile));
        await tester.pumpAndSettle();
        expect(repository.submittedFields, {'status': 'needsAction'});
        ops = await harness.database.select(harness.database.pendingOps).get();
        expect(ops.map((op) => jsonDecode(op.requestJson)), [
          {'status': 'completed'},
          {'status': 'needsAction'},
        ]);
        final row = (await harness.database.tasksDao.listTasks(
          task.accountId,
          task.taskListId,
        )).single;
        expect(row.status, 'needsAction');

        await harness.dispose();
      },
    );
  }

  for (final search in [false, true]) {
    testWidgets(
      'Android Schedule ${search ? 'search' : 'agenda'} checkbox completes and reopens a DAV hierarchy',
      (tester) async {
        late TaskEntity parent;
        final harness = await _pumpApp(
          tester,
          AppSettings.defaults().copyWith(
            androidScheduleViewMode: ScheduleViewMode.agenda,
          ),
          seedDatabase: (database) async {
            parent = await _seedAndroidDavTree(database);
          },
        );
        addTearDown(harness.dispose);
        final remote = StatefulTaskDavRemote(
          await harness.database.select(harness.database.davObjects).get(),
        );
        Future<void> replayAndReload({
          required bool completed,
          required int puts,
        }) async {
          final pending = await harness.database
              .select(harness.database.pendingOps)
              .get();
          expect(pending, hasLength(2));
          for (final op in pending) {
            final candidate = DavMutationPatch.fromJsonString(
              op.mutationPatchJson!,
            ).applyTo(op.baselineRawIcs!, nowUtc: DateTime.now().toUtc());
            expect(
              candidate,
              contains(completed ? 'STATUS:COMPLETED' : 'STATUS:NEEDS-ACTION'),
            );
            expect(candidate, isNot(contains('STATUS:CANCELLED')));
          }
          final summary = await DavPendingOperationsReplayer(
            database: harness.database,
            accountId: parent.accountId,
            serviceFactory: ({required account, required collection}) async =>
                DavConditionalMutationService(remoteClient: remote),
          ).replayDueOperations();
          expect(summary.appliedCount, 2);
          expect(summary.conflictCount, 0);
          expect(summary.retryCount, 0);
          expect(remote.puts, puts);
          expect(
            remote.resources.values.map((resource) => resource.raw),
            everyElement(
              contains(completed ? 'STATUS:COMPLETED' : 'STATUS:NEEDS-ACTION'),
            ),
          );
          expect(
            await harness.database.select(harness.database.pendingOps).get(),
            isEmpty,
          );
          final reloaded = await harness.container
              .read(scheduleRepositoryProvider)
              .listAllTasks(
                filters: const ScheduleFilters(
                  includeCalendarEvents: false,
                  taskCompletion: ScheduleTaskCompletion.all,
                  showNoDateTasks: true,
                ),
              );
          expect(reloaded, hasLength(2));
          expect(
            reloaded.map((task) => task.completed),
            everyElement(completed),
          );
          await tester.pumpAndSettle();
        }

        if (search) {
          await tester.tap(find.byIcon(Icons.search));
          await tester.pumpAndSettle();
        }
        final tile = find.widgetWithText(ListTile, 'Parent');
        expect(tile, findsOneWidget);
        await tester.tap(_completionControl(tile));
        await tester.pumpAndSettle();
        var rows = await harness.database.tasksDao.listTasks(
          parent.accountId,
          parent.taskListId,
        );
        expect(rows.map((row) => row.status), everyElement('completed'));
        await replayAndReload(completed: true, puts: 2);
        final childTile = find.widgetWithText(ListTile, 'Child');
        await tester.tap(_completionControl(childTile));
        await tester.pumpAndSettle();
        rows = await harness.database.tasksDao.listTasks(
          parent.accountId,
          parent.taskListId,
        );
        expect(rows.map((row) => row.status), everyElement('needsAction'));
        expect(
          rows.map((row) => row.providerStatus),
          isNot(contains('CANCELLED')),
        );
        await replayAndReload(completed: false, puts: 4);

        await harness.dispose();
      },
    );
  }

  testWidgets(
    'R03 repeated New task activation keeps the existing creation draft owner',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      await _seedAndroidEditorTask(harness.database);
      await _openAndroidScheduleScreen(tester);
      final screen = tester.state<ConsumerState<AndroidScheduleScreen>>(
        find.byType(AndroidScheduleScreen),
      );
      final list = (await harness.container.read(
        scheduleTaskListsProvider.future,
      )).single;
      void create() => unawaited(
        showAndroidTaskEditor(
          screen.context,
          screen.ref,
          creationList: list,
          creationProvider: BusyProvider.nextcloud,
        ),
      );
      create();
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'One exact new task draft',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'One exact creation recovery',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      create();
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Restore'), findsNothing);
      expect(find.text('One exact new task draft'), findsOneWidget);
      expect(find.text('One exact creation recovery'), findsOneWidget);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'R03 differing creation date intents keep independent draft recovery and cleanup',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final task = await _seedAndroidEditorTask(harness.database);
      await _openAndroidScheduleScreen(tester);
      final screen = tester.state<ConsumerState<AndroidScheduleScreen>>(
        find.byType(AndroidScheduleScreen),
      );
      final list =
          (await harness.container
                  .read(taskListsRepositoryForAccountProvider(task.accountId))
                  .listTaskLists())
              .single;
      void create() => unawaited(
        showAndroidTaskEditor(
          screen.context,
          screen.ref,
          creationList: list,
          creationProvider: BusyProvider.nextcloud,
        ),
      );
      create();
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Default request exact draft',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Default request recovery',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      void openDated() => unawaited(
        showAndroidTaskEditor(
          screen.context,
          screen.ref,
          creationList: list,
          creationProvider: BusyProvider.nextcloud,
          initialDue: DateTime(2026, 12, 8, 9),
        ),
      );
      openDated();
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsNWidgets(2),
      );
      expect(find.text('Restore'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Dated request exact draft',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Dated request recovery',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      openDated();
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsNWidgets(2),
      );
      final notes = secureStorage.entries
          .where((entry) => entry.key.startsWith('busymax.android.task-draft.'))
          .map((entry) => (jsonDecode(entry.value) as Map)['notes']);
      expect(
        notes,
        containsAll(['Default request recovery', 'Dated request recovery']),
      );
      create();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Dated request exact draft'), findsOneWidget);
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsNWidgets(2),
      );
      create();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Default request exact draft'), findsOneWidget);
      expect(
        secureStorage.entries
            .where(
              (entry) => entry.key.startsWith('busymax.android.task-draft.'),
            )
            .map((entry) => (jsonDecode(entry.value) as Map)['notes']),
        contains('Default request recovery'),
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android rapid task row activations share one loading editor and recovery owner',
    (tester) async {
      final release = Completer<void>();
      late _GatedTaskReadRepository repository;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) =>
            repository = _GatedTaskReadRepository(
              database: database,
              accountId: accountId,
              release: release,
            ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openAndroidScheduleScreen(tester);
      final task = find.widgetWithText(ListTile, 'Original move task');
      await tester.tap(task);
      await tester.pumpAndSettle();
      final edit = tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.edit_outlined),
          )
          .onPressed!;
      edit();
      edit();
      await tester.pump();
      release.complete();
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Only active owner',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      expect(
        (jsonDecode(
          secureStorage[_scopedTaskRecoveryKey(
            'google:move',
            'source-list',
            'move-task',
          )]!,
        ) as Map)['notes'],
        'Only active owner',
      );
      expect(repository.reads, 1);

      await harness.dispose();
    },
  );

  testWidgets(
    'Android concurrent acknowledged aliases converge on the first task editor reservation',
    (tester) async {
      final client = _AndroidTaskIdentityClient();
      final release = Completer<void>();
      late _GatedTaskReadRepository repository;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) =>
            repository = _GatedTaskReadRepository(
              database: database,
              accountId: accountId,
              release: release,
              apiClient: client,
            ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      final tasks = harness.container.read(
        tasksRepositoryForAccountProvider('google:move'),
      );
      final temporaryId = await tasks.createTask(
        'source-list',
        const TaskCreateInput(title: 'Acknowledged owner'),
      );
      await _openAndroidScheduleScreen(tester);
      final tile = find.widgetWithText(ListTile, 'Acknowledged owner');
      final oldOpen = tester.widget<ListTile>(tile).onTap!;
      client.releaseCreation.complete();
      expect(
        await PendingOpsReplayer(
          database: harness.database,
          apiClient: client,
          accountId: 'google:move',
        ).replayDueOps(),
        1,
      );
      await tester.pumpAndSettle();
      final acknowledged = (await harness.database.tasksDao.listTasks(
        'google:move',
        'source-list',
      )).singleWhere((row) => row.id == 'server-created-task');
      expect(
        TaskEntity.fromRow(acknowledged).matchesIdentity(temporaryId),
        isTrue,
      );
      final acknowledgedOpen = tester.widget<ListTile>(tile).onTap!;
      oldOpen();
      await tester.pumpAndSettle();
      final edit = find.byTooltip('Edit Task');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pump();
      acknowledgedOpen();
      await tester.pump();
      release.complete();
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsOneWidget,
      );
      expect(repository.reads, 2);
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'One verified alias owner',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final ops = await harness.database
          .select(harness.database.pendingOps)
          .get();
      expect(ops, hasLength(1));
      expect(ops.single.taskId, 'server-created-task');
      expect(ops.single.requestJson, isNot(contains(temporaryId)));
      await tester.tap(tile);
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('One verified alias owner'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);

      await harness.dispose();
    },
  );

  testWidgets(
    'Android top-level reopening a hidden parent preserves the child dirty guard',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      await _seedAndroidDavTree(harness.database);
      await _openAndroidScheduleScreen(tester);
      final parent = find.widgetWithText(ListTile, 'Parent');
      final reopenParent = tester.widget<ListTile>(parent).onTap!;
      await tester.tap(parent);
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Parent retained',
      );
      final child = find.widgetWithText(ListTile, 'Child');
      await _scrollUntilBuilt(tester, child);
      await tester.tap(child);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Child retained',
      );
      reopenParent();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Child retained'), findsOneWidget);
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsNWidgets(2),
      );
      reopenParent();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsOneWidget,
      );
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, 5000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Parent retained'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'R03 a verified moved task reuses its mounted draft owner and cleans only its migrated recovery',
    (tester) async {
      final client = _AndroidRecoveryMoveClient();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => TasksRepository(
          database: database,
          accountId: accountId,
          apiClient: client,
        ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openAndroidScheduleScreen(tester);
      await tester.tap(find.widgetWithText(ListTile, 'Original move task'));
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Exact mounted draft through movement',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final sourceKey = _scopedTaskRecoveryKey(
        'google:move',
        'source-list',
        'move-task',
      );
      expect(secureStorage, contains(sourceKey));
      await harness.container
          .read(tasksRepositoryForAccountProvider('google:move'))
          .moveTask(
            const TaskMoveInput(
              sourceTaskListId: 'source-list',
              destinationTaskListId: 'destination-list',
              taskId: 'move-task',
            ),
          );
      expect(
        await PendingOpsReplayer(
          database: harness.database,
          apiClient: client,
          accountId: 'google:move',
        ).replayDueOps(),
        1,
      );
      expect(await _taskRow(harness.database, 'source-list'), isNull);
      await tester.pumpAndSettle();
      final movedRow = find.descendant(
        of: find.byType(AndroidScheduleScreen, skipOffstage: false).last,
        matching: find.widgetWithText(
          ListTile,
          'Original move task',
          skipOffstage: false,
        ),
        skipOffstage: false,
      );
      final reopen = tester.widget<ListTile>(movedRow).onTap!;
      reopen();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Restore'), findsNothing);
      expect(find.text('Exact mounted draft through movement'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Destination list'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      final destinationKey = _scopedTaskRecoveryKey(
        'google:move',
        'destination-list',
        'move-task',
      );
      expect(secureStorage, isNot(contains(sourceKey)));
      expect(
        (jsonDecode(secureStorage[destinationKey]!) as Map)['notes'],
        'Exact mounted draft through movement',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final operation = await harness.database
          .select(harness.database.pendingOps)
          .getSingle();
      expect(operation.taskListId, 'destination-list');
      expect(jsonDecode(operation.requestJson), {
        'notes': 'Exact mounted draft through movement',
      });
      await tester.pump(const Duration(milliseconds: 2200));
      expect(secureStorage, isNot(contains(sourceKey)));
      expect(secureStorage, isNot(contains(destinationKey)));

      await harness.dispose();
    },
  );

  for (final differentAccount in [false, true]) {
    testWidgets(
      'Android identified editor reservations keep equal IDs in different ${differentAccount ? 'accounts' : 'lists'} independent',
      (tester) async {
        final harness = await _pumpApp(tester, AppSettings.defaults());
        addTearDown(harness.dispose);
        await _seedMovableTask(harness.database);
        final otherAccount = differentAccount
            ? 'google:other-owner'
            : 'google:move';
        final otherList = differentAccount
            ? 'source-list'
            : 'other-destination-list';
        if (differentAccount) {
          await harness.database
              .into(harness.database.accounts)
              .insert(
                AccountsCompanion.insert(
                  id: otherAccount,
                  provider: 'google',
                  authority: 'https://accounts.google.com',
                  providerAccountId: 'other-owner',
                  credentialKind: 'oauth',
                  authState: const Value('signed_in'),
                  displayName: const Value('Other account'),
                  createdAtUtc: '2026-08-01T00:00:00Z',
                  updatedAtUtc: '2026-08-01T00:00:00Z',
                ),
              );
          await harness.database.taskListsDao.upsertTaskList(
            TaskListsCompanion.insert(
              accountId: otherAccount,
              id: otherList,
              title: 'Other owner list',
              rawJson: '{}',
              createdLocalAtUtc: '2026-08-01T00:00:00Z',
              updatedLocalAtUtc: '2026-08-01T00:00:00Z',
            ),
          );
        }
        await harness.database.tasksDao.upsertTask(
          TasksCompanion.insert(
            accountId: otherAccount,
            taskListId: otherList,
            id: 'move-task',
            title: 'Independent task',
            rawJson: '{}',
            createdLocalAtUtc: '2026-08-01T00:00:00Z',
            updatedLocalAtUtc: '2026-08-01T00:00:00Z',
          ),
        );
        await _openAndroidScheduleScreen(tester);
        final openOther = tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Independent task'))
            .onTap!;
        await tester.tap(find.widgetWithText(ListTile, 'Original move task'));
        await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Notes'),
          'First account draft',
        );
        await tester.pump(const Duration(milliseconds: 1100));
        openOther();
        await _pumpUntilFound(tester, find.text('Independent task'));
        await tester.pumpAndSettle();
        final unexpectedRecovery = find.text('Restore').evaluate().isNotEmpty;
        if (unexpectedRecovery) {
          // Continue through the currently incorrect cross-scope prompt so the
          // regression also exercises the later writer and cleanup outcomes.
          await tester.tap(find.widgetWithText(TextButton, 'Discard'));
          await tester.pumpAndSettle();
        }
        expect(
          find.byType(AndroidTaskEditor, skipOffstage: false),
          findsNWidgets(2),
        );
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Title'))
              .controller!
              .text,
          'Independent task',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Notes'),
          'Other account draft',
        );
        await tester.pump(const Duration(milliseconds: 1100));
        final beforeCleanup = Map<String, String>.of(secureStorage);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
        await tester.pumpAndSettle();
        final afterCleanup = Map<String, String>.of(secureStorage);
        List<Map> records(Map<String, String> source) => [
          for (final entry in source.entries)
            if (entry.key.startsWith('busymax.android.task-draft.') &&
                jsonDecode(entry.value) is Map)
              jsonDecode(entry.value) as Map,
        ];
        final firstBefore = records(beforeCleanup).where(
          (record) =>
              record['accountId'] == 'google:move' &&
              record['taskListId'] == 'source-list',
        );
        final secondBefore = records(beforeCleanup).where(
          (record) =>
              record['accountId'] == otherAccount &&
              record['taskListId'] == otherList,
        );
        expect(
          firstBefore.map((record) => record['notes']),
          contains('First account draft'),
        );
        expect(
          secondBefore.map((record) => record['notes']),
          contains('Other account draft'),
        );
        expect(
          records(afterCleanup)
              .where(
                (record) =>
                    record['accountId'] == 'google:move' &&
                    record['taskListId'] == 'source-list',
              )
              .map((record) => record['notes']),
          contains('First account draft'),
        );
        expect(
          records(afterCleanup).where(
            (record) =>
                record['accountId'] == otherAccount &&
                record['taskListId'] == otherList,
          ),
          isEmpty,
        );
        expect(unexpectedRecovery, isFalse);
        expect(
          find.byType(AndroidTaskEditor, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Title'))
              .controller!
              .text,
          'Original move task',
        );
        expect(
          await harness.database.select(harness.database.pendingOps).get(),
          isEmpty,
        );

        await harness.dispose();
      },
    );
  }

  testWidgets(
    'R03 a foreign current-v2 canonical record survives another list save failure and discard',
    (tester) async {
      final received = Completer<void>();
      final release = Completer<void>()..complete();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => _GatedTaskRepository(
          database: database,
          accountId: accountId,
          received: received,
          release: release,
          failFirst: true,
        ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      final source = TaskEntity.fromRow(
        (await _taskRow(harness.database, 'source-list'))!,
      );
      const canonicalKey = 'busymax.android.task-draft.google:move.move-task';
      final canonicalRecord = jsonEncode({
        'v': 2,
        'savedAt': DateTime.now().toIso8601String(),
        'accountId': source.accountId,
        'taskListId': source.taskListId,
        'taskId': source.id,
        'baseTitle': source.title,
        'title': source.title,
        'notes': 'Foreign canonical exact notes',
        'observedTask': source.toDraftBaselineJson(),
      });
      secureStorage[canonicalKey] = canonicalRecord;
      await harness.database.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: 'google:move',
          taskListId: 'other-destination-list',
          id: 'move-task',
          title: 'Independent task',
          rawJson: '{}',
          createdLocalAtUtc: '2026-08-01T00:00:00Z',
          updatedLocalAtUtc: '2026-08-01T00:00:00Z',
        ),
      );
      await _openAndroidScheduleScreen(tester);
      await tester.tap(find.widgetWithText(ListTile, 'Independent task'));
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      expect(find.text('Restore'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Other scoped exact notes',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(received.isCompleted, isTrue);
      expect(find.textContaining('Local persistence failed'), findsOneWidget);
      expect(secureStorage[canonicalKey], canonicalRecord);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .controller!
            .text,
        'Other scoped exact notes',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(secureStorage[canonicalKey], canonicalRecord);
      expect(
        secureStorage,
        isNot(
          contains(
            _scopedTaskRecoveryKey(
              'google:move',
              'other-destination-list',
              'move-task',
            ),
          ),
        ),
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await tester.tap(find.widgetWithText(ListTile, 'Original move task'));
      await _pumpUntilFound(tester, find.text('Restore'));
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .controller!
            .text,
        'Foreign canonical exact notes',
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'R03 equal IDs in different live lists restore their own exact drafts after restart',
    (tester) async {
      Future<void> seed(AppDatabase database) async {
        await _seedMovableTask(database);
        await database.tasksDao.upsertTask(
          TasksCompanion.insert(
            accountId: 'google:move',
            taskListId: 'other-destination-list',
            id: 'move-task',
            title: 'Independent task',
            rawJson: '{}',
            createdLocalAtUtc: '2026-08-01T00:00:00Z',
            updatedLocalAtUtc: '2026-08-01T00:00:00Z',
          ),
        );
      }

      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        seedDatabase: seed,
      );
      addTearDown(harness.dispose);
      await _openAndroidScheduleScreen(tester);
      final openOther = tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Independent task'))
          .onTap!;
      await tester.tap(find.widgetWithText(ListTile, 'Original move task'));
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'First scope durable exact notes',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      openOther();
      await _pumpUntilFound(tester, find.text('Independent task'));
      await tester.pumpAndSettle();
      expect(find.text('Restore'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Second scope durable exact notes',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      expect(
        (jsonDecode(
          secureStorage[_scopedTaskRecoveryKey(
            'google:move',
            'source-list',
            'move-task',
          )]!,
        ) as Map)['notes'],
        'First scope durable exact notes',
      );
      expect(
        (jsonDecode(
          secureStorage[_scopedTaskRecoveryKey(
            'google:move',
            'other-destination-list',
            'move-task',
          )]!,
        ) as Map)['notes'],
        'Second scope durable exact notes',
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await harness.dispose();
      final restarted = await _pumpApp(
        tester,
        AppSettings.defaults(),
        seedDatabase: seed,
      );
      addTearDown(restarted.dispose);
      await _openAndroidScheduleScreen(tester);
      await tester.tap(find.widgetWithText(ListTile, 'Original move task'));
      await _pumpUntilFound(tester, find.text('Restore'));
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .controller!
            .text,
        'First scope durable exact notes',
      );
      expect(find.text('Second scope durable exact notes'), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      final otherKey = _scopedTaskRecoveryKey(
        'google:move',
        'other-destination-list',
        'move-task',
      );
      expect(
        (jsonDecode(secureStorage[otherKey]!) as Map)['notes'],
        'Second scope durable exact notes',
      );
      await tester.tap(find.widgetWithText(ListTile, 'Independent task'));
      await _pumpUntilFound(tester, find.text('Restore'));
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .controller!
            .text,
        'Second scope durable exact notes',
      );
      expect(find.text('First scope durable exact notes'), findsNothing);
      expect(
        await restarted.database.select(restarted.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'R03 late top-level child opening reuses the hierarchy editor after its completed list read',
    (tester) async {
      late _GatedCompletedTaskListReadRepository lists;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskListsRepository: (database, accountId) =>
            lists = _GatedCompletedTaskListReadRepository(
              database: database,
              accountId: accountId,
            ),
      );
      addTearDown(harness.dispose);
      await _seedAndroidDavTree(harness.database);
      await _openAndroidScheduleScreen(tester);
      final openChild = tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Child'))
          .onTap!;
      await tester.tap(find.widgetWithText(ListTile, 'Parent'));
      await _pumpUntilFound(tester, find.byType(AndroidTaskEditor));
      await tester.pumpAndSettle();
      lists.arm = true;
      addTearDown(() {
        if (!lists.release.isCompleted) {
          lists.release.complete();
        }
      });
      openChild();
      for (var i = 0; i < 100 && !lists.entered.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(lists.entered.isCompleted, isTrue);
      final childLink = find.widgetWithText(ListTile, 'Child');
      await _scrollUntilBuilt(tester, childLink);
      await tester.tap(childLink);
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsNWidgets(2),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Hierarchy child exact draft',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      lists.release.complete();
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsNWidgets(2),
      );
      expect(find.text('Restore'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Notes'))
            .controller!
            .text,
        'Hierarchy child exact draft',
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android hierarchy returns to the existing parent draft instead of creating another recovery owner',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final parent = await _seedAndroidDavTree(harness.database);
      await _openAndroidTaskEditor(tester, parent, BusyProvider.nextcloud);
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Parent L1',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final child = find.widgetWithText(ListTile, 'Child');
      await _scrollUntilBuilt(tester, child);
      await tester.tap(child);
      await tester.pumpAndSettle();
      final parentLink = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.title is Text &&
            (widget.title! as Text).data == 'Parent',
      );
      await _scrollUntilBuilt(tester, parentLink);
      await tester.tap(parentLink);
      await tester.pumpAndSettle();
      expect(find.text('Restore'), findsNothing);
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsOneWidget,
      );
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, 5000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Parent L1'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Parent L2',
      );
      await tester.pump(const Duration(milliseconds: 2200));
      final key = _scopedTaskRecoveryKey(
        parent.accountId,
        parent.taskListId,
        parent.id,
      );
      expect((jsonDecode(secureStorage[key]!) as Map)['notes'], 'Parent L2');
      final route = ModalRoute.of(
        tester.element(find.byType(AndroidTaskEditor)),
      )!;
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .removeRoute(route);
      await tester.pumpAndSettle();
      await _openAndroidTaskEditor(tester, parent, BusyProvider.nextcloud);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Parent L2'), findsOneWidget);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  for (final save in [false, true]) {
    testWidgets(
      'Android hierarchy sole recovery owner drains an old write before ${save ? 'Save' : 'Discard'} cleanup',
      (tester) async {
        final oldWrite = Completer<void>();
        final releaseOldWrite = Completer<void>();
        addTearDown(() {
          if (!releaseOldWrite.isCompleted) {
            releaseOldWrite.complete();
          }
        });
        final harness = await _pumpApp(tester, AppSettings.defaults());
        addTearDown(harness.dispose);
        final parent = await _seedAndroidDavTree(harness.database);
        final key = _scopedTaskRecoveryKey(
          parent.accountId,
          parent.taskListId,
          parent.id,
        );
        final writes = <String>[];
        messenger.setMockMethodCallHandler(secureStorageChannel, (call) async {
          final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
          final storageKey = args['key']?.toString();
          if (call.method == 'read') {
            return secureStorage[storageKey];
          }
          if (call.method == 'delete') {
            secureStorage.remove(storageKey);
          } else if (call.method == 'write') {
            final raw = args['value']!.toString();
            if (storageKey == key) {
              final notes = (jsonDecode(raw) as Map)['notes']!.toString();
              writes.add(notes);
              if (notes == 'Parent L1' && !oldWrite.isCompleted) {
                oldWrite.complete();
                await releaseOldWrite.future;
              }
            }
            secureStorage[storageKey!] = raw;
          }
          return null;
        });
        await _openAndroidTaskEditor(tester, parent, BusyProvider.nextcloud);
        await tester.enterText(
          find.widgetWithText(TextField, 'Notes'),
          'Parent L1',
        );
        await tester.pump(const Duration(milliseconds: 1100));
        expect(oldWrite.isCompleted, isTrue);
        final child = find.widgetWithText(ListTile, 'Child');
        await _scrollUntilBuilt(tester, child);
        await tester.tap(child);
        await tester.pumpAndSettle();
        final parentLink = find.byWidgetPredicate(
          (widget) =>
              widget is ListTile &&
              widget.title is Text &&
              (widget.title! as Text).data == 'Parent',
        );
        await _scrollUntilBuilt(tester, parentLink);
        await tester.tap(parentLink);
        await tester.pumpAndSettle();
        expect(
          find.byType(AndroidTaskEditor, skipOffstage: false),
          findsOneWidget,
        );
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, 5000),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Notes'),
          'Parent L2',
        );
        await tester.pump(const Duration(milliseconds: 1100));
        expect(writes, ['Parent L1']);
        if (save) {
          await tester.tap(find.widgetWithText(TextButton, 'Save'));
          await tester.pump(const Duration(milliseconds: 100));
        } else {
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
          await tester.pump(const Duration(milliseconds: 100));
        }
        releaseOldWrite.complete();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        expect(
          find.byType(SnackBar),
          findsNothing,
          reason: find
              .byType(SnackBar)
              .evaluate()
              .map((element) => (element.widget as SnackBar).content.toString())
              .join(', '),
        );
        expect(secureStorage, isNot(contains(key)));
        expect(find.byType(AndroidTaskEditor), findsNothing);
        final rows = await harness.database.tasksDao.listTasks(
          parent.accountId,
          parent.taskListId,
        );
        expect(
          rows.singleWhere((row) => row.id == parent.id).notes,
          save ? 'Parent L2' : isNull,
        );
        final ops = await harness.database
            .select(harness.database.pendingOps)
            .get();
        expect(ops, hasLength(save ? 1 : 0));

        await harness.dispose();
      },
    );
  }

  testWidgets(
    'Android hierarchy returning to an ancestor honors the child dirty-close cancellation',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final parent = await _seedAndroidDavTree(harness.database);
      await _openAndroidTaskEditor(tester, parent, BusyProvider.nextcloud);
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Parent draft',
      );
      final child = find.widgetWithText(ListTile, 'Child');
      await _scrollUntilBuilt(tester, child);
      await tester.tap(child);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Child draft',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final parentLink = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.title is Text &&
            (widget.title! as Text).data == 'Parent',
      );
      await _scrollUntilBuilt(tester, parentLink);
      await tester.tap(parentLink);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsNWidgets(2),
      );
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, 5000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Child draft'), findsOneWidget);
      final records = secureStorage.values.map((raw) => jsonDecode(raw) as Map);
      expect(
        records.map((record) => record['notes']),
        containsAll(['Parent draft', 'Child draft']),
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  for (final malformed in [null, 'categories', 'pendingMoveDestinationId']) {
    testWidgets(
      'Android ${malformed == null ? 'discarded review-only' : 'malformed $malformed'} recovery leaves a fresh editable baseline',
      (tester) async {
        final harness = await _pumpApp(tester, AppSettings.defaults());
        addTearDown(harness.dispose);
        await _seedMovableTask(harness.database);
        const key = 'busymax.android.task-draft.google:move.move-task';
        secureStorage[key] = jsonEncode({
          'v': 2,
          'savedAt': DateTime.now().toIso8601String(),
          'accountId': 'google:move',
          'taskId': 'move-task',
          'taskListId': 'source-list',
          'baseTitle': 'Original move task',
          'title': 'Recovered old title',
          'notes': 'Recovered old notes',
          if (malformed == 'categories') 'categories': 'invalid-list',
          if (malformed == 'pendingMoveDestinationId')
            'pendingMoveDestinationId': 42,
        });
        await _openMovableTaskEditor(tester, _movableTask());
        if (malformed == null) {
          await tester.tap(find.widgetWithText(TextButton, 'Discard'));
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.widgetWithText(TextField, 'Notes'),
          'Fresh notes after recovery rejection',
        );
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        final task = await _taskRow(harness.database, 'source-list');
        expect(task!.title, 'Original move task');
        expect(task.notes, 'Fresh notes after recovery rejection');
        final operations = await harness.database
            .select(harness.database.pendingOps)
            .get();
        expect(operations, hasLength(1));
        final payload = jsonDecode(operations.single.requestJson) as Map;
        expect(payload['notes'], 'Fresh notes after recovery rejection');
        expect(payload, isNot(contains('title')));

        await harness.dispose();
      },
    );
  }

  testWidgets(
    'Android read-only DAV hierarchy remains navigable with mutation controls disabled',
    (tester) async {
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        davTaskCapabilities: nextcloudTaskCollectionCapabilities.asReadOnly(),
      );
      addTearDown(harness.dispose);
      final parent = await _seedAndroidDavTree(
        harness.database,
        readOnly: true,
      );
      await _openAndroidTaskEditor(tester, parent, BusyProvider.nextcloud);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
      final child = find.widgetWithText(ListTile, 'Child');
      await _scrollUntilBuilt(tester, child);
      expect(_completionAction(tester, child), isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Create subtask'),
            )
            .onPressed,
        isNull,
      );
      expect(find.widgetWithText(OutlinedButton, 'Delete task'), findsNothing);
      await tester.tap(child);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, 5000),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Title'))
            .controller!
            .text,
        'Child',
      );
      final parentLink = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.title is Text &&
            (widget.title! as Text).data == 'Parent',
      );
      await _scrollUntilBuilt(tester, parentLink);
      await tester.tap(parentLink);
      await tester.pumpAndSettle();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      expect(secureStorage, isEmpty);

      await harness.dispose();
    },
  );

  testWidgets(
    'Android Nextcloud root and subtask checkboxes use the percentage hierarchy lifecycle',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final parent = await _seedAndroidDavTree(harness.database);
      await _openAndroidScheduleScreen(tester);
      final parentTile = find.widgetWithText(ListTile, 'Parent');
      await tester.tap(_completionControl(parentTile));
      await tester.pumpAndSettle();
      var rows = await harness.database.tasksDao.listTasks(
        parent.accountId,
        parent.taskListId,
      );
      expect(rows.map((row) => row.status), everyElement('completed'));
      expect(rows.map((row) => row.percentComplete), everyElement(100));
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        hasLength(2),
      );
      final currentParent = TaskEntity.fromRow(
        rows.singleWhere((row) => row.title == 'Parent'),
      );
      await _openAndroidTaskEditor(
        tester,
        currentParent,
        BusyProvider.nextcloud,
      );
      final child = find.widgetWithText(ListTile, 'Child');
      await _scrollUntilBuilt(tester, child);
      await tester.tap(_completionControl(child));
      await tester.pumpAndSettle();
      rows = await harness.database.tasksDao.listTasks(
        parent.accountId,
        parent.taskListId,
      );
      expect(rows.map((row) => row.status), everyElement('needsAction'));
      expect(rows.map((row) => row.percentComplete), everyElement(isNull));
      expect(rows.map((row) => row.completedUtc), everyElement(isNull));
      expect(
        rows.map((row) => row.providerStatus),
        isNot(contains('CANCELLED')),
      );
      final operations = await harness.database
          .select(harness.database.pendingOps)
          .get();
      expect(operations, hasLength(2));
      expect(operations.map((op) => op.davObjectId).toSet(), hasLength(2));
      for (final operation in operations) {
        final patch = jsonDecode(operation.mutationPatchJson!) as Map;
        final progress = (patch['operations'] as List).whereType<Map>().where(
          (entry) => entry['type'] == 'setTaskProgress',
        );
        expect(progress.map((entry) => entry['percentComplete']), [100, 0]);
      }

      await harness.dispose();
    },
  );

  testWidgets(
    'Android retries only the move after Save committed and move failed',
    (tester) async {
      late _FailFirstMoveTaskRepository repository;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) =>
            repository = _FailFirstMoveTaskRepository(
              database: database,
              accountId: accountId,
            ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openMovableTaskEditor(tester, _movableTask());
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Durably edited title',
      );
      final move = find.widgetWithText(ListTile, 'List');
      await _scrollUntilBuilt(tester, move);
      await tester.tap(move);
      await _pumpUntilFound(tester, find.text('Destination list'));
      await tester.tap(find.text('Destination list'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsOneWidget);
      expect(
        find.text(
          'Your edits were saved, but the task could not be moved. Retry the move.',
        ),
        findsOneWidget,
      );
      var row = await _taskRow(harness.database, 'source-list');
      expect(row!.title, 'Durably edited title');
      expect(row.notes, 'Concurrent untouched notes');
      expect(
        (await harness.database.select(harness.database.pendingOps).get()).map(
          (op) => op.operation,
        ),
        ['patch_task'],
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsNothing);
      row = await _taskRow(harness.database, 'destination-list');
      expect(row!.title, 'Durably edited title');
      expect(row.notes, 'Concurrent untouched notes');
      expect(
        (await harness.database.select(harness.database.pendingOps).get()).map(
          (op) => op.operation,
        ),
        ['patch_task', 'move_task'],
      );
      expect(repository.moveCalls, 2);

      await harness.dispose();
    },
  );

  for (final patchCommitted in [false, true]) {
    for (final cancelMove in [false, true]) {
      testWidgets(
        'Android failed move ${patchCommitted ? 'after' : 'before'} patch commit allows ${cancelMove ? 'cancelling only the move' : 'another destination'}',
        (tester) async {
          late _FailedMoveChoiceRepository repository;
          final harness = await _pumpApp(
            tester,
            AppSettings.defaults(),
            taskRepository: (database, accountId) =>
                repository = _FailedMoveChoiceRepository(
                  database: database,
                  accountId: accountId,
                  failFirstPatch: !patchCommitted,
                ),
          );
          addTearDown(harness.dispose);
          await _seedMovableTask(harness.database);
          await _openMovableTaskEditor(tester, _movableTask());
          await tester.enterText(
            find.widgetWithText(TextField, 'Title'),
            'Retained task edit',
          );
          final move = find.widgetWithText(ListTile, 'List');
          await _scrollUntilBuilt(tester, move);
          await tester.tap(move);
          await _pumpUntilFound(tester, find.text('Destination list'));
          await tester.tap(find.text('Destination list'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Save'));
          await tester.pumpAndSettle();
          expect(find.byType(AndroidTaskEditor), findsOneWidget);
          await tester.tap(move);
          await tester.pumpAndSettle();
          expect(find.text('Other destination list'), findsOneWidget);
          await tester.tap(
            find
                .text(cancelMove ? 'Source list' : 'Other destination list')
                .last,
          );
          await tester.pumpAndSettle();
          if (cancelMove) {
            expect(find.byType(AndroidTaskEditor), findsOneWidget);
            await tester.tap(find.widgetWithText(TextButton, 'Save'));
          } else {
            await tester.tap(find.widgetWithText(TextButton, 'Save'));
          }
          await tester.pumpAndSettle();
          final rows = await harness.database.tasksDao.listTasks(
            'google:move',
            cancelMove ? 'source-list' : 'other-destination-list',
          );
          expect(rows.single.title, 'Retained task edit');
          final ops = await harness.database
              .select(harness.database.pendingOps)
              .get();
          expect(ops.where((op) => op.operation == 'patch_task'), hasLength(1));
          expect(
            ops.where((op) => op.operation == 'move_task'),
            hasLength(cancelMove ? 0 : 1),
          );
          expect(repository.patchCalls, patchCommitted ? 1 : 2);
          expect(
            repository.moveDestinations,
            patchCommitted
                ? [
                    'destination-list',
                    if (!cancelMove) 'other-destination-list',
                  ]
                : [if (!cancelMove) 'other-destination-list'],
          );

          await harness.dispose();
        },
      );
    }
  }

  for (final removeDestination in [false, true]) {
    testWidgets(
      'Android failed move recovery ${removeDestination ? 'chooses a surviving destination' : 'can cancel only its restored move'}',
      (tester) async {
        late _FailFirstMoveTaskRepository repository;
        final harness = await _pumpApp(
          tester,
          AppSettings.defaults(),
          taskRepository: (database, accountId) =>
              repository = _FailFirstMoveTaskRepository(
                database: database,
                accountId: accountId,
              ),
        );
        addTearDown(harness.dispose);
        await _seedMovableTask(harness.database);
        await _openMovableTaskEditor(tester, _movableTask());
        await tester.enterText(
          find.widgetWithText(TextField, 'Title'),
          'Committed before recovery',
        );
        final move = find.widgetWithText(ListTile, 'List');
        await _scrollUntilBuilt(tester, move);
        await tester.tap(move);
        await _pumpUntilFound(tester, find.text('Destination list'));
        await tester.tap(find.text('Destination list'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        final key = _scopedTaskRecoveryKey(
          'google:move',
          'source-list',
          'move-task',
        );
        expect(
          (jsonDecode(secureStorage[key]!) as Map)['pendingMoveDestinationId'],
          'destination-list',
        );
        final route = ModalRoute.of(
          tester.element(find.byType(AndroidTaskEditor)),
        )!;
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .removeRoute(route);
        await tester.pumpAndSettle();
        if (removeDestination) {
          await (harness.database.update(harness.database.taskLists)
                ..where((row) => row.id.equals('destination-list')))
              .write(const TaskListsCompanion(pendingDelete: Value(true)));
        }
        final row = (await _taskRow(harness.database, 'source-list'))!;
        await _openMovableTaskEditor(tester, TaskEntity.fromRow(row));
        await tester.tap(find.text('Restore'));
        await tester.pumpAndSettle();
        if (removeDestination) {
          await _scrollUntilBuilt(tester, move);
          await tester.tap(move);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Other destination list').last);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Save'));
        } else {
          await _scrollUntilBuilt(tester, move);
          await tester.tap(move);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Source list').last);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Save'));
        }
        await tester.pumpAndSettle();
        final saved = (await _taskRow(
          harness.database,
          removeDestination ? 'other-destination-list' : 'source-list',
        ))!;
        expect(saved.title, 'Committed before recovery');
        expect(saved.notes, 'Concurrent untouched notes');
        final ops = await harness.database
            .select(harness.database.pendingOps)
            .get();
        expect(ops.where((op) => op.operation == 'patch_task'), hasLength(1));
        expect(
          ops.where((op) => op.operation == 'move_task'),
          hasLength(removeDestination ? 1 : 0),
        );
        expect(repository.moveCalls, removeDestination ? 2 : 1);
        expect(secureStorage, isNot(contains(key)));

        await harness.dispose();
      },
    );
  }

  testWidgets(
    'Android hierarchy navigation is blocked while the submitted task draft persists',
    (tester) async {
      final received = Completer<void>();
      final release = Completer<void>();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => _GatedTaskRepository(
          database: database,
          accountId: accountId,
          received: received,
          release: release,
        ),
      );
      addTearDown(harness.dispose);
      final parent = await _seedAndroidDavTree(harness.database);
      await _openAndroidTaskEditor(tester, parent, BusyProvider.nextcloud);
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Submitted parent title',
      );
      final child = find.widgetWithText(ListTile, 'Child');
      await _scrollUntilBuilt(tester, child);
      final staleOpen = tester.widget<ListTile>(child).onTap!;
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();
      expect(received.isCompleted, isTrue);
      expect(tester.widget<ListTile>(child).onTap, isNull);
      staleOpen();
      await tester.pump();
      expect(
        find.byType(AndroidTaskEditor, skipOffstage: false),
        findsOneWidget,
      );
      release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsNothing);
      final rows = await harness.database.tasksDao.listTasks(
        parent.accountId,
        parent.taskListId,
      );
      expect(
        rows.singleWhere((row) => row.id == parent.id).title,
        'Submitted parent title',
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android task list refresh error retains cached tasks and selected filters',
    (tester) async {
      late _AndroidRetryScheduleRepository schedule;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        scheduleRepository: (database) =>
            schedule = _AndroidRetryScheduleRepository(database),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openAndroidScheduleScreen(tester);
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      final filter = tester.widget<AndroidScheduleSearchFilters>(
        find.byType(AndroidScheduleSearchFilters),
      );
      filter.onChanged(
        filter.value.copyWith(
          taskListKeys: {
            const ScheduleTaskListKey(
              accountId: 'google:move',
              taskListId: 'source-list',
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextField),
        ),
        'Original',
      );
      await tester.pumpAndSettle();
      schedule.fail = true;
      await (harness.database.update(harness.database.tasks)
            ..where((row) => row.id.equals('move-task')))
          .write(const TasksCompanion(notes: Value('Remote refresh notes')));
      await tester.pumpAndSettle();
      expect(find.text('Original move task'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Source list · Move account'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      schedule.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Original move task'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.textContaining('Source list · Move account'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AndroidScheduleSearchFilters>(
              find.byType(AndroidScheduleSearchFilters),
            )
            .value
            .taskListKeys,
        filter.value
            .copyWith(
              taskListKeys: {
                const ScheduleTaskListKey(
                  accountId: 'google:move',
                  taskListId: 'source-list',
                ),
              },
            )
            .taskListKeys,
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android editor keeps title and notes through cloud creation acknowledgement',
    (tester) async {
      final client = _AndroidTaskIdentityClient();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => TasksRepository(
          database: database,
          accountId: accountId,
          apiClient: client,
        ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      final repository = harness.container.read(
        tasksRepositoryForAccountProvider('google:move'),
      );
      final tempId = await repository.createTask(
        'source-list',
        const TaskCreateInput(title: 'New task'),
      );
      final task = (await repository.readTask('source-list', tempId))!;
      final replay = PendingOpsReplayer(
        database: harness.database,
        apiClient: client,
        accountId: task.accountId,
      ).replayDueOps();
      await client.creationReceived.future;
      await _openMovableTaskEditor(tester, task);
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Draft title after create',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Draft notes after create',
      );
      client.releaseCreation.complete();
      expect(await replay, 1);
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsOneWidget);
      expect(find.text('Draft title after create'), findsOneWidget);
      expect(find.text('Draft notes after create'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final operation =
          (await harness.database.select(harness.database.pendingOps).get())
              .single;
      expect(operation.taskId, 'server-created-task');
      expect(operation.requestJson, isNot(contains(tempId)));
      expect(jsonDecode(operation.requestJson), {
        'title': 'Draft title after create',
        'notes': 'Draft notes after create',
      });
      expect(
        await PendingOpsReplayer(
          database: harness.database,
          apiClient: client,
          accountId: task.accountId,
        ).replayDueOps(),
        1,
      );
      expect(client.task!['title'], 'Draft title after create');
      expect(client.task!['notes'], 'Draft notes after create');
      expect(client.mutations, ['create', 'patch:server-created-task']);

      await harness.dispose();
    },
  );

  testWidgets(
    'Android recovery follows a verified temporary identity after restart',
    (tester) async {
      final client = _AndroidTaskIdentityClient();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => TasksRepository(
          database: database,
          accountId: accountId,
          apiClient: client,
        ),
      );
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      final repository = harness.container.read(
        tasksRepositoryForAccountProvider('google:move'),
      );
      final tempId = await repository.createTask(
        'source-list',
        const TaskCreateInput(title: 'New task'),
      );
      final task = (await repository.readTask('source-list', tempId))!;
      await _openMovableTaskEditor(tester, task);
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Recovery notes for acknowledged task',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final oldKey = _scopedTaskRecoveryKey(
        'google:move',
        'source-list',
        tempId,
      );
      expect(secureStorage, contains(oldKey));
      client.releaseCreation.complete();
      expect(
        await PendingOpsReplayer(
          database: harness.database,
          apiClient: client,
          accountId: task.accountId,
        ).replayDueOps(),
        1,
      );
      final acknowledged = (await harness.database.tasksDao.listTasks(
        task.accountId,
        task.taskListId,
      )).singleWhere((row) => row.id == 'server-created-task');
      await harness.dispose();
      final restarted = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(restarted.dispose);
      await _seedMovableTask(restarted.database);
      await restarted.database.tasksDao.upsertTask(
        acknowledged.toCompanion(true),
      );
      await _openMovableTaskEditor(tester, TaskEntity.fromRow(acknowledged));
      expect(find.text('Restore'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Recovery notes for acknowledged task'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final operation =
          (await restarted.database.select(restarted.database.pendingOps).get())
              .single;
      expect(operation.taskId, 'server-created-task');
      expect(operation.requestJson, isNot(contains(tempId)));
      expect(secureStorage, isNot(contains(oldKey)));
      expect(
        secureStorage,
        isNot(
          contains(
            _scopedTaskRecoveryKey(
              'google:move',
              'source-list',
              'server-created-task',
            ),
          ),
        ),
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android checklist rename failure retains the input and retry queues one operation',
    (tester) async {
      final client = _AndroidChecklistClient();
      late _FailFirstChecklistEditRepository repository;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) =>
            repository = _FailFirstChecklistEditRepository(
              database: database,
              accountId: accountId,
              apiClient: client,
            ),
      );
      addTearDown(harness.dispose);
      final task = await _seedAndroidChecklistTask(harness.database, client);
      await _openAndroidTaskEditor(tester, task, BusyProvider.microsoft);
      await _openChecklistAction(tester, 'Rename');
      await tester.enterText(
        find.byKey(const ValueKey('android-checklist-title')),
        'Retain rename',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('android-checklist-title')),
        findsOneWidget,
      );
      expect(find.text('Retain rename'), findsOneWidget);
      expect(
        find.textContaining('Checklist local commit failed'),
        findsOneWidget,
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(
        find.byKey(const ValueKey('android-checklist-title')),
        findsNothing,
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        hasLength(1),
      );
      expect(
        await PendingOpsReplayer(
          database: harness.database,
          apiClient: client,
          accountId: task.accountId,
        ).replayDueOps(),
        1,
      );
      expect(client.items['step-1']!['displayName'], 'Retain rename');

      await harness.dispose();
    },
  );

  testWidgets(
    'Android checklist pending create then rename replays with the acknowledged step identity',
    (tester) async {
      final client = _AndroidChecklistClient();
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        taskRepository: (database, accountId) => TasksRepository(
          database: database,
          accountId: accountId,
          apiClient: client,
        ),
      );
      addTearDown(harness.dispose);
      final task = await _seedAndroidChecklistTask(harness.database, client);
      await _openAndroidTaskEditor(tester, task, BusyProvider.microsoft);
      final create = find.widgetWithText(OutlinedButton, 'Create subtask');
      await _scrollUntilBuilt(tester, create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'New checklist step',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();
      var row = (await harness.database.tasksDao.listTasks(
        task.accountId,
        task.taskListId,
      )).single;
      final temporary = decodeTaskChecklistItems(
        row.microsoftChecklistItemsJson,
      ).singleWhere((item) => item.title == 'New checklist step');
      final actions = find.byKey(
        ValueKey('android-checklist-actions-${temporary.id}'),
      );
      await _scrollUntilBuilt(tester, actions);
      await tester.tap(actions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('android-checklist-title')),
        'Renamed before acknowledgement',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final pending = await harness.database
          .select(harness.database.pendingOps)
          .get();
      expect(pending.map((op) => op.operation), [
        'create_task_checklist_item',
        'patch_task_checklist_item',
      ]);
      expect(
        await PendingOpsReplayer(
          database: harness.database,
          apiClient: client,
          accountId: task.accountId,
        ).replayDueOps(),
        2,
      );
      row = (await harness.database.tasksDao.listTasks(
        task.accountId,
        task.taskListId,
      )).single;
      final acknowledged = decodeTaskChecklistItems(
        row.microsoftChecklistItemsJson,
      ).singleWhere((item) => item.title == 'Renamed before acknowledgement');
      expect(acknowledged.id, 'server-step-3');
      expect(acknowledged.matchesIdentity(temporary.id), isTrue);
      expect(
        client.items['server-step-3']!['displayName'],
        'Renamed before acknowledgement',
      );
      expect(client.mutations, ['create:server-step-3', 'patch:server-step-3']);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android Save protects the observed title and explicit server choice permits another edit',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openMovableTaskEditor(tester, _movableTask());
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Local title C',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final recoveryKey = _scopedTaskRecoveryKey(
        'google:move',
        'source-list',
        'move-task',
      );
      await (harness.database.update(
        harness.database.tasks,
      )..where((row) => row.id.equals('move-task'))).write(
        const TasksCompanion(
          title: Value('Remote title B'),
          rawJson: Value('{"id":"move-task","title":"Remote title B"}'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Local title C'), findsOneWidget);
      expect(
        (await _taskRow(harness.database, 'source-list'))!.title,
        'Remote title B',
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      expect(find.text('Keep server version'), findsOneWidget);
      await tester.tap(find.text('Keep server version'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Local title C'), findsOneWidget);
      expect(secureStorage, contains(recoveryKey));
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep server version'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Remote title B'), findsOneWidget);
      expect(secureStorage, isNot(contains(recoveryKey)));
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'After explicit resolution',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final op =
          (await harness.database.select(harness.database.pendingOps).get())
              .single;
      expect(jsonDecode(op.requestJson), {
        'title': 'After explicit resolution',
      });
      expect(
        (jsonDecode(op.baselineRawJson!) as Map)['title'],
        'Remote title B',
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android Save merges a remote notes change outside the edited title',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openMovableTaskEditor(tester, _movableTask());
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Local title C',
      );
      await (harness.database.update(
        harness.database.tasks,
      )..where((row) => row.id.equals('move-task'))).write(
        const TasksCompanion(
          notes: Value('Remote notes R'),
          rawJson: Value(
            '{"id":"move-task","title":"Original move task","notes":"Remote notes R"}',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final row = await _taskRow(harness.database, 'source-list');
      expect(row!.title, 'Local title C');
      expect(row.notes, 'Remote notes R');
      final op =
          (await harness.database.select(harness.database.pendingOps).get())
              .single;
      expect(jsonDecode(op.requestJson), {'title': 'Local title C'});
      expect(
        (jsonDecode(op.baselineRawJson!) as Map)['notes'],
        'Remote notes R',
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android recovered notes keep their original comparison when remote notes changed',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openMovableTaskEditor(tester, _movableTask());
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Recovered local notes L',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      await harness.dispose();
      final restarted = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(restarted.dispose);
      await _seedMovableTask(restarted.database);
      await (restarted.database.update(restarted.database.tasks)
            ..where((row) => row.id.equals('move-task')))
          .write(const TasksCompanion(notes: Value('Remote notes R')));
      final changed = TaskEntity.fromRow(
        (await _taskRow(restarted.database, 'source-list'))!,
      );
      await _openMovableTaskEditor(tester, changed);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Recovered local notes L'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Recovered local notes L'), findsOneWidget);
      expect(
        (await _taskRow(restarted.database, 'source-list'))!.notes,
        'Remote notes R',
      );
      expect(
        await restarted.database.select(restarted.database.pendingOps).get(),
        isEmpty,
      );
      expect(
        find.text(
          'This task changed since you opened it. Your edits are retained. Review the latest task before retrying.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final saved = jsonDecode(
        secureStorage[_scopedTaskRecoveryKey(
          'google:move',
          'source-list',
          'move-task',
        )]!,
      ) as Map;
      expect((saved['observedTask'] as Map)['notes'], isNull);
      expect((saved['originalObservedTask'] as Map)['notes'], isNull);
      expect(saved['notes'], 'Recovered local notes L');

      await harness.dispose();
    },
  );

  testWidgets(
    'Android task recurrence dates and exclusions stay read only during unrelated edits',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      const raw =
          '{"rules":["FREQ=DAILY;UNTIL=20260812T090000Z"],"dates":["20260820T090000Z"],"excludedDates":["20260805T090000Z"]}';
      final task = await _seedAndroidEditorTask(
        harness.database,
        due: '2026-08-01T09:00:00',
        recurrence: raw,
      );
      await _openAndroidTaskEditor(tester, task, BusyProvider.nextcloud);
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Unrelated note',
      );
      final recurrence = find.byKey(
        const ValueKey('android-task-advanced-recurrence'),
      );
      await _scrollUntilBuilt(tester, recurrence);
      expect(tester.widget<ListTile>(recurrence).enabled, isFalse);
      await tester.tap(recurrence);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final row = (await harness.database.tasksDao.listTasks(
        task.accountId,
        task.taskListId,
      )).single;
      expect(row.recurrenceJson, raw);
      expect(row.notes, 'Unrelated note');
      final operation =
          (await harness.database.select(harness.database.pendingOps).get())
              .single;
      expect(jsonDecode(operation.requestJson), {'notes': 'Unrelated note'});

      await harness.dispose();
    },
  );

  testWidgets(
    'Android task recurrence displays an existing timed UNTIL in its anchor zone',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      const raw =
          '{"rules":["FREQ=DAILY;UNTIL=20260813T023000Z"],"dates":[],"excludedDates":[]}';
      final task = await _seedAndroidEditorTask(
        harness.database,
        due: '2026-08-01T19:30:00',
        timeZone: 'America/Vancouver',
        recurrence: raw,
      );
      await _openAndroidTaskEditor(tester, task, BusyProvider.nextcloud);
      final recurrence = find.byKey(
        const ValueKey('android-task-advanced-recurrence'),
      );
      await _scrollUntilBuilt(tester, recurrence);
      await tester.tap(recurrence);
      await tester.pumpAndSettle();
      expect(find.text('8/12/2026'), findsOneWidget);
      expect(find.text('2026-08-13'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final row = (await harness.database.tasksDao.listTasks(
        task.accountId,
        task.taskListId,
      )).single;
      expect(row.recurrenceJson, raw);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  testWidgets(
    'Android recovery without an exact baseline stays review-only and retains original content',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await (harness.database.update(
        harness.database.tasks,
      )..where((row) => row.id.equals('move-task'))).write(
        const TasksCompanion(
          title: Value('Remote title B'),
          notes: Value('Remote notes R'),
        ),
      );
      const key = 'busymax.android.task-draft.google:move.move-task';
      secureStorage[key] = jsonEncode({
        'v': 2,
        'savedAt': DateTime.now().toIso8601String(),
        'accountId': 'google:move',
        'taskListId': 'source-list',
        'baseTitle': 'Original title A',
        'title': 'Original title A',
        'notes': 'Recoverable notes L',
      });
      final task = TaskEntity.fromRow(
        (await _taskRow(harness.database, 'source-list'))!,
      );
      await _openMovableTaskEditor(tester, task);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Remote title B'), findsOneWidget);
      expect(find.text('Recoverable notes L'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsOneWidget);
      expect(find.text('Recoverable notes L'), findsOneWidget);
      expect(find.text('Keep server version'), findsOneWidget);
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      expect(
        (await _taskRow(harness.database, 'source-list'))!.notes,
        'Remote notes R',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      final retainedKey = _scopedTaskRecoveryKey(
        'google:move',
        'source-list',
        'move-task',
      );
      expect(secureStorage, isNot(contains(key)));
      final retained = jsonDecode(secureStorage[retainedKey]!) as Map;
      expect(retained['baseTitle'], 'Original title A');
      expect(retained['notes'], 'Recoverable notes L');
      expect(retained.containsKey('observedTask'), isFalse);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(secureStorage, contains(retainedKey));
      expect(find.text('Recoverable notes L'), findsOneWidget);

      await harness.dispose();
    },
  );

  for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
    testWidgets(
      'Android ${provider.name} checkbox retains the existing status-only cloud payload',
      (tester) async {
        final harness = await _pumpApp(tester, AppSettings.defaults());
        addTearDown(harness.dispose);
        final task = await _seedAndroidEditorTask(
          harness.database,
          provider: provider,
        );
        await _openAndroidScheduleScreen(tester);
        final tile = find.widgetWithText(ListTile, 'Editable task');
        await tester.tap(_completionControl(tile));
        await tester.pumpAndSettle();
        var operations = await harness.database
            .select(harness.database.pendingOps)
            .get();
        expect(operations, hasLength(1));
        expect(jsonDecode(operations.single.requestJson), {
          'status': 'completed',
        });
        var row = (await harness.database.tasksDao.listTasks(
          task.accountId,
          task.taskListId,
        )).single;
        expect(row.status, 'completed');
        await tester.tap(_completionControl(tile));
        await tester.pumpAndSettle();
        operations = await harness.database
            .select(harness.database.pendingOps)
            .get();
        expect(operations.map((op) => jsonDecode(op.requestJson)), [
          {'status': 'completed'},
          {'status': 'needsAction'},
        ]);
        row = (await harness.database.tasksDao.listTasks(
          task.accountId,
          task.taskListId,
        )).single;
        expect(row.status, 'needsAction');

        await harness.dispose();
      },
    );
  }

  testWidgets('dirty task save-and-move persists edits before moving', (
    tester,
  ) async {
    final mutationCallbacks = <String>[];
    var editorPresentAtCommit = false;
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    await _seedMovableTask(harness.database);
    expect(
      await harness.database.taskListsDao.listTaskLists('google:move'),
      hasLength(3),
    );
    await tester.pump();
    await _openMovableTaskEditor(
      tester,
      _movableTask(),
      onMutationStarted: (result) => mutationCallbacks.add('started'),
      onMutationCommitted: (result) {
        mutationCallbacks.add('committed');
        editorPresentAtCommit = find
            .byType(AndroidTaskEditor)
            .evaluate()
            .isNotEmpty;
      },
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Edited before move',
    );
    await tester.pump();
    final move = find.widgetWithText(ListTile, 'List');
    await _scrollUntilBuilt(tester, move);
    expect(tester.widget<ListTile>(move).onTap, isNot(equals(null)));
    tester.widget<ListTile>(move).onTap!();
    await _pumpUntilFound(tester, find.text('Destination list'));
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Destination list'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AndroidTaskEditor), findsNothing);
    final row = await (harness.database.select(
      harness.database.tasks,
    )..where((task) => task.id.equals('move-task'))).getSingle();
    expect(row.title, 'Edited before move');
    expect(row.taskListId, 'destination-list');
    expect(mutationCallbacks, ['started', 'committed']);
    expect(editorPresentAtCommit, isTrue);
    final operations = await harness.database
        .select(harness.database.pendingOps)
        .get();
    expect(
      operations.map((operation) => operation.operation),
      containsAllInOrder(['patch_task', 'move_task']),
    );
    expect(
      secureStorage,
      isNot(
        contains(
          _scopedTaskRecoveryKey('google:move', 'source-list', 'move-task'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('cancelling a dirty task move preserves the draft', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    await _seedMovableTask(harness.database);
    await tester.pump();
    await _openMovableTaskEditor(tester, _movableTask());

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Unsaved move edit',
    );
    await tester.pump();
    final move = find.widgetWithText(ListTile, 'List');
    await _scrollUntilBuilt(tester, move);
    tester.widget<ListTile>(move).onTap!();
    await _pumpUntilFound(tester, find.text('Destination list'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AndroidTaskEditor), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, 1200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unsaved move edit'), findsOneWidget);
    final row = await (harness.database.select(
      harness.database.tasks,
    )..where((task) => task.id.equals('move-task'))).getSingle();
    expect(row.title, 'Original move task');
    expect(row.taskListId, 'source-list');
    expect(
      await harness.database.select(harness.database.pendingOps).get(),
      isEmpty,
    );
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('failed task move retains editor state and recovery', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    await _seedMovableTask(harness.database, includeSource: false);
    await tester.pump();
    await _openMovableTaskEditor(
      tester,
      _movableTask(taskListId: 'missing-source'),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Recover after move failure',
    );
    await tester.pump(const Duration(milliseconds: 1100));
    final recoveryKey = _scopedTaskRecoveryKey(
      'google:move',
      'missing-source',
      'move-task',
    );
    expect(secureStorage, contains(recoveryKey));
    final move = find.widgetWithText(ListTile, 'List');
    await _scrollUntilBuilt(tester, move);
    tester.widget<ListTile>(move).onTap!();
    await _pumpUntilFound(tester, find.text('Destination list'));
    await tester.tap(find.text('Destination list'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AndroidTaskEditor), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, 1200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recover after move failure'), findsOneWidget);
    expect(secureStorage, contains(recoveryKey));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('calendar administration requests prompt pending sync', (
    tester,
  ) async {
    var syncRequests = 0;
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      seedDatabase: _seedCalendarAdministration,
      onCalendarSync: (_) async => syncRequests += 1,
    );
    addTearDown(harness.dispose);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => const AndroidSettingsScreen(
              category: AndroidSettingsCategory.accounts,
            ),
          ),
        );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ListTile, 'Administration account').first,
    );
    await tester.pumpAndSettle();
    final source = find.text('Administration calendar');
    await _scrollUntilBuilt(tester, source);
    await tester.tap(source);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Renamed calendar');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(syncRequests, 1);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );

    final renamed = find.text('Renamed calendar');
    await _scrollUntilBuilt(tester, renamed);
    await tester.tap(renamed);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Calendar color'));
    await tester.tap(find.text('Calendar color'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Color 1'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(syncRequests, 2);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await harness.database.delete(harness.database.pendingOps).go();

    await _scrollUntilBuilt(tester, renamed);
    await tester.tap(renamed);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    expect(syncRequests, 3);
    expect(find.text('Renamed calendar'), findsNothing);
    final row = await harness.database
        .select(harness.database.calendarSources)
        .getSingle();
    expect(row.isDeleted, isTrue);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });

  testWidgets('Android sharing entry opens owner calendar permissions', (
    tester,
  ) async {
    var permissionReads = 0;
    final sharingClient = GoogleCalendarApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/acl')) {
          permissionReads++;
          return http.Response(jsonEncode({'items': <Object>[]}), 200);
        }
        return http.Response('unexpected request', 404);
      }),
      baseUri: Uri.parse('https://www.googleapis.com'),
    );
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      seedDatabase: _seedCalendarAdministration,
      googleSharingClient: sharingClient,
    );
    addTearDown(harness.dispose);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => const AndroidSettingsScreen(
              category: AndroidSettingsCategory.accounts,
            ),
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ListTile, 'Administration account').first,
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(
      const Key('android-manage-sharing-google:administration'),
    );
    await _scrollUntilBuilt(tester, entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Manage calendar sharing'), findsWidgets);
    expect(find.byKey(const Key('calendar-sharing-recipient')), findsOneWidget);
    expect(permissionReads, 1);

    await harness.dispose();
  });

  testWidgets(
    'Android opened Microsoft calendar removal is local and cancellable',
    (tester) async {
      final key = const MicrosoftSharedPrimaryCalendarAddress(
        owner: 'owner@example.test',
        graphCalendarId: 'owner-primary',
      ).sourceCalendarId;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults(),
        seedDatabase: (database) async {
          await database
              .into(database.accounts)
              .insert(
                AccountsCompanion.insert(
                  id: 'microsoft:owner',
                  provider: 'microsoft',
                  authority: 'https://login.microsoftonline.com/common',
                  providerAccountId: 'recipient',
                  credentialKind: 'oauth',
                  authState: const Value('signed_in'),
                  calendarsEnabled: const Value(true),
                  createdAtUtc: '2026-09-14T00:00:00Z',
                  updatedAtUtc: '2026-09-14T00:00:00Z',
                ),
              );
          await CalendarRepository(database: database).upsertSource(
            accountId: 'microsoft:owner',
            source: CalendarSourceDto(
              provider: BusyProvider.microsoft,
              providerCalendarId: key,
              summary: 'Owner calendar',
              readOnly: false,
              isRemovable: true,
            ),
          );
        },
      );
      addTearDown(harness.dispose);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => const AndroidSettingsScreen(
                category: AndroidSettingsCategory.accounts,
              ),
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Microsoft').first);
      await tester.pumpAndSettle();

      await _scrollUntilBuilt(tester, find.text('Owner calendar'));
      await tester.tap(find.text('Owner calendar').first);
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Calendar color'), findsNothing);
      await tester.tap(find.text('Remove from my calendars'));
      await tester.pumpAndSettle();
      expect(find.textContaining('will not be deleted'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(
        (await harness.database
                .select(harness.database.calendarSources)
                .getSingle())
            .isDeleted,
        isFalse,
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );
      await tester.tap(find.text('Owner calendar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from my calendars'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(
        (await harness.database
                .select(harness.database.calendarSources)
                .getSingle())
            .isDeleted,
        isTrue,
      );
      expect(
        await harness.database.select(harness.database.pendingOps).get(),
        isEmpty,
      );

      await harness.dispose();
    },
  );

  for (final provider in [BusyProvider.caldav, BusyProvider.nextcloud]) {
    for (final action in ['edit', 'add', 'delete', 'title']) {
      for (final blockedChannel in [false, true]) {
        testWidgets(
          'Android $provider $action reminder keeps sibling alarms (blocked channel: $blockedChannel)',
          (tester) async {
            if (blockedChannel) {
              messenger.setMockMethodCallHandler(
                platformChannel,
                (call) async => switch (call.method) {
                  'notificationCapabilities' => {
                    'notifications': true,
                    'reminders': false,
                    'summaries': true,
                    'status': true,
                  },
                  'googleAuthorizationAvailable' ||
                  'microsoftAuthorizationAvailable' => false,
                  _ => null,
                },
              );
            }
            final tomorrow = DateTime.now().toUtc().add(
              const Duration(days: 1),
            );
            final start = DateTime.utc(
              tomorrow.year,
              tomorrow.month,
              tomorrow.day,
              16,
            );
            final end = start.add(const Duration(hours: 1));
            String icsDate(DateTime value) =>
                '${value.toUtc().toIso8601String().split('.').first.replaceAll('-', '').replaceAll(':', '')}Z';
            const accountId = 'nextcloud:event-reminders';
            const collectionId = 'reminders-collection';
            const href = '/remote.php/dav/calendars/user/work/';
            late CalendarSourceEntity seededSource;
            late EventEditorDraft seededDraft;
            late String seededEventId;
            final raw =
                'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n'
                'UID:reminders@example.test\r\nDTSTART:${icsDate(start)}\r\n'
                'DTEND:${icsDate(end)}\r\nSUMMARY:Reminders\r\n'
                'CATEGORIES:one\\,two,雪\r\n'
                'BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT15M\r\n'
                'DESCRIPTION:First\r\nX-KEEP:first\r\nEND:VALARM\r\n'
                'BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT30M\r\n'
                'DESCRIPTION:Second\r\nX-KEEP:second\r\nEND:VALARM\r\n'
                'BEGIN:VALARM\r\nACTION:DISPLAY\r\n'
                'TRIGGER;RELATED=END:-PT0M\r\n'
                'DESCRIPTION:At end\r\nX-KEEP:end\r\nEND:VALARM\r\n'
                'BEGIN:VALARM\r\nACTION:AUDIO\r\nTRIGGER:-PT5M\r\n'
                'X-KEEP:audio\r\nEND:VALARM\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
            final harness = await _pumpApp(
              tester,
              AppSettings.defaults(),
              notificationBackend: _PermissionOnlyNotifications(),
              onCalendarSync: (_) async {},
              seedDatabase: (database) async {
                await tester.runAsync(() async {
                  await database
                      .into(database.accounts)
                      .insert(
                        AccountsCompanion.insert(
                          id: accountId,
                          provider: provider.storageValue,
                          authority: 'https://cloud.example.test',
                          providerAccountId: 'user',
                          credentialKind: provider == BusyProvider.caldav
                              ? 'caldav_password'
                              : 'nextcloud_app_password',
                          authState: const Value('signed_in'),
                          createdAtUtc: start.toIso8601String(),
                          updatedAtUtc: start.toIso8601String(),
                        ),
                      );
                  await database
                      .into(database.davCollections)
                      .insert(
                        DavCollectionsCompanion.insert(
                          id: collectionId,
                          accountId: accountId,
                          hrefKey: href,
                          requestUri: 'https://cloud.example.test$href',
                          displayName: 'Work',
                          supportedComponentMask: const Value(1),
                          currentUserPrivilegesJson: const Value(
                            '["{DAV:}read","{DAV:}write"]',
                          ),
                          readOnly: const Value(false),
                          eventProjectionEnabled: const Value(true),
                          createdAtUtc: start.toIso8601String(),
                          updatedAtUtc: start.toIso8601String(),
                        ),
                      );
                  await database
                      .into(database.calendarSources)
                      .insert(
                        CalendarSourcesCompanion.insert(
                          id: 'dav-calendar-$collectionId',
                          accountId: accountId,
                          provider: provider.storageValue,
                          providerCalendarId: href,
                          davCollectionId: const Value(collectionId),
                          summary: 'Work',
                          createdAtLocal: 0,
                          updatedAtLocal: 0,
                        ),
                      );
                  final prepared = DavPreparedObject.parse(
                    hrefKey: '${href}reminders.ics',
                    requestUri: Uri.parse(
                      'https://cloud.example.test${href}reminders.ics',
                    ),
                    etag: '"v1"',
                    contentType: 'text/calendar',
                    rawIcsBody: raw,
                  );
                  await DavObjectRepository(database: database).commit(
                    DavCollectionCommit(
                      accountId: accountId,
                      collectionId: collectionId,
                      provider: provider,
                      objects: [prepared],
                      deletedHrefKeys: const {},
                      completeMembership: true,
                      membershipHrefKeys: {prepared.hrefKey},
                      finalCursorKind: 'dav_sync_token',
                      finalCursorValue: 'sync-1',
                      baselineGeneration: 1,
                      completedAtUtc: DateTime.now().toUtc(),
                      projectionRangeStartUtc: start.subtract(
                        const Duration(days: 1),
                      ),
                      projectionRangeEndUtc: end.add(const Duration(days: 1)),
                    ),
                  );
                  final repository = CalendarRepository(database: database);
                  seededSource = (await repository.watchSourcesForAccounts([
                    accountId,
                  ]).first).single;
                  seededEventId =
                      (await database
                              .select(database.calendarEvents)
                              .getSingle())
                          .id;
                  seededDraft = EventEditorDraft.fromEventDetail(
                    (await repository.loadEventDetail(seededEventId))!,
                  );
                });
              },
            );
            addTearDown(harness.dispose);
            final repository = CalendarRepository(database: harness.database);
            expect(seededSource.capabilities.canEditEvents, isTrue);
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: harness.container,
                child: localizedTestApp(
                  child: const Scaffold(body: Text('Editor host')),
                ),
              ),
            );
            tester
                .state<NavigatorState>(find.byType(Navigator).first)
                .push<void>(
                  MaterialPageRoute(
                    builder: (_) => AndroidEventEditor(
                      sources: [seededSource],
                      draft: seededDraft,
                    ),
                  ),
                );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            if (action == 'title') {
              await tester.enterText(
                find.byType(TextFormField).first,
                'Unrelated title change',
              );
            }
            final second = find.byKey(
              const Key('android-event-dav-reminder-1'),
            );
            await _scrollUntilBuilt(tester, second);
            expect(
              find.byKey(const Key('android-event-dav-reminder-0')),
              findsOneWidget,
            );
            switch (action) {
              case 'title':
                break;
              case 'edit':
                tester
                    .widget<DropdownButtonFormField<int>>(second)
                    .onChanged!
                    .call(45);
              case 'add':
                await _scrollUntilBuilt(tester, find.text('Add Reminder'));
                await tester.tap(find.text('Add Reminder'));
              case 'delete':
                final row = find
                    .ancestor(of: second, matching: find.byType(Row))
                    .first;
                await tester.tap(
                  find.descendant(
                    of: row,
                    matching: find.byTooltip('Remove reminder'),
                  ),
                );
            }
            await tester.pump();
            await tester.tap(find.widgetWithText(TextButton, 'Save'));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(AndroidEventEditor), findsNothing);
            final operations = (await tester.runAsync(
              () => harness.database.select(harness.database.pendingOps).get(),
            ))!;
            expect(operations, hasLength(1));
            expect(operations.single.operationType, 'dav.update');
            final queuedBody =
                DavMutationPatch.fromJsonString(
                  operations.single.mutationPatchJson!,
                ).applyTo(
                  operations.single.baselineRawIcs!,
                  nowUtc: DateTime.now().toUtc(),
                );
            expect(
              find.text(
                blockedChannel
                    ? 'Android is blocking notifications or a notification category. Your reminders are saved. Review system notification settings.'
                    : 'Notification delivery status is unavailable. Review system settings.',
              ),
              action == 'title' ? findsNothing : findsOneWidget,
            );
            if (action == 'edit') {
              expect(queuedBody, contains('TRIGGER:-PT45M'));
            }
            if (action == 'add') {
              expect(queuedBody, contains('TRIGGER:-PT10M'));
            }
            expect(
              queuedBody,
              contains(r'CATEGORIES:one\,two,雪'),
              reason: 'Unchanged comma-containing categories retain their original values.',
            );
            expect(queuedBody, contains('X-KEEP:first'));
            expect(
              queuedBody,
              action == 'delete'
                  ? isNot(contains('X-KEEP:second'))
                  : contains('X-KEEP:second'),
            );
            expect(queuedBody, contains('TRIGGER;RELATED=END:-PT0M'));
            expect(queuedBody, contains('X-KEEP:end'));
            expect(queuedBody, contains('X-KEEP:audio'));
            final updated = (await tester.runAsync(
              () => repository.loadEventDetail(seededEventId),
            ))!;
            final editedRows = androidNextcloudEditableReminderRows(
              updated.reminders,
            )!;
            expect(editedRows.map((row) => row.minutes), switch (action) {
              'edit' => [15, 45],
              'add' => [15, 30, 10],
              'title' => [15, 30],
              _ => [15],
            });
            expect(jsonEncode(updated.reminders), contains('X-KEEP'));
            expect(tester.takeException(), isNull);

            await harness.dispose();
          },
        );
      }
    }
  }
  testWidgets('Android event label selection queues the scoped ID', (
    tester,
  ) async {
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      seedDatabase: _seedCalendarAdministration,
      googleLabels: const [
        GoogleEventLabel(
          id: 'label-1',
          name: 'Project',
          backgroundColor: '#336699',
        ),
      ],
    );
    addTearDown(harness.dispose);
    const source = CalendarSourceEntity(
      id: 'administration-calendar',
      accountId: 'google:administration',
      provider: BusyProvider.google,
      providerCalendarId: 'administration-calendar',
      summary: 'Administration calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
      accessRole: 'owner',
    );
    final now = DateTime.now().add(const Duration(hours: 1));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidEventEditor(
              sources: const [source],
              draft: EventEditorDraft.newEvent(
                accountId: source.accountId,
                sourceId: source.id,
                providerCalendarId: source.providerCalendarId,
                start: now,
                end: now.add(const Duration(hours: 1)),
              ).copyWith(title: 'Planning'),
            ),
          ),
        );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final selector = find.byKey(
      const Key('android-event-label-administration-calendar'),
    );
    await _scrollUntilBuilt(tester, selector);
    expect(tester.takeException(), isNull);
    tester
        .widget<DropdownButtonFormField<String>>(selector)
        .onChanged!
        .call('label-1');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    final ops = await harness.database
        .select(harness.database.pendingOps)
        .get();
    expect(ops, hasLength(1));
    expect(jsonDecode(ops.single.requestJson)['eventLabelId'], 'label-1');
    await tester.pump(const Duration(seconds: 6));

    await harness.dispose();
  });

  testWidgets('Android primary Google editor queues native focus time', (
    tester,
  ) async {
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      seedDatabase: _seedGoogleStatusCalendar,
      googleLabels: const [],
    );
    addTearDown(harness.dispose);
    const source = CalendarSourceEntity(
      id: 'status-calendar',
      accountId: 'google:status',
      provider: BusyProvider.google,
      providerCalendarId: 'status-calendar',
      summary: 'Primary',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
      primaryCalendar: true,
      accessRole: 'owner',
    );
    final now = DateTime.now().add(const Duration(hours: 1));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidEventEditor(
              sources: const [source],
              draft: EventEditorDraft.newEvent(
                accountId: source.accountId,
                sourceId: source.id,
                providerCalendarId: source.providerCalendarId,
                start: now,
                end: now.add(const Duration(hours: 1)),
              ).copyWith(title: 'Focus'),
            ),
          ),
        );
    await tester.pumpAndSettle();
    final type = find.byKey(const Key('android-google-event-type'));
    await _scrollUntilBuilt(tester, type);
    tester
        .widget<DropdownButtonFormField<String>>(type)
        .onChanged!
        .call('focusTime');
    await tester.pumpAndSettle();
    final decline = find.byKey(const Key('android-google-auto-decline'));
    await _scrollUntilBuilt(tester, decline);
    tester
        .widget<DropdownButtonFormField<String>>(decline)
        .onChanged!
        .call('declineOnlyNewConflictingInvitations');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    final request = jsonDecode(
      (await harness.database.select(harness.database.pendingOps).getSingle())
          .requestJson,
    ) as Map;
    expect(request['eventType'], 'focusTime');
    expect(
      (request['googleStatusProperties'] as Map)['autoDeclineMode'],
      'declineOnlyNewConflictingInvitations',
    );
    await tester.pump(const Duration(seconds: 6));

    await harness.dispose();
  });

  testWidgets('Android Microsoft category choice queues all assignments', (
    tester,
  ) async {
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      seedDatabase: _seedMicrosoftCategoryCalendar,
      microsoftCategories: const [
        MicrosoftMasterCategory(
          id: 'category-1',
          displayName: 'Work',
          color: 'preset7',
        ),
      ],
    );
    addTearDown(harness.dispose);
    const source = CalendarSourceEntity(
      id: 'microsoft-category-calendar',
      accountId: 'microsoft:categories',
      provider: BusyProvider.microsoft,
      providerCalendarId: 'calendar',
      summary: 'Work calendar',
      selected: true,
      hidden: false,
      readOnly: false,
      isDeleted: false,
    );
    final now = DateTime.now().add(const Duration(hours: 1));
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => AndroidEventEditor(
              sources: const [source],
              draft: EventEditorDraft.newEvent(
                accountId: source.accountId,
                sourceId: source.id,
                providerCalendarId: source.providerCalendarId,
                start: now,
                end: now.add(const Duration(hours: 1)),
              ).copyWith(title: 'Planning', categories: ['Unknown']),
            ),
          ),
        );
    await tester.pumpAndSettle();
    final option = find.widgetWithText(FilterChip, 'Work');
    await _scrollUntilBuilt(tester, option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    final request = jsonDecode(
      (await harness.database.select(harness.database.pendingOps).getSingle())
          .requestJson,
    ) as Map;
    expect(request['categoriesJson'], ['Unknown', 'Work']);
    await tester.pump(const Duration(seconds: 6));

    await harness.dispose();
  });

  testWidgets('Android feedback preserves failure and rotates edited retry', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'BusyMax',
      packageName: 'io.busystack.busymax',
      version: '0.2.4',
      buildNumber: '4',
      buildSignature: '',
    );
    final feedback = _RecordingFeedbackService();
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults(),
      feedbackService: feedback,
    );
    addTearDown(harness.dispose);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push<void>(
          MaterialPageRoute(builder: (_) => const AndroidFeedbackScreen()),
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<FeedbackCategory>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Problem or bug').last);
    await tester.enterText(
      find.byKey(const ValueKey('android-feedback-subject')),
      'First subject',
    );
    await tester.enterText(
      find.byKey(const ValueKey('android-feedback-message')),
      'A detailed failure message',
    );
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(feedback.submissions, hasLength(1));
    final firstId = feedback.submissions.single.submissionId;
    expect(
      find.textContaining('could not accept your feedback'),
      findsOneWidget,
    );
    expect(find.text('A detailed failure message'), findsOneWidget);

    feedback.fail = false;
    await tester.enterText(
      find.byKey(const ValueKey('android-feedback-subject')),
      'Edited subject',
    );
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(feedback.submissions, hasLength(2));
    expect(feedback.submissions.last.submissionId, isNot(firstId));
    expect(find.textContaining('feedback-test-receipt'), findsOneWidget);
    expect(find.text('A detailed failure message'), findsNothing);
    expect(tester.takeException(), isNull);

    await harness.dispose();
  });
}

String _scopedTaskRecoveryKey(
  String accountId,
  String taskListId,
  String taskId,
) =>
    'busymax.android.task-draft.v2.'
    '${base64Url.encode(utf8.encode(jsonEncode([accountId, taskListId, taskId])))}';

Future<void> _pumpAndSettleGraphIo(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

TaskEntity _movableTask({String taskListId = 'source-list'}) => TaskEntity(
  accountId: 'google:move',
  taskListId: taskListId,
  id: 'move-task',
  title: 'Original move task',
  localDirty: false,
  pendingDelete: false,
  pendingMove: false,
  rawJson: '{}',
  updatedLocalAtUtc: '2026-09-14T00:00:00.000Z',
);

Future<void> _openMovableTaskEditor(
  WidgetTester tester,
  TaskEntity task, {
  ValueChanged<AndroidTaskEditorResult>? onMutationStarted,
  ValueChanged<AndroidTaskEditorResult>? onMutationCommitted,
}) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push<void>(
        MaterialPageRoute(
          builder: (_) => AndroidTaskEditor(
            accountId: 'google:move',
            provider: BusyProvider.google,
            task: task,
            accountLabel: 'Move account',
            listLabel: task.taskListId == 'source-list'
                ? 'Source list'
                : 'Missing source',
            onMutationStarted: onMutationStarted,
            onMutationCommitted: onMutationCommitted,
          ),
        ),
      );
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilBuilt(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (target.evaluate().isEmpty) {
    for (final element
        in find.byType(Expansible, skipOffstage: false).evaluate().toList()) {
      final widget = element.widget as Expansible;
      if (widget.controller.isExpanded) {
        continue;
      }
      final tile = find
          .ancestor(
            of: find.byElementPredicate(
              (candidate) => identical(candidate, element),
              skipOffstage: false,
            ),
            matching: find.byType(ExpansionTile, skipOffstage: false),
          )
          .first;
      if (tile.evaluate().isEmpty) {
        continue;
      }
      await tester.ensureVisible(tile);
      final heading = find
          .descendant(of: tile, matching: find.byType(ListTile))
          .first;
      await tester.tap(heading);
      await tester.pumpAndSettle();
      if (target.evaluate().isNotEmpty) {
        break;
      }
    }
  }
  var direction = -1.0;
  for (var attempt = 0; attempt < 40 && target.evaluate().isEmpty; attempt++) {
    final candidates = find
        .byType(Scrollable)
        .evaluate()
        .where(
          (element) =>
              ((element as StatefulElement).state as ScrollableState)
                  .position
                  .axis ==
              Axis.vertical,
        )
        .toList();
    if (candidates.isEmpty) {
      break;
    }
    final element = candidates.last;
    final scroll =
        ((element as StatefulElement).state as ScrollableState).position;
    if (scroll.pixels >= scroll.maxScrollExtent - 1) {
      direction = 1;
    }
    if (scroll.pixels <= scroll.minScrollExtent + 1) {
      direction = -1;
    }
    await tester.drag(
      find.byElementPredicate((candidate) => identical(candidate, element)),
      Offset(0, direction * 260),
    );
    await tester.pump();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 20 && target.evaluate().isEmpty; attempt++) {
    final edit = find.byTooltip(
      tester.element(find.byType(Scaffold).last).l10n.editTask,
    );
    if (edit.evaluate().isNotEmpty) {
      await tester.ensureVisible(edit.last);
      await tester.pumpAndSettle();
      await tester.tap(edit.last);
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pumpAndSettle();
  if (target.evaluate().isEmpty) {
    final texts = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .join(' | ');
    fail('Target did not appear. Visible text: $texts');
  }
  expect(target, findsOneWidget);
}

Future<_AndroidAppHarness> _pumpApp(
  WidgetTester tester,
  AppSettings settings, {
  AppDatabase? databaseOverride,
  bool populated = false,
  String? localTimeZone,
  Future<void> Function(AppDatabase database)? seedDatabase,
  Future<void> Function(String accountId)? onCalendarSync,
  Future<void> Function()? onForegroundSync,
  FeedbackSubmissionService? feedbackService,
  CloudCalendarClient? calendarClient,
  GoogleCalendarApiClient? googleSharingClient,
  List<GoogleEventLabel>? googleLabels,
  List<MicrosoftMasterCategory>? microsoftCategories,
  MicrosoftTodoApiClient? todoClient,
  AndroidNotificationBackend? notificationBackend,
  TasksRepository Function(AppDatabase database, String accountId)?
  taskRepository,
  TaskListsRepository Function(AppDatabase database, String accountId)?
  taskListsRepository,
  ScheduleRepository Function(AppDatabase database)? scheduleRepository,
  Future<void> Function(ScheduleRange range, ScheduleFilters filters)?
  scheduleProjectionCoverage,
  TaskCollectionCapabilities? davTaskCapabilities,
}) async {
  final database = databaseOverride ?? AppDatabase.memoryForTests();
  if (seedDatabase != null) {
    await seedDatabase(database);
  }
  if (populated) {
    await _seedPopulatedSchedule(database);
  }
  final notifications = AndroidNotificationService(
    database: database,
    settings: () => settings,
    backend: notificationBackend,
  );
  final container = ProviderContainer(
    overrides: [
      buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
      networkAvailabilityProvider.overrideWith(
        (ref) => Stream.value(NetworkAvailability.unknown),
      ),
      networkConnectivityMonitorProvider.overrideWith((ref) {
        final monitor = NetworkConnectivityMonitor.withoutPlatformObservation();
        ref.onDispose(() => unawaited(monitor.dispose()));
        return monitor;
      }),
      databaseProvider.overrideWithValue(database),
      if (localTimeZone != null)
        localTimeZoneProvider.overrideWithValue(localTimeZone),
      scheduleRepositoryProvider.overrideWithValue(
        scheduleRepository?.call(database) ??
            ScheduleRepository(
              database,
              ensureProjectionCoverage: scheduleProjectionCoverage,
            ),
      ),
      taskListsRepositoryForAccountProvider.overrideWith(
        (ref, accountId) =>
            taskListsRepository?.call(database, accountId) ??
            TaskListsRepository(database: database, accountId: accountId),
      ),
      tasksRepositoryForAccountProvider.overrideWith(
        (ref, accountId) =>
            taskRepository?.call(database, accountId) ??
            TasksRepository(database: database, accountId: accountId),
      ),
      if (onCalendarSync != null)
        pendingCalendarMutationSyncRequesterForAccountProvider.overrideWith((
          ref,
          accountId,
        ) {
          final requester = PendingMutationSyncRequester(
            sync: () => onCalendarSync(accountId),
            debounce: Duration.zero,
          );
          ref.onDispose(requester.dispose);
          return requester;
        }),
      if (feedbackService != null)
        feedbackSubmissionServiceProvider.overrideWithValue(feedbackService),
      if (calendarClient != null)
        calendarRemoteApiClientForAccountProvider.overrideWith(
          (ref, accountId) => calendarClient,
        ),
      if (googleSharingClient != null)
        googleCalendarApiClientForAccountProvider.overrideWith(
          (ref, accountId) => googleSharingClient,
        ),
      if (googleLabels != null)
        googleEventLabelsForCalendarProvider.overrideWith(
          (ref, key) async => googleLabels,
        ),
      if (microsoftCategories != null)
        microsoftMasterCategoriesProvider.overrideWith(
          (ref, accountId) async => microsoftCategories,
        ),
      if (todoClient != null)
        microsoftTodoApiClientForAccountProvider.overrideWith(
          (ref, accountId) => todoClient,
        ),
      initialAppSettingsProvider.overrideWithValue(settings),
      localSettingsStoreProvider.overrideWithValue(
        MemorySettingsStore(settings.toJson()),
      ),
      allAccountsSyncRunnerProvider.overrideWithValue(
        onForegroundSync ?? () async {},
      ),
      notificationReconcilerProvider.overrideWithValue(
        CallbackNotificationReconciler(() async {}),
      ),
      androidNotificationServiceProvider.overrideWithValue(notifications),
      davTaskCollectionCapabilitiesProvider.overrideWith(
        (ref, key) => Stream.value(
          davTaskCapabilities ?? nextcloudTaskCollectionCapabilities,
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const AndroidBusyMaxApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _AndroidAppHarness(tester, container, database);
}

Future<void> _seedPopulatedSchedule(AppDatabase database) =>
    seedScheduleParityFixture(database, notes: _longScheduleDetailsNotes);

Future<void> _seedMovableTask(
  AppDatabase database, {
  bool includeSource = true,
}) async {
  const timestamp = '2026-09-14T00:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'google:move',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'move',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          displayName: const Value('Move account'),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  if (includeSource) {
    await database.taskListsDao.upsertTaskList(
      TaskListsCompanion.insert(
        accountId: 'google:move',
        id: 'source-list',
        title: 'Source list',
        rawJson: '{}',
        createdLocalAtUtc: timestamp,
        updatedLocalAtUtc: timestamp,
      ),
    );
    await database.tasksDao.upsertTask(
      TasksCompanion.insert(
        accountId: 'google:move',
        taskListId: 'source-list',
        id: 'move-task',
        title: 'Original move task',
        rawJson: '{}',
        createdLocalAtUtc: timestamp,
        updatedLocalAtUtc: timestamp,
      ),
    );
  }
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'google:move',
      id: 'destination-list',
      title: 'Destination list',
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    ),
  );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'google:move',
      id: 'other-destination-list',
      title: 'Other destination list',
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    ),
  );
}

Future<void> _seedCalendarAdministration(
  AppDatabase database, {
  String sourceId = 'administration-calendar',
}) async {
  const timestamp = '2026-09-14T00:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'google:administration',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'administration',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          displayName: const Value('Administration account'),
          email: const Value('owner@example.com'),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: sourceId,
          accountId: 'google:administration',
          provider: 'google',
          providerCalendarId: 'administration-calendar',
          summary: 'Administration calendar',
          accessRole: const Value('owner'),
          dataOwner: const Value('owner@example.com'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
}

Future<void> _seedGoogleStatusCalendar(AppDatabase database) async {
  const timestamp = '2026-09-14T00:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'google:status',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'status',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          displayName: const Value('Status account'),
          email: const Value('owner@example.com'),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'status-calendar',
          accountId: 'google:status',
          provider: 'google',
          providerCalendarId: 'status-calendar',
          summary: 'Primary',
          primaryCalendar: const Value(true),
          accessRole: const Value('owner'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
}

Future<void> _seedMicrosoftCategoryCalendar(AppDatabase database) async {
  const timestamp = '2026-09-14T00:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'microsoft:categories',
          provider: 'microsoft',
          authority: 'https://login.microsoftonline.com/common',
          providerAccountId: 'categories',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'microsoft-category-calendar',
          accountId: 'microsoft:categories',
          provider: 'microsoft',
          providerCalendarId: 'calendar',
          summary: 'Work calendar',
          accessRole: const Value('writer'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
}

final class _RecordingFeedbackService implements FeedbackSubmissionService {
  final List<FeedbackSubmission> submissions = [];
  bool fail = true;

  @override
  Future<FeedbackReceipt> submit(FeedbackSubmission submission) async {
    submissions.add(submission);
    if (fail) {
      throw const FeedbackServerFailure(statusCode: 503);
    }
    return const FeedbackReceipt(id: 'feedback-test-receipt');
  }
}

final class _ReminderTapBackend extends Fake
    implements AndroidNotificationBackend {
  late final DidReceiveNotificationResponseCallback _onResponse;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    _onResponse = onDidReceiveNotificationResponse!;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => null;

  @override
  Future<bool> canScheduleExactly() async => true;

  void tap(NotificationScheduleData row, {String? accountId}) => _onResponse(
    NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      payload: jsonEncode({
        'v': 1,
        'schedule': row.id,
        'generation': row.generation,
        'type': row.sourceType,
        'account': accountId ?? row.accountId,
        'source': row.sourceId,
      }),
    ),
  );
}

final class _PermissionOnlyNotifications extends Fake
    implements AndroidNotificationBackend {
  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> canScheduleExactly() async => true;
}

final class _AndroidAppHarness {
  _AndroidAppHarness(this.tester, this.container, this.database);

  final WidgetTester tester;
  final ProviderContainer container;
  final AppDatabase database;
  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    // The upstream infinite planner schedules day-build notifications on the
    // next event-loop turn, including when no listener is installed.
    await tester.pump(const Duration(milliseconds: 1));
    container.dispose();
    await database.close();
  }
}

class _ObservedTaskDraftRepository extends TasksRepository {
  _ObservedTaskDraftRepository({
    required super.database,
    required super.accountId,
  });
  TaskPatchInput? lastInput;
  Object? lastError;

  @override
  Future<void> patchTask(
    String taskListId,
    String taskId,
    TaskPatchInput input,
  ) async {
    lastInput = input;
    lastError = null;
    try {
      await super.patchTask(taskListId, taskId, input);
    } on Object catch (error) {
      lastError = error;
      rethrow;
    }
  }
}

class _GatedTaskRepository extends TasksRepository {
  _GatedTaskRepository({
    required super.database,
    required super.accountId,
    required this.received,
    required this.release,
    this.failFirst = false,
  });
  final Completer<void> received;
  final Completer<void> release;
  final bool failFirst;
  var calls = 0;
  Map<String, Object?>? submittedFields;

  @override
  Future<void> patchTask(
    String taskListId,
    String taskId,
    TaskPatchInput input,
  ) async {
    submittedFields = Map.of(input.fields);
    calls += 1;
    if (calls == 1) {
      received.complete();
      await release.future;
      if (failFirst) {
        throw StateError('Local persistence failed');
      }
    }
    await super.patchTask(taskListId, taskId, input);
  }
}

Future<Task?> _taskRow(AppDatabase database, String listId) =>
    (database.select(database.tasks)..where(
          (row) =>
              row.accountId.equals('google:move') &
              row.taskListId.equals(listId) &
              row.id.equals('move-task'),
        ))
        .getSingleOrNull();

Future<TaskEntity> _seedAndroidEditorTask(
  AppDatabase database, {
  BusyProvider provider = BusyProvider.nextcloud,
  String? taskUrl,
  String? due,
  String? start,
  String? recurrence,
  String? timeZone = 'UTC',
}) async {
  final accountId = '${provider.name}:android-editor';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: accountId,
          provider: provider.name,
          authority: 'https://example.test',
          providerAccountId: 'android-editor',
          credentialKind: provider == BusyProvider.nextcloud
              ? 'nextcloud_app_password'
              : 'oauth',
          authState: const Value('signed_in'),
          displayName: const Value('Editor account'),
          createdAtUtc: '2026-08-01T00:00:00.000Z',
          updatedAtUtc: '2026-08-01T00:00:00.000Z',
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: accountId,
      id: 'editor-list',
      title: 'Editor tasks',
      rawJson: '{}',
      createdLocalAtUtc: '2026-08-01T00:00:00.000Z',
      updatedLocalAtUtc: '2026-08-01T00:00:00.000Z',
    ),
  );
  await database.tasksDao.upsertTask(
    TasksCompanion.insert(
      accountId: accountId,
      taskListId: 'editor-list',
      id: 'editor-task',
      title: 'Editable task',
      rawJson: '{}',
      taskUrl: Value(taskUrl),
      dueUtc: Value(due),
      microsoftDueDateTime: Value(due),
      microsoftDueTimeZone: Value(timeZone),
      microsoftStartDateTime: Value(start),
      microsoftStartTimeZone: Value(timeZone),
      recurrenceJson: Value(recurrence),
      createdLocalAtUtc: '2026-08-01T00:00:00.000Z',
      updatedLocalAtUtc: '2026-08-01T00:00:00.000Z',
    ),
  );
  return TaskEntity.fromRow(
    (await database.tasksDao.listTasks(accountId, 'editor-list')).single,
  );
}

Future<void> _openAndroidTaskEditor(
  WidgetTester tester,
  TaskEntity task,
  BusyProvider provider,
) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push<void>(
        MaterialPageRoute(
          builder: (_) => AndroidTaskEditor(
            accountId: task.accountId,
            provider: provider,
            task: task,
            accountLabel: 'Editor account',
            listLabel: 'Editor tasks',
          ),
        ),
      );
  await tester.pumpAndSettle();
}

Finder _completionControl(Finder row) {
  final checkboxes = find.descendant(of: row, matching: find.byType(Checkbox));
  return checkboxes.evaluate().isNotEmpty
      ? checkboxes.first
      : find.descendant(of: row, matching: find.byType(IconButton)).first;
}

VoidCallback? _completionAction(WidgetTester tester, Finder row) {
  final widget = tester.widget<Widget>(_completionControl(row));
  if (widget is Checkbox) {
    return widget.onChanged == null
        ? null
        : () => widget.onChanged!(!(widget.value ?? false));
  }
  return (widget as IconButton).onPressed;
}

Future<void> _openAndroidItemSearch(WidgetTester tester, String query) async {
  var field = find.descendant(
    of: find.byType(AppBar),
    matching: find.byType(TextField),
  );
  if (field.evaluate().isEmpty) {
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
  }
  field = find.descendant(
    of: find.byType(AppBar),
    matching: find.byType(TextField),
  );
  await tester.enterText(field, query);
  await tester.pumpAndSettle();
}

Future<void> _openAndroidScheduleScreen(WidgetTester tester) async {
  if (find
      .descendant(of: find.byType(AppBar), matching: find.byType(TextField))
      .evaluate()
      .isEmpty) {
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
  }
  if (find.byType(AndroidScheduleSearchFilters).evaluate().isEmpty) {
    await tester.tap(find.byIcon(Icons.view_sidebar_outlined));
    await tester.pumpAndSettle();
  }
  final filters = tester.widget<AndroidScheduleSearchFilters>(
    find.byType(AndroidScheduleSearchFilters),
  );
  // This helper configures the shared search model; visible-control coverage
  // is in the native parity driver.
  filters.onChanged(
    filters.value.copyWith(
      type: ScheduleSearchType.tasks,
      date: ScheduleSearchDate.any,
      taskListKeys: {
        for (final list in filters.taskLists)
          ScheduleTaskListKey(accountId: list.accountId, taskListId: list.id),
      },
    ),
  );
  await tester.pumpAndSettle();
  if (find.byType(BottomSheet).evaluate().isNotEmpty) {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }
}

Future<void> _openAndroidSettings(WidgetTester tester) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push<void>(
        MaterialPageRoute(
          builder: (_) => const AndroidSettingsScreen(
            category: AndroidSettingsCategory.accounts,
          ),
        ),
      );
  await tester.pumpAndSettle();
}

Future<void> _openChecklistAction(WidgetTester tester, String action) async {
  final actions = find.byKey(
    const ValueKey('android-checklist-actions-step-1'),
  );
  await _scrollUntilBuilt(tester, actions);
  await tester.tap(actions);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

Future<TaskEntity> _seedAndroidChecklistTask(
  AppDatabase database,
  _AndroidChecklistClient client,
) async {
  final task = await _seedAndroidEditorTask(
    database,
    provider: BusyProvider.microsoft,
  );
  await (database.update(
    database.tasks,
  )..where((row) => row.accountId.equals(task.accountId))).write(
    TasksCompanion(
      microsoftChecklistItemsJson: Value(
        jsonEncode(client.items.values.toList()),
      ),
    ),
  );
  return TaskEntity.fromRow(
    (await database.tasksDao.listTasks(task.accountId, task.taskListId)).single,
  );
}

class _AndroidChecklistClient
    implements TaskRemoteClient, TaskChecklistRemoteClient {
  final items = <String, Map<String, Object?>>{
    'step-1': {
      'id': 'step-1',
      'displayName': 'Original step',
      'isChecked': false,
    },
    'step-2': {
      'id': 'step-2',
      'displayName': 'Sibling step',
      'isChecked': false,
    },
  };
  final mutations = <String>[];
  var readPages = 0;

  TaskChecklistItemDto dto(Map<String, Object?> value) => TaskChecklistItemDto(
    id: value['id']!.toString(),
    title: value['displayName']!.toString(),
    completed: value['isChecked'] == true,
    rawJson: Map.of(value),
  );

  @override
  Future<TaskChecklistItemsPageDto> listChecklistItemsPage({
    required String taskListId,
    required String taskId,
    String? pageToken,
  }) async {
    readPages += 1;
    final values = items.values.toList();
    return TaskChecklistItemsPageDto(
      items: pageToken == null
          ? values.take(1).map(dto).toList()
          : values.skip(1).map(dto).toList(),
      rawJson: const {},
      nextPageToken: pageToken == null && values.length > 1
          ? 'second-page'
          : null,
    );
  }

  @override
  Future<TaskChecklistItemDto> updateChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
    String? title,
    bool? completed,
  }) async {
    mutations.add('patch:$checklistItemId');
    final value = items[checklistItemId]!;
    if (title != null) {
      value['displayName'] = title;
    }
    if (completed != null) {
      value['isChecked'] = completed;
    }
    return dto(value);
  }

  @override
  Future<void> deleteChecklistItem({
    required String taskListId,
    required String taskId,
    required String checklistItemId,
  }) async {
    mutations.add('delete:$checklistItemId');
    items.remove(checklistItemId);
  }

  @override
  Future<TaskChecklistItemDto> createChecklistItem({
    required String taskListId,
    required String taskId,
    required String title,
    bool completed = false,
  }) async {
    final id = 'server-step-${items.length + 1}';
    mutations.add('create:$id');
    final value = {'id': id, 'displayName': title, 'isChecked': completed};
    items[id] = value;
    return dto(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected provider call: ${invocation.memberName}',
  );
}

class _AndroidRetryScheduleRepository extends ScheduleRepository {
  _AndroidRetryScheduleRepository(super.database);
  var fail = false;

  @override
  Future<List<ScheduleItem>> listItems({
    required ScheduleRange range,
    ScheduleFilters filters = const ScheduleFilters(),
  }) {
    if (fail) {
      return Future.error(StateError('test task query failure'));
    }
    return super.listItems(range: range, filters: filters);
  }

  @override
  Future<List<TaskScheduleItem>> listAllTasks({
    ScheduleFilters filters = const ScheduleFilters(
      includeCalendarEvents: false,
      taskCompletion: ScheduleTaskCompletion.all,
      showNoDateTasks: true,
    ),
  }) {
    if (fail) {
      return Future.error(StateError('test task query failure'));
    }
    return super.listAllTasks(filters: filters);
  }
}

Future<TaskEntity> _seedAndroidDavTree(
  AppDatabase database, {
  int? recurringCount,
  String? recurringRule,
  bool explicitParentStatus = true,
  bool recurringChild = false,
  bool readOnly = false,
  String? categories,
}) async {
  final task = await _seedAndroidEditorTask(database);
  await database.delete(database.tasks).go();
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'checkbox-dav',
          accountId: task.accountId,
          hrefKey: '/tasks/',
          requestUri: 'https://example.test/tasks/',
          displayName: 'Editor tasks',
          supportedComponentMask: const Value(2),
          currentUserPrivilegesJson: Value(
            readOnly ? '["{DAV:}read"]' : '["{DAV:}read","{DAV:}write"]',
          ),
          readOnly: Value(readOnly),
          taskProjectionEnabled: const Value(true),
          createdAtUtc: '2026-08-01T00:00:00Z',
          updatedAtUtc: '2026-08-01T00:00:00Z',
        ),
      );
  await (database.update(
    database.taskLists,
  )..where((row) => row.accountId.equals(task.accountId))).write(
    const TaskListsCompanion(
      id: Value('dav-task-list-checkbox-dav'),
      davCollectionId: Value('checkbox-dav'),
    ),
  );
  final recurringTitle = recurringChild ? 'Child' : 'Parent';
  final objects = [
    for (final title in ['Parent', 'Child'])
      DavPreparedObject.parse(
        hrefKey: '/tasks/${title.toLowerCase()}.ics',
        requestUri: Uri.parse(
          'https://example.test/tasks/${title.toLowerCase()}.ics',
        ),
        etag: '"one"',
        contentType: 'text/calendar',
        rawIcsBody: [
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'PRODID:-//BusyMax Android test//EN',
          'BEGIN:VTODO',
          'UID:${title.toLowerCase()}-uid',
          'SUMMARY:$title',
          if (categories != null) 'CATEGORIES:$categories',
          if (title != 'Parent' || explicitParentStatus) 'STATUS:NEEDS-ACTION',
          if (title != recurringTitle ||
              (recurringCount == null && recurringRule == null))
            'PERCENT-COMPLETE:0',
          if (title == recurringTitle &&
              (recurringCount != null || recurringRule != null)) ...[
            'DUE;VALUE=DATE:${_icalDate(DateTime.now().add(const Duration(days: 2)))}',
            'RRULE:${recurringRule ?? 'FREQ=DAILY;COUNT=$recurringCount'}',
          ],
          if (title == 'Child') 'RELATED-TO:parent-uid',
          'END:VTODO',
          'END:VCALENDAR',
          '',
        ].join('\r\n'),
      ),
  ];
  await DavObjectRepository(database: database).commit(
    DavCollectionCommit(
      accountId: task.accountId,
      collectionId: 'checkbox-dav',
      provider: BusyProvider.nextcloud,
      objects: objects,
      deletedHrefKeys: const {},
      completeMembership: true,
      membershipHrefKeys: objects.map((object) => object.hrefKey).toSet(),
      finalCursorKind: 'dav_sync_token',
      finalCursorValue: 'checkbox-sync',
      baselineGeneration: 1,
      completedAtUtc: DateTime.utc(2026, 8),
      projectionRangeStartUtc: DateTime.utc(2026),
      projectionRangeEndUtc: DateTime.utc(2027),
    ),
  );
  final rows = await database.tasksDao.listTasks(
    task.accountId,
    'dav-task-list-checkbox-dav',
  );
  return TaskEntity.fromRow(rows.singleWhere((row) => row.title == 'Parent'));
}

Finder _androidMutationTile(TaskEntity task, {bool skipOffstage = true}) => find
    .descendant(
      of: find.byKey(
        ValueKey(
          'agenda-mutation-${task.accountId}\u0000${task.taskListId}\u0000${task.id}',
        ),
        skipOffstage: skipOffstage,
      ),
      matching: find.byType(ListTile, skipOffstage: skipOffstage),
      skipOffstage: skipOffstage,
    )
    .first;

Future<void> _seedAndroidDavMoveDestination(
  AppDatabase database,
  String accountId,
) async {
  const timestamp = '2026-08-01T00:00:00Z';
  await database
      .into(database.davCollections)
      .insert(
        DavCollectionsCompanion.insert(
          id: 'editor-destination',
          accountId: accountId,
          hrefKey: '/other-tasks/',
          requestUri: 'https://example.test/other-tasks/',
          displayName: 'Other tasks',
          supportedComponentMask: const Value(2),
          currentUserPrivilegesJson: const Value(
            '["{DAV:}read","{DAV:}write"]',
          ),
          readOnly: const Value(false),
          eventProjectionEnabled: const Value(false),
          taskProjectionEnabled: const Value(true),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: accountId,
      id: 'dav-task-list-editor-destination',
      davCollectionId: const Value('editor-destination'),
      title: 'Other tasks',
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    ),
  );
}

String _icalDate(DateTime value) =>
    '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';

class _FailFirstMoveTaskRepository extends TasksRepository {
  _FailFirstMoveTaskRepository({
    required super.database,
    required super.accountId,
  }) : _database = database;
  final AppDatabase _database;
  var moveCalls = 0;

  @override
  Future<void> patchTask(
    String taskListId,
    String taskId,
    TaskPatchInput input,
  ) async {
    await super.patchTask(taskListId, taskId, input);
    await (_database.update(
      _database.tasks,
    )..where((row) => row.id.equals(taskId))).write(
      const TasksCompanion(notes: Value('Concurrent untouched notes')),
    );
  }

  @override
  Future<void> moveTask(TaskMoveInput input) async {
    moveCalls += 1;
    if (moveCalls == 1) {
      throw StateError('Move failed before commit');
    }
    await super.moveTask(input);
  }
}

class _AndroidRecoveryMoveClient implements TaskRemoteClient {
  String listId = 'source-list';
  int revision = 0;
  final mutations = <String>[];
  final task = <String, Object?>{
    'id': 'move-task',
    'title': 'Original move task',
    'status': 'needsAction',
  };

  void rename(String title) {
    task['title'] = title;
    _advance();
  }

  void _advance() {
    task['etag'] = 'move-${++revision}';
    task['updated'] = DateTime.utc(2026, 9, 14, 0, revision).toIso8601String();
  }

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    if (taskListId != listId || taskId != task['id']) {
      throw StateError('Task is not in the requested list');
    }
    return TaskDto.fromJson(Map.of(task));
  }

  @override
  Future<TaskDto> moveTask({
    required String sourceTaskListId,
    required String taskId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    String? destinationTaskListId,
  }) async {
    await getTask(taskListId: sourceTaskListId, taskId: taskId);
    mutations.add('move:$sourceTaskListId:$destinationTaskListId');
    listId = destinationTaskListId ?? sourceTaskListId;
    _advance();
    return TaskDto.fromJson(Map.of(task));
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    await getTask(taskListId: taskListId, taskId: taskId);
    mutations.add('patch:$taskListId');
    task.addAll(patch.toJson());
    _advance();
    return TaskDto.fromJson(Map.of(task));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected provider call: ${invocation.memberName}',
  );
}

class _AndroidTaskIdentityClient implements TaskRemoteClient {
  final creationReceived = Completer<void>();
  final releaseCreation = Completer<void>();
  final mutations = <String>[];
  Map<String, Object?>? task;
  var revision = 0;

  @override
  Future<TaskDto> createTask({
    required String taskListId,
    String? parentTaskId,
    String? previousSiblingTaskId,
    required TaskCreate create,
  }) async {
    creationReceived.complete();
    await releaseCreation.future;
    mutations.add('create');
    task = {
      ...create.toJson(),
      'id': 'server-created-task',
      'status': 'needsAction',
      'etag': 'v${++revision}',
      'updated': DateTime.now().toUtc().toIso8601String(),
    };
    return TaskDto.fromJson(task!);
  }

  @override
  Future<TaskDto> getTask({
    required String taskListId,
    required String taskId,
  }) async {
    if (task?['id'] != taskId) {
      throw StateError('Unexpected task identity');
    }
    return TaskDto.fromJson(Map.of(task!));
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    if (task?['id'] != taskId) {
      throw StateError('Obsolete task identity');
    }
    mutations.add('patch:$taskId');
    task = {
      ...task!,
      ...patch.toJson(),
      'etag': 'v${++revision}',
      'updated': DateTime.now().toUtc().toIso8601String(),
    };
    return TaskDto.fromJson(Map.of(task!));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected provider call: ${invocation.memberName}',
  );
}

class _FailFirstChecklistEditRepository extends TasksRepository {
  _FailFirstChecklistEditRepository({
    required super.database,
    required super.accountId,
    required super.apiClient,
  });
  var calls = 0;

  @override
  Future<void> patchChecklistSubtask({
    required String taskListId,
    required String parentTaskId,
    required String checklistItemId,
    TaskChecklistItemEntity? observedItem,
    String? title,
    bool? completed,
  }) async {
    calls += 1;
    if (calls == 1) {
      throw StateError('Checklist local commit failed');
    }
    await super.patchChecklistSubtask(
      taskListId: taskListId,
      parentTaskId: parentTaskId,
      checklistItemId: checklistItemId,
      observedItem: observedItem,
      title: title,
      completed: completed,
    );
  }
}

class _FailedMoveChoiceRepository extends TasksRepository {
  _FailedMoveChoiceRepository({
    required super.database,
    required super.accountId,
    required this.failFirstPatch,
  });
  final bool failFirstPatch;
  var patchCalls = 0;
  final moveDestinations = <String?>[];
  @override
  Future<void> patchTask(
    String taskListId,
    String taskId,
    TaskPatchInput input,
  ) async {
    patchCalls += 1;
    if (failFirstPatch && patchCalls == 1) {
      throw StateError('Patch failed before commit');
    }
    await super.patchTask(taskListId, taskId, input);
  }

  @override
  Future<void> moveTask(TaskMoveInput input) async {
    moveDestinations.add(input.destinationTaskListId);
    if (!failFirstPatch && moveDestinations.length == 1) {
      throw StateError('Move failed before commit');
    }
    await super.moveTask(input);
  }
}

class _GatedTaskReadRepository extends TasksRepository {
  _GatedTaskReadRepository({
    required super.database,
    required super.accountId,
    required this.release,
    super.apiClient,
  });
  final Completer<void> release;
  var reads = 0;
  @override
  Stream<TaskEntity?> watchTask(String taskListId, String taskId) async* {
    reads += 1;
    await release.future;
    yield* super.watchTask(taskListId, taskId);
  }
}

class _GatedCompletedTaskListReadRepository extends TaskListsRepository {
  _GatedCompletedTaskListReadRepository({
    required super.database,
    required super.accountId,
  });
  bool arm = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<TaskListEntity>> listTaskLists() async {
    final result = await super.listTaskLists();
    if (arm) {
      arm = false;
      entered.complete();
      await release.future;
    }
    return result;
  }
}

Future<void> _setAndroidCategories(
  WidgetTester tester,
  List<String> values,
) async {
  final editor = find.byType(AndroidCategoryEditor);
  await _scrollUntilBuilt(tester, editor);
  final chips = find.descendant(of: editor, matching: find.byType(InputChip));
  for (final chip in tester.widgetList<InputChip>(chips).toList()) {
    chip.onDeleted?.call();
    await tester.pump();
  }
  for (final value in values) {
    final add = find.descendant(
      of: editor,
      matching: find.widgetWithText(TextButton, 'Add category'),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final input = find.descendant(of: editor, matching: find.byType(TextField));
    await tester.enterText(input, value);
    await tester.tap(add);
    await tester.pumpAndSettle();
  }
}
