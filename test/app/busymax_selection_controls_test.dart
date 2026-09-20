import 'dart:ui' as ui;

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_task_chip.dart';
import 'package:busymax/src/providers/busy_provider.dart';
import 'package:busymax/src/schedule/schedule_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../test_localized_app.dart';

const _accent = Color(0xFF6D4AFF);
const _alternateAccent = Color(0xFFE95420);
const _captureBackground = Color(0xFF26313C);
const _controlKey = ValueKey('selection-control');

void main() {
  test('Linux themes suppress only the Yaru state indicators', () {
    final cases = <({ThemeData base, ThemeData theme, String name})>[
      (
        name: 'light',
        base: createYaruLightTheme(primaryColor: _accent),
        theme: _theme(Brightness.light),
      ),
      (
        name: 'dark',
        base: createYaruDarkTheme(primaryColor: _accent),
        theme: _theme(Brightness.dark),
      ),
      (
        name: 'high contrast',
        base: createYaruDarkTheme(primaryColor: _accent, highContrast: true),
        theme: _theme(Brightness.dark, highContrast: true),
      ),
    ];
    const stateSets = <Set<WidgetState>>[
      {},
      {WidgetState.hovered},
      {WidgetState.focused},
      {WidgetState.hovered, WidgetState.focused},
      {WidgetState.pressed},
      {WidgetState.selected},
      {WidgetState.disabled},
      {WidgetState.selected, WidgetState.disabled},
    ];

    for (final testCase in cases) {
      final theme = testCase.theme;
      final radio = theme.extension<YaruRadioThemeData>();
      final checkbox = theme.extension<YaruCheckboxThemeData>();
      final yaruSwitch = theme.extension<YaruSwitchThemeData>();

      expect(radio, isNotNull, reason: testCase.name);
      expect(checkbox, isNotNull, reason: testCase.name);
      expect(yaruSwitch, isNotNull, reason: testCase.name);
      expect(
        theme.extensions.values.whereType<YaruRadioThemeData>(),
        hasLength(1),
      );
      expect(
        theme.extensions.values.whereType<YaruCheckboxThemeData>(),
        hasLength(1),
      );
      expect(
        theme.extensions.values.whereType<YaruSwitchThemeData>(),
        hasLength(1),
      );

      for (final states in stateSets) {
        expect(
          radio!.indicatorColor!.resolve(states),
          Colors.transparent,
          reason: '${testCase.name} radio $states',
        );
        expect(
          checkbox!.indicatorColor!.resolve(states),
          Colors.transparent,
          reason: '${testCase.name} checkbox $states',
        );
        expect(
          yaruSwitch!.indicatorColor!.resolve(states),
          Colors.transparent,
          reason: '${testCase.name} switch $states',
        );
      }

      _expectRadioConfigurationPreserved(
        testCase.base.extension<YaruRadioThemeData>(),
        radio!,
      );
      _expectCheckboxConfigurationPreserved(
        testCase.base.extension<YaruCheckboxThemeData>(),
        checkbox!,
      );
      _expectSwitchConfigurationPreserved(
        testCase.base.extension<YaruSwitchThemeData>(),
        yaruSwitch!,
      );

      expect(theme.extension<BusyMaxSurfaceColors>(), isNotNull);
      for (final extension in testCase.base.extensions.values) {
        if (extension is YaruRadioThemeData ||
            extension is YaruCheckboxThemeData ||
            extension is YaruSwitchThemeData) {
          continue;
        }
        expect(
          theme.extensions.values.any(
            (candidate) => candidate.runtimeType == extension.runtimeType,
          ),
          isTrue,
          reason: '${testCase.name} should retain ${extension.runtimeType}',
        );
      }

      expect(
        theme.checkboxTheme.fillColor!.resolve({WidgetState.selected}),
        isNot(Colors.transparent),
      );
      expect(
        theme.radioTheme.fillColor!.resolve({WidgetState.selected}),
        isNot(Colors.transparent),
      );
      expect(
        theme.switchTheme.trackColor!.resolve({WidgetState.selected}),
        isNot(Colors.transparent),
      );
      expect(
        theme.checkboxTheme.fillColor!.resolve({WidgetState.disabled}),
        isNot(Colors.transparent),
      );
      expect(
        theme.radioTheme.fillColor!.resolve({WidgetState.disabled}),
        isNot(Colors.transparent),
      );
      expect(
        theme.switchTheme.trackColor!.resolve({WidgetState.disabled}),
        isNot(Colors.transparent),
      );
    }
  });

  test('Yaru indicator colors remain transparent while themes interpolate', () {
    final light = _theme(Brightness.light);
    final dark = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: _alternateAccent,
    );
    final highContrast = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: _alternateAccent,
      highContrast: true,
    );

    for (final transition in [
      ThemeData.lerp(light, dark, 0.25),
      ThemeData.lerp(light, dark, 0.5),
      ThemeData.lerp(dark, highContrast, 0.5),
      ThemeData.lerp(dark, highContrast, 0.75),
    ]) {
      for (final indicator in [
        transition.extension<YaruRadioThemeData>()!.indicatorColor!,
        transition.extension<YaruCheckboxThemeData>()!.indicatorColor!,
        transition.extension<YaruSwitchThemeData>()!.indicatorColor!,
      ]) {
        expect(indicator.resolve({WidgetState.hovered}), Colors.transparent);
        expect(indicator.resolve({WidgetState.focused}), Colors.transparent);
        expect(
          indicator.resolve({
            WidgetState.hovered,
            WidgetState.focused,
            WidgetState.selected,
          }),
          Colors.transparent,
        );
      }
    }
  });

  for (final controlCase in _controlCases) {
    testWidgets('${controlCase.name} paints no hover or focused-hover disk', (
      tester,
    ) async {
      final focusNode = FocusNode(debugLabel: controlCase.name);
      addTearDown(focusNode.dispose);
      final boundaryKey = GlobalKey();
      var activationCount = 0;

      await tester.pumpWidget(
        _selectionControlHost(
          boundaryKey: boundaryKey,
          focusNode: focusNode,
          controlCase: controlCase,
          onActivation: () => activationCount += 1,
        ),
      );
      await tester.pumpAndSettle();

      final resting = await _capturePixels(tester, boundaryKey);
      expect(
        _pixelsDifferentFrom(resting, _captureBackground),
        greaterThan(20),
        reason: '${controlCase.name} should retain its visible control paint',
      );

      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byKey(_controlKey)));
      await _pumpStateAnimations(tester);

      final hovered = await _capturePixels(tester, boundaryKey);
      expect(hovered.bytes, orderedEquals(resting.bytes));

      await mouse.down(tester.getCenter(find.byKey(_controlKey)));
      await mouse.up();
      await _pumpStateAnimations(tester);
      final hoveredAfterClick = await _capturePixels(tester, boundaryKey);
      expect(hoveredAfterClick.bytes, orderedEquals(resting.bytes));
      expect(
        activationCount,
        controlCase.enabled ? 1 : 0,
        reason: controlCase.name,
      );

      await mouse.moveTo(const Offset(790, 590));
      await _pumpStateAnimations(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        focusNode.hasPrimaryFocus,
        isFalse,
        reason: 'the traversal sentinel receives focus first',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await _pumpStateAnimations(tester);

      if (controlCase.enabled) {
        expect(focusNode.hasPrimaryFocus, isTrue);
        final focused = await _capturePixels(tester, boundaryKey);
        await mouse.moveTo(tester.getCenter(find.byKey(_controlKey)));
        await _pumpStateAnimations(tester);
        final focusedAndHovered = await _capturePixels(tester, boundaryKey);
        expect(focusedAndHovered.bytes, orderedEquals(focused.bytes));
      } else {
        expect(focusNode.hasFocus, isFalse);
      }
    });
  }

  testWidgets(
    'standalone controls expose outline focus, activation, disabled semantics, '
    'and switch dragging',
    (tester) async {
      final checkboxFocus = FocusNode(debugLabel: 'checkbox');
      final disabledFocus = FocusNode(debugLabel: 'disabled checkbox');
      final switchFocus = FocusNode(debugLabel: 'switch');
      addTearDown(checkboxFocus.dispose);
      addTearDown(disabledFocus.dispose);
      addTearDown(switchFocus.dispose);
      final checkboxBoundary = GlobalKey();
      final switchBoundary = GlobalKey();
      var checkboxValue = false;
      var switchValue = false;
      var checkboxChanges = 0;
      var switchChanges = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(Brightness.light),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      key: checkboxBoundary,
                      child: ColoredBox(
                        color: _captureBackground,
                        child: SizedBox(
                          width: 96,
                          height: 64,
                          child: Center(
                            child: BusyMaxYaruFocusBorder(
                              focusNode: checkboxFocus,
                              builder: (context, focusNode) => YaruCheckbox(
                                key: const ValueKey('standalone-checkbox'),
                                value: checkboxValue,
                                focusNode: focusNode,
                                hasFocusBorder: false,
                                onChanged: (value) {
                                  checkboxChanges += 1;
                                  setState(
                                    () => checkboxValue = value ?? false,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    BusyMaxYaruFocusBorder(
                      focusNode: disabledFocus,
                      builder: (context, focusNode) => YaruCheckbox(
                        key: const ValueKey('disabled-checkbox'),
                        value: false,
                        focusNode: focusNode,
                        hasFocusBorder: false,
                        onChanged: null,
                      ),
                    ),
                    RepaintBoundary(
                      key: switchBoundary,
                      child: ColoredBox(
                        color: _captureBackground,
                        child: SizedBox(
                          width: 112,
                          height: 68,
                          child: Center(
                            child: BusyMaxYaruFocusBorder(
                              focusNode: switchFocus,
                              builder: (context, focusNode) => YaruSwitch(
                                key: const ValueKey('standalone-switch'),
                                value: switchValue,
                                focusNode: focusNode,
                                hasFocusBorder: false,
                                onChanged: (value) {
                                  switchChanges += 1;
                                  setState(() => switchValue = value);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkboxResting = await _capturePixels(tester, checkboxBoundary);
      final switchResting = await _capturePixels(tester, switchBoundary);
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('standalone-checkbox'))),
      );
      await _pumpStateAnimations(tester);
      final checkboxHovered = await _capturePixels(tester, checkboxBoundary);
      expect(checkboxHovered.bytes, orderedEquals(checkboxResting.bytes));
      await mouse.moveTo(const Offset(790, 590));
      await _pumpStateAnimations(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await _pumpStateAnimations(tester);

      expect(checkboxFocus.hasPrimaryFocus, isTrue);
      expect(
        FocusManager.instance.highlightMode,
        FocusHighlightMode.traditional,
      );
      expect(checkboxValue, isFalse);
      expect(checkboxChanges, 0);
      final checkboxFocused = await _capturePixels(tester, checkboxBoundary);
      expect(
        _changedPixelCount(checkboxResting, checkboxFocused),
        greaterThan(0),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(checkboxValue, isTrue);
      expect(checkboxChanges, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await _pumpStateAnimations(tester);
      expect(disabledFocus.hasFocus, isFalse);
      expect(switchFocus.hasPrimaryFocus, isTrue);
      expect(switchValue, isFalse);
      expect(switchChanges, 0);
      final switchFocused = await _capturePixels(tester, switchBoundary);
      expect(_changedPixelCount(switchResting, switchFocused), greaterThan(0));

      final disabledSemantics = tester
          .getSemantics(find.byKey(const ValueKey('disabled-checkbox')))
          .getSemanticsData();
      expect(disabledSemantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(
        disabledSemantics.flagsCollection.isChecked,
        ui.CheckedState.isFalse,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(switchValue, isTrue);
      expect(switchChanges, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _pumpStateAnimations(tester);
      expect(checkboxFocus.hasPrimaryFocus, isTrue);
      expect(checkboxValue, isTrue);
      expect(switchValue, isTrue);
      expect(checkboxChanges, 1);
      expect(switchChanges, 1);

      await tester.drag(
        find.byKey(const ValueKey('standalone-switch')),
        const Offset(-36, 0),
      );
      await tester.pumpAndSettle();
      expect(switchValue, isFalse);
      expect(switchChanges, 2);
    },
  );

  testWidgets(
    'checkbox list tile gives row and control distinct outlines and actions',
    (tester) async {
      final rowFocus = FocusNode(debugLabel: 'checkbox row');
      final controlFocus = FocusNode(debugLabel: 'checkbox control');
      addTearDown(rowFocus.dispose);
      addTearDown(controlFocus.dispose);
      final boundaryKey = GlobalKey();
      var value = false;
      var changes = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  void onChanged(bool? next) {
                    changes += 1;
                    setState(() => value = next ?? false);
                  }

                  return RepaintBoundary(
                    key: boundaryKey,
                    child: ColoredBox(
                      color: _captureBackground,
                      child: SizedBox(
                        width: 360,
                        child: BusyMaxYaruFocusBorder(
                          focusNode: rowFocus,
                          borderStrokeAlign: BorderSide.strokeAlignInside,
                          builder: (context, rowFocusNode) =>
                              YaruCheckboxListTile(
                                value: value,
                                onChanged: onChanged,
                                focusNode: rowFocusNode,
                                hasFocusBorder: false,
                                control: BusyMaxYaruFocusBorder(
                                  focusNode: controlFocus,
                                  builder: (context, controlFocusNode) =>
                                      YaruCheckbox(
                                        key: const ValueKey(
                                          'list-checkbox-control',
                                        ),
                                        value: value,
                                        onChanged: onChanged,
                                        focusNode: controlFocusNode,
                                        hasFocusBorder: false,
                                      ),
                                ),
                                title: const Text('Include details'),
                                shape: const RoundedRectangleBorder(),
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final resting = await _capturePixels(tester, boundaryKey);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await _pumpStateAnimations(tester);
      expect(rowFocus.hasPrimaryFocus, isTrue);
      expect(controlFocus.hasFocus, isFalse);
      expect(value, isFalse);
      expect(changes, 0);
      final rowFocused = await _capturePixels(tester, boundaryKey);
      expect(_changedPixelCount(resting, rowFocused), greaterThan(0));
      expect(
        _pixelAt(rowFocused, x: 1, y: rowFocused.height ~/ 2),
        isNot(_pixelAt(resting, x: 1, y: resting.height ~/ 2)),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await _pumpStateAnimations(tester);
      expect(rowFocus.hasPrimaryFocus, isFalse);
      expect(controlFocus.hasPrimaryFocus, isTrue);
      expect(value, isFalse);
      expect(changes, 0);
      final controlFocused = await _capturePixels(tester, boundaryKey);
      expect(_changedPixelCount(resting, controlFocused), greaterThan(0));
      expect(
        _pixelAt(controlFocused, x: 1, y: controlFocused.height ~/ 2),
        isNot(_accent),
        reason: 'child focus must not also draw the row outline',
      );

      await tester.tap(find.text('Include details'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(changes, 1);
      var semantics = tester
          .getSemantics(find.text('Include details'))
          .getSemanticsData();
      expect(semantics.flagsCollection.isChecked, ui.CheckedState.isTrue);

      await tester.tap(find.byKey(const ValueKey('list-checkbox-control')));
      await tester.pumpAndSettle();
      expect(value, isFalse);
      expect(changes, 2);
      semantics = tester
          .getSemantics(find.text('Include details'))
          .getSemanticsData();
      expect(semantics.flagsCollection.isChecked, ui.CheckedState.isFalse);
      expect(semantics.flagsCollection.isEnabled, ui.Tristate.isTrue);
    },
  );

  testWidgets(
    'BusyMaxSwitchRow preserves row hover, single actions, and dragging',
    (tester) async {
      final boundaryKey = GlobalKey();
      var value = false;
      var changes = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  void onChanged(bool next) {
                    changes += 1;
                    setState(() => value = next);
                  }

                  return RepaintBoundary(
                    key: boundaryKey,
                    child: SizedBox(
                      width: 360,
                      child: BusyMaxSwitchRow(
                        title: 'Show reminders',
                        subtitle: 'Display task reminders',
                        value: value,
                        onChanged: onChanged,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = tester.widget<YaruSwitchListTile>(
        find.byType(YaruSwitchListTile),
      );
      final control = tester.widget<YaruSwitch>(find.byType(YaruSwitch));
      expect(tile.hasFocusBorder, isFalse);
      expect(tile.control, isA<BusyMaxYaruFocusBorder>());
      expect(control.hasFocusBorder, isFalse);
      expect(find.byType(BusyMaxYaruFocusBorder), findsNWidgets(2));
      expect(identical(tile.onChanged, control.onChanged), isTrue);

      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(const Offset(790, 590));
      await _pumpStateAnimations(tester);
      final resting = await _capturePixels(tester, boundaryKey);
      await mouse.moveTo(tester.getCenter(find.text('Show reminders')));
      await _pumpStateAnimations(tester);
      final hovered = await _capturePixels(tester, boundaryKey);
      expect(_changedPixelCount(resting, hovered), greaterThan(0));

      await tester.tap(find.text('Show reminders'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(changes, 1);

      await tester.tap(find.byType(YaruSwitch));
      await tester.pumpAndSettle();
      expect(value, isFalse);
      expect(changes, 2);

      await tester.drag(find.byType(YaruSwitch), const Offset(36, 0));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(changes, 3);
    },
  );

  for (final compact in [false, true]) {
    testWidgets(
      '${compact ? 'compact' : 'normal'} task chip keeps completion separate '
      'inside its real constraints',
      (tester) async {
        const item = TaskScheduleItem(
          id: 'task:selection-control',
          accountId: 'account:1',
          provider: BusyProvider.microsoft,
          sourceId: 'tasks:inbox',
          title: 'Finish report',
          completed: false,
          allDay: true,
          sourceName: 'Inbox',
        );
        var rowActivations = 0;
        var completionChanges = 0;
        bool? lastCompletion;
        final height = compact ? 26.0 : 54.0;

        await tester.pumpWidget(
          localizedTestApp(
            theme: _theme(Brightness.light),
            child: Scaffold(
              body: Center(
                child: ScheduleTaskChip(
                  item: item,
                  width: 180,
                  height: height,
                  compact: compact,
                  onTap: (_, [_]) => rowActivations += 1,
                  onCompletionChanged: (value) {
                    completionChanges += 1;
                    lastCompletion = value;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(ScheduleTaskChip)).height, height);
        expect(find.byType(YaruCheckbox), findsOneWidget);
        expect(find.byType(BusyMaxYaruFocusBorder), findsOneWidget);

        await tester.tap(find.byType(YaruCheckbox));
        await tester.pumpAndSettle();
        expect(completionChanges, 1);
        expect(lastCompletion, isTrue);
        expect(rowActivations, 0);

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await _pumpStateAnimations(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(completionChanges, 2);
        expect(rowActivations, 0);

        await tester.tap(find.text('Finish report'));
        await tester.pumpAndSettle();
        expect(rowActivations, 1);
        expect(completionChanges, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'mounted focused and hovered controls do not flash a disk across themes',
    (tester) async {
      final boundaryKey = GlobalKey();
      final focusNode = FocusNode(debugLabel: 'transition checkbox');
      addTearDown(focusNode.dispose);
      var theme = _theme(Brightness.light);
      late StateSetter setThemeState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setThemeState = setState;
            return MaterialApp(
              theme: theme,
              themeAnimationDuration: const Duration(milliseconds: 300),
              themeAnimationCurve: Curves.linear,
              home: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: () {}, child: const Text('Before')),
                      RepaintBoundary(
                        key: boundaryKey,
                        child: ColoredBox(
                          color: _captureBackground,
                          child: SizedBox(
                            width: 104,
                            height: 80,
                            child: Center(
                              child: YaruCheckbox(
                                key: _controlKey,
                                value: true,
                                onChanged: (_) {},
                                focusNode: focusNode,
                                hasFocusBorder: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await _pumpStateAnimations(tester);
      expect(focusNode.hasPrimaryFocus, isTrue);

      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byKey(_controlKey)));
      await _pumpStateAnimations(tester);

      final lightPixels = await _capturePixels(tester, boundaryKey);
      _expectOutsideControlIsBackground(tester, lightPixels, boundaryKey);
      final lightCenter = _pixelAtGlobal(
        tester,
        lightPixels,
        boundaryKey,
        tester.getCenter(find.byKey(_controlKey)),
      );

      setThemeState(() {
        theme = BusyMaxYaruTheme.build(
          brightness: Brightness.dark,
          accentColor: _alternateAccent,
        );
      });
      for (final duration in const [
        Duration.zero,
        Duration(milliseconds: 75),
        Duration(milliseconds: 75),
        Duration(milliseconds: 150),
      ]) {
        await tester.pump(duration);
        expect(focusNode.hasPrimaryFocus, isTrue);
        _expectOutsideControlIsBackground(
          tester,
          await _capturePixels(tester, boundaryKey),
          boundaryKey,
        );
      }
      final darkPixels = await _capturePixels(tester, boundaryKey);
      final darkCenter = _pixelAtGlobal(
        tester,
        darkPixels,
        boundaryKey,
        tester.getCenter(find.byKey(_controlKey)),
      );
      expect(darkCenter, isNot(lightCenter));

      setThemeState(() {
        theme = BusyMaxYaruTheme.build(
          brightness: Brightness.dark,
          accentColor: _alternateAccent,
          highContrast: true,
        );
      });
      for (final duration in const [
        Duration.zero,
        Duration(milliseconds: 100),
        Duration(milliseconds: 200),
      ]) {
        await tester.pump(duration);
        expect(focusNode.hasPrimaryFocus, isTrue);
        _expectOutsideControlIsBackground(
          tester,
          await _capturePixels(tester, boundaryKey),
          boundaryKey,
        );
      }
    },
  );
}

ThemeData _theme(Brightness brightness, {bool highContrast = false}) {
  return BusyMaxYaruTheme.build(
    brightness: brightness,
    accentColor: _accent,
    highContrast: highContrast,
  );
}

void _expectRadioConfigurationPreserved(
  YaruRadioThemeData? base,
  YaruRadioThemeData actual,
) {
  expect(actual.color, base?.color);
  expect(actual.borderColor, base?.borderColor);
  expect(actual.checkmarkColor, base?.checkmarkColor);
  expect(actual.mouseCursor, base?.mouseCursor);
}

void _expectCheckboxConfigurationPreserved(
  YaruCheckboxThemeData? base,
  YaruCheckboxThemeData actual,
) {
  expect(actual.color, base?.color);
  expect(actual.borderColor, base?.borderColor);
  expect(actual.checkmarkColor, base?.checkmarkColor);
  expect(actual.mouseCursor, base?.mouseCursor);
}

void _expectSwitchConfigurationPreserved(
  YaruSwitchThemeData? base,
  YaruSwitchThemeData actual,
) {
  expect(actual.color, base?.color);
  expect(actual.borderColor, base?.borderColor);
  expect(actual.thumbColor, base?.thumbColor);
  expect(actual.mouseCursor, base?.mouseCursor);
}

class _ControlCase {
  const _ControlCase({
    required this.name,
    required this.builder,
    this.enabled = true,
  });

  final String name;
  final bool enabled;
  final Widget Function(FocusNode focusNode, VoidCallback onActivation) builder;
}

final _controlCases = <_ControlCase>[
  _ControlCase(
    name: 'unselected YaruRadio',
    builder: (focusNode, onActivation) => YaruRadio<int>(
      value: 1,
      groupValue: 2,
      onChanged: (_) => onActivation(),
      focusNode: focusNode,
      hasFocusBorder: false,
    ),
  ),
  _ControlCase(
    name: 'selected YaruRadio',
    builder: (focusNode, onActivation) => YaruRadio<int>(
      value: 1,
      groupValue: 1,
      onChanged: (_) => onActivation(),
      focusNode: focusNode,
      hasFocusBorder: false,
    ),
  ),
  _ControlCase(
    name: 'unchecked YaruCheckbox',
    builder: (focusNode, onActivation) => YaruCheckbox(
      value: false,
      onChanged: (_) => onActivation(),
      focusNode: focusNode,
      hasFocusBorder: false,
    ),
  ),
  _ControlCase(
    name: 'checked YaruCheckbox',
    builder: (focusNode, onActivation) => YaruCheckbox(
      value: true,
      onChanged: (_) => onActivation(),
      focusNode: focusNode,
      hasFocusBorder: false,
    ),
  ),
  _ControlCase(
    name: 'mixed YaruCheckbox',
    builder: (focusNode, onActivation) => YaruCheckbox(
      value: null,
      tristate: true,
      onChanged: (_) => onActivation(),
      focusNode: focusNode,
      hasFocusBorder: false,
    ),
  ),
  _ControlCase(
    name: 'off YaruSwitch',
    builder: (focusNode, onActivation) => YaruSwitch(
      value: false,
      onChanged: (_) => onActivation(),
      focusNode: focusNode,
      hasFocusBorder: false,
    ),
  ),
  _ControlCase(
    name: 'on YaruSwitch',
    builder: (focusNode, onActivation) => YaruSwitch(
      value: true,
      onChanged: (_) => onActivation(),
      focusNode: focusNode,
      hasFocusBorder: false,
    ),
  ),
  _ControlCase(
    name: 'disabled YaruRadio',
    enabled: false,
    builder: (focusNode, onActivation) => YaruRadio<int>(
      value: 1,
      groupValue: 1,
      onChanged: null,
      focusNode: focusNode,
      hasFocusBorder: false,
    ),
  ),
  _ControlCase(
    name: 'disabled YaruCheckbox',
    enabled: false,
    builder: (focusNode, onActivation) => YaruCheckbox(
      value: true,
      onChanged: null,
      focusNode: focusNode,
      hasFocusBorder: false,
    ),
  ),
  _ControlCase(
    name: 'disabled YaruSwitch',
    enabled: false,
    builder: (focusNode, onActivation) => YaruSwitch(
      value: true,
      onChanged: null,
      focusNode: focusNode,
      hasFocusBorder: false,
    ),
  ),
];

Widget _selectionControlHost({
  required GlobalKey boundaryKey,
  required FocusNode focusNode,
  required _ControlCase controlCase,
  required VoidCallback onActivation,
}) {
  return MaterialApp(
    theme: _theme(Brightness.light),
    home: Scaffold(
      body: Center(
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                key: const ValueKey('traversal-sentinel'),
                onPressed: () {},
                child: const Text('Before'),
              ),
              RepaintBoundary(
                key: boundaryKey,
                child: ColoredBox(
                  color: _captureBackground,
                  child: SizedBox(
                    width: 104,
                    height: 80,
                    child: Center(
                      child: KeyedSubtree(
                        key: _controlKey,
                        child: controlCase.builder(focusNode, onActivation),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpStateAnimations(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<_CapturedPixels> _capturePixels(
  WidgetTester tester,
  GlobalKey key,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.binding.runAsync<ui.Image>(
    () => boundary.toImage(pixelRatio: 1),
  ))!;
  try {
    final data = (await tester.binding.runAsync<ByteData?>(
      () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
    ))!;
    return _CapturedPixels(
      bytes: Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
      width: image.width,
      height: image.height,
    );
  } finally {
    image.dispose();
  }
}

int _pixelsDifferentFrom(_CapturedPixels pixels, Color color) {
  final red = (color.r * 255).round();
  final green = (color.g * 255).round();
  final blue = (color.b * 255).round();
  final alpha = (color.a * 255).round();
  var count = 0;
  for (var offset = 0; offset < pixels.bytes.length; offset += 4) {
    if (pixels.bytes[offset] != red ||
        pixels.bytes[offset + 1] != green ||
        pixels.bytes[offset + 2] != blue ||
        pixels.bytes[offset + 3] != alpha) {
      count += 1;
    }
  }
  return count;
}

int _changedPixelCount(_CapturedPixels before, _CapturedPixels after) {
  expect(after.width, before.width);
  expect(after.height, before.height);
  var count = 0;
  for (var offset = 0; offset < before.bytes.length; offset += 4) {
    if (before.bytes[offset] != after.bytes[offset] ||
        before.bytes[offset + 1] != after.bytes[offset + 1] ||
        before.bytes[offset + 2] != after.bytes[offset + 2] ||
        before.bytes[offset + 3] != after.bytes[offset + 3]) {
      count += 1;
    }
  }
  return count;
}

Color _pixelAt(_CapturedPixels pixels, {required int x, required int y}) {
  final offset = (y * pixels.width + x) * 4;
  return Color.fromARGB(
    pixels.bytes[offset + 3],
    pixels.bytes[offset],
    pixels.bytes[offset + 1],
    pixels.bytes[offset + 2],
  );
}

Color _pixelAtGlobal(
  WidgetTester tester,
  _CapturedPixels pixels,
  GlobalKey boundaryKey,
  Offset globalPosition,
) {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final local = boundary.globalToLocal(globalPosition);
  return _pixelAt(
    pixels,
    x: local.dx.floor().clamp(0, pixels.width - 1),
    y: local.dy.floor().clamp(0, pixels.height - 1),
  );
}

void _expectOutsideControlIsBackground(
  WidgetTester tester,
  _CapturedPixels pixels,
  GlobalKey boundaryKey,
) {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final control = tester.renderObject<RenderBox>(find.byKey(_controlKey));
  final topLeft = boundary.globalToLocal(control.localToGlobal(Offset.zero));
  final bottomRight = boundary.globalToLocal(
    control.localToGlobal(control.size.bottomRight(Offset.zero)),
  );
  for (var y = 0; y < pixels.height; y += 1) {
    for (var x = 0; x < pixels.width; x += 1) {
      final inside =
          x >= topLeft.dx.floor() &&
          x < bottomRight.dx.ceil() &&
          y >= topLeft.dy.floor() &&
          y < bottomRight.dy.ceil();
      if (!inside) {
        expect(
          _pixelAt(pixels, x: x, y: y),
          _captureBackground,
          reason: 'unexpected paint outside the control at ($x, $y)',
        );
      }
    }
  }
}

class _CapturedPixels {
  const _CapturedPixels({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}
