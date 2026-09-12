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
  final time = MediaQuery.alwaysUse24HourFormatOf(context)
      ? DateFormat.Hm(locale)
      : DateFormat.jm(locale);
  String endpoint(DateTime value) => allDay
      ? date.format(value)
      : '${date.format(value.toLocal())} ${time.format(value.toLocal())}';
  return AppLocalizations.of(context).scheduleProposedRange(
    endpoint(interval.start),
    endpoint(allDay ? ScheduleTimeMath.date(interval.end, -1) : interval.end),
  );
}
