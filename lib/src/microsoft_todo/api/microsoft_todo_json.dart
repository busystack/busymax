import 'dart:convert';

Map<String, Object?> microsoftJsonObjectFromBody(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object.');
  }
  return decoded.cast<String, Object?>();
}

List<Map<String, Object?>> microsoftJsonObjectList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is Map) item.cast<String, Object?>(),
  ];
}

Map<String, Object?>? microsoftJsonObjectOrNull(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.cast<String, Object?>();
}

String? microsoftStringOrNull(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

bool? microsoftBoolOrNull(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value == null) {
    return null;
  }
  return value.toString() == 'true';
}
