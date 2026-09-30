import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../features/schedule/presentation/attachment_download.dart';
import '../../features/schedule/presentation/attachment_upload_coordinator.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../l10n/l10n.dart';
import '../../microsoft_calendar/microsoft_event_attachment.dart';
import '../../providers/busy_provider.dart';
import '../../schedule/event_attachment_link.dart';
import '../../schedule/schedule_item.dart';
import '../../features/schedule/presentation/google_event_attachment_reference.dart';

Future<void> showWindowsEventAttachmentsDialog(
  BuildContext context,
  CalendarScheduleItem item,
) => showDialog<void>(
  context: context,
  builder: (_) => _WindowsEventAttachmentsDialog(item: item),
);

class _WindowsEventAttachmentsDialog extends ConsumerStatefulWidget {
  const _WindowsEventAttachmentsDialog({required this.item});
  final CalendarScheduleItem item;

  @override
  ConsumerState<_WindowsEventAttachmentsDialog> createState() =>
      _WindowsEventAttachmentsDialogState();
}

class _WindowsEventAttachmentsDialogState
    extends ConsumerState<_WindowsEventAttachmentsDialog> {
  bool _saving = false;
  String? _error;
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
    return ContentDialog(
      title: Text(context.l10n.attachments),
      content: SizedBox(
        width: 480,
        height: 320,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error case final error?) Text(error),
              if (microsoft &&
                  uploadKey != null &&
                  uploads.needsReconciliation(uploadKey)) ...[
                Text(
                  uploads.confirmedId(uploadKey) == null
                      ? context.l10n.attachmentUploadUnresolved
                      : context.l10n.completed,
                ),
                Button(
                  onPressed: _saving
                      ? null
                      : () => unawaited(_reconcileUpload(eventId!)),
                  child: Text(context.l10n.refresh),
                ),
                if (uploads.hasResumableSession(uploadKey))
                  Button(
                    onPressed: _saving
                        ? null
                        : () => unawaited(_cancelUpload(eventId!)),
                    child: Text(context.l10n.cancel),
                  ),
                if (uploads.canResolveManually(uploadKey)) ...[
                  Button(
                    onPressed: _saving
                        ? null
                        : () => unawaited(
                            _resolveUpload(uploadKey, exists: true),
                          ),
                    child: Text(context.l10n.completed),
                  ),
                  Button(
                    onPressed: _saving
                        ? null
                        : () => unawaited(
                            _resolveUpload(uploadKey, exists: false),
                          ),
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
                              Button(
                                onPressed: () => unawaited(_open(link.url)),
                                child: Text(context.l10n.openInProvider),
                              ),
                              if ((google || nextcloud) &&
                                  item.capabilities.canEdit)
                                Button(
                                  key: const Key(
                                    'event-attachment-remove-reference',
                                  ),
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
                  loading: () => const ProgressRing(),
                  error: (error, _) => SelectableText(
                    '${context.l10n.attachmentsNotLoaded}\n$error',
                  ),
                  data: (attachments) => attachments.isEmpty
                      ? Text(context.l10n.noneValue)
                      : Column(
                          children: [
                            for (final attachment in attachments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(attachment.name),
                                          if (attachment.size case final size?)
                                            Text('$size B'),
                                        ],
                                      ),
                                    ),
                                    if (attachment.canDownload)
                                      Button(
                                        onPressed: _saving
                                            ? null
                                            : () =>
                                                  unawaited(_save(attachment)),
                                        child: Text(context.l10n.save),
                                      )
                                    else if (attachment.kind ==
                                            MicrosoftEventAttachmentKind
                                                .reference &&
                                        attachment.sourceUrl != null)
                                      Button(
                                        onPressed: () => unawaited(
                                          _open(attachment.sourceUrl!),
                                        ),
                                        child: Text(
                                          context.l10n.openInProvider,
                                        ),
                                      ),
                                    if (item.capabilities.canEdit &&
                                        attachment.id.isNotEmpty)
                                      Button(
                                        onPressed: _saving
                                            ? null
                                            : () => unawaited(
                                                _remove(attachment),
                                              ),
                                        child: Text(context.l10n.delete),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if ((microsoft || google || nextcloud) &&
            item.capabilities.canEdit &&
            (nextcloud || eventId != null))
          Button(
            key: const Key('event-attachment-add'),
            onPressed:
                _saving ||
                    (microsoft &&
                        uploadKey != null &&
                        !uploads.canSubmit(uploadKey))
                ? null
                : () => unawaited(_add()),
            child: Tooltip(
              message: context.l10n.attachments,
              child: const Icon(FluentIcons.add),
            ),
          ),
        Button(
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
        builder: (dialogContext) => ContentDialog(
          title: Text(context.l10n.attachments),
          content: InfoLabel(
            label: context.l10n.webLink,
            child: TextBox(
              onChanged: (value) => enteredUrl = value,
              autofocus: true,
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
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
    final file = await openFile();
    if (file == null || !mounted) return;
    final name = safeAttachmentFileName(file.name);
    if (name == null) {
      setState(() => _error = context.l10n.operationFailed);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (await file.length() > 150 * 1024 * 1024) {
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
      if (mounted) setState(() => _error = context.l10n.exportFailed('$error'));
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
      if (mounted) setState(() => _error = context.l10n.exportFailed('$error'));
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
      if (mounted) setState(() => _error = context.l10n.exportFailed('$error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resolveUpload(
    AttachmentUploadKey key, {
    required bool exists,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(exists ? context.l10n.completed : context.l10n.retry),
        content: Text(context.l10n.attachmentUploadUnresolved),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(exists ? context.l10n.completed : context.l10n.retry),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(attachmentUploadCoordinatorProvider)
        .resolveUncertainManually(key, exists: exists);
    _refresh();
  }

  Future<void> _removeReference(EventAttachmentLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(context.l10n.delete),
        content: Text(link.name),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
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
    setState(() {
      _saving = true;
      _error = null;
    });
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
      setState(() {
        _referenceLinks = links;
        if (!cacheUpdated) {
          _error = context.l10n.refreshFailed(context.l10n.attachments);
        }
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = context.l10n.exportFailed('$error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(MicrosoftEventAttachment attachment) async {
    final eventId = widget.item.providerEventId;
    if (eventId == null || !widget.item.capabilities.canEdit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(context.l10n.delete),
        content: Text(attachment.name),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
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
      ref
          .read(attachmentUploadCoordinatorProvider)
          .attachmentRemoved(
            AttachmentUploadCoordinator.eventKey(
              widget.item.accountId,
              widget.item.providerCalendarId,
              eventId,
            ),
            attachment.id,
          );
      _refresh();
    } on Object catch (error) {
      _refresh();
      if (mounted) setState(() => _error = context.l10n.exportFailed('$error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(String url) async {
    if (await openScheduleWebLink(url) || !mounted) return;
    setState(() => _error = context.l10n.eventLinkOpenFailed);
  }

  Future<void> _save(MicrosoftEventAttachment attachment) async {
    final eventId = widget.item.providerEventId;
    if (eventId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
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
      if (mounted) setState(() => _error = context.l10n.exportFailed('$error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
