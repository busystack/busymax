enum MicrosoftEventAttachmentKind { file, item, reference, unknown }

/// Metadata returned by the event-scoped Graph attachment collection.
/// File contents are requested separately only after an explicit action.
final class MicrosoftEventAttachment {
  const MicrosoftEventAttachment({
    required this.id,
    required this.name,
    required this.kind,
    this.size,
    this.contentType,
    this.sourceUrl,
  });

  factory MicrosoftEventAttachment.fromJson(Map<String, Object?> json) {
    return MicrosoftEventAttachment(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: switch (json['@odata.type']?.toString().toLowerCase()) {
        '#microsoft.graph.fileattachment' => MicrosoftEventAttachmentKind.file,
        '#microsoft.graph.itemattachment' => MicrosoftEventAttachmentKind.item,
        '#microsoft.graph.referenceattachment' =>
          MicrosoftEventAttachmentKind.reference,
        _ => MicrosoftEventAttachmentKind.unknown,
      },
      size: json['size'] is int ? json['size'] as int : null,
      contentType: json['contentType']?.toString(),
      sourceUrl: json['sourceUrl']?.toString(),
    );
  }

  final String id;
  final String name;
  final MicrosoftEventAttachmentKind kind;
  final int? size;
  final String? contentType;
  final String? sourceUrl;

  bool get canDownload =>
      id.isNotEmpty &&
      (kind == MicrosoftEventAttachmentKind.file ||
          kind == MicrosoftEventAttachmentKind.item);
}
