import 'dart:async';

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../test_localized_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('busymax_test/menu_button');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('menu button uses the centralized themed fallback', (
    tester,
  ) async {
    String? selected;
    final controller = BusyMaxMenuController();
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: YaruColors.orange,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw MissingPluginException(),
        );

    await tester.pumpWidget(
      localizedTestApp(
        child: Theme(
          data: theme,
          child: Scaffold(
            body: Center(
              child: BusyMaxMenuButton<String>(
                tooltip: 'Options',
                controller: controller,
                nativeMenuService: const NativeMenuService(channel: channel),
                onSelected: (value) => selected = value,
                entries: const [
                  BusyMaxMenuEntry(
                    value: 'refresh',
                    label: 'Refresh calendar',
                    icon: YaruIcons.refresh,
                  ),
                  BusyMaxMenuEntry(
                    value: 'open',
                    label: 'Open in provider',
                    icon: Icons.open_in_browser_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh calendar'), findsOneWidget);
    expect(find.text('Open in provider'), findsOneWidget);
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    expect(find.byType(MenuAnchor), findsNothing);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuItem<int>),
      findsNWidgets(2),
    );
    expect(
      tester
          .widgetList<Material>(find.byType(Material))
          .where((material) => material.color == colors.popover),
      isNotEmpty,
    );

    controller.close();
    await tester.pumpAndSettle();

    expect(find.text('Refresh calendar'), findsNothing);
    expect(selected, isNull);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh calendar'), findsOneWidget);
    expect(find.text('Open in provider'), findsOneWidget);

    await tester.tap(find.text('Open in provider'));
    await tester.pumpAndSettle();

    expect(selected, 'open');
    expect(find.text('Open in provider'), findsNothing);
  });

  testWidgets('menu button maps a native selected index to its domain value', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    String? selected;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'show' => 1,
            'dismiss' => true,
            _ => throw MissingPluginException(),
          };
        });

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Center(
            child: BusyMaxMenuButton<String>(
              tooltip: 'Options',
              nativeMenuService: const NativeMenuService(channel: channel),
              entries: const [
                BusyMaxMenuEntry(
                  value: 'refresh',
                  label: 'Refresh calendar',
                  selected: true,
                ),
                BusyMaxMenuEntry(value: 'open', label: 'Open in provider'),
              ],
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pump();

    expect(selected, 'open');
    expect(find.text('Refresh calendar'), findsNothing);
    expect(find.text('Open in provider'), findsNothing);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'show');
    final arguments = calls.single.arguments! as Map<Object?, Object?>;
    expect(arguments['anchor'], isA<Map<Object?, Object?>>());
    expect(arguments['entries'], [
      {'label': 'Refresh calendar', 'enabled': true, 'selected': true},
      {'label': 'Open in provider', 'enabled': true, 'selected': false},
    ]);
  });

  testWidgets('controller dismissal carries the owned native session', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    final nativeSelection = Completer<int?>();
    final controller = BusyMaxMenuController();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'show') {
            return await nativeSelection.future;
          }
          if (call.method == 'dismiss') {
            return true;
          }
          throw MissingPluginException();
        });

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: BusyMaxMenuButton<String>(
            tooltip: 'Options',
            controller: controller,
            nativeMenuService: const NativeMenuService(channel: channel),
            entries: const [
              BusyMaxMenuEntry(value: 'refresh', label: 'Refresh'),
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pump();
    controller.close();
    await tester.pump();

    final showArguments =
        calls.singleWhere((call) => call.method == 'show').arguments!
            as Map<Object?, Object?>;
    final dismissArguments =
        calls.singleWhere((call) => call.method == 'dismiss').arguments!
            as Map<Object?, Object?>;
    expect(dismissArguments['sessionId'], showArguments['sessionId']);

    nativeSelection.complete();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
  });

  testWidgets('an open menu keeps its entry and callback snapshot', (
    tester,
  ) async {
    final nativeSelection = Completer<int?>();
    final originalSelections = <String>[];
    final replacementSelections = <String>[];
    late StateSetter rebuild;
    var replacement = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'show') {
            return await nativeSelection.future;
          }
          if (call.method == 'dismiss') {
            return true;
          }
          throw MissingPluginException();
        });

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return BusyMaxMenuButton<String>(
                tooltip: 'Options',
                nativeMenuService: const NativeMenuService(channel: channel),
                entries: replacement
                    ? const [
                        BusyMaxMenuEntry(value: 'second', label: 'Second'),
                        BusyMaxMenuEntry(value: 'first', label: 'First'),
                      ]
                    : const [
                        BusyMaxMenuEntry(value: 'first', label: 'First'),
                        BusyMaxMenuEntry(value: 'second', label: 'Second'),
                      ],
                onSelected: replacement
                    ? replacementSelections.add
                    : originalSelections.add,
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pump();
    rebuild(() => replacement = true);
    await tester.pump();
    nativeSelection.complete(1);
    await tester.pumpAndSettle();

    expect(originalSelections, ['second']);
    expect(replacementSelections, isEmpty);
  });

  testWidgets('fallback dismissal removes its menu, not a newer route', (
    tester,
  ) async {
    late BuildContext hostContext;
    final controller = BusyMaxMenuController();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw MissingPluginException(),
        );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return BusyMaxMenuButton<String>(
                tooltip: 'Options',
                controller: controller,
                nativeMenuService: const NativeMenuService(channel: channel),
                entries: const [
                  BusyMaxMenuEntry(value: 'refresh', label: 'Refresh'),
                ],
                onSelected: (_) {},
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: hostContext,
        builder: (_) => const AlertDialog(title: Text('Unrelated dialog')),
      ),
    );
    await tester.pumpAndSettle();

    controller.close();
    await tester.pumpAndSettle();

    expect(find.text('Unrelated dialog'), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);

    Navigator.of(hostContext).pop();
    await tester.pumpAndSettle();
  });
}
