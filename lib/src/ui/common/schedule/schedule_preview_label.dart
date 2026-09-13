import 'package:busymax/src/l10n/time_format_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../schedule/schedule_event_rescheduling.dart';

String schedulePreviewLabel(
  BuildContext context,
  ScheduleInterval interval,
  bool allDay,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = DateFormat.MMMd(locale);
  final time = BusyMaxTimeFormatScope.of(context);
  String endpoint(DateTime value) => allDay
      ? date.format(value)
      : time.compose(
          date.format(value.toLocal()),
          value.toLocal(),
          AppLocalizations.of(context).dateTimeDisplay,
        );
  return AppLocalizations.of(context).scheduleProposedRange(
    endpoint(interval.start),
    endpoint(allDay ? ScheduleTimeMath.date(interval.end, -1) : interval.end),
  );
}
