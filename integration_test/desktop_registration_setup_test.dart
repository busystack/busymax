import 'dart:io';

import 'package:busymax/main_linux.dart' as app;
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/app/busymax_design.dart';
import 'package:busymax/src/core/auth/oauth_registration.dart';
import 'package:busymax/src/features/schedule/presentation/schedule_workspace.dart';
import 'package:busymax/src/features/settings/presentation/settings_screen.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Run only with an isolated data directory; no user accounts are opened.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final output = Platform.environment['BUSYMAX_ACCEPTANCE_ROOT'];
  testWidgets(
    'Settings owns desktop registration forms, guides and error states',
    (tester) async {
      expect(Platform.isLinux, isTrue);
      expect(Platform.environment['XDG_DATA_HOME'], '$output/data');
      await tester.runAsync(() => app.main(const []));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ScheduleWorkspace)),
      );
      expect(await container.read(accountsStreamProvider.future), isEmpty);
      final settings = container.read(appSettingsControllerProvider.notifier);
      await tester.runAsync(
        () => settings.setThemeModePreference(BusyMaxThemeModePreference.light),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      final staging = container.read(registrationStagingProvider);
      final picker = _Picker();
      final previousPicker = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = picker;
      addTearDown(() => FileSelectorPlatform.instance = previousPicker);
      final file = File('$output/desktop.json');
      await file.writeAsString(
        await File('test/fixtures/oauth/desktop_synthetic.json').readAsString(),
      );
      picker.selection = XFile(file.path);
      await tester.tap(find.text('Add Google account'));
      await tester.pumpAndSettle();
      await _capture(tester, '$output/google-empty.png');
      await tester.tap(_key('import'));
      await tester.pumpAndSettle();
      expect(_key('summary'), findsOneWidget);
      await _capture(tester, '$output/google-imported.png');
      picker.selection = null;
      await tester.tap(_key('import'));
      await tester.pumpAndSettle();
      expect(_key('summary'), findsOneWidget);
      picker.selection = XFile(file.path);
      await file.writeAsString('{"web":{}}');
      await tester.tap(_key('import'));
      await tester.pumpAndSettle();
      expect(_key('error'), findsOneWidget);
      expect(_key('summary'), findsOneWidget);
      await _capture(tester, '$output/google-invalid-replacement.png');
      await tester.tap(_key('guide'));
      await tester.pumpAndSettle();
      expect(_key('instructions-dialog'), findsOneWidget);
      expect(_key('back'), findsNothing);
      await _capture(tester, '$output/google-guide.png');
      expect(_key('authorize').hitTestable(), findsNothing);
      await tester.ensureVisible(_key('copy-all'));
      await tester.pumpAndSettle();
      await _capture(tester, '$output/google-guide-scrolled.png');
      await tester.ensureVisible(find.text('Open Google Cloud Console'));
      await tester.pumpAndSettle();
      // Native Linux launcher returns an error string; exercise its real exception path.
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.url_launcher_linux.UrlLauncherApi.launchUrl',
        StandardMessageCodec(),
      );
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            channel,
            (_) async => ['test launch failure'],
          );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(channel, null),
      );
      await tester.tap(find.text('Open Google Cloud Console'));
      await tester.pumpAndSettle();
      expect(_key('link-error'), findsOneWidget);
      await _capture(tester, '$output/google-guide-link-error.png');
      await tester.ensureVisible(_key('instructions-close'));
      await tester.tap(_key('instructions-close'));
      await tester.pumpAndSettle();
      expect(_key('instructions-dialog'), findsNothing);
      expect(_key('summary'), findsOneWidget);
      await _capture(tester, '$output/google-instructions-closed.png');
      staging
          .cancel(); // Same notification as expiry, without waiting ten minutes.
      await tester.pumpAndSettle();
      expect(
        tester.widget<ElevatedButton>(_key('authorize')).onPressed,
        isNull,
      );
      await _capture(tester, '$output/google-expired.png');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Microsoft account'));
      await tester.pumpAndSettle();
      await _capture(tester, '$output/microsoft-empty.png');
      await tester.enterText(_key('client-id'), 'invalid');
      await tester.pumpAndSettle();
      await _capture(tester, '$output/microsoft-invalid.png');
      await tester.enterText(
        _key('client-id'),
        '11223344-5566-7788-99aa-bbccddeeff00',
      );
      await _audience(tester, 3, capture: '$output/microsoft-menu-open.png');
      await tester.enterText(
        _key('tenant-id'),
        'aabbccdd-1122-3344-5566-77889900aabb',
      );
      await tester.pumpAndSettle();
      await _capture(tester, '$output/microsoft-tenant.png');
      await tester.tap(_key('guide'));
      await tester.pumpAndSettle();
      await _capture(tester, '$output/microsoft-guide.png');
      expect(_key('authorize').hitTestable(), findsNothing);
      await tester.ensureVisible(_key('copy-all'));
      await tester.pumpAndSettle();
      await _capture(tester, '$output/microsoft-guide-scrolled.png');
      await tester.ensureVisible(
        find.text('Open Microsoft Entra admin center'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Microsoft Entra admin center'));
      await tester.pumpAndSettle();
      await _capture(tester, '$output/microsoft-guide-link-error.png');
      await tester.ensureVisible(_key('instructions-close'));
      await tester.tap(_key('instructions-close'));
      await tester.pumpAndSettle();
      expect(_key('instructions-dialog'), findsNothing);
      expect(
        tester.widget<TextField>(_key('tenant-id')).controller!.text,
        'aabbccdd-1122-3344-5566-77889900aabb',
      );
      await _capture(tester, '$output/microsoft-instructions-closed.png');
      await _audience(tester, 2);
      expect(_key('tenant-id'), findsNothing);
      await _audience(tester, 3);
      expect(
        tester.widget<TextField>(_key('tenant-id')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<ElevatedButton>(_key('authorize')).onPressed,
        isNull,
      );
      await _capture(tester, '$output/microsoft-tenant-reset.png');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await file.writeAsString(
        await File('test/fixtures/oauth/desktop_synthetic.json').readAsString(),
      );
      picker.selection = XFile(file.path);
      for (final preference in [
        BusyMaxThemeModePreference.light,
        BusyMaxThemeModePreference.dark,
      ]) {
        await tester.runAsync(
          () => settings.setThemeModePreference(preference),
        );
        await tester.pumpAndSettle();
        final mode = preference.name;
        for (final name in ['Google', 'Microsoft']) {
          await tester.tap(find.text('Add $name account'));
          await tester.pumpAndSettle();
          final prefix = '$output/${name.toLowerCase()}-$mode';
          await _capture(tester, '$prefix-empty.png');
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          await tester.pumpAndSettle();
          await _capture(tester, '$prefix-empty-large.png');
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.pumpAndSettle();
          if (name == 'Google') {
            await tester.tap(_key('import'));
          } else {
            await tester.enterText(
              _key('client-id'),
              '11223344-5566-7788-99aa-bbccddeeff00',
            );
            await _audience(tester, 3, capture: '$prefix-menu.png');
            await tester.enterText(
              _key('tenant-id'),
              'aabbccdd-1122-3344-5566-77889900aabb',
            );
          }
          await tester.pumpAndSettle();
          await _capture(tester, '$prefix-populated.png');
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          await tester.pumpAndSettle();
          await _capture(tester, '$prefix-large-text.png');
          if (name == 'Microsoft') {
            await _audience(tester, 3, capture: '$prefix-menu-large.png');
          }
          await tester.tap(_key('guide'));
          await tester.pumpAndSettle();
          await _capture(tester, '$prefix-guide-large.png');
          await tester.ensureVisible(_key('copy-all'));
          await tester.pumpAndSettle();
          await _capture(tester, '$prefix-guide-scrolled-large.png');
          await tester.tap(_key('instructions-close'));
          await tester.pumpAndSettle();
          expect(
            _key(name == 'Google' ? 'summary' : 'tenant-id'),
            findsOneWidget,
          );
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.pumpAndSettle();
          if (name == 'Microsoft') {
            // Traverse from the client entry to the native combo using Tab.
            await tester.tap(_key('client-id'));
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
            expect(
              FocusManager.instance.primaryFocus!.debugLabel,
              'BusyMax menu trigger',
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.space);
            await tester.pumpAndSettle();
            await _capture(tester, '$prefix-menu-keyboard.png');
            await _nativeKeys(tester, [
              'Home',
              'Down',
              'Down',
              'Down',
              'Return',
            ]);
            await tester.pumpAndSettle();
            await tester.enterText(_key('tenant-id'), 'invalid');
            await tester.pumpAndSettle();
            await _capture(tester, '$prefix-error.png');
          }
          await tester.tap(_key('guide'));
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(_key('instructions-dialog'), findsNothing);
          expect(
            _key(name == 'Google' ? 'summary' : 'client-id'),
            findsOneWidget,
          );
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        }
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      expect(await container.read(accountsStreamProvider.future), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    skip: output == null,
  );
}

Finder _key(String value) => find.byKey(ValueKey('registration-$value'));

Future<void> _capture(WidgetTester tester, String path) async {
  // Capture the composited native display, including the modal overlay.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final result = await Process.run('/usr/bin/python3', [
      '-c',
      '''import sys, gi
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk
window = Gdk.get_default_root_window()
pixbuf = Gdk.pixbuf_get_from_window(window, 0, 0, window.get_width(), window.get_height())
pixbuf.savev(sys.argv[1], 'png', [], [])
''',
      path,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
}

Future<void> _audience(
  WidgetTester tester,
  int index, {
  String? capture,
}) async {
  await tester.tap(_key('audience'));
  await tester.pumpAndSettle();
  if (capture != null) await _capture(tester, capture);
  // This is the production GTK menu, outside Flutter's widget tree.
  await _nativeKeys(tester, [
    'Home',
    for (var i = 0; i < index; i++) 'Down',
    'Return',
  ]);
  // Native menu replies arrive independently of Flutter's frame scheduling.
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final row = tester.widget<BusyMaxComboRow<MicrosoftAudience>>(
      _key('audience'),
    );
    final menuOpen = tester
        .widgetList<Semantics>(
          find.descendant(
            of: _key('audience'),
            matching: find.byType(Semantics),
          ),
        )
        .any((widget) => widget.properties.expanded == true);
    if (row.selected == MicrosoftAudience.values[index] && !menuOpen) return;
  }
  await _capture(
    tester,
    '${Platform.environment['BUSYMAX_ACCEPTANCE_ROOT']}/native-menu-after-keys.png',
  );
  expect(
    tester
        .widget<BusyMaxComboRow<MicrosoftAudience>>(_key('audience'))
        .selected,
    MicrosoftAudience.values[index],
  );
}

Future<void> _nativeKeys(WidgetTester tester, List<String> keys) async {
  await tester.runAsync(() async {
    final result = await Process.run('/usr/bin/python3', [
      '-c',
      r'''import ctypes, re, subprocess, sys, time
x = ctypes.CDLL('libX11.so.6')
t = ctypes.CDLL('libXtst.so.6')
x.XOpenDisplay.argtypes = [ctypes.c_char_p]
x.XOpenDisplay.restype = ctypes.c_void_p
x.XStringToKeysym.argtypes = [ctypes.c_char_p]
x.XStringToKeysym.restype = ctypes.c_ulong
x.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x.XKeysymToKeycode.restype = ctypes.c_uint
x.XFlush.argtypes = [ctypes.c_void_p]
x.XCloseDisplay.argtypes = [ctypes.c_void_p]
x.XSetInputFocus.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
t.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
d = x.XOpenDisplay(None)
assert d, 'No isolated display'
# A nested display has no window manager to establish input focus.
# Focus the real GTK popup before injecting navigation keys.
tree = subprocess.check_output(['/usr/bin/xwininfo', '-root', '-tree'], text=True)
menus = []
properties = []
for window in re.findall(r'^\s*(0x[0-9a-f]+)\s', tree, re.MULTILINE):
    prop = subprocess.check_output(['/usr/bin/xprop', '-id', window, '_NET_WM_WINDOW_TYPE'], text=True)
    properties.append(window + ': ' + prop.strip())
    if '_NET_WM_WINDOW_TYPE_DROPDOWN_MENU' in prop or '_NET_WM_WINDOW_TYPE_POPUP_MENU' in prop:
        menus.append(int(window, 16))
assert len(menus) == 1, 'Expected the production GTK menu: ' + tree + '\n' + '\n'.join(properties)
x.XSetInputFocus(d, menus[0], 2, 0)
x.XFlush(d)
for key in sys.argv[1:]:
    code = x.XKeysymToKeycode(d, x.XStringToKeysym(key.encode()))
    t.XTestFakeKeyEvent(d, code, 1, 0)
    t.XTestFakeKeyEvent(d, code, 0, 0)
    x.XFlush(d)
    time.sleep(0.08)
x.XCloseDisplay(d)
''',
      ...keys,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
}

class _Picker extends FileSelectorPlatform {
  XFile? selection;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => selection;
}
