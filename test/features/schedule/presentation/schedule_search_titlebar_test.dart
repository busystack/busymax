import 'dart:async';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/linux/linux_header_style.dart';
import 'package:busymax/src/app/linux/linux_window_host.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_toolbar.dart';
import 'package:busymax/src/platform/gtk_window_preferences_service.dart';
import 'package:busymax/src/platform/gtk_header_icon_service.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
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
      final headerRect = tester.getRect(find.byType(ScheduleToolbar));
      final fieldRect = tester.getRect(
        find.byType(BusyMaxLinuxHeaderSearchField),
      );
      expect(headerRect.height, BusyMaxSizes.toolbarHeight);
      expect(fieldRect.height, BusyMaxLinuxHeaderStyle.searchEntryHeight);
      expect(fieldRect.center.dx, closeTo(headerRect.center.dx, .01));
      expect(fieldRect.center.dy, closeTo(headerRect.center.dy, .5));
      expect(fieldRect.width, lessThan(headerRect.width));

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

  testWidgets('bounded Search geometry remains centered in LTR and RTL', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await _pumpWorkspace(tester, width: 650, direction: direction);
      await _openSearch(tester);

      final headerRect = tester.getRect(find.byType(ScheduleToolbar));
      final fieldRect = tester.getRect(
        find.byType(BusyMaxLinuxHeaderSearchField),
      );
      expect(headerRect.height, BusyMaxSizes.toolbarHeight);
      expect(fieldRect.height, BusyMaxLinuxHeaderStyle.searchEntryHeight);
      expect(fieldRect.center.dx, closeTo(headerRect.center.dx, .01));
      expect(fieldRect.center.dy, closeTo(headerRect.center.dy, .5));
      expect(fieldRect.width, lessThan(headerRect.width));

      const keys = [
        ValueKey('schedule-search-filter-button'),
        ValueKey('schedule-search-button'),
        ValueKey('busymax-main-menu-button'),
      ];
      final controlRects = <Rect>[];
      for (final key in keys) {
        expect(
          tester.getSize(find.byKey(key)),
          const Size.square(BusyMaxSizes.headerIconButton),
        );
        final rect = tester.getRect(find.byKey(key));
        expect(fieldRect.overlaps(rect), isFalse);
        controlRects.add(rect);
      }
      controlRects.sort((a, b) => a.left.compareTo(b.left));
      for (var index = 1; index < controlRects.length; index++) {
        expect(
          controlRects[index].left - controlRects[index - 1].right,
          BusyMaxSpacing.headerInset,
        );
      }
    }
  });

  testWidgets('Search inputs do not steal the empty titlebar drag behavior', (
    tester,
  ) async {
    await _pumpWorkspace(tester, width: 1100);
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    await _openSearch(tester);

    final field = _searchTextField();
    final fieldRect = tester.getRect(field);
    final sidebarRect = tester.getRect(
      find.byKey(const ValueKey('schedule-sidebar-button')),
    );
    final emptyTitlebarPoint = Offset(
      (sidebarRect.right + fieldRect.left) / 2,
      fieldRect.center.dy,
    );

    final titlebarDrag = await tester.startGesture(
      emptyTitlebarPoint,
      kind: PointerDeviceKind.mouse,
    );
    await titlebarDrag.moveBy(const Offset(18, 0));
    await tester.pump();
    await titlebarDrag.up();
    expect(_dragCalls(windowCalls), 1);

    windowCalls.clear();
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
    await tester.tap(find.byKey(BusyMaxLinuxHeaderSearchField.clearKey));
    await tester.pump();
    expect(_dragCalls(windowCalls), 0);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);

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

int _dragCalls(List<MethodCall> calls) =>
    calls.where((call) => call.method == 'drag').length;

Future<void> _openSearch(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  expect(
    find.byType(BusyMaxLinuxHeaderSearchField).hitTestable(),
    findsOneWidget,
  );
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required double width,
  GlobalKey<_WorkspaceHarnessState>? harnessKey,
  TextDirection direction = TextDirection.ltr,
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
        gtkWindowPreferencesProvider.overrideWith(
          (ref) => Stream.value(_testWindowPreferences),
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

const _testWindowPreferences = GtkWindowPreferences(
  decorationLayout: GtkDecorationLayout(left: [], right: []),
  doubleClick: GtkTitlebarAction.toggleMaximize,
  middleClick: GtkTitlebarAction.none,
  rightClick: GtkTitlebarAction.menu,
);

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

class _MemorySettingsStore implements LocalSettingsStore {
  @override
  Future<Map<String, Object?>> load() async => <String, Object?>{};

  @override
  Future<void> save(Map<String, Object?> json) async {}
}
