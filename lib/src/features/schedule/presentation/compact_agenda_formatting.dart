import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../../schedule/schedule_item.dart';
import '../../../schedule/schedule_projection.dart';

String compactAgendaDayLabel(
  BuildContext context, {
  required DateTime today,
  required DateTime day,
}) {
  final normalizedToday = ScheduleProjection.day(today);
  final normalizedDay = ScheduleProjection.day(day);
  if (normalizedDay == normalizedToday) {
    return context.l10n.today;
  }
  if (normalizedDay == normalizedToday.add(const Duration(days: 1))) {
    return context.l10n.tomorrow;
  }
  final locale = Localizations.localeOf(context).toString();
  return DateFormat('EEE, MMM d', locale).format(normalizedDay);
}

String compactAgendaTodaySubtitle(BuildContext context, DateTime today) {
  final locale = Localizations.localeOf(context).toString();
  return '${context.l10n.today} - ${DateFormat.MMMd(locale).format(today)}';
}

String compactAgendaItemMeta(
  BuildContext context,
  ScheduleItem item, {
  required DateTime today,
}) {
  if (item is TaskScheduleItem) {
    return _taskDueLabel(context, item, today: today);
  }
  return _eventTimeLabel(context, item);
}

String _eventTimeLabel(BuildContext context, ScheduleItem item) {
  if (item.allDay) {
    return context.l10n.compactAgendaAllDay;
  }
  final start = item.start;
  if (start == null) {
    return '';
  }
  final end = item.end;
  final startText = _formatTime(context, start);
  if (end == null ||
      !end.isAfter(start) ||
      ScheduleProjection.day(end) != ScheduleProjection.day(start)) {
    return startText;
  }
  return '$startText-${_formatTime(context, end)}';
}

String _taskDueLabel(
  BuildContext context,
  TaskScheduleItem item, {
  required DateTime today,
}) {
  final start = item.start;
  if (start == null) {
    return '';
  }
  final day = ScheduleProjection.day(start);
  final normalizedToday = ScheduleProjection.day(today);
  if (day == normalizedToday) {
    return item.allDay
        ? context.l10n.compactAgendaDueToday
        : context.l10n.compactAgendaDueOn(_formatTime(context, start));
  }
  if (day == normalizedToday.add(const Duration(days: 1))) {
    return context.l10n.compactAgendaDueTomorrow;
  }
  if (day == normalizedToday.subtract(const Duration(days: 1))) {
    return context.l10n.compactAgendaDueOn(
      DateFormat.E(Localizations.localeOf(context).toString()).format(day),
    );
  }
  return context.l10n.compactAgendaDueOn(
    DateFormat.MMMd(Localizations.localeOf(context).toString()).format(day),
  );
}

String _formatTime(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}
