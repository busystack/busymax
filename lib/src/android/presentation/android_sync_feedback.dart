import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sync/sync_feedback.dart';
import '../../features/sync/sync_request.dart';
import '../../l10n/l10n.dart';

Future<void> refreshFromAndroid(
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
  confirmRetry: (context, title, message) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(dialogContext.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(dialogContext.l10n.retry),
        ),
      ],
    ),
  ),
);
