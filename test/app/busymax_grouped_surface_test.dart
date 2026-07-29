import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:busymax/src/app/app_theme.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/platform/native_menu_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

import '../test_localized_app.dart';

const _nativeMenuChannel = MethodChannel(nativeMenuChannelName);

void main() {
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

  testWidgets('filled surfaces use the shared native card shadow profile', (
    tester,
  ) async {
    const semanticShadow = Color(0xFF123456);
    const semanticElevation = 3.0;
    final baseTheme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFF3584E4),
    );
    final theme = baseTheme.copyWith(
      cardTheme: baseTheme.cardTheme.copyWith(
        elevation: semanticElevation,
        shadowColor: semanticShadow,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const BusyMaxSurface(child: SizedBox(width: 120, height: 48)),
      ),
    );

    final card = tester.widget<Card>(
      find.descendant(
        of: find.byType(BusyMaxSurface),
        matching: find.byType(Card),
      ),
    );
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(Card), matching: find.byType(Material)),
    );
    final shadowDecoration = _nativeCardDecoration(
      tester,
      find.byType(BusyMaxSurface),
    );
    expect(card.elevation, isNull);
    expect(card.shadowColor, Colors.transparent);
    expect(material.elevation, semanticElevation);
    expect(material.shadowColor, Colors.transparent);
    expect(
      shadowDecoration.shadows,
      BusyMaxShadow.nativeCardShadows(semanticShadow),
    );
  });

  testWidgets(
    'Flutter popover surfaces use the native layered shadow profile',
    (tester) async {
      const semanticShadow = Color.fromRGBO(32, 80, 128, 0.8);
      const menuKey = ValueKey('menu-popover');
      final baseTheme = BusyMaxYaruTheme.build(
        brightness: Brightness.light,
        accentColor: const Color(0xFF3584E4),
      );
      final theme = baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(shadow: semanticShadow),
      );
      final colors = theme.extension<BusyMaxSurfaceColors>()!;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                BusyMaxPopoverSurface(
                  key: menuKey,
                  color: colors.popover,
                  child: const SizedBox(width: 120, height: 48),
                ),
                const BusyMaxContentPopoverSurface(
                  child: SizedBox(width: 120, height: 48),
                ),
              ],
            ),
          ),
        ),
      );

      final menuDecorationFinder = find.descendant(
        of: find.byKey(menuKey),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is ShapeDecoration &&
              ((widget.decoration as ShapeDecoration).shadows?.isNotEmpty ??
                  false),
        ),
      );
      final contentDecorationFinder = find.descendant(
        of: find.byType(BusyMaxContentPopoverSurface),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is ShapeDecoration &&
              ((widget.decoration as ShapeDecoration).shadows?.isNotEmpty ??
                  false),
        ),
      );

      expect(menuDecorationFinder, findsOneWidget);
      expect(contentDecorationFinder, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BusyMaxPopoverSurface),
          matching: find.byType(PhysicalShape),
        ),
        findsNothing,
      );
      final expectedMenuShadows = BusyMaxShadow.nativePopoverShadows(
        semanticShadow,
      );
      final expectedDetailsShadows = BusyMaxShadow.nativePopoverShadows(
        semanticShadow,
        role: BusyMaxPopoverShadowRole.details,
      );
      for (final (finder, expectedShadows) in [
        (menuDecorationFinder, expectedMenuShadows),
        (contentDecorationFinder, expectedDetailsShadows),
      ]) {
        final decoratedBox = tester.widget<DecoratedBox>(finder);
        final decoration = decoratedBox.decoration as ShapeDecoration;
        expect(decoration.shadows, expectedShadows);
        for (final shadow in decoration.shadows!) {
          expect(shadow.color.r, semanticShadow.r);
          expect(shadow.color.g, semanticShadow.g);
          expect(shadow.color.b, semanticShadow.b);
        }
      }
      expect(expectedMenuShadows[0].blurRadius, 14);
      expect(expectedMenuShadows[1].blurRadius, 5);
      expect(expectedDetailsShadows[0].blurRadius, 13.5);
      expect(expectedDetailsShadows[1].blurRadius, 4.5);
      expect(expectedMenuShadows[0].color.a, closeTo(0.8 * 0.05, 0.0001));
      expect(expectedMenuShadows[1].color.a, closeTo(0.8 * 0.09, 0.0001));
      expect(
        expectedDetailsShadows.map((shadow) => shadow.color),
        expectedMenuShadows.map((shadow) => shadow.color),
      );
      expect(BusyMaxShadow.nativePopoverPaintMargin, 31);
    },
  );

  test('Settings and reused Year calendars use shared grouped cards', () {
    final settings = File(
      'lib/src/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();
    final yearView = File(
      'lib/src/features/schedule/presentation/schedule_year_view.dart',
    ).readAsStringSync();

    expect(settings, contains('BusyMaxGroupedList('));
    expect(yearView, contains('YearMonthMiniCalendar('));
    expect(yearView, contains('BusyMaxGroupedSurface('));
    for (final source in [settings, yearView]) {
      expect(source, isNot(contains('BoxShadow(')));
      expect(source, isNot(contains('elevation:')));
    }
  });

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
              (widget) => widget is Material && widget.color == colors.card,
            ),
          ),
        );
        expect(materialSurface.color, theme.cardTheme.color);
        expect(materialSurface.color?.a, 1);
        expect(materialSurface.elevation, theme.cardTheme.elevation);
        expect(materialSurface.shadowColor, Colors.transparent);
        expect(
          _nativeCardDecoration(tester, groupedSurface).shadows,
          BusyMaxShadow.nativeCardShadows(theme.colorScheme.shadow),
        );
        final shape = materialSurface.shape! as RoundedRectangleBorder;
        expect(shape.side, BorderSide.none);
        expect(
          find.descendant(of: groupedSurface, matching: find.byType(Card)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: groupedSurface,
            matching: find.byType(YaruListTile),
          ),
          findsNWidgets(2),
        );
        final divider = tester.widget<Divider>(
          find.descendant(of: groupedSurface, matching: find.byType(Divider)),
        );
        expect(divider.height, 1);
        expect(divider.thickness, 1);
        expect(divider.color, colors.cardShade);
        expect(colors.cardShade, isNot(colors.divider));
        expect(
          Color.alphaBlend(colors.cardShade, colors.card).toARGB32(),
          switch (brightness) {
            Brightness.light => const Color(0xFFEDEDED).toARGB32(),
            Brightness.dark => const Color(0xFF272727).toARGB32(),
          },
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

  testWidgets('unfilled surfaces stay flat and borderless', (tester) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFF3584E4),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const BusyMaxSurface(
          filled: false,
          child: SizedBox(width: 120, height: 48),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(BusyMaxSurface),
        matching: find.byType(Material),
      ),
    );
    final shape = material.shape! as RoundedRectangleBorder;
    expect(material.color, Colors.transparent);
    expect(material.elevation, 0);
    expect(shape.side, BorderSide.none);
    expect(
      find.descendant(
        of: find.byType(BusyMaxSurface),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
  });

  testWidgets('dialog grouped surface stays raised in dark mode', (
    tester,
  ) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: const Color(0xFF3584E4),
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    late Color resolvedSurface;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: BusyMaxSurfaceScope(
          role: BusyMaxSurfaceRole.window,
          child: Builder(
            builder: (context) {
              resolvedSurface = busyMaxGroupedSurfaceColor(
                context,
                parentRole: BusyMaxSurfaceRole.dialog,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      resolvedSurface.toARGB32(),
      Color.alphaBlend(colors.groupedSurface, colors.dialog).toARGB32(),
    );
    expect(resolvedSurface, isNot(colors.dialog));
    expect(
      resolvedSurface.computeLuminance(),
      greaterThan(colors.dialog.computeLuminance()),
    );
  });

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

  testWidgets(
    'disabled shared header and destructive actions use semantic roles',
    (tester) async {
      final theme = BusyMaxYaruTheme.build(
        brightness: Brightness.dark,
        accentColor: const Color(0xFF3584E4),
      );
      final colors = theme.extension<BusyMaxSurfaceColors>()!;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  BusyMaxHeaderIconButton(
                    key: const ValueKey('disabled-header-icon'),
                    tooltip: 'Disabled icon action',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: null,
                    foregroundColor: colors.foreground,
                    backgroundColor: busyMaxHeaderButtonBackground(context),
                  ),
                  TextButton(
                    key: const ValueKey('disabled-header-text'),
                    onPressed: null,
                    style: busyMaxHeaderTextButtonStyle(
                      context,
                      foregroundColor: colors.foreground,
                      backgroundColor: busyMaxHeaderButtonBackground(context),
                    ),
                    child: const Text('Disabled text action'),
                  ),
                  const BusyMaxActionRow(
                    title: 'Disabled destructive action',
                    destructive: true,
                    enabled: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final icon = find.descendant(
        of: find.byKey(const ValueKey('disabled-header-icon')),
        matching: find.byIcon(Icons.edit_outlined),
      );
      expect(
        IconTheme.of(tester.element(icon)).color,
        colors.disabledForeground,
      );
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('Disabled text action')),
        ).style.color,
        colors.disabledForeground,
      );
      expect(
        tester
            .widget<Text>(find.text('Disabled destructive action'))
            .style
            ?.color,
        colors.disabledForeground,
      );
      expect(
        busyMaxHeaderButtonBackground(
          tester.element(find.byKey(const ValueKey('disabled-header-icon'))),
        ).resolve({WidgetState.disabled}),
        colors.disabledControl,
      );
      final iconButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const ValueKey('disabled-header-icon')),
          matching: find.byType(IconButton),
        ),
      );
      expect(iconButton.style?.backgroundColor?.resolve({}), colors.control);
      expect(
        iconButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
        colors.controlHover,
      );
      expect(
        iconButton.style?.backgroundColor?.resolve({WidgetState.pressed}),
        colors.controlActive,
      );
    },
  );

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

  testWidgets('grouped cards preserve inherited card geometry and outline', (
    tester,
  ) async {
    const inheritedSide = BorderSide(color: Color(0xFF4A4A4A), width: 2);
    const inheritedRadius = BorderRadius.all(Radius.circular(9));
    final baseTheme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFF3584E4),
    );
    final theme = baseTheme.copyWith(
      cardTheme: baseTheme.cardTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: inheritedRadius,
          side: inheritedSide,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const BusyMaxGroupedSurface(
          child: SizedBox(width: 120, height: 48),
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
    expect(shape.borderRadius, inheritedRadius);
    expect(shape.side, inheritedSide);
  });

  testWidgets('grouped cards inherit the semantic card shadow color', (
    tester,
  ) async {
    const semanticShadow = Color(0x80123456);
    final baseTheme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFF3584E4),
    );
    final theme = baseTheme.copyWith(
      cardTheme: baseTheme.cardTheme.copyWith(shadowColor: semanticShadow),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const BusyMaxGroupedSurface(
          child: SizedBox(width: 120, height: 48),
        ),
      ),
    );

    final decoration = _nativeCardDecoration(
      tester,
      find.byType(BusyMaxGroupedSurface),
    );
    final expectedShadows = BusyMaxShadow.nativeCardShadows(semanticShadow);
    expect(decoration.shadows, expectedShadows);
    for (final shadow in decoration.shadows!) {
      expect(shadow.color.r, semanticShadow.r);
      expect(shadow.color.g, semanticShadow.g);
      expect(shadow.color.b, semanticShadow.b);
    }
    expect(
      expectedShadows[0].color.a,
      closeTo(semanticShadow.a * 0.03, 0.0001),
    );
    expect(
      expectedShadows[1].color.a,
      closeTo(semanticShadow.a * 0.07, 0.0001),
    );
    expect(
      expectedShadows[2].color.a,
      closeTo(semanticShadow.a * 0.03, 0.0001),
    );
  });

  testWidgets(
    'grouped card paints its opaque semantic role in a dark editor sheet',
    (tester) async {
      final theme = BusyMaxYaruTheme.build(
        brightness: Brightness.dark,
        accentColor: const Color(0xFF3584E4),
      );
      final colors = theme.extension<BusyMaxSurfaceColors>()!;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: BusyMaxModalEditorSurface(
              child: BusyMaxGroupedList(
                filled: true,
                children: [BusyMaxActionRow(title: 'Calendar', onTap: () {})],
              ),
            ),
          ),
        ),
      );

      final groupedMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(BusyMaxGroupedSurface),
          matching: find.byWidgetPredicate(
            (widget) => widget is Material && widget.color == colors.card,
          ),
        ),
      );
      final editorDialog = tester.widget<Dialog>(
        find.descendant(
          of: find.byType(BusyMaxModalEditorSurface),
          matching: find.byType(Dialog),
        ),
      );
      final cardOnEditor = Color.alphaBlend(
        colors.groupedSurface,
        colors.window,
      );
      expect(colors.groupedSurface.a, lessThan(1));
      expect(cardOnEditor.toARGB32(), colors.card.toARGB32());
      expect(colors.card.a, 1);
      expect(editorDialog.backgroundColor, colors.window);
      expect(editorDialog.surfaceTintColor, colors.window);
      expect(theme.dialogTheme.backgroundColor, colors.dialog);
      expect(colors.dialog, isNot(colors.window));
      expect(cardOnEditor, isNot(colors.window));
      expect(
        cardOnEditor.computeLuminance(),
        greaterThan(colors.window.computeLuminance()),
      );
      expect(groupedMaterial.color, colors.card);
      expect(groupedMaterial.color?.a, 1);
      expect(groupedMaterial.elevation, theme.cardTheme.elevation);
      expect(groupedMaterial.shadowColor, Colors.transparent);
      expect(
        _nativeCardDecoration(
          tester,
          find.byType(BusyMaxGroupedSurface),
        ).shadows,
        BusyMaxShadow.nativeCardShadows(theme.colorScheme.shadow),
      );
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('rows use the native $brightness boxed-row hover role', (
      tester,
    ) async {
      final baseTheme = BusyMaxYaruTheme.build(
        brightness: brightness,
        accentColor: const Color(0xFF3584E4),
      );
      const rowHover = Color(0x1A2A7FFF);
      final theme = baseTheme.copyWith(hoverColor: rowHover);

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

      expect(theme.hoverColor, rowHover);
      final expectedHover = brightness == Brightness.dark
          ? rowHover
          : rowHover.withValues(
              alpha: rowHover.a * BusyMaxAlpha.groupedRowLightHoverStrength,
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
      expect(actionTile.hoverColor, expectedHover);
      expect(switchTile.hoverColor, expectedHover);
      if (brightness == Brightness.light) {
        expect(expectedHover.a, lessThan(rowHover.a));
      } else {
        expect(expectedHover, rowHover);
      }
      expect(expectedHover.r, rowHover.r);
      expect(expectedHover.g, rowHover.g);
      expect(expectedHover.b, rowHover.b);
    });

    testWidgets('rows apply the native $brightness boxed-row hover strength', (
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
            body: BusyMaxActionRow(title: 'Calendar', onTap: () {}),
          ),
        ),
      );

      final tile = tester.widget<YaruListTile>(
        find.descendant(
          of: find.byType(BusyMaxActionRow),
          matching: find.byType(YaruListTile),
        ),
      );
      expect(theme.hoverColor.a, closeTo(10 / 255, 0.0001));
      final expectedAlpha = brightness == Brightness.dark
          ? theme.hoverColor.a
          : theme.hoverColor.a * BusyMaxAlpha.groupedRowLightHoverStrength;
      expect(tile.hoverColor?.a, closeTo(expectedAlpha, 0.0001));
      expect(
        tile.hoverColor?.a,
        closeTo(brightness == Brightness.dark ? 10 / 255 : 0.02, 0.001),
      );
      expect(tile.hoverColor, isNot(colors.controlHover));
    });
  }

  testWidgets('high-contrast grouped rows retain the full hover signal', (
    tester,
  ) async {
    final theme = buildBusyMaxTheme(
      brightness: Brightness.dark,
      accentColor: const Color(0xFF3584E4),
      highContrast: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: BusyMaxActionRow(title: 'Calendar', onTap: () {}),
        ),
      ),
    );

    final tile = tester.widget<YaruListTile>(
      find.descendant(
        of: find.byType(BusyMaxActionRow),
        matching: find.byType(YaruListTile),
      ),
    );
    expect(theme.colorScheme.isHighContrast, isTrue);
    expect(tile.hoverColor, theme.hoverColor);
  });

  testWidgets('grouped entry keeps interaction inside its field', (
    tester,
  ) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFF3584E4),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => YaruListTile.square(
              title: TextField(
                decoration: busyMaxGroupedTextFieldDecoration(
                  context,
                  labelText: 'Title',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final entryTile = tester.widget<YaruListTile>(find.byType(YaruListTile));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(entryTile.onTap, isNull);
    expect(entryTile.hoverColor, isNull);
    expect(field.decoration?.hoverColor, Colors.transparent);
  });

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

  testWidgets('combo row keeps a trailing action independently accessible', (
    tester,
  ) async {
    final selections = <String>[];
    var trailingActivations = 0;
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      _testApp(
        BusyMaxComboRow<String>(
          title: 'Reminder',
          values: const ['5 minutes', '10 minutes'],
          selected: '5 minutes',
          labelFor: (value) => value,
          onSelected: selections.add,
          trailingAction: BusyMaxHeaderIconButton(
            icon: const Icon(YaruIcons.window_close),
            tooltip: 'Remove reminder',
            onPressed: () => trailingActivations += 1,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Reminder'), findsOneWidget);
    final trailingButton = find.byType(IconButton);
    expect(tester.getSemantics(trailingButton).tooltip, 'Remove reminder');

    await tester.tap(trailingButton);
    await tester.pump();

    expect(trailingActivations, 1);
    expect(selections, isEmpty);
    expect(
      find
          .byWidgetPredicate((widget) => widget is PopupMenuItem<int>)
          .hitTestable(),
      findsNothing,
    );
    semanticsHandle.dispose();
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
    final trigger = find.descendant(of: combo, matching: _comboTriggerFinder());
    expect(trigger, findsOneWidget);

    await tester.tap(trigger, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      find
          .byWidgetPredicate((widget) => widget is PopupMenuItem<int>)
          .hitTestable(),
      findsNothing,
    );
    expect(find.byType(YaruRadio<int>).hitTestable(), findsNothing);
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
    expect(disabledSemantics.properties.onTap, isNull);
    expect(disabledSemantics.properties.value, 'Personal');
  });

  testWidgets('combo row delegates selection to the shared native menu path', (
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
      matching: _comboTriggerFinder(),
    );
    final trigger = tester.widget<YaruListTile>(triggerFinder);
    expect(trigger.onTap, isNotNull);
    expect(
      find.descendant(
        of: find.byType(BusyMaxComboRow<int>),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton && widget is! IconButton,
        ),
      ),
      findsNothing,
    );
    final restingSurface = tester.widget<Material>(
      find.descendant(of: triggerFinder, matching: find.byType(Material)).first,
    );
    expect(restingSurface.color, Colors.transparent);

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

    final expandedSemantics = tester.widget<Semantics>(
      find.descendant(
        of: find.byType(BusyMaxComboRow<int>),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Calendar' &&
              widget.properties.expanded == true,
        ),
      ),
    );
    expect(expandedSemantics.properties.onTap, isNotNull);
    expect(expandedSemantics.properties.value, 'Calendar 1');
    final firstChoice = _menuItemWithLabel('Calendar 1');
    final secondChoice = _menuItemWithLabel('Calendar 2');
    expect(firstChoice, findsOneWidget);
    expect(secondChoice, findsOneWidget);
    expect(
      tester.getRect(firstChoice).top,
      greaterThanOrEqualTo(arrowRect.bottom),
    );
    final visibleMenuItems = find
        .byWidgetPredicate((widget) => widget is PopupMenuItem<int>)
        .hitTestable();
    expect(visibleMenuItems, findsNWidgets(2));
    expect(find.byType(YaruFocusBorder), findsNothing);
    final radioItems = tester.widgetList<YaruRadio<int>>(
      find.byType(YaruRadio<int>),
    );
    expect(radioItems.map((item) => item.value), [0, 1]);
    expect(radioItems.map((item) => item.groupValue), everyElement(0));

    await tester.tap(secondChoice);
    await tester.pumpAndSettle();
    expect(selections, [2]);
  });

  testWidgets('combo row anchors its native menu to the trailing affordance', (
    tester,
  ) async {
    MethodCall? showCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, (call) async {
          if (call.method == 'show') {
            showCall = call;
            return null;
          }
          return true;
        });

    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 560,
          child: BusyMaxComboRow<String>(
            title: 'Repeat',
            values: const ['Never', 'Daily'],
            selected: 'Never',
            labelFor: (value) => value,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final combo = find.byType(BusyMaxComboRow<String>);
    final triggerFinder = find.descendant(
      of: combo,
      matching: _comboTriggerFinder(),
    );
    final triggerRect = tester.getRect(triggerFinder);
    final arrowRect = tester.getRect(
      find.descendant(
        of: triggerFinder,
        matching: find.byIcon(YaruIcons.pan_down),
      ),
    );

    await tester.tap(triggerFinder);
    await tester.pumpAndSettle();

    final arguments = showCall!.arguments! as Map<Object?, Object?>;
    final rawAnchor = arguments['anchor']! as Map<Object?, Object?>;
    final anchor = Rect.fromLTWH(
      (rawAnchor['x']! as num).toDouble(),
      (rawAnchor['y']! as num).toDouble(),
      (rawAnchor['width']! as num).toDouble(),
      (rawAnchor['height']! as num).toDouble(),
    );
    expect(anchor.left, closeTo(arrowRect.left, 0.01));
    expect(anchor.right, closeTo(arrowRect.right, 0.01));
    expect(anchor.top, closeTo(arrowRect.top, 0.01));
    expect(anchor.bottom, closeTo(arrowRect.bottom, 0.01));
    expect(anchor.left, greaterThan(triggerRect.left));
    expect(anchor.width, lessThan(triggerRect.width));
  });

  testWidgets('disposing a combo dismisses only its native menu session', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    final nativeSelection = Completer<int?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeMenuChannel, (call) async {
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
      _testApp(
        BusyMaxComboRow<String>(
          title: 'Calendar',
          values: const ['Personal', 'Work'],
          selected: 'Personal',
          labelFor: (value) => value,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.tap(_comboTriggerFinder());
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    final showArguments =
        calls.singleWhere((call) => call.method == 'show').arguments!
            as Map<Object?, Object?>;
    final dismissArguments =
        calls.singleWhere((call) => call.method == 'dismiss').arguments!
            as Map<Object?, Object?>;
    expect(dismissArguments['sessionId'], showArguments['sessionId']);

    nativeSelection.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
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

    await tester.tap(_comboTriggerFinder());
    await tester.pumpAndSettle();
    await tester.tap(_menuItemWithLabel('Select a category'));
    await tester.pumpAndSettle();

    expect(selections, [isNull]);
  });

  testWidgets('combo trigger keeps its layout width with long menu content', (
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

    final trigger = _comboTriggerFinder();
    expect(tester.getSize(trigger).width, greaterThan(selectorWidth));
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    expect(
      find
          .byWidgetPredicate((widget) => widget is PopupMenuItem<int>)
          .hitTestable(),
      findsNWidgets(2),
    );
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
      matching: _comboTriggerFinder(),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      find
          .byWidgetPredicate((widget) => widget is PopupMenuItem<int>)
          .hitTestable(),
      findsNWidgets(2),
    );
    expect(
      tester.getRect(find.text('Personal').last).top,
      greaterThanOrEqualTo(tester.getRect(triggerFinder).bottom),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selections, ['Work']);
    expect(
      find
          .byWidgetPredicate((widget) => widget is PopupMenuItem<int>)
          .hitTestable(),
      findsNothing,
    );
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

    expect(_comboTriggerFinder(), findsOneWidget);
    expect(
      tester.getSize(_comboTriggerFinder()).width,
      BusyMaxSizes.comboWidth + BusyMaxSpacing.md * 2,
    );
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
    testWidgets(
      'editor sheets, alerts, and popovers use native $brightness roles',
      (tester) async {
        final theme = BusyMaxYaruTheme.build(
          brightness: brightness,
          accentColor: const Color(0xFF3584E4),
        );
        final colors = theme.extension<BusyMaxSurfaceColors>()!;
        final expectedDialog = switch (brightness) {
          Brightness.light => const Color(0xFFFAFAFA),
          Brightness.dark => const Color(0xFF3E3E3E),
        };
        final expectedPopover = switch (brightness) {
          Brightness.light => const Color(0xFFFAFAFA),
          Brightness.dark => const Color(0xFF3E3E3E),
        };

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
              (widget) => widget is Material && widget.color == colors.window,
            ),
          ),
        );
        final modalDialog = tester.widget<Dialog>(
          find.descendant(
            of: find.byType(BusyMaxModalEditorSurface),
            matching: find.byType(Dialog),
          ),
        );
        expect(colors.dialog, expectedDialog);
        expect(colors.popover, expectedPopover);
        expect(modalDialog.backgroundColor, colors.window);
        expect(modalDialog.surfaceTintColor, colors.window);
        expect(modalDialog.elevation, isNull);
        expect(modalDialog.shadowColor, isNull);
        expect(modalDialog.shape, isNull);
        expect(modalMaterial.shape, theme.dialogTheme.shape);
        expect(modalMaterial.shadowColor, theme.dialogTheme.shadowColor);
        expect(modalMaterial.elevation, greaterThan(0));

        final popoverDecorationFinder = find.descendant(
          of: find.byType(BusyMaxPopoverSurface),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is ShapeDecoration &&
                (widget.decoration as ShapeDecoration).color ==
                    expectedPopover &&
                ((widget.decoration as ShapeDecoration).shadows?.isNotEmpty ??
                    false),
          ),
        );
        expect(popoverDecorationFinder, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BusyMaxPopoverSurface),
            matching: find.byType(PhysicalShape),
          ),
          findsNothing,
        );
        final outlineDecorationFinder = find.descendant(
          of: find.byType(BusyMaxPopoverSurface),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.position == DecorationPosition.foreground &&
                widget.decoration is ShapeDecoration,
          ),
        );
        expect(outlineDecorationFinder, findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: AlertDialog(
                title: Text('Discard changes?'),
                content: Text('Unsaved changes will be lost.'),
              ),
            ),
          ),
        );

        final alertDialog = tester.widget<AlertDialog>(
          find.byType(AlertDialog),
        );
        final alertMaterial = tester.widget<Material>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byWidgetPredicate(
              (widget) => widget is Material && widget.color == expectedDialog,
            ),
          ),
        );
        expect(alertDialog.backgroundColor, isNull);
        expect(alertDialog.surfaceTintColor, isNull);
        expect(theme.dialogTheme.backgroundColor, expectedDialog);
        expect(alertMaterial.color, expectedDialog);
        expect(alertMaterial.shape, theme.dialogTheme.shape);
        expect(alertMaterial.shadowColor, theme.dialogTheme.shadowColor);
        expect(alertMaterial.elevation, modalMaterial.elevation);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('popover perimeter remains outlined in high contrast', (
    tester,
  ) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.dark,
      accentColor: const Color(0xFF3584E4),
      highContrast: true,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: BusyMaxPopoverSurface(
            color: colors.popover,
            child: const SizedBox(width: 180, height: 80),
          ),
        ),
      ),
    );

    final outlineFinder = find.descendant(
      of: find.byType(BusyMaxPopoverSurface),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground &&
            widget.decoration is ShapeDecoration,
      ),
    );
    expect(outlineFinder, findsOneWidget);
    final outlineDecoration =
        tester.widget<DecoratedBox>(outlineFinder).decoration
            as ShapeDecoration;
    final outlineShape = outlineDecoration.shape as OutlinedBorder;
    expect(outlineShape.side.color, colors.floatingBorder);
    expect(outlineShape.side.width, BusyMaxStroke.outline);
  });

  testWidgets('combo row keeps its value inline for large text', (
    tester,
  ) async {
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
    final valueRect = tester.getRect(find.text('Personal calendar'));
    expect(valueRect.top, lessThan(titleRect.bottom));
    expect(tester.getSize(_comboTriggerFinder()).width, 760);
    expect(tester.takeException(), isNull);
  });

  testWidgets('time mode delegates full-width neutral selection to Yaru tabs', (
    tester,
  ) async {
    final changes = <bool>[];
    var allDay = true;
    await tester.pumpWidget(
      _timeModeTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            return BusyMaxTimeModeRow(
              allDay: allDay,
              onChanged: (value) {
                changes.add(value);
                setState(() => allDay = value);
              },
            );
          },
        ),
      ),
    );

    expect(find.text('Time'), findsNothing);
    expect(find.text('Use dates only or set specific times.'), findsNothing);
    expect(find.byType(YaruListTile), findsNothing);
    expect(find.byType(ToggleButtons), findsNothing);
    expect(find.byType(BusyMaxModeSwitcher<bool>), findsOneWidget);

    final control = tester.widget<YaruTabBar>(find.byType(YaruTabBar));
    expect(control.height, isNull);
    expect(control.labelColor, isNull);
    expect(control.unselectedLabelColor, isNull);
    expect(control.tabController?.index, 0);
    expect(
      Theme.of(tester.element(find.byType(YaruTabBar))).platform,
      TargetPlatform.linux,
    );

    final rowRect = tester.getRect(find.byType(BusyMaxTimeModeRow));
    final controlRect = tester.getRect(find.byType(YaruTabBar));
    expect(controlRect.width, rowRect.width);
    final optionWidths = [
      for (final label in ['All day', 'Time slot'])
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(InkWell),
                  )
                  .first,
            )
            .width,
    ];
    expect(optionWidths, hasLength(2));
    expect(optionWidths.first, optionWidths.last);

    await tester.tap(find.text('All day'));
    await tester.pump();
    expect(changes, isEmpty);

    await tester.tap(find.text('Time slot'));
    await tester.pump();
    expect(changes, [isFalse]);
    expect(control.tabController?.index, 1);
  });

  testWidgets('time mode remains full width when its section is narrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timeModeTestApp(
        const Center(
          child: SizedBox(
            width: 420,
            child: BusyMaxTimeModeRow(allDay: true, onChanged: _ignoreBool),
          ),
        ),
      ),
    );

    final rowRect = tester.getRect(find.byType(BusyMaxTimeModeRow));
    final controlRect = tester.getRect(find.byType(YaruTabBar));
    expect(controlRect.width, rowRect.width);
    expect(controlRect.width, 420);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mode switcher follows external selection changes', (
    tester,
  ) async {
    Widget switcher(bool allDay) {
      return BusyMaxTimeModeRow(allDay: allDay, onChanged: _ignoreBool);
    }

    await tester.pumpWidget(_timeModeTestApp(switcher(true)));
    expect(
      tester.widget<YaruTabBar>(find.byType(YaruTabBar)).tabController?.index,
      0,
    );

    await tester.pumpWidget(_timeModeTestApp(switcher(false)));
    await tester.pump();

    expect(
      tester.widget<YaruTabBar>(find.byType(YaruTabBar)).tabController?.index,
      1,
    );
  });

  testWidgets('mode switcher restores a rejected external selection', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      _timeModeTestApp(
        BusyMaxTimeModeRow(allDay: true, onChanged: changes.add),
      ),
    );

    await tester.tap(find.text('Time slot'));
    await tester.pump();

    expect(changes, [isFalse]);
    expect(
      tester.widget<YaruTabBar>(find.byType(YaruTabBar)).tabController?.index,
      0,
    );
  });

  testWidgets('mode switcher safely accepts a different choice count', (
    tester,
  ) async {
    Widget switcher(List<int> values) {
      return BusyMaxModeSwitcher<int>(
        values: values,
        selected: 1,
        labelFor: (value) => 'Mode $value',
        onSelected: (_) {},
      );
    }

    await tester.pumpWidget(_timeModeTestApp(switcher([1, 2])));
    await tester.pumpWidget(_timeModeTestApp(switcher([1, 2, 3])));

    final control = tester.widget<YaruTabBar>(find.byType(YaruTabBar));
    expect(control.tabs, hasLength(3));
    expect(control.tabController?.length, 3);
    expect(tester.takeException(), isNull);
  });

  test('mode switcher snapshots and validates domain choices', () {
    final values = [1, 2];
    final switcher = BusyMaxModeSwitcher<int>(
      values: values,
      selected: 1,
      labelFor: (value) => '$value',
      onSelected: (_) {},
    );
    values.add(3);

    expect(switcher.values, [1, 2]);
    expect(
      () => BusyMaxModeSwitcher<int>(
        values: const [1],
        selected: 1,
        labelFor: (value) => '$value',
        onSelected: (_) {},
      ),
      throwsArgumentError,
    );
    expect(
      () => BusyMaxModeSwitcher<int>(
        values: const [1, 1],
        selected: 1,
        labelFor: (value) => '$value',
        onSelected: (_) {},
      ),
      throwsArgumentError,
    );
    expect(
      () => BusyMaxModeSwitcher<int>(
        values: const [1, 2],
        selected: 3,
        labelFor: (value) => '$value',
        onSelected: (_) {},
      ),
      throwsArgumentError,
    );
  });

  testWidgets('mode switcher supports desktop keyboard selection', (
    tester,
  ) async {
    final changes = <bool>[];
    var allDay = true;
    await tester.pumpWidget(
      _timeModeTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            return BusyMaxTimeModeRow(
              allDay: allDay,
              onChanged: (value) {
                changes.add(value);
                setState(() => allDay = value);
              },
            );
          },
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(changes, [isFalse]);
  });

  testWidgets('mode switcher announces one selected localized mode', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var allDay = true;
    await tester.pumpWidget(
      _timeModeTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            return BusyMaxTimeModeRow(
              allDay: allDay,
              onChanged: (value) => setState(() => allDay = value),
            );
          },
        ),
      ),
    );

    var allDayNode = tester.getSemantics(find.text('All day'));
    var timeSlotNode = tester.getSemantics(find.text('Time slot'));
    expect(allDayNode.role, ui.SemanticsRole.tab);
    expect(timeSlotNode.role, ui.SemanticsRole.tab);
    expect(allDayNode.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(timeSlotNode.flagsCollection.isSelected, ui.Tristate.isFalse);

    await tester.tap(find.text('Time slot'));
    await tester.pump();

    allDayNode = tester.getSemantics(find.text('All day'));
    timeSlotNode = tester.getSemantics(find.text('Time slot'));
    expect(allDayNode.flagsCollection.isSelected, ui.Tristate.isFalse);
    expect(timeSlotNode.flagsCollection.isSelected, ui.Tristate.isTrue);
    semantics.dispose();
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

  testWidgets('modal editor shows Yaru undershoot below its fixed header', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        SizedBox(
          height: 260,
          child: BusyMaxModalEditorScaffold(
            title: 'Edit event',
            cancelLabel: 'Cancel',
            saveLabel: 'Save',
            onCancel: () {},
            onSave: null,
            children: [
              for (var index = 0; index < 8; index++)
                SizedBox(height: 64, child: Text('Editor row $index')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final undershoot = find.byType(YaruScrollViewUndershoot);
    final shadow = find.descendant(
      of: undershoot,
      matching: find.byType(AnimatedOpacity),
    );
    final scrollView = find.descendant(
      of: undershoot,
      matching: find.byType(SingleChildScrollView),
    );
    final titleTop = tester.getTopLeft(find.text('Edit event')).dy;

    expect(undershoot, findsOneWidget);
    expect(shadow, findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(shadow).opacity, 0);

    await tester.drag(scrollView, const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(tester.widget<AnimatedOpacity>(shadow).opacity, 1);
    expect(tester.getTopLeft(find.text('Edit event')).dy, titleTop);
  });

  testWidgets('dialog actions wrap at narrow localized text widths', (
    tester,
  ) async {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFFE95420),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: SizedBox(
                width: 320,
                height: 520,
                child: Builder(
                  builder: (context) => BusyMaxDialogShell(
                    title: 'Unsaved changes',
                    actions: [
                      BusyMaxPushButton.standard(
                        onPressed: () {},
                        child: const Text('Keep editing'),
                      ),
                      BusyMaxPushButton.destructive(
                        context: context,
                        onPressed: () {},
                        child: const Text('Discard changes'),
                      ),
                      BusyMaxPushButton.suggested(
                        onPressed: () {},
                        child: const Text('Save changes'),
                      ),
                    ],
                    children: const [Text('Choose how to continue.')],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(OverflowBar), findsOneWidget);
    final actionRows = {
      for (final label in ['Keep editing', 'Discard changes', 'Save changes'])
        tester.getCenter(find.text(label)).dy,
    };
    expect(actionRows.length, greaterThan(1));
  });
}

ShapeDecoration _nativeCardDecoration(WidgetTester tester, Finder surface) {
  final decoratedBox = tester.widget<DecoratedBox>(
    find.descendant(
      of: surface,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is ShapeDecoration &&
            ((widget.decoration as ShapeDecoration).shadows?.isNotEmpty ??
                false),
      ),
    ),
  );
  return decoratedBox.decoration as ShapeDecoration;
}

void _ignoreBool(bool value) {}

Finder _comboTriggerFinder() {
  return find.byWidgetPredicate(
    (widget) => widget is YaruListTile && widget.focusNode != null,
  );
}

Finder _menuItemWithLabel(String label) {
  return find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<int>,
        ),
      )
      .hitTestable();
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

Widget _timeModeTestApp(Widget child) {
  return localizedTestApp(
    child: Theme(
      data: BusyMaxYaruTheme.build(
        brightness: Brightness.light,
        accentColor: const Color(0xFF3584E4),
      ).copyWith(platform: TargetPlatform.linux),
      child: Scaffold(body: child),
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
