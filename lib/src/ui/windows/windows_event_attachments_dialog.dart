import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_bootstrap.dart';
import '../../features/schedule/presentation/attachment_download.dart';
import '../../features/schedule/presentation/schedule_event_details_format.dart';
import '../../l10n/l10n.dart';
import '../../microsoft_calendar/microsoft_event_attachment.dart';
import '../../schedule/schedule_item.dart';

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
              if (result == null)
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
        Button(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    );
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
