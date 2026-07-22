import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_theme/system_theme.dart';
import 'package:yaru/theme.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/app/app_theme.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/l10n/l10n.dart';
import 'package:busymax/src/platform/busymax_tray_service.dart';
import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:busymax/src/platform/linux_window_service.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';

import '../test_localized_app.dart';

void main() {
  test('builds with system accent and tokenized control surfaces', () {
    final light = _buildBusyMaxTheme(brightness: Brightness.light);
    final dark = _buildBusyMaxTheme(brightness: Brightness.dark);
    final alternate = _buildBusyMaxTheme(
      brightness: Brightness.light,
      accentColor: _alternateTestAccentColor,
    );
    final selected = {WidgetState.selected};

    final lightSurfaceColors = light.extension<BusyMaxSurfaceColors>()!;

    expect(light.colorScheme.primary, _testAccentColor);
    expect(dark.colorScheme.primary, _testAccentColor);
    expect(light.primaryColor, _testAccentColor);
    expect(light.visualDensity, VisualDensity.compact);
    expect(light.scaffoldBackgroundColor, isNot(_testAccentColor));
    expect(light.colorScheme.surface, alternate.colorScheme.surface);
    expect(
      light.colorScheme.surfaceContainerHighest,
      alternate.colorScheme.surfaceContainerHighest,
    );
    expect(light.colorScheme.secondary, _testAccentColor);
    expect(alternate.colorScheme.secondary, _alternateTestAccentColor);
    expect(light.switchTheme.trackColor?.resolve(selected), _testAccentColor);
    expect(light.radioTheme.fillColor?.resolve(selected), _testAccentColor);
    expect(light.checkboxTheme.fillColor?.resolve(selected), _testAccentColor);
    expect(
      light.colorScheme.primaryContainer,
      isNot(lightSurfaceColors.controlActive),
    );
    expect(
      light.listTileTheme.selectedTileColor,
      light.colorScheme.primaryContainer,
    );
    expect(
      light.textButtonTheme.style?.foregroundColor?.resolve({}),
      _testAccentColor,
    );
    expect(
      light.filledButtonTheme.style?.backgroundColor?.resolve({}),
      _testAccentColor,
    );
    expect(
      light.segmentedButtonTheme.style?.foregroundColor?.resolve(selected),
      _testAccentColor,
    );
    expect(
      light.segmentedButtonTheme.style?.side?.resolve(selected)?.color,
      _testAccentColor,
    );
    expect(
      light.segmentedButtonTheme.style?.backgroundColor?.resolve(selected),
      light.colorScheme.primaryContainer,
    );
    expect(light.floatingActionButtonTheme.backgroundColor, _testAccentColor);
    expect(light.progressIndicatorTheme.color, _testAccentColor);
    expect(light.textSelectionTheme.cursorColor, _testAccentColor);

    final focusedBorder =
        light.inputDecorationTheme.focusedBorder as OutlineInputBorder;
    expect(focusedBorder.borderSide.color, _testAccentColor);

    final outlinedShape =
        light.outlinedButtonTheme.style?.shape?.resolve({})
            as RoundedRectangleBorder;
    expect(outlinedShape.borderRadius, BorderRadius.circular(12));

    final pushButtonStyle = busyMaxPushButtonStyle(null);
    expect(
      pushButtonStyle.minimumSize?.resolve({}),
      BusyMaxSizes.pushButtonSize,
    );
    expect(
      pushButtonStyle.fixedSize?.resolve({}),
      const Size.fromHeight(BusyMaxSizes.pushButtonHeight),
    );
    expect(
      pushButtonStyle.padding?.resolve({}),
      const EdgeInsets.symmetric(horizontal: 12),
    );

    expect(light.outlinedButtonTheme.style?.side?.resolve({}), BorderSide.none);
    expect(
      light.outlinedButtonTheme.style?.side?.resolve({WidgetState.disabled}),
      BorderSide.none,
    );
    expect(
      light.outlinedButtonTheme.style?.side?.resolve({WidgetState.focused}),
      BorderSide(color: _testAccentColor),
    );
  });

  test('BusyMax Yaru theme exposes semantic fallback surfaces', () {
    final light = _buildBusyMaxTheme(brightness: Brightness.light);
    final dark = _buildBusyMaxTheme(brightness: Brightness.dark);

    final lightColors = light.extension<BusyMaxSurfaceColors>()!;
    final darkColors = dark.extension<BusyMaxSurfaceColors>()!;

    expect(lightColors.window, const Color(0xFFFAFAFB));
    expect(lightColors.view, const Color(0xFFFFFFFF));
    expect(lightColors.sidebar, const Color(0xFFEBEBED));
    expect(lightColors.card, const Color(0xFFFFFFFF));
    expect(lightColors.groupedSurface, const Color(0xFFFFFFFF));
    expect(lightColors.dialog, const Color(0xFFFAFAFB));
    expect(lightColors.popover, const Color(0xFFFFFFFF));
    expect(darkColors.window, const Color(0xFF1D1D20));
    expect(darkColors.view, const Color(0xFF1D1D20));
    expect(darkColors.sidebar, const Color(0xFF2E2E32));
    expect(darkColors.card, const Color(0xFF222226));
    expect(darkColors.groupedSurface, const Color(0xFF383838));
    expect(darkColors.dialog, const Color(0xFF222226));
    expect(darkColors.popover, const Color(0xFF383838));
    expect(darkColors.view, isNot(const Color(0xFF3E3E3E)));
    expect(light.scaffoldBackgroundColor, lightColors.window);
    expect(dark.scaffoldBackgroundColor, darkColors.window);
    expect(light.cardColor, lightColors.card);
    expect(dark.cardColor, darkColors.card);
    expect(light.dialogTheme.backgroundColor, lightColors.dialog);
    expect(dark.dialogTheme.backgroundColor, darkColors.dialog);
    expect(light.popupMenuTheme.color, lightColors.popover);
    expect(dark.popupMenuTheme.color, darkColors.popover);
    expect(light.tooltipTheme.decoration, isA<BoxDecoration>());
    expect(dark.tooltipTheme.decoration, isA<BoxDecoration>());
    expect(
      (light.tooltipTheme.decoration! as BoxDecoration).color,
      lightColors.popover,
    );
    expect((light.tooltipTheme.decoration! as BoxDecoration).border, isNull);
    expect(
      (light.tooltipTheme.decoration! as BoxDecoration).boxShadow,
      BusyMaxShadow.tooltipShadows(lightColors.shade),
    );
    expect(
      (dark.tooltipTheme.decoration! as BoxDecoration).color,
      darkColors.popover,
    );
    expect((dark.tooltipTheme.decoration! as BoxDecoration).border, isNull);
    expect(
      (dark.tooltipTheme.decoration! as BoxDecoration).boxShadow,
      BusyMaxShadow.tooltipShadows(darkColors.shade),
    );
    expect(light.tooltipTheme.textStyle?.color, lightColors.foreground);
    expect(dark.tooltipTheme.textStyle?.color, darkColors.foreground);
    expect(
      light.tooltipTheme.textStyle?.fontSize,
      light.textTheme.bodyMedium?.fontSize,
    );
    expect(
      dark.tooltipTheme.textStyle?.fontSize,
      dark.textTheme.bodyMedium?.fontSize,
    );
  });

  test('BusyMaxSurfaceColors copyWith preserves and overrides fields', () {
    final base = _buildBusyMaxTheme(
      brightness: Brightness.dark,
    ).extension<BusyMaxSurfaceColors>()!;

    final updated = base.copyWith(
      window: const Color(0xFF010203),
      sidebar: const Color(0xFF040506),
      groupedSurface: const Color(0xFF060708),
      disabledForeground: const Color(0xFF070809),
      shade: const Color(0xFF0A0B0C),
    );

    expect(updated.window, const Color(0xFF010203));
    expect(updated.sidebar, const Color(0xFF040506));
    expect(updated.groupedSurface, const Color(0xFF060708));
    expect(updated.disabledForeground, const Color(0xFF070809));
    expect(updated.shade, const Color(0xFF0A0B0C));
    expect(updated.view, base.view);
    expect(updated.popover, base.popover);
  });

  test('BusyMaxSurfaceColors lerp blends semantic fields', () {
    final start = _buildBusyMaxTheme(
      brightness: Brightness.light,
    ).extension<BusyMaxSurfaceColors>()!;
    final end = _buildBusyMaxTheme(
      brightness: Brightness.dark,
    ).extension<BusyMaxSurfaceColors>()!;

    final midpoint = start.lerp(end, 0.5);

    expect(midpoint.window, Color.lerp(start.window, end.window, 0.5));
    expect(midpoint.sidebar, Color.lerp(start.sidebar, end.sidebar, 0.5));
    expect(
      midpoint.groupedSurface,
      Color.lerp(start.groupedSurface, end.groupedSurface, 0.5),
    );
    expect(midpoint.dialog, Color.lerp(start.dialog, end.dialog, 0.5));
    expect(
      midpoint.disabledForeground,
      Color.lerp(start.disabledForeground, end.disabledForeground, 0.5),
    );
    expect(midpoint.shade, Color.lerp(start.shade, end.shade, 0.5));
  });

  test(
    'BusyMax theme preserves Yaru typography when no GTK font is provided',
    () {
      final base = createYaruLightTheme(
        primaryColor: BusyMaxLinuxPalette.light4,
      );
      final theme = _buildBusyMaxTheme(brightness: Brightness.light);

      _expectTextThemeMetrics(
        actual: theme.textTheme,
        base: base.textTheme,
        expectedFamilyForAll: null,
      );
    },
  );

  test(
    'BusyMax theme applies GTK family without changing Yaru metrics at 11',
    () {
      const gtkFamily = 'GTK Test Sans';
      final base = createYaruLightTheme(
        primaryColor: BusyMaxLinuxPalette.light4,
      );
      final theme = _buildBusyMaxTheme(
        brightness: Brightness.light,
        gtkFontFamily: gtkFamily,
        gtkFontSize: 11,
      );

      _expectTextThemeMetrics(
        actual: theme.textTheme,
        base: base.textTheme,
        expectedFamilyForAll: gtkFamily,
      );
      for (final style in _textStyles(theme.textTheme)) {
        expect(style.fontFamily, isNot(contains('packages/')));
      }
    },
  );

  test('BusyMax theme scales Yaru font sizes from GTK size', () {
    const gtkFamily = 'GTK Test Sans';
    const scale = 12 / 11;
    final base = createYaruLightTheme(primaryColor: BusyMaxLinuxPalette.light4);
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkFontFamily: gtkFamily,
      gtkFontSize: 12,
    );

    _expectTextThemeMetrics(
      actual: theme.textTheme,
      base: base.textTheme,
      expectedFamilyForAll: gtkFamily,
      expectedScale: scale,
    );
  });

  test('BusyMax theme ignores invalid GTK font size', () {
    const gtkFamily = 'GTK Test Sans';
    final base = createYaruLightTheme(primaryColor: BusyMaxLinuxPalette.light4);
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkFontFamily: gtkFamily,
      gtkFontSize: double.nan,
    );

    _expectTextThemeMetrics(
      actual: theme.textTheme,
      base: base.textTheme,
      expectedFamilyForAll: gtkFamily,
    );
  });

  test('BusyMax component themes use final GTK-adjusted typography', () {
    const gtkFamily = 'GTK Test Sans';
    const scale = 12 / 11;
    final base = createYaruLightTheme(primaryColor: BusyMaxLinuxPalette.light4);
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkFontFamily: gtkFamily,
      gtkFontSize: 12,
    );
    final textTheme = theme.textTheme;
    final buttonStates = <WidgetState>{};

    _expectComponentStyleUsesTypography(
      theme.appBarTheme.titleTextStyle,
      baseStyle: base.appBarTheme.titleTextStyle,
      fallback: textTheme.titleMedium,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.popupMenuTheme.textStyle,
      baseStyle: base.popupMenuTheme.textStyle,
      fallback: textTheme.bodyMedium,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.dialogTheme.titleTextStyle,
      baseStyle: base.dialogTheme.titleTextStyle,
      fallback: textTheme.titleLarge,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.dialogTheme.contentTextStyle,
      baseStyle: base.dialogTheme.contentTextStyle,
      fallback: textTheme.bodyMedium,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.listTileTheme.titleTextStyle,
      baseStyle: base.listTileTheme.titleTextStyle,
      fallback: textTheme.bodyMedium,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.listTileTheme.subtitleTextStyle,
      baseStyle: base.listTileTheme.subtitleTextStyle,
      fallback: textTheme.bodySmall,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.inputDecorationTheme.labelStyle,
      baseStyle: base.inputDecorationTheme.labelStyle,
      fallback: textTheme.bodyMedium,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.inputDecorationTheme.hintStyle,
      baseStyle: base.inputDecorationTheme.hintStyle,
      fallback: textTheme.bodyMedium,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.inputDecorationTheme.helperStyle,
      baseStyle: base.inputDecorationTheme.helperStyle,
      fallback: textTheme.bodySmall,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.inputDecorationTheme.errorStyle,
      baseStyle: base.inputDecorationTheme.errorStyle,
      fallback: textTheme.bodySmall,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.tooltipTheme.textStyle,
      baseStyle: null,
      fallback: textTheme.bodyMedium,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.snackBarTheme.contentTextStyle,
      baseStyle: base.snackBarTheme.contentTextStyle,
      fallback: textTheme.bodyMedium,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.dataTableTheme.headingTextStyle,
      baseStyle: base.dataTableTheme.headingTextStyle,
      fallback: textTheme.labelLarge,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.dataTableTheme.dataTextStyle,
      baseStyle: base.dataTableTheme.dataTextStyle,
      fallback: textTheme.bodyMedium,
      family: gtkFamily,
      scale: scale,
    );

    for (final pair in [
      (theme.outlinedButtonTheme.style, base.outlinedButtonTheme.style),
      (theme.filledButtonTheme.style, base.filledButtonTheme.style),
      (theme.elevatedButtonTheme.style, base.elevatedButtonTheme.style),
      (theme.textButtonTheme.style, base.textButtonTheme.style),
      (theme.segmentedButtonTheme.style, base.segmentedButtonTheme.style),
    ]) {
      _expectComponentStyleUsesTypography(
        pair.$1?.textStyle?.resolve(buttonStates),
        baseStyle: pair.$2?.textStyle?.resolve(buttonStates),
        fallback: textTheme.labelLarge,
        family: gtkFamily,
        scale: scale,
      );
    }

    _expectComponentStyleUsesTypography(
      theme.menuButtonTheme.style?.textStyle?.resolve(buttonStates),
      baseStyle: base.menuButtonTheme.style?.textStyle?.resolve(buttonStates),
      fallback: textTheme.labelLarge,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.dropdownMenuTheme.textStyle,
      baseStyle: base.dropdownMenuTheme.textStyle,
      fallback: textTheme.bodyMedium,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.tabBarTheme.labelStyle,
      baseStyle: base.tabBarTheme.labelStyle,
      fallback: textTheme.labelLarge,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.navigationRailTheme.selectedLabelTextStyle,
      baseStyle: base.navigationRailTheme.selectedLabelTextStyle,
      fallback: textTheme.labelMedium,
      family: gtkFamily,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.navigationBarTheme.labelTextStyle?.resolve(buttonStates),
      baseStyle: base.navigationBarTheme.labelTextStyle?.resolve(buttonStates),
      fallback: textTheme.labelMedium,
      family: gtkFamily,
      scale: scale,
    );
  });

  test('BusyMax theme applies matching GTK runtime colors', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF202020),
      view: Color(0xFF242424),
      sidebar: Color(0xFF303030),
      headerbar: Color(0xFF282828),
      headerbarFlat: Color(0xFF242424),
      card: Color(0xFF2C2C2C),
      dialog: Color(0xFF343434),
      popover: Color(0xFF383838),
      control: Color(0x1AFFFFFF),
      controlHover: Color(0x2EFFFFFF),
      controlActive: Color(0x33FFFFFF),
      activeToggle: Color(0x44FFFFFF),
      foreground: Color(0xFFEFEFEF),
      mutedForeground: Color(0xFFBDBDBD),
      disabledForeground: Color(0x61FFFFFF),
      disabledControl: Color(0x0FFFFFFF),
      border: Color(0x66000000),
      subtleBorder: Color(0x1AFFFFFF),
      sidebarBorder: Color(0x33000000),
      shade: Color(0x55000000),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );

    expect(theme.scaffoldBackgroundColor, gtkColors.window);
    expect(theme.colorScheme.surface, gtkColors.view);
    expect(theme.colorScheme.surfaceContainer, gtkColors.card);
    expect(theme.colorScheme.surfaceContainerHigh, gtkColors.control);
    expect(theme.colorScheme.surfaceContainerHighest, gtkColors.controlHover);
    expect(theme.colorScheme.onSurface, gtkColors.foreground);
    expect(theme.colorScheme.onSurfaceVariant, gtkColors.mutedForeground);
    expect(theme.dialogTheme.backgroundColor, gtkColors.dialog);
    expect(theme.popupMenuTheme.color, gtkColors.popover);
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    expect(colors.sidebar, gtkColors.sidebar);
    expect(colors.groupedSurface, gtkColors.popover);
  });

  test('BusyMax theme ignores light GTK runtime shade samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      window: Color(0xFFFFFFFF),
      view: Color(0xFFFFFFFF),
      sidebar: Color(0xFFF2F2F2),
      shade: Color(0x88FFFFFF),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    expect(colors.shade, busyMaxFallbackSurfaceColors(Brightness.light).shade);
    expect(colors.groupedSurface, gtkColors.view);
    expect(theme.shadowColor, theme.colorScheme.shadow);
    expect(theme.popupMenuTheme.shadowColor, theme.colorScheme.shadow);
    expect(theme.popupMenuTheme.shadowColor, isNot(colors.shade));
  });

  test('BusyMax theme ignores too-dark GTK popover samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF242424),
      view: Color(0xFF242424),
      sidebar: Color(0xFF303030),
      popover: Color(0xFF303030),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );

    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    expect(theme.popupMenuTheme.color, const Color(0xFF383838));
    expect(colors.popover, const Color(0xFF383838));
    expect(colors.groupedSurface, const Color(0xFF383838));
  });

  test('BusyMax theme ignores blue purple GTK dark surface samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF241F31),
      view: Color(0xFF241F31),
      sidebar: Color(0xFF3D3846),
      headerbar: Color(0xFF241F31),
      card: Color(0xFF3D3846),
      dialog: Color(0xFF241F31),
      popover: Color(0xFF3D3846),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    expect(theme.scaffoldBackgroundColor, const Color(0xFF1D1D20));
    expect(theme.colorScheme.surface, const Color(0xFF1D1D20));
    expect(theme.colorScheme.surfaceContainer, const Color(0xFF222226));
    expect(
      theme.colorScheme.surfaceContainerHigh,
      const Color.fromRGBO(255, 255, 255, 0.10),
    );
    expect(
      theme.colorScheme.surfaceContainerHighest,
      const Color.fromRGBO(255, 255, 255, 0.14),
    );
    expect(theme.dialogTheme.backgroundColor, const Color(0xFF222226));
    expect(colors.sidebar, isNot(const Color(0xFF3D3846)));
    expect(colors.control, const Color.fromRGBO(255, 255, 255, 0.10));
    expect(colors.controlHover, const Color.fromRGBO(255, 255, 255, 0.14));
    expect(colors.popover, const Color(0xFF383838));
    expect(colors.groupedSurface, const Color(0xFF383838));
  });

  test('BusyMax theme ignores GTK accent control samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      control: Color(0x22004A99),
      controlHover: Color(0x33005BBB),
      controlActive: Color(0x44006DDD),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    final fallback = busyMaxFallbackSurfaceColors(Brightness.dark);

    expect(colors.control, fallback.control);
    expect(colors.controlHover, fallback.controlHover);
    expect(colors.controlActive, fallback.controlActive);
    expect(theme.colorScheme.surfaceContainerHigh, fallback.control);
    expect(theme.colorScheme.surfaceContainerHighest, fallback.controlHover);
  });

  test('BusyMax theme derives sidebar from collapsed GTK colors', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF3E3E3E),
      view: Color(0xFF3E3E3E),
      sidebar: Color(0xFF3E3E3E),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );

    expect(theme.scaffoldBackgroundColor, gtkColors.window);
    expect(theme.colorScheme.surface, gtkColors.view);
    expect(
      theme.extension<BusyMaxSurfaceColors>()?.sidebar,
      isNot(const Color(0xFF2E2E32)),
    );
    expect(
      theme.extension<BusyMaxSurfaceColors>()?.sidebar,
      isNot(theme.scaffoldBackgroundColor),
    );
  });

  test('BusyMax theme uses native headerbar as sidebar candidate', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF242424),
      view: Color(0xFF242424),
      sidebar: Color(0xFF242424),
      headerbar: Color(0xFF303030),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );

    expect(theme.colorScheme.surface, gtkColors.view);
    expect(
      theme.extension<BusyMaxSurfaceColors>()?.sidebar,
      gtkColors.headerbar,
    );
  });

  test('BusyMax theme ignores black GTK surface samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF000000),
      view: Color(0xFF242424),
      sidebar: Color(0xFF000000),
      headerbar: Color(0xFF000000),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    expect(theme.scaffoldBackgroundColor, const Color(0xFF1D1D20));
    expect(theme.colorScheme.surface, gtkColors.view);
    expect(colors.sidebar, isNot(const Color(0xFF000000)));
    expect(colors.sidebar, isNot(const Color(0xFF2E2E32)));
  });

  test('BusyMax theme ignores near-black GTK surface samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF101010),
      view: Color(0xFF101010),
      sidebar: Color(0xFF101010),
      headerbar: Color(0xFF101010),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    expect(theme.scaffoldBackgroundColor, const Color(0xFF1D1D20));
    expect(theme.colorScheme.surface, const Color(0xFF1D1D20));
    expect(colors.sidebar, isNot(const Color(0xFF101010)));
    expect(colors.sidebar, isNot(theme.colorScheme.surface));
  });

  test('BusyMax theme ignores translucent GTK surface samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0x33000000),
      view: Color(0x33000000),
      sidebar: Color(0x33000000),
      headerbar: Color(0x33000000),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    expect(theme.scaffoldBackgroundColor, const Color(0xFF1D1D20));
    expect(theme.colorScheme.surface, const Color(0xFF1D1D20));
    expect(colors.sidebar, isNot(const Color(0x33000000)));
    expect(colors.sidebar, isNot(theme.colorScheme.surface));
  });

  test('BusyMax theme rejects unreadable GTK foreground samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF1D1D20),
      view: Color(0xFF1D1D20),
      sidebar: Color(0xFF2E2E32),
      foreground: Color(0xFF242428),
      mutedForeground: Color(0xFF242428),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    expect(colors.foreground, const Color(0xFFFFFFFF));
    expect(colors.mutedForeground, const Color.fromRGBO(255, 255, 255, 0.70));
    expect(theme.colorScheme.onSurface, colors.foreground);
    expect(theme.colorScheme.onSurfaceVariant, colors.mutedForeground);
  });

  test('BusyMax theme ignores GTK runtime colors for other brightness', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF202020),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkThemeColors: gtkColors,
    );

    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFAFB));
  });

  test(
    'BusyMax Yaru theme derives text theme from Yaru instead of scratch',
    () {
      final source = File(
        'lib/src/app/busymax_yaru_theme.dart',
      ).readAsStringSync();

      expect(source, contains('_busyMaxTextTheme('));
      expect(source, contains('base.copyWith('));
      expect(source, isNot(contains('return TextTheme(')));
      expect(source, isNot(contains('fontSize: 26')));
      expect(source, isNot(contains('fontSize: 15')));
    },
  );

  test('app sources do not hardcode product font families', () {
    const fontProperty =
        'font'
        'Family';
    const roboto =
        'Robo'
        'to';
    const ubuntu =
        'Ubun'
        'tu';
    const ubuntuSans =
        'Ubuntu '
        'Sans';
    const cantarell =
        'Canta'
        'rell';
    final forbidden = [
      "$fontProperty: '$roboto'",
      '$fontProperty: "$roboto"',
      "$fontProperty: '$ubuntu'",
      '$fontProperty: "$ubuntu"',
      "$fontProperty: '$ubuntuSans'",
      '$fontProperty: "$ubuntuSans"',
      "$fontProperty: '$cantarell'",
      '$fontProperty: "$cantarell"',
    ];
    final matches = <String>[];

    for (final root in [Directory('lib'), Directory('test')]) {
      for (final entry in root.listSync(recursive: true)) {
        if (entry is! File || !entry.path.endsWith('.dart')) {
          continue;
        }
        final text = utf8.decode(entry.readAsBytesSync(), allowMalformed: true);
        for (final token in forbidden) {
          if (text.contains(token)) {
            matches.add('${entry.path}: $token');
          }
        }
      }
    }

    expect(matches, isEmpty);
  });

  test('ThemeMode.system is the default', () {
    expect(AppSettings.defaults().themeMode, ThemeMode.system);
    expect(AppSettings.defaults().scheduleViewMode, ScheduleViewMode.week);
    expect(AppSettings.defaults().runInBackgroundWhenClosed, isTrue);
    expect(AppSettings.defaults().showTrayIcon, isTrue);
    expect(
      AppSettings.defaults().notificationDetailLevel,
      NotificationDetailLevel.normal,
    );
  });

  test('light and dark override persists', () async {
    final store = _MemorySettingsStore();
    final first = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);

    await first.setThemeModePreference(BusyMaxThemeModePreference.dark);

    final second = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);
    expect(second.state.themeModePreference, BusyMaxThemeModePreference.dark);

    await second.setThemeModePreference(BusyMaxThemeModePreference.light);
    final third = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);
    expect(third.state.themeModePreference, BusyMaxThemeModePreference.light);
  });

  test('schedule view mode persists', () async {
    final store = _MemorySettingsStore();
    final first = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);

    await first.setScheduleViewMode(ScheduleViewMode.month);

    final second = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);
    expect(second.state.scheduleViewMode, ScheduleViewMode.month);
    expect(store.json['scheduleViewMode'], 'month');
  });

  test('notification detail settings stay synchronized', () async {
    final store = _MemorySettingsStore();
    final settings = AppSettingsController(store);
    await Future<void>.delayed(Duration.zero);

    await settings.setNotificationDetailLevel(NotificationDetailLevel.private);
    expect(settings.state.detailedNotifications, isFalse);

    await settings.setDetailedNotifications(true);
    expect(
      settings.state.notificationDetailLevel,
      NotificationDetailLevel.normal,
    );

    final loaded = AppSettings.fromJson({
      'detailedNotifications': true,
      'notificationDetailLevel': 'private',
    });
    expect(loaded.notificationDetailLevel, NotificationDetailLevel.normal);
  });

  test('native headerbar receives semantic surface colors', () {
    final source = File('lib/src/app/busymax_app.dart').readAsStringSync();

    expect(
      source,
      contains('final colors = BusyMaxSurfaceColors.of(context);'),
    );
    expect(source, contains('await service.setTheme('));
    expect(source, contains('windowBackgroundColor: colors.window'));
    expect(source, contains('backgroundColor: colors.view'));
    expect(source, contains('sidebarBackgroundColor: colors.sidebar'));
    expect(source, contains('controlHoverColor: colors.controlHover'));
    expect(source, contains('accentColor: colorScheme.primary'));
    expect(source, contains('accentForegroundColor: colorScheme.onPrimary'));
    expect(source, contains('menu: l10n.mainMenu'));
    expect(source, contains('settings: l10n.settings'));
    expect(source, contains('keyboardShortcuts: l10n.keyboardShortcuts'));
    expect(source, contains('aboutBusyMax: l10n.aboutBusyMax'));
    expect(source, isNot(contains('menu: materialL10n.moreButtonTooltip')));
    expect(source, isNot(contains('setBackgroundColor(')));
    expect(source, isNot(contains('setSidebarBackgroundColor(')));
  });

  test(
    'root window wrapper clips bottom corners over matching native backing',
    () {
      final source = File('lib/src/app/busymax_app.dart').readAsStringSync();

      expect(source, contains('ClipRRect('));
      expect(source, contains('bottom: Radius.circular(BusyMaxRadius.window)'));
      expect(source, contains('clipBehavior: Clip.antiAliasWithSaveLayer'));
      expect(
        source,
        contains('color: BusyMaxSurfaceColors.of(context).window'),
      );
    },
  );

  test('signed-out onboarding background matches main content surface', () {
    final source = File(
      'lib/src/features/auth/presentation/sign_in_screen.dart',
    ).readAsStringSync();
    final shellStart = source.indexOf(
      'constraints: const BoxConstraints(maxWidth: 900)',
    );
    final shellEnd = source.indexOf('child: Column(', shellStart);
    final shellSource = source.substring(shellStart, shellEnd);

    expect(source, contains('color: BusyMaxSurfaceColors.of(context).view'));
    expect(
      source,
      isNot(contains('color: BusyMaxSurfaceColors.of(context).window')),
    );
    expect(shellSource, contains('BusyMaxSurface('));
    expect(shellSource, contains('filled: false'));
    expect(shellSource, isNot(contains('filled: true')));
    expect(source, contains('final title = context.l10n.onboardingSetupTitle'));
    expect(source, contains('service.updateState('));
    expect(source, contains('BusyMaxHeaderBarState('));
    expect(source, contains('title: title'));
    expect(source, isNot(contains('class _OnboardingHeader')));
    expect(source, isNot(contains('class _OnboardingProgressDots')));
    expect(source, isNot(contains('Border(top: BorderSide')));
    expect(
      source,
      contains('constraints: const BoxConstraints(maxWidth: 900)'),
    );
    expect(source, contains('constraints: const BoxConstraints('));
    expect(source, contains('maxWidth: 480'));
  });

  testWidgets('BusyMaxApp wires localization delegates and system theme', (
    tester,
  ) async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buildConfigProvider.overrideWithValue(_missingConfig),
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        ],
        child: const BusyMaxApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SystemThemeBuilder), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.localizationsDelegates, contains(AppLocalizations.delegate));
  });

  testWidgets('tray startup waits for persisted start-minimized settings', (
    tester,
  ) async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final store = _DelayedSettingsStore();
    final windowService = _RecordingWindowService();
    final trayService = _RecordingTrayService(windowService);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buildConfigProvider.overrideWithValue(_missingConfig),
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(store),
          linuxWindowServiceProvider.overrideWithValue(windowService),
        ],
        child: BusyMaxApp(
          trayServiceFactory:
              ({
                required windowService,
                required labels,
                required onOpenAgenda,
                onBeforeQuit,
              }) => trayService,
        ),
      ),
    );
    await tester.pump();

    expect(trayService.startCalls, 0);
    expect(windowService.hideWindowCalls, 0);

    store.completeLoad(<String, Object?>{
      'showTrayIcon': true,
      'runInBackgroundWhenClosed': true,
      'startMinimizedToTray': true,
    });
    await tester.pump();
    await tester.pump();

    expect(trayService.startCalls, 1);
    expect(windowService.hideWindowCalls, 1);

    // A rebuild with the same loaded settings must not restart the tray or
    // hide an already-running window a second time.
    await tester.pump();
    expect(trayService.startCalls, 1);
    expect(windowService.hideWindowCalls, 1);
  });

  test('app sources avoid forbidden hardcoded accent colors', () {
    final disallowedHue = String.fromCharCodes([111, 114, 97, 110, 103, 101]);
    final forbidden = [
      '0xFF0D6E'
          'FD',
      'Colors.'
          'blue',
      'Colors.'
          'red',
      'Colors.$disallowedHue',
      'YaruVariant.$disallowedHue',
    ];
    final matches = <String>[];

    for (final root in [Directory('lib'), Directory('test')]) {
      for (final entry in root.listSync(recursive: true)) {
        if (entry is! File) {
          continue;
        }
        final text = utf8.decode(entry.readAsBytesSync(), allowMalformed: true);
        for (final token in forbidden) {
          if (text.contains(token)) {
            matches.add('${entry.path}: $token');
          }
        }
      }
    }

    expect(matches, isEmpty);
  });

  testWidgets('non-English locale renders translated UI', (tester) async {
    await tester.pumpWidget(
      localizedTestApp(
        locale: const Locale('de'),
        child: Builder(builder: (context) => Text(context.l10n.settings)),
      ),
    );

    expect(find.text('Einstellungen'), findsOneWidget);
  });
}

const _testAccentColor = Color(0xFF2E7D32);
const _alternateTestAccentColor = Color(0xFF8A1D61);

ThemeData _buildBusyMaxTheme({
  required Brightness brightness,
  Color accentColor = _testAccentColor,
  String? gtkFontFamily,
  double? gtkFontSize,
  GtkThemeColors? gtkThemeColors,
}) {
  return buildBusyMaxTheme(
    brightness: brightness,
    accentColor: accentColor,
    gtkFontFamily: gtkFontFamily,
    gtkFontSize: gtkFontSize,
    gtkThemeColors: gtkThemeColors,
  );
}

class _TextThemeRole {
  const _TextThemeRole(this.name, this.actual, this.base);

  final String name;
  final TextStyle? actual;
  final TextStyle? base;
}

List<TextStyle> _textStyles(TextTheme theme) {
  return _textThemeRoles(
    theme,
    theme,
  ).map((role) => role.actual).whereType<TextStyle>().toList(growable: false);
}

List<_TextThemeRole> _textThemeRoles(TextTheme actual, TextTheme base) {
  return [
    _TextThemeRole('displayLarge', actual.displayLarge, base.displayLarge),
    _TextThemeRole('displayMedium', actual.displayMedium, base.displayMedium),
    _TextThemeRole('displaySmall', actual.displaySmall, base.displaySmall),
    _TextThemeRole('headlineLarge', actual.headlineLarge, base.headlineLarge),
    _TextThemeRole(
      'headlineMedium',
      actual.headlineMedium,
      base.headlineMedium,
    ),
    _TextThemeRole('headlineSmall', actual.headlineSmall, base.headlineSmall),
    _TextThemeRole('titleLarge', actual.titleLarge, base.titleLarge),
    _TextThemeRole('titleMedium', actual.titleMedium, base.titleMedium),
    _TextThemeRole('titleSmall', actual.titleSmall, base.titleSmall),
    _TextThemeRole('bodyLarge', actual.bodyLarge, base.bodyLarge),
    _TextThemeRole('bodyMedium', actual.bodyMedium, base.bodyMedium),
    _TextThemeRole('bodySmall', actual.bodySmall, base.bodySmall),
    _TextThemeRole('labelLarge', actual.labelLarge, base.labelLarge),
    _TextThemeRole('labelMedium', actual.labelMedium, base.labelMedium),
    _TextThemeRole('labelSmall', actual.labelSmall, base.labelSmall),
  ];
}

void _expectTextThemeMetrics({
  required TextTheme actual,
  required TextTheme base,
  required String? expectedFamilyForAll,
  double expectedScale = 1,
}) {
  for (final role in _textThemeRoles(actual, base)) {
    final actualStyle = role.actual;
    final baseStyle = role.base;
    expect(actualStyle, isNotNull, reason: '${role.name} should exist.');
    expect(baseStyle, isNotNull, reason: '${role.name} base should exist.');
    if (actualStyle == null || baseStyle == null) {
      continue;
    }

    if (expectedFamilyForAll == null) {
      expect(
        actualStyle.fontFamily,
        baseStyle.fontFamily,
        reason: '${role.name} should preserve the Yaru font family.',
      );
      expect(actualStyle.fontFamilyFallback, baseStyle.fontFamilyFallback);
    } else {
      expect(
        actualStyle.fontFamily,
        expectedFamilyForAll,
        reason: '${role.name} should use the GTK font family.',
      );
      expect(actualStyle.fontFamilyFallback, isNull);
    }

    if (baseStyle.fontSize == null) {
      expect(actualStyle.fontSize, isNull, reason: role.name);
    } else {
      expect(
        actualStyle.fontSize,
        moreOrLessEquals(baseStyle.fontSize! * expectedScale, epsilon: 0.0001),
        reason: '${role.name} should preserve Yaru size with GTK scaling.',
      );
    }

    expect(actualStyle.fontWeight, baseStyle.fontWeight, reason: role.name);
    expect(actualStyle.fontStyle, baseStyle.fontStyle, reason: role.name);
    expect(
      actualStyle.letterSpacing,
      baseStyle.letterSpacing,
      reason: role.name,
    );
    expect(actualStyle.height, baseStyle.height, reason: role.name);
    expect(actualStyle.wordSpacing, baseStyle.wordSpacing, reason: role.name);
    expect(actualStyle.textBaseline, baseStyle.textBaseline, reason: role.name);
    expect(
      actualStyle.leadingDistribution,
      baseStyle.leadingDistribution,
      reason: role.name,
    );
    expect(actualStyle.fontFeatures, baseStyle.fontFeatures, reason: role.name);
    expect(
      actualStyle.fontVariations,
      baseStyle.fontVariations,
      reason: role.name,
    );
    expect(actualStyle.decoration, baseStyle.decoration, reason: role.name);
    expect(
      actualStyle.decorationColor,
      baseStyle.decorationColor,
      reason: role.name,
    );
    expect(
      actualStyle.decorationStyle,
      baseStyle.decorationStyle,
      reason: role.name,
    );
    expect(
      actualStyle.decorationThickness,
      baseStyle.decorationThickness,
      reason: role.name,
    );
  }
}

void _expectComponentStyleUsesTypography(
  TextStyle? actual, {
  required TextStyle? baseStyle,
  required TextStyle? fallback,
  required String family,
  required double scale,
}) {
  expect(actual, isNotNull);
  expect(baseStyle ?? fallback, isNotNull);
  if (actual == null) {
    return;
  }
  final expected = baseStyle ?? fallback;
  if (expected == null) {
    return;
  }
  final expectedScale = baseStyle == null ? 1.0 : scale;

  expect(actual.fontFamily, family);
  expect(actual.fontFamilyFallback, isNull);
  if (expected.fontSize == null) {
    expect(actual.fontSize, isNull);
  } else {
    expect(
      actual.fontSize,
      moreOrLessEquals(expected.fontSize! * expectedScale, epsilon: 0.0001),
    );
  }
  expect(actual.fontWeight, expected.fontWeight);
  expect(actual.letterSpacing, expected.letterSpacing);
  expect(actual.height, expected.height);
}

class _MemorySettingsStore implements LocalSettingsStore {
  Map<String, Object?> json = <String, Object?>{};

  @override
  Future<Map<String, Object?>> load() async {
    return Map<String, Object?>.from(json);
  }

  @override
  Future<void> save(Map<String, Object?> json) async {
    this.json = Map<String, Object?>.from(json);
  }
}

class _DelayedSettingsStore implements LocalSettingsStore {
  final _loadCompleter = Completer<Map<String, Object?>>();

  void completeLoad(Map<String, Object?> json) {
    _loadCompleter.complete(Map<String, Object?>.from(json));
  }

  @override
  Future<Map<String, Object?>> load() => _loadCompleter.future;

  @override
  Future<void> save(Map<String, Object?> json) async {}
}

class _RecordingWindowService extends LinuxWindowService {
  var hideWindowCalls = 0;

  @override
  Future<void> hideWindow() async {
    hideWindowCalls += 1;
  }

  @override
  Future<void> setHideOnClose(bool enabled) async {}
}

class _RecordingTrayService extends BusyMaxTrayService {
  _RecordingTrayService(LinuxWindowService windowService)
    : super(
        windowService: windowService,
        labels: const BusyMaxTrayLabels(
          openBusyMax: 'Open BusyMax',
          agenda: 'Agenda',
          quitBusyMax: 'Exit',
        ),
        onOpenAgenda: _noop,
      );

  var startCalls = 0;
  var _available = false;

  @override
  bool get available => _available;

  @override
  Future<void> start() async {
    startCalls += 1;
    _available = true;
  }

  @override
  Future<void> stop() async {
    _available = false;
  }

  @override
  Future<void> updateLabels(BusyMaxTrayLabels labels) async {}
}

Future<void> _noop() async {}

const _missingConfig = BuildConfig(
  googleOAuthClientId: '',
  googleOAuthClientSecret: '',
  apiBaseUrl: 'https://tasks.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);
