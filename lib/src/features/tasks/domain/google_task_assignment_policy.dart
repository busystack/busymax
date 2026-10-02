import 'dart:convert';

/// Restrictions attached to an individual Google task, not to its list.
class GoogleTaskAssignmentPolicy {
  const GoogleTaskAssignmentPolicy({
    required this.isAssigned,
    required this.isFromDocument,
    this.originalTaskUrl,
  });

  factory GoogleTaskAssignmentPolicy.fromJson(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const GoogleTaskAssignmentPolicy(
        isAssigned: false,
        isFromDocument: false,
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      // The stored source is present but unreadable. Keep the conservative
      // hierarchy restriction until a later sync repairs the metadata.
      return const GoogleTaskAssignmentPolicy(
        isAssigned: true,
        isFromDocument: false,
      );
    }
    if (decoded is! Map) {
      return const GoogleTaskAssignmentPolicy(
        isAssigned: true,
        isFromDocument: false,
      );
    }
    final type = decoded['surfaceType']?.toString().toUpperCase();
    final rawUrl = decoded['linkToTask']?.toString();
    final url = Uri.tryParse(rawUrl ?? '');
    return GoogleTaskAssignmentPolicy(
      isAssigned: true,
      isFromDocument: type == 'DOCUMENT',
      originalTaskUrl:
          url != null &&
              (url.scheme == 'https' || url.scheme == 'http') &&
              url.host.isNotEmpty &&
              url.userInfo.isEmpty
          ? url.toString()
          : null,
    );
  }

  final bool isAssigned;
  final bool isFromDocument;
  final String? originalTaskUrl;

  void checkNotes(Object? notes) {
    if (isFromDocument && notes != null && notes.toString().isNotEmpty) {
      throw UnsupportedError('Tasks assigned from Docs cannot have notes.');
    }
  }

  void checkCanBeChild(String? parentId) {
    if (isAssigned && parentId != null && parentId.isNotEmpty) {
      throw UnsupportedError('Assigned tasks cannot become subtasks.');
    }
  }

  void checkCanBeParent() {
    if (isAssigned) {
      throw UnsupportedError('Assigned tasks cannot have subtasks.');
    }
  }
}
