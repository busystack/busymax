import 'package:busymax/src/app/app_settings.dart';
import 'package:busymax/src/schedule/schedule_view_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android view starts in agenda without changing the desktop default',
    () {
      final defaults = AppSettings.defaults();

      expect(defaults.androidScheduleViewMode, isNull);
      expect(defaults.scheduleViewMode, ScheduleViewMode.week);
    },
  );

  test('Android view mode round-trips independently', () {
    final restored = AppSettings.fromJson(
      AppSettings.defaults()
          .copyWith(androidScheduleViewMode: ScheduleViewMode.month)
          .toJson(),
    );

    expect(restored.androidScheduleViewMode, ScheduleViewMode.month);
    expect(restored.scheduleViewMode, ScheduleViewMode.week);
  });

  test('Android first-day preference is device-local and round-trips', () {
    for (final preference in BusyMaxFirstDayOfWeekPreference.values) {
      final restored = AppSettings.fromJson(
        AppSettings.defaults()
            .copyWith(firstDayOfWeekPreference: preference)
            .toJson(),
      );
      expect(restored.firstDayOfWeekPreference, preference);
    }
  });
}
