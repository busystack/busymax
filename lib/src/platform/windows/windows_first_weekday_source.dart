import 'dart:async';

import 'package:flutter/services.dart';

import '../../l10n/week_preferences_scope.dart';

final class WindowsFirstWeekdaySource
    implements BusyMaxSystemFirstWeekdaySource {
  WindowsFirstWeekdaySource({
    MethodChannel channel = const MethodChannel('busymax/windows_weekday'),
  }) : _channel = channel {
    _channel.setMethodCallHandler((call) async {
      if (!_disposed && call.method == 'weekdayChanged') {
        _changes.add(null);
      }
    });
  }

  final MethodChannel _channel;
  final _changes = StreamController<void>.broadcast(sync: true);
  var _disposed = false;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<int?> read() async {
    try {
      return await _channel.invokeMethod<int>('getFirstWeekday');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _channel.setMethodCallHandler(null);
    unawaited(_changes.close());
  }
}
