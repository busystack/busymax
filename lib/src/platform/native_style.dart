import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

@immutable
final class BusyMaxNativeSurfaceTheme {
  const BusyMaxNativeSurfaceTheme({
    required this.highContrast,
    required this.windowBackgroundColor,
    required this.dialogBackgroundColor,
    required this.dialogOutlineColor,
    required this.tooltipBackgroundColor,
    required this.tooltipForegroundColor,
    required this.tooltipBorderColor,
    required this.tooltipRadius,
    required this.tooltipFontSize,
    required this.tooltipHorizontalPadding,
    required this.tooltipVerticalPadding,
    required this.tooltipMinimumHeight,
  });

  final bool highContrast;
  final Color windowBackgroundColor;
  final Color dialogBackgroundColor;
  final Color dialogOutlineColor;
  final Color tooltipBackgroundColor;
  final Color tooltipForegroundColor;
  final Color tooltipBorderColor;
  final double tooltipRadius;
  final double tooltipFontSize;
  final double tooltipHorizontalPadding;
  final double tooltipVerticalPadding;
  final double tooltipMinimumHeight;

  Map<String, Object> toMessage() => <String, Object>{
    'highContrast': highContrast,
    'windowBackgroundColor': busyMaxCssColor(windowBackgroundColor),
    'dialogBackgroundColor': busyMaxCssColor(dialogBackgroundColor),
    'dialogOutlineColor': busyMaxCssColor(dialogOutlineColor),
    'tooltipBackgroundColor': busyMaxCssColor(tooltipBackgroundColor),
    'tooltipForegroundColor': busyMaxCssColor(tooltipForegroundColor),
    'tooltipBorderColor': busyMaxCssColor(tooltipBorderColor),
    'tooltipRadius': tooltipRadius,
    'tooltipFontSize': tooltipFontSize,
    'tooltipHorizontalPadding': tooltipHorizontalPadding,
    'tooltipVerticalPadding': tooltipVerticalPadding,
    'tooltipMinimumHeight': tooltipMinimumHeight,
  };

  @override
  bool operator ==(Object other) =>
      other is BusyMaxNativeSurfaceTheme &&
      other.highContrast == highContrast &&
      other.windowBackgroundColor == windowBackgroundColor &&
      other.dialogBackgroundColor == dialogBackgroundColor &&
      other.dialogOutlineColor == dialogOutlineColor &&
      other.tooltipBackgroundColor == tooltipBackgroundColor &&
      other.tooltipForegroundColor == tooltipForegroundColor &&
      other.tooltipBorderColor == tooltipBorderColor &&
      other.tooltipRadius == tooltipRadius &&
      other.tooltipFontSize == tooltipFontSize &&
      other.tooltipHorizontalPadding == tooltipHorizontalPadding &&
      other.tooltipVerticalPadding == tooltipVerticalPadding &&
      other.tooltipMinimumHeight == tooltipMinimumHeight;

  @override
  int get hashCode => Object.hashAll([
    highContrast,
    windowBackgroundColor,
    dialogBackgroundColor,
    dialogOutlineColor,
    tooltipBackgroundColor,
    tooltipForegroundColor,
    tooltipBorderColor,
    tooltipRadius,
    tooltipFontSize,
    tooltipHorizontalPadding,
    tooltipVerticalPadding,
    tooltipMinimumHeight,
  ]);
}

/// Applies semantic colors only to retained native surfaces.
///
/// Flutter owns the main header and sidebar. This bridge remains for GTK
/// dialogs, native tooltips, the window backing surface, and decorations.
final class NativeSurfaceStyleService {
  const NativeSurfaceStyleService({
    MethodChannel channel = const MethodChannel(
      'io.busystack.busymax/gtk_settings',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<void> setTheme(BusyMaxNativeSurfaceTheme theme) async {
    try {
      await _channel.invokeMethod<void>(
        'setNativeSurfaceTheme',
        theme.toMessage(),
      );
    } on MissingPluginException {
      // Lightweight tests and non-Linux compositions have no GTK bridge.
    } on PlatformException {
      // Native styling is advisory; Flutter remains fully themed.
    }
  }
}

String busyMaxCssColor(Color color) {
  final rgb = color.toARGB32() & 0x00ffffff;
  if (color.a >= 1) {
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
  final red = (rgb >> 16) & 0xff;
  final green = (rgb >> 8) & 0xff;
  final blue = rgb & 0xff;
  return 'rgba($red,$green,$blue,${color.a.toStringAsFixed(2)})';
}
