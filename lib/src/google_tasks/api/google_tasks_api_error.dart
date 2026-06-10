import 'dart:convert';

class GoogleTasksApiError implements Exception {
  const GoogleTasksApiError({
    required this.statusCode,
    required this.message,
    this.code,
    this.status,
    this.rawJson,
  });

  factory GoogleTasksApiError.fromResponse({
    required int statusCode,
    required String body,
  }) {
    if (body.isEmpty) {
      return GoogleTasksApiError(
        statusCode: statusCode,
        message: 'Google Tasks API returned HTTP $statusCode.',
      );
    }

    try {
      final decoded = jsonDecode(body) as Map<String, Object?>;
      final error = decoded['error'];
      if (error is Map) {
        final errorJson = error.cast<String, Object?>();
        return GoogleTasksApiError(
          statusCode: statusCode,
          code: errorJson['code']?.toString(),
          status: errorJson['status']?.toString(),
          message:
              errorJson['message']?.toString() ??
              'Google Tasks API returned HTTP $statusCode.',
          rawJson: decoded,
        );
      }
      return GoogleTasksApiError(
        statusCode: statusCode,
        message: 'Google Tasks API returned HTTP $statusCode.',
        rawJson: decoded,
      );
    } on Object {
      return GoogleTasksApiError(
        statusCode: statusCode,
        message: 'Google Tasks API returned HTTP $statusCode.',
      );
    }
  }

  final int statusCode;
  final String? code;
  final String? status;
  final String message;
  final Map<String, Object?>? rawJson;

  @override
  String toString() => 'GoogleTasksApiError($statusCode, $message)';
}
