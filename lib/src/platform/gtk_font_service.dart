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
    } on PlatformException {
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

  Future<void> setPreferDark(bool? preferDark) async {
    if (preferDark == null) {
      return;
    }
    try {
      await _methodChannel.invokeMethod<void>(
        'setGtkThemePreference',
        preferDark,
      );
    } on MissingPluginException {
      // Non-Linux and lightweight test hosts do not expose GTK settings.
    } on PlatformException {
      // A theme preference is advisory; fall back to the current GTK palette.
    }
  }

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
    } on PlatformException {
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

final initialGtkFontSettingsProvider = Provider<GtkFontSettings?>(
  (ref) => null,
);

final gtkFontSettingsProvider = StreamProvider<GtkFontSettings?>((ref) {
  return _seededGtkSettingsStream(
    ref.watch(initialGtkFontSettingsProvider),
    const GtkFontService().watchGtkFont(),
  );
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
    this.accentForeground,
    this.activeToggle,
    this.foreground,
    this.mutedForeground,
    this.disabledForeground,
    this.disabledControl,
    this.border,
    this.divider,
    this.floatingBorder,
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
  final Color? accentForeground;
  final Color? activeToggle;
  final Color? foreground;
  final Color? mutedForeground;
  final Color? disabledForeground;
  final Color? disabledControl;
  final Color? border;
  final Color? divider;
  final Color? floatingBorder;
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
            other.accentForeground == accentForeground &&
            other.activeToggle == activeToggle &&
            other.foreground == foreground &&
            other.mutedForeground == mutedForeground &&
            other.disabledForeground == disabledForeground &&
            other.disabledControl == disabledControl &&
            other.border == border &&
            other.divider == divider &&
            other.floatingBorder == floatingBorder &&
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
    accentForeground,
    activeToggle,
    foreground,
    mutedForeground,
    disabledForeground,
    disabledControl,
    border,
    divider,
    floatingBorder,
    sidebarBorder,
    shade,
  ]);
}

final initialGtkThemeColorsProvider = Provider<GtkThemeColors?>((ref) => null);

final gtkThemeColorsProvider = StreamProvider<GtkThemeColors?>((ref) {
  return _seededGtkSettingsStream(
    ref.watch(initialGtkThemeColorsProvider),
    const GtkThemeService().watchGtkThemeColors(),
  );
});

Stream<T?> _seededGtkSettingsStream<T>(T? initial, Stream<T?> updates) async* {
  var previous = initial;
  yield initial;
  await for (final update in updates) {
    if (update == previous) {
      continue;
    }
    previous = update;
    yield update;
  }
}

GtkFontSettings? _parseFontSettings(Object? value) {
  if (value is! Map) {
    return null;
  }
  final rawFamily = value['family'];
  final family = rawFamily is String ? rawFamily.trim() : null;
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
  final window = _parseColor(value['window']);
  final rawBrightness = value['brightness'];
  final brightness = switch (rawBrightness is String
      ? rawBrightness.trim()
      : null) {
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
    view: _parseColor(value['view']),
    sidebar: _parseColor(value['sidebar']),
    secondarySidebar: _parseColor(value['secondarySidebar']),
    headerbar: _parseColor(value['headerbar']),
    headerbarFlat: _parseColor(value['headerbarFlat']),
    card: _parseColor(value['card']),
    dialog: _parseColor(value['dialog']),
    popover: _parseColor(value['popover']),
    control: _parseColor(value['control']),
    controlHover: _parseColor(value['controlHover']),
    controlActive: _parseColor(value['controlActive']),
    accent: _parseColor(value['accent']),
    accentForeground: _parseColor(value['accentForeground']),
    activeToggle: _parseColor(value['activeToggle']),
    foreground: _parseColor(value['foreground']),
    mutedForeground: _parseColor(value['mutedForeground']),
    disabledForeground: _parseColor(value['disabledForeground']),
    disabledControl: _parseColor(value['disabledControl']),
    border: _parseColor(value['border']),
    divider: _parseColor(value['divider']),
    floatingBorder: _parseColor(value['floatingBorder']),
    sidebarBorder: _parseColor(value['sidebarBorder']),
    shade: _parseColor(value['shade']),
  );
}

Color? _parseColor(Object? value) {
  if (value is! String) {
    return null;
  }
  final raw = value.trim();
  if (raw.isEmpty || !raw.startsWith('#')) {
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
