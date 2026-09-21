import 'dart:async';

import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/linux/linux_window_host.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/accounts/data/accounts_repository.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_sidebar.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/platform/gtk_window_preferences_service.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

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

  testWidgets('search drag area exists with the sidebar expanded', (
    tester,
  ) async {
    await _pumpWorkspace(tester, width: 1100);
    await _openSearch(tester);

    expect(
      tester
          .getSize(find.byKey(const ValueKey('linux-sidebar-viewport')))
          .width,
      BusyMaxSizes.sidebarWidth,
    );
    _expectSearchDragArea(tester);
  });

  testWidgets('search drag area exists with the sidebar collapsed', (
    tester,
  ) async {
    await _pumpWorkspace(tester, width: 1100);
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    await _openSearch(tester);

    expect(find.byType(ScheduleSidebar).hitTestable(), findsNothing);
    _expectSearchDragArea(tester);
  });

  testWidgets('narrow search retains its own drag area without a sidebar', (
    tester,
  ) async {
    await _pumpWorkspace(tester, width: 650);
    await _openSearch(tester);

    expect(find.byType(ScheduleSidebar).hitTestable(), findsNothing);
    _expectSearchDragArea(tester);
  });

  testWidgets('only the explicit empty search region drags the window', (
    tester,
  ) async {
    await _pumpWorkspace(tester, width: 1100);
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    await _openSearch(tester);
    final dragArea = find.byKey(_searchDragAreaKey);

    final titlebarDrag = await tester.startGesture(
      tester.getCenter(dragArea),
      kind: PointerDeviceKind.mouse,
    );
    await titlebarDrag.moveBy(const Offset(18, 0));
    await tester.pump();
    await titlebarDrag.up();
    expect(_dragCalls(windowCalls), 1);

    windowCalls.clear();
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

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(_dragCalls(windowCalls), 0);
    Navigator.of(tester.element(find.byType(BusyMaxDialogShell))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(YaruIcons.edit_clear));
    await tester.pump();
    expect(_dragCalls(windowCalls), 0);

    await tester.tap(find.byTooltip('Main Menu'));
    await tester.pump();
    expect(_dragCalls(windowCalls), 0);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(_dragCalls(windowCalls), 0);
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
  });
}

const _searchDragAreaKey = ValueKey('schedule-search-titlebar-drag-area');

void _expectSearchDragArea(WidgetTester tester) {
  final area = find.byKey(_searchDragAreaKey);
  expect(area, findsOneWidget);
  expect(tester.getSize(area).width, BusyMaxSizes.headerIconButton);
  expect(
    find.descendant(of: area, matching: find.byType(TextField)),
    findsNothing,
  );
  expect(find.descendant(of: area, matching: find.byType(Focus)), findsNothing);
}

Finder _searchTextField() => find.descendant(
  of: find.byType(BusyMaxSearchField),
  matching: find.byType(TextField),
);

int _dragCalls(List<MethodCall> calls) =>
    calls.where((call) => call.method == 'drag').length;

Future<void> _openSearch(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  expect(find.byType(BusyMaxSearchField).hitTestable(), findsOneWidget);
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required double width,
  GlobalKey<_WorkspaceHarnessState>? harnessKey,
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
      child: localizedTestApp(child: _WorkspaceHarness(key: harnessKey)),
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
