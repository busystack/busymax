import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/linux_header_bar_service.dart';

enum ScheduleCreateChoice { event, task }

Future<ScheduleCreateChoice?> showScheduleCreateMenu({
  required BuildContext context,
  LinuxHeaderBarService? headerBarService,
}) {
  return showBusyMaxModalDialog<ScheduleCreateChoice>(
    context,
    headerBarService: headerBarService,
    builder: (dialogContext) {
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
                  dialogContext.l10n.createChoiceTitle,
                  style: Theme.of(dialogContext).textTheme.titleMedium,
                ),
                const SizedBox(height: BusyMaxSpacing.md),
                BusyMaxPushButton.outlined(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(ScheduleCreateChoice.event),
                  child: Text(dialogContext.l10n.createEventAtTime),
                ),
                const SizedBox(height: BusyMaxSpacing.sm),
                BusyMaxPushButton.outlined(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(ScheduleCreateChoice.task),
                  child: Text(dialogContext.l10n.createTaskAtDate),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
