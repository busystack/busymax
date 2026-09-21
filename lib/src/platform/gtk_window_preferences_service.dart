import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GtkTitlebarAction { none, minimize, toggleMaximize, menu, lower }

@immutable
final class GtkDecorationLayout {
  const GtkDecorationLayout({required this.left, required this.right});

  factory GtkDecorationLayout.parse(String? value) {
    final sides = (value ?? 'menu:minimize,maximize,close').split(':');
    final left = sides.isEmpty ? '' : sides.first;
    final right = sides.length < 2 ? '' : sides[1];
    return GtkDecorationLayout(
      left: _parseControls(left),
      right: _parseControls(right),
    );
  }

  final List<GtkWindowDecorationElement> left;
  final List<GtkWindowDecorationElement> right;

  @override
  bool operator ==(Object other) =>
      other is GtkDecorationLayout &&
      listEquals(other.left, left) &&
      listEquals(other.right, right);

  @override
  int get hashCode => Object.hash(Object.hashAll(left), Object.hashAll(right));

  static List<GtkWindowDecorationElement> _parseControls(String source) {
    return List.unmodifiable(
      source
          .split(',')
          .map(
            (token) => switch (token.trim()) {
              'menu' => GtkWindowDecorationElement.fallbackApplicationMenu,
              'icon' => GtkWindowDecorationElement.windowIcon,
              'minimize' => GtkWindowDecorationElement.minimize,
              'maximize' => GtkWindowDecorationElement.maximize,
              'close' => GtkWindowDecorationElement.close,
              _ => null,
            },
          )
          .whereType<GtkWindowDecorationElement>(),
    );
  }
}

/// An element from GTK 3's physical `gtk-decoration-layout` setting.
///
/// The fallback application menu is intentionally distinct from
/// [GtkTitlebarAction.menu], which requests the window-manager menu.
enum GtkWindowDecorationElement {
  fallbackApplicationMenu,
  windowIcon,
  minimize,
  maximize,
  close,
}

@immutable
final class GtkWindowPreferences {
  const GtkWindowPreferences({
    required this.decorationLayout,
    required this.doubleClick,
    required this.middleClick,
    required this.rightClick,
  });

  factory GtkWindowPreferences.fromMessage(Map<Object?, Object?> message) {
    return GtkWindowPreferences(
      decorationLayout: GtkDecorationLayout.parse(
        message['decorationLayout'] as String?,
      ),
      doubleClick: _parseAction(message['doubleClick'] as String?),
      middleClick: _parseAction(message['middleClick'] as String?),
      rightClick: _parseAction(message['rightClick'] as String?),
    );
  }

  factory GtkWindowPreferences.defaults() => GtkWindowPreferences(
    decorationLayout: GtkDecorationLayout.parse(null),
    doubleClick: GtkTitlebarAction.toggleMaximize,
    middleClick: GtkTitlebarAction.none,
    rightClick: GtkTitlebarAction.menu,
  );

  final GtkDecorationLayout decorationLayout;
  final GtkTitlebarAction doubleClick;
  final GtkTitlebarAction middleClick;
  final GtkTitlebarAction rightClick;

  @override
  bool operator ==(Object other) =>
      other is GtkWindowPreferences &&
      other.decorationLayout == decorationLayout &&
      other.doubleClick == doubleClick &&
      other.middleClick == middleClick &&
      other.rightClick == rightClick;

  @override
  int get hashCode =>
      Object.hash(decorationLayout, doubleClick, middleClick, rightClick);

  static GtkTitlebarAction _parseAction(String? value) => switch (value) {
    'minimize' => GtkTitlebarAction.minimize,
    'toggle-maximize' => GtkTitlebarAction.toggleMaximize,
    'menu' => GtkTitlebarAction.menu,
    'lower' => GtkTitlebarAction.lower,
    _ => GtkTitlebarAction.none,
  };
}

class GtkWindowPreferencesService {
  const GtkWindowPreferencesService({
    MethodChannel channel = const MethodChannel(
      'io.busystack.busymax/gtk_settings',
    ),
    EventChannel events = const EventChannel(
      'io.busystack.busymax/gtk_window_preferences',
    ),
  }) : _channel = channel,
       _events = events;

  final MethodChannel _channel;
  final EventChannel _events;

  Future<GtkWindowPreferences?> load() async {
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'getGtkWindowPreferences',
      );
      return value == null ? null : GtkWindowPreferences.fromMessage(value);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Stream<GtkWindowPreferences?> watch() async* {
    try {
      await for (final value in _events.receiveBroadcastStream()) {
        if (value is Map<Object?, Object?>) {
          yield GtkWindowPreferences.fromMessage(value);
        }
      }
    } on MissingPluginException {
      yield null;
    } on PlatformException {
      yield null;
    }
  }

  Future<void> lowerWindow() async {
    try {
      await _channel.invokeMethod<void>('lowerWindow');
    } on MissingPluginException {
      // Tests and non-Linux compositions do not expose the GTK bridge.
    } on PlatformException {
      // The compositor may refuse lowering; leave the window unchanged.
    }
  }
}

final initialGtkWindowPreferencesProvider = Provider<GtkWindowPreferences?>(
  (ref) => null,
);

final gtkWindowPreferencesProvider = StreamProvider<GtkWindowPreferences>((
  ref,
) async* {
  final initial = ref.watch(initialGtkWindowPreferencesProvider);
  var previous = initial ?? GtkWindowPreferences.defaults();
  yield previous;
  // Linux bootstrap supplies a concrete initial value only when the native
  // bridge exists. Avoid activating an EventChannel on widget-test and
  // non-Linux engines where no plugin is registered.
  if (initial == null) return;
  await for (final update in const GtkWindowPreferencesService().watch()) {
    if (update == null || update == previous) continue;
    previous = update;
    yield update;
  }
});
