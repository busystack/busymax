import 'package:flutter/material.dart';

const _dimLabelOpacity = 0.55;

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
    required this.divider,
    required this.floatingBorder,
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
  final Color divider;
  final Color floatingBorder;
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
    Color? divider,
    Color? floatingBorder,
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
      divider: divider ?? this.divider,
      floatingBorder: floatingBorder ?? this.floatingBorder,
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
      divider: Color.lerp(divider, other.divider, t)!,
      floatingBorder: Color.lerp(floatingBorder, other.floatingBorder, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      shade: Color.lerp(shade, other.shade, t)!,
    );
  }
}

BusyMaxSurfaceColors busyMaxFallbackSurfaceColors(Brightness brightness) {
  final foreground = switch (brightness) {
    Brightness.light => const Color.fromRGBO(0, 0, 6, 0.80),
    Brightness.dark => const Color(0xFFF6F5F4),
  };
  final mutedForeground = foreground.withValues(
    alpha: foreground.a * _dimLabelOpacity,
  );

  return switch (brightness) {
    Brightness.light => BusyMaxSurfaceColors(
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
      // Match Yaru's contained-button ladder. A weaker resting layer makes
      // standard controls look flat until their hover overlay appears.
      control: Color.fromRGBO(0, 0, 0, 0.10),
      controlHover: Color.fromRGBO(0, 0, 0, 0.14),
      controlActive: Color.fromRGBO(0, 0, 0, 0.18),
      activeToggle: Color(0xFFFFFFFF),
      foreground: foreground,
      mutedForeground: mutedForeground,
      disabledForeground: Color.fromRGBO(0, 0, 6, 0.38),
      disabledControl: Color.fromRGBO(0, 0, 0, 0.04),
      border: Color.fromRGBO(0, 0, 6, 0.18),
      divider: Color.fromRGBO(0, 0, 6, 0.10),
      floatingBorder: Color.fromRGBO(0, 0, 6, 0.10),
      sidebarBorder: Color.fromRGBO(0, 0, 6, 0.07),
      shade: Color.fromRGBO(0, 0, 6, 0.07),
    ),
    Brightness.dark => BusyMaxSurfaceColors(
      // Current Yaru/libadwaita semantic surface ladder. GTK 3 cannot expose
      // every libadwaita role reliably, so incompatible legacy samples fall
      // back to the matching modern surface rather than a hand-tuned shade.
      window: Color(0xFF222226),
      view: Color(0xFF222226),
      sidebar: Color(0xFF2E2E32),
      secondarySidebar: Color(0xFF28282C),
      headerbar: Color(0xFF2E2E32),
      headerbarFlat: Color(0xFF222226),
      card: Color(0xFF36363A),
      groupedSurface: Color(0xFF36363A),
      dialog: Color(0xFF36363A),
      popover: Color(0xFF36363A),
      control: Color.fromRGBO(255, 255, 255, 0.10),
      controlHover: Color.fromRGBO(255, 255, 255, 0.14),
      controlActive: Color.fromRGBO(255, 255, 255, 0.18),
      activeToggle: Color.fromRGBO(255, 255, 255, 0.20),
      foreground: foreground,
      mutedForeground: mutedForeground,
      disabledForeground: Color.fromRGBO(255, 255, 255, 0.38),
      disabledControl: Color.fromRGBO(255, 255, 255, 0.06),
      border: Color.fromRGBO(0, 0, 6, 0.75),
      divider: Color.fromRGBO(255, 255, 255, 0.10),
      floatingBorder: Color.fromRGBO(255, 255, 255, 0.10),
      sidebarBorder: Color.fromRGBO(255, 255, 255, 0.10),
      shade: Color.fromRGBO(0, 0, 6, 0.25),
    ),
  };
}
