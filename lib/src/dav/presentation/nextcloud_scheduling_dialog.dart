import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yaru/yaru.dart';

import '../../app/app_bootstrap.dart';
import '../../app/busymax_design.dart';
import '../../app/busymax_dialogs.dart';
import '../../dav/dav_errors.dart';
import '../../dav/nextcloud/nextcloud_scheduling_controller.dart';
import '../../dav/nextcloud/nextcloud_scheduling_service.dart';
import '../../features/calendar/presentation/event_editor_draft.dart';
import '../../l10n/l10n.dart';
import '../../l10n/time_format_scope.dart';

Future<void> showLinuxNextcloudSchedulingDialog(
  BuildContext context, {
  required String accountId,
  required String collectionId,
  EventEditorDraft? draft,
}) => showBusyMaxModalDialog<void>(
  context,
  barrierDismissible: false,
  builder: (dialogContext) => LinuxNextcloudSchedulingDialog(
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
    final l10n = context.l10n;
    final confirmed = await showBusyMaxConfirm(
      context,
      title: l10n.nextcloudAcknowledge,
      message: l10n.nextcloudAcknowledgeConfirm,
      confirmLabel: l10n.nextcloudAcknowledge,
    );
    if (confirmed && mounted) await model.acknowledge(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    String dateTime(DateTime value) =>
        formatClockDateTime(context, value, date.format(value));
    final error = model.error;
    final title = widget.draft == null
        ? l10n.nextcloudSchedulingInbox
        : l10n.nextcloudGuestAvailability;
    return BusyMaxDialogShell(
      key: const ValueKey('nextcloud-scheduling-dialog'),
      title: title,
      maxWidth: 600,
      actions: [
        BusyMaxPushButton.standard(
          onPressed: model.busy ? null : model.load,
          child: Text(l10n.refresh),
        ),
        BusyMaxPushButton.suggested(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
      children: [
        if (widget.draft == null)
          Text(l10n.nextcloudInboxExplanation)
        else if (widget.draft!.start != null && widget.draft!.end != null)
          SelectableText(
            '${dateTime(widget.draft!.start!)} – ${dateTime(widget.draft!.end!)}'
            ' (${widget.draft!.startTimeZone ?? ref.read(localTimeZoneProvider)})',
          ),
        if (model.busy) const Center(child: YaruCircularProgressIndicator()),
        if (error != null)
          Text(
            error is DavException && error.kind == DavErrorKind.authorization
                ? l10n.nextcloudOperationDenied
                : l10n.nextcloudServerUnavailable,
          ),
        if (model.loaded &&
            !model.busy &&
            error == null &&
            widget.draft == null &&
            model.messages.isEmpty)
          Text(l10n.nextcloudInboxEmpty),
        if (model.messages.isNotEmpty)
          BusyMaxGroupedList(
            filled: true,
            children: [
              for (final message in model.messages) ...[
                YaruListTile.square(
                  leading: const Icon(Icons.inbox_outlined),
                  title: SelectableText(message.title),
                  subtitle: message.method == null
                      ? null
                      : Text(message.method!),
                ),
                BusyMaxActionRow(
                  title: l10n.nextcloudAcknowledge,
                  leading: const Icon(Icons.done_outlined),
                  enabled: !model.busy,
                  onTap: () => _acknowledge(message),
                ),
              ],
            ],
          ),
        if (model.availability.isNotEmpty)
          BusyMaxGroupedList(
            filled: true,
            children: [
              for (final result in model.availability)
                YaruListTile.square(
                  leading: Icon(
                    result.availability == NextcloudAvailability.unknown
                        ? YaruIcons.warning
                        : result.intervals.isEmpty
                        ? Icons.event_available_outlined
                        : Icons.event_busy_outlined,
                  ),
                  title: SelectableText(
                    result.recipient.replaceFirst(RegExp(r'^mailto:'), ''),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.availability == NextcloudAvailability.unknown
                            ? l10n.nextcloudAvailabilityUnknown
                            : result.intervals.isEmpty
                            ? l10n.nextcloudAvailabilityFree
                            : l10n.nextcloudAvailabilityBusy,
                      ),
                      for (final interval in result.intervals)
                        SelectableText(
                          '${dateTime(interval.startUtc.toLocal())} – ${dateTime(interval.endUtc.toLocal())}',
                        ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
