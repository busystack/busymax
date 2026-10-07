final class EventAttachmentLink {
  const EventAttachmentLink({
    required this.url,
    required this.name,
    this.mimeType,
  });

  final String url;
  final String name;
  final String? mimeType;
}

/// Only externally openable references are projected. Binary iCalendar
/// attachments and malformed links remain in the original provider resource.
List<EventAttachmentLink> eventAttachmentLinks(Object? value) {
  if (value is! List) return const [];
  final result = <EventAttachmentLink>[];
  final seen = <String>{};
  for (final item in value) {
    final map = item is Map ? item : const {};
    final rawUrl = item is String
        ? item
        : map['fileUrl']?.toString() ?? map['url']?.toString() ?? '';
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !seen.add(uri.toString())) {
      continue;
    }
    final title = map['title']?.toString().trim();
    final pathName = uri.pathSegments
        .where((part) => part.isNotEmpty)
        .lastOrNull;
    result.add(
      EventAttachmentLink(
        url: uri.toString(),
        name: title != null && title.isNotEmpty
            ? title
            : pathName == null || pathName.isEmpty
            ? uri.host
            : pathName,
        mimeType: map['mimeType']?.toString(),
      ),
    );
  }
  return result;
}
