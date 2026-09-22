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
    expect(search?.focused.borderTop, 1);
    expect(search?.focused.hasInnerFocus, isTrue);
    expect(search?.focused.innerFocusWidth, 1);
    expect(search?.focused.innerFocusColor, const Color(0xFF336699));
    expect(search?.backdrop.foreground, const Color(0xFF777777));
    expect(search?.normal.hasInnerFocus, isFalse);
    expect(search?.backdrop.hasInnerFocus, isFalse);
    expect(search?.backdropFocused.hasInnerFocus, isFalse);
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
    final fallback = normal.extension<BusyMaxNativeSearchEntryTheme>()!.normal;
    expect(fallback.primaryIconForeground, fallback.secondaryIconForeground);
    expect(
      fallback.primaryIconForegroundRtl,
      fallback.secondaryIconForegroundRtl,
    );
    final focusedFallback = normal
        .extension<BusyMaxNativeSearchEntryTheme>()!
        .focused;
    expect(focusedFallback.borderTop, 1);
    expect(focusedFallback.hasInnerFocus, isTrue);
    expect(focusedFallback.innerFocusColor, const Color(0xFFAA4400));
    expect(focusedFallback.innerFocusWidth, 1);
    final backdropFallback = normal
        .extension<BusyMaxNativeSearchEntryTheme>()!
        .backdrop;
    expect(backdropFallback.hasInnerFocus, isFalse);
    expect(
      highContrast
          .extension<BusyMaxNativeSearchEntryTheme>()!
          .focused
          .hasInnerFocus,
      isFalse,
    );
    expect(
      highContrast
          .extension<BusyMaxNativeSearchEntryTheme>()!
          .focused
          .borderTop,
      2,
    );
  });

  test('lerp interpolates all primary and secondary icon colors', () {
    const first = BusyMaxNativeSearchEntryTheme(
      normal: _firstLerpState,
      focused: _firstLerpState,
      backdrop: _firstLerpState,
      backdropFocused: _firstLerpState,
    );
    const second = BusyMaxNativeSearchEntryTheme(
      normal: _secondLerpState,
      focused: _secondLerpState,
      backdrop: _secondLerpState,
      backdropFocused: _secondLerpState,
    );

    final state = first.lerp(second, .5).normal;
    expect(
      state.primaryIconForeground,
      Color.lerp(
        _firstLerpState.primaryIconForeground,
        _secondLerpState.primaryIconForeground,
        .5,
      ),
    );
    expect(
      state.primaryIconForegroundRtl,
      Color.lerp(
        _firstLerpState.primaryIconForegroundRtl,
        _secondLerpState.primaryIconForegroundRtl,
        .5,
      ),
    );
    expect(
      state.secondaryIconForeground,
      Color.lerp(
        _firstLerpState.secondaryIconForeground,
        _secondLerpState.secondaryIconForeground,
        .5,
      ),
    );
    expect(
      state.secondaryIconForegroundRtl,
      Color.lerp(
        _firstLerpState.secondaryIconForegroundRtl,
        _secondLerpState.secondaryIconForegroundRtl,
        .5,
      ),
    );
    expect(state.hasInnerFocus, isTrue);
    expect(
      state.innerFocusColor,
      Color.lerp(
        _firstLerpState.innerFocusColor,
        _secondLerpState.innerFocusColor,
        .5,
      ),
    );
    expect(state.innerFocusWidth, .5);
  });
}

const _firstLerpState = GtkSearchEntryStateStyle(
  background: Color(0xFF000000),
  foreground: Color(0xFF000000),
  borderTop: 1,
  borderRight: 1,
  borderBottom: 1,
  borderLeft: 1,
  borderColor: Color(0xFF000000),
  primaryIconForeground: Color(0xFF002000),
  primaryIconForegroundRtl: Color(0xFF200000),
  secondaryIconForeground: Color(0xFF000020),
  secondaryIconForegroundRtl: Color(0xFF200020),
  radius: 1,
  hasInnerFocus: false,
  innerFocusColor: Color(0x00000000),
  innerFocusWidth: 0,
);

const _secondLerpState = GtkSearchEntryStateStyle(
  background: Color(0xFFFFFFFF),
  foreground: Color(0xFFFFFFFF),
  borderTop: 2,
  borderRight: 2,
  borderBottom: 2,
  borderLeft: 2,
  borderColor: Color(0xFFFFFFFF),
  primaryIconForeground: Color(0xFFFF0000),
  primaryIconForegroundRtl: Color(0xFF00FF00),
  secondaryIconForeground: Color(0xFF0000E0),
  secondaryIconForegroundRtl: Color(0xFFE000E0),
  radius: 2,
  hasInnerFocus: true,
  innerFocusColor: Color(0xFFFFFFFF),
  innerFocusWidth: 1,
);

const _nativeSearchTheme = GtkSearchEntryTheme(
  normal: GtkSearchEntryStateStyle(
    background: Color(0xFF111111),
    foreground: Color(0xFFEEEEEE),
    borderTop: 1,
    borderRight: 2,
    borderBottom: 3,
    borderLeft: 4,
    borderColor: Color(0xFF555555),
    primaryIconForeground: Color(0xFF666666),
    primaryIconForegroundRtl: Color(0xFF676767),
    secondaryIconForeground: Color(0xFF686868),
    secondaryIconForegroundRtl: Color(0xFF696969),
    radius: 13,
  ),
  focused: GtkSearchEntryStateStyle(
    background: Color(0xFF222222),
    foreground: Color(0xFFDDDDDD),
    borderTop: 1,
    borderRight: 1,
    borderBottom: 1,
    borderLeft: 1,
    borderColor: Color(0xFF336699),
    primaryIconForeground: Color(0xFFBBBBBB),
    primaryIconForegroundRtl: Color(0xFFBCBCBC),
    secondaryIconForeground: Color(0xFFBDBDBD),
    secondaryIconForegroundRtl: Color(0xFFBEBEBE),
    radius: 12,
    hasInnerFocus: true,
    innerFocusColor: Color(0xFF336699),
    innerFocusWidth: 1,
  ),
  backdrop: GtkSearchEntryStateStyle(
    background: Color(0xFF333333),
    foreground: Color(0xFF777777),
    borderTop: 1,
    borderRight: 1,
    borderBottom: 1,
    borderLeft: 1,
    borderColor: Color(0xFF444444),
    primaryIconForeground: Color(0xFF555555),
    primaryIconForegroundRtl: Color(0xFF565656),
    secondaryIconForeground: Color(0xFF575757),
    secondaryIconForegroundRtl: Color(0xFF585858),
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
    primaryIconForeground: Color(0xFF999999),
    primaryIconForegroundRtl: Color(0xFF9A9A9A),
    secondaryIconForeground: Color(0xFF9B9B9B),
    secondaryIconForegroundRtl: Color(0xFF9C9C9C),
    radius: 10,
  ),
);
