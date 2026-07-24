import 'dart:async';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_toolbar.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../../../test_localized_app.dart';

const _nativeMenuChannel = MethodChannel(nativeMenuChannelName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _nativeMenuChannel,
          (_) async => throw MissingPluginException(),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, null);
  });

  testWidgets('toolbar delegates create selection to the native menu host', (
    tester,
  ) async {
    MethodCall? nativeCall;
    var events = 0;
    var tasks = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, (call) async {
          nativeCall = call;
          return 1;
        });

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.week,
              range: ScheduleRange.week(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (_) {},
              canCreateEvent: true,
              canCreateTask: true,
              onCreateEvent: () => events++,
              onCreateTask: () => tasks++,
              onRefresh: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();

    expect(events, 0);
    expect(tasks, 1);
    expect(nativeCall?.method, 'show');
    expect((nativeCall?.arguments as Map<Object?, Object?>)['entries'], [
      {'label': 'Event', 'enabled': true, 'selected': false},
      {'label': 'Task', 'enabled': true, 'selected': false},
    ]);
    expect(find.byType(PopupMenuItem<int>), findsNothing);
  });

  testWidgets('fallback toolbar exposes the complete shell command set', (
    tester,
  ) async {
    var sidebarToggles = 0;
    var searches = 0;
    var events = 0;
    var tasks = 0;
    ScheduleViewMode? selectedMode;
    ScheduleToolbarMenuAction? selectedMenuAction;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.week,
              range: ScheduleRange.week(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (value) => selectedMode = value,
              canCreateEvent: true,
              canCreateTask: true,
              onCreateEvent: () => events++,
              onCreateTask: () => tasks++,
              onRefresh: () {},
              canShowSidebar: true,
              sidebarVisible: true,
              onToggleSidebar: () => sidebarToggles++,
              onSearch: () => searches++,
              onMenuSelected: (value) => selectedMenuAction = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Toggle Sidebar'));
    await tester.tap(find.byTooltip('Search'));
    expect(sidebarToggles, 1);
    expect(searches, 1);

    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<int>), findsNWidgets(2));
    expect(find.byType(YaruRadio<int>), findsNothing);
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    await tester.tap(find.text('Event'));
    await tester.pumpAndSettle();
    expect(events, 1);
    expect(tasks, 0);

    await tester.tap(find.byTooltip('Week'));
    await tester.pumpAndSettle();
    expect(
      find.byType(PopupMenuItem<int>),
      findsNWidgets(ScheduleViewMode.values.length),
    );
    expect(
      find.byType(YaruRadio<int>),
      findsNWidgets(ScheduleViewMode.values.length),
    );
    await tester.tap(
      find.ancestor(
        of: find.text('Month'),
        matching: find.byType(PopupMenuItem<int>),
      ),
    );
    await tester.pumpAndSettle();
    expect(selectedMode, ScheduleViewMode.month);

    await tester.tap(find.byTooltip('Main Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<int>), findsNWidgets(3));
    expect(find.byType(YaruRadio<int>), findsNothing);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(selectedMenuAction, ScheduleToolbarMenuAction.settings);
  });

  testWidgets('compact fallback moves refresh into the main menu', (
    tester,
  ) async {
    var refreshes = 0;
    ScheduleToolbarMenuAction? selectedMenuAction;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 700,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.agenda,
              range: ScheduleRange.day(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (_) {},
              canCreateEvent: true,
              canCreateTask: true,
              onCreateEvent: () {},
              onCreateTask: () {},
              onRefresh: () => refreshes++,
              onMenuSelected: (value) {
                selectedMenuAction = value;
                if (value == ScheduleToolbarMenuAction.refresh) {
                  refreshes++;
                }
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Refresh all'), findsNothing);
    await tester.tap(find.byTooltip('Main Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<int>), findsNWidgets(4));
    await tester.tap(find.text('Refresh all'));
    await tester.pumpAndSettle();

    expect(selectedMenuAction, ScheduleToolbarMenuAction.refresh);
    expect(refreshes, 1);
  });

  testWidgets('fallback create menu keeps actions capability-aware', (
    tester,
  ) async {
    var events = 0;
    var tasks = 0;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.week,
              range: ScheduleRange.week(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (_) {},
              canCreateEvent: false,
              canCreateTask: true,
              onCreateEvent: () => events++,
              onCreateTask: () => tasks++,
              onRefresh: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<int>), findsNWidgets(2));
    expect(find.byType(YaruRadio<int>), findsNothing);
    final eventItem = tester.widget<PopupMenuItem<int>>(
      find.ancestor(
        of: find.text('Event'),
        matching: find.byType(PopupMenuItem<int>),
      ),
    );
    final taskItem = tester.widget<PopupMenuItem<int>>(
      find.ancestor(
        of: find.text('Task'),
        matching: find.byType(PopupMenuItem<int>),
      ),
    );
    expect(eventItem.enabled, isFalse);
    expect(taskItem.enabled, isTrue);

    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();
    expect(events, 0);
    expect(tasks, 1);
  });

  testWidgets(
    'keyboard controller opens and focuses the fallback create menu',
    (tester) async {
      final controller = BusyMaxMenuController();

      await tester.pumpWidget(
        localizedTestApp(
          child: Scaffold(
            body: SizedBox(
              width: 1000,
              child: ScheduleToolbar(
                mode: ScheduleViewMode.week,
                range: ScheduleRange.week(DateTime(2026, 7, 22)),
                selectedDate: DateTime(2026, 7, 22),
                onToday: () {},
                onPrevious: () {},
                onNext: () {},
                onModeChanged: (_) {},
                canCreateEvent: true,
                canCreateTask: true,
                onCreateEvent: () {},
                onCreateTask: () {},
                onRefresh: () {},
                createMenuController: controller,
              ),
            ),
          ),
        ),
      );

      expect(controller.openForKeyboard(), isTrue);
      expect(controller.isOpen, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuItem<int>), findsNWidgets(2));
      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);

      final trigger = tester.widget<YaruIconButton>(
        find.ancestor(
          of: find.byTooltip('Create'),
          matching: find.byType(YaruIconButton),
        ),
      );
      expect(trigger.focusNode, isNotNull);
      expect(Focus.of(tester.element(find.text('Event'))).hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(find.byType(PopupMenuItem<int>), findsNothing);
      expect(find.text('Event'), findsNothing);
      expect(find.text('Task'), findsNothing);
    },
  );

  testWidgets('controller close dismisses a pending native menu', (
    tester,
  ) async {
    final controller = BusyMaxMenuController();
    final nativeSelection = Completer<int?>();
    var showCalls = 0;
    var dismissCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, (call) async {
          switch (call.method) {
            case 'show':
              showCalls += 1;
              return nativeSelection.future;
            case 'dismiss':
              dismissCalls += 1;
              if (!nativeSelection.isCompleted) {
                nativeSelection.complete();
              }
              return true;
          }
          throw MissingPluginException();
        });

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.week,
              range: ScheduleRange.week(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (_) {},
              canCreateEvent: true,
              canCreateTask: true,
              onCreateEvent: () {},
              onCreateTask: () {},
              onRefresh: () {},
              createMenuController: controller,
            ),
          ),
        ),
      ),
    );

    expect(controller.openForKeyboard(), isTrue);
    await tester.pump();

    expect(controller.isOpen, isTrue);
    expect(showCalls, 1);
    expect(find.byType(PopupMenuItem<int>), findsNothing);

    controller.close();
    await tester.pumpAndSettle();

    expect(dismissCalls, 1);
    expect(controller.isOpen, isFalse);
    expect(find.byType(PopupMenuItem<int>), findsNothing);
  });

  testWidgets('keyboard controller follows a responsive toolbar replacement', (
    tester,
  ) async {
    final controller = BusyMaxMenuController();
    final nestToolbar = ValueNotifier(false);
    addTearDown(nestToolbar.dispose);

    Widget buildToolbar() {
      return ScheduleToolbar(
        mode: ScheduleViewMode.week,
        range: ScheduleRange.week(DateTime(2026, 7, 22)),
        selectedDate: DateTime(2026, 7, 22),
        onToday: () {},
        onPrevious: () {},
        onNext: () {},
        onModeChanged: (_) {},
        canCreateEvent: true,
        canCreateTask: true,
        onCreateEvent: () {},
        onCreateTask: () {},
        onRefresh: () {},
        createMenuController: controller,
      );
    }

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ValueListenableBuilder(
              valueListenable: nestToolbar,
              builder: (context, nested, child) {
                final toolbar = buildToolbar();
                return nested
                    ? Row(children: [Expanded(child: toolbar)])
                    : toolbar;
              },
            ),
          ),
        ),
      ),
    );
    expect(controller.isAttached, isTrue);

    nestToolbar.value = true;
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.isAttached, isTrue);
    expect(controller.openForKeyboard(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<int>), findsNWidgets(2));
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(Focus.of(tester.element(find.text('Event'))).hasFocus, isTrue);

    controller.close();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(find.byType(PopupMenuItem<int>), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    expect(controller.isAttached, isFalse);
    expect(controller.openForKeyboard(), isFalse);
  });

  testWidgets('create trigger disables when no creation kind is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.week,
              range: ScheduleRange.week(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (_) {},
              canCreateEvent: false,
              canCreateTask: false,
              onCreateEvent: () {},
              onCreateTask: () {},
              onRefresh: () {},
            ),
          ),
        ),
      ),
    );

    final trigger = tester.widget<YaruIconButton>(
      find.ancestor(
        of: find.byTooltip('Create'),
        matching: find.byType(YaruIconButton),
      ),
    );
    expect(trigger.onPressed, isNull);
    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Event'), findsNothing);
    expect(find.text('Task'), findsNothing);
  });
}
