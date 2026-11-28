import 'package:busymax/src/ui/common/flutter_material.dart';
import 'package:yaru/yaru.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_shortcuts.dart';
import '../../../l10n/l10n.dart';

enum ScheduleCreateChoice { event, task, journal }

ScheduleCreateChoice? singleAvailableScheduleCreateChoice({
  required bool canCreateEvent,
  required bool canCreateTask,
  bool canCreateJournal = false,
}) => [
  if (canCreateEvent) ScheduleCreateChoice.event,
  if (canCreateTask) ScheduleCreateChoice.task,
  if (canCreateJournal) ScheduleCreateChoice.journal,
].singleOrNull;

Future<ScheduleCreateChoice?> showScheduleCreateMenu({
  required BuildContext context,
  BuildContext? anchorContext,
  Offset? anchorPoint,
  bool canCreateEvent = true,
  bool canCreateTask = true,
  bool canCreateJournal = false,
  BusyMaxMenuSession? session,
  bool preferAbove = false,
}) async {
  if (!canCreateEvent && !canCreateTask && !canCreateJournal) {
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
      if (canCreateJournal)
        BusyMaxMenuEntry(
          value: ScheduleCreateChoice.journal,
          label: context.l10n.newJournalEntry,
          icon: YaruIcons.book,
        ),
    ],
  );
  return selection?.value;
}
