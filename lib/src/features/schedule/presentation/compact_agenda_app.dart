import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    unawaited(widget.windowController.setWindowMethodHandler(null));
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
        return true;
      case 'busymax.compactAgenda.destroy':
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
        return true;
    }

    throw MissingPluginException('Not implemented: ${call.method}');
  }

  Future<void> _show([Object? rawArgs]) async {
    final position = _requestedPosition(rawArgs) ?? _initialRequestedPosition();
    final shownNatively = await _showNativeWindow(position);
    if (!shownNatively) {
      await _moveNearTrayArea(position);
      await widget.windowController.show();
      unawaited(_focusNearTrayArea());
    }
    ref.invalidate(compactAgendaDataProvider);
  }

  Future<bool> _showNativeWindow(Offset? position) async {
    try {
      final result = await _compactAgendaWindowChannel.invokeMethod<bool>(
        'show',
        _nativeWindowArguments(position),
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on Object {
      return false;
    }
  }

  Future<void> _moveNearTrayArea(Offset? requestedPosition) async {
    try {
      final position = requestedPosition ?? _initialRequestedPosition();
      if (position == null) {
        await windowManager.setSize(_compactAgendaWindowSize);
        await windowManager.setAlignment(Alignment.topRight);
        return;
      }
      await windowManager.setBounds(
        null,
        position: position,
        size: _compactAgendaWindowSize,
      );
    } on Object {
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
        final accentColor = ubuntuAccentColor ?? systemColor.accent;
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
