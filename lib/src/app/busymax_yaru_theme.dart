import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/theme.dart';

import '../platform/gtk_font_service.dart';
import 'busymax_design.dart';
import 'busymax_surface_colors.dart';

export 'busymax_surface_colors.dart';

const _minimumRaisedSurfaceContrast = 1.08;

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
  static const light2 = Color(0xFFF6F5F4);
  static const light4 = Color(0xFFC0BFBC);
  static const dark5 = Color(0xFF000000);
}

class BusyMaxYaruTheme {
  const BusyMaxYaruTheme._();

  static ThemeData build({
    required Brightness brightness,
    required Color accentColor,
    String? gtkFontFamily,
    double? gtkFontSize,
    GtkThemeColors? gtkThemeColors,
    bool highContrast = false,
  }) {
    final base = switch (brightness) {
      Brightness.light => createYaruLightTheme(primaryColor: accentColor),
      Brightness.dark => createYaruDarkTheme(
        primaryColor: accentColor,
        highContrast: highContrast,
      ),
    };
    final resolvedColors = _BusyMaxResolvedSurfaceColors(
      brightness,
      gtkThemeColors: gtkThemeColors,
    ).colors;
    final colors = highContrast
        ? _highContrastSurfaceColors(brightness)
        : resolvedColors;
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
      error: highContrast
          ? base.colorScheme.error
          : brightness == Brightness.dark
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
    final outlinedButtonStyle = _semanticButtonStyle(
      base.outlinedButtonTheme.style,
      foreground: colors.foreground,
      background: Colors.transparent,
      disabledForeground: colors.disabledForeground,
      disabledBackground: Colors.transparent,
      textStyle: _normalizeTextStyleProperty(
        base.outlinedButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: textTheme.labelLarge,
      ),
    );
    final filledButtonStyle = _semanticButtonStyle(
      base.filledButtonTheme.style,
      foreground: colors.foreground,
      background: colors.control,
      disabledForeground: colors.disabledForeground,
      disabledBackground: colors.disabledControl,
      textStyle: _normalizeTextStyleProperty(
        base.filledButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: textTheme.labelLarge,
      ),
    );
    final elevatedButtonStyle = _semanticButtonStyle(
      base.elevatedButtonTheme.style,
      foreground: onAccent,
      background: accentColor,
      disabledForeground: colors.disabledForeground,
      disabledBackground: colors.disabledControl,
      textStyle: _normalizeTextStyleProperty(
        base.elevatedButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: textTheme.labelLarge,
      ),
    );
    final textButtonStyle = _semanticButtonStyle(
      base.textButtonTheme.style,
      foreground: accentColor,
      background: Colors.transparent,
      disabledForeground: colors.disabledForeground,
      disabledBackground: Colors.transparent,
      textStyle: _normalizeTextStyleProperty(
        base.textButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: textTheme.labelLarge,
      ),
    );
    final toggleButtonsTheme = base.toggleButtonsTheme.copyWith(
      color: colors.foreground,
      selectedColor: colors.foreground,
      disabledColor: colors.disabledForeground,
      fillColor: colors.controlActive,
      borderColor: colors.border,
      selectedBorderColor: colors.border,
      disabledBorderColor: colors.disabledForeground,
      hoverColor: colors.controlHover,
      highlightColor: colors.controlActive,
      splashColor: colors.controlHover,
      focusColor: colors.controlActive,
    );
    final menuStyle = _semanticMenuSurfaceStyle(
      base.menuTheme.style,
      color: colors.popover,
      shadowColor: colorScheme.shadow,
    );
    final dropdownMenuStyle = _semanticMenuSurfaceStyle(
      base.dropdownMenuTheme.menuStyle,
      color: colors.popover,
      shadowColor: colorScheme.shadow,
    );

    return base.copyWith(
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: accentColor,
      shadowColor: colorScheme.shadow,
      scaffoldBackgroundColor: colors.window,
      canvasColor: colors.window,
      cardColor: colors.card,
      extensions: [
        for (final extension in base.extensions.values)
          if (extension is! BusyMaxSurfaceColors) extension,
        colors,
      ],
      dividerColor: colors.subtleBorder,
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
        style: _semanticButtonStyle(
          base.iconButtonTheme.style,
          foreground: colors.foreground,
          background: Colors.transparent,
          disabledForeground: colors.disabledForeground,
          disabledBackground: Colors.transparent,
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
      toggleButtonsTheme: toggleButtonsTheme,
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: colors.popover,
        surfaceTintColor: colors.popover,
        elevation: BusyMaxElevation.popover,
        shadowColor: colorScheme.shadow,
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        iconColor: colors.mutedForeground,
        iconSize: 16,
        textStyle: normalizer.apply(
          base.popupMenuTheme.textStyle,
          fallback: textTheme.bodyMedium,
          color: colors.foreground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: highContrast
              ? BorderSide(color: colors.border)
              : BorderSide.none,
        ),
      ),
      menuTheme: MenuThemeData(
        style: menuStyle,
        submenuIcon: base.menuTheme.submenuIcon,
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
          border: highContrast ? Border.all(color: colors.border) : null,
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
        menuStyle: dropdownMenuStyle,
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

BusyMaxSurfaceColors _highContrastSurfaceColors(Brightness brightness) {
  final background = brightness == Brightness.dark
      ? Colors.black
      : Colors.white;
  final foreground = contrastColor(background);
  Color layer(double opacity) =>
      Color.alphaBlend(foreground.withValues(alpha: opacity), background);

  // High contrast is an accessibility contract, so it intentionally uses one
  // coherent palette instead of retaining GTK surfaces that may have mixed
  // luminance. Normal themes continue to preserve every valid GTK role.
  return BusyMaxSurfaceColors(
    window: background,
    view: background,
    sidebar: background,
    secondarySidebar: background,
    headerbar: background,
    headerbarFlat: background,
    card: background,
    groupedSurface: background,
    dialog: background,
    popover: background,
    control: layer(0.10),
    controlHover: layer(0.18),
    controlActive: layer(0.28),
    activeToggle: layer(0.22),
    foreground: foreground,
    mutedForeground: foreground,
    disabledForeground: layer(0.55),
    disabledControl: layer(0.06),
    border: foreground,
    subtleBorder: foreground,
    sidebarBorder: foreground,
    shade: Colors.black,
  );
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

    // GTK surface colors may be translucent CSS layers. Resolve them against
    // their semantic parent instead of rejecting valid native theme colors or
    // trying to infer whether a theme's hue is aesthetically acceptable.
    final sampledWindow =
        _runtimeSurfaceColor(runtime.window, over: fallback.window) ??
        fallback.window;
    final sampledView =
        _runtimeSurfaceColor(runtime.view, over: sampledWindow) ??
        fallback.view;
    final runtimeSidebar = _runtimeSurfaceColor(
      runtime.sidebar,
      over: sampledWindow,
    );
    final sampledSidebar = runtimeSidebar ?? fallback.sidebar;
    final runtimeSecondarySidebar = _runtimeSurfaceColor(
      runtime.secondarySidebar,
      over: sampledWindow,
    );
    final sampledSecondarySidebar =
        runtimeSecondarySidebar ?? fallback.secondarySidebar;
    final runtimeHeaderbar = _runtimeSurfaceColor(
      runtime.headerbar,
      over: sampledWindow,
    );
    final sampledHeaderbar = runtimeHeaderbar ?? fallback.headerbar;
    final sampledHeaderbarFlat =
        _runtimeSurfaceColor(runtime.headerbarFlat, over: sampledView) ??
        sampledView;
    final runtimeCard = _runtimeSurfaceColor(runtime.card, over: sampledWindow);
    final sampledCard = runtimeCard ?? fallback.card;
    final runtimeDialog = _runtimeSurfaceColor(
      runtime.dialog,
      over: sampledWindow,
    );
    final sampledDialog = runtimeDialog ?? fallback.dialog;
    final runtimePopover = _runtimeSurfaceColor(
      runtime.popover,
      over: sampledWindow,
    );
    final sampledPopover = runtimePopover ?? fallback.popover;
    final sampledBackgrounds = [
      sampledWindow,
      sampledView,
      sampledSidebar,
      sampledSecondarySidebar,
      sampledHeaderbar,
      sampledHeaderbarFlat,
      sampledCard,
      sampledDialog,
      sampledPopover,
    ];
    final foreground =
        _runtimeReadableColor(
          runtime.foreground,
          backgrounds: sampledBackgrounds,
        ) ??
        fallback.foreground;

    Color readableSurface(Color sampled, Color fallbackSurface) {
      return _contrastRatio(foreground, sampled) >= 4.5
          ? sampled
          : fallbackSurface;
    }

    // BusyMax currently has one generic foreground role. Preserve compatible
    // GTK roles when that foreground remains readable; raised roles receive
    // the additional hierarchy validation below.
    final window = readableSurface(sampledWindow, fallback.window);
    final view = readableSurface(sampledView, fallback.view);
    final sidebar = _resolvedRaisedSurface(
      runtimeSidebar,
      brightness: brightness,
      parent: window,
      foreground: foreground,
      fallback: fallback.sidebar,
    );
    final secondarySidebar = _resolvedRaisedSurface(
      runtimeSecondarySidebar,
      brightness: brightness,
      parent: window,
      foreground: foreground,
      fallback: fallback.secondarySidebar,
    );
    final headerbar = _resolvedRaisedSurface(
      runtimeHeaderbar,
      brightness: brightness,
      parent: window,
      foreground: foreground,
      fallback: fallback.headerbar,
    );
    final headerbarFlat = readableSurface(
      sampledHeaderbarFlat,
      fallback.headerbarFlat,
    );
    final card = _resolvedRaisedSurface(
      runtimeCard,
      brightness: brightness,
      parent: window,
      foreground: foreground,
      fallback: fallback.card,
    );
    final dialog = _resolvedRaisedSurface(
      runtimeDialog,
      brightness: brightness,
      parent: window,
      foreground: foreground,
      fallback: fallback.dialog,
    );
    final popover = _resolvedRaisedSurface(
      runtimePopover,
      brightness: brightness,
      parent: window,
      foreground: foreground,
      fallback: fallback.popover,
    );
    // Boxed/grouped content is one semantic card role. Keeping a single
    // resolved token prevents Settings, Agenda, and Year view from drifting.
    final groupedSurface = card;
    final sidebarBorder = _resolvedSidebarBorder(
      runtime.sidebarBorder,
      brightness: brightness,
      sidebar: sidebar,
      fallback: fallback.sidebarBorder,
    );
    final readableBackgrounds = [
      window,
      view,
      sidebar,
      secondarySidebar,
      headerbar,
      headerbarFlat,
      card,
      dialog,
      popover,
    ];
    final mutedForeground = _resolvedReadableColor(
      runtime.mutedForeground,
      fallback: fallback.mutedForeground,
      guaranteed: foreground,
      backgrounds: readableBackgrounds,
      minContrast: 3,
    );
    final disabledForeground = _resolvedReadableColor(
      runtime.disabledForeground,
      fallback: fallback.disabledForeground,
      guaranteed: foreground,
      backgrounds: readableBackgrounds,
      minContrast: 1.5,
    );

    return fallback.copyWith(
      window: window,
      view: view,
      sidebar: sidebar,
      secondarySidebar: secondarySidebar,
      headerbar: headerbar,
      headerbarFlat: headerbarFlat,
      card: card,
      groupedSurface: groupedSurface,
      dialog: dialog,
      popover: popover,
      control: _runtimeOverlayColor(runtime.control),
      controlHover: _runtimeOverlayColor(runtime.controlHover),
      controlActive: _runtimeOverlayColor(runtime.controlActive),
      activeToggle: _runtimeOverlayColor(runtime.activeToggle),
      foreground: foreground,
      mutedForeground: mutedForeground,
      disabledForeground: disabledForeground,
      disabledControl: _runtimeOverlayColor(runtime.disabledControl),
      border: _runtimeColor(runtime.border),
      subtleBorder: _runtimeColor(runtime.subtleBorder),
      sidebarBorder: sidebarBorder,
      shade: _runtimeShadeColor(runtime.shade, over: popover),
    );
  }
}

Color _resolvedRaisedSurface(
  Color? runtimeSurface, {
  required Brightness brightness,
  required Color parent,
  required Color foreground,
  required Color fallback,
}) {
  bool isReadable(Color color) => _contrastRatio(foreground, color) >= 4.5;

  bool hasExpectedHierarchy(Color color) {
    if (brightness != Brightness.dark) {
      return true;
    }
    return color.computeLuminance() > parent.computeLuminance() &&
        _contrastRatio(color, parent) >= _minimumRaisedSurfaceContrast;
  }

  if (runtimeSurface != null &&
      isReadable(runtimeSurface) &&
      hasExpectedHierarchy(runtimeSurface)) {
    return runtimeSurface;
  }
  if (isReadable(fallback) && hasExpectedHierarchy(fallback)) {
    return fallback;
  }

  // A fixed fallback may itself be recessed against a brighter custom theme.
  // Flat is safer than inverting the intended raised hierarchy.
  return parent;
}

Color _resolvedSidebarBorder(
  Color? runtimeBorder, {
  required Brightness brightness,
  required Color sidebar,
  required Color fallback,
}) {
  final candidate = _runtimeColor(runtimeBorder);
  if (candidate == null || brightness != Brightness.dark) {
    return candidate ?? fallback;
  }
  final effective = candidate.a < 1
      ? Color.alphaBlend(candidate, sidebar)
      : candidate;
  // A dark separator sampled from GTK's generic `borders` token becomes a
  // heavy inset edge on a dark sidebar. Retain native light separators and
  // use the semantic fallback when the sample is visually recessed.
  return effective.computeLuminance() < sidebar.computeLuminance()
      ? fallback
      : candidate;
}

Color? _runtimeColor(Color? color) {
  if (color == null || color.a <= 0) {
    return null;
  }
  return color;
}

Color? _runtimeOverlayColor(Color? color) {
  final candidate = _runtimeColor(color);
  if (candidate == null || candidate.a >= 1) {
    return null;
  }
  return candidate;
}

Color? _runtimeShadeColor(Color? color, {required Color over}) {
  final runtime = _runtimeColor(color);
  if (runtime == null) {
    return null;
  }
  final shaded = Color.alphaBlend(runtime, over);
  return shaded.computeLuminance() < over.computeLuminance() ? runtime : null;
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

Color _resolvedReadableColor(
  Color? runtime, {
  required Color fallback,
  required Color guaranteed,
  required Iterable<Color> backgrounds,
  required double minContrast,
}) {
  return _runtimeReadableColor(
        runtime,
        backgrounds: backgrounds,
        minContrast: minContrast,
      ) ??
      _runtimeReadableColor(
        fallback,
        backgrounds: backgrounds,
        minContrast: minContrast,
      ) ??
      guaranteed;
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

Color? _runtimeSurfaceColor(Color? color, {required Color over}) {
  final runtime = _runtimeColor(color);
  if (runtime == null) {
    return null;
  }
  return runtime.a < 1 ? Color.alphaBlend(runtime, over) : runtime;
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

/// Applies only the semantic floating-surface roles and retains Yaru's menu
/// geometry, item states, padding, and motion.
MenuStyle _semanticMenuSurfaceStyle(
  MenuStyle? base, {
  required Color color,
  required Color shadowColor,
}) {
  return (base ?? const MenuStyle()).copyWith(
    backgroundColor: WidgetStatePropertyAll(color),
    surfaceTintColor: WidgetStatePropertyAll(color),
    shadowColor: WidgetStatePropertyAll(shadowColor),
  );
}

/// Applies runtime semantic colors and typography without replacing Yaru's
/// geometry, focus treatment, hover/press overlays, or motion defaults.
ButtonStyle _semanticButtonStyle(
  ButtonStyle? base, {
  required Color foreground,
  required Color background,
  required Color disabledForeground,
  required Color disabledBackground,
  WidgetStateProperty<TextStyle?>? textStyle,
}) {
  return (base ?? const ButtonStyle()).copyWith(
    textStyle: textStyle,
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
  );
}
