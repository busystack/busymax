import 'dart:io';
import 'dart:ui' as ui;

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../test_localized_app.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'grouped list uses the semantic $brightness surface and Yaru rows',
      (tester) async {
        final theme = BusyMaxYaruTheme.build(
          brightness: brightness,
          accentColor: const Color(0xFF3584E4),
        );
        final colors = theme.extension<BusyMaxSurfaceColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: BusyMaxGroupedList(
                filled: true,
                children: [
                  BusyMaxActionRow(
                    title: 'Calendar',
                    subtitle: 'Personal account',
                    onTap: () {},
                  ),
                  const BusyMaxSwitchRow(
                    title: 'Notifications',
                    subtitle: 'Sync changes automatically',
                    value: true,
                    onChanged: _ignoreBool,
                  ),
                ],
              ),
            ),
          ),
        );

        final groupedSurface = find.byType(BusyMaxGroupedSurface);
        expect(groupedSurface, findsOneWidget);
        final materialSurface = tester.widget<Material>(
          find.descendant(
            of: groupedSurface,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Material && widget.color == colors.groupedSurface,
            ),
          ),
        );
        expect(BusyMaxElevation.card, 2);
        expect(materialSurface.elevation, BusyMaxElevation.card);
        expect(materialSurface.shadowColor, theme.colorScheme.shadow);
        final shape = materialSurface.shape! as RoundedRectangleBorder;
        expect(shape.side, BorderSide.none);
        expect(
          find.descendant(
            of: groupedSurface,
            matching: find.byType(YaruListTile),
          ),
          findsNWidgets(2),
        );

        final materialLayers = tester.widgetList<Material>(
          find.descendant(of: groupedSurface, matching: find.byType(Material)),
        );
        expect(
          materialLayers.where((material) => material.color == colors.control),
          isEmpty,
        );
        expect(
          DefaultTextStyle.of(
            tester.element(find.text('Personal account')),
          ).style.color,
          colors.mutedForeground,
        );
        expect(
          DefaultTextStyle.of(
            tester.element(find.text('Sync changes automatically')),
          ).style.color,
          colors.mutedForeground,
        );
      },
    );
  }

  testWidgets('disabled grouped subtitles use the semantic disabled role', (
    tester,
  ) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: const Color(0xFF3584E4),
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: BusyMaxActionRow(
            title: 'Calendar',
            subtitle: 'Account unavailable',
            enabled: false,
          ),
        ),
      ),
    );

    expect(
      DefaultTextStyle.of(
        tester.element(find.text('Account unavailable')),
      ).style.color,
      colors.disabledForeground,
    );
  });

  testWidgets('grouped cards add a semantic outline in high contrast', (
    tester,
  ) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: const Color(0xFF3584E4),
      highContrast: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: BusyMaxGroupedSurface(child: SizedBox(height: 48)),
        ),
      ),
    );

    final materialSurface = tester.widget<Material>(
      find.descendant(
        of: find.byType(BusyMaxGroupedSurface),
        matching: find.byType(Material),
      ),
    );
    final shape = materialSurface.shape! as RoundedRectangleBorder;
    expect(shape.side.color, theme.colorScheme.outline);
    expect(shape.side.width, BusyMaxStroke.outline);
  });

  for (final brightness in Brightness.values) {
    testWidgets('rows use the subtle Yaru $brightness hover role', (
      tester,
    ) async {
      final theme = BusyMaxYaruTheme.build(
        brightness: brightness,
        accentColor: const Color(0xFF3584E4),
      );
      final yaruBase = brightness == Brightness.light
          ? createYaruLightTheme(primaryColor: BusyMaxLinuxPalette.light4)
          : createYaruDarkTheme(primaryColor: BusyMaxLinuxPalette.light2);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                BusyMaxActionRow(title: 'Calendar', onTap: () {}),
                const BusyMaxSwitchRow(
                  title: 'Notifications',
                  value: true,
                  onChanged: _ignoreBool,
                ),
              ],
            ),
          ),
        ),
      );

      expect(theme.hoverColor, yaruBase.hoverColor);
      expect(
        theme.hoverColor,
        isNot(theme.extension<BusyMaxSurfaceColors>()!.controlHover),
      );
      final actionTile = tester.widget<YaruListTile>(
        find.descendant(
          of: find.byType(BusyMaxActionRow),
          matching: find.byType(YaruListTile),
        ),
      );
      final switchTile = tester.widget<YaruListTile>(
        find.descendant(
          of: find.byType(BusyMaxSwitchRow),
          matching: find.byType(YaruListTile),
        ),
      );
      expect(actionTile.hoverColor, theme.hoverColor);
      expect(switchTile.hoverColor, theme.hoverColor);
      expect(
        busyMaxEditorRowHoverColor(
          tester.element(find.byType(BusyMaxActionRow)),
        ),
        theme.hoverColor,
      );
    });
  }

  testWidgets('sidebar surface draws the semantic directional end boundary', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const BusyMaxSidebarSurface(
          child: SizedBox(width: BusyMaxSizes.sidebarWidth, height: 200),
        ),
      ),
    );
    final context = tester.element(find.byType(BusyMaxSidebarSurface));
    final colors = BusyMaxSurfaceColors.of(context);
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(BusyMaxSidebarSurface),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == colors.sidebar,
        ),
      ),
    );
    final decorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(BusyMaxSidebarSurface),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).border is BorderDirectional,
        ),
      ),
    );
    final border = (decorated.decoration as BoxDecoration).border!;

    expect(material.color, colors.sidebar);
    expect(decorated.position, DecorationPosition.foreground);
    expect(border, isA<BorderDirectional>());
    expect((border as BorderDirectional).end.color, colors.sidebarBorder);
    expect(border.end.width, BusyMaxStroke.outline);
  });

  testWidgets(
    'sidebar navigation delegates native geometry and states to Yaru',
    (tester) async {
      var selectedSchedule = false;
      await tester.pumpWidget(
        _testApp(
          SizedBox(
            width: BusyMaxSizes.sidebarWidth,
            height: 200,
            child: BusyMaxSidebarSurface(
              child: BusyMaxSidebarNavigation(
                children: [
                  BusyMaxSidebarNavigationTile(
                    selected: true,
                    leading: const Icon(YaruIcons.user),
                    title: const Text('Accounts'),
                    onTap: () {},
                  ),
                  BusyMaxSidebarNavigationTile(
                    selected: false,
                    leading: const Icon(YaruIcons.calendar_day),
                    title: const Text('Schedule'),
                    onTap: () => selectedSchedule = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(YaruMasterTile), findsNWidgets(2));
      expect(find.byType(YaruNavigationRailItem), findsNothing);

      final firstTile = find.byType(YaruMasterTile).first;
      final localContext = tester.element(firstTile);
      final localTheme = Theme.of(localContext);
      final colors = BusyMaxSurfaceColors.of(localContext);
      final listTileTheme = localTheme.listTileTheme;
      final parentTheme = Theme.of(
        tester.element(find.byType(BusyMaxSidebarNavigation)),
      );

      expect(tester.widget<YaruMasterTile>(firstTile).selected, isTrue);
      expect(tester.getSize(firstTile).height, BusyMaxSizes.sidebarRowHeight);
      expect(
        listTileTheme.selectedTileColor,
        Color.alphaBlend(colors.control, colors.sidebar),
      );
      expect(listTileTheme.selectedColor, colors.foreground);
      expect(listTileTheme.iconColor, colors.mutedForeground);
      expect(listTileTheme.titleTextStyle, localTheme.textTheme.bodyMedium);
      expect(listTileTheme.minTileHeight, BusyMaxSizes.sidebarRowHeight);
      expect(listTileTheme.horizontalTitleGap, BusyMaxSpacing.sm);
      expect(listTileTheme.minLeadingWidth, BusyMaxSizes.iconSm);
      expect(localTheme.hoverColor, parentTheme.hoverColor);
      expect(localTheme.focusColor, parentTheme.focusColor);
      expect(localTheme.highlightColor, parentTheme.highlightColor);

      await tester.tap(find.text('Schedule'));
      await tester.pump();
      expect(selectedSchedule, isTrue);
    },
  );

  test('all primary sidebars reuse the shared boundary surface', () {
    for (final path in [
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
      'lib/src/features/settings/presentation/settings_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('BusyMaxSidebarSurface('), reason: path);
      expect(
        source,
        isNot(contains('color: BusyMaxSurfaceColors.of(context).sidebar')),
        reason: path,
      );
    }
  });

  testWidgets('action row distinguishes keyboard and pointer activation', (
    tester,
  ) async {
    final activations = <Offset?>[];
    await tester.pumpWidget(
      _testApp(
        BusyMaxActionRow(
          title: 'Calendar',
          onActivated: (_, globalPosition) {
            activations.add(globalPosition);
          },
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activations, [isNull]);

    final pointerPosition = tester.getCenter(find.text('Calendar'));
    await tester.tapAt(pointerPosition);
    await tester.pump();

    expect(activations, [isNull, pointerPosition]);

    final tile = tester.widget<YaruListTile>(
      find.descendant(
        of: find.byType(BusyMaxActionRow),
        matching: find.byType(YaruListTile),
      ),
    );
    tile.onTap!();

    expect(activations, [isNull, pointerPosition, isNull]);
  });

  testWidgets('nested checkbox does not activate its action row', (
    tester,
  ) async {
    final activations = <Offset?>[];
    var completionChanges = 0;
    await tester.pumpWidget(
      _testApp(
        BusyMaxActionRow(
          title: 'Prepare release',
          trailing: YaruCheckbox(
            value: false,
            onChanged: (_) => completionChanges += 1,
          ),
          onActivated: (_, globalPosition) {
            activations.add(globalPosition);
          },
        ),
      ),
    );

    await tester.tap(find.byType(YaruCheckbox));
    await tester.pump();

    expect(completionChanges, 1);
    expect(activations, isEmpty);

    final tile = tester.widget<YaruListTile>(
      find.descendant(
        of: find.byType(BusyMaxActionRow),
        matching: find.byType(YaruListTile),
      ),
    );
    tile.onTap!();

    expect(activations, [isNull]);
  });

  testWidgets('disabled combo row cannot open or receive keyboard focus', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      _testApp(
        BusyMaxComboRow<String>(
          title: 'Calendar',
          values: const ['Personal', 'Work'],
          selected: 'Personal',
          labelFor: (value) => value,
          onSelected: selected.add,
          enabled: false,
        ),
      ),
    );

    final combo = find.byType(BusyMaxComboRow<String>);
    final trigger = find.descendant(of: combo, matching: _dropdownMenuFinder());
    expect(trigger, findsOneWidget);

    await tester.tap(trigger, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
    expect(selected, isEmpty);
    final disabledSemantics = tester.widget<Semantics>(
      find.descendant(
        of: combo,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Calendar',
        ),
      ),
    );
    expect(disabledSemantics.properties.button, isTrue);
    expect(disabledSemantics.properties.enabled, isFalse);
    expect(disabledSemantics.properties.value, 'Personal');
  });

  testWidgets('combo row delegates form selection and geometry to Yaru', (
    tester,
  ) async {
    final selections = <int>[];
    await tester.pumpWidget(
      _testApp(
        Directionality(
          textDirection: TextDirection.rtl,
          child: BusyMaxComboRow<int>(
            title: 'Calendar',
            values: const [1, 2],
            selected: 1,
            labelFor: (value) => 'Calendar $value',
            onSelected: selections.add,
          ),
        ),
      ),
    );

    final triggerFinder = find.descendant(
      of: find.byType(BusyMaxComboRow<int>),
      matching: _dropdownMenuFinder(),
    );
    final trigger = tester.widget<DropdownMenu>(triggerFinder);
    expect(trigger.selectOnly, isTrue);
    expect(trigger.enableSearch, isFalse);
    expect(trigger.width, tester.getSize(triggerFinder).width);
    expect(trigger.inputDecorationTheme, isNull);
    expect(trigger.menuStyle, isNull);
    expect(trigger.initialSelection, isNotNull);

    final selectedRect = tester.getRect(find.text('Calendar 1').first);
    final arrowRect = tester.getRect(
      find
          .descendant(
            of: triggerFinder,
            matching: find.byIcon(YaruIcons.pan_down),
          )
          .hitTestable(),
    );
    expect(arrowRect.right, lessThanOrEqualTo(selectedRect.left));

    await tester.tap(triggerFinder);
    await tester.pumpAndSettle();

    final firstChoice = find
        .byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Calendar 1',
        )
        .hitTestable();
    final secondChoice = find
        .byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Calendar 2',
        )
        .hitTestable();
    expect(firstChoice, findsOneWidget);
    expect(secondChoice, findsOneWidget);
    expect(
      tester.getRect(firstChoice).top,
      greaterThanOrEqualTo(tester.getRect(triggerFinder).bottom),
    );
    final visibleMenuItems = find.byType(MenuItemButton).hitTestable();
    expect(visibleMenuItems, findsNWidgets(2));
    expect(find.byType(YaruFocusBorder), findsNothing);
    final selectedSemantics = tester
        .widgetList<Semantics>(
          find.descendant(
            of: visibleMenuItems,
            matching: find.byType(Semantics),
          ),
        )
        .where((semantics) => semantics.properties.selected == true);
    expect(selectedSemantics, hasLength(1));

    await tester.tap(secondChoice);
    await tester.pumpAndSettle();
    expect(selections, [2]);
  });

  testWidgets('combo row maps a nullable domain choice through the popup', (
    tester,
  ) async {
    final selections = <String?>[];
    await tester.pumpWidget(
      _testApp(
        BusyMaxComboRow<String?>(
          title: 'Category',
          values: const [null, 'Problem'],
          selected: 'Problem',
          labelFor: (value) => value ?? 'Select a category',
          onSelected: selections.add,
        ),
      ),
    );

    await tester.tap(_dropdownMenuFinder());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select a category').last);
    await tester.pumpAndSettle();

    expect(selections, [isNull]);
  });

  testWidgets('combo popup stays constrained to its trigger width', (
    tester,
  ) async {
    const selectorWidth = 220.0;
    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 640,
          child: BusyMaxComboRow<String>(
            title: 'Calendar',
            width: selectorWidth,
            values: const [
              'Personal',
              'A provider-controlled calendar name that is intentionally long',
            ],
            selected: 'Personal',
            labelFor: (value) => value,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final trigger = _dropdownMenuFinder();
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    final triggerWidth = tester.getSize(trigger).width;
    for (final item in find.byType(MenuItemButton).hitTestable().evaluate()) {
      expect(tester.getSize(find.byWidget(item.widget)).width, triggerWidth);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('combo row supports keyboard activation and menu navigation', (
    tester,
  ) async {
    final selections = <String>[];
    await tester.pumpWidget(
      _testApp(
        BusyMaxComboRow<String>(
          title: 'Calendar',
          values: const ['Personal', 'Work'],
          selected: 'Personal',
          labelFor: (value) => value,
          onSelected: selections.add,
        ),
      ),
    );

    final triggerFinder = find.descendant(
      of: find.byType(BusyMaxComboRow<String>),
      matching: _dropdownMenuFinder(),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemButton).hitTestable(), findsNWidgets(2));
    expect(
      tester.getRect(find.text('Personal').last).top,
      greaterThanOrEqualTo(tester.getRect(triggerFinder).bottom),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selections, ['Work']);
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
  });

  testWidgets('combo row accepts unbounded horizontal constraints', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        UnconstrainedBox(
          child: BusyMaxComboRow<String>(
            title: 'Calendar',
            values: const ['Personal', 'Work'],
            selected: 'Personal',
            labelFor: (value) => value,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(_dropdownMenuFinder(), findsOneWidget);
    expect(tester.getSize(_dropdownMenuFinder()).width, 220);
    expect(tester.takeException(), isNull);
  });

  testWidgets('combo row exposes validation errors accessibly', (tester) async {
    await tester.pumpWidget(
      _testApp(
        BusyMaxComboRow<String>(
          title: 'Category',
          errorText: 'Choose a category',
          values: const ['None', 'Problem'],
          selected: 'None',
          labelFor: (value) => value,
          onSelected: (_) {},
        ),
      ),
    );

    final errorText = tester.widget<Text>(find.text('Choose a category'));
    final errorContext = tester.element(find.text('Choose a category'));
    expect(errorText.style?.color, Theme.of(errorContext).colorScheme.error);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.validationResult ==
                ui.SemanticsValidationResult.invalid,
      ),
      findsOneWidget,
    );
  });

  testWidgets('switch row exposes one merged toggle interaction', (
    tester,
  ) async {
    final values = <bool>[];
    await tester.pumpWidget(
      _testApp(
        BusyMaxSwitchRow(
          title: 'Notifications',
          value: true,
          onChanged: values.add,
        ),
      ),
    );
    final semanticsHandle = tester.ensureSemantics();

    expect(
      find.descendant(
        of: find.byType(BusyMaxSwitchRow),
        matching: find.byType(MergeSemantics),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);

    await tester.tap(find.text('Notifications'));
    await tester.pump();
    expect(values, [isFalse]);

    await tester.tap(find.byType(YaruSwitch));
    await tester.pump();
    expect(values, [isFalse, isFalse]);
    semanticsHandle.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('dialogs and popovers use native $brightness surface roles', (
      tester,
    ) async {
      final theme = BusyMaxYaruTheme.build(
        brightness: brightness,
        accentColor: const Color(0xFF3584E4),
      );
      final colors = theme.extension<BusyMaxSurfaceColors>()!;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Stack(
              children: [
                BusyMaxModalEditorSurface(
                  child: const SizedBox(width: 240, height: 120),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: BusyMaxPopoverSurface(
                    color: colors.popover,
                    child: const SizedBox(width: 180, height: 80),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final modalMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(BusyMaxModalEditorSurface),
          matching: find.byWidgetPredicate(
            (widget) => widget is Material && widget.color == colors.dialog,
          ),
        ),
      );
      final modalDialog = tester.widget<Dialog>(
        find.descendant(
          of: find.byType(BusyMaxModalEditorSurface),
          matching: find.byType(Dialog),
        ),
      );
      expect(modalDialog.backgroundColor, isNull);
      expect(modalDialog.surfaceTintColor, isNull);
      expect(modalDialog.elevation, isNull);
      expect(modalDialog.shadowColor, isNull);
      expect(modalDialog.shape, isNull);
      expect(modalMaterial.shape, theme.dialogTheme.shape);

      final physicalShape = tester.widget<PhysicalShape>(
        find.descendant(
          of: find.byType(BusyMaxPopoverSurface),
          matching: find.byType(PhysicalShape),
        ),
      );
      expect(physicalShape.elevation, BusyMaxElevation.tooltip);
      expect(physicalShape.shadowColor, theme.colorScheme.shadow);
      final outlinePaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(BusyMaxPopoverSurface),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.foregroundPainter != null,
          ),
        ),
      );
      expect(outlinePaint.foregroundPainter, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('combo row stacks its selector for large text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BusyMaxYaruTheme.build(
          brightness: Brightness.light,
          accentColor: const Color(0xFF3584E4),
        ),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
            body: SizedBox(
              width: 760,
              child: BusyMaxComboRow<String>(
                title: 'Calendar account with a long label',
                values: const ['Personal calendar', 'Work calendar'],
                selected: 'Personal calendar',
                labelFor: (value) => value,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(
      find.text('Calendar account with a long label'),
    );
    final triggerRect = tester.getRect(_dropdownMenuFinder());
    expect(triggerRect.top, greaterThanOrEqualTo(titleRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('time mode is a full-width neutral Yaru toggle group', (
    tester,
  ) async {
    const accentColor = Color(0xFF3584E4);
    final changes = <bool>[];
    await tester.pumpWidget(
      localizedTestApp(
        child: Theme(
          data: BusyMaxYaruTheme.build(
            brightness: Brightness.light,
            accentColor: accentColor,
          ),
          child: Scaffold(
            body: BusyMaxTimeModeRow(allDay: true, onChanged: changes.add),
          ),
        ),
      ),
    );

    expect(find.text('Time'), findsNothing);
    expect(find.text('Use dates only or set specific times.'), findsNothing);
    expect(find.byType(YaruListTile), findsNothing);

    final control = tester.widget<ToggleButtons>(find.byType(ToggleButtons));
    expect(control.isSelected, [isTrue, isFalse]);
    final theme = Theme.of(tester.element(find.byType(ToggleButtons)));
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    expect(theme.toggleButtonsTheme.fillColor, colors.controlActive);
    expect(theme.toggleButtonsTheme.fillColor, isNot(accentColor));
    expect(theme.toggleButtonsTheme.selectedColor, colors.foreground);
    expect(theme.toggleButtonsTheme.selectedBorderColor, colors.border);
    expect(
      theme.toggleButtonsTheme.borderRadius,
      BorderRadius.circular(BusyMaxRadius.sm),
    );

    final rowRect = tester.getRect(find.byType(BusyMaxTimeModeRow));
    final controlRect = tester.getRect(find.byType(ToggleButtons));
    expect(controlRect.width, rowRect.width);
    final segmentWidths = tester
        .widgetList<TextButton>(
          find.descendant(
            of: find.byType(ToggleButtons),
            matching: find.byType(TextButton),
          ),
        )
        .map((button) => tester.getSize(find.byWidget(button)).width)
        .toList();
    expect(segmentWidths, hasLength(2));
    expect(segmentWidths.first, segmentWidths.last);

    await tester.tap(find.text('Time slot'));
    await tester.pump();
    expect(changes, [isFalse]);
  });

  testWidgets('time mode remains full width when its section is narrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedTestApp(
        child: Theme(
          data: BusyMaxYaruTheme.build(
            brightness: Brightness.light,
            accentColor: const Color(0xFF3584E4),
          ),
          child: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                child: BusyMaxTimeModeRow(allDay: true, onChanged: _ignoreBool),
              ),
            ),
          ),
        ),
      ),
    );

    final rowRect = tester.getRect(find.byType(BusyMaxTimeModeRow));
    final controlRect = tester.getRect(find.byType(ToggleButtons));
    expect(controlRect.width, rowRect.width);
    expect(controlRect.width, 420);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor header actions are natural width with native loading', (
    tester,
  ) async {
    Widget header({required bool saving}) {
      return BusyMaxEditorHeader(
        title: 'Edit event',
        cancelLabel: 'Cancel',
        saveLabel: 'Save',
        onCancel: () {},
        onSave: () {},
        saving: saving,
      );
    }

    await tester.pumpWidget(_linuxTestApp(header(saving: false)));

    final cancel = find.byType(FilledButton);
    final save = find.byType(ElevatedButton);
    final slotWidth =
        tester.getSize(find.byType(BusyMaxEditorHeader)).width / 3;
    expect(tester.getSize(cancel).width, lessThan(slotWidth));
    expect(tester.getSize(save).width, lessThan(slotWidth));
    expect(tester.getSize(cancel).height, kYaruButtonHeight);
    expect(tester.getSize(save).height, kYaruButtonHeight);
    final cancelButton = tester.widget<FilledButton>(cancel);
    final saveButton = tester.widget<ElevatedButton>(save);
    final actionTextStyle = Theme.of(tester.element(save)).textTheme.titleSmall;
    expect(saveButton.style?.textStyle?.resolve(const {}), actionTextStyle);
    for (final style in [cancelButton.style, saveButton.style]) {
      expect(style?.minimumSize, isNull);
      expect(style?.fixedSize, isNull);
      expect(style?.maximumSize, isNull);
      expect(style?.padding, isNull);
      expect(style?.tapTargetSize, isNull);
      expect(style?.visualDensity, isNull);
    }

    await tester.pumpWidget(_linuxTestApp(header(saving: true)));
    await tester.pump();

    expect(tester.getSize(save).width, lessThan(slotWidth));
    expect(tester.getSize(save).height, kYaruButtonHeight);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('custom dialogs announce their title as route semantics', (
    tester,
  ) async {
    Semantics routeSemantics(String label) {
      return tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == label,
        ),
      );
    }

    await tester.pumpWidget(
      _testApp(
        BusyMaxModalEditorScaffold(
          title: 'Edit event',
          cancelLabel: 'Cancel',
          saveLabel: 'Save',
          onCancel: () {},
          onSave: null,
          children: const [Text('Editor content')],
        ),
      ),
    );
    final editorSemantics = routeSemantics('Edit event');
    expect(editorSemantics.properties.scopesRoute, isTrue);
    expect(editorSemantics.properties.namesRoute, isTrue);
    expect(editorSemantics.explicitChildNodes, isTrue);

    await tester.pumpWidget(
      _testApp(
        const BusyMaxDialogShell(
          title: 'Confirm action',
          children: [Text('Dialog content')],
        ),
      ),
    );
    final dialogSemantics = routeSemantics('Confirm action');
    expect(dialogSemantics.properties.scopesRoute, isTrue);
    expect(dialogSemantics.properties.namesRoute, isTrue);
    expect(dialogSemantics.explicitChildNodes, isTrue);
  });
}

void _ignoreBool(bool value) {}

Finder _dropdownMenuFinder() {
  return find.byWidgetPredicate((widget) => widget is DropdownMenu);
}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFF3584E4),
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: 480, child: child)),
    ),
  );
}

Widget _linuxTestApp(Widget child) {
  final previousPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  try {
    return _testApp(child);
  } finally {
    debugDefaultTargetPlatformOverride = previousPlatform;
  }
}
