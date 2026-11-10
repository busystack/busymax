import 'dart:io';

import 'package:posix/posix.dart' show chmod;

import '../../../dav/ical/ical_attachments.dart';
import '../../attachments/presentation/dav_attachment_desktop_save.dart';
export '../../attachments/presentation/dav_attachment_file_name.dart';

Future<String?> saveDavInlineAttachment(IcalAttachment attachment) =>
    saveDavInlineAttachmentToDesktop(
      attachment,
      restrictPermissions: (path, directory) {
        if (Platform.isLinux || Platform.isMacOS) {
          chmod(path, directory ? '700' : '600');
        }
      },
    );
