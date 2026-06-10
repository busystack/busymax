import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../l10n/l10n.dart';

enum ScheduleCreateChoice { event, task }

Future<ScheduleCreateChoice?> showScheduleCreateMenu({
  required BuildContext context,
}) {
  return showDialog<ScheduleCreateChoice>(
    context: context,
    builder: (context) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(BusyMaxSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.createChoiceTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: BusyMaxSpacing.md),
                BusyMaxPushButton.outlined(
                  onPressed: () =>
                      Navigator.of(context).pop(ScheduleCreateChoice.event),
                  child: Text(context.l10n.createEventAtTime),
                ),
                const SizedBox(height: BusyMaxSpacing.sm),
                BusyMaxPushButton.outlined(
                  onPressed: () =>
                      Navigator.of(context).pop(ScheduleCreateChoice.task),
                  child: Text(context.l10n.createTaskAtDate),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
