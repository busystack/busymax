import 'dart:convert';
import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../l10n/time_format.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../app/app_settings.dart';
import '../../core/time/stored_temporal_projection.dart';
import '../../db/app_database.dart';
import '../../l10n/locale_resolution.dart';

/// Stable absolute timing stays accurate in delayed delivery and native history.
/// Native backends escape display text; diagnostic redaction is never applied.
Future<({String title, String? body})> reminderPresentation(
  AppDatabase database,
  NotificationScheduleData row,
  AppSettings settings,
) async {
  final locale =
      settings.locale ??
      resolveBusyMaxLocales(
        PlatformDispatcher.instance.locales,
        busyMaxSupportedLocales,
      );
  final l10n = lookupAppLocalizations(locale);
  final localeName = locale.toLanguageTag();
  await initializeDateFormatting(localeName);
  final account = await (database.select(
    database.accounts,
  )..where((table) => table.id.equals(row.accountId))).getSingleOrNull();
  final accountLabel = account?.displayName?.trim().isNotEmpty == true
      ? account!.displayName!.trim()
      : account?.email?.trim();
  String date(DateTime value, {bool dateOnly = false}) {
    final day = DateFormat.yMMMd(localeName).format(value);
    if (dateOnly) return day;
    final time =
        settings.timeFormatPreference == BusyMaxTimeFormatPreference.twelveHour
        ? DateFormat(
            BusyMaxTimeFormatter(
              locale: localeName,
              use24Hour: false,
            ).twelveHourPattern,
            localeName,
          )
        : settings.timeFormatPreference ==
              BusyMaxTimeFormatPreference.twentyFourHour
        ? DateFormat.Hm(localeName)
        : DateFormat.jm(localeName);
    final offset = value.timeZoneOffset;
    final minutes = offset.inMinutes.abs();
    final zone =
        'UTC${offset.isNegative ? '−' : '+'}'
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
    // A retained post must remain unambiguous after the device changes zone.
    return '$day · ${time.format(value)} ($zone)';
  }

  if (row.sourceType == 'event') {
    final event =
        await (database.select(database.calendarEvents)..where(
              (table) =>
                  table.accountId.equals(row.accountId) &
                  table.id.equals(row.sourceId),
            ))
            .getSingleOrNull();
    if (event == null) return (title: row.title, body: row.body);
    final source =
        await (database.select(database.calendarSources)
              ..where((table) => table.id.equals(event.calendarSourceId)))
            .getSingleOrNull();
    final start = calendarEventStartAsLocal(event);
    return (
      title: event.title.trim().isEmpty
          ? l10n.trayUntitledEvent
          : event.title.trim(),
      body: [
        if (start != null)
          '${event.allDay ? '${l10n.allDay} · ' : ''}${date(start, dateOnly: event.allDay)}',
        if (event.location?.trim().isNotEmpty ?? false) event.location!.trim(),
        if (source != null && source.summary.trim().isNotEmpty)
          [
            source.summary.trim(),
            if (accountLabel?.isNotEmpty ?? false) accountLabel!,
          ].join(' · '),
      ].join('\n'),
    );
  }
  final task =
      await (database.select(database.tasks)..where(
            (table) =>
                table.accountId.equals(row.accountId) &
                table.id.equals(row.sourceId),
          ))
          .getSingleOrNull();
  if (task == null) return (title: row.title, body: row.body);
  final list =
      await (database.select(database.taskLists)..where(
            (table) =>
                table.accountId.equals(row.accountId) &
                table.id.equals(task.taskListId),
          ))
          .getSingleOrNull();
  final due = taskDeadlineAsLocal(task);
  var dateOnly = task.microsoftDueDateTime == null;
  try {
    final metadata = jsonDecode(task.providerMetadataJson ?? '{}');
    if (metadata is Map && metadata['nativeDue'] is Map) {
      dateOnly = (metadata['nativeDue'] as Map)['kind'] == 'date';
    }
  } on FormatException {
    /* Optional provider metadata. */
  }
  return (
    title: task.title.trim().isEmpty
        ? l10n.taskReminderNotificationTitle
        : task.title.trim(),
    body: [
      if (due != null) '${l10n.dueDate}: ${date(due, dateOnly: dateOnly)}',
      if (list != null && list.title.trim().isNotEmpty)
        [
          list.title.trim(),
          if (accountLabel?.isNotEmpty ?? false) accountLabel!,
        ].join(' · '),
    ].join('\n'),
  );
}
