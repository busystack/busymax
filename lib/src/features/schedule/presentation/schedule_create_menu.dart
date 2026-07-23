import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_surface_colors.dart';
import '../../../l10n/l10n.dart';
import 'schedule_anchored_popover.dart';

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
}) {
  if (!canCreateEvent && !canCreateTask) {
    return Future<ScheduleCreateChoice?>.value();
  }

  return showScheduleAnchoredPopover<ScheduleCreateChoice>(
    context: context,
    anchorContext: anchorContext ?? context,
    anchorPoint: anchorPoint,
    semanticLabel: context.l10n.createChoiceTitle,
    preferredWidth: 220,
    minimumWidth: 180,
    preferredMinimumHeight: 120,
    builder: (context, arrowSide, arrowAlignment) {
      return BusyMaxPopoverSurface(
        color: BusyMaxSurfaceColors.of(context).popover,
        arrowSide: arrowSide,
        arrowAlignment: arrowAlignment,
        padding: const EdgeInsets.symmetric(vertical: BusyMaxSpacing.xs),
        child: _ScheduleCreateMenuItems(
          canCreateEvent: canCreateEvent,
          canCreateTask: canCreateTask,
          autofocusFirstItem: anchorPoint == null,
        ),
      );
    },
  );
}

class _ScheduleCreateMenuItems extends StatelessWidget {
  const _ScheduleCreateMenuItems({
    required this.canCreateEvent,
    required this.canCreateTask,
    required this.autofocusFirstItem,
  });

  final bool canCreateEvent;
  final bool canCreateTask;
  final bool autofocusFirstItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScheduleCreateMenuItem(
          choice: ScheduleCreateChoice.event,
          label: context.l10n.createEventAtTime,
          enabled: canCreateEvent,
          autofocus: autofocusFirstItem && canCreateEvent,
        ),
        _ScheduleCreateMenuItem(
          choice: ScheduleCreateChoice.task,
          label: context.l10n.createTaskAtDate,
          enabled: canCreateTask,
          autofocus: autofocusFirstItem && !canCreateEvent && canCreateTask,
        ),
      ],
    );
  }
}

class _ScheduleCreateMenuItem extends StatelessWidget {
  const _ScheduleCreateMenuItem({
    required this.choice,
    required this.label,
    required this.enabled,
    required this.autofocus,
  });

  final ScheduleCreateChoice choice;
  final String label;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      autofocus: autofocus,
      leadingIcon: const SizedBox.square(dimension: BusyMaxSizes.iconSm),
      onPressed: enabled ? () => Navigator.of(context).pop(choice) : null,
      style: busyMaxDropdownMenuItemStyle(context),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
