import 'dart:convert';

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/android/presentation/android_availability_dialog.dart';
import 'package:busymax/src/android/presentation/android_diagnostics_screen.dart';
import 'package:busymax/src/android/presentation/android_feedback_screen.dart';
import 'package:busymax/src/android/presentation/android_schedule_screen.dart';
import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:busymax/src/android/presentation/android_tasks_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/calendar_providers/cloud_calendar_client.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/feedback/data/feedback_api_client.dart';
import 'package:busymax/src/features/feedback/data/feedback_submission.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/sync/pending_mutation_sync_requester.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/features/tasks/domain/task_capabilities.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/memory_settings_store.dart';

final _longScheduleDetailsNotes = List.generate(
  60,
  (index) => 'Full task note line ${index + 1}',
).join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const platformChannel = MethodChannel('io.busystack.busymax/android');
  const eventChannel = MethodChannel('io.busystack.busymax/events');
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, String> secureStorage;

  setUp(() {
    secureStorage = {};
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
          if (key != null) secureStorage.remove(key);
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
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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
    expect(find.textContaining('more'), findsWidgets);
    expect(find.text('Hidden event'), findsNothing);
    expect(find.text('Hidden task'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('more').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invitation event'));
    await tester.pumpAndSettle();
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Tentative'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('more').first);
    await tester.pumpAndSettle();
    expect(find.text('All-day event 3'), findsOneWidget);
    expect(find.text('Date-only task'), findsOneWidget);
    await tester.tap(find.text('All-day event 3'));
    await tester.pumpAndSettle();
    expect(find.text('All-day event 3'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await harness.container
        .read(appSettingsControllerProvider.notifier)
        .setAndroidScheduleViewMode(ScheduleViewMode.week);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('android-week-time-grid')),
      findsOneWidget,
    );
    expect(find.textContaining('Overnight event'), findsWidgets);
    expect(find.textContaining('more'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('more').first);
    await tester.pumpAndSettle();
    expect(find.text('Date-only task'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(800, 900);
    tester.binding.handleMetricsChanged();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('android-week-time-grid')),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('more').first);
    await tester.pumpAndSettle();
    expect(find.text('Date-only task'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(320, 500);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.binding.handleMetricsChanged();
    tester.binding.handleTextScaleFactorChanged();

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
          final more = find.ancestor(
            of: find.textContaining('more').first,
            matching: find.byType(TextButton),
          );
          tester.widget<TextButton>(more).onPressed!();
          await tester.pumpAndSettle();
          final task = find.text('Date-only task');
          await _scrollUntilBuilt(tester, task);
          await tester.ensureVisible(task);
          await tester.tap(task);
          await tester.pumpAndSettle();

          final details = find.byKey(
            const ValueKey('android-schedule-details-scroll'),
          );
          final edit = find.text('Edit Task');
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

    await tester.tap(find.textContaining('more').first);
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
      expect(find.text('free@example.com'), findsOneWidget);
      expect(find.text('failed@example.com'), findsOneWidget);
      expect(find.text('missing@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Android Settings exposes diagnostics and feedback routes', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    harness.container.read(androidSelectedDestinationProvider.notifier).state =
        2;
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

    final diagnostics = find.text('Diagnostics');
    await _scrollUntilBuilt(tester, diagnostics);
    await Scrollable.ensureVisible(
      tester.element(diagnostics),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(diagnostics);
    await tester.pumpAndSettle();
    expect(find.byType(AndroidDiagnosticsScreen), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    final feedback = find.text('Send feedback');
    await _scrollUntilBuilt(tester, feedback);
    await Scrollable.ensureVisible(
      tester.element(feedback),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(feedback);
    await tester.pumpAndSettle();
    expect(find.byType(AndroidFeedbackScreen), findsOneWidget);
    expect(find.text('Detailed message'), findsOneWidget);
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

      final labelText = find.descendant(
        of: find.byType(AndroidEventEditor),
        matching: find.text(label),
      );
      await _scrollUntilBuilt(tester, labelText);
      final field = find.ancestor(
        of: labelText,
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Edited $label');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidEventEditor), findsOneWidget);
      expect(find.text('Edited $label'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

      final labelText = find.descendant(
        of: find.byType(AndroidTaskEditor),
        matching: find.text(label),
      );
      await _scrollUntilBuilt(tester, labelText);
      final field = find.ancestor(
        of: labelText,
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Edited $label');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsOneWidget);
      expect(find.text('Edited $label'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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
    await tester.tap(find.text('Calendar B · google:b').last);
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
    expect(find.text('Calendar B · google:b'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    final rewritten = (jsonDecode(secureStorage[key]!) as Map)
        .cast<String, Object?>();
    expect(rewritten['showAs'], isNull);
    expect(rewritten['visibility'], isNull);
    expect(rewritten['start'], initial.start!.toIso8601String());
    expect(tester.takeException(), isNull);
  });

  testWidgets('event recovery preserves a recurring mutation scope', (
    tester,
  ) async {
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
    await tester.tap(find.text('This event'));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    const key = 'busymax.android.event-draft.google:a.occurrence';
    final saved = (jsonDecode(secureStorage[key]!) as Map)
        .cast<String, Object?>();
    expect(saved['recurringMutationScope'], 'singleOccurrence');
    expect(tester.takeException(), isNull);
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
    final saved = (jsonDecode(secureStorage[key]!) as Map)
        .cast<String, Object?>();
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
  });

  testWidgets('dirty task save-and-move persists edits before moving', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);
    await _seedMovableTask(harness.database);
    expect(
      await harness.database.taskListsDao.listTaskLists('google:move'),
      hasLength(3),
    );
    await tester.pump();
    await _openMovableTaskEditor(tester, _movableTask());

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Edited before move',
    );
    await tester.pump();
    final move = find.widgetWithText(OutlinedButton, 'List');
    await _scrollUntilBuilt(tester, move);
    expect(tester.widget<OutlinedButton>(move).onPressed, isNot(equals(null)));
    tester.widget<OutlinedButton>(move).onPressed!();
    await _pumpUntilFound(tester, find.text('Destination list'));
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Destination list'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AndroidTaskEditor), findsNothing);
    final row = await (harness.database.select(
      harness.database.tasks,
    )..where((task) => task.id.equals('move-task'))).getSingle();
    expect(row.title, 'Edited before move');
    expect(row.taskListId, 'destination-list');
    final operations = await harness.database
        .select(harness.database.pendingOps)
        .get();
    expect(
      operations.map((operation) => operation.operation),
      containsAllInOrder(['patch_task', 'move_task']),
    );
    expect(
      secureStorage,
      isNot(contains('busymax.android.task-draft.google:move.move-task')),
    );
    expect(tester.takeException(), isNull);
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
    final move = find.widgetWithText(OutlinedButton, 'List');
    await _scrollUntilBuilt(tester, move);
    tester.widget<OutlinedButton>(move).onPressed!();
    await _pumpUntilFound(tester, find.text('Destination list'));
    await tester.tap(find.text('Destination list'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AndroidTaskEditor), findsOneWidget);
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
    final recoveryKey = 'busymax.android.task-draft.google:move.move-task';
    expect(secureStorage, contains(recoveryKey));
    final move = find.widgetWithText(OutlinedButton, 'List');
    await _scrollUntilBuilt(tester, move);
    tester.widget<OutlinedButton>(move).onPressed!();
    await _pumpUntilFound(tester, find.text('Destination list'));
    await tester.tap(find.text('Destination list'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(find.byType(AndroidTaskEditor), findsOneWidget);
    expect(find.text('Recover after move failure'), findsOneWidget);
    expect(secureStorage, contains(recoveryKey));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
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
          MaterialPageRoute(builder: (_) => const AndroidSettingsScreen()),
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
  });

  testWidgets('Android feedback preserves failure and rotates edited retry', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'BusyMax',
      packageName: 'io.busystack.busymax',
      version: '0.2.2',
      buildNumber: '2',
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
  });
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
  TaskEntity task,
) async {
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
          ),
        ),
      );
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilBuilt(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 12 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    await tester.pump();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 20 && target.evaluate().isEmpty; attempt++) {
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
  bool populated = false,
  Future<void> Function(AppDatabase database)? seedDatabase,
  Future<void> Function(String accountId)? onCalendarSync,
  FeedbackSubmissionService? feedbackService,
  CloudCalendarClient? calendarClient,
}) async {
  final database = AppDatabase.memoryForTests();
  if (seedDatabase != null) await seedDatabase(database);
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
      taskListsRepositoryForAccountProvider.overrideWith(
        (ref, accountId) =>
            TaskListsRepository(database: database, accountId: accountId),
      ),
      tasksRepositoryForAccountProvider.overrideWith(
        (ref, accountId) =>
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
      initialAppSettingsProvider.overrideWithValue(settings),
      localSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
      allAccountsSyncRunnerProvider.overrideWithValue(() async {}),
      notificationReconcilerProvider.overrideWithValue(
        CallbackNotificationReconciler(() async {}),
      ),
      androidNotificationServiceProvider.overrideWithValue(notifications),
      davTaskCollectionCapabilitiesProvider.overrideWith(
        (ref, key) async => nextcloudTaskCollectionCapabilities,
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
  await database.taskListsDao.upsertTaskList(
    TaskListsCompanion.insert(
      accountId: 'google:populated',
      id: 'visible-list',
      title: 'Visible tasks',
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
    ),
  );
  await database.tasksDao.upsertTask(
    TasksCompanion.insert(
      accountId: 'google:populated',
      taskListId: 'visible-list',
      id: 'date-only-task',
      title: 'Date-only task',
      notes: Value(_longScheduleDetailsNotes),
      dueUtc: Value(
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}',
      ),
      status: const Value('needsAction'),
      rawJson: '{}',
      createdLocalAtUtc: timestamp,
      updatedLocalAtUtc: timestamp,
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
      .into(database.calendarEvents)
      .insert(
        CalendarEventsCompanion.insert(
          id: 'invitation',
          accountId: 'google:populated',
          calendarSourceId: 'calendar',
          provider: 'google',
          providerCalendarId: 'calendar',
          providerEventId: 'invitation',
          title: 'Invitation event',
          allDay: const Value(true),
          startDate: Value(
            DateTime(
              today.year,
              today.month,
              today.day,
            ).toIso8601String().substring(0, 10),
          ),
          endDate: Value(
            DateTime(
              today.year,
              today.month,
              today.day + 1,
            ).toIso8601String().substring(0, 10),
          ),
          attendeesJson: const Value(
            '[{"email":"me@example.com","self":true,"responseStatus":"needsAction"}]',
          ),
          organizerJson: const Value(
            '{"email":"organizer@example.com","self":false}',
          ),
          rawJson: const Value('{}'),
          createdAtLocal: 1,
          updatedAtLocal: 1,
        ),
      );
  for (var index = 1; index <= 4; index++) {
    await database
        .into(database.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: 'all-day-$index',
            accountId: 'google:populated',
            calendarSourceId: 'calendar',
            provider: 'google',
            providerCalendarId: 'calendar',
            providerEventId: 'all-day-$index',
            title: 'All-day event $index',
            allDay: const Value(true),
            startDate: Value(
              '${today.year.toString().padLeft(4, '0')}-'
              '${today.month.toString().padLeft(2, '0')}-'
              '${today.day.toString().padLeft(2, '0')}',
            ),
            endDate: Value(
              DateTime(
                today.year,
                today.month,
                today.day + 1,
              ).toIso8601String().substring(0, 10),
            ),
            rawJson: const Value('{}'),
            createdAtLocal: 1,
            updatedAtLocal: 1,
          ),
        );
  }
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

Future<void> _seedCalendarAdministration(AppDatabase database) async {
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
          id: 'administration-calendar',
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

final class _RecordingFeedbackService implements FeedbackSubmissionService {
  final List<FeedbackSubmission> submissions = [];
  bool fail = true;

  @override
  Future<FeedbackReceipt> submit(FeedbackSubmission submission) async {
    submissions.add(submission);
    if (fail) throw const FeedbackServerFailure(statusCode: 503);
    return const FeedbackReceipt(id: 'feedback-test-receipt');
  }
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
