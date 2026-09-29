import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaru/yaru.dart';

import '../../../app/app_bootstrap.dart';
import '../../../app/busymax_design.dart';
import '../../../app/busymax_dialogs.dart';
import '../../../l10n/l10n.dart';
import '../../../microsoft_calendar/microsoft_event_attachment.dart';
import '../../../schedule/schedule_item.dart';
import 'attachment_download.dart';
import 'schedule_event_details_format.dart';

Future<void> showLinuxEventAttachmentsDialog(
  BuildContext context,
  CalendarScheduleItem item,
) => showBusyMaxModalDialog<void>(
  context,
  builder: (_) => _LinuxEventAttachmentsDialog(item: item),
);

class _LinuxEventAttachmentsDialog extends ConsumerStatefulWidget {
  const _LinuxEventAttachmentsDialog({required this.item});
  final CalendarScheduleItem item;
  @override
  ConsumerState<_LinuxEventAttachmentsDialog> createState() =>
      _LinuxEventAttachmentsDialogState();
}

class _LinuxEventAttachmentsDialogState
    extends ConsumerState<_LinuxEventAttachmentsDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final eventId = item.providerEventId;
    final result = eventId == null
        ? null
        : ref.watch(
            microsoftEventAttachmentsProvider((
              accountId: item.accountId,
              calendarId: item.providerCalendarId,
              eventId: eventId,
            )),
          );
    return BusyMaxDialogShell(
      title: context.l10n.attachments,
      maxWidth: 520,
      actions: [
        if (item.capabilities.canEdit && eventId != null)
          BusyMaxPushButton.standard(
            onPressed: _saving ? null : () => unawaited(_add()),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [const Icon(Icons.add), Text(context.l10n.attachments)],
            ),
          ),
        BusyMaxPushButton.suggested(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
      children: [
        if (result == null)
          Text(context.l10n.attachmentsNotLoaded)
        else
          result.when(
            loading: () => const Center(child: YaruCircularProgressIndicator()),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText('${context.l10n.attachmentsNotLoaded}\n$error'),
                BusyMaxPushButton.standard(
                  onPressed: _refresh,
                  child: Text(context.l10n.retry),
                ),
              ],
            ),
            data: (attachments) => attachments.isEmpty
                ? Text(context.l10n.noneValue)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final attachment in attachments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(attachment.name)),
                              if (attachment.size case final size?)
                                Text('$size B'),
                              if (attachment.canDownload)
                                BusyMaxPushButton.standard(
                                  onPressed: _saving
                                      ? null
                                      : () => unawaited(_save(attachment)),
                                  child: Text(context.l10n.save),
                                )
                              else if (attachment.kind ==
                                      MicrosoftEventAttachmentKind.reference &&
                                  attachment.sourceUrl != null)
                                BusyMaxPushButton.standard(
                                  onPressed: () =>
                                      unawaited(_open(attachment.sourceUrl!)),
                                  child: Text(context.l10n.openInProvider),
                                ),
                              if (item.capabilities.canEdit &&
                                  attachment.id.isNotEmpty)
                                BusyMaxPushButton.standard(
                                  onPressed: _saving
                                      ? null
                                      : () => unawaited(_remove(attachment)),
                                  child: Text(context.l10n.delete),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }

  void _refresh() {
    final eventId = widget.item.providerEventId;
    if (eventId == null) return;
    ref.invalidate(
      microsoftEventAttachmentsProvider((
        accountId: widget.item.accountId,
        calendarId: widget.item.providerCalendarId,
        eventId: eventId,
      )),
    );
  }

  Future<void> _add() async {
    final eventId = widget.item.providerEventId;
    if (eventId == null || !widget.item.capabilities.canEdit) return;
    final file = await openFile();
    if (file == null || !mounted) return;
    final name = safeAttachmentFileName(file.name);
    if (name == null) {
      _error(const FormatException('Invalid attachment name.'));
      return;
    }
    setState(() => _saving = true);
    try {
      final size = await file.length();
      if (size > 150 * 1024 * 1024) {
        throw StateError('Event file exceeds 150 MB.');
      }
      await ref
          .read(
            microsoftCalendarApiClientForAccountProvider(widget.item.accountId),
          )
          .uploadEventFileAttachment(
            calendarId: widget.item.providerCalendarId,
            eventId: eventId,
            name: name,
            contentType: file.mimeType ?? 'application/octet-stream',
            bytes: await file.readAsBytes(),
          );
      _refresh();
    } on Object catch (error) {
      _refresh();
      _error(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(MicrosoftEventAttachment attachment) async {
    final eventId = widget.item.providerEventId;
    if (eventId == null || !widget.item.capabilities.canEdit) return;
    final confirmed = await showBusyMaxConfirm(
      context,
      title: context.l10n.delete,
      message: attachment.name,
      confirmLabel: context.l10n.delete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(
            microsoftCalendarApiClientForAccountProvider(widget.item.accountId),
          )
          .deleteEventAttachment(
            calendarId: widget.item.providerCalendarId,
            eventId: eventId,
            attachmentId: attachment.id,
          );
      _refresh();
    } on Object catch (error) {
      _refresh();
      _error(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.exportFailed('$error'))),
    );
  }

  Future<void> _open(String url) async {
    if (await openScheduleWebLink(url) || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.eventLinkOpenFailed)));
  }

  Future<void> _save(MicrosoftEventAttachment attachment) async {
    final eventId = widget.item.providerEventId;
    if (eventId == null) return;
    setState(() => _saving = true);
    try {
      final bytes = await ref
          .read(
            microsoftCalendarApiClientForAccountProvider(widget.item.accountId),
          )
          .downloadEventAttachment(
            calendarId: widget.item.providerCalendarId,
            eventId: eventId,
            attachment: attachment,
          );
      await saveAttachmentOnDesktop(name: attachment.name, bytes: bytes);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
