import 'dart:convert';

import '../../../providers/busy_provider.dart';
import '../data/calendar_event_detail.dart';
import '../presentation/event_editor_draft.dart';

/// Timing edits are narrower than personal edits (for example reminders).
bool canEditEventTiming({
  required BusyProvider provider,
  required bool canEdit,
  bool? isOrganizer,
  bool locked = false,
  bool? guestsCanModify,
  bool isFederated = false,
}) =>
    canEdit &&
    provider != BusyProvider.webCal &&
    (provider != BusyProvider.microsoft || isOrganizer != false) &&
    (provider != BusyProvider.nextcloud ||
        isFederated ||
        isOrganizer != false) &&
    (provider != BusyProvider.google ||
        (!locked && (isOrganizer == true || guestsCanModify == true)));

bool detailAllowsTimingEdit(CalendarEventDetail detail) {
  final organizer = detail.organizer;
  final raw = detail.raw;
  if (detail.provider == BusyProvider.nextcloud &&
      detail.attendees is List &&
      (detail.attendees as List).isNotEmpty &&
      raw is Map &&
      raw['canManageAttendees'] != true &&
      raw['federated'] != true) {
    return false;
  }
  return !detail.isDeleted &&
      !detail.isCancelled &&
      canEditEventTiming(
        provider: detail.provider,
        canEdit: true,
        isOrganizer: switch (detail.provider) {
          BusyProvider.google => organizer is Map && organizer['self'] == true,
          BusyProvider.microsoft || BusyProvider.nextcloud =>
            raw is Map ? raw['isOrganizer'] as bool? : null,
          _ => null,
        },
        locked: detail.locked,
        guestsCanModify: detail.guestsCanModify,
        isFederated: raw is Map && raw['federated'] == true,
      );
}

bool googleEventCanSplit({
  required String? eventType,
  required Object? conference,
}) {
  if (eventType != null && eventType.isNotEmpty && eventType != 'default') {
    return false;
  }
  if (conference == null) return true;
  if (conference is! Map || conference.isEmpty) return conference is Map;
  final solution = conference['conferenceSolution'];
  final key = solution is Map ? solution['key'] : null;
  return key is Map && key['type'] == 'hangoutsMeet';
}

bool eventSupportsThisAndFollowing(CalendarEventDetail detail) {
  if (!supportsThisAndFollowingEventMutation(detail.provider)) return false;
  if (detail.provider == BusyProvider.google) {
    return googleEventCanSplit(
      eventType: detail.eventType,
      conference: detail.conference,
    );
  }
  return detail.davObjectId != null && detail.occurrenceKey != null;
}

/// A timing/occurrence compare-and-set token, deliberately excluding unrelated
/// fields and server etags so concurrent title/reminder edits can be retained.
final class EventTimingBaseline {
  EventTimingBaseline.fromDetail(CalendarEventDetail detail)
    : _value = jsonEncode([
        detail.id,
        detail.accountId,
        detail.sourceId,
        detail.providerCalendarId,
        detail.providerEventId,
        detail.providerRecurringEventId,
        detail.providerOriginalStartKey,
        detail.icalUid,
        detail.recurrenceIdKey,
        detail.occurrenceKey,
        detail.allDay,
        detail.startDate,
        detail.startDateTime,
        detail.startTimeZone,
        detail.endDate,
        detail.endDateTime,
        detail.endTimeZone,
        detail.recurrence,
      ]);

  final String _value;

  bool matches(CalendarEventDetail detail) =>
      !detail.isDeleted &&
      !detail.isCancelled &&
      _value == EventTimingBaseline.fromDetail(detail)._value;
}

final class StaleEventTiming implements Exception {
  const StaleEventTiming();
  @override
  String toString() => 'The event changed while it was being rescheduled.';
}

/// The event transaction succeeded. Retrying the mutation would duplicate it.
final class EventNotificationRefreshFailure implements Exception {
  const EventNotificationRefreshFailure(this.cause);
  final Object cause;
}
