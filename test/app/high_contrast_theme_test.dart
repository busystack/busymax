import 'package:busymax/src/app/app_theme.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/app/busymax_surface_colors.dart';
import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/theme.dart';

const _testAccent = Color(0xFF3584E4);

void main() {
  test('high-contrast themes use Yaru high-contrast component semantics', () {
    final light = buildBusyMaxTheme(
      brightness: Brightness.light,
      accentColor: _testAccent,
      highContrast: true,
    );
    final dark = buildBusyMaxTheme(
      brightness: Brightness.dark,
      accentColor: _testAccent,
      highContrast: true,
    );

    expect(light.colorScheme.primary, Colors.black);
    expect(light.colorScheme.isHighContrast, isTrue);
    expect(dark.colorScheme.primary, Colors.white);
    expect(dark.colorScheme.isHighContrast, isTrue);

    final lightSurfaces = light.extension<BusyMaxSurfaceColors>()!;
    final darkSurfaces = dark.extension<BusyMaxSurfaceColors>()!;
    for (final surface in [
      lightSurfaces.window,
      lightSurfaces.view,
      lightSurfaces.sidebar,
      lightSurfaces.dialog,
      lightSurfaces.popover,
    ]) {
      expect(surface, Colors.white);
    }
    for (final surface in [
      darkSurfaces.window,
      darkSurfaces.view,
      darkSurfaces.sidebar,
      darkSurfaces.dialog,
      darkSurfaces.popover,
    ]) {
      expect(surface, Colors.black);
    }

    for (final theme in [light, dark]) {
      final surfaces = theme.extension<BusyMaxSurfaceColors>()!;
      expect(surfaces.mutedForeground, surfaces.foreground);
      expect(surfaces.disabledForeground, isNot(surfaces.foreground));
      expect(surfaces.border, surfaces.foreground);
      expect(surfaces.divider, surfaces.foreground);
      expect(surfaces.cardShade, surfaces.foreground);
      expect(surfaces.dialogOutline, surfaces.foreground);
      expect(surfaces.floatingBorder, surfaces.foreground);
      expect(surfaces.sidebarBorder, surfaces.foreground);
      expect(theme.colorScheme.outline, surfaces.foreground);
      expect(theme.colorScheme.outlineVariant, surfaces.foreground);
      expect(
        _contrastRatio(theme.colorScheme.error, surfaces.view),
        greaterThanOrEqualTo(4.5),
      );

      final outlinedSide = theme.outlinedButtonTheme.style!.side!.resolve({});
      expect(outlinedSide, isNot(BorderSide.none));
      expect(outlinedSide!.color, surfaces.border);

      final elevatedShape =
          theme.elevatedButtonTheme.style!.shape!.resolve({})
              as RoundedRectangleBorder;
      expect(elevatedShape.side, isNot(BorderSide.none));
      expect(elevatedShape.side.color, surfaces.border);

      final popupShape = theme.popupMenuTheme.shape! as OutlineInputBorder;
      expect(popupShape.borderSide.color, surfaces.border);
      final dialogShape = theme.dialogTheme.shape! as RoundedRectangleBorder;
      expect(dialogShape.side.color, surfaces.border);
      expect(theme.menuTheme.style?.side?.resolve({})?.color, surfaces.border);
      expect(
        theme.dropdownMenuTheme.menuStyle?.side?.resolve({})?.color,
        surfaces.border,
      );

      final tooltipDecoration = theme.tooltipTheme.decoration! as BoxDecoration;
      final tooltipBorder = tooltipDecoration.border! as Border;
      expect(tooltipDecoration.color, BusyMaxTooltipStyle.background);
      expect(tooltipDecoration.borderRadius, BusyMaxTooltipStyle.borderRadius);
      expect(tooltipBorder.top.color, BusyMaxTooltipStyle.border);
      expect(
        theme.tooltipTheme.textStyle?.color,
        BusyMaxTooltipStyle.foreground,
      );
      expect(theme.tooltipTheme.padding, BusyMaxTooltipStyle.padding);
      expect(theme.tooltipTheme.constraints, BusyMaxTooltipStyle.constraints);
    }
  });

  test('high contrast does not retain mixed-luminance GTK surfaces', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      window: Colors.white,
      view: Colors.white,
      sidebar: Colors.black,
      dialog: Colors.black,
      popover: Colors.black,
    );
    final theme = buildBusyMaxTheme(
      brightness: Brightness.light,
      accentColor: _testAccent,
      gtkThemeColors: gtkColors,
      highContrast: true,
    );
    final surfaces = theme.extension<BusyMaxSurfaceColors>()!;

    expect(surfaces.sidebar, Colors.white);
    expect(surfaces.dialog, Colors.white);
    expect(surfaces.popover, Colors.white);
    expect(surfaces.foreground, Colors.black);
  });

  testWidgets('calendar grids retain the high-contrast outline', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final theme = buildBusyMaxTheme(
        brightness: brightness,
        accentColor: _testAccent,
        highContrast: true,
      );
      Color? gridColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: theme,
            child: Builder(
              builder: (context) {
                gridColor = busyMaxCalendarGridColor(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(gridColor, theme.colorScheme.outlineVariant);
    }
  });

  test('standard themes retain the requested system accent', () {
    const accent = Color(0xFF3584E4);
    final theme = buildBusyMaxTheme(
      brightness: Brightness.light,
      accentColor: accent,
    );

    expect(theme.colorScheme.primary, accent);
    expect(theme.colorScheme.isHighContrast, isFalse);
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
