import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GtkFontSettings {
  const GtkFontSettings({required this.family, required this.size});

  final String family;
  final double size;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GtkFontSettings &&
            other.family == family &&
            other.size == size;
  }

  @override
  int get hashCode => Object.hash(family, size);
}

class GtkFontService {
  const GtkFontService({
    MethodChannel channel = _channel,
    EventChannel fontSettingsEvents = _fontSettingsEvents,
  }) : _methodChannel = channel,
       _fontSettingsEventsChannel = fontSettingsEvents;

  static const _channel = MethodChannel('io.busystack.busymax/gtk_settings');
  static const _fontSettingsEvents = EventChannel(
    'io.busystack.busymax/gtk_font_settings',
  );

  final MethodChannel _methodChannel;
  final EventChannel _fontSettingsEventsChannel;

  Future<GtkFontSettings?> getGtkFont() async {
    try {
      final raw = await _methodChannel.invokeMapMethod<String, Object?>(
        'getGtkFont',
      );
      if (raw == null) {
        return null;
      }

      return _parseFontSettings(raw);
    } on MissingPluginException {
      return null;
    }
  }

  Stream<GtkFontSettings?> watchGtkFont() async* {
    try {
      await for (final raw
          in _fontSettingsEventsChannel.receiveBroadcastStream()) {
        yield _parseFontSettings(raw);
      }
    } on MissingPluginException {
      yield null;
    } on PlatformException {
      yield null;
    }
  }
}

class GtkThemeService {
  const GtkThemeService({
    MethodChannel channel = GtkFontService._channel,
    EventChannel themeColorsEvents = _themeColorsEvents,
  }) : _methodChannel = channel,
       _themeColorsEventsChannel = themeColorsEvents;

  static const _themeColorsEvents = EventChannel(
    'io.busystack.busymax/gtk_theme_colors',
  );

  final MethodChannel _methodChannel;
  final EventChannel _themeColorsEventsChannel;

  Future<GtkThemeColors?> getGtkThemeColors() async {
    try {
      final raw = await _methodChannel.invokeMapMethod<String, Object?>(
        'getGtkThemeColors',
      );
      if (raw == null) {
        return null;
      }
      return _parseThemeColors(raw);
    } on MissingPluginException {
      return null;
    }
  }

  Stream<GtkThemeColors?> watchGtkThemeColors() async* {
    try {
      await for (final raw
          in _themeColorsEventsChannel.receiveBroadcastStream()) {
        yield _parseThemeColors(raw);
      }
    } on MissingPluginException {
      yield null;
    } on PlatformException {
      yield null;
    }
  }
}

final gtkFontSettingsProvider = StreamProvider<GtkFontSettings?>((ref) {
  return const GtkFontService().watchGtkFont();
});

@immutable
class GtkThemeColors {
  const GtkThemeColors({
    required this.brightness,
    this.window,
    this.view,
    this.sidebar,
    this.secondarySidebar,
    this.headerbar,
    this.headerbarFlat,
    this.card,
    this.dialog,
    this.popover,
    this.control,
    this.controlHover,
    this.controlActive,
    this.accent,
    this.activeToggle,
    this.foreground,
    this.mutedForeground,
    this.disabledForeground,
    this.disabledControl,
    this.border,
    this.subtleBorder,
    this.sidebarBorder,
    this.shade,
  });

  final Brightness brightness;
  final Color? window;
  final Color? view;
  final Color? sidebar;
  final Color? secondarySidebar;
  final Color? headerbar;
  final Color? headerbarFlat;
  final Color? card;
  final Color? dialog;
  final Color? popover;
  final Color? control;
  final Color? controlHover;
  final Color? controlActive;
  final Color? accent;
  final Color? activeToggle;
  final Color? foreground;
  final Color? mutedForeground;
  final Color? disabledForeground;
  final Color? disabledControl;
  final Color? border;
  final Color? subtleBorder;
  final Color? sidebarBorder;
  final Color? shade;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GtkThemeColors &&
            other.brightness == brightness &&
            other.window == window &&
            other.view == view &&
            other.sidebar == sidebar &&
            other.secondarySidebar == secondarySidebar &&
            other.headerbar == headerbar &&
            other.headerbarFlat == headerbarFlat &&
            other.card == card &&
            other.dialog == dialog &&
            other.popover == popover &&
            other.control == control &&
            other.controlHover == controlHover &&
            other.controlActive == controlActive &&
            other.accent == accent &&
            other.activeToggle == activeToggle &&
            other.foreground == foreground &&
            other.mutedForeground == mutedForeground &&
            other.disabledForeground == disabledForeground &&
            other.disabledControl == disabledControl &&
            other.border == border &&
            other.subtleBorder == subtleBorder &&
            other.sidebarBorder == sidebarBorder &&
            other.shade == shade;
  }

  @override
  int get hashCode => Object.hashAll([
    brightness,
    window,
    view,
    sidebar,
    secondarySidebar,
    headerbar,
    headerbarFlat,
    card,
    dialog,
    popover,
    control,
    controlHover,
    controlActive,
    accent,
    activeToggle,
    foreground,
    mutedForeground,
    disabledForeground,
    disabledControl,
    border,
    subtleBorder,
    sidebarBorder,
    shade,
  ]);
}

final gtkThemeColorsProvider = StreamProvider<GtkThemeColors?>((ref) {
  return const GtkThemeService().watchGtkThemeColors();
});

GtkFontSettings? _parseFontSettings(Object? value) {
  if (value is! Map) {
    return null;
  }
  final family = (value['family'] as String?)?.trim();
  if (family == null || family.isEmpty) {
    return null;
  }
  final rawSize = value['size'];
  final size = rawSize is num ? rawSize.toDouble() : 0.0;
  return GtkFontSettings(
    family: family,
    size: size.isNaN || size.isInfinite ? 0.0 : size,
  );
}

GtkThemeColors? _parseThemeColors(Object? value) {
  if (value is! Map) {
    return null;
  }
  final window = _parseColor(value['window'] as String?);
  final brightness = switch ((value['brightness'] as String?)?.trim()) {
    'dark' => Brightness.dark,
    'light' => Brightness.light,
    _ =>
      window == null
          ? null
          : window.computeLuminance() < 0.5
          ? Brightness.dark
          : Brightness.light,
  };
  if (brightness == null) {
    return null;
  }
  return GtkThemeColors(
    brightness: brightness,
    window: window,
    view: _parseColor(value['view'] as String?),
    sidebar: _parseColor(value['sidebar'] as String?),
    secondarySidebar: _parseColor(value['secondarySidebar'] as String?),
    headerbar: _parseColor(value['headerbar'] as String?),
    headerbarFlat: _parseColor(value['headerbarFlat'] as String?),
    card: _parseColor(value['card'] as String?),
    dialog: _parseColor(value['dialog'] as String?),
    popover: _parseColor(value['popover'] as String?),
    control: _parseColor(value['control'] as String?),
    controlHover: _parseColor(value['controlHover'] as String?),
    controlActive: _parseColor(value['controlActive'] as String?),
    accent: _parseColor(value['accent'] as String?),
    activeToggle: _parseColor(value['activeToggle'] as String?),
    foreground: _parseColor(value['foreground'] as String?),
    mutedForeground: _parseColor(value['mutedForeground'] as String?),
    disabledForeground: _parseColor(value['disabledForeground'] as String?),
    disabledControl: _parseColor(value['disabledControl'] as String?),
    border: _parseColor(value['border'] as String?),
    subtleBorder: _parseColor(value['subtleBorder'] as String?),
    sidebarBorder: _parseColor(value['sidebarBorder'] as String?),
    shade: _parseColor(value['shade'] as String?),
  );
}

Color? _parseColor(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty || !raw.startsWith('#')) {
    return null;
  }
  final hex = raw.substring(1);
  if (hex.length == 6) {
    final rgb = int.tryParse(hex, radix: 16);
    return rgb == null ? null : Color(0xff000000 | rgb);
  }
  if (hex.length == 8) {
    final argb = int.tryParse(hex, radix: 16);
    return argb == null ? null : Color(argb);
  }
  return null;
}
