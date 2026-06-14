import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'busymax_window_args.dart';

const _compactAgendaWindowWidth = 420.0;
const _compactAgendaWindowHeight = 680.0;
const _compactAgendaWindowShadowMargin = 32.0;
const _compactAgendaPanelScreenGap = 6.0;
const _compactAgendaWindowFrameWidth =
    _compactAgendaWindowWidth + _compactAgendaWindowShadowMargin * 2;
const _compactAgendaWindowFrameHeight =
    _compactAgendaWindowHeight + _compactAgendaWindowShadowMargin * 2;

@visibleForTesting
Offset compactAgendaTopRightWorkAreaPositionForTest(Rect workarea) {
  return _topRightWorkAreaPlacement(workarea).finalPosition;
}

class CompactAgendaWindowService {
  const CompactAgendaWindowService();

  static final Logger _logger = Logger('CompactAgendaWindowService');

  Future<void> toggle() async {
    final position = await _preferredCompactAgendaPosition();
    _logPlacementRequest('toggle', position);
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
    _logPlacementRequest('show', position);
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
    final List<WindowController> controllers;
    try {
      controllers = await WindowController.getAll();
    } on Object {
      return null;
    }
    for (final controller in controllers) {
      final args = BusyMaxWindowArgs.parse(controller.arguments);
      if (args.kind == BusyMaxWindowKind.compactAgenda) {
        return controller;
      }
    }
    return null;
  }

  Future<void> _createCompactAgendaWindow(Offset position) async {
    _logger.fine(
      'Compact agenda create requested: final_x=${position.dx.round()} '
      'final_y=${position.dy.round()} ${_sessionDescription()}',
    );
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
        _logger.fine(
          'Compact agenda native position invocation succeeded: method=$method '
          'final_x=${position.dx.round()} final_y=${position.dy.round()} '
          '${_sessionDescription()}',
        );
        return;
      } on Object catch (error) {
        if (attempt == attempts - 1) {
          _logger.warning(
            'Compact agenda native position invocation failed: method=$method '
            'final_x=${position.dx.round()} final_y=${position.dy.round()} '
            'error=$error ${_sessionDescription()}',
          );
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
        final frame = _visibleFrame(display);
        return frame.contains(cursor);
      }, orElse: () => primaryDisplay);
      final placement = _topRightWorkAreaPlacement(_visibleFrame(display));
      _logger.fine(
        'Compact agenda monitor placement resolved: cursor_x=${cursor.dx.round()} '
        'cursor_y=${cursor.dy.round()} workarea=${_displayGeometry(display)} '
        'raw_x=${placement.rawPosition.dx.round()} '
        'raw_y=${placement.rawPosition.dy.round()} '
        'final_x=${placement.finalPosition.dx.round()} '
        'final_y=${placement.finalPosition.dy.round()} '
        'window_width=${_compactAgendaWindowFrameWidth.round()} '
        'window_height=${_compactAgendaWindowFrameHeight.round()} '
        '${_sessionDescription()}',
      );
      return placement.finalPosition;
    } on Object catch (error) {
      try {
        final display = await screenRetriever.getPrimaryDisplay();
        final placement = _topRightWorkAreaPlacement(_visibleFrame(display));
        _logger.warning(
          'Compact agenda cursor placement fallback used: '
          'workarea=${_displayGeometry(display)} '
          'raw_x=${placement.rawPosition.dx.round()} '
          'raw_y=${placement.rawPosition.dy.round()} '
          'final_x=${placement.finalPosition.dx.round()} '
          'final_y=${placement.finalPosition.dy.round()} '
          'window_width=${_compactAgendaWindowFrameWidth.round()} '
          'window_height=${_compactAgendaWindowFrameHeight.round()} '
          'error=$error ${_sessionDescription()}',
        );
        return placement.finalPosition;
      } on Object catch (fallbackError) {
        _logger.warning(
          'Compact agenda placement fallback failed: error=$fallbackError '
          '${_sessionDescription()}',
        );
        return Offset.zero;
      }
    }
  }

  Map<String, Object?> _positionMethodArguments(Offset position) {
    return {
      'position': {'x': position.dx, 'y': position.dy},
    };
  }

  Rect _visibleFrame(Display display) {
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;
    return Rect.fromLTWH(
      visiblePosition.dx,
      visiblePosition.dy,
      visibleSize.width,
      visibleSize.height,
    );
  }

  void _logPlacementRequest(String action, Offset position) {
    _logger.fine(
      'Compact agenda placement requested: action=$action '
      'final_x=${position.dx.round()} final_y=${position.dy.round()} '
      'window_width=${_compactAgendaWindowFrameWidth.round()} '
      'window_height=${_compactAgendaWindowFrameHeight.round()} '
      '${_sessionDescription()}',
    );
  }

  String _displayGeometry(Display display) {
    final frame = _visibleFrame(display);
    return '${frame.left.round()},${frame.top.round()},'
        '${frame.width.round()}x${frame.height.round()}';
  }

  static String _sessionDescription() {
    final session = Platform.environment['XDG_SESSION_TYPE'] ?? '<unknown>';
    final backend = Platform.environment['GDK_BACKEND'] ?? '<unset>';
    return 'session=$session gdk_backend=$backend';
  }
}

_CompactAgendaPlacement _topRightWorkAreaPlacement(Rect workarea) {
  final rawPosition = Offset(
    workarea.right -
        _compactAgendaWindowFrameWidth -
        _compactAgendaPanelScreenGap,
    workarea.top + _compactAgendaPanelScreenGap,
  );
  return _CompactAgendaPlacement(
    rawPosition: rawPosition,
    finalPosition: _clampWindowPositionToWorkArea(rawPosition, workarea),
  );
}

Offset _clampWindowPositionToWorkArea(Offset position, Rect workarea) {
  return Offset(
    _clampToVisibleFrame(
      position.dx,
      workarea.left + _compactAgendaPanelScreenGap,
      workarea.right -
          _compactAgendaWindowFrameWidth -
          _compactAgendaPanelScreenGap,
    ),
    _clampToVisibleFrame(
      position.dy,
      workarea.top + _compactAgendaPanelScreenGap,
      workarea.bottom -
          _compactAgendaWindowFrameHeight -
          _compactAgendaPanelScreenGap,
    ),
  );
}

double _clampToVisibleFrame(double value, double min, double max) {
  if (max < min) {
    return min;
  }
  return value.clamp(min, max).toDouble();
}

class _CompactAgendaPlacement {
  const _CompactAgendaPlacement({
    required this.rawPosition,
    required this.finalPosition,
  });

  final Offset rawPosition;
  final Offset finalPosition;
}
