import 'package:flutter/material.dart';

@immutable
class BusyMaxSurfaceColors extends ThemeExtension<BusyMaxSurfaceColors> {
  const BusyMaxSurfaceColors({
    required this.window,
    required this.view,
    required this.sidebar,
    required this.secondarySidebar,
    required this.headerbar,
    required this.headerbarFlat,
    required this.card,
    required this.groupedSurface,
    required this.dialog,
    required this.popover,
    required this.control,
    required this.controlHover,
    required this.controlActive,
    required this.activeToggle,
    required this.foreground,
    required this.mutedForeground,
    required this.disabledForeground,
    required this.disabledControl,
    required this.border,
    required this.subtleBorder,
    required this.sidebarBorder,
    required this.shade,
  });

  final Color window;
  final Color view;
  final Color sidebar;
  final Color secondarySidebar;
  final Color headerbar;
  final Color headerbarFlat;
  final Color card;
  final Color groupedSurface;
  final Color dialog;
  final Color popover;
  final Color control;
  final Color controlHover;
  final Color controlActive;
  final Color activeToggle;
  final Color foreground;
  final Color mutedForeground;
  final Color disabledForeground;
  final Color disabledControl;
  final Color border;
  final Color subtleBorder;
  final Color sidebarBorder;
  final Color shade;

  static BusyMaxSurfaceColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<BusyMaxSurfaceColors>() ??
        busyMaxFallbackSurfaceColors(theme.brightness);
  }

  @override
  BusyMaxSurfaceColors copyWith({
    Color? window,
    Color? view,
    Color? sidebar,
    Color? secondarySidebar,
    Color? headerbar,
    Color? headerbarFlat,
    Color? card,
    Color? groupedSurface,
    Color? dialog,
    Color? popover,
    Color? control,
    Color? controlHover,
    Color? controlActive,
    Color? activeToggle,
    Color? foreground,
    Color? mutedForeground,
    Color? disabledForeground,
    Color? disabledControl,
    Color? border,
    Color? subtleBorder,
    Color? sidebarBorder,
    Color? shade,
  }) {
    return BusyMaxSurfaceColors(
      window: window ?? this.window,
      view: view ?? this.view,
      sidebar: sidebar ?? this.sidebar,
      secondarySidebar: secondarySidebar ?? this.secondarySidebar,
      headerbar: headerbar ?? this.headerbar,
      headerbarFlat: headerbarFlat ?? this.headerbarFlat,
      card: card ?? this.card,
      groupedSurface: groupedSurface ?? this.groupedSurface,
      dialog: dialog ?? this.dialog,
      popover: popover ?? this.popover,
      control: control ?? this.control,
      controlHover: controlHover ?? this.controlHover,
      controlActive: controlActive ?? this.controlActive,
      activeToggle: activeToggle ?? this.activeToggle,
      foreground: foreground ?? this.foreground,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      disabledForeground: disabledForeground ?? this.disabledForeground,
      disabledControl: disabledControl ?? this.disabledControl,
      border: border ?? this.border,
      subtleBorder: subtleBorder ?? this.subtleBorder,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      shade: shade ?? this.shade,
    );
  }

  @override
  BusyMaxSurfaceColors lerp(covariant BusyMaxSurfaceColors? other, double t) {
    if (other == null) {
      return this;
    }
    return BusyMaxSurfaceColors(
      window: Color.lerp(window, other.window, t)!,
      view: Color.lerp(view, other.view, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      secondarySidebar: Color.lerp(
        secondarySidebar,
        other.secondarySidebar,
        t,
      )!,
      headerbar: Color.lerp(headerbar, other.headerbar, t)!,
      headerbarFlat: Color.lerp(headerbarFlat, other.headerbarFlat, t)!,
      card: Color.lerp(card, other.card, t)!,
      groupedSurface: Color.lerp(groupedSurface, other.groupedSurface, t)!,
      dialog: Color.lerp(dialog, other.dialog, t)!,
      popover: Color.lerp(popover, other.popover, t)!,
      control: Color.lerp(control, other.control, t)!,
      controlHover: Color.lerp(controlHover, other.controlHover, t)!,
      controlActive: Color.lerp(controlActive, other.controlActive, t)!,
      activeToggle: Color.lerp(activeToggle, other.activeToggle, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      disabledForeground: Color.lerp(
        disabledForeground,
        other.disabledForeground,
        t,
      )!,
      disabledControl: Color.lerp(disabledControl, other.disabledControl, t)!,
      border: Color.lerp(border, other.border, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      shade: Color.lerp(shade, other.shade, t)!,
    );
  }
}

BusyMaxSurfaceColors busyMaxFallbackSurfaceColors(Brightness brightness) {
  return switch (brightness) {
    Brightness.light => const BusyMaxSurfaceColors(
      window: Color(0xFFFAFAFB),
      view: Color(0xFFFFFFFF),
      sidebar: Color(0xFFEBEBED),
      secondarySidebar: Color(0xFFF3F3F5),
      headerbar: Color(0xFFFFFFFF),
      headerbarFlat: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      groupedSurface: Color(0xFFFFFFFF),
      dialog: Color(0xFFFAFAFB),
      popover: Color(0xFFFFFFFF),
      control: Color.fromRGBO(0, 0, 0, 0.06),
      controlHover: Color.fromRGBO(0, 0, 0, 0.10),
      controlActive: Color.fromRGBO(0, 0, 0, 0.16),
      activeToggle: Color(0xFFFFFFFF),
      foreground: Color.fromRGBO(0, 0, 6, 0.80),
      mutedForeground: Color.fromRGBO(0, 0, 6, 0.56),
      disabledForeground: Color.fromRGBO(0, 0, 6, 0.38),
      disabledControl: Color.fromRGBO(0, 0, 0, 0.04),
      border: Color.fromRGBO(0, 0, 6, 0.18),
      subtleBorder: Color.fromRGBO(0, 0, 6, 0.10),
      sidebarBorder: Color.fromRGBO(0, 0, 6, 0.07),
      shade: Color.fromRGBO(0, 0, 6, 0.07),
    ),
    Brightness.dark => const BusyMaxSurfaceColors(
      window: Color(0xFF1D1D20),
      view: Color(0xFF1D1D20),
      sidebar: Color(0xFF2E2E32),
      secondarySidebar: Color(0xFF2E2E32),
      headerbar: Color(0xFF2E2E32),
      headerbarFlat: Color(0xFF1D1D20),
      card: Color(0xFF222226),
      groupedSurface: Color(0xFF383838),
      dialog: Color(0xFF222226),
      popover: Color(0xFF383838),
      control: Color.fromRGBO(255, 255, 255, 0.10),
      controlHover: Color.fromRGBO(255, 255, 255, 0.14),
      controlActive: Color.fromRGBO(255, 255, 255, 0.18),
      activeToggle: Color.fromRGBO(255, 255, 255, 0.20),
      foreground: Color(0xFFFFFFFF),
      mutedForeground: Color.fromRGBO(255, 255, 255, 0.70),
      disabledForeground: Color.fromRGBO(255, 255, 255, 0.38),
      disabledControl: Color.fromRGBO(255, 255, 255, 0.06),
      border: Color.fromRGBO(0, 0, 6, 0.75),
      subtleBorder: Color.fromRGBO(255, 255, 255, 0.10),
      sidebarBorder: Color.fromRGBO(0, 0, 6, 0.36),
      shade: Color.fromRGBO(0, 0, 6, 0.25),
    ),
  };
}
