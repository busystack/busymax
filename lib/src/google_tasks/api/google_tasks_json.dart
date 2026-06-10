import 'dart:convert';

Map<String, Object?> jsonObjectFromBody(String body) {
  if (body.isEmpty) {
    return <String, Object?>{};
  }
  return (jsonDecode(body) as Map).cast<String, Object?>();
}

List<Map<String, Object?>> jsonObjectList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map((item) => (item as Map).cast<String, Object?>()).toList();
}

String encodeGoogleDateTime(DateTime value) {
  return value.toUtc().toIso8601String();
}

String encodeGoogleDateOnly(DateTime value) {
  return encodeGoogleDateParts(value.year, value.month, value.day);
}

String encodeGoogleDateParts(int year, int month, int day) {
  final paddedYear = year.toString().padLeft(4, '0');
  final paddedMonth = month.toString().padLeft(2, '0');
  final paddedDay = day.toString().padLeft(2, '0');
  return '$paddedYear-$paddedMonth-$paddedDay';
}

String encodeGoogleDueDate(DateTime value) {
  return '${encodeGoogleDateOnly(value)}T00:00:00.000Z';
}

String? normalizeGoogleDueDateValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return encodeGoogleDateOnly(value);
  }

  final text = value.toString();
  if (text.isEmpty) {
    return null;
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return text;
  }
  final dateText = text.contains('T') ? text : '${text}T00:00:00.000Z';
  try {
    final parsed = DateTime.parse(dateText).toUtc();
    return encodeGoogleDateParts(parsed.year, parsed.month, parsed.day);
  } on FormatException {
    return text;
  }
}

Map<String, String> compactQuery(Map<String, String?> query) {
  return {
    for (final entry in query.entries)
      if (entry.value != null && entry.value!.isNotEmpty)
        entry.key: entry.value!,
  };
}

String? boolQuery(bool? value) => value?.toString();

String? intQuery(int? value) => value?.toString();

String? dateTimeQuery(DateTime? value) {
  return value == null ? null : encodeGoogleDateTime(value);
}
