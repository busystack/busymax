import 'package:flutter/material.dart';

import '../platform/gtk_font_service.dart';
import 'busymax_yaru_theme.dart';
import 'app_settings.dart';

ThemeData buildBusyMaxTheme({
  required Brightness brightness,
  required Color accentColor,
  BusyMaxThemeFamily family = BusyMaxThemeFamily.yaru,
  String? gtkFontFamily,
  double? gtkFontSize,
  GtkThemeColors? gtkThemeColors,
}) {
  return switch (family) {
    BusyMaxThemeFamily.yaru => BusyMaxYaruTheme.build(
      brightness: brightness,
      accentColor: accentColor,
      gtkFontFamily: gtkFontFamily,
      gtkFontSize: gtkFontSize,
      gtkThemeColors: gtkThemeColors,
    ),
  };
}
