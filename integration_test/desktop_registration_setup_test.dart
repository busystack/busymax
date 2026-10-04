import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/l10n/registration_setup_content.dart';
import 'package:busymax/src/providers/busy_provider.dart';
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
  testWidgets('Settings owns desktop registration forms, guides and error states', (
    tester,
  ) async {
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
    await _capture(tester, '$output/google-methods.png');
    expect(tester.widget<ElevatedButton>(_key('busymax')).onPressed, isNull);
    expect(_key('shared-unavailable'), findsOneWidget);
    await _back(tester);
    expect(_key('methods-dialog'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(_key('workspace'));
    await tester.pumpAndSettle();
    await _capture(tester, '$output/workspace-empty.png');
    await tester.tap(_key('import'));
    await tester.pumpAndSettle();
    await _capture(tester, '$output/workspace-imported.png');
    await tester.tap(_key('guide'));
    await tester.pumpAndSettle();
    await _inspectInstructions(
      tester,
      BusyProvider.google,
      DesktopConnectionMethod.googleWorkspace,
      '$output/workspace',
    );
    await _back(tester);
    expect(_key('summary'), findsOneWidget);
    await _back(tester);
    await tester.tap(_key('custom'));
    await tester.pumpAndSettle();
    // Both ownership pages share the same transactional importer and selection.
    expect(_key('summary'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Google account'));
    await tester.pumpAndSettle();
    await tester.tap(_key('custom'));
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
    expect(_key('back'), findsOneWidget);
    await _capture(tester, '$output/google-guide.png');
    await _inspectInstructions(
      tester,
      BusyProvider.google,
      DesktopConnectionMethod.custom,
      '$output/google',
    );
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
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
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
    await tester.ensureVisible(_key('back'));
    await tester.tap(_key('back'));
    await tester.pumpAndSettle();
    expect(_key('instructions-dialog'), findsNothing);
    expect(_key('summary'), findsOneWidget);
    await _capture(tester, '$output/google-instructions-closed.png');
    staging
        .cancel(); // Same notification as expiry, without waiting ten minutes.
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(_key('authorize')).onPressed, isNull);
    await _capture(tester, '$output/google-expired.png');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Microsoft account'));
    await tester.pumpAndSettle();
    await _capture(tester, '$output/microsoft-methods.png');
    expect(tester.widget<ElevatedButton>(_key('busymax')).onPressed, isNull);
    expect(_key('workspace'), findsNothing);
    await _back(tester);
    expect(_key('methods-dialog'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(_key('custom'));
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
    await _inspectInstructions(
      tester,
      BusyProvider.microsoft,
      DesktopConnectionMethod.custom,
      '$output/microsoft',
    );
    expect(_key('authorize').hitTestable(), findsNothing);
    await tester.ensureVisible(_key('copy-all'));
    await tester.pumpAndSettle();
    await _capture(tester, '$output/microsoft-guide-scrolled.png');
    await tester.ensureVisible(find.text('Open Microsoft Entra admin center'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Microsoft Entra admin center'));
    await tester.pumpAndSettle();
    await _capture(tester, '$output/microsoft-guide-link-error.png');
    await tester.ensureVisible(_key('back'));
    await tester.tap(_key('back'));
    await tester.pumpAndSettle();
    expect(_key('instructions-dialog'), findsNothing);
    expect(
      tester.widget<TextField>(_key('tenant-id')).controller!.text,
      'aabbccdd-1122-3344-5566-77889900aabb',
    );
    await _capture(tester, '$output/microsoft-instructions-closed.png');
    await _audience(tester, 1);
    expect(_key('tenant-id'), findsNothing);
    expect(
      tester.widget<ElevatedButton>(_key('authorize')).onPressed,
      isNotNull,
    );
    await _capture(tester, '$output/microsoft-organizations.png');
    await _audience(tester, 0);
    await _audience(tester, 2);
    expect(_key('tenant-id'), findsNothing);
    await _audience(tester, 3);
    expect(
      tester.widget<TextField>(_key('tenant-id')).controller!.text,
      isEmpty,
    );
    expect(tester.widget<ElevatedButton>(_key('authorize')).onPressed, isNull);
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
      await tester.runAsync(() => settings.setThemeModePreference(preference));
      await tester.pumpAndSettle();
      final mode = preference.name;
      for (final (name, methodKey) in [
        ('Google', 'workspace'),
        ('Google', 'custom'),
        ('Microsoft', 'custom'),
      ]) {
        await tester.tap(find.text('Add $name account'));
        await tester.pumpAndSettle();
        final prefix = '$output/${name.toLowerCase()}-$methodKey-$mode';
        await _capture(tester, '$prefix-methods.png');
        await tester.tap(_key(methodKey));
        await tester.pumpAndSettle();
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
        await tester.tap(_key('back'));
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
          await _nativeKeys(tester, ['Home', 'Down', 'Down', 'Down', 'Return']);
          await tester.pumpAndSettle();
          await tester.enterText(_key('tenant-id'), 'invalid');
          await tester.pumpAndSettle();
          await _capture(tester, '$prefix-error.png');
        }
        await tester.tap(_key('guide'));
        await tester.pumpAndSettle();
        await _back(tester);
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
    await tester.runAsync(() => settings.setLocaleTag('de'));
    await tester.pumpAndSettle();
    await _resize(tester, 720, 700);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await tester.pumpAndSettle();
    for (final provider in [BusyProvider.google, BusyProvider.microsoft]) {
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );
      final label = provider == BusyProvider.google
          ? l10n.addGoogleAccount
          : l10n.addMicrosoftAccount;
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await _capture(
        tester,
        '$output/${provider.storageValue}-narrow-german-methods.png',
      );
      await tester.ensureVisible(_key('custom'));
      await tester.tap(_key('custom'));
      await tester.pumpAndSettle();
      if (provider == BusyProvider.google) {
        await tester.tap(_key('import'));
      } else {
        await tester.enterText(
          _key('client-id'),
          '11223344-5566-7788-99aa-bbccddeeff00',
        );
      }
      await tester.pumpAndSettle();
      await _capture(
        tester,
        '$output/${provider.storageValue}-narrow-german-form.png',
      );
      if (provider == BusyProvider.microsoft) {
        await _audience(
          tester,
          0,
          capture: '$output/microsoft-narrow-german-menu.png',
        );
      }
      await tester.ensureVisible(_key('guide'));
      await tester.tap(_key('guide'));
      await tester.pumpAndSettle();
      await _capture(
        tester,
        '$output/${provider.storageValue}-narrow-german-guide.png',
      );
      await tester.ensureVisible(_key('copy-all'));
      await tester.pumpAndSettle();
      await _capture(
        tester,
        '$output/${provider.storageValue}-narrow-german-guide-scrolled.png',
      );
      await _back(tester);
      expect(_key('guide').hitTestable(), findsOneWidget);
      await tester.tap(_key('guide'));
      await tester.pumpAndSettle();
      await tester.tap(_key('close'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(_key('methods-dialog'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.runAsync(() => settings.setLocaleTag('en'));
    expect(await container.read(accountsStreamProvider.future), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, skip: output == null);
}

Finder _key(String value) => find.byKey(ValueKey('registration-$value'));

Future<void> _back(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

Future<void> _inspectInstructions(
  WidgetTester tester,
  BusyProvider provider,
  DesktopConnectionMethod method,
  String prefix,
) async {
  final l10n = AppLocalizations.of(tester.element(_key('instructions-dialog')));
  final steps = l10n.registrationDesktopSteps(provider, method: method);
  final header = tester.getTopLeft(_key('close'));
  for (var i = 0; i < steps.length; i++) {
    await tester.ensureVisible(find.text('${i + 1}. ${steps[i].heading}'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_key('close')), header);
    expect(_key('authorize'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is ModalBarrier && (w.color?.a ?? 0) > 0),
      findsOneWidget,
    );
    await _capture(tester, '$prefix-instructions-step-${i + 1}.png');
  }
  await tester.ensureVisible(_key('copy-all'));
  await tester.pumpAndSettle();
  await tester.tap(_key('copy-all'));
  await tester.pumpAndSettle();
  expect(
    (await Clipboard.getData(Clipboard.kTextPlain))?.text,
    steps.singleWhere((s) => s.copyAll).values,
  );
}

Future<void> _resize(WidgetTester tester, int width, int height) async {
  await tester.runAsync(() async {
    final result = await Process.run('/usr/bin/python3', [
      '-c',
      r'''import ctypes, re, subprocess, sys
x = ctypes.CDLL('libX11.so.6')
x.XOpenDisplay.argtypes = [ctypes.c_char_p]
x.XOpenDisplay.restype = ctypes.c_void_p
x.XResizeWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_uint, ctypes.c_uint]
x.XFlush.argtypes = [ctypes.c_void_p]
x.XCloseDisplay.argtypes = [ctypes.c_void_p]
tree = subprocess.check_output(['/usr/bin/xwininfo', '-root', '-tree'], text=True)
windows = re.findall(r'^\s*(0x[0-9a-f]+) "BusyMax":.*? (\d+)x(\d+)[+-]', tree, re.MULTILINE)
main = [item for item in windows if int(item[1]) > 300 and int(item[2]) > 300]
assert len(main) == 1
connection = x.XOpenDisplay(None)
x.XResizeWindow(connection, int(main[0][0], 16), int(sys.argv[1]), int(sys.argv[2]))
x.XFlush(connection)
x.XCloseDisplay(connection)
''',
      '$width',
      '$height',
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String path) async {
  // Capture only BusyMax from the native display, including GTK popup pixels.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final result = await Process.run('/usr/bin/python3', [
      '-c',
      r'''import sys, gi, re, subprocess
gi.require_version('Gdk', '3.0')
from gi.repository import Gdk
tree = subprocess.check_output(['/usr/bin/xwininfo', '-root', '-tree'], text=True)
windows = re.findall(r'^\s*(0x[0-9a-f]+) "BusyMax":.*? (\d+)x(\d+)[+-]', tree, re.MULTILINE)
main = [item for item in windows if int(item[1]) > 300 and int(item[2]) > 300]
assert len(main) == 1, 'Expected one isolated BusyMax application window'
info = subprocess.check_output(['/usr/bin/xwininfo', '-id', main[0][0]], text=True)
def field(name):
    return int(re.search(name + r':\s*(-?\d+)', info).group(1))
window = Gdk.get_default_root_window()
pixbuf = Gdk.pixbuf_get_from_window(window, field('Absolute upper-left X'), field('Absolute upper-left Y'), field('Width'), field('Height'))
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
  fail(
    'The native menu did not close with ${MicrosoftAudience.values[index]} selected.',
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
# Inspect the real GTK popup before injecting navigation keys.
tree = subprocess.check_output(['/usr/bin/xwininfo', '-root', '-tree'], text=True)
menus = []
properties = []
for window in re.findall(r'^\s*(0x[0-9a-f]+)\s', tree, re.MULTILINE):
    prop = subprocess.check_output(['/usr/bin/xprop', '-id', window, '_NET_WM_WINDOW_TYPE'], text=True)
    properties.append(window + ': ' + prop.strip())
    if '_NET_WM_WINDOW_TYPE_DROPDOWN_MENU' in prop or '_NET_WM_WINDOW_TYPE_POPUP_MENU' in prop:
        menus.append(int(window, 16))
assert len(menus) == 1, 'Expected the production GTK menu: ' + tree + '\n' + '\n'.join(properties)
main = re.findall(r'^\s*(0x[0-9a-f]+) \"BusyMax\":.*? (\d+)x(\d+)[+-]', tree, re.MULTILINE)
main = [item for item in main if int(item[1]) > 300 and int(item[2]) > 300]
assert len(main) == 1
# GTK's keyboard grab routes keys from its focused application to the menu.
x.XSetInputFocus(d, int(main[0][0], 16), 2, 0)
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
