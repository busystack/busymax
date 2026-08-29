import 'dart:async';
import 'dart:ui' as ui;

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    final boundaryKey = GlobalKey();
    final baseTheme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: YaruColors.orange,
    );
    const inheritedHover = Color(0x1A2A7FFF);
    final theme = baseTheme.copyWith(hoverColor: inheritedHover);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw MissingPluginException(),
        );

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: localizedTestApp(
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
                      shortcut: 'Ctrl+R',
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
      ),
    );

    final triggerFinder = find.ancestor(
      of: find.byTooltip('Options'),
      matching: find.byType(YaruIconButton),
    );
    var trigger = tester.widget<YaruIconButton>(triggerFinder);
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    expect(Theme.of(tester.element(triggerFinder)).hoverColor, inheritedHover);
    expect(trigger.isSelected, isFalse);
    expect(trigger.style, isNull);
    final yaruStyle = trigger.defaultStyleOf(tester.element(triggerFinder));
    expect(yaruStyle.backgroundColor?.resolve({}), isNull);
    expect(yaruStyle.overlayColor?.resolve({WidgetState.hovered}), isNotNull);
    expect(yaruStyle.overlayColor?.resolve({WidgetState.pressed}), isNotNull);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Refresh calendar'), findsOneWidget);
    expect(find.text('Ctrl+R'), findsOneWidget);
    expect(find.text('Open in provider'), findsOneWidget);
    trigger = tester.widget<YaruIconButton>(triggerFinder);
    expect(Theme.of(tester.element(triggerFinder)).hoverColor, inheritedHover);
    expect(trigger.isSelected, isTrue);
    expect(
      trigger
          .defaultStyleOf(tester.element(triggerFinder))
          .backgroundColor
          ?.resolve({WidgetState.selected}),
      isNotNull,
    );
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
    final firstFallbackItem = find
        .ancestor(
          of: find.text('Refresh calendar'),
          matching: find.byWidgetPredicate(
            (widget) => widget is PopupMenuItem<int>,
          ),
        )
        .first;
    final firstFallbackInkWell = find.descendant(
      of: firstFallbackItem,
      matching: find.byType(InkWell),
    );
    expect(firstFallbackInkWell, findsOneWidget);
    expect(
      Theme.of(tester.element(firstFallbackInkWell)).hoverColor,
      colors.controlHover,
    );
    expect(colors.controlHover, isNot(inheritedHover));

    final firstItemRect = tester.getRect(firstFallbackItem);
    final hoverProbe = Offset(
      firstItemRect.right - 12,
      firstItemRect.center.dy,
    );
    final idlePixel = await _capturePixel(tester, boundaryKey, hoverProbe);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(firstFallbackItem));
    await tester.pumpAndSettle();
    expect(firstFallbackInkWell, findsOneWidget);
    final hoveredPixel = await _capturePixel(tester, boundaryKey, hoverProbe);
    expect(hoveredPixel, isNot(idlePixel));
    expect(
      hoveredPixel,
      _colorCloseTo(Color.alphaBlend(colors.controlHover, colors.popover)),
    );
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    final restoredPixel = await _capturePixel(tester, boundaryKey, hoverProbe);
    expect(restoredPixel, idlePixel);

    controller.close();
    await tester.pumpAndSettle();

    trigger = tester.widget<YaruIconButton>(triggerFinder);
    expect(trigger.isSelected, isFalse);
    expect(Theme.of(tester.element(triggerFinder)).hoverColor, inheritedHover);
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

  testWidgets('menu button can keep a neutral trigger while open', (
    tester,
  ) async {
    final controller = BusyMaxMenuController();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw MissingPluginException(),
        );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: BusyMaxMenuButton<String>(
            tooltip: 'Options',
            controller: controller,
            highlightWhenOpen: false,
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
    await tester.pumpAndSettle();

    final trigger = tester.widget<YaruIconButton>(
      find.ancestor(
        of: find.byTooltip('Options'),
        matching: find.byType(YaruIconButton),
      ),
    );
    expect(controller.isOpen, isTrue);
    expect(trigger.isSelected, isFalse);

    controller.close();
    await tester.pumpAndSettle();
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
                  icon: YaruIcons.refresh,
                  role: BusyMaxMenuEntryRole.radio,
                  selected: true,
                  shortcut: 'Ctrl+R',
                ),
                BusyMaxMenuEntry(
                  value: 'open',
                  label: 'Open in provider',
                  role: BusyMaxMenuEntryRole.radio,
                ),
              ],
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    final triggerRect = tester.getRect(find.byType(YaruIconButton));
    await tester.tap(find.byTooltip('Options'));
    await tester.pump();

    expect(selected, 'open');
    expect(find.text('Refresh calendar'), findsNothing);
    expect(find.text('Open in provider'), findsNothing);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'show');
    final arguments = calls.single.arguments! as Map<Object?, Object?>;
    final rawAnchor = arguments['anchor']! as Map<Object?, Object?>;
    final anchor = Rect.fromLTWH(
      (rawAnchor['x']! as num).toDouble(),
      (rawAnchor['y']! as num).toDouble(),
      (rawAnchor['width']! as num).toDouble(),
      (rawAnchor['height']! as num).toDouble(),
    );
    expect(anchor, triggerRect);
    expect(arguments['entries'], [
      {
        'label': 'Refresh calendar',
        'icon': 'view-refresh-symbolic',
        'enabled': true,
        'role': 'radio',
        'selected': true,
        'shortcut': 'Ctrl+R',
      },
      {
        'label': 'Open in provider',
        'enabled': true,
        'role': 'radio',
        'selected': false,
      },
    ]);
  });

  testWidgets('toggle entries remain valid beside disabled calendar commands', (
    tester,
  ) async {
    MethodCall? nativeCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCall = call;
          return null;
        });

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: BusyMaxMenuButton<String>(
            tooltip: 'Options',
            nativeMenuService: const NativeMenuService(channel: channel),
            entries: const [
              BusyMaxMenuEntry(value: 'refresh', label: 'Refresh calendar'),
              BusyMaxMenuEntry(
                value: 'reminders',
                label: 'Event reminders',
                role: BusyMaxMenuEntryRole.toggle,
                selected: true,
              ),
              BusyMaxMenuEntry(
                value: 'delete',
                label: 'Delete',
                enabled: false,
              ),
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final entries =
        (nativeCall!.arguments as Map<Object?, Object?>)['entries']!
            as List<Object?>;
    expect(entries[1], {
      'label': 'Event reminders',
      'enabled': true,
      'role': 'toggle',
      'selected': true,
    });
    expect(entries[2], {
      'label': 'Delete',
      'enabled': false,
      'role': 'command',
      'selected': false,
    });
  });

  testWidgets('fallback renders toggle state independently of commands', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw MissingPluginException(),
        );

    await tester.pumpWidget(
      localizedTestApp(
        child: Scaffold(
          body: BusyMaxMenuButton<String>(
            tooltip: 'Options',
            nativeMenuService: const NativeMenuService(channel: channel),
            entries: const [
              BusyMaxMenuEntry(value: 'refresh', label: 'Refresh calendar'),
              BusyMaxMenuEntry(
                value: 'reminders',
                label: 'Event reminders',
                role: BusyMaxMenuEntryRole.toggle,
                selected: true,
              ),
              BusyMaxMenuEntry(
                value: 'delete',
                label: 'Delete',
                enabled: false,
              ),
            ],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(YaruRadio<int>), findsNothing);
    expect(find.byType(YaruCheckbox), findsOneWidget);
    expect(
      tester.widget<YaruCheckbox>(find.byType(YaruCheckbox)).value,
      isTrue,
    );
    expect(find.text('Delete'), findsOneWidget);
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

  testWidgets('a dismissed native session cannot keep the trigger stuck open', (
    tester,
  ) async {
    final nativeSelections = <Completer<int?>>[];
    final calls = <MethodCall>[];
    final selections = <String>[];
    final controller = BusyMaxMenuController();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'show') {
            final selection = Completer<int?>();
            nativeSelections.add(selection);
            return selection.future;
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
            onSelected: selections.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options'));
    await tester.pump();
    expect(controller.isOpen, isTrue);
    expect(nativeSelections, hasLength(1));

    controller.close();
    expect(controller.isOpen, isFalse);
    await tester.pump();

    await tester.tap(find.byTooltip('Options'));
    await tester.pump();
    expect(controller.isOpen, isTrue);
    expect(nativeSelections, hasLength(2));

    // A late result from the dismissed presentation must neither select an
    // entry nor retire the replacement session.
    nativeSelections.first.complete(0);
    await tester.pump();
    expect(selections, isEmpty);
    expect(controller.isOpen, isTrue);

    nativeSelections.last.complete(0);
    await tester.pumpAndSettle();
    expect(selections, ['refresh']);
    expect(controller.isOpen, isFalse);
    expect(calls.where((call) => call.method == 'show'), hasLength(2));
    expect(calls.where((call) => call.method == 'dismiss'), hasLength(1));
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

  testWidgets('keyed menu state follows its owner through a row reorder', (
    tester,
  ) async {
    final nativeSelection = Completer<int?>();
    final selections = <String>[];
    late StateSetter rebuild;
    var reversed = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'show') {
            return nativeSelection.future;
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
              final owners = reversed
                  ? const ['second', 'first']
                  : const ['first', 'second'];
              return Column(
                children: [
                  for (final owner in owners)
                    BusyMaxMenuButton<String>(
                      key: ValueKey(owner),
                      tooltip: 'Options $owner',
                      nativeMenuService: const NativeMenuService(
                        channel: channel,
                      ),
                      entries: [BusyMaxMenuEntry(value: owner, label: owner)],
                      onSelected: selections.add,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );

    YaruIconButton triggerFor(String owner) {
      return tester.widget<YaruIconButton>(
        find.ancestor(
          of: find.byTooltip('Options $owner'),
          matching: find.byType(YaruIconButton),
        ),
      );
    }

    await tester.tap(find.byTooltip('Options first'));
    await tester.pump();
    expect(triggerFor('first').isSelected, isTrue);
    expect(triggerFor('second').isSelected, isFalse);

    rebuild(() => reversed = true);
    await tester.pump();
    expect(triggerFor('first').isSelected, isTrue);
    expect(triggerFor('second').isSelected, isFalse);

    nativeSelection.complete(0);
    await tester.pumpAndSettle();
    expect(selections, ['first']);
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

Future<Color> _capturePixel(
  WidgetTester tester,
  GlobalKey boundaryKey,
  Offset globalPosition,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final localPosition = boundary.globalToLocal(globalPosition);
  final image = (await tester.binding.runAsync<ui.Image>(
    () => boundary.toImage(pixelRatio: 1),
  ))!;
  try {
    final data = (await tester.binding.runAsync<ByteData?>(
      () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
    ))!;
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final x = localPosition.dx.floor().clamp(0, image.width - 1).toInt();
    final y = localPosition.dy.floor().clamp(0, image.height - 1).toInt();
    final offset = (y * image.width + x) * 4;
    return Color.fromARGB(
      bytes[offset + 3],
      bytes[offset],
      bytes[offset + 1],
      bytes[offset + 2],
    );
  } finally {
    image.dispose();
  }
}

Matcher _colorCloseTo(Color expected) => predicate<Color>(
  (actual) =>
      (actual.r - expected.r).abs() <= 1 / 255 &&
      (actual.g - expected.g).abs() <= 1 / 255 &&
      (actual.b - expected.b).abs() <= 1 / 255 &&
      (actual.a - expected.a).abs() <= 1 / 255,
  'a color within one 8-bit channel step of $expected',
);
