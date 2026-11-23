import 'dart:async';

import '../../../calendar_providers/calendar_mutation.dart';

import 'package:logging/logging.dart';

import '../../recurrence/domain/series_timing_change.dart';
import '../data/calendar_repository.dart';
import '../domain/event_editor_draft.dart';
import '../domain/event_timing_policy.dart';

final _logger = Logger('EventSave');

enum EventSaveOutcome { committed, followUpPending }

/// The repository queues the mutation before refreshing reminders. Only errors
/// from the mutation itself should let the editor retry the write.
Future<EventSaveOutcome> saveEventDraft({
  required CalendarRepository repository,
  required EventEditorDraft draft,
  required CalendarGuestUpdatePolicy guestPolicy,
  required Future<void> Function() rememberDestination,
  required void Function() requestSync,
  Future<void> Function()? clearRecovery,
  String? creationId,
}) async {
  var outcome = EventSaveOutcome.committed;

  void followUpFailed(Object error) {
    outcome = EventSaveOutcome.followUpPending;
    _logger.warning('Committed event follow-up failed (${error.runtimeType}).');
  }

  try {
    if (draft.eventId == null) {
      await repository.createLocalEvent(
        draft,
        guestUpdatePolicy: guestPolicy,
        creationId: creationId,
      );
    } else {
      await repository.updateLocalEvent(draft, guestUpdatePolicy: guestPolicy);
    }
  } on EventNotificationRefreshFailure catch (error) {
    followUpFailed(error.cause);
  }

  try {
    await clearRecovery?.call();
  } on Object catch (error) {
    followUpFailed(error);
  }
  try {
    requestSync();
  } on Object catch (error) {
    followUpFailed(error);
  }
  if (draft.eventId == null) {
    // Remembering a default is independent of saving the event.
    unawaited(
      Future<void>.sync(rememberDestination).catchError((Object error) {
        _logger.warning(
          'Could not remember the event destination (${error.runtimeType}).',
        );
      }),
    );
  }
  return outcome;
}

/// The repository recalculates the proposal when saving so the approval applies
/// only to the exact recurrence change that was shown.
Future<EventEditorDraft?> approveEventSeriesTiming({
  required CalendarRepository Function() repository,
  required EventEditorDraft draft,
  required bool Function() isActive,
  required Future<bool> Function(SeriesTimingChange change, bool following)
  confirm,
}) async {
  final scope = draft.recurringMutationScope;
  if (draft.eventId == null ||
      (scope != RecurringEventMutationScope.entireSeries &&
          scope != RecurringEventMutationScope.thisAndFuture)) {
    return isActive() ? draft : null;
  }
  final change = await repository().prepareSeriesTimingChange(draft);
  if (!isActive()) return null;
  if (change == null || !change.requiresConfirmation) return draft;
  final approved = await confirm(
    change,
    scope == RecurringEventMutationScope.thisAndFuture,
  );
  return approved && isActive()
      ? draft.copyWith(seriesTimingApproval: change.signature)
      : null;
}
