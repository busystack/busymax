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
    required this.divider,
    required this.cardShade,
    required this.dialogOutline,
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

  /// Source layer for GTK's boxed-list/card role.
  ///
  /// Modern Yaru publishes this role as a translucent layer in dark mode.
  /// It is retained for semantic color resolution, but must not be painted
  /// directly by an elevated Flutter [Material]: the physical shadow would
  /// show through the translucent fill. Shared grouped surfaces composite it
  /// over their declared semantic parent before painting an opaque material.
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

  /// Recessed separator used between rows inside a boxed-list/card surface.
  ///
  /// This is libadwaita's `card_shade_color`, which is intentionally distinct
  /// from the generic GTK separator and outline roles.
  final Color cardShade;

  /// Restrained inside outline for modal dialog surfaces.
  ///
  /// Modern libadwaita uses a low-opacity light outline for this role. It is
  /// intentionally separate from both generic control borders and the darker
  /// perimeter used by anchored menus and popovers.
  final Color dialogOutline;

  /// Subtle perimeter for anchored menus and popovers.
  ///
  /// This is the current libadwaita/Yaru popover edge. Dialog decoration is a
  /// separate native role and must not reuse this token.
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
    Color? cardShade,
    Color? dialogOutline,
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
      cardShade: cardShade ?? this.cardShade,
      dialogOutline: dialogOutline ?? this.dialogOutline,
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
      cardShade: Color.lerp(cardShade, other.cardShade, t)!,
      dialogOutline: Color.lerp(dialogOutline, other.dialogOutline, t)!,
      floatingBorder: Color.lerp(floatingBorder, other.floatingBorder, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      shade: Color.lerp(shade, other.shade, t)!,
    );
  }
}

BusyMaxSurfaceColors busyMaxFallbackSurfaceColors(Brightness brightness) {
  final window = switch (brightness) {
    Brightness.light => const Color(0xFFFAFAFA),
    Brightness.dark => const Color(0xFF2C2C2C),
  };
  final view = switch (brightness) {
    Brightness.light => const Color(0xFFFFFFFF),
    Brightness.dark => const Color(0xFF272727),
  };
  final foreground = switch (brightness) {
    Brightness.light => const Color(0xFF3D3D3D),
    Brightness.dark => const Color(0xFFF7F7F7),
  };
  // Enabled 10–14 px labels consume this role. Keep it opaque so its contrast
  // remains stable on every semantic surface instead of stacking alpha on an
  // arbitrary view, dialog, or popover background.
  final mutedForeground = switch (brightness) {
    Brightness.light => const Color(0xFF666666),
    Brightness.dark => const Color(0xFFB5B5B5),
  };

  return switch (brightness) {
    Brightness.light => BusyMaxSurfaceColors(
      // Modern Yaru/libadwaita semantic surface roles. GTK 3 does not publish
      // every modern role, so named theme values replace these fallbacks only
      // when the bridge can identify the role and the resolver can read it.
      window: window,
      view: view,
      sidebar: Color(0xFFEBEBEB),
      secondarySidebar: Color(0xFFF0F0F0),
      headerbar: Color(0xFFFAFAFA),
      headerbarFlat: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      groupedSurface: Color(0xFFFFFFFF),
      dialog: const Color(0xFFFAFAFA),
      popover: const Color(0xFFFAFAFA),
      // Match Yaru's contained-button ladder. A weaker resting layer makes
      // standard controls look flat until their hover overlay appears.
      control: Color.fromRGBO(0, 0, 0, 0.10),
      controlHover: Color.fromRGBO(0, 0, 0, 0.14),
      controlActive: Color.fromRGBO(0, 0, 0, 0.18),
      activeToggle: Color(0xFFFFFFFF),
      foreground: foreground,
      mutedForeground: mutedForeground,
      // Yaru derives disabled content from the semantic foreground rather
      // than from absolute black. Keep the shared fallback on that same role
      // so native and Flutter controls resolve to one disabled color.
      disabledForeground: foreground.withValues(alpha: 0.38),
      disabledControl: Color.fromRGBO(0, 0, 0, 0.04),
      border: Color.fromRGBO(0, 0, 0, 0.18),
      divider: Color.fromRGBO(0, 0, 0, 0.10),
      cardShade: Color.fromRGBO(24, 24, 24, 0.08),
      // libadwaita's modal/floating-sheet surface uses this restrained inset
      // outline. Keep it independent of the black anchored-popover edge.
      dialogOutline: Color.fromRGBO(255, 255, 255, 0.07),
      // Current libadwaita/Yaru uses the same restrained edge in both modes.
      floatingBorder: Color.fromRGBO(0, 0, 0, 0.14),
      sidebarBorder: Color.fromRGBO(24, 24, 24, 0.08),
      shade: Color.fromRGBO(0, 0, 0, 0.07),
    ),
    Brightness.dark => BusyMaxSurfaceColors(
      // Modern Yaru/libadwaita semantic surface roles. Floating surfaces are
      // raised neutral gray rather than the near-black main content role.
      window: window,
      view: view,
      sidebar: Color(0xFF393939),
      secondarySidebar: Color(0xFF323232),
      headerbar: Color(0xFF393939),
      headerbarFlat: Color(0xFF272727),
      card: Color(0xFF3D3D3D),
      // libadwaita/Yaru's card role is a contextual layer, not a fixed dark
      // gray. It resolves against the semantic surface that contains it.
      groupedSurface: Color.fromRGBO(255, 255, 255, 0.08),
      dialog: Color(0xFF3E3E3E),
      popover: Color(0xFF3E3E3E),
      control: Color.fromRGBO(255, 255, 255, 0.10),
      controlHover: Color.fromRGBO(255, 255, 255, 0.14),
      controlActive: Color.fromRGBO(255, 255, 255, 0.18),
      activeToggle: Color.fromRGBO(255, 255, 255, 0.20),
      foreground: foreground,
      mutedForeground: mutedForeground,
      disabledForeground: foreground.withValues(alpha: 0.38),
      disabledControl: Color.fromRGBO(255, 255, 255, 0.06),
      border: Color.fromRGBO(0, 0, 0, 0.75),
      divider: Color.fromRGBO(255, 255, 255, 0.10),
      // Modern Yaru uses a 36% near-black recessed edge for dark cards.
      // Keep the neutral fallback free of the theme's slight blue component.
      cardShade: Color.fromRGBO(0, 0, 0, 0.36),
      dialogOutline: Color.fromRGBO(255, 255, 255, 0.07),
      floatingBorder: Color.fromRGBO(0, 0, 0, 0.14),
      // A sidebar boundary is recessed in Yaru, not highlighted. This exact
      // fallback mirrors its named semantic role when GTK 3 omits that role.
      sidebarBorder: Color.fromRGBO(16, 16, 16, 0.35),
      shade: Color.fromRGBO(0, 0, 0, 0.25),
    ),
  };
}
