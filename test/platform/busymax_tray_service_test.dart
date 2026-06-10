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
}

const _labels = BusyMaxTrayLabels(
  openBusyMax: 'Open app',
  agenda: 'Agenda',
  quitBusyMax: 'Exit',
);
