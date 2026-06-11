import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'busymax_window_args.dart';

class CompactAgendaWindowService {
  const CompactAgendaWindowService();

  Future<void> toggle() async {
    final controller = await _findCompactAgendaWindow();
    if (controller == null) {
      await _createCompactAgendaWindow();
      return;
    }
    await _invokeOrShow(controller, 'busymax.compactAgenda.toggle');
  }

  Future<void> show() async {
    final controller = await _findCompactAgendaWindow();
    if (controller == null) {
      await _createCompactAgendaWindow();
      return;
    }
    await _invokeOrShow(controller, 'busymax.compactAgenda.show');
  }

  Future<void> hide() async {
    final controller = await _findCompactAgendaWindow();
    if (controller == null) {
      return;
    }
    await _invokeOrIgnore(controller, 'busymax.compactAgenda.hide');
  }

  Future<void> closeIfOpen() async {
    final controller = await _findCompactAgendaWindow();
    if (controller == null) {
      return;
    }
    await _invokeOrIgnore(controller, 'busymax.compactAgenda.destroy');
  }

  Future<WindowController?> _findCompactAgendaWindow() async {
    final controllers = await WindowController.getAll();
    for (final controller in controllers) {
      final args = BusyMaxWindowArgs.parse(controller.arguments);
      if (args.kind == BusyMaxWindowKind.compactAgenda) {
        return controller;
      }
    }
    return null;
  }

  Future<void> _createCompactAgendaWindow() async {
    final controller = await WindowController.create(
      WindowConfiguration(
        arguments: BusyMaxWindowArgs.compactAgenda.encode(),
        hiddenAtLaunch: true,
      ),
    );
    await _invokeOrShow(controller, 'busymax.compactAgenda.show');
  }

  Future<void> _invokeOrShow(WindowController controller, String method) async {
    try {
      await controller.invokeMethod<bool>(method);
    } on Object {
      await controller.show();
    }
  }

  Future<void> _invokeOrIgnore(
    WindowController controller,
    String method,
  ) async {
    try {
      await controller.invokeMethod<bool>(method);
    } on Object {
      // Window may already be closing; nothing useful to do.
    }
  }
}
