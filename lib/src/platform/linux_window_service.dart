import 'package:flutter/services.dart';

import 'common/desktop_services.dart';

class LinuxWindowService implements DesktopWindowService {
  const LinuxWindowService({
    MethodChannel channel = const MethodChannel('io.busystack.busymax/window'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> setHideOnClose(bool enabled) {
    return _channel.invokeMethod<void>('setHideOnClose', enabled);
  }

  @override
  Future<void> hideWindow() {
    return _channel.invokeMethod<void>('hideWindow');
  }

  @override
  Future<void> showWindow() {
    return _channel.invokeMethod<void>('showWindow');
  }

  @override
  Future<void> quitApp() {
    return _channel.invokeMethod<void>('quitApp');
  }

  @override
  Future<bool> isWindowVisible() async {
    return await _channel.invokeMethod<bool>('isWindowVisible') ?? false;
  }
}
