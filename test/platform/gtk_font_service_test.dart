import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads native Ubuntu Sans 11 font settings', () async {
    const channel = MethodChannel('busymax_test/gtk_font_ubuntu');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getGtkFont');
          return <String, Object?>{'family': 'Ubuntu Sans', 'size': 11.0};
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final settings = await const GtkFontService(channel: channel).getGtkFont();

    expect(settings, const GtkFontSettings(family: 'Ubuntu Sans', size: 11));
  });

  test('reads native Cantarell 11 font settings', () async {
    const channel = MethodChannel('busymax_test/gtk_font_cantarell');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getGtkFont');
          return <String, Object?>{'family': 'Cantarell', 'size': 11};
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final settings = await const GtkFontService(channel: channel).getGtkFont();

    expect(settings, const GtkFontSettings(family: 'Cantarell', size: 11));
  });

  test('ignores missing or blank native font settings', () async {
    const channel = MethodChannel('busymax_test/gtk_font_blank');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return <String, Object?>{'family': '   ', 'size': 11};
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final settings = await const GtkFontService(channel: channel).getGtkFont();

    expect(settings, isNull);
  });

  test('missing native GTK font channel falls back to null', () async {
    final settings = await const GtkFontService(
      channel: MethodChannel('busymax_test/gtk_font_missing'),
    ).getGtkFont();

    expect(settings, isNull);
  });

  test('invalid native GTK font size does not crash', () async {
    const channel = MethodChannel('busymax_test/gtk_font_invalid_size');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return <String, Object?>{'family': 'GTK Test Sans', 'size': 'bad'};
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final settings = await const GtkFontService(channel: channel).getGtkFont();

    expect(settings, const GtkFontSettings(family: 'GTK Test Sans', size: 0));
  });

  test('missing native GTK font size does not crash', () async {
    const channel = MethodChannel('busymax_test/gtk_font_missing_size');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return <String, Object?>{'family': 'GTK Test Sans'};
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final settings = await const GtkFontService(channel: channel).getGtkFont();

    expect(settings, const GtkFontSettings(family: 'GTK Test Sans', size: 0));
  });

  test('font settings stream emits initial value', () async {
    const events = EventChannel('busymax_test/gtk_font_events_initial');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          events,
          MockStreamHandler.inline(
            onListen: (arguments, eventSink) {
              eventSink.success(<String, Object?>{
                'family': 'GTK Test Sans',
                'size': 11.0,
              });
            },
          ),
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(events, null);
    });

    final settings = await const GtkFontService(
      fontSettingsEvents: events,
    ).watchGtkFont().first;

    expect(settings, const GtkFontSettings(family: 'GTK Test Sans', size: 11));
  });

  test('font settings stream emits updated value', () async {
    const events = EventChannel('busymax_test/gtk_font_events_update');
    MockStreamHandlerEventSink? sink;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          events,
          MockStreamHandler.inline(
            onListen: (arguments, eventSink) {
              sink = eventSink;
              eventSink.success(<String, Object?>{
                'family': 'GTK Test Sans',
                'size': 11.0,
              });
            },
          ),
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(events, null);
    });

    final stream = const GtkFontService(
      fontSettingsEvents: events,
    ).watchGtkFont();
    final valuesFuture = stream.take(2).toList();
    await pumpEventQueue();

    expect(sink, isNotNull);
    sink!.success(<String, Object?>{'family': 'GTK Test Sans', 'size': 12.0});
    final values = await valuesFuture;

    expect(values, [
      const GtkFontSettings(family: 'GTK Test Sans', size: 11),
      const GtkFontSettings(family: 'GTK Test Sans', size: 12),
    ]);
  });

  test('font settings stream falls back to null on native error', () async {
    const events = EventChannel('busymax_test/gtk_font_events_error');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          events,
          MockStreamHandler.inline(
            onListen: (arguments, eventSink) {
              eventSink.error(code: 'gtk_error', message: 'unavailable');
            },
          ),
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(events, null);
    });

    final settings = await const GtkFontService(
      fontSettingsEvents: events,
    ).watchGtkFont().first;

    expect(settings, isNull);
  });

  test('reads native GTK theme colors', () async {
    const channel = MethodChannel('busymax_test/gtk_theme_colors');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getGtkThemeColors');
          return <String, Object?>{
            'brightness': 'dark',
            'window': '#202020',
            'view': '#212121',
            'sidebar': '#303030',
            'secondarySidebar': '#323232',
            'headerbar': '#242424',
            'headerbarFlat': '#212121',
            'card': '#2A2A2A',
            'dialog': '#343434',
            'popover': '#383838',
            'control': '#1AFFFFFF',
            'controlHover': '#2EFFFFFF',
            'controlActive': '#33FFFFFF',
            'activeToggle': '#44FFFFFF',
            'foreground': '#FFFFFF',
            'mutedForeground': '#C0C0C0',
            'disabledForeground': '#61FFFFFF',
            'disabledControl': '#0FFFFFFF',
            'border': '#99000000',
            'subtleBorder': '#1AFFFFFF',
            'sidebarBorder': '#33000000',
            'shade': '#55000000',
          };
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final colors = await const GtkThemeService(
      channel: channel,
    ).getGtkThemeColors();

    expect(colors?.brightness, Brightness.dark);
    expect(colors?.window, const Color(0xFF202020));
    expect(colors?.sidebar, const Color(0xFF303030));
    expect(colors?.headerbar, const Color(0xFF242424));
    expect(colors?.popover, const Color(0xFF383838));
    expect(colors?.control, const Color(0x1AFFFFFF));
    expect(colors?.controlActive, const Color(0x33FFFFFF));
    expect(colors?.subtleBorder, const Color(0x1AFFFFFF));
  });

  test('missing native GTK theme color channel falls back to null', () async {
    final settings = await const GtkThemeService(
      channel: MethodChannel('busymax_test/gtk_theme_missing'),
    ).getGtkThemeColors();

    expect(settings, isNull);
  });

  test('theme color stream emits initial and updated values', () async {
    const events = EventChannel('busymax_test/gtk_theme_events_update');
    MockStreamHandlerEventSink? sink;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          events,
          MockStreamHandler.inline(
            onListen: (arguments, eventSink) {
              sink = eventSink;
              eventSink.success(<String, Object?>{
                'brightness': 'dark',
                'window': '#202020',
              });
            },
          ),
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(events, null);
    });

    final stream = const GtkThemeService(
      themeColorsEvents: events,
    ).watchGtkThemeColors();
    final valuesFuture = stream.take(2).toList();
    await pumpEventQueue();

    expect(sink, isNotNull);
    sink!.success(<String, Object?>{
      'brightness': 'light',
      'window': '#FAFAFB',
    });
    final values = await valuesFuture;

    expect(values[0]?.brightness, Brightness.dark);
    expect(values[0]?.window, const Color(0xFF202020));
    expect(values[1]?.brightness, Brightness.light);
    expect(values[1]?.window, const Color(0xFFFAFAFB));
  });

  test('theme color stream falls back to null on native error', () async {
    const events = EventChannel('busymax_test/gtk_theme_events_error');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          events,
          MockStreamHandler.inline(
            onListen: (arguments, eventSink) {
              eventSink.error(code: 'gtk_error', message: 'unavailable');
            },
          ),
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(events, null);
    });

    final colors = await const GtkThemeService(
      themeColorsEvents: events,
    ).watchGtkThemeColors().first;

    expect(colors, isNull);
  });
}
