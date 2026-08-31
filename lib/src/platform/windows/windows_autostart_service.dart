import 'package:flutter/services.dart';

import '../common/desktop_services.dart';
import 'windows_window_service.dart';

final class WindowsAutostartService implements DesktopAutostartService {
  const WindowsAutostartService({
    MethodChannel channel = const MethodChannel(windowsDesktopChannelName),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<DesktopAutostartState> state() async {
    try {
      final value = await _channel.invokeMethod<String>('getStartupTaskState');
      return switch (value) {
        'enabled' => DesktopAutostartState.enabled,
        'disabled' => DesktopAutostartState.disabled,
        'disabledByUser' => DesktopAutostartState.disabledByUser,
        'disabledByPolicy' => DesktopAutostartState.disabledByPolicy,
        _ => DesktopAutostartState.unavailable,
      };
    } on MissingPluginException {
      return DesktopAutostartState.unavailable;
    } on PlatformException {
      return DesktopAutostartState.unavailable;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final current = await state();
    if (current == DesktopAutostartState.unavailable ||
        current == DesktopAutostartState.disabledByPolicy) {
      throw UnsupportedError('Windows StartupTask is unavailable.');
    }
    await _channel.invokeMethod<void>('setStartupTaskEnabled', enabled);
  }
}
