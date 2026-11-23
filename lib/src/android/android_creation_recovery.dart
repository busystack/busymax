import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

String newAndroidCreationId() => const Uuid().v4();

String recoverAndroidCreationId(Object? storedId, String key, String record) {
  if (storedId == null) {
    // Older drafts have no ID. Keep the same identity if their original
    // secure-storage record survives cleanup after a save on this version.
    return 'legacy:${sha256.convert(utf8.encode(jsonEncode([key, record])))}';
  }
  if (storedId is String &&
      (Uuid.isValidUUID(fromString: storedId) ||
          RegExp(r'^legacy:[0-9a-f]{64}$').hasMatch(storedId))) {
    return storedId;
  }
  throw const FormatException('Invalid recovery creation identity.');
}
