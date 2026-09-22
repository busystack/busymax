import 'dart:async';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/common/busymax_motion_widgets.dart';
import 'package:busymax/src/app/linux/linux_header_style.dart';
import 'package:busymax/src/app/linux/linux_window_host.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_toolbar.dart';
import 'package:busymax/src/platform/gtk_window_preferences_service.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:busymax/src/schedule/schedule_filters.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:busymax/src/schedule/schedule_range.dart';
import 'package:busymax/src/schedule/schedule_repository.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const yaruWindowChannel = MethodChannel('yaru_window');
  const yaruEventsChannel = EventChannel('yaru_window/events');
  const nativeMenuChannel = MethodChannel(nativeMenuChannelName);
  late List<MethodCall> windowCalls;

  setUp(() {
    windowCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(yaruWindowChannel, (call) async {
      windowCalls.add(call);
      return call.method == 'state' ? <String, Object?>{} : null;
    });
    messenger.setMockStreamHandler(
      yaruEventsChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(nativeMenuChannel, (_) async => null);
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(yaruWindowChannel, null);
    messenger.setMockStreamHandler(yaruEventsChannel, null);
    messenger.setMockMethodCallHandler(nativeMenuChannel, null);
  });

  testWidgets(
    'Search changes only the center and schedule control visibility',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpWorkspace(tester, width: 1100);

      for (final key in const [
        'schedule-sidebar-button',
        'schedule-today-button',
        'schedule-previous-button',
        'schedule-next-button',
        'schedule-view-button',
        'schedule-create-button',
        'schedule-refresh-button',
        'schedule-search-button',
        'busymax-main-menu-button',
      ]) {
        expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
      }

      await _openSearch(tester);

      expect(find.byType(ScheduleToolbar), findsOneWidget);
      expect(find.byType(BusyMaxLinuxHeaderLayout), findsOneWidget);
      expect(
        find.byType(BusyMaxLinuxHeaderSearchField).hitTestable(),
        findsOneWidget,
      );
      for (final key in const [
        'schedule-sidebar-button',
        'schedule-search-button',
        'busymax-main-menu-button',
      ]) {
        expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
      }
      for (final key in const [
        'schedule-today-button',
        'schedule-previous-button',
        'schedule-next-button',
        'schedule-view-button',
        'schedule-create-button',
        'schedule-refresh-button',
        'schedule-search-filter-button',
        'schedule-search-close-button',
        'schedule-search-titlebar-drag-area',
      ]) {
        expect(find.byKey(ValueKey(key)).hitTestable(), findsNothing);
      }
      final searchButton = tester.widget<BusyMaxLinuxHeaderIconButton>(
        find.byKey(const ValueKey('schedule-search-button')),
      );
      expect(searchButton.selected, isTrue);
      expect(searchButton.icon, BusyMaxLinuxHeaderIcon.search);
      expect(
        tester
            .widgetList<BusyMaxGtkHeaderIcon>(
              find.descendant(
                of: find.byType(BusyMaxLinuxHeaderSearchField),
                matching: find.byType(BusyMaxGtkHeaderIcon),
              ),
            )
            .map((icon) => icon.icon),
        [BusyMaxLinuxHeaderIcon.searchEntryFind],
      );
      final headerRect = tester.getRect(find.byType(ScheduleToolbar));
      final fieldRect = tester.getRect(
        find.byType(BusyMaxLinuxHeaderSearchField),
      );
      expect(headerRect.height, BusyMaxSizes.toolbarHeight);
      expect(fieldRect.height, BusyMaxLinuxHeaderStyle.searchEntryHeight);
      expect(fieldRect.center.dy, closeTo(headerRect.center.dy, .5));
      _expectSearchFillsPhysicalInterval(tester, TextDirection.ltr);
      expect(
        tester
            .widget<BusyMaxLinuxHeaderLayout>(
              find.byType(BusyMaxLinuxHeaderLayout),
            )
            .centerAllocation,
        BusyMaxLinuxHeaderCenterAllocation.fillBetweenControls,
      );

      final textField = tester.widget<TextField>(_searchTextField());
      expect(textField.decoration?.hintText, isNull);
      expect(find.text('Search'), findsNothing);
      expect(find.bySemanticsLabel('Search'), findsOneWidget);
      semantics.dispose();

      await tester.tap(find.byTooltip('Search (Ctrl+F)'));
      await tester.pumpAndSettle();
      expect(
        find.byType(BusyMaxLinuxHeaderSearchField).hitTestable(),
        findsNothing,
      );

      await _openSearch(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byType(BusyMaxLinuxHeaderSearchField).hitTestable(),
        findsNothing,
      );
    },
  );

  for (final width in const [1290.0, 1100.0, 650.0]) {
    for (final direction in TextDirection.values) {
      testWidgets('Search fills the physical interval at $width in '
          '${direction.name}', (tester) async {
        await _pumpWorkspace(tester, width: width, direction: direction);
        if (width == 1290) {
          await tester.sendKeyEvent(LogicalKeyboardKey.f9);
          await tester.pumpAndSettle();
        }
        await _openSearch(tester);

        final headerRect = tester.getRect(find.byType(ScheduleToolbar));
        final fieldRect = tester.getRect(
          find.byType(BusyMaxLinuxHeaderSearchField),
        );
        if (width == 1290) {
          expect(headerRect.width, width);
        }
        expect(headerRect.height, BusyMaxSizes.toolbarHeight);
        expect(fieldRect.height, BusyMaxLinuxHeaderStyle.searchEntryHeight);
        expect(fieldRect.center.dy, closeTo(headerRect.center.dy, .5));
        expect(fieldRect.width, lessThan(headerRect.width));
        _expectSearchFillsPhysicalInterval(tester, direction);
      });
    }
  }

  for (final testCase in const [
    _SystemControlCase('left', _leftSystemControls, true),
    _SystemControlCase('right', _rightSystemControls, false),
  ]) {
    testWidgets('Search respects physical ${testCase.label} system controls', (
      tester,
    ) async {
      await _pumpWorkspace(
        tester,
        width: 1100,
        preferences: testCase.preferences,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.f9);
      await tester.pumpAndSettle();
      await _openSearch(tester);

      _expectSearchFillsPhysicalInterval(tester, TextDirection.ltr);
      final header = tester.getRect(find.byType(ScheduleToolbar));
      final leading = tester.getRect(
        find.byKey(const ValueKey('schedule-header-leading-actions')),
      );
      final trailing = tester.getRect(
        find.byKey(const ValueKey('schedule-header-trailing-actions')),
      );
      final obstruction = BusyMaxLinuxWindowMetrics.clusterWidth(
        testCase.preferences.decorationLayout.left.isNotEmpty
            ? testCase.preferences.decorationLayout.left
            : testCase.preferences.decorationLayout.right,
      );
      if (testCase.onLeft) {
        expect(
          leading.left,
          greaterThanOrEqualTo(
            header.left + obstruction + BusyMaxSpacing.headerInset,
          ),
        );
      } else {
        expect(
          trailing.right,
          lessThanOrEqualTo(
            header.right - obstruction - BusyMaxSpacing.headerInset,
          ),
        );
      }
    });
  }

  testWidgets('title and Search retain centered opacity-only geometry', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_ToolbarHarnessState>();
    await _pumpToolbarHarness(tester, harnessKey: harnessKey, width: 1100);

    final normalSlot = tester.getRect(_scheduleCenterPresentation());
    final normalTitle = _scheduleCenterTitle();
    expect(
      tester.getRect(normalTitle).center.dx,
      closeTo(normalSlot.center.dx, .01),
    );

    harnessKey.currentState!.setSearchActive(true);
    await tester.pump();
    final searchSlot = tester.getRect(_scheduleCenterPresentation());
    _expectTransitionGeometry(tester, searchSlot);

    await tester.pump(const Duration(milliseconds: 80));
    _expectTransitionGeometry(tester, searchSlot);

    await tester.pump(const Duration(milliseconds: 80));
    _expectTransitionGeometry(tester, searchSlot);
  });

  testWidgets('title and Search geometry remains stable through reversal', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_ToolbarHarnessState>();
    await _pumpToolbarHarness(tester, harnessKey: harnessKey, width: 1100);
    final normalSlot = tester.getRect(_scheduleCenterPresentation());

    harnessKey.currentState!.setSearchActive(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final searchSlot = tester.getRect(_scheduleCenterPresentation());
    _expectTransitionGeometry(tester, searchSlot);

    harnessKey.currentState!.setSearchActive(false);
    await tester.pump();
    _expectRectCloseTo(
      tester.getRect(_scheduleCenterPresentation()),
      normalSlot,
    );
    _expectTransitionGeometry(
      tester,
      normalSlot,
      expectSearchHitTestable: false,
    );

    await tester.pump(const Duration(milliseconds: 80));
    _expectRectCloseTo(
      tester.getRect(_scheduleCenterPresentation()),
      normalSlot,
    );
    expect(
      tester.getRect(_scheduleCenterTitle()).center.dx,
      closeTo(normalSlot.center.dx, .01),
    );
  });

  testWidgets('reduced motion uses full interval without a stale frame', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final harnessKey = GlobalKey<_ToolbarHarnessState>();
    await _pumpToolbarHarness(tester, harnessKey: harnessKey, width: 1100);

    harnessKey.currentState!.setSearchActive(true);
    await tester.pump();
    _expectSearchFillsPhysicalInterval(tester, TextDirection.ltr);
    expect(_scheduleCenterTitle().hitTestable(), findsNothing);

    harnessKey.currentState!.setSearchActive(false);
    await tester.pump();
    expect(
      find.byType(BusyMaxLinuxHeaderSearchField).hitTestable(),
      findsNothing,
    );
    final slot = tester.getRect(_scheduleCenterPresentation());
    expect(
      tester.getRect(_scheduleCenterTitle()).center.dx,
      closeTo(slot.center.dx, .01),
    );
  });

  testWidgets('Schedule publishes only the settled non-empty Search query', (
    tester,
  ) async {
    final repository = _RecordingScheduleRepository();
    await _pumpWorkspace(tester, width: 1100, repository: repository);
    await _openSearch(tester);
    repository.queries.clear();
    final field = _searchTextField();

    await tester.enterText(field, 'p');
    await tester.pump(const Duration(milliseconds: 25));
    await tester.enterText(field, 'pl');
    await tester.pump(const Duration(milliseconds: 25));
    await tester.enterText(field, 'pla');
    await tester.pump(const Duration(milliseconds: 25));
    await tester.enterText(field, 'plan');
    expect(repository.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 149));
    expect(repository.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.queries, ['plan']);
  });

  testWidgets('Schedule applies Clear immediately and drops pending text', (
    tester,
  ) async {
    final repository = _RecordingScheduleRepository();
    await _pumpWorkspace(tester, width: 1100, repository: repository);
    await _openSearch(tester);
    repository.queries.clear();

    await tester.enterText(_searchTextField(), 'planning');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(BusyMaxLinuxHeaderSearchField.clearKey));
    await tester.pump();
    expect(tester.widget<TextField>(_searchTextField()).controller!.text, '');
    expect(repository.queries, isNotEmpty);
    expect(repository.queries.last, '');
    expect(repository.queries, isNot(contains('planning')));
    await tester.pump(const Duration(milliseconds: 151));
    expect(repository.queries, isNot(contains('planning')));
  });

  testWidgets('Search inputs and controls never initiate a titlebar drag', (
    tester,
  ) async {
    await _pumpWorkspace(tester, width: 1100);
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    await _openSearch(tester);

    final field = _searchTextField();
    await tester.enterText(field, 'selection survives');
    final fieldDrag = await tester.startGesture(
      tester.getCenter(field),
      kind: PointerDeviceKind.mouse,
    );
    await fieldDrag.moveBy(const Offset(24, 0));
    await tester.pump();
    await fieldDrag.up();
    expect(_dragCalls(windowCalls), 0);

    await tester.tap(field);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(field);
    await tester.pump();
    expect(_dragCalls(windowCalls), 0);

    await _dragControl(tester, 'schedule-search-filter-button');
    await _dragControl(tester, 'schedule-search-button');
    await _dragControl(tester, 'busymax-main-menu-button');
    expect(_dragCalls(windowCalls), 0);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(_dragCalls(windowCalls), 0);
    Navigator.of(tester.element(find.byType(BusyMaxDialogShell))).pop();
    await tester.pumpAndSettle();

    final clearIcon = find.byWidgetPredicate(
      (widget) =>
          widget is BusyMaxGtkHeaderIcon &&
          widget.icon == BusyMaxLinuxHeaderIcon.searchClear,
    );
    expect(tester.getSize(clearIcon), const Size.square(16));
    expect(
      find.ancestor(
        of: clearIcon,
        matching: find.byType(BusyMaxHeaderIconButton),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(of: clearIcon, matching: find.byType(IconButton)),
      findsNothing,
    );
    await _dragControl(
      tester,
      BusyMaxLinuxHeaderSearchField.secondaryIconKey.value,
    );
    expect(_dragCalls(windowCalls), 0);
    await tester.tap(find.byKey(BusyMaxLinuxHeaderSearchField.clearKey));
    await tester.pump();
    expect(_dragCalls(windowCalls), 0);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    final searchIcon = find.descendant(
      of: find.byType(BusyMaxLinuxHeaderSearchField),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is BusyMaxGtkHeaderIcon &&
            widget.icon == BusyMaxLinuxHeaderIcon.searchEntryFind,
      ),
    );
    expect(searchIcon, findsOneWidget);
    expect(clearIcon, findsNothing);
    await _dragControl(
      tester,
      BusyMaxLinuxHeaderSearchField.primaryIconKey.value,
    );
    expect(_dragCalls(windowCalls), 0);

    await tester.tap(find.byTooltip('Main Menu'));
    await tester.pump();
    expect(_dragCalls(windowCalls), 0);

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    expect(_dragCalls(windowCalls), 0);
    expect(
      find.byType(BusyMaxLinuxHeaderSearchField).hitTestable(),
      findsNothing,
    );
  });

  testWidgets('search text selection and focus survive an unrelated rebuild', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_WorkspaceHarnessState>();
    await _pumpWorkspace(tester, width: 1100, harnessKey: harnessKey);
    await _openSearch(tester);

    final field = _searchTextField();
    await tester.enterText(field, 'planning review');
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    final controller = editable.controller;
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
    editable.focusNode.requestFocus();
    await tester.pump();
    expect(editable.focusNode.hasFocus, isTrue);

    harnessKey.currentState!.rebuildParent();
    await tester.pump();

    final rebuilt = tester.widget<EditableText>(
      find.descendant(
        of: _searchTextField(),
        matching: find.byType(EditableText),
      ),
    );
    expect(rebuilt.controller, same(controller));
    expect(rebuilt.controller.text, 'planning review');
    expect(
      rebuilt.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 8),
    );
    expect(rebuilt.focusNode, same(editable.focusNode));
    expect(rebuilt.focusNode.hasFocus, isTrue);
    expect(_dragCalls(windowCalls), 0);

    rebuilt.controller.selection = const TextSelection(
      baseOffset: 3,
      extentOffset: 6,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
      rebuilt.controller.selection,
      TextSelection(
        baseOffset: 0,
        extentOffset: rebuilt.controller.text.length,
      ),
    );
    expect(
      find.byType(BusyMaxLinuxHeaderSearchField).hitTestable(),
      findsOneWidget,
    );
  });
}

Future<void> _dragControl(WidgetTester tester, String key) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byKey(ValueKey(key))),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(const Offset(30, 0));
  await tester.pump();
  await gesture.up();
}

Finder _searchTextField() => find.descendant(
  of: find.byType(BusyMaxLinuxHeaderSearchField),
  matching: find.byType(TextField),
);

Finder _scheduleCenterPresentation() => find.descendant(
  of: find.byType(ScheduleToolbar),
  matching: find.byType(BusyMaxBinaryPresentation),
);

Finder _scheduleCenterTitle() => find.descendant(
  of: _scheduleCenterPresentation(),
  matching: find.byType(Text),
);

void _expectSearchFillsPhysicalInterval(
  WidgetTester tester,
  TextDirection direction, {
  double tolerance = .01,
}) {
  final field = tester.getRect(find.byType(BusyMaxLinuxHeaderSearchField));
  final leading = tester.getRect(
    find.byKey(const ValueKey('schedule-header-leading-actions')),
  );
  final trailing = tester.getRect(
    find.byKey(const ValueKey('schedule-header-trailing-actions')),
  );
  final physicalLeftEdge = direction == TextDirection.ltr
      ? leading.right
      : trailing.right;
  final physicalRightEdge = direction == TextDirection.ltr
      ? trailing.left
      : leading.left;

  expect(
    field.left,
    closeTo(physicalLeftEdge + BusyMaxSpacing.headerInset, tolerance),
  );
  expect(
    field.right,
    closeTo(physicalRightEdge - BusyMaxSpacing.headerInset, tolerance),
  );
  expect(
    field.width,
    closeTo(
      physicalRightEdge - physicalLeftEdge - 2 * BusyMaxSpacing.headerInset,
      tolerance,
    ),
  );
  expect(field.overlaps(leading), isFalse);
  expect(field.overlaps(trailing), isFalse);
}

void _expectTransitionGeometry(
  WidgetTester tester,
  Rect expectedSlot, {
  bool expectSearchHitTestable = true,
}) {
  _expectRectCloseTo(
    tester.getRect(_scheduleCenterPresentation()),
    expectedSlot,
  );
  final field = find.byType(BusyMaxLinuxHeaderSearchField);
  final fieldRect = tester.getRect(field);
  expect(fieldRect.left, closeTo(expectedSlot.left, .01));
  expect(fieldRect.right, closeTo(expectedSlot.right, .01));
  expect(
    field.hitTestable(),
    expectSearchHitTestable ? findsOneWidget : findsNothing,
  );
  final title = _scheduleCenterTitle();
  if (title.evaluate().isNotEmpty) {
    expect(
      tester.getRect(title).center.dx,
      closeTo(expectedSlot.center.dx, .01),
    );
    expect(tester.getRect(title).left, greaterThan(expectedSlot.left));
  }
}

void _expectRectCloseTo(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, .01));
  expect(actual.top, closeTo(expected.top, .01));
  expect(actual.right, closeTo(expected.right, .01));
  expect(actual.bottom, closeTo(expected.bottom, .01));
}

int _dragCalls(List<MethodCall> calls) =>
    calls.where((call) => call.method == 'drag').length;

Future<void> _openSearch(WidgetTester tester) async {
  await _toggleSearchShortcut(tester);
  await tester.pumpAndSettle();
  expect(
    find.byType(BusyMaxLinuxHeaderSearchField).hitTestable(),
    findsOneWidget,
  );
}

Future<void> _toggleSearchShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required double width,
  GlobalKey<_WorkspaceHarnessState>? harnessKey,
  TextDirection direction = TextDirection.ltr,
  ScheduleRepository? repository,
  GtkWindowPreferences preferences = _testWindowPreferences,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 720);
  addTearDown(tester.view.reset);
  final database = AppDatabase.memoryForTests();
  addTearDown(database.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        accountsStreamProvider.overrideWith(
          (ref) => Stream.value(const <AccountEntity>[]),
        ),
        localTimeZoneProvider.overrideWithValue('UTC'),
        localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        if (repository != null)
          scheduleRepositoryProvider.overrideWithValue(repository),
        gtkWindowPreferencesProvider.overrideWith(
          (ref) => Stream.value(preferences),
        ),
      ],
      child: localizedTestApp(
        child: Directionality(
          textDirection: direction,
          child: _WorkspaceHarness(key: harnessKey),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpToolbarHarness(
  WidgetTester tester, {
  required GlobalKey<_ToolbarHarnessState> harnessKey,
  required double width,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 240);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    localizedTestApp(
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: _ToolbarHarness(key: harnessKey),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _testWindowPreferences = GtkWindowPreferences(
  decorationLayout: GtkDecorationLayout(left: [], right: []),
  doubleClick: GtkTitlebarAction.toggleMaximize,
  middleClick: GtkTitlebarAction.none,
  rightClick: GtkTitlebarAction.menu,
);

const _leftSystemControls = GtkWindowPreferences(
  decorationLayout: GtkDecorationLayout(
    left: [
      GtkWindowDecorationElement.minimize,
      GtkWindowDecorationElement.maximize,
      GtkWindowDecorationElement.close,
    ],
    right: [],
  ),
  doubleClick: GtkTitlebarAction.toggleMaximize,
  middleClick: GtkTitlebarAction.none,
  rightClick: GtkTitlebarAction.menu,
);

const _rightSystemControls = GtkWindowPreferences(
  decorationLayout: GtkDecorationLayout(
    left: [],
    right: [
      GtkWindowDecorationElement.minimize,
      GtkWindowDecorationElement.maximize,
      GtkWindowDecorationElement.close,
    ],
  ),
  doubleClick: GtkTitlebarAction.toggleMaximize,
  middleClick: GtkTitlebarAction.none,
  rightClick: GtkTitlebarAction.menu,
);

class _SystemControlCase {
  const _SystemControlCase(this.label, this.preferences, this.onLeft);

  final String label;
  final GtkWindowPreferences preferences;
  final bool onLeft;
}

class _WorkspaceHarness extends StatefulWidget {
  const _WorkspaceHarness({super.key});

  @override
  State<_WorkspaceHarness> createState() => _WorkspaceHarnessState();
}

class _WorkspaceHarnessState extends State<_WorkspaceHarness> {
  var rebuilds = 0;

  void rebuildParent() => setState(() => rebuilds += 1);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: rebuilds.isEven
            ? Colors.transparent
            : Colors.black.withValues(alpha: .01),
      ),
      child: LinuxWindowHost(child: const ScheduleWorkspace()),
    );
  }
}

class _ToolbarHarness extends StatefulWidget {
  const _ToolbarHarness({super.key});

  @override
  State<_ToolbarHarness> createState() => _ToolbarHarnessState();
}

class _ToolbarHarnessState extends State<_ToolbarHarness> {
  final searchController = TextEditingController();
  var searchActive = false;

  void setSearchActive(bool value) => setState(() => searchActive = value);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScheduleToolbar(
      mode: ScheduleViewMode.week,
      range: ScheduleRange.week(
        DateTime(2026, 7, 22),
        firstWeekday: DateTime.monday,
      ),
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
      canShowSidebar: true,
      sidebarVisible: true,
      onToggleSidebar: () {},
      onSearch: () => setSearchActive(!searchActive),
      searchActive: searchActive,
      searchController: searchController,
      onSearchChanged: (_) {},
      onClearSearch: searchController.clear,
      onMenuSelected: (_) {},
    );
  }
}

class _MemorySettingsStore implements LocalSettingsStore {
  @override
  Future<Map<String, Object?>> load() async => <String, Object?>{};

  @override
  Future<void> save(Map<String, Object?> json) async {}
}

class _RecordingScheduleRepository implements ScheduleRepository {
  final queries = <String>[];

  @override
  Future<List<ScheduleItem>> listItems({
    required ScheduleRange range,
    ScheduleFilters filters = const ScheduleFilters(),
  }) async {
    queries.add(filters.query);
    return const [];
  }

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
