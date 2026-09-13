import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Flutter's Windows settings watchers do not watch the clock preference.
/// The runner refreshes on intl settings messages and window activation.
class WindowsClockPreference extends ValueNotifier<bool?>
    with WidgetsBindingObserver {
  WindowsClockPreference({
    MethodChannel channel = const MethodChannel('busymax/windows_clock'),
  }) : _channel = channel,
       super(null) {
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (!_disposed &&
          call.method == 'clockChanged' &&
          call.arguments is bool) {
        _refreshSequence++;
        value = call.arguments as bool;
      }
    });
    unawaited(refresh());
  }

  final MethodChannel _channel;
  bool _disposed = false;
  int _refreshSequence = 0;

  Future<void> refresh() async {
    final sequence = ++_refreshSequence;
    try {
      final clock = await _channel.invokeMethod<bool>('getUses24HourClock');
      if (!_disposed && sequence == _refreshSequence && clock != null) {
        value = clock;
      }
    } on MissingPluginException {
      // Widget tests and hosts without the Windows runner use platform settings.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
