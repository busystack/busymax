import 'package:flutter/services.dart';

import '../l10n/week_preferences_scope.dart';

/// GNOME regional-format changes can require a new desktop session before
/// glibc exposes a different effective LC_TIME locale. Automatic mode follows
/// that effective session value; an explicit BusyMax preference is immediate.
final class LinuxFirstWeekdaySource
    extends BusyMaxSystemFirstWeekdaySourceBase {
  const LinuxFirstWeekdaySource({
    MethodChannel channel = const MethodChannel(
      'io.busystack.busymax/gtk_settings',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

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
}
