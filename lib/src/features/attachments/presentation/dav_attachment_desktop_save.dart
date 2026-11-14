import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../../../dav/ical/ical_attachments.dart';
import 'dav_attachment_file_name.dart';

/// Explicit user save only. Never auto-open or execute downloaded binary data.
/// Stage beside the chosen destination so commit is an atomic rename, never
/// a write through a destination symlink. No attachment cache/temp export is
/// retained; failed/cancelled saves leave the original destination untouched.
Future<String?> saveDavInlineAttachmentToDesktop(
  IcalAttachment attachment, {
  void Function(String path, bool directory)? restrictPermissions,
  Future<void> Function(File destination, List<int> bytes)? atomicWrite,
}) async {
  final bytes = attachment.decode();
  final location = await getSaveLocation(
    suggestedName: davAttachmentFileName(attachment),
  );
  if (location == null) return null;
  final destination = File(location.path);
  if (atomicWrite != null) {
    await atomicWrite(destination, bytes);
    return destination.path;
  }
  final staging = await destination.parent.createTemp('.busymax-attachment-');
  try {
    restrictPermissions?.call(staging.path, true);
    final file = File('${staging.path}/content');
    await file.create(exclusive: true);
    restrictPermissions?.call(file.path, false);
    await file.writeAsBytes(bytes, flush: true);
    final type = await FileSystemEntity.type(
      destination.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw const FileSystemException(
        'The selected destination is not a file.',
      );
    }
    await file.rename(destination.path);
    return destination.path;
  } finally {
    await staging.delete(recursive: true);
  }
}
