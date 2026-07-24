import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';

enum ScheduleCreateChoice { event, task }

ScheduleCreateChoice? singleAvailableScheduleCreateChoice({
  required bool canCreateEvent,
  required bool canCreateTask,
}) {
  if (canCreateEvent == canCreateTask) {
    return null;
  }
  return canCreateEvent
      ? ScheduleCreateChoice.event
      : ScheduleCreateChoice.task;
}

Future<ScheduleCreateChoice?> showScheduleCreateMenu({
  required BuildContext context,
  BuildContext? anchorContext,
  Offset? anchorPoint,
  bool canCreateEvent = true,
  bool canCreateTask = true,
  BusyMaxMenuSession? session,
}) async {
  if (!canCreateEvent && !canCreateTask) {
    return null;
  }

  final selection = await showBusyMaxMenu<ScheduleCreateChoice>(
    context: context,
    anchorContext: anchorContext ?? context,
    anchorPoint: anchorPoint,
    session: session,
    focusFirst: anchorPoint == null,
    entries: [
      BusyMaxMenuEntry(
        value: ScheduleCreateChoice.event,
        label: context.l10n.createEventAtTime,
        enabled: canCreateEvent,
      ),
      BusyMaxMenuEntry(
        value: ScheduleCreateChoice.task,
        label: context.l10n.createTaskAtDate,
        enabled: canCreateTask,
      ),
    ],
  );
  return selection?.value;
}
