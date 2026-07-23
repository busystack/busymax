import 'dart:io';
import 'dart:ui' as ui;

import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
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
        expect(shape.side.color, colors.subtleBorder);
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
      },
    );
  }

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

  test('all primary sidebars reuse the shared boundary surface', () {
    for (final path in [
      'lib/src/features/schedule/presentation/schedule_sidebar.dart',
      'lib/src/features/task_lists/presentation/task_lists_sidebar.dart',
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
    final trigger = find.descendant(
      of: combo,
      matching: find.byType(OutlinedButton),
    );
    expect(trigger, findsOneWidget);

    await tester.tap(trigger, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemButton), findsNothing);
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

    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(tester.getSize(find.byType(OutlinedButton)).width, 220);
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
    testWidgets('floating surfaces use semantic $brightness separation', (
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
            body: Column(
              children: [
                BusyMaxModalEditorSurface(
                  child: const SizedBox(width: 240, height: 120),
                ),
                BusyMaxPopoverSurface(
                  color: colors.popover,
                  child: const SizedBox(width: 180, height: 80),
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
      final modalShape = modalMaterial.shape! as RoundedRectangleBorder;
      expect(modalMaterial.elevation, BusyMaxElevation.window);
      expect(modalMaterial.shadowColor, theme.colorScheme.shadow);
      expect(modalShape.side.color, colors.subtleBorder);
      expect(modalShape.side.width, BusyMaxStroke.outline);

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
    final triggerRect = tester.getRect(find.byType(OutlinedButton));
    expect(triggerRect.top, greaterThanOrEqualTo(titleRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('time mode uses a labeled row and neutral Yaru toggle group', (
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

    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Use dates only or set specific times.'), findsOneWidget);
    expect(find.byType(YaruListTile), findsOneWidget);

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

    final titleRect = tester.getRect(find.text('Time'));
    final descriptionRect = tester.getRect(
      find.text('Use dates only or set specific times.'),
    );
    final controlRect = tester.getRect(find.byType(ToggleButtons));
    expect(descriptionRect.top, greaterThan(titleRect.top));
    expect(controlRect.left, greaterThan(titleRect.right));

    await tester.tap(find.text('Time slot'));
    await tester.pump();
    expect(changes, [isFalse]);
  });

  testWidgets('time mode stacks cleanly when its form section is narrow', (
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

    final descriptionRect = tester.getRect(
      find.text('Use dates only or set specific times.'),
    );
    final controlRect = tester.getRect(find.byType(ToggleButtons));
    expect(controlRect.top, greaterThanOrEqualTo(descriptionRect.bottom));
    expect(tester.takeException(), isNull);
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
