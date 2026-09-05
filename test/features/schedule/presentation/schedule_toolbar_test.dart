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

  testWidgets('fallback toolbar uses the semantic header title style', (
    tester,
  ) async {
    const inheritedTitleStyle = TextStyle(
      color: Color(0xFF123456),
      fontSize: 17,
      fontWeight: FontWeight.normal,
    );

    await tester.pumpWidget(
      localizedTestApp(
        theme: ThemeData(
          textTheme: const TextTheme(titleMedium: inheritedTitleStyle),
        ),
        child: Scaffold(
          body: SizedBox(
            width: 1200,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.agenda,
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
            ),
          ),
        ),
      ),
    );

    final titleFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == 'Agenda',
    );
    expect(titleFinder, findsOneWidget);
    final title = tester.widget<Text>(titleFinder);
    expect(title.style?.color, inheritedTitleStyle.color);
    expect(title.style?.fontSize, inheritedTitleStyle.fontSize);
    expect(title.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('day toolbar uses a localized standalone date heading', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedTestApp(
        locale: const Locale('ru'),
        child: Scaffold(
          body: SizedBox(
            width: 2000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.day,
              range: ScheduleRange.day(DateTime(2026, 9, 7)),
              selectedDate: DateTime(2026, 9, 7),
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

    expect(find.text('Понедельник, 7 сентября 2026 г.'), findsOneWidget);
  });

  testWidgets('Today is an accessible icon-only action', (tester) async {
    final semantics = tester.ensureSemantics();
    var activations = 0;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: ScheduleToolbar(
              mode: ScheduleViewMode.week,
              range: ScheduleRange.week(DateTime(2026, 7, 22)),
              selectedDate: DateTime(2026, 7, 22),
              onToday: () => activations++,
              onPrevious: () {},
              onNext: () {},
              onModeChanged: (_) {},
              canCreateEvent: true,
              canCreateTask: true,
              onCreateEvent: () {},
              onCreateTask: () {},
              onRefresh: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Today'), findsNothing);
    expect(find.byIcon(Icons.today_outlined), findsOneWidget);
    expect(find.byTooltip('Today (Shift+T)'), findsOneWidget);
    expect(find.bySemanticsLabel('Today'), findsOneWidget);

    await tester.tap(find.byTooltip('Today (Shift+T)'));
    expect(activations, 1);
    semantics.dispose();
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
      {
        'label': 'Event',
        'icon': 'x-office-calendar-symbolic',
        'enabled': true,
        'role': 'command',
        'selected': false,
        'shortcut': 'E',
      },
      {
        'label': 'Task',
        'icon': 'checkbox-checked-symbolic',
        'enabled': true,
        'role': 'command',
        'selected': false,
        'shortcut': 'T',
      },
    ]);
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNothing,
    );
  });

  testWidgets('fallback toolbar hides a range title that does not fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 600,
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
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data?.contains('2026') ?? false),
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.overflow == TextOverflow.ellipsis,
      ),
      findsNothing,
    );
  });

  testWidgets('fallback toolbar exposes the complete shell command set', (
    tester,
  ) async {
    var sidebarToggles = 0;
    var searches = 0;
    var events = 0;
    var tasks = 0;
    var sidebarVisible = true;
    ScheduleViewMode? selectedMode;
    ScheduleToolbarMenuAction? selectedMenuAction;

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            child: StatefulBuilder(
              builder: (context, setToolbarState) => ScheduleToolbar(
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
                sidebarVisible: sidebarVisible,
                onToggleSidebar: () {
                  sidebarToggles++;
                  setToolbarState(() => sidebarVisible = !sidebarVisible);
                },
                onSearch: () => searches++,
                onMenuSelected: (value) => selectedMenuAction = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Hide sidebar panel (F9)'));
    await tester.pump();
    expect(find.byTooltip('Show sidebar panel (F9)'), findsOneWidget);
    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    expect(sidebarToggles, 1);
    expect(searches, 1);

    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNWidgets(2),
    );
    expect(find.byType(YaruRadio<int>), findsNothing);
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    await tester.tap(find.text('Event'));
    await tester.pumpAndSettle();
    expect(events, 1);
    expect(tasks, 0);

    await tester.tap(find.byTooltip('Week (2)'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNWidgets(ScheduleViewMode.values.length),
    );
    expect(
      find.byType(YaruRadio<int>),
      findsNWidgets(ScheduleViewMode.values.length),
    );
    expect(find.text('Compact'), findsNothing);
    await tester.tap(
      find.ancestor(
        of: find.text('Month'),
        matching: find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<int>,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(selectedMode, ScheduleViewMode.month);

    await tester.tap(find.byTooltip('Main Menu'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNWidgets(4),
    );
    expect(find.byType(YaruRadio<int>), findsNothing);
    expect(find.text('Report an issue'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(selectedMenuAction, ScheduleToolbarMenuAction.settings);

    await tester.tap(find.byTooltip('Main Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report an issue'));
    await tester.pumpAndSettle();
    expect(selectedMenuAction, ScheduleToolbarMenuAction.reportIssue);
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
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNWidgets(5),
    );
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

    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNWidgets(2),
    );
    expect(find.byType(YaruRadio<int>), findsNothing);
    final eventItem = tester.widget<PopupMenuItem<int>>(
      find.ancestor(
        of: find.text('Event'),
        matching: find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<int>,
        ),
      ),
    );
    final taskItem = tester.widget<PopupMenuItem<int>>(
      find.ancestor(
        of: find.text('Task'),
        matching: find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<int>,
        ),
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

      expect(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
        findsNWidgets(2),
      );
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
      expect(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
        findsNothing,
      );
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
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNothing,
    );

    controller.close();
    await tester.pumpAndSettle();

    expect(dismissCalls, 1);
    expect(controller.isOpen, isFalse);
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNothing,
    );
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

    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNWidgets(2),
    );
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(Focus.of(tester.element(find.text('Event'))).hasFocus, isTrue);

    controller.close();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNothing,
    );
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
