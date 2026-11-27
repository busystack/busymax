import 'package:busymax/src/ui/common/flutter_material.dart';

import '../../l10n/l10n.dart';

Future<void> showScheduleCoverage(
  BuildContext context,
  Future<void> Function() retry, {
  VoidCallback? openSettings,
}) async {
  final l10n = context.l10n;
  final requested = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.scheduleCoverageWarning),
      content: Text(l10n.scheduleRangeIncomplete),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.close),
        ),
        if (openSettings != null)
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openSettings();
            },
            child: Text(l10n.settings),
          ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.retry),
        ),
      ],
    ),
  );
  if (requested == true) await retry();
}
