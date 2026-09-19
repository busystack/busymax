import 'package:busymax_android_platform/busymax_android_platform.dart';

import '../platform/common/desktop_services.dart';

final class AndroidLocalTimeZoneSource implements LocalTimeZoneSource {
  const AndroidLocalTimeZoneSource(this._platform);

  final BusyMaxAndroidPlatform _platform;

  @override
  String? get diagnostic => null;

  @override
  Future<String> currentIanaTimeZone() => _platform.currentTimeZoneId();
}
