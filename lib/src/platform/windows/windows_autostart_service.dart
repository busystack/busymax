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
        'enabledByPolicy' => DesktopAutostartState.enabledByPolicy,
        'disabled' => DesktopAutostartState.disabled,
        'disabledByUser' => DesktopAutostartState.disabledByUser,
        'disabledByPolicy' => DesktopAutostartState.disabledByPolicy,
        _ => DesktopAutostartState.unavailable,
      };
    } on MissingPluginException {
      return DesktopAutostartState.unavailable;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final current = await state();
    if (!current.canChange) {
      throw UnsupportedError('Windows StartupTask cannot be changed here.');
    }
    await _channel.invokeMethod<void>('setStartupTaskEnabled', enabled);
  }
}
