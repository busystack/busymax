import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/busymax_design.dart';
import '../../app/busymax_dialogs.dart';
import '../../l10n/l10n.dart';
import 'sync_feedback.dart';
import 'sync_request.dart';

Future<void> refreshFromLinux(
  BuildContext context,
  WidgetRef ref,
  SyncScope scope, {
  bool inspectFailure = true,
  VoidCallback? openRecovery,
}) => refreshWithFeedback(
  context,
  ref,
  scope,
  inspectFailure: inspectFailure,
  openRecovery: openRecovery,
  confirmRetry: _confirmDesktopRetry,
);

Future<bool?> _confirmDesktopRetry(
  BuildContext context,
  String title,
  String? message,
) => showBusyMaxModalDialog<bool>(
  context,
  builder: (dialogContext) => BusyMaxDialogShell(
    title: title,
    actions: [
      BusyMaxPushButton.standard(
        onPressed: () => Navigator.pop(dialogContext),
        child: Text(dialogContext.l10n.cancel),
      ),
      BusyMaxPushButton.suggested(
        onPressed: () => Navigator.pop(dialogContext, true),
        child: Text(dialogContext.l10n.retry),
      ),
    ],
    children: [if (message != null) Text(message)],
  ),
);
