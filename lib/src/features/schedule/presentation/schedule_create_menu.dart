import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_shortcuts.dart';
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
  bool preferAbove = false,
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
    preferAbove: preferAbove,
    entries: [
      BusyMaxMenuEntry(
        value: ScheduleCreateChoice.event,
        label: context.l10n.createEventAtTime,
        icon: Icons.event_outlined,
        enabled: canCreateEvent,
        shortcut: BusyMaxShortcutLabels.newEvent,
      ),
      BusyMaxMenuEntry(
        value: ScheduleCreateChoice.task,
        label: context.l10n.createTaskAtDate,
        icon: Icons.task_alt_outlined,
        enabled: canCreateTask,
        shortcut: BusyMaxShortcutLabels.newTask,
      ),
    ],
  );
  return selection?.value;
}
