import 'package:busymax_android_platform/busymax_android_platform.dart';

import '../../l10n/week_preferences_scope.dart';

final class AndroidFirstWeekdaySource
    extends BusyMaxSystemFirstWeekdaySourceBase {
  AndroidFirstWeekdaySource({BusyMaxAndroidPlatform? platform})
    : _platform = platform ?? BusyMaxAndroidPlatform.instance;

  final BusyMaxAndroidPlatform _platform;

  @override
  Future<int?> read() => _platform.getFirstWeekday();

  @override
  Stream<void> get changes => _platform.events
      .where((event) => event.type == 'systemSettingsChanged')
      .map((_) {});
}
