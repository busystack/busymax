import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../application/event_attachment_operations.dart';

export '../application/event_attachment_operations.dart'
    show safeAttachmentFileName;

Future<String?> saveAttachmentOnDesktop({
  required String name,
  required List<int> bytes,
}) async {
  final safeName = safeAttachmentFileName(name);
  if (safeName == null) throw const FormatException('Invalid attachment name.');
  final location = await getSaveLocation(suggestedName: safeName);
  if (location == null) return null;
  final file = File(location.path);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
