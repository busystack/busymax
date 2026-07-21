import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/theme.dart';

import '../platform/gtk_font_service.dart';
import 'busymax_design.dart';
import 'busymax_surface_colors.dart';

export 'busymax_surface_colors.dart';

abstract final class BusyMaxLinuxPalette {
  static const blueAccent = Color(0xFF3584E4);
  static const ubuntuBlueAccent = Color(0xFF0073E5);
  static const ubuntuTealAccent = Color(0xFF2190A4);
  static const ubuntuGreenAccent = Color(0xFF3A944A);
  static const ubuntuYellowAccent = Color(0xFFC88800);
  static const ubuntuOrangeAccent = Color(0xFFED5B00);
  static const ubuntuRedAccent = Color(0xFFDA3450);
  static const ubuntuPinkAccent = Color(0xFFD56199);
  static const ubuntuPurpleAccent = Color(0xFF7764D8);
  static const ubuntuSlateAccent = Color(0xFF6F8396);
  static const ubuntuBrownAccent = Color(0xFF986A44);
  static const ubuntuMagentaAccent = Color(0xFFB34CB3);
  static const ubuntuOliveAccent = Color(0xFF4B8501);
  static const ubuntuPrussianGreenAccent = Color(0xFF308280);
  static const ubuntuSageAccent = Color(0xFF657B69);
  static const ubuntuWartyBrownAccent = Color(0xFFB39169);
  static const red3 = Color(0xFFE01B24);
  static const red5 = Color(0xFFA51D2D);
  static const light1 = Color(0xFFFFFFFF);
  static const light2 = Color(0xFFF6F5F4);
  static const light3 = Color(0xFFDEDDDA);
  static const light4 = Color(0xFFC0BFBC);
  static const light5 = Color(0xFF9A9996);
  static const dark1 = Color(0xFF77767B);
  static const dark2 = Color(0xFF5E5C64);
  static const dark3 = Color(0xFF3D3846);
  static const dark4 = Color(0xFF241F31);
  static const dark5 = Color(0xFF000000);
  static const darkElevatedSurface = Color(0xFF383838);
}

class BusyMaxYaruTheme {
  const BusyMaxYaruTheme._();

  static ThemeData build({
    required Brightness brightness,
    required Color accentColor,
    String? gtkFontFamily,
    double? gtkFontSize,
    GtkThemeColors? gtkThemeColors,
  }) {
    final base = switch (brightness) {
      Brightness.light => createYaruLightTheme(
        primaryColor: BusyMaxLinuxPalette.light4,
      ),
      Brightness.dark => createYaruDarkTheme(
        primaryColor: BusyMaxLinuxPalette.light2,
      ),
    };
    final colors = _BusyMaxResolvedSurfaceColors(
      brightness,
      gtkThemeColors: gtkThemeColors,
    ).colors;
    final onAccent = contrastColor(accentColor);
    final accentContainer = Color.alphaBlend(
      accentColor.withValues(
        alpha: brightness == Brightness.dark ? 0.24 : 0.14,
      ),
      colors.view,
    );
    final colorScheme = base.colorScheme.copyWith(
      brightness: brightness,
      primary: accentColor,
      onPrimary: onAccent,
      primaryContainer: accentContainer,
      onPrimaryContainer: contrastColor(accentContainer),
      secondary: accentColor,
      error: brightness == Brightness.dark
          ? BusyMaxLinuxPalette.red3
          : BusyMaxLinuxPalette.red5,
      surface: colors.view,
      onSurface: colors.foreground,
      onSurfaceVariant: colors.mutedForeground,
      surfaceContainerLowest: colors.window,
      surfaceContainerLow: colors.view,
      surfaceContainer: colors.card,
      surfaceContainerHigh: colors.control,
      surfaceContainerHighest: colors.controlHover,
      outline: colors.border,
      outlineVariant: colors.subtleBorder,
      scrim: BusyMaxLinuxPalette.dark5,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: colors.border),
      borderRadius: BorderRadius.circular(6),
    );
    final focusedInputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: accentColor, width: 2),
      borderRadius: BorderRadius.circular(6),
    );
    final normalizer = _TextStyleNormalizer(
      gtkFontFamily: gtkFontFamily,
      gtkFontSize: gtkFontSize,
    );
    final textTheme = _busyMaxTextTheme(
      base.textTheme,
      brightness: brightness,
      colors: colors,
      normalizer: normalizer,
    );
    final inputDecorationTheme = base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: colors.control,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: focusedInputBorder,
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: normalizer.apply(
        base.inputDecorationTheme.labelStyle,
        fallback: textTheme.bodyMedium,
      ),
      floatingLabelStyle: normalizer.apply(
        base.inputDecorationTheme.floatingLabelStyle,
        fallback: textTheme.bodyMedium,
        color: accentColor,
      ),
      hintStyle: normalizer.apply(
        base.inputDecorationTheme.hintStyle,
        fallback: textTheme.bodyMedium,
        color: colors.mutedForeground,
      ),
      helperStyle: normalizer.apply(
        base.inputDecorationTheme.helperStyle,
        fallback: textTheme.bodySmall,
      ),
      errorStyle: normalizer.apply(
        base.inputDecorationTheme.errorStyle,
        fallback: textTheme.bodySmall,
        color: colorScheme.error,
      ),
      counterStyle: normalizer.apply(
        base.inputDecorationTheme.counterStyle,
        fallback: textTheme.bodySmall,
      ),
    );
    final outlinedButtonStyle = _buttonStyle(
      base.outlinedButtonTheme.style,
      shape: buttonShape,
      foreground: colors.foreground,
      background: colors.control,
      disabledForeground: colors.disabledForeground,
      disabledBackground: colors.disabledControl,
      textStyle: _normalizeTextStyleProperty(
        base.outlinedButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: textTheme.labelLarge,
      ),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: accentColor);
        }
        return BorderSide.none;
      }),
    );
    final filledButtonStyle = _buttonStyle(
      base.filledButtonTheme.style,
      shape: buttonShape,
      foreground: onAccent,
      background: accentColor,
      disabledForeground: colors.disabledForeground,
      disabledBackground: colors.disabledControl,
      overlayColor: _onAccentOverlay(onAccent),
      textStyle: _normalizeTextStyleProperty(
        base.filledButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: textTheme.labelLarge,
      ),
    );
    final elevatedButtonStyle = _buttonStyle(
      base.elevatedButtonTheme.style,
      shape: buttonShape,
      foreground: colors.foreground,
      background: colors.control,
      disabledForeground: colors.disabledForeground,
      disabledBackground: colors.disabledControl,
      textStyle: _normalizeTextStyleProperty(
        base.elevatedButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: textTheme.labelLarge,
      ),
    ).copyWith(elevation: const WidgetStatePropertyAll(0));
    final textButtonStyle = _buttonStyle(
      base.textButtonTheme.style,
      shape: buttonShape,
      foreground: accentColor,
      background: Colors.transparent,
      disabledForeground: colors.disabledForeground,
      disabledBackground: Colors.transparent,
      overlayColor: _accentOverlay(accentColor),
      textStyle: _normalizeTextStyleProperty(
        base.textButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: textTheme.labelLarge,
      ),
    );
    final segmentedButtonStyle =
        _buttonStyle(
          base.segmentedButtonTheme.style,
          shape: buttonShape,
          foreground: colors.foreground,
          background: colors.control,
          disabledForeground: colors.disabledForeground,
          disabledBackground: colors.disabledControl,
          overlayColor: _accentOverlay(accentColor),
          textStyle: _normalizeTextStyleProperty(
            base.segmentedButtonTheme.style?.textStyle,
            normalizer: normalizer,
            fallback: textTheme.labelLarge,
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BorderSide(color: accentColor);
            }
            return BorderSide(color: colors.border);
          }),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.disabledForeground;
            }
            if (states.contains(WidgetState.selected)) {
              return accentColor;
            }
            return colors.foreground;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentContainer;
            }
            return colors.control;
          }),
        );

    return base.copyWith(
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: accentColor,
      scaffoldBackgroundColor: colors.window,
      canvasColor: colors.window,
      cardColor: colors.card,
      extensions: [
        for (final extension in base.extensions.values)
          if (extension is! BusyMaxSurfaceColors) extension,
        colors,
      ],
      dividerColor: colors.subtleBorder,
      visualDensity: VisualDensity.compact,
      splashFactory: NoSplash.splashFactory,
      focusColor: accentColor.withValues(alpha: 0.18),
      hoverColor: colors.controlHover,
      splashColor: accentColor.withValues(alpha: 0.12),
      appBarTheme: base.appBarTheme.copyWith(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.headerbar,
        foregroundColor: colors.foreground,
        surfaceTintColor: colors.headerbar,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: normalizer.apply(
          base.appBarTheme.titleTextStyle,
          fallback: textTheme.titleMedium,
        ),
      ),
      textTheme: textTheme,
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: colors.dialog,
        surfaceTintColor: colors.dialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
        titleTextStyle: normalizer.apply(
          base.dialogTheme.titleTextStyle,
          fallback: textTheme.titleLarge,
        ),
        contentTextStyle: normalizer.apply(
          base.dialogTheme.contentTextStyle,
          fallback: textTheme.bodyMedium,
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        selectedColor: colors.foreground,
        selectedTileColor: accentContainer,
        iconColor: colors.mutedForeground,
        textColor: colors.foreground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        titleTextStyle: normalizer.apply(
          base.listTileTheme.titleTextStyle,
          fallback: textTheme.bodyMedium,
        ),
        subtitleTextStyle: normalizer.apply(
          base.listTileTheme.subtitleTextStyle,
          fallback: textTheme.bodySmall,
        ),
        leadingAndTrailingTextStyle: normalizer.apply(
          base.listTileTheme.leadingAndTrailingTextStyle,
          fallback: textTheme.labelSmall,
        ),
      ),
      inputDecorationTheme: inputDecorationTheme,
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
      textButtonTheme: TextButtonThemeData(style: textButtonStyle),
      iconButtonTheme: IconButtonThemeData(
        style: _buttonStyle(
          base.iconButtonTheme.style,
          shape: buttonShape,
          foreground: colors.mutedForeground,
          background: Colors.transparent,
          disabledForeground: colors.disabledForeground,
          disabledBackground: Colors.transparent,
          overlayColor: _accentOverlay(accentColor),
          textStyle: _normalizeTextStyleProperty(
            base.iconButtonTheme.style?.textStyle,
            normalizer: normalizer,
            fallback: textTheme.labelLarge,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledForeground;
          }
          if (states.contains(WidgetState.selected)) {
            return onAccent;
          }
          return colors.view;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledControl;
          }
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }
          return colors.controlHover;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }
          return colors.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledControl;
          }
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }
          return colors.control;
        }),
        checkColor: WidgetStatePropertyAll(onAccent),
        side: BorderSide(color: colors.border),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledForeground;
          }
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }
          return colors.mutedForeground;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: segmentedButtonStyle,
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: colors.popover,
        surfaceTintColor: colors.popover,
        elevation: BusyMaxElevation.popover,
        shadowColor: colors.shade,
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        iconColor: colors.mutedForeground,
        iconSize: 16,
        textStyle: normalizer.apply(
          base.popupMenuTheme.textStyle,
          fallback: textTheme.bodyMedium,
          color: colors.foreground,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: normalizer.apply(
          base.chipTheme.labelStyle,
          fallback: textTheme.labelLarge,
        ),
        secondaryLabelStyle: normalizer.apply(
          base.chipTheme.secondaryLabelStyle,
          fallback: textTheme.labelLarge,
        ),
      ),
      tooltipTheme: base.tooltipTheme.copyWith(
        decoration: BoxDecoration(
          color: colors.popover,
          borderRadius: BorderRadius.circular(BusyMaxRadius.headerButton),
          boxShadow: BusyMaxShadow.tooltipShadows(colors.shade),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: BusyMaxSpacing.tooltipHorizontal,
          vertical: BusyMaxSpacing.tooltipVertical,
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: colors.foreground),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        contentTextStyle: normalizer.apply(
          base.snackBarTheme.contentTextStyle,
          fallback: textTheme.bodyMedium,
        ),
      ),
      dataTableTheme: base.dataTableTheme.copyWith(
        headingTextStyle: normalizer.apply(
          base.dataTableTheme.headingTextStyle,
          fallback: textTheme.labelLarge,
        ),
        dataTextStyle: normalizer.apply(
          base.dataTableTheme.dataTextStyle,
          fallback: textTheme.bodyMedium,
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: (base.menuButtonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: _normalizeTextStyleProperty(
            base.menuButtonTheme.style?.textStyle,
            normalizer: normalizer,
            fallback: textTheme.labelLarge,
          ),
        ),
      ),
      dropdownMenuTheme: base.dropdownMenuTheme.copyWith(
        textStyle: normalizer.apply(
          base.dropdownMenuTheme.textStyle,
          fallback: textTheme.bodyMedium,
        ),
        inputDecorationTheme: inputDecorationTheme,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelStyle: normalizer.apply(
          base.tabBarTheme.labelStyle,
          fallback: textTheme.labelLarge,
        ),
        unselectedLabelStyle: normalizer.apply(
          base.tabBarTheme.unselectedLabelStyle,
          fallback: textTheme.labelLarge,
        ),
      ),
      navigationRailTheme: base.navigationRailTheme.copyWith(
        selectedLabelTextStyle: normalizer.apply(
          base.navigationRailTheme.selectedLabelTextStyle,
          fallback: textTheme.labelMedium,
        ),
        unselectedLabelTextStyle: normalizer.apply(
          base.navigationRailTheme.unselectedLabelTextStyle,
          fallback: textTheme.labelMedium,
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        labelTextStyle: _normalizeTextStyleProperty(
          base.navigationBarTheme.labelTextStyle,
          normalizer: normalizer,
          fallback: textTheme.labelMedium,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: onAccent,
        elevation: 0,
        focusColor: accentColor.withValues(alpha: 0.18),
        hoverColor: accentColor.withValues(alpha: 0.08),
        splashColor: accentColor.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        circularTrackColor: colors.control,
        linearTrackColor: colors.control,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: accentColor.withValues(alpha: 0.32),
        selectionHandleColor: accentColor,
      ),
    );
  }

  static TextTheme _busyMaxTextTheme(
    TextTheme base, {
    required Brightness brightness,
    required BusyMaxSurfaceColors colors,
    required _TextStyleNormalizer normalizer,
  }) {
    assert(brightness == Brightness.light || brightness == Brightness.dark);

    TextStyle? apply(TextStyle? style, {Color? color}) =>
        normalizer.apply(style, color: color);

    return base.copyWith(
      displayLarge: apply(base.displayLarge, color: colors.foreground),
      displayMedium: apply(base.displayMedium, color: colors.foreground),
      displaySmall: apply(base.displaySmall, color: colors.foreground),
      headlineLarge: apply(base.headlineLarge, color: colors.foreground),
      headlineMedium: apply(base.headlineMedium, color: colors.foreground),
      headlineSmall: apply(base.headlineSmall, color: colors.foreground),
      titleLarge: apply(base.titleLarge, color: colors.foreground),
      titleMedium: apply(base.titleMedium, color: colors.foreground),
      titleSmall: apply(base.titleSmall, color: colors.mutedForeground),
      bodyLarge: apply(base.bodyLarge, color: colors.foreground),
      bodyMedium: apply(base.bodyMedium, color: colors.foreground),
      bodySmall: apply(base.bodySmall, color: colors.mutedForeground),
      labelLarge: apply(base.labelLarge, color: colors.mutedForeground),
      labelMedium: apply(base.labelMedium, color: colors.mutedForeground),
      labelSmall: apply(base.labelSmall, color: colors.mutedForeground),
    );
  }
}

class _TextStyleNormalizer {
  _TextStyleNormalizer({String? gtkFontFamily, double? gtkFontSize})
    : _gtkFontFamily = _validFontFamily(gtkFontFamily),
      _fontScale = _validFontSize(gtkFontSize) == null
          ? null
          : _validFontSize(gtkFontSize)! / 11.0;

  final String? _gtkFontFamily;
  final double? _fontScale;

  TextStyle? apply(TextStyle? style, {TextStyle? fallback, Color? color}) {
    if (style == null) {
      if (fallback == null) {
        return null;
      }
      return color == null ? fallback : fallback.copyWith(color: color);
    }

    final scaledSize = _scaledFontSize(style.fontSize);
    if (_gtkFontFamily == null) {
      return style.copyWith(fontSize: scaledSize, color: color);
    }

    return TextStyle(
      inherit: style.inherit,
      color: color ?? style.color,
      backgroundColor: style.backgroundColor,
      fontSize: scaledSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      textBaseline: style.textBaseline,
      height: style.height,
      leadingDistribution: style.leadingDistribution,
      locale: style.locale,
      foreground: color == null ? style.foreground : null,
      background: style.background,
      shadows: style.shadows,
      fontFeatures: style.fontFeatures,
      fontVariations: style.fontVariations,
      decoration: style.decoration,
      decorationColor: style.decorationColor,
      decorationStyle: style.decorationStyle,
      decorationThickness: style.decorationThickness,
      debugLabel: style.debugLabel,
      fontFamily: _gtkFontFamily,
      overflow: style.overflow,
    );
  }

  double? _scaledFontSize(double? fontSize) {
    final scale = _fontScale;
    if (fontSize == null || scale == null) {
      return fontSize;
    }
    return fontSize * scale;
  }
}

class _BusyMaxResolvedSurfaceColors {
  _BusyMaxResolvedSurfaceColors(
    this.brightness, {
    GtkThemeColors? gtkThemeColors,
  }) : _runtime = gtkThemeColors?.brightness == brightness
           ? gtkThemeColors
           : null;

  final Brightness brightness;
  final GtkThemeColors? _runtime;

  BusyMaxSurfaceColors get colors {
    final fallback = busyMaxFallbackSurfaceColors(brightness);
    final runtime = _runtime;
    if (runtime == null) {
      return fallback;
    }

    final window =
        _runtimeSurfaceColor(runtime.window, brightness: brightness) ??
        fallback.window;
    final runtimeSidebar = _runtimeSurfaceColor(
      runtime.sidebar,
      brightness: brightness,
    );
    final runtimeSecondarySidebar = _runtimeSurfaceColor(
      runtime.secondarySidebar,
      brightness: brightness,
    );
    final runtimeView = _runtimeSurfaceColor(
      runtime.view,
      brightness: brightness,
    );
    final runtimeHeaderbar = _runtimeSurfaceColor(
      runtime.headerbar,
      brightness: brightness,
    );
    final runtimeHeaderbarFlat = _runtimeSurfaceColor(
      runtime.headerbarFlat,
      brightness: brightness,
    );
    final view = runtimeView ?? fallback.view;
    final sidebar =
        _firstDistinctSemanticColor(
          [runtimeSidebar, runtimeSecondarySidebar, runtimeHeaderbar],
          from: [view, window],
        ) ??
        _derivedSidebarColor(brightness, view);
    final readableBackgrounds = [window, view, sidebar];

    return fallback.copyWith(
      window: window,
      view: view,
      sidebar: sidebar,
      secondarySidebar: runtimeSecondarySidebar,
      headerbar: runtimeHeaderbar,
      headerbarFlat: runtimeHeaderbarFlat ?? view,
      card: _runtimeSurfaceColor(runtime.card, brightness: brightness),
      dialog: _runtimeSurfaceColor(runtime.dialog, brightness: brightness),
      popover: _runtimeElevatedSurfaceColor(
        runtime.popover,
        brightness: brightness,
      ),
      control: _runtimeControlColor(runtime.control, brightness: brightness),
      controlHover: _runtimeControlColor(
        runtime.controlHover,
        brightness: brightness,
      ),
      controlActive: _runtimeControlColor(
        runtime.controlActive,
        brightness: brightness,
      ),
      activeToggle: _runtimeColor(runtime.activeToggle),
      foreground: _runtimeReadableColor(
        runtime.foreground,
        backgrounds: readableBackgrounds,
      ),
      mutedForeground: _runtimeReadableColor(
        runtime.mutedForeground,
        backgrounds: readableBackgrounds,
        minContrast: 3.0,
      ),
      disabledForeground: _runtimeReadableColor(
        runtime.disabledForeground,
        backgrounds: readableBackgrounds,
        minContrast: 1.5,
      ),
      disabledControl: _runtimeColor(runtime.disabledControl),
      border: _runtimeColor(runtime.border),
      subtleBorder: _runtimeColor(runtime.subtleBorder),
      sidebarBorder: _runtimeColor(runtime.sidebarBorder),
      shade: _runtimeShadeColor(runtime.shade),
    );
  }
}

Color? _runtimeColor(Color? color) {
  if (color == null || color.a <= 0) {
    return null;
  }
  return color;
}

Color? _runtimeShadeColor(Color? color) {
  final runtime = _runtimeColor(color);
  if (runtime == null) {
    return null;
  }
  if (runtime.computeLuminance() > 0.35) {
    return null;
  }
  return runtime;
}

Color? _runtimeReadableColor(
  Color? color, {
  required Iterable<Color> backgrounds,
  double minContrast = 4.5,
}) {
  final runtime = _runtimeColor(color);
  if (runtime == null) {
    return null;
  }
  for (final background in backgrounds) {
    if (_contrastRatio(runtime, background) < minContrast) {
      return null;
    }
  }
  return runtime;
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

Color? _runtimeSurfaceColor(Color? color, {Brightness? brightness}) {
  final runtime = _runtimeColor(color);
  if (runtime == null) {
    return null;
  }
  if (runtime.a < 0.98 || _isNearBlackSurface(runtime)) {
    return null;
  }
  if (brightness == Brightness.dark && _isTintedDarkSurface(runtime)) {
    return null;
  }
  return runtime;
}

Color? _runtimeControlColor(Color? color, {required Brightness brightness}) {
  final runtime = _runtimeColor(color);
  if (runtime == null) {
    return null;
  }
  if (_isChromaticControlColor(runtime)) {
    return null;
  }
  if (brightness == Brightness.dark &&
      runtime.a >= 0.98 &&
      _isTintedDarkSurface(runtime)) {
    return null;
  }
  return runtime;
}

Color? _runtimeElevatedSurfaceColor(
  Color? color, {
  required Brightness brightness,
}) {
  final runtime = _runtimeSurfaceColor(color, brightness: brightness);
  if (runtime == null) {
    return null;
  }
  if (brightness == Brightness.dark && _isTooDarkElevatedSurface(runtime)) {
    return null;
  }
  return runtime;
}

bool _isTooDarkElevatedSurface(Color color) {
  final value = color.toARGB32();
  final red = (value >> 16) & 0xff;
  final green = (value >> 8) & 0xff;
  final blue = value & 0xff;
  return red < 0x38 || green < 0x38 || blue < 0x38;
}

bool _isNearBlackSurface(Color color) {
  final value = color.toARGB32();
  final red = (value >> 16) & 0xff;
  final green = (value >> 8) & 0xff;
  final blue = value & 0xff;
  return red <= 24 && green <= 24 && blue <= 24;
}

bool _isTintedDarkSurface(Color color) {
  return _isBlueDominantColor(color);
}

bool _isBlueDominantColor(Color color) {
  final value = color.toARGB32();
  final red = (value >> 16) & 0xff;
  final green = (value >> 8) & 0xff;
  final blue = value & 0xff;
  final maxChannel = math.max(red, math.max(green, blue));
  final minChannel = math.min(red, math.min(green, blue));
  return blue == maxChannel && maxChannel - minChannel >= 10;
}

bool _isChromaticControlColor(Color color) {
  final value = color.toARGB32();
  final red = (value >> 16) & 0xff;
  final green = (value >> 8) & 0xff;
  final blue = value & 0xff;
  final maxChannel = math.max(red, math.max(green, blue));
  final minChannel = math.min(red, math.min(green, blue));
  return maxChannel - minChannel >= 10;
}

Color? _firstDistinctSemanticColor(
  Iterable<Color?> candidates, {
  required Iterable<Color> from,
}) {
  for (final candidate in candidates) {
    if (candidate == null) {
      continue;
    }
    final duplicatesExisting = from.any(
      (existing) => _sameSemanticColor(candidate, existing),
    );
    if (!duplicatesExisting) {
      return candidate;
    }
  }
  return null;
}

Color _derivedSidebarColor(Brightness brightness, Color base) {
  final overlay = brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.055)
      : Colors.black.withValues(alpha: 0.045);
  return Color.alphaBlend(overlay, base);
}

bool _sameSemanticColor(Color left, Color right) {
  final leftValue = left.toARGB32();
  final rightValue = right.toARGB32();
  return ((leftValue >> 24) & 0xff) == ((rightValue >> 24) & 0xff) &&
      ((leftValue >> 16) & 0xff) == ((rightValue >> 16) & 0xff) &&
      ((leftValue >> 8) & 0xff) == ((rightValue >> 8) & 0xff) &&
      (leftValue & 0xff) == (rightValue & 0xff);
}

String? _validFontFamily(String? family) {
  final trimmed = family?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

double? _validFontSize(double? size) {
  if (size == null || size <= 0 || size.isNaN || size.isInfinite) {
    return null;
  }
  return size;
}

WidgetStateProperty<TextStyle?> _normalizeTextStyleProperty(
  WidgetStateProperty<TextStyle?>? property, {
  required _TextStyleNormalizer normalizer,
  required TextStyle? fallback,
}) {
  return WidgetStateProperty.resolveWith((states) {
    return normalizer.apply(property?.resolve(states), fallback: fallback);
  });
}

ButtonStyle _buttonStyle(
  ButtonStyle? base, {
  required OutlinedBorder shape,
  required Color foreground,
  required Color background,
  required Color disabledForeground,
  required Color disabledBackground,
  WidgetStateProperty<Color?>? overlayColor,
  WidgetStateProperty<BorderSide?>? side,
  WidgetStateProperty<TextStyle?>? textStyle,
}) {
  return (base ?? const ButtonStyle()).copyWith(
    visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    textStyle: textStyle,
    shape: WidgetStatePropertyAll(shape),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabledForeground;
      }
      return foreground;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabledBackground;
      }
      return background;
    }),
    overlayColor: overlayColor ?? _controlOverlay(foreground),
    side: side ?? const WidgetStatePropertyAll(BorderSide.none),
    elevation: const WidgetStatePropertyAll(0),
  );
}

WidgetStateProperty<Color?> _controlOverlay(Color foreground) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return foreground.withValues(alpha: 0.14);
    }
    if (states.contains(WidgetState.hovered)) {
      return foreground.withValues(alpha: 0.08);
    }
    if (states.contains(WidgetState.focused)) {
      return foreground.withValues(alpha: 0.10);
    }
    return null;
  });
}

WidgetStateProperty<Color?> _accentOverlay(Color accentColor) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return accentColor.withValues(alpha: 0.14);
    }
    if (states.contains(WidgetState.hovered)) {
      return accentColor.withValues(alpha: 0.08);
    }
    if (states.contains(WidgetState.focused)) {
      return accentColor.withValues(alpha: 0.12);
    }
    return null;
  });
}

WidgetStateProperty<Color?> _onAccentOverlay(Color accentForeground) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return accentForeground.withValues(alpha: 0.14);
    }
    if (states.contains(WidgetState.hovered)) {
      return accentForeground.withValues(alpha: 0.08);
    }
    if (states.contains(WidgetState.focused)) {
      return accentForeground.withValues(alpha: 0.12);
    }
    return null;
  });
}
