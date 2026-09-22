import 'package:busymax/src/platform/gtk_window_preferences_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses every GTK 3 decoration token in physical order', () {
    final preferences = GtkWindowPreferences.fromMessage(const {
      'decorationLayout': 'close,icon,menu:minimize,maximize',
      'doubleClick': 'toggle-maximize',
      'middleClick': 'lower',
      'rightClick': 'menu',
    });

    expect(preferences.decorationLayout.left, [
      GtkWindowDecorationElement.close,
      GtkWindowDecorationElement.windowIcon,
      GtkWindowDecorationElement.fallbackApplicationMenu,
    ]);
    expect(preferences.decorationLayout.right, [
      GtkWindowDecorationElement.minimize,
      GtkWindowDecorationElement.maximize,
    ]);
    expect(preferences.doubleClick, GtkTitlebarAction.toggleMaximize);
    expect(preferences.middleClick, GtkTitlebarAction.lower);
    expect(preferences.rightClick, GtkTitlebarAction.menu);
  });

  test('ignores unknown controls and actions safely', () {
    final preferences = GtkWindowPreferences.fromMessage(const {
      'decorationLayout': 'unknown,close:bogus,minimize',
      'doubleClick': 'unsupported',
      'middleClick': 'none',
      'rightClick': 'minimize',
    });

    expect(preferences.decorationLayout.left, [
      GtkWindowDecorationElement.close,
    ]);
    expect(preferences.decorationLayout.right, [
      GtkWindowDecorationElement.minimize,
    ]);
    expect(preferences.doubleClick, GtkTitlebarAction.none);
    expect(preferences.middleClick, GtkTitlebarAction.none);
    expect(preferences.rightClick, GtkTitlebarAction.minimize);
  });

  test(
    'loads preferences and delegates the narrowly scoped lower action',
    () async {
      const channel = MethodChannel('busymax_test/gtk_preferences');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'getGtkWindowPreferences') {
              return <String, Object>{
                'decorationLayout': 'menu:close',
                'doubleClick': 'minimize',
                'middleClick': 'none',
                'rightClick': 'menu',
              };
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      const service = GtkWindowPreferencesService(channel: channel);

      final value = await service.load();
      await service.lowerWindow();

      expect(value?.decorationLayout.left, [
        GtkWindowDecorationElement.fallbackApplicationMenu,
      ]);
      expect(value?.decorationLayout.right, [GtkWindowDecorationElement.close]);
      expect(value?.doubleClick, GtkTitlebarAction.minimize);
      expect(calls.map((call) => call.method), [
        'getGtkWindowPreferences',
        'lowerWindow',
      ]);
    },
  );

  test('window preference values have stable equality', () {
    final first = GtkWindowPreferences.fromMessage(const {
      'decorationLayout': ':minimize,maximize,close',
      'doubleClick': 'toggle-maximize',
      'middleClick': 'none',
      'rightClick': 'menu',
    });
    final second = GtkWindowPreferences.fromMessage(const {
      'decorationLayout': ':minimize,maximize,close',
      'doubleClick': 'toggle-maximize',
      'middleClick': 'none',
      'rightClick': 'menu',
    });

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('null decoration layout uses the documented GTK 3 default', () {
    final layout = GtkDecorationLayout.parse(null);

    expect(layout.left, [GtkWindowDecorationElement.fallbackApplicationMenu]);
    expect(layout.right, [
      GtkWindowDecorationElement.minimize,
      GtkWindowDecorationElement.maximize,
      GtkWindowDecorationElement.close,
    ]);
  });
}
