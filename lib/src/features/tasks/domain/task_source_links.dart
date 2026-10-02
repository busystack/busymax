import 'dart:convert';

/// Provider-supplied task navigation only. IDs are never used to invent URLs.
class TaskSourceLink {
  const TaskSourceLink({required this.url, this.label});

  final String url;
  final String? label;
}

List<TaskSourceLink> googleTaskSourceLinks({
  required String? assignmentInfoJson,
  required String? linksJson,
  required String? webViewLink,
}) {
  final result = <TaskSourceLink>[];
  final seen = <String>{};
  void add(String? url, String? label) {
    final uri = Uri.tryParse(url?.trim() ?? '');
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !seen.add(uri.toString())) {
      return;
    }
    result.add(TaskSourceLink(url: uri.toString(), label: label));
  }

  try {
    final assignment = jsonDecode(assignmentInfoJson ?? '');
    if (assignment is Map) {
      add(assignment['linkToTask']?.toString(), null);
    }
  } on Object {
    // Cached source metadata may be unavailable or malformed; it does not
    // affect editing/completion.
  }
  try {
    final links = jsonDecode(linksJson ?? '');
    if (links is List) {
      for (final raw in links) {
        if (raw is! Map) continue;
        final description = raw['description']?.toString().trim();
        final type = raw['type']?.toString().trim();
        add(
          raw['link']?.toString(),
          description != null && description.isNotEmpty
              ? description
              : type != null && type.isNotEmpty
              ? type
              : null,
        );
      }
    }
  } on Object {
    // Do not hide an independently valid task page link.
  }
  add(webViewLink, 'Google Tasks');
  return List.unmodifiable(result);
}
