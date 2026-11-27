import 'package:busymax/src/ui/common/flutter_material.dart';

import '../../../dav/ical/ical_task_alarm.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/time_format_scope.dart';

String taskAlarmLabel(BuildContext context, IcalTaskAlarm alarm) {
  final absolute = alarm.absoluteUtc;
  if (absolute != null) {
    final local = absolute.toLocal();
    return context.l10n.dateTimeDisplay(
      MaterialLocalizations.of(context).formatMediumDate(local),
      BusyMaxTimeFormatScope.of(context).format(local),
    );
  }
  final offset = alarm.relativeOffset;
  if (offset != null) {
    final absoluteSeconds = offset.inSeconds.abs();
    if (absoluteSeconds == 0) {
      return alarm.isRelatedToDue
          ? context.l10n.reminderAtTaskDue
          : context.l10n.reminderAtTaskStart;
    }
    final amount = absoluteSeconds % (7 * Duration.secondsPerDay) == 0
        ? absoluteSeconds ~/ (7 * Duration.secondsPerDay)
        : absoluteSeconds % Duration.secondsPerDay == 0
        ? absoluteSeconds ~/ Duration.secondsPerDay
        : absoluteSeconds % Duration.secondsPerHour == 0
        ? absoluteSeconds ~/ Duration.secondsPerHour
        : absoluteSeconds % Duration.secondsPerMinute == 0
        ? absoluteSeconds ~/ Duration.secondsPerMinute
        : absoluteSeconds;
    final unit = absoluteSeconds % (7 * Duration.secondsPerDay) == 0
        ? context.l10n.reminderUnitWeeks
        : absoluteSeconds % Duration.secondsPerDay == 0
        ? context.l10n.reminderUnitDays
        : absoluteSeconds % Duration.secondsPerHour == 0
        ? context.l10n.reminderUnitHours
        : absoluteSeconds % Duration.secondsPerMinute == 0
        ? context.l10n.reminderUnitMinutes
        : context.l10n.reminderUnitSeconds;
    final relation = alarm.isRelatedToDue
        ? (offset.isNegative
              ? context.l10n.beforeTaskDue
              : context.l10n.afterTaskDue)
        : (offset.isNegative
              ? context.l10n.beforeTaskStarts
              : context.l10n.afterTaskStarts);
    return '$amount $unit · $relation';
  }
  return alarm.triggerRaw;
}
