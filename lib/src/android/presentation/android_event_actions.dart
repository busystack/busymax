import 'package:flutter/material.dart';

import '../../calendar_providers/calendar_mutation.dart';
import '../../features/calendar/domain/event_editor_draft.dart';
import '../../features/recurrence/domain/series_timing_change.dart';
import '../../features/recurrence/presentation/recurrence_summary.dart';
import '../../l10n/l10n.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/schedule_event_rescheduling.dart';
import '../../schedule/schedule_item.dart';
import 'android_date_picker.dart';

Future<CalendarGuestUpdatePolicy?> showAndroidGuestDeliveryDialog(
  BuildContext context, {
  required BusyProvider provider,
  bool deleting = false,
}) {
  final l10n = context.l10n;
  final message = switch (provider) {
    BusyProvider.caldav => l10n.caldavSchedulingWarning,
    BusyProvider.nextcloud => l10n.nextcloudSchedulingPending,
    BusyProvider.microsoft =>
      deleting
          ? l10n.microsoftNotifyGuestsDeleteMessage
          : l10n.microsoftNotifyGuestsSaveMessage,
    _ =>
      deleting ? l10n.notifyGuestsDeleteMessage : l10n.notifyGuestsSaveMessage,
  };
  return showDialog<CalendarGuestUpdatePolicy>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        provider == BusyProvider.microsoft
            ? deleting
                  ? l10n.microsoftNotifyGuestsDeleteTitle
                  : l10n.microsoftNotifyGuestsSaveTitle
            : l10n.notifyGuestsTitle,
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        if (provider == BusyProvider.google)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, CalendarGuestUpdatePolicy.doNotSend),
            child: Text(l10n.doNotSend),
          ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, CalendarGuestUpdatePolicy.send),
          child: Text(
            provider == BusyProvider.google
                ? deleting
                      ? l10n.sendCancellation
                      : l10n.sendUpdates
                : deleting
                ? provider == BusyProvider.nextcloud
                      ? l10n.sendCancellation
                      : l10n.delete
                : l10n.save,
          ),
        ),
      ],
    ),
  );
}

Future<RecurringEventMutationScope?> showAndroidRecurringScope(
  BuildContext context, {
  required bool supportsFollowing,
}) => showModalBottomSheet<RecurringEventMutationScope>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(context.l10n.chooseRecurringEventScope)),
          for (final scope in RecurringEventMutationScope.values)
            if (scope != RecurringEventMutationScope.thisAndFuture ||
                supportsFollowing)
              ListTile(
                title: Text(switch (scope) {
                  RecurringEventMutationScope.singleOccurrence =>
                    context.l10n.singleOccurrence,
                  RecurringEventMutationScope.thisAndFuture =>
                    context.l10n.thisAndFollowingEvents,
                  RecurringEventMutationScope.entireSeries =>
                    context.l10n.entireSeries,
                }),
                onTap: () => Navigator.pop(context, scope),
              ),
        ],
      ),
    ),
  ),
);

Future<bool> confirmAndroidSeriesTimingChange(
  BuildContext context,
  SeriesTimingChange change,
  RecurringEventMutationScope scope,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.repeat),
        content: Text(
          context.l10n.seriesPatternChangeConfirmation(
            recurrenceRuleSummary(
              context,
              change.previewRule(
                following: scope == RecurringEventMutationScope.thisAndFuture,
                original: true,
              ),
              timeZone: change.timeZone,
            ),
            recurrenceRuleSummary(
              context,
              change.previewRule(
                following: scope == RecurringEventMutationScope.thisAndFuture,
              ),
              timeZone: change.timeZone,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    ) ??
    false;

/// Deliberate touch actions preserve normal grid scrolling. Moving keeps the
/// duration; resizing changes exactly the selected endpoint.
Future<void> showAndroidEventTimingActions(
  BuildContext context,
  CalendarScheduleItem item,
  ValueChanged<ScheduleRescheduleRequest> onReschedule,
) async {
  if (!item.canReschedule) return;
  final action = await showModalBottomSheet<ScheduleTimingAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(item.title)),
          ListTile(
            leading: const Icon(Icons.open_with),
            title: Text(context.l10n.moveEvent),
            onTap: () => Navigator.pop(context, ScheduleTimingAction.move),
          ),
          ListTile(
            leading: const Icon(Icons.first_page),
            title: Text(context.l10n.startDate),
            onTap: () =>
                Navigator.pop(context, ScheduleTimingAction.resizeStart),
          ),
          ListTile(
            leading: const Icon(Icons.last_page),
            title: Text(context.l10n.endDate),
            onTap: () => Navigator.pop(context, ScheduleTimingAction.resizeEnd),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final initial = action == ScheduleTimingAction.resizeEnd
      ? item.end!
      : item.start!;
  final date = await showBusyMaxDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(9999, 12, 31),
  );
  if (date == null || !context.mounted) return;
  TimeOfDay? time;
  if (!item.allDay) {
    time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !context.mounted) return;
  }
  final pointer = DateTime(
    date.year,
    date.month,
    date.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
  );
  final interval = const ScheduleTimeMath().change(
    original: ScheduleInterval(item.start!, item.end!),
    action: action,
    anchor: initial,
    pointer: pointer,
    allDay: item.allDay,
  );
  onReschedule(
    ScheduleRescheduleRequest(item: item, interval: interval, action: action),
  );
}
