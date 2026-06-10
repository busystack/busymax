import 'package:flutter/services.dart';

class LinuxWindowService {
  const LinuxWindowService({
    MethodChannel channel = const MethodChannel('io.busystack.busymax/window'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<void> setHideOnClose(bool enabled) {
    return _channel.invokeMethod<void>('setHideOnClose', enabled);
  }

  Future<void> hideWindow() {
    return _channel.invokeMethod<void>('hideWindow');
  }

  Future<void> showWindow() {
    return _channel.invokeMethod<void>('showWindow');
  }

  Future<void> quitApp() {
    return _channel.invokeMethod<void>('quitApp');
  }

  Future<bool> isWindowVisible() async {
    return await _channel.invokeMethod<bool>('isWindowVisible') ?? false;
  }
}
