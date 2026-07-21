import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:system_theme/system_theme.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/app_theme.dart';
import '../../../app/busymax_design.dart';
import '../../../app/system_accent.dart';
import '../../../platform/gtk_font_service.dart';
import '../../../platform/busymax_window_args.dart';
import '../application/compact_agenda_data.dart';
import 'compact_agenda_panel.dart';

const _compactAgendaPanelWidth = 420.0;
const _compactAgendaPanelHeight = 680.0;
const _compactAgendaWindowSize = Size(
  _compactAgendaPanelWidth + BusyMaxShadow.windowMargin * 2,
  _compactAgendaPanelHeight + BusyMaxShadow.windowMargin * 2,
);
const _compactAgendaWindowChannel = MethodChannel(
  'io.busystack.busymax/compact_agenda_window',
);
final _compactAgendaWindowLogger = Logger('BusyMaxCompactAgendaWindow');

class BusyMaxCompactAgendaApp extends ConsumerStatefulWidget {
  const BusyMaxCompactAgendaApp({
    required this.windowController,
    required this.windowArgs,
    super.key,
  });

  final WindowController windowController;
  final BusyMaxWindowArgs windowArgs;

  @override
  ConsumerState<BusyMaxCompactAgendaApp> createState() =>
      _BusyMaxCompactAgendaAppState();
}

class _BusyMaxCompactAgendaAppState
    extends ConsumerState<BusyMaxCompactAgendaApp>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    unawaited(
      widget.windowController.setWindowMethodHandler(_handleWindowMethodCall),
    );
    windowManager.addListener(this);
    unawaited(windowManager.setPreventClose(true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_show());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_clearWindowMethodHandler());
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<Object?> _handleWindowMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'busymax.compactAgenda.show':
        await _show(call.arguments);
        return true;
      case 'busymax.compactAgenda.hide':
        await widget.windowController.hide();
        return true;
      case 'busymax.compactAgenda.toggle':
        final visible = await windowManager.isVisible();
        final focused = await _isFocused();
        if (visible && focused) {
          await widget.windowController.hide();
        } else {
          await _show(call.arguments);
        }
        return true;
      case 'busymax.compactAgenda.refresh':
        ref.invalidate(compactAgendaDataProvider);
        ref.invalidate(compactAgendaDataForQueryProvider);
        return true;
      case 'busymax.compactAgenda.destroy':
        unawaited(_destroyWindow());
        return true;
    }

    throw MissingPluginException('Not implemented: ${call.method}');
  }

  Future<void> _destroyWindow() async {
    await _clearWindowMethodHandler();
    try {
      await windowManager.setPreventClose(false);
    } on Object {
      // The native window can already be gone during app shutdown.
    }
    try {
      await windowManager.destroy();
    } on Object {
      // Ignore stale secondary-window removal during main-process shutdown.
    }
  }

  Future<void> _clearWindowMethodHandler() async {
    try {
      await widget.windowController.setWindowMethodHandler(null);
    } on Object {
      // The compact engine may already be unregistering during app shutdown.
    }
  }

  Future<void> _show([Object? rawArgs]) async {
    final position = _requestedPosition(rawArgs) ?? _initialRequestedPosition();
    _logPositioning('show requested', position);
    final shownNatively = await _showNativeWindow(position);
    if (!shownNatively) {
      await _moveNearTrayArea(position);
      await widget.windowController.show();
      unawaited(_focusNearTrayArea());
    }
    ref.invalidate(compactAgendaDataProvider);
    ref.invalidate(compactAgendaDataForQueryProvider);
  }

  Future<bool> _showNativeWindow(Offset? position) async {
    const attempts = 8;
    const retryDelay = Duration(milliseconds: 60);
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      try {
        final result = await _compactAgendaWindowChannel.invokeMethod<bool>(
          'show',
          _nativeWindowArguments(position),
        );
        final succeeded = result ?? false;
        _logPositioning(
          'native show completed native_position_succeeded=$succeeded',
          position,
        );
        return succeeded;
      } on MissingPluginException {
        if (attempt == attempts - 1) {
          _logPositioning('native show unavailable', position, warning: true);
          return false;
        }
      } on Object catch (error) {
        if (attempt == attempts - 1) {
          _logPositioning(
            'native show failed error=$error',
            position,
            warning: true,
          );
          return false;
        }
      }
      await Future<void>.delayed(retryDelay);
    }
    return false;
  }

  Future<void> _moveNearTrayArea(Offset? requestedPosition) async {
    try {
      final position = requestedPosition ?? _initialRequestedPosition();
      if (position == null) {
        await windowManager.setSize(_compactAgendaWindowSize);
        await windowManager.setAlignment(Alignment.topRight);
        _logPositioning('window_manager fallback aligned topRight', null);
        return;
      }
      await windowManager.setBounds(
        null,
        position: position,
        size: _compactAgendaWindowSize,
      );
      _logPositioning('window_manager fallback setBounds succeeded', position);
    } on Object catch (error) {
      _logPositioning(
        'window_manager fallback failed error=$error',
        requestedPosition,
        warning: true,
      );
      // Positioning is best-effort, especially on Wayland.
    }
  }

  Future<void> _focusNearTrayArea() async {
    try {
      await windowManager.focus();
    } on Object {
      // Positioning is best-effort, especially on Wayland.
    }
  }

  Offset? _initialRequestedPosition() {
    final x = widget.windowArgs.requestedPositionX;
    final y = widget.windowArgs.requestedPositionY;
    if (x == null || y == null) {
      return null;
    }
    return Offset(x, y);
  }

  Offset? _requestedPosition(Object? rawArgs) {
    if (rawArgs is! Map) {
      return null;
    }
    final position = rawArgs['position'];
    if (position is! Map) {
      return null;
    }
    final x = position['x'];
    final y = position['y'];
    if (x is! num || y is! num) {
      return null;
    }
    final dx = x.toDouble();
    final dy = y.toDouble();
    if (!dx.isFinite || !dy.isFinite) {
      return null;
    }
    return Offset(dx, dy);
  }

  Map<String, Object?> _nativeWindowArguments(Offset? position) {
    return {
      if (position != null) ...{'x': position.dx, 'y': position.dy},
      'width': _compactAgendaWindowSize.width,
      'height': _compactAgendaWindowSize.height,
    };
  }

  void _logPositioning(String event, Offset? position, {bool warning = false}) {
    final requested = position == null
        ? 'requested_x=<none> requested_y=<none>'
        : 'requested_x=${position.dx.round()} requested_y=${position.dy.round()}';
    final session = Platform.environment['XDG_SESSION_TYPE'] ?? '<unknown>';
    final backend = Platform.environment['GDK_BACKEND'] ?? '<unset>';
    final message =
        'Compact agenda positioning: event="$event" $requested '
        'final_width=${_compactAgendaWindowSize.width.round()} '
        'final_height=${_compactAgendaWindowSize.height.round()} '
        'session=$session gdk_backend=$backend';
    if (warning) {
      _compactAgendaWindowLogger.warning(message);
    } else {
      _compactAgendaWindowLogger.fine(message);
    }
  }

  Future<bool> _isFocused() async {
    try {
      return await windowManager.isFocused();
    } on Object {
      return false;
    }
  }

  @override
  void onWindowClose() {
    unawaited(widget.windowController.hide());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final ubuntuAccentColor = ref
        .watch(ubuntuSystemAccentColorProvider)
        .valueOrNull;
    final gtkFont = ref.watch(gtkFontSettingsProvider).valueOrNull;
    final gtkThemeColors = ref.watch(gtkThemeColorsProvider).valueOrNull;

    return SystemThemeBuilder(
      builder: (context, systemColor) {
        final accentColor =
            ubuntuAccentColor ?? gtkThemeColors?.accent ?? systemColor.accent;
        return MaterialApp(
          title: 'BusyMax Agenda',
          debugShowCheckedModeBanner: false,
          theme: buildBusyMaxTheme(
            brightness: Brightness.light,
            accentColor: accentColor,
            family: settings.themeFamily,
            gtkFontFamily: gtkFont?.family,
            gtkFontSize: gtkFont?.size,
            gtkThemeColors: gtkThemeColors,
          ),
          darkTheme: buildBusyMaxTheme(
            brightness: Brightness.dark,
            accentColor: accentColor,
            family: settings.themeFamily,
            gtkFontFamily: gtkFont?.family,
            gtkFontSize: gtkFont?.size,
            gtkThemeColors: gtkThemeColors,
          ),
          themeMode: settings.themeMode,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            ...GlobalUbuntuLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            backgroundColor: Colors.transparent,
            body: Padding(
              padding: EdgeInsets.all(BusyMaxShadow.windowMargin),
              child: CompactAgendaPanel(),
            ),
          ),
        );
      },
    );
  }
}
