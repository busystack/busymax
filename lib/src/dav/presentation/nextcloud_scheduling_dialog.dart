import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:busymax/l10n/generated/app_localizations.dart';
import 'package:busymax/src/app/app_bootstrap.dart';
import 'package:busymax/src/dav/dav_errors.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_controller.dart';
import 'package:busymax/src/dav/nextcloud/nextcloud_scheduling_service.dart';
import 'package:busymax/src/features/calendar/presentation/event_editor_draft.dart';

Future<void> showLinuxNextcloudSchedulingDialog(
  BuildContext context, {
  required String accountId,
  required String collectionId,
  EventEditorDraft? draft,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => LinuxNextcloudSchedulingDialog(
    accountId: accountId,
    collectionId: collectionId,
    draft: draft,
  ),
);

class LinuxNextcloudSchedulingDialog extends ConsumerStatefulWidget {
  const LinuxNextcloudSchedulingDialog({
    super.key,
    required this.accountId,
    required this.collectionId,
    this.draft,
  });
  final String accountId, collectionId;
  final EventEditorDraft? draft;
  @override
  ConsumerState<LinuxNextcloudSchedulingDialog> createState() =>
      _LinuxNextcloudSchedulingDialogState();
}

class _LinuxNextcloudSchedulingDialogState
    extends ConsumerState<LinuxNextcloudSchedulingDialog> {
  late final NextcloudSchedulingController model;
  @override
  void initState() {
    super.initState();
    model = NextcloudSchedulingController(
      ref.read(nextcloudSchedulingServiceProvider(widget.accountId)),
      widget.collectionId,
      draft: widget.draft,
      fallbackTimeZone: ref.read(localTimeZoneProvider),
    )..addListener(_changed);
    unawaited(model.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    model.dispose();
    super.dispose();
  }

  Future<void> _acknowledge(NextcloudInboxMessage message) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.nextcloudAcknowledge),
        content: Text(l10n.nextcloudAcknowledgeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.nextcloudAcknowledge),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await model.acknowledge(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm();
    final size = MediaQuery.sizeOf(context);
    final error = model.error;
    return AlertDialog(
      key: const ValueKey('nextcloud-scheduling-dialog'),

      title: Text(
        widget.draft == null
            ? l10n.nextcloudSchedulingInbox
            : l10n.nextcloudGuestAvailability,
      ),
      content: SizedBox(
        width: math.max(180, math.min(560, size.width - 96)),
        height: math.max(160, math.min(480, size.height - 220)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.draft == null)
                Text(l10n.nextcloudInboxExplanation)
              else if (widget.draft!.start != null && widget.draft!.end != null)
                SelectableText(
                  '${date.format(widget.draft!.start!)} – ${date.format(widget.draft!.end!)}'
                  ' (${widget.draft!.startTimeZone ?? ref.read(localTimeZoneProvider)})',
                ),
              const SizedBox(height: 12),
              if (model.busy) const CircularProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error is DavException &&
                            error.kind == DavErrorKind.authorization
                        ? l10n.nextcloudOperationDenied
                        : l10n.nextcloudServerUnavailable,
                  ),
                ),
              if (model.loaded &&
                  !model.busy &&
                  error == null &&
                  widget.draft == null &&
                  model.messages.isEmpty)
                Text(l10n.nextcloudInboxEmpty),
              for (final message in model.messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(message.title),
                      Text(message.method ?? ''),
                      TextButton(
                        onPressed: model.busy
                            ? null
                            : () => _acknowledge(message),
                        child: Text(l10n.nextcloudAcknowledge),
                      ),
                    ],
                  ),
                ),
              for (final result in model.availability)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        result.recipient.replaceFirst(RegExp(r'^mailto:'), ''),
                      ),
                      Text(
                        result.availability == NextcloudAvailability.unknown
                            ? l10n.nextcloudAvailabilityUnknown
                            : result.intervals.isEmpty
                            ? l10n.nextcloudAvailabilityFree
                            : l10n.nextcloudAvailabilityBusy,
                      ),
                      for (final interval in result.intervals)
                        SelectableText(
                          '${date.format(interval.startUtc.toLocal())} – ${date.format(interval.endUtc.toLocal())}',
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: model.busy ? null : model.load,
          child: Text(l10n.refresh),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
