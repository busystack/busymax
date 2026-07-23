import 'package:busymax/src/platform/gtk_font_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('providers publish preloaded GTK settings on the first frame', () async {
    const font = GtkFontSettings(family: 'Ubuntu Sans', size: 11);
    const colors = GtkThemeColors(
      brightness: Brightness.light,
      window: Color(0xFFFFFFFF),
    );
    final container = ProviderContainer(
      overrides: [
        initialGtkFontSettingsProvider.overrideWithValue(font),
        initialGtkThemeColorsProvider.overrideWithValue(colors),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(gtkFontSettingsProvider.future), font);
    expect(await container.read(gtkThemeColorsProvider.future), colors);
  });

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

  test('native GTK settings errors fall back to null during preload', () async {
    const channel = MethodChannel('busymax_test/gtk_settings_error');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) => throw PlatformException(code: 'unavailable'),
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    expect(await const GtkFontService(channel: channel).getGtkFont(), isNull);
    expect(
      await const GtkThemeService(channel: channel).getGtkThemeColors(),
      isNull,
    );
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

  test('malformed native GTK payload types are ignored safely', () async {
    const fontChannel = MethodChannel('busymax_test/gtk_font_malformed');
    const themeChannel = MethodChannel('busymax_test/gtk_theme_malformed');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      fontChannel,
      (_) async => <String, Object?>{'family': 42, 'size': 11},
    );
    messenger.setMockMethodCallHandler(
      themeChannel,
      (_) async => <String, Object?>{
        'brightness': 'light',
        'window': 42,
        'view': true,
        'foreground': <String>['#000000'],
      },
    );
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(fontChannel, null)
        ..setMockMethodCallHandler(themeChannel, null);
    });

    expect(
      await const GtkFontService(channel: fontChannel).getGtkFont(),
      isNull,
    );
    final colors = await const GtkThemeService(
      channel: themeChannel,
    ).getGtkThemeColors();
    expect(colors?.brightness, Brightness.light);
    expect(colors?.window, isNull);
    expect(colors?.view, isNull);
    expect(colors?.foreground, isNull);
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
            'accent': '#C061CB',
            'accentForeground': '#FFFFFFFF',
            'activeToggle': '#44FFFFFF',
            'foreground': '#FFFFFF',
            'mutedForeground': '#C0C0C0',
            'disabledForeground': '#61FFFFFF',
            'disabledControl': '#0FFFFFFF',
            'border': '#99000000',
            'divider': '#1AFFFFFF',
            'floatingBorder': '#24000000',
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
    expect(colors?.accent, const Color(0xFFC061CB));
    expect(colors?.accentForeground, const Color(0xFFFFFFFF));
    expect(colors?.divider, const Color(0x1AFFFFFF));
    expect(colors?.floatingBorder, const Color(0x24000000));
  });

  test('missing native GTK theme color channel falls back to null', () async {
    final settings = await const GtkThemeService(
      channel: MethodChannel('busymax_test/gtk_theme_missing'),
    ).getGtkThemeColors();

    expect(settings, isNull);
  });

  test(
    'explicit theme preference is forwarded before palette lookup',
    () async {
      const channel = MethodChannel('busymax_test/gtk_theme_preference');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      const service = GtkThemeService(channel: channel);

      await service.setPreferDark(true);
      await service.setPreferDark(false);
      await service.setPreferDark(null);

      expect(calls.map((call) => call.method), [
        'setGtkThemePreference',
        'setGtkThemePreference',
      ]);
      expect(calls.map((call) => call.arguments), [true, false]);
    },
  );

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
                'accent': '#C061CB',
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
      'accent': '#E95420',
    });
    final values = await valuesFuture;

    expect(values[0]?.brightness, Brightness.dark);
    expect(values[0]?.window, const Color(0xFF202020));
    expect(values[0]?.accent, const Color(0xFFC061CB));
    expect(values[1]?.brightness, Brightness.light);
    expect(values[1]?.window, const Color(0xFFFAFAFB));
    expect(values[1]?.accent, const Color(0xFFE95420));
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
