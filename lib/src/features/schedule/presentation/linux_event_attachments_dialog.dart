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
import '../../../providers/busy_provider.dart';
import '../../../schedule/event_attachment_link.dart';
import '../../../schedule/schedule_item.dart';
import 'attachment_download.dart';
import 'google_event_attachment_reference.dart';
import 'schedule_event_details_format.dart';
import 'attachment_upload_coordinator.dart';

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
    return BusyMaxDialogShell(
      title: context.l10n.attachments,
      maxWidth: 520,
      actions: [
        if ((microsoft || google || nextcloud) &&
            item.capabilities.canEdit &&
            (nextcloud || eventId != null))
          BusyMaxPushButton.standard(
            key: const Key('event-attachment-add'),
            onPressed:
                _saving ||
                    (microsoft &&
                        uploadKey != null &&
                        !uploads.canSubmit(uploadKey))
                ? null
                : () => unawaited(_add()),
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
        if (microsoft &&
            uploadKey != null &&
            uploads.needsReconciliation(uploadKey)) ...[
          Text(
            uploads.confirmedId(uploadKey) == null
                ? context.l10n.attachmentUploadUnresolved
                : context.l10n.completed,
          ),
          BusyMaxPushButton.standard(
            onPressed: _saving
                ? null
                : () => unawaited(_reconcileUpload(eventId!)),
            child: Text(context.l10n.refresh),
          ),
          if (uploads.hasResumableSession(uploadKey))
            BusyMaxPushButton.standard(
              onPressed: _saving
                  ? null
                  : () => unawaited(_cancelUpload(eventId!)),
              child: Text(context.l10n.cancel),
            ),
          if (uploads.canResolveManually(uploadKey)) ...[
            BusyMaxPushButton.standard(
              onPressed: _saving
                  ? null
                  : () => unawaited(_resolveUpload(uploadKey, exists: true)),
              child: Text(context.l10n.completed),
            ),
            BusyMaxPushButton.standard(
              onPressed: _saving
                  ? null
                  : () => unawaited(_resolveUpload(uploadKey, exists: false)),
              child: Text(context.l10n.retry),
            ),
          ],
        ],
        if (!microsoft)
          if (_referenceLinks.isEmpty)
            Text(
              item.attachmentsLoaded
                  ? context.l10n.noneValue
                  : context.l10n.attachmentsNotLoaded,
            )
          else
            for (final link in _referenceLinks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(link.name),
                    Wrap(
                      spacing: 8,
                      children: [
                        BusyMaxPushButton.standard(
                          onPressed: () => unawaited(_open(link.url)),
                          child: Text(context.l10n.openInProvider),
                        ),
                        if ((google || nextcloud) && item.capabilities.canEdit)
                          BusyMaxPushButton.standard(
                            key: const Key('event-attachment-remove-reference'),
                            onPressed: _saving
                                ? null
                                : () => unawaited(_removeReference(link)),
                            child: Text(context.l10n.delete),
                          ),
                      ],
                    ),
                  ],
                ),
              )
        else if (result == null)
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
    if (!widget.item.capabilities.canEdit) return;
    if (widget.item.provider == BusyProvider.google ||
        widget.item.provider == BusyProvider.nextcloud) {
      final url = await showBusyMaxTextPrompt(
        context,
        title: context.l10n.attachments,
        label: context.l10n.webLink,
        actionLabel: context.l10n.save,
      );
      if (url == null || !mounted) return;
      await _changeReference(addFileUrl: url);
      return;
    }
    if (eventId == null) return;
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

  Future<void> _cancelUpload(String eventId) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(attachmentUploadCoordinatorProvider)
          .cancelEvent(
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

  Future<void> _resolveUpload(
    AttachmentUploadKey key, {
    required bool exists,
  }) async {
    final confirmed = await showBusyMaxConfirm(
      context,
      title: exists ? context.l10n.completed : context.l10n.retry,
      message: context.l10n.attachmentUploadUnresolved,
      confirmLabel: exists ? context.l10n.completed : context.l10n.retry,
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(attachmentUploadCoordinatorProvider)
        .resolveUncertainManually(key, exists: exists);
    _refresh();
  }

  Future<void> _removeReference(EventAttachmentLink link) async {
    final confirmed = await showBusyMaxConfirm(
      context,
      title: context.l10n.delete,
      message: link.name,
      confirmLabel: context.l10n.delete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
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
