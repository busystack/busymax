import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dav/ical/ical_attachments.dart';
import '../../../l10n/l10n.dart';
import '../../../schedule/event_attachment_link.dart';
import '../../schedule/presentation/schedule_event_details_format.dart';
import '../dav_attachment_providers.dart';
import 'dav_attachment_file_name.dart';

typedef DavAttachmentButtonBuilder = Widget Function(
  String label,
  VoidCallback? onPressed,
);

/// Read-only consumption of cached DAV data. A native view supplies its normal
/// explicit-save interface; no authenticated transport or mutation is involved.
class CalDavAttachmentsSection extends ConsumerStatefulWidget {
  const CalDavAttachmentsSection.event({
    super.key,
    required String eventId,
    required this.saveInline,
    this.showHeading = true,
    this.buttonBuilder,
  }) : eventId = eventId,
       task = null;

  const CalDavAttachmentsSection.task({
    super.key,
    required DavTaskAttachmentTarget target,
    required this.saveInline,
    this.buttonBuilder,
  }) : eventId = null,
       task = target,
       showHeading = true;

  final String? eventId;
  final DavTaskAttachmentTarget? task;
  final bool showHeading;
  final Future<String?> Function(IcalAttachment) saveInline;
  final DavAttachmentButtonBuilder? buttonBuilder;

  @override
  ConsumerState<CalDavAttachmentsSection> createState() =>
      _CalDavAttachmentsSectionState();
}

class _CalDavAttachmentsSectionState
    extends ConsumerState<CalDavAttachmentsSection> {
  bool _saving = false;
  bool _failed = false;

  Widget _button(String label, VoidCallback? pressed, {Key? key}) =>
      KeyedSubtree(
        key: key,
        child:
            widget.buttonBuilder?.call(label, pressed) ??
            TextButton(onPressed: pressed, child: Text(label)),
      );

  @override
  Widget build(BuildContext context) {
    final result = widget.task == null
        ? ref.watch(davEventAttachmentsProvider(widget.eventId!))
        : ref.watch(davTaskAttachmentsProvider(widget.task!));
    return result.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Text(context.l10n.attachmentsNotLoaded),
      data: (attachments) {
        final rows = <Widget>[];
        for (final attachment in attachments) {
          if (attachment.kind != IcalAttachmentKind.binary) continue;
          final name = davAttachmentFileName(attachment);
          rows.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attachment.mimeType),
                if (attachment.canSave)
                  _button(
                    '${context.l10n.save} $name',
                    _saving ? null : () => unawaited(_save(attachment)),
                    key: ValueKey('dav-attachment-save-${attachment.index}'),
                  )
                else ...[
                  Text(name),
                  Text(context.l10n.attachmentInvalidOrTooLarge),
                ],
              ],
            ),
          );
        }
        for (final link in eventAttachmentLinks([
          for (final attachment in attachments)
            if (widget.task != null || attachment.fromAlarm) attachment.uri,
        ])) {
          rows.add(
            _button(link.name, () async {
              if (await openScheduleWebLink(link.url) || !mounted) return;
              setState(() => _failed = true);
            }),
          );
        }
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeading) Text(context.l10n.attachments),
            if (_failed) Text(context.l10n.operationFailed),
            for (final row in rows)
              Padding(padding: const EdgeInsets.only(top: 4), child: row),
          ],
        );
      },
    );
  }

  Future<void> _save(IcalAttachment attachment) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.saveInline(attachment);
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
