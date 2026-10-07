/// An in-memory, item-scoped Microsoft attachment transfer. The URL is an
/// opaque credential for Outlook sessions and must never be logged or shown.
final class MicrosoftAttachmentUploadSession {
  MicrosoftAttachmentUploadSession({
    required this.url,
    required this.expiresAt,
    required this.nextOffset,
  });

  final Uri url;
  DateTime? expiresAt;
  int nextOffset;
  bool finalRangeMayHaveBeenSubmitted = false;

  void update(Map<String, Object?> response, int totalBytes) {
    final ranges =
        response['nextExpectedRanges'] ?? response['NextExpectedRanges'];
    if (ranges is! List || ranges.length != 1 || ranges.single is! String) {
      throw const FormatException('Invalid attachment upload progress.');
    }
    final match = RegExp(
      r'^(\d+)(?:-\d*)?$',
    ).firstMatch(ranges.single as String);
    final offset = match == null ? null : int.tryParse(match.group(1)!);
    if (offset == null || offset < 0 || offset > totalBytes) {
      throw const FormatException('Invalid attachment upload progress.');
    }
    nextOffset = offset;
    final expiration =
        response['expirationDateTime'] ?? response['ExpirationDateTime'];
    if (expiration != null) {
      expiresAt = DateTime.tryParse(expiration.toString())?.toUtc();
      if (expiresAt == null) {
        throw const FormatException('Invalid attachment upload expiry.');
      }
    }
  }
}

String attachmentIdFromUploadLocation(String? source) {
  final uri = Uri.tryParse(source ?? '');
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    throw const FormatException('Missing attachment upload identity.');
  }
  final segments = uri.pathSegments;
  if (segments.isEmpty) {
    throw const FormatException('Missing attachment upload identity.');
  }
  if (segments.length >= 2 &&
      segments[segments.length - 2].toLowerCase() == 'attachments' &&
      segments.last.isNotEmpty) {
    return segments.last;
  }
  // Outlook's documented final Location uses an OData key segment,
  // /Attachments('id'), whereas To Do uses /Attachments/id.
  final outlook = RegExp(
    r"^Attachments\('([^']+)'\)$",
    caseSensitive: false,
  ).firstMatch(segments.last);
  if (outlook == null) {
    throw const FormatException('Missing attachment upload identity.');
  }
  return outlook.group(1)!;
}

String attachmentIdFromUploadHeaders(Map<String, String> headers) =>
    attachmentIdFromUploadLocation(
      headers.entries
          .where((entry) => entry.key.toLowerCase() == 'location')
          .firstOrNull
          ?.value,
    );

/// A transfer request may have reached the service. It is not safe to start
/// another attempt merely because the response or status lookup was lost.
final class MicrosoftAttachmentUploadUncertain implements Exception {
  const MicrosoftAttachmentUploadUncertain();

  @override
  String toString() => 'Attachment upload outcome is unresolved.';
}
