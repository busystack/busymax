import 'package:busymax/src/ui/common/schedule/schedule_day_week_view.dart'
    as planner_view;
import 'package:busymax/src/ui/common/schedule/schedule_month_view.dart'
    as month_view;
import 'package:busymax/src/ui/common/schedule/schedule_year_view.dart'
    as year_view;
import 'package:busymax/src/android/presentation/android_schedule_screen.dart'
    show AndroidEventEditor;
import 'package:busymax/src/core/time/provider_date_time.dart';
import 'package:busymax/src/schedule/schedule_search_criteria.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/ui/common/schedule/schedule_interactions.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart' as icv;
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/core/secrets/secret_store.dart';

// Uses disposable in-memory data and the same first-party fixture on Linux and
// Android. No provider writes, invitations, or installed user database access.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:busymax/src/android/android_app.dart';
import 'package:busymax/src/android/android_workspace_navigation.dart';
import 'package:busymax/src/android/android_notifications.dart';
import 'package:busymax/src/android/presentation/android_settings_screen.dart';
import 'package:busymax/src/android/presentation/android_tasks_screen.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/notifications/notification_reconciler.dart';
import 'package:busymax/src/features/sync/pending_mutation_sync_requester.dart';
import 'package:busymax/src/features/sync/account_sync_operations.dart';
import 'package:busymax/src/features/sync/domain_sync_schedule.dart';
import 'package:busymax/src/features/sync/sync_request.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/memory_settings_store.dart';
import '../test/support/schedule_parity_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
          .shouldPropagateDevicePointerEvents =
      true;
  testWidgets('populated workspace interactions and viewport evidence', (
    tester,
  ) async {
    expect(const bool.fromEnvironment('BUSYMAX_PARITY_QA'), isTrue);
    final oldFatalHitTests = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(
      () => WidgetController.hitTestWarningShouldBeFatal = oldFatalHitTests,
    );
    final originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint('Runtime UI error: $details');
      originalErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalErrorHandler);
    final recovery = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = (call.arguments as Map?) ?? const {};
            final key = args['key']?.toString();
            switch (call.method) {
              case 'read':
                return recovery[key];
              case 'write':
                recovery[key!] = args['value'].toString();
                return null;
              case 'delete':
                recovery.remove(key);
                return null;
              case 'readAll':
                return Map<String, String>.from(recovery);
              default:
                return null;
            }
          },
        );
    final androidUi =
        Platform.isAndroid ||
        const bool.fromEnvironment('BUSYMAX_PARITY_ANDROID_UI');
    if (androidUi && !Platform.isAndroid) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.binding.handleMetricsChanged();
    }
    if (androidUi && !Platform.isAndroid) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('io.busystack.busymax/android'),
            (call) async => switch (call.method) {
              'getFirstWeekday' => 1,
              'currentTimeZoneId' => 'America/Edmonton',
              'systemUses24HourClock' => false,
              _ => null,
            },
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('io.busystack.busymax/events'),
            (_) async => null,
          );
    }
    final db = AppDatabase.memoryForTests();
    await seedScheduleParityStress(db);
    final settings = AppSettings.defaults().copyWith(
      taskListScheduleVisibility: {'google:populated::hidden-list': false},
      firstDayOfWeekPreference: BusyMaxFirstDayOfWeekPreference.monday,
      timeFormatPreference: BusyMaxTimeFormatPreference.twentyFourHour,
      themeModePreference: BusyMaxThemeModePreference.light,
      localeTag: 'en',
      notifyEventReminders: false,
      notifyTaskReminders: false,
    );
    final notifications = AndroidNotificationService(
      database: db,
      settings: () => settings,
    );
    final headerIcons = androidUi ? null : GtkHeaderIconService();
    if (headerIcons != null) {
      await tester.runAsync(() => headerIcons.initialize());
    }
    final workspaceRefreshes = <SyncRequest>[];
    final container = ProviderContainer(
      overrides: [
        if (headerIcons != null)
          gtkHeaderIconServiceProvider.overrideWith((ref) {
            ref.onDispose(headerIcons.dispose);
            return headerIcons;
          }),
        databaseProvider.overrideWithValue(db),
        // Production entry points initialize this provider before building the
        // shell. Keep the comparison's zone explicit on both platforms.
        localTimeZoneProvider.overrideWithValue(
          const String.fromEnvironment(
            'BUSYMAX_PARITY_TIME_ZONE',
            defaultValue: 'Etc/GMT+7',
          ),
        ),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        buildConfigProvider.overrideWithValue(
          androidUi ? BuildConfig.forAndroid() : BuildConfig.fromEnvironment(),
        ),
        initialAppSettingsProvider.overrideWithValue(settings),
        localSettingsStoreProvider.overrideWithValue(
          MemorySettingsStore(settings.toJson()),
        ),
        scheduleRepositoryProvider.overrideWithValue(
          ScheduleRepository(db, ensureCloudCoverage: (_, _) async => true),
        ),
        taskListsRepositoryForAccountProvider.overrideWith(
          (ref, id) => TaskListsRepository(database: db, accountId: id),
        ),
        tasksRepositoryForAccountProvider.overrideWith(
          (ref, id) => TasksRepository(database: db, accountId: id),
        ),
        accountSyncOperationsProvider.overrideWithValue(
          RequestAccountSyncOperations((request) async {
            workspaceRefreshes.add(request);
            return SyncOutcome(request, SyncDisposition.completed);
          }),
        ),
        signedInSyncRunnerProvider.overrideWithValue((_, _) async {}),
        pendingCalendarMutationSyncRequesterForAccountProvider.overrideWith((
          ref,
          _,
        ) {
          final requester = PendingMutationSyncRequester(
            sync: () async {},
            debounce: Duration.zero,
          );
          ref.onDispose(requester.dispose);
          return requester;
        }),
        notificationReconcilerProvider.overrideWithValue(
          CallbackNotificationReconciler(() async {}),
        ),
        androidNotificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    final output = Platform.isAndroid
        ? Directory('${(await getApplicationSupportDirectory()).path}/parity')
        : Directory(
            const String.fromEnvironment(
              'BUSYMAX_PARITY_OUTPUT',
              defaultValue: '/tmp/busymax-parity-linux',
            ),
          );
    await output.create(recursive: true);
    await File('${output.path}/environment.json').writeAsString(
      jsonEncode({
        'base_revision': const String.fromEnvironment(
          'BUSYMAX_PARITY_BASE_REVISION',
        ),
        'source_sha256': const String.fromEnvironment(
          'BUSYMAX_PARITY_SOURCE_SHA256',
        ),
        'runtime': Platform.operatingSystem,
        'presentation': androidUi ? 'android' : 'linux',
        'native_android': Platform.isAndroid,
        'fixture': 'seedScheduleParityStress',
        'date': DateTime.now().toIso8601String(),
        'time_zone': DateTime.now().timeZoneName,
        'app_time_zone': container.read(localTimeZoneProvider),
        'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
        'locale': 'en',
        'theme': 'light',
        'first_weekday': 'Monday',
        'time_format': '24h',
        'temporary_storage': true,
      }),
    );
    final nativeViewports =
        Platform.isAndroid &&
        const bool.fromEnvironment('BUSYMAX_PARITY_NATIVE_VIEWPORTS');
    const phone = bool.fromEnvironment('BUSYMAX_PARITY_PHONE');
    final native = Directory(
      '${output.path}/native-${const String.fromEnvironment('BUSYMAX_PARITY_RUN_ID')}',
    );
    var sequence = 0;
    Future<void> nativeRequest(
      Map<String, Object> command, {
      bool settle = true,
    }) async {
      if (!nativeViewports) {
        return;
      }
      await native.create(recursive: true);
      final seq = ++sequence;
      await File('${native.path}/request.json')
          .writeAsString(jsonEncode({'seq': seq, ...command}));
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (!await File('${native.path}/ack-$seq').exists()) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError(
              'Native viewport driver did not acknowledge $command',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    final boundary = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: boundary,
          child: androidUi ? const AndroidBusyMaxApp() : const BusyMaxApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name, {bool settle = true}) async {
      if (settle) await tester.pumpAndSettle();
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${output.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      final dayWeek = tester
          .widgetList<planner_view.ScheduleDayWeekView>(
            find.byWidgetPredicate(
              (w) => w is planner_view.ScheduleDayWeekView,
            ),
          )
          .firstOrNull;
      final month = tester
          .widgetList<month_view.ScheduleMonthView>(
            find.byWidgetPredicate((w) => w is month_view.ScheduleMonthView),
          )
          .firstOrNull;
      final year = tester
          .widgetList<year_view.ScheduleYearView>(
            find.byWidgetPredicate((w) => w is year_view.ScheduleYearView),
          )
          .firstOrNull;
      final displayedDate =
          dayWeek?.selectedDate ?? month?.selectedDate ?? year?.selectedDate;
      if (displayedDate != null &&
          (name == 'rtl-dark-week' ||
              RegExp(r'^(320|360|412|800|915|1200)-').hasMatch(name))) {
        expect(
          DateUtils.dateOnly(displayedDate),
          DateUtils.dateOnly(DateTime.now()),
          reason:
              'Changing the view or viewport must preserve the selected date: $name',
        );
      }
      await File('${output.path}/$name.json').writeAsString(
        jsonEncode({
          'selected_date': displayedDate?.toIso8601String(),
          'time_zone': container.read(localTimeZoneProvider),
          'captured_at': DateTime.now().toIso8601String(),
          'planner_scale': dayWeek == null
              ? null
              : tester
                    .state<icv.EventsPlannerState>(
                      find.byType(icv.EventsPlanner),
                    )
                    .heightPerMinute,
        }),
      );
      if (displayedDate != null) {
        debugPrint('Captured $name at ${displayedDate.toIso8601String()}');
      }
      await nativeRequest({'kind': 'capture', 'name': name}, settle: settle);
      expect(tester.takeException(), isNull, reason: 'Runtime capture: $name');
    }

    final controller = container.read(appSettingsControllerProvider.notifier);
    Future<void> mode(ScheduleViewMode value) async {
      await tester.tap(
        androidUi
            ? find.byTooltip('View')
            : find.byKey(const ValueKey('schedule-view-button')),
      );
      await tester.pumpAndSettle();
      if (androidUi) {
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is CheckedPopupMenuItem<ScheduleViewMode> &&
                widget.value == value,
          ),
        );
      } else {
        await tester.runAsync(
          () => Process.run('/usr/bin/python3', [
            'tool/linux/parity_input.py',
            'Home',
            for (var i = 0; i < value.index; i++) 'Down',
            'Return',
          ]),
        );
      }
      await tester.pumpAndSettle();
      final selected = container.read(appSettingsControllerProvider);
      expect(
        androidUi
            ? selected.androidScheduleViewMode
            : selected.scheduleViewMode,
        value,
      );
    }

    Future<void> workspaceCommand(String value) async {
      await tester.tap(find.byKey(const ValueKey('android-workspace-menu')));
      await tester.pumpAndSettle();
      await capture('workspace-menu-$value');
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is PopupMenuItem<String> && w.value == value,
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final value in ScheduleViewMode.values) {
      await mode(value);
      await capture(value.name);
      expect(tester.takeException(), isNull);
    }
    if (!androidUi) {
      await controller.setThemeModePreference(BusyMaxThemeModePreference.light);
      await tester.pumpAndSettle();
      await capture('sources-header');
      final refreshCount = workspaceRefreshes.length;
      await tester.tap(find.byKey(const ValueKey('schedule-refresh-button')));
      await tester.pumpAndSettle();
      expect(workspaceRefreshes.skip(refreshCount), [
        (
          scope: allSyncScope,
          origin: SyncTrigger.manual,
          strategy: SyncStrategy.ordinary,
        ),
      ]);
      await tester.tap(find.byKey(const ValueKey('schedule-create-button')));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Process.run('/usr/bin/python3', [
          'tool/linux/parity_input.py',
          'Home',
          'Return',
        ]),
      );
      await tester.pumpAndSettle();
      await capture('event-creation');
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('schedule-view-button')));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Process.run('/usr/bin/python3', [
          'tool/linux/parity_input.py',
          'Home',
          'Down',
          'Return',
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-today-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-next-button')));
      await tester.pumpAndSettle();
      await capture('next-period');
      await tester.tap(find.byKey(const ValueKey('schedule-previous-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-view-button')));
      await tester.pumpAndSettle();
      await capture('view-selector');
      await tester.runAsync(
        () => Process.run('/usr/bin/python3', [
          'tool/linux/parity_input.py',
          'Home',
          'Down',
          'Down',
          'Down',
          'Down',
          'Return',
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overdue follow-up 0').first);
      await tester.pumpAndSettle();
      await capture('task-preview');
      await tester.tap(find.byTooltip('Edit Task').last);
      await tester.pumpAndSettle();
      await capture('task-editor');
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-search-button')));
      await tester.pumpAndSettle();
      await capture('search-filters');
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('schedule-header-search-field')),
          matching: find.byType(TextField),
        ),
        'Project review',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await capture('search-results');
      await tester.tap(
        find.text('Project review 1 with the product team').first,
      );
      await tester.pumpAndSettle();
      await capture('event-preview');
      await tester.tap(find.byTooltip('Edit event').last);
      await tester.pumpAndSettle();
      await capture('event-editor');
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await capture('settings');
      final accountsNavigation = find.byKey(
        const ValueKey('settings-navigation-accounts'),
      );
      if (accountsNavigation.evaluate().isNotEmpty) {
        await tester.tap(accountsNavigation);
      } else {
        await tester.tap(find.byKey(const ValueKey('settings-page-selector')));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Process.run('/usr/bin/python3', [
            'tool/linux/parity_input.py',
            'Home',
            'Down',
            'Return',
          ]),
        );
      }
      await tester.pumpAndSettle();
      await capture('settings-accounts');
      await tester.ensureVisible(find.text('Calendar Account').last);
      await tester.tap(find.text('Calendar Account').last);
      await tester.pumpAndSettle();
      await capture('settings-account-detail');
      for (final (name, index) in [
        ('schedule', 2),
        ('notifications', 3),
        ('privacy', 4),
        ('diagnostics', 5),
      ]) {
        final navigation = find.byKey(ValueKey('settings-navigation-$name'));
        if (navigation.evaluate().isNotEmpty) {
          await tester.tap(navigation);
        } else {
          await tester.tap(
            find.byKey(const ValueKey('settings-page-selector')),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => Process.run('/usr/bin/python3', [
              'tool/linux/parity_input.py',
              'Home',
              for (var i = 0; i < index; i++) 'Down',
              'Return',
            ]),
          );
        }
        await tester.pumpAndSettle();
        await capture('settings-$name');
      }
    }
    if (androidUi) {
      final refreshCount = workspaceRefreshes.length;
      await workspaceCommand('refresh');
      expect(workspaceRefreshes.skip(refreshCount), [
        (
          scope: allSyncScope,
          origin: SyncTrigger.manual,
          strategy: SyncStrategy.ordinary,
        ),
      ]);
      await workspaceCommand('about');
      await capture('about');
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await mode(ScheduleViewMode.day);
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      await capture('next-period');
      await tester.tap(find.byTooltip('Previous page'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Today'));
      await tester.pumpAndSettle();
      final movedRow = await (db.select(
        db.calendarEvents,
      )..where((r) => r.id.equals('meeting-0'))).getSingle();
      final originalStart = providerDateTimeAsUtcInstant(
            movedRow.startDateTime,
            movedRow.startTimeZone,
          )!,
          originalEnd = providerDateTimeAsUtcInstant(
            movedRow.endDateTime,
            movedRow.endTimeZone,
          )!;
      var expectedStart = originalStart, expectedEnd = originalEnd;
      for (final action in [
        'move',
        'resizeEnd',
        'resizeStart',
        'cancel',
        'restore',
      ]) {
        debugPrint('Checking native planner gesture: $action');
        final event = find
            .byWidgetPredicate(
              (w) => w is ScheduleEventInteraction && w.item.id == 'meeting-0',
            )
            .first;
        // Bring the event into the timed viewport through actual scroll input.
        // Infinite horizontal scroll positions do not implement ensureVisible
        // with the same completion contract as ordinary Flutter scroll views.
        for (var attempt = 0; attempt < 12; attempt++) {
          final coordinates = tester
              .state<ScheduleInteractionRegionState>(
                find.byType(ScheduleInteractionRegion),
              )
              .widget
              .coordinates!;
          final box = coordinates.box!;
          final origin = box.localToGlobal(Offset.zero);
          final top = origin.dy + coordinates.gridTop;
          final bottom = origin.dy + box.size.height;
          final center = tester.getCenter(event).dy;
          final middle = (top + bottom) / 2;
          if ((center - middle).abs() < 130) break;
          await tester.dragFrom(
            origin +
                Offset(
                  coordinates.gutterWidth / 2,
                  (coordinates.gridTop + box.size.height) / 2,
                ),
            Offset(0, center > middle ? -180 : 180),
          );
          await tester.pumpAndSettle();
        }
        final planner = tester.state<icv.EventsPlannerState>(
          find.byType(icv.EventsPlanner),
        );
        final target = action.startsWith('resize')
            ? find.byKey(ValueKey('schedule-$action-meeting-0'))
            : event;
        final gesture = await tester.startGesture(tester.getCenter(target));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(
          Offset(
            0,
            (action == 'restore'
                    ? -45
                    : action == 'move' || action == 'cancel'
                    ? 30
                    : 15) *
                planner.heightPerMinute,
          ),
        );
        await tester.pump();
        await capture('touch-$action-preview', settle: false);
        if (action == 'cancel') {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await capture('touch-$action-released', settle: false);
        for (var frame = 0; frame < 100; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (!tester
              .state<ScheduleInteractionRegionState>(
                find.byType(ScheduleInteractionRegion),
              )
              .active) {
            break;
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        expect(
          tester
              .state<ScheduleInteractionRegionState>(
                find.byType(ScheduleInteractionRegion),
              )
              .active,
          isFalse,
          reason:
              'The $action proposal must finish or cancel through the shared coordinator',
        );
        expect(tester.takeException(), isNull);
        if (action == 'move' || action == 'restore') {
          final delta = Duration(minutes: action == 'restore' ? -45 : 30);
          expectedStart = expectedStart.add(delta);
          expectedEnd = expectedEnd.add(delta);
        } else if (action == 'resizeStart') {
          expectedStart = expectedStart.add(const Duration(minutes: 15));
        } else if (action == 'resizeEnd') {
          expectedEnd = expectedEnd.add(const Duration(minutes: 15));
        }
        final saved = await (db.select(
          db.calendarEvents,
        )..where((r) => r.id.equals('meeting-0'))).getSingle();
        expect(
          providerDateTimeAsUtcInstant(
            saved.startDateTime,
            saved.startTimeZone,
          ),
          expectedStart,
          reason: '$action start',
        );
        expect(
          providerDateTimeAsUtcInstant(saved.endDateTime, saved.endTimeZone),
          expectedEnd,
          reason: '$action end',
        );
        if (action == 'cancel') await capture('touch-committed');
      }
      final moved = await (db.select(
        db.calendarEvents,
      )..where((r) => r.id.equals('meeting-0'))).getSingle();
      expect(
        providerDateTimeAsUtcInstant(moved.startDateTime, moved.startTimeZone),
        originalStart,
      );
      expect(
        providerDateTimeAsUtcInstant(moved.endDateTime, moved.endTimeZone),
        originalEnd,
      );
      await capture('touch-restored');
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) => w is ScheduleEventInteraction && w.item.id == 'meeting-0',
            )
            .first,
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Edit event'), findsWidgets);
      await capture('planner-event-preview');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      debugPrint('Checking workspace search and filters');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      await capture('search-open');
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await capture('search-filters');
      await tester.tap(
        find.byType(DropdownButtonFormField<ScheduleSearchType>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks').last);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Overdue follow-up 0'), findsWidgets);
      await capture('task-search');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await mode(ScheduleViewMode.agenda);
      await tester.tap(find.text('Overdue follow-up 0').first);
      await tester.pumpAndSettle();
      await capture('task-preview');
      await tester.ensureVisible(find.text('Edit Task').last);
      await tester.tap(find.text('Edit Task').last);
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsOneWidget);
      await capture('task-editor');
      if (nativeViewports) {
        final field = find.widgetWithText(TextField, 'Title');
        await tester.ensureVisible(field);
        final point = tester.getCenter(field);
        await nativeRequest({
          'kind': 'focus',
          'x': (point.dx * tester.view.devicePixelRatio).round(),
          'y': (point.dy * tester.view.devicePixelRatio).round(),
        });
        for (
          var attempt = 0;
          attempt < 30 && tester.view.viewInsets.bottom == 0;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          tester.view.viewInsets.bottom,
          greaterThan(0),
          reason: 'Native keyboard must be visible',
        );
        await capture('task-keyboard');
      }
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Draft kept on Back',
      );
      await tester.pumpAndSettle();
      if (nativeViewports) {
        await nativeRequest({'kind': 'back'});
        if (find.text('Discard').evaluate().isEmpty) {
          await nativeRequest({'kind': 'back'});
        }
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.text('Discard'), findsWidgets);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('Draft kept on Back'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      container
          .read(androidWorkspaceRequestProvider.notifier)
          .state = AndroidWorkspaceRequest(
        date: DateTime.now(),
        itemId: 'date-only-task',
        accountId: 'google:populated',
        taskListId: 'visible-list',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Project notes, line 30.'), findsOneWidget);
      await capture('long-task-preview');
      await tester.drag(
        find.byKey(const ValueKey('android-schedule-details-scroll')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit Task').last);
      await tester.tap(find.text('Edit Task').last);
      await tester.pumpAndSettle();
      final notesField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Notes',
      );
      await tester.ensureVisible(notesField);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(notesField).controller!.text,
        contains('Project notes, line 30.'),
      );
      await capture('long-task-notes');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      container
          .read(androidWorkspaceRequestProvider.notifier)
          .state = AndroidWorkspaceRequest(
        date: DateTime.now(),
        itemId: 'meeting-0',
        accountId: 'google:populated',
      );
      await tester.pumpAndSettle();
      await capture('event-preview');
      await tester.ensureVisible(find.text('Edit event').last);
      await tester.tap(find.text('Edit event').last);
      await tester.pumpAndSettle();
      await capture('event-editor');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await controller.setDefaultTaskList(
        const CreationDestination(
          accountId: 'google:populated',
          id: 'visible-list',
        ),
      );
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'New task'));
      await tester.pumpAndSettle();
      expect(find.byType(AndroidTaskEditor), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'QA created task',
      );
      await tester.pumpAndSettle();
      await capture('task-creation');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
        (await db.tasksDao.listTasks(
          'google:populated',
          'visible-list',
        )).any((task) => task.title == 'QA created task'),
        isTrue,
      );
      await controller.setDefaultCalendar(
        const CreationDestination(
          accountId: 'google:populated',
          id: 'calendar',
        ),
      );
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'New event'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'QA created event',
      );
      await tester.pumpAndSettle();
      await capture('event-creation');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
        (await db.select(db.calendarEvents).get()).any(
          (event) => event.title == 'QA created event',
        ),
        isTrue,
      );
      await workspaceCommand('settings');
      await capture('settings');
      Future<void> settingsCategory(AndroidSettingsCategory value) async {
        final selector = find.byType(
          DropdownButtonFormField<AndroidSettingsCategory>,
        );
        if (selector.evaluate().isNotEmpty) {
          await tester.tap(selector);
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .text(
                  androidSettingsCategoryLabel(
                    tester.element(find.byType(AndroidSettingsScreen)),
                    value,
                  ),
                )
                .hitTestable()
                .last,
          );
        } else {
          await tester.tap(
            find
                .widgetWithText(
                  ListTile,
                  androidSettingsCategoryLabel(
                    tester.element(find.byType(AndroidSettingsScreen)),
                    value,
                  ),
                )
                .first,
          );
        }
        await tester.pumpAndSettle();
        if (selector.evaluate().isNotEmpty) {
          expect(
            tester
                .state<FormFieldState<AndroidSettingsCategory>>(selector)
                .value,
            value,
          );
        } else {
          expect(
            tester
                .widgetList<ListTile>(find.byType(ListTile))
                .any(
                  (tile) =>
                      tile.selected &&
                      tile.title is Text &&
                      (tile.title as Text).data ==
                          androidSettingsCategoryLabel(
                            tester.element(find.byType(AndroidSettingsScreen)),
                            value,
                          ),
                ),
            isTrue,
          );
        }
      }

      await settingsCategory(AndroidSettingsCategory.accounts);
      await capture('settings-accounts');
      await tester.ensureVisible(find.text('Calendar Account').last);
      await tester.tap(find.text('Calendar Account').last);
      await tester.pumpAndSettle();
      await capture('settings-account-detail');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await capture('settings-accounts-return');
      for (final value in [
        AndroidSettingsCategory.schedule,
        AndroidSettingsCategory.notifications,
        AndroidSettingsCategory.privacy,
        AndroidSettingsCategory.diagnostics,
      ]) {
        await settingsCategory(value);
        await capture('settings-${value.name}');
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      for (final (size, scale)
          in phone
              ? <(Size, double)>[]
              : [
                  (const Size(360, 800), 1.0),
                  (const Size(412, 915), 1.3),
                  (const Size(915, 412), 1.3),
                  (const Size(1200, 800), 1.0),
                  (const Size(800, 1280), 2.0),
                  (const Size(320, 500), 2.0),
                ]) {
        if (nativeViewports) {
          await nativeRequest({
            'kind': 'viewport',
            'width': size.width.toInt(),
            'height': size.height.toInt(),
            'scale': scale,
          });
        } else {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.binding.handleMetricsChanged();
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          tester.binding.handleTextScaleFactorChanged();
        }
        for (final value in ScheduleViewMode.values) {
          await mode(value);
          await capture('${size.width.toInt()}-$scale-${value.name}');
          if (size.width == 320 && value == ScheduleViewMode.month) {
            final now = DateTime.now(),
                today = DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                );
            final marker = find.byKey(
              ValueKey('month-day-marker-${today.toIso8601String()}'),
            );
            final month = find.byWidgetPredicate(
              (w) => w is month_view.ScheduleMonthView,
            );
            await tester.scrollUntilVisible(
              marker,
              120,
              scrollable: find
                  .descendant(of: month, matching: find.byType(Scrollable))
                  .first,
            );
            await tester.pumpAndSettle();
            final cell = find
                .ancestor(of: marker, matching: find.byType(ScheduleDateTarget))
                .first;
            await tester.tap(
              find
                  .descendant(of: cell, matching: find.byType(TextButton))
                  .first,
            );
            await tester.pumpAndSettle();
            expect(
              find.text(
                MaterialLocalizations.of(
                  tester.element(find.byType(Scaffold).first),
                ).formatFullDate(now),
              ),
              findsWidgets,
            );
            await capture('320-month-dated-overflow');
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }

          expect(
            tester.takeException(),
            isNull,
            reason: '$size text $scale ${value.name}',
          );
        }
        if (size.width == 320) {
          container
              .read(androidWorkspaceRequestProvider.notifier)
              .state = AndroidWorkspaceRequest(
            date: DateTime.now(),
            itemId: 'meeting-0',
            accountId: 'google:populated',
          );
          await tester.pumpAndSettle();
          await capture('320-event-preview');
          await tester.ensureVisible(find.text('Edit event').last);
          await tester.tap(find.text('Edit event').last);
          await tester.pumpAndSettle();
          await capture('320-event-editor');
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
          container
              .read(androidWorkspaceRequestProvider.notifier)
              .state = AndroidWorkspaceRequest(
            date: DateTime.now(),
            itemId: 'old-0',
            accountId: 'google:populated',
            taskListId: 'visible-list',
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Edit Task').last);
          await tester.tap(find.text('Edit Task').last);
          await tester.pumpAndSettle();
          await capture('320-task-editor');
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
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
          await capture('320-schedule-settings');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Calendars and task lists'));
          await tester.pumpAndSettle();
          await capture('320-sources');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
      await controller.setLocaleTag('ar');
      await controller.setThemeModePreference(BusyMaxThemeModePreference.dark);
      await mode(ScheduleViewMode.week);
      await capture('rtl-dark-week');
      await controller.setLocaleTag('en');
      await controller.setThemeModePreference(BusyMaxThemeModePreference.light);
      if (nativeViewports && !phone) {
        await nativeRequest({
          'kind': 'viewport',
          'width': 390,
          'height': 844,
          'scale': 1.0,
        });
      } else if (!nativeViewports) {
        tester.view.physicalSize = const Size(390, 844);
        tester.binding.handleMetricsChanged();
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        tester.binding.handleTextScaleFactorChanged();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Calendars and task lists'));
      await tester.pumpAndSettle();
      await capture('phone-sources');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      debugPrint('Checking inline all-day panel and creation gestures');
      await mode(ScheduleViewMode.day);
      await tester.tap(find.byTooltip('Today'));
      await tester.pumpAndSettle();
      SchedulePlannerCoordinates coordinates() => tester
          .state<ScheduleInteractionRegionState>(
            find.byType(ScheduleInteractionRegion),
          )
          .widget
          .coordinates!;
      final allDayScroll = find.byKey(
        const ValueKey('schedule-all-day-scroll'),
      );
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(of: allDayScroll, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      final originalScroll = scroll.pixels;
      await tester.dragFrom(
        tester.getCenter(allDayScroll),
        const Offset(0, -36),
      );
      await tester.pumpAndSettle();
      expect(scroll.pixels, greaterThan(originalScroll));
      await capture('all-day-scrolled');
      final handle = find.byKey(
        const ValueKey('schedule-all-day-resize-handle'),
      );
      final originalHeight = coordinates().allDayHeight;
      await tester.drag(handle, const Offset(0, 48));
      await tester.pumpAndSettle();
      expect(coordinates().allDayHeight, greaterThan(originalHeight));
      await capture('all-day-expanded');
      await tester.tap(handle);
      await tester.pumpAndSettle();
      expect(coordinates().allDayHeight, originalHeight);
      // The planner shares the user's vertical position between Day and Week.
      // Scroll the early empty interval into view before activating it.
      for (
        var attempt = 0;
        attempt < 12 &&
            coordinates().planner!.mainVerticalController.offset > 1;
        attempt++
      ) {
        final c = coordinates(), box = coordinates().box!;
        await tester.dragFrom(
          box.localToGlobal(
            Offset(c.gutterWidth / 2, (c.gridTop + box.size.height) / 2),
          ),
          Offset(0, (box.size.height - c.gridTop) * .7),
        );
        await tester.pumpAndSettle();
      }
      expect(
        coordinates().planner!.mainVerticalController.offset,
        closeTo(0, 1),
      );
      Offset emptySlot(int minute) {
        final c = coordinates(), planner = c.planner!;
        return c.box!.localToGlobal(
          Offset(
            c.gutterWidth + planner.dayWidth * .65,
            c.gridTop +
                c.dayTopPadding +
                minute * planner.heightPerMinute -
                planner.mainVerticalController.offset,
          ),
        );
      }

      await tester.tapAt(emptySlot(2 * 60));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'New event'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'New task'), findsOneWidget);
      await capture('empty-slot-choice');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final range = await tester.startGesture(emptySlot(2 * 60));
      await tester.pump(const Duration(milliseconds: 600));
      await range.moveTo(emptySlot(2 * 60 + 30));
      await tester.pump();
      await capture('range-preview', settle: false);
      await range.up();
      await tester.pumpAndSettle();
      expect(find.byType(AndroidEventEditor), findsOneWidget);
      final intervalDraft = tester
          .widget<AndroidEventEditor>(find.byType(AndroidEventEditor))
          .draft;
      expect(intervalDraft.start!.hour, 2);
      expect(intervalDraft.start!.minute, 0);
      expect(
        intervalDraft.end!.difference(intervalDraft.start!),
        const Duration(minutes: 30),
      );
      await capture('range-event-editor');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      final previousScale = coordinates().planner!.heightPerMinute;
      final firstFinger = await tester.startGesture(
        emptySlot(2 * 60),
        pointer: 31,
      );
      final secondFinger = await tester.startGesture(
        emptySlot(3 * 60),
        pointer: 32,
      );
      await tester.pump();
      await firstFinger.moveBy(const Offset(0, -30));
      await secondFinger.moveBy(const Offset(0, 30));
      await tester.pump();
      await firstFinger.moveBy(const Offset(0, -10));
      await secondFinger.moveBy(const Offset(0, 10));
      await tester.pump();
      await firstFinger.up();
      await secondFinger.up();
      await tester.pumpAndSettle();
      expect(
        coordinates().planner!.heightPerMinute,
        greaterThan(previousScale),
      );
      await capture('pinch-scaled-planner');
      debugPrint('Checking Month date creation and live overflow completion');
      await mode(ScheduleViewMode.month);
      final now = DateTime.now(),
          today = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          );
      final targetDay = DateTime(now.year, now.month, now.day + 7);
      Finder dayMarker(DateTime day) =>
          find.byKey(ValueKey('month-day-marker-${day.toIso8601String()}'));
      await tester.tap(dayMarker(targetDay));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Create').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'New event'));
      await tester.pumpAndSettle();
      final dateDraft = tester
          .widget<AndroidEventEditor>(find.byType(AndroidEventEditor))
          .draft;
      expect(
        DateTime(
          dateDraft.start!.year,
          dateDraft.start!.month,
          dateDraft.start!.day,
        ),
        targetDay,
      );
      expect(dateDraft.start!.hour, 9);
      await capture('month-date-creation');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(dayMarker(today));
      await tester.pumpAndSettle();
      final dateCell = find
          .ancestor(
            of: dayMarker(today),
            matching: find.byType(ScheduleDateTarget),
          )
          .first;
      await tester.tap(
        find.descendant(of: dateCell, matching: find.byType(TextButton)).first,
      );
      await tester.pumpAndSettle();
      await capture('month-date-overflow');
      final taskRow = find.widgetWithText(ListTile, 'Date-only task');
      await tester.ensureVisible(taskRow);
      await tester.pumpAndSettle();
      Finder completion() =>
          find.descendant(of: taskRow, matching: find.byType(Checkbox));
      await tester.tap(completion());
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(completion()).value, isTrue);
      await tester.tap(completion());
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(completion()).value, isFalse);
      await capture('month-overflow-completion-restored');
      await tester.tap(taskRow);
      await tester.pumpAndSettle();
      expect(find.text('Edit Task'), findsWidgets);
      await capture('month-overflow-task-preview');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      debugPrint('Checking narrow Month all-day move and both boundaries');
      final allDayEvent = await (db.select(
        db.calendarEvents,
      )..where((event) => event.id.equals('all-day-1'))).getSingle();
      // Put this existing fixture event on an otherwise empty date so Month
      // exposes its actual compact card, independently of the More surface.
      final experimentDay = DateTime(today.year, today.month, 25);
      String dateValue(DateTime day) => day.toIso8601String().substring(0, 10);
      await (db.update(
        db.calendarEvents,
      )..where((event) => event.id.equals(allDayEvent.id))).write(
        CalendarEventsCompanion(
          startDate: Value(dateValue(experimentDay)),
          endDate: Value(dateValue(experimentDay.add(const Duration(days: 1)))),
          organizerJson: const Value('{"email":"me@example.com","self":true}'),
        ),
      );
      await tester.pumpAndSettle();
      var expectedAllDayStart = experimentDay;
      var expectedAllDayEnd = experimentDay.add(const Duration(days: 1));
      for (final (action, offset) in [
        ('move', 1),
        ('resizeEnd', 2),
        ('resizeStart', 0),
        ('cancel', -1),
        ('restore', 0),
      ]) {
        final interaction = find.byWidgetPredicate(
          (w) => w is ScheduleEventInteraction && w.item.id == allDayEvent.id,
        );
        expect(
          (tester.widget<ScheduleEventInteraction>(interaction.first).item
                  as CalendarScheduleItem)
              .canReschedule,
          isTrue,
          reason: 'The all-day gesture fixture must satisfy provider timing policy.',
        );
        final resizeAction = action == 'restore' ? 'resizeEnd' : action;
        final source = resizeAction.startsWith('resize')
            ? find.byKey(ValueKey('schedule-$resizeAction-${allDayEvent.id}'))
            : interaction.first;
        final targetDay = experimentDay.add(Duration(days: offset));
        final target = find.byWidgetPredicate(
          (w) => w is ScheduleDateTarget && w.date == targetDay,
        );
        final gesture = await tester.startGesture(tester.getCenter(source));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(tester.getCenter(target));
        await tester.pump();
        await capture('month-all-day-$action-preview', settle: false);
        if (action == 'cancel') {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(
          tester
              .state<ScheduleInteractionRegionState>(
                find.byType(ScheduleInteractionRegion),
              )
              .active,
          isFalse,
        );
        if (action == 'move') {
          final duration = expectedAllDayEnd.difference(expectedAllDayStart);
          expectedAllDayStart = targetDay;
          expectedAllDayEnd = targetDay.add(duration);
        } else if (action == 'resizeStart') {
          expectedAllDayStart = targetDay;
        } else if (action == 'resizeEnd' || action == 'restore') {
          expectedAllDayEnd = targetDay.add(const Duration(days: 1));
        }
        final saved = await (db.select(
          db.calendarEvents,
        )..where((event) => event.id.equals(allDayEvent.id))).getSingle();
        expect(
          saved.startDate,
          dateValue(expectedAllDayStart),
          reason: '$action start',
        );
        expect(
          saved.endDate,
          dateValue(expectedAllDayEnd),
          reason: '$action end',
        );
        await capture('month-all-day-$action-saved');
      }
      await (db.update(
        db.calendarEvents,
      )..where((event) => event.id.equals(allDayEvent.id))).write(
        CalendarEventsCompanion(
          startDate: Value(allDayEvent.startDate),
          endDate: Value(allDayEvent.endDate),
          organizerJson: Value(allDayEvent.organizerJson),
        ),
      );
      await tester.pumpAndSettle();
      await (db.update(db.calendarSources)
            ..where((source) => source.id.equals('calendar')))
          .write(const CalendarSourcesCompanion(readOnly: Value(true)));
      container
          .read(androidWorkspaceRequestProvider.notifier)
          .state = AndroidWorkspaceRequest(
        date: DateTime.now(),
        itemId: 'meeting-0',
        accountId: 'google:populated',
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit event'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      await capture('read-only-preview');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await db.delete(db.calendarEvents).go();
      await db.delete(db.tasks).go();
      await mode(ScheduleViewMode.agenda);
      await capture('empty-agenda');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await notifications.dispose();
    await db.close();
  });
}
