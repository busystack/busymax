import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/theme.dart';

import '../platform/gtk_font_service.dart';
import 'busymax_design.dart';
import 'busymax_surface_colors.dart';

export 'busymax_surface_colors.dart';

const _minimumControlSurfaceContrast = 1.02;

abstract final class BusyMaxLinuxPalette {
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
    final surfaceContainers = _surfaceContainerLadder(colors, brightness);
    final sampledAccentForeground =
        gtkThemeColors?.brightness == brightness &&
            gtkThemeColors?.accent == accentColor
        ? gtkThemeColors?.accentForeground
        : null;
    final onAccent =
        sampledAccentForeground != null &&
            _contrastRatio(sampledAccentForeground, accentColor) >= 4.5
        ? sampledAccentForeground
        : contrastColor(accentColor);
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
      // Generic Material surfaces need opaque elevation roles. The translucent
      // control ladder belongs exclusively to interactive widget states.
      surfaceContainerLowest: surfaceContainers.lowest,
      surfaceContainerLow: surfaceContainers.low,
      surfaceContainer: surfaceContainers.container,
      surfaceContainerHigh: surfaceContainers.high,
      surfaceContainerHighest: surfaceContainers.highest,
      outline: colors.border,
      outlineVariant: colors.divider,
      scrim: BusyMaxLinuxPalette.dark5,
    );
    final normalizer = _TextStyleNormalizer(
      gtkFontFamily: gtkFontFamily,
      gtkFontSize: gtkFontSize,
    );
    final textTheme = _busyMaxTextTheme(
      base.textTheme,
      colors: colors,
      normalizer: normalizer,
    );
    final inputDecorationTheme = _semanticInputDecorationTheme(
      base.inputDecorationTheme,
      colors: colors,
      accentColor: accentColor,
      errorColor: colorScheme.error,
      normalizer: normalizer,
      textTheme: textTheme,
    );
    final dropdownInputDecorationTheme = _semanticInputDecorationTheme(
      base.dropdownMenuTheme.inputDecorationTheme ?? base.inputDecorationTheme,
      colors: colors,
      accentColor: accentColor,
      errorColor: colorScheme.error,
      normalizer: normalizer,
      textTheme: textTheme,
    );
    final outlinedButtonStyle = _semanticButtonStyle(
      _yaruDesktopButtonStyle(base.outlinedButtonTheme.style),
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
      _yaruDesktopButtonStyle(base.filledButtonTheme.style),
      foreground: colors.foreground,
      background: colors.control,
      selectedBackground: colors.controlActive,
      disabledForeground: colors.disabledForeground,
      disabledBackground: colors.disabledControl,
      textStyle: _normalizeTextStyleProperty(
        base.filledButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: textTheme.labelLarge,
      ),
    );
    final elevatedButtonStyle = _semanticButtonStyle(
      _yaruDesktopButtonStyle(base.elevatedButtonTheme.style),
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
      _yaruDesktopButtonStyle(base.textButtonTheme.style),
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
    final popoverSurfaceSide = BorderSide(
      color: highContrast ? colors.border : colors.floatingBorder,
    );
    final dialogSurfaceSide = BorderSide(
      color: highContrast ? colors.border : colors.dialogOutline,
    );
    final menuStyle = _semanticMenuSurfaceStyle(
      base.menuTheme.style,
      color: colors.popover,
      shadowColor: colorScheme.shadow,
      side: popoverSurfaceSide,
    );
    final dropdownMenuStyle = _semanticMenuSurfaceStyle(
      base.dropdownMenuTheme.menuStyle,
      color: colors.popover,
      shadowColor: colorScheme.shadow,
      side: popoverSurfaceSide,
    );
    final cardTheme = base.cardTheme.copyWith(
      // Filled Flutter surfaces must be opaque. [colors.card] is the semantic
      // GTK layer precomposited over the window/editor surface by the resolver.
      // Card and Yaru continue to own elevation and shadow geometry.
      color: colors.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: colorScheme.shadow,
      elevation: BusyMaxElevation.groupedCard,
      shape:
          base.cardTheme.shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BusyMaxRadius.md),
          ),
    );

    return base.copyWith(
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: accentColor,
      shadowColor: colorScheme.shadow,
      scaffoldBackgroundColor: colors.window,
      canvasColor: colors.window,
      cardColor: colors.card,
      cardTheme: cardTheme,
      extensions: [
        for (final extension in base.extensions.values)
          if (extension is! BusyMaxSurfaceColors) extension,
        colors,
      ],
      dividerColor: colors.divider,
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
        // Material 3 makes its default dialog shadow transparent. Restore the
        // semantic theme shadow while retaining the framework-owned elevation
        // and Yaru-owned dialog geometry.
        shadowColor: colorScheme.shadow,
        // Retain Yaru's dialog radius and geometry, but use the modern
        // libadwaita dialog outline instead of Yaru Flutter's conspicuous
        // dark-mode white outline. Popovers have a separate perimeter role.
        shape: _withOutlineSide(base.dialogTheme.shape, dialogSurfaceSide),
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
      checkboxTheme: base.checkboxTheme.copyWith(
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
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: colors.popover,
        surfaceTintColor: colors.popover,
        shadowColor: colorScheme.shadow,
        elevation: menuStyle.elevation?.resolve(const {}),
        textStyle: normalizer.apply(
          base.popupMenuTheme.textStyle,
          fallback: textTheme.bodyMedium,
          color: colors.foreground,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return normalizer.apply(
            base.popupMenuTheme.labelTextStyle?.resolve(states),
            fallback: textTheme.bodyMedium,
            color: states.contains(WidgetState.disabled)
                ? colors.disabledForeground
                : colors.foreground,
          );
        }),
        shape: _withOutlineSide(base.popupMenuTheme.shape, popoverSurfaceSide),
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
      tooltipTheme: base.tooltipTheme,
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
        inputDecorationTheme: dropdownInputDecorationTheme,
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
    required BusyMaxSurfaceColors colors,
    required _TextStyleNormalizer normalizer,
  }) {
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
      titleSmall: apply(base.titleSmall, color: colors.foreground),
      bodyLarge: apply(base.bodyLarge, color: colors.foreground),
      bodyMedium: apply(base.bodyMedium, color: colors.foreground),
      bodySmall: apply(base.bodySmall, color: colors.foreground),
      labelLarge: apply(base.labelLarge, color: colors.foreground),
      labelMedium: apply(base.labelMedium, color: colors.foreground),
      labelSmall: apply(base.labelSmall, color: colors.foreground),
    );
  }
}

({Color lowest, Color low, Color container, Color high, Color highest})
_surfaceContainerLadder(BusyMaxSurfaceColors colors, Brightness brightness) {
  var ladder = <Color>[
    colors.view,
    colors.window,
    colors.secondarySidebar,
    colors.secondarySidebar,
    colors.sidebar,
  ];
  if (!_isOpaqueMonotonicLadder(ladder, brightness)) {
    var candidates = <Color>[
      colors.view,
      colors.window,
      colors.secondarySidebar,
      colors.sidebar,
    ];
    if (candidates.any((color) => color.a < 1)) {
      final fallback = busyMaxFallbackSurfaceColors(brightness);
      candidates = [
        fallback.view,
        fallback.window,
        fallback.secondarySidebar,
        fallback.sidebar,
      ];
    }
    candidates.sort((first, second) {
      final luminanceOrder = first.computeLuminance().compareTo(
        second.computeLuminance(),
      );
      if (luminanceOrder != 0) {
        return brightness == Brightness.dark ? luminanceOrder : -luminanceOrder;
      }
      return first.toARGB32().compareTo(second.toARGB32());
    });
    ladder = [
      candidates[0],
      candidates[1],
      candidates[2],
      candidates[2],
      candidates[3],
    ];
  }

  return (
    lowest: ladder[0],
    low: ladder[1],
    container: ladder[2],
    high: ladder[3],
    highest: ladder[4],
  );
}

bool _isOpaqueMonotonicLadder(List<Color> ladder, Brightness brightness) {
  if (ladder.any((color) => color.a < 1)) {
    return false;
  }
  for (var index = 0; index < ladder.length - 1; index++) {
    final current = ladder[index].computeLuminance();
    final next = ladder[index + 1].computeLuminance();
    if (brightness == Brightness.light ? current < next : current > next) {
      return false;
    }
  }
  return true;
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
    divider: foreground,
    cardShade: foreground,
    dialogOutline: foreground,
    floatingBorder: foreground,
    sidebarBorder: foreground,
    shade: Colors.black.withValues(alpha: 0.50),
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
          requireOpaque: true,
        ) ??
        fallback.foreground;

    Color readableSurface(Color sampled, Color fallbackSurface) {
      return _contrastRatio(foreground, sampled) >= 4.5
          ? sampled
          : fallbackSurface;
    }

    // The Linux bridge only publishes named GTK semantic roles here; legacy
    // widget-class samples are omitted instead of being mislabeled as modern
    // surface roles. Preserve every supplied role when the shared foreground
    // remains readable. Inferring validity from luminance ordering would
    // reject legitimate custom GTK palettes.
    final window = readableSurface(sampledWindow, fallback.window);
    final view = readableSurface(sampledView, fallback.view);
    final sidebar = readableSurface(sampledSidebar, fallback.sidebar);
    final secondarySidebar = readableSurface(
      sampledSecondarySidebar,
      fallback.secondarySidebar,
    );
    final headerbar = readableSurface(sampledHeaderbar, fallback.headerbar);
    final headerbarFlat = readableSurface(
      sampledHeaderbarFlat,
      fallback.headerbarFlat,
    );
    final card = readableSurface(sampledCard, fallback.card);
    final dialog = readableSurface(sampledDialog, fallback.dialog);
    final popover = readableSurface(sampledPopover, fallback.popover);
    // Preserve GTK's semantic card layer as source data. Modern Yaru makes
    // this translucent, while [card] above is its opaque window/editor
    // composition. Elevated Flutter cards must paint that opaque role so
    // their physical shadow cannot bleed through the fill.
    final groupedSurface = _resolvedGroupedSurfaceLayer(
      runtime.card,
      fallback: fallback.groupedSurface,
      foreground: foreground,
      backgrounds: [window, view, dialog, popover],
    );
    final effectiveGroupedSurfaces = [
      for (final background in [window, view, dialog, popover])
        _surfaceColorOver(groupedSurface, over: background),
    ];
    // Sidebar boundaries, inset separators, and floating-surface outlines are
    // distinct named native roles. Preserve their GTK values directly instead
    // of rejecting a legitimate recessed edge by its luminance polarity.
    final runtimeSidebarBorder = _runtimeColor(runtime.sidebarBorder);
    final runtimeDivider = _runtimeColor(runtime.divider);
    final runtimeCardShade = _runtimeColor(runtime.cardShade);
    final runtimeFloatingBorder = _runtimeColor(runtime.floatingBorder);
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
      minContrast: 4.5,
      requireOpaque: true,
    );
    final disabledForeground = _resolvedReadableColor(
      runtime.disabledForeground,
      fallback: fallback.disabledForeground,
      guaranteed: foreground,
      backgrounds: readableBackgrounds,
      minContrast: 1.5,
    );
    final controlLadder = _resolvedControlLadder(
      runtimeControl: runtime.control,
      runtimeHover: runtime.controlHover,
      runtimeActive: runtime.controlActive,
      fallback: fallback,
      backgrounds: [
        view,
        sidebar,
        dialog,
        popover,
        ...effectiveGroupedSurfaces,
      ],
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
      control: controlLadder.control,
      controlHover: controlLadder.hover,
      controlActive: controlLadder.active,
      activeToggle: _runtimeOverlayColor(runtime.activeToggle),
      foreground: foreground,
      mutedForeground: mutedForeground,
      disabledForeground: disabledForeground,
      disabledControl: _runtimeOverlayColor(runtime.disabledControl),
      border: _runtimeColor(runtime.border),
      divider: runtimeDivider,
      cardShade: runtimeCardShade,
      floatingBorder: runtimeFloatingBorder,
      sidebarBorder: runtimeSidebarBorder,
      shade: _runtimeShadeColor(runtime.shade, over: popover),
    );
  }
}

Color _resolvedGroupedSurfaceLayer(
  Color? runtimeCard, {
  required Color fallback,
  required Color foreground,
  required Iterable<Color> backgrounds,
}) {
  final candidate = _runtimeColor(runtimeCard);
  if (candidate == null) {
    return fallback;
  }
  for (final background in backgrounds) {
    final effective = _surfaceColorOver(candidate, over: background);
    if (_contrastRatio(foreground, effective) < 4.5) {
      return fallback;
    }
  }
  return candidate;
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

({Color control, Color hover, Color active}) _resolvedControlLadder({
  required Color? runtimeControl,
  required Color? runtimeHover,
  required Color? runtimeActive,
  required BusyMaxSurfaceColors fallback,
  required Iterable<Color> backgrounds,
}) {
  final control = _runtimeOverlayColor(runtimeControl);
  final hover = _runtimeOverlayColor(runtimeHover);
  final active = _runtimeOverlayColor(runtimeActive);
  if (control == null || hover == null || active == null) {
    return (
      control: fallback.control,
      hover: fallback.controlHover,
      active: fallback.controlActive,
    );
  }

  // GTK 3 themes can report only a nearly transparent background-color while
  // painting the actual button through a background image. Such samples are
  // not usable as Flutter control roles. Require at least Yaru's semantic
  // strength and validate the complete state ladder against every surface on
  // which a shared control may appear.
  if (control.a < fallback.control.a ||
      hover.a < fallback.controlHover.a ||
      active.a < fallback.controlActive.a) {
    return (
      control: fallback.control,
      hover: fallback.controlHover,
      active: fallback.controlActive,
    );
  }

  for (final background in backgrounds) {
    final controlContrast = _contrastRatio(
      Color.alphaBlend(control, background),
      background,
    );
    final hoverContrast = _contrastRatio(
      Color.alphaBlend(hover, background),
      background,
    );
    final activeContrast = _contrastRatio(
      Color.alphaBlend(active, background),
      background,
    );
    if (controlContrast < _minimumControlSurfaceContrast ||
        hoverContrast < controlContrast ||
        activeContrast < hoverContrast) {
      return (
        control: fallback.control,
        hover: fallback.controlHover,
        active: fallback.controlActive,
      );
    }
  }

  return (control: control, hover: hover, active: active);
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
  bool requireOpaque = false,
}) {
  final runtime = _runtimeColor(color);
  if (runtime == null || (requireOpaque && runtime.a < 1)) {
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
  bool requireOpaque = false,
}) {
  return _runtimeReadableColor(
        runtime,
        backgrounds: backgrounds,
        minContrast: minContrast,
        requireOpaque: requireOpaque,
      ) ??
      _runtimeReadableColor(
        fallback,
        backgrounds: backgrounds,
        minContrast: minContrast,
        requireOpaque: requireOpaque,
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
  return _surfaceColorOver(runtime, over: over);
}

Color _surfaceColorOver(Color color, {required Color over}) {
  return color.a < 1 ? Color.alphaBlend(color, over) : color;
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

/// Applies semantic colors and GTK typography while retaining the input
/// geometry supplied by Yaru, including component-specific constraints.
InputDecorationThemeData _semanticInputDecorationTheme(
  InputDecorationThemeData base, {
  required BusyMaxSurfaceColors colors,
  required Color accentColor,
  required Color errorColor,
  required _TextStyleNormalizer normalizer,
  required TextTheme textTheme,
}) {
  final disabledBorderColor = colors.border.withValues(
    alpha: colors.border.a * 0.6,
  );

  InputBorder? borderWithColor(InputBorder? border, Color color) {
    return border?.copyWith(
      borderSide: border.borderSide.copyWith(color: color),
    );
  }

  return base.copyWith(
    border: borderWithColor(base.border, colors.border),
    enabledBorder: borderWithColor(base.enabledBorder, colors.border),
    focusedBorder: borderWithColor(base.focusedBorder, accentColor),
    errorBorder: borderWithColor(base.errorBorder, errorColor),
    focusedErrorBorder: borderWithColor(base.focusedErrorBorder, errorColor),
    disabledBorder: borderWithColor(base.disabledBorder, disabledBorderColor),
    activeIndicatorBorder: base.activeIndicatorBorder?.copyWith(
      color: accentColor,
    ),
    outlineBorder: base.outlineBorder?.copyWith(color: colors.border),
    iconColor: colors.foreground,
    labelStyle: normalizer.apply(
      base.labelStyle,
      fallback: textTheme.bodyMedium,
    ),
    floatingLabelStyle: normalizer.apply(
      base.floatingLabelStyle,
      fallback: textTheme.bodyMedium,
      color: accentColor,
    ),
    hintStyle: normalizer.apply(
      base.hintStyle,
      fallback: textTheme.bodyMedium,
      color: colors.mutedForeground,
    ),
    helperStyle: normalizer.apply(
      base.helperStyle,
      fallback: textTheme.bodySmall,
    ),
    errorStyle: normalizer.apply(
      base.errorStyle,
      fallback: textTheme.bodySmall,
      color: errorColor,
    ),
    counterStyle: normalizer.apply(
      base.counterStyle,
      fallback: textTheme.bodySmall,
    ),
  );
}

ShapeBorder? _withOutlineSide(ShapeBorder? shape, BorderSide side) {
  return switch (shape) {
    final InputBorder input => input.copyWith(borderSide: side),
    final OutlinedBorder outlined => outlined.copyWith(side: side),
    _ => shape,
  };
}

/// Applies only the semantic floating-surface roles and retains Yaru's menu
/// geometry, item states, padding, and motion.
MenuStyle _semanticMenuSurfaceStyle(
  MenuStyle? base, {
  required Color color,
  required Color shadowColor,
  required BorderSide side,
}) {
  return (base ?? const MenuStyle()).copyWith(
    backgroundColor: WidgetStatePropertyAll(color),
    surfaceTintColor: WidgetStatePropertyAll(color),
    shadowColor: WidgetStatePropertyAll(shadowColor),
    side: WidgetStatePropertyAll(side),
  );
}

/// Keeps Yaru's horizontal breathing room while allowing its own minimum
/// button height to remain the control height.
///
/// Yaru 10.2 applies its common padding on every edge. For a single-line
/// desktop action that vertical padding grows the control beyond Yaru's
/// declared button-height token. GTK-style buttons use the height token as
/// their metric, so normalize only that incompatible axis here, once, instead
/// of constraining individual buttons.
ButtonStyle? _yaruDesktopButtonStyle(ButtonStyle? base) {
  final sourcePadding = base?.padding;
  if (base == null || sourcePadding == null) {
    return base;
  }
  return base.copyWith(
    // Flutter's Linux-wide compact density would otherwise reduce Yaru's
    // declared 34 px button minimum to 26 px. Yaru already defines the native
    // control metric, so do not apply a second density reduction to buttons.
    visualDensity: VisualDensity.standard,
    // BusyMax is a desktop app. This is also Flutter's Linux default, but
    // declaring it on the shared button style keeps widget tests and fallback
    // shells from adding a mobile-only 48 px tap-target wrapper.
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: WidgetStateProperty.resolveWith((states) {
      return switch (sourcePadding.resolve(states)) {
        final EdgeInsets padding => EdgeInsets.only(
          left: padding.left,
          right: padding.right,
        ),
        final EdgeInsetsDirectional padding => EdgeInsetsDirectional.only(
          start: padding.start,
          end: padding.end,
        ),
        final padding => padding,
      };
    }),
  );
}

/// Applies runtime semantic colors and typography without replacing Yaru's
/// geometry, focus treatment, hover/press overlays, or motion defaults.
ButtonStyle _semanticButtonStyle(
  ButtonStyle? base, {
  required Color foreground,
  required Color background,
  Color? selectedBackground,
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
    iconColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabledForeground;
      }
      return foreground;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabledBackground;
      }
      if (selectedBackground != null && states.contains(WidgetState.selected)) {
        return selectedBackground;
      }
      return background;
    }),
  );
}
