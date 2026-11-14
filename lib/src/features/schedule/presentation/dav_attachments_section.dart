import 'package:flutter/material.dart';

import '../../../app/busymax_design.dart';
import '../../attachments/dav_attachment_providers.dart';
import '../../attachments/presentation/dav_attachments_section.dart';
import 'dav_attachment_save.dart';
export '../../attachments/dav_attachment_providers.dart';

class DavAttachmentsSection extends StatelessWidget {
  const DavAttachmentsSection.event({
    super.key,
    required String eventId,
    this.showHeading = true,
  }) : eventId = eventId,
       task = null;
  const DavAttachmentsSection.task({
    super.key,
    required DavTaskAttachmentTarget target,
  }) : eventId = null,
       task = target,
       showHeading = true;
  final String? eventId;
  final DavTaskAttachmentTarget? task;
  final bool showHeading;
  @override
  Widget build(BuildContext context) {
    Widget button(String label, VoidCallback? pressed) =>
        BusyMaxPushButton.standard(onPressed: pressed, child: Text(label));
    return task == null
        ? CalDavAttachmentsSection.event(
            eventId: eventId!,
            showHeading: showHeading,
            saveInline: saveDavInlineAttachment,
            buttonBuilder: button,
          )
        : CalDavAttachmentsSection.task(
            target: task!,
            saveInline: saveDavInlineAttachment,
            buttonBuilder: button,
          );
  }
}
