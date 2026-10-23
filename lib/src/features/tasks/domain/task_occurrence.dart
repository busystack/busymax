import 'dart:convert';

/// Identifies the authored occurrence represented by a recurring DAV master.
/// Notes, status, transport revisions and device-local conversions are excluded:
/// completing an occurrence may advance its dates/rule under the same task ID.
String? davTaskOccurrenceKey({
  required String? davCollectionId,
  required String? recurrenceJson,
  required String? recurrenceIdKey,
  required String? providerMetadataJson,
}) {
  if (davCollectionId == null || recurrenceJson == null) return null;
  final Object? recurrence;
  final Object? metadata;
  try {
    recurrence = jsonDecode(recurrenceJson);
    metadata = providerMetadataJson == null
        ? null
        : jsonDecode(providerMetadataJson);
  } on FormatException {
    return null;
  }
  if (recurrence is! Map || metadata is! Map) return null;
  final rules = recurrence['rules'];
  final dates = recurrence['dates'];
  if ((rules is! List || rules.isEmpty) && (dates is! List || dates.isEmpty)) {
    return null;
  }
  return jsonEncode([
    recurrenceIdKey,
    recurrence,
    metadata['nativeStart'],
    metadata['nativeDue'],
  ]);
}
