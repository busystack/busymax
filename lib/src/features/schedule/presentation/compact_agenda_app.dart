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
import '../../../app/system_accent.dart';
import '../../../platform/gtk_font_service.dart';
import '../application/compact_agenda_data.dart';
import 'compact_agenda_panel.dart';

class BusyMaxCompactAgendaApp extends ConsumerStatefulWidget {
  const BusyMaxCompactAgendaApp({required this.windowController, super.key});

  final WindowController windowController;

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
        await _show();
        return true;
      case 'busymax.compactAgenda.hide':
        await windowManager.hide();
        return true;
      case 'busymax.compactAgenda.toggle':
        final visible = await windowManager.isVisible();
        final focused = await _isFocused();
        if (visible && focused) {
          await windowManager.hide();
        } else {
          await _show();
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

  Future<void> _show() async {
    await windowManager.setAlignment(Alignment.topRight);
    await windowManager.show();
    await windowManager.focus();
    ref.invalidate(compactAgendaDataProvider);
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
    unawaited(windowManager.hide());
  }

  @override
  void onWindowBlur() {
    unawaited(_hideAfterBlurDelay());
  }

  Future<void> _hideAfterBlurDelay() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!await _isFocused()) {
      await windowManager.hide();
    }
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
            body: CompactAgendaPanel(),
          ),
        );
      },
    );
  }
}
