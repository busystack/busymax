import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';

class ScheduleEmptyState extends StatelessWidget {
  const ScheduleEmptyState({
    super.key,
    required this.onNewEvent,
    required this.onNewTask,
  });

  final VoidCallback onNewEvent;
  final VoidCallback onNewTask;

  @override
  Widget build(BuildContext context) {
    return BusyMaxEmptyState(
      icon: Icons.event_available,
      title: context.l10n.noEventsOrTasks,
      actions: [
        BusyMaxPushButton.outlined(
          onPressed: onNewEvent,
          child: Text(context.l10n.newEvent),
        ),
        BusyMaxPushButton.outlined(
          onPressed: onNewTask,
          child: Text(context.l10n.newTask),
        ),
      ],
    );
  }
}
