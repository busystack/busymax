import 'package:busymax/src/platform/gtk_window_preferences_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses physical decoration sides without applying text direction', () {
    final preferences = GtkWindowPreferences.fromMessage(const {
      'decorationLayout': 'close,menu:minimize,maximize',
      'doubleClick': 'toggle-maximize',
      'middleClick': 'lower',
      'rightClick': 'menu',
    });

    expect(preferences.decorationLayout.left, [
      GtkWindowControlType.close,
      GtkWindowControlType.menu,
    ]);
    expect(preferences.decorationLayout.right, [
      GtkWindowControlType.minimize,
      GtkWindowControlType.maximize,
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

    expect(preferences.decorationLayout.left, [GtkWindowControlType.close]);
    expect(preferences.decorationLayout.right, [GtkWindowControlType.minimize]);
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

      expect(value?.decorationLayout.left, [GtkWindowControlType.menu]);
      expect(value?.decorationLayout.right, [GtkWindowControlType.close]);
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
}
