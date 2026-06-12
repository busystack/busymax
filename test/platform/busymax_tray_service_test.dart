import 'dart:io';

import 'package:busymax/src/platform/busymax_tray_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tray menu contains only app, agenda, and exit actions', () {
    var openedApp = false;
    var openedAgenda = false;
    var quit = false;

    final menu = buildBusyMaxTrayMenu(
      labels: _labels,
      onOpenBusyMax: () async {
        openedApp = true;
      },
      onOpenAgenda: () async {
        openedAgenda = true;
      },
      onQuit: () async {
        quit = true;
      },
    );

    expect(menu.children, hasLength(3));
    expect(menu.children.map((item) => item.label), [
      'Open app',
      'Agenda',
      'Exit',
    ]);
    expect(menu.children.every((item) => item.enabled != false), isTrue);

    menu.children[0].onClicked?.call();
    menu.children[1].onClicked?.call();
    menu.children[2].onClicked?.call();

    expect(openedApp, isTrue);
    expect(openedAgenda, isTrue);
    expect(quit, isTrue);
  });

  test('application id uses Busystack reverse DNS id', () {
    expect(busyMaxApplicationId, 'io.busystack.busymax');
  });

  test('Linux desktop identity matches the displayed BusyMax window', () {
    final desktop = File(
      'linux/io.busystack.busymax.desktop',
    ).readAsStringSync();
    final cmake = File('linux/CMakeLists.txt').readAsStringSync();
    final runner = File('linux/runner/my_application.cc').readAsStringSync();

    expect(desktop, contains('Name=BusyMax'));
    expect(desktop, contains('Icon=io.busystack.busymax'));
    expect(desktop, contains('StartupWMClass=io.busystack.busymax'));
    expect(
      cmake,
      contains(r'"${CMAKE_CURRENT_SOURCE_DIR}/io.busystack.busymax.desktop"'),
    );
    expect(
      cmake,
      contains(
        r'"${CMAKE_CURRENT_SOURCE_DIR}/io.busystack.busymax.metainfo.xml"',
      ),
    );
    expect(
      cmake,
      contains(
        r'"${CMAKE_CURRENT_SOURCE_DIR}/../assets/branding/busymax-logo.svg"',
      ),
    );
    expect(cmake, contains('share/icons/hicolor/scalable/apps'));
    expect(cmake, contains('RENAME "io.busystack.busymax.svg"'));
    const pngExtension = 'png';
    expect(cmake, isNot(contains('.$pngExtension')));
    final iconFileName =
        '${busyMaxApplicationId.split('.').last}.$pngExtension';
    for (final size in [64, 128, 256]) {
      final path = [
        'linux',
        'runner',
        'resources',
        'icons',
        '${size}x$size',
        'apps',
        iconFileName,
      ].join(Platform.pathSeparator);
      expect(File(path).existsSync(), isFalse);
    }
    expect(
      runner,
      contains(
        'gtk_window_set_wmclass(window, APPLICATION_ID, APPLICATION_ID);',
      ),
    );
    expect(
      runner,
      contains(
        'if (application_icon == nullptr) {\n'
        '    gtk_window_set_icon_name(window, APPLICATION_ID);\n'
        '  }',
      ),
    );
  });

  test('agenda action no longer opens the main window', () {
    final source = File(
      'lib/src/platform/busymax_tray_service.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _showAgenda()'));
    expect(source, contains('return _onOpenAgenda();'));
    expect(
      source,
      isNot(
        contains(
          'await _windowService.showWindow();\n'
          '    await _onOpenAgenda();',
        ),
      ),
    );
    expect(source, contains('await _onBeforeQuit?.call();'));
  });
}

const _labels = BusyMaxTrayLabels(
  openBusyMax: 'Open app',
  agenda: 'Agenda',
  quitBusyMax: 'Exit',
);
