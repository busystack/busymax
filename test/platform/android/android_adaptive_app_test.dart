import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/android/presentation/android_tasks_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const platformChannel = MethodChannel('io.busystack.busymax/android');
  const eventChannel = MethodChannel('io.busystack.busymax/events');
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(platformChannel, (call) async {
      return switch (call.method) {
        'takeInitialActivation' => null,
        'googleAuthorizationAvailable' => false,
        'microsoftAuthorizationAvailable' => false,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(eventChannel, (_) async => null);
    messenger.setMockMethodCallHandler(secureStorageChannel, (_) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(platformChannel, null);
    messenger.setMockMethodCallHandler(eventChannel, null);
    messenger.setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets(
    'compact Android shell uses bottom navigation and accessible taps',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Schedule'), findsWidgets);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets('wide Android shell uses a rail in dark RTL mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = AppSettings.defaults().copyWith(
      localeTag: 'ar',
      themeModePreference: BusyMaxThemeModePreference.dark,
    );
    final harness = await _pumpApp(tester, settings);
    addTearDown(harness.dispose);

    expect(find.byType(NavigationRail), findsOneWidget);
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

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
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
      for (final destination in <int>[1, 2]) {
        harness.container
                .read(androidSelectedDestinationProvider.notifier)
                .state =
            destination;
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason:
              'destination $destination at ${size.width}x${size.height} '
              'and text scale $textScale',
        );
      }
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

    final settings = AppSettings.defaults().copyWith(
      androidScheduleViewMode: ScheduleViewMode.day,
      taskListScheduleVisibility: const {
        'google:populated::hidden-list': false,
      },
    );
    final harness = await _pumpApp(tester, settings, populated: true);
    addTearDown(harness.dispose);

    expect(find.byKey(const ValueKey('android-day-time-grid')), findsOneWidget);
    expect(find.textContaining('Overnight event'), findsWidgets);
    expect(find.text('Hidden event'), findsNothing);
    expect(find.text('Hidden task'), findsNothing);
    expect(tester.takeException(), isNull);

    await harness.container
        .read(appSettingsControllerProvider.notifier)
        .setAndroidScheduleViewMode(ScheduleViewMode.month);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('android-month-grid')), findsOneWidget);
    expect(find.text('Overnight event'), findsWidgets);
    expect(tester.takeException(), isNull);

    await harness.container
        .read(appSettingsControllerProvider.notifier)
        .setAndroidScheduleViewMode(ScheduleViewMode.year);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('android-year-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.text('Read-only account'), findsOneWidget);
    expect(find.text('Read-only list'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
  });
}

Future<_AndroidAppHarness> _pumpApp(
  WidgetTester tester,
  AppSettings settings, {
  bool populated = false,
}) async {
  final database = AppDatabase.memoryForTests();
  if (populated) await _seedPopulatedSchedule(database);
  final notifications = AndroidNotificationService(
    database: database,
    settings: () => settings,
  );
  final container = ProviderContainer(
    overrides: [
      buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
      databaseProvider.overrideWithValue(database),
      scheduleRepositoryProvider.overrideWithValue(
        ScheduleRepository(database),
      ),
      initialAppSettingsProvider.overrideWithValue(settings),
      localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      allAccountsSyncRunnerProvider.overrideWithValue(() async {}),
      notificationReconcilerProvider.overrideWithValue(
        CallbackNotificationReconciler(() async {}),
      ),
      androidNotificationServiceProvider.overrideWithValue(notifications),
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

Future<void> _seedPopulatedSchedule(AppDatabase database) async {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day - 1, 23);
  final end = DateTime(today.year, today.month, today.day, 1);
  const timestamp = '2026-09-14T00:00:00.000Z';
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: 'google:populated',
          provider: 'google',
          authority: 'https://accounts.google.com',
          providerAccountId: 'populated',
          credentialKind: 'oauth',
          authState: const Value('signed_in'),
          displayName: const Value('Calendar Account'),
          createdAtUtc: timestamp,
          updatedAtUtc: timestamp,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'calendar',
          accountId: 'google:populated',
          provider: 'google',
          providerCalendarId: 'calendar',
          summary: 'Populated calendar',
          selected: const Value(true),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  await database
      .into(database.calendarEvents)
      .insert(
        CalendarEventsCompanion.insert(
          id: 'overnight',
          accountId: 'google:populated',
          calendarSourceId: 'calendar',
          provider: 'google',
          providerCalendarId: 'calendar',
          providerEventId: 'overnight',
          title: 'Overnight event',
          startDateTime: Value(start.toIso8601String()),
          endDateTime: Value(end.toIso8601String()),
          rawJson: const Value('{}'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  await database
      .into(database.calendarSources)
      .insert(
        CalendarSourcesCompanion.insert(
          id: 'hidden-calendar',
          accountId: 'google:populated',
          provider: 'google',
          providerCalendarId: 'hidden-calendar',
          summary: 'Hidden calendar',
          selected: const Value(false),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  await database
      .into(database.calendarEvents)
      .insert(
        CalendarEventsCompanion.insert(
          id: 'hidden-event',
          accountId: 'google:populated',
          calendarSourceId: 'hidden-calendar',
          provider: 'google',
          providerCalendarId: 'hidden-calendar',
          providerEventId: 'hidden-event',
          title: 'Hidden event',
          startDateTime: Value(start.toIso8601String()),
          endDateTime: Value(end.toIso8601String()),
          rawJson: const Value('{}'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'google:populated',
      id: 'hidden-list',
      title: 'Hidden tasks',
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    ),
  );
  await database.tasksDao.upsertTask(
    TasksCompanion.insert(
      accountId: 'google:populated',
      taskListId: 'hidden-list',
      id: 'hidden-task',
      title: 'Hidden task',
      dueUtc: Value(
        DateTime(
          today.year,
          today.month,
          today.day,
          12,
        ).toUtc().toIso8601String(),
      ),
      status: const Value('needsAction'),
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    ),
  );
}

final class _AndroidAppHarness {
  const _AndroidAppHarness(this.tester, this.container, this.database);

  final WidgetTester tester;
  final ProviderContainer container;
  final AppDatabase database;

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await database.close();
  }
}
