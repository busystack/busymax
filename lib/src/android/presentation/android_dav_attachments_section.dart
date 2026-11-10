import 'package:flutter/material.dart';
import 'package:busymax_android_platform/busymax_android_platform.dart';

import '../../dav/ical/ical_attachments.dart';
import '../../features/attachments/dav_attachment_providers.dart';
import '../../features/attachments/presentation/dav_attachments_section.dart';
import '../../features/attachments/presentation/dav_attachment_file_name.dart';

class AndroidDavAttachmentsSection extends StatelessWidget {
  const AndroidDavAttachmentsSection.event({
    super.key,
    required String eventId,
    this.showHeading = true,
  }) : eventId = eventId,
       task = null;
  const AndroidDavAttachmentsSection.task({
    super.key,
    required DavTaskAttachmentTarget target,
  }) : eventId = null,
       task = target,
       showHeading = true;
  final String? eventId;
  final DavTaskAttachmentTarget? task;
  final bool showHeading;
  Future<String?> _save(IcalAttachment attachment) =>
      BusyMaxAndroidPlatform.instance.createDocument(
        suggestedName: davAttachmentFileName(attachment),
        mimeType: attachment.mimeType,
        bytes: attachment.decode(),
      );
  @override
  Widget build(BuildContext context) => task == null
      ? CalDavAttachmentsSection.event(
          eventId: eventId!,
          showHeading: showHeading,
          saveInline: _save,
        )
      : CalDavAttachmentsSection.task(target: task!, saveInline: _save);
}
