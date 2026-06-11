import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'busymax_window_args.dart';

const _compactAgendaWindowWidth = 420.0;
const _compactAgendaWindowHeight = 680.0;
const _compactAgendaWindowShadowMargin = 32.0;
const _compactAgendaPanelScreenGap = 6.0;

class CompactAgendaWindowService {
  const CompactAgendaWindowService();

  Future<void> toggle() async {
    final position = await _preferredCompactAgendaPosition();
    final controller = await _findCompactAgendaWindow();
    if (controller == null) {
      await _createCompactAgendaWindow(position);
      return;
    }
    await _invokeCompactMethod(
      controller,
      'busymax.compactAgenda.toggle',
      position,
    );
  }

  Future<void> show() async {
    final position = await _preferredCompactAgendaPosition();
    final controller = await _findCompactAgendaWindow();
    if (controller == null) {
      await _createCompactAgendaWindow(position);
      return;
    }
    await _invokeCompactMethod(
      controller,
      'busymax.compactAgenda.show',
      position,
    );
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

  Future<void> _createCompactAgendaWindow(Offset position) async {
    await WindowController.create(
      WindowConfiguration(
        arguments: BusyMaxWindowArgs.compactAgendaAt(
          x: position.dx,
          y: position.dy,
        ).encode(),
        hiddenAtLaunch: true,
      ),
    );
  }

  Future<void> _invokeCompactMethod(
    WindowController controller,
    String method,
    Offset position,
  ) async {
    const attempts = 12;
    const retryDelay = Duration(milliseconds: 80);
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      try {
        await controller.invokeMethod<bool>(
          method,
          _positionMethodArguments(position),
        );
        return;
      } on Object {
        if (attempt == attempts - 1) {
          return;
        }
        await Future<void>.delayed(retryDelay);
      }
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

  Future<Offset> _preferredCompactAgendaPosition() async {
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final displays = await screenRetriever.getAllDisplays();
      final cursor = await screenRetriever.getCursorScreenPoint();
      final display = displays.firstWhere((display) {
        final position = display.visiblePosition ?? Offset.zero;
        final size = display.visibleSize ?? display.size;
        return Rect.fromLTWH(
          position.dx,
          position.dy,
          size.width,
          size.height,
        ).contains(cursor);
      }, orElse: () => primaryDisplay);
      return _topRightWorkAreaPosition(display);
    } on Object {
      try {
        return _topRightWorkAreaPosition(
          await screenRetriever.getPrimaryDisplay(),
        );
      } on Object {
        return Offset.zero;
      }
    }
  }

  Map<String, Object?> _positionMethodArguments(Offset position) {
    return {
      'position': {'x': position.dx, 'y': position.dy},
    };
  }

  Offset _topRightWorkAreaPosition(Display display) {
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;
    final visibleFrame = Rect.fromLTWH(
      visiblePosition.dx,
      visiblePosition.dy,
      visibleSize.width,
      visibleSize.height,
    );
    final panelLeft = _clampToVisibleFrame(
      visibleFrame.right -
          _compactAgendaWindowWidth -
          _compactAgendaPanelScreenGap,
      visibleFrame.left + _compactAgendaPanelScreenGap,
      visibleFrame.right -
          _compactAgendaWindowWidth -
          _compactAgendaPanelScreenGap,
    );
    final panelTop = _clampToVisibleFrame(
      visibleFrame.top + _compactAgendaPanelScreenGap,
      visibleFrame.top + _compactAgendaPanelScreenGap,
      visibleFrame.bottom -
          _compactAgendaWindowHeight -
          _compactAgendaPanelScreenGap,
    );
    return Offset(
      panelLeft - _compactAgendaWindowShadowMargin,
      panelTop - _compactAgendaWindowShadowMargin,
    );
  }

  double _clampToVisibleFrame(double value, double min, double max) {
    if (max < min) {
      return min;
    }
    return value.clamp(min, max).toDouble();
  }
}
