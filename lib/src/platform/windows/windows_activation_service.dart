import 'dart:async';

import 'package:flutter/services.dart';

import '../common/desktop_services.dart';
import 'windows_window_service.dart';

Future<bool> forwardWindowsActivationToPrimary(
  DesktopActivation activation, {
  MethodChannel channel = const MethodChannel(windowsDesktopChannelName),
}) async {
  if (!activation.isValid) return false;
  try {
    return await channel.invokeMethod<bool>(
          'forwardActivation',
          activation.encode(),
        ) ??
        false;
  } on MissingPluginException {
    return false;
  }
}

final class WindowsActivationService implements DesktopActivationService {
  WindowsActivationService({
    MethodChannel channel = const MethodChannel(windowsDesktopChannelName),
  }) : _channel = channel {
    _controller = StreamController<DesktopActivation>.broadcast(
      onListen: _flushPending,
    );
  }

  final MethodChannel _channel;
  late final StreamController<DesktopActivation> _controller;
  final _pending = <DesktopActivation>[];
  bool _initialized = false;

  @override
  Stream<DesktopActivation> get activations => _controller.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'activation') {
        acceptEncoded(call.arguments);
      }
    });
    try {
      final initial =
          await _channel.invokeListMethod<String>('takeInitialActivations') ??
          const [];
      for (final encoded in initial) {
        acceptEncoded(encoded);
      }
      await _channel.invokeMethod<void>('activationReady');
    } on MissingPluginException {
      // Unpackaged tests may not load the native runner bridge.
    }
    _flushPending();
  }

  void acceptEncoded(Object? encoded) {
    if (encoded is! String) return;
    final activation = DesktopActivation.tryDecode(encoded);
    if (activation != null) accept(activation);
  }

  void accept(DesktopActivation activation) {
    if (!activation.isValid) return;
    if (!_initialized || !_controller.hasListener) {
      _pending.add(activation);
    } else {
      _controller.add(activation);
    }
  }

  void _flushPending() {
    if (!_initialized || !_controller.hasListener || _pending.isEmpty) return;
    for (final activation in _pending) {
      _controller.add(activation);
    }
    _pending.clear();
  }

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _controller.close();
  }
}
