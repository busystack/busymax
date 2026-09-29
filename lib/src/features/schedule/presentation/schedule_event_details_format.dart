import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../calendar_providers/calendar_description.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/time_format_scope.dart';
import '../../../schedule/schedule_item.dart';

String scheduleEventIntervalLabel(
  BuildContext context,
  CalendarScheduleItem event,
) {
  final start = event.start;
  if (start == null) return context.l10n.noDate;
  final locale = Localizations.localeOf(context).toLanguageTag();
  String date(DateTime value) => DateFormat.yMMMd(locale).format(value);
  final end = event.end;
  if (event.allDay) {
    // iCalendar DTEND is exclusive. Subtract a civil day, not 24 hours, so
    // daylight-saving transitions cannot add or remove a displayed date.
    final last = end == null
        ? start
        : DateTime(end.year, end.month, end.day - 1);
    final range = last.isAfter(start)
        ? '${date(start)} – ${date(last)}'
        : date(start);
    return '$range · ${context.l10n.allDay}';
  }
  final first = formatClockDateTime(context, start, date(start));
  final last = end == null
      ? null
      : formatClockDateTime(context, end, date(end));
  // Schedule projections are already in device-local time. The provider's
  // original TZID may differ and must not label these displayed wall values.
  final startZone = _displayTimeZone(start);
  if (end == null || last == null) return '$first · $startZone';
  final endZone = _displayTimeZone(end);
  if (startZone == endZone) return '$first – $last · $startZone';
  return '$first $startZone – $last $endZone';
}

String _displayTimeZone(DateTime value) {
  final offset = value.timeZoneOffset;
  final name = value.timeZoneName.trim();
  if (offset == Duration.zero) return 'UTC';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  final utcOffset = 'UTC${offset.isNegative ? '-' : '+'}$hours:$minutes';
  return name.isEmpty || name == 'UTC' ? utcOffset : '$name ($utcOffset)';
}

String calendarEventDescription(CalendarScheduleItem event) {
  final html = event.descriptionHtml;
  if (html != null && isHtmlContentType(event.descriptionContentType)) {
    return htmlCalendarDescriptionToPlainText(html);
  }
  return event.description ?? '';
}

List<Uri> calendarEventDescriptionLinks(CalendarScheduleItem event) {
  final found = <String>{};
  final text = calendarEventDescription(event);
  for (final match in RegExp(
    r'''https?://[^\s<>"']+''',
    caseSensitive: false,
  ).allMatches(text)) {
    found.add(match.group(0)!.replaceFirst(RegExp(r'[.,;:!?]+$'), ''));
  }
  final html = event.descriptionHtml;
  if (html != null && isHtmlContentType(event.descriptionContentType)) {
    for (final match in RegExp(
      r'''<a\b[^>]*\bhref\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      found.add(decodeHtmlEntities(match.group(1)!));
    }
  }
  return [
    for (final value in found)
      if (safeScheduleWebUri(value) case final uri?) uri,
  ];
}

Uri? safeScheduleWebUri(String? value) {
  final uri = value == null ? null : Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

Future<bool> openScheduleWebLink(String? value) async {
  final uri = safeScheduleWebUri(value);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

String scheduleEventPersonName(Map<String, Object?>? person) {
  if (person == null) return '';
  final emailAddress = person['emailAddress'];
  final nested = emailAddress is Map ? emailAddress : const {};
  for (final value in [
    person['displayName'],
    nested['name'],
    person['email'],
    nested['address'],
    person['value'],
  ]) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return '';
}

String scheduleEventResponseLabel(BuildContext context, String? response) {
  return switch (response?.toLowerCase()) {
    'accepted' => context.l10n.responseAccepted,
    'tentative' || 'tentativelyaccepted' => context.l10n.responseTentative,
    'declined' => context.l10n.responseDeclined,
    'needsaction' => context.l10n.responseNeedsAction,
    'organizer' => context.l10n.responseOrganizer,
    'none' || 'notresponded' || null => context.l10n.responseNotResponded,
    final value => value,
  };
}

String scheduleEventAttendeeLabel(
  BuildContext context,
  Map<String, Object?> attendee,
) {
  final statusObject = attendee['status'];
  final status =
      attendee['responseStatus']?.toString() ??
      (statusObject is Map ? statusObject['response']?.toString() : null);
  final optional =
      attendee['optional'] == true ||
      attendee['type']?.toString().toLowerCase() == 'optional';
  final name = scheduleEventPersonName(attendee);
  return '$name — ${scheduleEventResponseLabel(context, status)}'
      '${optional ? ' · ${context.l10n.attendeeOptional}' : ''}';
}
