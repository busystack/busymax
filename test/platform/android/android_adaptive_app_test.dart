import 'dart:async';
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
import 'package:busymax/src/calendar_providers/calendar_sync_dto.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/dav/storage/dav_object_repository.dart';
import 'package:busymax/src/dav/mutation/dav_mutation_patch.dart';
import 'package:busymax/src/features/calendar/data/calendar_repository.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';
import 'package:busymax/src/features/feedback/data/feedback_api_client.dart';
import 'package:busymax/src/features/feedback/data/feedback_submission.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/features/schedule/presentation/attachment_upload_coordinator.dart';
import 'package:busymax/src/features/recurrence/domain/recurrence_rule.dart';
import 'package:busymax/src/features/sync/pending_mutation_sync_requester.dart';
import 'package:busymax/src/google_calendar/google_calendar_api_client.dart';
import 'package:busymax/src/google_calendar/google_calendar_models.dart';
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
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
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
import '../../test_localized_app.dart';

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

  testWidgets('Android Settings fits and persists first weekday', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _pumpApp(tester, AppSettings.defaults());
    addTearDown(harness.dispose);

    await tester.tap(find.text('Settings').last);
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
    await tester.tap(find.textContaining('more').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invitation event'));
    await tester.pumpAndSettle();
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Tentative'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('more').hitTestable().first);
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
    final compactWeekMore = find.textContaining('more').first;
    await tester.ensureVisible(compactWeekMore);
    await tester.pumpAndSettle();
    await tester.tap(compactWeekMore);
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
    await tester.tap(find.textContaining('more').hitTestable().first);
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
    'period navigation keeps the time grid mounted while destination loads',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final destination = Completer<void>();
      DateTime? initialRangeStart;
      final harness = await _pumpApp(
        tester,
        AppSettings.defaults().copyWith(
          androidScheduleViewMode: ScheduleViewMode.day,
        ),
        populated: true,
        scheduleProjectionCoverage: (range) async {
          initialRangeStart ??= range.start;
          if (range.start != initialRangeStart) await destination.future;
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
          .singleWhere((state) => state.position.maxScrollExtent > 0);
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
    DateTime? initialRangeStart;
    final harness = await _pumpApp(
      tester,
      AppSettings.defaults().copyWith(
        androidScheduleViewMode: ScheduleViewMode.agenda,
      ),
      scheduleProjectionCoverage: (range) async {
        initialRangeStart ??= range.start;
        if (range.start != initialRangeStart) await destination.future;
      },
    );
    addTearDown(harness.dispose);

    expect(find.text('No events or tasks'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No events or tasks'), findsNothing);

    destination.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No events or tasks'), findsOneWidget);
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
    await tester.tap(find.textContaining('more').first);
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
      await tester.tap(find.textContaining('more').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invitation event'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
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
      ),
      populated: true,
    );
    addTearDown(harness.dispose);
    final stored = await (harness.database.select(
      harness.database.calendarEvents,
    )..where((row) => row.id.equals('overnight'))).getSingle();
    await (harness.database.update(
      harness.database.calendarEvents,
    )..where((row) => row.id.equals('overnight'))).write(
      CalendarEventsCompanion(
        startDateTime: Value(
          DateTime.parse(stored.startDateTime!).toUtc().toIso8601String(),
        ),
        endDateTime: Value(
          DateTime.parse(stored.endDateTime!).toUtc().toIso8601String(),
        ),
        startTimeZone: const Value('Pacific/Honolulu'),
        endTimeZone: const Value('Asia/Tokyo'),
      ),
    );
    await tester.pumpAndSettle();
    final eventLabel = find.textContaining('Overnight event').first;
    await tester.ensureVisible(eventLabel);
    await tester.pumpAndSettle();
    await tester.tap(eventLabel);
    await tester.pumpAndSettle();
    expect(find.textContaining('UTC'), findsWidgets);
    expect(find.textContaining('Pacific/Honolulu'), findsNothing);
    expect(find.textContaining('Asia/Tokyo'), findsNothing);
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
    harness.container.read(androidSelectedDestinationProvider.notifier).state =
        2;
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
      expect(
        find.descendant(of: field, matching: find.text('Edited $label')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
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

  testWidgets('B synced occurrence hides recurrence-rule editor', (
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
  });

  testWidgets(
    'Android task recovery retains notes after a remote rename and movement',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      await _seedMovableTask(harness.database);
      await _openMovableTaskEditor(tester, _movableTask());
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Unsaved recovery notes',
      );
      await tester.pump(const Duration(milliseconds: 1100));
      const key = 'busymax.android.task-draft.google:move.move-task';
      final stored = secureStorage[key]!;
      await harness.dispose();
      await tester.pumpAndSettle();
      secureStorage[key] = stored;
      final changedHarness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(changedHarness.dispose);
      await _seedMovableTask(changedHarness.database);
      await changedHarness.database.tasksDao.upsertTask(
        TasksCompanion.insert(
          accountId: 'google:move',
          taskListId: 'destination-list',
          id: 'move-task',
          title: 'Remote renamed title',
          rawJson: '{}',
          createdLocalAtUtc: '2026-09-14T00:00:00.000Z',
          updatedLocalAtUtc: '2026-09-15T00:00:00.000Z',
        ),
      );
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
        secureStorage['busymax.android.task-draft.google:move.move-task']!,
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
      expect(find.text('2026-08-12'), findsOneWidget);
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
        await tester.tap(
          find.byKey(const ValueKey('android-task-recurrence-end')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('On date').last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('android-task-recurrence-until')),
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
      await _openAndroidTasksScreen(tester);
      await tester.tap(find.text('All tasks').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Source list · Move account').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.filter_list));
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
      await tester.tap(find.byIcon(Icons.filter_list));
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
      await _openAndroidTasksScreen(tester);
      await tester.tap(find.text('All tasks').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editor tasks · Editor account').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.filter_list));
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
      await tester.tap(
        find.descendant(of: step, matching: find.byType(IconButton)).first,
      );
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
      await _openAndroidTasksScreen(tester);
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
    },
  );

  testWidgets(
    'Android Nextcloud root and subtask checkboxes use the percentage hierarchy lifecycle',
    (tester) async {
      final harness = await _pumpApp(tester, AppSettings.defaults());
      addTearDown(harness.dispose);
      final parent = await _seedAndroidDavTree(harness.database);
      await _openAndroidTasksScreen(tester);
      final parentTile = find.widgetWithText(ListTile, 'Parent');
      await tester.tap(
        find
            .descendant(of: parentTile, matching: find.byType(IconButton))
            .first,
      );
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
      await tester.tap(
        find.descendant(of: child, matching: find.byType(IconButton)).first,
      );
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
      final move = find.widgetWithText(OutlinedButton, 'List');
      await _scrollUntilBuilt(tester, move);
      await tester.tap(move);
      await _pumpUntilFound(tester, find.text('Destination list'));
      await tester.tap(find.text('Destination list'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
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
      await _openAndroidTasksScreen(tester);
      await tester.tap(find.text('All tasks').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Source list · Move account').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(SearchBar),
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
      expect(find.text('Source list · Move account'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      schedule.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Original move task'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Source list · Move account'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
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
      final oldKey = 'busymax.android.task-draft.google:move.$tempId';
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
            'busymax.android.task-draft.google:move.server-created-task',
          ),
        ),
      );
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
      const recoveryKey = 'busymax.android.task-draft.google:move.move-task';
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
        secureStorage['busymax.android.task-draft.google:move.move-task']!,
      ) as Map;
      expect((saved['observedTask'] as Map)['notes'], isNull);
      expect((saved['originalObservedTask'] as Map)['notes'], isNull);
      expect(saved['notes'], 'Recovered local notes L');
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
      expect(find.text('2026-08-12'), findsOneWidget);
      expect(find.text('2026-08-13'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
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
      final retained = jsonDecode(secureStorage[key]!) as Map;
      expect(retained['baseTitle'], 'Original title A');
      expect(retained['notes'], 'Recoverable notes L');
      expect(retained.containsKey('observedTask'), isFalse);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(secureStorage, contains(key));
      expect(find.text('Recoverable notes L'), findsOneWidget);
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
        await _openAndroidTasksScreen(tester);
        final tile = find.widgetWithText(ListTile, 'Editable task');
        await tester.tap(
          find.descendant(of: tile, matching: find.byType(IconButton)).first,
        );
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
        await tester.tap(
          find.descendant(of: tile, matching: find.byType(IconButton)).first,
        );
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
          MaterialPageRoute(builder: (_) => const AndroidSettingsScreen()),
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
            MaterialPageRoute(builder: (_) => const AndroidSettingsScreen()),
          );
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
    },
  );

  for (final blockedChannel in [false, true]) {
    testWidgets(
      'Android Nextcloud edits one reminder and keeps sibling alarms (blocked channel: $blockedChannel)',
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
        final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
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
                      provider: 'nextcloud',
                      authority: 'https://cloud.example.test',
                      providerAccountId: 'user',
                      credentialKind: 'nextcloud_app_password',
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
                      provider: 'nextcloud',
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
                  provider: BusyProvider.nextcloud,
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
                  (await database.select(database.calendarEvents).getSingle())
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
        final second = find.byKey(const Key('android-event-dav-reminder-1'));
        await _scrollUntilBuilt(tester, second);
        expect(
          find.byKey(const Key('android-event-dav-reminder-0')),
          findsOneWidget,
        );
        tester.widget<DropdownButtonFormField<int>>(second).onChanged!.call(45);
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
          findsOneWidget,
        );
        expect(queuedBody, contains('TRIGGER:-PT45M'));
        expect(queuedBody, contains('X-KEEP:first'));
        expect(queuedBody, contains('X-KEEP:second'));
        expect(queuedBody, contains('TRIGGER;RELATED=END:-PT0M'));
        expect(queuedBody, contains('X-KEEP:end'));
        expect(queuedBody, contains('X-KEEP:audio'));
        final updated = (await tester.runAsync(
          () => repository.loadEventDetail(seededEventId),
        ))!;
        final editedRows = androidNextcloudEditableReminderRows(
          updated.reminders,
        )!;
        expect(editedRows.map((row) => row.minutes), [15, 45]);
        expect(jsonEncode(updated.reminders), contains('X-KEEP'));
        expect(tester.takeException(), isNull);
      },
    );
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
  });
}

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
  GoogleCalendarApiClient? googleSharingClient,
  List<GoogleEventLabel>? googleLabels,
  List<MicrosoftMasterCategory>? microsoftCategories,
  MicrosoftTodoApiClient? todoClient,
  AndroidNotificationBackend? notificationBackend,
  TasksRepository Function(AppDatabase database, String accountId)?
  taskRepository,
  ScheduleRepository Function(AppDatabase database)? scheduleRepository,
  Future<void> Function(ScheduleRange range)? scheduleProjectionCoverage,
}) async {
  final database = AppDatabase.memoryForTests();
  if (seedDatabase != null) await seedDatabase(database);
  if (populated) await _seedPopulatedSchedule(database);
  final notifications = AndroidNotificationService(
    database: database,
    settings: () => settings,
    backend: notificationBackend,
  );
  final container = ProviderContainer(
    overrides: [
      buildConfigProvider.overrideWithValue(BuildConfig.forAndroid()),
      databaseProvider.overrideWithValue(database),
      scheduleRepositoryProvider.overrideWithValue(
        scheduleRepository?.call(database) ??
            ScheduleRepository(
              database,
              ensureProjectionCoverage: scheduleProjectionCoverage,
            ),
      ),
      taskListsRepositoryForAccountProvider.overrideWith(
        (ref, accountId) =>
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
      allAccountsSyncRunnerProvider.overrideWithValue(() async {}),
      notificationReconcilerProvider.overrideWithValue(
        CallbackNotificationReconciler(() async {}),
      ),
      androidNotificationServiceProvider.overrideWithValue(notifications),
      davTaskCollectionCapabilitiesProvider.overrideWith(
        (ref, key) => Stream.value(nextcloudTaskCollectionCapabilities),
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
    if (fail) throw const FeedbackServerFailure(statusCode: 503);
    return const FeedbackReceipt(id: 'feedback-test-receipt');
  }
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
    if (_disposed) return;
    _disposed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await database.close();
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
      if (failFirst) throw StateError('Local persistence failed');
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

Future<void> _openAndroidTasksScreen(WidgetTester tester) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push<void>(
        MaterialPageRoute(builder: (_) => const AndroidTasksScreen()),
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
    if (title != null) value['displayName'] = title;
    if (completed != null) value['isChecked'] = completed;
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
  Future<List<TaskScheduleItem>> listAllTasks({
    ScheduleFilters filters = const ScheduleFilters(
      includeCalendarEvents: false,
      taskCompletion: ScheduleTaskCompletion.all,
      showNoDateTasks: true,
    ),
  }) {
    if (fail) return Future.error(StateError('test task query failure'));
    return super.listAllTasks(filters: filters);
  }
}

Future<TaskEntity> _seedAndroidDavTree(AppDatabase database) async {
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
          currentUserPrivilegesJson: const Value(
            '["{DAV:}read","{DAV:}write"]',
          ),
          readOnly: const Value(false),
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
          'STATUS:NEEDS-ACTION',
          'PERCENT-COMPLETE:0',
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
    if (moveCalls == 1) throw StateError('Move failed before commit');
    await super.moveTask(input);
  }
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
    if (task?['id'] != taskId) throw StateError('Unexpected task identity');
    return TaskDto.fromJson(Map.of(task!));
  }

  @override
  Future<TaskDto> patchTask({
    required String taskListId,
    required String taskId,
    required TaskPatch patch,
  }) async {
    if (task?['id'] != taskId) throw StateError('Obsolete task identity');
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
    if (calls == 1) throw StateError('Checklist local commit failed');
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
