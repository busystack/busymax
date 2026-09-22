import 'package:busymax/src/app/busymax_yaru_theme.dart';
import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native GTK Search style overrides the BusyMax fallback', () {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFFAA4400),
      gtkThemeColors: const GtkThemeColors(
        brightness: Brightness.light,
        searchEntry: _nativeSearchTheme,
      ),
    );

    final search = theme.extension<BusyMaxNativeSearchEntryTheme>();
    expect(search, isNotNull);
    expect(search?.normal.radius, 13);
    expect(search?.normal.borderTop, 1);
    expect(search?.normal.borderRight, 2);
    expect(search?.normal.borderBottom, 3);
    expect(search?.normal.borderLeft, 4);
    expect(search?.focused.background, const Color(0xFF222222));
    expect(search?.backdrop.foreground, const Color(0xFF777777));
    expect(search?.backdropFocused.borderColor, const Color(0xFF888888));
  });

  test('sampled GTK geometry remains authoritative in high contrast', () {
    final theme = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFFAA4400),
      highContrast: true,
      gtkThemeColors: const GtkThemeColors(
        brightness: Brightness.light,
        searchEntry: _nativeSearchTheme,
      ),
    );

    expect(theme.extension<BusyMaxNativeSearchEntryTheme>()?.normal.radius, 13);
  });

  test('missing or wrong-brightness GTK Search style uses fallback', () {
    final normal = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFFAA4400),
    );
    final highContrast = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFFAA4400),
      highContrast: true,
    );
    final wrongBrightness = BusyMaxYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFFAA4400),
      gtkThemeColors: const GtkThemeColors(
        brightness: Brightness.dark,
        searchEntry: _nativeSearchTheme,
      ),
    );

    expect(normal.extension<BusyMaxNativeSearchEntryTheme>()?.normal.radius, 9);
    expect(
      highContrast.extension<BusyMaxNativeSearchEntryTheme>()?.normal.radius,
      6,
    );
    expect(
      wrongBrightness.extension<BusyMaxNativeSearchEntryTheme>()?.normal.radius,
      9,
    );
  });
}

const _nativeSearchTheme = GtkSearchEntryTheme(
  normal: GtkSearchEntryStateStyle(
    background: Color(0xFF111111),
    foreground: Color(0xFFEEEEEE),
    borderTop: 1,
    borderRight: 2,
    borderBottom: 3,
    borderLeft: 4,
    borderColor: Color(0xFF555555),
    iconForeground: Color(0xFF666666),
    iconForegroundRtl: Color(0xFF676767),
    radius: 13,
  ),
  focused: GtkSearchEntryStateStyle(
    background: Color(0xFF222222),
    foreground: Color(0xFFDDDDDD),
    borderTop: 2,
    borderRight: 2,
    borderBottom: 2,
    borderLeft: 2,
    borderColor: Color(0xFF336699),
    iconForeground: Color(0xFFBBBBBB),
    iconForegroundRtl: Color(0xFFBCBCBC),
    radius: 12,
  ),
  backdrop: GtkSearchEntryStateStyle(
    background: Color(0xFF333333),
    foreground: Color(0xFF777777),
    borderTop: 1,
    borderRight: 1,
    borderBottom: 1,
    borderLeft: 1,
    borderColor: Color(0xFF444444),
    iconForeground: Color(0xFF555555),
    iconForegroundRtl: Color(0xFF565656),
    radius: 11,
  ),
  backdropFocused: GtkSearchEntryStateStyle(
    background: Color(0xFF444444),
    foreground: Color(0xFF666666),
    borderTop: 1,
    borderRight: 1,
    borderBottom: 1,
    borderLeft: 1,
    borderColor: Color(0xFF888888),
    iconForeground: Color(0xFF999999),
    iconForegroundRtl: Color(0xFF9A9A9A),
    radius: 10,
  ),
);
