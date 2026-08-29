import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_theme/system_theme.dart';
import 'package:yaru/constants.dart';
import 'package:yaru/theme.dart';
import 'package:yaru/widgets.dart' show YaruInfoType;
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/app_router.dart';
import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/app/app_theme.dart';
import 'package:busymax/src/app/busymax_app.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/config/build_config.dart';
import 'package:busymax/src/db/app_database.dart';
import 'package:busymax/src/features/connectivity/network_connectivity_service.dart';
import 'package:busymax/src/features/sync/all_accounts_sync_scheduler.dart';
import 'package:busymax/src/features/tray/domain/tray_presentation.dart';
import 'package:busymax/src/l10n/l10n.dart';
import 'package:busymax/src/platform/busymax_tray_service.dart';
import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:busymax/src/platform/linux_window_service.dart';
import 'package:busymax/src/schedule/schedule_commands.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../test_localized_app.dart';

void main() {
  test('native header theme uses the exact first-frame semantic palette', () {
    final theme = _buildBusyMaxTheme(brightness: Brightness.light);
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    final headerTheme = busyMaxHeaderBarThemeFor(theme, highContrast: false);

    expect(headerTheme.preferDark, isFalse);
    expect(headerTheme.highContrast, isFalse);
    expect(headerTheme.windowBackgroundColor, colors.window);
    expect(headerTheme.backgroundColor, colors.window);
    expect(headerTheme.sidebarBackgroundColor, colors.sidebar);
    expect(headerTheme.foregroundColor, colors.foreground);
    expect(headerTheme.dialogBackgroundColor, colors.dialog);
    expect(headerTheme.modalBarrierColor, colors.shade);
    expect(headerTheme.tooltip.backgroundColor, BusyMaxTooltipStyle.background);
    expect(headerTheme.tooltip.foregroundColor, BusyMaxTooltipStyle.foreground);
    expect(headerTheme.tooltip.borderColor, BusyMaxTooltipStyle.border);
    expect(headerTheme.tooltip.borderRadius, BusyMaxRadius.tooltip);
    expect(
      headerTheme.tooltip.fontSize,
      theme.tooltipTheme.textStyle?.fontSize,
    );
    expect(
      headerTheme.tooltip.horizontalPadding,
      BusyMaxSpacing.tooltipHorizontal,
    );
    expect(headerTheme.tooltip.verticalPadding, BusyMaxSpacing.tooltipVertical);
    expect(headerTheme.tooltip.minimumHeight, BusyMaxSizes.tooltipMinHeight);
  });

  test('builds with system accent and tokenized control surfaces', () {
    final light = _buildBusyMaxTheme(brightness: Brightness.light);
    final dark = _buildBusyMaxTheme(brightness: Brightness.dark);
    final alternate = _buildBusyMaxTheme(
      brightness: Brightness.light,
      accentColor: _alternateTestAccentColor,
    );
    final selected = {WidgetState.selected};

    final lightSurfaceColors = light.extension<BusyMaxSurfaceColors>()!;
    final yaruBase = createYaruLightTheme(primaryColor: _testAccentColor);

    expect(light.colorScheme.primary, _testAccentColor);
    expect(dark.colorScheme.primary, _testAccentColor);
    expect(light.primaryColor, _testAccentColor);
    expect(light.visualDensity, yaruBase.visualDensity);
    expect(light.splashFactory, yaruBase.splashFactory);
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
      lightSurfaceColors.control,
    );
    expect(
      light.filledButtonTheme.style?.backgroundColor?.resolve(selected),
      lightSurfaceColors.controlActive,
    );
    expect(
      light.filledButtonTheme.style?.iconColor?.resolve({}),
      lightSurfaceColors.foreground,
    );
    expect(
      light.elevatedButtonTheme.style?.backgroundColor?.resolve({}),
      _testAccentColor,
    );
    expect(
      light.elevatedButtonTheme.style?.iconColor?.resolve({}),
      light.colorScheme.onPrimary,
    );
    for (final style in [
      light.filledButtonTheme.style,
      light.elevatedButtonTheme.style,
      light.outlinedButtonTheme.style,
      light.textButtonTheme.style,
    ]) {
      expect(
        style?.iconColor?.resolve({WidgetState.disabled}),
        lightSurfaceColors.disabledForeground,
      );
    }
    expect(light.toggleButtonsTheme, yaruBase.toggleButtonsTheme);
    expect(light.floatingActionButtonTheme.backgroundColor, _testAccentColor);
    expect(light.progressIndicatorTheme.color, _testAccentColor);
    expect(light.textSelectionTheme.cursorColor, _testAccentColor);

    final focusedBorder =
        light.inputDecorationTheme.focusedBorder as OutlineInputBorder;
    expect(focusedBorder.borderSide.color, _testAccentColor);

    final outlinedShape =
        light.outlinedButtonTheme.style?.shape?.resolve({})
            as RoundedRectangleBorder;
    expect(outlinedShape.borderRadius, BorderRadius.circular(BusyMaxRadius.sm));

    expect(
      light.outlinedButtonTheme.style?.side?.resolve({}),
      yaruBase.outlinedButtonTheme.style?.side?.resolve({}),
    );
    for (final pair in [
      (light.outlinedButtonTheme.style, yaruBase.outlinedButtonTheme.style),
      (light.filledButtonTheme.style, yaruBase.filledButtonTheme.style),
      (light.elevatedButtonTheme.style, yaruBase.elevatedButtonTheme.style),
    ]) {
      expect(pair.$1?.shape?.resolve({}), pair.$2?.shape?.resolve({}));
      for (final states in [
        {WidgetState.hovered},
        {WidgetState.focused},
        {WidgetState.pressed},
      ]) {
        expect(
          pair.$1?.overlayColor?.resolve(states),
          pair.$2?.overlayColor?.resolve(states),
        );
      }
    }
  });

  testWidgets('desktop tooltips use one explicit natural-width geometry', (
    tester,
  ) async {
    Future<({Rect surface, Rect text})> measureTooltip({
      required Brightness brightness,
      required String message,
    }) async {
      final tooltipKey = GlobalKey<TooltipState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: _buildBusyMaxTheme(brightness: brightness),
          home: Scaffold(
            body: Center(
              child: Tooltip(
                key: tooltipKey,
                message: message,
                child: const SizedBox.square(dimension: 32),
              ),
            ),
          ),
        ),
      );
      expect(tooltipKey.currentState!.ensureTooltipVisible(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final messageFinder = find.text(message);
      expect(messageFinder, findsOneWidget);
      final textRect = tester.getRect(messageFinder);
      Rect? surfaceRect;
      tester.element(messageFinder).visitAncestorElements((element) {
        if (element.widget case final ConstrainedBox constrained
            when constrained.constraints == BusyMaxTooltipStyle.constraints) {
          final box = element.renderObject! as RenderBox;
          surfaceRect = box.localToGlobal(Offset.zero) & box.size;
          return false;
        }
        return true;
      });
      expect(surfaceRect, isNotNull);
      return (surface: surfaceRect!, text: textRect);
    }

    for (final brightness in Brightness.values) {
      final short = await measureTooltip(
        brightness: brightness,
        message: 'Main menu',
      );
      final long = await measureTooltip(
        brightness: brightness,
        message: 'Show sidebar panel',
      );

      for (final measurement in [short, long]) {
        expect(measurement.surface.height, BusyMaxSizes.tooltipMinHeight);
        expect(
          measurement.surface.width,
          moreOrLessEquals(
            measurement.text.width +
                (BusyMaxSpacing.tooltipHorizontal + BusyMaxStroke.outline) * 2,
            epsilon: 0.01,
          ),
        );
      }
      expect(long.surface.width, greaterThan(short.surface.width));
    }
  });

  test('semantic theme retains Yaru component geometry and interactions', () {
    final theme = _buildBusyMaxTheme(brightness: Brightness.light);
    final base = createYaruLightTheme(primaryColor: _testAccentColor);
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    expect(theme.inputDecorationTheme.filled, base.inputDecorationTheme.filled);
    expect(
      theme.inputDecorationTheme.fillColor,
      base.inputDecorationTheme.fillColor,
    );
    expect(
      theme.inputDecorationTheme.contentPadding,
      base.inputDecorationTheme.contentPadding,
    );
    final inputShape =
        theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    final baseInputShape =
        base.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    expect(inputShape.borderRadius, baseInputShape.borderRadius);
    expect(inputShape.borderSide.width, baseInputShape.borderSide.width);
    expect(
      inputShape.borderSide.strokeAlign,
      baseInputShape.borderSide.strokeAlign,
    );
    expect(inputShape.borderSide.color, colors.border);

    expect(theme.cardTheme.color, colors.card);
    expect(theme.cardTheme.color?.a, 1);
    expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
    expect(theme.cardTheme.shadowColor, theme.colorScheme.shadow);
    expect(theme.cardTheme.elevation, BusyMaxElevation.groupedCard);
    expect(theme.cardTheme.margin, base.cardTheme.margin);
    expect(theme.cardTheme.clipBehavior, base.cardTheme.clipBehavior);
    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(cardShape.borderRadius, BorderRadius.circular(BusyMaxRadius.md));
    expect(cardShape.side, BorderSide.none);

    expect(
      theme.dropdownMenuTheme.inputDecorationTheme?.constraints,
      base.dropdownMenuTheme.inputDecorationTheme?.constraints,
    );

    final dialogShape = theme.dialogTheme.shape! as RoundedRectangleBorder;
    final baseDialogShape = base.dialogTheme.shape! as RoundedRectangleBorder;
    expect(theme.dialogTheme.elevation, base.dialogTheme.elevation);
    expect(theme.dialogTheme.shadowColor, theme.colorScheme.shadow);
    expect(dialogShape.borderRadius, baseDialogShape.borderRadius);
    expect(dialogShape.borderRadius, BorderRadius.circular(kYaruWindowRadius));
    expect(dialogShape.side, BorderSide(color: colors.dialogOutline));
    expect(dialogShape.side, isNot(baseDialogShape.side));
    expect(BusyMaxRadius.window, kYaruWindowRadius);

    for (final pair in [
      (theme.outlinedButtonTheme.style, base.outlinedButtonTheme.style),
      (theme.filledButtonTheme.style, base.filledButtonTheme.style),
      (theme.elevatedButtonTheme.style, base.elevatedButtonTheme.style),
      (theme.textButtonTheme.style, base.textButtonTheme.style),
    ]) {
      final padding = pair.$1?.padding?.resolve(const {})! as EdgeInsets;
      final basePadding = pair.$2?.padding?.resolve(const {})! as EdgeInsets;
      expect(padding.horizontal, basePadding.horizontal);
      expect(padding.vertical, 0);
      expect(
        pair.$1?.minimumSize?.resolve(const {}),
        pair.$2?.minimumSize?.resolve(const {}),
      );
      expect(pair.$1?.visualDensity, VisualDensity.standard);
      expect(pair.$1?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    }

    final checkboxShape = theme.checkboxTheme.shape! as RoundedRectangleBorder;
    final baseCheckboxShape =
        base.checkboxTheme.shape! as RoundedRectangleBorder;
    expect(checkboxShape.borderRadius, baseCheckboxShape.borderRadius);
    expect(checkboxShape.borderRadius, BorderRadius.circular(kYaruCheckRadius));

    final popupShape = theme.popupMenuTheme.shape! as OutlineInputBorder;
    final basePopupShape = base.popupMenuTheme.shape! as OutlineInputBorder;
    expect(popupShape.borderRadius, basePopupShape.borderRadius);
    expect(popupShape.borderSide, BorderSide(color: colors.floatingBorder));
    expect(
      theme.popupMenuTheme.elevation,
      theme.menuTheme.style?.elevation?.resolve(const {}),
    );
    expect(
      theme.menuTheme.style?.elevation?.resolve(const {}),
      base.menuTheme.style?.elevation?.resolve(const {}),
    );
    expect(theme.popupMenuTheme.menuPadding, base.popupMenuTheme.menuPadding);
    expect(theme.popupMenuTheme.position, base.popupMenuTheme.position);
    expect(
      theme.menuTheme.style?.side?.resolve({}),
      BorderSide(color: colors.floatingBorder),
    );
    expect(
      theme.dropdownMenuTheme.menuStyle?.side?.resolve({}),
      BorderSide(color: colors.floatingBorder),
    );

    for (final style in [
      theme.textTheme.titleSmall,
      theme.textTheme.bodySmall,
      theme.textTheme.labelLarge,
      theme.textTheme.labelMedium,
      theme.textTheme.labelSmall,
    ]) {
      expect(style?.color, colors.foreground);
      expect(style?.color, isNot(colors.mutedForeground));
    }
  });

  testWidgets('semantic Yaru status colors do not follow the app accent', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      Map<YaruInfoType, Color>? colorsForFirstAccent;
      for (final accent in const [Color(0xFFE95420), Color(0xFF7764D8)]) {
        final theme = _buildBusyMaxTheme(
          brightness: brightness,
          accentColor: accent,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            darkTheme: theme,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const Scaffold(
              body: SizedBox(key: ValueKey('status-color-probe')),
            ),
          ),
        );

        final context = tester.element(
          find.byKey(const ValueKey('status-color-probe')),
        );
        final semanticColors = YaruColors.of(context);
        final actual = <YaruInfoType, Color>{
          for (final type in YaruInfoType.values) type: type.getColor(context),
        };

        expect(actual, <YaruInfoType, Color>{
          YaruInfoType.information: semanticColors.link,
          YaruInfoType.success: semanticColors.success,
          YaruInfoType.important: YaruColors.purple,
          YaruInfoType.warning: semanticColors.warning,
          YaruInfoType.danger: semanticColors.error,
        });
        colorsForFirstAccent ??= actual;
        expect(actual, colorsForFirstAccent);
        expect(actual[YaruInfoType.information], isNot(accent));
      }
    }
  });

  test('shared push buttons expose semantic Yaru roles', () {
    final standard = BusyMaxPushButton.standard(
      onPressed: () {},
      child: const Text('Standard'),
    );
    final suggested = BusyMaxPushButton.suggested(
      onPressed: () {},
      child: const Text('Suggested'),
    );

    expect(standard, isA<FilledButton>());
    expect(suggested, isA<ElevatedButton>());
    expect(standard.style, isNull);
    expect(suggested.style, isNull);
  });

  test('BusyMax Yaru theme exposes semantic fallback surfaces', () {
    final light = _buildBusyMaxTheme(brightness: Brightness.light);
    final dark = _buildBusyMaxTheme(brightness: Brightness.dark);

    final lightColors = light.extension<BusyMaxSurfaceColors>()!;
    final darkColors = dark.extension<BusyMaxSurfaceColors>()!;

    expect(lightColors.window, const Color(0xFFFAFAFA));
    expect(lightColors.view, const Color(0xFFFFFFFF));
    expect(lightColors.sidebar, const Color(0xFFEBEBEB));
    expect(lightColors.secondarySidebar, const Color(0xFFF0F0F0));
    expect(lightColors.headerbar, const Color(0xFFFAFAFA));
    expect(lightColors.headerbarFlat, lightColors.view);
    expect(lightColors.card, const Color(0xFFFFFFFF));
    expect(lightColors.groupedSurface, const Color(0xFFFFFFFF));
    expect(lightColors.dialog, const Color(0xFFFAFAFA));
    expect(lightColors.popover, const Color(0xFFFAFAFA));
    expect(lightColors.control, const Color.fromRGBO(0, 0, 0, 0.10));
    expect(lightColors.controlHover, const Color.fromRGBO(0, 0, 0, 0.14));
    expect(lightColors.controlActive, const Color.fromRGBO(0, 0, 0, 0.18));
    expect(lightColors.mutedForeground, const Color(0xFF666666));
    expect(
      lightColors.dialogOutline,
      const Color.fromRGBO(255, 255, 255, 0.07),
    );
    expect(lightColors.floatingBorder, const Color.fromRGBO(0, 0, 0, 0.14));
    expect(lightColors.sidebarBorder, const Color.fromRGBO(24, 24, 24, 0.08));
    expect(darkColors.window, const Color(0xFF2C2C2C));
    expect(darkColors.view, const Color(0xFF272727));
    expect(darkColors.sidebar, const Color(0xFF393939));
    expect(darkColors.secondarySidebar, const Color(0xFF323232));
    expect(darkColors.headerbar, const Color(0xFF393939));
    expect(darkColors.card, const Color(0xFF3D3D3D));
    expect(
      darkColors.groupedSurface,
      const Color.fromRGBO(255, 255, 255, 0.08),
    );
    expect(darkColors.dialog, const Color(0xFF3E3E3E));
    expect(darkColors.popover, const Color(0xFF3E3E3E));
    expect(darkColors.mutedForeground, const Color(0xFFB5B5B5));
    expect(darkColors.border, const Color.fromRGBO(0, 0, 0, 0.75));
    expect(darkColors.dialogOutline, const Color.fromRGBO(255, 255, 255, 0.07));
    expect(darkColors.floatingBorder, const Color.fromRGBO(0, 0, 0, 0.14));
    expect(darkColors.sidebarBorder, const Color.fromRGBO(16, 16, 16, 0.35));
    expect(
      Color.alphaBlend(darkColors.sidebarBorder, darkColors.sidebar).toARGB32(),
      const Color(0xFF2B2B2B).toARGB32(),
    );
    expect(darkColors.shade, const Color.fromRGBO(0, 0, 0, 0.25));
    expect(darkColors.groupedSurface.a, lessThan(1));
    expect(
      Color.alphaBlend(darkColors.groupedSurface, darkColors.window).toARGB32(),
      darkColors.card.toARGB32(),
    );
    expect(
      Color.alphaBlend(
        darkColors.groupedSurface,
        darkColors.dialog,
      ).computeLuminance(),
      greaterThan(darkColors.dialog.computeLuminance()),
    );
    for (final (theme, colors) in [(light, lightColors), (dark, darkColors)]) {
      _expectOpaqueMonotonicSurfaceContainers(theme);
      expect(theme.colorScheme.surfaceContainerLowest, colors.view);
      expect(theme.colorScheme.surfaceContainerLow, colors.window);
      expect(theme.colorScheme.surfaceContainer, colors.secondarySidebar);
      expect(theme.colorScheme.surfaceContainerHigh, colors.secondarySidebar);
      expect(theme.colorScheme.surfaceContainerHighest, colors.sidebar);
      expect(colors.mutedForeground.a, 1);
      final effectiveGroupedSurfaces = [
        for (final parent in [
          colors.window,
          colors.view,
          colors.dialog,
          colors.popover,
        ])
          Color.alphaBlend(colors.groupedSurface, parent),
      ];
      for (final surface in [
        colors.window,
        colors.view,
        colors.sidebar,
        colors.secondarySidebar,
        colors.headerbar,
        colors.headerbarFlat,
        colors.card,
        colors.dialog,
        colors.popover,
      ]) {
        _expectNeutralSurface(surface);
        expect(
          _contrastRatio(colors.mutedForeground, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'Muted text must remain legible on $surface',
        );
      }
      for (final surface in effectiveGroupedSurfaces) {
        _expectNeutralSurface(surface);
        expect(
          _contrastRatio(colors.mutedForeground, surface),
          greaterThanOrEqualTo(4),
          reason:
              'Native contextual card layers must retain clear secondary text',
        );
      }
    }
    expect(light.scaffoldBackgroundColor, lightColors.window);
    expect(dark.scaffoldBackgroundColor, darkColors.window);
    expect(light.cardColor, lightColors.card);
    expect(dark.cardColor, darkColors.card);
    expect(light.cardTheme.color, lightColors.card);
    expect(dark.cardTheme.color, darkColors.card);
    expect(light.cardTheme.color?.a, 1);
    expect(dark.cardTheme.color?.a, 1);
    expect(light.cardTheme.elevation, BusyMaxElevation.groupedCard);
    expect(dark.cardTheme.elevation, BusyMaxElevation.groupedCard);
    expect(light.cardTheme.shadowColor, light.colorScheme.shadow);
    expect(dark.cardTheme.shadowColor, dark.colorScheme.shadow);
    expect(light.dialogTheme.backgroundColor, lightColors.dialog);
    expect(dark.dialogTheme.backgroundColor, darkColors.dialog);
    expect(light.dialogTheme.shadowColor, light.colorScheme.shadow);
    expect(dark.dialogTheme.shadowColor, dark.colorScheme.shadow);
    expect(light.popupMenuTheme.color, lightColors.popover);
    expect(dark.popupMenuTheme.color, darkColors.popover);
    expect(
      light.popupMenuTheme.labelTextStyle?.resolve(const {})?.color,
      lightColors.foreground,
    );
    expect(
      light.popupMenuTheme.labelTextStyle?.resolve(const {
        WidgetState.disabled,
      })?.color,
      lightColors.disabledForeground,
    );
    expect(
      dark.menuTheme.style?.backgroundColor?.resolve(const {}),
      darkColors.popover,
    );
    expect(
      dark.dropdownMenuTheme.menuStyle?.backgroundColor?.resolve(const {}),
      darkColors.popover,
    );
    final yaruDark = createYaruDarkTheme(primaryColor: _testAccentColor);
    for (final pair in [
      (dark.menuTheme.style, yaruDark.menuTheme.style),
      (dark.dropdownMenuTheme.menuStyle, yaruDark.dropdownMenuTheme.menuStyle),
    ]) {
      expect(
        pair.$1?.elevation?.resolve(const {}),
        pair.$2?.elevation?.resolve(const {}),
      );
      expect(
        pair.$1?.shape?.resolve(const {}),
        pair.$2?.shape?.resolve(const {}),
      );
      expect(
        pair.$1?.side?.resolve(const {}),
        BorderSide(color: darkColors.floatingBorder),
      );
      expect(
        pair.$1?.padding?.resolve(const {}),
        pair.$2?.padding?.resolve(const {}),
      );
    }
    final yaruLight = createYaruLightTheme(primaryColor: _testAccentColor);
    for (final theme in [light, dark]) {
      final decoration = theme.tooltipTheme.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(decoration.color, BusyMaxTooltipStyle.background);
      expect(decoration.borderRadius, BusyMaxTooltipStyle.borderRadius);
      expect(border.top.color, BusyMaxTooltipStyle.border);
      expect(
        theme.tooltipTheme.textStyle?.color,
        BusyMaxTooltipStyle.foreground,
      );
      expect(theme.tooltipTheme.padding, BusyMaxTooltipStyle.padding);
      expect(theme.tooltipTheme.constraints, BusyMaxTooltipStyle.constraints);
      expect(theme.tooltipTheme.waitDuration, BusyMaxMotion.tooltipWait);
    }
    expect(
      light.tooltipTheme.waitDuration,
      yaruLight.tooltipTheme.waitDuration,
    );
    expect(dark.tooltipTheme.waitDuration, yaruDark.tooltipTheme.waitDuration);
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
      dialogOutline: const Color(0xFF090A0B),
      shade: const Color(0xFF0A0B0C),
    );

    expect(updated.window, const Color(0xFF010203));
    expect(updated.sidebar, const Color(0xFF040506));
    expect(updated.groupedSurface, const Color(0xFF060708));
    expect(updated.disabledForeground, const Color(0xFF070809));
    expect(updated.dialogOutline, const Color(0xFF090A0B));
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
      midpoint.dialogOutline,
      Color.lerp(start.dialogOutline, end.dialogOutline, 0.5),
    );
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
      theme.popupMenuTheme.labelTextStyle?.resolve(buttonStates),
      baseStyle: base.popupMenuTheme.labelTextStyle?.resolve(buttonStates),
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
    expect(
      theme.tooltipTheme.textStyle?.fontFamily,
      theme.textTheme.bodyMedium?.fontFamily,
    );
    expect(
      theme.tooltipTheme.textStyle?.fontSize,
      theme.textTheme.bodyMedium?.fontSize,
    );
    expect(theme.tooltipTheme.textStyle?.color, BusyMaxTooltipStyle.foreground);
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
      card: Color(0xFF444444),
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
      divider: Color(0x1AFFFFFF),
      cardShade: Color(0x5A101010),
      floatingBorder: Color(0x24000000),
      sidebarBorder: Color(0x33000000),
      shade: Color(0x55000000),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );

    expect(theme.scaffoldBackgroundColor, gtkColors.window);
    expect(theme.colorScheme.surface, gtkColors.view);
    _expectOpaqueMonotonicSurfaceContainers(theme);
    expect(theme.colorScheme.surfaceContainerHigh, isNot(gtkColors.control));
    expect(
      theme.colorScheme.surfaceContainerHighest,
      isNot(gtkColors.controlHover),
    );
    expect(theme.colorScheme.onSurface, gtkColors.foreground);
    expect(theme.colorScheme.onSurfaceVariant, gtkColors.mutedForeground);
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    expect(theme.dialogTheme.backgroundColor, gtkColors.dialog);
    expect(theme.popupMenuTheme.color, gtkColors.popover);
    expect(colors.dialog, gtkColors.dialog);
    expect(colors.popover, gtkColors.popover);
    expect(colors.sidebar, gtkColors.sidebar);
    expect(colors.groupedSurface, gtkColors.card);
    expect(colors.cardShade, gtkColors.cardShade);
  });

  test('BusyMax theme uses GTK accent foreground when it is readable', () {
    const accent = Color(0xFF006B50);
    const accentForeground = Color(0xFFF5FFF9);
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      accent: accent,
      accentForeground: accentForeground,
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.light,
      accentColor: accent,
      gtkThemeColors: gtkColors,
    );

    expect(theme.colorScheme.onPrimary, accentForeground);
    expect(
      theme.elevatedButtonTheme.style?.foregroundColor?.resolve({}),
      accentForeground,
    );
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
    expect(
      colors.groupedSurface,
      busyMaxFallbackSurfaceColors(Brightness.light).groupedSurface,
    );
    expect(theme.shadowColor, theme.colorScheme.shadow);
    expect(theme.popupMenuTheme.shadowColor, theme.colorScheme.shadow);
    expect(theme.popupMenuTheme.shadowColor, isNot(colors.shade));
  });

  test('BusyMax preserves a flat light GTK3 sidebar role', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      window: Color(0xFFFAFAFA),
      view: Color(0xFFFAFAFA),
      sidebar: Color(0xFFFAFAFA),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;

    expect(colors.sidebar, gtkColors.sidebar);
  });

  test('light view keeps its semantic fallback when GTK omits it', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      window: Color(0xFFF4F4F4),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;
    final fallback = busyMaxFallbackSurfaceColors(Brightness.light);

    expect(colors.window, gtkColors.window);
    expect(colors.view, fallback.view);
    expect(colors.headerbarFlat, fallback.view);
  });

  test('an explicit GTK workspace view remains authoritative', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      window: Color(0xFFF4F4F4),
      view: Color(0xFFFFFFFF),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;

    expect(colors.window, gtkColors.window);
    expect(colors.view, gtkColors.view);
    expect(colors.headerbarFlat, gtkColors.view);
  });

  test('dark workspace keeps its distinct fallback when GTK omits view', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF303030),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;
    final fallback = busyMaxFallbackSurfaceColors(Brightness.dark);

    expect(colors.window, gtkColors.window);
    expect(colors.view, fallback.view);
    expect(colors.headerbarFlat, fallback.view);
  });

  test('BusyMax preserves a distinct light GTK sidebar sample', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      window: Color(0xFFFAFAFA),
      view: Color(0xFFFFFFFF),
      sidebar: Color(0xFFE8E8EA),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;

    expect(colors.sidebar, gtkColors.sidebar);
  });

  test('BusyMax preserves named GTK floating-surface roles', () {
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

    expect(theme.popupMenuTheme.color, gtkColors.popover);
    expect(colors.popover, gtkColors.popover);
    expect(colors.dialog, busyMaxFallbackSurfaceColors(Brightness.dark).dialog);
    expect(
      colors.groupedSurface,
      busyMaxFallbackSurfaceColors(Brightness.dark).groupedSurface,
    );
  });

  test('BusyMax preserves explicitly supplied readable GTK surface roles', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF2C2C2C),
      view: Color(0xFF272727),
      sidebar: Color(0xFF2A2A2A),
      popover: Color(0xFF1D1D1D),
      foreground: Color(0xFFF7F7F7),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    expect(colors.sidebar, gtkColors.sidebar);
    expect(colors.dialog, busyMaxFallbackSurfaceColors(Brightness.dark).dialog);
    expect(colors.popover, gtkColors.popover);
    expect(theme.popupMenuTheme.color, colors.popover);
    expect(
      theme.menuTheme.style?.backgroundColor?.resolve(const {}),
      colors.popover,
    );
    expect(
      theme.dropdownMenuTheme.menuStyle?.backgroundColor?.resolve(const {}),
      colors.popover,
    );
  });

  test('BusyMax does not tint readable neutral GTK semantic roles', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF2C2C2C),
      view: Color(0xFF272727),
      sidebar: Color(0xFF2C2C2C),
      headerbar: Color(0xFF131313),
      dialog: Color(0xFF2C2C2C),
      popover: Color(0xFF1D1D1D),
      foreground: Color(0xFFF7F7F7),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;

    expect(colors.window, gtkColors.window);
    expect(colors.view, gtkColors.view);
    expect(colors.sidebar, gtkColors.sidebar);
    expect(colors.headerbar, gtkColors.headerbar);
    expect(colors.dialog, gtkColors.dialog);
    expect(colors.popover, gtkColors.popover);
    for (final surface in [
      colors.window,
      colors.view,
      colors.sidebar,
      colors.secondarySidebar,
      colors.headerbar,
      colors.headerbarFlat,
      colors.card,
      colors.groupedSurface,
      colors.dialog,
      colors.popover,
    ]) {
      _expectNeutralSurface(surface);
    }
  });

  test('BusyMax preserves a GTK card layer for its actual parent', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF2C2C2C),
      view: Color(0xFF272727),
      card: Color.fromRGBO(255, 255, 255, 0.08),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;
    final expectedCard = Color.alphaBlend(gtkColors.card!, gtkColors.window!);
    final wrongParent = Color.alphaBlend(gtkColors.card!, gtkColors.view!);
    final expectedDialogCard = Color.alphaBlend(gtkColors.card!, colors.dialog);

    expect(colors.card, expectedCard);
    expect(colors.groupedSurface, gtkColors.card);
    expect(colors.groupedSurface.a, lessThan(1));
    expect(
      Color.alphaBlend(colors.groupedSurface, colors.window),
      expectedCard,
    );
    expect(
      Color.alphaBlend(colors.groupedSurface, colors.dialog),
      expectedDialogCard,
    );
    expect(expectedDialogCard, isNot(expectedCard));
    expect(colors.card, isNot(wrongParent));
  });

  test('BusyMax preserves custom GTK surface roles', () {
    const parent = Color(0xFF3E3E3E);
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: parent,
      view: parent,
      sidebar: Color(0xFF2A2A2A),
      secondarySidebar: Color(0xFF303030),
      headerbar: Color(0xFF303030),
      card: Color(0xFF303030),
      dialog: Color(0xFF303030),
      popover: Color(0xFF303030),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;

    expect(colors.sidebar, gtkColors.sidebar);
    expect(colors.secondarySidebar, gtkColors.secondarySidebar);
    expect(colors.headerbar, gtkColors.headerbar);
    expect(colors.card, gtkColors.card);
    expect(colors.groupedSurface, gtkColors.card);
    expect(colors.dialog, gtkColors.dialog);
    expect(colors.popover, gtkColors.popover);
  });

  test('BusyMax grouped surfaces ignore unreadable GTK card samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      window: Color(0xFFFFFFFF),
      view: Color(0xFFFFFFFF),
      card: Color(0xFF101010),
      popover: Color(0xFFEEEEEE),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;

    expect(
      colors.groupedSurface,
      busyMaxFallbackSurfaceColors(Brightness.light).groupedSurface,
    );
    expect(colors.groupedSurface, isNot(gtkColors.card));
    expect(colors.groupedSurface, isNot(gtkColors.popover));
  });

  test('BusyMax preserves readable flat or darker GTK card samples', () {
    for (final card in const [Color(0xFF242424), Color(0xFF101010)]) {
      final colors = _buildBusyMaxTheme(
        brightness: Brightness.dark,
        gtkThemeColors: GtkThemeColors(
          brightness: Brightness.dark,
          window: const Color(0xFF202020),
          view: const Color(0xFF242424),
          card: card,
        ),
      ).extension<BusyMaxSurfaceColors>()!;

      expect(colors.card, card);
      expect(colors.groupedSurface, card);
      expect(colors.groupedSurface.a, 1);
    }
  });

  test('BusyMax keeps an opaque GTK card independent of floating surfaces', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF202020),
      view: Color(0xFF242424),
      card: Color(0xFF303030),
      dialog: Color(0xFF3E3E3E),
      popover: Color(0xFF3E3E3E),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;
    expect(colors.card, gtkColors.card);
    expect(colors.groupedSurface, gtkColors.card);
    expect(colors.groupedSurface.a, 1);
  });

  test('BusyMax dark sidebar preserves its named recessed boundary role', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF202020),
      view: Color(0xFF242424),
      sidebar: Color(0xFF303030),
      sidebarBorder: Color.fromRGBO(16, 16, 16, 0.35),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;

    expect(colors.sidebarBorder, gtkColors.sidebarBorder);
    expect(
      Color.alphaBlend(colors.sidebarBorder, colors.sidebar).computeLuminance(),
      lessThan(colors.sidebar.computeLuminance()),
    );
  });

  test(
    'BusyMax keeps native divider, card shade, and outline roles separate',
    () {
      const gtkColors = GtkThemeColors(
        brightness: Brightness.dark,
        window: Color(0xFF2C2C2C),
        card: Color(0xFF3D3D3D),
        divider: Color.fromRGBO(0, 0, 6, 0.56),
        cardShade: Color.fromRGBO(16, 16, 16, 0.35),
        floatingBorder: Color.fromRGBO(255, 255, 255, 0.14),
      );
      final colors = _buildBusyMaxTheme(
        brightness: Brightness.dark,
        gtkThemeColors: gtkColors,
      ).extension<BusyMaxSurfaceColors>()!;

      expect(colors.divider, gtkColors.divider);
      expect(colors.cardShade, gtkColors.cardShade);
      expect(colors.floatingBorder, gtkColors.floatingBorder);
      expect(colors.cardShade, isNot(colors.divider));
      expect(colors.cardShade, isNot(colors.floatingBorder));
    },
  );

  test('BusyMax uses the semantic card shade when GTK omits the role', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF2C2C2C),
      card: Color(0xFF3D3D3D),
      divider: Color.fromRGBO(255, 255, 255, 0.10),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;

    expect(
      colors.cardShade,
      busyMaxFallbackSurfaceColors(Brightness.dark).cardShade,
    );
    expect(colors.cardShade, isNot(colors.divider));
  });

  test('BusyMax theme preserves chromatic GTK dark surface samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF241F31),
      view: Color(0xFF241F31),
      sidebar: Color(0xFF4A4458),
      headerbar: Color(0xFF342F40),
      card: Color(0xFF4A4458),
      dialog: Color(0xFF342F40),
      popover: Color(0xFF342F40),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;

    expect(theme.scaffoldBackgroundColor, gtkColors.window);
    expect(theme.colorScheme.surface, gtkColors.view);
    _expectOpaqueMonotonicSurfaceContainers(theme);
    expect(theme.dialogTheme.backgroundColor, gtkColors.dialog);
    expect(colors.sidebar, gtkColors.sidebar);
    expect(colors.control, const Color.fromRGBO(255, 255, 255, 0.10));
    expect(colors.controlHover, const Color.fromRGBO(255, 255, 255, 0.14));
    expect(colors.dialog, gtkColors.dialog);
    expect(colors.popover, gtkColors.popover);
    expect(colors.groupedSurface, gtkColors.card);
  });

  test('BusyMax theme preserves chromatic GTK control samples', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      control: Color.fromRGBO(120, 180, 255, 0.12),
      controlHover: Color.fromRGBO(120, 180, 255, 0.18),
      controlActive: Color.fromRGBO(120, 180, 255, 0.24),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    expect(colors.control, gtkColors.control);
    expect(colors.controlHover, gtkColors.controlHover);
    expect(colors.controlActive, gtkColors.controlActive);
    _expectOpaqueMonotonicSurfaceContainers(theme);
    expect(theme.colorScheme.surfaceContainerHigh, isNot(gtkColors.control));
    expect(
      theme.colorScheme.surfaceContainerHighest,
      isNot(gtkColors.controlHover),
    );
  });

  test('BusyMax theme rejects an imperceptible GTK control ladder', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      control: Color.fromRGBO(0, 0, 0, 0.02),
      controlHover: Color.fromRGBO(0, 0, 0, 0.04),
      controlActive: Color.fromRGBO(0, 0, 0, 0.06),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;
    final fallback = busyMaxFallbackSurfaceColors(Brightness.light);

    expect(colors.control, fallback.control);
    expect(colors.controlHover, fallback.controlHover);
    expect(colors.controlActive, fallback.controlActive);
  });

  test(
    'BusyMax theme rejects GTK controls indistinguishable from surfaces',
    () {
      const gtkColors = GtkThemeColors(
        brightness: Brightness.light,
        control: Color.fromRGBO(255, 255, 255, 0.12),
        controlHover: Color.fromRGBO(255, 255, 255, 0.18),
        controlActive: Color.fromRGBO(255, 255, 255, 0.24),
      );
      final colors = _buildBusyMaxTheme(
        brightness: Brightness.light,
        gtkThemeColors: gtkColors,
      ).extension<BusyMaxSurfaceColors>()!;
      final fallback = busyMaxFallbackSurfaceColors(Brightness.light);

      expect(colors.control, fallback.control);
      expect(colors.controlHover, fallback.controlHover);
      expect(colors.controlActive, fallback.controlActive);
    },
  );

  test('BusyMax theme rejects opaque GTK widget samples as overlay roles', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      control: Color(0xFF2C2C2C),
      controlHover: Color(0xFF343434),
      controlActive: Color(0xFF131313),
      activeToggle: Color(0xFF343434),
      disabledControl: Color(0xFF202020),
    );
    final colors = _buildBusyMaxTheme(
      brightness: Brightness.dark,
      gtkThemeColors: gtkColors,
    ).extension<BusyMaxSurfaceColors>()!;
    final fallback = busyMaxFallbackSurfaceColors(Brightness.dark);

    expect(colors.control, fallback.control);
    expect(colors.controlHover, fallback.controlHover);
    expect(colors.controlActive, fallback.controlActive);
    expect(colors.activeToggle, fallback.activeToggle);
    expect(colors.disabledControl, fallback.disabledControl);
  });

  test('BusyMax theme preserves a flat custom sidebar role', () {
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
    expect(theme.extension<BusyMaxSurfaceColors>()?.sidebar, gtkColors.window);
  });

  test('BusyMax theme keeps GTK semantic roles independent', () {
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
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    expect(colors.sidebar, gtkColors.sidebar);
    expect(colors.headerbar, gtkColors.headerbar);
  });

  test('BusyMax theme preserves a readable black sidebar sample', () {
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

    expect(theme.scaffoldBackgroundColor, gtkColors.window);
    expect(theme.colorScheme.surface, gtkColors.view);
    expect(colors.sidebar, gtkColors.sidebar);
    expect(colors.headerbar, gtkColors.headerbar);
  });

  test('BusyMax theme preserves a flat near-black sidebar sample', () {
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

    expect(theme.scaffoldBackgroundColor, gtkColors.window);
    expect(theme.colorScheme.surface, gtkColors.view);
    expect(colors.sidebar, gtkColors.sidebar);
    expect(colors.headerbar, gtkColors.headerbar);
  });

  test('BusyMax theme composites translucent GTK surface layers', () {
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
    final window = Color.alphaBlend(
      gtkColors.window!,
      busyMaxFallbackSurfaceColors(Brightness.dark).window,
    );
    final view = Color.alphaBlend(gtkColors.view!, window);

    expect(theme.scaffoldBackgroundColor, window);
    expect(theme.colorScheme.surface, view);
    expect(colors.sidebar, Color.alphaBlend(gtkColors.sidebar!, window));
    expect(colors.headerbar, Color.alphaBlend(gtkColors.headerbar!, window));
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
    final fallback = busyMaxFallbackSurfaceColors(Brightness.dark);

    expect(colors.foreground, fallback.foreground);
    expect(colors.mutedForeground, fallback.mutedForeground);
    expect(colors.mutedForeground.a, 1);
    expect(theme.colorScheme.onSurface, colors.foreground);
    expect(theme.colorScheme.onSurfaceVariant, colors.mutedForeground);
  });

  test('BusyMax theme falls back only mixed-luminance GTK surface roles', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      window: Color(0xFFFFFFFF),
      view: Color(0xFFFFFFFF),
      sidebar: Color(0xFF101010),
      secondarySidebar: Color(0xFF111111),
      headerbar: Color(0xFF121212),
      headerbarFlat: Color(0xFF131313),
      card: Color(0xFFFFFFFF),
      dialog: Color(0xFF141414),
      popover: Color(0xFF151515),
    );
    final theme = _buildBusyMaxTheme(
      brightness: Brightness.light,
      gtkThemeColors: gtkColors,
    );
    final colors = theme.extension<BusyMaxSurfaceColors>()!;
    final fallback = busyMaxFallbackSurfaceColors(Brightness.light);

    expect(colors.window, gtkColors.window);
    expect(colors.view, gtkColors.view);
    expect(colors.card, gtkColors.card);
    expect(colors.sidebar, fallback.sidebar);
    expect(colors.secondarySidebar, fallback.secondarySidebar);
    expect(colors.headerbar, fallback.headerbar);
    expect(colors.headerbarFlat, fallback.headerbarFlat);
    expect(colors.dialog, fallback.dialog);
    expect(colors.popover, fallback.popover);
    expect(colors.foreground, fallback.foreground);
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

    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFAFA));
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

  test('native headerbar receives semantic surface colors', () {
    final source = File('lib/src/app/busymax_app.dart').readAsStringSync();
    final synchronizer = File(
      'lib/src/platform/linux_header_bar_configuration_synchronizer.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('final colors = theme.extension<BusyMaxSurfaceColors>()!;'),
    );
    expect(source, contains('_headerBarConfigurationSynchronizer.schedule('));
    expect(synchronizer, contains('await service.setTheme('));
    expect(source, contains('windowBackgroundColor: colors.window'));
    expect(source, contains('backgroundColor: colors.window'));
    expect(source, isNot(contains('backgroundColor: colors.headerbarFlat')));
    expect(source, isNot(contains('backgroundColor: colors.headerbar,')));
    expect(source, contains('sidebarBackgroundColor: colors.sidebar'));
    expect(source, contains('foregroundColor: colors.foreground'));
    expect(source, contains('sidebarBorderColor: colors.sidebarBorder'));
    expect(source, isNot(contains('popoverBackgroundColor:')));
    expect(source, isNot(contains('menuHoverColor:')));
    expect(source, isNot(contains('popoverShadowColor:')));
    expect(source, contains('dialogBackgroundColor: colors.dialog'));
    expect(source, isNot(contains('floatingBorderColor:')));
    expect(source, contains('modalBarrierColor: colors.shade'));
    expect(source, isNot(contains('controlHoverColor: colors.controlHover')));
    expect(source, isNot(contains('accentColor: colorScheme.primary')));
    expect(source, contains('menu: l10n.mainMenu'));
    expect(source, contains('settings: l10n.settings'));
    expect(source, contains('keyboardShortcuts: l10n.keyboardShortcuts'));
    expect(source, contains('aboutBusyMax: l10n.aboutBusyMax'));
    expect(source, isNot(contains('menu: materialL10n.moreButtonTooltip')));
    expect(source, isNot(contains('setBackgroundColor(')));
    expect(source, isNot(contains('setSidebarBackgroundColor(')));
  });

  test('root window uses semantic backing while GTK owns window geometry', () {
    final source = File('lib/src/app/busymax_app.dart').readAsStringSync();

    expect(source, isNot(contains('_BusyMaxWindowCornerClip')));
    expect(source, isNot(contains('ClipRRect(')));
    expect(source, contains('color: BusyMaxSurfaceColors.of(context).window'));
  });

  test('signed-out onboarding background matches main content surface', () {
    final source = File(
      'lib/src/features/auth/presentation/sign_in_screen.dart',
    ).readAsStringSync();

    expect(source, contains('color: BusyMaxSurfaceColors.of(context).window'));
    expect(
      source,
      isNot(contains('color: BusyMaxSurfaceColors.of(context).view')),
    );
    expect(source, contains('final title = context.l10n.onboardingSetupTitle'));
    expect(source, contains('.claimSession()'));
    expect(source, contains('_headerBarSession.updateState('));
    expect(source, contains('BusyMaxHeaderBarState('));
    expect(source, contains('title: title'));
    expect(source, isNot(contains('class _OnboardingHeader')));
    expect(source, isNot(contains('class _OnboardingProgressDots')));
    expect(source, isNot(contains('Border(top: BorderSide')));
    expect(source, contains("key: const ValueKey('onboarding-content-rail')"));
    expect(source, contains('busyMaxOnboardingContentMaxWidth'));
    expect(source, contains('width: contentRailWidth'));
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

  testWidgets('BusyMaxApp does not dim Flutter content when inactive', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
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

    ColoredBox flutterSurface() {
      final shortcuts = tester
          .widgetList<Shortcuts>(find.byType(Shortcuts))
          .firstWhere(
            (widget) =>
                widget.child is Actions &&
                (widget.child as Actions).child is ColoredBox,
          );
      return (shortcuts.child as Actions).child as ColoredBox;
    }

    expect(flutterSurface().child, isNot(isA<Opacity>()));
    expect(find.byKey(const ValueKey('busymax-window-backdrop')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(flutterSurface().child, isNot(isA<Opacity>()));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(flutterSurface().child, isNot(isA<Opacity>()));
  });

  testWidgets('tray startup waits for persisted start-minimized settings', (
    tester,
  ) async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final store = _DelayedSettingsStore();
    final windowService = _RecordingWindowService();
    _RecordingTrayService? trayService;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buildConfigProvider.overrideWithValue(_missingConfig),
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(store),
          linuxWindowServiceProvider.overrideWithValue(windowService),
        ],
        child: BusyMaxApp(
          trayServiceFactory: (configuration) =>
              trayService = _RecordingTrayService(configuration),
        ),
      ),
    );
    await tester.pump();

    expect(trayService?.startCalls ?? 0, 0);
    expect(windowService.hideWindowCalls, 0);

    store.completeLoad(<String, Object?>{
      'showTrayIcon': true,
      'runInBackgroundWhenClosed': true,
      'startMinimizedToTray': true,
    });
    await tester.pump();
    await tester.pump();

    expect(trayService!.startCalls, 1);
    expect(windowService.hideWindowCalls, 1);

    // A rebuild with the same loaded settings must not restart the tray or
    // hide an already-running window a second time.
    await tester.pump();
    expect(trayService!.startCalls, 1);
    expect(windowService.hideWindowCalls, 1);
  });

  testWidgets('tray Agenda opens the main window in Agenda mode', (
    tester,
  ) async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final windowService = _RecordingWindowService();
    late _RecordingTrayService trayService;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buildConfigProvider.overrideWithValue(_missingConfig),
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
          linuxWindowServiceProvider.overrideWithValue(windowService),
        ],
        child: BusyMaxApp(
          trayServiceFactory: (configuration) =>
              trayService = _RecordingTrayService(configuration),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await trayService.openAgenda();
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BusyMaxApp)),
    );
    final command = container.read(scheduleWorkspaceCommandProvider);
    expect(windowService.showWindowCalls, 1);
    expect(command?.kind, ScheduleWorkspaceCommandKind.agenda);
    expect(command?.date, isNotNull);
    expect(command!.date!.year, DateTime.now().year);
    expect(command.date!.month, DateTime.now().month);
    expect(command.date!.day, DateTime.now().day);
  });

  testWidgets('tray application actions use shared routing and commands', (
    tester,
  ) async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final windowService = _RecordingWindowService();
    var syncEnumerations = 0;
    final syncScheduler = AllAccountsSyncScheduler(
      listSyncEligibleAccounts: () async {
        syncEnumerations += 1;
        return const [];
      },
      syncAccount: (_) async {},
      onSyncFailure: (_) async {},
      interval: Duration.zero,
    );
    addTearDown(syncScheduler.dispose);
    late _RecordingTrayService trayService;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buildConfigProvider.overrideWithValue(_missingConfig),
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
          linuxWindowServiceProvider.overrideWithValue(windowService),
          syncSchedulerProvider.overrideWithValue(syncScheduler),
        ],
        child: BusyMaxApp(
          trayServiceFactory: (configuration) =>
              trayService = _RecordingTrayService(configuration),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BusyMaxApp)),
    );
    final router = container.read(appRouterProvider);
    final initialRoute = router.state.uri.toString();

    await trayService.configuration.actions.showBusyMax();
    expect(router.state.uri.toString(), initialRoute);

    await trayService.configuration.actions.newEvent();
    expect(
      container.read(scheduleWorkspaceCommandProvider)?.kind,
      ScheduleWorkspaceCommandKind.newEvent,
    );

    await trayService.configuration.actions.newTask();
    expect(
      container.read(scheduleWorkspaceCommandProvider)?.kind,
      ScheduleWorkspaceCommandKind.newTask,
    );

    final event = BusyMaxTrayEventEntry(
      eventId: 'event-id',
      accountId: 'account-id',
      calendarSourceId: 'source-id',
      title: 'Event',
      start: DateTime(2026, 8, 29, 10),
      end: DateTime(2026, 8, 29, 11),
      allDay: false,
    );
    await trayService.configuration.actions.openEvent(event);
    final openEvent = container.read(scheduleWorkspaceCommandProvider);
    expect(openEvent?.kind, ScheduleWorkspaceCommandKind.openCalendarEvent);
    expect(openEvent?.itemId, 'event-id');
    expect(openEvent?.accountId, 'account-id');
    expect(openEvent?.sourceId, 'source-id');

    await trayService.configuration.actions.openTasksDueToday();
    expect(
      container.read(scheduleWorkspaceCommandProvider)?.kind,
      ScheduleWorkspaceCommandKind.agenda,
    );
    await trayService.configuration.actions.openTodayAgenda();
    expect(
      container.read(scheduleWorkspaceCommandProvider)?.kind,
      ScheduleWorkspaceCommandKind.agenda,
    );

    await trayService.configuration.actions.openSettings();
    expect(router.state.uri.path, '/settings');

    final showsBeforeSync = windowService.showWindowCalls;
    await trayService.configuration.actions.synchronize();
    expect(syncEnumerations, 1);
    expect(windowService.showWindowCalls, showsBeforeSync);

    await trayService.configuration.actions.quitBusyMax();
    expect(windowService.quitAppCalls, 1);
  });

  testWidgets('demo mode retains the local tray entry', (tester) async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final windowService = _RecordingWindowService();
    late _RecordingTrayService trayService;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buildConfigProvider.overrideWithValue(_demoConfig),
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
          linuxWindowServiceProvider.overrideWithValue(windowService),
        ],
        child: BusyMaxApp(
          trayServiceFactory: (configuration) =>
              trayService = _RecordingTrayService(configuration),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(trayService.startCalls, 1);
    expect(trayService.available, isTrue);
    expect(windowService.hideWindowCalls, 0);
  });

  testWidgets('tray presentation follows offline and restored connectivity', (
    tester,
  ) async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final changes = StreamController<List<ConnectivityResult>>.broadcast(
      sync: true,
    );
    final monitor = NetworkConnectivityMonitor(
      checkConnectivity: () async => [ConnectivityResult.none],
      connectivityChanges: changes.stream,
    );
    addTearDown(() async {
      await monitor.dispose();
      await changes.close();
    });
    final windowService = _RecordingWindowService();
    late _RecordingTrayService trayService;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buildConfigProvider.overrideWithValue(_missingConfig),
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
          linuxWindowServiceProvider.overrideWithValue(windowService),
          networkConnectivityMonitorProvider.overrideWithValue(monitor),
        ],
        child: BusyMaxApp(
          trayServiceFactory: (configuration) =>
              trayService = _RecordingTrayService(configuration),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(trayService.offlineStates, contains(true));
    final refreshCallsBeforeConnectivityChange = trayService.refreshCalls;

    changes.add([ConnectivityResult.wifi]);
    for (var attempt = 0; attempt < 10; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 10));
      if (trayService.offlineStates.isNotEmpty &&
          trayService.offlineStates.last == false) {
        break;
      }
    }

    expect(
      trayService.refreshCalls,
      greaterThan(refreshCallsBeforeConnectivityChange),
    );
    final currentPresentation = await tester.runAsync(
      trayService.configuration.loadPresentation,
    );
    expect(currentPresentation!.offline, isFalse);
  });

  testWidgets('tray refreshes after privacy and locale changes', (
    tester,
  ) async {
    final database = AppDatabase.memoryForTests();
    addTearDown(database.close);
    final windowService = _RecordingWindowService();
    late _RecordingTrayService trayService;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buildConfigProvider.overrideWithValue(_missingConfig),
          databaseProvider.overrideWithValue(database),
          localSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
          linuxWindowServiceProvider.overrideWithValue(windowService),
        ],
        child: BusyMaxApp(
          trayServiceFactory: (configuration) =>
              trayService = _RecordingTrayService(configuration),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BusyMaxApp)),
    );
    final settings = container.read(appSettingsControllerProvider.notifier);

    var previousRefreshCalls = trayService.refreshCalls;
    await settings.setNotificationDetailLevel(NotificationDetailLevel.private);
    await tester.pump();
    expect(trayService.refreshCalls, greaterThan(previousRefreshCalls));

    previousRefreshCalls = trayService.refreshCalls;
    await settings.setLocaleTag('de');
    await tester.pump();
    expect(trayService.refreshCalls, greaterThan(previousRefreshCalls));
  });

  test('production sources avoid forbidden hardcoded accent colors', () {
    final disallowedHue = String.fromCharCodes([111, 114, 97, 110, 103, 101]);
    final forbidden = [
      '0xFF0D6E'
          'FD',
      'Colors.'
          'blue',
      'Colors.'
          'red',
      'Colors.$disallowedHue',
    ];
    final matches = <String>[];
    const centralizedAccentMapping = 'lib/src/app/system_accent.dart';

    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File) {
        continue;
      }
      final text = utf8.decode(entry.readAsBytesSync(), allowMalformed: true);
      final fileForbidden = entry.path == centralizedAccentMapping
          ? forbidden
          : [...forbidden, 'YaruVariant.', 'YaruColors.'];
      for (final token in fileForbidden) {
        if (text.contains(token)) {
          matches.add('${entry.path}: $token');
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

void _expectNeutralSurface(Color color) {
  final channels = color.toARGB32();
  final red = (channels >> 16) & 0xff;
  final green = (channels >> 8) & 0xff;
  final blue = channels & 0xff;
  expect(green, red, reason: '$color has a red/green surface tint');
  expect(blue, red, reason: '$color has a red/blue surface tint');
}

void _expectOpaqueMonotonicSurfaceContainers(ThemeData theme) {
  final containers = [
    theme.colorScheme.surfaceContainerLowest,
    theme.colorScheme.surfaceContainerLow,
    theme.colorScheme.surfaceContainer,
    theme.colorScheme.surfaceContainerHigh,
    theme.colorScheme.surfaceContainerHighest,
  ];
  for (final color in containers) {
    expect(
      color.a,
      1,
      reason: '${theme.brightness} surface containers must remain opaque',
    );
  }
  for (var index = 0; index < containers.length - 1; index++) {
    final current = containers[index].computeLuminance();
    final next = containers[index + 1].computeLuminance();
    expect(
      theme.brightness == Brightness.light ? current >= next : current <= next,
      isTrue,
      reason: '${theme.brightness} surface containers must follow elevation',
    );
  }
}

double _contrastRatio(Color foreground, Color background) {
  final effectiveForeground = foreground.a < 1
      ? Color.alphaBlend(foreground, background)
      : foreground;
  final foregroundLuminance = effectiveForeground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

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
  var showWindowCalls = 0;
  var quitAppCalls = 0;

  @override
  Future<void> hideWindow() async {
    hideWindowCalls += 1;
  }

  @override
  Future<void> showWindow() async {
    showWindowCalls += 1;
  }

  @override
  Future<void> quitApp() async {
    quitAppCalls += 1;
  }

  @override
  Future<void> setHideOnClose(bool enabled) async {}
}

class _RecordingTrayService extends BusyMaxTrayService {
  _RecordingTrayService(this.configuration)
    : super(configuration: configuration);

  final BusyMaxTrayServiceConfiguration configuration;

  var startCalls = 0;
  var refreshCalls = 0;
  var _available = false;
  final offlineStates = <bool>[];

  @override
  bool get available => _available;

  @override
  Future<void> start() async {
    startCalls += 1;
    _available = true;
    offlineStates.add(configuration.initialPresentation.offline);
  }

  @override
  Future<void> stop() async {
    _available = false;
  }

  @override
  Future<bool> refreshPresentation() async {
    refreshCalls += 1;
    final presentation = await configuration.loadPresentation();
    offlineStates.add(presentation.offline);
    return true;
  }

  Future<void> openAgenda() => configuration.actions.openTodayAgenda();
}

const _missingConfig = BuildConfig(
  googleOAuthClientId: '',
  googleOAuthClientSecret: '',
  apiBaseUrl: 'https://tasks.googleapis.com',
  oauthAuthorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  oauthTokenEndpoint: 'https://oauth2.googleapis.com/token',
  oauthRevocationEndpoint: 'https://oauth2.googleapis.com/revoke',
);

const _demoConfig = BuildConfig(
  googleOAuthClientId: '',
  googleOAuthClientSecret: '',
  oauthAuthorizationEndpoint: 'https://example.test/authorize',
  oauthTokenEndpoint: 'https://example.test/token',
  oauthRevocationEndpoint: 'https://example.test/revoke',
  useFakeProviderData: true,
);
