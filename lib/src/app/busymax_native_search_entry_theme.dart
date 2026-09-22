import 'package:flutter/material.dart';
import 'package:yaru/theme.dart';

import '../platform/gtk_font_service.dart';
import 'busymax_surface_colors.dart';

@immutable
final class BusyMaxNativeSearchEntryTheme
    extends ThemeExtension<BusyMaxNativeSearchEntryTheme> {
  const BusyMaxNativeSearchEntryTheme({
    required this.normal,
    required this.focused,
    required this.backdrop,
    required this.backdropFocused,
  });

  factory BusyMaxNativeSearchEntryTheme.fromGtk(GtkSearchEntryTheme theme) {
    return BusyMaxNativeSearchEntryTheme(
      normal: theme.normal,
      focused: theme.focused,
      backdrop: theme.backdrop,
      backdropFocused: theme.backdropFocused,
    );
  }

  factory BusyMaxNativeSearchEntryTheme.fallback({
    required BusyMaxSurfaceColors colors,
    required Color accent,
    required bool highContrast,
  }) {
    final radius = highContrast ? 6.0 : 9.0;
    final backdropForeground = _withOpacity(colors.foreground, .5);
    final backdropIcon = _withOpacity(colors.mutedForeground, .5);
    return BusyMaxNativeSearchEntryTheme(
      normal: _fallbackState(
        colors: colors,
        foreground: colors.foreground,
        borderColor: colors.border,
        iconForeground: colors.mutedForeground,
        borderWidth: 1,
        radius: radius,
      ),
      focused: _fallbackState(
        colors: colors,
        foreground: colors.foreground,
        borderColor: accent,
        iconForeground: colors.mutedForeground,
        borderWidth: 2,
        radius: radius,
      ),
      backdrop: _fallbackState(
        colors: colors,
        foreground: backdropForeground,
        borderColor: colors.border,
        iconForeground: backdropIcon,
        borderWidth: 1,
        radius: radius,
      ),
      backdropFocused: _fallbackState(
        colors: colors,
        foreground: backdropForeground,
        borderColor: colors.border,
        iconForeground: backdropIcon,
        borderWidth: 1,
        radius: radius,
      ),
    );
  }

  final GtkSearchEntryStateStyle normal;
  final GtkSearchEntryStateStyle focused;
  final GtkSearchEntryStateStyle backdrop;
  final GtkSearchEntryStateStyle backdropFocused;

  static BusyMaxNativeSearchEntryTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<BusyMaxNativeSearchEntryTheme>() ??
        BusyMaxNativeSearchEntryTheme.fallback(
          colors: BusyMaxSurfaceColors.of(context),
          accent: theme.colorScheme.primary,
          highContrast: theme.colorScheme.isHighContrast,
        );
  }

  GtkSearchEntryStateStyle stateFor({
    required bool windowActive,
    required bool focused,
  }) {
    return switch ((windowActive, focused)) {
      (true, false) => normal,
      (true, true) => this.focused,
      (false, false) => backdrop,
      (false, true) => backdropFocused,
    };
  }

  @override
  BusyMaxNativeSearchEntryTheme copyWith({
    GtkSearchEntryStateStyle? normal,
    GtkSearchEntryStateStyle? focused,
    GtkSearchEntryStateStyle? backdrop,
    GtkSearchEntryStateStyle? backdropFocused,
  }) {
    return BusyMaxNativeSearchEntryTheme(
      normal: normal ?? this.normal,
      focused: focused ?? this.focused,
      backdrop: backdrop ?? this.backdrop,
      backdropFocused: backdropFocused ?? this.backdropFocused,
    );
  }

  @override
  BusyMaxNativeSearchEntryTheme lerp(
    covariant BusyMaxNativeSearchEntryTheme? other,
    double t,
  ) {
    if (other == null) return this;
    return BusyMaxNativeSearchEntryTheme(
      normal: _lerpState(normal, other.normal, t),
      focused: _lerpState(focused, other.focused, t),
      backdrop: _lerpState(backdrop, other.backdrop, t),
      backdropFocused: _lerpState(backdropFocused, other.backdropFocused, t),
    );
  }
}

GtkSearchEntryStateStyle _fallbackState({
  required BusyMaxSurfaceColors colors,
  required Color foreground,
  required Color borderColor,
  required Color iconForeground,
  required double borderWidth,
  required double radius,
}) {
  return GtkSearchEntryStateStyle(
    background: colors.view,
    foreground: foreground,
    borderTop: borderWidth,
    borderRight: borderWidth,
    borderBottom: borderWidth,
    borderLeft: borderWidth,
    borderColor: borderColor,
    iconForeground: iconForeground,
    radius: radius,
  );
}

GtkSearchEntryStateStyle _lerpState(
  GtkSearchEntryStateStyle first,
  GtkSearchEntryStateStyle second,
  double t,
) {
  return GtkSearchEntryStateStyle(
    background: Color.lerp(first.background, second.background, t)!,
    foreground: Color.lerp(first.foreground, second.foreground, t)!,
    borderTop: _lerpDouble(first.borderTop, second.borderTop, t),
    borderRight: _lerpDouble(first.borderRight, second.borderRight, t),
    borderBottom: _lerpDouble(first.borderBottom, second.borderBottom, t),
    borderLeft: _lerpDouble(first.borderLeft, second.borderLeft, t),
    borderColor: Color.lerp(first.borderColor, second.borderColor, t)!,
    iconForeground: Color.lerp(first.iconForeground, second.iconForeground, t)!,
    iconForegroundRtl: Color.lerp(
      first.iconForegroundRtl,
      second.iconForegroundRtl,
      t,
    )!,
    radius: _lerpDouble(first.radius, second.radius, t),
  );
}

double _lerpDouble(double first, double second, double t) =>
    first + (second - first) * t;

Color _withOpacity(Color color, double opacity) =>
    color.withValues(alpha: color.a * opacity);
