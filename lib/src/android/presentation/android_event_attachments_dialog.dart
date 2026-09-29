import 'dart:typed_data';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../features/schedule/presentation/attachment_download.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../l10n/l10n.dart';
import '../../microsoft_calendar/microsoft_event_attachment.dart';
import '../../schedule/schedule_item.dart';

Future<void> showAndroidEventAttachmentsDialog(
  BuildContext context,
  CalendarScheduleItem item,
) => showDialog<void>(
  context: context,
  builder: (_) => _AndroidEventAttachmentsDialog(item: item),
);

class _AndroidEventAttachmentsDialog extends ConsumerStatefulWidget {
  const _AndroidEventAttachmentsDialog({required this.item});
  final CalendarScheduleItem item;

  @override
  ConsumerState<_AndroidEventAttachmentsDialog> createState() =>
      _AndroidEventAttachmentsDialogState();
}

class _AndroidEventAttachmentsDialogState
    extends ConsumerState<_AndroidEventAttachmentsDialog> {
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
    return AlertDialog(
      title: Text(context.l10n.attachments),
      content: SizedBox(
        width: 420,
        child: result == null
            ? Text(context.l10n.attachmentsNotLoaded)
            : result.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => SelectableText(
                  '${context.l10n.attachmentsNotLoaded}\n$error',
                ),
                data: (attachments) => attachments.isEmpty
                    ? Text(context.l10n.noneValue)
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final attachment in attachments)
                            ListTile(
                              title: Text(attachment.name),
                              subtitle: attachment.size == null
                                  ? null
                                  : Text('${attachment.size} B'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (attachment.canDownload)
                                    IconButton(
                                      tooltip: context.l10n.save,
                                      onPressed: _saving
                                          ? null
                                          : () => _save(attachment),
                                      icon: const Icon(Icons.download_outlined),
                                    ),
                                  if (item.capabilities.canEdit &&
                                      attachment.id.isNotEmpty)
                                    IconButton(
                                      tooltip: context.l10n.delete,
                                      onPressed: _saving
                                          ? null
                                          : () => _remove(attachment),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                ],
                              ),
                              onTap:
                                  attachment.kind ==
                                          MicrosoftEventAttachmentKind
                                              .reference &&
                                      attachment.sourceUrl != null
                                  ? () => _open(attachment.sourceUrl!)
                                  : null,
                            ),
                        ],
                      ),
              ),
      ),
      actions: [
        if (item.capabilities.canEdit && eventId != null)
          TextButton.icon(
            onPressed: _saving ? null : _add,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.attachments),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(context.l10n.close),
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
    final document = await BusyMaxAndroidPlatform.instance.openDocument(
      mimeTypes: const ['*/*'],
      maximumBytes: 150 * 1024 * 1024,
    );
    if (document == null || !mounted) return;
    final name = safeAttachmentFileName(document.name ?? '');
    if (name == null) {
      _error(const FormatException('Invalid attachment name.'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(
            microsoftCalendarApiClientForAccountProvider(widget.item.accountId),
          )
          .uploadEventFileAttachment(
            calendarId: widget.item.providerCalendarId,
            eventId: eventId,
            name: name,
            contentType: document.mimeType ?? 'application/octet-stream',
            bytes: document.bytes,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.delete),
        content: Text(attachment.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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

  Future<void> _open(String url) async {
    if (await openScheduleWebLink(url) || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.eventLinkOpenFailed)));
  }

  Future<void> _save(MicrosoftEventAttachment attachment) async {
    final name = safeAttachmentFileName(attachment.name);
    if (name == null) {
      _error(const FormatException('Invalid attachment name.'));
      return;
    }
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
      await BusyMaxAndroidPlatform.instance.createDocument(
        suggestedName: name,
        mimeType: attachment.contentType ?? 'application/octet-stream',
        bytes: Uint8List.fromList(bytes),
      );
    } on Object catch (error) {
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
}
