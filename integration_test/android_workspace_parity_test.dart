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
import 'package:busymax/src/features/task_lists/data/task_lists_repository.dart';
import 'package:busymax/src/features/tasks/data/tasks_repository.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:flutter/material.dart';
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
              'currentTimeZoneId' => 'America/Vancouver',
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
    final container = ProviderContainer(
      overrides: [
        if (headerIcons != null)
          gtkHeaderIconServiceProvider.overrideWith((ref) {
            ref.onDispose(headerIcons.dispose);
            return headerIcons;
          }),
        databaseProvider.overrideWithValue(db),
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
        allAccountsSyncRunnerProvider.overrideWithValue(() async {}),
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
    final nativeViewports =
        Platform.isAndroid &&
        const bool.fromEnvironment('BUSYMAX_PARITY_NATIVE_VIEWPORTS');
    const phone = bool.fromEnvironment('BUSYMAX_PARITY_PHONE');
    final native = Directory(
      '${output.path}/native-${const String.fromEnvironment('BUSYMAX_PARITY_RUN_ID')}',
    );
    var sequence = 0;
    Future<void> nativeRequest(Map<String, Object> command) async {
      if (!nativeViewports) return;
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
      await tester.pumpAndSettle();
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
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${output.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      await nativeRequest({'kind': 'capture', 'name': name});
    }

    final controller = container.read(appSettingsControllerProvider.notifier);
    Future<void> mode(ScheduleViewMode value) async {
      if (androidUi) {
        await controller.setAndroidScheduleViewMode(value);
      } else {
        await controller.setScheduleViewMode(value);
      }
      await tester.pumpAndSettle();
    }

    for (final value in ScheduleViewMode.values) {
      await mode(value);
      await capture(value.name);
      expect(tester.takeException(), isNull);
    }
    if (androidUi) {
      await tester.tap(find.byTooltip('Schedule display'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All tasks').last);
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
        task: true,
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
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push<void>(
            MaterialPageRoute(builder: (_) => const AndroidSettingsScreen()),
          );
      await tester.pumpAndSettle();
      await capture('settings');
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
          expect(tester.takeException(), isNull);
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
            task: true,
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
