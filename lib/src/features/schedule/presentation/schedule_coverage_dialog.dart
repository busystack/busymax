import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';

Future<void> showScheduleCoverage(
  BuildContext context,
  bool? complete,
  Future<void> Function() retry, {
  VoidCallback? openSettings,
}) async {
  final l10n = context.l10n;
  final requested = await showBusyMaxModalDialog<_CoverageAction>(
    context,
    builder: (dialogContext) => BusyMaxDialogShell(
      title: l10n.scheduleCoverageStatus,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.close),
        ),
        if (complete == false && openSettings != null)
          BusyMaxPushButton.standard(
            onPressed: () =>
                Navigator.pop(dialogContext, _CoverageAction.settings),
            child: Text(l10n.settings),
          ),
        if (complete != true)
          BusyMaxPushButton.standard(
            onPressed: () =>
                Navigator.pop(dialogContext, _CoverageAction.retry),
            child: Text(l10n.retry),
          ),
      ],
      children: [
        Text(switch (complete) {
          null => l10n.scheduleCoveragePending,
          false => l10n.scheduleRangeIncomplete,
          true => l10n.scheduleCoverageVerified,
        }),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (requested) {
    case _CoverageAction.settings:
      openSettings?.call();
    case _CoverageAction.retry:
      await retry();
    case null:
      break;
  }
}

enum _CoverageAction { settings, retry }
