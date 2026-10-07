import 'dart:io';

import 'package:file_selector/file_selector.dart';

/// Reject provider-controlled path components before presenting a suggested
/// destination. The user still explicitly chooses the final save location.
String? safeAttachmentFileName(String name) {
  final value = name.trim();
  if (value.isEmpty ||
      value == '.' ||
      value == '..' ||
      value.endsWith('.') ||
      value.length > 255 ||
      value.contains('/') ||
      value.contains('\\') ||
      RegExp(r'[<>:"|?*]').hasMatch(value) ||
      RegExp(
        r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
        caseSensitive: false,
      ).hasMatch(value) ||
      value.codeUnits.any((unit) => unit < 32 || unit == 127)) {
    return null;
  }
  return value;
}

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
