import '../calendar_providers/calendar_mutation.dart';
import '../core/time/provider_date_time.dart';
import '../dav/ical/ical_semantics.dart';
import '../dav/ical/ical_timezone.dart';
import '../features/calendar/data/calendar_event_detail.dart';
import '../features/calendar/data/calendar_repository.dart';
import '../features/calendar/domain/event_timing_policy.dart';
import '../features/calendar/presentation/event_editor_draft.dart';
import 'schedule_item.dart';

enum ScheduleTimingAction { move, resizeStart, resizeEnd }

final class ScheduleInterval {
  const ScheduleInterval(this.start, this.end);
  final DateTime start;
  final DateTime end;
  Duration get duration => end.difference(start);
  bool sameAs(ScheduleInterval other) =>
      start.isAtSameMomentAs(other.start) && end.isAtSameMomentAs(other.end);
}

/// All civil arithmetic is performed independently of the host's DST rules.
/// Timed results are resolved instants; all-day results are exclusive dates.
final class ScheduleTimeMath {
  const ScheduleTimeMath({this.displayTimeZone});
  final String? displayTimeZone;
  static const gridMinutes = 15;

  static DateTime civil(DateTime value) => DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
  static DateTime date(DateTime value, [int days = 0]) =>
      DateTime(value.year, value.month, value.day + days);
  static int dayDifference(DateTime a, DateTime b) => DateTime.utc(
    a.year,
    a.month,
    a.day,
  ).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

  DateTime displayed(DateTime instant) =>
      providerInstantInTimeZone(instant, displayTimeZone);
  DateTime resolve(DateTime wall) =>
      displayed(providerWallTimeToInstant(wall, displayTimeZone));
  DateTime snap(DateTime wall) => resolve(
    DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      (wall.minute / gridMinutes).round() * gridMinutes,
    ),
  );

  ScheduleInterval change({
    required ScheduleInterval original,
    required ScheduleTimingAction action,
    required DateTime anchor,
    required DateTime pointer,
    bool dateOnly = false,
    bool allDay = false,
  }) {
    final delta = civil(pointer).difference(civil(anchor));
    if (delta == Duration.zero) return original;
    if (allDay) {
      final days = dayDifference(pointer, anchor);
      if (days == 0) return original;
      final start = action == ScheduleTimingAction.resizeEnd
          ? original.start
          : date(original.start, days);
      final end = action == ScheduleTimingAction.resizeStart
          ? original.end
          : date(original.end, days);
      if (!end.isAfter(start)) return original;
      return ScheduleInterval(start, end);
    }
    if (dateOnly) {
      final days = dayDifference(pointer, anchor);
      if (days == 0) return original;
      final wall = civil(displayed(original.start));
      final start = resolve(
        DateTime.utc(
          wall.year,
          wall.month,
          wall.day + days,
          wall.hour,
          wall.minute,
          wall.second,
          wall.millisecond,
          wall.microsecond,
        ),
      );
      return ScheduleInterval(start, start.add(original.duration));
    }
    if (action == ScheduleTimingAction.move) {
      final start = snap(civil(displayed(original.start)).add(delta));
      return ScheduleInterval(start, start.add(original.duration));
    }
    final boundary = action == ScheduleTimingAction.resizeStart
        ? original.start
        : original.end;
    final proposed = snap(civil(displayed(boundary)).add(delta));
    const minimum = Duration(minutes: gridMinutes);
    if (action == ScheduleTimingAction.resizeStart) {
      return ScheduleInterval(
        proposed.isAfter(original.end.subtract(minimum))
            ? original.end.subtract(minimum)
            : proposed,
        original.end,
      );
    }
    return ScheduleInterval(
      original.start,
      proposed.isBefore(original.start.add(minimum))
          ? original.start.add(minimum)
          : proposed,
    );
  }

  ScheduleInterval selection(DateTime anchor, DateTime pointer) {
    final a = snap(anchor);
    final b = snap(pointer);
    if (a == b) {
      return ScheduleInterval(a, a.add(const Duration(minutes: gridMinutes)));
    }
    return a.isBefore(b) ? ScheduleInterval(a, b) : ScheduleInterval(b, a);
  }
}

final class ScheduleRescheduleRequest {
  ScheduleRescheduleRequest({
    required this.item,
    required this.interval,
    this.action = ScheduleTimingAction.move,
  });
  final CalendarScheduleItem item;
  final ScheduleInterval interval;
  final ScheduleTimingAction action;
  bool _claimed = false;
  bool claim() {
    if (_claimed) return false;
    return _claimed = true;
  }
}

enum ScheduleRescheduleResult {
  cancelled,
  saved,
  savedWithNotificationFailure,
  savedWithSyncFailure,
}

typedef ScheduleScopeSelector =
    Future<RecurringEventMutationScope?> Function(
      CalendarEventDetail detail,
      bool supportsFollowing,
    );
typedef ScheduleGuestSelector =
    Future<CalendarGuestUpdatePolicy?> Function(EventEditorDraft draft);

/// The only bridge from pointer proposals to the existing mutation pipeline.
/// No store writes or provider requests occur until all decisions are complete.
final class ScheduleReschedulingCoordinator {
  const ScheduleReschedulingCoordinator({
    required this.repository,
    required this.chooseScope,
    required this.chooseGuestUpdates,
    required this.requestSync,
  });
  final CalendarRepository repository;
  final ScheduleScopeSelector chooseScope;
  final ScheduleGuestSelector chooseGuestUpdates;
  final Future<void> Function(String accountId) requestSync;

  Future<ScheduleRescheduleResult> commit(
    ScheduleRescheduleRequest request, {
    bool Function()? isActive,
  }) async {
    final item = request.item;
    bool active() => isActive?.call() ?? true;
    if (!request.claim() ||
        !item.canReschedule ||
        !active() ||
        request.interval.sameAs(ScheduleInterval(item.start!, item.end!))) {
      return ScheduleRescheduleResult.cancelled;
    }
    final duration = request.interval.duration;
    if (duration <= Duration.zero ||
        (!item.allDay &&
            request.action != ScheduleTimingAction.move &&
            duration < const Duration(minutes: ScheduleTimeMath.gridMinutes))) {
      throw ArgumentError('Invalid proposed event interval.');
    }
    var detail = await repository.loadEventDetail(item.id);
    if (detail == null || !detailAllowsTimingEdit(detail)) {
      throw const StaleEventTiming();
    }
    final baseline =
        item.timingBaseline ?? EventTimingBaseline.fromDetail(detail);
    if (!baseline.matches(detail) ||
        detail.sourceId != item.sourceId ||
        detail.accountId != item.accountId ||
        detail.allDay != item.allDay) {
      throw const StaleEventTiming();
    }
    if (item.timingBaseline == null) {
      final start = detail.allDay
          ? DateTime.tryParse(detail.startDate ?? '')
          : providerDateTimeAsLocal(detail.startDateTime, detail.startTimeZone);
      final end = detail.allDay
          ? DateTime.tryParse(detail.endDate ?? '')
          : providerDateTimeAsLocal(detail.endDateTime, detail.endTimeZone);
      if (start != item.start || end != item.end) {
        throw const StaleEventTiming();
      }
    }
    RecurringEventMutationScope? scope;
    if (detail.providerRecurringEventId != null) {
      scope = await chooseScope(detail, eventSupportsThisAndFollowing(detail));
      if (scope == null || !active()) return ScheduleRescheduleResult.cancelled;
    }
    detail = await repository.loadEventDetail(item.id);
    if (detail == null ||
        !baseline.matches(detail) ||
        !detailAllowsTimingEdit(detail)) {
      throw const StaleEventTiming();
    }
    var draft = EventEditorDraft.fromEventDetail(detail);
    var policy = CalendarGuestUpdatePolicy.send;
    if (draft.isOrganizer == true &&
        draft.attendees.any((guest) => !guest.self && !guest.organizer)) {
      final decision = await chooseGuestUpdates(draft);
      if (decision == null || !active()) {
        return ScheduleRescheduleResult.cancelled;
      }
      policy = decision;
    }
    // Dialogs may have been open while synchronization or another editor ran.
    detail = await repository.loadEventDetail(item.id);
    if (detail == null ||
        !baseline.matches(detail) ||
        !detailAllowsTimingEdit(detail)) {
      throw const StaleEventTiming();
    }
    draft = EventEditorDraft.fromEventDetail(detail);
    final document = await repository.loadEventTimeZoneDocument(detail);
    final resolver = document == null
        ? null
        : IcalTimeZoneResolver.fromDocument(
            IcalSemanticDocument.parse(document),
          );
    DateTime endpoint(DateTime value, String? zone) {
      if (detail!.allDay) return ScheduleTimeMath.date(value);
      if (resolver != null && zone != null && zone.isNotEmpty) {
        return resolver.fromUtc(value.toUtc(), zone);
      }
      return providerInstantInTimeZone(value.toUtc(), zone);
    }

    final changed = draft.copyWith(
      start: endpoint(request.interval.start, detail.startTimeZone),
      end: endpoint(request.interval.end, detail.endTimeZone),
      recurringMutationScope: scope,
    );
    if (!active()) return ScheduleRescheduleResult.cancelled;
    var result = ScheduleRescheduleResult.saved;
    try {
      await repository.updateLocalEvent(
        changed,
        guestUpdatePolicy: policy,
        timingBaseline: baseline,
      );
    } on EventNotificationRefreshFailure {
      result = ScheduleRescheduleResult.savedWithNotificationFailure;
    }
    try {
      await requestSync(item.accountId);
    } catch (_) {
      if (result == ScheduleRescheduleResult.saved) {
        result = ScheduleRescheduleResult.savedWithSyncFailure;
      }
    }
    return result;
  }
}
