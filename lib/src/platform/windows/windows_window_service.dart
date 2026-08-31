import 'package:flutter/services.dart';

import '../common/desktop_services.dart';

const windowsDesktopChannelName = 'org.busystack.busymax/windows_desktop';

final class WindowsWindowService implements DesktopWindowService {
  const WindowsWindowService({
    MethodChannel channel = const MethodChannel(windowsDesktopChannelName),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<void> reportNotificationActivationFailure() =>
      _channel.invokeMethod<void>('reportNotificationActivationFailure');

  @override
  Future<void> hideWindow() => _channel.invokeMethod<void>('hide');

  @override
  Future<bool> isWindowVisible() async =>
      await _channel.invokeMethod<bool>('isVisible') ?? true;

  @override
  Future<void> quitApp() => _channel.invokeMethod<void>('quit');

  @override
  Future<void> setHideOnClose(bool enabled) =>
      _channel.invokeMethod<void>('setHideOnClose', enabled);

  @override
  Future<void> showWindow() => _channel.invokeMethod<void>('showAndFocus');
}
