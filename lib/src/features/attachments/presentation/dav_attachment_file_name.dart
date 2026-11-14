import 'dart:convert';

import '../../../dav/ical/ical_attachments.dart';
import '../../schedule/presentation/attachment_download.dart';

String davAttachmentFileName(IcalAttachment attachment) {
  final hint = attachment.suggestedName;
  if (hint != null &&
      utf8.encode(hint).length <= 255 &&
      !hint.runes.any(
        (value) =>
            (value >= 0x7f && value <= 0x9f) ||
            (value >= 0x2028 && value <= 0x202e) ||
            (value >= 0x2066 && value <= 0x2069),
      )) {
    final name = safeAttachmentFileName(hint);
    if (name != null) return name;
  }
  return 'attachment-${attachment.index + 1}.bin';
}
