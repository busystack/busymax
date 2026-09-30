import 'dart:typed_data';

import 'package:busymax_android_platform/busymax_android_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../features/schedule/presentation/attachment_download.dart';
import '../../features/schedule/presentation/attachment_upload_coordinator.dart';
import '../../features/schedule/presentation/google_event_attachment_reference.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../l10n/l10n.dart';
import '../../microsoft_calendar/microsoft_event_attachment.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/event_attachment_link.dart';
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
  late List<EventAttachmentLink> _referenceLinks;

  @override
  void initState() {
    super.initState();
    _referenceLinks = List.of(widget.item.attachmentLinks);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final eventId = item.providerEventId;
    final microsoft = item.provider == BusyProvider.microsoft;
    final google = item.provider == BusyProvider.google;
    final nextcloud = item.provider == BusyProvider.nextcloud;
    final uploads = ref.watch(attachmentUploadCoordinatorProvider);
    final uploadKey = eventId == null
        ? null
        : AttachmentUploadCoordinator.eventKey(
            item.accountId,
            item.providerCalendarId,
            eventId,
          );
    final result = !microsoft || eventId == null
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
        child: !microsoft
            ? _referenceLinks.isEmpty
                  ? Text(
                      item.attachmentsLoaded
                          ? context.l10n.noneValue
                          : context.l10n.attachmentsNotLoaded,
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final link in _referenceLinks)
                          ListTile(
                            title: Text(link.name),
                            trailing:
                                (google || nextcloud) &&
                                    item.capabilities.canEdit
                                ? IconButton(
                                    key: const Key(
                                      'event-attachment-remove-reference',
                                    ),
                                    tooltip: context.l10n.delete,
                                    onPressed: _saving
                                        ? null
                                        : () => _removeReference(link),
                                    icon: const Icon(Icons.delete_outline),
                                  )
                                : null,
                            onTap: () => _open(link.url),
                          ),
                      ],
                    )
            : result == null
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
        if (microsoft &&
            uploadKey != null &&
            uploads.needsReconciliation(uploadKey)) ...[
          Text(context.l10n.attachmentUploadUnresolved),
          TextButton(
            onPressed: _saving ? null : () => _reconcileUpload(eventId!),
            child: Text(context.l10n.refresh),
          ),
        ],
        if ((microsoft || google || nextcloud) &&
            item.capabilities.canEdit &&
            (nextcloud || eventId != null))
          TextButton.icon(
            key: const Key('event-attachment-add'),
            onPressed:
                _saving ||
                    (microsoft &&
                        uploadKey != null &&
                        !uploads.canSubmit(uploadKey))
                ? null
                : _add,
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
    if (!widget.item.capabilities.canEdit) return;
    if (widget.item.provider == BusyProvider.google ||
        widget.item.provider == BusyProvider.nextcloud) {
      var enteredUrl = '';
      final url = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.attachments),
          content: TextField(
            onChanged: (value) => enteredUrl = value,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: context.l10n.webLink),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, enteredUrl),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      );
      if (url == null || !mounted) return;
      await _changeReference(addFileUrl: url);
      return;
    }
    if (eventId == null) return;
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
          .read(attachmentUploadCoordinatorProvider)
          .uploadEvent(
            client: ref.read(
              microsoftCalendarApiClientForAccountProvider(
                widget.item.accountId,
              ),
            ),
            accountId: widget.item.accountId,
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

  Future<void> _reconcileUpload(String eventId) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(attachmentUploadCoordinatorProvider)
          .reconcileEvent(
            client: ref.read(
              microsoftCalendarApiClientForAccountProvider(
                widget.item.accountId,
              ),
            ),
            accountId: widget.item.accountId,
            calendarId: widget.item.providerCalendarId,
            eventId: eventId,
          );
      _refresh();
    } on Object catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeReference(EventAttachmentLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.delete),
        content: Text(link.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _changeReference(removeFileUrl: link.url);
  }

  Future<void> _changeReference({
    String? addFileUrl,
    String? removeFileUrl,
  }) async {
    setState(() => _saving = true);
    try {
      final List<EventAttachmentLink> links;
      var cacheUpdated = true;
      if (widget.item.provider == BusyProvider.google) {
        final changed = await changeGoogleEventAttachmentReference(
          item: widget.item,
          client: ref.read(
            googleCalendarApiClientForAccountProvider(widget.item.accountId),
          ),
          repository: ref.read(calendarRepositoryProvider),
          addFileUrl: addFileUrl,
          removeFileUrl: removeFileUrl,
        );
        links = changed.links;
        cacheUpdated = changed.cacheUpdated;
      } else {
        final detail = await ref
            .read(calendarRepositoryProvider)
            .changeNextcloudUriAttachmentReference(
              accountId: widget.item.accountId,
              eventId: widget.item.id,
              addUrl: addFileUrl,
              removeUrl: removeFileUrl,
            );
        links = eventAttachmentLinks(detail?.attachments);
        cacheUpdated = detail != null;
      }
      if (!mounted) return;
      setState(() => _referenceLinks = links);
      if (!cacheUpdated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.refreshFailed(context.l10n.attachments)),
          ),
        );
      }
    } on Object catch (error) {
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
