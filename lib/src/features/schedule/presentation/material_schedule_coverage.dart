import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

Future<void> showScheduleCoverage(
  BuildContext context,
  bool? complete,
  Future<void> Function() retry, {
  VoidCallback? openSettings,
}) async {
  final l10n = context.l10n;
  final requested = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.scheduleCoverageStatus),
      content: Text(switch (complete) {
        null => l10n.scheduleCoveragePending,
        false => l10n.scheduleRangeIncomplete,
        true => l10n.scheduleCoverageVerified,
      }),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.close),
        ),
        if (complete == false && openSettings != null)
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openSettings();
            },
            child: Text(l10n.settings),
          ),
        if (complete != true)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.retry),
          ),
      ],
    ),
  );
  if (requested == true) await retry();
}
